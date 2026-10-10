Status: Rascunho

# Contratos de rede (Lync)

Autor: architect. Versão 3.1, 2026-10-08 (conciliação com DEC-106 a DEC-130, rodada 17 e `consistency-report.md` §5;
`Traffic` alinhado à **DEC-133**, lado técnico de `Q-131`).
Tudo aqui vira entrada em `src/Libs/Net/init.luau` (um `Lync.define("game", {...})`, requerido pelos dois lados).
Mudança neste arquivo passa pelo architect (`PIPELINE.md`, ponto de conflito). Arquitetura: `architecture.md`.
Tabelas que geram os enums: `content-data.md`.

---

## 0. O que mudou

### 0.0 Versão 3.1 (DEC-130, rodada 17)

| Entrada | Mudança | Origem |
|---|---|---|
| `Traffic` | `Route` cobre `TR-1..TR-10` (cabe em `int(1, 32)`); teto de slots continua 8. **DEC-133**: `StartedAt` sai; entram `AnchorAt`, `AnchorDist`, `StopDist`, `HeldUntil` (carro para no PARE e na faixa reservada por NPC); registro muda por evento, não só no nascimento | `MAP-01.md` revisão 3, DEC-133 |
| Semáforo | **removido** (não tinha rede; sai também o atributo `Workspace.RunEpoch`) | DEC-130 (revoga DEC-120) |
| Reserva de faixa / caixa do PARE | sem rede: `NpcService` → `TrafficService` no servidor; o client só vê o efeito (carro parado no registro `Traffic`, NPC andando) | `architecture.md` §8.1, T30, DEC-133 |
| Nenhuma entrada nova em `src/Libs/Net/init.luau` | só o schema de `Traffic` muda | — |

### 0.1 Versão 3

| Entrada | Mudança | Origem |
|---|---|---|
| `Shift` | + `WipeFrozen` (contador parado com prompt de compra aberto); `Chances` começa em 1 | DEC-118, DEC-110 |
| `Vitals` | `StateEndsAt` de Down = 6:00 AM da noite da queda | DEC-115 |
| `RunState` | `Joined` sai; entra `PriceParty` (fixado no fim do Day 1) | DEC-121 |
| `Bench` | 1 vaga especial; preço já multiplicado por `PriceParty` | DEC-106, DEC-129 |
| `Traffic` | sem `Speed` (perfil de velocidade da tabela por trecho) | FEAT-033 |
| `Ambulance` | **registro único** (uma ambulância por servidor), viagens `Pickup`/`Return`/`Dawn`, lista de corpos na parada | DEC-114, DEC-122, FEAT-034 |
| `Revive` | Robux e crédito: `Target` tem de ser o remetente | DEC-116 |
| `Interact` | item no chão usa `pick_up_item` ("Pick Up") | FEAT-036 |

### 0.2 Versão 2

| Entrada | Mudança | Origem |
|---|---|---|
| `Vitals` | `State` ganha `Down`, `Reviving`, `Spectator`; novos `StateEndsAt`, `KnockedUntil` | DEC-091, DEC-093, DEC-095 |
| `Shift` | novos `WipeEndsAt`, `Attempt`, fase `Resume`; `Chances` mantido | DEC-080, DEC-094, DEC-102 |
| `Upgrades` | sem prompt no equipamento; lido pela bancada | DEC-101 |
| `RunState` | **novo** set (registro único): `Joined`, contadores | DEC-098, `Q-112` |
| `Bench` | **novo** set: slots especiais sorteados por turno | DEC-100, DEC-101, DEC-106 |
| `Traffic` | **novo** set: agenda de carros | DEC-087 |
| `Ambulance` | **novo** set: timeline por jogador caído | DEC-091 |
| `Cutscene` | packet vira **set** (votos, entrada no meio) | DEC-078, DEC-088, DEC-098 |
| `KnockOut` | **removido**; vira `LifeEvent` | DEC-091 |
| `CarHit`, `Revive`, `SkipVote` | **novos** packets c → s | DEC-095, DEC-092, DEC-078 |
| `Profile` | + `EndlessDays`, `ReviveCredits` | DEC-084, §10.2 de `architecture.md` |
| `Reconnect` | + `Mode` (Live/Suspended), segundos restantes | DEC-080 |
| `ShiftReport` | `Gems` passa a ser "já creditado neste turno"; + `AfkLocked` | DEC-083, DEC-104 |

