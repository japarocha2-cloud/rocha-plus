# Controle de acesso a canais: pendências de lançamento

A política atual é `RochaReleaseStage.beta`: usuários autenticados entram sem cobrança e `_SubscriptionGate` não é acionado. Portanto, o bloqueio por mensalidade vencida **não está comprovado nem ativo nessa política**. A versão de produção congelada não foi alterada.

Quando a política exigir assinatura, `_SubscriptionGate` consulta a cada minuto o servidor configurado em `--dart-define=ROCHA_ENTITLEMENT_URL=https://...`. Nesse caminho, URL ausente, falha de rede, resposta inválida ou conta divergente negam autorização. Isso descreve o código do cliente; não comprova um serviço implantado ou o bloqueio de inadimplentes. Não mudar a política para `official` antes de concluir backend e testes de ponta a ponta.

## Contrato obrigatório do serviço (ainda não implementado)

- `GET` HTTPS no endpoint configurado; cabeçalho `Authorization: Bearer <Firebase ID token>`.
- O servidor valida a assinatura, emissor, audiência e expiração do ID token com Firebase Admin SDK, e obtém o `uid` exclusivamente do token validado. Nunca confia em um UID passado pelo aplicativo.
- Consulta o banco de direitos de acesso, não metadados editáveis pelo usuário: `trialEndsAt` imutável por UID, `paidThrough`, status de estorno e cancelamento, com horário do servidor. Teste gratuito = 7 dias desde ativação única. Reinstalação não reinicia.
- A confirmação manual só pode ser feita por administrador autenticado, auditada e ligada à transação; ou por webhook da operadora validado no backend. Abrir um link de pagamento **não equivale a pagamento**.
- Resposta `200 application/json`: `{"uid":"<uid-validado>","allowed":true}` somente quando teste vigente ou assinatura confirmada e vigente; caso contrário `allowed:false`.
- Bloquear também no backend as fontes protegidas e operações de espelhamento. A barreira de navegação Flutter por si só **não impede abuso ou replay de URLs**.
- Fazer testes obrigatórios: teste gratuito expira, mensalidade não paga, pagamento confirmado, estorno, troca de conta, reinstalação, relógio manipulado, perda de rede, abertura de player e espelhamento; relógio sempre servidor.

## Status

- **Cliente experimental**: beta gratuito para usuários autenticados. A barreira fail-closed está condicionada à política `official`, não ativa no beta. Não promover à produção até backend, administração e testes de ponta a ponta concluídos.
- **Backend de direitos de acesso**: pendente.
- **Cobrança/baixa automática**: pendente.
- **Certificação de ponta a ponta**: pendente.
