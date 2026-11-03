# Rocha+ LAB — diagnóstico não invasivo de HTTP 403 (03/11/2026)

Escopo: `lab/roku-visual-covers-performance-20261102`. Somente análise de código e evidências versionadas; sem alterações de IAM, Firebase, segredos, produção ou direitos. Não foram repetidos testes aprovados.

## Evidência existente e requisições

Fonte: `experiments/central-rights/run-audit.mjs`, workflow `.github/workflows/central-rights-lab.yml`, `docs/central-rights/20261102/authenticated-audit.json`, execução histórica 41551744667.

A rotina inicializa `firebase-admin` com `FIREBASE_SERVICE_ACCOUNT_JSON` do GitHub Actions e valida `key.project_id === 'rocha-plus'`; em seguida obtém `app.options.credential.getAccessToken()` e envia `Authorization: Bearer` às APIs Google.

| Chamada | Projeto/endpoint | Resultado registrado | Permissão indicada |
|---|---|---|---|
| GET Cloud Functions v2 list | `cloudfunctions.googleapis.com/v2/projects/rocha-plus/locations/southamerica-east1/functions` | HTTP 403 | `cloudfunctions.functions.list` |
| POST Cloud Logging entries:list | `logging.googleapis.com/v2/entries:list`, `resourceNames: ['projects/rocha-plus']` | HTTP 403 | `logging.logEntries.list` |
| GET Firestore database metadata | `firestore.googleapis.com/v1/projects/rocha-plus/databases/(default)` | Leitura registrada como bem-sucedida | não demonstra permissão para funções/logs |

As leituras de conta e Firestore comercial foram registradas como bem-sucedidas nessa auditoria. Portanto, token totalmente ausente ou projeto comercial inteiramente inacessível não são explicações adequadas para **essas duas** chamadas. Um 403, isoladamente, não prova API habilitada nem qual privilégio faltou: o código guarda apenas status HTTP, descartando o corpo de erro e headers de diagnóstico.

## Identidade que fez a chamada

Identidade **por tipo e origem**: conta de serviço presente no segredo `FIREBASE_SERVICE_ACCOUNT_JSON` do GitHub Actions; token derivado dessa credencial, não do Owner humano. O validador exigia projeto `rocha-plus`. **E-mail exato da conta de serviço não registrado em evidência pública sanitizada**; não inferir que seja a conta padrão `firebase-adminsdk` apenas pela existência dela no console.

Para fechar a identidade sem divulgar dados sensíveis: numa futura auditoria autorizada, registrar apenas e-mail da conta de serviço (não segredo), identificador do run/job, projeto, databaseId, endpoint, status HTTP e o par `error.status/error.message` sanitizado da resposta. Consultar Audit Logs de autenticação/permissão somente se o acesso estiver previamente autorizado; não elevar privilégios como teste.

## Separação de projetos

O 403 documentado está associado a `rocha-plus` comercial e database `(default)`. A confirmação visual do proprietário quanto a `rocha-plus-homologacao`, Firestore existente, Owner e Blaze **não é evidência da identidade, projeto ou banco consultados por essa execução**. O runtime experimental exige verificar de modo independente `config.labProjectId`, `labDb.projectId` e `commercialReadDb.projectId`; nenhuma configuração operacional atual foi atestada nesta análise.

## Permissões mínimas e proposta segura

- Para **diagnóstico administrativo somente leitura** de Functions: `cloudfunctions.functions.list` limitado ao projeto/escopo relevante; para leitura de logs: `logging.logEntries.list` com escopo restrito e sem divulgar payloads. Ambas são necessidades da auditoria, **não permissões automaticamente exigidas pelo runtime do Rocha+**.
- Para **runtime experimental**, determinar permissões a partir de chamadas reais de `experiments/central-rights/firebase-runtime.mjs`, `read-source.mjs` e `firestore-adapters.mjs`: Firebase Auth para verificar token/ler usuário, leitura dos documentos comerciais existentes, e transações apenas no banco LAB isolado. Não adicionar privilégios de listagem administrativa caso o runtime não invoque essas APIs.
- Não compartilhar ou gerar chave JSON privada; preferir identidade de execução gerenciada/credenciais efêmeras com escopo mínimo, após desenho e autorização. Não usar credencial comercial para escrever no LAB.
- Antes de qualquer alteração: obter o corpo sanitizado de ambos os 403 e o principal efetivo, verificar enablement das APIs Cloud Functions/Logging e escopo do recurso. Aplicar eventual ajuste IAM/API somente após aprovação explícita do proprietário.

