# Office: liberação por conta Google — experimental

O preço de R$49,90 é único para o pacote inteiro. Não há licença separada por módulo. O UID vem de um token Firebase Google verificado pelo Admin SDK com `checkRevoked=true`, nunca de um e-mail ou UID enviado pelo comprador.

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
2. O módulo cliente de prova está preparado, mas os instaladores LAB ainda não usam uma tela Google e um bloqueio comercial. Eles continuam experimentais e não devem ser distribuídos como produto pago protegido.
3. É necessário conectar portal, painel de aprovação e adaptadores de login Android/Windows, remover o editor da memória ao sair/revogar e validar com contas reais.
4. Preparar arquivos comerciais assinados em armazenamento privado e habilitar o assinador somente para os dois destinos fixos. Uma URL temporária já emitida pode continuar válida até expirar (máximo 60 segundos neste contrato); não prometer revogação instantânea de cópias baixadas.
5. Testar edição, salvar/exportar e impressão nos dispositivos reais e o fluxo compra → conferência → conta correta → duas instalações → terceiro bloqueado → estorno.

Nenhum pagamento real foi aprovado, nenhuma licença de comprador foi criada e nenhuma cobrança foi ativada por estes testes.
