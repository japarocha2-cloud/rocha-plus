# Assinatura no LAB físico — 27/10/2026

Somente branch fix/subscription-access-20261026. PR permanece draft; sem merge, publicação, cobrança ou alteração financeira.

LAB 713 instalado: menu Assinatura abriu em aparelho USB autorizado, com conta já conectada. Após Verificar acesso, a indicação mudou de Assinatura ainda não verificada para Acesso confirmado pelo servidor. É prova física de consulta positiva nessa conta, não prova de pagamento, motivo ou validade. Identificadores e logs permanecem locais.

A tentativa automática de atualizar o LAB (Actions 40601197328) foi bloqueada antes de preparar credenciais/gerar APK: tools/prepare_homologation.py exige workflow_dispatch. Não foi falha de login nem prova de secret incorreto. O disparo automático incompatível foi retirado; guarda manual preservada.

Para atualizar com assinatura existente, executar manualmente Build Rocha+ na branch experimental, homologation_login=true, signed_login=true, subscription_lab=true e entitlement_url=https://southamerica-east1-rocha-plus-homologacao.cloudfunctions.net/entitlement. O job de homologação confere pacote .lab/certificado OAuth; não existe publicação em loja nesse caminho. A atualização deve preservar dados; não desinstalar o LAB nem fazer downgrade.

Atualização do workflow reutilizável acrescenta opção numérica de versionCode, preservando o padrão anterior, e aplica a correção isolada do ciclo de vida VLC já usada nos testes USB antes de analisar/testar/compilar. Não muda lógica de assinatura, pagamentos ou backend.

VERDE: consulta positiva no LAB 713. AMARELO: build atual, motivo trial/pago/expirado físico, sete dias/persistência, contas de teste, renovação/estorno simulados e reconciliação. Nenhum pagamento aplicado. Backend functions/index.js retorna reason, mas não expiresAt; a tela atual só exibe validade quando recebida, sem inventá-la.
