# Decisões do Chatbot — Distribuidora de Bebidas
_Atualizado em 02/11/2026. Não montar o fluxo antes do OK final._

## Infraestrutura (teste local no Mac)
- Evolution API + n8n + Postgres + Redis via Docker (Colima) — pasta ~/Minha/mo
- Sem Chatwoot por enquanto
- IA: OpenAI (GPT) — modelo menor/barato, a definir no fluxo
- Instância WhatsApp: "Sessão Principal" (número Mendres) — conectada
- Bot responde TODO MUNDO (número exclusivo do bot)

## Suporte humano
- Bot pausa a conversa e avisa no grupo de WhatsApp **"Bot Geral"**
- Atendente responde pelo próprio WhatsApp do número da loja
- Se o atendente responder por conta própria, o bot também pausa
- Bot volta com o comando `#bot` OU após **30 minutos** sem mensagens
- Gatilhos: cliente pede humano, reclamação, problema com pedido, IA não sabe responder

## Funil
1. **Boas-vindas + idade (logo no início)** — "Você tem 18 anos ou mais?"
   - Não → explica que não pode vender e encerra
   - Cliente recorrente não é perguntado de novo
2. **Perfil:** consumo próprio (varejo) ou negócio (atacado)
2.1 **Envio do catálogo** — abertura diferente por perfil (ideia 5): negócio = margem/revenda; consumo = festa/churrasco/fim de semana
    logo após o cliente informar o perfil
   - Formato (baseado no exemplo enviado em 02/11):
     - Cabeçalho "📋 CATÁLOGO DE OFERTAS ATUALIZADO" + resumo das categorias
     - 🔥 DESTAQUES (melhores ofertas)
     - Catálogo completo dividido por seções, com preços
     - 📌 Informações importantes (ofertas enquanto durar o estoque; preços sujeitos a alteração)
     - Rodapé chamando para o app (entrega grátis, pague no recebimento)
   - Separadores ━━━━━━━━━━━━━━━━━━━━━━ e emojis por seção
   - PRIMEIRO envia a imagem catalogo/catalogo-imagem.png (arte com 33 produtos, preços conferidos em 03/11)
   - DEPOIS envia o catálogo completo em texto em UMA ÚNICA mensagem (cliente usa "Ler mais" no WhatsApp) — arquivo catalogo/catalogo.txt
   - Atualizar preços: editar catalogo/lista-original.txt e rodar `python3 catalogo/gerar_catalogo.py`
2.2 **Texto de apresentação**: após o catálogo, a PRIMEIRA mensagem do cliente (qualquer que seja) recebe o texto institucional (catalogo/texto-apresentacao.txt), adaptado do modelo da Master Frios
   - Matriz em São Paulo, SP | sem atendimento presencial | termina com "solicite o link do app" (não manda o link aqui)
   - Depois disso a IA responde qualquer pergunta normalmente
3. **Dúvidas com IA** — o bot atende TANTO varejo QUANTO atacado
   - Atacado: cliente envia CNPJ → bot consulta e mostra os dados da empresa
4. **Humano** quando necessário (ver gatilhos acima)
4.1 **Montagem de pedido (ideia 1)** — NÃO é etapa fixa; entra quando:
   - o cliente pergunta preço de itens específicos ou lista o que quer
   - o cliente diz que o mínimo de R$ 700 é alto / não sabe o que pedir
   - Henrique soma os itens (produtos.json), mostra quanto falta para R$ 700 e sugere complementos
   - Com o pedido montado → envia o link: "é só repetir esses itens no app"
4.2 **Respostas prontas (ideia 2)**: catalogo/respostas-prontas.md
4.3 **Toda resposta termina com um próximo passo rumo ao app (ideia 3)**
5. **Envio do link do app** (catalogo/texto-link-app.txt): quando o cliente pedir OU quando a IA achar oportuno (ex.: cliente quer comprar/cadastrar)
   - Pergunta se deseja se cadastrar → envia link do app + vídeo
   - Reforça: CADASTRO E PEDIDOS SOMENTE PELO APP, não aceita pedido pelo WhatsApp; pedido vai para a filial mais próxima; paga na entrega
   - Links {{LINK_APP}} e {{LINK_VIDEO}} provisórios por enquanto
- **Horário:** loja 24h; equipe humana sob demanda — bot sempre avisa no grupo

