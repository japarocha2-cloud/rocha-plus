# Android TV / LibVLC — regressões de superfície e controle (27/10/2026)

Branch exclusiva: `fix/subscription-access-20261026`; base `29a785e`; PR #42 draft.
Sem APK, publicação, merge, deploy ou pagamentos reais.

## Evidências anteriores à correção
[CI 40497325390](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40497325390), commit de testes `de701ac`:
223 testes Flutter aprovados e quatro testes novos reprovados.
- Troca para o segundo canal mantinha somente a criação do primeiro player: esperado duas superfícies, obtida uma.
- Controlador substituto sem criação de superfície produziu `LateInitializationError: _viewId ... has not been initialized` no descarte; algumas falhas posteriores decorriam desse descarte.
- A ação “Tentar no ExoPlayer” não recebia foco ao falhar o decoder.
A reprodução usa o controlador/widget reais do pacote fixado, com implementação simulada de VlcPlayerPlatform. Não executa decoder nativo nem áudio/vídeo.
A primeira rodada de testes (`af84b5a`) usava pumpAndSettle inadequadamente para um placeholder animado oculto; foi ajustada para quadros limitados antes de medir os defeitos. Essa rodada não é evidência de falha física.

## Correções pequenas
- Associar a identidade do VlcPlayer ao controlador com ObjectKey, garantindo uma nova superfície para um novo controlador e mantendo a superfície ao alternar fullscreen.
- Foco automático no botão de recuperação do ExoPlayer após erro.
- Remover o placeholder animado da árvore quando o controlador informa inicialização concluída.
Nenhuma atualização ou alteração do plugin de terceiros.

## Sete testes de regressão
Inicialização e Enter; troca de canal/superfície; Voltar do fullscreen; alternância fullscreen;
foco na recuperação; quatro trocas sucessivas com descarte dos players substituídos;
remoção da animação de carregamento após inicialização.
Validação final: suíte Flutter completa, flutter analyze completo e testes Node/Python na CI do commit corretivo, registrados no PR.

## Limites
Não houve teste físico: a ferramenta de depuração Android não foi encontrada no PATH nem na localização padrão verificada.
Testes da interface simulada não comprovam ausência de vazamento nativo, inicialização tardia de AndroidView,
imagem/áudio ou estabilidade do LibVLC no aparelho.
Continuam pendentes Android TV e Chromecast reais, imagem e áudio por 60/180 segundos,
reconexão, controle físico e consumo de memória. Não homologar reprodução ou excluir canais com base nestes testes.
