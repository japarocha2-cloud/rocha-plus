# Pagamentos Rocha+ — candidato de testes, sem lançamento
## Regras
Mensal BRL 4,90; oferta trial-7-days de P7D somente para novos assinantes elegíveis.
Sem teste disponível, apresentar assinatura mensal sem promessa de gratuidade.
Cancelamento na Google Play mantém acesso até expiryTime. Grace period mantém acesso;
pending, hold, pause, expired e erro de verificação não concedem acesso.
Beta continua gratuito após autenticação. Nenhuma conexão à loja em Beta.
Backend rejeita qualquer resposta Play sem testPurchase. Não remover essa proteção
nem mudar RochaReleasePolicy.stage sem autorização explícita de lançamento.

## Configuração manual (não executada por este PR)
1. Play Console: conferir app com.rochaplus.app, perfil de pagamentos e assinatura
   de uploads. Criar produto rocha_plus_monthly, base plan monthly, período P1M,
   Brasil BRL 4,90; criar oferta trial-7-days com fase gratuita P7D e elegibilidade
   gerenciada pela Play para novos assinantes. Não ativar vendas em produção.
2. Configurar testadores licenciados e track interno; instalar pela Play usando
   conta licenciada e confirmar que o diálogo indica compra de teste.
3. Firebase/Google Cloud: habilitar Firestore e Android Publisher API, atribuir à
   identidade do backend somente permissões necessárias para consultar e reconhecer
   assinaturas no app pela Play Console. Credenciais ficam no servidor por ADC.
4. Implantar backend/index.js como Firebase Functions somente em ambiente de testes,
   dependências backend/package.json; definir rules privadas de billingUsers e
   billingTokens, mesclando com regras existentes. Nunca substituir regras de
   outras áreas sem revisão. Nenhuma implantação está incluída aqui.
5. Para candidato comercial de TESTES, revisar mudança de stage para official em
   branch separada e fornecer ROCHA_BILLING_ENDPOINT HTTPS da function billing.
   Builds Beta e prévias visuais não precisam de endpoint e não compram.
6. Renovação, cancelamento e revogação são consultados novamente na Play em cada
   acesso ao endpoint entitlement e a cada 30s no cliente, ao retornar ao app e na
   restauração. Erro de rede bloqueia modo comercial. ExpiryTime tem timer local.
   Antes do lançamento adicionar RTDN autenticado, observabilidade e testes de
   integração com emulador Firestore; o polling não é comprovação de entrega RTDN.

## Segurança e limites
Firebase ID token verificado com revogação; UID não vem do corpo do cliente.
Obfuscated account ID SHA256 vincula compra e conta; token reclamado por transação.
Produto e base plan são conferidos pela resposta Publisher, nunca pelo cliente.
Reconhecimento somente após validação; pendente não é reconhecido.
Tokens privados no Firestore, nenhuma leitura/escrita cliente, nenhum log de tokens.
Tela e compra conferem fases BRL/P1M/4900000 micros e P7D quando elegível.
Trocar conta exige sair/entrar; compra não migra entre contas Firebase.
Este aplicativo usa canais públicos: o gate evita reprodução pelo app comercial,
mas não protege URLs públicas contra uso externo nem contra cliente modificado.
Proteção de conteúdo próprio exige URLs/DRM autorizados pelo backend.
Ao perder direito, a navegação é recriada para descartar player/fullscreen;
Cast recebe pedido de encerramento e proxy local fecha. Falha de rede no receptor
pode impedir parada imediata: validar em aparelho antes de qualquer lançamento.

## Matriz obrigatória em Play/aparelho (ainda não comprovada)
- Compra de teste elegível P7D, compra sem oferta, usuário cancela diálogo.
- Pending não libera; purchased validado libera; backend indisponível bloqueia.
- Reinstalação/restauração, troca de conta, replay concorrente de token.
- Renovação acelerada, cancelamento com direito restante, expiry, grace, hold,
  recuperação, refund/revoke e retorno de background.
- Player, fullscreen, Cast ativo e proxy na expiração; categorias Infantil/Notícias,
  scanner, Home e controles de TV, celular pequeno e orientação horizontal.
- APK assinado/Firebase e instalação por track de teste. Build preview de PR é
  somente visual e não prova login/compra real.

## Evidências
CI original main 231bca553bdd2417ae33bab68fd324d783febdf1:
Build Rocha+ 37853595491 e 37823568190 concluídos com sucesso.
Testes deste PR: verificar links e resultados atuais no PR; não interpretar
testes de política ou build como compra real comprovada.
