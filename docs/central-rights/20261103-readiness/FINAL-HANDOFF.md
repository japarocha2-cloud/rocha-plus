# Fechamento — continuidade integrada 03/11/2026

| Componente | Estado efetivamente comprovado |
|---|---|
| Reservas centrais |64backend/HTTPS e36Android preservados da rodada anterior; nenhum código central/overlay alterado agora |
| PreparaçãoHTTPS/logs |8novostestesaprovados local/CI; configuração desativada e preflight sem efeitos externos |
| Google/FirebaseAuth |Config200, Googlehabilitado e domíniosautorizados recuperados em auditoria somenteleitura |
| Banco comercial |Metadata200; identidadeCI tem permissões de escrita observadas, não utilizadas; não usar como credencial de host de mínimo privilégio |
| LABFirestore/IAM |rocha-plus-homologacao metadata403, testeIAM não listou permissões. Não comprovado para esta finalidade |
| Vinculação/recuperação/revogação |6novostestesfixturesaprovados local/CI; identidade real não exercitada |
| Visual/carrossel |Fontecorrigido,8checksnovos+33relacionados verdes em engineheadless; não instalado |
| Androidexperimental |Overlaypreservado, plano fixado porhashes pronto; branchAndroid não modificada |
| Catálogo/capas |607/578preservados;29pendências comfonte/motivo noCSVexistente; C6finalnão localizado anteriormente, sem nova reconstrução |
| BRSnativo |Últimaexecução0.6.7 com bloqueio, evidências já persistidas; não repetir nem contornar |
| QR/numérico |Não implementados; códigoatual8alfanuméricos preservado, divergência documentada |
| Mídia/FPS/RAM/áudio/físico |Não executados agora, sem novos números ou aprovação |

## Mudanças e evidências

-61add4fd: experiments/roku-readiness/preflight.mjs, preflight.test.mjs, runtime-preparation.json e firebase-readonly.mjs; workflow roku-readiness.yml. [CI41619638681](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41619638681) success,8testes. [Auditoria](firebase-readonly-results.json) sem usuários/pagamentos/token nos logs.
-7b9d4d0: GalleryBrowser.brs com clipping e janela deslizante; tests/roku-visual/readiness-{harness.brs,runner.mjs}. [41checks](roku-headless-tests.json), [revisão](visual-player-review.md). Fonte do clipping: [Group oficialRoku](https://developer.roku.com/dev/docs/group). Verificação de geometria/foco não equivale a captura física.
-2559f75: tests/roku-readiness/cross-platform.test.mjs, workflow roku-cross-preparation.yml e planos/templates. [CI41620227501](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41620227501) success,6testes.

Nenhuma falha final. O teste novo de viewport falha no fonte anterior e passa no corrigido. Checksnovos não revalidam a imagem renderizada nem audio. As33regressões foram repetidas somente por alteração relacionada noGalleryBrowser.64/36não repetidos. Scripts de preparação não são importados por entrypoints oficiais, não ligam socket nem aplicam permissões/grants. ConsultaPOSTtestIamPermissions apenas testa permissões, não alteraIAM.

## Preservação

ZIP0.6.7 mantido, SHA2566ff88bbf99786163a6de80eeb18c985557ea2a68441c102d114e26ab34f3cd07; não gerado nem reinstalado. O fonte atual difere do ZIP somente emGalleryBrowser no códigoRoku, ajuste para futuro pacote autorizado. Não declarar que o ajuste está instalado. Configurações de ativação/manifest, catálogo, todas as capas/artes e artefatos sem mudança noGitdiff emrelação26dd84c. [Preservação](preservation.json). Não houve interaçãoECP nem manipulação dos registros, favoritos ou temporizador. Androidoficial/C6/LAB714, branchAndroidexperimental, Rokuoficial, site e direitos comerciais intocados. Sem merge/deploy/publicação.

## Próximo portão do proprietário

Esta ordem não autoriza ativação. O [preflight real](actual-preparation-state.json) retorna readyToRequestActivation:false e activationAllowed:false. Para avançar é necessário identificar o hostisolado/domínio/certificado e o projetoLAB efetivamente acessível, preparar credencial própria demínimoprivilégio e comprovar conectividade/TLS deRoku/celular/Android. Nenhum host contratado ou custo assumido. Domínios de produção listados não são autorização para modificar hosting/siteoficial.

Com esses recursos concretos definidos, apresentar configuração deativação e grant temporário exato (conta privada, scopehomologation, início/fim absoluto, até24h) para aprovação específica. Só depois podem ser autorizados configuração declientes/pacote e testes físicos com aparelhos definidos. Não estender a proposta privada anterior; não marcar pagamento como direito. Se for necessário mudar domínioAuth comercial ou IAM, obter autorização específica para a alteração exata e seu risco. Nenhuma dessas mudanças foi feita.

Riscos concretos a resolver: credencialCI comercial possui escrita e não deve migrar aohost; bancoLAB403ainda não comprovado; certificado/rede não testados nosaparelhos; sincronização entre liberação do slot e decoder fisicamente parado permanece sem evidência; QR/numérico nãoimplementados. Checklist24casos em [CROSS-PLATFORM-HOMOLOGATION.md](CROSS-PLATFORM-HOMOLOGATION.md), todosNOT_EXECUTED. Não contornar bloqueio para navegar.

## Recuperação em novo chat

Fazer checkout da branch lab/roku-visual-covers-performance-20261102 e ler AGENTS.md, mestre, este fechamento, final-status.json e evidênciasCI. AplicaçãoAndroid futura segue android-integration-plan.json; sehashbase divergir, revisar sem sobrescrever. CSV de revisões vazio para coleta futura, não é catálogo alterado. Reproduzir somente testes alterados/novos comcomandos dos workflows. EngineRoku requer instalação localBRSapp.asar; nenhuma cópia proprietária doengine foi republicada.
