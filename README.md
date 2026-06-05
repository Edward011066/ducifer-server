# 🚀 Guia Definitivo: Servidor Caseiro
## Nextcloud, Vaultwarden, Redis & Cloudflare Tunnel

![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?style=for-the-badge&logo=Cloudflare&logoColor=white)
![Redis](https://img.shields.io/badge/redis-%23DD0031.svg?style=for-the-badge&logo=redis&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

Aprenda a contornar o **CGNAT** e criar sua própria nuvem, gerenciador de senhas e cache de alta performance de forma **gratuita, segura e sem abrir portas no roteador**.

Este tutorial ensina, passo a passo, como transformar um computador antigo ou uma máquina virtual rodando **Ubuntu Server** em um poderoso servidor pessoal. Seus serviços ficarão acessíveis de qualquer lugar da internet, mesmo sob CGNAT, utilizando o **Cloudflare Tunnel** com certificado SSL/TLS automático e otimizados com **Redis** para melhor desempenho do Nextcloud.

---

## 📋 Índice

- [O que você vai precisar](#-o-que-você-vai-precisar)
- [Conceitos Importantes](#-conceitos-importantes)
- [Passo a Passo Prático](#-passo-a-passo-prático)
  - [1. Instalação do Ubuntu](#passo-1-instalar-o-ubuntu-server-e-configurar-o-básico)
  - [2. Montagem de Disco (Opcional)](#passo-2-montar-um-hd-extra-para-os-dados-opcional)
  - [3. Instalação do Docker](#passo-3-instalar-o-docker-e-docker-compose)
  - [4. Estrutura de Pastas](#passo-4-criar-a-estrutura-de-pastas-do-projeto)
  - [5. Configuração de Variáveis (.env)](#passo-5-criar-o-arquivo-de-senhas-seguras-env)
  - [6. Docker Compose](#passo-6-criar-o-arquivo-principal-docker-composeyml)
  - [7. Configuração Pós-Instalação do Nextcloud](#passo-7-configuração-pós-instalação-do-nextcloud)
  - [8. Configurar o Domínio e o Túnel na Cloudflare](#passo-8-configurar-o-domínio-e-o-túnel-na-cloudflare)
- [Inicialização e Teste](#-inicialização-e-teste)
- [Comandos Úteis](#-comandos-úteis-para-o-dia-a-dia)
- [Perguntas Frequentes (FAQ)](#-perguntas-frequentes-faq)
- [Conclusão](#-conclusão)

---

## 📋 O que você vai precisar

| Requisito | Descrição |
| :--- | :--- |
| **Hardware** | PC antigo, Raspberry Pi ou VM com Ubuntu Server (22.04 ou 24.04 LTS). |
| **Domínio** | Um domínio próprio (ex: `meuservidor.cloud`). |
| **Cloudflare** | Conta gratuita para gerenciar o domínio e o túnel. |
| **Armazenamento** | (Opcional) Disco rígido extra para dados do Nextcloud. |

> [!IMPORTANT]
> **Por que um domínio é obrigatório?**
> O Cloudflare Tunnel exige um domínio real para criar as rotas de acesso externas. Isso elimina a necessidade de IP fixo ou abertura de portas (Port Forwarding).

---

## 🧠 Conceitos Importantes

### 1. O que é CGNAT?
A maioria dos provedores residenciais usa **CGNAT** para economizar IPs públicos. Isso impede que você receba conexões externas diretamente.
**A Solução:** O Cloudflare Tunnel cria uma conexão de *dentro para fora*, contornando o bloqueio do CGNAT sem expor seu IP real.

### 2. Caddy vs. Cloudflare Tunnel
Enquanto o Caddy exige portas 80/443 abertas, o **Cloudflare Tunnel** funciona perfeitamente em redes bloqueadas, substituindo a necessidade de um proxy reverso local como o Caddy ou Nginx Proxy Manager. O Caddy está incluído no repositório como uma opção comentada no `docker-compose.yml` para ambientes com IP público.

### 3. Redis para Nextcloud
**Redis** é um armazenamento de dados em memória, usado aqui como cache para o Nextcloud. Ele melhora significativamente o desempenho da sua nuvem, acelerando o carregamento de páginas e a execução de tarefas.

### 4. Estrutura de Diretórios (FHS)
| Diretório | Finalidade |
| :--- | :--- |
| `/home/$USER/` | Scripts, automações e projetos Docker. |
| `/mnt/data/` | Ponto de montagem para discos extras, onde todos os dados persistentes dos serviços Docker serão armazenados. |
| `/var/lib/docker/` | Arquivos internos do Docker (não mexer). |

---

## 🛠️ Passo a Passo Prático

### Passo 1: Instalar o Ubuntu Server e Configurar o Básico
1. Baixe a ISO oficial e grave-a em um pendrive (use Rufus ou `dd`).
2. Durante a instalação, **habilite o OpenSSH Server**.
3. Após o boot, atualize o sistema:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

### Passo 2: Montar um HD Extra para os Dados (Opcional)
Se tiver um disco separado, prepare-o para montagem automática. Todos os dados persistentes dos containers serão armazenados em `/mnt/data`.
```bash
# 1. Identifique o disco
sudo lsblk

# 2. Formate (ex: sda1)
sudo mkfs.ext4 /dev/sda1

# 3. Monte e configure o fstab
sudo mkdir -p /mnt/data
sudo mount /dev/sda1 /mnt/data
sudo blkid /dev/sda1 # Copie o UUID
```
Adicione ao `/etc/fstab` (substitua `seu-uuid` pelo UUID copiado):
`UUID=seu-uuid /mnt/data ext4 defaults 0 0`

### Passo 3: Instalar o Docker e Docker Compose
```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker
```

### Passo 4: Criar a Estrutura de Pastas do Projeto
```bash
mkdir -p ~/docker/meuservidor
cd ~/docker/meuservidor
sudo mkdir -p /mnt/data/{nextcloud/{data,config},mariadb,vaultwarden}
sudo chown -R $USER:$USER /mnt/data
```

### Passo 5: Configuração de Variáveis (.env)
Crie o arquivo `.env` na raiz do projeto (`~/docker/meuservidor/.env`) com base no `.env.example` fornecido. **Substitua os valores de exemplo por senhas fortes e o token do Cloudflare Tunnel.**

```bash
cp .env.example .env
nano .env
```

Conteúdo do `.env` (exemplo):
```env
NC_DB_PASSWORD=sua_senha_forte_para_nextcloud_db
NC_ROOT_PASSWORD=sua_senha_root_forte_para_mariadb
CLOUDFLARE_TUNNEL_TOKEN=seu_token_do_cloudflare_tunnel
```

> [!WARNING]
> **Segurança do arquivo .env:**
> 1. Gere senhas fortes (ex: `openssl rand -base64 32`).
> 2. Após criar o `.env` real, execute: `chmod 600 .env` para restringir o acesso.
> 3. **NUNCA** comite o `.env` real no controle de versão (Git).
> 4. Mantenha o `.env.example` no repositório (sem valores reais) para referência.

### Passo 6: Criar o Arquivo Principal (docker-compose.yml)
Crie o arquivo `docker-compose.yml` na raiz do projeto (`~/docker/meuservidor/docker-compose.yml`) com o seguinte conteúdo. Este arquivo define os serviços Nextcloud, MariaDB, Vaultwarden, Redis, Nextcloud Cron e Cloudflare Tunnel.

```yaml
services:
  nextcloud:
    build: .
    container_name: nextcloud
    restart: unless-stopped
    depends_on:
      - db
      - redis
    volumes:
      - /mnt/data/nextcloud/data:/var/www/html/data
      - /mnt/data/nextcloud/config:/var/www/html/config
    environment:
      - MYSQL_PASSWORD=${NC_DB_PASSWORD}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_HOST=db
      - APACHE_DISABLE_REWRITE_IP=1
      - REDIS_HOST=redis
      - OVERWRITEPROTOCOL=https
      - OVERWRITEHOST=nextcloud.seu-dominio.com # Substitua pelo seu domínio

  nextcloud-cron:
    image: nextcloud:latest
    container_name: nextcloud-cron
    restart: always
    depends_on:
      - nextcloud
    volumes:
      - /mnt/data/nextcloud/data:/var/www/html/data
      - /mnt/data/nextcloud/config:/var/www/html/config
    entrypoint: /cron.sh

  redis:
    image: redis:7-alpine
    container_name: nextcloud_redis
    restart: unless-stopped

  db:
    image: mariadb:10.11
    container_name: nextcloud_db
    restart: unless-stopped
    command: --transaction-isolation=READ-COMMITTED --log-bin=ROW
    volumes:
      - /mnt/data/mariadb:/var/lib/mysql
    environment:
      - MARIADB_ROOT_PASSWORD=${NC_ROOT_PASSWORD}
      - MARIADB_PASSWORD=${NC_DB_PASSWORD}
      - MARIADB_DATABASE=nextcloud
      - MARIADB_USER=nextcloud
      - TZ=America/Sao_Paulo

  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    volumes:
      - /mnt/data/vaultwarden:/data
    environment:
      - WEBSOCKET_ENABLED=true
      - SIGNUPS_ALLOWED=false # Altere para 'true' para criar sua primeira conta, depois volte para 'false' e reinicie os containers.

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}

# Opcional: Caddy como proxy reverso para ambientes com IP público
# Descomente se não estiver usando Cloudflare Tunnel e tiver portas 80/443 abertas
#  caddy:
#    image: caddy:latest
#    container_name: caddy
#    restart: unless-stopped
#    ports:
#      - "80:80"
#      - "443:443"
#    volumes:
#      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
#      - /mnt/data/caddy/data:/data
#      - /mnt/data/caddy/config:/config

networks:
  default:
    driver: bridge
```

> [!NOTE]
> O serviço `nextcloud` utiliza `build: .` porque há um `Dockerfile` na raiz do projeto. Este `Dockerfile` garante que o `ffmpeg` seja instalado no container do Nextcloud, permitindo a geração de miniaturas (thumbnails) para vídeos (MP4, MOV, etc.) diretamente no Nextcloud, sem configurações adicionais no sistema operacional hospedeiro.

### Passo 7: Configuração Pós-Instalação do Nextcloud
Após iniciar os containers, execute o script `post-install.sh` para configurar automaticamente o Nextcloud, habilitando o gerador de pré-visualizações e otimizando as configurações de cache.

```bash
cd ~/docker/meuservidor
sudo chmod +x post-install.sh
./post-install.sh
```

Este script:
- Habilita o `previewgenerator` no Nextcloud.
- Configura o Nextcloud para gerar pré-visualizações para PNG, JPEG, GIF, MP4, Movie e MKV.
- Define as dimensões máximas das pré-visualizações para 1024x1024 pixels.
- Executa o cron do Nextcloud para processar tarefas em segundo plano.

### Passo 8: Configurar o Domínio e o Túnel na Cloudflare
1. **Domínio:** Adicione seu domínio na Cloudflare e altere os Nameservers no seu registrador para os da Cloudflare.
2. **Tunnel:** No painel [Cloudflare Zero Trust](https://one.dash.cloudflare.com/), navegue até `Access` > `Tunnels`. Crie um novo túnel, selecione a opção `Docker` para o ambiente de setup e copie o **Token** gerado. Este token deve ser inserido no seu arquivo `.env` na variável `CLOUDFLARE_TUNNEL_TOKEN`.
3. **Public Hostnames:** Configure as rotas públicas para seus serviços:
   - `nextcloud.seu-dominio.com` (substitua pelo seu domínio) -> `http://nextcloud:80`
   - `vaultwarden.seu-dominio.com` (substitua pelo seu domínio) -> `http://vaultwarden:80`

---

## 🚀 Inicialização e Teste
Na raiz do seu projeto (`~/docker/meuservidor`), inicie os serviços Docker:
```bash
docker compose up -d
```
Para verificar os logs e garantir que tudo está funcionando corretamente:
```bash
docker compose logs -f
```

Acesse seus serviços pelos domínios configurados:
- Nextcloud: `https://nextcloud.seu-dominio.com`
- Vaultwarden: `https://vaultwarden.seu-dominio.com`

---

## 🔁 Comandos Úteis para o Dia a Dia

| Ação | Comando |
| :--- | :--- |
| **Iniciar todos os serviços** | `docker compose up -d` |
| **Parar todos os serviços** | `docker compose down` |
| **Ver logs de um serviço** | `docker compose logs -f [nome_do_serviço]` (ex: `nextcloud`, `vaultwarden`, `cloudflared`) |
| **Atualizar imagens e reiniciar** | `docker compose pull && docker compose up -d` |
| **Executar comando no Nextcloud** | `docker exec -it nextcloud php occ [comando]` |

---

## ❓ Perguntas Frequentes (FAQ)

**1. Posso usar Caddy com CGNAT?**
Não diretamente. O Caddy precisa de portas 80/443 abertas para funcionar como proxy reverso. O Cloudflare Tunnel é a solução recomendada para ambientes com CGNAT, pois estabelece uma conexão de saída, contornando as restrições de entrada.

**2. E se eu conseguir um IP público real depois?**
Você pode optar por migrar para o Caddy ou outro proxy reverso local, mas o Cloudflare Tunnel continua sendo uma opção mais segura por ocultar seu IP de origem e oferecer proteção DDoS e WAF.

**3. Domínios são caros?**
Não. Extensões como `.cloud` ou `.xyz` podem ser adquiridas por valores acessíveis (geralmente menos de R$ 20,00/ano). Evite serviços como DuckDNS para esta configuração, pois o Cloudflare Tunnel exige um domínio próprio.

**4. Como fazer backup dos dados?**
Todos os dados persistentes estão na pasta `/mnt/data`. Para fazer backup, basta copiar esta pasta para um local seguro. Por exemplo:
```bash
rsync -av /mnt/data/ /caminho/do/backup/
```

**5. O que é o `post-install.sh`?**
É um script que automatiza configurações importantes do Nextcloud, como a habilitação do gerador de pré-visualizações e a configuração de tipos de arquivos para os quais as pré-visualizações serão geradas. Ele simplifica a configuração inicial e garante que o Nextcloud funcione com todas as funcionalidades de mídia.

---

## 🏁 Conclusão
Parabéns! Você agora tem uma nuvem privada, um cofre de senhas seguro e um sistema otimizado com cache Redis, tudo rodando na sua própria casa, sem mensalidades e com total privacidade e acesso remoto seguro via Cloudflare Tunnel.

---
*Desenvolvido com ❤️ para a comunidade de Self-Hosting.*
