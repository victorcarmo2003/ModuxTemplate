Status: Rascunho

# Auditoria das falas do Walt × gameplay atual × lore × ending novo

Autor: secretário, 2026-10-23. Pedido do dono: "as falas e os diálogos do Walt estão mal planejados em relação à gameplay atual".
Só auditoria e proposta. Nada foi regravado, nenhum código mudou, nada foi aprovado. Tudo aqui é **Provisório**.
Dúvidas do dono: `Q-478` a `Q-485` em `open-questions.md`.

> **Resposta do dono, 2026-10-23:**
> - **DEC-360 (Aprovado):** a run é 100% noite e começa de noite; não existe dia nem ligação da manhã ("os primeiros 90 segundos do jogador ali no jogo são muito importantes"). Fecha `Q-478`. As falas de manhã ficam **mortas — sem dia** (não apagadas); o destino proposto (§3.3) segue **Provisório** em `Q-485`.
> - **DEC-361 (Aprovado):** fechar a janela despacha as anomalias-cliente (menos a ANM-022); o custo é o dinheiro (vendas pausadas; a anomalia sai sem pagar, sem × `PayMult` nem bônus). `Q-481` segue aberta só na Raincoat Lady e em "o Walt ensina a janela?".
> - O ending "O Segundo Café" segue aberto (`Q-480`): o dono vai testar a cinemática antes de aprovar.
>
> **2ª resposta do dono, 2026-10-23:**
> - **DEC-362:** aprova a lore progressiva na abertura de cada ligação da noite (fecha `Q-485`). §3.2 e §3.3 seguem como base **Provisória**; textos com o narrative-writer.
> - **DEC-363:** o final é "O Segundo Café" (fecha `Q-480`); só faltam os créditos. Tela de fim de run, pós-créditos e palco sem Mart em `Q-486`.
> - **DEC-364:** `Q-479` descartada (nenhuma cena de derrota nova).
> - **DEC-365:** Raincoat Lady despachada = −5 + ligação do Walt reclamando; o Walt ensina a janela com o custo (fecha `Q-481`).
> - `Q-482`, `Q-483`, `Q-484`: o dono não entendeu; reescritas em linguagem simples em `open-questions.md`.
>
> **3ª resposta do dono, 2026-10-23:** DEC-366 (ANM-022 = luz da loja, aviso na N8), DEC-367 (o Walt avisa toda novidade; disjuntor na N1), DEC-368 (lote corrigido), DEC-369 (pós-créditos, "From across the street.", tela "You Took the Shift"), DEC-370 (skins por noite), DEC-371 (Walt sombrio no estacionamento). Textos revisados pelo narrative-writer, prontos para gravar em `tools/voice/elevenlabs_script.md` ("PRONTAS PARA GRAVAR"). Abertas: `Q-487` (interação ativa além do aviso), `Q-488` (o que a sanidade baixa ainda muda no visual), `Q-489` (Walt com um café só no pós-créditos).
>
> **4ª resposta do dono, 2026-10-23:** DEC-372 (o Walt reage no meio da noite **sem telefone**, 1ª vez de cada coisa, até 2 por noite, nunca explicado; falas R1–R10 no roteiro, pasta `noite_reacoes/`), DEC-373 (sanidade baixa só alucinação), DEC-374 (Walt de dia com um café só no pós-créditos). Nenhuma pergunta aberta desta auditoria.

Fontes lidas: `tools/voice/elevenlabs_script.md` (121 falas, 47 gravadas), `Content/BossCalls.luau`, `Tutorial/client/TutorialController/Steps.luau`,
`Content/VoiceLines.luau`, `Content/Anomalies.luau`, `Content/AnomalyHints.luau`, `Content/Hints.luau` (papel), `Content/Nights.luau`,
`Content/ShopWindow.luau`, `Content/Breaker.luau`, `Content/Hallucinations.luau`, `Content/Cutscenes.luau`, `Content/Shift.luau`,
`Content/RunParams.luau`, `Round/server/RoundService/Flow.luau`, `Boss/server/BossService`, `Tutorial/server/TutorialService.luau`,
`Anomaly/server/AnomalyService/Rules/*.luau`, `Anomaly/client/.../Effects/ANM-010.luau`, `story/ending.md`, `story/walt-calls-lore.md`,
`decisions.md` (DEC-075, 076, 177, 307, 309, 312, 354, 357), `open-questions.md` (Q-466 a Q-477).

---

## 0. Fatos da gameplay que mudam a leitura do roteiro

