# Execução nativa Roku LAB 0.6.7 — 03/11/2026

Instalação efetivamente executada no BRS Desktop 2.6.2, engine 2.6.1 / SceneGraph 0.6.1. Apenas dev atualizado de 0.6.6 para 0.6.7; outro canal 0.6.3 preservado. Consultas XML anexas confirmam instalação e execução. Voltar encerrou normalmente; estado final Home, portanto não afirmar app ativo após o teste.

ZIP original do commit 572733db6f9d99f4b64f59d40f28d3602b4f89ac, 4.538.188 bytes; SHA256 6ff88bbf99786163a6de80eeb18c985557ea2a68441c102d114e26ab34f3cd07 conferido antes do upload. Nenhum novo ZIP ou alteração de código nesta etapa.

Registro ECP idêntico antes da instalação e após reabertura/saída: SHA256 fa5b0212fe1cf731d095f5432e1e07cdec9bec3a7aa28941f2dcdbef1a8eebfc. Exportação bruta mantida privada no computador, sem upload. Dados, favoritos e temporizador não foram apagados ou rearmados. Isso comprova preservação do registro, não funcionamento de favoritos populados.

## Resultados observados

- APROVADO: versão instalada 0.6.7 nos endpoints e rodapé da captura.
- APROVADO: bloqueio de homologação continua fechado; Down/OK não o contornam. Mensagem: acesso LAB aguardando configuração e confirmação da conta; assinatura comercial não consultada.
- APROVADO: Voltar sai; reabertura mantém bloqueio e registro.
- PARCIAL: início, logo, galáxia, banner e Home visíveis atrás da sobreposição. Primeiro frame apenas galáxia; não constitui teste completo de splash/animação.
- BLOQUEADO: menu/categorias navegáveis, lista/capas de canais, prévia, tela cheia, favoritos funcionais, busca e PET navegável. Os rótulos Home/PET visíveis não comprovam suas telas.
- NÃO EXECUTADO: reprodução/áudio, reconexão durante mídia, sessão prolongada, dispositivos físicos, Cast, autenticação/vinculação real e desempenho físico.

Sem exceção de execução observada no trecho de console capturado. O simulador estava indisponível quando retomada a sessão e foi reaberto; causa não determinada, sem atribuir ao código. FPS real e RAM não medidos. Endpoint de FPS desta versão é fixo em zero e não é medição. Comparação quantitativa 0.6.6→0.6.7 indisponível; ambas evidências mostram bloqueio de acesso. Não declarar ganho ou regressão de desempenho.

Capturas: 067-access-block.png (primeira sessão), 067-retry.png (reabertura e tentativa OK), 067-initial.png (primeiro frame). XMLs e console sanitizado no mesmo diretório. Horários no console são os do processo; datas deste relatório seguem America/Sao_Paulo.

## Continuidade

Preservar 578 associações/607 registros; nenhum catálogo ou arte alterado. Autenticação central continua desativada. Manter CI anterior 52 backend / 34 Android / 35 checks BrightScript, sem executá-los novamente por alteração apenas documental. Fonte final C6, contrato dos pagamentos e leitura de webhook continuam pendentes conforme relatório principal. Permissões anteriormente recusadas: cloudfunctions.functions.list e logging.logEntries.list; não repetir consultas idênticas nem inferir ausência de webhook.

Próxima investigação técnica: reproduzir se consultas de direitos removem indevidamente uma reserva de reprodução em devices.mjs e no cliente Android TV. Hipótese ainda não testada, nenhuma correção aplicada; preservar regras de duas reproduções e dados comerciais.

Para reproduzir: baixar o ZIP imutável indicado no mestre, conferir hash, fazer upload apenas dev pela API do simulador sem apagar registry; consultar apps/active-app; aguardar render assíncrono, tentar Down/Select e Back. Capturar após estabilização; consulta imediatamente após Back pode mostrar estado anterior.
