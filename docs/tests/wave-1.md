Status: Rascunho

# Plano de teste — Onda 1 (núcleo jogável de dia, carrinho)

Autor: qa-tester. Versão 1, 2026-10-10 (**TASK-040**). Resultado da execução: **TASK-041** preenche a §10 deste arquivo.

Base: `docs/tasks/board.md` (critérios de aceite TASK-003 a TASK-039), `docs/tech/network.md` v4,
`docs/tech/content-data.md` v4, `docs/tech/data.md` v4, `docs/tech/architecture.md` §18 (binding), `README.md` (regras de
rede), FEAT-003, 005–012, 014, 015, 028, 032 (`docs/design/features.md`), `proposals-round-2.md` §1.7 e §3.9
(critérios citados por FEAT-010/011/028), DEC-048, 049, 051, 071, 072, 142, 156, 171, 174, 175, 180, 184, 185, 186,
188, 190, 191, 201.

> **Base Provisória (DEC-193).** Onde a spec é Provisória (Q-130 T6/T13/T14/T40, Q-062, Q-163, Q-164, Q-165,
> `CategoryLimits.HotDog = 2`, `Flow.RecalcOn`), o caso testa o valor **Provisório** e está marcado **[P]**. Se a
> decisão mudar, o caso muda junto.

---

## 0. Como usar este plano

### 0.1 Tipos de verificação

| Código | Significa | Quem roda |
|---|---|---|
| **E** | estático: leitura de código/diff, `modux check`, `tools/analyze.ps1` | qa-tester, por task, antes de `Feito` |
| **S** | script/simulação: Command Bar do Studio (servidor) ou teste de unidade sobre função pura | qa-tester |
| **M** | manual no Studio (play test) | qa-tester (TASK-041) ou quem valida a task |

Compilação limpa **não** fecha nenhum caso **M** ou **S**.

### 0.2 Ambiente

| Item | Configuração |
|---|---|
| Ordem de build | `rogen build` → `modux generate` → `rojo serve`; place Run aberto no Studio e conectado |
| Modo | **dev** (`Workspace.PlaceRole` sem `PrivateServerId`; `PlaceService:IsDev() == true`), roster = quem entrar (`architecture.md` §1) |
| 1 jogador | Test → **Play** (F5) ou Clients and Servers com 1 client |
| 2 jogadores | Test → **Clients and Servers**, Clients = 2, Server + 2 janelas |
| 4 jogadores | só os casos de orçamento/teto marcados **4p** (opcional na onda 1; a party de 4 é da onda 2) |
| PC | teclado + mouse; tecla de interagir = **E** |
| Mobile | Studio → Test → **Device** (emulador): "iPhone SE" (667×375, menor alvo) e "iPad"; toque com o mouse. Se houver place publicado, repetir os casos marcados **📱real** em aparelho físico. Console: fora do plano (DEC-171) |
| Rede ruim | Studio → Settings → Network → `IncomingReplicationLag` = 0,3 s nos casos marcados **lag** |

### 0.3 Como observar o servidor

- **Explorer na visão Server** (Test → Current: Server): atributos `EntityId`, `PromptEnabled`, `PromptText`,
  `StationId`, `Species`, `Outfit`, `LookPack`, `NpcId`, `Item`, `Count`, `Toppings`.
- **Command Bar na visão Server**: ler sets pelo módulo de rede
  (`local Net = require(game.ReplicatedStorage.shared.Libs.Net)`) com a API de leitura do Lync usada no código
  (`Net.Stock:get(id)`, como `VitalController` faz com `Vitals:get`).
- **Command Bar na visão Client** (para pacote forjado, §3): o mesmo `require` e `Net.Interact:fireServer({...})` /
  `Net.ClassAction:fireServer({...})`. É exatamente o que um exploit faria.
- Relógio: `workspace:GetServerTimeNow()` no Command Bar das duas visões.

### 0.4 Pré-requisitos que o plano pede ao código (testabilidade)

Sem estes, parte dos casos vira observação lenta ou impossível. **Recomendação Provisória** do qa-tester ao
task-planner (não bloqueia; se não existir, o caso é feito no ritmo real e anotado):

| # | Pedido | Casos que dependem | Onde caberia |
|---|---|---|---|
| R1 | comando de dev (só `IsDev()`, sem rede) para pular para o Day N e para a próxima fase | T008, T028-04, T033-02/03, T037-02, §8 (Day 2–6) | TASK-012 |
| R2 | comando de dev para dar gemas (já previsto, TASK-017) e dinheiro da party | T017, T020, T035, T036 | TASK-017 / TASK-021 |
| R3 | sorteio de pedido exposto como função pura `(day, customerType, rng) -> { toppings }` | T033-01 (1.000 sorteios) | TASK-033 |
| R4 | log de dev (só `IsDev()`) de `Interact` descartado com motivo (`rate`, `range`, `target`, `state`) | §3 | TASK-011 |
| R5 | contador de tentativas de spawn de cliente por turno (spawnado / pulado por fila cheia) | T032-01/02 | TASK-032 |

Dia completo no ritmo real: Prep ≤ 60 s + Open 360 s + Closing ≤ 30 s + Summary 15 s ≈ **7 min 45 s**. Chegar ao
Day 6 sem R1 ≈ 39 min.

---

## 1. Portão estático (vale para **toda** task de código da onda 1)

Antes de qualquer caso manual. Falha aqui = task volta (`Falhou QA`) com arquivo:linha.

| ID | Verificação | Esperado |
|---|---|---|
| G-01 | `rogen build`, `modux generate`, `modux check` | 0 erro |
| G-02 | `powershell tools/analyze.ps1 -Detail` | 0 erro, 0 ciclo |
| G-03 | `git diff` não toca `src/Modux/**`, `*/Manifest/init.luau`, `*/Modules.luau`, `shared/Libs.luau`, `src/ModuxTypes/**`, `default.project.json` à mão (só por geração) | regenerar dá o mesmo arquivo |
| G-04 | escopo: só os arquivos da coluna "Arquivos / pastas" da task; `Net/init.luau` e `Template.luau` só na TASK-004; `Content/init.luau` só na TASK-003; `KitchenService/init.luau` só na TASK-025 | nenhum arquivo de outro dono |
| G-05 | todo `.luau` novo começa com `--!strict`; `const` em valor imutável | sim |
| G-06 | responder de rede (`onServer`/`onClient`) só em Service/Controller, dentro de `OnInit`; Component não registra responder | sim |
| G-07 | nenhum `keyBy` (T14); packet s → c para `NetService.Audience` ou `fireClient`, nunca `Lync.all`; só com `NetService:IsRunning()` | sim |
| G-08 | Charm só no servidor, Vide só no client; Lync e Vide requeridos direto (`ReplicatedStorage.Packages`), nunca via `src/Libs` | sim |
| G-09 | nenhum `InsertService` em runtime (T34) | sim |
| G-10 | server-authoritative: nenhum handler c → s aceita preço, resultado, quantidade, vaga, `Toppings` ou nível vindos do client (o payload é só `{Id, Action}` ou `{Action, Class}`) | sim |
| G-11 | `Content` não requer Lync, Vide nem `self.Libs` | sim |
| G-12 | Service com atom de run aparece em `data.md` §2.2 (R13) | sim |
| G-13 | task que toca `Net/init.luau`: boot no Studio (1 client) sem erro de `Lync.start()` no Output | 0 erro |

---

## 2. Casos por task

Colunas: **Tipo** (E/S/M) · **Jog.** (1p/2p/4p) · **Plat.** (PC/Mob/ambos). Mob = emulador; 📱real quando marcado.

### TASK-003 — `Content`

