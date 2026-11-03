# Diagnóstico de acesso e reservas — 03/11/2026

Escopo: investigação somente, base Roku d350ed3786164a2bc533938f74d4d251e6e062f6; Android experimental d3c56ab6551c844fcb27501ba326d0c9a5cff641. Sem correções, configurações, serviços iniciados, ZIP, concessões ou escritas em Firebase. Apenas relatório/evidência em memória. Branch remota conferida sem avanço antes do diagnóstico.

## Causa comprovada do bloqueio atual

Account.brs:22–24 tenta initCentralAccess, depois initLabAccess, depois acesso físico. CentralAccess.brs:6 retorna false porque config/central-access.json contém enabled:false; endpoint e approvalUrl vazios. O fluxo seguinte encontra physical-lab-access.json mode:account_homologation. LabAccess.brs:14 define lab_unconfigured; lab-access.json contém enabled:false e endpoint vazio. Então mostra exatamente o aviso fotografado e retorna antes de restaurar sessão, gerar código ou consultar direitos. m.authorized permanece false, painel intercepta navegação.

Não é uma resposta negativa de Firebase, pagamento, rede ou reserva de stream. Também não é o aviso do temporizador de duas horas: o modo physical_test_2h não é alcançado. Nenhum temporizador foi alterado. Evidência nativa anterior: ../20261102-followup/067-retry.png; XMLs confirmam dev0.6.7.

Detalhe adicional de interface: labAccountKey trata OK apenas em lab_locked, enquanto inicialização termina em lab_unconfigured. Por inspeção, OK nesse estado é consumido sem iniciar pedido. Condiz com teste nativo anterior; não precisa nem deve ser convertido em bypass. Proposta: futuramente esclarecer configuração indisponível e ação permitida, mantendo fechado enquanto sem runtime.

## Reserva removida — reprodução diagnóstica confirmada

Servidor experiments/central-rights/devices.mjs: no final, playing é true para mobile_playback ou status com playback_active:true. O else if action!=poll apaga a reserva do dispositivo. Assim entitlement do celular apaga streams.mobile. Cliente Android experimental lib/src/auth/central_rights_client.dart, status(tv:true,playback:false), envia status com playback_active:false, idêntico ao stop explícito. O servidor não pode distinguir consulta de navegação de parada.

Execução apenas por imports dos módulos atuais e memoryStore, sem arquivos de aplicação alterados. Relógio fixo 1800000000000, UID fictício diagnostic-fixture, IDs/tokens fictícios hexadecimais, identidade/conta e grant sintéticos, scope homologation. Estado inicial por caso: celular vinculado, duas sessões TV válidas, zero streams. Passos: mobile_playback; status(true) TV1; status(true) TV2; consulta; repetir status(true) TV2. Não houve passagem de tempo, expiração, logout ou parada do decoder na fixture.

| Consulta intermediária | Celular | TV1 | TV2 antes | Consulta | TV2 depois |
|---|---:|---:|---:|---:|---:|
| entitlement celular |200|200|409|200|200|
| status(false), como navegação Android TV |200|200|409|200|200|

O primeiro slot desaparece indevidamente no caso celular. No segundo, o protocolo atual interpreta a consulta Android TV como parada. Resultado: servidor passa a aceitar terceiro dispositivo enquanto os dois anteriores podem ainda reproduzir com leases emitidas. Confirma falha de contabilidade em fixture, não prova três decoders reais nem ocorrência em produção. NÃO causa o bloqueio atual: código não é alcançado na configuração Roku instalada. Teste Dart do corpo HTTP real e concorrência em dispositivos ainda não executados nesta etapa.

Plano de correção, AGUARDANDO AUTORIZAÇÃO: servidor preservar reservas em entitlement e status de consulta sem campo playback_active; liberar somente mobile_stop ou status com false explícito, além dos casos legítimos de logout/revogação/expiração. Cliente Android TV omitir playback_active em consulta neutra, mandar true na reprodução e false só em stop. Revisar consumidores e manter Roku requestLabStatus true enquanto preview/playing e releaseLabPlaybackLease false explícito. Validar fixture de terceiro stream antes/depois da consulta, parada e expiração, restauração, revogação e troca de celular sem remover TVs; teste Dart do corpo enviado e corridas de stop/novo player. Nenhuma implementação nesta etapa.

