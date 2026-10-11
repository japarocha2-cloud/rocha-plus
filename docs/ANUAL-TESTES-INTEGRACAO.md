# Rocha+ — integração anual em ambiente de testes

Branch: dev/founder-annual-app-integration. Base exata da PR #16: 8e0e3e36f19b3ab6f8a60894cd42185ae5f8483e. Conteúdo da PR #17: 471fe5d55c3bb0f1786d845f26bc47e77981c250.

## Implementação
- Planos fundadores de R$ 4,90/mês e R$ 53,90/12 meses no aplicativo, com economia anual de R$ 4,90. Futuro R$ 15,50/mês e R$ 170,50/ano somente informativo; filmes e séries sem data.
- Decisão do responsável: preservar as cores atuais do aplicativo. Assinatura, ajuda e documentos usam RochaTheme/RochaColors existentes, sem novo fundo ou paleta. O visual ciano/dourado/verde-água fica apenas na prévia web. Home/player/Cast/favoritos e o arquivo do tema foram preservados.
- Termos, regulamento, privacidade e Central de Ajuda da PR #17 incorporados como assets offline. Ajuda permite busca local; documentos seguem minutas, sem aceite contratual persistido.
- Produto de teste existente rocha_plus_monthly preservado; base plans monthly (P1M, BRL 4900000 micros) e yearly (P1Y, BRL 53900000 micros). O nome do produto é legado; a periodicidade vem do base plan, não do nome.
- Anual sem trial. Mensal só permite trial-7-days quando retornado pela loja com fase gratuita P7D e fase BRL 4,90/P1M. Sem promessa geral de teste grátis.
- Backend reconhece yearly e retorna basePlanId, mantendo verificação de conta, vencimento e rejeição de compras sem testPurchase antes de acknowledge.
- Beta continua gratuito e não consulta a loja. Fluxo de compra exige opt-in ROCHA_LICENSE_TEST_BUILD=true além do modo não beta; nenhum opt-in ou endpoint foi ativado nesta etapa.
- Simulador founder-sandbox.js cobre continuidade, cancelamento/vencimento/retorno e perda permanente. NÃO persiste elegibilidade e NÃO integra decisões de preço ao backend comercial.

## Plano de homologação Play, ainda pendente
1. Após liberação do Console, configurar produto existente e base plan yearly auto-renovável de 12 meses BRL 53,90, sem parcelamento e sem trial. Não ativar vendas públicas.
2. Preparar faixa interna, contas de licença e backend isolado que rejeite compras reais. Testar confirmação anual, restauração, cancelamento com acesso até vencimento, renovação acelerada, expiração, falha e conta incorreta.
3. Confirmar preços exibidos pela loja, período P1Y e ausência de fase promocional anual. Não substituir monthly nem encerrar coorte legada.
4. Definir corte fundador, aquisição do direito, migração e falhas involuntárias. Implementar armazenamento auditável por conta e histórico de assinatura no servidor; founder-sandbox é somente modelo de teste.
5. Aplicar preço legado conforme Google Play e comprovar retorno após cancelamento e vencimento sem recuperar benefício. Não confiar em texto, checkbox ou basePlanId para decidir fundador.
6. Homologar aceite versionado, identidade legal, suporte e exclusão de conta antes de venda. Solicitar autorização do responsável antes de publicar, ativar cobrança ou alterar main.

## Limites de validação
40 casos de backend executados localmente com as mesmas funções de teste e asserts, Publisher simulado; nenhum serviço externo de pagamentos chamado. Testes Flutter/Firestore e QA visual dependem da CI. Nenhum teste físico novo nesta etapa. Espelhamento continua pendência da PR #16; sessão conectada não comprova vídeo na TV.

Referências técnicas conferidas em 10/10/2026:
- https://developer.android.com/google/play/billing/subscriptions
- https://developer.android.com/google/play/billing/price-changes

## Avanço: persistência de fundador somente no emulador

- founder-test-store.js guarda registros e histórico de eventos em founderTestUsers, em transações. Rejeita qualquer projeto diferente de demo-rocha-billing ou host de emulador diferente de 127.0.0.1:8080. Não é importado/exportado pelo backend de cobrança.
- Matrícula de teste mensal conserva 490 centavos; anual, 5390. Matrícula repetida não sobrescreve o histórico, inclusive após perda do benefício.
- Eventos têm ID único e revisão esperada. Repetição é idempotente e retorna o estado atual; ID reutilizado para evento diferente e eventos desatualizados são recusados. Eventos concorrentes não sobrescrevem silenciosamente o histórico.
- Cancelamento seguido de vencimento persiste perda permanente; retorno, restauração de estado ou nova tentativa de matrícula não recuperam o benefício. Retomada antes do vencimento e renovação elegível preservam a modalidade e o preço original no simulador.
- Falha involuntária e migração ficam com reviewRequired, sem alterar modalidade ou inventar nova regra comercial.
- Clientes anônimos, o próprio usuário e outras contas não podem ler, criar, alterar ou excluir os registros e eventos pelas regras de cliente.
- Oito cenários adicionados à suíte do emulador: travas demo/local; persistência mensal/anual; perda após cancelamento/vencimento/retorno; continuidade; idempotência e eventos atrasados; concorrência; decisões pendentes; isolamento de cliente.

Limite: esses eventos são controlados pelo teste, não derivados de compras Google Play reais. Ainda falta integrar elegibilidade comercial ao Publisher/RTDN, definir corte e regras pendentes, versionar aceite e homologar preço legado com licença Play. Nenhum dado de produção, endpoint, cobrança, produto ou tela do aplicativo foi alterado nesta continuação.
