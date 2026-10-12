Status: Rascunho

# Roteiro: cutscene, tutorial, ligações do chefe, queda e noite perdida

Autor: narrative-writer, 2026-10-08. Nada aqui é decisão.
Base: DEC-008, DEC-019, DEC-021 a DEC-025, DEC-028, DEC-036, DEC-037, DEC-047, DEC-048, DEC-050, DEC-051, DEC-053, DEC-060, DEC-065; rodadas 7–11: DEC-073 a DEC-078, DEC-081, DEC-084, DEC-086 a DEC-088, DEC-091 a DEC-095, DEC-097, DEC-098, DEC-100 a DEC-104; rodadas 12–15: DEC-106, DEC-110 a DEC-116, DEC-122 a DEC-124, DEC-129; rodadas 16–17: DEC-130 (sem semáforo; plano 4 e tutorial reescritos), rota trailer ↔ Mart cruza a Juniper Sul (resposta a `Q-128`, DEC a registrar); GDD V1 §8, §9.
**Decisões do dono de 2026-10-12 (secretário; Provisório nos detalhes; revisão do texto pelo narrative-writer pendente):**
- **DEC-224:** o **trailer é o veículo único desde o Day 1**; o carrinho saiu. Onde este roteiro diz "cart"/"carrinho", leia **trailer**. **Saem** a compra do trailer (§4.1b `call_trailer_offer` e `call_trailer_bought`, §4.2) e a cena "compra do trailer" (placa FOR SALE, repasse do Walt, foco da câmera). O dia 4 volta a ser um dia comum (`call_day_after_2` sem a oferta). **A explicação das regras do Walt passa para a primeira chamada de noite** (§5, Noite 1: já é onde as regras abrem; nenhuma regra é explicada em outro lugar).
- **DEC-225:** a **abertura é curta** e começa na **calçada em frente ao Pad** (§1 reescrito abaixo; o roteiro antigo fica como histórico).
- **DEC-223:** o preparo vira o **modo focado** (V1): o tutorial do Day 1 (§3) ensina por estações (Order, Grill, Build, Serve) em vez de prompts no mundo; as falas dos passos "perto do pão", "pão cortado", "montando" e "hot dog pronto" precisam de reescrita.
Conciliado com `consistency-report.md` (2026-10-08, NW-4 a NW-13, NW-16, NW-20).
Falas em inglês (texto de jogo). Personagens em `characters.md`; regras das anomalias em `anomalies.md` (Aprovado); final em `ending.md` (Aprovado).

Formato das ligações (alinhado a FEAT-018, `design/features.md`):
- O **telefone fixo do veículo** (AST-042, mesma peça no carrinho e no trailer) toca **[DEC-124]**; `world.md` §4.1. Prompt **"Answer"**; qualquer jogador atende; atende sozinho depois de ~15 s.
- Viva-voz: a ligação toca para **todos** da party ao mesmo tempo (o chefe fala "you", serve para 1–4).
- Legenda na parte de baixo, **uma linha por vez**, avança **sozinha** (~2,5 s por linha, ritmo do servidor). **Sem avanço por toque, sem "Skip", sem replay, sem histórico** (DEC-077). Nome do falante: **"Walt"**.
- Áudio: murmúrio de voz de telefone (sem dublagem) + "heh" do chefe. Dublagem real fica para o áudio decidir.
- A última linha de cada ligação noturna é a **forma curta da regra** (`anomalies.md`): é o que o jogador deve guardar.

---

## 1. Cutscene de abertura (DEC-021, DEC-088, **DEC-225**) — party de 1–4

### 1.0 Abertura curta (DEC-225, 2026-10-12; revisão D3 rev. 2 do dono, 2026-10-12, Provisório; VALE no lugar da tabela de 10 planos abaixo)

Duração: **35 s** (teto 38 s). Sem carros, sem figurantes, trânsito parado durante a cena. POV 1ª pessoa compartilhado segue (dúvida em `Q-226`).
Falas curtas: **≤ 6 palavras**; Walt ao telefone: **3 falas**. O número do telefone aparece só no prompt e no panfleto (ninguém fala dígitos).

| Tempo | Plano | O que acontece | Texto |
|---|---|---|---|
| 0–3,8 s | céu / estabelecimento | Fade in; câmera solta alta atrás do avatar, descendo; título "Sell Hotdogs!" | título |
| 3,8–14 s | calçada norte → faixa **CW-4** → poste `P-01` | Parte da calçada norte da Ninth, **em frente ao trailer**; anda até a faixa de pedestres mais próxima do cartaz, **atravessa pela faixa** (rua vazia, sem carros) e chega ao poste do cartaz HELP WANTED, do lado do trailer; colegas lado a lado | "I really need a job." |
| 12–17 s | `P-01` (CS-P1..P4) | O olhar vai ao panfleto, close (FOV fecha), leitura | "Help wanted?" · "I'll call them." / "Let's call them." |
| 17–31,4 s | `P-01` | Prompt "Call"; flip aberto; Walt em viva-voz (3 falas abaixo); o flip some no clique | prompt "Call 555-0179" |
| 31,8–35 s | `P-01` → trailer | Todos viram a cabeça para o **trailer** no Pad, sob o sol; fade out; controle liberado, 7:00 AM ("Day 1") | — |

