import json, re

FIXES = [
    (r"\bGFR\b", "GRF"), (r"Campary", "Campari"), (r"Londo Dry", "London Dry"),
    (r"(\d+)l\b(?=$)", None),
    (r"Wit Blance", "Wit Blanche"), (r"Ballentines Finnest", "Ballantine's Finest"),
    (r"Licos Espanhol 43 tradicional", "Licor 43 Tradicional"), (r"Melância", "Melancia"),
    (r"Limão e maça", "Limão e Maçã"), (r"Dell Vale", "Del Valle"), (r"Rosê", "Rosé"),
    (r"Whisky Buchanan$", "Whisky Buchanan's"), (r"Jack Daniels", "Jack Daniel's"),
    (r"Tutifruit|TutiFruit", "Tutti Frutti"), (r"Becks", "Beck's"), (r"\bIpa\b", "IPA"),
    (r"Coca-Cola Pet 3300L", "Coca-Cola Pet 3.3l"), (r"2\.250ML", "2.25L"), (r"2\.250l", "2.25l"),
    (r"(\d+) ML\b", r"\1ml"), (r"(\d+)Ml\b", r"\1ml"), (r"(\d+)ML\b", r"\1ml"), (r"(\d)L\b", r"\1l"),
]
UNIT_FIX = [(r"(Tanqueray|Beefeater|Sevilla|Royale)(.*?)(\d+)l$", r"\1\2\3ml")]

EMOJI = {
    "REFRIGERANTES": "🥤", "ISOTÔNICOS": "💧", "ENERGÉTICOS": "⚡", "ÁGUA": "💦",
    "CERVEJA": "🍺", "CHOPP": "🍻", "DESTILADOS": "🥃",
}

def emoji(sec):
    for k, v in EMOJI.items():
        if sec.startswith(k): return v
    return "📦"

def fix_name(n, sec):
    for pat, rep in FIXES:
        if rep is not None: n = re.sub(pat, rep, n)
    n = re.sub(r"(Tanqueray.*?|Beefeater.*?)(\d+)l$", r"\1\2ml", n)
    if sec == "REFRIGERANTES ANTARCTICA":
        n = "Guaraná Antarctica " + n.title().replace("Guaraná ", "", 1).replace("Rv", "RV").replace("Pet", "Pet").replace("Ml", "ml").replace("L", "l").replace("lata", "Lata")
    return re.sub(r"\s+", " ", n).strip()

def key(n, pack):
    toks = sorted(re.sub(r"[^\w.]", " ", n.lower()).split())
    return (" ".join(toks), pack)

itens, vistos, removidos = [], set(), []
sec = None
for linha in open("lista-original.txt", encoding="utf-8"):
    linha = linha.strip()
    if not linha: continue
    if linha.startswith("## "):
        sec = linha[3:]; continue
    nome, pack, preco = [p.strip() for p in linha.split("|")]
    if "2º cadastro" in nome:
        removidos.append(nome); continue
    if nome == "Coca-Cola Pet 2l" and preco == "R$ 30,30":
        removidos.append(nome + " (R$ 30,30)"); continue
    if "Del" in nome or "Dell" in nome:
        if "Lata 290ml" in nome: preco = "R$ 47,76"
    if nome.startswith("Gatorade Uva"): pack = "Fardo (10 un)"
    nome = fix_name(nome, sec)
    k = key(nome, pack)
    if k in vistos:
        removidos.append(nome + " (repetido)"); continue
    vistos.add(k)
    valor = float(preco.replace("R$", "").replace(".", "").replace(",", ".").strip())
    itens.append({"categoria": sec, "nome": nome, "embalagem": pack, "preco": valor, "preco_txt": preco})

DESTAQUES = [
    "Cerveja Heineken Lata 350ml", "Cerveja Brahma Chopp GRF 600ml", "Cerveja Skol Pilsen Lata 350ml",
    "Coca-Cola Pet 2l", "Energético Red Bull 250ml Lata", "Johnnie Walker Red Label GRF 1l",
]
por_nome = {i["nome"]: i for i in itens}
for d in DESTAQUES: assert d in por_nome, d

SEP = "━━━━━━━━━━━━━━━━━━━━━━"
def linha_item(i):
    return f"▪️ {i['nome']}\n   {i['embalagem']} — *{i['preco_txt']}*"

def bloco(cats):
    out = []
    for c in cats:
        out.append(f"\n{emoji(c)} *{c}*\n")
        out += [linha_item(i) for i in itens if i["categoria"] == c]
    return "\n".join(out)

cats = list(dict.fromkeys(i["categoria"] for i in itens))
grupo_bebidas = [c for c in cats if not c.startswith(("CERVEJA", "CHOPP", "DESTILADOS"))]
grupo_cerveja = [c for c in cats if c.startswith(("CERVEJA", "CHOPP"))]
grupo_dest = [c for c in cats if c.startswith("DESTILADOS")]

msg1 = f"""📋 *CATÁLOGO DE OFERTAS ATUALIZADO*

Confira abaixo nossa seleção de cervejas, refrigerantes, energéticos, águas, sucos e destilados. 🍺🥤🥃

📦 Atacado e varejo | Qualidade | Preços competitivos

{SEP}

🔥 *DESTAQUES ATACADÃO DAS BEBIDAS*

""" + "\n".join(linha_item(por_nome[d]) for d in DESTAQUES)

msg2 = f"{SEP}\n🥤 *NÃO ALCOÓLICOS*\n{SEP}" + bloco(grupo_bebidas)
msg3 = f"{SEP}\n🍺 *CERVEJAS E CHOPP*\n{SEP}" + bloco(grupo_cerveja)
msg4 = f"{SEP}\n🥃 *DESTILADOS E DIVERSOS*\n{SEP}" + bloco(grupo_dest) + f"""

{SEP}

📌 *INFORMAÇÕES IMPORTANTES*

✅ Ofertas válidas enquanto durarem os estoques.

✅ Preços sujeitos a alteração sem aviso prévio.

🔞 Venda proibida para menores de 18 anos.

{SEP}

📲 *COMPRE PELO NOSSO APLICATIVO OFICIAL*

🎁 10% de desconto na primeira compra

🚚 Entrega totalmente grátis

💳 Pague na entrega (Pix, cartão ou dinheiro) ou por boleto à vista

🍻 *ATACADÃO DAS BEBIDAS*
Qualidade, variedade e preço para sua casa ou seu negócio! 🛒"""

# Mensagem única: o WhatsApp mostra "Ler mais" e o cliente expande conforme quiser
catalogo = "\n\n".join([msg1, msg2, msg3, msg4])
assert len(catalogo) < 60000, "catálogo passou do limite de uma mensagem do WhatsApp"
open("catalogo.txt", "w", encoding="utf-8").write(catalogo)
msgs = [catalogo]
json.dump({"destaques": DESTAQUES, "produtos": itens}, open("produtos.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

print("itens:", len(itens))
print("removidos:", *removidos, sep="\n  ")
print("tamanho msgs:", [len(m) for m in msgs])
