@echo off
setlocal

:: ==========================================
:: CONFIGURAÇÃO
:: ==========================================
set "PROXY_HOST=<SEU_IP_DO_SERVIDOR>"
set "PROXY_PORT=1080"
set "AUTH_URL=<SUA_LAMBDA_FUNCTION_URL>"
set "AUTH_TOKEN=<SEU_TOKEN>"
:: ==========================================

curl.exe -4 -fsS -X POST ^
  -H "Authorization: Bearer %AUTH_TOKEN%" ^
  "%AUTH_URL%" >nul

if errorlevel 1 (
    echo [ERRO] Não foi possível autorizar este IP na AWS.
    pause
    exit /b 1
)

timeout /t 1 >nul

taskkill /F /IM Discord.exe >nul 2>&1
timeout /t 1 >nul

for /f "delims=" %%D in ('dir /b /ad /o-n "%LocalAppData%\Discord\app-*" 2^>nul') do (
    start "" "%LocalAppData%\Discord\%%D\Discord.exe" --proxy-server="socks5://%PROXY_HOST%:%PROXY_PORT%" "--proxy-bypass-list=<-loopback>"
    goto :done
)

echo [ERRO] Discord não encontrado.
pause

:done
exit
