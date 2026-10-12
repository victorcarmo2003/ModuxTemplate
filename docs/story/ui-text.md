Status: Rascunho

# Textos de UI, prompts, placas e nomes

Autor: narrative-writer, 2026-10-08. Nada aqui é decisão. Texto de jogo em inglês (DEC-022).
Limites: prompt **até ~16 caracteres** (alvo mobile, DEC-014); notificação **uma linha**; nada de parede de texto.
Valores entre chaves são variáveis: `{n}`, `{price}`, `{item}`, `{name}`.
Sem XP, sem nível (DEC-081): nenhum texto de UI fala em XP, "level up" ou rank.
Conciliado com DEC-106, DEC-110 a DEC-116, DEC-124, DEC-129 e `consistency-report.md` (2026-10-08, NW-14, NW-16 a NW-23).
Revisão 2026-10-10 (TASK-082, onda 2): §10 a §15 novas (avisos, ligações do Walt, HUD noturno, placa do trailer, fim de
run); D-02 e D-03 do `tests/wave-1-report.md` resolvidos **do lado do documento** (§2, §15). Tudo da revisão é
**Provisório** (DEC-193): o usuário não revisou. Revisão 2026-10-12 (TASK-213): §16 Preparo 3D (dicas, recusas, selos, tutorial 3D com ids `PREP3D_*`), Provisório.

## 1. Nome do medidor (Q-054, arquivada; "Sanity" provisório)

| Opção | Prós | Contras |
|---|---|---|
| **Calm** (recomendada) | inglês simples para criança e para quem não é nativo; "Calm 0" = em pânico, leitura imediata; original | menos "horror" que Sanity |
| Nerve | evocativo ("lost your nerve") | expressão menos conhecida para não nativo |
| Sanity | claro para gamers | é o medidor central do jogo de referência (inspiração, não cópia — `research/animal-hospital.md`) |

Só muda o texto do HUD; a mecânica é a mesma (DEC-056). Abaixo, `{meter}` = o nome escolhido.

## 2. Prompts no mundo (DEC-015, DEC-066)

| Onde | Texto |
|---|---|
| Placa da frente | "Open Shop" / "Close Shop" |
| Telefone fixo do carrinho / do trailer (AST-042, DEC-124), tocando | **"Answer"** (Q-113 a) |
| Estoque de salsicha | "Grill" |
| Grelha, salsicha pronta | "Collect" |
| Pão | "Slice Bun" (mesmo texto de `design/features.md`; `items.md` ainda diz "Place Bun", correção do game-designer, GD-19) |
| Esteira (warmer) | "Add Sausage" |
| Complemento | "Add {item}" (ex.: "Add Ketchup") |
| Cliente no balcão | "Take Order" · "Refuse" |
| Entrega | "Serve" |
| Item solto (item alterado da N2; item derrubado no atropelamento, DEC-103) | **"Pick Up"** (igual a FEAT-036; proposta para `Q-113` a) |
| Colega (café) | "Give" |
| Prateleira do Mart | "Buy {item} — ${price}" (D-03, §15) · bloqueada: etiqueta "Out of stock", sem prompt |
| Bancada "GEAR WALL" (Mart, DEC-101), posições básicas B1–B5 (sempre à venda, DEC-106) | "Buy {upgrade} — ${price}" (mostra o próximo nível; D-03) · nível máximo: etiqueta **"Maxed"**, sem prompt (D-02, §15; igual a FEAT-015 e ao código) · B5 no carrinho: "Trailer only" |
| Bancada, vitrine especial S1 (DEC-106), com o Rescue Whistle | "Buy Whistle — ${price}" · vazia: etiqueta "Nothing special today" (FEAT-015) |
| Estação, com pacote na mão | "Restock" |
| Lixeira | "Throw Away" |
| Interruptor | "Lights Off" / "Lights On" (texto dinâmico pelo estado, como o "Take Coffee"; ajuda a N3 "lights off, count five, lights on"). Sem texto dinâmico: "Lights". Provisório (§12.4) |
| Botão da janela de serviço, ao lado do interruptor do trailer (só à noite, DEC-221; ação `shutter_toggle`) | **"Close Window"** / **"Open Window"** (texto dinâmico pelo estado, como o interruptor). Sem texto dinâmico: "Window". Provisório |
| Cafeteira | "Brew Coffee" · café pronto: "Take Coffee" (`PromptText`, `content-data.md` §6.9) |
| Tool Coffee | "Drink" |
| Tool Rescue Whistle (uso por colega depende de `Q-120` f) | na mão de um colega de pé: "Revive {name}" · na hotbar: "Blow Whistle" |
| Trailer no lote | "Buy Trailer — ${price}" (D-03; igual a `architecture.md` §19.5) |

Nome longo: "Add Potato Sticks" (17) e "Add Cream Cheese" (16) estão no limite; se não couber, usar só o ícone + "Add". "Revive {name}" com nome longo: cortar o nome com "…".
Saiu: "Upgrade ({price})" no próprio equipamento (Q-084 fechada por DEC-101: compra na bancada do Mart).

## 3. Veículos, ingredientes, upgrades, itens

| Placeholder atual | Proposta | Nota |
|---|---|---|
| "Boss's Cart" (DEC-052) | **Corner Cart** | letreiro físico: "BRAMBLE'S CORNER DOGS" |
| "Food Trailer" (DEC-052) | **Open Late Trailer** | letreiro físico desbotado: "BRAMBLE'S — OPEN LATE" |
| Grill (3 níveis) | Old Grill → Double Grill → Big Sizzle Grill | |
| Cooler (3 níveis) | Small Cooler → Big Cooler → Deep Chill Cooler | |
| Counter (3 níveis) | Little Counter → Wide Counter → Long Counter | |
| Cash Drawer Lock | **Drawer Lock** | |
| Trailer Lights | **Trailer Lights** (manter) | nome claro já ensina o uso |
| Cafeteira (fixa no trailer, DEC-125; não é vendida) | **Coffee Maker** | Tool: "Coffee" |
| Item raro de reviver (ITM-021; "Revive Kit" em DEC-129 e `design/`) | **Rescue Whistle** (nome de exibição) | apito dourado com cordão Teal (AST-051), da Bellmoor Rescue; chama a ambulância de volta. Fica na vitrine especial da bancada. Chave de dados segue `revive_kit` |
| Ingredientes | Bun, Sausage, Ketchup, Mustard, Cheese, Bacon, Potato Sticks, Cream Cheese | nomes genéricos, sem marca (Q-041) |
| Pacotes do Mart | "Sausages ×8", "Buns ×8", "Ketchup ×20", "Mustard ×20", "Cheese ×6", "Bacon ×6", "Potato Sticks ×10", "Cream Cheese ×8", "Ground Coffee ×10" | quantidades de DEC-049 e DEC-071 |

## 4. Placas e letreiros (assets com texto)

| Asset | Texto |
|---|---|
| Placa do carrinho/trailer | "OPEN" / "CLOSED" |
| Trailer no lote | "Available on Day 5" (DEC-047) · do Day 5 até a compra: "FOR SALE" (§13) |
| Carrinho, lateral | "Hot dogs on the corner since forever." |
| Carrinho coberto no lote (Q-082) | bilhete: "Good cart. Rest up. — W" |
| Mercado | "NINTH STREET MART" + neon "OPEN 24 HOURS" |
| Nota de consistência (art-director, level-designer) | o nome do painel da bancada é **"GEAR WALL"** em todo texto de `docs/story/`. Hoje divergem: MAP-01 diz "TODAY'S GEAR" e AST-072 diz "UPGRADES". Proposta: alinhar os dois a "GEAR WALL". |
| Mart, parede do fundo (DEC-101, DEC-106) | placa principal: "GEAR WALL" · placa da vitrine especial (S1): "SPECIAL" · "Changes every shift." |
| Cavalete de obra na calçada (proposta; substitui "ROAD CLOSED", que contradiz a Juniper Sul aberta, DEC-131) | "SIDEWALK CLOSED" · seta + "USE OTHER SIDE" (alternativa: "SIDEWALK CLOSED — WALK AROUND") |
| Mart, frutas e verduras | "FRESH PRODUCE" |
| Banco | "BELLMOOR SAVINGS" (com relógio) |
| Ruas | "NINTH AVE" · "JUNIPER ST" |
| Meio-fio em frente ao trailer (Q-103) | "NO PARKING" (meio-fio pintado de vermelho) |
| Ambulância (DEC-091) | "BELLMOOR RESCUE" |
| Lavanderia | "SUDS & SOCKS" |
| Panfleto (cutscene) | ver `script.md` §1 |
| Panfleto (pós-créditos) | ver `ending.md` §2.4 |
| Vitrines (cutscene) | "NO HELP WANTED" |

