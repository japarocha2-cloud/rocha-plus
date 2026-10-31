# Rocha+ TV — laboratório isolado de vencimento (planejamento)

Data: 2026-10-31. Branch exclusiva: `lab/trial-expiry-isolated-20261031`.

## Objetivo
Preparar validação física acelerada do bloqueio de trial sem alterar a candidata .6 instalada, seu trial real ou a versão oficial.

## Evidências preservadas
- CI Trial sandbox gate integration `41222167987`: trial de sete dias, vencimento exato e bloqueio em emulador aprovados.
- O preparador `tools/candidate/prepare_candidate.py` usa `ROCHA_CANDIDATE_SUBSCRIPTIONS=false` por padrão; quando ativado, exige endpoint do Firebase candidato. Isso **não é** isolamento local completo.
- O mesmo preparador define `ROCHA_LAB_ONLY=false`, exige branch de homologação e verifica a identidade da candidata; não deve ser reutilizado sem adaptação e revisão para gerar um pacote de laboratório.
- `tools/candidate/identity.json` ainda descreve `0.1.0-candidate.1`; não comprova a configuração do APK .6 instalado.

## Portões obrigatórios antes de alterar código ou compilar
1. Identidade de pacote exclusiva do laboratório, diferente de `com.rochaplus.app.candidate` e `com.rochaplus.app`.
2. Backend somente local/emulado; bloquear por padrão qualquer endpoint externo, incluindo Firebase real e Mercado Pago. Sem pagamentos reais.
3. Configuração de gate habilitada exclusivamente no build de laboratório e verificável no artefato.
4. Assinatura de laboratório distinta da candidata e da versão oficial; não criar/substituir chaves existentes sem aprovação.
5. Nenhum acesso ou mutação nos dados do trial real. Não alterar relógio do celular.
6. Não reinstalar, desinstalar, limpar dados nem substituir a candidata .6.
7. Antes de teste físico: inspecionar pacote, versão, assinatura, SHA-256, ABI e conectividade do APK experimental.
8. Manter PR #42 draft; sem merge, deploy ou publicação.

## Próxima implementação proposta (ainda não executada)
- Revisar pontos de configuração Flutter e do endpoint para criar uma variante de laboratório que falhe de forma segura sem emulador.
- Preparar teste de configuração isolada e build experimental em ambiente Flutter/Android SDK autorizado.
- Executar teste físico apenas com APK distinto e evidências registradas.

## Estado desta etapa
🟢 Branch isolada criada; 🟢 plano de segurança documentado; 🟡 adaptação de código, build e teste físico pendentes. Nenhum teste verde repetido.
