# Rocha+ TV — Consolidado pós-integração e continuidade sem retrabalho

Registro de continuidade em 31/10/2026. Este documento preserva conclusões verificadas no GitHub e separa o que foi comprovado por CI daquilo que ainda exige ambiente privado ou teste físico.

## Governança e estado das branches

- Repositório: `japarocha2-cloud/rocha-plus`.
- Branch de homologação: `homolog/technical-candidate-20261028`.
- PR #44: **integrado mediante autorização expressa do proprietário**, merge commit `f30457c9c75b475b12212b510841180f30beceec`; conferido no GitHub como merged/closed. Branch de homologação idêntica ao merge commit após integração.
- PR #42: **open/draft, não integrado**; branch experimental `fix/subscription-access-20261026` preservada.
- Versão oficial congelada. Sem publicação, deploy, cobrança real, alteração visual ou troca do APK público. Rocha+ Office permanece independente.
- PR #44 deixou de ser draft apenas para permitir o merge autorizado. Não tratá-lo como ainda draft.
- Não repetir itens verdes sem mudança relacionada, regressão reproduzível ou evidência contraditória. Teste físico nº 6 permanece verde/congelado.

## Verdes comprovados — preservar

- Identidade/certificado: commit `cd239d109c664048eebdbc8d383582dad5a2471a` exige, em `prepare` e `verify`, o assinante público aprovado. Testes de regressão para certificados não aprovados adicionados.
- CI Candidate Identity Guards #26: run `41221538520`, **success**.
- CI Subscription safety checks #131: run `41221538508`, **success** (Flutter, entitlement, backend, Android); job de APK experimental **skipped**. Evidências anteriores #23 e #129 também verdes.
- Trial sandbox: commit `02593ee34f8f987f98840adae0b035ce51840101`, CI `41222167987` **success**. Ensaio Firestore Emulator → endpoint → respostas JSON → gate Flutter, com ativação experimental apenas no processo de teste. Trial exatamente 7 dias, concessão única sob quatro consultas simultâneas, negação no vencimento exato, bloqueio após rechecagem, renovação fictícia, direitos independentes e estornos fictícios.
- Sandbox fictício isolado `demo-rocha-sandbox`, sem chamadas externas ao provedor; candidata padrão mantém gate de vencimento desligado. Esses testes **não** comprovam integração com rede real, pagamentos ou APK físico.
- LibVLC, ExoPlayer e Chromecast: auditoria do Codex não encontrou nova falha reproduzível; **não** afirmar homologação física com base apenas na revisão de código.
- Scripts de preflight, roteiro físico e procedimento de homologação preparados; isso **não** significa execução do build assinado.

## Pendências únicas — próxima execução autorizada

1. No ambiente privado disponível a partir de 04/11/2026, confirmar Firebase/OAuth da candidata e custódia da chave existente (`candidate.p12`, `signing.json`, sem copiar ao Git/logs). `firebaseProvisioning: pending` permanece até prova contrária.
2. Verificar se ambiente Android SDK/Flutter e scripts de build estão prontos. Executar preparação manual exclusivamente para a candidata, respeitando verificações de branch e identidade.
3. Compilar e assinar APK privado `com.rochaplus.app.candidate`, versão `0.1.0-candidate.1`, versionCode `1`; verificar pacote, ABI, versão, SHA-1/SHA-256 do certificado aprovado, assinatura apksigner e hash do APK. Não publicar.
4. Instalar apenas no aparelho de teste autorizado e validar login, foco/controle remoto, LibVLC/ExoPlayer, reprodução contínua, Cast/reconexão e trial/expiração com sandbox explicitamente aprovado. Preservar teste físico nº 6 salvo regressão.
5. Registrar modelo do aparelho, evidências, resultados e somente novas falhas reproduzíveis; CI verde não substitui teste físico. Decisão de distribuição exige aprovação separada.

## Política de retomada