## 5. HUD (DEC-015)

| Campo | Formato |
|---|---|
| Horário | "8:00 AM" (DEC-048) |
| Turno | "Day {n}" / "Night {n}" |
| Dinheiro | "${n}" |
| Medidor (só à noite) | "{meter}" (§1); onda 2: ver §12.1 |

## 6. Notificações (canto superior direito, uma linha)

| Evento | Texto |
|---|---|
| Trailer disponível, não comprado (DEC-028) | "Old trailer for sale! Check the lot." (`trailer_available`, §10; encurtado para caber no celular) |
| Lembrete nos dias seguintes | "The trailer's still waiting in the lot." (`trailer_waiting`) |
| Trailer comprado (DEC-086) | "Trailer bought! It's yours next shift." (`trailer_bought`) |
| Ingrediente novo | "New: {item}! A free pack is at the station." |
| Vitrine especial com Rescue Whistle (DEC-100, DEC-129) | "Something special at the Mart." (igual a FEAT-035) |
| Ladrão impedido (DEC-050) | "Nice catch! +$5" |
| Ladrão roubou | "Someone raided the drawer! −${n}" |
| Atropelado (DEC-095, DEC-103) | texto cômico no mundo, sobre o avatar: "BONK!" · se derrubou item: "Dropped {item}!" |
| Reconexão, no lobby (DEC-063) | "You have a shift in progress." · botão "Rejoin" |
| Colega desmaiou (DEC-091) | "{name} fainted!" |
| Colega revivendo | "{name} is coming back!" |
| Colega de volta | "{name} is back on shift!" |
| Colega virou espectador (DEC-093, DEC-115, DEC-129) | "{name} is resting for now." |
| Noite repetida, espectadores de volta (DEC-111, DEC-113) | "Everyone's back on shift!" |

### 6.1 Gemas por evento (DEC-104)

Cada gema é creditada e salva no instante do evento. A notificação aparece na hora; a tela de resumo só repete.
**Onda 2:** o contrato tem uma chave só, `gems_gained` (`ValueFrom = Number`), sem o evento. O toast fica genérico
(§10) e as frases abaixo viram linha da tela de resumo. Toast por evento exige `ValueFrom` novo (architect, onda 4).

| Evento (DEC-070, DEC-083, DEC-084) | Texto |
|---|---|
| Turno de dia concluído (≥ 3 pedidos completos) | "+2 Gems · Day {n} done!" |
| Nota A no dia | "+1 Gem · Grade A!" |
| Turno de dia sem o mínimo (anti-AFK) | "No gems this day: serve 3 full orders." |
| Noite vencida | "+{n} Gems · Night {n} survived!" |
| Final (10ª noite) | "+100 Gems · You kept the light on!" |
| Day 100 (secreto, por jogador) | "Secret found: Never Clocked Out! +300 Gems" |
| Selo de salvamento (opcional, discreto) | "Saved" |

## 7. Telas

| Tela | Textos |
|---|---|
| Cutscene, voto de pular (DEC-078) | "Hold to skip" · contador "Skip {votes}/{needed}" · ao pular: "Skipping..." |
| Resumo do turno | "Shift Summary" · "Sales" · "Tips" · "Boss Bonus" · "Grade" · "Gems earned" (já salvas) |
| Noite perdida, chance do chefe usada agora (DEC-110, DEC-112) | "Night Lost" · "That was your one chance." · "Same night again..." (automático) |
| Fim da run (2ª noite perdida da run) | "Shift's Over" · "Nights survived: {n}" · "Gems earned: {n}" · "Back to Lobby" |
| Fim da run com final | "You Kept the Light On" · "Gems earned: {n}" · "Back to Lobby" |

### 7.1 Queda, reviver e spectate (DEC-091 a DEC-094, DEC-100, DEC-111, DEC-113, DEC-115, DEC-116, DEC-129; sequência em `script.md` §9)

| Momento | Textos |
|---|---|
| Desmaio (tela de quem caiu) | "You fainted!" · "Bellmoor Rescue is on the way." |
| Oferta de reviver (Robux, DEC-092) — **só na tela do próprio caído, só para si** (DEC-116) | título "Get back on shift?" · botão "Revive" + ícone Robux + `{price}` (preço `Q-098`) · linha pequena "Revives left tonight: {n}" (2 → 1, DEC-129) |
| Oferta, se o caído tem Rescue Whistle na hotbar | botão "Use Whistle" |
| Colega de pé com o Whistle na mão (só o Whistle; uso por colega em `Q-120` f) | prompt "Revive {name}" (§2). Não existe oferta de Robux para colega (DEC-116) |
| Pagou / apito usado | "Hang on — Rescue's turning around!" |
| Voltou | "Back on shift!" · "{meter} {n}" (n = 50% do valor inicial da classe, FEAT-034) |
| Spectate durante a noite da queda (DEC-115) | "Watching: {name}" · "Tap to switch" · lembrete pequeno "Revive until 6:00 AM" |
| 3ª queda na mesma noite (DEC-129): sem oferta | "No revives left tonight." · segue para a linha abaixo |
| Spectate depois das 6:00 AM ou sem revive na noite (DEC-093, DEC-115) | "You're out for now." · "Watch your crew. Cheer them on!" · "Your gems are safe." · botão "Back to Lobby" |
| Todos caídos, janela (DEC-094) | "Everyone's out!" · "Revive in {n}..." (10 → 0) |
| Janela acabou (DEC-102) | segue para "Night Lost" |

Saiu: "You've had enough for tonight." · "Resting · back next shift" (proposta antiga do banco; não vale depois de DEC-091 e DEC-093).

## 8. Falas de cliente comum (balão, uma linha)

| Momento | Pool |
|---|---|
| Chegada | "Hi there!" · "One hot dog, please!" · "Smells great!" · "Lunch time!" |
| Recebeu completo | "Perfect, thanks!" · "Yum!" · "See you tomorrow!" |
| Incompleto (DEC-072, balão de reclamação) | "Hey, where's my {item}?" · "Something's missing..." |
| Errado | "That's not what I asked for." |
| Desistiu | "Too slow... bye." · "I'll eat somewhere else." |
| Noite (clientes normais) | "Long shift?" · "Glad you're open." · "Quiet night, huh?" |
| Viu o jogador ser atropelado (opcional) | "Ooh! You okay?" · "Look both ways, kid!" |

## 9. Badges / conquistas

| Conquista | Nome | Descrição |
|---|---|---|
| Achievement secreto dos 100 dias (DEC-058, DEC-084) | **Never Clocked Out** | "Work 100 days on the corner. Any run counts." (escondida até desbloquear) |
| Final da 10ª noite (sugestão) | **Kept the Light On** | "Survive all ten nights." |
| Primeira noite (sugestão) | **First Night Shift** | "Survive your first night." |

---

# Onda 2 (TASK-082, 2026-10-10, Provisório)

Fontes: `content-data.md` v5 §3.19, §6.7, §6.9; `architecture.md` §19.4–§19.11; `network.md` §13.1; FEAT-017, 018,
021, 025, 026, 032; `tests/wave-1-report.md` D-02, D-03, D-04. Daqui saem os `Text` de `Notices.luau` e os `Lines`
de `BossCalls.luau` quando a TASK-047 fechar (só o texto; chaves, `Audience` e `ValueFrom` são do architect).

**Limites de texto (Provisório):**

| Onde | Limite | Por quê |
|---|---|---|
| Toast (Notice) | **≤ 40 caracteres**, 1 linha | canto superior direito do celular |
| Linha de ligação (legenda) | alvo **≤ 42**, teto **48** (de 43 a 48 só frase que perderia o ritmo se quebrada; nenhuma linha passa de 47) | `LineTime = 2,5 s` → ~17 caracteres/s, o máximo que um jogador jovem lê sem perder a linha |
| Ligação de dia | ≤ 7 linhas (`DayMaxLines`) | FEAT-018 |
| Ligação de noite | ≤ 18 linhas (`NightMaxSeconds = 45` ÷ 2,5) | FEAT-018 |

Fala aprovada em `anomalies.md` (regra do chefe e forma curta) **não muda de palavra**: só é **quebrada** em duas
linhas de legenda quando passa do teto. As demais falas de `script.md` foram encurtadas aqui; `script.md` §3–§7 segue
como texto-fonte, e esta seção vale para as tabelas.

## 10. Notices (avisos) da onda 2

### 10.1 Chaves do contrato (`content-data.md` §6.9)

