# P0 — identidade da sessão, prévia integral e restauração segura
Data: 03/11/2026. Branch: incident/payment-recognition-20261103.

## Estado da entrega

Preparados: coletor de metadados Android, verificador de identidade autenticada, captura mascarada das cinco alterações e diagnóstico privado de regras/IAM. Nenhum aplicativo oficial foi modificado, compilado, instalado ou publicado.

NÃO confirmados: sessão atual no aparelho, package/versionName/versionCode instalados, origem efetiva, projeto e endpoint usados pelo binário instalado, regras implantadas, IAM atual, auditoria real pré-existente, operador da aplicação e autorização comercial. Não declarar acesso restaurado nem digest final fechado.

O proprietário escolheu executar os dados reais exclusivamente no ambiente privado do Work, sem publicar o resultado no GitHub. O executável privado recusa GITHUB_ACTIONS=true e exige diretório privado vazio fora do checkout. A única saída normal do terminal informa que o resultado foi guardado privadamente.

## Identidade e mecanismo de acesso

A evidência histórica de servidor confirmou uma conta habilitada/verificada, com Firebase UID diferente do Google subject e registro Spark sem campo paidUntil. Ela não comprova a sessão ou build em uso no aparelho hoje.

| Caminho de código | Identidade usada | Fonte de direito | Uma gravação somente em Spark resolve? |
|---|---|---|---|
| Cliente Spark histórico | Firebase UID autentica; Google subject escolhe documento | rochaSparkAccounts/<Google subject> | Candidato, desde que projeto, identidade, regras e demais campos do cliente sejam válidos |
| SubscriptionAccess com endpoint Cloud Function | UID extraído do token Firebase | entitlements/<Firebase UID> | Não |
| SubscriptionAccess com servidor Node experimental | UID extraído do token Firebase | rochaEntitlements/<sha256 UID> e rochaPayments | Não |
| CentralRightsRuntime habilitado | UID Firebase, dispositivo e scope | Contrato/lease do backend central configurado | Não demonstrado; validar implementação/ambiente/scope |
| Beta com enforcement desligado | Login | Gate comercial não é aplicado | Não atribuir bloqueio a Spark sem outra evidência |

Referências: lib/src/app.dart, lib/src/app_release_policy.dart, lib/src/auth/subscription_access.dart, lib/src/auth/central_rights_runtime.dart, functions/index.js e backend/entitlement/server.mjs. O pubspec do repositório não revela o versionCode do APK instalado: o CI pode substituí-lo.

Há caminhos que criam trial/conta durante a consulta. O GET da Cloud Function entitlement pode criar entitlements quando ausente; o serviço Node também pode inicializar conta. Não chamar esses endpoints em produção como se fossem consultas sem efeitos. O diagnóstico preparado usa leituras diretas de documentos e não inicializa trial.

Não foi comprovada uma segunda falha no gate do aparelho. Se a build usa entitlements/Node/central, a proposta Spark mira outra fonte de verdade; gravar em várias coleções para tentar contornar essa divergência não está autorizado.

## Forma mais rápida e segura de confirmar a sessão

1. Manter a instalação e sessão atuais. Obter pacote, versão/código e origem informada do APK, além do horário/fuso de uma tentativa já realizada. Não pedir logout, reinstalação ou novo pagamento.
2. Num computador de suporte já autorizado para o aparelho, o coletor abaixo lê apenas metadados do pacote. Não habilita depuração, não instala/desinstala, não executa run-as, não lê preferências nem despeja logcat. Se ADB não está disponível/autorizado, usar primeiro as informações do aplicativo nas configurações Android.
3. Opcionalmente obter hashes dos APKs instalados em cópias temporárias privadas. Comparar com evidência CI/manifesto da distribuição correspondente. Um APK dividido entregue pela Play não precisa ter o mesmo hash de um universal; installerPackageName e versionCode sozinhos não atestam procedência.
4. Correlacionar a build identificada com as opções de compilação e o backend efetivo. Pacote .lab sozinho não comprova projeto/endpoint.
5. Para prova de identidade atual, o backend deve validar o ID token recebido da MESMA sessão do aplicativo, checando revogação, audience/issuer e vínculo Google no Auth. Comparar somente fingerprints com o destino independente da recuperação. Não solicitar à cliente que copie ou envie o token.
6. Caso um backend existente já disponha de logs adequados da tentativa, consultá-los privadamente sem ativar novos logs de produção. Se não houver observabilidade suficiente, o verificador preparado ainda precisa de um transporte/instrumentação aprovado; ele não foi implantado. Não há como inferir criptograficamente a sessão instalada apenas por um login separado num navegador ou por metadados ADB.

