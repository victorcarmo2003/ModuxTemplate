# Walt — roteiro para o ElevenLabs (2026-10-23)

**Persona:** Walt, dono do ponto há 40 anos. Voz grave, calma, confiante demais. Fala do horror como quem fala do tempo:
explica tudo com uma desculpa banal, ri baixo nas horas erradas, nunca levanta a voz (só no rádio, no fim). Psicopata
gentil: carinhoso com o Rookie, frio com o resto. **A regra sempre fica clara no fim da fala**, mesmo quando ele inventa
desculpa.

**Como usar**
- Cada bloco = 1 arquivo. Cole só o texto do campo **ElevenLabs** (com as tags entre colchetes).
- Salve com o **ID** como nome, sem espaço: `v_643427f920.mp3`, em `Assets/new_voice/<pasta do dia>/`.
- A **legenda não muda** (o jogo acha o áudio pela legenda). O Walt pode falar diferente dela à vontade.
- `[whisper]` (dono, 2026-10-23): o Walt sussurra a ordem ou a regra no fim da fala, como no "Pull it". Não entra nas
  falas alegres nem no rádio (lá ele grita).
- Duração: tutorial ≤ 5 s por fala (o passo espera o Walt terminar); ligações da noite ≤ 12 s por fala.
- Depois me chama: eu importo, aplico o filtro de telefone (só nas falas de telefone), subo e monto o catálogo.
- ✅ = já gravado (está em `Assets/new_voice`), ⏳ = falta gravar.
- Progresso: **47 de 121** gravados.
- ~~Ordem do jogo: o Dia 1 não tem noite. A Noite k acontece no fim do Dia k + 1.~~
- **Ordem do jogo (DEC-360, dono 2026-10-23): a run é 100% noite e começa de noite.** Não existe turno de dia nem ligação
  da manhã. O "Dia 1" deste roteiro é a **Noite 1** (tutorial dentro dela; lição de upgrade às 6 AM depois dela). A única
  ligação de cada turno é a da noite, às 7 PM. Os títulos "Dia k + Noite k−1" abaixo ficam só para achar as pastas.
- **MORTA — SEM DIA** = a fala nunca toca. **Não gravar** (as já gravadas ficam guardadas). "Destino proposto" é
  **Provisório** (`Q-485`, `docs/story/walt-dialogue-audit.md` §3.3): virar a 1ª linha (abertura) da ligação da noite
  indicada, sem "Morning" (o Call é às 7 PM). Destino "nenhum" = sabor que pode sair.
- Também não gravar ainda: noite repetida / noite perdida (`Chances = 0`, `Q-479`), "That's two, Rookie." (`Q-479`),
  "Morning, Marigold." (fora do final, DEC-363), o rádio do Mart, e os textos com correção pendente (`Q-484`).
- **DEC-362:** cada ligação da noite abre com uma pista da lore, crescendo noite a noite. Texto das 10 aberturas
  (Provisório, TASK-655) em "PRONTAS PARA GRAVAR" → "Aberturas"; as manhãs mortas dizem se foram reaproveitadas.
- **DEC-363:** o final é "O Segundo Café": as 9 falas A1 ficam (isca) e entram 3 falas novas (seção do final).
- **DEC-365:** entram a ligação de reclamação da Raincoat Lady e a regra da janela com o custo (seção própria).

---

## PRONTAS PARA GRAVAR — lote de 2026-10-23 (DEC-365 a DEC-369; textos do narrative-writer)

Gravar com o **id novo** que a pipeline gera da legenda (legenda nova = id novo). Onde a legenda não mudou, o id é o antigo.
A coluna "substitui" diz qual entrada antiga sai (fica no roteiro marcada SUBSTITUÍDA). `[whisper]` sempre antes da regra.

### `dia_01/` — Noite 1, tutorial e lição de upgrade

✅→⏳ **(id novo)** · substitui v_8df981736c · lembrete da lição de upgrade (6 AM) · Legenda: Six A.M. Shift's over. Gear Stand, in the back. Find something useful.
- ElevenLabs: `[pleased] Six A.M. Shift's over, Rookie. [whisper] Gear Stand. In the back. Find something useful.`

✅→⏳ **(id novo)** · substitui v_4d28b6c67f · dica (só sem tutorial) · Legenda: Hot dog's ready. Hand it to the customer.
- ElevenLabs: `[calm] That one's done. [whisper] Hand it to the customer.`

### `dia_02/` — ligação da Noite 1

Nota: a N1 fica com 5 linhas (abertura + disjuntor ×2 + sem rosto + janela). Conferir no Play o limite de 45 s; se passar, cortar a B1b.

⏳ **(id novo)** · N1 · disjuntor (DEC-367) · Legenda: Power trips? Breaker's outside. Hold it till the lights come back.
- ElevenLabs: `[calm] Old wiring. Power trips now and then. [pause] Breaker's out back. [whisper] Go out. Hold it till the lights come back.`

⏳ **(id novo)** · substitui v_8c48d35c08 · N1 · Legenda: Only go out for the breaker. Then come right back in.
- ElevenLabs: `[easy] And Rookie... [pause] outside's for the breaker. Nothing else. [whisper] Do your job. Come right back in.`

⏳ **(id novo)** · N1 · janela com o custo (DEC-365) · Legenda: Something wrong at the window? Shut it. They'll go. So does the money.
- ElevenLabs: `[calm] Something looks wrong at the window? [whisper] Shut it. They'll go. [chuckles softly] Heh. So does their money, mind you.`

⏳ **(id novo)** · substitui v_0b0655a682 · N1 (regra, escreve o papel; última linha) · Legenda: No face? Blank ticket? Don't cook it. He leaves on his own.
- ElevenLabs: `[calm] Some folks come in with no face. Shy, I guess. [pause] Ticket comes up blank. [whisper] Don't cook it. He'll leave on his own.`

### `dia_03/` — ligação da Noite 2

⏳ **(id novo)** · substitui v_3c75317b9b · N2 · o que treme · Legenda: Shaky one's just hungry. Plain bun and sausage. Nothing on it.
- ElevenLabs: `[warm] If one's shaking, he's just hungry. Cold out there. [pause] Bun, sausage. [whisper] Nothing on it.`

### `dia_04/` — ligação da Noite 3

⏳ **(id novo)** · substitui v_05009b919e · N3 · apagão · Legenda: Lights out? Breaker's outside. Hold it till they come back.
- ElevenLabs: `[calm] Lights might go out again tonight. Storm season. [pause] Breaker's outside. [whisper] Hold it. Till they come back.`

### `dia_08/` — ligação da Noite 7