| Key | Text final | Audience | ValueFrom | Onda |
|---|---|---|---|---|
| `trailer_available` | "Old trailer for sale! Check the lot." | Party | None | 2 |
| `trailer_waiting` | "The trailer's still waiting in the lot." | Party | None | 2 |
| `trailer_bought` | "Trailer bought! It's yours next shift." | Party | None | 2 |
| `gems_gained` | "+{value} Gems!" | Player | Number | 2 |
| `afk_no_gems` | "No gems today. Serve 3 full orders!" | Party | None | 2 |
| `achievement` | "Badge unlocked: {achievement}!" | Player | Achievements | 2 |
| `thief_caught` | "Nice catch! +${value}" | Party | Number | 2 |
| `coffee_cooldown` | "Coffee again in {value}s" | Player | Number | 2 |
| `coffee_full` | "Already wide awake. Save it!" | Player | None | 2 |
| ~~`hide_taken`~~ | saiu com o esconderijo (DEC-221) | — | — | — |
| `shutter_closed` | "The window's shut. Open it to serve." | Player | None | 3 (DEC-221; recusa de "Take Order"/"Serve"/"Refuse" com a janela fechada. Provisório) |
| `item_dropped` | "Dropped {item}!" (texto do mundo "BONK!" fica no avatar, §6) | Player | conforme architect | 3 |

Onda 4 (texto pronto, chave já listada no §6.9): `revive_used` "Hang on — Rescue's turning around!" ·
`revive_credit_saved` "Revive saved for your next run." · `special_on_bench` "Something special at the Mart." ·
`shift_cant_resume` "That shift has ended. Start a new one!" · `not_in_roster` "This shift's crew is already set." ·
`shift_ended_resume` "Your shift went on without you."

### 10.2 Avisos que faltam no contrato (proposta ao architect, TASK-047)

| Key (proposta) | Text | Audience | ValueFrom | Quem emite | Nota |
|---|---|---|---|---|---|
| `thief_stole` | "The drawer got raided! -${value}" (hífen ASCII, igual à tabela: fonte segura) | Party | Number | ThiefService | §6 já tinha o evento, sem chave |
| `coffee_night_only` | "Save it for the night shift." | Player | None | VitalService (`Q-170`) | só se o café de dia continuar bloqueado |
| `coffee_has_one` | "They already have a coffee." | Player | None | ItemService (`give_coffee`) | FEAT-021: entregar a quem já tem 1 é bloqueado |

### 10.3 Recusas da D-04 (texto de toda candidata; quais emitem é da TASK-081)

Chaves propostas; o nome final é do architect (TASK-047). Tom: diz o que falta, sem bronca.

| Situação (`wave-1-report.md` D-04) | Key (proposta) | Text | ValueFrom |
|---|---|---|---|
| Grelha cheia | `grill_full` | "The grill is full." | None |
| Sem estoque na estação (grelha, pão, complemento) | `out_of_stock` | "Out of {item}! Restock it." | Ingredients |
| Tábua cheia | `board_full` | "No room on the board." | None |
| 3 complementos no hot dog | `topping_max` | "3 toppings max!" | None |
| Complemento repetido | `topping_repeat` | "It already has {item}." | Ingredients |
| Restock com estoque cheio (TASK-057) | `stock_full` | "{item} is already full." | Ingredients |
| Prateleira `Blocked` | `shelf_locked` | "{item} isn't in stock yet." | Ingredients |
| Bancada `busy` (outro jogador comprando) | `bench_busy` | "Someone's buying that right now." | None |
| Bancada `Maxed` | `upgrade_maxed` | "{upgrade} is maxed out." | Upgrades |
| Take Order fora de Open/Closing (TASK-053) | `shop_closed` | "Open the shop first!" | None |

## 11. Ligações do Walt (`BossCalls.Lines`)

Legenda: "Walt: {line}" (§12.4). Cada linha abaixo é **uma** entrada de `Lines`. A última linha de toda ligação
noturna é a forma curta aprovada (`anomalies.md`).

### 11.1 Day 1 (tutorial) e dicas

`script.md` §3 usa gatilhos de proximidade ("perto da placa"); o contrato só tem `Hint` por **1ª execução de uma ação**
(`Trigger.Action`). O tutorial foi refeito em cima disso: a ligação do Day 1 dá os 3 primeiros passos e cada dica toca
**depois** da ação que a abre.

| Key | Trigger | Lines |
|---|---|---|
| `call_day_1` | `DayPrep`, Day 1 | "Morning, Rookie! I'll stay on the line." · "Tap the sausage box. It goes on the grill." · "Flip the sign to OPEN when you're ready." |
| `hint_grill_place` | `Hint`, `grill_place` | "When the bar fills up, grab it." |
| `hint_grill_collect` | `Hint`, `grill_collect` | "It waits on the warmer. Now slice a bun." |
| `hint_bun_cut` | `Hint`, `bun_cut` | "Pop a sausage in the bun." |
| `hint_board_add_sausage` | `Hint`, `board_add_sausage` | "There's your hot dog. Wait for an order." |
| `hint_open_sign` | `Hint`, `open_sign` | "We're open! Folks line up at the counter." |
| `hint_take_order` | `Hint`, `take_order` | "See the bubble? That's the order." · "Add only what they asked for. Nothing extra." |
| `hint_serve` | `Hint`, `serve` | "Nice! Money goes in the drawer." · "Running low? The Mart's across the street." · "Look both ways! These drivers don't brake." |
| `hint_buy_package` | `Hint`, `buy_package` | "Careful crossing. Get hit, and you drop it." · "Gear's on the back wall." · "Sometimes there's something special." |
| `hint_restock` | `Hint`, `restock` | "That's how you restock. Easy." |
| `hint_discard` | `Hint`, `discard` | "Messed one up? Toss it. No harm done." |
| `hint_bench_buy_upgrade` | `Hint`, `bench_buy_upgrade` | "New gear's already on the cart. Heh." |

Ficam **fora** (sem gatilho no contrato): 1º passo na rua e 1º estoque baixo (entraram no `hint_serve`), 1ª entrada no
Mart (no `hint_buy_package`), 1ª saída da zona do carrinho, 1º atropelamento (onda 3; pede `Trigger` novo ao architect),
6 PM ("Flip the sign to CLOSED" **sai**: o Closing é automático, não tem placa). Sem dica para `refuse` de dia (não
ensinar recusa antes da N1).

### 11.2 Dias 2–5

Variante `_quentin` (N ≥ 3): a mesma ligação com **"Heard you caught Quentin in the act. Nice."** inserida como 2ª
linha (todas ficam ≤ 7 linhas).

| Key | Lines |
|---|---|
| `call_day_2` | "Morning! Cheese came in. Folks love cheese." · "Oh — keep an eye on your cash drawer." · "Some folks have quick hands." · "Stay close to the cart." |
| `call_day_3` | "Bacon day! Smell that?" · "That's the smell of money." · "You're doing great, Rookie. Really." |
| `call_day_4` | "New stuff: potato sticks. Kids love 'em." · "Bigger grill on the Mart's back wall." · "See that old trailer in the lot?" · "Not yet. Heh." |
| `call_day_5` | "Big day, Rookie. See that old trailer?" · "It's for sale. Buy it with the shop money." · "Don't ask how that works. Just trust me." · "She's been waiting for the right person." · "A long time." |

### 11.3 Dias depois das noites (proposta de chave ao architect)

`script.md` §4.4 numera por **dia**, mas a fala depende da **noite anterior**: com o trailer comprado no Day 7, o dia
depois da Night 1 é o Day 8. Proposta: `call_day_after_<k>` com `Trigger = { Kind = "DayPrep", Night = k }` (campo
`Night?` já existe no §6.7). "Cream cheese came in" saiu do dia depois da N1 (o toast `ingredient_unlocked` já avisa,
e o queijo pode ter chegado antes, no dia infinito).

| Key | Depois da | Lines |
|---|---|---|
| `call_day_after_1` | Night 1 | "Morning! You made it." · "Told you nights were quiet." · "Grill's hot. Go sell some dogs." |
| `call_day_after_2` | Night 2 | "Morning, Rookie. Sleep okay?" · "Good. Don't think about it too hard." |
| `call_day_after_3` | Night 3 | "Bank clock's ticking fine today. See?" · "Nice and normal. Sell some dogs." |
| `call_day_after_4` | Night 4 | "Just one Mr. Pickett today, I hope. Heh." · "...That was a joke. Mostly." |
| `call_day_after_5` | Night 5 | "She liked you. The lady. I can tell." · "Forget I said that. Grill's waiting." |
| `call_day_after_6` | Night 6 | "Ever notice nobody lives upstairs?" · "In the daytime, I mean." · "Huh. Next question." |
| `call_day_after_7` | Night 7 | "You kept your eyes down. Good." · "I used to count the lamps. It helps." |
| `call_day_after_8` | Night 8 | "Long night, huh? Coffee's on me." · "Tell Opal it's for Walt. She knows." |
| `call_day_after_9` | Night 9 | "Rookie. About the knocking." · "That wasn't me." · "I need you to believe that." · "Tonight's the last one." · "Then you get answers. I promise." |

