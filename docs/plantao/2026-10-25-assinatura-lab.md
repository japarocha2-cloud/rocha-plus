# Assinatura LAB e cadastro Firebase concluídos

Base: `8734c0f9d923e4237192228cf1a2e8b7bc9f625b`. Trabalho restrito à branch `feat/dual-player-lab-20261020` e ao projeto `rocha-plus-homologacao`. Nenhuma chave oficial, preço, pagamento ou referência congelada foi alterado.

## Concluído com evidências

- Autenticação da conta Rocha+ na CLI oficial e acesso ao projeto de homologação confirmados.
- App Android ativo: `com.rochaplus.app.lab`, ID `1:40393752948:android:1da90c9bb02e5d05b76c21`.
- Chave LAB exclusiva criada em PKCS12, RSA 3072/SHA256withRSA, senha aleatória e permissões locais restritas. Chave privada e senha não estão no Git.
- Certificados SHA-1 e SHA-256 cadastrados pelo MCP oficial Firebase, após confirmação do projeto ativo. As duas operações retornaram sucesso.
- SHA-1 público: `e1ad9a7e3b7388721756f5b7dc6195f8135cd4bd`.
- SHA-256 público: `5345c8a438838c297ee4925ec732555b8a47295992a188cc1fa53cd5c9e3f796`.
- Configuração Android recuperada novamente do Firebase; agora contém OAuth Android com SHA-1 correspondente à chave LAB e cliente OAuth web. O preparador aceitou essa configuração.
- Compatibilidade da chave real, senha, alias e configuração validada localmente com `keytool`, sem imprimir dados privados. Isso não é teste de login físico.

## Um único secret no GitHub

O CI experimental aceita `ROCHA_LAB_BUNDLE_JSON`, contendo a chave LAB e a configuração do Firebase experimental. Mantém compatibilidade com os secrets LAB individuais anteriores. Recusa projeto/pacote oficial, campos desconhecidos, configurações conflitantes, base64 inválido e injeção de novas variáveis por controles de linha.

Os campos internos são mascarados individualmente no runner antes de exportar senha/alias para a etapa Gradle. Chave e configuração continuam somente nos arquivos privados temporários e são removidas pelos workflows. O arquivo de backup privado não faz parte do repositório.

Na branch experimental, o disparo manual existente com `signed_login=true` agora chama o fluxo de homologação `.lab`. Assim, a interface já disponível de `Build Rocha+` pode iniciar o APK de homologação sem alterar o workflow congelado em main. `homologation_login=true` continua sendo uma escolha explícita equivalente. Fora da branch experimental, essa alteração não direciona compilação ao projeto de homologação.

## Validação

**89 testes locais aprovados, zero reprovados:** 24 Python de ferramentas, 35 Python do laboratório e 30 Node de direitos. Fiscal estático, YAML e `git diff --check` aprovados. Verificação adicional usou a chave real em scaffold temporário: certificado, senha e configuração compatíveis. Não houve build local Flutter, login físico ou confirmação de pagamento.

## Etapa pendente no GitHub

Inspeção da página de secrets confirmou que os secrets LAB ainda não existem. Há secrets oficiais antigos; nenhum foi aberto, lido, substituído ou removido. O formulário de novo secret foi preparado com nome `ROCHA_LAB_BUNDLE_JSON` e valor vazio.

A política do navegador exige intervenção do usuário antes da entrada, confirmação e envio de nova credencial. O usuário precisa colar o conteúdo do arquivo privado nesse campo e acionar `Add secret`. Depois, conferir o cadastro e executar manualmente `Build Rocha+`, branch experimental, `signed_login=true`, `subscription_lab=false`.

Não há APK de login homologado por este ciclo. O upload do APK de teste exige verificação do pacote real e do certificado antes de disponibilizar o artefato. APKs LAB antigos com assinatura debug temporária podem exigir remoção somente da instalação LAB para instalar a nova assinatura; o app oficial tem outro pacote e deve ser preservado.

## Arquivos do código

- `tools/lab_credentials.py`
- `tools/test_lab_credentials.py`
- `tools/prepare_homologation.py`
- `tools/lab/configure_stable_signing.py`
- `.github/workflows/build.yml`
- `.github/workflows/homologation-login.yml`
- Este relatório.
