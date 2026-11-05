# ROCHA+ TV — P0: execução de homologação em 04/11/2026 (Brasília)

## Decisão da etapa

**AMARELO — preparação e validação local avançaram; isolamento IAM remoto ainda NÃO comprovado.** Nenhuma autorização de implantação, ativação financeira ou alteração de IAM foi utilizada ou presumida.

Fonte fixada: `japarocha2-cloud/rocha-plus`, branch `impl/commercial-checkout-20261104`, commit `644e6cfbca060e1e598502bc8a82f211baa961f0`. Esta análise continua os resultados existentes; não reinicia o projeto nem repete a suíte histórica de 35 testes.

| Item | Estado | Evidência desta execução |
| --- | --- | --- |
| Expressão IAM por banco | VERDE, análise documental | Expressão informada corresponde ao exemplo oficial Firestore; não precisa ser trocada por prefixo de documentos. |
| Acesso efetivo da runtime ao banco de teste | VERMELHO, execução bloqueada | Não há credencial Google ou principal autenticado no executor; console e Cloud Shell indisponíveis no navegador. Nenhuma chamada se passou pela runtime. |
| Negação efetiva no `(default)` | VERMELHO, execução bloqueada | Não testada; a condição isolada na política não é prova. |
| Herança, grupos e acessos indiretos | AMARELO | Checklist e coletor parcial preparados; políticas atuais não puderam ser lidas. |
| Pacote HMAC recuperado | VERDE | ZIP reconstruído da cópia da branch; SHA-256 e todos os hashes internos verificados. |
| Transações/concurrency no Emulator | VERDE, escopo local | Nove cenários novos aprovados; TAP conta dez entradas incluindo o agrupador, zero falhas. |
| Pin do banco de teste | AMARELO, patch preparado | Patch limita o receptor exatamente a `rocha-payments-test`; dois testes aprovados. Não aplicado à branch nem implantado. |
| Credencial e merchant Mercado Pago | VERMELHO, acesso bloqueado | Painel retornou erro de acesso; token e identidade não consultados. |
| Webhook remoto pausado | VERDE, observação HTTP pública | GET retornou HTTP 503 e `{"received":false,"paused":true,"mode":"bootstrap"}`. Não houve POST financeiro. |
| Idempotência de tentativa do checkout | AMARELO, falha funcional reproduzida | Duas solicitações iguais geram dois pedidos e duas chaves diferentes em mock. |
| Checkout recorrente | AMARELO, não implementado neste fluxo | Código usa preferências e `mode=one_time`; mensal/anual indicam período comprado, sem renovação automática. |
| Integração remota HMAC/provedor/banco | VERMELHO, bloqueada | Não executada; não substituído o bootstrap nem habilitadas flags. |

## 1. IAM: o que está comprovado e o que falta

O binding informado pelo responsável é:

- Principal: `rocha-webhook-homolog@rocha-plus-homologacao.iam.gserviceaccount.com`.
- Papel: `roles/datastore.user`.
- Condição: `resource.name=="projects/rocha-plus-homologacao/databases/rocha-payments-test"`.

A documentação oficial apresenta exatamente esse padrão para limitar `roles/datastore.user` a um banco. A comparação com o recurso Database é suportada; não presumir que seria necessário acrescentar `/documents` ou usar `startsWith`. O console não é a superfície indicada para validar esse isolamento: usar REST/SDK autenticado.

O papel contém `datastore.databases.get` (transações), `datastore.entities.get/list` e permissões de criação/atualização/exclusão de documentos. A concessão condicionada foi desenhada para leitura e escrita nesse banco, mas uma concessão não é uma negação global: outros bindings, papéis customizados, herança, grupos e impersonação podem permitir caminhos adicionais. Leituras bem-sucedidas não provam a ausência de uma permissão exclusivamente de escrita no banco proibido.

Não há evidência que justifique modificar IAM nesta execução. Qualquer correção dependerá de encontrar a concessão indevida e propor a remoção/restrição daquele binding específico; exige aprovação separada. Não ampliar permissões nem substituir a condição válida por outra por suposição.

**Limitação observada:** nenhum `gcloud`/Firebase CLI/ADC/principal Google configurado inicialmente no executor; manifesto de identidade indisponível. Ferramentas Firebase autenticadas não expostas nesta sessão. Navegador mostrou `Site Unavailable` no console, persistindo após uma recarga, e também no Cloud Shell. Isso não comprova erro de senha, erro IAM ou API desabilitada. Não foi repetido o Policy Troubleshooter inválido.

Foi preparado e executado `iam_isolation_readonly.py`. Ele encerrou com `RED_EXECUTION_BLOCKED / gcloud_unavailable`, sem realizar testes remotos. O JSON preserva explicitamente `write_isolation_verified=false` e `full_inheritance_audit_verified=false`.

O coletor, quando executado em ambiente autenticado, usa token temporário em memória e não grava credenciais. Examina bindings diretos/públicos e sinaliza grupos/ancestrais não resolvidos. Confirma existência dos bancos usando a identidade operadora e testa GET/list de uma coleção aleatória sem documentos de negócio usando a identidade impersonada. Não altera IAM, dados, secrets ou serviços. Só aceita 403 com `PERMISSION_DENIED` como negação; falha de transporte/API não conta como isolamento. Se a identidade não puder ser impersonada, para sem conceder nada. Seis testes locais de classificação passaram; eles validam o coletor, **não o IAM do Google**.

`iam.serviceAccounts.actAs` não equivale a `iam.serviceAccounts.getAccessToken`. A autorização para anexar a conta ao webhook não garante que o operador possa emitir token temporário dela. Uma falha de impersonação não deve ser corrigida concedendo Token Creator automaticamente. Alternativa depende de executor já autorizado com essa identidade; qualquer nova concessão requer aprovação.

Para fechar o IAM, falta executar a matriz autenticada e ler políticas atuais do projeto/ancestrais e papéis customizados, expandir associações de grupo relevantes e revisar caminhos de impersonação. Não afirmar isolamento de escrita apenas pela matriz de leitura. IAM não é emulado pelo Firestore Emulator.

## 2. Artefato HMAC e testes novos

Pacote original localizado: `RochaPlus-Webhook-HMAC-Revisao-Local.zip`. A cópia embutida em `.github/workflows/hmac-review-download.yml` da branch permitiu recuperar os bytes sem pedir reenvio.

SHA-256: `336db70fadc765ce0944f91a02166f17dad133980746c2e4b57f83898a44ef16`.

Validados: integridade ZIP; todos os hashes de `SHA256SUMS`; manifesto com um único export `mercadoPagoWebhook`; identidade dedicada; codebase `webhook-bootstrap-homologacao`; flags false; ausência de entitlement no manifesto e de rota de concessão real nessa fonte. Os 35 testes históricos são resultados anteriores, não foram reexecutados nem contados como novos.

Dependências foram instaladas com lock, sem lifecycle scripts no pacote. Instalação offline inicial falhou por cache incompleto; instalação normal pelo registro npm funcionou. O CLI Firebase e o Emulator foram obtidos de suas distribuições oficiais. Java 17 não atende ao CLI atual; instalado Temurin JRE 21.0.13 localmente, sem alterar infraestrutura Google. Execução: Node 22.23.4, Firebase CLI 15.35.0, Firestore Emulator 1.22.0, firebase-admin 13.6.0.

`firestore_concurrency.test.cjs` usa exclusivamente loopback e projeto fictício `demo-rocha-financial-validation`, com dados sintéticos. A fonte original do pacote HMAC foi utilizada sem alterações de comportamento. Provedor simulado; HMAC local e transações reais no Emulator.

Cenários aprovados:

1. Doze notificações simultâneas: uma obtém o lease, onze recebem busy.
2. Lease expirado é retomado; token antigo não finaliza nem remove o novo lock.
3. Doze revisões canônicas simultâneas criam exatamente um recibo.
4. Falha simulada de provedor gera estado retryable e entrega seguinte conclui.
5. Pagamento pendente estaciona para revisão; aprovação canônica posterior pode ser processada.
6. Notificação já processada não consulta novamente o provedor.
7. Timestamp antigo e outro ID de notificação não duplicam o recibo do mesmo pagamento.
8. Reembolso tardio não altera o recibo histórico para virar direito atual; `licenseGranted=false` e nenhum entitlement criado.
9. Mudança conflitante de UID revisado não sobrescreve o titular do recibo.

**Limites:** o Emulator advertiu que múltiplos bancos não são suportados integralmente. O SDK recebeu um database ID nomeado, mas estes testes comprovam transações/idempotência locais, não isolamento entre bancos remotos, IAM ou regras cliente. O emulator teve regras permissivas locais; a autorização server-side é IAM e não está coberta. Não houve entrega real Mercado Pago ou validação de secrets reais. Nenhum teste equivale a aprovação comercial.

Patch adicional preparado em `prepared-patches/pin-test-database.patch`: fixa o único database ID permitido e preenche seu nome na configuração pausada. Dois testes locais cobrem rejeição de outro banco antes de acessar secrets/runtime e aceitação do nome exato após HMAC válido. É defesa adicional e não substitui IAM. Nenhuma fonte remota foi alterada por esse patch.

## 3. Mercado Pago: seleção segura de credencial

O código existente usa Checkout Pro baseado em preferências: `POST /checkout/preferences`, evento payment e consulta `GET /v1/payments/{id}`. Não migrar para Orders nem mudar o evento cadastrado nesta etapa.

A documentação atual do Checkout Pro explica que a credencial do vendedor de teste pode começar por `APP_USR`. Portanto, o prefixo isolado não distingue teste e produção. A seleção deve partir do ambiente **Teste** da aplicação `7818025101460456`, confirmando que o vendedor é usuário de teste. O recebedor produtivo `320683687` não deve ser reutilizado como merchant de teste por suposição.

Painel tentou abrir e mostrou `Hubo un error accediendo a esta pagina...`, inclusive após uma recarga. Não houve login utilizável, leitura de credencial ou consulta financeira autenticada. Nenhum token foi exposto ou escolhido.

Preparação para etapa autorizada: confirmar aplicação/produto/ambiente e vendedor no painel; consultar identidade do token por canal privado; preencher o merchant de teste; somente após aprovação específica criar secret `MP_RECEIVING_ACCESS_TOKEN` e conceder acesso à runtime exclusivamente nesse secret. Os bindings são resolvidos no cold start mesmo com handler pausado; a pausa não dispensa o secret. Não executar agora cadastro, grant ou consulta financeira adicional sem o escopo específico necessário.

## 4. Checkout, direitos e recuperação

Confirmado por código: UID vem de `verifyIdToken`; preço/plano são definidos no servidor; referência do pedido é criada antes da preferência; merchant é confrontado com `/users/me`; URLs de redirecionamento são restritas; callback isolado não é fonte de aprovação financeira. O cliente abre a URL externa com `LaunchMode.externalApplication`. Isso não comprova compatibilidade física com o aplicativo Mercado Pago; não executado teste em aparelho.

`checkout_retry.test.cjs` executou duas requisições idênticas com o mesmo UID/plano e todas as chamadas ao provedor substituídas por mocks. Resultado: dois pedidos distintos e duas chaves de idempotência distintas. O teste passou ao **reproduzir a lacuna**, não ao aprovar a idempotência. Não demonstra duas cobranças reais; demonstra ausência de deduplicação da tentativa de compra no servidor.

Correção necessária antes de ativar: introduzir intenção de compra idempotente vinculada ao UID, com chave persistida entre retries; retornar o pedido existente; serializar criação concorrente; definir recuperação de resultado ambíguo do provedor sem gerar outra compra cegamente. Não presumir que um header por si só garanta idempotência da API de preferências. Preservar IDs/valores/merchant como dados do servidor e testar falha após a preferência ter sido criada. Patch financeiro dessa mudança exige implementação e revisão própria; não foi aplicado nesta etapa.

