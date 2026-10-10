Status: Rascunho

# Plano de teste — Onda 2 (a noite existe: run completa sem anomalia)

Autor: qa-tester. Versão 1, 2026-10-10 (**TASK-094**). Resultado da execução: **TASK-095** preenche a §11 deste
arquivo e escreve `docs/tests/wave-2-report.md`.

Base: `docs/tasks/board.md` v2.0 (critérios de aceite TASK-047 a TASK-087, "Notas da v2.0"),
`docs/tech/architecture.md` v4.0 §19.0–§19.12, §19.20–§19.26, `docs/tech/network.md` v5 §13.0–§13.4, §13.10–§13.12,
`docs/tech/content-data.md` v5 §3.11, §3.12, §3.16, §3.20, §3.21, §6.1–§6.9, `docs/tech/data.md` v5 §5.1–§5.3,
FEAT-002, 003, 005, 009, 013, 014, 016–021, 025, 026, 029, 031, 032, 036 (`docs/design/features.md`),
`tests/wave-1.md` (casos T0xx reaproveitados na regressão) e `tests/wave-1-report.md` (B-01, B-02, D-04, D-08),
DEC-047, 050, 053, 056, 069, 070, 083, 084, 086, 093, 094, 104, 107, 110–113, 115, 121, 122, 124, 127, 129, 166–169,
171, 182, 184, 189, 196, 199, 200, 216, 219.

> **Base Provisória (DEC-193).** Onde a spec é Provisória (T42–T58, `Q-167`, `Q-168`, `Q-169`, `Q-170`,
> `BandMinHold`, `Flow.NightInterval`, `Nights[k].Customers`, números iniciais do `content-data.md` §6), o caso
> testa o valor **Provisório** e está marcado **[P]**. Se a decisão mudar, o caso muda junto.
>
> **Fora da onda 2** (não testar aqui; ver `tests/wave-3.md`, TASK-127): anomalias, `Gaze`, esconder, alucinações,
> cutscenes, trânsito/atropelamento (o `DropHeld` é testado por comando de dev, R8), passantes. **Onda 4:** lobby,
> party, sessão/retomada de 15 min, ambulância, reviver, S1. Nas ondas 2–3 **ninguém é revivido**: quem cai fica
> `Down` até as 6:00 AM ou até a noite ser perdida.

---

## 0. Como usar este plano

### 0.1 Tipos de verificação

Iguais aos da onda 1 (`wave-1.md` §0.1): **E** estático, **S** script (Command Bar / lune), **M** manual no Studio.
Compilação limpa **não** fecha nenhum caso **M** ou **S**.

### 0.2 Ambiente

| Item | Configuração |
|---|---|
| Build | `rogen build` → `modux generate` → `rojo serve`; place Run aberto e conectado; place salvo com o binding da TASK-083/085 |
| Modo | **dev** (`PlaceService:IsDev() == true`), roster = quem entrar; `RunParams.BindingWave = 2` |
| 1 jogador | Test → Play (F5) |
| 2 jogadores | Test → **Clients and Servers**, Clients = 2 |
| 4 jogadores | Clients and Servers, Clients = 4 (obrigatório nos casos **4p**: preço do trailer, snapshot ≤ 2 KB, noite repetida com espectadores, teto de NPC/FPS) |
| PC | teclado + mouse; interagir = **E** |
| Mobile | Test → Device: "iPhone SE" (667×375) e "iPad"; 📱real se houver place publicado. Console: fora (DEC-171) |
| Rede ruim | `IncomingReplicationLag` = 0,3 s nos casos **lag** |
| Noite curta | para casos que não medem duração, numa cópia local de `Nights.luau` trocar `Duration` da Night 1 para 240 (relógio 1 h = 24 s). **Nunca commitar.** Casos de duração (T054-03, T055-02) usam o valor real |

Ritmo real: dia ≈ 7 min 45 s; Night 1 = Call (≤ 60) + Prep (≤ 90) + Night (1200) + NightEnd 3 + Closing (≤ 30) +
Summary 20 ≈ **23 min**; Night 10 ≈ 33 min. Sem os comandos de dev a onda não é testável em tempo razoável.

### 0.3 Como observar o servidor

Igual à onda 1 (`wave-1.md` §0.3), mais:

- Sets novos pelo Command Bar (servidor ou client): `Net.Vitals:get(userId)`, `Net.Lights:get(i)`,
  `Net.Call:get(1)`, `Net.Thief:get(1)`, `Net.Shift:get(1)` (`Phase`, `Night`, `Attempt`, `Vehicle`, `WipeEndsAt`).
- Packets s → c (`Sanity`, `LifeEvent`, `Transition`, `RunReport`): conectar um listener no Command Bar do **client**
  antes do passo (`Net.Sanity:onClient(print)` ou a API equivalente usada no código).
- Comandos de dev já previstos nas tasks: `/dev night <k>`, `/dev lose wipe|critical`, `/dev win` (054);
  `/dev trailer buy|swap` (056); `/dev light on|off|hush` (059); `/dev sanity <n>`, `/dev down`, `/dev spectate`
  (062); `/dev call <key>` (070); `/dev thief now` (072); `Commands/Reward.luau` (074); mais os da onda 1
  (`day`, `skip`, `gems`, `cash`, `upgrade`, `interactlog`, `spawns`).

### 0.4 Pedidos de testabilidade (R6–R14)

Continuação dos R1–R5 da onda 1. **Recomendação Provisória** do qa-tester ao task-planner: cada pedido cabe num
arquivo **novo** em `DevService/Commands/` (ou num já previsto para a task), sem mexer em arquivo de outro dono.

| # | Pedido | Casos que dependem | Onde caberia |
|---|---|---|---|
| R6 | `/dev clock <h:mm>`: move o relógio dentro da fase atual (Open ou Night) reescrevendo `PhaseStartedAt` pelo mesmo caminho do tick | T072-02 (janela 9 AM–3 PM), T054-08 (Calma/Turno/Últimos), T062-07 (5:59 AM), roteiro §8 | TASK-054 (`Commands/Round.luau`) |
| R7 | `/dev reward endless <n> [player]` (escreve `EndlessDays` do perfil) e `/dev reward forget` (limpa `RunRewards.Keys` da run atual) | T074-05/06 (Day 100), repetir T074 depois de `ResetDev` (L2-04) | TASK-074 (`Commands/Reward.luau`) |
| R8 | `/dev drop [player]`: chama `ItemService:DropHeld(player, "Hit")` (o chamador real, trânsito, é da onda 3) | T066-07..10 (FEAT-036) | TASK-066 (arquivo novo `Commands/Item.luau`) |
| R9 | log de dev de vida: uma linha por `LifeChanged`, `Wipe` (abre/fecha), `NightResolved`, `SpendChance`, `RunEnded` | T062, T054-05..07, §8 | TASK-062 (`Commands/Vital.luau`) |
| R10 | `/dev snapshot`: imprime as chaves e o tamanho em bytes do JSON da última captura | T052-06, T066-03 | TASK-052 (arquivo novo `Commands/Snapshot.luau`) |
| R11 | `/dev priceparty <1..4>`: sobrescreve `PriceParty` (só `IsDev()`) | T056-02 (preço 3p/4p sem 4 clients) | TASK-052 (mesmo arquivo do R10) |
| R12 | `/dev light zones`: mostra os volumes `LightZone` no client de quem digitou e imprime `IsLit(HRP)` 1×/s por 10 s | T059-02..04, T062-03 | TASK-059 (`Commands/Light.luau`) |
| R13 | `/dev sanity <n> [player]` aceitar jogador alvo (não só quem digitou) | T062, T065, §8 com 2–4p | TASK-062 |
| R14 | `/dev thief now [L1\|L2\|L3]`: escolher o ponto de espreita | T072-03 | TASK-072 (`Commands/Thief.luau`) |

---

## 1. Portão estático (vale para **toda** task de código da onda 2)

G-01 a G-13 da onda 1 (`wave-1.md` §1) continuam, com os donos de arquivo da v2.0 ("Regras do board", "Ondas 2 e 3")
no lugar dos da onda 1. Novos:

| ID | Verificação | Esperado |
|---|---|---|
| G-14 | sem ciclo de `Require` (§19.0 regra 1, T42); `analyze.ps1` sem ciclo e `Require` de cada Service = tabela do §19.2 | 0 ciclo; nenhum `Require` a mais |
| G-15 | probe (`SetPhaseProbe`, `SetVehicleProbe`, `SetVerdict`, `AddGate`, `AddReportStep`) sem yield; erro vira `warn` + valor padrão | leitura: nenhum `task.wait`/`:Wait()`/`WaitForChild` em probe |
| G-16 | sinal de Service de prioridade **menor** conectado no `OnStart`, não no `OnInit` (§19.0 regra 2; ex.: `VehicleService.Swapped` em Kitchen/Item/Light) | sim |
| G-17 | todo comando de dev novo num arquivo próprio em `DevService/Commands/`; só `IsDev()`; sem rede | sim |
| G-18 | nenhum número de design no código (§19.0 regra 6): tempos, preços, raios, chances, gemas vêm de `Content` | grep de literais suspeitos (8, 16, 10, 15, 20, 25, 60, 300…) nos arquivos novos |
| G-19 | servidor nunca toca animação de jogador nem cria `Sound` (T47, T55) | grep `LoadAnimation`/`Animator`/`Instance.new("Sound")` em `src/*/server` = 0 (exceto `Ragdoll` da onda 3) |
| G-20 | ação nova registrada por um dono só (`RegisterAction`): `buy_trailer` Vehicle, `switch_light` Light, `answer_phone` Boss, `brew_coffee` Kitchen/CoffeeMachine, `give_coffee` Item, `discard` (rua) Kitchen | uma ocorrência por chave |
| G-21 | `Required.Wave2` validado no boot com `BindingWave = 2`; nada lê `RunParams.StartVehicle` como veículo atual (A6) | grep `StartVehicle` só em default de probe/restore |

---

## 2. Casos por task

