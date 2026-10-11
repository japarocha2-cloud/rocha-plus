# Rocha+ | V4 estabilidade (FFmpeg)

Executa até 30 segundos de decodificação por canal selecionado, descartando a saída (sem salvar vídeos). Usa o resultado de V3 `reports/channel_probe.csv`; somente entradas `video_e_audio`. Não remove canais do catálogo.

No Windows, com CMD aberto na pasta `tools`, após ativar o PATH para FFmpeg usando `set PATH=%CD%;%PATH%`, execute:

```bat
python channel_stability.py --input ..\reports\channel_probe.csv --output ..\reports\channel_stability --max-channels 10
```

Se os primeiros dez funcionarem e você quiser testar todos os candidatos:

```bat
python channel_stability.py --input ..\reports\channel_probe.csv --output ..\reports\channel_stability --max-channels 0 --workers 2 --seconds 30 --timeout 50
```

Relatórios em `reports/channel_stability.csv` e `.json`. Limite de 2 streams simultâneos por padrão. Status `completou_teste` significa que o FFmpeg saiu sem erro e levou tempo próximo do alvo, não garante reprodução contínua sem congelamentos e não confirma Cast. `terminou_antes_do_prazo` requer investigação. A V4 não certifica autorização de redistribuição ou estabilidade em Smart TV.

**Importante:** FFmpeg deve estar acessível no PATH da janela atual e os relatórios V3 devem estar copiados na pasta reports. Não use URLs contendo tokens privados em relatórios públicos.
