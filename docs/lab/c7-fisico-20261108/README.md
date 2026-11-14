# Candidata 7 — correções após teste físico — 08/11/2026

Base: 50fd7fa; branch isolada lab/candidata7-correcao-fisica-20261108. Ordem recebida: corrigir C7, sem tocar C6/Roku/Web TV/financeiro. C6 homologada entre 19–21/10/2026, 180 segundos de áudio/imagem por canal, permanece preservada; sem reaprovação.

## Causas e mudanças
- Entrada real FULL_UI_LAB não usava RochaTheme.dark, causando tema claro e texto escuro em cartões escuros. Novo entrypoint reaproveita exatamente o tema e a introdução Android existentes, sem importar Roku. Banner e assets aprovados intactos.
- A abertura nativa Flutter gerada trazia fundo padrão. Configuração restrita às branches C7 substitui o fundo por preto e usa ícone oficial centralizado com 200dp, cobrindo drawable e drawable-v21; adapta LaunchTheme para Android 12+.
- Menu LAB concentra categorias principais e Minha Lista; categorias adicionais continuam nos cartões da Home. Marca no menu passa de 174 para 104px de altura. Conta sem UID LAB pode abrir Assinatura. A página existente continua somente leitura, sem novo checkout ou cobranças; preços R$7,90/R$86,90 e aviso de até sete dias mantidos.
- Política C7 FULL_UI_LAB mantém CazéTV no primeiro slot de Esportes, sem alterar sua URL/capa e sem reordenar os demais canais. Aplicada ao diretório, cache, refresh e apresentação LAB. Outros modos não recebem essa política.
- Record: inventário recuperável de 11 entradas em record-inventory.json, com nome/URL/categoria/ID derivado porque a fonte não possui ID nativo. Mantidas Record News, Pluto TV Record News, RecordTV Interior SP (alias de Record Interior SP). Oito entradas excluídas somente da lista efetiva C7; snapshots intactos. Nomes semelhantes não reconhecidos como família não são excluídos automaticamente. Diretório remoto grava inventário antes da política em record-c7-inventory.json no diretório local da bridge LAB, quando disponível; falha de gravação não bloqueia teste físico.
- HISTORY e CazéTV aprovados fisicamente: fontes preservadas. Não reabrir sua homologação integral.

## Globo e Rá-Tim-Bum — pendências comprovadas

O mapeamento atual usa Globo http://79.127.238.228:14173/ e Rá-Tim-Bum http://170.83.49.66:8083/TVRATIMBUMHD/index.m3u8. As sondagens desses endereços e das alternativas 45.162.64.114 e 186.219.52.187 retornaram HTTP 403 nesta rede restrita. Não há leitura do payload ou de redirecionamentos para determinar formato. Isso não comprova falha do servidor de origem. Nenhuma URL alternativa foi inventada ou promovida sem validação.

Globo é URL-base sem extensão, não playlist HLS presumida. O player adaptativo consulta preferência medida e, sem preferência, usa Exo; LibVLC pode ser selecionado pela interface. Não foi alterada a escolha de engine por adivinhação. Os hosts atuais constam nas permissões Android revisadas; isso não prova disponibilidade remota. Formato/codec e teste físico de Globo e Rá-Tim-Bum permanecem pendentes. Próxima ação: sondagem em rede com acesso aos quatro endereços, registrar status/Location/Content-Type e amostra de manifesto ou stream; então validar alternativa e testar no aparelho.

## Validação e entrega

Testes novos cobrem entrada LAB real com tema escuro, contraste onSurface/surface, intro, navegação de assinaturas sem UID, preços/aviso, ordem estável CazéTV, filtros Record e preservação dos demais objetos. Teste do diretório efetivo roda explicitamente com ROCHA_FULL_UI_LAB=true; a suíte normal mantém as condições do app normal. Não afirmar inspeção visual física concluída só por esses testes.

Workflow c7-physical-corrections.yml verifica fontes protegidas, análise, suites Python/Flutter e política LAB antes de compilar um único APK. Mantém pacote com.rochaplus.app.labc7 e exige o certificado original SHA-256 5345c8a438838c297ee4925ec732555b8a47295992a188cc1fa53cd5c9e3f796. Mede tamanho exato e SHA-256 do binário em apk-size.json. Como a ABI do aparelho não foi comprovada, mantém APK universal como o testado, sem restringir silenciosamente a ARM64. Não gera AAB, APKs extras, assinatura comercial, merge/deploy/publicação.

Build, CI, tamanho e link do novo artefato só podem ser declarados após confirmação da execução remota. A ordem completa permanece aberta enquanto Globo/Rá-Tim-Bum estiverem bloqueados por falta de evidência técnica e teste físico.
