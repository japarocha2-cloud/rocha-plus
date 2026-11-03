# Preparação integrada — 03/11/2026

Base26dd84cd475d4f64949d115d7ca2fd3e0d92d3ab. Oito testes novos de preflight/sanitização aprovados localmente. Configuração em experiments/roku-readiness/runtime-preparation.json permanece desativada, sem origem/projetoLAB/grant. preflight.mjs apenas inspeciona evidências públicas fornecidas, nunca abre socket, concede direito ou carrega chave privada. readyToRequestActivation não é autorização nem atestado de ambiente real. Certificado de teste efêmero apenas em memória; nenhuma CA instalada.

CI preparado para consultas novas de configuração Auth, provedorGoogle e testIamPermissions. GETs de metadados Firestore apenas em rocha-plus/rocha-plus-homologacao, último candidato histórico, sem escolhê-lo como destino. POST testIamPermissions é consulta sem mutação de política. Nenhum usuário/pagamento é lido por este script, nenhum token, OAuthsecret, serviceaccountemail ou chave é emitido. Resultados serão anexados após execução. Skill aplicada: firebase-auth-basics; nenhuma instrução de deploy da skill é aplicável porque usuário proibiu ativação.

Não repetir64backend/36Android já verdes sem mudanças relacionadas. Revisão visual/player e checklist cruzado continuam nesta missão; resultados serão registrados por etapa.
