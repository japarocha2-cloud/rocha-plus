import test from 'node:test';
import assert from 'node:assert/strict';
import { founderRenewal as step } from './founder-sandbox.js';
const founder = { eligible: true, lost: false, canceled: false, priceCents: 5390 };
test('annual eligible renewal preserves original 5390 cents', () => assert.deepEqual(step(founder, 'renew'), founder));
test('cancellation does not remove benefit before expiry', () => assert.equal(step(founder, 'cancel').eligible, true));
test('canceled expiry and return permanently loses founder benefit', () => {
  const expired = step(step(founder, 'cancel'), 'expire');
  assert.equal(expired.lost, true); assert.equal(step(expired, 'return').eligible, false);
  assert.equal(step(expired, 'reactivate-before-expiry').eligible, false);
});
test('same subscription resumes before expiry without losing founder benefit', () => assert.equal(step(step(founder, 'cancel'), 'reactivate-before-expiry').eligible, true));
test('unresolved involuntary lapse and migration require review', () => {
  for (const event of ['expire','payment-failure','change-plan']) assert.equal(step(founder,event).reviewRequired, true);
});
