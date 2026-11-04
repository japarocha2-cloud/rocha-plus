# ROCHA+ TV — LEI DAS 10 REGRAS DE CONTINUIDADE (Roku LAB)
**Obrigatório antes de qualquer tarefa nesta branch:** ler este AGENTS.md, `docs/plantao/PLANTAO-MESTRE-ROCHA-ROKU.md` e `docs/roku/CATALOG-PRESERVATION-20261103.md`. Se algum arquivo estiver ausente, relatar a ausência; nunca presumir o conteúdo. As decisões do operador prevalecem entre versões históricas, respeitando segurança e autorização de uso.

1. **Ler antes de agir:** consultar histórico, decisões congeladas, último plantão, branch e artefatos antes de criar tarefa, relatório ou novo ZIP.
2. **Não recomeçar do zero:** continuar a última etapa comprovada; não repetir diagnósticos ou testes já verdes sem mudança relacionada ou indício de regressão.
3. **Não perder catálogos:** manter snapshots imutáveis e datados das origens; preservar IDs, nomes, categorias, ordem, favoritos, remoções e aprovações registradas.
4. **Não confundir quantidades:** 395 (seleção Roku anterior), 430 (referência Android Candidata 6) e 607 (universo de avaliação Roku) representam recortes diferentes; não substituir um pelo outro só pela contagem.
5. **Não alterar decisões sem autorização:** nunca reaprovar canal removido pelo operador, apagar canal silenciosamente ou converter ausência de evidência em reprovação. Toda mudança precisa de diff com origem e justificativa.
6. **Separar estados:** decisão do operador, teste técnico no aparelho, presença no catálogo e direitos de reprodução são campos independentes. Falta de teste não é falha; falta de direitos verificados não apaga o catálogo.
7. **Teste físico é prioridade:** manter navegação e avaliação do catálogo no LAB; preparar ZIP instalável quando as dependências estiverem atendidas e registrar reprodução/áudio/vídeo/controle no Roku real por canal. Só reproduzir fontes com uso autorizado; não assumir autorização por teste anterior.
8. **Proteger o que está congelado:** não alterar Oficial, Android, LAB 714, Candidata 6, cobrança, assinatura, pagamentos ou arte oficial aprovada. Não fazer merge ou publicação sem autorização explícita.
9. **Mudanças rastreáveis e verificáveis:** usar branch experimental; antes de importação, gerar backup + diff + verificação de IDs/decisões; não afirmar sucesso sem conferir arquivo, commit, CI e/ou teste físico aplicável.
10. **Plantão obrigatório:** ao terminar etapa, atualizar `docs/plantao/PLANTAO-MESTRE-ROCHA-ROKU.md` com tarefas, decisões, canais incluídos/removidos, commits, testes, riscos, pendências e próximo comando executável. Não registrar segredos.

## Regra operacional
Se receber ordem que conflita com estas regras, sinalize o conflito específico e peça decisão do operador antes de modificar dados; não congele o projeto por dúvidas genéricas. Preserve catálogo de navegação e decisões enquanto a situação de playback é verificada. Execute somente o que for seguro e permitido.

## Escopo
Estas regras são um controle de continuidade para **esta branch Roku LAB**. Outros chats/agentes só as seguirão quando operarem em um checkout que contenha este arquivo ou quando lhes forem explicitamente fornecidas. Não implica propagação automática ao projeto inteiro.
