# Auditoria e correção experimental — reconhecimento de pagamentos Rocha+

Data: 03/11/2026. Branch: `incident/payment-recognition-20261103`. Base revisada: `96e034cd10730604b1baf663c9b07e06325099c7`.

## Causa e limites da evidência

**Falha de arquitetura confirmada no código desta branch:** `functions/index.js` expõe apenas a consulta de direito; não havia export de webhook Mercado Pago. `functions/mercadopago_reconciliation.js` fazia GET canônico e mantinha registro de pagamento, enquanto `functions/reconcile_and_grant.js` era operação privilegiada desconectada do webhook. Portanto a aprovação não era projetada automaticamente por uma cadeia ativa nesse código.

**Causa específica em produção não confirmada:** esta sessão não tem conexão autorizada a Mercado Pago, Firebase, logs de Functions ou console de implantação. Não consultamos dados reais nem verificamos implantação/configuração/delivery do webhook. A relação pagamento↔UID por e-mail também não é prova suficiente: o grant existente exige claim revisado independentemente. A hipótese de falha do webhook em produção permanece pendente até leitura autorizada de configuração e logs.

## Bloqueio de convergência entre backends

O repositório também contém a recuperação Spark em `backend/entitlement/regular_payment_recovery.mjs`, que projeta `rochaSparkAccounts/{Google subject}`; a Functions `reconcile_and_grant.js` atualiza `entitlements/{Firebase UID}`. São coleções/identificadores diferentes. O webhook experimental desta branch chama apenas `reconcileAndGrant`, portanto **não restaura um cliente que efetivamente usa a projeção Spark**. A documentação histórica associa um build Android 538 ao Spark, mas não prova qual APK/sessão está instalada agora. Roku 0.6.10 REV2 permanece com acesso desativado.

Antes de homologar este webhook ou desenhar a projeção Spark, é obrigatório confirmar versão instalada, token/sessão da própria instalação via procedimento privado autorizado e endpoint/projeto efetivamente consultado. Não gravar nas duas coleções para “desbloquear”; escolher uma fonte de verdade após prova. Também não está demonstrado que o mensal do caso afetado tenha claim revisado em `payment_claims`.

## Rastreio por plataforma e backend efetivamente selecionado pelo código

| Plataforma | Roteamento no código | O que falta para identificar a build ativa |
|---|---|---|
| Android celular | `lib/src/auth/subscription_access.dart`: com `ROCHA_CENTRAL_RIGHTS=true`, chama `CentralRightsRuntime`; caso contrário faz GET HTTPS em `ROCHA_ENTITLEMENT_URL` com Firebase ID token e UID atual. `central_rights_runtime.dart` usa `ROCHA_CENTRAL_RIGHTS_URL` e Firebase ID token. Padrão do runtime central é false. | Os valores `--dart-define`, hash/versionCode do APK instalado e resposta da sessão não estão disponíveis. Portanto o backend usado pelo APK da cliente não está provado. |
| Android TV | Mesmo Flutter e mesma classe `SubscriptionAccess`; sem flag central usa o mesmo endpoint por build e UID Firebase; com flag, role tv e endpoint central. | Não há build/runtime Android TV identificado nesta sessão. O código compartilhado não prova que as configurações de celular/TV sejam iguais. |
| Roku TV | Na branch LAB 0.6.10, `config/auth.json`, `config/lab-access.json` e `config/central-access.json` estão desativados e com endpoint vazio. Logo essa REV2 não consulta nenhum desses backends para liberar direitos. | Login/integração central da Roku não foi ativado. Sessão no BRS confirmou pacote/versão, não leitura de entitlement. |

A endpoint de entitlement em `functions/index.js` verifica Firebase ID token e usa `entitlements/{Firebase UID}`; a consulta inicializa trial se o documento não existir. A recuperação Spark em `backend/entitlement/regular_payment_recovery.mjs` lê/projeta `rochaSparkAccounts/{Google subject}`, não a coleção anterior. São caminhos distintos, e nenhuma configuração presente permite afirmar qual é o sistema operacional usado pela cliente. Nenhuma gravação deve ser feita até identificar o build, projeto, endpoint e identidade da sessão.

