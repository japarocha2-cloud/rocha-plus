# Integração da conta Google do Rocha+ no site (pendente de dados reais)

## O que já existe no repositório
- O aplicativo Android usa `lib/src/auth/firebase_auth_repository.dart` com o mesmo Firebase Authentication e login Google, dependendo dos `--dart-define` `ROCHA_FIREBASE_PROJECT_ID`, `ROCHA_FIREBASE_APP_ID`, `ROCHA_FIREBASE_API_KEY`, `ROCHA_FIREBASE_SENDER_ID` e `ROCHA_GOOGLE_SERVER_CLIENT_ID`.
- As páginas TV e Office usam um módulo `web/assets/firebase-config.js` ainda não cadastrado. O exemplo está em `web/assets/firebase-config.example.js`.
- **UID de usuário compartilhado**: para ter o mesmo UID nos dois sistemas, usar o mesmo projeto Firebase, com aplicativos registrados separadamente para Android e Web. O `appId` do Firebase **Web** pode e normalmente será diferente do Android.

## Ativação (requer proprietário do projeto)
1. Conferir no Firebase Console qual `projectId` está efetivamente configurado no aplicativo Android em produção. Não copiar credenciais secretas nem colar tokens no chat.
2. Em Authentication, habilitar Google e cadastrar o domínio exato da hospedagem original em Authorized domains. O domínio `chatgpt.site` só deverá ser autorizado se o console permitir e a hospedagem for controlada pelo proprietário.
3. Cadastrar aplicativo **Web** no mesmo projeto e criar `web/assets/firebase-config.js` com os campos `apiKey`, `authDomain`, `projectId`, `appId`; não substituir pelos identificadores do app Android.
4. Publicar apenas em ambiente de testes controlado. Entrar com o mesmo Gmail na TV e no Office e comparar o UID autenticado com o Android usando ferramenta administrativa segura. Testar logout e retorno da sessão.

## Segurança de assinaturas e compras
- Login **não** comprova pagamento, não libera filmes, TV, APK, EXE nem licencia dois dispositivos.
- Como os três links externos do Mercado Pago não carregam vínculo garantido com o UID do Firebase, não há como atribuir um pagamento só pela tela de retorno. Antes de automatizar vendas, gerar uma referência de compra vinculada ao UID em um backend próprio, usar a integração de checkout que suporte esse vínculo e validar cada pagamento por consulta segura à API do Mercado Pago, com credenciais guardadas apenas no servidor.
- Tratar evento duplicado, estorno, vencimento, cancelamento, disputa e compra sem referência. Não ativar o serviço por e-mail informado no checkout ou por uma imagem de comprovante.
- A confirmação `approved` de pagamento é diferente da disponibilidade de saque; ainda é necessário verificar tipo, valor, plano e status da assinatura aplicável.
- Office: compra única com direito condicionado às regras de licença e limite de dois dispositivos administrado no servidor. Não habilitar download protegido até a entrega comercial validada.

## Verificação estática
Execute `python3 tools/verify_site_checkout.py` antes de qualquer merge. Isso confere preços/links, **não** realiza transações reais nem autentica usuários.
