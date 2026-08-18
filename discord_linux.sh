#!/usr/bin/env bash

# ==========================================
# CONFIGURAÇÃO: Insira o IP da sua AWS aqui
# ==========================================
PROXY_HOST="<SEU_IP_DO_SERVIDOR>"
PROXY_PORT="1080"
# ==========================================

killall -9 discord 2>/dev/null
pkill -f "Discord" 2>/dev/null
sleep 1

PROXY_ARGS="--proxy-server=socks5://${PROXY_HOST}:${PROXY_PORT} --proxy-bypass-list=<-loopback>"

if command -v discord &> /dev/null; then
    discord $PROXY_ARGS &
    exit 0
fi

if command -v flatpak &> /dev/null; then
    if flatpak list --columns=application 2>/dev/null | grep -Fxq "com.discordapp.Discord"; then
        flatpak run com.discordapp.Discord $PROXY_ARGS &
        exit 0
    fi
fi

echo "[ERRO] Discord não encontrado no sistema."
exit 1
