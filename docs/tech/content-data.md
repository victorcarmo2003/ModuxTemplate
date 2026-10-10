Status: Rascunho

# Dados de conteúdo (data-driven)

Autor: architect. Versão 3.1, 2026-10-08 (conciliação com DEC-106 a DEC-130, rodada 17 e `consistency-report.md` §5;
`Traffic` alinhado à **DEC-133**).
Formato das tabelas que game-designer, narrative-writer e level-designer preenchem e que o código só lê.
Base: DEC-044 ("parâmetros são tabela"), propostas das rodadas 1 e 2 (Aprovadas), fichas de `design/` e `story/`.
Números são **valores iniciais** (ajuste de número não exige DEC; mudança de regra exige).

Fichas de design (`ITM-###`, `UPG-###`, `NPC-###`, `CLS-###`, `ANM-###`) são a fonte; a tabela é a forma
executável. Toda linha tem `Ref` apontando para o ID da ficha.

---

## 0. O que mudou

### 0.0 Versão 3.1 (DEC-130, rodada 17)

| Tabela | Mudança | Origem |
|---|---|---|
| Traffic | **sem semáforo**: sai `Crossings` (`CarGreen`, `WalkGreen`, `Offset`) e todo estado de sinal; entram `Conflicts` (zonas do cruzamento), `ConflictGap`, `RouteWeight`. Rotas `TR-1..TR-10` com `JS-IN/JS-OUT`; rota do Mart cruza a Juniper Sul em CW-1 | DEC-130 (revoga DEC-120), rodada 17, `MAP-01.md` revisão 3 |
| Traffic (DEC-133) | sai `CrossGap` (era da brecha sem parada); entram `Routes[].Stops` (PARE e linhas de faixa por rota), `Crosswalks[].Lines`, e a subtabela **`Traffic.Crossing`** (PARE 1 s, raio de reserva 15 studs, espera máx. 4 s, cooldown 4 s, spawn ≥ 55 studs, 3 s por faixa de rolagem, Juniper Sul 12–20 s por sentido, frenagem, fila) | DEC-133, FEAT-033 |
| NpcNodes (mapa) | nó de travessia ganha atributo `Crosswalk = "CW-n"`: NPC só cruza pista ali, com reserva (DEC-133) | `architecture.md` §8.1, T30 |

### 0.1 Versão 3

| Tabela | Mudança | Origem |
|---|---|---|
| RunParams | `Chances = 1` (por run inteira); `PricePartyFrom = "JoinedByDay1End"` substitui `TrailerPartySource`; multiplicador vale para trailer e Revive Kit | DEC-110, DEC-112, DEC-121, DEC-129 |
| Items | `revive_kit` = ITM-021; só a Tool equipada cai; "Pick Up"; despawn 120 s; Hot Dog e café perdidos | DEC-103, FEAT-036 |
| Vehicles | `BuySpot` = o próprio trailer no estacionamento | DEC-107 |
| MarketBench / BenchItems | 1 vaga especial; Revive Kit 15% por turno depois do trailer, $200 × party | DEC-106, DEC-129 |
| Revive | prazo 6:00 AM; Robux só para si; limite 2 por noite; congelamento e crédito decididos | DEC-115 a DEC-118, DEC-129 |
| Ambulance | uma por servidor; paradas `AMB-M`/`AMB-P`; tempos de FEAT-034 | DEC-114, FEAT-034, `MAP-01.md` §5.5 |
| Traffic | rotas `TR-1..TR-6` (Ninth Avenue / Juniper Street); números de FEAT-033; ~~semáforo decidido~~ (revogado por DEC-130, ver §0.0) | ~~DEC-120~~, FEAT-033 |
| Nights | `Duration` 20 → 30 min | DEC-127 |
| Flow | `PartySource = "ActiveAtShiftStart"` | FEAT-009 (proposta para `Q-067`) |
| Cutscenes | só cutscenes de verdade (intro, finale, credits); troca de veículo e noite perdida são transições no mundo | FEAT-004 |
| Actions | `take_item` vira `pick_up_item` ("Pick Up", toque) | FEAT-036 |

### 0.2 Versão 2