| # | Fato (código hoje) | Consequência para as falas |
|---|---|---|
| F1 | `Shift.RunStartsAtNight = true` e `Flow.Next` sempre devolve `IsNight = true`. A run é **só noites**: N1 (Dia 2) … N10 (Dia 11), Finale. Não existe turno de dia. | `BossService:OnDayPrep` só roda em Prep **de dia** → **nenhuma ligação da manhã toca**: `call_day_1`, `call_day_2`, `call_day_after_1..9` e `call_day_infinite_*`. **Confirmado como regra pelo dono: DEC-360.** |
| F2 | `Shift.Morning.Enabled = false`: o Call (7 PM) e o Prep (7→8 PM) da noite são escuros. | A única ligação de cada turno é a **da noite, às 7 PM**. Qualquer pista de lore tem que caber nela (ou no fake_call/rádio). Fala que começa com "Morning" soa errada às 7 PM. |
| F3 | O tutorial roda **dentro da Noite 1** (fases Call/Night). A ligação da N1 toca depois do tutorial + 1 cliente. A lição de upgrade toca no **Summary das 6 AM** depois da N1. | O cabeçalho do roteiro ("Dia 1 não tem noite; a Noite k é no fim do Dia k+1") está errado. "Dia 1" = Noite 1 com tutorial. |
| F4 | `RunParams.Chances = 0` (DEC-319): a 1ª noite perdida encerra a run. | Noite repetida, noite perdida e "last chance" **nunca tocam**. "That's two, Rookie." está errado: é a primeira. |
| F5 | Hoje (2026-10-23, Provisório): fechar a janela manda embora **só as anomalias-cliente**, sem susto e sem nota; os clientes normais ficam. ANM-022 ignora a janela, bate a cabeça nela e só sai quando a luz da loja apaga. | Nenhuma fala ensina isso. A janela vira uma saída universal das anomalias-cliente. **DEC-361:** é intencional, e o custo é o dinheiro (vendas pausadas, a anomalia sai sem pagar). Seguir a regra do Walt paga mais (× `PayMult`); a janela é a saída segura e mais pobre. Abertos em `Q-481`: Raincoat Lady e se o Walt ensina. |
| F6 | 7 anomalias-cliente rodam com a condição interina `Serve` (qualquer entrega resolve, sem erro): 001, 004, 013, 015, 016, 022, 023 (`Q-474`). Só 011 `Plain`, 012 `NoLook`, 014 `Hurry` e 005 `Serve` estão vivas. | Várias regras do Walt (001, 004, 013) **não são cobradas** hoje. A fala é a regra planejada, não a do código. |
| F7 | O evento obrigatório da noite nas N1–N2 é o **desarme do disjuntor** (`Q-475`, `LightService:TripBreaker`). | O jogador precisa religar o disjuntor na N1 e na N2, mas o Walt só fala do disjuntor na N3. |
| F8 | `Cutscenes.Rules.Finale = "second_coffee"`, mas as cenas `second_coffee`, `second_coffee_in`, `second_coffee_out` **não existem** na tabela, e `CutsceneService` toca `"finale"` fixo. | Hoje o jogo ainda toca o **final A1** (Walt caloroso + "Morning, Marigold."). O ending novo é código parcial de outra sessão e não tem DEC (`Q-480`). |
| F9 | Restaurante sem Mart (DEC-307). | "Run INSIDE the Mart" e "From in here" (Walt no Mart) não têm mais palco. |

---

## 1. Tabela por dia/noite

Status: **ok** · **desalinhada** (texto ≠ o que a gameplay pede) · **contradiz** (lore, ending ou decisão) · **morta** (nunca toca) · **falta fala**.
✅ = gravada · ⏳ = falta gravar.

### Noite 1 (Dia 2) com tutorial

