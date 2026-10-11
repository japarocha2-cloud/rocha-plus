# Rocha+ | Terceira etapa: teste com FFprobe

A varredura HTTP não garante reprodução de vídeo. Esta etapa consulta metadados de streams com FFprobe, indicando se vídeo/áudio foram detectados. Não elimina canais nem altera o aplicativo.

## Preparar no Windows
Instale o pacote oficial FFmpeg de uma compilação Windows e adicione o diretório bin ao PATH. Feche e reabra o CMD. Verifique:

\`\`\`bat
ffprobe -version
\`\`\`

Copie reports/channel_triage.csv para a pasta reports do ZIP atualizado, abra CMD na raiz do projeto e execute primeiro um lote pequeno:

\`\`\`bat
python tools\channel_probe.py --max-channels 10
\`\`\`

Se funcionar, execute todos os candidatos prioritários:

\`\`\`bat
python tools\channel_probe.py --workers 3 --timeout 15
\`\`\`

O relatório será salvo em reports/channel_probe.csv e .json. As categorias video_e_audio, somente_video, somente_audio, sem_midia_detectada, tempo_esgotado e erro são diagnósticos pontuais. Ausência de áudio no momento do teste não garante ausência de áudio no canal. Para testar todos os 841 registros, adicione --all. Isso pode levar muito mais tempo e causar carga de rede considerável.

Nunca publique relatórios com URLs secretas ou tokens privados.