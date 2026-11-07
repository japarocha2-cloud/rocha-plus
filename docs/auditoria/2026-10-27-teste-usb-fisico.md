# Preparação de teste físico USB — 27/10/2026

Base de aplicação: `2321b26`; branch exclusiva `fix/subscription-access-20261026`.
Usuário informou celular Android e Chromecast disponíveis e USB com depuração ativada.

## Preflight real
Celular Moto g56 5G / Android 16 identificado por ADB com autorização USB.
Pacote existente `com.rochaplus.app.lab`: versionCode 713 / versionName 0.1.0, anterior às correções.
Pacote oficial `com.rochaplus.app` também existe. Nenhum desses pacotes é removido ou sobrescrito.

## Variante temporária
Entrada debug exclusiva `lib/usb_physical_main.dart`, exige `ROCHA_USB_PHYSICAL_TEST=true`.
Pacote independente `com.rochaplus.app.usbqa`, rótulo “Rocha+ USB QA”.
Compilação de teste sem credenciais Firebase, login, consulta de entitlement ou pagamentos.
Somente duas amostras HTTPS usadas nos exemplos do plugin Cast; sem catálogo comercial ou favoritos.
O workflow gera um bundle temporário de CI (retenção 1 dia) para transferência por USB,
sem release, Play Store, publicação comercial ou geração de APK oficial.
Identificador do commit, SHA-256, certificado, dependências e patch LAB LibVLC acompanham o artefato.
A preparação rejeita outras branches e configurações Android inesperadas.

## Escopo da evidência física
Registrar imagem/áudio no celular por engine, 60 s e 180 s; troca/retomada, exceções e memória.
Para Chromecast, o status PLAYING do receiver é uma camada de evidência, não comprovação de imagem/áudio na TV.
Solicitar confirmação humana de imagem/áudio quando a TV não puder ser capturada.
Um celular não homologa Android TV nem o controle remoto do televisor.
Esta variante não valida contas reais, trial ou pagamentos, pois não consulta o backend.
Resultados serão registrados após execução, sem promover pendências a VERDE por antecipação.

## Primeira execução real e correção das amostras
Build USB do código `7954893` instalado em pacote independente, preservando o oficial e o LAB 713.
ExoPlayer no Moto g56/Android 16 registrou Source error / HttpDataSource InvalidResponseCodeException 403
nas amostras antigas do bucket gtv-videos-bucket. Isso é falha de acesso à fonte, não prova de defeito do decoder.
O mesmo HTTP 403 foi confirmado por consulta externa; nenhum canal do catálogo foi removido.
Novas amostras: MP4 Media3 em exoplayer-test-media-0 e HLS test-streams.mux.dev/x36xhzz.
Ambas responderam HEAD 200 em 27/10/2026; isso não homologa reprodução audiovisual.
Referências: https://github.com/androidx/media/issues/3267 e https://test-streams.mux.dev/ .
Chromecast informado pelo usuário: dispositivo de sala (nome privado mantido fora do relatório público).
Recompilar a variante isolada e repetir o teste antes de declarar aprovação.
