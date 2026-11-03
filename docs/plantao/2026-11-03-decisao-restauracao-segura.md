# P0 — decisão de restauração segura
Data: 03/11/2026. Branch: incident/payment-recognition-20261103.
Decisão: **BLOQUEADO**. Não há autorização nem execução comercial nesta entrega.

## Avanço concreto desta etapa

A alegação de falta de credenciais deve ser delimitada: o executor privado Work/Codex não tem os bindings; a credencial já configurada no GitHub Actions EXISTE e FUNCIONA no próprio job.

Foi executada uma verificação nova e restrita de infraestrutura, sem consultar Auth de usuários, documentos de clientes ou Mercado Pago. [Execução 41700620811](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41700620811).

Resultado:
- Projeto da credencial corresponde ao projeto esperado.
- Metadados do banco: HTTP 200, edição STANDARD.
- testIamPermissions no projeto: HTTP 200; o teste limitado retornou get, create, update e delete de entidades.
- Release Firestore e leitura de seu fonte: HTTP 200.
- O fonte implantado não coincide byte a byte com o fonte Spark já revisado.
- customerQueries=0, documentQueries=0, paymentQueries=0.
- Nenhum valor de Secret, principal, fonte de regras, identificador de cliente ou estado financeiro foi publicado.

A presença de create/update/delete no teste limitado impede chamar a credencial de leitor com privilégio mínimo. O teste de IAM no projeto não é uma prova de autorização condicional em cada documento e NÃO executou uma escrita.

A diferença do fonte de regras não prova vulnerabilidade: pode incluir alterações legítimas ou comentários. Ela invalida apenas a aprovação automática por correspondência exata. O fonte completo precisa de revisão privada antes da aplicação.

## Uso seguro dos Secrets existentes

É possível usar um Secret no job nativo que o GitHub autoriza. Não é possível recuperar seu valor pela API para preencher a sessão privada do Work. Não imprimir, exportar, copiar para outro Secret, transferir por artifact/log ou enviar seu valor ao chat.

A execução nova comprovou o primeiro caminho: binding nativo, uso em memória e chamadas somente de leitura de infraestrutura. Seu resultado público contém exclusivamente códigos e indicadores de acesso; o diagnóstico completo da cliente não foi executado.

O diagnóstico privado existente mantém a recusa de execução em Actions. Esse bloqueio NÃO foi removido, e o script não foi chamado por outro executável.

### Executor proposto para o diagnóstico completo

Proposta a ser configurada/avaliada pelo proprietário, não infraestrutura criada nesta missão:
1. Executor privado efêmero sob controle do proprietário/Work, com custódia local do resultado e sem artifacts/logs financeiros públicos.
2. Execução manual, código/commit fixado e aprovado, revisão individual e escopo restrito ao repositório/branch. Não aceitar pull requests públicos, código arbitrário ou jobs concorrentes de outras origens nesse executor.
3. Se usar Secrets existentes, consumi-los apenas dentro do job nativo autorizado. Uma integração Work no mesmo host deve receber somente respostas de uma interface local de leitura, nunca os valores dos Secrets. A interface deve permitir exclusivamente a conta, os dois pagamentos e os documentos do manifesto aprovado.
4. A integração de execução privada precisa de implementação/revisão explícita. Não definir GITHUB_ACTIONS=false nem remover a guarda atual para fingir execução fora de Actions.
5. Para privilégio mínimo real, o administrador deve prover identidade de leitura restrita, preferencialmente federada/temporária quando houver suporte. A credencial existente demonstrou permissões de escrita; um programa que só faz GET não muda seu IAM. Configuração de IAM/OIDC/runner exige ação administrativa separada e não foi realizada.
6. Nenhuma permissão de cobrança, deploy, edição de regras ou escrita de direitos é necessária para o diagnóstico. O token de Mercado Pago deve ficar confinado ao processo autorizado de GET; não presumir que seu escopo seja de leitura sem comprovação.
7. Arquivos completos somente em diretório privado 0700 e arquivos 0600, fora do Git. Saída pública, quando necessária, limitada a códigos de bloqueio e indicadores sem dados pessoais/financeiros.

O conector GitHub disponível rejeita os endpoints administrativos de runners e environments como não suportados. Isso NÃO comprova que não existam runners privados ou ambientes protegidos. O proprietário precisa verificar/configurar essa parte em Settings; este executor não consegue fazê-lo pelos conectores disponíveis.

## Pendências, responsáveis e ações necessárias

