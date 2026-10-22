import { initializeApp } from 'firebase/app';
import { getAuth, onAuthStateChanged, signInWithCustomToken, signOut } from 'firebase/auth';
import { Capacitor } from '@capacitor/core';
import { Browser } from '@capacitor/browser';
import { installation, officeClient } from './license-client.mjs';
import { pairInstallation } from './pairing-client.mjs';
import { createAccessController } from './access-controller.mjs';
const config = __OFFICE_CONFIG__, $ = id => document.getElementById(id);
const human = message => /Two installation/.test(message) ? 'Esta conta já tem dois dispositivos. Desvincule um deles ou procure o suporte.' :
  /Payment approval/.test(message) ? 'A compra desta conta ainda precisa da aprovação do pagamento.' :
  /revoked|not active/.test(message) ? 'Esta instalação não está autorizada. Entre novamente ou procure o suporte.' :
  /Office|Entre|Verificando|Conta|Conta ou|Código|Não foi/.test(message) ? message : 'Não foi possível confirmar a liberação. Confira a conexão e tente novamente.';
if (!config.commercial || !config.enabled) {
  $('status').textContent = 'Esta é a versão de laboratório. O acesso comercial ainda não foi configurado.';
} else {
  try {
    const auth = getAuth(initializeApp(config.firebase));
    const device = await installation();
    const namespaces = new Map(); let frame, login;
    const client = officeClient({ endpoint: config.endpoint, installation: device,
      getToken: async () => {
        const user = auth.currentUser;
        if (!user) throw new Error('Entre com Google.');
        const token = await user.getIdToken(true);
        if (auth.currentUser?.uid !== user.uid) throw new Error('Conta alterada.');
        return token;
      },
    });
    const controller = createAccessController({
      verifyAccess: async (uid, activate) => {
        if (auth.currentUser?.uid !== uid) throw new Error('Conta alterada.');
        const result = await client.prove(activate ? 'activate' : 'access');
        if (auth.currentUser?.uid !== uid) throw new Error('Conta alterada.');
        return result;
      },
      showEditor(uid) {
        const namespace = namespaces.get(uid);
        if (!namespace) throw new Error('Conta não preparada.');
        if (!frame) {
          frame = document.createElement('iframe'); frame.title = 'Editor Rocha+ Office';
          frame.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-downloads allow-forms allow-modals');
          frame.src = `editor.html?account=${namespace}`; $('editor-container').append(frame);
        }
        frame.hidden = false; frame.inert = false; $('account-panel').hidden = true;
      },
      hideEditor(discard) {
        if (frame) { frame.hidden = true; frame.inert = true; if (discard) { frame.remove(); frame = null; } }
        $('account-panel').hidden = false;
      },
      setStatus(message) { $('status').textContent = human(message); },
    });
    async function applyAccount(user) {
      await controller.account(null); // immediately close previous account's editor
      if (user && (login || auth.currentUser?.uid !== user.uid)) return;
      $('account-name').textContent = user?.email ?? '';
      $('logout').hidden = !user; $('deactivate').hidden = !user; $('retry').hidden = !user;
      $('signin').hidden = !!user; $('signin').disabled = false;
      if (user) {
        const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(user.uid));
        namespaces.set(user.uid, [...new Uint8Array(digest)].map(v => v.toString(16).padStart(2, '0')).join(''));
        if (auth.currentUser?.uid === user.uid) await controller.account(user.uid);
      }
    }
    onAuthStateChanged(auth, applyAccount);
    $('signin').onclick = async () => {
      login?.abort(); const attempt = new AbortController(); login = attempt;
      $('signin').disabled = true; $('cancel').hidden = false;
      try {
        const customToken = await pairInstallation({ endpoint: config.endpoint, portalUrl: config.portalUrl,
          device, signal: attempt.signal,
          showCode(code) { $('code').hidden = false; $('code').textContent = code; $('status').textContent = 'Digite este código no navegador e confirme sua conta Google.'; },
          openBrowser: async url => {
            if (window.officeDesktop) return window.officeDesktop.openGoogle(url);
            if (Capacitor.isNativePlatform()) return Browser.open({ url });
            window.open(url, '_blank', 'noopener');
            const link = document.createElement('a'); link.href = url; link.target = '_blank'; link.rel = 'noopener'; link.textContent = 'Abrir navegador para confirmar'; $('status').replaceChildren(link);
          },
        });
        if (attempt.signal.aborted || login !== attempt) return;
        const credential = await signInWithCustomToken(auth, customToken);
        if (attempt.signal.aborted || login !== attempt) { await signOut(auth); return; }
        login = null; $('cancel').hidden = true; $('code').hidden = true;
        await applyAccount(credential.user);
      } catch (error) { if (login === attempt) $('status').textContent = attempt.signal.aborted ? 'Entrada cancelada.' : human(error.message); }
      finally { if (login === attempt || login === null) { $('signin').disabled = false; $('cancel').hidden = true; $('code').hidden = true; login = null; } }
    };
    $('cancel').onclick = () => { login?.abort(); $('code').hidden = true; $('status').textContent = 'Entrada cancelada.'; };
    $('logout').onclick = async () => {
      if (frame && !confirm('Salve seus arquivos antes de sair. Continuar?')) return;
      login?.abort(); await controller.account(null); await signOut(auth);
    };
    $('deactivate').onclick = async () => {
      if (!confirm('Salve seus arquivos. Deseja liberar a vaga deste dispositivo?')) return;
      try { await client.prove('deactivate'); await controller.account(null); await signOut(auth); }
      catch { $('status').textContent = 'Não foi possível desvincular. A vaga continua registrada até a confirmação do servidor.'; }
    };
    $('retry').onclick = () => controller.resume({ activate: true });
    document.addEventListener('visibilitychange', () => { if (!document.hidden && !login) controller.resume(); });
    window.addEventListener('pagehide', () => { login?.abort(); controller.close(); });
  } catch { $('status').textContent = 'Não foi possível preparar a entrada segura. Nenhuma liberação foi concedida.'; }
}
