let lastClipboardContent = '';

document.addEventListener('copy', async (e) => {
  try {
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


chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'updatePopup') {
   
  }
});