# Avanço — áudio de infraestrutura e acesso Firebase

Base experimental: `ca4a84a2bec51d8d622e504e9336e1d1490186a1`. Nenhum arquivo do aplicativo, catálogo oficial, preço, pagamento ou referência congelada alterado neste ciclo.

## Build validado

[Build 673](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40249144491) terminou **SUCCESS**. Jobs Android e backend passaram. O job manual de login de homologação ficou **SKIPPED**, como previsto para pull request; não é teste de login real aprovado. Isso valida a integração estática do novo fluxo manual e mantém o build comum funcionando.

## Experimento de áudio restrito ao laboratório

O artifact do LAB 64 continua sendo a evidência de falha: calibração host válida, saída Android com erros repetidos `pcm_writei ... I/O error` e ausência do tom de referência. A fonte AOSP define `VirtioSndCard` como a opção que habilita virtio-snd e desabilita Intel HDA:

https://android.googlesource.com/platform/external/qemu/+/emu-master-dev/android/data/advancedFeatures.ini

A inicialização do emulador no workflow experimental agora usa `-feature -VirtioSndCard`, testando Intel HDA com o mesmo backend PulseAudio. Trata-se de **hipótese de recuperação de infraestrutura**, não causa raiz comprovada nem áudio corrigido por evidência. O APK, o Android API 35 e os critérios RGB/PCM/440 Hz continuam iguais. Se o dispositivo alternativo não funcionar, a checagem obrigatória deve falhar; nenhuma aprovação é inferida da troca de driver.

Acrescentadas leituras opcionais de `/proc/asound/cards` e `/proc/asound/pcm` via `su 0` no guest userdebug, sem reiniciar `adbd`. Saída e erros são preservados. A indisponibilidade desses diagnósticos não aprova nem reprova reprodução por si só. Permitem confirmar qual cartão o guest realmente detectou, que antes ficava inacessível ao usuário shell.

## Validação

Os 35 testes locais do laboratório passaram e `git diff --check` não apresentou erros. O ciclo anterior mantém 20 testes Python de ferramentas e 30 Node aprovados. Nenhum teste local executa Android: o ambiente não tem `/dev/kvm`. O resultado do novo experimento deve vir do CI e não foi presumido.

## Firebase

A busca de integrações confirmou Firebase instalado e habilitado. Os recursos operacionais expostos nesta sessão são habilidades; não há ferramentas remotas Firebase disponíveis na lista atual. CLI oficial **15.34.1** verificada via `npx -y firebase-tools@latest --version`, com Node v24.22.1. `login:list --json --non-interactive` retornou sucesso e **nenhuma conta autenticada** neste ambiente. É necessária autorização Google para acessar o projeto experimental; não houve mudança de projeto, criação, implantação ou alteração de OAuth.

O próximo passo de login real continua condicionado a uma sessão autorizada, chave LAB estável e JSON experimental atualizado com o SHA-1 Android. Não reutilizar códigos de autorização de conversas anteriores nem assumir que a instalação do plugin fornece autenticação à CLI deste ambiente.

## Alterações

- `.github/workflows/player-lab-device.yml`
- Este relatório.

Estado: compilação VERDE; áudio AMARELO com falha histórica de infraestrutura ainda não resolvida por evidência; Firebase AMARELO por autenticação/configuração pendentes. Lançamento comercial não homologado.
