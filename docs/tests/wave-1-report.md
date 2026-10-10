Status: Rascunho

# Relatório de QA — Onda 1, rodada 1 (estática)

Autor: qa-tester. 2026-10-10. **TASK-041**, primeira passada. Branch `assets/kenney-pipeline`, HEAD `e7ee154`
(+ 1 correção não commitada, §3). Plano de referência: `docs/tests/wave-1.md` v1.

> **Escopo desta rodada:** só verificação **E** (estática) e contratos entre tasks. O Studio **não** esteve em Play
> (rojo serve desligado). Nenhum caso **M** ou **S** do plano foi executado: compilação limpa e contrato coerente
> **não** provam comportamento. Por isso nenhuma task de código passa a `Feito` nesta rodada; a TASK-041 segue aberta
> até o smoke test da §6 e o roteiro da §8 do plano.

---

## 1. Portão estático (G-01 a G-13)

| ID | Resultado | Evidência |
|---|---|---|
| G-01 | **Passou** | `rogen build` ("already up to date"), `modux generate` ("up to date"), `modux check` ("up to date") |
| G-02 | **Passou** | `tools/analyze.ps1 -Detail`: `total: 0 error(s), 0 cycle(s)` (antes e depois da correção C-01) |
| G-03 | **Falhou (B-01)** | no HEAD, regenerar **não** dá o mesmo arquivo: `src/Modux/server/Modules.luau`, `Manifest/init.luau` (server e client), `src/Modux/client/Modules.luau` e `default.project.json` commitados estão velhos (faltam 9 Services e `src/Item/shared`). A árvore de trabalho já está regenerada; falta commitar |
| G-04 | Passou com ressalva (B-05) | desvios de dono benignos, ver §4 |
| G-05 | **Passou** | todo `.luau` novo da onda começa com `--!strict` (os 4 sem cabeçalho são do template: `Counter.story`, `Interface.storybook`, `Libs/Signal`, `Shared/Types/Occlude`) |
| G-06 | **Passou** | `onServer`/`onClient` só em `InteractionService`, `ClassService`, `NetService` e Controllers, todos dentro de `OnInit` |
| G-07 | **Passou** | nenhum `keyBy`, nenhum `Lync.all`; todo packet s→c vai a `NetService.Audience` ou `fireClient(player)` com `IsRunning()` |
| G-08 | **Passou** | nenhum Charm em `*/client/`, nenhum Vide em `*/server/`; Lync/Vide/Charm vêm de `ReplicatedStorage.Packages` |
| G-09 | **Passou** | `rg InsertService src` vazio |
| G-10 | **Passou** | payloads c→s: `Interact {Id, Action}`, `ClassAction {Action, Class}`, `Ready {}`. Preço, quantidade, vaga, `Toppings` e nível saem sempre do servidor |
| G-11 | **Passou** | `src/Shared/Content` não requer Lync, Vide nem `self.Libs` |
| G-12 | Passou com ressalva (B-04) | chaves extras `Stn` (Kitchen) e `Fp` (Item) fora do `data.md` §3.3 |
| G-13 | **Pendente** | boot no Studio sem erro de `Lync.start()` (TASK-004) só em Play |

---

## 2. Revisão cruzada dos contratos

### 2.1 Net (`src/Libs/Net/init.luau`) × escritores × leitores (`network.md` §3–§4)

