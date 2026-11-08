# P0 Roku LAB — 08/11/2026

Base: dc63e32f466aa843ae2b59d7ced2e4297dbb7577. Branch: lab/p0-roku-20261108.
A ordem P0 autoriza teste físico em LAB sem bloquear o catálogo. Esta ordem substitui o modo visual-only desta base somente no novo pacote experimental; integrações comerciais continuam desativadas.

## Alterações
- Preservados os 607 IDs/registros e decisões existentes, com snapshot anterior e diff; uma entrada CazéTV adicionada em primeiro lugar em Esportes, fonte PR51.
- Globo (ID 8cfb1575ec9cbf69) recebe a fonte de teste do PR51. HISTORY conserva a URL corrigida no commit dc63e32; não houve nova alteração.
- Categoria adicional Não testados consulta ausência de evidência Roku ou de resultado local de áudio e imagem sem remover ou recategorizar os registros originais. Não altera aprovações Android da Candidata 6.
- Modo physical_test_manual explicitamente configurado para sideload LAB, sem cobrança/servidor ou expiração de duas horas. Exige auth, central e lab-access desativados. Não cria assinatura, conta ou direito comercial.
- Corrigida chamada inválida trim() no reconhecimento de formato do player, usando String.Trim().
- Capas aprovadas, favoritos persistidos e navegação/Voltar existentes preservados. CazéTV ainda não tem capa local aprovada: não foi criada arte substituta.

## Evidência
BrightScript/SceneGraph: BrighterScript 0.73.8 passou sem erros. Script de fixture do player passou; 12 testes de backend isolado passaram, sem Google real ou gravações em produção. O empacotador verifica os 607 registros anteriores, mudança restrita de Globo, CazéTV primeiro em Esportes, HISTORY, 578 arquivos de capa referenciados, CRC, estrutura e reprodução binária determinística do ZIP.

Artefato: /workspace/artifacts/RochaPlus-Roku-LAB-P0-0.6.11-20261108.zip. SHA e tamanho: package-evidence.json. O snapshot anterior e catalog-diff.json permitem auditoria. O ZIP contém 575 arquivos, catálogo com 608 entradas e 578 associações de capa. A contagem não equivale aos 430 registros Android homologados.

Não houve teste físico, sondagem de URLs nem medição de áudio/imagem. Instalar por sideload e verificar Globo, CazéTV, HISTORY, capas, favoritos e Voltar/Home. Não descrever os demais canais como falhos por falta de teste. Nenhuma versão congelada, pagamento ou aplicativo oficial foi alterado; nenhum merge ou publicação foi realizado.

Reproduzir: node tools/package_roku_p0.mjs. CI: .github/workflows/roku-p0-package.yml. Links e execução remota só são confirmados após push e leitura do resultado.
