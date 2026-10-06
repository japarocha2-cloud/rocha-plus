# Rocha+

Aplicativo Flutter focado em TV ao vivo pública ou devidamente autorizada, com experiência para celular, Android TV / Google TV e Google Cast.

## Fluxo atual

Vinheta cinematográfica real → entrada → catálogo de TV ao vivo → player → fullscreen / Google Cast.

## Componentes ativos

- identidade visual Rocha+;
- vinheta real em vídeo separada do ícone do launcher;
- catálogo remoto com cache local e preferência por feeds mais estáveis;
- acesso rápido com canais reais;
- busca/filtros e favoritos;
- player local responsivo com fullscreen;
- feedback de buffering e uma tentativa automática de recuperação em buffering prolongado;
- Google Cast com validação de sessão e confirmação de reprodução real;
- relay HLS local usado somente como fallback e encerrado após uso/falha;
- suporte de interface para celular e telas largas;
- compatibilidade de launcher Android TV / Google TV;
- Quality Guard antes e depois dos testes;
- auditoria Rocha+ Support em cada build;
- geração de APK universal, APK ARM64 e AAB.

## Equipe de suporte do projeto

- Coordenação principal: programação, arquitetura e desempenho.
- Suporte 1: Qualidade, limpeza, regressões e código morto.
- Suporte 2: Visual, responsividade e expansão.
- Suporte 3: Documentação, publicação e jurídico.
- Suporte 4: Testes físicos e compatibilidade.

## Estado de publicação

A documentação-base de privacidade, termos, ficha de loja, inventário de dados e matriz de testes já existe em `docs/`.

O login oficial Google e Apple permanece propositalmente para a fase final, depois da validação visual, desempenho e testes físicos.

## Regra de manutenção

O projeto deve manter apenas caminhos ativos. Arquivos antigos de branding, introduções substituídas, implementações abandonadas e código comprovadamente sem uso devem ser removidos. Build verde não substitui teste físico de player, Cast, fullscreen, vinheta e navegação em TV.
