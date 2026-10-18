# Amambai Notícias no primeiro bloco — 18/10/2026

## Escopo

Nova branch `feat/amambai-news-carousel-20261018`, derivada do checkpoint aprovado 6001. O checkpoint `checkpoint/rl-login6001-approved-20261018` permanece em `e9ae497ab6e5d5375448dcc6846f7ee7e59c8936`. O APK 4005 e seu checkpoint anterior também permanecem preservados.

A ativação usa `ROCHA_NEWS_CAROUSEL=true` somente na nova compilação de testes. A versão sem essa definição mantém a sequência e o visual anteriores. Não há alteração de autenticação, cobrança, permissões comerciais, favoritos, catálogo ou Firebase.

## Comportamento

- No celular, primeiro bloco e primeira posição ao abrir: uma notícia do Amambai Notícias; segundo: Baú; terceiro: espaço comercial existente. As artes e destinos do Baú são preservados.
- O site tem chamadas comerciais antigas fixadas no topo. O seletor usa os previews editoriais com título, trecho e data, escolhendo o mais recente já publicado. Não trata as chamadas comerciais fixas como notícia atual.
- Foto externa da matéria, título, chamada curta, nome do jornal e data. Máximo de 25 palavras provenientes do título/trecho por notícia. Não carrega nem republica o corpo integral da reportagem.
- Clique intencional abre a URL limpa da matéria no navegador externo. Nunca redireciona automaticamente.
- Consulta ao abrir e a cada 15 minutos enquanto o aplicativo está ativo; retorno do segundo plano consulta respeitando esse intervalo. Requisições simultâneas são compartilhadas.
- Falhas de rede/layout mantêm a última notícia válida por até 7 dias, sempre com a data de publicação. Sem notícia válida, o mesmo bloco oferece acesso ao portal, com identificação genérica em vez de inventar uma manchete. Falha da imagem mostra alternativa local sem quebrar o card.
- A atualização nunca bloqueia a Home. Rede tem timeout e limite de tamanho; não segue redirecionamentos do HTML. Links de notícia/imagem só são aceitos por HTTPS nos domínios exatos do jornal, em caminhos de notícia/uploads esperados. Texto HTML é convertido em texto; scripts não são executados.
- A sequência da TV permanece como aprovada, pois o pedido usa o carrossel comercial do celular.

## Origem e limites

Origem pública: https://www.amambainoticias.com.br/ . O endpoint WordPress REST respondeu HTTP 401 no ambiente, por isso o aplicativo usa a página pública, sem autenticação, contorno de bloqueio ou acesso administrativo. A seleção não depende da API restrita.

A identificação “Amambai Notícias” credita a origem do preview; não representa parceria nem prova de licença das fotos. O site declara direitos reservados. A autorização de uso comercial de imagens/conteúdo não foi demonstrada nesta tarefa; esta entrega permanece experimental, sem publicação comercial.

## Validação

Commit em validação: `a62f73ef107f4967126145d3afebb09ec147e73b`.
Execução: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39140542799

- `flutter analyze`: sem problemas.
- `flutter test`: 171 passaram; 10 casos exclusivos de flags/origem ignorados corretamente.
- Sessão autenticada no laboratório: 3 passaram.
- Notícias/primeiro bloco: 8 passaram.
- Renderização/catálogo/player de laboratório: 8 passaram.
- A prova de acesso vivo à origem não passou: HTTP 403 externo, registrado no artefato próprio; depende de rede permitida no aparelho.
- Verificações locais auxiliares: 21 testes Python, 2 testes Node, sintaxe Python e YAML.

Execução final concluída com os três jobs aprovados. A aprovação abrange estabilidade, interface, sessão e resposta de reserva; **não é prova de notícia viva carregada**, pois o acesso à origem foi recusado.

- APK release assinado 6002: `RochaPlus-AMAMBAI-LOGIN-TESTE`, artefato `12141965453`; nome no aparelho **Rocha+ Jornal TESTE**. Pacote de testes `com.rochaplus.soultvtest`, distinto do oficial 4005.
- SHA-256 APK: `238da5abd78277f52deec7518c0d01ee654341fe22a372cb720246cd439038db`.
- Android debug: Home/Infantil (21 canais)/retorno/rotação e quatro inicializações sem erros Flutter. Artefato `12142090038`.
- Nesse Android, os próprios logs registraram `[RochaNews] http=403`. `news-verification.json` registra `live_fetch_verified:false`, `fallback_verified:true`, `physical_network_test_required:true`.
- A captura da Home mostra a reserva Amambai Notícias no primeiro bloco; a captura subsequente mostra Baú no bloco seguinte após o avanço automático. Não há foto de reportagem real nessas capturas.
- Android com APK release real: login obrigatório, Google habilitado, retrato/paisagem/reabertura sem exceções. Artefato `12141756646`. Não foi selecionada uma conta Google no emulador.
- Resposta HTTP 403 da origem no runner preservada no artefato `12141362884`.
- Assinatura e pacote de testes verificados; autenticação, billing, favoritos, branding, catálogo aprovado/quarentena e backend passaram na comparação protegida. Nenhuma publicação comercial foi realizada.

Cobertura adicionada: extração de uma notícia atual; exclusão de chamadas fixas; entidades HTML; limpeza de rastreadores; rejeição de URL externa/insegura; cache, coalescência e expiração; dimensões e texto ampliado; clique da matéria; falha de abertura; primeira posição e manutenção do Baú em seguida. Android real emulado verifica também um preview vivo do site, além das regressões Home/Infantil/rotação e login assinado.

A primeira execução identificou delimitadores vazios `?#` na limpeza de URL; corrigidos construindo a URI somente com esquema, host e caminho. Os testes de geometria foram ajustados para resolver explicitamente a fixture HTTP antes de medir o card: ausência de frames não significa conclusão de streams assíncronos.

Teste físico pendente: instalar a nova versão, autenticar, ver foto/título/data no primeiro bloco, tocar e conferir a matéria no navegador, retornar ao app e verificar notícia/Baú e reprodução dos canais.

## Restrição confirmada da origem

A execução 39124609735 recebeu HTTP 403 ao consultar o site público a partir do runner GitHub. Isso confirma uma recusa de acesso nesse ambiente; não confirma que a rede do celular receberá a mesma resposta. A execução Android anterior exibiu a reserva e manteve Home/Infantil/rotação sem erros Flutter. Não se apresentou esse resultado como prova de notícia viva carregada.

A CI agora registra explicitamente a resposta da origem e, no Android, só classifica a reserva como comportamento esperado quando os próprios logs do aplicativo confirmam HTTP 403. Outros casos de preview ausente continuam falhando. O resultado de notícia viva versus reserva fica em `news-verification.json`, separado da aprovação dos testes de navegação. Nenhum proxy, credencial, alteração de User-Agent ou contorno de bloqueio foi implementado.

A obtenção automática de manchete/foto reais no aparelho continua pendente de teste físico em rede com acesso permitido ao jornal.

Uma atualização intermediária da branch experimental (b5137ff3) perdeu a referência da árvore base e continha apenas dois arquivos. A falha foi identificada no CI pela ausência de pubspec/test e corrigida em a62f73ef, usando explicitamente a árvore completa verificada de 56a34c76. A comparação de árvores confirmou apenas as duas alterações de teste esperadas sobre essa base. Os checkpoints e APKs congelados não foram alterados.
