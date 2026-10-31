# Rocha+ — estado atual da candidata — 29/10/2026

> Preservação documental — 31/10/2026.
> Este documento registra a investigação no checkout local
> `homolog/technical-candidate-20261028`, baseado em
> `98160d47f7a0ca341fbd7f80eda3db72fe0acb60`, com trabalho não publicado.
> Na base remota desta preservação
> (`2378d780f4c9ef79f0d3c0c220b3430adbc56003`), o reconciliador
> ainda exige `TEST-`. A aceitação condicionada de `APP_USR-`, com
> verificação de identidade, existe somente no trabalho local não publicado.
> O preflight local falhou por ausência de credencial verificável disponível;
> esse resultado não demonstra bloqueio por prefixo no código local.
> A exclusividade da credencial para testes não foi comprovada; Mercado Pago
> permanece não homologado.
>
> Este commit preserva somente documentação, sem publicar a implementação local.
> Os estados e menções a ausência de commit nas seções históricas referem-se
> às respectivas etapas da investigação, anteriores a esta preservação.
> Caminhos de custódia privada foram omitidos; nenhum arquivo privado acompanha
> esta documentação. Leia os registros cronológicos como histórico do checkout,
> não como descrição da implementação publicada ou homologação da candidata .6.

Branch `homolog/technical-candidate-20261028`, HEAD `98160d4`. Alteracoes locais
sem commit/push; nenhum novo CI, deploy ou publicacao nesta continuidade.

## Catalogo: criterio vigente

Usar somente aprovados na varredura de 180 segundos, com Globo, Band e Record
excluidos por solicitacao do operador. O filtro esta implementado no codigo
candidato e cobre carga, refresh, cache e consultas de bloqueio dos players.
A .3 ja instalada ainda usa o catalogo geral anterior.

| Fonte recuperada | Evidencia | Aplicada ao novo catalogo? |
| --- | --- | --- |
| LAB Windows original, 479 registros | Recuperado com SHA-256 conferido; 359 processos curtos, 60 prolongados com erro, 54 success=false, 6 inconclusivos | Nao: registro de processo nao comprova 180 s de A/V |
| Benchmark original, 788 URLs | 509 deteccoes A/V; campo tempo_deteccao_s de 0,44 a 11,12 s nos positivos | Nao: nao comprova reproducao de 180 s |
| 68 consolidados do LAB no GitHub | 0 testados e 479/480 pendentes em cada arquivo | Nao: sem aprovados recuperaveis nesses arquivos |
| Catalogo antigo do APK, 190 canais | Aproximadamente 30 s por registro | Nao: referencia historica preservada |
| Confirmacoes SBT Interior/Nacional nos documentos | FFmpeg 180 s ja documentados | Preservadas como evidencia parcial; nao equivalem ao relatorio completo |

O CSV original de 788 linhas foi recuperado de outra branch do mesmo repositorio,
sem alterar essa branch ou a plataforma Roku. Seu SHA-256 confere com o manifesto:
`17095a366a0ec73ac6cc85be27469500d3a10aac4df89ebf137ae0c54d424914`.
O relatorio Windows de 479 registros foi recebido e auditado. A pendencia agora
e a qualidade da evidencia: duration mede processo e success nao comprova A/V.
Ver [auditoria dos 479 registros](2026-10-29-recuperacao-lab-pc-479.md).
Preservar as sessoes e nao reiniciar a varredura.

Importador pronto: preserva fonte/hash e niveis de evidencia PC/Android, rejeita
conflitos e nao converte deteccao em homologacao. Auditor/importador PC integrado:
10 testes focais aprovados, 479 registros preservados em revisao, 380 erros
explicitos de conexao e 54 timeouts separados. Nenhuma aprovacao inferida por
duracao de processo ou exit zero. Snapshot candidato vazio ate
recuperar as aprovacoes; preparador impede gerar candidata distribuivel vazia.

## Aviso dos sete dias

Dialogo original e arte aprovada recuperados no historico: o aviso existia.
Seu fluxo usa o gate de billing e registros Spark; a candidata atual usa outro
fluxo de autenticacao/assinatura e nao inclui esse dialogo. Ainda nao identificada
a versao exata vista pelo operador. Nenhuma alegacao de regressao fisica corrigida.

Codigo preparado para apresentar a mensagem textual no cartao existente somente
com allowed=true, motivo trial, inicio/vencimento do servidor separados por sete
dias. Testes focais aprovados; endpoint continua vazio/desativado na .3. Nao
inventar datas ou conceder trial localmente. Arte antiga recuperada intacta
mostra R$ 4,90/R$ 55,00, enquanto o menu da base candidata mostra R$ 4,50/R$ 49,50.
Nao reutilizar essa arte automaticamente nem alterar precos/arte sem reconciliar
a divergencia com os valores vigentes.

## APK e aparelho

Candidata .3: com.rochaplus.app.candidate, versionCode 3, assinatura original
verificada no novo artefato, ABIs ARM32/ARM64/x86_64, ZIP/ELF 16 KiB verificados
no escopo documentado. Instalada no Moto G56 5G pelo operador com Success.
Abertura por componente explicito: Status ok, COLD, 1838 ms. Login e canais
carregados relatados; um canal com imagem/som. Sem prova de duracao, troca, Cast
ou TV. Telefone desconectado. Nao repetir instalacao/login ja aprovados sem motivo.

.4 intermediaria nao entregue: apenas exclusoes iniciais, anterior ao filtro
de aprovados. Nao usar para a proxima entrega. Nenhum novo APK gerado nesta rodada.

## Pagamentos, distribuicao e continuidade

Producao mantem live_mode=true. Identidade sandbox confirmada no Windows do
operador; ciclo financeiro externo sandbox ainda separado dos contratos
automatizados aprovados. Pagamentos reais anteriores nao repetidos.

Site permanece sem acesso de edicao confirmado pelo Sites conectado. APK .3
foi entregue via ZIP privado no Drive com somente permissao owner verificada.
Candidata nao e atualizacao do pacote Oficial nem confirma compras de producao.

Programa Windows recebido e copia V2 corrigida preparada em tools/windows:
10 testes headless e 2 fixtures locais aprovados, sem novas transmissoes.
Entrega separada do programa antigo; interface Windows/Tk ainda pendente.

Proximas dependencias: eventual evidencia A/V complementar dos registros
antigos ou validacao focal planejada; importar
somente aprovacoes sustentadas pelos dados; integrar consulta/ativacao de trial no backend candidato autorizado;
preparar proxima build e testes fisicos focais. Oficial, USBQA, LAB 714, site,
PR #42 e artes/layouts aprovados preservados.


