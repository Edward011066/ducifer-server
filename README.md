🚀 Guia Definitivo: Servidor Caseiro com
Nextcloud, Vaultwarden e Cloudflare Tunnel
Aprenda a contornar o CGNAT e criar sua própria nuvem e gerenciador de senhas de
forma gratuita, segura e sem abrir portas no roteador.
Este tutorial ensina, passo a passo, como transformar um computador antigo ou uma máquina virtual
rodando Ubuntu Server em um poderoso servidor pessoal. Seus serviços ficarão acessíveis de qualquer
lugar da internet, mesmo se você estiver atrás de CGNAT (a famosa "rede compartilhada" de provedores de
internet residenciais).
Vamos  instalar  o  Docker,  subir  containers  com  o  Nextcloud (sua  nuvem  pessoal  de  arquivos)  e  o
Vaultwarden (seu gerenciador de senhas seguro), e expor tudo para a internet usando o Cloudflare Tunnel
de forma totalmente gratuita, com certificado SSL/TLS automático.
📋 O que você vai precisar
Um computador dedicado: Pode ser um PC antigo, um Raspberry Pi ou uma Máquina Virtual (VM) na
sua rede local com o Ubuntu Server (versão 22.04 ou 24.04 LTS) instalado.
Um domínio próprio: Exemplo: meuservidor.cloud . Você pode adquirir um por valores muito baixos
em registradores como Cloudflare, GoDaddy ou Registro.br.
Conta gratuita na Cloudflare: Necessária para gerenciar o domínio e configurar o túnel de acesso.
Disco rígido extra (Opcional): Recomendado para armazenar os dados do Nextcloud e os bancos de
dados separadamente do sistema operacional.
💡 Por que é obrigatório ter um domínio?
O Cloudflare Tunnel exige um domínio real registrado sob sua conta para criar as rotas de acesso
externas. Com ele, você não precisará de IP fixo e nem de abrir portas no seu roteador doméstico.
🧠 Entendendo os Conceitos Importantes
Antes de iniciarmos a parte prática, é fundamental compreender como a arquitetura do seu servidor irá
funcionar. Isso facilitará a resolução de eventuais problemas.
1. O que é CGNAT e por que ele atrapalha?
A grande maioria dos provedores de internet residenciais utiliza uma tecnologia chamada CGNAT (Carrier-
Grade NAT) para economizar endereços de IP públicos. Na prática, isso significa que o seu roteador não
possui um IP exclusivo na internet; você compartilha o mesmo IP público com centenas de vizinhos.
• 
• 
• 
• 
Guia Definitivo: Servidor Caseiro
1


A principal consequência disso é que  você não consegue abrir portas no seu roteador para receber
conexões externas. Se você tentar hospedar um site tradicional na porta 80 ou 443, ninguém de fora da sua
casa conseguirá acessá-lo.
A Solução: O Cloudflare Tunnel resolve isso criando uma conexão de dentro para fora (do seu servidor local
para  os  servidores  da  Cloudflare).  Como  a  conexão  parte  do  seu  servidor,  o  bloqueio  do  CGNAT  é
completamente contornado.
2. Caddy versus Cloudflare Tunnel
O Caddy é um servidor web e proxy reverso excelente que gera certificados SSL de forma automática. No
entanto, ele só funciona se o seu servidor tiver um IP público acessível e se você puder abrir as portas 80 e
443 no roteador (como em uma VPS contratada na nuvem).
Em uma rede doméstica com CGNAT, o Caddy sozinho não consegue receber conexões de fora. É por isso
que, neste cenário, o Cloudflare Tunnel substitui o Caddy por completo. O tráfego da internet vai direto
para a Cloudflare e desce criptografado para o container do túnel no seu PC, tornando o uso de outro proxy
reverso desnecessário.
3. Estrutura de Diretórios no Linux (FHS)
Para manter o servidor organizado e evitar perdas de arquivos, usaremos o padrão de pastas do Linux:
Diretório
O que deve ser guardado aqui
/home/seu_usuario/
Arquivos pessoais, scripts de automação e seus projetos do Docker.
/mnt/  ou /media/
Pontos de montagem de discos rígidos extras, SSDs ou armazenamentos
externos.
/var/lib/docker/
Arquivos internos e de sistema do próprio Docker (não altere manualmente).
/etc/
Arquivos de configuração do sistema operacional Ubuntu.
Neste guia, salvaremos os dados do Nextcloud e dos bancos de dados em um HD extra montado no diretório
/mnt/data .
4. Entendendo os Volumes no Docker
No arquivo de configuração do Docker, você frequentemente encontrará a instrução de volumes parecida
com esta:
Guia Definitivo: Servidor Caseiro
2


