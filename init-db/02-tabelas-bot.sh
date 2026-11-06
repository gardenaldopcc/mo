#!/bin/bash
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname bot <<'SQL'
CREATE TABLE IF NOT EXISTS bot_pausa (
  telefone      TEXT PRIMARY KEY,
  pausado_ate   TIMESTAMPTZ NOT NULL,
  motivo        TEXT,
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
SQL
