#!/bin/bash
# Instala/atualiza o fluxo do chatbot no n8n. Pode rodar de novo sempre que o fluxo for atualizado.
set -e
cd "$(dirname "$0")"
source .env
INSTANCIA="${INSTANCIA:-Sessão Principal}"

echo "▶ 1/6 Subindo os serviços com a configuração nova..."
chmod -R a+rX catalogo init-db fluxo
docker compose up -d
until docker compose exec -T postgres pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; do sleep 2; done

echo "▶ 2/6 Criando as tabelas do fluxo..."
docker compose exec -T -e PGOPTIONS="-c client_min_messages=warning" postgres psql -q -U "$POSTGRES_USER" -d bot -f /docker-entrypoint-initdb.d/fluxo/tabelas.sql

echo "▶ 3/6 Chave da OpenAI"
if [ -z "$OPENAI_KEY" ]; then
  read -r -s -p "   Cole a sua chave da OpenAI (sk-...) e aperte Enter (ela não aparece na tela): " OPENAI_KEY; echo
fi
MODELOS=$(curl -s https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_KEY" | python3 -c 'import sys,json; print("\n".join(sorted(m["id"] for m in json.load(sys.stdin).get("data",[]))))' 2>/dev/null || true)
if [ -z "$MODELOS" ]; then echo "   ❌ Não consegui validar a chave da OpenAI. Confira a chave e se há créditos na conta."; exit 1; fi
# Testa um modelo de chat com os mesmos parâmetros que o fluxo usa (os que "pensam" usam parâmetros diferentes)
testar_chat() {
  python3 - "$1" "$OPENAI_KEY" <<'PY'
import json, sys, urllib.request
modelo, chave = sys.argv[1:]
pensa = not modelo.startswith("gpt-4")
corpo = {"model": modelo, "messages": [{"role": "user", "content": 'Responda só o JSON {"ok": true}'}],
         "response_format": {"type": "json_object"}}
corpo.update({"reasoning_effort": "low", "max_completion_tokens": 2000} if pensa else {"temperature": 0, "max_tokens": 20})
req = urllib.request.Request("https://api.openai.com/v1/chat/completions", data=json.dumps(corpo).encode(),
                             headers={"Authorization": f"Bearer {chave}", "Content-Type": "application/json"})
try:
    json.load(urllib.request.urlopen(req, timeout=60))["choices"][0]["message"]["content"]
except Exception as e:
    sys.exit(1)
PY
}
# Testa um modelo de transcrição com um áudio curto gerado pelo próprio Mac
testar_audio() {
  # Fora do Mac (ex.: Windows) não há como gerar o áudio de teste: aceita o modelo se ele existir na conta
  command -v say >/dev/null 2>&1 || return 0
  [ -f /tmp/teste-audio-chatbot.m4a ] || { say -o /tmp/teste-audio-chatbot.aiff "Oi, quero um fardo de cerveja" && afconvert -f m4af -d aac /tmp/teste-audio-chatbot.aiff /tmp/teste-audio-chatbot.m4a; } >/dev/null 2>&1 || return 1
  curl -s -f https://api.openai.com/v1/audio/transcriptions -H "Authorization: Bearer $OPENAI_KEY" \
    -F file=@/tmp/teste-audio-chatbot.m4a -F model="$1" -F language=pt -F prompt="Atendimento de distribuidora de bebidas" >/dev/null 2>&1
}

# Modelo do chat: o primeiro da lista que existir na conta e passar no teste (MODELO=... força um específico)
MODELO_ESCOLHIDO=""
for M in ${MODELO:-gpt-6-luna gpt-4.1-mini}; do
  if echo "$MODELOS" | grep -qx "$M" && testar_chat "$M"; then MODELO_ESCOLHIDO="$M"; break; fi
  echo "   ⚠️  O modelo $M não está disponível ou não respondeu ao teste."
done
if [ -z "$MODELO_ESCOLHIDO" ]; then
  echo "   Modelos disponíveis na sua conta:"
  echo "$MODELOS" | grep -E "^gpt-" | grep -viE "audio|realtime|tts|transcribe|search|image" | sed 's/^/     - /'
  read -r -p "   Digite o nome do modelo que deseja usar: " MODELO_ESCOLHIDO
  testar_chat "$MODELO_ESCOLHIDO" || { echo "   ❌ O modelo $MODELO_ESCOLHIDO não respondeu ao teste."; exit 1; }
fi
MODELO="$MODELO_ESCOLHIDO"

# Modelo dos áudios: o primeiro que existir na conta e transcrever o áudio de teste
TRANSCRICAO=""
for M in gpt-transcribe gpt-4o-mini-transcribe-2025-12-15 gpt-4o-mini-transcribe whisper-1; do
  if echo "$MODELOS" | grep -qx "$M" && testar_audio "$M"; then TRANSCRICAO="$M"; break; fi
done
[ -n "$TRANSCRICAO" ] || { TRANSCRICAO=whisper-1; echo "   ⚠️  Não consegui testar a transcrição de áudio; usando whisper-1."; }
rm -f /tmp/teste-audio-chatbot.aiff /tmp/teste-audio-chatbot.m4a 2>/dev/null || true
echo "   ✅ Modelo do chat: $MODELO  |  Áudios: $TRANSCRICAO"

echo "▶ 4/6 Criando as credenciais no n8n..."
python3 - "$POSTGRES_USER" "$POSTGRES_PASSWORD" "$EVOLUTION_API_KEY" "$OPENAI_KEY" > /tmp/credenciais-chatbot.json <<'PY'
import json, sys
u, senha, evo, oai = sys.argv[1:]
print(json.dumps([
  {"id": "pgBotCred0000001", "name": "Postgres Bot", "type": "postgres",
   "data": {"host": "postgres", "port": 5432, "database": "bot", "user": u, "password": senha, "ssl": "disable"}},
  {"id": "evoApiCred000001", "name": "Evolution API", "type": "httpHeaderAuth", "data": {"name": "apikey", "value": evo}},
  {"id": "openAiCred000001", "name": "OpenAI", "type": "openAiApi", "data": {"apiKey": oai}},
]))
PY
docker compose exec -T n8n sh -c 'cat > /tmp/cred.json' < /tmp/credenciais-chatbot.json
rm -f /tmp/credenciais-chatbot.json
docker compose exec -T n8n sh -c 'n8n import:credentials --input=/tmp/cred.json >/dev/null 2>&1; rm -f /tmp/cred.json'

echo "▶ 5/6 Importando e ativando o fluxo..."
python3 - "$MODELO" "$TRANSCRICAO" <<'PY' | docker compose exec -T n8n sh -c 'cat > /tmp/wf.json'
import json, sys
modelo, audio = sys.argv[1:]
wf = json.loads(open('fluxo/chatbot-workflow.json').read().replace('__MODELO_CHAT__', modelo).replace('__MODELO_AUDIO__', audio))
# Modelos antigos (gpt-4...) não "pensam": usam temperatura em vez de esforço de raciocínio
if modelo.startswith('gpt-4'):
    for n in wf['nodes']:
        if n['type'].endswith('lmChatOpenAi'):
            n['parameters']['options'] = {'temperature': 0.3}
print(json.dumps(wf))
PY
docker compose exec -T n8n sh -c 'n8n import:workflow --input=/tmp/wf.json >/dev/null 2>&1 && n8n publish:workflow --id=chatbotAtacadao01 >/dev/null 2>&1; rm -f /tmp/wf.json'
docker compose restart n8n >/dev/null
until curl -s localhost:5678/healthz >/dev/null 2>&1; do sleep 2; done

echo "▶ 6/6 Apontando os números de WhatsApp (Evolution) para o n8n..."
# Todas as conexões do Evolution (um número de WhatsApp cada) mandam mensagens para o mesmo fluxo
INSTANCIAS=$(curl -s "http://localhost:8080/instance/fetchInstances" -H "apikey: $EVOLUTION_API_KEY" | python3 -c '
import json, sys
dados = json.load(sys.stdin)
for i in (dados if isinstance(dados, list) else []):
    nome = i.get("name") or i.get("instanceName") or (i.get("instance") or {}).get("instanceName")
    if nome: print(nome)')
[ -n "$INSTANCIAS" ] || INSTANCIAS="$INSTANCIA"
while IFS= read -r NOME; do
  [ -n "$NOME" ] || continue
  INST_URL=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$NOME")
  RESP=$(curl -s -X POST "http://localhost:8080/webhook/set/$INST_URL" -H "apikey: $EVOLUTION_API_KEY" -H "content-type: application/json" \
    -d '{"webhook":{"enabled":true,"url":"http://n8n:5678/webhook/whatsapp","byEvents":false,"base64":true,"events":["MESSAGES_UPSERT"]}}')
  if echo "$RESP" | grep -q '"enabled":true'; then
    ATENDENTE=$(python3 -c '
import json, sys
try: n = json.load(open("catalogo/numeros.json", encoding="utf-8"))
except Exception: n = {}
c = json.load(open("catalogo/config.json", encoding="utf-8"))
print((n.get(sys.argv[1]) or {}).get("atendente") or ("⚠️  sem cadastro em catalogo/numeros.json — vai usar " + c.get("atendente", "")))' "$NOME")
    echo "   ✅ $NOME → $ATENDENTE"
  else
    echo "   ❌ Não consegui configurar o número $NOME: $RESP"
  fi
done <<< "$INSTANCIAS"

echo ""
echo "✅ Tudo pronto! O bot já está respondendo nos números acima."
echo "   Fluxo no n8n: http://localhost:5678"
