# Roku LAB 0.6.10 REV4 — catálogo completo para homologação física

Data: 03/11/2026 (BRT). Branch exclusiva: lab/roku-0.6.10-google-activation-admin-20261103. Base: REV3 visual-only.

## Escopo e situação

REV4 mantém os 607 registros do catálogo integrado disponíveis para navegação e avaliação. A leitura encontrou 607 IDs únicos, nomes presentes, URLs HTTP(S) HLS, nenhum registro marcado blocked/quarantined. Categorias, ordem, nomes, capas, busca e favoritos são preservados.

A evidência de autorização física encontrada no repositório continua vazia. Portanto **0/607 canais têm permissão de playback verificável** nesta revisão. Todos ficam visíveis com indicação “AUTORIZAÇÃO PENDENTE”; prévia e Assistir não iniciam streams. O CSV [dos 607 canais bloqueados](blocked-playback-channels.csv) registra ID, nome, grupo e evidência faltante. Aprovação técnica anterior não é autorização de distribuição.

## Avaliação e exportação

- Opção inicialmente focada: **Aprovar (padrão)**. Isso é uma ação de avaliação; canal sem sessão manual continua como “não avaliado”.
- **Reprovar** registra a avaliação técnica, sem esconder nem apagar o canal.
- Campos individuais: imagem, áudio, travamentos e controle remoto; estados não testado, aprovado, reprovado ou bloqueado.
- Botão vermelho abre confirmação para **Remover do LAB**. É uma remoção lógica local, não altera o catálogo de origem. Tecla Play alterna a visualização dos removidos; “Restaurar canal/avaliação” torna o canal visível novamente.
- O relatório JSON/CSV inclui os 607 registros, decisão, resultados físicos e razão de bloqueio de playback. O console imprime blocos entre ROCHAPLUS_PHYSICAL_REVIEW_JSON_BEGIN/END e ROCHAPLUS_PHYSICAL_REVIEW_CSV_BEGIN/END para salvamento pelo BRS/Developer Console.
- Decisão técnica não concede direitos.

## Direitos, CI e limites

Auth, central, acesso comercial LAB e escrita de direitos seguem desligados. Allowlist física: **0 canais**. Podem ser testados a UI, capas, navegação, busca, favoritos, marcação dos resultados e persistência local. Playback, áudio e imagem de canal são BLOQUEADOS pela falta de permissão documentada. Nenhum canal pode ser enumerado como autorizado; a matriz CSV lista os 607 impedidos e a evidência faltante (origem/licença, referência, plataforma Roku/teste físico, validade, revisor).

A workflow CI valida: 607 registros elegíveis e IDs únicos, 578 associações, avaliação/exportação, remoção confirmada e reversível, allowlist vazia, gates do player, manifesto/CRC/estrutura ZIP e ausência de segredos. O link, tamanho e hash serão registrados após CI verde.

## Roteiro físico

Developer Mode → Replace with ZIP. Navegue pela Home, TV ao Vivo e categorias; percorra as 607 posições; confira nome/capa e badge de autorização. Em cada canal, Options/asterisco abre avaliação: marque resultados apenas após observação; use Remover somente na caixa de confirmação. Play alterna a auditoria de removidos. Gere o relatório pelo item de check-up e salve a saída entre os marcadores no Developer Console/BRS. Teste setas, OK, Voltar e persistência ao reabrir. **Não tente reproduzir streams nesta revisão**; não há canal autorizado.

## Fontes

- [Branch LAB](https://github.com/japarocha2-cloud/rocha-plus/tree/lab/roku-0.6.10-google-activation-admin-20261103)
- [REV3 anterior](../physical-package-rev3-20261103/README.md)
- [Requisitos de evidência](../../../experiments/roku-readiness/physical-channel-lab.example.json)