Ligação (voz de telefone, Walt): 1. "Bramble's Corner Dogs. Walt here." 2. "You noticed the flyer. Good." 3. "Start today. Keys under the mustard."

Cortados em relação ao roteiro antigo: ônibus, pombos, mariposa, vitrines "NO HELP WANTED", carro de brinquedo, **"Empty. Again."** (o dono não entendia por que ele falava isso), "I really need a job right now... but nobody's hiring.", o número falado e as variantes longas do Walt. O "olhe antes" fica só no tutorial (§3: "Look both ways.").

Panfleto (texto de jogo, Provisório, narrative-writer confirma): "HELP WANTED! Run a hot dog **trailer**. No experience needed. Must notice things. Call Bramble's Corner Dogs — 555-0179".

### 1.1 Roteiro antigo (HISTÓRICO, superado por DEC-225 onde conflita)

Duração alvo: 35–45 s. **1ª pessoa** (POV de cada jogador), cena **compartilhada**: cada jogador vê os avatares dos colegas, não o próprio (DEC-088). Pontos de câmera e posições em `levels/MAP-01.md` §11.1 (CS-1 a CS-7).
**Sem braços** (DEC-097). Regras de câmera e de gesto desta cena:
- A câmera **é sempre a cabeça** do avatar: anda com ele, olha para cima ou para baixo, vira a cabeça para um alvo. Nada de plano aéreo, grua ou câmera solta.
- **Nenhum gesto de mão.** Nada "abre na mão", nada "é tirado do bolso". Objetos **aparecem sozinhos** (Tool que surge pronta na mão, coisa que voa para a tela) ou ficam **no mundo**.
- Ações do roteiro são mostradas como **prompt de mundo que se completa sozinho** (input travado; o jogador só vê). Isso já ensina o visual dos prompts do jogo. O botão de interagir continua sendo só o voto de pular.
Pulável: segurar o botão de interagir = voto "Skip"; em party, pula com 50% dos votos (DEC-078; texto em `ui-text.md` §7).
Tom inocente, sem nenhuma pista de horror (DEC-008).

**Quem liga?** Proposta para `Q-106` (c), alinhada a `design/features.md` ("Party na intro") e AST-038: **liga só o avatar do trilho 1** (só visual; não há líder na run, DEC-067). Os outros ficam em volta do poste. Viva-voz no flip: todos ouvem Walt. Solo: o jogador é o trilho 1.
**Alternativa recomendada para o usuário escolher em `Q-106` (c): todos ligam ao mesmo tempo.** Cada avatar ganha o próprio flip no plano 7; cada jogador vê o seu na tela e os colegas com o deles. Reforça "não há líder" (DEC-067) e rende piada leve na variante party (Walt: "All of you? Huh."). Custo: até 4 Tools AST-038 na cena em vez de 1. Mantida acima a proposta do trilho 1 até a decisão.

| # | Ponto (MAP-01) | POV (cada jogador) | Colegas (o que cada um vê dos outros) | Texto na tela |
|---|---|---|---|---|
| 1 | CS-1 | Fade in **na calçada** da Ninth Ave, olhar levantado para os telhados de Bellmoor; pombos levantam voo. O olhar baixa para a rua: ônibus amarelo passa. | Colegas em formação 2 × 2, também olhando para cima. | **Bellmoor** (título curto) |
| 2 | CS-1 → CS-2 | Anda pela calçada (input travado). Uma **mariposa** sobe voando da parte de baixo da tela, passa na frente dos olhos e vai embora. | Colegas andam lado a lado (fila de até 4); uma mariposa sai voando de cada um. | legenda própria: "Empty. Again." · balão sobre cada colega: "Empty. Again." |
| 3 | CS-2 | Passa por três vitrines com placas "NO HELP WANTED". Som de suspiro. | Colegas olham as vitrines também. | — |
| 4 | CS-4 → CS-5 | Para na beira da calçada da Ninth (sem semáforo, DEC-130). Um carro de brinquedo **passa rente sem parar**, buzina cômica "honk-honk!". O olhar vira para um lado, depois para o outro (rua livre) e só então a party atravessa. Ninguém encosta em ninguém. | Colegas param junto na calçada, dão um pulinho de susto com a buzina e atravessam juntos. | balão sobre cada colega: "Whoa!" |
| 5 | CS-5 | Esquina Ninth & Juniper. Vento. Um panfleto velho bate no poste; o olhar vai até ele. | Colegas param em meia-lua em volta do poste. | — |
| 6 | CS-6 | Close no panfleto (texto abaixo; o campo de visão fecha). Sobre o número, um prompt **"Call"** aparece e se completa sozinho. | — | prompt "Call" |
| 7 | CS-6 | Trilho 1: o **celular flip surge já aberto** na parte de baixo da tela (Tool, sem mão), tela acesa, bipes de discagem. Demais: nada na mão. | Todos veem o avatar do trilho 1 com o flip aberto na mão. | — |
| 8 | CS-6 | Ligação com Walt em viva-voz (legenda; variante solo ou party). | Colegas acenam com a cabeça nas falas dele. | legenda |
| 9 | CS-7 | O flip some. Todos viram a cabeça para o sudeste: o **carrinho** no Pad, sob o sol. Um carro de brinquedo passa entre a party e o carrinho e buzina, cômico ("beep-beep!"). | Colegas viram junto. | — |
| 10 | FIM | Fade → controle liberado: 1ª pessoa, 7:00 AM. O telefone fixo do carrinho (AST-042) começa a tocar (leva ao §3). | — | "Day 1" |

