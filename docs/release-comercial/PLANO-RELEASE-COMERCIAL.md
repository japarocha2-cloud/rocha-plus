# Release comercial pago do Rocha+ — preparação LAB (17/11/2026)

Branch local: `lab/release-candidate-20261117` (sem push, sem merge). Nada foi implantado,
publicado ou alterado em produção. Candidata 6, catálogo oficial congelado, banners e
LAB Cliente v7 preservados.

## Preparado e testado no LAB
| Item | Onde | Evidência |
|---|---|---|
| versionCode acima de 2465/3538 | `tools/configure_android.py` (`flutter.versionCode + 3000` no Gradle gerado; CI segue com `--build-number=run_number`) | `tools/test_configure_android.py` |
| Cobrança obrigatória só no build comercial | `lib/src/app_release_policy.dart` (`ROCHA_COMMERCIAL_RELEASE` → `official`; padrão continua beta) | `test/app_release_policy_test.dart` nos modos beta, comercial e experimental |
| Parâmetros comerciais de produção | `tools/commercial_release_config.py` (URLs https exatas de `rocha-plus`, catálogo fechado C7 540 com SHA-256; recusa homologação ou URL vazia) | `tools/test_commercial_release_config.py` (inclui preços 790/8690 e trial de 7 dias iguais no servidor e no app) |
| Ligação ao script protegido | `docs/release-comercial/prepare_signed_build.commercial.patch` — **não aplicado** | `git apply --check` OK; simulação com segredos fictícios gerou os defines comerciais e recusou backend de homologação |

## Estado da produção (somente leitura, 17/11)
- Firebase `rocha-plus`: app `com.rochaplus.app` ativo; SHA-256 registrado `8c83b088…` = certificado oficial do Build465; login Google ativo; Firestore `(default)` existe.
- Regras Firestore (14/10): só `users` e `rochaSparkAccounts`, sem curinga → coleções de pagamento negadas a clientes por padrão.
- **Cloud Functions: nenhuma** (`entitlement`, `checkout`, `mercadoPagoWebhook` → 404).
- **Secret Manager: API desativada**; sem credenciais Mercado Pago de produção.

## Bloqueios para gerar o APK release comercial assinado
1. **Backend de produção inexistente.** Exige, com autorização específica do proprietário:
   implantar `entitlement`, `checkout` e `mercadoPagoWebhook` em `rocha-plus` (região
   `southamerica-east1`) com `functions/.env.rocha-plus` de produção (`ROCHA_PAYMENT_MODE` live,
   checkout desligado até a validação), ativar Secret Manager e cadastrar
   `MP_RECEIVING_ACCESS_TOKEN`/`MP_WEBHOOK_SECRET` de produção (aplicação MP real, conta recebedora
   revisada), registrar o webhook no painel do MP e mesclar as regras Firestore preservando
   `users`/`rochaSparkAccounts`.
2. **Script protegido.** Aplicar o patch acima em `tools/prepare_signed_build.py` exige autorização.
3. **Assinatura oficial só no CI.** O keystore está nos secrets do GitHub (`ROCHA_KEYSTORE_*`);
   gerar exige `push` da branch e `workflow_dispatch` de "Build Rocha+" com
   `ROCHA_COMMERCIAL_RELEASE=true` e as duas URLs — ambos dependem de autorização.
   Observação: `build.yml` (protegido) ainda precisa expor esses três valores ao passo
   "Prepare signed Firebase build" (variáveis de ambiente/inputs).
4. **Pagamentos.** Homologação: aprovado mensal, renovação, pendente e webhook OK
   (`lab-c7-900/evidence/pagamentos-homolog-20261117/`). Faltam recusado (OTHE) e anual.
   Produção: nenhum teste (exige uma compra real autorizada, de valor mínimo, após o deploy).
5. **Jurídico/loja.** `docs/launch-checklist.md` todo em aberto (privacidade, termos, direitos das
   transmissões — inclusive a fonte da Rede Globo).
6. **Testes visuais desatualizados.** 3 falhas conhecidas em `test/official_visual_test.dart`
   (ordem aprovada dos banners); o CI roda `flutter test` e falharia até o teste ser atualizado.
