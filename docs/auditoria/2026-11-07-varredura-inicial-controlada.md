# ROCHA+ TV — Varredura inicial controlada — 2026-11-07

## Escopo e proteção
- Branch de auditoria: `audit/complete-sweep-20261107`, derivada de `lab/cazetv-link-only-20261106`.
- Não modificar versões oficiais ou Candidata 6 congelada, coleções Firebase, pagamentos, catálogo ou Roku.
- Exclusões só após prova de ausência de referências, função operacional, valor de backup e impacto de rollback.

## Evidências de CI
- GitHub Actions 42321576748 (Build Rocha+), 42321576755 (Rocha LAB Android evidence), 42321576628 (Subscription safety checks), 42321568774 (LAB catalog corrections validation) falharam no Flutter suite.
- Na execução 42321576628, Flutter: **233 testes passaram e 2 falharam**.
- Ambas as falhas: `test/subscription_screen_test.dart`, teste `subscription is reachable from Home` nas dimensões 320x568 e 1920x1080.
- Stack: `StateError: Bad state: No element` na linha 21, ao buscar `Assinatura`.
- Código da Home em `lib/src/screens/home_screen.dart`: menu Assinatura condicionado a `widget.accountUid != null` (linha 227 na branch de origem).
- Teste não fornecia `accountUid`. Corrigido **somente o fixture do teste** com UID fictício. Política de interface e autenticação preservada.
- Testes locais não executados nesta sessão. Necessária confirmação CI na nova branch.

## Inventário exploratório
- Árvore `fix/subscription-access-20261026`: 275 entradas, não truncada.
- Árvore `fix/sandbox-payment-isolation-20261106`: 353 arquivos regulares, não truncada. São branches diferentes e não devem ser misturadas.
- Branch `work/code-sweep` existe e contém histórico de trabalho anterior; NÃO é base desta correção.
- Arquivos grandes de branding, lockfiles, templates e relatórios não são automaticamente lixo.
- Não foi comprovado arquivo morto ou corrompido que possa ser excluído com segurança na etapa inicial; nenhuma exclusão realizada.

## Acompanhamento das funções
- Auditoria Geral: inventário e falhas confirmadas.
- Histórico: identificação dos congelamentos e branch anterior `work/code-sweep`.
- Desenvolvimento: correção isolada do fixture de assinatura, sem alterar o APK.
- Qualidade: pendente CI da branch isolada e avaliação de regressões.
- Infraestrutura e Pagamentos: somente revisão dos resultados já comprovados, sem novos deploys.

## Próximas verificações
1. CI para a branch de auditoria e interpretação de falhas novas ou preexistentes.
2. Inventariar referências dos arquivos candidatos à exclusão em cada branch-alvo.
3. Validar integridade de blobs de texto e assets no checkout completo; API de árvore não comprova integridade do conteúdo.
4. Registrar candidatos a remoção com justificativa e rollback antes de excluir.