| ID | Critério | Tipo | Passos | Esperado |
|---|---|---|---|---|
| T003-01 | `Validate()` sem erro em < 1 ms | S | Command Bar (servidor e client): `local t=os.clock(); require(game.ReplicatedStorage.shared.Content); print(os.clock()-t)` em place limpo | sem erro; < 0,001 s |
| T003-02 | chave duplicada → `error` com tabela e linha | S | cópia local de `Ingredients.luau` com `ketchup` duplicado; requerer | `error` cita `Ingredients` e a linha/índice |
| T003-03 | referência quebrada → `error` | S | `pack_ketchup.Ingredient = "ketchupp"`; classe com `Species = "raccoon"` | `error` com tabela e linha; guaxinim recusado (DEC-186) |
| T003-04 | `Keys` corretas dos stubs | E | ler `Classes`, `Shift`, `Upgrades`, `Vehicles`, `RunParams`, `Flow`, `Orders`, `CustomerTypes`, `Species`, `OpalLines` | chaves = `content-data.md` §3 (ex.: `class_dog`…`class_lion`; 18 espécies) |
| T003-05 | subconjuntos derivados, não à mão | E | `ToppingKeys`, `RecordKeys`, `PhaseKeys` | calculados no módulo; `ToppingKeys` = 6; `RecordKeys` = grill, rail, board, coffee_machine |
| T003-06 | `Actions` = §3.18 | E | comparar `Text`, `Hold`, `Radius` | `topping_add` existe, `board_add_topping`/`board_pickup`/`party_join` não; holds 0/0,5/1/1,5 conforme FEAT-005 |
| T003-07 | `ItemRules.HotbarSlots = 4` (DEC-174) | E | ler | 4; `CategoryLimits.Package = 2`, `HotDog = 2` **[P]** |
| T003-08 | sem `require` proibido | E | grep em `src/Shared/Content` | nenhum Lync/Vide/`self.Libs` |

### TASK-004 — Net v1 + Template

| ID | Critério | Tipo | Passos | Esperado |
|---|---|---|---|---|
| T004-01 | entradas = `network.md` §8 | E | diff de `Net/init.luau` contra §3–§4 | 7 sets + 6 packets da onda 1 + `Round`/`Vitals` legados; nenhuma entrada das ondas 2–4; nenhum `keyBy` |
| T004-02 | enums gerados de `Content` (T13) | E | `Lync.enum(Content.X.Keys)` | nenhum enum literal que duplique tabela (exceto `State`, `Result`, `Grade`, `Action` literais do §3–§4) |
| T004-03 | boot sem erro de `Lync.start()` | M | 1p, F5 | Output sem erro de schema |
| T004-04 | jogador novo | M | 1p, conta de teste sem perfil (Studio: DataStore de teste limpo) | `Profile` chega com `Classes = { class_dog }`, `Selected = class_dog`, `Gems = 0` |
| T004-05 | Template = `data.md` §1.1 | E | ler `Template.luau` | sem `Coins`/`Level`/`Playtime`; `Version = 1` |
| T004-06 | legado compila | E | analyze | `RoundService`/`VitalService` atuais sem erro |
| T004-07 | `Profile` é privado | M | 2p; alterar gemas do jogador A (R2) | só o client de A recebe `Profile`; B não vê gemas de A |

### TASK-005 — Binding do MAP-01 (place)

| ID | Critério | Tipo | Passos | Esperado |
|---|---|---|---|---|
| T005-01 | 0 tag faltando | S | `tools/assetplace/check_binding.luau` no Command Bar (edição) e `MapIndex.Validate` no `OnStart` | lista vazia (`architecture.md` §18.7 itens 1–6) |
| T005-02 | prompts vizinhos ≥ 2,5 studs (grade de complementos 2,0) | S | parte da checagem | sem violação |
| T005-03 | bancada do carrinho a 3,0 (DEC-157, **[P]** Q-153) | S | pivôs a y 3,45 | ok |
| T005-04 | grafo sem cruzar pista | S | checagem item 6 | nenhuma aresta cruza Z-03/Z-07/Z-08 |
| T005-05 | tábua com 2 vagas | M | Explorer: `CART-T` | `Att_Bun1` (`Slot = 1`), `Att_Bun2` (`Slot = 2`), um `Prompt_Board` com `PromptAction = board_add_sausage` |
| T005-06 | `Persistent` | S | checagem item 5 | todo `Model` com tag de gameplay `ModelStreamingMode = Persistent` |

### TASK-006 / TASK-007 — Kits (place)

| ID | Critério | Tipo | Passos | Esperado |
|---|---|---|---|---|
| T006-01 | todo id de `CrewLooks` existe | S | script: para cada id, `ContentProvider:PreloadAsync` / checar no kit | 0 faltando |
| T006-02 | sem `InsertService` | E | grep | nada |
| T006-03 | montagem por espécie Day/Mid/Night | M | story/script de teste: 18 espécies × 3 packs | nenhuma peça faltando; guaxinim só com `thief` |
| T007-01 | `TopHeight` em toda cobertura | S | percorrer `Assets.Items.Toppings` | 6/6 com número > 0 |
| T007-02 | HotDog na mão do rig da crew | M | 1p, equipar Tool `hot_dog` manualmente (servidor) | grip correto em R6, 1ª e 3ª pessoa |
| T007-03 | tris dentro das fichas | E | contar no Studio | ≤ orçamento do `style-guide.md` |

### TASK-008 / TASK-009 — Conteúdo

| ID | Critério | Tipo | Passos | Esperado |
|---|---|---|---|---|
| T008-01 | número com origem | E | ler `Shift`, `RunParams`, `Upgrades`, `Vehicles`, `Flow`, `Orders` | todo número com DEC/FEAT em comentário |
| T008-02 | valores | E | conferir | Prep 60 / Open 360 / Closing 30 / Summary 15; StartCash 30; Flow 22 s, 0,08/dia, teto 0,40, `PartyMult` {1,0;1,6;2,1;2,5}, `MaxCustomersDay` 8, `MaxNpc` 12; Grill 2/3/4 vagas, 12/10/8 s (DEC-201) |
| T008-03 | nível por veículo (DEC-184) | E | `Upgrades[k].Levels.cart` e `.trailer` | `trailer_lights` só em `trailer`; `Levels[v][1].Price = 0` em grill/cooler/counter |
| T008-04 | mudar número sem código | S | trocar `Shift` Open 360 → 120 numa cópia local | turno encurta sem mudar código |
| T009-01 | `Validate` recusa `Stat` fora da lista | S | classe com `{ Stat = "Chances" }` | `error` |
| T009-02 | nenhuma classe usa guaxinim | S | classe com `Species = "raccoon"` | `error` |
| T009-03 | 6 `InMvp`, preços | E | `Classes` | dog 0, rabbit/cat/bear 45, fox/owl 120 (DEC-186); panda/lion `InMvp = false` |
| T009-04 | `CustomerTypes` (DEC-188) | E | ler | NPC-001..006 com as espécies da DEC-188; nenhum usa `raccoon` nem `Outfits.crew` |

### TASK-010 — `Place` + `RunState`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T010-01 | 2 jogadores em `Members` | M | 2p | entrar | `RunState.RosterSize = 2`; `Members` com 2 entradas, classe e `EverJoined = true` |
| T010-02 | `Notify` só a quem deve | M | 2p | provocar `hands_full` em A (T022-01) | toast só em A; `upgrade_bought` (T035-02) chega a A e B |
| T010-03 | Service fora do papel | E | — | ler `OnInit` | retorno no topo quando `Is("Run")` é falso |
| T010-04 | `PriceParty` no fim do Day 1 (DEC-121) | M | 2p | B sai no meio do Day 1 e não volta; chegar ao Summary | `PriceParty = 2` (B tinha `EverJoined`); não muda no Day 2 se entrar um 3º |
| T010-05 | snapshot em memória | S | 1p | `RegisterSnapshot` chamado por Economy/Kitchen/Upgrade | capture/restore registrados; nada em MemoryStore na onda 1 |