Colunas: **Tipo** (E/S/M) · **Jog.** (1p/2p/4p) · **Plat.** (PC/Mob/ambos). Mob = emulador; 📱real quando marcado.

### TASK-047 — Content da onda 2

| ID | Critério | Tipo | Passos | Esperado |
|---|---|---|---|---|
| T047-01 | `Validate()` passa e é rápido | S | require de `Content` no servidor e no client, `os.clock()` antes/depois | sem erro; < 0,002 s |
| T047-02 | noite sem `NightCall` | S | cópia local de `BossCalls.luau` sem `call_night_4` | `error` cita `BossCalls`/Night 4 |
| T047-03 | ≠ 1 `NightRepeat` | S | 0 e 2 linhas `NightRepeat` | `error` nos dois |
| T047-04 | `Duration` não crescente | S | Night 5 = 1300 | `error` cita `Nights` e a linha |
| T047-05 | `Selling` fora de Open/Night | S | `Prep.Selling = true` | `error` |
| T047-06 | forma do `Shift` (§6.2) | E | ler | 12 fases com `Selling`, `SkipWithoutProbe`, override `Night`; `Closing.Kind = "Any"`; `Summary` 15/20; `Prep` 60/90 |
| T047-07 | `Nights` (§6.3) | E | ler | 10 linhas, `Duration` 1200…1800 (DEC-127); `Windows` Calm 1200–1260, Shift 1260–1740, Last 1740–1800 |
| T047-08 | A7 | E | `Actions` | `brew_coffee` hold 1, `give_coffee` 0,5 `NightOnly`, `hide` 0,5, `answer_phone` (0, raio 7, Wave 2), `get_up` (Wave 3) |
| T047-09 | A10 | E | `Items` | `DropDespawn` = 60 nos pacotes e no `revive_kit`; `"NextShiftEnd"` no `DROP-T` |
| T047-10 | `Notices` | E | comparar com §6.9 + D-04 (`wave-1-report.md` §4) | todas as chaves das ondas 2–3 + D-04 presentes; `ValueFrom` aceita `"Achievements"` |
| T047-11 | `RunParams.BindingWave = 2`, `EndlessFromDay = 6`, `AntiAfkMinCompleted = 3`; `Vehicles.trailer.Reminder = { 5, 3 }`; `Stations.coffee_machine.Params.BrewTime = 6`; `Revive.BodyFallback = 20`, `WipeWindow = 10`, `MaxPerNight = 2` | E | ler | valores do §6.8, §3.11, §3.12 |
| T047-12 | `Sanity`, `Thief`, `GemRewards`, `LightGroups` | E | ler | `Bands { 60, 40 }`, `DarkDelay 3`, `DarkPerSecond 1`, `CoffeeCooldown 60`, `CoffeeNightOnly true` **[P]**; Thief do §6.6; `NightBase 15`, `NightPerIndex 2`, `Finale 100`; 4 grupos do §6.4 |
| T047-13 | ids vazios aceitos | S | `Animations`/`Sounds` com `Id = ""` e um `rbxassetid://123` | passa; `Id = "abc"` dá `error` |
| T047-14 | sem `require` proibido; lune + `modux check` + analyze 0 | E | grep + portão | ok |

### TASK-048 — Net v2 + `Required.Wave2` + limpeza do legado

| ID | Critério | Tipo | Passos | Esperado |
|---|---|---|---|---|
| T048-01 | entradas = `network.md` §13.1–§13.4 | E | diff de `Net/init.luau` | `Vitals` (schema novo), `Sanity`, `LifeEvent`, `Transition`, `RunReport`, `Lights`, `Call`, `Thief`; nenhuma da onda 3–4 |
| T048-02 | legado fora (A9, §13.11) | E | grep | packet `Round` e `Vitals` Health/Armor/Stamina ausentes; componente `Vital`, `VitalService`/`VitalController` de exemplo removidos (casca vazia) |
| T048-03 | sem `keyBy`; enums de `Content` (T13) | E | grep | `Call.Call` = `BossCalls.Keys`; `Vitals.Class` = `Classes.Keys` |
| T048-04 | boot sem erro de `Lync.start()` | M | 1p, F5 | Output limpo (G-13) |
| T048-05 | `Required` por onda (A6) | S | `BindingWave = 1` e `= 2` numa cópia local; boot | valida `Wave1` e `Wave2` respectivamente; `Wave2` acusa ponto faltando com nome |
| T048-06 | B-01 fechado | E | checkout limpo do commit da task → `rogen build` → `modux generate` → `git status` | gerados idênticos ao commitado (G-03 passa) |
| T048-07 | nada quebrou no client que lia o legado | E | grep `Net.Round`, `Vitals:get` antigos | 0 |

### TASK-049 — Docs (D-01, D-05..D-07, A5, mecanismo `RunReport.Gems`)

| ID | Critério | Tipo | Esperado |
|---|---|---|---|
| T049-01 | D-05/D-06/D-07 corrigidos | E | `data.md` §3.3 com `Stn`/`Fp`; `network.md` sem "`pick_up_item` sem prompt"; sem `UpgradeController` |
| T049-02 | mecanismo das `Gems` no `RunReport` sem `Require` Round → Reward | E | descrito (probe/registro, T42); a TASK-054/074 seguem esse texto |
| T049-03 | dono do `discard` de rua = `KitchenService` (TASK-057) | E | registrado |

### TASK-050 — A1 `EconomyService`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T050-01 | `AddReportStep` na ordem, antes do envio | S | 1p | registrar 2 passos de teste (Command Bar) que escrevem `report.X = 1` e `report.X += 1`; fechar o turno (`/dev skip`) | client recebe `ShiftReport` já com os campos; ordem respeitada |
| T050-02 | passo com erro | S | 1p | passo que dá `error` | `warn` com o nome; relatório sai igual |
| T050-03 | `Steal(n)` | S | 1p | `Drawer = 20`; `Steal(8)` → 8; `Steal(50)` → 12 | `Drawer` 0 no fim; `ledger.Stolen = 20`; resumo mostra "Stolen" |
| T050-04 | `Catch` | S | 1p | `AddToDrawer(5, "Catch")` no Open | gaveta +5; `Arrived` não muda; entra no bônus da nota (FEAT-013) |
| T050-05 | `IsShopOpen` por `Selling` | S | 1p | ler em Prep, Open, Night, Closing, Summary | true em Open e Night; gaveta aceita entrada também no `Closing` **[P]** |
| T050-06 | regressão | M | 1–2p | T021-01..10 | sem mudança |

### TASK-051 — A2 `InteractionService`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T051-01 | `AddGate` | S | 1p | gate de teste que recusa `grill_place` com `"test"` | `Rejected(... "test")`; log da TASK-044 mostra `test xN` |
| T051-02 | todos os gates passam | S | 1p | 2 gates, um recusa | recusado com o nome do que recusou; estado igual |
| T051-03 | `Performed` só depois de `Run` sem erro | S | 1p | ouvir `Performed`; ação que dá certo; ação cujo `Run` dá erro (gate falso não chega a `Run`) | 1 disparo só no sucesso; nenhum na recusa |
| T051-04 | onda pela tabela | E | — | — | `BUILD_WAVE` sumiu; lê `RunParams.BindingWave`; ação `Wave = 3` (`hide`, `get_up`) descartada com `target` |
| T051-05 | membro via `RunStateService` | E/M | 2p | B `Away` (sai) e forja nada; A interage | `IsActive` do RunState; T011-01..09 sem regressão |

### TASK-052 — A3 `RunStateService`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T052-01 | `Member` v5 | E | — | — | campos do `data.md` §5.2; sem `Sanity`, `CoffeeReadyAt`, `SeenAnomalies`, `RevivesTonight` |
| T052-02 | `SpendChance` | S | 1p | chamar 2× | `true`, depois `false`; `Shift.Chances` 1 → 0 |
| T052-03 | `SetLifeState` + `LifeChanged` | S | 1p | `SetLifeState(uid, "Down")` | sinal `(uid, "Active", "Down")`; só o `VitalService` chama no código (grep) |
| T052-04 | `RepeatNight` | S | 2p | B `Spectator`; `Capture`; `Restore("RepeatNight")` | os 2 `Active`; `Ch` não volta |
| T052-05 | `ResetDev` | S | 1p | Day 4 com `Chances = 0`; `ResetDev()` | volta à 1ª captura, modo `Resume`, `Chances = 1` |
| T052-06 | snapshot ≤ 2 KB | S | 4p | Night 2 com Tools em todos (R10) | ≤ 2048 bytes; `M` sem `T` |
| T052-07 | regressão | M | 2p | roteiro de teste da TASK-010 (T010-01..05) | sem mudança |

### TASK-053 — A4 `CustomerService` à noite + `Acted` + D-04 do Take Order

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T053-01 | spawn em toda fase `Selling` | M | 1p | Night 1 (`/dev night 1`): Call, Prep, Night, NightEnd, Closing | só nasce em `Night` (8 PM–6 AM); 0 em Call/Prep/NightEnd/Closing |
| T053-02 | teto de noite | S | 1p | ninguém atende, Counter 3; contar `Customers` a cada 1 s (R5) | ≤ 6 (`MaxCustomersNight`) |
| T053-03 | intervalo da tabela **[P]** | S | 1p | `/dev spawns` numa Night 1 completa | média coerente com `Nights[1].Customers.BaseInterval` / `NightInterval` |
| T053-04 | `Acted` | S | 1p | ouvir `Acted`; Take Order, Serve, Refuse, deixar um desistir | 4 disparos; desistência com `player = nil`; `result` = `SaleResult` |
| T053-05 | Take Order fora de venda | M | 1p | cliente em Q1 no Closing → ok; forjar `take_order` na Prep/Summary | Closing aceita (onda 1); fora → `Notice` D-04 só ao autor, estado igual |
| T053-06 | Closing das 6 AM | M | 1p | 2 na fila às 5:55 AM (R6) | atendíveis no Closing; Summary quando o balcão esvazia ou em 30 s |
| T053-07 | regressão de dia | M | 1p | T032-01..08, T033-01..20 | sem mudança |

