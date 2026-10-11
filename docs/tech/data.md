Status: Rascunho

# Dados: perfil persistido, estado da run, MemoryStore

Autor: architect. **Versão 5, 2026-10-10 (pós onda 1):** §5 novo — o que persiste por categoria (progressão,
inventário, moeda, desbloqueios), `Member` enxuto, chaves de snapshot das ondas 2–4 (`T`, `Veh`, `Lt`, `Bs`, `Bn`)
com as chaves que a onda 1 já grava (`Run`, `M`, `Sh`, `Cash`, `Fp`, `Stk`, `Stn`, `Upg`), política de migração.
**Versão 5.2, 2026-10-11 (TASK-144; FEAT-037):** mesas do Pad (UPG-008) e Patio Lights (UPG-009) entram no `Upg`
como qualquer upgrade, com escopo **Pad** (o mesmo nível gravado nos dois veículos, Q-179 a); estado das mesas (suja,
gorjeta, quem está sentado) e duplas **não** persistem (§5.6). `V` e `Version` não mudam.
**Versão 5.3, 2026-10-11 (TASK-160 a TASK-162; pedido do usuário, Provisório):** loja em Robux, classe por Robux e
códigos (§1.7). Campo novo `RedeemedCodes` (sem migração: `Reconcile` acrescenta `{}`); `Receipts` passa a ter escritor
(`ShopService`, que faz o papel do `MonetizationService` do `architecture.md` §10.1); `Classes` e `Gems` ganham
escritores (`ShopService`, `CodesService`). `Version` não muda.
**Versão 5.1, 2026-10-10 (TASK-049):** D-05 fechado — `Stn` e `Fp` descritos como o código grava (§3.3, §5.3, exemplo
corrigido: `Fp` guarda chaves de **ingrediente**); `RunRewards.Gems` novo (soma da run, alimenta `RunReport.Gems`,
T59) sem bump de `Version` (§1.1, §1.3, §5.4). Provisório (DEC-193).
Versão 4, 2026-10-10 (**TASK-001**: estado DEC-140 a DEC-201). Versão anterior: 3.1, 2026-10-08.

> **Base Provisória (DEC-193).** Rascunho que vale para construir. Rede: `network.md` v5. Tabelas: `content-data.md` v5.
> Onde §1–§4 divergem do §5, **vale o §5**.

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
	RunRewards = { RunId = "", Keys = {} :: { string }, Gems = 0 }, -- Gems (v5.1, T59): soma creditada nesta run → RunReport.Gems

	Stats = {
		RunsStarted = 0,
		RunsFinished = 0,      -- final da 10ª noite (DEC-075)
		NightsWon = 0,
		BestNight = 0,
		BestDay = 0,
		Revives = 0,           -- vezes que foi revivido (telemetria de monetização)
	},

	-- Onboarding (Provisório, pedido do usuário 2026-10-11): tutorial do 1º cachorro-quente concluído ou pulado
	TutorialDone = false,

	-- Códigos resgatados (Provisório, pedido do usuário 2026-10-11; §1.7): código normalizado → os.time() do resgate
	RedeemedCodes = {} :: { [string]: number },
}
```

Notas:
- Chaves de conteúdo = `Key` da tabela (`class_dog`, `class_cat`…, DEC-186; `content-data.md` §3.10). Nunca índice.
- O animal **é** a classe (DEC-147): o perfil não guarda espécie separada; `Content.Classes[k].Species` resolve.
- `Profile` (packet) manda ao client só `Gems`, `Classes`, `Selected` e `TutorialDone` (`network.md` §4.5).
- `TutorialDone` (Provisório, 2026-10-11) entrou sem migração: `Reconcile` acrescenta `false` aos perfis antigos.
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
| `Receipts` | `ShopService` (papel do `MonetizationService`, §1.4) | L+R | todo recibo concedido | `SaveConfirmed` (§1.4) |
| `Gems` (crédito de pacote), `Classes` (classe por Robux) | `ShopService` | L+R | recibo de Developer Product (§1.7) | no mesmo `Update` do `PurchaseId` + `SaveConfirmed` |
| `Gems`, `Classes`, `RedeemedCodes` | `CodesService` | L+R | código resgatado (§1.7) | `RequestSave` |
| `Stats` | `RewardService`, `ReviveService` | R | eventos | `RequestSave` |
| `TutorialDone` | `TutorialService` (packet `TutorialComplete`, Provisório) | R | fim ou skip do tutorial | `RequestSave` |

Custo de escrita: ≤ 4 eventos por turno por jogador → muito abaixo de 60 + 40 × jogadores escritas/min por servidor.
Limite por chave hoje é 4 MB/min (sem o antigo cooldown de 6 s).

### 1.3 Gemas por evento: algoritmo (`RewardService`)

```
Credit(member, key, gems, extra):
  profile = ProfileService:Get(member) ; sem perfil carregado → não paga (DEC-104: só presentes e carregados)
  rr = profile.RunRewards()
  if rr.RunId ~= RunId then rr = { RunId = RunId, Keys = {}, Gems = 0 } end
  if key ∈ rr.Keys then return end                  -- noite repetida, retomada, reconexão: nunca 2×
  batch:
    Gems += gems ; GemsEarned += gems ; RunRewards = rr ∪ {key}, rr.Gems += gems ; extra (EndlessDays += 1, Stats...)
  RequestSave(member)
  Notice{gems_gained, gems} ao jogador
