Status: Rascunho

# Walkthrough — vozes gravadas pelo dono (2026-10-23)

Roteiro para ouvir, dentro do jogo, cada fala que o dono gravou para o Walt. As edições estão em
`tools/voice/edits.applied-2026-10-23.json`, os textos em `src/Tutorial/client/TutorialController/Steps.luau` e
`src/Shared/Content/BossCalls.luau` (ligações das noites).

## 0. Antes de testar

1. Subir as gravações e montar o catálogo (sem isso o jogo toca a voz antiga ou o TTS, e as falas longas usam o tempo
   fixo de 2,5 s por fala):
   ```
   cd tools/voice
   python upload.py
   python build_content.py
   ```
   Confira no fim do `upload.py` que nenhuma linha ficou `rejected`.
2. Studio: `rogen build` → `modux generate` → `rojo serve`, Play.
3. `SoundService:SetAttribute("SpeechLog", true)` na barra de comando do cliente: cada fala imprime `voiced from asset`
   (sua voz) ou `TTS` (falta voz). Qualquer `TTS` no tutorial ou nas noites = fala que não bateu com o áudio.

Em cada item marque: **voz certa** (é a sua, não cortada), **legenda bate** com o que você fala, **momento certo**.

## 1. Tutorial (`/dev tutorial reset`, depois atenda o telefone)

| # | Momento | Fala | Ok |
|---|---|---|---|
| 1 | Atendeu o telefone | "Hello, Rookie! My name is Walt. I've noticed that you're new here, so I'm gonna walk you through this." | [ ] |
| 2 | Logo depois, seta na alavanca | "Do you see that lever? Go there and pull it to open the store." | [ ] |
| 3 | Puxou a alavanca, cliente vindo | "Nice. Here it comes, your first client." | [ ] |
| 4 | Cliente no tablet | "Take his order." | [ ] |
| 5 | Parado no tablet ~12 s (lembrete) | "What are you doing? I don't have the whole night. Take his order." | [ ] |
| 6 | Cliente terminou de falar o pedido | "Plain dog. Go to the grill." → "Take the sausage from the cooler." → "Drag it to the grill." | [ ] |
| 7 | Hora de virar | "Now flip it." e, ao acertar, "Good." | [ ] |
| 8 | Salsicha pronta | "Now take it and put it aside." | [ ] |
| 9 | Fora da grelha, ir à tábua | "Now go to the cutting board and cut some bread." e, ao cortar, "Good." | [ ] |
| 10 | Pegar o prato | "Take his plate at the countertop." | [ ] |
| 11 | Com o prato | "Now, take the bread" | [ ] |
| 12 | Pão no prato | "Take the sausage now." | [ ] |
| 13 | Montado (pedido simples) | "This is a plain dog. Deliver it to the customer." | [ ] |
| 14 | 2º cliente (carro) pede | "Take his order." | [ ] |
| 15 | 2º cliente terminou de falar | "This one wants ketchup, so just do the same thing as before for now." (depois silêncio até o molho) | [ ] |
| 16 | Hora do molho | "Now go to the toppings table and put the ketchup." | [ ] |
| 17 | Parado no molho (lembrete) | "Rookie, just take the sauce." | [ ] |
| 18 | Molho errado (`/dev tutorial step r_discard` se precisar) | "This is not what he asked. What are you doing? No, just toss it." · lembrete "In the bin, Rookie." | [ ] |
| 19 | Molho certo | "Well, it looks good. Just take it to the customer." | [ ] |
| 20 | Vendeu | "Your first sale, huh? Good." | [ ] |
| 21 | Estoque (`r_box`) | "If you run out of ingredients, take it in the back." | [ ] |
| 22 | Close no relógio | "Your shift ends at six." | [ ] |
| 23 | Despedida | "That's your job. Call me if you need me." | [ ] |
| 24 | Fim do turno, lição de upgrade, parado (lembrete) | "It's 6 AM, your shift is over. Go outside and check if you find anything useful." | [ ] |
| 25 | Na Gear Stand, parado (lembrete) | "You can choose something. I'm gonna pay for it." | [ ] |

Saíram (não devem mais tocar): "Good evening, Rookie.", "Pick up the phone.", "Tap the tablet, Rookie.", "Wait for it.",
"Flip it now.", "Nice flip.", "Stocked up!", "Keep an eye on the clock.", "Ka-ching! First sale.", "Cash goes in the
drawer.", as falas do mercado (Mart) e do estoque antigo.

## 2. Ligações das noites (`/dev night N`, ou `/dev call call_night_N`)

| Noite | Falas | Ok |
|---|---|---|
| 1 | "Evening, Rookie. Some customers look off." · "And don't stay outside too long." (**voz sintética**) · "If you see someone with no face, just don't make any questions. Ignore him and he will leave." | [ ] |
| 2 | "If you see someone shaking, he's probably just hungry, give him a bread." · "Also, if someone knocks at the door... it's not me, lock it." | [ ] |
| 3 | "If the lights turn off, the breaker is outside, go there and fix it." · "Rookie, it seems that something weird is happening today... if you see someone showing up twice don't serve him." | [ ] |
| 4 | "Some customers have a neck problem, so if you see one, don't stare him, just give the food to him and your head down" · "Someone across the street? Don't look." (**voz sintética**) | [ ] |
| 5 | "If you see someone with white eyes, TURN OFF THE LIGHTS, and give them the food, they are light sensitive" · "Hey Rookie, if you see the raincoat lady, I love her, serve her and be nice to her." | [ ] |
| 6 | "If you see the customer with a big head, give them the food fast, they have a headache. And also, a red fog might show up, so close the window if it happens." | [ ] |
| 7, 8, 10 | sem mudança (**voz sintética**) | [ ] |
| 9 | "If you hear steps at the roof, it's probably a cat. Don't look up." | [ ] |

Noite repetida (`/dev call call_night_short` e depois a da noite): repete as mesmas falas.

Também conferir em cada noite: o **papel** do balcão é escrito na **última** fala (som do lápis), e o texto do papel
diz a mesma regra que você falou.

Outras ligações tocadas: `/dev call hint_take_order` → só "See the bubble? That's the order." ·
`/dev call call_tutorial_upgrade` → sem "Pick whatever you like. Your call."

## 3. Ainda com voz sintética (gravar depois, se quiser)

Noite 1 (2 primeiras), Noite 4 ("Someone across the street? Don't look."), Noites 7, 8 e 10 inteiras, "Pull the
window lever." (lembrete da alavanca), as ligações de dia, de café, de noite perdida, da lição de upgrade, as dicas e
as cutscenes do final. Na janela `record_gui.py`, filtro "Sem voz enviada".

## 4. Pontos para decidir no teste

- **Disjuntor:** a fala da noite 3 diz "the breaker is outside"; antes era "on the light panel". Confirmar onde ele
  fica no mapa do restaurante.
- **Lembretes longos:** os lembretes do tablet e da lição de upgrade passaram de ~40 para ~80 caracteres; ver se a
  legenda cabe.
- **Repetição:** um passo sem lembrete repete a fala a cada 20 s se o jogador ficar parado (ex.: o item 6, com 3 falas).
