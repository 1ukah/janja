#!/usr/bin/env bash

# ==========================================
# CONFIGURAÇÃO
# ==========================================
PROXY_HOST="<SEU_IP_DO_SERVIDOR>"
PROXY_PORT="1080"
AUTH_URL="<SUA_LAMBDA_FUNCTION_URL>"
AUTH_TOKEN="<SEU_TOKEN>"
# ==========================================

if ! command -v curl &> /dev/null; then
    echo "[ERRO] curl não encontrado no sistema."
    exit 1
fi

if ! curl -4 -fsS -X POST \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    "${AUTH_URL}" >/dev/null; then
    echo "[ERRO] Não foi possível autorizar este IP na AWS."
    exit 1
fi

sleep 1

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
