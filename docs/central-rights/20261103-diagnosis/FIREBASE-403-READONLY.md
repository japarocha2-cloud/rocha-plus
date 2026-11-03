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
