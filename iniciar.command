#!/bin/bash
cd "$(dirname "$0")"
if ! docker info >/dev/null 2>&1; then
  echo "Ligando o Colima..."
  colima start --cpu 4 --memory 6 --disk 30
fi
docker compose up -d
docker compose ps
echo ""
echo "Evolution API: http://localhost:8080/manager"
echo "n8n:           http://localhost:5678"
