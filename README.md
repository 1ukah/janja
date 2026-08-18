<p align="center">
  <img src="janja.png" alt="JANJA VAI TOMA NO CU">
</p>

# Desbloquear Compartilhamento de Tela do Discord após bloqueio da "Janja"

Este guia explica o passo a passo para contornar o bloqueio no Discord e restaurar o compartilhamento de tela criando um proxy próprio nos Estados Unidos. O objetivo é recuperar o acesso completo à transmissão sem depender de serviços pagos, sem instalar programas invasivos e sem comprometer a velocidade da conexão local.

---

## Como o Sistema Funciona

O Discord valida a localização apenas durante a inicialização e autenticação com a API.

1. Um servidor próprio nos EUA atua como intermediário exclusivamente no momento em que o Discord abre.
2. Após a validação da sessão, todo o tráfego pesado (como voz, vídeo e jogos) flui diretamente pela sua conexão de internet padrão, sem latência adicional.

---

## 1. Configuração do Servidor Próprio (AWS Free Tier)

Esta etapa precisa ser realizada apenas uma vez. O servidor ficará ativo continuamente.

### Criação da Máquina Virtual
1. Acesse o [Console da AWS](https://console.aws.amazon.com/) e faça login na sua conta.
2. Na barra de busca superior, pesquise por **EC2** e acesse o serviço.
3. No canto superior direito (ao lado do seu nome de usuário), selecione a região **US East (N. Virginia) `us-east-1`** (ou outra região dos EUA).
4. Clique no botão laranja **Launch instance**.
5. Preencha os campos:
   - **Name:** `discord-proxy`
   - **Application and OS Images (AMI):** `Amazon Linux 2023` (verifique a etiqueta `Free tier eligible`).
   - **Instance type:** `t2.micro` ou `t3.micro` (`Free tier eligible`).
   - **Key pair (login):** Selecione `Proceed without a key pair (Not recommended)`.

### Abertura de Porta no Firewall
Na seção **Network settings**:
1. Marque a opção **Allow SSH traffic from Anywhere**.
2. Clique no botão **Edit**.
3. Em **Inbound security groups rules**, clique em **Add security group rule**:
   - **Type:** `Custom TCP`
   - **Port range:** `1080`
   - **Source type:** `Anywhere` (`0.0.0.0/0`)
4. Clique no botão laranja **Launch instance**.

### Inicialização do Serviço de Proxy
1. Na lista de **Instances**, selecione a máquina criada e clique no botão **Connect** (no topo) -> aba **EC2 Instance Connect** -> botão **Connect** (abrirá o terminal no navegador).
2. No terminal, execute o comando abaixo:

```bash
sudo dnf update -y && sudo dnf install docker -y
sudo systemctl enable --now docker
sudo docker run -d --name socks5-proxy --restart always -p 1080:1080 -e SOCKS5_USER="" -e SOCKS5_PASS="" -e SOCKS5_PORT=1080 xkuma/socks5
```

3. Confirme que o serviço está ativo executando `sudo docker ps`.
4. Copie o **Public IPv4 address** da instância exibido no painel da AWS.

---

## 2. Inicialização do Discord

Use o script correspondente ao sistema operacional. Basta substituir o IP no campo de configuração.

---

### Windows (`discord.bat`)

Edite o `discord.bat` e substitua o IP:

```batch
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
```

> **Nota:** O inicializador padrão `Update.exe` descarta argumentos de linha de comando. O script busca o diretório da versão instalada mais recente e executa o `Discord.exe` diretamente com os parâmetros de rede necessários.

---

### macOS (`discord_macos.sh`)

Edite o `discord_macos.sh` e substitua o IP:

```bash
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
```

Dê permissão de execução no terminal:
```bash
chmod +x discord_macos.sh
```

---

### Linux (`discord_linux.sh`)

Edite o `discord_linux.sh` e substitua o IP:

```bash
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
```

O script tenta o comando `discord` (pacman, yay, apt e outros gerenciadores de pacotes). Se não estiver no `PATH`, inicia o Discord via Flatpak.

Dê permissão de execução:
```bash
chmod +x discord_linux.sh
```
