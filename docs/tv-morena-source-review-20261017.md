# TV Morena — revisão de fonte (não publicada)

Origem: https://gist.github.com/accacio1/bc0b5b58ade01081b6f7c6897cce02ff
Data da revisão: 2026-10-17
Base: checkpoint/mobile-sbc-kids6-approved-20261017

## Candidatos encontrados na lista histórica
- TV Morena padrão: identificador 5290
- TV Morena HD: identificador 5291
- TV Morena FHD: identificador 5292

## Verificação
- O Gist tem atividade histórica de 2022 e aponta para um único provedor IPTV de terceiros.
- Endereços inteiros e credenciais do provedor NÃO foram incorporados ao aplicativo.
- Nenhuma origem foi comprovada como ativa ou autorizada para redistribuição no Rocha+.
- Em catalog/approved.json da base existem 192 entradas, sem TV Morena.

## Antes de gerar um APK com TV Morena
1. Identificar uma transmissão atual e com permissão de distribuição.
2. Verificar resposta HLS, decodificação de vídeo e áudio e estabilidade por teste físico.
3. Adicionar à branch de testes, sem modificar branches freeze/ ou checkpoint/.
4. Compilar APK de teste isolado e comparar com baseline.

STATUS: PENDENTE. Não anunciar como adicionado ou build concluído.
