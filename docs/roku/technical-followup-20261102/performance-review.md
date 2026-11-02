# Revisão de desempenho e ciclo de vida — 02/11/2026

Base de código analisada: f5cce4b70d40edcb6a342312215a1b2314b79589, LAB0.6.4. A etapa0.6.5 não altera BrightScript/XML.

- ChannelBrowser.brs: sete slots são criados uma vez; renderizações reatribuem URI só quando muda página/revisão. Poster de linha sem item limpa URI. Não há crescimento de pool no código revisto.
- GalleryBrowser.brs: seis cartas de categoria e seis de favoritos são criadas sob demanda, guardadas em m e reutilizadas. Contagens de categoria são invalidadas por channelRevision. A varredura do catálogo ao invalidar é limitada; não foi demonstrada lentidão que justifique nova cache ou reordenação.
- Prévia: um Video de canal é reutilizado. queuePreview chama stopPreview antes do debounce350ms; a troca aguarda saída de playing/buffering/paused e tem limite de parada3s. Conteúdo anterior tem uma única referência substituída, sem lista crescente de ContentNodes.
- Saída por Voltar na lista, categoria vazia, falha, timeout e negação de acesso interrompe preview/timers. Tela cheia→prévia mantém o mesmo decoder por projeto. Voltar novamente para a galeria interrompe stream.
- Relógio/carrossel são parados fora da Home. A introdução usa outro nó, mas é interrompida antes de agendar a prévia; eventual sobreposição real de decodificadores exige F07 em hardware.
- Texturas de pools ocultos podem permanecer referenciadas de forma limitada. Isto não demonstra vazamento; cache global do renderer, memória GPU e coleta de ContentNodes não foram medidos.
- Não foi demonstrado defeito novo que justifique alteração da lógica. Não houve refatoração preventiva nem repetição dos30 cenários de comportamento verdes. O teste de delta verifica byte a byte que todo código e catálogo empacotados permanecem iguais.

Medições de arquivo: ZIP0.6.4=4.521.472 bytes;0.6.5=4.533.575 bytes (+12.103 bytes/+0,27%), devido à única capa nova.578 mapeamentos/534 texturas. Não se afirma melhora ou regressão deFPS/RAM a partir desses tamanhos.
Os limites e testes anteriores continuam históricos:7 linhas/42 nós,6 categorias/24 nós,6 favoritos/30 nós, zero alocações de nós em1000 renders no harness. Não equivalem a estabilidade física.
Riscos ainda a testar:F06–F09 (trocas/decoder/Voltar), F14–F20 (rede, sessão longa, memória/texturas/controle/Home). Ver roteiro físico. Nenhum teste físico ou mediçãoFPS/RAM foi executado nesta etapa.