| Fala | O que a gameplay pede ali | Status |
|---|---|---|
| ✅ v_6a998d7bee "Morning, Rookie! I'm on the line." · ✅ v_e06f57adaa "Tap the frank box. Grill it." · ✅ v_f2bed86855 "Open up when ready." (`call_day_1`) | Nada: não existe Prep de dia (F1). "Frank box" também não existe mais na cozinha. | **morta** (3 gravadas perdidas) |
| ✅ v_643427f920 saudação · ✅ v_07f1b13880 alavanca · ✅ v_e17886c499 lembrete | Atender o telefone, puxar a alavanca da janela. | ok |
| ✅ v_98dcdc1f92 … ✅ v_630c883f42 (pedido, grelha, virar, descansar, tábua, prato, pão, salsicha, entregar, ketchup, molho errado, lixeira, 1ª venda) | Passos do tutorial do restaurante (Steps.luau): batem um a um. | ok |
| ✅ v_03a5b65398 "If you run out of ingredients, take it in the back." | Estoque no fundo (despensa). | ok |
| ✅ v_1dcefd5818 "Your shift ends at six." | O turno da noite acaba às 6 AM. | ok |
| ✅ v_e0d63991ec "That's your job. Call me if you need me." | Despedida do tutorial. | ok |
| ⏳ v_0fa0be155e / v_5874c73b55 (o que os outros ouvem) | Ligação `call_tutorial` para quem não está no tutorial. | ok |
| ✅ v_660807b44d … v_922fb14183 (7 dicas do 1º dia) | Só tocam se o jogador **pular o tutorial** (o tutorial marca as dicas como ouvidas). "Hot dog's ready. Wait for orders." inverte o fluxo atual (o pedido vem antes do preparo). | ok, uso raro; v_4d28b6c67f **desalinhada** |
| ⏳ v_6ea4e48840 "Evening, Rookie. Some customers look off." | Abertura da 1ª ligação de noite. Repete a saudação do tutorial uns minutos antes. | ok |
| ⏳ v_8c48d35c08 "And don't stay outside too long." | Há caçador lá fora (OutsideService). Mas o evento obrigatório da N1 é o disjuntor, que fica **lá fora** (F7): a regra empurra o jogador para dentro na noite em que ele precisa sair. | **desalinhada** |
| ⏳ v_0b0655a682 "…no face, just don't make any questions. Ignore him and he will leave." (escreve o papel) | ANM-001: o pedido é sempre anotado (DEC-354); planejado `NoServe` ("DON'T COOK IT"), hoje interino `Serve` (F6); paciência ×0,5 (`Q-476`); a janela agora manda embora (F5). "Don't make any questions" pode ser lido como "não aperte Take Order", o que não existe mais como escolha. O texto do ElevenLabs ("Don't cook his order") está certo; a legenda não. | **desalinhada** (legenda) |
| ⏳ v_7a552ce2a2 / v_52d1defbaf / v_71c594aea2 café (sanidade 50) | Ir à máquina de café; o HUD destaca a barra. | ok. **Planta o café**: é o 1º café que o Walt "dá". |
| (nenhuma) | Disjuntor desarma como evento obrigatório da N1 (F7). | **falta fala** |
| (nenhuma) | Fechar a janela manda embora a anomalia-cliente (F5). | **falta fala** (decisão em `Q-481`) |
| ✅ v_8d74b17c53 / v_d568870e1a / v_df97670c5b / v_7c27354d0f lição de upgrade (⏳ as 4) | Summary das 6 AM depois da N1; Gear Stand no fundo do restaurante. | ok |
| ✅ v_8df981736c "It's 6 AM… Go outside and check if you find anything useful." | A Gear Stand fica **dentro, no fundo** (o próprio passo diz "In the back of the shop"). | **desalinhada** |
| ✅ v_0fb843d28b "You can choose something. I'm gonna pay for it." | Comprar qualquer upgrade; o jogo completa o dinheiro. | ok |

### Noite 2 (Dia 3)

| Fala | O que a gameplay pede ali | Status |
|---|---|---|
| ✅ v_2022c4e32e "Cheese is in." · ✅ v_7150b19925 "You work late tonight. I'll ring." (`call_day_2`) | Nada (F1). | **morta** (2 gravadas) |
| ✅ v_146c67bf64 "Morning! Told you nights were quiet." · ✅ v_e7276368d3 "Bacon's in." · ✅ v_3b40e44d74 "Grill's hot." (`call_day_after_1`) | Nada (F1). A ironia "nights were quiet" é boa e se perde. | **morta** (3 gravadas) |
| ⏳ v_3c75317b9b "…someone shaking… give him a bread." | ANM-011 `Plain` (vivo): o pedido dele é um hot dog **sem nada**. Cobertura = prato na parede, −15 de sanidade. "A bread" sugere pão sem salsicha. Papel e sussurro dizem "JUST BREAD / NOTHING ON IT", e a fala dele no susto é "I ONLY WANT BREAD." | **desalinhada** (ambígua; decidir o que é "plain") |
| ⏳ v_8bcaa6bb04 "…if someone knocks at the door… it's not me, lock it." | ANM-009 (D, verbo `lock`, a partir da N2): correr e trancar a porta dos fundos antes da 3ª série. | ok. Planta a chave e "it's not me". |
| (nenhuma) | Disjuntor ainda é o evento obrigatório da N2 (F7). | **falta fala** |

### Noite 3 (Dia 4)

| Fala | O que a gameplay pede ali | Status |
|---|---|---|
| ✅ v_3153f74405 "Morning, Rookie. Sleep okay?" · ✅ v_9f14feee91 "Good. Don't think about it." · ✅ v_e245baf6a4 "Potato sticks today. Bigger grill, too." | Nada (F1). | **morta** (3 gravadas) |
| ⏳ v_05009b919e "If the lights turn off, the breaker is outside, go there and fix it." | ANM-020: segurar o disjuntor por 3 s dentro da janela de tempo; o vulto ataca depois. O ElevenLabs diz "hold it", a legenda diz "fix it". | ok (legenda fraca: "fix" ≠ "hold") |
| ⏳ v_49de7dc12d "…someone showing up twice don't serve him." | ANM-004: planejado `NoServe`; hoje interino `Serve` (servir a cópia resolve, sem erro); a janela manda embora. | ok com o plano; o código não cobra (F6, `Q-474`) |

