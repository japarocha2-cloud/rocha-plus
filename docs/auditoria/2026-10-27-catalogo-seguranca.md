# Correções seguras de catálogo — 27/10/2026

Escopo exclusivo: `fix/subscription-access-20261026`, PR #42 em draft.
Sem merge, publicação, APK novo, implantação, cobrança ou escrita em pagamentos reais.

## Correções
- Removida lista fixa de 11 nomes sem evidência por URL, dispositivo e data. Isso não homologa reprodução nem distribuição; bloqueios escolhidos pelo usuário permanecem.
- Parser e agregação deduplicam pelo par URL exata + identidade normalizada. Nomes regionais distintos e URLs alternativas são preservados. Par estruturado evita colisão por delimitador.
- Cache guarda catálogo antes de ocultações locais. Ocultar todos retorna lista vazia; restaurar usa o cache mesmo offline. Falhas e respostas vazias mantêm o cache da própria fonte.
- Atualizadas expectativas antigas que ainda exigiam exclusão por nome, fusão de nomes distintos ou reprovação por HEAD 503.
- Acrescentadas regressões de cache, alternativas regionais, 11 nomes históricos, controle remoto TV e confirmação/falha/identidade de mídia no Cast.

## Verificação
CI ampliada para suíte Flutter completa, análise dos dois arquivos de implementação,
política experimental de assinatura, testes Node de funções e entitlement com HTTP local,
e testes Python de configuração Android celular/TV.
Geração e upload de APK desativados neste workflow durante a auditoria.
Resultados devem ser conferidos na execução do commit; não inferir sucesso da configuração.

## Limites
Mocks de Cast e teclado não substituem Chromecast e Android TV físicos.
HEAD não comprova áudio/vídeo; cache não comprova disponibilidade atual.
Sem exclusão de canais por falhas transitórias e sem homologação audiovisual nova.
Nenhuma função foi removida por parecer sem uso. Backend e regras de pagamento não foram alterados.
