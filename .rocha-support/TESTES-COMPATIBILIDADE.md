# Rocha+ Support • Testes e Compatibilidade

## Responsabilidades
- validar o comportamento do app em celular, tablet, Android TV e Google TV;
- verificar navegação por toque e controle remoto;
- testar Cast, fullscreen, orientação e retorno ao modo normal;
- conferir carregamento, retry, reconexão, buffering e estados de erro;
- observar regressões de layout em telas estreitas e largas;
- verificar comportamento do player após mudanças de código;
- acompanhar compatibilidade entre versões do Flutter e plugins críticos.

## Limites
- não alterar lógica de negócio sem coordenação;
- não remover código ou arquivos, apenas apontar falhas para a coordenação e para o Suporte 1;
- não substituir teste físico em aparelho real quando esse teste for necessário.

## Critérios de aceite
- app abre e navega sem travar;
- foco de TV não fica preso;
- controles principais continuam acessíveis;
- Cast e fullscreen não quebram após mudanças;
- falhas de stream exibem estado de erro e permitem recuperação;
- nenhuma tela apresenta overflow relevante;
- comportamento permanece consistente entre celular e TV.


## Regressões obrigatórias de abertura
- confirmar que a vinheta de abertura é reproduzida como intro real e não substituída pelo ícone do app;
- confirmar que o ícone/launcher aprovado permanece separado da vinheta;
- validar duração, transição para login/home e comportamento em celular e TV;
- se o vídeo da vinheta estiver ausente do pacote, considerar a build reprovada para teste final de experiência.
