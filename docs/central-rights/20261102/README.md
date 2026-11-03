# Plantão — pagamentos, direitos centrais e integração experimental

Atualizado em02/11/2026, horário de Brasília. **Estado: preparação técnica entregue; missão operacional/comercial ainda PARCIAL e BLOQUEADA.** Nenhuma assinatura comercial concedida, cobrança, deploy, merge ou publicação de aplicativo. Não tratar testes verdes como homologação de pagamento ou reprodução real.

## Diagnóstico comprovado

[A conta e os dois pagamentos foram auditados em leitura](authenticated-audit.json), no projeto comercial rocha-plus. No último diagnóstico de status, ambos eram regular_payment aprovados, pagador/recebedor correspondentes, sem reembolso/estado de disputa indicado. Spark sem paidUntil e nenhum direito aplicado nos stores conhecidos inspecionados. As datas individuais ficam em custódia privada; nenhum UID, e-mail ou ID financeiro é copiado aqui.

A [pesquisa histórica](historical-offer-audit.md) encontrou a oferta correta do site: mensal e anual12meses, com links diferentes dos planos recorrentes antigos. O backend recorrente e a leitura Spark não constituem uma ponte automática para esses avulsos. Existem esquemas e chaves de identidade distintos. Não foi encontrada regra contratual final de acumulação/substituição nem início/fim específicos dos dois pagamentos. As minutas deixam migração sem decisão; códigos experimentais usam políticas diferentes. Não escolher uma por suposição.

A [auditoria de origem](checkout-origins.json) retornou order.id ausente em ambos. Não se consultou preferência por ID adivinhado. Os links curtos corretos retornaram403 na leitura. Não foi possível provar pagamento→link→contrato. Busca de comprovantes restrita às duas transações no Gmail conectado não encontrou mensagens; não é busca global nem prova de inexistência de recibo.

Cloud Functions e logs do webhook retornaram403 por falta de permissões de leitura; endpoints convencionais derivados da fonte retornaram404. Isso não prova ausência de outro endpoint ou falha de entrega específica. [Sondagens](endpoint-probes.json). Não alteramos configuração, IAM ou segredos. Firestore comercial confirmado STANDARD/FIRESTORE_NATIVE.

## O que foi implementado no LAB

[Código e contrato central](../../../experiments/central-rights/README.md), fonte final preparada no commit4e949050f007209464bc147b7772c6b2435283ee.

- Fonte única por UID, estados paid/trial/expirado/revogado/pendente/LAB/desconhecido e lease até60s com relógio do servidor. A leitura não cria trial; adota o início original de7dias.
- Intenção de checkout com referência opaca e identidade verificada, sem criar checkout no provedor ou cobrar. Resolvedor exige reserva confiável ou contrato histórico revisado/autorizado. Nenhuma política comercial default é aprovada automaticamente.
- Webhook HMAC com consulta servidor-servidor, validação de recebedor/modo/moeda/valor/vínculo/período, ledger global idempotente, fila/alerta de revisão, reprocessamento, estorno e falhas transitórias. O mesmo período não é somado em duplicata.
- Uma sessão móvel, duasTVs e dois streams; TV ociosa não ocupa reprodução. Troca de celular preservaTVs. Estado transacional de pequenoLAB; adapter de escrita recusa projeto comercial e Candidata.
- Runtime HTTPS em loopback com página de aprovação Google/Firebase, sessões de dispositivo e restrição à conta exata configurada. Certificado efêmero só em memória nos testes; nenhuma CA instalada ou TLS desativado. Verificador real e credenciais próprias do host não configurados/ativados.

Os handlers não são importados pelos entrypoints oficiais e não foram publicados. Fila/alertas existem no adapter experimental; scheduler/notificação operacional e nova integração do checkout real não foram ativados. Antes de produção será necessária revisão operacional e de escala; o store de dispositivos tem limites explícitos de pequenoLAB.

## Android celular e Android TV

