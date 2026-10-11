@echo off
setlocal
cd /d "%~dp0.."
echo ======================================
echo   Rocha+ ^| Verificacao de video e audio
echo ======================================
where python >nul 2>nul
if errorlevel 1 (
  echo Python nao encontrado. Instale e reabra o CMD.
  pause
  exit /b 1
)
where ffprobe >nul 2>nul
if errorlevel 1 (
  echo FFprobe nao encontrado no PATH.
  echo Instale FFmpeg e adicione a pasta bin ao PATH.
  pause
  exit /b 1
)
if not exist "reports\channel_triage.csv" (
  echo Arquivo reports\channel_triage.csv nao encontrado.
  echo Copie o relatorio de triagem para a pasta reports.
  pause
  exit /b 1
)
echo.
echo Testando 10 canais iniciais...
python tools\channel_probe.py --max-channels 10
if errorlevel 1 (
  echo Falha no teste. Veja a mensagem acima.
  pause
  exit /b 1
)
echo.
echo Teste concluido. Relatorio: reports\channel_probe.csv
echo Para testar os 393 prioritarios, execute:
echo python tools\channel_probe.py --workers 3 --timeout 15
pause
