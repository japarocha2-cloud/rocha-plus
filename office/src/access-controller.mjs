// Editor creation/removal is owned by this controller, not by a CSS paid flag.
export function createAccessController({ verifyAccess, showEditor, hideEditor, setStatus,
  intervalMs = 60_000, verificationTimeoutMs = 12_000, schedule = setInterval, unschedule = clearInterval }) {
  let requestSequence = 0;
  let revision = 0, uid = null, timer, shown = false, closed = false;
  const lock = (discard = false) => { if (shown || discard) hideEditor(discard); shown = false; };
  async function check(expectedUid, generation, activate) {
    const sequence = ++requestSequence;
    let deadline;
    try {
      const result = await Promise.race([verifyAccess(expectedUid, activate), new Promise((_, reject) => { deadline = setTimeout(() => reject(new Error('Não foi possível confirmar a liberação a tempo.')), verificationTimeoutMs); })]);
      if (closed || generation !== revision || uid !== expectedUid || sequence !== requestSequence) return;
      if (result?.allowed !== true || result.uid !== expectedUid || result.product !== 'rocha-office-basic') throw new Error('Conta ou licença não autorizada.');
      if (!shown) { showEditor(expectedUid); shown = true; }
      setStatus('Office liberado para esta conta e instalação.');
    } catch (error) {
      if (closed || generation !== revision || uid !== expectedUid || sequence !== requestSequence) return;
      lock(); setStatus(error.message || 'Não foi possível confirmar a liberação do Office.');
    } finally { clearTimeout(deadline); }
  }
  return {
    async account(nextUid) {
      if (closed) return;
      revision++; uid = nextUid; lock(true); if (timer) unschedule(timer); timer = null;
      if (!uid) { setStatus('Entre com Google para verificar a liberação do pacote Office.'); return; }
      const generation = revision, expectedUid = uid;
      setStatus('Verificando a conta e a instalação…');
      await check(expectedUid, generation, true);
      if (!closed && generation === revision) timer = schedule(() => check(expectedUid, generation, false), intervalMs);
    },
    async resume({ activate = false } = {}) {
      if (closed || !uid) return;
      lock(); const generation = ++revision;
      if (timer) unschedule(timer); timer = null;
      const expectedUid = uid; await check(expectedUid, generation, activate);
      if (!closed && revision === generation) timer = schedule(() => check(expectedUid, generation, false), intervalMs);
    },
    close() { closed = true; revision++; lock(true); if (timer) unschedule(timer); timer = null; },
  };
}
