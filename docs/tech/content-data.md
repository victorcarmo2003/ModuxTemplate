Status: Rascunho

# Dados de conteúdo (data-driven)

Autor: architect. **Versão 5, 2026-10-10 (pós onda 1):** §3.20 Animations, §3.21 Sounds/Music, §6 tabelas das
ondas 2–4 (Shift de noite, Nights, LightGroups, Sanity, Thief, BossCalls, Anomalies, Hallucinations, Cutscenes,
WalkPaths, campos novos, Actions/Notices novas). Contrato de código: `architecture.md` §19.
**v5.2, 2026-10-10 (DEC-221):** esconderijo sai, janela do trailer entra: `Actions` −`hide` −`get_up` +`shutter_toggle`;
`Notices` −`hide_taken` +`shutter_closed`; `Vehicles` −`HidePoints` +`HasShutter`; `Animations` −`hide`; `AnomalyRules`
N8/N9 com verbo `shutter` (§6.9, §6.10). Versão 4.1, 2026-10-10 (**TASK-003**: implementação em `src/Shared/Content/`, §1.5; DEC-215 na
tábua do trailer). Versão 4, 2026-10-10 (**TASK-001**: estado DEC-140 a DEC-201, núcleo da onda 1). Anterior: 3.1.
Formato das tabelas que game-designer, narrative-writer e level-designer preenchem e que o código só lê.
Base: DEC-044 ("parâmetros são tabela"), propostas das rodadas 1 e 2 (Aprovadas), fichas de `design/` e `story/`.
Números são **valores iniciais** (ajuste de número não exige DEC; mudança de regra exige).

> **Base Provisória (DEC-193).** Rascunho que vale para construir. Item sem DEC está marcado **Provisório**.
> Rede: `network.md` v4. Persistência: `data.md` v4.

Fichas de design (`ITM-###`, `UPG-###`, `NPC-###`, `CLS-###`, `ANM-###`) são a fonte; a tabela é a forma
executável. Toda linha tem `Ref` apontando para o ID da ficha.

---

## 0. O que mudou

### 0.0 Versão 4 (TASK-001; DEC-140 a DEC-201)

| Tabela | Mudança | Origem |
|---|---|---|
| **ItemRules** (nova, registro único) | `HotbarSlots = 4`; limites por categoria (pacote 2, HotDog 2, café 1, alterado 1, Revive Kit 1). Sai o campo por item `HotbarSlots` ("1, `Q-056`") | **DEC-174**, DEC-049, DEC-100, FEAT-005 |
| Items | + `Category`; sai `ToolModel` (convenção do kit); atributos de Tool (`Item`, `Count`, `Toppings`) | DEC-040, **DEC-190**, DEC-142 |
| Ingredients | + `Icon` (plaquinha `Label_<Ing>`, `Q-152` placeholder), + `Stack` (queijo antes dos cordões), + `Vehicle` | **DEC-156**, **DEC-142** |
| Stations | reescrita com as chaves do binding (TASK-002 §18.4): `sausage_stock`, `grill`, `rail`, `bun_crate`, `board`, `toppings`, `trash`; `Record` (`PerSlot`/`Single`/`None`), `RecordKeys` para o set; tábua `board` com 2 vagas | **DEC-190**, DEC-201, MAP-01 §7.1 |
| Upgrades | `Levels` **por veículo** (`cart`, `trailer`); trailer recomeça do nível 1; `Vehicles` lista onde o upgrade existe; `Parts` por veículo | **DEC-184** (`Q-163` Provisório nos preços) |
| Vehicles | + `RailSlots`, `BoardSlots`, `HasCoffee`/`HasSwitch`/`HasShutter` (era `HidePoints`, DEC-221), `CoveredAfter` (lona) | DEC-190, FEAT-006, DEC-189, DEC-199, DEC-221 |
| Classes | **chaves por animal** (`class_dog`…); + `Species`; 6 com `InMvp = true`; efeitos com `When` | **DEC-186**, DEC-147 |
| **Species** (nova) | 18 espécies (DEC-158), `Class`, `Customer`, `Pedestrian`, `ReservedFor` (guaxinim só Quentin) | **DEC-158, DEC-186, DEC-188**, DEC-159, DEC-192 |
| **Outfits** (nova) | `crew`, `civil_a`..`civil_h`, `thief`; packs disponíveis por roupa | DEC-148, DEC-159, DEC-160, DEC-161, DEC-166 |
| **Moods** (nova) | humor → expressão; onda 1 só visual (**Provisório**, `Q-164`) | DEC-162, DEC-187 |
| CustomerTypes | `Species` (lista), `Accessories`, `Outfits`; mapa da DEC-188 | **DEC-188** |
| Flow | `PartySource = "Connected"`, `RecalcOn = "ShiftStarted"` (Provisório) | **DEC-185** |
| Sanity | + `Bands` (≥ 60 / 40–59 / < 40) e `Look` (faixa → pack → rosto) | DEC-166, **DEC-167** |
| Actions | lista da onda 1; `topping_add` substitui `board_add_topping`; saem `board_pickup` e `party_join` | DEC-190, DEC-179 |
| Notices | chaves da onda 1 | FEAT-005, FEAT-015, FEAT-032, DEC-186 |

### 0.1 Versão 3.1 (DEC-130, rodada 17)

| Tabela | Mudança | Origem |
|---|---|---|
| Traffic | **sem semáforo**: sai `Crossings` (`CarGreen`, `WalkGreen`, `Offset`) e todo estado de sinal; entram `Conflicts` (zonas do cruzamento), `ConflictGap`, `RouteWeight`. Rotas `TR-1..TR-10` com `JS-IN/JS-OUT`; rota do Mart cruza a Juniper Sul em CW-1 | DEC-130 (revoga DEC-120), rodada 17, `MAP-01.md` revisão 3 |
| Traffic (DEC-133) | sai `CrossGap` (era da brecha sem parada); entram `Routes[].Stops` (PARE e linhas de faixa por rota), `Crosswalks[].Lines`, e a subtabela **`Traffic.Crossing`** (PARE 1 s, raio de reserva 15 studs, espera máx. 4 s, cooldown 4 s, spawn ≥ 55 studs, 3 s por faixa de rolagem, Juniper Sul 12–20 s por sentido, frenagem, fila) | DEC-133, FEAT-033 |
| NpcNodes (mapa) | nó de travessia ganha atributo `Crosswalk = "CW-n"`: NPC só cruza pista ali, com reserva (DEC-133) | `architecture.md` §8.1, T30 |

### 0.2 Versão 3

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

### 0.3 Versão 2

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

`Table.new(list)` devolve, congelado: `List`, `Keys` (lista de chaves para `Lync.enum`/`Lync.bitfield`), `ByKey`,
`IndexOf` (posição na `List`; é o id de registro de `Stock` e `Upgrades`).
Subconjuntos usados pela rede são **derivados no próprio módulo**, nunca escritos à mão: `Ingredients.ToppingKeys`
(`Kind` ∈ Sauce, Topping), `Stations.RecordKeys` (`Record ≠ "None"`), `Shift.PhaseKeys`.
Registro único (ex.: `RunParams`, `ItemRules`) é tabela simples congelada, sem `Table.new`.

### 1.3 Regras

1. **Chave é para sempre.** Perfil e snapshot guardam chaves; para mudar o texto, mude `Name`. Chave nova:
   minúsculas com `_` (`^[a-z][a-z0-9_]*$`); exceções já usadas em enums literais da rede (`"Day"`, `"Mid"`,
   `"Night"`, nomes de humor) são valores, não chaves de tabela.
2. Ordem livre entre versões. O **Lync ordena** os nomes de `enum`/`bitfield` antes de numerar (Lync 4.0.2): a ordem
   da tabela não chega ao fio; o código lê strings. `IndexOf` (ordem da `List`) só é usado como id de registro.
3. **Sem lógica na tabela.** Fórmulas viram parâmetros (`Base`, `PerK`).
4. **Efeitos por modificador** `{ Stat, Op, Value, Scope, When? }` sobre a lista fechada de `Stat` (§3.10).
5. Tempo em segundos reais; dinheiro em inteiros; distância em studs; preço em Robux **nunca** na tabela.
6. Texto de jogador em `Name`/`Text`/`Lines`.
7. Enum com sentinela (`none`) declara a sentinela **como linha da tabela** (por convenção a primeira; a posição não
   importa para o fio).
8. Ids de textura de personagem **não** ficam em `Content`: ficam em `src/Crew/shared/CrewLooks.luau` (TASK-006),
   indexados pelas chaves de `Species`, `Outfits` e pelos packs `Day`/`Mid`/`Night`. `Content` diz **o que existe**;
   `CrewLooks` diz **com que textura**.

### 1.4 Validação

`Validate()` ao requerer `Content` (< 1 ms): chave duplicada ou fora do padrão, referência quebrada (pacote →
ingrediente; ingrediente → estação; classe → espécie; tipo de cliente → espécie/roupa; noite → anomalia; bench →
item; rota → nó), número fora de faixa, enum vazio, efeito de classe sobre `Stat` de regra de anomalia,
**ProductId = 0 em produção** (aviso no Studio). Regras novas da v4:
- `Species` com `ReservedFor` não é `Class` de nenhuma classe nem aparece em `CustomerTypes` (guaxinim, DEC-186);
- toda classe tem `Species`, e essa espécie tem `Class` apontando de volta (1 ↔ 1);
- `Upgrades[k].Levels[v]` existe para todo `v` em `Upgrades[k].Vehicles`; `Levels[v][1].Price = 0` para upgrades de
  nível inicial (Grill, Cooler, Counter);
- `Ingredients[k].Capacity` tem uma entrada por nível de Cooler (`#Upgrades.cooler.Levels.cart`);
- `ItemRules.CategoryLimits` soma ≥ `HotbarSlots` não é erro (limites são por categoria; o total manda);
- `Moods` contém `Neutral`; toda `Expression` de `Moods` existe na lista fechada de expressões (§3.16).

Falha = `error` com tabela e linha (R8: enum ruim derruba o `Lync.start()`).

### 1.5 Implementação (TASK-003, v4.1)

O que o código em `src/Shared/Content/` fixou além do texto acima (forma decidida pelo architect; dono do arquivo
`init.luau` = TASK-003; as outras tasks de conteúdo editam só o próprio arquivo de tabela):

