import { performance } from 'node:perf_hooks';
import { createBillingService } from './service.js';
import { accountId, productId } from './policy.js';

// No network, Firebase, Google credentials or production index imports.
// Timings and quotas below are explicit simulation inputs, not cloud measurements.
export async function runLoad({ users, playLatencyMs = 0, publisherBudget = Infinity, tokensPerUser = 1 }) {
  const now = Date.now(), latency = [];
  let calls = 0, rejected = 0, inflight = 0, peak = 0, incorrect = 0;
  const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
  const service = createBillingService({
    now: () => now,
    verifyIdentity: async uid => ({ uid }),
    store: {
      tokens: async uid => Array.from({ length: tokensPerUser }, (_, i) => uid + ':purchase:' + i),
      owner: async token => token.split(':')[0],
      claim: async () => { throw new Error('load test must never mutate purchases'); }
    },
    acknowledge: async () => { throw new Error('load test must never acknowledge purchases'); },
    readPlay: async token => {
      calls++;
      if (calls > publisherBudget) { rejected++; throw new Error('simulated-quota'); }
      if (playLatencyMs) await pause(playLatencyMs);
      const uid = token.split(':')[0];
      return {
        testPurchase: {},
        acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
        externalAccountIdentifiers: { obfuscatedExternalAccountId: accountId(uid) },
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        lineItems: [{ productId, offerDetails: { basePlanId: 'yearly' },
          expiryTime: new Date(now + 86400000).toISOString(),
          autoRenewingPlan: { autoRenewEnabled: true } }]
      };
    }
  });
  const started = performance.now(), statuses = {};
  await Promise.all(Array.from({ length: users }, async (_, index) => {
    const uid = 'user' + index, begin = performance.now();
    inflight++; peak = Math.max(peak, inflight);
    const account = await service.handle({ method: 'POST', authorization: 'Bearer ' + uid, body: { action: 'account' } });
    const result = await service.handle({ method: 'POST', authorization: 'Bearer ' + uid, body: { action: 'entitlement' } });
    inflight--;
    statuses[result.status] = (statuses[result.status] || 0) + 1;
    if (account.body.accountId !== accountId(uid) ||
      (result.status === 200 && (!result.body.active || result.body.basePlanId !== 'yearly'))) incorrect++;
    latency.push(performance.now() - begin);
  }));
  latency.sort((a, b) => a - b);
  const percentile = p => Math.round(latency[Math.min(latency.length - 1, Math.ceil(p * latency.length) - 1)] * 100) / 100;
  return { users, peakConcurrentVirtualUsers: peak, tokensPerUser, playLatencyMs,
    publisherBudget: Number.isFinite(publisherBudget) ? publisherBudget : 'unlimited-mock',
    requests: users * 2, statuses, publisherCalls: calls, simulatedQuotaRejections: rejected,
    incorrectResults: incorrect, elapsedMs: Math.round(performance.now() - started),
    latencyMs: { p50: percentile(.5), p95: percentile(.95), p99: percentile(.99), max: percentile(1) } };
}
