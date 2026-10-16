# Auditoria Rocha+: Roku e continuidade de Cast — 16/10/2026

Base Android aprovada: `freeze/mobile-4107-approved-20261015`, commit `999b104e9034449d0c6815d21258848a8efba7e3`. Auditoria isolada em `audit/roku-cast-continuity-20261016`. Nenhum código de produção, preço, serviço Firebase ou congelamento foi alterado.

## Resultado de equivalência Roku

O Roku ainda não atende a todas as exigências do APK aprovado. Há dois estados diferentes:

| Exigência | ZIP Roku V3.5 entregue | Fonte Roku presente na base 4107 |
|---|---|---|
| Catálogo | 190 canais HTTPS/HLS; mesmos IDs, ordem e URLs da base; faltam 187 campos de logotipo | Catálogo e quarentena idênticos byte a byte à base compartilhada |
| Login | Ausente; a própria interface informa login pendente | Pareamento e restauração de sessão implementados, mas endpoint vazio |
| Assinatura e bloqueio | Player inicia sem verificação de assinatura | Verificação antes do player, atualização de 60 s e concessão máxima de 5 min; billingEndpoint vazio impede ativação |
| Alerta dos sete dias, uma vez por conta | Ausente | Ausente; não há aceite/claim do aviso |
| Prazo único entre celular e Roku | Não integrado | Adaptador de conciliação Spark existe no servidor, mas publicação/configuração unificada não comprovada |
| Teste físico | Pendente | Pendente |

Pacote inspecionado: `RochaPlus-Roku-V3.5-Catalogo-20261012.zip`, SHA-256 `97164d54a6409dd15dd24e6b5cecb14a52485836b92757a9b0c8f6fca808578f`. A conclusão sobre o pacote entregue não é inferida apenas de uma branch: o ZIP foi aberto e o início de reprodução em HomeScene.brs foi conferido.

Fontes relevantes: `platforms/roku/components/Account.brs`, `HomeScene.brs`, `HomeScene.xml`, `platforms/roku/config/auth.json`, `billing/pairing/service.mjs`, `billing/spark_recurring_store.js` e `billing/index.js`.

## Continuidade de Cast

O proxy encaminha HLS sem transcodificar. O encerramento por inatividade é de duas horas e se renova em cada requisição válida; não é um corte fixo de duas horas durante uso contínuo. Existem limites de 5 s para resolução DNS e 8 s para respostas/dados do upstream. Interrupções podem afetar a sessão; nenhuma causa de falha física foi comprovada nesta auditoria.

Novos testes usam 30 minutos de relógio virtual para trial e assinatura, expiração de prazo sem reiniciar trial e 300 segmentos HLS sintéticos de 6 s pela mesma URL de sessão. Os segmentos não contêm mídia decodificável. Isso verifica transporte e estado de acesso, não demonstra 30 minutos de imagem e áudio em TV.

Não existe Roku/Cast físico acessível neste ambiente. Para homologação, executar na TV e no celular: registrar canal, modelo, conexão, horário inicial/final, imagem/áudio, pausas e reconexões durante pelo menos 30 minutos; repetir no caminho efetivamente usado pelo usuário (Cast ou espelhamento de tela). O teste de velocidade no computador não mede esse trajeto.

## Verificações

- Pareamento Node: 5 testes aprovados, sem acessos reais ao Firebase ou cobranças.
- Verificação compartilhada de plataformas: falha preexistente `Shared account adapter differs` entre `platforms/shared/account.js` e `platforms/web-tv/shared/account.js`. A suíte Python tem 2 aprovações e 1 erro. Isso não é divergência do catálogo Roku, mas impede declarar a suíte completa aprovada.
- Flutter/Cast: execução e evidências em https://github.com/japarocha2-cloud/rocha-plus/actions/runs/38982304461 — análise estática aprovada, 34 testes Flutter aprovados e 5 testes Node aprovados. A execução anterior 38982170884 falhou porque os testes de tela substituíam o HttpClient por respostas 400; os testes de transporte foram isolados em outro arquivo, sem alteração da implementação do proxy.

## Trabalho que ainda falta

Integrar endpoints reais de pareamento e status usando o mesmo prazo de acesso do Android; implementar o aviso e aceite único dos sete dias; testar troca de conta, restauração, reinstalação, vencimento e assinatura ativa; gerar outro ZIP identificado sem substituir o V3.5; homologar na TV. Esta auditoria não publica essas alterações.

## Recuperação de conexão: achado adicional

Em `lib/src/screens/player_screen.dart`, a inicialização tem limite de 8 s e erros do decoder levam à tela de tentar novamente manualmente. Não há recuperação automática controlada no código Dart nem monitor de travamento prolongado; o mecanismo nativo pode ter tentativas próprias. Esse ponto é uma oportunidade de melhoria, não prova da causa do problema físico. Para uma correção direcionada, distinguir reprodução local, Google Cast e espelhamento de tela e reproduzir a interrupção, preservando a pausa voluntária e o bloqueio de assinatura.