| Ponto | Forma |
|---|---|
| `Table` | `Table.new(list)` → `List`, `Keys`, `ByKey`, `IndexOf`, congelado em profundidade. `Table.with(t, extra)` acrescenta campos derivados ou registro único (`ToppingKeys`, `RecordKeys`, `PhaseKeys`, `Rules`, `Looks`). `Table.record(r)` congela registro único. `Table.keysWhere(t, pred)` deriva subconjunto de chaves. Duplicata não quebra o `new`: quem acusa é o `Validate` (com tabela e linha) |
| Exportados por `Content` | todas as tabelas da onda 1 + `ItemRules` (= `Items.Rules`), `Looks` (= `Outfits.Looks`), `MoodRules` (= `Moods.Rules`), `OrderPhases` (tabela de `Orders.luau`) e `OrderRules` (= `.Rules`), `Stats` (lista fechada da §3.10, `Stats.luau`, `Stats.Has[stat]`) |
| `Validate` | `Validate.luau` roda uma vez ao requerer `Content` (~0,2 ms medido); falha = `error("[Content] Tabela[linha] 'chave': motivo")`. Cobre as regras da §1.4 da onda 1, mais: todo ingrediente tem pacote; `Upgrades.BenchSpot` único; `KWeights` soma 1 e tem `MaxToppings + 1` entradas; `Actions.Requires` (`Held` = item ou categoria, `Phase` ⊆ `Shift`) |
| Chaves em PascalCase | só `Shift` (fases) e `Moods` (valores de enum da rede, regra §1.3); o resto segue `^[a-z][a-z0-9_]*$` |
| Ingredients | `OrderPrice` e `Weight` = 0 e `Stack = nil` em Base/Supply (o "—" das tabelas) |
| Stations | `Ingredient = Stations.PerAnchor` (`"PerAnchor"`) na estação de complementos |
| Actions | campo novo `Wave` (1ª onda com prompt ativo). `Requires` só carrega o que o client pré-checa (`Held`, `NotHasTopping`, `Phase`); o resto da coluna Requires da §3.18 é regra do servidor. `Held = "Package"` = categoria. `pick_up_item` = "Take", toque, ativo na onda 1 (N-03; item derrubado da onda 3 usa `PromptHold = 0.5` na âncora, FEAT-036) |
| Notices | campo novo `ValueFrom` (`None`, `Number`, `Ingredients`, `Upgrades`, `Classes`): diz ao client como ler `Notice.Value`. Placeholder `{class}` para as notices de classe |
| Upgrades | `Levels[veículo]` lista **todos** os níveis de `StartLevel` ao máximo, em ordem; a 1ª linha é o que o veículo traz (`Price = 0`; nível 0 de Cash Drawer Lock e Trailer Lights incluído, com os efeitos "sem upgrade") |
| CustomerTypes | `Role` (`Customer`/`Pedestrian`), `UnlockDay`/`UnlockNight`, `Weight = { Day, Night }`, `KShift = { Delta, Chance }`, `IngredientMult` por chave de topping; `pedestrian` com `Species = {}` (= qualquer espécie com `Pedestrian`) |
| OrderPhases | chaves `day_1`, `day_2_3`, `day_4_5`, `day_6_plus`, `night`; `ToDay = 0` = sem teto |
| OpalLines | chaves `day`, `n1_3`, `n4_6`, `n7_10` (+ `FromNight`/`ToNight`) |
| Stubs | `Classes`, `Species`, `Shift`, `Vehicles`, `Upgrades`, `RunParams`, `Flow`, `Orders`, `CustomerTypes`, `OpalLines` já saem com os números desta versão e de `upgrades.md`/`npcs.md`/FEAT-010 onde existiam; TASK-008/009 revisam e completam (nomes, falas, acessórios, noites) |

## 2. Mapa das tabelas

Coluna **Onda**: em que onda a tabela precisa estar completa. Na onda 1 (TASK-003) as tabelas marcadas "1 (stub)"
existem com `Keys` corretas e valores preenchidos nas TASK-008/009.

| Tabela | Arquivo | Fonte | Dono do conteúdo | Onda |
|---|---|---|---|---|
| RunParams | `RunParams.luau` | DEC-044, DEC-057, DEC-080, DEC-083, DEC-084, DEC-098, DEC-110, DEC-112, DEC-121 | game-designer (+ architect nos tempos técnicos) | 1 (stub → TASK-008) |
| Shift | `Shift.luau` | DEC-048 | game-designer | 1 (stub → TASK-008) |
| Ingredients | `Ingredients.luau` | DEC-071, DEC-142, DEC-156 | game-designer (+ art-director no `Icon`) | 1 |
| Packages | `Packages.luau` | DEC-049, DEC-071 | game-designer | 1 |
| Items, **ItemRules** | `Items.luau` | DEC-040, DEC-100, DEC-103, **DEC-174**, DEC-190 | game-designer | 1 |
| Stations | `Stations.luau` | DEC-016, DEC-046, DEC-055, **DEC-190**, DEC-201, MAP-01 §7.1 | game-designer + architect | 1 |
| Upgrades | `Upgrades.luau` | DEC-046, DEC-101, **DEC-184** | game-designer | 1 (stub → TASK-008) |
| Vehicles | `Vehicles.luau` | DEC-047, DEC-052, DEC-086, DEC-184, DEC-190 | game-designer | 1 (stub → TASK-008) |
| **Species** | `Species.luau` | **DEC-158, DEC-186, DEC-188**, DEC-159, DEC-192 | game-designer + art-director | 1 (stub → TASK-009) |
| **Outfits**, **Looks** | `Outfits.luau` | DEC-148, DEC-159, DEC-160, DEC-161, DEC-166, DEC-167 | art-director | 1 (TASK-003, completa: 10 roupas) |
| **Moods**, **MoodRules** | `Moods.luau` | DEC-162, DEC-187 (`Q-164`) | game-designer | 1 (TASK-003, Provisório) |
| MarketBench, BenchItems | `MarketBench.luau` | DEC-100, DEC-101, DEC-106, DEC-108, DEC-129 | game-designer (`Q-120`) | 4 |
| Flow | `Flow.luau` | DEC-045, **DEC-185** | game-designer | 1 (stub → TASK-008) |
| OrderPhases, OrderRules | `Orders.luau` | DEC-071, DEC-072 | game-designer | 1 (stub → TASK-008) |
| CustomerTypes | `CustomerTypes.luau` | `design/npcs.md`, **DEC-188** | game-designer + art-director | 1 (stub → TASK-009) |
| Thief | `Thief.luau` | DEC-050, DEC-182 | game-designer | 2 |
| Sanity | `Sanity.luau` | DEC-056, DEC-069, **DEC-166, DEC-167** | game-designer | 2 |
| Revive | `Revive.luau` | DEC-091 a DEC-094, DEC-102, DEC-115 a DEC-118, DEC-129 | game-designer | 4 |
| Ambulance | `Ambulance.luau` | DEC-091, DEC-114, DEC-122 | game-designer + level-designer | 4 |
| Traffic | `Traffic.luau` | DEC-087, DEC-095, DEC-103, DEC-130, DEC-133, DEC-198 | level-designer + game-designer | 3 |
| Products | `Products.luau` | DEC-092 | architect (ids do Creator Hub, pelo usuário) | 4 |
| Nights | `Nights.luau` | DEC-025, DEC-053, DEC-060, DEC-073, DEC-127 | game-designer + narrative-writer | 2 |
| Anomalies | `Anomalies.luau` | DEC-073, DEC-096, DEC-195 | game-designer + art-director | 3 |
| AnomalyRules (servidor) | `src/Anomaly/server/Rules/` | DEC-054, DEC-073, DEC-074 | game-designer | 3 |
| AnomalyCues | `AnomalyCues.luau` | `story/anomalies.md` | game-designer | 3 |
| BossCalls | `BossCalls.luau` | DEC-025, DEC-076, DEC-077 | narrative-writer | 2 |
| Cutscenes | `Cutscenes.luau` | DEC-021, DEC-075, DEC-078, DEC-088, DEC-194 | narrative-writer + level-designer | 4 |
| Classes | `Classes.luau` | DEC-069, DEC-070, **DEC-186** | game-designer | 1 (stub → TASK-009) |
| GemRewards | `GemRewards.luau` | DEC-070, DEC-083, DEC-084, DEC-104 | game-designer | 2 |
| Achievements | `Achievements.luau` | DEC-058, DEC-084 | game-designer + narrative-writer | 2 |
| Actions | `Actions.luau` | DEC-016, DEC-054, DEC-066, DEC-190 | architect + game-designer | 1 |
| Notices | `Notices.luau` | — | narrative-writer | 1 |
| Hallucinations | `Hallucinations.luau` | DEC-038, DEC-172, DEC-173 | game-designer + art-director | 2 |
| OpalLines | `OpalLines.luau` | DEC-079, CHR-003 | narrative-writer | 1 (stub → TASK-009) |

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
| `BaseWalkSpeed` | studs/s | 16 (classe sem efeito de velocidade) | DEC-069 |
| `StartVehicle` | chave de `Vehicles` | `cart` | DEC-007 |
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
| `ClockStepMinutes` | int | 5 (pedido do usuário 2026-10-11; era 10) |
| `PhaseKeys` | derivado | enum do set `Shift` |

Onda 1 (TASK-008): só as fases de dia têm números (Prep 60 s, Open 360 s, Closing ≤ 30 s, Summary 15 s); as de noite
existem como chave (o enum `PhaseKeys` já sai completo, o `Net` não muda na onda 2).

### 3.3 Ingredients

| Campo | Tipo | Exemplo (Ketchup) | Origem |
|---|---|---|---|
| `Key`, `Ref`, `Name` | | `ketchup`, `ITM-003`, "Ketchup" | |
| `Kind` | `"Base" \| "Sauce" \| "Topping" \| "Supply"` | `Sauce` | |
| `OrderPrice` | int | 1 | DEC-071 |
| `UnlockDay` | int (0 = depende de veículo) | 1 | DEC-071 |
| `Vehicle` | chave de `Vehicles` ou `nil` | `nil` (Coffee: `trailer`) | DEC-049, DEC-055 |
| `Weight` | number | 10 | DEC-071 |
| `Capacity` | `{ int }` por nível de Cooler | 30 / 50 / 75 | DEC-049, `items.md` |
| `Station` | chave de `Stations` | `toppings` | MAP-01 §7.1, `architecture.md` §18.4 |
| `Stack` | `"BeforeCords" \| "Cord" \| "InOrder"` | `Cord` | **DEC-142**: queijo sempre antes dos cordões (Ketchup, Mustard, Cream Cheese); o resto na ordem de montagem |
| `Icon` | asset id (`rbxassetid://…`); `""` = placeholder | `""` até `Q-152` | **DEC-156** |

A cobertura no kit é `ReplicatedStorage.Assets.Items.Toppings/<chave>` (convenção do §18.9.1, sem campo). A altura
(DEC-142) **não** fica aqui: é o atributo `TopHeight` no modelo do kit (medida da malha, TASK-007). `Stack` é a regra;
`TopHeight` é a medida.

