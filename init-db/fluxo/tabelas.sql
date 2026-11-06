CREATE TABLE IF NOT EXISTS bot_pausa (
  telefone      TEXT PRIMARY KEY,
  pausado_ate   TIMESTAMPTZ NOT NULL,
  motivo        TEXT,
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cliente (
  telefone      TEXT PRIMARY KEY,
  jid           TEXT,
  nome          TEXT,
  etapa         TEXT NOT NULL DEFAULT 'novo',
  perfil        TEXT,
  cnpj          TEXT,
  empresa       TEXT,
  tentativas    INT NOT NULL DEFAULT 0,
  link_enviado  BOOLEAN NOT NULL DEFAULT false,
  criado_em     TIMESTAMPTZ NOT NULL DEFAULT now(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- IDs das mensagens que o próprio bot enviou (para diferenciar do atendente humano)
CREATE TABLE IF NOT EXISTS bot_enviadas (
  msg_id     TEXT PRIMARY KEY,
  telefone   TEXT,
  enviado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Agrupa mensagens enviadas em sequência pelo cliente antes de responder
CREATE TABLE IF NOT EXISTS fila_mensagens (
  id          BIGSERIAL PRIMARY KEY,
  telefone    TEXT NOT NULL,
  msg_id      TEXT UNIQUE,
  texto       TEXT NOT NULL,
  processada  BOOLEAN NOT NULL DEFAULT false,
  recebida_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fila_mensagens_tel_idx ON fila_mensagens (telefone, processada);

-- Conta quantas respostas da IA já foram dadas sem enviar o link do app
ALTER TABLE cliente ADD COLUMN IF NOT EXISTS turnos_sem_link INT NOT NULL DEFAULT 0;

-- Memória da conversa da IA (mesmo formato que o n8n usa)
CREATE TABLE IF NOT EXISTS n8n_chat_memoria (
  id         SERIAL PRIMARY KEY,
  session_id VARCHAR(255) NOT NULL,
  message    JSONB NOT NULL
);

-- Anotações da IA sobre o cliente e pergunta pendente feita durante o roteiro
ALTER TABLE cliente ADD COLUMN IF NOT EXISTS notas TEXT;
ALTER TABLE cliente ADD COLUMN IF NOT EXISTS pendente TEXT;

-- Segmento do lojista (bar/adega/quiosque/conveniência recebem a oferta de kits) e pedido de exclusão pendente
ALTER TABLE cliente ADD COLUMN IF NOT EXISTS segmento TEXT;
ALTER TABLE cliente ADD COLUMN IF NOT EXISTS apagar_solicitado_em TIMESTAMPTZ;
-- Quando a equipe foi avisada pela última vez (para avisar de novo se o cliente continuar esperando)
ALTER TABLE bot_pausa ADD COLUMN IF NOT EXISTS alertado_em TIMESTAMPTZ;
-- Menores bloqueados (só o hash do telefone): o bloqueio continua mesmo se o cliente pedir para apagar os dados
CREATE TABLE IF NOT EXISTS bloqueados (
  telefone_hash TEXT PRIMARY KEY,
  bloqueado_em  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Quantas respostas da IA desde que o link foi enviado (evita reenviar o link completo em seguida)
ALTER TABLE cliente ADD COLUMN IF NOT EXISTS turnos_desde_link INT NOT NULL DEFAULT 99;

-- Laboratório de testes: respostas do bot ficam aqui em vez de irem para o WhatsApp
CREATE TABLE IF NOT EXISTS bot_log (
  id        BIGSERIAL PRIMARY KEY,
  telefone  TEXT NOT NULL,
  texto     TEXT NOT NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Cliente sem Android (iPhone): o link do app não é enviado
ALTER TABLE cliente ADD COLUMN IF NOT EXISTS sem_android BOOLEAN NOT NULL DEFAULT false;

-- Último aviso à equipe (evita mandar a mesma dúvida no grupo a cada mensagem)
ALTER TABLE cliente ADD COLUMN IF NOT EXISTS ultimo_alerta TEXT;
ALTER TABLE cliente ADD COLUMN IF NOT EXISTS ultimo_alerta_em TIMESTAMPTZ;
