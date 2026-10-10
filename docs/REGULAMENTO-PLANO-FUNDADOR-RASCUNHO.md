# Rocha+ — Regulamento do Plano Fundador

**MINUTA V0.1 • PARA REVISÃO • NÃO É UMA OFERTA ATIVA**

## Objetivo
Reconhecer quem aderir ao Rocha+ durante a fase inicial de TV aberta. A intenção é que o fundador preserve **o preço original de sua modalidade** nas renovações elegíveis mesmo se, no futuro, o aplicativo incorporar filmes e séries.

## Modalidades e valores de referência
| Condição | Mensal | Anual |
| --- | ---: | ---: |
| Fundador no lançamento de TV aberta | **R$ 5,00/mês** | **R$ 55,00/ano** |
| Nova adesão após a eventual expansão para filmes e séries | **R$ 15,50/mês** | **R$ 170,50/ano** |

Descontos anuais: fundador paga R$ 55,00 em vez de R$ 60,00 (economia de R$ 5,00, equivalente a uma mensalidade). Após expansão, novo cliente pagaria R$ 170,50 em vez de R$ 186,00 (economia de R$ 15,50, equivalente a uma mensalidade).

**Nenhum valor futuro é compromisso de lançamento de filmes.** A expansão não tem data e depende de autorizações de conteúdo, infraestrutura e capital.

## Elegibilidade a decidir ANTES da primeira venda
1. **Início e encerramento do período fundador:** [DATA/HORA/FUSO DE INÍCIO E DE CORTE A DEFINIR]. Deve haver comunicação prévia transparente.
2. **Momento de aquisição do direito:** [DECIDIR: compra paga validada pela Play OU assinatura com teste grátis iniciada antes da data de corte e convertida em pagamento após o teste]. O regulamento não pode deixar o cliente adivinhar.
3. **Identificação:** comprovação no backend pela compra Google Play, conta vinculada e produto/base plan, com mecanismo auditável, sem depender apenas de checkbox, texto da interface ou declaração do usuário.
4. **Duração do benefício:** preservação em renovações elegíveis enquanto persistirem as condições divulgadas e tecnicamente operáveis, sujeita a exigências legais; vedada promessa ambígua de "para sempre".
5. **Cancelamento e expiração:** [DECIDIR se perde o desconto ao expirar e se haverá janela de recuperação por problemas de pagamento].
6. **Troca de modalidade:** [DECIDIR o que acontece ao migrar mensal ↔ anual]. Evitar converter automaticamente sem informar valores e impacto no direito ao benefício.
7. **Falha de pagamento, suspensão, período de carência e reativação:** [DEFINIR conforme Play e CDC].
8. **Transferência de contas:** [DEFINIR]. Não permitir fraude com vínculos de token de compra.
9. **Alterações substanciais e comunicação:** observar regras de preço legado e direitos do consumidor.

## O que NÃO é prometido
- Inclusão de filmes ou séries em data específica, nem quantidade ou títulos determinados.
- Direito automático a qualquer recurso que não tenha sido efetivamente lançado.
- Valor fixo em situações de encerramento da assinatura e contratação de uma nova depois do período fundador, salvo regras expressas.
- Acesso comercial enquanto Play Console e backend estiverem em modo de testes.

## Apresentação proposta no aplicativo
> "Quem assinar o Rocha+ no período fundador poderá manter seu valor original nas renovações elegíveis, mesmo se lançarmos filmes e séries no futuro. A expansão ainda não tem data definida. Confira o regulamento completo, inclusive regras sobre cancelamento, troca de plano e elegibilidade, antes de assinar."

## Implementação futura
- Configurar base plans com períodos mensal e anual na Play Console.
- Usar preservação de *legacy price cohorts* ao atualizar os preços para novos assinantes; não encerrar a coorte antiga indevidamente.
- Persistir no backend metadados mínimos de elegibilidade e versão do regulamento; verificar entitlement na API Google Play.
- Fazer testes com contas de licença para renovação, preço legado, cancelamento, retorno, troca e eventual trial.
- Manter PR #16 em modo testes até autorização expressa. O código atual ainda trabalha com **R$ 4,90/mês**, divergente dos preços planejados mais recentes; conciliar antes de quaisquer cobranças.

Fonte técnica: https://developer.android.com/google/play/billing/price-changes