### Salvamento solicitado pelo usuário

Todas as alterações locais foram preservadas na branch `homolog/technical-candidate-20261028`. Conferência `git diff --check` aprovada. Cópia local privada do código e dos relatórios salva fora do checkout em `[custódia local privada; não publicada]`, sem incluir arquivos ignorados pelo Git, chaves, configuração privada ou APKs. Nenhum commit, push, CI, deploy ou publicação executado. As pendências técnicas registradas acima permanecem abertas.


### 30/10/2026 — retomada do ciclo externo Mercado Pago sandbox

Conferida somente disponibilidade dos insumos, sem repetir suites verdes ou a
identidade da conta ja confirmada no Windows. Ambiente conectado, observacoes
atuais; nenhuma identidade externa ou secret configurado neste executor. Nao
ha ROCHA_MP_SANDBOX_ACCESS_TOKEN/MP_TEST_ACCESS_TOKEN no ambiente nem arquivo
no caminho privado previsto [custódia local privada; não publicada]
Nao foram localizados planos privados com nomes de compra/renovacao/estorno
no diretorio privado. Isso nao estabelece ausencia de secrets no GitHub, de
credenciais no Windows ou de planos em outros locais nao informados.

Bloqueio: disponibilizar por canal privado a credencial de teste existente ao
executor e os claims revisados de recibos sandbox, com vendedor, valor/moeda,
plano e identidade sandbox independentes. Nao enviar tokens pelo chat. O
operador existente faz apenas GETs no Mercado Pago e gravacoes no emulador;
nao cria checkout, compra, renovacao ou estorno no provedor. A existencia desses
recibos externos ainda nao foi comprovada. Nao reutilizar IDs de compras reais.

Proxima execucao viavel: auditar recibos de teste existentes e executar fases
na mesma sessao efemera do emulador, verificando replay e preservacao do trial.
Isso ainda nao comprova desbloqueio no APK: candidata .3 tem endpoint vazio e
nao esta conectada a esse backend isolado. Fluxo externo/app segue pendente.
Nenhuma chamada ao provedor, pagamento, concessao cloud, nova build, CI,
commit, push, deploy ou publicacao nesta retomada. Producao live_mode=true
preservada. git diff --check aprovado.


### 30/10/2026 — roteiro externo preparado

Criado [roteiro de prova sandbox](2026-10-30-roteiro-mercado-pago-sandbox.md), conferido contra audit_provider.js e run_provider_phase.js. Separa recibo externo, reconciliacao local e acesso no APK; explicita que estornar uma compra nao bloqueia acesso se outra renovacao continua valida. Nenhuma execucao de pagamento ou suite verde repetida. Insumos privados continuam pendentes conforme conferencia anterior.


### 30/10/2026 — caminho local Windows para recibo sandbox

Preparados tools/sandbox/consultar-recibo-teste.ps1 e colar-consulta-recibo.txt:
GET de recibo existente, sem repetir identidade /users/me, token oculto em
memoria, sem gravacao remota/local de credencial ou concessao de acesso.
Sete testes novos com respostas simuladas aprovados em PowerShell 7.6.9 Linux;
Windows nativo e recibo externo pendentes. Nao repete suites verdes anteriores.
Criterio live_mode=false, ID/vendedor/valor BRL e estado conferidos. Consulta nao
comprova renovacao, replay, autenticidade da identidade atual ou acesso no APK.
Sem recibo TESTE existente nao executar: script nao cria checkout ou estorno.
Nenhuma chamada externa, pagamento, commit, CI, deploy, APK ou publicacao.


### 30/10/2026 — preparador de checkout isolado, sem execucao externa

Implementado tools/sandbox/prepare_test_checkout.py para operador Windows/Python:
GET users/me como guarda antes de POST checkout/preferences exclusivamente para
vendedor de teste esperado MLB/test_user. Nao e reexecucao solicitada do teste de
identidade historico: e verificacao obrigatoria para impedir nova escrita em conta
normal. Usa token oculto em memoria, TLS/proxy padrao, redirects recusados; nao
exibe token/payload/erro remoto. Aceita somente sandbox_init_point HTTPS no host
sandbox.mercadopago.com.br e vendedor correspondente; nao usa init_point real.
Sem webhook, producao, trial, concessao, assinatura ou pagamento automatico.

Seis testes novos com mocks aprovados (conta normal/divergente antes de POST,
preferencia minima, host/URL e vendedor de retorno, sem fallback de producao).
Codigo nao executado no Windows nem contra API. Documentacao web oficial tentou
ser consultada, mas retornou HTTPError nas tres paginas; compatibilidade externa
nao confirmada. Pacote preparado fora do Git em
/workspace/rocha-sandbox-checkout-delivery/rocha-checkout-teste-preparado.zip.
Uma preferencia de pagamento avulso nao comprova cobranca recorrente de assinatura.
Nao repetir automaticamente em falha apos POST. Nenhuma preferencia/pagamento
realmente criada nesta rodada; nenhum teste verde anterior repetido, APK, CI,
commit, push, merge, deploy ou publicacao. Assinaturas reais preservadas.


### 30/10/2026 — tentativa Windows nao confirmou checkout

Captura do operador comprova Python em Python315 executando o preparador e
terminando com Checkout nao confirmado apos entrada oculta. A mensagem antiga
nao identifica etapa/HTTP/TLS; criacao de preferencia anterior desconhecida.
Nao repetir POST nem afirmar que nenhuma preferencia foi criada. Nenhum recibo
ou pagamento sandbox aprovado comprovado. Bloqueio py/python no PATH resolvido
usando executavel existente, sem instalacao ou mudanca de PATH.

Novo diagnose_checkout.py somente GET users/me investiga transporte/credencial
no Python que falhou; nao substitui nem invalida identidade historica aprovada.
Guarda diagnostica limitada a esta falha nova; sem POST, conclusao sobre preferencia
anterior ou dados privados na saida. Quatro novos testes simulados passaram:
GET unico, HTTP expurgado, TLS sem bypass e formato invalido sem rede. Nao houve
reexecucao de suites verdes ou consulta externa pelo agente. Precisa do arquivo
prepare_test_checkout.py existente na mesma pasta; entregar separado sem ZIP.


### 30/10/2026 — correcao do diagnostico independente

Captura Windows mostra ImportError no diagnostico antes de qualquer prompt/requisicao. Removida dependencia de prepare_test_checkout.py; diagnostico usa somente biblioteca padrao e permite exclusivamente GET users/me. Sem POST nem criacao de preferencia. Reexecutada somente suite focal alterada, com novo teste de importacao independente/recusa POST: cinco testes simulados aprovados. Consulta externa ainda pendente; estado da primeira preferencia permanece desconhecido.


