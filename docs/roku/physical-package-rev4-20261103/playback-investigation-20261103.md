# Diagnóstico de reprodução do catálogo Roku LAB 0.6.10 REV4

Data: 03/11/2026 (BRT)  
Branch: `lab/roku-0.6.10-google-activation-admin-20261103`  
Ponto de código empacotado: [ee6158270219bcd752ed1a9a2dd17d735cb8f200](https://github.com/japarocha2-cloud/rocha-plus/commit/ee6158270219bcd752ed1a9a2dd17d735cb8f200)  
CI: [run 41749761631 — success](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41749761631). A execução concluiu fixtures e validações de pacote, não reprodução real.

## Conclusão executiva

- **Canais com permissão verificável para playback no Roku LAB: 0 de 607.**
- **Bloqueados por falta de evidência de autorização física/Roku: 607 de 607.** A allowlist `approvedForPhysicalTest` está vazia e `readyForEnabledZip` é `false`.
- **Canais com falha real de reprodução Roku comprovada nesta revisão: 0.** REV4 não foi executada em Roku física para playback. Bloqueio por autorização não é falha de stream.
- **Candidatos técnicos, sem validação de Roku atual:** 599 registros têm indicação textual de URL HLS (.m3u8); isso não prova que o endpoint ainda responda, seja compatível com Roku/codec/rede, nem autoriza uso. Os 8 restantes não têm extensão HLS reconhecida e estão como formato não-HLS/sem extensão; protocolo e compatibilidade precisam ser apurados.
- O gate no pacote é intencional. Nenhum canal deve ser tentado para contornar o bloqueio.

## Origem e qualidade das evidências dos 607 registros

Fonte de inventário: [commercial-lab-merged.json](../../../platforms/roku-lab-visual/catalog/commercial-lab-merged.json). O arquivo contém 607 IDs únicos e nomes.

| Origem/classificação encontrada no registro mesclado | Qtde | O que comprova | O que não comprova |
|---|---:|---|---|
| `benchmark_av_detected`, originado de `Benchmark_RochaPlus_Catalogo.csv` | 395 | O benchmark anterior marcou vídeo e áudio em uma checagem curta. 204 registros apontam para a playlist histórica `catalogo_rocha_br.m3u`, e 191 para `catalogo_rocha_sports.m3u`. | Não prova disponibilidade atual, reprodução em Roku, estabilidade, direito de distribuição ou autorização para teste físico. O próprio registro tem `roku_playback_verified:false`, `approved:false` e `distribution_authorization:unverified`. |
| `special_lab_tested`, sem objeto de evidência ou fonte primária anexada no registro mesclado | 212 | Somente a etiqueta histórica existente. | Não prova qual execução, aparelho, data, URL de origem ou resultado foi usado; não prova autorização nem compatibilidade atual. |
| Aprovação técnica em `catalog/approved.json` | 190 linhas nessa fonte; 169 IDs também aparecem no catálogo mesclado | O arquivo separado registra teste técnico reportado em `channel_stability_20261012.csv`, com duração decodificada de ~30 s e codecs H.264/AAC. | O status técnico não é licença. 21 IDs dessa lista não aparecem na versão mesclada; nenhum dos 190 tem, nesse objeto, evidência de permissão Roku/teste físico. |

As 607 entradas permanecem disponíveis para interface e avaliação. Categorias no CSV: Esportes 201; Geral 122; TV aberta 76; TV ao Vivo 54; Outros 49; Infantil 18; Notícias 17; Música 17; Religiosos 14; Entretenimento 13; Filmes 10; Educação 7; Séries 4; Documentários 2; Futebol 2; Cultura 1. Nenhum registro foi modificado nesta investigação.

A [matriz de reprodução bloqueada](blocked-playback-channels.csv) lista os 607 IDs e nomes, grupo, indicação de formato e evidência faltante. Não contém cópias de URLs de mídia.

## Classificação dos impedimentos

1. **Autorização ausente (607/607):** não há documentação verificável por canal com origem/licenciante, referência de permissão, plataforma Roku/teste físico, validade e responsável/revisor. A configuração LAB exige esses campos e mantém lista vazia.
2. **Formato/compatibilidade não confirmados (607/607):** a extensão HLS em 599 é apenas um indício; os 8 sem HLS identificado não têm protocolo afirmado. Não foi feito teste de decoder Roku nesta etapa.
3. **Falha real de playback (0 confirmadas; 607 não testadas fisicamente nesta REV4):** logs de benchmark antigos, respostas HTTP históricas ou uma entrada aparecer como bloqueada não equivalem a uma execução Roku que falhou. Portanto, não rotulamos as 607 como falhas técnicas.
4. **Runtime LAB de acesso também não está habilitado:** origem HTTPS, projeto/database LAB e autorização de sessão não foram configurados; Auth/central/comercial permanecem desligados. Mesmo uma futura prova de autorização de canal não habilita automaticamente o app: o acesso isolado deve ser estabelecido e validado em separado.

Os 8 registros com indicação não-HLS/sem extensão são: UniTV Porto Alegre; AXN White (United States) Portugal; AXN (Portugal); Telecine Action; MCM Pop; GloboNews; TLC Latin America Brazil; RecordTV Interior SP. A classificação não determina que esses sinais sejam incompatíveis; indica que protocolo/URL não foi confirmado.

## Pesquisa de players oficiais públicos

Foi feita uma pesquisa pública pontual, não uma verificação exaustiva dos 607 titulares: foram localizados players oficiais ao vivo/páginas de acesso de [SBT](https://sbt.com.br/ao-vivo), [RedeTV!](https://www.redetv.uol.com.br/aovivo) e [TV Brasil/EBC](https://tvbrasil.ebc.com.br/comosintonizar). Isso comprova oferta de visualização nos canais digitais oficiais. Não fornece permissão para extrair/incorporar os endpoints diretos no Rocha+ Roku nem cobre teste físico de um app de terceiros. Os [termos digitais do SBT](https://sbt.com.br/termos-de-uso) descrevem o uso das próprias plataformas; a existência de um player oficial não concede automaticamente autorização para retransmissão ou integração independente.

Nenhum URL direto, query string ou possível token do catálogo é reproduzido neste relatório. A fonte de catálogo inclui endereços de mídia; trate-os como dados de acesso potencialmente sensíveis e não os copie para logs, tickets ou relatórios públicos. A auditoria não consultou nem testou esses endpoints.

## Gate e arquivos examinados

- [Configuração de requisitos da allowlist](../../../experiments/roku-readiness/physical-channel-lab.example.json): `enabled:false`; host não configurado; `approvedForPhysicalTest: []`; playback comercial desligado.
- [Matriz de canais bloqueados](blocked-playback-channels.csv): 607/607 e campos de evidência faltantes.
- [Código do catálogo e avaliação](../../../platforms/roku-lab-visual/components/HomeScene.brs) e [navegador de canais](../../../platforms/roku-lab-visual/components/ChannelBrowser.brs): REV4 permite navegação/avaliação; os controles de imagem, áudio e travamentos permanecem bloqueados sem playback permitido.
- [Manifesto de benchmark](../../../platforms/roku-lab-visual/catalog/benchmark-manifest.json): 788 linhas-fonte no arquivo original, com deteções históricas; declara explicitamente `roku_playback_verified:false` e `public_release_approved:false`.
- [Build e validação REV4](README.md): 607 navegáveis, 578 associações de capa, CI/fixtures, hash e ZIP. CI não é teste de reprodução.

## O que falta para desbloquear algum canal com segurança

Para cada ID pretendido, anexar evidência verificável contendo: emissora/titular/originador; URL ou serviço oficial identificado sem segredo; documento/termo/licença que cubra uso em app Roku e teste físico (ou autorização escrita do titular); canais/território/plataforma/uso cobertos; período de validade; responsável pela revisão. Se for um conjunto, a evidência deve enumerar os IDs/nome(s) cobertos e comprovar que cada um está incluído. “É público”, “abre no navegador”, “é canal aberto”, “o benchmark tocou” e “tem aprovação técnica” não bastam isoladamente.

Depois da verificação: preparar allowlist exclusivamente com IDs aprovados e referência persistente; implementar/enforçar a política server-side isolada por ID; configurar host HTTPS e identidade/projeto de homologação; executar testes de contrato e allowlist. Só então gerar um ZIP novo, com consentimento para playback dos IDs registrados. O atual REV4 permanece sem playback. Nenhuma alteração foi feita em catálogo, aplicativo oficial, Android, pagamentos, assinaturas, Firebase comercial ou produção; nenhum ZIP novo foi gerado.

## Resultado desta etapa

Diagnóstico documental e leitura das fontes do branch concluídos. Sem consultas aos URLs de stream, sem gravações, sem teste físico de imagem/áudio e sem build. Próxima ação concreta: o titular/responsável de conteúdo fornecer a documentação de autorização descrita acima, começando por qualquer subset cujo uso Roku seja permitido; revisar os IDs e o escopo antes de qualquer alteração na allowlist.