Antes dos dois-pontos ( : ): É o caminho físico no HD do seu computador (Host).
Depois dos dois-pontos ( : ): É o caminho lógico dentro do container isolado.
Isso garante a persistência dos dados: se o container for atualizado ou reiniciado, seus arquivos continuam
salvos com segurança no seu HD real.
5. Docker, Compose e Imagens
Docker: É o motor que executa os serviços dentro de ambientes isolados chamados containers.
Docker Compose: Uma ferramenta que permite definir e rodar múltiplos serviços (como banco de dados
+ aplicativo) juntos, usando apenas um arquivo de configuração simplificado.
Imagem: É o pacote pronto do aplicativo (ex: a imagem oficial do Nextcloud). O container é essa imagem
rodando na prática.
🛠️ Passo a Passo Prático
Passo 1: Instalar o Ubuntu Server e Configurar o Básico
Baixe a imagem ISO oficial do Ubuntu Server (recomenda-se a versão estável LTS mais recente).
Grave a ISO em um pendrive utilizando softwares simples como o Rufus (no Windows) ou o comando 
dd  (no Linux).
Dê boot no computador antigo e siga as instruções de tela (escolha o idioma, layout do teclado e defina o
nome do usuário e senha do administrador).
Importante: Durante a instalação, marque a opção para Habilitar o OpenSSH Server. Isso permitirá que
você gerencie o servidor de qualquer outro computador da casa via terminal.
Após finalizar a instalação e reiniciar, atualize todo o sistema com o comando: 
Passo 2: Montar um HD Extra para os Dados (Opcional)
Se você possui um disco rígido separado para armazenar os arquivos da nuvem, siga os comandos abaixo
para prepará-lo e fazer com que ele inicie automaticamente com o sistema:
volumes:
  - /mnt/data/nextcloud/data:/var/www/html/data
• 
• 
• 
• 
• 
1. 
2. 
3. 
4. 
5. 
sudo apt update && sudo apt upgrade -y
Guia Definitivo: Servidor Caseiro
3


Passo 3: Instalar o Docker e Docker Compose
Utilize o script automatizado oficial fornecido pela própria Docker para garantir a instalação da versão mais
recente:
Confirme se ambos foram instalados com sucesso verificando suas versões:
# 1. Identifique o nome do seu disco extra (ex: sda, sdb)
sudo lsblk
# 2. Formate a partição do disco como ext4 (substitua pelo seu identificador correto, 
ex: sda1)
sudo mkfs.ext4 /dev/sda1
# 3. Crie a pasta onde o disco ficará acessível
sudo mkdir -p /mnt/data
# 4. Monte o disco temporariamente para teste
sudo mount /dev/sda1 /mnt/data
# 5. Descubra o código único (UUID) dessa partição para fixar a montagem
sudo blkid /dev/sda1
# 6. Abra o arquivo de inicialização do sistema para automatizar o processo
sudo nano /etc/fstab
# 7. Adicione a seguinte linha ao final do arquivo (substitua pelo seu UUID gerado):
# UUID=seu-codigo-uuid-aqui /mnt/data ext4 defaults 0 0
# 8. Teste se a configuração ficou correta e verifique o espaço disponível:
sudo mount -a
df -h /mnt/data
# Baixa e executa o instalador oficial
curl -fsSL https://get.docker.com | sudo sh
# Permite que seu usuário gerencie o Docker sem precisar digitar 'sudo' toda vez
sudo usermod -aG docker $USER
newgrp docker
docker --version
docker compose version
Guia Definitivo: Servidor Caseiro
4