### 30/10/2026 — formato recusado antes de rede; entrada alternativa

Duas capturas Windows de diagnostico V2 mostram credential_format_invalid e
providerCalled=false, mesmo apos operador relatar colagem unica. Isso nao prova
credencial invalida no provedor; conteudo nao foi inspecionado/exposto. Sem nova
consulta ou escrita externa nessas tentativas. Evitar insistir em Ctrl+V/getpass.
Preparada entrada opcional --clipboard com API nativa Windows CF_UNICODETEXT,
leitura em memoria sem echo, arquivo, variavel de ambiente ou argumento de token.
Entrega nova diagnostico_clipboard_v3.py; token permanece no clipboard do operador,
que deve substitui-lo por texto inofensivo depois. Diagnostico continua somente
GET, sem POST e sem conclusao sobre a preferencia anterior. Seis verificacoes
locais focais passaram, incluindo verificacao estatica de entrada; API clipboard
Windows nao foi executada neste Linux. Sem aprovacao externa ou APK.


### 30/10/2026 — diagnostico Python/clipboard confirmado no Windows

Captura final do operador comprova diagnostico V3 --clipboard retornando
reason=read_transport_ok, providerCalled=true, remoteWrites=0,
checkoutApproved=false, previousPreferenceCreated=unknown. Isso comprova GET
users/me via Python Windows e guarda de vendedor esperado/site MLB/test_user
aprovada, sem expor credencial. Entrada por clipboard funcionou; falhas anteriores
de formato no getpass nao comprovavam token invalido. Diagnostico encerrado:
nao repetir sem regressao. Token continua no Windows, nao neste executor.
Nenhuma preferencia ou pagamento criado pelo diagnostico. Estado da tentativa
original de criacao permanece desconhecido; nao repetir POST cegamente.
Proximo passo: preparar entrada clipboard no gerador e investigar eventual
preferencia ja existente antes de nova criacao; manter sem pagamento automatico,
sem usar assinaturas reais. Nao ha prova externa de compra/renovacao/estorno,
reconciliacao ou desbloqueio APK. Nenhum CI, commit, deploy ou nova build.


### 30/10/2026 — busca de preferencia anterior preparada

Novo search_test_preferences.py/entrega buscar_preferencia_somente_leitura_v1.py:
GET checkout/preferences/search, sem users/me ou POST. Filtra referencia exclusiva
sandbox-checkout-UUID do preparador, vendedor correspondente; nao exibe IDs,
recibos, token ou URLs. Paginacao limitada a 200 registros; so marca busca completa
quando total explicito do provedor foi atingido. Resultado incompleto ou erro
nao estabelece inexistencia de preferencia. Cinco testes novos com mocks passaram:
preferencia existente, ausencia de total, vazio confirmado, registros alheios e
recebedor divergente. API externa ainda nao consultada pelo agente; leitura no
Windows pendente. Credencial clipboard continua somente no Windows. Prova nao
valida pagamento, assinatura recorrente ou acesso no app. Nao repetir criacao
anterior enquanto estado desconhecido. Sem CI, commit, APK ou deploy.


### 30/10/2026 — busca Windows finalizada, gerador clipboard preparado

Captura do operador: preferenceSearchCompleted=true, isolatedPreferenceCandidates=0,
recordsReviewed=0, remoteWrites=0, identityRechecked=false. Operador confirmou o
ID correto do vendedor informado. Busca nao comprova pagamento. Nao repetir
busca/diagnostico sem regressao. Preparado gerador independente
criar_checkout_teste_clipboard_v2.py, entrada nativa clipboard sem token em
arquivo/argumento/saida. Mantem guarda test_user/MLB/vendedor antes de POST e
sandbox_init_point estrito. Acrescenta failedStage/httpStatus expurgados e
preferenceMayExist para evitar repeticao cega apos POST. Compilacao/importacao
e smoke novo com transporte simulado aprovados, sem rede. Suites verdes antigas
nao repetidas. Criacao externa ainda nao executada pelo agente; operador deve
executar uma unica vez. Preferencia nao equivale a pagamento nem assinatura.


### 30/10/2026 — preferencia sandbox criada no Windows

Captura do operador comprova gerador clipboard V2 executado, guarda do vendedor
de teste aprovada e mensagem Preferencia criada com sandbox_init_point HTTPS
no dominio sandbox.mercadopago.com.br. Nao reproduzir link/identificador privado
no relatorio. Sintaxe Windows previamente verificada com py_compile/saida 0.
Entrega manual inicial foi truncada e exigiu completar chamada main no arquivo;
falhas locais anteriores nao eram pagamentos. Agora preferencia criada: NAO
repetir gerador, busca ou diagnostico sem regressao.

Isso nao comprova pagamento aprovado, recorrencia, renovacao, estorno,
idempotencia externa, reconciliacao ou desbloqueio do APK. Proximo passo do
operador: abrir o link ja criado em janela privada, entrar com comprador de
TESTE distinto, usar exclusivamente cartao de teste oficial; preservar
assinaturas e credenciais reais. Aguardar conferencia da tela sandbox antes
de concluir pagamento. Credencial nao foi transferida ao executor. Nenhum
pagamento pelo agente, CI, commit, build, merge, deploy ou publicacao.


### 30/10/2026 — compra externa sandbox aprovada na interface

Captura do operador mostra dominio sandbox.mercadopago.com.br, faixa Sandbox,
mensagem Seu pagamento ja foi aprovado e R$ 4,50 com saldo em conta no checkout
isolado avulso. Referencia da operacao preservada somente em evidencia privada;
nao copiar dados do comprador ou link ao Git. Este e resultado externo na UI,
nao mock. Nao repetir compra aprovada. Houve erro generico apos selecao inicial
do vendedor; checkout abriu novamente na sessao posterior, sem nova preferencia.

Pendente: GET autenticado do recibo e verificacao explicita live_mode=false,
ID, vendedor, BRL, valor/status; reconciliacao no emulador com replay; segundo
periodo/renovacao e estorno; acesso em APK. Pagamento e avulso e nao comprova
assinatura recorrente. Endpoint da candidata permanece vazio. Nenhuma alteracao
nas compras reais anteriores, nenhuma concessao cloud, CI, commit, deploy ou APK.


### 30/10/2026 — auditor GET do recibo pago preparado

