# Rocha+ Roku LAB — continuidade técnica — 02/11/2026

Entrega experimental parcial: lista vertical e lógica de prévia implementadas; 158 canais com imagens existentes recuperadas e empacotadas. Permanecem 449 capas pendentes. Não há aprovação de reprodução, áudio ou FPS, nem confirmação do catálogo final da Candidata 6.

## Pacote e isolamento

- ZIP: `RochaPlus-Roku-LAB-VISUAL-CAPAS-DESEMPENHO-20261102.zip`.
- Tamanho: 7.325.578 bytes; abaixo do limite de 7.340.032 bytes do BRS Desktop 2.6.2. O ZIP é maior que o de referência porque inclui imagens antes remotas.
- SHA-256: `88b48ff003423c35f3f991ded03704a5ceb75febe3e1a2285c21af7872072d63`.
- Branch: `lab/roku-visual-covers-performance-20261102`, baseada em `ebf6514d5b70c82c702cd57798d4ce07ee58e34c` de `lab/roku-mario-maria-20261101`.
- Código: `repository/platforms/roku-lab-visual`. A pasta original `platforms/roku` e o Android não foram alterados.
- Commit local da importação fiel do ZIP: `86796a8b50b9c2ef865f6acfb9a96daf90a4b50d`.
- Commit local das correções: `db3fd257b1cbef7b1f96cd725b2621d1dd0defb1`.
- Este documento registra a etapa local original. O envio posterior para o GitHub e o estado mais recente estão no [relatório mestre](../../plantao/PLANTAO-MESTRE-ROCHA-ROKU.md). Não houve PR, merge, deploy, publicação de aplicativo ou alteração comercial.

O ZIP HOME-VISUAL-EXPERIMENTAL foi escolhido como baseline por ser a variante visual mais recente disponibilizada. O ZIP REVISAO-CAPAS-NAVEGACAO também foi inspecionado e teve seu CRC validado. Nenhum dos dois coincide exatamente com o HomeScene da branch remota: a importação foi registrada separadamente, sem presumir uma origem versionada inexistente. Os hashes de ambos estão em `reference-packages.json`.

## Capas

| Medida sobre 607 registros do catálogo integrado | Quantidade |
| --- | ---: |
| Capas recuperadas e válidas para exibição local | 158 |
| Associações configuradas para o cache local | 158 |
| Arte oficial utilizável ainda ausente/pendente | 449 |
| URLs de logo originalmente declaradas | 166 |
| Referências coverLocal originalmente declaradas | 212 |
| Caminhos coverLocal inexistentes no ZIP | 0 |

Foram recuperados 142 arquivos de logo distintos de URLs que já estavam associadas ao catálogo; 158 canais compartilham esses recursos. O mapa separado `config/cover-map.json` preserva os registros originais. As miniaturas mantêm a proporção e transparência; os downloads originais estão em `references/logo-originals` no workspace, com hashes registrados na auditoria.

As 420 imagens PNG de capas presentes no ZIP eram cartões provisórios de 240 × 135, com o mesmo padrão azul e texto. Continuam preservadas como arquivos históricos, mas não são apresentadas como logotipos. Canais sem imagem recuperada mostram “Capa pendente”, sem arte inventada. Permanecem pendentes BabyFirst, BabyFirst Brazil, Box Kids TV, Cartoon Network e as variantes Disney citadas: não havia logo oficial associado a esses registros nas referências verificadas.

Dos oito canais restantes que declaravam logo remoto, houve respostas 403, falha de conexão, páginas HTML retornadas com HTTP 200 e formatos SVG/AVIF sem conversão validada nesta etapa. URLs, respostas e hashes estão em `logo-network-audit.json`. A cobertura por canal e os 449 pendentes estão em `cover-coverage.json` e `pending-covers.csv`.

## Comportamento implementado

Sete linhas reutilizáveis à esquerda, nome e capa quando disponível, seleção por ↑/↓, foco no botão Assistir por → e OK para tela cheia. A seleção interrompe a transmissão anterior e aguarda 350 ms antes de iniciar a prévia à direita. O mesmo Video é redimensionado entre prévia e tela cheia. Voltar sai da tela cheia mantendo a prévia; outro Voltar encerra a prévia e abre categorias; o próximo retorna à Home.

Carregamento, falha e timeout de 25 s permanecem na lista, com tentativa explícita por OK. Troca de foco não cria um ciclo automático de novas tentativas. Expiração do acesso também interrompe prévias. Favoritos e registros de check-up foram preservados.

A Home mantém a galáxia, o banner original com suas cartas laterais, menu e cores. A logomarca original foi recuperada de `branding/rocha-wordmark-antennas.webp` e convertida para PNG de exibição; o original não foi alterado. Relógio/data aparecem apenas na Home. PET e espaço do Baú estão presentes. Temporizadores da Home param fora dela. O banner tem um único slide aprovado configurado; não foram inventadas campanhas ou novas artes.

## Desempenho e validação

