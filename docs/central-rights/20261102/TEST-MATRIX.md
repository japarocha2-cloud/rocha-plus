# Matriz de24 cenários — níveis de evidência

AUTO significa fixture/harness ou HTTPS local, nunca aprovação física. Clientes estão desativados e nenhum direito comercial foi aplicado.

| # | Cenário | Resultado automatizado | Limite real |
|---|---|---|---|
|1|Conta paga vigente|AUTO: resolveRights e cliente contrato|Sem conta real liberada|
|2|Trial vigente|AUTO: relógio original de7dias|Sem novo trial em banco real|
|3|Trial expirado|AUTO: nega sem reset|Vencimento real não executado|
|4|Pagamento aprovado sem direito|AUTO: fila/alerta de revisão|Pagamentos reais permanecem sem concessão|
|5|Pagamento duplicado|AUTO: ledger global único|Sem cobrança real|
|6|Webhook repetido|AUTO: idempotência|Entrega real não comprovada|
|7|Falha temporária no webhook|AUTO:503 e retry seguro|Operação real não ativada|
|8|Reprocessamento idempotente|AUTO: revisão pode ser resolvida sem estender ciclo|Nenhum reprocessamento comercial|
|9|Assinatura cancelada|PARCIAL: cancelamento de pagamento não concede; ciclo já pago preservado no contrato|Ciclo de assinatura recorrente real pendente|
|10|Pagamento reembolsado|AUTO: período removido e renovação da TV negada|Estorno real não executado|
|11|Direito revogado|AUTO: nega e interrompe renovação|Sem revogação de cliente real|
|12|Conta inexistente|AUTO: conta ausente/desabilitada rejeitada|Auth real positivo pendente|
|13|UID divergente|AUTO: servidor, Android e Roku rejeitam|Vetores comuns|
|14|Token expirado|AUTO: verifier rejeita|JWT Firebase real pendente|
|15|Falha de rede|AUTO: não renova autorização|Rede de aparelho não homologada|
|16|Troca de celular|AUTO: antigo celular rejeitado, TVs preservadas|Sem teste físico|
|17|Duas TVs vinculadas|AUTO: códigos e sessões por dispositivo|TV física pendente|
|18|Duas reproduções simultâneas|AUTO: slots transacionais de fixture|Não é reprodução de mídia|
|19|Terceira reprodução rejeitada|AUTO:409 sem slot|Sem decoder real|
|20|Expiração durante reprodução|AUTO: nega lease; cliente para preview em harness|Decoder e áudio físicos pendentes|
|21|Reconexão após falha|AUTO: nova consulta válida após503|Reconexão física pendente|
|22|Vinculação Roku|AUTO: serviço +35 verificações BrightScript|BRS0.6.7 e conta real bloqueados|
|23|Restauração Android|PARCIAL: código preparado com UID/endpoint e consulta da sessão|Persistência em aparelho não executada|
|24|Consistência entre três plataformas|AUTO:9 vetores iguais no servidor, Dart e BrightScript|Ponta a ponta real das três plataformas pendente|

## Estado por plataforma

| Plataforma | Login | Assinatura | Trial | Vinculação | Reprodução |
|---|---|---|---|---|---|
|Android celular|Token simulado aprovado; login real pendente|Contrato automático aprovado; real bloqueado|Cálculo aprovado; cronologia real pendente|Troca móvel automática; aparelho pendente|Wrapper preparado; mídia não executada|
|Android TV|Transporte simulado aprovado; login real pendente|Mesmo contrato; real bloqueado|Mesmo cálculo; aparelho pendente|Código e sessão simulados; TV real pendente|Regressões de superfície aprovadas com mocks; mídia não homologada|
|Roku TV|Sessão simulada; conta real bloqueada|Contrato BrightScript aprovado; real bloqueado|Contrato aprovado; real pendente|Código/lease simulados; real bloqueado|BRS0.6.6 bloqueado;0.6.7 não instalado; hardware não executado|

Backend:28 cenários integrados,8fronteiras HTTPS,6contratos de checkout,6ponta a ponta HTTPS e4fronteiras Firebase. Auditorias:6testes de segurança de conta e6de origem de checkout. Roku:35checks do engine (14 relacionados anteriores+21 novos). Android:34testes direcionados e análise sem problemas. Não somar essas contagens como homologações de clientes ou canais.

Testes antigos de catálogo, Cast e versão0.6.6 foram preservados. Só regressões relacionadas ao novo gate/cliente/player foram reexecutadas. Falhas intermediárias de certificado de teste e retorno Future estão registradas no histórico; os resultados finais substituem a rodada reprovada, sem apagá-la.