### TASK-011 — `InteractionService`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T011-01 | único responder de `Interact` | E | — | grep `Interact:onServer` | uma ocorrência, no `OnInit` do `InteractionService` |
| T011-02 | `EntityId` inexistente | M | 1p | client forja `Interact{Id = 65000, Action = "grill_place"}` | descartado, sem erro no Output do servidor |
| T011-03 | fora do raio | M | 1p | ficar no Mart; forjar `grill_place` no `EntityId` da caixa de salsicha | descartado; estoque igual |
| T011-04 | taxa > 8/s | M | 1p | loop de 30 `fireServer` no mesmo frame com `grill_place` válido | ≤ 8 processados no segundo; resto descartado sem erro (R4) |
| T011-05 | serialização no mesmo frame | M | 2p | ver T027-02 | só um recebe |
| T011-06 | ação errada para o alvo | M | 1p | forjar `serve` no `EntityId` de uma vaga da grelha | descartado |
| T011-07 | ação de onda futura | M | 1p | forjar `pick_up_item`, `buy_trailer`, `bench_buy_item`, `hide` em qualquer âncora | descartado (nenhuma `RegisterAction` dessas na onda 1) |
| T011-08 | `PromptEnabled`/`PromptText` | M | 1p | olhar Explorer (Server) | atributos escritos só pelo servidor; mudar no client não muda o servidor |
| T011-09 | id liberado volta só após 10 s | S | — | NPC some e outro nasce em < 10 s | ids diferentes |

### TASK-012 — `RoundService` (FEAT-003)

| ID | Critério | Tipo | Jog. | Plat. | Passos | Esperado |
|---|---|---|---|---|---|---|
| T012-01 | nenhum cliente antes de 8:00 AM | M | 1p | PC | não tocar "Open Shop"; observar 60 s de Prep | 0 NPC em D1/SP-A; fase vira Open em 60 s; relógio pula para 8:00 |
| T012-02 | "Open Shop" antecipa | M | 1p | ambos | tocar na placa no 10º s | fase Open; relógio 8:00 AM; placa OPEN |
| T012-03 | "Open Shop" só na Prep, qualquer jogador | M | 2p | ambos | B abre; depois A forja `open_sign` no Open | B consegue; forjado descartado, fase não reinicia |
| T012-04 | CLOSED às 6:00, fim em ≤ 30 s | M | 1p | PC | deixar 2 clientes na fila às 5:50 PM e atender | às 6:00 PM placa CLOSED, nenhum spawn depois; fila ainda atendida; Summary em ≤ 30 s (antes, se o balcão esvaziar) |
| T012-05 | Closing termina com balcão vazio | M | 1p | PC | fila vazia às 6:00 PM | Summary quase imediato |
| T012-06 | horário igual para todos | M | 2p | PC + Mob | comparar relógio nas 2 janelas em 5 instantes | diferença ≤ 1 passo de 10 min (FEAT-003) |
| T012-07 | relógio não pausa com jogador fora | M | 2p | PC | B sai às 10:00 AM; medir tempo real até 6:00 PM | mesmo ritmo (1 h = 36 s ± 1 s) |
| T012-08 | Day N → Day N+1 | M | 1p | PC | completar o Summary | `Shift.Day = 2`, fase Prep; `Night = 0`, `IsNight = false` fixos |
| T012-09 | campos fixos da onda 1 | S | — | — | ler `Shift` | `Vehicle = cart`, `Chances = 1`, `WipeEndsAt = 0`, `Attempt = 0` |

### TASK-013 — Componentes (já entregue)

| ID | Critério | Tipo | Esperado |
|---|---|---|---|
| T013-01 | puros, sem `require` de Controller | E | ok |
| T013-02 | stories abrem | M | UI Labs: `ProgressBar`, `PromptBillboard`, `Toast`, `UseTween` sem erro |
| T013-03 | toque na pílula do prompt | M | só validável em play test (T014-03) |

### TASK-014 — `PromptController` (FEAT-005)

| ID | Critério | Tipo | Jog. | Plat. | Passos | Esperado |
|---|---|---|---|---|---|---|
| T014-01 | **toda ação do MVP no mobile** só com interagir + hotbar + câmera | M | 1p | Mob (+📱real) | fazer o roteiro da §8 inteiro no emulador iPhone SE | todas as 13 ações da §3.18 executáveis; nenhuma exige teclado |
| T014-02 | um prompt visível por vez; alvo = mais próximo do centro com histerese | M | 1p | ambos | olhar entre duas tigelas vizinhas (2,0 studs) devagar | um prompt; sem piscar entre os dois na fronteira |
| T014-03 | soltar antes do fim do hold não dispara | M | 1p | ambos | "Restock" (1 s) soltando em 0,8 s; "Slice Bun" (0,5) em 0,3 | nada acontece; nenhum `Interact` enviado (R4) |
| T014-04 | `PromptEnabled = false` não aparece | M | 1p | ambos | grelha cheia → caixa de salsicha | "Grill" some |
| T014-05 | prompt condicional (FEAT-005) | M | 1p | ambos | sem HotDog perto das tigelas; com HotDog com ketchup | sem "Add X" sem HotDog; com HotDog, sem "Add Ketchup" |
| T014-06 | tecla E no PC / botão fixo no mobile | M | 1p | ambos | — | bind por `InputController:Bind` |
| T014-07 | hold mostra fill | M | 1p | ambos | segurar "Refuse" | fill de 0 → 1 em 1 s |
| T014-08 | **lag** | M | 1p | PC | lag 0,3 s; tocar "Grill" 2× rápido com 1 vaga livre | servidor aceita 1; o 2º descartado (vaga já ocupada) |

### TASK-015 — `RoundController`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T015-01 | relógio local ≤ 1 passo do servidor | M | 1p | comparar `ClockText` com a fórmula de `network.md` §3.1 no Command Bar | ≤ 1 passo |
| T015-02 | reconectar mostra a fase atual | M | 2p | B sai e volta no meio do Open | HUD de B mostra Open e hora certa na hora, sem esperar troca de fase |
| T015-03 | formato | M | 1p | — | "8:00 AM" … "6:00 PM", passo de 10 min (DEC-048) |

### TASK-016 — `CrewRig`

| ID | Critério | Tipo | Passos | Esperado |
|---|---|---|---|---|
| T016-01 | 18 espécies × roupas Crew e civil A–H | S | script de montagem | sem erro, sem peça faltando |
| T016-02 | troca de pack/expressão em runtime | S | `ApplyPack`/`SetExpression` no mesmo modelo | sem recriar o modelo |
| T016-03 | sem vazamento | S | 200 × `Build` + `Destroy`; `#workspace:GetDescendants()` e `stats():GetTotalMemoryUsageMb()` antes/depois | contagem volta ao valor inicial |
| T016-04 | `Dress` no client (T40 **[P]**) | E | — | servidor não escreve `TextureID`/`SurfaceAppearance` após a montagem (`network.md` §5.1) |

### TASK-017 — `ClassService` (FEAT-028, DEC-186)

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T017-01 | conta nova = Cachorro | M | 1p | perfil limpo | `Selected = class_dog`, `Classes = { class_dog }` |
| T017-02 | comprar sem gemas falha | M | 1p | `Gems = 0`; Buy `class_rabbit` | `Notice not_enough_gems`; perfil igual |
| T017-03 | compra com gemas | M | 1p | R2: 45 gemas; Buy `class_rabbit` | `Gems = 0`, `Classes` inclui `class_rabbit`; `class_bought` |
| T017-04 | compra dupla não cobra 2× | M | 1p | forjar 2 `Buy class_cat` no mesmo frame com 90 gemas | uma compra; `Gems = 45` |
| T017-05 | classe fora do MVP | M | 1p | forjar `Buy class_panda` com 999 gemas | recusado (`InMvp = false`) |
| T017-06 | Select de classe não possuída | M | 1p | forjar `Select class_fox` | `class_locked`; `Selected` igual |
| T017-07 | Select depois do spawn | M | 1p | já spawnado; forjar `Select class_rabbit` | recusado (só antes do spawn, **[P]** modo dev) |
| T017-08 | classe travada fora do modo dev | M | 1p | `Workspace.PlaceRole` de não-dev (simular) e `Select` | recusado (DEC-069/186). Se não for simulável no Studio: **E** no código |
| T017-09 | perfil por cópia | E | — | — | `profile.Classes(withKey(...))`, nunca mutação no lugar (`data.md` §1.1) |
| T017-10 | `GetModifier` | S | — | `GetModifier(p, "WalkSpeed")` por classe | dog 16, rabbit 18, cat 15, bear 16 (14 com 3 pacotes), fox 16, owl 15 (dia) |
| T017-11 | gemas de dev sem rede | E | — | — | comando só no servidor com `IsDev()`; nenhum packet c → s dá gemas |
| T017-12 | taxa `ClassAction` ≤ 2/s | M | 1p | 20 `Select` num frame | ≤ 2 processados |

