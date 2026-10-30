# ROCHA+ TV — Preparação conjunta Roku TV e Android TV (29/10/2026)

## Escopo e fontes de verdade
- Repositório: japarocha2-cloud/rocha-plus.
- Android TV: PR #42 (fix/subscription-access-20261026), PR #22 (Home/login), PR #19 (fullscreen), PR #33 (LAB).
- Roku TV: PR #43 (Roku 0.6.1, benchmark), PR #23 (catálogo anterior compartilhado).
- Referências: docs/auditoria/2026-10-29-roku-catalogo.md, platforms/roku/README.md, platforms/roku/catalog/benchmark-manifest.json, benchmark-pending.json, benchmark-test.json e tools/import_roku_benchmark.py (PR #43).
- Não confundir 395 candidatos HTTPS/HLS do benchmark com canais aprovados fisicamente. Não substituir catálogo Android automaticamente com candidatos Roku.

## Regras comuns, sem mudanças na versão oficial
1. Preservar todos os canais aprovados, variantes regionais e URLs alternativas válidas; nunca excluir por falha transitória ou por nome apenas.
2. Manter reprovados com evidência separados para revisão, sem remoção automática do APK oficial.
3. Manter seis registros inconclusivos do LAB Windows em quarentena até recuperar o JSON original dos 479 registros; não inventar nomes/URLs nem afirmar que os 473 restantes estão aprovados.
4. Preservar identidade visual aprovada, imagens, logos, categorias, favoritos, contas, assinatura e gate; não contornar login ou pagamentos.
5. Manter PR #42 e #43 draft, sem merge, deploy, publicação, cobrança real ou atualização de APK oficial.
6. Não repetir cenários verdes sem alteração relacionada, regressão ou evidência contraditória.

## Preparação de testes físicos
### Android TV
- Abrir canal via D-pad/OK em fullscreen; Voltar retorna à grade; CH+/CH- e troca rápida.
- Vídeo e áudio contínuos por 180 segundos com evidência (aparelho, versão, URL/identidade, início/fim, falhas).
- Verificar LibVLC/ExoPlayer, foco após recuperação, descarte/reabertura, rede e memória.
- Não confundir CI simulado com teste físico.

### Roku TV
- Usar candidato experimental Roku 0.6.1 do PR #43; não presumir instalação nem player liberado.
- Conferir catálogo exportado, IDs, categorias, logos, navegação remota, conta/assinatura e endpoints configurados em ambiente de teste.
- Validar reprodução real e áudio/vídeo por 180 segundos por canal de amostra aprovado; registrar evidência.
- BrightScript/SceneGraph e pacote Roku são distintos do APK Android.

## Bloqueios explícitos
- JSON original dos 479 resultados LAB Windows não disponível neste repositório: impossível identificar/exportar os seis inconclusivos sem o arquivo.
- Testes físicos de Android TV e Roku TV dependem de dispositivos; nenhum aprovado por este documento.
- Segredos, certificados, endpoints de produção e credenciais não devem ser inventados ou inseridos.

## Critérios de saída
- Inventário auditável de aprovados/reprovados/inconclusivos por identidade e URL.
- Catálogo candidato reproduzível por plataforma, sem remoção de aprovados.
- CI e validação de pacote experimental, seguidos de testes físicos documentados.
- Aprovação explícita separada antes de qualquer publicação.

Status: preparação documental apenas; não comprova configuração de serviços, build, instalação ou reprodução física.