## Conclusão

**Comprovado:** as chamadas de listagem de Cloud Functions e de logs no projeto `rocha-plus` retornaram 403 numa auditoria com token de conta de serviço; há compatibilidade com falta de permissão para essas operações. **Não comprovado:** principal exato, corpo de erro do Google, se a API está desabilitada ou se há restrição organizacional, nem se esses 403 correspondem ao problema operacional atual do `rocha-plus-homologacao`.

Status: **AMARELO (diagnóstico parcial)**. Nenhum IAM/API/deploy/pagamento/arte/arquivo executável alterado.


## Fechamento cruzado com a passagem final e logs CI — 03/11/2026

Fontes lidas sem reexecução: `docs/central-rights/20261103-readiness/FINAL-HANDOFF.md`, `firebase-readonly-results.json`, `actual-preparation-state.json`, `experiments/roku-readiness/firebase-readonly.mjs`, `.github/workflows/roku-readiness.yml` e logs originais dos jobs listados abaixo. Inspeção somente leitura; nenhuma credencial, token ou mensagem pessoal reproduzida.

### Incidentes separados

| Incidente | Execução e job GitHub Actions | Requisição e projeto | Resultado |
|---|---|---|---|
| Comercial: inventário de Functions | [run 41551744667](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41551744667), job `125640755110` | GET `https://cloudfunctions.googleapis.com/v2/projects/rocha-plus/locations/southamerica-east1/functions` | HTTP 403; `cloudfunctions.functions.list` é a operação de leitura necessária |
| Comercial: logs de webhook | Mesmo run/job | POST `https://logging.googleapis.com/v2/entries:list`, `resourceNames: ['projects/rocha-plus']` | HTTP 403; `logging.logEntries.list` é a operação de leitura necessária |
| LAB: metadados Firestore | [run 41619638681](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41619638681), job `125861783179` | GET `https://firestore.googleapis.com/v1/projects/rocha-plus-homologacao/databases/(default)` | HTTP 403, `type:null` (tipo não observado) |
| LAB: consulta de permissões | Mesmo run/job | POST `https://cloudresourcemanager.googleapis.com/v1/projects/rocha-plus-homologacao:testIamPermissions` | HTTP 200; `effectivePermissions:null` (nenhuma permissão listada na resposta sanitizada, não prova inexistência do banco) |

No mesmo run do LAB, o GET de metadados de `rocha-plus/databases/(default)` respondeu 200 e `testIamPermissions` comercial respondeu 200, listando `datastore.entities.get/create/update/delete`, `firebaseauth.configs.get` e `firebaseauth.users.get`. Essas permissões de escrita **observadas** não foram usadas e tornam a credencial atual imprópria para ser simplesmente reutilizada como identidade de host LAB mínimo privilégio.

### Identidade efetiva e limites de evidência

Os dois workflows passam o mesmo segredo **nomeado** `FIREBASE_SERVICE_ACCOUNT_JSON` para o processo Node, que usa `firebase-admin` / `cert(key)` e `app.options.credential.getAccessToken()`. Os dois scripts exigem `key.project_id === 'rocha-plus'`. Logo, o principal efetivo é uma conta de serviço carregada pelo segredo do GitHub Actions para o projeto comercial, **não a sessão Owner do proprietário**. O e-mail exato, `client_email` e eventual versão/rotação desse segredo **não estão disponíveis nos registros sanitizados**. O mesmo nome do segredo em diferentes execuções não prova byte a byte que sua credencial permaneceu idêntica; não é correto inferir que a conta padrão `firebase-adminsdk` seja a usada.

Os logs originais das duas execuções foram conferidos. Contêm, respectivamente, apenas registros `CENTRAL_AUDIT` e `READINESS_AUDIT` com HTTP 403 e status sanitizados. Não contêm um corpo de resposta `error.status/error.message` atribuído ao Google, porque `run-audit.mjs` e `firebase-readonly.mjs` descartam `r.json()` quando `r.ok === false`. **Nenhuma mensagem de erro adicional recuperável nesses logs**. Não atribuir códigos textuais como `PERMISSION_DENIED` sem o corpo verdadeiro.

### databaseIds e papéis diferentes

As URLs consultadas explicitamente usam databaseId `(default)` em ambos os projetos. Isso confirma o alvo das requisições, **não que `(default)` exista ou seja o banco correto de implantação LAB**. A evidência visual do console do proprietário de banco existente/Owner/Blaze não prova que o mesmo principal e databaseId sejam usados na execução. Verificar banco real antes de considerar mudar permissão; conta do proprietário e conta de serviço do CI são identidades diferentes.

