# Roku LAB — plano executável de ativação segura (03/11/2026)

**Estado:** proposta preparada; não foi autorizado criar conta de serviço, IAM, deploy, hosting ou acesso real. Não altera APK, Roku oficial, C6, LAB714, website, pagamentos, catálogo, imagem ou temporizadores.

## Evidência e inventário atual

- Commit de entrada: `78c489140d625ba8f253e15d99ddb8fe70a9d826`; ZIP Roku LAB 0.6.8 permanece fixado em `9d34121cb651726ee8f60dcd2ac8ba0d204423f9`, SHA-256 `00c3a2c6c8cea91958e11a4cf82fdecc1ff177bd4566431dc2a08f8636de1305`, com 13 validações documentadas; acesso desativado.
- GitHub Actions run `41619638681` (job `125861783179`): o principal CI cuja chave referencia `rocha-plus` recebeu HTTP 200 em metadados de Firestore comercial; HTTP **403** ao consultar metadados `rocha-plus-homologacao/databases/(default)`; `testIamPermissions` no LAB respondeu 200 sem permissões listadas. Mensagem Google e e-mail exato não persistidos na auditoria anterior.
- Script `experiments/roku-readiness/firebase-403-closeout.mjs` e workflow `roku-lab-403-closeout.yml` preparam consulta unicamente de metadados, com registro sanitizado. **Nenhum novo resultado do workflow foi confirmado nesta etapa.** A existência da credencial CI comercial não autoriza reutilizá-la no runtime.
- Fonte Roku: `Account.brs -> initCentralAccess()` desativa central (`central-access.json enabled:false`); `initLabAccess()` usa modo `account_homologation` mas `lab-access.json enabled:false` e endpoint vazio, produz `lab_unconfigured` sem navegar/reproduzir.
- No código versionado foi localizado um endpoint histórico de `entitlement` de homologação, porém **não é prova de implantação atual**, compatibilidade com Roku, nem de um host `/approve`/`/v1/access`. Não se dispõe nesta sessão de inventário autenticado atual de Cloud Functions v1/v2 e Cloud Run; status **NÃO VERIFICADO**, não declarar “inexistente”.

## Pré-verificação somente leitura pelo proprietário/identidade autorizada

Executar em Cloud Shell com conta autorizada, **sem colar saídas sensíveis no chat** e sem alterar configuração:

```bash
PROJECT=rocha-plus-homologacao
gcloud config set project "$PROJECT"                 # muda apenas contexto local da CLI
gcloud functions list --gen2 --project "$PROJECT" --format="table(name,region,state,serviceConfig.uri)"
gcloud run services list --project "$PROJECT" --platform managed --format="table(metadata.name,metadata.namespace,status.url,status.conditions)"
gcloud firestore databases list --project "$PROJECT" --format="table(name,locationId,type)"
gcloud services list --enabled --project "$PROJECT" --filter="config.name:(firestore.googleapis.com OR run.googleapis.com OR cloudfunctions.googleapis.com OR identitytoolkit.googleapis.com)" --format="table(config.name)"
```

Alguns comandos podem retornar 403 por permissões de inventário. Registrar comando, principal e mensagem sanitizada, não fazer escalonamento. Em Cloud Console, confirmar **projeto e databaseId efetivo**, região, Functions e Cloud Run; não inferir existência a partir de Blaze ou de um endpoint antigo. Evitar output de variáveis de ambiente ou configuração secreta.

## Alternativas e decisão de menor custo

**A — preferida se já existir hospedagem compatível:** reaproveitar um Cloud Run/Cloud Functions 2nd gen **do LAB** apenas se for isolável sem interferir em workloads existentes, sem substituir endpoint comercial, com controle de origem, CPU/memória/custos e separação IAM; exigir revisão do código antes de ativar.

**B — se não houver host compatível:** serviço novo e isolado **Cloud Run no mesmo projeto**, região `southamerica-east1` a confirmar, URL `*.run.app` fornecida pela plataforma com TLS gerenciado; `min-instances=0`, limite inicial de instâncias/concurrency, timeout curto, limites de entrada e alertas de orçamento. Não provisionar antes de aprovação. Usar somente conta de serviço gerenciada; **não criar chave JSON**.

**C — Cloud Functions 2nd gen:** possível se já houver infraestrutura de Functions e for simples adaptar o handler HTTP, observando que é serviço sobre infraestrutura Cloud Run e tem custos associados.

**Alerta de compatibilidade:** `experiments/central-rights/https-runtime.mjs` cria um servidor HTTPS local com `key/cert` e exige `req.socket.encrypted`. Em Cloud Run/Functions, TLS normalmente termina na borda gerenciada e o backend recebe HTTP interno; não executar esse arquivo sem adaptação revisada para handler/plataforma, preservando a garantia de HTTPS público e checagem de origem. A URL `run.app` **não é por si só um domínio autorizado no Firebase Auth do projeto comercial**; verificar necessidade de adicionar domínio autorizado, que exige aprovação separada.

**Custos potenciais:** uso de CPU, memória, invocações, egress, logs, Firestore, Cloud Build e Artifact Registry podem ser cobrados; cotas gratuitas de Run/Functions dependem da conta de faturamento, consumo e região. Preferir `min-instances=0`, sem VPC connector, deploy ocioso ou domínio pago, com orçamento/alertas; alertas **não são bloqueio rígido de gasto**. Sem orçamento/custos concretos de inventário, nenhum valor em reais é garantido.

## Identidade e autorização IAM mínima (NÃO APLICAR)

