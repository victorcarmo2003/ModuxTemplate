Status: Rascunho

# Contratos de rede (Lync)

Autor: architect. **Versão 5, 2026-10-10 (pós onda 1):** §13 novo — entradas das ondas 2–4 com schema, quem escreve,
quem lê, frequência e por quê; remoção do legado `Vitals`/`Round`; `Lights`, `Call`, `Thief`, `Hides`,
`Anomalies`, `Pedestrians`, `Transition`, `RunReport` novos (contrato de código em `architecture.md` §19).
**Versão 5.1, 2026-10-10 (TASK-049):** divergências da onda 1 fechadas (`wave-1-report.md` D-06, D-07); origem de
`RunReport.Gems` (T59); lixeira de rua sem entrada nova (T60). Ver §0.-2.
**Versão 5.3, 2026-10-11 (TASK-144; FEAT-037, FEAT-038):** set `Tables` novo; `Customers` ganha `Order2` e `Leader`
(opcionais, duplas); `Actions` + `buy_in_place`, `clean_table`; `Notices` + `table_added`; atributo `Seated` no rig (§14).
**Versão 5.4, 2026-10-11 (TASK-160 a TASK-162; pedido do usuário, Provisório):** loja, classe por Robux e códigos
(§15): packets `ClassBuy`/`ClassBuyResult` e `CodeRedeem`/`CodeRedeemResult`. **Sem set `Wallet`**: saldo e classes
possuídas já viajam no packet privado `Profile` (§4.5). Robux: o client chama `PromptProductPurchase`; o servidor só
processa recibo (`ShopService`).
**Versão 5.6, 2026-10-11 (pedido do usuário, Provisório):** plataformas de squad (§16.6): set `Party` ganha
`Platform`, `FriendsOnly`, `MaxPlayers`, `StartAt` e o estado `Configuring`; packet novo `PartyConfigure`; avisos
`FriendsOnly`, `Configured`; `PartyStart` passa a ter contagem de 5 s.
**Versão 5.8, 2026-10-12 (pedido do usuário, Provisório; Q-217):** cancelar a contagem do Start (§16.8): packet novo
`PartyCancel` (c → s, vazio); avisos `StartCancelled`, `CancelTooLate`. Sala em dois estágios (§16.9): o set `Party`
troca `FriendsOnly` por `Access`; `PartyConfigure` troca `FriendsOnly` por `Access`; avisos `SetupFirst`, `RoomClosed`,
`InviteOnly`; plataformas sem capacidade fixa.
**Versão 5.7, 2026-10-11 (pedido do usuário, Provisório):** botão Play do lobby com escolha (§16.7): packet novo
`PartyQuickPlay { Mode = "Solo" | "Squad" }`; squad "Solo" de 1 começa já e some ao voltar ao estado ocioso.
**Versão 5.9, 2026-10-18 (TASK-512; DEC-302, DEC-303, DEC-304; Provisório):** cozinha com esteira (§19): packets novos
`PrepBelt` e `PrepStage` (namespace "game"), `CenterPut` (namespace "restaurant"); set `PrepSeats` ganha `Stop`, `Wait`,
`Line`, `Away` (prato parado na esteira; emenda do dono: dois prompts, ação nova `prep_grill`); set `Plates` ganha `Grade` e passa a ser a mesa central (vagas 1..8). Contrato completo em `prep-conveyor.md`.
**Versão 5.2, 2026-10-10 (DEC-221):** set `Hides` sai; janela do trailer = atributo `Shutter` no `Model` do veículo
(§13.6, T61); `Actions` perde `hide`/`get_up` e ganha `shutter_toggle`; `Notices` troca `hide_taken` por `shutter_closed`.
Versão 4, 2026-10-10 (**TASK-001**: estado DEC-140 a DEC-201, núcleo da onda 1). Versão anterior: 3.1, 2026-10-08.
Tudo aqui vira entrada em `src/Libs/Net/init.luau` (um `Lync.define("game", {...})`, requerido pelos dois lados).
Mudança neste arquivo passa pelo architect (`PIPELINE.md`, ponto de conflito). Arquitetura: `architecture.md`.
Tabelas que geram os enums: `content-data.md`. Dados persistidos: `data.md`.

> **Base Provisória (DEC-193).** Este documento é Rascunho e vale como base Provisória para construir. Itens sem DEC
> estão marcados **Provisório**; técnicas T# seguem Provisórias até a `Q-130`. Lib conferida: **Lync 4.0.2**
> (`Packages/_Index/axp3cter_lync@4.0.2`).

---

## 0. O que mudou

### 0.-2 Versão 5.1 (TASK-049; só documento, `init.luau` não muda)

| Ponto | Antes | Agora | Onde |
|---|---|---|---|
| D-06 | §11 item 3: `pick_up_item` "sem prompt ativo" na onda 1 | ativo desde a TASK-046 com prompt **"Take"** (toque, raio 7), só no pacote grátis (como o §7 e o código já diziam); `bench_buy_item` segue sem prompt até a onda 4 | §11 |
| D-07 | §3.7: `UpgradeController` lê `Upgrades` | **não existe**; único leitor é o `MarketController`. A peça visível é do servidor (`UpgradeService/Pieces.luau`, visibilidade, T38) e replica como instância | §3.7, §7 |
| `RunReport.Gems` | sem origem definida | passo do `RewardService` registrado em `RoundService:AddRunReportStep` (T59, `architecture.md` §19.11); valor = `RunRewards.Gems` do perfil (`data.md` §1.3). Schema igual | §13.0, §13.1 |
| Lixeira de rua (DEC-200) | — | **sem entrada nova**: `Interact` com `Action = discard` numa âncora `StreetBin`; dono `KitchenService` (T60, `architecture.md` §19.5) | §13.0 |

### 0.-1 Versão 5 (pós onda 1; contratos das ondas 2–4)

| Entrada | Mudança | Onda | Origem |
|---|---|---|---|
| `Vitals` | o nome fica; schema troca pelo da §6.1 (sem `Sanity`; número vai pelo packet `Sanity`) | 2 | DEC-167; T5 |
| `Round` (packet legado) | **removido** | 2 | §4.7 |
| `Sanity`, `LifeEvent` | packets da §6 entram | 2 | DEC-167, DEC-091 |
| `Switches` (v3) | vira **`Lights`** (um registro por grupo de luz, dono `LightService`) | 2 | `architecture.md` §19.6, T45 |
| `BossCall` (packet, v3) | vira **set `Call`** (reconexão no meio da ligação ouve o resto) | 2 | FEAT-018, T44 |
| `Thief`, `Transition`, `RunReport` | novos | 2 | FEAT-013, 016, 026, 027; T58 |
| `Anomalies` (set), `AnomalyCue`, `Gaze`, ~~`Hides`~~ | `Anomalies` novo; `AnomalyCue`/`Gaze` da §6 com schema final; `Hides` **sai** (v5.2, DEC-221: atributo `Shutter`, §13.6) | 3 | DEC-204; T53, T61 |
| `Stations` | + `Altered` (ITM-020) | 3 | §3.5 "Onda 3" |
| `Cutscene`, `SkipVote`, `Traffic`, `CarHit` | como §6.2 | 3 | DEC-133, DEC-194 |
| `Pedestrians` | novo (passantes como ator de client, aparência no set) | 3 | DEC-183, T46 |
| `Parties`, `PartyAction`, `Reconnect`, `ReconnectReply`, `Ambulance`, `Revive`, `Bench` | schema final | 4 | DEC-179, §5, §6 |
| `Profile` | + `ReviveCredits` | 4 | DEC-117 |
| `Interact`, `Notice` | enums crescem com `Content.Actions`/`Notices` (chaves novas na §13.10) | 2–4 | — |

### 0.0 Versão 4 (TASK-001; DEC-140 a DEC-201)

| Entrada | Mudança | Origem |
|---|---|---|
| Regra 3 (enum) | **corrigida**: o Lync 4.0.2 **ordena** os nomes de `enum`/`bitfield` antes de numerar; o índice no fio é a posição na lista ordenada, não a ordem da tabela. O código vê **strings** (`enum`) e `{ [string]: boolean }` (`bitfield`). Nada muda para persistência (já era por chave) | código do Lync (`codec/Composites.luau`, `sortedNames`) |
| `Stations` | um registro **por vaga** (grelha, **tábua**) ou por estação de estado único (trilho); id = `StationId × 100 + Slot` (binding T33/§18 da TASK-002). Tábua de **2 vagas compartilhadas** = 2 registros `Kind = board` (decisão desta versão, §3.5). Saem `Contents` (montagem não acontece mais na tábua) e o estado `Blocked` | **DEC-190**, DEC-201 |
| `Stock` | + `Blocked` (ingrediente não liberado): fonte única da tampa + cadeado da tigela, do "Out of stock" do Mart e do sorteio de pedido | **DEC-156**, DEC-180, DEC-071 |
| `Customers` | sai `Look` (índice opaco). Aparência de **todo** NPC (cliente, passante, ladrão) vai em **atributos do modelo** (§5); o set fica só com estado de jogo. `Mood` vira enum da tabela `Moods` (**Provisório**, humor simplificado da onda 1, `Q-164`) | DEC-181, **DEC-188**, DEC-183, DEC-187 |
| `Upgrades` | o set mostra os níveis do **veículo atual**; o servidor guarda nível **por veículo** e reescreve o set na troca | **DEC-184** |
| `Shift` | sem mudança de schema; onda 1 só escreve os campos de dia (§3.1) | DEC-048, DEC-193 |
| `ShiftReport` | campos renomeados para o resumo de FEAT-014 (`Arrived`, `Completed`, `Drawer`, `Deposited`); `Grade` perde `"None"` (sem cliente = C); + `LastChanceUsed` | DEC-051, FEAT-014, DEC-110 |
| `Profile` | chaves de classe por **animal** (`class_dog`…); onda 1 manda só `Gems`, `Classes`, `Selected` | **DEC-186**, DEC-147 |
| `ClassAction` | válido também no Run em **modo dev** (sem lobby na onda 1) | DEC-186, TASK-017 |
| `Interact` | chaves de ação da linha nova: `topping_add` (no lugar de `board_add_topping`), `board_pickup` sai (o HotDog vai direto para a mão), `party_join` sai (plataforma física) | DEC-190, DEC-179 |
| `Vitals` (onda 2) | proposta: `Sanity` deixa de ir a todos; vai só ao dono (packet `Sanity`). A party vê a **faixa** pela aparência (`LookPack` no personagem), nunca o número | **DEC-167, DEC-169** |
| `Round`, `Vitals` antigos | **ficam** no `init.luau` na onda 1, sem uso novo; removidos na onda 2 junto com `VitalService`/`RoundController` novos | TASK-004 |
| Aparência de personagem | **sem rede própria**: geometria pelo servidor, textura e rosto pelo client a partir de atributos (T40, **Aprovada** pelo architect por delegação da DEC-208, §5; segue a DEC-167/169 "troca no client" e diverge da T35 do `architecture.md` §18.9.4, ver §11) | DEC-148, 150, 152, 161, 166–169, 181 |
| `keyBy` | nenhuma entrada usa (T14) | T14 |

### 0.1 Versão 3.1 (DEC-130, rodada 17)

| Entrada | Mudança | Origem |
|---|---|---|
| `Traffic` | `Route` cobre `TR-1..TR-10`; **DEC-133**: `StartedAt` sai; entram `AnchorAt`, `AnchorDist`, `StopDist`, `HeldUntil` | `MAP-01.md` revisão 3, DEC-133 |
| Semáforo | **removido** (sem rede; sai `Workspace.RunEpoch`) | DEC-130 |
| Reserva de faixa | sem rede: `NpcService` → `TrafficService` no servidor | DEC-133 |

### 0.2 Versões 3 e 2 (resumo)

| Entrada | Mudança | Origem |
|---|---|---|
| `Shift` | `WipeEndsAt`, `WipeFrozen`, `Attempt`, fase `Resume`; `Chances` começa em 1 | DEC-080, 094, 102, 110, 118 |
| `Vitals` | `State` com `Down`/`Reviving`/`Spectator`/`Away`; `StateEndsAt` (6:00 AM), `KnockedUntil` | DEC-091, 093, 095, 115 |
| `RunState` | novo; `PriceParty` fixado no fim do Day 1 | DEC-098, DEC-121 |
| `Bench`, `Traffic`, `Ambulance`, `Cutscene` | novos sets | DEC-087, 091, 100, 106, 114, 129 |
| `CarHit`, `Revive`, `SkipVote` | novos packets c → s; `KnockOut` vira `LifeEvent` | DEC-078, 092, 095, 116 |
| `Reconnect`, `ShiftReport`, `Interact` | `Mode`/`Seconds`; `Gems` creditadas por evento, `AfkLocked`; `pick_up_item` | DEC-080, 083, 104, FEAT-036 |

## 1. Regras

1. **Set** (`Lync.replicate`) para estado que a party vê e que quem chega/reconecta precisa receber pronto.
   **Packet** para evento ou dado privado.
2. **Sem `keyBy`** (T14). O servidor da run tem uma party só; no lobby o único set (`Parties`) é público.
3. **Enums e bitfields gerados das tabelas de conteúdo** (`Lync.enum(Content.X.Keys)`, T13). O Lync **ordena** os
   nomes; o índice no fio é a posição ordenada, igual nos dois lados porque os dois requerem o mesmo `Content`. O
   código lê e escreve **strings**. Nada persistido usa índice: perfil, MemoryStore e snapshot guardam a chave.
   Acrescentar ou renomear chave muda o fio → servidor e client da mesma versão (publicação normal já garante).
4. **Tempo em tempo de servidor.** Campos `*At` são `f64` de `workspace:GetServerTimeNow()`; o client interpola.
   Exceção: `Reconnect.Seconds` (o lobby não compartilha relógio com a run).
5. **IDs de registro e de alvo** (alinhados ao binding da TASK-002, `architecture.md` §18.2–§18.3, T33):

   | Id | Quem aloca | Usado em |
   |---|---|---|
   | `UserId` | Roblox | `Vitals`, `Ambulance.Riders` |
   | `EntityId` (1–65535, runtime) | `InteractionService` para **toda** âncora `Interactable` (do mapa e de runtime); id liberado só volta ao uso 10 s depois | `Interact.Id` (alvo do prompt) |
   | `StationId` (runtime, ≤ 99 por place) | `KitchenService`, atributo no `Model` da estação | id de registro de `Stations` = `StationId × 100 + Slot` (`Slot = 0` para estação de registro único) |
   | `NpcId` (1–65535, runtime) | `NpcService`, atributo no rig, **novo a cada spawn** (contador cíclico; rig do pool reaproveitado ganha id novo) | id de registro de `Customers`; `Sale.Npc` |
   | `IndexOf` da tabela (posição na **lista**, não no enum ordenado) | `Content` | `Stock`, `Upgrades` |
   | slot | dono | `Traffic` (1–8), `Bench` (S1 = 1) |
   | `1` | — | registro único (`Shift`, `RunState`, `Economy`, `Ambulance`, `Cutscene`) |

   Snapshot nunca guarda `EntityId`, `StationId` nem `NpcId` (nascem a cada servidor): guarda chaves estáveis.

6. **Packets s → c vão para `NetService.Audience`** (ou `fireClient` a um jogador do grupo), nunca `Lync.all`, e só
   com `NetService:IsRunning()`.
7. **Responder só em Service/Controller, no `OnInit`.** Componente não registra responder.
8. **Todo packet c → s é validado**: membro no estado certo, taxa máxima, alvo existe, distância/plausibilidade.
9. **Aparência de personagem não passa pelo Lync** (§5): é atributo no modelo, escrito pelo servidor, aplicado pelo
   client. Estado de jogo nunca vai em atributo de modelo (vai em set). **Exceções declaradas:** `Bought` (TASK-056) e
   `Shutter` (§13.6, T61, DEC-221) — estado de objeto do mundo, 1 bool, um escritor.

## 2. Entradas por onda

| Entrada | Tipo | Onda | Estado nesta versão |
|---|---|---|---|
| `Ready` | packet c → s | existe | sem mudança |
| `Profile` | packet s → c | **1** | schema novo (§4.5) |
| `Shift` | set | **1** | §3.1 |
| `RunState` | set | **1** | §3.2 |
| `Economy` | set | **1** | §3.3 |
| `Stock` | set | **1** | §3.4 |
| `Stations` | set | **1** | §3.5 |
| `Customers` | set | **1** | §3.6 |
| `Upgrades` | set | **1** | §3.7 |
| `Interact` | packet c → s | **1** | §4.1 |
| `Notice` | packet s → c/grupo | **1** | §4.2 |
| `Sale` | packet s → grupo | **1** | §4.3 |
| `CustomerComplain` | packet s → grupo | **1** | §4.3a |
| `ShiftReport` | packet s → grupo | **1** | §4.4 |
| `ClassAction` | packet c → s | **1** | §4.6 |
| `Round` (packet antigo) | packet | legado | **mantido** na onda 1, sem uso novo; removido na onda 2 |
| `Vitals` (Health/Armor/Stamina) | set | legado | **mantido** na onda 1 (o `VitalService` de exemplo compila); trocado pelo schema da §6.1 na onda 2 |
| `Sanity`, `Switches`, `Bench`, `Traffic`, `Ambulance`, `Cutscene`, `Parties`, `Gaze`, `CarHit`, `Revive`, `SkipVote`, `BossCall`, `AnomalyCue`, `LifeEvent`, `PartyAction`, `Reconnect`, `ReconnectReply` | — | 2–4 | §6; **não entram** no `init.luau` da onda 1. **v5: lista final por onda na §13.0** (`Switches` → `Lights`, `BossCall` → set `Call`) |

