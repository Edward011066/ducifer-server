# Guia de Sobrevivência Self-Host do Eduardo 🚀

Olá, Eduardo! Este guia foi feito especialmente para você, que montou seu próprio servidor com peças reais e está mergulhando no mundo do self-hosting. Aqui você aprenderá desde os fundamentos até como proteger sua vida digital que agora mora nesse HD de 1TB.

---

## 1. O Coração do seu Servidor: Fundamentos de Linux

Você já conhece o `cd` e o `lsblk`. Vamos expandir esse vocabulário com o que você realmente vai usar no dia a dia.

### Comandos Essenciais (O "Kit de Ferramentas")

| Comando | O que faz (em português claro) | Quando usar |
| :--- | :--- | :--- |
| `sudo` | "Manda quem pode". Dá poderes de administrador. | Sempre que um comando der "Permission denied". |
| `df -h` | "Quanto espaço sobra?". Mostra o uso do disco. | Para saber se o seu HD de 1TB está enchendo. |
| `top` ou `htop` | "Gerenciador de Tarefas". Mostra o que está pesando. | Se o Nextcloud ficar lento. |
| `docker ps` | "Quem está vivo?". Lista seus containers rodando. | Para ver se o Vaultwarden ou Nextcloud caíram. |
| `docker logs -f [nome]` | "O que está acontecendo?". Mostra as mensagens de erro. | Quando algo não abre no navegador. |

> **Dica de Ouro:** No terminal, você não precisa digitar nomes de pastas inteiros. Digite as primeiras letras e aperte a tecla **TAB**. O Linux completa para você!

---

## 2. Gerenciando Discos: O seu HD de 1TB e o Futuro de 4TB

Você viu no seu `lsblk` que tem o `sda1` montado em `/mnt/data`. Isso é ótimo! Mas o que acontece se você quiser trocar esse disco?

### Como adicionar um novo HD (Passo a Passo)
1. **Conecte o HD:** O Linux vai reconhecê-lo como `sdc` ou algo parecido. Use `lsblk` para confirmar.
2. **Formate (Cuidado!):** Use `sudo mkfs.ext4 /dev/sdX` (troque o X pela letra do novo disco). Isso apaga tudo nele.
3. **Monte:** Crie uma pasta (ex: `sudo mkdir /mnt/backup`) e use `sudo mount /dev/sdX /mnt/backup`.

### O Upgrade para 4TB no Futuro
Quando seu HD de 1TB ficar pequeno, você não precisa reinstalar nada. O Linux é como um LEGO.

1. **Conecte o HD de 4TB** (via SATA ou USB).
2. **Crie a partição:** Use o comando `sudo fdisk /dev/sdc` (assumindo que o novo é o SDC). Digite `n` para nova, `p` para primária e vá dando Enter até o fim. Digite `w` para salvar.
3. **Formate:** `sudo mkfs.ext4 /dev/sdc1`.
4. **Copie os dados (O Comando Mágico):**
   ```bash
   sudo rsync -avxHAX --progress /mnt/data/ /mnt/novo_disco/
   ```
   - Este comando copia TUDO (arquivos, permissões, datas) exatamente como estão.
5. **Ajuste o "GPS" do Linux (fstab):** O arquivo `/etc/fstab` diz ao Linux qual HD montar em qual pasta. Você só precisará trocar o ID do HD velho pelo ID do HD novo. Para ver o ID (UUID), use: `blkid`.

> **Dica de Segurança:** Nunca apague o HD de 1TB até ter certeza de que o de 4TB está funcionando perfeitamente por pelo menos uma semana! Ele será seu "backup de emergência" durante a transição.

---

## 3. Resiliência: O que fazer quando a luz cai? 🔌

Você mencionou que sua BIOS não tem a opção de ligar sozinha. Aqui estão as soluções reais:

### Solução de Hardware (O "Pulo do Gato")
Se a BIOS falha, usamos a física. Aqui estão as opções da mais simples para a mais robusta:

1. **O Truque do Capacitor (Custo Zero):** 
   - Se você tem um ferro de solda, pode soldar um **capacitor eletrolítico (ex: 470uF 16V)** em paralelo com os pinos do botão de Power na placa-mãe. 
   - **Como funciona:** Quando a fonte recebe energia, o capacitor carrega instantaneamente, o que a placa-mãe interpreta como um "curto" momentâneo (o mesmo que apertar o botão). Assim que carrega, ele para de conduzir, simulando que você soltou o botão.
2. **Relé de 5V ou 12V (Mais Seguro):** 
   - Você pode usar um pequeno relé conectado a uma saída de energia da fonte (como um fio vermelho de 5V ou amarelo de 12V). 
   - Os contatos do relé (Normalmente Aberto) são ligados aos pinos do botão de Power. Quando a fonte liga, o relé fecha o contato por um segundo e liga o PC.
3. **Tomada Inteligente + Configuração (A mais moderna):** 
   - Compre uma tomada inteligente (Tuya/Smart Life). Configure-a no aplicativo para "Restaurar estado: Ligado". 
   - Se a sua placa-mãe for muito antiga e não tiver NADA na BIOS, você pode usar um módulo **"Esp8266 PC Power Switch"** (vende no AliExpress/Mercado Livre). Ele liga direto nos pinos da placa-mãe e você controla pelo celular de qualquer lugar do mundo.

