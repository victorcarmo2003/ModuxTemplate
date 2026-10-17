Status: Rascunho

# Trailer expandido (restaurante), ponta a ponta com a chave ligada: plano de teste (TASK-446)

Autor: qa-tester · 2026-10-17 · Executa: TASK-447 (Studio S3).
Fontes: `tech/restaurant-flow.md` rev. 2, `design/restaurant-flow.md` (FEAT-043..050), `design/tutorial-restaurant.md`,
`design/anomalies-v3-restaurant.md` (Em revisão), DEC-269..284, board "Rodada terror + testes" (TASK-441..447).
Código lido no checkout principal (`feat/anomalies-v2-shop-2026-10-14`, HEAD `d695b04`): `src/Customer` (Pickup), `src/Plate`,
`src/Tablet`, `src/Kitchen` (Stations Cut/Grill/Rail), `src/Seating`, `src/Supply`, `src/OrderBoard`, `src/Door`,
`src/Market` (GearStandService), `src/Tutorial`, `src/Place/shared/MapIndex/Required.luau`, `src/Dev/.../Commands/*`,
`tools/assetplace/restaurant_bind.luau`.

**Regra deste plano: vale o que o código faz.** Onde o design (FEAT-043..050) promete mais do que foi implementado, o passo
diz o comportamento do código e a diferença fica na coluna "Nota" (não é bug do teste; vira task se o dono quiser).

Análise estática no momento da escrita: `modux check` = up to date; `tools/analyze.ps1 -Detail` = **0 erro, 0 ciclo**.
Isso não prova comportamento: schema do Lync, binding do mapa e fluxo só aparecem em Play.

---

## 0. Pré-condições

### 0.1 Ligar as chaves (só no Studio de teste; não commitar sem pedido)

| # | Arquivo | Mudança | Por quê |
|---|---|---|---|
| P1 | `src/Shared/Content/Restaurant.luau` | `Rules.Enabled = true` | chave única (TASK-390): deriva `Prep.Rules.Enabled = false`, `WorldKitchenPrompts = true`, `Seating.SitAt = "Served"`, `DirtyTables = false`, `Vehicles.trailer.HasBackDoor = false`, corte das anomalias `Switch.CutAnomalies`, `Supply.MartShelves = false` |
| P2 | mesmo arquivo | `Supply.Enabled = true` | telefone, baias `StockShelf`, escotilha, passos `r_call`/`r_box`/`r_restock` do tutorial |
| P3 | — | **não** mexer em `Prep.luau`, `Seating.luau`, `Vehicles.luau`: os campos são derivados; o `Validate` falha se alguém editar à mão | |
| P4 | terminal | `rogen build` → `modux generate` → `modux check` → `powershell tools/analyze.ps1 -Detail` (0/0) → `rojo serve` | ordem do README |
| P5 | Studio | place com o restaurante aplicado (`restaurant_bind.luau` rodado, TASK-441 sincronizada, `Place.diff` = 0). **Nunca `Place.run`** sem pedido (memória `studio-hand-edits`) | |
| P6 | Studio | Dev mode ligado (DevService carrega `Commands/`); Output do servidor **e** do client abertos | os `/dev` respondem no Output do client em alguns comandos |

Atalhos usados em todo o plano (todos existem hoje): `/dev intro skip`, `/dev tutorial reset|step <key>|auto`, `/dev tutdebug`,
`/dev day <n>`, `/dev night <k>`, `/dev skip`, `/dev arrivals on|off`, `/dev customer pair a,b c,d`, `/dev cash <n>`,
`/dev tablet [state|talk|finish|time <k>]`, `/dev plate [list|assign <npc>|fill <n>|prep <n>|clear|test]`,
`/dev pickup [test|take|serve [npc]|ticket <npc>|pause <npc> on|off]`, `/dev railfeed [n]`, `/dev seating`,
`/dev supply [state|order <pkg> <n>…|arrive|take [<pkg>]|seed|clear|test]`, `/dev gear [open|close|state]`, `/dev market`,
`/dev shutter [open|close|in]`, `/dev closed on|off`, `/dev light on|off|here`, `/dev anomaly <key>|stop|agenda`,
`/dev sanity <n>`, `/dev audio`, `/dev interactlog`.
**Não existe** `/dev kitchen` para cortar/virar (use os prompts) e o `/dev smoke` ainda é o do trailer (ver R-6).

