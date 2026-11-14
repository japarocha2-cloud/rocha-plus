# Checkpoint • Central ECC • sessão LAB 13–14/11/2026

Retomar daqui. Nada foi enviado ao GitHub (push HTTP 403 — Claude GitHub App sem acesso de
escrita). Recuperação por bundle/patch em `recuperacao-lab/` (fora do git, ver README de lá).

## Branches LAB locais (todas a partir de main d18478c)
| Branch | Commits | Conteúdo |
|---|---|---|
| lab/central-agentes-ecc-20261113 | 7164c7c + este checkpoint | central ECC, checkpoint |
| lab/qualidade-tools-20261113 | a793486, a185c0b | regex loopback do Quality Guard, sys.path dos testes, testes novos |
| lab/roteamento-modelos-sim-20261113 | eeeb2ca | protótipo LiteLLM só com mocks + limites |

## Testes executados
- Quality Guard (main): APROVADO estático, 57 arquivos Dart.
- Python tools (branch qualidade): 8/8 OK da raiz e via `discover` (CI).
- Flutter 3.50.0 (local; CI fixa 3.47.6) em main d18478c: `flutter test` 92/92 OK;
  `flutter analyze` 28 infos `deprecated_member_use` (material.dart), 0 warnings, 0 erros.
- Roteamento: fallback 429 → modelo B simulado, também com rede bloqueada.
- Catálogo congelado 08/11: SHA-256 do JSON e do CSV conferem com SHA256SUMS.json; CSV = 479.

## Achados principais (somente leitura, não corrigidos — áreas protegidas)
- ALTO: limites 1 celular / 2 TVs / 2 reproduções não aplicados em nenhum backend encontrado.
- ALTO: workflows de contas/pagamento fixos no projeto de produção `rocha-plus`, sem
  `environment` com aprovação; owner-exemption-apply concede direito só com string de confirmação;
  resolve-test-account.yml contém e-mail real fixo.
- MÉDIO: spark-single-account-sync sem validação regex de UID; dispara em push na main.
- MÉDIO (C7): falha de rede na verificação de assinatura aparece como "sem assinatura";
  códigos de erro Google/Firebase não registrados; workflow físico C7 não passa
  `ROCHA_C7_SUBSCRIPTION_QUERY`; versionCode = 738 + run_number (não 738 fixo).
- Catálogo: 479 (CSV/quantidade_base) vs 483 (JSON com 4 adições: CazéTV, TV Rá-Tim-Bum HD,
  Record TV MT, Telecine Action). Não reconciliado. Roku: 607/608.
- Roku: todos os elementos visuais exigidos presentes no código; sem evidência de teste físico.
- Trial: servidor, 7×24h, `tx.create` por UID — reinstalação/novo login não reinicia.

## Próximas ações sugeridas (dependem de autorização)
1. Corrigir acesso de escrita do Claude GitHub App e enviar as 3 branches.
2. Decidir correções nos workflows de pagamento (áreas protegidas).
3. Implementar limites de dispositivos no backend de homologação, com testes.
