'use strict';

// Pure entitlement calculation. Only verified, admin-linked ledger entries
// may be supplied by the trusted backend. Never accept ledger data from an app.
const PERIODS = Object.freeze({monthly: 1, annual: 12});
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
function entitlementFromLedger(uid, records) {
  if (!uid || typeof uid !== 'string' || !Array.isArray(records)) throw new Error('invalid input');
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
    // Concurrent monthly and annual purchases do not compound or extend one
    // another: the latest independently approved end date wins.
    const expiration = addUtcMonths(row.approvalDate, PERIODS[row.plan]).getTime();
    paidUntilMs = Math.max(paidUntilMs, expiration);
  }
  return paidUntilMs ? new Date(paidUntilMs).toISOString() : null;
}
module.exports = {addUtcMonths, entitlementFromLedger};
