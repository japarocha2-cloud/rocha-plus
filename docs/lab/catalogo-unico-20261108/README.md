# Catálogo oficial único — decisão do proprietário de 08/11/2026

Branch LAB: `lab/catalogo-unico-oficial-20261108`. Base Android: `92451ea`.
Fonte recebida diretamente do proprietário; não houve nova seleção manual, varredura de streams ou homologação. A aprovação histórica de 19 a 21/10, com verificações de áudio/imagem de 180 segundos por canal, permanece reconhecida. Os campos históricos do arquivo são preservados e não representam disponibilidade atual.

## Fonte congelada, hashes e backup

Originais recebidos, preservados byte a byte em `catalog/official/frozen/2026-11-08/`:

| Arquivo | SHA-256 |
| --- | --- |
| ROCHA_CATALOGO_OFICIAL_CONGELADO_2026-11-08.json | `ce8a82a5e5cf637759f75f2dcf063fc6aff67b0832336860b82b6346cd10a2e9` |
| ROCHA_CATALOGO_479_CONGELADO_2026-11-08.csv | `4a5355e5037f9aca1e4e65718acfd5d82e62813849a16f7081c6b63758fefd85` |

Backups integrais em `catalog/official/backups/<sha256>`; índices em `frozen/SHA256SUMS.json`. O hash histórico `sha256_fonte` contido no documento é metadado fornecido, não confundir com o hash do anexo efetivamente recebido. JSON e CSV conferidos campo a campo, incluindo ordem, booleanos e os 71 registros históricos “Revisar PC”. A decisão atual autoriza todos os 479, sem reclassificar seu histórico.

## Contrato compartilhado

`tools/official_catalog/catalog.py` lê os originais fixos, aplica somente `catalog/official/overrides.json` e produz a seleção compartilhada. `--write` regenera os adaptadores; sem argumento, verifica a equivalência exata. Nunca altera fontes, backups ou inventários históricos. Alterações futuras devem ter decisão explícita e uma nova revisão separada; não se edita a base congelada.

A seleção efetiva contém **483 registros: 479 da base + quatro adições declaradas no manifesto**. CazéTV, TV Rá-Tim-Bum HD, Record TV MT e Telecine Action pertencem à camada de adições. Telecine Action existe também na base; ambos os registros são preservados, com IDs distintos. Não houve deduplicação ou remoção por contagem.

Cada registro tem `sourceLayer`, `sourceIndex`, ID estável, nome, categoria, URL preferencial e metadados históricos. `baseCount` e `additionCount` mantêm as contagens separadas. O esquema de seleção C7 existente foi reutilizado, sem reescrever o sistema de catálogo. A seleção foi serializada como JSON ASCII com escapes Unicode para que Android e BrightScript verifiquem exatamente os mesmos bytes SHA-256, sem ambiguidade de codificação.

- Android celular/TV compartilham `C7SelectedCatalog` e o mesmo asset `branding/c7/selection.json`. O pin é gerado em `official_catalog_pin.dart`, aplicado quando C7 está habilitada. O modo não C7 permanece separado; este trabalho não altera versões publicadas.
- Roku LAB reutiliza integralmente a interface de `platforms/roku-lab-visual` do commit `6ccbf96bc301589372ebc82940d05193157c19b1`. O adaptador `OfficialCatalogue.brs` verifica o SHA e lê o mesmo conteúdo em `catalog/official-selection.json`. A chamada de carregamento existente foi ligada ao adaptador, sem fallback para o catálogo antigo. Fonte/artes mantidas em Git, sem modificar a branch Roku anterior.
- Samsung e futuras plataformas podem consumir esse contrato JSON e o hash; ainda não há interface Samsung implementada. Nunca devem importar playlists externas ou editar cópias geradas independentemente.

As duas cópias de empacotamento são geradas da mesma fonte e comparadas byte a byte no CI. Não são listas mantidas manualmente por plataforma. Preferências de interface, autenticação e direitos financeiros não pertencem ao catálogo.

## Correções e preservação

