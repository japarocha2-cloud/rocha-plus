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

## Critérios de validação antes do teste

1. Tela 16:9, sem recortes, contraste e foco visíveis a distância.
2. Esquerda/direita mudam o destaque correto. Cima/baixo alcançam menu e categorias. OK abre seleção. Voltar retorna sem encerrar indevidamente.
3. Player abre e retorna à Home; indisponibilidade e catálogo vazio apresentam mensagem, sem canal fictício.
4. Confirmar áudio, vídeo, carregamento e recuperação de erro em **dispositivo real**, por plataforma.

## Política de proteção

Nunca editar a branch `main`, a referência `frozen/build-353-baseline` ou o APK/teste congelado durante essa integração. Trabalhar em branches ou pacotes novos. Este contrato não representa testes físicos concluídos.