Preparado audit_paid_sandbox_receipt.py e entrega independente
conferir_recibo_sandbox_v1.py com claim especifico da operacao em referencia
privada, sem credencial. Consulta somente GET payments/ID, nao repete users/me,
nao cobra/estorna/concede. Exige live_mode booleano false, ID/vendedor esperados,
BRL 450 centavos, approved/accredited, sem estorno e datas com timezone. JSON
expurgado nao contem IDs, token, comprador ou payload. Cinco testes novos com
respostas simuladas aprovados; recibo externo ainda pendente de consulta no
Windows. Compra UI aprovada preservada, sem repeticao. Nao valida assinatura
recorrente, replay no emulador ou APK. Sem commit, CI, deploy ou nova build.


### 30/10/2026 — recibo V1 nao confirmado, diagnostico V2 preparado

Captura mostra receiptVerified=false, reason=receipt_not_confirmed e remoteWrites=0.
Sem codigo HTTP na saida, causa nao identificada: nao afirmar que pagamento foi
recusado, token invalido ou sandbox comprovado pela API. Aprovacao visual continua
preservada. Auditor V2 agora distingue divergencias de modo/ID/vendedor/valor/BRL,
approved/accredited, estorno e datas por codigos fixos sem payload/PII. Guardas
mantidas; seis testes focais passaram apos alteracao, incluindo novo caso de
motivo expurgado. Recibo externo segue pendente. Nao repetir compra, criar nova
preferencia ou estornar antes de reconciliar aprovacao.


### 30/10/2026 — divergencia de modo no recibo externo

Captura Windows V2: receiptVerified=false, reason=sandbox_mode, remoteWrites=0.
API respondeu, mas live_mode nao era booleano false. Saida atual NAO distingue
true, ausente ou outro tipo; nao afirmar cobranca real nem modo sandbox validado.
Faixa Sandbox/compra aprovada na UI nao substitui verificacao do recibo API.
Nao importar/conceder/reconciliar este recibo como sandbox; nao estornar ou repetir
compra para tentar contornar. Producao live_mode=true preservada; reconciliador
sandbox continua exigindo false. Identidade/transporte previamente aprovados nao
reexecutados. Preparado refinamento de diagnostico com codigos true/missing/
wrong_type sem payload ou PII; sete testes focais apos mudanca aprovados. Nova
consulta externa ainda nao executada; evidencia API de modo bloqueia proxima fase.


### 30/10/2026 — resposta API com live_mode=true confirmada

Captura Windows V4: receiptVerified=false, reason=sandbox_mode_true,
remoteWrites=0. Refinamento aplicado localmente ao auditor V2 que ja executava,
sem repetir compra; V3 local continha teste unitario incorretamente copiado e
falhou no import antes de rede. Evidencia comprova live_mode booleano true na
resposta consultada. Nao comprova que ID/vendedor/valor/status correspondem:
guarda de modo e primeira verificacao e interrompe antes das demais.
UI Sandbox + compra aprovada e API live_mode=true sao evidencias distintas e
ainda divergentes. Nao afirmar cobranca real com base apenas nessa flag nem
aprovar recibo sandbox. Reconciliacao, grants, estornos e nova compra suspensos
para esta transacao ate esclarecer comportamento do provedor e correspondencia
do recibo. Nao relaxar guarda sandbox false nem producao true. Proxima investigacao
independente: documentacao oficial sobre pagamentos de test users/Checkout Pro e
contrato live_mode, e auditoria somente leitura dos demais campos sem concessao,
caso necessaria. Diagnostico de modo concluido, nao repetir. Sem pagamentos reais
executados pelo agente, deploy, CI, commit, merge ou APK.


### 30/10/2026 — investigacao oficial e inspecao conjunta

Fonte oficial acessivel: https://raw.githubusercontent.com/mercadopago/sdk-nodejs/master/src/clients/payment/commonTypes.ts
(comentario live_mode: true when the payment was created in production mode).
Paginas web de testes Checkout Pro BR/global retornaram 403 neste executor.
Nao encontrada evidencia oficial de excecao que autorize aceitar live_mode=true
como sandbox; nao flexibilizar guarda. Definicao do SDK nao basta para provar
movimento de dinheiro real em transacao de usuarios de teste.

Auditor anterior bloqueia antes das comparacoes de identidade. Preparado
inspect_receipt_fields.py, entrega inspecionar_recibo_campos_v1.py: somente GET
pagamento e flags expurgadas de ID/vendedor/comprador/valor/BRL/status/estorno/
referencia isolada, sem early-return no modo e sem grants. Inspecao nao aprova
recibo mesmo se todos os campos corresponderem. Tres testes novos simulados
passaram para modo true com demais checks, divergencias simultaneas e modo ausente.
Nao repetidas suites verdes de compra/conexao, nenhuma consulta autenticada pelo
agente ou nova compra. Execucao Windows conjunta ainda pendente; finalidade e
distinguir recibo errado de divergencia real no mesmo fluxo de teste.


### 30/10/2026 — inspecao conjunta externa concluida no Windows

Captura do operador: inspectionOnly=true, liveMode=true, liveModePresent=true;
paymentIdMatches/sellerMatches/buyerMatches/amountMatches/currencyMatches/
statusApproved/statusAccredited/noRefund/isolatedReferenceMatches todos true.
remoteWrites=0, entitlementGranted=false, sandboxReceiptApproved=false.
Resultado corresponde ao ID esperado, ambos test users previamente identificados,
valor BRL 450 centavos e referencia de formato exclusivo do preparador. Nao e
simulacao local: GET externo executado pelo operador no Windows. A referencia
foi verificada por formato sandbox-checkout-UUID; nao houve comparacao literal
com UUID da preferencia original nem nova consulta da identidade dos usuarios.

Diagnostico concluido: nao repetir consultas de identidade, transporte, modo ou
campos sem regressao. Checkout exibiu Sandbox; recibo da operacao correspondente
retorna live_mode=true. Sem evidencia oficial de excecao, permanece incompativel
com guarda de reconciliacao sandbox false. Nao relaxar producao true nem aceitar
recibo como sandbox automaticamente. Pagamento aprovado/identidades/valor estao
comprovados nesse escopo; recorrencia, renovacao, estorno, replay externo com
reconciliacao e APK permanecem pendentes. Proximo bloqueio externo: esclarecer
contrato de test users/Checkout Pro/live_mode com documentacao ou suporte oficial
Mercado Pago. Nao enviar mensagem externa em nome do operador sem instrucao.
Nenhuma nova compra, estorno, grant, CI, commit, merge, APK ou deploy nesta rodada.


### 30/10/2026 — bloqueio externo consolidado e relato de suporte pronto

