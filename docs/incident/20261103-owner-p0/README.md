# P0 — continuidade e proposta controlada (03/11/2026)

Status final da cliente: **VERMELHO** — acesso não restaurado, backend/sessão instalada não comprovados e prévia atual não aplicável. Código de recuperação isolado/testado existe; nenhuma produção modificada. Base desta etapa d3b6278bd2b9d4d4b252d42bc11d98001ea2fa18, branch incident/payment-recognition-20261103. Nenhum AGENTS.md presente na árvore dessa revisão; relatórios de plantão do incidente foram lidos integralmente. Não reutilizar instruções do projetoRoku para alterar este escopo.

## O que já estava comprovado, sem repetir consultas de clientes

[Correção e diagnóstico anteriores](../../plantao/2026-11-03-incidente-pagamento-correcao.md), [restrições de execução privada](../../plantao/2026-11-03-decisao-restauracao-segura.md), [prévia integral](../../plantao/2026-11-03-sessao-previa-restauracao.md).

- Consulta financeira/identidade anterior confirmou dois pagamentosapproved, recebedor/pagador correspondentes, contaGoogle habilitada/verificada e documentoSpark sem campo paidUntil, com trial encerrado. Isso descreve o instante da consulta; não atualiza a produção hoje.
- [Contratos41693005627](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41693005627): referências individuais dos recibos resolveram contratosmonthly/annual authorized; payer_id correspondente, payer_email ausente. Datas de início e próxima cobrança foram obtidas naAPI. Não equivalem automaticamente a período de cobertura aprovado.
- [Simulação41693463861](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41693463861): dryRuntrue/writes0/accessGrantedfalse, requiresContractReviewtrue/readyForAuthorizationfalse, sem empilhar mensal+anual. As datas exatas constam da fonte e da prévia privada, sem republicar registros financeiros individualizados nesteGit.
- [Emulador41694129959](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41694129959) validou concorrência/rollback doSDK comfixtures. Não foi repetido nesta etapa.
- Infraestrutura41700620811: credencialActions funciona, possui inclusive escrita comercial; leitura de regras funciona e fonte implantado diverge da fonteSpark revisada. Isso exige revisão privada, não prova falha de regras. Não chamar essa credencial de leitor de mínimo privilégio.

## Causas e limites

Bloqueio histórico noSpark: paidUntil não projetado após pagamentosaprovados. FirebaseUID não é Google subject; clienteSpark resolve providerDataGoogle.uid e consulta rochaSparkAccounts/subject. Filtro de contratos por payer_email perde recibos cujo contrato só oferece payer_id; correção existente usa referência direta do recibo com validações de recebedor/pagador/valor/moeda/agenda.

Rotina legada inspecionada usa contexto de planos/recebedor diferente; sincronização tem padrão desativado/prontidão. Webhookinspecionado pode confirmar receivedtrue sem encontrar fatura/vínculo de assinatura para projetar oSpark. São lacunas comprováveis dofonte; entrega/configuração efetivamenteimplantada e evento responsável pelo bloqueio permanecem sem prova (Functions/Logging403 nas consultas anteriores). Não repetir a mesma tentativa nem inferir que o webhook inexiste.

Não há prova de que a instalação atual da cliente useSpark. Se usar entitlements ou outrobackend, escreverSpark não comprovadamente resolve; não escrever em váriosbancos para tentar desbloquear.

## Evidência nova de build538

Ref congelada frozen/build-538-spark-alert-approved aponta473abcaa25f7618a84ad8ea96bc0a40be8551091. [Run38525937963, número538](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/38525937963). Artefato11876231446 rocha-plus-release-evidence baixado sem APK; SHA256doZIP 7d06d5ca15bf3ea154f5d8824ac087eeba7340d1b21ddcf06fec6f344784c9b7 coincide com metadadoGitHub. Conteúdo original [build-538-release-evidence.json](build-538-release-evidence.json) contém apenas evidência pública da distribuição; URLtemporária assinada não persistida.