### TASK-054 — `RoundService`: run completa

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T054-01 | `Flow.luau` puro | S | — | lune: tabela de casos | Day 4 cart → Day 5; Day 5 trailer → Night 1; Night k → Day D+1; Day N trailer → Night k+1; Night 10 vencida → `Finale`; sem trailer e Day ≥ 6 → `Endless` |
| T054-02 | 1º turno de run nova | M | 1p | entrar | `Intro` pulada (sem probe, §19.0 regra 4): `Phase` vai direto a `Prep` (ou fica em `Intro` 0 s) |
| T054-03 | fases e relógio de noite | M | 1p | Night 1 sem pular, cronometrar | `Call` 7:00 PM parado (≤ 60 s) → `Prep` 7→8 PM (≤ 90 s) → `Night` 8 PM→6 AM em 1200 s ± 1 → `NightEnd` 3 s → `Closing` → `Summary` 20 s → Day D+1 |
| T054-04 | ordem da fronteira | S | 1p | ouvir `BeforeShift`, `ShiftStarted`, `PhaseChanged` e chamada de `SetEndless`/`Capture` (log) | `BeforeShift` → `Flow.Next` → `SetEndless` → `ShiftStarted` → `PhaseChanged` → `Capture` |
| T054-05 | noite perdida com chance | M | 2p | Night 1: `/dev lose wipe` | `NightLost` 6 s → `NightResolved(Lost, wipe)` → `SpendChance` → restore `RepeatNight` → `Shift.Attempt = 1`, `Phase = Call`; captura nova |
| T054-06 | 2ª noite perdida | M | 2p | depois de T054-05, `/dev lose wipe` de novo (mesma ou outra noite) | `RunEnd` 15 s + `RunEnded("Failed")` + `RunReport` a cada jogador → `ResetDev` → Day 1 (`Resume` ≤ 15 s → Prep) |
| T054-07 | `LoseNight` idempotente e só em Call/Prep/Night | S | 1p | 2× no mesmo frame; 1× no `NightEnd`, `Summary`, dia | 1 `NightResolved`; fora das fases: ignorado sem erro |
| T054-08 | `NightWindow` | S | 1p | ler em 8:30 PM, 10 PM, 5:30 AM (R6) | `Calm`, `Shift`, `Last`; de dia `nil` |
| T054-09 | `Verdict` no fim da `Night` | M | 2p | A `Active`, B `Down` às 6:00 AM | `NightEnd` + `NightResolved(Won)`; os 2 `Down` → regra do Vital (T062-08) |
| T054-10 | Night 10 vencida | M | 1p | `/dev night 10` + `/dev win` | `NightEnd` → `Finale` pulada (sem probe) → `RunEnd(Success)`; **sem** Closing/Summary (FEAT-027) |
| T054-11 | probes | S | 1p | `SetPhaseProbe("Call", fn)` devolvendo true; `SetCounterProbe` (alias) | `Call` termina no próximo tick; Closing da onda 1 sem regressão |
| T054-12 | `Record().Vehicle` (A6) | S | 1p | depois do swap | `Shift.Vehicle = trailer` pelo probe, não `StartVehicle` |
| T054-13 | `LastChanceUsed` | M | 1p | perder a Night 1, vencer a repetição | resumo noturno com "Last chance used"; noites seguintes: ver L2-11 |
| T054-14 | `IsSelling`, `NightEndsAt` | S | 1p | ler | `NightEndsAt` = instante das 6:00 AM desta noite (± 0,1 s) |
| T054-15 | dev | M | 1p | `/dev night 3`, `/dev lose critical`, `/dev win` | vai à Call da Night 3; `NightResolved(Lost, critical)`; vitória imediata |
| T054-16 | regressão | M | 1–2p | T012-01..09, T015-01..03, comandos da TASK-042 | sem mudança (`Shift.Night = 0` de dia) |

### TASK-055 — `RoundController`

| ID | Critério | Tipo | Jog. | Plat. | Passos | Esperado |
|---|---|---|---|---|---|---|
| T055-01 | sources novos | S | 1p | — | ler `Night()`, `Attempt()`, `NightWindow()` | iguais a `Shift` e ao relógio |
| T055-02 | relógio de noite | M | 2p | PC + Mob | Night 1 real; comparar com a fórmula em 5 instantes | "8:00 PM" → "6:00 AM"; 1 h = 120 s; ≤ 1 passo entre clients |
| T055-03 | parado na `Call` | M | 1p | ambos | durante a ligação | "7:00 PM" fixo |
| T055-04 | reconexão | M | 2p | PC | B sai e volta às 2 AM | hora certa na hora |
| T055-05 | regressão | M | 1p | — | T015-01..03 | ok |

### TASK-056 — `VehicleService`

| ID | Critério | Tipo | Jog. | Plat. | Passos | Esperado |
|---|---|---|---|---|---|---|
| T056-01 | só com `Day ≥ 5`, de dia, não comprado | M | 1p | ambos | Day 4: olhar o trailer; forjar `buy_trailer`. Day 5 Prep: prompt | Day 4: sem prompt, forjado recusado; Day 5: "Buy Trailer — $300", hold 2 |
| T056-02 | preço pela party fixa (DEC-121) | S/M | 1–4p | — | `PriceParty` 1..4 (R11 ou 4 clients reais) | $300 / $450 / $570 / $660 |
| T056-03 | compra | M | 2p | ambos | `Cash` ≥ preço; A segura 2 s | `Cash` −preço; `trailer_bought` nos 2; prompt some; placa some |
| T056-04 | sem saldo | M | 1p | ambos | `Cash` = preço − 1 | hold não executa / forjado → `not_enough_cash`; `Cash` igual |
| T056-05 | compra dupla no mesmo frame | M | 2p | — | A e B soltam juntos (e forjado nos 2 clients) | 1 compra; um único débito |
| T056-06 | compra na Prep, Open, Closing, Summary | M | 1p | — | uma por run (`/dev` reset entre elas) | todas aceitas; troca só na fronteira (FEAT-016) |
| T056-07 | troca no `BeforeShift` | M | 2p | PC + Mob | comprar no Day 5 e esperar o fim do Summary | `Transition` (fade 1,5 s nos 2) → trailer em `TRL`, carrinho em `TRL-SALE` com a lona visível → `Shift.Vehicle = trailer` → Night 1 |
| T056-08 | `Swapped` uma vez | S | 1p | — | ouvir | `(cart, trailer)` 1× |
| T056-09 | lembretes (FEAT-017) | M | 1p | — | não comprar; Summary do Day 5, 6, 7, 8, 11 | `trailer_available` no fim do Day 5; `trailer_waiting` no fim do Day 8 e 11; nada no 6/7; nada depois da compra |
| T056-10 | snapshot `Veh` | S | 1p | — | Night 1 perdida (T054-05); depois `ResetDev` | repetição: trailer em `TRL`; `ResetDev`: carrinho em `CART`, trailer à venda, `Bought = false`, prompt volta no Day 5 |
| T056-11 | probe no `OnInit` | E | — | — | — | `SetVehicleProbe` registrado no `OnInit` |
| T056-12 | dev | M | 1p | — | `/dev trailer buy`, `/dev trailer swap` | compra sem custo / troca imediata pelo mesmo caminho |

### TASK-057 — `KitchenService` reage à troca + lixeira de rua + Restock cheio

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T057-01 | estoque passa inteiro | M | 1p | carrinho com Cooler 2, salsicha 18/20; trocar | trailer: `Amount` 18; `Capacity` do trailer (Cooler 1 no trailer, DEC-184) |
| T057-02 | acima da capacidade **[P]** `Q-169` | M | 1p | T057-01 | 18/12 fica; "Restock" some e forjado → `Notice` D-04; volta quando `Amount < Capacity` |
| T057-03 | café liberado no trailer | M | 1p | depois da troca | `coffee.Blocked = false`; prompt de Restock/Brew da cafeteira ligado |
| T057-04 | prompts do veículo antigo | M | 1p | ir ao carrinho em `TRL-SALE` | nenhum prompt de estação nele; forjado → recusado (estação não atual) |
| T057-05 | lixeira de rua (DEC-200) **[P]** `Q-166` | M | 1p | HotDog na mão → `Prompt_Discard` da rua; pacote na mão | HotDog some; pacote: sem prompt / forjado recusado |
| T057-06 | Restock com estoque cheio | M | 1p | 12/12 + pacote; forjar `restock` | `Notice` D-04 ao autor; pacote intacto |
| T057-07 | regressão | M | 1p | T025-01..10, T028-07 | ok |

### TASK-058 — `VehicleController` + gaveta só do veículo atual

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T058-01 | `SIGN-T` "Available on Day 5" | M | 1p | ambos | visível do Day 1; some ao comprar; texto depois do Day 5 sem compra: ver L2-12 |
| T058-02 | fade no `Transition` | M | 2p | PC + Mob | 1,5 s nos dois ao mesmo tempo; quem reconecta depois não vê fade |
| T058-03 | sem estado próprio | E | — | — | lê `Shift.Vehicle`; nenhuma variável de veículo local |
| T058-04 | billboard da gaveta | M | 1p | ambos | antes: só no carrinho; depois da troca: só no trailer (fecha o Provisório da TASK-024) |
| T058-05 | regressão | M | 2p | ambos | T024-01..04 |

