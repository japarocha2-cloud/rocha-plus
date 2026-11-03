# Incidente P0 — correção experimental e proposta de recuperação
> Continuidade: [sessão instalada, prévia integral, execução privada e rollback](2026-11-03-sessao-previa-restauracao.md). Nenhuma autorização comercial foi concedida nessa etapa.

Data: 03/11/2026. Branch: incident/payment-recognition-20261103.
Estado: código e simulação preparados; NENHUMA restauração em produção executada.

## Causa comprovada e limites da conclusão

A tentativa #2 confirmou que o documento Spark existe, mas o campo paidUntil está AUSENTE (o diagnóstico financeiro anterior o representava como null). O trial já terminou. Nenhum dos registros de pagamento consultados existe. Firebase UID e subject Google são distintos.

A classificação regular_payment NÃO significa ausência de contrato recorrente. Os recibos possuem referência direta a contratos; a consulta individual confirmou recebedor, payer_id correspondente ao respectivo recibo e contratos authorized. O provedor NÃO retorna payer_email nesses contratos. Uma descoberta que exige coincidência de payer_email perde esses contratos, embora o pagamento seja válido.

A rotina periódica inspecionada usa credencial/recebedor e IDs de planos de outra integração. Seu modo padrão é uma consulta de prontidão, com zero reconciliações. No webhook inspecionado, topic=payment consulta authorized_payments, transforma as faturas em preapproval_id e só sincroniza assinaturas já vinculadas. Sem faturas/assinatura vinculada, pode responder received=true sem atualizar o direito. Essa é uma lacuna comprovável no código; NÃO é prova de que um webhook específico tenha sido entregue ou recebido com sucesso no ambiente implantado.

A prévia experimental existente ainda somava períodos mensal+anual automaticamente. Esse defeito foi corrigido: compras independentes não autorizam soma de vigências.

Portanto, o bloqueio imediato é o período pago não persistido no documento consultado pelo fluxo Spark. A investigação identifica falhas de descoberta/vínculo e uma prévia temporal incorreta; o histórico exato de entrega do webhook continua sem prova, pois as leituras de Cloud Functions e Cloud Logging retornaram HTTP 403.

## Evidências novas, sem dados pessoais fixos

