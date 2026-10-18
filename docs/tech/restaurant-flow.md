Status: Rascunho (Provisório até DEC do dono; nada aqui é código)

# Restaurante: fluxo "Overcooked de anomalia" (desenho técnico)

Autor: architect · 2026-10-17 · Fonte: `docs/source/2026-10-17-restaurante-brief.md` + esboço `2026-10-17-restaurante-esboco.webp`.
Base: `architecture.md` (§3, §18, §19.28), `network.md`, `content-data.md`, `prep-mode.md`, `prep-3d.md`, o código atual de
`src/Customer`, `src/Kitchen`, `src/Prep`, `src/Seating`, `src/Delivery`, `src/Interaction`, `src/Hud`, `src/Item`, `src/Npc`,
`src/Vehicle`, `src/Traffic`, `src/Upgrade`, `src/Shared/Content`, `src/Libs/Net/init.luau`. Anomalias do novo fluxo:
`docs/design/anomalies-v3-restaurant.md` (game-designer, paralelo). Mapa: `docs/levels/MAP-01-r4-restaurant.md`
(level-designer, paralelo; IDs `TAB-1..4`, `PLATE-1..8`, `GRILL-n`, `CUT-n`, `COND-n`, `DOOR-K`, `DT-STOP`, `DT-PC`, adotados aqui; rev. 2: `TAB-1` só, `PICKUP`, `PU-1..n`, sem `DOOR-K`).
`DT-R#` = decisão técnica proposta (o secretário numera como DEC técnica; o dono pode vetar), lista em §9.

**Rev. 2 (2026-10-17, mudança do dono):** **1 tablet** (`TAB-1`, ponta direita do balcão; 2º tablet só por upgrade);
**sai a porta de saída**; o balcão vai até a ponta esquerda com o **pote de gorjetas** e o **ponto de retirada** (`PICKUP`,
fila lateral `PU-1..n`). Cliente: fila no tablet → pede → espera na retirada → o jogador entrega o prato **no balcão** →
o cliente leva o prato, senta, come e vai embora. **O jogador não sai da loja.** Esta revisão troca `serve_table` por
entrega na retirada e volta a fila a ser única (é a fila de hoje). Onde o texto abaixo diverge, vale a rev. 2.

> **Rev. 3 (DEC-302 a DEC-305, 2026-10-18; TASK-507): a cozinha do restaurante é o modo focado com esteira.** Vale sobre a
> rev. 2 e sobre a premissa abaixo **na cozinha**: o preparo não é mais por prompts de mundo. O modo focado (DEC-223,
> `src/Prep`) fica **ligado** com o restaurante (`Prep.Rules.Mode = "Conveyor"`, `WorldKitchenPrompts = false`); a passa
> `PLATE-n` sai e entra a **mesa central** de 8 vagas (`CENTER`), onde o prato nasce vazio com o ticket e onde termina
> (DEC-304). Contrato completo: `tech/prep-conveyor.md` (não repetido aqui). Continuam valendo deste documento: tablet e
> diálogo (§2.4, §3.2), fila do tablet e fila de retirada (§3.1), sentar depois de servido, `DT-R1`, drive-thru (§3.4),
> persistência (§4.3), orçamento de NPC e IA (§7).
>
> | Seção | Situação |
> |---|---|
> | §0 linhas "pedido vai a um prato-slot", "cortar, grelhar...", "passar itens" | **superadas**: o prato nasce na mesa central; preparo na esteira; hand-off pela mesa central (§3.3) |
> | §1 linhas `Kitchen`, `Prep`, `Interaction`, `Item` | **superadas**: sem `Cut.luau`/`grill_flip`/`rail_take`; Prep ligado; item `plate` no lugar de `bun_sliced`/`sausage_grilled` (`prep-conveyor.md` §6.3, §11) |
> | §2.2 Plate | **emendada**: o set `Plates` passa a ser as 8 vagas da mesa central, com `Grade`; prato lógico com três formas (`prep-conveyor.md` §6, §7) |
> | §2.3 Station | **emendada**: as estações são as da bancada do foco; ações de mundo de preparo ficam escondidas (`prep-conveyor.md` §1.1) |
> | §3.3 Montagem e entrega | **reescrita** abaixo |
> | §4.1 `Binding.Plate*`, §4.2 linhas de `Actions`/`Items`/`Stations` do preparo de mundo | **superadas**: `Center*`, `prep_grill`, item `plate` (`prep-conveyor.md` §7.4, §11.1); as mortas em §11.2 |
> | §4.4 `GrillAutoCollect`, `SlicerStack`, `AutoFlip`, `IngredientCarry` | **sem efeito na esteira** (a pronta já vai sozinha ao descanso; não há Tool de ingrediente); o game-designer revê |
> | §5 R2 "Prep desligado", R5 "remover `src/Prep/client`" | **canceladas** |
> | §6 Modo de preparo focado | **emendada** (aviso no início da seção) |
> | §8 riscos "prompts amontoados", "Economia sem `Quality`" | **emendados**: sem prompts de preparo no mundo; a nota volta (Perfect = base + $1) |
> | §9 DT-R3, DT-R7, DT-R8, perguntas 1 e 3 | **superadas** pelas DEC-302 a DEC-305 |

**Premissa:** o jogo está publicado e com anúncio. A regra deste desenho é **reaproveitar o fluxo de mundo que já existe**
(estações com prompt, Tool `hot_dog`, `topping_add`, sentar após o pedido, `serve_table`) e acrescentar só três peças novas:
**tablets**, **pratos-slot** e (depois) **drive-thru**. Nada de economia, estoque ou entrega paralelos.

---

## 0. A leitura em uma tabela

O código já tem quase todo o "Overcooked": antes do modo focado (DEC-223) o trailer funcionava com prompts no mundo
(`grill_place`, `grill_collect`, `bun_cut`, `board_add_sausage`, `topping_add`). A fila única `Q1..Q5` com pedido em `Q1`
é exatamente a fila do tablet. O que entra: um **ponto de pedido** com conversa, **pratos-slot**, uma **fila de retirada** e o
cliente que **leva o prato e senta sozinho** (o "sentar depois de servido" já existiu antes da Q-209; volta como modo).

