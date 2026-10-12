Status: Rascunho

# Roteiro: cutscene, tutorial, ligações do chefe, queda e noite perdida

Autor: narrative-writer, 2026-10-08. Nada aqui é decisão.
Base: DEC-008, DEC-019, DEC-021 a DEC-025, DEC-028, DEC-036, DEC-037, DEC-047, DEC-048, DEC-050, DEC-051, DEC-053, DEC-060, DEC-065; rodadas 7–11: DEC-073 a DEC-078, DEC-081, DEC-084, DEC-086 a DEC-088, DEC-091 a DEC-095, DEC-097, DEC-098, DEC-100 a DEC-104; rodadas 12–15: DEC-106, DEC-110 a DEC-116, DEC-122 a DEC-124, DEC-129; rodadas 16–17: DEC-130 (sem semáforo; plano 4 e tutorial reescritos), rota trailer ↔ Mart cruza a Juniper Sul (resposta a `Q-128`, DEC a registrar); GDD V1 §8, §9.
Conciliado com `consistency-report.md` (2026-10-08, NW-4 a NW-13, NW-16, NW-20).
Falas em inglês (texto de jogo). Personagens em `characters.md`; regras das anomalias em `anomalies.md` (Aprovado); final em `ending.md` (Aprovado).

Formato das ligações (alinhado a FEAT-018, `design/features.md`):
- O **telefone fixo do veículo** (AST-042, mesma peça no carrinho e no trailer) toca **[DEC-124]**; `world.md` §4.1. Prompt **"Answer"**; qualquer jogador atende; atende sozinho depois de ~15 s.
- Viva-voz: a ligação toca para **todos** da party ao mesmo tempo (o chefe fala "you", serve para 1–4).
- Legenda na parte de baixo, **uma linha por vez**, avança **sozinha** (~2,5 s por linha, ritmo do servidor). **Sem avanço por toque, sem "Skip", sem replay, sem histórico** (DEC-077). Nome do falante: **"Walt"**.
- Áudio: murmúrio de voz de telefone (sem dublagem) + "heh" do chefe. Dublagem real fica para o áudio decidir.
- A última linha de cada ligação noturna é a **forma curta da regra** (`anomalies.md`): é o que o jogador deve guardar.

---

## 1. Cutscene de abertura (DEC-021, DEC-088) — party de 1–4

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

| Estágio | Frase-guia | Turnos |
|---|---|---|
| 1 | "Good job today!" | dias 1–2 |
| 2 | "You're doing great." | dias 3–5 |
| 3 | "Can you cover the night shift?" | ligação do trailer, noites 1–3, dias 6–8 |
| 4 | "There's something you should know..." | noites 4–6, dias 9–11 |
| 5 | "Whatever you do, never..." | noites 7–10, dias 12–14 |

Ordem da run (cenário L, DEC-057): dias 1–5 → noite 1 → dia 6 → noite 2 → … → dia 14 → noite 10.

## 3. Tutorial do dia 1 (Walt na linha)

Provisório (Q-193, 2026-10-11): o tutorial roda **sempre no dia 1 de toda run**, para todos, e **não é salvo** como concluído nem obrigatório (Skip vale só para a run). Passou do dia 1, não volta na mesma run.

O dia 1 começa com o telefone do carrinho tocando (plano 10 do §1). Isso ensina o prompt **"Answer"** logo de cara.
Walt atende e **fica na linha em viva-voz** durante o dia 1: cada dica sai pelo alto-falante do telefone, uma vez, quando a party chega àquele passo pela primeira vez. Sem painel, sem botão: a ação é sempre o prompt no mundo (DEC-015, DEC-066).

| Gatilho | Fala |
|---|---|
| "Answer" no telefone do carrinho | "Morning, Rookie! I'll stay on the line. Speaker's on." |
| perto da placa | "Flip the sign to OPEN when you're ready." |
| perto do estoque de salsicha | "Tap the sausage box. It goes right on the grill." |
| barra da grelha cheia | "Ready! Grab it. It goes on the warmer." |
| perto do pão | "Tap the buns. One gets sliced for you." |
| pão cortado | "Now pop a sausage in the bun." |
| primeiro cliente no balcão | "See the bubble? That's the order." |
| montando | "Add only what they asked for. Nothing extra." (DEC-072) |
| hot dog pronto | "Hand it over. Money goes in the drawer." |
| primeiro estoque abaixo de 25% | "Running low? The Mart's across the street." |
| primeira vez que alguém pisa na rua | "Look both ways! These drivers don't brake. Heh." |
| primeira volta do Mart com item na mão | "Careful crossing. Get hit, and you drop it." (DEC-103) |
| primeira entrada no Mart | "Gear's on the back wall. Sometimes there's something special." (DEC-106) |
| primeira saída da zona do carrinho | "Don't leave the cart alone too long." |
| primeiro atropelamento (qualquer jogador) | "Ooh. You okay? Dust off. Grab your stuff." |
| 6:00 PM | "Flip the sign to CLOSED. Finish the line." |
| resumo do dia 1 | "Good job today! See you at seven." |

