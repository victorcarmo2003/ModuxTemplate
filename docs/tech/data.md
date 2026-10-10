Status: Rascunho

# Dados: perfil persistido, estado da run, MemoryStore

Autor: architect. Versão 4, 2026-10-10 (**TASK-001**: estado DEC-140 a DEC-201). Versão anterior: 3.1, 2026-10-08.

> **Base Provisória (DEC-193).** Rascunho que vale para construir. Rede: `network.md` v4. Tabelas: `content-data.md` v4.

Versão 4:
- **Template v1 confirmado** com as chaves de classe por animal (DEC-186): conta nova = `{ class_dog = true }`,
  `SelectedClass = "class_dog"`. Chaves `class_rookie`… nunca foram publicadas: troca sem migração.
- **Nível de upgrade por veículo** (DEC-184) no estado da run e no snapshot (`Upg` passa a ser por veículo).
- Tools no stash/snapshot guardam o extra do HotDog (`Toppings`, DEC-190).
- Onda 1 (TASK-010): place Run em **modo dev**, snapshot **só em memória** (MemoryStore na onda 2).
- Nada novo persiste por causa de sanidade/visual (DEC-166 a DEC-169, DEC-181): faixa e pack são estado vivo da noite.

Versão 3: `ReviveCredits` decidido (DEC-117); `PriceParty` fixado no fim do Day 1 substitui `Joined` (DEC-121);
`Chances` padrão 1 (DEC-110, DEC-112); noite repetida restaura **todos** como `Active` (DEC-111, DEC-113); retomada
também após queda do servidor (DEC-119); oferta especial da bancada entra no snapshot (FEAT-035); contador de revives
por noite (DEC-129).

Versão 3.1: sem semáforo (DEC-130, revoga DEC-120) → sai o campo `Run.Epoch` (só servia ao ciclo do semáforo).
Trânsito, rotas novas (`TR-7..TR-10`) e a rota do Mart cruzando a Juniper Sul (rodada 17) não persistem nada:
carros e travessias de NPC continuam fora do snapshot (§2.2). Perfil e formato do snapshot sem mudança (`V` igual).
DEC-133 (PARE e reserva de faixa para NPC) também não persiste: reservas e paradas são estado vivo do turno.

| Camada | Onde | Vida | Conteúdo |
|---|---|---|---|
| Perfil | DataStore via ProfileStore (`ProfileService`, store `"Player"`) | para sempre | gemas, classes, achievements, **contador Day 100**, **créditos de reviver**, **recibos processados**, **chaves de gema da run**, estatísticas |
| Run | memória do servidor reservado (atoms Charm por Service) | enquanto houver ≥ 1 conectado | tudo do jogo |
| Ponteiros | MemoryStore HashMap `Runs`, `PlayerRun` | TTL 960 s, renovado no batimento | qual run cada jogador tem, roster, estado (`Live`/`Suspended`/...) |
| **Snapshot** | MemoryStore HashMap `Snap` | TTL 2700 s vivo; **960 s** ao suspender | estado de início do turno corrente (DEC-080) |

Mudança de fundo desde a versão 1: DEC-080 trouxe o snapshot para fora do servidor; DEC-104 trouxe o save de gemas
por evento; DEC-084 trouxe o contador persistido; DEC-092 trouxe recibos de Robux.

---

## 1. Perfil (ProfileStore)

### 1.1 Template v1 (confirmado; TASK-004)

Substitui o Template de exemplo (`Coins`, `Level`, `Playtime`). Jogo não lançado: trocar o Template não exige
migração de jogador real. Sem XP nem nível (DEC-081). Os campos das ondas 2–4 já entram no v1 (custo ~zero; evita
migração quando a onda abrir); o que a onda 1 lê e escreve: `Gems`, `Classes`, `SelectedClass`.

