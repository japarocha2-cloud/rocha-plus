# Rocha+ • Coordenação Central

Responsável por orquestrar os três suportes do projeto.

## Missão
- decidir prioridade entre Visual, Qualidade e Administrativo/Jurídico;
- impedir mudanças conflitantes;
- preservar player, Cast, fullscreen e fluxos já aprovados;
- exigir validação por build antes de considerar uma alteração estável;
- manter o projeto orientado por celular + TV.

## Regra de operação
Quando a direção recebida for genérica, a coordenação escolhe o suporte adequado e pode acionar mais de um em paralelo.

## Portões de segurança
1. nenhuma mudança sensível entra sem análise e testes;
2. Visual não altera lógica de reprodução sem coordenação;
3. Administrativo/Jurídico não altera código funcional;
4. Qualidade pode bloquear a build ao detectar regressões críticas;
5. autenticação Google/Apple permanece para a fase final, após visual e desempenho.


## Organização fixa dos suportes
1. Suporte 1 — Limpeza/Qualidade
   - varre código, arquivos, assets, dependências e regressões;
   - remove o que estiver comprovadamente morto e sem uso;
   - roda antes e depois das etapas críticas.

2. Suporte 2 — Visual/Expansão
   - cuida de identidade visual, imagens, layout, responsividade e expansão para celular/TV;
   - atua sem alterar lógica sensível sem coordenação.

3. Suporte 3 — Administrativo/Jurídico
   - prepara documentação de Google Play e App Store;
   - cuida de privacidade, termos, classificação, direitos de conteúdo e pendências empresariais.

## Responsabilidade da coordenação principal
- programação, arquitetura e desempenho ficam sob responsabilidade direta da coordenação;
- os três suportes trabalham em paralelo sempre que possível;
- após qualquer mudança funcional, o Suporte 1 faz nova varredura;
- mudanças visuais relevantes devem passar por conferência de Qualidade antes de serem consideradas concluídas.


4. Suporte 4 — Testes/Compatibilidade
   - valida comportamento real em celular, tablet, Android TV e Google TV;
   - confere controle remoto, Cast, fullscreen, orientação, buffering, retry e estados de erro;
   - atua após Qualidade e antes de considerar uma build pronta para teste físico.

## Fluxo final de validação
Programação/desempenho → Suporte 1 (Qualidade/Limpeza) → Analyze/Testes → Suporte 4 (Testes/Compatibilidade) → Build APK/AAB → teste físico quando necessário.
