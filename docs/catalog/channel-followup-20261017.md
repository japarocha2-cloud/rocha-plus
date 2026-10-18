# Canais solicitados — verificação de 17/10/2026

Branch de trabalho: feat/soul-tv-candidates-20261016. Base da APK instalada: 9ade44d8a0c41fa8d897592b248168dc1487d5ad, versão experimental 3. Nenhuma promoção para produção ou alteração do APK 4005.

## Referências Soul TV identificadas

As páginas públicas foram consultadas diretamente em 17/10/2026:
- https://www.soultv.com.br/channel/193: TV Mais Brasil.
- https://www.soultv.com.br/channel/74: ISTV (já cadastrada; não duplicar).
- https://www.soultv.com.br/channel/313: SBC (já cadastrada como SBC TV).

Os números pertencem à Soul TV e não são a numeração do catálogo Rocha+.

## SBC: retorno físico do proprietário

Lucas confirmou nesta data que a SBC funciona na APK experimental, com imagem perfeita e áudio funcionando. Isso comprova abertura, vídeo e áudio no aparelho usado por ele; não comprova estabilidade prolongada, Chromecast ou autorização de distribuição. Não trocar a fonte aprovada tecnicamente nesta investigação.

## TV Mais Brasil

Site oficial: https://tvmaisbrasil.com.br/
Player incorporado pelo próprio site: https://playerv.samcast.com.br/video/tvmaisbrasil/2/true/true/YzNSdGRqZ3VjMkZ0WTJGemRDNWpiMjB1WW5JPSta/16:9//nao/nao

O código do player publica a fonte:
https://stmv8.samcast.com.br/tvmaisbrasil/tvmaisbrasil/playlist.m3u8

Manifest HTTPS respondeu 200. FFmpeg decodificou 899 quadros, 29,994 segundos, vídeo H.264 High 1920x1080 a 30 fps e áudio AAC LC estéreo 48 kHz. Processo terminou com código zero. Teste curto de servidor, sem validação Android/Cast ou estabilidade contínua.

Permissão de distribuição no Rocha+ ainda não comprovada. Continua candidata fora de catalog/approved.json, conforme critério original da passagem de plantão. Não confundir acesso público ao player com autorização.

Contato publicado em https://tvmaisbrasil.com.br/contato/: diretoriatvmaisbrasil@hotmail.com e glauco-camargo@hotmail.com. Nenhuma mensagem enviada.

## TV da Quebrada

Site associado à emissora pelo guia de canais: https://www.tvdaquebrada.com.br/
A consulta direta retornou HTTP 403. Não foi encontrada e validada uma fonte oficial HLS nesta rodada. Isso não prova que a emissora esteja fora do ar. Não incluída como aprovada.

## Band

Ausente de catalog/approved.json. Não é um bloqueio de preferência do celular.
A página oficial https://www.band.com.br/ao-vivo respondeu 200 e usa player Spalla:
https://beyond.spalla.io/player/?live=019a797e-eeb8-7eda-9518-132403ccb160

Não foi validado nesta rodada um manifest de transmissão ao vivo reutilizável no player nativo Rocha+. O MP4 de 98 segundos presente nos metadados sociais do player não deve ser cadastrado como canal ao vivo. Autorização de distribuição também não comprovada.

## Recuperação dos relatórios CMD

Relatórios originais localizados nos arquivos enviados pelo proprietário:
- channel_stability(1).csv, de 11/10: 348 linhas; 336 completou_teste, 6 tempo_esgotado, 5 erro_decodificacao_ou_rede e 1 terminou_antes_do_prazo.
- channel_stability_20261012.csv, de 12/10: 348 linhas; 313 completou_teste, 22 tempo_esgotado, 11 erro_decodificacao_ou_rede e 2 terminou_antes_do_prazo.
- No segundo relatório, somente 311 das 313 linhas completou_teste também atingem 29 segundos com codecs de vídeo e áudio. O status isolado não basta para admissão.

Busca por nomes infantis (kids, infantil, nick, cartoon, disney, toon, pluto, gloob, baby, boomerang, anim, discovery):
- Gospel Cartoon (360p): 30,03 segundos em ambos; já incluído.
- Nickelodeon (Brazil) (480p): 30 segundos em ambos; já incluído. Os logs de Cast posteriores registram falhas; a aprovação de FFmpeg não aprova Cast.
- Box Kids TV (720p): 30,03 segundos em ambos, mas fonte HTTP de terceiro; já excluída por insecure_http_transport. Não reintroduzir nem liberar HTTP globalmente para restaurá-la.

Band e canais com nome Pluto não aparecem nesses dois CSVs. Não atribuir aprovação a eles nem substituir esse resultado por uma varredura pública sem seleção.

Conclusão: os relatórios recuperados não justificam acrescentar outros infantis aprovados ao catálogo atual. O pedido de ampliar Infantil continua pendente de fontes oficiais funcionais e de comprovação do direito de distribuição. O catálogo permanece com 191 entradas, incluindo dois infantis.
