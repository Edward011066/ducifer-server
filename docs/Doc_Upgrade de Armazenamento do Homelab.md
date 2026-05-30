# Tutorial Detalhado: Upgrade de Armazenamento do Homelab

Este tutorial irá guiá-lo passo a passo através do processo de upgrade do armazenamento do seu homelab, migrando os dados de um HD mecânico para um SSD NVMe e configurando o HD antigo para backups automáticos. Ele foi projetado para usuários com pouco ou nenhum conhecimento prévio em Linux, com explicações claras e exemplos práticos.

## 1. Entendendo o Ambiente e o Objetivo

Antes de começarmos, é importante entender o que temos e o que queremos alcançar. Seu homelab atualmente roda Ubuntu 26.04 LTS e possui dois discos:

*   **sdb (~300 GB):** Contém o sistema operacional (Ubuntu), Docker e outros serviços. Este disco não será alterado diretamente neste processo.
*   **sda (1 TB):** Atualmente armazena seus dados (Nextcloud, Vaultwarden) montados em `/mnt/data`. Este é um HD mecânico.

**Nosso objetivo principal é:**

1.  Adicionar um novo **SSD NVMe** para ser o armazenamento principal dos seus dados (Nextcloud, Vaultwarden), montado em `/mnt/data`.
2.  Configurar o **HD de 1 TB (sda)**, que atualmente guarda os dados, para ser o destino de **backups automáticos**.

Esta migração trará um ganho significativo de desempenho para seus serviços e melhorará a resiliência do seu sistema, separando o sistema operacional, os dados ativos e os backups.

## 2. Conceitos Básicos para Iniciantes

Para facilitar o entendimento, vamos revisar alguns termos e comandos essenciais:

*   **SSH (Secure Shell):** É a forma segura de se conectar e controlar seu servidor remotamente através da linha de comando. Você já está usando isso!
*   **Terminal/Linha de Comando:** É onde você digitará os comandos. No Linux, muitos processos são realizados por aqui.
*   **`sudo`:** Significa "SuperUser DO". Ao usar `sudo` antes de um comando, você o executa com privilégios de administrador (root). É como "Executar como administrador" no Windows. **Sempre use com cautela!**
*   **`lsblk`:** Lista informações sobre os dispositivos de bloco (seus discos e partições).
*   **`fdisk` ou `gdisk`:** Ferramentas para gerenciar partições em discos.
*   **`mkfs`:** Cria um sistema de arquivos (formata) em uma partição.
*   **`mount`:** Conecta um sistema de arquivos a um diretório no sistema de arquivos principal, tornando-o acessível.
*   **`umount`:** Desconecta um sistema de arquivos.
*   **`rsync`:** Uma ferramenta poderosa para sincronizar arquivos e diretórios, muito útil para copiar grandes volumes de dados de forma eficiente.
*   **`fstab`:** Um arquivo de configuração que define quais sistemas de arquivos devem ser montados automaticamente na inicialização do sistema.
*   **LUKS (Linux Unified Key Setup):** Um padrão para criptografia de disco, que protege seus dados contra acesso não autorizado em caso de perda ou roubo do disco.

## 3. Preparação e Instalação Física do NVMe

**Atenção:** Este tutorial assume que você já instalou fisicamente o SSD NVMe em seu servidor. Se você não fez isso, consulte o manual do seu hardware para instruções sobre como instalar um SSD NVMe. Certifique-se de que o servidor esteja desligado durante a instalação física.

Após a instalação física, ligue o servidor e reconecte-se via SSH.

## 4. Identificando o Novo SSD NVMe

Primeiro, precisamos identificar o novo SSD NVMe no sistema. Execute o seguinte comando:

```bash
lsblk -o NAME,SIZE,ROTA,TYPE,MOUNTPOINT
```

**Exemplo de Saída (pode variar):**

```
NAME                        SIZE ROTA TYPE MOUNTPOINT
sda                       931.5G    1 disk 
└─sda1                    931.5G    1 part /mnt/data
sdb                       298.1G    1 disk 
├─sdb1                        1G    1 part /boot/efi
├─sdb2                        2G    1 part /boot
└─sdb3                      295G    1 part 
  └─ubuntu--vg-ubuntu--lv   295G    1 lvm  /
nvme0n1                   500G    0 disk  
```

No exemplo acima, `nvme0n1` é o nosso novo SSD NVMe de 500GB. O `ROTA` sendo `0` indica que é um dispositivo de estado sólido (SSD), enquanto `1` indica um disco rotacional (HD). Anote o nome do seu novo NVMe (por exemplo, `nvme0n1`).

## 5. Criptografando o NVMe com LUKS

Vamos criptografar o novo NVMe para proteger seus dados. **Este passo é irreversível e apagará todos os dados existentes no disco (se houver). Certifique-se de que você selecionou o disco correto!**

