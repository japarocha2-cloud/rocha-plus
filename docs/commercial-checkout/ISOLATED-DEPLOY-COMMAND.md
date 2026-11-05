# Comando revisado de implantação isolada — NÃO EXECUTADO
Branch impl/commercial-checkout-20261104.
Config conferida: firebase.homologacao.json, codebase subscription-homologacao, Node.js 22.
Sintaxe dos seletores conferida no código oficial firebase/firebase-tools tag v15.35.0, src/deploy/functions/functionsDeployHelper.ts. Não foram executados CLI, deploy ou testes.

## Evento Mercado Pago compatível
Selecionar futuramente Pagamentos (legacy) na configuração de WEBHOOKS da aplicação revisada, com type=payment e payment.created/payment.updated.
O receptor atual exige POST, query data.id numérica, body.id de notificação numérico, body.data.id consistente quando presente, x-request-id e x-signature HMAC SHA-256. O manifesto é id:<data.id>;request-id:<x-request-id>;ts:<ts>;.
Isso não é compatibilidade genérica com IPN antigo: uma notificação sem esse envelope/assinatura é rejeitada.
Order (Mercado Pago), com type=order, NÃO é suportado. Com receptor habilitado, eventos não payment são ignorados com HTTP 200, sem reconciliar.
Com a flag de reconciliação false, o wrapper retorna 503 antes do handler para qualquer evento, sem consultar provedor ou escrever inbox.
Não registrar URL de produção nem URL nova de homologação nesta etapa. Receber 503 de um receptor pausado é esperado; não é homologação HMAC/financeira.

## Pré-requisitos obrigatórios antes de executar
1. Checkout exato da branch/commit revisado, Node 22 e dependências functions resolvidas pelo package-lock existente. Sem modificações em entitlement.
2. MP_RECEIVING_ACCESS_TOKEN e MP_WEBHOOK_SECRET cadastrados e com versões habilitadas no Secret Manager de rocha-plus-homologacao, por procedimento autorizado separado. Atualmente o proprietário informou que não há secrets.
3. Procedência de ambas credenciais validada para aplicação/ambiente revisados. Não copiar produção. Token/segredo de teste não permitem conceder licença pelo reconciliador live atual; não relaxar a regra em backend compartilhado.
4. Selecionar explicitamente contas runtime/build e comprovar seu acesso. A conta default conhecida é candidata, não aprovação automática de uso.
5. Runtime checkout: secretmanager.versions.access somente no token. Runtime webhook: mesma permissão nos dois secrets. Pode ser fornecida por roles/secretmanager.secretAccessor nos recursos individuais. Confirmar acesso Firestore adequado e impacto sobre usuários, sem alterar documentos.
6. Deployer proprietário: capacidades create/build/serviceusage/actAs já confirmadas pelo responsável. Ainda revisar bindings Secret Manager e política de invocação. O código define invoker public e a CLI pode tentar configurar IAM Cloud Run dos dois serviços novos; isso requer autorização específica de política antes do deploy. Não conceder permissões nem aceitar alterações inesperadas por suposição.
7. Preparar localmente functions/.env.rocha-plus-homologacao com EXATAMENTE ambas as linhas:
```dotenv
ROCHA_CHECKOUT_ENABLED=false
ROCHA_WEBHOOK_RECONCILIATION_ENABLED=false
```
Não incluir valores de secrets no arquivo, não sobrescrever arquivo preexistente sem revisão, verificar que .env genérico ou outra configuração não conflite. Este arquivo deve ser preparado no executor autorizado antes da execução; não foi criado/aplicado nesta etapa.
8. Se a ferramenta solicitar criação de secrets, habilitação de APIs, concessões IAM não revisadas ou exclusões, interromper. Não usar --force. Não executar deploy geral.
9. Obter autorização específica para os DOIS serviços e, separadamente, os bindings de invocação pública. A autorização desta conversa é somente de preparação.

## Comando exato (somente após os pré-requisitos e autorização)
Na raiz do checkout revisado, na Cloud Shell da conta proprietária:
```bash
test "$(git branch --show-current)" = "impl/commercial-checkout-20261104"
npx --yes firebase-tools@15.35.0 deploy \
  --project rocha-plus-homologacao \
  --config firebase.homologacao.json \
  --only 'functions:subscription-homologacao:checkout,functions:subscription-homologacao:mercadoPagoWebhook' \
  --non-interactive
```
A invocação usa seletores de codebase + função. Não usar --only functions:subscription-homologacao, pois selecionaria o codebase inteiro. Não remover --only. entitlement não é alvo.
--non-interactive impede depender de prompts de confirmação; não transforma IAM, APIs ou deploy em ações autorizadas e não é dry-run. O comando altera serviços se executado.

## Verificação posterior (preparada, não executada)
Antes de um deploy autorizado, registrar privadamente nome/updateTime e revisão de entitlement como baseline, sem exportar ambiente ou credenciais. Se os dois alvos novos já existirem, revisar suas revisões/flags antes de criar ou atualizar; não presumir reversão por exclusão.
Após conclusão: conferir somente metadata de checkout e mercadoPagoWebhook, projeto/região, contas, secret references e ambas as flags exatamente false. Capturar URLs reais, sem inferi-las.
Conferir que metadata/revisão de entitlement coincide com baseline. Parar se houve mudança inesperada.
Pode-se verificar webhook com POST vazio: deve retornar 503/paused sem escrita, conforme guard. Não enviar pagamento real, notification ID histórico nem callback assinado de produção. Checkout autenticado e desativado deve retornar 503 sem criar pedido/preferência; requer sessão de homologação válida para essa verificação posterior.
Não chamar deploy de entitlement para testar login: consulta autenticada de direitos pode inicializar trial, portanto só com conta de teste autorizada.
A verificação de flags não habilita HMAC ou reconciliação. URL futura não deve ser registrada no Mercado Pago sem validação/autorização específica.

## Reversão preparada, também requer autorização
As flags permanecem false; nenhum endpoint novo deve receber notificações reais. Se houver falha parcial, interromper e registrar quais serviços foram criados, sem reexecutar cegamente.
Se comprovadamente ambos eram inexistentes no baseline e foram criados exclusivamente por esse deploy, uma reversão autorizada pode remover SOMENTE os serviços efetivamente criados:
```bash
gcloud functions delete checkout --gen2 --region=southamerica-east1 --project=rocha-plus-homologacao
gcloud functions delete mercadoPagoWebhook --gen2 --region=southamerica-east1 --project=rocha-plus-homologacao
```
Executar cada exclusão somente se esse recurso foi criado nesta implantação e sua remoção foi autorizada. Não excluir serviço que já existia. Para alvos preexistentes, restaurar revisão/configuração aprovada em procedimento separado.
Não apagar/rotacionar secrets, inbox, claims, ledger ou entitlements como rollback. Nenhuma alteração de IAM deve ser revertida automaticamente. Não tocar Nádia, produção, Candidata 6, LAB 714 ou catálogo.

## Próxima ação executável
Concluir a revisão de origem das credenciais e obter autorização específica para cadastrar os dois secrets pelo script já preparado; depois confirmar runtime/bindings e invocação. O comando acima fica preparado, mas bloqueado até essas condições. Nada foi implantado, configurado no Mercado Pago, cobrado ou alterado em IAM nesta preparação.
