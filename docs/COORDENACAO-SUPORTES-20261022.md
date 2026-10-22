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

- No código de partida, Cast não possuía observação contínua da desconexão inesperada. O segundo ciclo abaixo implementa observador; teste físico e CI do novo código continuam necessários.
- Favoritos usavam chave local global no código de partida, sem UID. Correção adicional passa UID explicitamente do app às telas e congela namespace por instância do repositório; guest fica separado. Listas legadas não são atribuídas a conta por suposição. Carregamentos antigos são descartados após mudar conta. Quatro testes adicionados, ainda pendentes de execução Flutter. Não há sincronização em nuvem.
- No código de partida, o gate de assinatura podia deixar uma rota de player aberta após expiração. O segundo ciclo abaixo corrige a propriedade das rotas locais; integração, testes e interrupção de Cast remoto continuam bloqueios de lançamento.
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

## Continuação: CI do `184c731` e segundo ciclo

Os seis suportes entregaram o primeiro ciclo no commit `184c731e7720c027e18d831449798ebfc3749419`. Conferência remota preservou 12 referências protegidas (`main`, freeze/frozen/checkpoint).

- [Build 39787581579](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39787581579): job unitário Node concluído com sucesso; etapas Analyze e Test do Flutter passaram. Compilação/observação Android ainda em execução na conferência deste ciclo; não declarar workflow inteiro aprovado antes de concluir.
- [Laboratório 39787581678](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39787581678): build concluído com sucesso; `smoke / device` iniciado, ainda sem nova conclusão audiovisual. Essa execução testa `184c731`, não as mudanças posteriores abaixo.
- Fiscal acrescentou rejeição de metadados de preferência e métricas malformadas sem derrubar o validador. Os 26 testes Python LAB passaram; as exigências de aprovação audiovisual não foram reduzidas.
- Segurança preparou gate proprietário de um Navigator protegido: negativa, erro e timeout de revalidação removem as rotas locais, com proteção contra respostas atrasadas de UID antigo. A política beta gratuita continua intacta. Testes de regressão novos ainda devem passar no CI; destruição de widget/controlador não comprova parada física nem revoga Cast remoto.
- Espelhamento integrou observação contínua da sessão, incluindo desconexão inesperada, erro/fim do stream e cancelamento de callbacks antigos. Treze regressões novas foram escritas para observador/sessão; a confirmação de conexão agora distingue operação válida de cancelada para evitar pausa/navegação tardia. Execução Flutter no CI ainda necessária. Não equivale a homologação física de reconexão ou espelhamento.
- O gate recebeu sete testes widget com PlayerScreen/VideoPlayerController e plataforma simulada, inclusive fullscreen, erro, timeout, Voltar e UID trocado. A dependência da interface de vídeo foi declarada somente para desenvolvimento. Isso verifica pedidos de descarte quando os testes passarem; não comprova parada física do decoder. Revalidação periódica de um minuto e timeout de 12 segundos, sem promessa de revogação instantânea.
- Nova evidência do diagnóstico anterior: os erros `pcm_writei` começam antes da instalação/abertura do laboratório. Falha de sons do sistema já existia no emulador; não atribuir ao player/catálogo sem isolamento adicional.

O estado de lançamento permanece VERMELHO até áudio Android comprovado e assinatura integrada/testada ponta a ponta. O novo ciclo continua exclusivamente experimental.

## Correção do CI após `245acd3`

[Build 39789137900](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39789137900), job `119860156473`, parou na análise por sete ocorrências de `prefer_function_declarations_over_variables` em `test/subscription_gate_test.dart`. Não houve erro de tipo ou compilação apontado nessa etapa; os testes Flutter e a geração de APK foram pulados. O job Node de direitos passou. O laboratório `39789137922` ainda não tinha jobs na consulta, pois aguarda a execução anterior do mesmo grupo.

O hotfix substitui as sete closures nomeadas por declarações locais de função; não suprime o analisador e não modifica código de produção ou exigências dos testes. `git diff --check` passou. Resultado da nova análise e dos testes deve ser conferido no próximo CI, sem aprovação antecipada.

### Resultado do `86655f0` e instrumentação do descarte

[Build 39789955824](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39789955824): Analyze passou; Node passou; Flutter registrou **136 testes passando e cinco falhando**, todos no novo arquivo do gate. Falhas: descarte após expiração, erro, timeout e mudança de UID; retorno por Voltar. Os testes de Cast passaram nessa execução. O APK não foi gerado por esse build.

Os testes agora registram desativação/descarte da rota, cancelamento dos eventos de vídeo e chamada de descarte da plataforma. A checagem inclui widgets fora da tela (`skipOffstage: false`) e aguarda as condições completas com limite de dois segundos; também verifica término da animação de entrada antes de Voltar. Nenhum assert de encerramento foi removido, nenhum teste foi pulado e nenhum código de produção foi alterado neste diagnóstico. O próximo CI deve distinguir espera assíncrona insuficiente de falha real; o gate permanece sem aprovação até o resultado.

