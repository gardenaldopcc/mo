#!/bin/bash
# Laboratório: leads simulados conversam com o Henrique real (n8n + OpenAI), sem mandar nada no WhatsApp.
# Uso: ./laboratorio.command          (todas as personas)
#      ./laboratorio.command 5        (só 5 personas, sorteadas)
#      ./laboratorio.command todas 8 instalacao   (todas do grupo 'instalacao', 8 ao mesmo tempo)
cd "$(dirname "$0")"
python3 laboratorio/rodar.py "$@"
