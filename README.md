# 🚀 Guia Definitivo: Servidor Caseiro
## Nextcloud, Vaultwarden & Cloudflare Tunnel

![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?style=for-the-badge&logo=Cloudflare&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

Aprenda a contornar o **CGNAT** e criar sua própria nuvem e gerenciador de senhas de forma **gratuita, segura e sem abrir portas no roteador**.

Este tutorial ensina, passo a passo, como transformar um computador antigo ou uma máquina virtual rodando **Ubuntu Server** em um poderoso servidor pessoal. Seus serviços ficarão acessíveis de qualquer lugar da internet, mesmo sob CGNAT, utilizando o **Cloudflare Tunnel** com certificado SSL/TLS automático.

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
  - [7. Cloudflare Tunnel](#passo-7-configurar-o-domínio-e-o-túnel-na-cloudflare)
- [Comandos Úteis](#-comandos-úteis-para-o-dia-a-dia)
- [Perguntas Frequentes (FAQ)](#-perguntas-frequentes-faq)

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
Enquanto o Caddy exige portas 80/443 abertas, o **Cloudflare Tunnel** funciona perfeitamente em redes bloqueadas, substituindo a necessidade de um proxy reverso local como o Caddy ou Nginx Proxy Manager.

### 3. Estrutura de Diretórios (FHS)
| Diretório | Finalidade |
| :--- | :--- |
| `/home/$USER/` | Scripts, automações e projetos Docker. |
| `/mnt/` ou `/media/` | Pontos de montagem para discos extras. |
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
Se tiver um disco separado, prepare-o para montagem automática:
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
Adicione ao `/etc/fstab`:
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

### Passo 5: Criar o Arquivo de Senhas Seguras (.env)
```bash
nano ~/docker/meuservidor/.env
```
Conteúdo do `.env`:
```env
NC_DB_PASSWORD=sua_senha_forte
NC_ROOT_PASSWORD=sua_senha_root_forte
CLOUDFLARE_TUNNEL_TOKEN=seu_token_aqui
```

### Passo 6: Criar o Arquivo Principal (docker-compose.yml)
```yaml
services:
  nextcloud:
    build: .
    container_name: nextcloud
    restart: unless-stopped
    depends_on:
      - db
    volumes:
      - /mnt/data/nextcloud/data:/var/www/html/data
      - /mnt/data/nextcloud/config:/var/www/html/config
    environment:
      - MYSQL_PASSWORD=${NC_DB_PASSWORD}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_HOST=db
      - APACHE_DISABLE_REWRITE_IP=1
      - OVERWRITEPROTOCOL=https
      - OVERWRITEHOST=nextcloud.seu-dominio.com
    networks:
      - default

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
    networks:
      - default

  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    volumes:
      - /mnt/data/vaultwarden:/data
    environment:
      - WEBSOCKET_ENABLED=true
      - SIGNUPS_ALLOWED=false
    networks:
      - default

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}
    networks:
      - default

networks:
  default:
    driver: bridge
```

---

### NOTA DE CONTEXTO:
Perceba que na primeira linha do docker-compose.yml escrevemos 
```yaml
services:
  nextcloud:
    build: .
```
Quando na verdade o mais comum seria:
```yaml
services:
  nextcloud:
    image: nextcloud:latest 
```
Isso acontece porque na raiz desse projeto temos o arquivo Dockerfile.
No Dockerfile contém a então imagem nextcloud:latest, ou seja, ainda vamos baixar a imagem mais recente do nextcloud so que através de um dockerfile ao invés de ser direto no docker-compose. Então o build . significa "Construir o que está no dockerfile". Mas a grande vantagem é que além de construir ele ainda executa dentro do ambiente docker os comandos 
```dockerfile
RUN apt-get update && \
    apt-get install -y ffmpeg && \
    rm -rf /var/lib/apt/lists/*
```
Que fazem a instalação do ffmpeg que é fundamental para que o Nextcloud gere miniaturas (thumbnails) de vídeos MP4, MOV e outros formatos suportados. Caso contrário você veria miniaturas apenas de imagens em geral. A vantagem de ter o ffmpeg diretamente no container é que funcionará até em sistemas operacionais sem esse "programa" (ffmpeg) instalado. Pois ele virá dentro do container.

 [!NOTE]
> Se você estiver instalando este projeto do zero, nenhuma configuração adicional será necessária para miniaturas de vídeo.
> Caso esteja migrando de uma instalação antiga do Nextcloud que já possua arquivos enviados anteriormente, os vídeos antigos podem não exibir miniaturas imediatamente. Nesse caso basta acessar um vídeo ou reenviá-lo para que o Nextcloud gere a miniatura automaticamente.

### Passo 7: Configurar o Domínio e o Túnel na Cloudflare
1. **Domínio:** Adicione seu domínio na Cloudflare e altere os Nameservers no seu registrador.
2. **Tunnel:** No painel Zero Trust, crie um túnel, selecione Docker e copie o **Token** para o seu `.env`.
3. **Public Hostnames:**
   - `nextcloud.seu-dominio.com` -> `http://nextcloud:80`
   - `vaultwarden.seu-dominio.com` -> `http://vaultwarden:80`

---

## 🚀 Inicialização e Teste
```bash
docker compose up -d
docker compose logs -f
```
Acesse: `https://nextcloud.seu-dominio.com` e `https://vaultwarden.seu-dominio.com`.

---

## 🔁 Comandos Úteis para o Dia a Dia

| Ação | Comando |
| :--- | :--- |
| **Iniciar** | `docker compose up -d` |
| **Parar** | `docker compose down` |
| **Logs** | `docker compose logs -f [serviço]` |
| **Atualizar** | `docker compose pull && docker compose up -d` |

---

## ❓ Perguntas Frequentes (FAQ)

**1. Posso usar Caddy com CGNAT?**
Não diretamente. O Caddy precisa de portas abertas. O Cloudflare Tunnel é a solução para CGNAT.

**2. E se eu conseguir um IP público real depois?**
Você pode migrar para o Caddy, mas o Túnel continua sendo mais seguro por ocultar seu IP.

**3. Domínios são caros?**
Não. Extensões como `.cloud` ou `.xyz` custam menos de R$ 20,00/ano. Evite DuckDNS para esta configuração.

**4. Como fazer backup?**
Basta copiar a pasta `/mnt/data`:
```bash
rsync -av /mnt/data/ /caminho/do/backup/
```

---

## 🏁 Conclusão
Parabéns! Você agora tem uma nuvem privada e um cofre de senhas seguro rodando na sua própria casa, sem mensalidades e com total privacidade.

---
*Desenvolvido com ❤️ para a comunidade de Self-Hosting.*