## Técnicas de conversão aprovadas (03/11)
- [x] (1) Montar pedido junto com o cliente até R$ 700 — gatilhos: cliente cita produtos/quantidades, pergunta preço total, acha o mínimo alto, ou diz que quer comprar
- [x] (2) Respostas prontas para objeções (catalogo/respostas-prontas.md), CNPJ = {{CNPJ_LOJA}} (dono preenche)
- [x] (3) Toda resposta termina com um próximo passo/pergunta que leva ao app
- [ ] (4) Confirmação de instalação 15 min depois — NÃO por enquanto
- [x] (5) Abertura do catálogo diferente por perfil (negócio x consumo próprio)
- [x] (6) Juntar idade + perfil — NÃO (perguntas separadas)
- [ ] (7) Lembrete após 24h — não incluído por enquanto (risco de banimento)
- [x] (8) Desconto de 10% é aplicado AUTOMATICAMENTE no app

## Formatação das mensagens (WhatsApp)
- *negrito* para valores, prazos, condições e nomes de produtos
- _itálico_ para observações secundárias
- Emojis como marcadores visuais no início das linhas (não no meio do texto)
- Parágrafos curtos (1–3 linhas) com linha em branco entre blocos
- Preço sempre no formato *R$ 00,00*
- Nada de tabelas ou markdown de títulos (# não funciona no WhatsApp)

## Consulta de CNPJ
- Valida os dígitos do CNPJ antes de consultar (evita chamada à toa)
- APIs gratuitas em cascata (fallback):
  1. BrasilAPI
  2. CNPJ.ws (pública)
  3. ReceitaWS
  - Se todas falharem: bot segue o atendimento sem os dados e registra o CNPJ
- Exibe SÓ: nome fantasia (ou razão social se não houver fantasia)
- Situação cadastral é ignorada (não bloqueia o atendimento)

## Pendências
- [x] Incentivo/cupom: NÃO tem — bot só manda o link
- [x] Campos do CNPJ: definido
- [x] Nome da loja
- [x] Pedido mínimo vale para atacado e varejo
- [x] Equipe humana: sob demanda, sempre avisar no grupo
- [x] Perguntas frequentes (base inicial)
- [x] Persona: opção A
- [x] Pagamento: somente na entrega (PIX, cartão débito/crédito 3x, dinheiro)
- [x] Catálogo: mesmo preço para varejo e atacado
- [x] 10% de desconto na 1ª compra pelo app: VALE
- [x] Lista de produtos: 338 itens em catalogo/produtos.json (digitação corrigida, duplicados removidos)
  - Coca-Cola Pet 2L = R$ 23,04 | Sucos Del Valle lata 290ml = R$ 47,76 | Gatorade Uva = fardo 10 un | Sukita 2.5L ok
  - Antarctica Original 600ml e Lata 350ml: repetição removida, item mantido
- [x] Preços confirmados pelo dono (compra direta de fabricantes)
- [x] Nome "Atacadão das Bebidas" confirmado como registrado pela loja
- [x] Destaques (6): Heineken Lata 350ml, Brahma Chopp 600ml, Skol Lata 350ml, Coca-Cola 2L, Red Bull 250ml, Johnnie Walker Red Label 1L
- [ ] Revisão do catálogo (catalogo/catalogo.txt) pelo dono
- [x] Ideias de conversão: 1, 2, 3 e 5 aprovadas; 4 (confirmar instalação) fica para depois
- [ ] CNPJ 24.305.769/0001-86 consta em ITABORAÍ/RJ na Receita, mas o texto diz matriz em São Paulo/SP — corrigir
- [ ] App na Play Store? | Desconto 10%: cupom ou automático? | Chega gelada? | Política de recusa/troca
- [ ] Links definitivos do app e do vídeo (provisórios por enquanto)
- [x] OK final dado em 03/11 — fluxo do n8n em construção
- [ ] Dados da loja (lista abaixo)
- [ ] OK final para montar o fluxo

## Dados da loja
- Nome: Atacadão das Bebidas
- Persona: se apresenta como Henrique, do Atacadão das Bebidas; não menciona por conta própria que é automático
- Se o cliente perguntar se é robô: "Sou o assistente virtual do Atacadão das Bebidas. Se preferir, chamo um atendente da equipe agora." → chama humano se o cliente quiser
- Cobertura: todo o Brasil, mais de 30 filiais
- Funcionamento: 24 horas por dia
- Link do app e do vídeo: PROVISÓRIOS no início (trocar depois)
- Pedido mínimo: R$ 700 (atacado e varejo)
- Frete GRÁTIS para todo o Brasil a partir de R$ 700
- Prazo de entrega: 2 a 4 dias úteis para qualquer estado
- Pagamento SOMENTE NA ENTREGA, cliente escolhe: PIX | Cartão (débito ou crédito em até 3x) | Dinheiro
- PAGAMENTO SOMENTE NA ENTREGA: cliente recebe, confere produtos, validade e nota fiscal, depois paga
- Tom da conversa: FORMAL
- Perguntas frequentes: base = texto de condições enviado em 02/11 (entrega, frete, mínimo, pagamento na entrega)

## Respostas definidas em 03/11
- Entrega: cliente pode escolher dia e horário
- Bebidas chegam geladas, na temperatura das normas
- Revenda/volume: tem condições especiais → chama humano para negociar
- Entregador leva troco
- App SOMENTE na Play Store (Android) → cliente de iPhone: informar e chamar humano
- Devolução totalmente gratuita → chama humano para conduzir

## Ajustes após o laboratório (03/11)
- Perfil: com a IA classificadora ativa, ela decide se é consumo ou negócio ("esse negócio de pagar", "trem pra vender, não" não viram lojista). Na etapa do CNPJ, quem diz que é pra casa vira consumo.
- Avisos à equipe: a mesma dúvida não vai de novo para o grupo em até 12h (nenhum aviso repetido em menos de 15 min). O Henrique sabe que a equipe já foi avisada e para de repetir "vou confirmar".
- Link: não é reenviado nas 2 respostas seguintes, a não ser que o cliente peça. Antes do catálogo, o Henrique não oferece nem promete o link.
- Laboratório: leads simulados desistem ou decidem depois de pedir a mesma coisa 3 vezes (antes ficavam em círculo até o limite de turnos).
- Desconto por volume confirmado: a partir de R$ 20 mil em compras, +2%; a partir de R$ 100 mil, +3%. O Henrique pode citar. Dúvidas de detalhe (por pedido ou somando, se acumula com os 10%) vão para a equipe.
- Texto dos kits: "consignação" virou "comodato" e o título agora é "OPORTUNIDADE PARA O SEU NEGÓCIO" (sem "FECHAMENTO IMEDIATO").
- Laboratório 2 (03/11): idade decidida pela IA classificadora em mensagens longas ("não uso app android" não é "não tenho 18"); CNPJ da própria loja repetido pelo cliente não vira CNPJ dele; Henrique não diz que tem filial em estado específico; preço copiado exatamente da lista; não chama vinho 750ml de "garrafão"; não fica em silêncio quando o cliente pergunta ou diz que está esperando; iPhone recebe o link se pedir ou for usar o Android de outra pessoa; não reoferece o app para quem disse que não quer agora.
- Clientes só com iPhone (inclusive lojista/distribuidora): continua só pelo app Android de outra pessoa. O bot NÃO chama a equipe para fazer pedido manual.

## Novo jeito de conduzir (03/11) — a IA escreve todas as respostas
- Antes: o roteiro era montado com textos fixos + pedaços da IA, o que deixava respostas desencontradas (ex.: "Tenho sim, por quê?" ignorado).
- Agora: o código só decide O QUE precisa acontecer (regras) e a IA escreve COMO, numa resposta só, olhando a conversa inteira.
- Regras garantidas pelo código (a IA não consegue furar): idade 18+ confirmada antes de catálogo, preços ou link; menor de idade bloqueado com mensagem fixa; catálogo (imagem + lista + kits para bar) enviado pelo sistema no ponto marcado pela IA; link só depois do catálogo; CNPJ consultado antes da resposta para a IA citar o nome da empresa.
- Ordem continua: idade → consumo ou negócio → CNPJ (opcional, só negócio) → catálogo → app. Se o cliente já disse o perfil/CNPJ antes, não é perguntado de novo. Se não der para saber o perfil depois de 2 tentativas, o catálogo vai assim mesmo.
- Se a OpenAI falhar, o cliente recebe a mensagem fixa equivalente ao passo (ex.: pergunta da idade).
- Laboratório 3 (03/11, novo jeito de conduzir): conversas bem mais naturais. Ajustes: não cumprimenta de novo no meio da conversa (nem com período diferente do cliente); "chega até sábado?" nunca recebe "sim" (só o prazo + datas no app); não inventa soluções/garantias ("a gente dá um jeito", "sem multa", "chega gelada lá"); barco/balsa/flutuante sempre avisa a equipe para confirmar prazo; lojista sem CNPJ compra com CPF; quem se recusa a dizer a idade não passa; o link não é reenviado só porque o cliente citou o app, e a frase "quer que eu te mande o link?" sai quando o link vai junto; parágrafos longos viram balões.

## Troca de modelo (03/11)
- A OpenAI desliga o gpt-4.1 e o gpt-4.1-mini em 14/01/2027 e o gpt-4o-mini-transcribe em 26/02/2027. Novo padrão: gpt-6-luna (chat, classificação e leitura de imagem, com raciocínio "low") e gpt-transcribe (áudios).
- O instalador testa cada modelo na sua conta antes de usar; se o gpt-6-luna falhar, cai para o gpt-4.1-mini. Para forçar um modelo: MODELO=nome-do-modelo ./instalar-fluxo.command.
- As instruções do Henrique foram reorganizadas: a parte fixa (regras, respostas prontas, produtos) vem primeiro e a situação do cliente no final, para a OpenAI cobrar mais barato o texto repetido.
- Laboratório 4 (gpt-6-luna): respostas precisas (preços, prazos, sem prometer data, avisos à equipe no ponto certo). Ajustes: CNPJ de MEI não mostra o nome da pessoa (só nome fantasia ou razão social de empresa); despedida longa não recebe mais "Tô aqui, no que posso ajudar?"; se o cliente desconfiar do link, o Henrique explica que é a página oficial na Google Play em vez de mandar não usar.
- Vídeo de instalação (05/11): em vez do link do vídeo, o próprio vídeo (catalogo/video-instalacao.mp4, convertido para MP4/H.264 compatível com qualquer celular, 1,3 MB, sem áudio) vai junto com o PRIMEIRO link do app e é reenviado quando o cliente tem dificuldade para instalar ([[VIDEO]]). Lembretes do link não reenviam o vídeo. Antes do catálogo o vídeo não sai. Se o arquivo sumir da pasta, o bot manda o link_video do config no lugar.
- 05/11: o app oficial está na Google Play; o Henrique volta a dizer isso. O vídeo atual é provisório (mostra instalação por .apk) e será trocado pelo oficial antes de ir ao ar.
- 05/11: o Henrique ganhou um roteiro para quem não consegue instalar o app (resolve sozinho só os casos simples: vídeo sem som, vídeo que não abre (explica em texto), onde fica a Play Store, iPhone; qualquer erro na tela, no cadastro ou cliente irritado → pede o print e chama a equipe). Laboratório ganhou 8 personas de dificuldade de instalação e filtro por grupo: ./laboratorio.command todas 8 instalacao
- 05/11 (lab 5): idoso/baixa visão → o Henrique explica em frases curtas antes de chamar a equipe; no meio de um problema de instalação ele não puxa outro assunto (CNPJ, perfil, oferta).
- 05/11 (decisões após lab 5): (1) cliente que já está tentando instalar o app vai direto para a ajuda + link/vídeo, sem pergunta de perfil/CNPJ e sem catálogo (o catálogo vai se ele pedir); (2) catálogo continua completo; (3) Henrique tenta UMA dica antes de chamar a equipe para erro de instalação, negociação/lead grande vira aviso "quando der" sem pausar o bot, e o grupo separa 🔴 URGENTE (bot pausado, cliente esperando) de 🟡 QUANDO DER (bot continua).
- 05/11: o Henrique nunca manda o cliente procurar o app na Play Store; se o link não abrir a loja (ou a dica não resolver), diz que a equipe técnica vai chamar em uns 10 minutinhos e chama a equipe (🔴 urgente).

## Vários números (05/11)
- 5 a 6 números, cada um com nome de atendente, link do app (link curto próprio, para saber de qual número veio o cliente) e grupo da equipe próprios, em catalogo/numeros.json. O que não estiver lá usa o config.json.
- Cada número tem conversas separadas (memória, pausa e #bot por número). Menor de idade bloqueado em um número fica bloqueado em todos.
- Cada número avisa no seu próprio grupo "Bot Geral" (o número precisa estar no grupo). O aviso mostra por qual número/atendente o cliente chegou.
- Sem relatório diário.
- Número novo: conectar no Evolution → adicionar o bloco em catalogo/numeros.json → ./ligar-numeros.command.
