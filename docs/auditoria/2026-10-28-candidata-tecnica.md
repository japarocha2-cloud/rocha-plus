# Homologação técnica e candidata — 28/10/2026

Estado: AMARELO; distribuição bloqueada. Branch isolada
`homolog/technical-candidate-20261028`, baseada em
`61780147654b42709070702a677eec24b33a2ac5` do PR #42, que permanece draft.
Não houve merge, deploy, publicação, cobrança, substituição de APK, mudança
visual, remoção de canal ou alteração de Oficial, USBQA e LAB 714.

## 1. LAB 714 e candidata separada

[Build 714](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40601852385),
fonte `c5cf28af77bd2791c209f96d7ee7ee1c530be59a`: sucesso nos jobs
entitlement e homologation-login; compilação release assinada e verificação
de pacote/certificado OAuth aprovadas. Artefato `12778908400`,
`rocha-plus-homologacao-subscription-lab`, 99.939.280 bytes.
Digest informado pela API para o ZIP:
`59546f50b15d85077e867481aa6f46ac78968a87d2cbc39ed2f6b33ecd4ce888`.
Isso não é o SHA-256 do APK. Download via gh retornou Forbidden no armazenamento
de artefatos; não foi possível reconferir APK, ABIs e certificado localmente.

As correções VLC, Cast, foco e assinatura anteriores já integram a base;
não foram reaplicadas. A branch desta etapa separa o código candidato da LAB.
Não existe APK público candidato homologado. Os preparadores assinados atuais
exigem `.lab` e branches explícitas; não foram relaxados para reutilizar a
identidade LAB. Antes de uma candidata instalável em paralelo: definir pacote
próprio diferente de Oficial/LAB/USBQA, registrar OAuth/Firebase desse pacote,
provisionar assinatura própria e conferir configurações de sandbox. Não copiar
secrets ou credenciais para o repositório. Nenhum número de build foi reservado.
`pubspec.yaml` continua `0.1.0+1`; o workflow LAB usa `--build-number` da execução
(714 no caminho padrão), não uma versão pública candidata.

## 2. Login e trial

Preservadas regressões de troca de conta, token, offline, retomada e reabertura,
e a evidência física positiva de consulta no LAB 713 em
[assinatura física](2026-10-27-assinatura-fisica.md). Não equivale a cadastro,
login novo, trial ou pagamento homologado.

Correção desta etapa: `functions/index.js` agora retorna `expiresAt` e
`trialStartedAt` em UTC a partir dos timestamps persistidos pelo servidor.
Prioridade de motivo continua pago, trial, expirado. Datas ausentes retornam
null; registro existente não recebe novo trial. A tela já aceita `expiresAt`;
nenhum layout foi alterado. Implantação não realizada: o endpoint atualmente
implantado não passa a fornecer essas datas por causa deste commit.

O trial começa na primeira consulta autenticada de entitlement, não simplesmente
no cadastro. A transação cria uma vez por UID; sete dias são 7 × 24 horas pelo
servidor. Isso não impede uma pessoa de criar UIDs diferentes. Notificações
push/email/agendadas de vencimento não foram encontradas em `functions/index.js`
nem no fluxo de assinatura inspecionado. O serviço de notificação de mídia
Android não comprova aviso de trial. Avisos automáticos continuam pendentes.

## 3. Assinaturas e pagamentos

A base já contém reconciliação privilegiada, idempotência, estornos e escolha
do maior vencimento sem acumulação automática. Consulte `functions/README.md`:
a antiga divergência de cálculo está resolvida em código; integração operacional
não está homologada. Fixtures não comprovam compra sandbox.

Nenhum pagamento real ou sandbox foi iniciado. Não há credenciais do provedor
configuradas neste ambiente. Pendem compra e estorno ponta a ponta em sandbox,
revisão independente de UID/plano/recebedor/valor e consulta de acesso no app.
Firestore real/emulador com concorrência e retries continua pendente; o harness
em memória não comprova isolamento transacional do Firestore.

## 4. Players e Chromecast