### TASK-059 — `LightService` + `Zones`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T059-01 | `IsLit` < 0,05 ms | S | — | 10.000 chamadas com posições aleatórias | média < 0,00005 s |
| T059-02 | caixa orientada e esfera | S | 1p | R12: andar nas bordas de LZ-1 (Block girado) e LZ-3 (Ball, raio 18) | `IsLit` muda na borda (± 0,5 stud) |
| T059-03 | zona ativa | S | 1p | de dia dentro do Mart; à noite no Mart; trailer com interruptor off; `trailer_lights` 0 vs 1 | dia: nada é escuro (`IsLit` irrelevante, Vital não perde); noite: Mart aceso sempre; LZ-1/2 só com interruptor; LZ-3 só com upgrade ≥ 1 e interruptor |
| T059-04 | `juniper_posts` sem volume (DEC-196) | S | 1p | sob um poste da Juniper à noite | `IsLit` falso (salvo volume marcado pelo level-designer) |
| T059-05 | interruptor | M | 2p | A toca "Lights" | estado da party; B vê o mesmo; set `Lights` atualizado |
| T059-06 | cooldown 0,5 s | M | 1p | 5 toques em 1 s (e forjado) | ≤ 2 trocas |
| T059-07 | liga sozinho na noite | M | 1p | desligar na Night 1, vencer, Day, Night 2 | começa ligado |
| T059-08 | Hush | S | 1p | `/dev light hush` | LZ do trailer apagadas; interruptor sem efeito; Mart aceso; `EndHush` volta |
| T059-09 | snapshot `Lt` | M | 1p | desligar e perder a noite | repetição começa **ligada** (FEAT-020) |
| T059-10 | `SwitchChanged` | S | 1p | ouvir | `(on, player)` a cada troca efetiva; nada no cooldown |

### TASK-060 — `LightController`

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T060-01 | lâmpadas seguem `Lights.On` | M | 2p | ambos | iguais nos 2; de dia "Lights" só visual |
| T060-02 | Hush poste a poste | M | 2p | PC | `Order × 1,5 s` desde `At`; B que entra no meio vê os postes certos |
| T060-03 | preset dia/noite | M | 1p | ambos | `Lighting` muda na fase; sem salto estranho no `Summary` |
| T060-04 | corte por distância | M | 1p | PC | luz longe desligada sem pop perto do jogador |
| T060-05 | 60 FPS à noite | M | 1p | Mob (+📱real) | ≥ 60 no emulador/aparelho de referência dentro do trailer e no Mart (§12.1) |

### TASK-061 — `CharacterService` onda 2

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T061-01 | `SpawnPointFor` | M | 2p | dia; noite; noite repetida | `PS-n`; `PS-N1..4`; `REV-1..4` (DEC-122), de pé |
| T061-02 | não spawna `Down`/`Spectator`/`Away` | M | 2p | B `Spectator` (`/dev spectate`); reset de B | B sem personagem; câmera de spectate |
| T061-03 | `SetLookPack` | S | 1p | `SetLookPack(p, "Mid")`; resetar personagem | atributo `LookPack = Mid` também após respawn |
| T061-04 | `Faint` (DEC-216) | M | 2p | `/dev down` em A | A em **ragdoll** no lugar, sem arremesso, rosto `Fainted`; B vê igual. Se vier pose: ver L2-13 |
| T061-05 | `RemoveBody` | M | 2p | depois de T061-04, esperar 20 s | corpo some com fade (`BodyFallback`) |
| T061-06 | `Freeze` | S | 1p | `Freeze(p, "test", true)` | não anda nem pula; `false` volta; 2 motivos: só solta quando os 2 saem |
| T061-07 | `Prompt_Give` | M | 2p | Explorer | âncora no HRP de cada membro, `PromptAction = give_coffee` |
| T061-08 | ids de locomoção | S | 1p | `Animations.Locomotion.crew` com 1 id de teste e o resto vazio | `Animate` do personagem com o id; vazios mantêm o padrão |
| T061-09 | regressão | M | 2p | T018-01..07 | ok |

### TASK-062 — `VitalService` reescrito

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T062-01 | início da noite pela classe | M | 2–4p | Night 1 com Cachorro, Coelho (Runner), Coruja (Night Owl) | 100/100, 90/100, 120/120 (FEAT-019); packet `Sanity` só ao dono |
| T062-02 | dia sem sanidade | M | 1p | qualquer dia | `Sanity{0, 0}`; nenhuma variação; `LookPack = Day` |
| T062-03 | escuro | M | 1p | à noite, sair de toda zona e cronometrar | 0 perda nos 3 s; depois −1/s; voltar à luz para; não perde em `Closing`/`Summary` (fora de `DarkPhases`) |
| T062-04 | faixa → `LookPack` (DEC-167) | M | 2p | `/dev sanity 59`, `39`, `60` em A | B vê A com Mid (+Exhausted), Night (+`Normal_Night`), Day; troca instantânea; B nunca recebe o número (só `LookPack`) |
| T062-05 | 0 → `Down` | M | 2p | `/dev sanity 0` em A (B `Active`) | `Vitals[A].State = Down`, `StateEndsAt = NightEndsAt`; `Faint`; Tools de A no stash; `LifeEvent{Down}` aos 2; A sem prompts |
| T062-06 | `MaxPerNight` | E | — | — | `RevivesTonight ≥ 2` → `Spectator` direto (na onda 2 não ocorre: sem reviver) |
| T062-07 | 6:00 AM | M | 2p | A `Down`, B `Active`; ir a 5:59 AM (R6) | às 6:00: A `Spectator`, `LifeEvent{Spectating}`; pacotes de A em `DROP-T` (com `Count`); HotDog/café de A somem |
| T062-08 | janela de 10 s | M | 2p | B `Down`; A vai a 0 | `Shift.WipeEndsAt = now + 10`; `LifeEvent{Wipe}`; em 10 s → `LoseNight("wipe")` |
| T062-09 | janela fecha | M | 2p | B `Active` saiu (`Away`) antes; A cai (janela abre); B volta dentro dos 10 s | B volta `Active` → `SetWipe(0)` + `WipeCleared`; noite segue |
| T062-10 | `Verdict` | S | 2p | às 6 AM com só `Down`/`Spectator` presentes (sem passar pela janela: `/dev skip` na Night) | `LoseNight("wipe")`, não `Won` |
| T062-11 | gate `Vital` | M | 2p | A `Down`/`Spectator` forja `grill_place`, `buy_package`, `answer_phone` | todos `Rejected(... "Vital")` |
| T062-12 | estado por `UserId` | M | 2p | A com 47 sai e volta na mesma noite | volta com 47 e mesma faixa (FEAT-030); `Down` volta `Down`; volta depois das 6 AM → `Spectator` |
| T062-13 | noite repetida | M | 2p | A `Spectator`, perder a noite | todos `Active`, sanidade inicial da classe, `RevivesTonight = 0`, `Seen` vazio |
| T062-14 | APIs da onda 3 prontas | E | — | — | `SeeAnomaly` (−5 1×/anomalia/noite), `Penalize` (−35, nenhuma classe muda, FEAT-019), `SetKnocked`, `SetPickupHandler` existem e compilam |
| T062-15 | `SetLifeState` em toda troca | E | — | — | cada mudança de `State` chama `RunStateService:SetLifeState` |
| T062-16 | dev | M | 1p | `/dev sanity 10`, `/dev down`, `/dev spectate` | estados certos, mesmos caminhos do jogo |
| T062-17 | `BandMinHold` **[P]** | M | 1p | ficar oscilando em 60 (escuro ↔ luz) | registrar se o visual pisca; se piscar, pedir `BandMinHold = 1` ao game-designer |

### TASK-063 — `VitalController` + `CharacterController` + vinheta

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T063-01 | sources | S | 1p | — | `Sanity`, `Max`, `Band`, `State[uid]` iguais ao servidor |
| T063-02 | `Max = 0` esconde | M | 1p | ambos | sem medidor/vinheta de dia |
| T063-03 | vinheta só no dono | M | 2p | PC | A em 30: vinheta/saturação em A; B não vê nada |
| T063-04 | sem vermelho nem tremor (AST-084) | M | 1p | ambos | faixas sem cor vermelha nem shake |
| T063-05 | controles travados | M | 2p | ambos | `Down`/`Spectator`/`Freeze`: sem andar/pular/hotbar; `Active` volta |

### TASK-064 — `CameraController`: spectate, `Fixed`, braços

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T064-01 | spectate colega `Active` | M | 3p | PC + Mob | A `Down` vê B em 1ª pessoa; interagir troca para C |
| T064-02 | sem colega | M | 2p | ambos | os 2 fora de `Active` (antes de a janela fechar) → `Fixed` em `SPEC-P`/`SPEC-M` |
| T064-03 | volta à 1ª pessoa | M | 2p | — | noite repetida / run nova |
| T064-04 | braços (DEC-219) | M | 1p | ambos | braços reais visíveis em 1ª pessoa com o pack da faixa à noite (ver L2-14 sobre "só à noite") |
| T064-05 | spectate de dia | M | 2p | — | espectador continua seguindo um colega no dia seguinte (FEAT-025) |
| T064-06 | regressão | M | 1p | ambos | T019-01..03 |

### TASK-065 — `HudController` onda 2

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T065-01 | medidor só com `Max > 0` | M | 1p | ambos | noite sim, dia não (FEAT-032) |
| T065-02 | retrato da faixa | M | 1p | ambos | troca com a faixa (placeholder letra + cor) |
| T065-03 | "Night k" | M | 1p | ambos | "Night 1"; dia "Day N" |
| T065-04 | contador de 10 s | M | 2p | ambos | aparece a todos com `WipeEndsAt`, some no `WipeCleared` |
| T065-05 | "Watching {name}" | M | 2p | ambos | nome do colega assistido; troca junto com a câmera |
| T065-06 | tela de fim de run | M | 2p | ambos | `RunReport` 15 s: resultado, Day, Night, gemas do jogador |
| T065-07 | nada clicável para `Active` | M | 1p | ambos | clicar/tocar todo o HUD noturno: nada responde |
| T065-08 | `Chances` nunca | M | 1p | — | nenhum texto de chances (DEC-053) |
| T065-09 | layout mobile | M | 1p | Mob (iPhone SE) | medidor + retrato + toasts + contador não cobrem hotbar, joystick nem botão de interagir |
| T065-10 | regressão | M | 1p | ambos | T039-01..07 |