O token Firebase atesta identidade/projeto do portador; ele NÃO atesta packageName, versionCode, origem da instalação ou o backend compilado. O verificador deixa installedBuildVerified, backendVerified e deviceSessionVerified como false. Não apresentar uma autenticação separada no navegador como prova da sessão do APK.

Coleta de metadados, pelo operador autorizado, substituindo o pacote após identificá-lo:
```sh
python3 tools/incident/device_metadata.py --package PACOTE_CONFIRMADO
```
Acrescentar --hash-apk somente se a cópia privada temporária do APK for adequada ao suporte. O coletor não publica APK e remove a cópia temporária; não inclui serial do aparelho no relatório.

## Dados mínimos da cliente

- Nome do aparelho/modelo e versão Android, sem IMEI ou serial.
- Pacote, versionName e versionCode, quando disponíveis.
- Origem informada da instalação ou referência privada ao arquivo recebido.
- Horário/fuso da falha já observada e mensagem apresentada.
- Conferência privada de que a conta exibida no aplicativo é a esperada, sem publicar o e-mail.

A cliente não deve fornecer senha, código de autenticação, ID/refresh token, UID completo, dumps de armazenamento ou novo comprovante financeiro. Nenhuma dessas informações manuais substitui a validação autenticada do UID.

## Prévia integral das cinco alterações

A captura usa a implementação EXISTENTE de regular_payment_firestore.mjs com um banco de gravação apenas em memória. O banco real fornece exclusivamente get(); seu runTransaction, create, set e update nunca são chamados pela captura.

| Documento | Operação pretendida | Antes | Depois proposto |
|---|---|---|---|
| rochaDirectPaymentLedger/<fingerprint mensal> | create | Ausência deve ser reconfirmada privadamente | id, uid, googleSubject, merchantId, plan, amountCents, currency, periodStart, periodEnd, status, bindingDigest, provider, contractEvidence, checkedAt, authorizedBy, authorizationReference |
| rochaDirectPaymentLedger/<fingerprint anual> | create | Ausência deve ser reconfirmada privadamente | Mesmo esquema, com o período anual independente |
| rochaSparkAccounts/<fingerprint Google> | update | paidUntil historicamente ausente; ler também reconciledAt e versão atual | Somente paidUntil como timestamp do término aprovado e reconciledAt; todos os demais campos permanecem preservados |
| rochaDirectPaymentProjections/<fingerprint Google> | set | Ler existência/conteúdo atual | uid, googleSubject, paidUntil em milissegundos e digest financeiro |
| rochaDirectPaymentAudit/<digest financeiro> | create | Existência real ainda não consultada nesta etapa | uid, actorUid, authorizationReference, previousPaidUntil, paidUntil, paymentIds e at |

O relatório privado contém, para cada documento: caminho mascarado, operação, existência, antes, depois, digest do antes, digest do depois-modelo e updateTime. Recusa create sobre auditoria/registro existente. As imagens anteriores com caminhos reais ficam SOMENTE em before-images.private.json, arquivo privado necessário ao rollback.

Operador não escolhido: authorizedBy/actorUid=null no MODELO.
Autorização não concedida: authorizationReference=null no MODELO.
Timestamp da futura execução: marcador simbólico, não data inventada.
Consequentemente, finalAuthorizationBoundDigest=null. O digest financeiro anterior não é um digest final que vincule operador, autorização, evidência da sessão e o changeset completo. changesetTemplateDigest identifica apenas o modelo atual, não o autoriza.

Não completar esses campos com o usuário do GitHub, a identidade do diagnóstico ou uma autorização fictícia. Após seleção do operador e consentimento específico, criar o envelope final e vincular seu digest ao manifesto privado e às precondições da aplicação. O verificador de autorização da futura execução precisa validar esse envelope.