O plano 4 ensina, sem texto, "**olhe antes**": carro comum não para por você em Bellmoor (DEC-130, DEC-133). Versão alinhada ao MAP-01 rev.3 (CS-4/CS-5). Nenhum carro comum freia em nenhum momento do jogo, nem em cutscene, o que preserva o padrão que a N8 quebra (`world.md` §3.2). O plano 9 reforça o trânsito (DEC-087) e o tom pastelão antes do primeiro atropelamento. Nenhum dos dois mostra impacto (cutscene sem ninguém se machucar).
> Descartada (rodada 18): versão em que o carro **freia em cima** da party no meio da rua ("SCREEECH!"). Motivo: seria um carro comum parando por causa do jogador, contradiz DEC-133 e enfraquece a N8.
Para o art-director (AST-075, AST-038): a carteira que abre sai da cena; fica só a mariposa (sobe da borda da tela). O flip entra direto no estado `Open`, sem animação de abrir.

Panfleto (asset — texto em inglês, art-director):

> **HELP WANTED!**
> Run a hot dog cart.
> No experience needed. Must notice things.
> Call **Bramble's Corner Dogs** — 555-0179

Ligação da cutscene (solo):

1. Walt: "Bramble's Corner Dogs! Walt speaking."
2. Walt: "The flyer? Huh. Nobody's called about that one in years."
3. Walt: "But you noticed it. That counts for a lot."
4. Walt: "Can you start today? Great. Wonderful."
5. Walt: "The cart's right on the corner. Ninth and Juniper."
6. Walt: "Keys are under the mustard. See you around, Rookie."

Variante party (troca só as linhas 2 e 3):

2. Walt: "The flyer? All of you? Huh. Nobody's called in years."
3. Walt: "You all noticed it. That counts for a lot. Heh."

Membro atrasado (DEC-098): sugestão para `Q-112` (c) — não vê a cutscene; aparece na esquina e segue o turno. Recebe só as dicas do tutorial que ainda não tocaram.

## 2. Arco do chefe por turno (GDD §9)

**Cronologia (pedido do dono 2026-10-12, Provisório, Q-207; DEC-224: sem carrinho e sem oferta do trailer):** Day 1 (tutorial) → Day 2 → **Night 1 (no trailer)** → Day 3 → Night 2 → Day 4
(~~**oferta do trailer** de manhã; compra opcional~~: **saiu**, DEC-224) → Night 3 → … → Day 11 → Night 10 → Final. A noite *k* é jogada no fim do dia *k + 1*; a ligação
da manhã seguinte é `call_day_after_<k>` (dia *k + 2*). Antes: dias 1–5 → compra do trailer → noite 1 → dia 6 → … (SUPERADO).

| Estágio | Frase-guia | Turnos |
|---|---|---|
| 1 | "Good job today!" | dias 1–2 |
| 2 | "You're doing great." | dias 3–4, noites 1–2 (carrinho) |
| 3 | "Can you cover the night shift?" | noites 1–3 (a pergunta formal já não existe: Walt avisa no Day 2 e a ligação da noite 1 abre as regras), oferta do trailer no Day 4 |
| 4 | "There's something you should know..." | noites 4–6, dias 5–8 |
| 5 | "Whatever you do, never..." | noites 7–10, dias 9–11 |

## 3. Tutorial do dia 1 (Walt na linha)

Provisório (Q-193, 2026-10-11): o tutorial roda **sempre no dia 1 de toda run**, para todos, e **não é salvo** como concluído nem obrigatório (Skip vale só para a run). Passou do dia 1, não volta na mesma run.

O dia 1 começa com o telefone do carrinho tocando (plano 10 do §1). Isso ensina o prompt **"Answer"** logo de cara.
Walt atende e **fica na linha em viva-voz** durante o dia 1: cada dica sai pelo alto-falante do telefone, uma vez, quando a party chega àquele passo pela primeira vez. Sem painel, sem botão: a ação é sempre o prompt no mundo (DEC-015, DEC-066).