| Etapa | Hoje | No restaurante (rev. 2) | Peça de código |
|---|---|---|---|
| cliente chega e entra na fila do tablet | fila única `Q1..Q5`, só `Q1` pede | **igual** (`Q1` = frente do `TAB-1`); 2º tablet por upgrade = 2ª cabeça (§3.1) | `CustomerService/Queue` (sem mudança no MVP) |
| diálogo + nota construída item a item | "Take Order" instantâneo no rig | `tablet_take` no `TAB-1`, conversa de 2 a 4 s, pop-up por item; no fim o mesmo `TakeOrderFor` | `TabletService` (novo), `HudOrder` (+prop), `TabletController` (novo) |
| depois de pedir | senta na mesa (Q-209) e espera lá | **anda até a fila de retirada** `PU-1..n` e espera em pé (relógio Order corre) | `CustomerService` (fila de retirada nova) |
| pedido vai a um prato-slot com BillboardGui | não existe | (rev. 3: prato vazio com ticket nasce na **mesa central**, §3.3) ~~ticket cai no `PLATE-n` livre~~ | `PlateService` + `PlateController` + `PlateTicket` (novos) |
| cortar, grelhar/virar/empilhar, montar, condimentos | prompts de mundo / Tool `hot_dog` | (rev. 3: **modo focado com esteira**, §3.3) ~~`bun_slice`, `grill_flip`, `rail_take`, `plate_put`/`plate_take`, `topping_add`~~ | `Stations/Cut.luau` (novo), `Grill`/`Rail` (pequeno), `PlateService` |
| entregar | `serve` no rig do balcão / `serve_table` na mesa | **no balcão**: `pickup_serve` no `PICKUP` (ou `serve`/arrasto no rig do `PU-n`); o servidor acha na fila de retirada o cliente cujo pedido o hot dog atende | `CustomerService` (`ServeFor` reaproveitado) |
| cliente leva o prato, senta, come, vai embora | (antes da Q-209) sentar depois de servido, `Eating` | servido Completo/Incompleto → pega o prato (rig `Carrying`), `SeatingService:Offer` **na venda**, senta, come, vai embora; sem mesa livre = leva para viagem | `SeatingService` (modo `SitAt = "Served"`), `SeatingController` (bandeja na mão) |
| gorjeta | pote de gorjetas (`TipJarService`) + gorjeta na mesa suja | **pote na ponta esquerda do balcão** (existente); mesa **não** fica suja (o jogador não sai da loja, pergunta 5) | dados (`Seating`) |
| drive-thru | não existe | carro no client, cliente sem rig, `DT-PC` = tablet do drive, `drive_serve` na janela | `DriveThru` (novo, onda R3) |
| passar itens entre jogadores | hotbar, `give_coffee` | pela mesa central (rev. 3: pôr por clique, pegar segurando E); dar na mão fica para R4 | `PlateService` |

`serve_table` e a porta de saída **saem do fluxo** (o código de `serve_table` fica, sem âncora ligada; `DOOR-K` não existe).

---

## 1. Mapa por sistema: o que existe e o que muda

| Sistema (pasta) | Existe hoje (relevante) | Muda | Tamanho |
|---|---|---|---|
| `Customer/server/CustomerService` (2183 l.) | spawn, fila `Q1..Q5`, `Orders`/`OrderRoll` (preço, Completo/Incompleto/Errado, DEC-072), dois relógios de paciência (Q-192), pares, `SetSeater`, `TakeOrderFor`/`ServeFor`, `Acted`, `SpawnActor`, `SetHeld` | (rev. 2) fila do tablet **inalterada** (`Q1..Q5`); **fila de retirada nova** (`PU-1..n`, módulo puro `Pickup.luau`: quem pediu entra no fim, sai quando servido ou sem paciência, os de trás andam); `ServeAtPickup(player)` (escolhe na fila de retirada o cliente que o hot dog atende: `Ticket` do Tool, senão o mais antigo com pedido igual, senão o 1º = Errado); depois da venda chama o Seater com o prato na mão (`Carrying`); `PausePatience(id, on)` durante a conversa; prompt `take_order` do rig desligado com `TAB-1` no mapa; cabeças só quando houver o upgrade do 2º tablet; `SpawnDrive` (R3) | médio, **arquivo-quente** |
| `Customer/client/CustomerController` | escolhe o cliente da nota (`HudOrder`: alvo do prompt, senão `Q1` em Waiting), balões | prioridade da nota: conversa no meu tablet > ticket do prato na mão > alvo > cabeça mais antiga | pequeno |
| `Kitchen/server/KitchenService` + `Stations/*` | estações descobertas por tag `Station` dentro de `Vehicle`; módulo novo em `Stations/` **não toca o init** (StationApi); `Grill.Flip` já existe (servidor carimba); `Rail` FIFO; `Toppings` (`topping_add` com `hot_dog` na mão) | (rev. 3: **superado**; estações usadas pelo foco, `prep-conveyor.md` §5, §10.2) ~~`Stations/Cut.luau` (novo, kind `cut`, ingrediente `bun`, ação `bun_slice`, restock pelo core); `Grill.luau` ganha o prompt `grill_flip` (mesma `Grill.Flip`); `Rail.luau` ganha `rail_take`~~ | pequeno; `init.luau` **não** muda |
| `Prep/*` (modo focado, DEC-223) | ~25 mil linhas; inerte sem `Station_n` | (rev. 3: **ligado em modo esteira**, `prep-conveyor.md` §1) ~~desligado por flag (`Prep.Rules.Enabled = false`)~~ | — |
| `Seating/server/SeatingService` | `Offer` no Take Order, mesa reservada, `serve_table`, comer, gorjeta na mesa, `clean_table` | (rev. 2) **modo `Content.Seating.SitAt = "Served"`**: o `Offer` vem da venda na retirada (não do "Take Order"); o grupo anda `PU-n` → mesa com o prato, senta, come `EatTime`, vai embora; sem mesa = sai com o prato; `serve_table` sem âncora; `DirtyTables = false` (gorjeta vai ao pote, mesa volta a Free) | pequeno |
| `Seating/client/SeatingController` (`Tray`, `Meal`) | bandeja na mesa, hot dog na mão ao comer | bandeja/prato na mão enquanto o rig anda (`Carrying`) | pequeno |
| `Delivery/client/DeliveryController` | arrastar o hot dog até o cliente do balcão | vale para o cliente no `PU-n` (o `serve` do rig na retirada aciona `ServeAtPickup`); nada muda | 0 |
| `Interaction` (server + `PromptController`) | `Interact` único, `RegisterAction`, `AddGate`, `Requires.Held` (item ou categoria) | (rev. 3: **superado**; sem prompts de preparo no mundo) `Rules.luau` do cliente: mostrar `plate_put` só com `bun_sliced`/`sausage_grilled`/`hot_dog` na mão e `plate_take` só com mão livre (o servidor revalida) | pequeno, **quente** |
| `Item/server/ItemService` | Tools do kit, limites por categoria, stash, snapshot `T`, `Toppings`, `Altered` | (rev. 3: item `plate` no lugar destes, `prep-conveyor.md` §6.3) itens novos `bun_sliced`, `sausage_grilled` (categoria nova `Ingredient`, limite 2); atributo de Tool novo `Ticket` (NpcId do pedido; não entra no snapshot) | só dados + 1 atributo |
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

