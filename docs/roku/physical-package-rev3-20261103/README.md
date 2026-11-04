# Roku LAB REV3 — readiness para teste físico

Data: 03/11/2026. Branch: `lab/roku-0.6.10-google-activation-admin-20261103`. Base analisada: `cd27929df00cb868deaadffd1f7cd6d487bf7d24`.

## Resultado

Não foi produzido REV3. A configuração de teste físico não contém IDs de canais aprovados (`approvedForPhysicalTest: []`), não tem endpoint HTTPS isolado e está marcada `readyForEnabledZip:false`. Não existe evidência para conceder reprodução aos 607 canais incluídos.

## Fonte e limites

A configuração `physical-channel-lab.example.json` exige prova de origem, referência de permissão, plataforma permitida, validade e revisor. As integrações auth/LAB/central da REV2 estão desligadas. O modo físico local de duas horas no BrightScript ignora identidade do servidor e habilita a navegação/reprodução global; não foi acionado.

A lista usada pelo Roku é `commercial-lab-merged.json`: 607 itens; 395 têm `approved:false`, 212 não têm campo `approved`, nenhum tem `approved:true`. A rotina de carga atual não filtra `approved`. O arquivo separado `catalog/approved.json` tem 190 itens marcados como estáveis/aprovados em evidência de decodificação; isso não comprova licença ou permissão de reprodução Roku. Não usar esses marcadores como autorização jurídica.

## Última versão preservada

REV2, sem alteração: [CI 41729054117](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41729054117), [commit 2fef125307d9c2e35e9c2d82d1860dbdafb5f3e0](https://github.com/japarocha2-cloud/rocha-plus/commit/2fef125307d9c2e35e9c2d82d1860dbdafb5f3e0), [ZIP](https://raw.githubusercontent.com/japarocha2-cloud/rocha-plus/2fef125307d9c2e35e9c2d82d1860dbdafb5f3e0/artifacts/roku-lab/20261103/RochaPlus-Roku-LAB-0.6.10-ACESSO-DESATIVADO-REV2.zip), 4,538,938 bytes, SHA-256 `d789c6607b0f32bb2629adf9b1082518715c3a624f1e16445972fbf6817ddaa1`. REV2 foi observado no BRS Desktop, mas controles, login e playback não foram validados.

## Próxima ação concreta

Enviar somente a allowlist e referências de permissão (sem segredo), e indicar endpoint de homologação HTTPS já existente. Depois implementar a allowlist como limite server-side e client-side em branch LAB, executar novos testes de inclusão/exclusão/expiração/revogação, empacotar REV3 via Actions, registrar artifact/size/SHA e testar na Roku física.

Nenhuma alteração em código, config, artefato, produção, cobrança, direito, Android ou versão oficial nesta etapa. Nenhum teste foi repetido. Status: **BLOQUEADO para playback; REV2 preservado**.

## Referências verificáveis

- [Config física de exemplo](https://github.com/japarocha2-cloud/rocha-plus/blob/lab/roku-0.6.10-google-activation-admin-20261103/experiments/roku-readiness/physical-channel-lab.example.json)
- [Loader Roku atual](https://github.com/japarocha2-cloud/rocha-plus/blob/lab/roku-0.6.10-google-activation-admin-20261103/platforms/roku-lab-visual/components/HomeScene.brs)
- [Fluxo LAB de homologação](https://github.com/japarocha2-cloud/rocha-plus/blob/lab/roku-0.6.10-google-activation-admin-20261103/platforms/roku-lab-visual/components/LabAccess.brs)
- [Configuração do timer físico](https://github.com/japarocha2-cloud/rocha-plus/blob/lab/roku-0.6.10-google-activation-admin-20261103/platforms/roku-lab-visual/config/physical-lab-access.json)
- [Workflow de empacotamento](https://github.com/japarocha2-cloud/rocha-plus/blob/lab/roku-0.6.10-google-activation-admin-20261103/.github/workflows/roku-0610-package.yml)


### Atualização após resposta do proprietário (03/11/2026)

O proprietário informou que dispõe de uma lista de canais autorizados, mas não forneceu nesta resposta os IDs/nomes, referências de permissão, validade ou responsável pela revisão. Nenhuma allowlist pôde ser comparada ao catálogo/build. Também não indicou endpoint HTTPS de homologação existente; as configurações consultadas continuam sem origem/endpoints.

Não usar o modo local `physical_test_2h` neste ZIP público: ele habilitaria reprodução sem vínculo/verificação do servidor e não oferece limite por identidade. A lista por si só não basta enquanto o runtime não puder autorizar somente IDs aprovados e emitir/revogar sessão LAB. REV3 continua sem build/artefato.


## REV3 — LAB visual, catálogo navegável e reprodução fechada (03/11/2026)

A pedido do proprietário, seguimos com a homologação visual mesmo sem a allowlist de direitos. A revisão do histórico/configuração desta branch não encontrou IDs com referência verificável de autorização física para Roku. Portanto a lista de reprodução permanece vazia: nenhum canal está autorizado para playback neste ZIP. A aprovação técnica de catálogo/decodificação não foi usada como autorização de distribuição.

Foi preparado o modo de acesso **visual_only**, experimental e local ao pacote Roku LAB. Permite abrir a interface e navegar pelo catálogo atual, categorias, busca e favoritos sem afirmar assinatura ou pagamento. Há bloqueios explícitos em fila de prévia, debounce de prévia e início de tela cheia; o modo visual não usa o antigo timer physical_test_2h, não inicia streams e não consulta direitos comerciais. O catálogo de 607 registros e o mapa de 578 capas permanecem inalterados. Os arquivos auth.json, central-access.json e lab-access.json continuam desativados.

### Estado do build e limites

- Novo workflow gera RochaPlus-Roku-LAB-0.6.10-REV3-VISUAL-PLAYBACK-BLOCKED.zip como artefato GitHub Actions; sem merge, deploy ou publicação.
- CI confirma estrutura/CRC, manifesto, 607 itens, 578 associações, 574 arquivos, flags comerciais desligadas, allowlist vazia e os três bloqueios do player. Run/artifact, SHA-256 e tamanho serão acrescentados após a execução confirmada.
- Navegação gráfica/BRS Desktop e instalação em Roku física ainda não foram executados nesta revisão. Áudio, vídeo e reprodução ficam bloqueados intencionalmente; não anunciar teste de mídia aprovado.
- Teste físico da UI pode conferir Home, categorias, lista/capas, busca, favoritos e mensagens de bloqueio. Para playback de mídia é necessária allowlist com IDs e evidência explícita de permissão; atualmente 0 canais.

## Fontes permanentes

- [Branch LAB](https://github.com/japarocha2-cloud/rocha-plus/tree/lab/roku-0.6.10-google-activation-admin-20261103)
- [Account.brs](https://github.com/japarocha2-cloud/rocha-plus/blob/lab/roku-0.6.10-google-activation-admin-20261103/platforms/roku-lab-visual/components/Account.brs)
- [ChannelBrowser.brs](https://github.com/japarocha2-cloud/rocha-plus/blob/lab/roku-0.6.10-google-activation-admin-20261103/platforms/roku-lab-visual/components/ChannelBrowser.brs)
- [Modo LAB visual](https://github.com/japarocha2-cloud/rocha-plus/blob/lab/roku-0.6.10-google-activation-admin-20261103/platforms/roku-lab-visual/config/physical-lab-access.json)
- [Workflow REV3](https://github.com/japarocha2-cloud/rocha-plus/blob/lab/roku-0.6.10-google-activation-admin-20261103/.github/workflows/roku-0610-package.yml)