## Runtime HTTPS: preparado em código, não operacional

Arquivos: firebase-runtime.mjs, read-source.mjs, firestore-adapters.mjs, https-runtime.mjs, mobile-approval.html, runtime.example.json. createFirebaseRuntime recebe dependências por injeção; createHttpsRuntime recebe key/cert/handler; listenLoopback escuta 127.0.0.1. Não há configuração de host operacional preenchida no exemplo. Não foi feita nova verificação de credenciais ou IAM real nesta etapa.

Faltam evidências/configuração autorizada de: host isolado e rota acessível simultaneamente ao celular e BRS/TV, origem HTTPS e certificado confiável nesses clientes, composição do processo com Firebase Admin e credenciais próprias, projeto/banco LAB explicitamente confirmado e permissões mínimas, configuração pública Firebase consistente com identidade comercial rocha-plus, domínio autorizado de Auth/OAuth já existente, e autorização privada restrita à conta com início/fim absolutos aprovados (máximo24h). Não alterar Auth de produção para acomodar domínio sem homologação/autorização. Se nenhum domínio já autorizado atender ao host isolado, registrar impedimento.

Identidade rocha-plus não implica banco de escrita comercial: runtime exige Auth desse projeto e leitura comercial; armazenamento de sessões exclusivamente LAB separado. Adaptador rejeita rocha-plus e rocha-plus-candidate para escrita. Histórico rocha-plus-homologacao não é confirmação de acesso/configuração atual. Leitor exige conta Google verificada e snapshot existente; não cria trial. Configuração scope homologation remove períodos/trial da decisão e só aceita grant LAB exato autorizado. Pagamento aprovado não abre este ambiente automaticamente.

Certificado efêmero localhost dos testes não serve para clientes reais; 127.0.0.1 no celular/TV aponta para o próprio aparelho. Não desabilitar TLS, abrir serviço público ou instalar CA global. Separar segredo Admin de configuração pública; não reutilizar/exportar segredos CI. Rotas necessárias /approve e POST /v1/access; não injetar paymentWebhook nem ativar pagamentos. Ausência de credenciais próprias permanece impedimento, não permissão para usar produção.

## Sequência segura proposta — não executada

1. Aprovar separadamente a correção de reservas e seus testes, mantendo autenticação desativada; depois revisar resultados e commits antes de ativação.
2. Confirmar inventário do host, certificado, rede, projeto LAB, domínio Auth já autorizado e acessos mínimos, sem mudar produção. Fazer preflight negativo de TLS/origin/identidade incorreta e verificar isolamento.
3. Submeter autorização LAB exata de conta, ambiente e prazo ao proprietário. Não prolongar a proposta anterior, não conceder direito nesta etapa. Falta de contrato comercial não autoriza marcar paid; homologação deve permanecer independente.
4. Somente após autorização específica, configurar runtime e clientes experimentais. Esta etapa atual não gera ZIP; pacote atual tem configuração embutida desativada, portanto corrigir backend sozinho não abrirá 0.6.7. Eventual pacote configurado exige etapa posterior autorizada.
5. Usuário faz login Google real no celular e confirma código de8caracteres da TV dentro de10minutos. register_mobile exige autenticação recente (até5minutos), substitui apenas celular anterior, preserva TVs. approve verifica vínculo/limite2TVs; poll entrega sessão e lease curta. Página preparada exibe código manual, não há comprovação de QR implementado.
6. Conferir UID/dispositivo/scope/expiração da resposta e recusa de outra conta/terceiraTV/terceirostream, expiração e revogação. SessãoTV24h não equivale a acesso24h: lease de direitos até60s e grant absoluto limitam. Aprovação pode escrever sessões somente no LAB; por isso não executada agora.
7. Repetir grupos Roku bloqueados: navegação, categorias, lista/capas, PET, busca, favoritos preservados, prévia, fullscreen/Back. Registrar saída/retorno/rede e evidências. Áudio/stream único/RAM/FPS reais exigem testes específicos e físicos; não aproveitar fixtures como aprovação de mídia.

