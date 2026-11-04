# Build de homologação com checkout — 04/11/2026
A branch de implementação usa jobs exclusivos em build.yml. Não há deploy, release de loja ou alteração do servidor.
O job checkout-validation resolve Flutter 3.47.6, registra pubspec.lock na mesma branch, executa fixtures, analyze e test. O lockfile é gerado pelo resolvedor, nunca inventado.
O job checkout-apk exige sucesso da validação, usa exatamente o commit com lock e produz pacote com.rochaplus.app.checkout, launcher Rocha+ Checkout HOM, login real e flags sem bloqueio e sem preview. Artefato: rocha-plus-checkout-homologacao, com APK, SHA256SUMS e SOURCE_COMMIT.
Não se gera APK sem bundle privado revisado. Campos exigidos no secret ROCHA_CHECKOUT_HOMOLOGATION_JSON:
verified_by, verified_at, firebase_project_id, firebase_app_id, firebase_sender_id, firebase_api_key, google_server_client_id, android_package (com.rochaplus.app.checkout), signing_sha256, checkout_url, entitlement_url, backend_project_id, backend_token_audience, merchant_id, checkout_enabled (false), payment_mode (one_time), backend_kind (firebase_entitlements), identity_binding (firebase_uid).
Assinatura usa secrets existentes ROCHA_KEYSTORE_BASE64, ROCHA_KEYSTORE_PASSWORD, ROCHA_KEY_ALIAS.
Os endpoints devem ser as Functions HTTPS checkout e entitlement no projeto Firebase revisado; backend_project_id e backend_token_audience precisam coincidir com firebase_project_id. Essa conferência é estrutural e baseada no bundle revisado. Não comprova implantação, configuração real do Admin SDK, OAuth ou transação financeira.
O app Firebase deve estar registrado para o pacote .checkout e certificado SHA-1/SHA-256 da chave. google_server_client_id deve ser cliente Web do mesmo projeto com provedor Google habilitado e OAuth configurado.
O servidor permanece ROCHA_CHECKOUT_ENABLED=false. O workflow não tem credenciais de deploy e não o altera.

## Antes da primeira compra real da conta de suporte
1. Confirmar pacote/versionCode/SHA-256 do APK instalado, login Google real, UID e projeto emitente do Firebase ID token. Confirmar que checkout e entitlement validam esse token no mesmo projeto, usando entitlements/{Firebase UID}; não usar a projeção Spark por Google subject.
2. Confirmar privadamente MP_RECEIVING_ACCESS_TOKEN em /users/me, merchant ID e recebedor financeiro esperado. Não exportar tokens para artifacts ou APK.
3. Confirmar implantação de checkout, webhook HMAC e reconciliador deste código no ambiente correto; configurar URL e MP_WEBHOOK_SECRET. Com checkout ainda desligado, fazer homologação isolada dos casos de aprovação, replay, concorrência, divergência de merchant/valor/UID, reembolso e estorno. Fixtures não substituem essa validação.
4. Registrar que os valores são BRL 450/4950 centavos, pagamento único por período, sem preapproval nem renovação automática. Demonstrar no ambiente autorizado a passagem pedido->preferência->payment canônico->claim->ledger->paidUntil no UID correto.
5. Consultar os direitos da conta de suporte e pedidos/pagamentos existentes para evitar nova cobrança desnecessária. Não alterar conta de Nádia, claims históricos ou pagamentos existentes.
6. Somente após revisão financeira e autorização da compra, configurar no servidor ROCHA_CHECKOUT_ENABLED=true, merchant ID, mode=one_time e webhook URL verificados. Isso é ativação externa futura, não executada por este build. Após pagamento autorizado, verificar status approved/accredited, live mode, moeda/valor, ausência de reembolso e paidUntil na mesma conta; reabrir app e confirmar acesso pago prioritário sem bloquear o catálogo.
A primeira compra real não está autorizada apenas pelo sucesso da compilação.
