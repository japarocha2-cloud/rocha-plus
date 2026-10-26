// Laboratory regression tests only. All transactions are synthetic and in memory.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createAccessService, DAY } from './service.mjs';

function fixture() {
  const accounts=new Map(),payments=new Map(),audit=[];
  let chain=Promise.resolve();
  let clock=Date.UTC(2026,9,26);
  let failCommit=false;
  const store={transact(uid,id,fn){
    const job=chain.then(async()=>{
      const a=new Map(structuredClone([...accounts]));
      const p=new Map(structuredClone([...payments]));
      const events=structuredClone(audit);
      const result=await fn({
        account:a.get(uid),payment:p.get(id),
        payments:[...p.values()].filter(item=>item.uid===uid),
        setAccount:item=>a.set(uid,item),
        setPayment:item=>p.set(id,item),
        audit:(kind,detail)=>events.push({kind,...detail}),
      });
      if(failCommit) throw new Error('simulated-commit-failure');
      accounts.clear();for(const [k,v] of a)accounts.set(k,v);
      payments.clear();for(const [k,v] of p)payments.set(k,v);
      audit.splice(0,audit.length,...events);
      return result;
    });
    chain=job.catch(()=>{});
    return job;
  }};
  const access=createAccessService({
    verifyToken:async token=>({uid:token==='admin'?'fixture-admin':'fixture-user',
      firebase:{sign_in_provider:'google.com'},rochaAdmin:token==='admin'}),
    store,now:()=>clock,
    plans:{monthly:{amountCents:450,days:30},annual:{amountCents:4950,days:365}},
  });
  const confirm=(id,plan='monthly')=>access({
    method:'POST',path:'/v1/admin/confirm',authorization:'Bearer admin',
    body:{uid:'fixture-user',provider:'mercadopago',transactionId:id,
      evidenceReference:'FAKE-ONLY',plan,
      amountCents:plan==='annual'?4950:450,currency:'BRL'},
  });
  const refund=id=>access({
    method:'POST',path:'/v1/admin/refund',authorization:'Bearer admin',
    body:{uid:'fixture-user',provider:'mercadopago',transactionId:id,
      evidenceReference:'FAKE-REFUND'},
  });
  const read=()=>access({method:'GET',path:'/v1/entitlement',
    authorization:'Bearer user'});
  return {confirm,refund,read,accounts,payments,audit,
    advance:days=>{clock+=days*DAY;},
    setFail:value=>{failCommit=value;},now:()=>clock};
}

test('failed atomic commit cannot leave account, payment or audit half-written',async()=>{
  const f=fixture();f.setFail(true);
  await assert.rejects(f.confirm('11'),/simulated-commit-failure/);
  assert.equal(f.payments.size,0);assert.equal(f.accounts.size,0);assert.equal(f.audit.length,0);
  f.setFail(false);
  const r=await f.confirm('11');
  assert.equal(r.duplicate,false);assert.equal(f.payments.size,1);assert.equal(f.audit.length,1);
});

test('refund racing with a retry never reinstates the reversed payment',async()=>{
  const f=fixture();await f.confirm('11');
  const outcomes=await Promise.allSettled([f.refund('11'),f.confirm('11')]);
  assert.equal(outcomes.length,2);
  assert.equal(f.payments.size,1);
  assert.equal([...f.payments.values()][0].status,'refunded');
  await assert.rejects(f.confirm('11'),error=>error.status===409);
  assert.equal((await f.read()).allowed,true); // original seven-day trial remains
  f.advance(7);
  assert.equal((await f.read()).allowed,false);
});

test('two independent payments survive one refund with no double credit',async()=>{
  const f=fixture();await f.confirm('11','monthly');await f.confirm('22','annual');
  assert.equal(f.payments.size,2);assert.equal(f.audit.length,2);
  await f.refund('11');
  assert.equal(f.payments.size,2);assert.equal(f.audit.length,3);
  assert.equal(Date.parse((await f.read()).expiresAt),f.now()+365*DAY);
  await f.refund('11');
  assert.equal(f.audit.length,3);
});
