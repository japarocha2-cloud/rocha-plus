# Confirmação administrativa de pagamento no APK Spark

O APK 4005 aprovado permanece congelado. Ele já lê `paidUntil` em
`rochaSparkAccounts/{googleSubject}`. O comando abaixo permite registrar uma
fatura realmente paga nesse documento, após conferência administrativa na API
do Mercado Pago. Não exige alteração do APK ou migração para Blaze.

## Estado e limites

- Implementado e testado com respostas simuladas. Ainda não executado com
  credenciais ou pagamentos reais; não representa integração publicada.
- É uma ferramenta administrativa, não um endpoint acessível pelo aplicativo
  nem um serviço automático. Exige Firebase Admin autorizado e token Mercado
  Pago do recebedor no processo seguro do administrador.
- Não cria planos, assinaturas ou cobranças; não modifica contratos existentes.
- Exige conta Firebase ativa, e-mail verificado igual ao pagador e identidade
  Google estável. E-mails diferentes ou referências externas de outro sistema
  exigem outro procedimento de comprovação; não são associados automaticamente.
- Confere assinatura, fatura e pagamento obtidos pela API: recebedor, plano,
  pagador, valor, moeda, modo de produção e período. Autorização de recorrência,
  promessa de pagamento ou captura de tela não são pagamento confirmado.
- Só registra um ciclo aprovado, vigente e sem estorno. Preserva teste, aceite,
  favoritos e eventual período pago mais longo. Não cria um teste novo.
- Pagamento e assinatura têm vínculos exclusivos por identidade Google.
  Repetições ou chamadas concorrentes não somam meses; uma confirmação já
  registrada não restaura acesso revogado por um administrador.
- As duas novas coleções administrativas são negadas aos clientes pelas regras
  publicadas, que só autorizam favoritos e o documento Spark individual.
  Não ampliar permissões do aplicativo para usar esta rotina.

## Execução

Usar Node 22 e instalar as dependências de `billing/package-lock.json`.
As credenciais Firebase Admin usam Application Default Credentials. O token do
Mercado Pago é lido de `MP_ACCESS_TOKEN`, nunca da linha de comando, do APK,
do repositório ou da conversa. Preencher os IDs administrativos confirmados.

Primeiro, diagnóstico sem gravação:

```bash
node billing/tools/confirm-spark-payment.mjs \
  --project rocha-plus --uid FIREBASE_UID \
  --subscription MP_SUBSCRIPTION_ID --invoice MP_INVOICE_ID \
  --collector MP_COLLECTOR_ID \
  --monthly-plan MP_MONTHLY_PLAN_ID --annual-plan MP_ANNUAL_PLAN_ID --live
```

Após conferir o diagnóstico, repetir com `--apply`. A rotina consulta novamente
os recursos do provedor e verifica vínculos em transação antes de gravar.
`--apply` exige `--live`; testes não podem liberar acesso na base real.

`dry-run` não grava; `applied` confirma a transação; `already-recorded` significa
que a fatura já foi registrada e nenhuma liberação foi repetida. Uma falha com
`outcome: not-confirmed` pode ter ocorrido após um commit: consultar o estado
antes de concluir se houve alteração. Nenhum token é exibido no diagnóstico.

## Validação física e automação pendentes

Após uma aplicação real confirmada, verificar a conta correta no APK 4005,
usar a atualização de acesso disponível ou reabrir o app e confirmar a
reprodução. Uma segunda conta não pode ser liberada por esse pagamento.

Esta rotina é somente concessão administrativa. Não revoga automaticamente
estornos posteriores nem acompanha novas cobranças. Não é suficiente para
anunciar desbloqueio automático ou comercializar sem operação administrativa.
Automação depende de acesso Mercado Pago, credenciais, webhook publicado,
reconciliação de renovação/estorno e uma autoridade comum para Spark e TVs.
O serviço recorrente existente em `billing/recurring_service.js` deve ser
reaproveitado nessa etapa; ele ainda grava outra coleção e não sincroniza
sozinho a validade usada pelo APK Spark.

O teste de laboratório de dois minutos não substitui a confirmação de bloqueio
persistente após reabrir, reinstalar e trocar de aparelho.
