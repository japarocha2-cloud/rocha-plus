# Android TV experimental — overlay de reservas

Base fixa d3c56ab6551c844fcb27501ba326d0c9a5cff641 da branch lab/central-rights-android-20261102. Para respeitar branch exclusiva Roku, estes dois arquivos corrigidos são aplicados por cópia somente no checkout efêmero CI dessa base. Nenhuma alteração na branch Android ou APK.

status(tv:true) omite playback_active; reprodução envia true, stop envia false; logout permanece action:logout via runtime existente. Consultas de restoreTv usam status neutro corrigido. CI executa Flutter tests e análise sobre app completo. Aplicação futura à branch Android requer etapa própria autorizada. Não copiar sobre Android oficial/C6/LAB714.