Preservadas correções `2321b26`, `29a785e`, `88e539a` e testes verdes do PR.
Não há evidência nova que justifique refazer essas correções. Validar em aparelho:
ExoPlayer e VLC, troca rápida de canais, erro/retry, desconectar Cast, retorno
local, reconexão, rede perdida/restaurada e ausência de sucesso para mídia errada.
Registrar imagem e áudio contínuos; eventos simulados não provam decoder nativo.

## 5. Android TV e roteiro físico

Usar também `matriz-fisica-20261027.csv`. Registrar fabricante/modelo, Android,
ABI, rede, build, SHA-256, engine, fonte autorizada e tempo de cada observação.
- D-pad: foco inicial, seleção, CH repetido, retry, fullscreen e Voltar.
- Cada engine: 60 s de imagem/áudio e 180 s de confirmação por canal.
- Estabilidade: sessão de 60 min, trocas e interrupções de rede; registrar memória,
  travamentos e recuperação, sem promover resultado parcial a aprovação global.
- Cast: desconexão do receiver durante reprodução e confirmação do retorno local.
- Contas dedicadas: primeira ativação, datas, saída/entrada, troca de conta,
  reinício/reinstalação, vencimento e renovação sandbox; sem mudar relógio do
  servidor nem conceder acesso a contas reais.

## 6. Validação e continuidade

[CI da base 40645464203](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40645464203):
backend, entitlement, android-configuration e Flutter aprovados, incluindo
`flutter analyze` completo e testes Flutter; APK skipped intencionalmente.
Não repetir manualmente essas tarefas verdes sem regressão. Oito testes locais
do endpoint passaram após a mudança (Node 24.19.0); CI usa Node 22.
CI da branch isolada será registrado abaixo após conclusão. A execução final
é necessária para validar a nova resposta do endpoint e preservar compatibilidade.

Flutter e SDK Android não estão disponíveis neste executor; nenhuma compilação
local foi declarada aprovada. Novo APK só será viável com toolchain e identidade
separada; assinatura, SHA-256, versionName/code e ABIs devem ser extraídos do
novo binário, não inferidos do código nem do APK LAB. Não publicar artefato.

Próximos passos: concluir CI, configurar identidade candidata isolada, executar
sandbox/Firestore e roteiro físico, conferir evidências de autorização dos canais.
Distribuição segue bloqueada por essas lacunas; versão oficial preservada.

### Resultado final desta etapa

Commit de implementação: `a1cd34792f65f44ade64be6b215fa625d6ea66e6`.
[CI 40684071278](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40684071278)
concluído com **success** no código acima: backend, entitlement,
android-configuration e Flutter aprovados. Suíte Flutter completa,
`flutter analyze` e política opt-in experimental aprovados. APK **skipped**,
conforme a guarda existente; não houve compilação Android nova.
Os oito testes locais do endpoint também passaram. Este adendo é documental
com `[skip ci]`; não reexecutar a suíte verde por ele.

Concluído: histórico/CI revisados, base verde preservada, LAB 714 analisada,
branch separada, resposta de datas corrigida com regressões, CI final aprovado
e pendências registradas. Não concluído: APK candidato, homologação física,
compra sandbox E2E, concorrência Firestore e notificações automáticas.

### Continuação — Firestore Emulator Standard

Nova suíte em `functions/emulator/`, com CLI 15.34.1 e emulador 1.22.0,
projeto local descartável `demo-rocha-concurrency`. Nenhum banco cloud consultado
ou alterado. Guardas rejeitam projeto diferente e host fora do loopback antes
de inicializar o SDK. A verificação negativa sem variáveis do emulador foi
executada e recusada como esperado.

Execução local final: **6 testes aprovados**, incluindo o teste agregador.
Cinco cenários: trial concorrente/vencimento exato; mesmo pagamento concorrente;
planos mensal/anual simultâneos; replay do estorno mensal mantendo anual;
estorno da última assinatura negando acesso sem reiniciar trial.
SDK registrou **10 operações, 17 tentativas, 7 retries**. Contagens finais de
eventos, `paidUntil`, campos originais do trial e resposta do endpoint conferidos.
Isso resolve a lacuna de concorrência/retry **no emulador** nesses cenários;
não comprova concorrência cloud, IAM/regras nem compra sandbox.