### Noite 4 (Dia 5)

| Fala | O que a gameplay pede ali | Status |
|---|---|---|
| ✅ v_444b37b9a8 "Bank clock's ticking fine. See?" · ⏳ v_b826ff9af4 "Nice and normal." | Nada (F1). | **morta** (1 gravada) |
| ⏳ v_5495df0c7e "…neck problem… don't stare him, just give the food to him and your head down" | ANM-012 `NoLook` (vivo): na entrega, a cabeça dela fora do cone de 30° de quem serve. | ok |
| ⏳ v_84845b02f9 "Someone across the street? Don't look." | ANM-006 (D, a partir da N4): só chega perto enquanto alguém encara; janela fechada = bate e vai embora. | ok |

### Noite 5 (Dia 6)

| Fala | O que a gameplay pede ali | Status |
|---|---|---|
| ⏳ v_1ae72da760 "One Mr. Pickett today, I hope." · ⏳ v_6643e2a67d "That was a joke. Mostly." | Nada (F1). | **morta** |
| ⏳ v_6e89e13998 "…white eyes, TURN OFF THE LIGHTS, and give them the food…" | ANM-013: planejado `Dark` (`Q-471`), hoje interino `Serve`. | ok com o plano; o código não cobra (F6) |
| ⏳ v_8b2fd70edd "…raincoat lady, I love her, serve her and be nice to her." | ANM-005 `Serve` (vivo): deixar ela ir embora = −5 de sanidade de cada um. Com a janela de hoje (F5) ela vai embora **sem custo**. A regra "serve her" perde a aposta. | **desalinhada** (com F5) |

### Noite 6 (Dia 7)

| Fala | O que a gameplay pede ali | Status |
|---|---|---|
| ⏳ v_f36e086018 "She liked you. The lady." · ⏳ v_2825918158 "Forget I said that." | Nada (F1). | **morta** |
| ⏳ v_38eb8400bb "…big head, give them the food fast… red fog… close the window…" | ANM-014 `Hurry` 40 s (vivo) + ANM-021 (C): janela fechada e ficar dentro até a névoa sair. | ok. Com F5, fechar a janela na névoa também manda embora o cabeção que estiver na fila (efeito colateral, sem custo). |

### Noite 7 (Dia 8)

| Fala | O que a gameplay pede ali | Status |
|---|---|---|
| ⏳ v_ec32a5c044 / v_accbaddd4a / v_e07ecc1b65 "nobody lives upstairs" | Nada (F1). | **morta** |
| ⏳ v_aaaf538e6f / v_3c84ea3eda "Get off the floor. Climb the counter." (ElevenLabs: "Wait for the thud.") | ANM-017: pés fora do chão durante a janela de olhar. "Wait for the thud" é a dica da **ANM-015** (papel e sussurro). Mistura as duas regras na noite em que as duas estreiam. | **desalinhada** (ElevenLabs) |
| ⏳ v_aa5a08d1a0 (repetição) | Noite repetida não existe (F4). | **morta** |
| (nenhuma) | ANM-015 estreia na N7 (planejado `Grounded`; papel "WAIT FOR THE THUD"). | **falta fala** |

### Noite 8 (Dia 9)

| Fala | O que a gameplay pede ali | Status |
|---|---|---|
| ⏳ v_79fe1b45ba "You kept your eyes down. Good." · ⏳ v_b938f43cf2 "I counted the lamps." | Nada (F1). | **morta** |
| ⏳ v_70a8507099 / v_0b669707f9 "Shut the window. Keep it shut." | ANM-008: janela fechada e dentro quando o farol acende, até o carro sair. | ok |
| ⏳ v_0db7046e74 (repetição) | F4. | **morta** |
| (nenhuma) | ANM-022 estreia **muda** na N8: ignora a janela, bate a cabeça nela, só sai com a luz da loja apagada (F5). O papel da N8 diz "Banging its head? **BE QUICK**." e o sussurro diz "BEFORE THE GLASS CRACKS": as duas contradizem a regra real. | **falta fala** + papel **desalinhado** |

### Noite 9 (Dia 10)

