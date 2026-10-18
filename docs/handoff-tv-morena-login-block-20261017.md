# Passagem de plantão — APK TV Morena bloqueado no login (2026-10-17)

## Evidência física
Usuário instalou APK de teste e enviou screenshot: tela Rocha+, botões Google e Apple cinza; mensagem **“O login ainda não foi ativado nesta versão. Aguarde a atualização.”** Não é possível acessar catálogo nem testar TV Morena. Build verde não prova usabilidade.

## Histórico
- Base de referência aprovada: checkpoint/mobile-sbc-kids6-approved-20261017; 192 canais anteriores.
- Branch isolada: test/tv-morena-source-review-20261017.
- Commit inclusão catálogo: 48ffa47af0173fd2c7867e5f630e969813912f65; três variantes de TV Morena 5290, 5291, 5292, com status experimental e uso somente pelo dono.
- Workflow de compilação criado: .github/workflows/tv-morena-test-apk.yml (commit 579a6710ec4ef919bcb040ad1bb528d4c2cae899). Faz flutter build apk --debug, sem configurar autenticação Firebase; provável causa do bloqueio.
- Nenhuma fonte TV Morena validada com áudio, vídeo ou permissão; não marcar canais como funcionais.

## Próxima execução requerida
1. Identificar no código quais condições bloqueiam botões e impedem acesso ao catálogo.
2. Gerar build de teste com autenticação real usando configuração/assinatura existentes com segurança, ou mecanismo *estritamente isolado para desenvolvedor* que permita testar catálogo sem alterar produção. Nunca contornar acesso ou pagamentos em release pública.
3. Executar testes pertinentes e compilar APK de teste instalável, com appId separado; confirmar que login e catálogo abrem.
4. Testar TV Morena; registrar falhas e resultados. Não tocar em branches freeze nem pagamentos, favoritos, identidade visual ou APK congelado.

Status: BLOQUEADO. Corrigir antes de declarar conclusão.
