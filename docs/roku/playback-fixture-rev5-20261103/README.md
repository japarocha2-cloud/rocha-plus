# Roku LAB 0.6.10 REV5 — fixture de player

Data: 04/11/2026.

## Alterações

- Tela isolada **Teste do player** com Play, Stop e Voltar, estado/erro do Video node, timeout de 30 segundos e log local limitado aos últimos 20 eventos.
- Fixture usa o sample HLS demonstrativo documentado pela Roku. A fixture é explicitamente marcada como `player_fixture_only`; não libera reprodução do catálogo.
- A configuração `visual_only`, a allowlist vazia e os gates de preview/fullscreen do catálogo permanecem ativos.
- Removida atribuição universal `streamFormat=hls`: formatos explícitos são respeitados; extensões `.m3u8` e `.mp4` podem ser inferidas; formato desconhecido permanece sem classificação.
- Catálogo (607 registros), mapa (578 associações de capas), avaliações, favoritos e categorias verificados no pacote.

## Validação e artefato

- Branch: `lab/roku-0.6.10-google-activation-admin-20261103`
- Commit: [708c2245e2bd0953b75a225b5390bcaa61888b2c](https://github.com/japarocha2-cloud/rocha-plus/commit/708c2245e2bd0953b75a225b5390bcaa61888b2c)
- CI: [run 41761924718 — success](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41761924718)
- Testes: 21 fixture/isolation checks aprovados; 12 testes backend aprovados; estrutura e verificações do ZIP aprovadas.
- Artefato: [RochaPlus-Roku-LAB-0.6.10-REV5-PLAYER-FIXTURE-DIAGNOSTIC.zip](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41761924718/artifacts/13291455577)
- ZIP: 4.542.912 bytes, 575 arquivos.
- SHA-256 do ZIP interno: `8d6bbc7b3b9686bc972915bbf379941ea55e8942a7315b33dc39577358279bb9`.
- SHA-256 do arquivo do artefato Actions: `2a68df7081ff8478da349ecf2967105af4b4d1ea0c5028d5c8c99b35dd13afcc` (4.465.624 bytes).
- CI detectou zero segredos no conteúdo verificado; autenticação e integrações comerciais continuam desativadas.

## BRS Desktop e teste físico

Uma tentativa de abrir/capturar o BRS Desktop foi feita; a captura expirou por timeout. Não houve evidência gráfica utilizável, então instalação e teste manual BRS ficam **NÃO EXECUTADOS**. Sem nova tentativa em loop.

O ZIP é preparado para sideload Roku. Instale em Developer Mode → Replace with ZIP, depois abra Home → **Teste do player**. Use Play, observe o estado/erros, Stop e Voltar. Imagem, áudio, compatibilidade no hardware e controle remoto ainda precisam ser observados na Roku física. O sample testa somente o componente/player Roku; **não testa os 607 streams do catálogo**. Os 607 continuam navegáveis e sem playback autorizado; allowlist continua vazia.

Sem merge, deploy, publicação ou alterações em produção, pagamentos, direitos ou aplicativos oficiais.