Nova consulta de documentacao oficial Checkout Pro/test accounts retornou 403;
fonte SDK preference confirma existencia de sandbox_init_point, sem esclarecer
live_mode de test users. Busca publica GitHub retornou 422; nao equivale a
inexistencia de explicacao. Nao encontrada evidencia suficiente para mudar
contrato sandbox. Criado 2026-10-30-mercado-pago-suporte.md, com relato e tres
perguntas precisas sobre modo, fluxo false e ausencia de fundos reais. Nao enviado
externamente pelo agente, sem tokens/IDs/PII no texto. Proxima dependencia concreta:
operador abrir chamado autenticado com dados da operacao existente, receber
orientacao oficial. Nao repetir diagnosticos concluidos, compras ou estornos.
Nenhuma mudanca de regra, reconciliacao, concessao, APK, CI, commit ou deploy.


### 30/10/2026 — investigacao SDK e revisao das barreiras locais

Consultados fontes oficiais SDK Node: e2e/payment/create.spec.ts,
e2e/payment/get.spec.ts, e2e/payment/search.spec.ts,
e2e/paymentRefund/create.spec.ts, docs/troubleshooting.md e mocks de email de
teste. Exemplos de integracao nao verificam live_mode e nao documentam excecao
para saldo de test user; nao constituem evidencia para relaxar guarda. Nenhum
exemplo foi executado, especialmente criacao PIX/refund. Nenhuma nova operacao
ou teste verde local reexecutado. Fonte oficial troubleshooting recomenda
reconciliar por ID/referencia antes de retry e escalar com dados expurgados.

Revisao somente leitura do codigo local: eligiblePayment exige liveMode=true
mas sinaliza apenas elegibilidade para revisao. reconcile_and_grant tambem exige
claim privilegiado revisado com UID/plano/valor/moeda/merchantId correspondentes.
Portanto, live_mode=true sozinho nao autoriza acesso. Nao encaminhar este recibo
de teste a producao apenas para contornar guarda sandbox false. Ambos modulos
preservados; nenhuma mudanca de regras ou cadastro de claims cloud.

Resultado concreto: compra entre contas de teste comprovada na UI e recibo API
correspondente, mas prova exigida pelo reconciliador sandbox live_mode=false
nao foi obtida. Execucao de reconciliacao externa permanece bloqueada, nao
concluida. Investigacao acessivel nao forneceu resposta oficial para divergencia.
Chamado segue preparado, nao enviado e nao exigido automaticamente do operador.
Sem mais scripts ou pagamentos propostos nesta etapa. Trabalho independente de
catalogo/trial pode prosseguir pelos pendentes ja registrados; nao significa
pagamentos 100% nem homologacao concluida.


### 30/10/2026 — etapa do trial: integracao candidata preparada

Encontrada lacuna concreta: teste historico auth_trial exercita functions/index.js,
enquanto backend candidato usava leitor read-only que nao inicializa trial. Nao
tratar teste historico como prova da composicao candidata. Adicionados
functions/candidate/trial_access.js e trial_access.test.js; backend candidato
compoe criacao transacional uma unica vez e leitura autenticada. Chave
ROCHA_CANDIDATE_TRIAL_ACTIVATION_ENABLED permanece desligada por padrao; nenhuma
ativacao remota ou deploy. functions/index.js e reconciliador de producao intactos.

Servidor preserva registros existentes (inclusive pagos, expirados ou incompletos),
datas servidor + sete dias exatos; concorrencia nao duplica; token revogado/UID
invalido recusado. Leitor original nao foi modificado. Validacao NOVA com Firestore
Emulator real demo-rocha-candidate/127.0.0.1:8092: seis cenarios aprovados, sete
incluindo agrupador, zero falhas. Auth nessa suite e fronteira injetada; nao e
novo teste Google OAuth fisico. Rechecado somente teste backend afetado pela
composicao. Suite Auth/trial historica verde nao repetida.

Flutter: tela de assinatura consulta automaticamente ao abrir/trocar conta/retomar
somente no perfil candidato exato, sem alterar estrutura visual ou arte. Resposta
antiga nao aparece na outra conta; datas/mensagem continuam vindo do servidor,
sem grant/calculo de trial no cliente. Perfil default conserva consulta manual.
Dois cenarios novos candidato aprovados e um default aprovado, skips de perfil
registrados (um na execucao candidata, dois na default); tres cenarios distintos.
Analyze focal da tela e teste novo: No issues found. Testes feitos em scaffold
descartavel existente, nao gerado APK. Primeira chamada Flutter foi no checkout
sem dependencias resolvidas e foi corrigida para o scaffold; nao e falha funcional.

Toolchain: CLI Firebase 15.34.1 preparado em cache local sem alterar lockfile;
primeiro inicio falhou por config/cache read-only. Resolvido com XDG_CONFIG_HOME
e FIREBASE_EMULATORS_PATH gravaveis, preservando HOME/TLS/proxy. Execucao final
emulador encerrou com codigo 0. Logs privados: trial-access-integration-20261030-final.log,
trial-auto-status-candidate-20261030.log, trial-auto-status-default-20261030.log,
trial-auto-status-analyze-20261030.log em [custódia local privada; não publicada]

Limites: APK .3 instalado NAO recebeu estas mudancas, endpoint segue vazio;
nenhuma Function implantada/flag habilitada. Mensagem preparada no cartao de
assinatura existente; nao e restauracao do popup antigo apos login. Proxima
ativacao real exige backend candidato implantado e configuracao de endpoint,
operacoes que seguem fora desta execucao sem deploy. Nova build tambem continua
bloqueada por catalogo aprovado vazio. Validacao fisica da mensagem/Google login
pendente. Sem CI, commit, push, merge, pagamentos, alteracao Oficial/USBQA/LAB714,
site, precos ou arte. git diff --check aprovado.


### 30/10/2026 — contrato novo backend trial → Flutter aprovado

Criado trial_contract_fixture.js: gera respostas do createTrialAccess real novo
com Firestore Emulator real, projeto demo-rocha-candidate, e Auth injetado com
UID ficticio. Fixture nova privada, escrita exclusiva modo 600, sem dados cloud,
credenciais reais ou exportacao de banco. Captura dois estados para o mesmo trial:
ativo e vencido; suite historica de Auth/trial e suite nova anterior nao repetidas.

Novo candidate_trial_server_contract_test.dart usa essa fixture via HTTP MockClient
com SubscriptionAccess.check e SubscriptionScreen reais, perfil candidato exato.
Comprova consulta automatica, parsing de datas, mensagem de sete dias e vencimento;
resposta expirada remove aviso ativo. Um teste integrado novo aprovado sem skip.
Backend gerador terminou com codigo 0. Logs/fixture em referencia privada
[custódia local privada; não publicada] nao publicar conteudo.
Evidencia e contrato backend-emulador/cliente-HTTP-simulado, nao endpoint HTTPS
implantado, Google Sign-In fisico ou APK de aparelho. Nenhum trial real concedido.

