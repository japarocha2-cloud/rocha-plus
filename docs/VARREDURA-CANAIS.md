# Varredura física de canais — ponto de retomada

Atualizado em 2026-10-11T02:54:17.514Z

Aparelho Motorola moto g56 5G, Beta 2417/PR16. Código em dev/founder-annual-app-integration/PR18. Cores, layout e favoritos preservados.

- Record RS (720p) [Geo-blocked]: Sinal indisponível. Remoção persistente preparada no código; no celular há apenas quarentena de sessão
- Rede Globo (1080p): Imagem visível e estado Reproduzindo. Manter no catálogo.
- RedeTV! Parana: Imagem visível e estado Reproduzindo. Manter no catálogo.
- SBT Cuiaba: Sinal indisponível nas duas tentativas. Remoção persistente preparada no código; no celular há apenas quarentena de sessão
- SBT Interior (720p): Imagem visível e estado Reproduzindo. Manter no catálogo.
- SBT Nacional (1080p): Imagem visível e estado Reproduzindo. Manter no catálogo.
- SBT Nova Mutum: Sinal indisponível nas duas tentativas. Remoção persistente preparada no código; no celular há apenas quarentena de sessão

As três remoções são filtros por identidade de nome na lista existente do repositório, sem exclusão de favoritos. Não são avaliação permanente da disponibilidade mundial: somente sinais reprovados no aparelho/rede nesta etapa. A Record RS já falhou no teste anterior e novamente agora; SBT Cuiabá e Nova Mutum falharam inclusive ao tocar Tentar novamente.

Atenção: o celular ainda usa Beta 2417 e mostra quarentena de sessão; os filtros novos exigem um próximo APK candidato. Nenhuma atualização instalada nesta etapa. Teste de regressão adicionado para os três bloqueios e preservação de Globo/RedeTV/SBT Interior/SBT Nacional/Record SP; execução Flutter pendente no CI do novo commit.

## Retomar daqui
- Conferir CI Flutter e gerar APK candidato com as remoções antes de instalar
- Testar SBT Rondonópolis e TV Pantanal MS; Pantanal não transmite 24 horas
- Confirmar remoção persistente após reabrir, preservando favoritos
- Retestar BabyFirst e Avatar em Infantil, BandNews em Notícias
- Concluir as demais categorias; identificar explicitamente o que não foi testado

Tela atual: SBT Nova Mutum; repetição também falhou. Retornar ao catálogo.

Ainda não examinados nesta etapa: SBT Rondonópolis, TV Pantanal MS, BabyFirst, Avatar, BandNews e restante das categorias. Não afirmar varredura completa. Pantanal tem indicação Not 24/7: falha em horário fora da programação não comprova canal morto. Áudio, Cast e estabilidade prolongada não foram homologados.

Evidências privadas XML/PNG em work/phone-*. Não publicar telas da conta. Estado estruturado salvo em outputs/VARREDURA-CANAIS-ESTADO.json.

Método de retomada: consultar aparelho com adb devices -l; exigir celular desbloqueado, ler uiautomator XML e agir conforme coordenadas atuais. Usar Start-Process com WindowStyle Hidden em ambiente autorizado; não limpar dados/desinstalar o app.
