# Rocha+ — restauração do login experimental (18/10/2026)

## Causa confirmada

O workflow anterior compilava somente com `ROCHA_LAB_TEST=true`. Não fornecia as cinco definições Firebase/Google nem a assinatura estável. `FirebaseAuthRepository.initialize()` detecta os quatro campos Firebase vazios e retorna “O login ainda não foi ativado nesta versão”. O APK auditado anterior contornava isso intencionalmente abrindo a Home local sem autenticação.

Apenas recolocar a tela não ativa Google. O pacote anterior `com.rochaplus.labaudit20261018`, assinado com chave debug temporária, também não é automaticamente reconhecido pelo cadastro OAuth de outro pacote/certificado.

## Correção

- O modo experimental agora exige sessão por padrão (`ROCHA_LAB_REQUIRE_LOGIN=true`). Entrada local só pode ser selecionada explicitamente nas compilações de regressão automatizada.
- Inicializa o mesmo controlador/repositório Firebase oficial; só eventos de sessão confirmada liberam Home. A UID real é passada ao isolamento existente de favoritos. Expiração/logout remove rotas privadas; sem mudança no repositório de favoritos.
- O APK final usa o pacote de testes já cadastrado `com.rochaplus.soultvtest` e a assinatura estável existente. Nome visível: **Rocha+ R.L Login TESTE**; versionCode 6001.
- A configuração é consultada em modo somente leitura. Falta do cadastro, SHA ou vínculo OAuth interrompe a compilação. Nenhum cadastro, certificado, provedor, regra, conta, assinatura ou configuração de produção é criado/alterado por esse script.
- Os segredos de assinatura e a configuração Firebase são usados somente no runner e removidos ao final. Não são publicados como artefatos de configuração.
- Catálogo R.L experimental e tolerância de player permanecem ativos; fluxo comercial e pagamentos permanecem fora do APK de laboratório.
- A mitigação de renderização/tooltip da auditoria anterior permanece no laboratório.

## Verificação

Testes adicionados: login obrigatório, conclusão do popup sem sessão, falha de inicialização, UID real, remoção de rotas na expiração, troca de conta e logout. Os testes usam provedor simulado e não demonstram autenticação Google real.

Também há verificação Android do APK assinado: tela de login, botão Google habilitado, retrato/paisagem e reabertura; sem selecionar conta de usuário. O APK de regressão local serve somente para testar Home/Infantil/rotação sem credenciais e está identificado como SEM LOGIN.

Commit em validação: `6676b9b019647cfdf192ff978df7813969ea5b52`.
Execução: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/39121802056

Verificações locais: 21 testes Python, 2 testes Node, sintaxe Python/Node e YAML aprovados. No runner: `flutter analyze` sem problemas; 164 testes gerais passaram (8 testes exclusivos de laboratório ignorados), 3 testes de sessão autenticada passaram e 8 testes de renderização/catálogo/player de laboratório passaram. A consulta somente leitura do cadastro Firebase existente, SHA do certificado e vínculo OAuth passou no job assinado. A execução concluiu os três jobs com sucesso.

- APK release assinado: `RochaPlus-RL-LOGIN-TESTE`, artefato `12135116429`.
- SHA-256 do APK: `c2d4dc2c6052b71f801642d8b65440b74d0752d3bf0ca1a79e6ef47d547c9c5d`.
- Android API 35, APK real: login obrigatório, Google habilitado, retrato, paisagem e reabertura, sem exceções Flutter verificadas nos logs. **Nenhuma conta Google foi selecionada no emulador.** Evidências: artefato `12135011759`.
- Android debug de regressão: Home → Infantil (21 canais) → Home → rotação; quatro inicializações sem erros Flutter. Evidências: artefato `12134741560`.
- Assinatura APK v2 verificada, pacote de testes e versionCode 6001 conferidos pelo aapt.
- Comparação com o checkpoint passou para autenticação oficial, pagamentos, favoritos, branding, catálogo aprovado/quarentena e backend. A branch congelada segue em `e8b4c057f5a29c4edae6ea81f54f61eeed8f0163`.

O artefato `RochaPlus-LOCAL-SEM-LOGIN-apenas-regressao` é apenas evidência auxiliar de renderização, **não é o APK com login entregue**.

## Limites físicos

É necessário selecionar a conta Google no aparelho, confirmar que entra na Home, reabrir para conferir persistência, sair e entrar novamente, além de reproduzir canais após autenticar. A aprovação física do APK anterior não prova o novo fluxo. A troca de canais por controle remoto durante espelhamento continua sem validação e não é alterada por esta correção.

APK 4005 e branch congelada preservados. Sem publicação comercial.

## Observações da validação

A primeira execução passou análise, 164 testes gerais e os 8 testes locais; dois testes novos de sessão expiraram em `pumpAndSettle` ao aguardar I/O de catálogo sob relógio simulado. Eles foram ajustados para verificar as transições de rotas/sessão com frames delimitados, como já ocorre nos testes oficiais de sessão. A renderização/carga completa continua coberta separadamente. Não se atribuiu esse timeout artificial ao login Android nem se alterou o player por isso.
