# ROCHA+ Roku LAB — Registro de preservação de catálogo (03/11/2026)

## Regra de operação
Este registro protege **decisões históricas**, não atesta direito de distribuição ou funcionamento de streams.

- Catálogo Roku inicial: **395 selecionados**, referência histórica de 31/10.
- Candidata 6 Android: **430 aprovados informados pelo operador**, referência de 01/11.
- Catálogo Roku LAB consolidado: **607 registros de avaliação**, relatório de 03/11.
- Capas encontradas em 02/11: **158**; 449 pendentes no relatório daquele dia.
- **607 não substitui 430**: universos e estados diferentes; não inferir inclusão, exclusão ou aprovação individual pela comparação dessas contagens.
- O operador determinou remoções específicas em 01/11; **não reinterpretar** como reprovação técnica ou jurídica sem registro explícito.

## Estados independentes por canal
1. `operator_decision`: `approved` | `removed` | `unreviewed`.
2. `technical_result`: `passed_on_device` | `failed_on_device` | `not_tested`.
3. `rights_status`: `verified` | `unverified` | `denied`.
4. `catalog_presence`: `included` | `archived`.

Ausência de teste técnico **não significa** falha. Falta de confirmação de autorização **não significa** canal tecnicamente quebrado. Decisão de remover pelo operador só muda com decisão posterior do operador.

## Política contra perda e bloqueios em massa
- Preservar arquivo-fonte e snapshots datados em commits, sem sobrescrever snapshots antigos.
- Antes de importar, fazer backup e comparar IDs e decisões anteriores.
- Nunca eliminar, renomear em lote ou marcar como removidos os canais sem registro individual e justificativa.
- Falta de direitos confirmados pode bloquear **playback/distribuição**, não apagar histórico ou impedir navegação pelo catálogo do LAB.
- Somente reproduzir conteúdo cuja utilização esteja permitida; o teste físico é o que determina resultado técnico, não autorizações presumidas.
- O aplicativo comercial, as assinaturas e o LAB 714 ficam intocados.
- No Roku LAB: manter categorias, ordem, capas existentes, favoritos e decisões de remoção; gerar lista de diferenças antes de importar.
- Se dados originais não estiverem presentes, **não fabricar** IDs, nomes, aprovações ou URLs.

## Critério de aceite antes do próximo ZIP
- Exportar snapshot de cada origem com SHA256 e data, incluindo nomes e IDs de cada canal.
- Produzir `diff` (incluídos, alterados, removidos); nenhuma remoção sem autorização registrada.
- Testar navegação do catálogo independente de playback.
- Apenas depois criar ZIP LAB e realizar teste físico em Roku.
- Registrar falhas reais de áudio, vídeo e carregamento individualmente.

**Situação deste registro:** política versionada em branch LAB isolada. Não atesta que os arquivos de catálogo tenham sido localizados, restaurados ou que o bloqueio de reprodução tenha sido alterado.
