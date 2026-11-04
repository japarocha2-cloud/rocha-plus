# Homologação: resultado da inspeção autorizada — 04/11/2026
Projeto único consultado: rocha-plus-homologacao.
Branch: impl/commercial-checkout-20261104.
Execução de leitura: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41930655927
Código da inspeção: 156be5b660377362f5a227dd852b36ead27e6112.

## 1. Compatibilidade da entitlement existente
NÃO COMPROVADA. A consulta autenticada da API Cloud Functions v2 para projects/rocha-plus-homologacao/locations/southamerica-east1/functions/entitlement retornou HTTP 403. A execução parou a inspeção de funções nessa resposta, sem repetir consultas negadas.
Não houve acesso ao source implantado, IAM ou configuração efetiva da função. Não é correto inferir coleções, Firebase UID, trial ou prioridade paga pelo código do repositório.
A autenticação via service account configurada foi tentada; o HTTP 403 não permite afirmar apenas com esta evidência se a causa é IAM, política ou habilitação da API.

## 2. Implantação
Nenhum serviço implantado ou alterado. A implantação foi bloqueada pelas condições explícitas do usuário: compatibilidade, IAM, secrets/ambiente, recebedor e efeitos sobre usuários não foram comprovados.
FIREBASE_SERVICE_ACCOUNT_JSON e MP_RECEIVING_ACCESS_TOKEN estão presentes nos bindings do Actions; valores não foram exportados.
EXPECTED_RECEIVING_MERCHANT_ID ausente. A conferência do recebedor não foi realizada sem a identidade esperada revisada.
Não foram criadas preferências, chamados webhooks ou alteradas licenças/pagamentos.
O estado operacional ROCHA_CHECKOUT_ENABLED não foi lido; não declarar que o servidor existente está comprovadamente desligado. Nenhuma ativação foi executada.

## 3. Validação
A inspeção read-only executou e produziu artifact homologation-readonly-result. Job verde significa que a coleta do resultado terminou; NÃO significa homologação financeira aprovada.
Integração real Google/Firebase e UID: não executada, sem sessão autenticada da conta de suporte e sem acesso à configuração do backend.
Assinatura webhook, duplicatas/replay, aprovação, trial sem reset e prioridade paga têm fixtures anteriores aprovadas (59 backend). As 241 verificações Flutter e 4 de configuração também são evidência anterior. Não foram repetidas ou apresentadas como testes de integração real.
O cadastro do aplicativo, certificados e OAuth foi informado pelo usuário e não é contestado; falta comprovar o contrato do backend implantado.

## 4. APK
Não gerado nesta execução. ROCHA_CHECKOUT_HOMOLOGATION_JSON permanece ausente no Actions. Não é possível completar dados reais revisados por suposição; nenhum secret foi criado/modificado.
Sem APK, não há novo link de download nem SHA-256 de APK.
A chave existente já foi verificada na execução de certificados registrada anteriormente.

## 5. Ação necessária
O responsável pelo acesso deve diagnosticar o HTTP 403 e disponibilizar à identidade aprovada leitura da função v2 em homologação, configuração/IAM e fonte correspondente. Leitura da função requer cloudfunctions.functions.get; leitura do objeto de source, quando usado, requer storage.objects.get no objeto pertinente. Não criar novas chaves, atribuir privilégios amplos ou consultar produção por causa desta falha.
Disponibilizar EXPECTED_RECEIVING_MERCHANT_ID por cofre com a identidade financeira revisada, e o bundle ROCHA_CHECKOUT_HOMOLOGATION_JSON conforme BUILD.md, usando app/projeto/OAuth de homologação já cadastrados.
Depois de acesso liberado: revisar source real e runtime do entitlement, identidade de execução, projeto/audience e coleções; comprovar recebedor em /users/me; revisar secrets do webhook e IAM/efeitos de uma implantação restrita a checkout e mercadoPagoWebhook. Preservar entitlement existente até comprovar contrato e impacto.
Só então implantar no projeto indicado com ROCHA_CHECKOUT_ENABLED=false, executar integração isolada verificável sem cobrança e gerar APK assinado.
Uma única compra real da conta de suporte exige posteriormente aprovação financeira explícita, sessão/UID comprovados, valor BRL 4,50 ou 49,50 por período, pagamento único sem renovação automática, ausência de duplicidade e confirmação do caminho pedido -> pagamento canônico -> claim -> paidUntil na mesma identidade. Esta execução não autoriza a compra.

Candidata 6, catálogo/430 canais, visual, LAB 714, Nádia, produção e configurações financeiras não foram modificados. Nenhum catálogo foi bloqueado.