Estado consolidado: preparacao e contrato local do trial concluidos neste escopo.
Ativacao real continua OFF; endpoint do APK instalado vazio. Deploy/ativacao e
configuracao seriam necessarios para testar no aparelho e permanecem fora das
restricoes vigentes. Nenhum APK gerado; catalogo candidato aprovado ainda vazio.
Pagamento externo preservado com divergencia live_mode documentada, sem novas
operacoes. HEAD continua 98160d4; sem commit/push/CI/merge/deploy/publicacao.
Backup atualizado do codigo e documentos fora do checkout em
[custódia local privada; não publicada] git diff --check aprovado.


### 30/10/2026 — disponibilidade remota do backend candidato

Executada consulta somente leitura functions:list explicita ao projeto
rocha-plus-candidate. Falhou por autenticacao indisponivel no executor atual;
nao concluir ausencia de backend/Functions/secret. Sem novo login ou leitura de
valores de credenciais. Evidencia privada candidate-functions-readiness-20261030
(.json/.log) fora do Git. Nenhuma URL remota confirmada.

Criado plano 2026-10-30-ativacao-trial-candidata.md com sequencia concreta e
bloqueios: acesso remoto, escopo sem deploy, endpoint vazio, catalogo aprovado
vazio e aparelho desconectado. Localmente a preparacao/contrato trial ja passou;
nao repetir testes para substituir ativacao remota. Nao afirmar que o trial esta
ativo no APK. Nenhum recurso remoto/secret/config de versao congelada alterado,
novo APK, CI, commit ou publicacao. git diff --check aprovado.


### 30/10/2026 — Console candidato confirma bloqueio de plano Spark

Captura fornecida pelo operador na pagina Functions do projeto
rocha-plus-candidate mostra plano Spark e aviso Para usar Functions, faca upgrade
do plano de precos do seu projeto. Isto estabelece bloqueio de provisionamento
Functions nesse plano, independente da autenticacao CLI indisponivel. Login do
operador no navegador nao autenticou o executor. Nao presumir endpoint candidato
ativo/utilizavel com base na preparacao local.

Para hospedar a composicao Functions preparada, seria necessario habilitar
faturamento/plano compativel (Blaze) e realizar implantacao; ambos nao executados.
Upgrade pode gerar custos e nao deve ser tratado como correcao de login ou passo
silencioso. Nao orientado clique em upgrade. Mantidos Spark, flags OFF, endpoint
vazio e restricao sem deploy. Alternativa sem upgrade exigiria arquitetura de
backend confiavel em outro ambiente ou avaliacao de regras/fluxo Spark ja existente;
nao mover concessao de trial para o cliente, reutilizar Oficial ou declarar
compatibilidade equivalente sem validacao. Preparacao/testes locais continuam
aprovados; ativacao remota no APK ainda bloqueada. Nenhum teste verde repetido,
novo APK, pagamento, secret, CI, commit/push/merge, deploy ou publicacao.


### 30/10/2026 — pedido de aumento de cota enviado pelo operador

Evidencias adicionais do Console Google Cloud confirmaram projeto
rocha-plus-candidate sem conta de faturamento vinculada e tentativa bloqueada
pelo limite de projetos com faturamento ativado. Conta de faturamento existente
aparece Ativa; nao foi necessario criar outra conta. Declaracao anterior do
operador de tres projetos vinculados nao confirmou vinculo candidato; tela de
linkedaccount especifica esclareceu ausencia efetiva. Nao houve downgrade
comprovado nem alteracao dos projetos existentes.

Operador preencheu formulario billing_quota_increase com motivo Associating more
projects with my billing account e justificativa de um projeto existente adicional
para homologacao isolada. Captura final confirma Your email has been sent e
request for additional quota successfully submitted. Estado: ENVIADO, AGUARDANDO
ANALISE; nao aprovado. Pagina informa resposta tipicamente em cerca de dois dias
uteis, podendo demorar mais, para e-mail informado. Nenhum numero de chamado
visivel nesta captura. Nao registrar ID de faturamento ou dados pessoais no Git.

Nao repetir formulario nem vinculo enquanto aguarda resposta. Proximo passo apos
aprovacao efetiva: verificar cota e concluir vinculo do candidato a conta existente,
reconferir plano, sem mexer nos outros projetos. Isso nao implanta backend,
autentica executor ou configura APK. Deploy/ativacao continuam separados e nao
executados. Logs/testes locais verdes preservados; nenhum APK, pagamento, grant,
CI, commit/push/merge, publicacao ou mudanca de layout nesta continuidade.


### 30/10/2026 — proxima etapa independente: catalogo focal planejado

Reaproveitados documentos existentes, sem reexecutar auditoria/varredura verde.
Criado docs/lab/candidate-focused-evidence-plan-20261030.json: oito fontes de
conferencia, duas SBT com decodificacao historica preservada e seis Windows
inconclusivas referenciadas pela auditoria ja salva. Nao e lista de aprovados.
SBT precisa de evidencia Android; nao repetir rodadas FFmpeg verdes. Seis fontes
precisam primeiro de evidencia complementar, nao inferir aprovacao nem rodar
transmissoes automaticamente. Plano explicita doNotRepeat/missingEvidence e
zero novos testes de stream. Relatorio detalhado 2026-10-30-proxima-etapa-catalogo.md.
Snapshot candidato segue vazio/bloqueado, nenhuma URL ou catalogo alterado,
nenhum canal aprovado removido, APK ou CI gerado. Pedido Google aguardando
analise, sem reenvio. Pagamento/trial verdes preservados dentro dos seus limites.


### 30/10/2026 — aumento de cota APROVADO por e-mail

Captura do operador mostra mensagem Google Cloud Compliance, assunto Quota
Granted - Paid Cloud Services, informando aprovacao da solicitacao de cota
adicional. Prazo informado: nova cota deve entrar em vigor dentro de uma hora
apos recebimento. Atualiza estado anterior aguardando analise para APROVADO;
nao repetir formulario ou presumir que o vinculo foi concluido automaticamente.
Nao registrar endereco do remetente, IDs de faturamento ou dados pessoais no Git.

Proximo passo do operador: rever linkedaccount do projeto rocha-plus-candidate e
concluir vinculo com a conta existente quando cota efetiva, preservando demais
projetos. Verificar resultado e plano depois. Aprovacao da cota nao e deploy,
nao autentica executor, nao cria backend nem altera endpoint do APK. Sem reenvio,
novo pagamento, grant, CI, commit, APK ou implantacao pelo agente.

