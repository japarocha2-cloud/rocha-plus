# Rocha+ Asaas — APK adicional em preparação

Base preservada: freeze/mobile-4107-approved-20261015, commit 999b104e9034449d0c6815d21258848a8efba7e3.
Branch independente: feat/mobile-asaas-550-20261015.

Decisão do titular: mensal Asaas R$ 5,50. Anual mantido em R$ 55,00.
O build define ROCHA_ASAAS_VARIANT=true. Sem esse define, a variante Mercado Pago mantém R$ 4,90 e seus links existentes.
A tela de assinatura e o preço do aviso de trial (inclusive acessibilidade) usam a mesma configuração.
A arte original permanece intacta; o preço rasterizado é coberto por texto nativo somente no build Asaas.

Este APK ainda NÃO cobra pelo Asaas. Botões de contratação desativados e ambas as implementações de checkout bloqueiam qualquer tentativa de usar o Mercado Pago nesta variante. Nenhum segredo Asaas, plano, cobrança ou acesso pago foi criado. Backend Mercado Pago e regras de acesso não foram alterados.

Próxima etapa após cadastro: configurar credenciais privadas, checkout hospedado, vínculo entre cliente/cobrança e identidade autenticada, consulta autenticada dos pagamentos e processamento idempotente de confirmação/reembolso; testar em sandbox antes de produção. Não basta trocar um link.

A identidade Android com.rochaplus.app e assinatura oficial são mantidas para preservar o login Firebase existente. Os dois APKs são arquivos separados, mas ocupam a mesma instalação Android: instalar este candidato atualiza o app no aparelho. Instalação simultânea exige registrar outra aplicação Android/OAuth no Firebase; isso não foi configurado. Para preservar também a instalação aprovada, testar o candidato em outro aparelho.

Trial e aceite continuam vinculados à mesma conta no servidor, sem reiniciar os sete dias. Catálogo, favoritos, cast, capas e banner Baú continuam os da base aprovada.

## Evidências concluídas

Build assinado 4204: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/38847582271
Código compilado: dc08e0e85fa410c104aec67d882ef94014959dcd.
Análise estática aprovada. 42 testes herdados de autenticação/acesso/assinatura e 3 testes Asaas aprovados, sem skips nesses comandos. Não foi repetida a suíte completa com falhas de layout preexistentes.
Captura visual renderizada com a arte original foi inspecionada: mensal R$ 5,50 e anual R$ 55,00 legíveis.
Metadados Android: versionCode 4204, label Rocha+ Asaas, mesma identidade e assinatura oficial; apksigner e integridade ZIP aprovados.
APK SHA-256: f7d7540efab8a2eaf14997b91d3992179054b462848296923f0e04f01b94639b (78.549.706 bytes).
Nenhum pagamento efetuado, plano/preço remoto modificado ou documento de produção alterado.
Validação em aparelho físico e integração Asaas continuam pendentes. Não homologado para cobrança.
