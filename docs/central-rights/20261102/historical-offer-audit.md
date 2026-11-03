# Auditoria histórica da oferta e dos checkouts

## Fontes encontradas após investigação ampliada

| Fonte imutável | Evidência | Limite |
|---|---|---|
|[Site — snapshot a7a77c5](https://github.com/japarocha2-cloud/rocha-plus/blob/a7a77c5a5fdd78fe7c1d20550aae51ae9af02a34/web/assinaturas/index.html)|Mensal R$4,50 por mês, link32m6qxz; anual R$49,50 por12meses, link1CKFRB2|Presença no Git não prova página hospedada/termos aceitos na compra|
|[Alteração mensal f60949e](https://github.com/japarocha2-cloud/rocha-plus/commit/f60949efdc23017f4eaf9b50fb3bd6b09736c7ce)|Atualização de oferta/link mensal em20/10/2026|Não associa por si só uma transação ao link|
|[Alteração anual04e335a](https://github.com/japarocha2-cloud/rocha-plus/commit/04e335ad4fff33d3e2db8bac9ce2f928d1cade13)|Atualização de oferta/link anual em21/10/2026|Não informa regra de troca/acumulação|
|[FAQ em rascunho](https://github.com/japarocha2-cloud/rocha-plus/blob/471fe5d55c3bb0f1786d845f26bc47e77981c250/docs/FAQ-ASSINATURAS-RASCUNHO.md)|Pergunta8: troca mensal para anual ainda não decidida|Documento de proposta/Google Play, não contrato Mercado Pago concluído|
|[Termos em rascunho](https://github.com/japarocha2-cloud/rocha-plus/blob/471fe5d55c3bb0f1786d845f26bc47e77981c250/docs/TERMOS-DE-USO-E-ASSINATURA-RASCUNHO.md)|Anual definido como12meses; migrações ainda a detalhar|Minuta sem vigência; preços/provedor diferem do site posterior|
|[Fluxo seguro do site](https://github.com/japarocha2-cloud/rocha-plus/blob/a7a77c5a5fdd78fe7c1d20550aae51ae9af02a34/docs/site/FLUXO-SEGURO-PAGAMENTOS.md)|Link estático não comprova UID; sem referência mantém conciliação manual|Preparação não implantada|
|[Consolidação de pagamentos recorrentes](https://github.com/japarocha2-cloud/rocha-plus/blob/89c71a8679cb5fad5f24d8b3d33651f5b31ae5c8/docs/payments-and-platforms.md)|Fatura mensal1mês/anual12; ciclo duplicado não acumula; cancelamento conserva já pago|Outros links/recebedor e modalidade recorrente, não prova de período dos avulsos|
|[Política experimental Android](https://github.com/japarocha2-cloud/rocha-plus/blob/61780147654b42709070702a677eec24b33a2ac5/functions/entitlement_periods.js)|Maior fim independente desde aprovação, sem somar mensal+anual|Código experimental não é autorização comercial nem termos aceitos|

## Conclusão limitada às evidências

As modalidades documentadas são mensal e anual de12meses. Não foi encontrada regra expressa aplicável a esses dois pagamentos que determine acumulação, substituição, crédito de migração ou data exata de início do acesso. Não transformar a política de código experimental em contrato comercial. O histórico contém diferenças de preço, links e modalidade: site avulso e app recorrente são caminhos distintos. Não alteramos nenhum deles.

HEAD dos dois links corretos do site retornou403; a navegação web também não conseguiu acessá-los. Nenhum formulário/checkout foi submetido. Uma auditoria adicional apenas de leitura foi preparada para conferir pagamento→merchant order→preference e eventual correspondência com os links. Falta de acesso não equivale a link incorreto; igualdade só será reportada se demonstrada.

Datas de aprovação e dados financeiros individuais ficam na custódia privada local central-rights/historical-payments.json; não são copiados para GitHub. O último GET autenticado confirma aprovação sem direito aplicado; isso não estabelece sozinho início/fim contratual. Não há plano de escrita executável/autorizado com datas inventadas.

A proposta de conciliação deve fixar: vínculo de cada pagamento ao plano/UID, datas exatas comprovadas, tratamento do período mensal frente ao anual, chave idempotente global e preservação de trial/favoritos. Reconsultar o provedor e ledger imediatamente antes de eventual transação aprovada pelo proprietário. Sem essa comprovação, manter revisão pendente e zero concessões.

## Resultado autenticado da origem

[CI41558913252](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41558913252) concluído com sucesso: os dois recursos de pagamento retornaram sem order.id. Sem esse vínculo não se consultou preference por adivinhação e não foi demonstrada correspondência com os links curtos. [Flags sanitizadas](checkout-origins.json). Zero escritas ou concessões. As durações1mês/12meses permanecem comprovadas na oferta histórica, não como datas de cobertura específicas nas transações. Não foi encontrada regra expressa de acumulação/substituição.
