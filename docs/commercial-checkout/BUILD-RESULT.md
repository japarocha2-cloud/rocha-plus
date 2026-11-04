# Resultado executado — build checkout, 04/11/2026
Branch: impl/commercial-checkout-20261104.
Implementação original preservada: 3c9214599d75637c5931f66efcf6b1a65eca1f7b.
Workflow corrigido: 172175488bcc9c9a63d1d41713ff3c454915d47c.
Lockfile resolvido pelo Flutter e registrado pelo Actions: bc7331aaaa9b161fa99b119c10ff264fb73104d7.
Validação final do código: c72369ed476683de55650498a33926a18c7a8602.
Execução: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41925878646

## Resultado
- flutter analyze: sem problemas.
- flutter test: 241 testes passaram.
- Backend Node 22: 59 testes passaram.
- Configuração isolada Python: 4 testes passaram.
- pubspec.lock registrado e preservado no artefato rocha-checkout-validation.
- Job checkout-apk: scaffold gerado com sucesso; falhou ao preparar configuração privada antes de flutter build.
- Causa comprovada nos logs: ROCHA_CHECKOUT_HOMOLOGATION_JSON vazio. Os três bindings de assinatura aparecem mascarados como configurados; seus valores não foram lidos ou exportados.
- APK não gerado; SHA-256 de APK indisponível. O artefato abaixo contém lockfile, NÃO APK.
Artefato: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41925878646/artifacts/13369212808
SHA-256 do ZIP desse artefato informado pelo GitHub: 614ef8cf143c3559836263ce31c87bc421a40577fc4e8981b5b505591f393868.

## Ação necessária fora do código
Disponibilizar por cofre/GitHub Actions Secrets o bundle ROCHA_CHECKOUT_HOMOLOGATION_JSON descrito em BUILD.md. Não enviar credenciais no chat. O bundle deve documentar a revisão e a configuração real do Firebase para com.rochaplus.app.checkout e o certificado correspondente, os endpoints HTTPS verificados de checkout e entitlement e a mesma identidade Firebase UID no backend financeiro. Sem essa evidência, não preencher URLs por suposição nem reutilizar um app Firebase de outro pacote.
A compatibilidade financeira real continua NÃO CONFIRMADA: a conferência do bundle e o teste de login/ID token/UID contra os endpoints efetivamente implantados ainda são necessários. O workflow não ativou nem implantou servidor; o estado operacional dele não foi consultado.

## Primeira compra real
Além do bundle e APK instalado/autenticado, concluir os seis pré-requisitos detalhados em BUILD.md: projeto/audience/UID e backend único; recebedor canônico; webhook HMAC e fluxo financeiro completo homologados; BRL 4,50/49,50 e pagamento único sem renovação; consulta da conta de suporte para evitar duplicidade; revisão financeira e autorização antes de habilitar servidor para compra. Não alterar Nádia, pagamentos existentes ou catálogo.
Candidata 6 preservada. Nenhum deploy, publicação, alteração de conta, bloqueio de catálogo ou cobrança foi executado.