Uma falha inicial foi do harness que carregava o endpoint em outro contexto
JavaScript incompatível com o SDK; corrigido o carregador de teste. Nenhuma
mudança adicional no código de produção, fluxo de pagamentos ou layout.
O CI novo é específico da suíte de emulador. Filtros evitam reexecutar a suíte
Flutter verde por mudanças exclusivas de documentação/emulador; o CI geral
continua cobrindo mudanças no aplicativo e nos módulos de produção.

Pendências mantidas: identidade e build candidata separada, login/trial físico,
notificações automáticas, compra/estorno sandbox E2E, testes TV/Cast e autorizações
de distribuição. Não confundir fixtures `live_mode: true` com transações reais.
Não há alteração na função implantada nem ativação de webhook/reconciliação.

### CI da continuação e commits

- `5e9096a`: filtros de CI para preservar suítes verdes em mudanças exclusivas
  de emulador/documentação (`[skip ci]`).
- `e1d7e692bf237c96375ef93bdc2eb8f62cb83fef`: suíte e job dedicados ao emulador.
- [CI 40686132051](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40686132051):
  **success**, Node 22, Java 21, Standard Emulator; 6 testes aprovados,
  10 operações, 19 tentativas, **9 retries** observados. Nenhum abort simulado.
- A execução geral `40686132022`, disparada pelo push que também continha a
  mudança dos filtros, foi cancelada para evitar repetição redundante. Isso
  não invalida nem substitui o CI verde `40684071278`; não houve mudança de
  código de produção nesta continuação.

Bloqueio sandbox adicional confirmado na inspeção:
`reconcileAndGrant` e `eligiblePayment` exigem `liveMode === true`. Credenciais
sandbox sozinhas não permitem homologação positiva pelo módulo atual; preparar
um caminho explicitamente isolado sem remover a guarda existente. Nenhum
pagamento real pode ser usado como alternativa. Compras, notificações e respostas
de estorno fora de ordem do provedor não estão homologadas por este teste local.

A etapa avançou somente na pendência de concorrência Firestore. APK, assinatura,
OAuth próprios da candidata, aparelhos físicos e pagamentos sandbox continuam
bloqueados pelas condições registradas acima. Oficial, USBQA, LAB 714, PR #42
e site oficial permanecem preservados; sem publicação, merge ou deploy.

### Continuação — caminho sandbox e configuração candidata independentes

Escopo solicitado: preservar o reconciliador de produção e permitir homologação
sandbox isolada. `5e9096a`, `e1d7e69` e `8962a64` consultados; continuidade na mesma
branch, sem reiniciar a rodada anterior.

**Sandbox:** criado módulo separado em `functions/sandbox/reconcile.js`, sem
importação no aplicativo ou nas Functions implantáveis. Exige projeto
`demo-rocha-sandbox`, host loopback, credencial `TEST-` e resposta obtida por GET
com `live_mode === false` explícito. Grava somente coleções `sandbox_*` no
emulador; recusa banco cloud, modo real, ID/recebedor/valor/claim divergentes.
Os arquivos de produção `reconcile_and_grant.js` e
`mercadopago_reconciliation.js` permanecem byte a byte inalterados; teste fixa
seus hashes e verifica que o predicado de produção continua negando sandbox.
Não foi criada flag para afrouxar `liveMode === true` na produção.

Teste local final: **9 testes aprovados** (incluindo agregador), 14 operações,
22 tentativas, 8 retries do SDK. Compra aprovada e renovação por novo ID com
respostas simuladas `live_mode=false`, replay concorrente/idempotência, estorno
preservando renovação independente, último estorno retirando validade paga sem
reiniciar trial expirado e resposta obsoleta sem ressuscitar período estornado.
Conferidas coleções de produção vazias. Nenhuma chamada POST/cobrança/estorno
remoto é implementada no cliente; o leitor usa somente GET do provedor.

**Limite da evidência:** respostas do Mercado Pago foram simuladas; SDK e
transações Firestore foram reais no emulador. Não há token/test users/transação
sandbox configurados neste ambiente. Portanto compra, renovação e estorno
ponta a ponta no Mercado Pago continuam pendentes, embora o caminho isolado
agora aceite pagamentos sandbox válidos sem alterar produção.

