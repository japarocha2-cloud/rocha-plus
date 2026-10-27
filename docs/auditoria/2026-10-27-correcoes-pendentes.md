# Correções adicionais — 27/10/2026

Base: `88e539a7c0bf282a77394ffa4b627b18c6ef504c`.
Escopo exclusivo da branch `fix/subscription-access-20261026`, PR #42 draft.

## Defeitos corrigidos
- **Cast/eventos em sequência:** um evento PLAYING anterior podia encerrar a confirmação antes de um ERROR, mídia diferente ou limpeza de mídia já enfileirados. Agora somente o estado mais recente do lote pode confirmar reprodução ou receber PLAY. A consulta complementar não reinsere um evento antigo após o mais recente.
- **TV/escolha de engine:** erro ou espera sem fim na leitura das preferências locais podia manter o spinner indefinidamente. Falha, ausência de preferência ou espera superior a dois segundos selecionam ExoPlayer. Escolhas explícitas e preferências válidas de LibVLC são preservadas; leitura tardia não substitui a escolha.
- **Assinatura/metadados:** offsets de fuso fora do intervalo de horas/minutos são rejeitados na data exibida. Isso não muda allowed nem cria/estende direito de acesso.

## Regressões acrescentadas
Seis testes Cast (erro após PLAYING, PAUSED obsoleto, mídia diferente, polling atrasado e mídia removida);
quatro de seleção de engine (escolha explícita, preferência ausente, falha e espera limitada);
um de offsets inválidos e conversão válida UTC.
Suíte Flutter completa, flutter analyze completo e CI Node/Python permanecem obrigatórios.

## Limites e preservação
Os cenários acima são reproduções automatizadas, não testes físicos.
Chromecast, imagem/áudio de 60/180 s, controle real, LibVLC nativo e memória continuam pendentes de aparelho.
Sem APK novo, publicação, deploy, merge, reconciliação, cobrança ou alteração real de direitos.
Sem remoção de canais, favoritos, variantes regionais ou mudanças de backend.
