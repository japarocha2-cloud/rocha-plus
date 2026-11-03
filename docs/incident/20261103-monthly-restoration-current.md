# P0 — estado vigente: anual cancelado, restaurar somente mensal

Atualização de03/11/2026, conforme confirmação visual do proprietário noMercadoPago: assinatura ANUALcancelada e MENSALem dia. Devoluçãoanual porPix externo informada pelo proprietário; comprovante não conciliado nesta execução. Essas informações não são uma nova consultaAPI. Não classificar pagamentoanual como refunded/estornado noMercadoPago. **Não executar nem solicitar novo cancelamento ou reembolso.**

A preparação antiga de cancelamentoanual está superada paraesta cliente. Preservar contratos/recibos/histórico e o mensal, sem alterar preço, agenda ou cobrança. Próxima cobrança mensal prevista20/11/2026 permanece referência histórica, sem alteração ou confirmação de vigência automática.

## Caminho operacional que falta

Não foi identificada conexão privada utilizável no diagnóstico anterior: cinco bindings ausentes e lista de ambientesCloud vazia. Nesta atualização não se repetiram consultas de infraestrutura, dados ou403; não há nova leitura privada nem alegação de acesso restabelecido.

O proprietário/administrador do hostprivado autorizado precisa disponibilizar os bindings EXISTENTES por cofre/integração do processo: FIREBASE_SERVICE_ACCOUNT_JSON, MP_RECEIVING_ACCESS_TOKEN, INCIDENT_TARGET_EMAIL, INCIDENT_PAYMENT_IDS_JSON e EXPECTED_RECEIVING_MERCHANT_ID. Não enviar valores aochat, exportarSecretsActions ou criar chave/IAM/recurso. A descrição de origem/escopo de cada um está no [procedimento operacional](20261103-operational-executor/README.md). IdentidadeGitHubActions não é automaticamente uma conexãoWork.

No checkout completo privado, comNode22+/npm ebindings jáconectados:

```sh
git fetch origin incident/payment-recognition-20261103
git checkout --detach c0eb9bf0313e7826991bdd64b2e365354c7b018e
(cd backend/entitlement && npm ci --ignore-scripts --no-audit --no-fund)
umask 077
export ROCHA_PRIVATE_REPORT_DIR="$(mktemp -d /tmp/rocha-monthly-readiness.XXXXXX)"
node backend/entitlement/diagnostics/incident_session_readiness.mjs
```

Este script lê ambos os recibos para validar vínculos, mas SOMENTE o mensal entra no planoSpark. Não possui execuçãoPUT/cancelamento/refund; consulta de anual não autoriza ação financeira. Qualquer campo de cancellationPreview eventualmente retornado é modelo histórico e NÃO deve ser executado, mesmo se contradizer a confirmação visual. Divergência deestado deve apenas ser registrada para revisão. Não bloquear o trabalho administrativo por pedido de novo cancelamento.

Saídasprivadas: readiness.private.json e before-images.private.json. Elas devem permitir conferir IDdo mensal, approved/status_detail, recebedor/pagador/moeda/valor, ausência de estorno e ciclo correto. Contratoem dia não substitui validação do recibo e cobertura. Calendário histórico do primeiro mensal:20/10/2026 22:30:38UTC→20/11/2026 22:30:38UTC, apenas candidato a revisar. Não acrescentar anual, criartrial ou renovar prazo por preço/statusvisual.

## Antes de sincronizar qualquer direito

1. Confirmar instalação: ConfiguraçõesAndroid→Apps→Rocha+→Informações, versão/origem e mensagem/horário do bloqueio, semlogout/reinstalação/limpeza. Build538conhecida temversionCode3538 e Spark, mas não está comprovada como instalação da cliente. Comparadorhash/coletor jápreparados; não reenviar perguntas comerciais respondidas.
2. Confirmar identidade da MESMAsessão, projeto e backend efetivo. Se não forSpark, parar a propostaSpark e mapear a fonte real; não gravar em múltiplascoleções para tentar desbloquear.
3. Conferir quatrodocumentos atuais e versões: ledger único do mensal, rochaSparkAccounts/GoogleSubject, projeção e auditoria. Imagensprivadas contêm before/afterTemplate; preservam trial/welcome/favoritos. IDToken não é enviado aochat nem copiado pela cliente.
4. Revisar cobertura mensal eprecondições. Se paidUntil anual jáexistir, não baixar nem reutilizar silenciosamente; apresentar esse caso comantesreal para decisão específica. Conferir duplicidades e estorno antes deautorizar.
5. Produzir manifesto privado completo comoperador individual, identidade, período mensal, before/after/updateTimes/digest e impacto limitado aos4documentos. Solicitar autorização específica SOMENTE para sincronização mensal; nenhum cancelamento fazparte dela.
6. Após futura autorização, operador revalida provedor e executa transaçãoidempotente pelo adaptador existente; depois confirma reconhecimento na mesma instalação sem modificarAPKoficial. Nenhum desses passos deescrita ou teste deacesso foi autorizado/executado aqui.

## Evidências reutilizadas e preservação

[CI41721966928](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41721966928):7fixturesmensais+4regressões deantes/depois e sintaxe aprovadas. [CI41719572181](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41719572181):26financeiros+8comparaçãoAPK. Nenhuma alteração decódigo nesta atualização; não repetidos testes verdes nem diagnósticos403.

A duplicidade anterior não foi comprovada como causa direta do bloqueio; falhas históricas de vínculo/projeção e sincronização desativada continuam evidências disponíveis. Cancelar anual não projeta automaticamente direito mensal noSpark.

Status **VERMELHO de acesso**, pois sessão/backend eantes/depois atuais ainda não foram capturados e cliente não teve restauração confirmada. Estadoanual cancelado é informação confirmada visualmente pelo proprietário, não tarefa pendente. Próximaação concreta: conectar osbindings no hostprivado aprovado, executar a leitura acima, correlacionar instalação/sessão e apresentar manifesto de4documentos para autorização. Nenhuma produção, mensal, cobrança, APK, Roku, LAB714, IAM ou recurso alterado.