Revisão D3 rev. 2 (2026-10-12, Provisório): **≤ 6 palavras por fala, ≤ 3 falas por passo.** Texto de jogo em `src/Tutorial/client/TutorialController/Steps.luau` (a lista é a fonte; abaixo, o resumo).

| Passo | Fala (Say) · elogio (Done) · lembrete (Remind) |
|---|---|
| saudação (ao atender) | "Morning, Rookie. Walt here." · "I'll walk you through it." |
| primeiro cliente | "Your first customer's coming." |
| pedido | "Take their order." · "A ketchup dog. Easy." · "Take the order, Rookie." |
| abrir a loja | "Flip the sign to open." · "We're open." · "Flip the sign. Open up." |
| grelha | "Frank from the cooler." "Onto the grill." · "Nice." · "Frank on the grill." |
| pão | "Slice a bun while it cooks." · "Good." · "Hold to slice the bun." |
| esperar a salsicha | "Wait for the bar." |
| coletar | "Ready. Grab it." · "Got it." · "Grab it off the grill." |
| montar | "Frank in the bun." · "Beautiful." · "Put it in the bun." |
| toppings | "They want ketchup." "Nothing extra." (DEC-072) · "Perfect." · "Ketchup. Hold to add." |
| descartar | "Not what they asked. Toss it." · "Toss it in the bin." |
| servir | "Now serve it." · "Hand it over." |
| primeira venda | "Ka-ching! First sale." "Cash goes in the drawer." |
| ir ao Mart | "That was your last bun." "Mart's across the street." "Look both ways." · "That's the place." · "Follow the arrow to the Mart." |
| comprar | "Grab buns at the bakery." · "Eight buns. That'll do." · "Bakery shelf. Hold Buy Buns." |
| voltar | "Bring them to the trailer." · "Back to the trailer." |
| reabastecer | "Hold Restock on the bun crate." · "Stocked up!" · "Hold Restock at the bun crate." |
| despedida | "That's the job. You got this." "Call me if..." · pulou: "Alright. You know the drill." "Call me if you need me." |

Dicas depois da ação (`hint_*`, uma vez): "Bar full? Grab it." · "Now slice a bun." · "Pop a frank in the bun." · "Hot dog's ready. Wait for orders." · "We're open! Folks are lining up." · "See the bubble? That's the order." + "Nothing extra." · "Nice! Cash goes in the drawer." + "Low on stock? Try the Mart." + "Look both ways." · "Careful crossing. Get hit, drop it." (DEC-103) + "Gear's on the back wall." + "Sometimes there's something special." (DEC-106) · "That's how you restock. Easy." · "Messed up? Toss it. No harm." · "New gear's on the trailer. Heh."

Não existem mais (cortadas em 2026-10-12): "Don't leave the cart alone too long.", "Ooh. You okay? Dust off. Grab your stuff.", "Flip the sign to CLOSED. Finish the line." e "Good job today! See you at seven." como falas de tutorial (ficam como texto de UI do resumo, §4.5/`ui-text.md`).

## 4. Ligações de dia (7:00 AM)

### 4.1 Dias 1–5 (novo fluxo 2026-10-12: só os dias 1 e 2 têm ligação própria; os dias 3 e 4 viraram `call_day_after_1` e `call_day_after_2`, abaixo e em §4.4)

| Dia | Abertura | Fim do turno (resumo) |
|---|---|---|
| 1 | tutorial (§3) | "Good job today! See you at seven." |
| 2 | "Cheese is in. Folks love cheese." / "Watch your drawer. Quick hands." / "You work late tonight. I'll ring." | "Good job today! Two for two." (segue direto para a noite 1) |
| 3 | (SUPERADO: o dia 3 vem depois da noite 1; "Bacon's in today. Smell that?" entrou em `call_day_after_1`) | — |
| 4 | (SUPERADO: o dia 4 vem depois da noite 2; "potato sticks / bigger grill" entrou em `call_day_after_2`, seguida da oferta do trailer) | — |
| 5 | (SUPERADO por 4.1b: o trailer não é mais comprado no dia 5) | — |

Pista leve, a partir do dia 3, só se o ladrão foi pego no dia anterior (substitui a 2ª linha): "You caught Quentin. Nice work." (Walt não estava lá.)

### 4.1b Oferta do trailer — **OBSOLETA (DEC-224, 2026-10-12): o trailer é o veículo único desde o Day 1; não há oferta, repasse, placa nem `call_trailer_bought`.** Histórico:
Manhã depois da noite `Content.Trailer.OfferAfterNight` (= 2) — Provisório (pedido do dono, 2026-10-12)

