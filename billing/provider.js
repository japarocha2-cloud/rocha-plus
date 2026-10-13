import { MercadoPagoConfig, Payment, Preference, WebhookSignatureValidator } from 'mercadopago';
export function createProvider({ accessToken, webhookSecret, notificationsUrl, liveMode }) {
  const client = new MercadoPagoConfig({ accessToken, options: { timeout: 8000 } });
  return {
    async checkout(order, plan) {
      const uri = new URL(notificationsUrl);
      if (uri.protocol !== 'https:' || uri.username || uri.password) throw new Error('webhook-url');
      const result = await new Preference(client).create({
        body: {
          items: [{ id: 'rocha_plus_' + order.plan, title: plan.title,
            quantity: 1, currency_id: 'BRL', unit_price: plan.cents / 100 }],
          external_reference: order.id,
          notification_url: notificationsUrl,
          metadata: { application: 'rocha_plus', order_id: order.id },
        },
        requestOptions: { idempotencyKey: order.id },
      });
      return liveMode ? result.init_point : result.sandbox_init_point;
    },
    payment: id => new Payment(client).get({ id }),
    verifySignature: ({ dataId, signature, requestId }) => WebhookSignatureValidator.validate({
      dataId, xSignature: signature, xRequestId: requestId, secret: webhookSecret,
    }),
  };
}
