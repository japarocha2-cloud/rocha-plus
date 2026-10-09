# Favoritos e assinatura juntos

Candidato de integração de PR14 (442708c) e PR15 (64e9656), sobre main 231bca5.
App mantém AccountFavorites fora do SubscriptionGate. A perda de direito remove
rotas e players e solicita parada de Cast; mantém a sessão de favoritos até logout.
Home e TV ao Vivo compartilham o mesmo repositório por UID; o menu Assinatura volta.

Beta continua gratuito, sem inicializar compras. Modo comercial exige backend
verificado e direito ativo. Preço aprovado: R$ 4,90 mensal; 7 dias somente para
novos assinantes elegíveis. Backend continua aceitando somente testPurchase.
Nenhuma implantação, publicação do app ou cobrança real autorizada por este PR.

Regras combinadas em backend/firestore.rules; emulator de favoritos usa essas
mesmas regras. Cópia favorites/firestore.rules comparada por teste de igualdade.
billingUsers/billingTokens negam leitura e gravação dos clientes. Favoritos próprios
não dependem de assinatura ativa e não concedem acesso ao player.

Validação adicionada: expiração descarta rota de canal, conserva favoritos e
renovação recupera o mesmo repositório; Beta mantém compras desativadas; emulator
confirma favoritos após expiração sem abrir documentos de cobrança.
Esses testes simulam o direito e não comprovam compra licenciada/Publisher/RTDN.

Favoritos no Beta PR15: recuperação após reinstalar e Redmi -> Motorola observadas
pelo agente. Remoção nos dois aparelhos e sincronização de favorito marcado offline
confirmadas pelo usuário, sem nova inspeção do agente nessas duas etapas.

Antes de aprovação comercial: testar versão integrada nos aparelhos, Play Console,
produto/base plan mensal/offer elegível, license testers, Publisher/IAM e backend
de teste, RTDN, pendência, renovação, cancelamento e expiração reais de teste.
Repetir reprodução/fullscreen/Cast/scanner/Infantil/Notícias. Não trocar plano
Firebase, publicar regras novas ou habilitar cobranças reais sem autorização.