| Entrada | Escreve (código) | Lê (código) | Bate com `network.md`? |
|---|---|---|---|
| `Shift` (set, id 1) | `RoundService` (effect, `StartRun`) | `RoundController` (+ `Vehicle` p/ `MarketController`) | sim |
| `RunState` (set, id 1) | `RunStateService` (effect) | — (nenhum Controller lê na onda 1) | sim (leitor previsto só na onda 2) |
| `Economy` (set, id 1) | `EconomyService` (effect) | `EconomyController`, `MarketController` | sim |
| `Stock` (set, 9 registros, id = `IndexOf`) | `KitchenService` (add no `OnStart` + effect) | `KitchenController`, `MarketController`, `PromptController` (`Rules`) | sim; regra L-02 (Restock some com `Amount ≥ Capacity`, não com 0) aplicada em `Rules.luau:119-131` |
| `Stations` (set, id = `StationId×100+Slot`) | `KitchenService:Publish` a partir de `Station.Records` (Grill/Rail/Board) | `KitchenController` (Grill/Rail/Board via `Slots.Reader`), `PromptController` (Collect só `Ready`) | sim (rail `Slot 0`, board 2 registros) |
| `Customers` (set, id = `NpcId`) | `CustomerService` (`add`/`update`/`remove`) | `CustomerController`, `PromptController` | sim; T41 respeitada (`PatienceEndsAt = 0` até "Take Order", mesma escrita de `Order` + `Waiting` em `CustomerService:TakeOrder`) |
| `Upgrades` (set, 5 registros) | `UpgradeService` (effect) | `MarketController` | sim; `network.md` cita um `UpgradeController` que não existe (peça é visibilidade no servidor, T38) → B-04 |
| `Interact` | `PromptController` | `InteractionService` (único responder) | sim |
| `Notice` | `RunStateService:Notify` (Item, Kitchen, Economy, Upgrade, Market) e `ClassService:Notify` (direto) | `HudController` (toast), `ClassController` (limpa pendente) | sim; toda chave usada existe em `Content.Notices` |
| `Sale` | `CustomerService:Settle` | `EconomyController` ("+$N"), `CustomerController` (reação) | sim |
| `ShiftReport` | `EconomyService:Deposit` | `HudController` | sim (campos 1:1) |
| `Profile` / `ClassAction` | `ProfileService` / `ClassController` | `ProfileController` / `ClassService` | sim (corrigido C-01: `Select` travado agora responde `class_locked`) |

### 2.2 Ações: `Content.Actions` × `RegisterAction` × `Rules.luau`

As 14 ações com `Wave = 1` têm **exatamente um** dono registrado:

| Ação | Dono (registro) | Quando registra | Âncora no binding (`bind_map01.luau`) |
|---|---|---|---|
| `open_sign` | `RoundService` | `OnStart` (750 > 730, por isso não no `OnInit`) | `OPEN.Prompt_Open` |
| `grill_place`, `grill_collect` | `KitchenService` (módulo `Grill`) | `OnInit` (650) | `CART-S.Prompt_Take`; `CART-G.Att_Slot1..4` (+`Slot`) |
| `bun_cut` | `KitchenService` (`BunCrate`) | `OnInit` | `CART-B.Prompt_Take` |
| `board_add_sausage` | `KitchenService` (`Board`) | `OnInit` | `CART-T.Prompt_Board`; vagas `Att_Bun1/2` (+`Slot`) |
| `topping_add`, `discard` | `KitchenService` (`Toppings`, `Trash`) | `OnInit` | `CART-K.Prompt_Use_<Suf>` (+`Ingredient`); `BIN-C.Prompt_Discard` |
| `restock` | `KitchenService` (núcleo) | `OnInit` | `CART-S/B.Prompt_Restock`; `CART-K.Prompt_Restock_<Suf>` (+`Ingredient`) |
| `take_order`, `serve`, `refuse` | `CustomerService` | `OnInit` (590) | runtime: `Prompt_Customer`/`Prompt_Refuse` no HRP (Pool do `NpcService`) |
| `buy_package`, `bench_buy_upgrade` | `MarketService` | `OnInit` (615) | `MKT-SHELVES.BUY-*` (+`Package`); `GEAR_WALL.Prompt_Buy_B1..B5` (+`BenchSlot`) |
| `pick_up_item` | `ItemService` (`Pickup`) | `OnInit` (720) | runtime: `FreePack_*.Prompt_Take` |

`bench_buy_item` (S1, onda 4) fica sem registro → `PromptEnabled = false` pelo padrão do `InteractionService:Track`
e `MarketService:Refresh`. `RegisterAction` dá `error` em chave fora do `Content` ou repetida: contrato fechado em
runtime. `Rules.luau` só cita chaves existentes (`topping_add`, `restock`, `grill_collect`, `take_order`, `serve`).

### 2.3 Prioridades e ordem de `OnInit` (Loader: ordem decrescente de `Priority`, sem ordenação por `Require`)

Servidor: Net 1000 → Place 950 → Player 900 → Profile 800 → RunState 760 → Round 750 → Economy 740 →
**Interaction 730** → Item 720 → Character 715 → Vital 700 → Class 690 → Kitchen 650 → Upgrade 630 → Market 615 →
Npc 610 → Customer 590 → Dev 100.

- Todo `RegisterAction` em `OnInit` vem de prioridade < 730 (Item, Kitchen, Market, Customer). Round (750) registra no
  `OnStart`, que roda antes do `OnStart` do Interaction (scan das âncoras), então o `PromptEnabled` padrão já vê o
  handler. **OK.**