### 5.1. Criando uma Partição (Opcional, mas Recomendado)

Embora você possa criptografar o disco inteiro, é uma boa prática criar uma partição primeiro. Usaremos `gdisk` para discos GPT (modernos).

```bash
sudo gdisk /dev/nvme0n1 # Substitua nvme0n1 pelo nome do seu NVMe
```

Dentro do `gdisk`:

1.  Digite `o` e pressione Enter para criar uma nova tabela de partições GPT vazia. Confirme com `y`.
2.  Digite `n` e pressione Enter para criar uma nova partição.
3.  Pressione Enter para o número da partição (padrão é 1).
4.  Pressione Enter para o primeiro setor (padrão).
5.  Pressione Enter para o último setor (padrão, para usar o disco inteiro).
6.  Pressione Enter para o código hexadecimal (padrão é Linux filesystem).
7.  Digite `w` e pressione Enter para gravar as mudanças no disco. Confirme com `y`.

Agora, seu NVMe deve ter uma partição, por exemplo, `nvme0n1p1`.

### 5.2. Criptografando a Partição

Agora, vamos criptografar a partição com LUKS. **Escolha uma senha forte e guarde-a em um local seguro! Se você perder esta senha, seus dados serão irrecuperáveis.**

```bash
sudo cryptsetup -y -v luksFormat /dev/nvme0n1p1 # Substitua nvme0n1p1 pela sua partição
```

Você será solicitado a digitar `YES` em maiúsculas para confirmar e, em seguida, digitar sua senha duas vezes.

### 5.3. Abrindo o Volume Criptografado

Para usar o disco criptografado, precisamos "abrir" o volume. Isso criará um dispositivo mapeado em `/dev/mapper/`.

```bash
sudo cryptsetup luksOpen /dev/nvme0n1p1 nvme_criptografado # Substitua nvme0n1p1
```

Você será solicitado a digitar a senha que você definiu. Após isso, você terá um novo dispositivo em `/dev/mapper/nvme_criptografado`.

## 6. Formatando o Volume Criptografado

Agora que o volume criptografado está aberto, podemos formatá-lo com um sistema de arquivos, como `ext4`.

```bash
sudo mkfs.ext4 /dev/mapper/nvme_criptografado
```

## 7. Montagem Temporária do Novo NVMe

Vamos criar um ponto de montagem temporário para copiar os dados.

```bash
sudo mkdir /mnt/newdisk
sudo mount /dev/mapper/nvme_criptografado /mnt/newdisk
```

Verifique se ele foi montado corretamente:

```bash
df -h /mnt/newdisk
```

## 8. Migrando os Dados com `rsync`

Esta é a parte crucial da migração. Usaremos `rsync` para copiar todos os dados do seu HD antigo (`/mnt/data`) para o novo NVMe (`/mnt/newdisk`).

### 8.1. Parando os Containers Docker

É **essencial** parar todos os serviços que estão acessando os dados em `/mnt/data` para garantir uma cópia consistente. No seu caso, Nextcloud e Vaultwarden provavelmente estão rodando em Docker. Você pode parar todos os containers com:

```bash
sudo docker stop $(sudo docker ps -aq)
```

Verifique se todos pararam:

```bash
sudo docker ps
```

Se houver outros serviços acessando `/mnt/data` que não sejam Docker, pare-os também.

### 8.2. Copiando os Dados

Agora, execute o `rsync`. Este comando pode levar um tempo considerável, dependendo do volume de dados. A opção `-aAXv` preserva permissões, links simbólicos, atributos estendidos e exibe o progresso.

```bash
sudo rsync -aAXv /mnt/data/ /mnt/newdisk/
```

**Explicação das opções:**

*   `-a`: Modo arquivo, que preserva permissões, proprietário, grupo, timestamps, links simbólicos, etc.
*   `-A`: Preserva ACLs (Access Control Lists).
*   `-X`: Preserva atributos estendidos.
*   `-v`: Modo verboso, mostra o que está sendo copiado.
*   `/mnt/data/`: A barra final é importante! Ela significa "copie o *conteúdo* de `/mnt/data`", não o diretório `/mnt/data` em si.
*   `/mnt/newdisk/`: O destino.

### 8.3. Sincronização Final

Após a cópia inicial, execute o `rsync` novamente. Como os serviços estão parados, esta cópia será muito mais rápida e garantirá que quaisquer pequenas alterações que ocorreram durante a primeira cópia (se houver) sejam sincronizadas.

```bash
sudo rsync -aAXv /mnt/data/ /mnt/newdisk/
```

## 9. Ajustando os Pontos de Montagem

Agora que os dados estão no NVMe, precisamos fazer com que o sistema monte o NVMe em `/mnt/data` e o HD antigo em um novo local para backup.

