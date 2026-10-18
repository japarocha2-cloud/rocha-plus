# Acesso administrativo Rocha+ (implementação inicial)

Branch: `feat/admin-login-firebase-20261014`. A referência `freeze/apk-538-20261014` permanece intacta.

## Comportamento
- Tela de login padrão continua oferecendo Google. Apple aparece desabilitado com o aviso vermelho "Em breve".
- Entrada discreta "Acesso administrativo" abre um formulário de e-mail e senha.
- O Firebase Authentication valida a senha. Somente o endereço `luquin.has.rocha2@gmail.com`, com e-mail **verificado** e custom claim `rochaAdmin: true`, recebe acesso ao painel ADM.
- Não existe senha armazenada no APK e não há bypass dos sete dias para usuários comuns.
- O painel ADM é intencionalmente informativo, sem permissões de escrita ou operações de pagamento.

## Provisionamento seguro necessário antes de usar
1. Confirmar no Firebase Authentication que a conta com esse e-mail tem o provedor **E-mail/senha** habilitado e que o e-mail está verificado. O endereço não deve ser autorizado somente pela aparência do texto.
2. Um operador autorizado, **em ambiente seguro, fora do APK e sem armazenar chaves no GitHub**, deve utilizar o Firebase Admin SDK com credenciais de serviço protegidas para conceder o custom claim `rochaAdmin: true` **ao UID confirmado da conta**.
3. Restringir quaisquer futuras operações de administração em um backend ou nas Security Rules validando `request.auth.token.rochaAdmin == true`. A verificação de claim no app é apenas controle de navegação, não um limite de segurança de dados.
4. Testar e-mail/senha válido, inválido, usuário sem claim, e-mail não verificado, reentrada e logout. Só então gerar um APK de teste da branch.

**Estado:** telas e autenticação implementadas no código. Claim não concedido, nenhuma alteração remota no Firebase realizada, APK não compilado nem testado fisicamente. Nunca conceder esse claim apenas porque um cliente ou app solicita.
