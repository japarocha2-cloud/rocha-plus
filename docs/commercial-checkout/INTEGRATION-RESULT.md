# Integração: resultado incremental — 04/11/2026
Branch impl/commercial-checkout-20261104.

## Comparação efetivamente possível
A confirmação visual fornecida pelo responsável estabelece Firebase UID, entitlements/{uid}, trial de sete dias, paidUntil e reconciliador que exige claim revisado. O novo checkout é compatível com esse contrato: UID vem de verifyIdToken; checkout_orders armazena o pedido; checkout_claim cria payment_claims com UID/plano/valor/moeda/merchant após consulta canônica; reconcile_and_grant recalcula paidUntil na mesma identidade sem reiniciar documento existente.
Essa compatibilidade de contrato não é comparação byte a byte da fonte implantada. O source/manifesto completo implantado não foi fornecido e o acesso automatizado de leitura permanece com a última evidência HTTP 403. A confirmação do usuário é incorporada, sem repetir a consulta negada.
Claims históricos sem external_reference de pedido autenticado não se tornam automaticamente válidos: continuam exigindo revisão independente. O campo reviewed=true dos pedidos novos é emitido pelo servidor após vinculação canônica, não por cliente nem correspondência de e-mail. Essa política precisa ser revisada para o ambiente antes de ativação.
A concessão atual exige pagamento live, approved/accredited, BRL, valor/merchant compatíveis e ausência de reembolso. Pagamento simulado/sandbox não será concedido por essa regra live; fixtures podem simular o fluxo, mas uma homologação sandbox que grave direitos exige isolamento explícito e não deve relaxar esse requisito no backend comum.

## Correção executada
Incompatibilidade operacional identificada: desabilitar checkout não impedia o webhook de reconciliar claims históricos e atualizar licenças.
Commit 81c22cd95df7088919fd571a9c834976b42748e2 adiciona pausa independente ao NOVO receptor antes de criar inbox, consultar provedor ou conceder/recalcular direitos. Sem ROCHA_WEBHOOK_RECONCILIATION_ENABLED=true, resposta 503/no-store, sem reconhecimento definitivo da notificação. O provedor pode tentar novamente; não registrar a URL no provedor até a revisão, para evitar fila de retries.
O requisito ROCHA_CHECKOUT_ENABLED=false permanece. Para preparar a futura implantação isolada, manter também ROCHA_WEBHOOK_RECONCILIATION_ENABLED=false. Não alterar o receptor operacional de outro ambiente, especialmente durante compras/reembolsos ativos.
Nenhuma função implantada foi alterada. Pausa existe apenas no código da branch, não foi aplicada remotamente.
Commit e890a2b998573a31712dfc38afce4cd45641ae28 registra cinco cenários novos. Executados localmente com Node 24; todos passaram. Cobrem flags ausentes/false, checkout true com receptor pausado, ausência de acesso financeiro/storage e habilitação explícita encaminhando ao handler assinado. Não repetidas suítes anteriores; teste da habilitação usa mock, não é validação HMAC real.
O teste novo será incluído na suíte Node 22 já configurada na próxima execução autorizada do Actions; não foi disparado build completo por esta alteração.

## Configuração privada e implantação
Não foram inventados endpoints, app IDs, OAuth IDs ou merchant IDs.
Última leitura do Actions (run 41930655927): EXPECTED_RECEIVING_MERCHANT_ID e ROCHA_CHECKOUT_HOMOLOGATION_JSON ausentes; bindings administrativos Firebase e token recebedor presentes, sem valores exportados. Nenhuma evidência posterior com dados revisados está disponível.
Tentativa de ler somente nomes de secrets pelo conector GitHub foi recusada pelo próprio endpoint suportado (400); ele não permite administrar esses bindings por essa rota. Não houve tentativa de contornar nem extrair secrets.
Ação necessária: responsável com acesso homologado corrigir o 403 de leitura e disponibilizar via cofre/Actions o merchant esperado e bundle real revisado (campos em BUILD.md). Confirmar IAM de implantação, runtime, bindings de MP_WEBHOOK_SECRET/MP_RECEIVING_ACCESS_TOKEN e efeitos sobre documentos existentes antes de deploy restrito aos dois exports novos. Não redeployar entitlement por suposição nem alterar produção.
Nenhum deploy, alteração de IAM, concessão de licença, registro de webhook, pagamento ou alteração de secret foi executado.

## APK
Não gerado nesta execução. Sem bundle revisado e endpoints efetivos, não há requisitos completos para o build assinado. Não foi repetida uma compilação que já falhava por esse requisito. O workflow continua pronto para rodar após fornecimento e validação desses dados.
Candidata 6, catálogo, visual, LAB 714, conta da Nádia e produção preservados.
