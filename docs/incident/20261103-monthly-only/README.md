# P0 — decisão mensal exclusiva, preparação sem aplicação

Proprietário informou devolução externa porPix do valoranual. Relato aceito como decisão, comprovante ainda não conciliado. Não é estornoMercadoPago; nenhum segundo reembolso proposto. Manter exclusivamente mensal conforme ordem, sem alterar contratos nesta etapa.

Base f9ece2e1fa2b4e8371e20d1eeddb8a6c6608fb37. Histórico e diagnósticos anteriores preservados. Não há novos bindings privados neste executor; não se exportaramSecretsActions nem removeu guarda private-work-execution-only. IDs exatos dos contratos não puderam ser recuperados: logs históricos mantêm somente evidência sanitizada, sem IDs. O ID do pagamento anual não será usado como preapproval_id. Fonte para resolução: recibo.metadata.preapproval_id ou point_of_interaction.transaction_data.subscription_id, depois GET do contrato validandoid/recebedor/payer_id/agenda. Novo prepareMonthlyOnly usa apenas esse resolvedor e métodos de leitura injetados. **Nenhum ID inventado, cancelamento ou consulta real nova executada.**

## Prévia das operações, não aplicável ainda

| Operação | Antes disponível | Depois proposto |
|---|---|---|
| Cancelamento da recorrência anual exata | Contratoauthorized na última consulta histórica; ID/estado atual privados não recuperados | PreviewPUT /preapproval/<IDanualverificado>, candidato statuscancelled; conferir enum naAPI atual/SDK antes de autorização. Se já cancelado e vínculo validado, NO_OP. Preservar recibos/histórico; nenhumrefund |
| Contrato mensal | authorized histórico; próxima cobrança prevista20/11/2026 | Nenhuma alteração no provedor; manter contrato/valor/agenda |
| DireitoSpark | paidUntil historicamenteausente; valoresatuais/subject/sessão desconhecidos | Somente pagamento mensal elegível; anual excluído mesmo se continuarapproved noMP |
| Ledger/projeção/auditoria | Existência/versões atuais pendentes | Umledger mensal +updateSpark +projeção +auditoria =4documentos, sem somar anual |
| DevoluçãoPix externa | Relato do proprietário, comprovante não conciliado | Anotação no relatório; nenhum campoMP de estorno alterado |

Candidato mensal histórico do primeirociclo:20/10/2026 22:30:38UTC a20/11/2026 22:30:38UTC (19:30:38BRT). É agenda retornada pelo contrato na consulta41693005627, não paidUntil concedido automaticamente. Revalidar recibo/status/ausência deestorno e revisar cobertura mensal antes de qualquer proposta final. Proposta anual anterior está **SUPERADA** pela decisão mensal exclusiva e não deve ser usada para restaurar acesso. Não alongar prazo usando anual devolvido.

Alterações de código isolado: monthly_only_preparation.mjs gera préviaread-only, separa devoluçãoexterna deMP, impede mistura de contratos/contas, preservamensal e excluianual; ausência de métodos de escrita/cancelamento/refund. recovery_changeset_preview.mjs deixadeexigir doisrecibos, aceita1a5 e calcula expectedDocumentCount conforme novosledgers+3. Assim a prévia de um mensal tem4documentos; a antiga de2continua5. Nenhum adaptadorfinanceirodeprodução alterado.

## Identidade, duplicidade e limites

Build538congelada temversionCode3538, Spark e automatic_paymentsfalse. Instalação/identidade atual da cliente ainda não comprovadas, conforme confirmação do proprietário. Preservar sessão e obter ConfiguraçõesAndroid →Apps→Rocha+→Informações; comparador dehash e coletor anteriores estão prontos. Semlogout/reinstalação/limpeza. Não escreverSpark se backend real foroutro.

Doiscontratos não são causa-raiz isolada comprovada. Há falhas históricas de descoberta porpayer_email ausente e projeção de direito, além de sincronizaçãoautomática desativada; a coexistência criou ambiguidade de cobertura e risco de duasrecorrências. Não há evidência de que o gate bloqueie por simplesmente contar doiscontratos. Entrega do webhookimplantado permanece sem confirmação, consultas anteriores403. Não repetir as mesmasconsultas como se novas fossem.

## Testes e procedimento posterior

7novostestesfixtures aprovados localmente: destinoanualobtido decontrato/nãopagamento, mensalintacto, Pixnãoviraestorno, exclusãoanual, preparaçãoidempotente, mensalestornado/pagadorerradonegados, prévia4documentos semtransação real e anualjá canceladoNO_OP. Testes anteriores de pagamento/estorno/concorrência preservados, 26financeiros e8comparação noCI41719572181. [CI41721373830](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41721373830) concluído success:7novos+4regressões canônicas da prévia, zerofalhas, semSecrets. Código02608f4187d1d9db1ae265456bd38bc866a3724c.

1. Operador privado autorizado captura IDs dos dois contratos a partir dos recibos, estadosatuais e vínculoexato; compara comrecibos/recebedor/payer_id e preserva comprovantes.
2. Conciliar comprovantePix externo como documento separado, sem converter statusMP e sem fazer outroreembolso.
3. Confirmar APK/backend e identidade da mesma sessão; executar leitura privada atual deSpark/ledger/projeção/auditoria. Não reutilizar baselineanterior desconhecido.
4. Revisar período mensal e produzirchangesetfinal de4documentos combefore/after/updateTimes, operador/digest. Preparar cancelamentoanual comIDvalidado e contrato mensal explicitamente excluído de qualquer mutação. A autorização futura deve separar essasduas operações; nenhuma autorizada agora.
5. Só após autorização específica e revalidação, operador poderá cancelar recorrênciaanual e/ou aplicarchangeset mensal conforme operações aprovadas. Não há executor de escrita novo nesta entrega.

Status **VERMELHO operacional**: acesso não restaurado; preparação pronta para completar dados privados, IDs e baseline. Sem cobrança/cancelamento/estorno/assinaturas/Firebase/IAM/produção/Oficial/Roku/LAB714/avós/merge/deploy/APK. Documentos anteriores de recuperaçãoanual são históricos, superados nesta decisão. A prévia privada preview-historical-NOT-APPLICABLE.json também não deve ser usada como plano mensal.

Referência API consultada: https://www.mercadopago.com.br/developers/pt/reference/online-payments/subscriptions/update-preapproval/put . Documentação de gestão menciona cancelamento porPUT; a enum deve ser revisada na integração operacional, sem assumir tradução do texto como esquema validado. Nenhuma requisição de mutação enviada.


Precondição adicional da préviafinal: se já houver créditoconcedido peloanual ou paidUntilfuturo, não reduzi-lo nem preservá-lo silenciosamente como se fosse mensal. Capturar antes real e preparar decisão específica deajuste/rollback para revisão, sem mudar nestaetapa.
