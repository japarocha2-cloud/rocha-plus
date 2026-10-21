# Login Google no Rocha+ (prévia, não publicado)

O código da página TV e da página Estudando / Empresas compartilha o mesmo aplicativo Firebase Web e, portanto, a mesma identidade Firebase (UID). O login apenas identifica a pessoa; não concede assinatura, download, licença ou prazo de teste gratuito.

## Ativação

1. Abra o projeto Firebase já usado pelo Rocha+. **Não crie outro projeto por engano.**
2. No Firebase Console, em **Authentication > Sign-in method**, habilite **Google** e configure o e-mail de suporte solicitado.
3. Em **Authentication > Settings > Authorized domains**, inclua o **domínio real do site Rocha+** e os domínios de prévia que serão usados nos testes. Não adicione domínios desconhecidos.
4. Em **Configurações do projeto > Seus aplicativos**, use/cadastre um aplicativo Web, copie os parâmetros de configuração e crie `web/assets/firebase-config.js` baseado em `firebase-config.example.js`. Não coloque nesse arquivo credenciais de servidor, chave privada de conta de serviço, tokens Mercado Pago, client secret OAuth ou senhas.
5. Publique somente no ambiente de teste, abra as duas páginas e confirme que o mesmo Gmail mostra o mesmo UID. Teste entrar, atualizar a página e sair; em celular, confira abertura do login.
6. Depois, implemente no backend verificação do **Firebase ID token** e dos **webhooks Mercado Pago** com validação no servidor. O sistema deve conferir **status approved, valor, produto, identificador de transação e vínculo prévio com UID**, proteger contra notificações duplicadas e registrar expiração/estorno/cancelamento. Links externos de pagamento não associam automaticamente um pagamento ao UID.
7. Não habilite downloads do Office ou canais pagos com base apenas no login, retorno do navegador, e-mail digitado pelo visitante ou comprovante enviado.

## Estado

A configuração real do Firebase, o servidor de verificação e a hospedagem do site original ainda não foram identificados/ativados nesta branch. A interface mostra login indisponível enquanto faltar configuração. O site roxo original não foi modificado.
