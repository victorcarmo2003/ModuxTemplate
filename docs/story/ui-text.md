Status: Rascunho

# Textos de UI, prompts, placas e nomes

Autor: narrative-writer, 2026-10-08. Nada aqui é decisão. Texto de jogo em inglês (DEC-022).
Limites: prompt **até ~16 caracteres** (alvo mobile, DEC-014); notificação **uma linha**; nada de parede de texto.
Valores entre chaves são variáveis: `{n}`, `{price}`, `{item}`, `{name}`.
Sem XP, sem nível (DEC-081): nenhum texto de UI fala em XP, "level up" ou rank.
Conciliado com DEC-106, DEC-110 a DEC-116, DEC-124, DEC-129 e `consistency-report.md` (2026-10-08, NW-14, NW-16 a NW-23).

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
| Prateleira do Mart | "Buy {item} ({price})" |
| Bancada "GEAR WALL" (Mart, DEC-101), posições básicas B1–B5 (sempre à venda, DEC-106) | "Buy {upgrade} ({price})" (mostra o próximo nível) · nível máximo: etiqueta "MAX", sem prompt (igual a FEAT-015) |
| Bancada, vitrine especial S1 (DEC-106), com o Rescue Whistle | "Buy Whistle ({price})" · vazia: etiqueta "Nothing special today" (FEAT-015) |
| Estação, com pacote na mão | "Restock" |
| Lixeira | "Throw Away" |
| Interruptor | "Lights" |
| Balcão (noite) | "Hide" · "Get Up" |
| Cafeteira | "Brew Coffee" |
| Tool Coffee | "Drink" |
| Tool Rescue Whistle (uso por colega depende de `Q-120` f) | na mão de um colega de pé: "Revive {name}" · na hotbar: "Blow Whistle" |
| Trailer no lote | "Buy Trailer ({price})" |

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
| Pacotes do Mart | "Sausages ×8", "Buns ×8", "Ketchup ×20", "Mustard ×20", "Cheese ×6", "Bacon ×6", "Potato Sticks ×10", "Cream Cheese ×8", "Coffee ×10" | quantidades de DEC-049 e DEC-071 |

## 4. Placas e letreiros (assets com texto)

| Asset | Texto |
|---|---|
| Placa do carrinho/trailer | "OPEN" / "CLOSED" |
| Trailer no lote | "Available on Day 5" (DEC-047) |
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
| Medidor (só à noite) | "{meter}" (§1) |

## 6. Notificações (canto superior direito, uma linha)

| Evento | Texto |
|---|---|
| Trailer disponível, não comprado (DEC-028) | "The old trailer is for sale! Check the parking lot." |
| Lembrete nos dias seguintes | "The trailer is still waiting in the lot." |
| Trailer comprado (DEC-086) | "The trailer takes the corner next shift!" |
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
