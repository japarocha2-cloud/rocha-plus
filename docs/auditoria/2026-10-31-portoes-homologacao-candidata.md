# Rocha+ TV — Portões de homologação da candidata (31/10/2026)

Escopo: branch de trabalho `work/candidate-build-guard-20261031` -> PR #44 -> `homolog/technical-candidate-20261028`. Não alterar Oficial, LAB, PR #42, artes, catálogo ou testes verdes congelados.

## 1. Integração controlada
- [x] Comparação do PR #44: 10 commits à frente, zero atrás, cinco arquivos novos; sem modificações nos arquivos existentes da candidata.
- [x] CI #119 Subscription safety checks: sucesso; Flutter, backend, entitlement e configuração Android aprovados; APK experimental ignorado.
- [x] CI #9 Candidate Identity Guards: sucesso, incluindo regressões de SHA-1/SHA-256 incorretos.
- [ ] PR #44 permanece draft e sem merge. Integração depende de autorização explícita que revogue a restrição de não fazer merge; nenhum merge automático.

- [x] Commit `7adf115`: testes adicionais para impedir projeto Firebase oficial, pacote oficial, aprovação de produção e SHA-1 ausente. CI #12 (`41217447670`) aprovado; CI geral #121 (`41217447698`) aprovado, inclusive Flutter.

- [x] Commit `6a6fa50`: quatro testes extras de Firebase/OAuth (duplicidade, chave ausente, app ID incompatível e múltiplos OAuth web). CI #15 (`41219317459`) aprovado; CI geral #123 (`41219317444`) aprovado, incluindo Flutter.

## 2. Firebase/OAuth e assinatura
- [x] Identidade pública esperada: `com.rochaplus.app.candidate`; projeto `rocha-plus-candidate`; SHA-1/SHA-256 em `tools/candidate/signer-public.json`.
- [x] Preflight compara as impressões públicas aos valores aprovados, sem ler segredos.
- [ ] Confirmar no ambiente privado a presença e custódia de `candidate.p12`, `signing.json` e `google-services.json`; nunca copiar para Git/logs/artifacts.
- [ ] Verificar no Firebase real o registro Android, OAuth web e hash do certificado. O campo `firebaseProvisioning: pending` e o README podem estar desatualizados; não alterar sem prova.
- [ ] Executar `prepare_candidate.py prepare` somente na branch exata de homologação, via disparo manual, com diretório privado externo ao checkout.

## 3. APK candidato
- [ ] Compilar `com.rochaplus.app.candidate`, versão `0.1.0-candidate.1`, versionCode `1`, usando apenas chave da candidata.
- [ ] Executar `prepare_candidate.py verify` com ferramentas Android reais: pacote, versão, ABI ARM64, assinatura apksigner, SHA-1/SHA-256 e SHA-256 do APK.
- [ ] Manter APK privado, sem deploy, publicação, troca de APK oficial ou cobrança real.
- [ ] Se faltarem credenciais ou SDK, registrar bloqueio; não improvisar chaves ou dados Firebase.

## 4. Aparelho físico
- [ ] Após APK candidato validado, instalar somente no aparelho de teste autorizado; verificar login, controle remoto/foco, LibVLC/ExoPlayer, reprodução contínua, Cast e cenários sandbox de trial/expiração.
- [ ] Registrar evidência, modelo do aparelho, versão, resultado, falhas reproduzíveis e correções.
- [x] Teste físico nº 6 permanece verde e congelado; não repetir sem alteração relacionada, regressão ou evidência contraditória.

## Regras permanentes
Sem merge do PR #42/#44, publicação, pagamentos reais, alteração da versão oficial ou mudança visual sem aprovação expressa. Resultados verdes anteriores não comprovam assinatura de APK real nem homologação física.


## Continuidade — CI #125 e preparação física

- 🟢 Commit `02c90d3`: testes simulados do verificador APK ampliados (versionName, ABI não permitida e ausência de SHA-1). CI Candidate Identity Guards #18 (`41219607566`) **success**; CI geral Subscription safety checks #125 (`41219607529`) **success**.
- 🟡 Commit `b386919`: roteiro de homologação física documentado em `docs/auditoria/2026-10-31-roteiro-fisico-candidata.md`. **Roteiro não significa execução física**.
- 🔒 PR #42 e #44 permanecem sem merge; não publicar, não alterar Oficial, não cobrar de verdade. Teste físico nº 6 já verde permanece congelado.
- 🟡 Próximo bloqueio: recuperar acesso privado à configuração Firebase/OAuth e à chave candidata após 04/11/2026, conferir identidade e assinatura e só então compilar/verificar o APK real.


## Fechamento — cobertura do workflow de preflight

- 🟢 Commit `e14924f`: workflow de testes da candidata passou a observar alterações em `.github/workflows/candidate-build-preflight.yml`, evitando lacuna de disparo em revisões futuras.
- 🟢 CI Candidate Identity Guards #23 (`41220295319`): **success**.
- 🟢 CI geral Subscription safety checks #129 (`41220295304`): **success**, incluindo Flutter, Backend, Android e Entitlement; APK experimental **skipped**.
- 🟡 Pré-build manual na branch de homologação não executado nesta branch de trabalho; assinatura real, Firebase/OAuth privado e aparelho físico permanecem pendentes.
- 🔒 PR #42 e #44 em draft, sem merge; não modificar a versão oficial, não publicar nem realizar pagamentos reais.


## Auditoria Codex — certificado aprovado e CI final

- 🟢 Commit `cd239d1` (`cd239d109c664048eebdbc8d383582dad5a2471a`): `prepare` e `verify` agora exigem que as impressões SHA-1/SHA-256 do certificado correspondam ao assinante público aprovado, sem aceitar apenas metadados autorreferentes. Adicionados testes de regressão do certificado não aprovado.
- 🟢 GitHub Actions: Candidate Identity Guards #26 (`41221538520`) **success**; Subscription safety checks #131 (`41221538508`) **success**, incluindo Flutter, Backend, Android e Entitlement; job do APK **skipped**.
- 🟢 Conferência dos PRs #42 e #44 no GitHub: ambos abertos, **draft**, **sem merge**; a correção está no head do PR #44.
- 🟡 Revisão de players/Chromecast sem novo defeito comprovado conforme relatório do Codex; isso **não equivale a homologação física**.
- 🟡 A candidata padrão permanece com bloqueio por vencimento desligado; ensaio de expiração/gate depende de configuração sandbox isolada e expressamente aprovada, nunca produção nem pagamentos reais.
- 🟡 `firebaseProvisioning: pending` permanece sem alteração até comprovação no ambiente privado. Assinatura real, APK e Android TV/Chromecast físicos continuam pendentes.
- 🔒 Nenhuma autorização para merge, publicação, mudanças visuais/oficiais ou exposição de credenciais; testes verdes e teste físico nº 6 preservados.
