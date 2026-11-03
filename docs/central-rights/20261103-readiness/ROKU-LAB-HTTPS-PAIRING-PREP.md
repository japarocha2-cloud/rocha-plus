# Rocha+ Roku LAB — HTTPS isolado e alternativas de pareamento (03/11/2026)

**Estado: preparação somente. Sem deploy, custos, login real, concessão de direito, QR funcional ou mudança do contrato existente.**

## Arquitetura e infraestrutura

A configuração congelada está em `experiments/roku-readiness/runtime-preparation.json` (`enabled:false`, `publicServiceEnabled:false`, `labProjectId:""`, `origin:""`, `listenHost:"127.0.0.1"`, `paymentsEnabled:false`). O arquivo é template desativado, não endereço público. `platforms/roku-lab-visual/config/central-access.json` e `config/lab-access.json` continuam desativados com URLs vazias.

O host isolado ainda **não foi escolhido, contratado ou verificado**. Antes de qualquer ativação, apresentar para aprovação:

- Host/provedor, custos previstos, região, processo de deploy e rollback, domínio homologado sob controle do proprietário, DNS A/AAAA/CNAME e prazo de expiração.
- Certificado TLS válido para o host e cadeia de confiança verificável por Roku, Android TV e celular; rejeitar certificados inválidos e desabilitação de TLS. `localhost`/127.0.0.1 não é acessível entre dispositivos distintos.
- Rotas estritamente necessárias: `GET /approve` e `POST /v1/access`. CORS/origin e CSP restritos, limites de corpo, método, tempo de resposta, proteção contra brute-force, sessão vinculada a UID/dispositivo e expiração.
- Identidade **gerenciada e exclusiva do host**, sem JSON privado no pacote Roku e sem usar credencial CI comercial. A identidade deverá ler somente o necessário em Firebase Auth e registros comerciais autorizados, e usar transações somente no banco LAB separado. Revisar IAM concreto antes de conceder.
- Logs de request-id, status, latência e classes de falha sem UID, e-mail, conteúdo de token, código de pareamento ou payload de pagamento. Não registrar Authorization.
- Testes físicos de rede Wi-Fi, resolução DNS, TLS/handshake, 4xx/5xx, perda/reconexão, renovação, expiração/revogação e erro do banco. Nenhuma conectividade entre aparelhos foi demonstrada ainda.

## Solução mínima por 403

Comercial: consultas administrativas da execução 41551744667 retornaram 403 para `cloudfunctions.functions.list` e `logging.logEntries.list`. Não adicionar esses privilégios ao runtime Roku; se a auditoria administrativa for necessária, pedir aprovação explícita do escopo de leitura e prazo.

LAB: execução 41619638681 retornou 403 para `rocha-plus-homologacao/databases/(default)` com a credencial CI comercial. Confirmar principal efetivo, corpo sanitizado do Google, projeto/banco e API antes de qualquer alteração. A consulta de metadados não comprova permissão transacional; o 403 não prova ausência do banco. **Nunca conceder Owner/Editor como atalho.**

Rollback proposto, não executado: manter flags `false`, remover eventual atribuição IAM **exata** concedida futuramente, revogar só os recursos novos e preservar logs/artefatos de diagnóstico. A revogação deverá ser aprovada e registrada com identificador de concessão, projeto, função e início/fim; não tocar atribuições preexistentes.

## Pareamento atual e expansão opt-in

**Fluxo existente preservado:** código alfanumérico de 8 caracteres/10 minutos, 1 celular, 2 TVs vinculadas, até 2 streams, preservação das TVs na troca de celular, consultas neutras sem liberar slot, stop explícito libera somente o próprio slot, terceiro stream 409, revogação e expiração falham fechadas. 64 backend/HTTPS e 36 Android verdes históricos, não repetidos nesta etapa.

**QR experimental proposto (não integrado):** renderizar na Roku apenas uma URL HTTPS de aprovação LAB com identificador opaco *público de pareamento*, de uso único, duração até 10 minutos, sem token de sessão, access/ID token, UID, e-mail ou grant no QR. O telefone abre HTTPS, exige Google login recente, exibe nome da TV e pede confirmação explícita. A implementação precisa vincular o pedido aos mesmos estados e regras do fluxo de 8 caracteres; HTTPS não deve conceder direito pelo simples acesso ao QR.

**Alternativa numérica (não integrada):** código aleatório gerado no servidor via CSPRNG, com no mínimo 6 dígitos e limite por conta/IP/dispositivo, tentativas/falhas com backoff, TTL curto e invalidação em uso; verificar riscos de entropia e rate limit antes de escolher comprimento final. Nunca converter/truncar o código alfanumérico atual em dígitos e nunca fazer validação apenas no cliente. Exigir Google recente e confirmação do aparelho também no numérico.

Contrato versionado/negociação de capacidade (futuro): `pairingModes: ['alphanumeric8']` por padrão, sem novos modos em clientes enquanto backend e testes não estiverem aprovados; modos `qr-https` e `numeric` só mediante versão experimental compatível e opt-in explícito. Códigos antigos permanecem válidos pelo prazo original; erros não liberam access.

## Testes novos necessários após implementar códigos

- QR adulterado/expirado/reutilizado; navegação HTTPS com origem errada/TLS inválido; telefone não autenticado; aprovação de conta errada; competição de duas aprovações; Back e revogação.
- Código numérico curto/colisão; excesso de tentativas por IP/conta/TV; código roubado não concede direito; expiração/uso único; migração compatível com alfanumérico atual.
- Consultas neutras não alteram reservas; stop/expiração/revogação liberam seletivamente; terceiro stream retorna 409; troca móvel preserva TVs.
- Testes físicos Roku + Android + celular, rede instável e logs sanitizados. Todos **NOT_EXECUTED**.

## ZIP físico disponível sem rebuild redundante

Pacote 0.6.8 já criado em commit `9d34121cb651726ee8f60dcd2ac8ba0d204423f9`, 4.538.311 bytes, 574 entradas, SHA-256 `00c3a2c6c8cea91958e11a4cf82fdecc1ff177bd4566431dc2a08f8636de1305`; 13 validações documentadas, verificação remota histórica. Contém carrossel corrigido e acesso explicitamente desligado. ZIP 0.6.7 intacto. Não reconstruir uma versão idêntica por mera renomeação. Instalação física não executada; sem login real, mídia e carrossel navegável desbloqueados.
