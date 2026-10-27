# Rocha+ — auditoria transversal e triagem de canais (26/10/2026)

Status: **em execução / evidências parciais**. Este documento não homologa reprodução ou licenças.

## Escopo e preservação
- Repositório: `japarocha2-cloud/rocha-plus`; branch experimental `fix/subscription-access-20261026`.
- Não alterar versão congelada, não fazer merge nem publicar APK comercial.
- Não apagar canais com base em um timeout ou em teste HTTP isolado.
- Não remover código sem pesquisa de referências, cobertura de testes e validação da equipe responsável.
- Conservar funções do laboratório ExoPlayer/LibVLC e protótipos futuros se houver uso planejado.

## Evidência obtida pela leitura do código
1. `lib/src/live/channel_repository.dart` consome duas playlists remotas: `iptv-org.github.io/iptv/countries/br.m3u` e `iptv-org.github.io/iptv/categories/sports.m3u`. A segunda é global, não estritamente brasileira.
2. A deduplicação em `_loadDirectory` usa somente URL como chave. URLs diferentes podem repetir um mesmo canal; URLs idênticas com nomes diferentes podem ser fundidas.
3. Existem 11 nomes em `_blockedChannelNames`, mas não há relatório de reprodução datado, por aparelho, associado a cada exclusão. Bloqueio por nome pode atingir feed alternativo válido.
4. O cache `_lastKnownGoodCache` mantém canais quando uma fonte remota falha; lista recuperada de cache não equivale a reprodução atual.
5. `isQuarantined` retorna sempre `false` e `_playbackFailures` guarda diagnóstico por URL, mas não determina remoção. Isso impede que um erro transitório exclua um canal indevidamente; não confundir com validação.
6. `LiveTvScreen.scan` examina apenas os primeiros 40 itens visíveis e contabiliza disponibilidade de URL, explicitando que ainda é necessário testar reprodução no player.
7. `branding/lab_approved.json` está vazio na branch inspecionada; não existe aqui uma lista assinada de canais atualmente reproduzíveis.
8. O catálogo experimental inclui grupos futuros (Filmes/Séries) em `labCategories`, mas isso não autoriza anunciá-los como conteúdo disponível na versão oficial.

## Matriz de homologação obrigatória por canal
Registrar: nome canônico, variante/região, URL original, origem da playlist, licença/autorização de redistribuição, data/hora da prova, dispositivo Android celular/Android TV, player ExoPlayer/LibVLC, código HTTP, início de imagem, áudio audível, reprodução contínua de 60 s e confirmação de 180 s, reconexão, resultado, evidência e responsável.

Estados:
- **APROVADO**: direito de distribuição confirmado + imagem e áudio reais durante 180 s no aparelho-alvo (ou evidência equivalente documentada).
- **INSTÁVEL**: falha intermitente, timeout, erro de busca/HEAD ou um único teste insuficiente. Manter fora dos destaques até nova prova, sem exclusão definitiva.
- **REPROVADO**: repetidas falhas de reprodução, em momentos diferentes e com testes documentados de pelo menos dois players quando cabível.
- **SEM AUTORIZAÇÃO**: não distribuir, independentemente de conseguir reproduzir.
- **NÃO TESTADO**: não anunciar como canal aprovado.

## Limpeza proposta, ainda não executada
1. Exportar catálogo atual para CSV/JSON com URL+nome+categoria e marcar equivalências por identidade canônica, região e provedor. Não deduplicar automaticamente canais regionais diferentes.
2. Testar amostra prioritária: SBT, emissoras locais com autorização, notícias, infantil, esportes. Confirmar direitos antes de reprodução/distribuição.
3. Fazer 60 s por player e 180 s para confirmar vencedor. Registrar falha e êxito com data.
4. Só após evidências, excluir links permanentemente indisponíveis do catálogo experimental ou mover para quarentena revisável. Nunca remover um canal estável por apenas um teste.
5. Auditar funções sem uso por análise de chamadas, `flutter analyze`, testes Flutter/Node e revisão de compatibilidade. Remover isoladamente com rollback.
6. Revalidar áudio, fullscreen, troca de canal pelo controle, Cast, login e bloqueio após qualquer alteração.

## Pendências explícitas
- Sem execução de stream audiovisual ou Android físico nesta inspeção: nenhuma reprodução foi homologada.
- Sem varredura completa de referências no repositório: nenhuma função foi classificada como seguramente removível.
- Sem inventário de direitos/licenças: nenhum canal novo deve ser lançado apenas porque seu link funciona.
- Pagamentos reais e assinatura permanecem na homologação separada do PR #42.

## Critério de saída
Gerar relatório por canal: VERDE/AMARELO/VERMELHO com evidências, CSV das URLs aprovadas, lista de variantes duplicadas e changelog de limpeza reversível, preservando APK oficial.

## Evidências históricas recuperadas em 26/10 (sem repetir testes)

A biblioteca de trabalho contém `Benchmark_RochaPlus_Catalogo.csv`, criado em 19/10/2026: 788 URLs avaliadas; 509 marcadas `video_audio`, 270 `sem_sinal` e nove casos restantes. Os resultados documentam detecção audiovisual por ferramentas externas naquele momento, **não homologação de ExoPlayer/LibVLC em Android**, nem direito de retransmissão. Não converter automaticamente `sem_sinal` em remoção definitiva.

Relatórios anteriores registram SBT Interior/Nacional com verificações FFmpeg de 60 e 180 segundos; ocorreram relatos físicos de áudio, imagem e fullscreen no celular, sem atribuição conclusiva de canal/build/duração. Emulador/CI audiovisual falhou no preflight de áudio em rodadas de 24 a 26/10: não usar como reprovação dos streams isoladamente.

**Fila de ação:** importar CSV histórico e cruzar por URL exata + identidade normalizada contra o catálogo remoto atual. Identificar URLs coincidentes: `video_audio` passa a candidato prioritário; `sem_sinal` recebe marcador *reteste recomendado*; outras URLs ficam *sem evidência atual*. Filtrar autorizações antes de adicionar ao catálogo comercial. Registrar decisões reversíveis e nunca apagar as listas originais ou favoritos.

**Separação de métricas:** teste HTTP HEAD ≠ FFprobe com áudio e vídeo ≠ 60/180 s no FFmpeg ≠ vídeo/áudio no aparelho Android ≠ autorização de distribuição. Cada camada deve aparecer separadamente no relatório final.
