# Rocha+ site existente: mapa de integração de assinaturas (26/10/2026)

**Somente documentação de homologação. Sem alteração do site existente, sem deploy e sem escrita no Firebase oficial.**

## Localização confirmada
- O site de PR #35 está na branch `feat/site-office-estudando-empresas-20261020` (não na branch experimental Android).
- Páginas: `web/index.html`, `web/assinaturas/index.html`, `web/assinaturas/documentos.html`, `web/assinaturas/ajuda.html`, `web/estudando-empresas/index.html`.
- `web/assinaturas/index.html` contém opções mensal R$4,50 e anual R$49,50, com links externos Mercado Pago. Os links **não** comprovam a identidade Firebase de quem pagou e podem iniciar cobranças reais; NÃO acionar em testes.
- O módulo `web/assets/firebase-config.js` da PR #35 está associado ao projeto oficial `rocha-plus`, e **não** ao `rocha-plus-homologacao`. Não copiar nem usar essa configuração na homologação.
- A PR descreve login Google e documentação, mas a presença dos arquivos não comprova deploy, autenticação real ou funcionamento do site hospedado.

## Integração pretendida, somente em ambiente experimental
1. Preservar site publicado e branch de PR #35. Trabalhar apenas nesta branch Android autorizada até nova autorização específica para alterar o site.
2. Criar/configurar um Firebase Web **separado** no projeto `rocha-plus-homologacao`; validar domínio de origem permitido e mesmo UID entre Web e Android LAB com identidades de teste.
3. Utilizar um endpoint HTTPS de homologação que verifica ID token via Firebase Admin e deriva UID do token. Nunca confiar em UID enviado pelo navegador.
4. Para novos pagamentos, substituir links estáticos apenas após existir backend que cria referência única por UID + plano, valida pagamento no provedor servidor-servidor e registra ledger idempotente com auditoria. Não cobrar durante validação.
5. Para pagamentos históricos já confirmados: reconciliar por IDs de transação em rotina administrativa somente leitura; conferir recebedor, comprador, status atual, histórico completo, vinculação UID e política de duração antes de qualquer importação. Nunca usar o e-mail isolado como prova da identidade Firebase.
6. Escrituras de concessão, inclusive em homologação, exigem configuração de isolamento e testes atômicos. **Sem gravação no projeto oficial `rocha-plus`**.
7. Testar login/logout, conta trocada, tentativa de duplicação, vencimento dos sete dias, retorno do site, reembolso, indisponibilidade do backend e Cast no APK LAB.
8. Revisar autorizações dos canais e documentos comerciais antes de lançamento.

## Bloqueios atuais
- Hospedagem efetiva do endereço `rocha-mais-download.sappyrose17.chatgpt.site` não confirmada por consulta pública.
- PR #35 está aberta e não deve ser mesclada automaticamente.
- Nenhum backend experimental HTTPS implantado/verificado nesta fiscalização.
- Nenhum pagamento real aplicado, nenhum `paidUntil` oficial modificado.