**Candidata:** identidade de release reservada `com.rochaplus.app.candidate`,
debug `.candidate.debug`; projeto proposto `rocha-plus-candidate` ainda não
provisionado. Versão planejada `0.1.0-candidate.1`, versionCode `1` (pacote novo,
sem alterar códigos Oficial/LAB/USBQA). Preparador próprio em `tools/candidate/`
valida projeto, pacote, OAuth Android, SHA-1 independente e cliente web antes
de alterar um scaffold gerado. Rejeita endpoint Oficial/LAB, assinatura ausente,
branch/disparo incorretos e fallback de assinatura debug no release.

Chave exclusiva RSA 3072/PKCS12 criada localmente fora do checkout:
`/workspace/rocha-candidate-private`, diretório 700 e arquivos 600. Senha aleatória
somente no JSON privado, não impressa nem registrada no Git. Não substitui chave
existente. Impressões públicas em `tools/candidate/signer-public.json`:
SHA-1 `e2f0e4efa910b18b93fce60e9944f7ddf48ee02b`;
SHA-256 `1103e22ab107a77ad3e6ef8b0d327e44240b91b9a4c0bbbad2d258185e0c696b`.
Custódia/backup privado e secrets de build ainda não configurados; a chave está
somente neste workspace. Não depender de atualização futura sem essa custódia.

**Testes da candidata:** 5 testes Python aprovados. Cobrem isolamento, rejeição
OAuth/pacote/certificado, ausência de mutação em configuração inválida, Gradle
independente, metadados/versões/ABIs e verificador de assinatura/SHA-256. Os testes
de APK usam ferramentas simuladas; não comprovam APK real. O verificador futuro
exige apksigner válido e impressões SHA-1/SHA-256 correspondentes à chave própria.

**Pendências reais:** criar/configurar projeto e OAuth próprios, obter Google
Services real, guardar chave em custódia segura, preparar build runner/toolchain,
validar endpoint candidato, compilar e inspecionar o APK; executar compra/renovação/
estorno sandbox E2E e testes físicos. Não houve criação remota de projeto, OAuth,
conta, backend ou regras, nem build/deploy/publicação. Notificações automáticas,
TV/Cast físicos e autorização de distribuição continuam pendentes.

Os problemas iniciais locais foram configuração do ruleset do novo emulador e
credencial customizada incompatível com o Admin SDK; corrigidos antes da execução
verde. Não eram falhas do reconciliador de produção. Job de CI novo testa apenas
sandbox/candidata; suítes Flutter/player/Cast e emulador anterior permanecem
preservadas. Resultado do CI e commits serão acrescentados após conclusão.

### Fechamento da rodada sandbox/candidata

Commits:
- `4bb02cb`: filtros para CI dedicado, publicado antes do código com `[skip ci]`.
- `9e49c5eb817c04bd2efea03b9d9c70d737b0bfcf`: módulo sandbox isolado, testes,
  preparador/verificador e identidade pública da candidata, documentação.

[CI 40688631610](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40688631610)
**success** no commit de implementação:
- `sandbox-emulator`: 9 testes aprovados, 14 operações, 23 tentativas e 9 retries;
  Node 22, Java 21 e Firestore Emulator Standard.
- `candidate-configuration`: 5 testes Python aprovados.
Nenhuma nova execução das suítes verdes Flutter/player/Cast, emulador anterior
ou build Android. Preservados os CIs `40684071278` e `40686132051`.

Verificação local adicional: impressões extraídas da chave real com keytool
correspondem exatamente a `signer-public.json`, com permissões privadas
conferidas. `git ls-files` não contém nova chave, senha, JSON de assinatura ou
Google Services. Nenhum APK foi gerado, inspecionado ou publicado nesta rodada.

**Evidência histórica preservada:** encontrada auditoria de recibo sandbox
[38702929655](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/38702929655),
15/10/2026, com os passos Verify test seller e Verify existing sandbox payment
without writes aprovados. Não foi reexecutada. O workflow existente referencia
`MP_TEST_ACCESS_TOKEN`; a consulta somente aos nomes de secrets retornou 403
(Resource not accessible by integration). Não inferir ausência do secret no
GitHub nem disponibilidade/validade atual. Nenhum valor de secret foi consultado.
Essa evidência histórica não comprova compra/renovação/estorno completos no novo
caminho isolado e não muda a pendência de E2E atual.