## 1. Regras

1. **Set** (`Lync.replicate`) para estado que a party vê e que quem chega/reconecta precisa receber pronto.
   **Packet** para evento ou dado privado.
2. **Sem `keyBy` no MVP.** O servidor da run tem uma party só; no lobby o único set (`Parties`) é público.
3. **Enums gerados das tabelas de conteúdo** (`Lync.enum(Content.X.Keys)`). Ordem da lista = índice no fio.
   Nada persistido usa o índice (perfil, MemoryStore e snapshot guardam a chave string).
4. **Tempo em tempo de servidor.** Campos `*At` são `f64` de `workspace:GetServerTimeNow()`; o client interpola.
   Exceção: `Reconnect.Seconds` (o lobby não compartilha relógio com a run; manda a duração restante).
5. **IDs de registro.** `UserId` para jogadores (`Vitals`, `Ambulance`), `EntityId` (1–65535) para estações e NPCs,
   índice da tabela para estoque e upgrades, slot (1–8) para `Traffic` e `Bench`, `1` para registro único.
6. **Packets s → c vão para `NetService.Audience`**, nunca `Lync.all`, e só com `NetService:IsRunning()`.
7. **Responder só em Service/Controller, no `OnInit`.**
8. **Todo packet c → s é validado**: membro no estado certo, taxa máxima, alvo existe, distância/plausibilidade.

## 2. Mudanças no que já existe em `src/Libs/Net/init.luau`

| Entrada atual | Vira | Motivo |
|---|---|---|
| `Profile` (Coins, Level, Playtime) | `Profile` (§6) | Template novo (`data.md` §1); sem XP/Level (DEC-081) |
| `Vitals` (Health, Armor, Stamina) | `Vitals` (§3.3) | sanidade + estado de vida |
| `Round` (packet) | **removido**; set `Shift` | estado do turno chega pronto a quem reconecta |
| `Ready` | sem mudança | handshake |

## 3. Sets — place Run

### 3.1 `Shift` (registro único, id `1`)

```lua
Shift = Lync.replicate(Lync.struct({
	Day = Lync.int(1, 10000),
	Night = Lync.int(0, 10),
	IsNight = Lync.bool(),
	Attempt = Lync.int(0, 9),               -- tentativas da noite atual (0 = primeira); fala curta do chefe na repetida
	Phase = Lync.enum(Content.Shift.PhaseKeys), -- Resume, Intro, Prep, Open, Closing, Summary, Call, Night, NightEnd, NightLost, Finale, RunEnd
	PhaseStartedAt = Lync.f64(),
	PhaseDuration = Lync.int(0, 3600),
	ClockFrom = Lync.int(0, 2880),
	ClockTo = Lync.int(0, 2880),
	Vehicle = Lync.enum(Content.Vehicles.Keys),
	Chances = Lync.int(0, 9),               -- começa em 1 por run inteira (DEC-110, DEC-112); não vai ao HUD (DEC-053)
	WipeEndsAt = Lync.f64(),                -- 0 = sem janela; >0 = contador de 10 s "todos caídos" (DEC-094)
	WipeFrozen = Lync.bool(),               -- true = contador parado (prompt de compra aberto), até +20 s no total (DEC-118)
}))
```

| | |
|---|---|
| Escreve | `RoundService` (`WipeEndsAt` e `WipeFrozen` vêm do `VitalService`; ao descongelar, `WipeEndsAt` é reenviado já somado do tempo parado) |
| Lê | `RoundController` → HUD (relógio derivado), `CameraController`, `HudController` (contador), `CutsceneController` |
| Frequência | por troca de fase; wipe raro |
| Por que set | todos veem; quem reconecta precisa do estado atual |

### 3.2 `Economy` (registro único) — sem mudança

`{ Cash: int(0, 2^31−1), Drawer: int(0, 1000000) }`. Escreve `EconomyService`; lê `EconomyController`. Por venda,
compra, depósito, roubo (~0,2–1/s em pico).

### 3.3 `Vitals` (id = `UserId`) — estendido