Substitui "dia 5 — compra do trailer". A noite 1 já acontece no carrinho (Walt explica a noite na própria noite 1); o trailer é oferecido depois porque **ajuda contra as anomalias**. Na manhã seguinte à noite 2 (Prep, depois da fala normal do dia, `call_day_after_2`) o Walt liga (`call_trailer_offer`, 8 linhas, 20 s). A linha 2 vira a câmera da party para a placa FOR SALE (~3 s, o corpo fica parado 3,6 s); a linha 3 faz o **repasse**: o caixa do Walt completa o dinheiro da party até o preço do trailer ($300 × fator da party; só a diferença, uma vez por run; toast "Walt's till: +$N for the trailer!" + som `coin`). A seta/Highlight (ObjectiveController) fica na placa até a compra, e o prompt de compra mora na placa.

1. "One more thing, Rookie. The old trailer."
2. "See that sign? FOR SALE. Go take a look." (foco da câmera)
3. "Here. The money's from Walt's own till." (repasse)
4. "She's got a service window. It shuts tight."
5. "Her lights reach far. Folks respect a light."
6. "And the Mart's sign never goes out. Remember that."
7. "You'll be safer in there... mostly."
8. "Walk up to the sign. Buy her."

Depois da compra (`call_trailer_bought`, toca na hora no telefone do carrinho; a troca de veículo continua na virada de turno). Sem explicar a noite de novo:

1. "You bought the old girl! Heh."
2. "The cart gets a rest. She takes the corner."
3. "Close her window when things get strange."
4. "Keep her light on. That's half the job."
5. "Welcome to the real shop, Rookie."

A dica "See that old trailer in the lot? Not yet. Heh." saiu da fala do dia 4. Voz: todas as chamadas do Walt agora têm TTS (BossController, Speech compartilhado); linhas sem "sausage" e sem números.

### 4.2 Trailer (antigo: fim do dia 5 — SUPERADO por 4.1b e, depois, **OBSOLETO por DEC-224**: sem compra do trailer; as falas deste bloco ("I need someone on nights", "a few house rules") **não existem mais**: a explicação das regras passa para a ligação da Noite 1, §5, e o narrative-writer pode trazer uma linha de "house rules" para lá)

Comprou (fade + ligação no telefone do carrinho, a última dele; próximo turno = noite 1, trailer já na esquina):

1. Walt: "You bought the old girl! She looks good on you."
2. Walt: "She'll be on the corner tonight. Cart gets a rest."
3. Walt: "Listen... I need someone on nights."
4. Walt: "Can you cover the night shift? Starts at eight."
5. Walt: "There are a few... house rules. Nothing big."
6. Walt: "I'll call the trailer at eight. Get some rest."

Não comprou (DEC-028 — notificação, não tutorial; texto em `ui-text.md`). Fala do resumo: "No trailer yet? That's okay. She'll wait."

### 4.3 Modo dia infinito (DEC-028, DEC-058) — REMOVIDO em 2026-10-12 (as noites não dependem mais do trailer; sem dia infinito, sem estas falas)

Uma fala sorteada por manhã, sem repetir duas seguidas:
"Another day, another dog." · "Proud of you, Rookie. Really." · "Grill's hot. Let's go." · "The trailer's still there. Just saying." · "Nice and normal. Just how I like it." · "Peek at the Mart's glass case. Sometimes there's a surprise."

"Day 100" (DEC-084) soma dias de modo infinito **por jogador, entre sessões**: cada jogador da party pode chegar ao 100 num dia diferente. Por isso **não tem ligação do Walt**; é só notificação pessoal + badge (`ui-text.md` §6, §9).

### 4.4 Dias 3–11 (entre as noites; antes "dias 6–14")

Uma linha de trabalho + uma linha de pista. As pistas criam perguntas, não respondem (DEC-008). Telefone de parede do trailer (do carrinho, até a compra).
A numeração abaixo é a **antiga** (dia 6 = depois da noite 1); no novo fluxo o dia depois da noite *k* é o **dia *k* + 2** (3 a 11). Quentin (ladrão pego no dia anterior)
tem variante nas ligações dos dias 3 e 4 (`call_day_after_1_quentin`, `call_day_after_2_quentin`: a fala do Quentin é a 2ª linha).

| Dia (antigo) | Depois da | Abertura |
|---|---|---|
| 6 | noite 1 | "Morning! Told you nights were quiet." / "Bacon's in. Smell that?" / "Grill's hot. Sell some dogs." |
| 7 | noite 2 | "Morning, Rookie. Sleep okay?" / "Good. Don't think about it." / "Potato sticks today. Bigger grill, too." |
| 8 | noite 3 | "Bank clock's ticking fine. See?" / "Nice and normal. Sell some dogs." |
| 9 | noite 4 | "One Mr. Pickett today, I hope." / "...That was a joke. Mostly." |
| 10 | noite 5 | "She liked you. The lady." / "Forget I said that." |
| 11 | noite 6 | "Ever notice nobody lives upstairs?" / "In the daytime, I mean." / "Huh. Next question." |
| 12 | noite 7 | "You kept your eyes down. Good." / "I counted the lamps. It helps." |
| 13 | noite 8 | "Long night, huh? Coffee's on me." / "Tell Opal it's for Walt." |
| 14 | noite 9 | "Rookie. About the knocking." / "That wasn't me. Believe that." / "Tonight's the last. I promise." |