| Key | Ref | Kind | OrderPrice | UnlockDay | Weight | Capacity (Cooler 1/2/3) | Station | Stack |
|---|---|---|---|---|---|---|---|---|
| `bun` | ITM-001 | Base | — | 1 | — | 12 / 20 / 30 | `bun_crate` | — |
| `sausage` | ITM-002 | Base | — | 1 | — | 12 / 20 / 30 | `sausage_stock` | — |
| `ketchup` | ITM-003 | Sauce | 1 | 1 | 10 | 30 / 50 / 75 | `toppings` | Cord |
| `mustard` | ITM-004 | Sauce | 1 | 1 | 10 | 30 / 50 / 75 | `toppings` | Cord |
| `cheese` | ITM-005 | Topping | 2 | 2 | 7 | 8 / 14 / 20 | `toppings` | BeforeCords |
| `bacon` | ITM-006 | Topping | 3 | 3 | 6 | 8 / 14 / 20 | `toppings` | InOrder |
| `potato_sticks` | ITM-007 | Topping | 2 | 4 | 6 | 15 / 25 / 35 | `toppings` | InOrder |
| `cream_cheese` | ITM-008 | Topping | 2 | 6 | 5 | 12 / 20 / 30 (2/3 **Provisório**, `Q-062`) | `toppings` | Cord |
| `coffee` | ITM-009 | Supply | — | 0 (`Vehicle = trailer`) | — | 20 / 20 / 20 | `coffee_machine` | — |

`ToppingKeys` = Sauce + Topping (6 chaves; bitfield de `Customers.Order`). Estoque inicial = capacidade do nível 1
(`RunParams.StartStockFull`, DEC-049). `Stock.Blocked` = `Day < UnlockDay` ou `Vehicle` diferente do atual.

### 3.4 Packages

| Campo | Exemplo |
|---|---|
| `Key`, `Ref`, `Name` | `pack_sausages`, `ITM-011`, "Sausages" |
| `Ingredient` | `sausage` |
| `Amount`, `Price` | 8, 6 |
| `Item` | chave em `Items` (`pack_sausages`) |

Linhas: `pack_sausages` (8, $6), `pack_buns` (8, $4), `pack_ketchup` (20, $4), `pack_mustard` (20, $4), `pack_cheese`
(6, $6), `pack_bacon` (6, $9), `pack_potato_sticks` (10, $5), `pack_cream_cheese` (8, $6), `pack_coffee` (10, $5)
(`items.md`, DEC-049, DEC-071). Limite de carga: `ItemRules.CategoryLimits.Package` (§3.5).

### 3.5 Items (Tools) e ItemRules

Toda Tool que vai à hotbar (DEC-040). A Tool no kit é `ReplicatedStorage.Assets.Items.Tools/<chave>` (convenção do
`architecture.md` §18.9.1; sai o campo `ToolModel`).

| Campo | Tipo | Exemplo (Hot Dog) |
|---|---|---|
| `Key`, `Ref`, `Name` | | `hot_dog`, `ITM-010`, "Hot Dog" |
| `Kind` | `"Package" \| "Consumable" \| "Product" \| "Revive" \| "Anomaly"` | `Product` |
| `Category` | chave de `ItemRules.CategoryLimits` | `HotDog` |
| `Stackable` | bool (contagem em atributo `Count`) | false |
| `DropOnHit` | `"Keep" \| "Lost" \| "Vanish"` | `Lost` (só a Tool equipada cai, DEC-103; FEAT-036) |
| `DropDespawn` | s ou `"NextShiftEnd"` | — |
| `KeepOnSpectate` | bool | false |

Linhas: um item por pacote (ITM-011…019, `Category = Package`, `Stackable = true`), `coffee` (ITM-009, `Coffee`),
`hot_dog` (ITM-010, `HotDog`), `altered_item` (ITM-020, `Altered`), `revive_kit` (ITM-021, `Revive`). Onda 1 usa os
9 pacotes e `hot_dog`; as demais linhas existem (o `Validate` cobre referências).

**Atributos de Tool** (escritos só pelo `ItemService`; contrato em `network.md` §7.1): `Item` (todas, chave), `Count`
(pacotes, café), `Toppings` (HotDog: chaves de `Ingredients` separadas por vírgula, na ordem de montagem, **DEC-190**,
DEC-142), `Altered` (HotDog, onda 3).

`ItemRules` (registro único):

| Campo | Valor | Origem |
|---|---|---|
| `HotbarSlots` | **4** (total de Tools por jogador; o 5º é bloqueado com "Hands full") | **DEC-174** |
| `CategoryLimits.Package` | 2 (modificado por `PackageLimit`: Urso 3, dentro das 4 vagas) | DEC-049, DEC-186 |
| `CategoryLimits.HotDog` | 2 | FEAT-005 (proposta; **Provisório**) |
| `CategoryLimits.Coffee` | 1 | FEAT-005 |
| `CategoryLimits.Altered` | 1 | FEAT-005, ITM-020 |
| `CategoryLimits.Revive` | 1 | DEC-100 |

### 3.6 Stations (estações da cozinha do veículo)

Chaves alinhadas ao binding da TASK-002 (`architecture.md` §18.4, §18.14 item 1): `StationKind` no `Model` com tag
`Station` = chave desta tabela. Gaveta/POS, placa OPEN, prateleiras e bancada do Mart **não** são estação (são
âncoras `Interactable` soltas, §18.4). O set `Stations` usa só as linhas com `Record ≠ "None"` (`RecordKeys`), com id
= `StationId × 100 + Slot` (`network.md` §3.5).

| Campo | Tipo | Exemplo (grelha) |
|---|---|---|
| `Key` | | `grill` |
| `Letter` | letra do MAP-01 §7.1 (documentação) | `G` |
| `Record` | `"PerSlot" \| "Single" \| "None"` | `PerSlot` |
| `Actions` | chaves de `Actions` com âncora nesta estação | `grill_collect` |
| `Ingredient` | chave de `Ingredients`, ou `"PerAnchor"` (atributo `Ingredient` em cada âncora), ou `nil` | `nil` |
| `Params` | números da própria estação (tempos e capacidades que dependem de nível ou veículo vêm de `Upgrades`/`Vehicles`) | — |

| Key | Letra | Record | Actions | Ingredient | Params / de onde vem o número | Módulo (`architecture.md` §18.12) |
|---|---|---|---|---|---|---|
| `sausage_stock` | S | None | `grill_place` ("Grill"), `restock` | `sausage` | — | `Grill.luau` |
| `grill` | G | PerSlot | `grill_collect` ("Collect") | — | vagas e tempo: `Upgrades.grill` (`GrillSlots` 2/3/4, `GrillTime` 12/10/8; DEC-046, **DEC-201**) | `Grill.luau` |
| `rail` | R | Single | — (consumido por `board_add_sausage`) | — | capacidade: `Vehicles[v].RailSlots` | `Rail.luau` |
| `bun_crate` | B | None | `bun_cut` ("Slice Bun"), `restock` | `bun` | `CutTime = 1.5` (FEAT-006) | `BunCrate.luau` |
| `board` | T | PerSlot | `board_add_sausage` ("Add Sausage", **um** prompt na tábua) | — | nº de vagas: `Vehicles[v].BoardSlots` (2 no carrinho, 3 no trailer; **DEC-190**, **DEC-215**) | `Board.luau` |
| `toppings` | K | None | `topping_add` ("Add {item}"), `restock` | `PerAnchor` | 6 complementos (tigela de inox ou garrafa; DEC-156, DEC-140); estado = `Stock` (`Amount`, `Blocked`) | `Toppings.luau` |
| `trash` | BIN-C | None | `discard` ("Throw Away") | — | — | `Trash.luau` |
| `coffee_machine` | C (trailer) | Single | `brew_coffee`, `restock` | `coffee` | `BrewTime = 6` (onda 2) | onda 2 |

`restock` é do núcleo do `KitchenService` (por `Ingredient`), não de módulo (§18.12 item 4).

### 3.7 Upgrades (nível por veículo, **DEC-184**)

| Campo | Tipo | Exemplo (Grill) |
|---|---|---|
| `Key`, `Ref`, `Name` | | `grill`, `UPG-001`, "Grill" |
| `Vehicles` | lista de chaves de `Vehicles` onde o upgrade existe | `{ "cart", "trailer" }` (Trailer Lights: `{ "trailer" }`) |
| `StartLevel` | int | 1 (Cash Drawer Lock e Trailer Lights: 0) |
| `Levels` | `{ [vehicle]: { { Level, Price, Effects, Part } } }` | `cart = { {1, 0, {GrillSlots=2, GrillTime=12}, "Grill_L1"}, {2, 60, {GrillSlots=3, GrillTime=10}, "Grill_L2"}, {3, 150, {GrillSlots=4, GrillTime=8}, "Grill_L3"} }`; `trailer` = mesma lista com peças do trailer |
| `UnlockDay` | int | 1 |
| `SoldAt` | `"Bench"` | Bench (DEC-101; sempre à venda, DEC-106) |
| `BenchSpot` | posição na bancada (`B1`..`B5`) | `B1` |

- `Effects` é mapa `{ [Stat]: valor absoluto do nível }` sobre a lista fechada de `Stat` (§3.10): `GrillSlots`,
  `GrillTime`, `StockCapacityLevel`, `QueueSize`, `PatienceBonus`, `DrawerOpenTime`, `StealPct`, `LightRadius`,
  `DayFlowBonus`.
- **Por veículo (DEC-184):** o estado da run guarda `Levels[vehicle][upgrade]`; o trailer nasce com `StartLevel` em
  tudo; comprar na bancada sobe o nível **do veículo atual**. Preços do trailer = preços do carrinho e Cash Drawer Lock
  recomprado no trailer: **Provisório** até `Q-163` (a, c); mudar é só número na linha `trailer`.
- Linhas: `grill` (UPG-001), `cooler` (UPG-002), `counter` (UPG-003), `cash_drawer_lock` (UPG-004), `trailer_lights`
  (UPG-005, só trailer, "Trailer only" na bancada antes). Coffee Machine (UPG-007) vem com o trailer, sem linha de compra.
- `Part`: nome da peça visível no modelo do veículo (DEC-052); grill = rolos por nível (DEC-201). Nomes com o
  art-director/level-designer (binding TASK-002).

### 3.8 Vehicles

| Campo | `cart` | `trailer` | Origem |
|---|---|---|---|
| `Ref`, `Name` | AST-026, "Corner Cart" | UPG-006 / AST-027, "Open Late Trailer" | DEC-139, DEC-141 |
| (modelo) | `Model` com tag `Vehicle`, `Vehicle = "cart"` no `Workspace` (T36; sai o campo `Model`) | idem, `"trailer"` | `architecture.md` §18.1, §18.14 |
| `HasNight` | false | true | DEC-007 |
| `RailSlots` | 6 | 8 | FEAT-006 |
| `BoardSlots` | **2** | **3** | **DEC-190**, **DEC-215** |
| `HasCoffee`, `HasSwitch`, `HasShutter` (v5.2; sai `HidePoints`) | false, false, false | true, true, true | DEC-125, DEC-189, DEC-221 |
| `BuyFromDay` | — | 5 | DEC-037 |
| `BuySpot` | — | o **próprio trailer** à venda no estacionamento (prompt `buy_trailer`). Fixo, fora da bancada (DEC-107) | DEC-107 |
| `CoveredAfter` | lona AST-043 na vaga do trailer depois da troca (DEC-199) | — | DEC-199 |

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