Variante com alguém em spectate (`script.md` §4.4): 1ª linha vira "Short a hand today? You'll manage." (pede
`Trigger.Variant`; sem isso, fica fora da onda 2).

### 11.4 Dia infinito (`call_day_infinite`, 1 linha sorteada, sem repetir a anterior)

"Another day, another dog." · "Proud of you, Rookie. Really." · "Grill's hot. Let's go." · "The trailer's still
there. Just saying." · "Nice and normal. Just how I like it." · "Ketchup, mustard, a smile. That's the job."

Saiu: "Peek at the Mart's glass case…" (no dia infinito a vitrine especial fica vazia, FEAT-017).
Formato do pool (uma linha sorteada de `Lines` ou N chaves) é do architect.

### 11.5 Trailer comprado (`call_trailer_bought`)

Pelo `architecture.md` §19.5 ela toca na `Call` da Night 1, **dentro do trailer** (não mais no fade do carrinho, como
`script.md` §4.2). Texto refeito para esse momento. **Tem de tocar antes da `call_night_1`** (hoje a noite tem
prioridade 4 e esta 3: pedido ao architect/game-designer: prioridade 4 com ordem fixa, ou 5).

"You bought the old girl! Heh." · "She looks good on that corner." · "The cart gets a rest now." · "Listen... I need
someone on nights." · "Can you cover the night shift? Tonight?" · "There are a few... house rules." · "Nothing big.
I'll tell you as we go." (7 linhas, 17,5 s; com a `call_night_1` somam ~37 s, dentro do cap de 60 da `Call`.)

### 11.6 Noites (`call_night_<N>`)

| Key | Lines | Linhas / s |
|---|---|---|
| `call_night_1` | "Evening, Rookie. First night." · "Nights are... quieter." · "Some customers might look a little off." · "If someone walks up with no face —" · "no eyes, no mouth — don't serve them." · "Just refuse. They'll wander off." · "Keep the grill hot. See you at six." · **"No face? Refuse them."** | 8 / 20 |
| `call_night_2` | "Night two. You did fine last night." · "Check your food before it goes out." · "A gray sausage, or a bun with a bite" · "in it you didn't take — toss it." · "Trash can. Don't serve it." · "And still no faces. Remember faces." · **"Wrong food? Throw it away."** | 7 / 17,5 |
| `call_night_3` | "Evening. Can you see the bank clock?" · "Keep an eye on it. And an ear. It ticks." · "If it stops, flip the trailer lights off." · "Count to five. Then back on." · "That gets it going again." · "Don't leave it stuck. Trust me on this." · **"Clock stops? Lights off, count five, lights on."** | 7 / 17,5 |
| `call_night_4` | "Rookie... there's something you should know." · "Sometimes a customer shows up twice." · "Same face, same clothes." · "One of them is a copy." · "The copy is backwards." · "Look at their shirt. Their watch. Backwards." · "Refuse the backwards one. Serve the real one." · "Who are they? ...Next question." · **"Two of them? Refuse the backwards one."** | 9 / 22,5 |
| `call_night_5` | "Tonight, a lady in a yellow raincoat" · "might come by." · "It won't be raining." · "She'll be dripping anyway." · "Serve her. Always. Whatever she asks for." · "Don't refuse her. Don't make her wait." · "She's a... very old customer. Be nice." · **"Yellow raincoat? Always serve her."** | 8 / 20 |
| `call_night_6` | "Evening. Folks upstairs might wave tonight." · "Don't wave back. Don't even look up." · "They just want someone to notice them." · "Eyes on your grill. They'll get bored." · "I know. I know. I'll explain someday." · **"Someone waving upstairs? Don't look up."** | 6 / 15 |
| `call_night_7` | "Rookie. Listen close. This one matters most." · "Down Juniper Street, someone walks" · "toward the trailer." · "Every time you look at them," · "they get closer." · "Whatever you do," · "never let them reach your light." · "Don't watch the Walker. Not for a second." · "When the far lamp buzzes, they're there." · "Tell your crew." · **"Whatever you do, never watch the Walker."** | 11 / 27,5 |
| `call_night_8` | "Evening. You're doing better than I ever did." · "If a long car parks across the street" · "with its lights on you —" · "close the service window. Stay inside." · "Don't open it till you hear it drive away." · "Can't serve with it shut. Folks will wait." · "Regular cars never stop there. That one does." · "And never watch the Walker." · **"Long car? Close the window. Keep it shut."** | 9 / 22,5 |
| `call_night_9` | "One more thing. This is important." · "I never come to the trailer at night. Never." · "If someone knocks on the back door" · "and says it's me —" · "it isn't. Close the window. Stay inside." · "Keep it shut till the knocking stops." · "...I'm sorry I didn't tell you sooner." · "And never watch the Walker." · **"Knocking? It's not me. Close the window."** | 9 / 22,5 |
| `call_night_10` | "Last night, Rookie. Ten." · "Nobody's made it to ten since... well." · "Tonight the street might go dark." · "Lamp by lamp." · "When the lamps start going out," · "leave the trailer." · "Go to the Mart. Stand under the OPEN sign." · "It never goes out." · "Come back when the lamps come back." · "And never watch the Walker." · "See you at sunrise. I promise." · **"Lamps going out? Go to the Mart sign."** | 12 / 30 |

Todas ≤ 45 s. A forma curta é sempre a última linha (o que fica na cabeça).
N8 e N9 (DEC-221, Provisório): o verbo "esconder" virou "fechar a janela"; as falas repetem o prompt "Close Window" e
dizem a regra inteira: janela fechada protege, abrir antes da hora custa, com ela fechada não se atende.

### 11.7 Noite repetida e noite perdida

| Key | Lines | Nota |
|---|---|---|
| `call_night_short` | "Same night, Rookie. Same rules." · "You know them." · {forma curta da Night N} · (N ≥ 8) "And never watch the Walker." | uma só linha `NightRepeat` no contrato, mas o texto muda por noite: proposta ao architect = o `BossService` acrescenta a **última linha** da `call_night_<N>` e, de N ≥ 8, a linha do Walker. Na N7 o lembrete **não** entra (a forma curta já é o Walker; corrige o "7–10" do `script.md` §5.11) |
| `call_lost_critical` | "You watched it, didn't you?" · "...It's okay. Breathe." | toca antes da de baixo |
| `call_lost_last_chance` | "Rough night. Let's try that again." · "Everyone's back on their feet." · "But listen. This is the only time" · "I can do this, Rookie." · "Be careful out there." | a linha da party ("Whole crew's back on…") virou uma que serve no solo, sem variante |
| `call_run_over` | "That's two, Rookie." · "I can't put you on nights anymore." · "Go home. Rest. You did more than most." | `architecture.md` §19.9 proíbe ligação em `NightLost`/`RunEnd`: sem fase para tocar. Proposta: estas linhas aparecem na **tela de fim de run** como citação "Walt: …" (§14), sem telefone |

Ordem na `Call` da noite repetida: `call_lost_critical` → `call_lost_last_chance` → `call_night_short` (as três têm
prioridade 4; pedido de ordem fixa ao architect). Total ≤ 11 linhas, ~27 s.

### 11.8 Falas da tela de resumo (não são ligação; FEAT-018)

| Key (proposta) | Text |
|---|---|
| `line_day_end_1` … `_5` | "Good job today! See you at seven." · "Good job today! Two for two." · "You're doing great. Same time tomorrow?" · "You're doing great. Tomorrow's a big day." · Day 5 sem compra: "No trailer yet? That's okay. She'll wait." |
| `line_grade_A` … `_D` | `script.md` §4.5 (sem mudança) |
| `line_night_end_1` … `_9` | `script.md` §6 (sem mudança; todas ≤ 42) |
| `line_night_end_resting` | "You made it. Your friend's resting. They're okay." (onda 2 sem ambulância: sai "at Bellmoor Rescue") |

Onde ficam (tabela ou HUD) é do architect; hoje nenhuma tabela da onda 2 tem esse campo.

## 12. HUD noturno

