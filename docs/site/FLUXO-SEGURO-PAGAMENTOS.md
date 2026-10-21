# Rocha+ | Fluxo seguro de pagamentos e acesso (prévia)

Documento técnico. Não está implantado em produção.

## Regras obrigatórias
1. Usuário faz login Google no site; backend verifica o Firebase ID token e recupera UID com SDK Admin.
2. Backend cria uma tentativa de compra contendo UID, produto (tv_mensal, tv_anual, office_unico), preço esperado em centavos, status `pending`, identificador aleatório e horário.
3. Para **vinculação automática**, checkout deve carregar referência única criada pelo backend e efetivamente retornada pelo provedor. Links de pagamento estáticos, usados na prévia, não comprovam correspondência entre pagante e conta. Sem referência verificada, manter **conciliação manual**.
4. Provedor notifica endpoint HTTPS. Endpoint valida origem conforme documentação do provedor, não confia no corpo da notificação e consulta o pagamento pelo servidor com credenciais secretas; verifica status `approved`, valor, moeda, conta recebedora, produto e referência. Armazena ID de pagamento de forma única e processa repetição idempotentemente.
5. Só então atualizar autorização do UID em transação, emitindo período TV ou licença Office correspondente. Nenhuma senha, token secreto ou API privada pode ir para HTML/browser.
6. O aplicativo consulta backend autenticado. Expiração, estorno, chargeback e cancelamento impedem renovação indevida e preservam o acesso já pago quando legalmente aplicável.
7. Office: limite de dois dispositivos controlado no servidor, com política de desativação e troca, nunca somente por armazenamento no aparelho.
8. Auditar concessões, revogações, políticas de privacidade e eventos para atendimento.

## Nunca conceder acesso com
- Clique em "pagar", redirecionamento de sucesso, print/comprovante do usuário sem conferência oficial;
- parâmetros `status=approved`, `payment_id` ou `uid` fornecidos pelo navegador;
- notificação não autenticada ou pagamento com valor/conta diferentes;
- login Google isolado, sem comprovação de pagamento.

## Testes de aceite
- Aprovação real controlada, pendente, recusada, reembolso, notificação duplicada e fora de ordem;
- URLs e UID manipulados; duas contas Google; pagamento errado; tentativa sem sessão;
- Assinatura mensal/anual e licença Office, expiração, renovação, logout e troca de dispositivo.

**Status:** somente especificação. Não criar botão de "liberar" antes de backend e ensaio ponta a ponta.
