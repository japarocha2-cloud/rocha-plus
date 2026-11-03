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