### TASK-018 — `CharacterService`

| ID | Critério | Tipo | Jog. | Plat. | Passos | Esperado |
|---|---|---|---|---|---|---|
| T018-01 | animal da classe | M | 2p | PC | A Cachorro, B Coelho (T017-03) | cada um vê o outro com o animal certo, uniforme Crew, rosto Normal |
| T018-02 | atravessam um ao outro (DEC-175) | M | 2p | PC | andar um contra o outro no corredor do carrinho e no Mart | sem colisão em todo o mapa **[P]** |
| T018-03 | velocidades | M | 2p | PC | medir 50 studs em linha reta | Coelho 18, Cachorro 16 (±0,5) |
| T018-04 | nenhum avatar do Roblox | M | 2p | ambos | entrar, morrer/respawn (resetar personagem) | sempre o rig da crew; `CharacterAutoLoads = false` |
| T018-05 | spawn em PS-1..4 | M | 2p | — | — | cada um num PS diferente, olhando para o norte |
| T018-06 | atributos | M | 1p | — | Explorer | `Species`, `Outfit = crew`, `LookPack = Day` |
| T018-07 | Urso com 3 pacotes | M | 1p | PC | Urso compra 3 pacotes | velocidade 14 com 3; volta a 16 com 2 |

### TASK-019 — `CameraController`

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T019-01 | 1ª pessoa travada; nada do próprio rosto/orelha/boné na visão | M | 1p | ambos | testar as 6 espécies (orelhas do Coelho e do Urso) olhando para cima, baixo, lados |
| T019-02 | colegas veem o personagem completo | M | 2p | PC | cabeça e orelhas de A visíveis para B |
| T019-03 | Tool na mão em 1ª pessoa (DEC-097) | M | 1p | ambos | HotDog e pacote visíveis na mão |

### TASK-020 — Tela "Crew"

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T020-01 | 6 animais; sem guaxinim/panda/leão jogáveis | M | 1p | ambos | só os 6 da DEC-186 |
| T020-02 | reflete o `Profile` em ≤ 1 s após compra | M | 1p | ambos | cronometrar do Buy até o estado "desbloqueado" |
| T020-03 | Buy desabilitado sem gemas | M | 1p | ambos | botão inativo; forjar `ClassAction` mesmo assim → T017-02 |
| T020-04 | funciona em mobile | M | 1p | Mob (+📱real) | tela cabe em 667×375; botões tocáveis; prévia no `ViewportFrame` |
| T020-05 | não conflita com FEAT-032 | M | 1p | ambos | a tela é a exceção de botão; fechada, o HUD do jogador ativo não tem clicável (T039-01) |

### TASK-021 — `EconomyService` (FEAT-012, FEAT-014)

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T021-01 | `Cash` inicia em 30 | M | 1p | início do Day 1 | `Economy.Cash = 30`, `Drawer = 0` |
| T021-02 | dinheiro da party não muda com venda | M | 1p | vender 3 hot dogs | `Cash` igual; `Drawer` sobe |
| T021-03 | depósito no Summary | M | 1p | gaveta $20, nota A | Bônus = floor(20 × 0,20) = 4; `Deposited = 24`; `Cash` +24; `Drawer = 0` |
| T021-04 | bônus inteiro | M | 1p | gaveta $17, nota B | floor(1,7) = 1 |
| T021-05 | sem cliente = C | M | 1p | R1/turno com 0 chegadas (não abrir e fechar a fila) | `Grade = C`, `Bonus = 0` |
| T021-06 | nota D | M | 1p | 4 chegam, 1 completo (25%) | `D`, bônus 0 |
| T021-07 | **duas compras simultâneas nunca negativo** | M | 2p | `Cash = 6`; A e B seguram "Buy Sausages — $6" e soltam juntos (ou forjar no mesmo frame) | exatamente 1 compra; `Cash = 0`; o outro recebe `not_enough_cash` |
| T021-08 | `ShiftReport` ao grupo | M | 2p | fim do turno | os dois recebem; campos `Arrived`, `Completed`, `Drawer`, `Tips`, `Bonus`, `Deposited`; `Stolen = 0`, `Gems = 0`, `AfkLocked = false` |
| T021-09 | nota igual para a party, calculada no servidor | E | — | — | nota só no `EconomyService`; nenhum client calcula |
| T021-10 | snapshot | S | — | — | `Cash` registrado; `Drawer`/ledger zeram (`data.md` §2.2) |

### TASK-022 — `ItemService` (FEAT-005)

| ID | Critério | Tipo | Jog. | Plat. | Passos | Esperado |
|---|---|---|---|---|---|---|
| T022-01 | 5º Tool bloqueado com aviso | M | 1p | ambos | 2 pacotes + 2 HotDogs; tentar "Add Sausage" | bloqueado; toast "Hands full" (`hands_full`) |
| T022-02 | limite de pacotes | M | 1p | ambos | Cachorro com 2 pacotes tenta o 3º | bloqueado; `package_limit` |
| T022-03 | Urso 3 pacotes, dentro de 4 | M | 1p | PC | Urso: 3 pacotes + 1 HotDog; tentar 2º HotDog | 3 pacotes ok; 2º HotDog bloqueado (total 4) |
| T022-04 | limite de HotDog = 2 **[P]** | M | 1p | PC | 2 HotDogs + 0 pacote; "Add Sausage" | bloqueado (`hands_full`) |
| T022-05 | pacote com sobra mantém `Count` | M | 1p | PC | Restock que transfere 3 de 8 (T025-01) | Tool fica com `Count = 5` |
| T022-06 | HotDog criado pelo servidor na mão de quem tocou | M | 2p | PC | B toca "Add Sausage" | Tool aparece equipada em B, não em A |
| T022-07 | atributos | M | 1p | — | Explorer | `Item = hot_dog`, `Toppings = ""` ao nascer; `Count` só em pacote |
| T022-08 | hotbar mobile mostra 4 vagas | M | 1p | Mob (iPhone SE) +📱real | 4 Tools | as 4 visíveis e tocáveis (risco de FEAT-005) |

### TASK-023 — `HotDogVisual` (DEC-142)

| ID | Critério | Tipo | Passos | Esperado |
|---|---|---|---|---|
| T023-01 | qualquer combinação de até 3 | M/S | gerar as 42 combinações de 0 a 3 complementos entre 6 (1 + 6 + 15 + 20) num story/script; olhar de cima e na mão em 1ª pessoa | nada atravessa; nenhum cordão flutua |
| T023-02 | queijo antes dos cordões | M | montar Ketchup → Cheese | queijo por baixo do ketchup (não o cobre) |
| T023-03 | resto na ordem de montagem | M | Bacon → Potato Sticks e o inverso | ordem do visual = ordem de `Toppings` |
| T023-04 | chamado pelo servidor | E | — | `ItemService` chama; visual replica |

### TASK-024 — `EconomyController` + gaveta