### 3.10 Classes e modificadores (**DEC-186**: animal = classe)

| Campo | Tipo | Exemplo (Gato) |
|---|---|---|
| `Key`, `Ref`, `Name`, `Description` | | `class_cat`, `CLS-003`, "Line Cook" (placeholder, narrative-writer), ... |
| `Species` | chave de `Species` | `cat` |
| `Tier`, `Price` | int (gemas) | 1, 45 |
| `InMvp` | bool | true |
| `Effects` | lista `{ Stat, Op = "Set" \| "Mul" \| "Add", Value, Scope = "Self" \| "Party", When?, WhenValue? }` | `{GrillTime, Mul, 0.85, Self}`, `{WalkSpeed, Set, 15, Self}` |

**Chaves por animal (decisão desta versão, pedida pela TASK-001):** `class_<espécie>`. O animal é a identidade
estável da classe (DEC-147: escolher o animal é escolher a classe); o nome ("Rookie", "Line Cook"…) é placeholder e
muda com o narrative-writer sem tocar em perfil. As chaves antigas `class_rookie`… nunca foram publicadas (sem
migração).

| Key | Ref | Species | Name (placeholder) | Tier | Price | InMvp | Effects | Origem |
|---|---|---|---|---|---|---|---|---|
| `class_dog` | CLS-001 | `dog` | "Rookie" | 0 | 0 | true | — (régua) | DEC-186; conta nova = Cachorro |
| `class_rabbit` | CLS-002 | `rabbit` | "Runner" | 1 | 45 | true | `{WalkSpeed, Set, 18}`, `{SanityStart, Set, 90}` | DEC-069, DEC-186 |
| `class_cat` | CLS-003 | `cat` | "Line Cook" | 1 | 45 | true | `{GrillTime, Mul, 0.85, Self}` (só salsichas que ele pôs), `{WalkSpeed, Set, 15}` | DEC-069, DEC-186 |
| `class_bear` | CLS-004 | `bear` | "Hauler" | 1 | 45 | true | `{PackageLimit, Set, 3}`, `{WalkSpeed, Set, 14, When = PackagesAtLeast, WhenValue = 3}` | DEC-069, DEC-186 |
| `class_fox` | CLS-005 | `fox` | "Hawker" | 2 | 120 | true | `{TipAmount, Set, 2, Self}`, `{TipWindow, Add, -4, Self}` | DEC-069, DEC-186 |
| `class_owl` | CLS-006 | `owl` | "Night Owl" | 2 | 120 | true | `{SanityStart, Set, 120}`, `{SanityMax, Set, 120}`, `{WalkSpeed, Set, 15, When = Day}` | DEC-069, DEC-186 |
| `class_panda` | CLS-007 | `panda` | "Barista" | 2 | 120 | false | `{CoffeeBrewTime, Set, 3, Self}`, `{CoffeeRestore, Set, 35, Self}`, `{SeeAnomalyLoss, Set, 8}` | DEC-069, DEC-186 (1ª atualização) |
| `class_lion` | CLS-008 | `lion` | "Shift Lead" | 3 | 180 | false | `{BossBonusPP, Add, 5, Party}` (não acumula), `{TipAmount, Set, 0, Self}` | DEC-069, DEC-186 (1ª atualização) |

- Velocidade base de quem não tem efeito: `RunParams.BaseWalkSpeed = 16` (DEC-069).
- `Scope = Self`: só nas ações do próprio jogador. "Pedido do dono" (Raposa, Leão) = pedido em que **ele fez o "Take
  Order"** (a janela de gorjeta começa ali, DEC-072) — **Provisório**, game-designer confirma em `classes.md`.
- Onda 1 implementa `WalkSpeed`, `GrillTime`, `PackageLimit`, `TipAmount`, `TipWindow` (TASK-017). `SanityStart`/
  `SanityMax` na onda 2; Panda e Leão fora do MVP.

Lista fechada de `Stat`:

| Stat | Lido por | Usam |
|---|---|---|
| `WalkSpeed` | `CharacterService` (Humanoid) | Coelho, Gato, Coruja (dia), Urso (com 3 pacotes) |
| `GrillTime`, `GrillSlots` | `Kitchen` | Gato, Grill |
| `StockCapacityLevel` | `Kitchen` | Cooler |
| `QueueSize`, `PatienceBonus` | `Customer` | Counter |
| `PackageLimit` | `Item` | Urso |
| `TipAmount`, `TipWindow` | `Economy`/`Customer` | Raposa, Leão |
| `SanityStart`, `SanityMax` | `Vital` | Coelho (90), Coruja (120) |
| `CoffeeBrewTime`, `CoffeeRestore`, `SeeAnomalyLoss` | `Kitchen`, `Vital` | Panda |
| `BossBonusPP` | `Economy` | Leão (Party, não acumula) |
| `DrawerOpenTime`, `StealPct` | `Thief` | Cash Drawer Lock |
| `LightRadius`, `DayFlowBonus` | `Vital`, `Customer` | Trailer Lights |

`When`: `"Always"` (padrão), `"Day"`, `"Night"`, `"PackagesAtLeast"` (com `WhenValue`). `Validate()`: nenhum `Stat`
toca regra de anomalia, chances, revive ou trânsito (guarda pay-to-win e DEC-069); guaxinim nunca é `Species` de
classe (DEC-186).

### 3.10a Species (nova; **DEC-158**, DEC-186, **DEC-188**)

| Campo | Tipo | Exemplo (Pinguim) |
|---|---|---|
| `Key`, `Name` | | `penguin`, "Penguin" |
| `Asset` | sufixo do kit (`AST-053_Animal_<Asset>`, texturas `T_Head_<Asset>[_Mid\|_Night]`) | `Penguin` |
| `Class` | chave de `Classes` ou `nil` | `nil` |
| `Customer` | bool: a espécie pode aparecer como cliente (DEC-188 a). Quais tipos a usam: `CustomerTypes.Species` | true |
| `Pedestrian` | bool: pode ser passante (NPC-019, onda 2) | true |
| `ReservedFor` | ID de personagem/NPC ou `nil` | `nil` (guaxinim: `NPC-007`) |

| Key | Asset | Class | Customer | Pedestrian | ReservedFor | Nota |
|---|---|---|---|---|---|---|
| `dog` | Dog | `class_dog` | true | true | — | jogável (MVP) |
| `rabbit` | Rabbit | `class_rabbit` | true | true | — | jogável (MVP) |
| `cat` | Cat | `class_cat` | true | true | — | jogável (MVP) |
| `bear` | Bear | `class_bear` | true | true | — | jogável (MVP) |
| `fox` | Fox | `class_fox` | true | true | — | jogável (MVP) |
| `owl` | Owl | `class_owl` | true | true | — | jogável (MVP) |
| `panda` | Panda | `class_panda` | true | true | — | classe da 1ª atualização |
| `lion` | Lion | `class_lion` | true | true | — | classe da 1ª atualização |
| `penguin` | Penguin | — | true | true | — | NPC-001 |
| `hamster` | Hamster | — | true | true | — | NPC-002 |
| `mouse` | Mouse | — | true | true | — | NPC-002 |
| `frog` | Frog | — | true | true | — | NPC-003 |
| `monkey` | Monkey | — | true | true | — | NPC-004 |
| `turtle` | Turtle | — | true | true | — | NPC-005 |
| `sheep` | Sheep | — | true | true | — | NPC-005 |
| `koala` | Koala | — | true | true | — | NPC-006 |
| `pig` | Pig | — | true (DEC-192, **a confirmar**) | true | — | sem tipo de cliente ainda (`Q-165`) |
| `raccoon` | Raccoon | — | **false** | false | `NPC-007` | só Quick Quentin (DEC-159, DEC-186) |

- Espécies jogáveis e o porco têm `Customer = true` (DEC-188 a, DEC-192), mas **nenhum tipo** da onda 1 os usa: onde
  aparecem é `Q-165` (game-designer). Na onda 1 o pool de clientes sai só de `CustomerTypes.Species`.
- Personagens com nome (Walt, Opal, médicos, Pickett, Raincoat Lady, Walker; DEC-178) usam espécie a definir
  (`Q-160`). Opal na onda 1: espécie **Provisória** (TASK-038).

### 3.10b Outfits e Looks (novas; DEC-148, 159, 160, 161, 166, 167)

`Outfits` (lista):

| Key | Ref | Arms | Packs | Use | Origem |
|---|---|---|---|---|---|
| `crew` | AST-053 (`AST-053_CrewTex`, `T_Crew_Uniform[_Mid\|_Night]`) | Uniform (manga) | Day, Mid, Night | Crew: só personagem de jogador; **nunca** NPC (DEC-188) | DEC-151, DEC-161, DEC-166 |
| `civil_a` … `civil_h` | AST-053/054 (`T_Civil_<X>[_Mid\|_Night]`) | Civil (`AST-053_CivilArms`) | Day, Mid, Night | Civil: clientes e passantes, sorteada por tipo (DEC-188) | DEC-160, DEC-163, DEC-166 |
| `thief` | AST-056 (`T_Civil_Thief_Day`, `AST-053_ThiefHat`, `T_Expr_Thief`) | Civil | **Day** | Reserved: NPC-007 | DEC-159, DEC-163 |

`Looks` (registro único):

| Campo | Valor | Origem |
|---|---|---|
| `Packs` | `{ "Day", "Mid", "Night" }` (valores do atributo `LookPack`, `network.md` §5.2) | DEC-166 |
| `PackFace` | `Day → Normal`, `Mid → Exhausted`, `Night → Normal_Night` (rosto da crew pela faixa) | DEC-166, DEC-167 |
| `Expressions` (lista fechada) | `Normal`, `Happy`, `Smile`, `Sad`, `Fainted`, `Skeptical`, `Exhausted`, `Stressed`, `Normal_Night` (+ `Thief`, só NPC-007). Nome = `SurfaceAppearance` em `ReplicatedStorage.CrewExpressions` (TASK-006) | DEC-152, DEC-162, DEC-166 |
| `NpcNeverUses` | `Fainted` em NPC (Provisório, DEC-187); `crew` em NPC | DEC-187, DEC-188 |

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

### 3.16 Flow, OrderPhases, OrderRules, CustomerTypes, Moods, Thief, Sanity