Ciclo (rev. 2): `Queued` em `Q2..Q5` → `Q1` (frente do `TAB-1`) → `Ordering` (relógio Queue corre) → jogador faz
`tablet_take` → `Tablets[1] = Talking` (relógio pausado, `PausePatience`) → fim da fala → `CustomerService:TakeOrderFor`
(o mesmo caminho do prompt antigo: grava `Order`, relógio Order, `Acted("take_order")`; **sem** `Offer` de mesa no modo
`SitAt = "Served"`) → `PlateService` ouve `Acted` e põe o ticket num `PLATE-n` → cliente sai de `Q1` (a fila anda) e entra
no fim da fila de retirada `PU-k` (`Customers.Pickup = k`, `State Waiting`) → jogador entrega no `PICKUP` →
veredito DEC-072 → servido: `Customers.State = Leaving` com `Dining`, rig `Carrying = true`, `SeatingService:Offer` →
mesa (senta, come, vai embora) ou saída direto com o prato; Errado: o hot dog volta à mão de quem entregou (regra atual),
o cliente segue esperando; paciência acaba: `Left`/`Slow` como hoje, sai da retirada.

### 2.2 Plate (o prato-slot)

> **Emenda rev. 3:** os slots são as 8 vagas da **mesa central** (não a passa `PLATE-n`); o prato nasce vazio com o ticket e
> existe numa de três formas (mesa, mão, esteira) sob o `PlateService`; `plate_put` ("Add Bun", "Add Sausage", "Put Plate")
> sai e o pôr é por clique (`CenterPut`). A tabela abaixo é histórico do fluxo de mundo: vale `tech/prep-conveyor.md` §6 e §7.

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

> **Emenda rev. 3:** no restaurante as estações são usadas **dentro do foco** (grelha, rail = mesa de descanso, tábua,
> condimentos); as ações de mundo de preparo desta tabela ficam escondidas (`tech/prep-conveyor.md` §1.1). Ficam no mundo
> `restock`, `discard` da BIN-C e o café.

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

Dono: `TabletService`. Rev. 2: **1 registro no MVP** (id 1 = `TAB-1`). Extensível sem mudar o schema: id 2 = `TAB-2`
(upgrade do 2º tablet, só existe registro quando o upgrade está comprado e o mapa tem a peça); id 5 = `DT-PC` (R3).

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
| `Tablets` | **set** | quem fala no tablet e quando começou: alimenta a nota do taker e o balão para os outros; 1 registro no MVP (até 3: `TAB-2` por upgrade, `DT-PC`) |
| `Customers.Pickup` | campo opcional do set existente | posição na fila de retirada; todos veem quem espera onde (BillboardGui do pedido sobre o rig, já existe o balão) |
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

	-- restaurant-flow.md §2.4, record 1 = TAB-1 (always), 2 = TAB-2 (only with the 2nd tablet upgrade bought and bound),
	-- 5 = drive-thru computer (DT-PC, wave R3). Writer: TabletService.
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

E no `Customers` existente, dois campos opcionais (R0), sem quebrar escritores antigos:

```lua
		-- restaurant-flow.md §2.1 rev. 2: place in the pickup line PU-1..n after "Take Order"; nil = not in the pickup line
		Pickup = Lync.optional(Lync.int(1, 8)),
		-- §3.4 (wave R3): drive-thru lane spot (DriveCars id); nil = a walking customer
		Drive = Lync.optional(Lync.int(1, 2)),
```

`Customers.Slot` mantém schema e significado (`1..5` = fila do tablet; com o 2º tablet, `1..Heads` = cabeças). Enums vêm do `Content` (Lync ordena os nomes; os dois lados requerem o mesmo `Content`).

Ritmo: `Plates` < 2 escritas/s no pico (4 jogadores), `Tablets` 2 escritas por pedido, `DriveCars` 3 por carro. Soma
< 150 B/s por client no pior caso: irrelevante perto de `Customers`/`Stations`.

---

## 3. Fluxos detalhados

### 3.1 Fila do tablet e fila de retirada (CustomerService)

**Fila do tablet (rev. 2): a de hoje, sem mudança.** `Q1` = frente do `TAB-1`, `Q2..Q5` atrás (tamanho pelo upgrade
`counter`, `QueueSize`). O prompt `take_order` do rig fica desligado quando o `TAB-1` está ligado (o pedido é no tablet).

**2º tablet (upgrade, depois do MVP):** `Queue` ganha `Heads` (2 cabeças fixas: `Q1` = `TAB-1`, `Q1B` = `TAB-2`; quem sai de
uma cabeça não move a outra; o primeiro da espera vai à cabeça livre). Ativado por `Effect("TabletCount")` = 2 **e** `TAB-2`
no mapa; com 1, o código é o de hoje. Fica fora do MVP para não mexer no `Queue.luau` agora.

**Fila de retirada (nova, MVP):** módulo puro `CustomerService/Pickup.luau` (mesmo formato do `Queue`: lista, `join`,
`leave`, `point(k) = "PU-k"`; testável em Luau puro).

- Depois do "Take Order" (fim da fala), o cliente sai de `Q1` (a fila do tablet anda) e anda até o fim da retirada
  (`PU-k`, `Customers.Pickup = k`). `PU-1` = no balcão, ao lado do `PICKUP`; `PU-2..n` = fila lateral (`MapPoint` + `NpcNode`).
- O relógio Order continua (Q-192); acabou → `Slow`, sai da fila, os de trás andam.
- Tamanho: `Content.Restaurant.Rules.PickupSlots` (proposta 4). Retirada cheia → o "Take Order" é recusado
  (`Notice pickup_full`) e o cliente fica no tablet: é a pressão natural da cozinha. `PlateSlots` (8) ≥ `PickupSlots`, então o
  gate `Plates` raramente dispara.
- Pares (FEAT-038): o par ocupa 1 lugar (o parceiro segue o líder como hoje, `StepPairs`); cada linha é servida à parte.
- Sem `PU-n` no mapa: comportamento antigo (espera em `Q1`, servido ali). É o rollback.

**Entrega no balcão:** `pickup_serve` "Hand Over" (tap, raio 6) no `Prompt_Serve` do `PICKUP` e o `serve` do rig de quem está
na retirada (o arrasto do `DeliveryController` cai nele) chamam `CustomerService:ServeAtPickup(player)`. O servidor escolhe o
cliente: (1) o dono do `Ticket` do hot dog, se está na retirada; (2) o mais antigo da retirada cujo pedido o hot dog
atende (`Orders.Match`); (3) senão o `PU-1` → veredito Errado (regra atual: o hot dog volta à mão). Preço, gorjeta, humor
e `Sale`: o caminho do `ServeFor` atual.

**Depois de servido:** linha Completa/Incompleta → `Leave(..., dining = true)` com o rig `Carrying = true` (o client põe o
prato com o `HotDogVisual` na mão do rig) → `SeatingService:Offer(party)` (modo `SitAt = "Served"`; as mesmas 5 condições)
→ mesa: anda, senta, `Eating`, vai embora (fluxo atual a partir de `Eating`); sem mesa: sai pela rota de saída levando o
prato. Mesa não fica suja (`Content.Seating.DirtyTables = false`): a gorjeta de mesa vai direto ao pote
(`TipJarService`), porque o jogador não sai da loja (pergunta 5).

### 3.2 Diálogo e nota (client)

