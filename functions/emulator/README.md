# Concorrência local de entitlement

Teste dedicado ao **Firestore Emulator Standard**, projeto descartável
`demo-rocha-concurrency`, sem implantação ou acesso a bancos cloud.
Não executa pagamento, consulta Mercado Pago real ou usa conta Firebase real.
O campo `live_mode: true` é exclusivamente uma fixture do contrato existente;
não é evidência de compra sandbox ou real. As guardas do código de produção
continuam intactas.

Requisitos: Node 22, Java 21 e dependências do lockfile de `functions`.
A partir da raiz do repositório:

```sh
npm ci --prefix functions --ignore-scripts --no-audit --no-fund
GCLOUD_PROJECT=demo-rocha-concurrency npx --yes firebase-tools@15.34.1 emulators:exec --only firestore --project demo-rocha-concurrency --config functions/emulator/firebase.json 'node --test functions/emulator/concurrency.test.js'
```

A suíte recusa projeto diferente e host que não seja `127.0.0.1:PORTA` antes de
inicializar o SDK. O CLI cria uma instância local efêmera, sem importar/exportar
estado. Não apontar para um emulador compartilhado: os IDs de fixture são fixos.
O ruleset desta pasta pertence somente ao emulador e nega acesso de clientes;
o teste usa Admin SDK, portanto não audita regras de clientes ou IAM.

Cobertura nova:

- Quatro primeiras consultas concorrentes persistem um trial de 7 × 24 horas;
  consultas no vencimento negam acesso e preservam o registro.
- Três reconciliações concorrentes do mesmo ID criam um único evento; somente
  uma reporta primeira gravação e não há extensão cumulativa do período.
- IDs diferentes para a mesma conta mantêm os dois eventos e o vencimento anual.
- Replay concorrente do estorno mensal preserva a assinatura anual independente.
- Estorno da última assinatura bloqueia acesso; datas do trial não reiniciam.

A suíte executa `functions/index.js` e `reconcile_and_grant.js` reais, com
transações e SDK Firestore reais. A autenticação, o relógio do endpoint e o
provedor de pagamento são fixtures. O carregador do endpoint mantém o mesmo
contexto JavaScript do SDK, sem alterar `Date` global nem o módulo de produção.
Os resultados de `allowed`, motivo e datas são conferidos também após
reconciliação/estorno. O diagnóstico informa operações, tentativas e retries
observados do SDK; não fabrica aborts e não exige uma quantidade específica de
retries, que varia conforme o agendamento.

Não substitui login físico, latência cloud, compra sandbox, segurança de regras,
webhook implantado, atualização de estornos do provedor ou garantia contra
resposta de pagamento obsoleta recebida fora de ordem. A ordem de consulta de
status ao provedor continua uma pendência operacional independente.
