# Rocha+ — homologação funcional experimental (27/10/2026)

Missão: comentário https://github.com/japarocha2-cloud/rocha-plus/pull/42#issuecomment-6439534795
Base: `903bfad7528781f2a5807955e7ce52c1e05e3f37`; branch exclusiva `fix/subscription-access-20261026`.
Preservar PR draft, APK oficial, pagamentos, favoritos e canais. Sem merge, deploy, publicação ou APK novo.

## Auditoria e mudanças
- Cast consultava o último status a cada 500 ms. Eventos durante LOAD ou entre consultas podiam não ser examinados. A observação agora começa antes de LOAD, com fila limitada, cancelamento em finally e consulta complementar.
- Status antigo e mídia de outro canal continuam insuficientes. PLAY ocorre uma única vez e somente para a mídia solicitada pausada. Erro sem metadados é atribuído ao pedido apenas após observação da mídia correspondente.
- Erros de conexão, comando, receiver e ausência de confirmação têm mensagens distintas e sem detalhes sensíveis. Falha de observação/desconexão impede PLAY. Nova carga invalida a anterior. Timeout de confirmação não inicia um segundo LOAD via relay; fallback fica limitado a erro explícito de mídia.
- Navegação usa FocusScope para priorizar foco nos botões, sem exigir uma tecla extra no contêiner. D-pad conserva navegação de foco; repetição de CH não troca canal novamente.
- Player Exo libera o controller antigo uma única vez e ignora inicialização tardia. Temporizador dos controles é cancelável. LibVLC passa a sair do fullscreen com Voltar antes de sair da rota, com foco inicial no controle de reprodução.
- Assinatura preserva allowed/uid como decisão do servidor e exibe reason coerente trial/paid/expired. expiresAt é opcional, com formato validado; nunca é inventado a partir de prazo local.
- Consulta de assinatura descarta troca de conta durante token/HTTP. UI limpa resposta anterior na consulta, troca de conta, retomada e reabertura. Não guarda autorização de reprodução nem modifica entitlement.
- Nenhuma função Firebase, regra, reconciliação, pagamento ou canal alterado.

## Verificação automatizada
Suíte Flutter completa, flutter analyze completo, testes Node de funções e entitlement/HTTP local,
e Python de configuração Android na CI do commit desta missão.
Testes adicionais: eventos Cast durante LOAD, timeout/reconexão, desconexão e receiver sem metadata;
D-pad/foco/repetição de teclas; decoder falho/recuperação/troca rápida/descarte/Voltar;
motivo de acesso, metadados inválidos, token, offline, troca de conta, retomada e reabertura.
Resultados e links são registrados no PR após a execução. Nenhum mock é teste físico.

## Roteiro físico obrigatório (AMARELO)
Usar somente build LAB já autorizado ou futuro build solicitado separadamente. Esta missão não gera APK.
Registrar: data/hora com fuso, responsável, commit/build instalado, modelo/Android, Chromecast/firmware,
engine, rede, canal/região e identificador privado da fonte (não publicar tokens/URLs sensíveis).

| Setor | Procedimento | Evidência exigida |
|---|---|---|
| Cast | Conectar, LOAD, confirmação, pausar/retomar, trocar canal e repetir após desconectar/reconectar | Imagem e áudio no receiver; nenhum controle liberado para mídia antiga |
| Cast | Retirar rede/desligar receiver durante LOAD, restaurar e reconectar | Mensagem correta; tentativa antiga não envia PLAY nem encerra a nova sessão |
| Cast | Canal com erro comprovado no receiver e canal lento | Distinguir erro de mídia de ausência de confirmação; não excluir canal por timeout |
| TV Exo/LibVLC | D-pad, Select/Enter, CH+/CH-, PageUp/Down, fullscreen, Voltar duas vezes | Primeiro Voltar sai do fullscreen; foco visível e sem troca por repetição |
| TV Exo/LibVLC | Alternar canais rapidamente, falhar/repetir, trocar engine, sair/reabrir 10 vezes | Sem áudio residual, controllers antigos ou crescimento persistente de memória |
| Assinatura | Contas de homologação trial, paid, expired; conta trocada; token inválido; offline; retomada | UI corresponde ao servidor, sem liberar por data local ou conservar status da outra conta |

Para cada canal selecionado e autorizado: Exo 60 s + LibVLC 60 s, depois confirmação de 180 s no engine escolhido.
Registrar imagem, áudio audível, startup, buffering, reconexão, resultado e evidência.
Matriz em branco: `docs/auditoria/matriz-fisica-20261027.csv`. URLs e nomes regionais preservados.
Trial/pagamentos só com fixtures/contas de homologação preparadas; sem cobranças ou reconciliação real.

## Classificação
VERDE apenas para verificações automatizadas efetivamente aprovadas.
AMARELO para audiovisual, estabilidade/memória nativa, rede física e estados reais de conta ainda não observados.
VERMELHO somente para falha comprovada, com evidência; não confundir teste pendente com reprovação de canal.
