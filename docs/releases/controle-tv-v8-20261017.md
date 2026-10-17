# Controle de canais na TV — candidato v8

Pedido do titular: trocar canais pelo controle sem voltar à lista, nos aplicativos instalados nas TVs. Implementação isolada em feat/soul-tv-candidates-20261016, a partir da fonte v7. Produção e APKs congeladas não modificadas.

## Comportamento Android/TV Box

- CH+/CH− trocam para o próximo/anterior da lista aberta. Page Up/Down também são aceitos.
- ↑/↓ trocam somente com os controles ocultos. OK/Enter abre os controles; setas com controles visíveis continuam navegando.
- Mantém categoria, pesquisa ou Favoritos que originaram a lista. A lista é copiada e deduplicada por URL na abertura do player; não busca canais adicionais.
- Do último canal volta ao primeiro e vice-versa. Com um único canal a tecla não reinicia o player.
- Nome do canal aparece por três segundos. Tela cheia existente é preservada na troca.
- Voltar mantém o comportamento de tela cheia anterior; retornando à grade, rola e devolve foco ao último canal escolhido.
- Tecla segurada não cria novas tentativas a cada repetição. Novas pressões durante carregamento invalidam a tentativa anterior e descartam seu controlador; um carregamento antigo não pode iniciar áudio depois da troca.
- URLs, limite de inicialização, adaptação HLS, catálogo, temas, artes, preços, login e regras de assinatura não alterados.
- Troca do player local. Não implementa controle do Rocha+ pelo controle físico do Chromecast/espelhamento do celular; o Cast mantém seus comandos e fluxo existentes.

## Roku

ChannelVideo estende o player Video nativo. ↑/↓ em foco de reprodução enviam direção à cena; a lista atual define os limites. OK, transporte e menus continuam delegados ao player nativo. Troca verifica novamente o acesso existente, encerra o sinal anterior, mantém tela cheia e mostra o nome; Voltar retorna com channelIndex atualizado.

Compilador BrighterScript 0.73.7 aprovou o pacote e o interpretador brs 0.45.0 executou os testes das funções reais de tecla e índice. Isso não confirma reprodução, foco interno nem entrega das teclas em uma Roku física.

Limitação preexistente confirmada: platforms/roku/config/auth.json contém endpoint, billingEndpoint e introUrl vazios. O cliente mantém acesso bloqueado nessa configuração. Não foi adicionado bypass nem alterado login/assinatura para liberar esse teste. Ativação do serviço e teste físico continuam pendentes.

## Evidências

- Fonte inicial: cc6d6b82b61abd0313a89a1ab036e91f4b236b5e.
- Ajuste de foco e descarte do controlador de teste: d1e28d1b3727814206bcfb152ba6f9acafff1995.
- Serialização do descarte nativo em múltiplas pressões rápidas: cfb3534f4c3ce948449154f1afc4cab0a8b08b2b. Um teste mantém dispose() pendente, envia duas trocas e exige que nenhum novo decoder seja criado antes da conclusão; depois somente o último canal solicitado é aberto.
- Correção exclusiva do diagnóstico: 9fd3c2606704fc3dadedec6ecd04f3293256fb42. O log Android mostrou Bad state: No element em channel_remote_probe.dart:14, antes do vídeo. A fonte oficial usa porta HTTPS explícita :443, normalizada pelo Uri. Identificação passou a comparar Uri.parse(c.url) == uri. Catálogo e URLs originais preservados.
- 21 testes Python e guarda estática aprovados localmente.
- Primeira compilação Android parou na análise do controlador simulado (must_call_super); correção chama o descarte da superclasse e evita atualizar o simulador descartado. Nenhuma APK dessa tentativa foi publicada.
- Compilação assinada: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39055035967 (em andamento; fonte cfb3534).
- Roku e Android com teclas nativas: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39055127693 (em andamento; fonte 9fd3c26).
- O diagnóstico Android usa o PlayerScreen real com streams aprovados, envia keycodes 166, 167, 19, 23, 20 e exige avanço da reprodução após cada troca. A APK de diagnóstico nunca é distribuída.

## Teste físico

Instalar somente o candidato Android separado, abrir Infantil, entrar em tela cheia e testar CH+/CH− ou ↑/↓ com os controles ocultos. Confirmar nome, imagem e áudio sem sobreposição; usar OK e setas nos controles, trocar rapidamente, testar Voltar e foco na grade. Repetir em Favoritos e nos extremos da lista. Verificar o modelo do controle/TV caso uma tecla não seja entregue pelo sistema.

## Compilação anterior não entregue

A compilação d1e28d1 passou em 170 testes e gerou uma APK assinada. Não foi entregue porque, na revisão seguinte, foi acrescentada a garantia de descarte serializado para trocas rápidas. A versão 8 ainda não havia sido disponibilizada ao titular; versionCode 8 foi mantido na reconstrução.