> **Importante:** Se você não se sente confortável soldando na placa-mãe, a opção do módulo pronto (Esp8266) é a mais segura e profissional. Ela custa uns 50-80 reais e te dá controle total.

### Boas Práticas de Software
Para que o Docker volte sozinho quando o PC ligar, garanta que seus containers tenham a política de reinicialização:
`restart: always` ou `restart: unless-stopped` no seu arquivo `docker-compose.yml`.

---

## 4. Backups: Protegendo sua Vida Digital 🛡️

Fazer backup não é apenas copiar arquivos. É ter certeza de que você consegue restaurar.

### Backup Incremental com Restic ou Kopia
Como você é leigo, recomendo o **Kopia** ou **Restic**. Eles fazem o seguinte:
1. Na primeira vez, copiam tudo.
2. Nas próximas, copiam **apenas o que mudou**.
3. Se você deletar algo por querer, pode voltar no tempo e recuperar a versão de ontem ou de semana passada.

**O Plano de Backup para o Eduardo:**
*   **Disco A (1TB):** Onde estão seus dados ativos.
*   **Disco B (Externo ou outro interno):** Onde o Kopia vai salvar os backups.
*   **Nuvem (Opcional):** O Kopia pode mandar uma cópia criptografada para o Google Drive ou Backblaze automaticamente.

---

## 5. Criptografia: Vale a pena usar LUKS? 🔐

O **LUKS** protege seus dados se alguém roubar o seu HD físico.
*   **Vale a pena?** Sim, se você teme furto.
*   **O Problema:** Se o PC cair a energia e ligar sozinho, ele vai parar numa tela preta pedindo a senha do HD. Ele **não vai subir o Nextcloud** até você digitar a senha.
*   **Solução para Self-Host:** Use criptografia apenas em pastas sensíveis ou aceite que, para ter automação total (ligar sozinho), o HD precisa abrir sem senha manual (ou usar um pendrive como chave).

---

## 6. Boas Práticas: Sincronização e Dispositivos

*   **No Windows:** Use o cliente Nextcloud com "Arquivos Virtuais". Você vê tudo, mas não baixa nada até precisar.
*   **No iOS/Android:** Ative o "Upload de Câmera". Assim que você tira uma foto, ela vai para o seu servidor em casa.
*   **Segurança:** Como você usa Cloudflare Tunnel, você está seguro contra ataques diretos no seu IP. Mantenha o **2FA (Autenticação em duas etapas)** ativado no Nextcloud e Vaultwarden!

---

## Próximos Passos: O que ler amanhã?
1. Aprenda a usar o `docker-compose`. É muito mais fácil que rodar comandos `docker run` gigantes.
2. Compre um **No-break (UPS)** simples. Ele segura o PC por 15 minutos, tempo suficiente para ele desligar com segurança se a luz não voltar.

Este é apenas o começo, Eduardo. Seu servidor é sua liberdade digital! 

---

## 7. O Próximo Nível: Docker Compose 🐳

Hoje você usa comandos `docker run`. Isso é difícil de lembrar. O **Docker Compose** é um arquivo de texto onde você escreve a "receita" do seu servidor.

### Por que usar?
- Se o servidor pifar, você leva esse arquivo para outro PC, digita um comando e **tudo volta exatamente como estava**.
- É muito mais fácil de ler e organizar.

**Exemplo de como seria o seu arquivo `docker-compose.yml`:**
```yaml
services:
  nextcloud:
    image: nextcloud:latest
    restart: always
    volumes:
      - /mnt/data/nextcloud:/var/www/html
    environment:
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD=sua_senha
      - MYSQL_HOST=db

  db:
    image: mariadb:10.11
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=sua_senha_root
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD=sua_senha
```

---

## 8. Checklist de Manutenção (Para ler todo domingo)

1.  **Espaço em disco:** Rode `df -h`. Se o `/mnt/data` estiver com mais de 90%, hora de pensar no HD de 4TB.
2.  **Logs de Erro:** Rode `docker ps`. Se algum container estiver com status "Restarting", algo está errado.
3.  **Teste o Backup:** Tente restaurar um arquivo aleatório do seu backup uma vez por mês. Backup que não foi testado não é backup!
4.  **Atualizações:** De vez em quando, rode:
    ```bash
    sudo apt update && sudo apt upgrade -y
    ```
    Isso mantém o seu Linux (Ubuntu/Debian) seguro contra hackers.

---

## 9. Considerações Finais: O Futuro com Raspberry Pi

Se você decidir migrar para um Raspberry Pi no futuro:
- **Vantagem:** Consome quase nada de energia (pode ficar ligado 24h por centavos).
- **Desvantagem:** É menos potente que um PC real. O Nextcloud pode ficar um pouco mais lento.
- **Dica:** Se for para o Raspberry, use um **SSD externo** via USB 3.0. Nunca confie seus dados apenas num cartão SD, eles queimam fácil!

Eduardo, você está construindo sua própria independência digital. No começo parece muita coisa, mas em um mês esses comandos serão naturais para você. Qualquer dúvida, recorra a este guia!
