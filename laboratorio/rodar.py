#!/usr/bin/env python3
"""Laboratório de testes do Henrique.

Leads simulados por IA conversam com o fluxo REAL do n8n (mesma OpenAI, mesmo prompt),
mas as respostas do bot vão para a tabela bot_log em vez do WhatsApp.

Uso (na pasta do projeto):  python3 laboratorio/rodar.py [quantidade|todas] [quantas_ao_mesmo_tempo] [grupo]
  grupo = parte do nome do arquivo de personas ou do id (ex.: instalacao, nordeste, sul-01)
"""
import getpass
import hashlib
import glob
import json
import os
import random
import subprocess
import sys
import time
import urllib.request
import re
import unicodedata
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

PASTA = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.dirname(PASTA)
WEBHOOK = "http://localhost:5678/webhook/whatsapp"
MAX_TURNOS = int(os.environ.get("MAX_TURNOS", 14))
SILENCIO_FIM_RESPOSTA = 7      # segundos sem mensagem nova = o bot terminou de responder
ESPERA_MAXIMA = 90             # segundos esperando a resposta do bot


def sql(comando):
    base = os.environ.get("LAB_PSQL", "docker compose exec -T postgres psql -U chatbot -d bot").split()
    r = subprocess.run(base + ["-tA", "-F", "\t", "-c", comando], cwd=PROJETO, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr)
    return [linha.split("\t") for linha in r.stdout.strip().splitlines() if linha]


