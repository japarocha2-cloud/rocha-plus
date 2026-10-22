import { initializeApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider, onAuthStateChanged, signInWithPopup, signOut } from 'firebase/auth';
const config = __OFFICE_CONFIG__, $ = id => document.getElementById(id);
let candidate = null, session = 0;
if (!config.enabled) $('status').textContent = 'O painel aguarda a configuração do serviço de liberação.';
else {
  const auth = getAuth(initializeApp(config.firebase));
  $('signin').disabled = false;
  onAuthStateChanged(auth, async user => {
    const current = ++session; candidate = null; $('buyer-panel').hidden = true; $('admin-panel').hidden = true;
    $('signin').hidden = !!user; $('signout').hidden = !user;
    if (!user) { $('status').textContent = 'Acesso exclusivo do operador autorizado do Office.'; return; }
    try {
      const token = await user.getIdTokenResult(true);
      if (current !== session) return;
      if (token.claims.rochaOfficeAdmin !== true || token.claims.firebase?.sign_in_provider !== 'google.com') throw Error();
      $('admin-panel').hidden = false; $('status').textContent = `Operador: ${user.email ?? 'conta Google'}`;
    } catch { if (current === session) $('status').textContent = 'Esta conta não possui permissão administrativa do Office.'; }
  });
  async function request(action, body) {
    const user = auth.currentUser, generation = session;
    if (!user) throw Error();
    const token = await user.getIdToken(true);
    const response = await fetch(`${config.endpoint.replace(/\/$/, '')}/v1/office/admin/${action}`, {
      method: 'POST', cache: 'no-store', signal: AbortSignal.timeout(12_000), headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    if (generation !== session || auth.currentUser?.uid !== user.uid || !response.ok) throw Error();
    return response.json();
  }
  $('signin').onclick = async () => { try { await signInWithPopup(auth, new GoogleAuthProvider()); } catch { $('status').textContent = 'Entrada Google não concluída. Nenhuma aprovação foi realizada.'; } };
  $('signout').onclick = () => signOut(auth);
  $('email').oninput = () => { candidate = null; $('buyer-panel').hidden = true; $('payment-form').reset(); $('refund-form').reset(); };
  $('lookup-form').onsubmit = async event => {
    event.preventDefault(); candidate = null; $('buyer-panel').hidden = true;
    const email = $('email').value.trim().toLowerCase();
    try {
      const buyer = await request('lookup', { email });
      if ($('email').value.trim().toLowerCase() !== email) return;
      candidate = buyer; $('buyer-name').textContent = buyer.email; $('buyer-state').textContent = buyer.licensed ? 'Pacote aprovado para esta conta.' : 'Sem compra Office aprovada.';
      $('buyer-panel').hidden = false; $('devices').replaceChildren();
      for (const device of buyer.devices) {
        const row = document.createElement('p'), button = document.createElement('button'); row.textContent = device.label + ' ';
        button.textContent = 'Revogar este dispositivo'; row.append(button); $('devices').append(row);
        button.onclick = async () => {
          const evidenceReference = prompt('Referência do atendimento para revogar esta instalação:');
          if (!evidenceReference || candidate?.uid !== buyer.uid) return;
          try { await request('revoke-device', { uid: buyer.uid, deviceId: device.id, evidenceReference }); row.textContent = `${device.label}: revogação registrada.`; }
          catch { $('status').textContent = 'Revogação não confirmada. Confira o estado antes de repetir.'; }
        };
      }
    } catch { $('status').textContent = 'Conta Google não localizada ou acesso indisponível. Nenhuma liberação foi feita.'; }
  };
  $('payment-form').onsubmit = async event => {
    event.preventDefault(); const buyer = candidate, button = event.submitter;
    if (!buyer || !$('confirmed').checked) return;
    button.disabled = true;
    try {
      const result = await request('confirm', { uid: buyer.uid, product: 'rocha-office-basic', provider: 'mercadopago', currency: 'BRL', amountCents: 4990,
        transactionId: $('transaction').value.trim(), evidenceReference: $('evidence').value.trim() });
      if (result.status !== 'confirmed') throw Error();
      $('status').textContent = result.duplicate ? 'Esta aprovação já estava registrada. Não foi criada uma segunda liberação.' : `Liberação do pacote registrada para ${buyer.email}.`;
      $('confirmed').checked = false;
    } catch { $('status').textContent = 'Aprovação não confirmada. Confira a conta e o pagamento antes de repetir.'; }
    finally { button.disabled = false; }
  };
  $('refund-form').onsubmit = async event => {
    event.preventDefault(); const buyer = candidate, button = event.submitter;
    if (!buyer || !confirm('O estorno já foi confirmado na conta de pagamento? Esta ação registra a revogação no Office.')) return;
    button.disabled = true;
    try {
      const result = await request('refund', { uid: buyer.uid, provider: 'mercadopago', transactionId: $('refund-transaction').value.trim(), evidenceReference: $('refund-evidence').value.trim() });
      if (result.status !== 'refunded') throw Error(); $('status').textContent = `Estorno e revogação registrados para ${buyer.email}.`;
    } catch { $('status').textContent = 'Registro de estorno não confirmado. Confira o estado antes de repetir.'; }
    finally { button.disabled = false; }
  };
}
