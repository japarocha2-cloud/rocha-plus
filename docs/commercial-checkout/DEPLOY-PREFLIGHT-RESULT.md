# Pré-implantação: permissões efetivas — 04/11/2026
Execução somente leitura: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41940338867
Artifact: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41940338867/artifacts/13375846708
Projeto único: rocha-plus-homologacao. Branch: impl/commercial-checkout-20261104.

## Identidade e permissões observadas
Executor: firebase-adminsdk-fbsvc@rocha-plus.iam.gserviceaccount.com.
testIamPermissions do projeto: HTTP 200.
Concedidas entre as consultadas:
cloudfunctions.functions.get, cloudfunctions.functions.list, cloudfunctions.functions.getIamPolicy,
cloudfunctions.operations.get, resourcemanager.projects.get, run.services.get,
serviceusage.services.get, serviceusage.services.list, cloudbuild.builds.get.
Não concedidas no escopo do projeto:
cloudfunctions.functions.create, cloudfunctions.functions.update,
cloudfunctions.functions.setIamPolicy, run.services.setIamPolicy,
serviceusage.services.use, cloudbuild.builds.create.
Essa lista é resultado de avaliação de capacidades; não implica que todo item seja necessário em toda estratégia de implantação. Criação dos dois endpoints requer capacidade de create; update será pertinente a atualizações posteriores; mudanças de política dependem da política de invocação escolhida. Não conceder todos os itens indiscriminadamente.
Não foram enumeradas todas as permissões possíveis nem aprovadas dependências de build/storage/Artifact Registry.

## Service accounts, secrets e estado dos alvos
Conta candidata de runtime, conhecida da metadata anterior de entitlement:
40393752948-compute@developer.gserviceaccount.com.
A consulta read-only do Cloud Build confirmou a mesma identidade como default de build. Isso identifica a candidata/default, não autoriza seu uso nem exige reutilizá-la.
Teste iam.serviceAccounts.actAs/get na conta: HTTP 403. Resultado INCONCLUSIVO sobre a permissão actAs em si; não declarar granted=false sem resposta de avaliação. Não houve impersonação.
Metadados do secret MP_RECEIVING_ACCESS_TOKEN em Secret Manager: HTTP 403. Não comprova inexistência e não comprova acesso runtime ao payload. MP_WEBHOOK_SECRET não foi consultado após a negativa.
Os secrets GitHub já existentes não demonstram bindings ou versões acessíveis no Secret Manager de homologação.
checkout e mercadoPagoWebhook: GET Cloud Functions v2 retornou HTTP 404 para ambos. Nenhuma consulta repetida de entitlement ou source Storage.

## Configuração preparada
Template com checkout_enabled=false e webhook_reconciliation_enabled=false verificado por leitura.
Guard do novo webhook verifica ROCHA_WEBHOOK_RECONCILIATION_ENABLED !== 'true' antes de acesso financeiro/storage.
Intenção de implantação registrada no artifact:
- projeto rocha-plus-homologacao e região southamerica-east1;
- firebase.homologacao.json / codebase subscription-homologacao;
- somente exports checkout e mercadoPagoWebhook;
- preservar export entitlement;
- definir explicitamente ROCHA_CHECKOUT_ENABLED=false e ROCHA_WEBHOOK_RECONCILIATION_ENABLED=false nos dois alvos novos;
- não registrar webhook no Mercado Pago, não ativar cobranças.
As flags são preparação em arquivo/intenção; os alvos ainda não existem. Não foram aplicadas remotamente.

## Procedimento exato para autorizar uma implantação posterior
1. O proprietário revisa este resultado e escolhe uma identidade de implantação já existente. Pode ser o executor acima ou outra identidade aprovada; não criar conta/chave por padrão.
2. O administrador confirma o acesso necessário no projeto de homologação: criação das Functions, uso dos serviços e a cadeia de build escolhida. Para uso das contas escolhidas, comprovar iam.serviceAccounts.actAs nesses recursos. Qualquer concessão IAM é ação separada que exige autorização; não está sendo executada por este relatório.
3. Confirmar conta de runtime/build e acesso runtime a Firestore e somente aos secrets MP_RECEIVING_ACCESS_TOKEN e MP_WEBHOOK_SECRET. Confirmar versões/bindings sem exibir valores. Os HTTP 403 atuais deixam esse passo aberto.
4. Revisar a política de invocação dos dois endpoints: o código usa invoker public com validação Firebase/HMAC no handler. Criar esses bindings pode exigir run.services.setIamPolicy e/ou capacidades do fluxo Functions. Não autorizar implicitamente alteração de IAM sob o nome de deploy.
5. Registrar uma autorização específica, com escopo:
   “Autorizo implantar exclusivamente checkout e mercadoPagoWebhook da branch/commit revisado no projeto rocha-plus-homologacao, região southamerica-east1, usando as contas de build/runtime identificadas e aprovadas, com ROCHA_CHECKOUT_ENABLED=false e ROCHA_WEBHOOK_RECONCILIATION_ENABLED=false; preservar entitlement, sem cobranças e sem registro de webhook no Mercado Pago.”
   A autorização deve dizer separadamente se permite os bindings de invocação dos DOIS novos endpoints. Sem essa autorização, parar se a ferramenta solicitar política pública ou outro IAM.
6. Antes da execução, fixar o commit revisado, preparar as duas flags no ambiente somente de homologação e usar seleção restrita dos dois exports do codebase. Não executar deploy geral, de regras, Auth, Storage, produção, entitlement ou exclusões de serviços. Parar em solicitações inesperadas de habilitação de APIs, concessões, criação de secrets/contas ou mudança de usuários.
7. Após autorização e deploy restrito concluídos: ler URLs e flags efetivas; completar checkout_url no candidato privado e gravar o bundle pelo mecanismo seguro já aprovado; só então gerar APK assinado.
Não há autorização de implantação neste documento nem nesta execução. As faltas de capacidade e evidências impedem considerá-la pronta.

Não houve concessão de IAM, deploy, testes repetidos, acesso a payload de secret, cobrança ou alteração de entitlement, Nádia, Candidata 6, LAB 714 ou catálogo.
