# Mercado Pago — revisão pontual da validação APP_USR-

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

**Resultado: nenhuma alteração de validação aplicada. Execução externa permanece bloqueada.**
A premissa de que o módulo atual aceita apenas TEST- não corresponde ao código
presente no workspace. Não remover ou enfraquecer guardas para corrigir um
bloqueio por prefixo que já não existe nesta implementação.

## 🟢 Confirmado

- `test_identity.js:credentialFormat` já permite os formatos TEST- e APP_USR-.
- `reconcile.js:sandboxToken` exige recebedor esperado independente para APP_USR-.
- Antes da consulta do pagamento, o caminho APP_USR- chama GET /users/me, exige
  ID correspondente, site MLB e tags contendo test_user. A identidade é relida
  a cada consulta. Conta comum, perfil malformado ou recebedor diferente falham.
- GET /v1/payments/{id} continua exigindo live_mode estritamente false, ID e
  collector_id correspondentes. Modo true, ausente ou null são recusados.
- Projeto demo-rocha-sandbox, loopback do emulador, igualdade do ambiente real
  do SDK, claims independentes revisados e comparação de moeda/valor/recebedor
  continuam intactos. Sem criação de pagamento, assinatura ou estorno.
- O preflight --check verifica disponibilidade/formato e transporte; não autentica
  a credencial e não demonstra que ela pertença a sandbox. Uma entrada aceita
  sintaticamente não significa providerCredentialVerified=true.
- A causa observada na pré-homologação foi ausência de credencial disponível no
  executor. O escopo TEST- daquela solicitação era uma restrição da tarefa, não
  a descrição completa dos formatos já aceitos pelo helper.
- PR #42 consultada via API GET: aberta e draft. Não alterada.

## Documentação oficial consultada nesta tarefa

As três páginas oficiais abaixo foram consultadas por GET, sem credenciais,
com proxy/TLS herdados; todas retornaram HTTP 403:

- https://www.mercadopago.com.br/developers/pt/docs/subscriptions/integration-test
- https://www.mercadopago.com.br/developers/pt/docs/your-integrations/credentials
- https://www.mercadopago.com/developers/en/docs/subscriptions/integration-test

Não foi possível verificar o texto atual dessas páginas nem uma garantia oficial
específica de exclusividade da credencial para Assinaturas. Não tratar URL, título
da seção do painel ou prefixo como prova suficiente dessa exclusividade.

Foi lido com sucesso o código do SDK oficial atual:
https://raw.githubusercontent.com/mercadopago/sdk-nodejs/master/src/clients/payment/commonTypes.ts
O campo live_mode é documentado como `true` quando o pagamento foi criado em
produção. Isso sustenta preservar a rejeição de recibos true; não comprova o
ambiente exclusivo de uma credencial APP_USR-.

## 🟡 Pendências e limites da prova

- O guard de identidade prova a identidade/tipo da conta retornada por /users/me;
  não é, isoladamente, um certificado do modo exclusivo da credencial/aplicação.
- Nesta execução não existe credencial real disponibilizada nem plano privado
  revisado para validar a cadeia externa. Nenhum token foi solicitado ou consumido.
- O histórico já registra aprovação visual de checkout e conta de teste, seguida
  de recibo live_mode=true. Não reutilizar isso como sandbox genuíno, nem repetir
  essa compra. Nem conta test_user nem o prefixo substituem o modo do recibo.
- UID e plano continuam vindo do claim independente revisado. Conforme relatório
  anterior, o código não automatiza comprador↔UID ou tabela plano↔preço. Nenhuma
  correção desses outros pontos foi iniciada nesta tarefa pontual.

## 🔴 Bloqueio e alternativa segura

Não foi comprovado que uma credencial APP_USR- disponível pertença exclusivamente
ao ambiente de testes. Logo, nenhuma validação foi alterada para ampliar aceitação
ou autorizar execução real. O formato já aceito permanece submetido às guardas.

Dependência exata: evidência oficial verificável aplicável à modalidade Assinaturas
sobre a credencial de teste, mais identidade independente do vendedor e uma
credencial real de teste disponibilizada por configuração privada autorizada.
A consulta externa do recibo existente ainda precisa resultar em live_mode=false,
ID e recebedor esperados; UID, plano, valor e moeda precisam de claim revisado.
Se o provedor não fornecer comprovação compatível, manter a execução bloqueada
até esclarecimento oficial. Não trocar prefixos, aceitar conta normal, confiar em
flag do cliente ou remover a exigência live_mode=false como alternativa.

Estas são dependências registradas, não execução/autorização de outra etapa.
Nenhum pedido de token foi feito ao operador e nenhum novo pagamento foi realizado.

## Arquivos, testes, commit e preservação

- Código modificado: **nenhum**, incluindo o módulo experimental.
- Documentação nova: este relatório; nota de continuidade no relatório de
  pré-homologação e no estado atual.
- Testes executados nesta tarefa: **nenhum**. Nenhum comportamento foi alterado;
  a cobertura existente foi inspecionada sem repetir testes verdes.
- Cobertura existente inspecionada: test_identity.test.js,
  identity_native_transport.test.js, account_bound_phase.test.js,
  reconcile.test.js e private_inputs.test.js. Casos de conta normal, identidade
  errada, recibo live/malformado e ausência de identidade já estão contemplados.
- Commit novo: **nenhum**. HEAD base 98160d47f7a0ca341fbd7f80eda3db72fe0acb60.
  Há alterações locais de tarefas anteriores; não confundir HEAD com a entrega .6.
- Onze hashes de arquivos protegidos iguais antes/depois: reconciliador sandbox,
  gate de identidade, leitor de entradas privadas, código de produção, catálogo,
  identidade e manifesto congelado da candidata .6.
- Nenhuma alteração no Figma, Oficial ou .6; sem build, merge, deploy ou publicação.
- Evidência expurgada: [custódia local privada; não publicada]
- Status HTTP da documentação: official-documentation.json no mesmo diretório.

**Mercado Pago não homologado. Tarefa pontual encerrada; nenhuma etapa seguinte iniciada.**