| ID | Critério | Tipo | Jog. | Esperado |
|---|---|---|---|---|
| T024-01 | valor da gaveta igual para todos | M | 2p | A e B veem o mesmo número a cada venda |
| T024-02 | "+$N" na gaveta no `Sale` | M | 2p | os dois veem "+$6" na Perfect |
| T024-03 | modelo antigo e POS nova (DEC-155) | M | 1p | `Value_Anchor` nos dois modelos; sem erro se faltar (warn) |
| T024-04 | HUD de dinheiro = `Cash` | M | 1p | não muda em venda (T021-02) |

### TASK-025 — `KitchenService` + estoque (FEAT-007)

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T025-01 | Restock nunca passa da capacidade; sobra fica | M | 1p | salsicha 9/12; Restock com pacote de 8 | 12/12; pacote `Count = 5` |
| T025-02 | pacote vazio some | M | 1p | salsicha 4/12; Restock com 8 | 12/12; Tool some |
| T025-03 | Restock com estoque cheio | M | 1p | 12/12, pacote na mão | prompt "Restock" não aparece (ou não faz nada); pacote intacto |
| T025-04 | pacote errado | M | 1p | pacote de pão na caixa de salsicha; forjar `restock` | recusado |
| T025-05 | Cooler aumenta capacidade na hora, sem mudar o atual | M | 1p | salsicha 7/12; comprar Cooler 2 | 7/20 imediato, mesmo com o comprador no Mart |
| T025-06 | estoque do Day N+1 = fim do Day N | M | 1p | anotar os 9 `Amount` no Summary | iguais no Prep seguinte |
| T025-07 | `Stock` sempre 9 registros; `coffee` bloqueado | S | — | ler | `coffee`: `Blocked = true`, `Amount = 0` |
| T025-08 | estoque inicial cheio (DEC-049) | M | 1p | Day 1 | bun/sausage 12, ketchup/mustard 30 |
| T025-09 | pacote grátis no dia de liberação (DEC-071) | M | 1p | Day 2 (R1) | 1 `pack_cheese` aparece sobre a estação do queijo; ver lacuna L-03 |
| T025-10 | `Blocked` recalculado no `ShiftStarted` | M | 1p | Day 1 → 2 | `cheese.Blocked` false no Day 2; `bacon` segue true |

### TASK-026 — Grelha + trilho (FEAT-006 1–3)

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T026-01 | sem vaga não grelha | M | 1p | 2 salsichas na grelha L1; "Grill" | prompt some; forjado recusado; estoque igual |
| T026-02 | estoque 0 não grelha | M | 1p | gastar as 12 | "Grill" some; forjado recusado |
| T026-03 | estoque cai exatamente 1 | M | 1p | "Grill" | `Amount` −1; lag 0,3 s + 2 toques rápidos com 1 vaga = −1 |
| T026-04 | barra ±0,2 s do nível | M | 1p | cronometrar com `StartedAt/Duration` e com o vídeo | L1 12 s, L2 10 s, L3 8 s |
| T026-05 | Line Cook 0,85× só nas dele | M | 2p | A Gato e B Cachorro grelham ao mesmo tempo (L1) | A 10,2 s, B 12 s; barra de cada vaga com o tempo certo (§1.7) |
| T026-06 | não queima | M | 1p | deixar `Ready` 2 min | segue `Ready`, ocupa a vaga |
| T026-07 | Collect → trilho FIFO, 6 no carrinho | M | 1p | 6 no trilho; "Collect" | prompt some/recusado com trilho cheio |
| T026-08 | vaga nova do Grill 2 entra vazia; em andamento não reinicia | M | 2p | A grelha 2; B compra Grill 2 no Mart | 3ª vaga `Empty`; as 2 continuam com o mesmo `StartedAt` |

### TASK-027 — Pão + tábua (DEC-190)

| ID | Critério | Tipo | Jog. | Plat. | Passos | Esperado |
|---|---|---|---|---|---|---|
| T027-01 | "Slice Bun" ocupa vaga livre de menor `Slot` | M | 1p | ambos | 2× "Slice Bun" | vaga 1 depois vaga 2; corte 1,5 s; 3º "Slice Bun" some (sem vaga) |
| T027-02 | **dois jogadores, mesma tábua, mesmo instante: só um recebe** | M | 2p | PC + Mob | 1 pão `Ready`, 1 salsicha no trilho; A e B tocam "Add Sausage" juntos (contagem em voz alta; repetir 10×; também forjado no mesmo frame pelos 2 clients) | exatamente 1 HotDog no total; trilho −1; vaga −1; o outro não recebe nada |
| T027-03 | duas vagas `Ready`, dois toques | M | 2p | PC | 2 pães `Ready`, 2 salsichas | cada um recebe 1; vaga mais antiga primeiro |
| T027-04 | hotbar cheia bloqueia "Add Sausage" | M | 1p | ambos | 4 Tools | "Hands full"; pão e salsicha ficam |
| T027-05 | sem trilho | M | 1p | — | pão `Ready`, trilho vazio | "Add Sausage" não aparece |
| T027-06 | pão: estoque −1 | M | 1p | — | "Slice Bun" | `bun.Amount` −1 |

### TASK-028 — Complementos + lixeira

| ID | Critério | Tipo | Jog. | Plat. | Passos | Esperado |
|---|---|---|---|---|---|---|
| T028-01 | "Add X" some para complemento já presente | M | 1p | ambos | HotDog com ketchup | sem "Add Ketchup"; forjado recusado; `Toppings` igual |
| T028-02 | "Add X" some com estoque 0 | M | 1p | ambos | gastar todo o mustard | sem "Add Mustard"; forjado recusado |
| T028-03 | máximo 3 | M | 1p | — | Day 4+ (R1): 3 complementos; tentar o 4º | prompt some; forjado recusado |
| T028-04 | tigela `Blocked` (DEC-156) | M | 1p | ambos | Day 1, tigela do queijo | tampa + cadeado; sem prompt; forjar `topping_add` no queijo → recusado |
| T028-05 | bloqueio some no dia de liberação | M | 1p | — | Day 2 | tampa/cadeado do queijo somem; bacon segue |
| T028-06 | consome 1 uso | M | 1p | — | "Add Ketchup" | `ketchup.Amount` −1; `Toppings = "ketchup"` |
| T028-07 | "Throw Away" | M | 1p | ambos | hold 0,5 na lixeira com HotDog | Tool some; nada volta ao estoque |
| T028-08 | sem HotDog na mão | M | 1p | — | forjar `topping_add` e `discard` | recusado |
| T028-09 | HotDog na hotbar mas não equipado | M | 1p | PC | HotDog na hotbar, pacote na mão; forjar `topping_add` | recusado (requisito é **na mão**, `Held`) |

### TASK-029 / TASK-030 — Visuais da cozinha

| ID | Critério | Tipo | Jog. | Esperado |
|---|---|---|---|---|
| T029-01 | contadores iguais para todos | M | 2p | "7/12" igual em A e B; vermelho com ≤ 2 |
| T029-02 | `Fill` acompanha Restock e consumo | M | 1p | tween curto; ketchup 30 → 15 = metade |
| T029-03 | ícone placeholder (Q-152) | M | 1p | `SurfaceGui` na `Label_<Ing>` sem erro com `Icon = ""` |
| T029-04 | cadeado por `Stock.Blocked` | M | 1p | segue `Blocked`, não `Shift.Day` |
| T030-01 | barra termina junto com o "Ready" (±0,2 s) | M | 1p | grelha e tábua |
| T030-02 | quem reconecta vê o estado atual | M | 2p | B sai e volta com 2 salsichas na grelha a 50% e 1 pão cortado | barras de B continuam do ponto certo; pão cortado na vaga certa |
| T030-03 | salsichas no trilho | M | 1p | `Count` visível = registro `rail.Count` |

