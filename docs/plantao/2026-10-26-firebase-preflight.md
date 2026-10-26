# Firebase de homologação — verificação real de 26/10/2026

Status geral: AMARELO. Não publicar nem mesclar na versão oficial.

## Confirmado por consultas autenticadas

- Login da conta autorizada concluído nesta sessão.
- `rocha-plus-homologacao` está ACTIVE e acessível.
- Banco `(default)`: Firestore STANDARD, FIRESTORE_NATIVE, região `southamerica-east1`.
- App Android ativo: `com.rochaplus.app.lab`.
- Configuração Android baixada pelo CLI, mantida fora do versionamento e validada pelo preparador existente: projeto/pacote corretos, OAuth Android com certificado e OAuth web presentes.
- Regras ativas e índices foram baixados pelo `firebase init firestore` em diretório temporário de inspeção. Não houve publicação das regras.

## Auditoria das regras ativas

```json
{
  "score": 5,
  "summary": "Para as coleções financeiras pertencentes ao servidor, a regra ativa nega todas as leituras e escritas de clientes, inclusive create/update/delete. O Admin SDK depende de IAM, que não foi homologado nesta auditoria.",
  "findings": []
}
```

Regra ativa observada: `match /{document=**} { allow read, write: if false; }`.
Não substituir por outro ruleset: a proteção necessária às coleções `entitlements`, `payment_events` e `payment_claims` já está presente. Esta conclusão não equivale a teste de IAM, Firestore Emulator ou funcionamento de outras coleções.

## Impedimento encontrado

`functions:list` retornou HTTP 403 com mensagem do provedor informando que `cloudfunctions.googleapis.com` está desativada ou ainda não foi utilizada no projeto. Não há endpoint de assinatura verificado nesta sessão.

Após a autorização de continuidade pelo responsável, o comando de implantação avançou até a habilitação das APIs necessárias. O Firebase interrompeu a operação porque o projeto precisa do plano Blaze para habilitar `artifactregistry.googleapis.com`. O CLI também indicou a necessidade de Cloud Functions e Cloud Build.

Mensagem observada: `Your project rocha-plus-homologacao must be on the Blaze (pay-as-you-go) plan to complete this command. Required API artifactregistry.googleapis.com can't be enabled until the upgrade is complete.`

Não houve alteração do plano de faturamento. Nenhuma função foi implantada nesta tentativa e nenhum endpoint novo foi verificado. O CLI tentou habilitar APIs antes de retornar o erro; não presumir que todas permaneceram desativadas.

Página indicada pelo próprio Firebase: https://console.firebase.google.com/project/rocha-plus-homologacao/usage/details . A ativação de Blaze é uma decisão separada de faturamento e não está autorizada pela instrução de implantar sem alterar o plano.

## Implantação preparada para revisão

- Configuração: `firebase.homologacao.json`, codebase `subscription-homologacao`, fonte `functions`, runtime Node.js 22.
- Dependências instaladas sem scripts de instalação e registradas em `functions/package-lock.json`.
- `functions/.gitignore` exclui dependências locais, arquivos de ambiente e logs do Firebase.
- Nenhuma configuração de Firestore/Auth/Hosting está incluída no arquivo de implantação de funções.
- Comando específico já autorizado e executado, atualmente bloqueado pelo plano:

```bash
npx -y firebase-tools@latest deploy --only functions:subscription-homologacao:entitlement --project rocha-plus-homologacao --config firebase.homologacao.json --non-interactive
```

A função proposta cria um endpoint HTTPS acessível publicamente; o código exige e verifica token Firebase para consultar/criar o direito da conta. Limite configurado: 10 instâncias, região `southamerica-east1`. O plano atual impede a implantação. Não vincular faturamento nem alterar plano automaticamente.

## Validação local deste preparo

- Registro da função com os SDKs Firebase efetivamente instalados passou; export `entitlement` e região conferidos.
- 15 testes de backend passaram após a instalação das dependências.
- Verificações sintáticas e `git diff --check` passaram.
- O CI do preparo `56e79c9666833b82199ee27a153702d34e3d7eb6` passou nos três jobs, tanto na execução `40413671623` quanto na `40413664635`: backend, Flutter e experimental-apk. Isso comprova compilação e testes automatizados, sem equivaler a teste físico ou implantação de backend.

## Ainda pendente

Decisão sobre a ativação do Blaze exclusivamente no projeto de homologação, conclusão das APIs/implantação e verificação HTTPS com tokens reais, trial/vencimento persistentes, reconciliação real por conta e testes físicos em celular/Android TV/Cast. Nenhum pagamento foi aplicado ou estornado neste avanço. A versão oficial permanece preservada.
