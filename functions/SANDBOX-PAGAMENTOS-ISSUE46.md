# ROCHA+ TV — Pagamentos em sandbox isolado (Issue #46)

**Branch de implementação:** `fix/sandbox-payment-isolation-20261106`

## O que mudou
- `sandboxCheckout`: cria pedido somente em `sandbox_checkout_orders` após autenticar o Firebase UID autorizado; retorna exclusivamente `sandbox_init_point`.
- `sandboxPaymentWebhook`: recebe notificações **payment** assinadas, consulta o pagamento pela API do Mercado Pago, correlaciona com o pedido autenticado e grava apenas em `sandbox_payment_events`, `sandbox_entitlements` e inbox/locks de sandbox.
- `sandboxPaymentVerify`: permite verificar manualmente o pagamento sandbox de um único UID autorizado, sem depender de um POST de teste do provedor.
- Checkout, webhook e `entitlement` comerciais **continuam inalterados**. Pagamentos sandbox (`live_mode=false`) **nunca** geram `entitlements/{uid}.paidUntil`.

## Gates e segredos exigidos antes de qualquer implantação
Apenas no projeto isolado de homologação:
- `ROCHA_SANDBOX_ENABLED=true` (padrão: desativado)
- `ROCHA_SANDBOX_TEST_UID`: UID Firebase de conta de teste independente, não cliente.
- `ROCHA_SANDBOX_MERCHANT_ID`: ID da conta vendedora de testes, confirmado junto ao Mercado Pago.
- `ROCHA_SANDBOX_WEBHOOK_URL`: endereço HTTPS do **sandboxPaymentWebhook**, nunca o webhook comercial.
- `MP_SANDBOX_ACCESS_TOKEN` e `MP_SANDBOX_WEBHOOK_SECRET`: segredos separados das credenciais comerciais.

**Nunca usar credencial de produção, webhook de produção, cliente real, valores de cobrança reais ou usuários existentes nestes endpoints.** A configuração do Mercado Pago deve habilitar eventos **payment**, não apenas planos/assinaturas.

## Roteiro de homologação (não realizado)
1. Rodar `cd functions && npm test` com Node.js 22 e analisar CI/revisão.
2. Conferir permissões Firestore para impedir gravações de cliente em coleções `sandbox_*`; somente backend autorizado pode gravar.
3. Confirmar credenciais sandbox, UID permitido, ID da conta vendedora e URL de notificação em fonte autorizada.
4. Com aprovação específica para implantar apenas endpoints sandbox, configurar segredos, ambiente e fazer deploy limitado às três funções sandbox.
5. Autenticar a conta de teste, criar um checkout sandbox, usar cartão/conta de teste e identificar o pagamento de teste (sem dinheiro real).
6. Checar webhook sandbox `payment` e, se necessário, chamar `sandboxPaymentVerify` com o paymentId e Firebase ID token da conta de teste.
7. Validar `sandbox_entitlements/{testUid}.approved === true`; confirmar que `entitlements/{testUid}` e todos os documentos comerciais permaneceram inalterados.

**Critério de conclusão deste patch:** fluxo sandbox verificável e isolado, não liberação comercial. Um acesso do app de produção só pode ser concedido depois da homologação separada do fluxo real. Não mudar `ROCHA_CHECKOUT_ENABLED` ou `ROCHA_WEBHOOK_RECONCILIATION_ENABLED` nesta etapa.

## Limitações atuais
- Código criado em branch separada; **não implantado**, sem testes de integração com o provedor nesta sessão.
- Em ambientes de Mercado Pago que não emitem notificações para pagamentos sandbox, a verificação autenticada por ID permite testar a reconciliação isolada, mas não comprova entrega automática de webhook.
- O painel de notificações e as restrições de conta de teste precisam ser validados em testes reais antes de habilitar o recurso.
