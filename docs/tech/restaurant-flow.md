Status: Rascunho (Provisório até DEC do dono; nada aqui é código)

# Restaurante: fluxo "Overcooked de anomalia" (desenho técnico)

Autor: architect · 2026-10-17 · Fonte: `docs/source/2026-10-17-restaurante-brief.md` + esboço `2026-10-17-restaurante-esboco.webp`.
Base: `architecture.md` (§3, §18, §19.28), `network.md`, `content-data.md`, `prep-mode.md`, `prep-3d.md`, o código atual de
`src/Customer`, `src/Kitchen`, `src/Prep`, `src/Seating`, `src/Delivery`, `src/Interaction`, `src/Hud`, `src/Item`, `src/Npc`,
`src/Vehicle`, `src/Traffic`, `src/Upgrade`, `src/Shared/Content`, `src/Libs/Net/init.luau`. Anomalias do novo fluxo:
`docs/design/anomalies-v3-restaurant.md` (game-designer, paralelo). Mapa: `docs/levels/MAP-01-r4-restaurant.md`
(level-designer, paralelo; IDs `TAB-1..4`, `PLATE-1..8`, `GRILL-n`, `CUT-n`, `COND-n`, `DOOR-K`, `DT-STOP`, `DT-PC`, adotados aqui).
`DT-R#` = decisão técnica proposta (o secretário numera como DEC técnica; o dono pode vetar), lista em §9.

**Premissa:** o jogo está publicado e com anúncio. A regra deste desenho é **reaproveitar o fluxo de mundo que já existe**
(estações com prompt, Tool `hot_dog`, `topping_add`, sentar após o pedido, `serve_table`) e acrescentar só três peças novas:
**tablets**, **pratos-slot** e (depois) **drive-thru**. Nada de economia, estoque ou entrega paralelos.

---

## 0. A leitura em uma tabela

O código já tem quase todo o "Overcooked": antes do modo focado (DEC-223) o trailer funcionava com prompts no mundo
(`grill_place`, `grill_collect`, `bun_cut`, `board_add_sausage`, `topping_add`), e o cliente **já senta logo depois do
"Take Order" e é servido na mesa** (`SeatingService`, Q-209). O restaurante troca o balcão único por 4 pontos de pedido e põe
um "prato" físico entre as estações.

| Etapa do brief | Hoje | No restaurante | Peça de código |
|---|---|---|---|
| cliente chega pelo meio e vai a um tablet | fila única `Q1..Q5`, só `Q1` pede | fila com **4 cabeças** (`Q1..Q4` = frente dos `TAB-1..4`), espera em `Q5..Q8` | `CustomerService/Queue` (muda) |
| diálogo + nota construída item a item | "Take Order" instantâneo no rig; `HudOrder` mostra o pedido inteiro | `tablet_take` no tablet, conversa de 2 a 4 s, nota com pop-up por item; no fim o mesmo `TakeOrderFor` | `TabletService` (novo), `HudOrder` (+prop), `TabletController` (novo) |
| pedido vai sozinho a um prato-slot com BillboardGui | não existe | ticket cai no `PLATE-n` livre (prato translúcido + papel do pedido) | `PlateService` + `PlateController` + `PlateTicket` (novos) |
| cortar o pão e pôr no prato | `bun_cut` põe o pão na tábua do trailer | `bun_slice` no `CUT-n` dá o Tool `bun_sliced`; `plate_put` no prato | `Stations/Cut.luau` (novo), `PlateService` |
| grelhar, empilhar, pegar a salsicha | grelha + trilho (`Rail`, até 30) | igual; virar por prompt (`grill_flip`); `rail_take` dá o Tool `sausage_grilled` | `Stations/Grill.luau`, `Stations/Rail.luau` (pequeno) |
| pegar o prato, levar aos condimentos | Tool `hot_dog` + `topping_add` (segurar 1 s) | `plate_take` transforma o prato no Tool `hot_dog`; `COND-n` = estação `toppings` atual, sem mudança | reuso total |
| sair pela porta e entregar na mesa | `serve_table` na mesa, `PickServeTool` acha o hot dog certo | igual; `DOOR-K` = `AutoDoor` (porta local, sem código) | reuso total |
| drive-thru (paciência, buzina, vai embora, pet) | não existe | carro desenhado no client, cliente "sem rig", `DT-PC` = 5º tablet, `drive_serve` na janela | `DriveThru` (novo, onda R3) |
| carregar prato/itens entre jogadores | hotbar (4), coffee tem `give_coffee` | entrega pelo **prato-slot** (pôr de volta, outro pega) e pela pilha; dar na mão fica para R4 | `PlateService` (`plate_put` com hot dog) |

---

## 1. Mapa por sistema: o que existe e o que muda

