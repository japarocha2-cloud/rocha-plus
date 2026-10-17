# Análise do teste físico enviado — 16/10/2026

Arquivo privado analisado: rocha-teste.txt. O log bruto permanece fora do repositório; este documento contém apenas achados técnicos selecionados. O teste foi executado pelo usuário no celular e no Chromecast, não por controle remoto do agente.

## Evidência
O caminho observado é Google Cast, com carregamento direto da URL HTTPS na TV, não espelhamento de tela Android. No Nickelodeon (Brazil) (480p), duas sessões passam de PLAYING para BUFFERING repetidamente e terminam em IDLE com idleReason ERROR. Não há evento PAUSED nos status de mídia Cast capturados.

- Sessão 7: do primeiro LOADING ao ERROR, aproximadamente 54,7 s.
- Sessão 8: do primeiro LOADING ao ERROR, aproximadamente 68,0 s.

As posições também deixam de progredir em vários eventos. Isso comprova falha da reprodução remota e diferencia o travamento de pausa voluntária. Não revela se a causa original é transporte da fonte, Wi-Fi do Chromecast, compatibilidade do receptor ou comportamento do fluxo HLS. Não há prova de que a conexão de internet doméstica tenha caído.

O arquivo inclui registros antigos, de outros aplicativos e de builds de laboratório; exceções antigas não foram atribuídas à falha atual.

## Contraprova limitada
Uma requisição atual da playlist respondeu HTTP 200. FFmpeg conseguiu decodificar aproximadamente 70 segundos de mídia para saída nula, concluindo com código 0 e 2060 quadros. A leitura utilizou conteúdo disponível em buffer e terminou em cerca de 32,6 s de processamento; não representa 70 s de reprodução física. Houve avisos de parâmetros H264 ausentes durante a entrada na transmissão. O resultado não comprova compatibilidade nem continuidade no Chromecast.

## Correção complementar
Além de observar a desconexão da sessão, o player e os controles passam a tratar IDLE/ERROR da mídia confirmada. O erro aciona a retomada local quando o app havia pausado o celular para transmitir à TV. Erros de outra mídia e pausa voluntária não acionam essa recuperação. O observador do player permanece ativo após sair dos controles e é cancelado na desmontagem.

Não há reconexão automática à TV nem alteração de canais, preços, trial, login ou congelamentos. A causa da interrupção remota permanece aberta. APK com a alteração ainda não foi gerado ou instalado.

## Validação automatizada
Análise estática, 38 testes Flutter e 5 testes Node aprovados: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/38984466828. Inclui regressão do estado IDLE/ERROR com a sessão ainda conectada, erro de mídia alheia, pausa voluntária e remoção da área privada. Não substitui a homologação em aparelho físico.
