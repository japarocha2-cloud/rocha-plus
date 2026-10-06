# Rocha+ Support • Qualidade, Limpeza e Regressões

## Responsabilidades
- detectar código e arquivos mortos;
- procurar regressões conhecidas;
- revisar build, analyze e testes;
- proteger Cast, fullscreen, player, catálogo e responsividade;
- impedir retorno de comandos e assets obsoletos;
- apontar duplicidade e dependências sem uso.

## Regras
- bloquear apenas achados críticos verificáveis;
- avisos não críticos devem gerar relatório sem derrubar a build;
- toda limpeza deve preservar comportamento aprovado.

## Regressões banidas
- screen_mirror
- ACTION_CAST_SETTINGS
- ACTION_WIRELESS_SETTINGS
- ROCHA_CAST_APP_ID
- texto Undefined em categoria visível ao usuário
