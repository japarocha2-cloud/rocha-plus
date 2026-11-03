# Auditoria e correção experimental — reconhecimento de pagamentos Rocha+

Data: 03/11/2026. Branch: `incident/payment-recognition-20261103`. Base revisada: `96e034cd10730604b1baf663c9b07e06325099c7`.

## Causa e limites da evidência

**Falha de arquitetura confirmada no código desta branch:** `functions/index.js` expõe apenas a consulta de direito; não havia export de webhook Mercado Pago. `functions/mercadopago_reconciliation.js` fazia GET canônico e mantinha registro de pagamento, enquanto `functions/reconcile_and_grant.js` era operação privilegiada desconectada do webhook. Portanto a aprovação não era projetada automaticamente por uma cadeia ativa nesse código.

**Causa específica em produção não confirmada:** esta sessão não tem conexão autorizada a Mercado Pago, Firebase, logs de Functions ou console de implantação. Não consultamos dados reais nem verificamos implantação/configuração/delivery do webhook. A relação pagamento↔UID por e-mail também não é prova suficiente: o grant existente exige claim revisado independentemente. A hipótese de falha do webhook em produção permanece pendente até leitura autorizada de configuração e logs.

## Correção isolada preparada

- Novo `functions/mercadopago_webhook.js`: verifica HMAC SHA-256 (`x-signature` + `x-request-id` + `data.id`), exige evento payment, valida consistência query/body e trata o callback apenas como sinal; o pagamento é buscado de novo na API canônica.
- Registro idempotente em `mercadoPagoWebhookInbox`, com estados processado, revisão necessária e falha transitória. Resposta não contém e-mail, UID, valor ou segredo.
- Somente chama o reconciliador privilegiado já existente, que exige claim previamente revisado, merchant/valor/moeda compatíveis e reavalia o ledger. Ausência de claim e divergências determinísticas vão para revisão; não concedem acesso. Payload do callback não controla status/valor.
- Export experimental `mercadoPagoWebhook` em Functions, com secrets nomeados `MP_RECEIVING_ACCESS_TOKEN` e `MP_WEBHOOK_SECRET`. Nenhum secret foi criado/configurado e nenhum endpoint implantado.
- Workflow `.github/workflows/incident-payment-webhook-fixtures.yml`: testes com fixtures somente, sem credenciais e sem etapa de deploy.

## Testes e plataformas

A suíte nova contém 10 cenários: assinatura válida/inválida, integridade dos IDs, ignorar status vindo do cliente, duplicidade, associação ausente, divergência para revisão, falha transitória e método/evento inválidos. As execuções iniciais falharam em ajustes do mock e do filtro do workflow; ambos foram corrigidos e os motivos registrados nos commits intermediários. [CI 41738187870](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41738187870), SHA `a2856a82abf905b868fb3248187f717ba206bfed`: sucesso, sintaxe válida, 45 testes aprovados e 0 falhas (10 testes novos do webhook incluídos). São fixtures sem secrets e não validam Mercado Pago/Firebase reais. Fixtures não são homologação de integração.

- Android celular: **NÃO COMPROVADO**; build default não habilita runtime central e nenhuma sessão real foi consultada.
- Android TV: **NÃO COMPROVADO**; compartilha Flutter/código de direitos com celular, mas não foi exercitada sessão real.
- Roku TV: **NÃO COMPROVADO**; REV2 carregado no BRS Desktop na etapa anterior, mas a integração de acesso permanece desativada. Nenhuma consulta ao backend compartilhado foi provada.
- Mercado Pago/Firebase reais, pagamentos, reprodução/áudio: **NÃO EXECUTADOS**.

Não declarar correção aprovada para as três plataformas. A convergência requer validar o backend e projeto usados por cada app, instalar/configurar a rota em homologação isolada, associar uma conta de teste por fluxo aprovado e confirmar a mesma leitura de entitlement em cada cliente. Nada disso aconteceu aqui.

## Próximo procedimento

1. Verificar workflow/commit verdes, sem usar secrets do Actions para consultas privadas.
2. Em projeto Firebase **de homologação confirmado**, configurar os secrets existentes por cofre aprovado, registrar URL de notificação no painel de integração Mercado Pago e validar assinatura/eventos via sandbox.
3. Criar claim de pagamento somente depois de revisão independente de proprietário/UID/plano/merchant/valor, sem mapear por e-mail isoladamente.
4. Executar casos sandbox de aprovado, duplicado, renovação, reembolso/chargeback, divergência e concorrência; verificar ledger + entitlement com transações idempotentes.
5. Validar as builds experimentais das três plataformas contra a MESMA API/coleção, com limites de dispositivos e duas reproduções. Nenhum ajuste de produção neste commit.
6. Antes de qualquer produção: consultar implantação e logs reais com conexão autorizada, mapear sessão afetada e apresentar plano de mudança; solicitar autorização explícita.

## Evidências e arquivos

- [Código do webhook](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/functions/mercadopago_webhook.js)
- [Integração Firebase experimental](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/functions/index.js)
- [Fixtures](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/functions/mercadopago_webhook.test.js)
- [Workflow](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/.github/workflows/incident-payment-webhook-fixtures.yml)
- [Reconciliador com claim revisado](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/functions/reconcile_and_grant.js)
- [Regras de períodos](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/functions/entitlement_periods.js)
- [Direitos centrais Android](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/docs/central-rights/README.md)

Este relatório é registro técnico experimental. Não contém credenciais nem dados pessoais de clientes.
