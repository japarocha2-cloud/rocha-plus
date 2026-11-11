# Candidato CazéTV configurado para teste — 09/10/2026

ID oficial: rLwn_v8PyZM.
URL: https://www.youtube.com/watch?v=rLwn_v8PyZM
Canal verificado: UCZiYbVptd3PVPf4f6eR6UaQ.
Evento: Judô, Mundial de Baku 2026, finais do 6º dia.
Início informado: 09/10/2026 às 10h de Brasília (13:00 UTC).

O workflow da branch feat/cazetv-official-embed agora preenche cazetv_video_id com este candidato. signed_login continua true por padrão. A validação oficial de autoria permanece obrigatória antes da compilação assinada. É possível limpar explicitamente o campo para gerar APK sem fonte CazéTV.

Na consulta anterior à configuração, LIVE_STREAM_OFFLINE, isLiveNow=false e playableInEmbed=true. O serviço oficial oEmbed confirmou autoria; playback_verified=false. Metadados de incorporação não garantem reprodução.

A build 392 instalada não contém esse ID. É preciso gerar e instalar um novo APK ARM64 assinado a partir desta branch. Validar reprodução efetiva no Android após início real do evento. Não considerar um evento agendado ou uma prévia visual como transmissão funcionando. Não extrair nem retransmitir vídeo.

A alteração é somente no padrão de entrada do workflow e nesta documentação; não altera player, fullscreen, Cast, main ou a lista das 130 exclusões. Sem merge.