```lua
Vitals = Lync.replicate(Lync.struct({
	Sanity = Lync.int(0, 200),
	MaxSanity = Lync.int(0, 200),
	State = Lync.enum({ "Active", "Down", "Reviving", "Spectator", "Away" }),
	StateEndsAt = Lync.f64(),       -- Down: 6:00 AM da noite da queda, fim da oferta (DEC-115); 0 = sem prazo
	KnockedUntil = Lync.f64(),      -- atropelado até (ragdoll); 0 = de pé
	Class = Lync.enum(Content.Classes.Keys),
}))
```

| | |
|---|---|
| Escreve | componente `Vital` (servidor) e `VitalService`; `KnockedUntil` por `CharacterService` via `VitalService:SetKnocked` (um dono por set) |
| Lê | `VitalController` (HUD), `CameraController` (spectate escolhe colega Active), `ReviveController` (oferta enquanto `Down`), `HallucinationController` |
| Frequência | noite: escuro a 1 Hz por jogador no pior caso; eventos. Dia: só atropelamento e Away |
| Por que set | a party precisa ver quem caiu, quem está em spectate e quem está fora. Registro **não** é removido quando o jogador sai (vira `Away`); membro atrasado ainda não chegado não tem registro |

### 3.4 `Stock`, 3.5 `Stations`, 3.6 `Customers`, 3.8 `Switches` — sem mudança de schema

Ver versão 1 (mesmos campos). Notas: `Stations.Kind` e `Customers.Look` continuam índices de tabela; `Customers`
não diz "anomalia". Escritores e leitores iguais.

```lua
Stock = Lync.replicate(Lync.struct({ Amount = Lync.int(0, 999), Capacity = Lync.int(0, 999) })),
Stations = Lync.replicate(Lync.struct({
	Kind = Lync.enum(Content.Stations.Keys),
	State = Lync.enum({ "Empty", "Working", "Ready", "Blocked" }),
	StartedAt = Lync.f64(), Duration = Lync.quant(0, 120, 0.1),
	Count = Lync.int(0, 30), Contents = Lync.bitfield(Content.Ingredients.Keys),
})),
Customers = Lync.replicate(Lync.struct({
	Look = Lync.int(1, 255),
	State = Lync.enum({ "Arriving", "Queued", "Ordering", "Waiting", "Leaving" }),
	Slot = Lync.int(0, 8),
	Order = Lync.bitfield(Content.Ingredients.ToppingKeys),
	PatienceEndsAt = Lync.f64(),
	Mood = Lync.enum({ "Neutral", "Happy", "Annoyed", "Complaining" }),
})),
Switches = Lync.replicate(Lync.struct({ On = Lync.bool() })),
```

### 3.7 `Upgrades` (id = índice em `Content.Upgrades`)

`{ Level: int(0, 9) }`. Escreve `UpgradeService`; lê `MarketController` (preço e nível na bancada) e
`UpgradeController` (peça visível). Por compra. Sem prompt no equipamento (DEC-101).

### 3.9 `RunState` (registro único, id `1`) — novo

```lua
RunState = Lync.replicate(Lync.struct({
	PriceParty = Lync.int(0, 4),    -- 0 até o fim do Day 1; depois fixo = quem entrou até ali (DEC-121). Multiplica trailer e Revive Kit
	RosterSize = Lync.int(1, 4),
	Endless = Lync.bool(),          -- run em modo dia infinito (contador Day 100 ativo)
}))
```

| | |
|---|---|
| Escreve | `RunStateService` |
| Lê | prompt do trailer à venda (`PromptController`), `MarketController` (preço do Revive Kit), `HudController` |
| Frequência | 1 vez no fim do Day 1; entrada no modo infinito |
| Por que set | os preços dependem dele e são mostrados a todos |

### 3.10 `Bench` (id = vaga especial; hoje só `1`, DEC-106) — novo

```lua
Bench = Lync.replicate(Lync.struct({
	Item = Lync.enum(Content.BenchItems.Keys), -- inclui "none" (slot vazio no turno)
	Price = Lync.int(0, 100000),               -- já multiplicado por PriceParty ($200 × mult. para o Revive Kit, DEC-129)
	Left = Lync.int(0, 9),                       -- unidades restantes neste turno
}))
```

