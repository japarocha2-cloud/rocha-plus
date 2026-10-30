# Validação física experimental — Android TV e Roku (30/10/2026)

Status inicial: **não executada**. Compilação, teste de catálogo, HEAD HTTP e
presença de áudio/vídeo em benchmark não comprovam reprodução nesses aparelhos.
Nenhum candidato recebe aprovação para distribuição por este roteiro.

## Preparação e identificação

- Usar Android TV/Google TV e Roku físicos; registrar modelo, versão do sistema,
  rede (Wi-Fi/Ethernet), data/hora com fuso e operador.
- Registrar branch, commit, execução CI, nome do pacote, tamanho e SHA-256.
  Conferir o SHA-256 antes de instalar. Não compartilhar credenciais nem URLs
  contendo parâmetros de autenticação nos registros públicos.
- Android: instalar somente o APK debug LAB (`com.rochaplus.app.lab`), mantendo
  o aplicativo oficial separado. Confirmar entrada LAB e exatamente 12 canais.
  Coletar `adb logcat` e relatório exportado pelo laboratório, quando disponível.
- Roku: usar modo desenvolvedor/sideload somente em aparelho de testes.
  Registrar qual ZIP foi instalado: catálogo de 395 ou amostra LAB de 12.
  O sideload substitui o aplicativo de desenvolvimento existente: preservar
  antes seu pacote e dados necessários. Não publicar no Channel Store.
- Comparar primeiro a amostra de 12 nas duas plataformas, na mesma rede e janela
  de tempo. Não iniciar pareamento de conta, assinatura ou pagamento real.

## Matriz obrigatória por canal e plataforma

Registrar ID/nome do candidato, resultado (`não executado`, `aprovado neste
ensaio`, `reprovado`, `inconclusivo`), tempo até primeiro quadro, tempo até áudio,
resolução observada, duração efetiva, erro exibido e referência do log/vídeo.
Aprovação neste ensaio não é autorização editorial ou de distribuição.

1. **Abertura e áudio/vídeo:** reproduzir por pelo menos 180 segundos; confirmar
   quadros avançando, áudio contínuo e sincronizado, proporção sem cortes e
   ausência de tela preta, travamento ou buffering contínuo. Testar volume/mudo
   e restauração. Registrar indisponibilidade da fonte como tal.
2. **Troca:** alternar pelos 12 canais, ida e volta; fazer dez trocas rápidas.
   Confirmar encerramento do áudio anterior, foco consistente e retorno de imagem
   sem reprodução duplicada. Anotar tempo e erros por troca.
3. **Controle remoto:** setas, OK, voltar, play/pause quando suportados, volume,
   mudo e retorno do player ao catálogo. Confirmar acesso sem toque/mouse, foco
   visível e ausência de bloqueio da navegação.
4. **Estabilidade:** manter três candidatos de grupos distintos por 30 minutos
   cada. Registrar interrupções, buffering, sincronismo e falhas; coletar logs
   em qualquer encerramento inesperado. Não generalizar esse resultado aos 395.
5. **Reconexão:** durante reprodução, desconectar a rede por 30 segundos e
   reconectar; repetir três vezes. Verificar erro/estado inteligível, retry,
   recuperação ou necessidade de reabrir, sem duplicação de áudio. Testar também
   indisponibilidade temporária de uma fonte sem apagar o canal do catálogo.
6. **Ciclo de vida:** sair e reabrir o app, standby/retomada, reinício do aparelho
   e nova reprodução. Confirmar liberação do player e recuperação da navegação.
7. **Catálogo Roku 395:** após a amostra, verificar contagem, navegação e categorias
   no ZIP completo. Ensaios adicionais devem registrar explicitamente os IDs
   testados; a existência de 395 registros não representa 395 reproduções aprovadas.

## Registro de execução

| Plataforma/aparelho | Pacote/commit/SHA-256 | ID do canal | Cenário/duração | Resultado observado | Log/vídeo | Pendência |
| --- | --- | --- | --- | --- | --- | --- |
| Android TV | a preencher | a preencher | a executar | não executado | — | aparelho físico |
| Roku | a preencher | a preencher | a executar | não executado | — | aparelho físico |

Falha isolada não remove candidato. Preservar canal, erro, horário e contexto para
repetição dirigida. Alterações em identidade visual, versão oficial, cobrança,
merge e publicação ficam fora deste ensaio.
