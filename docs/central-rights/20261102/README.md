# Missão de pagamentos e direitos — plantão de 02/11/2026

## Estado comprovado

[A auditoria autenticada](authenticated-audit.json) foi concluída em 02/11/2026 às 21:17 Brasília (03/11 00:17 UTC), no [CI 41551744667](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41551744667), commit c94c29ed49e9f1a5251e425b6818573e8ece67b4. Apenas leituras, zero concessões.

Os dois pagamentos continuam approved/regular_payment, em modo real, pagador e recebedor correspondentes, sem reembolso ou estado de disputa indicado nos GETs. Não trazem external_reference, notification_url de pagamento, plano ou período explícito nos metadados verificados. Não se infere prazo pelo título/valor. Spark existe sem paidUntil; rochaBillingUsers, rochaEntitlements, entitlements e projeção consultados não existem para a conta. Nenhum registro correspondente nos três ledgers de pagamentos inspecionados.

## Causa e lacunas

O caminho faltante é demonstrável no código: Spark Android abre links estáticos e só consulta seu documento; webhook recorrente depende de fatura/vínculo de assinatura e ignora recursos sem dono. Não há ponte comprovada entre esses pagamentos avulsos e o documento pago usado pelo app. UID Firebase e subject Google não são a mesma chave.

As URIs comerciais derivadas de nome/região/projeto para mercadoBilling e mercadoWebhook retornaram GET 404 ([sondagens](endpoint-probes.json)). Isso não prova ausência de endpoints com outros nomes/regiões. Inventário Cloud Functions e leitura de logs receberam 403: faltam cloudfunctions.functions.list e logging.logEntries.list à identidade do runner. Não é possível afirmar se o painel do provedor tinha webhook configurado, se entregou ou qual erro recebeu. Ausência de notification_url no pagamento não exclui configuração do aplicativo.

A edição Firestore comercial foi confirmada STANDARD/FIRESTORE_NATIVE. PR #42 continua draft, sem mudança, head61780147654b42709070702a677eec24b33a2ac5. Ela documenta projeto rocha-plus-homologacao separado do comercial e políticas temporais conflitantes: dias desde confirmação, acumulação de meses e períodos independentes. Não adotar uma para a conta real sem decisão explícita.

## Preparação experimental

[Código central](../../../experiments/central-rights/README.md): um contrato, períodos explícitos, leitura sem novo trial, conciliação idempotente, revisão de pagamentos sem vínculo, dispositivos/streams transacionais e runtime HTTPS isolado com página de aprovação Firebase. Nenhum entrypoint oficial modificado. Adapters de escrita recusam o projeto comercial e Candidata.

[26 cenários integrados](integration-tests.json) e [8 testes HTTPS](https-tests.json) aprovados localmente, com fixtures. TLS não foi desativado; certificado/chave efêmeros somente em memória e cliente de teste. Não é login Firebase real, Firestore real ou reprodução. A CI de código novo será conferida antes da entrega.

Integração preparada em branch Android própria [lab/central-rights-android-20261102](https://github.com/japarocha2-cloud/rocha-plus/tree/0735da35ebbad7a26edd82494bd1440c8dd81910), sem tocar PR #42. Cliente compartilhado, renovação/parada e vinculação TV opt-in, padrão desativado. CI41553166585 em andamento neste checkpoint.

Cliente Roku central preparado e configuração desativada:26 verificações relacionadas aprovadas (14 regressões anteriores +12 novas). Correção demonstrada de saída: o cliente solicita logout ao servidor antes de apagar a sessão local, evitando perder a possibilidade de liberar vínculo/slot. ZIP0.6.7 preparado, [integridade e preservação](roku-067-package.json); não instalado no BRS, que continua0.6.6.

CI41552648744 aprovou os26 cenários de integração, mas reprovou a fixture HTTPS por serial ASN.1 aleatório com padding redundante. Gerador corrigido; cinco certificados novos aceitos pelo OpenSSL local. Nova execução CI pendente; não ocultar essa falha histórica. O BRS permanece na 0.6.6 bloqueada; não atribuir a esta etapa nova execução de reprodução. Os testes verdes anteriores permanecem históricos e não foram repetidos.

## Bloqueios para aplicação real

1. Determinar e aprovar o plano/duração/relação entre os dois pagamentos com evidência de contrato. Não somar períodos automaticamente.
2. Conferir configuração e entregas de webhook com as permissões de leitura faltantes; só depois propor configuração concreta.
3. Preparar no host isolado credenciais próprias de mínimo privilégio: verificação Auth/leitura Spark comercial e sessões/dados LAB em banco distinto. Não exportar segredo do CI.
4. Aprovação expressa do proprietário antes de qualquer concessão ou conciliação comercial, deploy ou serviço público. Não houve pedido de nova cobrança.
5. Executar login positivo, dispositivos/renovação e playback em cada plataforma, depois hardware e Cast.

Nenhum dado pessoal, ID financeiro, comprovante, token ou chave privada foi copiado para este relatório.

## Atualização do cliente e pacote preparados

Os vetores comuns de contrato revelaram rejeição de números primitivos vindos de ParseJson no Roku; labNumber agora aceita os tipos numéricos boxed e primitivos, preservando rejeição de strings. 35 verificações Roku relacionadas aprovadas (14 anteriores +21 novas, incluindo9 vetores compartilhados). Backend atualizado:27 cenários; HTTPS:8.

ZIP0.6.7 regenerado após a correção:4.538.188bytes/574arquivos, SHA2566ff88bbf99786163a6de80eeb18c985557ea2a68441c102d114e26ab34f3cd07. Capas, catálogo, artes e configurações comerciais/LAB anteriores conferidos byte a byte. Continua desativado.0.6.7 não foi instalado; a última execução nativa permanece0.6.6 documentada no commit89c71a8. A consulta ECP nesta etapa final falhou (fetch failed); não se afirma que esteja ativo agora.

Android: testes iniciais passaram; análise apontou retorno Future sem await dentro de try, corrigido para que erros assíncronos sejam capturados. Vetores compartilhados adicionados em nova revisão. PR42 permanece intacta. Resultados finais de CI serão anexados após confirmação.

[Auditoria histórica ampliada da oferta](historical-offer-audit.md): encontrados os links corretos do site e modalidade mensal/anual12meses. Não encontrada regra final de troca/acumulação aplicável aos dois pagamentos. Leitura de origem no provedor preparada, sem submeter checkout ou cobrar. Nova instrução do proprietário preservada: continuar pesquisa, não escolher regra comercial por pergunta ou suposição.

Hardening adicional: código de vinculação deve ter formato de8caracteres e não pode acessar chaves de protótipo; índices de conta usam hash; reserva abandonada expira sem prender permanentemente vaga de TV.28 cenários integrados atualizados,8HTTPS e6 contratos de checkout preparados aprovados localmente. Intenção de checkout não cria cobrança; política não aprovada é recusada.