## Execução privada preparada para o Work

Revisão do código privado: 62ffc28a241418def8f28140344e837d2d04974d.
Executável: backend/entitlement/diagnostics/incident_session_readiness.mjs.

Usar credenciais privadas já autorizadas no executor do Work. Este executor Codex não possui os quatro bindings privados: FIREBASE_SERVICE_ACCOUNT_JSON, MP_RECEIVING_ACCESS_TOKEN, INCIDENT_TARGET_EMAIL e INCIDENT_PAYMENT_IDS_JSON. Também é necessário EXPECTED_RECEIVING_MERCHANT_ID independente.

Não exportar segredos dos Actions por um workflow, não colocá-los no chat e não criar/mostrar chaves no GitHub. Se só existem nos Secrets do GitHub, é preciso provisionar acesso privado apropriado ao Work por canal seguro; a API GitHub não recupera os valores.

No checkout privado, com as variáveis fornecidas pelo mecanismo seguro do ambiente:
```sh
(cd backend/entitlement && npm ci --ignore-scripts --no-audit --no-fund)
export ROCHA_PRIVATE_REPORT_DIR="$(mktemp -d /tmp/rocha-incident-private.XXXXXX)"
node backend/entitlement/diagnostics/incident_session_readiness.mjs
```

O resultado fica em readiness.private.json; o baseline confidencial fica em before-images.private.json. Diretório 0700, arquivos 0600, criação exclusiva para não sobrescrever evidência anterior. Não anexar esses arquivos a issues, commits, artifacts ou logs públicos. O resultado real desta etapa ainda NÃO existe: o script foi preparado e validado com fixtures, não executado com as credenciais da cliente.

Ele faz: consulta financeira/contratual GET; leitura Auth/Firestore; captura em memória; GET de metadados do banco/regras; POST testIamPermissions (consulta de permissões, sem concessão). Nunca aplica o direito e nunca concede autorização.

## Regras de segurança e permissões

Avaliação estática estruturada: [session-security-review.json](2026-11-03-session-security-review.json). Usei a skill firebase-security-rules-auditor; ela não autoriza deploy nem alteração de regras.

- O fonte Spark histórico revisado permite get do próprio documento pelo Google subject verificado e bloqueia alteração cliente de paidUntil. Coleções novas não casadas por nenhum allow permanecem negadas nesse fonte completo.
- Isso NÃO prova o ruleset implantado. O diagnóstico privado consulta o release cloud.firestore e seu ruleset. Só conclui automaticamente quando o fonte completo coincide exatamente com o blob Spark revisado; fonte diferente exige auditoria manual de todos os matches sobrepostos.
- Os arquivos locais da raiz/backend são deny por padrão e não incluem a leitura Spark. Não substituí-los em produção.
- O Admin SDK ignora regras do cliente. A proteção das gravações administrativas depende de IAM e do operador autenticado, não de uma regra allow false.
- Diagnóstico: leitura Auth da conta selecionada, get dos documentos exatos, metadados do banco, firebaserules.releases.get/rulesets.get e testIamPermissions quando disponível. Leitura de configuração/logs é adicional e deve permanecer restrita ao projeto. Nenhuma permissão de escrita é necessária para esta etapa.
- Aplicação futura: conferir datastore.entities.get/create/update e permissões necessárias à transação no banco já selecionado, além da leitura Auth; não presumir que uma consulta de IAM no projeto comprove acesso condicional aos documentos. Não conceder delete para a recuperação inicial, nem funções de cobrança/deploy.
- IAM pode não oferecer restrição por documento/coleção. Nesse caso o invocador autenticado deve impor alvo, dois pagamentos, manifesto/digest e escopo mínimos; não descrever um papel amplo como se fosse restrito à cliente.
- Nenhuma conta cliente recebe rochaAdmin, papel IAM ou privilégio por e-mail. Operador do diagnóstico e operador da aplicação são papéis distintos.

## Plano de restauração e autorização específica

