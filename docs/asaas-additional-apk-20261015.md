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