| Sistema (pasta) | Existe hoje (relevante) | Muda | Tamanho |
|---|---|---|---|
| `Customer/server/CustomerService` (2183 l.) | spawn, fila `Q1..Q5`, `Orders`/`OrderRoll` (preço, Completo/Incompleto/Errado, DEC-072), dois relógios de paciência (Q-192), pares, `SetSeater`, `TakeOrderFor`/`ServeFor`, `Acted`, `SpawnActor`, `SetHeld` | **Queue com cabeças fixas** (`Heads` = tablets ativos; quem sai de um tablet não empurra os outros; o próximo da espera vai ao tablet livre); `OnFronted` por cabeça; `AtHead(n)`; `PausePatience(id, on)` durante a conversa; prompt `take_order` do rig **desligado** quando há tablets no mapa; `SpawnDrive` (R3) | médio, **arquivo-quente** |
| `Customer/client/CustomerController` | escolhe o cliente da nota (`HudOrder`: alvo do prompt, senão `Q1` em Waiting), balões | prioridade da nota: conversa no meu tablet > ticket do prato na mão > alvo > cabeça mais antiga | pequeno |
| `Kitchen/server/KitchenService` + `Stations/*` | estações descobertas por tag `Station` dentro de `Vehicle`; módulo novo em `Stations/` **não toca o init** (StationApi); `Grill.Flip` já existe (servidor carimba); `Rail` FIFO; `Toppings` (`topping_add` com `hot_dog` na mão) | `Stations/Cut.luau` (novo, kind `cut`, ingrediente `bun`, ação `bun_slice`, restock pelo core); `Grill.luau` ganha o prompt `grill_flip` (mesma `Grill.Flip`); `Rail.luau` ganha `rail_take` | pequeno; `init.luau` **não** muda |
| `Prep/*` (modo focado, DEC-223) | ~25 mil linhas; inerte sem `Station_n` | **desligado por flag** (`Prep.Rules.Enabled = false`); código fica (§7.3) | 1 linha |
| `Seating/server/SeatingService` | `Offer` no Take Order, mesa reservada, `serve_table`, comer, gorjeta na mesa, `clean_table` | **nada** de código; o restaurante usa as 4 mesas (`TableIndex 1..4`, grupo `Trailer`); quantas começam compradas é número (`Upgrades.trailer_tables`) | 0 |
| `Delivery/client/DeliveryController` | arrastar o hot dog até o cliente do balcão | vale também para o cliente que ficou no tablet sem mesa; nada muda | 0 |
| `Interaction` (server + `PromptController`) | `Interact` único, `RegisterAction`, `AddGate`, `Requires.Held` (item ou categoria) | `Rules.luau` do cliente: mostrar `plate_put` só com `bun_sliced`/`sausage_grilled`/`hot_dog` na mão e `plate_take` só com mão livre (o servidor revalida) | pequeno, **quente** |
| `Item/server/ItemService` | Tools do kit, limites por categoria, stash, snapshot `T`, `Toppings`, `Altered` | itens novos `bun_sliced`, `sausage_grilled` (categoria nova `Ingredient`, limite 2); atributo de Tool novo `Ticket` (NpcId do pedido; não entra no snapshot) | só dados + 1 atributo |
| `Hud` + `Interface/Components/HudOrder` | nota no canto superior esquerdo (`Toppings`, `Toppings2`, `Patience`, `Revealed`) | prop nova `Reveal: (() -> number)?` (quantos itens já apareceram; o novo entra com pop 0,25 s, `Motion`); `HudController` **não muda** | pequeno |
| `Npc/server/NpcService` | pool R6 de 12, grafo `NpcNode` (A*, ≤ 80 nós) | nada; o grafo novo é dado do mapa (nós entre as mesas até `Q1..Q8`, mesas `TBL-1..4`) | 0 |
| `Vehicle` (`VehicleService`, `Shutter`, `TrailerDoorService`) | trailer único = `Vehicle "trailer"`, `IsInside` = `LZ-1`, janela = loja aberta/fechada (TASK-284), porta dos fundos | o restaurante **é** o Model `Vehicle = "trailer"` (DT-R1); a persiana única cobre o balcão dos tablets e a janela do drive; `TrailerDoorService` fica inerte com `Vehicles.trailer.HasBackDoor = false` (não cria âncoras no prédio) | pequeno |
| `Traffic` | carros 1D no client a partir de registro (`Motion`), sem modelo no servidor | nada no MVP; o drive-thru **não** usa a rua (pista própria, §3.4); reusa só o kit de carros e `Traffic/shared/Motion` (puro) | 0 |
| `Upgrade/server/UpgradeService` | níveis por veículo, `Effect(stat)`, `Stats` | upgrades novos são **linhas** (`Upgrades`, `Stats`) lidas pelos módulos via `ctx.Effect` (§4.4) | dados |
| `Shared/Content` | `Actions`, `Items`, `Stations`, `Notices`, `Vehicles`, `Seating`, `Upgrades`, `Validate` | `Restaurant.luau` (novo) + linhas novas (§4) | onda R0 |
| `Libs/Net/init.luau` | `Customers`, `Stations`, `Stock`, `Tables`, `Prep*` | sets `Plates`, `Tablets` (R0) e `DriveCars` (R3); `Customers` ganha `Drive` opcional (R3) | onda R0 |
| `Tutorial/*` | ensina o modo focado | reescrita mínima para o restaurante (bloqueia o release, §6) | médio |
| `Anomaly/*` | `KitchenService:Alter("rail"/"board")`, `TRL`, `LZ-1`, `CART`, persiana | ANM-002 passa a `Alter("grill")`/`PlateService:Alter`; demais por dado (doc do game-designer) | onda R4 |

---

## 2. Modelo de estado (server-authoritative)

O cliente só apresenta (e prevê pop-ups e animações). Toda escolha (qual slot, se cabe na mão, se tem estoque, quem
pagou) é do servidor, síncrona dentro de um `Run` de `Interact`.

### 2.1 Order (o pedido)

**Não há entidade Order nova.** O pedido já é o `Orders.Ticket` server-only do `CustomerService` (linhas, K, preço,
relógios), publicado no set `Customers` (`Order`, `Order2`, `PatienceEndsAt`, `Phase`) desde o "Take Order". O restaurante
só acrescenta **onde** o pedido está sendo trabalhado:

| Campo lógico | Onde vive | Dono |
|---|---|---|
| id | `NpcId` do cliente (= id do registro `Customers`) | `CustomerService` |
| origem | `Customers.Slot` 1..4 = `TAB-n` (cabeça); `Customers.Drive` 1..2 = pista do drive (R3) | `CustomerService` |
| itens | `Customers.Order` / `Order2` (bitfield de toppings; pão + salsicha são implícitos) | `CustomerService` |
| estado | `Customers.State` (`Queued` → `Ordering` no tablet → `Waiting`) + `Tablets[n].State` (`Talking`) + prato (`Plates[k].Npc`) | os três |
| veredito e pagamento | `CustomerService:ServeTable` / `ServeFor` / `Serve` (DEC-072 inalterado) | `CustomerService` |

Ciclo: `Queued` em `Q5..Q8` → cabeça livre `Qn` (frente do `TAB-n`) → `Ordering` (relógio Queue corre) → jogador faz
`tablet_take` → `Tablets[n] = Talking` (relógio pausado, `PausePatience`) → fim da fala → `CustomerService:TakeOrderFor`
(o mesmo caminho do prompt antigo: grava `Order`, relógio Order, `Acted("take_order")`, oferece mesa) → `PlateService`
ouve `Acted` e põe o ticket num `PLATE-n` → cliente anda até a mesa (ou fica no tablet se não há mesa livre, servido ali
com `serve`, fluxo atual).

### 2.2 Plate (o prato-slot)

Dono único: `PlateService`. 8 slots (`Content.Restaurant.Rules.PlateSlots`; o mapa diz quantos existem).

```
Slot  = { Index, Anchor(s), Npc (0 = sem ticket), Line (1|2, par), Bun, Sausage, Toppings {string}, Altered, Since }
Holder: o prato está no slot (registro) OU na mão como Tool hot_dog com atributo Ticket = Npc (não existe "meio prato" na mão)
```

