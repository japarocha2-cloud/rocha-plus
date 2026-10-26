# Cadastro confirmado; conteúdo do secret precisa de correção

O usuário salvou `ROCHA_LAB_BUNDLE_JSON`. A lista de secrets e o aviso `Repository secret added` confirmaram a criação; nenhum valor privado foi aberto no GitHub.

Foram iniciados builds manuais de homologação na branch experimental, com login isolado ativo e assinatura de pagamento desativada. [Build 676](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40252744985) falhou na preparação, com `JSONDecodeError`; backend passou e o job Android habitual ficou pulado conforme o modo isolado. O diagnóstico adicional seguro identificou um objeto JSON com 6163 caracteres, inválido na linha 2/coluna 13. [Build 678](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40253239131) confirmou a falha de formatação. Não foi produzido APK nesses builds.

O leitor passou a aceitar BOM, cercas de código e JSON serializado como string, sem remover as validações de projeto/pacote, campos exatos, chave, alias, certificado ou pagamento. Isso não recuperou o conteúdo salvo. Foi preparado um arquivo privado alternativo em texto ASCII, com prefixo `ROCHA_LAB_V1:` e o mesmo bundle codificado em base64. Esse transporte não é criptografia nem torna o conteúdo público: continua sendo credencial privada, destinada exclusivamente ao campo Secret. Evita a cópia de aspas e escapes JSON pelo usuário.

O conteúdo alternativo foi decodificado e validado localmente contra a mesma chave e senha originais. O leitor exige base64 íntegro, UTF-8 e JSON válido e aplica todos os controles anteriores após decodificar. Os 27 testes de ferramentas passaram, incluindo transporte, corrupção e rejeição do projeto oficial; `git diff --check` passou. Os certificados cadastrados no Firebase não foram modificados.

Pendente: o usuário precisa substituir o conteúdo do secret pelo texto integral do novo arquivo e salvar. Essa entrada e envio de credencial exigem intervenção do usuário pela política do navegador. Só depois iniciar um build manual na revisão que contém o leitor atualizado. Não reexecutar build antigo esperando receber código novo, nem afirmar login/compilação homologados antes do resultado.

Sem modificação da versão congelada, preços, pagamentos ou configuração oficial. Arquivos privados permanecem fora do Git. Arquivos de código alterados: `tools/lab_credentials.py`, `tools/test_lab_credentials.py` e diagnóstico em `tools/prepare_homologation.py`.
