# Regressões executadas nesta etapa

Código bfedc1540c79d09ab812432163c7793679ad08f4. Fixtures isoladas; sem Firebase/pagamentos reais.

| Caso novo | Resultado backend local/CI |
|---|---|
| Duas reproduções; reiniciar a mesma não ocupa segunda vaga | Aprovado |
| Terceira recebe409 | Aprovado |
| entitlement do celular preserva reservas e409 | Aprovado |
| status neutro AndroidTV preserva reservas e409 | Aprovado |
| Status repetido não libera nem prolonga lease | Aprovado |
| StopTV libera somente sua reserva | Aprovado |
| Logout remove sua sessão/vínculo/stream, preserva celular/outraTV | Aprovado |
| Revogação impede renovação celular/TV | Aprovado |
| Antes do deadline59999ms409; no deadline60000ms vaga liberada | Aprovado |
| Falha de rede retorna503 sem antecipar liberação | Aprovado |
| Concorrentes pela última vaga:200/409, total2 | Aprovado |
| Stopmobile e nova tentativa legítima usando a vaga | Aprovado |

Backend CI:28integração +12reservas +8HTTPS +6contratos +6end-to-endHTTPS +4fronteirasFirebase =64aprovados. Sem falhas finais. Transação concorrente testada com memoryStore serializado; adaptador real usa Firestore runTransaction, cuja concorrência em nuvem não foi executada. Não afirmar validação IAM/Firebase real ou mídia.

Antes/depois em http-before-after.json: são códigos de resposta do handler utilizado no servidor HTTP, invocado diretamente em fixture; não chamadas a um serviço público. Novo teste HTTPS end-to-end relacionado também passou no CI. Baseline anterior falha na preservação da reserva; detalhes em reservation-regressions.json. Falha inicial de comparação do harness entre contextos NodeREPL foi corrigida usando serialização de valores simples, sem alterar lógica de aplicação.

Android: dois novos testes verificam corpos enviados por HTTP MockClient. Validam status neutro sem playback_active, start com true, stop com false, logout sem flag e distinção entitlement/mobile_playback/mobile_stop. CI concluído:36testes totais aprovados e análise sem problemas; resultados em ci-results.json. Não há Android real/TV/Cast/Google login positivo nesta etapa.

Reprodução backend: node --input-type=module -e "import {runReservationTests} from './experiments/central-rights/reservations.test.mjs'; console.log(await runReservationTests())". Para integração relacionada, usar runIntegrationTests de integration.test.mjs. CI contém comandos HTTPS e Flutter na ordem aplicada; overlay Android aplicado ao commit fixo d3c56ab, nunca à versão oficial.