def openai(chave, modelo, mensagens, temperatura=0.9):
    # Modelos que "pensam" (gpt-5/gpt-6...) não aceitam temperatura e contam o raciocínio no limite de tokens
    extra = {"temperature": temperatura, "max_tokens": 300} if modelo.startswith("gpt-4") else {"reasoning_effort": "low", "max_completion_tokens": 2000}
    corpo = json.dumps({"model": modelo, "messages": mensagens, **extra}).encode()
    req = urllib.request.Request(os.environ.get("OPENAI_BASE", "https://api.openai.com/v1") + "/chat/completions", data=corpo,
                                 headers={"Authorization": f"Bearer {chave}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)["choices"][0]["message"]["content"].strip()


# Qual número da loja o lead "chama" (LAB_INSTANCIA=nome da conexão no Evolution; padrão: o principal)
INSTANCIA = os.environ.get("LAB_INSTANCIA", "Sessão Principal")


def chave_conversa(telefone):
    # Mesma regra do fluxo: números que não são o principal ganham "#nome-da-conexão"
    if INSTANCIA == "Sessão Principal":
        return telefone
    slug = "".join(c for c in unicodedata.normalize("NFD", INSTANCIA) if unicodedata.category(c) != "Mn").lower()
    slug = re.sub(r"[^a-z0-9]+", "-", slug).strip("-")
    return f"{telefone}#{slug}"


def enviar_ao_bot(telefone, nome, texto):
    corpo = {"event": "messages.upsert", "instance": INSTANCIA, "lab": True,
             "data": {"key": {"remoteJid": f"{telefone}@s.whatsapp.net", "fromMe": False, "id": "LAB" + uuid.uuid4().hex[:16]},
                      "pushName": nome, "message": {"conversation": texto}, "messageType": "conversation"}}
    req = urllib.request.Request(WEBHOOK, data=json.dumps(corpo).encode(), headers={"Content-Type": "application/json"})
    urllib.request.urlopen(req, timeout=15).read()


def esperar_respostas(telefone, ultimo_id):
    inicio, ultima_novidade, respostas = time.time(), None, []
    while time.time() - inicio < ESPERA_MAXIMA:
        linhas = sql(f"SELECT id, replace(texto, E'\\n', '⏎') FROM bot_log WHERE telefone = '{chave_conversa(telefone)}' AND id > {ultimo_id} ORDER BY id")
        if linhas:
            for i, t in linhas:
                respostas.append(t.replace("⏎", "\n"))
                ultimo_id = int(i)
            ultima_novidade = time.time()
        if ultima_novidade and time.time() - ultima_novidade > SILENCIO_FIM_RESPOSTA:
            break
        time.sleep(2)
    return respostas, ultimo_id


def prompt_lead(p):
    return f"""Você é um cliente REAL conversando pelo WhatsApp com uma distribuidora de bebidas. Interprete esta pessoa:
Nome: {p['nome']} — {p.get('cidade', '')}/{p.get('estado', '')}
Quem é e o que quer: {p['descricao']}
Como escreve: {p['estilo']}
Objetivo/fim: {p['objetivo_final']}

Regras:
- Escreva SÓ a próxima mensagem do cliente, curta, do jeito que essa pessoa digitaria no WhatsApp (gírias, abreviações, erros, sem formatação).
- Se quiser mandar mensagens picadas seguidas, separe com " || " (máximo 3).
- Reaja de verdade ao que o atendente disse: se algo soar robótico, repetido, confuso ou suspeito, demonstre isso como a pessoa faria.
- Se mandaria um áudio, escreva a transcrição do áudio entre colchetes, assim: [áudio] texto falado.
- Nas mensagens do atendente, [IMAGEM: ...] e [VÍDEO: ...] são uma imagem e um vídeo de verdade que ele te mandou (você pode assistir, ou dizer que não abriu, conforme a sua história). Se for mandar um print, descreva assim: [print] o que aparece na tela.
- Gente real não insiste para sempre: se você já pediu a mesma coisa 3 vezes sem conseguir, ou a conversa está andando em círculos, tome uma decisão (desistir, aceitar o que foi oferecido ou esperar a equipe) e encerre.
- Quando a conversa terminar para você (baixou o app, desistiu, foi atendido, vai esperar a equipe ou cansou), responda apenas: FIM: motivo em poucas palavras."""


def conversar(p, chave, modelo, saida):
    telefone = "5599" + str(int(hashlib.md5(p["id"].encode()).hexdigest(), 16) % 10**9).zfill(9)
    k = chave_conversa(telefone)
    sql(f"DELETE FROM cliente WHERE telefone = '{k}'; DELETE FROM n8n_chat_memoria WHERE session_id = '{k}'; "
        f"DELETE FROM bot_pausa WHERE telefone = '{k}'; DELETE FROM fila_mensagens WHERE telefone = '{k}'; "
        f"DELETE FROM bloqueados WHERE telefone_hash = md5('{telefone}');")
    ultimo = int((sql("SELECT coalesce(max(id), 0) FROM bot_log") or [["0"]])[0][0])
    historico = [{"role": "system", "content": prompt_lead(p)}]
    linhas = [f"# {p['nome']} — {p.get('cidade', '')}/{p.get('estado', '')} ({p.get('perfil', '')})", "", f"_{p['descricao']}_", ""]
    fala = p["primeira_mensagem"]
    fim = "limite de turnos"
    for turno in range(MAX_TURNOS):
        partes = [x.strip() for x in fala.split("||") if x.strip()]
        for parte in partes:
            texto = parte.replace("[áudio]", "").strip() if parte.startswith("[áudio]") else parte
            enviar_ao_bot(telefone, p["nome"], texto)
            linhas.append(f"**👤 {p['nome']}:** {parte}")
            time.sleep(0.4)
        respostas, ultimo = esperar_respostas(telefone, ultimo)
        if not respostas:
            linhas.append("**🤖 Henrique:** _(sem resposta)_")
        for r in respostas:
            linhas.append("**🤖 Henrique:** " + r.replace("\n", "  \n> "))
        linhas.append("")
        # Na vida real o bot pausa e a equipe assume: a conversa simulada termina aqui
        chamou = next((r for r in respostas if r.startswith("[SISTEMA: equipe chamada")), None)
        if chamou:
            fim = "equipe chamada (" + chamou.split("—", 1)[-1].strip(" ]") + ")"
            break
        historico.append({"role": "assistant", "content": fala})
        historico.append({"role": "user", "content": "\n\n".join(respostas) or "(o atendente não respondeu)"})
        fala = openai(chave, modelo, historico)
        # O lead às vezes escreve a mensagem e o "FIM:" juntos: manda a mensagem e encerra
        if "FIM:" in fala.upper():
            i = fala.upper().index("FIM:")
            fim = fala[i + 4:].strip(" :") or "encerrou"
            fala = fala[:i].strip()
            if fala:
                for parte in [x.strip() for x in fala.split("||") if x.strip()]:
                    enviar_ao_bot(telefone, p["nome"], parte.replace("[áudio]", "").strip())
                    linhas.append(f"**👤 {p['nome']}:** {parte}")
                respostas, ultimo = esperar_respostas(telefone, ultimo)
                linhas += ["**🤖 Henrique:** " + r.replace("\n", "  \n> ") for r in respostas] or ["**🤖 Henrique:** _(sem resposta)_"]
            break
    linhas.append(f"**Fim da conversa:** {fim}")
    with open(os.path.join(saida, f"{p['id']}.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas) + "\n")
    return fim


def main():
    config = json.load(open(os.path.join(PROJETO, "catalogo", "config.json"), encoding="utf-8"))
    if not config.get("modo_teste"):
        sys.exit("❌ Ligue \"modo_teste\": true no catalogo/config.json antes de rodar o laboratório.")
    chave = os.environ.get("OPENAI_KEY") or getpass.getpass("Cole sua chave da OpenAI (não aparece na tela): ")
    modelo = os.environ.get("MODELO_LEAD", "gpt-6-luna")
    personas = []
    grupo = sys.argv[3].lower() if len(sys.argv) > 3 else ""
    for arq in sorted(glob.glob(os.path.join(PASTA, "personas", "*.json"))):
        for p in json.load(open(arq, encoding="utf-8")):
            if not grupo or grupo in os.path.basename(arq).lower() or grupo in p["id"].lower():
                personas.append(p)
    if not personas:
        sys.exit(f"❌ Nenhuma persona encontrada para o grupo '{grupo}'.")
    random.shuffle(personas)
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        personas = personas[: int(sys.argv[1])]
    saida = os.path.join(PASTA, "resultados", datetime.now().strftime("%Y-%m-%d_%H-%M"))
    os.makedirs(saida, exist_ok=True)
    # Por padrão, todas as conversas rodam ao mesmo tempo (máximo 10)
    paralelo = int(sys.argv[2]) if len(sys.argv) > 2 else min(10, len(personas))
    print(f"▶ {len(personas)} conversas, {paralelo} ao mesmo tempo. Resultados em: {saida}")

    def rodar(p):
        try:
            return conversar(p, chave, modelo, saida)
        except Exception as e:  # uma conversa com erro não para o laboratório
            return f"ERRO: {e}"

    resumo, feitas = [], 0
    with ThreadPoolExecutor(max_workers=paralelo) as pool:
        tarefas = {pool.submit(rodar, p): p for p in personas}
        for p in personas:
            print(f"  ▶ começou: {p['nome']} ({p.get('estado', '')})", flush=True)
        for tarefa in as_completed(tarefas):
            p, fim = tarefas[tarefa], tarefa.result()
            feitas += 1
            print(f"  ✔ [{feitas}/{len(personas)}] {p['nome']} ({p.get('estado', '')}) → {fim}", flush=True)
            resumo.append(f"- **{p['nome']}** ({p.get('estado', '')}, {p.get('perfil', '')}): {fim}")
    with open(os.path.join(saida, "00-resumo.md"), "w", encoding="utf-8") as f:
        f.write("# Resumo do laboratório\n\n" + "\n".join(resumo) + "\n")
    print("✅ Pronto! Agora é só me avisar que eu analiso as conversas.")


if __name__ == "__main__":
    main()
