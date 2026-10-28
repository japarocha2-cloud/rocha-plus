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