| Tabela | Mudança | Origem |
|---|---|---|
| Classes | chaves `class_*` e `Ref` `CLS-###` | DEC-069 |
| Anomalies | `Ref` = `ANM-###`; `IsCritical` só em ANM-007; `Scope` da ficha | DEC-073, DEC-074, DEC-096 |
| GemRewards | crédito por evento; anti-AFK; Day 100 por contador | DEC-083, DEC-084, DEC-104 |
| RunParams | modo infinito, anti-AFK, retomada, janela de 10 s | DEC-080, DEC-083, DEC-084, DEC-094, DEC-098 |
| Upgrades | `SoldAt = "Bench"`, sempre à venda | DEC-101, DEC-106 |
| Vehicles | compra do trailer fixa, fora da rotação | DEC-107 |
| **Items** (Tools) | nova: pacotes, café, hot dog, kit de reviver; drop e despawn | DEC-040, DEC-100, DEC-103 |
| **MarketBench / BenchItems** | nova: slots especiais e pesos do sorteio | DEC-101, DEC-106, `Q-120` |
| **Revive** | nova: tempos, sanidade ao reviver, janela, quem paga | DEC-091 a DEC-094, `Q-107` |
| **Ambulance** | nova: timeline | DEC-091 |
| **Traffic** | nova: rotas, densidade por fase, atropelamento (semáforo da v3 removido na 3.1, DEC-130) | DEC-087, DEC-095, DEC-103, `Q-102`, `Q-122` |
| **Products** | nova: developer products | DEC-092 |
| Cutscenes | `Skippable`, marcas para 1–4 avatares | DEC-078, DEC-088 |
| Shift | fase `Resume` | DEC-080 |
| Actions, Notices | novas chaves | todas acima |
| XP | nada (não existe) | DEC-081 |

## 1. Convenções

### 1.1 Lugar

| Pasta | DataModel | Quem lê | O quê |
|---|---|---|---|
| `src/Shared/Content/` (`init.luau`) | `ReplicatedStorage.shared.Content` | servidor e client | tudo que o client mostra ou prevê |
| `src/Anomaly/server/Rules/` | `ServerScriptService.server.Anomaly.Rules` | só servidor | verbo correto, gatilhos (spoiler fora do `ReplicatedStorage`, T10) |

`Content/init.luau` reexporta cada tabela. Não depende de `self.Libs`, Lync ou Vide (pode ser requerido por `Net`).

### 1.2 Forma de cada tabela

```lua
--!strict
local Table = require(script.Parent.Table)

export type Ingredient = {
	Key: string,     -- chave estável (minúsculas_com_underscore); é o que se persiste
	Ref: string,     -- ID da ficha (ITM-###, UPG-###, NPC-###, CLS-###, ANM-###)
	Name: string,    -- texto em inglês (DEC-022); placeholder até o narrative-writer
}

return Table.new({
	{ Key = "bun", Ref = "ITM-001", Name = "Bun" },
} :: { Ingredient })
```

`Table.new(list)` devolve, congelado: `List`, `Keys` (enum do Lync), `ByKey`, `IndexOf`.
Registro único (ex.: `RunParams`) é tabela simples congelada, sem `Table.new`.

### 1.3 Regras

1. **Chave é para sempre.** Perfil e snapshot guardam chaves; para mudar o texto, mude `Name`.
2. Ordem livre entre versões, fixa dentro de uma (índice só vive no fio).
3. **Sem lógica na tabela.** Fórmulas viram parâmetros (`Base`, `PerK`).
4. **Efeitos por modificador** `{ Stat, Op, Value, Scope }` sobre a lista fechada de `Stat` (§3.10).
5. Tempo em segundos reais; dinheiro em inteiros; distância em studs; preço em Robux **nunca** na tabela.
6. Texto de jogador em `Name`/`Text`/`Lines`.
7. Enum com sentinela (`none`) declara a sentinela **como linha da tabela** (primeira posição).

### 1.4 Validação

`Validate()` ao requerer `Content` (< 1 ms): chave duplicada ou fora do padrão, referência quebrada (pacote →
ingrediente; noite → anomalia; bench → item; rota → nó), número fora de faixa, enum vazio, efeito de classe sobre
`Stat` de regra de anomalia, **ProductId = 0 em produção** (aviso no Studio). Falha = `error` com tabela e linha
(R8: enum ruim derruba o `Lync.start()`).

## 2. Mapa das tabelas

