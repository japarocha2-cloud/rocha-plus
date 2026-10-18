# Rocha+ — candidato de desenvolvimento (07/10/2026)

## Base e evidência
Base retomada: build #289, commit 7bb99e557a645ada2d74ce72a1b2cde5a6d397f0.
O #289 concluiu análise, testes, APK universal, ARM64 e AAB com sucesso.
Comparação Cast: build #147, commit 46f08066da7b203eefef1ac84b641e4309200b3d.
A descoberta básica e a inicialização eram semelhantes; a causa da regressão física
de descoberta permanece sem confirmação. O #147 tinha validação de sessão,
confirmação de reprodução e relay HLS local, removidos da base #289.
Este candidato solicita busca ativa no seletor, recupera confirmação e encerra buscas corretamente. O relay local HLS foi recuperado após as falhas físicas relatadas no #303:
primeiro tenta o sinal diretamente; em falha HLS na mesma rede, tenta pelo celular.
O servidor liga somente durante essa tentativa, em interface privada IPv4, com
links aleatórios por recurso e fontes HTTPS públicas, inclusive redirecionamentos.
Preserva variantes, segmentos e chaves, sem transcodificar. Codec incompatível,
DRM ou falta de autorização continuam sem solução automática. O celular precisa
permanecer ligado e na mesma rede; não há serviço de relay garantido em segundo plano.

## Etapas implementadas e validação automatizada
- Cast: solicitação de busca ativa da versão 1.5.0, dispositivos existentes, evento inicial, busca vazia, erro, repetição,
  encerramento da busca; conexão e mídia específica precisam confirmar PLAYING.
- Player: sucesso exige posição avançando fora de buffering; retry e erro limpam
  evidência. Não há transcodificação ou redução de resolução.
- Catálogo: requisições simultâneas compartilhadas; fontes paralelas, cache e
  fallback testados; URLs originais permanecem intactas.
- Fullscreen: vídeo sem corte e controles sem escala; voltar sai da tela cheia;
  telefone aberto em retrato restaura portraitUp, telas largas liberam orientação.
- Scanner: até quatro verificações de endereço simultâneas, acionadas pelo usuário,
  em até 40 canais exibidos. HEAD não comprova reprodução. Resposta não suportada,
  erro de rede ou redirecionamento permanece sem confirmação e não gera bloqueio definitivo.
- Bloqueios: nomes normalizados por resolução e acentos; lista física histórica
  preservada, inclusive Esportes; ocultação local persistente e restauração testadas.
  Falha de reprodução isolada continua em quarentena apenas durante a sessão.
- Infantil/Notícias: categorias compostas, categoria vazia e preservação da escolha
  durante carregamento testadas; Notícias abre o catálogo sem conteúdo editorial fictício.
  A classificação dos diretórios não substitui revisão editorial de cada canal.
- Visual: Home e login com texto ampliado em 320x568, 430x932, 960x540 e 1920x1080;
  controles por teclado simulados. Paleta preta/roxa/dourada e Play verde preservados.
  Asset histórico #147 restaurado pelo blob 587481a95f41f7811884dbd3e15ea987d0ae463e,
  sem gerar imagem substituta. Não há aprovação visual física nova.

## Administrativo e segurança
- Google/Apple continuam sem autenticação, com botões desativados.
  A navegação atual é pública; nenhum painel administrativo protegido foi implementado.
- Favoritos (URLs) e canais ocultos (nomes normalizados) ficam no armazenamento local.
  Repositório de métricas comerciais também usa armazenamento local, sem transmissão
  encontrada nas telas atuais. Não há localização implementada.
- Diretórios, logos e streams consultam servidores externos. Esses pedidos e o
  receiver Cast podem expor dados de conexão aos respectivos serviços.
- Dependências sem uso removidas: permission_handler e cupertino_icons.
- Manifest exige rede e serviço de mídia, compatibilidade TV opcional,
  serviço de notificação não exportado e tráfego HTTP aberto desativado.
- Scanner não segue redirecionamento para HTTP; parser rejeita credenciais embutidas,
  hosts vazios e logos sem HTTPS.
- Inicialização Cast aguardada pelo seletor; ausência do serviço não impede abrir o app.
- CI executa teste de configuração Android e verifica o manifest de release mesclado;
  publica SHA-256, tamanho e commit dos APKs/AAB em release-evidence.json.
- Assinatura de produção, ID empresarial, documentos de loja, política final de
  privacidade e direitos de distribuição permanecem pendentes. Estes pacotes são
  candidatos de desenvolvimento, não publicação em loja.
- TV Morena: contato estabelecido, aguardando resposta. Não bloqueia desenvolvimento.
  Inclusão de canal em diretório público não é prova de licença.

## Teste físico pendente — registrar aparelho, Android, rede, build e resultado
1. Comparar #147 e candidato na mesma TV e Wi-Fi: busca inicial, abrir novamente,
   seleção, conexão e reprodução real com imagem/áudio.
2. Conferir seleção de canal novo em sessão Cast existente e recusa de mídia:
   evitar mensagem de sucesso para outro canal ou interrupção indevida do vídeo local.
3. Testar carga rápida/lenta, buffering, retry, áudio e qualidade em diferentes redes.
4. Entrar/sair de fullscreen, botão voltar, rotação, saída do Player e retornar ao catálogo;
   repetir em celular, tablet, Android TV e Google TV.
5. Ocultar um canal, fechar/reabrir o aplicativo, atualizar diretório e restaurar:
   o bloqueio deve sobreviver a reinício, mas desinstalação/limpeza dos dados remove preferências.
6. Revisar cada canal Infantil e Notícias e conferir a identidade visual no aparelho.
7. Controle remoto: primeira tecla revela controles; foco, pausar, fullscreen e navegação.
8. Instalação/atualização: assinatura de desenvolvimento pode exigir reinstalação;
   guardar preferências antes se houver necessidade de desinstalar a versão anterior.

Nunca registrar etapa física como aprovada apenas porque CI passou.

Referência técnica para busca ativa: [changelog do plugin, seção 1.5.0](https://github.com/felnanuke2/flutter_google_cast/blob/master/CHANGELOG.md).

## Retorno físico do #303 e correções seguintes
O usuário enviou nove imagens e informou áudio excelente em um canal testado com
sucesso na TV. Outros canais falharam no Cast, incluindo imagem posterior de Rede
Globo (1080p) reproduzindo no celular com falha de confirmação na TV. Não há aprovação
geral de Cast, estabilidade, orientação ou persistência física.
TV ao Vivo exibiu zero canais: o filtro TV aberta não existia no diretório remoto.
Identidades conhecidas de canais abertos agora são classificadas por tvg-id/nome,
sem roubar tags Infantil, Notícias ou Esportes. Testes reproduzem General/Undefined.
Prioridade regional recuperada de Rocha+ APK 18h: Amambai/MS, TV Morena/Globo,
SBT MS, Record MS e Band MS. A classificação está preparada; as quatro variantes
regionais não aparecem com esses nomes no catálogo atual. A grade regional completa
permanece pendente de fontes públicas/autorizadas, sem substituir por canais nacionais
renomeados nem remover canais durante a conferência.
