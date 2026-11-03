# P0 — bloqueio operacional e execução privada

Base2e6b906acb7d2521bd09faa1d9da606425fdb71c, branchincident/payment-recognition-20261103. **ACESSO OPERACIONAL PRIVADO: NÃO DISPONÍVEL.** Não há conexãoFirebase/MercadoPago nesta sessão. Os5bindings abaixo foram testados somente porpresença e todosausentes; listaCodexCloud retorna environments[]/nextCursornull. Nenhum executorprivado utilizável foi identificado. Não confundir a existência deSecretsActions com acesso desteprocesso aosdados.

## O que falta e onde configurar

| Binding no executor privado | Origem autorizada / configuração |
|---|---|
| FIREBASE_SERVICE_ACCOUNT_JSON | Credencial existente autorizada do projeto rocha-plus via cofre/integração privada do host. Não gerar chave ou concederIAM nestaordem. Precisa AuthgetUserByEmail/getUser, leituraFirestore dos documentos específicos e, se executar diagnóstico deinfra, leitura de regras/metadados. IdentidadeCI existente tem permissões amplas e não é leitor mínimo por definição. |
| MP_RECEIVING_ACCESS_TOKEN | Credencial existente da aplicação/conta recebedora legítima, por integração privada dohost. Consultar quem administra a aplicação em MercadoPagoDevelopers/Suasintegrações; não criar token, trocar conta nem copiar valor aochat. ApenasGETs no script. |
| INCIDENT_TARGET_EMAIL | Seletor da conta jáinformada, configurado no mecanismo privado deenv dohost. Não é pedido de nova informação comercial. |
| INCIDENT_PAYMENT_IDS_JSON | ArrayJSON de strings com osdois recibos já investigados (mensal eanual), obtido da custódia privada existente; não substituir IDdo pagamento porIDdo contrato. |
| EXPECTED_RECEIVING_MERCHANT_ID | IDindependente da conta recebedora validada, fornecido pela custódia privada. Não derivar automaticamente de um recibo para depois chamar essa coincidência de verificação independente. |

Onde: administrador/proprietário precisa selecionar um computador/VM privado jáautorizado, idealmenteLinux para osmodos0700/0600, e ligar o cofre/integração existente ao ambiente do processoWork/Codex nessehost. Nenhum nome/IP dehost foi fornecido ou descoberto; não há autorização para criarVM/runner/conta/chave/IAM. EmCodexCloud não há configuração acessível nesta sessão. EmGitHub os Secrets existem em Settings→Secrets and variables→Actions; isso permite uso dentro dejob nativo, não revela valores nem os vincula aWork. Não extrairsegredos porartifact/log, não remover guardaGITHUB_ACTIONS e não fingir execução privada numjobpúblico. Este diagnóstico segue bloqueado emActions por escolha anterior do proprietário.

## Comando concreto no host privado aprovado

Pré-condições: checkout completo do repositório, Node22+, npm, autenticação deGit de leitura existente, bindings pelo cofre sem aparecer no histórico/terminal; não colocar valores nos comandos. Estes comandos NÃO foram executados contra produção aqui.

```sh
cd /CAMINHO_PRIVADO_DO_CHECKOUT/rocha-plus
git fetch origin incident/payment-recognition-20261103
git checkout --detach OPERATIONAL_CODE_COMMIT
(cd backend/entitlement && npm ci --ignore-scripts --no-audit --no-fund)
node --input-type=module -e 'const names=["FIREBASE_SERVICE_ACCOUNT_JSON","MP_RECEIVING_ACCESS_TOKEN","INCIDENT_TARGET_EMAIL","INCIDENT_PAYMENT_IDS_JSON","EXPECTED_RECEIVING_MERCHANT_ID"]; console.log(names.map(name=>({name,present:!!process.env[name]}))); if(names.some(name=>!process.env[name]))process.exit(1)'
umask 077
export ROCHA_PRIVATE_REPORT_DIR="$(mktemp -d /tmp/rocha-monthly-readiness.XXXXXX)"
node backend/entitlement/diagnostics/incident_session_readiness.mjs
```

Substituir somente caminho local pelo checkout efetivo; oSHAde código será fixado no fechamento. Não definir GITHUB_ACTIONS=false para contornar guarda. Não pedir à cliente token/senha. Comando permiteleitura real e gravação dos arquivos locaisprivados, não aplicaFirestore/provedor. O diretório deve ser novo, vazio, fora do checkout; arquivos não devem ser anexados aGit/log/artifact. EmWindowschmod não substitui revisão deACLNTFS; escolher hostprivado compatível ou revisar custódia antes deexecutar.