### Diagnóstico do `2da5277` e nova correção do teste

[Build 39790773555](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39790773555): análise passou; 136 testes passaram e cinco falharam. A instrumentação confirmou zero players inclusive offstage, `route-dispose` e `events-cancel:0`, sem `native-dispose`. O retorno por Voltar já remove a rota; resta confirmar o descarte da plataforma simulada.

A fonte oficial Dart mostra que cancelamento síncrono sem Future pode retornar o singleton de Future da zona raiz. A fake foi alterada para modelar cancelamento assíncrono na zona do teste e alocar o Future de fechamento nessa mesma zona. Adicionado baseline do controlador sem Navigator e exigência de conclusão de cancelamento/descarte, mantendo o limite de dois segundos. A hipótese é específica do ambiente de testes e será confirmada ou rejeitada pelo novo CI; não constitui teste físico nem mudança de produção.

O smoke de `184c731` terminou VERMELHO: RGB 5/5, tom 440 Hz ausente e RMS −98,84018 dBFS. Artifact `12430982223`, ZIP SHA-256 `e0e2bd842746ddb9c360138f00d31fa4007e3955e5255d6fc32d98077a65bf14`, confirmou root no emulador. A coleta ALSA descartava stdout útil quando um dos caminhos posteriores não existia. O coletor agora separa cards, pcm, status e dispositivos, preserva stdout/stderr e código de saída mesmo em falha. Um teste de regressão cobre esse comportamento; aprovação audiovisual permanece igual.

## Terceiro ciclo: integração HTTP e calibração antecipada

[Build do fcdedef, 39791595216](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39791595216) concluiu com sucesso: Node, análise e **142 testes Flutter**, APK experimental e observação das rotas de categorias no emulador. O log do job `119868783727` confirma o baseline do controlador e o descarte após expiração fullscreen passando. A correção da fake de cancelamento resolveu as falhas da suíte; isso comprova o comportamento automatizado local, sem homologar aparelhos físicos ou cobrança real. [Laboratório 39791595575](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39791595575) ainda não tinha resultado audiovisual confirmado na consulta deste ciclo.

### Assinaturas

- Transporte HTTP extraído para módulo testável, preservando Firebase/Firestore no adaptador de servidor. Testes usam sockets de loopback reais e o núcleo de regras existente; verificadores e armazenamento dos cenários positivos são doubles.
- Corrigida decodificação UTF-8 de JSON dividido em pacotes. O limite de corpo conta bytes e retorna JSON 413 sem interromper antecipadamente o leitor com um erro de conexão em vez da resposta.
- Gerado lockfile e executado `npm ci --ignore-scripts` localmente. Nenhuma credencial de produção foi consultada, nenhum serviço implantado e nenhum pagamento real foi processado.
- **25 testes Node passaram**: 15 do núcleo, oito de HTTP e dois com o Firebase Admin SDK real para rejeitar tokens malformados e audiência/emissor incorretos. Ainda faltam tokens legítimos, revogação remota, transações/regras Firestore reais, HTTPS e integração com o app/administrador/Cast.
- CI passa a instalar dependências com lockfile e executar todos os arquivos de teste do backend.
- Fiscal estático agora ignora dependências instaladas em `node_modules` e inclui os módulos próprios `.mjs` na verificação. Três regressões comprovam que arquivos de terceiros não geram falsos achados, enquanto segredo fixo e URL insegura do backend próprio continuam bloqueados. Sete testes Python de configuração/fiscal passaram.

### Áudio

- Criada checagem preliminar independente que coleta aproximadamente 45 segundos da primeira fase Exo da fixture conhecida e os dumps de áudio. Tem limite de infraestrutura de três minutos e exige três quadros RGB e pelo menos 20 segundos úteis de PCM com tom 440 Hz, RMS e pico espectral compatíveis.
- A checagem produz somente `preflight.json`, sempre com `productionApproved=false` e `channelApproval=false`. Não gera resultado homologado de canal.
- Se o ambiente falhar, o CI preserva os diagnósticos e bloqueia a etapa longa antes de percorrer as fixtures completas. Se passar, o smoke completo e os lotes continuam exigindo 60 segundos em cada player e confirmação de 180 segundos, sem alteração.
- **31 testes Python LAB passaram**, incluindo quatro casos da checagem preliminar: tom correto, silêncio/tom errado/captura curta/ruído, RGB insuficiente e erro na gravação. A execução real do novo preflight aguarda o próximo CI; áudio continua VERMELHO.

O lançamento permanece VERMELHO. Beta gratuito, versão congelada, catálogo oficial e política de cobrança não foram alterados.