| Ação (`Content.Actions`) | Âncora | Regra do servidor | Efeito |
|---|---|---|---|
| `plate_put` "Add Bun" / "Add Sausage" / "Put Plate" (tap) | `Prompt_Put` do `PLATE-n` | na mão `bun_sliced` e slot sem pão; ou `sausage_grilled` e slot sem salsicha; ou `hot_dog` e slot vazio | consome o Tool (`ItemService:Consume`); `hot_dog` devolve pão + salsicha + toppings + `Ticket` ao slot |
| `plate_take` "Take Plate" (tap) | `Prompt_Take` do `PLATE-n` | slot com pão **e** salsicha; mão com espaço (`HotDog` 2) | `ItemService:Give(hot_dog, {Toppings, Altered})` + atributo `Ticket`; o slot esvazia e **solta o ticket** (fica livre para o próximo pedido) |
| (automático) `Assign(npc, line)` | — | `Acted(_, "take_order")`: slot livre preferindo um já com pão+salsicha (pré-preparo do solo), senão o de menor índice | `Npc`, `Line`, `Since` |
| (automático) `Release(npc)` | — | `Left` / venda do cliente | zera `Npc`; o conteúdo fica (serve para o próximo) |
| gate `Plates` em `take_order`/`tablet_take` (o `DT-PC` também é `tablet_take`) | — | todos os slots com ticket | recusa com `Notice plates_full` |

Por que o prato vira `hot_dog` na mão (DT-R3): `topping_add`, `HotDogVisual`, `PickServeTool`, `serve_table`, `discard`,
stash, snapshot `T`, `Altered` e o `DeliveryController` já trabalham com esse Tool. O "prato" é só o estado no slot. O
veredito continua pelos toppings (qualquer cliente com o mesmo pedido aceita), então o `Ticket` é **guia**, nunca trava.

### 2.3 Station

Sem modelo novo: são as estações do `KitchenService` (tag `Station`, `StationKind`, registros no set `Stations`).

| ID do mapa | `StationKind` | Ações | Registro `Stations` |
|---|---|---|---|
| `GRILL-n` | `grill` (+ `sausage_stock` ao lado, a "pilha" de cruas) | `grill_place`, **`grill_flip`** (novo, prompt no slot `Att_Slot<n>` enquanto `Working` na pausa), `grill_collect` | `PerSlot` (existente; `Flip` já no fio) |
| (pilha quente, ao lado da grelha) | `rail` | **`rail_take`** (novo) "Take Sausage" | `Single`, `Count` (existente) |
| `CUT-n` | **`cut`** (novo) | **`bun_slice`** (segurar 0,8 s, `Stations.cut.Params.CutTime`), `restock` | `None` (o estoque é `Stock.bun`) |
| `COND-n` | `toppings` (existente) | `topping_add`, `restock`, `topping_unwrap` | `None` |
| `BIN-K` | `trash` (existente) | `discard` | `None` |
| café | `coffee_machine` (existente) | sem mudança | `Single` |

Com 2+ `GRILL-n` ou `CUT-n` o `KitchenService` já aceita kind repetido no mesmo veículo (`Key` `"/2"`, `"/3"`), e
`Grill.PlaceFor` hoje escolhe "o grill do veículo": **conferir** em R1-A que `grill_place` usa a grelha da âncora tocada
(prioridade da tarefa, não do desenho).

### 2.4 Tablet

Dono: `TabletService`. Registros 1..4 = `TAB-1..4`; 5 = `DT-PC` (R3).

```
Tablet = { Index, Anchor, Stand (MapPoint Qn), State "Idle"|"Talking", Npc, User, StartedAt, EndsAt }
TalkTime = Rules.TalkBase + Rules.TalkStep x (2 + K)   -- pão, salsicha e cada topping viram um pop-up
```

- `tablet_take` (tap, raio 6): cliente em `Ordering` na cabeça `n`, tablet `Idle`, gate `Plates` livre, jogador Active. O
  jogador **não** é congelado (pode sair; a fala termina igual: sem estado meio-feito).
- No fim: `CustomerService:TakeOrderFor(player, npc)`. Se o cliente sumiu antes (anomalia, persiana, fim de fase),
  volta a `Idle` sem nada.
- A ordem dos pop-ups é **determinística** do bitfield (pão, salsicha, toppings na ordem de `ToppingKeys`): o servidor
  não manda passo a passo, o cliente revela `i` em `StartedAt + TalkBase + TalkStep x i`. Todos os clientes veem o mesmo.

### 2.5 Set ou packet

| Entrada | Tipo | Por quê |
|---|---|---|
| `Plates` | **set** | 4 jogadores veem os 8 pratos e quem entra tarde recebe o estado; poucas escritas (eventos) |
| `Tablets` | **set** | quem fala em qual tablet e quando começou: alimenta a nota do taker e o balão para os outros; ≤ 5 registros |
| `DriveCars` (R3) | **set** | carro parado/chegando/saindo, visto por todos; ≤ 2 registros |
| ações (`plate_put`, `tablet_take`, …) | `Interact` (packet existente) | nenhum packet novo: toda ação é prompt |
| recusas | `Notice` (packet existente) | `plates_full`, `plate_full`, `plate_not_ready`, `tablet_busy` |
| buzina | **nada** | o client deriva do `PatienceEndsAt`/`PatienceSpan` do cliente do drive (mesmo instante em todos) |

**Sem `keyBy`** (um servidor = uma equipe; não há audiência a particionar). Nenhum set tem 8+ registros com registro
pequeno: `Plates` tem 8, mas cada registro carrega `Npc` de 16 bits e `Since` f64 (bem acima de 1 byte; README
"drop.section").

### 2.6 Diff proposto de `src/Libs/Net/init.luau` (só documento; implementação na onda R0)