- Sinais usados em `OnInit` são criados no `Setup` de quem tem prioridade maior: `Round.ShiftStarted/ShiftEnded/
  PhaseChanged` (750) ← Economy, Item, Kitchen, Npc, Customer; `RunState.MemberJoined` (760) ← Character;
  `Npc.Despawned` (610) ← Customer (590). `UpgradeService.Changed` (630) é ligado pelo Kitchen (650) no `OnStart`.
  **OK.**
- Nenhum `OnInit` chama método de dependência de prioridade menor (Item→Class, Character→Class, Kitchen→Upgrade só
  em closures/`OnStart`). **OK.**
- Atenção: `Loader.invoke` faz `pcall` de cada `OnInit` e só dá `warn`. Um erro de `RegisterAction` derruba o resto
  daquele `OnInit` em silêncio → no Play, olhar o Output do servidor por `[Modux] OnInit of ... errored`.

Client: Net 1000 → Place 950 → Input 900 → Profile/Round/Vital 800 → Economy 790 → Camera 690 → Kitchen/Market/Rig
680 → Customer 670 → Prompt 620 → Opal 600 → Hud 500 → Class 450. Todo `Require` aponta para prioridade maior. **OK.**

### 2.4 Atributos do binding × leitores

| Atributo / tag | Escrito por | Lido por | OK? |
|---|---|---|---|
| `Vehicle` (tag + attr `cart`) | binding | Kitchen (`VehicleOf`), Upgrade/Pieces, Item/Pickup, EconomyController | sim |
| `Station` + `StationKind` (+`Ingredient` em S/B) | binding | KitchenService, KitchenController, Pickup, Prompt (`Owner`) | sim (7 kinds = `Required.Stations`) |
| `PromptAction` / `Slot` / `Ingredient` / `Package` / `BenchSlot` | binding | Interaction, Kitchen, Market, Prompt/Rules, MarketController | sim |
| `StationId`, `EntityId`, `PromptEnabled`, `PromptText` | servidor (runtime) | Prompt, KitchenController | sim |
| `MapPoint`/`NpcNode` (`PointId`, `NodeId`, `Links`) | binding | `MapIndex` (Character PS-n, Npc, Customer, Opal OP-1) | sim (pontos = `Required.Points`) |
| `DRAWER.Value_Anchor` | binding | EconomyController | sim |
| `UpgradePiece` (+`Upgrade`/`Level`) | **ninguém** (`check_map01` lista como `PENDING_TAGS`) | UpgradeService/Pieces | **não** → B-02 |
| `Price_Anchor_<Slot>` | asset (pode faltar; binding só avisa) | MarketController (fallback acima da âncora) | risco visual, Play |

### 2.5 Snapshot (`RegisterSnapshot`) × `data.md` §3.3

| Chave | Dono | `data.md` |
|---|---|---|
| `Run`, `M` | RunStateService | sim |
| `Sh` | RoundService | sim |
| `Cash` | EconomyService | sim |
| `Stk` | KitchenService | sim |
| `Upg` | UpgradeService | sim (2 veículos) |
| `Stn` | KitchenService | **não** (módulos devolvem `nil`, vira `{}`) → B-04 |
| `Fp` | ItemService/Pickup | **não** (Provisório da TASK-046) → B-04 |
| `Veh`, `Bn` | — | onda 2 (VehicleService, oferta S1); esperado faltar |

### 2.6 Fluxo completo de um hot dog (leitura de código, servidor)