| | |
|---|---|
| Escreve | `MarketService` no `ShiftStarted` (sorteio com semente, ou a oferta restaurada do snapshot) e a cada compra |
| Lê | `MarketController` (modelo exposto no slot, billboard de preço, "Sold out") |
| Frequência | 1 por turno por slot + compras |
| Por que set | oferta compartilhada; quem chega vê a oferta atual |
| Nota | upgrades básicos **não** passam aqui (sempre à venda, DEC-106): leem `Upgrades` e tabela. O Food Trailer não é da bancada (prompt no próprio trailer, DEC-107): lê `Shift.Vehicle`, `RunState.PriceParty` e tabela |

### 3.11 `Traffic` (id = slot de carro, 1–8) — novo

```lua
Traffic = Lync.replicate(Lync.struct({
	Route = Lync.int(1, 32),          -- índice em Content.Traffic.Routes (TR-1..TR-10 hoje; polilinha nomeada no mapa)
	Look = Lync.int(1, 16),           -- modelo/cor
	AnchorAt = Lync.f64(),            -- tempo de servidor da âncora (nascimento ou última arrancada)
	AnchorDist = Lync.f32(),          -- studs ao longo da rota em AnchorAt; velocidade não vai no fio (perfil por trecho)
	StopDist = Lync.f32(),            -- próxima parada (studs ao longo da rota); 0 = nenhuma parada à frente
	HeldUntil = Lync.f64(),           -- arranca sozinho neste tempo (PARE com caixa reservada); 0 = parado até novo registro
}))
```

| | |
|---|---|
| Escreve | só `TrafficService`: `set` ao nascer, ao ganhar/trocar a próxima parada (PARE `SL-N/SL-S`, linha de faixa com reserva de NPC, fila atrás de outro carro), ao arrancar (nova âncora) e `remove` ao sair da rota |
| Lê | `TrafficController` (clona o modelo; posição = `Shared/TrafficMotion(registro, rota, now)`, a mesma função que o servidor usa no tick de 10 Hz e na validação de `CarHit`; testa hit local) |
| Frequência | por carro: 1 ao nascer + 1–2 por PARE (o 2º só se a caixa `X-T` estava ocupada) + 0–2 por faixa reservada + `remove`. Teto 4 carros de dia; Juniper Sul 1 carro a cada 12–20 s por sentido (DEC-133); 1 carro à noite, só TR-1/TR-2 (`Q-103`). Pior caso < 40 B/s por client |
| Paradas (DEC-133) | `StopDist`/`HeldUntil` existem por causa do PARE (1 s, Juniper) e da reserva de faixa por NPC (máx. 4 s). **Nenhum campo depende de jogador**: carro nunca para nem desvia por jogador. PARE com caixa livre já sai com `HeldUntil = chegada + 1 s` (sem segundo registro, imune à latência) |
| Por que âncora e não `StartedAt` + lista de paradas | a duração de parada por NPC só é conhecida quando o NPC sai da pista; re-ancorar a cada arrancada mantém o registro em tamanho fixo (~34 B) e a posição função pura do último registro |
| Por que set e não packet | quem chega ou reconecta precisa ver os carros já na rua (inclusive parados); o registro some sozinho |
| Por que não posição por frame | 4 carros × 10 Hz × CFrame seria ~2 KB/s; a cinemática é determinística entre eventos |
| Reserva de faixa no fio? | **não**: o client não precisa saber da reserva; vê o carro parar pelo registro. Evita set extra e mantém a regra só no servidor |

### 3.12 `Ambulance` (registro único, id `1`) — novo

```lua
Ambulance = Lync.replicate(Lync.struct({
	Trip = Lync.enum({ "Pickup", "Return", "Dawn" }), -- coleta (médicos descem, DEC-114) / volta do reviver (ninguém desce, DEC-091) / noite perdida (parte sem sirene, DEC-122)
	Phase = Lync.enum({ "Arrive", "Load", "Leave", "Drop", "Depart" }),
	StartedAt = Lync.f64(),           -- início da fase atual
	Stop = Lync.int(1, 4),            -- índice em Content.Ambulance.Stops (AMB-M, AMB-P)
	Riders = Lync.array(Lync.struct({ -- corpos a recolher nesta parada (Pickup) ou quem aparece em REV-n (Return)
		UserId = Lync.f64(),
		Body = Lync.vec3(),           -- onde o corpo está; ignorado em Return
	}), 0, 4),
}))
```

