# Assinaturas e versões a partir da Build #510

## Referência preservada

Build #510, commit `9652b3dbc60ad962e570c9afe17e6f19c58a291f`, APK universal versionCode 3510, SHA-256 `d616a2be4ea3800604d4a3ee07b92514b02e0b8c7cb00f5135d88e95a19dff91`.

Lucas confirmou no aparelho login, favoritos, assinatura, reprodução, catálogo, visual, ícone, introdução, áudio e espelhamento. Esse relato aprova o APK instalado; não é teste físico de cada plataforma TV.

A branch `frozen/build-510-physical-approved` preserva essa referência. Toda esta etapa comercial fica em `feat/mercadopago-trial-20261013`.

A #510 existente permanece beta gratuito: um APK congelado não recebe um bloqueio de assinatura que não estava em seu código. O controle comercial será aplicado na próxima versão configurada e instalada.

## Comportamento comercial implementado

- Primeiro acesso confirmado pelo servidor cria um único prazo de sete dias para o UID Firebase.
- Celular e TVs da mesma conta consultam a mesma validade; sair/reentrar/reinstalar não reinicia o prazo.
- Após o prazo, o app fecha a navegação privada e solicita assinatura. Abrir um checkout ou voltar dele não libera acesso.
- Mensal: R$ 4,90 e um mês civil; anual: R$ 55,00 e doze meses civis. Se o usuário comprar durante o teste, os dias gratuitos restantes são preservados.
- Cada checkout tem uma referência aleatória vinculada no servidor à conta e ao plano. O app não escolhe preço ou UID.
- Webhook validado pelo SDK oficial Mercado Pago; o servidor consulta o pagamento na API e compara conta recebedora, ambiente, referência, valor e moeda.
- Duplicatas não renovam novamente. Estorno, contestação ou reembolso parcial retiram a concessão daquele pagamento. Atualizações antigas não readmitem pagamento revogado.
- Esta etapa vende períodos de acesso: **não há débito automático recorrente**. Renovação depende de novo pagamento; recorrência exige integração e aceite próprios.
- Não há migração automática de pagamentos antigos dos links genéricos da #510 para uma conta. Havendo compradores anteriores, reconciliar o pagamento e a identidade antes do lançamento.

## Mesma base por plataforma

| Plataforma | Implementação | Validação desta etapa |
| --- | --- | --- |
| Celular Android | Flutter da #510 + bloqueio comercial | Testes automatizados; nova versão ainda depende de servidor e aparelho |
| Android TV / Google TV / Fire TV | Mesma base Flutter, catálogo, recursos, player e política de acesso | Compatibilidade de login/controle/Cast por aparelho ainda precisa de confirmação |
| Roku | BrightScript existente reaproveitado, conta pareada, assinatura pelo mesmo UID, catálogo exato e exclusões persistentes | Compilação BrightScript realizada; configuração e teste físico pendentes |
| LG webOS / Samsung Tizen | Cliente web existente reaproveitado, pareamento e assinatura, favoritos por conta e exclusões persistentes | Testes do adaptador e sintaxe; SDKs de empacotamento e TVs reais pendentes |
| Chromecast antigo | Cast do app Android, sem APK próprio | A #510 foi aprovada pelo usuário; o bloqueio comercial tenta encerrar a sessão ao perder acesso |

`catalog/approved.json` e `catalog/quarantine.json` são a fonte única. `tools/sync_platform_baseline.py` exporta os mesmos bytes para Roku e web-TV, verifica evidência e recusa fontes não aprovadas. Não consulta playlists públicas. Nenhum fallback experimental será exportado.

Recursos visuais e introdução são reaproveitados. Android usa os recursos já validados; web-TV inclui o mesmo vídeo; Roku usa URL HTTPS do mesmo vídeo, que ainda precisa ser hospedado/configurado. Compilação não comprova áudio/vídeo em televisores.

## Ativação pendente: servidor e credenciais

Código não equivale a serviço publicado. Nenhuma função, cobrança real ou permissão administrativa foi ativada nesta etapa.

1. Usar o **mesmo projeto Firebase** do login da #510, com acesso administrativo e Firestore disponível. Conferir o plano/custos antes de contratar ou ampliar serviços.
2. No projeto Firebase/Secret Manager, cadastrar `MP_ACCESS_TOKEN` e `MP_WEBHOOK_SECRET` pela interface segura ou Firebase CLI. Nunca colocar esses valores no APK, Git ou conversa.
3. Configurar parâmetros do servidor: `MP_COLLECTOR_ID`, `MP_NOTIFICATIONS_URL`, `ROCHA_FIREBASE_WEB_API_KEY` (configuração pública do cliente), `MP_LIVE_MODE=false` e `MP_PAYMENTS_ENABLED=false` inicialmente.
4. Publicar apenas a nova codebase: `firebase deploy --config firebase.billing.json --only functions:rocha-mercadopago --project PROJETO_CONFIRMADO`. As funções são `mercadoBilling`, `mercadoWebhook` e `rokuPairing`, região `southamerica-east1`.
5. Conferir as regras Firestore existentes antes de alterá-las. Mesclar os três bloqueios de `billing/firestore.rules` e impedir permissões amplas sobre essas coleções; não substituir regras de favoritos/outros serviços às cegas. O SDK Admin usa IAM.
6. Pareamento requer emissão de custom tokens pelo SDK Admin. Conferir a permissão mínima de assinatura para a identidade da função e a API de autenticação. Não conceder papéis amplos ao aplicativo cliente.
7. No Mercado Pago, configurar o evento `payment` para a URL publicada de `mercadoWebhook`, e testar com credenciais de teste. Confirmar pagamento, pendência, duplicata e estorno com duas contas.
8. Após essa validação, configurar credenciais/recebedor de produção e habilitar `MP_LIVE_MODE=true` e `MP_PAYMENTS_ENABLED=true`. A compra real é realizada pelo usuário, não pelo agente.
9. No GitHub, configurar as variáveis públicas `ROCHA_BILLING_API_URL` e `ROCHA_ROKU_PAIRING_ENDPOINT` com as URLs publicadas. O pipeline recusa APK comercial com URL ausente/insegura.
10. Configurar os clientes Roku/web-TV com `tools/configure_tv_services.py`, incluindo URL HTTPS da introdução original para Roku.

O painel Firebase mostra registros em `rochaBillingUsers` (UID, e-mail verificado, fim do teste, pagamentos e validade) e `rochaBillingPayments` (estado conferido no provedor). A situação atual é calculada comparando a validade com a hora do servidor; uma fotografia antiga de `active` não deve ser interpretada como concessão eterna. Leitura administrativa usa IAM; clientes não podem enumerar assinantes.

## Testes físicos a executar depois da ativação

- Duas contas: A paga não libera B; reinstalar A não reinicia teste.
- Avançar o cenário em ambiente de teste do servidor, sem alterar o relógio do aparelho: sete dias acabam e fecham inclusive a rota do player.
- Pagamento pendente/rejeitado não libera; aprovado libera; duplicado mantém a mesma validade; estornado bloqueia.
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
