import { initializeApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider, onAuthStateChanged, signInWithPopup, signOut } from 'firebase/auth';
const config = __OFFICE_CONFIG__, $ = id => document.getElementById(id);
const id = new URLSearchParams(location.hash.slice(1)).get('pair');
if (!config.enabled || !/^[\w-]{43}$/.test(id ?? '')) {
  $('status').textContent = 'Abra esta página pelo botão Entrar com Google no programa Office. A ativação comercial ainda depende da configuração do serviço.';
} else {
  const auth = getAuth(initializeApp(config.firebase));
  $('signin').disabled = false;
  onAuthStateChanged(auth, user => {
    $('account').textContent = user?.email ? `Conta: ${user.email}` : '';
    $('approve-form').hidden = !user; $('signin').hidden = !!user; $('signout').hidden = !user;
    $('status').textContent = user ? 'Digite o código que aparece no Office e confirme.' : 'Entre com a conta Google usada na compra.';
  });
  $('signin').onclick = async () => {
    $('signin').disabled = true;
    try { await signInWithPopup(auth, new GoogleAuthProvider()); }
    catch { $('status').textContent = 'Entrada não concluída. Confira a configuração Google deste endereço e tente novamente.'; }
    finally { $('signin').disabled = false; }
  };
  $('signout').onclick = () => signOut(auth);
  $('approve-form').onsubmit = async event => {
    event.preventDefault(); const button = event.submitter; button.disabled = true;
    const user = auth.currentUser;
    try {
      if (!user) throw Error();
      const token = await user.getIdToken(true);
      const response = await fetch(`${config.endpoint.replace(/\/$/, '')}/v1/office/pair/approve`, {
        method: 'POST', cache: 'no-store', signal: AbortSignal.timeout(12_000),
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, code: $('pair-code').value.trim().toUpperCase() }),
      });
      if (auth.currentUser?.uid !== user.uid) throw Error();
      if (!response.ok) {
        $('status').textContent = response.status === 403 ? 'Confira o código e a aprovação do pagamento desta conta.' : 'Código expirado ou serviço indisponível. Inicie novamente pelo Office.';
        return;
      }
      const result = await response.json(); if (result.approved !== true) throw Error();
      $('approve-form').hidden = true; $('status').textContent = 'Conta confirmada. Volte ao Office para concluir a liberação desta instalação.';
    } catch { $('status').textContent = 'Não foi possível confirmar. A liberação não foi concedida.'; }
    finally { button.disabled = false; }
  };
}
