# Rocha+ — diagnóstico de conta paga, somente leitura — 26/10/2026

## Escopo
Conta selecionada pelo proprietário: nadiarocha10@hotmail.com. Consulta expressamente autorizada; scripts e workflow somente na branch experimental feat/dual-player-lab-20261020. Nenhuma cobrança, confirmação, alteração de assinatura, acesso, preços, Firebase ou versões congeladas.

## Evidência real
Execução: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40342449660
Fonte: Firebase Admin e API Mercado Pago, com credenciais protegidas do repositório. Nenhuma credencial, UID, documento bancário ou identificador de pagamento impresso.

- Firebase oficial rocha-plus: conta encontrada, e-mail verificado, não desativada, Google vinculado, documento Spark existente.
- paidUntil: ausente/nulo. Não há período pago vigente registrado nesse documento.
- Mercado Pago: recebedor autenticado. Pesquisa de assinaturas retornou sete resultados, nenhum com payer_email exatamente igual ao e-mail selecionado. Não se aceita filtro do provedor sem conferir cada resultado.
- Pagamentos diretos: busca completa no recebedor conectado, últimos 30 dias, filtrada localmente por e-mail exato do pagador e recebedor. Uma operação correspondente: status approved, live_mode true, operation_type card_validation, valor BRL 0,00, sem estorno, aprovada em 13/10/2026 22:19:42 no fuso America/Sao_Paulo (14/10/2026 01:19:42 UTC).
- Validação de cartão sem valor não comprova pagamento do plano.
- Nenhuma liberação de acesso foi realizada; login físico no APK não foi testado.

## Limites e próximo passo
Não é prova de inexistência de pagamento. Pagamento em outro recebedor, outro e-mail de pagador, fora da janela consultada ou em Asaas/Inter não foi coberto. Para localizar o pagamento relatado, obter o ID da transação ou comprovante com data/valor/meio/recebedor e conferir diretamente no provedor. Não solicitar novo pagamento nem vincular por semelhança de nomes.

O APK 686 usa Firebase de homologação e bloqueio comercial desativado. A existência de conta/pagamento no projeto oficial não prova liberação nesse APK; não copiar registros reais para homologação automaticamente.

Status: VERDE para execução de diagnóstico somente leitura; AMARELO para vínculo de pagamento e teste no aplicativo. O resultado não homologa cobrança.