| Tabela | Arquivo | Fonte | Dono do conteúdo |
|---|---|---|---|
| RunParams | `RunParams.luau` | DEC-044, DEC-057, DEC-080, DEC-083, DEC-084, DEC-098, DEC-110, DEC-112, DEC-121 | game-designer (+ architect nos tempos técnicos) |
| Shift | `Shift.luau` | DEC-048 | game-designer |
| Ingredients | `Ingredients.luau` | DEC-071 | game-designer |
| Packages | `Packages.luau` | DEC-049, DEC-071 | game-designer |
| Items | `Items.luau` | DEC-040, DEC-100, DEC-103 | game-designer |
| Stations | `Stations.luau` | DEC-016, DEC-046, DEC-055 | game-designer |
| Upgrades | `Upgrades.luau` | DEC-046, DEC-101 | game-designer |
| Vehicles | `Vehicles.luau` | DEC-047, DEC-052, DEC-086 | game-designer |
| MarketBench, BenchItems | `MarketBench.luau` | DEC-100, DEC-101, DEC-106, DEC-108, DEC-129 | game-designer (`Q-120`) |
| Flow | `Flow.luau` | DEC-045 | game-designer |
| OrderPhases, OrderRules | `Orders.luau` | DEC-071, DEC-072 | game-designer |
| CustomerTypes | `CustomerTypes.luau` | `design/npcs.md` | game-designer + art-director |
| Thief | `Thief.luau` | DEC-050 | game-designer |
| Sanity | `Sanity.luau` | DEC-056, DEC-069 | game-designer |
| Revive | `Revive.luau` | DEC-091 a DEC-094, DEC-102, DEC-115 a DEC-118, DEC-129 | game-designer |
| Ambulance | `Ambulance.luau` | DEC-091, DEC-114, DEC-122 | game-designer + level-designer |
| Traffic | `Traffic.luau` | DEC-087, DEC-095, DEC-103, DEC-130, DEC-133 | level-designer + game-designer |
| Products | `Products.luau` | DEC-092 | architect (ids do Creator Hub, pelo usuário) |
| Nights | `Nights.luau` | DEC-025, DEC-053, DEC-060, DEC-073, DEC-127 | game-designer + narrative-writer |
| Anomalies | `Anomalies.luau` | DEC-073, DEC-096 | game-designer + art-director |
| AnomalyRules (servidor) | `src/Anomaly/server/Rules/` | DEC-054, DEC-073, DEC-074 | game-designer |
| AnomalyCues | `AnomalyCues.luau` | `story/anomalies.md` | game-designer |
| BossCalls | `BossCalls.luau` | DEC-025, DEC-076, DEC-077 | narrative-writer |
| Cutscenes | `Cutscenes.luau` | DEC-021, DEC-075, DEC-078, DEC-088 | narrative-writer + level-designer |
| Classes | `Classes.luau` | DEC-069 | game-designer |
| GemRewards | `GemRewards.luau` | DEC-070, DEC-083, DEC-084, DEC-104 | game-designer |
| Achievements | `Achievements.luau` | DEC-058, DEC-084 | game-designer + narrative-writer |
| Actions | `Actions.luau` | DEC-016, DEC-054, DEC-066 | architect + game-designer |
| Notices | `Notices.luau` | — | narrative-writer |
| Hallucinations | `Hallucinations.luau` | DEC-038 | game-designer + art-director |
| OpalLines | `OpalLines.luau` | DEC-079, CHR-003 | narrative-writer |

## 3. Formato de cada tabela

### 3.1 RunParams (registro único)

| Campo | Tipo | Valor inicial | Origem |
|---|---|---|---|
| `TrailerDay` | int | 5 | DEC-037 |
| `TrailerBasePrice` | int | 300 | DEC-047 |
| `PartyPriceMult` | `{ number }` por 1–4 | 1.0, 1.5, 1.9, 2.2 | DEC-047; vale para o trailer e para o Revive Kit (DEC-121, DEC-129) |
| `PricePartyFrom` | `"JoinedByDay1End"` (fixo) | membros do roster que entraram até o fim do Day 1; fixado ali, não muda depois | DEC-121 (regra: mudar exige DEC) |
| `Nights` | int | 10 | DEC-060 |
| `Chances` | int | **1** (por run inteira: a 2ª noite perdida encerra a run) | DEC-110, DEC-112 (emendam DEC-057) |
| `StartCash` | int | 30 | DEC-045 |
| `StartStockFull` | bool | true | DEC-049 |
| `JoinWindow` | s | 60 | DEC-098 |
| `ResumeWindow` | s | 900 (15 min) | DEC-080 |
| `ResumeWait` | s | 15 (fase `Resume`) | architect |
| `EndlessFromDay` | int | 6 | DEC-084 ("a partir do Day 6") |
| `EndlessRequiresNoTrailer` | bool | true | DEC-084 ("dias sem trailer"); game-designer confirma |
| `AntiAfkMinCompleted` | int | 3 | DEC-083 |
| `AntiAfkAppliesToGradeA` | bool | true (leitura do secretário, a confirmar) | DEC-083 |

### 3.2 Shift

| Campo | Tipo | Valor inicial |
|---|---|---|
| `Phases` | lista `{ Key, Duration, ClockFrom, ClockTo, Kind = "Day"/"Night"/"Any" }` | **Resume 15 s** · Intro · Prep 60 s 7:00→8:00 · Open 360 s 8:00→18:00 · Closing ≤ 30 s · Summary 15 s · Call · Night (duração por `Nights`) 20:00→06:00 · NightEnd · NightLost · Finale · RunEnd |
| `ClockStepMinutes` | int | 10 |
| `PhaseKeys` | derivado | enum do set `Shift` |

### 3.3 Ingredients

