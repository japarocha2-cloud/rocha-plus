# Acesso de homologação Roku LAB — 02/11/2026

**Estado real: preparado e testado com fixtures; não ativado para a conta real.** Cadastro, pagamento e direito comercial permanecem NÃO VERIFICADOS. Nenhuma conta foi marcada como paga, criada, alterada ou cobrada. Nenhum backend foi implantado.

## Causa confirmada do bloqueio

Account.brs chama activatePhysicalLabAccess antes da vinculação. O arquivo physical-lab-access.json dos ZIPs0.6.4/0.6.5 seleciona physical_test_2h. O registro local RochaPlusPhysicalLab/firstStart fixa a primeira abertura; o prazo é firstStart+7200 segundos. Reinstalar um ZIP com a mesma identidade pode preservar esse registro. Ao expirar, a função retorna true e impede a consulta de conta/assinatura.

A mensagem “Teste LAB de 2 horas encerrado” é desse mecanismo local, não evidência sobre pagamento. config/auth.json também contém endpoint e billingEndpoint vazios; por isso esses ZIPs não consultavam o sistema comercial.

Consulta somente leitura ao ECP local confirmou dev0.6.4 em /query/apps e /query/active-app. O ZIP0.6.5 existe, mas instalar0.6.5 sozinho não elimina a expiração antiga. Não apagar registros globais, favoritos nem manipular firstStart para simular direito.

## Conta e evidências

A conta informada pelo proprietário é mantida somente em proposta privada fora do repositório. Este repositório é público: não colocar e-mail, UID, tokens, comprovantes ou identificadores financeiros nos relatórios.

- Cadastro: não verificado; isso não significa inexistente.
- Pagamento confirmado e vínculo legítimo: não verificados; isso não significa inadimplência.
- Direito pago válido: não verificado. Zero concessões comerciais ou alterações de assinatura.
- Não havia credencial administrativa padrão Firebase/Google nos caminhos de configuração consultados; nenhum segredo foi lido ou exibido.
- A tentativa de consultar sessão administrativa pela interface foi interrompida pelo controle do computador porque a URL atual não pôde ser confirmada. Nenhum formulário de conta foi submetido.
- Foi solicitado ao proprietário apenas o ID do projeto/painel autenticado, sem pedir credenciais. Não inferir o projeto correto por nomes históricos.
- Evidência disponível nesta etapa é de código e versão local, não recibo nem retorno autenticado do provedor. Veja account-verification.json e version-diagnosis.json.

## Mecanismo preparado

Somente platforms/roku-lab-visual foi alterado. O0.6.6 substitui o modo físico anônimo no pacote por account_homologation. O novo LabAccess.brs mantém autorizaçãoLAB separada dos estados paid/trial.

O ZIP distribuído tem config/lab-access.json.enabled=false e endpoint vazio. **Permanece bloqueado por padrão.** Não é um desbloqueio imediato e não contém autorização embutida, e-mail de proprietário, chave, token, UID ou senha. O operador deve concluir a verificação/configuração isolada antes de usar.

tools/roku-lab-access/service.mjs prepara o serviçoLAB; firebase-adapter.mjs exige projeto de identidade explícito e injeta Firebase Admin Auth apenas para verifyIdToken(token, true), getUser e getUserByEmail. Não cria usuários, claims, pagamentos ou direitos comerciais, nem escreve no Firestore.

A proposta privada tem enabled=false, conta exata fornecida pelo proprietário, ambiente roku-lab, escopo homologation e janela absoluta de24horas. Não é ativada automaticamente nem renovada ao abrir/reinstalar/pollar. A expiração exata está em account-verification.json; o e-mail só está em C:/Users/Administrador/Documents/ChatGPT/Rocha +/private/roku-lab-access/authorization-proposal.json. Não enviar esse arquivo ao GitHub.

## Código temporário e política de dispositivos

Fluxo preparado por código de oito caracteres, compatível com o formato existente de Conectar Roku; não usa serviço externo de QR.

1. Roku pede start pelo HTTPS isolado. Recebe user_code de8 caracteres e device_code aleatório de256bits, válidos por até10minutos.
2. No fluxo de homologação do celular, a pessoa entra de verdade na conta autorizada. O servidor valida token Firebase revogado, e-mail verificado exato, cadastro existente/ativo e provedor Google/Apple. Informar somente o e-mail não libera nada.
3. register_mobile exige identificação aleatória do celular e autenticação recente. Trocar o celular altera só seu vínculo e slot móvel; TVs continuam vinculadas. Token de login antigo não pode retomar o celular depois da troca.
4. approve exige esse celular atual e o código. Até duas TVs ficam vinculadas.
5. poll com o segredo da TV recebe sessão exclusivamenteLAB, vinculada ao UID/dispositivo. O código visível sozinho não concede acesso.
6. A prévia só inicia após resposta do servidor permitindo slot de reprodução. status usa playback_active; TVs ociosas não ocupam slots. mobile_playback/mobile_stop compartilham o limite de duas reproduções. Saída da prévia libera seu slot; lease perdido expira em até60s.
7. Acesso e slots usam leases de até60s, renovados após30s, nunca além do prazo absoluto da autorização. Falha, conta/dispositivo divergente ou expiração fecham o acesso e interrompem vídeo.
8. SessãoLAB expirada/inválida: OK verifica novamente; opções(*) permite novo vínculo, limpando apenas dados da sessãoLAB, sem mexer em pagamento.

