# Office: liberação por conta Google — experimental

O preço de R$49,90 é único para o pacote inteiro. Não há licença separada por módulo. O UID vem de uma sessão Firebase verificada pelo Admin SDK com `checkRevoked=true`, nunca de um e-mail ou UID enviado pelo comprador. A sessão pode ser Google direta (portal) ou uma sessão restrita da instalação, emitida após confirmação Google no navegador externo.

## Implementado

- Aprovação manual exige a claim administrativa específica `rochaOfficeAdmin=true`, valor 4990 centavos, BRL, produto `rocha-office-basic`, identificação do pagamento e referência da conferência. O servidor registra o administrador e a data. A referência é um registro da conferência humana; não comprova pagamento por si só.
- Transação idempotente impede repetir a mesma aprovação ou atribuir o pagamento Office a outra conta. Os registros e permissões do Office são separados dos da TV. A conferência humana deve confirmar que o pagamento é especificamente do Office, e não uma assinatura de TV.
- Até duas instalações simultâneas por conta, com registro transacional. A terceira recebe 409 inclusive sob concorrência. Reautorizar a mesma chave não consome outra vaga.
- A instalação comprova posse de chave privada P-256 por desafio aleatório assinado, válido por 60 segundos e de uso único. UID, produto, ação e instalação integram a mensagem assinada. Copiar apenas um identificador ou uma chave pública não basta.
- A biblioteca cliente gera chave privada não exportável e persiste em IndexedDB; não guarda um `paid=true`. Isso não equivale a uma chave de hardware inviolável: cópias privilegiadas de dados/ambiente precisam de mitigação nativa adicional.
- Sair de uma instalação permite liberar a vaga. Revogação administrativa bloqueia a chave inclusive para desafios já emitidos; estorno da última compra remove a licença e as instalações. Um novo pagamento não reaproveita a transação estornada.
- Downloads exigem conta aprovada e prova da instalação. O adaptador de produção não possui assinador de arquivos habilitado; retorna 503. Não existe URL pública de instalador comercial.
- Integração HTTP inclui limite de corpo, negação em erros, `no-store` e CORS por origens HTTPS exatas. Nenhuma origem é liberada por padrão.

## Executar e testar

Node 22: `npm ci --ignore-scripts` e `npm test`. Os testes usam chaves criptográficas reais, HTTP real local, cliente WebCrypto e armazenamento transacional em memória. Os dois testes negativos do Firebase usam o Admin SDK real, sem credenciais, para rejeitar tokens malformados ou de outro projeto. Não comprovam um login legítimo ou Firestore em nuvem.

## Preparação para implantação

`npm start` exige identidade de serviço ADC e `GOOGLE_CLOUD_PROJECT` experimental. `ROCHA_OFFICE_ORIGINS` recebe um array JSON de origens autorizadas. O servidor escuta apenas em `127.0.0.1:8081`, atrás de gateway HTTPS configurado separadamente. Recusa variáveis de emuladores. As regras Firestore do Office devem ser incorporadas sem substituir regras existentes; clientes não leem nem escrevem registros de licença. Configurar expiração TTL de `rochaOfficeChallenges.expiresAt` no projeto.

Somente um operador autorizado deve atribuir a claim `rochaOfficeAdmin`. Não atribuir a compradores nem reutilizar automaticamente a claim administrativa da TV.

## O que ainda impede ativação comercial

1. Acesso ao Firebase e identidade de serviço não estão disponíveis nesta sessão; não houve implantação, criação de claims nem teste Google real.
2. A tela comercial, o controlador de acesso, o pareamento no navegador e o painel administrativo estão conectados em código. O build padrão continua LAB e sem bloqueio; o modo comercial exige configuração HTTPS e Firebase explícita. Os instaladores LAB não devem ser distribuídos como produto pago protegido.
3. É necessário publicar o portal/painel com a configuração real, habilitar o serviço, autorizar o domínio Google e testar Android/Windows reais. Ao sair/trocar conta o frame do editor é descartado. Falha de verificação pausa o frame e conserva o trabalho não salvo; uma nova autorização da mesma conta pode retomá-lo. A verificação comercial preparada exige conexão ao servidor e é repetida a cada minuto, com timeout de 12 segundos.
4. Preparar arquivos comerciais assinados em armazenamento privado e habilitar o assinador somente para os dois destinos fixos. Uma URL temporária já emitida pode continuar válida até expirar (máximo 60 segundos neste contrato); não prometer revogação instantânea de cópias baixadas.
5. Testar edição, salvar/exportar e impressão nos dispositivos reais e o fluxo compra → conferência → conta correta → duas instalações → terceiro bloqueado → estorno.

Nenhum pagamento real foi aprovado, nenhuma licença de comprador foi criada e nenhuma cobrança foi ativada por estes testes.

## Entrada Google no Android e Windows

`ROCHA_OFFICE_PORTAL_URL` habilita os endpoints `/v1/office/pair/start`, `/approve` e `/finish`. Não habilitar antes de configurar HTTPS e limitação de requisições na entrada pública. O par expira em dois minutos; é necessário digitar no navegador o código exibido pelo programa. O navegador confirma uma sessão Google verificada e uma compra aprovada. Só a chave privada da instalação, junto do segredo de consulta, resgata a sessão uma vez. Segredos e tokens não entram em URLs.

O Firebase Admin emite um custom token contendo UID, instalação e horário da autenticação Google original. A sessão resultante só comprova essa instalação e não pode aprovar pagamentos. O verificador compara também o horário original com `tokensValidAfterTime`, evitando que uma troca tardia de custom token contorne uma revogação anterior. O serviço precisa da permissão IAM de assinatura necessária ao `createCustomToken` do Firebase Admin.

O portal e o painel usam Google pelo navegador normal. O Android abre o navegador via Capacitor Browser; o Electron usa uma ponte restrita ao URL de confirmação configurado. Não há Google OAuth dentro de um WebView embutido. O painel só aparece para `rochaOfficeAdmin=true`, mas a autorização efetiva é repetida pelo servidor para cada operação. Busca comprador Google por e-mail, confirma o pacote de R$49,90, registra estorno já realizado e revoga instalações. Nenhum desses botões movimenta dinheiro.

Para o Electron com arquivos locais, a origem `null` pode ser explicitamente incluída em `ROCHA_OFFICE_ORIGINS`; ela não é aceita nas rotas administrativas nem na aprovação Google do pareamento. As rotas de comprador continuam exigindo token e prova criptográfica. Adicionar a origem real do portal e a origem nativa Android configurada. Configurar TTL de `rochaOfficePairings.expiresAt`, além dos desafios de instalação.

## Verificação desta etapa

39 testes locais passaram: regras, HTTP, SDK Firebase negativo, pareamento criptográfico, controlador do editor, concorrência, conta divergente e configuração do build. O cliente e o servidor usam assinaturas reais nos testes; identidades Google válidas e banco são simulados. A compilação comercial com dados fictícios confirmou separação entre tela de acesso e editor e namespace de dados por conta, inclusive no financeiro incorporado. A prévia HTTP interna não oferece WebCrypto; ela mostrou o editor fechado nessa condição, sem comprovar login real.

Não houve implantação em nuvem, teste de conta Google legítima, assinatura comercial de arquivos, liberação de download pago ou ativação de cobrança.
