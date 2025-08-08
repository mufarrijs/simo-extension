
document.addEventListener('DOMContentLoaded', () => {
  loadClipboardItems();
  
  document.getElementById('clearAll').addEventListener('click', () => {
    if (confirm('Are you sure you want to clear all clipboard items?')) {
      chrome.storage.local.set({ clipboardItems: [] });
      loadClipboardItems();
      
      chrome.runtime.sendMessage({ action: 'clearAll' });
    }
  });
});

async function loadClipboardItems() {
  const result = await chrome.storage.local.get(['clipboardItems']);
  const items = result.clipboardItems || [];
  
  const container = document.getElementById('clipboardItems');
  
  if (items.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <p>No clipboard items yet.</p>
        <p>Copy some text to get started!</p>
      </div>
    `;
    return;
  }
  
  container.innerHTML = '';
  
  items.forEach((item, index) => {
    const itemElement = document.createElement('div');
    itemElement.className = 'clipboard-item';
    
    const truncatedText = item.length > 40 ? item.substring(0, 40) + '...' : item;
    
    itemElement.innerHTML = `
      <div class="item-number">${index + 1}</div>
      <div class="item-text" title="${escapeHtml(item)}">${escapeHtml(truncatedText)}</div>
      <button class="paste-btn" data-index="${index}">Paste</button>
    `;
    
    container.appendChild(itemElement);
  });
  

  document.querySelectorAll('.paste-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const index = parseInt(e.target.dataset.index);
      pasteItem(index + 1); 
    });
  });
}

async function pasteItem(itemNumber) {
  try {
    const result = await chrome.storage.local.get(['clipboardItems']);
    const items = result.clipboardItems || [];
    
    if (itemNumber < 1 || itemNumber > items.length) {
      return;
    }
    
    const text = items[itemNumber - 1]; 
    
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    
    await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: (textToPaste) => {
        navigator.clipboard.writeText(textToPaste).then(() => {
          const activeElement = document.activeElement;
          if (activeElement && (activeElement.tagName === 'INPUT' || 
              activeElement.tagName === 'TEXTAREA' || 
              activeElement.isContentEditable)) {
            
            if (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA') {
              const start = activeElement.selectionStart;
              const end = activeElement.selectionEnd;
              activeElement.value = activeElement.value.substring(0, start) + textToPaste + activeElement.value.substring(end);
              activeElement.selectionStart = activeElement.selectionEnd = start + textToPaste.length;
            } else if (activeElement.isContentEditable) {
              document.execCommand('insertText', false, textToPaste);
            }
            
            activeElement.dispatchEvent(new Event('input', { bubbles: true }));
          }
        });
      },
      args: [text]
    });
    
    window.close();
    
  } catch (error) {
    console.error('Error pasting:', error);
  }
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && changes.clipboardItems) {
    loadClipboardItems();
  }
});