- CazéTV é movida ao primeiro espaço de Esportes. A ordem relativa dos 479 registros da base permanece intacta.
- HISTORY utiliza a URL completa já aprovada no anexo. Globo e Globoplay Novelas mantêm suas correções mais recentes, exatamente como recebidas.
- Rá-Tim-Bum conserva as três URLs documentadas em `docs/lab/CANDIDATA6_LINKS_APROVADOS_20261106.md`, na ordem documentada da camada, com `preferredUrlIndex: 1`. A URL principal é a segunda. Android expõe também `alternateUrls`; Roku recebe a mesma lista. Nenhuma troca automática ou novo caminho foi inventado.
- Record TV MT e TV Universal mantêm as URLs recebidas. TV Universal continua com seu rótulo histórico, sem exclusão por ele.
- Telecine Action, Globo e Globoplay têm endereços-base explicitamente identificados no manifesto. A presença do registro não comprova o caminho HLS nem disponibilidade atual; não se acrescentou extensão, senha ou caminho.
- Decisões antigas de remoção/pendência armazenadas no dispositivo não excluem registros oficiais. Seus dados de evidência permanecem salvos. Busca, categoria e favoritos continuam filtros escolhidos pelo usuário. Não se muda autenticação ou acesso financeiro.
- A ordem atual do proprietário para preservar todos os 479 prevalece sobre tombstones da experiência anterior. Os arquivos antigos e seus testes permanecem como histórico; a nova seleção tem `removals: []`, sem apagar essas evidências.
- As 578 capas Roku e demais arquivos originais são preservados. 423 registros efetivos têm correspondência exata com IDs anteriores do Roku, incluindo identificação por nome e URL quando possível. Nenhum ID foi inferido por semelhança; correspondências ambíguas usam ID determinístico novo. Favoritos antigos continuam armazenados, sem reset.

## Diferenças verificáveis

`differences.json` identifica cada adição, mudanças de URL por hash, correspondências de IDs e registros fora da fonte oficial. Não inclui tokens de URLs nos relatórios.

| Comparação | Lista anterior versionada | Registros antigos fora dos nomes oficiais | Nomes efetivos sem correspondência exata anterior |
| --- | ---: | ---: | ---: |
| Android `branding/lab_candidates.json` | 479 | 0 | 4 |
| Roku `commercial-lab-merged.json` | 608 | 185 | 60 |

Os 185 registros adicionais do inventário Roku continuam integralmente no arquivo histórico, sem promoção automática para a seleção oficial e sem exclusão. O relatório compara os snapshots locais versionados, não uma suposta captura completa dos 882 canais anteriormente observados no aparelho. Não se baixaram playlists para tentar reconstruir essa captura.

## Testes e verificação

Comandos reproduzíveis:

```sh
python3 tools/official_catalog/catalog.py
python3 tools/official_catalog/preservation.py
python3 -m unittest discover -s tools/official_catalog -p 'test_*.py' -v
python3 -m unittest discover -s tools/c7_catalog -p 'test_*.py' -v
npx --yes --package=brighterscript@0.73.8 bsc --project platforms/roku-lab-visual/bsconfig.official.json
flutter pub get
flutter analyze
flutter test
flutter test test/official_catalog_test.dart test/c7_selected_catalog_test.dart test/c7_effective_catalog_test.dart test/c7_category_navigation_test.dart --dart-define=ROCHA_FULL_UI_LAB=true
```

Onze novos testes Python verificam originais, CSV, backups, 71 históricos, correspondência integral dos 479, quatro adições, IDs, URLs, ordem, três alternativas, capas, adulteração e sincronização dos adaptadores. Nove testes anteriores de importação isolada passaram para proteger a continuidade do fluxo antigo; nenhuma homologação física foi repetida. Três testes Flutter novos exercitam o asset real, todos os registros, preferência Rá-Tim-Bum, cache de remoção antigo, atualização sem rede e adulteração. O CI dedicado também executa análise, regressões Flutter e compilação BrightScript/SceneGraph sem pacote.

`preservation.py` verifica 1.133 arquivos originais Roku inalterados (incluindo catálogos e artes); só quatro arquivos antigos de interface/carregamento têm alteração autorizada, além dos novos adaptadores. Inventários Android, autenticação, assinatura e backend são comparados à base Git. O CI desta branch não gera APK/ZIP, não assina, não consulta provedores, não usa secrets e não publica. O job genérico de APK também foi impedido nesta branch. O configurador reconhece esta branch como `.labc7` e recusa certificado temporário se faltar a chave LAB existente. Os hosts de todas as alternativas oficiais entram somente no recurso debug após conferência do SHA; a política main não foi ampliada. As regressões de configuração Android/debug e assinatura dedicada também são executadas.

## Prontidão e limites

A integridade da fonte já permite preparar futuros APK/ZIP LAB a partir desta branch, após CI aprovado. Para Android C7, manter `ROCHA_FULL_UI_LAB=true` e o pin gerado (ou fornecer o mesmo valor via `ROCHA_C7_CATALOG_SHA256`). Antes de empacotar ambas as plataformas, executar a verificação oficial e a preservação; não usar o verificador legado do store C7 para substituir esta fonte congelada. O catálogo antigo permanece somente como inventário histórico.

Nenhum APK ou ZIP foi gerado nesta tarefa. Assinatura, certificado, instalação e reprodução em hardware não foram revalidados e não são declarados homologados. Os endereços-base continuam pendências já documentadas, sem bloquear acesso aos registros. C6, versão oficial, pagamentos, Firebase e secrets não foram alterados. Sem merge, deploy ou publicação.

Workflow: `.github/workflows/official-catalog-lab.yml`. Resultado remoto e commit final devem acompanhar a entrega; não presumir CI aprovado antes da execução.