| Campo | Tipo | Exemplo (Ketchup) |
|---|---|---|
| `Key`, `Ref`, `Name` | | `ketchup`, `ITM-003`, "Ketchup" |
| `Kind` | `"Base" \| "Sauce" \| "Topping" \| "Supply"` | `Sauce` |
| `OrderPrice` | int | 1 |
| `UnlockDay` | int | 1 |
| `Weight` | number | 10 |
| `Capacity` | `{ int }` por nível de Cooler | 30 / 50 / 75 (`items.md`) |
| `Station` | chave de `Stations` | `condiment_ketchup` |
| `Icon` | asset id | (art-director) |

Linhas (DEC-071): bun, sausage (Base); ketchup, mustard (dia 1); cheese (2); bacon (3); potato_sticks (4);
cream_cheese (6); coffee (Supply). `ToppingKeys` = Sauce + Topping. Capacidade do Cream Cheese: `Q-062`.

### 3.4 Packages

| Campo | Exemplo |
|---|---|
| `Key`, `Ref`, `Name` | `pack_sausages`, `ITM-011`, "Sausages" |
| `Ingredient` | `sausage` |
| `Amount`, `Price` | 8, 6 |
| `Item` | chave em `Items` (`pack_sausages`) |

`MaxCarried = 2` (DEC-049), modificado por `PackageLimit` (Hauler, pós-MVP).

### 3.5 Items (Tools) — nova

Toda Tool que vai à hotbar (DEC-040).

