# Cadastro seguro dos secrets Mercado Pago — preparação, sem execução
Projeto exclusivo: rocha-plus-homologacao.
Código conferido em functions/index.js: defineSecret('MP_RECEIVING_ACCESS_TOKEN') e defineSecret('MP_WEBHOOK_SECRET').

## Valores esperados e procedência
MP_RECEIVING_ACCESS_TOKEN: access token oficial da aplicação/integração destinada ao ambiente de homologação, com conta recebedora revisada. É credencial de servidor; não entra em APK, Firebase client config ou logs.
MP_WEBHOOK_SECRET: chave secreta de assinatura fornecida pelo Mercado Pago na configuração de Webhooks da MESMA integração/ambiente revisados. Não é public key, access token, token Firebase ou senha. Não inventar uma chave aleatória como substituta.
Não copiar automaticamente tokens de produção ou secrets do GitHub. A confirmação prévia do merchant não comprova, sozinha, que a aplicação e o modo de uma credencial são adequados a este novo ambiente.
Antes de fornecer os valores ao script, confirmar a origem, aplicação e modo de cada credencial. Se o token escolhido só for de teste, não relaxar o reconciliador comum: ele atualmente exige live_mode=true para concessões. Fixtures e simulações isoladas não autorizam cobrança real.
Se obter o segredo no painel exigir cadastrar/ativar URL de webhook ou mudar a integração operacional, parar e solicitar autorização separada. Este procedimento não registra URL nem ativa notificações.

## Execução posterior, somente com autorização específica de cadastro
Script preparado: tools/homologation/register_mp_secrets.sh.
Na Cloud Shell privada, sem screen sharing/gravação, com a branch revisada em checkout e identidade aprovada:
```bash
gcloud auth list --filter=status:ACTIVE --format='value(account)'
bash tools/homologation/register_mp_secrets.sh --cadastro-autorizado
```
O script fixa o projeto, confirma projectId, exige confirmação explícita da procedência e duas digitações ocultas de cada valor. Não usa argumentos contendo valores, variáveis exportadas, arquivos temporários, artifacts ou commits para credenciais.
Cria somente os dois nomes exatos e adiciona versões via stdin. Não altera IAM, configuração de Functions, flags ou qualquer dado financeiro.
O argumento não substitui autorização humana nem valida a procedência automaticamente.
Em secret já existente, falha de IAM ou cadastro parcial: parar e revisar o estado; não apagar secrets, contornar falhas ou sobrescrever versões por tentativa. O script não executa rollback financeiro/IAM nem reexecução automática.
Nenhum dos comandos de cadastro foi executado nesta preparação.

## Permissões mínimas por finalidade
- Operador de cadastro: secretmanager.secrets.create no projeto e secretmanager.versions.add nos dois secrets; resourcemanager.projects.get para a validação de destino do script e acesso de uso da API quando exigido. Não necessita ler payload de versões ou alterar políticas para cadastrar.
- Runtime de checkout: secretmanager.versions.access somente em MP_RECEIVING_ACCESS_TOKEN.
- Runtime de mercadoPagoWebhook: secretmanager.versions.access somente em MP_RECEIVING_ACCESS_TOKEN e MP_WEBHOOK_SECRET.
- O papel pré-definido roles/secretmanager.secretAccessor, aplicado separadamente nos secrets necessários à conta de runtime aprovada, fornece acesso ao payload. Não conceder no projeto inteiro nem dar acesso a entitlement por este cadastro.
- Deployer pode precisar leitura de metadados/versões para validar bindings; não necessita acesso ao payload apenas para configurar referência. Se o CLI pedir concessão de acesso runtime, interromper: qualquer mudança IAM exige revisão e autorização separadas.
Não atribuir automaticamente acesso à identidade do Actions, à conta proprietária ou a contas default. A conta runtime/build candidata anterior ainda precisa de seleção e confirmação. A permissão actAs é separada da leitura dos secrets.

## Flags e pendências exatas
Manter ROCHA_CHECKOUT_ENABLED=false e ROCHA_WEBHOOK_RECONCILIATION_ENABLED=false na futura configuração dos dois exports novos. Cadastrar secret não ativa essas flags nem implanta serviços.
Pendências: origem/aplicação/modo dos dois valores revisados; autorização específica do cadastro; confirmação de create/addVersion para a identidade que executará; escolha da conta de runtime e confirmação futura de acesso secretAccessor somente aos secrets necessários.
A evidência do proprietário de API ativa e ausência de secrets foi incorporada, sem repetir consultas. Permissões da conta proprietária não são transferidas automaticamente à service account do Actions.
Produção, entitlement, Nádia, Candidata 6, LAB 714 e catálogo não foram alterados. Nenhuma cobrança ou teste concluído foi executado.
