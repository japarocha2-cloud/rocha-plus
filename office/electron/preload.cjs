const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('officeDesktop', { openGoogle: url => ipcRenderer.invoke('office-google-browser', url) });
