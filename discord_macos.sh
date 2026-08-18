#!/usr/bin/env bash

# ==========================================
# CONFIGURAÇÃO: Insira o IP da sua AWS aqui
# ==========================================
PROXY_HOST="<SEU_IP_DO_SERVIDOR>"
PROXY_PORT="1080"
# ==========================================

pkill -f "Discord" 2>/dev/null
sleep 1

PROXY_ARGS="--proxy-server=socks5://${PROXY_HOST}:${PROXY_PORT} --proxy-bypass-list=<-loopback>"

if ! open -a "Discord" --args $PROXY_ARGS; then
    echo "[ERRO] Discord não encontrado na pasta /Applications."
    exit 1
fi
