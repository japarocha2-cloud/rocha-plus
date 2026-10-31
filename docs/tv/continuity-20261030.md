# Continuidade técnica — Rocha+ TV — 30/10/2026

Trabalho experimental, sem publicação, merge, cobrança ou promoção de candidatos.
A identidade visual e as versões oficiais não foram alteradas.

## Estado confirmado no GitHub

- Android TV: `homolog/technical-candidate-20261028`; base
  `d99425311a1e109a7818b4cc313d2e542d696d0f`.
- Roku: `feat/roku-current-catalog-20261029`,
  `acf04b7fa53b81f19d74a4398169c9b2d441f8fc`; PR #43 aberto e draft.
- Assinatura: `fix/subscription-access-20261026`,
  `61780147654b42709070702a677eec24b33a2ac5`; PR #42 aberto e draft,
  sem alteração neste trabalho.
- As branches não foram mescladas. O catálogo Roku foi comparado por leitura
  dos objetos Git e dos artefatos, sem incorporar a branch ao Android.

## Local de execução

A análise, os testes Flutter e os builds Android foram executados nos runners
reais do GitHub Actions, com logs e commits identificados abaixo. O SDK Flutter
não foi instalado nesta máquina; a verificação dos pacotes baixados foi feita
neste workspace.

## Falha Android e correção

O [CI original](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41046833524)
falhou ao procurar `android/app/build.gradle`: o checkout não contém scaffold
Android, e o workflow tentava compilar diretamente.

Commit `33c6623cc1fb5383d6e4febcae05a55e27c508fe`:
cria scaffold temporário sem sobrescrever fontes Dart, aplica as ferramentas
Android/TV e bridge LAB existentes, fixa Flutter 3.47.9 (versão observada no CI
anterior), aplica a correção VLC LAB já existente e valida seu protocolo Pigeon.
Executa análise e suíte Flutter completa; compila somente debug com
`ROCHA_LAB_ONLY=true` e `ROCHA_TV_PARITY_12=true`.
A verificação exige assinatura válida, pacote `com.rochaplus.app.lab`, modo
debuggable e categoria `LEANBACK_LAUNCHER`. O artefato inclui lock de dependências,
evidências VLC, assinatura, badging e SHA-256.

A [primeira execução corrigida](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41047829906)
passou em 9 testes Python TV, análise sem problemas, 232 testes Flutter
(incluindo `tv_parity_lab_test.dart`) e protocolo
VLC, mas falhou em `:app:checkDebugAarMetadata`: `permission_handler_android`
exige compileSdk 37 e o scaffold usava 36. Commit
`4fba22f4ce2333dbfc1bc319f180baf08e7d5490` aplica compileSdk 37, como o workflow
principal já faz. A nova execução é necessária por essa mudança de configuração
nativa relacionada à falha, sem alteração de fontes, dependências ou layouts.

## Android TV: resultado final e pacote conferido

[CI 41048599655](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41048599655)
**concluído com sucesso**, fonte `4fba22f4ce2333dbfc1bc319f180baf08e7d5490`:
9 testes Python TV, análise sem problemas e **232 testes Flutter aprovados**,
incluindo `tv_parity_lab_test.dart`. Protocolo VLC validado e APK debug compilado.
As falhas anteriores foram de build/configuração, não falhas de testes Flutter.

[Artefato APK LAB](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41048599655/artifacts/12974306297)
(disponibilidade informada pelo GitHub até 13/11/2026).
[Exemplos compartilhados](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41048599655/artifacts/12974241503).

- Arquivo: `RochaPlus-AndroidTV-Paridade12-LAB-debug.apk`.
- Tamanho: 311.840.853 bytes.
- SHA-256 do APK baixado: `39d19842f0de3d75c55586f7b1d267ff08fc78f0ee9c4d767b4a59149a0a6486`.
- Pacote `com.rochaplus.app.lab`, versão `0.1.0+1`, debuggable,
  atividade `com.rochaplus.app.LabActivity`, categoria TV verificada no CI.
- compileSdk 37, targetSdk 36, minSdk 24 (Android 7.0 ou superior).
- ABIs conferidas no badging e nos cabeçalhos ELF de `libflutter.so`:
  `arm64-v8a` (64 bits), `armeabi-v7a` (32 bits), `x86_64` (64 bits).
- `apksigner verify --verbose --print-certs`: **Verifies**, assinatura v2 válida,
  um assinante `C=US, O=Android, CN=Android Debug`. Certificado SHA-256:
  `0940696e89f238040567406830cce312298ea33a127dad472707f34d8d67bb55`.
  É assinatura debug experimental, sem identidade de produção garantida entre builds.
- CRC do APK íntegro; hash coincide com `SHA256SUMS` do artefato.
  Asset de paridade tem 12 candidatos, todos não aprovados, e coincide byte a byte
  com a fonte. Os seis arquivos visuais/vinheta empacotados coincidem com a fonte.
- Comando registrado no log: `flutter build apk --debug
  --dart-define=ROCHA_LAB_ONLY=true --dart-define=ROCHA_TV_PARITY_12=true`.
  Isso comprova a configuração da compilação; a navegação/reprodução física continua pendente.

