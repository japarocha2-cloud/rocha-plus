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

## Implantação concluída após ativação do Blaze pelo responsável

O impedimento inicial era o plano Spark do projeto de homologação. O responsável concluiu a vinculação de faturamento na própria interface do Firebase. Não é necessário repetir a ativação.

A função `entitlement` está ACTIVE no projeto `rocha-plus-homologacao`, geração 2, Node.js 22, região `southamerica-east1`. A implantação retornou atualização bem-sucedida. O CLI terminou com código 1 depois dessa atualização por ausência de política de limpeza de imagens; a configuração dessa política ainda não está confirmada.

Endpoint verificado: https://southamerica-east1-rocha-plus-homologacao.cloudfunctions.net/entitlement . URL do serviço: https://entitlement-mrau75n36a-rj.a.run.app .

Verificações HTTPS reais concluídas:

- GET sem autenticação: HTTP 401, `allowed: false`, `Cache-Control: no-store`.
- GET com bearer inválido: HTTP 401, `allowed: false`, `Cache-Control: no-store`.
- POST: HTTP 405, `allowed: false`, `Cache-Control: no-store`.

Essas verificações comprovam disponibilidade e rejeição de solicitações inválidas. Não comprovam login Google no aparelho nem criação/persistência de trial com token válido. As tentativas auxiliares de obter token com credencial CLI não produziram autenticação válida e não foram usadas como evidência de defeito do login Android.

Configuração implantada: `firebase.homologacao.json`, codebase `subscription-homologacao`, fonte `functions`. Nenhuma regra Firestore ou configuração Auth/Hosting foi publicada neste avanço.

```bash
npx -y firebase-tools@latest deploy --only functions:subscription-homologacao:entitlement --project rocha-plus-homologacao --config firebase.homologacao.json --non-interactive
```

O endpoint HTTPS verifica token Firebase, utiliza o UID verificado e consulta/cria o direito dessa conta. Limite: 10 instâncias. Reconciliação Mercado Pago, webhook e agendamento não foram ativados pela implantação desta função.

## APK experimental com login e bloqueio

A execução Build Rocha+ #711 (`40419850739`, fonte `425f14b`) concluiu com sucesso e gerou `rocha-plus-homologacao-login-lab`. O pacote e certificado OAuth foram verificados pelo job. Essa variante tem bloqueio desativado e não serve como evidência de trial/vencimento.

A execução #712 falhou na preparação, antes de gerar APK. A correção `195bb1e14871e24ed5963dac440548f0854975a8` isola a validação do preparador LAB, aceita somente o endpoint de homologação acima e preserva a restrição do preparador original. Os 32 testes Python passaram. A execução #713 (`40422345307`) concluiu com sucesso com login, assinatura e bloqueio experimental ativados. O job conferiu pacote e certificado OAuth antes de publicar o artefato `rocha-plus-homologacao-subscription-lab` (`12698546158`). Fonte: `195bb1e`. SHA-256 do ZIP publicado: `1854da68eb2d6253ad70acb9078cdad648ddbc768f65282df39cbbd1715258bb`.

O ZIP foi baixado e seu SHA-256 corresponde ao digest do GitHub. O APK também corresponde ao SHA-256 do relatório: `aab578be60ef750db332464964dc5a45c04f3132e566e8cddae32fd203cab860`. O relatório confirma projeto/pacote corretos, certificado compatível, bloqueio e endpoint configurados; mantém `productionApproved: false`, `physicalLoginValidation: pending`, `cloudAccessValidated: false`, pagamento e trial/vencimento pendentes.

## Validação automatizada

- O CI do código `195bb1e` concluiu os três jobs com sucesso: backend, Flutter e APK debug experimental, nas execuções `40422210239` (PR) e `40422204959` (push). O debug não substitui a variante assinada com login e bloqueio.
- Registro da função com os SDKs Firebase efetivamente instalados passou; export `entitlement` e região conferidos.
- 15 testes de backend passaram após a instalação das dependências.
- Verificações sintáticas e `git diff --check` passaram.
- O CI do preparo `56e79c9666833b82199ee27a153702d34e3d7eb6` passou nos três jobs, tanto na execução `40413671623` quanto na `40413664635`: backend, Flutter e experimental-apk. Isso comprova compilação e testes automatizados, sem equivaler a teste físico ou implantação de backend.

## Ainda pendente

Verificar HTTPS com token real do aplicativo, trial/vencimento persistentes, reconciliação real por conta e testes físicos em celular/Android TV/Cast. Nenhum pagamento foi aplicado ou estornado neste avanço. A versão oficial permanece preservada. A homologação geral continua AMARELA.