Variante Quentin (dias 3 e 4): "Morning! You made it." / "You caught Quentin. Nice work." / "Bacon's in. Go sell some dogs." e "Morning, Rookie. Sleep okay?" / "You caught Quentin. Nice work." / "Potato sticks and a bigger grill."

Variante (qualquer dia 6–14), se alguém da party está em spectate (DEC-093; só volta se a party perder uma noite e ela for repetida, DEC-111, DEC-113), substitui a 1ª linha: "Short a hand today? Your friend's resting. You'll manage."

### 4.5 Nota do turno (DEC-051), na tela de resumo

| Nota | Fala |
|---|---|
| A | "Perfect shift! Bonus is yours." |
| B | "Solid work. Here's a little bonus." |
| C | "Not bad. A little faster tomorrow." |
| D | "Rough one. Folks went home hungry." |

## 5. Ligações da noite (8:00 PM)

Cada noite: abertura → regra nova → (a partir da noite 7) lembrete da crítica → forma curta. Só a N7 (Walker) é crítica (DEC-074).
Na repetição de uma noite perdida (DEC-053), toca a **versão curta** (§5.11), não a ligação inteira. É ligação nova, disparada pelo sistema; não é replay (leitura de DEC-077, `Q-077` d).
Linhas marcadas com † são **novas** desta revisão e não mudam a regra aprovada em `anomalies.md`.

Revisão D3 rev. 2 (2026-10-12, Provisório): **≤ 4 falas por noite, ≤ 6 palavras cada**; a última é a **forma curta** da regra. A lore essencial fica (a regra e a pista); o resto (aberturas longas, explicações, "Tell your crew") saiu. Texto de jogo em `BossCalls.luau`.

### Noite 1 — ANM-001 The blank folks (estágio 3)

A noite 1 acontece no **trailer** (DEC-224); a ligação é **a primeira chamada de noite** e abre as regras (DEC-224). Depois dela toca `call_night_1_coffee` ("You sound tired, Rookie..." / "Have some coffee." / "It'll keep your head on straight.").

1. "Evening, Rookie. Some customers look off."
2. "No face at all? Just refuse."
3. "They'll wander off. Grill stays hot."
4. **"No face? Refuse them."**

### Noite 2 — ANM-002 The wrong food

1. "Night two. Check your food first."
2. "Gray frank, bitten bun? Trash it."
3. "Still refuse the faceless ones."
4. **"Wrong food? Throw it away."**

### Noite 3 — ANM-003 The stopped clock

1. "Evening. Watch the bank clock."
2. "If it stops, trailer lights off."
3. "Count to five. Then lights on."
4. **"Clock stops? Lights off, count five."**

(Fluxo atual: a anomalia exige o interruptor do trailer — `Trailer = "Needs"`.)

### Noite 4 — ANM-004 The copies (estágio 4)

1. "Sometimes a customer shows up twice."
2. "One's a copy. Everything's backwards."
3. "Look at shirts and watches."
4. **"Two? Refuse the backwards one."**

### Noite 5 — ANM-005 The Raincoat Lady

1. "A lady in a yellow raincoat."
2. "It won't rain. She'll drip anyway."
3. "Serve her, whatever she asks."
4. **"Yellow raincoat? Always serve her."**

### Noite 6 — ANM-006 The wavers

1. "Folks upstairs might wave tonight."
2. "Don't wave back. Eyes down."
3. "They just want to be noticed."
4. **"Someone waving upstairs? Don't look up."**

### Noite 7 — ANM-007 The Walker (estágio 5, regra crítica)

1. "Down Juniper, someone walks toward you."
2. "Each look brings them closer."
3. "Never let them reach your light."
4. **"Never watch the Walker."**

O sinal de início (DEC-123, §5.12) e o aviso "quando o poste distante zumbe, eles chegaram" saíram da fala; o sinal continua sendo som/figura no mundo.

### Noite 8 — ANM-008 The long car

1. "A long car may park across."
2. "Lights on you? Out of sight."
3. "Window shut. Or the Mart."
4. **"Long car? Window shut, or Mart."**

A janela do trailer (DEC-221) e o Mart (quem está sem trailer) seguem; "Regular cars never stop there" e "Don't come back till it drives away" saíram. Na repetição entra também "And never watch the Walker.".

### Noite 9 — ANM-009 The knock

1. "I never visit at night. Never."
2. "Knocking? It isn't me. I'm sorry."
3. "Window shut. Or the Mart."
4. **"Knocking? Not me. Window, or Mart."**

### Noite 10 — ANM-010 The Hush (final)

1. "Last night. The lamps may die."
2. "Go stand beneath the Mart's sign."
3. "It never goes out. I promise."
4. **"Lamps out? To the Mart sign."**

### 5.11 Versão curta (noite repetida)

1. "Same night, Rookie. Same rules."
2. (forma curta da regra nova da noite)
3. (noites 8–10) "And never watch the Walker."

