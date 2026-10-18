# Assinaturas e versões a partir da Build #510

## Referência preservada

Build #510, commit `9652b3dbc60ad962e570c9afe17e6f19c58a291f`, APK universal versionCode 3510, SHA-256 `d616a2be4ea3800604d4a3ee07b92514b02e0b8c7cb00f5135d88e95a19dff91`.

Lucas confirmou no aparelho login, favoritos, assinatura, reprodução, catálogo, visual, ícone, introdução, áudio e espelhamento. Esse relato aprova o APK instalado; não é teste físico de cada plataforma TV.

A branch `frozen/build-510-physical-approved` preserva essa referência. Toda esta etapa comercial fica em `feat/mercadopago-trial-20261013`.

A #510 existente permanece beta gratuito: um APK congelado não recebe um bloqueio de assinatura que não estava em seu código. O controle comercial será aplicado na próxima versão configurada e instalada.

## Comportamento comercial implementado

O contrato real é uma assinatura recorrente do Mercado Pago, criada pelos links já existentes, conforme a captura enviada por Lucas (adesão mensal em teste grátis, primeira cobrança indicada para 21/out). A produção agora usa `recurring_service.js`, não o protótipo anterior de pagamentos avulsos (`service.js`, mantido apenas para testes históricos). Não se cria outro plano, não se altera o contrato da irmã, nem se cobra dinheiro nesta correção.

- Os links continuam mensal R$ 4,90 → `https://mpago.la/2E7yjF4` e anual R$ 55,00 → `https://mpago.la/2b9hitF`.
- A consulta autenticada usa UID e e-mail **verificado do token Firebase**. Não aceita e-mail, UID, valor ou identificação de assinatura escolhidos pelo cliente.
- O servidor procura assinaturas dos dois IDs de plano configurados, consulta os detalhes e confere recebedor, plano, valor, moeda, recorrência, pagador e datas. Uma assinatura com referência externa de outro sistema exige revisão administrativa, não é reassociada silenciosamente.
- O mesmo e-mail no Google/Firebase e no Mercado Pago permite reconhecer adesões já feitas pelos links da #510. E-mails diferentes exigem prova de identidade e vínculo administrativo; nome, captura ou saber um ID não bastam. Uma assinatura já vinculada a outro UID não pode ser tomada.
- O primeiro acesso estabelece sete dias. UID e hash do e-mail verificado guardam o prazo no servidor; reinstalar ou recriar UID com o mesmo e-mail não renova. Isso **não impede uma pessoa de usar vários e-mails distintos**.
- O prazo não é prolongado pela adesão posterior: utiliza a menor data entre o teste registrado e o início original da assinatura. Uma nova `next_payment_date` não vira teste grátis. Não há acesso gratuito adicional, mas a agenda de cobrança existente no Mercado Pago não é alterada: se a pessoa aderir mais tarde a um plano com teste próprio, pode haver intervalo bloqueado até a primeira cobrança. Alinhar cobrança e teste contratual é uma configuração separada que precisa ser conferida no painel real, sem modificar contratos antigos automaticamente.
- `authorized` indica autorização para recorrência, **não pagamento realizado**. Depois dos sete dias, somente cobrança confirmada na API libera acesso. Cada fatura mensal cobre seu mês civil; a anual cobre doze meses. Não se soma teste novamente a cada fatura.
- Webhooks aceitam `subscription_preapproval`, `subscription_authorized_payment` e `payment`, validam assinatura com o SDK oficial e consultam os recursos correspondentes. O vínculo fatura → assinatura → UID e pagamento → recebedor/pagador/valor é conferido.
- Repetir uma notificação ou ter duas cobranças no mesmo ciclo não soma meses. Reembolso/contestação retiram o acesso concedido por aquele pagamento. Cancelamento/pausa interrompem o indicador de renovação; o período já pago continua até vencer, salvo estorno. Atualizações antigas não restauram pagamento/renovação revogados.
- O cliente mostra quando encontrou a assinatura. Voltar do checkout não libera reprodução. A concessão curta é renovada pelo servidor; expiração fecha player e navegação privada, inclusive Cast.

## Mesma base por plataforma

