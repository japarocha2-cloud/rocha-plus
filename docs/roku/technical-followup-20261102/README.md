# Investigação técnica — continuidade do Roku LAB — 02/11/2026

Base:07a3f2f3a528d24aa09f4605dd146d99f2ef77d6, branch lab/roku-visual-covers-performance-20261102.

## Catálogo C6 — resultado e limites

- Inventariados todos os 1.442 artefatos ainda listados pela API Actions, em 15 páginas. Nenhum nome identifica Candidata6 ou exportação de remoções01/11. Isto é inventário de metadados, não inspeção dos1.442 conteúdos.
- Enumeradas77branches;zero tags e zero releases. Investigadas árvores de cinco refs de homologação/candidato/importação/diagnóstico, cinco relatórios e páginas de100commits do candidato e100da branch de importação. A história do arquivo branding/lab_candidates.json tem um commit em20/10 no ref candidato, sem alteração finalC6.
- Buscas de commits por “Candidata 6”, “remoções” e “372” retornaram vazias. Nenhuma exportação de remoções de01/11 encontrada.
- Inspecionado artefato12691257099, run40405750673,26/10/2026: rocha-lab-catalog. SHA256 a3c6fbb8d5cd807c4e60c7c68da802999783f1e13d6084e50b1a04fb495cd237;source-commit f9689e0b7ef0cdb1e71385ef0ab023025b326525.
- Contém479candidatos elegíveis e inventário de11.333URLs únicas (55.005ocorrências);zero aprovados e zero testados no inventário. É triagem histórica,não catálogo homologadoC6.
- Relatório consolidado31/10 distingue teste físico nº6 congelado de APK candidato ainda pendente;numeração de teste não prova versãoC6.
- Catálogo Roku de607registros e todos os históricos/exclusões permanecem byte a byte. Não há comparação final confiável C6→Roku sem exportação aprovada.

Evidências:ci-artifacts-all.json,refs-releases-recent-commits.json,historical-ref-paths.json,historical-report-excerpts.json,candidate-commit-history.json,historical-cover-matches.json.
Artefato de origem:[run40405750673](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40405750673/artifacts/12691257099).
APK/arquivos Android não alterados,não reenviados.

## Capas e revisão

Os30pendentes foram cruzados conservadoramente por URL exata/alternativa declarada e nome normalizado com o inventário histórico completo. Novas identidades foram encontradas,mas a maioria dos respectivos logos continuou com403 ou sem logo. Uma imagem original de beIN Sports Haber foi baixada viaHTTPS e conferida visualmente;aplicação ao pacote ainda será registrada na próxima etapa. As577associações anteriores permanecem intactas.
cover-downloads.json registra resultado de cada download. TLS não foi desabilitado. Não substituir logos indisponíveis nem usar fundo genérico como capa.

## Estado deste checkpoint

Código e ZIP continuam0.6.4. Investigação persistida;nenhum teste verde repetido. Próximos passos:incorporar apenas a capa validada,verificar integridade das577associações,gerar ZIP justificado,revisar ciclo de vida e preparar roteiro físico. Nenhum teste físico executado.
