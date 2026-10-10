# Rocha+ — planos fundadores, termos e prévia de site (RASCUNHO)

Status: **proposta de planejamento, NÃO publicada e sem cobrança**. Revisão jurídica e verificação de viabilidade comercial/Google Play obrigatórias antes de uso real.

## Fonte e valores atualizados pelo responsável do projeto

| Cliente / fase | Mensal | Anual | Observação |
| --- | ---: | ---: | --- |
| Fundador que contrata na fase inicial de TV aberta | R$ 5,00 | R$ 55,00 | Anual com desconto de 1 mensalidade (12 × R$ 5 = R$ 60; R$ 60 - R$ 5 = R$ 55). |
| Novos clientes **após eventual** lançamento de filmes e séries | R$ 15,50 | R$ 170,50 | Anual com desconto de 1 mensalidade (12 × R$ 15,50 = R$ 186; menos R$ 15,50). |

- Lançamento principal: **TV aberta autorizada**, sem filmes e séries inicialmente.
- Filmes e séries: apenas **hipótese futura**; preparar com capital gerado, sem data garantida e sem promessa de catálogo.
- Estratégia proposta: assinantes **fundadores** mantêm o preço original *nas renovações elegíveis*, inclusive após a eventual expansão. Novas adesões posteriores seguem a tabela então vigente.
- Data de corte, definição do status fundador e tratamento de cancelamento, restauração, renovação, troca de plano, interrupção de pagamento, reembolsos, mudanças exigidas pela Play e clientes que retornam **ainda precisam de regras formais**. Não prometer preço vitalício irrestrito nem benefício que já esteja tecnicamente implementado.
- Nenhuma contratação, implantação, atualização do APK, lançamento ou mudança de cobrança foi autorizada por este rascunho.

## Incompatibilidade a resolver antes de uma implementação de pagamento

A branch Work \`feat/favorites-billing-integration\` e o PR #16 apresentam **R$ 4,90/mês** e teste de 7 dias (quando elegível), com backend que aceita apenas compras de teste. A decisão mais recente nesta conversa de planejamento é **R$ 5,00/mês** e **R$ 55,00/ano** para fundadores. Estas alterações **não** mudam produto na Play, widget de compra, backend, contrato da API nem o controle de elegibilidade. **Não ativar cobranças reais** antes de reconciliar os preços, configurar planos oficiais na Play e testar o comportamento integral da assinatura mensal/anual.

## Textos sugeridos para os termos (minuta, não publicação)

### Escopo
O Rocha+ oferece, na fase inicial, acesso por aplicativo a conteúdos de TV aberta cuja disponibilização seja autorizada. A eventual inclusão de filmes e séries dependerá de viabilidade técnica, financeira e dos direitos de transmissão. Não há prazo garantido para essa expansão.

### Assinaturas, cobrança e renovação
Antes da compra, apresentar o plano efetivamente disponível na Google Play, o valor total, moeda, período de cobrança, política de renovação, o fim do eventual teste gratuito e como cancelar. A oferta exibida pela Play na confirmação da compra é a referência operacional para a cobrança, sujeita às normas de defesa do consumidor. Cancelar impede renovações futuras conforme a política da loja, sem suprimir direitos legais a reembolso e a informações.

### Regra de fundador
Assinaturas elegíveis iniciadas no período fundador receberão o benefício de manutenção do preço de sua modalidade, enquanto atenderem às condições contratuais claras e às possibilidades técnicas da Google Play. O preço especial não significa que o catálogo futuro esteja disponível no presente. Informar a data de corte, modalidades, prazo de manutenção, efeito da troca/cancelamento, inadimplência, pausa, retomada, migrações obrigatórias e encerramento de oferta ANTES da contratação. O valor da próxima renovação será mostrado nas interfaces pertinentes.

### Proteção do consumidor
Não incluir cláusulas de renúncia antecipada a reembolsos legais, exclusão absoluta de responsabilidade, alteração unilateral sem transparência, ou adesão compulsória a futuro plano mais caro. Mudanças comerciais devem observar legislação brasileira aplicável e normas da Play.

### Privacidade (estrutura obrigatória a completar)
Documento separado deve informar controlador e contato, finalidades e bases legais dos dados, categorias de dados efetivamente usados, serviços de autenticação, pagamentos e terceiros, retenção, proteção, compartilhamentos, direitos LGPD, canal para exercício de direitos e data de atualização. A mera aceitação dos Termos não é consentimento genérico para todos os tratamentos. Usar informação verdadeira verificada no código e contratos.

## Interação de aceite

- Exibir links para Termos, Regulamento Fundador e Política de Privacidade antes da confirmação.
- O campo de ciência/aceite, quando necessário e juridicamente apropriado, deve ser desmarcado por padrão.
- Registro persistente futuro: UID, identificador e hash da versão dos termos, data UTC, plano, mecanismo de aceite e origem, evitando armazenar dados desnecessários. Planejar regras de acesso e retenção.
- A prévia HTML contém apenas um **aceite simulado no navegador**, sem armazenamento nem pedido de compra.
- **Nunca** conceder assinatura com base apenas em um checkbox. Compra e entitlement devem ser validados no backend contra a Google Play.

## Escopo deste PR
- Novo \`web/assinaturas/index.html\`: layout responsivo independente; não altera Flutter.
- Este documento como referência para o Work e para revisão legal.
- Não há link público hospedado; sem alterações em produção, Firebase ou pagamentos.

## Checklist antes de publicação comercial
- [ ] Confirmar preço mensal fundador **R$ 5,00** versus candidato existente **R$ 4,90**.
- [ ] Aprovar os preços e condições de mensal/anual fundadores e pós-expansão.
- [ ] Revisão jurídica dos Termos, Política de Privacidade e Regulamento.
- [ ] Definir data de corte e regras de perda/recuperação do preço fundador.
- [ ] Configurar produtos/base plans e eventuais preços legados no Google Play.
- [ ] Conferir a exibição da oferta real, elegibilidade do teste grátis e cancelamento.
- [ ] Testar compras em licença de teste, restauração, renovação, falhas e controle antifraude.
- [ ] Registrar o aceite por versão no serviço adequado.
- [ ] Preservar beta gratuito e isolamento da build/PR do Work; só ativar produção após autorização expressa.
