# Rocha+ — finalização experimental e destaques — 26/10/2026

## Decisão do proprietário

Lucas solicitou a retirada da Globo dos destaques por falha de reprodução e, em seguida, acrescentou Record e Band: "deixa só SBT". A mudança é editorial, na branch experimental, e não exclui canais do catálogo ou favoritos nem modifica as referências congeladas.

## Alteração

- A seleção de canais da Home aceita somente SBT, SBT Nacional e SBT Interior na categoria de TV ao Vivo. SBT News e SBT Kids continuam em suas categorias e não entram nesse destaque de sinal aberto.
- A prioridade editorial de TV ao Vivo fica somente com SBT. Os outros canais permanecem acessíveis no catálogo geral.
- A área de canais da Home passa a se chamar "SBT em destaque"; se não houver SBT disponível, direciona ao catálogo, sem promover outro canal automaticamente.
- O carrossel de navegação, a identidade visual, os arquivos de arte, os controles, Firebase, pagamentos e preços permanecem preservados.
- Essa decisão não equivale à homologação audiovisual de cada fonte SBT. Globo segue pendente; não foi marcada como corrigida.

## Estado de finalização

| Área | Situação comprovada e condição restante |
|---|---|
| APK Android experimental | Build assinado 684 aprovado antes desta mudança; exige novo build para entregar os novos destaques. |
| Player | Inicialização até 30s, falhas sem exclusão automática e alternativa manual de player incorporadas no 684; confirmação no aparelho ainda necessária. |
| SBT | FFmpeg de 60/180 segundos concluído, com avisos DTS na rodada prolongada; falta validação ExoPlayer/LibVLC no aparelho. |
| Globo | Proprietário confirmou falha também no congelado; fonte existente recusou acesso. Candidatos do Gist não entregaram HLS no teste. Sem substituição aprovada. |
| Login/Firebase | Pacote .lab e certificado do projeto de homologação conferidos no CI. O retorno genérico "estão funcionando" do proprietário não é convertido em homologação detalhada de autenticação/dados. |
| Sete dias e cobrança | Backend com 30 testes aprovados no ciclo anterior; integração em nuvem e fluxo real de vencimento/pagamento ainda não homologados. O APK de homologação foi gerado com bloqueio de cobrança desativado. |
| Android TV/TV Box/Cast | Rotas de categorias observadas no emulador no build 683. Controles, áudio, Cast e reconexão em equipamentos físicos ainda pendentes. |
| Catálogo e autorizações | Exigir evidências por canal e permissão de distribuição; destaque não significa aprovação. |

Status geral: AMARELO para homologação experimental; lançamento comercial ainda não liberado. Não alterar a versão congelada ou publicar versões sem aprovação.