```lua
--!strict
return {
	Version = 1,

	-- Gemas (DEC-070, DEC-104)
	Gems = 0,                                  -- saldo
	GemsEarned = 0,                            -- total histórico

	-- Classes = animais da crew (DEC-147, DEC-186). Chave = Content.Classes Key (class_<espécie>)
	Classes = { class_dog = true } :: { [string]: boolean }, -- Cachorro grátis: conta nova = Cachorro
	SelectedClass = "class_dog",

	-- Achievements e Day 100 (DEC-058, DEC-084)
	Achievements = {} :: { [string]: number }, -- chave → os.time() da conquista
	BadgesAwarded = {} :: { [string]: boolean }, -- badge confirmado pelo BadgeService (retry até true)
	EndlessDays = 0,                           -- dias de modo infinito concluídos com anti-AFK, entre sessões

	-- Monetização (DEC-092; architecture.md §10)
	ReviveCredits = 0,                         -- reviver pago em Robux e ainda não usado (DEC-117); só para si (DEC-116)
	Receipts = {} :: { string },               -- últimos 50 PurchaseId processados (lista circular)

	-- Idempotência de gemas por run (architecture.md §10.4)
	RunRewards = { RunId = "", Keys = {} :: { string } },

	Stats = {
		RunsStarted = 0,
		RunsFinished = 0,      -- final da 10ª noite (DEC-075)
		NightsWon = 0,
		BestNight = 0,
		BestDay = 0,
		Revives = 0,           -- vezes que foi revivido (telemetria de monetização)
	},
}
```

Notas:
- Chaves de conteúdo = `Key` da tabela (`class_dog`, `class_cat`…, DEC-186; `content-data.md` §3.10). Nunca índice.
- O animal **é** a classe (DEC-147): o perfil não guarda espécie separada; `Content.Classes[k].Species` resolve.
- `Profile` (packet) manda ao client só `Gems`, `Classes`, `Selected` (`network.md` §4.5).
- O perfil é reativo **por campo de topo** (`Atomic.Table`): campo aninhado (`Classes`, `RunRewards`, `Stats`,
  `Receipts`) muda **por cópia** (`profile.Classes(withKey(profile.Classes(), key))`). Mutar no lugar não dispara o
  `effect` e não persiste.
- Tamanho: ~1 KB por jogador no pior caso (50 recibos de 36 caracteres = 1,9 KB; ainda irrelevante perto de 4 MB).
- `EndlessDays` não é exibido como progresso para "Day 100" (achievement **secreto**, DEC-058).

### 1.2 Quem escreve

| Campo | Escritor | Place | Quando | Save |
|---|---|---|---|---|
| `Gems`, `GemsEarned` | `RewardService` | R | cada `RewardEvent` (DEC-104) | `RequestSave` (agrupa 2 s) |
| `Gems` (débito), `Classes`, `SelectedClass` | `ClassService` | L (onda 1: **R em modo dev**, TASK-017, Provisório) | compra/seleção (`ClassAction`) | `RequestSave` |
| `Gems` (crédito de dev) | comando de servidor no Studio (`PlaceService:IsDev()`) | R dev | teste | `RequestSave` |
| `EndlessDays` | `RewardService` | R | dia de modo infinito concluído com anti-AFK | `RequestSave` |
| `Achievements`, `BadgesAwarded` | `RewardService` (R); retry de badge também no L | L+R | `EndlessDays` = 100 | `RequestSave` |
| `RunRewards` | `RewardService` | R | junto de cada crédito | mesmo save |
| `ReviveCredits` | `ReviveService` (+1 pelo recibo, −1 no uso) | L+R | recibo; uso | `Save()` imediato no recibo (§1.4) |
| `Receipts` | `MonetizationService` | L+R | todo recibo concedido | `Save()` + espera `OnAfterSave` |
| `Stats` | `RewardService`, `ReviveService` | R | eventos | `RequestSave` |

Custo de escrita: ≤ 4 eventos por turno por jogador → muito abaixo de 60 + 40 × jogadores escritas/min por servidor.
Limite por chave hoje é 4 MB/min (sem o antigo cooldown de 6 s).

### 1.3 Gemas por evento: algoritmo (`RewardService`)

```
Credit(member, key, gems, extra):
  profile = ProfileService:Get(member) ; sem perfil carregado → não paga (DEC-104: só presentes e carregados)
  rr = profile.RunRewards()
  if rr.RunId ~= RunId then rr = { RunId = RunId, Keys = {} } end
  if key ∈ rr.Keys then return end                  -- noite repetida, retomada, reconexão: nunca 2×
  batch:
    Gems += gems ; GemsEarned += gems ; RunRewards = rr ∪ {key} ; extra (EndlessDays += 1, Stats...)
  RequestSave(member)
  Notice{gems_gained, gems} ao jogador
```