**Limite da preparação:** serviço em memória, de processo único, sem endpoint publicado e sem portal móvel homologado. A aprovação precisa ser integrada ao fluxoLAB autenticado do celular; o APK Candidata6 e a autenticação de produção não foram alterados. A política foi testada no serviço isolado, não comprovada entre dispositivos de produção. Não declarar que os limites globais já estão implantados em Android/TV comercial.

## Como concluir a ativação com evidência

1. Identificar o projeto correto e obter sessão administrativa de leitura já autorizada; não enviar credenciais pelo chat.
2. Executar auditAccountReadOnly(email) com o Admin Auth desse projeto. A função reporta cadastro/validação sem incluir UID/e-mail no resultado e nunca deduz pagamento. Se indisponível, continuar como não verificado.
3. Para pagamento, usar a auditoria existente billing/tools/check-recurring-account.mjs com UID, vendedor e planos exatos em ambiente seguro e token de provedor fora de logs. Ela é somente leitura. Conferir confirmação atual, ciclo válido, estorno/revogação, vínculo UID/provider e registro servidor; um link de checkout ou tela de compra não é prova.
4. Se houver direito pago legítimo, preparar apenas o reconhecimento desse direito no clienteLAB usando o contrato comercial existente. Não criar direito duplicado, renovar período nem executar reconciliadores com escrita nesta tarefa.
5. Sem confirmação suficiente, não marcar paid. Usar a autorizaçãoLAB temporária restrita: confirmar projeto/conta, hospedar adaptador em HTTPS isolado aprovado e integrar aprovação móvel. Somente então habilitar a proposta privada e configurar lab-access.json em cópia experimental, preservando prazo absoluto e escopo.
6. Não apontar esse protocolo para o endpoint comercial nem implantar mudanças no projeto oficial. Não usar dados de fixtures em uma conta real.
7. Antes de ativar/distribuir novo ZIP configurado, atualizar plantão, testes e hash. Depois comprovar login real, rejeição de outra conta, expiração e política de dispositivos. Nenhum desses testes reais foi executado aqui.

## Instalação e identificação de versão

Para conferir o pacote anterior, baixar o ZIP0.6.5 do relatório mestre e carregá-lo no BRS Desktop. A instalação deve substituir o canal dev; confirmar o manifesto0.6.5 e o item dev em /query/apps, não outro canal já instalado. Reabrir dev e verificar /query/active-app.

Nesta etapa foi gerado0.6.6 PREPARADO com identificação “Roku LAB0.6.6” na interface. O texto fica oculto em tela cheia. Instalar0.6.6 não prova pagamento nem ativa a configuração desabilitada. O BRS nativo continuava em0.6.4 durante a consulta; o0.6.6 não foi instalado/executado pela interface nesta etapa.

GET http://127.0.0.1:8060/query/apps e GET /query/active-app permitem a conferência local. Não limpar os dados do aplicativo para reiniciar trial.

## Testes e artefato

-33 cenários BrightScript de comportamento:30 anteriores e3novos de espera/liberação de slot.
-20 cenários do serviço:restrição de conta, identidade verificada, cadastro ativo, limite24h, código10min, duasTVs, doisstreams incluindo celular, celular substituído sem derrubarTVs, expiração e leitura sem concessão comercial.
-14 cenários do cliente no engine:escopoLAB, UID/dispositivo, tipos/relógio, prazo, bloqueio por padrão, HTTPS e parada de vídeo.
-4controles do pacote:578 associações e catálogos preservados, configuração comercial idêntica, conta privada ausente e versão/delta corretos.
Total:71 verificações locais aprovadas, zero falhas finais. São fixtures/harness, não prova de pagamento, login real ou teste físico.

Reproduzir: node tests/roku-visual/run-lab-access.mjs "CAMINHO/resources/app.asar". Não há rede real nem decoder nesse harness. O runner geral verify.mjs também foi atualizado; inclui verificações adicionais de imagens.

ZIP: artifacts/roku-lab/20261102/access/RochaPlus-Roku-LAB-0.6.6-ACESSO-HOMOLOGACAO-PREPARADO-20261102.zip.
4.536.431 bytes,572 arquivos, SHA256 a8d7ba17fc1dd703d5cf81bea012ffc8942268ed68dc60765c9ef42b25212dd4.
Os578 mapeamentos,534 texturas e607 registros de catálogo (599runtime) permanecem preservados;29capas pendentes. Arte, categorias, ordem e homologações não alteradas.

Pendentes:projeto/consulta autenticada da conta, pagamento/vínculo legítimo, HTTPSLAB, aprovação móvel, configuração/ativação real e testes em aparelho. Sem merge, deploy, publicação, cobrança ou alteração de produção.
