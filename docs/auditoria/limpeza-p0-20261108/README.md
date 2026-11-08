# Limpeza inteligente P0 — 08/11/2026

## Escopo e continuidade

Auditoria integral dos arquivos rastreados em quatro snapshots, sem misturar aplicações ou reescrever branches congeladas. Base Android: 50fd7fa (Candidata 7); Roku: 4f281e6 (último P0); Web TV: 86bdabe (branch de integração existente); main: d18478c (snapshot local `work`). SHAs completos estão no inventário. Não é varredura de todas as revisões históricas ou de serviços remotos. Caches, SDKs e arquivos locais não rastreados não são produto e não entram na classificação de arquivos mortos.

Lidos o relatório de varredura de 07/11, a continuidade P0 e o plantão Roku. As falhas antigas dos fixtures Flutter já foram corrigidas e tiveram CI verde; não foram reabertas. A Candidata 6 permanece homologada em 19–21/10/2026, 180 segundos por canal com áudio/imagem, sem exigência de nova aprovação. Oficial, Candidata 6, catálogos, decisões, capas e evidências não foram modificados.

## Encontrados e preservados

| Snapshot | Arquivos | Grupos SHA-256 iguais dentro do snapshot | Falhas de formato verificadas | Links Markdown quebrados |
|---|---:|---:|---:|---:|
| Android C7 | 257 | 0 | 0 | 0 |
| Roku P0, incluindo Web TV | 1712 | 34 | 0 | 8 |
| Integração Web TV | 235 | 6 | 0 | 0 |
| Main | 89 | 0 | 0 | 0 |

São 2293 registros de arquivo em snapshots distintos, não 2293 caminhos únicos. Os seis grupos da integração Web também aparecem no snapshot Roku: não somar os grupos como redundâncias únicas. [Inventário completo](inventory.json) relaciona caminho, tamanho, SHA-256, grupos e candidatos a referências textuais por arquivo.

- Quatro grupos de branding Android/Web: galáxia, introdução, wordmark e ícone. Cópias necessárias nos roots de empacotamento independentes, preservadas.
- Catálogos approved/quarantine em três roots: consumidos por pacotes próprios. Protegidos explicitamente; não substituir por symlinks ou remover cópias.
- Arquivos Roku/LAB equivalentes: source/main, PairingRequest, benchmark, configuração e branding. Componentes são carregados pelo SceneGraph, por nome e por convenções pkg:/; não são mortos por ausência de import textual.
- Imagens de capa iguais com IDs diferentes: associação por identidade e arquivo esperada pelos catálogos; não deduplicar nem alterar IDs.
- Capturas/XML históricos iguais: evidências de etapas diferentes, preservadas mesmo com bytes iguais.
- experiments/central-rights/https-runtime.mjs e experiments/roku-0610/https-runtime.mjs: entrypoints de experimentos independentes; uso/implantação independente impede fusão segura nesta limpeza.
- appinfo.json/config.xml Web TV são manifests reconhecidos pela plataforma. PairingRequest.xml é componente SceneGraph. Ausência de referência textual direta não indica desuso.

Nenhuma redundância de produto foi comprovada como removível com segurança. Nenhum arquivo foi excluído, movido ou substituído por link.

## Corrigidos

Oito links em `docs/roku/physical-package-rev4-20261103/playback-investigation-20261103.md` e `playback-p0-20261103.md` usavam `../../../../` quando o root está a três níveis. Corrigidos para `../../../` e conferidos os oito destinos reais. A evidência original e seu significado foram preservados. Commit Roku: 6ccbf96, branch `lab/limpeza-roku-p0-20261108`. Nenhum dado do pacote mudou; regenerar APK/ZIP não é necessário para correção de links documentais.

## Integridade, referências e testes

Todos os blobs dos snapshots foram lidos e receberam SHA-256. `git fsck --connectivity-only` passou. JSON foi interpretado, XML analisado, ZIP verificado por CRC; PNG/JPEG/WebP/GIF verificados e decodificados com Pillow 13.0.0; MP4 inspecionado com ffprobe. Nenhuma falha encontrada nesses formatos. MP4 não teve cada frame decodificado; um SHA calculado sem checksum externo não comprova autenticidade histórica.

Imports/exports/parts Dart relativos e caminhos literais Roku pkg:/ foram resolvidos: nenhum destino faltante encontrado. Referências textuais completas dos snapshots foram consultadas para grupos duplicados; carregamento dinâmico, globs, consumidores externos e convenções de plataforma impedem concluir uso apenas por busca textual. Não se fez análise exaustiva de dead code em runtime, decodificação de todos os formatos binários, validação de URLs remotas ou testes físicos.

75 testes locais passaram: 37 tools, 37 tools/lab, 1 integração do inventário. Este último detecta duplicação, JSON inválido e link quebrado, verificando ausência de mutações. Oito links corrigidos passaram no teste de regressão Roku. Workflows isolados: `cleanup-audit.yml` (inventário/testes existentes) e `cleanup-links.yml` (links históricos). CI precisa ser confirmado pelas execuções remotas da própria branch, não pelo CI anterior dos builds P0.

## Pendentes — sem exclusão autorizada

A lista completa `noTextualReferenceCandidates` no inventário é triagem, não prova de arquivo morto. No Android C7: `lib/src/ads/ad_campaign.dart` (AdCampaign/AdPlacement) e `lib/src/screens/news_screen.dart` (NewsScreen) não têm callers encontrados; NewsScreen delega a LiveTvScreen. Preservar até decisão sobre funcionalidade futura/consumidores externos. Outras revisões também apresentam ad_metrics_repository e manifests/componentes de plataforma; estes foram preservados por uso implícito ou histórico.

Nenhuma exclusão definitiva será feita sem autorização específica. Antes de propor remoção: confirmar consumidores externos/dinâmicos, plano funcional e rollback por arquivo. Não pedir reaprovação dos catálogos como requisito de limpeza. Nenhum merge, deploy ou publicação realizado.

## Acompanhamento CI

Links Roku aprovados: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/42526074314 (commit 6ccbf96). As primeiras execuções do inventário falharam por NumPy ausente no runner dos testes de preflight; o diagnóstico confirmou ModuleNotFoundError, não defeito de produto. Dependência adicionada ao workflow sem relaxar testes. O scanner e a regressão documental não alteram código Flutter, portanto não se recompilam APKs nem se repetem testes físicos nesta etapa.
