# C7 — catálogo local fechado — 08/11/2026

Branch: lab/candidata7-catalogo-fechado-20261108, base 1cd674e. Sem APK, merge, deploy ou publicação. Sem alterações de Firebase, secrets, pagamentos, C6 ou versão oficial. A homologação física C6 (19–21/10/2026, áudio/imagem por 180s por canal) continua válida; não se pede nova aprovação.

## Causa e correção

ChannelRepository._loadDirectory combinava br.m3u e sports.m3u. A fonte esportiva recebia group=Esportes em todos os itens. A entrada FULL_UI_LAB usava ChannelRepository por padrão. O resultado não era o catálogo congelado da C6 e variava conforme fontes externas. 882/502 são o resultado físico informado, não limites usados para apagar itens.

Quando ROCHA_FULL_UI_LAB=true, loadBrazilPublicDirectory agora retorna exclusivamente C7SelectedCatalog, ANTES de qualquer cache remoto, _lastKnownGoodCache ou importação. forceRefresh não acessa a rede nem amplia a seleção. Também não há fallback para lab_candidates, lab_approved ou catálogo validado antigo. Os caminhos alternativos loadLabCatalog e ValidatedLabRepository respeitam a mesma restrição na C7. Foi retirada a injeção automática de CazéTV no caminho remoto; a seleção precisa conter sua entrada autorizada.

O comportamento dos modos não C7 permanece separado e coberto pelos testes anteriores. A versão oficial e as referências congeladas não foram alteradas. Logos/streams dos canais selecionados ainda podem ser remotos; o que foi eliminado é a admissão de novos canais por playlists externas.

## Fonte C6 — estado real

[source-provenance.json](source-provenance.json) registra SHAs/commits dos arquivos efetivamente inspecionados. C7 tem 479 candidatos pending e lab_approved vazio. As branches históricas candidate6-link-recovery e candidate6-approved-link-patch também têm lab_approved vazio; a documentação de recuperação registra ausência do snapshot final. O catálogo Roku de 190 entradas e o universo Roku de 607 não representam a seleção C6 de aproximadamente 430. A investigação anterior já identificara que o artefato histórico 12691257099 era de candidatos, NÃO C6; não foi promovido nem novamente tratado como fonte aprovada.

**O manifesto exato dos ~430 não foi recuperado nesta tarefa.** Não se pode afirmar que ele foi migrado integralmente. Não há seleção de produção inventada nem lista vazia apresentada como aprovada. O aplicativo informa seleção ausente e nunca busca candidatos para substituí-la. Isso é uma barreira de preparação: nenhum APK desta branch deve ser gerado/entregue antes de instalar e validar a fonte correta.

É necessário receber o arquivo/backup original da seleção já aprovada ou a última exportação manual do proprietário, com origem identificada. Não é pedido de nova varredura ou aprovação física. A ausência desse arquivo é bloqueio de migração, não reprovação de canais.

## Normalização, removidos e inventário

A ferramenta converte categorias para português, p.ex. Sports/Sport/Esporte -> Esportes, News -> Notícias, Kids -> Infantil. Categorias desconhecidas ficam em Outros, com originalCategory preservada; não se apaga o canal. A UI C7 usa TV ao Vivo de ponta a ponta, sem duplicação TV aberta/TV ao Vivo. CazéTV ocupa o primeiro slot de Esportes e os demais mantêm sua ordem relativa; nenhum URL ou capa é mudado automaticamente. Depois da seleção validada, a UI não reaplica o filtro Record por nome nem a ordenação editorial antiga: os tombstones e a seleção explícita determinam a admissão.

[authorized-removals.json](authorized-removals.json) mantém as oito exclusões Record da ordem física anterior, com identidade/URL e ID derivado. A fonte de 11 registros continua intacta na evidência anterior; as três variantes aprovadas não são bloqueadas por substring. Novas remoções da seleção manual viram tombstones persistentes. ID e identidade+URL impedem replays; se não restou variante da mesma identidade, a identidade também bloqueia reaparecimento com nova URL/ID. Alternativas explicitamente retidas não são apagadas. Não é possível remover CazéTV já presente por simples omissão numa atualização desta ordem.

O inventário não testado continua byte a byte em branding/lab_candidates.json, sem entrar no catálogo ativo. catalog/c7/pending-inventory-reference.json guarda SHA bruto e semântico, contagem e approvalTransferred=false. O importador recusa esse inventário inteiro mesmo se apenas reformatado. A evidência de aprovação vem da origem da seleção manual/C6 identificada, nunca de uma quantidade, benchmark ou marca pending.

