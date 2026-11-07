# Suporte 41 — Auditoria administrativa de 22/10/2026

**Estado: AMARELO documental; publicação não liberada.** Inspeção do repositório experimental em `461e62d0be8e73d202a004791944a51a2e2a67b6`, branch `feat/dual-player-lab-20261020`. Nenhum aplicativo, termo oficial, catálogo congelado, branch ou referência oficial foi alterado por esta frente.

## Escopo e limites

Esta é uma auditoria dos arquivos disponíveis no checkout. Não foram consultados correio eletrônico, documentos empresariais privados, consoles de lojas ou contratos externos. Documento não localizado aqui significa **evidência não apresentada nesta auditoria**, não prova de inexistência. Não houve parecer jurídico nem teste físico. O estado técnico VERMELHO de áudio/assinaturas descrito pela coordenação continua independente desta avaliação documental.

## Inventário de evidências

| Item | Evidência localizada | Resultado e próxima entrega |
| --- | --- | --- |
| Autorização de cada canal, marca e logotipo | `README.md`, final; `docs/candidate-validation.md`, seção Administrativo e segurança; `docs/launch-checklist.md`, Conteúdo | Há orientação e pendência declarada, sem comprovantes de concessão no checkout. Contato com TV Morena é descrito como aguardando resposta no documento histórico; não equivale a autorização. Preparar registro por canal: titular, escopo permitido, plataformas, território, prazo, anúncios/cobrança, data e referência privada da autorização. |
| Termos de uso e política de privacidade finais | `docs/launch-checklist.md:12-19` | Itens ainda desmarcados; busca de arquivos e textos não localizou documentos finais ou URLs desses documentos na interface. Preparar textos com dados verificados do responsável, contato e funcionamento atual; submeter à revisão responsável antes de publicação. |
| Atendimento e identidade do produto | `docs/launch-checklist.md:5-10` | Canal de suporte, site e identificação de versão aparecem como itens pendentes. Não preencher CNPJ/documentos ou credenciais no repositório; confirmar informações públicas no canal apropriado. |
| Tratamento/exclusão de dados | `docs/login-setup.md:64`; `lib/src/auth/auth_repository.dart:15-20`; `lib/src/auth/firebase_auth_repository.dart:85-92` | Interface de autenticação expõe saída da sessão, sem operação de exclusão de conta encontrada nesta inspeção. Sair não constitui exclusão. Definir fluxo, verificação de identidade, retenção e consequências antes de prometer exclusão. |
| Assinatura, integridade e rastreio do APK | `tools/release_evidence.py:30-61`; `.github/workflows/build.yml:78-103` | Existe geração de tamanho, SHA-256, commit e evidência para build manual assinada. O script registra `physical_validation: pending`. Existência do mecanismo não comprova que um APK específico está pronto para venda/distribuição. Anexar evidência do artefato exato aprovado posteriormente. |
| Permissões Android | `tools/configure_android.py:16-24`; `tools/release_evidence.py:27-28` | Gerador adiciona INTERNET, ACCESS_NETWORK_STATE, FOREGROUND_SERVICE e FOREGROUND_SERVICE_MEDIA_PLAYBACK. Inventário final deve vir do manifest mesclado do APK exato, incluindo dependências; este checkout não contém scaffold Android materializado. |
| Transporte de mídia | `tools/configure_android.py:37-48`; `tools/release_evidence.py:19-25` | Política base nega HTTP genérico, mas há exceções de hosts revisados. Evitar alegação pública de “todos os dados sempre criptografados” sem avaliar exceções e tráfego real. |
| Publicação por loja/site | `docs/launch-checklist.md:29-48`; `docs/login-setup.md`, orientação sobre artefatos | Checklist de lojas permanece aberto. Prévia sem canais, laboratório e beta com login possuem finalidades distintas; identificar claramente o arquivo de download e seu escopo. Distribuição por site não constitui evidência de conclusão das pendências de conteúdo, segurança ou privacidade. |

