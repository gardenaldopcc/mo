# Chatbot Atacadão das Bebidas

## Ligar / desligar
- Ligar: `./iniciar.command`  ·  Desligar: `./parar.command`  ·  Logs: `./logs.command`
- Evolution: http://localhost:8080/manager  (API Key: cc26120bc0d9b44e88cf9660ddb303ea4f7edbc9deded50a)
- n8n: http://localhost:5678

## Instalar ou atualizar o fluxo do bot
```bash
cd ~/Minha/mo
./instalar-fluxo.command
```
Pede a chave da OpenAI, cria tabelas e credenciais, importa e ativa o fluxo e liga o WhatsApp ao n8n.
Pode rodar de novo sempre que eu (Claude) atualizar o fluxo.

## O que você pode editar SEM mexer no n8n (vale na próxima mensagem)
Tudo fica na pasta `catalogo/`:
- `config.json` → link do app, link do vídeo, CNPJ da loja, nome do grupo da equipe, minutos de pausa
- `prompt-henrique.md` → instruções/personalidade do Henrique
- `respostas-prontas.md` → respostas para objeções e dúvidas
- `texto-apresentacao.txt` e `texto-link-app.txt` → mensagens fixas
- `catalogo-imagem.jpg` → arte do catálogo (mantenha o mesmo nome)
- Preços: edite `lista-original.txt` e rode `python3 catalogo/gerar_catalogo.py`

## Atendimento humano
- O bot chama humano sozinho (avisa no grupo "Bot Geral") e pausa a conversa.
- Se alguém da equipe responder um cliente pelo WhatsApp da loja, o bot pausa naquela conversa.
- Para devolver ao bot: envie `#bot` na conversa do cliente (a mensagem é apagada sozinha) ou aguarde 30 min sem mensagens.

## Testar
- Mande mensagem de um número cadastrado em `numeros_teste` (config.json).
- Envie `#reset` desse número para recomeçar o funil do zero.
- `"modo_teste": true` deixa as respostas rápidas. **Antes de liberar para clientes, mude para `false`** (volta o ritmo humano de digitação).

## Laboratório (testar com o Henrique de verdade, sem mandar nada no WhatsApp)
1. Deixe `"modo_teste": true` no `catalogo/config.json` e rode `./instalar-fluxo.command` (uma vez, depois de cada atualização).
2. Rode:
```bash
./laboratorio.command        # todas as 25 personas (5 por região)
./laboratorio.command 5      # só 5 personas sorteadas (mais rápido e barato)
```
3. As conversas ficam em `laboratorio/resultados/<data>/`. Me avise que eu analiso.
Personas: `laboratorio/personas/*.json` (dá para criar mais no mesmo formato).
