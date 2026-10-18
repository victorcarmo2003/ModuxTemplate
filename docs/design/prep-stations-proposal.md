Status: Rascunho

# Preparo em estações separadas, com o prato na mão (TASK-478)

Autor: game-designer + level-designer, 2026-10-18. Proposta (nada aqui é Aprovado; vale como **Provisório** até DEC do dono).
Fontes: feedback do dono no Play de 2026-10-18 (abaixo), **DEC-223** (modo focado), **DEC-271/272** (pratos-slot, estações
físicas), **DEC-275** (todos em paralelo), **DEC-278** (anomalia não se confunde com o fluxo), **DEC-280/282/285** (retirada no
balcão, porta dos fundos, estoque infinito na despensa), **DEC-292** (apagão: só o disjuntor salva);
`design/restaurant-flow.md` (FEAT-044, FEAT-045, FEAT-049), `tech/prep-mode.md`, `tech/prep-3d.md`,
`levels/MAP-01-r4-restaurant.md` (§5.4, §5.5, §5.6); código atual `src/Plate` (PlateService), `src/Kitchen`, `src/Prep`.
Perguntas: **Q-361 a Q-366** (`open-questions.md`).

> Fala do dono (Play 2026-10-18, resumida): "Quero muito separar a estação de trabalho em etapas, em vez de uma coisa só. Você
> anda segurando um prato e leva por cada etapa: primeiro corta o pão, o pão vai para o prato, dá para pôr o prato numa mesa;
> depois pega a salsicha grelhada e põe no prato; depois leva o prato à mesa de condimentos. Acho que o fluxo que eu sugeri está
> meio bagunçado, então precisa melhorar."

---

## 0. Resumo (recomendação)

**Opção C — "o prato viaja, as estações têm saída".** O pedido confirmado no tablet cria o prato **#n** na **passa** (a mesa de
montagem de hoje). O jogador **pega o prato vazio** e passa por **3 estações fisicamente separadas** no fundo: **Pão** →
**Grelha** → **Condimentos**, e entrega no **PICKUP** (ou deixa na **prateleira de saída** ao lado dele). Cada estação faz o
trabalho **direto no prato que está na mão** e tem uma pequena **saída** (cesta de pães cortados; as salsichas prontas
ficam na grelha), para que um colega adiante o serviço. O prato só pousa em **apoios marcados** (passa, um por estação,
saída). Um brilho Mustard mostra a **próxima parada** do prato equipado.

---

## 1. O que está "bagunçado" hoje (diagnóstico)

| # | Problema | De onde vem |
|---|---|---|
| 1 | **Uma bancada faz tudo.** O `Station_n` (vistas `Board`/`Build`/`Toppings` na mesma tábua, `PrepService:StepNear`) não tem etapas visíveis no mundo: o jogador não "anda" pelo hot dog | DEC-223 + o binding atual (`TRL/Kitchen/Station_1..4/Mount/*`) |
| 2 | **Três coisas diferentes viajam**: pilha de pães, pilha de salsichas e o prato. O jogador pensa em hotbar, não em hot dog | FEAT-045 (Tools `bun_sliced`, `sausage_grilled`, `hot_dog`) |
| 3 | **O prato só existe no fim** (`plate_take` exige pão **e** salsicha). Antes disso o pedido é um fantasma na passa: não dá para "levar o pedido" | `PlateService` (cabeçalho, `plate_take`) |
| 4 | **"Fill All", toque, segurar** na passa: muitos prompts juntos, difícil no celular | FEAT-044 |
| 5 | **A mesa de trabalho invade a porta** | TASK-477 (outra sessão) |

O que o dono propôs resolve 1–3. O que pode ficar bagunçado no fluxo dele, se feito literalmente: **solo** sem lote (um prato
por vez, ida e volta), **co-op parado** (só quem segura o prato trabalha), **muitos pedidos** (onde ficam os pratos, qual é de
quem). As opções abaixo tratam isso de formas diferentes.

---

## 2. Opções de fluxo

Peças comuns às três: tablet (FEAT-043) sem mudança; entrega no balcão (FEAT-046) sem mudança; grelha cozinha sozinha em
paralelo e queima (FEAT-045); estoque infinito na despensa, limite por estação (DEC-285); nota calculada só em `Grade.luau`.

### Opção A — "Overcooked puro": só o prato