### 0.2 Testes de tabela puros (rodar primeiro, 1 jogador)

| # | Comando | Esperado |
|---|---|---|
| T1 | `/dev pickup test` | todas as linhas `ok` (join / leave / a fila anda / cheia / choose) |
| T2 | `/dev plate test` | todas `ok` (`Slots.luau`) |
| T3 | `/dev supply test` | todas `ok` (`Order.luau`: quick, custo, limites) |
| T4 | `/dev prep grade` | `N/N ok` (o `Grade` continua sendo requerido por `Grill`/`CustomerService`) |

---

## 1. Boot

| # | Passo | Esperado (observável) | Nota |
|---|---|---|---|
| B1 | Play (1 jogador), olhar o Output do servidor nos primeiros 10 s | nenhum `error`; nenhum `[MapIndex] ... missing`; `Lync.start()` sem erro de schema (`Plates`, `Tablets`, `Supply`, `Hatch`, `Customers.Pickup/Number`) | |
| B2 | procurar no Output `binding passes wave 2 but not wave 3` | **não pode aparecer**. Se aparecer, o `PlaceService` rebaixou a falha do wave 3 a aviso: listar as linhas `2: required MapPoint PU-…` / `6: required node PU-…` / `no path Q1 -> PU-…` | **R-1**: o `Required` exige `PU-1..PU-8` (máximo de `Rules.PickupSlots` = {4,6,8,8}) e o `restaurant_bind.luau` cria só `PU-1..4` |
| B3 | procurar `anchor spacing (rule 4)` | lista vazia, ou só pares conhecidos e aceitos (anotar todos com distância) | ver R-4 (CUT-1 legado × CUT-2) |
| B4 | procurar `Gear Stand binding` / `Pad tables binding` | nenhum problema (avisos soft só se a TASK-441 já conhece) | |
| B5 | `/dev tablet` | `TAB-1` ligado, estado `Idle`, sem cliente; nunca "not enabled" | |
| B6 | `/dev plate` | 8 slots ligados (`PLATE-1..8`), ativos = 4 (party de 1), todos sem ticket | |
| B7 | `/dev pickup` | modo pickup **on**, pontos `PU-k` achados, tamanho = min(`PickupSlots[party]`, PU no mapa) | com 4 PU no mapa o tamanho fica 4 mesmo com 2+ jogadores (R-1) |
| B8 | `/dev supply` | 0 chamadas; baias `StockShelf` listadas (uma por pacote); escotilha com 6 vagas | |
| B9 | Mart | sem prateleiras `BUY-*` exigidas (`MartShelves = false`); o Gear Stand (B1..B5, S1, persianas) continua no mapa e ligado | DEC-282 diz "sair para ir ao Mart": hoje o Mart saiu do mapa com a chave ligada. Pergunta para o dono, não bug |
| B10 | prompts do Prep | nenhum `prep_work` em lugar nenhum (Prep desligado) | |

---

## 2. Loop principal (1 jogador, Day 2 para fugir do tutorial)

Preparo: `/dev intro skip` → `/dev day 2` → na Prep abrir a janela (alavanca `shutter_toggle` ou `/dev shutter open` e esperar o Open)
→ `/dev arrivals off` e criar clientes um a um com `/dev customer pair ketchup mustard` (pedido conhecido) ou deixar o fluxo
normal com `/dev arrivals on`.

### 2.1 Tablet e nota (FEAT-043)

