'use strict';
// Shared server-side entitlement response validator. No device may grant access
// based on payment UI actions, cached booleans, or a client-provided expiration.
function validateAccessResponse(data, nowMs = Date.now()) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) return { allowed: false };
  if (!['trial', 'paid', 'expired'].includes(data.state) ||
      typeof data.active !== 'boolean' ||
      !Number.isSafeInteger(data.serverTime) ||
      !Number.isSafeInteger(data.accessUntil) ||
      !Number.isFinite(nowMs)) return { allowed: false };
  if (data.active !== (data.state !== 'expired')) return { allowed: false };
  if (!data.active || data.accessUntil <= data.serverTime) return { allowed: false };
  const durationMs = data.accessUntil - data.serverTime;
  if (durationMs > 366 * 86400000) return { allowed: false };
  // Lease prevents indefinite playback without rechecking server rights.
  return { allowed: true, leaseMs: Math.min(durationMs, 60000) };
}
module.exports = { validateAccessResponse };