- `TabletController` (novo) lê `Tablets`. Se `User == eu` e `Talking`: abre a nota com `Reveal` crescendo pelo relógio do
  servidor e mostra as falas em `TabletDialog` (Vide, inferior esquerdo ou balão sobre o cliente; nada central em 1ª pessoa,
  AGENT-BRIEF §4). Para os outros: só o balão sobre o cliente.
- Falas: `Content.Restaurant.Dialog` (`Greeting`, `Ask[ingrediente]`, `Close`; inglês na UI, narrative-writer). Voz TTS é
  opcional e posterior (sem "sausage", `frank`).
- ANM-001 (sem rosto): nota em branco, sem pop-ups (o `HudOrder` já tem `Empty`).
- Depois da fala, a nota segue a regra de prioridade (§1, `CustomerController`): com prato na mão, mostra o pedido do
  `Ticket` daquele prato.

### 3.3 Montagem e entrega (rev. 3: esteira e mesa central; DEC-302 a DEC-305)

Contrato: `tech/prep-conveyor.md` (números de seção entre parênteses). Aqui só o fluxo do restaurante de ponta a ponta.

1. **Ticket → prato na mesa central** (DEC-304). Fim da fala do tablet → `CustomerService:TakeOrderFor` →
   `Acted("take_order")` → `PlateService:Assign`: nasce um **prato vazio com o ticket #n** (um por linha da dupla) na vaga
   livre de maior índice da **mesa central** (`CENTER`, fileira de 8, set `Plates`; §6.2, §7.1). Um prato órfão já
   montado que sirva ao pedido adota o ticket. Sem lugar (teto de tickets cheio), o tablet não toma o pedido ("Kitchen
   full"; §7.3). O client desenha o prato e a plaquinha do ticket na vaga (`Att_Ticket`).
2. **Pegar o prato:** **segurar E** no `Prompt_Take` da vaga (`plate_take` da mesa central) → Tool `plate` na mão (até 2
   pratos, categoria `HotDog`); enquanto o jogador segura o prato, o **ticket fica no HUD** (§6.3, §6.4, §7.2).
3. **Grelhador:** prompt **Grill** (`prep_grill`, `Prompt_Grill`) → assento de grelha e vista focada da grelha: clicar põe
   e vira; pronta em 8/6/4 s (UPG-001), **sem queima e sem barra**; virar na janela dá só bônus (`FlipBonus`), fora da nota;
   a pronta vai **sozinha à mesa de descanso** (8 lugares; cheia = espera na grelha) (§2.2, §5).
4. **Montador:** prompt **Work** (`prep_work`, `Prompt_Work`) com o prato na mão → assento de esteira (até 2) e o prato
   desce à esteira na parada 1. Setas esquerda/direita levam o **próprio** prato (`PrepBelt`); uma estação por prato, o
   2º espera ao lado. Na **Tábua**: cortar o pão arrastando e arrastar a salsicha do descanso ao pão (`PrepStage Cut`/`Dog`).
   Nos **Condimentos**: desenhar o padrão de cada molho e fechar (`PrepFinish`) → nota Perfect/Good/Messy, calculada só em
   `Grade`. O prato vai a `Out`, o foco termina e ele volta à mão como `hot_dog` com `Quality` (§3, §4, §6.5, §6.7).
5. **Solo:** sair da esteira deixa o prato **parado e reservado** na parada; o jogador usa o prompt Grill e volta pelo
   Work para retomar o mesmo prato (§2.3, §2.4).
6. **Mesa central ou PICKUP:** com o `hot_dog` na mão, **clicar numa vaga livre** põe o prato (`CenterPut`), para outro
   jogador pegar e entregar; ou **segurar E** no `PICKUP` (`pickup_serve`, "Hand Over") entrega ao **dono do ticket** que
   está na fila de retirada (§7.2, §7.5, §8). Prato pela metade também pode voltar à mesa (levar até `Out`, sair, clicar).
7. **Errou ou perdeu:** a lixeira do foco esvazia o prato e mantém o ticket (§6.6); `discard` na BIN-C com o hot dog na mão
   faz nascer um prato vazio novo com o mesmo ticket se o cliente ainda espera; cliente que foi embora deixa o prato órfão
   (§7.6).

Veredito Completo/Incompleto/Errado, preço, janela de gorjeta (DEC-072) e humor: **inalterados**. Em cima disso, a nota
volta (DEC-303): **Perfect = gorjeta base + $1** (`Grades.Effects.Perfect.TipExtra = 1`, DEC-305) e o bônus de virar soma
uma vez por prato (§8). Saem do restaurante: `bun_slice`, `bun_sliced`/`sausage_grilled`, `grill_place`/`grill_flip`/
`grill_collect` de mundo, `rail_take`, `topping_add` de mundo, `plate_put` e a passa `PLATE-n` (lista exata em
`prep-conveyor.md` §1.1; limpeza na TASK-506), além de `serve_table`, mesa suja e `clean_table` (código fica, sem âncora).

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
	Enabled: boolean,        -- false = trailer flow (no pickup line, no plate gate, tablets ignored)
	PlateSlots: number,      -- 8 (map may bind fewer)
	PickupSlots: number,     -- 4: PU-1..n; full = "Take Order" refused (pickup_full)
	TabletsMax: number,      -- 2: TAB-1 always, TAB-2 with the upgrade (TabletCount); records 1..TabletsMax
	TakeawayWhenNoTable: boolean, -- true: served with no free table = leaves carrying the plate
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
	PickupTag: "Pickup", PickupPrompt: "Prompt_Serve", PickupPoint: "PU-%d",               -- Model PICKUP + MapPoints
	DriveStop: "DT-STOP", DriveIn: "DT-IN", DriveOut: "DT-OUT", DrivePc: "DT-PC", DriveWindow: "DT-WIN",
}
```

Regras de binding (§18 da arquitetura), rev. 2: **tag + atributo** decidem, o nome é o `MapId` do level-designer.

| Peça | Binding |
|---|---|
| `TAB-1` (ponta direita do balcão) | `Model` tag `Tablet`, `TabletIndex = 1`, filho `Prompt_Take` (tag `Interactable`, `PromptAction = tablet_take`), opcional `Att_Screen` (balão). `MapPoint` `Q1` na frente dele, `Q2..Q5` atrás (como hoje) |
| `TAB-2` (opcional, upgrade) | igual, `TabletIndex = 2`, `MapPoint` `Q1B`; ausente no MVP |
| `PICKUP` (ponta esquerda do balcão) | `Model` tag `Pickup`, filho `Prompt_Serve` (`PromptAction = pickup_serve`); `MapPoint` + `NpcNode` `PU-1` (no balcão) .. `PU-n` (fila lateral), em cadeia, ligados ao grafo das mesas e à saída |
| pote de gorjetas | o `TRL-TIPJAR` existente (`TipJarService`), movido para a ponta esquerda, ao lado do `PICKUP` |
| `PLATE-1..8` | `Part` tag `PlateSlot`, `PlateIndex = n`, âncoras `Prompt_Put`/`Prompt_Take`, `Att_Ticket` (BillboardGui), prato visual filho |
| `GRILL-n`/`CUT-n`/`COND-n`/`BIN-K` | `Model` tag `Station` + `StationKind` (§18.4 inalterado), dentro do Model `Vehicle = "trailer"` (o prédio) |
| mesas | as 4 `SeatTable` `TableIndex 1..4`, `TBL-1..4`; **sem** `ServeAnchor`/`CleanAnchor` ligados (o client não mostra prompt de mesa) |
| `DOOR-K` | **sai** (o jogador não sai da loja); a cozinha é fechada, cliente nunca entra |
| `DT-*` (R3) | `MapPoint`; `DT-PC` = `Model` tag `Tablet`, `TabletIndex = 5`; `DT-WIN` = âncora `drive_serve` |

**Pontos de compatibilidade que o restaurante TEM de manter** (lidos por código vivo; `MapIndex/Required.luau` falha o boot
sem eles): `TRL` (pivô do prédio), `CART` (frente do `TAB-1`; Adopt e cutscene), `Q1..Q5` (fila do tablet), `PS-1..4`/`PS-N1..4`
(spawn dentro da cozinha), `DROP-T`, `L3`, `AN-05`, `TRL-OUT` (pouso dentro da loja, já que não há saída), `LightZone LZ-1`
(volume da cozinha = "dentro", proteção e luz), `TBL-1..4` e as `SeatTable`, `Prompt_Shutter` + persiana do balcão. Novos
obrigatórios no restaurante: `PU-1..n`, o `PICKUP` e o `TAB-1`.

### 4.2 Linhas novas nas tabelas existentes

> **Emenda rev. 3:** `bun_slice`, `plate_put`, `grill_flip`, `rail_take`, os itens `bun_sliced`/`sausage_grilled`,
> `CategoryLimits.Ingredient`, a estação `cut` e `Binding.Plate*` estão mortos no restaurante; as chaves novas da esteira
> (`prep_grill`, item `plate`, `CenterTable`, `Binding.Center*`, `Conveyor.*`) estão em `tech/prep-conveyor.md` §11.

| Tabela | Linhas |
|---|---|
| `Actions` | `tablet_take` "Take Order" (tap, r 6), `bun_slice` "Slice Bun" (0,8 s, r 6), `plate_put` "Add {item}"/"Put Plate" (tap, r 5), `plate_take` "Take Plate" (tap, r 5), `grill_flip` "Flip" (tap, r 7), `rail_take` "Take Sausage" (tap, r 7), `pickup_serve` "Hand Over" (tap, r 6; rev. 2), `drive_serve` "Hand Over" (tap, r 6, R3); o drive usa `tablet_take` no `DT-PC` |
| `Seating` | `SitAt = "Served"` (novo campo; `"Order"` = Q-209, o trailer), `DirtyTables = false` (gorjeta de mesa direto ao pote) |
| `Items` | `bun_sliced`, `sausage_grilled` (categoria nova `Ingredient`); kit Tools em `ReplicatedStorage.Assets.Items.Tools/<key>` (FoodPack) |
| `ItemRules.CategoryLimits` | `Ingredient = 2` (Provisório; upgrade de bandeja pode subir) |
| `Stations` | `cut` (`Record = "None"`, `Ingredient = "bun"`, `Actions = {"bun_slice", "restock"}`, `Params = { CutTime = 0.8 }`); `grill.Actions` += `grill_flip`; `rail.Actions` += `rail_take` |
| `Notices` | `plates_full`, `pickup_full`, `plate_full`, `plate_not_ready`, `tablet_busy`, `drive_left` (R3) |
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

> **Emenda rev. 3:** na esteira `GrillAutoCollect` já é o padrão, e `SlicerStack`, `AutoFlip` e `IngredientCarry` não têm
> onde agir (corte e virar são gestos; não há Tool de ingrediente). O game-designer revê esta lista.

Todos são `Stats` lidos por `ctx.Effect(stat)` dentro do módulo dono, sem serviço novo:

| Stat (proposta) | Lido em | Efeito |
|---|---|---|
| `TabletCount` | `CustomerService/Queue`, `TabletService` | 1 ou 2 (upgrade novo "Second Tablet"; liga `TAB-2` e a 2ª cabeça, §3.1) |
| `PickupSize` | `CustomerService/Pickup` | lugares na retirada (mais clientes esperando sem travar o tablet) |
| `GrillAutoCollect` | `Stations/Grill.luau` (Tick) | salsicha pronta vai sozinha à pilha (tira um papel do solo) |
| `SlicerStack` | `Stations/Cut.luau` (Tick) | o `CUT` corta sozinho até N pães; `bun_slice` vira instantâneo enquanto há pão cortado |
| `AutoFlip` | `Stations/Grill.luau` | vira sozinho no fim do 1º lado |
| `IngredientCarry` | `ItemService` (limite da categoria) | bandeja: carregar 2 → 4 itens |
| `TalkSpeed` | `TabletService` | `TalkStep` x fator (atender mais rápido) |
| `KioskTablet` | `TabletService` | um tablet atende sozinho após X s sem jogador (solo atende enquanto cozinha) |

---

## 5. Ondas e posse de arquivos

> **Emenda rev. 3:** as ondas R0 a R2 são histórico do fluxo de mundo. As tarefas da cozinha com esteira estão no board,
> tabela "Cozinha com esteira" (TASK-496, 503 a 523); a posse de arquivos delas vale sobre esta seção.

Regra: um dono por arquivo por onda; arquivo novo sempre que possível. Antes da R0 o orquestrador **commita a árvore atual**
(há mudanças não commitadas em quase todos os arquivos-quentes abaixo).

### Onda R0: contratos (1 agente, sequencial, ~meio dia; bloqueia todas)

| Arquivo | Mudança |
|---|---|
| `src/Shared/Content/Restaurant.luau` (novo) + `Content/init.luau` (1 linha) | §4.1 |
| `Content/Actions.luau`, `Items.luau`, `Stations.luau`, `Notices.luau`, `Vehicles.luau`, `Sounds.luau`, `Validate.luau` | §4.2 |
| `src/Libs/Net/init.luau` | `Plates`, `Tablets` (1 registro no MVP), `Customers.Pickup` (§2.6). `DriveCars` e `Customers.Drive` já entram aqui também (schema pronto, sem escritor; evita reabrir o arquivo na R3) |
| `src/Place/shared/MapIndex/Required.luau` | `PU-1..n` (obrigatório quando há `TAB-1`), `Q1B` opcional; `DT-*` opcionais até a R3 |
| `Content/Seating.luau` | `SitAt`, `DirtyTables` (§4.2) |
| Aceite | `rogen build` → `modux generate` → `modux check` 0 erro; `Lync.start()` sem erro de schema em Play (o analyze não pega schema) |

### Onda R1: MVP em paralelo (8 trilhas, arquivos disjuntos)

| Trilha | Dono | Arquivos (só estes) | Depende |
|---|---|---|---|
| **R1-A** Kitchen | backend | `Kitchen/server/KitchenService/Stations/Cut.luau` (novo), `Stations/Grill.luau`, `Stations/Rail.luau` | R0 |
| **R1-B** Plate (server) | backend | `src/Plate/server/PlateService/init.luau` (novo) + `Slots.luau` (novo, puro), `Dev/server/DevService/Commands/Plate.luau` (novo) | R0 |
| **R1-C** Customer | backend | `Customer/server/CustomerService/Pickup.luau` (novo, puro, com testes de tabela), `CustomerService/init.luau` (fila de retirada, `Customers.Pickup`, `ServeAtPickup`, `serve` do rig na retirada, `PausePatience`, prompt `take_order` do rig desligado, Seater chamado na venda com `Carrying`, saída para viagem). `Queue.luau` **não** muda no MVP (cabeças só com o 2º tablet) | R0 |
| **R1-D** Tablet (server) | backend | `src/Tablet/server/TabletService.luau` (novo), `Dev/.../Commands/Tablet.luau` (novo) | R0 (chama APIs de R1-B/R1-C por nome; mock por tipo até lá) |
| **R1-E** Mapa | level-designer + Studio | restaurante no place (tag `Vehicle`, `Vehicle = "trailer"`), trailer antigo para `ServerStorage.TRAILER_Backup_20261017` (com `OrigPath`/`OrigTags`), snippet `tools/assetplace/restaurant_bind.luau` (novo, idempotente), kit Tools `bun_sliced`/`sausage_grilled`; seção nova no `STUDIO_LAYER.md` | R0 (nomes) |
| **R1-F** Plate + Tablet (client) | frontend | `src/Plate/client/PlateController.luau` (novo), `src/Tablet/client/TabletController.luau` (novo), `Interface/client/Components/PlateTicket/` (novo + story), `Interface/client/Components/TabletDialog/` (novo + story), `Interaction/client/PromptController/Rules.luau` | R0 |
| **R1-G** Nota do HUD | frontend | `Interface/client/Components/HudOrder/init.luau` (+`Reveal`, story), `Customer/client/CustomerController/init.luau` (prioridade da nota) | R0 |
| **R1-H** Veículo | backend | `Vehicle/server/TrailerDoorService.luau` (`HasBackDoor`), conferir `VehicleService/Shutter.luau` com o `LZ-1` novo (sem mudança esperada) | R0 |
| **R1-I** Seating (rev. 2) | backend | `Seating/server/SeatingService/init.luau` (modo `SitAt = "Served"`: `Offer` a partir da venda, grupo sai do `PU-n` com o prato; `DirtyTables = false`: gorjeta ao pote pelo `TipJarService`, mesa volta a Free; sem âncoras `serve_table`/`clean_table` no restaurante) | R0 |
| **R1-J** Seating client (rev. 2) | frontend | `Seating/client/SeatingController/{Tray,Meal}.luau` (prato na mão do rig com `Carrying`, depois na mesa) | R0 |

Prioridades de boot (`SeatingService` 568 continua acima; o `CustomerService` chama o Seater por callback, sem `Require` novo): `PlateService` **566** (`Require`: `InteractionService`, `ItemService`, `KitchenService`, `CustomerService`,
`RoundService`, `NetService`; conecta `CustomerService.Acted`/`Left` no `OnStart`), `TabletService` **564** (`InteractionService`,
`CustomerService`, `PlateService`, `UpgradeService`, `NetService`), `DriveThruService` **562** (R3: `CustomerService`,
`TabletService`, `PlateService`, `RoundService`, `NetService`). Controllers: `PlateController` e `TabletController` abaixo de
`CustomerController`, sem dependência entre si (os dois só leem sets). Responders: nenhum novo (só `Interact`, que é do
`InteractionService`).

### Onda R2: fechar o MVP (sequencial curto)

| Trilha | Arquivos |
|---|---|
| ~~Prep desligado~~ | **cancelado** (rev. 3): o Prep fica ligado em modo esteira (`prep-conveyor.md` §1) |
| Tutorial mínimo do restaurante (bloqueia release) | `Tutorial/server/TutorialService.luau`, `Tutorial/client/TutorialController/{init,Steps}.luau`, `Tutorial/shared/Rules.luau`: tablet → mesa central → esteira (cortar, salsicha, condimento) → grelha → entregar no `PICKUP` (rev. 3; roteiro na TASK-511) |
| Smoke | `Dev/server/DevService/Commands/Smoke.luau`: um pedido de ponta a ponta por `/dev` (tablet → prato → `pickup_serve` → cliente senta) |
| Números do restaurante | `Content/Restaurant.luau`, `Upgrades.luau` (mesas iniciais, 2º tablet, `PickupSize`), `Flow.luau` (intervalo com 1 tablet) — game-designer |
| QA | plano do qa-tester (solo e 4 jogadores, mobile) |

**MVP técnico = R0 + R1 (A a J) + R2.** Loop jogável (rev. 2): cliente → fila do `TAB-1` → conversa com nota → espera na
retirada → ticket no prato → cortar / grelhar / virar / empilhar → prato → condimentos → entrega no `PICKUP` → paga → o
cliente leva o prato, senta, come, vai embora (gorjeta no pote). O jogador nunca sai da loja. Sem drive-thru, sem pets,
sem voz, sem anomalias novas (as V2 que dependem de peça do trailer ficam desligadas por dado até a R4).

### Ondas seguintes

| Onda | Conteúdo | Arquivos |
|---|---|---|
| **R3** drive-thru | spike sem rig (meio dia), `SpawnDrive`, carro, buzina, `drive_serve`, tablet 5 | `src/DriveThru/server/DriveThruService.luau` (novo), `src/DriveThru/client/DriveThruController.luau` (novo), `CustomerService/init.luau` (dono R1-C), `TabletService.luau` (dono R1-D), `Content/Restaurant.luau` (`Drive`) |
| **R4** anomalias V3, co-op e 2º tablet | `Content.Anomalies` + `Rules/ANM-0xx.luau` (doc do game-designer); `KitchenService:Alter("grill")` e `PlateService:Alter`; 2º tablet (`Queue.luau` com cabeças, dono R1-C; `TabletService`); guichê por tablet (Q-330, perde peso com 1 tablet); pets; `give_item` entre jogadores (padrão do `give_coffee`); voz das falas; upgrades do solo (§4.4) | arquivos de regra são novos; `Grill.luau`/`Cut.luau` voltam ao dono R1-A |
| **R5** limpeza | (rev. 3: **cancelada** para o Prep, que é a cozinha do restaurante) remover `src/Prep/client/**` e `PrepService` depois de 1 release estável do restaurante (o `Prep/shared/Grade` fica: `CustomerService` e `Grill` o requerem); apagar âncoras `Station_n` do backup | só remoção |

### Arquivos-quentes (conflito)

| Arquivo | Por quê | Regra |
|---|---|---|
| `src/Libs/Net/init.luau` | todo set/packet | só R0 (inclui o schema da R3) |
| `src/Shared/Content/{Actions,Items,Stations,Notices,Vehicles,Validate,init}.luau` | toda feature acrescenta linha | só R0; números depois só em `Restaurant.luau`/`Upgrades.luau` |
| `src/Customer/server/CustomerService/init.luau` (2183 l.) | fila, retirada, pedido, drive | **um dono para o projeto todo** (R1-C → R3) |
| `src/Customer/client/CustomerController/init.luau` | nota do HUD | só R1-G |
| `src/Interaction/client/PromptController/Rules.luau` | visibilidade dos prompts | só R1-F |
| `src/Kitchen/server/KitchenService/init.luau` | ninguém deve precisar (StationApi descobre módulos) | se precisar, para e fala com o architect |
| `src/Hud/client/HudController.luau` | não muda | — |
| `src/Seating/server/SeatingService/init.luau` | modo `SitAt` | só R1-I |
| `src/Tutorial/**`, `Dev/.../Smoke.luau` | já modificados nesta árvore | só R2 |
| place (Studio), `MAP-01_placements.luau`, `STUDIO_LAYER.md` | edição à mão do dono | só R1-E; **nunca `Place.run`** sem pedido (memória `studio-hand-edits`) |

---

## 6. Modo de preparo focado (DEC-223) e código do trailer

> **Emenda rev. 3 (DEC-302):** o primeiro e o terceiro itens abaixo estão **superados**. O Prep **não** fica desligado no
> restaurante: a chave dupla é `Switch.PrepEnabled = true` sempre, `Switch.PrepMode = "Conveyor"` com o restaurante e
> `Switch.WorldKitchenPrompts = false` sempre (`tech/prep-conveyor.md` §1). A DEC-223 **vale** no restaurante, com a esteira
> no lugar das abas/pan e da tábua por assento. O item do trailer (backup, chave `trailer`, DT-R1) e o rollback para o
> trailer continuam; o rollback para prompts de mundo deixa de existir depois da TASK-506.

- **Prep:** desligado por `Prep.Rules.Enabled = false`. O restaurante não tem `Station_n`, então o `PrepService` fica inerte
  mesmo sem a flag; a flag garante que nenhum `prep_work` apareça. **Não remover agora** (risco e tempo): fica o rollback e
  a chance de reaproveitar uma vista focada como bônus opcional numa estação (ex.: corte de precisão no `CUT` dá gorjeta),
  depois. `Grade` e o `Quality` continuam no código; sem prep, nenhum hot dog tem `Quality` (gorjeta Perfect do prep some:
  impacto de economia para o game-designer). Isto **suspende a DEC-223 no restaurante: precisa de DEC do dono**.
- **Trailer:** sai do mapa para `ServerStorage.TRAILER_Backup_20261017` (mesmo padrão do `CART_Backup`). O código não tem
  flag de "veículo": o restaurante **herda a chave `trailer`** (DT-R1), então `Upgrades`, `Stations`, `Seating`, snapshots e
  as 75 referências a `"trailer"` continuam válidas. Renomear para `restaurant` é cosmético e caro: fica para a R5, se o dono quiser.
- **Chave única (TASK-390):** ligar o restaurante = só `Content.Restaurant.Rules.Enabled = true`. Os outros dados derivam de
  `Content.Restaurant.Switch` na hora do `require` (ninguém edita à mão): `Prep.Rules.Enabled = false` e
  `Prep.Rules.WorldKitchenPrompts = true` (a cozinha do restaurante é de prompts de mundo), `Seating.SitAt = "Served"`,
  `Seating.DirtyTables = false`, `Vehicles.trailer.HasBackDoor = false` / `Restaurant = true`, as anomalias de
  `Switch.CutAnomalies` saem da agenda (`Family = nil`, sem `Scripted`: ANM-002, 003, 004, 007, 009 e a família B inteira
  017/018/019, que pede o HideZone atrás do trailer) e `Nights[6..9].NewAnomaly` passam a 014/015/008/016 (a 016 estreia na
  N9). O `Validate` falha se algum desses campos não seguir a chave. Provisório até a R4 (anomalias V3).
- **Rollback** (sem código): `Restaurant.Rules.Enabled = false` (tudo acima volta junto) + trailer de volta do backup no
  Studio (snippet `restaurant_bind.luau "undo"`). Com `Enabled = false` não há fila de retirada (serve em `Q1`), `Seating.SitAt` volta a `"Order"` e o gate dos pratos some.

---

## 7. Orçamento

| Item | Teto (Provisório) |
|---|---|
| Rigs animados no servidor | 12 (DEC-045) de dia: até 5 na fila do tablet + 4 na retirada + até 8 sentados disputam o mesmo teto (`MaxCustomersDay` 8 já limita); à noite ≤ 9 (§6.3 do doc de anomalias, Q-334) |
| Carros do drive | 1 parado + 1 na fila, só client, **sem rig** (motorista no modelo) |
| Pets | 1, rig do pool (conta no teto) |
| BillboardGui | 8 pratos + 1 a 2 tablets + balões da retirada (já existem), `MaxDistance` 40, atualizam só quando o registro muda |
| Rede | `Plates` < 2 escritas/s, `Tablets` por pedido, `DriveCars` por carro; nada a 10 Hz |
| IA | sem mudança de estratégia: A* no grafo `NpcNode` (≤ 80 nós; o prédio troca nós do Pad, não soma), ≤ 2 rotas por frame, `MoveTo` por aresta ≤ 40 studs; cliente nunca entra na cozinha; grafo novo: `Q1..Q5` → `PU-1..n` → mesas/saída |
| Servidor | `PlateService` sem tick (só eventos); `TabletService` tick 2 Hz só para fim de fala; `DriveThruService` 2 Hz |

---

## 8. Riscos

| Risco | Mitigação |
|---|---|
| **Mobile: prompts amontoados** (8 pratos lado a lado, tablet, retirada, grelha + pilha) (rev. 3: restam `Prompt_Work`, `Prompt_Grill`, `Prompt_Take` das vagas e o `PICKUP`; espaçamento em `levels/MAP-01-r4-restaurant.md` §16) | prompts contextuais por mão (`Rules.luau`: `plate_put` só com item certo, `plate_take` só com mão livre), raio 5 nos pratos, slots a ≥ 2,5 studs (pedido ao level-designer), o `InteractionMenu`/modo "Single" existente escolhe o mais perto; testar em 667x375 |
| **Câmera dentro de prédio pequeno** (parede e teto atrás do personagem) | teto e parede da frente com fade local quando o jogador está no `LZ-1` (client, `CameraController` ou snippet de `LocalTransparencyModifier`), ou `DevCameraOcclusionMode = Invisicam` no place; decidir em Play na R1-E |
| **Boot quebra sem os pontos legados** (`TRL`, `CART`, `LZ-1`, `Q1..Q5`, `PS-*`, `DROP-T`, `L3`, `AN-05`, `TRL-OUT`) | lista de compatibilidade (§4.1) como aceite da R1-E; `check_map01` e `/dev smoke` antes de entregar |
| **Anomalias V2 presas ao trailer** (ANM-002 tábua/trilho, ANM-004 porta dos fundos, ANM-009 batida, alucinações de teto, persiana) | no MVP desligar por dado as que dependem de peça que não existe; adaptação na R4 pelo doc do game-designer; `Alter("board")` devolve `false` sem tábua (já é seguro) |
| **Studio e place** (dono edita à mão; `Place.run` apaga) | só snippets idempotentes e cirúrgicos (`restaurant_bind.luau`, por tag/atributo, com `undo`); `list_roblox_studios` antes; `Place.diff` = 0 e o dono salvar antes de qualquer rebuild; `MeshId` por clone do template |
| **CustomerService enorme e já modificado** | um dono só; a retirada em `Pickup.luau` puro com testes de tabela (`Queue.luau` intocado no MVP); commit da árvore antes da R0 |
| **Gargalo de 1 tablet** (rev. 2: um jogador preso no tablet, fila parada) | conversa curta e sem trava; `KioskTablet`/`TalkSpeed` e o 2º tablet como upgrades; `PickupSize` evita que a retirada cheia trave o tablet; medir `Left` na fila do tablet |
| **Cliente na retirada "some" da vista da cozinha** | balão do pedido sobre o rig (já existe) + `PlateTicket` mostra o paciente; `PU-1` visível do `COND` (pedido ao level-designer) |
| **Cliente carregando prato + pathfinding até a mesa** | mesmo `Diner.Sit` e rota `TBL-n`; o prato é só visual no client (`Carrying`); sem mesa livre, sai para viagem (nunca fica parado no salão) |
| **Solo chato / pior que o trailer** (5 estações para um jogador) | pré-preparo (prato com pão+salsicha recebe o próximo ticket, `PreppedFirst`), upgrades de automação (§4.4) e `KioskTablet`; medir `Left`/`Slow` contra o baseline do trailer nos primeiros dias |
| **Ritmo: conversa de 2 a 4 s por pedido** | `TalkStep` curto, conversa não trava o jogador, relógio de paciência pausado durante a fala; `TalkSpeed` como upgrade |
| **Schema do Lync** (erro só em runtime, derruba o `start`) | R0 testa em Play; nenhum `keyBy`; registros acima de 1 byte |
| **Hotbar** (4 slots, `Ingredient` 2 + `HotDog` 2) pode confundir (rev. 3: só `HotDog` 2, `plate` e `hot_dog`; sem `plate_put`) | ícones dos Tools novos; o `plate_put` consome o item certo sem precisar equipar (o servidor escolhe no Backpack, como `PickServeTool`) |
| **Tutorial do jogador novo quebra** (o atual ensina o prep) | tutorial mínimo é **bloqueante** do release (R2); até lá, publicar só com o tutorial reescrito |
| ~~Economia sem `Quality`~~ | **superado** (rev. 3): a nota volta; Perfect = gorjeta base + $1 (DEC-305) |

---

## 9. Decisões técnicas propostas (veto livre) e perguntas

- **DT-R1** O restaurante é o Model `Vehicle = "trailer"` (chave mantida); sem veículo novo, sem migração de snapshot.
- **DT-R2** Sem entidade Order nova: o pedido continua o `Ticket` do `CustomerService`; o restaurante só diz onde ele está (cabeça, prato).
- **DT-R3** (superada na rev. 3 pela DT-E7/DT-E8 de `prep-conveyor.md`) O prato vira o Tool `hot_dog` ao ser pego (atributo `Ticket` só de guia); no slot é estado do `PlateService`. Itens intermediários são Tools (`bun_sliced`, `sausage_grilled`, categoria `Ingredient`).
- **DT-R4** (rev. 2) Fila do tablet = a fila única atual; fila de retirada nova em `CustomerService/Pickup.luau`; cabeças fixas no `Queue` só com o upgrade do 2º tablet (`TabletCount`).
- **DT-R5** Rede: 2 sets novos no MVP (`Plates`, `Tablets` com 1 registro, extensível a `TAB-2` e `DT-PC`), `Customers.Pickup` opcional, 1 na R3 (`DriveCars`), `Customers.Drive` opcional; nenhum packet novo, nenhum `keyBy`; buzina e pop-ups derivados do relógio do servidor.
- **DT-R6** Cliente do drive-thru sem rig (motorista no modelo do carro, client), plano B rig invisível após spike.
- **DT-R7** (superada na rev. 3: sem `Cut.luau`; as estações são usadas pelo foco) Estações novas como módulos do `KitchenService` (`Stations/Cut.luau`), sem tocar no `init`.
- **DT-R8** (superada na rev. 3, DEC-302: Prep ligado em modo esteira) Prep desligado por flag, código mantido até 1 release estável (remoção na R5, `Grade` fica).
- **DT-R9** Features novas: `src/Plate`, `src/Tablet`, `src/DriveThru` (cada uma `server` + `client`); `Content.Restaurant` em `Shared/Content`.
- **DT-R10** Binding por tag + atributo (`Tablet`/`TabletIndex`, `PlateSlot`/`PlateIndex`); nomes `TAB-n`, `PLATE-n`, `GRILL-n`, `CUT-n`, `COND-n`, `PICKUP`, `PU-n`, `DT-*` são `MapId`.
- **DT-R11** (rev. 2) Entrega no balcão (`pickup_serve` / `serve` no rig da retirada → `ServeAtPickup`); o cliente leva o prato e o `SeatingService` o senta **depois da venda** (`Seating.SitAt = "Served"`); `serve_table` e mesa suja saem do restaurante (código fica).

Perguntas ao dono (o secretário numera; não bloqueiam a R0/R1, seguem com a recomendação):

1. (Respondida pela DEC-302: o modo focado vale no restaurante, com esteira.) DEC-223 (modo focado) fica **suspensa no restaurante**? Recomendação: sim, flag desligada, código mantido.
2. Quantas mesas no Dia 1 e o 2º tablet é upgrade de que dia? Recomendação: 2 mesas (até 4); 2º tablet a partir do Dia 3.
3. (Superada pela DEC-304: o prato nasce vazio na mesa central e é pego vazio.) Pegar o prato exige pão **e** salsicha? Recomendação: sim no MVP (prato meio feito não sai do slot; o hand-off é pelo slot).
4. Drive-thru entra no primeiro release do restaurante ou no seguinte? Recomendação: seguinte (R3), para soltar o loop principal antes.
5. Sem o jogador sair da loja, quem limpa as mesas? Recomendação: ninguém; a mesa volta livre quando o cliente sai e a gorjeta de mesa cai no pote (`DirtyTables = false`).
6. Sem mesa livre, o cliente servido leva o prato para viagem (paga igual) ou espera em pé? Recomendação: para viagem.