| Fala | O que a gameplay pede ali | Status |
|---|---|---|
| ⏳ v_0eec32dec6 "Long night, huh? Coffee's on me." · ⏳ v_4550eb2216 "Tell Opal it's for Walt." | Nada (F1). É a pista mais forte do 2º café. | **morta** |
| ⏳ v_951af0016c "…steps at the roof… cat. Don't look up." | ANM-019: não olhar para cima enquanto ele anda. | ok |
| (nenhuma) | ANM-016 estreia na N9 (papel "SERVE HIM. Don't stare back"; interino `Serve`). | **falta fala** |

### Noite 10 (Dia 11) + final

| Fala | O que a gameplay pede ali | Status |
|---|---|---|
| ⏳ v_9a2f7f9949 / v_319d2c7703 / v_909f41e668 "About the knocking. / That wasn't me. / Tonight's the last. I promise." | Nada (F1). "I promise" é a promessa do final, e se perde. | **morta** |
| ⏳ v_140f750fc0 "Last night, Rookie." | Abertura da N10. | ok |
| ⏳ v_37eb690baf / v_a5a48fc8ed "Lamps dying outside? Shop light off. / Keep it off till they're back." | ANM-010 (restaurante): luz da loja apagada (ou janela fechada) enquanto a cabeça entra; na N10 às 5:45 os postes só voltam às 6:00. "Dying" está na lista proibida (`world.md` §1; `walt-calls-lore.md` §6). | ok na regra; **contradiz** a lista de palavras |
| ⏳ v_7caee4e9eb (repetição) | F4. | **morta** |
| ⏳ v_86b4351c71 rádio "Run INSIDE the Mart, now!" | Não existe Mart no restaurante (F9); o client usa a outra linha. | **morta** + **contradiz** DEC-307 |
| ⏳ v_d9a7a5ee99 rádio "Kill the lights in here, NOW!" | É a linha que toca no restaurante (`SHOP_LINE`). "Kill" é proibida. | **contradiz** a lista de palavras |
| (nenhuma) | ANM-023 estreia na N10 (papel "CHECK THE CAMERAS"). | **falta fala** (o papel já cobre; decidir em `Q-483`) |
| ⏳ v_f271c54c14 … v_f3e7afb49b (9 falas A1) | Hoje: o final A1 (F8). Com o Segundo Café (proposta sem DEC): as mesmas 9 falas viram **isca**. "I watched every one. From in here." supõe o Mart (F9). | ok nos dois finais; "From in here" **desalinhada** com o mapa |
| ⏳ v_4e6cef12f6 "Morning, Marigold." | A1: fecha a cena. Segundo Café: **sai** da sequência principal. | depende de `Q-480`: **não gravar ainda** |
| (nenhuma) walt_dark "Forty years, Rookie. Forty years of nights." · "Now I get the mornings." · rádio "...welcome to the other side, Rookie..." | Segundo Café (b), (e), (f). | **falta fala** (3; sem *kill/die*) |
| Segundo Café × DEC-076 / DEC-177 | Walt em pessoa depois que o céu volta à noite, na despensa, maior, agarrando o jogador. DEC-076: em pessoa só no amanhecer da N10. DEC-177 (nota): "Walt segue não sendo anomalia". DEC-172/DEC-023: Mild, sem violência ("joga o jogador na rua", "mãos puxam"). | **contradiz** decisões em vigor até sair a DEC nova (`Q-480`) |

### Fim da run e noites repetidas (qualquer noite)

| Fala | O que a gameplay pede ali | Status |
|---|---|---|
| ⏳ v_cea0c2176a "Same night, Rookie. Same rules." | Noite repetida não existe (`Chances = 0`, F4). | **morta** |
| ⏳ v_80f4cae4c8 / v_32b25cfd5c "You watched it… Breathe." (`call_lost_critical`) | F4; e "watched it" vem da regra crítica antiga de olhar (Walker), que não existe mais. | **morta** + **desalinhada** |
| ⏳ v_e2948c76ce / v_8d823b58bf / v_089cce41c0 (`call_lost_last_chance`) | F4. | **morta** |
| ⏳ v_d91e854ce1 "That's two, Rookie." | Fim da run na 1ª noite perdida (F4). | **desalinhada** |
| ⏳ v_d30128cf6d "No more nights for you." · ⏳ v_fe4055ecce "Go home. You did well." | Citadas na tela de fim de run. Com a derrota proposta (batida + "Rookie? It's me. It's Walt. Open up.") "Go home" vira ironia boa. | ok |
| ⏳ v_67ee73c3b4 … v_67ad984e40 (6 dias sem fim) | Sem dia de turno e sem modo sem fim ligado na run (F1). | **morta** (confirmar se existe modo sem fim) |

### Ligação falsa e rádio (contexto, `Hallucinations.luau`, DEC-312)

