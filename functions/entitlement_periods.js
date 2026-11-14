'use strict';

// Pure entitlement calculation. Only verified, admin-linked ledger entries
// may be supplied by the trusted backend. Never accept ledger data from an app.
const PERIODS = Object.freeze({monthly: 1, annual: 12});

// Commercial rule for a customer holding monthly AND annual payments.
// PENDING OWNER DECISION — change only this constant:
//   'latest_end' (current): periods do not add up; the latest end date wins.
//   'stacked': each approved payment extends from max(its approval, current end),
//              in approval order (1 + 12 months = 13 months of access).
const MONTHLY_ANNUAL_POLICIES = Object.freeze(['latest_end', 'stacked']);
const MONTHLY_ANNUAL_POLICY = 'latest_end';
function addUtcMonths(iso, months) {
  const date = new Date(iso);
  if (!Number.isFinite(date.getTime()) || !Number.isInteger(months) || months < 1) {
    throw new Error('invalid approval date or period');
  }
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth() + months;
  const targetYear = year + Math.floor(month / 12);
  const targetMonth = month % 12;
  const lastDay = new Date(Date.UTC(targetYear, targetMonth + 1, 0)).getUTCDate();
  return new Date(Date.UTC(targetYear, targetMonth,
    Math.min(date.getUTCDate(), lastDay), date.getUTCHours(), date.getUTCMinutes(),
    date.getUTCSeconds(), date.getUTCMilliseconds()));
}
function entitlementFromLedger(uid, records, policy = MONTHLY_ANNUAL_POLICY) {
  if (!uid || typeof uid !== 'string' || !Array.isArray(records)) throw new Error('invalid input');
  if (!MONTHLY_ANNUAL_POLICIES.includes(policy)) throw new Error('invalid period policy');
  const eligible = [];
  const seen = new Set();
  let paidUntilMs = 0;
  for (const row of records) {
    if (!row || row.uid !== uid || !/^\d+$/.test(String(row.paymentId))) throw new Error('ledger ownership mismatch');
    if (seen.has(String(row.paymentId))) throw new Error('duplicate payment ledger entry');
    seen.add(String(row.paymentId));
    if (row.provider !== 'mercadopago' || row.status !== 'approved' ||
        row.eligibleForReview !== true || row.reviewed !== true ||
        !Object.hasOwn(PERIODS, row.plan)) continue;
    const approvalMs = Date.parse(row.approvalDate);
    if (!Number.isFinite(approvalMs) || !/Z$|[+-]\d\d:\d\d$/.test(row.approvalDate)) {
      throw new Error('untrusted approval timestamp');
    }
    if (approvalMs > Date.now() + 5 * 60 * 1000) {
      throw new Error('approval date is in the future');
    }
    eligible.push({approvalMs, approvalDate: row.approvalDate, months: PERIODS[row.plan],
      paymentId: String(row.paymentId)});
  }
  // Deterministic order: approval time, then payment id (ledger order is irrelevant).
  eligible.sort((a, b) => a.approvalMs - b.approvalMs || a.paymentId.localeCompare(b.paymentId));
  for (const p of eligible) {
    if (policy === 'stacked' && paidUntilMs > p.approvalMs) {
      paidUntilMs = addUtcMonths(new Date(paidUntilMs).toISOString(), p.months).getTime();
    } else {
      // latest_end: concurrent purchases do not compound; the latest end date wins.
      paidUntilMs = Math.max(paidUntilMs, addUtcMonths(p.approvalDate, p.months).getTime());
    }
  }
  return paidUntilMs ? new Date(paidUntilMs).toISOString() : null;
}
module.exports = {addUtcMonths, entitlementFromLedger, MONTHLY_ANNUAL_POLICY};
