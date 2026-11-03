# Integração central Android — experimental e desativada

Base preservada: PR #42 draft, `fix/subscription-access-20261026`, commit 61780147654b42709070702a677eec24b33a2ac5. Esta branch nova não modifica a PR, Candidata6, LAB714, APK público, catálogo ou identidade visual.

Celular e Android TV compartilham o Flutter e `AdaptivePlayerScreen`. O opt-in `ROCHA_CENTRAL_RIGHTS=false` é o padrão. Quando ativado em build experimental próprio, `SubscriptionAccess` consulta o contrato central; um login móvel recente registra apenas aquele celular. A TV recebe código e exige aprovação autenticada no celular. O wrapper de reprodução só monta Exo/VLC após autorização de stream, renova a cada25s e remove o player ao expirar. Voltar/dispose libera o slot; falha de rede não cria direito. A Home não ocupa stream.

`CentralLease` confere versão, ambiente, escopo, UID, dispositivo, estado e relógio do servidor, descontando RTT. LAB não vira paid. `central_rights_runtime.dart` usa Firebase ID token do usuário; nunca Admin. Sessão TV local é vinculada a UID+endpoint, validada pelo servidor ao restaurar; armazenamento é privado do app via SharedPreferences, não há alegação de chave protegida por hardware. Troca de conta rejeita respostas em trânsito. O servidor mantém a exclusividade do celular sem revogar as TVs.

Definições futuras de build: `ROCHA_CENTRAL_RIGHTS=true`, `ROCHA_CENTRAL_DEVICE_KIND=phone|tv`, `ROCHA_CENTRAL_RIGHTS_URL=https://HOST/v1/access`, `ROCHA_CENTRAL_RIGHTS_SCOPE=homologation|commercial`. Nenhuma delas foi ativada ou usada para gerar APK. Usar apenas o runtime isolado autorizado, com identidade comercial e armazenamento LAB separados. A configuração Firebase de homologação existente não deve ser presumida equivalente à conta comercial.

Execute `flutter test test/central_rights_client_test.dart test/subscription_access_result_test.dart` e `flutter analyze lib/src/auth lib/src/screens/adaptive_player_screen.dart test/central_rights_client_test.dart`. CI desta branch executa somente testes/análise, sem APK, deploy ou segredos.

Pendências: login Firebase real, restauração de sessão no aparelho, Android TV/controle real, expiração durante decoder/Cast e desconexão remota. Parada de Cast é solicitada; receiver offline não é comprovadamente parado pelo app. Contagem independente de receiver Chromecast permanece sem homologação; não ativar o caminho comercial até validar a atribuição do receiver a slot de TV. Testes de transporte não aprovam áudio, vídeo, desempenho físico ou autenticação positiva. Políticas dos pagamentos históricos e concessão comercial dependem de aprovação separada.

O backend/código Roku e o plantão mestre estão na branch `lab/roku-visual-covers-performance-20261102`, em `experiments/central-rights` e `docs/central-rights/20261102`. Não há novo sistema de assinatura Android: ambos os tipos de aparelho usam o mesmo estado central, ainda sem implantação.

## Resultado confirmado

[CI41559164920](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41559164920), código86a700209166ad36d4deb90c47ff82d29915e86e:34testes direcionados aprovados (cliente central, resposta de assinatura, gate e superfícieTV), análise dos arquivos afetados sem problemas. Nenhum APK. Histórico:41553166585 passou testes mas análise encontrou Future sem await; corrigido.41558132141 aprovou17testes e análise; a última rodada ampliou apenas regressões relacionadas ao gate/player alterados.