Branch lab/central-rights-android-20261102, código [86a7002](https://github.com/japarocha2-cloud/rocha-plus/commit/86a700209166ad36d4deb90c47ff82d29915e86e), [relatório persistido](https://github.com/japarocha2-cloud/rocha-plus/blob/d3c56ab6551c844fcb27501ba326d0c9a5cff641/docs/central-rights/README.md). Base PR42 preservada em61780147654b42709070702a677eec24b33a2ac5, ainda draft.

Cliente compartilhado opt-in, com padrão ROCHA_CENTRAL_RIGHTS=false: identidade Firebase, código/pareamentoTV, restauração por UID+endpoint, consulta sem reinstalação e wrapper de Exo/VLC que só monta o player após lease de reprodução. Renovação/expiração e troca de conta falham fechadas. Home não ocupa slot. Sem APK novo ou alteração da C6/LAB714. Cast físico, receiver offline e atribuição de slot ainda não homologados.

## Roku0.6.7 preparado

[ZIP permanente](https://raw.githubusercontent.com/japarocha2-cloud/rocha-plus/572733db6f9d99f4b64f59d40f28d3602b4f89ac/artifacts/roku-lab/20261102/central-rights/RochaPlus-Roku-LAB-0.6.7-CENTRAL-PREPARADO-20261102.zip), código/artefato572733db6f9d99f4b64f59d40f28d3602b4f89ac.4.538.188bytes,574arquivos, SHA2566ff88bbf99786163a6de80eeb18c985557ea2a68441c102d114e26ab34f3cd07. [Download integral reconferido](remote-zip-verification.json).

Novo CentralAccess.brs usa o mesmo contrato e código móvel, mas central-access.json continua enabled=false/endpoint vazio. Corrigidos dois defeitos demonstráveis: números primitivos de ParseJson eram rejeitados pelo validador numérico; saída local podia apagar sessão sem primeiro liberar aTV no servidor.35checks passaram, incluindo9vetores iguais aos do Dart/servidor.

578associações,534texturas,29pendências e607registros/599runtime preservados; imagens, catálogo e configurações anteriores iguais byte a byte. [Delta do pacote](roku-067-package.json). Nada na homologação, ordem ou artes mudou.

0.6.7 **não foi instalado**. A última execução nativa é0.6.6 no commit89c71a8:3aprovados,3parciais,8grupos bloqueados. A consulta ECP ao final desta missão não respondeu; não afirmar versão ativa atual. Não contornamos o bloqueio, rearmamos relógio ou usamos fixtures para liberar o catálogo real.

## Validação final

[CI e contagens](ci-status.json), [matriz dos24cenários](TEST-MATRIX.md), [preservação das branches](preservation.json).

| Camada | Resultado | Evidência |
|---|---|---|
|Backend|52testes:28integração+8HTTPS+6contratos+6E2E+4Firebase|[CI41559660532](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41559660532)|
|Android|34testes direcionados; análise sem problemas|[CI41559164920](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41559164920)|
|Roku|35checks engine,14anteriores relacionados+21novos|[Resultados](roku-client-tests.json), sem prova de decoder/rede real|
|Auditorias|6segurança+6origem; consultas autenticadas em leitura|[Conta](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41551744667),[origem](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41558913252)|
|Ponta a ponta local|6cenários HTTPS completos, incluídos nos52|[Detalhes](https-e2e-tests.json); Auth/provedor/banco/player simulados|
|Firebase/TVs reais|Não homologados|Sem login positivo, direito real, áudio/vídeo ou desempenho físico aprovados|

Falhas intermediárias preservadas: CI41552648744 falhou na fixture de certificado ASN.1; gerador corrigido. CI41553166585 passou testes e falhou análise por Future sem await; corrigido. As rodadas finais acima estão verdes. Só testes relacionados às mudanças foram repetidos; verdes antigos restantes preservados.

## Conciliação e aprovação

[Proposta de conciliação](COMMERCIAL-RECONCILIATION-PROPOSAL.json): dry-run, readyToApply=false, commercialPatch=null. Não há datas inventadas ou autorização solicitada para uma alteração indefinida. A vigência específica dos pagamentos não pôde ser estabelecida. Será necessária evidência de contrato/período para produzir a transação exata, seguida de autorização expressa do proprietário antes de escrever direito comercial.

[Ativação e roteiro físico](ACTIVATION-AND-PHYSICAL-TESTS.md). Faltam acesso de leitura à configuração/entregas do webhook, documento contratual aplicável, hostHTTPS confiável com identidade comercial de leitura e bancoLAB separado, aprovação móvel real e homologação nas três plataformas. Não exportar segredo deCI. Nenhum serviço público pode ser ativado com esta entrega.

## Recuperação em outro chat

Leia AGENTS.md e o relatório mestre na branch Roku, esteREADME, ci-status.json e TEST-MATRIX.md. Código central em experiments/central-rights; Roku em platforms/roku-lab-visual; ZIP em artifacts/roku-lab/20261102/central-rights. Android tem snapshot completo na branch separada, sem alterar PR42. preservation.json lista os caminhos alterados. Os commits de documentação são posteriores aos de código/CI e devem ser consultados no histórico.

Com Node22+, executar as funções runIntegrationTests, runHttpsTests, runContractTests, runEndToEndTests e runFirebaseBoundaryTests nos respectivos arquivos .test.mjs, conforme o workflow central-rights-tests.yml. O engine Roku usa tests/roku-visual/central-access-runner.mjs e o app.asar instalado. Android: executar os quatro arquivos de teste e análise definidos no workflow central-rights-android.yml; não gerar APK. Não repetir rodadas verdes sem mudança/regressão.

Cópia local Roku: C:/Users/Administrador/Documents/ChatGPT/Rocha +/repository. Delta Android local: C:/Users/Administrador/Documents/ChatGPT/Rocha +/android-central-experiment; a fonte completa está no GitHub. Dados financeiros privados: C:/Users/Administrador/Documents/ChatGPT/Rocha +/private/central-rights/historical-payments.json, fora do repositório, persistente neste computador e não acessível por um chat em outra máquina. Proposta privada de autorização LAB anterior permanece fora do GitHub, desativada e sem ampliar sua expiração. Relatórios compartilhados não dependem de credencial ou dado pessoal em texto público.