### TASK-066 — `ItemService` onda 2

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T066-01 | stash ao sair e voltar (L-01) | M | 2p | B com pacote `Count = 5` + HotDog `ketchup,cheese` sai e volta | mesmas Tools, `Count` e `Toppings`; HotDog com visual |
| T066-02 | stash no `Down` e no respawn | M | 2p | `/dev down` em B; noite repetida | Tools somem no `Down`; voltam iguais ao snapshot `T` na repetição |
| T066-03 | snapshot `T` | S | 2p | R10 | `T` por `uid`; conectado = Backpack + mão; `Away`/`Down` = stash |
| T066-04 | `RegisterUse` só em Tool do servidor | S | 1p | handler de teste; ativar Tool do servidor e uma Tool criada no client | só a do servidor chega ao `Run` |
| T066-05 | `give_coffee` | M | 2p | noite: A com café segura 0,5 s em B | Tool vai para B (com `Restore`); A fica sem |
| T066-06 | `give_coffee` bloqueado | M | 2p | B já tem café; B `Down`; de dia (`NightOnly`); A sem café | recusado; Tool de A intacta (FEAT-021). Hotbar de B cheia: ver L2-08 |
| T066-07 | `DropHeld` Keep (R8) | M | 2p | A com pacote `Count = 5` → `/dev drop` | modelo no chão (não Tool) com "Take" hold 0,5; B pega → pacote `Count = 5` (FEAT-036) |
| T066-08 | despawn 60 s | M | 1p | não pegar | some em 60 s ± 1 |
| T066-09 | `Lost` | M | 2p | HotDog na mão → `/dev drop` | splat 2 s; nada pegável; nunca servível |
| T066-10 | Take com hotbar cheia | M | 1p | 4 Tools | `hands_full`; item fica |
| T066-11 | `DropStash` `DROP-T` | M | 2p | = T062-07 | pacotes no balcão do trailer; somem no fim do turno seguinte |
| T066-12 | itens no chão fora do snapshot | M | 1p | item no chão; perder a noite | some na restauração |
| T066-13 | `CurrentVehicle` | E/S | 1p | depois da troca | = `VehicleService:Current()` |
| T066-14 | regressão | M | 1–2p | T022-01..08, T025-09 (pacote grátis da TASK-046) | ok |

### TASK-067 — `ItemController`

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T067-01 | anel sob item no chão | M | 2p | ambos | visível aos 2, inclusive no escuro |
| T067-02 | splat e café derramado | M | 2p | ambos | 2 s, local em cada client, sem resto depois |
| T067-03 | sem `Highlight` permanente | E/M | — | — | nenhum `Highlight` criado sem destruir |

### TASK-068 — Estação de café (servidor)

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T068-01 | preparo | M | 1p | trailer, `coffee ≥ 1`, hold 1 s "Brew Coffee" | `coffee` −1; `Working` 6 s; `Ready` |
| T068-02 | "Take Coffee" | M | 1p | tocar em `Ready` | Tool `coffee` com `Restore = 25`; registro volta a `Empty` |
| T068-03 | 1 por vez | M | 2p | B toca "Brew" com `Working` | sem prompt; forjado recusado |
| T068-04 | sem estoque / `Blocked` | M | 1p | `coffee = 0`; carrinho (antes do trailer) | recusado; estoque igual |
| T068-05 | Barista (fora do MVP) | S | — | `GetModifier` com classe forçada no console | `BrewTime` 3, `Restore` 35 de quem **preparou** (não de quem pegou) |
| T068-06 | dois "Take" no mesmo frame | M | 2p | forjado nos 2 | 1 café só |
| T068-07 | `Single` no set; não edita o `init` | E | — | — | registro único; `git diff` sem `KitchenService/init.luau` |
| T068-08 | hotbar cheia no "Take" | M | 1p | 4 Tools | `hands_full`; café fica `Ready` |

### TASK-069 — `KitchenController/Coffee.luau`

| ID | Critério | Tipo | Jog. | Esperado |
|---|---|---|---|---|
| T069-01 | barra ±0,2 s | M | 1p | barra termina com o `Ready` |
| T069-02 | copo pronto visível | M | 2p | os 2 veem o copo em `Ready`, some no Take |
| T069-03 | reconexão | M | 2p | B entra a 50%: barra continua do ponto certo |
| T069-04 | escopo | E | — | só `Coffee.luau` + 1 linha no `PARTS` |

### TASK-070 — `BossService`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T070-01 | `call_day_<N>` na Prep | M | 1p | Day 2 e 3 | telefone do carrinho toca; `Call.State = Ringing` |
| T070-02 | variante `_quentin` | M | 1p | ladrão pego no Day 3 (T072-05); Day 4 | `call_day_4_quentin` |
| T070-03 | dia infinito | M | 1p | Day 6, 7 sem trailer | pool `call_day_infinite`, sem repetir a anterior |
| T070-04 | `call_night_<N>` / `call_night_short` | M | 1p | Night 1; Night 1 repetida | completa na 1ª; curta na repetição (FEAT-018) |
| T070-05 | `call_trailer_bought` | M | 1p | trailer comprado | toca na `Call` da Night 1 (§19.5); ver L2-09 |
| T070-06 | perdidas | M | 1p | `/dev lose wipe` com chance; `/dev lose critical` com chance; 2ª perda | `call_lost_last_chance`; `call_lost_critical` + `last_chance`; `call_run_over`: ver L2-10 |
| T070-07 | dicas | M | 1p | Day 1: 1º "Grill" | `hint_<passo>` 1× por run (via `Performed`); repetir a ação não toca de novo |
| T070-08 | uma por vez, por prioridade | S | 1p | `/dev call` de 2 chaves seguidas | segunda espera a primeira; maior `Priority` primeiro |
| T070-09 | fases proibidas | S | 1p | `/dev call` em `NightLost`, `RunEnd` | não toca; fica na fila (ou descarta: registrar) |
| T070-10 | atender | M | 2p | ambos | A toca "Answer" no telefone do veículo atual | `Talking`; B ouve a mesma linha |
| T070-11 | auto 15 s | M | 1p | ninguém atende | `Talking` em 15 s ± 0,2 |
| T070-12 | ritmo | M | 2p | PC + Mob | cronometrar linhas | 2,5 s/linha; mesma linha nos 2 (≤ 0,5 s, FEAT-018) |
| T070-13 | sem repetir | M | 1p | ambos | depois da ligação | nenhum prompt no telefone; forjar `answer_phone` sem ligação → recusado |
| T070-14 | probe `Call` | M | 1p | Night 1 | `Prep` começa quando a ligação acaba (antes do cap 60) |
| T070-15 | snapshot `Bs` | S | 1p | perder a Night 1 | `call_night_1` não toca de novo (está em `Bs`) |
| T070-16 | reconexão | M | 2p | B sai e volta no meio | B vê só as linhas restantes; quem volta depois não recebe a ligação |
| T070-17 | durações | E | — | — | dia ≤ 7 linhas; noite ≤ 45 s (`Validate`) |

### TASK-071 — `BossController`

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T071-01 | toque e luz no veículo atual | M | 1p | ambos | carrinho de dia (antes da troca); trailer depois |
| T071-02 | legenda "Walt: …" | M | 2p | ambos | 2,5 s/linha pelo `StartedAt`; ≥ 14 px no iPhone SE; nenhuma linha passada reaparece |
| T071-03 | volume por distância | M | 1p | PC | mais baixo no Mart; legenda igual |
| T071-04 | sem modelo do Walt | E | — | — | nenhum rig do Walt fora da cutscene (FEAT-018) |

### TASK-072 — `ThiefService` + `NpcService.Role`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T072-01 | sorteio | S | — | 100 sementes × Day 1, 2, 3 (função do sorteio ou log) | Day 1 0%; Day 2 50% ± 10 p.p.; Day 3+ 70% ± 10; ≤ 1 por dia; nunca à noite |
| T072-02 | janela 9 AM–3 PM | S | 1p | 20 dias (`/dev day`, R6) | hora sorteada sempre entre 9:00 AM e 3:00 PM |
| T072-03 | spawn e rota | M | 1p | `/dev thief now` (R14 L1..L3) | guaxinim, roupa `thief`, de `ST-R` até `L1..L3` sem cruzar pista; conta no teto de 12 |
| T072-04 | gatilho | M | 2p | ficar a 13 studs do `Zone_Center`; depois a 15 por 3 s | parado a 13; `Approaching` após 3 s a 15; aproximação 4 s ± 0,3 |
| T072-05 | pego | M | 2p | entrar na zona durante `Opening` | foge; gaveta +5 (`Catch`); `thief_caught` nos 2; `quentin_caught_day = Day`; `Arrived` igual |
| T072-06 | roubo | M | 1p | gaveta $23, não interromper | gaveta 12 (floor 50% = 11); `Stolen 11` no resumo |
| T072-07 | UPG-004 | M | 1p | Cash Drawer Lock; gaveta $23 | abertura 16 s; rouba 6 (floor 30%) |
| T072-08 | gaveta < $5 | M | 1p | gaveta $4 | não rouba nada |
| T072-09 | espreita máx. 120 s | M | 1p | ficar na zona o tempo todo | vai embora em 120 s sem roubar |
| T072-10 | quem conta na zona | M | 2p | só um `Spectator` ou um jogador `Away` perto | não conta (zona "vazia") |
| T072-11 | `raccoon` só com papel `Thief` | E/S | — | 30 min de clientes | nenhum cliente guaxinim/`thief` |
| T072-12 | set `Thief` | S | 1p | ouvir | ~4 escritas por ladrão; `None` no fim |

### TASK-073 — `ThiefController`

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T073-01 | barra em `Bar_Thief` | M | 2p | ambos | igual nos 2; 8 s (16 com UPG-004) |
| T073-02 | some | M | 1p | — | em `Fleeing`/`None` |
| T073-03 | reconexão | M | 2p | — | B entra no meio da abertura e vê a barra do ponto certo |

