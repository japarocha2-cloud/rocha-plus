# Serviço experimental de direitos — suporte #40

**Não implantado; não homologado para cobrança.** Não altera `RochaReleasePolicy.beta`, não liga bloqueio em produção, não recebe Pix nem confirma banco automaticamente. Nenhuma transação real foi aprovada neste ciclo.

## Implementação

- `GET /v1/entitlement`: recebe `Authorization: Bearer <Firebase ID token>`. Firebase Admin verifica o token com revogação; aceita provedor Google/Apple e deriva UID exclusivamente do token. Primeiro acesso cria trial de exatamente 7 × 24 horas pelo relógio do servidor. Requisições/reinstalações da mesma conta não reiniciam o registro.
- `POST /v1/admin/confirm`: exige custom claim **booleana** `rochaAdmin: true`, atribuída apenas por operação administrativa de confiança. Body: `uid`, `provider`, `transactionId`, `evidenceReference`, `plan`, `amountCents`, `currency: "BRL"`. O administrador deve conferir a liquidação no banco/operadora ANTES de chamar; o campo de evidência é referência de auditoria, não comprovação automática. Um usuário comum não pode se aprovar.
- Planos e valores vêm de configuração exclusiva do servidor. Valores usados nos testes são fixtures e não mudam preços comerciais. A transação global não pode ser reaproveitada em outra conta; repetição não soma dias. Não há rota que transforme pendência, abertura de link ou comprovante enviado pelo comprador em aprovação.
- `POST /v1/admin/refund`: mesma autenticação administrativa; body `uid`, `provider`, `transactionId`, `evidenceReference` da confirmação bancária do estorno. Remove a concessão estornada do cálculo. Preserva outros pagamentos válidos e trial original, se ainda vigente. Repetição é idempotente; transação estornada não pode ser reativada por `confirm`.
- Renovação acumula dias sobre período pago ainda vigente. Pagamentos confirmados são recalculados em ordem de confirmação; ao remover um deles por estorno, os demais são recalculados desde suas confirmações. Não há renovação automática, cancelamento de débito recorrente nem estorno financeiro por este serviço: ele registra direitos após ações externas confiáveis.
- Firestore mantém trial, pagamentos e auditoria em transações. IDs de documentos são hashes; credenciais ficam em Application Default Credentials no servidor. As regras incluídas negam leitura/escrita direta de clientes nessas coleções. Auditar IAM e regras do projeto antes de qualquer instalação; não sobrescrever regras existentes cegamente.

## Execução preparada, ainda não realizada

Node >=22. `node --test backend/entitlement/service.test.mjs` executa testes sem instalar dependências. São testes do núcleo com verificador e armazenamento em memória; não validam SDK, assinatura criptográfica real, Firestore, HTTPS, banco ou aplicativo físico.

O adaptador `server.mjs` exige `firebase-admin`, `GOOGLE_CLOUD_PROJECT` de ambiente experimental, `ROCHA_PLANS_JSON` (mapa de IDs de planos com `amountCents` inteiro positivo e `days` de 1 a 366), credenciais de servidor por ADC e Firestore. Dependência declarada, mas não instalada nem resolvida/lockada neste ambiente; revisar e gerar lockfile antes de instalar. Não armazenar chave privada neste repositório.

O processo escuta somente `127.0.0.1`; requer gateway HTTPS configurado separadamente, limite de requisições e monitoramento. O adaptador recusa variáveis de autenticação/Firestore de emulador para evitar ativação acidental de verificação insegura. Configurar endpoint do cliente completo `/v1/entitlement` apenas no experimento após integração. Respostas são `no-store`; falhas não retornam permissão.

## Bloqueios de lançamento

1. Instalar/resolver dependência e testar adaptador com projeto experimental e tokens reais (expirado, revogado, audiência errada, administrador, usuário comum). Testar concorrência e regras/IAM Firestore reais, falha de rede e persistência entre processos.
2. Implementar administração com revisão da evidência bancária; não foi criado painel nem conectada operadora. Definir cancelamento, estornos parciais e reconciliação.
3. A correção experimental do gate local agora coloca Home e players em um Navigator protegido, removido inteiro em caso de negação, erro ou timeout. Os testes de regressão usam PlayerScreen e VideoPlayerController reais com plataforma de vídeo simulada; o resultado do CI e E2E ainda deve ser conferido. A política beta permanece gratuita, portanto esse gate só é usado quando a política exigir assinatura. Cast remoto e fontes ainda precisam de revogação/autorização no servidor; dispose local não comprova parada do receptor e URLs públicas copiadas não são protegidas pela tela Flutter. A revalidação periódica é de um minuto, com timeout de 12 segundos; não equivale a revogação instantânea no segundo exato da expiração. Retorno do background exige nova validação.
4. O beta segue gratuito. Não mudar para `official` antes de E2E completo de UID, 7 dias, reinstalação, relógio alterado, confirmação, renovação, estorno, player e Cast físico.

Referências primárias consultadas em 22/10/2026: [Firebase ID tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens), [transações Firestore](https://firebase.google.com/docs/firestore/manage-data/transactions), [custom claims](https://firebase.google.com/docs/auth/admin/custom-claims).
