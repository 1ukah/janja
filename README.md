<p align="center">
  <img src="janja.png" alt="JANJA VAI TOMA NO CU">
</p>

> [!WARNING]
> Depois de usar o proxy, o compartilhamento de tela volta a funcionar **para você**. Quem não estiver usando o proxy continuará bloqueado — isso não é uma falha deste workaround, e sim do bloqueio do Discord. Seus amigos também precisam usar o proxy.
>
> Você pode enviar o `.bat` ou o `.sh` já configurado para os amigos usarem também.

> [!IMPORTANT]
> O proxy não deve ficar aberto para `0.0.0.0/0`. Este guia utiliza uma AWS Lambda para autorizar automaticamente apenas o IP atual de cada usuário antes de iniciar o Discord.
>
> Não usamos um open proxy aberto sem autenticação, porque a ToS não permite.

# Desbloquear Compartilhamento de Tela do Discord após bloqueio da "Janja"

Este guia explica como restaurar o compartilhamento de tela do Discord utilizando uma instância EC2 nos Estados Unidos como proxy SOCKS5.

O IP atual do usuário é autorizado automaticamente no Security Group da AWS antes do Discord iniciar.

---

## Como o Sistema Funciona

1. O script chama uma AWS Lambda antes de iniciar o Discord.
2. A Lambda identifica o IP público de quem fez a chamada.
3. A Lambda adiciona temporariamente esse IP ao Security Group da EC2.
4. O Discord inicia utilizando a EC2 como proxy SOCKS5.
5. Qualquer IP que não estiver autorizado pelo Security Group não consegue acessar o proxy.

Fluxo:

```text
discord.bat / discord_macos.sh / discord_linux.sh
                    |
                    v
               AWS Lambda
                    |
                    v
            Autoriza IP atual
                    |
                    v
            EC2 Security Group
                    |
                    v
              SOCKS5 :1080
                    |
                    v
                 Discord
```

---

# 1. Criação da EC2

Acesse o [Console da AWS](https://console.aws.amazon.com/) e abra o serviço **EC2**.

Clique em **Launch instance**.

Configure:

- **Name:** `discord-proxy`
- **AMI:** Amazon Linux 2023
- **Instance type:** `t2.micro` ou `t3.micro`, conforme disponibilidade do Free Tier
- **Key pair:** crie uma nova key pair
  - Tipo: `ED25519`
  - Formato: `.pem`

Guarde o arquivo `.pem`. Ele será utilizado somente para administrar a EC2.

---

## Network Settings

No Security Group, inicialmente deixe apenas:

```text
SSH
TCP 22
Source: My IP
```

As portas do proxy serão liberadas automaticamente somente para os IPs autorizados.

---

# 2. Conectar na EC2

## Windows

Antes de conectar, o Windows pode considerar o arquivo `.pem` acessível por outros usuários e o OpenSSH irá recusá-lo.

No PowerShell, navegue até a pasta onde está a chave e execute:

```powershell
icacls .\key.pem /inheritance:r

$me = whoami
icacls .\key.pem /grant:r "${me}:(R)"
```

Confirme as permissões:

```powershell
icacls .\key.pem
```

Agora conecte:

```powershell
ssh -i .\key.pem ec2-user@<IP_PUBLICO_DA_EC2>
```

> [!NOTE]
> Se sua conexão com a internet mudar e seu IP público mudar, atualize a regra `SSH / TCP 22 / My IP` no Security Group da EC2 antes de tentar conectar novamente.

## macOS/Linux

Proteja a chave:

```bash
chmod 600 ./key.pem
```

Conecte:

```bash
ssh -i ./key.pem ec2-user@<IP_PUBLICO_DA_EC2>
```

---

# 3. Instalar Docker

Dentro da EC2:

```bash
sudo dnf update -y
sudo dnf install docker -y
sudo systemctl enable --now docker
```

Confirme:

```bash
sudo docker ps
```

---

# 4. Iniciar o Proxy SOCKS5

Execute:

```bash
sudo docker run -d \
  --name socks5-proxy \
  --restart always \
  -p 1080:1080 \
  -p 443:1080 \
  -e SOCKS5_USER="" \
  -e SOCKS5_PASS="" \
  -e SOCKS5_PORT=1080 \
  xkuma/socks5
```

Confirme:

```bash
sudo docker ps
```

Você deve ver algo semelhante:

```text
0.0.0.0:1080->1080/tcp
0.0.0.0:443->1080/tcp
```

Isso significa apenas que o Docker está escutando nessas portas.

---

# 5. Criar a Lambda

No AWS Console:

**Lambda -> Create function**

Configure:

```text
Function name: janja-authorize
Runtime: Python 3.13
Architecture: x86_64
```

Clique em **Create function**.

---

## Environment Variables

Abra:

**Configuration -> Environment variables**

Adicione:

```text
SG_ID=<ID_DO_SECURITY_GROUP_DA_EC2>
TOKEN=<SEU_TOKEN_SECRETO>
```

O `SG_ID` é o ID do Security Group da EC2. Para encontrar:

**EC2 -> Instances**

Selecione a instância `discord-proxy`.

Abra:

**Security -> Security groups**

Clique no Security Group e copie o **Security group ID**. Ele começa com `sg-`.

Exemplo:

```text
sg-0123456789abcdef0
```

Utilize um token longo e aleatório.

---

# 6. Permissão da Lambda

Abra:

**Lambda -> Configuration -> Permissions**

Clique no **Execution role**.

Adicione uma Inline Policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:AuthorizeSecurityGroupIngress",
      "Resource": "*"
    }
  ]
}
```

---

# 7. Código da Lambda

Substitua o código da função por:

```python
import boto3
import json
import os
from botocore.exceptions import ClientError