### 12.1 Medidor

| Elemento | Texto |
|---|---|
| Rótulo do medidor | **sem palavra**: retrato do rosto da faixa (DEC-167) + barra. Se o layout pedir rótulo: "Sanity" (provisório nas DEC, `Q-054` arquivada); recomendação do §1 continua "Calm" |
| Número (opcional) | "{value}" sem "/max" (o máximo muda por classe e confunde) |
| De dia | nada (`Max = 0` esconde) |

### 12.2 Turno e relógio

| Momento | Texto |
|---|---|
| HUD | "Night {n}" · relógio "7:00 PM" parado na `Call`, depois "8:00 PM" → "6:00 AM" |
| Banner no início da noite | grande "Night {n}" · pequeno "Stay open till 6:00 AM." |
| Banner na noite repetida | grande "Night {n}" · pequeno "Same night. Same rules." (nunca fala de chances, DEC-053) |
| 6:00 AM (`NightEnd`) | "6:00 AM" · "You made it!" |
| Todos de volta na noite repetida | "Everyone's back on shift!" (§6) |

### 12.3 Queda, janela e espectador (onda 2: sem ambulância nem reviver; ondas 2–3)

| Momento | Texto |
|---|---|
| Desmaio (tela de quem caiu) | "You fainted!" · "Your crew's still on shift." (a linha "Bellmoor Rescue is on the way." volta na onda 4, §7.1) |
| Spectate | "Watching: {name}" · troca: celular "Tap to switch", PC "Press E to switch", gamepad "Press X to switch" (tecla real do bind) |
| Spectate sem colega de pé (`SPEC-P`/`SPEC-M`) | "Watching the trailer" |
| Virou espectador (6:00 AM ou 3ª queda) | "You're out for now." · "Watch your crew. Cheer them on!" · "Your gems are safe." (sem botão: não há lobby até a onda 4) |
| Janela de 10 s | "Everyone's out!" · "Lights out in {n}" (10 → 0). Onda 4 acrescenta "Revive now to keep the night!" só para quem tem oferta |
| Janela fechada por alguém voltando (`WipeCleared`) | toast "Someone's back! Keep going!" |
| Toasts por `LifeEvent` (com nome, montados no client) | `Down`: "{name} fainted!" · `Spectating`: "{name} is resting for now." · `Revived` (onda 4): "{name} is back on shift!" |

### 12.4 Ligação, telefone, café, luz

| Elemento | Texto |
|---|---|
| Legenda | "Walt: {line}" (uma linha, ≥ 14 px, TASK-071) |
| Telefone tocando | só som e luz; prompt "Answer" |
| Alucinação de telefone | "Walt: ..." (sem prompt) |
| Cafeteira | "Brew Coffee" → barra → "Take Coffee" |
| Tool | "Coffee" · colega: "Give" |
| Interruptor | "Lights Off" / "Lights On" (§2) |
| Botão da janela (DEC-221) | "Close Window" / "Open Window" (§2) · atender com ela fechada: toast `shutter_closed` (§10.1) |

### 12.5 Tela de resumo da noite

| Campo | Texto |
|---|---|
| Título | "Night {n} Survived" |
| Linhas | as do resumo de dia (§7) + "Gems earned" |
| Fala | `line_night_end_<n>` (§11.8) |

## 13. Placa e prompt do trailer (SIGN-T, TASK-058)

| Estado | Texto |
|---|---|
| Antes do `BuyFromDay` | "Available on Day {n}" (n = 5) |
| Do Day 5 até a compra | "FOR SALE" (o preço fica no prompt) |
| Prompt | "Buy Trailer — ${price}" (hold 2 s) |
| Depois da compra | placa some |

## 14. Fim de run (`RunReport`, TASK-065)

| `Result` | Textos |
|---|---|
| `Failed` | "Shift's Over" · "Days worked: {Day}" · "Nights survived: {n}" · "Gems earned: {Gems}" · citação: as 3 linhas de `call_run_over` (§11.7) |
| `Success` | "You Kept the Light On" · "Nights survived: 10" · "Gems earned: {Gems}" |
| Rodapé, ondas 2–3 | "Starting over at Day 1..." (o `ResetDev` volta ao Day 1, sem lobby) |
| Rodapé, onda 4 | botão "Back to Lobby" (§7) |

`{n}` em `Failed` = `Night − 1` (a noite perdida não conta como sobrevivida). Quem calcula é o client.
Noite perdida com a chance gasta agora (`LastChanceUsed`): "Night Lost" · "That was your one chance." · "Same night
again..." (§7, sem mudança).

## 15. D-02 e D-03 (resolvidos no documento, sem task de código)

| Divergência | Escolha | Motivo | O que muda |
|---|---|---|---|
| D-02 "Maxed" × "MAX" | **"Maxed"** | já está em FEAT-015, no código (`MarketController/Labels.luau`) e nos testes T036-08/10 | só este documento (§2). AST-049, se tiver "MAX" pintado, alinha com o art-director (texto da etiqueta é gerado no código) |
| D-03 "Buy {upgrade} — ${price}" × "Buy {upgrade} ({price})" | **"Buy {x} — ${price}"** | já está em `Actions`, FEAT-015 e §19.5; o "$" deixa claro que é dinheiro da party | §2: prateleira, bancada, Whistle e trailer no mesmo formato |

## 16. Preparo 3D (TASK-213, 2026-10-12, Provisório)

Fontes: `docs/tech/prep-3d.md` (§2.2 alvos, §3.0 seções, §3.2 a §3.5 estágios, §5 HUD), `docs/art/prep-ui-spec.md` §6 a §7,
`Content.Prep` (`Texts`, `Build.Texts.Hints`, `Reasons`, `Grades.Labels`), `Notices.luau`, `Steps.luau`, `tools/voice/lines.json`.
**Tudo Provisório, sem DEC.** Texto de jogo em inglês (DEC-022). Nomes de seção em inglês: **Grill, Board, Toppings, Serve**
(`prep-3d.md` §3.0). Vocabulário fixo: **trailer** (nunca "cart"), **frank** na voz, **rail** (trilho), **roller** (rolete),
**crate** (caixa de pães), **box** (caixa de franks), **bin** (lixeira), **window** (janela de entrega).

**Limites (Provisório):**

| Onde | Limite |
|---|---|
| Dica (uma linha, acima da barra de seções) | **<= 36 caracteres**, 1 linha, 16 px |
| Toast | **<= 36 caracteres** (teto 40, §10), 1 por vez |
| Rótulo de botão, aba ou chip | **<= 12 caracteres** |
| Fala do Walt (voz) | **<= 8 palavras** (alvo 6), sem dígito, sem "sausage" (use "frank" ou "hot dog"), sem "cart", sem número de telefone |
| Texto de UI (não falado) | pode dizer "sausage" e dígitos; a voz não |

Regra de escrita: o verbo vem primeiro, o alvo vem depois ("Drag the knife along the line"). Nunca só cor: onde a dica fala
de "ring" ou "mark", há forma e som também (`prep-3d.md` §2.4). Sem vermelho, sem bronca: a recusa diz o que falta.

### 16.1 Dicas por alvo (`PrepTarget`, `prep-3d.md` §2.2)

Aparecem na linha de dica quando o alvo está em hover (mouse, foco do gamepad) ou pulsando (toque). `{item}` = nome do topping.

