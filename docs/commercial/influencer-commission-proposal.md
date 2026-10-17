# Rocha+ — proposta de comissão para influenciadores

Estado: proposta comercial para revisão de Lucas. Não publicada, não contratada e não implementada no aplicativo. Não altera preço, checkout, Firebase, login, pagamentos ou assinaturas.

## Comissão proposta

- R$ 1,00 por mensalidade confirmada de cliente novo indicado.
- Até seis mensalidades elegíveis por cliente, dentro dos seis meses contados do primeiro pagamento.
- Sem comissão sobre os sete dias gratuitos, tentativas recusadas, pagamentos pendentes, duplicados, cancelados ou estornados.
- Cliente cancelou e parou de pagar: não gera comissão adicional.
- Planos anuais fora do programa inicial; regra específica deverá ser definida antes de oferecê-los aos parceiros.
- Sem pagamento antecipado por visualização ou promessa de venda.

Exemplos por competência, com todos os pagamentos elegíveis:
| Mensalidades indicadas pagas | Comissão |
| --- | --- |
| 20 | R$ 20,00 |
| 50 | R$ 50,00 |
| 100 | R$ 100,00 |

No preço mensal de R$ 4,90, restam R$ 3,90 antes de taxas, tributos e demais custos. Na alternativa de R$ 5,50, restam R$ 4,50 antes desses custos. Isto é aritmética da proposta, não uma projeção de lucro nem mudança de preço. Conferir os custos reais antes de ativar a campanha.

## Como identificar a indicação

1. Cada parceiro recebe código exclusivo, por exemplo ANA10, e link contendo o código. O código não implica desconto.
2. A página de destino preserva o código e explica como digitá-lo no app. Instalação por APK pode perder os parâmetros; não confiar somente no clique.
3. O cliente informa ou confirma o código antes do primeiro pagamento. Vincular à conta, nunca apenas ao aparelho.
4. Antes de ativar o programa, implementar registro verificável da indicação no servidor: conta, parceiro, código, origem e data do aceite. Não aplicar automaticamente a clientes antigos.
5. Um cliente tem um único parceiro. O primeiro código válido confirmado vence; a atribuição é encerrada no primeiro pagamento. Mudanças posteriores exigem correção registrada, sem pagamento em dobro.
6. Pagamento confirmado pelo servidor gera lançamento de comissão, com identificador único do pagamento para evitar duplicação. Reembolso/estorno cancela a comissão; se já paga, registrar ajuste na próxima apuração.

## Apuração e pagamento propostos

- Apuração mensal por parceiro, com extrato de mensalidades elegíveis, estornos, comissão pendente e comissão liberada.
- Liberar somente após 30 dias da confirmação do pagamento; pagar no dia 10 os valores liberados até o encerramento do mês anterior.
- Pagamento via Pix após conferência do extrato, sem valor mínimo nesta proposta.
- O parceiro recebe contagens e identificadores de referência; não precisa receber e-mails, telefones ou dados de cartão dos assinantes.
- Autorreferência, cadastro duplicado e transações de teste não geram comissão.

## O que falta implementar antes de prometer esse programa

Atualmente não foi localizado módulo de afiliados na candidata. Link com código, campo de confirmação no app, registro por conta, conciliação por pagamento, relatório e controle de pagamentos ao parceiro ainda precisam ser implementados e testados. Um link isolado não comprova uma venda atribuída.

Primeiro validar o fluxo de indicação e comissão em ambiente de teste. Qualquer ativação comercial depende da revisão desta proposta e do funcionamento da apuração; esta nota não habilita cobranças ou repasses.