Trabalho independente em curso preservado: preparado coletor
 tools/windows/collect_candidate_diagnostics.py (somente get-state, dumpsys
package candidato, pidof e logcat -d do PID). Nao instala/inicia/limpa dados ou
logs; salva somente versao e contagens expurgadas sem logs brutos/URLs/tokens/
serial. Quatro testes novos com ADB simulado aprovados, incluindo ausencia de
pacote, PID ambiguo e ausencia de erros nao equivale a aprovacao. Windows real
e aparelho ainda nao exercitados. Nao confundir este coletor com teste fisico
concluido; nao e substituto de evidencia audiovisual.


### 30/10/2026 — vinculo de faturamento candidato CONFIRMADO

Captura da pagina Google Cloud Gerenciamento da conta mostra explicitamente
rocha-plus-candidate na tabela Projetos vinculados a esta conta de faturamento,
com os demais projetos preservados. Captura anterior da mesma conta mostrava
Conta paga. Pedido de cota aprovado e vinculo agora comprovado pela UI; bloqueio
de cota/vinculo resolvido. Nao repetir upgrade, vinculo ou formulario.
Nao guardar codigo da conta ou dados financeiros no Git. Tela Foundation Builder
vista antes era configuracao de organizacao com demanda de varios projetos,
nao requisito para esta candidata; nao iniciar provisionamento por esse fluxo.

Isso nao comprova Functions implantadas, endpoint disponivel, autenticacao CLI
restabelecida ou trial ativo no APK. Proximo passo somente leitura: atualizar
Functions do projeto candidato para verificar estado/lista efetiva. Nao clicar
em iniciar implantacao ou alterar recursos. Restricoes sem deploy/commit/CI/APK
permanecem. Testes e dados originais aprovados preservados, sem reexecucao.


### 30/10/2026 — deploy SOMENTE trial autorizado; pacote pronto, autenticacao bloqueada

Apos pergunta explicita de autorizacao restrita ao backend trial candidato,
operador respondeu avancar. Escopo: apenas endpoint trial no projeto
rocha-plus-candidate; nao autoriza pagamentos/notificacoes, site, merge, CI,
publicacao ou novo APK. Captura Authentication mostra usuario Google existente;
nao recriar conta ou repetir cadastro/login fisico. Sem PII copiada para Git.

Criado trial_only_entry.js com guard de projeto antes de importar SDK, recusa
emuladores; exporta somente candidateTrialEntitlement (minInstances=0,
maxInstances=2). Dois cenarios novos de entrypoint aprovados; teste de importacao
do pacote real com dependencias resolvidas confirmou um unico export e nao
invocou handler. Suites trial/emulador/Flutter verdes nao repetidas.

Pacote separado fora do checkout em
[custódia local privada; não publicada] npm ci concluido
com lockfile existente, sem scripts, sem alterar lockfile do repositorio.
Codebase rocha-candidate-trial, configuracao limitada a Functions, flag de
ativacao true no pacote autorizado (nao aplicada remotamente). Nenhum export
pagamento/FCM/cron ou dependencia de reconciliacao incluida. ZIP de entrega
/workspace/rocha-candidate-trial-deploy-delivery/rocha-candidate-trial-only-20261030.zip
verificado legivel, com manifesto/hash privado, sem credenciais.

Preflight functions:list novamente necessario antes do deploy agora autorizado:
retornou bloqueio de autenticacao, nenhum recurso remoto alterado. login:list
nao estabeleceu conta autenticada; sem inferir conta pelo login Console. Runtime
nao oferece identidade externa configurada. Nao executar deploy sem acesso.
Plano alternativo concreto: Cloud Shell do proprio operador, autenticacao mantida
no terminal/browser, upload do pacote e comando --only do endpoint especifico.
Nao solicitar token/codigo de login pelo chat. Sem deploy executado nesta rodada;
URL nao estabelecida, endpoint do APK vazio. Faturamento vinculado preservado.


### 30/10/2026 — Cloud Shell aberto; entrega ZIP bloqueada no chat

Captura do operador confirma Cloud Shell no projeto rocha-plus-candidate.
Nao equivale a autenticacao deste executor. Download do ZIP falhou no cliente;
nao insistir nem copiar arquivos manualmente por partes. Preparado comando de
transferencia direta transferir-cloud-shell.txt, pacote embutido base64 com
SHA-256 obrigatorio, extracao em pasta temporaria nova sem sobrescrever checkout.
Nao contem credenciais, chaves, APKs ou pagamentos; nao executa deploy.

Pacote minimo mantem quatro modulos trial/read, mas notification_policy fornece
somente DAY, sem planejador/FCM. Dependencias diretas pinadas nas versoes do
lockfile aprovado. Lockfile completo nao incluido nesta transferencia minima;
usar npm install --ignore-scripts para materializacao posterior, nao npm ci.
Transitive resolution nova deve ser conferida antes de deploy. Transferencia
simulada localmente, SHA e importacao com dependencias ja resolvidas conferidos;
unico export candidateTrialEntitlement, nenhum handler invocado. Script de
transferencia 5324 caracteres, ZIP embutido 3604 bytes. Sem suite verde repetida.
Nenhum deploy/cloud recurso alterado nesta etapa; permissao restrita trial
candidato continua vigente e autenticacao de execucao sera no Cloud Shell.


### 30/10/2026 — Cloud Shell pronto; API Functions habilitada

Capturas operador: transferencia base64 com SHA-256 aprovado em pasta temporaria
Cloud Shell /tmp/rocha-trial-only-agdhk48j, npm install concluiu 252 pacotes;
Node inicialmente 24 foi alinhado para 22.23.4 por nvm, checksum conferido.
Nao repetir instalacao ou toolchain aprovados. Firebase CLI functions:list
falhou com mensagem generica e nao gerou firebase-debug.log; gcloud list
explicitou API cloudfunctions.googleapis.com desabilitada no candidato.

Operador confirmou y no prompt de habilitacao, dentro da autorizacao de deploy
trial candidato. Captura final confirma habilitacao concluida e Listed 0 items
na consulta us-central1. Nao concluir ausencia global em outras regioes. Acesso
gcloud funciona no Cloud Shell do operador; executor Codex segue separado.
Nao pedir novo login Firebase por rotina ou tratar falha anterior como perda
obrigatoria de credencial; API desabilitada foi causa comprovada nesta consulta.

Proxima operacao autorizada: deploy seletivo codebase rocha-candidate-trial,
endpoint candidateTrialEntitlement, projeto explicito rocha-plus-candidate,
configuracao minima transferida. Nenhum deploy comprovado ate esta captura,
nenhuma URL estabelecida; app permanece com endpoint vazio. Oficial, pagamentos,
FCM/cron, regras Firestore, site e APKs nao fazem parte desse deploy. Sem commit,
push, CI, merge ou nova compra.