| Passo | Caminho | Achado |
|---|---|---|
| Comprar pacote | `buy_package` → `MarketService:ValidatePackage` (run iniciada, membro ativo, não `Blocked`, intervalo) → `BuyPackage`: `ItemService:CanGive` → `EconomyService:Spend(price, player)` → `ItemService:Give(Count = Amount)`, sem yield entre cobrar e entregar | ok |
| Restock | `restock` → `KitchenService:Evaluate` (`Requires.Held = Package`) → `CheckRestock` (pacote do ingrediente da estação/âncora, não `Blocked`, `Amount < Capacity`) → `Restock` move `min(sobra, cap − atual)`, `SetCount` (vazio some) | ok |
| Grill | `grill_place` (âncora em `sausage_stock`) → `Grill.place`: vaga livre de menor `Slot` + `TakeStock(sausage, 1)` → registro `Working`, `Duration = GrillTime × Modifier` | ok |
| Collect | `Grill.Tick` 10 Hz `Working → Ready`; `grill_collect` (`Att_Slot<n>`) → `Rail.Push` → vaga `Empty` | ok |
| Slice bun | `bun_cut` → `Board.Free` + `TakeStock(bun, 1)` → `Board.Place` (`Working` 1,5 s) → `Board.Tick` → `Ready` | ok |
| Add sausage | `board_add_sausage` → pão `Ready` mais antigo + `Rail.Count ≥ 1` → `Give(hot_dog)` **antes** de `Rail.Pop` (recusa não mexe em nada) | ok |
| Add topping | `topping_add` (`Prompt_Use_<Suf>`, `Ingredient`) → `canAdd` (HotDog na mão, sem repetir, < 3, estoque ≥ 1) → `TakeStock` (recusa `Blocked`) → `ItemService:AddTopping` (+`HotDogVisual.refresh`) | ok |
| Take order | cliente em Q1 (`Fronted` liga prompts) → `CanAct(Ordering)` exige loja Open/Closing → `TakeOrder`: ticket guarda taker, janela e gorjeta; uma escrita `Waiting` + `Order` + `PatienceEndsAt`; âncora vira `serve` | ok |
| Serve | `CanAct(Waiting)` + `TakenAt > 0` + HotDog na mão → `Orders.Evaluate` → `AddToDrawer(Sale)` (+`Tip` → `Perfect`) → `CountResult` + `Sale` ao grupo → `Leave` | ok; Errado = $0, HotDog fica |
| Gaveta | `EconomyService.Drawer` (só Open/Closing) → set `Economy` → `EconomyController` (valor no `Value_Anchor` + "+$N") | ok |
| Resumo | Closing termina com balcão vazio (`SetCounterProbe`) ou 30 s → Summary → `ShiftEnded` → `Deposit` (nota, bônus, `Cash += gaveta + bônus`) → `ShiftReport` → `HudController` → Summary acaba → Day+1 → `ShiftStarted` (unlock + pacote grátis) → `Capture` | ok |

Nenhuma quebra de contrato no fluxo. Riscos que só o Play mostra estão em §5.

---

## 3. Bugs corrigidos nesta rodada (correção mínima, não commitada)

| ID | Arquivo | Problema | Correção |
|---|---|---|---|
| C-01 | `src/Class/server/ClassService/init.luau:176-186` (`ClassService:Select`) | Com a classe já travada na run (spawn), `Select` voltava **em silêncio**. Board TASK-017 ("senão `class_locked`") e `network.md` §4.6 mandam responder `class_locked`; sem resposta, a tela "Crew" fica em "..." até o timeout de 3 s, sem toast | chave validada antes e `self:Notify(player, "class_locked", IndexOf[key])` quando travada (5 linhas). `modux check` e analyze: 0 erro depois |

---

## 4. Divergências entre tasks e documentos

| # | Divergência | Onde | Dono | Severidade |
|---|---|---|---|---|
| D-01 | `ShiftEnded(info, report)` no `architecture.md` §4.1 (linha 303) × código `ShiftEnded(info)` (Round) + `EconomyService.Reported(info, report)` | `architecture.md:303`; `RoundService.luau:65`; `EconomyService/init.luau:70` | architect (alinhar doc) | Baixa |
| D-02 | "Maxed" (FEAT-015, `MarketController/Labels.luau:26`) × "MAX" (`ui-text.md:37`, AST-049) | — | narrative-writer | Baixa |
| D-03 | Texto da bancada: `Actions` "Buy {upgrade} — ${price}" × `ui-text.md:37` "Buy {upgrade} ({price})" | `Content/Actions.luau:50` | narrative-writer | Baixa |
| D-04 | Notices faltando: recusas silenciosas sem toast (grelha cheia/sem estoque, tábua cheia, 3 coberturas, cobertura repetida, Restock com estoque cheio, prateleira `Blocked`, bancada `busy`/`Maxed`, Take Order fora de Open/Closing). Hoje o client esconde o prompt; forjado é descartado sem aviso | `Content/Notices.luau` | narrative-writer + game-designer | Baixa (UX) |
| D-05 | `data.md` §3.3 sem `Stn` e `Fp` | `KitchenService/init.luau:858`, `ItemService/init.luau:454` | architect | Baixa |
| D-06 | `network.md` §11 (linha 647) diz `pick_up_item` "sem prompt ativo"; §7 (linha 543) e o código têm prompt "Take" ativo | `network.md:647` | architect | Baixa |
| D-07 | `network.md` §3.7 cita `UpgradeController` como leitor de `Upgrades`; não existe (peça por visibilidade no servidor, T38) | `network.md` §3.7 | architect | Baixa |
| D-08 | Plano: T011-07 e X-09 esperam `pick_up_item` "sem `RegisterAction`"; agora é registrada (TASK-046). Forjada em âncora que não é pacote grátis continua descartada (`target`) | `tests/wave-1.md:179`, `:521` | qa-tester (próxima versão do plano) | Baixa |
| D-09 | Board TASK-028, Provisório (1) ainda descreve o fallback `Consume + Give`; o código usa só `ctx.AddTopping` (a 1 linha pedida entrou no `BuildContext`) | `board.md` linha TASK-028 | task-planner | Baixa |
| D-10 | Item `pack_coffee` = "Coffee Pack" (Tool) × `Packages.pack_coffee` = "Coffee" (prateleira) | `Content/Items.luau`, `Packages.luau` | game-designer | Info (onda 2) |

