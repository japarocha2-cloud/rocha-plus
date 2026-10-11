# Rocha+ — Política de Privacidade

**MINUTA V0.1 • NÃO PUBLICAR SEM DADOS REAIS E AUDITORIA DE IMPLEMENTAÇÃO**

Esta política explicará, em linguagem clara, como o Rocha+ trata dados pessoais. A versão final precisará corresponder ao código realmente publicado, aos provedores realmente usados e à declaração de segurança de dados na Google Play.

## 1. Controlador e canal de contato
Controlador: **[RAZÃO SOCIAL/NOME LEGAL A DEFINIR]**; inscrição **[CNPJ/CPF]**; contato LGPD: **[E-MAIL VÁLIDO]**; endereço profissional ou canal acessível: **[PREENCHER]**.

**Não publicar esta minuta com campos em aberto.** Identificação e informações sobre a organização devem corresponder às informações da loja.

## 2. Quais dados e de onde vêm (auditar antes de publicar)
Dados que **podem ser necessários**, conforme os recursos efetivamente ativados:
- Conta/autenticação: identificador de conta, e-mail, nome de exibição e dados disponibilizados por provedor de login escolhido.
- Assinatura: ID da conta, estado da assinatura, produto e periodicidade, datas de ativação/expiração e identificadores técnicos de compra tratados em ambiente protegido. O app não deve coletar diretamente dados completos do cartão processado pela Google Play.
- Uso e diagnóstico: informações técnicas essenciais à segurança, funcionamento do player e resolução de falhas, **somente se efetivamente coletadas**.
- Suporte: dados enviados voluntariamente ao solicitar assistência.

**Auditoria pendente:** confirmar se Firebase Authentication, Firestore, Google Play Billing, logs de servidor, crash reporting, analytics, favoritos ou recursos para crianças coletam dados, quem recebe cada categoria e a retenção aplicável. Não afirmar coleta ou não coleta sem verificação.

## 3. Para que os dados são usados e quais bases legais
As finalidades pretendidas são: criar e proteger a conta, autenticar o usuário, confirmar assinatura, prevenir fraude, prestar suporte e cumprir obrigações legais. Bases legais específicas conforme cada operação: **[MAPEAR SOB LGPD; NÃO TRATAR O ACEITE DOS TERMOS COMO CONSENTIMENTO GENÉRICO]**. Marketing e personalização opcionais, se implementados, exigirão transparência e controles apropriados.

## 4. Com quem dados são compartilhados
A versão final deverá identificar categorias reais de fornecedores e funções, possivelmente incluindo **Google Play** (compra), **Firebase/Google Cloud** (contas e infraestrutura), além de suporte e provedores de hospedagem apenas quando usados. Informar transferências internacionais aplicáveis, mecanismos e finalidades efetivas após auditoria.

## 5. Armazenamento, retenção e segurança
Dados devem ser conservados pelo tempo necessário a cada finalidade ou obrigação legal. **[DEFINIR PERÍODOS, EXCEÇÕES, LOGS, BACKUPS E POLÍTICA DE ELIMINAÇÃO].** O backend deve proteger identificadores de compra, controlar acessos e limitar dados ao estritamente necessário. Não prometer segurança absoluta.

## 6. Direitos do titular
Conforme LGPD e condições aplicáveis, o usuário pode solicitar informações, confirmação, acesso, correção, portabilidade quando cabível, informações sobre compartilhamentos, oposição/revisão quando aplicável, eliminação ou anonimização quando juridicamente possível e outros direitos previstos na lei. Canal previsto: **[SUPORTE LGPD]**. Alguns dados podem ser mantidos quando exigidos por obrigação legal ou defesa de direitos.

## 7. Exclusão de conta
Se o aplicativo permitir criação de conta, deve haver forma clara de solicitar exclusão **no app e por uma página/link acessível fora do app**, de acordo com a política da Google Play. Endereço externo destinado à exclusão: **[URL A CRIAR]**. Especificar quais dados são apagados e quais, por quanto tempo, precisam ser conservados por motivo legítimo. Cancelar assinatura e apagar conta são ações distintas; esclarecer o fluxo para evitar cobranças inesperadas.

## 8. Crianças e adolescentes
Avaliar público-alvo, classificação etária e funções reais antes da publicação. Implementar proteções adicionais se tratar dados de crianças/adolescentes, com melhor interesse e bases legais adequadas. Não presumir dispensa de exigências por haver uma seção "Infantil".

## 9. Cookies e tecnologia web
Se houver site público ou analytics, listar cookies, tecnologias de armazenamento e controle apenas após verificar a implementação. A prévia estática de assinaturas não persiste dados; a interface futura poderá ser diferente.

## 10. Atualizações
Informar data de publicação, versão e histórico material de alterações. Quando necessário, apresentar aviso destacando mudanças relevantes.

## Checklist antes da publicação
- [ ] Identificação do controlador e contato LGPD.
- [ ] Auditoria do código, serviços e declarações da Play.
- [ ] Categorias/terceiros/bases legais e retenções por finalidade.
- [ ] Exclusão de conta funcionando no app E por link externo.
- [ ] Política publicamente acessível, mesmo sem login, e link no app e Play Console.
- [ ] Procedimento de atendimento de direitos LGPD.
- [ ] Revisão jurídica e consistência com Data Safety.

Referências oficiais:
- Google Play User Data: https://support.google.com/googleplay/android-developer/answer/10144311
- ANPD direitos: https://www.gov.br/anpd/pt-br/assuntos/titular-de-dados/direito-dos-titulares