⏳ **(id novo)** · substitui v_3c84ea3eda (e v_aaaf538e6f) · N7 · o barulho no chão · Legenda: Scratching under the floor? Up on the counter till it passes.
- ElevenLabs: `[calm] We got rats under the floorboards. Big ones. [chuckles softly] Heh. You hear scratching... [whisper] get off the floor. Up on the counter till it passes.`

⏳ **(id novo)** · N7 · o que flutua (DEC-367) · Legenda: Feet not touching the floor? Don't serve yet. Wait for the thud.
- ElevenLabs: `[calm] Some fellas come in light on their feet. Real light. [chuckles softly] Heh. Don't serve him floating. [whisper] Wait for the thud.`

### `dia_09/` — ligação da Noite 8

⏳ **(id novo)** · N8 · ANM-022, 2ª regra (DEC-366) · Legenda: Banging his head on the glass? Window won't stop him. Shop light off.
- ElevenLabs: `[calm] Fella might knock his head on the glass tonight. [chuckles softly] Heh. Thick skull, that one. [pause] Shutting the window won't send him off. [low] [whisper] Shop light off. Then he goes.`
- Papel (sem áudio): `Head on the glass? Window won't help. SHOP LIGHT OFF.` · Sussurro: `SHOP LIGHT OFF` / `WINDOW WON'T STOP HIM. LIGHT OFF.` / `light off...`, `lights off, Rookie...`, `the glass won't stop him...`, `turn it off...`

### `dia_10/` — ligação da Noite 9

⏳ **(id novo)** · N9 · o que encara (DEC-367) · Legenda: Never blinks? Serve him like normal. Just don't stare back.
- ElevenLabs: `[calm] One regular, he doesn't blink. Dry eyes, I figure. [pause] Serve him like anyone else. [whisper] Just don't stare back.`

### `dia_11/` — Noite 10 e final

⏳ **(id novo)** · substitui v_37eb690baf · N10 · Hush · Legenda: Lamps going out outside? Shop light off.
- ElevenLabs: `[calm] If the street lamps start going out... [pause] power company, heh. [whisper] Shop light off.`

⏳ **v_a5a48fc8ed** (legenda igual) · N10 · Legenda: Keep it off till they're back.
- ElevenLabs: `[low] And keep it off. [whisper] Till the lamps are back.`

⏳ **(id novo)** · N10 · o das câmeras (DEC-367) · Legenda: Looks normal? Check the cameras. Wrong on camera, don't cook it.
- ElevenLabs: `[calm] Cameras are old. Sometimes they show a fella... different. [chuckles softly] Heh. Bad lens, probably. [pause] Check them. [whisper] Wrong on camera? Don't cook his order.`

⏳ **(id novo)** · substitui v_d9a7a5ee99 e v_86b4351c71 · rádio N10 (grita, sem whisper) · Legenda: The lamps are going out! Lights off in there, NOW!
- ElevenLabs: `[urgent, shouting] Rookie! The lamps are going out! Lights off in there! NOW!`

⏳ **(id novo)** · substitui v_b85c836266 · final, fala 2 (DEC-369) · Legenda: I watched every one. From across the street. Best seat in town.
- ElevenLabs: `[warm, slow] I watched every one, Rookie. [pause] From across the street. [chuckles softly] Best seat in town.`

### `qualquer_dia/`

⏳ **(id novo)** · substitui v_d91e854ce1 · fim da run (tela final) · Legenda: That's it, Rookie.
- ElevenLabs: `[calm, low] Well. [pause] That's it, Rookie. [chuckles softly] Heh.`

⏳ **(id novo)** · reclamação da Raincoat Lady (DEC-365) · Legenda: You shut her out, Rookie. You might regret that.
- ElevenLabs: `[disappointed, calm] You shut the window on her, Rookie. [pause] She just wanted a dog. [low] [whisper] You might regret that.`

Também prontas (DEC-363, seção do final): as 3 falas do Segundo Café.

### Aberturas da ligação da noite N1–N10 (DEC-362, TASK-655) · **Provisórias**

Linha 1 de cada `call_night_k` (a regra vem depois). Uma linha por noite, **≤ 6 s** com as pausas (medir no Play; se passar,
tirar a tag `[pause]`, nunca a frase). Sem "Morning" (a ligação é às 7 PM). Sem regra: o `[whisper]` cai no **fecho** da
abertura. Cada uma reage à noite anterior e solta 1 peça da lore, sem revelar peça de noite seguinte
(`docs/story/walt-calls-lore.md` §4.2). Fio do café: N1 (ligação do café) → N4 → N9 → N10.

⏳ **v_6ea4e48840** (legenda igual) · `dia_02/` · abertura N1 · Legenda: Evening, Rookie. Some customers look off.
- ElevenLabs: `[calm, deep] Evening, Rookie. [pause] Some customers look a little off. [whisper] Nothing to worry about.`
- Texto do ElevenLabs encurtado para caber em 6 s (a N1 já tem 5 linhas). Nenhuma manhã morta reaproveitada.

⏳ **(id novo)** · `dia_03/` · abertura N2 · reaproveita ✅ v_146c67bf64 (sem "Morning!") · Legenda: You came back. Told you nights were quiet.
- ElevenLabs: `[bright, a little too bright] You came back, Rookie. [chuckles] [whisper] Told you the nights were quiet.`

⏳ **(id novo)** · `dia_04/` · abertura N3 · reaproveita ✅ v_3153f74405 + ✅ v_9f14feee91 (numa fala só, sem "Morning") · Legenda: Sleep okay? Good. Don't think about it.
- ElevenLabs: `[warm] Sleep okay, Rookie? [pause] [flat, quick] Good. [whisper] Don't think about it.`

⏳ **(id novo)** · `dia_05/` · abertura N4 (1ª noite da skin cansada, DEC-370) · reaproveita "Coffee's on me" de v_0eec32dec6 · Legenda: You look tired, Rookie. Coffee's on me tonight.
- ElevenLabs: `[warm, a little too warm] You look tired, Rookie. [pause] [whisper] Coffee's on me tonight.`

⏳ **(id novo)** · `dia_06/` · abertura N5 · reaproveita v_1ae72da760 + v_6643e2a67d (sem o nome Pickett, que o jogador não conhece; eco das cópias da N3) · Legenda: Just one of everybody tonight, I hope. Joke. Mostly.
- ElevenLabs: `[dry] Just one of everybody tonight, I hope. [chuckles] Joke. [pause, flat] [whisper] Mostly.`

⏳ **(id novo)** · `dia_07/` · abertura N6 (depois da Raincoat Lady da N5) · reaproveita v_f36e086018 + v_2825918158 (numa fala só) · Legenda: She liked you. The lady. Forget I said that.
- ElevenLabs: `[softly] She liked you, you know. The lady. [pause] [whisper] Forget I said that.`

