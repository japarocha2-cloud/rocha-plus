# Incidente P0 — reconhecimento de pagamento — 03/11/2026

> Atualização posterior: a tentativa #2 executou a leitura privada com sucesso. A investigação também confirmou contratos recorrentes referenciados nos recibos, sem payer_email. Consulte o [relatório de correção e simulação](2026-11-03-incidente-pagamento-correcao.md). As seções abaixo preservam o estado da primeira entrega; a pendência de configurar os seletores privados foi resolvida.

Status: FASE 1 PARCIAL. Pagamento confirmado novamente no provedor; restauração de acesso NÃO executada. Fases seguintes aguardam fechamento do diagnóstico.

## Investigação e evidência atual

- Provedor identificado: Mercado Pago. Firebase oficial: rocha-plus.
- Consulta nova, somente leitura, em 03/11/2026 às 17:59 UTC: [Actions 41689468076](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41689468076).
- Dois pagamentos selecionados pelo diagnóstico histórico foram novamente consultados individualmente na API oficial. Ambos: approved/accredited, live_mode=true, BRL, zero estorno informado, pagador correspondente à conta investigada e recebedor correspondente à conta esperada.
- Firebase Authentication: conta encontrada, e-mail verificado, conta habilitada, Google vinculado. Documento Spark encontrado; paidUntil reportado como nulo e paidAccessCurrent=false.
- A pesquisa de recorrência não encontrou payer_email correspondente. Os pagamentos confirmados são regular_payment. Isso não prova inexistência de outros contratos e não autoriza cobrança ou renovação automática.
- A consulta também distingue um pagamento estornado. Ele NÃO deve ser usado para conceder acesso.
- Dados pessoais, IDs financeiros e UIDs completos não são repetidos neste relatório público. A evidência histórica já existente foi consultada; não houve envio de credenciais ao repositório.

## Diagnóstico comprovado e limites

O registro Spark consultado não contém período pago reconhecido, apesar dos pagamentos aprovados. Essa é a falha de reconhecimento observada no backend. Ainda não foi comprovada a cadeia completa de eventos/webhook que levou à ausência do direito.

A rotina periódica existente usa MP_ACCESS_TOKEN e um recebedor diferente daquele verificado para estes pagamentos. O diagnóstico específico usa MP_RECEIVING_ACCESS_TOKEN. O código da rotina periódica trata planos/assinaturas recorrentes; sua consulta padrão de prontidão não reconcilia pagamentos avulsos.

A execução periódica [41688262954](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41688262954), hoje às 17:51 UTC, terminou com checked=7, reconciled=0, previewed=0. Seu sucesso NÃO comprova reconhecimento dos pagamentos investigados. Seus 136 testes aprovados são evidência histórica de CI, não testes executados nesta entrega.

Referências de código inspecionadas:
- billing/tools/reconcile-spark-payments.mjs na revisão 86bdabe25cf53f74d59c1061d95e500ee9fb4f6b: recebedor legado fixo, fluxo recorrente, modo padrão somente leitura.
- lib/src/billing/spark_billing_repository.dart na mesma revisão: consulta rochaSparkAccounts pela identidade Google e exige paidUntil futuro para reconhecer pagamento; abrir checkout não concede assinatura.
- functions/index.js na base d3c56ab6551c844fcb27501ba326d0c9a5cff641: backend experimental consulta entitlements pelo Firebase UID. Não comprova qual endpoint está implantado ou em uso no aparelho.
- backend/entitlement/DIRECT_PAYMENT_RECONCILIATION_PLAN.md: divergências conhecidas de identidade, ledger e regra temporal.

Firebase UID e subject Google não devem ser presumidos iguais. O diagnóstico financeiro existente seleciona a conta pelo e-mail e localiza o documento pela identidade Google vinculada, mas não expõe o UID nem verifica a sessão do aplicativo.

## Alterações e commits

