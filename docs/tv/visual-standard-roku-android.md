# Rocha+ TV — padrão visual canônico (Roku → outras TVs)

Status: **contrato de design**, não comprovação de build ou compatibilidade. Este documento consolida o exemplar de Home já aprovado. A implantação é individual por plataforma.

## Elementos obrigatórios

- Home cósmica: fundo preto e roxo profundo; acentos dourados, prateados e brancos. Não substituir por tema preto/vermelho nem banner gigante.
- Destaques no topo: **três cartas visíveis**, carta central ampliada, cartas laterais parcialmente visíveis; carrossel circular quando suportado.
- Seção **Explore o Rocha+** diretamente abaixo dos destaques, com categorias TV ao Vivo, Esportes, Notícias, Infantil e Favoritos/Minha Lista.
- Menu legível a distância, seleção/foco claramente destacado, navegação por setas, OK e Voltar. Texto e botões não podem ser cortados.
- Evitar conteúdo fictício apresentado como transmissão real. Catálogo de canais somente após aprovação individual da varredura já realizada; indisponíveis ou em quarentena não entram na reprodução.
- Não modificar arte aprovada ou cores sem nova aprovação. Ajustes responsivos devem preservar hierarquia e identidade.

## Adaptadores por ambiente

- **Roku (BrightScript/SceneGraph)**: referência visual e navegação por controle. O player Roku e catálogo aprovado precisam de validação no aparelho.
- **Android TV / Google TV (Flutter)**: usar a mesma composição; suporte a foco e DPAD; considerar overscan, resolução e área segura.
- **Fire TV (Flutter/Android, quando compatível)**: compartilhar componentes da TV Android, testar DPAD/Back/decodificação separadamente.
- **Samsung Tizen / LG webOS (Web)**: replicar o padrão via HTML/CSS/JS e APIs do controle; não assumir compatibilidade binária com o Roku.
- **Android celular**: conservar identidade e componentes, mas adaptar navegação para toque e largura estreita; não forçar 3 cartas inteiras na largura do telefone.


## Padrão funcional compartilhado (validar no Roku primeiro)

A experiência aprovada na Roku será referência de **comportamento**, não só de aparência. Em cada plataforma, reproduzir os mesmos resultados do usuário, com implementação técnica nativa quando necessário:

- Controle remoto: setas movem foco previsivelmente; OK seleciona/reproduz; Voltar sai do player para a lista e da lista para Home; botão Home segue regras do sistema.
- Carrossel: três cartões, destaque central, avanço manual sincronizado com o cartão ativo; avanço automático somente conforme especificação aprovada e sem prejudicar a seleção do controle.
- Catálogo: categorias, ordenação e favoritos coerentes; somente canais aprovados, sem URLs inválidas, duplicatas não desejadas ou canais em quarentena.
- Player: abrir canal selecionado, indicar carregamento, reproduzir imagem e áudio, mostrar erro inteligível, permitir retorno seguro e liberar recursos ao sair.
- Estados: catálogo vazio, falha de conexão, transmissão indisponível e carregamento sempre tratados sem tela travada.
- Navegação e layout: foco visível, contraste legível à distância e sem recortes em telas 16:9.

**Regra de propagação:** funcionalidade só recebe status de **validada no Roku** depois de teste real. A partir daí vira requisito a implementar e validar separadamente em Android TV/Google TV, Fire TV, Samsung Tizen e LG webOS. Reprodução validada no Roku **não prova** funcionamento em outros sistemas, que têm APIs, decodificadores e formatos de instalação distintos. O objetivo é reutilizar especificação, componentes e dados, sem repetir o planejamento nem pular os testes técnicos.

**Registro de status em 11/10/2026:** Roku V0.7 possui fluxo de player no código, mas sem teste físico confirmado; nenhuma compatibilidade de reprodução multiplataforma foi comprovada por esse pacote. Não alterar o último teste congelado.

## Critérios de validação antes do teste

1. Tela 16:9, sem recortes, contraste e foco visíveis a distância.
2. Esquerda/direita mudam o destaque correto. Cima/baixo alcançam menu e categorias. OK abre seleção. Voltar retorna sem encerrar indevidamente.
3. Player abre e retorna à Home; indisponibilidade e catálogo vazio apresentam mensagem, sem canal fictício.
4. Confirmar áudio, vídeo, carregamento e recuperação de erro em **dispositivo real**, por plataforma.

## Política de proteção

Nunca editar a branch `main`, a referência `frozen/build-353-baseline` ou o APK/teste congelado durante essa integração. Trabalhar em branches ou pacotes novos. Este contrato não representa testes físicos concluídos.