⏳ **(id novo)** · `dia_08/` · abertura N7 (1ª noite da skin da noite, DEC-370) · nova (as manhãs "nobody lives upstairs" ficam sem destino: o restaurante não tem andar de cima) · Legenda: You're starting to look the part, Rookie.
- ElevenLabs: `[low, pleased] Well, look at you, Rookie. [pause] [whisper] Starting to look the part.`

⏳ **(id novo)** · `dia_09/` · abertura N8 · reaproveita v_79fe1b45ba + v_b938f43cf2 ("I counted the lamps" → "I used to count the lamps": ele já fez as noites) · Legenda: You kept your eyes down. Good. I used to count the lamps.
- ElevenLabs: `[approving, low] You kept your eyes down. Good. [pause, distant] [whisper] I used to count the lamps.`
- A mais longa das dez: conferir os 6 s; se passar, cortar "Good." do ElevenLabs (a legenda fica).

⏳ **(id novo)** · `dia_10/` · abertura N9 · reaproveita v_0eec32dec6 ("Long night, huh?"; sem Opal, que não está no restaurante) · Legenda: Long night, huh? I'm saving you a coffee.
- ElevenLabs: `[warm] Long night, huh? [chuckles softly] [whisper] I'm saving you a coffee.`

⏳ **(id novo)** · `dia_11/` · abertura N10 · substitui v_140f750fc0 ("Last night, Rookie.") · Legenda: Last night, Rookie. I'll bring the coffee myself.
- ElevenLabs: `[warm, slow] Last night, Rookie. [pause] [whisper] I'll bring the coffee myself.`
- Ecoa o `fake_call` da N10 ("Almost morning. I'll bring the coffee myself."): de propósito, quem ouviu os dois confirma.

Manhãs mortas **sem** destino depois desta rodada (seguem guardadas, não gravar): v_444b37b9a8 (relógio do banco), v_ec32a5c044 /
v_accbaddd4a / v_e07ecc1b65 (andar de cima), v_4550eb2216 (Opal), v_9a2f7f9949 / v_319d2c7703 / v_909f41e668 (a batida e a
promessa; a peça "it's not me" já está na regra da N2 e no rádio).

### `noite_reacoes/` — o Walt sem telefone (DEC-372) · **SEM FILTRO DE TELEFONE**

Tocam no meio da noite, **sem o telefone tocar e sem ninguém atender**, só na **1ª vez** de cada gatilho na run, **no máximo 2 por noite**, nunca durante uma anomalia. Voz perto, íntima, crua (não passar no filtro de telefone). Nunca explicar ao jogador. Gravar a **principal**; a alternativa fica de reserva (gravar se sobrar tempo). Gatilhos e textos Provisórios (narrative-writer, 2026-10-23).

| # | Gatilho (1ª vez na run) | Principal (Legenda · ElevenLabs) | Alternativa (Legenda · ElevenLabs) |
|---|---|---|---|
| R1 | disjuntor religado | Lights back. Steady hands. · `[low, close] Lights back. [pause] Steady hands. [chuckles softly] Heh.` | There. Much better. Heh. · `[calm, low] There. [pause] Much better. [chuckles softly] Heh.` |
| R2 | um jogador sai para a rua à noite | Chilly out there, isn't it? · `[low, amused] Chilly out there, [pause] isn't it?` | Nice night for a walk. · `[close, intimate] Nice night [pause] for a walk. [chuckles softly]` |
| R3 | anomalia-cliente despachada pela janela (não a Raincoat Lady: ela tem a ligação própria) | That one cost you. Worth it. · `[low] That one cost you. [pause] [chuckles softly] Worth it.` | Money walks. Smart choice. · `[calm] Money walks. [pause] [low] Smart choice.` |
| R4 | anomalia-cliente atendida certo | I saw that. Well done. · `[close, intimate] I saw that. [pause] [low] Well done.` | By the book. I like that. · `[low, pleased] By the book. [pause] I like that. [chuckles softly]` |
| R5 | susto por regra errada com cliente estranho | Heh. Rules matter, kid. · `[chuckles softly] Heh. [pause] [whisper] Rules matter, kid.` | I saw that. Breathe. · `[low, close] I saw that. [pause] [whisper] Breathe.` |
| R6 | jogador encara o Walt sombrio do estacionamento ou chega perto e ele some | Best seat in town. · `[close, intimate] [whisper] Best seat [pause] in town.` | Don't stare, kid. Heh. · `[whisper] Don't stare, kid. [pause] [chuckles softly] Heh.` |
| R7 | 1º café na máquina | Good coffee. My recipe. · `[low, warm] Good coffee. [pause] My recipe.` | Stay awake for me. · `[close, intimate] Stay awake [pause] for me. [chuckles softly]` |
| R8 | 1ª leitura do papel de dicas | I wrote those. Read slowly. · `[low] I wrote those. [pause] [whisper] Read slowly.` | Good. Paper never lies. · `[calm] Good. [pause] [low] Paper never lies.` |
| R9 | porta dos fundos trancada a tempo na batida | Just in time. Heh. · `[low, close] Just in time. [pause] [chuckles softly] Heh.` | Locked. Good. I heard. · `[whisper] Locked. [pause] Good. [pause] [low] I heard.` |
| R10 | luz da loja apagada e o que bate a cabeça vai embora | Dark works too. Clever. · `[low, amused] Dark works too. [pause] Clever.` | He'll find another door. · `[close, intimate] He'll find [pause] another door. [chuckles softly]` |

Ids: todos novos (a pipeline gera da legenda). Nenhuma usa palavra proibida; nenhuma cria regra.

---

## Dia 1 — primeiro dia (tutorial, sem noite) · `dia_01/` · 38/44

### Manhã: ligação do dia — MORTA — SEM DIA (DEC-360). Destino proposto: nenhum (o tutorial da Noite 1 já cobre)

✅ **v_6a998d7bee** · **MORTA — SEM DIA** · destino: nenhum · Legenda: Morning, Rookie! I'm on the line.
- ElevenLabs: `[cheerful, too calm] Morning, Rookie. It's Walt. I'm on the line.`

✅ **v_e06f57adaa** · **MORTA — SEM DIA** · destino: nenhum ("frank box" não existe mais) · Legenda: Tap the frank box. Grill it.
- ElevenLabs: `[calm] Tap the frank box. Grill it.`

✅ **v_f2bed86855** · **MORTA — SEM DIA** · destino: nenhum · Legenda: Open up when ready.
- ElevenLabs: `[easy] Open up whenever you're ready.`

