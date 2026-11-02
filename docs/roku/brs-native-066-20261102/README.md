# Execução real no BRS Desktop — LAB 0.6.6

Em 02/11/2026, o pacote dev foi atualizado de 0.6.4 para **0.6.6**, no BRS Desktop 2.6.2 / engine 2.6.1 / SceneGraph 0.6.1 do Windows. É execução nativa com captura do framebuffer, não harness automatizado.

## Instalação e preservação

Download direto do commit b47ccf380152acf3d2ee996fbea1d01c6d5a099d: HTTP 200, 4.536.431 bytes, 572 arquivos, SHA-256 a8d7ba17fc1dd703d5cf81bea012ffc8942268ed68dc60765c9ef42b25212dd4. Instalador local respondeu Install Success. A instalação é assíncrona: uma consulta imediata ainda mostrou 0.6.4; consultas posteriores confirmaram dev 0.6.6 instalado e ativo. Outro canal 141576129 permaneceu 0.6.3.

[Antes: apps](before-apps.xml), [antes: app ativo](before-active-app.xml), [depois: apps](after-apps.xml), [depois: app ativo](after-active-app.xml), [estado final ativo](final-active-app.xml). O estado inicial ativo era a Home do simulador; 0.6.4 foi iniciado normalmente para comparação, sem modificar seu temporizador.

A exportação ECP registry/dev foi idêntica antes, após instalar e após reabrir: SHA-256 fa5b0212fe1cf731d095f5432e1e07cdec9bec3a7aa28941f2dcdbef1a8eebfc. Registro bruto ficou privado no computador, fora do GitHub. Nenhum dado apagado, favorito alterado, temporizador reiniciado ou assinatura simulada. Preservação do registro não equivale a teste funcional de favoritos.

## Evidências e roteiro executado

- [0.6.4: bloqueio de duas horas](before-064-loaded.png).
- [0.6.6: primeiro quadro de galáxia](after-066-initial.png). Splash completo não foi observado.
- [0.6.6: Home ao fundo, versão e bloqueio atual](after-066-block.png).
- Down: overlay permaneceu; Select/OK: mesmo bloqueio, sem concessão. Respostas HTTP 200 não provam navegação funcional. [Ações](actions.json).
- Back: [retorno à Home do simulador](after-back-simulator-home.png), [active-app após Voltar](after-back-active-app.xml), console EXIT_USER_NAV.
- Reabrir dev: [mesmo bloqueio em 0.6.6](after-066-relaunch.png); registro preservado.
- [Console nativo](native-console.log), [player final fechado/sem erro](final-media-player.xml), [resultados detalhados](results.json).

Mensagem observada na 0.6.6: “Acesso LAB aguardando configuração e confirmação da conta. Assinatura comercial não consultada.” O aviso bloqueia a navegação inteira, além da reprodução. Não é confirmação de falha de assinatura comercial. Nenhum login ou código temporário foi simulado.

| Teste solicitado | Resultado |
|---|---|
|1. Inicialização e splash|PARCIAL — App iniciou e chegou ao bloqueio; galáxia inicial capturada. Splash completo não observado.|
|2. Logo original|APROVADO_VISUAL — Rocha+ visível ao fundo da tela bloqueada; sem alteração de arte.|
|3. Galáxia e banner Home|APROVADO_VISUAL — Fundo e banner visíveis ao fundo do overlay; interação não aprovada.|
|4. Menu lateral e controle|BLOQUEADO — Down aceito pela API mas overlay impede mudança do menu.|
|5. Categorias horizontais|BLOQUEADO — Não foi possível entrar em Categorias.|
|6. Lista vertical|BLOQUEADO — Não acessível sem autorização LAB.|
|7. Capas e nomes|BLOQUEADO — Não foi possível abrir lista de canais para inspeção nativa.|
|8. Prévia automática|BLOQUEADO — Nenhum stream iniciado; player close sem erro.|
|9. Tela cheia e Voltar|PARCIAL — Tela cheia bloqueada; Voltar do overlay encerrou normalmente (EXIT_USER_NAV).|
|10. Favoritos e persistência|BLOQUEADO — Não acessíveis. Registro exportado ECP idêntico antes/depois; favoritos funcionais não testados.|
|11. Busca|BLOQUEADO — Overlay impede abrir busca.|
|12. PET|BLOQUEADO — Texto PET visível na Home ao fundo, categoria não acessível.|
|13. Autenticação e bloqueio|APROVADO — Aviso 0.6.6 aguardando configuração; OK não concede acesso. Reabertura continua bloqueada.|
|14. Estabilidade e FPS|PARCIAL — Sem erro de execução no console durante observação curta; FPS indisponível (endpoint zero fixo).|

Total: 3 aprovados no escopo descrito, 3 parciais, 8 bloqueados, zero reprovações demonstradas do código. Bloqueados/parciais não contam como aprovação. O timeout da ferramenta de janela é falha de instrumentação, registrada separadamente. Reprodução, áudio e desempenho físico não foram aprovados.

## Desempenho observado e comparação

0.6.4 e 0.6.6 chegaram à Home com overlay: a primeira informa fim do teste de 2 horas; a segunda informa configuração/conta pendentes. A primeira captura após reabrir 0.6.6 já estava carregada em até 11,1 s; é limite superior do intervalo observado, não latência exata. Não existe medição equivalente da 0.6.4 nesta etapa.

FPS real não disponível: [ECP bruto](graphics-frame-rate.xml) retorna 0.000000 porque a função Ie do app/main.js instalado contém constante fixa. Não interpretar como zero FPS real, nem usar para alegar melhora. Troca de categorias, carregamento de capas, prévia e encerramento de stream ativo não puderam ser medidos; o player permaneceu close e nenhum stream foi iniciado.

[Memória dos processos](process-memory.json): duas fotografias dos cinco processos do simulador. Soma de working sets ~1299,9 e ~1282,6 MiB; soma de private bytes ~699,3 e ~678,9 MiB. Os estados diferem (Home do simulador e overlay do app); páginas compartilhadas podem ser contadas em duplicidade e private bytes são memória comprometida. Sem baseline 0.6.4 comparável e sem série longa, não demonstram melhora, regressão ou vazamento.

Console não registrou runtime error, syntax error ou crash no trecho observado (inícios às 16:45:30, 16:45:52 e 16:46:44 Brasília; log usa UTC). Isso não aprova sessão longa. Captura sky da janela falhou duas vezes por timeout; a API local de instalação/ECP/screenshot e console TCP 8085 permitiu continuar. Não foi controlada página Brave nem diálogo de autenticação.

## Continuidade

Não houve mudança de código ou novo ZIP: o bloqueio está conforme configuração desativada e não foi encontrado defeito demonstrável que autorizasse contorná-lo. As 578 associações de capas e 607 registros permanecem no mesmo pacote. Testes automatizados anteriores preservados, sem repetição. Sem merge, deploy, publicação, pagamento ou alteração de assinatura.

Próximo passo: preparar o runtime HTTPS LAB e aprovação móvel autenticada conforme relatório de acesso; depois repetir apenas casos bloqueados/parciais e medir FPS real, memória em série, tempo de capas/categorias e reprodução. Teste físico permanece necessário.

Para repetir esta etapa sem apagar dados: confira o hash do ZIP, use o instalador HTTP local existente (tests/roku-visual/simulator-api.mjs), aguarde atualização assíncrona e consulte /query/apps e /query/active-app. Capture via /plugin_inspect e /pkgs/dev.png após concluir gravação. Use ECP para Down/Select/Back; não editar registro nem alterar enabled=false. Consulte master e AGENTS.md antes de continuar.
