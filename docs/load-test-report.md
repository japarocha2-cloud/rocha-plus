# Teste de carga Rocha+
Executado em 11/10/2026 UTC na branch dev/founder-annual-app-integration, a partir de 700826f6f153cdbfdb73dc179cda4835d4dda1f2.

## Escopo e método
Código real de backend/service.js e policy.js, executado localmente. Todas as tarefas de cada cenário foram iniciadas juntas com Promise.all. Cada usuário faz account e entitlement sequencialmente: 20.000 chamadas de serviço para 10.000 usuários. Identidade, armazenamento e Google Play são simulados; a resposta do Play recebe atraso artificial de 80 ms. Não é teste HTTP, de celulares, Firebase real, emulador Firestore ou infraestrutura hospedada. A concorrência medida corresponde às tarefas virtuais locais, não a conexões de rede.
Nenhuma cobrança, confirmação de compra, alteração de produção, publicação ou acesso aos streams/listas de terceiros. Nenhuma cor ou tela modificada.

## Medições locais
| Usuários simultâneos | Sucessos | Erros | Tempo p95 por abertura | Duração do cenário |
|---|---:|---:|---:|---:|
| 1.000 | 1.000 | 0 | 183,91 ms | 198 ms |
| 5.000 | 5.000 | 0 | 443,27 ms | 480 ms |
| 10.000 | 10.000 | 0 | 696,29 ms | 772 ms |

Zero resultados incorretos nas verificações realizadas: identificador de conta e assinatura anual ativa. Isso não substitui a suíte funcional de segurança já existente. Latências dependem da máquina local e dos mocks; não estimam tempos reais do aplicativo.

## Gargalo encontrado
No cenário artificial de 10.000 usuários com orçamento de 3.000 consultas ao Play, 3.000 passaram e 7.000 receberam HTTP lógico 403 (verification-unavailable). Não houve concessão indevida de acesso. Este cenário aplica um orçamento fixo ao burst; não implementa uma janela móvel ou reproduz as respostas HTTP reais do Google.
A documentação oficial informa padrão de 3.000 consultas/minuto por bucket, incluindo SubscriptionPurchasesV2 no bucket de assinaturas: https://developers.google.com/android-publisher/quotas .
A cota efetiva deste projeto NÃO foi consultada; pode ser diferente.

O cliente comercial consulta entitlement a cada 30 segundos. Com um token por pessoa, 5.000 pessoas mantidas online podem produzir aproximadamente 10.000 consultas/minuto ao Publisher; 10.000 produzem 20.000. Esse cálculo não inclui restauração, abertura e retomada. No beta, o billing é desabilitado e essa rotina não se aplica.
Com 1.000 pessoas e 20 tokens históricos por conta, o teste realizou 20.000 consultas simuladas ao Play. O código permite até 20 tokens e revalida todos. Cada consulta entitlement também lê o documento de usuário e os donos de seus tokens no Firestore.
O endpoint declara maxInstances:5; capacidade efetiva, filas, inicialização e configuração real de concorrência não foram medidas.

## Antes de liberar milhares de acessos
1. Reduzir consultas repetidas de assinatura com cache no servidor, validade limitada, atualização por notificações e invalidação de cancelamentos/revogações; validar segurança e expiração antes de implementar.
2. Rever consulta periódica do cliente, uso de tokens históricos e tratamento de indisponibilidade temporária, preservando a regra de nunca conceder acesso sem validação.
3. Medir cota e custos do projeto; configurar ambiente isolado e instrumentar erros, latência, filas, leituras e concorrência.
4. Executar teste HTTP gradual de 1.000/5.000/10.000 sessões no ambiente isolado com Firebase/Firestore de teste e dependência Play simulada, depois homologar integração com usuários de licença.
5. Testar favoritos/listeners, autenticação, listas, reprodução, fullscreen e espelhamento em aparelhos. A capacidade dos servidores externos dos canais precisa de avaliação própria e autorização dos responsáveis; o vídeo não passa pelo backend de assinaturas.

Conclusão: o núcleo local concluiu 10.000 tarefas simultâneas com mocks, mas o aplicativo completo ainda não está homologado para 10.000 pessoas reais.

## Reprodução
Node 22, sem instalar dependências: executar node backend/run-load-test.js a partir da raiz. Salvar a saída JSON para comparar execuções. O teste importa apenas o serviço e a política, sem inicializar Firebase ou GoogleAuth. Resultados desta execução estão em load-test-results.json.