| # | Passo / atalho | Esperado | Nota |
|---|---|---|---|
| L1 | cliente chega à fila; observar `Q1..Q5` | só `Q1` fica na frente do `TAB-1` em `Ordering`; nunca mais de 5 na fila | |
| L2 | o rig em `Q1` | **não** tem prompt `take_order` (o pedido é no tablet) | |
| L3 | prompt "Take Order" no `TAB-1` (ou `/dev tablet talk`) | `Tablets[1] = Talking`; a nota do HUD (canto superior esquerdo) abre vazia e ganha **um pop-up por item**, na ordem pão → salsicha → complementos na ordem de `ToppingKeys`; balão sobre o cliente para os outros | |
| L4 | cronometrar do toque ao fim (`/dev tablet time 2` dá o valor teórico) | K=2: Open 1,2 + Lead 0,8 + 0,45 × 4 + Confirm 0,6 = **4,4 s**; medido entre 4,4 e **4,9 s** (o fim é decidido num tick de 2 Hz) | o critério do design (± 0,3 s) não cabe no tick de 2 Hz; anotar o medido |
| L5 | durante a fala, a barra de paciência do cliente | **parada** (`PausePatience`); volta a correr se a fala for cancelada | |
| L6 | andar para longe durante a fala | a fala **continua** e o pedido é tomado igual (regra TASK-381) | design FEAT-043 dizia "afastar cancela": divergência registrada, não bug |
| L7 | apertar interagir de novo durante a fala | nada acelera | "Hurry ×2" e "veterano ×1,6" não foram implementados (design FEAT-043) |
| L8 | 2º jogador toca o tablet ocupado (co-op, §5) | toast `tablet_busy` "Someone's taking that order." | |
| L9 | fim da fala | cliente sai de `Q1` (a fila anda), ganha **#n** sobre a cabeça e anda até o fim da retirada `PU-k`; `/dev pickup` mostra o #n e a paciência de preparo correndo | |
| L10 | dinheiro no fim da fala | **não muda** (o pagamento é na entrega, DEC-072) | design FEAT-048 dizia "paga ao confirmar"; o código não faz isso: anotar |
| L11 | cliente ANM-001 (sem rosto), se a noite tiver | nota em branco, sem pop-ups | |

### 2.2 Prato-slot (FEAT-044)