### TASK-031 — `NpcService`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T031-01 | nunca > 12 NPCs | S/M | 2p | Day 6+ (R1), Counter 3, ninguém atende; contar a cada 1 s por 10 min | máximo ≤ 12 (Opal fora, DEC-191) |
| T031-02 | nenhum NPC com uniforme Crew nem guaxinim | S | 1p | 30 min; checar `Outfit` e `Species` de todo NPC spawnado | `Outfit ∈ civil_a..h`; `Species ≠ raccoon`; espécie ∈ `CustomerTypes[tipo].Species` |
| T031-03 | pool reaproveita rigs (soak 30 min) | S | 1p | 30 min de Open contínuo (R1 para repetir o Open ou 4 dias) | nº de rigs do pool não cresce; `NpcId` novo a cada spawn |
| T031-04 | sem colisão com jogadores/NPC | M | 1p | ficar na frente da fila | NPC atravessa; jogador não empurra NPC |
| T031-05 | spawn em D1 e SP-A; rota por grafo | M | 1p | observar 10 clientes | só por D1/SP-A; caminho = arestas do grafo |
| T031-06 | pack Day de dia | M | 1p | — | `LookPack = Day` |

### TASK-032 — `CustomerService` (FEAT-009)

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T032-01 | 16 ± 2 clientes no Day 1 solo | S | 1p | 5 Days 1 (R1) com atendimento rápido ou Refuse para nunca encher a fila; contar spawns (R5) | média 14–18 por dia; ver lacuna L-05 |
| T032-02 | fila cheia não gera cliente | M | 1p | Counter 1 (Q1–Q3), ninguém atende | 3 na fila; nenhum novo nasce; o pulado não entra em `Arrived` |
| T032-03 | ≤ 12 NPCs | — | — | = T031-01 | — |
| T032-04 | só no Open | M | 1p | Prep e Closing | 0 spawn |
| T032-05 | `PartyMult` pelos conectados, no `ShiftStarted` **[P]** | M | 2p | Day 1 com 2p; B sai às 10:00 AM | fluxo do Day 1 segue ×1,6; no Day 2 vira ×1,0 |
| T032-06 | avança até Q1; saída EX-E/D1 | M | 1p | servir Q1 | Q2 → Q1; quem sai vai a EX-E ou D1 |
| T032-07 | Counter 2 → Q4 | M | 1p | comprar Counter 2 com 3 na fila | Q4 passa a aceitar na hora |
| T032-08 | `Customers` sem aparência | E | — | — | set sem `Look` (v4); aparência em atributos do rig |

### TASK-033 — Pedido, atendimento, pagamento (FEAT-010, FEAT-011)

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T033-01 | distribuição de K ±3 p.p. em 1.000 sorteios por fase | S | — | R3: 1.000 sorteios em Day 1, 2, 4, 6 | Day 1: 10/60/30/0; 2–3: 5/45/40/10; 4–5: 5/35/40/20; 6+: 0/30/40/30 (±3 p.p.); ver nota "K > liberados" abaixo |
| T033-02 | sem ingrediente não liberado | S | — | Day 1: 1.000 sorteios | só ketchup/mustard; nunca K = 3 |
| T033-03 | sem repetição, ≤ 3 | S | — | Day 6: 1.000 | nenhum pedido com chave repetida ou > 3 |
| T033-04 | multiplicador do tipo ±3 p.p. | S | — | R3 com 2 tipos de `IngredientMult` diferentes | frequência proporcional à tabela |
| T033-05 | ×1,5 no dia de liberação | S | — | Day 2: frequência de cheese | peso 7 × 1,5 |
| T033-06 | `Order` vazio até "Take Order" | M | 1p | cliente em Q1 `Ordering` | balão vazio; set `Customers.Order` vazio |
| T033-07 | "Serve" só com pedido anotado | M | 1p | ambos | antes do "Take Order": prompt "Serve" não existe; forjado recusado |
| T033-08 | preços (§3.9) | M | 1p | entregar completos | ketchup $5; + cheese $7 (K: ketchup+cheese); bacon + mustard $8; K = 0 $4 |
| T033-09 | gorjeta na janela | M | 1p | K = 1: servir 10 s após "Take Order" | `Perfect`, +$1 (total $6) |
| T033-10 | gorjeta nunca fora da janela | M | 1p | K = 1: servir 25 s após "Take Order" (janela 20 s) | `Complete`, $5 |
| T033-11 | incompleto = floor(50%), sem gorjeta | M | 1p | pedido ketchup+mustard ($6), entregar só ketchup em 5 s | `Incomplete`, $3 |
| T033-12 | errado = $0, HotDog volta | M | 1p | pedido ketchup, entregar com mustard | `Wrong`, $0, Tool volta à mão de quem serviu com `Toppings` igual; cliente vai embora (Complaining) |
| T033-13 | paciência 40 + 5K desde a chegada | M | 1p | K = 1 sem atender | sai em 45 s ± 1 a partir de ocupar a vaga; `Left`, $0 |
| T033-14 | Counter soma paciência | M | 1p | Counter 2 | K = 1 → 55 s |
| T033-15 | Raposa −4 s e $2 **[P]** "pedido do dono" | M | 2p | A Raposa faz "Take Order" K = 1; B serve em 18 s | janela 16 s → sem gorjeta; se A serve em 10 s, +$2 |
| T033-16 | "Refuse" hold 1 s | M | 1p | ambos | cliente vai embora; `Refused`, $0; conta em `Arrived`, não em `Completed` |
| T033-17 | client não manda preço nem resultado | E | — | — | handler de `serve` lê só `{Id, Action}`; preço do `Content` + `Toppings` da Tool no servidor |
| T033-18 | ordem dos complementos ignorada | M | 1p | pedido ketchup+mustard, montar mustard → ketchup | `Complete` |
| T033-19 | humor só visual **[P]** Q-164 | M | 1p | Annoyed a ≤ 1/3 da paciência; servir completo | pagamento igual ao sem humor (`AffectsPay = false`) |
| T033-20 | Serve em cliente `Ordering` | M | 1p | forjar `serve` antes do "Take Order" | recusado; HotDog fica |

Nota de K: no Day 1 há 2 complementos liberados e K = 3 tem peso 0, então "K > liberados" não ocorre; no Day 2–3
(3 liberados) também não. A regra "K = liberados" só é testável com peso de K maior que os liberados (não acontece
na tabela atual); conferir por leitura (**E**).

### TASK-034 — `CustomerController`

| ID | Critério | Tipo | Jog. | Esperado |
|---|---|---|---|---|
| T034-01 | balão só depois do "Take Order" | M | 2p | A anota; A e B veem o balão ao mesmo tempo |
| T034-02 | ≤ 8 balões | M | 1p | Day 6+ com fila longa (Counter 3) | nunca > 8 |
| T034-03 | rosto pelo `Mood` | M | 1p | Normal → Skeptical (Annoyed) → Happy (Completo) / Stressed (Complaining) |
| T034-04 | reação ao `Sale` | M | 2p | feliz/neutro/reclamação iguais nos 2 clients |
| T034-05 | ícone placeholder (Q-152) | M | 1p | sem erro com `Icon = ""` |

### TASK-035 — `UpgradeService` (FEAT-015)

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T035-01 | efeito imediato | M | 2p | B no Mart compra Grill 2 | vaga 3 aparece na hora (T026-08) |
| T035-02 | peça muda para todos em ≤ 1 s, sem ir ao veículo | M | 2p | A no carrinho, B compra | peça nova em A em ≤ 1 s; toast "Grill upgraded!" em A e B |
| T035-03 | sem prompt de compra no equipamento | M | 1p | olhar todas as estações | nenhuma oferece compra |
| T035-04 | nível por veículo (DEC-184) | S | — | — | estado guarda `Levels.cart`; set só do veículo atual |
| T035-05 | sem saldo | M | 1p | `Cash` < preço | ver T036-05 |
| T035-06 | `Spend` atômico | M | 2p | dois compram Cooler 2 juntos com dinheiro para um | 1 nível só (não pula 2 níveis); o outro: `not_enough_cash` ou recusado por nível já comprado |

