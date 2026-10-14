import { access, addMonths, PLANS } from './policy.js';
import { checkedPlan, checkedSubscription, checkedRecurringPayment, LINKS,
  normalizeEmail, recurringStatus, subscriptionIdValid } from './recurring.js';
export function createRecurringService({ store, provider, verifyIdentity, verifySignature,
  collectorId, planIds, liveMode = false, paymentsEnabled = false, now = Date.now }) {
  const config = time => ({ collectorId, planIds, liveMode, now: time });
  const configured = () => collectorId && Object.keys(PLANS).every(p => subscriptionIdValid(planIds?.[p]))
    && planIds.monthly !== planIds.annual;
  async function applyInvoices(subscription, owner, time, invoices) {
    const relevant = invoices.filter(item => {
      const debit = Date.parse(item.debit_date);
      return !Number.isFinite(debit) || addMonths(debit, PLANS[subscription.plan].months) > time;
    });
    if (relevant.length > 10) throw new Error('invoice-limit');
    for (const item of relevant) {
      if (!/^\d{1,30}$/.test(String(item.id))) throw new Error('invoice-id');
      const invoice = await provider.invoice(String(item.id));
      if (String(invoice.id) !== String(item.id) || invoice.preapproval_id !== subscription.id) {
        throw new Error('invoice-resource');
      }
      if (!invoice.payment?.id) continue;
      const paymentId = String(invoice.payment.id);
      if (!/^\d{1,30}$/.test(paymentId)) throw new Error('payment-id');
      const payment = await provider.payment(paymentId);
      if (String(payment.id) !== paymentId) throw new Error('payment-resource');
      await store.apply({ id: subscription.id, uid: owner.uid, plan: subscription.plan }, paymentId,
        checkedRecurringPayment(invoice, payment, subscription, config(time)), time);
    }
  }
  async function syncKnown(value, owner, time, invoices) {
    const subscription = checkedSubscription(value, config(time));
    if (owner.plan !== subscription.plan || owner.payerId !== subscription.payerId) throw new Error('subscription-changed');
    await store.bindSubscription(owner.uid, subscription, time);
    await applyInvoices(subscription, owner, time, invoices ?? await provider.invoices(subscription.id));
    return subscription;
  }
  async function reconcile(uid, email, time) {
    const user = await store.user(uid, time, email || null);
    // Refresh previously linked records even if the user changed their Google email.
    const linked = Object.values(user.subscriptions ?? {});
    for (const old of linked) {
      const value = await provider.subscription(old.id);
      if (value.id !== old.id) throw new Error('subscription-resource');
      await syncKnown(value, { uid, plan: old.plan, payerId: old.payerId }, time);
    }
    if (email) {
      const results = await provider.subscriptions(email, planIds);
      for (const item of results) {
        if (linked.some(old => old.id === item.id)) continue;
        if (!subscriptionIdValid(item.id)) throw new Error('subscription-id');
        const value = await provider.subscription(item.id);
        if (value.id !== item.id) throw new Error('subscription-resource');
        const subscription = checkedSubscription(value, config(time));
        if (!subscription.email || subscription.email !== email) continue;
        // A free-text reference belonging to another integration is not auto-claimed.
        if (value.external_reference != null && value.external_reference !== '') continue;
        await store.bindSubscription(uid, subscription, time);
        await applyInvoices(subscription, { uid }, time, await provider.invoices(subscription.id));
      }
    }
    return store.user(uid, time, email || null);
  }
  async function handle({ method, authorization, body }) {
    if (method !== 'POST') return { status: 405, body: { error: 'method' } };
    const token = /^Bearer (\S+)$/.exec(authorization ?? '')?.[1];
    if (!token) return { status: 401, body: { error: 'auth' } };
    let identity;
    try { identity = await verifyIdentity(token, true); } catch (_) { return { status: 401, body: { error: 'auth' } }; }
    if (!identity?.uid) return { status: 401, body: { error: 'auth' } };
    if (!['status', 'checkout', 'claimTrialWelcomeNotice'].includes(body?.action)) return { status: 400, body: { error: 'action' } };
    if (body.action === 'checkout' && !Object.hasOwn(PLANS, body.plan)) return { status: 400, body: { error: 'plan' } };
    if (!configured()) return { status: 503, body: { error: 'subscriptions-not-configured' } };
    const email = identity.email_verified === true ? normalizeEmail(identity.email) : '';
    try {
      const time = now();
      const user = await reconcile(identity.uid, email, time);
      if (body.action === 'status') return { status: 200, body: recurringStatus(user, access(user, time)) };
      if (body.action === 'claimTrialWelcomeNotice') return { status: 200,
        body: { showNotice: await store.claimTrialWelcomeNotice(identity.uid, time) } };
      if (!paymentsEnabled) return { status: 503, body: { error: 'payments-not-configured' } };
      if (!email) return { status: 403, body: { error: 'verified-email-required' } };
      if (Object.values(user.subscriptions ?? {}).some(s => s.status === 'authorized' || s.status === 'pending')) {
        return { status: 409, body: { error: 'subscription-already-linked' } };
      }
      // Read-only verification of the EXISTING plan. No new plan, card or charge is created.
      checkedPlan(await provider.plan(planIds[body.plan]), body.plan, config(time));
      return { status: 200, body: { checkoutUrl: LINKS[body.plan], automaticRenewal: true } };
    } catch (_) { return { status: 503, body: { error: 'subscription-unavailable' } }; }
  }
  async function webhook({ method, dataId, body, signature, requestId }) {
    const topic = body?.type;
    const validId = topic === 'subscription_preapproval' ? subscriptionIdValid(dataId) : /^\d{1,30}$/.test(dataId ?? '');
    if (method !== 'POST') return { status: 405, body: { error: 'method' } };
    if (!['subscription_preapproval', 'subscription_authorized_payment', 'payment'].includes(topic) ||
        !validId || String(body.data?.id) !== dataId) return { status: 400, body: { error: 'notification' } };
    try { verifySignature({ dataId, signature, requestId }); }
    catch (_) { return { status: 401, body: { error: 'signature' } }; }
    if (!configured()) return { status: 503, body: { error: 'subscriptions-not-configured' } };
    try {
      const time = now();
      let invoices;
      if (topic === 'subscription_authorized_payment') {
        const invoice = await provider.invoice(dataId);
        if (String(invoice.id) !== dataId) throw new Error('invoice-resource');
        invoices = [invoice];
      } else if (topic === 'payment') {
        invoices = await provider.invoicesForPayment(dataId);
      }
      const ids = topic === 'subscription_preapproval' ? [dataId]
        : [...new Set(invoices.map(i => i.preapproval_id))];
      for (const id of ids) {
        if (!subscriptionIdValid(id)) throw new Error('subscription-id');
        const owner = await store.subscriptionOwner(id);
        // Unbound subscriptions are reconciled through verified login, never guessed from a callback.
        if (!owner) continue;
        const value = await provider.subscription(id);
        if (value.id !== id) throw new Error('subscription-resource');
        await syncKnown(value, owner, time, invoices?.filter(i => i.preapproval_id === id));
      }
      return { status: 200, body: { received: true } };
    } catch (_) { return { status: 503, body: { error: 'notification-unavailable' } }; }
  }
  return { handle, webhook };
}