Resultados esperados: readiness.private.json com IDs reaismensal/anual, vínculo validado, calendário e prévia mensal; before-images.private.json com4caminhos reais, existência, valoresanteriores, updateTime/digests e afterTemplate integral. Operador/autorização ainda não escolhidos e horário de execução simbólico, portanto não é mudançasetfinal aplicável. O comando NÃO valida sozinho a sessão doAPK: essa prova precisa vir da MESMAsessão e de backend efetivo, conforme verificador preparado. A prévia continua marcada não autorizada.

## Correções nesta etapa

O executável antigo ainda reunia todos osrecibos na recuperação. Agora consulta dois recibos, exige ummensal e umanual, valida contratos com prepareMonthlyOnly e envia SOMENTE monthlyTerms ao simuladorSpark. O anual não entra empaidUntil/ledger deacesso. Guarda deexecuçãoprivada, escritadisabled e retorno público mínimo preservados. Nenhuma rota/admin/appnovo.

monthly_only_preparation agora retorna oIDanual explícito inclusive quandojá cancelado(NO_OP). recovery_changeset_preview mantém o antes exato e adiciona operação/afterTemplate apenas ao sinkprivado, não ao retornomascarado. O script já suporta4documentos para umrecibo. Regressões verificam presença doafter privadamente e ausência deidentidade no retornopúblico.

## Prévia operacional ainda bloqueada

Nenhum recibo/contrato/conta foi lido novamente. IDsmensal/anual, UID/Google subject e updateTimesatuais permanecem desconhecidos nesteexecutor. Histórico: mensalconfirmado, próximoscalendário20/11/2026; período candidato20/10/2026 22:30:38UTC→20/11/2026 22:30:38UTC, sujeito àrevisão decobertura, não paidUntil automático. Duplicidade contribuiu paraambiguidade, mas não provou causa direta: falhas deemail/vínculo/projeção históricas continuam diagnóstico. Não repetir Functions/Logging403; não foram consultados.

| Operação futura | Destino e antes que faltam | Proposta |
|---|---|---|
| Ledger | rochaDirectPaymentLedger/IDmensal real;existência/updateTime | Create do mensal verificado, nunca anual |
| Spark | rochaSparkAccounts/subjectGoogle verificado;paidUntil/reconciledAt/updateTime | SomentepaidUntil mensal aprovado e reconciledAt; preservar trial/favoritos |
| Projeção | rochaDirectPaymentProjections/subject;conteúdo/versão | Projeção mensal consistente comledger eidentidade |
| Auditoria | rochaDirectPaymentAudit/digest;existência | Create único, operador/referência/digestaprovados |

Concorrência/idempotência: adaptador já lê osregistros emrunTransaction, ledgerporID, préviastale recusada e auditoriaúnica. Beforecapturado fora detransação não prova snapshotconsistente; futura aplicação tem de revalidar provedores e versões emtransação. Não baixar silenciosamentepaidUntil anual eventualmente jáexistente, nempreservarcomo se fosse mensal: revisar essecaso comantesreal.

Cancelamento anual permanece separado: descobrirIDreal pela referência do recibo, confirmar recebedor/payer_id/agenda/tipo e IDdiferente do mensal, depois produzir préviaPUT /preapproval/IDanual correta, comschema/status do provedor revisado e autorização específica. Contrato mensal nenhuma mutação; manter próxima cobrança prevista20/11. Nenhuma requisiçãoPUT/cancelamento/refund nestecomando. Pixexterno49,50 relatado pelo proprietário, comprovante não conciliado, sem classificar como estornoMP.

## Bloqueio e próxima ação exata

Responsáveloperacional: proprietário/administrador do ambiente privado precisa indicar o host autorizado e ligar os5bindings existentes ao processo, sem exportarSecretGitHub. Depois ooperador executa ocomando acima e guarda saídasprivadas; suporte confirma APK/sessão real semlogout/reinstalação. Só com esse material será possível apresentar antes/depois atual verificável e duas autorizações posteriores separadas (acesso mensal e recorrênciaanual).

Não é falta de autorização para estasleituras: a ordem já autoriza. É ausência deconexão/bindings/executor nesta sessão, somada àidentidade da instalação ainda desconhecida. Não fabricar valores, reexecutar403 ou conceder direito para testar. StatusVERMELHO operacional; nenhuma aplicação, cobrança, deploy ou mudança depermissão/produção.
