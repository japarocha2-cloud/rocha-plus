# Rocha+ Roku LAB — preparação segura para teste físico de canais (03/11/2026)

**Status: PREPARADO EM DOCUMENTAÇÃO, BLOQUEADO PARA ACESSO REAL.** Nenhuma credencial, IAM, grant ou endpoint foi ativado. Não usar esta etapa para contornar a autenticação. ZIP 0.6.8 preservado.

## 1. Bloqueio exato confirmado no fonte

`platforms/roku-lab-visual/components/Account.brs`: `initAccount()` invoca `initCentralAccess()`, depois `initLabAccess()`, depois `activatePhysicalLabAccess()` e só então a autenticação convencional. Em `CentralAccess.brs`, `initCentralAccess` retorna `false` porque `config/central-access.json` contém `enabled:false`, `endpoint:""` e `approvalUrl:""`. Em `LabAccess.brs`, `physical-lab-access.json` contém `mode:"account_homologation"`; `initLabAccess` escolhe esse fluxo, mas `config/lab-access.json` contém `enabled:false` e `endpoint:""`. Assim, define `authStage=lab_unconfigured`, mantém `authorized=false` e mostra o painel de bloqueio, sem pedir vínculo nem lease ao servidor. `config/auth.json` também está desativado. O bloqueio não é comprovadamente falha do decoder, dos streams ou do pagamento.

## 2. Arquitetura mínima para teste permitido

- **Identidade:** Firebase Authentication do projeto comercial existente `rocha-plus` apenas para autenticar a conta de teste Google, verificar UID e estado da conta, sem alterar status pago/trial.
- **Fonte de direitos:** apenas LAB `scope:homologation`, permitida ao UID/e-mail de teste previamente autorizado em configuração privada, com `notBefore`/`expiresAt` absolutos e máximo de 24 horas. Não derivar da existência de pagamento. Uma autorização temporária precisa de aprovação separada com conta, dispositivos e datas exatas.
- **Firestore LAB:** projeto candidato `rocha-plus-homologacao`, banco `(default)` ainda NÃO confirmado pelo principal de serviço, após 403 no GET de metadados. Host não deve assumir que o projeto é acessível até confirmação de databaseId e IAM. Transações de pareamento/sessões/slots exclusivamente nesse banco LAB, sem escrita comercial.
- **Runtime HTTPS:** host isolado ainda não definido, DNS controlado, TLS válido para Roku/celular, `GET /approve`, `POST /v1/access`; logs sanitizados; sem webhook de cobrança. Configuração `experiments/roku-readiness/runtime-preparation.json` continua `enabled:false`, origem/banco vazio.
- **Cliente Roku:** quando host e aprovação forem comprovados, futura versão experimental deve habilitar somente `config/central-access.json` com `enabled:true`, `environment:"central-rights-lab"`, `scope:"homologation"`, endpoint HTTPS e approvalUrl HTTPS; `lab-access.json` e `auth.json` permanecem desativados. A mudança de configuração necessita revisão do contrato e pacote validado. NÃO aplicar na 0.6.8 atual.
- **Contratos:** código alfanumérico atual com 8 caracteres e 10 minutos, login Google recente (5 min), 1 celular por conta, até 2 TVs, até 2 streams simultâneos. Leases de até 60 s revalidadas, terceira stream 409, consulta neutra não libera reserva, stop explícito libera apenas sua própria vaga, conta trocada/expirada/revogada bloqueia acesso. Não substituir por QR/número ainda desativados.
- **Dispositivos:** duas TVs no máximo vinculadas à conta LAB. Identificar hardware e ambiente em inventário privado antes de conceder; identificador de aparelho deve ser gerado aleatoriamente no fluxo e vinculado no servidor, não fixado como segredo em ZIP.

## 3. Matriz de permissões propostas, NÃO CONCEDIDAS

| Principal futuro | Projeto/recurso | Operação indispensável | Limites |
|---|---|---|---|
| Identidade de host **gerenciada separada**, a definir | `rocha-plus` Auth | Verificar tokens emitidos e obter status/UID da conta (`firebaseauth.users.get` quando exigido pela API em uso) | Não alterar usuários/provedores/claims; projeto e endpoint exatos a confirmar |
| Mesmo host, leitura comercial restrita | `rocha-plus` Firestore | `datastore.entities.get` nos documentos estritamente necessários | Nenhuma escrita, create/delete/update comercial |
| Mesmo host, transações LAB | `rocha-plus-homologacao` e databaseId confirmado | `datastore.entities.get/create/update/delete` apenas para sessões/grants operacionais e slots isolados, conforme regras e backend; verificar requisito de transação na implantação | Banco e coleções LAB; policy de serviço e isolamento revistos antes de conceder; sem Owner/Editor |
| CI histórico, **se** auditoria administrativa voltar a ser necessária | `rocha-plus` Functions/Logging | `cloudfunctions.functions.list` e `logging.logEntries.list` | Não são permissões necessárias ao runtime Roku; autorização separada |

