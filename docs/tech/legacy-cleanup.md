Status: Rascunho (TASK-563, 2026-10-18; DEC-306, DEC-307). Remoção em andamento (TASK-564/565): ver §5.

# Limpeza dos sistemas antigos

Pedido do dono (DEC-306): antes de qualquer feature nova, tirar o que sobrou de sistemas que o jogo não usa mais.
O jogo hoje é o **restaurante** (`Content.Restaurant.Rules.Enabled = true`). Quase tudo abaixo existe porque o fluxo do
**trailer** continua no código como *rollback* (`Rules.Enabled = false`). Por isso a primeira decisão é a Q-394.

## 1. A decisão que destrava a limpeza

**Q-394 — o modo trailer sai do código?** Se sai, cada linha "só trailer" abaixo vira remoção. Se fica, elas ficam
(só desligadas). Recomendação (Provisória): **sai**. O jogo publicado é antigo, o rollback nunca foi testado depois da
cozinha nova, e manter dois fluxos dobra cada task.

## 2. Corrigido nesta rodada (TASK-562)

| O quê | Causa | Correção |
|---|---|---|
| Persiana, cozinha, luzes e anomalias não achavam o restaurante | O modelo `TRL` virou a pasta `Trailer` (escolha do dono, organização); o código exigia um `Model` | Helper `src/Vehicle/shared/VehicleRoot.luau` (pivô e caixa de um Model **ou** Folder); tag `Vehicle` e atributos na pasta; `restaurant_bind` aceita a pasta e grava o atributo `Pivot` (MapPoint TRL) |
| Não dava para pegar caixa no depósito | `Content.Restaurant.Supply.Enabled = false`: o Mercado saiu do mapa e o depósito nunca foi ligado no lugar | `Supply.Enabled` passa a seguir a chave do restaurante |
| Marcas `Plates/Mark1..8` | modelos novos sem `Persistent` | ajustado no Studio |

## 3. Inventário

Ação: **Remover** (morto no restaurante), **Remover se Q-394 = sai** (só trailer), **Reescrever** (vivo, mas no fluxo
antigo), **Manter**.

| Sistema | Onde | Evidência | Ação |
|---|---|---|---|
| Tutorial do Mercado | `Tutorial/client/TutorialController/Steps.luau` (`money`, `mart_go`, `mart_buy`, `mart_back`, `restock`, `mart`, `upg_go`, `upg_buy`) + falas em `VoiceLines`/`BossCalls` | dono viu o tutorial mandar ao Mercado; o Mercado não existe no restaurante | **Remover** o caminho do Mercado já; o resto do tutorial do restaurante (`r_*`) segue o fluxo da esteira e será **reescrito** depois da TASK-566 |
| Mercado (prateleiras `BUY-*`, `buy_package`) | `Market/server/MarketService.luau`, `Market/client/MarketController`, `Content.Mart`, `ServerStorage.Mart` | `Switch.MartShelves = false` | **Remover se Q-394 = sai** |
| Opal (caixa do Mercado) | `Opal/client/OpalController.luau`, ponto `OP-1`, `CHR-003` | só existe no Mercado | **Remover se Q-394 = sai** |
| Gear Stand (bancada de upgrades B1..B5) | `Market/server/GearStandService.luau`, `MapIndex.KioskNotes` | ainda é exigido no binding; o dono não falou dele | **Confirmar** (Q-395): fica no restaurante ou sai com o Mercado? |
| `LightGroups.mart` (LZ-4, LZ-5) | `Content/LightGroups.luau` | zonas não existem; o código já pula (TASK-562) | **Remover** a linha |
| Entrega por arrastar até a janela do trailer | `Delivery/client/DeliveryController.luau` | o restaurante entrega na retirada (`PU-*`) | **Remover se Q-394 = sai** (conferir na TASK-566 se a cozinha de mundo reaproveita o arrastar) |
| Bandejas e mesas sujas | `Trash/client/TrashController.luau`, `Content.Trash`, `clean_table` | `Switch.DirtyTables = not on` | **Remover se Q-394 = sai** |
| Porta dos fundos do trailer | `Vehicle/server/TrailerDoorService.luau` | `Switch.HasBackDoor = not on`; o restaurante usa `RestaurantDoorService` | **Remover se Q-394 = sai** |
| Esconderijo do trailer (`HideZone`) | `Anomaly/.../Kit/Hide.luau` (servidor e client) | ANM-007/018 cortadas; **ANM-017 usa o teste "Floor"** do mesmo kit | **Manter** o kit; remover só os caminhos de zona do trailer |
| Anomalias cortadas | `Anomalies/ANM-002, 003, 007, 018` (+ `Rules/` e `Effects/`) | `Switch.CutAnomalies` | **Remover se Q-394 = sai** (as cenas do `HorrorScenes` delas também) |
| Preparo focado do trailer | `Prep/` modo `Trailer`, alvos `Trailer/Kitchen/Prep/PT_Hatch` e `PT_Bin`, `Station_1..4` (`PrepStationsV1/V2`) | **`PT_Hatch` = o peitoril da janela do trailer onde o prato era arrastado no estágio Serve do modo focado** (`Prep/client/PrepController/World/Stages/Serve.luau`); no restaurante ninguém usa | **Remover** os alvos do mapa e o modo `Trailer` do `Prep` se Q-394 = sai |
| Minigame da esteira | `Prep/` modo `Conveyor`, `Plate/.../CenterTable`, `PlateService` (CenterSlot), item `plate` | DEC-306 substitui pela cozinha de mundo (Q-390); tem os 3 erros do gate | **Decidir com a Q-390**; se sai, a TASK-566 define o que fica (`Grade`, ticket) |
| Bancada antiga duplicada | `Trailer/Kitchen`: `TLR-BUN_CRATE` e `TLR_BUN_CUT` com o mesmo `MapId=TRL-B`; `TLR-CUTTING_BOARD` com `PendingStationKind=cut` | layout novo do dono | **Reescrever** o binding na TASK-567 |
| Comandos dev antigos | `Dev/server/DevService/Parts` | reescrita já mesclada (`docs/tech/dev-commands.md`) | revisar junto com cada remoção |
| Sons | `Content/Sounds.luau`: `van_arrive` (a van de entrega saiu, FEAT-050), `music_day_*`/`music_night_*` sem referência direta | 9 chaves sem uso fora do arquivo; as músicas podem vir de pool | **Remover** `van_arrive`; conferir as músicas antes |
| Ambiente do Mercado | `Sounds.Rules.AmbientZones` (dentro do Mercado) | Mercado fora | **Remover se Q-394 = sai** |