ec2 = boto3.client("ec2")

SG_ID = os.environ["SG_ID"]
TOKEN = os.environ["TOKEN"]


def lambda_handler(event, context):
    headers = {
        k.lower(): v
        for k, v in event.get("headers", {}).items()
    }

    if headers.get("authorization") != f"Bearer {TOKEN}":
        return {
            "statusCode": 401,
            "body": "Unauthorized"
        }

    ip = event["requestContext"]["http"]["sourceIp"]

    for port in (1080, 443):
        try:
            ec2.authorize_security_group_ingress(
                GroupId=SG_ID,
                IpPermissions=[
                    {
                        "IpProtocol": "tcp",
                        "FromPort": port,
                        "ToPort": port,
                        "IpRanges": [
                            {
                                "CidrIp": f"{ip}/32",
                                "Description": "janja-auto"
                            }
                        ]
                    }
                ]
            )
        except ClientError as e:
            if e.response["Error"]["Code"] != "InvalidPermission.Duplicate":
                raise

    return {
        "statusCode": 200,
        "body": json.dumps({
            "authorized": True,
            "ip": ip
        })
    }
```

Clique em **Deploy**.

---

# 8. Criar a Function URL

Abra:

**Lambda -> Configuration -> Function URL**

Clique em **Create function URL**.

Configure:

```text
Auth type: NONE
```

A autenticação será feita pelo Bearer Token configurado na própria Lambda.

A URL será semelhante a:

```text
https://xxxxxxxx.lambda-url.us-east-1.on.aws/
```

---

# 9. Configurar os Scripts

# Windows

Edite:

```text
discord.bat
```

Configure:

```batch
set "PROXY_HOST=<SEU_IP_DO_SERVIDOR>"
set "PROXY_PORT=1080"
set "AUTH_URL=<SUA_LAMBDA_FUNCTION_URL>"
set "AUTH_TOKEN=<SEU_TOKEN>"
```

Depois execute:

```text
discord.bat
```

O script:

1. Autoriza seu IP atual na AWS.
2. Fecha o Discord.
3. Inicia o Discord utilizando o proxy.

---

# macOS

Edite:

```text
discord_macos.sh
```

Configure:

```bash
PROXY_HOST="<SEU_IP_DO_SERVIDOR>"
PROXY_PORT="1080"
AUTH_URL="<SUA_LAMBDA_FUNCTION_URL>"
AUTH_TOKEN="<SEU_TOKEN>"
```

Dê permissão:

```bash
chmod +x discord_macos.sh
```

Execute:

```bash
./discord_macos.sh
```

---

# Linux

Edite:

```text
discord_linux.sh
```

Configure:

```bash
PROXY_HOST="<SEU_IP_DO_SERVIDOR>"
PROXY_PORT="1080"
AUTH_URL="<SUA_LAMBDA_FUNCTION_URL>"
AUTH_TOKEN="<SEU_TOKEN>"
```

Dê permissão:

```bash
chmod +x discord_linux.sh
```

Execute:

```bash
./discord_linux.sh
```

O script tenta primeiro encontrar o Discord instalado diretamente no sistema.

Se não encontrar, tenta iniciar:

```text
com.discordapp.Discord
```

via Flatpak.

---