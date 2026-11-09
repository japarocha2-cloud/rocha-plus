# Rocha+ — diagnóstico do áudio do laboratório

Status: VERMELHO para evidência audiovisual; build principal VERDE.

Revisão investigada: 7bd1d1d3fa29db8721a705ced3303b54cb6cae66.

Execução: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40357197981

Job: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40357197981/job/121714866399

Artefato: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40357197981/artifacts/12668263958

## Evidência

O APK compilou e instalou. A imagem da calibração foi capturada, mas o PCM Android permaneceu silencioso em ambas as tentativas: pico 0, RMS -240 dBFS, fração não silenciosa 0. O gate bloqueou os lotes e não aprovou canais.

O host capturou o tom de 997 Hz e confirmou hostLoopbackVerified=true. O cliente QEMU estava conectado ao PulseAudio, sem mute, a 100%, no sink esperado. Isso afasta falha total do gravador host, sem provar áudio Android.

O diagnóstico privilegiado guest-audio-cards.txt registra `--- no soundcards ---`. O log Android registra `pcm_open failed ... No such file or directory` e `failed to create alsa sink ... creating NullSink instead`. Portanto, o experimento que desabilitou VirtioSndCard não disponibilizou dispositivo ALSA ao guest API35 desta execução. Não é evidência de canal quebrado ou defeito comprovado no aparelho físico.

## Correção restrita à infraestrutura experimental

Removido o argumento `-feature -VirtioSndCard` para restaurar a seleção padrão de dispositivo de som do emulador. O histórico com virtio também contém erros PCM; a reversão não é declarada como solução audiovisual validada. Mantidos API35, APK, backend PulseAudio, tom de 440 Hz, duração, limiares e preservação dos dois checkpoints.

Nenhum limiar foi reduzido e nenhuma falha foi convertida em sucesso. O resultado deve ser confirmado por novo CI e teste físico.

## Login e pagamentos

O novo disparo manual de login permanece sem execução confirmada; a execução manual observável mais recente é #686 e pertence a revisão anterior. Não substituir essa pendência por reexecução silenciosa de revisão antiga.

Reconciliação continua em dry-run. Não houve gravação Firebase, alteração de preços, cobrança, publicação de APK ou mudança de versão congelada.
