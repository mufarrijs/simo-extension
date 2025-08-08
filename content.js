// Content script to monitor copy events
let lastClipboardContent = '';

// Monitor copy events
document.addEventListener('copy', async (e) => {
  try {
    // Small delay to ensure clipboard is updated
    setTimeout(async () => {
      try {
        const text = await navigator.clipboard.readText();
        if (text && text !== lastClipboardContent) {
          lastClipboardContent = text;
          chrome.runtime.sendMessage({
            action: 'addClipboardItem',
            text: text
          });
        }
      } catch (error) {
        console.log('Could not read clipboard:', error);
      }
    }, 100);
  } catch (error) {
    console.log('Copy event error:', error);
  }
});

// Also monitor keyboard shortcuts for copy
document.addEventListener('keydown', (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key === 'c') {
    setTimeout(async () => {
      try {
        const text = await navigator.clipboard.readText();
        if (text && text !== lastClipboardContent) {
          lastClipboardContent = text;
          chrome.runtime.sendMessage({
            action: 'addClipboardItem',
            text: text
          });
        }
      } catch (error) {
        console.log('Could not read clipboard:', error);
      }
    }, 100);
  }
});

// Listen for messages from background script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'updatePopup') {
    // This will be handled by popup.js if popup is open
  }
});