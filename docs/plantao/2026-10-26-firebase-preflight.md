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

A revisão automática bloqueou a tentativa de implantação de `entitlement`, por envolver uma alteração na nuvem com endpoint público e possíveis consequências de faturamento. Nenhuma nova tentativa de implantação deverá ocorrer sem aprovação específica. Não contornar essa rejeição por outra ferramenta.

## Implantação preparada para revisão

- Configuração: `firebase.homologacao.json`, codebase `subscription-homologacao`, fonte `functions`, runtime Node.js 22.
- Dependências instaladas sem scripts de instalação e registradas em `functions/package-lock.json`.
- `functions/.gitignore` exclui dependências locais, arquivos de ambiente e logs do Firebase.
- Nenhuma configuração de Firestore/Auth/Hosting está incluída no arquivo de implantação de funções.
- Comando proposto, SOMENTE APÓS APROVAÇÃO:

```bash
npx -y firebase-tools@latest deploy --only functions:entitlement --project rocha-plus-homologacao --config firebase.homologacao.json --non-interactive
```

A função cria um endpoint HTTPS acessível publicamente; o código exige e verifica token Firebase para consultar/criar o direito da conta. Limite configurado: 10 instâncias, região `southamerica-east1`. O estado do faturamento não foi confirmado. Não vincular faturamento nem alterar plano automaticamente.

## Validação local deste preparo

- Registro da função com os SDKs Firebase efetivamente instalados passou; export `entitlement` e região conferidos.
- 15 testes de backend passaram após a instalação das dependências.
- Verificações sintáticas e `git diff --check` passaram.
- O CI e APK do commit `07e50be2f49336f830afda17c93478f9894fa844` permanecem como evidência anterior de compilação; este preparo não constitui nova homologação de APK.

## Ainda pendente

Aprovação específica da implantação, confirmação de faturamento/APIs necessárias, verificação HTTPS com tokens reais, trial/vencimento persistentes, reconciliação real por conta e testes físicos em celular/Android TV/Cast. Nenhum pagamento foi aplicado ou estornado neste avanço. A versão oficial permanece preservada.