| Tabela | Campos |
|---|---|
| Flow | `BaseInterval` 22 · `GrowthPerDay` 0.08 · `GrowthCap` 0.40 · `PartyMult` {1.0, 1.6, 2.1, 2.5} · **`PartySource = "Connected"`** (jogadores conectados, DEC-185; substitui `ActiveAtShiftStart`) · `RecalcOn = "ShiftStarted"` (**Provisório**, DEC-185) · `Jitter` 0.25 · `MaxCustomersDay` 8 · `MaxCustomersNight` 6 · `MaxActorsNight` 3 · `MaxNpc` 12 (DEC-045; passantes fora ou dentro do teto: `Q-162`) · `DayWalkers` {6, 8} e `NightWalkers` {1, 2} (DEC-183, onda 2) · **`Adopt`** (passante vira cliente, TASK-163, **Provisório**, pedido do usuário 2026-10-11): `ChanceDay` 0,5 · `ChanceNight` 0,15 · `FromDay` 1 · `FromNight` 1 (0 = nunca à noite) · `MaxDistance` 60 (studs de Q5, plano XZ) · `MinGapSeconds` 8 · `NoticeLead` 0,8 s (o passante freia antes da tentativa) · `Beat` 0,6 s (de frente para o carrinho antes de andar) · `FirstDelay` {3, 5} s (1ª tentativa da fase de venda; antes era um intervalo inteiro). `Validate`: chances 0..1, `FromNight` 0..10, `MaxDistance` 0..200, `FirstDelay` = {min ≤ max} |
| OrderPhases | `{ FromDay, ToDay, IsNight, KWeights }` (FEAT-010) |
| OrderRules | `BasePrice` 4 · `MaxToppings` 3 · `NewIngredientBoost` 1.5 · `TipAmount` 1 · `TipWindowBase` 16 · `TipWindowPerK` 4 · `PatienceBase` 40 · `PatiencePerK` 5 · `IncompletePct` 50 (floor) · `GradeThresholds` {A 0.90, B 0.75, C 0.50} · `GradeBonusPct` {A 20, B 10, C 0, D 0} · `NoCustomerGrade = "C"` (DEC-051) |
| Thief | `ChanceByDay`, `MaxPerDay`, `WindowClock`, `LurkMax`, `ZoneRadius`, `ZoneEmptyTime`, **`ApproachTime` 4** (fixo; velocidade = distância ÷ 4, DEC-182), `OpenTime`, `StealPct`, `MinDrawer`, `CatchReward` (onda 2) |
| Sanity | `Start` 100 · `SeeAnomaly` −5 · `SeeTime` · `SeeAngle` · `SeeRange` · `RuleBroken` −35 · `DarkDelay` 3 · `DarkPerSecond` −1 · `Coffee` +25 · `CoffeeCooldown` 60 · `CoffeeBrew` 6 · `TrailerLightRadius` 18 · `BasicLampRadius` (lâmpada de fábrica do trailer, DEC-189; número com o game-designer) · **`Bands = { High = 60, Mid = 40 }`** (≥ 60 → `Day`, 40–59 → `Mid`, < 40 → `Night`; pontos absolutos, DEC-167) · `BandMinHold` 0 s (1 s se piscar no teste, **Provisório**, DEC-167) (onda 2) |

`CustomerTypes` (**DEC-188**; números com o game-designer, TASK-009):

| Campo | Tipo | Exemplo |
|---|---|---|
| `Key`, `Ref`, `Name` | | `office_worker`, `NPC-001`, "Office Worker" |
| `Species` | lista de chaves de `Species` (1–2 fixas) | `{ "penguin" }` |
| `Accessories` | lista de nomes de malha no kit `ReplicatedStorage.Assets.Crew` (nomes finais na TASK-006) | `{ "Acc_Badge", "Acc_Briefcase" }` |
| `Outfits` | lista de chaves de `Outfits` (só `civil_*`); sorteio uniforme | `{ "civil_a", "civil_c", "civil_e", "civil_g" }` |
| `Shift` | `"Day" \| "Night" \| "Any"` | `Day` |
| `WalkSpeed`, `Weight`, `IngredientMult`, `KShift`, `Lines` | como em `npcs.md` | |

| Key | Ref | Species | Acessório (DEC-188) |
|---|---|---|---|
| `office_worker` | NPC-001 | `penguin` | crachá + pasta |
| `student` | NPC-002 | `hamster`, `mouse` | mochila |
| `jogger` | NPC-003 | `frog` | fone |
| `construction_worker` | NPC-004 | `monkey` | capacete + colete |
| `grandparent` | NPC-005 | `turtle`, `sheep` | bengala |
| `night_shift_worker` | NPC-006 | `koala` | crachá de plantão |
| `pedestrian` | NPC-019 | qualquer `Species` com `Pedestrian = true` (inclui `pig`) | nenhum (onda 2) |

- `Validate()`: nenhum tipo usa `raccoon` nem `Outfits.crew`; toda espécie listada tem `Customer = true`.
- Variante = espécie × roupa (DEC-188); "nunca 2 clientes vivos com a mesma variante do mesmo tipo" é regra do
  `NpcService` (proposals-round-3 §3, **Provisório**).
- Espécies jogáveis e porco como cliente: `Q-165` (fora da onda 1).

`Moods` (**Provisório**, `Q-164`; onda 1 só visual, sem mexer no pagamento da DEC-072):

| Key | Expression | Quando (onda 1) |
|---|---|---|
| `Neutral` | `Normal` | chegada |
| `Happy` | `Happy` | venda Completo/Perfeito |
| `Annoyed` | `Skeptical` | resta ≤ `MoodRules.AnnoyedAt` da paciência |
| `Complaining` | `Stressed` | desistiu (paciência zerou), Errado, Refuse |

`MoodRules` (registro único): `AnnoyedAt = 0.33` (fração da paciência restante), `AffectsPay = false` (onda 1). O humor
dinâmico completo (DEC-187: sobe e desce, muda pagamento) acrescenta linhas e campos aqui; o `Net` não muda.

### 3.17 Nights, Anomalies, AnomalyCues, AnomalyRules

| Tabela | Campos |
|---|---|
| Nights | `Index` 1–10 · `Duration` (s; DEC-127: 1200, 1260, 1320, 1380, 1440, 1560, 1620, 1680, 1740, 1800) · `NewAnomaly` (chave ANM) · `IntroCall`, `RepeatCall` (versão curta, `Q-077` d) · `MaxSimultaneous` · `TrafficDensity` (override opcional, `Q-103`) |
| Anomalies (shared) | `Key` (`anm_blank_folks`…), `Ref` (`ANM-001`…`ANM-010`), `Actor` (`Customer`/`World`/`Ambient`/`Vehicle`), `Look`, `Scope` (`Party`/`PerPlayer`, DEC-073) |
| AnomalyCues | `Key`, `Kind`, parâmetros |
| AnomalyRules (servidor) | `Anomaly`, `Signal`, `CorrectVerb`, `LikelyWrongVerb`, `Window`, `IsCritical` (só `ANM-007`, `Validate()` garante, DEC-074) |

### 3.18 Actions

| Campo | Tipo | Exemplo |
|---|---|---|
| `Key` | | `topping_add` |
| `Text` | texto do prompt; `{item}` = `Name` do ingrediente da peça | "Add {item}" |
| `Hold` | s (0 = toque) | 1 |
| `Radius` | studs | 7 |
| `Requires` | `{ Held = chave de Items ou categoria, NotHasTopping = true?, Phase = {...}? }` | `{ Held = "hot_dog", NotHasTopping = true }` |
| `Night` | `"Any" \| "DayOnly" \| "NightOnly"` | Any |

Ações da **onda 1** (FEAT-005, FEAT-006, FEAT-007, FEAT-008, FEAT-011, FEAT-015):

| Key | Text | Hold | Radius | Requires | Origem |
|---|---|---|---|---|---|
| `open_sign` | "Open Shop" | 0 | 10 | `Phase = Prep` | FEAT-003 |
| `grill_place` | "Grill" | 0 | 7 | vaga livre, `Stock.sausage ≥ 1` | FEAT-006 |
| `grill_collect` | "Collect" | 0 | 7 | vaga `Ready`, trilho com espaço | FEAT-006 |
| `bun_cut` | "Slice Bun" | 0.5 | 7 | vaga da tábua livre, `Stock.bun ≥ 1` | FEAT-006, DEC-190 |
| `board_add_sausage` | "Add Sausage" | 0 | 7 | vaga da tábua `Ready`, trilho ≥ 1, vaga na hotbar (`HotDog` < 2 e total < 4) | FEAT-006, **DEC-190** |
| `topping_add` | "Add {item}" | 1 | 7 | `Held = hot_dog` sem o ingrediente, < 3 complementos, `Stock ≥ 1`, não `Blocked` | FEAT-006, DEC-072, DEC-156 |
| `discard` | "Throw Away" | 0.5 | 7 | `Held = hot_dog` (onda 3: ou `altered_item`) | FEAT-006, DEC-054 |
| `take_order` | "Take Order" | 0 | 10 | cliente `Ordering` em Q1 | FEAT-011 |
| `serve` | "Serve" | 0 | 10 | `Held = hot_dog`, cliente `Waiting` | FEAT-011, DEC-190 |
| `refuse` | "Refuse" | 1 | 10 | cliente em Q1 | FEAT-011 |
| `restock` | "Restock" | 1 | 7 | `Held` = pacote do ingrediente da peça | FEAT-007 |
| `buy_package` | "Buy {item} — ${price}" | 0.5 | 7 | não `Blocked` (senão a etiqueta "Out of stock" e **sem** prompt, DEC-180); limite de pacotes e hotbar | FEAT-008 |
| `bench_buy_upgrade` | "Buy {upgrade} — ${price}" | 1.5 | 7 | upgrade existe no veículo atual e não está no máximo ("Maxed" sem prompt) | FEAT-015, DEC-184 |
| `pick_up_item` | "Take" | 0 | 7 | vaga na hotbar (total < 4) e limite de pacotes; na onda 1 só o **pacote grátis** do dia de liberação (modelo de exibição, não `Tool`; `network.md` §7). Item derrubado (onda 3, FEAT-036) usa a mesma ação com `PromptHold = 0.5` na âncora. **Provisório** (N-03 do board, L-03 do QA) | DEC-071, FEAT-036 |

Chaves das ondas seguintes **já existem na tabela** (o enum do `Interact` e a checagem do binding, `architecture.md`
§18.7 item 3, precisam delas), sem prompt ativo na onda 1: `bench_buy_item` (S1 fica "Nothing special today"),
`buy_trailer` (2 s), `brew_coffee`, `give_coffee`, `switch_light`, `shutter_toggle` (v5.2; `hide`/`get_up` saem, DEC-221), `safe_spot`. **Saem:** `board_add_topping`
(complemento é na estação, não na tábua), `board_pickup` (o HotDog nasce na mão, DEC-190), `party_join` (plataforma
física, DEC-179). Lixeira de rua (DEC-200) reaproveita `discard` (o que aceita: `Q-166`).

### 3.19 BossCalls, Cutscenes, Notices, Hallucinations, OpalLines

