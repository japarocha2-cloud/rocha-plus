# Rocha+ LG webOS / Samsung Tizen

Base web existente, com pareamento aprovado pelo celular, validade consultada no servidor, catálogo da #510, favoritos por UID e exclusões persistentes por URL. O adaptador de conta é exportado de `platforms/shared/account.js`. O vídeo de abertura e recursos oficiais são reaproveitados da base Android.

Sem URLs configuradas, o app bloqueia o acesso. Não existe fallback para catálogo experimental nem assinatura local fictícia. Configure os serviços com `tools/configure_tv_services.py` antes de testar.

Esta fonte possui teste automatizado do adaptador e validação de sintaxe. Não é uma afirmação de compatibilidade física: empacotamento/assinatura pelos SDKs LG/Samsung, políticas de reprodução HLS, autoplay com áudio, controle remoto e expiração ainda precisam de validação na TV. Consulte `docs/payments-and-platforms.md`.