Passo 4: Criar a Estrutura de Pastas do Projeto
Vamos  criar  os  diretórios  necessários  para  armazenar  os  arquivos  de  configuração  e  os  dados  das
aplicações dentro do nosso HD montado:
Passo 5: Criar o Arquivo de Senhas Seguras (.env)
Para evitar expor senhas diretamente nos arquivos principais, utilizaremos variáveis de ambiente ocultas em
um arquivo chamado .env :
Copie e cole as linhas abaixo no editor, substituindo os textos indicados por senhas fortes criadas por você:
Salve o arquivo (pressione Ctrl+O , Enter  e saia com Ctrl+X ). Em seguida, restrinja o acesso a esse
arquivo por segurança:
Passo 6: Criar o Arquivo Principal (docker-compose.yml)
Crie o arquivo que gerenciará a inicialização coordenada de todos os serviços:
# Pasta para os arquivos de configuração do Docker Compose
mkdir -p ~/docker/meuservidor
cd ~/docker/meuservidor
# Pastas dedicadas para os dados das aplicações dentro do HD
sudo mkdir -p /mnt/data/{nextcloud,mariadb,vaultwarden}
sudo mkdir -p /mnt/data/nextcloud/{data,config}
# Ajusta as permissões das pastas para que seu usuário consiga manipulá-las
sudo chown -R $USER:$USER /mnt/data
nano ~/docker/meuservidor/.env
# Banco de dados do Nextcloud (Crie senhas complexas)
NC_DB_PASSWORD=coloque_aqui_uma_senha_muito_forte_para_o_usuario
NC_ROOT_PASSWORD=coloque_aqui_uma_senha_muito_forte_para_o_root
# Token do Cloudflare Tunnel (Você irá obter este código no Passo 7)
CLOUDFLARE_TUNNEL_TOKEN=seu_token_da_cloudflare_ficara_aqui
chmod 600 ~/docker/meuservidor/.env
nano ~/docker/meuservidor/docker-compose.yml
Guia Definitivo: Servidor Caseiro
5


Cole o bloco de configuração abaixo integralmente:
Guia Definitivo: Servidor Caseiro
6


services:
  nextcloud:
    image: nextcloud:latest
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
      - OVERWRITEHOST=nextcloud.meuservidor.cloud   # <-- Substitua pelo seu 
subdomínio real
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
      - SIGNUPS_ALLOWED=false   # Bloqueia a criação de contas por desconhecidos após 
Guia Definitivo: Servidor Caseiro
7


⚠️ Atenção: Lembre-se de alterar a linha OVERWRITEHOST  colocando o endereço do domínio real que você
irá utilizar.
Passo 7: Configurar o Domínio e o Túnel na Cloudflare
7.1. Adicionar seu domínio na Cloudflare
Acesse o painel web da Cloudflare e crie uma conta. Clique em Add a domain (Adicionar um domínio).
Digite o domínio que você comprou (ex: meuservidor.cloud ).
A Cloudflare mostrará dois servidores de nome (Nameservers). Copie esses endereços e altere-os na
empresa onde você comprou o domínio (ex: Registro.br ou GoDaddy), substituindo os originais da
empresa pelos da Cloudflare. Aguarde alguns minutos até a propagação do domínio ocorrer.
7.2. Criar o Túnel via Painel Web
No menu lateral da Cloudflare, acesse a aba Zero Trust → Networks → Tunnels.
Clique em Create a tunnel (Criar um túnel) e atribua um nome a ele (ex: servidor-caseiro ).
Na tela de ambiente de execução, selecione a opção Docker.
O painel exibirá um comando contendo um código extenso. Copie apenas o texto do Token (a longa
sequência alfanumérica que fica após a palavra --token ).
Abra novamente o seu arquivo .env  no servidor e cole esse código na linha 
CLOUDFLARE_TUNNEL_TOKEN= .
No painel da Cloudflare, vá para a aba Public Hostname e adicione as duas rotas de acesso conforme a
tabela a seguir:
você se cadastrar
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
1. 
2. 
3. 
1. 
2. 
3. 
4. 
5. 
6. 
Guia Definitivo: Servidor Caseiro
8