### TASK-074 — `RewardService`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T074-01 | dia com anti-AFK | M | 2p | Day com 3 completos e nota A | +2 e +1 a cada um; `gems_gained`; `report.Gems = 3` |
| T074-02 | dia sem anti-AFK | M | 1p | 2 completos, nota A (FEAT-029) | 0 gemas; `afk_no_gems`; `AfkLocked = true` |
| T074-03 | noite vencida | M | 2p | vencer Night 1, Night 3 (`/dev night`) | +15, +19 (`15 + 2 × (N − 1)`) |
| T074-04 | final | M | 1p | `/dev night 10` + `/dev win` | +33 e +100 **antes** do `Finale`/`RunEnd`; total 133 |
| T074-05 | Day 100 | S | 1p | R7: `EndlessDays = 99`; concluir um Day ≥ 6 sem trailer com anti-AFK | 300 gemas + badge + `achievement` 1× por conta; contador não aparece em tela |
| T074-06 | Day 100 não soma | S | 1p | Day 1–5; dia com trailer; dia sem anti-AFK | contador igual |
| T074-07 | qualquer estado | M | 2p | B `Spectator` na vitória | B recebe |
| T074-08 | desconectado não recebe | M | 2p | B sai 1 s **antes** do evento | B não recebe aquele evento |
| T074-09 | salvo no instante | M | 2p | B sai 1 s **depois** da vitória | gemas de B salvas (reentrar: `Profile.Gems`) |
| T074-10 | idempotência | S | 1p | disparar o mesmo passo 2× (Command Bar) | 1 crédito (`RunRewards`) |
| T074-11 | `RunReport.Gems` | M | 2p | fim da run | soma da run por jogador (ou 0 até a TASK-049 definir) |
| T074-12 | badge com retry | S | 1p | `AwardBadge` falhando (mock) | tenta de novo; `BadgesAwarded` só no sucesso |

### TASK-075 — `AnimController`

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T075-01 | protótipo `Q-167` d | M | 2p | PC | `Animator` local num rig de NPC de servidor toca sem erro nos 2 clients; resultado enviado ao secretário |
| T075-02 | locomoção de NPC | M | 1p | ambos | `idle`/`walk` pela velocidade do HRP |
| T075-03 | LOD | M | 1p | PC | > 120 studs ou fora da tela: pausa; voltar retoma |
| T075-04 | ids vazios | S | 1p | — | fallback sem erro nem warn repetido |
| T075-05 | FPS | M | 4p | Mob (+📱real) | 12 NPCs + 4 crews: sem queda perceptível (≥ 30 FPS emulador; 60 no aparelho de referência) |
| T075-06 | `PlayOwn` replica | M | 2p | — | one-shot do dono (ex.: `drink`) visto por B |

### TASK-076 — `AudioController`

| ID | Critério | Tipo | Jog. | Esperado |
|---|---|---|---|---|
| T076-01 | `SoundGroup`s | S | 1p | Master/Music/Ambient/Sfx/Voice/Ui em `SoundService` |
| T076-02 | teto 12 | S | 1p | 30 `Play` seguidos: ≤ 12 vozes; pool reaproveita |
| T076-03 | música por fase | M | 1p | troca com fade entre dia, Calma e Turno |
| T076-04 | ducking | M | 1p | música cai a 0,3 durante a ligação |
| T076-05 | id `""` | S | 1p | silêncio sem erro; warn no máximo 1× por chave |
| T076-06 | sem rede | E | — | nenhum `Net` no `AudioController` |

### TASK-077 — A8 `OpalController`

| ID | Critério | Tipo | Esperado |
|---|---|---|---|
| T077-01 | id fixo fora | E | grep `180435571` = 0 |
| T077-02 | idle da tabela | M | `opal_idle` vazio → idle R6 sem erro |
| T077-03 | falas por `Night` | M | Night 3 usa o pool da noite 3 |
| T077-04 | regressão | M | T038-01..05 |

### TASK-078 — `PromptController` onda 2

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T078-01 | onda pela tabela | E | — | — | `ACTIVE_WAVE` sumiu; lê `BindingWave` |
| T078-02 | só `Active` | M | 2p | ambos | `Down`/`Spectator`: nenhum prompt |
| T078-03 | nunca a própria `Prompt_Give` | M | 2p | ambos | com café, olhando para baixo/próprio corpo: sem "Give"; em B: "Give" |
| T078-04 | `PromptText` dinâmico | M | 1p | ambos | "Brew Coffee" ↔ "Take Coffee"; "Buy Trailer — $X" |
| T078-05 | pré-checagem de `give_coffee` | M | 2p | — | sem café ou alvo com café: sem prompt |
| T078-06 | regressão | M | 1p | ambos | T014-01..08 (com as ações novas no T014-01 mobile) |

### TASK-079 — Som, animação e VFX nos controllers da onda 1

| ID | Critério | Tipo | Esperado |
|---|---|---|---|
| T079-01 | sem rede nova | E | `git diff` sem `Net` novo; só eventos que o controller já recebe |
| T079-02 | nenhuma regra muda | E | diff só apresentação |
| T079-03 | SFX P1 | M | cada evento toca o SFX da `sound-list` §5.3–§5.6 (silêncio se id vazio) |
| T079-04 | `Cust_Happy`/`Cust_Complain`/`Cust_Pay` | M | pelo `AnimController` no `Sale` |
| T079-05 | teto de VFX | S | ≤ 150 partículas, ≤ 8 emissores perto, grelha cheia + 8 clientes |
| T079-06 | regressão | M | T024, T029, T030, T034, T037 |

### TASK-080 — D-04: avisos de recusa

| ID | Critério | Tipo | Jog. | Esperado |
|---|---|---|---|---|
| T080-01 | estações | M | 1p | grelha cheia, sem salsicha, tábua cheia, 3 coberturas, cobertura repetida (forjados): `Notice` D-04 só ao autor, estado igual |
| T080-02 | Mart | M | 1p | prateleira `Blocked`, bancada `busy`/`Maxed` (forjados): `Notice` |
| T080-03 | `Blocked` do Mart = `KitchenService:IsBlocked` | E | — | Provisório da TASK-036 fechado |
| T080-04 | regressão | M | 1p | T026–T028, T036 |

### TASK-081 / TASK-082 — números e textos (docs + tabelas)

| ID | Critério | Tipo | Esperado |
|---|---|---|---|
| T081-01 | `NightInterval`, `Nights[k].Customers` definidos | E | docs e tabela iguais; `Validate` passa |
| T081-02 | D-10 (`pack_coffee` com nome único) | E | um nome só em `Items`/`Packages` |
| T082-01 | toda chave nova de `Notices` com texto final | E | nenhuma "placeholder" |
| T082-02 | `BossCalls.Lines` nos tetos | S | `Validate` (≤ 7 linhas dia; ≤ 45 s noite) |
| T082-03 | D-02/D-03 resolvidos de um lado | E | "Maxed"×"MAX" e texto da bancada iguais em `ui-text.md` e código (se cair no código: task nova) |

### TASK-083 — Binding do MAP-01, onda 2

| ID | Critério | Tipo | Esperado |
|---|---|---|---|
| T083-01 | `check_map01` PASS e `Validate(Required.Wave2)` 0 erro | S | lista vazia |
| T083-02 | estações do trailer | S/M | `Vehicle = "trailer"`, `Rail_8`, `Att_Bun1..3`, `coffee_machine` com `Prompt_Brew`/`Prompt_Restock`; prompts vizinhos ≥ 2,5 studs |
| T083-03 | telefones | M | `Prompt_Answer` no carrinho e no trailer (DEC-124) |
| T083-04 | compra e lona | M | `Prompt_Buy` + `SIGN-T`; `VehicleCover` escondida até a troca |
| T083-05 | luz | S | LZ-1..5 com `ZoneId`, `Group`, `CanCollide/CanQuery/CanTouch = false`; postes JL-01..09 + P-01 com `Order` 1..10 sem repetir; `Prompt_Switch`; nenhum volume na rota Pad ↔ Mart (DEC-196) |
| T083-06 | pontos | S | `PS-N1..4`, `REV-1..4`, `TRL`, `TRL-SALE`, `CART`, `SPEC-P`, `SPEC-M`, `DROP-T`, `L1..L3`, `ST-R` + nós até as espreitas |
| T083-07 | lixeiras de rua | S | `Prompt_Discard` → `discard` |
| T083-08 | escuro da rota | M | à noite, Pad → Mart → Pad andando sem parar: perda total ≤ ~4 de sanidade (≈ 2–4 s de escuro por perna, DEC-196) **[P]** |
| T083-09 | place salvo | M | reabrir o place: binding presente |

### TASK-084 / TASK-085 — peças de upgrade (B-02)

| ID | Critério | Tipo | Esperado |
|---|---|---|---|
| T084-01 | peças por `Upgrade`/`Level` | S | grill 1–3, cooler 1–3, counter 1–3, `cash_drawer_lock` 0–1, `trailer_lights` 0–1; `check()` 0 problema; idempotente |
| T084-02 | tris | S | dentro das fichas |
| T085-01 | troca para todos ≤ 1 s | M | 2p: B compra Grill/Cooler/Counter no Mart; A no veículo vê a peça nova em ≤ 1 s (`wave-1.md` §8 passo 12; FEAT-015) |
| T085-02 | por veículo (DEC-184) | M | depois da troca: peças do trailer pelos níveis do trailer; carrinho em `TRL-SALE` mantém as dele |
| T085-03 | check PASS | S | `UpgradePiece` fora de `PENDING_TAGS` |

### TASK-086 / TASK-087 — ids de animação e áudio (dependem do usuário)

| ID | Critério | Tipo | Esperado |
|---|---|---|---|
| T086-01 | todo clipe da onda 2 com id do grupo | E | `Animations.luau`: ids `rbxassetid://` dos clipes da onda 2 (AST-069, DEC-217) |
| T086-02 | crew anda/corre com os clipes | M | 2p: B vê A com a locomoção nova |
| T086-03 | id inválido | S | id de asset inexistente → fallback sem erro |
| T087-01 | licença antes do id | E | cada id em `Sounds.luau` tem linha em `docs/art/credits.md` com licença comercial (`git log` do `credits.md` ≤ commit do id) |
| T087-02 | mixagem | M | susto nunca acima do ambiente (`sound-list` §6, DEC-005/173) |