```lua
	-- restaurant-flow.md §2.2, record = plate slot 1..Content.Restaurant.Rules.PlateSlots (only the slots the map has).
	-- Writer: PlateService. 8 records, but Npc is 16 bits and Since an f64, so the README drop.section floor does not apply
	Plates = Lync.replicate(Lync.struct({
		Npc = Lync.int(0, 65535), -- NpcId of the ticket on this plate, 0 = no ticket
		Line = Lync.int(0, 2), -- line of a pair ticket (1 = leader's hot dog, 2 = partner's), 0 = no ticket
		Bun = Lync.bool(),
		Sausage = Lync.bool(),
		Toppings = Lync.bitfield(Content.Ingredients.ToppingKeys), -- a plate put back after the condiments
		Since = Lync.f64(), -- server time the ticket landed (oldest first, age tint); 0 = no ticket
		Altered = Lync.optional(Lync.bool()), -- ANM-002 on a plate (wave R4); nil = false
	})),

	-- restaurant-flow.md §2.4, record = tablet 1..4 (TAB-n), 5 = drive-thru computer (DT-PC, wave R3). Writer: TabletService.
	-- The client reveals item i of Order at StartedAt + TalkBase + TalkStep * i (bun, sausage, then ToppingKeys order)
	Tablets = Lync.replicate(Lync.struct({
		State = Lync.enum({ "Idle", "Talking" }),
		Npc = Lync.int(0, 65535), -- customer at this tablet, 0 = none
		User = Lync.f64(), -- UserId taking the order, 0 = nobody
		StartedAt = Lync.f64(),
		EndsAt = Lync.f64(),
		Order = Lync.bitfield(Content.Ingredients.ToppingKeys),
		Order2 = Lync.optional(Lync.bitfield(Content.Ingredients.ToppingKeys)), -- pair (FEAT-038)
	})),

	-- restaurant-flow.md §3.4 (wave R3), record = drive lane spot 1..Content.Restaurant.Drive.Lanes (1 = at the window,
	-- 2 = waiting behind). Writer: DriveThruService. The client moves the car DT-IN -> DT-STOP -> DT-OUT from State + At
	DriveCars = Lync.replicate(Lync.struct({
		State = Lync.enum({ "Arriving", "Waiting", "Leaving" }),
		Npc = Lync.int(0, 65535), -- the drive customer (Customers record)
		Look = Lync.int(1, 32), -- Content.Traffic.LookIndex
		At = Lync.f64(), -- server time of the State change
		Pet = Lync.optional(Lync.bool()), -- a pet rides along (R4)
	})),
```

E no `Customers` existente (R3), um campo opcional, sem quebrar escritores antigos:

```lua
		Drive = Lync.optional(Lync.int(1, 2)), -- drive-thru lane spot (DriveCars id); nil = a walking customer
```

`Customers.Slot` mantém o schema (`int(0, 8)`); muda o significado documentado: `1..Heads` = cabeça no `TAB-n`, `Heads+1..8`
= espera. Enums vêm do `Content` (Lync ordena os nomes; os dois lados requerem o mesmo `Content`).

Ritmo: `Plates` < 2 escritas/s no pico (4 jogadores), `Tablets` 2 escritas por pedido, `DriveCars` 3 por carro. Soma
< 150 B/s por client no pior caso: irrelevante perto de `Customers`/`Stations`.

---

## 3. Fluxos detalhados

### 3.1 Fila com cabeças (CustomerService/Queue)

- `Queue` passa de lista única para `{ Heads: {[n]: id}, Line: {id} }` (puro, testável em Luau sem Roblox).
- `Heads` ativos = `Effect("TabletCount")` (upgrade `counter` reaproveitado: hoje `QueueSize` 1..5; ver §4.4), limitado
  aos `TAB-n` presentes no mapa; à noite `Content.Restaurant.Rules.NightTablets` (2, proposta do Q-334 do game-designer).
- Chegada → fim da `Line` (`Q5..Q8`); cabeça livre → o primeiro da `Line` anda até `Qn` (o tablet mais perto dele, desempate
  pelo índice). Quem sai de uma cabeça **não** move as outras cabeças.
- `MapPoint` `Q1..Q4` = onde o cliente fica em frente ao `TAB-1..4` (atributo `Tablet = n`); `Q5..Q8` = espera, também
  `NpcNode`. Sem tablets no mapa, `Heads = 1` e tudo se comporta como hoje (rollback).
- O prompt `take_order` do rig fica desligado quando há `TAB-n` ligados (o pedido é no tablet). `serve` no rig continua
  para quem ficou sem mesa.

### 3.2 Diálogo e nota (client)

- `TabletController` (novo) lê `Tablets`. Se `User == eu` e `Talking`: abre a nota com `Reveal` crescendo pelo relógio do
  servidor e mostra as falas em `TabletDialog` (Vide, inferior esquerdo ou balão sobre o cliente; nada central em 1ª pessoa,
  AGENT-BRIEF §4). Para os outros: só o balão sobre o cliente.
- Falas: `Content.Restaurant.Dialog` (`Greeting`, `Ask[ingrediente]`, `Close`; inglês na UI, narrative-writer). Voz TTS é
  opcional e posterior (sem "sausage", `frank`).
- ANM-001 (sem rosto): nota em branco, sem pop-ups (o `HudOrder` já tem `Empty`).
- Depois da fala, a nota segue a regra de prioridade (§1, `CustomerController`): com prato na mão, mostra o pedido do
  `Ticket` daquele prato.

### 3.3 Montagem e entrega

1. Ticket cai no `PLATE-n`: o client deixa o prato translúcido (`Transparency 0,5`) e monta `PlateTicket` (BillboardGui
   Vide, `MaxDistance 40`, `LightInfluence 0`, papel com ícones do `Icons`/AST-071, borda = paciência do cliente pelo
   `Customers`). Conteúdo do prato (pão, salsicha) desenhado no slot com o `HotDogVisual` (client, só visual).
2. `CUT-n`: `bun_slice` → Tool `bun_sliced` → `plate_put`.
3. `GRILL-n`: `grill_place` → pausa → `grill_flip` → `grill_collect` (pilha) → `rail_take` → `sausage_grilled` → `plate_put`.
4. `plate_take` → `hot_dog` na mão → `COND-n` `topping_add` (segurar 1 s cada) → `DOOR-K` → mesa `serve_table`.
5. Errou o topping: `discard` no `BIN-K` (o pão e a salsicha se perdem, como hoje). Hand-off: pôr o prato de volta num
   slot vazio (`plate_put` com `hot_dog`), outro jogador pega.

Veredito, preço, gorjeta (janela de gorjeta a partir do "Take Order", DEC-072), humor, mesa suja e `clean_table`:
**inalterados**. Sem `Quality` (o mundo não dá nota de preparo; Perfect = Completo dentro da janela, como DEC-072).

### 3.4 Drive-thru (onda R3)