## Preservação

Nenhum arquivo executável modificado, Android oficial/C6/LAB714/Roku oficial intactos; sem merge/deploy/publicação/novo ZIP. CI anterior permanece referência, não foi repetido. Resultado novo é diagnóstico isolado em memória. Próximo passo depende de autorização para implementar a proposta de correção; concessão e ativação exigem autorização própria com escopo definido.


## Execução autorizada posterior — 03/11/2026

A ordem de execução posterior autorizou corrigir backend e cliente experimental. O diagnóstico acima é histórico. Correção aplicada em devices.mjs: consultas neutras não apagam nem prolongam reservas; apenas mobile_stop ou status(false) explícito libera. Atomicidade continua no callback transacional do store. Foram criados12cenários em reservations.test.mjs;12/12verdes localmente e28/28integração relacionada. Resultado inicial de fixture/comparação entre contextos corrigido; execução da versão antiga falha em preservação de entitlement, nova passa. Não houve alteração de política comercial.

Cliente Android TV corrigido mantido como overlay em experiments/central-rights/android-tv, aplicado em CI ao commit Android fixado d3c56ab. Dois testes novos verificam corpos de consulta/reprodução/stop/logout e semântica mobile. Branch Android não foi modificada, respeitando a branch exclusiva desta ordem. Nenhum APK. CI41590689968 concluído com sucesso:64backend/HTTPS e36Android, análise sem problemas.


## Fechamento da etapa autorizada

Código e testes: [bfedc1540c79d09ab812432163c7793679ad08f4](https://github.com/japarocha2-cloud/rocha-plus/commit/bfedc1540c79d09ab812432163c7793679ad08f4). [CI41590689968](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41590689968) completed/success nos doisjobs.64backend/HTTPS (12novasregressões) e36Android (2novostestes), zero falhas finais; Flutter analyze sem problemas. [Resultados](ci-results.json), [excertos](ci-test-excerpts.log), [matriz individual](regression-checklist.md), [antes/depois](http-before-after.json), [auditoriaHTTPS](https-mobile-audit.md), [preservação](preservation.json), [estado inicial](initial-state.json).

Antes: consulta celular/TV seguida de terceira reprodução200; depois:409nos dois casos. Stop legítimo libera só o slot correspondente; concorrência pela última vaga200/409. Memória serializada/HTTPSloopback e MockClient não comprovam concorrência Firestore real ou reprodução em aparelhos.

Arquivos executáveis alterados: devices.mjs; novo reservations.test.mjs; workflow central-rights-tests.yml; dois arquivos de overlay Android e README. Overlay validado no app experimental completo em checkout CI; aplicação na branch Android persistente não realizada porque a ordem exige branch exclusiva Roku. Cliente base Android conserva arquivo anterior, não instalar nem afirmar corrigido fora do overlay testado. Nenhum teste real de loginGoogle/Firebase ou playback nesta etapa.

Configurações central e LAB permanecem false/endpoints vazios, comprovadas por bytes; modo account_homologation preservado. Todo platforms/roku-lab-visual, catálogo607/578associações, artes, oficial e artefatos inalterados no diffGit. ZIP0.6.7 não regenerado,4.538.188bytes, SHA2566ff88bbf99786163a6de80eeb18c985557ea2a68441c102d114e26ab34f3cd07 reconferido. Nenhuma interação ECP/nova instalação, dados/favoritos/registros/temporizador não tocados.

Conclusão desta etapa: critérios de correção e regressão cumpridos no ambiente experimental testado; bloqueio LAB mantido conforme ordem. AtivaçãoHTTPS, aplicação futura na branchAndroid e homologação física permanecem pendentes, sem concessões ou implantação autorizadas. Não declarar missão operacional completa.
