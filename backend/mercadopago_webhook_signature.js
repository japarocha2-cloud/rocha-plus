'use strict';
const crypto = require('node:crypto');

/**
 * Validates Mercado Pago HMAC signature for a webhook notification.
 * dataId MUST come from the URL query parameter data.id, not JSON body.
 * Caller must still fetch the resource from Mercado Pago using server-side credentials.
 */
function verifyWebhookSignature({ secret, signature, requestId, dataId, now = Date.now(), maxAgeMs = 5 * 60 * 1000 }) {
  if (typeof secret !== 'string' || !secret ||
      typeof signature !== 'string' || typeof requestId !== 'string' || !requestId ||
      typeof dataId !== 'string' || !dataId) return false;
  const entries = signature.split(',').map(entry => entry.trim().split('='));
  const values = new Map(entries.filter(parts => parts.length === 2));
  const ts = values.get('ts');
  const v1 = values.get('v1');
  if (!ts || !/^[0-9]{12,16}$/.test(ts) || !v1 || !/^[a-fA-F0-9]{64}$/.test(v1)) return false;
  const timestamp = Number(ts);
  if (!Number.isSafeInteger(timestamp) || !Number.isFinite(now) ||
      Math.abs(now - timestamp) > maxAgeMs) return false;
  const manifest = `id:${dataId.toLowerCase()};request-id:${requestId};ts:${ts};`;
  const expected = crypto.createHmac('sha256', secret).update(manifest).digest();
  return crypto.timingSafeEqual(expected, Buffer.from(v1, 'hex'));
}
module.exports = { verifyWebhookSignature };