Subdomínio
Domínio
Service URL (Endereço Interno)
nextcloud
meuservidor.cloud
http://nextcloud:80
vaultwarden
meuservidor.cloud
http://vaultwarden:80
💡 Por que o endereço interno usa HTTP puro e o nome do serviço?
Como o container do túnel ( cloudflared ) e os aplicativos estão rodando dentro da mesma rede
interna do Docker, eles conseguem se comunicar pelo nome do serviço criado. A Cloudflare cuida de
toda a segurança HTTPS e criptografia na internet, enquanto a comunicação interna local consome
menos processamento usando HTTP comum.
Passo 8: Inicializar os Serviços
Com todas as configurações salvas, execute o comando na pasta do projeto para baixar as imagens e iniciar
o servidor de forma silenciosa (em segundo plano):
Você pode acompanhar o processo de inicialização e verificar se o túnel se conectou sem erros lendo os
logs:
Passo 9: Testar o Acesso Externo
Abra o navegador do seu celular ou de qualquer outro computador fora da sua rede e acesse os endereços
criados:
https://nextcloud.seu-dominio.cloud  (Para gerenciar seus arquivos e fotos)
https://vaultwarden.seu-dominio.cloud  (Para armazenar e sincronizar suas senhas)
No primeiro acesso, ambos os sistemas guiarão você para criar a sua conta master de administrador.
🔁 Comandos Úteis para o Dia a Dia
Abaixo estão reunidos os principais comandos que você precisará usar para manter o seu servidor rodando
perfeitamente:
cd ~/docker/meuservidor
docker compose up -d
docker compose logs -f
• 
• 
Guia Definitivo: Servidor Caseiro
9


Ação Desejada
Comando do Terminal
Iniciar os serviços em segundo plano
docker compose up -d
Parar e desligar todos os containers
docker compose down
Visualizar logs em tempo real de um serviço
docker compose logs -f [nome_do_serviço]
Reiniciar um container específico
docker compose restart nextcloud
Atualizar as imagens para a versão mais
recente
docker compose pull && docker compose up -d
Acessar o terminal interno de um container
docker exec -it nextcloud bash
❓ Perguntas Frequentes (FAQ)
1. Posso utilizar o Caddy mesmo se estiver sob a rede CGNAT?
Não. Conforme explicado, o Caddy depende obrigatoriamente de que as portas físicas 80 e 443 do seu
modem/roteador estejam totalmente abertas e apontadas para a internet pública, o que é impossível em uma
infraestrutura de CGNAT.
2. E se no futuro o meu provedor me fornecer um IP público real?
Caso consiga um IP público dedicado, você tem a opção de desativar o container do Cloudflare Tunnel e
migrar para uma estrutura clássica usando o Caddy como proxy reverso. Porém, manter o Cloudflare Tunnel
continua sendo uma excelente opção pela segurança de não expor o IP da sua casa na internet.
3. É necessário gastar muito dinheiro para adquirir um domínio?
Não.  Extensões  de  domínios  como  .cloud ,  .xyz  ou  .top  são  extremamente  baratas  e  custam
geralmente menos de R$ 20,00 por ano. Evite usar subdomínios dinâmicos gratuitos (como DuckDNS), pois
eles não integram perfeitamente com o ecossistema de túneis da Cloudflare.
4. Como posso realizar o backup completo dos meus dados?
Como  centralizamos  todas  as  pastas  importantes  no  diretório  /mnt/data ,  basta  realizar  a  cópia  ou
sincronização dessa pasta para um outro HD externo ou serviço externo de backup usando ferramentas
nativas do Linux como o rsync : 
5. Sinto o Nextcloud um pouco lento. Existe alguma otimização?
A  velocidade  do  sistema  em  servidores  caseiros  depende  muito  da  velocidade  de  leitura  do  disco
(recomenda-se fortemente o uso de SSDs para o sistema de banco de dados). Adicionalmente, configurar o
rsync -av /mnt/data/ /caminho/do/seu/hd/externo/
Guia Definitivo: Servidor Caseiro
10


gerenciador  de  cache  Redis na  documentação  avançada  do  Nextcloud  melhora  drasticamente  o
carregamento da interface.
🏁 Conclusão
Parabéns! Você estruturou e colocou em funcionamento um ambiente completo de nuvem privada e cofre de
senhas de nível corporativo dentro da sua própria casa, sem pagar mensalidades e contornando todas as
limitações  técnicas  impostas  pelas  operadoras.  Mantendo  seu  sistema  operacional  atualizado
periodicamente, você terá uma plataforma estável e segura por muitos anos.
Guia Definitivo: Servidor Caseiro
11
