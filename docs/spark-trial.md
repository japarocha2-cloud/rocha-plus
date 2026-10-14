# Rocha+ — teste real no Firebase Spark

O modo `ROCHA_SPARK_TRIAL=true` usa o Firestore do projeto confirmado `rocha-plus`, sem Cloud Functions, conta Cloud Billing ou serviços pagos novos. O login, canais, player, favoritos e Cast nativo permanecem no aplicativo completo. A imagem do alerta é o arquivo original aprovado, sem animações.

`rochaSparkAccounts/{googleSubject}` usa a identidade Google estável presente no token Firebase. O primeiro login cria `trialStartedAt` com horário do servidor, imutável. A validade é esse horário + 7 dias; o relógio do celular não participa do cálculo. A leitura usa `batchGet.readTime`, e o controlador limita a concessão em memória e renova o acesso pelo servidor. Reinstalação e recriação de UID com a mesma conta Google não criam outro teste.

O botão verde fecha o alerta imediatamente. A aceitação é registrada localmente, depois enviada como `welcomeAcceptedAt` com horário do servidor. Falhas de rede mantêm o registro local e a sincronização pendente. Outros aparelhos consultam o mesmo documento. Se o aparelho fechar antes de gravar o registro local ou a rede nunca permitir sincronização, a persistência entre aparelhos ainda depende dessa sincronização.

As regras mantêm integralmente o bloco existente de favoritos e acrescentam apenas acesso individual aos registros Spark. Elas impedem listar contas, ler outra identidade, apagar registro, alterar início do teste, limpar aceitação ou criar/alterar `paidUntil` pelo cliente.

## Limitações que precisam constar no teste

- O Spark não executa o servidor atual de confirmação automática Mercado Pago. Os links mensal e anual aprovados permanecem; abrir ou voltar do checkout nunca comprova pagamento.
- Depois de conferir um pagamento por um procedimento administrativo, o administrador pode registrar `paidUntil` como timestamp no documento da conta. Não se deve liberar acesso apenas com alegação ou captura do cliente.
- Pareamento Roku por custom token continua pendente; o Chromecast nativo Android não depende desse endpoint.
- Firestore tem cotas gratuitas. A frequência de atualização atual é uma leitura por minuto enquanto o controlador permanece ativo.
- Reprodução, login Google, Cast e expiração precisam de validação física com o APK entregue.

## Configuração

Publicar `billing/spark/firestore.rules` depois dos testes. O arquivo `firestore.before.rules` é a regra lida do projeto antes desta alteração e permite restaurar o estado anterior. Não substituir regras futuras sem uma nova comparação.

GitHub: variável `ROCHA_SPARK_TRIAL=true`. O workflow manual assinado conserva os Secrets Firebase/assinatura existentes, verifica se o projeto do arquivo Firebase assinado é `rocha-plus` e compila com o modo Spark explicitamente habilitado. O modo HTTP original conserva a exigência de URLs publicadas. `main`, Build 353 e Build 510 congeladas permanecem preservadas.
