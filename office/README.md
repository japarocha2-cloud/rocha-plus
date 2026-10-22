# Rocha+ Office LAB 0.3

Instaladores experimentais Android (Capacitor) e Windows (Electron), baseados no editor HTML 1.3 já preparado. Inclui documentos, planilha básica, apresentações e financeiro local. Não é uma suíte DOCX/XLSX/PPTX completa.

## Build

Node 22: `npm ci --ignore-scripts`, `npm run build`. Android: Java 21, Android SDK, `npx cap add android`, `cd android && ./gradlew assembleDebug`. Windows: `npm run desktop:pack -- --publish never` em Windows.

O workflow `Rocha Office experimental installers` compila ambos e guarda artefatos com SHA256. Android é debug; Windows é experimental sem assinatura de distribuição. Não publicar estes arquivos como produto comercial.

## Pendências para venda

- Verificar edição, importação/exportação, salvar no dispositivo e impressão em Android e Windows reais. Download Blob e impressão web precisam de validação específica no WebView Android.
- Conectar Google/Firebase e a aprovação manual ao servidor de licenças.
- Implementar e testar limite transacional de dois dispositivos, revogação, renovação da sessão e proteção dos downloads privados.
- Preparar assinatura permanente de distribuição, termos comerciais e recuperação/backup dos dados.

Preço confirmado: R$49,90 único. Link confirmado pelo usuário: https://mpago.la/2KWTnPa . Ter um link não comprova pagamento nem entrega. Nenhum arquivo deste protótipo valida uma licença comercial. A regra continua: acesso pago só após aprovação confiável e ligado à conta compradora.

## Modo comercial preparado

O padrão de `npm run build` continua LAB, preservando o editor experimental existente. O código agora também compila `commercial.html`, `portal.html` e `admin.html`.

Para gerar a entrada comercial como `dist/index.html`, configure `ROCHA_OFFICE_COMMERCIAL=true`, `ROCHA_OFFICE_LICENSE_URL` (base HTTPS do serviço), `ROCHA_OFFICE_PORTAL_URL` (URL HTTPS exata do portal Google) e `ROCHA_OFFICE_FIREBASE_JSON` (configuração pública Web do projeto `rocha-plus`). Sem todos esses dados o build comercial falha. O editor é separado em `editor.html` e só é anexado pela tela de acesso após autorização. Os dados locais do editor e do financeiro recebem namespace por conta. Não há promessa de impedir engenharia reversa de arquivos já obtidos.

O programa mostra um código, abre o navegador do sistema e recebe uma sessão restrita à instalação após aprovação Google. Tokens não entram no URL. Trocar conta e sair descartam o editor anterior; falhas de verificação pausam o frame sem apagar imediatamente trabalho não salvo. A sessão é verificada periodicamente. Não há cache de licença offline habilitado.

Apenas o portal/painel e seus assets devem ir para o site público. Nunca copiar `dist/index.html`, `editor.html`, APK ou EXE comercial para uma pasta pública para simular um download protegido. O backend ainda precisa de implantação e armazenamento privado com arquivos assinados validados. Os builds automáticos permanecem identificados como LAB, não comerciais.
