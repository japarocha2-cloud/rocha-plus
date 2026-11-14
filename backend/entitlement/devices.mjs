import { randomUUID } from 'node:crypto';
import { AccessError, recordKey } from './service.mjs';

/**
 * Device and concurrent-playback limits. Server-owned: the UID always comes from
 * the verified token, never from the request body.
 *
 * Commercial plan (2026-11): one phone, two TVs, two simultaneous streams.
 * A stream is a short lease renewed by heartbeat, so a crashed or offline
 * player frees its slot automatically when the lease expires.
 */
// removalsPer30Days caps device swaps so one account cannot be lent out by
// rotating devices (value pending commercial confirmation).
export const DEFAULT_LIMITS = Object.freeze({
  phone: 1, tv: 2, streams: 2, leaseMs: 90_000, removalsPer30Days: 3,
});
const SWAP_WINDOW_MS = 30 * 86_400_000;
export const DEVICE_ROUTES = new Set([
  '/v1/devices/register', '/v1/devices/remove',
  '/v1/streams/start', '/v1/streams/heartbeat', '/v1/streams/stop',
]);

const fail = (status, message) => { throw new AccessError(status, message); };
// Client-generated install ID (random, 16-128 safe chars). Stored only as a hash.
const DEVICE_ID = /^[A-Za-z0-9_-]{16,128}$/;
const STREAM_ID = /^[0-9a-f-]{36}$/;

export function validateLimits(limits) {
  const merged = { ...DEFAULT_LIMITS, ...limits };
  for (const key of ['phone', 'tv', 'streams', 'removalsPer30Days']) {
    if (!Number.isSafeInteger(merged[key]) || merged[key] < 1 || merged[key] > 10) {
      throw new Error(`Invalid device limit: ${key}`);
    }
  }
  if (!Number.isSafeInteger(merged.leaseMs) || merged.leaseMs < 15_000 || merged.leaseMs > 600_000) {
    throw new Error('Invalid stream lease');
  }
  return Object.freeze(merged);
}

function deviceKey(body) {
  if (typeof body.deviceId !== 'string' || !DEVICE_ID.test(body.deviceId)) fail(400, 'Invalid device');
  return recordKey(body.deviceId);
}

const active = (sessions, nowMs) => sessions.streams.filter(s => s.expiresAtMs > nowMs);

/**
 * Applies one device/stream request inside an already-open store transaction.
 * `allowed` is the entitlement decision computed in the same transaction.
 */
export function handleDeviceRoute({ path, body, nowMs, allowed, state, limits }) {
  const sessions = structuredClone(state.sessions ?? { devices: [], streams: [] });
  // Only removals inside the rolling window are kept (bounded document size).
  sessions.removals = (sessions.removals ?? []).filter(atMs => atMs > nowMs - SWAP_WINDOW_MS);
  // Expired leases never count and are dropped on every write.
  sessions.streams = active(sessions, nowMs);
  const save = result => { state.setSessions(sessions); return result; };

  if (path === '/v1/devices/register') {
    if (body.kind !== 'phone' && body.kind !== 'tv') fail(400, 'Invalid device kind');
    const id = deviceKey(body);
    const known = sessions.devices.find(d => d.id === id);
    if (known) {
      if (known.kind !== body.kind) fail(409, 'Device already registered with another kind');
      known.lastSeenAtMs = nowMs;
      return save({ registered: true, duplicate: true, kind: known.kind });
    }
    const sameKind = sessions.devices.filter(d => d.kind === body.kind).length;
    if (sameKind >= limits[body.kind]) {
      fail(409, body.kind === 'phone' ? 'Phone limit reached' : 'TV limit reached');
    }
    sessions.devices.push({ id, kind: body.kind, registeredAtMs: nowMs, lastSeenAtMs: nowMs });
    return save({ registered: true, duplicate: false, kind: body.kind });
  }

  if (path === '/v1/devices/remove') {
    const id = deviceKey(body);
    if (!sessions.devices.some(d => d.id === id)) return save({ removed: false });
    if (sessions.removals.length >= limits.removalsPer30Days) fail(429, 'Device change limit reached');
    sessions.devices = sessions.devices.filter(d => d.id !== id);
    sessions.streams = sessions.streams.filter(s => s.deviceId !== id);
    sessions.removals.push(nowMs);
    return save({ removed: true });
  }

  if (path === '/v1/streams/stop') {
    if (typeof body.streamId !== 'string' || !STREAM_ID.test(body.streamId)) fail(400, 'Invalid stream');
    sessions.streams = sessions.streams.filter(s => s.id !== body.streamId);
    return save({ stopped: true });
  }

  // start / heartbeat: playback needs a current entitlement and a registered device.
  if (!allowed) fail(403, 'Entitlement required');
  const id = deviceKey(body);
  if (!sessions.devices.some(d => d.id === id)) fail(403, 'Device not registered');
  const expiresAtMs = nowMs + limits.leaseMs;

  if (path === '/v1/streams/heartbeat') {
    const stream = sessions.streams.find(s => s.id === body.streamId && s.deviceId === id);
    if (!stream) fail(409, 'Stream lease expired');
    stream.expiresAtMs = expiresAtMs;
    return save({ streamId: stream.id, expiresAt: new Date(expiresAtMs).toISOString() });
  }

  // /v1/streams/start — one lease per device; restarting on the same device reuses it.
  let stream = sessions.streams.find(s => s.deviceId === id);
  if (!stream) {
    if (sessions.streams.length >= limits.streams) fail(409, 'Concurrent stream limit reached');
    stream = { id: randomUUID(), deviceId: id, startedAtMs: nowMs, expiresAtMs };
    sessions.streams.push(stream);
  }
  stream.expiresAtMs = expiresAtMs;
  return save({ streamId: stream.id, expiresAt: new Date(expiresAtMs).toISOString(),
    leaseSeconds: limits.leaseMs / 1000 });
}
