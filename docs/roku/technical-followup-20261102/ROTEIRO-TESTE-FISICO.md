# Roteiro de homologação física — Roku LAB 0.6.5

**Estado: NÃO EXECUTADO.** Este arquivo prepara o teste; não homologa aparelho, canal, áudio ou desempenho. Resultados anteriores da Candidata 6 Android permanecem congelados.

## Preparação e identificação

- Instalar somente o ZIP LAB autorizado, sem substituir a versão oficial de produção.
- Registrar modelo Roku, firmware, resolução, TV/saída de áudio, rede (Ethernet/Wi-Fi), distância do roteador, data, testador e commit.
- Conferir ZIP pelo SHA256 em final-build.json. Guardar o 0.6.4 para comparação com as mesmas condições.
- Usar sessão/conta LAB já autorizada. Não alterar trial, assinaturas, pagamentos, homologações ou favoritos pessoais.
- Escolher canais de teste já presentes: um infantil, um de notícias, um esportivo, um de sinal estável e um que apresente falha reproduzível. Não transmitir novos links nem mudar a classificação.
- Salvar logs sem URLs assinadas, tokens ou credenciais. Registrar nome/ID do canal, horário e resultado. Usar o CSV desta pasta.

## Casos e critérios observáveis

| ID | Procedimento | Critério para registrar aprovação |
|---|---|---|
| F01 | Abrir o LAB a frio e aguardar Home | Sem crash; galáxia/logo corretos; nenhuma prévia de canal na Home |
| F02 | Percorrer todas as categorias com setas e segurar uma seta | Ordem preservada, PET presente, foco visível; sem salto indevido/travamento |
| F03 | Abrir categorias com 0, 1 e muitos canais | Estado vazio correto e seleção dentro dos limites; nomes/capas corretos |
| F04 | Abrir lista e aguardar prévia automática | Primeiro quadro identificado, nome corresponde ao vídeo; registrar latência real |
| F05 | Conferir imagem e áudio por 180 s em cada canal da amostra | Imagem contínua, áudio audível e sincronizado; registrar interrupções |
| F06 | Fazer 50 trocas rápidas de seleção e aguardar a última | Último canal selecionado corresponde à prévia; sem áudio anterior ou sobreposição |
| F07 | Medir requisições/decodificadores durante F06 com ferramentas do aparelho | Um stream de canal ativo; anterior encerrado; guardar método/evidência |
| F08 | Acionar Assistir/OK e voltar 20 vezes | Tela cheia ocupa a tela; Voltar retorna à mesma prévia sem novo stream desnecessário |
| F09 | Usar Voltar na lista, categorias e Home | Lista→categorias (ou favoritos de origem), depois Home; saída para Home para stream |
| F10 | Abrir favoritos vazios; adicionar favoritos só na conta de teste | Vazio correto; grade de cartões grandes com foco e nomes corretos |
| F11 | Percorrer grade 3x2, páginas e última página incompleta | Setas/OK/Voltar funcionam; sem índice inválido ou capa trocada |
| F12 | Remover favorito selecionado e o último favorito de teste | Grade/lista atualiza sem crash; dados pessoais não alterados |
| F13 | Encerrar e reabrir LAB | Favoritos de teste persistem; sem restauração de canais removidos |
| F14 | Interromper internet no roteador de teste durante prévia | Interface responde; carregamento/falha controlados; sem loop de novas tentativas |
| F15 | Restaurar internet e pressionar OK para tentar novamente | Novo stream inicia ou falha claramente; sem necessitar reinstalação |
| F16 | Repetir perda/retorno da rede em tela cheia | Voltar e retry continuam utilizáveis; sem stream oculto persistente |
| F17 | Usar canal já presente que falha ou demora | Registrar timeout próximo de 25 s quando aplicável; lista/controle continuam responsivos |
| F18 | Reproduzir por 60 min e alternar 100 vezes entre telas | Registrar crashes, buffering, sincronismo e funcionamento do controle |
| F19 | Medir RAM/texturas/FPS/CPU no início, 15, 30 e 60 min | Comparar tendência com 0.6.4; identificar retenção crescente com evidência, sem inventar valores |
| F20 | Pressionar Home do controle Roku, reabrir e encerrar app | Sem áudio residual ou stream mantido após encerramento; foco e sessão recuperados |
| F21 | Conferir beIN Sports Haber na lista onde já existe | Logo beIN SPORTS HABER correto, proporção preservada; canal/ordem inalterados |

## Registro de resultados

Cada linha do CSV começa como NOT_EXECUTED. Alterar somente após execução real para PASS, FAIL ou INCONCLUSIVE. Incluir aparelho, canal/ID, duração, primeiro quadro em ms, áudio, falha reproduzível, logs e captura quando disponível.
Não aprovar F07 ou F19 apenas por percepção visual. Se ferramentas de medição não estiverem disponíveis, marcar INCONCLUSIVE e explicar. O endpoint de FPS do BRS Desktop retorna valor fixo e não serve para medição física.
Uma falha de stream não autoriza remover/reprovar/restaurar canais. Relatar o fato e preservar catálogo e homologação. Evitar repetir testes Android congelados.
Após execução, atualizar o relatório mestre com resultados e evidências; commit/push só na branch experimental, sem merge/publicação.