A distribuição declara workflow538, **versionCode3538**, billing_modespark_trial, automatic_paymentsfalse, FirebaseAuthconfigurado e physical_validationpending. Portanto538 é número dojob, não versionCode. Buildassinada depende de paidUntil projetado; abrircheckout não cria direito. Fontes congelados tools/prepare_signed_build.py e validate_billing_config.py exigem rocha-plus; SubscriptionGate seleciona SparkBillingRepository quando flagcompiladaROCHA_SPARK_TRIAL estátrue, confirmado pelo manifestoevidência.

Hashes dos doisAPKoriginais estão no manifesto, sem baixar/republicarAPK. Novo installed_release_comparison.mjs compara metadados/hashes reportados sem tocaraparelho, serviços ou conta. Coincidência identifica candidato compilado, nunca a sessão autenticada nem concede acesso. EntregaPlaydividida pode terhashdistinto: ausência de coincidência não é prova automática de aplicativo ilegítimo.

Cliente informou nesta etapa que versão/código/hash ainda não foram coletados. Esteexecutor não possui adb,node,python ou gh noPATH e não tem os cinco bindings privados necessários (verificação por presença, sem valores). O NodeREPL permitefixtures; não é executor privado configurado deMercadoPago/Admin. SecretsGitHub não podem ser exportados, e a guarda do diagnóstico privado continua intacta. Nenhuma nova consulta decliente/MercadoPago foi simulada como real.

## Procedimento simples para identificar a instalação

1. Na própria cliente, ConfiguraçõesAndroid → Aplicativos → Rocha+ → Informações: anotar versão exibida e origem conhecida da instalação. Se oapp oferecer Sobre/Versão, consultar sem sair da conta. Registrar apenas mensagem do bloqueio e horário/fuso, modelo/Android, sem senha ou códigos.
2. Se versionCode/pacote não aparecerem, não fazer logout, limpardados, atualizar ou reinstalar. Um computador de suporte já autorizado pode usar tools/incident/device_metadata.py --package PACOTE_CONFIRMADO. O coletor jáexistente não ativaADB nem lê dados deconta. AquiADB não está disponível, portanto nenhuma coleta foi executada.
3. Opcionalmente --hash-apk no suporte autorizado calcula hash de cópias privadas temporárias e as remove. Comparar com o manifesto538 e installed_release_comparison.mjs. Não enviar APK, token ou dumps dearmazenamento aochat. Não habilitar depuração/instrumentação nova sem autorização específica.
4. Confirmar identidade da MESMA sessão e projeto/backend com observabilidade já existente ou transporte aprovado; loginGoogle separado no navegador não prova sessão doAPK. Preservar odiagnóstico session_identity_diagnostic e a recusa de Actions no incident_session_readiness.

## Correção mínima proposta e antes/depois

Recuperação existente regular_payment_contract.mjs + regular_payment_recovery.mjs + regular_payment_firestore.mjs: primeira compra vinculada ao contrato porreferência/payer_id, termos explícitos revisados, pagamento consultado novamente, ledger global porID, transação e auditoria idempotentes. Não cria cobrança nem altera recorrências. Regra de períodos independentes: maior término válido, nunca soma mensal+anual. Renovação posterior exige ciclo específico; o resolvedor atual deliberadamente recusa tratar qualquer renovação como primeirociclo. Recusar estorno antes deapply não é monitor automático de estorno futuro: integração contínua continua pendente.

Prévia histórica privada criada nesteworkspace: C:/Users/Administrador/Documents/ChatGPT/Rocha +/private/incident-payment-recognition-20261103/preview-historical-NOT-APPLICABLE.json. Fora doGit, contém candidatos temporais e os registros conhecidos; não contém segredos. **Não é a captura atual nem manifesto final autorizável.** Não inventarUID/subject/versões ou substituir ausência de campo porFirestore null.

