# Rocha+ — instruções para o Claude Code (ambiente LAB)

Projeto: Rocha+ TV (Flutter, celular + TV). Repositório `japarocha2-cloud/rocha-plus`.
Responsável: Japa. Idioma de trabalho: português.

## Regras obrigatórias
- Trabalhar somente em branches `lab/*` isoladas. Nunca commitar em `main`.
- Preservar integralmente a **Candidata 6** e o **catálogo oficial congelado (479 registros)**.
- Nunca fazer merge, deploy, publicação, `git push`, `workflow_dispatch`, cobrança real,
  alteração financeira, exclusão destrutiva ou uso de API paga sem autorização explícita do Japa.
- Não alterar pagamentos nem dados reais de clientes.
- Não afirmar que teste ou correção foi concluído sem evidência (comando + resultado).
- Antes de mexer em arquivos: conferir branch ativa, histórico (`git log`) e resultados de testes
  existentes. Não repetir diagnóstico já concluído (ver `.rocha-support/CHECKPOINT-CENTRAL-*.md`).
- Priorizar soluções gratuitas.

## Áreas protegidas (somente leitura)
Ver lista completa em `.rocha-support/CENTRAL-AGENTES-ECC.md`. Resumo: branches `*candidate6*`,
catálogo oficial (`lib/src/live/channel_repository.dart`, `open_tv_channels.dart`, `channel_blocks.dart`),
`.github/workflows/build.yml`, `soul-tv-build-dispatch.yml`, workflows de pagamento/conta,
`tools/prepare_signed_build.py` e segredos.

## Delegação para agentes ECC (plugin `ecc`)
Delegar com o Agent tool; o mapa completo está em `.rocha-support/CENTRAL-AGENTES-ECC.md`.

| Tarefa | Agente |
|---|---|
| Planejar / mapear código | `ecc:planner`, `ecc:code-explorer`, `ecc:architect` |
| Revisão Dart/Flutter | `ecc:flutter-reviewer`, `ecc:code-reviewer` |
| Build Flutter quebrado | `ecc:dart-build-resolver` |
| Código morto / erros silenciosos | `ecc:refactor-cleaner`, `ecc:silent-failure-hunter` |
| Testes | `ecc:tdd-guide`, `ecc:pr-test-analyzer`, `ecc:e2e-runner` |
| Segurança / segredos / workflows | `ecc:security-reviewer` |
| Scripts Python em `tools/` | `ecc:python-reviewer` |
| Acessibilidade / foco de TV | `ecc:a11y-architect` |
| Documentação | `ecc:doc-updater` |
| Avaliação da entrega | `ecc:agent-evaluator` |

Todo agente delegado herda estas regras: o prompt de delegação deve repetir
"somente LAB, sem push/merge/deploy, áreas protegidas somente leitura".

## Verificações padrão
- `python3 tools/rocha_quality_guard.py`
- `cd tools && python3 -m unittest discover`
- `flutter analyze` e `flutter test` (SDK local; o CI fixa Flutter 3.47.6)

## Relatório final de cada tarefa
Correções · testes executados (comando e resultado) · falhas · pendências.
