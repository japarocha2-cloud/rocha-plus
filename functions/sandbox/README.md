# Mercado Pago: caminho sandbox isolado

Este módulo é independente do reconciliador de produção, que permanece inalterado
com a exigência `liveMode === true`. Não há flag de configuração capaz de tornar
o reconciliador de produção permissivo. Não importar este módulo em Functions
implantadas nem no aplicativo.

`createSandbox` exige simultaneamente:

- Projeto descartável `demo-rocha-sandbox` e `FIRESTORE_EMULATOR_HOST=127.0.0.1:PORTA`,
  validados antes de inicializar o SDK. Não aceita banco cloud nem instância
  externa fornecida pelo chamador.
- Credencial com prefixo `TEST-`; nunca `APP_USR-`. Não relaxar essa guarda para
  contornar falta de credencial sandbox compatível.
- Resposta obtida por GET no endpoint oficial de pagamentos, com ID correspondente,
  `live_mode` **explicitamente false** e data de atualização do provedor válida.
- Associação UID/plano/valor/recebedor previamente revisada em
  `sandbox_payment_claims`. UIDs devem começar com `sandbox-`.

Grava exclusivamente `sandbox_payment_events` e `sandbox_entitlements` no emulador.
Os registros da conta/trial são preparados pelo operador/teste, sem copiar contas
reais. Recalcula o maior vencimento confiável sem acumular entregas duplicadas.
Estornos removem o período correspondente. Respostas anteriores e tentativa de
reativar o mesmo ID estornado são ignoradas; divergência de identidade/modo falha
antes de gravação. Não existem métodos de cobrança, criação de pagamento ou
estorno remoto neste módulo: nenhuma chamada POST ao provedor é implementada.

## Testes executáveis sem credenciais

```sh
npm ci --prefix functions --ignore-scripts --no-audit --no-fund
GCLOUD_PROJECT=demo-rocha-sandbox npx --yes firebase-tools@15.34.1 emulators:exec --only firestore --project demo-rocha-sandbox --config functions/sandbox/firebase.json 'node --test functions/sandbox/reconcile.test.js'
```

Os testes usam SDK/transações Firestore reais, com respostas Mercado Pago
**simuladas** `live_mode=false`: compra aprovada, renovação por novo ID, replay
concorrente, estornos, resposta obsoleta, rejeição de modo real/credenciais reais
e invariância dos módulos de produção. Conferem que as coleções de produção
permanecem vazias. Isso não é uma compra sandbox no serviço do Mercado Pago.

## Integração futura com o sandbox do provedor

O cliente de leitura está pronto para consultar uma transação sandbox previamente
criada por test users/checkout de teste do Mercado Pago. Configurar o token como
segredo fora do Git e nunca imprimir resposta completa, comprador ou token.
`createSandbox({accessToken: process.env.ROCHA_MP_SANDBOX_ACCESS_TOKEN})` utiliza
GET real por padrão; `fetchImpl` é substituído somente na suíte local.

Antes de executar: confirmar documentação vigente da conta sandbox, vendedor e
comprador de teste, meio de pagamento de teste e projeto do emulador. Não usar
contas, cartões, links ou IDs históricos de produção. Associar/revisar o claim
independentemente do retorno do checkout; não inferir UID/plano de payload público.
Registrar evidência expurgada do ID de execução, `live_mode=false`, estado,
valor/moeda/recebedor esperados, renovação, repetição e estorno e seu reflexo na
conta isolada. O módulo não provisiona checkout, webhook ou aplicativo sandbox.

Neste ambiente não há token, test users nem transação sandbox atestados. Compra,
renovação e estorno ponta a ponta no provedor continuam pendentes. Não mover o
resultado do emulador para contas cloud ou declarar acesso pago real homologado.
