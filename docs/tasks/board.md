Status: Rascunho

# Board de tarefas (TASK-###)

Dono do arquivo: task-planner. Versão 1.1, 2026-10-10. Primeira onda depois da **bandeira verde (DEC-193)**.
v1.1: retorno da TASK-040 (`docs/tests/wave-1.md` §0.4 R1–R5 e §9 L-01–L-10) → TASK-042 a TASK-046 e notas
abaixo da tabela.

Base: `CLAUDE.md`, `README.md` (Modux V3), `docs/PIPELINE.md`, `docs/tech/architecture.md`, `network.md`, `data.md`,
`content-data.md` (v3.1), `docs/design/*.md`, `docs/levels/MAP-01.md`, `docs/art/asset-list.md`, `decisions.md`
(DEC-001 a DEC-193), `tools/assetplace/build_crew.luau`.

> **Base Provisória (DEC-193).** Quase todas as specs de design e de tech estão em **Rascunho**. Pela DEC-193 elas valem
> como **base Provisória** para construir, abaixo das DEC e dos documentos Aprovados. A coluna **Provisória** lista o que
> cada task assume sem decisão do usuário (Q aberta, técnica T# sem aprovação em `Q-130`, ou entrega não aprovada).
> Se a decisão vier diferente, abre-se uma task de ajuste.

---

## Regras do board

- **Status:** `Pronta` (todas as dependências feitas) · `Bloqueada` (falta dependência) · `Em andamento` (dono marca
  antes de começar) · `Em QA` · `Feito` · `Falhou QA` (gera task de correção).
- **Um dono por arquivo.** Duas tasks que tocam o mesmo arquivo nunca ficam em paralelo. Pontos de conflito:
  - `src/Libs/Net/init.luau` e `src/Profile/server/ProfileService/Template.luau`: **só a TASK-004** nesta onda.
  - `src/Shared/Content/init.luau`: **só a TASK-003**. As demais tasks de conteúdo editam só o próprio arquivo de tabela.
  - `src/Kitchen/server/KitchenService/init.luau`: só a TASK-025. Estações novas entram como arquivos em
    `KitchenService/Stations/` (descobertos pelo init), sem editar o init.
  - Arquivos gerados (`src/Modux/*/Manifest/init.luau`, `*/Modules.luau`, `shared/Libs.luau`, `src/ModuxTypes/**`,
    `default.project.json`): **nunca à mão**. Conflito neles no merge se resolve rodando `rogen build` → `modux generate`.
- Coder trabalha em worktree própria por task (`PIPELINE.md`). Entrega exige `modux check` e `tools/analyze.ps1` com
  **zero erro**; task que toca `Net/init.luau` exige também boot no Studio sem erro de `Lync.start()`.
- Backend e frontend da mesma feature correm em paralelo **depois** que o contrato está em `docs/tech/network.md`
  (TASK-001) e o binding do mapa em `docs/tech/architecture.md` (TASK-002).
- Onda 1 roda no **place Run em modo de desenvolvimento** (`architecture.md` §1: sem `PrivateServerId`, roster = quem
  entrar). Lobby, party e teleporte ficam para a onda 2.

---

## Tabela de tasks — Onda 1 (núcleo jogável de dia, carrinho)

| ID | Título | Dono | Depende de | Arquivos / pastas | Spec | Provisória | Status |
|---|---|---|---|---|---|---|---|
| TASK-001 | Contratos de rede, conteúdo e dados da onda 1 (docs) | architect | — | `docs/tech/network.md`, `content-data.md`, `data.md` | DEC-140 a DEC-193; FEAT-003, 005–012, 014, 015, 028, 032 | Q-130 (T6, T13, T14) | Feito |
| TASK-002 | Contrato de binding do MAP-01, kits de asset e layout de módulos (docs) | architect | — | `docs/tech/architecture.md` (seção nova) | MAP-01 §5, §7; DEC-146, 151, 156, 157, 190 | Q-153 | Feito (`architecture.md` §18, v3.2; T32–T39 em `Q-130`, T35 retirada pela T40) |
| TASK-003 | `Content`: scaffold + tabelas que geram enum + stubs tipados | architect | TASK-001 | `src/Shared/Content/` (Table, Validate, init, Ingredients, Packages, Items, Stations, Actions, Notices + stubs) | `content-data.md` §1–§3; DEC-071, 174, 180, 186, 190 | Q-062 | Feito (`src/Shared/Content/`, 22 arquivos com `Stats`/`Outfits`/`Moods`; `content-data.md` §1.5, v4.1; Validate ~0,2 ms) |
| TASK-004 | Net v1 do núcleo + Template do perfil | architect | TASK-003 | `src/Libs/Net/init.luau`, `src/Profile/server/ProfileService/Template.luau`, `.../ProfileService/init.luau`, `src/Profile/client/ProfileController.luau` | `network.md` (pós TASK-001); `data.md` §1.1; DEC-186 | Q-130 (T13, T14) | Em QA (Net v1 com 14 entradas da onda 1 + `Vitals`/`Round` legados; Template v1 + `Migrations.luau`; `ProfileService` ganha `RequestSave`, `OwnedClasses`, `SelectedClass`, `Migrate`; erro de tipo da linha 23 corrigido; analyze 0 erro; **falta boot no Studio** sem erro de `Lync.start()`) |
| TASK-005 | Binding do MAP-01 no place (tags, atributos, pontos, grafo de NPC) | level-designer | TASK-002 | place (Studio, fora do Rojo); `tools/assetplace/MAP-01_placements.luau` se preciso | MAP-01 §5.1, §5.3, §7.1, §7.4, §9.1; DEC-157, 190 | Q-153; AN-08 fora (DEC-191) | Feito (Studio: Check PASS, 0 erros, 2026-10-10) |
| TASK-006 | Kit de personagem no place + `CrewLooks` | modeler-3d | TASK-002 | `ReplicatedStorage.Assets.Crew`, `ReplicatedStorage.CrewExpressions` (Studio); `src/Crew/shared/CrewLooks.luau` | DEC-145, 151–154, 158–166, 181; `build_crew.luau` | pack Mid entregue sem aprovação (DEC-166); Q-144 h | Em QA (`src/Crew/shared/CrewLooks.luau` gerado por `tools/assetplace/gen_crew_looks.py` (18 espécies, 10 roupas, atlas Mid/Night; pelagem lida da `T_Head_<A>.png`; `EarsUp` falso em Dog, Frog, Monkey, Penguin, Pig, Sheep, Turtle, lido do `REF_Cap` dos `.blend`); `tools/assetplace/build_kits.luau` monta `Assets.Crew` (`Body`, `CivilArms`, `CapEarsUp`, `Hats/ThiefHat`, `Animals/<A>` ×18, `Accessories` vazio) e `CrewExpressions` (10), `KitVersion` 1; `CrewBase` fora do kit (§18.9.1). analyze 0 erro. Studio 2026-10-10: `Kits.run({ baseUrl, demo = true })` = "crew kit v1: 18 species, 10 expressions; 0 problem(s)" (cross-check de Content pulado: rojo serve desligado). **Falta:** olhar `workspace.KitDemo` (captura voltou preta), conferir boné com furos nas 10 espécies novas, `Kits.clearDemo()` e salvar o place) |
| TASK-007 | Kit de itens e comida no place | modeler-3d | TASK-002, TASK-006 (mesma sessão de Studio) | `ReplicatedStorage.Assets.Items` (Studio) | AST-001–011; DEC-137, 141, 142, 174 | Provisórios: pacotes em cor chapada (sem recolor de atlas nem rótulo AST-072; Cheese = carton-small deitado, Sausages = carton deitado); `altered_item` fica para a onda 3 (AST-061 tem 2 variantes); `revive_kit` (AST-051) incluído; `Items.KitVersion` próprio (raiz `KitVersion` segue do `build_kits`); Food com pivô na base (§18.9.5; ficha AST-002 diz centro) | Em QA (Studio 2026-10-10: `Items.run` = "items kit v1: 12 tools, 6 toppings, 4 food; 0 problem(s)"; falta olhar `ItemsDemo`, `Items.clearDemo()` e salvar) — Pronta p/ Studio (`tools/assetplace/build_items.luau`: monta só `Assets.Items` — `Tools/<chave do Content.Items>` ×12 (hot_dog, coffee, 9 `pack_*`, revive_kit; `Grip` = `Att_Hand`, `CanBeDropped` false, `Att_Topping1`/`Att_Serve` no hot_dog), `Toppings/<ingrediente>` ×6 com `TopHeight` medido no Studio e conferido contra o `.blend` (ketchup 0,031, mustard 0,027, cheese 0,026, bacon 0,115, potato_sticks 0,119, cream_cheese 0,068), `Food/` SausageRaw, SausageGrilled, BunClosed, BunOpen; attachments recriados das empties dos `.blend` (o FBX não as traz); idempotente, cache `ServerStorage.__AssetCache`, não toca `Assets.Crew`. `check()`: todo item/cobertura do Content tem peça, ids existem, tamanhos/posições batem com o `.blend`, tris nas fichas (hot dog + 3 coberturas mais pesadas = 864 ≤ 900). `demo = true` → `workspace.ItemsDemo` (Tools, coberturas, 12 empilhamentos com a regra DEC-142, crew segurando cada Tool na pose R6). analyze 0 erro. **Rodar no Command Bar** (repo na 8772): `local H=game:GetService("HttpService") local w=H.HttpEnabled H.HttpEnabled=true local ms=Instance.new("ModuleScript") ms.Source=H:GetAsync("http://127.0.0.1:8772/tools/assetplace/build_items.luau") H.HttpEnabled=w local Items=require(ms) print(Items.run({ baseUrl = "http://127.0.0.1:8772/", demo = true }))`; depois olhar `ItemsDemo`, `Items.clearDemo()` e salvar o place) |
| TASK-008 | Conteúdo: turno, upgrades, veículos, fluxo e pedidos | backend-coder | TASK-003 | `src/Shared/Content/` Shift, RunParams, Upgrades, Vehicles, Flow, Orders | FEAT-003, 009, 010, 011, 015; `upgrades.md`; DEC-045, 048, 072, 184, 185 | Q-062, Q-163 | Em QA |
| TASK-009 | Conteúdo: classes, espécies, tipos de cliente, falas da Opal | backend-coder | TASK-003 | `src/Shared/Content/` Classes, Species, CustomerTypes, OpalLines | DEC-069, 070, 186, 188, 192; `npcs.md`; `characters.md` CHR-003 | Q-165 (jogáveis e porco só passante, onda 2), DEC-192/214 (porco confirmado), nomes `Acc_*` até a TASK-006 | Em QA (Classes: descrições placeholder + origem DEC por efeito; Species: `PlayableKeys` derivado = 6 MVP, porco DEC-214; CustomerTypes: acessórios DEC-188 com nomes `Acc_*` Provisórios, roupa A–H em todos (office_worker saiu de a/c/e/g); OpalLines: 4 pools do CHR-003. Testar: `Validate()` passa; classe com `Stat` fora da lista, classe/tipo com `raccoon` e tipo com `crew` dão erro com tabela e linha. Verificado em lune + `modux check` + `analyze.ps1` 0 erro) |
| TASK-010 | `Place` + `RunState` mínimo (modo dev) + `MapIndex` compartilhado (leitura do mapa por tag/atributo, `architecture.md` §18; pré-requisito da TASK-031) | backend-coder | TASK-004 | `src/Place/server/PlaceService`, `src/Place/client/PlaceController`, `src/Run/server/RunStateService/`, `src/Map/shared/MapIndex` | `architecture.md` §1, §2.3, §7; `data.md` §2.1 | modo dev; snapshot só em memória | Em QA (backend-coder, 2026-10-10). **Arquivos:** `src/Place/server/PlaceService.luau` (950), `src/Place/client/PlaceController.luau` (950), `src/Place/shared/MapIndex/` (`init`, `Graph`, `Required`; caminho do `architecture.md` §18.7/§18.8/§18.11, **não** `src/Map/...` desta coluna → `ReplicatedStorage.shared.Place.MapIndex`), `src/Run/server/RunStateService/` (`init`, `Snapshots`; 760). **O que faz:** `Is(role)`/`IsDev()`; `PlaceRole` ausente = `"Run"` com warn (Provisório); `IsDev` = Run + sem `PrivateServerId` + `RunService:IsStudio()` (Provisório: servidor Run público nunca liga comando de dev). `PlaceService` roda `MapIndex.Validate(MapIndex.Required)` no `OnStart` (itens 1–6 do §18.7; item 7 só na ferramenta, pois lê `MapId`); sem raiz `MapBinding` = warn "TASK-005 pending". `MapIndex`: `WaitReady`, `Point`, `FindPoint`, `Points`, `Node`, `Path` (+ opção `AvoidQueue`, aviso de rota do `check_map01.luau`), `Validate`, `HasBinding`, `Refresh`; `Required` deriva pacotes, toppings, bancada e nº de vagas de `Content`. `RunStateService`: roster de dev (primeiros 4 = `#RunParams.PartyPriceMult`), membro criado no `ProfileService.Loaded` com a classe travada, `Away` ao sair e estado anterior ao voltar, sinais `MemberJoined`/`MemberAway`, `GetMember`/`IsMember`/`IsActive`, set `RunState` por `effect` no `OnStart`, `Notify(player | "all", key, value)` (chave validada; só jogador `Ready`; "all" = `NetService.Audience`), `RegisterSnapshot`/`Capture`/`Restore(mode)`/`LastSnapshot` em memória (tamanho JSON: aviso > 2 KB, erro no Studio > 8 KB), registros próprios `Run` e `M` (`RepeatNight` não restaura `Ch` e põe todos `Active`). **Para a TASK-012:** chamar `FixPriceParty()` no fim do Day 1 e `Capture()` no início de cada turno. **Fora do escopo, registrar:** `ClassService` (TASK-017) ainda usa `isRun/isDev` próprios (sem `IsStudio`) e deve passar a `Require "PlaceService"`; `Member.Class` não acompanha um "Select" feito depois da entrada no modo dev. **Como testar:** Studio, Test → 2 Players; Command Bar do servidor: `local R = require(game.ServerScriptService.server.Run.RunStateService)` → `R.Members()` lista os 2 UserIds (`Class`, `State = "Active"`, `EverJoined`); `R:Notify(game.Players.Player1, "hands_full")` chega só ao Player1 e `R:Notify("all", "upgrade_bought", 1)` aos dois (ouvir `Notice` no client até a HudController existir); `R:FixPriceParty()` → set `RunState.PriceParty = 2`; fechar o Player2 → `State = "Away"`; `R:Capture()` e `R:Restore("RepeatNight")` sem erro. Com `Workspace.PlaceRole = "Lobby"`, nada conecta e o set não é criado. Verificado: `rogen build`, `modux generate`, `modux check` ok; `tools/analyze.ps1` 0 erro; A* do `Graph` testado em lune (vizinhança simétrica, `AvoidQueue`, link desconhecido). **Falta:** boot no Studio e `Validate` contra o binding real (depende da TASK-005) |
| TASK-011 | `InteractionService` (único responder de `Interact`) | backend-coder | TASK-002, TASK-004 | `src/Interaction/server/InteractionService/` | `architecture.md` §4, T6; FEAT-005; DEC-066, 174 | Q-130 (T6); membro ativo = personagem vivo (sem `RunStateService` ainda); `BUILD_WAVE = 1` constante no Service (Content não tem campo de onda do build: pedido ao architect) | Em QA (`InteractionService/init.luau` + `Registry.luau`, prioridade 730, Require Player/Net. API: `RegisterAction(key, {Validate, Run})`, `Get`, `IdOf`, `Position`, `SetPrompt(anchor, enabled, text?)`, `SetPromptHold`, `IsActive`, sinal `Rejected(player, id, action, reason)`. Checagem em ordem: taxa (balde 8/s) → `target` (id, `Workspace`, `PromptAction` da âncora = ação, handler registrado, `Actions.Wave ≤ 1`) → `state` (personagem vivo) → `range` (`Radius` + 2) → `state` (`PromptEnabled = false` ou `Validate` falso); fila por `EntityId` (mesmo frame ou `Run` que cede). Ids no `OnStart` por `GetFullName`, runtime por tag + `AncestryChanged`, reuso só após 10 s; `PromptEnabled` padrão = ação ativa, se ausente. Testar: T011-01..09 de `tests/wave-1.md` (conectar em `Rejected` para ver o motivo); analyze 0 erro nos arquivos da task, `modux check` ok. Ajuste quando a TASK-010 entrar: membro via `RunStateService`) |
| TASK-012 | `RoundService`: turno de dia, relógio, placa OPEN/CLOSED | backend-coder | TASK-004, TASK-008, TASK-010, TASK-011 | `src/Round/server/RoundService.luau` | FEAT-002, FEAT-003; DEC-048, 085 | noite fora da onda (Day N → Day N+1); **Provisório**: run (Day 1 Prep) só começa quando entra o 1º membro; sem `CustomerService`, Closing termina no 1º tick (balcão vazio); `ShiftEnded(info)` sem `report` (o relatório é da TASK-021); `DevSetDay(n>1)` chama `FixPriceParty` | Em QA (backend-coder, 2026-10-10). Reescreve o exemplo: prio 750, Require Place/Net/RunState/Interaction, só Run. Atoms `Day`, `Phase`, `PhaseStartedAt`; set `Shift` (id 1) por `effect` criado no início da run (campos fixos: `Night 0`, `IsNight false`, `Attempt 0`, `Vehicle = RunParams.StartVehicle`, `Chances` do `RunStateService`, `WipeEndsAt 0`); durações/relógio só de `Content.Shift`. Ciclo Prep → Open → Closing → Summary → Prep do Day N+1, tick 10 Hz, fim por prazo começa a fase seguinte no prazo exato (sem drift; relógio não pausa). Fim de turno: entrar no Summary → `ShiftEnded` → `FixPriceParty()` no Day 1; fim do Summary → Day+1 → `ShiftStarted` → `PhaseChanged` → `Capture()`. Sinais `PhaseChanged(phase, day, night)`, `ShiftStarted(info)`, `ShiftEnded(info)` no `Setup`. `open_sign` registrado no `OnStart` (InteractionService 730 cria a tabela no próprio `OnInit`, depois do nosso; o scan dele roda depois): `Validate` = Prep + membro `Active`; `PromptEnabled` das âncoras `open_sign` só na Prep. Closing: `SetCounterProbe(fn)` para a TASK-032. Snapshot `Sh` {D,N,Ni,A}; restore volta à Prep do dia capturado sem nova captura. API: `GetPhase`, `GetDay`, `IsNight`, `IsStarted`, `Info`, `Minutes`, `DevSkipPhase()` (mesmo caminho do prazo), `DevSetDay(n)` (`error` sem `IsDev()`). Packet `Round` legado não é mais usado. **Testar:** T012-01..09 + T015-01..03 + T010-04; Command Bar: `local R = require(game.ServerScriptService.server.Round.RoundService)` → `R:DevSkipPhase()` avança fase, `R:DevSetDay(5)` vai à Prep do Day 5. Verificado: rogen/generate/check ok, analyze 0 erro. **Falta:** boot no Studio |
| TASK-013 | Interface: `ProgressBar`, `PromptBillboard`, `Toast`, `UseTween` (+ stories) | frontend-coder | — | `src/Interface/client/Components/` (pastas novas) | `animalplane-reuse.md` §1, §2; DEC-015, 029, 066 | — | Feito |
| TASK-014 | `PromptController` + `Prompt` + bind de interagir | frontend-coder | TASK-002, TASK-004, TASK-013 | `src/Interaction/client/`, `src/Input/client/InputController.luau` | FEAT-005; DEC-039, 066, 097, 171; `architecture.md` §13 | `ACTIVE_WAVE = 1` local em `Rules.luau`; botão de toque = botão CAS "Use" 72 px junto ao pulo; sem SFX (GetSFX não portado) | Em QA (`src/Interaction/client/PromptController/` `init` + `Prompt` + `Rules`; `InputController` ganha `Keys`, `Title`, `TouchSize`, `Context` e source `Device`. Alvo = mais perto do centro (≤ 35% da altura), histerese 5%, não troca durante hold; hold completo (sem o 0,65 do AnimalPlane); pré-checagem local: `Requires` + Tool na mão, `Stock` (L-02), `Stations` Ready, `Customers` Ordering/Waiting. Testar com TASK-005/011: E no PC, botão "Use" e toque na pílula no emulador; T014-02..07; analyze 0 erro em Interaction/Input/client) |
| TASK-015 | `RoundController`: set `Shift` → sources Vide | frontend-coder | TASK-004 | `src/Round/client/RoundController.luau` | FEAT-003; `network.md` §3.1 | — | Em QA (substitui o exemplo: o listener do packet `Round` legado e os sources `Status`/`Seconds` saíram; lê `Shift` id 1 por `onAdded`/`onChanged`/`onRemoved` → sources `Day`, `Phase`, `IsNight`, `ClockText` + `Ready`; relógio = fórmula do §3.1 com `GetServerTimeNow`, interpolado a 10 Hz, `ClockText` só reescrito ao mudar o passo de `Content.Shift.ClockStepMinutes`; `Format(minutes)` e `MinutesAt(clock, now)` públicos. `modux check` ok; analyze 0 erro nos arquivos do client (os erros restantes são da `ClassService`, TASK-017 em andamento, que pede `PlaceService` da TASK-010). Testar depois da TASK-012: T015-01 a 03 de `wave-1.md`; no client, `RoundController.ClockText()` contra a fórmula; Open vai de "8:00 AM" a "6:00 PM" em passos de 10 min; Player 2 sai e volta no meio do Open e vê `Phase = Open` e a hora certa na hora) |
| TASK-016 | `CrewRig`: montagem de personagem de produção (crew e NPC) | backend-coder | TASK-006 | `src/Crew/shared/CrewRig/` | DEC-146, 152, 161, 165–169, 181; `build_crew.luau` | Q-144 h (casca de rosto) | Em QA |
| TASK-017 | `ClassService`: 6 classes, desbloqueio, seleção, modificadores | backend-coder | TASK-004, TASK-009 | `src/Class/server/ClassService/` | FEAT-028; DEC-069, 070, 186 | seleção no Run em modo dev (lobby `Q-085`); gemas de dev; "pedido do dono" (Raposa/Leão) = quem fez o Take Order (`content-data.md` §3.10/§5) x "Serve" em `classes.md` CLS-005: **divergência registrada**, vale Take Order até o game-designer fechar | Em QA (`ClassService` prio 690, Require Profile/Place/Net; único responder de `ClassAction`, taxa 2/s; no Run só com `IsDev()`. `Buy`: `InMvp`, não possuída, `Gems ≥ Price`, débito + `Classes` por cópia num `Update` (batch) + `RequestSave`; Notice `class_bought`/`not_enough_gems` (Value = preço). `Select`: possuída e não travada, senão `class_locked`; ok → `class_selected` (Value = `Classes.IndexOf`). `GetClass(p)`: no Run a 1ª leitura trava a classe até o jogador sair (a TASK-018 lê no spawn; antes dela nada trava). `GetModifier(p, stat, base?, ctx?)`: base padrão WalkSpeed 16, GrillTime 1 (multiplicador), PackageLimit 2, TipAmount 1, TipWindow 0 (offset); `ctx = { Packages, IsNight }`. `DevGrantGems(p, n)`: `error` sem `IsDev()`, saldo em 0..2^31−1, sem rede. Notice vai direto ao dono (L+R, sem `RunStateService`). Testar: T017-01..06, 09, 11, 12 já; T017-07 só com a TASK-018 (ou chamar `GetClass` no console); T017-10 no console: `GetModifier(p, "WalkSpeed", nil, { Packages = 3 })` com Urso = 14. rogen/generate/check ok; analyze 0 erro no `ClassService` (1 erro restante é do `PlaceService` da TASK-010 em andamento: `MapIndex` ainda não existe)) |
| TASK-018 | `CharacterService`: spawn da crew com o animal da classe | backend-coder | TASK-005, TASK-010, TASK-016, TASK-017 | `src/Character/server/CharacterService/` | DEC-146, 147, 167, 175, 186; `architecture.md` §1.1, §8.3, T25, T26 | Q-130 (T25, T26); colisão no mapa todo (DEC-175); animações R6 padrão (AST-069 Rascunho) | Em QA — `CharacterService` (715, só Run): fila de spawn; `CrewRig.Build(espécie de `ClassService:GetClass`, "crew", Day)` vira `StarterPlayer.StarterCharacter` por uma chamada de `LoadCharacter` (Animate/Health R6 padrão, sem avatar; **Provisório**, entra na lista da Q-130); `PS-<assento no roster>` +3 studs; grupo `Players` sem colisão consigo; `WalkSpeed` por `GetModifier` (conta Tools `Package` em mochila+mão; noite = false na onda 1); reset → respawn como crew após `RespawnTime`; personagem que não é crew (autoload, `LoadCharacter` alheio) é destruído e trocado. Testar: T018-01..07 (`wave-1.md`). Fora do escopo: `VitalService:Kill` (template) chama `LoadCharacter` sem rig — o guard troca, mas deve sair na reescrita do Vital |
| TASK-019 | `CameraController`: 1ª pessoa travada, corpo local | frontend-coder | TASK-002 | `src/Camera/client/CameraController.luau` | DEC-039, 097, 146, 171 | braços ocultos por padrão (DEC-097); gancho `SetArmsVisible` para DEC-167 | Em QA (testar: Play no Studio com 2 jogadores em PC e no emulador mobile; olhar para baixo/cima e girar: nada de cabeça, rosto, boné ou orelha na câmera, Tool visível na mão; o outro jogador vê o personagem inteiro. Rig custom só com a TASK-018; até lá vale com o R6 padrão) |
| TASK-020 | Tela "Crew": escolher e comprar animal (`ClassController` + UI) | frontend-coder | TASK-004, TASK-013, TASK-016 | `src/Class/client/`, `src/Interface/client/Components/CrewCard/` | DEC-186; FEAT-001 (parte de classe), FEAT-028 | nomes de classe placeholder; ícones (art-director) | Em QA (frontend-coder, 2026-10-10). **Arquivos:** `src/Class/client/ClassController.luau` (prio 450, Require Profile/Input/Place), `src/Interface/client/Components/CrewCard/` (`init`, `State`, story), `src/Interface/client/Components/CrewScreen/` (`init`, `Preview`, story). **O que faz:** só no Lobby ou no Run com `PlaceController:IsDev()` (mesma regra do `ClassService:CanWrite`); fora disso nem bind nem tela. 6 cards (`InMvp`; Panda/Leão fora, guaxinim nunca) com estado Selected/Owned/Buy/NoGems lido só do `ProfileController` (nada aplicado localmente); botão principal do animal em foco: Select / "Buy · 45 Gems" / desabilitado ("Selected", "Need 45 Gems", "..." enquanto há pedido). `ClassAction` por `fireServer`; o pendente limpa no próximo `Profile`, num `Notice` `class_*`/`not_enough_gems` (listener no `OnInit`) ou em 3 s. Toast fica com a `HudController`. Prévia: `ViewportFrame` com `CrewRig.Build(species, "crew", { Tag = false, Anchored = true })` + `Dress`, em `pcall` (sem kit = letra placeholder + 1 aviso), cache por espécie, estática. Layout mobile 620 × 320 px em escala 1 (cabe no iPhone SE paisagem com `CoreUISafeInsets`), `UIScale` até 2; toque ≥ 44 px, texto ≥ 14 px. **Provisórios:** abrir/fechar = `C` / `ButtonY` / botão touch "Crew" (56 px, posição padrão do CAS); fechar também com `ButtonB` (contexto Menu) e botão X; tela aberta põe o contexto `Menu` (prompts param) e volta a `Gameplay` ao fechar; textos e ícones placeholder (letra do animal; `ui-text.md` ainda sem seção "Crew"). **Como testar:** Studio Play Solo (modo dev) → `C` abre; conta nova: Dog "Selected", demais "45/120 Gems" em vermelho e botão "Need 45 Gems" desabilitado; no servidor `require(game.ServerScriptService.server.Class.ClassService):DevGrantGems(game.Players.Player1, 200)` → saldo 200 e cards Mustard em ≤ 1 s; Rabbit → "Buy · 45 Gems" → card "Owned", saldo 155, toast "Runner unlocked!"; "Select" → "Selected"; repetir rápido não manda 2 pedidos (botão "..."); emulador de celular (iPhone SE) e gamepad (seleção move o foco e a prévia). UI Labs: stories `CrewCard` e `CrewScreen` (compra/seleção simuladas com latência). Verificado: `rogen build`, `modux generate`, `modux check` ok; `tools/analyze.ps1` 0 erro nos arquivos da task (2 restantes em `src/Customer`, de outra task). **Falta:** boot no Studio e conferir a prévia com o kit real (`Assets.Crew`) |
| TASK-021 | `EconomyService`: dinheiro da party, gaveta, nota, resumo | backend-coder | TASK-004, TASK-010, TASK-012 | `src/Economy/server/EconomyService/` | FEAT-012, FEAT-014; DEC-045, 050, 051, 072, 083 | **Provisório**: gaveta e ledger só aceitam entrada em Open/Closing (fora disso warn e 0); gaveta não vazia no `ShiftStarted` (pulo de dev sem Summary) é descartada com warn; relatório sai pelo sinal próprio `Reported(info, report)` do EconomyService (o `ShiftEnded(info)` do RoundService segue sem `report`; `architecture.md` §4.1 diz `ShiftEnded(info, report)` → architect alinha); `BossBonusPP` (Leão, fora do MVP) = maior valor entre membros não `Away`, soma em A/B/C e nunca em D | Em QA (backend-coder, 2026-10-10). **Arquivos:** `src/Economy/server/EconomyService/init.luau` (740, Require Place/Net/RunState/Round, só Run) + `Ledger.luau` (puro: contadores, nota, bônus; números de `Content.OrderRules`/`RunParams`). **O que faz:** atoms `Cash` (= `RunParams.StartCash`) e `Drawer` → set `Economy` (id 1) por `effect` no `OnStart`. API: `Spend(amount, player?): boolean` (checagem e débito sem yield; falha com `player` → `not_enough_cash` com o preço), `AddToDrawer(amount, "Sale"\|"Tip"\|"Catch"): number`, `CountArrival()`, `CountResult(SaleResult)` (Perfect/Complete = satisfeito), `GetCash`, `GetDrawer`, `CanAfford`, `GetLedger`, `LastReport`, `IsShopOpen`, `DevAddCash(n)` (`error` sem `IsDev()`, `Cash` em 0..2^31−1). `ShiftEnded` → nota A–D (0 chegadas = C), bônus floor(gaveta × %), `Cash += gaveta + bônus`, `Drawer = 0`, `ShiftReport` ao `Audience` (`Stolen`/`Gems` 0, `AfkLocked`/`LastChanceUsed` false), sinal `Reported`. `ShiftStarted` zera ledger. Snapshot `Cash` (número); restore zera gaveta e ledger. Para a TASK-033: `CountArrival` ao chegar ao balcão, `AddToDrawer(preço, "Sale")` + `AddToDrawer(gorjeta, "Tip")`, `CountResult(result)`. **Testar:** Command Bar do servidor: `local E = require(game.ServerScriptService.server.Economy.EconomyService)`; T021-01 (`E:GetCash()` = 30); no Open: `E:CountArrival()` ×1, `E:AddToDrawer(20, "Sale")`, `E:CountResult("Complete")`, `RoundService:DevSkipPhase()` até o Summary → `ShiftReport` A, Bonus 4, Deposited 24, `Cash` 54, `Drawer` 0 (T021-03); gaveta 17 + 4 chegadas/3 completas → B, bônus 1 (T021-04); turno sem chegada → C (T021-05); `E:Spend(6)` duas vezes no mesmo script com `Cash = 6` → true, false (T021-07). `E:DevAddCash(-999)` → 0. Verificado: rogen/generate/check ok; analyze 0 erro no servidor (erros restantes são do client, `HudController` em andamento derrubando a tipagem dos Controllers). **Falta:** boot no Studio; T021-07 de ponta a ponta só com a TASK-036 |
| TASK-022 | `ItemService`: Tools, hotbar de 4, pacotes, Tool HotDog | backend-coder | TASK-004, TASK-007, TASK-011, TASK-017 | `src/Item/server/ItemService/` | FEAT-005, FEAT-007; DEC-040, 049, 174, 190 | **Provisório**: `Give` devolve `Tool?` (o `Context.Give` da §18.12 adapta com `~= nil`); categoria cheia que não é pacote (HotDog 2, Coffee 1…) avisa `hands_full`; só Tools criadas pelo `ItemService` contam no limite; sem snapshot de Tools (stash = onda 2, N-01); `DropHeld` (colisão só nas peças da Tool, não no `ToppingVisual`) fica para a onda do trânsito | Em QA (backend-coder, 2026-10-10). **Arquivo:** `src/Item/server/ItemService/init.luau` (prio 720, Require Place/Player/RunState/Class; só Run). **O que faz:** clona `Assets.Items.Tools/<key>`, nome = `Content.Items.Name`, atributos `Item`, `Count` (empilháveis; padrão = `Packages.Amount`), `Toppings` (hot_dog, limpo: só `ToppingKeys`, sem repetir, ≤ `OrderRules.MaxToppings`); põe na mão (`EquipTool`). Limites: `ItemRules.HotbarSlots` (4) e `CategoryLimits`, pacote por `ClassService:GetModifier(p, "PackageLimit")` (Urso 3). Recusa → `RunStateService:Notify` `hands_full` / `package_limit` (Value = limite), salvo `Silent`. API: `CanGive(p, key) -> (ok, notice?, value?)` (TASK-046), `Give(p, key, { Count?, Toppings?, Equip?, Silent? }) -> Tool?`, `Consume(p, tool)`, `SetCount(tool, n)` (≤ 0 consome: pacote vazio some), `AddTopping(tool, ing) -> boolean` + `HotDogVisual.refresh` (TASK-023), `GetHeld(p)`, `Holding(p, keyOuCategoria)` (= `Actions.Requires.Held`), `Count(tool)`, `Toppings(tool)`, `ItemOf(tool)`, `Tools(p)`, `CountCategory`, `PackageCount`, `PackageLimit`; sinal `Changed(player)` (velocidade do Urso na TASK-018). Tool que sai da Backpack/personagem do dono (morte, respawn) é esquecida e destruída; `PlayerRemoving` destrói e esquece tudo (N-01, sem vazamento). Boot avisa Tools faltando no kit (exceto `altered_item`, onda 3). **Testar** (Play, Command Bar servidor): `local I = require(game.ServerScriptService.server.Item.ItemService)`; `local p = game.Players:GetPlayers()[1]`; `I:Give(p, "pack_buns")` ×3 → o 3º dá toast "You can carry 2 packs" e nil (Urso: 3º passa); `I:Give(p, "hot_dog", { Toppings = "ketchup,cheese" })` aparece na mão com coberturas; mais Tools até 4 → 5º `hands_full`; `I:SetCount(pacote, 3)` mantém `Count`, `SetCount(pacote, 0)` some; `I:AddTopping(hd, "ketchup")` repetido = false; Player 2 sai com Tools → sem erro, `I.ByPlayer[p] == nil` e `I.Owners` sem as Tools dele. Verificado: rogen/generate/check ok; analyze 0 erro no `ItemService` (4 restantes em `CrewScreen/Preview` e `OpalController`, de outras tasks) |
| TASK-023 | `HotDogVisual`: empilhamento das coberturas | frontend-coder | TASK-007 | `src/Item/shared/HotDogVisual/` | DEC-142; AST-003 | — | Em QA — `HotDogVisual.apply(tool, toppings)` / `.refresh(tool)` (lê o atributo `Toppings`), `.order`, `.parse`, `.clear`; coberturas soldadas ao Handle (Weld C0) em `Model ToppingVisual`; ordem pelo `Content.Ingredients[k].Stack`. Testar: T023-01..04 (`docs/tests/wave-1.md`); no Command Bar, clonar `Assets.Items.Tools.hot_dog` no workspace (Handle ancorado) e chamar `apply(c, "ketchup,cheese")`. Provisório: chave desconhecida/ausente no kit é pulada e devolvida na lista de retorno (sem erro) |
| TASK-024 | `EconomyController` + gaveta no mundo (POS) | frontend-coder | TASK-004, TASK-005, TASK-013 | `src/Economy/client/` | FEAT-012; DEC-050, 155 | modelo novo da POS em produção (AST-020) | Em QA (frontend-coder, 2026-10-10). **Arquivos:** `src/Economy/client/EconomyController.luau` (790), `src/Interface/client/Components/DrawerValue/` (`init`, `Pop`, `DrawerValue.story`). **O que faz:** set `Economy` (registro 1) → sources `Cash`, `Drawer`, `Ready` (HUD da TASK-039 lê `Cash`); `Sale` com `Amount > 0` → "+$N" Mustard subindo 1,2 s sobre a gaveta (máx. 4 na tela); BillboardGui "$23" com moeda (pílula Ink 70%, Fredoka 26 px, pulo 1,15× quando sobe) em cada `Vehicle` tagueado, no `Value_Anchor` (Attachment ou BasePart) buscado dentro do veículo → vale para a registradora antiga e a POS nova (DEC-155). Sem `Value_Anchor` após 5 s: warn único e fallback no topo do modelo `MapId = DRAWER`; sem ele, warn e nada desenhado; `Value_Anchor` que chega depois substitui o fallback. Nada de dinheiro é aplicado localmente. Sem input (só exibição). **Provisórios:** `MaxDistance` 60 studs, `AlwaysOnTop = false`; um billboard por `Vehicle` (onda 2 com trailer estacionado precisa filtrar pelo `Shift.Vehicle`); moeda desenhada até AST-071; sem `VFX_Coins` (moedas da §10). **Como testar:** UI Labs → `DrawerValue` (alternar Sell). Studio com TASK-005 + EconomyService: T024-01..04 de `tests/wave-1.md` (2 players: mesmo valor e mesmo "+$N"; HUD/`Cash` não muda na venda; apagar `Value_Anchor` → warn + valor no topo da POS). Verificado: `rogen build`, `modux generate`, `modux check` ok; `tools/analyze.ps1` 0 erro |
| TASK-025 | `KitchenService` núcleo + estoque + Restock | backend-coder | TASK-002, TASK-008, TASK-011, TASK-022 | `src/Kitchen/server/KitchenService/init.luau` | FEAT-006, FEAT-007; DEC-049, 071, 184 | Q-062; **Provisórios** desta entrega: ingrediente bloqueado no início da run começa com `Amount = 0` (o pacote grátis do dia de liberação, TASK-046, abastece); snapshot com os nomes do `data.md` §3.3 (`Stk` = Amount por chave; `Stn` = `Capture` de cada módulo por chave estável `cart/grill`, nil = vazia) em vez de `"Kitchen"` do §18.12; `StationKind` sem módulo = **warn** (não `error`) enquanto 026–028 não entram; `StationApi` ganha `Station.Key`, `Station.Anchors`, `Station.Records` (o módulo escreve e chama `ctx.Publish`) e `Module.Refresh` opcional (architect incorpora ao §18.12); `Level` da vaga = nível do upgrade com a mesma chave da `StationKind` (grill); `ingredient_unlocked` (grupo) enviado aqui no `ShiftStarted` | Em QA (backend-coder, 2026-10-10). **Arquivos:** `src/Kitchen/server/KitchenService/init.luau` (650; Require Place/Net/RunState/Round/Interaction/Item/Class/Upgrade; só Run) + `StationApi.luau` (tipos do §18.12 + `check` da forma do módulo + `empty(kind)`). **O que faz:** atom `Amounts`; `Capacity` = `Ingredients.Capacity[GetEffect("StockCapacityLevel")]` do veículo atual e `Blocked` = `Day < UnlockDay` ou outro veículo, derivados (nunca guardados); set `Stock` com os 9 registros (`add` no `OnStart` + `effect`: compra de Cooler, restock, restore, dia novo e troca de veículo caem no mesmo effect). `restock` do núcleo: membro ativo, estação do veículo atual, pacote do ingrediente da âncora/estação na mão, não `Blocked`, `Amount < Capacity`; move min(sobra, capacidade − atual) e `ItemService:SetCount` (vazio some). Estações: `require` de `Stations/*.luau` (forma conferida; `Kind` repetida = `error`; `restock` em módulo = recusado), um `RegisterAction` por chave (união + `restock`) no `OnInit`; `OnStart` varre `Station` no `Workspace` em ordem de `GetFullName`, monta `Station` (vagas `Slot` filtradas por `Level`, âncoras do dono), escreve `StationId` (1..99), chama `Bind`; tag adicionada/removida em runtime tratada. Antes da ação: membro `Active`, estação do veículo atual, `Requires` da tabela (fase, dia/noite, item na mão), depois `restock` ou `Validate` do módulo (2º retorno = chave de `Notices` → toast); `Run` revalida dentro de trava **por estação** (fila de threads, vale mesmo se o `Run` ceder). `Publish(station)` faz diff de `station.Records` → `Stations` add/update/remove (id `StationId×100+Slot`, campos no range do fio). `Tick` 10 Hz dos módulos. Prompts: estação de outro veículo desligada (T36); `Restock` desligado com `Blocked`. API para outros: `GetStock`, `GetCapacity`, `IsBlocked`, `Stock`, `TakeStock`, sinal `StockChanged`. **Como testar** (Play com TASK-005; Command Bar servidor: `local K = require(game.ServerScriptService.server.Kitchen.KitchenService)`; `local I = require(game.ServerScriptService.server.Item.ItemService)`; `local p = game.Players:GetPlayers()[1]`): T025-07/08 `K:Stock("sausage")` 12/12, ketchup 30, `cheese`/`coffee` `Blocked = true`, `Amount = 0`; T025-01 `K:TakeStock("sausage", 3)` → 9/12, `I:Give(p, "pack_sausages")`, Restock na caixa → 12/12 e pacote `Count = 5`; T025-02 com 4/12 o pacote some; T025-03 com 12/12 o prompt some e forjado não mexe; T025-04 pacote de pão na caixa de salsicha recusado (`Rejected` "state"); T025-05 `UpgradeService:SetLevel("cart","cooler",2)` → 7/20 na hora; T025-06 `/dev skip` até o Prep seguinte com os mesmos `Amount`; T025-10 `/dev day 2` → `cheese.Blocked = false` + toast "New: Cheese!", bacon segue true. Verificado: `rogen build`, `modux generate`, `modux check` ok; `analyze.ps1` **0 erro** numa cópia sem `src/Customer/server` (no repo há ~600 erros vindos do `ModuxTypes/server/CustomerService.luau` gerado, outro agente: comentário no fim de linha de campo no `Setup` quebra o gerador e derruba a tipagem de todos os Services). **Falta:** boot no Studio |
| TASK-026 | Estações: grelha + trilho de descanso | backend-coder | TASK-025 | `src/Kitchen/server/KitchenService/Stations/Grill.luau`, `Rail.luau` | FEAT-006 passos 1–3; UPG-001; DEC-069 (Line Cook) | **Provisórios**: prompt "Grill" desligado sem vaga livre ou com estoque 0 e "Collect" ligado só em vaga `Ready` com espaço no trilho (sem toast: `Notices` não tem chave para isso); `Duration` fixada na colocação (upgrade no meio não reinicia nem acelera) e arredondada a 0,1 s (o que o fio carrega); `Capture` = nil nos dois (data.md §2.2: turno recomeça vazio) | Em QA (backend-coder, 2026-10-10). **Arquivos:** `src/Kitchen/server/KitchenService/Stations/Grill.luau` (`Kinds = { grill, sausage_stock }`, §18.12) e `Rail.luau` (`Kinds = { rail }`, sem ações). **O que faz:** `grill_place` (na caixa de salsicha): valida estoque ≥ 1 e vaga livre na grelha do mesmo veículo; `Run` pega a vaga livre de menor `Slot`, só então `TakeStock(sausage, 1)` (nunca uma sem a outra) e grava `Working` com `StartedAt = Now`, `Duration = Effect(GrillTime) × Modifier(quem colocou, GrillTime)` (Gato 0,85 só nas dele). Vagas ativas = `Slot` 1..`GrillSlots` (2/3/4) com Attachment no nível; vaga nova do upgrade entra `Empty`, em andamento não reinicia (`Refresh` + `Tick`). `Tick` 10 Hz: `Working` → `Ready` em `StartedAt + Duration`, sem queimar. `grill_collect` (âncora `Att_Slot<n>`, `Slot`): vaga `Ready` + trilho com espaço → `Rail.Push`, vaga volta a `Empty`. Trilho: fila FIFO, registro único `Slot 0` (`Ready` com ≥ 1, `Count`), capacidade `Vehicles[v].RailSlots` (6). **API para a TASK-027** (`require(script.Parent.Rail)`): `Rail.Find(vehicle)`, `Rail.Count(vehicle)`, `Rail.Room(vehicle)`, `Rail.Push(ctx, vehicle)`, `Rail.Pop(ctx, vehicle) -> boolean` (síncronas, publicam sozinhas). **Como testar** (Play com TASK-005; Command Bar servidor `local K = require(game.ServerScriptService.server.Kitchen.KitchenService)`): T026 — "Grill" ×1 → `K:Stock("sausage").Amount` cai exatamente 1 e a vaga 1 mostra barra de 12 s (±0,2); "Grill" com 2 vagas ocupadas (nível 1) → prompt some e nada muda; `K:TakeStock("sausage", 99)` até 0 → prompt some; `UpgradeService:SetLevel("cart","grill",2)` → 3ª vaga entra vazia, as em curso seguem, novas com 10 s; Gato: 10,2 s no nível 1 só nas que ele colocou; "Collect" na pronta → trilho `Count` +1, vaga livre; trilho com 6 → "Collect" some; 2 jogadores "Grill" no mesmo frame com 1 vaga → só 1 salsicha sai do estoque. Verificado: `rogen build`, `modux generate`, `modux check` ok; `tools/analyze.ps1` **0 erro**. **Falta:** boot no Studio |
| TASK-027 | Estações: caixa de pão + tábua (vagas = `Vehicles.<v>.BoardSlots`: carrinho 2, trailer 3) → Tool HotDog | backend-coder | TASK-026 | `.../Stations/BunCrate.luau`, `Board.luau` | FEAT-006 passos 4–5; **DEC-190, DEC-215** | **Provisórios:** "Slice Bun" desligado sem vaga livre na tábua ou com pão 0 e "Add Sausage" ligado só com pão cortado + trilho ≥ 1 (mesma regra da grelha); `Capture` = nil (turno recomeça com a tábua vazia, data.md §2.2); "Hands full" vem do próprio `ItemService:Give` (o `Context` não tem `CanGive`): `Give` antes do `Rail.Pop`, recusa não mexe em trilho nem em pão | Em QA (backend-coder, 2026-10-10). **Arquivos:** `src/Kitchen/server/KitchenService/Stations/BunCrate.luau` (`Kinds = { bun_crate }`, ação `bun_cut`) e `Board.luau` (`Kinds = { board }`, ação `board_add_sausage`). **O que faz:** `bun_cut` (caixa de pão, hold 0,5): pão ≥ 1 e vaga livre; `Run` pega a vaga livre de menor `Slot` (`Board.Free`), só então `TakeStock(bun, 1)` e `Board.Place` grava `Working` com `Duration = Content.Stations.bun_crate.Params.CutTime` (1,5). Vagas ativas = `Slot` 1..`Vehicles[v].BoardSlots` (carrinho 2, trailer 3) com Attachment; um registro `board` por vaga (`StationId×100+Slot`, contrato do `KitchenController/Board.luau`). `Tick` 10 Hz: `Working` → `Ready` (pão cortado). `board_add_sausage` (`Prompt_Board`, toque, um prompt): pão cortado mais antigo (DEC-190) + `Rail.Count ≥ 1` → `Give(hot_dog)` → `Rail.Pop` → vaga `Empty`; tudo síncrono dentro da trava da tábua (só um recebe). **Como testar** (Play com TASK-005; `K`/`I`/`p` da TASK-025): "Slice Bun" → `K:Stock("bun").Amount` −1, vaga 1 com pão inteiro + barra 1,5 s → cortado; 2ª vez → vaga 2; 3ª no carrinho → prompt some e forjado não tira pão; `K:TakeStock("bun", 99)` → prompt some; sem salsicha no trilho "Add Sausage" some; com trilho ≥ 1 → Tool "Hot Dog" na mão, trilho `Count` −1, vaga do pão mais antigo livre; hotbar com 4 Tools (`I:Give` ×4) → toast "Hands full", trilho e pão intactos; 2 jogadores no mesmo frame com 1 pão → só um HotDog. Verificado: `rogen build`, `modux generate`, `modux check` ok; `tools/analyze.ps1` **0 erro** no projeto. **Falta:** boot no Studio |
| TASK-028 | Estações: complementos em tigelas (com bloqueio) + lixeira | backend-coder | TASK-025 | `.../Stations/Toppings.luau`, `Trash.luau` | FEAT-006 passo 6; DEC-071, 072, 156 | **Provisórios:** (1) o `StationApi.Context` não tem `AddTopping`: o módulo usa `ctx.AddTopping` se existir, senão troca o HotDog por um novo com as coberturas (`Consume` + `Give`; o hot dog pode mudar de slot na hotbar e reequipa). Pedido ao architect/dono da TASK-025: `Context.AddTopping = ItemService:AddTopping` (1 linha no `BuildContext` + tipo no `StationApi`); o módulo passa a usar sozinho. (2) Com 3 coberturas o servidor recusa sem toast (não há `Notice`); `Rules.luau` (frontend) não esconde "Add X" com 3 → pedido ao frontend: checar `#Toppings >= OrderRules.MaxToppings`. (3) `PromptEnabled` de `topping_add` fica ligado; esconder por `Blocked`/0 é do client via `Stock` | Em QA (backend-coder, 2026-10-10). **Arquivos:** `src/Kitchen/server/KitchenService/Stations/Toppings.luau` (`Kinds = {"toppings"}`, ação `topping_add`), `Trash.luau` (`Kinds = {"trash"}`, ação `discard`). **O que faz:** "Add X": `Ingredient` da âncora tem de ser Sauce/Topping; HotDog na mão (`Item` = `hot_dog`), sem esse complemento, `< MaxToppings` (3), `GetStock ≥ 1`; no `Run` (trava da estação) revalida, `TakeStock(ing, 1)` (recusa `Blocked`/vazio de forma atômica) e só então adiciona. Sem registro em `Stations` e sem snapshot (estado = `Stock`/"Stk"). `Bind` avisa âncora `topping_add` sem `Ingredient` válido. "Throw Away": HotDog na mão → `ctx.Consume`. **Como testar** (Play, Command Bar servidor com `K`/`I`/`p` da TASK-025): `I:Give(p, "hot_dog")`; hold "Add Ketchup" → ketchup 29/30, Tool com `Toppings = "ketchup"` e visual; de novo na mesma tigela: prompt some (client) e Interact forjado não muda nada; ketchup+mustard+um 3º liberado → 4º recusado, estoque intacto; Day 1 `cheese` bloqueado: forjado não tira nada; `/dev day 2` → cheese abre (bloqueio some, prompt volta); `K:TakeStock("mustard", 30)` → "Add Mustard" some, forjado recusado; dois jogadores com o último ketchup → só um recebe; lixeira com HotDog → some; sem HotDog → nada. Verificado: `rogen build`, `modux generate`, `modux check` ok; `analyze.ps1 -Filter *Kitchen*` **0 erro** |
| TASK-029 | `KitchenController` núcleo + estoque visual (contadores, `Fill`, ícones, cadeado) | frontend-coder | TASK-004, TASK-005 | `src/Kitchen/client/KitchenController/` (+ `Stock.luau`) | FEAT-007; DEC-140, 156 | Q-152 (ícones placeholder); modelo novo AST-017 em produção; contador das tigelas na plaquinha `Label_<Ing>` (não billboard: 6 billboards a 2 studs colidiriam com os prompts); sem registro = tigela fechada; `Fill` encolhe para a própria base (mín. 12%, 0 = some); tween 0,25 s | Em QA (frontend-coder, 2026-10-10). **Arquivos:** `src/Kitchen/client/KitchenController/` (`init` prio 680, `Context`, `Stock`), `src/Interface/client/Components/StockCounter/` e `StockPlate/` (+ stories), `Theme.Color.Low`. **O que faz:** listeners de `Stock` e `Stations` no `OnInit` → sources Vide (`StockOf(key)`, `SlotOf(id)`); monta por `Station` (tag) as partes de `PARTS` cujo `Kinds` contém o `StationKind` (root Vide por estação, desmonta ao sair). `Stock`: S/B → `Fill` + pílula "7/12" 1,2 acima dos prompts da estação; K → por tigela `Fill_<Suf>`, `StockPlate` (SurfaceGui na face da `Label_<Suf>` que olha para longe da `Bin_<Suf>`: ícone `Content.Ingredients.Icon` ou placeholder nome + cor da paleta, "7/12" vermelho com ≤ 2) e `Lid_<Suf>`/`Lock_<Suf>` só com `Blocked` (sem `Lock_`: clone de `Assets.Equipment.Padlock` em `Att_Lock_<Suf>`/topo da tampa). Tudo local (`LocalTransparencyModifier`, Size/CFrame no client). **TASK-030:** criar `Grill`/`Rail`/`Board` como `Context.Part` e listar em `PARTS`; ler `context.Slot(StationId*100+Slot)`. **Como testar:** Studio com TASK-005; sem `KitchenService` as 6 tigelas ficam com tampa+cadeado e sem contador. Com a TASK-025 (ou `Net.Stock:add(i, {...})` no console do servidor): Amount/Capacity muda contador e `Fill` (tween curto); ≤ 2 vermelho; `Blocked = true` fecha a tigela e some o contador; 2 clients veem o mesmo. UI Labs: `StockCounter` (Auto drena) e `StockPlate` (Icon vazio = placeholder, Vertical). rogen/generate/check ok; analyze 0 erro em Kitchen/StockCounter/StockPlate (erros restantes em `HudSummary`, `EconomyService`, `DevService` de outras tasks) |
| TASK-030 | Visuais de grelha, trilho e tábua (salsichas, barras, pães) | frontend-coder | TASK-013, TASK-029 | `src/Kitchen/client/KitchenController/` (`Grill.luau`, `Rail.luau`, `Board.luau`) | FEAT-006; DEC-015, 029, 190 | — | Em QA (frontend-coder: `Grill`/`Rail`/`Board` + helpers `Slots.luau` no PARTS; comida = clone local de `Assets.Items.Food` soldado na vaga, `ProgressBar` 1,0 stud acima; troca crua→grelhada / inteiro→cortado quando a barra local fecha; trilho mostra `Count` nas vagas 1..n. Testar com a TASK-026/027: grelhar/cortar, conferir barra × "Ready" ±0,2 s e reentrar no meio de um preparo. Provisório: orientação da comida pela linha das vagas (salsicha atravessada, pão ponta a ponta) e âncora sem `Level` vence; VFX de pronto/vapor fora do escopo) |
| TASK-031 | `NpcService` mínimo: pool, cliente animal, rota por grafo | backend-coder | TASK-005, TASK-009, TASK-016 | `src/Npc/server/NpcService/` | `architecture.md` §12.3, T11; DEC-045, 149, 181, 188, 191 | Q-130 (T11); Q-162; sem trânsito/reserva de faixa nesta onda | Em QA (backend-coder, 2026-10-10). **Arquivos:** `src/Npc/server/NpcService/` (`init` prio 610, Require Place/Round; `Look`, `Pool`, `Walker`). **O que faz:** só Run. Pool de no máx. `Content.Flow.MaxNpc` (12) rigs, Opal fora; rig por `CrewRig.Build` (espécie do tipo, `civil_*` sorteada, acessórios do tipo); reuso por chave espécie+tipo (roupa é só atributo, o client veste, T40); sem rig ocioso igual: constrói enquanto há vaga, senão reconstrói o ocioso mais antigo; todos ocupados = `Spawn` devolve nil. Ocioso fica em `ServerStorage.NpcPool` (EntityIds liberados). Servidor só escreve `Species`/`Outfit`/`CustomerType`/`LookPack`/`NpcId` (NpcId cíclico 1..65535, novo a cada spawn); `LookPack` Day de dia / Mid à noite, refeito no `ShiftStarted` (DEC-181); Night nunca escrito aqui. Âncoras `Prompt_Customer` (`take_order`) e `Prompt_Refuse` (`refuse`) criadas 1× por rig no HRP, `PromptEnabled = false`, resetadas no despawn. Grupo `Npc` sem colisão com `Npc`/`Players` (registra os dois grupos); dono de rede = servidor; estados de Humanoid não usados desligados. Movimento: `Humanoid:MoveTo` nó a nó por `MapIndex.Path` (`AvoidQueue` padrão true: Q nunca intermediário, MAP-01 §9.1), ≤ 2 A*/frame, ponto perdido 2× = encaixe no nó; ao chegar num `MapPoint` vira para a frente dele. **API (TASK-032):** `Spawn({CustomerType?, Species?, Outfit?, From?, Rng?}) -> NpcId?`, `WalkTo(id, node, {AvoidQueue?, AvoidCrossings?, Face?}) -> boolean` (cede; cancelado por `Stop`/novo `WalkTo`/`Despawn`), `Stop`, `Despawn`, `DespawnAll`, `Get`, `GetModel`, `GetNode`, `Anchors(id)`, `IdOf(instância)`, `Count`, `Capacity`, `PoolStats() -> (rigs, builds)`, `PickType(rng?)`, sinais `Spawned(id, model)`/`Despawned(id)`. **Provisórios:** chegada de dia SP-A/D1 50/50 (30/30 do MAP-01 sem SP-B), noite 60/40, constante no Service (sem tabela em Content); offsets das âncoras (0, 1,5, 0)/(0, 0, 0); encaixe anti-trava; sorteio de tipo por `Weight`/`Unlock*` com `Random` próprio (TASK-032 deve passar `Rng` com semente da run, §4 regra 6); passantes (DEC-183) e animação por `Motor6D.Transform` fora: onda 2/Q-162 (Transform não replica, é do client); movimento segue T11 (`MoveTo`). **Fora do escopo, registrar:** grupo `Players` precisa ser aplicado ao personagem pela TASK-018 (até lá jogador colide com NPC, T031-04 depende dela); rig de NPC é `Atomic` (CrewRig) e contém `Interactable`: `MapIndex.Validate` item 5 acusaria se rodasse com NPC na rua (hoje só roda no `OnStart`). **Como testar:** Studio com binding + kits; Command Bar do servidor: `local N = require(game.ServerScriptService.server.Npc.NpcService)` → `N:DevParade(5)` (só dev): nascem em SP-A/D1, vão a Q5 pela calçada (não pela fila), Q1, EX-E e voltam ao pool; `N:Count()` ≤ 12 e `N:Spawn()` com 12 ativos = nil; `N:PoolStats()` não cresce acima de 12 em soak; conferir atributos `Outfit ∈ civil_a..h`, `Species ≠ raccoon`, `LookPack = Day`, `NpcId` novo a cada spawn (T031-01..06). Verificado: `rogen build`, `modux generate`, `modux check` ok; `analyze.ps1` 0 erro nos arquivos da task (erros restantes são de controllers do client de outras tasks) |
| TASK-032 | `CustomerService`: fluxo, fila Q1–Q5, ciclo de vida | backend-coder | TASK-008, TASK-012, TASK-031 | `src/Customer/server/CustomerService/` (`init.luau`, `Queue.luau`) | FEAT-009; DEC-045, 046, 185; MAP-01 §9.1 | recálculo no início do turno (DEC-185) | Em QA (backend-coder, 2026-10-10). **Arquivos:** `src/Customer/server/CustomerService/` (`init` prio 590, Require Place/Net/RunState/Round/Economy/Interaction/Upgrade/Npc; `Queue` puro). **O que faz:** só Run, só fase Open. Intervalo médio = `BaseInterval` ÷ (crescimento do dia × `PartyMult`[membros conectados] × `DayFlowBonus`), ±`Jitter`, tudo de `Content.Flow`/`UpgradeService`; agenda pelo horário previsto (sem drift). Cada tentativa: fila cheia (não-`Leaving` ≥ `QueueSize`, lido ao vivo → Counter 2 abre Q4 na hora) = `skipped_queue_full`; `MaxCustomersDay` (8) / teto do pool / `Spawn` nil = `skipped_npc_cap`; senão `spawned`; sinal `SpawnAttempted(outcome)` sempre. `Random` por turno = hash(`RunSeed`, Day, IsNight, Attempt, "customers") passado ao `NpcService:Spawn`. Ciclo: `Arriving` (ponto → Q5, `AvoidQueue`) → `Queued` (entra atrás do último, `CountArrival`, sinal `Joined`; anda vaga a vaga até a sua) → `Ordering` em Q1 (sinal `Fronted`) → `Waiting` (TASK-033) → `Leaving` (sai EX-E 60% / D1 40%; de Q2..Q5 pela fila; despawn ao chegar, 45 s de rede de segurança) → removido (sinal `Removed`). Quem está em Q1 segura a vaga até sair. Set `Customers` (id = `NpcId`): `add` no spawn, `update` registro inteiro, `remove` ao sumir; `PatienceEndsAt = 0` e `Order` vazio aqui (T41); prompts ficam desligados (TASK-033 liga). Summary manda todo mundo embora (`shift_end`); `ShiftStarted` (e restore) zera tudo; `SetCounterProbe` = ninguém fora de `Leaving`. **API p/ TASK-033:** `Get`, `IdOf(instância)`, `Front`, `Update(id, {State=Ordering/Waiting, Order, PatienceEndsAt, Mood})` (valida), `Leave(id, mood?, reason?)`, `Count`, `Occupants`, `QueueSize`, `Flow()`; sinais `SpawnAttempted`, `Joined`, `Fronted`, `Left(id, reason)`, `Removed`; `JoinedAt` no registro = base da paciência. **Provisórios:** `PartyMult` travado na entrada do Open (não no `ShiftStarted`: na onda 1 a run começa com o 1º membro e o 2º chega na Prep); divisão de saída 60/40 constante no Service (sem tabela em Content); quem está em Ordering/Waiting segura Q1; sem fluxo à noite (Content sem campo; aviso único); clientes ainda na fila no fim do Closing saem sem `CountResult` (TASK-033 decide pelo `Left` com `shift_end`). **Como testar:** Command Bar do servidor `local C = require(game.ServerScriptService.server.Customer.CustomerService)`; `R:DevSkipPhase()` até Open; `C:Flow()` (Party, MeanInterval 22 no Day 1 solo, QueueSize 3); sem atender, fila para em 3 e `SpawnAttempted` passa a `skipped_queue_full` (T032-02); `C:Leave(C:Front())` → Q2 vai a Q1, sai por EX-E/D1 (T032-06); `C:DevSpawn()` (só dev); Prep/Closing sem spawn (T032-04); Closing termina assim que o último sai. Verificado: `rogen build`, `modux generate`, `modux check` ok; `analyze.ps1` 0 erro no projeto. **Falta:** boot no Studio |
| TASK-033 | Pedido, atendimento e pagamento (Take Order / Serve / Refuse) | backend-coder | TASK-021, TASK-022, TASK-032 | `src/Customer/server/CustomerService/Orders.luau`, `OrderRoll.luau` (função pura, R3) (+ registro no `init.luau`) | FEAT-010, FEAT-011; DEC-071, 072, 187 | **humor simplificado** (Q-164) | Em QA (backend-coder, 2026-10-10). **Arquivos:** `CustomerService/OrderRoll.luau` (puro, R3: `Roll(day, customerType, rng, isNight?)`, só `Content`), `Orders.luau` (puro: `Roll` → OrderRoll, `Patience`, `TipWindow`, `Price`, `Ticket`, `Evaluate`, `Pay`, `Tip`, `IsAnnoyed`; números de `OrderRules`/`MoodRules`), `init.luau` (seção "Orders"; Require + `ItemService`, `ClassService`). **O que faz:** pedido sorteado no `Joined` (K oculto, `Ticket` só no servidor; `Random` próprio por turno, domínio `orders`, para não deslocar os sorteios de spawn); paciência 40 + 5K + `PatienceBonus` desde `JoinedAt`. `Fronted` liga "Take Order" + "Refuse". **Take Order** (Ordering, Q1, membro ativo, loja Open/Closing): uma escrita `Waiting` + `Order` + `PatienceEndsAt` (T41); guarda no ticket quem anotou, `TipEndsAt` = agora + 16 + 4K + `TipWindow` dele e `TipAmount` dele (L-04); âncora vira `serve`. **Serve** (Waiting, HotDog na mão): Completo = preço (+ gorjeta na janela = `Perfect`; Leão $0 → `Complete`), Incompleto = floor(50%) sem gorjeta, Errado = $0 e o HotDog fica na mão; consome o HotDog nos outros casos. **Refuse** e paciência zerada = $0 (`Refused`/`Left`). Todo desfecho: `AddToDrawer` (Sale/Tip), `CountResult`, `Sale` ao grupo, `Leave`. Humor (Provisório, Q-164): Annoyed a ≤ `AnnoyedAt` da paciência (escrito pelo servidor), Happy em Completo/Perfeito, Complaining em Errado/Refuse/desistiu; Incompleto mantém o atual; não mexe no pagamento. **Provisórios:** `PatienceBonus` travado na chegada à fila; quem sai no `shift_end` não gera `CountResult`/`Sale` (loja fechada; conta só como chegou e não satisfeito); Refuse vale em Ordering e Waiting. **Como testar:** Command Bar (Server) `local R = require(game.ServerScriptService.server.Customer.CustomerService.OrderRoll)`; `local r = Random.new(7) local t = os.clock() for i = 1, 1000 do R.Roll(1, "student", r) end print(os.clock() - t)` (< 0,05 s); mesmo `Random.new(seed)` = mesmo pedido; contar `#R.Roll(d, ...)` em 1.000 para K por fase (±3 p.p.), Day 1 só ketchup/mustard, nunca repetido, ≤ 3. Em jogo: chegar a Open, cliente em Q1 → "Take Order" (balão + anel), `C:GetTicket(id)` mostra o pedido; servir certo (+$ na gaveta, Happy), sem um complemento (50%), com complemento a mais (HotDog volta, $0), "Refuse" (hold 1 s), esperar a paciência (Annoyed → Left). Verificado: `rogen build`, `modux generate`, `modux check` ok; `analyze.ps1` 0 erro no projeto. **Falta:** boot no Studio |
| TASK-034 | `CustomerController`: balão do pedido, rosto de humor, reação de venda | frontend-coder | TASK-004, TASK-013, TASK-016 | `src/Customer/client/` | FEAT-010, FEAT-011; DEC-071, 152, 162, 187 | Q-164; Q-152; **Provisório**: ícones placeholder (chip colorido + letras; base pão+salsicha desenhada) até Q-152/AST-071; anel de paciência com vão = max(40 + 5K, tempo restante ao ver o `PatienceEndsAt`) (bônus do Counter fora deste controller); reação Refused = neutra sem fala; Incompleto sem `{item}` | Em QA (frontend-coder, 2026-10-10). `src/Customer/client/CustomerController/` (`init`, `Reactions`; prio 670, Require RigController) + componentes `OrderBubble` e `ReactionBubble` (com story). Set `Customers` → source por NpcId (listeners no OnInit); rig achado pelo atributo `NpcId` das `AnimalRig` (re-lido a cada mudança, pool). Balão só em `State = Waiting` (pós Take Order), base + até 3 ícones na ordem de `ToppingKeys`, ≤ 8 montados, tamanho em px fixo (ícone 44 px, texto ≥ 16 px). Anel só com `PatienceEndsAt > 0` (T41), Green → Mustard em ≤ `MoodRules.AnnoyedAt`. Rosto = `Moods[Mood].Expression` via `RigController:SetExpression` (sem derivar humor da paciência), limpo quando o registro sai. `Sale` → `ReactionBubble` 3 s (Perfect/Complete estrela; Incomplete/Wrong/Left nuvem; Refused "..."), fala de `ui-text.md` §8; o balão de pedido some durante a reação. Sem input (nada clicável). **Testar:** UI Labs `OrderBubble`/`ReactionBubble`; no Studio, sem TASK-032, criar pelo Command Bar (Server) um rig `CrewRig.Build` com `NpcId = 7` e um registro `Net.Customers:add(7, {...})` → balão só ao passar a `Waiting` com `Order`/`PatienceEndsAt`; `Mood = "Annoyed"` troca o rosto; `Net.Sale:fireAll`-equivalente do grupo com `Npc = 7` mostra a reação. Verificado: rogen/generate/check ok, analyze 0 erro. **Falta:** teste com a TASK-032/033 |
| TASK-035 | `UpgradeService`: níveis por veículo, efeitos, peça visível | backend-coder | TASK-008, TASK-021 | `src/Upgrade/server/UpgradeService/` | FEAT-015; `upgrades.md`; DEC-046, 052, 101, 106, **184** | Q-163. **Entregue:** `init` + `Pieces` (priority 630). API: `GetEffect(stat, vehicle?)`, `GetLevel`, `CurrentRow`, `NextLevel`, `IsMaxed`, `CanBuy`, `Buy(key, player?)` → `(ok, reason)` (`unknown`/`not_on_vehicle`/`maxed`/`locked`/`busy`/`not_enough_cash`), sinal `Changed(key, level, vehicle)`, `SetVehicle` (onda 2); snapshot `Upg` (os 2 veículos); set `Upgrades` com 5 registros (`trailer_lights` = 0 no cart); peça `UpgradePiece` por visibilidade no servidor. **Provisório:** depois de uma compra, o mesmo upgrade fica recusado (`busy`) por `Actions.bench_buy_upgrade.Hold` (T035-06: o `Interact` não traz nível). Testar: só com a TASK-036 (bancada) ou com um comando dev `upgrade <key>` (sugestão, fora do escopo) | Em QA |
| TASK-036 | `MarketService`: prateleiras + bancada de upgrades básicos | backend-coder | TASK-011, TASK-022, TASK-035 | `src/Market/server/MarketService/` | FEAT-008, FEAT-015; DEC-049, 101, 106, 109, **180** | S1 sempre vazia nesta onda (Q-120). **Provisório:** `Blocked` derivado no próprio Service pela fórmula do `Stock.Blocked` (`Day < UnlockDay` ou `Ingredients.Vehicle` ≠ veículo atual) até a TASK-025 expor o dela; texto da bancada "Buy Grill 2 — $60" (Name + nível; sem número se só há 1 nível a comprar); `buy_package` do mesmo jogador com intervalo < 0,8 × Hold recusado | Em QA (backend-coder, 2026-10-10). **Arquivos:** `src/Market/server/MarketService/init.luau` (615, Require Place/Player/Interaction/Item/Economy/Upgrade/Round/RunState; só Run); `src/Dev/server/DevService/Commands/Upgrade.luau`. **O que faz:** registra `buy_package` e `bench_buy_upgrade` no `OnInit`; `Validate` = run iniciada + membro `Active` (+ pacote não `Blocked`; upgrade `UpgradeService:CanBuy`). Pacote: `CanGive` (toast `package_limit`/`hands_full`, sem cobrar) → kit/Backpack → `Spend` (toast `not_enough_cash`) → `Give` com `Count = Packages.Amount`, sem yield entre cobrar e entregar. Upgrade: `UpgradeService:Buy(key, player)`. Prompts por um `effect` (Day, veículo, níveis): prateleira `PromptEnabled = not Blocked` (texto fica com o client); B1–B5 só com o upgrade no veículo, não Maxed e `Day ≥ UnlockDay`, `PromptText` com nível e preço; S1 sempre desligado (`bench_buy_item` onda 4, não registrado). Mart aberto em toda fase. Dev: `/dev upgrade` (lista), `/dev upgrade <key>` (próximo nível grátis), `/dev upgrade <key> <n>` (nível exato) via `SetLevel`. **Testar:** T036-01..12 + T035-01/02/06 (`wave-1.md`); `/dev cash 500`, `/dev day 2` (queijo à venda, bacon não). Verificado: rogen/generate/check ok, analyze 0 erro. **Falta:** boot no Studio |
| TASK-037 | `MarketController`: preços, "Out of stock", bancada no mundo | frontend-coder | TASK-004, TASK-005, TASK-013 | `src/Market/client/` | FEAT-008, FEAT-015; DEC-015, 180 | linha "Day N" sob a etiqueta (Rascunho) | Em QA (`src/Market/client/MarketController/` `init` + `Labels`; componentes `ShelfTag` e `BenchCard` com story em `Interface/client/Components/`; `Theme.Color.NoCash`; `RoundController` ganha source `Vehicle`. Lê `Economy`/`Stock`/`Upgrades` em `OnInit`; prateleira: preço, vermelho sem saldo, "Out of stock" + "Day N" enquanto `Stock.Blocked`; bancada B1–B5: próximo nível (nome, efeito em 1 linha, preço), "Maxed", "Trailer only" (B5 no carrinho); S1 "Nothing special today" (sem set `Bench` na onda 1). Provisórios: nomes de nível e linhas de efeito (`ui-text.md` §3 Rascunho), "Maxed" vs "MAX" do `ui-text.md`/AST-049, miniatura = inicial até AST-071, posição dos cartões (acima de `Price_Anchor_<Slot>` ou da âncora; etiqueta 1,3 abaixo da âncora da prateleira). analyze 0 erro nos arquivos da task. Testar com TASK-036/035/025 no Studio: 9 etiquetas no Mart, Cheese/Bacon/etc. com "Out of stock"+"Day N" no Day 1 e sem etiqueta no dia de liberação; `Economy.Cash` < preço deixa a etiqueta vermelha; comprar Grill troca o cartão B1 para "Big Sizzle Grill"/$150 e depois "Maxed"; B5 "Trailer only"; legível a ~4 studs no emulador de celular) |
| TASK-038 | Opal local: idle e falas por fase | frontend-coder | TASK-009, TASK-016 | `src/Opal/client/OpalController.luau` | DEC-079, 099, 178, 191; NPC-020; `architecture.md` §2.3 | Q-160 (espécie da Opal) — fechada: coruja (DEC-203) | Em QA (frontend-coder). Feito: `OpalController` (rig local `owl` em `OP-1`, `Tag=false`, Day/Normal fixos, Humanoid → AnimationController + idle em loop; balão 3 s ao entrar a 8 studs, 1×/visita, cooldown 90 s, sem repetir a última fala; pool por `IsNight` + `Night` se o `RoundController` expuser, senão N1; zero rede, sem gancho de anomalia) + componente `Interface/Components/SpeechBalloon` (+ story). Provisório: roupa `civil_a` sem boné até a ficha AST-057; idle R6 padrão (`180435571`) até o idle de palavras cruzadas. Testar (T038-01..05): Play solo, ir ao caixa do Mart → 1 balão; sair/voltar antes de 90 s → nada (NPC-020; T038-02 precisa de entradas ≥ 90 s); Explorer do servidor sem `Opal`; RigController não toca nela (sem tag `AnimalRig`) |
| TASK-039 | `HudController` básico: relógio, turno, dinheiro, toasts, resumo | frontend-coder | TASK-013, TASK-015, TASK-024 | `src/Hud/client/HudController.luau`, `src/Interface/client/Components/Hud*/` | FEAT-032, FEAT-014; DEC-015, 048, 051, 053, 081 | textos placeholder até `ui-text.md` | Em QA (frontend-coder, 2026-10-10). **Arquivos:** `src/Hud/client/HudController.luau` (500), `src/Interface/client/Components/HudPill/` (`init`, `Money`, `HudPill.story`), `HudSummary/` (`init`, `HudSummary.story`), `HudScreen/` (`init`, `HudScreen.story`); `Theme.Color.Slate` (nota D). **O que faz:** monta a ScreenGui `Hud` (`CoreUISafeInsets`, `ResetOnSpawn = false`) no `OnStart`: topo esquerdo dinheiro da party (`EconomyController.Cash`, moeda, pulo 1,15× ao subir) e abaixo "Day N" com sol (`RoundController.Day/IsNight`); topo centro relógio (`ClockText`); topo direito toasts de `Notice` (texto de `Content.Notices` com `{value}/{item}/{upgrade}/{class}`, 4 s, 3 visíveis, fila máx. 6, mesmo texto já na fila é descartado; Alert = Mustard, Good = Green); centro resumo do `ShiftReport` (nota grande A/B/C/D sem vermelho, Customers completos/chegaram, Drawer, Stolen só se > 0, "Grade X bonus", Deposited, Gems só se > 0, "Last chance used"), some sozinho em 15 s dia / 20 s noite ou quando começa novo turno. Só Frame/TextLabel, nenhum bind de input, nada clicável; não lê `Chances`; sem reputação, XP ou sanidade. Escala 1 no celular menor (375 px de altura) até 2 (1080p). Responders `Notice`/`ShiftReport` no `OnInit`. **Provisórios:** à noite a pílula mostra só "Night" sem número (RoundController ainda não expõe `Shift.Night`; onda 2); sanidade fora (onda 2); ícones sol/lua/moeda desenhados até AST-071; textos do resumo ("Customers", "Drawer", "Stolen", "Grade X bonus", "Deposited", "Gems", "No gems: away too long", "Last chance used") placeholder até `ui-text.md`; toast 4 s; dedupe de toast igual; escala `ViewportSize.Y / 540` limitada a 1..2. **Como testar:** UI Labs → `HudScreen` (Phone 667×375, Toast, Summary, Cash), `HudSummary`, `HudPill`. Studio: T039-01..07 de `tests/wave-1.md`. Verificado: `rogen build`, `modux generate`, `modux check` ok; `tools/analyze.ps1` 0 erro nos arquivos da task (6 erros restantes são de `src/Dev/server/DevService/Commands/Interact.luau`, outro agente) |
| TASK-040 | Plano de teste da onda 1 | qa-tester | TASK-001 | `docs/tests/wave-1.md` | critérios das FEAT da onda; DEC-171 (mobile + PC) | — | Feito (`tests/wave-1.md` v1; lacunas L-01..L-10 na §9, pedidos de testabilidade R1..R5 na §0.4) |
| TASK-041 | Validação integrada da onda 1 (dia completo, solo e party de 2) | qa-tester | TASK-010 a TASK-039, TASK-040, TASK-042 a TASK-046 | `docs/tests/wave-1.md` (resultado) | `tests/wave-1.md` | — | Em andamento (qa-tester, 2026-10-10). **Rodada 1 (estática) feita**, relatório em `docs/tests/wave-1-report.md`: rogen/generate/check ok, analyze 0 erro/0 ciclo, `rg InsertService src` vazio; contratos Net × Services × Controllers, ações (14 da onda 1, um dono cada), prioridades de `OnInit`, atributos do binding, snapshot e fluxo do hot dog sem quebra. **Corrigido** C-01: `ClassService:Select` com classe travada agora responde `class_locked` (`network.md` §4.6), sem commit. **Aberto:** B-01 (Média) gerados do HEAD velhos (`Modules`/`Manifest`/`default.project.json` sem 9 Services e `Item/shared`; árvore regenerada, falta commitar); B-02 sem `UpgradePiece` no binding; B-03 `Prompt_Refuse` a 1,5 stud do `Prompt_Customer`; B-05 desvios de dono (TASK-028 em `KitchenService/init`/`Rules.luau`, TASK-037 em `RoundController`); divergências de doc D-01..D-10 (`ShiftEnded(info, report)`, "Maxed"×"MAX", Notices faltando, `Stn`/`Fp` fora do `data.md`). **Falta:** smoke test em Play com 2 jogadores (§7 do relatório) e roteiro §8 do plano; nenhuma task vira `Feito` antes disso |
| TASK-042 | `DevService` + comandos de dev de turno (R1: pular para o Day N e para a próxima fase) | backend-coder | TASK-010, TASK-012 | `src/Dev/server/DevService/init.luau`, `Commands/Round.luau` | `tests/wave-1.md` §0.4 R1, L-10; `architecture.md` §1 (modo dev) | ferramenta de dev, sem DEC (só `IsDev()`) | Em QA (`src/Dev/server/DevService/` `init`, `Api`, `Commands/Round`; Priority 100, Require PlaceService. Contrato **Provisório**: cada `Commands/*.luau` devolve `Api.Module = (ctx) -> { Command }`, chamado no `OnStart`; `ctx.Get("XService")` dá o Service vivo (043–045 sem editar o init). Command Bar (Server): `require(game.ServerScriptService.server.Dev.DevService).Run("day", 4)` (cópia do Command Bar repassa por `BindableFunction` `DevBridge`); chat `/dev help`, `/dev day 6`, `/dev skip`. Resposta só no Output do servidor (Provisório). Testar: Play com IsDev → `/dev day 2` (Shift.Day = 2, Cheese liberado), `/dev skip` em Open → Closing → Summary com depósito; sem dev (`PlaceRole = "Lobby"`) não há `/dev` e `Run` dá `error`. Analyze 0 erro em `src/Dev`) |
| TASK-043 | Comando de dev: dar gemas e dinheiro da party (R2) | backend-coder | TASK-042, TASK-017, TASK-021 | `src/Dev/server/DevService/Commands/Economy.luau` | `tests/wave-1.md` §0.4 R2; TASK-017 (gemas de dev) | ferramenta de dev | Em QA — `Commands/Economy.luau`: `gems <n> [player]` (jogador por Name/DisplayName, exato ou prefixo único; sem arg = quem digitou; no Command Bar = único jogador do servidor, Provisório) e `cash <n>`; valores finitos, floor; clamp ≥ 0 e `IsDev()` ficam nos donos. Testar: `/dev gems 45` → comprar `class_rabbit`; `/dev cash 500` no HUD dos 2; `/dev cash -9999` → 0; `Run("cash", 10)` no Command Bar |
| TASK-044 | Log de dev de `Interact` descartado com motivo (R4) | backend-coder | TASK-042, TASK-011 | `src/Dev/server/DevService/Commands/Interact.luau` | `tests/wave-1.md` §0.4 R4, §3 | ferramenta de dev | Em QA — `Commands/Interact.luau` assina `InteractionService.Rejected`; buffer por (player, id, action, reason) despejado 1x/s, 1 linha por chave com ` xN` (Provisório: agregação por janela, sem linha imediata). `/dev interactlog [on\|off]` (padrão on). Testar: T011-02..07 forjados → linha com motivo; 30 `fireServer` num frame → ≤ 2 linhas (`state xN` + `rate x22`) |
| TASK-045 | Contador de tentativas de spawn de cliente por turno (R5) | backend-coder | TASK-042, TASK-032 | `src/Dev/server/DevService/Commands/Spawns.luau` | `tests/wave-1.md` §0.4 R5, T032-01/02 | ferramenta de dev | Em QA — `Commands/Spawns.luau` assina `CustomerService.SpawnAttempted` (conta também `DevSpawn`), zera no `ShiftStarted`, e no `PhaseChanged -> "Closing"` (fim do Open por timer, balcão vazio ou `skip`) imprime `[Dev] Day N: attempts X, spawned Y, skipped (queue) Z, skipped (cap) W`. `/dev spawns` mostra o turno atual + fase. Testar: Day 1 com Refuse rápido → Z = 0 e X = Y + Z + W; Counter 1 sem atender → com a fila cheia Z sobe a cada tentativa e Y não (T032-02); `/dev day 1` zera |
| TASK-046 | Pacote grátis do dia de liberação no mundo, pego por "Take" (L-03) | backend-coder | TASK-010, TASK-011, TASK-012, TASK-022, TASK-025 (só para o aceite do Restock) | `src/Item/server/ItemService/Pickup.luau` (+ registro no `ItemService/init.luau`) | DEC-071, DEC-174; FEAT-007; `tests/wave-1.md` L-03, T025-09 | **Provisório** (architect + task-planner): prompt "Take" em vez de toque nativo; ver nota N-03. **Entregue (backend-coder):** `Pickup.luau` (módulo puro) + `WirePickup` no `OnInit` do `ItemService` (Require + `InteractionService`, `RoundService`); `RegisterAction("pick_up_item")`, spawn no `ShiftStarted`, snapshot `"Fp"` (`{G,L}`). Modelo = clone do kit sem scripts/`Handle`, partes ancoradas sem toque, em `Workspace.FreePacks` (fora do `Vehicle`, para não mexer na contagem do binding), âncora `Attachment` `Prompt_Take` no topo. Cheio → `Notice` vem do `Give` (`hands_full` ou `package_limit`, como em `network.md` §7). **Provisório:** (a) Day 1 não gera pacote (kit inicial, não é liberação); (b) posição lida por tag `Station` (o `MapIndex` não indexa estações nem tem ponto de pacote grátis): topo da estação ou, em `toppings`, acima da âncora com `Ingredient`; (c) chave `"Fp"` fora de `data.md` §3.3 (architect registra). T011-07/X-09: `pick_up_item` agora é registrada, mas forjada em âncora que não é pacote continua descartada (`target`). Restock do pacote pego = Tool `pack_*` comum, depende só da TASK-025. Testar: `DevSetDay 2` → `pack_cheese` sobre a tigela do queijo; encostar não pega; "Take" com 4 Tools/2 pacotes → toast e pacote fica; pegar → Tool na mão com `Count` 6; `DevSetDay 4` direto → só `potato_sticks` | Em QA |

### Notas do retorno da TASK-040 (QA, `docs/tests/wave-1.md` §0.4 e §9)

As linhas da tabela em execução (TASK-003, 005, 006, 019) **não** foram alteradas. Mudanças em tasks ainda
`Bloqueada` estão nas seções de detalhe (marcadas "v1.1").

**Testabilidade (§0.4).** Princípio: o Service dono expõe um gancho mínimo, dentro da própria task; todo comando e
log de dev mora em `src/Dev/` (TASK-042 a 045), que nenhuma outra task toca. Assim as tasks de dev não disputam
arquivo com as de gameplay.

| Pedido | Onde fica | Gancho no Service dono |
|---|---|---|
| R1 pular dia/fase | TASK-042 | TASK-012: `DevSkipPhase()`, `DevSetDay(n)` |
| R2 gemas e dinheiro | TASK-043 | TASK-017: `DevGrantGems(player, n)` (já previsto); TASK-021: `DevAddCash(n)` |
| R3 sorteio puro | critério da TASK-033 (`OrderRoll.luau`) | — |
| R4 log de `Interact` descartado | TASK-044 | TASK-011: sinal `Rejected(player, id, action, reason)` |
| R5 contador de spawns | TASK-045 | TASK-032: sinal `SpawnAttempted(outcome)` |

**Lacunas (§9).**

- **N-01 (L-01, stash de Tools ao sair e voltar):** vai para a **onda 2** (sessão/reconexão; ver lista de ondas).
  Mínimo na onda 1, critério novo da TASK-022: Tools de quem sai somem sem erro e sem vazar instância. Q-01/Q-08 do
  plano ficam com esse resultado esperado.
- **N-02 (L-02, L-06, L-07): correção para o architect** (`docs/tech/` é dele; o planner não edita). Doc-only, pode
  rodar já, em paralelo à TASK-003 (arquivos diferentes):
  - L-02 — `network.md` §3.4 (≈ linha 186): o `PromptController` esconde "Restock" com `Amount = Capacity` (ou
    `Blocked`), **não** com `Amount = 0`. Afeta TASK-014/029.
  - L-06 — `network.md` §3.6: `Customers.PatienceEndsAt` (40 + 5K) replicado na chegada deixa o client deduzir K
    antes do "Take Order" (FEAT-011 "K oculto"). Decidir: aceitar o vazamento (baixo impacto) e registrar, ou
    replicar só depois do "Take Order" (antes disso, um valor sem K). Afeta TASK-033/034.
  - L-07 — `architecture.md` §18.4 (≈ linha 1030, linha K): trocar `board_add_topping` por `topping_add`
    (`content-data.md` v4). Afeta a checagem do binding da TASK-005.
  - L-03 — registrar a definição Provisória da N-03 em `network.md` §7 (linha "Pacote grátis") e em `content-data.md`
    (`Actions.pick_up_item`: texto, hold, raio, ativo na onda 1 só para o pacote grátis).
- **N-03 (L-03, pacote grátis sem prompt) — definição Provisória (task-planner + architect):** o pacote grátis do
  dia de liberação (DEC-071) aparece sobre a estação nova como **modelo de exibição, não `Tool`** (sem `Handle`
  tocável, logo sem pegada nativa do Roblox) e é pego pela ação `pick_up_item` com prompt **"Take"** (toque, sem
  hold). O servidor valida hotbar de 4 (DEC-174) e limite de pacotes (2, Urso 3); cheio → "Hands full" e o pacote
  fica no mundo. Dono: **TASK-046**; sai da TASK-025. Se a `Actions` da TASK-003 sair com o texto "Pick Up", a
  TASK-046 troca o texto para "Take" depois que a TASK-003 estiver `Feito` (único arquivo de `Content` que ela toca).
  O caso T025-09 do plano passa a ser da TASK-046.
- **N-04 (L-04, L-05): para o game-designer.**
  - L-04 — Raposa (gorjeta $2, janela −4 s) vale no pedido do dono (quem fez "Take Order"). Definir o que acontece se
    o dono sair antes do Serve. Recomendação Provisória até a resposta: a janela e o bônus já calculados no "Take
    Order" se mantêm (o servidor guarda no pedido, não consulta o jogador no Serve).
  - L-05 — FEAT-009 "16 ± 2 clientes no Day 1 solo": dizer se conta **tentativas** de spawn ou clientes nascidos e
    trocar "30 min simulados" por um método. Recomendação Provisória: contar tentativas (spawnado + pulado por fila
    cheia), medido com a TASK-045 em 5 Days 1.
- **N-05 (L-08):** descrição da TASK-032 corrigida (sem `Look`; aparência em atributos do rig, TASK-031).
- **N-06 (L-09):** T017-08 ("classe não muda durante a run fora do modo dev") fica **E** até a onda 2 (sem run fora
  do modo dev na onda 1). Só registro; a TASK-041 não falha por ele.
- **N-07 (L-10):** coberto pela TASK-042 (R1).

---

## Próximas paralelizáveis

O que pode começar **agora**, por agente:

| Agente | Tasks |
|---|---|
| architect | TASK-003 em andamento · **nota N-02** (correções doc-only em `docs/tech/`, outra sessão, sem conflito com a TASK-003) |
| frontend-coder | TASK-019 em QA · nada novo pronto (TASK-014/015/023/024/029/037 esperam TASK-004/005/007) |
| backend-coder | — (espera TASK-003/TASK-004) |
| level-designer, modeler-3d | TASK-005 e TASK-006 (já com dono) |
| game-designer | **nota N-04** (L-04, L-05) |

### Ordem recomendada (etapas)

Cada etapa abre quando as dependências da anterior fecham. Dentro da etapa, tudo é paralelo.

| Etapa | architect | backend-coder | frontend-coder | outros |
|---|---|---|---|---|
| E0 (agora) | 001, 002 | — | 013 | — |
| E1 | 003 | — | 019 | level-designer 005 · modeler-3d 006 · qa-tester 040 |
| E2 | 004 | 008, 009 | (013 se não terminou) | modeler-3d 007 (depois da 006) |
| E3 | — | 010, 011, 016, 017 | 014, 015, 023, 024, 029, 037 | — |
| E4 | — | 012, 018, 022, 031 | 020, 030, 034, 038, 039 | — |
| E5 | — | 021, 025, 032, 042 | — | — |
| E6 | — | 026, 028, 033, 035, 043, 044, 045, 046 | — | — |
| E7 | — | 027, 036 | — | — |
| E8 | — | — | — | qa-tester 041 |

- **Caminho crítico:** 001 → 003 → 004 → 011 → 022 → 025 → 026 → 027 (montagem completa do hot dog) e
  006 → 016 → 031 → 032 → 033 (cliente que paga). Backend tem 19 tasks contra 13 do frontend: rode **2 ou 3 sessões
  de backend-coder** em paralelo a partir da E3 (as tasks de cada etapa não compartilham arquivo).
- v1.1: TASK-042 a 046 ficam fora do caminho crítico. 043/044/045 são arquivos separados em
  `DevService/Commands/` (descobertos pelo `init` da 042) e podem rodar juntas. A TASK-046 toca `ItemService/init.luau`
  só para registrar o `Pickup.luau`: não roda em paralelo com outra task no `ItemService`. A TASK-044 pode ser
  antecipada para logo depois da 042 (só precisa da 011); vale começar cedo para servir de apoio aos testes de §3.
- Frontend fica à frente a partir da E3: tudo dele lê sets e atributos do contrato (TASK-001/002), então pode ser
  feito e testado com dados de story (UI Labs) antes do backend fechar.

---

## Detalhe das tasks (critérios de aceite)

### TASK-001 — Contratos de rede, conteúdo e dados da onda 1
Atualizar `network.md`, `content-data.md` e `data.md` (v4) para o estado DEC-140 a DEC-193 **no escopo do núcleo**:
- `network.md`: schema final de `Shift`, `RunState`, `Economy`, `Stock`, `Stations`, `Customers`, `Upgrades`,
  `Interact`, `Notice`, `Sale`, `ShiftReport`, `Profile`, `ClassAction`. `Stations` cobre a **tábua de 2 vagas
  compartilhadas** (DEC-190: 2 registros ou slot no registro, decidir) e tigela bloqueada (`Blocked`, DEC-156);
  `Customers.Look` cobre espécie + roupa civil A–H + acessório (DEC-188) e pack Day/Mid (DEC-181); `Customers.Mood`
  serve à versão simplificada da onda 1 (Q-164). Diz explicitamente que `Round`, `Vitals` antigos ficam até a onda 2.
- `content-data.md`: `HotbarSlots` = 4 (DEC-174); `Classes` com campo `Species` e 6 `InMvp` (DEC-186; chaves estáveis
  decididas aqui); tabela nova `Species` (DEC-158/188, guaxinim não jogável); `Upgrades` com nível **por veículo**
  (DEC-184); `Ingredients.Icon` (DEC-156); `Stations` com as chaves da linha do carrinho (MAP-01 §7.1); atributo de
  Tool `Toppings` do HotDog; `Flow.PartySource = "Connected"` (DEC-185).
- `data.md`: Template v1 confirmado (Gems, Classes, SelectedClass com as chaves novas).
- Aceite: toda entrada de `Net/init.luau` da onda 1 tem schema, escritor, leitor e frequência; cada mudança cita a DEC;
  item Provisório marcado como tal; nenhuma entrada usa `keyBy` (T14).
- **Entrega (architect, 2026-10-10):** `network.md` v4, `content-data.md` v4, `data.md` v4. Decisões que mudam a
  descrição de outras tasks (o planner ajusta o texto delas): (1) tábua = 2 registros `Kind = board` + prompt único
  na tábua (`network.md` §3.5); (2) bloqueio de ingrediente = `Stock.Blocked` (tigela, Mart e pedido), não estado de
  `Stations` (TASK-028/029/037); (3) aparência de NPC em **atributos do rig** (`Species`, `Outfit`, `CustomerType`,
  `LookPack`, `NpcId`), fora do set `Customers` (TASK-031/032/034); (4) textura e rosto vestidos **no client** a partir
  dos atributos (T40, `network.md` §5; diverge da T35 do `architecture.md` §18.9.4 → TASK-016/018/031/034); (5) chaves
  de classe por animal `class_dog`… (TASK-004/009/017/020); (6) chaves de `Stations` e ids alinhados ao §18 da TASK-002.
  Novo Provisório: `Vehicles.trailer.BoardSlots = 3` × DEC-190 (2 vagas, sem citar veículo) → game-designer.

### TASK-002 — Contrato de binding do MAP-01, kits de asset e layout de módulos
Seção nova em `architecture.md`:
- **Binding do mapa:** tags `CollectionService` e atributos que o código lê (`EntityId`, `StationKind`, `Slot`,
  `Ingredient`, `PromptAction`, `PromptHold`), nomes de pontos (`PS-1..4`, `Q1..Q5`, `D1`, `SP-A`, `EX-E`, `OP-1`,
  prateleiras, `B1..B5`, `S1`), formato do grafo `NpcNode`. Usa os `Prompt_*`/`Att_*` que já existem nos modelos
  colocados por `MAP-01_placements.luau`.
- **Kits de asset:** `ReplicatedStorage.Assets.Crew`, `ReplicatedStorage.CrewExpressions`, `ReplicatedStorage.Assets.Items`
  (pastas, nomes, atributos como `TopHeight` nas coberturas); proibido `InsertService` em runtime.
- **Layout de módulos:** onde ficam módulos que não são Service/Controller (`<Service>/init.luau` + filhos, como
  `ProfileService/Template.luau`; `src/<Feature>/shared/`), o contrato `KitchenService/Stations/*.luau` (interface de
  estação descoberta pelo init) e `CustomerService/*.luau`.
- Aceite: level-designer, modeler-3d e coders conseguem trabalhar só com esta seção; nenhum nome conflita com o
  `MAP-01.md`; seção marcada Provisória onde depende de Q-130/Q-153.

### TASK-003 — `Content`: scaffold + tabelas que geram enum
- `Table.luau` (`Table.new` → `List`, `Keys`, `ByKey`, `IndexOf`, congelado), `Validate.luau` (regras de
  `content-data.md` §1.4), `init.luau` reexportando **todas** as tabelas da onda 1.
- Completas: `Ingredients`, `Packages`, `Items` (inclui `hot_dog` e os 9 pacotes; `revive_kit` só como linha), `Stations`,
  `Actions` (textos e holds de FEAT-005), `Notices` (chaves da onda 1).
- Stubs tipados com `Keys` corretas (valores na TASK-008/009): `Classes`, `Shift`, `Upgrades`, `Vehicles`, `RunParams`,
  `Flow`, `Orders`, `CustomerTypes`, `Species`, `OpalLines`.
- Aceite: `require(ReplicatedStorage.shared.Content)` roda `Validate()` sem erro em < 1 ms; chave duplicada ou
  referência quebrada faz `error` com tabela e linha; nenhum `require` de Lync/Vide/`self.Libs`; analyze zero erro.

### TASK-004 — Net v1 do núcleo + Template do perfil
- `src/Libs/Net/init.luau` com as entradas da TASK-001; `Round` e `Vitals` antigos **mantidos** (remoção na onda 2,
  com `VitalService`/`RoundController` novos). Enums gerados de `Content` (T13).
- `Template.luau` = `data.md` §1.1 (sem Coins/Level/Playtime); `ProfileService` replica o `Profile` novo;
  `ProfileController` expõe os campos como sources.
- Aceite: analyze e `modux check` zero erro; boot no Studio sem erro de `Lync.start()`; jogador novo recebe `Profile`
  com `Classes = { class do Cachorro }` e `Gems = 0`; `RoundService`/`VitalService` atuais continuam compilando.

### TASK-005 — Binding do MAP-01 no place
- Taguear/atribuir no place, conforme TASK-002: estações do carrinho (estoque S, grelha G com vagas do nível 1, trilho
  R, pães B, **tábua T com 2 vagas**, 6 tigelas K, entrega/POS + gaveta, lixeira BIN-C, placa OPEN), Q1–Q5, PS-1..4,
  D1/SP-A/EX-E com grafo `NpcNode` até Q1, 9 pontos de compra do Mart, B1–B5 e S1 da bancada, OP-1.
- Aceite: script de checagem (ou checklist) lista 0 tag faltando; distâncias de prompt ≥ 2,5 studs (MAP-01 §7);
  bancada do carrinho a 3,0 (DEC-157); nenhum nó do grafo atravessa pista fora de faixa.

### TASK-006 — Kit de personagem no place + `CrewLooks`
- Importar para `ReplicatedStorage.Assets.Crew`: `AST-053_CrewTex`, `AST-053_CrewBase`, `AST-053_CivilArms`, as 18
  espécies (`AST-053_Animal_<A>`), bonés (normal e `EarsUp`), `AST-053_ThiefHat`, acessórios de cliente que existirem;
  `ReplicatedStorage.CrewExpressions` com uma `SurfaceAppearance` por expressão (Normal, Happy, Smiling, Sad, Fainted,
  Skeptical, Exhausted, Stressed, `Normal_Night`, `_Night` que houver).
- `src/Crew/shared/CrewLooks.luau`: ids de textura `T_*` (Day/Mid/Night por espécie e por roupa, atlas Mid/Night).
- Aceite: todo id citado em `CrewLooks` existe; nada carrega por `InsertService`; uma montagem de teste por espécie
  em Day/Mid/Night sem peça faltando.

### TASK-007 — Kit de itens e comida no place
- `ReplicatedStorage.Assets.Items`: Tool `HotDog` (AST-003, `Att_Topping1..3`, grip na mão R6), coberturas AST-004 a
  009 com atributo `TopHeight` medido (DEC-142), salsicha crua/grelhada (AST-002), pão aberto/fechado (AST-001),
  9 Tools de pacote (AST-011).
- Aceite: cada cobertura tem `TopHeight`; o HotDog equipado aparece na mão do rig da crew; tris dentro das fichas.

### TASK-008 — Conteúdo: turno, upgrades, veículos, fluxo e pedidos
- `Shift` (fases de dia de FEAT-003: Prep 60 s 7→8, Open 360 s 8→18, Closing ≤ 30 s, Summary 15 s; fases de noite
  só como chave), `RunParams` (StartCash 30, estoque cheio, `PartyPriceMult`), `Upgrades` (UPG-001 a 005 com níveis,
  preços, efeitos, `Part`; nível por veículo), `Vehicles` (`cart`, `trailer`), `Flow` (22 s, 0,08/dia até 0,40,
  `PartyMult`, teto 8 clientes de dia), `Orders` (`OrderPhases` e `OrderRules` de FEAT-010/011).
- Aceite: todo número tem a DEC/FEAT de origem em comentário; `Validate()` passa; mudar um número não exige código.
- **Entrega (backend-coder, 2026-10-10):** `Shift`, `RunParams`, `Upgrades`, `Vehicles`, `Flow`, `Orders` revisados
  contra FEAT-003/009/010/011/014/015, `upgrades.md` e DEC-045/046/048/050/051/071/072/184/185/190/201/215; nenhum
  campo novo (forma da `content-data.md` v4.1). Valores dos stubs conferidos (nenhum número mudou); cada número com
  origem em comentário. `Upgrades`: linhas `cart` e `trailer` escritas em separado (preço do trailer = só número;
  Provisório `Q-163` a/c marcado por linha). Fora do schema, para o architect na onda 2: intervalo de noite do FEAT-009
  (40 s / 36 s), Preparação de noite 90 s e Resumo de noite 20 s (FEAT-003/014) não cabem em `Flow`/`Shift` atuais.
  Como testar: `require(ReplicatedStorage.shared.Content)` sem erro; `Content.Upgrades.ByKey.grill.Levels.trailer[2].Price`
  = 60; `Content.Vehicles.ByKey.trailer.BoardSlots` = 3; `Content.Flow.BaseInterval` = 22; `Content.Shift.ByKey.Open.Duration`
  = 360. Verificações: `rogen build`, `modux generate`, `modux check` ok; `tools/analyze.ps1` 0 erro.

### TASK-009 — Conteúdo: classes, espécies, tipos de cliente, falas da Opal
- `Classes`: CLS-001 a 006 `InMvp = true` e 007/008 `false`, espécie, tier, preço (0/45/45/45/120/120/180), efeitos
  da DEC-069/186. `Species`: 18 espécies, `Playable` (6), raccoon só Quentin. `CustomerTypes`: NPC-001 a 006 com
  espécies e acessórios da DEC-188 (+ porco como cliente, DEC-192, a confirmar). `OpalLines`: fases Day/N1_3/N4_6/N7_10.
- Aceite: `Validate()` recusa classe com `Stat` fora da lista fechada; nenhuma classe jogável usa o guaxinim.

### TASK-010 — `Place` + `RunState` mínimo
- `PlaceService`/`PlaceController`: `Is("Run")`, `IsDev()` (atributo `Workspace.PlaceRole`).
- `RunStateService`: roster de dev (quem entra), `Members` (classe, `EverJoined`), set `RunState`, `Notify(player|all,
  key, value)` → packet `Notice` pelo `NetService.Audience`, `RegisterSnapshot(name, capture, restore)` guardando em
  memória (MemoryStore na onda 2).
- Aceite: 2 jogadores no Studio aparecem em `Members`; `Notify` chega só a quem deve; Service fora do papel retorna no
  topo do `OnInit`.

### TASK-011 — `InteractionService`
- Único responder de `Interact`; registro `EntityId ↔ Instance` pelas tags da TASK-002;
  `RegisterAction(key, { Validate, Run })` chamado por outros Services no `OnInit`; valida membro ativo, distância
  (raio da tabela + folga), taxa ≤ 8/s, requisitos (ex.: Tool na mão); atributos `PromptEnabled`/`PromptText` mantidos
  pelo servidor.
- Aceite: `Interact` com `EntityId` inexistente, fora do raio ou acima da taxa é descartado sem erro; duas ações no
  mesmo alvo no mesmo frame são serializadas (base do critério "só um recebe" da FEAT-006).
- v1.1 (R4): sinal `Rejected(player, entityId, action, reason)` com `reason` ∈ `rate`, `range`, `target`, `state`
  disparado em todo descarte; o log fica na TASK-044. Aceite extra: cada um dos 4 motivos dispara o sinal uma vez por
  pacote descartado.

### TASK-012 — `RoundService`: turno de dia
- Reescreve o exemplo: fases de `Content.Shift` em atom Charm, set `Shift` por `effect` no `OnStart`, relógio por
  `PhaseStartedAt/ClockFrom/ClockTo`, `Day` crescente, sinais `PhaseChanged`, `ShiftStarted`, `ShiftEnded`; ação
  `open_sign` ("Open Shop", qualquer jogador, só na Preparação); Fechamento termina com balcão vazio ou 30 s.
- Aceite: FEAT-003 (nenhum cliente antes de 8:00 AM nem depois de 6:00 PM; CLOSED às 6:00 e fim em ≤ 30 s; horário igual
  para todos; relógio não pausa com jogador fora). Depois do Summary do Day N começa o Day N+1 (sem noite nesta onda).
- v1.1 (R1): ganchos `DevSkipPhase()` (encerra a fase atual **pelo mesmo caminho** do fim do tempo: Fechamento,
  Summary e sinais rodam normalmente) e `DevSetDay(n)` (vai para a Preparação do Day N disparando `ShiftStarted` como
  na troca natural). Os dois fazem `error` se `PlaceService:IsDev()` for falso. Os comandos ficam na TASK-042.

### TASK-013 — Componentes de Interface
- Porte de `CookInterface` → `ProgressBar`, `PromptInterface` → `PromptBillboard` (Hidden/Indicator/Prompt, fill do
  hold), `UseTween`, `Toast` (canto superior direito, 3–6 s), cada um com story no UI Labs.
- Aceite: componentes puros (só props), sem `require` de Controller; stories abrem sem erro; analyze zero erro.
- **Entrega (frontend-coder, 2026-10-10):** `Components/ProgressBar` (`init` = BillboardGui, `Bar` = corpo 2D),
  `Components/PromptBillboard`, `Components/Toast` (`init` = cartão, `Stack` = coluna no canto superior direito, fila
  de até 3), `Components/UseTween`, `Components/Theme` (tokens do style guide §2/§7). Analyze em `*Interface*`: 0 erro.
  Como testar: UI Labs → storybook "ModuxTemplate" → `ProgressBar` (slider, Auto, Thief, InWorld: barra numa peça 8
  studs à frente da câmera), `PromptBillboard` (State/KeyLabel/Holding/HoldDuration; prévia no viewport 3D), `Toast`
  (botão "Push toast" e Auto), `UseTween` (AtEnd, Duration). Toque na pílula do prompt só chega a `OnPress/OnRelease`
  em play test, com o BillboardGui sob `PlayerGui` (TASK-014).

### TASK-014 — `PromptController` + `Prompt`
- Porte do AnimalPlane sem `PlaneController`; alvo = prompt mais próximo do centro da tela com histerese; hold pela
  duração do atributo; dispara `Interact{Id, Action}`; teclas por `InputController:Bind` (E no PC, botão fixo no mobile);
  um prompt visível por vez.
- Aceite: FEAT-005 (toda ação executável no mobile só com interagir, hotbar e câmera; prompt com `PromptEnabled = false`
  não aparece); soltar antes do fim do hold não dispara.

### TASK-015 — `RoundController`
- Lê `Shift` → sources Vide `Day`, `Phase`, `ClockText` ("8:00 AM", passo de 10 min, DEC-048), `IsNight`.
- Aceite: relógio local bate com o do servidor (≤ 1 passo de diferença); reconectar mostra a fase atual sem esperar
  troca de fase.

### TASK-016 — `CrewRig`
- Versão de produção de `build_crew.luau` (`architecture.md` §18.9.2, T40 de `network.md` §5): `Build(species, outfit,
  opts)` **no servidor**, a partir dos kits (sem `InsertService`): geometria, acessórios por tipo de cliente, tag
  `AnimalRig`, atributos `Species`, `Outfit`, `CustomerType`, `LookPack` (peças no pack Day do kit). `Dress(model, pack,
  expression)` **no client** (equivalente de `Crew.applyTime` + `setExpression`: `TextureID` por `CrewLooks`, atlas,
  `SurfaceAppearance` do rosto) + o Controller que veste todo `AnimalRig` ao aparecer e quando um atributo muda. O
  servidor nunca escreve `TextureID`/`SurfaceAppearance`.
- Aceite: monta as 18 espécies com roupa `crew` e `civil_a`..`civil_h`; trocar `LookPack` no servidor re-veste em todos
  os clients sem recriar o modelo; troca local (Night) não é desfeita por escrita do servidor; sem vazamento de
  instâncias (teste de 200 montagens/destroys).
- **Entrega (backend-coder, 2026-10-10):** `src/Crew/shared/CrewRig/` (`init`, `Kit`, `Build`, `Dress`) +
  `src/Crew/client/RigController.luau` (Priority 680, o Controller único do §18.9.2). API: `CrewRig.Build(species,
  outfit, { CustomerType?, Accessories?, Cap?, Hat?, LookPack?, Name?, CFrame?, Anchored?, Tag? }) -> Model`
  (servidor; tag `AnimalRig`, atributos `Species`/`Outfit`/`CustomerType`/`LookPack`, `ModelStreamingMode = Atomic`);
  `CrewRig.Dress(model, pack?, expression?) -> boolean` (só client em jogo; `error` se chamado no servidor rodando);
  `CrewRig.PackForSanity(value, { High, Mid })` (faixas vêm de `Content.Sanity`, onda 2); `RigController:SetExpression
  (model, name?)` (rosto local: humor da TASK-034, Thief/médicos na onda 2) e `:Refresh(model?)`. Braços civis e sem
  avental por `Outfits.Arms = "Civil"`; boné por `Outfits.Use = "Crew"` (ou `opts.Cap`); chapéu só por `opts.Hat`
  (`"ThiefHat"` passado pelo chamador). Camada local §5.3: personagem local com `LookPack = "Night"` → NPCs (menos
  `Use = "Reserved"`) em Night + `Normal_Night`. **Provisórios:** (1) o `Build` grava a folha **Day da roupa** e a cor
  da pelagem durante a montagem (o kit só tem as folhas crew/civil_a), leitura de "nunca escreve TextureID *depois* da
  montagem" (`network.md` §5.1); (2) acessório soldado ao R6 do atributo `Anchor` da peça ou, sem ele, à peça R6 mais
  próxima na pose de repouso (AST-054 não existe; acessório faltando = aviso único, rig segue); (3) máscara dos médicos
  (DEC-213) = `opts.Accessories` + `SetExpression("Exhausted")` quando a peça e a roupa de paramédico existirem
  (art-director decide acessório × textura); (4) `PreloadAsync` dos 3 packs por espécie/roupa ao aparecer pela 1ª vez.
  Verificações: `rogen build`, `modux generate`, `modux check` ok; `tools/analyze.ps1` 0 erro em `*Crew*` (4 erros
  atuais em `src/Market`, de outra task); nenhum `InsertService` em `src/`.
  Como testar (Play Solo, Command Bar do **servidor**): `local R = require(game.ReplicatedStorage.shared.Crew.CrewRig);
  local C = require(game.ReplicatedStorage.shared.Content); local f = Instance.new("Folder", workspace); f.Name = "RigTest";
  for i, s in C.Species.Keys do for j, o in { "crew", "civil_a", "civil_b", "civil_c", "civil_d", "civil_e", "civil_f",
  "civil_g", "civil_h" } do R.Build(s, o, { Anchored = true, CFrame = CFrame.new(i * 5, 3, j * 7) }).Parent = f end end`
  → 162 rigs completos, client veste (civil com braço reto e sem avental; orelha em pé com boné furado só na crew).
  Re-vestir: `for _, m in f:GetChildren() do m:SetAttribute("LookPack", "Mid") end` → todos os clients trocam sem
  recriar. Troca local: no Command Bar do **client**, `game.Players.LocalPlayer.Character:SetAttribute("LookPack",
  "Night")` com rigs `civil_*` → só esse client vê Night + `Normal_Night`; depois, no servidor, `LookPack = "Day"` nos
  rigs não desfaz o Night local. Vazamento: `for k = 1, 200 do R.Build("dog", "civil_a").Parent = f; f:ClearAllChildren()
  end` e conferir `#game:GetService("CollectionService"):GetTagged("AnimalRig")` e a memória (Instances) estáveis.

### TASK-017 — `ClassService`
- Lê/escreve `Classes`, `SelectedClass`, `Gems` no perfil (cópia, não mutação); `ClassAction{Buy|Select}` validado
  (gemas, `InMvp`, já possui); `GetClass(player)` travada na run; `GetModifier(player, stat)` para `WalkSpeed`,
  `GrillTime`, `PackageLimit`, `TipAmount`, `TipWindow`.
- Provisório: no Run em modo dev, `Select` permitido antes do spawn e um comando de dev dá gemas (sem `RewardService`
  nesta onda).
- Aceite: conta nova = Cachorro; comprar sem gemas falha; classe não muda durante a run fora do modo dev (este último
  fica **E** até a onda 2, nota N-06).
- v1.1 (R2): o comando de dev de gemas é o gancho `DevGrantGems(player, n)` (só `IsDev()`); a entrada de comando
  fica na TASK-043.

### TASK-018 — `CharacterService`
- `CharacterAutoLoads = false`; spawn em `PS-1..4` com `CrewRig` (espécie da classe, uniforme Crew, pack Day, rosto
  Normal); Humanoid R6, `BreakJointsOnDeath = false`; grupo `Players` sem colisão com `Players` (DEC-175, mapa todo);
  `WalkSpeed` pelo modificador da classe; atributos `Species`, `Outfit = "crew"`, `LookPack = "Day"` no personagem
  (o servidor só escreve atributos; quem veste é o client, T40, `architecture.md` §18.9.4).
- Aceite: 2 jogadores com espécies diferentes se veem com o animal certo; atravessam um ao outro; Coelho anda a 18 e
  Cachorro a 16; nenhum avatar do Roblox aparece.

### TASK-019 — `CameraController`
- `LockFirstPerson`; cabeça, boné, orelhas e acessórios do próprio personagem com `LocalTransparencyModifier = 1`; a Tool
  aparece na mão (DEC-097).
- Aceite: em 1ª pessoa nenhuma peça do próprio rosto/orelha tapa a visão; colegas veem o personagem completo; PC e mobile.

### TASK-020 — Tela "Crew"
- `ClassController` + UI Vide: 6 animais (DEC-186), preço em gemas, estado bloqueado/desbloqueado/selecionado, Buy e
  Select por `ClassAction`, prévia em `ViewportFrame` com `CrewRig`. Guaxinim, Panda e Leão não aparecem como jogáveis
  (Panda/Leão podem aparecer como "coming soon" só se o game-designer pedir).
- Aceite: refletir o `Profile` em ≤ 1 s após compra; botão Buy desabilitado sem gemas; funciona em mobile.

### TASK-021 — `EconomyService`
- Dono único de `Cash` (inicia em 30) e `Drawer`; `Spend(amount): boolean` atômico; `AddToDrawer(amount, kind)`;
  ledger do turno (servidos, completos, gorjetas, roubado = 0 nesta onda); no Summary: nota A–D (DEC-051), bônus
  floor(gaveta × %), depósito, `ShiftReport` ao grupo, gaveta zera; snapshot registrado.
- Aceite: FEAT-012 (dinheiro da party não muda com venda durante o turno); FEAT-014 (bônus inteiro; sem cliente = C);
  duas compras simultâneas nunca deixam `Cash` negativo.
- v1.1 (R2): gancho `DevAddCash(n)` (só `IsDev()`; `n` pode ser negativo, nunca deixa `Cash` < 0); comando na
  TASK-043.

### TASK-022 — `ItemService`
- `Give/Consume/GetHeld/Count`; máximo **4 Tools** (DEC-174) e 2 pacotes (3 com a classe do Urso); `Count` em atributo;
  Tool `HotDog` com atributo `Toppings` e visual por `HotDogVisual`; "Hands full" por `Notice`.
- Aceite: FEAT-005 (5º Tool bloqueado com aviso); pacote com sobra mantém `Count`; HotDog criado pelo servidor aparece
  na mão de quem tocou.
- v1.1 (L-01, nota N-01): o stash (`data.md` §2.3) é da onda 2. Aceite extra: jogador que sai com Tools (HotDog,
  pacote pela metade) não gera erro; as Tools somem e nada fica referenciado no `ItemService` (sem vazamento).
- v1.1 (L-03): `Give` e a checagem "cabe na hotbar / no limite de pacotes" ficam públicas (`CanGive(player, item)`)
  para a TASK-046.

### TASK-023 — `HotDogVisual`
- Módulo compartilhado (chamado pelo `ItemService` no servidor): coloca as coberturas pela `TopHeight` real, **queijo
  sempre antes dos cordões** (Ketchup, Mustard, Cream Cheese), o resto na ordem de montagem.
- Aceite: critério da DEC-142 (qualquer combinação de até 3, vista de cima e na mão em 1ª pessoa: nada atravessa,
  nenhum molho some sob o queijo, nenhum cordão flutua).

### TASK-024 — `EconomyController` + gaveta no mundo
- Sources `Cash`, `Drawer`; BillboardGui do valor da gaveta na POS (igual para todos); "+$N" flutuante na gaveta no
  `Sale`.
- Aceite: valor da gaveta igual para todos (FEAT-012); funciona com o modelo antigo e com a POS nova (DEC-155).

### TASK-025 — `KitchenService` núcleo + estoque
- Registro de estações pelas tags; carrega `Stations/*.luau` (interface da TASK-002); estoque por ingrediente em atom,
  capacidade pelo nível de Cooler **do veículo atual** (DEC-184), set `Stock`; ação `restock` (hold 1 s, pacote na mão,
  transfere min(sobra, capacidade − atual), pacote vazio some); snapshot. **v1.1:** o pacote grátis do dia de
  liberação (DEC-071) saiu desta task e foi para a TASK-046 (nota N-03).
- Aceite: FEAT-007 (Restock nunca passa da capacidade; upgrade de Cooler aumenta capacidade sem mudar o atual; estoque
  do Day N+1 = fim do Day N).

### TASK-026 — Grelha + trilho
- "Grill" (toque) consome 1 salsicha para uma vaga livre; tempo 12/10/8 s por nível; Gato (Line Cook) 0,85× só nas
  dele; "Collect" leva ao trilho FIFO (6 no carrinho); registros em `Stations`.
- Aceite: FEAT-006 (sem vaga ou estoque 0 não grelha; estoque cai exatamente 1; barra ±0,2 s do nível).

### TASK-027 — Pão + tábua de 2 vagas
- "Slice Bun" (hold 0,5 s) consome 1 pão para uma das **2 vagas compartilhadas** (DEC-190), corte 1,5 s; "Add Sausage"
  com trilho ≥ 1 e pão cortado vira Tool `HotDog` na mão de quem tocou e libera a vaga.
- Aceite: dois jogadores na mesma vaga no mesmo instante: só um recebe o HotDog (FEAT-006); hotbar cheia bloqueia "Add
  Sausage" com "Hands full".

### TASK-028 — Complementos + lixeira
- "Add {item}" (hold 1 s) com HotDog na mão: consome 1 uso, não repete, máximo pelo pedido de 3; tigela de ingrediente
  não liberado fica `Blocked` (tampa + cadeado, DEC-156); "Throw Away" (hold 0,5 s) descarta o HotDog.
- Aceite: FEAT-006 ("Add X" não aparece para complemento já presente nem com estoque 0); bloqueio some no dia de
  liberação.

### TASK-029 — `KitchenController` núcleo + estoque visual
- Contador "7/12" por estação (vermelho com ≤ 2); `Fill` das garrafas e tigelas proporcional ao estoque com tween curto
  (DEC-140); `SurfaceGui` + `ImageLabel` na `Label_<Ing>` (DEC-156); tampa/cadeado conforme `Blocked`.
- Aceite: contadores iguais para todos; `Fill` acompanha Restock e consumo; ícone placeholder até `Q-152`.

### TASK-030 — Visuais de grelha, trilho e tábua
- Salsicha por vaga (crua → grelhada no fim), `ProgressBar` por `StartedAt/Duration`, salsichas no trilho, pão nas 2
  vagas da tábua (inteiro → cortado).
- Aceite: barra termina junto com o "Ready" do servidor (±0,2 s); quem reconecta vê o estado atual das vagas.

### TASK-031 — `NpcService` mínimo
- Pool ≤ 12 (Opal fora, DEC-191); cliente montado por `CrewRig.Build` com espécie do tipo, roupa `civil_*` sorteada,
  acessório; o servidor só escreve atributos (`Species`, `Outfit`, `CustomerType`, `LookPack` Day de dia / Mid à noite,
  DEC-181; `NpcId` novo a cada spawn) e cria as âncoras `Prompt_Customer`/`Prompt_Refuse` (`architecture.md` §18.4);
  o client veste (T40); `MoveTo` por A* no grafo `NpcNode`; grupo `Npc` sem colisão com
  `Players`/`Npc`; spawn em D1 e SP-A (sem trânsito nesta onda).
- Aceite: nunca mais de 12 NPCs de servidor; nenhum NPC usa o uniforme da crew nem o guaxinim; pool reaproveita rigs
  (sem crescer em 30 min de soak).

### TASK-032 — `CustomerService`: fluxo e fila
- Intervalo base 22 s ×crescimento ×`PartyMult` pelos **conectados** (DEC-185) recalculado no `ShiftStarted`
  (Provisório), ±25%; só na fase Open; vagas Q1..Q3/Q4/Q5 pelo Counter; fila cheia pula o spawn; avança até Q1; saída
  EX-E/D1; set `Customers` (`State`, `Slot`, `PatienceEndsAt`, `Mood`; `Order` pela TASK-033) com id = `NpcId`
  (`network.md` §3.6). **v1.1 (L-08):** sem `Look`; a aparência é atributo do rig, escrita pelo `NpcService`
  (TASK-031, `network.md` §5.2).
- v1.1 (R5): sinal `SpawnAttempted(outcome)` com `outcome` ∈ `spawned`, `skipped_queue_full`, `skipped_npc_cap` a
  cada tentativa de spawn; o contador fica na TASK-045.
- Aceite: FEAT-009 (16 ± 2 clientes no Day 1 solo; fila cheia não gera cliente; ≤ 12 NPCs). A métrica do "16 ± 2"
  (tentativas ou nascidos) está com o game-designer (nota N-04, L-05); até a resposta, vale contar tentativas.

### TASK-033 — Pedido, atendimento e pagamento
- K por `OrderPhases`, pesos × tipo × 1,5 no dia de liberação, ≤ 3, só liberados; paciência 40 + 5K (+Counter) desde a
  chegada; "Take Order" abre a janela de gorjeta 16 + 4K (Raposa −4 s); "Serve" valida Completo / Incompleto (50%) /
  Errado (HotDog volta) e paga na gaveta; "Refuse" (hold 1 s); `Sale` ao grupo; ledger.
- Humor (Provisório, Q-164): `Mood` só visual (Neutral → Annoyed com a paciência; Happy em Completo), **sem** mexer no
  pagamento da DEC-072 até o desenho do game-designer.
- Aceite: FEAT-010 (sem ingrediente não liberado, sem repetição, ≤ 3, distribuição de K ±3 p.p. em 1.000 sorteios);
  FEAT-011 (Serve só com pedido anotado; gorjeta nunca fora da janela nem em incompleto; client não manda preço).
- v1.1 (R3): o sorteio do pedido fica em `CustomerService/OrderRoll.luau`, função pura
  `Roll(day: number, customerType: string, rng: Random): { string }` (chaves de ingrediente). Só `require` de
  `Content`; sem estado, sem Service, sem rede, sem `math.random` global. Aceite extra: com o mesmo `Random.new(seed)`
  devolve o mesmo pedido; 1.000 chamadas pelo Command Bar (visão Server) rodam em < 50 ms; `Orders.luau` usa só
  essa função para sortear.
- v1.1 (L-04): se o dono do pedido (quem fez "Take Order") sair antes do Serve, vale a janela e o bônus já guardados
  no pedido no "Take Order" (Provisório até o game-designer, nota N-04).

### TASK-034 — `CustomerController`
- Balão com ícones do pedido (bitfield) visível para a party; rosto por `Mood` via `CrewRig.Dress` no client
  (Normal, Happy, Skeptical, Stressed; T40, `network.md` §5.3), achando o rig pelo `NpcId`; reação ao `Sale` (balão feliz/neutro/reclamação).
- Aceite: balão aparece só depois do "Take Order"; ≤ 8 balões; ícone placeholder até `Q-152`.

### TASK-035 — `UpgradeService`
- Nível por upgrade **por veículo** (DEC-184; nesta onda só `cart`); set `Upgrades` do veículo atual; `GetEffect(stat)`
  (GrillSlots, GrillTime, StockCapacityLevel, QueueSize, PatienceBonus, DrawerOpenTime/StealPct); `Buy(key)` por
  `EconomyService:Spend`; troca a peça visível (DEC-052); "Grill upgraded!" para a party.
- Aceite: FEAT-015 (efeito imediato; peça muda para todos em ≤ 1 s; sem prompt de compra no equipamento).

### TASK-036 — `MarketService`
- Prateleiras: `buy_package` hold 0,5 s, preço da tabela, `Spend`, Tool na mão, limite de pacotes; ingrediente não
  liberado = **"Out of stock"** sem compra (DEC-180); Coffee só depois do trailer.
- Bancada: B1–B4 sempre à venda (DEC-106), B5 "Trailer only", `bench_buy_upgrade` hold 1,5 s → `UpgradeService`,
  "Maxed" sem prompt; S1 = "Nothing special today" (sorteio na onda 4).
- Aceite: FEAT-008 (sem saldo não compra; party nunca negativa; frutas/verduras sem prompt); FEAT-015 (B1–B4 em 100% dos
  turnos).

### TASK-037 — `MarketController`
- Billboards de preço nas prateleiras; etiqueta "Out of stock" (+ "Day N" Provisório); bancada com miniatura, nível,
  preço, efeito em 1 linha, "Maxed", "Trailer only"; S1 "Nothing special today". Sem UI de loja em tela (DEC-015).
- Aceite: preço em vermelho sem saldo; etiqueta some no dia de liberação.

### TASK-038 — Opal local
- Modelo da Opal (espécie Provisória, Q-160) montado no client por `CrewRig`, ancorado, `AnimationController`, idle;
  balão de fala de `OpalLines` pela fase ao entrar a 8 studs do caixa, 1× por visita. Zero rede.
- Aceite: não conta no teto de NPC; nunca recebe anomalia (DEC-191); fala muda entre dia e noite.

### TASK-039 — `HudController` básico
- Relógio, "Day N", dinheiro da party, toasts de `Notice`, tela de resumo do `ShiftReport` (some sozinha, 15 s).
- Aceite: FEAT-032 (nenhum elemento clicável para jogador ativo; sem reputação, chances, XP); sanidade não aparece de dia.

### TASK-040 — Plano de teste da onda 1
- `docs/tests/wave-1.md`: casos por critério de aceite das tasks acima, com 1 e 2 jogadores, PC e mobile (DEC-171).

### TASK-041 — Validação integrada da onda 1
- No Studio (modo dev), solo e party de 2: spawn como animal da classe em 1ª pessoa → abre a loja → cliente chega a
  Q1 → anota pedido → monta o hot dog (grelha, trilho, pão, tábua, complementos) → serve → gaveta sobe → resumo
  deposita → compra pacote no Mart, Restock → compra upgrade na bancada → Day 2 libera Cheese e Bacon segue "Out of
  stock".
- Aceite: todos os casos do plano passam; `modux check` e analyze zero erro; falha vira task de correção neste board.

### TASK-042 — `DevService` + comandos de turno (R1)
- Feature nova `src/Dev/`. `DevService` retorna no topo do `OnInit` se `PlaceService:IsDev()` for falso (nada criado,
  nenhum comando registrado). Carrega `Commands/*.luau` (cada um exporta `{ Name, Help, Run(args, caller?) }`), mesmo
  padrão de descoberta das `Stations/` (TASK-002); comando novo = arquivo novo, sem editar o `init`.
- Entrada **sem Lync**: chamada direta pelo Command Bar na visão Server
  (`require(<DevService>).Run("day", 4)`) e `TextChatCommand` `/dev <comando> <args>` criado no servidor. `/dev help`
  lista os comandos.
- `Commands/Round.luau`: `day <n>` → `RoundService:DevSetDay(n)`; `skip` → `RoundService:DevSkipPhase()`.
- Aceite: com `IsDev()` falso, `/dev` não existe e `require(...).Run` faz `error`; `day 2` a partir do Day 1 deixa o
  jogo igual ao Day 2 natural (Cheese liberado, Bacon "Out of stock", `Shift.Day = 2` para todos); `skip` em Open passa
  por Fechamento e Summary normalmente (resumo e depósito acontecem); Day 6 alcançável em < 1 min; nenhum `require`
  de Lync; analyze zero erro.

### TASK-043 — Comando de dev: gemas e dinheiro (R2)
- `Commands/Economy.luau`: `gems <n> [player]` → `ClassService:DevGrantGems`; `cash <n>` → `EconomyService:DevAddCash`.
- Aceite: `gems 45` permite comprar `class_rabbit` (T017-03); `cash 500` aparece no HUD de todos em ≤ 1 s; `cash -9999`
  deixa `Cash = 0`, nunca negativo; sem `IsDev()` nada disso existe.

### TASK-044 — Log de `Interact` descartado (R4)
- `Commands/Interact.luau`: assina `InteractionService.Rejected` e imprime no Output do servidor
  `[Interact] <player> <entityId> <action> -> <reason>`, com agregação por segundo (ex.: `rate x22`) para não inundar.
  Comando `interactlog on|off` (padrão on em dev).
- Aceite: cada caso de pacote forjado da §3 do plano mostra a linha com o motivo certo (`rate`, `range`, `target`,
  `state`); 30 pacotes no mesmo frame geram ≤ 2 linhas.

### TASK-045 — Contador de spawns de cliente (R5)
- `Commands/Spawns.luau`: assina `CustomerService.SpawnAttempted`; zera no `ShiftStarted`; no fim da fase Open imprime
  `Day N: tentativas X, spawnados Y, pulados (fila) Z, pulados (teto) W`; comando `spawns` mostra o turno atual.
- Aceite: X = Y + Z + W; com fila sempre vazia (Refuse rápido) Z = 0; números batem com a contagem manual de T032-02.

### TASK-046 — Pacote grátis pego por "Take" (L-03, Provisório)
- `ItemService/Pickup.luau` (+ 1 linha de registro no `init.luau` do `ItemService`): no `ShiftStarted` do dia de
  liberação de um ingrediente (`Content.Ingredients`), coloca **1 modelo de exibição** do pacote (não `Tool`; sem
  `Handle` tocável) sobre a estação desse ingrediente (ponto pelo `MapIndex`), com `EntityId` e tag `Interactable`.
  Registra a ação `pick_up_item` no `InteractionService` (prompt "Take", toque). Validação: `ItemService:CanGive`
  (hotbar 4, DEC-174; limite de pacotes 2/Urso 3); ok → `Give` do pacote cheio na mão de quem tocou e o modelo some;
  cheio → `Notice` "Hands full" e o modelo fica.
- Fica no mundo até ser pego (não some no fim do dia, não reaparece). Dias pulados pelo `DevSetDay` não geram pacote
  (só o dia em que se entra). Snapshot por `RegisterSnapshot` (pacote não pego sobrevive ao snapshot).
- Se `Actions.pick_up_item` vier da TASK-003 com texto diferente de "Take", trocar o texto em
  `src/Shared/Content/Actions.luau` (só depois de TASK-003 `Feito`).
- Aceite: Day 2 (R1) → 1 `pack_cheese` sobre a estação do queijo (T025-09); encostar não pega; "Take" com hotbar
  cheia ou 2 pacotes → "Hands full", pacote fica; dois jogadores no mesmo frame → só um recebe (serialização da
  TASK-011); o pacote pego faz Restock normal (TASK-025).

---

## Ondas seguintes (só listadas; viram TASK quando a onda abrir)

| Onda | Escopo | Specs |
|---|---|---|
| 2 — Noite e meta | `VitalService` com sanidade e faixa visual da crew (DEC-166/167/169), troca local de NPC para Night (DEC-168/181), escuro e `LightZone`, interruptor e lâmpada básica (DEC-189), café, **compra do trailer** e troca de veículo (DEC-107/184), noite no `RoundService`, ligações do chefe, snapshot e noite repetida, ladrão (DEC-182), humor dinâmico completo (Q-164), passantes (DEC-183, Q-162), lobby com plataformas (DEC-179), party, sessão/teleporte/reconexão, **stash de Tools ao sair e devolução ao voltar (`data.md` §2.3; L-01 da TASK-040)**, gemas por evento (`RewardService`). Limpeza de `Round`/`Vitals` antigos no `Net` | FEAT-001, 002, 013, 016–021, 026, 029–031 |
| 3 — Anomalias e rua | `AnomalyService`, 7 verbos, ANM-001 a ANM-010, alucinações, trânsito com PARE e reserva de faixa (DEC-133), atropelamento e item no chão | FEAT-022–024, 033, 036; `anomalies.md` |
| 4 — Queda e monetização | desmaio, **ambulância**, reviver, spectate, janela de 10 s, Revive Kit na S1, `MonetizationService` (reviver por Robux), cutscenes de intro e final, final da 10ª noite | FEAT-004, 025, 027, 034, 035; DEC-091–094, 114–118, 129 |