### Tutorial do 1º hot dog (só o Rookie ouve, na ordem dos passos)

✅ **v_643427f920** · atendeu o telefone (saudação)
- Legenda: Hello, Rookie! My name is Walt. I've noticed that you're new here, so I'm gonna walk you through this.
- ElevenLabs: `[warm, slow] Well, hello there, Rookie. [pause] Name's Walt. This is my corner. [chuckles softly] You're new. I can always tell. [confident] Don't worry. I'm gonna walk you through every little thing.`

✅ **v_07f1b13880** · logo depois, seta na alavanca
- Legenda: Do you see that lever? Go there and pull it to open the store.
- ElevenLabs: `[calm] See that lever by the window? [pause] Go on. [whisper] Pull it. [confident] That's how we open the store.`

✅ **v_e17886c499** · lembrete da alavanca (também no fim da lição de upgrade)
- Legenda: Pull the window lever.
- ElevenLabs: `[patient] The lever, Rookie... [low] [whisper] Pull it!`

✅ **v_98dcdc1f92** · puxou a alavanca, cliente chegando
- Legenda: Nice. Here it comes, your first client.
- ElevenLabs: `[pleased] There we go. [leaning in] And here comes your very first customer. [chuckles] Look at him. Hungry.`

✅ **v_9ffa48f04a** · cliente no tablet
- Legenda: Take his order.
- ElevenLabs: `[calm] Go on. [whisper] Take his order.`

✅ **v_808accb026** · parado no tablet (lembrete)
- Legenda: What are you doing? I don't have the whole night. Take his order.
- ElevenLabs: `[flat, unamused] What are you doing? [pause] I don't have all night, Rookie. [cold] [whisper] Take. His. Order.`

✅ **v_e959ad766d** · ouviu o 1º pedido
- Legenda: Plain dog. Go to the grill.
- ElevenLabs: `[confident] A plain dog. Simple man. [chuckles] Go to the grill.`

✅ **v_5134581f2b** · na grelha
- Legenda: Take the sausage from the cooler.
- ElevenLabs: `[calm] Grab a sausage from the cooler. Put it on the grill.`

✅ **v_52aa709d1f** · hora de virar
- Legenda: Now flip it.
- ElevenLabs: `[sharp, quiet] Now. [whisper] Flip it.`

✅ **v_1af4e68b2e** · elogio curto (virar, cortar, pão no prato)
- Legenda: Good.
- ElevenLabs: `[satisfied, low] Good.`

✅ **v_e9e95cf807** · salsicha pronta
- Legenda: Now take it and put it aside.
- ElevenLabs: `[calm] Done. Take it off and set it aside. Let it rest.`

✅ **v_2f3f900213** · fora da grelha, ir à tábua
- Legenda: Now go to the cutting board and cut some bread.
- ElevenLabs: `[confident] Now the cutting board. [pause] Cut the bread. [chuckles softly] [whisper] Clean cut. I like a clean cut.`

✅ **v_738c3d9fb1** · pegar o prato
- Legenda: Take his plate at the countertop.
- ElevenLabs: `[calm] His plate's on the counter. Take it.`

✅ **v_17a4e08ff7** · com o prato
- Legenda: Now, take the bread
- ElevenLabs: `[calm] Now the bread. On the plate.`

✅ **v_3a5bc4ff9f** · pão no prato
- Legenda: Take the sausage now.
- ElevenLabs: `[calm] And now the sausage. In the bun.`

✅ **v_57270a5e38** · montado, entregar (1º pedido)
- Legenda: This is a plain dog. Deliver it to the customer.
- ElevenLabs: `[proud] That's a plain dog. [pause] Go on, hand it to him. Don't keep a man waiting.`

✅ **v_46d1362f8c** · ouviu o 2º pedido (ketchup)
- Legenda: This one wants ketchup, so just do the same thing as before for now.
- ElevenLabs: `[amused] This one wants ketchup. [chuckles] Same thing as before, Rookie. You know the drill now.`

✅ **v_2d26ffde0c** · hora do molho
- Legenda: Now go to the toppings table and put the ketchup.
- ElevenLabs: `[calm] Toppings table. Ketchup. [low] [whisper] Just the ketchup.`

✅ **v_e7b24d9e83** · parado no molho (lembrete)
- Legenda: Rookie, just take the sauce.
- ElevenLabs: `[sighs] Rookie. [patient] The sauce. [whisper] Just take the sauce.`

✅ **v_3964010cb7** · molho errado
- Legenda: This is not what he asked. What are you doing? No, just toss it.
- ElevenLabs: `[cold, slow] That's not what he asked for. [pause] What are you doing? [sighs] No. [whisper] Toss it. We start over.`

✅ **v_abe7cb691e** · lixeira (lembrete)
- Legenda: In the bin, Rookie.
- ElevenLabs: `[flat] In the bin, Rookie.`

✅ **v_16750f60c7** · molho certo, entregar (2º pedido)
- Legenda: Well, it looks good. Just take it to the customer.
- ElevenLabs: `[pleased] Well, now. That looks good. [chuckles] Take it to him.`

✅ **v_630c883f42** · vendeu
- Legenda: Your first sale, huh? Good.
- ElevenLabs: `[warm, slow] Your first sale. [chuckles softly] Feels good, doesn't it? Good.`

✅ **v_03a5b65398** · estoque
- Legenda: If you run out of ingredients, take it in the back.
- ElevenLabs: `[calm] You run out of anything, there's more in the back. [low] [whisper] Just go get it. Don't dawdle back there.`

✅ **v_1dcefd5818** · close no relógio
- Legenda: Your shift ends at six.
- ElevenLabs: `[confident] Your shift ends at six. [pause] [whisper] Not a minute before.`

✅ **v_e0d63991ec** · despedida
- Legenda: That's your job. Call me if you need me.
- ElevenLabs: `[warm] That's the job, Rookie. [pause] You need me, you call. [chuckles softly] [whisper] I'm always around.`

### O que os outros jogadores ouvem enquanto o Rookie faz o tutorial

⏳ **v_0fa0be155e** · Legenda: Got a rookie today!
- ElevenLabs: `[pleased] Got a new rookie today. [chuckles]`

⏳ **v_5874c73b55** · Legenda: I'm walking them through it.
- ElevenLabs: `[calm] I'm walking them through it.`

### Dicas do 1º dia (cada uma toca uma vez, na 1ª vez que a ação acontece)

✅ **v_660807b44d** · Legenda: Bar full? Grab it.
- ElevenLabs: `[calm] Bar's full? Grab it.`

✅ **v_0aca9b5c3e** · Legenda: Now slice a bun.
- ElevenLabs: `[calm] Now slice a bun.`