O artefato inclui `pubspec.lock`, `signature.txt`, `badging.txt`, `SHA256SUMS` e
relatórios VLC. Avisos remanescentes do CI: plugins ainda usam Kotlin Gradle
Plugin e ações/dependências Node apresentam depreciações. Não impediram este build;
acompanhar compatibilidade em futuras atualizações sem atualizar dependências aqui.

O commit de continuidade também explicita `shell: bash` no workflow, para que
execuções futuras preservem falhas em pipelines com `tee` (`pipefail`). Essa
configuração de shell e a documentação não alteram o conteúdo do APK acima;
seu commit-fonte permanece `4fba22f`. Não se recompila o mesmo código por essa
mudança de registro/propagação de falhas; a saída real `Verifies` foi conferida.

## Roku: evidência reutilizada e pacotes conferidos

[CI 40997693193](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40997693193)
concluído com sucesso no commit atual `acf04b7`:
6 testes Python aprovados; verificação de proveniência e IDs; compilação
BrighterScript 0.69.0 do catálogo de 395 e da amostra de 12; validação dos IDs e
política experimental. Logs do job `123874582464` foram efetivamente lidos.
Houve avisos de depreciação npm; não houve erro de compilação.
Não repetimos essa execução verde, conforme a restrição do plantão.

[Artefato Roku com os dois ZIPs](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40997693193/artifacts/12951868037).
Baixado e verificado: CRC dos dois ZIPs íntegro, manifesto experimental 0.6.1,
395 registros no catálogo, 12 na amostra, todos `approved=false`. Amostra
habilitada somente no ZIP LAB. IDs/URLs dos 12 coincidem com o asset Android.
Arquivos XML diferem das fontes apenas por formatação/ordenação e injeção de
`bslib` pelo compilador; nós e atributos visuais foram comparados e preservados.
O runtime `source/bslib.brs` é saída gerada pelo BrighterScript.

| Pacote | SHA-256 conferido sobre o arquivo baixado |
| --- | --- |
| `RochaPlus-Roku-0.6.1-Catalogo395-Teste.zip` | `68334b09260b58ebdd5e3b82f0e8f891812fb9a382fb2d15ef6e0eae43299ff6` |
| `RochaPlus-Roku-0.6.1-Amostra12-LAB.zip` | `0e9c51cc3192ba3b4a6581136197799a09a3d3cfc9891975c9e26be7228a41f5` |

Os dois ZIPs contêm os catálogos de 395 e 12; a configuração seleciona qual usar.
Portanto o ZIP de amostra não é uma versão que remove os outros candidatos.

## Validação física e próximos passos

Nenhuma reprodução física Android TV ou Roku foi comprovada neste plantão.
Também não foram validados login real, assinatura, cobrança ou Cast físico.
Seguir [o roteiro físico](physical-validation-20261030.md), começando pela amostra
idêntica de 12 canais em ambas as plataformas. Registrar primeiro quadro, áudio,
sincronismo, 180 segundos por canal, trocas, controle remoto, sessões longas,
perda/retorno da rede e ciclo de vida. Usar logs/vídeos identificados por pacote,
SHA-256, aparelho, canal e horário. Falha isolada não remove candidato.

Somente após essas evidências classificar cada resultado físico; os candidatos
permanecem experimentais e não aprovados para distribuição.


## Retomada e confirmação independente — 31/10/2026

- 🟢 Reconsultados via GitHub (somente leitura) os workflows Android `41048599655` e Roku `40997693193`: ambos status `completed`, conclusão `success`. Preservar testes verdes; não reexecutar.
- 🟢 Android: artefato `12974306297` (`rocha-android-tv-parity12-lab-debug`), ainda listado como disponível, expiração informada 13/11/2026. A fonte do build permanece no commit `4fba22f4ce2333dbfc1bc319f180baf08e7d5490`.
- 🟢 Roku: artefato `12951868037` (`RochaPlus-Roku-0.6.1-Catalogo395-Teste`), ainda listado como disponível, expiração informada 28/01/2027. Contém, segundo verificação anterior registrada, os ZIPs 395 candidatos e amostra LAB 12. Não reinterpretar o SHA-256 do ZIP de artefato como SHA-256 dos ZIPs internos.
- 🟢 Conferido estado do PR #42: aberto, `draft=true`, `merged=false`.
- 🟡 Confirmado que `docs/tv/physical-validation-20261030.md` continua com execução física **não executada**. O trabalho anterior gerou matriz/roteiro, não prova de áudio/vídeo em hardware. Falta indicar dispositivos de teste disponíveis para organizar coleta dirigida, mantendo separação Android/Roku.
- 🔒 Esta retomada não realizou builds, instalação, novos testes, merge, publicação, cobrança, mudanças visuais, promoção de candidatos nem acesso a aparelhos reais. APK `com.rochaplus.app.lab` não é o APK independente `com.rochaplus.app.candidate`.
- 👉 Próxima evidência útil: registros de execução do roteiro no(s) aparelho(s) físico(s), incluindo modelo, SHA-256 do pacote instalado, logs, canal, data/hora e observação. Somente nova regressão/alteração relacionada justifica reabrir testes verdes.
