# Revisão visual e player — código LAB, sem novo pacote

Defeito comprovado por geometria: seis cartas230px em x350+i245 terminavam em1805, todas dentro de1920; faltava a carta parcialmente visível exigida. GalleryBrowser.brs agora recorta categoryRows em [350,0,1380,1080] (borda1730) e desliza first=max(0,categoryIndex-4). Cinco cartas completas e155px da sexta são visíveis; quando focada, a sexta entra integralmente na janela. Dimensões, artes, nomes, categorias, ordem e pool6preservados. Última categoria pode não ter sucessora parcial, por fim da lista; wrap mantém Outros e foco visível.

Recurso clippingRect é documentado pelo Roku: https://developer.roku.com/dev/docs/group . Fonte oficial consultada; retângulo limita desenho do Group/descendentes no sistema de coordenadas local. Não há novo bitmap nem redesenho de cartas.

Baseline anterior falha no teste de viewport; correção passa8novoschecks +33regressões relacionadas no engine localBRS2.6.2. Resultado e hash do engine em roku-headless-tests.json. Cenários de preview, troca rápida, Back, fullscreen único, timeout, grade favoritos e pools foram repetidos porque GalleryBrowser foi alterado e compartilha render/navigation com ChannelBrowser.64backend/36Android não repetidos nesta etapa.

| Item aprovado | Evidência / limite |
|---|---|
| Galáxia/logo/banner/menu | XML e arte original mantidos; captura nativa0.6.7 já persistida, não repetida |
| Carrossel parcial + foco | Corrigido no fonte;8checksnovos, sem imagem nativa do novo fonte |
| Lista vertical/capa ao lado/nome | ChannelBrowser pool7 e coordenadas existentes; fonte preservado |
| Prévia direita/fullscreen/Back | Harness relacionado passa; só um channelVideo, controle de preview debounce |
| Busca | KeyboardDialog + filtro nome local; não novo teste interativo pois bloqueio mantido |
| Favoritos | Pool6cartas, retorno e Home verificados em harness; registro real não tocado |
| PET/Outros | Índices preservados18/20; PETvazia conforme catálogo existente |
| Relógio sóHome | Novos checks de visibilidade/timer ao sair/retornar |
| Artes/catálogo | Não alterados nesta correção |

Player: código para fechamento manda control:stop e aguarda state stopped antes de substituir decoder; falha de stop após3s produz mensagem. A liberação da reserva é solicitada em stopPreview antes da confirmação de término pelo decoder. O harness testa solicitação/stop, mas não mede quando o dispositivo remoto efetivamente cessou de renderizar. **Lacuna restante:** medir confirmação de stop e corrida de liberação/novo play sob rede/decoder reais; não afirmar simultaneidade física garantida pelo teste. Também não foi demonstrada perda de decoder ou vazamento; não modificar isso sem reprodução específica. onVideoStateChanged buffering e timeout25s/error preservados; recuperação é retry explícito, não conexão comprovada.

Memória/FPS: nenhum valor físico novo. Pools limitados não equivalem a RAM do processo. EndpointFPSsimulador permanece inutilizável como métrica. Áudio/reprodução contínua/reconexão real não executados. Nenhuma abertura do simulador, bypass ou pacote gerado. ZIP0.6.7 instalado continua anterior ao ajuste do carrossel; somente fonte para futuro pacote autorizado foi corrigido.
