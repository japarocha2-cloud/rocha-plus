# Rocha+ • Matriz de Teste Físico

Usar esta matriz somente em builds que passaram pelo Quality Guard, analyze e testes automatizados.

## Abertura
- [ ] Ícone do launcher permanece correto.
- [ ] Vinheta real em vídeo inicia automaticamente.
- [ ] Vinheta não aparece como ícone estático.
- [ ] Vídeo não está pixelado de forma perceptível.
- [ ] Ao terminar a vinheta, a transição para login ocorre uma única vez.
- [ ] Toque permite pular a vinheta sem travar.

## Celular
- [ ] Home abre sem overflow.
- [ ] Canais reais aparecem no acesso rápido.
- [ ] Busca/filtros não congelam.
- [ ] Logos não provocam travamentos ou consumo excessivo.
- [ ] Favoritos persistem após fechar e abrir o app.

## Player local
- [ ] Canal inicia em tempo aceitável.
- [ ] Áudio e vídeo permanecem sincronizados.
- [ ] Buffering exibe indicador.
- [ ] Buffering prolongado tenta uma recuperação automática.
- [ ] Falha de stream oferece “Tentar novamente”.
- [ ] Play/Pause funciona.
- [ ] Tela cheia entra e sai corretamente.
- [ ] Retorno da tela cheia restaura orientação e barras do sistema.

## Google Cast
- [ ] Dispositivo “Sala de TV” ou equivalente é descoberto.
- [ ] Sessão só é considerada sucesso quando o receiver confirma PLAYING.
- [ ] Canal compatível reproduz imagem e áudio na TV.
- [ ] Canal incompatível não gera falso positivo.
- [ ] Se o envio direto falhar em HLS local, o relay é tentado quando aplicável.
- [ ] Ao encerrar/falhar Cast, o relay é liberado.
- [ ] Player local retoma após desconexão.
- [ ] Testar pelo menos 5 canais diferentes, incluindo um que já falhou no passado.

## Android TV / Google TV
- [ ] App aparece no launcher da TV.
- [ ] Controle remoto navega por Home, canais e player.
- [ ] Foco visual nunca fica invisível ou preso.
- [ ] Voltar funciona de forma previsvisível.
- [ ] Player abre em proporção correta.
- [ ] Fullscreen não deixa barras ocupando espaço.
- [ ] Texto é legível a distância.

## Regressões proibidas
- [ ] Nenhum “Undefined” aparece como categoria.
- [ ] Nenhum ícone antigo/preto-dourado-vermelho retorna.
- [ ] Nenhuma intro antiga comprimida retorna.
- [ ] Nenhum atalho legado de screen_mirror / Cast Settings retorna.
- [ ] Build verde não é marcada como aprovada sem teste físico das funções críticas.

## Resultado
Registrar: número da build, aparelho, versão Android/TV, canais testados, comportamento do Cast, falhas encontradas e correções necessárias.
