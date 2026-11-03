# Roku LAB 0.6.8 — pacote para sideload físico, acesso desativado

Base confirmada67e6e839b6f2cfeebc50123adb64e0744a5e1040, branch exclusiva lab/roku-visual-covers-performance-20261102. Novo pacote gerado a pedido do proprietário; nenhuma instalação remota ou alteração de TV/BRS executada.

Arquivo: RochaPlus-Roku-LAB-0.6.8-TV-REAL-ACESSO-DESATIVADO-20261103.zip
Caminho persistente: artifacts/roku-lab/20261103/RochaPlus-Roku-LAB-0.6.8-TV-REAL-ACESSO-DESATIVADO-20261103.zip
Versão manifest/rodapé:0.6.8
Tamanho:4.538.311bytes,574arquivos
SHA256:00c3a2c6c8cea91958e11a4cf82fdecc1ff177bd4566431dc2a08f8636de1305

## Conteúdo e delta

Em relação ao ZIP0.6.7, apenas quatro arquivos diferentes, nenhum removido: GalleryBrowser.brs com correção já validada do recorte/janela de categorias; HomeScene.xml só rodapé0.6.8; manifest build_version8; config/auth.json enabledfalse explicitamente. auth antestrue com endpoints vazios e sem ser alcançado no modoLAB; agora também falso por defesa explícita. Demais config central/LAB false e endpoints vazios, mode account_homologation preservado. Nenhuma reativação de2h.

Carrossel preserva dimensões/artes/ordem e mostra a próxima carta parcialmente à direita, mantendo a selecionada inteira ao deslocar janela. Não foi acrescentado efeito de carta parcial à esquerda. Conteúdo Home/galáxia/logo/banner/menu, lista vertical, capas, busca, favoritos, PET, prévia, fullscreen e Back está no código existente. Acesso desativado impede exercitar a maior parte disso na TV; inclusão noZIP não é aprovação de comportamento físico.

607registros de catálogo byte-idênticos,578associações de capa/534texturas válidas e preservadas.29capaspendentes continuam conforme docs/roku/technical-followup-20261102/pending-covers.csv. Fonte finalC6 ainda não comprovada; nenhuma remoção, restauração ou reconstrução. Código de favoritos/sessões/temporizador byte-idêntico. Artes e todas as imagens incluídas byte-idênticas aoZIPanterior.

## Validação

13verificações direcionadas aprovadas, zero falhas finais: raiz manifest/source/main.brs sem pastaenvoltória; CRC de574entradas;0.6.7 preservado porhash; versão/rodapé; deltaexato4arquivos;607registros;578mapas/534texturas; artes e exclusão de cartasprovisórias; JSONs; flagsfalse/endpoints vazios; lógica de dados intacta; caminhos/segredos; recursos ativos; sintaxe dos8BrightScript e XMLHomeScene57IDs únicos. Detalhes em validation.json e runner tests/roku-visual/physical-package-068.test.mjs.

Todos os574arquivos fonte do pacote anterior foram mantidos; build usa excludeProvisionalCovers:true e onlyMappedLogoFiles:true. Catálogo inclui campos históricos de capa que o runtime ignora; validar esses campos como referências ativas causou uma falha inicial do validador. O runtime usa cover-map.json e todas as578associações desse mapa foram verificadas. Metadado histórico LAB-REVISAO-IMAGENS.json foi inspecionado e permitido explicitamente, inalterado. Esses ajustes são do validador, não correções de catálogo.

Segredos: nenhum arquivoAdmin/chaveprivada/env/rawregistry/pagamento ou grant privado incluído; padrões de tokens administrativos e campos de sessão preenchidos não encontrados. Foram encontrados dois usos do mesmo tipo de JWT de entrega de vídeo, restritos ao campoURLHTTPS dos dois catálogos históricos byte-idênticos ao0.6.7. Claims não são FirebaseUID/email/token de identidade; valores não publicados no relatório. Não foram introduzidos nem removidos do catálogo. Scanner passou com essa exceção estreita verificada, sem alegar detecção universal de qualquer segredo. O pacote já contém URLs do catálogo existente, como antes.