| Tabela | Campos |
|---|---|
| BossCalls | `Key`, `Lines` (`{ Text, Audio? }`), `Short` (versão curta), `Skippable = false` (DEC-077, `Q-077` b) |
| Cutscenes | `Key` (`none`, `intro`, `finale`, `credits`), `Duration`, `Skippable` (todas, por voto; FEAT-004). Troca de veículo e noite perdida **não** são cutscene: são transições no mundo, sem "Skip" (FEAT-004), dirigidas por `VehicleService` e `RunStateService`/`AmbulanceService`. Campos: `Marks` (nomes `CutsceneMark1..4` no mapa), `Beats` (lista `{ At, Kind = "MoveTo"/"LookAt"/"Line"/"Actor", Target }`) |
| Notices | `Key`, `Text` com `{value}` (ou `{item}`/`{upgrade}` quando `Value` é `IndexOf` de tabela), `Audience = "Player" \| "Party"`. **Onda 1:** `hands_full` ("Hands full", FEAT-005), `package_limit`, `not_enough_cash`, `upgrade_bought` ("{upgrade} upgraded!", Party, FEAT-015), `ingredient_unlocked` (Party, FEAT-032), `class_bought`, `class_selected`, `not_enough_gems`, `class_locked` (DEC-186). Ondas seguintes: `gems_gained`, `afk_no_gems`, `revive_credit_saved`, `revive_used`, `trailer_price`, `shift_ended_resume`, `shift_cant_resume`, `item_dropped`, `special_on_bench`. Textos placeholder até `ui-text.md` (narrative-writer) |
| Hallucinations | `Key`, `MinSanity`, `MaxSanity`, `Kind`, `Cooldown`, `Weight` (teto por `Q-043`) |
| OpalLines | `Phase` (`Day`, `N1_3`, `N4_6`, `N7_10`), `Lines` (CHR-003) |

### 3.20 Animations (v5; `architecture.md` §19.20, T47; `Q-167`)

Animações do rig IK do usuário, exportadas como `Animation` R6 e enviadas ao grupo. A tabela só guarda id e uso; quem
toca é o `AnimController` (client) e o `Animate` do personagem (crew).

| Campo | Tipo | Exemplo |
|---|---|---|
| `Key` | | `crew_walk` |
| `Id` | `rbxassetid://…` ou `""` (vazio = fallback: locomoção R6 padrão do Roblox; one-shot não toca) | `""` até o upload |
| `Rig` | `"Crew" \| "Npc" \| "Actor"` | `Crew` |
| `Looped` | bool | false |
| `Priority` | nome de `Enum.AnimationPriority` | `Action` |
| `FadeTime`, `Speed` | s, multiplicador | 0.15, 1 |
| `Ref` | AST-### / DEC | `AST-069`, DEC-202 |

`Locomotion` (registro único): conjunto → papel → chave da linha. Papéis: `idle`, `walk`, `run`, `jump`, `fall`,
`climb`, `sit`.

| Conjunto | Usado por |
|---|---|
| `crew` | personagem do jogador (`Animate` R6, gravado pelo `CharacterService`) |
| `npc` | clientes, ladrão, passantes (client, T47) |
| `walt` | Walt na cutscene final (andar corcunda com bastão, DEC-202) |
| `medic` | médicos (onda 4) |
| `walker` | Walker (ANM-007, DEC-212) |

Lista inicial (Provisória, `Q-167`; ids vazios até o upload):

| Rig | Chaves |
|---|---|
| Crew | `crew_idle`, `crew_walk`, `crew_jump`, `crew_fall`, `get_up` (atropelado levanta, 0,5 s), ~~`hide`~~ (sai, DEC-221), `drink` (1,5 s), `give`, `answer_phone` (loop), `wave_skip` (voto da cutscene, opcional) |
| Npc | `npc_idle`, `npc_walk`, `npc_wait` (impaciente, loop), `npc_happy`, `npc_complain`, `npc_refuse_leave`, `thief_sneak`, `thief_open` (loop), `thief_flee` |
| Actor | `opal_idle` (hoje id fixo no `OpalController`), `walt_walk`, `walt_offer_coffee`, `medic_walk`, `medic_carry`, `medic_lift`, `walker_step`, `waver_wave` (silhueta da janela, N6), `copy_backwalk` (N4), `raincoat_idle` |

`Validate`: `Id` vazio ou `rbxassetid://<n>`; toda chave de `Locomotion` existe na lista com o `Rig` certo.

### 3.21 Sounds, Music e SoundRules (v5; `architecture.md` §19.21, T55; `Q-168`)

`Sounds` (lista):

| Campo | Tipo | Exemplo |
|---|---|---|
| `Key` | | `phone_ring` |
| `Id` | `rbxassetid://…` ou `""` (silêncio, sem erro) | `""` até `Q-168` |
| `Group` | `"Music" \| "Ambient" \| "Sfx" \| "Voice" \| "Ui"` | `Sfx` |
| `Volume` | 0–1 | 0.6 |
| `Looped` | bool | true |
| `Spatial`, `MaxDistance` | bool, studs | true, 60 |
| `Ref` | AST-### / licença em `credits.md` | — |

`Music` (cues): `{ Key, Sound (chave de Sounds), When = { IsNight: boolean?, Phase: { string }?, Window: string? },
FadeIn, FadeOut, Priority }`. O `AudioController` toca a cue de maior `Priority` cuja condição vale; `PushMusic`
sobrepõe (cutscene, final).

`SoundRules` (registro): `MaxVoices = 12` (`architecture.md` §12.5), `DuckOnCall = 0.3`, `SirenMaxVolume` (DEC-005),
`ScareMaxVolume` (DEC-173).

Lista inicial (Provisória, `Q-168`):

| Grupo | Chaves |
|---|---|
| Music | `music_lobby`, `music_day`, `music_night_calm`, `music_night`, `music_finale`, `music_credits` |
| Ambient | `amb_day_street`, `amb_night_street`, `amb_mart_hum`, `amb_clock_tick` (C-01), `amb_fog` (N10) |
| Sfx | `grill_sizzle`, `bun_slice`, `topping_squirt`, `topping_sprinkle`, `restock`, `coin`, `drawer`, `buy`, `upgrade_done`, `trash`, `coffee_brew`, `coffee_drink`, `switch_click`, `phone_ring`, `phone_pickup`, `car_engine`, `car_honk_soft`, `hit_boing`, `siren_soft`, `door_knock`, `door_creak`, `curtain`, `post_buzz`, `post_tunk`, `walker_step`, `smoke_poof`, `splash`, `whisper`, `thief_open`, `thief_caught`, `faint`, `revive` |
| Ui | `toast`, `summary`, `prompt_done`, `skip_vote` |
| Voice | (vazio no MVP: legenda sem voz) |

### 3.22 Mart (registro único; Mart v2 "Gear Stand", TASK-135, Provisório)

`src/Shared/Content/Mart.luau`, exposto como `Content.Mart`. Fonte: FEAT-015 v2, `MAP-01.md` §18.4/§18.5; `Q-175`,
`Q-176`, `Q-177` com a recomendação A. Só apresentação e quando o quiosque atende: preço, efeito e rotação seguem em
`Upgrades` (DEC-101, DEC-106). Nenhuma rede nova: a porta é derivada da fase do set `Shift`.

| Campo | Valor | Quem lê |
|---|---|---|
| `KioskClosedPhases` | `Summary`, `Call`, `NightLost`, `Resume`, `Intro`, `Finale`, `RunEnd` | `MarketService` (recusa e prompts), `MarketController` (porta), `OpalController` (sem balão) |
| `Pedestals` | `B1`..`B5` (`Offer = "Upgrade"`, via `Upgrades.BenchSpot`), `S1` (`"Special"`), da esquerda para a direita | `MarketController`, `Required.Kiosk` |
| `Doors` | `L` = B1–B3, `C` = balcão da Opal, `R` = B4, B5, S1 (ordem = defasagem) | `Kiosk.luau`, `Required.Kiosk` |
| `Door` | `CloseTime` 2,0 · `OpenTime` 1,6 · `Stagger` 0,25 | `Kiosk.luau` |
| `Mini` | `Size` 1,6 · `Lift` 1,2 · `Bob` 0,25 · `BobPeriod` 3 · `SpinPeriod` 8 · `ActiveRadius` 60 · `LockedTransparency` 0,5 | `Minis.luau` |
| `Purchase` | `PopTime` 0,4 · `PopScale` 1,3 · `PopTurns` 1 · `Confetti` 14 · `RiseDelay` 0,5 · `RiseTime` 0,6 · `OpalLineGap` 20 · `OpalLineRadius` 12 | `Minis.luau`, `MarketController` (os dois `OpalLine*` ficam para o pool `Purchase`, TASK-142) |
| `Plate` | `Distance` 45 | `MarketController` (`BenchCard` modo placa) |
| `Tags` | `Pedestal = "GearPedestal"`, `Shutter = "GearShutter"`, `Slot = "Slot"` | client, `Required.Kiosk` |
| `Fallback` | `DoorHeight` 7 · `DoorAhead` 1 · `AnchorHeight` 4,2 · `Margin` 1,5 | porta de teste gerada no client quando o mapa não tem `GearShutter` |

`Validate` (`checkMart`): toda fase fechada existe em `Shift`, sem repetição; cada `Upgrades.BenchSpot` tem pedestal e
vice-versa; exatamente 1 pedestal `Special`; pedestal atrás de no máximo uma porta; números dentro de faixa.

## 4. Quem edita o quê

- **game-designer**: números e listas (preços, tempos, pesos, fases, classes, noites, bancada, revive, densidade de trânsito).
- **narrative-writer**: `Name`, `Text`, `Lines`, `Description`, falas da Opal, beats de fala das cutscenes.
- **art-director / modeler-3d**: `Icon`, `Part`, `Outfits`, `Accessories` de `CustomerTypes`, modelos de carro e ambulância; ids de textura em `CrewLooks.luau` (TASK-006).
- **level-designer**: nomes de rota, parada, cruzamento, marca de cutscene, `BenchSpot`, `BuySpot` (autoria no mapa).
- **architect**: forma das tabelas, `Stat`, `Actions`, `Validate()`, `Products`.
- **usuário**: cria no Creator Hub o developer product e o badge e passa os ids.

Adicionar campo a uma tabela é mudança de contrato: passa pelo architect.

## 5. Provisórios desta versão (v4)

| Item | Onde | Fecha em |
|---|---|---|
| Capacidade do Cream Cheese nos níveis 2/3 (20/30) | §3.3 | `Q-062` |
| `CategoryLimits.HotDog = 2` | §3.5 | game-designer (FEAT-005) |
| Preços do trailer = carrinho; Cash Drawer Lock recomprado | §3.7 | `Q-163` (a, c) |
| "Pedido do dono" = quem fez o Take Order (Raposa, Leão) | §3.10 | game-designer (`classes.md`) |
| `Flow.RecalcOn = "ShiftStarted"` | §3.16 | DEC-185 (parte Provisória) |
| `Moods`/`MoodRules` da onda 1 (só visual) | §3.16 | `Q-164` |
| Espécies jogáveis e porco sem tipo de cliente | §3.10a | `Q-165`, DEC-192 (a confirmar) |
| Nomes de malha de acessório e de peça (`Acc_*`, `Part`) | §3.7, §3.16 | TASK-002/TASK-006 (kits; acessório em `Assets.Crew.Accessories/<chave>`, §18.9.1) |
| `Sanity.BandMinHold` | §3.16 | teste da onda 2 |

