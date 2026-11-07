> [!WARNING]
> **⚠️ NÃO SOLICITAR APROVAÇÃO MANUAL DO CATÁLOGO DA CANDIDATA 6.**
> O catálogo da Candidata 6 **JÁ FOI APROVADO EM TESTES FÍSICOS**, realizados de **19/10/2026 a 21/10/2026**, com **180 segundos por canal** e validação de **áudio e imagem**. Não exigir nova aprovação manual nem reabrir a homologação integral dos canais já aprovados. Preservar o catálogo e os resultados históricos. Na Candidata 7, verificar somente a fidelidade da migração e as alterações, novos canais ou regressões efetivas. A existência de arquivos LAB com status `pending` não revoga a aprovação física da Candidata 6.

# Candidata 7 — auditoria do catálogo — 07/11/2026

A Candidata 6 permanece congelada. Não fazer merge ou publicar.

- Catálogo de referência da Candidata 6: 430 canais, segundo validação física anterior.
- `branding/lab_candidates.json` na Candidata 7: 479 registros, todos `pending`.
- `branding/lab_approved.json`: `[]` (zero aprovados neste arquivo).
- Não existe evidência suficiente para declarar que o catálogo de 430 canais está integralmente preservado no APK futuro.
- Correções de URLs de CazéTV, Globo, HISTORY e Rá-Tim-Bum estão presentes no repositório.
- Planos de R$ 7,90 e R$ 86,90 estão no código da tela de assinatura.
- Aviso de sete dias existente: preservar lógica, alterar somente visual.

## Histórico de homologação física da Candidata 6 — registro informado pelo responsável

**Período:** 19/10/2026 a 21/10/2026 (dois dias inteiros de testes).

**Resultado informado:** catálogo da Candidata 6 **APROVADO**. Em cada canal, foram verificados **áudio e imagem durante 180 segundos**, com aprovação de ambos os critérios. A duração de 180 segundos por canal explica o período de dois dias dedicado à avaliação.

**Preservação:** esta aprovação histórica é a referência para a Candidata 7. Não reclassificar os canais já aprovados como reprovados nem exigir repetição integral dos testes sem alteração relacionada ou evidência de regressão. A equivalência do catálogo da Candidata 7 com a Candidata 6 ainda precisa ser conferida; este registro não afirma que o APK da Candidata 7 foi testado.

**Origem do registro:** declaração do responsável pelo projeto em 07/11/2026; não equivale a logs brutos de reprodução anexados nesta auditoria.

## Bloqueio de homologação
Antes de compilar para teste físico, comparar manifesto efetivo da Candidata 6 com o catálogo carregado pela Candidata 7, reconciliando nome, identidade, URL, categoria, ordem e capa. Não converter 479 pendentes em aprovados automaticamente.

Depois verificar login, exibição de assinaturas, trial existente, checkout homologado sem cobrança real, reprodução e testes Flutter. Não afirmar que está pronto antes dos testes e da geração de APK funcional.

## Verificação do pipeline Android (07/11/2026)

O workflow `.github/workflows/build.yml` oferece `workflow_dispatch` com `signed_login=true` para gerar APK universal e ARM64 com Firebase e assinatura, sujeito à existência dos secrets e à conclusão do CI. Na branch Candidata 7, **não** selecionar `subscription_lab=true` antes da homologação de direitos e pagamentos. O fluxo de prévia `ROCHA_LAYOUT_PREVIEW=true` gera APK **sem canais** e não é uma entrega funcional da Candidata 7. O build de laboratório por PR pode usar `ROCHA_FULL_UI_LAB=true`, mas não substitui a validação de login e assinatura reais.

**Não foi disparado workflow nesta etapa; não há APK compilado ou teste físico novo confirmado.**

**Critério de liberação:** somente APK assinado funcional, com catálogo reconciliado com a Candidata 6, e verificação de reprodução, navegação, login e assinaturas. Não repetir aprovação manual do catálogo congelado.