### TASK-036 / TASK-037 — Mart (FEAT-008, FEAT-015, DEC-180)

| ID | Critério | Tipo | Jog. | Plat. | Passos | Esperado |
|---|---|---|---|---|---|---|
| T036-01 | compra de pacote | M | 1p | ambos | hold 0,5 "Buy Sausages — $6" | `Cash` −6; Tool `pack_sausages` `Count = 8` na mão |
| T036-02 | ingrediente não liberado = "Out of stock", sem compra | M | 1p | ambos | Day 1, prateleira do queijo; forjar `buy_package` | etiqueta "Out of stock"; sem prompt; forjado recusado, `Cash` igual |
| T036-03 | Coffee só depois do trailer | M | 1p | — | prateleira do café na onda 1 | "Out of stock" (ou ausente), sem compra |
| T036-04 | frutas/verduras sem prompt (DEC-109) | M | 1p | ambos | percorrer o expositor | nenhum prompt |
| T036-05 | sem saldo não compra; party nunca negativa | M | 1p | ambos | `Cash = 3`; segurar "Buy Sausages" | preço em vermelho; hold não executa; forjado → `not_enough_cash`, `Cash = 3` |
| T036-06 | duas compras simultâneas nunca acima do saldo | M | 2p | — | = T021-07 | — |
| T036-07 | limite de pacotes e hotbar | M | 1p | — | 2 pacotes; comprar o 3º | recusado antes de cobrar (`Cash` igual) |
| T036-08 | B1–B4 em 100% dos turnos | M | 1p | — | 3 turnos seguidos | B1–B4 sempre com prompt (salvo "Maxed") |
| T036-09 | B5 "Trailer only" | M | 1p | — | olhar B5; forjar `bench_buy_upgrade` em B5 | placa "Trailer only"; forjado recusado |
| T036-10 | "Maxed" sem prompt | M | 1p | — | Grill 3 | "Maxed"; sem prompt; forjado recusado, `Cash` igual |
| T036-11 | S1 "Nothing special today" | M | 1p | — | olhar S1 | texto; sem prompt; forjar `bench_buy_item` → recusado |
| T037-01 | preço vermelho sem saldo | M | 1p | ambos | `Cash` < preço | vermelho nas prateleiras e na bancada |
| T037-02 | etiqueta some no dia de liberação | M | 1p | — | Day 2 | queijo à venda; bacon "Out of stock" |
| T037-03 | sem UI de loja em tela (DEC-015) | M | 1p | ambos | — | tudo em billboard no mundo |
| T036-12 | Mart aberto em toda fase | M | 1p | — | comprar na Prep, Open, Closing e Summary | todas funcionam |

### TASK-038 — Opal

| ID | Critério | Tipo | Jog. | Esperado |
|---|---|---|---|---|
| T038-01 | não conta no teto de NPC | S | 1p | nenhum rig da Opal no servidor; contagem de T031-01 sem ela |
| T038-02 | fala ao entrar a 8 studs, 1× por visita | M | 1p | entrar/sair 3× | 1 balão por entrada |
| T038-03 | zero rede | E | — | `OpalController` sem `Net` |
| T038-04 | nunca anomalia (DEC-191) | E | — | sem gancho de anomalia |
| T038-05 | fala muda entre dia e noite | E | — | na onda 1 só há dia: verificar por leitura que a fase vem de `OpalLines` por `IsNight` |

### TASK-039 — HUD (FEAT-032, FEAT-014)

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T039-01 | nenhum elemento clicável para jogador ativo | M | 1p | ambos | clicar/tocar em todo o HUD: nada responde; hotbar nativa é a única exceção |
| T039-02 | sem reputação, chances, XP, sanidade de dia | M | 1p | ambos | ausentes |
| T039-03 | relógio, "Day N", dinheiro | M | 2p | ambos | iguais nos 2 clients |
| T039-04 | toasts no canto superior direito, 3–6 s | M | 1p | ambos | `hands_full`, `upgrade_bought`, `ingredient_unlocked` |
| T039-05 | resumo some sozinho em 15 s | M | 1p | ambos | sem botão de fechar |
| T039-06 | resumo mostra as linhas de FEAT-014 | M | 1p | ambos | turno, completos/chegaram, gaveta, bônus com nota, depositado; sem "Roubado" quando 0 |
| T039-07 | layout mobile | M | 1p | Mob (iPhone SE) | nada sobrepõe a hotbar, o botão de interagir nem o joystick |

---

## 3. Client mal-intencionado (pacotes forjados)

Todos pelo Command Bar na visão **Client**, com `Net = require(game.ReplicatedStorage.shared.Libs.Net)`. Esperado
comum: servidor descarta **sem erro** no Output, estado igual, nenhum `Notice` falso a outros jogadores.

| ID | Pacote | Esperado |
|---|---|---|
| X-01 | `Interact{Id = <âncora a 200 studs>, Action = válida}` | descartado (raio + 2) |
| X-02 | `Interact` com `Id` de NPC que já saiu (id liberado < 10 s) | descartado (alvo não existe) |
| X-03 | 100 × `Interact` num frame | ≤ 8/s processados; servidor sem queda de FPS perceptível |
| X-04 | `Interact{Action = "serve"}` sem HotDog na mão | descartado |
| X-05 | `Interact{Action = "topping_add"}` em tigela `Blocked` | descartado |
| X-06 | `Interact{Action = "buy_package"}` em prateleira `Blocked` ou sem saldo | descartado; `Cash` igual |
| X-07 | `Interact{Action = "bench_buy_upgrade"}` em `Maxed`, B5, S1 | descartado |
| X-08 | `Interact{Action = "open_sign"}` fora da Prep | descartado |
| X-09 | `Interact` com ação de onda futura (`buy_trailer`, `pick_up_item`, `hide`, `brew_coffee`) | descartado |
| X-10 | `Interact{Action = "take_order"}` em cliente fora de Q1 | descartado |
| X-11 | `Interact{Action = "refuse"}` em cliente fora de Q1 | descartado |
| X-12 | `ClassAction{Buy, class_lion}` com gemas suficientes | recusado (`InMvp = false`) |
| X-13 | `ClassAction{Select, <não possuída>}` | `class_locked` |
| X-14 | client muda localmente `Toppings` da Tool para `"ketchup,mustard,cheese"` e serve | servidor usa o atributo **do servidor**; mudança local não replica |
| X-15 | client muda `PromptEnabled = true` local numa tigela bloqueada e segura o prompt | prompt pode aparecer local; `Interact` recusado no servidor |
| X-16 | client apaga/move a âncora local | sem efeito no servidor |
| X-17 | `Ready` repetido 50× | servidor não duplica `Profile`/estado (handshake idempotente) |
| X-18 | client tenta mover a Tool HotDog para outro jogador (`Parent`) | não replica (filtering) |
| X-19 | teleporte do personagem (exploit de movimento) até a tábua e "Add Sausage" | aceito só se dentro do raio; fora do escopo da onda 1 bloquear teleporte (anotar) |

---

## 4. Jogador sai no meio