- **Na mão:** só pratos (1 por vez; Q-362). Nenhum ingrediente avulso.
- **Etapas:** passa (pega o prato #n) → **Pão**: com o prato equipado, "Cut Bun" corta e o pão cai no prato → **Grelha**:
  "Put Dog" tira uma salsicha pronta da grelha **direto para o prato** → **Condimentos**: o prato pousa na tábua de condimentos,
  seção `Toppings` → **PICKUP**.
- **Pôr o prato:** apoios marcados (passa e um em cada estação).
- **Co-op:** quem não tem prato só pode pôr salsicha crua na grelha, atender o tablet ou cuidar de anomalias. Duas pessoas
  com prato disputam a mesma tábua.
- **Vários pedidos:** um prato por pessoa; os outros esperam na passa.
- **Prós:** leitura imediata, é o fluxo do dono ao pé da letra, menos Tools. **Contras:** solo lento (3 voltas para 3 pedidos);
  em 3–4 jogadores a fila na tábua de pão vira gargalo; quem está sem prato fica olhando (fere DEC-275).

### Opção B — "Linha parada": pratos fixos na passa, ingredientes viajam (o de hoje, arrumado)

- **Na mão:** pilhas (pães ×3, salsichas ×3) e, no fim, o prato pronto.
- **Etapas:** corta pães em lote → leva a pilha à passa → "Fill All" → coleta salsichas em lote → passa → pega o prato pronto →
  condimentos → PICKUP.
- **Prós:** lote eficiente, quase tudo já existe no código (`PlateService`, pilhas, `Fill All`). **Contras:** é exatamente o que o
  dono chamou de bagunçado: três coisas na mão, muitos prompts na passa, o hot dog não "anda"; não atende o pedido.

### Opção C — "O prato viaja, as estações têm saída" (**recomendada**)

- **Na mão:** pratos (**até 2**, as Tools `hot_dog` de hoje, agora desde o prato vazio; Q-362). Sem pilhas avulsas.
- **Etapas e o que acontece em cada uma:**

| Parada | Com prato equipado | Sem prato (para adiantar) | Saída da estação |
|---|---|---|---|
| 1. **Passa** (`PLATE-n`) | "Put Plate" pousa o prato num apoio livre | "Take Plate #12" (toque) pega o prato **em qualquer estado**, até vazio | — |
| 2. **Pão** (`CUT-n`) | se a cesta tem pão cortado: toque = pão no prato (0 s). Senão: "Cut Bun" abre a seção `Board`, corta, o pão **desliza para o prato** e a seção fecha | "Cut Buns" corta em sequência para a **cesta** (até 4) | **cesta de pães cortados** (4; cada pão guarda a nota `bun_cut`) |
| 3. **Grelha** (`GRILL-n`) | "Add Dog" pega a pronta **mais perto de queimar** direto para o prato (só com pão; regra de FEAT-045). Na seção `Grill`: arrastar a pronta até o ícone do prato | pôr cruas, virar, descartar queimada (seção `Grill` como hoje) | as **prontas na grelha** (o relógio de queimar continua) |
| 4. **Condimentos** (`COND-n`) | "Add Toppings #12": o prato pousa na tábua, seção `Toppings`, só as tigelas do pedido acendem; **Done** devolve o prato à mão. K = 0 pula esta parada | — | — |
| 5. **Saída / PICKUP** | "Hand Over" no `PICKUP` (como hoje) **ou** "Put Plate" na **prateleira de saída** (2 apoios) | "Hand Over #12" da prateleira, por qualquer um | prateleira de saída (2) |

- **Pôr o prato:** só em **apoios marcados**: os 8 da passa, **1 por estação** (o prato fica ali enquanto a seção está aberta e
  se o jogador sair dela) e os 2 da saída. Nunca no chão, nunca em qualquer superfície (Q-363).
- **Próxima parada:** com um prato equipado, a estação de que ele precisa acende (contorno Mustard + ícone sobre a placa);
  a billboard do prato mostra pão / salsicha / complementos em cinza (falta) ou cheio (feito), como a FEAT-044.
- **Ordem:** pão → salsicha → condimentos, fixa (Q-364). Condimento antes da salsicha não abre.
- **Prós:** é o fluxo do dono, com as duas folgas que tiram a bagunça: a **saída** de cada estação deixa um colega adiantar
  serviço sem segurar prato, e **2 pratos na mão** dão lote ao solo. Reaproveita quase tudo (§5). **Contras:** mais um estado
  por estação (a cesta); o prato com 2 Tools pede cuidado de leitura na hotbar (qual está equipado).

### Comparação

| Critério | A | B | C |
|---|---|---|---|
| É o que o dono pediu (prato anda pelas etapas) | sim | não | sim |
| Solo com 3–4 pedidos | fraco (1 prato) | bom (lote) | bom (2 pratos + cesta) |
| Co-op 4p sem ninguém parado | fraco | médio | **bom** (saídas) |
| Leitura (o que fazer agora) | ótima | fraca | ótima (próxima parada) |
| Prompts no celular | poucos | muitos na passa | poucos (1 por estação) |
| Reuso do que existe | médio | alto | **alto** |
| Escopo | médio | baixo | médio |

---

## 3. Como a opção C joga

### 3.1 Co-op (1–4 jogadores)

Nenhum papel é fixo; o layout os sugere.

| Party | Divisão natural |
|---|---|
| 1 | faz o laço inteiro com 2 pratos: pega #12 e #13 → corta os 2 (ou 1 corte + cesta) → põe cruas na grelha **antes** de cortar → condimentos → entrega. Tablet e anomalias no meio |
| 2 | **A** (fundo): tablet + grelha + cesta de pães · **B** (frente): pratos, condimentos, entrega. Os dois cuidam das anomalias |
| 3 | caixa/drive-thru + noite · fundo (grelha e cesta) · montador (pratos → condimentos → entrega) |
| 4 | caixa · grelheiro · padeiro (cesta) e estoque · montador/expedição. Com `COND-2`, 2 montadores (um do salão, um do drive-thru) |

Regras de disputa: **seção focada = 1 jogador por estação** (trava como hoje, `PrepSeats`); a **saída** (cesta, prontas na
grelha, prateleira) é tocável por todos ao mesmo tempo, o servidor resolve (DEC-259, toast de recusa ao 2º). Prato na mão é
de quem segura; no apoio, de qualquer um.

### 3.2 Vários pedidos em paralelo

- Cada pedido confirmado cria o prato **#n** num apoio livre da passa (fantasma de hoje, agora pegável). O teto de pedidos
  abertos continua `ActivePlates` (1p 4 · 2p 6 · 3–4p 8) e o "Kitchen full" do tablet (FEAT-043/044) não muda.
- O prato mais antigo pulsa (FEAT-044). Com 2 pratos na mão, a estação age no **equipado**; segurar a interação 0,5 s na
  cesta / grelha = "para os dois" (substitui o "Fill All" da passa).
- Pedido de dupla (FEAT-038): 2 pratos, um por linha, entregues juntos (como hoje).
- Cliente desistiu: o prato vira órfão (cinza "?", FEAT-044) **onde estiver** (na mão, no apoio). Pedido idêntico reaproveita.
- Drive-thru: prato com ícone de carro; nasce no apoio mais a leste; sua parada de condimentos é o `COND-2` (perto da janela).

### 3.3 Anomalias (sair da estação)

| Situação | Regra proposta |
|---|---|
| Anomalia chama (disjuntor, porta, câmeras…) com seção aberta | `PrepService:Kick` / `CueLock` como hoje; o prato fica **no apoio da estação** e o jogador volta a ele, ou o leva na mão |
| Ir resolver segurando prato | permitido: disjuntor, persiana, tranca e câmeras funcionam com o prato equipado (prompt não exige mão livre) |
| Grelha sem ninguém | continua cozinhando e queimando (pressão do Overcooked; Heat Lamp UPG-016 alivia) |
| **Apagão** (DEC-292, 30 s) | **a grelha pausa** (sem fogo e sem queimar) e as seções fecham; os prompts das estações apagam até religar. Assim o apagão pune pelo disjuntor, não em dobro pela comida (Q-365) |
| Prato nos apoios | **nunca muda sozinho**. Nenhuma anomalia mexe em prato sem sinal visível (DEC-278: "prato a mais" vetado) |
| Erro de anomalia | −sanidade (DEC-277), sem tocar nos pratos |

Ganchos possíveis para o dono das anomalias (só citação): pão que sai mordido na cesta (ANM-002 já é "pão mordido"), salsicha
que não doura, tigela de condimento que não acende para ninguém.

### 3.4 Café

O café é da sanidade (cafeteira `R-COFFEE`, DEC-125), não do pedido: **fica fora do laço**, na parede oeste. Para não brigar
com os 2 pratos na hotbar, proposta: na cafeteira, **"Drink Here"** (toque, bebe no lugar, sem Tool); a caneca para viagem
continua para quem quer levar (Q-366).

### 3.5 Tempo por pedido (solo, K = 2, sem upgrade, conferir no playtest)

| Passo | s |
|---|---|
| Pegar prato na passa | 0,3 |
| Caminhar passa → Pão → Grelha → Condimentos → PICKUP (~47 studs a 16/s) | ~3,0 |
| Pão: seção `Board` (entrar/sair 0,65 + corte 1,0) | 1,65 |
| Grelha: pôr crua (em lote, por pedido) + pegar pronta | ~1,5 |
| Condimentos: seção `Toppings` | ~5,6 |
| Entregar | 0,5 |
| **Cozinha por pedido** | **~12,5** (FEAT-049 somava ~16,5 para grelha + pão/montagem + condimentos + expedição) |

Com 2 pratos a caminhada se divide por 2. Não pede mexer nas paciências da FEAT-048.

---

## 4. Layout na cozinha atual (MAP-01 r4)

Referencial do `MAP-01-r4-restaurant.md` §2 (+X leste, +Z sul; no place `(−x, y, 67,887 − z)`). Medidas são proposta do
level-designer; **conferir no place depois da TASK-477 e da sincronização das edições à mão do dono** (memória
`studio-hand-edits`). A bancada única do fundo vira **três móveis separados** com vão entre eles, cada um com placa
pendurada (ícone: pão, chama, bisnaga), para que as etapas se leiam como lugares diferentes.

```
  X →   25        30        35        40        45        50        55      60
        |         |         |         |         |         |         |       |
  Z54   Wc$cccscsccPccccccccccccccccLccTcccW     $ pote · s s = SAÍDA-1/2 · P PICKUP · L persiana · T TAB-1
  Z56   W..........p...................p...W     p = poses do jogador (PICKUP, TAB-1)
  Z58   W.......@....@....@....@...........J     corredor da frente (5,4); @ = PS-1..4; J = DT-WIN
  Z60   Wcc.............................m.PJ     c = R-COFFEE; m/P = DT-PC
  Z62   Wcc...AAOAOAAOAOAAOAOAA........J         PASSA X 31,5..52, O = apoios PLATE-1..8 ; corredor leste 7,5
  Z64   Wu................................S      u = BIN-K; S = KSW
  Z66   W..................................F     corredor do fundo (5,0); F = PHONE-R
  Z68   W......MMMMM.GGGGSSgggg.BBXXXXX.mmmW     M COND-1 · G GRILL-1 · S STOCK · g GRILL-2 (upgrade) · B BUN · X CUT-1/2 · m COND-2
  Z70   W......MMMMM.GGGGSSgggg.BBXXXXX.mmmW     "." entre móveis = vão de 1,0 (móveis separados)
  Z72   WPPPPPWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW     PPPPP = DOOR-P (X 25,5..30,5): nada da bancada antes de X 32
  Z74   W........................W               despensa (rev. 3), baias de caixas infinitas (DEC-285)
  Z78   WDDDDDDbbbbbbbbbbbbbbbbbbW               D = passagem para DOOR-B · b = baias
```

ASCII ±1 stud; a tabela manda.

| ID | Peça | X (largura) | Z | Prompt (borda, Y 3,3) | Nota |
|---|---|---|---|---|---|
| — | **Folga da porta** | 25,5..32 | 66..72 | — | nada de bancada/prop; DOOR-P abre livre (corrige o tipo de problema da TASK-477) |
| `COND-1` | **Mesa de condimentos** (salão), móvel próprio, 5 tigelas | 32..36,5 | 68,5..71,5 | (34,25; 68,9) | última parada antes do PICKUP: sai pelo corredor oeste (X 27..31) até (36; 56,6) |
| `GRILL-1` + coifa | **Bancada da grelha** (AST-120) | 37,5..41,25 | idem | (39,4; 68,9) | coifa KP `extractorhood` vem junto; `GAS-1` passa para a parede do fundo atrás da grelha, (39,4; 71,8) Y 4,5 |
| `STOCK` | Cooler de salsichas cruas (mesmo móvel da grelha) | 41,5..43,5 | idem | (42,5; 68,9) | Restock pelas caixas DOGS |
| `GRILL-2` | Grelha 2 (UPG-015), mesmo móvel | 43,75..47,5 | idem | (45,6; 68,9) | sem o upgrade: tampo vazio com fantasma de compra |
| `BUN` + `CUT-1` | **Bancada do pão**: caixa de pães + tábua 1 + **cesta** | 48,5..53 | idem | Restock (49,4; 68,9) Y 3,6 · corte (51,75; 68,9) | cesta de 4 pães cortados no canto da tábua |
| `CUT-2` | Tábua 2 (2ª pessoa no pão), mesmo móvel | 53,25..55,75 | idem | (54,5; 68,9) | |
| `COND-2` | **Molheira do drive-thru** (3 tigelas), móvel próprio | 56,75..59,5 | idem | (58,1; 68,9) | parada dos pratos com carro; 3,2 do `PHONE-R` |
| `PASSA` (`ASM`) | Mesa de montagem → **passa** | **31,5..52** (encurtada a leste) | 61..63,5 | `PLATE-1..8` em X 33 · 35,5 · 38 · 40,5 · 43 · 45,5 · 48 · 50,5 | libera o **corredor leste** (X 52..59,5, 7,5 livres) que liga frente e fundo |
| `SAÍDA-1/2` | **Prateleira de saída** no balcão | (31; 55) e (33,5; 55) | — | prompts a 2,5 do `PICKUP` (36) e do pote (27,5) | "Put Plate" por dentro; "Hand Over #n" por dentro; com Now Serving (UPG-026) o cliente pega dali |
| apoio de estação | 1 por estação (`Att_PlateSpot`) | no tampo, ao lado do prompt | — | — | onde o prato fica com a seção aberta |

**Rotas** (sem cruzar ninguém parado em prompt): salão = passa → corredor do fundo para leste (Pão) → oeste (Grelha) →
oeste (COND-1) → corredor oeste → PICKUP. Drive-thru = passa → Pão → Grelha → leste (COND-2) → corredor leste → `DT-WIN`.
Larguras: corredor da frente 5,4; do fundo 5,0; oeste 4,2 (cafeteira e lixeira); leste 7,5 (pose do `DT-PC` dentro dele,
sem bloquear). Distância entre prompts vizinhos ≥ 2,5 (DEC-066), exceto `BUN`↔`CUT-1` (2,35, alturas e ações diferentes:
Restock é segurar, corte é toque); se o teste no celular errar, a caixa de pão vai para baixo do tampo.

**Câmera da seção** (`CamAnchor_*`, `Focus_*`, `Att_Stand_*`): um conjunto por estação física (`CUT-n` → `Board`,
`GRILL-n` → `Grill`, `COND-n` → `Toppings`), não mais 4 conjuntos por `Station_n` na mesma bancada.

---

## 5. O que muda × o que se reaproveita

### 5.1 Contra o modo focado atual (DEC-223, `tech/prep-mode.md`, `prep-3d.md`)

| Peça | Destino | Detalhe |
|---|---|---|
| `Grade.luau`, `Content.Prep.Tolerances`, `/dev prep grade` | **continua** | a nota de cada ingrediente viaja no prato (atributos como hoje no `hot_dog`) e `Grade` fecha na entrega |
| Gestos (`slice`, `trace`, `slide`, `taps`, `hold`), Assist, reduced motion, cursor virtual | **continua** | dentro das seções |
| Câmera `Prep` e vistas `Board`/`Grill`/`Toppings` | **continua** | presas a cada estação física (§4), uma seção por estação (Q-307 A já previa isso) |
| `PrepService:Kick`, `CueLock`, `PrepSeats`, `PrepEnter/Leave` | **continua** | `Station` = estação física |
| `Station_1..4` na mesma bancada + `PrepService:StepNear` | **sai** | atrás de flag; cada estação tem o seu binding |
| Vista `Build` (salsicha no vão do pão, gesto `place`) | **sai** | a salsicha vai ao prato na grelha |
| Abas e pan entre seções (DEC-232), Next → Serve | **sai** | ficam Done e Leave |

### 5.2 Contra a FEAT-044/045 (restaurant-flow)

| Peça | Destino |
|---|---|
| `PlateService` (slots, `Ticket`, órfão, "Kitchen full", `plate_put`/`plate_take`) | **continua**: os slots viram apoios da passa; `plate_take` passa a aceitar prato **em qualquer estado** (hoje exige pão e salsicha); `plate_put` aceita também os apoios de estação e de saída |
| Tool `hot_dog` com `Ticket` (máx. 2) | **continua**, nasce vazio e ganha estado `Empty → Bun → Base → Ready` |
| Pilhas `bun_sliced` / `sausage_grilled` e "Fill All" | **saem do fluxo do jogador** (a cesta e a grelha são a saída); o código pode ficar para o Grill Bot / Auto-Slicer, que passam a encher a cesta e a bandeja quente |
| Grelha com `Burnt`, `grill_pickup`, Heat Lamp | **continua**; coleta vai ao prato equipado |
| Seção `Toppings` com prato na mão (FEAT-045) | **continua** igual |
| `ServeAtPickup`, DELIVER só no dono, `Seating` | **continua**; + entrega a partir da prateleira de saída |
| Restock por estação (DEC-285) | **continua** |

### 5.3 Docs a emendar se o dono aprovar

`design/restaurant-flow.md` FEAT-044/045/049 (dono: game-designer), `tech/restaurant-flow.md` e `tech/prep-mode.md` (architect),
`levels/MAP-01-r4-restaurant.md` §5.4–5.5 (level-designer), `docs/tests/restaurant-e2e.md` (qa-tester).

---

## 6. Quebra de tarefas (rascunho para o task-planner; IDs ficam com ele)

| # | Peça | Dono | Depende | Aceite mínimo |
|---|---|---|---|---|
| 1 | Contrato: `Content.Restaurant.Line` (ordem das paradas, cesta 4, apoios por estação, saída 2, `PlateCarry` 2, flag `Rules.LineMode`) e estado do prato no `hot_dog` | architect | — | `modux check` limpo; flag desligada = fluxo de hoje |
| 2 | `PlateService`: pegar prato vazio; apoios de estação e de saída; "Hand Over" da saída | backend | 1 | prato #n pega vazio, pousa e volta; órfão segue funcionando |
| 3 | Pão: corte direto no prato + cesta (corte sem prato) | backend + frontend | 1, 2 | pão vai ao prato equipado; cesta para em 4; nota `bun_cut` por pão |
| 4 | Grelha: "Add Dog" para o prato (a mais perto de queimar) + arrasto na seção | backend + frontend | 1, 2 | sem pão, recusa com toast; queimada nunca vai ao prato |
| 5 | Condimentos com o prato da mão em `COND-n` (já desenhado) + `COND-2` para drive-thru | frontend + backend | 2 | Done devolve `Ready`; K = 0 pula |
| 6 | "Próxima parada" (contorno + ícone) e billboard do prato com estado | frontend | 2 | só a estação certa acende para o prato equipado |
| 7 | Seções presas às estações físicas; `StepNear`/`Station_n` atrás da flag | frontend + backend | 1 | `/dev prep enter` abre a seção da estação mais próxima |
| 8 | Mapa: bancada do fundo em 3 móveis + `COND-2`, passa encurtada, saída no balcão, folga da porta, placas, câmeras por estação, `GAS-1` | level-designer (Studio) | TASK-477, sync das edições à mão | `restaurant_walk_check` ok; corredores ≥ 4; prompts ≥ 2,5 |
| 9 | Apagão pausa a grelha e apaga os prompts de estação | backend | Q-365 | 30 s de apagão não queimam nada |
| 10 | Café "Drink Here" | backend + frontend | Q-366 | bebe sem Tool, mesma dose |
| 11 | Textos de dica (placas, toasts "Needs a bun first") | narrative-writer | 6 | inglês, curtos |
| 12 | QA: solo, 2p e 4p, tempo parado < 25% (FEAT-049), celular | qa-tester | 2–8 | plano + prints |

Paralelismo: 1 primeiro; depois 2 e 8 juntos; 3, 4, 5, 6, 7 em paralelo (arquivos diferentes em `Kitchen`, `Plate`, `Prep`); 9–11
quando o dono responder; 12 no fim.

---

## 7. Riscos

| Risco | Mitigação |
|---|---|
| Solo cansativo (muito andar) | 2 pratos na mão, cesta, distâncias curtas (~47 studs por laço); upgrade de bandeja depois, se o playtest pedir |
| Hotbar confusa com 2 pratos | o prato equipado mostra "#12" grande na mão e na nota do HUD; a próxima parada segue o equipado |
| Fila na tábua de pão em 4p | 2 tábuas e cesta tocável por todos |
| Mudança grande antes de provar | flag `LineMode`; onda 0 com prompts no mundo (sem seção) antes das seções focadas |