✅ **v_d8753a68f3** · Legenda: Pop a frank in the bun.
- ElevenLabs: `[easy] Pop the frank in the bun.`

✅ **v_4d28b6c67f** · **SUBSTITUÍDA** (DEC-368) · Legenda: Hot dog's ready. Wait for orders.
- ElevenLabs: `[satisfied] Hot dog's ready. [pause] Now we wait. They always come.`

✅ **v_9b6108722e** · Legenda: See the bubble? That's the order.
- ElevenLabs: `[leaning in] See the little bubble over his head? [pause] That's what he wants.`

✅ **v_6beee3781c** · Legenda: That's how you restock. Easy.
- ElevenLabs: `[pleased] And that's how you restock. [chuckles] Easy.`

✅ **v_922fb14183** · Legenda: Messed up? Toss it. No harm.
- ElevenLabs: `[calm] Messed it up? Toss it. [chuckles softly] No harm done. [whisper] Nobody's counting. Yet.`

### Fim do turno (6 PM): lição de upgrade, Gear Stand

⏳ **v_8d74b17c53** · Legenda: Shift's over, Rookie. Nice work.
- ElevenLabs: `[warm] Shift's over, Rookie. Nice work.`

⏳ **v_d568870e1a** · Legenda: Before tonight, get some gear.
- ElevenLabs: `[serious] Before tonight... [whisper] get yourself some gear.`

⏳ **v_df97670c5b** · Legenda: Gear Stand, in the back.
- ElevenLabs: `[calm] Gear Stand's in the back.`

⏳ **v_7c27354d0f** · Legenda: Short on cash? I've got you.
- ElevenLabs: `[generous] Short on cash? [chuckles] I've got you.`

✅ **v_8df981736c** · **SUBSTITUÍDA** (DEC-368; ver "PRONTAS PARA GRAVAR") · fim do turno, lição de upgrade (lembrete)
- Legenda: It's 6 AM, your shift is over. Go outside and check if you find anything useful.
- ElevenLabs: `[calm] Six A.M. Shift's over. [pause] Step outside, take a look around. Find something useful.`

✅ **v_0fb843d28b** · na Gear Stand (lembrete)
- Legenda: You can choose something. I'm gonna pay for it.
- ElevenLabs: `[generous] Pick something. Anything you like. [chuckles] It's on me.`

## Dia 2 + Noite 1 (primeira noite) · `dia_02/` · 2/8

### Manhã — MORTA — SEM DIA (DEC-360)

✅ **v_2022c4e32e** · **MORTA — SEM DIA** · destino: nenhum · Legenda: Cheese is in. Folks love cheese.
- ElevenLabs: `[pleased] Cheese came in today. [chuckles] Folks love cheese.`

✅ **v_7150b19925** · **MORTA — SEM DIA** · destino: nenhum (a run já começa de noite) · Legenda: You work late tonight. I'll ring.
- ElevenLabs: `[low] You're working late tonight. [pause] [whisper] I'll call you.`

### Noite 1: ligação (o cliente sem rosto)

⏳ **v_6ea4e48840** · N1 · Legenda: Evening, Rookie. Some customers look off.
- ElevenLabs: `[calm, deep] Evening, Rookie. [pause] Some of tonight's customers... look a little off. [chuckles softly] [whisper] Nothing to worry about.`

⏳ **v_8c48d35c08** · **SUBSTITUÍDA** (DEC-367) · N1 · Legenda: And don't stay outside too long.
- ElevenLabs: `[casual] And don't stay outside too long. [pause] [whisper] The air's bad at night.`

⏳ **v_0b0655a682** · **SUBSTITUÍDA** (DEC-368) · N1 (regra, escreve o papel) · Legenda: If you see someone with no face, just don't make any questions. Ignore him and he will leave.
- ElevenLabs: `[matter-of-fact] Someone shows up with no face? [chuckles] Rough week, that's all. [leaning in] Don't ask him questions. Don't cook his order. [whisper] Ignore him, and he'll leave.`

### Noite 1: café (toca a 1ª vez que a sanidade cai a 50)

⏳ **v_7a552ce2a2** · Legenda: You sound tired, Rookie...
- ElevenLabs: `[concerned, slow] You sound tired, Rookie...`

⏳ **v_52d1defbaf** · Legenda: Have some coffee.
- ElevenLabs: `[gentle] Go have some coffee.`

⏳ **v_71c594aea2** · Legenda: It'll keep your head on straight.
- ElevenLabs: `[chuckles softly] It'll keep your head on straight. [pause] [whisper] You'll want that tonight.`

## Dia 3 + Noite 2 · `dia_03/` · 3/5

### Manhã (depois da Noite 1) — MORTA — SEM DIA (DEC-360)

✅ **v_146c67bf64** · **MORTA — SEM DIA** · **reaproveitada** (TASK-655): abertura N2 "You came back. Told you nights were quiet." (id novo, ver "Aberturas") · Legenda: Morning! Told you nights were quiet.
- ElevenLabs: `[bright, a little too bright] Morning! [chuckles] Told you the nights were quiet.`

✅ **v_e7276368d3** · **MORTA — SEM DIA** · destino: nenhum · Legenda: Bacon's in. Smell that?
- ElevenLabs: `[inhales, pleased] Bacon's in. Smell that? [chuckles softly]`

✅ **v_3b40e44d74** · **MORTA — SEM DIA** · destino: nenhum · Legenda: Grill's hot. Sell some dogs.
- ElevenLabs: `[confident] Grill's hot. Go sell some dogs.`

### Noite 2: o que treme (pão puro) e a batida na porta

⏳ **v_3c75317b9b** · **SUBSTITUÍDA** (DEC-368) · N2 · Legenda: If you see someone shaking, he's probably just hungry, give him a bread.
- ElevenLabs: `[easy] Someone shaking all over? [chuckles] He's not sick. He's hungry. [confident] Give him plain bread. [whisper] Nothing on it.`

⏳ **v_8bcaa6bb04** · N2 · Legenda: Also, if someone knocks at the door... it's not me, lock it.
- ElevenLabs: `[pause, low] And if somebody knocks on the back door... [very calm] it's not me. I've got a key. [whisper] Lock it.`

## Dia 4 + Noite 3 · `dia_04/` · 3/5

### Manhã (depois da Noite 2) — MORTA — SEM DIA (DEC-360)

✅ **v_3153f74405** · **MORTA — SEM DIA** · **reaproveitada** (TASK-655): abertura N3, junto com v_9f14feee91 (id novo) · Legenda: Morning, Rookie. Sleep okay?
- ElevenLabs: `[warm] Morning, Rookie. [pause] Sleep okay?`

