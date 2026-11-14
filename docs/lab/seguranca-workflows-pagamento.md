# Rocha+ LAB • Segurança dos workflows de contas e pagamento

Branch: `lab/seguranca-workflows-pagamento-20261114` (base `main` d18478c).
Estado: **somente edição de arquivos**. Nenhum workflow foi executado; nenhum segredo,
conta ou dado financeiro foi acessado.

## Mudanças
| Workflow | Antes | Depois |
|---|---|---|
| owner-exemption-apply.yml | concessão em produção só com frase de confirmação | exige aprovação no environment `producao-contas-escrita` |
| spark-single-account-sync.yml | rodava em push na main com segredos; UIDs sem validação no workflow | só manual; aprovação no environment (inclusive no preview, que também lê produção); UID validado (formato + iguais) no primeiro passo, antes do checkout e de qualquer segredo |
| test-subscriber-payment-audit.yml | rodava em push na main com segredos | só manual |
| resolve-test-account.yml | e-mail pessoal fixo no arquivo | e-mail vem do segredo `ROCHA_TEST_ACCOUNT_EMAIL`; falha fechado se ausente |
| tools/test_workflow_safety.py | — | contrato estático, roda no CI (`discover -s tools`) |

## Antes do merge (ação do responsável — obrigatório)
1. **Settings → Environments → New environment** `producao-contas-escrita`.
   Marcar **Required reviewers** (o responsável) e, se possível, **Deployment branches** restritas.
   ⚠️ Se o environment não existir, o GitHub o cria automaticamente **sem proteção** na primeira
   execução — a aprovação só vale depois desta configuração.
2. Recomendado: mover `FIREBASE_SERVICE_ACCOUNT_JSON` e `MP_ACCESS_TOKEN` usados para escrita para
   segredos **do environment**, para que só jobs aprovados os recebam.
3. Criar o segredo de repositório `ROCHA_TEST_ACCOUNT_EMAIL` antes de usar `resolve-test-account`.

## Limites conhecidos (não resolvidos nesta branch)
- `workflow_dispatch` usa o arquivo da branch escolhida. O job de `owner-exemption-apply` só roda a
  partir de `feat/spark-payment-confirmation-20261015`; **a cópia daquela branch continua sem a
  aprovação** até ser atualizada também. Restringir quem pode disparar workflows ou proteger
  aquela branch resolve.
- Qualquer branch pode conter um job sem `environment:`; enquanto os segredos de produção forem
  segredos **de repositório**, esse job os receberia. Mover os segredos para o environment (item 2
  acima) é o que fecha essa porta.
- O contrato é textual: cobre os segredos `FIREBASE_SERVICE_ACCOUNT_JSON`/`MP_ACCESS_TOKEN`
  (inclusive `secrets[...]` e `secrets: inherit`) e gatilhos automáticos; exige environment por
  arquivo, não por job, e reconhece escrita pela flag `--apply`.
- Scripts em `billing/tools/` daquela branch têm e-mails fixos; ficam fora do escopo (branch não-LAB).
- O projeto de produção `rocha-plus` segue fixo nos workflows de diagnóstico de leitura; a lista
  permitida está em `tools/test_workflow_safety.py`.

## Validação executada
- Contrato: 6 testes OK com as mudanças; com os arquivos originais da main, falhas detectadas.
- Auditoria cruzada (`security-reviewer`): aprovado com ressalvas; validação movida para o 1º passo e contrato reforçado.
- `actionlint` e parser YAML: sem erros nos 4 workflows alterados.
- Simulação local do passo de UID: preview passa; UIDs iguais e válidos passam; diferentes,
  injeção (`a;echo`, `$(id)`) e vazios são bloqueados.
