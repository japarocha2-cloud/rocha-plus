# PLANTÃO MESTRE — ROCHA+ ROKU LAB

Atualização: 02/11/2026. Responsável técnico: Codex. Destinatários: Rupi e futuras sessões.
Entrega atual preparada: LAB 0.6.6 para homologação por conta, DESATIVADO até confirmar/configurar a identidade. O LAB 0.6.5 e os resultados anteriores permanecem históricos. **A paridade de catálogo com a Candidata 6 não está comprovada.** Não tratar o pacote experimental como nova homologação.

## Recuperar o trabalho sem depender deste chat

Repositório: [japarocha2-cloud/rocha-plus](https://github.com/japarocha2-cloud/rocha-plus). Branch exclusiva: `lab/roku-visual-covers-performance-20261102`.

1. Leia este relatório e [AGENTS.md](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/AGENTS.md).
2. Faça checkout dessa branch; não trabalhe em main, Oficial, Android, LAB 714 ou Candidata 6.
3. Use o [código Roku isolado](https://github.com/japarocha2-cloud/rocha-plus/tree/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual), os [relatórios da etapa atual](https://github.com/japarocha2-cloud/rocha-plus/tree/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102) e o ZIP abaixo. Não reconstruir o catálogo com base em contagens.
4. Preserve os resultados aprovados. Ao concluir cada etapa técnica, atualize este arquivo, faça commit/push apenas na branch LAB e confira links/SHAs remotos.
5. Próxima prioridade: localizar catálogo final e exportação de remoções da C6; em paralelo, testar este ZIP em Roku física.



## Etapa de acesso LAB — 0.6.6 preparado, não ativado

[Relatório e fluxo completo](../roku/lab-access-20261102/README.md),[situação da conta](../roku/lab-access-20261102/account-verification.json),[versão observada](../roku/lab-access-20261102/version-diagnosis.json),[testes de servidor](../roku/lab-access-20261102/server-tests.json),[cliente](../roku/lab-access-20261102/client-lease-tests.json),[comportamento](../roku/lab-access-20261102/behavior-tests.json),[pacote](../roku/lab-access-20261102/package-tests.json).

- Causa: firstStart+7200s no registro local de physical_test_2h; essa rotina retorna antes da consulta comercial. Endpoints comerciais vazios. Bloqueio não prova falta de pagamento. BRS local confirmado em0.6.4;0.6.5também mantém o limite antigo.
- Conta fornecida pelo proprietário:cadastro, pagamento e direito pago NÃO VERIFICADOS por fonte autenticada. Zero cobranças, concessões pagas ou escritas em produção. E-mail/proposta privados fora do GitHub. Consulta pela interface interrompida porque URL não pôde ser confirmada; sem credencial administrativa disponível.
- Preparado0.6.6:modo account_homologation, código8 caracteres/10min, conta existente e verificada, proposta absoluta de24h, leases60s. Um celular, duasTVs, duasreproduções no serviçoLAB; troca móvel preservaTVs. Não implantado nem homologado em produção.
- ZIP seguro por padrão:enabled=false, endpoint vazio. Não libera testes reais até concluir configuração/identidade. Nunca substituir isso por paid ou rearmar o relógio de2h.
-71 verificações locais aprovadas(33 comportamento+20 servidor+14 cliente+4 pacote), zero falhas finais. Testes reais de conta, pagamento, vinculação e hardware não executados.578capas/29 pendências e catálogo607/599 preservados.
- ZIP preparado em artifacts/roku-lab/20261102/access/RochaPlus-Roku-LAB-0.6.6-ACESSO-HOMOLOGACAO-PREPARADO-20261102.zip,4.536.431 bytes, SHA256 a8d7ba17fc1dd703d5cf81bea012ffc8942268ed68dc60765c9ef42b25212dd4.
- Próximo passo:informar projeto correto/consulta administrativa autorizada, verificar conta e vínculo financeiro somente por leitura; integrarHTTPS e aprovação móvel noLAB e só então habilitar a autorização temporária. Sem merge, publicação ou produção.

## Entrega anterior — LAB 0.6.5

[Baixar ZIP 0.6.5](https://raw.githubusercontent.com/japarocha2-cloud/rocha-plus/fcfc414db96dd59ade0480439daa0adf82b3247c/artifacts/roku-lab/20261102/followup/RochaPlus-Roku-LAB-0.6.5-CAPA-HABER-20261102.zip) · [Commit de código e artefatos](https://github.com/japarocha2-cloud/rocha-plus/commit/fcfc414db96dd59ade0480439daa0adf82b3247c) · [Resultados dos 13 testes](https://github.com/japarocha2-cloud/rocha-plus/blob/fcfc414db96dd59ade0480439daa0adf82b3247c/docs/roku/technical-followup-20261102/related-tests.json) · [Roteiro físico de 21 casos](https://github.com/japarocha2-cloud/rocha-plus/blob/fcfc414db96dd59ade0480439daa0adf82b3247c/docs/roku/technical-followup-20261102/ROTEIRO-TESTE-FISICO.md)

Download remoto confirmado HTTP200 e SHA256 integral conferido. [Verificação remota](../roku/technical-followup-20261102/remote-verification.json). Branch confirmada neste commit; zero check-runs e zero Actions, sem PR/merge/publicação. O commit deste relatório final é posterior ao código e está no histórico do arquivo.

[Relatório completo](../roku/technical-followup-20261102/README.md),[auditoria das30 pendências](../roku/technical-followup-20261102/pending-30-audit.json),[29ainda pendentes](../roku/technical-followup-20261102/pending-covers.csv),[revisão de desempenho](../roku/technical-followup-20261102/performance-review.md),[roteiro físico](../roku/technical-followup-20261102/ROTEIRO-TESTE-FISICO.md),[resultados físicos NÃO EXECUTADOS](../roku/technical-followup-20261102/physical-results.csv).

- Checkpoint de pesquisa persistido:79df0398de07968058e585a967587fa183ee0f90. Todos os1.442 artefatos listados inventariados; apenas o conteúdo do catálogo histórico selecionado foi inspecionado, não todos os1.442. FonteC6/remoções01/11 continuam não encontradas.
- Recuperada uma capa original adicional:beIN Sports Haber. Total578 associações/534 texturas;577 anteriores preservadas. Restam29 pendências(10HTTP403,4HTTP404,3 TLS/DNS,5sem logo,7sem identidade exata).
- Novo ZIP artifacts/roku-lab/20261102/followup/RochaPlus-Roku-LAB-0.6.5-CAPA-HABER-20261102.zip:4.533.575 bytes, SHA256 3e9f11df58b01374b09eafe786a47888466906e06f9c8e42693560cdd14089a9. OriginalJPEG eSHA256SUMS no mesmo diretório.
- Só capa, mapa e versão mudaram no pacote. Catálogos607/599, ordem, exclusões, BRS/XML, Android eRokuoficial preservados byte a byte. Nenhuma homologação alterada.
- 13 testes de dados/preservação relacionados aprovados; zero falhas.30 cenários de comportamento verdes anteriores preservados sem repetição. CI nova não executada. Nenhuma aprovação física;21 casos preparados e não executados.0.6.5também não foi executado no BRS nativo.
- Revisão não demonstrou defeito que justificasse refatoração de desempenho. FPS/RAM, texturas/decoders reais e reprodução contínua continuam dependentes do roteiro físico.
- Continuidade:use esta seção atual; contagens577/30 e ZIP0.6.4 abaixo são históricos. Não reconstruir catálogo e não reutilizar aprovações de triagemCI.

## Estado confirmado e commits

- Base remota preservada: [ebf6514d5b70c82c702cd57798d4ce07ee58e34c](https://github.com/japarocha2-cloud/rocha-plus/commit/ebf6514d5b70c82c702cd57798d4ce07ee58e34c).
- Primeira etapa persistida: [85bec547c1a39ecbccd0de914993638fb73fad97](https://github.com/japarocha2-cloud/rocha-plus/commit/85bec547c1a39ecbccd0de914993638fb73fad97) — importação dos ZIPs de referência, interface/lista/prévia, 158 capas, 21 testes iniciais e auditoria.
- Código e entrega da etapa 0.6.4: [f5cce4b70d40edcb6a342312215a1b2314b79589](https://github.com/japarocha2-cloud/rocha-plus/commit/f5cce4b70d40edcb6a342312215a1b2314b79589) — 419 capas adicionais, categorias horizontais, favoritos grandes, cache otimizado, 40 verificações e ZIP 0.6.4.
- O commit que contém este relatório é posterior ao commit de código acima. Consulte o histórico deste arquivo para obter seu SHA; os links de artefatos apontam ao commit imutável de código.
- Nenhum PR desta branch encontrado; nenhum merge ou publicação realizado.
- CI do commit atual: zero check-runs e zero execuções de Actions, verificados via API. Commits de persistência usam [skip ci]. **40 testes locais aprovados não são CI.** [Download remoto e hashes conferidos](../roku/android-sync-20261102/remote-verification.json). Veja [estado GitHub](../roku/android-sync-20261102/github-status.json) e [Actions do repositório](https://github.com/japarocha2-cloud/rocha-plus/actions).
- O histórico local anterior (86796a8, db3fd25, d13ea8d) pertence ao trabalho preparatório; os SHAs canônicos para continuidade são os links remotos acima.

## ZIP anterior — LAB 0.6.4 (histórico)

[Baixar Roku LAB 0.6.4 — Android, capas e catálogo](https://raw.githubusercontent.com/japarocha2-cloud/rocha-plus/f5cce4b70d40edcb6a342312215a1b2314b79589/artifacts/roku-lab/20261102/RochaPlus-Roku-LAB-ANDROID-CAPAS-CATALOGO-20261102-v2.zip)

- Caminho persistente: `artifacts/roku-lab/20261102/RochaPlus-Roku-LAB-ANDROID-CAPAS-CATALOGO-20261102-v2.zip`.
- 4.521.472 bytes, 569 arquivos; dentro do limite de 7 MiB do BRS Desktop.
- SHA256: `6725384fb64b5af4e8058d068c7e094560c3cd81fc1bb30cb4358a811a72f848`.
- Download remoto HTTP 200 e SHA256 conferidos integralmente após o push.
- [Manifesto 0.6.4](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/manifest), [validação do pacote](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/package-checks.json), [somas de todos os ZIPs](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/artifacts/roku-lab/20261102/SHA256SUMS).

## Correções e localização do código

- [HomeScene.brs](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/components/HomeScene.brs) e [HomeScene.xml](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/components/HomeScene.xml): navegação, áreas de categorias/favoritos, IDs e integração.
- [ChannelBrowser.brs](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/components/ChannelBrowser.brs): sete linhas reutilizadas, capas e nomes legíveis; prévia à direita com debounce de 350 ms; encerra o canal anterior e reutiliza um único Video na prévia/tela cheia; estado de carregamento/erro, timeout de 25 s e retorno coerente. Sem criar centenas de Posters nem decodificadores.
- [GalleryBrowser.brs](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/components/GalleryBrowser.brs): seis cartas horizontais de categorias e favoritos em grade 3x2 de cartões grandes, carregados por janela; pools reaproveitados.
- Account.brs: interrompe a prévia quando o acesso LAB expira. Regras de autenticação/assinaturas/pagamentos não alteradas.
- Corrigido erro de relógio que usava asTimeString, substituído por getters suportados; regressão coberta.
- [cover-map.json](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/config/cover-map.json): somente associações verificadas; [cache final](https://github.com/japarocha2-cloud/rocha-plus/tree/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/images/cache) com 533 PNGs, dimensões 192x108 e letterbox transparente, sem esticar/recolorir os logos.
- Ferramentas: [build/CRC](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/tools/roku_visual_lab.mjs), [associação Android](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/tools/roku_android_artwork_audit.mjs), [cache](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/tools/roku_image_cache.mjs), [folhas de contato](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/tools/roku_artwork_contact_sheets.mjs).

## Catálogo, homologação e diferenças com Android

**Nenhum canal foi criado, removido, restaurado, reordenado ou homologado nesta etapa.** Arquivos originais de catálogo permanecem byte a byte. O LAB herdado contém registros com approved=false/status de benchmark; presença em ZIP, imagem recuperada e sucesso de teste não significam aprovação.

- Fonte Roku: [commercial-lab-merged.json](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/catalog/commercial-lab-merged.json) — 607 registros. O filtro .m3u8 preexistente exibe 599; 8 não HLS continuam no arquivo e estão detalhados na auditoria anterior.
- [approved.json](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/catalog/approved.json) tem 190 registros históricos; [quarantine.json](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/catalog/quarantine.json) tem 159; benchmark histórico tem 788. Não fundir essas listas para criar uma aprovação atual.
- [Benchmark_RochaPlus_Catalogo.csv](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/catalog/Benchmark_RochaPlus_Catalogo.csv) é histórico, não a lista final C6.
- Candidata 6 v0.1.0 congelada em 31/10: fonte final exata NÃO localizada. Aproximadamente 430 restantes e 372 remoções são referências fornecidas pelo usuário, sem lista final verificável. Exportação de remoções de 01/11 e favoritos exportáveis não encontrados.
- APK inspecionado: Candidata 3 (0.1.0-candidate.3, versionCode3, com.rochaplus.app.candidate). Inventário de 479 registros idêntico a [branding/lab_candidates.json no commit Android2394b1](https://github.com/japarocha2-cloud/rocha-plus/blob/2394b12379f84111fcaa9b0944eb31726c3bc45a/branding/lab_candidates.json). lab_approved.json é vazio nesse snapshot. Outro APK é TV Test0.1.0/código1; nenhum é C6.
- Dos 607 registros Roku, 422 coincidem por nome normalizado e URL exata com o inventário C3; 185 não. Essa comparação documenta proveniência, sem aprovação.
- Android usa playlists dinâmicas iptv-org de Brasil/esportes. Elas ajudaram a localizar logos, mas seu conteúdo atual não representa o catálogo congelado C6.
- Fontes históricas lidas: [auditoria 28/10](https://github.com/japarocha2-cloud/rocha-plus/blob/2394b12379f84111fcaa9b0944eb31726c3bc45a/docs/auditoria/2026-10-28-candidata-tecnica.md), [portões 31/10](https://github.com/japarocha2-cloud/rocha-plus/blob/2394b12379f84111fcaa9b0944eb31726c3bc45a/docs/auditoria/2026-10-31-portoes-homologacao-candidata.md), [inventário issue34](https://github.com/japarocha2-cloud/rocha-plus/blob/2394b12379f84111fcaa9b0944eb31726c3bc45a/docs/lab/issue34-inventory-summary.json), [continuidade TV](https://github.com/japarocha2-cloud/rocha-plus/blob/2394b12379f84111fcaa9b0944eb31726c3bc45a/docs/tv/continuity-20261030.md). Busca também em histórico/artefatos; inventário de Actions consultou os 100 mais recentes de 1.442, não todos.
- Evidências: [comparação](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/catalog-comparison.json), [APKs e hashes](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/audit/apk-inventory.json), [proveniência histórica](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/visual-20261102/catalog-provenance.json), [diferenças runtime](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/visual-20261102/catalog-runtime-differences.json).

### Categorias e ordem preservadas

[Lista completa de categorias, IDs, nomes e ordem dos 599 canais](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/categories-and-channel-order.json).

| Ordem | Categoria | Canais no runtime |
|---|---|---:|
|1|Geral|122|
|2|TV ao Vivo|129|
|3|Esportes|201|
|4|Notícias|16|
|5|Infantil|18|
|6|Filmes|8|
|7|Séries|4|
|8|Documentários|2|
|9|Educação|6|
|10|Cultura|1|
|11|Comédia|0|
|12|Culinária|0|
|13|Entretenimento|12|
|14|Música|16|
|15|Religiosos|14|
|16|Estilo de Vida|0|
|17|Vida ao Ar Livre|0|
|18|Viagens|0|
|19|PET|0|
|20|Futebol|2|
|21|Outros|48|

PET foi mantida; não preencher ou mover canais sem fonte homologada. Favoritos dependem dos dados locais do usuário; não foram inventados/importados. O simulador estava sem favoritos; o harness valida a grade populada.

## Capas: resultado completo

- Etapa anterior: 158 canais / 142 imagens únicas. Pendentes:449.
- Auditoria atual:449/449 examinados;419 recuperados,30 pendentes. Total final:577 canais com associação local;533 texturas únicas, algumas compartilhadas entre variantes da mesma identidade.
- 339 pendentes coincidiram com o inventário C3;336 tinham logo. Outras94 associações vieram das fontes de playlists usadas pelo Android. Das430 associações com URL de logo,419 tiveram download/imagem validada. Estes430 não são o catálogo final430 citado historicamente.
- 404 URLs distintas verificadas;393 arquivos originais válidos recuperados. Formatos originais preservados no arquivo ZIP; derivados PNG otimizados no runtime.
- Correspondência exige stream exato (ou alternativa declarada) E identidade normalizada. Só nome semelhante não basta; conflitos não são aceitos. Resolução/acentos/anotações são normalizados apenas para comparar; nomes/IDs armazenados não mudam. Nenhum status de aprovação transferido.
- Revisão visual das393 imagens em nove folhas; BabyFirst (duas variantes), Box Kids TV, Cartoon Network Latin America Brazil, Disney Portugal, Disney Latin America, Disney Mexico e Disney Panregional HD conferidos. Parte dessas prioridades também foi vista no BRS.
- [449 linhas com origem, IDs e decisão](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/audit/pending-449-audit.json), [cobertura final](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/cover-coverage.json), [downloads/hashes](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/audit/image-downloads.json), [folhas de contato](https://github.com/japarocha2-cloud/rocha-plus/tree/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/contact-sheets).
- [30 pendências, canal e motivo exato](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/pending-covers.csv):4 HTTP403,4 HTTP404,3 falhas de rede/TLS (CRTV Chile: cadeia de certificado; Golf Channel:DH fraco; Laboral TV:DNS),3 registros Android sem logo,16 sem identidade exata nas fontes verificadas. TLS não foi desabilitado.
- 420 PNGs antigos eram cartas geradas com nome, não logos oficiais. Mantidos nas fontes/ZIPs históricos e excluídos do pacote novo. Não contados como recuperação. Pendentes mostram o estado previsto pela interface, sem criar arte genérica.

## Visual e decisões congeladas

Galáxia original, logomarca, banners/splash e artes oficiais preservados. Derivados mantêm imagem/proporção; fundo neutro das capas melhora leitura de logos claros/escuros. Categorias horizontais, canais em lista vertical, prévia automática à direita, único stream, Assistir para tela cheia e favoritos grandes. Não retornar à grade antiga de oito canais.
[Artes Roku](https://github.com/japarocha2-cloud/rocha-plus/tree/f5cce4b70d40edcb6a342312215a1b2314b79589/platforms/roku-lab-visual/images), [artes de categoria originais](https://github.com/japarocha2-cloud/rocha-plus/tree/ebf6514d5b70c82c702cd57798d4ce07ee58e34c/branding/categories/mobile), [proveniência das derivações](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/audit/category-art-provenance.json).
Não houve substituição de arte oficial por imagem de IA.

## Desempenho e testes

| Medida | Antes | Atual |
|---|---:|---:|
| ZIP |7.325.578 bytes|4.521.472 bytes (−38,28%)|
| Canais com capa |158|577|
| Pendências |449|30|
| Alocações no harness |4.000 nós/100 renders|0 novos nós/1.000 renders|
| Pool de canais |recriado a cada render|7 linhas /42 nós|
| Texturas finais |dimensões variáveis|533 PNGs192x108;2.181.118 bytes|

Pools lazy:6 categorias/24 nós e6 favoritos/30 nós. Sete texturas representam580.608 bytes RGBA teóricos, excluindo vídeo, fundos, renderer e cache do simulador. **Não é medida de RAM do processo.** Queixa anterior de15FPS vazio/2–3FPS com app é relato do usuário; não foi medida independentemente. Endpoint ECP deFPS retorna0 fixo nessa versão e não serve de evidência. FPS real e memória real não medidos.

Aprovados:30 cenários BrightScript com SceneGraph simulado +10 testes de identidade/pacote; zero falhas. Cinco scripts com sintaxe aceita pelo engine instalado;56IDs XML únicos e referências conferidas. CRC e14 JSON válidos,577 mapeamentos sem imagem ausente; catálogo e artes preservadas por hash.
[Resultados de comportamento](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/automated-tests.json), [identidade](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/artwork-identity-tests.json), [métricas](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/performance.json), [cache](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/cache-optimization.json).

BRS Desktop2.6.2 (engine2.6.1) instalado: observados Home, categorias, capas infantis, prévia e tela cheia de Gospel Cartoon com imagem, Voltar e favoritos vazios. [Capturas nativas](https://github.com/japarocha2-cloud/rocha-plus/tree/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/android-sync-20261102/screenshots).
Não executados/comprovados:áudio, reprodução contínua de todos os canais, Roku físico, RAM/FPS reais, sessão longa, condições reais de rede, paridade C6 e favoritos Android. Nenhuma nova homologação de canal. O harness não tem decoder/rede reais.

## Reproduzir sem repetir trabalho já aprovado

1. Baixe o ZIP atual e confira SHA256. Abra no BRS Desktop2.6.2; aguarde inicialização. Use a branch experimental, não a versão oficial.
2. Categorias → Infantil: confira capas/nomes; troque rapidamente e aguarde350ms; somente uma prévia deve permanecer. Assistir/OK abre tela cheia; Voltar retorna à lista, depois categorias, depois Home.
3. Percorra categorias até PET e confira ordem; sem fonte C6, não reorganizar. Favoritos:use dados de teste do próprio testador e opções*, verifique grade3x2, retorno e persistência. Não alterar favoritos reais sem exportação.
4. Em Roku física, registre primeiro quadro, áudio, buffering, timeout25s, trocas rápidas, rede indisponível/retorno, uso de RAM, FPS e CPU na mesma configuração antes/depois. Registre aparelho/firmware/rede.
5. Testes locais com Node.js:
```powershell
node tests/roku-visual/verify.mjs "C:\CAMINHO\BrightScript Simulator\resources\app.asar"
```
[Runner](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/tests/roku-visual/verify.mjs) usa módulos nativos e engine instalado. [Harness](https://github.com/japarocha2-cloud/rocha-plus/tree/f5cce4b70d40edcb6a342312215a1b2314b79589/tests/roku-visual). Não requer acessar streams.
6. Build reproduzível:importe build de tools/roku_visual_lab.mjs e passe `{excludeProvisionalCovers:true, onlyMappedLogoFiles:true}`; fonte platforms/roku-lab-visual. Defaults são históricos e não representam o ZIP v2.
7. [API local do simulador](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/tests/roku-visual/simulator-api.mjs) permite upload/ECP/captura. A captura aguarda a escrita assíncrona do PNG; evite interpretar frame anterior como falha de navegação.
8. Não repetir suítes verdes sem mudança relacionada; novos testes físicos e obtenção de fonteC6 permanecem necessários.

## Materiais persistentes e histórico dos ZIPs

[Diretório completo de artefatos](https://github.com/japarocha2-cloud/rocha-plus/tree/f5cce4b70d40edcb6a342312215a1b2314b79589/artifacts/roku-lab/20261102) e [SHA256SUMS](https://github.com/japarocha2-cloud/rocha-plus/blob/f5cce4b70d40edcb6a342312215a1b2314b79589/artifacts/roku-lab/20261102/SHA256SUMS).

| Arquivo | Situação | SHA256 |
|---|---|---|
|references/RochaPlus-Roku-LAB-HOME-VISUAL-EXPERIMENTAL-20261102.zip|entrada,4.847.890 bytes|3dce918642e43a07ab31a83f725dd02fd952242578b6bf541e4ad38ada21849a|
|references/RochaPlus-Roku-LAB-REVISAO-CAPAS-NAVEGACAO-20261102.zip|entrada,4.823.625 bytes|602477cd52c0df1d47f56d5fde4b34c0372d841156a171901784a5c446aa3211|
|RochaPlus-Roku-LAB-VISUAL-CAPAS-DESEMPENHO-20261102.zip|etapa1,7.325.578 bytes|88b48ff003423c35f3f991ded03704a5ceb75febe3e1a2285c21af7872072d63|
|RochaPlus-Roku-LAB-ANDROID-CAPAS-CATALOGO-20261102-v2.zip|histórico 0.6.4,4.521.472 bytes|6725384fb64b5af4e8058d068c7e094560c3cd81fc1bb30cb4358a811a72f848|
|references/LOGOS-ORIGINAIS-RECUPERADOS-20261102.zip|142 originais da etapa1|0bda12f1a65e63ad7170af2398d1677c2dad83015369cb96d6ddb6883548c6b6|
|references/LOGOS-ORIGINAIS-ANDROID-RECUPERADOS-20261102.zip|393 novos originais,24.203.804 bytes|d70c12b10c31613b4cd8d0c5600f5706623165769e20f9aa75a17358fdfb3ba9|

[Baixar originais Android recuperados](https://raw.githubusercontent.com/japarocha2-cloud/rocha-plus/f5cce4b70d40edcb6a342312215a1b2314b79589/artifacts/roku-lab/20261102/references/LOGOS-ORIGINAIS-ANDROID-RECUPERADOS-20261102.zip).
[Auditoria anterior preservada](https://github.com/japarocha2-cloud/rocha-plus/tree/f5cce4b70d40edcb6a342312215a1b2314b79589/docs/roku/visual-20261102); seus449pendentes e21 testes descrevem a etapa1, superada pelos resultados atuais, sem apagar o histórico.
Os APKs inspecionados permanecem apenas nos caminhos persistentes do computador, sem upload do Android: `C:/Users/Administrador/Downloads/rocha-plus-candidate-0.1.0-candidate.3-3.apk` e `C:/Users/Administrador/Desktop/Rocha+/app-release.apk`. Hashes/manifestos em apk-inventory.json; inventário fonte equivalente já está no GitHub. O trabalho Roku não depende de recuperar esses APKs.
Cópia local do repositório: `C:/Users/Administrador/Documents/ChatGPT/Rocha +/repository`; ZIP também em `C:/Users/Administrador/Documents/ChatGPT/Rocha +/deliverables`. Downloads intermediários/inspeções em references/ e inspection/ do workspace são auxiliares; materiais necessários à continuidade estão nos commits/arquivos persistidos acima.

## Pendências e próximos passos

1. Recuperar exportação final C6 congelada31/10, lista de removidos01/11, categorias/ordem e favoritos exportáveis. Comparar IDs/URLs e exclusões com evidência antes de qualquer alteração. Nunca restaurar removidos.
2. Resolver as30capas conforme CSV, com imagem original e associação verificável; não usar imagens inventadas, nem desabilitar TLS para contornar falhas.
3. Testar Roku físico e medir desempenho; validar áudio/stream único/rede/favoritos, sem reabrir homologação Android.
4. Atualizar este relatório e anexar evidências por etapa; commit/push apenas no LAB. Sem merge, publicação, alteração de assinaturas/pagamentos ou identidade visual.

Nenhuma senha, token, chave privada ou credencial foi incluída neste relatório.

## Etapa técnica seguinte — investigação histórica (02/11/2026)

Continuidade da base07a3f2f. [Relatório de investigação](../roku/technical-followup-20261102/README.md). Inventário ampliado de100para todos os1.442 artefatos listados;77 branches, sem tags/releases. Artefato histórico12691257099 inspecionado:11.333 URLs/479 elegíveis/zeroaprovados; fonte finalC6 e remoções01/11 ainda não encontradas. Catálogos preservados. Imagem original beIN Sports Haber recuperada e conferida; incorporação ao pacote pendente neste checkpoint. As577 associações e os40 testes verdes anteriores permanecem preservados. Código/ZIP0.6.4 ainda não alterados.