Por que não declarar já tudo: cada entrada nova arrasta enums de tabelas que a onda 1 ainda não tem (`Anomalies`,
`BossCalls`, `Cutscenes`, `BenchItems`); stub de tabela só para o Lync subir é dado falso. Acrescentar entrada depois
não quebra as existentes (o `define` é por nome).

## 3. Sets — place Run, onda 1

### 3.1 `Shift` (registro único, id `1`)

```lua
Shift = Lync.replicate(Lync.struct({
	Day = Lync.int(1, 10000),
	Night = Lync.int(0, 10),
	IsNight = Lync.bool(),
	Attempt = Lync.int(0, 9),                   -- tentativas da noite atual (0 = primeira)
	Phase = Lync.enum(Content.Shift.PhaseKeys), -- Resume, Prep, Open, Closing, Summary, Call, Night, NightEnd, NightLost, Finale, RunEnd
	PhaseStartedAt = Lync.f64(),
	PhaseDuration = Lync.int(0, 3600),          -- teto da fase; Closing termina antes se o balcão esvaziar
	ClockFrom = Lync.int(0, 2880),              -- minutos de jogo
	ClockTo = Lync.int(0, 2880),
	Vehicle = Lync.enum(Content.Vehicles.Keys),
	Chances = Lync.int(0, 9),                   -- 1 por run (DEC-110, DEC-112); não vai ao HUD (DEC-053)
	WipeEndsAt = Lync.f64(),                    -- 0 = sem janela de 10 s (DEC-094)
	WipeFrozen = Lync.bool(),                   -- DEC-118
}))
```

| | |
|---|---|
| Escreve | `RoundService` (único dono; `WipeEndsAt`/`WipeFrozen` vêm do `VitalService` pela API do `RoundService`, onda 2) |
| Lê | `RoundController` → sources `Day`, `Phase`, `ClockText`, `IsNight` (os outros Controllers leem esses sources, não o set); `HudController`; placa OPEN/CLOSED. "Out of stock" e cadeado **não** derivam do `Day` no client: leem `Stock.Blocked` |
| Frequência | por troca de fase (4 por dia de jogo) |
| Por que set | todos veem; quem reconecta precisa da fase atual (TASK-015) |
| Onda 1 | escreve `Day`, `Phase` (Prep, Open, Closing, Summary), `PhaseStartedAt`, `PhaseDuration`, `ClockFrom/To`, `Vehicle = "cart"`. Fixos: `Night = 0`, `IsNight = false`, `Attempt = 0`, `Chances = 1`, `WipeEndsAt = 0`, `WipeFrozen = false`. Placa OPEN/CLOSED é **derivada** de `Phase` (Prep: CLOSED com prompt "Open Shop"; Open: OPEN; Closing/Summary: CLOSED), sem campo |
| Relógio | `ClockText` = `ClockFrom + (ClockTo − ClockFrom) × (now − PhaseStartedAt) / PhaseDuration`, arredondado para baixo a 10 min (DEC-048). Na Prep, `PhaseDuration` = 60 mesmo que "Open Shop" abra antes: o servidor troca a fase e o relógio pula para 8:00 |

**Novo fluxo da run (pedido do dono 2026-10-12, Provisório, Q-207): sem mudança de schema.** A sequência passa a ser D1, D2, N1, D3, N2 … D11, N10
(a noite *k* tem `Day = k + 1`); `Night` (0..10), `IsNight`, `Vehicle` (`cart` ou `trailer`: as noites começam no carrinho) e `Day` já comportam isso.
`PhaseDuration` da fase `Night` passa a ser 540..900 s (cabe em `int(0, 3600)`). `Endless` fica sempre `false`. O set tem **1** registro,
então nenhum campo precisa ser de 8 bits; os campos novos de sets com ≥ 8 registros (p. ex. `Upgrades.Wait`) seguem a regra do `Level`.
Nenhum pacote novo.

### 3.2 `RunState` (registro único, id `1`)

```lua
RunState = Lync.replicate(Lync.struct({
	PriceParty = Lync.int(0, 4),  -- 0 até o fim do Day 1; depois fixo (DEC-121). Multiplica trailer e Revive Kit
	RosterSize = Lync.int(1, 4),
	Endless = Lync.bool(),        -- modo dia infinito (DEC-084). SEMPRE false desde 2026-10-12 (Q-207): o campo fica por compatibilidade
}))
```

| | |
|---|---|
| Escreve | `RunStateService` |
| Lê | `HudController`; `MarketController` (onda 2+: preço do Revive Kit); prompt do trailer (onda 2) |
| Frequência | entrada/saída de membro; 1 vez no fim do Day 1 |
| Onda 1 | modo dev (sem `PrivateServerId`): `RosterSize` = quem entrou; `PriceParty` fixa no fim do Day 1 normalmente; `Endless = false` |

### 3.3 `Economy` (registro único, id `1`) — sem mudança

`{ Cash = Lync.int(0, 2147483647), Drawer = Lync.int(0, 1000000) }`.

| | |
|---|---|
| Escreve | `EconomyService` (dono único de `Cash` e `Drawer`; outros chamam `Spend(amount): boolean`, `AddToDrawer`) |
| Lê | `EconomyController` → sources `Cash`, `Drawer`; BillboardGui da gaveta (igual para todos, FEAT-012) |
| Frequência | por venda, compra, depósito (~0,2–1/s em pico) |

### 3.4 `Stock` (id = `Content.Ingredients.IndexOf[key]`)

```lua
Stock = Lync.replicate(Lync.struct({
	Amount = Lync.int(0, 999),
	Capacity = Lync.int(0, 999),  -- Ingredients[k].Capacity[nível do Cooler do veículo atual] (DEC-184)
	Blocked = Lync.bool(),        -- ingrediente ainda não liberado (Shift.Day < UnlockDay; Coffee: sem trailer)
}))
```

| | |
|---|---|
| Escreve | `KitchenService` (dono do estoque). `Blocked` recalculado no `ShiftStarted`; `Capacity` na compra de Cooler e na troca de veículo |
| Lê | `KitchenController` (contador "7/12", vermelho com ≤ 2; `Fill` das garrafas e tigelas, DEC-140; **tampa + cadeado** quando `Blocked`, DEC-156); `MarketController` ("Out of stock" quando `Blocked`, DEC-180); `PromptController` (previsão de apresentação: esconde "Add X" com `Amount = 0` ou `Blocked`; esconde "Restock" com `Amount = Capacity` ou `Blocked`, nunca com `Amount = 0`: estoque vazio é justamente quando se repõe; L-02 do QA, TASK-040) |
| Frequência | por consumo/restock (≤ 2/s em pico de party de 4) |
| Registros | um por ingrediente, **sempre os 9**: `coffee` existe desde o Day 1 com `Blocked = true` e `Amount = 0` até a compra do trailer (o Mart mostra a prateleira de café pelo mesmo `Blocked`; a cafeteira começa com 10 doses, UPG-007, onda 2) |
| Por que `Blocked` aqui e não em `Stations` | o bloqueio é do **ingrediente no dia**, não da estação: a mesma flag fecha a tigela, mostra "Out of stock" no Mart e tira o ingrediente do sorteio de pedido. Um registro por ingrediente = um dono, uma escrita. Na tarefa e no MAP-01, "tigela `Blocked`" (DEC-156) **é** `Stock[ing].Blocked == true` |

### 3.5 `Stations` (id = `StationId × 100 + Slot`)

```lua
Stations = Lync.replicate(Lync.struct({
	Kind = Lync.enum(Content.Stations.RecordKeys), -- grill, rail, board (onda 1); coffee_machine (onda 2)
	State = Lync.enum({ "Empty", "Working", "Ready" }),
	StartedAt = Lync.f64(),                        -- início do trabalho (grelhar, cortar); 0 = parado
	Duration = Lync.quant(0, 120, 0.1),            -- duração real (já com nível e classe)
	Count = Lync.int(0, 30),                       -- rail: salsichas no trilho; demais: 0
}))
```

| Kind | Registros (carrinho) | `State` | Notas |
|---|---|---|---|
| `grill` | 1 por vaga (`Slot` 1..4): 2 / 3 / 4 pelo nível do Grill (UPG-001, DEC-201: 1 salsicha por par de rolos) | Empty → Working (`StartedAt`, `Duration` = 12/10/8 s × 0,85 se quem colocou é o Gato, CLS-003) → Ready (salsicha pronta parada na vaga, sem queimar) | vaga nova do upgrade entra com `add` vazia; as em andamento não reiniciam (UPG-001) |
| `rail` | 1 (`Slot = 0`) | Empty / Ready (com ≥ 1) | `Count` = salsichas (FIFO no servidor). Capacidade = `Vehicles[v].RailSlots` (6 carrinho) |
| `board` | **2** (`Slot` 1..2, DEC-190); trailer **3** (`Slot` 1..3, DEC-215; onda 2) | Empty → Working (corte 1,5 s após "Slice Bun") → Ready (pão cortado esperando salsicha) | ver decisão abaixo |

**Decisão (DEC-190 pediu "2 registros ou slot no registro"): 2 registros `board`, prompt único na tábua.**

| | |
|---|---|
| Estado | cada vaga é um registro próprio (`StationId × 100 + Slot`; `Att_Bun1`/`Att_Bun2` com `Slot` 1..2 no binding, `architecture.md` §18.4; no trailer, 3 registros `board`, `Att_Bun1..3`, `Slot` 1..3, `Vehicles.trailer.BoardSlots = 3`, DEC-215). O visual do pão por vaga (inteiro → cortado) e a barra de corte saem direto do registro, igual à grelha |
| Interação | o **prompt fica na tábua** (uma âncora `Prompt_Board` → `board_add_sausage`), não em cada vaga: as duas vagas ficam a < 2,5 studs (MAP-01 §7: prompts vizinhos ≥ 2,5). "Slice Bun" (na caixa de pão) ocupa a vaga livre de menor `Slot`; "Add Sausage" (na tábua) usa a vaga `Ready` mais antiga e o 1º do trilho |
| Concorrência | as duas ações passam pelo `InteractionService`, que serializa por alvo no mesmo frame (TASK-011): dois toques simultâneos → o 1º leva o HotDog, o 2º encontra a vaga já `Empty` (ou a outra `Ready`). Atende "só um recebe" (FEAT-006) |
| Descartada | 1 registro com `Slots = array(...)` ou bits por vaga: obriga o client a diferenciar o array a cada mudança e foge do padrão "registro = coisa com barra" da grelha |

| | |
|---|---|
| Escreve | `KitchenService` (estações em `KitchenService/Stations/*.luau`, interface da TASK-002) |
| Lê | `KitchenController` (salsicha por vaga, `ProgressBar` por `StartedAt/Duration`, salsichas no trilho, pão nas vagas); `PromptController` (prompt "Collect" só em `Ready`, previsão) |
| Frequência | ~1/s em pico (cada salsicha: 2 escritas na grelha + 1 no trilho; cada hot dog: 2 na tábua + 1 no trilho) |
| Por que set | todos veem as mesmas vagas; quem reconecta vê o estado atual (TASK-030) |
| Fora do set | caixa de salsicha, caixa de pão, complementos (estado = `Stock`), lixeira, entrega/POS (estado = `Economy.Drawer`), placa (estado = `Shift.Phase`) |
| Onda 3 | ITM-020 (item alterado no trilho/tábua) acrescenta campo `Altered` (`bool` na vaga; posição no trilho) — mudança de schema registrada quando a onda abrir |

### 3.6 `Customers` (id = `NpcId`)

```lua
Customers = Lync.replicate(Lync.struct({
	State = Lync.enum({ "Arriving", "Queued", "Ordering", "Waiting", "Leaving" }),
	Slot = Lync.int(0, 8),                               -- 0 = fora da fila; 1..5 = Q1..Q5 (Counter 3/4/5)
	Order = Lync.bitfield(Content.Ingredients.ToppingKeys), -- vazio até "Take Order"; nunca o K antes disso (FEAT-011)
	PatienceEndsAt = Lync.f64(),                         -- prazo da fase de paciência em curso (hora do servidor); 0 = sem relógio (Q-192)
	Phase = Lync.enum({ "None", "Queue", "Order" }),     -- Q-192 (Provisório): Queue = Q1 até "Take Order"; Order = "Take Order" até servir; None = sem relógio
	PatienceSpan = Lync.int(0, 255),                     -- Q-192: duração da fase em s inteiros (a barra é (PatienceEndsAt - agora) / PatienceSpan); 8 bits de propósito (set com 8+ registros)
	Mood = Lync.enum(Content.Moods.Keys),                -- Provisório (Q-164): Neutral, Happy, Annoyed, Complaining
}))
```

| | |
|---|---|
| Escreve | `CustomerService` (`add` no spawn, `remove` ao sumir) |
| Lê | `CustomerController`: balão com ícones do `Order` (visível à party, DEC-071; só depois de `Take Order`); rosto pelo `Mood` (§5.3); reação ao `Sale`. `PromptController`: "Take Order" só em `Ordering`, "Serve" só em `Waiting` (previsão; o servidor revalida) |
| Frequência | ~1/s em pico (≤ 8 clientes de dia: chegada, fila, pedido, humor, saída) |
| Aparência | **não está aqui**: espécie, roupa, tipo/acessório e pack vão em atributos do modelo do NPC (§5.2). O modelo é achado pelo atributo `NpcId` = id do registro. Os prompts "Take Order"/"Serve" e "Refuse" são âncoras `Interactable` no rig com `EntityId` próprios (`architecture.md` §18.4); o `InteractionService` resolve âncora → rig → `NpcId` |
| Humor (onda 1, **Provisório**, `Q-164`) | só visual: Neutral na chegada → Annoyed quando falta ≤ 1/3 da paciência (`MoodRules.AnnoyedAt`) → Complaining ao desistir, em Errado ou Refuse; Happy em venda Completo/Perfeito (`content-data.md` §3.16). **Não** mexe no pagamento da DEC-072 até o desenho do game-designer (DEC-187: humor dinâmico completo, que muda pagamento, vem depois). O enum vem de `Content.Moods`: estender o humor não muda o `Net` |
| Gorjeta | a janela de gorjeta (16 + 4K) **não** vai no set: não aparece no HUD (DEC-015) e o resultado só existe no servidor |
| Duas paciências (**Q-192**, Provisório) | fila (`Phase = Queue`, 45 s) começa quando o cliente chega a Q1 (`Ordering`) e **não** revela K (não depende dele); no "Take Order" o servidor troca para `Phase = Order` (75 + 5K s) na mesma escrita de `Order`/`Waiting`, e zera o humor. O client não deriva mais nada: lê `PatienceEndsAt` + `PatienceSpan` e escolhe a barra por `Phase` (azul/amarela com relógio; verde/vermelha com pão). Queue esgotada = `Sale.Result Left`; Order esgotada = `Slow`. Cliente do tutorial: `Phase None`, `PatienceEndsAt 0` |
| Paciência e K oculto (**T41**, parcialmente substituída pela linha acima; o K segue oculto; decidida pelo architect, DEC-208 delegada; L-06 do QA, TASK-040) | `PatienceEndsAt` deixaria o client deduzir K (40 + 5K) antes do "Take Order", contra FEAT-011 ("K oculto"). Regra: o servidor escreve `PatienceEndsAt = 0` enquanto o cliente está `Arriving`/`Queued`/`Ordering` e o valor real (contado desde a chegada ao balcão, sem mudar a regra da DEC-072) na mesma escrita em que preenche `Order` e passa a `Waiting`. Nenhum visual da onda 1 precisa da paciência antes disso (`Annoyed` é escrito pelo servidor no `Mood`). Descartada: aceitar o vazamento (custo zero, mas abre leitura de K por exploit do client). Afeta TASK-033 (escrita) e TASK-034 (barra/rosto só com `PatienceEndsAt > 0`) |

### 3.7 `Upgrades` (id = `Content.Upgrades.IndexOf[key]`)

```lua
Upgrades = Lync.replicate(Lync.struct({ Level = Lync.int(0, 255), Wait = Lync.int(0, 255) })) -- Level real 0..9; Wait = turnos até a linha voltar à venda (cooldown do Gear Stand, Q-203), 0 = à venda; fio de 8 bits por causa do limite de keyframe do Lync 4.0.2 (comentário em src/Libs/Net)
```

| | |
|---|---|
| Escreve | `UpgradeService` |
| Lê | `MarketController` (bancada B1–B5: nível atual, próximo preço, "Maxed", "Trailer only", `Wait` > 0 = "Sold out", mini some). `Wait` = turnos restantes calculados no servidor (`UpgradeService:GetWait`; o contador de turnos não vai ao client). Cooldown: `design/upgrades.md`. v5.1 (D-07): **não** há `UpgradeController`; a peça visível no veículo (DEC-052) é alternada pelo servidor (`UpgradeService/Pieces.luau`, T38) e chega ao client como instância, sem leitura do set |
| Frequência | por compra; na troca de veículo, todos os registros de uma vez (num `batch`) |
| Nível por veículo (**DEC-184**) | o servidor guarda `Levels[vehicle][upgrade]`; o set mostra **só o veículo atual** (`Shift.Vehicle`). Na troca carrinho → trailer, o set é reescrito com os níveis do trailer (todos 1, ou 0 nos de compra única). O client nunca precisa do nível de um veículo que não está em uso |
| Onda 1 | só `cart`; 5 registros (UPG-001..005). `trailer_lights` existe com `Level = 0` e a bancada mostra "Trailer only" pela tabela (`Upgrades[k].Vehicles` não contém `cart`) |