## 4. Ligações de dia (7:00 AM)

### 4.1 Dias 1–5

| Dia | Abertura | Fim do turno (resumo) |
|---|---|---|
| 1 | tutorial (§3) | "Good job today! See you at seven." |
| 2 | "Morning! Cheese came in. Folks love cheese." / "Oh — keep an eye on your cash drawer." / "Some folks have quick hands. Stay close to the cart." | "Good job today! Two for two." |
| 3 | "Bacon day! Smell that? That's the smell of money." / "You're doing great, Rookie. Really." | "You're doing great. Same time tomorrow?" |
| 4 | "New stuff: potato sticks. Crunchy. Kids love 'em." / "Bigger grill on the Mart's back wall. Just saying." / "See that old trailer in the lot? Not yet. Heh." | "You're doing great. Tomorrow's a big day." |
| 5 | "Big day, Rookie. That old trailer in the lot?" / "It's for sale. Buy it with the shop money." / "Don't ask how that works. Just trust me." / "She's been waiting for the right person a long time." | ver §4.2 |

Pista leve, a partir do dia 3, só se o ladrão foi pego no dia anterior (substitui a 2ª linha): "Heard you caught Quentin in the act. Nice." (Walt não estava lá.)

### 4.2 Trailer (fim do dia 5 ou do dia em que for comprado — DEC-047, DEC-086)

Comprou (fade + ligação no telefone do carrinho, a última dele; próximo turno = noite 1, trailer já na esquina):

1. Walt: "You bought the old girl! She looks good on you."
2. Walt: "She'll be on the corner tonight. Cart gets a rest."
3. Walt: "Listen... I need someone on nights."
4. Walt: "Can you cover the night shift? Starts at eight."
5. Walt: "There are a few... house rules. Nothing big."
6. Walt: "I'll call the trailer at eight. Get some rest."

Não comprou (DEC-028 — notificação, não tutorial; texto em `ui-text.md`). Fala do resumo: "No trailer yet? That's okay. She'll wait."

### 4.3 Modo dia infinito (DEC-028, DEC-058)

Uma fala sorteada por manhã, sem repetir duas seguidas:
"Another day, another dog." · "Proud of you, Rookie. Really." · "Grill's hot. Let's go." · "The trailer's still there. Just saying." · "Nice and normal. Just how I like it." · "Peek at the Mart's glass case. Sometimes there's a surprise."

"Day 100" (DEC-084) soma dias de modo infinito **por jogador, entre sessões**: cada jogador da party pode chegar ao 100 num dia diferente. Por isso **não tem ligação do Walt**; é só notificação pessoal + badge (`ui-text.md` §6, §9).

### 4.4 Dias 6–14 (entre as noites)

Uma linha de trabalho + uma linha de pista. As pistas criam perguntas, não respondem (DEC-008). Telefone de parede do trailer.

| Dia | Depois da | Abertura |
|---|---|---|
| 6 | noite 1 | "Morning! You made it. Told you nights were quiet." / "Cream cheese came in. Fancy." |
| 7 | noite 2 | "Morning, Rookie. Sleep okay?" / "Good. Don't think about it too hard." |
| 8 | noite 3 | "Bank clock's ticking fine today. See?" / "Nice and normal. Sell some dogs." |
| 9 | noite 4 | "Just one Mr. Pickett today, I hope. Heh." / "...That was a joke. Mostly." |
| 10 | noite 5 | "She liked you. The lady. I can tell." / "Forget I said that. Grill's waiting." |
| 11 | noite 6 | "Ever notice nobody lives upstairs? In the daytime, I mean." / "Huh. Next question." |
| 12 | noite 7 | "You kept your eyes down. Good." / "I used to count the lamps. It helps." |
| 13 | noite 8 | "Long night, huh? Coffee's on me." / "Tell Opal it's for Walt. She knows." |
| 14 | noite 9 | "Rookie. About the knocking." / "That wasn't me. I need you to believe that." / "Tonight's the last one. Then you get answers. I promise." |

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

### Noite 1 — ANM-001 The blank folks (estágio 3)

1. "Evening, Rookie. First night. Nights are... quieter."
2. "Some customers might look a little off."
3. "If someone walks up with no face — no eyes, no mouth — don't serve them."
4. "Just refuse. They'll wander off."
5. "That's it. Keep the grill hot. See you at six."
6. **"No face? Refuse them."**