> TASK-088 a TASK-093 (assets dependentes de DEC) não têm caso aqui: validam pelo `check()` do kit e pela troca do
> placeholder **sem mudar código** (a TASK-095 só confere que HUD, plaquinhas e lona trocam sozinhos se a entrega
> chegar antes dela).

---

## 3. Client mal-intencionado (pacotes forjados, onda 2)

Mesmo método da onda 1 (`wave-1.md` §3). Esperado comum: descarte **sem erro** no Output, estado igual, nenhum
`Notice` falso a outros jogadores (o `Notice` D-04 ao próprio autor é permitido).

| ID | Pacote / ação | Esperado |
|---|---|---|
| X2-01 | `buy_trailer` antes do Day 5, à noite, já comprado, sem saldo | descartado; `Cash` igual |
| X2-02 | `buy_trailer` 2× no mesmo frame com saldo para 1 | 1 compra (T056-05) |
| X2-03 | `answer_phone` sem ligação tocando; no telefone do veículo não atual | descartado |
| X2-04 | `switch_light` 20× em 1 s; de dia; durante Hush | ≤ 2 trocas/s; de dia só visual; Hush sem efeito |
| X2-05 | `brew_coffee` no carrinho, com `coffee = 0`, com `Working` | descartado; estoque igual |
| X2-06 | `give_coffee` em si mesmo, em `Down`, em quem tem café, de dia, sem café na mão | descartado |
| X2-07 | qualquer `Interact` de jogador `Down`/`Spectator` | `Rejected(... "Vital")` |
| X2-08 | `pick_up_item` em item no chão a 30 studs; com hotbar cheia | descartado / `hands_full` |
| X2-09 | `pick_up_item` em âncora que não é item no chão nem pacote grátis | descartado (`target`) — substitui o esperado de T011-07/X-09 da onda 1 (D-08) |
| X2-10 | ações da onda 3 (`hide`, `get_up`, `safe_spot`) | descartado (`Wave = 3`) |
| X2-11 | client cria uma Tool local chamada "Coffee" e ativa | `RegisterUse` ignora (Tool não é do servidor); sanidade igual |
| X2-12 | client muda `LookPack`/`Restore` local | só local; servidor e outros clients iguais |
| X2-13 | client tenta disparar packet s → c (`Sanity`, `LifeEvent`, `RunReport`) | sem handler no servidor; nada muda |
| X2-14 | `ClassAction{Select}` no meio da run | `class_locked` (T017-08 deixa de ser só **E**: run da onda 2 roda o caminho travado, salvo se continuar só modo dev) |
| X2-15 | `take_order` fora de fase de venda | `Notice` D-04 só ao autor (T053-05) |
| X2-16 | teleporte para dentro de uma `LightZone` | aceito (a posição é do servidor; anti-teleporte fora do escopo, como X-19) |

---

## 4. Jogador sai no meio (onda 2)

| ID | Situação | Jog. | Esperado (fonte) |
|---|---|---|---|
| Q2-01 | sai com Tools e volta | 2p | Tools iguais (T066-01; fecha L-01/Q-01/Q-08 da onda 1) |
| Q2-02 | sai à noite com sanidade 47 e volta | 2p | 47, mesma faixa, mesmo cooldown de café (FEAT-030) |
| Q2-03 | `Down` sai e volta antes / depois das 6 AM | 2p | `Down` / `Spectator` (FEAT-030) |
| Q2-04 | o único `Active` sai com o outro `Down` | 2p | nenhum presente `Active` → janela de 10 s → noite perdida se ninguém voltar. Ver L2-02 |
| Q2-05 | sai no meio da ligação e volta | 2p | só as linhas restantes (T070-16) |
| Q2-06 | sai durante o `NightLost` e volta | 2p | entra no estado restaurado (FEAT-026) |
| Q2-07 | sai durante o `RunEnd` | 2p | perde só a tela do `RunReport`; gemas já salvas |
| Q2-08 | sai 1 s depois da vitória da noite | 2p | gemas salvas (T074-09) |
| Q2-09 | quem comprou o trailer sai antes da fronteira | 2p | troca acontece igual |
| Q2-10 | Barista prepara café e sai antes do "Take" | 2p | `Restore` de quem preparou (T068-05) |
| Q2-11 | sai no meio do hold de "Give" | 2p | nada enviado; café fica com o doador |
| Q2-12 | sai com o ladrão em `Opening` sendo o único na zona | 2p | zona vazia; ladrão segue (FEAT-013: desconectado não conta) |
| Q2-13 | alvo do "Give" sai durante o hold do doador | 2p | `Interact` recusado (alvo sumiu); café fica |
| Q2-14 | único jogador sai | 1p | servidor do Studio fecha sem erro de `BindToClose` (suspensão é da onda 4) |

---

## 5. Saldo insuficiente (onda 2)

| ID | Onde | Esperado |
|---|---|---|
| $2-01 | trailer sem saldo | hold não executa; forjado → `not_enough_cash` (T056-04) |
| $2-02 | gaveta não paga o trailer | `Cash = 0`, `Drawer = 500`: recusado |
| $2-03 | trailer + pacote no mesmo frame com saldo para um | só um; `Cash` nunca negativo |
| $2-04 | noite perdida desfaz compras | comprou Grill 2 na Night 1 e perdeu: nível e `Cash` voltam ao snapshot (FEAT-015) |

---

## 6. Desempenho e orçamento

| ID | Medida | Jog. | Esperado |
|---|---|---|---|
| P2-01 | banda Lync por client à noite | 4p | sets da onda 1 + `Vitals`/`Sanity`/`LifeEvent` + `Lights`/`Call`/`Thief`/`Transition` < 0,2 KB/s (`network.md` §13.12; total da onda 3 < 0,5 KB/s) |
| P2-02 | `IsLit` | — | < 0,05 ms (T059-01) |
| P2-03 | escuro 1 Hz × 4 jogadores | 4p | sem pico no MicroProfiler do servidor |
| P2-04 | snapshot | 4p | ≤ 2 KB (T052-06) |
| P2-05 | NPCs | 2p | ≤ 12 com ladrão + 8 clientes de dia; ≤ 6 clientes à noite |
| P2-06 | FPS à noite | Mob +📱real | 60 no aparelho de referência dentro do trailer (T060-05); ≥ 30 no emulador com 12 NPCs + 4 crews (T075-05) |
| P2-07 | vozes de áudio | 1p | ≤ 12 (T076-02) |
| P2-08 | VFX | 1p | ≤ 150 partículas, ≤ 8 emissores perto (T079-05) |
| P2-09 | memória numa run longa | 1p | Day 1 → Night 3 com `/dev`: sem crescimento contínuo (NPC pool, Tools no stash, itens no chão, sons) |

---

## 7. Matriz de plataforma (DEC-171)

Mínimo a repetir no **mobile** (emulador iPhone SE; 📱real se publicado): T056-01 (hold 2 s no toque), T056-07 e
T058-02 (fade), T059-05 (interruptor), T064-01 (troca de colega pelo botão de interagir), T065-07, T065-09,
T066-05 ("Give" no colega), T068-01/02, T070-10/12, T071-02 (legenda ≥ 14 px), T078-02/03, T014-01 com as ações
novas. Party de 2: A no PC, B no mobile no roteiro §8. Console: fora.

---

## 8. Roteiro integrado (base da TASK-095)

Rodar **party de 2 (PC + mobile)** inteiro; **solo (PC)** dos passos 1–9 e 15–16; **party de 4** só os passos
8–13. Cada passo cita os casos que cobre. `/dev` só onde indicado.

1. Entrar; Day 1 sem `Intro` (T054-02); dica do chefe no 1º "Grill" (T070-07); roteiro da onda 1 (`wave-1.md` §8) até
   o Summary, sem regressão (§9 deste plano).
2. `/dev day 3`; ladrão (`/dev thief now`): deixar abrir e roubar (T072-06, T073); de novo e pegar (T072-05). Day 4:
   `call_day_4_quentin` (T070-02).
3. Antes, no Day 4: placa "Available on Day 5" visível e sem prompt (T058-01, T056-01). `/dev day 5`,
   `/dev cash 500`: prompt "Buy Trailer — $X" aparece; comprar na Prep com hold 2 s no mobile (T056-01/03); toast
   nos 2; placa some.
4. Fim do Summary do Day 5: fade 1,5 s nos 2 (T056-07, T058-02); trailer no Pad, carrinho com lona (T083-04);
   estoque e níveis por veículo (T057-01/02, T085-02).
5. Night 1 — `Call`: telefone do trailer toca, relógio 7:00 PM parado (T055-03); A atende; legenda igual nos 2
   (T070-10/12); `call_trailer_bought` + `call_night_1` (T070-04/05).
6. `Prep` 7→8 PM (T054-03); "Open Shop"; interruptor começa ligado (T059-07); medidor 100 (Cachorro) e 90 (Coelho)
   (T062-01, T065-01).
7. `Night`: clientes até 6 (T053-01/02); café: Brew → Take → beber (+25 até o máximo; `coffee_full` com cheio;
   `coffee_cooldown` antes de 60 s) (T068, T062 uso); "Give" no colega (T066-05).
8. Escuro: B sai até a Juniper sem luz (T062-03); faixa Mid e Night vistas por A (T062-04); B a 0 → `Down`, ragdoll,
   Tools no stash (T062-05, T061-04); A vê `LifeEvent`; B em spectate seguindo A (T064-01, T065-05).
9. B continua `Down` até 5:59 AM (R6); às 6:00 B vira `Spectator`, pacotes no `DROP-T` (T062-07, T066-11); A de pé →
   `NightEnd`, vitória, +15 gemas aos 2 (T054-09, T074-03, T074-07). Summary noturno 20 s.
