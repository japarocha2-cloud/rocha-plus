# Continuidade: bundle preparado sem nova leitura Cloud — 04/11/2026
Branch impl/commercial-checkout-20261104.

## Resultado executado
URL real confirmada anteriormente registrada no template público pelo commit 4c7a8bea932282b44d255404104f15a27a9d2b4c. Nenhum GET de entitlement ou Cloud Storage foi repetido.
O JSON Firebase/OAuth atualizado e já validado foi utilizado para preencher um candidato LOCAL PRIVADO do bundle: Firebase App ID, Sender ID, API Key e OAuth Web. Não foram registrados no Git, logs ou artifacts.
Também preenchidos no candidato: merchant já confirmado e metadados de revisão estrutural efetivamente realizada. A revisão não é autorização de IAM, deploy ou compra.
Arquivo privado fora do repositório, diretório 0700, arquivo 0600. Não foi escrito o secret do GitHub. Checkout e reconciliação do webhook permanecem false no candidato.
Único campo de dados pendente no candidato: checkout_url.

## Comparação e limite de evidência
O contrato descrito pelo responsável na tela Origem (Firebase UID, entitlements/{uid}, trial e paidUntil; reconciliador com vínculo revisado) é compatível com a implementação do repositório. Isso permite continuar a preparação do bundle sem solicitar novo IAM de Storage.
Não há screenshot integral, export da fonte ou digest do handler implantado disponível para provar igualdade integral. Fonte do repositório e descrição visual parcial não provam que todas as linhas, dependências e regras implantadas sejam iguais.
A leitura anterior registrou apenas HTTP 403 do objeto de source; não persistiu bucket/object/generation. Logo a coordenada exata não pode ser recuperada dessa evidência. Não inventar endereço gs:// nem solicitar papel amplo de Storage. Se igualdade integral for exigida na revisão, obter a referência exata do arquivo exibida na Origem/metadata já disponível ao operador ou o arquivo privado correspondente; storage.objects.get no objeto específico seria a capacidade de leitura pertinente, não foi solicitada/concedida.
Nenhuma nova consulta Cloud nem alteração de IAM executada.

## Próximo bloqueio real
Checkout ainda não tem URL de implantação comprovada. Obter essa URL depende de implantação restrita autorizada, com permissões de implantação e efeitos sobre usuários verificados. O papel de visualizador recém-validado comprova leitura, não implantação.
Após a revisão/autorização específica: implantar apenas checkout e mercadoPagoWebhook em rocha-plus-homologacao com ROCHA_CHECKOUT_ENABLED=false e ROCHA_WEBHOOK_RECONCILIATION_ENABLED=false, preservando entitlement. Não registrar URL no Mercado Pago.
Só depois acrescentar a URL retornada pela implantação ao candidato privado e registrar o secret ROCHA_CHECKOUT_HOMOLOGATION_JSON por identidade autorizada; então executar o build assinado.
Nesta execução não houve deploy, testes repetidos, build prematuro, cobrança, secret remoto alterado ou mudança em Candidata 6, LAB 714, catálogo/visual, Nádia ou produção.
