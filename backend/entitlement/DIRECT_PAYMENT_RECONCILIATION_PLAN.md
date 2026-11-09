# Plano de reconciliação de pagamentos avulsos (somente laboratório)
Data: 2026-10-26. Status: BLOQUEADO PARA ESCRITA OFICIAL.

## Evidências existentes e limites
- Diagnóstico somente leitura: Actions 40351814361. Foram reportados dois pagamentos Mercado Pago `regular_payment` aprovados (mensal e anual), mas `rochaSparkAccounts.paidUntil` permanece nulo.
- A prévia `direct_payment_preview.mjs` verifica identidade, recebedor, moeda, valores, aprovação, estorno e duplicação na entrada, mas declara `existingPaymentLedgerChecked: false` e `readyToApply: false`.
- O serviço experimental `service.mjs` já usa `recordKey([provider, transactionId])` e `store.transact` com exclusividade global, repetição idempotente, auditoria e estorno. Esse serviço **não é** uma integração comprovada com `rochaSparkAccounts` oficial.
- CI de Android não equivale a teste de login/assinatura no aparelho. Não interpretar aprovação de testes unitários como liberação da conta.

## Divergências que bloqueiam aplicação
1. **Política temporal:** a prévia acumula 1 + 12 meses por calendário UTC a partir da aprovação; `service.mjs` soma `days * 86_400_000` a partir da confirmação administrativa. Uma importação pode produzir expiração diferente. Escolher UMA regra e testá-la antes da vinculação.
2. **Fonte de verdade:** identificar se há ledger já persistido em `rochaSparkAccounts`, nas coleções de pagamentos experimentais ou em outro sistema. `paidUntil: null` não comprova ledger vazio.
3. **UID:** a leitura do diagnóstico encontra o documento pelo UID numérico do provedor Google, enquanto o serviço usa Firebase Auth `uid`. Confirmar vínculo e esquema, sem pressupor que as chaves sejam iguais.
4. **Reembolsos e chargeback:** consultar estado atual da transação no provedor imediatamente antes de qualquer aplicação. Definir política de estorno parcial.
5. **Concorrência e replay:** reservar chave única global `mercadopago:<paymentId>` e gravar ledger + direito + auditoria na mesma transação Firestore. Reexecução deve retornar `already_processed` sem estender a data.
6. **Escopo:** jamais executar a migração usando credenciais de produção durante homologação. `rocha-plus-homologacao` e `rocha-plus` são projetos distintos.

## Plano de execução sem risco
- [ ] Leitura **somente leitura** de índices/ledgers e configuração de acesso. Minimizar dados pessoais nos relatórios.
- [ ] Reconciliação das duas IDs com evidência do provedor; não solicitar novo pagamento.
- [ ] Aprovar política de duração incluindo a relação entre mensal e anual.
- [ ] Implementar planejador puro de importação com `dryRun: true` por padrão e rejeição por falta de ledger completo.
- [ ] Testes: mesmo pagamento duas vezes, dois workers simultâneos, cross-account, estorno/chargeback, expiração, falha parcial, diferença UID e relógio.
- [ ] Testar transação de gravação somente com fixtures e Firestore de homologação devidamente autorizado.
- [ ] Verificar no APK experimental bloqueio, login, vencimento, player e Cast com assinatura simulada.
- [ ] Solicitar autorização específica antes de qualquer gravação no Firebase oficial.

## Restrições preservadas
Não alterar `main`, APK oficial, preços, transações reais, `paidUntil` oficial, permissões ou segredos. Este documento não autoriza liberação automática.