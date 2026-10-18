# Rocha+ — Regulamento do Plano Fundador

**MINUTA V0.1 • PARA REVISÃO • NÃO É UMA OFERTA ATIVA**

## Objetivo
Reconhecer quem aderir ao Rocha+ durante a fase inicial de TV aberta. A intenção é que o fundador preserve **o preço original de sua modalidade** nas renovações elegíveis mesmo se, no futuro, o aplicativo incorporar filmes e séries.

## Modalidades e valores de referência
| Condição | Mensal | Anual |
| --- | ---: | ---: |
| Fundador no lançamento de TV aberta | **R$ 4,90/mês** | **R$ 53,90/ano** |
| Nova adesão após a eventual expansão para filmes e séries | **R$ 15,50/mês** | **R$ 170,50/ano** |

Descontos anuais: fundador paga R$ 53,90 em vez de R$ 58,80 (economia de R$ 4,90, equivalente a uma mensalidade). Após expansão, novo cliente pagaria R$ 170,50 em vez de R$ 186,00 (economia de R$ 15,50, equivalente a uma mensalidade).

**Nenhum valor futuro é compromisso de lançamento de filmes.** A expansão não tem data e depende de autorizações de conteúdo, infraestrutura e capital.

## Elegibilidade a decidir ANTES da primeira venda
1. **Início e encerramento do período fundador:** [DATA/HORA/FUSO DE INÍCIO E DE CORTE A DEFINIR]. Deve haver comunicação prévia transparente.
2. **Momento de aquisição do direito:** [DECIDIR: compra paga validada pela Play OU assinatura com teste grátis iniciada antes da data de corte e convertida em pagamento após o teste]. O regulamento não pode deixar o cliente adivinhar.
3. **Identificação:** comprovação no backend pela compra Google Play, conta vinculada e produto/base plan, com mecanismo auditável, sem depender apenas de checkbox, texto da interface ou declaração do usuário.
4. **Duração do benefício:** preservação em renovações elegíveis enquanto persistirem as condições divulgadas e tecnicamente operáveis, sujeita a exigências legais; vedada promessa ambígua de "para sempre".
5. **Cancelamento e expiração — DECISÃO COMERCIAL:** se o cliente cancelar a renovação e a assinatura chegar ao fim do período pago sem continuidade, **perde definitivamente o benefício de fundador para nova contratação futura**. O cancelamento não encurta o período já pago: o acesso permanece até o vencimento, salvo situações legalmente previstas (por exemplo, reembolso/revogação). Se desfizer o cancelamento **antes do vencimento**, mantendo a mesma assinatura ativa sem interrupção, conserva o benefício. Depois que ela expirar, eventual nova assinatura usará o preço disponível para novos clientes na data da contratação, mesmo que seja a mesma conta.
6. **Troca de modalidade:** [DECIDIR o que acontece ao migrar mensal ↔ anual]. Evitar converter automaticamente sem informar valores e impacto no direito ao benefício.
7. **Falha de pagamento, suspensão, período de carência e reativação:** [DEFINIR conforme Play e CDC].
8. **Transferência de contas:** [DEFINIR]. Não permitir fraude com vínculos de token de compra.
9. **Alterações substanciais e comunicação:** observar regras de preço legado e direitos do consumidor.

## O que NÃO é prometido
- Inclusão de filmes ou séries em data específica, nem quantidade ou títulos determinados.
- Direito automático a qualquer recurso que não tenha sido efetivamente lançado.
- Recuperação do preço fundador após o vencimento de uma assinatura cancelada: nessa hipótese, o cliente que voltar adere à tabela vigente, sem preço legado.
- Acesso comercial enquanto Play Console e backend estiverem em modo de testes.

## Apresentação proposta no aplicativo
> "Quem assinar o Rocha+ no período fundador poderá manter seu valor original nas renovações elegíveis, mesmo se lançarmos filmes e séries no futuro. Se você cancelar e deixar sua assinatura vencer, perderá o preço de fundador ao voltar. Seu acesso já pago continua até o vencimento. Filmes e séries ainda não têm data definida. Consulte as condições completas antes de assinar."

## Implementação futura
- Configurar base plans com períodos mensal e anual na Play Console.
- Usar preservação de *legacy price cohorts* ao atualizar os preços para novos assinantes; não encerrar a coorte antiga indevidamente.
- Persistir no backend metadados mínimos de elegibilidade e versão do regulamento; verificar entitlement na API Google Play.
- Fazer testes com contas de licença para renovação, preço legado, cancelamento, retorno, troca e eventual trial.
- Manter PR #16 em modo testes até autorização expressa. O mensal em testes de **R$ 4,90/mês** agora coincide com o planejamento; o anual **R$ 53,90/ano** ainda precisa ser configurado e validado antes de qualquer cobrança.

Fonte técnica: https://developer.android.com/google/play/billing/price-changes
