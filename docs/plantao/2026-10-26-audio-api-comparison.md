# Áudio — comparação isolada da imagem Android

Base: ad9cbe46a233c740ff218ef69f166eb15dc007a5. Login assinado #700 e CI principal #699 continuam sendo evidências verdes desta base.

## Resultado da restauração de VirtIO

A execução https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40367275669 terminou com falha no smoke. O artefato 12671049159 teve seu SHA-256 conferido: 7056ef880bd9c9dbfd5dd3e37ad4585e155487d40b2a2fc212110b58664f64d2.

A placa VirtIO SoundCard e seu PCM reapareceram no guest, porém o HAL ranchu registrou repetidamente `pcm_writei ... I/O error`. O tom de 440 Hz não foi observado: a segunda tentativa registrou RMS -98,7095 dBFS, pico 0,000061 e fração não silenciosa 0. O host gravou seu tom de 997 Hz e passou a calibração separada. Restaurar a placa resolveu sua ausência, mas não comprovou áudio funcional.

Nenhum canal aprovado; batch10, batch25 e remaining foram pulados. A consolidação passou apenas como processamento dos resultados.

## Próximo experimento

Adicionado o parâmetro api_level ao workflow reutilizável, com padrão 35. O fluxo de catálogo continua usando API35 e o mesmo gate. Um job separado usa o mesmo APK em API34 e executa somente `run_android.py --stage preflight`: fixture de RGB e tom de 440 Hz, sem testar ou aprovar canais. Não é fallback que substitua a falha API35 por sucesso.

Os artefatos identificam a API no nome e preservam a versão do emulador e a API efetiva do guest. A consolidação aguarda também a comparação, mas o diagnóstico de calibração não produz results.json de canais nem libera os lotes de API35.

O objetivo é isolar se a imagem Android altera a falha. Um eventual sucesso em API34 não comprova compatibilidade API35, login, pagamentos ou aparelho físico. Nenhum limiar de áudio, vídeo, duração ou repetição foi reduzido.

Sem modificação do aplicativo, catálogo oficial, preços, cobranças, Firebase oficial, assinatura comercial ou versão congelada. O #700 permanece com subscription_lab=false e entitlement_url vazio.
