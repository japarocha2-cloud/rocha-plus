# Rocha+ — auditoria de continuidade e critérios de entrega (12/10/2026)

> Registro de referência para impedir regressões e retrabalho. Não equivale a confirmação de funcionamento físico.

## Comprovado pelo usuário
- Android: build #147 reproduziu SBT Interior via Cast na televisão. Recuperar descoberta, conexão e envio de mídia sem reinstaurar layout antigo.
- Roku: V1 instalou, abriu, fechou e respondeu à navegação com controle remoto. É um protótipo sem catálogo real; não repetir esse teste básico sem motivo.

## Marcos que não podem ser confundidos
- Build #353: backup congelado segundo histórico; sua existência/artefatos devem ser auditados antes de afirmar nova baseline.
- O APK "universal" é universal dentro de arquiteturas Android compatíveis, não Roku, Tizen ou webOS.
- CI e geração de APK NÃO certificam Cast, vídeo, áudio, estabilidade ou UI em TV física.

## Pontos ainda pendentes
1. Catálogo: manter os 11 bloqueios históricos já presentes em `channel_repository.dart`. O scanner por HEAD mede alcançabilidade e NÃO prova reprodução. Catálogo de demonstração só deve mostrar URLs explicitamente aprovadas por reprodução real + direitos de uso. `ROCHA_VERIFIED_ONLY=true` ativa o modo restritivo na branch de correção; nenhuma URL deve ser ficticiamente aprovada.
2. Bloqueios/quarentena: `_sessionFailedUrls` não persiste entre sessões. Definir registro durável com evidências de falha, versão da URL e diagnóstico. Diferenciar falha de rede, codec/DRM, geobloqueio, autorização e indisponibilidade da fonte.
3. Cast: comparar com #147 e recuperação descrita em `docs/candidate-validation.md`; confirmar detecção, conexão, vídeo+áudio e reconexão, sem exigir testagens repetidas do usuário.
4. Roku: V1 provou somente estrutura/navegação. V2 de player ainda não foi validada fisicamente; criar aplicação própria com SceneGraph, player, Home, foco de controle, categorias, loading/error e somente fontes Roku compatíveis e licenciadas. Não afirmar canais ao vivo prontos.
5. UI: preservar visual Home cósmico e os assets aprovados; não substituir por mockups que não correspondam ao app.
6. Comercial: assinaturas/pagamentos/Play Store e CazéTV são frentes separadas e não devem ser declaradas prontas sem integração e evidência. GanheBR e links de apostas não devem ser embutidos sem revisão regulatória.

## Critérios de um único próximo teste físico consolidado
- Confirmar de antemão builds, artefatos, hashes, testes automáticos e screenshots de layout.
- Uma rodada com o dispositivo disponível: abrir app, navegar, iniciar canais previamente aprovados, obter imagem e som, testar fullscreen/voltar e estabilidade.
- Resultado por canal/fonte: aprovado, instável, não validado ou bloqueado, indicando aparelho e protocolo.
- Evitar testar canais desconhecidos com usuário final.

## Política de comunicação
- Reportar com precisão: código escrito, PR aberto, CI aprovado, APK gerado, teste físico realizado. Não atribuir trabalho em segundo plano.
- Não prometer entrega em horário futuro sem execução real.
- Não solicitar ao usuário repetir provas já suficientes.