- [Tentativa #2 — identidade e registros](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41689887013/attempts/2): executada, writes=0. A ausência de registros vale para os caminhos consultados, não para um inventário universal de sistemas.
- [Contratos e identidades do pagador](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41693005627): consulta individual das referências presentes nos recibos; payer_email ausente, payer_id correspondente, mensal e anual authorized, datas de início e próxima cobrança obtidas no provedor. Nenhuma cobrança criada/alterada/cancelada.
- [69 testes e simulação real somente leitura](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41693463861): 69 passaram, zero falhas; dryRun=true, writes=0, accessGranted=false. A proposta usa períodos independentes e o maior término válido, sem somar mensal e anual. requiresContractReview=true, readyForAuthorization=false.
- [Firestore Emulator: transações reais do SDK](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41694129959): projeto demo-rocha-recovery; provedor e identidades simulados; três execuções concorrentes produziram um registro de pagamento e uma auditoria; replay estável e rollback confirmados; productionWrites=0.
- Primeira execução do emulador [41693859456](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41693859456) falhou por caminho de regras fora do diretório do projeto. O caminho/configuração foi corrigido e a execução seguinte passou. Nenhuma regra foi reescrita: o workflow reutiliza a regra deny existente numa cópia efêmera.

Não confundir prova externa financeira, simulação com leituras reais, testes com fixtures e teste do aplicativo. Login da cliente, APK instalado e desbloqueio no aparelho NÃO foram testados.

## Fluxo inspecionado

1. Checkout histórico conduz ao Mercado Pago, onde o pagamento é aprovado.
2. O recibo retornado não contém external_reference de UID nem metadata de associação; possui referência ao contrato dentro de point_of_interaction.
3. O filtro por e-mail perde contratos sem payer_email. O contexto legado de recebedor/planos também não corresponde ao contexto financeiro validado.
4. A confirmação não está registrada nos caminhos consultados; não há projeção paga Spark.
5. O cliente Spark resolve Firebase UID autenticado para providerData.google.com.uid e lê rochaSparkAccounts pelo subject Google. Não usar Firebase UID como se fosse a chave desse documento.
6. O código LAB desta branch também contém outra consulta: SubscriptionAccess usa o Firebase UID em uma API de entitlements/central rights. Gravar apenas Spark não comprova restauração nesse outro backend. A versão/configuração efetivamente instalada ainda deve ser identificada.

## Correções e arquivos

Commit principal: 8a1595f7713d117e439614bd986a847bf00712e2.

- backend/entitlement/direct_payment_preview.mjs e teste: remove soma automática de mensal+anual; preserva o caráter de proposta sem autorização.
- regular_payment_contract.mjs e teste: resolve o contrato pela referência do recibo, exige coincidência de recurso/recebedor/payer_id/valor/moeda/status/agenda. Consulta limitada à recuperação do primeiro ciclo; não interpreta automaticamente qualquer renovação posterior como primeiro período.
- regular_payment_recovery.mjs e teste: exige identidade verificada, termos explícitos, inspeção dos registros conhecidos e nova consulta financeira. Simulação por padrão. Aplicação depende de verificador de autorização injetado, operador individual, UID, escopo, referência e digest da prévia. Termos não revisados permitem somente simulação.
- regular_payment_firestore.mjs: adaptador com dependências injetadas, sem conexão/escrita na importação. Reserva global do pagamento por ID, auditoria e atualização do documento Spark na mesma transação. Todas as leituras precedem escritas. Preserva trial, aviso e favoritos. Bloqueia conflito com registros legados, outra conta ou alteração manual posterior.
- diagnostics/incident_recovery_dry_run.mjs: executável somente leitura, sem flag apply. Não fornece o método de transação ao serviço e o conversor de timestamps de escrita lança erro. Recebe seletores por Secrets e omite IDs/e-mail/UID do resultado público.
- diagnostics/incident_provider_terms_readonly.mjs: consulta financeira/contratual oficial e tentativa sanitizada de leitura de configuração/logs.
- emulator/firebase.json e emulator/recovery.integration.mjs: isolamento de loopback/projeto demo e teste real de concorrência/rollback do SDK.
- Workflows novos: incident-provider-terms-readonly.yml, incident-recovery-dry-run.yml e incident-recovery-emulator.yml. Sem publicação de APK/ZIP ou deploy.

Commits adicionais relevantes:
- bedca439a4fb842bd77aa84f06335cb05887a1a5, 143efd18d78e1d46e121abc610b7b80511f233da, 5fca6f995228fb26e829a04d2376146f6c3be713: inspeção financeira/contratos e vínculo por payer_id.
- 0e730c276930a306f44186c883e921c668277f1b, 767351756316ef7e5f76a1fadf5a1a71a9bbf2b1, 7dd27e7d7365c1fdecd3233611af55e5b4cbd7bd: execuções somente leitura com revisões fixadas.
- 22543108726029295304cd1be6f4fe83620ab6d3: testes e simulação.
- 1451b6a912a42a1b9c4b567d5fe0b021ee0f9427, 4344e73b88736307017a971282dab41d65713456, 9f0fe427bbb6974d0cac1e26c6274369b1cb3cb4, c4520a8a9661a73d5e27aee01212dbe1d7db55d7: teste Firestore e ajuste de configuração do emulador.

## Testes

- 35 verificações locais dirigidas, aprovadas, incluindo os testes anteriores de prévia/planejamento/atomicidade e os 16 novos testes de contrato/recuperação.
- Suíte completa backend/entitlement no GitHub: 69 testes, 69 aprovados.
- Casos novos: contrato sem payer_email; calendário exato do provedor; ausência de termos; não acumular períodos; diferença Firebase UID/Google; pagamentos pendentes, recusados, estornados, chargeback, sandbox e estorno parcial; falha do provedor; conflito com outra conta/registro legado; autorização ausente; prévia obsoleta; revogação manual; repetição e execução concorrente.
- Emulador Firestore: concorrência e aborto real de transação confirmados com dados fictícios de teste. Não é uma prova de compra sandbox ou de login real no aplicativo.
- Nenhuma reprodução de canais foi habilitada por estes testes.

## Proposta concreta de restauração

Usar os períodos retornados pelos contratos como candidatos à revisão, sem acrescentar um ao outro. A simulação registra o término proposto e seu digest nos logs sanitizados. Datas exatas e seleção da cliente devem ser revisadas em canal apropriado, sem repetir seus identificadores no GitHub público.

Após conferir o cliente instalado e aprovar a interpretação contratual, a recuperação pontual proposta escreve atomicamente:
1. Dois documentos globais em rochaDirectPaymentLedger.
2. paidUntil e reconciledAt no documento Spark da identidade Google já vinculada à conta Firebase.
3. Um documento de projeção em rochaDirectPaymentProjections.
4. Um documento de auditoria em rochaDirectPaymentAudit.

Total esperado da primeira aplicação para os dois pagamentos: cinco documentos. Reexecução não soma prazo. Reconsultar recibos/contratos e os registros imediatamente antes de aplicar; mudanças exigem nova prévia/revisão. Não escrever em entitlements de outro backend para tentar compensar uma versão desconhecida.

## Autorizações e pendências exatas

- Identificar versão/pacote e configuração efetivamente usada no aparelho; comparar a sessão autenticada ao UID resolvido. Não pedir senha nem publicar ID token.
- Obter leitura de configuração implantada e logs: as consultas Cloud Functions/Cloud Logging retornaram 403. Validar APIs/IAM; quando aplicável, Cloud Functions Viewer e Logs Viewer para a identidade de diagnóstico, restritos ao projeto e escopo necessário. Isso não solicita permissão de implantação ou escrita.
- Revisar as regras atualmente implantadas para as novas coleções de registro/auditoria: clientes não podem escrever nelas. Edição/configuração do banco oficial e permissões do operador devem ser confirmadas antes de qualquer integração de produção.
- Revisar o contrato e a relação entre as duas recorrências authorized. A próxima cobrança segue o provedor; cancelamento, alteração de preço ou desativação de recorrência exigem autorização SEPARADA e não estão propostos para execução aqui.
- A autorização comercial necessária será específica: conta/UID verificados, dois pagamentos selecionados, períodos exatos aprovados, documento-alvo confirmado, digest da prévia atual, cinco documentos e referência de auditoria, com operador autenticado e escopo regular-payment-recovery. Não incluir cobrança, ADM, reprodução, alteração de trial, merge ou deploy.
- Não solicitar aprovação genérica para liberar a conta: confirmar os itens acima e apresentar a prévia final. A simulação atual mantém requiresContractReview=true.
- O módulo de recuperação NÃO foi ligado a endpoint, webhook ou scheduler. A integração operacional contínua de renovação/estorno e sua observabilidade ainda precisam ser validadas no ambiente correto. Recusar uma recuperação quando o pagamento está estornado não substitui um monitor que revogue um direito já concedido após um estorno futuro.

## Preservação

Produção: zero gravações. Nenhum merge, deploy, cobrança, privilégio ADM, publicação de APK/ZIP, mudança visual, alteração de Roku, catálogo, versão congelada ou aplicativo dos avós. A restauração no aparelho permanece pendente; não declarar incidente resolvido.