| Momento | Servidor (`DriveThruService`) | Client (`DriveThruController`) |
|---|---|---|
| spawn | pelo mesmo relógio de fluxo (`CustomerService:Attempt` sorteia "drive" com `Content.Restaurant.Drive.Chance` quando a pista 1 ou 2 está livre); `CustomerService:SpawnDrive(spec)` cria um registro `Customers` **sem rig** (DT-R6) com `Drive = 1|2` | clona o carro do kit de trânsito (`Content.Traffic.LookIndex`, sem tocar no `TrafficController`), motorista faz parte do modelo |
| chegada | `DriveCars = Arriving`, `At`; após `Drive.ArriveTime` → `Waiting` em `DT-STOP`; relógio Queue começa | anda `DT-IN → DT-STOP` (polilinha de `MapPoint`, `Traffic/shared/Motion` para frear) |
| pedido | `DT-PC` = tablet 5 (`TabletService`, mesma conversa, mesma nota); no fim `TakeOrderFor` → prato com ticket (origem drive) | igual aos tablets |
| buzina | nada | em `Drive.HornAt` (ex.: 0,5 e 0,25 da paciência) toca `SFX` de buzina no carro + pulinho; todos ouvem no mesmo instante |
| entrega | `drive_serve` "Hand Over" no `DT-WIN` (janela) → `CustomerService:ServeFor(player, nil, npc)` (mesmo veredito) | carro sai |
| desiste | relógio acaba → `GiveUp` (existente, `Left`) → `DriveCars = Leaving` | buzina longa, sai acelerando |
| pet (R4) | `Pet = true`; rig de pet pelo `NpcService` (conta no teto) sai pela porta do carro, volta antes de `Leaving`; gancho das anomalias (`ANM-033` do game-designer) | — |

Se o ramo "sem rig" no `CustomerService` se mostrar invasivo demais no spike (R3-0, meio dia), plano B: rig do pool
ancorado e invisível em `DT-STOP` (custa 1 vaga de NPC por carro). A decisão é do coder dono do `CustomerService` após o spike.

---

## 4. Content data

### 4.1 `src/Shared/Content/Restaurant.luau` (novo, registro único, padrão `Table.with`)

```lua
export type Rules = {
	Enabled: boolean,        -- false = trailer flow (Queue Heads = 1, no plate gate, tablets ignored)
	PlateSlots: number,      -- 8 (map may bind fewer)
	TabletsDay: number,      -- cap of active heads by day (4); the Counter upgrade gives TabletCount up to this
	NightTablets: number,    -- 2 (Q-334 proposal)
	TalkBase: number,        -- 0.8 s greeting before the first pop-up
	TalkStep: number,        -- 0.45 s per item (bun, sausage, each topping)
	TalkRadius: number,      -- 10 studs (only for the balloon; the talk never cancels)
	TakeRadius: number,      -- 6
	PreppedFirst: boolean,   -- true: a ticket prefers a plate that already has bun + sausage
}
export type Drive = { Lanes: number, Chance: number, ArriveTime: number, LeaveTime: number, HornAt: { number },
	PatienceMult: number, PetChance: number }
export type Dialog = { Greeting: { string }, Ask: { [string]: { string } }, Close: { string }, Blank: { string } }
export type Binding = {
	TabletTag: "Tablet", TabletIndex: "TabletIndex", TabletPrompt: "Prompt_Take",          -- Model TAB-n
	PlateTag: "PlateSlot", PlateIndex: "PlateIndex", PlatePut: "Prompt_Put", PlateTake: "Prompt_Take",
	PlateTicket: "Att_Ticket",                                                             -- Part PLATE-n
	DriveStop: "DT-STOP", DriveIn: "DT-IN", DriveOut: "DT-OUT", DrivePc: "DT-PC", DriveWindow: "DT-WIN",
	Door: "DOOR-K",
}
```

Regras de binding (§18 da arquitetura): **tag + atributo** decidem, o nome (`TAB-1`, `PLATE-3`) é o `MapId` do level-designer,
só para leitura humana e para o `check`. `TAB-n`: `Model` tag `Tablet`, `TabletIndex = n`, filhos `Prompt_Take` (tag
`Interactable`, `PromptAction = tablet_take`), opcional `Att_Screen` (balão). `PLATE-n`: `Part` tag `PlateSlot`,
`PlateIndex = n`, dois `Attachment` âncora (`Prompt_Put`/`Prompt_Take`), `Att_Ticket` (BillboardGui) e o prato visual como
filho. `GRILL-n`/`CUT-n`/`COND-n`/`BIN-K`: `Model` tag `Station` + `StationKind`, contrato do §18.4 inalterado, **dentro** do
Model `Vehicle = "trailer"` (o prédio). `DOOR-K`: tag `AutoDoor` (porta local, `DoorController`, sem código).
`DT-*`: `MapPoint` (e `NpcNode` onde o pet anda); `DT-PC` = `Model` tag `Tablet`, `TabletIndex = 5`; `DT-WIN` = âncora
`drive_serve`.

**Pontos de compatibilidade que o restaurante TEM de manter** (lidos por código vivo; `MapIndex/Required.luau` falha o boot
sem eles): `TRL` (pivô do prédio), `CART` (frente do balcão dos tablets; Adopt e cutscene), `Q1..Q5` (agora `Q1..Q8`),
`PS-1..4`/`PS-N1..4` (spawn dentro da cozinha), `DROP-T`, `L3`, `AN-05`, `TRL-OUT`, `LightZone LZ-1` (volume da cozinha =
"dentro", proteção e luz), `TBL-1..4` e as mesas `SeatTable` `TableIndex 1..4`, `Prompt_Shutter` + peças da persiana.

### 4.2 Linhas novas nas tabelas existentes