| Ponto | Status |
|---|---|
| "Blank face? Window shut." (N1), "Head on backwards? Window." (N4): com a janela de hoje (F5), essas falas agora **batem** com a gameplay e **contradizem** a ligação real da noite ("ignore him", "head down"). Duas regras para a mesma anomalia. | **desalinhada** entre canais |
| "Someone just standing there? Eyes down." está na N5; o vulto (ANM-006) estreia na N4. | desalinhada (leve) |
| "Won't leave? Shop light off." (Default): é a regra real da ANM-022, só que dita na ligação falsa e não na real. | ok, mas fora do lugar |
| Pistas do Segundo Café já plantadas: "Opal's pouring two" (N6), rádio "the second coffee was mine once" (N6), "don't take his coffee" (N9), "I'll bring the coffee myself" (N10), "he'll offer you the shift" (N10). | ok, alinhadas com o ending novo |

### Contagem

- **Gravadas que nunca tocam:** 12 (manhãs dos "dias" 1 a 5).
- **Pendentes que nunca tocariam:** ~29 (14 da manhã dos "dias" 5 a 11, 3 repetições, 6 de noite perdida/repetida, 6 de dias sem fim) + o rádio do Mart. **Não gravar** antes de `Q-478` e `Q-479`.
- **Falas de regra que faltam:** disjuntor N1–N2, janela universal, ANM-015, ANM-022, ANM-016, ANM-023, e as 3 do Segundo Café.

---

## 2. Os problemas mais graves

1. **As ligações da manhã estão mortas** (F1; **DEC-360**: confirmado, não existe mais dia). 12 gravadas, ~14 pendentes. Toda a trilha de pistas do dia (Pickett, "nobody lives upstairs", "I counted the lamps", "Coffee's on me / Tell Opal", "That wasn't me", "Tonight's the last. I promise") nunca chega ao jogador. O arco do Walt hoje é só "regra, regra, regra". → `Q-478`.
2. **Ending novo sem DEC e sem cena** (F8). O código aponta para `second_coffee`, que não existe; toca o A1. O Segundo Café bate de frente com DEC-075, DEC-076, a nota de DEC-177 e o Mild (DEC-172). Faltam 3 falas. "Morning, Marigold." não deveria ser gravada ainda. → `Q-480`.
3. **A janela universal não tem fala** (F5). **DEC-361:** a saída é intencional e custa o dinheiro (as regras do Walt pagam mais; a janela é a saída pobre e segura). O texto abaixo é a leitura de antes da DEC. Ninguém ensina que fechar a janela tira a anomalia-cliente. Se o jogador descobrir, as regras do Walt (001, 004, 011, 012, 013, 014, 015, 016, 023) viram opcionais e a Raincoat Lady sai sem custo. Os dois canais do Walt já dizem coisas opostas (ligação real "ignore him" × falsa "Window shut"). → `Q-481`.
4. **ANM-022 sem fala e com a dica errada.** Estreia muda na N8; o papel e o sussurro dizem "BE QUICK", e a regra real é "a janela não segura; luz da loja apagada". → `Q-482`.
5. **Fim da run errado** (F4). "That's two, Rookie." numa run que termina na 1ª noite perdida; as 9 falas de noite repetida/perdida nunca tocam. → `Q-479`.
6. **Estreias sem fala e disjuntor fora de ordem** (F7). O jogador religa o disjuntor na N1 e na N2 sem ninguém ter ensinado, e a N1 manda "não fique lá fora". ANM-015, ANM-016 e ANM-023 estreiam sem fala do Walt. → `Q-483`.
7. **Texto da regra ≠ verbo real.** Shaker "give him a bread" (o pedido é um hot dog sem nada); crawler "Wait for the thud" (é a dica do floater); "no face… don't make any questions"; upgrade "Go outside" (a Gear Stand fica no fundo); "dying" e "kill" (palavras proibidas); rádio do Mart. → `Q-484`.
8. **Regras faladas que o código não cobra** (F6): 001, 004 e 013 rodam com o interino `Serve`. Isso já está em `Q-474`; o roteiro deve ser gravado com a regra **planejada**, para não regravar depois.

---

## 3. Proposta de reestruturação: o arco do Walt em 10 noites (Provisória)

### 3.1 Formato de cada ligação (Provisório)

Só existe uma ligação por turno (7 PM). Proposta:

| Linha | Conteúdo | Limite |
|---|---|---|
| 1 | **Abertura**: reação à noite passada + 1 peça da lore (o que era a "manhã") | ≤ 6 s |
| 2 | regra da estreia 1 (sinal + resposta) | ≤ 12 s |
| 3 | regra da estreia 2, ou o lembrete da janela/exceção | ≤ 12 s |

