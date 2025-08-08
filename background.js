/*
 * thats the file that listens for keyboard shortcuts
 * + it manages the list of copied items, it adds new ones and stores them
 * + handles pasting when u press the shortcuts
 */


let clipboardItems = [];
const MAX_ITEMS = 9; // can store up to 9 clipboard items cz doing ctrl v 10 will b annoying



chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'addClipboardItem') {
    addClipboardItem(message.text);
    sendResponse({ success: true });
  } else if (message.action === 'getClipboardItems') {
    sendResponse({ items: clipboardItems });
  }
});


chrome.commands.onCommand.addListener((command) => {
  if (command.startsWith('paste-item-')) {
    const itemNumber = parseInt(command.split('-')[2]);
    pasteItem(itemNumber);
  } else if (command === 'clear-clipboard') {
    clearClipboard();
  }
});

function addClipboardItem(text) {
  if (!text || text.trim() === '') return;

  const existingIndex = clipboardItems.indexOf(text);
  if (existingIndex !== -1) {

    showNotification(`Item already exists at position ${existingIndex + 1}`);
    return;
  }
  

  clipboardItems.push(text);

  if (clipboardItems.length > MAX_ITEMS) {
    clipboardItems.shift(); 
  }
  

  chrome.storage.local.set({ clipboardItems: clipboardItems });
  
  // thats to show which number this item is !!
  showNotification(`Copied as item ${clipboardItems.length}`);
  

  updatePopup();
}


async function pasteItem(itemNumber) {
  if (itemNumber < 1 || itemNumber > clipboardItems.length) {
    showNotification(`No item ${itemNumber} in clipboard`);
    return;
  }
  
  const text = clipboardItems[itemNumber - 1]; 
  
  try {

    await chrome.scripting.executeScript({
      target: { allFrames: true },
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
    
    showNotification(`Pasted item ${itemNumber}: "${text.substring(0, 20)}..."`);
  } catch (error) {
    console.error('Error pasting:', error);
    showNotification('Error pasting item');
  }
}

// this is to clear all clipboard items
function clearClipboard() {
  chrome.scripting.executeScript({
    target: { allFrames: true },
    func: () => {
      if (confirm('Are you sure you want to clear all clipboard items?')) {
        return true;
      }
      return false;
    }
  }).then((results) => {
    if (results && results[0] && results[0].result) {
      clipboardItems = [];
      chrome.storage.local.set({ clipboardItems: [] });
      updatePopup();
      showNotification('Clipboard cleared');
    }
  });
}

// thats to show notification popup on the webpage
function showNotification(message) {
  chrome.scripting.executeScript({
    target: { allFrames: true },
    func: (msg) => {
      // to create notification element
      const notification = document.createElement('div');
      notification.textContent = msg;
      notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: #333;
        color: white;
        padding: 10px 15px;
        border-radius: 5px;
        z-index: 10000;
        font-family: Arial, sans-serif;
        font-size: 14px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.3);
      `;
      
      document.body.appendChild(notification);
      
      // Remove after 2 seconds
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification);
        }
      }, 2000);
    },
    args: [message]
  });
}

function updatePopup() {
  chrome.runtime.sendMessage({ action: 'updatePopup', items: clipboardItems });
}

chrome.storage.local.get(['clipboardItems'], (result) => {
  if (result.clipboardItems) {
    clipboardItems = result.clipboardItems;
  }
});