| Plataforma | Implementação | Validação desta etapa |
| --- | --- | --- |
| Celular Android | Flutter da #510 + bloqueio comercial | Testes automatizados; nova versão ainda depende de servidor e aparelho |
| Android TV / Google TV / Fire TV | Mesma base Flutter, catálogo, recursos, player e política de acesso | Compatibilidade de login/controle/Cast por aparelho ainda precisa de confirmação |
| Roku | BrightScript existente reaproveitado, conta pareada, assinatura pelo mesmo UID, catálogo exato e exclusões editoriais | Compilação BrightScript realizada; configuração e teste físico pendentes |
| LG webOS / Samsung Tizen | Cliente web existente reaproveitado, pareamento e assinatura, favoritos por conta e exclusões editoriais | Testes do adaptador e sintaxe; SDKs de empacotamento e TVs reais pendentes |
| Chromecast antigo | Cast do app Android, sem APK próprio | A #510 foi aprovada pelo usuário; o bloqueio comercial tenta encerrar a sessão ao perder acesso |

`catalog/approved.json` e `catalog/quarantine.json` são a fonte única. `tools/sync_platform_baseline.py` exporta os mesmos bytes para Roku e web-TV, verifica evidência e recusa fontes não aprovadas. Não consulta playlists públicas. Nenhum fallback experimental será exportado.

Recursos visuais e introdução são reaproveitados. Android usa os recursos já validados; web-TV inclui o mesmo vídeo; Roku usa URL HTTPS do mesmo vídeo, que ainda precisa ser hospedado/configurado. Compilação não comprova áudio/vídeo em televisores.

## Ativação pendente: servidor e credenciais

Código não equivale a serviço publicado. Nenhuma função, cobrança real ou permissão administrativa foi ativada nesta etapa.

1. Usar o **mesmo projeto Firebase** do login da #510, com acesso administrativo e Firestore disponível. Conferir o plano/custos antes de contratar ou ampliar serviços.
2. No projeto Firebase/Secret Manager, cadastrar `MP_ACCESS_TOKEN` e `MP_WEBHOOK_SECRET` pela interface segura ou Firebase CLI. Nunca colocar esses valores no APK, Git ou conversa.
3. Configurar parâmetros do servidor: `MP_COLLECTOR_ID`, `MP_MONTHLY_PLAN_ID`, `MP_ANNUAL_PLAN_ID` (IDs dos planos já existentes), `ROCHA_FIREBASE_WEB_API_KEY` (configuração pública do cliente), `MP_LIVE_MODE=false` e `MP_PAYMENTS_ENABLED=false` inicialmente.
4. Publicar apenas a nova codebase: `firebase deploy --config firebase.billing.json --only functions:rocha-mercadopago --project PROJETO_CONFIRMADO`. As funções são `mercadoBilling`, `mercadoWebhook` e `rokuPairing`, região `southamerica-east1`.
5. Conferir as regras Firestore existentes antes de alterá-las. Mesclar os cinco bloqueios de `billing/firestore.rules` e impedir permissões amplas sobre essas coleções; não substituir regras de favoritos/outros serviços às cegas. O SDK Admin usa IAM.
6. Pareamento requer emissão de custom tokens pelo SDK Admin. Conferir a permissão mínima de assinatura para a identidade da função e a API de autenticação. Não conceder papéis amplos ao aplicativo cliente.
7. No Mercado Pago, configurar os eventos `subscription_preapproval`, `subscription_authorized_payment` e `payment` para a URL publicada de `mercadoWebhook`, e testar com credenciais de teste. Confirmar pagamento, pendência, duplicata e estorno com duas contas.
8. Após essa validação, configurar credenciais/recebedor de produção e habilitar `MP_LIVE_MODE=true` e `MP_PAYMENTS_ENABLED=true`. A compra real é realizada pelo usuário, não pelo agente.
9. No GitHub, configurar as variáveis públicas `ROCHA_BILLING_API_URL` e `ROCHA_ROKU_PAIRING_ENDPOINT` com as URLs publicadas. O pipeline recusa APK comercial com URL ausente/insegura.
10. Configurar os clientes Roku/web-TV com `tools/configure_tv_services.py`, incluindo URL HTTPS da introdução original para Roku.

O painel Firebase mostra vínculos exclusivos em `rochaBillingSubscriptions`, prazo compartilhado em `rochaBillingEmailTrials` (somente hash do e-mail) e registros em `rochaBillingUsers` (UID, e-mail verificado, fim do teste, pagamentos e validade) e `rochaBillingPayments` (estado conferido no provedor). A situação atual é calculada comparando a validade com a hora do servidor; uma fotografia antiga de `active` não deve ser interpretada como concessão eterna. Leitura administrativa usa IAM; clientes não podem enumerar assinantes.

## Testes físicos a executar depois da ativação