- A última linha continua escrevendo o papel (`HintService:WaltSaysRule`).
- Nenhuma abertura começa com "Morning" (o Call é às 7 PM), a não ser que o dono religue a manhã (`Q-478` b).
- As regras usam as **mesmas palavras** do papel e do sussurro (`Hints.luau`, `AnomalyHints.luau`): "DON'T COOK IT", "JUST BREAD", "HOLD IT", "DON'T LOOK AT HER", "LIGHTS OFF", "SERVE HER", "BE QUICK", "UP ON THE COUNTER", "WAIT FOR THE THUD", "Keep it shut", "DON'T LOOK UP", "Shop light OFF", "CHECK THE CAMERAS".

### 3.2 Arco em três atos (Provisório)

Fio: **o café**. O Walt "dá" um café em cada ato; o 2º café do final é a armadilha (`walt-calls-lore.md` §3, opção B).

| Ato | Noites | O Walt na superfície | O que planta | Fio do café |
|---|---|---|---|---|
| 1. O chefe gente boa | N1–N3 | caloroso, ensina tudo, desculpas banais | já ensinou "muitos"; só ele tem a chave; "it's not me" | N1: "Have some coffee." (ligação do café) |
| 2. Ele sabe demais | N4–N7 | carinhoso, mas sabe o que vai acontecer | assiste de algum lugar; compara com "o último"; Opal serve dois | N4–N6: "Opal's pouring two." / "Coffee's on me." |
| 3. A oferta | N8–N10 | mais íntimo, promete o fim | "it's not here for me"; "that wasn't me"; "the last one"; "I'll bring the coffee myself" | N10: "I'll bring the coffee myself." → Segundo Café |

### 3.3 Linha 1 (abertura) por noite: reaproveitando o que existe (Provisório)

| Noite | Abertura proposta | Origem | Regravar? |
|---|---|---|---|
| N1 | "Evening, Rookie. Some customers look off." | já existe | não |
| N2 | "Told you nights were quiet. Heh." | ✅ v_146c67bf64 sem o "Morning!" | sim (texto curto) |
| N3 | "Sleep okay? …Good. Don't think about it." | ✅ v_3153f74405 + v_9f14feee91 sem "Morning" | sim, ou só a 2ª (✅ já serve) |
| N4 | "Bank clock's ticking fine. See?" | ✅ v_444b37b9a8 | **não** (serve como está) |
| N5 | "One Mr. Pickett tonight, I hope. …Joke. Mostly." | v_1ae72da760 + v_6643e2a67d (eco das cópias da N3) | ⏳ (ajustar "today") |
| N6 | "She liked you. The lady. …Forget I said that." | v_f36e086018 + v_2825918158 (depois da Raincoat da N5) | ⏳ |
| N7 | "Ever notice nobody lives upstairs? …At night, I mean." | v_ec32a5c044 + v_accbaddd4a ("daytime" → "at night") | ⏳ |
| N8 | "You kept your eyes down. Good. I counted the lamps too." | v_79fe1b45ba + v_b938f43cf2 | ⏳ |
| N9 | "Long night, huh? Opal's pouring two tonight. One's for you." | v_0eec32dec6 + v_4550eb2216 reescritas | ⏳ (pista direta do 2º café) |
| N10 | "Last night, Rookie. That knocking wasn't me. I'll bring the coffee myself." | v_140f750fc0 + v_319d2c7703 + fake_call N10 | ⏳ |

**Texto final das aberturas (narrative-writer, TASK-655, 2026-10-23; Provisório).** Substitui a tabela acima como base.
Roteiro com o campo ElevenLabs em `tools/voice/elevenlabs_script.md` → "PRONTAS PARA GRAVAR" → "Aberturas". Cada uma ≤ 6 s,
sem "Morning", sem regra, `[whisper]` no fecho.

| Noite | Abertura (legenda) | Peça da lore | Origem | Mudou em relação à base |
|---|---|---|---|---|
| N1 | Evening, Rookie. Some customers look off. | o late crowd existe | v_6ea4e48840 (legenda igual; ElevenLabs encurtado) | não |
| N2 | You came back. Told you nights were quiet. | "you came back": nem todo Rookie volta | ✅ v_146c67bf64 reescrita | + "You came back" |
| N3 | Sleep okay? Good. Don't think about it. | ele sabe no que pensar (a batida da N2) | ✅ v_3153f74405 + ✅ v_9f14feee91 | não |
| N4 | You look tired, Rookie. Coffee's on me tonight. | ele **vê** o Rookie (skin cansada, DEC-370); café | "Coffee's on me" de v_0eec32dec6; nova | sai o relógio do banco |
| N5 | Just one of everybody tonight, I hope. Joke. Mostly. | ele sabia das cópias da N3 | v_1ae72da760 + v_6643e2a67d | sem o nome Pickett |
| N6 | She liked you. The lady. Forget I said that. | ele conhece a Raincoat Lady de perto | v_f36e086018 + v_2825918158 | não |
| N7 | You're starting to look the part, Rookie. | a noite transforma o Rookie (skin da noite, DEC-370) | nova | sai "nobody lives upstairs" (restaurante sem andar de cima) |
| N8 | You kept your eyes down. Good. I used to count the lamps. | ele já fez as noites | v_79fe1b45ba + v_b938f43cf2 | "I counted" → "I used to count" |
| N9 | Long night, huh? I'm saving you a coffee. | o 2º café (armadilha) | v_0eec32dec6 reescrita | sem Opal (fora do restaurante) |
| N10 | Last night, Rookie. I'll bring the coffee myself. | ele vem em pessoa no amanhecer (DEC-076) | v_140f750fc0 + `fake_call` N10 | sai "That knocking wasn't me" (não cabe em 6 s) |

