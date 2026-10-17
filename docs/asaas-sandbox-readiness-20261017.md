# Asaas — confirmação de pagamentos em preparação

## Problema encontrado

A branch feat/mobile-asaas-550-20261015 (f0f0fb68cb2a6dda6e63aac7e30752f7ee252129) contém uma variante visual preparatória: R$ 5,50 mensais, botões de contratação desativados e bloqueio de checkout Mercado Pago. Não implementa cobrança ou liberação automática Asaas. A APK 4204 usa com.rochaplus.app e não deve ser instalada sobre o congelado para estes testes.

## Código preparado nesta etapa

- Cliente servidor GET para payments e subscriptions, com host Asaas fixado por ambiente, timeout, proteção contra redirecionamento da credencial e erros sem dados privados.
- Verificação de authToken do webhook com comparação exata; usa o cabeçalho asaas-access-token, separado da chave access_token da API.
- Validação mensal R$ 5,50: cobrança, assinatura, cliente, referência opaca criada pelo servidor, método de pagamento e período precisam coincidir com um vínculo confiável criado anteriormente.
- O corpo do webhook não determina preço, dono da conta, status financeiro ou validade: os recursos são consultados novamente na API autenticada.
- Pagamentos pendentes não geram acesso. CONFIRMED/RECEIVED registram somente o período pago. Estorno, contestação e exclusão revogam a parcela de teste correspondente.
- Calendário mensal com ajuste de fim de mês, sem adicionar outros sete dias gratuitos.
- Eventos duplicados e confirmações concorrentes não adicionam meses. Uma resposta antiga não desfaz um estorno nem um snapshot pendente apaga uma confirmação.
- Ledger somente de sandbox, sob rochaAsaasSandboxBindings, rochaAsaasSandboxUsers e rochaAsaasSandboxEvents. Não escreve em contas Spark, favoritos ou registros Mercado Pago.
- Reconciliação desativada por padrão; a tentativa de usá-la em produção é rejeitada. Não há exportação nova em billing/index.js e nenhum endpoint foi publicado.
- A suíte padrão de cobrança inclui os novos testes. Workflow próprio testa Node 22 e publica os logs sem credenciais.

Os testes usam respostas sintéticas do provedor e o simulador de transações já usado no repositório. Isso não comprova uma chamada real ao Asaas ou uma transação real no Firestore. O módulo é preparação de servidor, não integração concluída no aplicativo.

## Próximas dependências concretas

1. Configurar conta e credenciais privadas de sandbox, separadas das de produção; não enviar chaves pelo chat ou incluí-las no APK.
2. Implementar o checkout hospedado com identidade autenticada e persistir os vínculos server-side antes de aceitar confirmações. Um link genérico compartilhado não basta; não vincular assinaturas por e-mail informado no pagamento.
3. Registrar cada cobrança gerada pelo Asaas em seu período correto, incluindo renovações, sem permitir que o cliente envie validade ou UID de outro usuário.
4. Publicar o recebimento/filas de webhook de sandbox com autenticação e testar entrega/repetição, falha temporária de API, pagamento, recusa, renovação e estorno na API real. O handler atual processa sincronamente e não está pronto para receber tráfego de produção sem a fila durável recomendada pelo provedor.
5. Definir e validar a projeção de pagamentos Asaas para o acesso do app preservando trial, aceite, acessos manuais e o período pago em outro provedor. Hoje nenhum registro de sandbox libera o app.
6. Preparar APK Asaas com identificador experimental separado e aproveitar a correção de shared_preferences_android 2.4.28 já validada. Não reutilizar cegamente o workflow 4204, que usa a identidade de produção.
7. Após aprovação cadastral e validação sandbox, verificar configurações e autorização operacional de produção; testar a cadeia completa e a troca de contas no aparelho antes de divulgar.

Nenhuma cobrança, plano remoto, chave, regra Firestore, login, assinatura existente, identidade visual, produção ou APK 4005 foi modificado nesta etapa.

## Fontes primárias consultadas em 17/10/2026

- https://docs.asaas.com/docs/receive-asaas-events-at-your-webhook-endpoint
- https://docs.asaas.com/docs/webhook-para-cobrancas
- https://docs.asaas.com/reference/recuperar-uma-unica-cobranca
- https://docs.asaas.com/reference/recuperar-uma-unica-assinatura
- https://docs.asaas.com/reference/create-new-subscription
- https://docs.asaas.com/docs/cobrancas-via-cartao-de-credito

Criar assinatura ou redirecionar após checkout não comprova pagamento. Os estados CONFIRMED e RECEIVED também se distinguem pela disponibilidade do saldo; não tratar a confirmação de acesso como dinheiro já disponível para repasse de comissão.
