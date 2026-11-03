# Aprovação móvel e HTTPS — auditoria 03/11/2026

Nenhum serviço ativado, configuração Firebase alterada, credencial solicitada/exportada ou direito concedido. Classificação distingue código preparado de infraestrutura comprovada. Estado desta etapa não depende de cobrar ou conciliar pagamentos.

| Item | Classificação | Evidência / falta concreta |
|---|---|---|
| Host isolado operacional | Não comprovado | Nenhum host em runtime.example.json; origin vazio. BRS local não é host de autenticação. Nenhum provedor/VM confirmado por evidência de implantação nesta etapa. |
| Runtime HTTPS em código | Disponível, mas não configurado | createHttpsRuntime e listenLoopback, injeção de handler/key/cert; sem processo operacional preparado com credenciais reais. |
| HTTPS confiável por celular/Roku | Dependência externa pendente | FQDN/origem alcançável e cadeia válida confiável em ambos. Loopback localhost no celular refere-se ao celular; certificado efêmero de fixture não atende. Sem CA global/TLS desabilitado. |
| Compatibilidade do certificado | Não comprovado | Não existe certificado operacional selecionado para inspecionar SAN, cadeia, validade ou testar TLS1.2 no Roku. Mínimo TLS1.2 no servidor não prova compatibilidade do aparelho. |
| Projeto Firebase LAB apropriado | Não comprovado | Histórico aponta rocha-plus-homologacao; existência histórica não comprova acesso atual ou banco autorizado para esta finalidade. labProjectId vazio. Não escolher automaticamente rocha-plus ou candidato. |
| Permissões e credenciais do host | Dependência externa pendente | Não provisionadas/comprovadas no host. Identidade comercial somente consulta; LAB transacional separado. Nunca reutilizar/exportar segredo CI. |
| Domínio Auth/OAuth compatível | Não comprovado | Origem operacional e lista atual authorizedDomains não consultadas nesta etapa; não assumir que um domínio novo é aceito. Login Google real não executado. |
| Login Google preparado | Disponível, mas não configurado | /approve importa SDK, signInWithPopup e token em memória; depende de config pública correspondente ao Auth rocha-plus e domínio já autorizado. Alteração de configuração Auth comercial continua fora do escopo. |
| Separação de bancos em código | Disponível e comprovado | Runtime exige Auth/commercialReadDb rocha-plus; adaptador de escrita recusa rocha-plus/candidate e exige labProjectId explícito. Fixture CI valida fronteiras. IAM real ainda não comprovado. |
| Autorização temporária exata ativa | Bloqueado por autorização | Proposta privada existe com enabled:false; janela original termina 03/11/2026 11:39:52.101 BRT, não rearmada. Mesmo dentro da janela não está ativa nem autorizada para ativação nesta ordem. Nenhum identificador privado copiado. |

## Permissões mínimas a preparar, sem conceder nesta etapa

Identidade: verificar ID token e revogação/estado com Firebase Admin; consultar somente a conta necessária (firebaseauth.users.get; dependências de inicialização/configuração devem ser verificadas no preflight, sem conceder papel Admin amplo). Google SDK verifica certificado público do emissor; não expor chave Admin ao app.

Comercial Firestore: somente leitura dos documentos Spark necessários ao UID/provedor e sem create/update/delete. LAB separado: leitura e transações do estado rochaCentralLabRuntime/devices e leitura canônica rochaCentralLabAccounts. Permissões esperadas incluem datastore.entities.get/create/update e capacidades de transação efetivamente exigidas pelo SDK; configuração IAM deve ser verificada contra chamadas reais. O SDK Admin usa IAM, não regras cliente; prefixo de coleção não substitui isolamento de projeto/IAM. Não conceder escrita comercial.

As permissões cloudfunctions.functions.list e logging.logEntries.list anteriormente recusadas dizem respeito à auditoria de webhook comercial; não são pré-requisitos para executar estas fixtures nem justificam conceder direitos. Não houve nova tentativa idêntica.

## Bloqueio e preservação

central-access.json e lab-access.json continuam enabled:false, endpoints vazios, approvalUrl central vazio. physical-lab-access mantém account_homologation. Configurações e manifest0.6.7 comparados por bytes ao commit84ecf7a. Account chama central, LAB e físico nessa ordem; LAB retorna true antes do físico. Não há fallback alcançável que abra acesso nessa configuração. Aviso LAB não consulta assinatura. Não houve nova instalação ou interação ECP; nenhum dado/registro/favorito/temporizador alterado por esta etapa.

## Próxima sequência

1. Revisar correção/CI, confirmar host e projeto LAB, credenciais próprias mínimas e domínio já autorizado, além de certificado/rede nos aparelhos.
2. Preparar configuração privada de conta exata, prazo absoluto e scope homologation para aprovação específica do proprietário; a ordem atual não autoriza ativação ou concessão.
3. Após autorização futura, compor runtime isolado sem paymentWebhook; testar recusas de TLS/origin/identidade e limites. Não ativar serviço público nesta etapa.
4. Só depois habilitar clientes experimentais em etapa própria. ZIP0.6.7 permanece desativado; correção no backend não remove seu bloqueio.
5. Usuário faz Google login e confirmação manual do código8caracteres/10min; autenticação móvel recente até5min. Validar uma conta/um celular, duasTVs, doisstreams, rejeição terceiro, expiração e revogação. QR ainda não demonstrado.
6. Executar navegação e mídia antes bloqueadas sem apagar dados; testes físicos de áudio, rede, controles, FPS/RAM continuam pendentes.