| Id | Alvo (`TargetKind`) · estado | Dica |
|---|---|---|
| PREP3D_TIP_GRILL | seção Grill, ao entrar | "Drop franks on the rollers" |
| PREP3D_TIP_BOX | `SausageStock` (caixa de franks) | "Tap the box or drag a frank out" |
| PREP3D_TIP_ROLLER_FREE | `GrillSlot` livre | "Drop it on a free roller" |
| PREP3D_TIP_ROLLER_COOK | `GrillSlot` cozinhando, antes da janela | "Cooking. Wait for the ring." |
| PREP3D_TIP_ROLLER_FLIP | `GrillSlot` na janela de virar (40 a 60%) | "Tap it when the ring closes" |
| PREP3D_TIP_ROLLER_LATE | `GrillSlot` depois da janela, ainda não virado | "Late flip. It still counts." |
| PREP3D_TIP_ROLLER_READY | `GrillSlot` pronto | "Ready! Tap it to collect" |
| PREP3D_TIP_RAIL | `Rail` (trilho) | "Ready franks wait on the rail" |
| PREP3D_TIP_CRATE | `BunCrate` (caixa de pães) | "Tap the crate for a bun" |
| PREP3D_TIP_BOARD | `Board`, pão fechado | "Cut the bun with the knife" |
| PREP3D_TIP_KNIFE | `Knife` | "Drag the knife along the line" |
| PREP3D_TIP_BOARD_OPEN | `Board`, pão aberto sem salsicha | "Drag the frank into the bun" |
| PREP3D_TIP_BOWL | `Topping`, qualquer tigela livre (hover) | "Tap to pick up {item}" |
| PREP3D_TIP_BOWL_KETCHUP | tigela/garrafa de ketchup | "Ketchup: trace the zig-zag" |
| PREP3D_TIP_BOWL_MUSTARD | tigela/garrafa de mustard | "Mustard: trace the zig-zag" |
| PREP3D_TIP_BOWL_CREAM | tigela/garrafa de cream cheese | "Cream cheese: trace the zig-zag" |
| PREP3D_TIP_BOWL_CHEESE | tigela de cheese | "Cheese: drag the slice on" |
| PREP3D_TIP_BOWL_BACON | tigela de bacon | "Bacon: tap each ring as it closes" |
| PREP3D_TIP_BOWL_POTATO | tigela de potato sticks | "Potato sticks: hold, then let go" |
| PREP3D_TIP_BOWL_USED | tigela já usada neste prato | "Already on the plate" |
| PREP3D_TIP_BOWL_LOCKED | tigela de ingrediente do dia futuro | "Not in stock yet" |
| PREP3D_TIP_BIN | `Bin` (lixeira), com prato na mão | "Drag the plate to the bin" |
| PREP3D_TIP_HATCH | `Hatch` (janela), prato pronto | "Drag the plate to the window" |
| PREP3D_TIP_CUSTOMER | `Customer` em `Q1`, `Ordering` | "Tap the customer for the order" |
| PREP3D_TIP_TICKET | ticket 2D, mais de um na fila | "Tap a ticket to pin it" |
| PREP3D_TIP_TAKE | botão Take do ticket | "Take the order" |
| PREP3D_TIP_LEAVE | Leave | "Leave. Your plate waits 20 s" |
| PREP3D_TIP_NEXT_GRILL | Next, seção Grill | "Next: on to the board" |
| PREP3D_TIP_NEXT_BOARD | Next, seção Board, habilitado | "Next: add toppings" |
| PREP3D_TIP_NEXT_BOARD_OFF | Next, seção Board, desabilitado | "Cut the bun and add the frank first" |
| PREP3D_TIP_NEXT_TOP | Next, seção Toppings | "Next: close the bun" |
| PREP3D_TIP_SERVE_OFF | Serve desabilitado | "Finish the plate first" |
| PREP3D_TIP_PAD_A | glifo no gamepad | "{A}: pick up or drop" |
| PREP3D_TIP_PAD_X | glifo no gamepad | "{X}: next target" |

Notas: PREP3D_TIP_NEXT_BOARD_OFF tem 35 caracteres (o teto é 36). `20 s` é `Rules.ClientIdle` (valor lido de `Content.Prep`; se mudar, o texto
usa `{n}`).

### 16.2 Seções (abas embaixo) e progresso (`prep-3d.md` §3.0, §5)

| Id | Elemento | Texto |
|---|---|---|
| PREP3D_UI_TAB_GRILL | aba 1 | "Grill" |
| PREP3D_UI_TAB_BOARD | aba 2 | "Board" |
| PREP3D_UI_TAB_TOPPINGS | aba 3 | "Toppings" |
| PREP3D_UI_TAB_SERVE | aba 4 | "Serve" |
| PREP3D_TIP_TAB_GRILL | dica da aba 1 | "Grill: franks cook while you work" |
| PREP3D_TIP_TAB_BOARD | dica da aba 2 | "Board: cut the bun, add the frank" |
| PREP3D_TIP_TAB_TOPPINGS | dica da aba 3 | "Toppings: up to 3, any order" |
| PREP3D_TIP_TAB_SERVE | dica da aba 4 | "Serve: send the plate out" |
| PREP3D_TIP_TABS_FREE | primeira vez que o jogador troca de aba | "Tabs are free. Next keeps the order" |
| PREP3D_UI_PROG_GRILL | cartão de progresso, Grill | "Grilling" |
| PREP3D_UI_PROG_BOARD | cartão de progresso, Board | "Cutting {n}%" |
| PREP3D_UI_PROG_TOP | cartão de progresso, Toppings | "Toppings {n}/{k}" |
| PREP3D_UI_PROG_SERVE | cartão de progresso, Serve | "Serving" |
| PREP3D_UI_PIPS | três pips de nota (Cut, Place, Top) | "Cut" · "Place" · "Top" |
| PREP3D_UI_BADGE_READY | badge da aba Grill (tooltip) | "{n} ready" |
| PREP3D_UI_WAITING | prato esperando salsicha (já existe em `Texts.Waiting`) | "Waiting for the grill" |

### 16.3 Dicas por gesto (substituem `Build.Texts.Hints`)

Mesmas chaves de `Content.Prep.Build.Texts.Hints`; a coluna "Antes" é o texto de hoje. Ficam na linha de dica durante o gesto.

| Id | Chave | Dica 3D | Antes |
|---|---|---|---|
| PREP3D_GST_SLICE | `slice` | "Drag the knife along the line" | igual |
| PREP3D_GST_SLICE_HOLD | `slice_hold` | "Hold the knife on the line" | "Hold on the line" |
| PREP3D_GST_PLACE | `place` | "Drag the frank into the bun" | "Drag the sausage into the bun" |
| PREP3D_GST_PLACE_HOLD | `place_hold` | "Hold where the frank goes" | "Hold where the sausage goes" |
| PREP3D_GST_TRACE | `trace` | "Trace the zig-zag" | igual |
| PREP3D_GST_TRACE_HOLD | `trace_hold` | "Hold to pour, let go at the mark" | "Hold to pour, release in the green" (só cor) |
| PREP3D_GST_SLIDE | `slide` | "Drag the slice onto the bun" | igual |
| PREP3D_GST_SLIDE_HOLD | `slide_hold` | "Hold where the slice goes" | igual |
| PREP3D_GST_TAPS | `taps` | "Tap each ring as it closes" | igual |
| PREP3D_GST_HOLD | `hold` | "Hold, let go at the ring" | "Hold, release in the green" (só cor) |
| PREP3D_GST_ADD | `add` | "Add a topping or press Next" | igual |
| PREP3D_GST_FLIP | grelha (`grill_flip`) | "Tap it when the ring closes" | "Flip when the ring glows" |
| PREP3D_GST_COLLECT | grelha (`Collect`) | "Tap it or drag it to the rail" | (novo) |

Textos soltos do Build que mudam de palavra (`Build.Texts`): `Sausage` "Sausage" -> "Frank"; `PlaceFirst` "Place the sausage first" -> **"Place the frank first"**; `Full` "Plate is full. Press Next" -> "3 toppings max. Press Next".

### 16.4 "Tap mode" e "Assist" (chips de 44 px, ao lado do Leave; `prep-3d.md` §5 item 6)

Leitura (Provisório; o frontend decide o comportamento exato): **Tap mode** = nenhum gesto exige arrastar; cada gesto vira "toque, toque"
(o `*_hold` atual é a base). **Assist** = alvos maiores, tolerância +30% (`Rules.Assist`) e guia sempre visível.

| Id | Elemento | Texto |
|---|---|---|
| PREP3D_UI_TAPMODE | rótulo do chip | "Tap mode" |
| PREP3D_UI_TAPMODE_TIP | tooltip | "Tap mode: tap, no dragging" |
| PREP3D_UI_TAPMODE_ON | toast ao ligar | "Tap mode on" |
| PREP3D_UI_TAPMODE_OFF | toast ao desligar | "Tap mode off" |
| PREP3D_UI_ASSIST | rótulo do chip (já existe em `Texts.Assist`) | "Assist" |
| PREP3D_UI_ASSIST_TIP | tooltip | "Assist: bigger targets, easier marks" |
| PREP3D_UI_ASSIST_ON | toast ao ligar | "Assist on" |
| PREP3D_UI_ASSIST_OFF | toast ao desligar | "Assist off" |

Dicas dos gestos com **Tap mode** ligado (sobrepõem a 16.3):

| Id | Gesto | Dica |
|---|---|---|
| PREP3D_TAP_SLICE | `slice` | "Tap the bun to cut" |
| PREP3D_TAP_PLACE | `place` | "Tap the frank, then the bun" |
| PREP3D_TAP_TRACE | `trace` | "Tap to pour, tap to stop" |
| PREP3D_TAP_SLIDE | `slide` | "Tap the slice, then the bun" |
| PREP3D_TAP_HOLD | `hold` | "Tap to start, tap to stop" |
| PREP3D_TAP_TAPS | `taps` | "Tap each ring as it closes" |
| PREP3D_TAP_PLATE | prato (lixeira ou janela) | "Tap the plate, then the spot" |