Perfil ainda carregando (trava de sessão, R4) no instante do evento: o crédito espera até 10 s pelo `Loaded`; depois
disso, perde o evento (é "não estava presente"). Registrar em log.

### 1.4 Recibos (`MonetizationService`, `architecture.md` §10.1)

```
ProcessReceipt(receipt):
  player = Players:GetPlayerByUserId(receipt.PlayerId) ; ausente → NotProcessedYet
  profile = ProfileService:Get(player) ; não carregado → NotProcessedYet
  if receipt.PurchaseId ∈ profile.Receipts then return PurchaseGranted end
  handler = Products[receipt.ProductId].Kind → handler registrado ; ausente → NotProcessedYet (log alto)
  handler(player, receipt)                  -- Revive: ReviveCredits += 1; se intenção válida aqui, consome na hora
  Receipts = append(Receipts, PurchaseId) cortado em 50
  profile Save() ; espera OnAfterSave contendo o PurchaseId (timeout 15 s)
  ok → PurchaseGranted ; timeout/inativo → NotProcessedYet (o handler é idempotente pelo ledger)
```

Por que o crédito vem antes do consumo: se o servidor cair depois de aplicar o revive e antes do save, o recibo é
reentregue e encontra o crédito ainda não gravado como consumido; a ordem "crédito salvo → consumo" garante que o
jogador nunca perde o que pagou.

### 1.5 Migração de versão

`ProfileService:Load`: `Reconcile` → `Migrate` (enquanto `Data.Version < CURRENT`, aplica `Migrations[v]`) → `Bind`.
- `src/Profile/server/ProfileService/Migrations.luau`: funções puras `(data) -> ()`, append-only.
- Renomear/remover campo = migração (o `Reconcile` só adiciona).
- Classe removida da tabela: devolve as gemas do preço e volta `SelectedClass` para `class_dog`.
- `SelectedClass` que não está em `Classes` (dado corrompido): volta para `class_dog` na leitura, sem gravar.
- Chave desconhecida em `Classes`/`Achievements` é ignorada na leitura.
- QA: fixture da versão N−1 → carrega → compara.
- Versão 1 é a primeira publicada; a troca do Template de exemplo não precisa de migração.

### 1.6 Sessão entre places

Mesmo store nos dois places. Lobby encerra a sessão no `PlayerRemoving`; a run abre com `StartSessionAsync`. A trava
pode atrasar alguns segundos (R4): a run não espera o perfil; classe vale quando carregar (Cachorro, `class_dog`, até lá; o spawn espera no máximo 10 s pelo perfil antes de usar o Cachorro, **Provisório**).

## 2. Estado da run (memória do servidor reservado)

Tipos ilustrativos; cada parte vive em atoms do Service dono.

### 2.1 Raiz e membros (`RunStateService`)

```lua
type LifeState = "Active" | "Down" | "Reviving" | "Spectator" | "Away"

type Member = {
	UserId: number,
	Class: string,              -- chave de Content.Classes, travada na run
	State: LifeState,
	StateBeforeAway: LifeState?,
	Sanity: number,             -- dono real: componente Vital; aqui o valor guardado quando Away
	Stash: { { Kind: string, Count: number, Extra: string? } }, -- Tools guardadas (sair, cair, respawn); Extra = Toppings do HotDog (DEC-190)
	CoffeeReadyAt: number,
	SeenAnomalies: { [string]: true },          -- chave ANM-### vista nesta noite (−5 uma vez, DEC-056)
	RevivesTonight: number,     -- revives usados nesta noite (Robux + Kit + crédito); teto 2 (DEC-129); zera a cada noite
	EverJoined: boolean,        -- já entrou na run ao menos uma vez; base de PriceParty no fim do Day 1 (DEC-121)
}

type Run = {
	RunId: string,              -- game.PrivateServerId
	Seed: number,               -- semente da run (gerada no lobby, gravada em Runs)
	StartedAt: number,
	Roster: { number },         -- UserIds do lobby; fixo
	PriceParty: number,         -- 0 até o fim do Day 1; depois = nº de membros com EverJoined, fixo (DEC-121)
	Members: { [number]: Member },
	Chances: number,            -- começa em RunParams.Chances = 1 (DEC-110, DEC-112)
	Endless: boolean,
	Counters: { [string]: number }, -- limites por run (ex.: revive_kit_sold)
	Ended: boolean,
}
```

