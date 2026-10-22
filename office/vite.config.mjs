import { defineConfig } from 'vite';
import { readFileSync, renameSync, writeFileSync } from 'node:fs';
import { buildConfig } from './src/build-config.mjs';
const config = buildConfig(process.env);
export default defineConfig({ base: './', server: { allowedHosts: ['terminal.local'] }, preview: { allowedHosts: ['terminal.local'] }, define: { __OFFICE_CONFIG__: JSON.stringify(config) },
  build: { rollupOptions: { input: ['index.html', 'commercial.html', 'portal.html', 'admin.html'] } },
  plugins: [{ name: 'office-build-mode', closeBundle() {
    writeFileSync('dist/office-public-config.json', JSON.stringify(config));
    if (config.commercial) {
      renameSync('dist/index.html', 'dist/editor.html');
      const storage = `<script>const ns=new URLSearchParams(location.search).get('account');if(!/^[a-f0-9]{64}$/.test(ns||''))throw Error('Account required');const backing=window.localStorage;window.officeStorage={getItem:k=>backing.getItem('office:'+ns+':'+k),setItem:(k,v)=>backing.setItem('office:'+ns+':'+k,v),removeItem:k=>backing.removeItem('office:'+ns+':'+k)};</script>`;
      let editor = readFileSync('dist/editor.html', 'utf8').replaceAll('localStorage', 'officeStorage');
      editor = editor.replace('<head>', '<head>' + storage).replace('&lt;head&gt;', '&lt;head&gt;&lt;script&gt;window.officeStorage=parent.officeStorage;&lt;/script&gt;');
      writeFileSync('dist/editor.html', editor);
      renameSync('dist/commercial.html', 'dist/index.html');
    }
    // The public portal package contains no editor or installer files.
    const html = readFileSync('dist/portal.html', 'utf8');
    if (!html.includes('Entrar com Google')) throw new Error('Missing Google approval portal');
  } }],
});
