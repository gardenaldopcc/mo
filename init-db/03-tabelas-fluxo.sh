#!/bin/bash
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname bot -f /docker-entrypoint-initdb.d/fluxo/tabelas.sql
