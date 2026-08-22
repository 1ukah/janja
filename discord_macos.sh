#!/usr/bin/env bash

# ==========================================
# CONFIGURAÇÃO
# ==========================================
PROXY_HOST="<SEU_IP_DO_SERVIDOR>"
PROXY_PORT="1080"
AUTH_URL="<SUA_LAMBDA_FUNCTION_URL>"
AUTH_TOKEN="<SEU_TOKEN>"
# ==========================================

if ! curl -4 -fsS -X POST \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    "${AUTH_URL}" >/dev/null; then
    echo "[ERRO] Não foi possível autorizar este IP na AWS."
    exit 1
fi

sleep 1

pkill -f "Discord" 2>/dev/null
sleep 1

PROXY_ARGS="--proxy-server=socks5://${PROXY_HOST}:${PROXY_PORT} --proxy-bypass-list=<-loopback>"

if ! open -a "Discord" --args $PROXY_ARGS; then
    echo "[ERRO] Discord não encontrado na pasta /Applications."
    exit 1
fi
