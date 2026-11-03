# Preparação integrada — 03/11/2026

Base26dd84cd475d4f64949d115d7ca2fd3e0d92d3ab. Oito testes novos de preflight/sanitização aprovados localmente. Configuração em experiments/roku-readiness/runtime-preparation.json permanece desativada, sem origem/projetoLAB/grant. preflight.mjs apenas inspeciona evidências públicas fornecidas, nunca abre socket, concede direito ou carrega chave privada. readyToRequestActivation não é autorização nem atestado de ambiente real. Certificado de teste efêmero apenas em memória; nenhuma CA instalada.

CI preparado para consultas novas de configuração Auth, provedorGoogle e testIamPermissions. GETs de metadados Firestore apenas em rocha-plus/rocha-plus-homologacao, último candidato histórico, sem escolhê-lo como destino. POST testIamPermissions é consulta sem mutação de política. Nenhum usuário/pagamento é lido por este script, nenhum token, OAuthsecret, serviceaccountemail ou chave é emitido. Resultados confirmados em firebase-readonly-results.json e fechamento abaixo. Skill aplicada: firebase-auth-basics; nenhuma instrução de deploy da skill é aplicável porque usuário proibiu ativação.

Não repetir64backend/36Android já verdes sem mudanças relacionadas. Revisão visual/player e checklist cruzado continuam nesta missão; resultados serão registrados por etapa.


## Etapa visual e auditoria concluídas

[CI41619638681](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41619638681) success:8testesnovos; consultaAuth/Google200, provedor habilitado, domínios no JSON. FirestoreLAB403 e IAM sem permissões listadas: não confirmado. CredencialCI possui permissões de escrita comercial, apenas observadas, nunca usadas; não transferir para hostLAB nem afirmar menorprivilégio. [Auditoria](firebase-readonly-results.json).

[Revisão visual/player](visual-player-review.md): GalleryBrowser.brs corrigido para recorte e janela deslizante, oito checksnovos e33regressões relacionadas aprovados no engine headless. [Resultados](roku-headless-tests.json). ZIP0.6.7 preservado; novo fonte não instalado. Sem alterações em catálogo/capas/favoritos/configuração/temporizador. Preparação cruzada e checklist seguem abaixo/em arquivos anexos nesta missão.


## Preparação cruzada concluída

[Seis testes novos](cross-platform-tests.json) de código/aprovação manual, poll perdido, outra conta, recuperação de transporte, revogação global e expiração aprovados localmente. Fluxo manual é8caracteres alfanuméricos, QR e numérico não implementados; não mudar contrato por suposição. [PlanoAndroid com hashes](android-integration-plan.json) pronto sem aplicar à branchAndroid. [Roteiro24casos](CROSS-PLATFORM-HOMOLOGATION.md) e template todosNOT_EXECUTED, CSVvazio para futuras decisões de canais com evidências. Não houve testes físicos, acesso concedido ou pacotes. CI41620227501 concluído success, seis testesaprovados.


## Fechamento final

[Passagem completa, classificação e próximos portões](FINAL-HANDOFF.md) · [EstadoCI e commits](final-status.json) · [Preflight atual bloqueado](actual-preparation-state.json) · [Preservação](preservation.json). Toda etapa técnica persistida na branch exclusiva, sem concessões/ativação/novo pacote.
