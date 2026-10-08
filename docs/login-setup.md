# Login obrigatório: ativação pendente

Esta branch prepara autenticação Firebase Google/Apple no Android. Ela não deve ser integrada ou distribuída como versão de uso até configurar um projeto real e validar login no aparelho. Sem configuração, o acesso aos canais fica bloqueado com uma mensagem de indisponibilidade.

## Configuração externa

1. Ativar pessoalmente a verificação em duas etapas da conta Google: o console Firebase atualmente exige essa etapa para acesso.
2. Criar um projeto Firebase para Rocha+ e ativar Authentication.
3. O aplicativo Android foi registrado no Firebase `rocha-plus` com identificador `com.rochaplus.app`. A ferramenta Android ajusta applicationId/namespace e a atividade Kotlin para esse identificador.
4. Registrar o app Android e os SHA-1/SHA-256 da assinatura utilizada. Ativar Google, definir o e-mail de suporte e obter o Client ID do tipo Web para Google Sign-In.
5. Para Apple no Android: configurar Sign In with Apple na conta Apple Developer e ativar o provedor no Firebase. Credenciais privadas Apple permanecem no console, nunca no app ou repositório.

## Configuração da build

Os valores públicos de configuração Firebase e o Client ID são recebidos por `--dart-define-from-file` durante a build. O arquivo deve conter os nomes abaixo com os valores do projeto real; não há valores fictícios no código:

- ROCHA_FIREBASE_PROJECT_ID
- ROCHA_FIREBASE_APP_ID (app Android)
- ROCHA_FIREBASE_API_KEY
- ROCHA_FIREBASE_SENDER_ID
- ROCHA_GOOGLE_SERVER_CLIENT_ID (cliente OAuth Web)
- ROCHA_APPLE_ENABLED (true somente depois de ativar o provedor)

Exemplo de comando: `flutter build apk --release --dart-define-from-file=config/firebase.android.json`.

O workflow de CI desta branch valida compilação sem configuração, portanto gera um APK bloqueado para login. Uma build funcional requer os valores do projeto; o CI não possui essa configuração ainda. Não colocar chaves privadas Apple, arquivos de conta de serviço, senhas ou tokens neste arquivo. Configurar assinatura estável para que a sessão Google funcione no APK distribuído e na Play Store.

## Escopo e limites

- A entrada sem conta foi removida por solicitação do usuário.
- A sessão Firebase, inclusive ao reabrir o app, determina acesso. Estado local de preferências não libera o catálogo.
- Login cancelado ou com erro não abre os canais.
- Sair ou perder a sessão remove rotas de catálogo/player abertas.
- Favoritos continuam armazenados por aparelho; não há sincronização ou isolamento por conta nesta etapa.
- O conteúdo vem de URLs públicas de terceiros. Exigir login na interface não torna essas URLs privadas e não substitui autorização de conteúdo.
- iOS, web e desktop não estão ativados nesta versão. A CI existente só gera Android.
- O fluxo Google/Apple precisa ser testado separadamente em Android TV/Google TV. Não existe fluxo de pareamento por QR/code nesta etapa; não alegar compatibilidade de login na TV sem teste físico.
- Exclusão de conta e revogação Apple ainda precisam ser implementadas/validadas antes de publicar contas reais aos usuários.

## Fontes

- https://firebase.google.com/docs/auth/flutter/federated-auth
- https://firebase.google.com/docs/flutter/setup
- https://pub.dev/packages/google_sign_in