---

## 5. Bugs abertos

| ID | Severidade | Descrição | Evidência | Sugestão |
|---|---|---|---|---|
| B-01 | **Média** | Arquivos gerados no HEAD estão velhos: `Modules.luau` do servidor não lista Character, Customer, Dev, Economy, Item, Kitchen, Market, Npc, Upgrade; `default.project.json` não mapeia `src/Item/shared` (`HotDogVisual`). Quem fizer checkout e der `rojo serve` sem `modux generate` sobe um jogo sem gameplay. A árvore de trabalho já está certa | `git diff --stat` (5 arquivos gerados modificados antes desta rodada) | commitar os gerados junto com o fechamento da onda (não foi feito aqui: sem commit) |
| B-02 | Baixa | Nenhuma `UpgradePiece` no binding: comprar Grill/Cooler/Counter não troca peça no carrinho (roteiro §8 passo 12 "ver a peça" não passa). O Grill 2 aparece pela 3ª vaga | `check_map01.luau:44` (`PENDING_TAGS`) | level-designer/modeler quando as peças existirem |
| B-03 | Baixa | `Prompt_Refuse` a 1,5 stud de `Prompt_Customer` (regra de vizinhos ≥ 2,5); escolha de alvo pode alternar entre "Take Order" e "Refuse" | `Npc/server/NpcService/Pool.luau:43-44` (Provisório) | conferir T014-02 no Play |
| B-04 | Baixa | Divergências de documento D-01, D-05 a D-09 | §4 | donos indicados |
| B-05 | Baixa | Desvios de dono de arquivo (benignos, combinados em nota): TASK-028 editou `KitchenService/init.luau` (+3, `Context.AddTopping`), `StationApi.luau` e `PromptController/Rules.luau`; TASK-037 editou `Round/client/RoundController.luau` (source `Vehicle`) | `git show --stat 0ca32d0`, `c526a3d` | registrar no board |
| B-06 | Info | Na onda 1 (modo dev) a classe trava no spawn, que acontece ao entrar. Trocar de animal pela tela "Crew" só vale na próxima sessão (perfil salvo). T018-01 com Coelho exige: comprar + selecionar, parar e dar Play de novo (com acesso a API do Studio ligado, senão o ProfileStore usa mock e perde) | `ClassService:GetClass` + `CharacterService:Spawn` | anotar no roteiro; sem mudança de código |

---

## 6. Resultado por task

Legenda: **E ok** = revisão estática e contratos sem defeito; **M pendente** = casos manuais do plano ainda não
rodados. Nenhuma task falhou no estático (exceto o portão G-03, que é do repositório, B-01).

