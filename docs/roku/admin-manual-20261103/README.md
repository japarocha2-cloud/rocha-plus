# Roku LAB0.6.9 — teste manual real e conta administrativa

Branch lab/roku-visual-covers-performance-20261102; base0a950167ba494b17a89920f9521dfd4d257aefe2. Código/consulta5aeb3785500fc81625083c6524bedc30f09f5c4e. LidosAGENTS.md, mestre, relatórios de0.6.8/HTTPS/ativação e mudanças remotas novas; não reconstruídoaplicativo.

## Conclusão

**Loginreal: NÃOEXECUTADO. ReconhecimentoADM: NÃOEXECUTADO, sem evidência para aprovação.** O appreal0.6.9 abre noBRS e para noaviso deacessoLABaguardandoconfiguração. Não houve envio detokenGoogle, geração decódigo ou consulta dedireitos peloRoku. Nãoéloginreprovadoporcredenciais; é fluxoindisponível antes deautenticar.

Conta pedida consultada somente emAuth rocha-plus: existe, habilitada, emailverificado, Googlevinculado, provedorsenhafalse e **customclaimrochaAdminfalse**. [CI41723718265](https://github.com/japarocha2-cloud/rocha-plus/actions/runs/41723718265) success, writes0. account-verification.json contém indicadores permitidos, semUID/subject/token/claimscompletas. ConsultausergetByEmail nãoautentica usuário e nãoaudita pagamentos/direitos; nenhuma conta/permissão criada.

## Fluxo e função administrativa

initAccount tenta central, LAB e físiconessaordem. central-access enabledfalse; lab-access enabledfalse/endpoints vazios, physicalmodeaccount_homologation. Retorna antes depairing. Integraçãocentral preparada usa Google no celular +confirmação8caracteresalfanuméricos/10min, nãoQRativo nemsomente numérico. PropostasQR/numérico permanecemdesativadas e semimplementaçãooperacional. Nenhumendpointvalidado/ativado nestaetapa.

ArquivosAccount/CentralAccess/LabAccess não usamrochaAdmin nem oemailsolicitado. Não há painelADM noRoku nem exceçãodeassinatura porcontaGoogleCloud. docs/admin-access.md trata implementaçãoAndroidhistórica, outroemail e claimrochaAdmin; não transferirsuaautorização paraRoku/esta conta. Claimfalse não elimina possibilidade deoutraspolíticasexternas, mas nenhumafoicomprovada aqui. Estado de assinatura/adminexemption não foiconsultado/concedido; nãopresumir direitoexistente.

Integraçãooperacional delogin eADM **não pôdeser concluída** sem runtimeHTTPS/identidadereais e políticadepapelvalidada. Não incluir bypass client-side/hardcodeemail nem atribuir claim para satisfazerteste. Proposta futura: revisar fonteautoritativa deADMexistente e direitoprevisto separadamente, definir autorização no backend, usarHTTPS/pairingoficial, fazerloginGooglepelo própriousuário, confirmarUID/scope/dispositivoelease e sóentão testar persistência/logout. Mudanças emclaims/IAM/produção nãoautorizadas, portanto nãoforam propostas como execuçãodestaentrega. Não háautenticaçãosimulada usada como provadecontareal.

## Execução gráfica efetivamente realizada

BRSDesktop2.6.2 instaladoWindows, engine2.6.1/SceneGraph0.6.1. AppfoiabertoviaComputerUse e operadopelaAPIlocaloficial doemulador, nãoharness. Antesdev0.6.7, outrocanal0.6.3. UploadHTTP200InstallSuccess, dev0.6.9instaladoeativonosdoisECP. Capturas reais069-access.png e069-reopened.png; XMLapps/active-app/back, ações econsole sanitizado anexos. Primeiroframe069-initial sógaláxia, nãointerpretarcomofalha.

SetasDown/Right eSelect enviados noECP:200 e telaigual, acesso nãoaberto. Back encerrouparaHome, reabertura mantevebloqueio. RegistroECPbyteidênticoantes/depois, SHA256fa5b0212fe1cf731d095f5432e1e07cdec9bec3a7aa28941f2dcdbef1a8eebfc; bruto somenteprivado, nãoGit. Nenhum favorito/tempodetesteapagado. Isso nãoé teste depersistênciadelogin, pois nenhuma sessão autenticada foiobtida. Não efetuarlogout nemremoção decanal semacesso. Trechodeconsolecapturado semexceção; não provaestabilidadelongaduracão. Playerstateclose/errorfalse, nenhumstream. FPS/RAMreais não medidos.

Resultados individuais em manual-results.json. Navcategoria/lista/capas/busca/PET/gradefavoritos/remoçãoconfirmada não validadosmanualmenteporque bloqueados. Códigoimplementadopreservado, catálogo607/carregador599HLS,578capas/534texturas/29pendências preservados; contagemtécnica nãoé homologação físicadecanais. Logomarca/galáxia/banner vistos sobsobreposição, portanto visualparcial. RelógioapenasHome ecarrosselparcial/focointeiro já têmchecksheadlessanteriores, nãosubstituíram teste manual agora.

## ZIP atualizado solicitado

Nome RochaPlus-Roku-LAB-0.6.9-VERIFICACAO-ADM-ACESSO-DESATIVADO.zip
Caminho artifacts/roku-lab/20261103/RochaPlus-Roku-LAB-0.6.9-VERIFICACAO-ADM-ACESSO-DESATIVADO.zip
Versão0.6.9,4.538.311bytes,574arquivos.
SHA2568722ac2a2563235dcd4876cd690347ef18e64f12c7134196b8a9db500ae21795.
Deltaexato contra0.6.8:manifestbuild9 erodapé0.6.9. Não hácorreçãonovadelogin, grant ourecursooperacional: pacoteidentificadoparaesta rodada solicitada. Carrosselcorrigido e demaisrecursosjáaprovados incluídos.0.6.8/0.6.7não sobrescritos. No histórico, nãofoiencontrada evidência deZIPtestadofisicamente emTV;0.6.7tinhaexecuçãonativaBRSconfirmada, agora0.6.9também. Não inventarhardwareanterior.

7validações direcionadas passaram:CRC/574entradas;deltaexato2arquivos;607/578eimagensbyteidênticos;flagsfalse/endpoints vazios;8BRScriptparse/XML;versão;conteúdosemsegredosnovos. Verificação usa payload0.6.8jáauditado byteporbyte, mesmasURLshistóricasdevídeocomtokensdeentrega jádocumentados, semcredenciaisAdmin/registro/sessãoprivados. package-tests.json. Não repetidas64backend/36Android/41headless porque semlógicanova. ConsultaAuthreadonly única, semnovostestesfinanceiros.

## Instalação física e próximos passos

NenhumaTVfísicaacessada. BaixarZIP, compararhash e, noDevelopmentApplicationInstallerdoaparelhoautorizado, Upload→Install/Replace. NoBRS podeaparecerReplacewithZIP. Confirmarantes que devéLABautorizado; nãoDelete/limpardados/resetar/substituirOficial. Nãofornecersenhaaqui. Guiaoficial: https://developer.roku.com/dev/docs/developer-setup .

Checklistfísico:instalação/versão0.6.9,abertura/legibilidade/logo/galáxia/banner,sobreposição/aviso,Back/reabrir e preservação deestado. Navegaçãointerna,login/persistência/logoutADM,catálogo/capas/favoritos/busca/PET,remoçãocomconfirmação,prévia/fullscreen/áudio continuamBLOQUEADOSatéativação válida. Não usaradmincomoalternativadebypass. ParaaprovaçãoADMreal faltam runtimeHTTPSconfigurado, vinculaçãoreal autorizada e definiçãoautoritativadosdireitosADMexistentes. Claimnãofoiconcedida. Depois registrarimagem/áudio/rede/FPS/RAMemhardware;nenhumaprovadoaqui.

## Preservação e continuidade

NenhumFirebase/pagamento/assinatura/IAMalterado. AndroidOficial/C6/LAB714/avós/RokuOficial/siteintactos,semmerge/deploy/ChannelStore. ApenasbranchLAB,artefatoetesteautorizado. Todosresultadosverificáveis nacaptura/ECP/CI, semfingirtestecompleto porautomação. Paraoutrochat:lerAGENTS,mestre eeste relatório, conferirheadremoto eartefatos; não repetir403/readinessanteriores semcausanova. ContarealnãoécontaADMcomprovada.


## Artefato e links permanentes

[Baixar ZIP0.6.9](https://raw.githubusercontent.com/japarocha2-cloud/rocha-plus/7784870b90f6ed15417715c9846b875add9cbe24/artifacts/roku-lab/20261103/RochaPlus-Roku-LAB-0.6.9-VERIFICACAO-ADM-ACESSO-DESATIVADO.zip) · [Código/artefato7784870](https://github.com/japarocha2-cloud/rocha-plus/commit/7784870b90f6ed15417715c9846b875add9cbe24) · [Captura real](069-access.png) · [Reabertura](069-reopened.png) · [ContaAuth](account-verification.json) · [Resultadosmanuais](manual-results.json) · [ValidaçãoZIP](package-tests.json) · [Verificaçãoremota](remote-verification.json). DownloadHTTP200/hashintegral conferidos; nãoTVfísica.