Fontes: [SubscriptionAccess Android](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/lib/src/auth/subscription_access.dart), [runtime central Android](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/lib/src/auth/central_rights_runtime.dart), [recovery Spark](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/backend/entitlement/regular_payment_recovery.mjs), [config de acesso Roku LAB 0.6.10](https://github.com/japarocha2-cloud/rocha-plus/blob/lab/roku-0.6.10-google-activation-admin-20261103/platforms/roku-lab-visual/config/central-access.json), [conta Roku](https://github.com/japarocha2-cloud/rocha-plus/blob/lab/roku-0.6.10-google-activation-admin-20261103/platforms/roku-lab-visual/config/auth.json).

## Acesso privado e procedimento operacional

Não há nesta sessão conexão privada autorizada com Mercado Pago, Firebase Auth/Firestore nem logs de Functions. Não foi feita consulta real. A [instrução do executor privado](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/docs/incident/20261103-operational-executor/README.md) registra que bindings existentes necessários são `FIREBASE_SERVICE_ACCOUNT_JSON`, `MP_RECEIVING_ACCESS_TOKEN`, `INCIDENT_TARGET_EMAIL`, `INCIDENT_PAYMENT_IDS_JSON` e `EXPECTED_RECEIVING_MERCHANT_ID`; devem ser injetados pelo cofre em host já autorizado, sem compartilhar os valores, exportar secrets do GitHub Actions ou criar chaves/IAM.

No host privado autorizado, com Node 22, checkout completo e bindings montados pelo cofre, executar somente a leitura já preparada:

```sh
cd /CAMINHO_PRIVADO/rocha-plus
git fetch origin incident/payment-recognition-20261103
git checkout --detach 6f1720c11df0d6cf19b89ffc7ec72b87edf58590
(cd backend/entitlement && npm ci --ignore-scripts --no-audit --no-fund)
umask 077
export ROCHA_PRIVATE_REPORT_DIR="$(mktemp -d /tmp/rocha-monthly-readiness.XXXXXX)"
node backend/entitlement/diagnostics/incident_session_readiness.mjs
```

O script gera relatórios privados de readiness/before-images; não aplica mudanças. Deve ser executado pelo operador com acesso já autorizado. As variáveis não devem ser impressas, enviadas ao chat, nem anexadas a artifacts. Logs de Functions precisam ser consultados separadamente por observabilidade com permissão já existente; não repetir consultas 403.

## Vinculação e recuperação sem concessão por e-mail

O reconciliador aceita apenas `payment_claims/{paymentId}` com UID/plano e revisão independente. A prova adequada deve combinar GET canônico do recibo, conta recebedora/merchant, estado aprovado/accredited, moeda/valor/reembolso e referência de compra confiável quando existente com autenticação da conta Rocha+ pelo UID/subject da própria sessão. E-mail coincidente, captura isolada ou payload webhook não bastam. Para pagamento histórico sem vínculo confiável, operador autorizado revisa evidência original e registra claim em processo privado auditado; se a associação não puder ser provada, permanece em revisão sem direito.

## Revisão de idempotência e pendências do webhook

A implementação nesta branch usa HMAC e a consulta canônica já existente. A repetição sequencial é deduplicada. A revisão corrente acrescenta lock/lease por payment ID para serializar notificações simultâneas; falhas transitórias liberam/reprocessam via 503, e leases abandonados podem ser retomados após expiração. Renovação usa um payment ID por ciclo; reconciliador recalcula o ledger em vez de somar períodos. Reembolso/estorno do provedor atualiza o evento e recálculo pode remover o período correspondente. Fixtures existentes de reconciliador cobrem replay/refund; novos fixtures cobrem corrida/retry do webhook. Revisão de projeto e comportamento real em Firestore emulator/sandbox ainda pendente.

Notificações sem claim recebem 200 com `review_required`, para evitar retries inúteis do provedor; não há worker automático implementado. Depois de revisão do vínculo, reprocessar por executor privado autorizado ou implementar job de reconciliação controlado. Não marcar esse fluxo como plenamente automático até haver retomada durável monitorada.

## Correção isolada preparada

- Novo `functions/mercadopago_webhook.js`: verifica HMAC SHA-256 (`x-signature` + `x-request-id` + `data.id`), exige evento payment, valida consistência query/body e trata o callback apenas como sinal; o pagamento é buscado de novo na API canônica.
- Inbox idempotente em `mercadoPagoWebhookInbox`, com lock/lease por ID de pagamento em `mercadoPagoWebhookLocks`: serializa avisos simultâneos para o mesmo pagamento, rejeita temporariamente concorrentes para permitir retry e permite recuperar lease expirado. Estados: processado, revisão necessária e falha transitória. Resposta não contém e-mail, UID, valor ou segredo.
- Somente chama o reconciliador privilegiado já existente, que exige claim previamente revisado, merchant/valor/moeda compatíveis e reavalia o ledger. Ausência de claim e divergências determinísticas vão para revisão; não concedem acesso. Payload do callback não controla status/valor.
- Export experimental `mercadoPagoWebhook` em Functions, com secrets nomeados `MP_RECEIVING_ACCESS_TOKEN` e `MP_WEBHOOK_SECRET`. Nenhum secret foi criado/configurado e nenhum endpoint implantado.
- Workflow `.github/workflows/incident-payment-webhook-fixtures.yml`: testes com fixtures somente, sem credenciais e sem etapa de deploy.

## Testes e plataformas

A suíte nova contém 12 cenários, incluindo assinatura válida/inválida, IDs inconsistentes, ignorar status do cliente, repetição, associação ausente, divergência, retry, métodos/eventos inválidos e lease ocupado. [CI 41741751485](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41741751485), SHA `80ddc0c0fdb1fa37a53f9a63f84650fe0a45bc9a`: verde, 47/47 testes, zero falhas e syntax checks aprovados. O teste de serialização usa fixture de lock em memória; Firestore Emulator e concorrência em infraestrutura real não foram executados. As execuções iniciais falharam em ajustes do mock e do filtro do workflow; ambos foram corrigidos e os motivos registrados nos commits intermediários.  A nova execução para os 12 cenários de webhook/serialização será registrada após o commit. Execuções anteriores (CI 41738187870 e 41738449387) passaram com 45 testes e 0 falhas antes desta ampliação. São fixtures sem secrets e não validam Mercado Pago/Firebase reais. Fixtures não são homologação de integração.

- Android celular: **NÃO COMPROVADO**; build default não habilita runtime central e nenhuma sessão real foi consultada.
- Android TV: **NÃO COMPROVADO**; compartilha Flutter/código de direitos com celular, mas não foi exercitada sessão real.
- Roku TV: **NÃO COMPROVADO**; REV2 carregado no BRS Desktop na etapa anterior, mas a integração de acesso permanece desativada. Nenhuma consulta ao backend compartilhado foi provada.
- Mercado Pago/Firebase reais, pagamentos, reprodução/áudio: **NÃO EXECUTADOS**.

Não declarar correção aprovada para as três plataformas. A convergência requer validar o backend e projeto usados por cada app, instalar/configurar a rota em homologação isolada, associar uma conta de teste por fluxo aprovado e confirmar a mesma leitura de entitlement em cada cliente. Nada disso aconteceu aqui.

## Revisão de idempotência e pendências do webhook

A revisão usa lease por payment ID, retorna 503 para concorrente e permite nova tentativa após liberação/expiração. CI 41741751485 passou 47 testes; as corridas foram simuladas com fixture em memória, não no Firestore Emulator. Eventos `review_required` recebem 200 e ainda não têm worker automático; após claim revisado, executor privado precisa reprocessá-los. Renovação/refund são cobertos pelos fixtures do reconciliador. Sequência real MP/Firebase, webhook sandbox, Firestore Emulator e ordenação de entrega do provedor continuam pendentes.

## Próximo procedimento

1. CI fixture-only aprovado: [run 41741751485](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41741751485), 47/47. Não usar secrets do Actions para consultas privadas.
2. Em projeto Firebase **de homologação confirmado**, configurar os secrets existentes por cofre aprovado, registrar URL de notificação no painel de integração Mercado Pago e validar assinatura/eventos via sandbox.
3. Criar claim de pagamento somente depois de revisão independente de proprietário/UID/plano/merchant/valor, sem mapear por e-mail isoladamente.
4. Executar casos sandbox de aprovado, duplicado, renovação, reembolso/chargeback, divergência e concorrência; verificar ledger + entitlement com transações idempotentes.
5. Primeiro resolver a divergência de backend acima. Depois validar as builds experimentais das três plataformas contra a MESMA API/coleção, com limites de dispositivos e duas reproduções. Nenhum ajuste de produção neste commit.
6. Antes de qualquer produção: consultar implantação e logs reais com conexão autorizada, mapear sessão afetada e apresentar plano de mudança; solicitar autorização explícita.

## Evidências e arquivos

- [Código do webhook](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/functions/mercadopago_webhook.js)
- [Integração Firebase experimental](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/functions/index.js)
- [Fixtures](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/functions/mercadopago_webhook.test.js)
- [Workflow](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/.github/workflows/incident-payment-webhook-fixtures.yml)
- [Reconciliador com claim revisado](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/functions/reconcile_and_grant.js)
- [Regras de períodos](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/functions/entitlement_periods.js)
- [Direitos centrais Android](https://github.com/japarocha2-cloud/rocha-plus/blob/incident/payment-recognition-20261103/docs/central-rights/README.md)

## Estado operacional e encerramento

Incidente **ABERTO**. A causa específica do bloqueio da cliente ainda não está provada porque instalação/sessão, endpoint de produção, receipt confirmado e logs de webhook/Functions não foram lidos. Android celular, Android TV e Roku estão sem validação de direito real; nenhuma sincronização foi aplicada. Este incidente não deve ser fechado até que a cliente recupere o acesso mensal validado na plataforma efetivamente usada e a mesma fonte de direito seja demonstrada em celular, Android TV e Roku.

Código do webhook e testes validados no commit `80ddc0c0fdb1fa37a53f9a63f84650fe0a45bc9a`. Relatório mestre atualizado no commit `54f73ff43d916832482779646dca7fa8b32eca95`.

Este relatório é registro técnico experimental. Não contém credenciais nem dados pessoais de clientes.