- Ler **este consolidado** e `docs/auditoria/2026-10-31-portoes-homologacao-candidata.md` antes de executar tarefas.
- Trabalhar somente nas pendências acima; **não refazer** auditorias, verificações e testes verdes por rotina.
- Registrar no fim de cada etapa: data, branch, commits, CI com links e resultados, evidência, status 🟢/🟡/🔴, bloqueios e próximo passo. Não afirmar persistência sem commit.
- Nunca modificar visual aprovado, remover canais sem evidência, misturar Office/TV, executar pagamento real, alterar Oficial, fazer deploy ou publicar sem autorização específica.


## Retomada WORK — 31/10/2026: disponibilidade do ambiente

- 🟢 Leitura obrigatória deste consolidado e dos portões concluída. HEAD observado antes deste registro: `47dc3f6ecba1e537e775468656d77fee205a372b`. [Comparação com o merge autorizado](https://github.com/japarocha2-cloud/rocha-plus/compare/f30457c9c75b475b12212b510841180f30beceec...47dc3f6ecba1e537e775468656d77fee205a372b): somente este consolidado foi adicionado; nenhuma alteração de código nesse intervalo.
- 🟢 Testes verdes e teste físico nº 6 preservados, sem reexecução. Permanecem como evidências históricas os CIs [Identity Guards](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41221538520), [Subscription safety](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41221538508) e [Trial sandbox](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41222167987); esta retomada não disparou CI.
- 🟡 Identidade pública conferida nos arquivos da candidata: projeto esperado `rocha-plus-candidate`, pacote `com.rochaplus.app.candidate`, alias esperado `rocha-candidate-20261028`; certificado aprovado SHA-1 `e2f0e4efa910b18b93fce60e9944f7ddf48ee02b`, SHA-256 `1103e22ab107a77ad3e6ef8b0d327e44240b91b9a4c0bbbad2d258185e0c696b`. Isto não confirma configuração Firebase/OAuth real nem posse da chave.
- 🔴 Ambiente privado não localizado nesta sessão Windows. O README registra custódia anterior em `/workspace/rocha-candidate-private`; esse caminho e `C:\workspace\rocha-candidate-private` não estão disponíveis. Busca apenas por nomes em `C:\Users\Administrador\Documents\Codex` não encontrou `candidate.p12` ou `signing.json`. Não concluir perda da chave: o ambiente anterior não está montado/conectado nesta sessão.
- 🔴 Ambiente de compilação indisponível nos locais verificados: `git`, `flutter`, `dart`, `java`, `adb`, `keytool` e `wsl` não resolvidos no PATH; Android SDK não encontrado em `%LOCALAPPDATA%\Android\Sdk`, Flutter não encontrado em `C:\flutter` ou `C:\src\flutter`, diretórios padrão `C:\Program Files\Android` e `C:\Program Files\Java` ausentes. Verificação limitada a PATH e esses caminhos; não comprova ausência em outros locais.
- 🟡 Recursos privados previstos foram informados ao proprietário antes de qualquer leitura: `candidate.p12`, `signing.json`, `google-services.json` na pasta privada externa ao checkout e `keytool`. Nenhum conteúdo privado foi acessado; nenhuma chave gerada, assinatura executada ou configuração Firebase alterada. `firebaseProvisioning: pending` preservado.
- 🔴 APK ainda não compilado, assinado ou verificado. Nenhum hash de APK ou resultado físico disponível. Nenhuma publicação, pagamento real, novo merge ou alteração de Oficial, visual, catálogo ou Office.
- 🟡 Instalação permanece condicionada ao APK privado verificado: pacote/versão `0.1.0-candidate.1` / code `1`, ARM64, apksigner e certificado aprovado, SHA-256 do arquivo; depois identificar modelo/Android e aparelho autorizado antes de selecionar o destino. Não executar instalação enquanto estes portões estiverem pendentes.
- Próximo passo: proprietário indicar como acessar o ambiente privado existente, sem transmitir segredos no chat. Após localização, anunciar caminhos exatos e ferramentas efetivas antes de ler credenciais/assinar; validar custódia e certificado, Firebase/OAuth real, preparar exclusivamente a candidata em checkout isolado e seguir o roteiro físico. A previsão histórica de acesso em 04/11/2026 não foi tratada como prova de disponibilidade atual.


## Busca do ambiente anterior e recuperação segura — 31/10/2026

- 🟡 A pedido do proprietário, buscou-se o ambiente anterior antes de solicitar recuperação dos arquivos. Consultados chats anteriores pelos mecanismos de histórico do aplicativo: “Auditar candidata Rocha+ TV” (`01a192db-9ef2-7ea1-9d73-b3a0874832f3`) confirma apenas referência histórica à pasta e custódia não verificada; “Homologação experimental Rocha+”, “Relatório de homologação Rocha+” e “Relatório de plantão Rocha+” descrevem LAB e não fornecem custódia da chave candidata. Não reutilizar certificados/configuração LAB.
- 🔴 A referência “Plantão Rocha Plus” (`6ae18e2e-571c-83e8-b53d-8e13ba58f733`) encontrada no chat “Investigar pagamentos sandbox Rocha+” não pôde ser aberta: ferramenta retornou ausência de chat legível no host local. Isso não comprova exclusão do ambiente nem perda dos arquivos.
- 🔴 Consulta atual de ambientes salvos de nuvem retornou `environments: []`, sem próxima página. Inventário do aplicativo não apresentou host remoto conectado. Histórico arquivado ChatGPT retornou vazio. Nenhuma ferramenta disponível forneceu acesso ao filesystem do antigo `/workspace`; não foi possível inspecionar seu conteúdo ou backups.
- 🟡 Busca adicional apenas por nomes em Desktop, Downloads e OneDrive, quando presentes, não retornou `candidate.p12`, `signing.json`, `google-services.json` nem arquivos com nomes combinando Rocha/candidate e backup/private. A busca anterior em Documents/Codex também não encontrou chave/metadados. Raízes de filesystem apresentadas: C: e D:; enumeração de diretórios de D: não retornou itens. Essas buscas não abrangem backups desconectados nem comprovam inexistência de cópia segura.
- 🔴 Bloqueio mantido: recuperar acesso ao ambiente original ou backup privado existente. Nenhum conteúdo de credencial foi lido, nenhuma chave criada/substituída, nenhum teste verde repetido, APK assinado/publicado ou alteração oficial efetuada.
- Arquivos exatos necessários: (1) `candidate.p12` original, contendo a chave privada do certificado aprovado; (2) `signing.json` correspondente, contendo alias `rocha-candidate-20261028` e senha existente; (3) `google-services.json` real do projeto `rocha-plus-candidate`, para `com.rochaplus.app.candidate`. O terceiro pode ser obtido novamente do console autorizado do mesmo app se nunca foi provisionado/exportado; não comprova recuperação da chave e não deve ser inventado. Não são necessários credenciais de pagamentos, certificado Oficial/LAB ou conta de serviço para recuperar esses arquivos.
- Disponibilização segura: preferir reabrir o ambiente original e confirmar, sem exibir conteúdo, a existência da pasta. Se houver backup, o responsável restaura os arquivos originais por transferência autenticada/cifrada para pasta privada fora de qualquer checkout, em Linux compatível com os scripts; diretório 700, arquivos 600, proprietário autorizado, sem links simbólicos. Não enviar arquivos/senha no chat, Git, PR, logs ou artifacts; informar somente ambiente e caminho. Não criar a pasta dentro de outputs do chat. Preservar o backup original.
- Após disponibilização, anunciar caminhos e ferramentas exatos antes de ler credenciais. Validar o certificado existente contra ambas as impressões aprovadas antes de qualquer build. Se faltar `signing.json`, recuperar a senha existente do cofre/backup autorizado e restaurar o metadado correspondente; não trocar senha/alias ou gerar certificado para contornar. Sem a chave original e senha, manter assinatura bloqueada e registrar decisão separada do proprietário.
