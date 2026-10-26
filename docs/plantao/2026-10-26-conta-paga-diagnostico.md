# Rocha+ — pagamentos reais confirmados e liberação pendente — 26/10/2026

## Resultado vigente

A credencial MP_RECEIVING_ACCESS_TOKEN cadastrada pelo proprietário autenticou a conta recebedora esperada. As duas transações foram consultadas individualmente por GET na API Mercado Pago. Ambas são reais, estão approved/accredited, em BRL, com zero estorno informado e correspondência exata de pagador e recebedor.

| Plano informado pelo proprietário | Referência | Valor | Aprovação, America/Sao_Paulo | Resultado |
|---|---|---|---|---|
| Mensal | 185249688226 | R$4,50 | 20/10/2026 19:30:41 | Pagamento confirmado, sem estorno |
| Anual | 184267748145 | R$49,50 | 21/10/2026 06:39:29 | Pagamento confirmado, sem estorno |

Pagadora selecionada: nadiarocha10@hotmail.com. Conta Firebase oficial encontrada, e-mail verificado, Google vinculado, conta não desativada e documento rochaSparkAccounts existente. O campo paidUntil permanece nulo, portanto o documento consultado não contém período pago vigente. Nenhuma duração foi calculada ou concedida nesta rodada.

## Evidência

- Execução real: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40351814361
- Revisão executada: 6b7faf8a1b920427b64b5353ee2d17672b139648.
- Fonte da credencial: receiving-account; recebedor confere com o User ID exibido pelo proprietário no painel da Andressa.
- Script verifica identidade do recebedor antes de consultar pagamentos e só utiliza GET no provedor e leituras no Firebase.
- writes: 0; appLoginTested: false; accessGrantedByThisCheck: false.
- Verificação sintática Node e git diff --check aprovados.
- A aprovação do job comprova a execução do diagnóstico, não a homologação do fluxo completo de assinatura.

## Diagnóstico

As consultas anteriores com MP_ACCESS_TOKEN retornaram 404 para esses IDs. Com a credencial da conta recebedora correta ambos retornaram dados confirmados. Isso resolve a dúvida de escopo da credencial: o 404 anterior não indicava inexistência de pagamento.

A falta de paidUntil é uma pendência de registro/vínculo do direito no Firebase, separada da confirmação financeira. A causa exata da sincronização ausente ainda precisa de investigação; não atribuir o problema a cartão, falta de pagamento ou e-mail incorreto.

A busca de assinaturas recorrentes não encontrou correspondência exata de payer_email. Os pagamentos reais identificados são regular_payment. Não interpretar falta de assinatura recorrente como falta de pagamento avulso. Não substituir links ou criar cobranças novas.

## Próximo passo técnico

Preparar a vinculação idempotente dos dois pagamentos à identidade verificada, com verificação de titularidade, valor/plano e política de duração/renovação. Essa rotina precisa distinguir o documento Spark oficial do backend experimental de direitos. Nenhum registro financeiro real foi copiado para o projeto de homologação.

O APK 686 continua com pacote .lab, Firebase rocha-plus-homologacao e bloqueio comercial desativado. Login/reprodução nesse APK não demonstram reconhecimento desses pagamentos no projeto oficial. Validar integração e depois o fluxo no dispositivo antes de declarar homologação.

## Preservação

Alterações apenas em scripts, workflow e documentação da branch experimental feat/dual-player-lab-20261020. Sem gravações em Firebase, aprovação administrativa, cobrança, alteração de preços, publicação de APK ou modificação de refs congeladas. O token antigo permanece preservado; a nova variável é usada apenas pelo diagnóstico.

Status: VERDE para confirmação dos dois pagamentos; AMARELO para vínculo de acesso e teste no aplicativo.