### 9.1. Desmontando os Discos

Primeiro, desmonte o HD antigo e o NVMe temporário.

```bash
sudo umount /mnt/data
sudo umount /mnt/newdisk
```

### 9.2. Obtendo UUIDs

Para garantir que os discos sejam montados corretamente mesmo se a ordem dos dispositivos mudar, usaremos seus UUIDs (Universally Unique Identifiers). O UUID é um identificador único para cada partição.

```bash
sudo blkid
```

Anote os UUIDs para:

*   A partição LUKS do seu NVMe (por exemplo, `/dev/nvme0n1p1`).
*   A partição do seu HD de 1TB (por exemplo, `/dev/sda1`).

**Exemplo de Saída `blkid`:**

```
/dev/sda1: UUID="<UUID_DO_HD_ANTIGO>" TYPE="ext4" PARTUUID="..."
/dev/sdb1: UUID="..." TYPE="vfat" PARTLABEL="..."
/dev/sdb2: UUID="..." TYPE="ext4" PARTUUID="..."
/dev/sdb3: UUID="..." TYPE="LVM2_member" PARTUUID="..."
/dev/mapper/ubuntu--vg-ubuntu--lv: UUID="..." TYPE="ext4"
/dev/nvme0n1p1: UUID="<UUID_DO_NVME_LUKS>" TYPE="crypto_LUKS" PARTUUID="..."
/dev/mapper/nvme_criptografado: UUID="<UUID_DO_NVME_FORMATADO>" TYPE="ext4"
```

Você precisará do UUID do `TYPE="crypto_LUKS"` para o NVMe e do UUID do `TYPE="ext4"` para o HD antigo.

### 9.3. Editando o `/etc/crypttab`

Para que o sistema abra o volume LUKS automaticamente na inicialização, precisamos adicionar uma entrada em `/etc/crypttab`. Este arquivo informa ao sistema quais volumes criptografados devem ser abertos e com qual nome.

```bash
sudo nano /etc/crypttab
```

Adicione a seguinte linha no final do arquivo, substituindo `<UUID_DO_NVME_LUKS>` pelo UUID que você anotou:

```
nvme_criptografado UUID=<UUID_DO_NVME_LUKS> none luks,discard
```

*   `nvme_criptografado`: O nome que daremos ao dispositivo mapeado.
*   `UUID=<UUID_DO_NVME_LUKS>`: O UUID da partição LUKS.
*   `none`: Não há arquivo de chave (a senha será solicitada no boot).
*   `luks,discard`: Opções para LUKS, `discard` permite o TRIM para SSDs.

Salve e saia do `nano` (Ctrl+O, Enter, Ctrl+X).

### 9.4. Editando o `/etc/fstab`

Agora, vamos editar o `/etc/fstab` para montar o NVMe em `/mnt/data` e o HD antigo em `/mnt/backup`.

```bash
sudo nano /etc/fstab
```

1.  **Remova ou comente** (adicione um `#` no início da linha) a linha referente ao seu HD antigo (`/dev/sda1` ou seu UUID) que montava em `/mnt/data`.

    **Exemplo (linha a ser comentada):**
    `UUID=<UUID_DO_HD_ANTIGO> /mnt/data ext4 defaults 0 2`

2.  Adicione as seguintes linhas no final do arquivo, substituindo os UUIDs pelos que você anotou:

    ```
    # Novo NVMe para dados
    UUID=<UUID_DO_NVME_FORMATADO> /mnt/data ext4 defaults,nofail 0 2

    # HD antigo para backup
    UUID=<UUID_DO_HD_ANTIGO> /mnt/backup ext4 defaults,nofail 0 2
    ```

    *   `UUID=<UUID_DO_NVME_FORMATADO>`: O UUID do volume criptografado *formatado* (o que você obteve de `/dev/mapper/nvme_criptografado`).
    *   `UUID=<UUID_DO_HD_ANTIGO>`: O UUID da partição do seu HD de 1TB.
    *   `nofail`: Importante! Garante que o sistema continue a inicializar mesmo se o disco não puder ser montado (útil para discos de backup que podem não estar sempre presentes ou para evitar problemas no boot se algo der errado).

Salve e saia do `nano` (Ctrl+O, Enter, Ctrl+X).

### 9.5. Criando o Ponto de Montagem para Backup

Crie o diretório para o HD de backup:

```bash
sudo mkdir /mnt/backup
```

### 9.6. Atualizando o `initramfs`

Para que as mudanças no `crypttab` sejam reconhecidas na inicialização, precisamos atualizar o `initramfs`.

```bash
sudo update-initramfs -u
```

## 10. Testando as Novas Montagens e Reiniciando

É crucial testar as novas configurações antes de reiniciar. Você pode tentar montar os discos manualmente para verificar se o `fstab` está correto.

