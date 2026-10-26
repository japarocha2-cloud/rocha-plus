# Rocha+ — auditoria experimental de acesso — 26/10/2026

## Evidência e escopo

Base: f6d39f89361136c3683598070e50f33a8fe7b67b, branch experimental feat/dual-player-lab-20261020. APK 686 permanece a entrega de teste, com SBT nos destaques e bloqueio de assinatura desativado. Nenhuma alteração em preço, pagamento, configuração Firebase, versão congelada ou publicação.

## Resultado desta rodada

- Backend: 30 testes aprovados, zero reprovados, zero ignorados. Inclui sete dias por UID sem reinício, vencimento, negação sem confirmação, confirmação administrativa, duplicidade e estorno. Verificação positiva e persistência ainda usam doubles; sockets HTTP locais são reais e os testes negativos de token usam SDK Firebase Admin real.
- Ferramentas: 29 testes aprovados, zero reprovados. Inclui dois novos cenários de regressão do relatório de homologação. A saída de certificado inválido é intencional no teste negativo.
- Fiscal estático: aprovado; git diff --check: aprovado.
- Novos campos em homologation.json distinguem bloqueio configurado e endpoint configurado. Não revelam URL nem credenciais. Configuração não equivale a execução no aparelho: pagamento e vencimento continuam explicitamente pendentes.
- Metadados ausentes, tipos incorretos ou combinação inconsistente impedem gerar relatório de sucesso. Preparação e verificação devem ser executadas na mesma revisão. Relatórios históricos não são reescritos.

## Pendências de homologação

| Setor | Status | Condição para aprovação |
|---|---|---|
| Regras de acesso locais/backend | VERDE nos testes automatizados | Resultados acima, sem extrapolar para nuvem |
| Integração Firebase e assinatura | AMARELO | Endpoint HTTPS experimental implantado e validado, token legítimo/revogado, persistência Firestore e isolamento IAM/regras |
| Sete dias e pagamento no app | AMARELO | APK experimental com bloqueio ativado, conta de teste, vencimento, reinício, reinstalação, confirmação confiável e estorno ponta a ponta |
| Android TV/TV Box/Cast | AMARELO | Testes físicos de controle, áudio, parada e reconexão |
| Lançamento comercial | BLOQUEADO | Integração e testes acima, autorizações dos canais; nenhuma publicação autorizada neste ciclo |

O backend segue não implantado por esta rodada. Nenhum pagamento real foi confirmado. Não ativar bloqueio comercial em um APK sem serviço de direitos validado.