| Registro proposto | Antes observado / falta atual | Depois-modelo / condição |
|---|---|---|
| rochaDirectPaymentLedger/IDmensal | Ausência histórica; existência atual desconhecida | Create do recibo confirmado, identidadeGoogle/Firebase, período mensal explícito, origemcontratual, operador/autorização/timestamp pendentes |
| rochaDirectPaymentLedger/IDanual | Ausência histórica; existência atual desconhecida | Mesmo modelo, período anual independente; não acumularmensal |
| rochaSparkAccounts/GoogleSubject | paidUntil historicamente AUSENTE, updateTime/reconciledAt atuais não capturados | Atualizar somentepaidUntil para término candidato revisado +reconciledAt da execução; preservar trial/welcome/favoritos |
| rochaDirectPaymentProjections/GoogleSubject | Estado atual desconhecido | uid,googleSubject,paidUntil e digestfinanceiro |
| rochaDirectPaymentAudit/digest | Existência atual desconhecida | Create único comator/referência/before/after/IDs/data; bloquearse jáexiste |

Candidatos exatos de período provêm do contrato consultado e simulação histórica, não de cálculo porpreço nem decisão comercial nova. paidUntil candidate só poderá ser selecionado após revisar interpretação de vigência. Before atual exato permanece **indisponível**, portanto readyToApplyfalse, finalAuthorizationBoundDigestnull. Não pedir aprovação genérica de dados desconhecidos.

## Testes nesta etapa

-8novos testescomparação deAPK passaram: ausência de versão, sóversão, universal/ARM64exatos, versionCodeincompatível, split/AAB não confundircomAPK, metadadosinválidos e não ecoaridentificadores/tokens.
-26fixturesfinanceiras dirigidas passaramlocalmente (targeted-financial-tests.json), cobrindo duplicidade, períodos independentes, renovação comciclo incorreto recusada, estorno/chargeback/refundparcial, pagador/recebedor errados, termos ausentes, concorrência, autorizaçãoausente, manualrevocation e rollback.
-Runnerlocalnode:test padrão falhou por spawnEPERM; isolationnone expirou. Para executar callbacks, localmente adaptou-se somente registro doframework; uma fixtureJSON passou a clonar no mesmo contexto para evitar comparação deprotótipos doNodeREPL. Asserções/lógica deaplicação preservadas; cópiasadaptadas não serão commitadas. Testes canônicos sem adaptação serão executados emCI semSecrets e resultados anexados.
-69testes completos e emulador anteriores permanecem evidênciashistóricas; nenhum cliente real, pagamento novo, aplicaçãoSpark ou desbloqueio foi testado.

## Próximo procedimento executável

Coletar metadados sem sessão nova; comparar com evidência538; disponibilizar executorprivado aprovado com bindingsleitores próprios (sem exportarSecretsCI); executar incident_session_readiness.mjs no checkout de referência conforme relatório de sessão. Ele permiteapenas leitura e gravação de resultado privado, recusaActions e não tem modoapply. Guardar readiness.private.json e before-images.private.json privadamente.

Esse resultado deve preencher caminhos/valores/versões dos cinco documentos, existência da auditoria, vínculo doaparelho e revisão do rulesetimplantado. Selecionar operador e interpretação contratual antes deproduzir digestfinal do envelope completo. Só então apresentar autorização específica de regularização para revisão. Nenhuma alteração emprodução nestaordem, inclusivepaidUntil, IAM, contratos, webhooks ou flags.

Riscos tratados: cobrança duplicada evitada por nenhumGET virarcheckout/cancelamento; concessãoindevida evitada porreview/digest/identidade/estadofinanceiro; duplocrédito evitadoledger/transação; coexistênciamensal/anual preservada sem cancelamento ou soma; frontenddesconhecido impede alegação de restauração. Risco remanescente: recuperação pontual não substitui rotina contínua de renovação/estorno revisada.

## Preservação

Somente branchincident. Roku, LAB714, aplicativo dosavós, C6, versãooficialcongelada e site não modificados. Nenhuma cobrança, assinatura, produção, IAM, recurso, regra, deploy, merge ou APK. Arquivos novos de código: installed_release_comparison.mjs e teste; workflowincident-installed-release-fixtures.yml (semSecrets); documentosdestapasta. Correçãofinanceira existente não alterada. StatusVERMELHO permanece até confirmar restauração no aplicativo real após futura autorização.