| | |
|---|---|
| Escreve | `AmbulanceService` (uma ambulância por servidor; a fila de viagens fica no servidor, não replica) |
| Lê | `AmbulanceController` (ambulância, sirene, médicos, maca: tudo local pela timeline; caminho dos médicos calculado no client sobre o grafo `NpcNode`), `CameraController` |
| Frequência | ~5 updates por viagem; uma viagem pode servir várias quedas |
| Por que set | colegas e quem reconecta veem a sequência no ponto atual; registro removido quando a ambulância sai do mapa |
| Por que registro único | só existe uma ambulância (FEAT-034, NPC-023, `MAP-01.md` §9.6); id por caído (versão 2) permitia várias simultâneas |

### 3.13 `Cutscene` (registro único) — packet virou set

```lua
Cutscene = Lync.replicate(Lync.struct({
	Scene = Lync.enum(Content.Cutscenes.Keys), -- inclui "none"
	StartedAt = Lync.f64(),
	Votes = Lync.int(0, 4),
	Needed = Lync.int(0, 4),                   -- 0 = não pulável
}))
```

| | |
|---|---|
| Escreve | `CutsceneService` |
| Lê | `CutsceneController` (timeline por tempo, POV), `CameraController`, `HudController` ("Skip 1/2") |
| Frequência | início, cada voto, fim |
| Por que set | atrasado e reconectado entram no ponto atual (DEC-088, `Q-112` c); votos visíveis a todos |

## 4. Sets — place Lobby

### 4.1 `Parties` — sem mudança

`{ Pad, Owner, Members (array de UserId, 0–4), Ready (bitfield M1–M4), State }`. Escreve `PartyService`.

## 5. Packets — place Run

| Nome | Direção | Schema | Dispara | Responde/lê | Frequência | Justificativa |
|---|---|---|---|---|---|---|
| `Interact` | c → s | `{ Id: int(1,65535), Action: enum(Content.Actions.Keys) }` | `PromptController` | `InteractionService` | ≤ 8/s | alvo por `EntityId`; bancada, prateleira, trailer à venda (`buy_trailer`), item derrubado (`pick_up_item`, "Pick Up") passam aqui |
| `Gaze` | c → s, `.newest(10)` | `{ Yaw: angle(1), Pitch: angle(1) }` | `CameraController` (noite, ator ativo) | `AnomalyService` | 10 Hz | perda aceitável |
| `CarHit` | c → s | `{ Car: int(1,8) }` | `CharacterController`/`TrafficController` ao detectar contato local | `TrafficService` | ≤ 1 por imunidade (5 s); servidor limita a 2/s | client vê o carro onde ele está para ele; servidor valida posição calculada ± 8 studs (`architecture.md` §8.2) |
| `Revive` | c → s | `{ Target: f64, Method: enum({"Robux","Item","Credit"}) }` | `ReviveController` (oferta no spectate enquanto `Down`, Tool do Kit ativada) | `ReviveService` | ação; limite 1/s | Validação: **`Method = Robux` ou `Credit` → `Target == remetente`** e remetente `Down` (DEC-116), senão descarta. `Item`: remetente `Down` com o Kit no stash (alvo = ele) ou `Active` com o Kit na mão (alvo escolhido pelo servidor, `Revive.KitTarget`; `Target` ignorado). Sempre: alvo `Down` (nunca `Spectator`), antes das 6:00 AM (DEC-115), `RevivesTonight < 2` (DEC-129). Robux: servidor grava intenção e chama `PromptProductPurchase`; o client **não** abre o prompt sozinho |
| `SkipVote` | c → s | `Lync.empty()` | `CutsceneController` (hold "Skip") | `CutsceneService` | 1 por cutscene por jogador | voto não se retira |
| `Notice` | s → client ou grupo | `{ Kind: enum(Content.Notices.Keys), Value: int(-1000000,1000000) }` | qualquer Service via `RunStateService:Notify` | `HudController` (toast) | evento | inclui `gems_gained` (Value = gemas), `afk_no_gems`, `revive_credit_saved`, `trailer_price` |
| `Sale` | s → grupo | `{ Npc: int(1,65535), Result: enum({"Perfect","Complete","Incomplete","Wrong","Left","Refused"}), Amount: int(0,1000) }` | `CustomerService` | `CustomerController` | por venda | apresentação |
| `ShiftReport` | s → grupo | `{ Day, Night, Revenue, Tips, Bonus, Stolen: int; Grade: enum({"A","B","C","D","None"}); Served, Satisfied, Completed: int(0,999); Gems: int(0,1000); AfkLocked: bool }` | `EconomyService` + `RewardService` | `HudController` | 1 por turno | `Gems` = já creditado no turno (DEC-104); `AfkLocked` explica "sem gema de dia" (DEC-083) |
| `BossCall` | s → grupo | `{ Call: enum(Content.BossCalls.Keys), Short: bool }` | `BossService` | `BossController` | 1–2 por turno | `Short` = versão curta da noite repetida (`Q-077` d); sem replay (DEC-077) |
| `AnomalyCue` | s → client ou grupo | `{ Anomaly: enum(Content.Anomalies.Keys), Cue: enum(Content.AnomalyCues.Keys), Entity: int(0,65535), Seed: int(0,65535) }` | `AnomalyService` | `AnomalyController` | eventos | escopo "por jogador" (DEC-073) |
| `LifeEvent` | s → grupo | `{ UserId: f64, Event: enum({"Down","Revived","Spectating","Hit","Wipe","WipeCleared"}) }` | `VitalService`, `TrafficService` | `CameraController`, `HudController`, `AmbulanceController` (sirene), áudio | raro | gatilho de transição; o estado está em `Vitals`/`Shift` |

