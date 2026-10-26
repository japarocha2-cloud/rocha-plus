# Rocha+ — Cast não inicia na TV

Relato físico: o proprietário informou aviso de que a TV não confirmou a transmissão e confirmou que não aparece imagem nem áudio na TV. No celular, informou áudio, imagem, tela cheia e outras categorias funcionando. Modelo da TV, canal e build instalado ainda não foram explicitados.

## Falha encontrada no código

CastChannelLoader enviava LOAD com autoPlay=false e, assim que a chamada retornava, enviava PLAY. A implementação Android da dependência fixada flutter_chrome_cast 1.5.0 chama RemoteMediaClient.load e devolve sucesso imediatamente ao Dart; não aguarda o carregamento de mídia no receptor. Portanto, o PLAY podia chegar enquanto a TV ainda carregava ou estava em uma sessão de mídia anterior.

Fontes verificadas: pacote oficial https://pub.dev/packages/flutter_chrome_cast/versions/1.5.0, android/src/main/kotlin/com/felnanuke/google_cast/RemoteMediaClientMethodChannel.kt (onMethodCall/loadMedia) e https://developers.google.com/cast/docs/media/messages. Isso identifica um defeito possível na sequência de comandos, não comprova sozinho a causa no equipamento do proprietário.

## Correção experimental

- LOAD agora pede reprodução automática no próprio comando.
- PLAY separado só é tentado uma vez, depois de o receptor informar o canal solicitado em PAUSED.
- A confirmação continua exigindo PLAYING e identidade do canal. Retorno do plugin ou descoberta da TV não aprovam a transmissão.
- Um status em cache anterior ao LOAD não confirma nem rejeita a nova tentativa.
- IDLE sem motivo de erro e INTERRUPTED podem representar transição; ERROR, CANCELLED e FINISHED seguem reprovando a tentativa.
- Janela de confirmação ampliada de 20 para 60 segundos para receptores lentos. Fallback HLS local e limpeza de sessão permanecem.
- A autorização é conferida antes do LOAD e durante a espera, inclusive depois de cada comando assíncrono. Revogação impede PLAY e confirmação subsequentes.

Adicionados testes do fluxo com receptor simulado: autoplay, carregamento lento, retomada após PAUSED, status em cache, transições IDLE, erro remoto, identidade de outro canal e revogação. Esses testes não reproduzem TV física.

## Verificação necessária

Rodar análise e suíte Flutter no CI, gerar novo APK .lab assinado no projeto rocha-plus-homologacao com subscription_lab=false e entitlement_url vazio, conferir assinatura/hashes e repetir o teste físico na TV. Não declarar Cast corrigido antes desse teste. O APK #700 não contém esta alteração.

## Firebase e escopo preservado

Login administrativo confirmado em rochaplus.app@gmail.com. Projeto experimental rocha-plus-homologacao: plano Spark; Firestore (default), edição Padrão, nativo, southamerica-east1, sem coleções na consulta; Google Authentication ativado. Foi observado um usuário Google existente, distinto da conta de teste de pagamentos. A conta nadiarocha10@hotmail.com é referência de teste, não credencial administrativa.

A página Functions exige upgrade do projeto para usar backend gerenciado. Nenhum upgrade de faturamento, nova credencial, implantação, escrita Firestore, acesso oficial, cobrança ou publicação de APK foi realizado nesta rodada. A integração de assinatura continua pendente e separada da correção Cast.
