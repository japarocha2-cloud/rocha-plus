import { MercadoPagoConfig, Payment, PreApproval, PreApprovalPlan, Invoice, WebhookSignatureValidator } from 'mercadopago';
export function createProvider({ accessToken, webhookSecret }) {
  const client = new MercadoPagoConfig({ accessToken, options: { timeout: 8000 } });
  const subscriptions = new PreApproval(client), invoices = new Invoice(client);
  async function pages(search, options) {
    const results = [];
    for (let offset = 0; offset < 200; offset += 50) {
      const result = await search({ options: { ...options, limit: 50, offset } });
      if (!Array.isArray(result.results) || !Number.isFinite(result.paging?.total)) throw new Error('provider-page');
      results.push(...result.results);
      if (offset + 50 >= result.paging.total) return results;
    }
    throw new Error('provider-limit');
  }
  return {
    subscription: id => subscriptions.get({ id }),
    async subscriptions(email, planIds) {
      const result = await Promise.all(Object.values(planIds).map(preapproval_plan_id =>
        pages(args => subscriptions.search(args), { payer_email: email, preapproval_plan_id })));
      return [...new Map(result.flat().map(item => [item.id, item])).values()];
    },
    plan: id => new PreApprovalPlan(client).get({ id }),
    invoice: id => invoices.get({ id }),
    invoices: preapproval_id => pages(args => invoices.search(args), { preapproval_id }),
    invoicesForPayment: payment_id => pages(args => invoices.search(args), { payment_id }),
    payment: id => new Payment(client).get({ id }),
    verifySignature: ({ dataId, signature, requestId }) => WebhookSignatureValidator.validate({
      dataId, xSignature: signature, xRequestId: requestId, secret: webhookSecret,
    }),
  };
}