## 6. Packets — place Lobby (e perfil nos dois)

| Nome | Direção | Schema | Dispara | Responde/lê | Frequência | Justificativa |
|---|---|---|---|---|---|---|
| `Profile` | s → client | `{ Gems: int(0,2^31−1), Classes: bitfield(Content.Classes.Keys), Selected: enum(Content.Classes.Keys), Achievements: bitfield(Content.Achievements.Keys), EndlessDays: int(0,100000), ReviveCredits: int(0,99) }` | `ProfileService:Replicate` (effect existente) | `ProfileController` | quando muda (por evento de gema) | privado por construção; `EndlessDays` **não** é mostrado como "Day 100" (achievement secreto, DEC-058): só debug/estatística |
| `PartyAction` | c → s | `{ Action: enum({"Join","Leave","Ready","Unready","Start"}), Party: int(0,255) }` | `PartyController` | `PartyService` | ≤ 4/s | |
| `ClassAction` | c → s | `{ Action: enum({"Buy","Select"}), Class: enum(Content.Classes.Keys) }` | `ClassController` | `ClassService` | ação | |
| `Reconnect` | s → client | `{ Mode: enum({"Live","Suspended"}), Day: int(1,10000), Night: int(0,10), IsNight: bool, Connected: int(0,4), Seconds: int(0,900) }` | `SessionService` ao achar run | `SessionController` → notificação (DEC-063) | 1 por entrada + atualização a cada 30 s se mudar | `Suspended` mostra "Resume Day N" e o tempo restante (DEC-080); `Seconds` = 0 em `Live` |
| `ReconnectReply` | c → s | `{ Accept: bool }` | `SessionController` | `SessionService` | 1 | |
| `Notice` | s → client | (mesmo de §5) | `PartyService`, `SessionService`, `ClassService`, `MonetizationService` | `HudController` | evento | "That shift has ended.", "That shift can't be resumed.", crédito de reviver recebido no lobby |

## 7. O que não passa pelo Lync

| O quê | Como replica | Por quê |
|---|---|---|
| Tools (pacotes, Coffee, HotDog, Revive kit) | Backpack nativo; `Count` em atributo | DEC-040 |
| Item derrubado (atropelamento: só a Tool da mão, DEC-103) | a própria Tool no `Workspace` com atributos de prompt (`EntityId`, `PromptAction = pick_up_item`) | já é instância; o prompt lê atributos |
| Usar Tool simples (café) | `Tool.Activated` no servidor | o revive kit usa `Revive` (precisa de alvo) |
| Ragdoll | `Motor6D.Enabled`/constraints mudados no servidor; física do client dono | replicação nativa |
| NPCs | física + `Animator` no servidor | |
| Travessia de NPC (DEC-133) | **nenhuma rede própria**: `NpcService` pede/libera a reserva da faixa ao `TrafficService` no servidor; o client vê o NPC andar (física nativa) e os carros pararem (registro `Traffic`) | reserva é regra do servidor; o efeito já replica |
| Luzes dos postes (emissiva, `SpotLight`, corte por distância) | locais ao client; apagar no Hush vem do `AnomalyCue` que já existe | `architecture.md` §12.5, T31 |
| Fala da Opal | escolhida localmente pelo client | puro ambiente (DEC-079) |
| Compra em Robux | `MarketplaceService:PromptProductPurchase` chamado **no servidor**; recibo em `ProcessReceipt` | o servidor associa compra e alvo |
| Peças de upgrade, troca de veículo | instâncias no `Workspace` | |
| Teleporte, roster, snapshot | `TeleportService` + MemoryStore | `data.md` §3 |