### 2.2 Por Service: o que entra no snapshot de turno

| Service | Estado (atoms) | No snapshot? | Nota |
|---|---|---|---|
| `RunStateService` | Seed, Roster, PriceParty, Members (classe, estado de vida, stash, EverJoined), Chances, Endless, Counters | **sim** | na noite perdida, `Chances` **não** é restaurado (já descontado) e **todo membro volta `Active`** (DEC-111, DEC-113; Away segue Away com `StateBeforeAway = Active`). Na retomada, estado de vida como capturado |
| `RoundService` | Day, Night, IsNight, Attempt, fase | sim (Day/Night/IsNight/Attempt) | fase volta ao início do turno |
| `EconomyService` | Cash, Drawer, ledger do turno | Cash sim; Drawer e ledger zeram | gaveta já foi depositada no fim do turno anterior |
| `KitchenService` | estoque, estações (vagas da grelha, trilho, vagas da tábua) | estoque sim (`Amount` por ingrediente; `Capacity` e `Blocked` são derivados de Cooler/Day/veículo e **não** entram); estações vazias | turno recomeça com grelha, trilho e tábua vazios |
| `UpgradeService` | Level **por veículo** por upgrade (DEC-184) | sim, os dois veículos | o set `Upgrades` mostra só o veículo atual; o snapshot guarda os dois |
| `VehicleService` | Vehicle, troca agendada | Vehicle sim | troca do fim de turno já aplicada antes da captura |
| `ItemService` | Tools de cada membro (com `Count` e `Toppings`), itens no chão | Tools sim (no stash do membro, com o extra); itens no chão **não** | |
| `MarketService` | oferta da vaga especial, `Left` | **sim** (só a chave do item sorteado; `Left` volta ao valor de início de turno) | FEAT-035: noite repetida e retomada não sorteiam de novo. `Counters` da run ficam no `RunStateService` |
| `VitalService` | sanidade, estado de vida, `RevivesTonight` | estado de vida sim (no `Member`); sanidade não (início de noite da classe, DEC-056/069); `RevivesTonight` não (é 0 em toda captura) | |
| `CustomerService`, `ThiefService`, `NpcService`, `TrafficService`, `AmbulanceService` | entidades vivas, fila da ambulância | não | turno recomeça vazio; na noite repetida a ambulância só faz a viagem `Dawn` (DEC-122) |
| `AnomalyService` | agenda da noite | não | recalculada da tabela + semente + Attempt |
| `RewardService` | — | não | idempotência mora no **perfil** (`RunRewards`) |
| `CutsceneService` | cena atual | não | cutscene de abertura só no Day 1 da 1ª vez (retomada no Day 1 toca de novo, pulável) |

Regra para o backend-coder: Service com atom de run que não aparece nesta tabela é bug (R13).

### 2.3 Jogador que sai e volta (servidor vivo)

| Ao sair (`PlayerRemoving`) | Ao voltar |
|---|---|
| `StateBeforeAway = State`; `State = Away` | estado anterior (Active; Down → Spectator se passou das 6:00 AM da noite da queda enquanto fora, DEC-115; Spectator) |
| Tools do Backpack e da mão vão para `Stash` | Tools recriadas do `Stash` (Active); Spectator não recebe Tools |
| sanidade guardada | sanidade restaurada (escuro não desconta de Away) |
| era o último conectado → **suspende** (§3.4) | spawn junto ao veículo (Active) ou câmera de spectate |

## 3. MemoryStore

Três HashMaps. Todo valor tem `V` (versão do formato). Chaves de conteúdo por **string**.

### 3.1 `Runs` — chave `RunId`