1. Confirmar sessão, build, projeto, backend e documento realmente consultado; se não for Spark, parar e preparar uma proposta adequada à fonte correta, sem duplicar direitos em várias coleções.
2. Executar o diagnóstico privado, revisar regras/IAM e reconfirmar os períodos. Capturar as imagens anteriores e precondições de versão dos cinco documentos.
3. Esclarecer contratualmente se a cliente quer manter as duas recorrências ou substituir o mensal pelo anual. Preservar ambas até decisão válida. Essa decisão não autoriza automaticamente cancelamento.
4. Selecionar operador individual autenticado. Preencher o envelope específico com alvo confirmado, dois pagamentos elegíveis, períodos, campos dos cinco documentos, baseline, digest final e referência da autorização. Submeter a prévia final; aprovação genérica do incidente não vale como autorização comercial.
5. Somente após autorização: reconsultar provedor e estado/versões dos documentos dentro do procedimento aprovado; aplicar numa transação e manter auditoria. Mudança de pagamento, baseline, identidade ou termos exige nova simulação.
6. Verificar o acesso no aplicativo real com a mesma sessão, sem alterar proteção global. A aprovação de testes de código não comprova desbloqueio.

## Rollback controlado

Rollback é outra alteração em produção e requer autorização específica, salvo se já incluído explicitamente no consentimento de aplicação.

- Antes da aplicação, guardar em custódia privada o baseline exato e suas versões; a captura de hoje não é uma transação de snapshot consistente e deve ser reconfirmada no procedimento final.
- Só reverter quando os cinco documentos e o digest ainda corresponderem à aplicação autorizada. Se houve renovação, outro pagamento, alteração administrativa ou outra execução posterior, parar e reconciliar; não sobrescrever estado novo.
- Restaurar somente paidUntil/reconciledAt aos valores e PRESENÇAS anteriores. Se o campo era ausente, removê-lo; não confundir ausência com null. Preservar trial, aviso e favoritos, inclusive alterações legítimas posteriores.
- Preservar os registros financeiros originais no provedor. Nos dois registros INTERNOS da recuperação, registrar status administrativo rolled_back para impedir reaplicação; isso não significa estorno financeiro.
- Manter a auditoria original imutável, marcar a projeção como revertida de maneira compatível com o baseline e criar uma nova auditoria de rollback vinculada ao digest anterior, operador e autorização. Não apagar rastros para fingir que nada ocorreu.
- A rotina original de recuperação rejeita registro interno cujo status deixou de ser confirmed. O procedimento operacional de rollback ainda deve ser implementado/revisado a partir do baseline real; não há rollback de produção executado ou homologado nesta etapa.

## Cobranças preservadas

Os dois contratos permanecem intactos. As agendas mensal e anual informadas no incidente não foram alteradas. Manter ambos ou substituir o mensal pelo anual exige esclarecimento com a cliente; cancelamento/renovação/cobrança/alteração de recorrência continuam fora desta autorização.

## Commits e testes desta etapa

- 03cdd335b136dd72f732035f2d847eae01b6baea: coletor Android, verificador de identidade, captura dos cinco documentos e diagnóstico de leitura.
- 8fdf12ccb4c282c0169873d1494d8be6b053fdfb: workflow somente fixtures, sem secrets.
- 62ffc28a241418def8f28140344e837d2d04974d: execução real restrita a Work privado e custódia privada das imagens anteriores.
- b4f2d4f7707f0c1bd151ab78df3c57194b323bc6: auditoria estática de segurança.
- 18afcac61508bf2abee77d3e57cc0a678d8829b8: teste adicional somente do sink privado.

[Primeiros dez testes novos no GitHub](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41697983452): sete verificações Node e três Python, aprovadas. O [teste adicional do sink privado](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41698731529) também passou no GitHub. Total desta etapa: 11 verificações novas aprovadas. Os 69 testes financeiros anteriores e o emulador anteriormente aprovado NÃO foram repetidos.

Nenhuma alteração de produção, direito comercial, cobrança, regra implantada, build congelada, design ou Roku. A solicitação de workflow com dados reais foi recusada pela revisão automática pelo risco de publicar estado privado em logs públicos. Ela não foi criada; o proprietário escolheu a alternativa privada.
