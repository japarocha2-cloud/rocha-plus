# ROCHA+ Roku — atualização do catálogo de teste — 29/10/2026

## Resultado

Integrado o snapshot `Benchmark_RochaPlus_Catalogo.csv`, SHA-256
`17095a366a0ec73ac6cc85be27469500d3a10aac4df89ebf137ae0c54d424914`.
O inventário possui 788 URLs únicas: 509 `video_audio`, 270 `sem_sinal`,
4 `audio_apenas`, 1 `video_apenas` e 4 `tempo_esgotado`.

O cliente Roku 0.6.1 de teste carrega `catalog/benchmark-test.json`: 395 resultados
positivos com HTTPS/HLS, preservando a política de transporte existente.
Os demais 393 registros estão em `benchmark-pending.json`, incluindo os 114
positivos incompatíveis com o filtro atual (HTTP e/ou formato não confirmado).
Nenhuma URL foi apagada. O catálogo antigo de 190 permanece em `approved.json`
para histórico e preservação de IDs, grupos e logos por URL exata.
Entradas novas sem categoria comprovada ficam em Geral; não há inferência de
conteúdo infantil. Nomes, URLs e evidência originais são conservados.

## Limites e preservação

`video_audio` significa detecção audiovisual externa histórica, sem comprovar
180 segundos no Roku, codecs aceitos pelo aparelho ou autorização de distribuição.
As entradas carregadas usam `benchmark_av_detected`, `approved:false` e
`roku_playback_verified:false`, sem promovê-las a canais homologados.
Este snapshot foi o maior inventário testado localizado, não uma varredura nova.

Base isolada: `audit/roku-cast-continuity-20261016`, commit
`3ac4cb0090cea8f8d291896504af63f4a7dc025f`.
Branch de implementação: `feat/roku-current-catalog-20261029`.
Não altera Android, main, pagamentos, endpoints, imagens ou layout.
Login e assinatura conservam o bloqueio existente: os endpoints vazios da base
impedem acesso ao player. Não foi introduzido bypass para demonstrar o catálogo.

## Verificação e entrega

O importador reproduz os arquivos e confere o SHA-256 da origem. Seis testes
cobrem inventário, filtro de reprodução, IDs e metadados existentes, bloqueios
explícitos, origem modificada e exportação reproduzível.
O workflow `Roku current benchmark catalogue` executa esses testes e compila o
cliente SceneGraph/BrightScript com BrighterScript 0.69.0, gerando ZIP e SHA-256.
Consultar a execução do commit antes de declarar a compilação aprovada.

## Pendências

Configurar os serviços compatíveis de pareamento e assinatura; instalar o ZIP
via sideload na TV; validar navegação, favoritos, vídeo/áudio contínuos,
reconexão e expiração. Revisar os 114 positivos fora do filtro com evidência de
formato e compatibilidade. Publicação de loja e instalação física não realizadas.
