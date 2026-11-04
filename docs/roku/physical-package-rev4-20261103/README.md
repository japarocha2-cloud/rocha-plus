# Roku LAB 0.6.10 REV4 — catálogo completo para homologação física

Data: 03/11/2026 (BRT). Branch exclusiva: lab/roku-0.6.10-google-activation-admin-20261103. Base: REV3 visual-only.

## Escopo e situação

REV4 mantém os 607 registros do catálogo integrado disponíveis para navegação e avaliação. A leitura encontrou 607 IDs únicos e nomes presentes; 599 URLs têm indicação de HLS (.m3u8) e 8 URLs não terminam/incluem essa extensão. Nenhum registro marcado blocked/quarantined. O loader foi alterado para não filtrar por protocolo/formato ou status técnico: os 607 registros ficam navegáveis; os 8 formatos distintos não estão declarados reproduzíveis. Categorias, ordem, nomes, capas, busca e favoritos são preservados.

A evidência de autorização física encontrada no repositório continua vazia. Portanto **0/607 canais têm permissão de playback verificável** nesta revisão. Todos ficam visíveis com indicação “AUTORIZAÇÃO PENDENTE”; prévia e Assistir não iniciam streams. O CSV [dos 607 canais bloqueados](blocked-playback-channels.csv) registra ID, nome, grupo, formato indicado e evidência faltante. Aprovação técnica anterior não é autorização de distribuição.

## Avaliação e exportação

- Opção inicialmente focada: **Aprovar (padrão)**. Isso é uma ação de avaliação; canal sem sessão manual continua como “não avaliado”.
- **Reprovar** registra a avaliação técnica, sem esconder nem apagar o canal.
- Campos individuais: imagem, áudio, travamentos e controle remoto; estados não testado, aprovado, reprovado ou bloqueado.
- Botão vermelho abre confirmação para **Remover do LAB**. É uma remoção lógica local, não altera o catálogo de origem. Tecla Play alterna a visualização dos removidos; “Restaurar canal/avaliação” torna o canal visível novamente.
- O relatório JSON/CSV inclui os 607 registros, decisão, resultados físicos e razão de bloqueio de playback. O console imprime blocos entre ROCHAPLUS_PHYSICAL_REVIEW_JSON_BEGIN/END e ROCHAPLUS_PHYSICAL_REVIEW_CSV_BEGIN/END para salvamento pelo BRS/Developer Console.
- Decisão técnica não concede direitos.

## Direitos, CI e limites

Auth, central, acesso comercial LAB e escrita de direitos seguem desligados. Allowlist física: **0 canais**. Podem ser testados a UI, capas, navegação, busca, favoritos, marcação dos resultados e persistência local. Playback, áudio e imagem de canal são BLOQUEADOS pela falta de permissão documentada. Nenhum canal pode ser enumerado como autorizado; a matriz CSV lista os 607 impedidos e a evidência faltante (origem/licença, referência, plataforma Roku/teste físico, validade, revisor).

A workflow CI valida: 607 registros elegíveis e IDs únicos, 578 associações, avaliação/exportação, remoção confirmada e reversível, allowlist vazia, gates do player, manifesto/CRC/estrutura ZIP e ausência de segredos. Primeiro CI REV4 falhou corretamente ao encontrar apenas 599 formatos HLS. Loader corrigido para listar os 607, independentemente de extensão, mantendo playback bloqueado. O workflow será executado novamente; tamanho/hash/link serão registrados somente após CI verde.

## Roteiro físico

Developer Mode → Replace with ZIP. Navegue pela Home, TV ao Vivo e categorias; percorra as 607 posições; confira nome/capa e badge de autorização. Em cada canal, Options/asterisco abre avaliação: marque resultados apenas após observação; use Remover somente na caixa de confirmação. Play alterna a auditoria de removidos. Gere o relatório pelo item de check-up e salve a saída entre os marcadores no Developer Console/BRS. Teste setas, OK, Voltar e persistência ao reabrir. **Não tente reproduzir streams nesta revisão**; não há canal autorizado.

## Fontes

- [Branch LAB](https://github.com/japarocha2-cloud/rocha-plus/tree/lab/roku-0.6.10-google-activation-admin-20261103)
- [REV3 anterior](../physical-package-rev3-20261103/README.md)
- [Requisitos de evidência](../../../experiments/roku-readiness/physical-channel-lab.example.json)

### Correção do primeiro CI

[Run 41748923411](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41748923411) falhou na asserção “all records navigable”: 599 de 607 têm .m3u8; oito têm outros formatos/endpoints. Os 12 fixtures de acesso passaram (12/0). Nenhum artefato foi publicado. O código removeu o filtro .m3u8/blocked/quarantined exclusivamente do carregamento de lista e valida apenas ID/nome únicos; playback continua negado no LAB visual. O CSV agora registra media_format_hint para cada ID. CI será reexecutado após a correção.


## Resultado final do build REV4 — CI verde

- Correção após [run falho 41748923411](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41748923411): o catálogo tinha 599 URLs com indicação .m3u8 e 8 URLs de outro formato/sem extensão HLS. A nova função loadLabCatalogue carrega todos os 607 por ID/nome, sem filtrar extensão, blocked ou quarantined; os registros não-HLS seguem sem alegação de reprodução.
- Código: [commit 3b1a298](https://github.com/japarocha2-cloud/rocha-plus/commit/3b1a298b30edb909590a64ab43648f68b281ecd7). CI [run 41749313776 — success](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41749313776); 12/12 fixtures passaram, build/ZIP/CRC e asserts de 607 IDs, estados da avaliação, export, visibilidade, 578 capas, allowlist vazia e segredos passaram.
- ZIP: RochaPlus-Roku-LAB-0.6.10-REV4-CATALOGO-607-PLAYBACK-BLOQUEADO.zip; tamanho **4.540.470 bytes**; SHA-256 **f9b360696642d76494adff76ec9348f458797321e9cbdfc11fcbb25a7316f616**. 574 arquivos, catálogo 607, associações de capas 578, zero secrets detectados.
- [Baixar ZIP REV4](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41749313776/artifacts/13284568186) — artefato 13284568186, Actions archive 4.463.170 bytes, digest externo SHA-256 5ce05e08496b5eb55e69cb270d1df9a49780d5d5c4561d48759f42370721fe0d, expira em 04/12/2026 UTC. Download pelo GitHub Actions verificado disponível; exige acesso à conta GitHub.
- Direitos: allowlist documentada **0/607**. O CSV [blocked-playback-channels.csv](blocked-playback-channels.csv) enumera cada ID/nome/grupo, indicação HLS (599) ou outro formato (8), e campos de evidência de permissão ausentes. Nenhuma prévia, intro ou reprodução de canal é permitida nesta build.
- Interface: BRS Desktop/TV física não foi executado nesta etapa. Teste físico real, áudio/vídeo, latência e controle precisam ser preenchidos pela execução na Roku com Developer Mode. A função de registro e exportação está no ZIP, mas CI não substitui esse teste. Não marcar campos como aprovados antes da observação física.

Arquivo de plantão atualizado no commit documental seguinte. Sem merge/deploy/publicação e sem alteração de comercial, Android, Roku oficial ou dados originais.