### 16.5 Recusas e toasts

Chaves que **já existem** em `Notices.luau` ou em §10 mantêm o texto (coluna "Existe"). Nenhuma recusa fala de "chance", "erro seu" ou
"errado": diz o que falta.

| Id | Situação (`Reason`) | Texto | Existe |
|---|---|---|---|
| PREP3D_REF_NOFRANKS | `NoStock`, caixa de franks vazia | "Out of franks! Restock it." | `out_of_stock` com `{item}` cobre; texto novo só se o dono quiser "frank" no toast |
| PREP3D_REF_NOBUNS | `NoStock`, caixa de pães vazia | "Out of buns! Restock it." | idem |
| PREP3D_REF_NOTOPPING | `NoStock`, topping | "Out of {item}! Restock it." | `out_of_stock` |
| PREP3D_REF_GRILL_FULL | grelha cheia | "The grill is full." | `grill_full` (§10.3) |
| PREP3D_REF_RAIL_FULL | trilho cheio (a pronta fica no rolete) | "The rail is full." | novo |
| PREP3D_REF_RAIL_EMPTY | `NoSausage` (nada pronto no trilho) | "No ready franks yet." | substitui `prep_no_sausage` "No sausage on the warmer yet." |
| PREP3D_REF_TOO_EARLY | virar antes da janela | "Not yet. Wait for the ring." | novo |
| PREP3D_REF_FLIPPED | virar duas vezes | "Already flipped." | novo |
| PREP3D_REF_TOO_FAST | `TooFast` | "Too fast! Try again." | `prep_too_fast` |
| PREP3D_REF_CUT_FIRST | encaixar sem cortar | "Cut the bun first" | novo |
| PREP3D_REF_PLACE_FIRST | topping sem salsicha | "Place the frank first" | substitui `Build.Texts.PlaceFirst` |
| PREP3D_REF_TOP_MAX | quarto topping | "3 toppings max!" | `topping_max` (§10.3) |
| PREP3D_REF_TOP_REPEAT | topping repetido | "It already has {item}." | `topping_repeat` (§10.3) |
| PREP3D_REF_ONE_TOOL | pegar 2ª ferramenta | "Put that tool down first" | novo |
| PREP3D_REF_HANDS | `HandsFull` | "Hands full" | `hands_full` |
| PREP3D_REF_BUSY | `Busy` | "Someone's already there." | `prep_busy` |
| PREP3D_REF_LOCKED | `Locked` | "Not right now." | `prep_locked` |
| PREP3D_REF_NOT_READY | Serve sem prato pronto | "Nothing to serve yet" | novo |
| PREP3D_REF_NO_TICKET | Serve sem ticket fixado | "Pin a ticket first" | novo |
| PREP3D_REF_CLOSED | `NotSelling` | "We are closed" | `Build.Texts.Closed` / `shop_closed` |
| PREP3D_REF_SHUTTER | janela fechada à noite | "The window's shut. Open it to serve." | `shutter_closed` (§10.1) |
| PREP3D_REF_SAVED | Leave com prato em curso | "Plate saved for 20 s" | `prep-ui-spec` §6.1 |
| PREP3D_REF_EXPIRED | prato expirou | "Plate expired" | `Build.Texts.Expired` |
| PREP3D_REF_TRASHED | lixeira, havia salsicha | "Plate trashed" | `prep-ui-spec` §6.5 |
| PREP3D_REF_KICKED | `Kick*` | "Prep interrupted." | `prep_kicked` |
| PREP3D_REF_IDLE | `KickIdle` | "Stepped away from the station." | `prep_idle` |
| PREP3D_REF_RETRY | `PrepFinish` recusado | "Pick the tab again to retry" | `Build.Texts.Retry` |

Palavra "sausage" nos toasts existentes (`prep_no_sausage`) é só texto, não voz; a proposta é trocar por "frank" para o vocabulário fechar.

### 16.6 Selos Perfect, Good, Messy (`Grades.Labels`, `prep-ui-spec` §7)

| Id | Elemento | Texto |
|---|---|---|
| PREP3D_SEAL_PERFECT | selo, forma estrela | "Perfect!" |
| PREP3D_SEAL_GOOD | selo, forma círculo-check | "Good" |
| PREP3D_SEAL_MESSY | selo, forma mancha | "Messy" |
| PREP3D_SEAL_TIP | gorjeta do Perfect (valor de `Effects.Perfect.Tip`) | "+${tip} tip" |

Motivo do Messy (uma linha pequena sob o selo, só da pior etapa; chave = `Tolerances.Key`; Provisório):

| Id | Etapa | Texto |
|---|---|---|
| PREP3D_SEAL_WHY_CUT | `bun_cut` | "The cut wandered" |
| PREP3D_SEAL_WHY_PLACE | `sausage_place` | "The frank sat off-center" |
| PREP3D_SEAL_WHY_SAUCE_LOW | molho, pouca cobertura | "Sauce missed the bun" |
| PREP3D_SEAL_WHY_SAUCE_HIGH | molho, excesso | "Too much sauce" |
| PREP3D_SEAL_WHY_CHEESE | `cheese` | "The cheese slid off-center" |
| PREP3D_SEAL_WHY_BACON | `bacon` | "Bacon timing was off" |
| PREP3D_SEAL_WHY_POTATO | `potato_sticks` | "The sticks piled wrong" |
| PREP3D_SEAL_WHY_FLIP | `grill_flip` | "Flipped too early or late" |

Selo de entrega (carimbo no ticket, forma diferente do selo de nota; `prep-3d.md` §3.5): "Complete" · "Incomplete" · "Wrong".

### 16.7 Tutorial do Day 1 adaptado ao fluxo 3D

Fluxo (`prep-3d.md` §3.0): phone -> open the trailer -> customer -> take order (**inalterados**, ver `script.md` §3) e depois
**Work na grelha -> pôr -> virar -> coletar -> aba Board -> pão -> corte -> salsicha no pão -> aba Toppings -> ketchup -> Next -> servir**;
depois `money`, `mart_*`, `restock` e a despedida (**inalterados**). `Pulse` = alvo 3D que o `World/Coach` pulsa (TASK-209).
Regras mantidas de `script.md` §3: <= 3 falas por passo, Walt curto, "Nothing extra" (DEC-072), pulável.

Convenções: **Say** = falas ao começar o passo · **Done** = elogio ao passar · **Remind** = lembrete após ocioso (`IDLE`).
**Áudio**: `E` = o texto exato já está em `tools/voice/lines.json` (conferido; há áudio pré-gerado em `Content.VoiceLines`);
`NOVA` = exige regeneração. Passos antigos que **somem** (`grill`, `slice`, `slicing`, `cooking`, `collect`, `assemble`,
`toppings`, `discard`) são substituídos pelos `p3_*`; os textos antigos viram falas sem uso (o áudio fica, não é apagado).

**Passos inalterados (só ganham `PrepHint` novo, sem fala nova):**

| Passo | Pulse | `PrepHint` (painel) |
|---|---|---|
| `phone`, `wait_call`, `open`, `wait_customer` | sem mudança | sem mudança |
| `order` | `Customer` em `Q1` (vista Window) ou botão Take do ticket | "Tap the customer or press Take." |

**Passos novos (3D):**