```bash
sudo mount -a
```

Se não houver erros, verifique os pontos de montagem:

```bash
df -h
```

Você deve ver o NVMe montado em `/mnt/data` e o HD antigo em `/mnt/backup`.

Se tudo estiver correto, você pode reiniciar o servidor. **Este é o momento em que você precisará digitar a senha do LUKS para o NVMe durante o boot.** Se o seu servidor não tiver um monitor conectado, você pode precisar de um teclado e monitor temporariamente para digitar a senha.

```bash
sudo reboot
```

Após o reboot, reconecte-se via SSH e verifique novamente os pontos de montagem:

```bash
df -h
```

E também o conteúdo de `/mnt/data` para confirmar que seus dados estão lá:

```bash
ls -l /mnt/data
```

## 11. Reiniciando os Containers Docker

Com o NVMe montado corretamente em `/mnt/data`, você pode reiniciar seus containers Docker:

```bash
sudo docker start $(sudo docker ps -aq)
```

Verifique se estão rodando:

```bash
sudo docker ps
```

## 12. Configurando Backups Automáticos no HD Antigo

Agora que o HD de 1TB está montado em `/mnt/backup`, você pode configurá-lo como destino para seus backups. O PDF menciona que o HD de backup não terá LUKS, mas os backups em si serão criptografados pela ferramenta de backup.

Ferramentas de backup recomendadas:

*   **Restic:** Uma ferramenta de backup rápida, eficiente e segura que suporta criptografia e deduplicação. É excelente para backups incrementais.
*   **BorgBackup:** Outra ferramenta robusta com deduplicação e criptografia, ideal para backups de sistemas de arquivos.
*   **Duplicati:** Uma solução de backup de código aberto que suporta vários destinos e criptografia, com uma interface web opcional.

### Exemplo Básico com Restic (Instalação e Uso)

Vamos usar o Restic como exemplo. Primeiro, instale-o:

```bash
sudo apt update
sudo apt install restic
```

Inicialize um repositório Restic no seu disco de backup. **Escolha uma senha forte para o repositório Restic!**

```bash
sudo restic init --repo /mnt/backup/restic_repo
```

Crie um script de backup (por exemplo, `backup.sh`):

```bash
nano backup.sh
```

Adicione o seguinte conteúdo, substituindo `SUA_SENHA_RESTIC` pela senha que você definiu para o repositório Restic:

```bash
#!/bin/bash

export RESTIC_PASSWORD='SUA_SENHA_RESTIC'
RESTIC_REPO="/mnt/backup/restic_repo"

# Excluir diretórios que não precisam de backup
EXCLUDES="--exclude-dir=/mnt/data/nextcloud/data/__groupfolders --exclude-dir=/mnt/data/nextcloud/data/appdata_*/preview"

restic backup $EXCLUDES /mnt/data \
  --repo $RESTIC_REPO \
  --verbose

restic forget --repo $RESTIC_REPO \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --prune \
  --verbose

unset RESTIC_PASSWORD
```

Salve e saia (Ctrl+O, Enter, Ctrl+X).

Torne o script executável:

```bash
chmod +x backup.sh
```

Você pode testar o backup executando:

```bash
./backup.sh
```

### 12.1. Agendando Backups com `cron`

Para automatizar o backup, usaremos `cron`. `cron` é um agendador de tarefas no Linux.

```bash
sudo crontab -e
```

Se for a primeira vez, escolha um editor (geralmente `nano`). Adicione a seguinte linha no final do arquivo para executar o script de backup todos os dias à 1h da manhã:

```
0 1 * * * /home/ducifer/backup.sh >> /var/log/restic_backup.log 2>&1
```

*   `0 1 * * *`: Significa "à 1h da manhã, todos os dias da semana, todos os dias do mês, todos os meses".
*   `/home/ducifer/backup.sh`: O caminho completo para o seu script de backup.
*   `>> /var/log/restic_backup.log 2>&1`: Redireciona a saída do script (incluindo erros) para um arquivo de log, o que é muito útil para depuração.

Salve e saia (Ctrl+O, Enter, Ctrl+X).

## 13. Considerações Finais

Parabéns! Você realizou um upgrade significativo no seu homelab. Lembre-se de:

*   **Guardar bem a senha do LUKS e do Restic.**
*   **Monitorar os logs de backup** (`tail -f /var/log/restic_backup.log`) para garantir que estão funcionando corretamente.
*   **Testar a restauração de backups** periodicamente para ter certeza de que seus dados podem ser recuperados.

Este tutorial cobriu os passos essenciais. Para configurações mais avançadas de LUKS (como chaves de arquivo) ou Restic (como backups para armazenamento em nuvem), consulte a documentação oficial das ferramentas.

---