## 4. Packets — onda 1

### 4.1 `Interact` (c → s)

```lua
Interact = Lync.packet(Lync.struct({
	Id = Lync.int(1, 65535),                    -- EntityId da âncora alvo (runtime, T33)
	Action = Lync.enum(Content.Actions.Keys),
}))
```

| | |
|---|---|
| Dispara | `PromptController` ao fim do hold (ou no toque) |
| Responde | `InteractionService` (único responder, T6, **Provisório** pela `Q-130`); despacha para a ação registrada por `RegisterAction(key, { Validate, Run })` |
| Taxa | ≤ 8/s por jogador; excesso descartado sem erro |
| Validação | membro ativo; alvo existe e aceita a ação (`StationKind`/tag); distância ≤ `Actions[a].Radius` + 2 de folga; requisito de mão (`Actions[a].Requires`, ex.: HotDog para "Add X"/"Serve", pacote do ingrediente certo para "Restock"); estado (vaga livre, estoque ≥ 1, fase). Falha → descarta; quando o jogador precisa saber (hotbar cheia, sem saldo), `Notice` |
| Hold | o servidor não cronometra o hold (o client segura e só então manda); a guarda contra hold falso é a taxa + a regra (FEAT-005 aceita a mesma tolerância do AnimalPlane) |
| Ações da onda 1 | `open_sign`, `grill_place`, `grill_collect`, `bun_cut`, `board_add_sausage`, `topping_add`, `discard`, `take_order`, `serve`, `refuse`, `restock`, `buy_package`, `bench_buy_upgrade` (`content-data.md` §3.18) |
| Prompt por jogador | o atributo `PromptEnabled` (servidor) diz se a ação existe para a party; a condição **da mão** ("Add Ketchup" só com HotDog sem ketchup) é avaliada no client pelo `Actions.Requires` + atributos da Tool na mão (`Toppings`), só para apresentação. O servidor revalida tudo |

### 4.2 `Notice` (s → jogador ou grupo)

```lua
Notice = Lync.packet(Lync.struct({
	Kind = Lync.enum(Content.Notices.Keys),
	Value = Lync.int(-1000000, 1000000),        -- parâmetro do texto ({value}); índice de tabela quando o texto cita item/upgrade
	By = Lync.optional(Lync.f64()),             -- DEC-320: UserId de quem fez (o client põe o nome do colega na frente)
}))
```

| | |
|---|---|
| Dispara | qualquer Service por `RunStateService:Notify(player | "all", key, value)` (TASK-010) |
| Lê | `HudController` (toast no canto superior direito, 3–6 s) |
| Onda 1 | `hands_full`, `package_limit`, `not_enough_cash`, `upgrade_bought` (Value = `IndexOf` do upgrade, "Grill upgraded!", grupo), `ingredient_unlocked` (Value = `IndexOf` do ingrediente, grupo, no `ShiftStarted`), `class_bought`, `class_selected`, `not_enough_gems`, `class_locked`, `mart_hint` (dica do Closing, grupo, uma vez por turno, Q-203), `class_locked` (`content-data.md` §3.19) |
| Frequência | evento (< 1/s) |

### 4.3 `Sale` (s → grupo)

```lua
Sale = Lync.packet(Lync.struct({
	Npc = Lync.int(1, 65535),                   -- NpcId
	Result = Lync.enum({ "Perfect", "Complete", "Incomplete", "Wrong", "Left", "Refused", "Slow" }), -- Left = não atendido (fila); Slow = a comida demorou (preparo, Q-192)
	Amount = Lync.int(0, 1000),                 -- valor que entrou na gaveta (com gorjeta)
}))
```

| | |
|---|---|
| Dispara | `CustomerService` (validação de "Serve", desistência, "Refuse") |
| Lê | `CustomerController` (balão feliz/neutro/reclamação), `EconomyController` ("+$N" flutuante na gaveta) |
| Frequência | por venda (≤ 1/s) |

### 4.3a `CustomerComplain` (s → grupo)

Janela de serviço fechada por um jogador (TASK-585, Provisório): o cliente reclama sobre a cabeça antes de ir embora.

```lua
CustomerComplain = Lync.packet(Lync.struct({
	Npc = Lync.int(1, 65535),                   -- NpcId
	Line = Lync.int(1, 64),                     -- índice em Content.ShopWindow.ShutLines
}))
```

| | |
|---|---|
| Dispara | `CustomerService:ComplainLineAway` (janela fechada por `ShutGrace` s) |
| Lê | `CustomerController`: balão `Complaint` com o texto + som/clipe de `Reactions.Feedback("Slow")`; o `Sale Refused` que vem `ComplainTime` s depois não troca o balão |
| Frequência | evento (um por cliente da fila, por fechamento) |
| `Perfect` | Completo **com** gorjeta (dentro da janela, DEC-072). `Wrong` → o HotDog volta à mão de quem serviu (Tool, sem rede) |
| Por que packet | é apresentação de um instante; o estado (gaveta) já está em `Economy` |

### 4.4 `ShiftReport` (s → grupo)

```lua
ShiftReport = Lync.packet(Lync.struct({
	Day = Lync.int(1, 10000),
	Night = Lync.int(0, 10),
	IsNight = Lync.bool(),
	Arrived = Lync.int(0, 999),                 -- clientes que chegaram ao balcão (FEAT-014)
	Completed = Lync.int(0, 999),               -- servidos completos (= satisfeitos, DEC-051)
	Drawer = Lync.int(0, 1000000),              -- gaveta antes do bônus (inclui gorjetas)
	Tips = Lync.int(0, 100000),
	Stolen = Lync.int(0, 1000000),              -- onda 1: sempre 0 (sem ladrão)
	Grade = Lync.enum({ "A", "B", "C", "D" }),  -- sem cliente = C (DEC-051)
	Bonus = Lync.int(0, 1000000),               -- floor(gaveta × %), DEC-051
	Deposited = Lync.int(0, 1000000),
	Gems = Lync.int(0, 1000),                   -- já creditado neste turno (DEC-104); onda 1: 0 (sem RewardService)
	AfkLocked = Lync.bool(),                    -- DEC-083; onda 1: false
	LastChanceUsed = Lync.bool(),               -- resumo de noite (DEC-053, DEC-110); onda 1: false
}))
```

| | |
|---|---|
| Dispara | `EconomyService` no início do Summary (com `RewardService` a partir da onda 2) |
| Lê | `HudController` (tela de resumo 15 s dia / 20 s noite, some sozinha) |
| Frequência | 1 por turno |
| Reconexão no meio do Summary | perde a tela (apresentação de 15 s); o dinheiro já está em `Economy` |

### 4.5 `Profile` (s → jogador)

```lua
Profile = Lync.packet(Lync.struct({
	Gems = Lync.int(0, 2147483647),
	Classes = Lync.bitfield(Content.Classes.Keys), -- desbloqueadas
	Selected = Lync.enum(Content.Classes.Keys),
	TutorialDone = Lync.bool(), -- legado (Q-193): ninguém lê; o tutorial roda no dia 1 de toda run
	Guides = Lync.bitfield(Content.Lobby.Guide.Keys), -- setas de chão do lobby já mostradas (Provisório, 2026-10-20)
}))

-- c -> s, Provisório (pedido do dono 2026-10-20). Responder: LobbyService. A seta de chão `Key` ("pad" | "classes")
-- chegou ao alvo: grava em LobbyGuides e não aparece mais. Cosmético, idempotente; o servidor confia no client.
LobbyGuideDone = Lync.packet(Lync.enum(Content.Lobby.Guide.Keys))

-- c -> s, Provisório (2026-10-11). Responder: TutorialService. Fecha o tutorial desta run para o jogador, só na
-- memória do servidor (nada é salvo; idempotente; Q-193). O servidor confia no client (nada de dinheiro, item ou stat depende disso).
TutorialComplete = Lync.packet(Lync.empty())

-- c -> s, Provisório (2026-10-11). Responder: TutorialService. O novato atendeu a ligação do tutorial (ou ela não
-- veio): se ele ainda tem o tutorial pendente (dia 1 da run, não concluído nem pulado), CustomerService:RequestTutorial() traz o cliente de tutorial (um por
-- vez; pedido fixo, sem paciência, fora da nota; atributo de rig `TutorialCustomer` = true). Idempotente.
TutorialBegin = Lync.packet(Lync.empty())
```

| | |
|---|---|
| Dispara | `ProfileService:Replicate` (effect existente + handshake `Ready`) |
| Lê | `ProfileController` → sources `Gems`, `Classes`, `Selected`; tela "Crew" (`ClassController`, TASK-020) |
| Frequência | quando muda (compra/seleção, crédito de gema) |
| Por que packet | privado por construção (README) |
| Chaves | `class_dog`, `class_rabbit`, `class_cat`, `class_bear`, `class_fox`, `class_owl`, `class_panda`, `class_lion` (`content-data.md` §3.10, **DEC-186**) |
| Ondas seguintes | + `ReviveCredits = Lync.int(0, 99)` (onda 4, DEC-117). `EndlessDays` e `Achievements` **não** vão ao client: achievement secreto (DEC-058); o toast de conquista vai por `Notice` |

### 4.6 `ClassAction` (c → s)

```lua
ClassAction = Lync.packet(Lync.struct({
	Action = Lync.enum({ "Buy", "Select" }),
	Class = Lync.enum(Content.Classes.Keys),
}))
```

| | |
|---|---|
| Dispara | `ClassController` (tela "Crew") |
| Responde | `ClassService` (L+R) |
| Validação | `Buy`: classe com `InMvp = true`, ainda não possuída, `Gems ≥ Price` (cópia do mapa, não mutação). `Select`: possuída; no Run, só **antes do spawn** e só em **modo dev** (**Provisório**, TASK-017: sem lobby na onda 1); fora do modo dev a classe é travada na run (DEC-069, DEC-186) |
| Resposta | `Profile` atualizado + `Notice` (`class_bought`, `class_selected`, `not_enough_gems`, `class_locked`) |
| Taxa | ≤ 2/s |
| Gemas de dev | **sem rede**: comando de servidor no Studio, só com `PlaceService:IsDev()` (TASK-017) |

### 4.7 Legado mantido na onda 1

| Entrada | Por que fica | Remoção |
|---|---|---|
| `Round` (packet `{ Status, Seconds }`) | `RoundController`/`RoundService` de exemplo compilam até as TASK-012/015 reescreverem; nenhuma task nova lê | onda 2, junto com a limpeza do `Net` (board, "Ondas seguintes") |
| `Vitals` (`Health`, `Armor`, `Stamina`) | `VitalService` + componente `Vital` de exemplo seguem compilando (TASK-004 aceite) | onda 2: vira o schema da §6.1 com o `VitalService` de sanidade |

## 5. Aparência de personagem (crew e NPC): contrato sem Lync

Base: DEC-145/146 (jogador é animal da crew), DEC-148 (textura), DEC-149 (NPC também é animal), DEC-150/181 (packs por
turno; Night reservado à tensão), DEC-152/161/162 (rosto por textura; expressões), DEC-166/167 (visual = faixa de
sanidade, só a crew), DEC-168/169 (sanidade baixa: NPC em Night **só para quem está na faixa**), DEC-188 (tipo de
cliente = espécie + acessório + roupa civil sorteada).

### 5.1 Técnica (T40, **Aprovada**: decidida pelo architect, DEC-208 delegada)

| Camada | Quem escreve | Como replica |
|---|---|---|
| **Geometria** (corpo R6, cabeça/orelhas/cauda da espécie, braços de uniforme ou civis, boné, acessórios do tipo) | servidor (`CrewRig.Build`, TASK-016), clonando do kit em `ReplicatedStorage.Assets.Crew` (TASK-006) | instâncias (nativo) |
| **Dados da aparência** (atributos §5.2) | servidor (`CharacterService` para a crew, `NpcService` para NPCs) | atributo (nativo) |
| **Textura e rosto** (`MeshPart.TextureID` do pack; `SurfaceAppearance` da casca de rosto clonada de `ReplicatedStorage.CrewExpressions`) | **cada client** (`CrewRig.Dress`), a partir dos atributos + camada local (§5.3) | não replica |

- O servidor **nunca** escreve `TextureID` nem `SurfaceAppearance` depois da montagem (o kit clonado já vem com o pack
  Day como padrão). Assim a troca local do client não é desfeita por replicação.
- O client veste ao ver o modelo (tag do binding da TASK-002; vale também para modelo que entra por streaming) e
  re-veste quando qualquer atributo da §5.2 muda ou quando a camada local muda.
- Pré-carga: ao entrar, o client faz `PreloadAsync` dos 3 packs das espécies da party e das roupas civis em uso
  (DEC-167, item Provisório "3 packs pré-carregados"). Memória: `Q-144` (g), art-director + architect.
- **Alternativa descartada:** servidor aplicar texturas e o client sobrescrever localmente para a sanidade baixa. O
  servidor reescreve `TextureID` na virada Day → Mid e apaga o override local; `SurfaceAppearance` trocada no servidor
  duplica a casca local. A troca local da DEC-168 ficaria frágil.

### 5.2 Atributos no modelo

| Atributo | Em | Valores (chave de `Content`) | Escreve | Onda |
|---|---|---|---|---|
| `Species` | personagem da crew, NPC | `Species.Keys` (`dog`, `penguin`…) | `CharacterService` (da classe), `NpcService` | 1 |
| `Outfit` | personagem, NPC | `Outfits.Keys`: `crew` (jogador), `civil_a`..`civil_h` (sorteada, DEC-160/188), `thief` (Quentin) | idem | 1 |
| `CustomerType` | NPC | `CustomerTypes.Keys`; define o(s) acessório(s) (DEC-188). Passante: `pedestrian` (onda 2) | `NpcService` | 1 |
| `LookPack` | personagem, NPC | `"Day"`, `"Mid"`, `"Night"` | crew: `CharacterService` (onda 1 sempre `Day`; onda 2 pelo `VitalService` conforme a faixa); NPC: `NpcService` (Day de dia, Mid à noite, DEC-181; Night só no clima de anomalia, onda 3, `Q-159`; **Provisório (2026-10-14):** o client também veste Night, sempre, nas variantes `blank`/`raincoat`, e a faixa baixa do jogador local não veste mais NPCs) | 1 |
| `NpcId` | NPC | id do registro em `Customers` | `NpcService` | 1 |
| `FromWalker` | NPC | id (slot 1..`WalkPaths.Rules.Slots`) do registro de `Pedestrians` que virou este cliente (adoção, TASK-163); ausente nos outros. Escrito antes de o rig entrar no `Workspace`, no mesmo frame em que o registro do passante sai; o client usa para a troca sem pulo (TASK-164). Sem rig do `CustomerType` (sem acessório: o passante não tinha) | `NpcService` | 3 (**Provisório**, pedido ao architect ratificar) |

O rosto **não** é atributo escrito pelo servidor: deriva do pack (crew: Day → Normal, Mid → Exhausted, Night →
`Normal_Night`, DEC-166/167; `Down` → Fainted, **Provisório** DEC-167) e, no NPC, do `Customers.Mood` (§5.3). O
atributo `Expression` da §18.9.2 do `architecture.md`, se o `CrewRig` o escrever, é local ao client (debug).

Valores de `Outfit` são **chaves de `Content.Outfits`** (`crew`, `civil_a`…`civil_h`, `thief`), pela regra "valores são
chaves" do binding (§18.0 item 4). O `CrewLooks.Outfits` (§18.9.3, TASK-006) deve ser indexado por essas chaves
(`crew → "Crew_Uniform"`, `civil_a → "Civil_A"`…); hoje o rascunho usa `Crew`, `A`..`H`, `Thief`.

### 5.3 Camada local do client (o que cada client decide sozinho)

| Regra | Valor | Origem |
|---|---|---|
| Crew: pack | `LookPack` do personagem; **todos** veem o mesmo (a faixa é estado do servidor) | DEC-167, DEC-169 |
| Crew: 1ª pessoa | braços/mãos com o pack do próprio `LookPack`; retrato do rosto no HUD pelo mesmo atributo | DEC-167 |
| NPC: pack | `LookPack` do modelo, **exceto** se o personagem local estiver com `LookPack = "Night"` à noite (faixa baixa, < 40): então todo cliente e passante é vestido **Night + `Normal_Night`** só neste client | **DEC-168, DEC-169**. **Provisório (2026-10-14):** a faixa baixa local **não** veste mais NPC; o pack é o do modelo (Night só nas variantes `blank`/`raincoat`, sempre, `NIGHT_VARIANTS` no `RigController`; `mirror` fica com o pack do servidor). O Night do personagem do próprio jogador segue pelo servidor |
| NPC: rosto | `Moods[Customers.Mood].Expression` (Normal, Happy, Skeptical, Stressed); o humor vale também na faixa baixa (**Provisório (2026-10-14)**: `Normal_Night` não vence mais); variantes têm rosto fixo: `blank` = `Blank`, `raincoat` = `EyesClosed`, `mirror` = `EyesWhite` | DEC-162, DEC-187, `Q-164` |
| Fora da troca local | Opal (CHR-003, local, DEC-191), Quentin (só dia, só textura Day, DEC-159), atores de anomalia que dependem do sinal (`Q-147`, onda 3) | DEC-159, DEC-191 |
| Transição | instantânea, sem VFX | DEC-167 |
| Proibido | Desmaiado (X) em NPC; pack Mid na crew de dia | DEC-187 (Provisório), DEC-167 |