| Passo | Pulse | Fala | Id | Papel | Palavras | Áudio |
|---|---|---|---|---|---|---|
| `p3_work` | `Prompt_Work` da grelha | "Press Work at the grill." | PREP3D_V_WORK_S1 | Say | 5 | NOVA |
| | | "Hit Work by the grill." | PREP3D_V_WORK_R | Remind | 5 | NOVA |
| `p3_place` | caixa de franks, depois rolete livre | "Frank from the box." | PREP3D_V_PLACE_S1 | Say | 4 | NOVA |
| | | "Onto the grill." | PREP3D_V_PLACE_S2 | Say | 3 | E |
| | | "Nice." | PREP3D_V_PLACE_D | Done | 1 | E |
| | | "Drag a frank to a roller." | PREP3D_V_PLACE_R | Remind | 6 | NOVA |
| `p3_flip` | a salsicha e o anel | "Wait for the ring." | PREP3D_V_FLIP_S1 | Say | 4 | NOVA |
| | | "Tap it as it closes." | PREP3D_V_FLIP_S2 | Say | 5 | NOVA |
| | | "Perfect." | PREP3D_V_FLIP_D_PERFECT | Done (nota Perfect) | 1 | E |
| | | "Nice." | PREP3D_V_FLIP_D_GOOD | Done (nota Good) | 1 | E |
| | | "Bit late. Still fine." | PREP3D_V_FLIP_D_MESSY | Done (nota Messy) | 4 | NOVA |
| | | "Tap the glowing frank." | PREP3D_V_FLIP_R | Remind | 4 | NOVA |
| `p3_collect` | salsicha pronta, depois `Rail` | "Ready. Grab it." | PREP3D_V_COLLECT_S1 | Say | 3 | E |
| | | "Got it." | PREP3D_V_COLLECT_D | Done | 2 | E |
| | | "Tap it, or drag to the rail." | PREP3D_V_COLLECT_R | Remind | 6 | NOVA |
| `p3_board_tab` | aba Board | "Tap Board, down below." | PREP3D_V_BOARDTAB_S1 | Say | 4 | NOVA |
| | | "Board tab, down below." | PREP3D_V_BOARDTAB_R | Remind | 4 | NOVA |
| `p3_bun` | `BunCrate` | "Bun from the crate." | PREP3D_V_BUN_S1 | Say | 4 | NOVA |
| | | "Tap the bun crate." | PREP3D_V_BUN_R | Remind | 4 | NOVA |
| `p3_cut` | `Knife` e a guia de corte | "Drag the knife across." | PREP3D_V_CUT_S1 | Say | 4 | NOVA |
| | | "Good." | PREP3D_V_CUT_D | Done | 1 | E |
| | | "Knife along the line." | PREP3D_V_CUT_R | Remind | 4 | NOVA |
| `p3_assemble` | frente do `Rail`, depois vão do pão | "Frank in the bun." | PREP3D_V_ASM_S1 | Say | 4 | E |
| | | "Drag it from the rail." | PREP3D_V_ASM_S2 | Say | 5 | NOVA |
| | | "Beautiful." | PREP3D_V_ASM_D | Done | 1 | E |
| | | "Put it in the bun." | PREP3D_V_ASM_R | Remind | 5 | E |
| `p3_toppings_tab` | aba Toppings | "Now tap Toppings." | PREP3D_V_TOPTAB_S1 | Say | 3 | NOVA |
| | | "Toppings tab, down below." | PREP3D_V_TOPTAB_R | Remind | 4 | NOVA |
| `p3_ketchup` | tigela/garrafa de ketchup, depois o pão | "They want ketchup." | PREP3D_V_KET_S1 | Say | 3 | E |
| | | "Grab the bottle." | PREP3D_V_KET_S2 | Say | 3 | NOVA |
| | | "Nothing extra." | PREP3D_V_KET_S3 | Say | 2 | E |
| | | "Perfect." / "Nice." / "Bit late. Still fine." | PREP3D_V_KET_D_* | Done por nota (mesmas falas do `p3_flip`) | 1 a 4 | E / E / NOVA (já contada) |
| | | "Trace the squiggle on the bun." | PREP3D_V_KET_R | Remind | 6 | NOVA |
| `p3_next` | botão Next | "Press Next when it's done." | PREP3D_V_NEXT_S1 | Say | 5 | NOVA |
| | | "Press Next, Rookie." | PREP3D_V_NEXT_R | Remind | 3 | NOVA |
| `p3_discard` (se o prato não bater) | `Bin` | "Not what they asked. Toss it." | PREP3D_V_BIN_S1 | Say | 6 | E |
| | | "Drag it to the bin." | PREP3D_V_BIN_R | Remind | 5 | NOVA |
| `p3_serve` | prato, depois `Hatch` | "Now serve it." | PREP3D_V_SERVE_S1 | Say | 3 | E |
| | | "Plate to the window." | PREP3D_V_SERVE_S2 | Say | 4 | NOVA |
| | | "Hand it over." | PREP3D_V_SERVE_R | Remind | 3 | E |

**`PrepHint` (painel de apoio, texto, <= 36 caracteres por linha):**

| Id | Passo | Texto |
|---|---|---|
| PREP3D_PH_WORK | `p3_work` | 'Press "Work" at the grill.' |
| PREP3D_PH_PLACE | `p3_place` | "Drag a frank onto a roller." |
| PREP3D_PH_FLIP | `p3_flip` | "Tap it when the ring closes." |
| PREP3D_PH_COLLECT | `p3_collect` | "Tap the ready frank." |
| PREP3D_PH_BOARDTAB | `p3_board_tab` | "Tap the Board tab." |
| PREP3D_PH_BUN | `p3_bun` | "Tap the bun crate." |
| PREP3D_PH_CUT | `p3_cut` | "Drag the knife along the line." |
| PREP3D_PH_ASM | `p3_assemble` | "Drag the frank into the bun." |
| PREP3D_PH_TOPTAB | `p3_toppings_tab` | "Tap the Toppings tab." |
| PREP3D_PH_KETCHUP | `p3_ketchup` | "Pick the ketchup, trace the zig-zag." |
| PREP3D_PH_NEXT | `p3_next` | "Press Next." |
| PREP3D_PH_BIN | `p3_discard` | "Drag the plate to the bin." |
| PREP3D_PH_SERVE | `p3_serve` | "Drag the plate to the window." |

**`hint_*` do Walt depois da ação (`BossCalls`, `Trigger.Hint`; opcional, só se continuarem ativos no 3D).** As de §11.1 falam de "bar"
e de "Pop a sausage": ficam obsoletas no 3D. Substitutas propostas (texto da dica = fala, ≤ 6 palavras):

| Id | Gatilho | Fala | Áudio |
|---|---|---|---|
| PREP3D_V_HINT_GRILL | `grill_place` (substitui "When the bar fills up, grab it.") | "Watch for the ring." | NOVA |
| PREP3D_V_HINT_COLLECT | `grill_collect` (substitui "It waits on the warmer. Now slice a bun.") | "Now cut a bun." | NOVA |
| PREP3D_V_HINT_CUT | `bun_cut` (substitui "Pop a sausage in the bun.") | "Frank goes in the bun." | NOVA |

Pendência de coerência (não alterei §11.1 nem `script.md` §3: a TASK-213 só autoriza o `script.md` se a TASK-183 já fechou, e não confirmei):
`call_day_1` (§11.1) diz "Tap the sausage box" (palavra vetada na voz); `script.md` §3 e esta tabela devem ser conciliados pelo
secretário no fim da rodada.

### 16.8 O que a regeneração de voz precisa

- **Falas NOVAS que exigem áudio** (texto único, contadas uma vez): 24 do tutorial (`PREP3D_V_*` com "NOVA") + 3 de `hint_*` opcionais = **27**.
- **Falas `E` (já geradas)**: 14 textos únicos reaproveitados ("Onto the grill.", "Nice.", "Perfect.", "Ready. Grab it.", "Got it.",
  "Good.", "Frank in the bun.", "Beautiful.", "Put it in the bun.", "They want ketchup.", "Nothing extra.",
  "Not what they asked. Toss it.", "Now serve it.", "Hand it over."), mais as dos passos inalterados.
- **Falas que deixam de ser usadas** (áudio fica, sem apagar): "Frank from the cooler.", "Frank on the grill.", "Slice a bun while it cooks.",
  "Hold to slice the bun.", "Wait for the bar.", "Grab it off the grill.", "Ketchup. Hold to add.", "Toss it in the bin." (as 8 viram `p3_*` acima).
- Onde mora: as falas precisam estar em `Steps.luau` nos campos `Say`, `Done`, `Remind` (o `tools/voice/collect_lines.py` só lê esses campos, mais
  `GREETING`, `GOODBYE` e `SKIP_GOODBYE`). **A fala `Done` por nota** (Perfect, Good, Messy) precisa de campo que o coletor reconheça (por exemplo,
  três strings em `Say` de um passo-sombra) **ou** o coletor ganha o nome do campo novo; senão `Bit late. Still fine.` fica sem áudio e cai no
  `AudioTextToSpeech` (voz diferente da do Walt).
- Ordem do pipeline em `tools/voice/`: `collect_lines.py` (gera `lines.json`) -> `generate.py` (síntese) -> `upload.py` -> `build_content.py` (reescreve
  `src/Shared/Content/VoiceLines.luau`). Ordem de `generate`/`upload` inferida dos nomes; conferir o cabeçalho de cada script. Não gerei áudio.
- Todas as falas novas passam no filtro: sem "sausage", sem dígito, sem número de telefone, <= 6 palavras.
- Nada a regenerar para a despedida, saudação, `money`, `mart_*` e `restock`.
