# Configuração final: resultado executado — 04/11/2026
Branch impl/commercial-checkout-20261104.
Execução: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41934614980
Artifact: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41934614980/artifacts/13372832683

## Confirmado no Actions sem expor valores
EXPECTED_RECEIVING_MERCHANT_ID presente e correspondente à conferência canônica anterior.
Três bindings de assinatura presentes.
ROCHA_CHECKOUT_HOMOLOGATION_JSON ausente.
Nenhuma chamada financeira/Firebase, repetição de suítes, alteração de secret, IAM ou deploy nesta execução. Job verde significa coleta de readiness concluída, não APK pronto.

## Bundle preparado
Arquivo config/checkout-homologation.template.json gravado no commit c638c41fb78d5f2f10a94c12af166d7cab051fff.
Preenchidos com evidência: projeto e audience rocha-plus-homologacao; pacote com.rochaplus.app.checkout; SHA256 anteriormente extraído da chave existente; backend firebase_entitlements e vínculo firebase_uid; pagamento one_time; checkout_enabled=false e webhook_reconciliation_enabled=false.
merchant_id fica null no template público e foi preenchido apenas no candidato temporário privado pelo secret confirmado. O arquivo privado foi removido, não impresso nem anexado. Não é campo pendente de investigação.
Somente oito campos continuam efetivamente pendentes:
- firebase_app_id, firebase_sender_id, firebase_api_key: configuração SDK do app .checkout já cadastrado no Firebase homologação.
- google_server_client_id: client ID Web do OAuth homologação usado pelo login.
- entitlement_url: URL real da função existente.
- checkout_url: URL real do novo endpoint após implantação autorizada e verificada.
- verified_by, verified_at: responsável e data da revisão efetiva do bundle completo.
Não é possível criar o secret definitivo com nulls. O mecanismo de escrita de secrets permanece inacessível à integração conforme 403 anterior; responsável com permissão do repositório deve gravar o JSON pelo cofre/GitHub Secrets. Não enviar tokens ou chaves no chat.

## Preparação restrita da implantação
Projeto único: rocha-plus-homologacao.
Config existente: firebase.homologacao.json, codebase subscription-homologacao.
Exports novos a selecionar exclusivamente: checkout e mercadoPagoWebhook.
Excluir entitlement de qualquer alteração; não executar deploy geral do codebase/projeto, deploy de regras, alterações OAuth ou exclusões de serviços.
Flags no ambiente dos dois exports novos: ROCHA_CHECKOUT_ENABLED=false e ROCHA_WEBHOOK_RECONCILIATION_ENABLED=false.
Secrets: checkout usa MP_RECEIVING_ACCESS_TOKEN; mercadoPagoWebhook usa MP_RECEIVING_ACCESS_TOKEN e MP_WEBHOOK_SECRET. Nenhum valor deve entrar em Git, artifacts ou APK.
Novo webhook permanece pausado com 503 antes de consultar provedor ou escrever inbox/claims/ledger/direitos. Não registrar sua URL no Mercado Pago nesta etapa.
Não aplicar pausa a qualquer receptor financeiro operacional existente.
Preservar o contrato Firebase UID / entitlements/{uid} / paidUntil já confirmado pelo usuário.

## Permissões: escopo necessário e limite da verificação
Não foi possível atestar concessões IAM efetivas: leitura Cloud Functions v2 retornou 403 na execução anterior. Não repetir a consulta nem criar IAM por suposição.
Antes de implantar, o operador deve confirmar por identidade/recurso:
- leitura: cloudfunctions.functions.get, operações de leitura e política da função/serviço pertinente; storage.objects.get somente na fonte da função, se necessária.
- deploy: cloudfunctions.functions.create/update nos serviços-alvo; cloudfunctions.operations.get e serviceusage.services.use para execução/observação. As necessidades finais dependem da versão do CLI, serviços e build já existentes.
- delegação: iam.serviceAccounts.actAs exclusivamente nas contas de runtime/build efetivamente selecionadas; não presumir conta default nem criar novas contas/chaves.
- build: verificar permissões dos service agents existentes de Functions/Build/Artifact Registry e conta de build para os repositórios/buckets específicos. Não conceder Owner/Editor para contornar erro.
- runtime: acesso Firestore necessário a checkout_orders, payment_claims, payment_events e entitlements; secretmanager.versions.access apenas nos secrets nomeados. Acesso ao banco não deve ser concedido sem avaliar impacto sobre usuários existentes.
- invocação: verificar IAM Cloud Run/Functions v2 dos endpoints HTTP e acesso ao handler que valida token Firebase/HMAC; qualquer mudança de política pública requer revisão explícita, não está autorizada por este documento.
Esta é relação de capacidades a verificar, não role criada nem declaração de que o conjunto foi confirmado como suficiente. Nenhuma política alterada.

## APK e próxima ação
APK não gerado: bundle completo ainda não existe e implantação/IAM ainda não foram confirmados.
Próxima ação objetiva: o operador autorizado deve fornecer a configuração SDK do app .checkout, client ID Web e URL real de entitlement; confirmar a identidade/IAM de implantação restrita; implantar somente os dois endpoints novos com ambas as flags false; copiar a URL efetiva de checkout e registrar revisão do bundle; gravar ROCHA_CHECKOUT_HOMOLOGATION_JSON pelo mecanismo de secrets. Só então executar o build assinado existente e verificar APK/SHA256.
Nenhum teste já aprovado foi repetido. Nenhuma produção, pagamento da Nádia, Candidata 6, LAB 714, catálogo ou visual foi alterado; nenhum bloqueio de canais introduzido.
