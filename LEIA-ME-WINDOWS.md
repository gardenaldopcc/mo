# Rodando o bot 24 horas num PC com Windows

Requisitos: Windows 10 (22H2) ou 11, 8 GB de RAM, internet estável. O PC fica ligado na tomada o tempo todo.

## 1. Copiar a pasta
Copie a pasta inteira do projeto para o PC (ex.: `C:\chatbot`), **incluindo o arquivo `.env`** (ele guarda as senhas internas).
Evite pastas sincronizadas (OneDrive/Google Drive) e caminhos com acento.

## 2. Instalar os programas (uma vez)
1. Clique com o botão direito em **`0-instalar-programas.bat`** → *Executar como administrador*.
   Instala Docker Desktop, Git (traz o "bash") e Python.
2. **Reinicie o computador.**
3. Abra o **Docker Desktop** uma vez, aceite os termos e espere aparecer "Engine running".
   Em *Settings > General*, marque **"Start Docker Desktop when you sign in"**.
4. Clique com o botão direito em **`1-configurar-24h.bat`** → *Executar como administrador*.
   Ele desliga a suspensão/hibernação e cria duas tarefas no Windows: ligar o bot ao entrar no Windows e conferir a cada 10 minutos se ele continua de pé.

## 3. Ligar o bot (uma vez)
1. Dê dois cliques em **`iniciar.bat`** (sobe WhatsApp, n8n e banco).
2. Dê dois cliques em **`instalar-fluxo.bat`** (pede a chave da OpenAI, instala o fluxo e liga os números).
3. Abra `http://localhost:8080/manager`, entre com a `EVOLUTION_API_KEY` do `.env`, crie a conexão **"Sessão Principal"** e leia o QR Code com o celular do número.
   (No PC novo o WhatsApp precisa ser conectado de novo: a conexão do Mac não vem junto.)
4. Rode **`ligar-numeros.bat`** de novo depois de conectar (ou ao conectar outros números).
5. Confirme mandando `#reset` do seu número de teste.

**Atenção:** desligue o bot no Mac (`./parar.command`) antes de ligar no Windows. O mesmo número conectado nos dois lugares faz o WhatsApp derrubar uma das conexões.

## 4. Dia a dia
| Arquivo | Para quê |
|---|---|
| `iniciar.bat` | Liga tudo (o Windows já faz isso sozinho) |
| `parar.bat` | Desliga tudo |
| `logs.bat` | Ver o que está acontecendo / erros |
| `instalar-fluxo.bat` | Quando eu mandar um fluxo novo |
| `adicionar-numero.bat` | **Colocar um número novo**: abre uma janela que pede atendente, link e grupo, mostra o QR Code e liga o número ao bot |
| `ligar-numeros.bat` | Depois de conectar um número novo no Evolution |
| `laboratorio.bat` | Testes com leads simulados (`laboratorio.bat 10`) |

Mudanças nos arquivos da pasta `catalogo` (textos, preços, vídeo, `config.json`, `numeros.json`) valem na hora, sem reinstalar.

## 5. Para não cair
- **Login automático**: tecla Windows + R → `netplwiz` → desmarque "Os usuários devem digitar um nome de usuário e uma senha" (assim, depois de uma queda de energia, o Windows entra sozinho e o bot volta).
- **BIOS**: se tiver a opção *"Restore on AC Power Loss" / "AC Back"*, deixe em **On** (liga o PC sozinho quando a energia volta).
- **Windows Update**: em *Configurações > Windows Update > Horário ativo*, deixe ativo das 6h às 23h (reinicializações ficam para a madrugada). O bot volta sozinho depois.
- **Nobreak** é recomendado.
- **Memória (opcional)**: o Docker usa até metade da RAM (4 GB), o que dá conta. Se o PC ficar lento, crie o arquivo `C:\Users\<seu usuário>\.wslconfig` com:
  ```
  [wsl2]
  memory=5GB
  ```
  e reinicie.
