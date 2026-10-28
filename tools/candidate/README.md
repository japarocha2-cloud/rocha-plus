# Identidade independente do APK candidato

Preparação local; sem build, cadastro remoto, deploy ou publicação automática.
Nenhuma alteração nos preparadores de Oficial, LAB ou USBQA.

- Pacote release reservado: `com.rochaplus.app.candidate`.
- Pacote debug gerado: `com.rochaplus.app.candidate.debug` (não `.lab`).
- Projeto Firebase proposto: `rocha-plus-candidate`, **ainda não provisionado**.
- Versão planejada: `0.1.0-candidate.1`, versionCode `1`, identidade de aplicativo nova.
- Endpoint, se bloqueio explicitamente ativado:
  `https://southamerica-east1-rocha-plus-candidate.cloudfunctions.net/entitlement`.
  **Não implantado ou validado.** Por padrão bloqueio desativado e URL vazia.

## Assinatura

`signer-public.json` contém somente SHA-1 e SHA-256 do certificado exclusivo
criado nesta etapa. A chave RSA 3072/PKCS12 e sua senha ficaram fora do repositório,
no diretório privado `/workspace/rocha-candidate-private`, com permissões 700
(diretório) e 600 (arquivos). Não são a chave oficial ou LAB. Não imprimir/copiar
`signing.json` para logs, Git ou artifacts.

A chave existe somente neste workspace; ainda requer custódia/backup privado e
configuração em secrets do ambiente de build antes de depender dela para futuras
atualizações. Não regenerar silenciosamente: `init-signing` recusa substituição.
A impressão pública deve ser cadastrada no OAuth Android do novo projeto, junto
do pacote correto; cadastrar também SHA-256 quando exigido pelo serviço.

Para criar uma identidade *nova* em outro ambiente, usar diretório privado novo,
fora do checkout, e revisar a mudança de impressões antes de qualquer atualização:

```sh
python3 tools/candidate/prepare_candidate.py init-signing --private /caminho/privado/novo
```

## OAuth/Firebase e scaffold

Provisionar separadamente o projeto indicado, registrar app Android do pacote
candidato e configurar Google Sign-In com o certificado e OAuth web desse projeto.
Este trabalho não criou projeto, clientes OAuth, contas, regras ou backend remoto.
Baixar o `google-services.json` real para o diretório privado. Nenhum valor
Firebase/OAuth fictício deve ser inserido como configuração pronta.

Depois, numa cópia de trabalho isolada desta branch, gerar scaffold com Flutter e
`tools/configure_android.py`. A preparação exige branch exata, disparo manual e
chave privada existente; o JSON é validado contra projeto/pacote/certificado e
cliente web únicos antes de alterar qualquer arquivo:

```sh
GITHUB_REF=refs/heads/homolog/technical-candidate-20261028 GITHUB_EVENT_NAME=workflow_dispatch \
python3 tools/candidate/prepare_candidate.py prepare \
  --private /workspace/rocha-candidate-private \
  --google-services /workspace/rocha-candidate-private/google-services.json
```

A saída Firebase/dart-define e metadados ficam somente na pasta privada. O Gradle
gerado recebe applicationId independente e signingConfig exclusivo; namespace,
artes, layouts e canais são preservados. Não há fallback de assinatura debug no
release. A versão deve ser aplicada na futura compilação com
`--build-name=0.1.0-candidate.1 --build-number=1` e
`--dart-define-from-file=/workspace/rocha-candidate-private/dart-define.json`.

O processo de build deve carregar o JSON privado de assinatura sem imprimi-lo e
passar ao subprocesso Flutter somente as variáveis:
`ROCHA_CANDIDATE_KEYSTORE` (caminho de `candidate.p12`),
`ROCHA_CANDIDATE_STORE_PASSWORD` (campo `password`) e
`ROCHA_CANDIDATE_KEY_ALIAS` (campo `alias`). Não passar senha na linha de comando.
Ainda não existe workflow de build assinado/secret provisionado para a candidata.

## Verificação futura do APK

```sh
python3 tools/candidate/prepare_candidate.py verify \
  --private /workspace/rocha-candidate-private \
  --apk /caminho/do/app-release.apk --build-tools /caminho/do/android/build-tools
```

O verificador exige pacote, versionCode/name, ARM64 e ABIs permitidas, verificação
criptográfica pelo apksigner e ambas as impressões do certificado independente.
Produz SHA-256 do APK e marca homologação física pendente. Os testes Python usam
ferramentas de APK simuladas: não são evidência de binário compilado/assinado.
Não publicar nem substituir APKs existentes.

## Estado

Chave e impressões locais: prontas. Guardas de configuração/verificador: testadas.
Projeto/OAuth reais, Google Services, endpoint candidato, SDK Flutter/Android,
compilação, certificado extraído do APK e testes físicos: pendentes.
