# Investigação técnica — continuidade do Roku LAB — 02/11/2026

Base:07a3f2f3a528d24aa09f4605dd146d99f2ef77d6, branch lab/roku-visual-covers-performance-20261102.

## Catálogo C6 — resultado e limites

- Inventariados todos os 1.442 artefatos ainda listados pela API Actions, em 15 páginas. Nenhum nome identifica Candidata6 ou exportação de remoções01/11. Isto é inventário de metadados, não inspeção dos1.442 conteúdos.
- Enumeradas77 branches; zero tags e zero releases. Investigadas árvores de cinco refs de homologação/candidato/importação/diagnóstico, cinco relatórios e páginas de100 commits do candidato e100da branch de importação. A história do arquivo branding/lab_candidates.json tem um commit em20/10 no ref candidato, sem alteração finalC6.
- Buscas de commits por “Candidata 6”, “remoções” e “372” retornaram vazias. Nenhuma exportação de remoções de01/11 encontrada.
- Inspecionado artefato12691257099, run40405750673,26/10/2026: rocha-lab-catalog. SHA256 a3c6fbb8d5cd807c4e60c7c68da802999783f1e13d6084e50b1a04fb495cd237; source-commit f9689e0b7ef0cdb1e71385ef0ab023025b326525.
- Contém479 candidatos elegíveis e inventário de11.333 URLs únicas (55.005 ocorrências); zero aprovados e zero testados no inventário. É triagem histórica, não catálogo homologadoC6.
- Relatório consolidado31/10 distingue teste físico nº6 congelado de APK candidato ainda pendente; numeração de teste não prova versãoC6.
- Catálogo Roku de607 registros e todos os históricos/exclusões permanecem byte a byte. Não há comparação final confiável C6→Roku sem exportação aprovada.

Evidências:ci-artifacts-all.json, refs-releases-recent-commits.json, historical-ref-paths.json, historical-report-excerpts.json, candidate-commit-history.json, historical-cover-matches.json.
Artefato de origem:[run40405750673](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40405750673/artifacts/12691257099).
APK/arquivos Android não alterados, não reenviados.

## Capas e revisão

Os30pendentes foram cruzados conservadoramente por URL exata/alternativa declarada e nome normalizado com o inventário histórico completo. Novas identidades foram encontradas, mas a maioria dos respectivos logos continuou com403 ou sem logo. Uma imagem original de beIN Sports Haber foi baixada viaHTTPS e conferida visualmente; aplicação ao pacote ainda será registrada na próxima etapa. As577 associações anteriores permanecem intactas.
cover-downloads.json registra resultado de cada download. TLS não foi desabilitado. Não substituir logos indisponíveis nem usar fundo genérico como capa.

## Checkpoint histórico da investigação

No checkpoint79df0398de07968058e585a967587fa183ee0f90, código e ZIP continuavam0.6.4. Investigação persistida; nenhum teste verde repetido. Próximos passos:incorporar apenas a capa validada, verificar integridade das577 associações, gerar ZIP justificado, revisar ciclo de vida e preparar roteiro físico. Nenhum teste físico executado.

## Entrega técnica atual — LAB 0.6.5

Uma capa adicional foi recuperada:beIN Sports Haber, ID d8766cba28a96cfe. Identidade corresponde por URL exata e nome ao inventário histórico; originalJPEG conferido visualmente e preservado em artifacts/roku-lab/20261102/followup/ORIGINAL-beIN-Sports-Haber.jpg. Derivação192x108 sem distorcer, recolorir ou inventar imagem. As577 associações anteriores e bytes das imagens foram preservados; total578 associações/534 texturas e29pendentes.

Novo ZIP justificado somente por essa capa:RochaPlus-Roku-LAB-0.6.5-CAPA-HABER-20261102.zip,4.533.575 bytes,570 arquivos, SHA256 3e9f11df58b01374b09eafe786a47888466906e06f9c8e42693560cdd14089a9. Delta interno:cover-map, manifest e umaPNG; nenhum BRS/XML/catálogo alterado. CRC,14 JSON e578 mapeamentos válidos.

13 testes relacionados aprovados(10identidade/integridade+3preservação/delta/proveniência), zero falhas. Os30 cenários de comportamento anteriores não foram repetidos porque todos os bytes de código permanecem iguais. Runner verify.mjs atualizado para o pacote atual e aceita execução completa futura; followup-artwork.test.mjs contém os3novos controles.

29 pendências atuais:10HTTP403,4HTTP404,3 TLS/DNS,5 identidades históricas sem logo,7sem identidade exata. CSV e pending-30-audit.json mantêm motivo e causa de rede; TLS preservado. O antigo pending-covers.csv de android-sync descreve o estado0.6.4 e não deve ser apagado.

Comparação histórica dos607 registros:420coincidem com os479 candidatos elegíveis do artefato de26/10;187não. A fonteC3 anterior produzia422/185; os snapshots diferem. Nenhum representa a lista finalC6. Consulte historical-catalog-comparison.json.

Revisão de desempenho em performance-review.md:não foi demonstrado defeito novo, nem alegado vazamento ausente. Sem alteração preventiva de lógica ou nova mediçãoFPS/RAM. ROTEIRO-TESTE-FISICO.md e physical-results.csv preparam21 casos, todosNOT_EXECUTED. O0.6.5não foi executado em BRS nativo nem em Roku físico nesta etapa.

Para reproduzir somente mudanças desta etapa, importe runArtworkTests com expected={audited:30, recovered:1, pending:29, mapped:578} e runFollowupTests; veja related-tests.json. Para a execução completa planejada:node tests/roku-visual/verify.mjs "CAMINHO/resources/app.asar". Build usa os mesmos dois flags de exclusão do0.6.4.

ArtefatoCI original4,36MB permanece no workspace persistente references/followup/rocha-lab-catalog-12691257099.zip; metadados, hashes e associações auditadas estão no GitHub. O arquivo bruto contém URLs de streams e não foi republicado; origemCI é referenciada, sem persistir URL temporária assinada. A continuidade do pacote não depende desse arquivo bruto.
