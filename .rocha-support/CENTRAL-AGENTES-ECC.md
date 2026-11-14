# Rocha+ • Central Multiagente ECC (LAB)

Branch de origem: `lab/central-agentes-ecc-20261113` (criada a partir de `main` @ `d18478c`).
Estado: **configuração inicial — somente diagnóstico**. Nenhum código funcional alterado.

Complementa `COORDENADOR.md`: os suportes fixos continuam valendo; esta central apenas
mapeia cada suporte para os agentes especializados do plugin ECC.

## Mapa suporte → agentes ECC

| Suporte Rocha+ | Agentes ECC | Papel |
|---|---|---|
| Coordenação (programação/arquitetura) | `ecc:planner`, `ecc:architect`, `ecc:code-architect`, `ecc:code-explorer` | planejar, desenhar e mapear antes de mudar |
| Suporte 1 — Limpeza/Qualidade | `ecc:flutter-reviewer`, `ecc:code-reviewer`, `ecc:refactor-cleaner`, `ecc:silent-failure-hunter`, `ecc:dart-build-resolver` | revisão Dart/Flutter, código morto, erros silenciosos, build |
| Suporte 2 — Visual/Expansão | `ecc:a11y-architect`, `ecc:flutter-reviewer` | foco de TV, acessibilidade, responsividade (referência visual bloqueada em `VISUAL.md`) |
| Suporte 3 — Administrativo/Jurídico | `ecc:doc-updater` | documentação; nunca altera código funcional |
| Testes e Compatibilidade | `ecc:tdd-guide`, `ecc:pr-test-analyzer`, `ecc:e2e-runner` | testes primeiro, cobertura, fluxos críticos |
| Auditoria/Segurança | `ecc:security-reviewer`, `ecc:python-reviewer` (tools/), `ecc:agent-evaluator` | segredos, OWASP, scripts Python, avaliação de entrega |

Comandos ECC úteis: `/ecc:flutter-review`, `/ecc:flutter-test`, `/ecc:flutter-build`,
`/ecc:code-review`, `/ecc:security-scan`, `/ecc:harness-audit`, `/ecc:orch-fix-defect`.

## Fluxo padrão de uma tarefa

1. Coordenação verifica branch ativa, histórico e testes existentes (não repetir diagnóstico concluído).
2. `ecc:planner` ou `ecc:code-explorer` delimita a mudança.
3. Implementação só em branch `lab/*` isolada.
4. Suporte 1 roda: `python3 tools/rocha_quality_guard.py`, testes Python (`cd tools && python3 -m unittest`),
   `flutter analyze` e `flutter test` quando o SDK estiver disponível.
5. `ecc:code-reviewer` / `ecc:flutter-reviewer` + `ecc:security-reviewer` revisam o diff.
6. Relatório: correções, testes executados, falhas e pendências.

## Áreas protegidas (somente leitura para agentes)

- **Candidata 6**: branches `lab/candidate6-*`, `work/candidate6-*` — não tocar.
- **Catálogo oficial aprovado**: `lab/catalogo-unico-oficial-*`, `lib/src/live/channel_repository.dart`,
  `lib/src/live/open_tv_channels.dart`, `lib/src/live/channel_blocks.dart`.
- **Produção**: `main`, `.github/workflows/build.yml`, `soul-tv-build-dispatch.yml` (disparam em push na `main`).
- **Pagamentos/contas**: `owner-exemption-apply.yml`, `spark-*.yml`, `*payment*`, `*receipt*`,
  `single-account-diagnosis.yml`, `resolve-test-account.yml` — não disparar nem editar.
- **Credenciais/assinatura**: `tools/prepare_signed_build.py`, segredos do GitHub/Firebase.

## Proibido sem autorização explícita do responsável

Merge, deploy, publicação em loja, `workflow_dispatch`, cobrança real, alteração financeira,
exclusão destrutiva (inclusive de branches), uso de APIs pagas e ferramentas MCP de escrita
(Firebase deploy, anúncios, redes sociais, e-mail).

Checkpoint de retomada: `CHECKPOINT-CENTRAL-20261113.md`. Roteamento de modelos: branch `lab/roteamento-modelos-sim-20261113`, `docs/lab/roteamento-modelos.md`.