| Task | Estático | Evidência principal | Pendente (Play) |
|---|---|---|---|
| TASK-004 Net + Template | E ok | 7 sets + `Ready`/`Profile`/`Interact`/`Notice`/`Sale`/`ShiftReport`/`ClassAction` + 2 legados; enums de `Content` | G-13 boot sem erro de `Lync.start()`; T004-04/07 |
| TASK-006 / 007 Kits | n/a (Studio) | `CrewLooks` gerado; `ItemService:CheckKit` avisa ferramenta faltando | olhar `KitDemo`/`ItemsDemo`, salvar place |
| TASK-008 / 009 Conteúdo | E ok | números conferidos (Shift 60/360/30/15, Flow, Grill 2/3/4 e 12/10/8, classes) | — |
| TASK-010 Place + RunState | E ok | roster, `Notify` validado contra `Content.Notices`, snapshots | T010-01..05 |
| TASK-011 Interaction | E ok | único responder; taxa → alvo → estado → raio → `PromptEnabled` → `Validate`; fila por id | T011-02..09, §3 |
| TASK-012 Round | E ok | ciclo, `open_sign` no `OnStart`, sonda de balcão | T012-01..09 |
| TASK-014 Prompt | E ok | `Rules` alinhado a L-02 e ao limite de 3 coberturas | T014-01..08 (mobile) |
| TASK-015 RoundController | E ok | lê `Shift` id 1 | T015-01..03 |
| TASK-016 CrewRig | E ok | usado por Character, Npc, Opal, Preview | T016-01..03 |
| TASK-017 Class | E ok após **C-01** | `Select` travado → `class_locked` | T017-01..12 |
| TASK-018 Character | E ok | spawn por `StarterCharacter`, grupo `Players`, velocidade por pacotes | T018-01..07 (ver B-06) |
| TASK-019 Camera | E ok | — | T019-01..03 |
| TASK-020 Crew screen | E ok | limpa pendente em `class_*` (agora inclui o caso travado) | T020-01..05 |
| TASK-021 Economy | E ok | `Spend` atômico, gaveta só Open/Closing, nota/bônus em `Ledger` | T021-01..10 |
| TASK-022 Item | E ok | limites 4/categoria/pacote por classe, `Holding` = `Requires.Held` | T022-01..08 |
| TASK-023 HotDogVisual | E ok | refresh no servidor a cada `Toppings` | T023-01..04 |
| TASK-024 EconomyController | E ok | `Value_Anchor` no binding | T024-01..04 |
| TASK-025 Kitchen núcleo | E ok | estoque, Restock, estações por módulo, trava por estação | T025-01..10 |
| TASK-026 Grelha + trilho | E ok | vaga e estoque juntos; `Rail` FIFO | T026 |
| TASK-027 Pão + tábua | E ok | `Give` antes de `Pop` | T027-01..02 |
| TASK-028 Complementos + lixeira | E ok | `TakeStock` recusa `Blocked` de forma atômica | T028 (B-05 escopo) |
| TASK-029 / 030 Visuais cozinha | E ok | ids `StationId×100+Slot` iguais ao servidor | T029/T030 (orientação da comida Provisória) |
| TASK-031 Npc | E ok | pool ≤ 12, âncoras com `PromptEnabled = false` antes da tag | T031-01..06 |
| TASK-032 Customer | E ok | fila Q1–Q5 por `QueueSize` ao vivo, `SpawnAttempted` sempre | T032-01..06 |
| TASK-033 Pedido/pagamento | E ok | T41 numa escrita; DEC-072 em `Orders.luau` | T033 (inclui 1.000 sorteios S) |
| TASK-034 CustomerController | E ok | balão só em `Waiting`, anel só com `PatienceEndsAt > 0` | T034 |
| TASK-035 Upgrade | E ok | por veículo, guarda `busy`, snapshot `Upg` | T035 (B-02 peça) |
| TASK-036 / 037 Mart | E ok | `CanGive` antes de cobrar; etiquetas por `Stock.Blocked` | T036-01..12, T037 (D-02) |
| TASK-038 Opal | E ok | local, sem rede | T038-01..05 |
| TASK-039 HUD | E ok | toasts por `Content.Notices`, resumo 1:1 com `ShiftReport` | T039-01..07 |
| TASK-042..045 Dev | E ok | comandos achados por `ModuxModules` (depende de B-01 no checkout limpo) | `/dev day`, `skip`, `gems`, `cash`, `interactlog`, `spawns` |
| TASK-046 Pacote grátis | E ok | `Fp`, "Take", `Give` decide `hands_full`/`package_limit` | T025-09, aceite da TASK-046 |

---

## 7. Smoke test em Play (2 jogadores) — ordem de maior cobertura