Onda 1: só dia → crew sempre Day + Normal; NPC Day + rosto pelo `Mood`. As regras de noite já valem como contrato
para a onda 2 (sem mudança de rede: só os valores de `LookPack` mudam).

### 5.4 Divergência com a T35 (`architecture.md` §18.9.4, TASK-002)

A TASK-002 propôs a T35: pack da crew e Day/Mid de NPC aplicados **no servidor** (replica); só o Night local da faixa
baixa no client, **reaplicado** quando o servidor muda o pack. Este documento propõe a T40 (client veste tudo a partir
dos atributos). Os atributos, quem os escreve e o que cada jogador vê são **iguais** nas duas; muda só quem escreve
`TextureID`/casca de rosto.

| Ponto | T35 | T40 (esta versão) |
|---|---|---|
| Texto da DEC | — | DEC-169 (tabela "Como": "servidor replica a faixa; cada client aplica a textura daquele personagem") e DEC-167 (Impacto: "troca no client") |
| Override local da DEC-168 | apagado a cada escrita do servidor (virada Day → Mid, pool reaproveitado); depende de reaplicar | servidor nunca escreve textura depois da montagem; nada a reaplicar |
| Quem entra depois | recebe pronto | recebe o kit no pack Day (padrão do kit) e o client aplica Mid/Night no mesmo frame em que o atributo chega |
| Fontes | uma (servidor) + override | uma (atributo) |

Pela ordem de autoridade do `CLAUDE.md` (DEC acima de Rascunho), **vale a T40** até o usuário decidir na `Q-130`.
Pedido à TASK-002: alinhar §18.9.4 (ou registrar a divergência lá). Tasks afetadas (descrição na board diz "servidor
aplica pack Day"): TASK-016 (`CrewRig` ganha `Dress` no client), TASK-018, TASK-031 (servidor só monta e escreve
atributos), TASK-034. Para a onda 1 a diferença é pequena: de dia tudo é Day, que é o padrão do kit.

## 6. Ondas 2–4 (contrato v3 mantido; não entra no `init.luau` da onda 1)

### 6.1 `Vitals` (id = `UserId`) — schema da onda 2 (**Provisório**)

```lua
Vitals = Lync.replicate(Lync.struct({
	State = Lync.enum({ "Active", "Down", "Reviving", "Spectator", "Away" }),
	StateEndsAt = Lync.f64(),       -- Down: 6:00 AM da noite da queda (DEC-115); 0 = sem prazo
	KnockedUntil = Lync.f64(),      -- atropelado até (ragdoll); 0 = de pé
	Class = Lync.enum(Content.Classes.Keys),
}))
Sanity = Lync.packet(Lync.struct({  -- s → dono; enviado na mudança (≤ 1 Hz no escuro e na queda ambiente da fase Night) e no Ready/respawn
	Value = Lync.int(0, 200),
	Max = Lync.int(0, 200),
}))
```

| | |
|---|---|
| Mudança da v3 | `Sanity`/`MaxSanity` saem do set (iam a todos) e vão só ao dono. DEC-167: "o número nunca é mostrado a outro jogador"; a party vê a faixa pela aparência (`LookPack`, §5). Menos dado exposto a exploit; banda igual |
| Escreve | `VitalService` (+ componente `Vital`); `LookPack` no personagem pela faixa (≥ 60 Day, 40–59 Mid, < 40 Night; de dia sempre Day; `Content.Sanity.Bands`) |
| Lê | `VitalController` (medidor e retrato), `CameraController` (spectate), `ReviveController`, `HallucinationController` (faixas de alucinação < 60/< 40/< 20, FEAT-019) |
| Packet e reconexão | como o `Profile`: reenviado no `ClientReady` e no respawn |

### 6.2 Demais entradas (sem mudança de schema desde a v3.1)

```lua
| Escuro no cliente | o pacote não diz a causa da queda. O servidor marca o `Player` com o atributo `SanityDarkAt` (`Content.Sanity.DarkAtAttribute`, hora do servidor do último tick que tirou sanidade por escuro) e o `VitalController` liga o visual de escuro até `DARK_HOLD` depois dele (Q-477; antes era a heurística "queda ≤ 2 × DarkPerSecond") |
Switches = Lync.replicate(Lync.struct({ On = Lync.bool() })), -- interruptor do trailer (DEC-189: vem de fábrica)
Bench = Lync.replicate(Lync.struct({
	Item = Lync.enum(Content.BenchItems.Keys),  -- inclui "none"
	Price = Lync.int(0, 100000),                -- já × PriceParty (DEC-129)
	Left = Lync.int(0, 9),
})),
Traffic = Lync.replicate(Lync.struct({
	Route = Lync.int(1, 32), Look = Lync.int(1, 16),
	AnchorAt = Lync.f64(), AnchorDist = Lync.f32(), StopDist = Lync.f32(), HeldUntil = Lync.f64(),
})),
Ambulance = Lync.replicate(Lync.struct({
	Trip = Lync.enum({ "Pickup", "Return", "Dawn" }),
	Phase = Lync.enum({ "Arrive", "Load", "Leave", "Drop", "Depart" }),
	StartedAt = Lync.f64(), Stop = Lync.int(1, 4),
	Riders = Lync.array(Lync.struct({ UserId = Lync.f64(), Body = Lync.vec3() }), 0, 4),
})),
Cutscene = Lync.replicate(Lync.struct({
	Scene = Lync.enum(Content.Cutscenes.Keys), StartedAt = Lync.f64(),
	Votes = Lync.int(0, 4), Needed = Lync.int(0, 4), -- ceil(50% dos conectados), DEC-194
})),
Parties = Lync.replicate(Lync.struct({ ... })),    -- lobby; plataformas físicas (DEC-179)
```

| Entrada | Escreve → lê | Frequência | Nota |
|---|---|---|---|
| `Switches` | `KitchenService`/`VehicleService` → `TrailerController` | por toque | interruptor vem com o trailer (DEC-189) |
| `Bench` | `MarketService` → `MarketController` | 1 por turno + compras | só a vaga especial S1; básicos leem `Upgrades` (DEC-106) |
| `Traffic` | `TrafficService` → `TrafficController` | ≤ 6 por carro | DEC-133; noite rara (DEC-198) |
| `Ambulance` | `AmbulanceService` → `AmbulanceController` | ~5 por viagem | uma por servidor (DEC-114) |
| `Cutscene` | `CutsceneService` → `CutsceneController` | início, votos, fim | limiar ≥ 50% dos **conectados** (DEC-194) |

| Packet | Direção | Schema | Responde/lê | Nota |
|---|---|---|---|---|
| `Gaze` | c → s, `:newest(10)` | `{ Yaw: angle(1), Pitch: angle(1) }` | `AnomalyService` | só à noite |
| `CarHit` | c → s | `{ Car: int(1,8) }` | `TrafficService` | ± 8 studs |
| `Revive` | c → s | `{ Target: f64, Method: enum({"Robux","Item","Credit"}) }` | `ReviveService` | Robux/crédito só para si (DEC-116) |
| `SkipVote` | c → s | `Lync.empty()` | `CutsceneService` | DEC-194 |
| `BossCall` | s → grupo | `{ Call: enum(Content.BossCalls.Keys), Short: bool }` | `BossController` | não pulável (DEC-194 b, Provisório) |
| `AnomalyCue` | s → jogador/grupo | `{ Anomaly, Cue, Entity: int(0,65535), Seed: int(0,65535), User: f64? }` (`User` = UserId do cue pessoal, DEC-320) | `AnomalyController` | |
| `LifeEvent` | s → grupo | `{ UserId: f64, Event: enum({"Down","Revived","Spectating","Hit","Wipe","WipeCleared"}) }` | Camera, Hud, Ambulance | |
| `PartyAction` | c → s | `{ Action: enum({"Leave","Ready","Unready","Start"}), Party: int(0,255) }` | `PartyService` | entrar = pisar na plataforma (DEC-179), sem `Join` |
| `Reconnect` / `ReconnectReply` | s → c / c → s | como na v3 | `SessionService` | |

## 7. O que não passa pelo Lync

| O quê | Como replica | Por quê |
|---|---|---|
| Tools (pacotes, HotDog, café, Revive Kit) | Backpack nativo; atributos na Tool (§7.1) | DEC-040 |
| Aparência de personagem (pack, rosto, espécie, roupa) | atributos + vestir no client (§5) | T40 |
| Pacote grátis do dia de liberação | **modelo de exibição** (não `Tool`, sem `Handle` tocável) sobre a estação nova, com âncora `Interactable` → `pick_up_item` (prompt "Take", toque, raio 7, `Content.Actions`); o servidor valida hotbar de 4 (DEC-174) e limite de pacotes (2, Urso 3), cheio → o pacote vai **direto ao estoque** do ingrediente (`Notice ingredient_stocked`, 2026-10-11; sem estoque a receber → `hands_full` e o pacote fica no mundo); pego com espaço → vira a Tool `pack_*` na mão; todo dia com `1 < UnlockDay <= dia` (inclusive dias pulados) põe o pacote uma vez. **Provisório** (N-03 do board, L-03 do QA). Dono: TASK-046 | DEC-071 |
| Prompts (`PromptEnabled`, `PromptText`, `PromptHold`) | atributos das peças, mantidos pelo servidor (TASK-011; nomes no binding da TASK-002) | prompt é do mundo |
| Peças de upgrade, troca de veículo | instâncias no `Workspace`; peça alternada **pelo servidor** por visibilidade (T38), sem controller no client (v5.1, D-07) | DEC-052 |
| NPCs (posição, animação) | física + `Animator` no servidor (T11); passantes por `Motor6D.Transform` (DEC-183, Provisório, onda 2) | |
| Opal | modelo e falas locais ao client (`OpalController`), zero rede | DEC-079, DEC-191 |
| Item derrubado, ragdoll, luzes dos postes, compra em Robux, teleporte/snapshot | como na v3.1 | |

### 7.1 Atributos de Tool (contrato com `ItemService`, `HotDogVisual`, `PromptController`)

| Atributo | Tools | Tipo | Escreve | Uso |
|---|---|---|---|---|
| `Item` | todas | string (`Content.Items` key) | `ItemService` | identificar sem depender do nome da Tool (nome igual ao do binding, §18.2) |
| `Count` | pacotes, café | int | `ItemService` | sobra do pacote (DEC-049) |
| `Toppings` | `hot_dog` | string: chaves de `Ingredients` separadas por vírgula, **na ordem de montagem** (ex.: `"ketchup,cheese"`); `""` = sem complemento | `ItemService` (a cada "Add X") | `HotDogVisual` empilha (queijo antes dos cordões, DEC-142); `PromptController` esconde "Add X" já presente; `CustomerService` valida o pedido (ordem ignorada, DEC-071) |
| `Altered` | `hot_dog` | bool | `ItemService` | onda 3 (ITM-020) |
| `Restore` | `coffee` | int | `ItemService` (do `CoffeeRestore` de quem preparou: 25 / Barista 35) | `VitalService` ao beber (onda 2, `architecture.md` §19.8) |

Por que string e não bitmask: a ordem de montagem é dado (DEC-142 usa a ordem para o visual); ≤ 3 complementos,
custo irrelevante; legível no Explorer.

## 8. `init.luau` da onda 1 (referência para a TASK-004)

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)
local Content = require(ReplicatedStorage.shared.Content)