| Pendência específica | Responsável | Ação necessária |
|---|---|---|
| Executor privado apto a usar credenciais sem exportá-las | Proprietário / administrador GitHub / Work | Identificar ou preparar o executor privado aprovado e o mecanismo de autenticação de leitura. Manter o diagnóstico atual bloqueado em Actions até a integração privada ser revisada. |
| Credencial não comprovada como privilégio mínimo | Administrador Firebase/GCP | Revisar o IAM do principal diagnosticado e disponibilizar contexto leitor adequado; não conceder permissões à assinante e não alterar IAM nesta missão sem autorização administrativa. |
| Regras implantadas diferentes do fonte revisado | Administrador Firebase / revisor de segurança | Revisar o fonte completo em ambiente privado, inclusive permissões sobrepostas, acesso Spark próprio e bloqueio cliente das novas coleções. A API de leitura de regras já funciona no job autorizado. |
| Pacote/build/projeto/backend e identidade da sessão instalada desconhecidos | Suporte / cliente | Coletar metadados do aplicativo atual e correlacionar a sessão autenticada, sem senha/token, novo login, desinstalação ou alteração de proteção. |
| Antes/depois atuais, existência da auditoria e baseline privado | Work no executor aprovado | Executar incident_session_readiness.mjs privadamente; guardar os arquivos de evidência e conferir as precondições dos cinco documentos. |
| Operador da eventual aplicação e manifesto final não selecionados | Proprietário / operador autorizado | Identificar operador autenticado, completar a proposta específica e vincular o digest ao manifesto integral, à sessão e ao baseline. Isso ainda não concede autorização de produção. |
| Sobreposição das duas recorrências | Proprietário / cliente | Esclarecer se manter ambos ou substituir o mensal pelo anual. Preservar ambos enquanto isso; não inferir cancelamento ou soma de períodos. |

Não pedir novamente credenciais ao proprietário para a verificação de infraestrutura que já foi concluída. O problema restante é a execução privada autorizada e a revisão das permissões/fontes, não inexistência global dos Secrets.

## Procedimento mínimo para o aplicativo

Obter apenas pacote, versionName, versionCode, origem informada da instalação, modelo/Android e horário da falha já observada. Manter a sessão e instalação atuais. Não solicitar pagamento, senha, token, logout ou novo login.

O coletor preparado tools/incident/device_metadata.py lê apenas metadados e, opcionalmente, hashes temporários dos APKs. Ele não habilita ADB, não instala nada, não lê preferências e não extrai credenciais. Usá-lo apenas em computador/aparelho já autorizados. Caso contrário, começar pelas informações do aplicativo nas configurações Android.

Associar o binário à evidência CI/distribuição e à configuração do backend. Package/versionCode/installer sozinhos não comprovam projeto Firebase ou identidade da sessão. Se o backend existente já registra a tentativa autenticada, revisar essa evidência privadamente; se não registra, o verificador preparado precisa de transporte aprovado. Não usar um login independente num navegador como substituto.

Spark usa Google subject como chave; os caminhos de Cloud Function, Node experimental e direitos centrais usam fontes diferentes. Sem identificar o aplicativo, não há prova de que gravar Spark desbloqueie a sessão real.

## Situação da prévia e período

A evidência financeira e a simulação anteriores permanecem válidas como evidência HISTÓRICA; não foram repetidas nesta etapa. A proposta anual continua limitada ao término informado no briefing, sem somar o mensal.

Os cinco documentos propostos continuam sendo dois registros únicos de recuperação, uma atualização restrita da conta Spark, uma projeção e uma auditoria. A implementação de captura integral e de imagens anteriores privadas já está preparada; a captura ATUAL não foi executada em ambiente privado.

Ainda faltam valores atuais/versões, existência da auditoria, fonte real do aplicativo, operador selecionado e revisão dos termos. Portanto:
- O antes/depois real e atual não está declarado completo.
- Operator/authorizationReference não foram fabricados.
- O digest financeiro histórico não é um digest final de autorização.
- finalAuthorizationBoundDigest continua pendente; não há manifesto final aplicável.

A autorização só deve ser solicitada depois da prévia final revisável. A falta de autorização concedida, sozinha, não impediria classificar uma proposta completa como PRONTO PARA AUTORIZAÇÃO; os impedimentos atuais são as evidências e definições técnicas/contratuais acima.

## Plano de restauração e rollback

Concluir as pendências; produzir o manifesto privado dos cinco documentos com baseline e precondições; revisar o prazo anual e a relação dos contratos; selecionar operador; apresentar autorização específica com digest final.

Somente após autorização comercial separada: revalidar provedor/identidade/versões, executar uma transação e confirmar o aplicativo real. Nenhuma etapa de aplicação foi autorizada aqui.

Rollback requer consentimento específico: conferir que os documentos ainda correspondem à aplicação, restaurar somente paidUntil/reconciledAt e sua presença anterior, preservar trial/favoritos, manter a auditoria original e registrar a reversão administrativa sem alterar recibos ou contratos no provedor. O roteiro completo está no [relatório anterior](2026-11-03-sessao-previa-restauracao.md).

## Arquivos, commits e testes novos

- f36167c6e94d7b90ea6a31ecbed8cc85079bdb85:
  - backend/entitlement/credential_policy_probe.mjs
  - backend/entitlement/credential_policy_probe.test.mjs
  - backend/entitlement/diagnostics/actions_infrastructure_readonly.mjs
- 14bdca395326c1805afa95f19bb2957dca8592a7:
  - .github/workflows/incident-infrastructure-policy.yml
- Três testes novos aprovados, localmente e no GitHub: restrição dos endpoints, ausência de dados privados no resultado e rejeição de projeto inesperado/erros privados.
- Os testes financeiros, o emulador e as investigações financeiras já aprovadas não foram repetidos.

Zero alterações de produção, direitos, pagamentos, recorrências ou regras. Nenhum deploy, merge, APK/ZIP, segredo copiado ou trabalho em Roku.
