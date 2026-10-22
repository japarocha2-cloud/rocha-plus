# Coordenação dos seis suportes — 22/10/2026

## Escopo

O usuário autorizou explicitamente a execução paralela dos seis suportes. Foram iniciados seis agentes nesta sessão, um por tarefa #36 a #41, com revisão e integração pelo coordenador. Isso é execução desta sessão, não serviço permanente nem execução automática das issues.

Trabalho restrito à branch experimental `feat/dual-player-lab-20261020`, PR #33, partindo de `461e62d0be8e73d202a004791944a51a2e2a67b6`. Não promover lançamento nem alterar a versão oficial congelada. Código corrigido, teste automatizado, observação no emulador e teste físico são evidências diferentes.

## Resultado mais recente examinado

[Laboratório 39776616606](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39776616606): compilação passou; `smoke / device` falhou; batch10, batch25 e remaining foram pulados. A execução terminou; não estava mais trabalhando ao iniciar este ciclo.

O artifact `12425863407`, ZIP SHA-256 `7b9ac05550072f7b21184c8156124bb5dc32a4b073c90621b993a15aef80ee66`, contém:

- `host-calibration.json`: tom host de 997 Hz reconhecido por dois segundos, `hostLoopbackVerified=true`, `androidAudioVerified=false`.
- `smoke/calibration-failure.json`: 5/5 quadros RGB reconhecidos, movimento observado, tom Android de 440 Hz ausente; RMS −98,76195 dBFS.
- AudioFlinger com sinal no mixer e erros HAL `pcm_writei ... I/O error`. Isso orienta investigar o caminho guest/host; ainda não demonstra a causa exata nem defeito dos canais.

## Entregas dos suportes

| Suporte | Resultado deste ciclo | Estado de homologação |
| --- | --- | --- |
| #36 Fiscal | Gate Python exige fase inicial do motor escolhido por 60 s e confirmação de 180 s, com pixels e PCM em ambas. Novas regressões e diagnóstico privilegiado apenas no emulador AOSP descartável. CI passa a testar o backend Node. | VERMELHO para áudio Android; compilação anterior passou. |
| #37 Catálogo | Gate Dart e importador alinhados; rejeitam preferência incoerente e métricas impossíveis. Inventário: 479 URLs distintas, zero duplicações exatas e 14 categorias; `lab_approved.json` vazio. | AMARELO; nenhum canal novo homologado. |
| #38 Visual | Auditoria de fontes sem mudança de tema/artes: entradas principais não solicitam fullscreen TV; VLC tem modo fullscreen incompleto; este carrossel experimental não contém Amambai/Baú; classes usam ícones. | AMARELO; propostas exigem revisão antes de integração visual. |
| #39 Espelhamento | Invalidação de operações Cast pendentes após parar/destruir sessão; retorno antigo não reativa Cast, troca canal ou destrava operação nova. Cinco regressões adicionadas. | AMARELO; testes Flutter e testes físicos ainda necessários. |
| #40 Segurança | Backend experimental de direitos com UID/token verificado, trial de sete dias, registro administrativo de confirmação/renovação/estorno, idempotência e Firestore transacional preparado. Exceções de token tratadas com timeout. Quinze testes unitários passaram. Nenhuma implantação ou ativação da política paga. | VERMELHO; bloqueio de inadimplência ainda não aprovado. |
| #41 Administrativo | Inventário documental e lacunas registrados em `SUPORTE-41-ADMINISTRATIVO-20261022.md`. Sem termos finais ou comprovantes de autorizações apresentados no checkout. | AMARELO documental; publicação não liberada. |

## Pendências adicionais verificadas

- Cast não possui observação contínua da desconexão inesperada no fluxo examinado; há verificações ao retornar da tela de controle. A proteção contra retorno tardio não resolve essa pendência inteira.
- Favoritos usavam chave local global no código de partida, sem UID. Correção adicional passa UID explicitamente do app às telas e congela namespace por instância do repositório; guest fica separado. Listas legadas não são atribuídas a conta por suposição. Carregamentos antigos são descartados após mudar conta. Quatro testes adicionados, ainda pendentes de execução Flutter. Não há sincronização em nuvem.
- O gate atual de assinatura pode deixar uma rota de player já aberta quando a assinatura expira. O backend não resolve essa evasão sozinho; interromper player e Cast de forma verificável continua bloqueio de lançamento.
- Detecção de tela larga se baseia em largura, não identifica por si só Android TV. Fullscreen e controle exigem ensaio físico.
- Termos, privacidade e autorizações podem existir fora do repositório; não foram apresentados nesta auditoria. Não inferir inexistência externa.

## Validação e limites

- 24 testes Python de laboratório passaram; quatro testes Python de configuração passaram; Fiscal estático passou.
- Quinze testes Node do núcleo de direitos passaram, usando verificador e armazenamento em memória. Sintaxe do adaptador Node verificada. Dependência Firebase Admin ainda não instalada; adaptador, criptografia real, Firestore e HTTP/HTTPS não foram testados ponta a ponta.
- Flutter/Dart não estão instalados no ambiente local: as novas regressões Dart não foram executadas localmente. Devem passar no CI antes de serem consideradas verificadas.
- Não houve teste físico de TV, Chromecast, áudio, pagamento ou bloqueio neste ciclo. Backend não implantado e catálogo oficial preservado.
- Resultado do novo CI e validação do backend serão registrados após o envio, separadamente das evidências anteriores.

## Ordem de saída

1. Revisar e testar correções, enviar somente à branch experimental e conferir o novo CI.
2. Obter diagnóstico ALSA/kernel e corrigir áudio guest/host sem reduzir exigências para conseguir aprovação artificial.
3. Validar backend em ambiente isolado com Firebase/Firestore reais ou emuladores adequados, sem tocar produção; executar E2E antes de ligar cobrança.
4. Reexecutar canais somente após calibração Android válida; preservar categorias e populares primeiro, sem aprovar candidatos por URL.
5. Testar controle/Cast em aparelhos, revisar propostas visuais e completar documentação antes de qualquer lançamento.
