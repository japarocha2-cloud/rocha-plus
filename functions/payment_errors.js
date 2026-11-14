'use strict';
// Stable codes for payment reconciliation outcomes. The webhook classifies by
// code, so rewording an error message cannot silently change provider retries.
function codedError(code, message) {
  const error = new Error(message);
  error.code = code;
  return error;
}
// Claim or trial not there YET (e.g. approved before the checkout claim): retry.
const WAIT_FOR_ASSOCIATION = new Set(['CLAIM_MISSING', 'TRIAL_MISSING']);
// Data conflicts that need a person: park, acknowledge, never retry blindly.
const NEEDS_REVIEW = new Set(['CLAIM_MISMATCH', 'OWNERSHIP_CONFLICT', 'LEDGER_MISMATCH']);
module.exports = {codedError, WAIT_FOR_ASSOCIATION, NEEDS_REVIEW};
