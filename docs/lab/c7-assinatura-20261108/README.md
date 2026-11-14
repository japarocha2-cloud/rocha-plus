# C7 LAB — consulta de assinaturas — 08/11/2026

Base a063074; branch lab/candidata7-assinatura-consulta-20261108. Sem alteração de C6, versão oficial, catálogo, preços, servidor implantado ou direitos de produção. Este relatório não contém e-mail, UID, IDs de pagamento, dados pessoais ou credenciais.

## Causa comprovada

O entrypoint FULL_UI_LAB não autentica uma conta e o workflow compilou sem ROCHA_ENTITLEMENT_URL. SubscriptionAccess.check exige UID da sessão Firebase atual, token válido e endpoint HTTPS; a tela esconde a consulta se faltar a sessão ou configuração. Os preços visíveis não significam que o backend esteja conectado.

## Trabalho reutilizado e correção independente

A rota LAB agora reutiliza AuthController, FirebaseAuthRepository e SubscriptionAccess existentes, com login Google opcional para consulta; o catálogo não é bloqueado por autenticação. Estado pago é limpo na troca/logout. O retorno de um popup não estabelece identidade: só o evento de autenticação fornece o UID. A resposta continua exigindo o mesmo UID, e datas/motivo vêm do servidor. Não se usa e-mail como autorização. O modo de consulta só inicializa em build explicitamente configurada (ROCHA_C7_SUBSCRIPTION_QUERY) com Firebase e endpoint; sem isso exibe diagnóstico, sem fingir ativação. Os planos permanecem R$7,90/R$86,90, e nenhum botão de cobrança real foi adicionado.

## Backend existente e risco de efeitos colaterais

- functions/index.js: entitlement verifica token revogado e cria trial na primeira leitura se não houver documento. Documento existente é reutilizado, sem recalcular trial. É chaveado por UID Firebase por projeto, não pela identidade Google estável de outro projeto.
- backend/entitlement/service.mjs: conta/trial e pagamentos possuem transações e proteção de replay. O GET de acesso também pode inicializar conta ausente.
- A implementação Spark anterior usa rochaSparkAccounts por subject Google estável; o início é horário do servidor e é descrito como imutável nas regras/histórico. Seu status() pode criar documento se ausente; não foi invocado contra produção.
- billing/recurring_service.js na branch existente: action=status executa reconcile(), bindSubscription(), applyInvoices() e projectAccess(). Portanto não é uma rota puramente de leitura, apesar do nome. Não foi chamada sob a autorização de consulta sem alterações de produção.
- Checkout Mercado Pago anterior foi localizado e seus fixtures sandbox reutilizados sem reconstruir o sistema. Não se abriram links antigos de produção nem se executou POST no provedor.

## Conta e pagamentos históricos

O diagnóstico anterior já confirmou os dois pagamentos históricos. Não foi repetido nem reinterpretado como concessão atual. O registro histórico distinguia confirmação financeira de paidUntil/vínculo ao direito, que permanecia pendente naquele momento. O projeto de homologação e o documento Spark oficial são universos diferentes: entrar com a mesma conta em outro projeto não prova migração do direito, e uma nova linha de trial LAB não deve ser apresentada como reinício/concessão do trial oficial.

A rotina de períodos existente aceita, em fixture verificada, mensal de 20/10/2026 e anual de 21/10/2026 como períodos sobrepostos, com vencimento anual em 21/10/2027, sem somar o mensal. Um preview administrativo antigo usa proposta acumulativa e exige revisão de política/ledger. Não escolher nem aplicar uma política em produção nesta tarefa. A data real só pode ser confirmada pela leitura atual do vínculo/ledger associado à identidade verificada. Nenhuma data, pagamento, trial ou direito foi escrito.

## Bloqueios exatos

1. Runtime sem FIREBASE_SERVICE_ACCOUNT_JSON e MP_RECEIVING_ACCESS_TOKEN injetados; GOOGLE_APPLICATION_CREDENTIALS aponta para JSON vazio, não uma credencial utilizável. Presença de secrets GitHub é inspecionada separadamente por nomes/booleanos no CI, sem extrair valores para este ambiente.
2. Rede bloqueia southamerica-east1-rocha-plus-homologacao.cloudfunctions.net e api.mercadopago.com com CONNECT 403. Não é resposta funcional do backend. Destinos adicionais de identidade/Firestore só devem ser permitidos conforme o fluxo existente de acesso, sem contornar a política através do CI.
3. Configuração LAB histórica registra pacote .lab. C7 conserva .labc7 e certificado original: é necessário confirmar client OAuth desse pacote e certificado no projeto escolhido. O preflight publica apenas booleanos; jamais reutiliza silenciosamente configuração de outro pacote/projeto.
4. Não foi demonstrada uma consulta autenticada ao estado real dessa conta. Não se presume acesso Firebase por uma credencial GitHub, nem que secret presente tenha IAM adequado.
5. As rotas localizadas podem criar trial/reconciliar. Antes de consultar o direito oficial pelo app, comprovar uma rota já implantada de leitura sem efeitos indesejados, ou obter autorização específica para mudança de backend. Esta ordem proíbe deploy e alteração de direitos de produção; nenhuma implantação foi feita.

## Testes e entrega

35 testes existentes de Functions, 53 de entitlement (após instalar dependências travadas), 19 fixtures sandbox existentes, 40 testes Python e fixture nova do vencimento anual passaram localmente. Nenhum desses resultados equivale a leitura real da conta, checkout sandbox do provedor ou APK homologado. O novo teste Flutter exercita login/UID, retorno de popup sem identidade e limpeza do status após logout; execução e análise são verificadas no workflow c7-subscription-readiness.yml junto à suíte completa.

Não se gera APK rotulado como consulta funcional enquanto faltarem prova autenticada, vínculo correto de identidade/direito e configuração compatível C7. Um APK com flags/URL preenchidos sem essa prova repetiria a falha anterior. O último APK C7 continua preservado. A ordem permanece aberta; o CI desta branch demonstra apenas prontidão do código e testes de fixtures, não homologação do servidor.

Próximas ações: acesso seguro somente leitura e rede para os diagnósticos já existentes; conferir vínculo por subject/UID, ledger e trialStartedAt; confirmar OAuth .labc7 e certificado; validar a consulta autenticada sem inicializar novo trial ou reconciliar produção; testar checkout com contas/credenciais sandbox já existentes; só então preparar o build LAB com configuração comprovada e medições de pacote/tamanho/hash/certificado. Nenhum valor secreto deve ser enviado no chat.

## Configuração existente confirmada no CI

O preflight de 42534779256 confirmou, sem revelar valores: bundle LAB válido, configuração Firebase LAB presente e projeto de homologação correto; credenciais de leitura oficial, conta recebedora e sandbox vinculadas nos Secrets GitHub. Não solicitar cadastro duplicado desses secrets. Entretanto, c7PackageClientPresent=false e c7CertificateRegistered=false: o JSON disponível não contém cliente .labc7, portanto não comprova OAuth para o certificado desse pacote. webOAuthClientPresent=false refere-se ao cliente C7 ausente, não prova ausência global de um OAuth Web no projeto.

Acesso seguro dessas credenciais no runtime e domínios de rede ainda faltam; presença de secret no CI não prova IAM nem consulta autenticada bem-sucedida. A rota nova distingue sessão ausente de endpoint não configurado, sem apresentar o usuário como inadimplente.
