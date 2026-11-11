# Favoritos na conta Rocha+
Os favoritos de usuários autenticados ficam em users/{Firebase UID}/favorites/{SHA256 da identidade do canal}. Home destaca "Meus favoritos" antes do carrossel e lista todos, sem limite de dez. Home e TV ao Vivo compartilham a mesma sessão e observam atualizações. Canais ocultos/quarentenados continuam respeitando os filtros do aparelho; o registro favorito não é apagado.

Cada documento guarda nome, endereço, grupo, logo e horário de adição. A identidade normalizada do nome preserva seleção quando a URL/resolução muda. Nomes normalizados iguais representam um favorito; um catálogo com canais distintos de mesmo nome requer IDs fornecidos pelo catálogo em trabalho futuro. A ordem de adição é preservada; não foi acrescentado arrastar/reordenar.

No Android, o cache persistente do Firestore mantém leitura offline e enfileira alterações. A interface diferencia cache, salvamento pendente, confirmação do servidor e erro. Apenas favoritos confirmados no servidor podem ser recuperados após desinstalar. Desinstalar offline antes de sincronizar pode perder mudanças pendentes. Em aparelhos novos, entrar com a MESMA conta Firebase é obrigatório. Logout não apaga documentos; troca de UID recria o repositório e as rotas.

Favoritos antigos em SharedPreferences não são atribuídos automaticamente. A tela oferece importação com confirmação explícita. Documentos existentes são preservados e gravações esperam confirmação do servidor; a cópia antiga permanece no aparelho para recuperação de canais ausentes.

## Configuração manual e validação real pendentes
1. Criar/habilitar Firestore no mesmo projeto Firebase do login Android. Conferir região e custos antes de habilitar recursos.
2. Revisar e integrar o match users/{uid}/favorites/{id} de favorites/firestore.rules às regras do projeto, mantendo as regras privadas de assinatura/tokens do PR #14. NÃO substituir regras existentes por esse arquivo isolado nem permitir regras abertas. O emulator testa esse arquivo isoladamente; regras combinadas precisam de novos testes.
3. Publicar as regras integradas somente após revisão; este PR não publica regras nem serviços. Nenhum índice composto necessário.
4. Gerar beta com Firebase/assinatura configurados e testar dois aparelhos com mesmo UID: adicionar/remover canais, aguardar "Favoritos salvos na sua conta", reinstalar, entrar novamente e conferir lista/ordem.
5. Testar outro UID, logout, perda de conexão, pendência, rejeição de permissão e mudança de URL. Confirmar que acesso de reprodução segue o gate de assinatura quando integrado ao PR #14; favoritos não concedem direito de reprodução.
6. Ao combinar com PR #14, preservar AccountFavorites ao redor de SubscriptionGate/HomeScreen e injetar o repositório na Home. Ambas as branches alteram app.dart e exigem resolução de conflito e repetir testes.

## Evidência
Testes Dart usam servidor em memória: restauração após apagar armazenamento local, dois clientes, remoção, isolamento, sessão expirada, mudança de URL, ordem, falha, pendência, cache, migração e descarte. Testes de widgets verificam destaque, lista acima de dez, navegação com o mesmo repositório e metadados quando catálogo omite canal. Firebase Emulator verifica regras de leitura/escrita/remoção, anonimato e campos inválidos.
Esses testes não comprovam sincronização do aplicativo em Firebase de produção. APK de PR é prévia visual sem login/canais reais. Reprodução, fullscreen, Cast, scanner, Infantil e Notícias precisam de teste físico no beta configurado; as suítes existentes continuam executadas no CI.
