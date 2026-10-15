# Varredura de login, trial e acesso — 15/10/2026

Base imutável: `freeze/mobile-bau-approved-20261015`, commit
`fa1f048b1960a706ba143a145a1608c4d4329922`.
Correção: `fix/login-trial-access-race-20261015`, PR #29.

## Diagnóstico

O gate anterior decidia entre Home e assinatura pelo booleano `allowed`, que é
falso antes da primeira resposta do servidor. Isso mostrava checkout enquanto a
consulta/primeira criação de trial ainda estava em andamento. O alerta era
agendado em outro callback e podia aparecer depois dessa cobrança temporária.

A sessão principal já tinha uma chave por UID. Entretanto, o gate isolado não
recriava seu controller quando recebia outro UID, nem invalidava os callbacks
assíncronos do aviso. O aviso era uma rota modal independente da árvore privada.

A consulta somente de leitura da conta solicitada, executada em
https://github.com/japarocha2-cloud/rocha-plus/actions/runs/38754099660,
confirmou para `andressarocha9706@gmail.com`:

- Início: 14/10/2026 07:24:40.112 UTC (03:24:40 em Manaus).
- Vencimento: 21/10/2026 07:24:40.112 UTC (03:24:40 em Manaus).
- Na leitura de 15/10/2026 14:44:36.993 UTC: `state=trial`, 492004 segundos restantes.
- Aviso aceito, sem `paidUntil`. Nenhuma data foi modificada.

Portanto, a reprodução dessa conta por mais de dois minutos não comprova falha:
ela ainda possui trial real de sete dias. O laboratório de dois minutos é outro
entrypoint (`lib/trial_lab_main.dart`) e não determina o prazo comercial.

## Comportamento corrigido

- Sem resposta de acesso: tela neutra, sem Home ou cobrança.
- Falha de consulta: mensagem neutra com nova tentativa e saída da conta.
- Trial não aceito: mesma arte aprovada, antes da Home. Ao aceitar, a confirmação
  fica em tela neutra até o servidor persistir o aceite. Falha pode ser repetida
  sem reapresentar a arte na mesma sessão; o recibo local não substitui o servidor.
- Trial aceito válido e assinatura paga válida: Home.
- Resposta de período vencido: assinatura, sem saída para Home ou player.
- Revogação de acesso: descarta a pilha privada e solicita encerramento do Cast.
- Troca de conta: invalida controller, pilha e callbacks anteriores.
- Saída: fecha acesso local antes de aguardar limpeza do provedor e ignora eventos
  não nulos durante esse encerramento.
- Reabertura e reinstalação consultam o mesmo registro por Google subject; nenhuma
  correção de UI cria um novo prazo ou altera datas/pagamentos no Firestore.

## Validação

Os testes cobrem consulta lenta, falha/retry, trial novo/aceito, pago/vencido,
resposta atrasada após troca, player aberto ao trocar/vencer, troca durante aviso,
aceitação lenta/falha, reinstalação sem preferências, reabertura vencida e resume.
Os testes REST cobrem o limite exato de sete dias, conflito na primeira criação,
recriação do repositório e rejeição de resposta de outra conta.

As nove verificações das regras Firestore passaram localmente em emulador usando
as regras desta branch: criar uma vez, isolamento, rejeitar reset/delete e data
arbitrária, impedir auto concessão de pagamento, aceite imutável, UID recriado com
mesmo Google subject, preservar pagamento, favoritos e protocolo REST.

A primeira suíte completa teve 132 casos aprovados e quatro falhas de overflow em
Home com texto ampliado. Home e seus assets não foram alterados nesta correção.
O CI executa a suíte completa no candidato e na base Baú imutável, sem pular
casos. Só libera a compilação se o conjunto de falhas coincidir exatamente com os
quatro casos documentados de layout, sem nova falha nem testes pulados. O relatório
`access-flow-test-evidence` distingue esses casos; CI aprovado não significa que
as falhas visuais antigas foram corrigidas.

## Validação física pendente — sem pagamento

1. Instalar o candidato separado e confirmar seu versionCode; guardar APKs 4005,
   4007 e Baú congelado como referências.
2. Trocar de conta com rede lenta: somente tela neutra durante a confirmação,
   sem cobrança piscando ou conteúdo da conta anterior.
3. Conta elegível: aviso aprovado; aceitar; Home; sair e voltar; reabrir e
   reinstalar com a mesma conta; aviso e prazo não devem reiniciar.
4. Conta Andressa: abrir Home diretamente enquanto o trial acima estiver válido.
5. Conta realmente vencida sem pagamento: assinatura; Voltar, reabertura e troca
   de conta não liberam canais. Não alterar datas reais para fabricar expiração.
6. Assinante já ativo: Home sem aviso. Não criar nova cobrança para este teste.
7. Revalidar canal com áudio/vídeo, fullscreen, favorito por conta e Cast.

Nenhum aparelho físico está conectado a este ambiente. Estes passos exigem
instalação e observação no aparelho do responsável; não foram declarados feitos.
A homologação com R$ 4,90 fica para depois das evidências e dessa validação.

## Preservação

Sem mudanças em arte, link comercial, banner Baú, Home, catálogo/capas dos canais,
player, Cast, preços ou destino dos checkouts. Sem merge, atualização das refs
congeladas, implantação de regras, escrita em produção ou cobranças reais.
