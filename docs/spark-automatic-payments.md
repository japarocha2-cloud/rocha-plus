# Pagamentos recorrentes no APK Spark 4005

## Estado

Código preparado e testado com transações simuladas. Ainda não publicado como
serviço ou executado contra o Firestore real. O pagamento 184246702490 de R$ 4,90
foi confirmado pela API entre as contas de teste 3717765439 e 3717765441; não libera
uma conta real. O provedor retornou `live_mode=true` nesse teste, por isso o
recebedor exato também precisa ser validado.

`spark_recurring_store.js` reaproveita o ledger e as verificações do serviço
recorrente. Após consultar assinatura, fatura e pagamento, projeta a validade em
`rochaSparkAccounts/{googleSubject}.paidUntil`, que o APK congelado já lê.

- Exige recebedor real `1981204845`, modo live, Google verificado e documento Spark
  existente. Não concede outro teste. O prazo HTTP/TV também é limitado ao Spark.
- O primeiro vínculo exige o mesmo e-mail verificado no Google e no Mercado Pago.
  Assinatura autorizada sem fatura paga não concede acesso. Ciclos repetidos não
  somam meses; mensal cobre um mês civil e anual cobre doze.
- Estorno, chargeback, mediação e reembolso parcial removem o ciclo correspondente
  ao receber webhook ou na próxima reconciliação. Cancelamento conserva o já pago.
- Preserva a validade manual anterior como piso. Alterar `paidUntil` externamente
  após adoção interrompe a projeção para revisão, sem desfazer revogação manual.
  Pagamentos já confirmados pela ferramenta manual exigem migração explícita.
- Vínculos exclusivos impedem transferir assinatura para outra conta. Recriar UID
  com vínculo existente exige revisão; não migra identidades automaticamente.
- Não modifica favoritos, aceite ou início do teste. Uma falha depois de gravar o
  ledger pode ser recuperada na próxima passagem; não prova ausência de alterações.

## Runner em servidor confiável

Nenhuma hospedagem, conta paga, credencial ou agendador foi criado. Firestore
Spark permanece; Cloud Functions no Spark não é o caminho de ativação.

Usar Node 22, dependências de `billing/package-lock.json`, Firebase Admin via
Application Default Credentials e token de produção em `MP_ACCESS_TOKEN` no
ambiente seguro. Nunca colocar tokens no APK, Git, linha de comando ou conversa.
Os IDs dos dois planos comerciais ainda precisam ser conferidos pela API.

Diagnóstico somente de leitura (recebedor, planos e prontidão da conta):

```bash
node billing/tools/reconcile-spark-payments.mjs --project rocha-plus \
  --uid FIREBASE_UID --collector 1981204845 \
  --monthly-plan MONTHLY_PLAN_ID --annual-plan ANNUAL_PLAN_ID
```

Adicionar `--apply` executa uma passagem real. Usar `--all` em vez de `--uid`
percorre no máximo mil usuários, em páginas de cem; ignora contas sem documento
Spark. Retorna somente contagens, sem e-mails ou tokens. A prontidão não simula
pagamentos nem comprova vínculo. Falhas parciais podem ocorrer após gravações.

O APK 4005 não chama o endpoint de cobrança: um processo confiável precisa executar
passagens periódicas para descobrir a primeira assinatura pelo e-mail verificado.
A frequência depende das cotas e do volume de assinantes. Não há latência garantida
sem agendador ativo. A atualização do aplicativo e reprodução precisam de teste físico.

O flag `ROCHA_SPARK_PAYMENT_SYNC=true` habilita a mesma projeção no servidor HTTP
existente, se publicado em infraestrutura autorizada. O padrão é false. Webhooks
assinados atualizam somente vínculos já estabelecidos; o runner descobre os novos.
Não configurar webhook para URL ainda não publicada.

## Ativação pendente

1. Credencial Mercado Pago do recebedor real e IDs dos dois planos comerciais.
2. Credencial Firebase Admin e servidor autorizado para executar o runner.
3. Diagnóstico, primeira passagem conferida e agendamento.
4. Teste físico: pagamento libera A, não B; repetição conserva validade; estorno
   retira apenas o ciclo administrado; reinstalação não renova teste.

Os testes cobrem o serviço, ledger e projeção: mensal, anual, concorrência,
repetição, pendência, autorização sem pagamento, estorno, reembolso parcial,
cancelamento, falha de API, conflito de contas, validade manual, revogação e
rejeição das contas de teste. Não equivalem a execução real ou teste físico.