```lua
{
	V = 1,
	Code = "<ReservedServerAccessCode>",
	Seed = 123456789,
	JobId = "<game.JobId do dono>",          -- vazio até o primeiro boot
	State = "Starting" | "Live" | "Resuming" | "Suspended" | "Ended",
	Roster = { 111, 222, 333 },
	Connected = { 111, 333 },
	Day = 7, Night = 2, IsNight = true,
	CreatedAt = 1760000000,
	UpdatedAt = 1760000000,                  -- os.time() do último batimento
	ExpiresAt = 0,                           -- Suspended: os.time() + 900
}
```

| Escreve | Quando | TTL |
|---|---|---|
| `SessionService` (lobby) | criação (`Starting`) | 300 s |
| `SessionService` (run) | claim no boot (`UpdateAsync`), `Live`, batimento 30 s, entrada/saída | 960 s |
| `SessionService` (run) | suspender (último sai ou `BindToClose` com run viva) | 960 s |
| `SessionService` (run) | fim da run (sem chances, final, `RunEnd`): **remove** | — |

~350 B.

### 3.2 `PlayerRun` — chave `UserId`

```lua
{ V = 1, RunId = "<PrivateServerId>", Code = "<ReservedServerAccessCode>" }
```

Escrito pelo lobby na criação; renovado pela run a cada **5 min** (TTL 960 s) e ao suspender; removido no fim da
run; sobrescrito quando o jogador começa outra run. ~120 B.

### 3.3 `Snap` — chave `RunId` (DEC-080)

Estado de **início do turno corrente**. Chaves curtas para caber na cota (R16). Exemplo com 2 jogadores:

```lua
{
	V = 1,
	At = 1760000000,                 -- os.time() da captura
	Run = { Seed = 123456789, Roster = { 111, 222 }, Pp = 2, Ch = 1, End = false,
	        Cnt = {} },                -- Pp = PriceParty (DEC-121); Ch = chances restantes (1 por run, DEC-110)
	Sh = { D = 7, N = 2, Ni = true, A = 0 },          -- Day, Night, IsNight, Attempt
	Cash = 412,
	Veh = "trailer",
	Stk = { bun = 18, sausage = 20, ketchup = 41, mustard = 30, cheese = 12, bacon = 9,
	        potato_sticks = 15, cream_cheese = 6, coffee = 22 },
	Upg = {                          -- nível por veículo (DEC-184); o trailer recomeça do StartLevel
		cart = { grill = 2, cooler = 1, counter = 2, cash_drawer_lock = 1 },
		trailer = { grill = 1, cooler = 2, counter = 1, cash_drawer_lock = 0, trailer_lights = 1 },
	},
	Bn = { "revive_kit" },           -- oferta da vaga especial S1 neste turno ("none" se vazia; FEAT-035)
	M = {
		["111"] = { C = "class_cat", S = "Active", J = true,
		            T = { { "pack_sausages", 4 }, { "coffee", 1 }, { "hot_dog", 1, "ketchup,cheese" } } }, -- 3º campo = extra (Toppings)
		["222"] = { C = "class_owl", S = "Spectator", J = true, T = {} }, -- caiu numa noite anterior; volta Active se esta noite for repetida
	},
}
```

| Item | Valor |
|---|---|
| Tamanho | ~700 B base + ~120 B por membro → solo ~0,8 KB, 4 jogadores ~1,2 KB (JSON). Alvo ≤ 2 KB; teto 8 KB (`error` no Studio, log em produção) |
| Escreve | `SessionService` a pedido do `RunStateService` em cada captura (fronteira de turno, início da run, noite repetida) |
| TTL | 2700 s vivo (maior que a noite mais longa, 30 min, + 15 min); **960 s** ao suspender |
| Lê | o servidor que retoma (§3.5) |
| Remove | fim da run |
| Membro Down/Reviving na captura | não ocorre: a captura é na fronteira de turno, e quem está Down às 6:00 AM vira `Spectator` (DEC-115) antes dela. Reviving em andamento no fim da noite termina antes da captura (vira `Active`) |
| Restore da noite repetida | todos os membros `Active` (inclusive `S = "Spectator"` da captura), `Ch` não restaurado, sanidade de início de noite, aparecem em `REV-1..4` ao lado do trailer (DEC-111, DEC-113, DEC-122; `architecture.md` §7) |
| Restore da retomada | tudo como capturado; vale para saída de todos **e** queda do servidor (DEC-080, DEC-119) |
| Não guarda | sanidade (valor de início de noite da classe), NPCs, carros, ambulância, itens no chão, gaveta, ledger, Profile |