| ID | Situação | Jog. | Esperado (fonte) | Observação |
|---|---|---|---|---|
| Q-01 | A sai segurando HotDog | 2p | Tools vão para o `Stash` e voltam ao reentrar (`data.md` §2.3) | **lacuna L-01**: nenhuma task da onda 1 implementa o stash. Registrar o comportamento real; esperado mínimo: Tool some sem erro e sem vazar instância |
| Q-02 | A anotou o pedido e sai; B serve | 2p | B serve normalmente; pagamento e gorjeta pela janela que já começou | se A era Raposa: qual gorjeta? **lacuna L-04** |
| Q-03 | A sai no meio do hold de "Slice Bun" | 2p | nada enviado; pão e estoque iguais | — |
| Q-04 | A (Gato) põe salsicha e sai | 2p | a salsicha termina em 10,2 s (tempo travado na colocação) | — |
| Q-05 | B sai durante o Summary | 2p | `ShiftReport` perdido para B; `Cash` certo ao voltar (`network.md` §4.4) | — |
| Q-06 | B sai e volta no Open | 2p | volta com a mesma classe; sets corretos na hora (Shift, Stock, Stations, Customers, Upgrades, Economy) | — |
| Q-07 | B sai; fluxo | 2p | multiplicador muda só no próximo `ShiftStarted` **[P]** | — |
| Q-08 | B sai com pacote pela metade (`Count = 5`) | 2p | volta com o pacote `Count = 5` (stash) | lacuna L-01 |
| Q-09 | único jogador sai | 1p | onda 1: servidor do Studio fecha; sem erro de `BindToClose` | suspensão é da onda 2 |
| Q-10 | B entra no meio do Day 2 (nunca entrou) | 2p | spawn em PS livre; `EverJoined = true`; `PriceParty` já fixo não muda | — |

---

## 5. Saldo insuficiente (resumo cruzado)

| ID | Onde | Esperado |
|---|---|---|
| $-01 | prateleira | preço vermelho; hold não executa; `not_enough_cash` se forjado (T036-05) |
| $-02 | bancada | idem (T035-05) |
| $-03 | duas compras com saldo para uma | só uma (T021-07, T035-06) |
| $-04 | gaveta não paga compra | com `Cash = 0` e `Drawer = 50`, compra recusada (FEAT-012) |
| $-05 | gemas | Buy sem gemas recusado (T017-02) |
| $-06 | `Cash` nunca negativo | nenhum caminho escreve `Cash < 0` (o `Lync.int(0, …)` estouraria): **E** em `Spend` |

---

## 6. Desempenho e orçamento

| ID | Medida | Jog. | Esperado |
|---|---|---|---|
| P-01 | banda Lync por client | 4p (opcional) / 2p | < 150 B/s no pico (`network.md` §9); Studio → View → Stats / Network |
| P-02 | NPCs | 2p | ≤ 12 (T031-01) |
| P-03 | memória após 30 min | 1p | sem crescimento contínuo (T031-03, T016-03) |
| P-04 | FPS mobile | Mob +📱real | ≥ 30 no carrinho com 8 clientes na fila |

---

## 7. Matriz de plataforma (DEC-171)

Mínimo a repetir no **mobile** (emulador iPhone SE; 📱real se publicado): T014-01, T014-02, T014-03, T019-01,
T020-04, T022-08, T027-02 (A no PC, B no mobile), T036-05, T039-01, T039-07. O resto basta no PC. Console: fora.

---

## 8. Roteiro integrado (base da TASK-041)

Rodar **solo (PC)**, **solo (mobile)** e **party de 2 (PC + mobile)**. Cada passo cita os casos que ele cobre.

1. Entrar → tela "Crew" (T020); Cachorro selecionado (T017-01). Na party: B compra o Coelho com gemas de dev (T017-03).
2. Spawn como o animal em 1ª pessoa, em PS-n (T018, T019). Party: atravessam um ao outro (T018-02).
3. Prep: relógio 7:00 AM (T015); estoque cheio (T025-08); queijo/bacon com cadeado (T028-04); "Open Shop" (T012-02).
4. Cliente chega a Q1 (T031-05, T032-06); "Take Order" (T033-06); balão (T034-01).
5. Montagem: "Grill" (T026-03) → barra (T026-04) → "Collect" (T026-07) → "Slice Bun" (T027-01) → "Add Sausage"
   (T022-06) → "Add Ketchup" (T028-06, T023).
6. "Serve" na janela (T033-09): gaveta sobe (T024-01/02); `Cash` igual (T021-02).
7. Erro proposital: servir errado (T033-12), jogar na lixeira (T028-07).
8. Party: os dois tocam "Add Sausage" juntos (T027-02).
9. 6:00 PM: CLOSED (T012-04); Summary (T039-05/06); depósito e nota (T021-03).
10. Mart: comprar pacote (T036-01), "Out of stock" no queijo do Day 1 (T036-02), sem saldo (T036-05).
11. Restock com sobra (T025-01).
12. Bancada: comprar Grill 2 (T035-01/02) e ver a peça no carrinho em ≤ 1 s.
13. Day 2: queijo liberado (T025-10, T028-05, T037-02); pacote grátis (T025-09); bacon segue "Out of stock".
14. Fim: `modux check` e analyze zero erro (G-01, G-02).

---

## 9. Lacunas de spec encontradas ao escrever o plano

Achados para o dono indicado; nenhum bloqueia a onda. Cada um vira caso com esperado **a definir** até ser respondido.

| ID | Achado | Onde | Para |
|---|---|---|---|
| L-01 | `data.md` §2.3 diz que Tools vão para o `Stash` e voltam ao reentrar, mas **nenhuma task da onda 1** implementa isso (TASK-010 só lista `Members` com classe/`EverJoined`; TASK-022 não cita stash). Q-01/Q-08 ficam sem dono | `board.md` TASK-010/022; `data.md:176`, `data.md:222` | task-planner |
| L-02 | `network.md` §3.4 diz que o `PromptController` esconde "Restock" com `Amount = 0`. Deveria ser `Amount = Capacity` (ou `Blocked`): com estoque 0 é justamente quando se repõe | `docs/tech/network.md:186` | architect |
| L-03 | pacote grátis do dia de liberação (DEC-071) é "Tool no mundo sobre a estação nova", mas a ação de pegar (`pick_up_item`) está **sem prompt na onda 1**. Sem ela, ou o pacote é pego por toque nativo do Roblox (fura o limite de hotbar e o "Hands full"), ou não há como pegar | `network.md` §7 (linha "Pacote grátis"); `content-data.md:714`; TASK-025 | architect + task-planner |
| L-04 | Raposa (gorjeta $2, janela −4 s) vale no "pedido do dono" = quem fez "Take Order" **[P]**. Não está dito o que acontece se o dono sair antes do Serve | `content-data.md` §3.10 | game-designer |
| L-05 | FEAT-009 "16 ± 2 clientes no Day 1 solo" pressupõe fila nunca cheia; com Counter 1 e atendimento real, spawns são pulados. O critério precisa dizer se conta **tentativas** de spawn ou clientes nascidos, e "30 min simulados" não define o método | `features.md:461`; TASK-032 | game-designer |
| L-06 | `Customers.PatienceEndsAt` (40 + 5K, replicado na chegada) deixa o client deduzir **K** antes do "Take Order", contra "K oculto" (FEAT-011). Só o tamanho, não os itens; baixo impacto | `network.md` §3.6; `features.md:497` | architect (aceitar ou mandar só depois do "Take Order") |
| L-07 | `architecture.md` §18.4 (linha K) ainda cita `board_add_topping`; `content-data.md` v4 trocou por `topping_add`. A checagem do binding (§18.7 item 3) recusaria a chave antiga | `docs/tech/architecture.md:1030` | architect (TASK-002) |
| L-08 | TASK-032 no board ainda diz "set `Customers` (`Look`, `State`, `Slot`)"; v4 tirou `Look` (aparência em atributos) | `docs/tasks/board.md:73` (descrição da TASK-032) | task-planner |
| L-09 | T017-08 ("classe não muda durante a run fora do modo dev") não é observável na onda 1, que só roda em modo dev. Fica **E** até a onda 2 | TASK-017 | — (registro) |
| L-10 | Não há comando de dev para pular dias/fases (R1). Casos de Day 2–6 custam ~8 min por dia no ritmo real | §0.4 | task-planner |

---

## 10. Resultado (preenchido pela TASK-041)

| Rodada | Data | Build (commit) | Solo PC | Solo Mob | Party 2 | Casos falhos | Tasks de correção |
|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — |
