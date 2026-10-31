# Mercado Pago — pré-homologação sandbox em modo de consulta

> Preservação documental — 31/10/2026.
> Este documento registra a investigação no checkout local
> `homolog/technical-candidate-20261028`, baseado em
> `98160d47f7a0ca341fbd7f80eda3db72fe0acb60`, com trabalho não publicado.
> Na base remota desta preservação
> (`2378d780f4c9ef79f0d3c0c220b3430adbc56003`), o reconciliador
> ainda exige `TEST-`. A aceitação condicionada de `APP_USR-`, com
> verificação de identidade, existe somente no trabalho local não publicado.
> O preflight local falhou por ausência de credencial verificável disponível;
> esse resultado não demonstra bloqueio por prefixo no código local.
> A exclusividade da credencial para testes não foi comprovada; Mercado Pago
> permanece não homologado.
>
> Este commit preserva somente documentação, sem publicar a implementação local.
> Os estados e menções a ausência de commit nas seções históricas referem-se
> às respectivas etapas da investigação, anteriores a esta preservação.
> Caminhos de custódia privada foram omitidos; nenhum arquivo privado acompanha
> esta documentação. Leia os registros cronológicos como histórico do checkout,
> não como descrição da implementação publicada ou homologação da candidata .6.

Resultado: **bloqueado para prova externa e ponta a ponta; Mercado Pago não homologado**.
Repositório japarocha2-cloud/rocha-plus. PR #42 consultada: OPEN, isDraft=true.
Branch local homolog/technical-candidate-20261028; HEAD base 98160d47f7a0ca341fbd7f80eda3db72fe0acb60.

Nenhum pagamento, checkout, estorno, deploy, merge, publicação, build de APK ou
alteração no reconciliador foi feito nesta etapa. Testes verdes não foram repetidos.

## 🟢 Pré-requisitos confirmados

- Runtime conectado, observações atuais, política de rede aplicada. Não há bindings
  de credenciais/variáveis/identidades de saída no runtime. Isso não informa os
  segredos eventualmente existentes no GitHub ou no PC do operador.
- Operador existente `audit_provider.js --check`, com Node 22 e `--use-env-proxy`,
  informou transportReady=true, providerCalled=false e providerCredentialVerified=false.
  É prontidão de configuração TLS/proxy, não autenticação na API do Mercado Pago.
- Projeto permitido no reconciliador isolado: demo-rocha-sandbox. SDK aponta para
  loopback e exige concordância entre ambiente fornecido e process.env.
- Configuração de emuladores: Firestore 127.0.0.1:8086, Auth 127.0.0.1:9097;
  singleProjectMode=true; interface desligada; regras do cliente negam leitura/escrita.
- O reconciliador sandbox exige recibo com live_mode estritamente false, ID esperado,
  recebedor esperado, moeda e valor coincidentes com claim previamente revisado.
- Verificação de vendedor existente exige ID independente, site MLB e tag test_user.
- Contratos já aprovados foram preservados como evidência HISTÓRICA: há provas locais
  de emulador/contrato Flutter, mas com respostas do provedor simuladas.
- PR #42 permanece aberta e draft, segundo consulta somente leitura ao GitHub.
- Sete arquivos protegidos mantêm seus hashes nesta etapa. APK e ZIP congelados da
  candidata .6 coincidem com o manifesto de congelamento. Zero chamadas ao Figma.

## 🟡 Configurações pendentes

1. **Vendedor e comprador:** há registro anterior do operador de contas de teste
   distintas e correspondência das identidades na consulta do recibo. Não foi
   refeita essa consulta verde. As identidades esperadas não estão configuradas
   para esta execução, e não houve autenticação nova para confirmar estado atual.
2. **Sessão de emulador:** configuração está pronta, mas não há listeners nas portas
   8086/9097 e GCLOUD_PROJECT/FIRESTORE_EMULATOR_HOST não estão definidos no processo.
   Nenhum emulador foi iniciado e nenhum documento foi escrito nesta etapa.
3. **Plano privado independente:** não foi disponibilizado um plano revisado para
   execução real. Precisa estar fora do repositório, arquivo regular do operador,
   modo 600, project=demo-rocha-sandbox, UID sandbox-* e claims de IDs distintos
   conforme a fase. reviewed=true somente após revisão efetiva.
4. **Preço/plano:** os valores do catálogo são mensal 450 centavos e anual 4950,
   BRL. O código exige plano permitido, valor positivo e correspondência com recibo;
   NÃO valida automaticamente a tabela plano↔preço. Essa associação precisa ser
   conferida independentemente no plano privado antes de executar.
5. **Comprador/UID:** o reconciliador confere collector_id contra merchantId;
   NÃO estabelece automaticamente payer.id↔UID. UID/plano vêm do claim revisado,
   não são provados pelo recibo. É necessária evidência independente da associação;
   formato sandbox-* ou um external_reference com padrão esperado não bastam.

## 🔴 Bloqueios encontrados

- **Credencial TEST- indisponível neste executor.** Não existem variáveis com nomes
  Mercado Pago reconhecidos/documentados; ROCHA_MP_SANDBOX_ACCESS_TOKEN e
  MP_TEST_ACCESS_TOKEN estão ausentes. O arquivo privado documentado também não
  existe. Não se leram arquivos de segredo nem se expuseram valores.
- O preflight existente retornou exitCode=2,
  sandboxCredentialAvailableAndAccepted=false. Não houve chamada à API do provedor.
- **Nenhum recibo genuíno live_mode=false foi confirmado como disponível.** O único
  recibo historicamente inspecionado após aprovação visual do checkout apresentou
  live_mode=true e não pode passar na reconciliação sandbox. Isso não permite
  concluir, por si só, que houve cobrança real; permite concluir que a evidência
  não atende ao critério sandbox exigido. Não é uma nova consulta deste executor.
- Não há plano privado revisado e sessão local preparada para a prova externa.
- Não existe evidência externa ponta a ponta. Os resultados simulados anteriores
  e a captura de aprovação da interface não substituem um recibo sandbox genuíno.

O helper sandbox histórico admite TEST- e APP_USR- com verificação de vendedor
para o segundo formato. **Isso não foi usado para ampliar a autorização atual**:
nenhuma credencial APP_USR- ou de produção foi consumida, e a exigência TEST-
desta etapa permanece. Prefixo, sozinho, não comprova ambiente de uma operação.

## Próxima ação técnica recomendada

1. Disponibilizar uma credencial de TESTE autorizada, por configuração privada do
   ambiente, sem colá-la no chat, nos argumentos ou no repositório. Se o painel
   não oferecer TEST-, esclarecer o fluxo oficial antes de substituir o formato;
   não usar token de produção nem alterar o prefixo de um token existente.
2. Identificar recibo de teste JÁ EXISTENTE e fornecer IDs esperados de vendedor e
   comprador por entrada privada. Consultar apenas GET /users/me e
   GET /v1/payments/{id}, com TLS/proxy preservados. Exigir live_mode=false.
   A consulta atual está bloqueada pela ausência da credencial; não repetir a
   compra anterior nem criar pagamento/estorno para contornar esse bloqueio.
3. Revisar o plano independentemente do recibo: UID de teste, vínculo do comprador,
   plano, valor esperado, BRL e recebedor. Não inventar dados nem marcar reviewed
   automaticamente. Se a exigência for associação automática verificável, há uma
   lacuna no caminho sandbox atual que deve ser especificada separadamente.
4. Somente com esses insumos, iniciar sessão efêmera do projeto demo-rocha-sandbox
   com Firestore em loopback e usar o operador existente para a nova evidência
   provedor→reconciliação local. Não repetir contratos simulados verdes.
5. Para ciclo completo, são necessários recibos existentes compatíveis com cada
   fase: compra aprovada sem estorno; renovação por dois IDs distintos, em ordem
   temporal, mesmo recebedor; estorno integral/chargeback confirmado pelo provedor.
   Preservar o trial e a mesma sessão entre fases; não inicializar novamente datas.
6. Mesmo que a reconciliação local passe, o operador retorna
   applicationEndToEndApproved=false. Ponta a ponta no aplicativo exige cliente
   sandbox separado, autenticação e acesso validados nesse isolamento. A .6
   congelada consulta o candidato cloud e não deve ser redirecionada ao emulador.
   Nenhuma alteração de cliente foi autorizada ou realizada nesta etapa.

Se não houver recibos genuínos existentes para as fases, manter a execução
bloqueada e registrar a ausência. Não realizar novos pagamentos nesta etapa.

## Evidências verificáveis

- `functions/sandbox/firebase.json`: hosts/portas locais e singleProjectMode.
- `functions/sandbox/reconcile.js:10`: guardas do projeto/loopback.
- `functions/sandbox/reconcile.js:22`: consulta e validação estrita do recibo.
- `functions/sandbox/reconcile.js:74`: associação a claim revisado e comparação
  de UID, plano, moeda, valor e recebedor, com os limites descritos acima.
- `functions/sandbox/audit_provider.js:11`: validação do plano independente.
- `functions/sandbox/test_identity.js`: gate de vendedor brasileiro de teste.
- `functions/sandbox/private_inputs.js`: entrada privada existente, sem criar secrets.
- `docs/auditoria/2026-10-30-mercado-pago-suporte.md`: divergência histórica live_mode.
- Evidência nova expurgada: `[custódia local privada; não publicada]`.
- Evidências históricas preservadas, não reexecutadas:
  `iteration-16k/sandbox-access-contract-evidence.json`,
  `iteration-16k/provider-phase-evidence.json` e
  `iteration-16k/sandbox-account-bound-evidence.json`, no diretório privado.

Resumo desta etapa: 0 novas chamadas Mercado Pago, 0 pagamentos, 0 escritas de
banco, 0 testes verdes repetidos, 0 alterações de código de produção/catálogo/APK.


## Revisao pontual APP_USR- — sem mudanca de validacao

Ver [revisao pontual](2026-10-30-mercado-pago-app-usr-revisao-pontual.md).
O helper atual ja aceita o formato APP_USR- com identidade de conta verificada;
a restricao TEST- da pre-homologacao era escopo da tarefa, nao um bloqueio
sintatico atual. Documentacao oficial web retornou 403; exclusividade de uma
credencial real de teste nao comprovada. Guardas preservadas; nenhum codigo,
teste verde, pagamento, commit, APK, deploy ou estado de PR alterado nesta etapa.