O runtime experimental em `experiments/central-rights/firebase-runtime.mjs` usa Auth comercial `rocha-plus`, `commercialReadDb` comercial e `labDb` separado, passado explicitamente por configuração. `read-source.mjs` faz `auth.getUser(uid)` e leituras documentais de `rochaSparkAccounts` no comercial e `rochaCentralLabAccounts` no LAB. `firestore-adapters.mjs` executa transações de sessões/pagamentos **apenas no LAB**, e rejeita `rocha-plus` e `rocha-plus-candidate` como destino de escrita. O cliente Roku não precisa receber permissões IAM para listar Functions ou logs; a identidade do host HTTPS (ainda não implantado) é que precisaria permissões de Auth/documentos e transações no LAB.

### Correção mínima proposta, NÃO aplicada

1. **403 comercial:** somente se for indispensável continuar auditoria administrativa, confirmar a identidade exata do run e resposta de erro sanitizada; então submeter para aprovação apenas `cloudfunctions.functions.list` e/ou `logging.logEntries.list` em escopo mínimo. Alternativamente, manter esse inventário indisponível; essas permissões não são requisito do player ou login Roku.
2. **403 LAB:** confirmar em acesso de leitura autorizado o *projectId* e o *databaseId* reais, o principal efetivo de execução e o corpo sanitizado do 403; verificar separadamente API habilitada, escopo e política IAM. Preparar identidade de host dedicada, preferencialmente federada/gerenciada sem chave privada, com Auth/leituras comerciais estritamente necessárias e acesso a documentos/transações no LAB somente. Revisar políticas antes de solicitar aprovação; **não conceder** `Owner`, `Editor` nem papéis amplos como solução rápida.
3. **Bloqueio atual:** `runtime.example.json` e preparação Roku permanecem desativados, `labProjectId` vazio, host/origin/certificado não definidos, `activationAllowed:false`. Corrigir um 403, por si só, não ativa o Roku ou valida mídia em equipamento real.

**Próxima ação necessária do proprietário:** autorizar especificamente uma **coleta somente leitura de diagnóstico sanitizado** da identidade da conta de serviço usada pelo CI e do corpo do 403 do LAB (ou fornecer exportação sanitizada dessas informações), junto da confirmação do projectId/databaseId no console. Isso não autoriza ajuste de IAM/API nem ativação do host. Depois apresentar proposta exata de menor privilégio para aprovação separada.

**Estado:** incidente comercial identificado nas APIs administrativas; incidente LAB localizado em run/job/requisição, mas causa raiz exata ainda não fechada. **AMARELO.** Nenhum teste reaplicado, nenhuma alteração fora desta documentação.


## Missão mestre 03/11 — coleta limitada autorizada

A nova ordem autorizou uma única consulta diagnóstica restrita a **metadados do Firestore LAB**, sem documentos pessoais, assinaturas, pagamentos ou trials e sem mudanças IAM/API/Secrets. O script `experiments/roku-readiness/firebase-403-closeout.mjs` foi adicionado na branch LAB: obtém em memória token da credencial CI existente; registra o e-mail de serviço e projectId da identidade (nunca chave/token); consulta somente `rocha-plus-homologacao/databases/(default)` e estado da API Firestore via GET; limita/sanitiza o corpo de eventual erro Google. Workflow novo `.github/workflows/roku-lab-403-closeout.yml` com `contents:read`, branch LAB, sem direito GitHub de escrita.

**Ainda não existe resultado de novo job recuperado/verificado nesta sessão.** Não afirmar identidade exata nem corpo do Google com base apenas no script. Evidências históricas verificadas: [run LAB 41619638681](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41619638681) e [run comercial 41551744667](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41551744667).

Próxima etapa: caso o workflow novo produza `LAB403_CLOSEOUT`, ler e registrar uma única vez o resultado sanitizado e parar se inconclusivo, sem repetir testes aprovados. `errorStatus`/mensagem poderá distinguir falta de permissão, API desativada, projeto/banco incorreto ou restrição. **Nenhuma permissão aplicada.**

Plano de HTTPS, identidade de host independente e alternativas de QR/código numérico (apenas preparação, sem ativação) documentado em `docs/central-rights/20261103-readiness/ROKU-LAB-HTTPS-PAIRING-PREP.md`.