Versão: `V` muda quando o formato muda. O servidor que retoma aceita `V` atual e `V − 1` (com função de conversão);
mais antigo = "That shift can't be resumed." (R19).

Versão 4 deste documento mudou `Upg` (por veículo) e o item de `T` (extra). O formato **nunca foi publicado**:
continua `V = 1`. Onda 1 (TASK-010): `RegisterSnapshot(name, capture, restore)` guarda a mesma estrutura **em memória**
(sem MemoryStore); serve para validar o registro de cada Service (R13) antes da onda 2.

### 3.4 Suspender

```
Gatilho: PlayerRemoving deixa Connected = 0, ou BindToClose com run Live.
1. Runs: State = Suspended, Connected = {}, ExpiresAt = now + 900, UpdatedAt = now        TTL 960
2. Snap: reescreve o último snapshot capturado                                            TTL 960
3. PlayerRun de cada membro do roster                                                    TTL 960
Tudo dentro dos 30 s do BindToClose (3–6 requisições, < 1 s típico).
```

### 3.5 Retomar

```
Servidor novo, mesmo PrivateServerId (teleporte com o código guardado):
1. GetAsync Runs[RunId]
2. Retomável se: (State = Suspended e now < ExpiresAt) ou (State ∈ {Live, Resuming} e now − UpdatedAt ≥ 90)
3. UpdateAsync Runs: só se ainda retomável → State = Resuming, JobId = game.JobId, UpdatedAt = now
   (perdeu a corrida → devolve ao lobby)
4. GetAsync Snap[RunId]; V aceito → RunStateService:Restore(snap) → fase Resume (15 s) → turno do início
5. State = Live; batimento; captura nova (início do turno retomado) com TTL 2700
```

### 3.6 Leitura no lobby

Tabela de decisão em `architecture.md` §5.4. Custo: 2 leituras por entrada no lobby; repetição a cada 30 s enquanto
a notificação estiver aberta (para atualizar o tempo restante e o modo).

### 3.7 Cota e custo

| Item | Valor |
|---|---|
| Cota de memória (experiência) | 64 KB + 1,2 KB × usuários simultâneos |
| Cota de requisições | 1000 + 120 × usuários por minuto (unidades); `UpdateAsync` conta ≥ 2 |
| Valor máximo por item | 32 KB (o snapshot usa ≤ 2 KB) |
| Por run viva | `Runs` ~0,35 KB + `PlayerRun` 0,12 KB × membros + `Snap` ≤ 2 KB → solo ~1,3 KB; 4 jogadores ~2,1 KB |
| Contribuição de cota da própria run | 1,2 KB × membros conectados → solo 1,2 KB (ligeiramente abaixo do uso); 4 jogadores 4,8 KB |
| Jogadores no lobby | contribuem 1,2 KB cada sem usar quase nada |
| Run suspensa | ocupa ~1,3–2,1 KB por até 16 min sem contribuir |
| Requisições por run viva | `Runs` 2/min + `PlayerRun` ~1/min + `Snap` ~0,2/min ≈ 3–4/min |

Conclusão: cabe com folga em qualquer mistura realista (lobby + runs de party). O pior caso teórico (todos os
jogadores em runs solo, muitas runs suspensas) fica perto do teto: R16. Mitigação pronta, sem mudar regra: gravar o
`Snap` só ao suspender (mesmo conteúdo; perde-se apenas a retomada após queda do **servidor**).

Falha de escrita (cota, rede): log + `Notice` interno; a run viva segue; só a recuperação fica indisponível.

## 4. O que **não** é persistido

- Dinheiro, estoque, upgrades, veículo, chances fora do snapshot de 15 min (DEC-035, DEC-080).
- Progresso de "Day N" da run (o contador persistido é só `EndlessDays`).
- Espectador, estado de vida, Tools: só no snapshot.
- Oferta da bancada: só no snapshot (`Bn`), nunca no perfil.
- Faixa de sanidade, `LookPack`, humor de cliente, aparência de NPC: estado vivo (DEC-166 a DEC-169, DEC-181, DEC-187).
