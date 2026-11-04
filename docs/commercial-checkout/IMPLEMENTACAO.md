# Implementação comercial isolada — 04/11/2026
Base: incident/payment-recognition-20261103, commit 0f94b29f67efbbff2e136cb010eadbfb5dd57e99.
Branch: impl/commercial-checkout-20261104.

## Alterações implementadas
- Botões Mensal R$ 4,50 e Anual R$ 49,50 na tela existente, mantendo tema e catálogo.
- Cliente exige sessão Firebase atual, envia somente plano e abre URL HTTPS oficial do Mercado Pago no navegador externo.
- Endpoint POST checkout verifica ID token revogado, consulta /users/me, confere recebedor configurado e cria preferência oficial com preço definido no servidor.
- Pedido persistido antes da preferência, com UID autenticado e referência aleatória. Nenhum e-mail é usado para conceder licença.
- Webhook assinado existente agora pode vincular pagamento canônico ao pedido autenticado; o reconciliador existente continua exigindo moeda, valor, merchant, live mode e aprovação financeira antes do grant. Claims históricos não são sobrescritos. Um pedido aceita um payment ID.
- Pedidos novos inicializam trial apenas se o documento de direito não existir. Trial e licença existentes não são reiniciados.
- A API existente já prioriza licença paga válida sobre trial; a suíte de regressão verifica esse comportamento.
- A tela de assinatura consulta direitos ao abrir e ao retomar o app. Mostra aviso de teste somente quando o servidor retorna trial. Isso não implementa um aviso global no primeiro login fora dessa tela.
- Modo implementado: pagamento único por período, SEM renovação automática, explicitado na tela. Não há integração de assinaturas recorrentes/preapproval.

## Configuração e limites
Checkout fica desabilitado por padrão. ROCHA_CHECKOUT_ENABLED=true somente após revisão privada financeira; configurar também ROCHA_CHECKOUT_MERCHANT_ID, ROCHA_CHECKOUT_MODE=one_time, ROCHA_CHECKOUT_WEBHOOK_URL e o secret existente MP_RECEIVING_ACCESS_TOKEN. O webhook existente exige MP_WEBHOOK_SECRET. O APK precisa de ROCHA_CHECKOUT_URL e do endpoint de direitos confirmado no mesmo projeto.
Não ativar a configuração enquanto não houver comprovação do recebedor, identidade de sessão, configuração financeira e backend efetivo. Os flags são configuração operacional, não prova dessa revisão.
O Firestore atual não concede acesso cliente a checkout_orders: permissões ausentes são negadas. Somente Admin SDK grava pedidos e claims.
Sem deploy nesta execução; nenhum pedido ou pagamento real foi criado, consultado ou alterado.

## Validação executada
59 cenários Node passaram, em sete arquivos: checkout 7, vínculo de pedido 5, endpoint 7, períodos 5, reconciliação 5, webhook 12, concessão 18. Fixtures locais, Node 24; package original requer Node 22. Não são homologação Mercado Pago/Firebase.
O primeiro teste do endpoint falhou porque seu harness rejeitava as novas dependências; foi atualizado para carregar os módulos locais, preservando os casos e assertions anteriores. Nova execução passou.
Flutter analyze/test/build não executados: Flutter e Dart ausentes e proxy Git indisponível no executor. O pubspec foi atualizado, mas sem regeneração de lockfile nem compilação para validar url_launcher no Android.
Conta de Nádia (ADM/demo/isenção), sessão da conta de suporte, recebedor real, sandbox, Firestore Emulator e teste físico continuam NÃO VERIFICADOS.
A mensagem do usuário terminou em “prioridade sobre”; adotada prioridade sobre trial, sem inferir requisitos posteriores.

## Preservação e entrega
Apenas código de checkout, tela de assinatura, dependência e testes foram alterados. Catálogo, streams, player, tema e política beta não foram modificados. Candidata 6 e branch original preservadas.
Nenhum bloqueio de catálogo foi introduzido. Quantidade dos 430 canais e reprodução não revalidadas.
APK comercial ainda não gerado. Bloqueio da entrega instalável permanece: toolchain/rede indisponíveis, assinatura/configuração Android e validação financeira sem acesso.
Esta entrega é implementação parcial em branch separada, com testes e limitações documentadas. Não declarar ativação comercial concluída.