Fio do café: N1 (ligação do café) → N4 → N9 → N10 → Segundo Café. Sem destino: v_444b37b9a8, v_ec32a5c044, v_accbaddd4a,
v_e07ecc1b65, v_4550eb2216, v_9a2f7f9949, v_319d2c7703, v_909f41e668 (guardadas).

### 3.4 Regras que faltam ou mudam (texto Provisório, a revisar pelo narrative-writer)

| Noite | Regra | Texto proposto (legenda) |
|---|---|---|
| N1 | disjuntor (evento obrigatório) | "Power trips? Breaker's out back. Hold it." |
| N1 | janela universal (só se o dono quiser que o Walt ensine, `Q-481`) | "Something wrong at the window? Shut it. They'll go. So does the money." |
| N1 | blank folks | "No face? Blank ticket? Don't cook it. It leaves." |
| N2 | shaker | "Shaky one's just hungry. Plain. Nothing on it." |
| N3 | blackout | "Lights out? Breaker outside. Hold it till they're back." |
| N7 | crawler + floater | "Scratching under the floor? Up on the counter." / "Feet not touching? Wait for the thud." |
| N8 | head banger | "Banging his head on the glass? The window won't stop him. Shop light off." |
| N9 | starer | "Never blinks? Serve him. Don't stare back." |
| N10 | Hush | "Lamps going out? Shop light off. Keep it off." (sem "dying") |
| N10 | on camera | "Not sure? Check the cameras." (opcional: o papel já diz) |
| rádio N10 | Hush | "The lamps are going out! Lights off in there, NOW!" (sem "kill", sem Mart) |
| upgrade | lembrete | "Six A.M. Shift's over. Gear Stand, in the back. Find something useful." |

### 3.5 Final e derrota (Provisório, depende de `Q-480`, `Q-479`)

- Vitória: Segundo Café como descrito pelo coordenador (a)–(h). As 9 falas A1 ficam iguais (isca). "Morning, Marigold." sai da sequência principal. Faltam 3 falas (walt_dark ×2, rádio ×1).
- Derrota (run acaba na 1ª noite perdida): "That's it, Rookie." · "No more nights for you." · "Go home. You did well." → batida → "Rookie? It's me. It's Walt. Open up." (já existe no ANM-009) + vulto dele na janela.
- Noite repetida e noite perdida: **não gravar** enquanto `Chances = 0`.

### 3.6 Lista de gravação recomendada (Provisória)

- **Gravar já** (não dependem de decisão): N1–N10 regras que já batem (v_84845b02f9, v_5495df0c7e, v_38eb8400bb, v_0b669707f9, v_951af0016c, v_8bcaa6bb04, v_6ea4e48840, café ×3, lição de upgrade ×4, tutorial "outros" ×2).
- **Segurar**: tudo marcado **morta** (as de manhã estão marcadas "morta — sem dia" no roteiro, com o destino proposto), "Morning, Marigold.", "That's two", e as falas com texto a corrigir (`Q-484`).
- **Atualizar o cabeçalho do roteiro**: a run começa na Noite 1 com tutorial; não há turno de dia.

---

## 4. Critérios de aceite da reestruturação

- Toda anomalia com erro possível tem fala do Walt na noite em que estreia (ou o dono marca como "descoberta", `Q-483`).
- Ligação, papel e sussurro dizem a mesma regra com as mesmas palavras.
- Nenhuma fala gravada fica num gatilho que não dispara (conferir F1, F4 antes de cada lote).
- Nenhuma fala usa *die, dying, dead, kill, blood, hurt, monster…* (`world.md` §1).
- Nenhuma abertura às 7 PM começa com "Morning".
- Cada ligação de noite: ≤ 3 linhas, ≤ 12 s por linha, ≤ 45 s no total (`BossCalls.Rules.NightMaxSeconds`).
- Nenhuma pista de noite N revela peça de noite > N.
