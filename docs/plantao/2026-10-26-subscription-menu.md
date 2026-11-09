# Assinatura no menu experimental

O usuário constatou no APK de homologação que o menu não continha Assinatura.
A assinatura digital do APK havia sido verificada; isso não valida uma
assinatura comercial. O menu agora abre uma tela própria em celular e TV.

A tela apresenta mensal R$ 4,50 e anual R$ 49,50 para conferência, sem checkout
ou criação de cobranças. Explica que um pagamento existente precisa ser
validado e vinculado à conta, e orienta a não pagar novamente para liberar acesso.
Não exibe plano ativo ou prazo inventado. O teste de sete dias é descrito como
previsto, com validação do prazo/bloqueio ainda em homologação.

Com entitlement_url vazio, não realiza consulta nem altera Firebase. Com URL
HTTPS e conta, permite somente verificar acesso usando o verificador existente,
que exige token Firebase e UID correspondente na resposta. Acesso permitido
não é apresentado como pagamento aprovado (pode ser trial). Falha de consulta
não é apresentada como prova de inadimplência.

Mantidos subscription_lab=false, endpoint vazio, projeto experimental e versão
oficial congelada. A integração do backend, reconciliação dos pagamentos e
bloqueio real continuam pendentes. Esta alteração não os conclui.

Testes de widget cobrem navegação pelo menu de celular/TV, retorno, ausência de
confirmação indevida e apresentação de planos sem ações de cobrança.