| # | Passo / atalho | Esperado |
|---|---|---|
| P1 | logo após L9 | o ticket cai num `PLATE-n` livre em ≤ 0,5 s; prato translúcido com `BillboardGui` (#n + ícones iguais aos da nota, borda = paciência) |
| P2 | `/dev plate prep 3` antes de um pedido novo | o próximo ticket prefere o `PLATE-3` (já com pão + salsicha; `PreppedFirst`) |
| P3 | `/dev plate fill 4` (solo: 4 ativos) e tentar "Take Order" | tablet mostra "Kitchen full" para todos; toast `plates_full`; cliente fica em `Q1` com a paciência de fila correndo |
| P4 | pegar 1 prato (`plate_take`) com P3 ativo | o tablet destrava (`Full` → `Idle`) em ≤ 0,5 s |
| P5 | `/dev plate clear` | todos vazios, sem ticket |

### 2.3 Corte, grelha, pilha, condimento (FEAT-045)

| # | Passo / atalho | Esperado | Nota |
|---|---|---|---|
| K1 | segurar "Slice Bun" no `CUT-2` (0,6 s) | −1 `Stock.bun`; Tool `bun_sliced` `Count = 1`; de novo = mesmo Tool `Count 2`, até 3 (`Stacks.Bun`) | |
| K2 | sem pão (`Stock.bun` 0) | prompt some ou recusa `out_of_stock` | |
| K3 | `bun_sliced` equipado → "Add Bun" no prato do ticket | pão aparece no slot, prato menos translúcido; `Count` −1 | o prompt `plate_put` só aparece com o Tool **equipado** (Rules.luau) |
| K4 | "Grill" na caixa de salsichas ao lado do `GRILL-1` | −1 estoque; salsicha na vaga mais baixa livre **da grelha tocada** | |
| K5 | esperar o 1º lado | a salsicha **para** (Working, pausada) e aparece "Flip" sobre aquela vaga; sem virar ela **nunca fica pronta** | não há queima no código (`BurnAfter` do design não existe): anotar |
| K6 | "Flip" | 1 s depois `Ready`; aparece "Collect" | |
| K7 | "Collect" | salsicha vai para a pilha (rail); `Count` do rail +1 | |
| K8 | "Take Dogs" na pilha (ou `/dev railfeed 3` e depois "Take Dogs") | Tool `sausage_grilled` com até 3 (`Stacks.Sausage`); sobra fica na pilha | |
| K9 | 3º Tool de `Ingredient` (já com `bun_sliced` + `sausage_grilled`) | `hands_full` (`CategoryLimits.Ingredient = 2`) | |
| K10 | "Add Sausage" no prato | salsicha no slot; prato `Base` | |
| K11 | "Take Plate" com mão livre | Tool `hot_dog` com atributo `Ticket` = NpcId; o slot **libera o ticket** na hora | |
| K12 | "Take Plate" num prato só com pão | prompt não aparece / recusa `plate_not_ready` | |
| K13 | `hot_dog` equipado → condimentos (`COND-n`, segurar 1 s por topping) | só os toppings aplicados entram; nota do HUD passa a mostrar o pedido do `Ticket` do prato na mão | |
| K14 | errar um topping → "Throw Away" na lixeira | Tool some, pão/salsicha perdidos | |
| K15 | "Put Plate" com `hot_dog` num slot vazio (hand-off) | o slot recebe pão + salsicha + toppings + ticket; outro jogador pega com "Take Plate" | |
| K16 | **olhar o `CUT-1`** (clone da tábua do trailer) e a caixa de pão legada | anotar se aparecem `bun_cut` / `board_add_sausage` / prompts da tábua antiga | **R-4**: com a chave ligada `WorldKitchenPrompts = true` liga os 5 prompts de mundo do trailer; o `CUT-1` continua `StationKind = board` (o atributo `PendingStationKind = cut` não é lido por nenhum código) |
| K17 | celular (emulador 667×375) na frente da grelha | anotar se dá para tocar o "Flip"/"Collect" da vaga certa | **R-3**: as âncoras de vaga ficam a < 1 stud uma da outra e `Att_Flip<n>` fica 0,35 acima do `grill_collect`; a regra 4 do MapIndex não confere âncoras do mesmo dono |

### 2.4 Retirada, mesa, viagem (FEAT-046)

| # | Passo / atalho | Esperado | Nota |
|---|---|---|---|
| D1 | `hot_dog` certo → "Hand Over" no `PICKUP` (ou `/dev pickup serve`) | vende para o cliente do `Ticket`, onde quer que esteja em `PU-1..n`; dinheiro + preço (+ gorjeta na janela); a fila anda em ≤ 2 s | |
| D2 | entregar arrastando no rig de um `PU-n` (DeliveryController) | mesmo resultado (`ServeAtPickup` com alvo) | |
| D3 | `hot_dog` sem `Ticket` (feito pela tábua legada ou `Ticket` apagado) | vai ao mais antigo com pedido idêntico; senão `PU-1` → Errado | |
| D4 | `hot_dog` errado | veredito Errado: o hot dog **volta à mão**, o cliente segue esperando | |
| D5 | faltando topping | Incompleto: paga menos (DEC-072), cliente sai insatisfeito | |
| D6 | servido Completo com mesa livre | cliente anda com o prato na mão (`Carrying`) até `TBL-n`, senta, come ~12 s, levanta; **$1 por pessoa** cai no pote; mesa volta a livre sem "Clean Table" | |
| D7 | 8 lugares ocupados (`/dev seating` para ver) ou sem folga no teto | quem recebe sai **para viagem** levando o prato; nunca fica parado no salão | |
| D8 | deixar a paciência de preparo zerar | cliente sai (`Slow`), sai da retirada, os de trás andam; o prato vira órfão (ticket solto) | estorno não existe no código (pagamento é na entrega) |
| D9 | retirada cheia (`Rules.PickupSlots[party]`) e tentar "Take Order" | `pickup_full` "Kitchen full! Serve who is waiting."; cliente fica no tablet | |
| D10 | par (`/dev customer pair ketchup mustard`) | 1 lugar na retirada; 2 tickets (Line 1 e 2) em 2 pratos; entrega das duas linhas | |

### 2.5 Painel de pedidos (OrderBoard, MenuStrip)

| # | Passo | Esperado | Nota |
|---|---|---|---|
| O1 | durante a fala no tablet | card "NEW" com itens apagados e sem barra | |
| O2 | ticket no prato | card #n (= o do cliente) em `Queued`; com pão ou salsicha → `Preparing` | |
| O3 | prato pego | card fica no último estado (≥ `Preparing`) até a venda; some na venda/desistência | `Ready` só aparece se um `hot_dog` com todos os toppings voltar ao slot (os toppings vão no prato na mão) |
| O4 | barra | drena pela paciência; "!" abaixo de 25% | |
| O5 | 4 clientes no painel | mais antigo à esquerda; mesmo #n em todos os clients | |

---

## 3. Estoque: telefone, caixas, baias, escotilha, estoque baixo (FEAT-050)

| # | Passo / atalho | Esperado | Nota |
|---|---|---|---|
| S1 | "Order Stock" no telefone `PHONE-R` (toque) | pedido rápido (`Order.quick`: até 4 caixas, menor estoque primeiro); débito = Σ preços + $2; toast `supply_ordered` para a party com o ETA | não há menu de escolha (falta packet; TASK-389) e o prompt é toque, não segurar |
| S2 | ligar de novo com pedido a caminho | `supply_busy` com os segundos restantes; nada debitado | |
| S3 | `/dev cash -9999` e ligar | `not_enough_cash`; nada chega | |
| S4 | esperar 45 s ou `/dev supply arrive` | cada caixa vai para a **baia do pacote** (`StockShelf`); sem baia, para a escotilha (vagas 1..6); o resto espera "fora" e entra quando abre vaga (`/dev supply`) | |
| S5 | "Take <pacote>" na baia (ou `/dev supply take buns`) | Tool de pacote na mão; 3ª caixa = `package_limit` (2; urso 3) | |
| S6 | "Restock" (segurar 1 s) na estação do ingrediente (pão = `CUT`, salsicha = caixa da grelha, condimento = `COND`) | transfere até a capacidade; sobra fica na caixa; caixa vazia some | |
| S7 | gastar o pão até ≤ 25% | ícone de caixa pulsando no `StockMenu` e toast `stock_low` "Low on Bun" **1× por queda** | |
| S8 | `/dev night 1` (1ª Night da run) | `StartBoxes` (1 DOGS + 1 BUNS) chegam de uma vez | |
| S9 | caminho a pé telefone → baia → estação | tudo dentro do trailer (DEC-280/282) | |

---

## 4. Gear Stand, portas, tutorial

### 4.1 Gear Stand: horário (GearStandService)

| # | Passo / atalho | Esperado |
|---|---|---|
| G1 | run nova, Day 1 Open | Gear Stand **fechado** (Intro fecha; só abre no fim do 1º turno) |
| G2 | fim do turno (`/dev skip` até `Summary`) | abre: persianas sobem, som de porta de metal no stand, toast `gear_open` "Gear Stand is OPEN" para todos |
| G3 | início do próximo turno de venda (Open/Night) | `/dev gear` mostra o fechamento agendado para +45 s; aos 20 s restantes toast `gear_closing` "closing in 20s"; depois fecha com som e `gear_shut` |
| G4 | comprar com ele fechado | `gear_closed`; nada debitado |
| G5 | `/dev gear open` / `/dev gear close` | força e mostra persiana + som + toast; volta à regra na próxima troca natural |
| G6 | `NightLost`/`Resume` | sempre fechado |

### 4.2 Portas automáticas (DoorController, local)

| # | Passo | Esperado | Nota |
|---|---|---|---|
| A1 | andar até a porta da despensa `DOOR-P` e a porta externa `DOOR-B` (DEC-282) | abre a < 8 studs, `door_creak`; fecha 1 s depois de sair com `door_close`; folha nunca é a parede inteira (aviso `MAX_LEAF_WIDTH`) | |
| A2 | 2 jogadores, um perto da porta | cada client anima a sua; quem está longe também vê abrir (outro Humanoid conta) | |
| A3 | NPC (cliente/pedestre) perto de uma `AutoDoor` | se o NPC precisa passar, a cópia do servidor tem de estar sem colisão; anotar se trava | o servidor não anima a porta |
| A4 | sair por `DOOR-B` e voltar | o jogador consegue; a entrega continua só no balcão (sem porta na frente) | |

### 4.3 Tutorial Day 1 (restaurante)

Preparo: Play limpo (perfil novato) ou `/dev tutorial reset`; `/dev tutdebug` mostra o passo ao vivo.

| # | Passo | Esperado (seta / fala do Walt) |
|---|---|---|
| U1 | telefone toca | `phone` → atender |
| U2 | Prep | `open`: "Open the window." na alavanca |
| U3 | cliente na fila → `Q1` | `wait_customer` → `r_tablet` "Take their order at the tablet." |
| U4 | fala | `r_listen` sem seta |
| U5 | corte e prato | `r_cut` → `r_bun_plate` (seta no prato mais adiantado, sem ticket: o cliente do tutorial não ganha ticket) |
| U6 | grelha | `r_grill` → `r_cooking` → `r_flip` "Flip it." → `r_collect` → `r_rail` → `r_dog_plate` |
| U7 | prato e ketchup | `r_take_plate` → `r_toppings` "Ketchup on it."; topping errado → `r_discard` |
| U8 | entrega | `r_pickup` "Hand it over at pickup." → `money` |
| U9 | estoque (`Supply.Enabled`) | `r_call` (caixa completado até o preço do pedido rápido, uma vez) → `r_boxes` (fala repete a cada 20 s, Day 1 parado) → `r_box` → `r_restock` → "Stocked up!" |
| U10 | fora de ordem: grelhar antes de cortar; jogar o hot dog no lixo | nunca trava; o passo segue o estado; lixo volta ao corte |
| U11 | ficar parado | lembrete falado a cada 12 s; o Day 1 solta sozinho depois de `Shift.TutorialHoldMax` |
| U12 | **lição do Gear Stand** no Closing do Day 1 (18h, relógio segurado) | Walt liga `call_tutorial_upgrade` "Gear Stand, in the back."; `upg_go` → `upg_buy` comprar Storage. **Conferir se o stand está aberto**: pela regra de horário ele só abre no `Summary`, e a lição roda no `Closing` (antes). Se fechado, o novato recebe `gear_closed` e a lição só acaba pelo `TutorialHoldMax` → **Falhou** (R-2) |
| U13 | co-op 2 novatos | cada um vê o próprio passo vindo do estado compartilhado; quem não segura o prato vê `r_crew` (seta no `PICKUP`, sem fala); veterano não vê tutorial |

---

## 5. Co-op 2 jogadores (Studio Test > Clients and Servers, 2 clients)

| # | Passo | Esperado |
|---|---|---|
| C1 | os 2 entram; `/dev plate` | ativos = 6 (party 2); `/dev pickup` tamanho = min(6, PU no mapa) (R-1) |
| C2 | J1 no tablet, J2 cortando/grelhando ao mesmo tempo | nenhum espera o outro; a nota de J1 monta os itens; J2 vê o balão sobre o cliente |
| C3 | os 2 tocam o mesmo prato no mesmo frame ("Add Bun") | só um efeito; o outro recebe o toast da recusa |
| C4 | J1 pega o prato, J2 entrega? (hand-off pelo slot: J1 "Put Plate", J2 "Take Plate") | ticket e toppings preservados |
| C5 | J2 toca o tablet durante a fala de J1 | `tablet_busy` |
| C6 | J1 sai do jogo no meio da fala | no fim a fala volta a `Idle` sem pedido (`TakeOrderFor` recusa um jogador que saiu; aviso no Output); a paciência do cliente volta a correr; J2 consegue tomar o pedido de novo |
| C7 | J1 sai com um `hot_dog` (Ticket) na mão | o cliente daquele #n continua na retirada; o prato se perde; nada trava; J2 refaz e entrega (vai por pedido idêntico) |
| C8 | painel de pedidos e billboards | iguais nos 2 clients (#n, estado, barra) |
| C9 | `stock_low`, `supply_ordered`, `gear_*` | toast para os 2 (Audience Party) |
| C10 | DEC-275 | log: nenhum jogador > 5 s parado sem tarefa útil por mais de 25% do turno (medir à mão no 1º teste) |

---

## 6. Terror: apagão e música em passos (TASK-443/444, em desenvolvimento)

Escrito pela spec do board e DEC-283/284; ajustar os nomes dos comandos quando a task entregar.

| # | Passo / atalho | Esperado |
|---|---|---|
| H1 | `/dev night 1` → `/dev anomaly anm_020_blackout` | a energia cai: som `lights off`, cozinha **realmente escura** (TASK-442) com só luz de emergência/fora; **texto de aviso na tela** (ex.: "Power's out. Hide in the back!") para todos |
| H2 | música | passa de calmo → inquieto → tensão com **violinos acelerando** → clímax "bicho chegou" (`Horror Coral`) → alívio; cada passo dirigido pelo ciclo da anomalia (prenúncio → ativa → resolvida/erro), nunca dois passos tocando juntos |
| H3 | 2 jogadores: J1 dentro da despensa (`HIDE-P`), J2 fora quando a criatura chega | J1 sem perda; J2 perde sanidade (−35, DEC-277) e só cai se zerar; jumpscare no erro |
| H4 | religar o disjuntor (fundos) depois que a criatura vai embora | luzes voltam, música vai a "alívio", aviso some |
| H5 | `/dev anomaly stop` no meio | tudo volta: luz, música calma, sem texto preso na tela |
| H6 | `/dev audio` antes e depois de 3 apagões | contagem de instâncias de som não cresce (sem vazamento); `LoadQueue` sem pico |
| H7 | jogador entra (late join) durante o apagão | vê escuro + aviso + o passo de música atual |
| H8 | TASK-445: sons em pastas por passo | nenhum som "não encontrado" no Output de client; IDs SFX/MUS/AMB iguais (DEC-284) |

---

## 7. Casos de borda e client mal-intencionado

| # | Caso | Esperado |
|---|---|---|
| E1 | executor manda `Interact` de `plate_put` sem Tool na mão | servidor recusa (escolhe o Tool no Backpack ou recusa), nada muda no `Plates` |
| E2 | `Interact` de `tablet_take` a 50 studs | recusa por raio (`TakeRadius` 6) |
| E3 | `Interact` de `pickup_serve` com `hot_dog` cujo atributo `Ticket` foi editado no client | atributo de Tool é do servidor; se o client mexer, o servidor usa o seu ou cai em pedido idêntico; veredito pelos toppings, nunca trava |
| E4 | spam de `take_box` (10 por s) | cadência do `SupplyService` recusa; no máximo 1 caixa por toque |
| E5 | spam de `order_stock` | um pedido; os outros `supply_busy` (toast com anti-spam de 2 s) |
| E6 | `grill_flip` fora da pausa | silencioso, nada muda |
| E7 | saldo insuficiente no telefone / no Gear Stand | `not_enough_cash`; nada debitado, nada entregue |
| E8 | fim do turno com fala ativa / pratos com ticket | `ShiftStarted` zera o tablet; pratos/órfãos não sobram no turno seguinte |
| E9 | resume de snapshot no meio do turno | caixas nas baias/escotilha voltam (`Sup`); chamadas a caminho caem com o dinheiro devolvido; `Ticket` não volta |

---

## 8. Regressão com a chave desligada (`Rules.Enabled = false`, `Supply.Enabled = false`)

| # | Passo | Esperado |
|---|---|---|
| X1 | rebuild (P4) e Play no **mesmo** place | boot sem erro; o fluxo do trailer: "Take Order" no rig em `Q1`, servido em `Q1`, `Seating.SitAt = "Order"`, mesa suja e "Clean Table" |
| X2 | `/dev tablet`, `/dev plate`, `/dev supply` | respondem que o restaurante está desligado (não erram em silêncio) |
| X3 | prompts `tablet_take`/`plate_*`/`grill_flip`/`rail_take`/`bun_slice`/`pickup_serve`/`order_stock`/`take_box` | nenhum aparece |
| X4 | Prep | modo focado volta (`Prep.Rules.Enabled = true`) com as âncoras `Station_n` que existirem |
| X5 | Mart | prateleiras `BUY-*` exigidas de novo (`MartShelves = true`): no place do restaurante o Mart está em `ServerStorage.Mart` → anotar se o boot acusa `OP-1`/`MKT-DOOR`/`BUY-*` (rollback precisa do Mart de volta) |
| X6 | anomalias | `CutAnomalies` voltam à agenda (`/dev anomaly agenda` na Night 6..9 mostra as estreias originais) |
| X7 | tutorial | idêntico ao do trailer; lição do Gear Stand desligada |
| X8 | `/dev smoke` | `SMOKE: N ok, 0 failures` (o smoke é do trailer) |

---

## 9. Riscos achados lendo o código (para a TASK-447 confirmar)

| ID | Risco | Onde | Teste |
|---|---|---|---|
| R-1 | `Required` exige `PU-1..PU-8` + rotas `Q1 → PU-8` com a chave ligada; o bind cria só `PU-1..4`. Resultado provável: aviso "passes wave 2 but not wave 3" (o wave 3 inteiro deixa de ser checado como fatal) e retirada travada em 4 com 2+ jogadores | `src/Place/shared/MapIndex/Required.luau:439-456`; `tools/assetplace/restaurant_bind.luau:2291-2294`, `:2309-2315` | B2, B7, C1 |
| R-2 | Lição do Gear Stand no Closing do Day 1 com o stand fechado: o horário só abre no `Summary`, e o Closing é segurado pela lição. Novato vai ao stand e recebe `gear_closed` | `src/Market/server/GearStandService.luau` (`OnPhase`, abre só em `Summary`); `src/Tutorial/shared/Rules.luau:36-43`; `src/Tutorial/server/TutorialService.luau:234-256` | U12 |
| R-3 | Prompts da grelha amontoados: `Att_Flip<n>` a 0,35 stud do `grill_collect` da mesma vaga e vagas vizinhas < 1 stud; a regra 4 (2,5 studs) só compara donos diferentes, então nada avisa | `restaurant_bind.luau:1648-1659`; `src/Place/shared/MapIndex/init.luau:637-668` | K17 |
| R-4 | Cozinha legada ligada junto: `WorldKitchenPrompts = true` liga os 5 prompts de mundo; `CUT-1` continua tábua `board` (o `PendingStationKind` não é lido por ninguém), então há um 2º caminho de montagem sem prato/ticket, e o `CUT-1` fica a ~2,3 studs do `CUT-2` | `restaurant_bind.luau:1679-1697`; `src/Kitchen/server/KitchenService/init.luau:894-900` | B3, K16, D3 |
| R-5 | Design × código: sem queima, sem "Hurry"/veterano, a fala não cancela ao afastar, pagamento na entrega (sem estorno), pedido de estoque sem menu e por toque (o cabeçalho diz segurar). Critérios de aceite do FEAT-043/045/048/050 vão falhar se forem lidos ao pé da letra | `src/Tablet/server/TabletService.luau:9-20`; `Kitchen/.../Stations/Grill.luau:6`; `Supply/.../init.luau:7-12`; `Content/Actions.luau:165` | L4, L6, L7, L10, K5, S1 |
| R-6 | `/dev smoke` é do trailer (passos `mart`, `seating buy + sit`, `trailer ready`): com a chave ligada falha e não existe o smoke do restaurante pedido no tech §5 R2 | `src/Dev/server/DevService/Commands/Smoke.luau:119-237` | X8 (desligada); com a chave ligada só como informação |
| R-7 | Ondas: `drive_serve` é `Wave = 4` com `BindingWave = 3` (fica desligado, correto enquanto o drive-thru é R3). Os avisos `supply_*`/`stock_low` têm `Wave = 4`, mas em `Notices` o `Wave` é só documentação (não corta) | `Content/Actions.luau:163`; `Content/Notices.luau:6, 111-113` | nenhum (informativo) |
| R-8 | Pedido em fala com o atendente que sai: o tablet volta a `Idle` e o pedido é perdido em silêncio (só `warn` no servidor); o cliente refaz a fila de pedido do zero na frente | `src/Tablet/server/TabletService.luau:218-229` | C6 |
| R-9 | Mart fora do mapa com a chave ligada (`MartShelves = not on`) contra DEC-282 ("sair pela porta dos fundos para ir ao Mart"); no rollback o Mart precisa voltar do `ServerStorage.Mart` | `Content/Restaurant.luau:385`; `Required.luau:105-110` | B9, X5 |
