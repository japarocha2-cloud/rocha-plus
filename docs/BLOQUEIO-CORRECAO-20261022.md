# Correção experimental do bloqueio — 22/10/2026

## Mudanças

- A revogação invalida imediatamente permissões de carregamentos Cast em andamento. Concluir uma conexão antiga depois de revogar/reautorizar não recupera a permissão antiga.
- O gate remove as rotas e controladores locais e solicita fechamento do relay e encerramento da sessão Cast. Cada operação tem timeout; falha não libera conteúdo nem é anunciada como parada confirmada da TV.
- Novo acesso só é liberado após a limpeza remota pendente terminar com sucesso. Verificações antigas de outra conta não concedem acesso à atual.
- Cast carrega mídia com autoplay desativado e verifica a permissão antes de mandar reproduzir e durante a confirmação. O fallback de relay também verifica permissão após etapas assíncronas. Comando de reproduzir no controle Cast não é enviado sem permissão vigente.
- `ROCHA_EXPERIMENTAL_SUBSCRIPTIONS=true` habilita o gate em uma compilação experimental sem reclassificar o projeto como lançamento oficial. O beta padrão não muda silenciosamente. A CI testa a política com e sem a opção.

## Testes e limites

Foram adicionadas regressões para revogação de carregamento pendente, troca de proprietário da permissão, parada do receiver apesar de falha no relay, fechamento do relay apesar de falha no receiver, autorização negada após falha de parada, reautorização aguardando limpeza e DNS do relay concluído após revogar. A análise Flutter, os testes Flutter e o teste explícito da opção experimental passaram no CI do commit cd7f8fb. O APK LAB compilou. A observação visual não executou: o download da imagem Android falhou com “Error on ZipFile unknown archive”, antes do emulador iniciar. Não há SDK Flutter local.

O backend já contém trial imutável de sete dias por UID, relógio do servidor, confirmação administrativa auditada/idempotente, renovação e estorno, com 25 testes Node locais e de integração HTTP. Isso não comprova Firestore, tokens legítimos, revogação remota ou pagamentos reais em uma implantação.

## Ativação ainda pendente

A instalação do plugin Firebase falhou conforme imagem enviada pelo usuário. Nenhuma conexão à conta foi confirmada e nenhum serviço foi implantado. São necessários acesso ao projeto experimental, configuração do serviço de direitos, HTTPS e `ROCHA_ENTITLEMENT_URL` no APK experimental, além de teste com uma conta real autorizada e outra expirada. Não ligar a opção experimental de cobrança em um APK de distribuição antes dessa validação.

O receiver padrão do Google pode continuar com uma URL pública se o telefone perder conexão antes de enviar a parada. Um pedido de encerramento não é prova física e não equivale a revogação de mídia no servidor. Bloqueio independente do telefone exige receiver/URLs com autorização e expiração verificadas no servidor, além das autorizações dos fornecedores dos canais. Esse requisito permanece aberto.

A versão oficial congelada, preços, pagamentos reais e catálogo oficial não foram alterados.

## Preparação do APK de teste

O workflow manual agora aceita `subscription_lab=true` com `signed_login=true` e `entitlement_url`. A preparação rejeita a opção fora de `feat/dual-player-lab-20261020` e exige URL HTTPS pública, sem credenciais, query ou fragmento. Os três artefatos recebem nomes `rocha-plus-subscription-lab-*`, distintos do beta com login. A evidência de release registra a opção e o endpoint, mantendo validação física e de assinatura/pagamentos pendentes.

A configuração Firebase não controla os modos de compilação: a preparação sobrescreve `ROCHA_LAB_ONLY` e `ROCHA_LAYOUT_PREVIEW` com falso, e a opção de bloqueio deriva exclusivamente do pedido explícito. Sem esse pedido, o bloqueio fica desativado e o endpoint é apagado. Isso evita ativação acidental ou desvio do gate por valores antigos no Secret JSON.

Nove testes Python de configuração passaram localmente, incluindo sobreposição dos modos no JSON, branch incorreta e endpoints inválidos. Nenhum APK assinado com bloqueio foi gerado ou distribuído nesta etapa. A implantação Firebase e os testes reais continuam pendentes; configurar uma URL não demonstra que o serviço esteja funcionando.
