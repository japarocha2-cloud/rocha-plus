# Rocha+ Roku — base compartilhada com #510

Cliente SceneGraph/BrightScript existente reaproveitado. Catálogo e quarentena são cópias exatas da seleção da #510, geradas por `tools/sync_platform_baseline.py`. HTTP e fontes experimentais não são admitidos. Falhas de reprodução ficam excluídas por URL neste aparelho; favoritos são separados pelo UID.

Login por código aprovado no celular. A validade do teste de sete dias e do período pago é consultada no mesmo servidor do Android. Uma conta conectada não equivale a assinatura ativa. Ao expirar o acesso, o player é interrompido e a TV pede assinatura na mesma conta do celular.

As URLs em `config/auth.json` estão vazias até a publicação do servidor. Essa configuração bloqueia acesso, sem modo gratuito automático. Configure com `tools/configure_tv_services.py`, inclusive uma URL HTTPS do vídeo de introdução original. A fonte congelada #510 permanece preservada.

Compilação: `bsc --project platforms/roku/bsconfig.json`. O ZIP gerado é para sideload de desenvolvimento; não é um pacote assinado de loja. Login, vídeo/áudio, controle, favoritos e expiração precisam de teste físico após configuração. Detalhes de ativação em `docs/payments-and-platforms.md`.

## Catálogo de teste — 29/10/2026

A versão 0.6.1 carrega 395 candidatos HTTPS/HLS com detecção audiovisual no
benchmark de 788 URLs (509 positivos). Os 114 positivos restantes permanecem
em revisão por HTTP ou formato não confirmado. Consulte
`docs/auditoria/2026-10-29-roku-catalogo.md`. Não representa homologação Roku.

