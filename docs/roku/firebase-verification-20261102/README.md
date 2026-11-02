# Firebase e conta Roku LAB — verificação de 02/11/2026

## Resultado atual comprovado

O projeto de identidade/cobrança existente é **rocha-plus**. A conta solicitada foi localizada por consulta autenticada em02/11/2026,16:41:51UTC:cadastro verificado e ativo,vínculoGoogle e registroSpark encontrados.

Dois pagamentos específicos foram consultados:aprovados,modo real,pagador e recebedor correspondentes,sem reembolso informado nesses dois registros. Não são publicados e-mail,UID,IDs de pagamento,valores ou comprovantes.

**Isso ainda não estabelece direito comercial aplicado.** A consultaSpark retornou paidUntil=null e paidAccessCurrent=false. A projeção é somente preview,com revisão de duração e ledger pendente;readyToApply=false. Não conceder paid,não somar períodos,não duplicar cobrança ou concessão.

Fonte atual:[run40354015839,attempt2](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/40354015839/attempts/2),job125409233413,iniciado02/11/2026 e concluído success. O run original é de26/10,mas foi repetido somente o job de leitura,com fonte imutável55461ffea352aa26eec1c5e02cfd595db0ddcc00. Não confundir created_at original com run_started_at da nova tentativa. Script revisado:FirebasegetUser/getFirestore.get e MercadoPagoGET;zero escrituras,nenhum acesso concedido.

current-account-evidence.json registra somente resultados sanitizados. historical-account-evidence.json preserva a observação anterior de26/10. A consulta histórica não foi tomada como prova de situação atual.

## Projetos separados por evidência

| ID | Papel comprovado | Limite |
|---|---|---|
|rocha-plus|Identidade existente e cobrançaSpark;workflowBuild,guardasAdmin e consulta atual da conta|Consulta não altera assinatura nem cria direito|
|rocha-plus-candidate|CandidataAndroid isolada,packagecom.rochaplus.app.candidate|Não substituir projeto comercial;console histórico não é prova da conta atual|
|demo-rocha-spark|Fixture de emulador das regrasFirestore|Não é cadastro comercial|
|RokuLAB|Escoporoku-lab/homologation do protocolo preparado|Não foi comprovado um projetoFirebase próprio nem endpointHTTPS já configurado|

firebase-project-map.json contém caminhos e commits de origem. O repositório japarocha2-cloud/rocha-plus não é um IDFirebase.

## Cobertura e consulta adicional do ledger

A repetição do diagnóstico anterior consultaSpark e provedor,mas não valida o ledger de pagamentos já processados. Por isso não concluir que todo direito é ausente só porque paidUntilSpark está vazio.

Foi preparada auditoria adicional exclusivamente de leitura:.github/workflows/roku-lab-stored-rights.yml e tools/roku-lab-access/stored-rights-audit.mjs. Ela consulta oUID exato autenticado,rochaBillingUsers,rochaSparkAccounts,projeçãoSpark e os registros correspondentes aos mesmos dois pagamentos. Não usa store.user(),apply(),reconciliadores,transações,checkout,webhook ou método de escrita. O cálculo legado é puro e apenas descreve dados já armazenados.

O sujeito e as referências são obtidos de diagnóstico público anterior fixado por commit eSHA256,sem copiar identificadores pessoais para os novos arquivos. Nada é avaliado como código remoto. Resultado contém apenas flags sem e-mail,UID,GoogleSubject ouIDs financeiros. Fonte Admin deve pertencer explicitamente a rocha-plus.

Seis testes de segurança locais aprovados:sem escrita/concessão,saída privada,UID divergente rejeitado,registro ausente não vira paid,relógio servidor obrigatório e escopo de duas referências numéricas. Resultado da nova execução será anexado após confirmação.

## O que falta de fato

Não falta mais o ID do projeto nem acesso para a consulta autenticada já concluída:o runner existente conseguiu lerAuth,Firestore e provedor. Não pedir nova chave privada nem exportar o Secret usado noCI.

Para ativar o protocoloLAB0.6.6 ainda faltam:runtimeHTTPS isolado,verificador de identidade nele configurado para rocha-plus,aprovação móvel autenticada e teste real de vínculo/expiração/dispositivos. O Secret disponível dentro do runner não é automaticamente uma credencial disponível para outro servidor. Não transferir segredo por chat ou GitHub.

A proposta privada foi vinculada ao projeto comprovado rocha-plus,mas enabled continuafalse,prazo absoluto original preservado. Ela permanece restrita à conta exata,janela máxima24h,escopohomologation e nenhuma assinatura comercial. A autorização não foi ativada.

## ZIP0.6.6 reconfirmado

Commit do código/artefato:b47ccf380152acf3d2ee996fbea1d01c6d5a099d.
[Download permanente](https://raw.githubusercontent.com/japarocha2-cloud/rocha-plus/b47ccf380152acf3d2ee996fbea1d01c6d5a099d/artifacts/roku-lab/20261102/access/RochaPlus-Roku-LAB-0.6.6-ACESSO-HOMOLOGACAO-PREPARADO-20261102.zip).

HTTP200,4.536.431bytes,572arquivos,CRC conferido;SHA256 a8d7ba17fc1dd703d5cf81bea012ffc8942268ed68dc60765c9ef42b25212dd4. Manifesto0.6.6 e enabled=false/endpointvazio conferidos dentro doZIP.
71verificações anteriores reconfirmadas nos relatórios imutáveis:33comportamento,20servidor,14cliente,4pacote. Não repetidas porque nenhum código Roku mudou nesta etapa. zip-066-reverification.json registra a conferência.

ConsultaECP atual confirma dev0.6.4 ainda carregado. Para identificar instalação,use /query/apps e /query/active-app;não confundir versão1.0 doXML com versão doapp. Carregar0.6.5 mantém limite2h;0.6.6é preparação bloqueada por padrão,não desbloqueio imediato.

Nenhum novoZIP necessário nesta etapa;catálogos,578capas,arte,AndroidC6,Rokuoficial e regras comerciais intactos. Sem merge,deploy,publicação,cobrança ou escrita de direito.