### Noite 2 — ANM-002 The wrong food

1. "Night two. You did fine last night."
2. "Check your food before it goes out."
3. "A gray sausage, or a bun with a bite in it you didn't take —"
4. "toss it. Trash can. Don't serve it."
5. "And still no faces. Remember faces."
6. **"Wrong food? Throw it away."**

### Noite 3 — ANM-003 The stopped clock

1. "Evening. Can you see the bank clock from there?"
2. "Keep an eye on it. And an ear. It ticks."
3. "If it stops, flip the trailer lights off. Count to five. Then back on."
4. "That gets it going again. Don't leave it stuck."
5. "Trust me on this one."
6. **"Clock stops? Lights off, count five, lights on."**

### Noite 4 — ANM-004 The copies (estágio 4)

1. "Rookie... there's something you should know."
2. "Sometimes a customer shows up twice. Same face, same clothes."
3. "One of them is a copy. The copy is backwards."
4. "Look at their shirt. Their watch. Backwards."
5. "Refuse the backwards one. Serve the real one."
6. "Who are they? ...Next question."
7. **"Two of them? Refuse the backwards one."**

### Noite 5 — ANM-005 The Raincoat Lady

1. "Tonight, a lady in a yellow raincoat might come by."
2. "It won't be raining. She'll be dripping anyway."
3. "Serve her. Always. Whatever she asks for."
4. "Don't refuse her. Don't make her wait."
5. "She's a... very old customer. Be nice."
6. **"Yellow raincoat? Always serve her."**

### Noite 6 — ANM-006 The wavers

1. "Evening. Folks upstairs might wave at you tonight."
2. "Don't wave back. Don't even look up."
3. "They just want someone to notice them."
4. "Eyes on your grill. They'll get bored."
5. "I know. I know. I'll explain someday."
6. **"Someone waving upstairs? Don't look up."**

### Noite 7 — ANM-007 The Walker (estágio 5, regra crítica)

1. "Rookie. Listen close. This one matters most."
2. "Down Juniper Street, someone walks toward the trailer."
3. "Every time you look at them, they get closer."
4. "Whatever you do, never let them reach your light."
5. "Don't watch the Walker. Not for a second."
6. † "When the far lamp buzzes, they're there. Tell your crew."
7. **"Whatever you do, never watch the Walker."**

A linha 6 apoia o sinal de início decidido em DEC-123 (§5.12).

### Noite 8 — ANM-008 The long car

1. "Evening. You're doing better than I ever did."
2. "If a long car parks across the street with its lights on you —"
3. "close the service window. Stay inside."
4. "Don't open it till you hear it drive away."
5. "Can't serve with it shut. Folks will wait."
6. † "Regular cars never stop there. That one does."
7. "And never watch the Walker."
8. **"Long car? Close the window. Keep it shut."**

DEC-221 (Provisório): linhas 3–5 e a forma curta trocadas (era "get down behind the counter. Stay down." / "Wait till
you hear it drive away." / "Long car's lights on you? Hide."). "Close the window" repete o prompt "Close Window".
A linha 6 apoia a proposta para `Q-103` (`world.md` §3.2: red curb "NO PARKING", rua esvazia).

### Noite 9 — ANM-009 The knock

1. "One more thing. This is important."
2. "I never come to the trailer at night. Never."
3. "If someone knocks on the back door and says it's me —"
4. "it isn't. Close the window. Stay inside."
5. "Keep it shut till the knocking stops."
6. "...I'm sorry I didn't tell you sooner."
7. "And never watch the Walker."
8. **"Knocking? It's not me. Close the window."**

DEC-221 (Provisório): linhas 4–5 e a forma curta trocadas (era "it isn't. Get down. Stay quiet till it stops." /
"Knock at the back? It's not me. Hide.").

### Noite 10 — ANM-010 The Hush (final)

1. "Last night, Rookie. Ten. Nobody's made it to ten since... well."
2. "Tonight the street might go dark. Lamp by lamp."
3. "When the lamps start going out, leave the trailer."
4. "Go to the Mart. Stand under the OPEN sign. It never goes out."
5. "Come back when the lamps come back."
6. "And never watch the Walker. See you at sunrise. I promise."
7. **"Lamps going out? Go to the Mart sign."**

(Linha 1 encurtada para caber no mobile; o "A long time." saiu.)

### 5.11 Versão curta (noite repetida)

1. "Same night, Rookie. Same rules. You know them."
2. (forma curta da regra nova da noite)
3. (noites 7–10) "And never watch the Walker."

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
