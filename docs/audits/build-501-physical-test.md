# Rocha+ — auditoria da Build #501 e teste físico geral

Data da auditoria: 13/10/2026. Estado: **candidato a teste; não aprovado para lançamento**.

## Base efetivamente conferida

- Repositório: `japarocha2-cloud/rocha-plus`.
- Branch: `fix/favoritos-capas-canais-20261013`.
- HEAD no início da auditoria e commit do APK: `2b9255514bffc93f1b418dd07596e08c1b735689`.
- [Run #501](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/38463549672): completed/success, tentativa 1.
- [Artefato universal 11848751275](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/38463549672/artifacts/11848751275): `rocha-plus-beta-login-universal`, não expirado na consulta.
- ZIP SHA-256: `5f9992c353569defa2078e82c6953e3fa5489a4e778c3ceb65519fb30a225687`.
- APK SHA-256: `2e38343f2e17534b1570dd3d7abca686740bae9a09295ecb77970c3ea2c43481`; 65.369.314 bytes. Ambos conferidos nos bytes baixados e coincidem com as evidências de Actions.
- APK: `com.rochaplus.app`, versionCode 501, versionName 0.1.0, Android mínimo API 24.
- Certificado SHA-256: `8c83b088b0964d7e8bc81b32562e9191f319e0d58cffaa1e5f27f7567b919d22`.
- Assinatura v2: assinatura RSA/SHA-256 e digest de conteúdo do APK verificados criptograficamente; certificado corresponde à chave pública do signer. Não há v1/v3. Falta comparar o certificado com a identidade de produção esperada e os SHAs cadastrados no Firebase.
- Firebase configurado no release-evidence; App ID Android esperado encontrado também no binário ARM64. Isso não comprova funcionamento do provedor, cadastro de SHA nem autenticação real.

A documentação histórica `docs/candidate-validation.md` descreve builds anteriores e contém informações antigas de login e favoritos. Para esta auditoria, vale o código do commit acima e o APK #501. Nenhum APK antigo foi usado como base ou gerado.

## Evidências e limites

CI #501: configuração Android, Quality Guard, flutter analyze, flutter test (100 testes aprovados no log do job), builds universal/ARM64/AAB e release evidence concluíram com sucesso. Os testes Dart incluem mocks de autenticação, armazenamento e HTTP e verificações de widgets; não são teste físico nem varredura de canais reais. Nesta auditoria, os quatro testes Python de configuração/assinatura e o Quality Guard foram executados novamente e passaram. Flutter e aparelho/ADB não estavam disponíveis nesta sessão; nenhum teste Dart local ou físico novo foi declarado executado.

## Achados que impedem aprovação geral

1. **Catálogo não atende à regra exigida.** `lib/src/live/channel_repository.dart` carrega os diretórios Brasil e Sports do iptv-org e admite automaticamente URLs HTTPS não bloqueadas. `_lastKnownGoodCache` significa carga bem-sucedida do diretório, não canal validado. Não existe lista de aprovação por canal/URL com evidência física. HEAD acessível também não comprova vídeo/áudio.
2. **Falha pode voltar após reinício.** `reportPlaybackFailure` usa conjunto apenas em memória. A lista histórica fixa por nome e os canais ocultos pelo usuário persistem, mas a quarentena do player não. Restaurar canais ocultos limpa os bloqueios locais explicitamente. Atualização de URL ou nome pode introduzir fonte nova sem aprovação.
3. **Favoritos são locais por conta.** Há separação por UID, gravação com confirmação e teste automatizado de isolamento. Não há sincronização em nuvem; desinstalar/limpar dados pode remover as listas. A identidade usa URL: troca de URL no diretório pode deixar favorito sem correspondência. Falta teste físico A → B → A e reinício.
4. **Player não comprova áudio/imagem por telemetria.** `PlaybackEvidence` aceita posição avançando fora de buffering. Isso não prova quadros visíveis, áudio audível/sincronizado nem estabilidade. Cast exige sessão e PLAYING da mídia solicitada; ainda depende de observação na TV.
5. **Assinaturas são checkout externo.** Os preços e destinos estão corretos no código e os dois links estão presentes no binário ARM64. Não há backend/webhook ou entitlement implementado nessa tela para reconhecer pagamento. O beta permite acesso gratuito após login. Os 7 dias aparecem como texto; não há contagem ou expiração do período implementada.
6. **Segurança tem verificações parciais.** Manifest do APK: debuggable ausente (padrão false), usesCleartextTraffic=false. Não foram encontrados arquivos .jks/.keystore/.p12/.pem/.env/key.properties/service-account.json, marcadores de chave privada, credenciais GitHub ou identificador AWS pesquisados nas entradas do APK. Isso não prova ausência absoluta de segredos. Configuração pública Firebase/OAuth é esperada em cliente móvel e não deve ser confundida com chave privada. Manifest não define allowBackup (padrão true); revisar backup dos dados locais e sessão. Não foi auditada configuração remota Firebase/restrições de API/regras de backend nesta sessão.

Não preencher uma lista de aprovados com todos os canais do diretório. Não apagar canais previamente aprovados sem identificar suas fontes e evidências. A correção do catálogo precisa usar um registro explícito de fontes aprovadas e reprovações persistentes, com revisão manual para URL nova; falta esse registro no repositório. A #501 pode ser usada para diagnóstico físico, mas não pode ser apresentada como catálogo já aprovado.

## Matriz dos 16 itens

| Item | Evidência no código/automação da #501 | Verificação física pendente / critério |
| --- | --- | --- |
| 1. Login Firebase | Inicialização Firebase; Google idToken → credential; acesso depende de accountChanges; troca de UID reinicia navegação | Entrar em conta real, cancelar seletor, reiniciar, sair, entrar na segunda conta; não abrir conteúdo sem sessão |
| 2. Favoritos por conta | SharedPreferences em chave por UID; mocks A/B; UID passado à Home/Live/Notícias | A marca dois canais; force stop/reabre; B não vê A; B marca outro; A recupera apenas os seus; remover e reiniciar |
| 3. Capas/fallbacks | Image.network com fallback durante carregamento, erro ou ausência; capa local com nome | Logos reais, nome legível e fallback em erro de imagem; conferir Home, catálogo e lista |
| 4. Catálogo válido | Parser HTTPS e blocklist; admissão de fontes sem validação é bloqueador | Inventariar URLs exatas; validar cada canal; quebrado/não validado fica fora do catálogo aprovado; atualizar/reiniciar não deve recolocar |
| 5. Vídeo/áudio/estabilidade | video_player; retry; erro/quarentena; posição avança | Vídeo visível + áudio audível/sincronizado; 5 min por canal, 30 min nos principais; registrar travamentos e rede |
| 6. Fullscreen | Landscape/immersive; PopScope; restauração de orientação; testes de viewport | Entrar/sair 5 vezes, girar aparelho, voltar sai primeiro do fullscreen; vídeo sem corte, controles acessíveis |
| 7. Cast/espelhamento | Google Cast com busca, confirmação de mídia e fallback HLS local | Mesma Wi-Fi: descobrir, conectar, vídeo+áudio na TV, trocar canal, pausar, volume, desconectar, retomar; repetir com app em segundo plano |
| 8. Sports | Categoria/ordenação e blocklist; diretório internacional adicional | Cada fonte aprovada reproduz; categoria correta e sem canais reprovados; não presumir jogo/evento disponível |
| 9. Infantil | Mapeamento Kids/Children/Animation; rota e estados vazios | Conferir conteúdo real e adequação de cada fonte; tag de diretório não basta; busca/voltar |
| 10. Notícias | NewsScreen abre LiveTvScreen em Notícias, com UID | Conferir identidade, conteúdo, vídeo/áudio e navegação por fonte |
| 11. Navegação | Rotas Home/categorias/lista/menu/busca; testes de widgets/foco | Todos os botões, busca, atualizar, voltar, troca rápida de telas e logout dentro de rota; repetir com controle remoto |
| 12. Assinaturas | Rota no menu; tela rolável e responsiva | Abrir, ler, rolar e voltar em celular e TV; sem overflow; botão acessível por controle |
| 13. Mensal | R$ 4,90 → https://mpago.la/2E7yjF4, launchUrl externo | Tocar; conferir destino final, valor e beneficiário; voltar ao app; não efetuar compra na auditoria |
| 14. Anual | R$ 55,00 → https://mpago.la/2b9hitF, launchUrl externo | Mesmo teste, no destino anual; não efetuar compra na auditoria |
| 15. 7 dias grátis | Texto em ambos os planos | Texto visível e legível; registrar separadamente que prazo/ativação comercial ainda não estão implementados |
| 16. Segurança/assinatura | Hashes e assinatura v2 conferidos; manifest; varredura limitada | Atualizar preservando dados; comparar certificado da versão instalada e cadastro Firebase; não divulgar tokens/logins nos registros |

Cast aqui é transmissão da mídia ao receiver; não foi encontrada implementação de espelhamento integral da tela. Teste de espelhamento pelo sistema deve ser registrado separadamente. Pareamento Roku depende de endpoint configurado e não equivale a Google Cast nem prova reprodução na Roku.

## Execução física preparada

1. Registrar modelo, Android, build 501, tipo de instalação (atualização/limpa), Wi-Fi/operadora, TV/receiver e horário. Confirmar o arquivo pelo SHA acima. Preferir atualização; não desinstalar nem limpar dados para resolver erro de assinatura antes de guardar o estado do teste.
2. Executar login e ciclo de contas/favoritos. Registrar contas como A/B, sem e-mail, senha ou token.
3. Inventariar o catálogo visto nessa execução, com nome, categoria e URL exata. Diretórios remotos mudam mesmo mantendo APK. Só transportar para a lista aprovada os canais com evidência completa; não restaurar reprovados automaticamente.
4. Testar todos os canais que permanecerão no catálogo, com vídeo e áudio por 5 minutos. Testar os principais por 30 minutos, depois 20 trocas de canal, pausa/retomada e perda/retorno de rede. Registrar hora de abertura e travamentos. Se não houver áudio ou imagem, marcar reprovado; falha de rede inconclusiva continua não validada.
5. Completar capas, fullscreen, categorias, navegação e TV/controle remoto.
6. Fazer Cast direto e, se acionado, fallback relay; registrar o modo. Testar celular bloqueado/segundo plano por 10 min. Relay precisa do celular ligado na rede e não garante serviço em segundo plano.
7. Conferir tela comercial e ambos os checkouts sem pagamento. Uma página aberta não comprova ativação de plano nem direito a teste grátis.
8. Consolidar resultados; repetir apenas os casos afetados por correção. Nenhum campo pendente vira aprovado por CI verde.

### Registro por cenário

| ID | Aparelho/rede | Passos | Resultado esperado | Resultado observado | Estado | Evidência/horário |
| --- | --- | --- | --- | --- | --- | --- |
| LOGIN-A/B | preencher | entrar/cancelar/sair/trocar/reabrir | sessão correta | preencher | PENDENTE | preencher |
| FAV-A/B/A | preencher | favoritar/reabrir/trocar/remover | listas separadas e persistentes | preencher | PENDENTE | preencher |
| CAPA | preencher | Home/lista/logo falho | nome/capa legíveis | preencher | PENDENTE | preencher |
| PLAYER/FULL | preencher | cada canal + 5/30 min + rotação | vídeo/áudio/estabilidade/fullscreen | preencher | PENDENTE | preencher |
| CAST | preencher | descobrir/conectar/trocar/desconectar/background | mídia correta na TV | preencher | PENDENTE | preencher |
| NAV-CATEG | preencher | Sports/Infantil/Notícias/busca/voltar | categoria e retorno corretos | preencher | PENDENTE | preencher |
| PLANOS | preencher | mensal/anual/voltar | URLs/valores/7 dias corretos | preencher | PENDENTE | preencher |
| CAT-RESTART | preencher | reprovar/atualizar/reiniciar | não recolocar canal reprovado | código já identifica falha de persistência | BLOQUEADOR #501 | requer correção |

### Registro por canal (uma linha por URL)

| Nome | Categoria revisada | URL exata | Data/hora | Aparelho/rede | Vídeo | Áudio/sincronia | Duração | Travamentos | Fullscreen | Cast/receiver | Estado | Evidência |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| preencher | preencher | preencher | preencher | preencher | pendente | pendente | 0 min | pendente | pendente | pendente | NÃO VALIDADO | preencher |

Estados: APROVADO FÍSICO, REPROVADO, NÃO VALIDADO. Cast deve ter estado próprio por receiver; aprovação local não implica aprovação no Cast. URL nova exige revisão. Falha transitória inconclusiva não é aprovação. A lista histórica de bloqueios fica preservada.

## Próximas pendências concretas

- Registrar fontes realmente aprovadas e excluídas com URL e evidência; substituir admissão automática por controle explícito de aprovação; persistir reprovações e exigir revisão para restauração/troca de fonte.
- Executar a matriz física da #501 como diagnóstico, sem alegar catálogo aprovado; resultados alimentam a revisão acima.
- Conferir Firebase/SHAs e certificado esperado; revisar backup Android e escopo das credenciais públicas.
- Testar abertura dos checkouts e fallback em aparelho sem navegador/app compatível; launchUrl atualmente trata false, mas não captura exceção nessa tela.
- Antes de fase comercial, implementar/revisar reconhecimento de pagamento, assinatura e período de teste. Acesso beta grátis não é teste comercial de sete dias.

Esta auditoria acrescenta documentação/evidência à mesma branch. Não muda o código da #501 nem gera novo APK. Alteração posterior terá outro commit e precisará de outro candidato completo antes de aprovação física.

## Retorno físico: instalação recusada no Moto g56 5G

ADB autorizado no PC do usuário mostrou `INSTALL_FAILED_VERSION_DOWNGRADE`: versionCode 501 é inferior ao código 2465 ainda registrado no aparelho. A tela gráfica mostrava apenas pacote inválido. Não é prova de arquivo corrompido. A instalação da #501 falhou; nenhuma aprovação de execução física foi concedida.

Correção na mesma branch: versionCode Android passa a 3000 + número do run, igual para APK universal, ARM64 e AAB. O run de Actions continua com seu próprio número; release-evidence registra ambos separadamente. Preservados o código funcional da #501, package ID, assinatura/Firebase e catálogo. Não usar downgrade forçado, limpeza de dados ou desinstalação adicional como solução. A compatibilidade da assinatura com o pacote 2465 ainda precisa ser testada.