Somente instrumentação experimental, sem correção comercial aplicada:
- 7f5da6e2ccb5011f5f9bd9aaa57b982d33c57358: .github/workflows/incident-payment-readonly-20261103.yml. Executa a revisão histórica auditada 6b7faf8a1b920427b64b5353ee2d17672b139648 com leituras Firebase e GETs Mercado Pago.
- 25afacb9b524ec5e52f13db2c0b0a3213f038438: backend/entitlement/diagnostics/incident_identity_readonly_20261103.mjs. Leitura adicional de identidade e caminhos exatos de registros; recebe seletores privados e publica somente fingerprints dos identificadores.
- 45ec3ef156bfac7ab7f84c888b2734330d283c84: .github/workflows/incident-private-identity-readonly-20261103.yml. Prepara execução com entradas privadas, checkout fixado, instalação sem scripts de dependências e nenhuma operação de escrita no banco.
- Este relatório é o quarto arquivo desta entrega; seu commit fica no histórico da branch.

## Verificações e resultados

- Consulta externa atual: concluída com sucesso, writes=0, accessGrantedByThisCheck=false, appLoginTested=false.
- node --check no diagnóstico genérico: aprovado. Isso valida sintaxe, não integração externa.
- Revisão do diagnóstico genérico: sem e-mail ou IDs financeiros fixos; chamadas Firebase de leitura, sem transação ou gravação.
- [Actions 41689887013](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41689887013): os passos de diagnóstico de identidade foram SKIPPED por ausência das entradas privadas. O job verde NÃO significa identidade/ledger auditados.
- Não foram executados testes de login no aparelho, emulador BRS ou Roku físico.

## Pendências indispensáveis

1. Configurar privadamente no GitHub Actions INCIDENT_TARGET_EMAIL e INCIDENT_PAYMENT_IDS_JSON (array JSON de IDs em strings) para a conta e transações já selecionadas. Não enviar tokens ao chat nem publicar seletores no Git. As credenciais de Firebase e recebedor já funcionaram na consulta financeira.
2. Reexecutar o job privado após configurar as entradas. Ele confere fingerprints de identidade, datas e associação nos caminhos conhecidos de entitlements, claims, eventos, registros billing e projeção Spark. Ele declara ledgerScopeComplete=false: inventário de outros backends ainda requer revisão.
3. Conferir o Firebase UID contra a sessão efetiva do aplicativo, versão instalada, projeto Firebase e endpoint usado. Não solicitar senha nem publicar ID token.
4. Inspecionar configuração implantada e logs de webhook/sincronização para determinar o evento e a falha exatos. Ainda não há evidência de webhook rejeitado, duplicado ou ausente.
5. Confirmar contratação, início/fim e política de relação entre os pagamentos mensal e anual. A data de aprovação foi confirmada; ela não estabelece sozinha a regra contratual de vigência. Nenhum vencimento ou próxima cobrança foi inventado.

## Caminho seguro de recuperação

Após completar os itens acima, preparar na branch experimental um plano somente leitura que associe cada pagamento confirmado ao Firebase UID e ao documento de acesso realmente usado no aplicativo. Reconsultar o estado financeiro imediatamente antes da aplicação.

A correção deverá usar chave única de pagamento, controle de concorrência e gravação atômica de registro, direito e auditoria; repetição não pode somar prazo. Pagamento estornado, pendente, recusado ou ciclo expirado não pode conceder acesso. Testar também conflito entre contas e revogação.

Apresentar UID identificado por canal adequado, registro-alvo, transações elegíveis, regra temporal, datas resultantes e impacto exato; solicitar autorização específica ANTES de modificar direitos em produção ou reprocessar eventos reais. Não há pedido de liberação comercial nesta entrega, pois o plano ainda não está completo.

## Preservação

Nenhum deploy, merge, APK/ZIP publicado, cobrança, alteração de direito comercial, privilégio ADM, reprodução autorizada, catálogo, visual oficial, versão congelada ou aplicativo dos avós alterado. Trabalho restrito à branch incident/payment-recognition-20261103. Nenhuma outra fase foi declarada concluída.