```

`RunRewards.Gems` (v5.1, T59, Provisório) só existe para o `RunReport` (`network.md` §13.1): no `RunEnded` o passo
do `RewardService` (`RoundService:AddRunReportStep`, `architecture.md` §19.11) copia `rr.Gems` para `report.Gems` se
`rr.RunId` é a run atual (senão 0). Como mora no perfil e muda no mesmo `batch` do crédito, sobrevive a noite
repetida, `ResetDev` (mesmo `RunId`, nada é pago de novo), reconexão e retomada em outro servidor. Ninguém além do
`RewardService` escreve; o Round nunca lê o perfil.

Perfil ainda carregando (trava de sessão, R4) no instante do evento: o crédito espera até 10 s pelo `Loaded`; depois
disso, perde o evento (é "não estava presente"). Registrar em log.

### 1.4 Recibos (`MonetizationService`, `architecture.md` §10.1)

> **v5.3 (TASK-160):** o `MonetizationService` existe com o nome **`ShopService`** (`src/Shop/server/ShopService.luau`,
> prioridade 790, L+R). Mesmo algoritmo abaixo, com três detalhes do código: (1) produto desconhecido é checado
> **antes** de esperar o perfil; (2) o perfil carregando é esperado até 10 s (padrão ProfileStore); (3) a confirmação
> é `ProfileService:SaveConfirmed(player, pred)`: `Save()` e espera `OnAfterSave` até `LastSavedData.Receipts` conter o
> `PurchaseId` (15 s no total, nova tentativa a cada 5 s). Concessão e `PurchaseId` entram no **mesmo** `Update`
> (um `batch` do Charm, sem yield entre "já concedido?" e a escrita). `RegisterProduct(productId, nome, handler)`;
> o handler devolve `{ Patch, After? }` (o patch não toca `Receipts`; `After` = feedback).

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

### 1.7 Loja, classe por Robux e códigos (v5.3; TASK-160 a TASK-162; pedido do usuário 2026-10-11, **Provisório**)

**Classes possuídas = o campo `Classes` que já existe** (o "OwnedClasses" do pedido). Não há campo novo nem
migração: `ProfileService:OwnedClasses(profile)` lê `Classes` (ignora chave desconhecida e sempre inclui o Cachorro,
grátis, DEC-186); `SelectedClass` só aceita classe possuída (`ClassService:Select`; leitura cai no Cachorro).
`ProfileService:WithClass(profile, key)` devolve a cópia do mapa com a chave (o perfil muda por cópia, §1.1).

| Caminho | Quem | Checagem | Escrita (um `Update`, sem yield entre checagem e escrita) | Save |
|---|---|---|---|---|
| Classe com gemas (`ClassBuy` Gems ou `ClassAction` Buy) | `ClassService:BuyWithGems` | `InMvp`; lobby (ou Run em modo dev); perfil carregado; não possuída; `Gems ≥ Price` | `Gems −= Price`, `Classes = WithClass` | `RequestSave` |
| Classe com Robux | `ShopService` (recibo) | `PurchaseId` ∉ `Receipts`; produto registrado (`Content.Shop`, id > 0, `InMvp`) | `Classes = WithClass` + `Receipts`; **já possuída** → `Gems += Price` da classe (nada pago se perde) | `SaveConfirmed` antes do `PurchaseGranted` |
| Pacote de gemas | `ShopService` (recibo) | idem | `Gems += pack.Gems` + `Receipts` (`GemsEarned` **não** muda: é ganho jogando) | `SaveConfirmed` |
| Código | `CodesService:Redeem` | código existe, ativo, não expirado, ∉ `RedeemedCodes` | `Gems += Reward.Gems`; `Classes = WithClass` (já possuída → `Gems += Price`); `RedeemedCodes[código] = os.time()` | `RequestSave` |

- Recibo de classe chega em qualquer place (inclusive no meio da run): a classe fica possuída; a classe **travada**
  da run não muda (DEC-069).
- `RedeemedCodes` guarda o código **normalizado** (sem espaços, maiúsculo). Tabela de códigos **só no servidor**
  (`src/Codes/server/CodesService/Codes.luau`): o que está em `ReplicatedStorage` qualquer client lê, e código que
  vai ao client é público. Por isso não é `Content.Codes`.
- Tamanho: ~20 bytes por código resgatado; irrelevante.

## 2. Estado da run (memória do servidor reservado)

Tipos ilustrativos; cada parte vive em atoms do Service dono.

### 2.1 Raiz e membros (`RunStateService`)

> v5: `Sanity`, `CoffeeReadyAt`, `SeenAnomalies` e `RevivesTonight` **saem** do `Member` (o `VitalService` guarda por
> `UserId`); `Stash` só vale para quem está fora do servidor ou `Down`. Tipo atual no §5.2.

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
| `ItemService` | Tools de cada membro (com `Count` e `Toppings`), itens no chão, pacote grátis | Tools sim (no stash do membro, com o extra); itens no chão **não**; pacote grátis sim (`Fp`, §5.3) | |
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

> v5: as chaves e o exemplo atualizados (Tools em `T`, não em `M[uid].T`; `Fp`, `Stn`, `Lt`, `Bs`) estão no §5.3.
> v5.1 (D-05 do `wave-1-report.md`): o exemplo abaixo é o da v4 e **não** tem `Stn` (`KitchenService`) nem `Fp`
> (`ItemService/Pickup`), que a onda 1 já grava; o formato de cada um está no §5.3, que vale.

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

## 5. Ondas 2–4 (versão 5)

Contrato de código: `architecture.md` §19. Nada aqui muda regra de jogo.

### 5.1 O que persiste, por categoria

| Categoria | Persiste no perfil (para sempre) | Só na run (memória + snapshot de 15 min) | Escreve |
|---|---|---|---|
| Moeda | `Gems`, `GemsEarned` (DEC-070, DEC-104) | `Cash` da party (DEC-035) | `RewardService`, `ClassService` (débito) / `EconomyService` |
| Desbloqueios | `Classes`, `SelectedClass` (DEC-186) | classe travada do membro (DEC-069) | `ClassService` |
| Progressão | `EndlessDays`, `Achievements`, `BadgesAwarded`, `Stats` (sem XP, DEC-081) | Day, Night, Attempt, `Chances`, veículo, níveis de upgrade por veículo, `Endless` | `RewardService` / Round, RunState, Vehicle, Upgrade |
| Inventário | `ReviveCredits` (DEC-117) — único "item" persistido | Tools de cada membro (snapshot `T`), estoque, oferta S1 | `ReviveService` / Item, Kitchen, Market |
| Idempotência | `Receipts` (50), `RunRewards { RunId, Keys, Gems }` (`Gems` = soma da run para o `RunReport`, v5.1) | — | `MonetizationService`, `RewardService` |

**Template continua `Version = 1`** (§1.1): as ondas 2–4 só **leem e escrevem** campos que já existem. Nada novo
persiste por sanidade, luz, anomalia, chefe, ladrão, trânsito ou passantes (estado vivo do turno).

### 5.2 `Member` (versão 5)

```lua
type LifeState = "Active" | "Down" | "Reviving" | "Spectator" | "Away"
type Member = {
	UserId: number,
	Class: string,                 -- travada na run (DEC-069)
	State: LifeState,              -- escrito só por VitalService via RunStateService:SetLifeState
	StateBeforeAway: LifeState?,
	Stash: { { Kind: string, Count: number, Extra: string? } }, -- só fora do servidor ou Down; escrito só pelo ItemService (SetStash)
	EverJoined: boolean,           -- PriceParty (DEC-121)
}
```

Estado por jogador que **não** está no `Member` (dono guarda por `UserId`, sobrevive a `Away`):

| Dado | Dono | Zera |
|---|---|---|
| sanidade, máximo, `DarkSince`, `ProtectUntil` | `VitalService` | início de cada noite (classe) |
| `CoffeeReadyAt` | `VitalService` | nunca (cooldown real, FEAT-030 "abuso") |
| `RevivesTonight` (DEC-129) | `VitalService` | início de cada noite |
| anomalias vistas na noite (−5 uma vez, DEC-056) | `VitalService` (`SeeAnomaly`) | início de cada noite |

### 5.3 Snapshot: chaves (versão 5)

`V` continua **1** (formato nunca publicado; a onda 1 guarda só em memória). Ordem de restore = ordem de registro
(prioridade do Service, `Snapshots.luau`).

| Chave | Dono | Conteúdo | Onda | Restore `RepeatNight` | Restore `Resume` |
|---|---|---|---|---|---|
| `Run` | RunState | `{ Seed, Roster, Pp, Ch, End, Cnt }` | 1 | `Ch` **não** volta (já gasto) | tudo |
| `M` | RunState | `{ [uid] = { C, S, J } }` (**sem `T`**, T50) | 1 (ajuste A3) | todos `Active` (DEC-111, 113) | `S` como capturado |
| `Sh` | Round | `{ D, N, Ni, A }` | 1 | `A + 1`, captura nova | fase `Resume`, captura nova |
| `Cash` | Economy | número | 1 | igual | igual |
| `T` | Item | `{ [uid] = { { item, count, extra? } } }` | 2 (ajuste A3 + W2-G) | igual | igual |
| `Fp` | Item (`Pickup.luau`) | `{ G = { ingrediente }, L = { ingrediente } }`: listas ordenadas de chaves de `Content.Ingredients` (não de pacote). `G` = ingredientes cujo pacote grátis já foi posto no mundo (nunca de novo); `L` = pacotes ainda no mundo na captura (pacote grátis, TASK-046; v5.1, D-05) | 1 | igual: remove os do mundo, marca `G`, recoloca `L` no veículo atual (`L` também conta como dado) | igual |
| `Stk` | Kitchen | `Amount` por ingrediente | 1 | igual | igual |
| `Stn` | Kitchen | `{ [StableKey] = dado do módulo }`; `StableKey` = `"<veículo>/<kind>"` (+ `"/2"`, `"/3"` se o kind repete no veículo). Só entra estação cujo `Capture` devolve não-`nil`: na onda 1 nenhuma (grelha, trilho, tábua, caixa de pão, tigelas e lixeira devolvem `nil`) → `{}`. Restore chama `Restore(ctx, station, saved[key])` em **toda** estação (com `nil` = começa vazia) e republica o set (v5.1, D-05) | 1 | igual | igual |
| `Upg` | Upgrade | níveis por veículo (DEC-184); upgrades `Scope = "Pad"` (`patio_tables`, `patio_lights`) com o mesmo nível nos dois veículos (v5.2) | 1 | igual | igual |
| `Veh` | Vehicle | chave do veículo atual | 2 | igual (posições + `SetVehicle`) | igual |
| `Lt` | Light | `{ S = interruptor }` | 2 | ligado (FEAT-020) | igual |
| `Bs` | Boss | chaves `Once` já tocadas | 2 | igual | igual |
| `Bn` | Market | chave do especial de S1 (`none`) | 4 | igual (FEAT-035) | igual |

Não entram (estado vivo; recomeça vazio ou recalculado): sanidade, faixa e `LookPack`, NPCs, ladrão, passantes, carros,
ambulância, anomalias (agenda recalculada com `Attempt`), janela do trailer (abre no início do turno, DEC-221), itens no chão, gaveta, ligação em curso,
cutscene.

Exemplo (2 jogadores, Night 2, ~1,1 KB em JSON):

```lua
{
	V = 1, At = 1760000000,
	Run = { Seed = 123456789, Roster = { 111, 222 }, Pp = 2, Ch = 1, End = false, Cnt = { quentin_caught_day = 6 } },
	M = { ["111"] = { C = "class_cat", S = "Active", J = true }, ["222"] = { C = "class_owl", S = "Spectator", J = true } },
	Sh = { D = 7, N = 2, Ni = true, A = 0 },
	Cash = 412,
	T = { ["111"] = { { "pack_sausages", 4 }, { "coffee", 1 }, { "hot_dog", 1, "ketchup,cheese" } }, ["222"] = {} },
	Fp = { G = { "bacon", "cheese", "potato_sticks" }, L = {} },  -- chaves de ingrediente (v5.1)
	Stk = { bun = 18, sausage = 20, ketchup = 41, mustard = 30, cheese = 12, bacon = 9, potato_sticks = 15, cream_cheese = 6, coffee = 22 },
	Stn = {},
	Upg = { cart = { grill = 2, cooler = 1, counter = 2, cash_drawer_lock = 1, trailer_lights = 0 },
	        trailer = { grill = 1, cooler = 1, counter = 1, cash_drawer_lock = 0, trailer_lights = 1 } },
	Veh = "trailer",
	Lt = { S = true },
	Bs = { "call_day_2", "call_day_3", "call_trailer_bought", "call_night_1" },
	Bn = "none",
}
```

Tamanho: `Bs` cresce até ~40 chaves curtas (~0,6 KB no fim da run); total ≤ 2 KB com 4 jogadores. Se passar do alvo,
`Bs` vira lista de índices de `BossCalls` (mudança de `V`).

### 5.4 Migração

| Caso | Como |
|---|---|
| Campo **novo** no Template | `Reconcile` acrescenta; **sem** bump de `Version` |
| Renomear, remover ou mudar o tipo de campo | `Version += 1` no Template + `Migrations[v](data)` (puro, append-only, §1.5); QA com fixture da versão anterior |
| Chave de conteúdo removida (classe, achievement) | a migração devolve gemas da classe e volta `SelectedClass` para `class_dog` (§1.5) |
| Formato do snapshot | `V += 1` + conversão `V − 1 → V` no `RunStateService` (aceita a anterior); mais antigo → "That shift can't be resumed." (R19) |
| MemoryStore `Runs`/`PlayerRun` | campo `V` próprio; mesma regra |

Nenhuma migração é necessária nas ondas 2–4 com este contrato. v5.1: `RunRewards.Gems` é campo **novo aninhado**; o
`Reconcile` do ProfileStore completa tabelas aninhadas, então perfil antigo carrega com `Gems = 0` sem bump de
`Version`. A linha entra no `Template.luau` junto com o `RewardService` (TASK-074, uma linha no Template e no tipo
`RunRewards`).

### 5.5 MemoryStore (onda 4)

§3 vale sem mudança. `SessionService` é o único que fala com `MemoryStoreService`; `RunStateService` entrega cada
captura a `SessionService:WriteSnapshot(snap)` (onda 4). Antes disso, captura só em memória (como a onda 1).

### 5.6 Mesas do Pad e duplas (v5.2, TASK-144; FEAT-037, FEAT-038; Provisório)

| Dado | Onde vive | Persiste? |
|---|---|---|
| Mesas compradas (UPG-008, `TableCount` 0..5) e Patio Lights (UPG-009) | `UpgradeService` (`Levels[vehicle][key]`), snapshot `Upg` | **sim, como upgrade da run** (snapshot de turno; nunca no perfil). Escopo `Pad`: `SetLevel` grava o mesmo nível no carrinho e no trailer, então a troca de veículo não zera (Q-179 a); `Restore` normaliza para o maior nível salvo (snapshot antigo com só um veículo) |
| Estado por mesa (`Free`/`Occupied`/`Dirty`), gorjeta em cima da mesa, quem está sentado | `SeatingService` (memória) | **não**: todo turno, restore e noite repetida começam com as mesas limpas e vazias; gorjeta não recolhida se perde no `Summary` (Q-181 A, DEC-053 para a noite perdida) |
| Duplas (líder/parceiro, pedido de 2 itens) | `CustomerService` | não (clientes não entram no snapshot, §2.2) |
| Back Bar (UPG-010) | `UpgradeService` (só trailer, escopo `Vehicle`) | como upgrade; ainda não vendido (sem TBL-6) |

Nenhuma chave nova de snapshot, nenhum campo novo no perfil.

### 5.7 Papéis de servidor e squad (TASK-154 a TASK-156; `architecture.md` §20; Provisório)

**Nada novo é persistido.** Papel do servidor, squads do lobby e convites vivem só na memória do servidor do lobby;
o roster da run vem do `TeleportData` (`network.md` §16.5) e fica no `RunStateService` como antes (§2.1). Sem
MemoryStore: quem sai de um servidor `Game` não tem como voltar à mesma run (§3 segue como plano). O `Template` do
perfil não muda.
