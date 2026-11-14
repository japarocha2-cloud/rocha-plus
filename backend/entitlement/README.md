# Serviço experimental de direitos — suporte #40

**Não implantado; não homologado para cobrança.** Não altera `RochaReleasePolicy.beta`, não liga bloqueio em produção, não recebe Pix nem confirma banco automaticamente. Nenhuma transação real foi aprovada neste ciclo.

## Implementação

- `GET /v1/entitlement`: recebe `Authorization: Bearer <Firebase ID token>`. Firebase Admin verifica o token com revogação; aceita provedor Google/Apple e deriva UID exclusivamente do token. Primeiro acesso cria trial de exatamente 7 × 24 horas pelo relógio do servidor. Requisições/reinstalações da mesma conta não reiniciam o registro.
- `POST /v1/admin/confirm`: exige custom claim **booleana** `rochaAdmin: true`, atribuída apenas por operação administrativa de confiança. Body: `uid`, `provider`, `transactionId`, `evidenceReference`, `plan`, `amountCents`, `currency: "BRL"`. O administrador deve conferir a liquidação no banco/operadora ANTES de chamar; o campo de evidência é referência de auditoria, não comprovação automática. Um usuário comum não pode se aprovar.
- Planos e valores vêm de configuração exclusiva do servidor. Valores usados nos testes são fixtures e não mudam preços comerciais. A transação global não pode ser reaproveitada em outra conta; repetição não soma dias. Não há rota que transforme pendência, abertura de link ou comprovante enviado pelo comprador em aprovação.
- `POST /v1/admin/refund`: mesma autenticação administrativa; body `uid`, `provider`, `transactionId`, `evidenceReference` da confirmação bancária do estorno. Remove a concessão estornada do cálculo. Preserva outros pagamentos válidos e trial original, se ainda vigente. Repetição é idempotente; transação estornada não pode ser reativada por `confirm`.
- Renovação acumula dias sobre período pago ainda vigente. Pagamentos confirmados são recalculados em ordem de confirmação; ao remover um deles por estorno, os demais são recalculados desde suas confirmações. Não há renovação automática, cancelamento de débito recorrente nem estorno financeiro por este serviço: ele registra direitos após ações externas confiáveis.
- Firestore mantém trial, pagamentos e auditoria em transações. IDs de documentos são hashes; credenciais ficam em Application Default Credentials no servidor. As regras incluídas negam leitura/escrita direta de clientes nessas coleções. Auditar IAM e regras do projeto antes de qualquer instalação; não sobrescrever regras existentes cegamente.

## Execução local e limites

Node >=22. Dentro desta pasta, `npm ci --ignore-scripts --no-audit --no-fund` instala as dependências registradas no lockfile e `npm test` executa a suíte. Há testes do núcleo com doubles, integração HTTP por sockets reais em loopback e rejeição de tokens malformados/com audiência ou emissor inválidos usando Firebase Admin SDK real. Os testes positivos de direitos/pagamentos ainda usam verificador e armazenamento em memória. Não validam tokens legítimos, assinatura criptográfica positiva, revogação remota, Firestore, HTTPS, banco ou aplicativo físico.

O adaptador `server.mjs` exige `firebase-admin`, `GOOGLE_CLOUD_PROJECT` de ambiente experimental, `ROCHA_STAGING_PROJECT_ID` igual ao ID do projeto experimental e **diferente de `rocha-plus`** (o adaptador recusa a inicialização com o projeto oficial), `ROCHA_PLANS_JSON` (mapa de IDs de planos com `amountCents` inteiro positivo e `days` de 1 a 366), credenciais de servidor por ADC e Firestore. Dependências resolvidas no lockfile e instaladas localmente sem scripts de ciclo de vida. O adaptador Firebase/Firestore não foi iniciado com credenciais reais. Não armazenar chave privada neste repositório.

O processo escuta somente `127.0.0.1`; requer gateway HTTPS configurado separadamente, limite de requisições e monitoramento. O adaptador recusa variáveis de autenticação/Firestore de emulador para evitar ativação acidental de verificação insegura. Configurar endpoint do cliente completo `/v1/entitlement` apenas no experimento após integração. Respostas são `no-store`; falhas não retornam permissão.

## Bloqueios de lançamento