## 4. Ordem da remoção (TASK-564 servidor, TASK-565 client)

1. Sem esperar decisão: tutorial do Mercado, `LightGroups.mart`, `van_arrive`, alvos `PT_Hatch`/`PT_Bin` e `Station_1..4` só se Q-394 = sai.
2. Com Q-394 = sai: um lote por sistema (Mercado+Opal, Entrega, Trash, Porta, Anomalias cortadas, Prep modo Trailer), gate limpo e boot no Studio a cada lote.
3. Com Q-390: a esteira.

## 5. Andamento (2026-10-19, DEC-307: o trailer sai)

Feito (commits na `feat/anomalies-v2-shop-2026-10-14`, gate sem erro novo e boot limpo no Studio a cada um):

| Commit | O quê |
|---|---|
| `4cb29f00` | Ramos `if Restaurant.Rules.Enabled` colapsados para o restaurante (anomalias, clientes, cozinha, tablet, depósito, HUD, prompts); textos do Mercado/trailer que o jogador via (dica de servir, Gear Stand, nomes de upgrade) |
| `7580325c` | `Restaurant.Rules.Enabled` e o `Switch` derivado saem; Prep, Seating, Vehicles e Supply guardam os valores do restaurante |
| `11d4923f` | Anomalias cortadas ANM-002, 003, 007, 018 removidas (módulos, regras, efeitos, Journal, imagens, cues); catálogo = 17 |
| `5d783d8a` | Porta dos fundos do trailer (`TrailerDoorService`, `trailer_exit/enter`) e o fluxo da cópia batendo nela (ANM-004) |
| `2dfa657d` | `/dev smoke` sem a chave |

Falta (código morto, o jogador não vê):

| Sistema | Por que ainda não | Esforço |
|---|---|---|
| Mesas sujas (`Dirty`, `clean_table`, `TrashController`) e `SitAt = "Order"` | `Dirty` está no tipo de rede e no client de Seating (1356 linhas); remoção pede Play de mesas | médio |
| Mercado (`MarketService` prateleiras, `BUY-*`, Opal no Mercado) | depende da **Q-395** (a Gear Stand e a Opal ficam?) | médio |
| Preparo focado `Mode = "Trailer"` e o minigame da esteira | depende da **Q-390** (a cozinha de mundo da DEC-306 substitui a esteira?) | grande (`Prep` tem ~27 mil linhas) |
| Tutorial: ramo trailer (`DecideLive`), compras no Mercado (`mart_*`, `Trail`) | o tutorial será reescrito na cozinha nova (depois da TASK-566); o ramo não roda no restaurante | médio |
| Item alterado (`Altered`, ANM-002) em Kitchen/Plate/Net | plumbing sem dono; sai junto com a cozinha nova | pequeno |
| Cues `copy_knock/grab/vanish` no client da ANM-004 | sem servidor que mande; sai com a cena da ANM-004 | pequeno |