## 6. Ondas 2–4: tabelas novas e mudanças (versão 5)

Contrato de código: `architecture.md` §19. Cada onda abre com a task de contrato (W2-0, W3-0, W4-0) que cria os
arquivos de tabela com `Keys` certas e números iniciais; o dono do conteúdo (coluna da §2) revisa depois sem tocar no
`init.luau`. Números de design aqui são os das fichas; ajustar número não exige DEC.

### 6.1 Mapa (onda em que a tabela entra no `init.luau`)

| Tabela | Arquivo | Onda | Gera enum de rede? | Dono do conteúdo |
|---|---|---|---|---|
| Shift (mudança) | `Shift.luau` | 2 | `PhaseKeys` (sem mudança de chave) | game-designer |
| Nights | `Nights.luau` | 2 | não | game-designer + narrative-writer |
| LightGroups | `LightGroups.luau` | 2 | não (id = `IndexOf`) | game-designer + level-designer |
| Sanity | `Sanity.luau` | 2 | não | game-designer |
| Thief | `Thief.luau` | 2 | não | game-designer |
| BossCalls, BossCallRules | `BossCalls.luau` | 2 | `Call.Call` | narrative-writer (falas) + game-designer (gatilhos) |
| GemRewards, Achievements | `GemRewards.luau`, `Achievements.luau` | 2 | não | game-designer |
| Animations | `Animations.luau` | 2 | não | usuário (ids) + art-director (lista) |
| Sounds, Music, SoundRules | `Sounds.luau` | 2 | não | art-director + usuário (ids, licença) |
| Actions, Notices (linhas novas) | existentes | 2–4 | `Interact.Action`, `Notice.Kind` | architect + narrative-writer |
| Vehicles, Items, RunParams, Flow, Stations (campos novos) | existentes | 2 | não | game-designer |
| Anomalies, AnomalyCues | `Anomalies.luau` | 3 | `Anomalies.Anomaly`, `AnomalyCue.Cue` | game-designer + narrative-writer |
| AnomalyRules (servidor) | `src/Anomaly/server/AnomalyService/Rules/` | 3 | não | game-designer |
| Hallucinations | `Hallucinations.luau` | 3 | não | game-designer + art-director |
| Cutscenes | `Cutscenes.luau` | 3 | `Cutscene.Scene` | narrative-writer + level-designer |
| Traffic | `Traffic.luau` | 3 | não | level-designer + game-designer |
| WalkPaths | `WalkPaths.luau` | 3 | não (id = `IndexOf`) | level-designer |
| Revive, Ambulance, Products, MarketBench/BenchItems, PartyConfig | — | 4 | `Bench.Item` | game-designer / architect |

### 6.2 Shift (mudança de forma)

Campos novos por linha: `Selling: boolean` (nasce cliente, gaveta conta), `SkipWithoutProbe: boolean`,
`Night: { Duration, ClockFrom, ClockTo }?` (override no turno de noite). `Closing` passa a `Kind = "Any"`.

| Key | Duration (dia / noite) | Relógio dia | Relógio noite | Selling | SkipWithoutProbe |
|---|---|---|---|---|---|
| `Resume` | 15 | parado | parado | não | não |
| `Intro` | 50 (cap) | 7:00 AM | — | não | **sim** |
| `Call` | — / 60 (cap) | — | 7:00 PM parado | não | **sim** |
| `Prep` | 60 / **90** | 7→8 AM | 7→8 PM | não | não |
| `Open` | 360 / — | 8 AM→6 PM | — | **sim** | não |
| `Night` | — / `Nights[k].Duration` | — | 8 PM→6 AM | **sim** | não |
| `NightEnd` | — / 3 | — | 6:00 AM | não | não |
| `Closing` | ≤ 30 / ≤ 30 | 6 PM | 6 AM | não | não |
| `Summary` | 15 / **20** | parado | parado | não | não |
| `NightLost` | — / 6 | — | parado | não | não |
| `Finale` | — / 150 (cap) | — | 6 AM | não | **sim** |
| `RunEnd` | 15 | parado | parado | não | não |

### 6.3 Nights

| Campo | Tipo | Valor inicial | Origem |
|---|---|---|---|
| `Index` | 1..10 | — | DEC-060 |
| `Duration` | s (8 PM → 6 AM) | 1200, 1260, 1320, 1380, 1440, 1560, 1620, 1680, 1740, 1800 | DEC-127 |
| `NewAnomaly` | chave de `Anomalies` | `anm_001_blank_folks` … `anm_010_hush` | DEC-073 |
| `Call`, `ShortCall` | chaves de `BossCalls` | `call_night_<N>`, `call_night_short` | FEAT-018 |
| `MaxSimultaneous` | int | 1, 1, 1, 2, 2, 2, 2, 3, 3, 3 | FEAT-022 |
| `MinGap` | s | 60 (1–4), 40 (5–7), 25 (8–10) | FEAT-022 |
| `Customers` | `{ BaseInterval, Max }` | Max 6 (`Flow.MaxCustomersNight`); intervalo com o game-designer | FEAT-009 |

Registro `Nights.Windows` (minutos de jogo): `Calm = { 1200, 1260 }`, `Shift = { 1260, 1740 }`,
`Last = { 1740, 1800 }` (FEAT-003). Registro `Nights.Occurrences`: `Premiere = 3`, `Recent = 2` (1–2 noites depois),
`Old = 1` (`progression.md` §4.2). `Validate`: 10 linhas, `Duration` crescente, toda `NewAnomaly` existe.

### 6.4 LightGroups

| Key | Kind | Condição (além de ser noite) | HushOff | Outros |
|---|---|---|---|---|
| `mart` | `Always` | — | **false** (nunca apaga, ANM-010) | zonas LZ-4, LZ-5 |
| `trailer_interior` | `Switch` | veículo atual `trailer` e interruptor ligado | true | LZ-1, LZ-2; `Cooldown = 0.5` (FEAT-020) |
| `trailer_lights` | `Upgrade` | idem + `trailer_lights` ≥ 1 | true | LZ-3; raio = efeito `LightRadius` (18) |
| `juniper_posts` | `Posts` | — (visual; volume só se marcado, DEC-196) | true | `Step = 1.5` (s por poste no Hush, MAP-01 §5.6) |

### 6.5 Sanity (completa a §3.16)

Campos novos: `DarkPhases = { "Call", "Prep", "Night", "NightEnd" }`, `SeeAngle = 40` (graus, cone total),
`SeeTime = 1` (s acumulado), `SeeRange = 60` (padrão; por anomalia em `Anomalies.ViewRange`), `RuleBroken = 35`,
`CoffeeDrinkTime = 1.5`, `CoffeeNightOnly = true` (Provisório, `Q-170`). `Bands`, `BandMinHold` como na §3.16.

### 6.6 Thief (completa a §3.16; DEC-050, DEC-182)

| Campo | Valor inicial |
|---|---|
| `ChanceByDay` | `{ [1] = 0, [2] = 0.5, Default = 0.7 }` |
| `MaxPerDay` | 1 |
| `WindowClock` | `{ 540, 900 }` (9 AM–3 PM) |
| `LurkMax` | 120 |
| `ZoneRadius`, `ZoneEmptyTime` | 14, 3 |
| `ApproachTime` | 4 (fixo, DEC-182) |
| `OpenTime`, `StealPct` | do efeito do Cash Drawer Lock (`DrawerOpenTime` 8/16, `StealPct` 50/30) |
| `MinDrawer`, `CatchReward` | 5, 5 |
| `Lurks`, `Spawn`, `Exits` | `{ "L1", "L2", "L3" }`, `"ST-R"`, `{ "ST-R", "EX-E" }` (MAP-01 §5.3) |

### 6.7 BossCalls e BossCallRules (FEAT-018; `script.md`)

| Campo | Tipo | Exemplo |
|---|---|---|
| `Key` | | `call_night_3` (sentinela `none`) |
| `Lines` | `{ { Text, Speaker? } }` | `{ { Text = "Keep an eye on the bank clock." } }` |
| `Trigger` | `{ Kind = "DayPrep" \| "DayInfinite" \| "NightCall" \| "NightRepeat" \| "TrailerBought" \| "LostCritical" \| "LostLastChance" \| "RunOver" \| "Hint", Day?, Night?, Action?, Variant? }` | `{ Kind = "NightCall", Night = 3 }` |
| `Priority` | 1 (baixa) .. 4 (máxima) | 4 |
| `Once` | bool (uma vez por run) | true |

`BossCallRules`: `LineTime = 2.5`, `AutoAnswer = 15`, `DayMaxLines = 7`, `NightMaxSeconds = 45`. Hints:
`Trigger.Action` = chave de `Actions` cuja 1ª execução na run dispara a dica (via `InteractionService.Performed`).
`Validate`: cada noite tem `NightCall`; existe exatamente um `NightRepeat`; nenhuma linha passa do teto de tempo.

### 6.8 Vehicles, Items, RunParams, Flow, Stations, Revive (campos novos)

| Tabela | Campo novo | Valor |
|---|---|---|
| `Vehicles.trailer` | `Reminder = { FirstDay = 5, Every = 3 }` | FEAT-017 |
| `Items` | `DropDespawn` dos pacotes e do `revive_kit` | **60 s** na rua (FEAT-036, DEC-197; era 120); `"NextShiftEnd"` no balcão (`DROP-T`) |
| `Items.coffee` | `Use = true` (ativa) | FEAT-021 |
| `RunParams` | `BindingWave` | 1 → 2 → 3 (qual `Required.Wave*` o `PlaceService` valida) |
| `Flow` | `NightInterval` (base do fluxo de noite) | com o game-designer (FEAT-009) |
| `Stations.coffee_machine` | `Params.BrewTime = 6` | FEAT-021 (Barista 3 pela classe) |
| `Revive` | `BodyFallback = 20` | s até o corpo sumir sem ambulância (ondas 2–3, T54) |

### 6.9 Actions e Notices (linhas novas)

Actions:

| Key | Text | Hold | Radius | Night | Wave | Nota |
|---|---|---|---|---|---|---|
| `answer_phone` | "Answer" | 0 | 7 | Any | 2 | **nova**; FEAT-018 |
| ~~`get_up`~~ | — | — | — | — | — | **sai (v5.2, DEC-221)**: sem esconderijo não há "levantar". O clipe `get_up` de `Animations` fica (atropelamento) |
| `brew_coffee` | "Brew Coffee" / "Take Coffee" (`PromptText`) | **1** (era 0) | 7 | Any | 2 | FEAT-021 |
| `give_coffee` | "Give" | **0.5** (era 0) | 7 | NightOnly | 2 | FEAT-021 |
| ~~`hide`~~ | — | — | — | — | — | **sai (v5.2, DEC-221)** |
| `shutter_toggle` | "Close Window" / "Open Window" (`PromptText` pelo estado; placeholder até o `ui-text.md`) | **0.5** | 7 | NightOnly | 3 | **nova (v5.2)**; FEAT-023, DEC-221; âncora `Prompt_Shutter`; dono `VehicleService`; cooldown 1 s no `Validate` (não é campo da tabela) |
| `safe_spot` | — | — | — | — | — | fica na tabela (enum), **sem prompt**: o ponto seguro é zona (`Text` = "Safe Spot", só rótulo de debug; era "Hide", TASK-133) |