## Inventário inicial para elaborar a política de privacidade

Este inventário deriva do código-fonte, sem captura de tráfego. Não é declaração final de Segurança dos dados nem inventário completo dos SDKs.

| Dado/fluxo observado | Evidência | Informação ainda necessária |
| --- | --- | --- |
| UID e nome de exibição da conta Firebase/Google | `lib/src/auth/auth_repository.dart:1-4`; `lib/src/auth/firebase_auth_repository.dart` | Responsável pelo tratamento, finalidades, bases aplicáveis, serviços envolvidos, retenção e processo de exclusão/revogação. |
| Token Firebase enviado como Bearer ao endpoint HTTPS de direitos, quando chamado | `lib/src/auth/subscription_access.dart:9-28` | Endpoint realmente implantado, controle de logs/acesso e retenção do backend; não registrar tokens em relatórios. |
| URLs favoritas em armazenamento local compartilhado do aparelho | `lib/src/live/favorites_repository.dart:4-15` | Validar comportamento por conta/aparelho, limpeza e texto correto da política. A chave observada não inclui UID; não prometer sincronização ou isolamento por conta com base neste arquivo. |
| Contadores locais de impressões/cliques por campanha | `lib/src/ads/ad_metrics_repository.dart:3-24` | Confirmar se alguma integração externa transmite métricas; não foi demonstrado tráfego de telemetria por esta inspeção. |
| Diretórios externos de canais, streams, imagens e receiver Cast | `lib/src/live/channel_repository.dart:14-17`; `docs/candidate-validation.md`, Administrativo e segurança | Identificar fornecedores e endpoints usados no build final, dados de conexão expostos e condições de terceiros. Lista pública de canais não comprova autorização de distribuição. |

## Divergências documentais que impedem usar textos antigos como versão final

- `README.md` descreve uma base inicial, outra paleta e funcionalidades como etapas futuras. Não deve ser utilizado diretamente como ficha comercial atual.
- `docs/candidate-validation.md` é datado de 07/10/2026 e declara Google/Apple sem autenticação, enquanto o código atual contém integração Firebase/Google. Seu conteúdo histórico não comprova o estado atual de login, catálogo ou privacidade.
- `docs/login-setup.md` reúne instruções de diferentes fases e orienta execução em `main`; esta auditoria não executou esse procedimento. A coordenação atual autoriza trabalho apenas experimental.
- `docs/COORDENACAO-20261022.md` registra corretamente que beta sem cobrança não comprova bloqueio de inadimplentes. Não anunciar proteção de mensalidade antes de backend e testes de ponta a ponta aprovados.

## Entregas para encerrar a frente administrativa

1. **Conteúdo:** matriz de canais e referências dos comprovantes, sem guardar contratos sensíveis ou credenciais no repositório. Marcar cada caso como comprovado, pendente, negado ou vencido; não usar reprodução bem-sucedida como comprovação documental.
2. **Privacidade e termos:** produzir versões finais baseadas no build efetivo, com contato, finalidades, terceiros, retenção e exclusão definidos; disponibilizar links e validar abertura no aparelho.
3. **Distribuição:** definir artefato de entrega, versão, assinatura estável e SHA-256; registrar instruções de instalação/atualização e atendimento. Conferir requisitos da plataforma escolhida quando essa publicação for executada.
4. **Liberação:** anexar decisão do coordenador após evidências das frentes fiscal, segurança, catálogo, visual e Cast; não declarar o produto pronto enquanto os bloqueios técnicos persistirem.

## Validação desta entrega

Foram lidos o relatório da coordenação, checklist de lançamento, documentos de candidato/login e os fontes indicados. Foram pesquisados termos de privacidade, uso, exclusão, autorização e arquivos de contrato no checkout. Nenhum teste de aplicativo foi executado por esta frente: alteração somente documental. Sem envio de e-mail/comentário externo, sem commit/push e sem alteração dos itens oficiais.