Papéis prontos do Google não equivalem automaticamente a escopo por coleção/documento. Confirmar a configuração de menor privilégio tecnicamente aplicável no host e IAM antes de fornecer comandos executáveis; se não for possível impor restrições por IAM para o acesso server-side, limitar por projeto/banco e controles de aplicação auditados. O `testIamPermissions` com lista vazia não demonstra existência/inexistência do banco; o 403 exige corpo Google sanitizado e principal efetivo antes de qualquer concessão.

## 4. Canal autorizado para teste: portão separado de direitos

O arquivo `catalog/approved.json` documenta aprovação **técnica de estabilidade**, não autorização jurídica. O catálogo Roku existente tem 607 registros e 578 associações de capa, que devem permanecer byte-idênticos nesta preparação. Não usar `status:approved`, canal aberto na internet, m3u público ou streaming reproduzível como substituto de licença.

Criar **registro privado de autorização de teste** com identificador de catálogo, emissora/originador, URL oficial autorizada, autorização/termos públicos que cubram uso neste LAB e plataforma/dispositivo, validade e responsável pela aprovação. O registro público versionável deve conter somente IDs e referências não sensíveis **após** verificação. Até lá, a allowlist de reprodução deve permanecer **VAZIA**, e o servidor deve recusar lease de canal não autorizado. Não incluir URLs com tokens de terceiros nem comprovantes privados em commits.

O contrato atual de `devices.mjs` gerencia slots/lease **por dispositivo**, e não seleciona IDs de canal autorizados. Para controle de canal individual, ainda precisa de uma validação server-side do canal/ID solicitado antes de emitir a lease ou entregar a URL de reprodução. Não alegar que a arquitetura atual já restringe os canais de acordo com a licença. Não bloquear os canais originais no catálogo visual, mas negar reprodução fora da allowlist.

## 5. Ordem segura de habilitação (dependente de aprovações futuras)

1. Recuperar log sanitizado da leitura 403 e determinar conta de serviço, projeto, banco, erro e eventual API desativada. O CI tem credencial comercial excessiva para runtime; não reutilizá-la no host.
2. Confirmar host/DNS/TLS/custo, acesso nos 3 dispositivos e identidade gerenciada sem chave privada; submeter proposta exata para aprovação; não contratar, habilitar ou implantar agora.
3. Validar direito de reprodução dos canais específicos e registrar allowlist LAB não vazia somente com evidência. Sem canais aprovados, teste de imagem/áudio fica bloqueado.
4. Depois de autorizados IAM e grant exato (UID, aparelhos, início/fim até24 h), testar no LAB com fixtures negativa/positiva, limites, expiração, reconexão e autorização por canal.
5. Criar **novo ZIP posterior ao 0.6.8** com apenas configuração HTTPS pública validada, nenhuma credencial privada, nova identificação experimental, checksum e diffs completos contra o 0.6.8. Manter 0.6.7/0.6.8 intactos e não substituir build antecipadamente.
6. Executar instalação manual em Roku LAB após confirmação de que o dev instalado não é Oficial. Registrar firmware, ID de teste privado, hash do ZIP e resultados físicos sem publicar tokens.

## 6. Roteiro físico pós-liberação (todos NOT_EXECUTED)

| Grupo | Testes / evidência |
|---|---|
| Login/vínculo | Google recente, código de 8 caracteres, confirmação no celular, única conta, até 2 TVs, troca de celular preservando as TVs; capturas sem códigos/token |
| Home/controle | Galáxia, logo, carrossel, foco e recorte; D-pad, OK, Back, lista vertical, busca, PET, categorias, Favoritos por conta |
| Prévia/player | Iniciar canal autorizado, vídeo e áudio separados, demora até primeiro frame/som, fullscreen, sair e voltar, selecionar canal rapidamente |
| Estabilidade | Canal autorizado por 60 s e 180 s, reconexão Wi-Fi, recuperação após erro, pausa e stop reais, divergência entre slot liberado e decoder cessado |
| Limites | Terceira TV e terceira reprodução retornam 409, duas simultâneas permitidas, stop libera somente um slot, expiração e revogação negam acesso |
| Negativos | Canal fora da allowlist não recebe lease, token inválido, TLS inválido, conta não autorizada, host indisponível, servidor 403/503 |
| Integridade | Preservar favoritos e temporizadores anteriores, conferir hash de artes/catálogo, registrar memória/FPS somente com medições físicas reais |

## 7. ZIP atual

0.6.8 já recuperado em GitHub, commit `9d34121cb651726ee8f60dcd2ac8ba0d204423f9`, tamanho 4.538.311 bytes, SHA-256 `00c3a2c6c8cea91958e11a4cf82fdecc1ff177bd4566431dc2a08f8636de1305`, 574 entradas e 13 validações estruturais documentadas. Ainda **BLOQUEADO para reprodução**; não apresentar como pacote habilitado. Próximo ZIP operacional depende das etapas 1–4. Não há teste físico homologado nessa missão.

**Próximas decisões do proprietário:** autorizar exatamente o host proposto (provedor/domínio/custo), aceitar eventual alteração IAM com identidade/função/escopo individualizados, designar conta/dispositivos LAB e prazo, e fornecer/verificar os direitos de canais específicos para o teste. Cada decisão depende de proposta concreta; este documento NÃO constitui autorização para executar as mudanças.
