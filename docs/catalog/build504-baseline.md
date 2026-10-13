# Base física preservada: Build #504

Base: commit `3a96cd09928f28fd5ea4854ae1725ba80ef3e10b`, run `38470642076`, APK universal versionCode 3504.

Lucas confirmou instalação, favoritos separados por conta e fluxo de Assinaturas no aparelho. Esses relatos não aprovam automaticamente reprodução de todos os canais nem sincronização entre aparelhos.

## Escopo da organização do catálogo

- Preservar a implementação de login, favoritos, Assinaturas, preços e visual da base.
- Carregar somente a seleção empacotada; nunca usar uma lista pública completa como fallback.
- Seleção e quarentena recuperadas do commit `6f12b2fc62de56e508fafce834d1765eb1621298` da PR #23. A PR inteira não foi incorporada.
- 190 fontes selecionadas anteriormente por decodificação automatizada; 158 exclusões recuperadas, mais SBT Cuiabá excluído por HTTP 404 nesta rodada. A evidência anterior é de FFmpeg, não de aprovação física de 190 canais.
- Capas recuperadas por correspondência de URL/nome, sem acrescentar canais.
- Bloqueios históricos por nome continuam aplicados, independentemente da resolução ou URL.
- Falhas reportadas pelo player persistem por URL; atualização, reinício e progresso tardio do decoder não readmitem uma fonte rejeitada. Uma falha de rede pode provocar uma exclusão conservadora que exigirá revisão explícita.

## SBT: pendência aberta

Lucas reportou falha nesta versão em um canal SBT que funcionava anteriormente. Ainda não há diagnóstico conclusivo do player no aparelho.

Em 2026-10-13, a sondagem FFprobe das três fontes SBT da seleção não confirmou vídeo e áudio: Interior encerrou com erro; Nacional e News atingiram o limite de 22 segundos. Esse resultado do ambiente de auditoria não distingue indisponibilidade do servidor, restrição de rede e regressão no aparelho. Não se declara SBT corrigido nem se troca sua fonte automaticamente.

Na verificação seguinte, os manifests Interior, Nacional e News responderam HTTP 200 com HLS. A decodificação de segmentos baixados confirmou 29,996633 segundos de vídeo H.264 e áudio AAC, sem erros, para SBT Nacional e SBT News. Essa prova automatizada não mede estabilidade contínua de streaming nem reprodução no Android.

A playlist de SBT Cuiabá (visível no teste físico enviado) respondeu HTTP 404. A fonte foi registrada na quarentena e não será readmitida pela atualização pública. SBT Nacional e News permanecem na seleção; não se reintroduz outro SBT sem revisão.

## Validação necessária

Testes automatizados devem comprovar admissão restrita, persistência das exclusões e ausência de fallback público. Depois, testar fisicamente atualização/reabertura do catálogo e reprodução SBT com vídeo e áudio. A próxima build permanece candidata a teste.