Preparação: `rogen build` → `modux generate` → `rojo serve`; place Run com binding (TASK-005) e kits (TASK-006/007)
salvos; Game Settings → Security → **Enable Studio Access to API Services** ligado (perfil persiste). Test →
**Clients and Servers**, 2 clients (P1 no PC; P2 no emulador iPhone SE se der). Deixar o Output do **servidor** visível.

1. **Boot (G-13, T004-03):** Output do servidor sem `[Modux] OnInit/OnStart ... errored`, sem erro de schema do Lync,
   sem `MapIndex.Validate` reclamando, sem `[ItemService] Assets.Items.Tools is missing`. `/dev help` lista
   day/skip/gems/cash/interactlog/spawns/upgrade.
2. **Spawn (T018-01/02/05/06, T019):** os dois nascem como Cachorro em PS-1/PS-2, 1ª pessoa, atravessam um ao
   outro. P2 abre a tela Crew (`C`), tenta "Select" num animal → toast "{class} is locked" (C-01).
3. **Prep (T012-01/02, T015, T025-07/08, T028-04, T036-02):** relógio 7:00 AM nas duas janelas; estoque 12/12, 30/30;
   tigelas de queijo/bacon com tampa; no Mart, queijo "Out of stock" + "Day 2". P2 toca "Open Shop" → Open, 8:00 AM.
4. **Montagem (T026, T027-01, T022-06, T028-06, T023):** P1 "Grill" ×2 → barras 12 s; terceira tentativa sem prompt.
   "Collect" ×2 → trilho 2. "Slice Bun" ×2 → pães cortados em 1,5 s. **P1 e P2 tocam "Add Sausage" juntos** (T027-02,
   T011-05) → 2 hot dogs (um cada) ou 1 se só havia 1 pão/salsicha. P1 "Add Ketchup" → visual na mão; "Add Ketchup"
   de novo some.
5. **Cliente (T031, T032, T033-06, T034-01):** cliente chega pela calçada a Q5 → Q1; "Take Order" → balão e anel
   nas duas janelas. Servir certo dentro da janela → "+$N", gaveta sobe igual nos dois, `Cash` igual (T021-02,
   T024-01/02). Próximo cliente: servir errado (T033-12) → $0, HotDog fica; jogar na lixeira (T028-07). Outro:
   "Refuse" (hold 1 s, T014-07).
6. **Limites (T022-01/02, $-01):** P2 compra 2 pacotes de salsicha no Mart; 3º → "You can carry 2 packs"; P1 enche a
   hotbar (4) e toca "Add Sausage" → "Hands full", trilho e pão intactos.
7. **Restock (T025-01, T022-05):** com estoque de salsicha < 12, P2 "Restock" → transfere só o que cabe, pacote mantém
   o resto (`Count`); com estoque cheio o prompt some.
8. **Fim do dia (T012-04/05, T021-03/08, T039-05/06):** `/dev skip` até Closing → placa CLOSED, sem spawn; balcão
   vazio → Summary imediato; os dois recebem o resumo (nota, bônus, depositado); `Cash` sobe pelo depósito.
   `/dev spawns` (T045): X = Y + Z + W.
9. **Bancada (T035-01/02, T036, T021-07):** `/dev cash 60`; P1 e P2 seguram "Buy Grill 2 — $60" juntos → só uma
   compra, `Cash = 0`, o outro recebe "Not enough cash"; toast "Grill upgraded!" nos dois; 3ª vaga na grelha (peça:
   B-02, esperado não mudar).
10. **Day 2 (T025-09/10, T028-05, T037-02, TASK-046):** Summary acaba → Day 2: toast "New: Cheese!", tampa do queijo
    some, pacote grátis sobre a tigela; P1 com hotbar cheia toca "Take" → toast e pacote fica; P2 pega → `Count` 6,
    Restock no queijo. Bacon segue "Out of stock".
11. **Forjados (§3 do plano, R4):** Command Bar do **client** de P2: `Interact` em âncora longe (X-01), `serve` sem
    HotDog (X-04), `open_sign` fora da Prep (X-08), 30 pacotes num frame (X-03) → `/dev interactlog` mostra `range`,
    `state`, `state`, `rate xN`; nenhum estado muda.
12. **Saída (Q-01, Q-06):** P2 sai segurando HotDog → sem erro no Output; volta no Open → mesma classe, sets certos.
13. **Fechamento:** `modux check` e `tools/analyze.ps1` de novo; preencher §10 do `wave-1.md`.

Falha em qualquer passo vira linha nova no board (`Falhou QA` na task dona + task de correção).
