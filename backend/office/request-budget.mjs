// Process-wide protection before JSON parsing, Firebase calls or Firestore work.
// Does not trust forwarded IP headers. A shared gateway limit is still required
// across replicas; this deliberately uses constant memory under hostile traffic.
export function createRequestBudget({ now = Date.now, windowMs = 60_000,
  totalLimit = 600, pairingLimit = 60 } = {}) {
  for (const value of [windowMs, totalLimit, pairingLimit]) {
    if (!Number.isSafeInteger(value) || value <= 0) throw new TypeError('Positive request budget required');
  }
  let resetAt = 0;
  let total = 0;
  let pairing = 0;
  return path => {
    const time = now();
    if (!Number.isFinite(time)) return { allowed: false, retryAfter: 60 };
    if (time >= resetAt) {
      resetAt = time + windowMs;
      total = 0;
      pairing = 0;
    }
    const isPairing = path.startsWith('/v1/office/pair/');
    const retryAfter = Math.max(1, Math.ceil((resetAt - time) / 1000));
    if (total >= totalLimit || (isPairing && pairing >= pairingLimit)) {
      return { allowed: false, retryAfter };
    }
    total++;
    if (isPairing) pairing++;
    return { allowed: true };
  };
}