41checks de carrossel/player/foco do engineheadless já aprovados na etapa anterior preservados; GalleryBrowser idêntico à base67e6e8 verificada porGitblob. Não repetidos porque nenhuma lógica desse arquivo mudou agora.64backend/36Android e CI anteriores também não repetidos. Não há CI novo obrigatório configurado para o builderlocal; testes locais específicos estão anexados. Nenhuma execução física, áudio, RAM, FPS ou reprodução aprovada.

## Instalação manual — somente após autorização posterior para substituir o dev

Fonte oficial consultada: https://developer.roku.com/dev/docs/developer-setup . Não executar ações naTV automaticamente. A Roku tem um aplicativo de desenvolvimento por vez: confirmar que o dev existente é exclusivamente oLAB autorizado antes de substituir; se for outro aplicativo/Oficial, não prosseguir nessaTV.

1. Baixar ZIP sem descompactar e compararSHA256. NoWindows: Get-FileHash -Algorithm SHA256 -LiteralPath 'CAMINHO_DO_ZIP'.
2. Se necessário e autorizado pelo proprietário, habilitar DeveloperMode pelo controle: Home3x, Up2x, Right, Left, Right, Left, Right; seguir Enable installer/restart e guardar a senha apenas localmente.
3. No computador na mesma rede, abrir o endereço local mostrado pelaTV. Entrar como rokudev com a senha definida no próprio aparelho; não enviar senha aochat.
4. No Development Application Installer selecionar Upload e esseZIP, depois Install/Replace conforme interface. NoBRS a ação pode se chamar Replace with ZIP. Não selecionar Delete, limpar dados, resetar ou reinstalar outros canais.
5. Confirmar versão0.6.8 no dev/rodapé. Quando ECP acessível e permitido, consultar /query/apps e /query/active-app. Preservar favoritos e registros; não foi testado que essaTV conservará dados aoReplace, portanto registrar estado antes/depois sem prometer preservação física não observada.

## Checklist físico desta entrega

- NÃOEXECUTADO: upload/aceitação no instalador, identificação0.6.8 e abertura/fechamento sem crash.
- NÃOEXECUTADO: logo/galáxia/banner e Home ao fundo do aviso; legibilidade/escala naTV.
- NÃOEXECUTADO: mensagem de acessoLAB não configurado; Down/OK não devem liberar; Back deve sair.
- NÃOEXECUTADO: reabrir e conferir dados/favoritos/temporizador preservados, sem qualquer limpeza.
- BLOQUEADO por configuração: menu interno, carrossel navegável, lista/capas de canais, busca/PET/favoritos funcionais, prévia, fullscreen e imagem/áudio de canais.
- NÃOEXECUTADO: FPS/RAM/áudio, sessão longa, rede e sincronização de parada física do stream. Não usar FPSzero doBRS como medição.

O pacote é ZIPRoku estruturalmente apropriado para sideload, não pacote comercialassinado nem prova de instalação em todos osfirmwares. Aceitação real depende do aparelho e só será comprovada no teste autorizado. Para liberar navegação/reprodução ainda faltam host/origemTLS confiável, acessoLAB/IAM comprovado e autorização exata de homologação. Não contornar autenticação para validar o carrossel. Roteiro cruzado24casos permanece em docs/central-rights/20261103-readiness/CROSS-PLATFORM-HOMOLOGATION.md.

## Reproduzir o build

ComNode e fonte desta branch, chamar build de tools/roku_visual_lab.mjs com source platforms/roku-lab-visual e flags {excludeProvisionalCovers:true,onlyMappedLogoFiles:true}. Rodar validatePhysicalPackage com zipPath, previousZip0.6.7 e asar local doBRS. O engine não é incluído noZIP. Fonte local conferida com árvoreGit67e6e8 antes da alteração de versão/config; nenhum arquivo não verificado agregado.

ZIP0.6.7 original permanece no commit572733db6f9d99f4b64f59d40f28d3602b4f89ac, SHA2566ff88bbf99786163a6de80eeb18c985557ea2a68441c102d114e26ab34f3cd07. Sem merge, deploy/publicação comercial, alteraçãoAndroid/Oficial/C6/LAB714/site/direitos ou pagamentos. O novo artefato só é persistido na branchLAB conforme ordem.
