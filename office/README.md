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
