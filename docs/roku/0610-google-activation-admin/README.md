# Rocha+ Roku LAB 0.6.10 — relatório de etapa

Atualizado em 03/11/2026. Branch: `lab/roku-0.6.10-google-activation-admin-20261103`, criada a partir de `471c1bf76ba25656cdaf356abc30ff8d8c360a47`. Código da etapa: [commit 0.6.10](https://github.com/japarocha2-cloud/rocha-plus/commit/7b245b4336dd7e695d5813c9d3f37fc0dba63cea). Commits adicionais de layout e CI estão no histórico da branch.

## Resultado

O LAB prepara vínculo por navegador móvel com OAuth Google oficial e código manual de oito caracteres. O Roku não gera QR. A aprovação real continua indisponível porque não há host HTTPS e backend isolado habilitados. Configurações comercial, central e LAB permanecem `enabled:false`; nenhum acesso foi concedido. O endpoint Firebase OAuth público não foi preenchido no pacote, e não há credenciais privadas incluídas.

A função ADM vem exclusivamente do custom claim do servidor, sob política separada que continua desativada. Gmail, login Google ou IAM do projeto não concede papel ADM nem direito de reprodução. A leitura histórica de conta em CI indicou claim `rochaAdmin=false`; esta etapa não consultou novamente a conta e não autenticou `rochaplus.app@gmail.com`. Login real e validação ADM: **NÃO EXECUTADOS**.

## Testes e evidências

- Backend isolado: 12/12 testes de fixture passaram nesta etapa, pelo Node runtime local. Incluem vínculo sem direito de playback, separação ADM/direito, aprovação de uso único, código expirado/cancelado, rate limit, limites de TVs/streams, revogação e concorrência. Não são testes Google/produção.
- Cliente BrightScript: matriz registrada de 9/9 checks, fixture/headless, anteriormente aprovada; não repetida nesta etapa.
- ZIP: 574 arquivos, estrutura Roku e CRC revisados pelo empacotador, manifesto 0.6.10, catálogo 607 registros, 578 associações de capa; flags auth/central/LAB desligadas; nenhuma URL de fixture ou segredo detectado.
- BRS Desktop estava aberto e sua árvore de acessibilidade indicava versão 0.6.10 e 0 erros/0 avisos. A tela do simulador expirou durante captura; o ZIP revisado não foi instalado nessa sessão. Execução gráfica desta versão e teste de controle remoto: **INCONCLUSIVOS**. Capturas no diretório desta etapa são do harness local, não provam Google real nem playback. Uma captura de fixture mostra rodapé do harness sobreposto; revisar antes de usar como evidência visual de layout.
- Google OAuth, reconhecimento ADM, persistência real, TV física, áudio, vídeo e reprodução: **NÃO EXECUTADOS**.

## ZIP revisado

Nome: `RochaPlus-Roku-LAB-0.6.10-ACESSO-DESATIVADO-REV2.zip`  
Tamanho: 4,538,938 bytes  
SHA-256: `d789c6607b0f32bb2629adf9b1082518715c3a624f1e16445972fbf6817ddaa1`

A cópia de trabalho foi criada em `artifacts/roku-lab/20261103/`. O workflow [Roku LAB 0.6.10 package](https://github.com/japarocha2-cloud/rocha-plus/actions/workflows/roku-0610-package.yml) reconstrói esse ZIP de forma determinística, roda os 12 testes, valida catálogo/configuração/segredos e publica um artefato GitHub Actions por 30 dias. Link de download do run só pode ser registrado depois de confirmar uma execução concluída. O ZIP anterior `0.6.10-LOGIN-GOOGLE-ATIVACAO-ADM.zip` foi preservado (4,538,927 bytes; SHA-256 `467135d58fc1fce92fc02950dcb3dd9ad81bbf9f6ac6738d95c8fdf04260bb7b`); revisão anterior não substitui o REV2.

## Próximos passos

1. Confirmar CI verde e registrar URL do run e artefato. Não declarar o artefato persistente antes disso.
2. Instalar manualmente o REV2 no BRS via Developer Mode/Replace with ZIP, preservando dados; repetir captura quando o simulador responder.
3. Confirmar com o proprietário o projeto Firebase de homologação, domínio OAuth autorizado, host TLS e Firestore isolado; nenhum deve ser inferido ou ligado à produção.
4. Somente após configuração/autorizações específicas, testar o OAuth Google real e confirmar o claim ADM sem conceder um.
5. Depois testar navegação, categorias, capas, favoritos, busca, playback de streams autorizados, imagem/áudio e controle remoto no simulador e Roku físico.

Sem QR, API/endpoints ativos, vínculo real ou reprodução aprovada. Sem merge, deploy, publicação, alteração comercial, Roku oficial, Android, Candidata 6, LAB 714 ou app dos avós.


## Teste manual real no BRS Desktop — REV2 (03/11/2026)

O arquivo selecionado pelo proprietário foi conferido antes da instalação e novamente após os testes: RochaPlus-Roku-LAB-0.6.10-ACESSO-DESATIVADO-REV2.zip, 4.538.938 bytes, SHA-256 d789c6607b0f32bb2629adf9b1082518715c3a624f1e16445972fbf6817ddaa1. O BRS Desktop carregou o ZIP em C:/Users/Administrador/Downloads/; a árvore de acessibilidade confirmou versão 0.6.10 e 0 erros / 0 avisos. Não houve tela branca.

### Evidência e resultados

- Capturas reais salvas pelo BRS Desktop: brs-rev2-home.png, brs-rev2-after-right.png, brs-rev2-reopened.png e brs-rev2-after-back.png, no diretório local docs/roku/0610-google-activation-admin/. Mostram marca Rocha+, fundo/banner galáxia, menu lateral, categorias escurecidas pelo overlay e a mensagem “Acesso LAB aguardando configuração e confirmação da conta. Assinatura comercial não consultada.” A tela também mostra “Conecte sua conta Rocha+” e “OK: tentar novamente • Voltar: sair”.
- Foram enviados ao BRS comandos Right, Left, Up, Down, Return (OK) e Backspace (Voltar). Não houve mudança visível; a tela permaneceu no overlay. A navegação pelo controle fica NÃO VALIDADA; os comandos de teclado não comprovam resposta de um controle Roku físico.
- Fechamento do app no BRS (Ctrl+W) e reabertura do mesmo ZIP (Ctrl+O com o caminho verificado) concluídos. Após reabrir, versão 0.6.10, caminho REV2 e contadores 0/0 confirmados. Nenhuma limpeza de dados foi feita.
- Achado visual: rodapé de versão aparece truncado (“Roku LAB 0.6…”), embora a versão completa conste na barra de status do BRS.
- O teste real cobriu carregamento, ausência de tela branca, branding/aviso, estado do pacote e reabertura. Login Google, reconhecimento ADM, persistência de sessão, catálogo navegável, favoritos, busca, áudio, vídeo e reprodução continuam NÃO EXECUTADOS, pois o acesso LAB está desativado. Sem medição de FPS/RAM.

O artefato GitHub Actions confirmado é o run 41729054117 (https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41729054117), artefato 13275907155 (https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41729054117/artifacts/13275907155), commit de pacote 2fef125307d9c2e35e9c2d82d1860dbdafb5f3e0. O download e o hash do ZIP local coincidiram. As capturas foram gravadas no workspace local e ainda não têm URL permanente no GitHub. Nenhuma correção de código foi necessária nesta etapa; nenhum ZIP novo foi gerado.

**Status: AMARELO.** A inicialização/visual do aviso e reabertura foram observados; navegação sem resposta visível, autenticação, playback e hardware permanecem pendentes. Integrações comerciais continuam desativadas; nenhum direito ADM concedido.

## REV3 para teste físico — BLOQUEADO por falta de allowlist de direitos (03/11/2026)

Pedido de novo ZIP para testar canais com imagem/áudio sem assinatura comercial foi avaliado a partir da última base validada REV2. A REV2 permanece o artefato mais recente seguro: [run 41729054117](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41729054117), [commit 2fef125307d9c2e35e9c2d82d1860dbdafb5f3e0](https://github.com/japarocha2-cloud/rocha-plus/commit/2fef125307d9c2e35e9c2d82d1860dbdafb5f3e0), ZIP 4,538,938 bytes, SHA-256 `d789c6607b0f32bb2629adf9b1082518715c3a624f1e16445972fbf6817ddaa1`. Não repetir testes verdes sem alteração.

### Evidências do bloqueio

- `experiments/roku-readiness/physical-channel-lab.example.json`: `approvedForPhysicalTest: []`, host não configurado, autorização desabilitada, `readyForEnabledZip:false`.
- `platforms/roku-lab-visual/config/lab-access.json`, `auth.json` e `central-access.json`: desativados, endpoints vazios. `physical-lab-access.json` está em `account_homologation`.
- O código legado tem modo local `physical_test_2h` que habilitaria reprodução local sem identidade no servidor; o loader de catálogo atual percorre `commercial-lab-merged.json`, não exige `approved:true` e só ignora `blocked/quarantined`. Não ativar esse modo para o teste solicitado.
- No snapshot 0.6.10: catálogo integrado tem 607 itens: 395 `approved:false`, 212 sem campo de aprovação e nenhum `approved:true`. `catalog/approved.json` tem 190 marcas `approved:true`, com evidência de estabilidade/decodificação, mas isso não prova autorização de direitos/plataforma Roku nem substitui referência legal. A amostra isolada de 12 não foi demonstrada como allowlist com direitos.

Um REV3 com playback aberto ou o timer físico daria acesso a itens cuja autorização Roku não está registrada. Por isso não foi criado pacote de playback amplo nem temporizador novo. Nenhuma modificação de código/configuração e nenhum novo ZIP foram feitos; REV2 não foi alterado. Nenhum pagamento, direito, Firebase comercial, assinatura ou versão oficial foi tocado.

### Para liberar a próxima etapa com segurança

1. Fornecer uma allowlist de IDs Rocha+ (ou nomes+IDs), cada uma ligada a evidência de permissão: origem/licença, permissão explícita para Roku/teste físico, validade e responsável pela revisão. Não enviar URLs assinadas, tokens ou credenciais.
2. Disponibilizar um endpoint HTTPS já existente em Firebase/projeto LAB isolado, com identidade/test account de homologação e escopo/expiração aprovados. Não criar recursos, chaves ou IAM nesta ordem.
3. Ajustar o build para limitar seleção e reprodução à allowlist no servidor e no cliente, sem alterar os 607 registros nem a fonte comercial; manter duas reproduções/dispositivos conforme política, quando aplicável.
4. Testar CI com allowlist e expirado/revogado/replay negado; gerar REV3 via Actions com auth comercial desligada; verificar ZIP, SHA-256 e artifact URL.
5. Instalar manualmente na TV Roku do proprietário e registrar imagem/áudio/controle somente para os IDs autorizados. Reprodução física não é aprovada até essa execução real.

### Estado desta etapa

**Sem REV3 para baixar.** Bloqueio concreto: allowlist jurídica/física vazia e endpoint de homologação ausente. Testes automáticos novos: não executados; os checks aprovados do REV2 foram preservados. Instalação e reprodução física da REV3: não executadas. Incidente/solicitação continua aberto. Próximo passo: anexar allowlist e confirmar endpoint LAB existente; então retomar implementação na mesma branch experimental.


### Atualização após resposta do proprietário (03/11/2026)

O proprietário informou que dispõe de uma lista de canais autorizados, mas não forneceu nesta resposta os IDs/nomes, referências de permissão, validade ou responsável pela revisão. Nenhuma allowlist pôde ser comparada ao catálogo/build. Também não indicou endpoint HTTPS de homologação existente; as configurações consultadas continuam sem origem/endpoints.

Não usar o modo local `physical_test_2h` neste ZIP público: ele habilitaria reprodução sem vínculo/verificação do servidor e não oferece limite por identidade. A lista por si só não basta enquanto o runtime não puder autorizar somente IDs aprovados e emitir/revogar sessão LAB. REV3 continua sem build/artefato.
