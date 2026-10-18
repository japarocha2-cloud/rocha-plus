# Retomada do canal após desconexão Cast — 16/10/2026

Sintoma relatado: a transmissão para a TV fecha e o canal fica pausado; ao voltar ao canal ele funciona. Isso não identifica a causa do encerramento da sessão nem comprova falha da internet.

Base preservada: APK 4107 aprovado, commit 999b104e9034449d0c6815d21258848a8efba7e3. Alterações isoladas em fix/cast-disconnect-resume-20261016.

## Correção
O player registra a pausa que ele próprio fez ao transferir a reprodução à TV e passa a observar a sessão Cast mesmo depois de sair dos controles. Ao perder a conexão, libera o relay e solicita reprodução local automaticamente. Se o controller já tem erro ou o comando de reprodução falha, reinicializa o canal. A recuperação não atua depois de o player ser desmontado nem depois de uma tentativa mais recente tomar seu lugar.

Os controles da TV agora observam a sessão, acionam a retomada e saem da tela após a perda. O caso em que a sessão cai entre a confirmação e a abertura da tela também é tratado. Eventos duplicados não executam a mesma retomada novamente.

A pausa local enquanto a TV está transmitindo continua sendo necessária para não tocar áudio duplicado. Esta correção elimina a pausa abandonada depois do Cast, não remove os controles de pausa voluntária aprovados.

## Limites
Não reconecta automaticamente à TV e não prova nem corrige a causa do encerramento da sessão. Não afeta espelhamento do sistema Android: o caminho tratado é o Google Cast do Rocha+. Teste físico ainda necessário para confirmar o caminho utilizado e o resultado no aparelho. Sem alteração de assinatura, prazo, canais, preços ou backend.

## Validação
Testes de tela para perda de sessão, eventos duplicados, queda antes da abertura e desmontagem da área privada, junto das regressões de acesso e Cast. Análise estática aprovada; 37 testes Flutter e 5 testes Node aprovados. Evidências: https://github.com/japarocha2-cloud/rocha-plus/actions/runs/38982860834. São testes automatizados, sem TV física.