## 8. Esboço do `init.luau` (referência; não aplicar na Fase 0)

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)
local Content = require(ReplicatedStorage.shared.Content)

return Lync.define("game", {
	Ready = Lync.packet(Lync.empty()),
	Profile = Lync.packet(Lync.struct({ ... })),
	-- sets da run
	Shift = Lync.replicate(Lync.struct({ ... })),
	RunState = Lync.replicate(Lync.struct({ ... })),
	Economy = Lync.replicate(Lync.struct({ ... })),
	Vitals = Lync.replicate(Lync.struct({ ... })),
	Stock = Lync.replicate(Lync.struct({ ... })),
	Stations = Lync.replicate(Lync.struct({ ... })),
	Customers = Lync.replicate(Lync.struct({ ... })),
	Upgrades = Lync.replicate(Lync.struct({ ... })),
	Switches = Lync.replicate(Lync.struct({ ... })),
	Bench = Lync.replicate(Lync.struct({ ... })),
	Traffic = Lync.replicate(Lync.struct({ ... })),
	Ambulance = Lync.replicate(Lync.struct({ ... })),
	Cutscene = Lync.replicate(Lync.struct({ ... })),
	-- set do lobby
	Parties = Lync.replicate(Lync.struct({ ... })),
	-- packets
	Interact = Lync.packet(Lync.struct({ ... })),
	Gaze = Lync.packet(Lync.struct({ ... })):newest(10),
	CarHit = Lync.packet(Lync.struct({ ... })),
	Revive = Lync.packet(Lync.struct({ ... })),
	SkipVote = Lync.packet(Lync.empty()),
	-- Notice, Sale, ShiftReport, BossCall, AnomalyCue, LifeEvent,
	-- PartyAction, ClassAction, Reconnect, ReconnectReply
})
```

Os dois places definem todas as entradas (mesmo código). Requerer `shared.Content` em `Net` é seguro (não depende
de `self.Libs`, Lync ou Vide). Enums com valor sentinela (`"none"` em `BenchItems` e `Cutscenes`) ficam **na
tabela**, não no código, para a ordem continuar vindo de um lugar só.

Checklist de PR que toca este arquivo: `tools/analyze.ps1` zero erro **e** boot no Studio nos dois places sem erro
de `Lync.start()`.

## 9. Escolhas justificadas (resumo)

| Escolha | Por quê |
|---|---|
| `Traffic` como set, não posição por frame | ~34 B por evento (nascer, parar, arrancar), ≤ 6 por carro; o client interpola; servidor só faz cinemática 1D, zero física (DEC-133 acrescenta paradas sem mudar o modelo) |
| `Ambulance` como set de registro único | uma ambulância por servidor; a sequência tem fases longas (segundos) e precisa aparecer certa para quem reconecta no meio |
| `Cutscene` como set | votos e entrada no meio; packet não entrega estado a quem chega |
| `Revive` com `Method` | um responder só para três caminhos de pagamento; o servidor decide a validade (Robux e crédito só para si, DEC-116) |
| `CarHit` c → s | detecção onde o jogador vê o carro; servidor valida plausibilidade |
| `Bench` só para a vaga especial | básicos são fixos (DEC-106) e o trailer não é da bancada (DEC-107); mandar o que já está em `Upgrades` duplicaria dono |
| `LifeEvent` em vez de `KnockOut` | mais transições (Down, Revived, Spectating, Hit, Wipe); estado continua nos sets |
| Sem set de gemas | gemas são privadas: vão no packet `Profile` + `Notice` |