**Principal proposto, ainda não criado:** `rocha-lab-runtime@rocha-plus-homologacao.iam.gserviceaccount.com`. Este é um **nome sugerido**, não evidência de conta existente. Associar como service identity **exclusivamente ao runtime LAB** (sem chave privada) quando houver autorização.

| Recurso | Necessidade exata | Condição |
|---|---|---|
| Firebase Auth `rocha-plus` | Verificação de ID token e leitura de `getUser(uid)` (p.ex. `firebaseauth.users.get` quando necessária) | Role custom de leitura mínima; **sem** alterar usuários ou claims |
| Firestore comercial `rocha-plus` | `datastore.entities.get` nos registros necessários | Role custom de leitura, reconhecer que IAM server-side pode não limitar por coleção; filtro e validação em código |
| Firestore LAB `rocha-plus-homologacao` com databaseId validado | `datastore.databases.get/getMetadata` se exigidos pelo SDK, `datastore.entities.get/create/update/delete` para transações do pequeno LAB | Preferir role custom limitada a projeto/banco suportado, nunca Owner/Editor/Admin; revisar escopo que IAM realmente suporta |
| Cloud Functions list / Cloud Logging read | **Não exigidos** pelo app Roku | Apenas para auditoria separada e aprovação separada |

O 403 no CI não prova que o *futuro* principal gerenciado falhará. Primeiro confirmar projeto/DB, permissão e resposta do erro sanitizada; só então propor comandos de concessão para aprovação exata. Reversão: desativar service, remover somente bindings novos, manter backups/evidências, nunca afetar IAM anterior.

## Vinculação LAB e teste de canais autorizados

- Fluxo atual: Google login recente, código de **8 alfanuméricos/10 min**, um celular por conta, até duas TVs, até duas reproduções, leases curtas de 60 s, terceira reprodução HTTP 409. Código QR/numérico são templates desativados, **não funcionam no 0.6.8**.
- Autorizar exclusivamente a conta definida pelo proprietário em custódia privada e dispositivos identificados por vínculo autenticado; `scope=homologation`, `notBefore`/`expiresAt` absolutos e no máximo 24h; nunca gravar o e-mail, UID, device token ou grant privado no ZIP/repositório.
- `createFirebaseRuntime` usa `createExistingRightsReader`: `loadRights` retorna `base` vazio se não houver snapshot existente; nesse caso o LAB grant não é emitido mesmo com `authorization.enabled:true`. **Verificar/ajustar e testar esse caso explicitamente sem criar trial comercial** antes da ativação.
- `devices.mjs` controla slots por dispositivo, mas **não aplica allowlist por canal**. Exigir `channelId` com verificação server-side de autorização antes de lease/play (inclusive trocas de canal), negar canais fora da allowlist e renovar autorização; testes positivos e negativos por canal. Evitar reescrever URLs do catálogo.
- O arquivo `experiments/roku-readiness/physical-channel-lab.example.json` mantém `channels.approvedForPhysicalTest:[]`, `enabled:false`, e nenhuma autorização real foi comprovada. `catalog/approved.json` indica estabilidade técnica, **não direito de transmissão**. Registrar permissão por fonte/canal/plataforma/prazo e responsável; sem evidência, nenhum canal entra na allowlist.

## Plano de ativação com aprovações separadas

1. **Inventário:** proprietário confirma Cloud Run/Functions disponíveis, serviços habilitados, databaseId LAB, região e URL; confirma se domínio é autorizado para OAuth. Aprovação para uma consulta de leitura não é autorização IAM/deploy.
2. **Projeto de host:** apresentar recurso concreto selecionado, região, limite de recursos, estimativa de faturamento, custo máximo pretendido e procedimento de rollback. Proprietário aprova ou rejeita contratação/deploy.
3. **IAM:** fornecer principal exato, lista de roles/permissões, projetos, escopo, condições e rollback. Proprietário aprova **separadamente** criação de identidade e mudanças IAM. Nada de JSON.
4. **Implementação:** adaptar handler ao gateway HTTPS, garantir Auth, exclusão de pagamentos, fail-closed por canal e reservas; executar testes novos e relacionados, não repetir indiscriminadamente históricos 64/36.
5. **Grant de teste:** proprietário aprova conta/dispositivos específicos e horários absolutos de até 24 horas, em canal privado, sem concessão comercial. Sem grant não liberar acesso.
6. **ZIP:** gerar versão experimental **posterior à 0.6.8** com `central-access.json` configurado somente após ambiente validado; incluir apenas URL HTTPS pública, não tokens/segredos; comparar hashes de catálogo, capas, favoritos, temporizadores e artes com a versão 0.6.8, validar CRC/manifest/testes e publicar apenas como artefato privado para sideload manual. 0.6.8/0.6.7 preservados.
7. **Físico:** usuário instala via `Replace with ZIP` no **dev app LAB**, grava firmware, ID de hardware em custódia privada, e testa D-pad, foco, carrossel, categorias/PET, busca/favoritos, prévia, áudio e vídeo separados, fullscreen/Back, 60/180s, stop e terceira stream 409, offline/reconexão, expiração/revogação. Sem live host e canal autorizado esses testes permanecem bloqueados.

## Status

**AMARELO:** solução concreta planejada com projeto existente, mas Cloud Functions/Run e banco operacional ainda não inventariados com acesso de administração autorizado; IAM/HTTPS/grant não concedidos; canais com permissão de reprodução não confirmados; ZIP 0.6.8 continua seguro/bloqueado. Nenhuma ativação realizada.