return Lync.define("game", {
	Ready = Lync.packet(Lync.empty()),

	Profile = Lync.packet(Lync.struct({
		Gems = Lync.int(0, 2147483647),
		Classes = Lync.bitfield(Content.Classes.Keys),
		Selected = Lync.enum(Content.Classes.Keys),
	})),

	-- sets da run (onda 1)
	Shift = Lync.replicate(Lync.struct({ --[[ §3.1 ]] })),
	RunState = Lync.replicate(Lync.struct({ --[[ §3.2 ]] })),
	Economy = Lync.replicate(Lync.struct({ Cash = Lync.int(0, 2147483647), Drawer = Lync.int(0, 1000000) })),
	Stock = Lync.replicate(Lync.struct({ Amount = Lync.int(0, 999), Capacity = Lync.int(0, 999), Blocked = Lync.bool() })),
	Stations = Lync.replicate(Lync.struct({ --[[ §3.5 ]] })),
	Customers = Lync.replicate(Lync.struct({ --[[ §3.6 ]] })),
	Upgrades = Lync.replicate(Lync.struct({ Level = Lync.int(0, 255), Wait = Lync.int(0, 255) })), -- Level 0..9 real, Wait = turnos de cooldown (§3.7)

	-- packets (onda 1)
	Interact = Lync.packet(Lync.struct({ --[[ §4.1 ]] })),
	Notice = Lync.packet(Lync.struct({ --[[ §4.2 ]] })),
	Sale = Lync.packet(Lync.struct({ --[[ §4.3 ]] })),
	ShiftReport = Lync.packet(Lync.struct({ --[[ §4.4 ]] })),
	ClassAction = Lync.packet(Lync.struct({ --[[ §4.6 ]] })),

	-- legado mantido até a onda 2 (§4.7)
	Vitals = Lync.replicate(Lync.struct({
		Health = Lync.int(0, 100), Armor = Lync.int(0, 100), Stamina = Lync.int(0, 100),
	})),
	Round = Lync.packet(Lync.struct({
		Status = Lync.enum({ "Waiting", "Playing", "Ending" }), Seconds = Lync.int(0, 3600),
	})),
})
```

- `Content` precisa expor, na onda 1: `Shift.PhaseKeys`, `Vehicles.Keys`, `Stations.RecordKeys`,
  `Ingredients.ToppingKeys`, `Moods.Keys`, `Actions.Keys`, `Notices.Keys`, `Classes.Keys` (TASK-003). Requerer
  `shared.Content` em `Net` é seguro (não depende de `self.Libs`, Lync ou Vide).
- Checklist de PR que toca este arquivo: `tools/analyze.ps1` zero erro **e** boot no Studio sem erro de
  `Lync.start()` (o schema só é validado em runtime, R8).

## 9. Orçamento de replicação (onda 1, por client, pior caso: party de 4 em pico de dia)

| Fonte | Taxa | Bytes/s aprox. |
|---|---|---|
| `Stations` | ~1–2 escritas/s (4 jogadores montando) | < 40 |
| `Customers` | ~1/s (≤ 8 clientes) | < 30 |
| `Stock` | ≤ 2/s | < 15 |
| `Economy`, `Shift`, `Upgrades`, `RunState` | eventos | < 10 |
| packets (`Notice`, `Sale`) | eventos | < 20 |
| `Interact` (c → s) | ≤ 8/s, típico 1/s | ~5 por jogador |

Total de Lync < 150 B/s por client. Atributos de aparência: uma vez por spawn de NPC (≤ 1 a cada ~5 s) e por troca de
faixa (onda 2). O peso real continua sendo física dos Humanoids (T11) e memória de textura (`Q-144` g).

## 10. Escolhas justificadas (resumo)

| Escolha | Por quê |
|---|---|
| Tábua = 2 registros `board` + prompt único na tábua | mesmo padrão da grelha (registro = vaga com barra); prompts vizinhos ≥ 2,5 studs; servidor escolhe a vaga, o client nunca manda índice de vaga |
| `Blocked` em `Stock`, não em `Stations` | bloqueio é do ingrediente no dia; uma flag serve tigela, Mart e pedido |
| Aparência fora do `Customers` | passantes (DEC-183), ladrão e atores de anomalia também precisam; um mecanismo para todo NPC; o set fica com estado de jogo |
| `Mood` por tabela | humor dinâmico (DEC-187) ainda em desenho (`Q-164`); estender sem tocar no `Net` |
| `Upgrades` só do veículo atual | DEC-184 separa níveis; o client só mostra o veículo em uso; o dono guarda os dois |
| `Sanity` privado (onda 2) | DEC-167 (número nunca a outro jogador); a faixa já é visível pela aparência |
| Entradas das ondas 2–4 fora do `init.luau` da onda 1 | sem stubs de tabela para enums que ainda não existem; adicionar entrada depois não quebra as outras |
| Sem `keyBy` | T14 |

## 11. Sobreposição com a TASK-002 (`architecture.md` §18)

A TASK-002 (outra sessão do architect) escreveu o binding, os kits e o layout de módulos em `architecture.md` §18 e
deixou notas para esta task em §18.14. Este documento **não** edita `architecture.md`. Resposta item a item:

| §18.14 | Resposta nesta versão |
|---|---|
| 1. chaves de `Stations` | **adotadas**: `sausage_stock`, `grill`, `rail`, `bun_crate`, `board`, `toppings`, `trash` (+ `coffee_machine`) (`content-data.md` §3.6). Gaveta, placa, prateleiras e bancada não são estação |
| 2. instância ↔ registro do set | **adotado**: atributo `StationId`; id do registro = `StationId × 100 + Slot` (`Slot = 0` no trilho). Tigela não tem registro (estado em `Stock`) |
| 3. `Actions` | `board_add_topping` vira **`topping_add`**; demais iguais. `bench_buy_item` e `pick_up_item` existem na tabela desde a onda 1 (a checagem do binding recusa chave fora de `Content`). v5.1 (D-06): `bench_buy_item` sem prompt ativo até a onda 4; `pick_up_item` **ativo** na onda 1 com prompt "Take" (toque, raio 7) só no pacote grátis (TASK-046, §7) |
| 4. `Upgrades.BenchSpot` | `B1`..`B5` (`content-data.md` §3.7) |
| 5. `Vehicles.Model` | sai; o veículo é o `Model` com tag `Vehicle` (T36) |
| 6. `Species.Asset`, `Items.ToolModel` | `Species.Asset` = nome do animal no kit; `ToolModel` sai (a Tool do kit tem o nome da chave). Idem `Ingredients.Model` (cobertura = `Assets.Items.Toppings/<chave>`) |
| 7. sufixo PascalCase | aceito, sem campo |
| 8. `Toppings` | formato confirmado (§7.1); atributo da chave do item = **`Item`** (nome do §18.2) |
| 9. faixa de sanidade | fonte = `VitalService` (onda 2), escrita como atributo `LookPack` no personagem (não é espelho: é o valor replicado); `Vitals` não leva faixa nem número (§6.1) |

Divergências que ficam abertas entre as duas sessões:

| Ponto | TASK-002 | Este documento | Encaminhamento |
|---|---|---|---|
| Quem aplica textura | T35: servidor (crew e Day/Mid de NPC) | T40: client, a partir de atributos | §5.4; vale a T40 pela DEC-167/169 até a `Q-130`; TASK-002 alinha §18.9.4 |
| Valores de `Outfit` | `Crew`, `A`..`H`, `Thief` (§18.9.2) | chaves de `Content.Outfits` (`crew`, `civil_a`…) | §18.0 item 4 ("valores são chaves") pede chave; `CrewLooks` mapeia |
| Nomes de expressão | `Smile` (nome do JSON de texturas) | `Content.Looks.Expressions` usa os nomes do JSON | alinhado: `Smile`, não `Smiling` |

## 12. Provisórios desta versão

| Item | Base | Fecha em |
|---|---|---|
| T6 (`InteractionService` único), T13 (enums das tabelas), T14 (sem `keyBy`) | architect | `Q-130` |
| **T40** aparência vestida no client a partir de atributos (diverge da T35) | DEC-167/169 ("troca no client") + nota técnica da DEC-168 | `Q-130` (acrescentar); alinhar com a T35 (§11) |
| Humor simplificado (Neutral/Happy/Annoyed/Complaining, só visual) | board, TASK-033 | `Q-164` |
| `Sanity` como packet privado (onda 2) | DEC-167 (leitura do architect) | `Q-130` |
| `Stations` id = `StationId × 100 + Slot` | architect, sugestão do §18.14 item 2 da TASK-002 | — |
| Rosto Desmaiado na crew `Down`; `Normal_Night` vence o humor (**Provisório (2026-10-14):** só o Desmaiado segue; o humor não é mais vencido pela faixa baixa) | DEC-167 (itens Provisórios), proposals-round-3 §2 | game-designer |
| `Select` de classe no Run em modo dev | TASK-017 | lobby (`Q-085`, onda 2) |

## 13. Ondas 2–4: entradas (versão 5)

Contrato de código de cada dono: `architecture.md` §19. Regras da §1 valem (sem `keyBy`, T14; enums das tabelas,
T13; `*At` em tempo de servidor; packets s → c só para `NetService.Audience` ou um jogador `Ready`; todo c → s
validado). Uma task de contrato por onda escreve as entradas da onda em `src/Libs/Net/init.luau` (W2-0, W3-0, W4-0,
`architecture.md` §19.24); acrescentar entrada não quebra as outras.

### 13.0 Resumo por onda

| Entrada | Tipo | Id / alvo | Escreve | Lê | Frequência | Onda |
|---|---|---|---|---|---|---|
| `Vitals` | set | `UserId` | `VitalService` | `VitalController`, `CameraController`, `HudController` | troca de estado (≤ 1/s por jogador) | 2 |
| `Sanity` | packet s → dono | jogador | `VitalService` | `VitalController`, `HallucinationController` | ≤ 1/s à noite; no `Ready`/respawn | 2 |
| `LifeEvent` | packet s → grupo | grupo | `VitalService`, `TrafficService` (`Hit`) | Hud, Camera, Anim, Audio | evento | 2 |
| `Lights` | set | `IndexOf(LightGroups)` | `LightService` | `LightController` | toque no interruptor, início da noite, Hush | 2 |
| `Power` | set | `1` | `LightService` | `PowerController` | queima/conserto da lâmpada, início/fim do apagão (§13.2a) | — |
| `Call` | set | `1` | `BossService` | `BossController`, `HudController` | ~3 por ligação | 2 |
| `Thief` | set | `1` | `ThiefService` | `ThiefController` | ~4 por ladrão | 2 |
| `Transition` | packet s → grupo | grupo | `VehicleService` | `VehicleController` | 1 por run | 2 |
| `Transition` Kind `TrailerFocus` | packet s → grupo | grupo | `VehicleService` (cue da chamada `call_trailer_offer`) | `VehicleController` → `ObjectiveController` (foco da câmera ~3 s na placa) | 1 por run | 3 |
| `Transition` Kind `TrailerDoor` | packet s → jogador | quem usou a porta | `TrailerDoorService` | `VehicleController` (fade 0,65 s) | por uso, cooldown 1 s | 3 |
| `SanityCue` | packet s → dono | dono | `VitalService` | `VitalController` / `HudSanity` | Hint 1x na noite 1; Gain por café | 3 |
| `RunReport` | packet s → jogador | jogador | `RoundService` (`Gems` pelo passo do `RewardService`, T59) | `HudController` | 1 por run | 2 |
| `Anomalies` | set | ocorrência 1..255 | `AnomalyService` | `AnomalyController`, `LightController`, `AudioController` | ≤ 2/s com Walker ativo | 3 |
| `AnomalyCue` | packet s → grupo | grupo (DEC-204) | `AnomalyService` | `AnomalyController` | evento | 3 |
| `Gaze` | packet c → s, `:newest(10)` | — | `CameraController` (só à noite, `Active`) | `AnomalyService` | 10 Hz | 3 |
| ~~`Hides`~~ → atributo `Shutter` (v5.2, DEC-221) | atributo do `Model` do veículo | veículo | `VehicleService` | `VehicleController`, `PromptController` | evento (≤ 1/s) | 3 |
| `Cutscene` | set | `1` | `CutsceneService` | `CutsceneController` | início, votos, fim | 3 |
| `SkipVote` | packet c → s | — | `CutsceneController` | `CutsceneService` | ≤ 1 por segmento | 3 |
| `Traffic` | set | slot 1..8 | `TrafficService` | `TrafficController` | ≤ 6 por carro | 3 |
| `CarHit` | packet c → s | — | `TrafficController` | `TrafficService` | evento | 3 |
| `Pedestrians` | set | slot 1..8 | `PedestrianService` | `PedestrianController` | spawn + paradas na faixa | 3 |
| `Parties` | set (lobby) | plataforma | `PartyService` | `PartyController` | entrar/sair/contagem | 4 |
| `PartyAction` | packet c → s | — | `PartyController` | `PartyService` | ≤ 2/s | 4 |
| `Reconnect` / `ReconnectReply` | packet s → c / c → s | jogador | `SessionService` / `SessionController` | o outro lado | entrada no lobby, 30 s | 4 |
| `Ambulance` | set | `1` | `AmbulanceService` | `AmbulanceController` | ~5 por viagem | 4 |
| `Revive` | packet c → s | — | `ReviveController` | `ReviveService` | ≤ 1/s | 4 |
| `Bench` | set | `1` (S1) | `MarketService` | `MarketController` | 1 por turno + compra | 4 |
| `Profile` | packet (existe) | jogador | `ProfileService` | `ProfileController` | + `ReviveCredits` | 4 |

### 13.1 Onda 2: vida, sanidade, transições, fim de run

```lua
Vitals = Lync.replicate(Lync.struct({        -- id = UserId (substitui o legado Health/Armor/Stamina)
	State = Lync.enum({ "Active", "Down", "Reviving", "Spectator", "Away" }),
	StateEndsAt = Lync.f64(),                 -- Down: 6:00 AM da noite da queda (DEC-115); 0 = sem prazo
	KnockedUntil = Lync.f64(),                -- atropelado até (onda 3); 0 = de pé
	Class = Lync.enum(Content.Classes.Keys),
})),
Sanity = Lync.packet(Lync.struct({           -- s → dono
	Value = Lync.int(0, 200),
	Max = Lync.int(0, 200),                   -- 0 = sem sanidade (dia): HUD esconde o medidor
})),
LifeEvent = Lync.packet(Lync.struct({        -- s → grupo
	UserId = Lync.f64(),
	Event = Lync.enum({ "Down", "Revived", "Spectating", "Hit", "Wipe", "WipeCleared" }),
})),
Transition = Lync.packet(Lync.struct({       -- s → grupo
	Kind = Lync.enum({ "VehicleSwap" }),
	StartedAt = Lync.f64(),
})),
RunReport = Lync.packet(Lync.struct({        -- s → cada jogador no RunEnded
	Result = Lync.enum({ "Success", "Failed" }),
	Day = Lync.int(1, 10000),
	Night = Lync.int(0, 10),
	Gems = Lync.int(0, 100000),               -- gemas desta run para este jogador: RunRewards.Gems do perfil, posto pelo
	                                          -- passo do RewardService (RoundService:AddRunReportStep, T59); 0 sem Reward
})),
```

| Escolha | Por quê |
|---|---|
| `Vitals` set, `Sanity` packet | estado de vida a party vê e quem chega precisa pronto (set); o número da sanidade é só do dono (DEC-167: a party vê a faixa pela aparência, `LookPack`) |
| `LifeEvent` packet | apresentação de um instante (desbotar, "Zzz", toast); o estado já está em `Vitals` |
| `Transition` packet | fade de 1,5 s; quem reconecta no meio não precisa dele. A sequência da noite perdida **não** usa packet: sai de `Shift.Phase = "NightLost"` + `PhaseStartedAt` |
| `RunReport` packet por jogador | gemas da run são por jogador (`RunRewards`); reconexão no `RunEnd` perde só a tela |
| `Gems` vindo de passo registrado (v5.1, T59) | o `RewardService` requer o `RoundService`, nunca o contrário (T42); o total já está no perfil (`RunRewards.Gems`, gravado no crédito), então a retomada em outro servidor não zera a tela; sem campo novo no Lync nem estado novo na run |

### 13.2 `Lights` (onda 2)

```lua
Lights = Lync.replicate(Lync.struct({        -- id = Content.LightGroups.IndexOf[key]
	On = Lync.bool(),                         -- grupo aceso agora (noite, interruptor/upgrade, sem Hush)
	At = Lync.f64(),                          -- instante da última troca; Hush: início (postes apagam por Order × Step)
})),
```

| | |
|---|---|
| Escreve / lê | `LightService` / `LightController` (visual), `VitalController` (previsão do medidor) |
| Por quê set | todos veem as mesmas luzes; quem reconecta no Hush vê os postes certos |
| Fora daqui | a regra do escuro (zona ativa) é calculada no servidor (T8); o client só desenha |

### 13.2a `Power` (pedidos do dono 2026-10-21; **Provisório**, Q-433, Q-434, Q-435)

```lua
Power = Lync.replicate(Lync.struct({         -- registro 1
	Burnt = Lync.bool(),                      -- lâmpada da cozinha queimada (interruptor morto)
	Out = Lync.bool(),                        -- apagão do ANM-020 ligado (sobrevive à ocorrência até o disjuntor) ou desarme
	Trip = Lync.bool(),                       -- Out é o disjuntor desarmando sozinho, sem anomalia (Content.Breaker, Q-435)
	At = Lync.f64(),                          -- instante da última troca (o client só toca a queima se for recente)
})),
```

| | |
|---|---|
| Escreve / lê | `LightService` / `PowerController` (faísca, som `power_cut`, linha do `Announce`; espelha em `Light/Power` para `Effects/ANM-020` manter o escuro com `Out` depois que o registro do `Anomalies` sai) |
| Apagão (Q-434) | o escuro antes do susto tem 12 s (era 30); o ANM-020 termina `LeaveAfter` (6) s depois do susto, mas a energia **fica cortada** até alguém segurar o disjuntor (ou turno novo / restore). Antes a ocorrência segurava mais `MaxDark` (20) s e devolvia a luz sozinha |
| Regra | `Content.Bulb.Toggles` (6) toques no interruptor em `Bulb.Window` (8 s), por servidor, queimam a lâmpada: `trailer_interior` apaga (registro do `Lights`), o prompt do interruptor fica com `Bulb.DeadText` e recusa, e o prompt `breaker_reset` (o disjuntor lá fora do ANM-020, mesma seta guia) liga. Segurar o disjuntor conserta e reacende. Turno novo ou restore também consertam |
| Por quê set | todos dividem a mesma luz; quem entra depois vê o estado sem a faísca (`Bulb.Fresh` s) |
| Fora daqui | sem packet novo: o conserto é a ação `breaker_reset` que já existe |

### 13.2b `Chores` (pedido do dono 2026-10-21; **Provisório**, Q-436)

```lua
Chores = Lync.replicate(Lync.struct({        -- registro = Content.Chores.IndexOf[key]
	On = Lync.bool(),                         -- a tarefa está ligada
	Mask = Lync.int(0, 255),                  -- rats: bit i-1 = rato em Rules.Spots[i]; camera_static: índice em Security.Cams
	At = Lync.f64(),                          -- instante em que começou (o client só toca o início se for recente)
})),
```

| | |
|---|---|
| Escreve / lê | `ChoreService` / `ChoreController` (fogo, ratos, linha do `Announce`, sons) e `SecurityController` (câmera sem imagem: chiado cheio + "NO SIGNAL") |
| Ações | `fire_out` (segurar 2 s na chapa), `rat_shoo` (toque em cada rato), `camera_fix` (segurar 2 s, raio 22, linha de visão no servidor); a porta usa o `door_toggle` que já existe |
| Gate | `InteractionService` gate `Chore`: os prompts da chapa pegando fogo e da estação com rato recusam; o client esconde os mesmos (`PromptController` gate `Chore`) |
| Por quê set | estado de todos; quem entra depois vê o fogo e os ratos sem o aviso (`Rules.Fresh` s) |

### 13.3 `Call` (onda 2)

```lua
Call = Lync.replicate(Lync.struct({          -- registro 1
	Call = Lync.enum(Content.BossCalls.Keys), -- inclui "none"
	State = Lync.enum({ "Idle", "Ringing", "Talking" }),
	StartedAt = Lync.f64(),                   -- início do toque ou da fala; linha = floor((now − StartedAt) / LineTime)
})),
```

| | |
|---|---|
| Escreve / lê | `BossService` / `BossController` (toque, legenda), `HudController`, `AudioController` (ducking) |
| Por quê set (T44) | FEAT-018: quem reconecta no meio ouve só as linhas restantes; o set entrega o estado atual e o client calcula a linha. Packet por linha perderia a ligação na reconexão e mandaria 7–18 pacotes |
| Atender | `Interact{ Action = "answer_phone" }` (âncora `Prompt_Answer`); sem packet novo |
| Ligação do tutorial (Provisório, pedido do usuário 2026-10-11) | linha `call_tutorial` (Trigger `Tutorial`): toca em Prep/Open de dia enquanto `TutorialService:AnyPending()`; no Day 1 substitui `call_day_1`; não atende sozinha; fica `Talking` (StartedAt fixo) até ninguém ter tutorial pendente e então mais `BossCallRules.Tutorial.Goodbye` s. As falas do novato são locais (`TutorialController` → `BossController:Hold/Say` + TTS); quem não está no tutorial ouve as `Lines` da linha. Sem campo novo no set |

### 13.4 `Thief` (onda 2)

> **Removido (DEC-313, 2026-10-20):** o ladrão saiu do jogo e do código (`src/Thief`, `Content.Thief`, `Net.Thief`, UPG-004, notices `thief_*`, ligações "quentin"). Texto abaixo é histórico.

```lua
Thief = Lync.replicate(Lync.struct({         -- registro 1
	State = Lync.enum({ "None", "Lurking", "Approaching", "Opening", "Fleeing" }),
	StartedAt = Lync.f64(),
	Duration = Lync.quant(0, 30, 0.1),        -- Opening: 8 s (16 s com UPG-004)
})),
```

| | |
|---|---|
| Escreve / lê | `ThiefService` / `ThiefController` (barra em `Bar_Thief`, `ProgressBar` por `StartedAt/Duration`) |
| Por quê set | a barra é igual para todos e quem chega no meio precisa dela; o NPC é um rig comum (`NpcId`, aparência por atributo) |

### 13.5 Anomalias (onda 3; DEC-204)

```lua
Anomalies = Lync.replicate(Lync.struct({     -- id = ocorrência 1..255 (cíclico, por noite)
	Anomaly = Lync.enum(Content.Anomalies.Keys),
	Phase = Lync.enum({ "Signal", "Active", "Resolved", "Failed" }),
	StartedAt = Lync.f64(),
	Step = Lync.int(0, 20),                   -- Walker: passo 0..10; Hush: postes apagados; demais 0
	Anchor = Lync.int(0, 65535),              -- NpcId do cliente-anomalia, ou índice de âncora (AnchorId/MapPoint); 0 = nenhum
})),
AnomalyCue = Lync.packet(Lync.struct({       -- s → grupo (todos veem o sinal, DEC-204)
	Anomaly = Lync.enum(Content.Anomalies.Keys),
	Cue = Lync.enum(Content.AnomalyCues.Keys), -- knock, honk, smoke, splash, door_creak, buzz, blackout...
	Entity = Lync.int(0, 65535),
	Seed = Lync.int(0, 65535),
})),
Gaze = Lync.packet(Lync.struct({             -- c → s, só à noite e só Active
	Yaw = Lync.angle(1),
	Pitch = Lync.angle(1),
})):newest(10),
```

| Escolha | Por quê |
|---|---|
| `Anomalies` set | estado que persiste por segundos (janela acesa, Walker no passo 5, relógio parado, long car estacionado): quem reconecta precisa ver pronto (T53) |
| `AnomalyCue` packet | instantes (batida, buzina, fumaça); perder um ao reconectar não muda regra |
| Sem verbo correto na rede | `Content.Anomalies` (shared) não tem verbo nem prazo; ficam em `Rules/` no servidor (T10) |
| `Gaze` `:newest(10)` | só o último olhar importa; 10 Hz bastam para cone de 40° (T7); ~6 B por envio |
| Validação do `Gaze` | só à noite, membro `Active` (v5.2: "não escondido" sai; com a janela fechada o `Looking` filtra no servidor, §19.14); sem verificação de plausibilidade além do formato (co-op, R10) |

Mudança em set existente: `Stations` ganha `Altered = Lync.int(0, 30)` (0 = nada; grelha/tábua: 1 = esta vaga;
trilho: posição 1..`Count` do item alterado). Hot dog montado com ele leva o atributo de Tool `Altered = true` (§7.1).

### 13.6 Janela do trailer (onda 3; **v5.2, DEC-221**: substitui o set `Hides`)

O set `Hides` **sai** (o esconderijo saiu do jogo, DEC-221). Nada novo no `Lync.define`: o estado da janela de
serviço vai como **atributo** no `Model` do veículo.

| Item | Contrato |
|---|---|
| Atributo | `Shutter` (bool) no `Model` com tag `Vehicle` (`false`/ausente = aberta, `true` = fechada) |
| Escreve | só o `VehicleService` (ação `shutter_toggle`, aberturas automáticas, `Swapped`; `architecture.md` §19.14) |
| Lê | `VehicleController` (anima a aba `Awning` em volta do `Shutter_Hinge`, tween local 0,6 s), `PromptController` (`Rules.SetShutterProbe`: esconde "Take Order"/"Serve"/"Refuse" com o veículo atual fechado) |
| Frequência | evento: ≤ 1/s (cooldown 1 s da ação) + 1 por início de turno; ~10 B por mudança |
| Pedido c → s | nenhum novo: `Interact{ Id, Action = "shutter_toggle" }` (enum vem de `Content.Actions`) |
| Aviso | `Notice shutter_closed` (Player) quando o gate recusa uma ação de balcão por corrida |

Por que atributo e não set (T61, **exceção declarada à regra 9 da §1**, como o atributo `Bought` da TASK-056):

| Opção | Por que não |
|---|---|
| set novo `Shutter` | entrada no `Net`, boot do `Lync.start()` e enum para **um** bool de um objeto do mundo |
| campo no `Lights` | o registro é de grupo de luz e o dono é o `LightService`; mistura semântica e dono |
| campo no `Shift` | dois escritores no registro do `RoundService` (mesmo motivo da T52) |
| **atributo `Shutter`** (escolhido) | o client já precisa do `Model` para animar a aba; `StreamingEnabled = false` (T57) garante o atributo em todo client e quem entra no meio recebe pronto; a regra (protegido, gate de venda) roda só no servidor, o client só apresenta |

### 13.7 Cutscene, trânsito e passantes (onda 3)

`Cutscene`, `SkipVote`, `Traffic` e `CarHit` com o schema da §6.2 (sem mudança). Novo:

```lua
Pedestrians = Lync.replicate(Lync.struct({   -- id = slot 1..8
	Path = Lync.int(1, 64),                   -- IndexOf de Content.WalkPaths
	Species = Lync.enum(Content.Species.Keys),
	Outfit = Lync.enum(Content.Outfits.Keys),
	Speed = Lync.quant(4, 12, 0.5),
	AnchorAt = Lync.f64(),
	AnchorDist = Lync.f32(),
	StopDist = Lync.f32(),                    -- parada na faixa esperando reserva (§8.1); 0 = sem parada
	HeldUntil = Lync.f64(),
})),
```

| Escolha | Por quê |
|---|---|
| Mesmo registro 1D do `Traffic` | uma função de posição (`Traffic/shared/Motion.luau`) para carros e passantes; ≤ 3 registros por passante por travessia |
| Aparência no set (exceção à regra 9) | passante não tem modelo no servidor (T46) para levar atributo; `Species`/`Outfit` são chaves de `Content`; o client monta e o `RigController` veste, inclusive o Night local da faixa baixa (DEC-169) |

**Portão de carregamento (Provisório, frontend-coder 2026-10-11, feedback do usuário: o começo de uma cena se perdia
enquanto o client ainda carregava).** `Cutscene` ganha `Waiting = Lync.bool()` (true enquanto o `CutsceneService`
segura a cadeia; `Scene = "none"` nesse meio-tempo) e há um packet novo:

| Entrada | Direção | Schema | Escritor → leitor | Taxa |
|---|---|---|---|---|
| `ClientReady` | packet c → s | `Lync.empty()` | `LoadingController` → `CutsceneService` | 1 por join |
| `CutsceneSnapshot` | packet s → `Audience` / jogador | mesmo struct do record `Cutscene` | `CutsceneService` → `CutsceneController` | a cada escrita do set + resposta ao `ClientReady` |

`CutsceneSnapshot` é fallback (debugger 2026-10-11): o client só o usa enquanto o set `Cutscene` não tem o record 1
(backlog perdido como `drop.unready`; ver README, "Um aviso que nao e teu"). O reparo geral é o
`NetService:Resync(player)` no `Ready`, que reenvia todos os sets àquele jogador.

O `LoadingController` (tela de carregamento: jogo carregado, controllers iniciados, kit da crew, imagens
críticas) manda `ClientReady`; a cadeia só começa quando todo participante conectado mandou, ou
após `Content.Cutscenes.Rules.ReadyTimeout` (30 s). A fase Intro, cujo teto cobria essa espera, foi removida (DEC-309); a regra vale para o finale.
Não é o handshake `Ready` do `NetService`.

### 13.8 Lobby e sessão (onda 4)

> **v5.5 (2026-10-11):** `Parties`/`PartyAction` não foram implementados; valem o set `Party` e os packets do **§16**.

```lua
Parties = Lync.replicate(Lync.struct({       -- id = plataforma (atributo Party), place Lobby
	Owner = Lync.f64(),                       -- UserId do 1º a pisar; 0 = vazia
	Members = Lync.array(Lync.f64(), 0, 4),
	State = Lync.enum({ "Open", "Countdown", "Teleporting" }),
	CountdownEndsAt = Lync.f64(),
})),
PartyAction = Lync.packet(Lync.struct({       -- c → s; entrar e sair = pisar/sair da plataforma (DEC-179)
	Action = Lync.enum({ "Start", "Cancel" }),
	Party = Lync.int(1, 32),
})),
Reconnect = Lync.packet(Lync.struct({         -- s → c (lobby); Seconds: relógio do lobby, não do servidor da run (§1 regra 4)
	Mode = Lync.enum({ "None", "Rejoin", "Resume" }),
	Day = Lync.int(1, 10000),
	Night = Lync.int(0, 10),
	IsNight = Lync.bool(),
	Seconds = Lync.int(0, 960),
})),
ReconnectReply = Lync.packet(Lync.struct({ Accept = Lync.bool() })), -- c → s
```

### 13.9 Ambulância, reviver, bancada (onda 4)

> **Descartado (DEC-314, 2026-10-20):** a ambulância e os médicos não serão feitos; o corpo fica no chão até o reviver ou o fim da noite (`Revive.BodyFallback`). Texto abaixo sobre ambulância é histórico.

`Ambulance`, `Revive` e `Bench` com o schema da §6.2 (sem mudança). `Profile` ganha
`ReviveCredits = Lync.int(0, 99)` (§4.5).

### 13.10 Chaves novas de enum (vêm de `Content`; `content-data.md` §3.18–§3.19)

| Tabela | Chaves novas | Onda |
|---|---|---|
| `Actions` (`Interact.Action`) | `answer_phone`, `shutter_toggle` (v5.2, DEC-221; as demais da onda 2+ já existem: `buy_trailer`, `brew_coffee`, `give_coffee`, `switch_light`, `safe_spot`, `bench_buy_item`). **Saem** `hide` e `get_up` | 2, 3 |
| `Notices` (`Notice.Kind`) | `trailer_available`, `trailer_waiting`, `trailer_bought`, `gems_gained`, `afk_no_gems`, `achievement`, `thief_caught`, `coffee_cooldown`, `coffee_full`, `shutter_closed` (v5.2; sai `hide_taken`), `revive_used`, `revive_credit_saved`, `special_on_bench`, `shift_cant_resume`, `not_in_roster` | 2–4 |

### 13.11 Removidos

| Entrada | Quando | Substituída por |
|---|---|---|
| `Round` (packet legado) | W2-0 | `Shift` |
| `Vitals` legado (Health/Armor/Stamina) | W2-0 (mesmo nome, schema da §13.1) | `Vitals` + `Sanity` |
| `Switches` (v3, nunca implementado) | — | `Lights` |
| `BossCall` (v3, nunca implementado) | — | `Call` |
| `Hides` (set) | v5.2 (DEC-221; TASK-133) | atributo `Shutter` no `Model` do veículo (§13.6) |

Checklist de toda task de contrato: `tools/analyze.ps1` zero erro **e** boot no Studio sem erro de `Lync.start()` (R8).

### 13.12 Orçamento (pior caso: noite, 4 jogadores, Walker e Hush ativos)

| Fonte | Bytes/s por client |
|---|---|
| sets da onda 1 (`Stations`, `Customers`, `Stock`, `Economy`, `Shift`, `Upgrades`, `RunState`) | < 150 |
| `Vitals`, `Sanity`, `LifeEvent` | < 40 |
| `Lights`, `Call`, `Thief`, `Transition`, atributo `Shutter` | < 15 |
| `Anomalies`, `AnomalyCue` | < 40 |
| `Traffic`, `Pedestrians` | < 50 |
| `Gaze` (c → s) | ~60 por jogador |

Total < 0,5 KB/s por client; abaixo da meta da §12.4 do `architecture.md` (≤ 10 KB/s).

## 14. Mesas do Pad e duplas (v5.3, TASK-144; FEAT-037, FEAT-038; Provisório)

Contrato de código: `architecture.md` §19.28. Tabelas: `content-data.md` §3.25. Nenhum packet novo: o toast de compra
usa `Notice` (`table_added`), o "+$N" da limpeza sai do próprio set (`Tip` → 0 e `State` Dirty → Free na mesma
escrita; a gaveta sobe pelo `Economy`).

### 14.1 `Tables` (set, id = índice da mesa 1..`Content.Seating.Tables` = 9: Pad 1..5, Trailer 6..9, `Q-209`)

```lua
Tables = Lync.replicate(Lync.struct({
	State = Lync.enum(Content.Seating.States), -- Locked, Ghost, Free, Occupied, Dirty
	Price = Lync.int(0, 1000),                  -- > 0 só na próxima mesa à venda (Ghost)
	Npc1 = Lync.int(0, 65535),                  -- NpcId dos clientes na mesa (0 = ninguém)
	Npc2 = Lync.int(0, 65535),
	Tip = Lync.int(0, 1000),                    -- $ em cima da mesa (Dirty)
}))
```

| | |
|---|---|
| Escreve | `SeatingService` (único). Registros 1..9 sempre presentes (`add` no `OnStart`, todos `Locked`; o `Refresh` escreve o estado real). **Grupos** (`Content.Seating.Groups`): Pad = 1..5, Trailer = 6..9. Mesa do grupo Trailer fica `Locked` enquanto o veículo não for o trailer e, depois, só a próxima à venda é `Ghost` (as seguintes `Locked`). Back Bar (UPG-010) não tem registro. **Schema inalterado**: 9 registros, mas todo registro carrega campos de 10 e 16 bits (`Price`, `Npc1`, `Npc2`, `Tip`; `State` de 3 bits vai junto), muito acima do 1 byte por registro de keyframe do Lync 4.0.2 (a armadilha do `Upgrades.Level`, 8 bits de propósito, vale para sets com 8+ registros de campos pequenos; `Upgrades` agora tem 9 registros e segue com `Level`/`Wait` de 8 bits) |
| Lê | `SeatingController` (TASK-147): `Locked` = mesa escondida (antes do Day 2, ou mesa do trailer antes de o trailer ser o veículo); `Ghost` = malha a `Seating.GhostTransparency` (a `GhostDimTransparency`, mais fraca, quando `Price > 0` e a party não paga), placa de preço só com `Price > 0` (título do grupo: "Patio Table" / "Trailer Table"); `Free`/`Occupied` = mesa normal; `Dirty` = bandeja + moeda no `Tray_Anchor` (ou no topo da mesa). Limpeza = escrita com `Dirty → Free` e `Tip → 0`: o client mostra "+$N" com o `Tip` anterior. `PromptController` só lê os atributos da âncora |
| Frequência | por evento (compra, sentar, levantar, limpar, fase): < 1/s |
| Colisão | mesa `Locked`/`Ghost` tem `CanCollide = false` escrito **pelo servidor** (replica); a transparência é do client |
| Por que set | estado do mundo que todos veem e quem entra no meio precisa pronto (bandeja, fantasma) |

### 14.2 `Customers` (campos novos, opcionais)

```lua
Order2 = Lync.optional(Lync.bitfield(Content.Ingredients.ToppingKeys)), -- líder de dupla: 2º hot dog pendente
Leader = Lync.optional(Lync.int(1, 65535)),                              -- parceiro: NpcId do líder
```

| | |
|---|---|
| Escrita | `Customers:update` **não limpa** campo opcional passado como `nil` (o `for` do Lync pula chaves nil; só `Lync.none` limpa). `CustomerService:Publish` manda `Order2 = Lync.none` / `Leader = Lync.none` quando nil: sem isso o cliente mantinha o `Order2` antigo ao lado do novo `Order` e o pedido restante aparecia **duplicado** (balão e cartão HUD). Sem mudança de schema |
| `Order2` | só no líder de uma dupla, escrito junto com `Order` no "Take Order" (T41 continua: nada antes). O registro mostra sempre **os itens pendentes**: `Order` = 1º pendente, `Order2` = 2º pendente; ao resolver um, o que sobra vira `Order` e `Order2` vai a `nil` (o balão volta a 1 linha, TASK-148) |
| `Leader` | só no parceiro. O parceiro nunca tem balão nem prompt e seu `State` é só `Arriving` → `Queued` → `Leaving` (`Slot = 0`); o rosto segue o `Mood` do líder (copiado pelo servidor) |
| `Sale` | uma por hot dog; `Npc` = dono da linha (linha 1 = líder, linha 2 = parceiro): a reação aparece sobre quem pediu |
| Cliente sentado | **Q-209 (2026-10-12):** sem campo novo. Esperando a comida na mesa: `State = Waiting`, `Slot = 0`, `Phase = Order` (o balão e a barra de paciência seguem); `Tables[n]` = `Occupied` com `Npc1`/`Npc2`. Servido bem: `Leaving` (come, sem mais prompts). A mesa que ele espera se lê no `Tables` e no atributo `Seated` do rig (§14.3) |

### 14.3 Atributos (sem Lync)

| Onde | Atributo | Escreve | Uso |
|---|---|---|---|
| `Model` da mesa (tag `SeatTable`) | `TableIndex` (1..5) | bind do mapa (TASK-149); no fallback por nome, o `SeatingService` escreve tag e atributo em runtime | client acha a mesa do registro |
| rig do NPC | `Eating` = `true` quando a comida foi servida (Q-209); só com `Seated` | `SeatingService` | `Meal.luau` só põe o hot dog na mão e morde com `Eating`; sentado esperando = mãos vazias |
| rig do NPC | `Seated` = índice da mesa (nil = de pé) | `SeatingService` | client toca `npc_sit`/`npc_eat_seated` quando tiverem Id; sem Id o servidor já dobra quadril/ombro por `Motor6D.C0` (replica) |
| `Motor6D` do rig | `RestC0` (CFrame) | `SeatingService` (`Diner.luau`) | C0 de repouso; `NpcService/Pool` restaura ao devolver o rig ao pool |
| âncora de mesa (`Prompt_Table` runtime, ou `Prompt_BuyTable`/`Prompt_CleanTable` do bind) | `PromptAction` (`buy_in_place` ↔ `clean_table` na âncora única), `PromptEnabled`, `PromptText` ("Buy Table — $30"), `Upgrade` = `patio_tables`, `TableIndex` | `SeatingService` | `PromptController` como qualquer âncora |
| âncora de entrega (`Prompt_Serve` runtime, ou `Prompt_ServeTable` do bind) | `PromptAction = serve_table`, `PromptEnabled` (só com cliente sentado esperando), `PromptText` ("Serve Table 2: Ketchup + Cheese"; dupla `A \| B`), `TableIndex` | `SeatingService` | `PromptController` e o menu de interação (uma linha por mesa) |
| placa do Patio Lights (`Prompt_PatioLights`) | `PromptAction = buy_in_place`, `Upgrade = patio_lights` | bind (TASK-149) + `SeatingService` | idem |

`Interact` ganha `buy_in_place` (hold 1,5, raio 7), `clean_table` (hold 1, raio 7) e `serve_table` (tap, raio 8, mão = hot dog; Q-209: o enum cresce 1 valor, nenhum campo novo; o set `Tables` já tem registro largo, `Customers` não muda) pelo enum de `Content.Actions`;
`Notice` ganha `table_added` (Party, `Value` = índice da mesa). Orçamento: +< 5 B/s por client.

---

## 15. Loja, classe por Robux e códigos (v5.4; TASK-160 a TASK-162; pedido do usuário 2026-10-11, **Provisório**)

Lobby (e Run em modo dev, mesma regra do `ClassAction`). Dados: `data.md` §1.7. Produtos e preços: `Content.Shop`
(`economy.md` §9). Nomes combinados com o frontend.

**Saldo e classes possuídas: reaproveita o `Profile` (§4.5).** O pedido previa um set `Wallet` (Gems, OwnedClasses)
"se não existir algo equivalente". Existe: `Profile` é packet **privado** (`fireClient`), já leva `Gems`, `Classes`
(bitfield das possuídas, Cachorro sempre incluso) e `Selected`, é reenviado a cada mudança do perfil pelo `effect` do
`ProfileService` e no handshake `Ready`. Um set seria pior: `keyBy` não serve para "cada um vê o seu" (README), e
sem `keyBy` todo client veria o saldo de todos. O client lê pelo `ProfileController` (`Gems`, `Classes`, `Selected`).

### 15.1 `ClassBuy` (c → s) / `ClassBuyResult` (s → dono)

```lua
ClassBuy = Lync.packet(Lync.struct({
	Class = Lync.enum(Content.Classes.Keys),
	Currency = Lync.enum({ "Gems", "Robux" }),
})),
ClassBuyResult = Lync.packet(Lync.struct({
	Class = Lync.enum(Content.Classes.Keys),
	Ok = Lync.bool(),
	Reason = Lync.enum({ "Ok", "Prompt", "Granted", "Converted", "Owned", "NotEnoughGems", "NotForSale",
		"Unavailable", "Busy" }),
})),
```

| | |
|---|---|
| Responde | `ClassService` (L+R), taxa ≤ 2/s **somada** ao `ClassAction` |
| `Currency = "Gems"` | compra na hora (`BuyWithGems`, `data.md` §1.7). Resposta `Ok` (+ `Notice class_bought` + `Profile` novo) ou `Owned` / `NotEnoughGems` / `NotForSale` (não `InMvp`) / `Unavailable` (Run fora do modo dev) / `Busy` (taxa ou perfil carregando) |
| `Currency = "Robux"` | **só pré-checagem**, nada é escrito. `Prompt` = classe à venda, com produto criado e não possuída: o client chama `MarketplaceService:PromptProductPurchase(LocalPlayer, Content.Shop.ClassProducts.ByKey[Class].ProductId)`. Senão `Owned` / `NotForSale` / `Unavailable` (`ProductId` 0 = produto ainda não criado) / `Busy` |
| Game Pass (TASK-291, 2026-10-14) | Classe em Robux é **Game Pass** (`Content.Shop.GamePasses`, `PassId`): o client chama `MarketplaceService:PromptGamePassPurchase`; o servidor concede em `PromptGamePassPurchaseFinished` e confere `UserOwnsGamePassAsync` ao entrar. As linhas abaixo sobre `ProductId`/recibo de classe valem só como histórico |
| Recibo de classe | `ShopService` manda `ClassBuyResult{ Ok = true, Reason = "Granted" }` (+ `Notice class_bought`) ou `"Converted"` (já possuía: virou as gemas do preço, + `Notice gems_gained`). Chega **depois** do diálogo do Roblox fechar; pode chegar noutro servidor (recibo reentregue) |
| `Ok` | `true` para `Ok`, `Prompt`, `Granted`, `Converted` |
| Pular a pré-checagem | permitido: o client pode chamar o prompt direto; o servidor valida no recibo do mesmo jeito |
| `ClassAction` Buy | segue valendo (tela "Crew", TASK-020); mesma compra, resposta só por `Notice` |

### 15.2 `CodeRedeem` (c → s) / `CodeRedeemResult` (s → dono)

```lua
CodeRedeem = Lync.packet(Lync.struct({
	Code = Lync.str(0, 32),
})),
CodeRedeemResult = Lync.packet(Lync.struct({
	Ok = Lync.bool(),
	Reason = Lync.enum({ "Ok", "Invalid", "Expired", "Already", "Busy" }),
	Reward = Lync.struct({
		Gems = Lync.int(0, 1000000),
		Class = Lync.optional(Lync.enum(Content.Classes.Keys)),
	}),
})),
```

| | |
|---|---|
| Responde | `CodesService` (L+R). Uma resposta por pedido |
| Normalização | tira todo espaço e põe em maiúsculas (`" hot dog "` = `HOTDOG`). Código com mais de 32 caracteres é recusado pelo Lync (o client limita a caixa a 32) |
| Taxa | 1 tentativa por segundo; depois de 5 respostas `Invalid`/`Expired` em 60 s, tudo vira `Busy` até a janela acabar |
| `Reward` | o que foi creditado: `Gems` (inclui o preço de uma classe já possuída, convertida) e `Class` (nil se não ganhou classe). `{ Gems = 0 }` quando não é `Ok` |
| Também muda | `Profile` (saldo, classes). Sem `Notice`: o feedback é a própria resposta |

### 15.3 Pacotes de gemas (sem packet novo)

O client chama `PromptProductPurchase` com `Content.Shop.GemPacks.ByKey[k].ProductId` (botão escondido/desligado com
id 0). O servidor credita no recibo; o client vê o saldo no `Profile` e o toast `Notice gems_gained` (`Value` = gemas
do pacote). Preço exibido: `MarketplaceService:GetProductInfo(id, Enum.InfoType.Product).PriceInRobux`, com
`Robux` da tabela só como fallback.

Orçamento: eventos raros, por clique; irrelevante.

## 16. Squad (party) no lobby e volta ao lobby (v5.5, TASK-154 a TASK-156; `architecture.md` §20; Provisório)

Pedido do usuário (2026-10-11). Substitui, para o que foi implementado, o §13.8 (`Parties`/`PartyAction` por
plataforma): os nomes abaixo foram combinados com o frontend. `Reconnect`/`ReconnectReply` (§13.8) seguem só plano.
Papel do servidor **não passa pelo Lync**: atributo `ReplicatedStorage.ServerRole` (`"Lobby"`, `"Game"`,
`"PrivateLobby"`), lido no client por `PlaceController:GetServerRole()`.

Regras comuns: UserId viaja como `f64` (exato até 2^53). Todo pacote c → s de squad soma na taxa de
`PartyRules.Rules.RateMax` (8) por segundo por jogador; o excedente é descartado e o 1º excedente recebe `TooFast`.
Fora de um papel de lobby, todo pacote de squad responde `PartyNotice{ Key = "WrongServer" }`. Constantes e chaves:
`ReplicatedStorage.shared.Party.PartyRules` (`Rules`, `NoticeKeys`).

### 16.1 `Party` (set, id = `PartyId` 1..65535)

```lua
Party = Lync.replicate(Lync.struct({
	Leader = Lync.f64(),
	Members = Lync.array(Lync.f64(), 1, 4), -- ordem da squad, líder primeiro
	Ready = Lync.map(Lync.f64(), Lync.bool(), 0, 4), -- todo membro; o líder sempre true
	State = Lync.enum({ "Forming", "Configuring", "Starting" }),
	Platform = Lync.int(0, 4), -- §16.6: LOBBY-SQUAD-n da squad; 0 = squad de convite
	Access = Lync.enum(PartyRules.Access), -- §16.9 (era FriendsOnly, §16.6)
	MaxPlayers = Lync.int(1, 4), -- §16.6
	StartAt = Lync.f64(), -- §16.6: workspace:GetServerTimeNow() do teleporte; 0 = sem contagem
})),
```

| | |
|---|---|
| Escreve | `PartyService` (só no lobby), único escritor |
| Audiência | todos no lobby (sem `keyBy`); o client acha a própria squad procurando o seu UserId em `Members` |
| Vida | `add` ao criar; `update` (registro inteiro) a cada mudança; `remove` quando fica vazia. Não existe no `Game` |
| `State` | `Forming` = squad de convite montando; `Configuring` = squad de plataforma montando (§16.6); `Starting` = contagem (`StartAt`) e depois reserva/teleporte (nada muda até acabar, só sair; falha volta ao estado de antes) |

### 16.2 Pedidos (c → s; responde `PartyService`)

| Packet | Payload | Validação no servidor | Resposta |
|---|---|---|---|
| `PartyCreate` | — | fora de squad | set + `Created` / `AlreadyInParty` |
| `PartyInvite` | `{ UserId }` | líder (sem squad: cria e vira líder), alvo no servidor, não é ele mesmo, fora da squad, não `Starting`, vaga (`MaxPlayers`), 3 s por alvo | `PartyInviteReceived` ao alvo + `InviteSent{UserId}` / `InviteSelf`, `PlayerNotFound`, `NotLeader`, `Busy`, `AlreadyInParty{UserId}`, `PartyFull`, `TooFast` |
| `PartyRespond` | `{ PartyId, Accept }` | convite existe e não expirou (60 s), squad existe e `Forming`, vaga; a squad atual (se houver) está `Forming` | aceito: set + `Joined{UserId}` à squad; recusado: `InviteDeclined{UserId}` ao líder; `InviteExpired`, `PartyFull`, `Busy` |
| `PartyLeave` | — | está numa squad (vale até em `Starting`) | set + `Left{UserId}` aos que ficam (+ `NewLeader{UserId}` se era o líder) / `NotInParty` |
| `PartyKick` | `{ UserId }` | líder, `Forming`, alvo é membro e não é ele | `Kicked` ao alvo + `Left{UserId}` à squad / `NotLeader`, `Busy`, `PlayerNotFound` |
| ~~`PartyReady`~~ | — | **removido** (DEC-344, TASK-618): não há mais passo de pronto; o campo `Ready` saiu do record `Party` | — |
| `PartyStart` | — | líder, `Forming`/`Configuring`, com quem estiver na squad (sozinho vale, DEC-344) | set `Starting` + `StartAt` + `Starting` à squad → `Rules.Countdown` s (5) depois, teleporte (`TeleportRetry` a cada nova tentativa; `TeleportFailed` se todas falharem); no Studio a contagem roda e termina em `StudioNoTeleport` (volta ao estado de antes) / `NotLeader`, `Busy` |
| `PartyConfigure` | `{ Access, MaxPlayers }` | líder, não `Starting`; `Access` ∈ `Open`/`Friends`/`Invite`/`Closed` (sem `Setup`, DEC-344); `MaxPlayers` preso a `[max(#Members, 1), 4]` | set + `Configured` aos outros membros / `NotInParty`, `NotLeader`, `Busy` |
| `PartyCancel` | — | líder, `Starting`, antes de `StartAt - Rules.CancelCutoff` (§16.8) | set volta ao estado ocioso (solo: some) + `StartCancelled{UserId = líder}` aos outros / `NotLeader`, `NotInParty`, `CancelTooLate` |
| `PartyQuickPlay` | `{ Mode }` (`"Solo"`/`"Squad"`) | fora de squad (§16.7) | `Solo`: set (`Platform 0`, `MaxPlayers 1`) já em `Starting` + `Starting`; `Squad`: set `Forming` + `Created` / `AlreadyInParty` |

### 16.3 Avisos (s → jogador)

```lua
PartyInviteReceived = Lync.packet(Lync.struct({ From = Lync.f64(), PartyId = Lync.int(1, 65535) })),
PartyNotice = Lync.packet(Lync.struct({
	Key = Lync.enum(PartyRules.NoticeKeys),
	UserId = Lync.optional(Lync.f64()), -- o outro jogador, quando o aviso nomeia alguém
})),
```

`PartyNotice.Key` (o client é dono dos textos): `Created`, `AlreadyInParty`, `NotInParty`, `NotLeader`, `PartyFull`,
`PlayerNotFound`, `InviteSelf`, `InviteSent`, `InviteExpired`, `InviteDeclined`, `Joined`, `Left`, `Kicked`,
`NewLeader`, `NotAllReady`, `Busy`, `TooFast`, `Starting`, `TeleportRetry`, `TeleportFailed`, `StudioNoTeleport`,
`ReturningToLobby`, `ReturnFailed`, `WrongServer`, `FriendsOnly` (§16.6: plataforma só de amigos recusou), `Configured`
(§16.6: o líder mudou as opções), `StartCancelled` (§16.8: o líder cancelou a contagem), `CancelTooLate` (§16.8:
cancelou tarde demais). **Acréscimo ao combinado**: o campo opcional `UserId` (o frontend
pode ignorar).

### 16.4 `LobbyReturn` (c → s, papel `Game`; responde `PartyRunService`) — **entrada nova**

```lua
LobbyReturn = Lync.packet(Lync.empty()),
```

Botão "Back to lobby" (tela de fim de run; aceito também no meio da run, DEC-067). 1 por 2 s por jogador. Resposta:
`ReturningToLobby` e teleporte para um servidor público da place; `ReturnFailed` depois de 3 tentativas;
`StudioNoTeleport` no Studio; `WrongServer` fora de servidor reservado `Game`. No `RunEnded` o servidor manda todos
sozinho depois de 12 s (cada um recebe `ReturningToLobby`).

### 16.5 TeleportData (não é Lync; escrito só pelo `PartyService`)

```lua
{ Role = "Game", PartyId = number, Members = { UserId }, Leader = UserId }
```

Lido no servidor reservado por `RoleService` (`player:GetJoinData().TeleportData` do 1º jogador, validado por
`Roles.ParseLaunch`). Não é autorização: só servidores do jogo têm o código do reservado.

Orçamento: eventos por clique e um set de ≤ 4 UserIds por squad; irrelevante.

### 16.6 Plataformas de squad (v5.6, pedido do usuário 2026-10-11; **Provisório**; emenda a DEC-179 de volta às plataformas, convite mantido)

As 4 plataformas do lobby (`Content.Lobby.Zones`, `Platform` 1..4, centro = `MapPoint` `LOBBY-SQUAD-n`, raio 4) são
**detectadas no servidor**: o `PartyService` lê o `HumanoidRootPart` de cada jogador a cada `Content.Lobby.Squad.Poll`
(0,15 s) com histerese (`shared.Lobby.LobbyZones`: entra a ≤ raio, sai a > raio + 1,25, |dy| ≤ 8). Nada disso passa
pelo Lync: o client só vê o resultado no set `Party`.

| Evento | Regra |
|---|---|
| Pisa numa plataforma livre | squad nova com `Platform = n`, `State = "Configuring"`, ele lidera (`Created`). Líder de squad de convite (`Platform 0`) leva a squad para a plataforma |
| Pisa numa plataforma com squad | entra se a squad não está `Starting`, tem vaga (`#Members < MaxPlayers`) e, com `FriendsOnly`, ele é amigo do líder (`Player:IsFriendsWith`, fora do loop: rende; tudo é conferido de novo depois). Membro de plataforma entra **pronto** (`Ready = true`). Recusa = `Busy` / `PartyFull` / `FriendsOnly`, uma vez; não tenta de novo até ele sair da plataforma |
| Sai da plataforma (ou morre) | sai da squad (`Left`; líder → `NewLeader`); squad vazia some e a plataforma fica livre (quem ainda estiver em cima é tentado de novo). Depois que o teleporte começou, sair não tira ninguém |
| Sai pelo botão / é expulso em cima da plataforma | não volta sozinho até sair e pisar de novo |
| `PartyConfigure` | só o líder, fora de `Starting` (tabela do §16.2) |
| `PartyStart` | igual a toda squad: contagem de `Rules.Countdown` s com `StartAt`, depois teleporte (§16.2) |

Cores no client (anéis, `Content.Lobby.Squad.Colors`): sem squad = **branco**; com squad (`Forming`/`Configuring`,
alguém configurando) = **vermelho**; `Starting` = **verde**. A tela da plataforma (`SquadSetup`) mostra a squad da
plataforma em que o jogador está; contagem = `StartAt - workspace:GetServerTimeNow()`.

```lua
PartyConfigure = Lync.packet(Lync.struct({
	Access = Lync.enum(PartyRules.Access), -- §16.9 (era FriendsOnly)
	MaxPlayers = Lync.int(1, 4),
})),
```

Orçamento: o set `Party` ganha 4 campos pequenos por squad; a detecção é só no servidor (≤ N jogadores × 4 círculos a
6–7 Hz). Irrelevante.

### 16.7 Play com escolha: `PartyQuickPlay` (v5.7, pedido do usuário 2026-10-11; **Provisório**)

O botão Play do lobby, fora de squad, abre a escolha **Play Solo** / **Create Squad** (`PlayChoice`). Em squad, o Play
abre a janela de configuração da própria squad (`SquadSetup`: Start do líder, Ready dos membros de squad de convite).

```lua
PartyQuickPlay = Lync.packet(Lync.struct({
	Mode = Lync.enum({ "Solo", "Squad" }),
})),
```

| Mode | Servidor (`PartyService:HandleQuickPlay`) |
|---|---|
| `Solo` | squad nova sem plataforma (`Platform 0`, `MaxPlayers 1`), já em `Starting` com `StartAt` (mesma contagem de `Rules.Countdown` s e mesmo teleporte do `PartyStart`). Aviso `Starting` (sem `Created`). Ao voltar ao estado ocioso (Studio → `StudioNoTeleport`; todas as tentativas falharam → `TeleportFailed`) a squad é **desfeita** em vez de ficar `Forming`: o Play volta a oferecer a escolha |
| `Squad` | squad de convite aberta (`Platform 0`, `State "Forming"`, opções padrão) + `Created`. O client abre a configuração (Friends only, Max players, Invite players, Leave, Start) sem andar até plataforma; convites como no §16.2; o líder ainda pode levá-la a uma plataforma livre pisando nela (§16.6) |

Validação: rate e papel comuns (§16); já em squad = `AlreadyInParty`. `Solo` é campo só do servidor (não viaja no set).
Client: botões ficam desligados até o registro da squad chegar no set (ou 6 s / `AlreadyInParty` / `TooFast` /
`WrongServer`). Orçamento: um evento por clique.

### 16.8 Cancelar a contagem: `PartyCancel` (v5.8, pedido do usuário 2026-10-12; **Provisório**, Q-217)

Durante `Starting` (contagem de `Rules.Countdown` = 5 s do Start de squad ou do Play Solo) o botão Play do lobby vira
**CANCEL** (mostarda escura, tecla X / X do gamepad; na janela `SquadSetup` há um botão Cancel).

```lua
PartyCancel = Lync.packet(Lync.empty()), -- c -> s (pad rooms: no-op, DEC-347)
-- DEC-347 (2026-10-21, Provisório): barra do pad. StartNow / FriendsOnly = líder; SkipTutorial = cada membro. Party ganha
-- Skip = Lync.map(f64, bool, 0, 4); TeleportData ganha SkipTutorial = { UserId } (TutorialService fecha o tutorial dele)
PartyPad = Lync.packet(Lync.struct({ Action = Lync.enum({ "StartNow", "SkipTutorial", "FriendsOnly" }), On = Lync.bool() }))
```

Servidor (`PartyService:HandleCancel`): rate e papel comuns (§16); sem squad = `NotInParty`; não líder = `NotLeader`;
`State ~= "Starting"` = ignorado (idempotente); `Launched` ou `GetServerTimeNow() >= StartAt - Rules.CancelCutoff`
(0,5 s) = `CancelTooLate` ao líder, nada muda. Aceito: `Token` da squad sobe (a thread da contagem de `Begin` só dispara
se o `Token` ainda for o seu, então não há corrida com `Fire`/`ReserveServer`/`TeleportAsync`), `StartAt = 0`, estado
volta ao ocioso (`Forming`/`Configuring`; os Ready dos membros ficam como estavam) e o set é publicado; squad Solo é
desfeita (o Play oferece a escolha de novo). Os outros membros recebem `StartCancelled{UserId = líder}` ("Leader
cancelled"). **Client**: o botão só existe para o líder enquanto `StartAt - agora > CancelCutoff + 0,1 s`; depois
volta a "STARTING...". Orçamento: um evento por clique.

### 16.9 Sala em dois estágios e plataformas sem capacidade fixa (v5.8, pedido do usuário 2026-10-12; **Provisório**, Q-217)

> **DEC-344 (2026-10-20, TASK-618/619) — supera a parte "dois estágios" e o pronto:** pisar no pad (ou o **Create
> Squad** do Play) cria a sala já existente com `Access = "Friends"`; não há mais `Setup` (saiu do enum
> `PartyRules.Access`), nem `Create Room`, nem `PartyReady`, nem as notices `SetupFirst`/`NotAllReady`. O líder tem só
> **START** no HUD (inicia sozinho ou com quem estiver; contagem de 5 s cancelável); o acesso e o tamanho ficam na
> engrenagem ao lado (`SquadSetup`). Pisar no pad não abre janela. Sair do pad = sair da sala. O rastreio `Configured`
> (funil "squad" do `MetricsService`) passa a disparar logo depois de `Created`, com o `Access` inicial. O resto desta
> seção vale só como histórico.

Cada plataforma (e o **Create Squad** do Play) cria a sala **privada** e o líder a monta em dois estágios no
`SquadSetup`; o servidor só guarda o resultado. **Nenhuma plataforma tem capacidade própria**: o tamanho é o `MaxPlayers`
(1..4, `Rules.MaxSize`, DEC-012) que o líder escolhe na criação.

```lua
Access = Lync.enum(PartyRules.Access), -- { "Setup", "Open", "Friends", "Invite", "Closed" } (set Party e PartyConfigure)
```

| `Access` | Quem entra | Start |
|---|---|---|
| `Setup` | **ninguém** (sala privada; plataforma recusa `RoomClosed`, convite `SetupFirst` ao líder) | recusado (`SetupFirst`) |
| `Open` | qualquer um pisando na plataforma ou por convite, até `MaxPlayers` | sim |
| `Friends` | amigos do líder (`IsFriendsWith`) na plataforma; convite do líder vale | sim |
| `Invite` | só por convite (plataforma recusa `InviteOnly`) | sim |
| `Closed` | ninguém (`RoomClosed`; squad de 1 do Play Solo é `Closed`) | sim |

Estágios (client, locais): **1** "How many players?" (botões 1–4; `1` = sala fechada de um só: `PartyConfigure
{ Access = "Closed", MaxPlayers = 1 }` e vai direto ao estágio 3) → `PartyConfigure { Access = "Setup", MaxPlayers = n }`
e **2** "Who can join?" (Open / Friends only / Invite only / Closed; Back volta ao 1) → `PartyConfigure { Access = escolha,
MaxPlayers }`: **só aí** a sala sai de `Setup` e os outros podem entrar. **3** = a sala (líder: Who can join com ciclo,
Max players −/+, Start, Cancel; membros: leitura). Squads criadas por `PartyCreate`/`PartyInvite` nascem `Invite`
(convite imediato, como antes); `PartyQuickPlay "Squad"` e as plataformas nascem `Setup`; `"Solo"` nasce `Closed`.

Servidor (`PartyService`): `HandleConfigure` (líder, não `Starting`) clampa `MaxPlayers` a `[max(#Members,1), 4]` e recusa
`Setup` com mais de um membro (mantém o `Access` atual); `Join` pela plataforma e `HandleRespond` rechecam o `Access`;
`PartyStart` em `Setup` = `SetupFirst`. Avisos novos: `SetupFirst`, `RoomClosed`, `InviteOnly`.

Placa da plataforma (`PadTag`): **FREE** (livre) / **CONFIGURING** (`Setup`) / **OPEN n/máx** (+ **FRIENDS ONLY**,
**INVITE ONLY**) / **CLOSED** (`Closed` ou lotada: **FULL**) / **STARTING IN n...**; o "n/máx" só aparece quando a sala
tem tamanho. Orçamento: o campo `Access` é um enum de 3 bits dentro de um registro largo (ids `f64`), então não há risco do
`drop.section` do README (set pequeno, poucos registros).


## 17. Preparo 3D (TASK-194; `prep-3d.md` §7, §15; Provisório)

Nenhum pacote novo. Três mudanças de schema, todas **aditivas** (campos `optional`; o cliente e o servidor 2D de hoje compilam e codificam sem mudar):

| # | Onde | Campo | Regra |
|---|---|---|---|
| N1 | `PrepGrill` | (nenhum campo novo) | `Place` com `Slot` 1..8 = **preferência** (livre: usa; ocupado: o primeiro livre); `Slot 0` = como hoje. Servidor: TASK-195 |
| N2 | set `Stations` | `Flip = optional(int(0, 101))` | só vaga de grelha: nota do virar + 1 (1..101); nil/0 = não virada. Escreve `Grill.Flip`; zera no `Collect` e no `Place`. O set tem 8+ registros: o campo cabe em 7 bits (101 < 128), então o piso de `drop.section` do README não se aplica |
| N3 | `PrepTab` e set `PrepSeats` | `Plate = optional(int(0, 255))` | máscara **cosmética** do prato aberto (`Content.Prep.PlateMask`, `Prep/shared/PlateMask.luau`): bit 0 pão cortado, bit 1 salsicha posta, bits 2..7 os toppings na ordem de `Ingredients.ToppingKeys`. Servidor: só cresce, <= `MaxToppings` bits de topping, nenhum bit sem chave (`PlateMask.Valid`), zera no Begin/Finish/Trash/Leave; ignora sem erro o que violar. `PrepSeats` <= 4 registros |

Enum de aba: `PrepTab.Step` e `PrepSeats.Step` usam `Content.Prep.WireTabs` (união dos conjuntos 2D `Order, Grill, Build, Serve` e 3D `Grill, Board, Toppings, Serve`); o servidor só aceita o conjunto ativo (`Content.Prep.Tabs`, definido por `Rules.ThreeD`) e `Content.Prep.TabAlias` traduz a chave do outro modo (inclusive o atributo `PromptStep` do mapa).

Tráfego: `PrepTab` ainda <= 4/s por jogador e só quando algo muda (+1 byte opcional); `Stations.Flip` = 1 escrita por virada; `PrepSeats.Plate` ~1 escrita/s no total. Mão fantasma (`PrepHand`, Q-233) **não** existe: fica atrás de `Rules.World.GhostHand = false`.

## 18. Jogadores online (TASK-312; pedido do dono 2026-10-15, **Provisório**)

Set `Online`, registro **1**, só em papéis de lobby (`Lobby`, `PrivateLobby`). Escritor: `PresenceService`
(`src/Presence/server`). Leitor: `LobbyController` → `LobbyHud.Online` (pílula no topo central, "200 players online").

| Campo | Tipo | Regra |
|---|---|---|
| `Count` | `int(0, 16777215)` | jogadores online na experiência inteira (lobbies, lobbies privados e runs); nunca abaixo da contagem local do servidor |

Fonte (não é Lync): MemoryStore HashMap `Online_v1`. Todo servidor grava `JobId → #Players` a cada 30 s (expira em 90 s;
`RemoveAsync` no `BindToClose`). Um lobby por vez pega a lease (`_lease`, `UpdateAsync`, 50 s), lista o mapa e grava
`_total = { Count, At }` a cada 60 s; os demais lobbies só leem `_total` a cada 30 s. Custo ≈ 2 req/min por servidor
+ 2 por lobby + servidores/200 páginas por minuto, muito abaixo da cota (1000 + 100 × usuários). Studio ou erro do
MemoryStore: só a contagem local. Tráfego: `update` só quando o número muda (no máximo a cada 30 s, mais entradas/saídas
locais). Um registro de 24 bits: sem o piso de `drop.section` do README.

## 19. Cozinha com esteira (v5.9, TASK-512; DEC-302, DEC-303, DEC-304; **Provisório**)

Contrato completo, regras de jogo e assinaturas entre serviços: `prep-conveyor.md`. Vale só com
`Content.Prep.Rules.Mode = "Conveyor"` (restaurante ligado, §1 de `prep-conveyor.md`); no modo `"Trailer"` nenhuma entrada
abaixo é escrita e as mudanças de schema são **aditivas** (campos `optional`), então o trailer compila e codifica como hoje.
Grava tudo: **TASK-513** (único dono de `Net/*` nesta rodada). Sem `keyBy`. Enums vêm de `Content.Prep` (Lync ordena os nomes).

### 19.1 Entradas novas e mudadas

| Entrada | Arquivo | Tipo / direção | Schema | Escritor | Leitor | Ritmo | Por quê |
|---|---|---|---|---|---|---|---|
| `PrepBelt` | `Net/init.luau` | packet c → s | `{ Dir = enum(Content.Prep.BeltDirs) }` (`Left`, `Right`) | `PrepController` (setas: teclado, toque, gamepad) | `PrepService` (responder no `OnInit`) | ≤ `Conveyor.Rates.Belt` = 6/s por jogador | pedido de mover **o próprio** prato uma parada; sem campo de alvo, então não há como mover o prato de outro. Evento: packet |
| `PrepStage` | `Net/init.luau` | packet c → s | `{ Stage = enum(Content.Prep.BeltStages), Score = int(0, 100), Slot = int(0, 8) }` (`Cut`: `Slot` 0; `Dog`: `Slot` = posição 1..8 do descanso) | `PrepController` (fim do gesto de cortar / de arrastar a salsicha) | `PrepService` | ≤ `Conveyor.Rates.Stage` = 2/s | commit de uma etapa no prato (pão do estoque, salsicha do descanso); tudo ou nada; resposta em `PrepResult Act = Stage` |
| `PrepResult` | `Net/init.luau` | packet s → dono | sem mudança de schema; `Act` + `Belt`, `Stage`; `Reason` + `NoPlate`, `BeltFull`, `GrillBusy`, `WrongStop`, `PlateDone` | `PrepService` | `PrepController` | 1 por pedido | `Belt`: `Ok = true` e `Value` = parada nova 1..4 (se o prato ficou esperando ao lado, o cliente vê `Wait` 1 ou 2 no `PrepSeats`); `Stage`: `Value` = nota aceita |
| `PrepSeats` | `Net/init.luau` | set, id = assento 1..4 | **+** `Stop = optional(int(0, 15))`, `Wait = optional(int(0, 2))` (0 = na parada, 1 = esperando à esquerda `WaitL_n`, 2 = à direita `WaitR_n`), `Line = optional(int(0, 2))`, `Away = optional(bool)` (true = o dono saiu e o prato está parado e reservado na esteira; o assento continua dele). `Ticket` passa a ser o NpcId do ticket **do prato** na esteira; `Step` = aba da parada; `Plate` = máscara do conteúdo (bits de pão/salsicha escritos pelo servidor no commit) | `PrepService` | `PrepController` (`Mates`, `World/BeltMates`, StationTag, ticket do foco), `MetricsService` | 1 escrita por seta aceita, por commit, por promoção e por sair/voltar (`Away`); pior caso ≈ 12/s no set, típico < 1/s | todos veem o prato de cada montador andar e quem chega tarde recebe o estado. **3 registros** no modo esteira (1–2 esteira, 3 grelha), 4 no trailer: sem `drop.section` (< 8 registros; `User`/`Since` `f64`) |
| `Plates` | `Net/Restaurant.luau` | set, id = vaga 1..`CenterTable.Slots` (8; fio 1..12) | **+** `Grade = optional(enum(Content.Prep.GradeKeys))` (nil = não montado). Os campos de hoje (`Npc`, `Line`, `Bun`, `Sausage`, `Toppings`, `Since`, `Orphan`, `Altered`) passam a descrever o prato **na vaga da mesa central** | `PlateService` | `PlateController` (grid, ticket na vaga), `OrderBoardController`, `TutorialController` | por pedido: nascer, pegar, pôr, órfão (~4 escritas por pedido) | estado compartilhado da mesa central; 8 registros largos (`Npc` 16 bits, `Since` `f64`): sem `drop.section` |
| `CenterPut` | `Net/Restaurant.luau` | packet c → s | `{ Slot = int(1, 12) }` | `PlateController` (clique/toque na vaga livre; gamepad: vaga livre mais perto) | `PlateService` (responder no `OnInit`; primeiro packet do namespace "restaurant") | ≤ `CenterTable.PutRate` = 4/s | pôr o prato equipado numa vaga; a vaga é escolhida no clique, que não é ProximityPrompt. Recusa por `Notice` (`slot_taken`), como o resto do `PlateService` |

### 19.2 Sem mudança de schema, com regra nova no modo esteira

| Entrada | Regra no modo esteira |
|---|---|
| `PrepEnter` | `Station` é o assento pedido (1–2 esteira exige prato não montado na mão ou prato parado; 3 = grelha). O caminho normal são os prompts: `prep_work` (`Prompt_Work`) → esteira, `prep_grill` (`Prompt_Grill`) → grelha |
| `PrepLeave` | prato fora de `Out`: fica parado na esteira (`Away = true`, reserva mantida); prato em `Out`: volta à mão, a parada libera e promove quem esperava |
| `PrepTab` | segue como batimento e máscara de toppings; o servidor ignora a troca de aba (a aba vem da parada) |
| `PrepGrill` | aceito só do assento 3 (grelha); sem pausa de virar, sem queima; pronta em 8/6/4 s |
| `PrepFinish` | só na parada 3; `Cut` e `Place` do resumo são ignorados (o servidor usa os que gravou no `PrepStage`); não cria Tool |
| `PrepTrash` | `From = Plate` esvazia o prato na esteira e mantém o ticket |
| `PrepGrab` / `PrepClaims` | `From = Rail` = mesa de descanso (8 posições) |
| `PrepPointer` / `PrepGhost` | sem mudança (`Station` = assento) |
| `PrepBegin`, `PrepOrder` | sem uso: recusa `Invalid` / `Locked` |
| `Stations` | grelha: `Burnt` nunca escrito; `Flip` segue sendo a nota do virar; rail: `Count` = salsichas no descanso |
| `Customers` | sem mudança; `Number` é o #n do ticket no HUD e na vaga |
| `Interact` | ação nova `prep_grill` (entra na grelha; o enum `Action` cresce com `Content.Actions.Keys`, sem campo novo); `plate_take` (segurar 0,5 s, vaga da mesa central) e `pickup_serve` (segurar 0,5 s) |

### 19.3 Atributos de Tool novos (sem Lync; completa o §7.1)

Item novo `plate` (prato não montado). Atributos escritos pelo `PlateService`: `PlateId` (int), `Ticket` (NpcId; já
existia no `hot_dog`), `TicketLine` (1..2), `Orphan` (bool), `Bun` e `Dog` (bool, só `plate`), `FlipBonus` (bool). A nota do
prato montado é o atributo **`Quality`** que já existe. Notas de etapa e relógio do prato ficam só no servidor.

### 19.4 Orçamento e tipos

Tráfego novo por jogador < 2 pacotes/s em ritmo normal (setas e etapas); sets: `PrepSeats` ~1 byte por escrita,
`Plates` sem mudança de ordem de grandeza. Os structs novos são montados fora da tabela do `define` (funções locais, como
`cutsceneRecord`) por causa do orçamento do LuauSolverV2 no namespace "game"; se ainda estourar, `PrepBelt` e `PrepStage`
vão para um namespace próprio `Net/Belt.luau` requerido pelo `init.luau` (como `Net/Restaurant.luau`), decisão registrada
pela TASK-513 (`prep-conveyor.md` P23).
