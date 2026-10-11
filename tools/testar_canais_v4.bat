@echo off
setlocal
cd /d "%~dp0"
set "PATH=%CD%;%PATH%"
echo Rocha+ V4 - verificacao de estabilidade
if not exist "ffmpeg.exe" (
  where ffmpeg >nul 2>nul
  if errorlevel 1 (
    echo ERRO: copie ffmpeg.exe para esta pasta tools.
    pause
    exit /b 1
  )
)
if not exist "..\reports\channel_probe.csv" (
  echo ERRO: falta reports\channel_probe.csv da V3.
  pause
  exit /b 1
)
echo.
echo Testando 10 canais, 30 segundos por canal.
python channel_stability.py --input ..\reports\channel_probe.csv --output ..\reports\channel_stability --max-channels 10 --workers 2
echo.
echo Resultado: reports\channel_stability.csv
echo Para testar TODOS os candidatos, execute:
echo python channel_stability.py --input ..\reports\channel_probe.csv --output ..\reports\channel_stability --max-channels 0 --workers 2
pause