✅ **v_9f14feee91** · **MORTA — SEM DIA** · **reaproveitada** (TASK-655): abertura N3, junto com v_3153f74405 (id novo) · Legenda: Good. Don't think about it.
- ElevenLabs: `[flat, quick] Good. [pause] [whisper] Don't think about it.`

✅ **v_e245baf6a4** · **MORTA — SEM DIA** · destino: nenhum · Legenda: Potato sticks today. Bigger grill, too.
- ElevenLabs: `[pleased] Potato sticks today. And a bigger grill. [chuckles] We're growing.`

### Noite 3: o apagão (disjuntor) e as cópias

⏳ **v_05009b919e** · **SUBSTITUÍDA** (DEC-368) · N3 · Legenda: If the lights turn off, the breaker is outside, go there and fix it.
- ElevenLabs: `[casual] Lights might go out tonight. Old wiring. [pause] Breaker's outside. [whisper] Go out there and hold it till they're back on.`

⏳ **v_49de7dc12d** · N3 · Legenda: Rookie, it seems that something weird is happening today... if you see someone showing up twice don't serve him.
- ElevenLabs: `[amused] Funny thing about tonight, Rookie... [pause] same customer might show up twice. [chuckles] Twins, I guess. [cold] The second one? [whisper] Don't serve him.`

## Dia 5 + Noite 4 · `dia_05/` · 1/4

### Manhã (depois da Noite 3) — MORTA — SEM DIA (DEC-360)

✅ **v_444b37b9a8** · **MORTA — SEM DIA** · destino (TASK-655): nenhum (a N4 abre com a skin cansada + café) · Legenda: Bank clock's ticking fine. See?
- ElevenLabs: `[too reassuring] Bank clock's ticking just fine. [pause] [whisper] See?`

⏳ **v_b826ff9af4** · **MORTA — SEM DIA** · destino: nenhum · Legenda: Nice and normal. Sell some dogs.
- ElevenLabs: `[calm] Nice and normal today. Sell some dogs.`

### Noite 4: pescoço virado (não olhar) e o vulto do outro lado da rua

⏳ **v_5495df0c7e** · N4 · Legenda: Some customers have a neck problem, so if you see one, don't stare him, just give the food to him and your head down
- ElevenLabs: `[calm] One of the regulars has a neck thing. Head turned all the way around. [chuckles] She didn't break it. She's just tired and looked back. [low] [whisper] Don't stare. Hand her the food with your head down.`

⏳ **v_84845b02f9** · N4 · Legenda: Someone across the street? Don't look.
- ElevenLabs: `[quiet] Somebody standing across the street? [pause] [whisper] Don't look.`

## Dia 6 + Noite 5 · `dia_06/` · 0/4

### Manhã (depois da Noite 4) — MORTA — SEM DIA (DEC-360)

⏳ **v_1ae72da760** · **MORTA — SEM DIA** · **reaproveitada** (TASK-655): abertura N5, sem o nome Pickett (id novo) · Legenda: One Mr. Pickett today, I hope.
- ElevenLabs: `[dry] Just one Mister Pickett today. [pause] [whisper] I hope.`

⏳ **v_6643e2a67d** · **MORTA — SEM DIA** · **reaproveitada** (TASK-655): abertura N5 ("Joke. Mostly.", id novo) · Legenda: That was a joke. Mostly.
- ElevenLabs: `[chuckles] That was a joke. [pause, flat] [whisper] Mostly.`

### Noite 5: olhos brancos (apagar a luz) e a moça da capa de chuva

⏳ **v_6e89e13998** · N5 · Legenda: If you see someone with white eyes, TURN OFF THE LIGHTS, and give them the food, they are light sensitive
- ElevenLabs: `[gentle] Customer with white eyes? [chuckles] Light sensitive, poor thing. [confident] Turn off the lights first. [whisper] Then give them the food.`

⏳ **v_8b2fd70edd** · N5 · Legenda: Hey Rookie, if you see the raincoat lady, I love her, serve her and be nice to her.
- ElevenLabs: `[warm, fond] And Rookie... the lady in the raincoat. [pause] [whisper] I love that woman. [firm] Serve her. And be nice to her.`

## Dia 7 + Noite 6 · `dia_07/` · 0/3

### Manhã (depois da Noite 5) — MORTA — SEM DIA (DEC-360)

⏳ **v_f36e086018** · **MORTA — SEM DIA** · **reaproveitada** (TASK-655): abertura N6, junto com v_2825918158 (id novo) · Legenda: She liked you. The lady.
- ElevenLabs: `[softly] She liked you, you know. [pause] [whisper] The lady.`

⏳ **v_2825918158** · **MORTA — SEM DIA** · **reaproveitada** (TASK-655): abertura N6, junto com v_f36e086018 (id novo) · Legenda: Forget I said that.
- ElevenLabs: `[quiet] [whisper] Forget I said that.`

### Noite 6: cabeção (rápido) e a névoa vermelha (fechar a janela)

⏳ **v_38eb8400bb** · N6 · Legenda: If you see the customer with a big head, give them the food fast, they have a headache. And also, a red fog might show up, so close the window if it happens.
- ElevenLabs: `[casual] Guy with a head way too big for him? [chuckles] Headache. Don't keep him waiting. Serve him fast. [pause, lower] [whisper] And if a red fog rolls in... shut the window. Keep it shut till it's gone.`

## Dia 8 + Noite 7 · `dia_08/` · 0/6

### Manhã (depois da Noite 6) — MORTA — SEM DIA (DEC-360)

⏳ **v_ec32a5c044** · **MORTA — SEM DIA** · destino (TASK-655): nenhum (restaurante sem andar de cima; N7 abre com a skin da noite) · Legenda: Ever notice nobody lives upstairs?
- ElevenLabs: `[casual] Ever notice nobody lives upstairs? [pause]`

⏳ **v_accbaddd4a** · **MORTA — SEM DIA** · destino (TASK-655): nenhum · Legenda: In the daytime, I mean.
- ElevenLabs: `[too quick] [whisper] In the daytime, I mean.`

⏳ **v_e07ecc1b65** · **MORTA — SEM DIA** · destino (TASK-655): nenhum · Legenda: Huh. Next question.
- ElevenLabs: `[chuckles] Huh. [flat] Next question.`

### Noite 7: arranhão no chão (subir no balcão)

⏳ **v_aaaf538e6f** · **SUBSTITUÍDA** (DEC-368, junta com a v_3c84ea3eda numa fala só) · N7 · Legenda: Scratching under the floor?
- ElevenLabs: `[calm] [whisper] You hear scratching under the floor?`

