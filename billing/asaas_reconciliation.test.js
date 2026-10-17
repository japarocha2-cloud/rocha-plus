import test from 'node:test';
import assert from 'node:assert/strict';
import { createAsaasReconciliation } from './asaas_reconciliation.js';
import { checkedAsaasPayment } from './asaas_policy.js';
import { fixture, time, token, hash } from './asaas_test_helpers.js';
const user = f => f.db.data.get('rochaAsaasSandboxUsers/' + hash(f.binding.uid));
const decision = f => checkedAsaasPayment({ payment: f.payment, subscription: f.subscription,
  binding: f.binding, now: time });

test('unbound payment cannot claim an account or call provider by matching payload email', async () => {
  const f = fixture(); const before = structuredClone(f.db.data);
  f.event.payment.email = 'owner@example.com'; f.event.payment.uid = 'A';
  assert.equal((await f.run()).status, 200);
  assert.deepEqual(f.db.data, before); assert.equal(f.calls.length, 0);
});
test('authenticated webhook re-fetches payment and subscription and persists a sandbox cycle', async () => {
  const f = fixture(); await f.store.bindPayment(f.binding);
  assert.equal((await f.run()).status, 200);
  assert.equal(f.calls.length, 2); assert.equal(user(f).paidUntil, f.binding.periodEnd);
});
test('forged paid payload cannot override provider pending status, amount or account', async () => {
  const f = fixture(); await f.store.bindPayment(f.binding); f.payment.status = 'PENDING';
  f.event.payment = { ...f.payment, status: 'RECEIVED', value: 550, customer: 'cus_other' };
  assert.equal((await f.run()).status, 200); assert.equal(user(f).paidUntil, null);
});
test('default-disabled and production settings cannot call API or write records', async () => {
  const f = fixture();
  for (const config of [{}, { enabled: true, provider: { ...f.provider, environment: 'production' } },
    { enabled: true, store: { ...f.store, environment: 'production' } }]) {
    const service = createAsaasReconciliation({ provider: f.provider, store: f.store, ...config });
    assert.equal((await service.webhook({ method: 'POST', token, body: f.event })).status, 503);
  }
  assert.equal(f.calls.length, 0); assert.equal(f.db.data.size, 3);
});
test('wrong token, wrong method and malformed events cannot touch provider or ledger', async () => {
  const f = fixture();
  for (const [req, code] of [
    [{ method: 'GET', token, body: f.event }, 405],
    [{ method: 'POST', token: 'wrong', body: f.event }, 401],
    [{ method: 'POST', token, body: { ...f.event, id: '../bad' } }, 400],
    [{ method: 'POST', token, body: { ...f.event, payment: { id: 'pay_x/y' } } }, 400],
  ]) assert.equal((await f.service.webhook(req)).status, code);
  assert.equal(f.calls.length, 0); assert.equal(f.db.data.size, 3);
});
test('checkout redirect and subscription event do not unlock a payment', async () => {
  const f = fixture(); await f.store.bindPayment(f.binding);
  assert.equal((await f.run({ id: 'evt_checkout', event: 'CHECKOUT_PAID' })).status, 200);
  assert.equal(f.calls.length, 0); assert.equal(user(f), undefined);
});
test('parallel redelivery produces one event and does not add another month', async () => {
  const f = fixture(); await f.store.bindPayment(f.binding);
  const replies = await Promise.all([f.run(), f.run(), f.run()]);
  assert.ok(replies.every(r => r.status === 200));
  assert.equal(user(f).paidUntil, f.binding.periodEnd);
  assert.equal([...f.db.data.keys()].filter(k => k.startsWith('rochaAsaasSandboxEvents/')).length, 1);
});
test('separate confirmed/received events for the same payment never extend validity', async () => {
  const f = fixture(); await f.store.bindPayment(f.binding); await f.run();
  f.payment.status = 'RECEIVED';
  await f.run({ ...f.event, id: 'evt_received', event: 'PAYMENT_RECEIVED' });
  assert.equal(user(f).paidUntil, f.binding.periodEnd);
  assert.equal(Object.keys(user(f).payments).length, 1);
});
test('refund revokes sandbox validity and stale paid snapshot cannot restore it', async () => {
  const f = fixture(); await f.store.bindPayment(f.binding); const stale = decision(f); await f.run();
  f.payment.status = 'REFUNDED';
  await f.run({ ...f.event, id: 'evt_refund', event: 'PAYMENT_REFUNDED' });
  assert.equal(user(f).paidUntil, null);
  await f.store.record({ eventId: 'evt_stale', decision: stale, now: time });
  assert.equal(user(f).paidUntil, null);
  assert.equal(Object.values(user(f).payments)[0].status, 'revoked');
});
test('stale pending snapshot cannot erase a confirmed cycle', async () => {
  const f = fixture(); await f.store.bindPayment(f.binding); f.payment.status = 'PENDING';
  const stale = decision(f); f.payment.status = 'CONFIRMED'; await f.run();
  await f.store.record({ eventId: 'evt_stale_pending', decision: stale, now: time });
  assert.equal(user(f).paidUntil, f.binding.periodEnd);
});
test('renewal and refund recalculate validity without deleting another paid cycle', async () => {
  const f = fixture(); await f.store.bindPayment(f.binding); await f.run();
  const second = { ...f.binding, paymentId: 'pay_test2', dueDate: '2026-11-15',
    periodStart: f.binding.periodEnd, periodEnd: Date.parse('2026-12-15T00:00:00Z') };
  await f.store.bindPayment(second);
  const later = Date.parse('2026-11-16T00:00:00Z');
  const paid = { ...decision(f), paymentId: second.paymentId, periodStart: second.periodStart,
    periodEnd: second.periodEnd, current: true };
  await f.store.record({ eventId: 'evt_renewal', decision: paid, now: later });
  await f.store.record({ eventId: 'evt_old_refund', decision: { ...decision(f), status: 'revoked' }, now: later });
  assert.equal(user(f).paidUntil, second.periodEnd);
});
test('binding cannot change owner, price or calendar period, and retries ignore field order', async () => {
  const f = fixture(); await f.store.bindPayment(f.binding);
  await f.store.bindPayment(Object.fromEntries(Object.entries(f.binding).reverse()));
  for (const change of [{ uid: 'B' }, { amountCents: 1 }, { periodEnd: time }]) {
    await assert.rejects(f.store.bindPayment({ ...f.binding, ...change }));
  }
});
test('an event cannot be replayed for a different bound payment', async () => {
  const f = fixture(); await f.store.bindPayment(f.binding); await f.run();
  const other = { ...f.binding, paymentId: 'pay_test2', uid: 'B' }; await f.store.bindPayment(other);
  await assert.rejects(f.store.record({ eventId: f.event.id,
    decision: { ...decision(f), paymentId: other.paymentId, uid: 'B' }, now: time }));
  assert.equal(f.db.data.get('rochaAsaasSandboxUsers/' + hash('B')), undefined);
});
test('invalid API resource returns retryable failure without partial ledger writes', async () => {
  const f = fixture(); await f.store.bindPayment(f.binding); const before = structuredClone(f.db.data);
  f.payment.customer = 'cus_other';
  assert.equal((await f.run()).status, 503); assert.deepEqual(f.db.data, before);
});
test('sandbox processing never changes production access, trial, favorites or Mercado Pago', async () => {
  const f = fixture(); const before = structuredClone(f.db.data);
  await f.store.bindPayment(f.binding); await f.run(); f.payment.status = 'REFUNDED';
  await f.run({ ...f.event, id: 'evt_refund', event: 'PAYMENT_REFUNDED' });
  for (const [path, value] of before) assert.deepEqual(f.db.data.get(path), value);
  for (const path of f.db.data.keys()) {
    if (!before.has(path)) assert.match(path, /^rochaAsaasSandbox(Bindings|Events|Users)\//);
  }
});
