# Candidatos Soul TV para Rocha+ (16/10/2026)

Origem: solicitação do proprietário do Rocha+.

- SBC TV, Soul TV canal 313: já cadastrada em `catalog/approved.json` como SBC TV (1080p). Teste FFmpeg de 30s relatado em `docs/catalog/sbc-20261016.json`. Teste físico, estabilidade e autorização de distribuição ainda pendentes.
- ISTV, Soul TV canal 74: já cadastrada em `catalog/approved.json`; não duplicar.
- TV Mais Brasil, Soul TV canal 193: página https://www.soultv.com.br/channel/193 confirma o canal; URL HLS e permissão de distribuição no Rocha+ não verificadas. NÃO incluir em approved sem validação.
- TV da Quebrada: solicitada; identificar página oficial/sinal de vídeo e autorização; não confundir com o programa 'Canal da Quebrada'. NÃO incluir em approved sem validação.

## Critérios para aprovação

1. Confirmar fonte oficial de mídia compatível, licença/autorização para exibição no Rocha+ e disponibilidade ao público.
2. Testar decodificação de vídeo e áudio por pelo menos 30 s; testar abertura e estabilidade no telefone e Cast.
3. Cadastrar apenas entradas não duplicadas, mantendo grupos e funções congeladas intactos.
4. Criar build candidata assinada separada do APK 4301 e testar fisicamente antes de promover.

Estado: NÃO foram adicionadas fontes fictícias e NÃO foi gerado APK por esta nota.

## Pesquisa adicional (16/10/2026)

- TV Mais Brasil: site próprio https://tvmaisbrasil.com.br/ e Soul TV canal 193 confirmados por fontes públicas.
- URLs HLS encontradas em listas públicas de terceiros, **não validadas** (NÃO inserir no catálogo aprovado sem testes e autorização):
  - https://stmv8.samcast.com.br/tvmaisbrasil/tvmaisbrasil/playlist.m3u8
  - https://stmv1.paineltv.net/tvmaisbrasil/tvmaisbrasil/playlist.m3u8
- Tentativa de requisição direta às duas URLs pelo ambiente disponível retornou ConnectionError: não se pode afirmar se os streams estão online ou offline.
- TV da Quebrada: listada na grade Soul TV compilada por Line-UP (https://www.lineup.tv.br/vod.php?idVOD=11413); URL HLS oficial ainda não localizada.
- Acesso HTTP 200 ou reprodução dentro da Soul TV não substituem autorização para o Rocha+.
- O processo disponível nesta sessão não expõe um acionamento de workflow_dispatch do GitHub Actions; APK não gerado.