⏳ **v_3c84ea3eda** · **SUBSTITUÍDA** (DEC-368) · N7 · Legenda: Get off the floor. Climb the counter.
- ElevenLabs: `[chuckles] Rats. Big ones. [confident] Get off the floor. Up on the counter. [whisper] Wait for the thud.`

⏳ **v_aa5a08d1a0** · N7 (repetição) · Legenda: Scratching? Up on the counter.
- ElevenLabs: `[calm] Scratching? [whisper] Up on the counter.`

## Dia 9 + Noite 8 · `dia_09/` · 0/5

### Manhã (depois da Noite 7) — MORTA — SEM DIA (DEC-360)

⏳ **v_79fe1b45ba** · **MORTA — SEM DIA** · **reaproveitada** (TASK-655): abertura N8, junto com v_b938f43cf2 (id novo) · Legenda: You kept your eyes down. Good.
- ElevenLabs: `[approving, low] You kept your eyes down. [pause] [whisper] Good.`

⏳ **v_b938f43cf2** · **MORTA — SEM DIA** · **reaproveitada** (TASK-655): abertura N8, como "I used to count the lamps" (id novo) · Legenda: I counted the lamps. It helps.
- ElevenLabs: `[calm, distant] I counted the lamps last night. [pause] [whisper] It helps.`

### Noite 8: o carro comprido no drive-thru (fechar a janela)

⏳ **v_70a8507099** · N8 · Legenda: A long car at the drive-thru?
- ElevenLabs: `[slow] [whisper] A car at the drive-thru... that just keeps going? [pause]`

⏳ **v_0b669707f9** · N8 · Legenda: Shut the window. Keep it shut.
- ElevenLabs: `[very calm] Shut the window. [whisper] Keep it shut. [chuckles] He'll get the hint.`

⏳ **v_0db7046e74** · N8 (repetição) · Legenda: Long car? Shut it. Keep it shut.
- ElevenLabs: `[calm] Long car? Shut the window. [whisper] Keep it shut.`

## Dia 10 + Noite 9 · `dia_10/` · 0/3

### Manhã (depois da Noite 8) — MORTA — SEM DIA (DEC-360)

⏳ **v_0eec32dec6** · **MORTA — SEM DIA** · **reaproveitada** (TASK-655): abertura N9 "Long night, huh? I'm saving you a coffee." e o "Coffee's on me" da N4 (ids novos) · Legenda: Long night, huh? Coffee's on me.
- ElevenLabs: `[warm] Long night, huh? [chuckles] Coffee's on me.`

⏳ **v_4550eb2216** · **MORTA — SEM DIA** · destino (TASK-655): nenhum (Opal fora do restaurante) · Legenda: Tell Opal it's for Walt.
- ElevenLabs: `[easy] Tell Opal it's for Walt.`

### Noite 9: passos no telhado (não olhar pra cima)

⏳ **v_951af0016c** · N9 · Legenda: If you hear steps at the roof, it's probably a cat. Don't look up.
- ElevenLabs: `[casual] Footsteps on the roof? [chuckles] Cat. Big cat. [low, firm] [whisper] Whatever you do, don't look up.`

## Dia 11 + Noite 10 (a última) + final · `dia_11/` · 0/19

### Manhã (depois da Noite 9) — MORTA — SEM DIA (DEC-360)

⏳ **v_9a2f7f9949** · **MORTA — SEM DIA** · destino (TASK-655): nenhum · Legenda: Rookie. About the knocking.
- ElevenLabs: `[serious, slow] Rookie. [pause] [whisper] About the knocking.`

⏳ **v_319d2c7703** · **MORTA — SEM DIA** · destino (TASK-655): nenhum (não cabe nos 6 s da N10) · Legenda: That wasn't me. Believe that.
- ElevenLabs: `[very calm] That wasn't me. [pause] [whisper] Believe that.`

⏳ **v_909f41e668** · **MORTA — SEM DIA** · destino (TASK-655): nenhum · Legenda: Tonight's the last. I promise.
- ElevenLabs: `[gentle] Tonight's the last one. [pause] [whisper] I promise.`

### Noite 10: os postes apagando (luz da loja desligada)

⏳ **v_140f750fc0** · **SUBSTITUÍDA** (TASK-655, abertura nova da N10 em "PRONTAS PARA GRAVAR") · N10 · Legenda: Last night, Rookie.
- ElevenLabs: `[warm, slow] Last night, Rookie. [pause]`

⏳ **v_37eb690baf** · **SUBSTITUÍDA** (DEC-368) · N10 · Legenda: Lamps dying outside? Shop light off.
- ElevenLabs: `[calm] Street lamps start dying outside? [pause] [whisper] Turn the shop light off.`

⏳ **v_a5a48fc8ed** · N10 · Legenda: Keep it off till they're back.
- ElevenLabs: `[low] And keep it off till they come back on. [chuckles softly] [whisper] Trust me.`

⏳ **v_7caee4e9eb** · N10 (repetição) · Legenda: Lamps out? Shop light off.
- ElevenLabs: `[calm] Lamps out? [whisper] Shop light off.`

### Noite 10: rádio (o único momento em que ele grita)

⏳ **v_86b4351c71** · **SAI** (DEC-368: não há Mart) · Legenda: The lamps are dying! Run INSIDE the Mart, now!
- ElevenLabs: `[urgent, shouting] The lamps are dying! [panicked] Get inside the Mart! Now!`

⏳ **v_d9a7a5ee99** · **SUBSTITUÍDA** (DEC-368) · Legenda: The lamps outside are dying! Kill the lights in here, NOW!
- ElevenLabs: `[urgent, shouting] The lamps outside are dying! [panicked] Kill the lights in there! NOW!`

### Final (presencial, sem telefone): mais devagar, mais perto

⏳ **v_f271c54c14** · Legenda: Ten nights. You kept the light on.
- ElevenLabs: `[quiet, impressed] Ten nights. [pause] You kept the light on.`

⏳ **v_b85c836266** · **SUBSTITUÍDA** (DEC-369, "From across the street.") · Legenda: I watched every one. From in here. Best seat in town.
- ElevenLabs: `[chuckles softly] I watched every one of them. From in here. [pause] [whisper] Best seat in town.`

⏳ **v_0520e8b100** · Legenda: I worked that corner forty years. Since '. (no jogo: "Since '79")
- ElevenLabs: `[nostalgic, slow] I worked that corner forty years. [pause] Since nineteen seventy-nine.`

⏳ **v_83d0e946e7** · Legenda: The corner's a crossing, Rookie. At night, the late crowd comes through.
- ElevenLabs: `[low, confiding] This corner's a crossing, Rookie. [pause] [whisper] At night... the late crowd comes through.`

