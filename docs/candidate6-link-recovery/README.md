# Candidata 6 — recuperação de fonte e links (06/11/2026)

## Resultado

Status: **BLOQUEADO antes de qualquer alteração de aplicativo**. Nenhuma fonte verificável nesta sessão identifica o catálogo congelado da Candidata 6 (~430 canais) nem uma lista de links alternativos que tenham sido testados e aprovados pelo proprietário. Não alteramos código, catálogo, URLs, artes, interface, assinatura, Firebase ou dados. Nenhum APK foi compilado.

Branch documental isolada: `work/candidate6-link-recovery-20261106`, baseada em `homolog/technical-candidate-20261028` no commit `3254d0503dd72984682b9080da5d4d21c24f2458`. O objetivo é documentar a recuperação; não é uma branch de APK candidata validada.

## Assinatura original

- O caminho histórico informado é `/workspace/rocha-candidate-private` (arquivos `candidate.p12` e `signing.json`). Essa pasta não está montada no executor Windows atual; `C:\workspace\rocha-candidate-private` também não existe.
- O checkout local acessível não contém esses nomes de arquivo. A busca foi limitada a `C:\Users\Administrador\Documents\ChatGPT\Rocha +` e não encontrou a chave nem o JSON. Não concluí que foram perdidos; o ambiente original não está acessível nesta sessão.
- A tarefa Codex original localizada é **“31/10 homologação”**, ID `01a192ee-41b0-7b92-b20e-d5343c229487`, com diretório de trabalho histórico `C:\Users\Administrador\Documents\Codex\2026-10-31\rocha-tv-work-retomada-da-homologa`. Esse diretório está ausente/não montado no host atual.
- [Commit histórico 6ca4c998](https://github.com/japarocha2-cloud/rocha-plus/commit/6ca4c998373840dd025862b11bba06f54989b6ee) registra que o proprietário informou ter encontrado a chave em 28/10, alias `rocha-candidate-20261028`, e que o certificado correspondia ao assinante público. O próprio registro ressalva que o executor não leu os arquivos nem repetiu keytool.
- [Identidade pública](https://github.com/japarocha2-cloud/rocha-plus/blob/homolog/technical-candidate-20261028/tools/candidate/signer-public.json): SHA-1 `e2f0e4efa910b18b93fce60e9944f7ddf48ee02b`; SHA-256 `1103e22ab107a77ad3e6ef8b0d327e44240b91b9a4c0bbbad2d258185e0c696b`. São impressões públicas esperadas, não prova de posse atual da chave.
- O histórico diz que backup privado cifrado, restauração verificável e disponibilidade no runner continuavam pendentes. Nenhum backup foi encontrado nesta sessão. Não criamos outra chave nem copiamos/expusemos material privado.

## Fonte da Candidata 6 e catálogo

O branch `homolog/technical-candidate-20261028` não contém pasta `catalog/`, APK/AAB, nem snapshot identificado como o catálogo final da Candidata 6. Ele contém o scaffold técnico da identidade candidata e `branding/lab_candidates.json`; esse arquivo de candidatos LAB **não foi usado** como catálogo e não substitui a referência congelada.

A cópia local de `references/android-source` possui sete arquivos de scaffold, inclusive uma cópia de `branding__lab_candidates.json`, e não inclui o APK nem o catálogo aprovado C6. O diretório local de imagens recuperadas contém apenas artes avulsas, sem um manifesto C6 que prove canal, categoria, posição e favoritos. Nenhum desses materiais foi convertido em lista de canais.

A quantidade aproximada de 430 canais é uma referência informada pelo proprietário, não uma fonte de dados recuperada. Não reconstruímos o catálogo, não reclassificamos canais e não usamos os 479 itens LAB.

## Links de transmissão

Não encontramos, na fonte C6 disponível, uma lista por canal dos links quebrados nem um registro verificável dos links alternativos previamente testados/aprovados pelo proprietário. Assim:

- Links modificados: **0**.
- Canais com substituição comprovada: **0**.
- CazéTV: presença, identificador e posição no catálogo original não verificados nesta referência; nenhuma entrada foi criada nem movida.
- Não foi feita sondagem de streams nem inferida aprovação por funcionamento técnico ou por fontes públicas.

## Validação e arquivos

- Arquivos de aplicação alterados: **nenhum**.
- Arquivos de catálogo/links/arte alterados: **nenhum**.
- APK compilada e assinatura validada: **não** — fonte C6 e chave original indisponíveis no executor. Sem binário para apksigner ou hash.
- Testes automatizados de aplicativo: **não executados**, pois não houve mudança de código e o checkout atual é o Roku LAB, não a Candidata 6. Testes Python históricos da identidade não comprovam a compilação C6.
- Teste físico: pendente. Nenhuma aprovação física declarada.

## Próxima ação executável

Restaurar/acessar no host privado autorizado o workspace que contém `/workspace/rocha-candidate-private` e a referência C6, ou disponibilizar um backup autorizado dos arquivos de assinatura e um artefato/snapshot original do catálogo. No ambiente privado, um executor autorizado deve conferir apenas alias e impressão pública com keytool, sem imprimir senha/chave; criar backup cifrado com senha armazenada separadamente e testar restauração antes de encerrar o workspace original.

Para correção de links, fornecer/exportar o manifesto congelado C6 e a tabela de revisão já aprovada que associe cada ID Rocha+ afetado ao link alternativo aprovado. Então fazer uma branch/worktree a partir do commit C6, alterar exclusivamente o campo URL desses IDs, comparar o restante do catálogo byte a byte, compilar para identidade candidata isolada e verificar package/version/signature/hash. Não assinar até a chave original estar acessível. A instalação física continua separada e não deve substituir a Candidata 6 instalada.
