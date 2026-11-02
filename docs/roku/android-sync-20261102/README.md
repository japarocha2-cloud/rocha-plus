# Rocha+ Roku LAB — auditoria Android e capas — 02/11/2026

Estado: pacote experimental 0.6.4 testável no BRS Desktop. A fonte final da Candidata 6 NÃO foi recuperada. Nenhuma homologação, exclusão, categoria, posição, ID ou URL do catálogo foi alterada.

## Entrega e evidências

- 449 pendências auditadas individualmente: 419 capas adicionais recuperadas, 30 pendentes.
- Total: 577 associações válidas para imagens locais (158 anteriores + 419), 533 texturas únicas. Isto não significa 577 canais homologados ou reproduzíveis.
- 393 imagens originais novas arquivadas; a mesma imagem pode servir a variantes com identidade correspondente. Associação exige nome normalizado E stream exato/alternativo declarado. Revisão visual por folhas de contato; conflitos permanecem pendentes.
- 30 pendências: 4 HTTP 403, 4 HTTP 404, 3 falhas TLS/DNS, 3 registros sem logo, 16 sem identidade exata nas fontes verificadas. Detalhes em pending-covers.csv e audit/pending-449-audit.json.
- Catálogo fonte: 607 registros; filtro HLS preexistente exibe 599. Os 8 restantes continuam no arquivo. Ordem e dados preservados byte a byte. PET existe com zero canais no runtime atual.
- APK Candidata 3, versão 0.1.0-candidate.3/código3, contém inventário de479 canais igual ao commit Android2394b12379f84111fcaa9b0944eb31726c3bc45a. Outro APK é TV Test0.1.0/código1. Nenhum é C6.
- 422 dos607 registros coincidem por identidade+stream com inventárioC3;185 não. Fontes de playlists dinâmicas usadas pelo Android permitiram recuperar outras imagens, sem transferir aprovação.
- Galáxia, logomarca e artes originais preservadas. Categorias em cartas horizontais, lista vertical7 linhas, prévia à direita, Assistir/tela cheia, favoritos3x2 de cartões grandes. O simulador tinha zero favoritos; grade populada verificada no harness.
- 30 testes BrightScript de comportamento +10 de identidade/integridade aprovados. Cinco scripts sem erro de sintaxe;56IDs XML únicos. CI desta etapa não executada; não equivale a teste físico.
- Observação nativa BRS Desktop2.6.2/engine2.6.1: Home, categorias, capas infantis, prévia Gospel Cartoon e tela cheia com imagem. Capturas em screenshots/. Áudio, FPS real, memória real, estabilidade longa e Roku físico não medidos.

## Desempenho

ZIP anterior7.325.578bytes → final4.521.472bytes (−38,28%). SHA256 final6725384fb64b5af4e8058d068c7e094560c3cd81fc1bb30cb4358a811a72f848.569arquivos,14JSON,577mapeamentos sem arquivo ausente;CRC validado.
533PNGs192x108 com transparência e proporção preservada;cache total2.181.118bytes. Carregamento somente da janela visível. Pool7linhas/42nós;6categorias/24nós;6favoritos/30nós. Harness: baseline4000nós/100renderizações;versão nova0novos nós/1000renderizações. Não é medição deFPS ou RAM.580.608bytes RGBA teóricos para sete texturas, sem vídeo/cache do renderer.
Prévia aguarda350ms e para o canal anterior; único Video reutilizado em tela cheia;timeout25s.420cartões antigos gerados com texto excluídos do ZIP, mantidos nas fontes históricas;não contados como capas oficiais.

## Reproduzir

1. Leia docs/plantao/PLANTAO-MESTRE-ROCHA-ROKU.md e AGENTS.md. Use apenas a branch lab/roku-visual-covers-performance-20261102.
2. Abra BRS Desktop2.6.2 e carregue artifacts/roku-lab/20261102/RochaPlus-Roku-LAB-ANDROID-CAPAS-CATALOGO-20261102-v2.zip. Limite do simulador7MiB;ZIP abaixo do limite.
3. Aguarde Home inicializar. Selecione Categorias: confira seis cartas horizontais, role atéPET e demais. Abra Infantil: confira BabyFirst, BabyFirst Brazil, Box Kids, Cartoon Network e Disney. Mude de canal e aguarde debounce; a prévia anterior deve parar. Selecione Assistir/OK e use Voltar para lista, categorias e Home.
4. Favoritos: sem dados exportados não importar/inventar favoritos. No aparelho do testador, favoritar pelo menu*, abrir grade, navegar3colunas e usar Voltar. Verificar áudio, reprodução contínua, falha/rede lenta, memória eFPS no Roku físico.
5. Node.js instalado: execute node tests/roku-visual/verify.mjs "CAMINHO_DO_BRS/resources/app.asar". Runner usa apenas módulos nativos e engine instalado; executa40cenários e verificaCRC/catálogo.
6. Recriar ZIP: importe build de tools/roku_visual_lab.mjs e execute build("platforms/roku-lab-visual","destino.zip",{excludeProvisionalCovers:true,onlyMappedLogoFiles:true}). Não use defaults para esta versão.
7. tests/roku-visual/simulator-api.mjs fornece upload/captura/ECP locais. Captura aguarda escrita assíncrona antes de buscarPNG; não interpretar frame anterior como falha de navegação.

## Continuidade

catalog-comparison.json e categories-and-channel-order.json documentam diferenças/ordem completa. audit/ inclui proveniência, APKs,449linhas e fontes consultadas. cache-optimization.json preserva hashes origem/derivada. Originais novos e ZIPs anteriores em artifacts/roku-lab/20261102/references/. Fotografias e arte aprovadas não foram substituídas por IA.
Buscar fonte C6 final, exportação de remoções01/11 e favoritos antes de qualquer sincronização de catálogo. Não assumir430/372 históricos como catálogo. Nenhum merge, publicação, Android, pagamento ou versão oficial alterado.
