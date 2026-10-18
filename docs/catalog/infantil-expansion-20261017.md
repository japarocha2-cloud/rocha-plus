# Ampliação do Infantil — investigação de 17/10/2026

## Escopo e preservação

Pedido do titular: ampliar principalmente Infantil, mantendo o comportamento atual aprovado. A APK 5 congelada permanece em freeze/mobile-images5-approved-20261017, commit 82c3bbc3204b6d4921c3f2948d14cde073cff037. Nenhum código de aplicativo, player, identidade visual, pagamentos ou catálogo de execução foi alterado nesta rodada.

O catálogo continua com 191 entradas, sendo dois infantis. Não substituir canais existentes nem bloquear canais por timeout ou falha transitória.

## SBC Kids — candidata prioritária, ainda não aprovada para o catálogo

- Página do grupo: https://www.sbcgroup.com.br/sbckids
- Site vinculado pelo grupo: https://sbckids.com.br/
- Contato publicado: contato@sbcgroup.com.br; telefone 11 96575-6354.
- Atenção: a página do grupo identifica um canal infantil distinto; não presumir que autorização ou teste da SBC TV generalista cubra SBC Kids.
- O site infantil indica o iframe https://tv.brascast.com/player/tv411747?ar=16&as=1, que retornou HTTP 404 nesta consulta.
- No host atual https://live.brascast.com/player/tv411747, a configuração window.PHCFG identifica o título SBC PIPOCA e outra fonte. Não usar esse sinal na categoria Infantil.
- Uma pista de terceiro indicava rede1220. O player público do próprio provedor https://live.brascast.com/player/rede1220/1 confirmou o título SBC KIDS e a fonte https://video01.brascast.com/rede1220/rede1220/playlist.m3u8. Isso confirma metadados do provedor, mas a ligação atual do site infantil com essa fonte e os direitos de distribuição ainda precisam ser confirmados pela emissora.

### Testes realizados

1. FFprobe direto: não terminou dentro de 22 segundos. Não interpretar como canal permanentemente offline.
2. Requisição HTTPS da playlist: HTTP 200; manifest mestre leva a uma playlist de mídia com contexto de sessão temporário.
3. Primeiro segmento listado: HTTP 404. Possível expiração na janela ao vivo; não foi determinada a causa no servidor.
4. Nova playlist, checagem dos cinco segmentos mais recentes: todos HTTP 200.
5. Segmentos baixados foram concatenados localmente e decodificados por FFmpeg: 900 quadros, 29,977007 segundos, saída zero e sem mensagens de erro na decodificação.
6. Vídeo H.264 1920x1080; áudio AAC, estéreo, 44.100 Hz.
7. Um quadro da amostra foi inspecionado visualmente e mostrava animação infantil. Isso não comprova adequação de toda a grade nem direitos sobre os programas.
8. O teste é decodificação de uma amostra local obtida dos segmentos. Não equivale a reprodução contínua da URL no Android, Chromecast ou Roku, nem mede estabilidade prolongada ou capacidade de rede do usuário.

Manter approved=false. Antes de integrar: confirmar com o canal a fonte autorizada para OTT/Android TV/Cast/Roku e as condições de distribuição; depois validar a URL estável no player Android, áudio, reconexões e Cast sem alterar a APK congelada. Não fixar parâmetros de sessão temporários no catálogo.

## Outras opções oficiais

### DumDum / Stenna
- https://www.canaldumdum.com.br/contato/
- O próprio site oferece contato para inclusão na grade de operadoras.
- contato@stennagroup.com; telefone 11 99814-9991.
- https://stennagroup.com/servicos/ descreve distribuição para streaming OTT.
- Fonte autorizada e condições comerciais ainda não obtidas; nenhuma decodificação executada, nenhum custo assumido.

### Box Kids TV / Box Brazil
- https://www.boxbrazil.tv.br/boxkids.php
- comunicacao@boxbrazil.tv.br.
- Página oficial lista operadoras e formulário de contato.
- A fonte antiga do relatório CMD era HTTP e continua excluída. Não substituir apenas o protocolo ou liberar HTTP globalmente.
- Falta fonte HTTPS autorizada e validação técnica. Não incluído.

### Pluto TV — canais infantis solicitados anteriormente
- https://service-website-app-use1-1.prd.pluto.tv/partners
- Contato oficial para distribuição: distributionqueries@pluto.tv.
- A disponibilidade no aplicativo da Pluto não confirma distribuição autorizada no Rocha+. Nenhum canal da Pluto foi incluído ou declarado validado nesta rodada.

## Resultado

Uma nova candidata infantil com amostra de vídeo e áudio decodificada: SBC Kids. Aprovação de distribuição e validação Android/Cast permanecem pendentes. DumDum, Box Kids e Pluto têm caminhos oficiais de contato identificados. Nenhuma mensagem foi enviada a terceiros. Nenhuma APK nova foi gerada, pois nenhuma candidata reuniu todos os critérios para integrar o catálogo.

## Atualização após a investigação — inclusão experimental solicitada

Lucas pediu explicitamente adicionar SBC Kids após receber os resultados acima. A candidata foi adicionada somente à branch experimental, para APK 6, mantendo as 191 entradas anteriores byte a byte em seus objetos e todas as funções da APK 5. São 192 canais, três infantis. A aprovação neste contexto é técnica para teste pelo titular; distribution_permission continua unverified e não há declaração de acordo de distribuição. O sinal ainda exige teste físico pelo titular e não foi promovido à produção.

As cópias de catálogo Roku e web-TV foram sincronizadas, sem alegar homologação física nessas plataformas. O workflow sbc-kids-runtime-check testa separadamente abertura e avanço da posição de vídeo usando o plugin nativo Android e o limite de inicialização de 8 segundos do player atual; sua APK diagnóstica não é distribuída. Consultar os logs dessa execução para o resultado, sem confundir decodificação local FFmpeg com reprodução nativa.
