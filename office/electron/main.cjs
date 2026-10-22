const { app, BrowserWindow, shell, ipcMain } = require('electron');
const path = require('node:path');
const { readFileSync } = require('node:fs');
const { fileURLToPath } = require('node:url');

function createWindow() {
  const window = new BrowserWindow({
    width: 1280, height: 820, minWidth: 800, minHeight: 550,
    backgroundColor: '#10263b',
    webPreferences: { preload: path.join(__dirname, 'preload.cjs'), contextIsolation: true, nodeIntegration: false, sandbox: true }
  });
  window.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
  window.webContents.setWindowOpenHandler(({url}) => {
    if (url.startsWith('https://')) shell.openExternal(url);
    return {action: 'deny'};
  });
}
app.whenReady().then(() => {
  ipcMain.handle('office-google-browser', async (event, raw) => {
    const entry = path.join(__dirname, '..', 'dist', 'index.html');
    if (event.senderFrame !== event.sender.mainFrame || fileURLToPath(new URL(event.senderFrame.url)) !== entry) throw new Error('Invalid login caller');
    const config = JSON.parse(readFileSync(path.join(__dirname, '..', 'dist', 'office-public-config.json'), 'utf8'));
    const target = new URL(raw), expected = new URL(config.portalUrl);
    if (!config.enabled || target.protocol !== 'https:' || target.origin !== expected.origin ||
        target.pathname !== expected.pathname || target.search || !/^#pair=[\w-]{43}$/.test(target.hash)) throw new Error('Invalid login destination');
    await shell.openExternal(target.href);
  });
  createWindow();
});
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