Fluxo é `one_time`: mensal e anual são períodos, não contratos recorrentes. Não há renovação automática, ciclo de cancelamento de recorrência ou integração de contratos comprovados por este checkout. Não inventar essa equivalência.

O reconciliador da branch é separado e exige pagamento live e claim revisado antes de recalcular direitos pelo ledger. Ele não foi ligado ao receptor de teste, executado ou implantado. Há tratamento em código para recomputação após reembolso, mas não houve homologação remota. Não se pode inferir que esse código corresponda à função `entitlement` implantada.

Riscos abertos do HMAC: timestamp assinado sem janela de frescor; body.id não é assinado integralmente; mudança de notification ID pode provocar nova consulta canônica, embora recibo permaneça único. Eventos `review_required` recebem 200 e ficam estacionados sem worker automático. Recibo aprovado é histórico e não reflete necessariamente o estado financeiro após refund; jamais consumi-lo como autorização de acesso. Falta procedimento de recuperação controlada de eventos perdidos, critérios de titularidade e integração remota com contas exclusivamente de teste.

## 5. Arquivos, recursos remotos e preservação

Criados localmente: coletor IAM, seis testes de classificação, suíte de nove cenários Emulator, teste que reproduz retry de checkout, dois testes do pin, patch não aplicado, logs/JSON/TAP e este relatório. Fontes de referência foram recuperadas em `review-source/`; o pacote em `hmac-review/` preserva os arquivos originais e contém uma cópia adicional preparada do receiver para testar o patch. Não incluir node_modules ou runtimes nos entregáveis.

Alterações em Google Cloud/Firebase/Secret Manager/Mercado Pago: **nenhuma**. GET público do bootstrap foi a única observação HTTP de serviço; não alterou configuração. Não criadas identidades/chaves/bancos/secrets; não alterados IAM, cobranças ou documentos. Nenhum deploy. `entitlement`, Nádia, paidUntil/trialUntil, produção, Oficial, Candidata 6, LAB 714, Roku, dispositivos, simultaneidade e catálogo preservados.

O registro documental na branch autorizada usa `[skip ci]`. Esse registro documental não é deploy, não substitui o pacote e não implanta patches. Não executado CI remoto nesta etapa.

## 6. Próxima ação executável

Disponibilizar ao Work um executor Google Cloud autenticado com acesso de leitura às políticas e capacidade **já existente** de executar como a runtime (ou de impersoná-la). O console e o Cloud Shell desta sessão estão indisponíveis, portanto um simples “já estou logado” em outro navegador não transfere credenciais para este executor.

Alternativa de menor intervenção se o Work continuar sem acesso: executar uma vez `python3 validation/iam_isolation_readonly.py` a partir do pacote em um Cloud Shell já autenticado. O coletor não instala nada nem muda permissões. Caso a impersonação seja negada, guardar só o diagnóstico sanitizado e preparar decisão sobre a permissão mínima; não pedir token/JSON pelo chat. Uma execução do coletor continua sendo parcial quanto à herança e permissões exclusivamente de escrita: completar a análise das políticas antes de declarar o isolamento VERDE.

Cadastro de token de teste, novo IAM, deploy HMAC, integração que grave dados remotos e ativação de flags continuam dependendo de autorização específica quando houver uma operação concreta e revisada. Não solicitar aprovação genérica antecipada.

## Referências oficiais

- https://firebase.google.com/docs/firestore/manage-databases — Configure per-database access permissions.
- https://firebase.google.com/docs/firestore/security/iam — papéis e permissões por método.
- https://docs.cloud.google.com/iam/docs/service-account-permissions — actAs e Token Creator.
- https://www.mercadopago.com.br/developers/pt/docs/checkout-pro-preferences/test-accounts — ambiente e credencial de teste.
- https://www.mercadopago.com.br/developers/pt/docs/checkout-pro-preferences/payment-notifications — HMAC e evento Payments.
- https://www.mercadopago.com.br/developers/pt/reference/online-payments/checkout-pro-preferences/create-preference/post — integração por preferências.
