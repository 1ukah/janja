@echo off
setlocal

:: ==========================================
:: CONFIGURAÇÃO: Insira o IP da sua AWS aqui
:: ==========================================
set "PROXY_HOST=<SEU_IP_DO_SERVIDOR>"
set "PROXY_PORT=1080"
:: ==========================================

taskkill /F /IM Discord.exe >nul 2>&1
timeout /t 1 >nul

for /f "delims=" %%D in ('dir /b /ad /o-n "%LocalAppData%\Discord\app-*" 2^>nul') do (
    start "" "%LocalAppData%\Discord\%%D\Discord.exe" --proxy-server="socks5://%PROXY_HOST%:%PROXY_PORT%" "--proxy-bypass-list=<-loopback>"
    goto :done
)

:done
exit
