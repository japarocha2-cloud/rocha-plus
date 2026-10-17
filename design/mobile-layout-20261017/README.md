# Rocha+ — ponto de retomada do layout

Estado deste trabalho: artes e proposta visual salvas; a implementação Flutter deste layout não foi realizada nesta etapa. O titular pediu salvar e continuar depois.

## Escopo autorizado

- Alterar somente a organização visual da Home do celular e as imagens ilustrativas aprovadas.
- Preservar integralmente a paleta e o tema atuais. Não substituir o tema por cores sugeridas pela imagem de conceito.
- Carrossel horizontal próximo de 16:9; quatro categorias em duas colunas, conforme modelo aprovado.
- Preservar login, Firebase, assinaturas, preços, catálogo, favoritos, player e Cast.
- Preservar o link existente do Baú; nunca abrir o site do anunciante no ambiente de desenvolvimento.
- Usar bau_original.png sem redesenhar, cortar ou esticar. SHA-256 original: e18f1a3d5cdefeec1b96fb756dab07cd33974afc875cab2d119ac43f83f20ec1.
- Trabalhar somente na experimental feat/soul-tv-candidates-20261016. Não alterar produção nem APK 4005.

## Artes

As cinco novas ilustrações e a arte original do Baú têm 1672 × 941 pixels (aproximadamente 16:9). O modelo de referência tem 1024 × 1536 pixels e não deve ser inserido como screenshot dentro do aplicativo.

- tv_ao_vivo.png: apresentadora fictícia em estúdio.
- esportes.png: bola em estádio.
- infantil.png: menino e cachorro fictícios.
- noticias.png: jornal e café.
- publicidade_jornal.png: praça de cidade fictícia.
- bau_original.png: arte enviada pelo titular (Aventura Mágica na Ilha do Tesouro(3).png).
- modelo_aprovado.png: referência visual aprovada.

Os arquivos aqui são originais preservados, fora do conjunto de assets empacotados no pubspec. Copiar para os assets de execução somente ao implementar e validar o layout.

## Encaixe e validação pendentes

A resolução permite reduzir as imagens para os cartões sem esticar, mas não comprova o encaixe no aplicativo. Os cartões aprovados são retangulares horizontais, não quadrados. Se a área tiver outra proporção, adaptar a composição/conteiner, mantendo a arte intacta, sem forçar largura e altura independentemente.

A TV tem apresentação própria: não substituir suas artes nem afirmar que o novo visual está homologado em TV sem ajustar e validar. Ao retomar, comparar com o estado atual do repositório e outras alterações aprovadas antes de editar. Não refazer trabalho concluído em outra branch.

Próxima etapa autorizada: aplicar layout no celular, capturar visual Flutter em telas pequenas e grandes, testar navegação e acessibilidade, verificar preservação das funcionalidades e compilar APK experimental assinada com identificador separado. Nenhuma nova APK foi produzida por este checkpoint.