## Uso offline: importar, conferir diff, exportar e verificar

Formato de entrada: JSON com lista de canais ou objeto channels. Campos mínimos name/url; id estável preferido. group ou category, logo, genres e preferredEngine são preservados quando presentes, salvo normalização explícita da categoria. IDs ausentes são derivados de SHA256(name+NUL+url), recuperando ID anterior quando há correspondência exata. Não se adota M3U remoto automaticamente. Exportações M3U/CSV devem ser convertidas para esse formato preservando campos e origem antes de importar; não inventar a seleção a partir do nome de uma playlist.

Calcule o hash do arquivo recebido e execute o dry run (expected-head=none somente na primeira importação):

```sh
sha256sum /caminho/ultima-selecao.json
python3 tools/c7_catalog/selection.py import --source /caminho/ultima-selecao.json --expected-source-sha256 HASH_RECEBIDO --expected-head none --provenance owner-selection --reference REFERENCIA_DA_EXPORTACAO
```

Para um backup original C6 identificado, use provenance c6-original. Não rotular um arquivo de candidatos como C6. Depois de conferir o diff, repetir o comando com --apply. Se o original C6 contiver entradas excluídas pela ordem C7 anterior, --apply-authorized-removals filtra SOMENTE os tombstones, arquiva o original integral e relata authorizedExclusions; não remove da C6 nem reativa entradas.

```sh
python3 tools/c7_catalog/selection.py export --output branding/c7/selection.json
python3 tools/c7_catalog/selection.py verify
```

O store padrão catalog/c7/store possui sources/ (bytes originais por SHA), selections/ (revisões imutáveis), diffs/ e HEAD.json atualizado por rename atômico. Importação usa lock exclusivo; interrupção pode exigir revisão de um lock residual. Não se sobrescrevem backups. Para atualizar, use expected-head igual ao SHA atual; export sobre arquivo existente exige --expected-output-sha256 com o hash anterior e backup imutável correspondente. Assim não se sobrescreve um arquivo arbitrário. Fontes originais nunca são escritas pelo importador.

verify confere a seleção exportada, cadeia de revisões, fontes brutas, categorias/IDs/URLs canônicos e preservação dos tombstones. Exige CazéTV presente antes de qualquer build; não a insere de outra lista. Se a fonte C6 antiga não a contiver, manter essa fonte arquivada e incorporar a inclusão já autorizada em uma revisão manual identificada, sem importar playlists.

O retorno de export fornece ROCHA_C7_CATALOG_SHA256. Um futuro build C7 deve fixar esse hash com --dart-define e usar somente branding/c7/selection.json. O loader valida bytes UTF-8 por SHA-256, proveniência, IDs únicos, categorias canônicas e remoções antes de exibir canais. Sem arquivo/pin, hash incorreto ou reinclusão, rejeita sem fallback. SHA protege integridade; não autentica sozinho a autoridade do proprietário. O diff e a origem precisam ser conferidos, sem nova homologação física de todos os canais.

## Testes e limites da entrega

Nove testes Python de importação/exportação, hash, backup, revisão obsoleta, tombstones, variantes retidas, IDs duplicados, source inválida e bloqueio de pré-build passaram localmente. As suites Python existentes continuam passando. Fixtures são sintéticas e ficam somente em test/fixtures; não entram no asset bundle nem são catálogo aprovado. O CI c7-closed-catalog.yml roda análise e suites Flutter padrão e com FULL_UI_LAB=true, incluindo zero requisições às playlists no carregamento, cache, refresh, restauração, falta de fonte e corrupção. Testa também categorias e navegação TV ao Vivo. Não há etapa de build, assinatura, secrets ou deployment. O job Android do workflow legado Build Rocha+ fica explicitamente desativado para esta branch fechada, tanto em PR quanto em disparo manual: ele não pode gerar inadvertidamente uma variante sem o seletor/pin. Um futuro workflow de build C7 precisa verificar a seleção e fixar seu SHA antes da compilação.

Confirmação de escopo: código C7 não amplia a seleção automaticamente. A recuperação/preenchimento da seleção aprovada permanece pendente do arquivo correto; nenhum número foi usado para completar ou cortar canais. Relatório de CI deve ser lido na execução remota desta branch antes de considerar regressões aprovadas.