**Situação final: AMARELO.** Resolvido o bloqueio de aceitar `live_mode=false`
num caminho separado de testes; produção continua exigindo `live_mode=true`.
Configuração independente e chave candidata preparadas localmente. Faltam
credencial/test users atuais para E2E controlado, cadastro real Firebase/OAuth,
custódia da chave/secrets de build, toolchain/build do APK, validação física e
autorizações. Nada foi implantado ou publicado; Oficial, USBQA, LAB 714, site
e PR #42 preservados. Este fechamento é documental e usa `[skip ci]`.

### Preparação da build candidata — inspeção de 28/10/2026

**Estado: AMARELO; build assinada bloqueada por insumos e custódia.**
Inspeção da branch `homolog/technical-candidate-20261028`, HEAD
`98160d47f7a0ca341fbd7f80eda3db72fe0acb60`. Alteração desta rodada:
somente este relatório. Nenhuma configuração de conta/recurso externo foi
criada ou alterada. Nenhum comando de build, pagamento, deploy, publicação,
merge, atualização do site ou reexecução de teste foi realizado.

#### Confirmado por leitura de código e evidências existentes

- `tools/candidate/identity.json`: release `com.rochaplus.app.candidate`,
  debug `com.rochaplus.app.candidate.debug`, projeto esperado
  `rocha-plus-candidate`, provisionamento `pending`,
  versão planejada `0.1.0-candidate.1` / code `1`.
  Isso é uma reserva no código; não comprova existência/disponibilidade do
  project ID nem cadastro no console Firebase/Google Cloud.
- `prepare_candidate.py` exige disparo manual e branch exata, valida
  project ID/número, app Android/pacote, cliente OAuth Android/SHA-1 da chave
  fornecida e um único cliente web. Gera os defines fora do checkout e muda
  somente o scaffold Android gerado da cópia candidata.
- `lib/src/auth/firebase_auth_repository.dart` inicializa Firebase por
  `FirebaseOptions` e usa `ROCHA_GOOGLE_SERVER_CLIENT_ID` como cliente
  servidor/web. O Google Services é insumo do preparador; apenas copiar esse
  arquivo para Android não substitui os defines usados por este aplicativo.
- Não há Google Services candidato versionado na árvore inspecionada.
  Não houve acesso autenticado ao console/API do Firebase ou OAuth nesta
  rodada: existência, provedores habilitados, consentimento e IAM remotos
  continuam não verificados. Nenhum arquivo de Oficial/LAB deve preencher
  essa lacuna.
- `candidate-sandbox.yml` contém somente checks; não compila APK.
  Não existe workflow assinado dedicado à candidata. `build.yml` referencia
  preparadores/secrets de outras identidades: não disparar esse fluxo como
  substituto da preparação candidata.
- Reconferidos por GET os CIs verdes `40688631610`, `40686132051` e
  `40684071278`. No primeiro, ambos os jobs continuam **success**.
  Preservadas as contagens de testes registradas nas rodadas anteriores.
  Não houve suíte nova nem regressão de código nesta etapa.

#### Firebase/OAuth: configurações pendentes, somente após autorização

1. Confirmar conta proprietária e disponibilidade do projeto proposto
   `rocha-plus-candidate`; criar/selecionar apenas o projeto independente.
   Se o ID não estiver disponível, devolver a decisão ao responsável antes
   de mudar identidade/endpoint no código.
2. Registrar o app Android release com pacote exato
   `com.rochaplus.app.candidate`. O debug é outra identidade e só precisa
   de cadastro próprio se houver objetivo de testar login em debug.
3. Cadastrar o certificado original da candidata, após recuperar/conferir a
   chave: SHA-1 `e2f0e4efa910b18b93fce60e9944f7ddf48ee02b`;
   SHA-256
   `1103e22ab107a77ad3e6ef8b0d327e44240b91b9a4c0bbbad2d258185e0c696b`.
   São impressões públicas; não são a chave privada.
