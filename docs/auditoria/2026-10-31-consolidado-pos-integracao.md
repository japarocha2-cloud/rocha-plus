# Rocha+ TV — Consolidado pós-integração e continuidade sem retrabalho

Registro de continuidade em 31/10/2026. Este documento preserva conclusões verificadas no GitHub e separa o que foi comprovado por CI daquilo que ainda exige ambiente privado ou teste físico.

## Governança e estado das branches

- Repositório: `japarocha2-cloud/rocha-plus`.
- Branch de homologação: `homolog/technical-candidate-20261028`.
- PR #44: **integrado mediante autorização expressa do proprietário**, merge commit `f30457c9c75b475b12212b510841180f30beceec`; conferido no GitHub como merged/closed. Branch de homologação idêntica ao merge commit após integração.
- PR #42: **open/draft, não integrado**; branch experimental `fix/subscription-access-20261026` preservada.
- Versão oficial congelada. Sem publicação, deploy, cobrança real, alteração visual ou troca do APK público. Rocha+ Office permanece independente.
- PR #44 deixou de ser draft apenas para permitir o merge autorizado. Não tratá-lo como ainda draft.
- Não repetir itens verdes sem mudança relacionada, regressão reproduzível ou evidência contraditória. Teste físico nº 6 permanece verde/congelado.

## Verdes comprovados — preservar

- Identidade/certificado: commit `cd239d109c664048eebdbc8d383582dad5a2471a` exige, em `prepare` e `verify`, o assinante público aprovado. Testes de regressão para certificados não aprovados adicionados.
- CI Candidate Identity Guards #26: run `41221538520`, **success**.
- CI Subscription safety checks #131: run `41221538508`, **success** (Flutter, entitlement, backend, Android); job de APK experimental **skipped**. Evidências anteriores #23 e #129 também verdes.
- Trial sandbox: commit `02593ee34f8f987f98840adae0b035ce51840101`, CI `41222167987` **success**. Ensaio Firestore Emulator → endpoint → respostas JSON → gate Flutter, com ativação experimental apenas no processo de teste. Trial exatamente 7 dias, concessão única sob quatro consultas simultâneas, negação no vencimento exato, bloqueio após rechecagem, renovação fictícia, direitos independentes e estornos fictícios.
- Sandbox fictício isolado `demo-rocha-sandbox`, sem chamadas externas ao provedor; candidata padrão mantém gate de vencimento desligado. Esses testes **não** comprovam integração com rede real, pagamentos ou APK físico.
- LibVLC, ExoPlayer e Chromecast: auditoria do Codex não encontrou nova falha reproduzível; **não** afirmar homologação física com base apenas na revisão de código.
- Scripts de preflight, roteiro físico e procedimento de homologação preparados; isso **não** significa execução do build assinado.

## Pendências únicas — próxima execução autorizada

1. No ambiente privado disponível a partir de 04/11/2026, confirmar Firebase/OAuth da candidata e custódia da chave existente (`candidate.p12`, `signing.json`, sem copiar ao Git/logs). `firebaseProvisioning: pending` permanece até prova contrária.
2. Verificar se ambiente Android SDK/Flutter e scripts de build estão prontos. Executar preparação manual exclusivamente para a candidata, respeitando verificações de branch e identidade.
3. Compilar e assinar APK privado `com.rochaplus.app.candidate`, versão `0.1.0-candidate.1`, versionCode `1`; verificar pacote, ABI, versão, SHA-1/SHA-256 do certificado aprovado, assinatura apksigner e hash do APK. Não publicar.
4. Instalar apenas no aparelho de teste autorizado e validar login, foco/controle remoto, LibVLC/ExoPlayer, reprodução contínua, Cast/reconexão e trial/expiração com sandbox explicitamente aprovado. Preservar teste físico nº 6 salvo regressão.
5. Registrar modelo do aparelho, evidências, resultados e somente novas falhas reproduzíveis; CI verde não substitui teste físico. Decisão de distribuição exige aprovação separada.

## Política de retomada

- Ler **este consolidado** e `docs/auditoria/2026-10-31-portoes-homologacao-candidata.md` antes de executar tarefas.
- Trabalhar somente nas pendências acima; **não refazer** auditorias, verificações e testes verdes por rotina.
- Registrar no fim de cada etapa: data, branch, commits, CI com links e resultados, evidência, status 🟢/🟡/🔴, bloqueios e próximo passo. Não afirmar persistência sem commit.
- Nunca modificar visual aprovado, remover canais sem evidência, misturar Office/TV, executar pagamento real, alterar Oficial, fazer deploy ou publicar sem autorização específica.
