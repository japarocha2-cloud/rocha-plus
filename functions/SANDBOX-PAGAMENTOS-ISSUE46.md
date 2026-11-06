# ROCHA+ TV — Pagamentos em sandbox isolado (Issue #46)

**Branch de implementação:** `fix/sandbox-payment-isolation-20261106`

## Isolamento de banco verificado em 06/11/2026
- Firestore já existente: `rocha-payments-test`, região `southamerica-east1`.
- Os três endpoints sandbox usam **exclusivamente** `getFirestore(admin.app(), 'rocha-payments-test')`. O banco `(default)` não é usado por esses endpoints.
- Cada endpoint sandbox define `serviceAccount: rocha-sandbox-payments@rocha-plus-homologacao.iam.gserviceaccount.com`.
- A conta de serviço recebeu `roles/secretmanager.secretAccessor` somente nos dois segredos sandbox; foi concedido `roles/datastore.user` com condição IAM `RochaSandboxPaymentsOnly` para `resource.name=='projects/rocha-plus-homologacao/databases/rocha-payments-test'`; a eficácia da condição ainda não foi verificada em execução.
- Antes do deploy, validar que o papel condicionado realmente permite operações no banco nomeado e não permite no `(default)`; não presumir que a presença da condição prova isolamento efetivo.
- O banco não foi criado nem modificado nesta etapa. Nenhum deploy autorizado.

## Procedimento preparado para deploy limitado — NÃO EXECUTAR SEM NOVA AUTORIZAÇÃO
**Escopo:** as funções `sandboxCheckout`, `sandboxPaymentVerify` e `sandboxPaymentWebhook` **somente** no projeto `rocha-plus-homologacao` e região `southamerica-east1`. Nada de merge, deploy comercial ou movimentação de dinheiro.

**Evidências:** o GitHub Actions (run `42257775278`) passou backend, entitlement, Android e Flutter. A conta `rocha-sandbox-payments` existe. Os dois segredos sandbox possuem versão 1 ativa e vínculos `secretAccessor` no nível dos segredos. Banco nomeado `rocha-payments-test` já existe. O Cloud Shell ainda não comprovou acesso efetivo pela conta de serviço; Policy Troubleshooter API desativada e endpoint de testIamPermissions do Firestore retornou 501.

**Pré-requisitos obrigatórios antes de autorizar o deploy:**
1. Confirmar SHA da branch e passar o CI no commit exato.
2. Confirmar que o projeto e conta selecionados no terminal são os autorizados.
3. Validar com fonte autorizada o ID do vendedor de teste, o token **sem exibi-lo**, a URL de webhook sandbox final e a assinatura do ambiente de teste (não confundir com webhook comercial).
4. Confirmar que o Firebase UID `6f5WMpl6ZbSprXE5R66SvWtFx2g1` corresponde à conta independente autorizada; sem tocar outros usuários.
5. Testar efetivamente que o papel condicionado limita a conta à base `rocha-payments-test`; NÃO conceder `roles/datastore.user` irrestrito. Se o teste requerer impersonação, pedir aprovação específica para concessão temporária e emissão de token antes de usá-los.
6. Revisar como o CLI Firebase resolve `functions` (o repositório não contém `firebase.json` nem `.firebaserc` na raiz da branch consultada); preparar manifesto local temporário e revisar diff/target. Não acionar deploy sem essa revisão.
7. Garantir variáveis apenas para os três endpoints sandbox: `ROCHA_SANDBOX_ENABLED`, `ROCHA_SANDBOX_TEST_UID`, `ROCHA_SANDBOX_MERCHANT_ID`, `ROCHA_SANDBOX_WEBHOOK_URL`. Verificar que o processo de deploy seletivo não atualiza funções existentes nem configura flags comerciais.
8. Confirmar que a identidade usada no deploy possui `iam.serviceAccounts.actAs` **somente onde necessário**, sem criar papéis novos automaticamente. Não conceder no planejamento.
9. Documentar mecanismo de reversão que apague apenas as funções sandbox comprovadamente novas e preserve os bancos e segredos.

**Comando de deploy previsto, MAS NÃO AUTORIZADO PARA EXECUTAR AINDA:**
```bash
firebase deploy --project rocha-plus-homologacao --only functions:sandboxCheckout,functions:sandboxPaymentVerify,functions:sandboxPaymentWebhook
```
O comando só é utilizável após confirmar manifesto Firebase, fonte/commit, variáveis, IAM e URL. Nenhum comando de deploy deve ser rodado só com este procedimento.

**Pós-deploy sujeito a aprovação futura:** testar HTTP não autenticado (401/405/503 esperado conforme gate), verificar identidade e banco de execução, habilitar sandbox apenas após validação; criar checkout com conta Firebase autorizada e comprador de teste Mercado Pago; reconciliar evento real em `sandbox_entitlements`; verificar integridade do banco padrão.

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