| Tabela | Linhas |
|---|---|
| `Actions` | `tablet_take` "Take Order" (tap, r 6), `bun_slice` "Slice Bun" (0,8 s, r 6), `plate_put` "Add {item}"/"Put Plate" (tap, r 5), `plate_take` "Take Plate" (tap, r 5), `grill_flip` "Flip" (tap, r 7), `rail_take` "Take Sausage" (tap, r 7), `drive_take` não (é `tablet_take` no `DT-PC`), `drive_serve` "Hand Over" (tap, r 6, R3) |
| `Items` | `bun_sliced`, `sausage_grilled` (categoria nova `Ingredient`); kit Tools em `ReplicatedStorage.Assets.Items.Tools/<key>` (FoodPack) |
| `ItemRules.CategoryLimits` | `Ingredient = 2` (Provisório; upgrade de bandeja pode subir) |
| `Stations` | `cut` (`Record = "None"`, `Ingredient = "bun"`, `Actions = {"bun_slice", "restock"}`, `Params = { CutTime = 0.8 }`); `grill.Actions` += `grill_flip`; `rail.Actions` += `rail_take` |
| `Notices` | `plates_full`, `plate_full`, `plate_not_ready`, `tablet_busy`, `drive_left` (R3) |
| `Vehicles.trailer` | `HasBackDoor = false` (TrailerDoorService inerte), `Restaurant = true` |
| `Sounds` | `plate_put`, `ticket_pop`, `dialog_blip`, `car_horn`, `car_horn_long`, `car_arrive` (SFX novos, audio-list) |
| `Upgrades`/`Stats` | ver §4.4 |
| `Validate` | `Restaurant` (faixas, `HornAt` decrescente, `Ask` cobre `bun`, `sausage` e todo `ToppingKeys`), ações das estações existem, `Ingredient` tem limite |

`content-data.md` ganha a seção "Restaurant" quando o secretário consolidar (este doc é o dono até lá).

### 4.3 Persistência (`data.md`)

**Nenhuma mudança no Template do perfil, nenhuma migração.** Run snapshot: `Plates` e `Tablets` não entram (o turno recomeça
vazio, como grelha/tábua, `data.md` §2.2); os Tools novos entram no `T` pelo caminho genérico; o atributo `Ticket` **não**
(um ticket depois de um resume aponta para cliente que não existe). Upgrades novos entram no `Upg` por chave.

### 4.4 Ganchos para os upgrades do solo (números são do game-designer)

Todos são `Stats` lidos por `ctx.Effect(stat)` dentro do módulo dono, sem serviço novo:

| Stat (proposta) | Lido em | Efeito |
|---|---|---|
| `TabletCount` | `CustomerService/Queue` | cabeças ativas 1..4 (upgrade `counter` muda de `QueueSize` para `TabletCount`; o `QueueSize` antigo continua no snapshot, mapeado 1:1) |
| `GrillAutoCollect` | `Stations/Grill.luau` (Tick) | salsicha pronta vai sozinha à pilha (tira um papel do solo) |
| `SlicerStack` | `Stations/Cut.luau` (Tick) | o `CUT` corta sozinho até N pães; `bun_slice` vira instantâneo enquanto há pão cortado |
| `AutoFlip` | `Stations/Grill.luau` | vira sozinho no fim do 1º lado |
| `IngredientCarry` | `ItemService` (limite da categoria) | bandeja: carregar 2 → 4 itens |
| `TalkSpeed` | `TabletService` | `TalkStep` x fator (atender mais rápido) |
| `KioskTablet` | `TabletService` | um tablet atende sozinho após X s sem jogador (solo atende enquanto cozinha) |

---

## 5. Ondas e posse de arquivos

Regra: um dono por arquivo por onda; arquivo novo sempre que possível. Antes da R0 o orquestrador **commita a árvore atual**
(há mudanças não commitadas em quase todos os arquivos-quentes abaixo).

### Onda R0: contratos (1 agente, sequencial, ~meio dia; bloqueia todas)

| Arquivo | Mudança |
|---|---|
| `src/Shared/Content/Restaurant.luau` (novo) + `Content/init.luau` (1 linha) | §4.1 |
| `Content/Actions.luau`, `Items.luau`, `Stations.luau`, `Notices.luau`, `Vehicles.luau`, `Sounds.luau`, `Validate.luau` | §4.2 |
| `src/Libs/Net/init.luau` | `Plates`, `Tablets` (§2.6). `DriveCars` e `Customers.Drive` já entram aqui também (schema pronto, sem escritor; evita reabrir o arquivo na R3) |
| `src/Place/shared/MapIndex/Required.luau` | `Q6..Q8` opcionais; `DT-*` opcionais até a R3 |
| Aceite | `rogen build` → `modux generate` → `modux check` 0 erro; `Lync.start()` sem erro de schema em Play (o analyze não pega schema) |

### Onda R1: MVP em paralelo (8 trilhas, arquivos disjuntos)

| Trilha | Dono | Arquivos (só estes) | Depende |
|---|---|---|---|
| **R1-A** Kitchen | backend | `Kitchen/server/KitchenService/Stations/Cut.luau` (novo), `Stations/Grill.luau`, `Stations/Rail.luau` | R0 |
| **R1-B** Plate (server) | backend | `src/Plate/server/PlateService/init.luau` (novo) + `Slots.luau` (novo, puro), `Dev/server/DevService/Commands/Plate.luau` (novo) | R0 |
| **R1-C** Customer | backend | `Customer/server/CustomerService/Queue.luau`, `CustomerService/init.luau` (cabeças, `AtHead`, `PausePatience`, prompt do rig, `Heads` por `TabletCount`) | R0 |
| **R1-D** Tablet (server) | backend | `src/Tablet/server/TabletService.luau` (novo), `Dev/.../Commands/Tablet.luau` (novo) | R0 (chama APIs de R1-B/R1-C por nome; mock por tipo até lá) |
| **R1-E** Mapa | level-designer + Studio | restaurante no place (tag `Vehicle`, `Vehicle = "trailer"`), trailer antigo para `ServerStorage.TRAILER_Backup_20261017` (com `OrigPath`/`OrigTags`), snippet `tools/assetplace/restaurant_bind.luau` (novo, idempotente), kit Tools `bun_sliced`/`sausage_grilled`; seção nova no `STUDIO_LAYER.md` | R0 (nomes) |
| **R1-F** Plate + Tablet (client) | frontend | `src/Plate/client/PlateController.luau` (novo), `src/Tablet/client/TabletController.luau` (novo), `Interface/client/Components/PlateTicket/` (novo + story), `Interface/client/Components/TabletDialog/` (novo + story), `Interaction/client/PromptController/Rules.luau` | R0 |
| **R1-G** Nota do HUD | frontend | `Interface/client/Components/HudOrder/init.luau` (+`Reveal`, story), `Customer/client/CustomerController/init.luau` (prioridade da nota) | R0 |
| **R1-H** Veículo | backend | `Vehicle/server/TrailerDoorService.luau` (`HasBackDoor`), conferir `VehicleService/Shutter.luau` com o `LZ-1` novo (sem mudança esperada) | R0 |

