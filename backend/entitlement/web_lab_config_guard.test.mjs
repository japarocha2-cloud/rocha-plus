import test from 'node:test';
import assert from 'node:assert/strict';
import { validateLabWebConfig as validate } from './web_lab_config_guard.mjs';
const fixture = () => ({ projectId:'rocha-plus-homologacao',
  authDomain:'rocha-plus-homologacao.firebaseapp.com',
  appId:'1:123456789:web:abcd1234',apiKey:'AIza'+'A'.repeat(25) });
test('accepts format-only LAB metadata but never enables payments or subscriptions',()=>{
  const result=validate(fixture());
  assert.equal(result.validatedFormatOnly,true);
  assert.equal(result.checkoutEnabled,false);
  assert.equal(result.productionWritesEnabled,false);
  assert.equal(result.subscriptionLab,false);
});
test('rejects official Rocha+ Firebase configuration',()=>{
  assert.throws(()=>validate({...fixture(),projectId:'rocha-plus',authDomain:'rocha-plus.firebaseapp.com'}));
});
test('rejects attempts to activate subscription or point to a live entitlement endpoint',()=>{
  assert.throws(()=>validate(fixture(),{subscriptionLab:true}));
  assert.throws(()=>validate(fixture(),{entitlementUrl:'https://example.test/v1/entitlement'}));
});
test('rejects mismatched auth domain and incomplete app credentials',()=>{
  assert.throws(()=>validate({...fixture(),authDomain:'rocha-plus.firebaseapp.com'}));
  assert.throws(()=>validate({...fixture(),appId:''}));
  assert.throws(()=>validate({...fixture(),apiKey:''}));
});