### 5.12 Som de início do Walker (ANM-007) — **decidido, DEC-123**

Acréscimo ao sinal aprovado (figura sob o último poste + passo abafado), para quem está de costas para a Juniper (comum no celular). Anotado em `anomalies.md` N7.

| Campo | Conteúdo |
|---|---|
| Som **[DEC-123]** | o **último poste da Juniper zumbe** (zumbido elétrico grave que sobe por ~2 s e para seco), ouvido por todos da party |
| Diferença da alucinação **[DEC-123]** | a alucinação do poste (§8, sanidade < 40) **pisca sem zumbir**; o zumbido só existe no Walker real |
| Volume | médio, sem pico; não é susto (DEC-005) |
| Função | avisa "não olhe para a Juniper agora" **sem precisar olhar** |
| Visual junto (proposta, **fora** de DEC-123) | a luz daquele poste fica **mais fria** (amarelo → branco-azulado) enquanto o Walker está lá. Só entra com DEC própria. |

### 5.13 Quem vê o sinal (proposta para `Q-069`)

Todo sinal é visto/ouvido por todos da party; erro e penalidade seguem o escopo da ficha (party ou por jogador). Ver `world.md` §5.1.

## 6. Fim da noite (6:00 AM, vitória), na tela de resumo

| Noite | Fala |
|---|---|
| 1 | "Six o'clock. You made it! Easy, right?" |
| 2 | "Morning. Toss anything weird? Good." |
| 3 | "Sun's up. Clock's ticking. Go get some sleep." |
| 4 | "You did good. Better than me, my first time." |
| 5 | "She came by, didn't she? ...Get some sleep." |
| 6 | "Morning. Neck sore from not looking up? Heh." |
| 7 | "Eyes down the whole night. I'm proud of you." |
| 8 | "Sunrise. I always loved sunrise." |
| 9 | "It's over. You're okay. That's what matters." |
| 10 | final (`ending.md`) |

Variante, se alguém desmaiou na noite e não voltou (DEC-093, DEC-115), em vez da fala da noite: "You made it. Your friend's resting at Bellmoor Rescue. They're okay."

## 7. Noite perdida (DEC-053, DEC-094, DEC-102, DEC-110 a DEC-113, DEC-122)

**Uma chance do chefe por run inteira** (DEC-110, DEC-112). A 1ª noite perdida gasta essa chance e a noite se repete; a 2ª noite perdida da run é o **fim da run**. O texto nunca fala em "chances" no plural nem dá contagem: diz que **essa foi a única vez**.

Duas formas de perder a noite:

| Causa | Sequência (transição ≤ 6 s, sem "Skip") |
|---|---|
| **Todos caídos** e ninguém reviveu na janela de 10 s (DEC-094, DEC-102, DEC-118) | contador de 10 s na tela de todos (`ui-text.md` §7) → zera → luzes do trailer piscam e apagam → tela escurece → amanhecer (abaixo) → Walt liga |
| **Regra crítica** (Walker chega à luz, ANM-007) | sem janela: o poste da esquina e as luzes do trailer piscam e apagam na hora → tela escurece → amanhecer (abaixo) → Walt liga |

**Amanhecer — decidido, DEC-122**: **todos acordam em pé na calçada, ao lado do trailer, enquanto a ambulância da Bellmoor Rescue vai embora com a sirene desligada.** Sem banco. Mesma imagem do reviver (aparecer ao lado da ambulância).
**Quem acorda — DEC-111, DEC-113**: **todos** da party acordam juntos, **inclusive quem estava assistindo** (espectadores desta noite e de noites anteriores). Sem exceção de texto: ninguém segue em spectate depois dessa cena.
Se a noite perdida for o fim da run (chance já usada), a cena de amanhecer é a mesma e leva à tela "Shift's Over" (`ui-text.md` §7).

Ligações depois da noite perdida (telefone fixo do trailer, AST-042):

| Situação | Ligação |
|---|---|
| Noite perdida pela regra crítica (antes da linha abaixo) | "You watched it, didn't you? ...It's okay. Breathe." |
| Noite perdida, chance usada agora (a noite repete) | "Rough night. Let's try that again." (texto de DEC-053) / "Whole crew's back on. Even the sleepy ones." (só em party) / "But listen. This is the only time I can do this, Rookie." / "Be careful out there." |
| Noite perdida com a chance já usada (fim da run) | "That's two, Rookie. I can't put you on nights anymore." / "Go home. Rest. You did more than most." |

## 8. Sanidade baixa: alucinações (DEC-038)

Ideias de texto e situação para art/áudio. Sem gore, sem grito, sem jumpscare como base (DEC-005, DEC-023). Escalam conforme a sanidade cai. Só no client do jogador; sem prompt (FEAT-019).