| Verificação | Resultado |
| --- | --- |
| Alocação no render antigo: 100 atualizações com oito itens | 4.000 nós criados |
| Alocação no render novo: 1.000 atualizações | Zero novos nós após montar o pool de 35 nós |
| Arquivos recuperados, antes de dimensionar para exibição | 7.502.762 bytes |
| Cópias de exibição empacotadas | 2.420.376 bytes — redução de 67,74% |
| Pixels agregados das imagens recuperadas | 24.189.588 → 3.166.754 — redução de 86,91% |
| Testes comportamentais BrightScript | 21 aprovados |
| Análise sintática | Quatro arquivos BRS sem erros |
| XML | 52 IDs únicos; referências findNode verificadas |
| ZIP | CRC e round-trip dos 593 arquivos aprovados; 14 JSON válidos |
| Preservação | 435 arquivos originais de imagens/catálogos comparados byte a byte |

As alocações foram contadas executando o código BrightScript antigo e novo com nós SceneGraph simulados, usando a engine distribuída no BRS Desktop 2.6.2. O harness cobre troca rápida, debounce, prévia/tela cheia, Voltar, erro, timeout, categoria vazia, acesso negado, capa ausente e relógio com métodos reais de roDateTime. Isso não mede GPU, memória real ou decoder. A redução de pixels é uma estimativa de necessidade de textura, não uma leitura de consumo do processo.

No BRS Desktop instalado, o pacote foi recebido e aberto. Foram observados Home, lista de sete itens com logos locais, área de prévia, carregamento/indisponibilidade e retorno às categorias. As capturas estão em `screenshots/`. A consulta do player retornou `state=close`; não houve evidência suficiente de vídeo/áudio funcionando. Uma incompatibilidade de relógio encontrada no primeiro ensaio foi corrigida e ganhou teste de regressão. O endpoint de FPS do simulador retorna um zero fixo no código da ferramenta e não foi usado como medida. Os 15 FPS/2–3 FPS continuam sendo observações informadas pelo usuário, sem nova comparação controlada.

A técnica de limitar dimensões de carga dos Posters segue a [documentação de Poster da Roku](https://developer.roku.com/dev/docs/poster); a relação entre pixels e memória de textura está descrita em [Memory management](https://developer.roku.com/dev/docs/memory-management).

## Catálogo e homologação

Todos os arquivos de catálogo foram preservados byte a byte, inclusive ordem, flags e exclusões empacotadas. O catálogo integrado contém 607 registros; o filtro HLS preexistente exibe 599, deixando oito URLs sem “.m3u8” de fora. Esses oito não foram apagados. O arquivo chamado approved.json contém 190 registros; seu nome não comprova aprovação da Candidata 6.

Foram consultados os históricos Roku, benchmark de 788 linhas e auditorias de candidata/plantão na branch `work/candidate-build-guard-20261031`, head `2394b12379f84111fcaa9b0944eb31726c3bc45a`. Fontes relevantes:

- [Continuidade de TV em 30/10](https://github.com/japarocha2-cloud/rocha-plus/blob/2394b12379f84111fcaa9b0944eb31726c3bc45a/docs/tv/continuity-20261030.md): distingue candidatos de homologação física.
- [Portões da candidata em 31/10](https://github.com/japarocha2-cloud/rocha-plus/blob/2394b12379f84111fcaa9b0944eb31726c3bc45a/docs/auditoria/2026-10-31-portoes-homologacao-candidata.md): preserva teste físico nº 6; não fornece a lista final de canais.
- [Inventário histórico issue34](https://github.com/japarocha2-cloud/rocha-plus/blob/2394b12379f84111fcaa9b0944eb31726c3bc45a/docs/lab/issue34-inventory-summary.json): 479 elegíveis, zero aprovados nesse inventário; não representa o catálogo final.

Não foi recuperada a lista exata dos aproximadamente 430 canais nem a exportação de remoções de 01/11. As 372 remoções são referência histórica informada pelo usuário, não uma lista reconstruída. A presença de 607 registros no ZIP não foi convertida em aprovação nem reconciliada por suposição. Não houve restauração ou exclusão de canais. Consulte `catalog-provenance.json` e `catalog-runtime-differences.json`.

## Continuidade necessária

1. Recuperar a exportação final da Candidata 6 e de suas remoções; comparar IDs/URLs, categorias, ordem e exclusões antes de qualquer alteração de catálogo.
2. Fornecer ou localizar artes oficiais dos 449 pendentes, principalmente os canais infantis citados. Conferir também formatos SVG/AVIF e URLs que falharam.
3. Em Roku física: comprovar imagem/áudio contínuos, primeiro quadro, buffering, timeout/retry e troca rápida sem dois streams ativos.
4. Testar controle remoto, prévia → tela cheia → lista → categorias, favoritos, reinício e perda/retorno da rede. Não reabrir testes congelados sem regressão relacionada.
5. Comparar ZIP anterior e novo na mesma Roku e no mesmo BRS, com resolução e limite de FPS idênticos; registrar FPS, memória, texturas e uso de CPU durante sessão prolongada.

Não aprovado para publicação. Nenhuma mudança em Oficial, Android, LAB 714, Candidata 6, pagamentos ou assinaturas de produção.
