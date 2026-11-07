# Login Firebase isolado — avanço do plantão

Somente branch `feat/dual-player-lab-20261020`, a partir de `f200c1a2f2c1780b2fd142c771ba176df8700cf8`. Sem alteração da versão congelada, preços, cobrança ou configuração Firebase oficial.

## Resultado observado no CI anterior

[Build 672](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40248264144): **os dois jobs concluíram com sucesso**. Geração do APK, verificação do certificado corrigida, upload do artefato experimental e observação de rotas de categorias no Android passaram. Isso comprova que o erro de leitura `V2 Signer:` foi removido nessa execução. Esse verde não equivale a aprovação de áudio ou login físico, nem valida o novo fluxo assinado deste ciclo.

## Novo fluxo de homologação

O workflow existente `Build Rocha+` recebe a opção manual `homologation_login=true`, com padrão **false**. Na branch experimental ela chama `.github/workflows/homologation-login.yml`, reutilizável; o job Android habitual é desativado somente nessa escolha. Os fluxos habituais de PR e do projeto oficial mantêm suas opções anteriores. O preparador original `prepare_signed_build.py` não foi alterado.

O fluxo novo:

1. Aceita exclusivamente `rocha-plus-homologacao` e o cliente Android `com.rochaplus.app.lab`.
2. Converte o `google-services.json` experimental para as configurações Dart efetivamente usadas pelo aplicativo, com cliente OAuth web inequívoco.
3. Exige cadastro OAuth Android com SHA-1 válido; não assume que cliente web sozinho configure login Android.
4. Usa chave LAB dedicada e instala com pacote `.lab` e nome `Rocha+ Homologação`, preservando a instalação oficial. Não abre a aplicação de player LAB sem login; usa o fluxo normal de autenticação.
5. Mantém assinatura obrigatória de pagamento desativada por padrão. O teste opcional de bloqueio exige a opção explícita anterior e endpoint HTTPS. Não implanta backend nem comprova pagamento.
6. Depois de compilar, lê o pacote real com `aapt`, verifica criptograficamente o APK com `apksigner` e exige que os certificados correspondam aos fingerprints do JSON enviado. Um APK do pacote oficial ou de chave não cadastrada não pode ser enviado como homologação válida.
7. Envia apenas APK e relatório sem credenciais para artefato de teste, após verificações. Não cria Release, não publica na loja e não promove versão. A execução é manual; não foi disparada neste ciclo.

## Secrets necessários e condição real atual

- `ROCHA_LAB_GOOGLE_SERVICES_JSON`: JSON completo do app experimental, baixado novamente após cadastrar o SHA-1 da chave LAB.
- `ROCHA_LAB_KEYSTORE_BASE64`, `ROCHA_LAB_KEYSTORE_PASSWORD`, `ROCHA_LAB_KEY_ALIAS`: chave exclusiva de testes. Não reutilizar assinatura debug temporária de runner.

O arquivo enviado pelo usuário foi validado localmente **sem imprimir valores privados**. Ele contém projeto/pacote corretos e cliente web, porém não contém o cliente OAuth Android com SHA-1 requerido. O preparador agora rejeita essa condição antes de gerar arquivos privados ou APK, com instrução de cadastrar a assinatura e baixar novamente a configuração. Este é um bloqueio de configuração real, não um teste de login reprovado.

Não foi possível confirmar ou alterar o console Firebase e os secrets do GitHub com as ferramentas operacionais expostas nesta sessão. Nenhuma credencial foi criada, alterada ou exposta. O código não fornece bypass quando essas configurações faltam.

## Validação e limites

20 testes de ferramentas Python passaram (incluindo seis testes novos de homologação); os 35 testes Python de laboratório e 30 Node permanecem aprovados na mesma base: **85 testes locais aprovados, zero reprovações ao final**. Os novos casos rejeitam projeto oficial, pacote incorreto, ausência de OAuth Android, cliente web ambíguo, app/sender inconsistentes, execução fora da branch ou sem secrets, APK com pacote/certificado incorretos e falha de verificação criptográfica. Validam também que o JSON externo não ativa laboratório sem login nem cobrança.

YAML dos workflows validado, fiscal estático aprovado e `git diff --check` limpo. Geração/verificação de APK nos novos testes usa executáveis simulados. O novo fluxo assinado ainda não foi compilado nem exercitado com a chave/Firebase real. Nenhum teste físico realizado.

## Arquivos deste avanço

- `.github/workflows/build.yml`
- `.github/workflows/homologation-login.yml`
- `tools/prepare_homologation.py`
- `tools/test_homologation.py`
- Este relatório.

## Pendências

Conferir conclusão do CI corrigido, completar cadastro da assinatura OAuth Android e secrets LAB, executar manualmente o fluxo experimental e testar login em celular/TV. O laboratório audiovisual permanece condicionado ao gate de 440 Hz e aos erros de áudio HAL identificados; não aprovar canais nem testes físicos por inferência.