Prioridades de boot: `PlateService` **566** (`Require`: `InteractionService`, `ItemService`, `KitchenService`, `CustomerService`,
`RoundService`, `NetService`; conecta `CustomerService.Acted`/`Left` no `OnStart`), `TabletService` **564** (`InteractionService`,
`CustomerService`, `PlateService`, `UpgradeService`, `NetService`), `DriveThruService` **562** (R3: `CustomerService`,
`TabletService`, `PlateService`, `RoundService`, `NetService`). Controllers: `PlateController` e `TabletController` abaixo de
`CustomerController`, sem dependência entre si (os dois só leem sets). Responders: nenhum novo (só `Interact`, que é do
`InteractionService`).

### Onda R2: fechar o MVP (sequencial curto)

| Trilha | Arquivos |
|---|---|
| Prep desligado | `Content/Prep.luau`: `Rules.Enabled = false` (rollback = `true` + trailer de volta) |
| Tutorial mínimo do restaurante (bloqueia release) | `Tutorial/server/TutorialService.luau`, `Tutorial/client/TutorialController/{init,Steps}.luau`, `Tutorial/shared/Rules.luau`: tablet → cortar → grelhar/virar → prato → condimento → mesa |
| Smoke | `Dev/server/DevService/Commands/Smoke.luau`: um pedido de ponta a ponta por `/dev` (tablet → prato → serve_table) |
| Números do restaurante | `Content/Restaurant.luau`, `Upgrades.luau` (mesas iniciais, `TabletCount`), `Flow.luau` (intervalo com 4 cabeças) — game-designer |
| QA | plano do qa-tester (solo e 4 jogadores, mobile) |

**MVP técnico = R0 + R1 (A a H) + R2.** Loop jogável: cliente → tablet → conversa com nota → ticket no prato → cortar /
grelhar / virar / empilhar → prato → condimentos → porta → mesa → paga e suja a mesa → limpar. Sem drive-thru, sem pets,
sem voz, sem anomalias novas (as V2 que dependem de peça do trailer ficam desligadas por dado até a R4).

### Ondas seguintes

| Onda | Conteúdo | Arquivos |
|---|---|---|
| **R3** drive-thru | spike sem rig (meio dia), `SpawnDrive`, carro, buzina, `drive_serve`, tablet 5 | `src/DriveThru/server/DriveThruService.luau` (novo), `src/DriveThru/client/DriveThruController.luau` (novo), `CustomerService/init.luau` (dono R1-C), `TabletService.luau` (dono R1-D), `Content/Restaurant.luau` (`Drive`) |
| **R4** anomalias V3 e co-op | `Content.Anomalies` + `Rules/ANM-0xx.luau` (doc do game-designer); `KitchenService:Alter("grill")` e `PlateService:Alter`; guichê por tablet (Q-330 a, dono `TabletService`); pets; `give_item` entre jogadores (padrão do `give_coffee`); voz das falas; upgrades do solo (§4.4) | arquivos de regra são novos; `Grill.luau`/`Cut.luau` voltam ao dono R1-A |
| **R5** limpeza | remover `src/Prep/client/**` e `PrepService` depois de 1 release estável do restaurante (o `Prep/shared/Grade` fica: `CustomerService` e `Grill` o requerem); apagar âncoras `Station_n` do backup | só remoção |

### Arquivos-quentes (conflito)

| Arquivo | Por quê | Regra |
|---|---|---|
| `src/Libs/Net/init.luau` | todo set/packet | só R0 (inclui o schema da R3) |
| `src/Shared/Content/{Actions,Items,Stations,Notices,Vehicles,Validate,init}.luau` | toda feature acrescenta linha | só R0; números depois só em `Restaurant.luau`/`Upgrades.luau` |
| `src/Customer/server/CustomerService/init.luau` (2183 l.) | fila, pedido, drive | **um dono para o projeto todo** (R1-C → R3) |
| `src/Customer/client/CustomerController/init.luau` | nota do HUD | só R1-G |
| `src/Interaction/client/PromptController/Rules.luau` | visibilidade dos prompts | só R1-F |
| `src/Kitchen/server/KitchenService/init.luau` | ninguém deve precisar (StationApi descobre módulos) | se precisar, para e fala com o architect |
| `src/Hud/client/HudController.luau` | não muda | — |
| `src/Tutorial/**`, `Dev/.../Smoke.luau` | já modificados nesta árvore | só R2 |
| place (Studio), `MAP-01_placements.luau`, `STUDIO_LAYER.md` | edição à mão do dono | só R1-E; **nunca `Place.run`** sem pedido (memória `studio-hand-edits`) |

---

## 6. Modo de preparo focado (DEC-223) e código do trailer

- **Prep:** desligado por `Prep.Rules.Enabled = false`. O restaurante não tem `Station_n`, então o `PrepService` fica inerte
  mesmo sem a flag; a flag garante que nenhum `prep_work` apareça. **Não remover agora** (risco e tempo): fica o rollback e
  a chance de reaproveitar uma vista focada como bônus opcional numa estação (ex.: corte de precisão no `CUT` dá gorjeta),
  depois. `Grade` e o `Quality` continuam no código; sem prep, nenhum hot dog tem `Quality` (gorjeta Perfect do prep some:
  impacto de economia para o game-designer). Isto **suspende a DEC-223 no restaurante: precisa de DEC do dono**.
- **Trailer:** sai do mapa para `ServerStorage.TRAILER_Backup_20261017` (mesmo padrão do `CART_Backup`). O código não tem
  flag de "veículo": o restaurante **herda a chave `trailer`** (DT-R1), então `Upgrades`, `Stations`, `Seating`, snapshots e
  as 75 referências a `"trailer"` continuam válidas. Renomear para `restaurant` é cosmético e caro: fica para a R5, se o dono quiser.
- **Rollback** (sem código): `Restaurant.Rules.Enabled = false` + `Prep.Rules.Enabled = true` + trailer de volta do backup no
  Studio (snippet `restaurant_bind.luau "undo"`). Com `Enabled = false` a fila volta a `Heads = 1` e o gate dos pratos some.

---

## 7. Orçamento