| Faixa (sugestão) | Alucinação |
|---|---|
| < 60 | o telefone de parede do trailer toca; a legenda é "Walt: ..." e nada mais (sem "Answer") |
| < 60 | chiado de salsicha numa grelha vazia |
| < 40 | passos leves no teto do trailer |
| < 40 | um cliente na fila que não está lá quando você olha de novo |
| < 40 | um poste da Juniper pisca como se fosse o Walker, **sem zumbido** (alarme falso; ver §5.12) |
| < 20 | sussurro baixo: "Rookie..." |
| < 20 | o letreiro do Mart pisca uma vez (o lugar seguro, o que dá mais medo) |
| < 20 | sombra passando na janela dos fundos |

Alucinação nunca dispara erro de regra nem conta como anomalia vista.

## 9. Queda: desmaio, ambulância, reviver, spectate (DEC-091 a DEC-094, DEC-100, DEC-111, DEC-113 a DEC-116, DEC-129)

Substitui a antiga proposta "Had enough" → banco (Q-055, não escolhida). Decidido: sanidade 0 → desmaio, o avatar cai → os médicos descem e levam o avatar (DEC-114) → reviver por **Robux** (só para si, DEC-116) ou pelo **Rescue Whistle** do Mart, até **6:00 AM** da noite da queda (DEC-115), no máximo **2 revives por jogador por noite** (DEC-129) → senão **spectate**, até o fim da run **ou** até a party perder uma noite e ela ser repetida (DEC-111, DEC-113). Tempos de tela são sugestões; textos de tela em `ui-text.md` §7.
Tom: **cuidado e resgate**. Nada de "died", "body", grito ou câmera tremendo.

### 9.1 Jogador cai (ainda há colega de pé)

| Tempo (sugestão) | Quem caiu (1ª pessoa) | Os colegas |
|---|---|---|
| 0,0 s | sanidade chega a 0; duas batidas de coração abafadas; som ambiente abafa | — |
| 0,0–1,5 s | bordas escurecem, leve desfoque; câmera cambaleia e desce devagar até o chão | o avatar cambaleia, senta e tomba de lado devagar; espiral de estrelinhas sobre a cabeça; balão "Zzz..." |
| 1,5–2,5 s | tela escura: **"You fainted!"** · "Bellmoor Rescue is on the way." | notificação: "{name} fainted!" |
| 2,5 s → | câmera passa para um colega (spectate); painel de reviver (§9.3) | — |
| ~5–10 s | (assiste pelo colega) | sirene curta e suave; a ambulância para ao lado do trailer; dois médicos (CHR-008) descem com a maca: "Easy now. We've got you."; levam o avatar; a ambulância vai embora |

O jogador caído não tem prompt e não é alvo de anomalia. Suas Tools ficam guardadas (game-designer confirma).

### 9.2 Reviver (Robux ou Rescue Whistle)

| Passo | Quem reviveu | Os colegas |
|---|---|---|
| pagou / item usado | tela: "Hang on — Rescue's turning around!" | notificação: "{name} is coming back!" |
| ~3–5 s | — | a ambulância volta e **para ao lado do trailer**; **ninguém desce** (DEC-091) |
| chega | volta à 1ª pessoa, em pé ao lado da ambulância; sacode a cabeça como quem acorda; legenda curta: "Back on shift!" | o avatar aparece ao lado da ambulância, que vai embora |

Item raro (DEC-100; ITM-021): nome de exibição **Rescue Whistle** (`ui-text.md` §3; "Revive Kit" em DEC-129 e `design/` é o mesmo item, chave `revive_kit`). O apito chama a ambulância de volta. Robux: só o próprio caído compra, para si (DEC-116). Whistle: o próprio caído no spectate ou um colega de pé (uso por colega ainda em `Q-120` f); os textos cobrem as duas formas.
Limite (DEC-129): 2 revives por jogador por noite, somando Robux e Whistle. Na 3ª queda da mesma noite não há oferta: vira espectador na hora.

### 9.3 Spectate

- Até as **6:00 AM** da noite em que caiu (DEC-115): painel pequeno com o reviver (se ainda tem revive na noite, DEC-129).
- Às 6:00 AM sem reviver, ou sem revive sobrando na noite (DEC-093, DEC-115, DEC-129): "You're out for now." · "Watch your crew. Cheer them on!" · "Your gems are safe." (DEC-104) · botão "Back to Lobby". (Não diz "rest of the run": se a party perder uma noite e ela repetir, todos voltam, DEC-111, DEC-113.)
- Troca de colega: o botão de interagir passa para o próximo (FEAT-025). Rótulo: "Watching: {name}".

### 9.4 Último de pé cai (ou solo)

- Mesma queda do §9.1, mas **sem troca de câmera**: a tela fica escurecida, com a sirene ao longe, e abre a **janela de 10 s** (DEC-094) para todos: "Everyone's out! Revive in {n}..."
- Reviveu na janela: a sequência §9.2 roda e a noite segue.
- Ninguém reviveu: noite perdida (§7, DEC-102).
- Solo: idêntico (o solo é sempre o "último de pé").
