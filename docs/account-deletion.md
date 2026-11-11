# Exclusão de conta — preparação para Play Store

O menu da sessão autenticada passa a oferecer Excluir conta. O diálogo exige confirmação explícita e esclarece que a conta Google/Apple não será excluída. O Firebase exclui apenas o usuário atualmente autenticado; não há seleção de outra identidade durante a operação. Login recente exigido pelo Firebase gera orientação para sair e entrar novamente na mesma conta.

Após confirmação do Firebase, os favoritos locais são apagados e a sessão Google local é encerrada. A falha de armazenamento local depois da exclusão remota ainda precisa de validação de apresentação ao usuário, pois a mudança de sessão pode desmontar a tela. A exclusão remota não é revertida por essa falha.

Testes adicionados: falha preserva sessão; sucesso remove sessão; cliques concorrentes geram uma operação; usuário sem sessão não pode excluir. CI deve confirmar análise e testes. Não foi executada exclusão de uma conta real.

Pendências para publicação: validar com conta descartável no APK assinado, publicar página externa de solicitação de exclusão e política de privacidade com operador e retenção confirmados; verificar outros dados eventualmente armazenados pelo backend. Esta mudança não certifica conformidade completa nem autoriza publicação.
