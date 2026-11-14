# Candidata 6 — correção restrita de links (06/11/2026)

**NÃO MODIFICAR A APK ORIGINAL CONGELADA.** Referência de governança: issue #49. A branch atual é uma cópia de trabalho, não uma nova APK e não autoriza publicação.

## Substituições autorizadas, sem duplicar canais
- CazéTV: `http://138.204.86.4:8080/CAZE_TV/playlist.m3u8`
- Globo: `http://79.127.238.228:14173/`
- HISTORY: `http://170.83.16.50/HISTORY/index.m3u8`
- TV Rá-Tim-Bum: preferencial `http://170.83.49.66:8083/TVRATIMBUMHD/index.m3u8`; alternativas testadas `http://45.162.64.114/RA_TIM_BUM/index.m3u8` e `http://186.219.52.187/ratimbum/index.m3u8`.

## Limites obrigatórios
Somente substituir URL de entrada existente e identificada inequivocamente. Preservar todos os outros campos e o catálogo inteiro; sem renomear, traduzir, reclassificar, apagar, adicionar ou bloquear canais. Não modificar visual, capas, autenticação, pagamentos, assinaturas, versão oficial ou APK congelada. Não realizar merge, deploy nem publicação. Não assumir que estes links tenham direitos de retransmissão comercial verificados.

## Estado real
A branch foi criada a partir de `lab/cazetv-link-only-20261106`, onde CazéTV, Globo e HISTORY já possuem mapeamento no código-fonte. A entrada TV Rá-Tim-Bum precisa ser localizada na fonte real antes de qualquer patch; **nenhum APK foi compilado ou assinado nesta etapa**. Verificar compatibilidade de pacote e assinatura com o APK congelado antes de sugerir instalação.