⏳ **v_a407bfc9ae** · Legenda: They like the light. And the smell of food. Heh.
- ElevenLabs: `[amused] They like the light. [pause] And the smell of food. [chuckles] Heh.`

⏳ **v_a2fdcbe997** · Legenda: Keep the rules, and they stay polite. That's the deal.
- ElevenLabs: `[confident] Keep the rules, and they stay polite. [pause] [whisper] That's the deal.`

⏳ **v_2bd5e253a0** · Legenda: Somebody has to keep the light on. Every night.
- ElevenLabs: `[grave] Somebody has to keep the light on. [pause] [whisper] Every night.`

⏳ **v_5e55db4a7b** · Legenda: My knees are done. But you... you notice things.
- ElevenLabs: `[tired, warm] My knees are done. [pause] But you... [leaning in] [whisper] you notice things.`

⏳ **v_f3e7afb49b** · Legenda: The night shift is yours. If you want it.
- ElevenLabs: `[deliberate] The night shift is yours. [pause] [whisper] If you want it.`

⏳ **v_4e6cef12f6** · **FORA DA SEQUÊNCIA PRINCIPAL** (DEC-363: o final é "O Segundo Café"; só o final A1 de reserva usa) · **não gravar agora** · Legenda: Morning, Marigold.
- ElevenLabs: `[soft, fond] Morning, Marigold.`

### Final "O Segundo Café" (DEC-363, Aprovado): falas novas (id a gerar pela pipeline; voz `walt_dark` = Walt mais lento e grave; rádio = voz "radio")

⏳ **(id a gerar)** · walt_dark, depois do 2º café estendido, céu voltando à noite · Legenda: Forty years, Rookie. Forty years of nights.
- ElevenLabs: `[slow, low, the warmth gone] Forty years, Rookie. [pause] Forty years... of nights.`

⏳ **(id a gerar)** · walt_dark, ao jogar o jogador na rua · Legenda: Now I get the mornings.
- ElevenLabs: `[low, satisfied, almost tender] [whisper] Now I get the mornings.`

⏳ **(id a gerar)** · rádio, voz do último Rookie, no preto · Legenda: ...welcome to the other side, Rookie...
- ElevenLabs: `[weak, distant, broken radio] ...welcome to the other side... Rookie...`
- Sem *kill/die* em nenhuma das três (`world.md` §1).

## Falas novas das DEC-365 — **SUPERADAS pela versão revisada em "PRONTAS PARA GRAVAR"** (não gravar estas)

⏳ **(id a gerar)** · ligação de reclamação, logo depois que a Raincoat Lady é despachada pela janela (uma vez por run) · Legenda: You shut her out, Rookie. You might regret that.
- ElevenLabs: `[quiet, disappointed] You shut her out, Rookie. [pause, colder] [whisper] You might regret that.`

⏳ **(id a gerar)** · Noite 1, ligação da noite, regra da janela com o custo · Legenda: Something wrong at the window? Shut it. They'll go. So does the money.
- ElevenLabs: `[casual] Something wrong at the window? [pause] Shut it. They'll go. [chuckles] [whisper] So does the money.`

## Qualquer dia ou noite · `qualquer_dia/` · 0/15

### Noite repetida (abre a ligação; depois ele repete as falas daquela noite)

Nota: com `Chances = 0` (DEC-319) não há noite repetida nem noite perdida com volta: as 6 falas abaixo **nunca tocam**. Não gravar.

⏳ **v_cea0c2176a** · noite repetida (abertura) · Legenda: Same night, Rookie. Same rules.
- ElevenLabs: `[patient, unbothered] Same night, Rookie. [chuckles] [whisper] Same rules.`

### Noite perdida (na ligação da noite repetida)

⏳ **v_80f4cae4c8** · Legenda: You watched it, didn't you?
- ElevenLabs: `[quiet, knowing] [whisper] You watched it, didn't you?`

⏳ **v_32b25cfd5c** · Legenda: It's okay. Breathe.
- ElevenLabs: `[soothing] It's okay. [pause] [whisper] Breathe.`

⏳ **v_e2948c76ce** · Legenda: Rough night. Let's try again.
- ElevenLabs: `[calm] Rough night. [chuckles softly] Let's try that again.`

⏳ **v_8d823b58bf** · Legenda: Everyone's back on their feet.
- ElevenLabs: `[easy] Everyone's back on their feet. [pause] [whisper] More or less.`

⏳ **v_089cce41c0** · Legenda: Only chance I get. Be careful.
- ElevenLabs: `[serious] This is the only chance I can give you. [whisper] Be careful.`

### Fim da run (citado na tela final)

Nota (DEC-364): `Q-479` foi descartada pelo dono; o texto fica como está. "That's two, Rookie." não bate com o jogo atual (a 1ª noite perdida já acaba a run): está no lote `Q-484`. Não gravar até lá.

⏳ **v_d91e854ce1** · **SUBSTITUÍDA** (DEC-368, "That's it, Rookie.") · Legenda: That's two, Rookie.
- ElevenLabs: `[disappointed, slow] That's two, Rookie.`

⏳ **v_d30128cf6d** · Legenda: No more nights for you.
- ElevenLabs: `[flat] [whisper] No more nights for you.`

⏳ **v_fe4055ecce** · Legenda: Go home. You did well.
- ElevenLabs: `[gentle] Go home. [pause] You did well.`

### Dias sem fim (depois da Noite 10; uma por dia, sorteada) — MORTA — SEM DIA (DEC-360); destino: nenhum (as 6 abaixo)

⏳ **v_67ee73c3b4** · Legenda: Another day, another dog.
- ElevenLabs: `[chuckles] Another day, another dog.`

⏳ **v_d559c7aa79** · Legenda: Proud of you, Rookie. Really.
- ElevenLabs: `[warm, sincere] Proud of you, Rookie. [pause] Really.`

⏳ **v_4585eb246b** · Legenda: Grill's hot. Let's go.
- ElevenLabs: `[confident] Grill's hot. Let's go.`

⏳ **v_d601ce4350** · Legenda: Corner's quiet. Too quiet. Heh.
- ElevenLabs: `[amused] Corner's quiet. [pause] [whisper] Too quiet. [chuckles] Heh.`

⏳ **v_edd36e4c4d** · Legenda: Nice and normal. Just right.
- ElevenLabs: `[satisfied] Nice and normal. Just right.`

⏳ **v_67ad984e40** · Legenda: Ketchup, mustard, smile. That's the job.
- ElevenLabs: `[smiling] Ketchup, mustard, smile. [chuckles] That's the whole job.`
