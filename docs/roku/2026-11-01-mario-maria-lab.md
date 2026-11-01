# Roku LAB — Mário e Maria — 2026-11-01

## Escopo aprovado
- Aplicativo familiar exclusivo para os avós, isolado do Rocha+ oficial.
- Preservar identidade cósmica, cores, navegação e menu lateral existentes.
- Substituir somente o falso carrossel da Home por **um banner fixo horizontal** cobrindo a largura da área principal (sem cartões laterais).
- Arte aprovada: Super Vô e Super Vó em cartoon 3D, Fusca azul-bebê, placa **Mario e Maria**, traje da Super Vó vermelho/azul/dourado.
- Abaixo do banner, mostrar **Canais ao Vivo** com cartões individuais que abrem canais do catálogo real; nunca inventar canais.
- Reaproveitar categorias do catálogo consolidado; respeitar a lista de 372 remoções e preservar os itens já aprovados. A origem e o cruzamento com a lista de remoções precisam ser verificados antes de empacotar.
- Teste físico: navegação por controle remoto, foco, áudio/vídeo, retorno, favoritos, canais que falham. Remoção de canal somente com evidência do teste.
- Não publicar, fazer merge, cobrar ou alterar versão oficial.

## Diagnóstico do código antes da implementação
- Base: lab/roku-catalog-diagnostics-20261031
- Home: platforms/roku/components/HomeScene.xml; atualmente usa Poster banner-demo.jpg e texto estático.
- Lógica: platforms/roku/components/HomeScene.brs; catálogo LAB de benchmark-test.json e amostra isolada opcional.
- O catálogo LAB **não é prova de homologação física Roku**; não apresentar os candidatos como reproduções verificadas.
- Arte binária aprovada precisa ser incorporada ao pacote em platforms/roku/images antes de trocar o URI do banner.

## Estado
Preparação de branch isolada e especificação registradas. Ainda não há ZIP instalado, compilação ou teste físico concluído.
## Implementação parcial — 01/11/2026
- `6c82229`: HomeScene.xml reserva banner horizontal 1540x475 e faixa Canais ao Vivo, mantendo a identidade cósmica.
- `8a5eaff`: HomeScene.brs renderiza até quatro cartões com nomes do catálogo LAB e navegação por controle remoto.
- **Pendente:** substituir `banner-demo.jpg` pela arte aprovada, auditar 372 remoções, validar autenticação, compilar com bsc, criar ZIP e testar em Roku físico.
- **Atenção:** os cartões refletem os primeiros candidatos carregados, não um catálogo final homologado; não instalar como presente definitivo.

## Revisão adicional
- `fc42115`: cartões da Home selecionam o primeiro canal disponível de TV aberta, Notícias, Esportes e Infantil, sem inventar títulos.
- O catálogo `benchmark-test.json` informa `approved:false`, `roku_playback_verified:false` e `distribution_authorization:unverified` para candidatos examinados. A integração não equivale a autorização de distribuição.
- Não foi encontrada nesta revisão uma lista consolidada verificável das 372 remoções dentro de `docs/catalog`, `docs/auditoria` ou `docs/roku` nesta branch. Não afirmar que as exclusões já foram aplicadas.
- `config/auth.json` ainda tem endpoint e billingEndpoint vazios; isso impede validar o fluxo completo de login.
- O banner aprovado não está incorporado: o arquivo referenciado ainda é `banner-demo.jpg`.
- Nenhum teste de compilação ou Roku físico foi executado nesta etapa.
