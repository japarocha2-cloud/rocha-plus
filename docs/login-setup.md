# Como gerar o beta de login sem confundir com a prévia

A partir desta alteração, **builds automáticas** (`push` e `pull_request`) geram **somente** o APK `rocha-plus-layout-preview-no-channels`. Esse APK serve para avaliar o visual e nunca reproduz canais. O GitHub não publicará mais um APK normal bloqueado com o nome `rocha-plus-universal` nas builds automáticas.

Para gerar uma versão que tente login real:

1. No GitHub, abra **Settings → Secrets and variables → Actions** e verifique **somente os nomes**, não os valores, dos quatro Repository secrets: `ROCHA_KEYSTORE_BASE64`, `ROCHA_KEYSTORE_PASSWORD`, `ROCHA_KEY_ALIAS`, `ROCHA_FIREBASE_CONFIG_JSON`. Este conector não permite confirmar se esses Secrets estão cadastrados. Não publique nem envie os valores.
2. Verifique no Firebase Authentication se Google permanece ativado, se o Android `com.rochaplus.app` está registrado e se **SHA-1 e SHA-256 correspondem à mesma assinatura PKCS12** armazenada no GitHub. Ter SHA cadastrado não prova que coincide com a assinatura de um novo APK.
3. Acesse **Actions → Build Rocha+ → Run workflow** na branch `main`. Deixe `signed_login=true` (padrão nas execuções manuais) e inicie a ação. Se faltar Secret ou configuração, a etapa **Prepare signed Firebase build** falhará de maneira explícita.
4. Se a execução terminar verde, em **Artifacts** baixe `rocha-plus-beta-login-universal` para instalar no celular. O AAB `rocha-plus-beta-login-play-store-aab` destina-se a preparação da loja, não ao teste direto no aparelho.
5. No celular faça o primeiro login com a conta Google escolhida. Verifique que a sessão é confirmada, que os canais abrem e que o Cast funciona na mesma rede. CI verde **não substitui teste físico**.

Os dados `ROCHA_FIREBASE_CONFIG_JSON` são o objeto JSON de configurações **públicas** Firebase e OAuth usado pelo aplicativo, não credenciais de conta de serviço ou certificados privados. O próprio Secret não deve ser publicado. As chaves de assinatura e senhas devem permanecer privadas e estáveis.

---

# Builds de teste após a Build #348

A **Build #348** foi gerada automaticamente pelo GitHub Actions, sem `--dart-define-from-file`, e por isso não permite login. Os botões Google e Apple desativados são o comportamento esperado nessa build sem Firebase, **não um teste aprovado de autenticação**.

Para avaliar apenas a apresentação do aplicativo, os workflows comuns agora incluem um artefato distinto chamado `rocha-plus-layout-preview-no-channels`. Abra a tela de login desse APK e selecione **Visualizar layout de teste**. A prévia exibe a Home com sua identidade e navegação visual, mas **não carrega canais, não reproduz vídeos e não permite Cast**. Não é uma versão beta funcional e não deve ser publicada na Play Store.

O APK normal de builds automáticas não é mais apresentado como versão funcional. O artefato de produção beta somente aparece quando uma execução manual assinada é concluída com sucesso. Para testar canais e espelhamento com login, é necessária uma execução manual de **Build Rocha+ → Run workflow → signed_login: true**, com os quatro Secrets GitHub exigidos pelo script `tools/prepare_signed_build.py` e o provedor Google configurado, incluindo SHA-1/SHA-256 da assinatura utilizada. Se faltar qualquer valor, a compilação assinada falhará de forma explícita. Não cole senhas, certificados privados ou tokens neste repositório ou chat.

---

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
