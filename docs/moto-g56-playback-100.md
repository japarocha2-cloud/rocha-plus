# Rocha+ - resultado de 100 testes no Moto G56 5G

Build 381 instalado, commit 4409c9d953653798dce73ea61b45eedd65841e28, branch feat/cazetv-official-embed. Testes no aparelho f�sico, com 9 entradas de TV aberta e 91 de esportes.

| Resultado | Quantidade |
|---|---:|
| Player abriu e indicou reprodu��o | 55 |
| Dessas, imagens com movimento observado | 54 |
| Dessas, movimento inconclusivo (ADO TV) | 1 |
| Sinal indispon�vel / falha | 45 |
| Total de entradas testadas | 100 |

Globo, RedeTV! Paran�, SBT Interior, SBT Nacional e TV Pantanal MS mostraram imagens avan�ando. Record RS, SBT Cuiab�, SBT Nova Mutum e SBT Rondon�polis falharam.

Nos esportes, FIFA+ Portuguese, ge Fast, N Sports, Red Bull TV BR e Strongman Champions League est�o entre os canais que reproduziram. H� tamb�m v�rias entradas internacionais que falharam. Os 91 resultados individuais est�o em testes-esportes-moto-g56.md.

## Player, fullscreen e TV

- SBT Interior entrou em fullscreen horizontal por gesto duplo; sair e voltar � lista funcionou.
- SBT Nacional reproduziu no celular; o receptor Sala de TV confirmou estado de reprodu��o do conte�do solicitado pelo Cast. O app abriu a tela de controle da sess�o.
- Desconectar da TV devolveu a reprodu��o ao celular.
- N�o houve resposta do usu�rio confirmando imagem e som na tela f�sica da TV. N�o afirmar observa��o direta dessa tela nem �udio aud�vel.

## Limites e pend�ncias

Estes cem testes s�o uma amostra de entradas do cat�logo, priorizando TV aberta e depois esportes. **N�o s�o a lista identificada dos cem endere�os acess�veis na varredura HTTP anterior.** A varredura de 547 endere�os e o teste do decoder medem coisas diferentes; os resultados n�o devem ser somados nem confundidos.

Testes curtos: espera inicial de cerca de 12 segundos nos lotes esportivos e duas capturas separadas por 6 segundos quando o player indicou reprodu��o. N�o certificam estabilidade prolongada, �udio, disponibilidade permanente ou autoriza��o de cada fonte.

ADO TV indicou reprodu��o, mas mostrou uma tela quase est�tica nas duas capturas; movimento n�o confirmado. Canal Showsport mostrou um filme; correspond�ncia do conte�do ao nome pendente. A entrada FIFA+ Women exibiu futebol com apar�ncia de competi��o masculina; revisar sua identifica��o. Origem oficial de cada entrada ainda precisa ser validada antes de aprovar o cat�logo final.

Caz�TV permanece sem transmiss�o oficial incorpor�vel validada. O v�deo anteriormente configurado foi bloqueado pelo propriet�rio. N�o houve extra��o de v�deo nem tentativa de contornar essa restri��o.

Nenhuma altera��o de c�digo, novo APK ou merge neste ciclo de testes. A base principal deve continuar congelada no commit 231bca553bdd2417ae33bab68fd324d783febdf1. Build 381 e CI anteriores passaram; estes testes f�sicos n�o substituem a valida��o pendente da Caz�TV.


## Resultados das 91 entradas de esportes