1. Testar adaptador com projeto experimental e tokens reais (válido, expirado, revogado, administrador, usuário comum). A rejeição de audiência/emissor inválidos e token malformado já tem teste local com SDK real, mas não valida assinatura positiva ou revogação. Testar concorrência e regras/IAM Firestore reais, falha de rede e persistência entre processos.
2. Implementar administração com revisão da evidência bancária; não foi criado painel nem conectada operadora. Definir cancelamento, estornos parciais e reconciliação.
3. A correção experimental do gate local agora coloca Home e players em um Navigator protegido, removido inteiro em caso de negação, erro ou timeout. Os testes de regressão usam PlayerScreen e VideoPlayerController reais com plataforma de vídeo simulada; o resultado do CI e E2E ainda deve ser conferido. A política beta permanece gratuita, portanto esse gate só é usado quando a política exigir assinatura. Cast remoto e fontes ainda precisam de revogação/autorização no servidor; dispose local não comprova parada do receptor e URLs públicas copiadas não são protegidas pela tela Flutter. A revalidação periódica é de um minuto, com timeout de 12 segundos; não equivale a revogação instantânea no segundo exato da expiração. Retorno do background exige nova validação.
4. O beta segue gratuito. Não mudar para `official` antes de E2E completo de UID, 7 dias, reinstalação, relógio alterado, confirmação, renovação, estorno, player e Cast físico.

Referências primárias consultadas em 22/10/2026: [Firebase ID tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens), [transações Firestore](https://firebase.google.com/docs/firestore/manage-data/transactions), [custom claims](https://firebase.google.com/docs/auth/admin/custom-claims).

### Proteção de ambiente experimental (25/10/2026)

A inicialização do servidor exige `GOOGLE_CLOUD_PROJECT=ID_DO_PROJETO_DE_TESTES` e `ROCHA_STAGING_PROJECT_ID=ID_DO_PROJETO_DE_TESTES`; nenhum dos dois pode apontar para o projeto oficial `rocha-plus`. Isto é uma barreira de configuração, não substitui isolamento IAM, regras, HTTPS, logs e testes reais. **Não crie projeto nem implante serviço automaticamente.** O projeto de homologação ainda precisa ser criado/confirmado e ter custos e permissões revisados antes de qualquer integração Firebase real.

## Limites de aparelhos e reproduções (LAB 14/11/2026)

**Não implantado.** Regras do plano: 1 celular, 2 TVs, 2 reproduções simultâneas (`devices.mjs`,
`DEFAULT_LIMITS`). UID vem só do token; tudo roda na mesma transação do direito de acesso.

| Rota (POST) | Body | Efeito |
|---|---|---|
| `/v1/devices/register` | `deviceId`, `kind: phone\|tv` | registra; acima do limite → 409; repetir é idempotente |
| `/v1/devices/remove` | `deviceId` | libera a vaga e encerra reproduções do aparelho; máx. 3 trocas / 30 dias → 429 |
| `/v1/streams/start` | `deviceId` | exige acesso válido e aparelho registrado; máx. 2 ativas → 409; concessão de 90 s |
| `/v1/streams/heartbeat` | `deviceId`, `streamId` | renova; acesso expirado → 403; concessão vencida → 409 (player deve parar) |
| `/v1/streams/stop` | `streamId` | encerra (idempotente) |

- `deviceId`: ID aleatório de instalação gerado pelo app (16–128 caracteres seguros), salvo só como hash.
- Firestore: `rochaDeviceSessions/{sha256(uid)}`; regras negam leitura/escrita de clientes.
- Rotas de reprodução nunca criam trial; só `GET /v1/entitlement` inicia os 7 dias.

**Validado:** 70 testes locais (`npm test`), com dublê em memória serializado (inclui corrida de 3
inícios simultâneos → exatamente 2). **Não validado:** Firestore real/emulador, app Flutter, aparelho.

**Pendências de decisão / limites conhecidos:**
- Número de trocas por 30 dias (3) e duração da concessão (90 s) aguardam confirmação comercial.
- `deviceId` é falsificável sem atestação (Play Integrity / App Check). A concessão é consultiva
  enquanto a URL de mídia não exigir o `streamId` (CDN/DRM). Falta rate limit por UID no gateway.
- Reiniciar no mesmo aparelho mantém a vaga e gera novo `streamId` (encerramento tardio da tela
  anterior não derruba a nova).

### Cliente Flutter (`lib/src/auth/device_limits.dart`)
- Desligado por padrão. Ativar só em build LAB: `--dart-define=ROCHA_DEVICE_LIMITS=true` junto com
  `ROCHA_ENTITLEMENT_URL=https://…/v1/entitlement` (outro formato desativa e avisa em debug).
- O player pede a concessão antes de abrir a mídia; renova a cada 30 s; recusa explícita
  (401/403/409) para na hora; 3 renovações sem resposta/erro temporário seguidas param a reprodução;
  sair do player libera a vaga (inclusive se a concessão chegar depois do fechamento).
- Celular × TV por tamanho de tela (lado menor ≥ 480 = TV; tablets contam como TV) até haver
  verificação nativa de Android TV.
- **Lacuna:** transmissão por Cast não ocupa vaga nem é limitada ainda.