### 30/10/2026 — DEPLOY TRIAL CANDIDATO confirmado e endpoint protegido

Captura Cloud Shell confirma Node.js22/2nd Gen candidateTrialEntitlement em
us-central1 criado com Successful create operation, projeto rocha-plus-candidate,
codebase rocha-candidate-trial e URL real:
https://us-central1-rocha-plus-candidate.cloudfunctions.net/candidateTrialEntitlement
Upload e criacao concluidos. APIs auxiliares necessarias ao deploy foram habilitadas
pela CLI no candidato. Nenhum export pagamento, notificacao ou cron implantado
por esse pacote. Faturamento e projeto Oficial permanecem fora dessa operacao.

Erro final CLI refere somente ausencia de cleanup policy das imagens em
Artifact Registry us-central1; funcao foi implantada. Nao repetir deploy nem
usar --force global para tratar a mensagem. Politica de retencao e ajuste separado
restrito a imagens de build, pendente. CLI local consultada confirma
functions:artifacts:setpolicy --location --days, aplicavel ao projeto explicito.

Validacao externa NOVA pelo agente, sem credenciais: GET endpoint => HTTP401,
allowed=false; POST => HTTP405, allowed=false; ambos Cache-Control=no-store.
Nenhum trial concedido; metodos proibidos e requisicao anonima nao liberam acesso.
Evidencia privada endpoint-unauthenticated-validation.json no pacote privado.
Nao e teste de token Google real, ativacao Firestore real ou mensagem fisica.
APK .3 ainda sem endpoint e sem novo codigo; nova build continua dependente do
catalogo/evidencias. Nao declarar trial/app finalizados por deploy. Sem commit,
push, merge, CI, APK ou publicacao de site nesta etapa. Apenas deploy especifico
trial candidato foi autorizado e executado pelo operador.


### 30/10/2026 — cleanup policy configurada; pendencia pos-deploy resolvida

Captura Cloud Shell confirma Successfully set up cleanup policy that deletes
images older than 7 days, restrita ao repositorio gcf-artifacts em us-central1
no projeto rocha-plus-candidate. Operador confirmou o prompt apos explicacao.
Nao repetir deploy, politica ou testes anonimos GET401/POST405 ja aprovados.
Erro final anterior era configuracao pos-deploy, agora resolvida. Retencao de
imagens de build nao e exclusao da funcao em execucao ou de dados dos usuarios.

Estado remoto comprovado: trial-only endpoint implantado; acesso anonimo negado,
metodo POST recusado; retencao configurada. Ainda NAO comprovados: consulta com
ID token de usuario candidato real, criacao/leitura Firestore cloud do trial,
configuracao de endpoint no APK instalado e mensagem no aparelho. Nao promover
contratos emulador/HTTP Mock para prova fisica. Pagamentos/notificacoes reais nao
foram implantados nem ativados pelo pacote. Oficial/USBQA/LAB714 preservados.
Sem commit/push/merge/CI, APK novo ou publicacao de site.


## 30/10/2026 — Firestore remoto criado e URL do preparador corrigida

Capturas do operador confirmam API Firestore habilitada, banco `(default)`
Firestore Native em `us-central1`, funcao `candidateTrialEntitlement` ACTIVE
 e conta de execucao com `roles/editor` no projeto candidato. Nenhuma concessao
IAM adicional foi feita nesta etapa. Isso nao prova chamada autenticada ou trial
ativo; o papel Editor e mais amplo que o necessario e nao foi alterado aqui.

O preparador ainda exigia o endpoint antigo `southamerica-east1/.../entitlement`.
Corrigido para a funcao efetivamente publicada em
`https://us-central1-rocha-plus-candidate.cloudfunctions.net/candidateTrialEntitlement`.
A URL antiga do candidato agora integra os casos rejeitados, e a configuracao
emitida e conferida contra a URL publicada. Seis testes focados do preparador
passaram. Sem novo deploy, APK, commit, push ou varredura de transmissoes.

Catalogo aprovado permanece vazio: registros disponiveis nao permitem liberar
canais automaticamente. Proxima dependencia externa e validacao audiovisual
focal em aparelho, comecando pelas duas fontes SBT que ja possuem registros
FFmpeg, preservando os resultados existentes sem repetir 479 fontes.


## 30/10 — revisao manual com remocao persistente, pedido atualizado

Ver [escopo e evidencias](2026-10-30-remocao-manual-candidata.md). O pedido de
revisar o catalogo atual substitui a proposta anterior de APK com somente dois
SBT, exclusivamente no modo candidato de revisao manual. Nao e homologacao
automatica do diretorio. Oficial/LAB/USBQA preservados.


## 30/10 — exportacao manual recebida: 372 remocoes

Ver [revisao manual aplicada na candidata .6](2026-10-30-catalogo-revisao-manual-final.md).
Decisoes do operador incorporadas permanentemente, com PET/Infantil, ordem das
seis Noticias e abas. Nenhuma nova varredura ou aprovacao inferida dos restantes.


## Candidata .6 congelada por pedido expresso do operador

Ver [registro de congelamento](candidate-6-congelada.md). Binario e assinatura
preservados; futuras alteracoes exigem nova versao. Sem nova homologacao inferida.


## Trial exibido como ativo na captura do operador

Ver [evidencia visual](trial-confirmacao-visual-operador.md): validade
06/11/2026 17:50 UTC. Bloqueio segue desativado; expiracao efetiva e pagamentos
nao foram comprovados pela imagem. Candidata .6 congelada preservada.


## Mercado Pago — pre-homologacao em consulta, sem repetir testes verdes

Ver [relatorio](2026-10-30-mercado-pago-pre-homologacao-readonly.md): TEST-
indisponivel no executor, nenhum recibo live_mode=false confirmado, emuladores
configurados mas inativos e plano revisado pendente. PR #42 OPEN/draft conferida.
Nao homologado; zero pagamentos, novas chamadas MP ou mudancas de codigo.


## Revisao pontual APP_USR- — sem mudanca de validacao

Ver [revisao pontual](2026-10-30-mercado-pago-app-usr-revisao-pontual.md).
O helper atual ja aceita o formato APP_USR- com identidade de conta verificada;
a restricao TEST- da pre-homologacao era escopo da tarefa, nao um bloqueio
sintatico atual. Documentacao oficial web retornou 403; exclusividade de uma
credencial real de teste nao comprovada. Guardas preservadas; nenhum codigo,
teste verde, pagamento, commit, APK, deploy ou estado de PR alterado nesta etapa.
