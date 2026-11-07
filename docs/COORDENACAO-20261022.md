# Coordenação geral Rocha+ — 22/10/2026

## Escopo e decisão

Correções somente em `feat/dual-player-lab-20261020`, PR #33. Nenhuma alteração em `main`, referências freeze/frozen/checkpoint, catálogo oficial ou política de cobrança. Não promover lançamento: áudio e segurança seguem VERMELHOS. Nenhum canal novo aprovado neste ciclo.

## Evidência do commit 5e1384fd0c26595b8a95eecf3822152938e3e654

| Suporte | Estado | Evidência e limite |
| --- | --- | --- |
| #36 Fiscal | VERMELHO no laboratório; VERDE na compilação anterior | [Build 39754886953](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39754886953): analyze sem problemas, 109 testes Flutter passaram e APK experimental gerado. [Laboratório 39754887144](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39754887144): smoke falhou; batch10, batch25 e remaining foram pulados. Não equivale a teste físico. |
| #37 Player e catálogo | AMARELO, homologação bloqueada pelo áudio | Dois fixtures positivos e um HTTP 404 foram processados no emulador; a sequência ultrapassou um canal, mas áudio não foi comprovado. A execução não valida os canais reais nem resolve os falsos positivos dos relatórios PC por si só. |
| #38 Visual | AMARELO | Job android 119744276499 passou a etapa de observação de rotas de categorias em emulador e produziu artifact 12415044344. Sem auditoria visual completa ou homologação de TV física neste ciclo. |
| #39 Espelhamento e controles | AMARELO | Sem novo teste físico de Chromecast, reconexão, áudio e troca de canal pelo controle durante Cast. |
| #40 Segurança | VERMELHO | Política atual beta não exige assinatura. Backend de direitos, aprovação administrativa confiável, renovação, estorno, trial por UID e E2E não comprovados. Não afirmar bloqueio de inadimplentes. |
| #41 Administrativo | AMARELO | Autorizações de distribuição, termos e privacidade ainda pendentes conforme issue. Não aprovar comercialização de candidatos apenas pela reprodução. |

## Diagnóstico de áudio obtido dos arquivos reais

- [Job do emulador 119756235603](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39754887144/job/119756235603), Android API 35, emulator 37.2.12, imagem x86_64. Não houve teste em aparelho físico.
- `calibration-failure.json`: Exo com 5/5 quadros RGB reconhecidos, movimento observado, áudio não observado; frequência dominante 12 Hz, RMS −98,76948 dBFS. O tom esperado de 440 Hz falhou. As outras fases também ficaram perto de −98,7 dBFS.
- O cliente PulseAudio do QEMU existia, no sink `rocha_lab`, sem mute e a 100%. Android STREAM_MUSIC também não estava mudo. Portanto, falta de cliente ou mute não explica os dados coletados.
- `smoke/logcat.txt` registrou repetidamente `android.hardware.audio@7.1-impl.ranchu: pcmWrite:259 pcm_writei failed ... I/O error`. O ponto exato da falha guest/host ainda precisa ser isolado; não atribuir a falha aos canais.
- A calibração host também era inválida: log mostra início da gravação às 09:51:32 UTC, término aproximado às 09:51:38, emissão do tom apenas às 09:51:39. A action executa cada linha em um novo shell e aguarda o comando; `&` não forneceu a sobreposição pretendida. WAV host analisado: 5,999896 s, pico zero, −240 dBFS, SHA256 `8b0f0299210e8c37f82ac0b3974948a649e7fc2580cf619e81f5156f003a7768`.
- [Artifact de evidências 12417168458](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39754887144/artifacts/12417168458), SHA256 do ZIP informado pelo upload: `0d5843a68aaf781f3b9a10ca9d6c81236d2d398eb8bf57a01b1c13b215edeaca`.

## Alterações deste ciclo

1. Calibração host movida para um único processo Python com subprocessos concorrentes, conclusão explícita e erros fatais. Tom host de 997 Hz, distinto do fixture Android de 440 Hz; os processos terminam antes de iniciar reprodução Android. Resultado separado em JSON; nunca aprova áudio Android. Mantidas as exigências de PCM/vídeo e duração dos testes.
2. Capturas de AudioFlinger, AudioPolicy, estado de áudio, ALSA e kernel durante a primeira amostra de cada fase, para investigar os erros de escrita enquanto o player está ativo. A indisponibilidade de diagnóstico fica explícita.
3. Documentação de assinatura corrigida: a descrição anterior dizia que todos os usuários autenticados seriam bloqueados sem endpoint; isso não corresponde à política beta vigente. Sem mudar a política ou liberar pagamentos.

## Validação local deste ciclo

- 19 testes Python do laboratório passaram, incluindo rejeição de silêncio/tom errado e separação entre calibração host e aprovação Android.
- 4 testes Python de configuração/build passaram; fiscal estático passou; `git diff --check` sem erros.
- Esses testes usam dados sintéticos para a análise PCM; não substituem gravação real. Não foi possível executar PulseAudio/Android localmente: os executáveis não estão instalados e a instalação de pacote falhou pelas restrições do ambiente. Flutter não foi executado localmente.
- Novo CI após envio: pendente. A correção de sincronização não resolve por evidência os erros de áudio do Android; diagnóstico e aprovação permanecem separados.

## Próximos critérios de saída

1. Host deve capturar 997 Hz; em seguida Android deve exibir RGB e emitir 440 Hz em Exo, VLC e confirmação para os dois fixtures; HTTP 404 deve falhar. Sem isso, não executar homologação de catálogo.
2. Se host passar e Android falhar, inspecionar os novos dumps durante playback junto com `pcm_writei`; só então escolher uma correção de HAL/emulador. Não enfraquecer limites para obter VERDE.
3. Segurança: implementar serviço HTTPS com Firebase Admin e armazenamento autoritativo antes de alterar a política de acesso. Testar UID/token, sete dias, reinstalação, relógio alterado, pagamento pendente/confirmado, renovação, estorno, falha de rede, player e Cast. Não há endpoint implantado comprovado neste ciclo.
4. Após smoke válido, executar lotes Exo/VLC 60 s e confirmação 180 s; manter autorização de distribuição como requisito separado. Testes físicos de TV/Cast e auditoria visual continuam necessários.