- Duas contas: A paga não libera B; reinstalar A não reinicia teste.
- Avançar o cenário em ambiente de teste do servidor, sem alterar o relógio do aparelho: sete dias acabam e fecham inclusive a rota do player.
- Adesão `authorized` sem cobrança depois do teste não libera. Confirmar reconhecimento de uma adesão anterior usando o mesmo e-mail verificado. Pagamento pendente/rejeitado não libera; aprovado libera; duplicado mantém a mesma validade; estornado bloqueia.
- Retorno do checkout atualiza pelo servidor; perda de conexão não transforma acesso desconhecido em assinatura válida.
- Celular e TV pareada usam o mesmo UID e validade. Verificar controle remoto, introdução com áudio, vídeo/áudio, fullscreen e interrupção de Cast na perda de acesso.

Fontes oficiais: Firebase ID tokens (`https://firebase.google.com/docs/auth/admin/verify-id-tokens`), parâmetros/secrets (`https://firebase.google.com/docs/functions/config-env`), Mercado Pago Webhooks (`https://www.mercadopago.com.br/developers/en/docs/links-and-debts/additional-content/your-integrations/notifications/webhooks`).

## Aviso único e teste físico dos 7 dias

Após o primeiro login com teste ativo, o aplicativo mostra “Você ganhou 7 dias grátis!” e o botão “Começar a assistir”. O servidor reserva o aviso uma única vez por UID em transação; reinstalar, abrir em outro aparelho ou chamadas concorrentes não repetem o aviso. Um erro de rede não é tratado como teste vencido nem como novo teste. A reserva prioriza não repetir: caso o app feche entre reservar e desenhar o aviso, ele pode não chegar a aparecer. O prazo começa no primeiro acesso autenticado ao serviço, não no botão do aviso.

Para testar sem esperar uma semana, use uma conta descartável sem histórico de pagamento. O APK precisa ser completo, assinado e apontar para o serviço publicado. O utilitário administrativo abaixo é somente de terminal, exige credenciais administrativas fora do APK e não oferece endpoint para alterar prazo pelo cliente:

```
node billing/tools/expire-test-trial.mjs --project PROJECT_ID --test-uid TEST_UID
node billing/tools/expire-test-trial.mjs --project PROJECT_ID --test-uid TEST_UID --apply
```

O primeiro comando apenas verifica o resultado previsto. O segundo encurta somente o prazo da conta indicada; não modifica a regra global de 7 dias, não cria outro teste, não apaga o registro do aviso e recusa contas com pagamentos. Ainda não foi executado contra Firebase real.

Teste físico: entrar com a conta nova e observar o aviso; fechar e entrar novamente para confirmar que não repete; abrir um canal; vencer o prazo com o utilitário; usar “Já paguei / verificar acesso” ou aguardar a consulta periódica (até um minuto); confirmar que vídeo e áudio param, a tela de Assinaturas aparece e Voltar não reabre o player; reinstalar e confirmar que o mesmo UID permanece bloqueado. Pagamento e liberação devem ser verificados separadamente pelo fluxo oficial do Mercado Pago. Não alterar o relógio do celular para esse teste.

Visual do aviso aprovado por Lucas: menino de corpo inteiro fazendo um coração com as mãos, painel escuro com borda dourada, preços mensais/anuais e botão verde. O personagem é um asset com transparência; títulos, valores e botões são widgets reais. O diálogo tem rolagem para telas pequenas. A imagem fictícia inteira não é usada como tela do aplicativo.

## Auditoria real de uma conta já assinante

`billing/tools/check-recurring-account.mjs` é um diagnóstico administrativo somente de leitura: usa o UID informado, consulta o e-mail verificado no Firebase, procura os dois planos configurados, confere faturas e compara o vínculo persistido. Não cancela, cobra, cria assinatura ou grava no Firestore. Requer credencial administrativa já autorizada e `MP_ACCESS_TOKEN` fornecido de forma segura ao processo; nunca colocar o token na linha de comando, no Git ou nesta conversa.

```
node billing/tools/check-recurring-account.mjs --project PROJECT_ID --uid TEST_UID --collector COLLECTOR_ID --monthly-plan MONTHLY_PLAN_ID --annual-plan ANNUAL_PLAN_ID --live
```

Nesta correção passaram 27 casos novos de assinaturas recorrentes, além dos testes anteriores. A API do Mercado Pago e as transações Firestore são simuladas nesses testes. A consulta da conta real da irmã e a liberação física do APK continuam pendentes até disponibilizar acesso ao servidor/credenciais; uma captura de adesão não comprova vínculo no Firebase.