Notices (`Audience`, `ValueFrom`):

| Key | Text (placeholder) | Audience | ValueFrom | Onda |
|---|---|---|---|---|
| `trailer_available` | "The old trailer is for sale! Check the parking lot." | Party | None | 2 |
| `trailer_waiting` | "The trailer is still waiting in the lot." | Party | None | 2 |
| `trailer_bought` | "Trailer bought! It's yours after this shift." | Party | None | 2 |
| `gems_gained` | "+{value} gems" | Player | Number | 2 |
| `afk_no_gems` | "No gems today: serve at least 3 orders." | Party | None | 2 |
| `achievement` | "{achievement} unlocked!" | Player | Achievements | 2 |
| `thief_caught` | "Nice catch! +${value}" | Party | Number | 2 |
| `coffee_cooldown` | "Wait {value}s for another coffee" | Player | Number | 2 |
| `coffee_full` | "You're wide awake" | Player | None | 2 |
| ~~`hide_taken`~~ | — | — | — | **sai (v5.2, DEC-221)** |
| `shutter_closed` | "The window is closed." (placeholder) | Player | None | 3 (v5.2; recusa de corrida do gate `Shutter`, FEAT-005) |
| `revive_used`, `revive_credit_saved`, `special_on_bench`, `shift_cant_resume`, `not_in_roster` | `ui-text.md` | conforme | conforme | 4 |

`Notices.ValueFrom` ganha `"Achievements"`. Textos finais: narrative-writer (`ui-text.md`).

### 6.10 Anomalies, AnomalyCues, AnomalyRules (onda 3)

`Anomalies` (shared; **sem** verbo nem prazo, T10):

| Campo | Tipo | Exemplo (ANM-007) |
|---|---|---|
| `Key`, `Ref`, `Name` | | `anm_007_walker`, `ANM-007`, "The Walker" |
| `Night` | 1..10 (estreia) | 7 |
| `Actor` | `"Customer" \| "Street" \| "Vehicle" \| "World" \| "Audio" \| "Item"` | `Street` |
| `NpcCost` | 0 ou 1 (teto de 3 atores à noite) | 1 |
| `Scope` | `"Party" \| "PerPlayer"` (DEC-204: sinal para todos; penalidade por jogador) | `Party` |
| `ViewRange`, `SeeMode` | studs, `"Cone" \| "AudioZone"` | 300, `Cone` |
| `ExclusiveWith` | chaves | — |
| `Scripted` | `{ Night, Clock }?` | `{ Night = 10, Clock = 1785 }` (5:45 AM) |
| `Tension` | bool: liga o clima Night e a rua deserta (`Q-159`, `Q-162`; Provisório) | true |

`AnomalyCues`: lista de chaves de efeito instantâneo (`blank_coin`, `smoke`, `clock_stop`, `clock_resume`,
`mirror_smile`, `raincoat_drip`, `waver_more`, `post_buzz`, `post_flicker`, `walker_step`, `car_highbeam`,
`car_honk`, `trailer_blackout`, `knock`, `door_crack`, `hush_fog`).

`Rules/` (servidor, um arquivo por anomalia ou uma tabela): `{ Anomaly, Verb, LikelyWrongVerb, Window, Params,
IsCritical }`. `Params` por anomalia (FEAT-023, NPC-009..018): N3 `DarkHold = 5`, `Window = 60`; N6
`LookLimit = 3`, `AutoOff = 20`; N7 `Steps = 10`, `StepEvery = 1`, `BackEvery = 10`; N8 `CloseWindow = 8` (era `HideWindow`, v5.2),
`StayFor = 15`; N9 `Window = 12`, `Zone = "trailer"` (N8/N9: `Verb = "shutter"`, era `"hide"`, DEC-221; "protegido" =
janela fechada e dentro do trailer, `architecture.md` §19.14); N10 `PostsOff = 15`, `HoldFor = 20`, `Point = "SS"`,
`Radius = 6`. `Validate`: `IsCritical` só em ANM-007 (DEC-074); todo verbo é um dos 7 (DEC-054; v5.2: `refuse`, `serve`, `dont_look`,
`light`, `shutter`, `discard`, `safe_spot`).

### 6.11 Hallucinations, Cutscenes, WalkPaths (onda 3)

| Tabela | Campos | Valores iniciais |
|---|---|---|
| Hallucinations | `Key`, `MaxSanity` (60 / 40 / 20), `Effect` (nome do módulo em `Effects/`), `Cooldown`, `Weight` | FEAT-019: `fake_call` (< 60), `grill_hiss` (< 60), `roof_steps` (< 40), `ghost_customer` (< 40), `post_flicker` (< 40, sem zumbido, DEC-123), `whisper` (< 20), `mart_sign_blink` (< 20), `window_shadow` (< 20) |
| Cutscenes | como §3.19 + `Participants = "ConnectedAtStart"` | `intro` 67,2 s (cap 70, Provisório 2026-10-11; era 45 s, cap 50), `finale` ≤ 60, `credits` ≤ 75 (FEAT-004, FEAT-027) |
| WalkPaths | `Key`, `Nodes = { NodeId }`, `Loop`, `Shift = "Day" \| "Night" \| "Any"`, `Weight` | caminhos de calçada do MAP-01 (level-designer); faixa = par de nós com `Crosswalk` |

### 6.12 Onda 4

`Revive`, `Ambulance`, `Products`, `MarketBench`/`BenchItems` como §3.9, §3.12, §3.13, §3.15 (sem mudança; +
`Ambulance.MedicFace = "Exhausted"`, `MedicSpecies = { "rabbit", "panda" }`, DEC-213). `PartyConfig` (registro):
`MaxParty = 4`, `Countdown = 5`, `TeleportRetries = { 2, 5, 10 }`, `JoinWindow = RunParams.JoinWindow`.

### 3.25 Seating, Flow.Groups e mudanças de mesas/duplas (v5.3, TASK-144; FEAT-037, FEAT-038; Provisório)

Arquivos: `Content/Seating.luau` (novo, registro), `Flow.luau` (`Groups`), `Upgrades.luau`, `CustomerTypes.luau`,
`Stats.luau`, `Actions.luau`, `Notices.luau`, `Animations.luau`; `Validate.checkSeating` cobre tudo abaixo.

**`Content.Seating`** (registro): `UnlockDay` 2 · `Tables` 5 · `UpgradeKey` `patio_tables` · `LightsKey`
`patio_lights` · `TableLabel` "Table" · `EatTime` { Day 20, Night 24, Jitter 3, GroupExtra 4 } · `TableTip` 2 ·
`MaxTip` 1000 · `MaxDiners` { Day 4, Night 2 } · `SitHeadroom` 2 · `NightSitMult` 0,75 · `GroupSitBonus` 0,20 ·
`SitChanceCap` 0,95 · `CleanHold` 1 · `BuyHold` 1,5 · `PromptRadius` 7 (iguais às linhas de `Actions`, Validate) ·
`TipLostAtSummary` true · `SeatedOutsideCap` false · `SitPhases` { Open, Night } · `TensionAnomalies` { anm_007_walker,
anm_008_long_car, anm_009_knock, anm_010_hush } · `GhostTransparency` 0,7 · `StandTimeout` 30 · `WalkTimeout` 6 ·
`Approach` 2,5 · `States` { Locked, Ghost, Free, Occupied, Dirty } (enum do set `Tables`) · `Seats` { Solo {1},
Pair {1, 3}, Couple {1, 2} } · `Binding` { Tag `SeatTable`, IndexAttribute `TableIndex`, Folder { MAP01_Assets, PadDecor }
(fallback), ModelName `AST-100_PicnicTable`, SeatPrefix `Seat`, SeatCount 4, BuyAnchor `Prompt_BuyTable`, CleanAnchor
`Prompt_CleanTable`, RuntimeAnchor `Prompt_Table`, TrayAnchor `Tray_Anchor`, NodePrefix `TBL-`, LightsAnchor
`Prompt_PatioLights` }. Só `TipLostAtSummary = true` e `SeatedOutsideCap = false` estão implementados (o outro valor
avisa no boot).

**`Flow.Groups`**: `ChanceDay` 0,20 · `ChanceNight` 0,10 · `FromDay` 2 · `FromNight` 2 · `IntervalMult` 1,6 ·
`PatienceBonus` 10 · `FollowGap` 2 · `SideGap` 2 · `QueueGap` 1,8 · `Leash` 8 · `PartnerSpeedMult` 1,2 · `Pairs`
{ `Shift`, `Leader`, `Partner`, `Weight`, `Couple` } com as 9 linhas da FEAT-038. Validate: tipos existem e são
`Customer`, aparecem no turno do par, e todo líder deixa ao parceiro outra espécie (noite) ou outra roupa (dia).

**`Upgrades`** (campos novos em toda linha): `SoldAt` `"Bench" | "InPlace"` · `BenchSpot` (`""` em InPlace) ·
`PlaceSpots` (InPlace: um ponto por nível comprável, em ordem) · `Scope` `"Vehicle" | "Pad"` (Pad = mesmo nível nos
dois veículos; Validate exige linhas iguais) · `Requires?` { `Upgrade`, `Level` }. Linhas novas: `patio_tables`
(UPG-008, `StartLevel` 0, níveis 0..5 = $0/30/45/60/80/100, `Effects.TableCount`, `UnlockDay` 2, `PlaceSpots`
TBL-1..TBL-5, Pad); `patio_lights` (UPG-009, $120, `Effects.SitBonus` 0,10, `Requires` patio_tables ≥ 2, Pad);
`back_bar` (UPG-010, $90, só trailer, `Scope` Vehicle, sem efeito ainda, não vendido). Gear Stand (`Mart`,
`Required.Bench`, `MarketController.OnLevel`) passam a olhar só `SoldAt = "Bench"`.

**`Stats`**: + `TableCount`, `SitBonus`. **`CustomerTypes.SitChance`** (0..1, valor de dia; noite × `NightSitMult`):
office 0,30 · student 0,60 · jogger 0,10 · construction 0,50 · grandparent 0,70 · night shift 0,40 · pedestrian 0.
**`Actions`**: `buy_in_place` ("Buy {item} — ${price}", 1,5 s, raio 7, onda 3) e `clean_table` ("Clean Table", 1 s,
raio 7, onda 3). **`Notices`**: `table_added` ("Table added!", Party, Number). **`Animations`**: `npc_sit` (Idle,
loop) e `npc_eat_seated` (Action), Id "" até o upload (TASK-151).
