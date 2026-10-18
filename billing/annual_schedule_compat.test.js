import test from 'node:test';
import assert from 'node:assert/strict';
import { checkedSchedule } from './recurring.js';

test('existing annual plan may use 1 year without changing the 55 BRL price', () => {
  assert.doesNotThrow(() => checkedSchedule({
    frequency_type: 'years', frequency: 1, currency_id: 'BRL', transaction_amount: 55,
  }, 'annual'));
});
test('annual plan still supports 12 months', () => {
  assert.doesNotThrow(() => checkedSchedule({
    frequency_type: 'months', frequency: 12, currency_id: 'BRL', transaction_amount: 55,
  }, 'annual'));
});
test('monthly must remain 1 month for 4.90 BRL', () => {
  assert.doesNotThrow(() => checkedSchedule({
    frequency_type: 'months', frequency: 1, currency_id: 'BRL', transaction_amount: 4.9,
  }, 'monthly'));
  assert.throws(() => checkedSchedule({
    frequency_type: 'years', frequency: 1, currency_id: 'BRL', transaction_amount: 4.9,
  }, 'monthly'));
});
test('reject a mismatched annual amount or recurrence', () => {
  assert.throws(() => checkedSchedule({
    frequency_type: 'years', frequency: 1, currency_id: 'BRL', transaction_amount: 4.9,
  }, 'annual'));
  assert.throws(() => checkedSchedule({
    frequency_type: 'years', frequency: 2, currency_id: 'BRL', transaction_amount: 55,
  }, 'annual'));
});
