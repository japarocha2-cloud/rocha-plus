# Direitos centrais — experimento isolado, desativado

Não há deploy, cobrança ou concessão comercial. O código não é importado pelos entrypoints oficiais. O ambiente público permanece desativado; configuração de exemplo é bloqueada. Leituras da identidade comercial são separadas das escritas experimentais. Os adapters de escrita recusam `rocha-plus` e `rocha-plus-candidate`.

## Contrato e origem dos direitos

`rights.mjs` resolve um único snapshot por Firebase UID para celular, Android TV e Roku. Trial deriva exclusivamente do início original de sete dias; consultar não cria conta/trial. Períodos pagos têm início/fim explícitos e são independentes: não somam mensal e anual. Essa é uma propriedade do transporte experimental, **não aprovação da regra comercial para os pagamentos históricos**. Um contrato histórico aprovado ainda precisa fornecer os períodos corretos.

Estados: paid, trial, trial_expired, subscription_expired, revoked, reconciliation_pending, lab e unknown. LAB usa scope homologation; paid/trial usam commercial. Respostas incluem contractVersion, UID, dispositivo, estado, horário do servidor e lease até 60 s. Clientes devem descontar RTT e medir duração com relógio monotônico. Falha de rede não renova lease.

`read-source.mjs` adota o relógio Spark existente por vínculo Google verificado no Admin Auth. Não cria trial ou importa paidUntil sem revisão. Uma divergência de identidade/relógio resulta em indisponível. `firebase-runtime.mjs` exige identidade `rocha-plus`, banco comercial apenas de leitura e armazenamento LAB separado para sessões. Ainda requer instâncias Admin autorizadas no host isolado; o segredo do CI não foi transferido.

## Pagamentos e conciliação

`payments.mjs` valida assinatura antes de consultar o pagamento pelo servidor. O corpo da notificação nunca autoriza. Valida recurso, recebedor, moeda, modo, datas e estorno. `periodResolver` é uma dependência confiável do servidor: precisa de política aprovada, vínculo de pagador, ID de pagamento ou referência reservada, plano/valor e início/fim. Não existe configuração automática de planos ou alteração de preços.

Pagamento aprovado sem contrato verificável entra em revisão/alerta, sem direito. A mesma revisão pode ser reprocessada após resolver o vínculo, mesmo sem mudança de timestamp no provedor. Ledger global, período e alerta são gravados atomicamente. Duplicatas não estendem o período; eventos antigos não ressuscitam reembolsos. Falha temporária retorna 503 para retry. Cancelamento de renovação não revoga automaticamente um ciclo já pago; estorno/disputa do pagamento remove somente esse período. A revisão comercial deve confirmar políticas de estorno parcial e cancelamento antes da implantação.

`fixture-payment-store.mjs` é fixture serializada; `firestore-adapters.mjs` prepara a transação experimental sem executar escrita real. A fila/alerta é persistida no mesmo banco experimental; entrega de alertas a operadores e scheduler de reprocessamento não foram ativados. Não há nova criação de checkout/link; o contrato prevê referência opaca reservada para integração futura, sem trocar os links oficiais nesta etapa.

## Dispositivos

`devices.mjs`: código de oito caracteres/10 min, segredo do dispositivo, aprovação Firebase autenticada e conta ativa/verificada. Uma sessão de celular, duas TVs vinculadas, duas reproduções. TV ociosa não ocupa stream. Troca de celular preserva TVs. Lease de stream expira em até 60 s; sessão de TV até 24 h. Store transacional serializa concorrência. Adapter Firestore é intencionalmente limitado a pequeno LAB (128 pares/sessões e documento abaixo de 700 KB), não projeto de escala comercial.

## HTTPS e aprovação móvel

`https-runtime.mjs` fornece página `/approve` e POST `/v1/access`, TLS real, JSON limitado, no-store e verificação de origem. `listenLoopback` liga somente 127.0.0.1. Cabeçalho de proxy não substitui TLS. `mobile-approval.html` usa Google/Firebase Auth oficial com persistência de identidade somente em memória e confirmação explícita do código. O ID local do cliente não é credencial administrativa.

O runtime foi testado em loopback com certificado efêmero confiado **somente pelo cliente de teste**. A chave nunca é persistida; nenhuma CA do Windows foi instalada e TLS não foi desativado. Isso não configura HTTPS acessível ao celular físico ou certificado aceito pelo Roku. Não houve popup Google real, concessão para conta real ou publicação do serviço.

## Reproduzir

Com Node 22 ou superior:

```text
node --input-type=module -e "import {runIntegrationTests} from './experiments/central-rights/integration.test.mjs'; console.log(await runIntegrationTests())"
node --input-type=module -e "import {runHttpsTests} from './experiments/central-rights/https.test.mjs'; console.log(await runHttpsTests())"
```

Os testes não cobram nem alteram assinaturas. Resultados e restrições estão em `docs/central-rights/20261102`. Para implementação real ainda são necessários: política temporal aprovada, reserva/vínculo confiável de checkout, acesso à configuração e entregas do webhook, credenciais de mínimo privilégio no runtime isolado, testes Firebase Auth positivos e Firestore concorrente real, integrações de player e testes físicos. Não habilitar produção por ter testes verdes.

Referências oficiais: [webhooks Mercado Pago](https://raw.githubusercontent.com/mercadopago/sdk-nodejs/master/docs/webhooks.md), [ID tokens Firebase](https://firebase.google.com/docs/auth/admin/verify-id-tokens), [revogação de sessões](https://firebase.google.com/docs/auth/admin/manage-sessions).

## Integração completa em loopback

`contracts.mjs` prepara referência opaca vinculada a identidade Firebase verificada, sem chamar o provedor ou criar cobrança. Somente política temporal aprovada pelo servidor pode gerar intenção. O resolvedor usa reserva verificável ou contrato histórico revisado/autorizado; ausência de referência continua em conciliação. Não se atribui automaticamente a regra experimental aos pagamentos reais.

`e2e.test.mjs` testa, com fixtures, intenção→webhook HMAC por HTTPS→GET autorizado simulado→ledger único→mesma validade no celular/TV→estorno→bloqueio da renovação. TLS é real em loopback; Auth, pagamento, banco e player são fixtures. `/v1/payment-notifications` só existe quando handler é explicitamente injetado. Não foi ativado endpoint público ou comercial.