10. Day seguinte: B continua espectador (T064-05, FEAT-025). `/dev night 2`.
11. Night 2: A desliga o interruptor e fica no escuro até 0 (B já `Spectator`) → janela de 10 s no HUD dos 2
    (T062-08, T065-04) → `NightLost` 6 s → chance usada → repetição: os 2 `Active` em `REV-1..4` com sanidade
    inicial, Tools/dinheiro/estoque/níveis/interruptor do snapshot, `Attempt = 1` (T054-05, T062-13, T066-02,
    T059-09, $2-04); `call_lost_last_chance` + `call_night_short` (T070-04/06).
12. Vencer a Night 2 repetida (`/dev win` ou sobreviver): "Last chance used" no resumo (T054-13); gemas da noite 2
    (+17) creditadas uma vez (T074-10).
13. Party de 4: na Night 3, 1 espectador desde a Night 2 + perda proposital (`/dev lose wipe`) → 2ª perda →
    `call_run_over` (L2-10) → `RunEnd(Failed)` → `RunReport` com as gemas da run (T054-06, T065-06, T074-11) →
    `ResetDev` → Day 1 (T056-10).
14. Vitória completa: `/dev night 10` + `/dev win` → +33 +100 antes do fim (T074-04) → `RunEnd(Success)` sem
    Closing/Summary (T054-10).
15. Dia infinito (outra run, solo): sem trailer até o Day 8: `trailer_available` (Day 5), `trailer_waiting` (Day 8)
    (T056-09); gemas com anti-AFK (T074-01/02); `call_day_infinite` (T070-03); R7 + Day 100 (T074-05).
16. Fim: G-01..G-21; P2-01..09 medidos na party de 4.

---

## 9. Regressão da onda 1 nos arquivos que os ajustes tocam

Rodar o bloco da onda 1 depois que a task da coluna 2 estiver `Em QA`. Falha aqui = a task da onda 2 volta.

| Arquivo / pasta tocado | Task(s) da onda 2 | Casos da onda 1 a repetir (`wave-1.md`) |
|---|---|---|
| `src/Libs/Net/init.luau`, `Place/shared/MapIndex/Required.luau`, `PlaceService` | 048 | T004-03, T005-01..06, T010-03, G-13 |
| `EconomyService/` | 050 | T021-01..10, $-01..06 |
| `InteractionService/` | 051 | T011-01..09, §3 X-01..X-19 (X-09 com o esperado novo X2-09) |
| `RunStateService/` | 052 | T010-01..05 |
| `CustomerService/` | 053 | T032-01..08, T033-01..20 |
| `RoundService/` (vira pasta), `Commands/Round.luau` | 054 | T012-01..09, T015-01..03, comandos `day`/`skip` da TASK-042 |
| `RoundController` | 055 | T015-01..03, T037 (source `Vehicle`, B-05) |
| `KitchenService/init`, `StationApi`, `Stations/Trash` | 057 | T025-01..10, T028-07/08 |
| `Stations/Grill`, `BunCrate`, `Board`, `Toppings`; `MarketService` | 080 | T026-01..08, T027-01..06, T028-01..09, T036-01..12 |
| `EconomyController` | 058, 079 | T024-01..04 |
| `CharacterService/` | 061 | T018-01..07 |
| `CameraController` | 064 | T019-01..03 |
| `HudController` | 065 | T039-01..07 |
| `ItemService/` (+ `Pickup`) | 066 | T022-01..08, T025-09 (pacote grátis) |
| `NpcService/` (`Role`) | 072 | T031-01..06 |
| `OpalController` | 077 | T038-01..05 |
| `PromptController/` | 078 | T014-01..08 |
| `KitchenController/`, `CustomerController/`, `MarketController/` | 069, 079 | T029-01..04, T030-01..03, T034-01..05, T037-01..03 |

Correção ao plano da onda 1 (**D-08**): T011-07 e X-09 esperavam `pick_up_item` "sem `RegisterAction`". Desde a
TASK-046 ela é registrada; o esperado passa a ser "forjada em âncora que não é pacote grátis nem item no chão →
descartada (`target`)" (X2-09). Na onda 2 `buy_trailer`, `switch_light`, `answer_phone`, `brew_coffee`,
`give_coffee` deixam de ser "onda futura"; `hide`/`get_up`/`bench_buy_item` continuam descartadas.

---

## 10. Lacunas de spec encontradas ao escrever o plano

Nenhuma bloqueia o início da onda; cada uma vira caso com esperado **a definir** até ser respondida.

| ID | Achado | Onde | Para |
|---|---|---|---|
| L2-01 | FEAT-016 (critério de aceite) diz "depois da troca, os níveis de upgrade são idênticos aos do fim do turno"; DEC-184 decidiu níveis **por veículo** (trailer começa com os dele). O plano testa a DEC (T057-01, T085-02) | `features.md:637` × DEC-184, `upgrades.md` | game-designer (corrigir o critério) |
| L2-02 | Janela de 10 s: §19.7 abre com "nenhum **presente** `Active`/`Reviving`", logo também quando o último `Active` **sai** (não cai). FEAT-026 só fala em queda ("o último jogador `Active` conectado cai"). Dizer se sair abre a janela (Q2-04) | `architecture.md` §19.7; `features.md` FEAT-026 | game-designer + architect |
| L2-03 | Queda depois do veredito: `DarkPhases` inclui `NightEnd`, mas `LoseNight` só vale em Call/Prep/Night. Se o último `Active` zerar no `NightEnd` (3 s) a janela abre e não pode fechar a noite. Definir: `SetWipe` ignorado depois do `Verdict` (recomendação) ou tirar `NightEnd` de `DarkPhases` | `content-data.md` §6.5; `architecture.md` §19.4, §19.7 | architect |
| L2-04 | `ResetDev` volta à 1ª captura da **mesma** run; se o `RunId` não muda, as chaves `RunRewards` (`D1:day` …) já foram usadas e a run repetida em modo dev não credita gemas. Testes de gemas depois do `RunEnd` precisam do R7 `forget` ou de `RunId` novo no `ResetDev` | `architecture.md` §19.4 (T56), §19.11; `data.md` §1.3 | architect |
| L2-05 | Café de dia (`Q-170` **[P]**): `brew_coffee` vale de dia (`Night = Any`), beber não. Falta o retorno ao jogador que ativa o café de dia (nenhum `Notice` previsto) | `content-data.md` §6.5, §6.9 | game-designer + narrative-writer |
| L2-06 | Espectador no fluxo: FEAT-025 "espectador não conta como ativo no multiplicador do turno seguinte"; DEC-185 / `Flow.PartySource = "Connected"` conta **conectados** | `features.md` FEAT-025 × `content-data.md` §3.16 | game-designer |
| L2-07 | Pacote grátis do café na troca: §19.5 diz que o `ItemService` reage a `Swapped` ("pacote grátis"), mas o aceite da TASK-066 e da TASK-057 não citam. Sem dono, o café libera sem o pacote do dia de liberação (DEC-071) | `architecture.md` §19.5; board TASK-066 | task-planner |
| L2-08 | `give_coffee` com a hotbar do alvo cheia (4 Tools): §19.8 só cita "sem café". Falta a regra e o `Notice` (para quem?) | `architecture.md` §19.8 | architect |
| L2-09 | `call_trailer_bought`: FEAT-018 diz "fim do turno em que o trailer foi comprado (com o fade)"; §19.5 diz "toca na `Call` da Night 1". O plano testa o §19.5 | `features.md:685` × `architecture.md` §19.5 | game-designer (alinhar ficha) |
| L2-10 | `call_run_over` nunca toca: o gatilho é `NightResolved("Lost")` com a chance já usada, mas a fila não toca em `NightLost` nem em `RunEnd` (§19.9), e depois do `RunEnd` vem o `ResetDev`. FEAT-026 pede `call_run_over` antes da tela de fim | `architecture.md` §19.4, §19.9 | architect |
| L2-11 | "Last chance used": o passo da TASK-054 preenche em "noite com `Chances = 0`", o que repete o texto em **todo** resumo noturno depois da perda. FEAT-014 diz "depois de a chance ser usada" (ambíguo: só na noite repetida ou em todas) | `features.md` FEAT-014 | game-designer + narrative-writer |
| L2-12 | Cap da `Call` (60 s) × fila: toque até 15 s + noite ≤ 45 s = 60 s; na noite repetida entram `call_lost_last_chance` (+ `call_lost_critical`) e `call_night_short`, e no Night 1 `call_trailer_bought` + `call_night_1`. O cap corta a fila; não está dito se o resto toca na `Prep` ou é descartado, nem a ordem entre ligações de mesma `Priority` | `content-data.md` §6.2, §6.7; `architecture.md` §19.9 | architect + narrative-writer |
| L2-13 | DEC-216 decidiu desmaio = **ragdoll** + `Fainted`, mas o `Ragdoll.luau` está na onda 3 (TASK-100) e o Provisório da TASK-061 ainda diz "ragdoll ou pose". T061-04 espera ragdoll | board TASK-061 × DEC-216 | task-planner + architect |
| L2-14 | TASK-064 diz "braços visíveis **à noite**"; DEC-219 (depois do board) decidiu braços reais visíveis em 1ª pessoa sempre (mais ao segurar item). T064-04 testa a DEC | board TASK-064 × DEC-219 | task-planner |
| L2-15 | Placa `SIGN-T`: texto depois do Day 5 sem compra (continua "Available on Day 5"?) não definido | `architecture.md` §19.5; `ui-text.md` | narrative-writer |
| L2-16 | Barista (`class_panda`) está fora do MVP (`InMvp = false`): `CoffeeBrewTime`/`CoffeeRestore` 3 s/35 só testáveis por console (T068-05) | `Classes.luau`; FEAT-021 | — (registro) |

---

## 11. Resultado (preenchido pela TASK-095)

| Rodada | Data | Build (commit) | Solo PC | Party 2 (PC + Mob) | Party 4 | Casos falhos | Tasks de correção |
|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — |
