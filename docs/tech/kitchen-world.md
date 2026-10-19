Status: Rascunho (TASK-566, 2026-10-19; DEC-306, DEC-308). Contrato da cozinha de mundo. Números Provisórios até o Play do dono.

# Cozinha de mundo — contrato

Fonte: fala do dono (DEC-306) e Q-390 A (DEC-308): **a esteira e o preparo focado saem; o hot dog é montado no mundo**.
Substitui `tech/prep-conveyor.md` e `tech/prep-mode.md` no restaurante, e o §3.3 de `tech/restaurant-flow.md`.
Reaproveita quase tudo do fluxo do trailer que já existe em `KitchenService/Stations` (grelha, descanso, tábua,
condimentos, lixeira) e do restaurante (tablet, ticket, retirada).

## 1. O fluxo em uma tabela

Bancada de trás, oeste → leste, como o dono montou no Studio (2026-10-18):

| # | Lugar (map) | Quem faz | Ação (prompt) | Resultado |
|---|---|---|---|---|
| 1 | Caixa de salsichas `TLR-SAUSAGES` (`sausage_stock`) | fritador | **Grill** (toque) | 1 salsicha crua na vaga livre da grelha |
| 2 | Grelha `TLR-GRILLS` (`grill`) | fritador | **Flip** (toque, opcional: bônus) | pronta em `GrillTime` (8/6/4 s, UPG-001) |
| 3 | Grelha → descanso `TRL-SAUSAGE_RAIL` (`rail`) | fritador | **Collect** (toque na vaga pronta) | salsicha vai para a **pilha do descanso** (FIFO, máx. 8) |
| 4 | Bandeja de pães `TLR-BUN_CRATE` (`bun_crate`) | cortador | **Slice Bun** (segurar 0,8 s) | 1 pão do estoque, cortado, vai para a **pilha de pães cortados** |
| 5 | Pilha de pães cortados `TLR_BUN_CUT` (vagas `Att_Bun1..8`) | — | — | é o `board` de hoje com as vagas na bandeja da direita |
| 6 | Pilha de pratos (marcas `Plates/Mark1..8` da bancada da frente) | montador | **Take Plate** (toque, mão livre) | Tool `plate` vazio, preso ao **ticket mais antigo sem prato** (HUD do ticket, DEC-304) |
| 7 | Pilha de pães cortados | montador | **Add Bun** (toque, prato na mão) | o pão mais antigo vai para o prato |
| 8 | Descanso | montador | **Add Sausage** (toque, prato na mão) | a salsicha mais antiga vai para o prato |
| 9 | Mesa de condimentos `PRODUCTION` (`Pan_*`) | condimentos | **Add {topping}** (segurar 0,5 s) | só as panelas do pedido do ticket acendem |
| 10 | Retirada `PICKUP` / cliente | servidor | **Hand Over** (ou arrastar, `DeliveryController`) | venda; nota (§4) |

Ordem livre entre 7 e 8. Um jogador sozinho faz tudo; com 4, os papéis da DEC-306 aparecem naturalmente.
Lixeira `TRL-BIN` (**Throw Away**, segurar 0,5 s): joga fora o prato na mão (erro de condimento).

## 2. Estado (servidor manda)

| Coisa | Onde vive | Registro de rede |
|---|---|---|
| Vagas da grelha | `Stations/Grill.luau` (igual hoje) | `Stations` (uma por vaga) |
| Pilha do descanso | `Stations/Rail.luau` (igual hoje; capacidade `Vehicles.trailer.RailSlots` = 8) | `Stations` (Slot 0, Count) |
| Pilha de pães cortados | `Stations/Board.luau`: as vagas `Att_Bun1..n` passam para o modelo `TLR_BUN_CUT`; `BoardSlots` = 8 | `Stations` (uma por vaga) |
| Prato na mão | **Tool `plate`** (ITM-025) com atributos `Ticket`, `Bun`, `Sausage`, `Toppings` (bitfield), `Since` | `Restaurant.Plates` (um registro por prato vivo: `Npc` = ticket, `Bun`, `Sausage`, `Toppings`, `Since`; sai `Line`, `Orphan`, `Grade`) |
| Estoque | `Stock` (igual hoje), reposto com caixas do depósito (`take_box` → **Restock** na estação) | `Stock` |

Regras:
- **Um prato por mão** (Provisório; DEC-299 dizia até 2 — fica 1 para não confundir o ticket na HUD).
- `Take Plate` sem ticket livre: prato **sem ticket** (montagem antecipada); ganha o ticket mais antigo no **Hand Over**.
- `Add Bun` / `Add Sausage` recusam com toast quando o prato já tem a peça, ou a pilha está vazia (`pile_empty`).
- `Add {topping}` só com pão **e** salsicha no prato; máximo `OrderRules.MaxToppings`; repetido recusa (`topping_repeat`).
- A salsicha pronta **espera na grelha** se o descanso estiver cheio (Collect recusa `rail_full`, igual hoje).
- Nada queima (DEC-298).

## 3. Ações (Content.Actions)

| Key | Texto | Hold | Requer | Dono |
|---|---|---|---|---|
| `grill_place` | Grill | 0 | estoque, vaga livre | KitchenService (Grill) — **igual** |
| `grill_flip` | Flip | 0 | vaga esperando virar | KitchenService (Grill) — **igual** |
| `grill_collect` | Collect | 0 | vaga pronta, descanso com espaço | KitchenService (Grill) — **igual** |
| `bun_cut` | Slice Bun | 0,8 | estoque, vaga livre na pilha | KitchenService (BunCrate) — **igual, sem o bloqueio da esteira** |
| `plate_take` | Take Plate | 0 | mão livre | **PlateService** — muda: dá o Tool `plate` (não mais da mesa central) |
| `plate_add_bun` | Add Bun | 0 | `plate` na mão, pilha de pães ≥ 1 | **novo**, KitchenService (Board) |
| `plate_add_sausage` | Add Sausage | 0 | `plate` na mão, descanso ≥ 1 | **novo**, KitchenService (Rail) — substitui `rail_take` e `board_add_sausage` |
| `topping_add` | Add {item} | 0,5 | `plate` com pão e salsicha | KitchenService (Toppings) — muda `Requires.Held` de `hot_dog` para `plate`; hold 1 → 0,5 (DEC-299) |
| `discard` | Throw Away | 0,5 | `plate` na mão | KitchenService (Trash) — aceita `plate` |
| `pickup_serve` | Hand Over | 0 | `plate` completo | CustomerService (Pickup) — igual, lê o prato |

Saem: `bun_slice` (CUT-n), `rail_take`, `board_add_sausage`, `plate_put`, `CenterPut`, `prep_work`, `prep_grill`.

## 4. Nota (Grade) sem minigame

`Prep/shared/Grade.luau` fica com uma função nova `Grade.Assembly(order, plate, seconds)`:

| Banda | Regra (Provisória) |
|---|---|
| **Perfect** | condimentos exatamente os do pedido e `seconds ≤ PerfectTime` (desde o ticket; 45 s solo, −5 s por jogador extra) |
| **Good** | condimentos exatamente os do pedido |
| **Messy** | faltou ou sobrou condimento (o cliente aceita, sem gorjeta) |

Gorjeta: `Grade.SaleEffect` como hoje (Perfect = base + $1, DEC-305). As funções de gesto (`Score`, `CoverageError`,
`Plausible`, `FlipScore`) saem com o `Prep`; o bônus de virar (DEC-298) vira +1 ponto na banda (Good → Perfect) quando
a salsicha foi virada no ponto.

## 5. Mapa (binding, TASK-567)

| Peça | Hoje no Studio | Precisa |
|---|---|---|
| `TLR-BUN_CRATE` | `StationKind=bun_crate`, `MapId=TRL-B` | `MapId=TRL-BC` (único) |
| `TLR_BUN_CUT` | `StationKind=bun_crate`, `MapId=TRL-B` (duplicado) | `StationKind=board`, `MapId=TRL-T`, 8 attachments `Att_Bun1..8` em cima da bandeja, `Prompt_Board` (Add Bun) |
| `TLR-CUTTING_BOARD` | `StationKind=board`, `PendingStationKind=cut` | cenário da tábua (sem `StationKind`) ou âncora do Slice Bun |
| `TRL-SAUSAGE_RAIL` | `rail` | + `Prompt_Rail` (Add Sausage) |
| `Plates/Mark1..8` | marcas de fila (`AST-019`) | `Prompt_Plate` (Take Plate) num só ponto da pilha de pratos; as marcas viram cenário |
| `PRODUCTION/Pan_*` | atributo `Topping` | tag `Station`, `StationKind=toppings`, `Prompt_Use_<Suf>` (como o `K` do trailer) |
| `Prep/PT_Hatch`, `PT_Bin`, `Station_1..4` | alvos do preparo focado | **saem** |

## 6. O que sai do código (TASK-581)

`src/Prep/**` inteiro menos `Prep/shared/Grade.luau` (que encolhe, §4); `Content.Prep` vira só o que o `Grade` lê;
`PlateService` perde a mesa central (`CenterTable`, `CenterPut`, `SilencePass`); `PlateController` perde a mesa central e a
esteira; `Kitchen/client/Slots` perde o modo esteira; `Content.Restaurant.CenterTable` e `Binding.Center*` saem. Os 3
erros de tipo do gate (`Prep/Bridge`, `Plate/CenterTable`) saem junto.

## 7. Critérios de aceite (TASK-572)

- Solo: um pedido com 2 condimentos sai em **≤ 8 prompts** e **≤ 25 s** de cozinha, com a pilha já cheia.
- 2 jogadores (fritador + montador): ninguém espera o outro mais de 5 s com as pilhas cheias.
- Nenhum prompt da esteira ou do preparo focado aparece; nenhuma tela focada abre.
- A HUD do ticket mostra o pedido do prato na mão; as panelas certas acendem.
- Repor do depósito: caixa de salsicha → Restock na caixa de salsichas; idem pães e cada condimento.