4. Habilitar Authentication/Google no projeto candidato; definir email de
   suporte e configuração OAuth/consentimento aplicável à conta, incluindo
   usuários de teste quando exigidos. Conferir cliente Android ligado ao
   pacote/SHA-1 e cliente web do mesmo projeto, usado como server client ID.
   Não criar secret OAuth web dentro do APK; o app requer o client ID.
5. Obter Google Services atualizado após esses cadastros e entregá-lo ao
   executor por canal privado, fora do Git. Conferir projeto, app ID,
   sender/project number, API key, cliente Android e cliente web.
   Os IDs e a API key Firebase são configuração de cliente, não substituem
   regras/IAM; manter o arquivo fora do Git conforme a restrição desta etapa.
6. Para login simples, o endpoint de entitlement não é requisito de compilação.
   Para homologar trial/bloqueio, será necessário backend isolado validado,
   Auth e dados/regras/IAM candidatos definidos. A URL planejada
   `https://southamerica-east1-rocha-plus-candidate.cloudfunctions.net/entitlement`
   não foi implantada ou validada. Qualquer criação/configuração externa
   exige autorização; deploy continua proibido nesta etapa.

Referências oficiais consultadas:
[Google Sign-In Android/Firebase](https://firebase.google.com/docs/auth/android/google-signin),
[cliente servidor/web](https://firebase.google.com/docs/auth/android/google-signin#authenticate_with_firebase)
e [proteção de chave Android](https://developer.android.com/studio/publish/app-signing#secure-key).

#### Mercado Pago: disponibilidade, sem valores de credenciais

- Não foram encontradas variáveis `MP_*`, `ROCHA_*`,
  Mercado Pago, keystore ou signing no ambiente deste executor; nenhuma
  credencial foi impressa, copiada ou enviada ao Git. Isso descreve somente
  este executor, não outros ambientes remotos do Codex.
- O workflow histórico referencia `MP_TEST_ACCESS_TOKEN`; a execução
  `38702929655` de 15/10/2026 foi reconferida como **success**, sem reexecução.
  O relatório anterior registra 403 ao listar nomes dos secrets.
  O conector atual não oferece leitura de secrets; disponibilidade e validade
  atuais no GitHub permanecem **não verificadas**, sem presumir ausência.
- O módulo novo recebe `ROCHA_MP_SANDBOX_ACCESS_TOKEN`, exige prefixo
  `TEST-` e resposta `live_mode=false`. Não trocar nomes automaticamente,
  relaxar a guarda ou usar token real para contornar incompatibilidade.
- Faltam confirmação privada de credencial compatível, test seller/buyer,
  meio de pagamento de teste e transação sandbox apropriada ao novo roteiro.
  Não foram realizadas chamadas ao Mercado Pago, criação de usuários,
  compras ou estornos. O token não deve entrar no APK nem nos defines Flutter.
- Credenciais Mercado Pago não são requisito para compilar o APK; são
  requisito da homologação E2E posterior, que continua pendente.

#### Chave exclusiva: localização e proposta de custódia

O caminho histórico `/workspace/rocha-candidate-private` **não existe no
executor desta inspeção**, cujo workspace é diferente do anterior.
Não foi possível conferir a chave original, permissões atuais ou backups.
Não afirmar perda definitiva nem disponibilidade da chave no Codex remoto.

Antes de encerrar/descartar o ambiente original, o responsável por aquele
ambiente deve localizar `candidate.p12` e `signing.json`, conferir alias e
impressões com keytool sem imprimir senha, e preservar os dois por canal
privado. Não executar `init-signing` como recuperação: uma chave nova não
reconstitui a chave original.

Proposta sujeita à autorização do proprietário: guardar o PKCS12 em cofre
privado com controle de acesso, backup cifrado e recuperação verificada;
guardar a senha em segredo separado. Definir responsável e método de
restauração. Permissões 700/600 protegem o uso local, mas não garantem
persistência do workspace nem substituem backup. GitHub Secrets, se escolhido,
pode fornecer insumos ao runner; não deve ser a única cópia de recuperação.
Base64 é transporte, não cifragem.

Não houve upload, exportação de chave, criação de cofre/secret ou mudança de
conta nesta etapa. Após autorização, restaurar os insumos temporariamente fora
do checkout, sem log de valores, escopo de acesso mínimo e limpeza após o uso.
Não anexar material privado a chat, relatório, artifact de CI ou commit.

Atenção para o próximo executor: o preparador confronta OAuth com a chave
fornecida, mas não fixa por si só essa chave a `signer-public.json`.
Conferir também as duas impressões públicas versionadas antes de preparar
o scaffold e antes de aceitar o APK; não aceitar substituição silenciosa.

#### Lista objetiva a devolver ao Codex para a compilação futura

- Checkout isolado da branch candidata e revisão deste adendo; preservar
  Oficial, USBQA, LAB 714, PR #42 e todos os testes verdes.
- Chave original recuperada, backup confirmado e insumos privados disponíveis:
  `candidate.p12`, `signing.json` com alias
  `rocha-candidate-20261028`, e Google Services real do projeto candidato.
- Runner/toolchain: Flutter `3.47.6` conforme workflow existente,
  SDK Android com API 37, JDK/Gradle compatíveis, keytool, aapt e apksigner;
  acesso às dependências e correções nativas já aprovadas preservadas.
  Neste executor não há flutter/dart/adb/aapt/apksigner no PATH; Java/keytool
  estão presentes. Nenhuma instalação ou compilação foi tentada.
- Gerar scaffold em cópia descartável com Flutter e aplicar
  `tools/configure_android.py` antes do preparador candidato.
  Não usar preparadores de Oficial/LAB ou seus secrets.
- Rodar `prepare_candidate.py prepare` com
  `GITHUB_REF=refs/heads/homolog/technical-candidate-20261028` e
  `GITHUB_EVENT_NAME=workflow_dispatch`, caminhos privados e identidade
  pública conferida. Em execução local essas variáveis são guardas de
  configuração; no futuro CI, restringir também branch/disparo/acesso a secrets.
- Carregar assinatura por ambiente no subprocesso, sem senha em argumento/log:
  `ROCHA_CANDIDATE_KEYSTORE`, `ROCHA_CANDIDATE_STORE_PASSWORD`,
  `ROCHA_CANDIDATE_KEY_ALIAS`. Os nomes são o contrato atual do preparador,
  não comprovam secrets provisionados em qualquer conta.
- Compilar APK release com `--build-name=0.1.0-candidate.1`,
  `--build-number=1` e `--dart-define-from-file=<privado>/dart-define.json`.
  O preparador gera os cinco defines Firebase/OAuth a partir do JSON validado.
  Não usar o número da execução LAB como versão candidata.
- Padrão atual: `ROCHA_CANDIDATE_SUBSCRIPTIONS=false` e
  `ROCHA_CANDIDATE_ENTITLEMENT_URL` vazia. Isso permite preparar a variante
  sem bloqueio, mas não homologa trial/assinatura nem autoriza distribuição.
  Só ativar `true` com endpoint candidato exato e validado, após decisão
  explícita; não apontar para Oficial/LAB.
- Executar o verificador de APK existente sobre o binário efetivo: pacote,
  versão/code, ABIs (ARM64 obrigatória), assinatura válida, SHA-1/SHA-256
  originais e SHA-256 do APK. Esse exame do novo artefato ainda é necessário
  e não repete testes verdes. Manter APK privado, sem publicação/substituição.
- Registrar evidência e limitações. Login/trial físico, TV/Cast, E2E Mercado
  Pago e notificações permanecem pendentes. Não promover build compilada a
  homologação completa.

**Autorizações pendentes:** criar/configurar apenas o projeto Firebase/OAuth
candidato; definir e configurar destino privado de custódia/backup e secrets
de build; eventual criação de app/usuários/configuração sandbox, se faltantes.
Nenhuma dessas autorizações é presumida. Deploy, publicação, merge, site e
pagamentos reais continuam fora de escopo. A próxima rodada deve retornar ao
Codex com as decisões autorizadas e referências privadas dos insumos, nunca
seus valores no texto.