| Item | Teto (Provisório) |
|---|---|
| Rigs animados no servidor | 12 (DEC-045) de dia: até 4 nos tablets + 4 na espera + até 8 sentados disputam o mesmo teto (`MaxCustomersDay` 8 já limita); à noite ≤ 9 (§6.3 do doc de anomalias, Q-334) |
| Carros do drive | 1 parado + 1 na fila, só client, **sem rig** (motorista no modelo) |
| Pets | 1, rig do pool (conta no teto) |
| BillboardGui | 8 pratos + 5 tablets, `MaxDistance` 40, atualizam só quando o registro muda |
| Rede | `Plates` < 2 escritas/s, `Tablets` por pedido, `DriveCars` por carro; nada a 10 Hz |
| IA | sem mudança de estratégia: A* no grafo `NpcNode` (≤ 80 nós; o prédio troca nós do Pad, não soma), ≤ 2 rotas por frame, `MoveTo` por aresta ≤ 40 studs; cliente nunca entra na cozinha |
| Servidor | `PlateService` sem tick (só eventos); `TabletService` tick 2 Hz só para fim de fala; `DriveThruService` 2 Hz |

---

## 8. Riscos

| Risco | Mitigação |
|---|---|
| **Mobile: prompts amontoados** (8 pratos lado a lado, 4 tablets, grelha + pilha) | prompts contextuais por mão (`Rules.luau`: `plate_put` só com item certo, `plate_take` só com mão livre), raio 5 nos pratos, slots a ≥ 2,5 studs (pedido ao level-designer), o `InteractionMenu`/modo "Single" existente escolhe o mais perto; testar em 667x375 |
| **Câmera dentro de prédio pequeno** (parede e teto atrás do personagem) | teto e parede da frente com fade local quando o jogador está no `LZ-1` (client, `CameraController` ou snippet de `LocalTransparencyModifier`), ou `DevCameraOcclusionMode = Invisicam` no place; decidir em Play na R1-E |
| **Boot quebra sem os pontos legados** (`TRL`, `CART`, `LZ-1`, `Q1..Q5`, `PS-*`, `DROP-T`, `L3`, `AN-05`, `TRL-OUT`) | lista de compatibilidade (§4.1) como aceite da R1-E; `check_map01` e `/dev smoke` antes de entregar |
| **Anomalias V2 presas ao trailer** (ANM-002 tábua/trilho, ANM-004 porta dos fundos, ANM-009 batida, alucinações de teto, persiana) | no MVP desligar por dado as que dependem de peça que não existe; adaptação na R4 pelo doc do game-designer; `Alter("board")` devolve `false` sem tábua (já é seguro) |
| **Studio e place** (dono edita à mão; `Place.run` apaga) | só snippets idempotentes e cirúrgicos (`restaurant_bind.luau`, por tag/atributo, com `undo`); `list_roblox_studios` antes; `Place.diff` = 0 e o dono salvar antes de qualquer rebuild; `MeshId` por clone do template |
| **CustomerService enorme e já modificado** | um dono só; mudança da fila em `Queue.luau` puro com testes de tabela; commit da árvore antes da R0 |
| **Solo chato / pior que o trailer** (5 estações para um jogador) | pré-preparo (prato com pão+salsicha recebe o próximo ticket, `PreppedFirst`), upgrades de automação (§4.4) e `KioskTablet`; medir `Left`/`Slow` contra o baseline do trailer nos primeiros dias |
| **Ritmo: conversa de 2 a 4 s por pedido** | `TalkStep` curto, conversa não trava o jogador, relógio de paciência pausado durante a fala; `TalkSpeed` como upgrade |
| **Schema do Lync** (erro só em runtime, derruba o `start`) | R0 testa em Play; nenhum `keyBy`; registros acima de 1 byte |
| **Hotbar** (4 slots, `Ingredient` 2 + `HotDog` 2) pode confundir | ícones dos Tools novos; o `plate_put` consome o item certo sem precisar equipar (o servidor escolhe no Backpack, como `PickServeTool`) |
| **Tutorial do jogador novo quebra** (o atual ensina o prep) | tutorial mínimo é **bloqueante** do release (R2); até lá, publicar só com o tutorial reescrito |
| **Economia sem `Quality`** (sem gorjeta Perfect do prep) | número do game-designer (gorjeta pela janela continua) |

---

## 9. Decisões técnicas propostas (veto livre) e perguntas

- **DT-R1** O restaurante é o Model `Vehicle = "trailer"` (chave mantida); sem veículo novo, sem migração de snapshot.
- **DT-R2** Sem entidade Order nova: o pedido continua o `Ticket` do `CustomerService`; o restaurante só diz onde ele está (cabeça, prato).
- **DT-R3** O prato vira o Tool `hot_dog` ao ser pego (atributo `Ticket` só de guia); no slot é estado do `PlateService`. Itens intermediários são Tools (`bun_sliced`, `sausage_grilled`, categoria `Ingredient`).
- **DT-R4** Fila com cabeças fixas (`Q1..Q4` = tablets) em `CustomerService/Queue`, `Heads` por `TabletCount`.
- **DT-R5** Rede: 2 sets novos no MVP (`Plates`, `Tablets`), 1 na R3 (`DriveCars`), `Customers.Drive` opcional; nenhum packet novo, nenhum `keyBy`; buzina e pop-ups derivados do relógio do servidor.
- **DT-R6** Cliente do drive-thru sem rig (motorista no modelo do carro, client), plano B rig invisível após spike.
- **DT-R7** Estações novas como módulos do `KitchenService` (`Stations/Cut.luau`), sem tocar no `init`.
- **DT-R8** Prep desligado por flag, código mantido até 1 release estável (remoção na R5, `Grade` fica).
- **DT-R9** Features novas: `src/Plate`, `src/Tablet`, `src/DriveThru` (cada uma `server` + `client`); `Content.Restaurant` em `Shared/Content`.
- **DT-R10** Binding por tag + atributo (`Tablet`/`TabletIndex`, `PlateSlot`/`PlateIndex`); nomes `TAB-n`, `PLATE-n`, `GRILL-n`, `CUT-n`, `COND-n`, `DOOR-K`, `DT-*` são `MapId`.

Perguntas ao dono (o secretário numera; não bloqueiam a R0/R1, seguem com a recomendação):

1. DEC-223 (modo focado) fica **suspensa no restaurante**? Recomendação: sim, flag desligada, código mantido.
2. Quantos tablets e mesas no Dia 1 (o resto por upgrade)? Recomendação: 2 tablets e 2 mesas, até 4 e 4.
3. Pegar o prato exige pão **e** salsicha? Recomendação: sim no MVP (prato meio feito não sai do slot; o hand-off é pelo slot).
4. Drive-thru entra no primeiro release do restaurante ou no seguinte? Recomendação: seguinte (R3), para soltar o loop principal antes.