| Campo | Tipo | Exemplo (kit de reviver) |
|---|---|---|
| `Key`, `Ref`, `Name` | | `revive_kit`, `ITM-021`, "Revive Kit" |
| `Kind` | `"Package" \| "Consumable" \| "Product" \| "Revive" \| "Anomaly"` | `Revive` |
| `ToolModel` | nome do modelo (AST-###) | (art-director) |
| `Stackable` | bool | false |
| `DropOnHit` | `"Keep" \| "Lost" \| "Vanish"` | `Keep` (Revive Kit e pacotes ficam no chão). Só a Tool **equipada** cai (DEC-103); `Lost` = Hot Dog e café ("splat"/derrama, some em 2 s); `Vanish` = item alterado (FEAT-036) |
| `DropDespawn` | s ou `"NextShiftEnd"` | pacote 120 s na rua; Revive Kit `NextShiftEnd` (FEAT-036; game-designer fecha `Q-122` e) |
| `KeepOnSpectate` | bool | true (fica no stash; usável pelo `Revive` com `Method = Item`) |
| `HotbarSlots` | int | 1 (`Q-056`) |

Linhas: um item por pacote (ITM-011…019), `coffee` (ITM-009), `hot_dog` (ITM-010), `altered_item` (ITM-020),
`revive_kit` (ITM-021).

### 3.6 Stations

| Campo | Exemplo (vaga de grelha) |
|---|---|
| `Key` | `grill_slot` |
| `BaseDuration` | 12 |
| `Actions` | `grill_place`, `grill_collect` |
| `Consumes` | `sausage` |

### 3.7 Upgrades

| Campo | Tipo | Exemplo (Grill) |
|---|---|---|
| `Key`, `Ref`, `Name` | | `grill`, `UPG-001`, "Grill" |
| `Levels` | lista `{ Price, Effects, Part }` | N1 `{0, {GrillSlots=2, GrillTime=12}}` · N2 `{60, ...}` · N3 `{150, ...}` |
| `Vehicle` | `"Any" \| "Trailer"` | Any |
| `UnlockDay` | int | 1 |
| `SoldAt` | `"Bench"` | Bench (DEC-101; sempre à venda, DEC-106) |
| `BenchSpot` | nome da peça de exibição na bancada | `BenchGrill` (level-designer) |

Linhas MVP: grill (UPG-001), cooler (UPG-002), counter (UPG-003), cash_drawer_lock (UPG-004), trailer_lights
(UPG-005). Coffee Machine (UPG-007) vem com o trailer (sem compra). Nível passa do carrinho ao trailer: `Q-075`.

### 3.8 Vehicles

| Campo | Exemplo |
|---|---|
| `Key`, `Ref`, `Name` | `cart` / `trailer` (`UPG-006`) |
| `Model` | modelo no `ServerStorage` |
| `HasNight` | false / true |
| `BuyFromDay` | — / 5 |
| `BuySpot` | — / o **próprio trailer** à venda no estacionamento (peça com prompt `buy_trailer`; level-designer). **Fixo**, fora da bancada e da rotação (DEC-107, FEAT-016) |

### 3.9 MarketBench e BenchItems (DEC-106, DEC-129; FEAT-035)

Upgrades básicos **não** passam por estas tabelas: ficam sempre à venda (`Upgrades.SoldAt = "Bench"`, DEC-106).
Aqui só a vaga especial.

`MarketBench` (registro único):

| Campo | Tipo | Valor inicial |
|---|---|---|
| `SpecialSlots` | int | **1** (S1, FEAT-035) |
| `RollOn` | `"EveryShift"` | início da Preparação de todo turno, dia e noite (DEC-101) |
| `SameForParty` | bool | true (oferta compartilhada; set `Bench`) |
| `InSnapshot` | bool | true (FEAT-035: noite repetida e retomada não sorteiam de novo) |

`BenchItems` (lista; primeira linha é a sentinela `none` = "Nothing special today"). Especial novo exige DEC (DEC-106).

| Campo | Tipo | Revive Kit |
|---|---|---|
| `Key` | | `none`, `revive_kit` |
| `Item` | chave de `Items` | `revive_kit` (ITM-021) |
| `BasePrice` | int (dinheiro da party, DEC-108) | **200** (DEC-129) |
| `PriceScalesWithParty` | bool | true: × `RunParams.PartyPriceMult[PriceParty]` → 1p $200 · 2p $300 · 3p $380 · 4p $440 (DEC-121, DEC-129) |
| `Chance` | 0–1 por turno | **0.15** (DEC-129) |
| `RequiresTrailer` | bool | true: só depois da compra do trailer (DEC-129) |
| `PerShift` | int | 1 (vendido → "Sold out" até o fim do turno) |
| `PerRun` | int ou 0 (sem limite) | 0 (limite por turno/run do Kit segue com o game-designer, `Q-120`) |

### 3.10 Classes e modificadores

| Campo | Tipo | Exemplo (Line Cook) |
|---|---|---|
| `Key`, `Ref`, `Name`, `Description` | | `class_line_cook`, `CLS-003`, "Line Cook", ... |
| `Tier`, `Price` | int | 1, 45 gemas |
| `InMvp` | bool | true |
| `Effects` | lista `{ Stat, Op, Value, Scope }` | `{GrillTime, Mul, 0.85, Self}`, `{WalkSpeed, Set, 15, Self}` |

Lista fechada de `Stat`:

| Stat | Lido por | Usam |
|---|---|---|
| `WalkSpeed` | `CharacterService` (Humanoid) | Runner, Line Cook, Night Owl (dia), Hauler |
| `GrillTime`, `GrillSlots` | `Kitchen` | Line Cook, Grill |
| `StockCapacityLevel` | `Kitchen` | Cooler |
| `QueueSize`, `PatienceBonus` | `Customer` | Counter |
| `PackageLimit` | `Item` | Hauler (pós-MVP) |
| `TipAmount`, `TipWindow` | `Economy` | Hawker (pós-MVP) |
| `SanityStart`, `SanityMax` | `Vital` | Runner (90), Night Owl (120) |
| `CoffeeBrewTime`, `CoffeeRestore`, `SeeAnomalyLoss` | `Kitchen`, `Vital` | Barista (pós-MVP) |
| `BossBonusPP` | `Economy` | Shift Lead (pós-MVP, Party, não acumula) |
| `DrawerOpenTime`, `StealPct` | `Thief` | Cash Drawer Lock |
| `LightRadius`, `DayFlowBonus` | `Vital`, `Customer` | Trailer Lights |

Linhas MVP (DEC-069): class_rookie (grátis), class_runner (45), class_line_cook (45), class_night_owl (120).
Hauler, Hawker, Barista, Shift Lead com `InMvp = false`. `Validate()`: nenhum `Stat` toca regra de anomalia, chances,
revive ou trânsito (guarda pay-to-win e DEC-069).

### 3.11 GemRewards e Achievements

`GemRewards` (registro único):

| Campo | Valor inicial | Evento (`RewardEvent.key`) |
|---|---|---|
| `DayShift` | 2 | `D{n}:day` (exige anti-AFK) |
| `DayGradeA` | 1 | `D{n}:gradeA` (anti-AFK conforme `RunParams.AntiAfkAppliesToGradeA`) |
| `NightBase`, `NightPerIndex` | 15, 2 | `N{n}:night` |
| `Finale` | 100 | `finale` |
| `RunFailedExtra` | 0 | — |
| `CreditMoment` | `"Event"` (fixo, DEC-104) | — |

`Achievements`:

| Campo | Exemplo |
|---|---|
| `Key`, `Name`, `Hidden` | `day_100`, "Day 100" (placeholder), true |
| `Counter` | `EndlessDays` (campo do perfil) |
| `Target` | 100 |
| `Gems` | 300 |
| `BadgeId` | id do Creator Hub (usuário) |

### 3.12 Revive (números de FEAT-034; regras por DEC)

| Campo | Tipo | Valor inicial | Nota |
|---|---|---|---|
| `SanityPct` | 0–1 | 0.5 | sanidade ao voltar = floor(50% do máximo da classe): 50 / 60 (Night Owl) |
| `ProtectTime` | s | 5 | sem perda por escuro depois de aparecer |
| `OfferUntil` | `"NightEnd"` (fixo) | 6:00 AM = `ClockTo` da fase Night | **DEC-115**: revivível até 6:00 AM da noite da queda; depois `Spectator`. Spectator nunca é revivido |
| `MaxPerNight` | int | **2** | **DEC-129**: por jogador por noite, somando Robux, Kit e crédito. 3ª queda = `Spectator` na hora, sem oferta |
| `KitAllowOthers` | bool | true | proposta de FEAT-034 (colega de pé usa o Kit); fecha em `Q-120` f |
| `KitTarget` | `"OldestDown"` | `OldestDown` | proposta de FEAT-034; fecha em `Q-120` f |
| `WipeWindow` | s | 10 | DEC-094 |
| `WipeFreezeOnPrompt` | bool | true | **DEC-118**: congela a janela enquanto há prompt de compra aberto |
| `WipeFreezeMax` | s | 20 | **DEC-118** |
| `IntentTimeout` | s | 60 | intenção de compra → recibo |
| `CreditOnUnapplied` | bool | true | **DEC-117**: recibo sem alvo vira `ReviveCredits` no perfil |

Robux e crédito são **só para o próprio caído** (DEC-116). Não há campo para isso: é regra, não número (mudar exige
DEC).

### 3.13 Ambulance (FEAT-034, DEC-114, DEC-122; IDs do `MAP-01.md` §5.5)

| Campo | Valor inicial |
|---|---|
| `Count` | 1 por servidor (fila FIFO de viagens) |
| `ArriveTime` | 8 s da queda até a parada |
| `LoadTime` | 10 s (2 médicos descem, vão até o corpo, maca 2 s, voltam; DEC-114) |
| `LeaveTime`, `ExitTime` | 2 s para partir, ~6 s até sumir do mapa |
| `ReturnDelay`, `ReturnTime`, `DepartTime` | 2 s depois da confirmação, ~6 s até `AMB-P`, parte 2 s depois que o jogador aparece (ninguém desce, DEC-091) |
| `Speed` | 12 studs/s |
| `Reach` | 40 studs (alcance dos médicos e janela para entrar na mesma viagem) |
| `Stops` | `AMB-M` (queda a oeste de X −24), `AMB-P` (resto; parada do reviver) |
| `DropPoints` | `REV-1..4` (ao lado de `AMB-P`); também onde todos acordam na noite perdida (DEC-122) |
| `HoldDuring` | chaves de ANM-008 e ANM-010 em `Anomalies`: não despacha enquanto ativas |
| `DawnSiren` | false (noite perdida: parte com a sirene desligada, DEC-122) |
| `Siren` | id de som + volume máximo (DEC-005: não vira jumpscare) |
| `Model`, `MedicLooks` | AST-### (AST-052; médicos com o art-director, `Q-127`) |

### 3.14 Traffic (FEAT-033, DEC-130, **DEC-133**; rotas do `MAP-01.md` §9.5, revisão 3)

Sem semáforo (DEC-130, revoga DEC-120): a tabela **não tem** ciclo, fase nem verde/vermelho. DEC-133: carros param
**só** no PARE dos braços da Juniper (1 s) e na linha de faixa com reserva de NPC; **nunca** por jogador (nenhum
campo da tabela pode mudar isso: é regra, não número). A rota trailer ↔ Mart cruza a Juniper Sul em CW-1.

| Campo | Tipo | Valor inicial |
|---|---|---|
| `Routes` | lista `{ Key, Path = nome da pasta de nós no mapa, Shift = "Day"\|"DayNight", Lane = chave da faixa de rolagem de entrada, Conflicts = { chaves de zona }, Stops = { { Kind = "Pare"\|"Crosswalk", Ref = "SL-S"\|"CW-1"…, Line = nome da peça-linha no mapa } } }` (ordem = ordem na rota) | `TR-1`, `TR-2` (Ninth reta, `DayNight`, **sem** `Pare`); `TR-3`..`TR-6` (Juniper Norte ↔ Ninth, `Day`; as que vêm de `JN-IN` têm `Pare` em `SL-N`); **`TR-7`..`TR-10`** (Juniper Sul, `Day`, todas com `Crosswalk` CW-1; TR-7/TR-10 com `Pare` em `SL-S`, TR-8 com `Pare` em `SL-N`). Todas com `Conflicts = { "X-T" }` |
| `RouteWeight` | `{ [Key]: number }` | 1 para todas. Escolhe a rota **dentro** do sentido sorteado (Juniper Sul) ou entre as demais |
| `Conflicts` | lista `{ Key, Box = nome da peça-volume no mapa }` | `X-T` (cruzamento Ninth & Juniper, 4 braços). Caixa reservada para o carro que sai do PARE; Ninth preferencial (`architecture.md` §8.1) |
| `ConflictGap` | s | 1,0 (folga entre dois carros na mesma zona) |
| `Crosswalks` | lista `{ Key, Box, Lines = { [sentido] = nome da peça-linha } }` | `CW-1`..`CW-4`, **pintadas** (DEC-133; posição do level-designer). `Lines` = linhas de parada com reserva (`SL-1N`/`SL-1S` em CW-1 etc.). Só NPC usa a reserva; não protege o jogador |
| `SpawnInterval` | por `Kind` de fase: `{ Day = {min,max}, Night = {min,max} }` s por rota | Day 6–10 para rotas **fora** da Juniper Sul; Night 45–75 (`Q-103` segue aberta); à noite só rotas `DayNight` |
| `MaxCars` | `{ Day, Night }` | 4, 1 (a ambulância ocupa 1 vaga de veículo) |
| `SpeedStraight`, `SpeedCrossing` | studs/s | 22, 12 |
| `NoTrafficDuring` | lista | ANM-010 (Hush), cutscenes, Final; durante ANM-008 (long car) nenhum carro nasce |
| `Looks` | lista de modelos (AST-###) | 3 modelos × 4 cores; nenhum preto e comprido (reservado à ANM-008) |
| `KnockTime`, `GetUpTime` | s | 2,5, 0,5 |
| `ImpulseForward`, `ImpulseUp` | studs/s | 30, 15 (architect calibra) |
| `ImmuneTime` | s | **5** |

`Traffic.Crossing` (DEC-133; regra decidida, números ajustáveis sem DEC nova; marcados **Provisório** os que a DEC
não fixou):

| Campo | Tipo | Valor inicial | Origem |
|---|---|---|---|
| `PareStop` | s | **1** (± 0,1 no critério de aceite) | DEC-133 |
| `ReserveRadius` | studs | **15** (nenhum carro a menos disso da linha da faixa para conceder) | DEC-133 |
| `MaxWait` | s | **4** (reserva expira; nenhum carro espera mais) | DEC-133 |
| `Cooldown` | s | **4** (nova reserva da mesma faixa só depois disso) | DEC-133 |
| `NpcCrossTime` | s | 3 (24 studs a 8 studs/s) | FEAT-033, Provisório |
| `SpawnMinDist` | studs | **55** (spawn até a 1ª faixa da rota; `Validate()` mede no mapa) | DEC-133 |
| `LaneGap` | s | **3** (entre carros da mesma faixa de rolagem) | DEC-133 |
| `JuniperSouthInterval` | `{min,max}` s, por sentido | **12–20** de dia (NB = TR-7 + TR-10, SB = TR-8 + TR-9); noite: sem carros | DEC-133 (número ajustável) |
| `BrakeDecel`, `PullAway` | studs/s² | 22, 22 (22 → 0 em 1 s ≈ 11 studs) | architect, Provisório |
| `CarGap` | studs | 14 (distância parada atrás de outro carro) | architect, Provisório |
| `FollowDelay` | s | 0,5 (carro de trás arranca depois do líder) | architect, Provisório |

`Validate()` falha alto se: rota da Ninth tiver `Pare`; `Stops` fora de ordem ao longo de `Path`; 1ª faixa a
< `SpawnMinDist` da entrada; `ReserveRadius` menor que a distância de frenagem (`SpeedStraight² / (2·BrakeDecel)`);
`MaxWait` < `NpcCrossTime`.
| `HitTolerance` | studs | 8 (validação no servidor) |
| `HitsNpcs` | bool | false |
| `AmbulanceHits` | bool | false |

### 3.15 Products — nova

| Campo | Exemplo |
|---|---|
| `Key` | `revive` |
| `ProductId` | id do developer product no Creator Hub (usuário cria; preço lá, `Q-098`) |
| `Kind` | `Revive` (handler registrado pelo `ReviveService`) |

### 3.16 Flow, OrderPhases, OrderRules, CustomerTypes, Thief, Sanity

Sem mudança de formato desde a versão 1 (valores de DEC-045, DEC-050, DEC-056, DEC-071, DEC-072):

| Tabela | Campos |
|---|---|
| Flow | `BaseInterval` 22 · `GrowthPerDay` 0.08 · `GrowthCap` 0.40 · `PartyMult` {1.0, 1.6, 2.1, 2.5} · `PartySource` = `"ActiveAtShiftStart"` (ativos no início do turno, sem espectadores; FEAT-009, `Q-067`) · `MaxCustomersDay` 8 · `MaxCustomersNight` 6 · `MaxActorsNight` 3 · `MaxNpc` 12 · `DayWalkers` 2 (`Q-083`) |
| OrderPhases | `{ FromDay, ToDay, IsNight, KWeights }` |
| OrderRules | `BasePrice` 4 · `MaxToppings` 3 · `NewIngredientBoost` 1.5 · `TipAmount` 1 · `TipWindowBase` 16 · `TipWindowPerK` 4 · `PatienceBase` 40 · `PatiencePerK` 5 · `IncompletePct` 50 (floor) · `GradeThresholds` · `GradeBonusPct` |
| CustomerTypes | `Key`, `Ref` (NPC-###), `Name`, `Looks` (R6), `WalkSpeed`, `Weight`, `IngredientMult`, `Lines` |
| Thief | `ChanceByDay`, `MaxPerDay`, `WindowClock`, `LurkMax`, `ZoneRadius`, `ZoneEmptyTime`, `OpenTime`, `StealPct`, `MinDrawer`, `CatchReward` |
| Sanity | `Start` 100 · `SeeAnomaly` −5 (1× por anomalia, por jogador, por noite, `Q-114`) · `SeeTime` · `SeeAngle` · `SeeRange` · `RuleBroken` −35 · `DarkDelay` 3 · `DarkPerSecond` −1 · `Coffee` +25 · `CoffeeCooldown` 60 · `CoffeeBrew` 6 · `TrailerLightRadius` 18 · `BasicLampRadius` (`Q-064`) |

### 3.17 Nights, Anomalies, AnomalyCues, AnomalyRules

| Tabela | Campos |
|---|---|
| Nights | `Index` 1–10 · `Duration` (s; DEC-127: 1200, 1260, 1320, 1380, 1440, 1560, 1620, 1680, 1740, 1800) · `NewAnomaly` (chave ANM) · `IntroCall`, `RepeatCall` (versão curta, `Q-077` d) · `MaxSimultaneous` · `TrafficDensity` (override opcional, `Q-103`) |
| Anomalies (shared) | `Key` (`anm_blank_folks`…), `Ref` (`ANM-001`…`ANM-010`), `Actor` (`Customer`/`World`/`Ambient`/`Vehicle`), `Look`, `Scope` (`Party`/`PerPlayer`, DEC-073) |
| AnomalyCues | `Key`, `Kind`, parâmetros |
| AnomalyRules (servidor) | `Anomaly`, `Signal`, `CorrectVerb`, `LikelyWrongVerb`, `Window`, `IsCritical` (só `ANM-007`, `Validate()` garante, DEC-074) |

### 3.18 Actions

| Campo | Exemplo |
|---|---|
| `Key` | `grill_place`, `grill_collect`, `bun_cut`, `board_add_sausage`, `board_add_topping`, `board_pickup`, `serve`, `take_order`, `refuse`, `restock`, `buy_package`, **`bench_buy_upgrade`**, **`bench_buy_item`**, `buy_trailer`, `brew_coffee`, `switch_light`, `hide`, `discard`, `safe_spot`, `open_sign`, **`pick_up_item`**, `party_join` |
| `Text`, `Hold`, `Radius`, `Night`, `Requires` | como na versão 1 (`pick_up_item`: "Pick Up", toque, 7 studs, FEAT-036) |

### 3.19 BossCalls, Cutscenes, Notices, Hallucinations, OpalLines

| Tabela | Campos |
|---|---|
| BossCalls | `Key`, `Lines` (`{ Text, Audio? }`), `Short` (versão curta), `Skippable = false` (DEC-077, `Q-077` b) |
| Cutscenes | `Key` (`none`, `intro`, `finale`, `credits`), `Duration`, `Skippable` (todas, por voto; FEAT-004). Troca de veículo e noite perdida **não** são cutscene: são transições no mundo, sem "Skip" (FEAT-004), dirigidas por `VehicleService` e `RunStateService`/`AmbulanceService`. Campos: `Marks` (nomes `CutsceneMark1..4` no mapa), `Beats` (lista `{ At, Kind = "MoveTo"/"LookAt"/"Line"/"Actor", Target }`) |
| Notices | `Key`, `Text` com `{value}`, `Kind`. Novas: `gems_gained`, `afk_no_gems`, `revive_credit_saved`, `revive_used`, `trailer_price`, `shift_ended_resume`, `shift_cant_resume`, `item_dropped` |
| Hallucinations | `Key`, `MinSanity`, `MaxSanity`, `Kind`, `Cooldown`, `Weight` (teto por `Q-043`) |
| OpalLines | `Phase` (`Day`, `N1_3`, `N4_6`, `N7_10`), `Lines` (CHR-003) |

## 4. Quem edita o quê

- **game-designer**: números e listas (preços, tempos, pesos, fases, classes, noites, bancada, revive, densidade de trânsito).
- **narrative-writer**: `Name`, `Text`, `Lines`, `Description`, falas da Opal, beats de fala das cutscenes.
- **art-director / modeler-3d**: `Icon`, `Look`, `ToolModel`, `Part`, modelos de carro e ambulância.
- **level-designer**: nomes de rota, parada, cruzamento, marca de cutscene, `BenchSpot`, `BuySpot` (autoria no mapa).
- **architect**: forma das tabelas, `Stat`, `Actions`, `Validate()`, `Products`.
- **usuário**: cria no Creator Hub o developer product e o badge e passa os ids.

Adicionar campo a uma tabela é mudança de contrato: passa pelo architect.
