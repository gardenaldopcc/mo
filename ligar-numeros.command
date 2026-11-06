#!/bin/bash
# Liga ao bot todos os números de WhatsApp conectados no Evolution (use depois de conectar um número novo).
# Não precisa da chave da OpenAI nem reinstalar o fluxo.
cd "$(dirname "$0")"
source .env
INSTANCIA="Sessão Principal"
echo "▶ Ligando os números de WhatsApp ao bot..."
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

echo "✅ Pronto."
