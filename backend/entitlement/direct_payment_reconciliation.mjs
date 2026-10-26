// Pure reconciliation planning only. No Firebase, Mercado Pago, writes or access grants.
// Caller must supply an independently verified, complete ledger snapshot.
const deny = reason => { throw new Error('reconciliation-blocked:' + reason); };
const validId = v => typeof v === 'string' && /^[0-9]{1,30}$/.test(v);
const key = (provider, id) => provider + ':' + id;
export function planDirectPaymentReconciliation({
  verifiedPayments, ledger, ledgerComplete = false, targetUid,
  durationPolicyApproved = false,
}) {
  if (!targetUid || typeof targetUid !== 'string' || targetUid.length > 128) deny('uid');
  if (ledgerComplete !== true || !Array.isArray(ledger)) deny('ledger-incomplete');
  if (durationPolicyApproved !== true) deny('duration-policy-unapproved');
  if (!Array.isArray(verifiedPayments) || verifiedPayments.length === 0) deny('payments');
  const consumed = new Map();
  for (const entry of ledger) {
    if (!entry || entry.provider !== 'mercadopago' || !validId(entry.transactionId) ||
        typeof entry.uid !== 'string' || !entry.uid ||
        !['confirmed', 'refunded', 'charged_back'].includes(entry.status)) deny('ledger-entry');
    const k = key(entry.provider, entry.transactionId);
    if (consumed.has(k)) deny('ledger-duplicate');
    consumed.set(k, entry);
  }
  const seen = new Set(), pending = [], alreadyProcessed = [];
  for (const payment of verifiedPayments) {
    if (!payment || payment.provider !== 'mercadopago' || !validId(payment.transactionId) ||
        payment.uid !== targetUid || payment.verified !== true ||
        payment.approved !== true || payment.refunded !== false ||
        payment.chargedBack !== false) deny('unverified-payment');
    const k = key(payment.provider, payment.transactionId);
    if (seen.has(k)) deny('input-duplicate');
    seen.add(k);
    const prior = consumed.get(k);
    if (prior) {
      if (prior.uid !== targetUid) deny('cross-account');
      if (prior.status !== 'confirmed') deny('payment-reversed');
      alreadyProcessed.push(payment.transactionId);
    } else pending.push(payment.transactionId);
  }
  return Object.freeze({
    dryRun: true, writes: 0, accessGranted: false, readyToApply: false,
    targetUid, pendingTransactionIds: Object.freeze(pending),
    alreadyProcessedTransactionIds: Object.freeze(alreadyProcessed),
    requiresAtomicTransaction: true,
    durationPolicyApproved,
    warning: 'snapshot-can-become-stale; recheck-provider-and-ledger-in-atomic-commit',
  });
}