| Entrada | Resultado no player | Conferência de imagem |
|---|---|---|
| Strongman Champions League (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| FIFA+ Portuguese (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| ge Fast (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| N Sports (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| Red Bull TV BR (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| A Spor SD (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| ACC Digital Network (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| ACI Sport TV SD (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| Adjarasport 1 | Falha / sinal indisponível | Sem reprodução |
| ADO TV (720p) | Reproduzindo | Movimento inconclusivo |
| Africa 24 Sport (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| Al Iraqia Sport (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| Alfa Sport (1080p) [Not 24/7] | Falha / sinal indisponível | Sem reprodução |
| AS3 Sport TV (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| Astrahan.Ru Sport (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| ATG Live (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| Awapa Sports TV (1080p) [Not 24/7] | Falha / sinal indisponível | Sem reprodução |
| Bahrain Sports 1 (720p) [Not 24/7] | Falha / sinal indisponível | Sem reprodução |
| Bahrain Sports 2 (720p) [Not 24/7] | Reproduzindo | Duas capturas com mudança de imagem |
| Barca TV | Falha / sinal indisponível | Sem reprodução |
| beIN SPORTS XTRA (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| BEK Sports West (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| Belarus-5 (1080p) [Not 24/7] | Falha / sinal indisponível | Sem reprodução |
| Belarus-5 Internet (1080p) [Not 24/7] | Falha / sinal indisponível | Sem reprodução |
| Bellator MMA | Falha / sinal indisponível | Sem reprodução |
| Billiard TV (1080p) [Geo-blocked] | Falha / sinal indisponível | Sem reprodução |
| Brondby TV | Falha / sinal indisponível | Sem reprodução |
| Canal Showsport (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| Canal+ Sport 360 | Falha / sinal indisponível | Sem reprodução |
| CBC Sport [Geo-blocked] | Falha / sinal indisponível | Sem reprodução |
| CBS Sports Golazo Network (720p) | Falha / sinal indisponível | Sem reprodução |
| CBS Sports HQ (720p) | Falha / sinal indisponível | Sem reprodução |
| CCTV-5+ | Falha / sinal indisponível | Sem reprodução |
| CDN Deportes (720p) [Not 24/7] | Reproduzindo | Duas capturas com mudança de imagem |
| Colimdo TV (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| Cricket Gold (1080p) | Falha / sinal indisponível | Sem reprodução |
| CRTV (Chile) (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| DAZN Combat (684p) | Falha / sinal indisponível | Sem reprodução |
| DAZN Darts x Pluto TV | Falha / sinal indisponível | Sem reprodução |
| DAZN Heldinnen x Pluto TV | Falha / sinal indisponível | Sem reprodução |
| DD Sports (720p) | Falha / sinal indisponível | Sem reprodução |
| DD Sports SD (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| Deportes por Movistar Plus+ | Falha / sinal indisponível | Sem reprodução |
| Digi Sport 1 | Falha / sinal indisponível | Sem reprodução |
| Digi Sport 2 HD (1080i) | Falha / sinal indisponível | Sem reprodução |
| Dong Nai TV 2 (720p) | Falha / sinal indisponível | Sem reprodução |
| DraftKings Network (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| El-Heddaf TV (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| Equidia (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| ESPN8: The Ocho (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| Esport3 (1080p) [Geo-blocked] | Falha / sinal indisponível | Sem reprodução |
| Esport3 Originals (1080p) [Not 24/7] | Falha / sinal indisponível | Sem reprodução |
| F1 Channel (1080p) [Geo-blocked] | Falha / sinal indisponível | Sem reprodução |
| Fast&FunBox (Netherlands) | Reproduzindo | Duas capturas com mudança de imagem |
| FCK Lovinderne | Falha / sinal indisponível | Sem reprodução |
| FIFA+ (720p) | Falha / sinal indisponível | Sem reprodução |
| FIFA+ French (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| FIFA+ German (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| FIFA+ Hispanic America (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| FIFA+ Italy (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| FIFA+ Spain (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| FIFA+ United States (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| FIFA+ Women (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| Fight Network (1080p) | Falha / sinal indisponível | Sem reprodução |
| FightBox | Falha / sinal indisponível | Sem reprodução |
| FightBox HD | Reproduzindo | Duas capturas com mudança de imagem |
| FITE 24/7 (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| FloHockey (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| FloRacing (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| FTF Sports (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| FTV (Bolivia) (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| Fubo Sports Network (1080p) | Falha / sinal indisponível | Sem reprodução |
| FUEL TV (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| FUEL TV AU (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| FUEL TV US (1080p) [Geo-blocked] | Falha / sinal indisponível | Sem reprodução |
| Futbol (1080p) | Falha / sinal indisponível | Sem reprodução |
| Game+ (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| GEM Fit | Falha / sinal indisponível | Sem reprodução |
| GEM Sport | Falha / sinal indisponível | Sem reprodução |
| Glory Kickboxing Poland (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| Golazo Network (720p) | Falha / sinal indisponível | Sem reprodução |
| Golf Channel | Falha / sinal indisponível | Sem reprodução |
| Hard Knocks (1080p) | Falha / sinal indisponível | Sem reprodução |
| Horse TV (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| HTSpor TV (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| HTV Sports | Falha / sinal indisponível | Sem reprodução |
| Inter TV (Italy) (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| InTrouble (1080p) | Reproduzindo | Duas capturas com mudança de imagem |
| IRIB 3 | Falha / sinal indisponível | Sem reprodução |
| ITV Deportes (720p) | Reproduzindo | Duas capturas com mudança de imagem |
| Jordan Sport (1080p) [Geo-blocked] | Reproduzindo | Duas capturas com mudança de imagem |
