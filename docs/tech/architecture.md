Status: Rascunho

# Arquitetura técnica

Autor: architect. Versão 3.1, 2026-10-08 (conciliação com DEC-106 a DEC-130, rodada 17 e `consistency-report.md` §5;
alinhada à **DEC-133** — PARE na Juniper, reserva de faixa para NPC — fechando o lado técnico de `Q-131`).
**Versão 3.2, 2026-10-10 (Fase 1, TASK-002):** §18 novo (binding do MAP-01, kits de asset, layout de módulos), T32–T39.
Base: `README.md` (raiz, Modux V3), `CLAUDE.md`, `docs/vision.md`, `docs/decisions.md` (DEC-001 a DEC-130),
`docs/open-questions.md`, `design/proposals-round-1.md` e `proposals-round-2.md` (Aprovados), `story/anomalies.md`
(Aprovado), `art/style-guide.md` (Aprovado, DEC-126), `levels/MAP-01.md` (Rascunho, revisão 3: rotas e entradas),
`design/features.md` (Rascunho), `docs/research/animalplane-reuse.md` e o código em `src/`.

Rodadas 12 a 15 já registradas: as antigas marcas "R12-a/b/c" desta versão 2 são **DEC-108** (Revive Kit pago com
dinheiro da party), **DEC-106** (básicos sempre à venda, só especiais no sorteio) e **DEC-107** (Food Trailer fora
da rotação, compra no próprio trailer). As propostas D1–D5 do §15 viraram DEC-117, DEC-118, DEC-119, DEC-120 e
DEC-111/DEC-113. DEC-120 (semáforo) foi **revogada por DEC-130**; versão 3.1 remove o semáforo de todo o `docs/tech/`.

Documentos irmãos:
- `network.md`: cada entrada de `src/Libs/Net/init.luau`.
- `data.md`: perfil persistido (ProfileStore), estado da run, MemoryStore (ponteiros + snapshot).
- `content-data.md`: tabelas data-driven em `src/Shared/Content`.

Nada aqui é código. Fase 0: nenhum arquivo em `src/` muda até a bandeira verde. Nomes de Service, Controller,
Component, campo e pacote são **propostas**; viram contrato quando o documento for Aprovado.
Fase 1 (DEC-193): este documento vale como **base Provisória** para construir; o §18 é o contrato de binding e de kits
que level-designer, modeler-3d e coders seguem na onda 1.

---

## 0. O que mudou

### 0.-1 Versão 3.2 (Fase 1, TASK-002, 2026-10-10)

| Tema | Antes | Agora | Origem |
|---|---|---|---|
| Binding do mapa | "atributos de prompt", nomes soltos | **§18**: tags reservadas, atributos autorados × de runtime, âncoras por nome só dentro do dono, pontos `MapPoint`, grafo `NpcNode`, checagem | TASK-002; MAP-01 §5, §7; DEC-157, DEC-190 |
| Kits de asset | `InsertService` nos protótipos | **§18.9–§18.10**: `ReplicatedStorage.Assets` montado em modo de edição; **sem `InsertService` em runtime**; malha só como instância, textura por id em módulo de dados | DEC-146, DEC-151, DEC-166, DEC-167, DEC-181 |
| Layout de módulos | implícito | **§18.11–§18.13**: `src/<F>/shared/`, filhos de Service, contrato `KitchenService/Stations/*.luau`, `CustomerService/*.luau` | TASK-002 |
| Estações e Mart | "componentes de estação", componentes `Shelf`/`BenchSlot` | módulos de estação descobertos pelo `KitchenService`; prateleiras e bancada são âncoras `Interactable` (sem Component) | §18.4, §18.12 |
| Técnicas | T1–T31 | + **T32–T34, T36–T40** (decididas pelo architect, DEC-208 delegada); T35 proposta e **retirada** em favor da T40 de `network.md` §5 (client veste o personagem a partir de atributos) | §14, §18.9.4 |

### 0.0 Versão 3.1 (rodadas 16 e 17)

| Tema | Versão 3 | Versão 3.1 | Origem |
|---|---|---|---|
| Semáforo | decidido nas faixas com trânsito (DEC-120) | **não existe no MVP**. Sem ciclo, sem `RunEpoch`, sem `IsWalkGreen`, sem `Traffic.Crossings` com sinal | **DEC-130** (revoga DEC-120) |
| Rota trailer ↔ Mart | CW-1 no beco, sem carros | **cruza a Juniper Sul em CW-1, sem semáforo**: o reabastecimento tem risco de atropelamento **de propósito** | rodada 17 (resposta a `Q-128`) |
| Rotas | `TR-1..TR-6`; entradas `W/E/JN` | **`TR-1..TR-10`**; + `JS-IN/JS-OUT` (Juniper Sul) | `MAP-01.md` revisão 3 §5.4, §9.5 |
| Agenda de carros | carro só agendado se cruza cada faixa no verde | **cinemática 1D no servidor com paradas**: PARE de 1 s nos dois braços da Juniper (entra só com a caixa `X-T` livre; Ninth preferencial nunca para) e parada na linha da faixa com reserva de NPC; nunca para nem desvia por jogador (§8.1, T21). Set `Traffic` ganha âncora + `StopDist`/`HeldUntil` | DEC-130, **DEC-133** (`Q-131`) |
| Travessia de NPC | só no verde de pedestre | **só na faixa, com reserva do servidor** (`TrafficService:ReserveCrossing`): dada só sem carro a < 15 studs da linha; carros param na linha, esperam no máx. 4 s; nova reserva só 4 s depois de liberar (§8.1, T30) | **DEC-133** |
| Postes da Juniper | JL-01..09 a 12 studs | **a cada 8 studs até Z ~−135** (~15 postes + P-01): só metade com `SpotLight` real (§12.5, T31) | `MAP-01.md` revisão 3, `style-guide.md` §5.1 |
| Técnicas T1–T31 | "registrar se o usuário não vetar" | **Provisórias** até aprovação do usuário (`Q-130`) | `CLAUDE.md`, `Q-130` |

### 0.1 Versão 3 (rodadas 12 a 15)

| Tema | Versão 2 | Versão 3 | Origem |
|---|---|---|---|
| Chances do chefe | 3 por run | **1 por run inteira** (`RunParams.Chances = 1`) | DEC-110, DEC-112 |
| Noite repetida | volta só quem caiu naquela noite | **todos voltam `Active`**, inclusive espectadores de noites anteriores (Away segue Away) | DEC-111, DEC-113 |
| Acordar na noite perdida | banco do trailer | **em pé na calçada ao lado do trailer** (pontos `REV-1..4`) | DEC-122 |
| Queda por sanidade | `Ragdoll(∞)` | **animação de desmaio** + corpo ancorado; ragdoll só no atropelamento | `style-guide.md` §4.6 (Aprovado) |
| Prazo do reviver | `OfferWindow` / reviver em spectate | **até 6:00 AM da noite da queda**; Spectator **nunca** é revivido | DEC-115 |
| Quem paga Robux | qualquer presente por qualquer caído | **só o próprio caído** (comprador = alvo) | DEC-116 |
| Limite de revives | sem limite | **2 por jogador por noite** (Robux + Kit + crédito); 3ª queda = Spectator na hora | DEC-129 |
| Recibo sem alvo | proposta D1 | **crédito no perfil** (`ReviveCredits`) | DEC-117 |
| Janela de 10 s | proposta D2 | **congela com prompt de compra aberto, até +20 s** | DEC-118 |
| Queda do servidor | proposta D3 | **retomada de 15 min também na queda do servidor** | DEC-119 |
| Semáforo | proposta D4 em CW-1 | ~~decidido (DEC-120)~~ → **removido na versão 3.1** | DEC-120, revogada por DEC-130 |
| Party para preço | `Joined` que cresce, lido na compra | **`PriceParty` fixado no fim do Day 1** (trailer e Revive Kit) | DEC-121, DEC-129 |
| Bancada | básicos fixos + N slots especiais | básicos fixos + **1 vaga especial** (Revive Kit 15% por turno, depois do trailer) | DEC-106, DEC-129 |
| Food Trailer | listado na bancada | **fora do `MarketService`**: prompt no próprio trailer (`VehicleService`) | DEC-107 |
| Ambulância | uma por caído, até 4 | **uma por servidor**, fila de coletas; médicos descem na ida | DEC-114, FEAT-034 |
| Nomes do mapa | Main St / Cross St | **Ninth Avenue / Juniper Street**, rotas `TR-1..TR-6` (3.1: `TR-1..TR-10`) | `MAP-01.md` revisão 2 (3.1: revisão 3) |
| Luzes à noite | ≤ 6 com sombra | **≤ 3 com sombra, ≤ 18 locais (alvo 14)** | `style-guide.md` §5.1 (Aprovado) |
| Duração da noite | `Q-044` | **20, 21, 22, 23, 24, 26, 27, 28, 29, 30 min** | DEC-127 |

### 0.2 Versão 2

| Tema | Antes | Agora | Origem |
|---|---|---|---|
| Estado da run fora do servidor | nada (só ponteiros) | **snapshot no MemoryStore** a cada início de turno; retomada em 15 min | DEC-080 (emenda DEC-067) |
| Snapshot da noite (DEC-053) | por Service, em memória | **o mesmo snapshot de turno** serve à noite repetida e à retomada | T12 revista |
| Gemas | creditadas no resumo | **creditadas e salvas por evento**, com chave de idempotência por run | DEC-104 |
| Day 100 | maior Day numa run | **contador persistido** de dias de modo infinito, entre sessões | DEC-084 |
| Anti-AFK | — | gema de dia exige ≥ 3 pedidos completos da party | DEC-083 |
| XP | não havia | confirmado fora | DEC-081 |
| Sanidade 0 | banco do trailer, volta no turno seguinte | **desmaio (animação) → ambulância → reviver pago ou spectate até o fim da run**; janela de 10 s quando todos caem (v3: prazo 6:00 AM, limite 2, volta na noite repetida) | DEC-091, DEC-093, DEC-094, DEC-102, DEC-111, DEC-115, DEC-129 |
| Monetização | fora do MVP | **developer product de reviver** (ProcessReceipt idempotente) | DEC-092 |
| Trânsito | não havia | **carros andando**, atropelamento em ragdoll, derruba item | DEC-087, DEC-095, DEC-103 |
| Compra de upgrade | prompt no equipamento | **bancada do Mart**; básicos fixos, especiais sorteados por turno | DEC-101, DEC-106 |
| Cutscene | câmera de rig, packet | **1ª pessoa compartilhada**, avatares visíveis, set com voto de pular | DEC-078, DEC-088 |
| Personagens | R15 proposto | **R6 para todos**; 1ª pessoa padrão sem braços | DEC-089, DEC-097 |
| Atrasado na janela de 60 s | fica fora | **entra depois** | DEC-098 |
| IDs de anomalia | rótulo N1–N10 | `ANM-001`…`ANM-010` | DEC-096 |
| Celular de referência | Android 3 GB / iPhone 8 | **adiado**; metas viram alvo de Rascunho | DEC-090 |

## 1. Topologia: dois places, um código

| Place | Tipo de servidor | MaxPlayers | Papel |
|---|---|---|---|
| **Lobby** (start place) | público | 24 (ajustável) | perfil, loja de classes, party, oferta de reconexão/retomada, teleporte, recibos pendentes |
| **Run** | **reservado** (`TeleportService:ReserveServer`), um por party | **4** | a run inteira |

Mesmo código nos dois (mesmo `rogen build` + `rojo`); cada place tem o seu mapa (Workspace não é gerido pelo Rojo).
Papel do place: atributo `Workspace.PlaceRole` (`"Lobby"`/`"Run"`). No Studio, Run sem `PrivateServerId` sobe em
**modo de desenvolvimento** (roster = quem entrar, sem MemoryStore, snapshot só em memória).

### 1.1 Configuração de place (não é código; checklist do level-designer/usuário no Studio)

| Configuração | Lobby | Run | Origem |
|---|---|---|---|
| Avatar | R6 forçado (Game Settings → Avatar) | R6 forçado | DEC-089, DEC-097 — **emendado por DEC-146**: jogador sem avatar próprio, personagem da crew (ver nota abaixo) |
| `StarterPlayer.CameraMode` | `LockFirstPerson` | `LockFirstPerson` | DEC-039, DEC-097 |
| `Players.CharacterAutoLoads` | true | **false** (spawn controlado: atrasado, revive, retomada, spectate) | DEC-091, DEC-098 |
| `StreamingEnabled` | true | true, `StreamingMinRadius` 256, `StreamingTargetRadius` 512; gameplay `Persistent` (§12.4, `Q-087`) | |
| Grupos de colisão | `Players` não colide com `Players` | idem + `Npc` não colide com `Players`/`Npc` | `Q-086` |
| Developer product "Revive" | criado no Creator Hub (id em `Content.Products`) | mesmo | DEC-092 |
| Badge "Day 100" | criado no Creator Hub | — | DEC-070, DEC-084 |

> **DEC-146 / DEC-147 (2026-10-10), nota do secretário — a resolver pelo architect:** o jogador **não usa o avatar do Roblox**; joga com o animal da HotDog Crew (corpo base R6 custom + peças do animal + uniforme), e **animal = classe** (`CLS-###`). Pontos: personagem por **StarterCharacter custom** ou montagem no `CharacterService` (com T25 `CharacterAutoLoads = false`); **Humanoid R6**; nenhuma aparência do avatar aplicada (sem `HumanoidDescription` do jogador); animal escolhido no lobby e levado à run (classe já persistida, DEC-069); ragdoll T22, Tool (`RightGripAttachment`), maca (DEC-143) e animações no rig custom; cutscene "avatares visíveis" → personagens da crew. NPCs clientes seguem R6 de plataforma (T11). Técnica nova vai à lista da `Q-130` como Provisória. Medidas do corpo: `Q-144`.

## 2. Mapa de features

Feature = pasta `src/<Feature>/` com `server/` e/ou `client/`. Arquivo na raiz da feature vai para
`ReplicatedStorage.shared.<Feature>`. Módulo com mais de um arquivo é pasta com `init.luau`.
Legenda: **E** = existe e será estendido; **N** = novo. Place: L, R, L+R.

### 2.1 Infraestrutura

| Feature | Server | Client | Place | Responsabilidade |
|---|---|---|---|---|
| `Net` (E, sem mudança) | `NetService` | `NetController` | L+R | `Lync.start/flush/close`, `Ready`, grupo `Audience` |
| `Player` (E, sem mudança) | `PlayerService` | — | L+R | sinais de entrada/saída e personagem |
| `Place` (N) | `PlaceService` | `PlaceController` | L+R | `Is("Lobby"/"Run")`, `IsDev()` |
| `Profile` (E) | `ProfileService` + `Template` + `Migrations` | `ProfileController` | L+R | ProfileStore; **save agrupado por evento** (`RequestSave`, §10.3) |
| `Monetization` (N) | `MonetizationService` | — | L+R | **único** `ProcessReceipt`; ledger idempotente no perfil; despacha por tipo de produto (§10) |
| `Session` (N) | `SessionService` | `SessionController` | L+R | MemoryStore (ponteiros, roster, batimento, **snapshot**), teleporte com retry, oferta de reconexão/retomada |
| `Input` (E) | — | `InputController` | L+R | `DeviceSettings` portado; botão fixo de interagir no mobile |
| `Interface` (E) | — | componentes Vide + stories | L+R | `ProgressBar`, `PromptBillboard`, `Toast`, `Countdown`, `UseTween` |
| `Content` (N, `src/Shared/Content`) | — | — | L+R | tabelas (`content-data.md`) |

### 2.2 Lobby

| Feature | Server | Client | Place | Responsabilidade |
|---|---|---|---|---|
| `Party` (N) | `PartyService` | `PartyController` | L | formar party 1–4, pronto, iniciar |
| `Class` (N) | `ClassService` | `ClassController` | L+R | L: comprar/selecionar com gemas. R: aplicar modificadores |

### 2.3 Run

| Feature | Server | Client | Responsabilidade |
|---|---|---|---|
| `Run` (N) | `RunStateService` | `RunStateController` | roster, membros, `EverJoined` por membro, **`PriceParty`** (fixado no fim do Day 1, DEC-121), chances (1, DEC-110), fim da run, **registro de snapshot** (§7) |
| `Round` (E) | `RoundService` | `RoundController` | ciclo de turnos, fases, relógio, Day/Night, modo infinito, noite perdida/repetida |
| `Economy` (N) | `EconomyService` | `EconomyController` | caixa, gaveta, preço do pedido, gorjeta, nota, **ledger do turno** (pedidos completos para o anti-AFK) |
| `Interaction` (N) | `InteractionService` | `PromptController` + `Prompt` | prompt custom (DEC-066); **único** responder de `Interact` |
| `Item` (N) | `ItemService` | `ItemController` | Tools (pacotes, Coffee, HotDog, **Revive**), contagem, limite, **stash** (sair, cair, respawn), **item derrubado** no mundo |
| `Character` (N) | `CharacterService` | `CharacterController` | spawn controlado (`LoadCharacter`), grupo de colisão, **ragdoll R6 só no atropelamento** (juntas pré-montadas), **desmaio por animação** (sanidade 0), "atordoado até", controles desligados em cutscene |
| `Kitchen` (N) | `KitchenService` + módulos `Stations/*.luau` (§18.12) | `KitchenController` + visuais | estoque, estações, montagem, restock |
| `Market` (N) | `MarketService` (prateleiras e vagas da bancada são âncoras `Interactable`, §18.4) | `MarketController` | prateleiras (pacotes), **bancada** (upgrades básicos sempre à venda + **1 vaga especial** sorteada por turno, DEC-106). O Food Trailer **não** passa aqui (DEC-107) |
| `Upgrade` (N) | `UpgradeService` | `UpgradeController` | nível por upgrade, efeito, peça visível; **compra delegada pela bancada** |
| `Vehicle` (N) | `VehicleService` | — | carrinho → trailer; **prompt de compra no próprio trailer** no estacionamento a partir do dia 5 (DEC-107, FEAT-016), preço × `PriceParty`; troca no fim do turno |
| `Npc` (N) | `NpcService` + `Walker` | `NpcController` | pool R6, teto de 12, rotas por grafo, LOD; nó de faixa pede reserva ao `TrafficService` (DEC-133, §8.1) |
| `Traffic` (N) | `TrafficService` | `TrafficController` | carros (set) com cinemática 1D e paradas (PARE, faixa reservada), reserva da caixa `X-T` e das faixas para NPC, validação de atropelamento (§8). Sem semáforo (DEC-130); paradas por DEC-133 |
| `Customer` (N) | `CustomerService` + `Customer` | `CustomerController` | fluxo, fila, pedido, paciência, pagamento |
| `Thief` (N) | `ThiefService` | — | ladrão de dia |
| `Vital` (E) | `VitalService` + `Vital` | `VitalController` | sanidade **e estado de vida** (Active, Down, Reviving, Spectator, Away), prazo 6:00 AM, contagem de revives da noite, janela de 10 s (§6) |
| `Ambulance` (N) | `AmbulanceService` | `AmbulanceController` | **uma ambulância por servidor** com fila de viagens (coleta: médicos descem e levam o corpo, DEC-114; volta do reviver: ninguém desce, DEC-091), timeline replicada; ambulância e médicos só no client |
| `Revive` (N) | `ReviveService` | `ReviveController` | pedidos de reviver (Robux só para si, Kit, crédito), intenção de compra, créditos, limite 2 por noite, validação; UI de oferta enquanto `Down` |
| `Anomaly` (N) | `AnomalyService` + componentes + `Rules` (só servidor) | `AnomalyController` | agenda da noite, atores, verbos, regra crítica (só ANM-007) |
| `Hallucination` (N) | — | `HallucinationController` | efeitos só client |
| `Boss` (N) | `BossService` | `BossController` | ligações (não puláveis, não repetíveis, DEC-077) |
| `Reward` (N) | `RewardService` | — | gemas **por evento**, anti-AFK, contador Day 100, achievements, badge (§10.4) |
| `Camera` (N) | — | `CameraController` | 1ª pessoa padrão; **spectate** (colega em 1ª pessoa, troca de alvo); POV de cutscene |
| `Cutscene` (N) | `CutsceneService` | `CutsceneController` | intro e final **compartilhadas em 1ª pessoa**, marcas para 1–4 avatares, voto de pular, entrada no meio (§11) |
| `Hud` (N) | — | `HudController` | sanidade, relógio, Day/Night, dinheiro, toasts, contador de 10 s, resumo, oferta de reconexão |

Opal (CHR-003, DEC-079): **sem Service próprio**. Modelo ancorado no mapa com `AnimationController` (sem Humanoid),
idle no client; fala em balão escolhida **localmente** pelo client ao entrar na zona do Mart, por fase (dia,
noites 1–3, 4–6, 7–10). Zero rede, fora do teto de NPCs (`Q-091` a).

Fora do MVP, sem pasta: resto da monetização (`Q-017`), lanterna, decoração com dinheiro (DEC-082).

### 2.4 Por que estender e não criar paralelo

| Existente | Vira | Motivo |
|---|---|---|
| `VitalService` / `Vital` / `Vitals` | sanidade **+ estado de vida** | já é "valor por jogador, replicado, com morte e volta". O estado Down/Spectator é a "morte" do template; reviver é a "volta" |
| `RoundService` / `RoundController` | ciclo de turnos | já é "fases com tempo em atom, publicado por effect". Packet `Round` vira set `Shift` |
| `ProfileService` / `Template` | gemas, classes, Day 100, créditos, recibos | perfil reativo já persiste e replica. Ganha migração e `RequestSave` |
| `InputController` | interagir | `ContextActionService` do prompt portado passa por `InputController:Bind` |

Reviver **não** é Service paralelo ao `VitalService`: `ReviveService` só decide **se** e **como pagar**; quem muda o
estado é `VitalService:Revive(target, source)`. `AmbulanceService` só apresenta.

## 3. Prioridades de boot e dependências

Loader: todos os `OnInit` por prioridade decrescente, depois todos os `OnStart`. **`Require` injeta, não ordena.**
Quem usa estado de outro no próprio `OnInit` precisa de prioridade menor. `effect` que escreve em Lync nasce no
`OnStart`. Responder de rede só em Service/Controller, no `OnInit`.

### 3.1 Servidor

| Prioridade | Service | Require | Place | Notas |
|---|---|---|---|---|
| 1000 | `NetService` | — | L+R | existente |
| 950 | `PlaceService` | — | L+R | |
| 900 | `PlayerService` | — | L+R | existente |
| 800 | `ProfileService` | PlayerService, NetService | L+R | +migração, +`RequestSave` |
| 790 | `MonetizationService` | ProfileService, PlaceService | L+R | `ProcessReceipt` no `OnStart`; handlers registrados por outros no `OnInit` (prioridade menor) |
| 780 | `SessionService` | PlaceService, PlayerService, NetService | L+R | MemoryStore, TeleportService |
| 760 | `RunStateService` | PlaceService, SessionService, PlayerService, ProfileService, NetService | R | roster, membros, registro de snapshot |
| 750 | `RoundService` | NetService, RunStateService, VitalService | R | sinais de fase criados no `Setup` |
| 740 | `EconomyService` | RunStateService, RoundService, NetService | R | |
| 730 | `InteractionService` | PlayerService, RunStateService, NetService | R | |
| 720 | `ItemService` | PlayerService, RunStateService, InteractionService | R | stash, item derrubado |
| 715 | `CharacterService` | PlayerService, RunStateService, ItemService | R | spawn, desmaio (animação), ragdoll (só atropelamento), colisão |
| 700 | `VitalService` | PlayerService, RunStateService, RoundService, CharacterService, NetService | R | sanidade + vida |
| 690 | `ClassService` | ProfileService, PlaceService, NetService | L+R | |
| 680 | `PartyService` | PlaceService, SessionService, ProfileService, NetService | L | |
| 650 | `KitchenService` | InteractionService, ItemService, EconomyService, ClassService | R | |
| 630 | `UpgradeService` | EconomyService, RunStateService | R | sem prompt próprio (DEC-101) |
| 620 | `VehicleService` | InteractionService, EconomyService, UpgradeService, RunStateService | R | compra do trailer pelo prompt no próprio trailer (DEC-107) |
| 615 | `MarketService` | InteractionService, ItemService, EconomyService, UpgradeService, VehicleService, RoundService, RunStateService | R | prateleiras + bancada; `VehicleService` só para saber se o trailer já foi comprado (Trailer Lights e Revive Kit, DEC-106, DEC-129) |
| 610 | `NpcService` | TrafficService (reserva/liberação de faixa em jogo, DEC-133) | R | |
| 600 | `TrafficService` | RoundService, CharacterService, ItemService, RunStateService, NetService | R | |
| 590 | `CustomerService` | NpcService, KitchenService, EconomyService, RoundService, InteractionService | R | |
| 580 | `ThiefService` | NpcService, EconomyService, RoundService | R | |
| 570 | `AnomalyService` | NpcService, RoundService, VitalService, InteractionService, CustomerService | R | |
| 565 | `AmbulanceService` | VitalService, CharacterService, RoundService, NetService | R | uma ambulância, fila de viagens |
| 560 | `BossService` | RoundService, NetService | R | |
| 555 | `ReviveService` | VitalService, AmbulanceService, MonetizationService, ItemService, RunStateService, NetService | R | |
| 550 | `RewardService` | ProfileService, RoundService, RunStateService, EconomyService | R | |
| 540 | `CutsceneService` | RoundService, CharacterService, RunStateService, NetService | R | |

`NpcService` (610) requer `TrafficService` (600): só chama `TrafficService:ReserveCrossing(crosswalk, npcId)` e
`TrafficService:ReleaseCrossing(crosswalk, npcId)` em tempo de jogo, nunca no `OnInit`; permitido pela regra ("Require
injeta, não ordena"). `TrafficService` não conhece `NpcService` (dependência num sentido só; a reserva expira sozinha).

Gating por papel: Service só R (ou só L) retorna no topo do `OnInit`/`OnStart` se o papel não bate. Exceção:
`MonetizationService` e `ReviveService` registram o handler de produto **nos dois places**: no lobby, o recibo de
reviver vira crédito (§10.2). `ReviveService` portanto é L+R no registro do handler e R no resto.

### 3.2 Client

| Prioridade | Controller | Notas |
|---|---|---|
| 1000 | `NetController` | existente |
| 950 | `PlaceController` | |
| 900 | `InputController` | existente |
| 800 | `ProfileController`, `VitalController`, `RoundController` | trocam o schema |
| 790 | `RunStateController`, `EconomyController` | |
| 780 | `SessionController` | oferta de reconexão/retomada (L) |
| 720 | `CharacterController` | ragdoll previsto localmente, controles |
| 700 | `PromptController` | |
| 690 | `CameraController` | 1ª pessoa, spectate, cutscene |
| 680 | `ItemController`, `KitchenController`, `CustomerController`, `NpcController`, `UpgradeController`, `MarketController`, `TrafficController` | |
| 670 | `AmbulanceController`, `ReviveController` | |
| 660 | `AnomalyController`, `BossController`, `CutsceneController` | |
| 650 | `PartyController`, `ClassController` | L |
| 600 | `HallucinationController` | |
| 500 | `HudController` | monta a árvore Vide no `OnStart` |

## 4. Fluxo de dados

```
            client                                     server
 ┌──────────────────────────┐                ┌─────────────────────────────────────┐
 │ PromptController (hold)  │── Interact ───▶│ InteractionService (único responder)│
 │ CameraController         │── Gaze 10 Hz ─▶│ AnomalyService (visão)              │
 │ CharacterController      │── CarHit ─────▶│ TrafficService (valida plausível)   │
 │ ReviveController         │── Revive ─────▶│ ReviveService → Monetization / Item │
 │ CutsceneController       │── SkipVote ───▶│ CutsceneService                     │
 │                          │                │  donos únicos mudam atoms Charm     │
 │ Vide sources ◀─ sets ────│◀── Lync sets ──│  effect (OnStart) → set:update      │
 │ HUD, bolhas, carros,     │◀── packets ────│  Notice, Sale, ShiftReport, BossCall│
 │ ambulância (simulados    │                │  AnomalyCue, LifeEvent              │
 │ localmente por tempo)    │                │ MarketplaceService.ProcessReceipt   │
 └──────────────────────────┘                │  → MonetizationService (único)      │
                                             │ MemoryStore ◀── SessionService      │
                                             │ DataStore   ◀── ProfileService      │
                                             └─────────────────────────────────────┘
```

Regras:
1. **Um dono por estado.** Só `EconomyService` escreve `Cash`; outros chamam `Spend(amount): boolean`.
2. **Client nunca decide resultado.** Venda, estoque, sanidade, vida, verbo, gemas, compra, revive: servidor.
   O client **prevê** só apresentação (ragdoll local imediato no atropelamento, barra interpolada).
3. **Tempo por `StartedAt/Duration`** em `workspace:GetServerTimeNow()`. Vale para barras, carros, ambulância e
   cutscene: o servidor replica o início; o client calcula a posição. Nada por frame na rede.
4. **IDs numéricos de entidade** (`EntityId`); nunca `Instance` vinda do client.
5. **Sem acoplamento escondido.** `self.Dependencies.X` declarado; sinais para "aconteceu", métodos para "faça".
6. **Aleatoriedade com semente da run.** Sorteios que afetam o jogo (oferta da bancada, pedidos, agenda de
   anomalia, agenda de carros) usam `Random.new(hash(RunSeed, Day, IsNight, Attempt, domínio))`. A oferta da
   bancada é sorteada uma vez por turno e **guardada no snapshot** (FEAT-035): retomada e noite repetida mostram a
   mesma oferta; sair e voltar não "rerrola" a bancada.

### 4.1 Sinais

| Sinal | Dono | Quando | Quem escuta |
|---|---|---|---|
| `PhaseChanged(phase, day, night)` | RoundService | troca de fase | Customer, Thief, Anomaly, Boss, Cutscene, Kitchen, Traffic, Market |
| `ShiftStarted(info)` / `ShiftEnded(info, report)` | RoundService | início/fim de turno | Economy, Reward, Vital, Market (nova oferta), RunState (snapshot) |
| `NightLost(reason)` | RoundService | regra crítica ou janela de 10 s esgotada | RunState (restaura com todos `Active` ou encerra a run se `Chances = 0`, §7), Ambulance (viagem `Dawn`), Boss |
| `MemberStateChanged(uid, old, new)` | VitalService | Active/Down/Reviving/Spectator/Away | Round ("todos caídos"), Ambulance, Revive, Camera (via set), Reward |
| `Wipe(started: boolean, endsAt)` | VitalService | último de pé caiu / janela fechou | Round, Revive, Hud (via set) |
| `RewardEvent(key, kind, members)` | RoundService/Economy | dia concluído, nota A, noite vencida, final, dia infinito | Reward |

## 5. Lobby → servidor reservado → reconexão → retomada (resposta completa a Q-058)

### 5.1 Resumo da resposta

| Item de Q-058 | Resposta |
|---|---|
| (a) Lobby descobre a run | HashMap `PlayerRun[UserId]` → `Runs[RunId]` (§5.2, `data.md` §3) |
| (b) Volta ao **mesmo** servidor | `TeleportAsync` com o `ReservedServerAccessCode` guardado. Se o servidor ainda vive, entra nele; se fechou, o Roblox sobe **um servidor novo com o mesmo `PrivateServerId`**, que é exatamente o caminho da retomada (§5.5) |
| (c) Bloquear quem não começou | roster gravado pelo lobby no MemoryStore; chegada fora do roster volta ao lobby. `TeleportData` não é usado para autorização |
| (d) Quanto tempo o estado de um desconectado fica | **até o fim da run** enquanto o servidor vive (membro `Away` em memória). Se todos saem, o estado vai no snapshot por 15 min |
| (e) Saída voluntária x queda | **valem as duas.** O servidor não distingue (`PlayerRemoving` é igual) e DEC-080 diz "se todos saírem". Sem botão "abandonar run" no MVP; a oferta expira sozinha em 15 min ou é sobrescrita se o jogador começa outra run |
| (f) O que o snapshot guarda | estado de **início do turno corrente** (`data.md` §3.3): run, turno, caixa, estoque, upgrades, veículo, chances, `PriceParty`, oferta especial da bancada, membros (classe, vivo/espectador, Tools), contadores da run. ~1–1,6 KB |
| (g) Como o lobby oferece | mesma notificação de DEC-063, com modo `Live` ("Rejoin") ou `Suspended` ("Resume Day 7 — 12:40 left") (§5.4) |
| Extra: servidor caiu sem `BindToClose` | mesma retomada (o batimento para; o registro sobrevive 16 min). **Decidido: DEC-119** (T16) |

### 5.2 Iniciar a run

```
Lobby (PartyService: dono aperta Start, todos prontos)
 1. SessionService:ReserveRun() → ReserveServer(RunPlaceId) → (code, privateServerId); RunId = privateServerId
 2. Runs[RunId] = {State="Starting", Code, Roster, Seed, CreatedAt}                     TTL 300 s
    PlayerRun[uid] = {RunId, Code} por membro                                           TTL 960 s
 3. TeleportAsync(RunPlaceId, players, {ReservedServerAccessCode=code}); 3 tentativas (2/5/10 s)
Run
 4. Boot: lê Runs[PrivateServerId]. Casos em §5.5. Primeiro boot: State = Starting.
 5. Claim (UpdateAsync): JobId = game.JobId. Janela de entrada 60 s ou todos chegarem.
 6. Run começa com quem chegou (DEC-098: o resto entra quando chegar). State = "Live".
    Snapshot inicial (§7) + batimento a cada 30 s (Runs TTL 960 s).
```

### 5.3 Sair, reconectar, chegar atrasado

```
Run: jogador sai (PlayerRemoving)
 - Member.State = Away; ItemService guarda Tools (stash); sanidade e estado de vida guardados.
 - Conectados ≥ 1 → run segue; relógio não pausa (DEC-085 a). Away não conta para "todos caídos" (DEC-085 c).
 - Conectados = 0 → Suspend() (§5.5).
Lobby: jogador entra → oferta (§5.4) → "Rejoin" → TeleportAsync com o mesmo código.
Run: jogador chega
 - No Roster e State = Live → restaura (Tools do stash; estado; spawn no veículo ou spectate).
 - No Roster, nunca entrou (atrasado, DEC-098) → entra como membro novo do roster (§5.6).
 - Fora do Roster → volta ao lobby ("This shift is already running.").
```

### 5.4 Oferta no lobby

Ordem de leitura: `PlayerRun[uid]` → `Runs[RunId]` → `uid ∈ Roster`. Decisão:

| `Runs.State` | Condição | Oferta |
|---|---|---|
| `Live` | `now − UpdatedAt < 90 s` | **Rejoin** (run viva com colegas) |
| `Live` | `now − UpdatedAt ≥ 90 s` (servidor caiu sem `BindToClose`) | **Resume**, prazo = `UpdatedAt + 900` |
| `Suspended` | `now < ExpiresAt` | **Resume**, prazo = `ExpiresAt` |
| `Resuming` | `now − UpdatedAt < 90 s` | **Rejoin** (outro colega já está retomando) |
| `Starting` | `now − CreatedAt < 300 s` | **Rejoin** (teleporte inicial falhou para ele) |
| qualquer outro / registro ausente | — | sem oferta |

Packet `Reconnect` (`network.md` §6) com `Mode`, Day/Night e segundos restantes. Fechar a notificação só esconde.
MemoryStore fora do ar: sem oferta, com log (R15).

### 5.5 Suspender e retomar (DEC-080)

```
Suspender (servidor da run)
 - Gatilho: último conectado sai, ou BindToClose com run viva (atualização com restart, desligamento).
 - Runs[RunId]: State="Suspended", ExpiresAt=now+900, Connected={}               TTL 960 s
 - Snap[RunId]: reescreve o snapshot do início do turno corrente com TTL 960 s.
 - PlayerRun de cada membro do roster: TTL 960 s.
 - Gemas já creditadas ficam (DEC-104). O turno em andamento é descartado.
Retomar (servidor novo com o mesmo PrivateServerId, subido pelo teleporte do primeiro que volta)
 1. Boot lê Runs[RunId]:
    - Suspended e now < ExpiresAt                  → retomável
    - Live e now − UpdatedAt ≥ 90 s (queda)        → retomável
    - Live/Resuming com batimento recente e JobId ≠ o meu → outro servidor é dono: devolve ao lobby (raro)
    - Starting                                       → boot normal (§5.2)
    - Ended / ausente / expirado                     → "That shift has ended." e volta ao lobby
 2. Claim atômico (UpdateAsync): State="Resuming", JobId=game.JobId. Perdeu o claim → devolve ao lobby.
 3. GetAsync Snap[RunId]. V desconhecido ou ausente → "That shift can't be resumed." e Ended.
 4. RunStateService:Restore(snapshot) → cada Service restaura o seu pedaço (§7).
 5. Fase `Resume` (15 s, tabela): espera colegas, mostra "Resuming Day 7". Depois o turno recomeça do início.
 6. State="Live", batimento normal. Os outros membros passam a ver "Rejoin".
Expirou (ninguém voltou em 15 min): o TTL apaga os registros; nada a limpar (DEC-080: run encerrada).
```

Consequências diretas, sem regra nova: o turno interrompido recomeça (dinheiro e eventos depois do snapshot se
perdem, DEC-080); gema de evento já ocorrido não é paga de novo graças à chave de idempotência (§10.4).

### 5.6 Membro atrasado (DEC-098, resposta técnica a Q-112)

| Item | Recomendação | Por quê |
|---|---|---|
| (a) Tamanho da party para preços (DEC-047) | **Decidido (DEC-121)**: `PriceParty` = membros do roster com `EverJoined = true` **no fim do Day 1** (no `ShiftEnded` do Day 1, antes da captura do snapshot). **Fixo** dali em diante: não sobe com atrasado, não desce com quem sai. Vale para o trailer e para o Revive Kit (DEC-129). Antes de fixado vale 0 (nenhum preço por party existe no Day 1) | atrasado do Day 1 conta; quem nunca chega não encarece |
| (b) Até quando pode entrar | **a qualquer momento** enquanto a run estiver `Live`, `Resuming` ou `Suspended` (o caminho é o mesmo da reconexão) | é só um membro do roster que ainda não tinha chegado |
| (c) Cutscene de abertura | se a intro ainda está tocando, **entra nela** no ponto atual (a timeline é função do tempo, §11); senão spawna direto no veículo | sincronização por `StartedAt` torna o "pular para o ponto atual" gratuito |
| (d) Voto de pular e fluxo | voto de pular conta **conectados** no momento. Fluxo de clientes: **ativos no início do turno** (conectados e não espectadores), proposta de FEAT-009 para `Q-067` (`Flow.PartySource = "ActiveAtShiftStart"`) | o fluxo é recalculado no `ShiftStarted`; trocar a fonte é uma linha de tabela |

## 6. Vida do jogador: sanidade, desmaio, ambulância, reviver, spectate

Regras de design que este capítulo implementa: DEC-091 a DEC-094, DEC-102, DEC-111, DEC-113 a DEC-118, DEC-129;
FEAT-025, FEAT-034 (Rascunho, números). Sanidade só existe à noite (DEC-056): os estados Down e Reviving só ocorrem à
noite.

### 6.1 Estados (dono: `VitalService`; replicado em `Vitals.State`)

```
  Active ── sanidade 0, revives da noite < 2 ──────────────▶ Down
  Active ── sanidade 0, já usou 2 revives na noite ────────▶ Spectator   (na hora, sem oferta; DEC-129)
  Down   ── reviver aceito (Robux próprio, Kit, crédito) ──▶ Reviving ── ambulância volta ──▶ Active (em pé em REV-n)
  Down   ── 6:00 AM da noite da queda, sem reviver ────────▶ Spectator   (DEC-115)
  Spectator ── só no restore da noite repetida ────────────▶ Active      (todos voltam; DEC-111, DEC-113)
  Qualquer estado ── sai ──▶ Away (guarda o anterior) ── volta ──▶ anterior
```

**Spectator nunca é revivido** (DEC-115, DEC-113): nenhum método de `Revive` aceita alvo `Spectator`, nem na janela
de 10 s. Não há transição Spectator → Reviving.

| Transição | Servidor faz | Client vê |
|---|---|---|
| Active → Down | sanidade 0 e `RevivesTonight < Revive.MaxPerNight`. `CharacterService:Faint(player)`: controles desligados, prompts em curso cancelados, **animação de desmaio** (senta e deita de lado, ~1,2 s; `style-guide.md` §4.6, Aprovado: **não é ragdoll**); no fim o `HumanoidRootPart` fica **ancorado** na pose deitada. Stash das Tools. `AmbulanceService:RequestPickup(uid, bodyPos)`. `Vitals.StateEndsAt` = instante de servidor das **6:00 AM** desta noite | `LifeEvent{Down}`; balão "Zzz", visão desbota e escurece; oferta de reviver no spectate |
| Active → Spectator (3ª queda) | sanidade 0 com `RevivesTonight = 2` (DEC-129): mesmo desmaio e mesma coleta, **sem oferta** | `LifeEvent{Spectating}` |
| Down (coleta) | viagem de coleta (§6.3); no `Load`, o personagem é destruído (`player.Character = nil`) | médicos descem e levam o corpo (DEC-114); câmera de spectate |
| Down → Reviving | `ReviveService` aceitou (§6.4); `RevivesTonight += 1`; `AmbulanceService:RequestReturn(uid)` | ambulância volta e para em `AMB-P` |
| Reviving → Active | no `Drop`: `CharacterService:Spawn(player, "REV-n")` em pé ao lado da ambulância; sanidade = `floor(Revive.SanityPct × máx. da classe)`; proteção de escuro `Revive.ProtectTime`; Tools do stash | `LifeEvent{Revived}`; ambulância sai **sem ninguém descer** (DEC-091) |
| Down → Spectator | chegou **6:00 AM** (`NightEnd`) sem reviver (DEC-115). Reviving em andamento termina antes (vira Active) | spectate até o fim da run |
| Spectator → Active | **só** no restore da noite repetida (§7). Noite vencida não devolve ninguém (DEC-113) | aparece com o resto da party |

`RevivesTonight` é campo do membro, zerado no início de cada noite (a captura do snapshot já o leva a 0).

### 6.2 Todos caídos (DEC-094, DEC-102, DEC-118)

- "Presentes" = membros conectados (Active, Down, Reviving, Spectator). Away não conta (DEC-085 c).
- Nenhum presente `Active` nem `Reviving` → `Wipe(true, now + Revive.WipeWindow)`; `Shift.WipeEndsAt` replica o
  contador de 10 s.
- **Congelamento (DEC-118)**: enquanto algum caído presente tem prompt de compra de reviver aberto (intenção
  registrada e `PromptProductPurchaseFinished` ainda não chegou), o contador para (`Shift.WipeFrozen = true`) e
  `WipeEndsAt` é empurrado pelo tempo parado. Extensão total ≤ `Revive.WipeFreezeMax` (20 s). Depois do teto o
  contador volta a correr mesmo com prompt aberto. Máximo real: 30 s.
- Quem pode reviver na janela: cada `Down` **por si** (Robux próprio, Kit próprio, crédito próprio). Spectator não.
- O primeiro reviver aceito (estado vira Reviving) fecha a janela com sucesso; os outros seguem `Down` até 6:00 AM.
- Membro do roster que aparece `Active` durante a janela (atrasado, reconexão) também a fecha com sucesso.
- Janela esgotada → `NightLost("wipe")` → §7 (gasta a chance ou encerra a run).
- Regra crítica (ANM-007) perde a noite **direto**, sem janela (DEC-094).
- Recibo que chega depois de a janela fechar ou de a noite ser perdida vira crédito no perfil (DEC-117, §10.2).

### 6.3 Ambulância (sequência, não NPC)

- Ambulância e médicos **não são NPCs do servidor**: atores roteirizados renderizados no client a partir do set
  `Ambulance` (registro único: viagem, fase, `StartedAt`, parada, corpos). Não contam no teto de 12 NPCs. A
  ambulância ocupa 1 vaga no teto de **veículos** (FEAT-034).
- **Uma ambulância por servidor** (FEAT-034, NPC-023, `MAP-01.md` §9.6). `AmbulanceService` mantém uma **fila de
  viagens** (FIFO). Uma viagem de coleta pode servir várias quedas: para em `AMB-M` e depois em `AMB-P` na mesma
  passada (oeste → leste, MAP-01). Quem cai enquanto ela está parada na mesma parada (≤ `Ambulance.Reach`) entra
  nela; senão, entra na próxima viagem.
- Paradas (`MAP-01.md` §5.5): `AMB-M` (queda a oeste de X −24: praça, SS, Mart) e `AMB-P` (resto; em frente ao
  trailer; **parada do reviver**). Pontos de aparecer: `REV-1..4`.
- **Coleta (DEC-114)**: os 2 médicos (NPC-024, R6) **descem**, andam até o corpo e o levam na maca. O caminho dos
  médicos é calculado **no client** sobre o mesmo grafo `NpcNode` (A* determinístico: mesma entrada, mesmo
  caminho); o servidor só manda parada e posição do corpo. Corpo fora de alcance: caso de FEAT-034 (Rascunho,
  game-designer), parâmetro `Ambulance.Reach`.
- **Volta do reviver (DEC-091)**: para em `AMB-P`, o jogador aparece em `REV-n`, ninguém desce.
- **Noite perdida (DEC-122)**: viagem `Dawn`: a ambulância está parada em `AMB-P` e parte **com a sirene desligada**
  enquanto todos aparecem em pé ao lado do trailer (§7).
- Tempos: tabela `Ambulance` (`content-data.md` §3.13, números de FEAT-034).
- Espera: não despacha enquanto ANM-008 ou ANM-010 estão ativas (FEAT-034; `Ambulance.HoldDuring`).
- **A ambulância não atropela** (sem detecção de colisão; `Q-122` c). É roteirizada: não entra na agenda de carros; o `TrafficService` reserva para ela as zonas que cruza (`AMB-*` declara): carro da Ninth que chegaria à zona na janela não nasce; carro da Juniper espera no PARE (DEC-133). Reserva de faixa para NPC não é dada com a ambulância a < 15 studs (§8.1).
- Durante anomalia: é apresentação; não interage com atores.

### 6.4 Reviver (Robux, Revive Kit, crédito)

Validação comum a todo método (`ReviveService`): alvo `Down` (nunca Spectator nem Reviving), relógio antes das
6:00 AM da noite da queda (DEC-115), `RevivesTonight < Revive.MaxPerNight` (2; Robux, Kit e crédito somam, DEC-129).

| Caminho | Fluxo | Dono |
|---|---|---|
| Robux (DEC-092, **DEC-116**) | **Só o próprio caído, para si.** `Revive{Target, Method=Robux}` → `ReviveService` exige `Target == remetente` e remetente `Down` → grava **intenção** `{buyer = target, expira Revive.IntentTimeout}` → `MarketplaceService:PromptProductPurchase(buyer, ReviveProductId)` (chamado no servidor) → recibo → `MonetizationService` → handler `Revive`: `ReviveCredits += 1` (salvo) → se a intenção ainda vale, consome o crédito e aplica | Revive + Monetization |
| Revive Kit (ITM-021; DEC-100, DEC-108, DEC-129) | comprado na vaga especial da bancada com **dinheiro da party** × `PriceParty` (`EconomyService:Spend`) → Tool `revive_kit`. Uso (FEAT-034, ainda Rascunho em `Q-120` f): (a) o próprio caído com o Kit no stash: "Use Revive Kit" no spectate → `Revive{Target=self, Method=Item}`; (b) colega `Active` com o Kit na mão ativa a Tool → `Revive{Method=Item}`; o **servidor** escolhe o alvo pela regra da tabela (`Revive.KitTarget`, proposta de FEAT-034: caído mais antigo da party). `ItemService:Consume` | Revive + Item |
| Crédito guardado (DEC-117) | caído com `ReviveCredits > 0`: a oferta mostra "Use saved revive" → `Revive{Target=self, Method=Credit}`. Só para si (o crédito vem de Robux) | Revive + Profile |

Quem pode pagar por quem: Robux e crédito, **só o próprio** (DEC-116; é regra, não flag: mudar exige DEC). Kit: o
próprio ou um colega de pé (`Revive.KitAllowOthers`, proposta de FEAT-034 até `Q-120` f fechar).

## 7. Snapshot de turno (DEC-080 + DEC-053 + DEC-119)

Um só mecanismo atende **três** usos: noite perdida (DEC-053), retomada em 15 min (DEC-080) e queda do servidor
(DEC-119).

- **Registro**: cada Service com estado de run chama, no `OnInit`,
  `RunStateService:RegisterSnapshot(name, capture: () -> table, restore: (table, mode) -> ())`, com
  `mode = "RepeatNight" | "Resume"`. `RunStateService` não conhece os Services (sem dependência circular; T12).
- **Captura**: na fronteira de turno, **depois** de processar o `ShiftEnded` (depósito da gaveta, troca de veículo,
  gemas, fixação de `PriceParty` no fim do Day 1) e antes da fase inicial do turno seguinte (início da Preparação,
  FEAT-002). É o "início do turno corrente" de DEC-080. Também no início da run e no começo da noite repetida.
  Inclui a **oferta especial da bancada** (FEAT-035): noite repetida e retomada não sorteiam de novo.
- **Escrita**: `SessionService` grava `Snap[RunId]` (TTL 2700 s, maior que a noite mais longa, 30 min, + 15 min) a
  cada captura; ao suspender, reescreve com TTL 960 s. Tamanho alvo ≤ 2 KB; teto duro 8 KB (falha alta no Studio).
- **Noite perdida** (`NightLost`): `Chances = 0` → `RunEnd` (DEC-110, DEC-112: 1 chance por run inteira). Senão
  `Chances -= 1` → restaura o snapshot da noite em modo `RepeatNight`:
  - mantém `Chances` (já descontada) e as chaves de gema;
  - **todos os membros voltam `Active`** (DEC-111, DEC-113), inclusive quem já era `Spectator` na captura (caiu em
    noite anterior) e quem estava Down/Reviving/Spectator na noite perdida. `Away` continua `Away`, com
    `StateBeforeAway = Active`;
  - sanidade = início de noite da classe; `RevivesTonight = 0`; fila da ambulância esvaziada; intenções de compra
    pendentes viram crédito quando o recibo chegar (DEC-117);
  - todos aparecem **em pé na calçada ao lado do trailer** (`REV-1..4`), não no banco (DEC-122), enquanto a
    ambulância parte de `AMB-P` com a sirene desligada (viagem `Dawn`);
  - nova captura (noite repetida, `Attempt + 1`).
- **Retomada** (modo `Resume`; jogadores saíram ou o servidor caiu): restaura tudo como capturado, inclusive o
  estado de vida (Spectator segue Spectator).

Conteúdo e formato: `data.md` §3.3.

## 8. Trânsito (DEC-087, DEC-095, DEC-103, DEC-130, **DEC-133**; rodada 17; resposta técnica a Q-102, Q-122, Q-129 e Q-131)

### 8.1 Modelo

DEC-133 (resposta a `Q-129`, opção B) troca "carro nunca para" por "carro nunca para **por jogador**": há parada de
1 s no PARE dos braços da Juniper e parada na linha da faixa quando um NPC tem reserva. A posição deixa de ser função
pura de `StartedAt`; vira função pura do **último registro** do carro (âncora + próxima parada). Isso fecha o lado
técnico de `Q-131`.

| Aspecto | Proposta | Por quê |
|---|---|---|
| Onde roda | **servidor decide, client interpola.** `TrafficService` mantém cada carro como cinemática **1D** (distância ao longo da rota) num tick de **10 Hz** (≤ 4 carros, só aritmética). O set `Traffic` só muda em **evento** (nascer, ganhar/trocar parada, arrancar, sair). Cada client move o modelo local por `CFrame` a partir do registro | carro ancorado movido no servidor replicaria CFrame de várias partes por frame; aqui são ~30 B por evento, ≤ 6 eventos por carro |
| Registro do carro | `{ Route, Look, AnchorAt, AnchorDist, StopDist, HeldUntil }` (`network.md` §3.11). Regra de posição, igual nos dois lados (`Shared/TrafficMotion`, função pura): parte de `AnchorDist` em `AnchorAt` com o perfil de velocidade da rota; se `StopDist > 0`, freia com `Traffic.Crossing.BrakeDecel` para parar **exatamente** em `StopDist` e fica lá até `HeldUntil`; `HeldUntil = 0` = "parado até novo registro"; ao arrancar acelera com `PullAway` | um único formato serve PARE, faixa, fila e reconexão; o client nunca decide parar nem arrancar sozinho além do que o registro já diz |
| Física | carro local, ancorado, `CanCollide = false`, `CanQuery = false` | sem empurrão físico caótico; o "arremesso" é um impulso roteirizado (cômico, controlável) |
| Sem semáforo (DEC-130) | nenhum sinal, nenhum ciclo | DEC-130 continua |
| **Jogador** (DEC-133, DEC-095) | carro **nunca** para nem desvia por jogador, nem na faixa. Nenhuma consulta de posição de jogador entra na decisão de parada | "na sorte": risco do reabastecimento intencional (R22) |
| **PARE** (DEC-133) | toda rota que entra no T por um braço da Juniper (as de TR-3..TR-6 que vêm de `JN-IN`, TR-7, TR-8, TR-10; marcado na tabela por `Stops`) tem a linha `SL-N`/`SL-S` como parada obrigatória. Quando o carro passa a ter o PARE como próxima parada, o servidor grava `StopDist = SL`; ≥ 1,5 s antes da chegada decide a entrada: reserva a caixa `X-T` para `[chegada + 1 s, + tempo de travessia + ConflictGap]` e grava `HeldUntil = chegada + 1 s` (o client arranca sozinho, sem segundo registro). Caixa ocupada → `HeldUntil = 0` e, quando a caixa liberar, novo registro de arrancada. 1 carro por vez de braço da Juniper na caixa | parada fixa de 1 s custa 1 registro; esperar a caixa custa 1 a mais, só quando há conflito |
| **Ninth preferencial** | carros da Ninth (TR-1, TR-2 e trechos Ninth de TR-9/TR-10) **nunca** param no cruzamento. A caixa `X-T` é dada a um carro da Juniper só se nenhum carro da Ninth pode chegar a ela na janela, usando a **chegada mais cedo possível** (perfil sem paradas) de cada carro da Ninth | parada a montante (faixa) só atrasa o carro da Ninth, nunca adianta: a conta conservadora é segura sem fila |
| **Faixa com reserva de NPC** (DEC-133) | `NpcService` pede `TrafficService:ReserveCrossing(cw, npcId)`. Concedida só se: (1) nenhum carro a **< 15 studs** da linha da faixa nos dois sentidos (nem dentro da faixa); (2) passaram **≥ 4 s** desde a última liberação daquela faixa (`Crossing.Cooldown`). Ao conceder, todo carro que ainda vai cruzar a faixa e não tem parada mais próxima recebe `StopDist = linha da faixa` (`SL-1N`/`SL-1S` etc.), `HeldUntil = 0`. `ReleaseCrossing` (NPC saiu da pista) ou expiração grava a arrancada desses carros (`HeldUntil = agora`) | 15 studs > distância de frenagem (22 → 0 em 1 s ≈ 11) + folga: todo carro avisado consegue parar antes da linha |
| Espera máxima | reserva expira em `Crossing.MaxWait` = **4 s** depois da concessão (tempo de NPC na pista 3 s). Se o NPC ainda estiver na pista na expiração, `NpcService` faz `PivotTo` para o nó do meio-fio de destino (failsafe, logado). Nenhum carro espera > 4 s por reserva | DEC-133; o failsafe evita NPC dentro da pista com carro arrancando |
| Anti-bloqueio | carro só passa da linha de uma faixa se há espaço até a próxima parada (ex.: SL-1S → SL-S); senão a parada dele fica **antes** da faixa. **Nenhum carro para dentro da faixa** | FEAT-033 / DEC-133 |
| Fila | carro atrás de carro parado recebe `StopDist = StopDist do líder − Crossing.CarGap` (14 studs); arranca `Crossing.FollowDelay` (0,5 s) depois do líder. Com teto de 4 carros, espera ≤ 4 s e intervalo de 3 s, a fila máxima prática é 2 | fila curta, resolvida no servidor, sem física |
| Spawn (DEC-133) | só nas pontas de entrada das rotas (`W-IN`, `E-IN`, `JN-IN`, `JS-IN`), atrás das barreiras, a **≥ 55 studs** da primeira faixa da rota (`Validate()` mede no mapa e falha alto); **≥ 3 s** entre carros da mesma faixa de rolagem (`Crossing.LaneGap`); não nasce se a ponta estiver ocupada por fila | aviso de ~2,5 s a 22 studs/s; motor audível desde o spawn |
| Fluxo na Juniper Sul (CW-1), dia | **1 carro a cada 12–20 s por sentido** (`Crossing.JuniperSouthInterval`, média 16 s; NB = TR-7 + TR-10, SB = TR-8 + TR-9). A agenda sorteia o próximo carro **por sentido** da Juniper Sul nesse intervalo e escolhe a rota pelo `RouteWeight`; demais rotas seguem `SpawnInterval`. Número ajustável na tabela sem DEC | DEC-133: alavanca única do risco em CW-1 (R22) |
| Teto | **próprio**: `Traffic.MaxCars` = 4 de dia, 1 à noite (FEAT-033; número da noite ainda em `Q-103`); a ambulância ocupa 1 vaga de veículo; **não conta** nos 12 NPCs (não é Humanoid, não roda IA no servidor) | o teto de 12 (DEC-045) mede Humanoids no servidor |
| Velocidade | 22 studs/s na reta, 12 no cruzamento (FEAT-033); frenagem/arrancada 22 studs/s² | perfil por trecho da rota, não por carro |
| Ambulância | roteirizada (§6.3), fora do set `Traffic`; conta como veículo na regra dos 15 studs (reserva de faixa não é dada com ela perto) e reserva a caixa `X-T` durante a viagem; não para para NPC | evita NPC na pista na frente de um veículo que não para |
| Noite / ANM-008 | intervalo por fase vem da tabela; Juniper Sul sem carros à noite (CW-1 livre); 0 carro à noite também é suportado (`Q-103`); durante ANM-008 ativa nenhum carro nasce; durante ANM-010, cutscenes e Final, sem trânsito (FEAT-033) | decisão de conteúdo, não de sistema |
| Streaming | rotas, zonas de conflito, linhas de parada e nós de travessia `Persistent`; modelos de carro em `ReplicatedStorage` (clonados no client) | o client precisa da rota inteira |
| Latência | arrancada chega ao client ~ping/2 depois do servidor: o client, ao receber um registro com `AnchorAt`/`HeldUntil` no passado, avança o carro à posição calculada em ≤ 0,2 s (mistura), nunca teleporta > 6 studs | a validação de hit já tolera 8 studs (§8.2) |

Rotas (`MAP-01.md` §9.5, revisão 3): `TR-1`..`TR-6` na **Ninth Avenue** (leste–oeste, dois sentidos) e na
**Juniper Norte**; `TR-7`..`TR-10` usam a **Juniper Sul** e passam por **CW-1**:

| Rota | Trajeto | Zonas de conflito | Faixas de pedestre cruzadas |
|---|---|---|---|
| TR-7 | `JS-IN` → Juniper NB → CW-1 → PARE `SL-S` → T reto → `JN-OUT` | `X-T` | CW-1 (+ as do T que a rota cruzar, posição do level-designer) |
| TR-8 | `JN-IN` → Juniper SB → PARE `SL-N` → T reto → CW-1 → `JS-OUT` | `X-T` | CW-1 |
| TR-9 | `W-IN` → Ninth EB → T (preferencial, sem PARE), vira ao sul → CW-1 → `JS-OUT` | `X-T` | CW-1 |
| TR-10 | `JS-IN` → Juniper NB → CW-1 → PARE `SL-S` → T, vira ao leste → `E-OUT` | `X-T` | CW-1 |

Entradas e saídas: `W-IN/W-OUT`, `E-IN/E-OUT`, `JN-IN/JN-OUT`, **`JS-IN/JS-OUT`** (Juniper Sul, atrás da curva em
Z ~112, fora de vista). À noite só TR-1 e TR-2 (proposta do level-designer, `MAP-01.md` §9.5): Juniper Sul sem
carros à noite, então a rota do Mart só tem risco de dia. Linhas `SL-*` do MAP-01 (DEC-133): `SL-N`/`SL-S` são
**PARE** (parada fixa de 1 s); `SL-1N`/`SL-1S` e equivalentes nas outras faixas são linhas de parada **só com reserva
de NPC ativa**. Carros da Ninth não têm PARE.

**Rota trailer ↔ Mart (rodada 17)**: cruza a Juniper Sul em **CW-1, sem semáforo**. O sistema não oferece travessia
segura ao jogador: o risco no reabastecimento é intencional (R22). A dosagem é de conteúdo:
`Traffic.Crossing.JuniperSouthInterval` (12–20 s por sentido, DEC-133) e `RouteWeight` das TR-7..TR-10
(game-designer + level-designer). As faixas CW-1..CW-4 são pintadas (DEC-133) e não protegem o jogador; no sistema
elas só existem para a reserva dos NPCs. Efeito emergente aceito (FEAT-033): atravessar junto com um NPC reservado
é mais seguro, porque os carros param para o NPC.

### 8.2 Atropelamento

```
Client (dono da física do próprio personagem)
 - TrafficController testa a caixa de cada carro local contra o próprio HumanoidRootPart a cada frame.
 - Contato → previsão local imediata: ragdoll + impulso (direção do carro + para cima); CarHit{Car} ao servidor.
Servidor (TrafficService)
 - Valida: carro existe; posição calculada do carro em now − ping/2 a ≤ 8 studs do HRP; jogador Active;
   sem imunidade; sem cutscene. Inválido → ignora (o client se levanta sozinho no fim do tempo local).
 - Válido → CharacterService:Knock(player, Traffic.KnockTime) (juntas ragdoll ligadas no servidor = os outros veem);
   ItemService:DropHeld(player) (DEC-103: derruba a Tool da mão; o resto da hotbar fica);
   imunidade Traffic.ImmuneTime.
 - Sem efeito em sanidade (DEC-103).
```

| `Q-122` | Recomendação técnica (números de FEAT-033/FEAT-036) | Dono do número |
|---|---|---|
| (a) tempo no chão | 2,5 s no chão + 0,5 s levantando (`Traffic.KnockTime`, `Traffic.GetUpTime`) | game-designer |
| (b) NPCs atropelados? | **não** (DEC-133): NPC só cruza na faixa com reserva do servidor; com reserva, carros param na linha (§8.1). `HitsNpcs = false` | decidido (DEC-133) |
| (c) ambulância atropela? | **não** (§6.3) | — |
| (d) cooldown | imunidade **5 s** depois de levantar (`Traffic.ImmuneTime`); um carro atinge o mesmo jogador no máximo 1 vez | game-designer |
| (e) item derrubado | **só a Tool equipada** (DEC-103); vira item no chão com prompt **"Pick Up"** (toque, 7 studs) para qualquer membro; pacote mantém o `Count`; some em 120 s na rua (`Items.DropDespawn`); caído na pista vai para a calçada mais próxima (FEAT-036) | game-designer (fecha `Q-122` e) |
| (f) hot dog derrubado | **perdido** ("splat", some em 2 s); café derrama; Revive Kit fica até o fim do turno seguinte (FEAT-036) | game-designer (fecha `Q-122` f) |

Por que o client detecta: o personagem é do client (network owner); detectar onde o jogador **vê** o carro evita
"fui atropelado por um carro que já tinha passado". Trapaça possível = **não** reportar o atropelamento, que só
ajuda o próprio jogador num jogo cooperativo (R10, aceito).

### 8.3 Ragdoll R6 e desmaio (`CharacterService`)

- Ragdoll é **só do atropelamento** (`style-guide.md` §4.6, Aprovado). No spawn, o servidor cria
  `BallSocketConstraint` desligadas para pescoço, braços e pernas do R6 e guarda os `Motor6D`. `Knock` desliga os
  Motor6D e liga as constraints **no servidor** (replica para todos); o client dono simula a física.
  `Humanoid:ChangeState(Physics)` no client dono durante o knock. Levantar: religa Motor6D, `GettingUp`.
- **Desmaio** (sanidade 0) **não é ragdoll**: `Faint` toca a animação (senta e deita de lado), desliga controles e,
  no fim, ancora o `HumanoidRootPart` na pose deitada até a ambulância levar o corpo. Sem física, sem juntas soltas.
- `BreakJointsOnDeath = false`; o Humanoid nunca morre (sem `Health = 0` em lugar nenhum): sanidade não é vida.

## 9. Mart: prateleiras e bancada (DEC-049, DEC-100, DEC-101, DEC-106 a DEC-109, DEC-129)

| Parte | Comportamento | Estado / rede |
|---|---|---|
| Prateleiras | pacotes, sempre à venda; ingrediente não liberado conforme `Q-088` | atributos de prompt; sem set |
| Frutas/verduras | **só cenário** no MVP (DEC-109): sem prompt | nada |
| Bancada: upgrades básicos (Grill, Cooler, Counter, Cash Drawer Lock, Trailer Lights) | **sempre à venda**, nunca saem da oferta (DEC-106); Trailer Lights aparece depois da compra do trailer e fica; prompt mostra o próximo nível e preço | set `Upgrades` existente |
| Bancada: **1 vaga especial** (S1) | sorteada no início da Preparação de **cada** turno, dia e noite (FEAT-035). Hoje o único especial é o **Revive Kit** (ITM-021): **15% por turno**, só **depois da compra do trailer** (DEC-129); 1 unidade por aparição; preço **$200 × multiplicador de `PriceParty`** (DEC-121, DEC-129). Especial novo exige DEC (DEC-106) | set `Bench` (id = 1) |

- **Food Trailer não é da bancada** (DEC-107, FEAT-015/FEAT-016): prompt de compra **no próprio trailer** à venda
  no estacionamento, do dia 5 em diante, tratado pelo `VehicleService` (`BuySpot` = o trailer). Preço $300 ×
  multiplicador de `PriceParty`.
- Sorteio com semente da run (Day, IsNight); a oferta **entra no snapshot** (FEAT-035): retomada e noite repetida
  mostram a mesma oferta sem sortear de novo. Compras do turno repetido voltam junto com o dinheiro (o snapshot é
  do início do turno).
- Limites "por run" ficam em `RunState.Counters` e entram no snapshot.
- Compra: `Interact{BenchSlot, buy}` → `MarketService` valida dinheiro (`EconomyService:Spend`), limite de hotbar
  (`Q-056`) e unidades da vaga → `ItemService:Give`.

## 10. Monetização e persistência por evento

### 10.1 `MonetizationService` (DEC-092)

- **Único** `MarketplaceService.ProcessReceipt` do place (Lobby e Run). Outros Services registram
  `RegisterProduct(kind, handler(player, receipt): GrantResult)` no `OnInit`.
- Idempotência (padrão ProfileStore):
  1. Perfil não carregado → `NotProcessedYet` (o Roblox reentrega depois).
  2. `receipt.PurchaseId ∈ profile.Receipts` → `PurchaseGranted` (já entregue).
  3. Chama o handler; ele muda o perfil (ou o estado da run **e** o perfil, ver §10.2).
  4. Adiciona `PurchaseId` a `Receipts` (lista circular de 50), `Save()`, espera `OnAfterSave` com o id presente
     (timeout 15 s) → `PurchaseGranted`. Timeout ou sessão inativa → `NotProcessedYet`.
- Preço do produto não fica no código (Creator Hub); `Content.Products` guarda só `ProductId` e tipo.

### 10.2 Recibo de reviver que não pode ser aplicado agora

Casos reais: o recibo chega depois da janela de 10 s, o alvo já foi revivido por outro, a noite acabou, o comprador
saiu para o lobby antes do recibo, o recibo é reentregue noutro servidor.

**Decidido (DEC-117)**: o recibo **sempre** é concedido como **1 crédito de reviver persistido** (`ReviveCredits`
no perfil) e, se houver intenção válida no mesmo servidor, o crédito é **consumido na hora** no próprio comprador
(DEC-116: comprador = alvo). Na prática o jogador nunca paga sem receber: ou revive agora, ou fica com um "revive
guardado" para uma queda futura (uso: §6.4, mesmas regras de prazo e limite). Vale também para recibo que chega na
noite já perdida, depois da janela de 10 s, com o jogador já revivido, ou no lobby. Alternativa descartada: devolver
não existe (Robux não tem estorno por API); recusar o recibo indefinidamente viola a regra de entregar o que foi
pago.

### 10.3 Save por evento (DEC-104)

- `ProfileService:RequestSave(player)`: agrupa pedidos em 2 s e chama `session:Save()` (UpdateAsync). Eventos
  simultâneos (dia concluído + nota A + dia infinito) viram uma escrita.
- Limite do DataStore por servidor: 60 + 40 × jogadores escritas/min; uma run de 4 faz ~3 escritas por turno por
  jogador. Folga de duas ordens de grandeza. Não há mais cooldown de 6 s por chave (limite atual: 4 MB/min por chave).
- Crédito fica no atom na hora (HUD e `Profile` mostram); a escrita é assíncrona. Servidor morrer nos ≤ 2 s entre o
  crédito e o save perde aquele evento (R5, aceito).

### 10.4 Gemas por evento, anti-AFK, Day 100 (`RewardService`)

| Evento (`RewardEvent.key`) | Gemas | Condição | Quem recebe |
|---|---|---|---|
| `D{day}:day` | 2 | dia concluído **e** ≥ 3 pedidos completos da party no turno (DEC-083) | presentes no instante (DEC-104) |
| `D{day}:gradeA` | 1 | nota A **e** o mesmo mínimo (leitura do secretário em DEC-083, a confirmar com game-designer) | idem |
| `N{night}:night` | 15 + 2 × (N − 1) | noite vencida (repetida paga 1×) | idem, inclusive Down/Spectator (DEC-070, DEC-085 c) |
| `finale` | 100 | final da 10ª noite | idem |
| `D{day}:endless` | 0 (só contador) | dia de modo infinito concluído e anti-AFK ok (DEC-084) | idem: `EndlessDays += 1` |
| `achievement:day_100` | 300 + badge | `EndlessDays` chega a 100, 1× por conta | o jogador |

- **Idempotência por run**: o perfil guarda `RunRewards = {RunId, Keys}`. Antes de pagar, `RewardService` checa se a
  chave já está lá; se o `RunId` é outro, zera a lista. Cobre noite repetida, retomada de snapshot antigo e
  reconexão. Chave é texto curto; ~40 por run.
- "Modo infinito": definição em tabela (`RunParams.EndlessFromDay`, `RunParams.EndlessRequiresNoTrailer`), dono
  game-designer (DEC-084 diz "dias sem trailer, a partir do Day 6").
- Badge: `BadgeService:AwardBadge` com retry; se falhar, `Achievements` já marca e o `RewardService` (ou o lobby, no
  `Loaded`) tenta de novo enquanto `UserHasBadgeAsync` for falso.

## 11. Cutscene compartilhada em 1ª pessoa (DEC-078, DEC-088)

- Os **personagens reais** dos jogadores atuam: `CutsceneService` desliga controles (`CharacterController`),
  posiciona cada personagem numa marca (`CutsceneMark1..4` no mapa) e move com `Humanoid:MoveTo` nos trechos de
  caminhada. Cada client põe a câmera na cabeça do próprio personagem (`Scriptable`, olhando para o alvo da cena).
  Os colegas veem os avatares de verdade, sem dublê.
- Set `Cutscene` (registro único): `{Scene, StartedAt, Votes, Needed}`. A timeline no client é função de
  `GetServerTimeNow() − StartedAt`: quem chega no meio entra no ponto atual (§5.6 c).
- Voto de pular: packet `SkipVote`; `Needed = ceil(conectados × 0,5)`; voto não se retira; solo pula sozinho.
- Atores não-jogadores (Walt no final, Raincoat Lady) são locais ao client, como a ambulância.
- Só intro e final são puláveis (conciliação do game-designer, `Q-077`); ligações não.

## 12. Orçamento de performance

DEC-090: sem celular de referência agora. Metas abaixo são **alvo de Rascunho**, medidas no aparelho disponível;
o teste de soak e a medição de servidor continuam obrigatórios.

### 12.1 Metas

| Métrica | Meta | Como medir |
|---|---|---|
| FPS client | ≥ 30 estável em celular médio | MicroProfiler no aparelho |
| Memória client | ≤ 900 MB (Run), ≤ 700 MB (Lobby) | Developer Console |
| Heartbeat do servidor | ≤ 4 ms médio, ≤ 12 ms pico (4 jogadores + 12 NPCs + trânsito) | MicroProfiler do servidor |
| Rede recebida por client | ≤ 10 KB/s de Lync; ≤ 50 KB/s total | Network stats |
| Memória do servidor em 6 h | crescimento ≤ 10% depois da 1ª hora | soak de 6 h |
| Boot até jogável (Run) | ≤ 15 s depois do teleporte; retomada ≤ 20 s | log do Modux |

### 12.2 Entidades por servidor

| Tipo | Teto | Onde roda | Conta nos 12? |
|---|---|---|---|
| NPC Humanoid (clientes, ladrão, atores de anomalia que andam, passantes) | **12** (DEC-045) | servidor, pool R6 | sim |
| Carros | 4 dia / 1 noite (tabela, FEAT-033; noite em `Q-103`) | client (agenda no servidor) | não (teto de veículos) |
| Ambulância + 2 médicos | **1 ambulância por servidor**, fila de viagens | client (timeline do servidor) | não (ambulância ocupa 1 vaga de veículo) |
| Opal | 1, ancorada | client (idle local) | não (`Q-091` a) |
| Atores de cutscene (Walt, Raincoat Lady) | — | client | não |
| Jogadores | 4 | client (física própria) | — |

### 12.3 NPCs e IA

| Item | Decisão |
|---|---|
| Rig | **R6** (DEC-089), Humanoid no servidor, estados não usados desligados, `BreakJointsOnDeath = false` |
| Pool | 12 rigs pré-criados; spawn = trocar aparência e reposicionar |
| Movimento | `Humanoid:MoveTo` por grafo autorado (`NpcNode`); NPC só cruza pista em nó de faixa (`Crosswalk = CW-n`): espera no meio-fio e pede `TrafficService:ReserveCrossing` a 2 Hz só enquanto espera; com reserva atravessa (3 s) e chama `ReleaseCrossing` ao chegar ao outro meio-fio (DEC-133). Ladrão nunca cruza pista |
| Pathfinding | sem `PathfindingService` em runtime; A* no grafo (≤ 80 nós) no spawn; máx. 2 rotas por frame |
| Tick de IA | cliente 5 Hz; visão 5 Hz; escuro 1 Hz; trânsito: cinemática 1D a 10 Hz (≤ 4 carros, decide paradas/arrancadas e caixa `X-T`), sorteio de spawn a cada 1 s, validação de hit por evento |
| Física | NPC: dono = servidor, grupo `Npc` (sem colisão com `Players` e `Npc`) |
| LOD (client) | animação parada a > 120 studs e fora do campo de visão; bolha a ≤ 40 studs; carro fora do raio de stream não é clonado |
| Plano B | NPC lógico no servidor e modelo só no client, se a medição pedir |

### 12.4 Replicação Lync (por client, pior caso: noite, 4 jogadores)

| Fonte | Taxa | Bytes/s aprox. |
|---|---|---|
| `Vitals` | ≤ 4 updates/s | < 50 |
| `Customers`, `Stations` | ~1/s cada | < 60 |
| `Stock`, `Economy`, `Shift`, `Upgrades`, `Bench` | eventos | < 20 |
| `Traffic` | por carro: nascer + 1–2 registros por PARE + 0–2 por faixa reservada + saída (≤ 6 × ~30 B); ≤ 4 carros, um a cada poucos segundos (dia) | < 40 |
| `Ambulance`, `Cutscene` | eventos raros | < 5 |
| packets (`Notice`, `Sale`, `AnomalyCue`, `LifeEvent`) | eventos | < 50 |
| `Gaze` (c → s) | 10 Hz, só à noite | ~30 por jogador |

Total de Lync < 1 KB/s. O peso real continua sendo física dos Humanoids e personagens ragdoll.

### 12.5 Mundo e render

- Streaming (`Q-087`): ligado; `StreamingMinRadius` 256 cobre o mapa inteiro a partir do Pad (na prática, tudo
  carregado, como pede o level-designer), mas mantém a proteção de memória do engine. Gameplay `Persistent`.
- Noite (`style-guide.md` §5.1 e §9, Aprovado, DEC-126): **≤ 3 luzes com sombra** visíveis ao mesmo tempo; **≤ 18
  luzes locais** ativas no mapa (alvo 14); dia 0–2. `Lighting.Technology = Future` com fallback manual para
  ShadowMap; nenhuma mecânica depende de sombra (escuro de jogo = `LightZone`). Áudio ≤ 12 sons (sirene conta 1).
- Postes da Juniper (`MAP-01.md` revisão 3: a cada **8 studs**, último em Z ~−135, ~15 postes + P-01). Um
  `SpotLight` por poste estoura o teto (16 + 6 fixas = 22 > 18). Proposta (T31, Provisória):
  - todo poste tem lâmpada **emissiva** (Neon, custo zero de luz); o pisca do Walker e o apagar do Hush mexem nela;
  - `SpotLight` real (para baixo, Range 16–20, **sem sombra**) só em **um poste a cada dois** (16 studs) + P-01:
    ~9 luzes. Com as fixas (interior do trailer 1, Trailer Lights 1 + 2 fracas, Mart 2) = **~15** locais;
  - sombra só em: interior do trailer, mastro do Trailer Lights e (opcional) letreiro do Mart = **≤ 3**;
  - corte local no client: `SpotLight` de poste a > 150 studs da câmera desliga (fica a emissiva) → em qualquer
    vista ≤ 14 ativas. Hush apaga a emissiva e a luz (se houver) do mesmo poste; nenhuma regra muda.
  - `LightZone` (escuro de jogo, servidor) é independente da luz visual: um volume por poste, como antes; o
    level-designer marca, o Hush desliga um por um.
- UI: um prompt visível por vez; ≤ 5 barras; ≤ 8 bolhas.
- Run de 6 h: disposers de `effect`, conexões por jogador, pool de NPC, carros locais destruídos ao fim da rota.

## 13. Plano de porte do AnimalPlane (DEC-029, DEC-066)

Sem mudança desde a versão 1: prompt custom, `ProgressBar`, `UseTween`, `DeviceSettings`, `GetSFX`/`GetVFX`, padrão
`StartedAt/Duration`. VFX/SFX exportados pelo usuário (`Q-045`). Porte só depois da bandeira verde.

| Origem (AnimalPlane) | Destino | Mudança |
|---|---|---|
| `Prompt/client/ProximityPromptController.luau` | `src/Interaction/client/PromptController.luau` | tirar `PlaneController`/`CharacterController` do AnimalPlane; teclas via `InputController:Bind`; dispara `Interact` |
| `Prompt/client/Prompt.luau` | `src/Interaction/client/Prompt.luau` | + `EntityId`, `PromptAction`, `PromptText`, `PromptEnabled` |
| `Prompt/client/PromptInterface.luau` | `src/Interface/client/Components/PromptBillboard/` | story |
| `Kitchen/client/CookInterface.luau` | `src/Interface/client/Components/ProgressBar/` | cópia + story |
| `shared/Interface/UseTween.luau`, `shared/Input/DeviceSettings.luau`, `GetSFX`, `GetVFX` | `Interface`, `Input`, `src/Fx/` | cópia |
| `Kitchen/client/Boil.luau`, `Kitchen/server/Boil.luau` | `src/Kitchen/...` | reescrever sobre o set `Stations`; timer no tick do Service (entra no snapshot) |

## 14. Decisões técnicas propostas

Numeração local (T#). **Todas (T1–T31) são Provisórias até aprovação do usuário (`Q-130`)**: nenhuma vira
`DEC-###` técnica por silêncio; o secretário registra só o que o usuário aprovar. A coluna "Histórico" diz de que
versão a proposta vem, não se foi aprovada.

| # | Proposta | Alternativa descartada | Histórico |
|---|---|---|---|
| T1 | Dois places, mesmo código, papel por `Workspace.PlaceRole` | dois projetos Rojo; PlaceId fixo | mantida |
| T2 | ~~Estado da run só em memória~~ | — | **substituída** por DEC-080 e T16 |
| T3 | Reconexão por `PlayerRun` + `Runs` (HashMap) + claim por `JobId` | só `ReservedServerAccessCode` | mantida; TTL 960 s |
| T4 | Roster gravado pelo lobby no MemoryStore | `TeleportData` | mantida |
| T5 | Estender `Vital` (sanidade + vida) e `Round` (turnos, set `Shift`) | services paralelos | ampliada |
| T6 | `InteractionService` único responder de `Interact`; alvo por `EntityId` | packet por feature | mantida |
| T7 | Visão calculada no servidor com `Gaze` | client relata "vi" | mantida |
| T8 | Escuro por `LightZone` no servidor | client relata | mantida |
| T9 | Alucinações só client | replicar | mantida |
| T10 | Regras de anomalia só no servidor | tudo em `Shared` | mantida |
| T11 | NPC R6 com Humanoid no servidor, pool de 12, grafo autorado | só client; pathfinding dinâmico | ampliada (R6) |
| T12 | Snapshot por Service via **registro** no `RunStateService` | serviço central que conhece todos | revista: um snapshot para noite, retomada e queda |
| T13 | Enums Lync gerados das tabelas; persistência por chave string | enums à mão | mantida |
| T14 | Sem `keyBy` no MVP | `keyBy` por party | mantida |
| T15 | Publicar sem "Restart servers" com runs vivas | reiniciar sempre | mantida, impacto menor (restart agora custa só o turno corrente) |
| T16 | Snapshot em `Snap[RunId]` a cada fronteira de turno; suspender no último `PlayerRemoving`/`BindToClose`; **queda do servidor** também retomável pelo batimento parado | snapshot só ao sair (não cobre queda); DataStore (escrita lenta, persiste além do necessário) | nova; o gatilho de queda do servidor foi decidido em **DEC-119** |
| T17 | Retomada no servidor novo com o mesmo `PrivateServerId`, claim atômico por `UpdateAsync` | servidor reservado novo (perde o código que o lobby tem) | nova |
| T18 | Sorteios com semente da run (`RunSeed`, Day, IsNight, Attempt) | `math.random` | nova |
| T19 | Gemas por evento com chave de idempotência por run no perfil; save agrupado em 2 s | save imediato por crédito; ledger no MemoryStore | nova |
| T20 | `ProcessReceipt` único, ledger de 50 `PurchaseId` no perfil, `PurchaseGranted` só depois do `OnAfterSave` | conceder antes de salvar | nova |
| T21 | Trânsito decidido no servidor como cinemática 1D (10 Hz) e interpolado no client a partir de um registro por evento `{AnchorAt, AnchorDist, StopDist, HeldUntil}`; **sem semáforo** (DEC-130); paradas só no PARE da Juniper (1 s, entra com a caixa `X-T` reservada; Ninth preferencial nunca para) e na linha da faixa com reserva de NPC (DEC-133); nunca para nem desvia por jogador; spawn ≥ 55 studs da 1ª faixa, ≥ 3 s por faixa de rolagem; hit detectado no client e validado no servidor | carros físicos no servidor; posição replicada por frame; carro que nunca para (incompatível com DEC-133); hit só no servidor | revista na 3.1 (DEC-133, `Q-131`) |
| T22 | Ragdoll R6 com constraints pré-montadas, ligadas no servidor, física no client dono, **só no atropelamento**; desmaio por animação com HRP ancorado; Humanoid nunca morre | `Health = 0` + respawn; ragdoll infinito na queda (proibido pelo `style-guide.md` §4.6) | revista |
| T23 | Ambulância (uma por servidor, fila de viagens), médicos, atores de cutscene e Opal são locais ao client, dirigidos por set/tempo; fora do teto de NPCs | NPCs de servidor; uma ambulância por caído | revista |
| T24 | Cutscene com personagens reais em marcas e câmera POV local; set `Cutscene` com votos | dublês por client; packet | nova |
| T25 | `CharacterAutoLoads = false` no Run; spawn só por `CharacterService` | spawn automático | nova |
| T26 | Streaming ligado com raio mínimo que cobre o mapa (`Q-087`); colisão jogador–jogador desligada (`Q-086`) | streaming desligado | nova |
| T30 | NPC cruza só na faixa com reserva do servidor (`TrafficService:ReserveCrossing`/`ReleaseCrossing`, sem rede): concedida sem carro a < 15 studs da linha e ≥ 4 s depois da última liberação; carros param na linha; reserva expira em 4 s (failsafe `PivotTo` do NPC); nenhum carro para dentro da faixa (DEC-133) | NPC atropelável; NPC só em brecha sem carro parar (`IsCrossingClear`, versão 3.1 inicial, incompatível com DEC-133); fila física de carros | nova na 3.1, revista por DEC-133 (`Q-131`) |
| T31 | Postes da Juniper: emissiva em todos, `SpotLight` sem sombra em um a cada dois + P-01, corte por distância no client; `LightZone` separada da luz visual | `SpotLight` em todos (estoura ≤ 18) | nova na 3.1 |
| T32 | Binding do mapa por **tag + atributo** (autorado × runtime); âncora por nome só **dentro do dono** achado por tag; índice compartilhado `MapIndex` (§18.1–§18.8) | caminhos de pasta (`workspace.MAP01_Assets.Cart...`); busca global por nome; `MapId` como chave de código | nova na 3.2; **decidida pelo architect (DEC-208, delegada)** |
| T33 | `EntityId` atribuído pelo servidor no registro (ordem estável por `GetFullName`), escrito como atributo de runtime; nunca autorado; snapshot nunca usa `EntityId` | id autorado no place (colisão, esquecimento, retrabalho a cada mudança de mapa) | nova na 3.2; **decidida pelo architect (DEC-208, delegada)** |
| T34 | Kits em `ReplicatedStorage.Assets` montados em **modo de edição** por script reproduzível; **sem `InsertService` em runtime**; malha só como instância; id de textura/imagem em módulo de dados (`CrewLooks`, `Content`) | `InsertService:LoadAsset` em runtime (só funciona com asset do dono do place, latência, falha de rede); `MeshId` por código (não é gravável em runtime) | nova na 3.2; **decidida pelo architect (DEC-208, delegada)** |
| ~~T35~~ | ~~Visual da crew aplicado no servidor; Night de NPC só no client~~ → **retirada**: vale a **T40** de `network.md` §5.1 (servidor monta a geometria e escreve atributos; **cada client veste** textura e rosto), que segue o texto da DEC-167/169 ("servidor replica a faixa; cada client aplica a textura"). Id T35 não é reaproveitado | — | proposta e retirada na 3.2 |
| T36 | Veículos vivem no `Workspace` e são **reposicionados** (`PivotTo`); estação de veículo que não é o atual fica com prompt desligado | trocar o veículo entre `ServerStorage` e `Workspace` (quebra registro por tag e streaming) | nova na 3.2; **decidida pelo architect (DEC-208, delegada)** |
| T37 | `KitchenService` descobre `Stations/*.luau` sozinho; uma inscrição por chave de ação no `InteractionService`; despacho pela `StationKind` do dono da âncora (§18.12) | lista estática no init (conflito de merge entre tasks paralelas); um Component por estação (estado espalhado, snapshot difícil) | nova na 3.2; **decidida pelo architect (DEC-208, delegada)** |
| T38 | Peça de upgrade alternada por **visibilidade**, nunca reparentada; âncoras de prompt e de vaga ficam fora da peça (filtro `Level` quando a posição muda por nível) | trocar o modelo inteiro da estação a cada nível (perde tags e atributos) | nova na 3.2; **decidida pelo architect (DEC-208, delegada)** |
| T39 | Grafo `NpcNode` por atributos (`NodeId`, `Links`, `Crosswalk`); aresta ≤ 40 studs (limite de 8 s do `MoveTo`); A* determinístico com desempate por `NodeId` (servidor e client) | `ObjectValue` por aresta (some no client com streaming); `PathfindingService` em runtime | nova na 3.2; **decidida pelo architect (DEC-208, delegada)** |
| T40 | Aparência de personagem vestida **no client** a partir de atributos do modelo (`Species`, `Outfit`, `CustomerType`, `LookPack`); servidor monta a geometria e escreve os atributos (`network.md` §5.1; substitui a T35 retirada) | servidor aplica textura e rosto (T35) | nova (`network.md` v4); **Aprovada: decidida pelo architect (DEC-208, delegada)** |

## 15. Propostas ao usuário: situação

As propostas D1–D5 da versão 2 foram decididas (D4 depois revogada por DEC-130). Pendente com o usuário:
aprovação das técnicas **T1–T31** (§14 e abaixo), todas **Provisórias** até lá (`Q-130`; hoje a pergunta lista
T27–T29, o secretário amplia para T1–T31).

| # | Pergunta | Decisão | Onde está implementado |
|---|---|---|---|
| D1 | Recibo de reviver em Robux que não pode ser aplicado vira crédito no perfil? | **sim — DEC-117** | §10.2, `data.md` §1.1 (`ReviveCredits`), `content-data.md` §3.12 |
| D2 | Janela de 10 s congela com prompt de compra aberto (teto +20 s)? | **sim — DEC-118** | §6.2, `network.md` §3.1 (`WipeFrozen`) |
| D3 | Queda do servidor também abre a retomada de 15 min? | **sim — DEC-119** | §5.5, §7, T16 |
| D4 | Semáforo com faixa de pedestre na travessia trailer ↔ Mart e nos cruzamentos? | ~~sim — DEC-120~~ → **revogada: sem semáforo no MVP — DEC-130**; rota do Mart cruza a Juniper Sul em CW-1 sem semáforo (rodada 17) | §8.1 (removido) |
| D5 | Espectador volta na noite repetida? | **todos voltam, inclusive de noites anteriores — DEC-111, DEC-113** (a recomendação A foi recusada) | §6.1, §7 |

Novas técnicas da versão 3 — **Provisórias até aprovação do usuário (`Q-130`)**; T30 e T31 (versão 3.1) estão no §14:

| # | Proposta | Alternativa descartada |
|---|---|---|
| T27 | Oferta especial da bancada guardada no snapshot (FEAT-035), não re-sorteada | re-sortear pela semente (com `Attempt` na semente a noite repetida mudaria a oferta) |
| T28 | Uma ambulância por servidor com fila FIFO de viagens; caminho dos médicos calculado no client sobre o grafo `NpcNode` | uma sequência por caído; caminho enviado pelo servidor |
| T29 | `PriceParty` fixado no `ShiftEnded` do Day 1 e guardado no snapshot (DEC-121) | ler `Joined` na hora da compra |

## 16. Riscos técnicos

| # | Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|---|
| R1 | Run perdida por queda | **baixa** (era alta) | médio | DEC-080/T16: perde só o turno corrente; T15 |
| R2 | Teleporte falha ou chega parte da party | média | médio | retry; janela de 60 s; atrasado entra depois (DEC-098) |
| R3 | Código reservado reaproveitado sobe servidor novo | certa | — | agora é o caminho da retomada (T17); claim por `JobId` |
| R4 | Trava de sessão do ProfileStore atrasa o perfil na run | média | baixo | run não espera o perfil; Rookie até carregar; recibo espera (`NotProcessedYet`) |
| R5 | Servidor morre entre crédito de gema e save (≤ 2 s) | baixa | baixo | save agrupado curto; aceito |
| R6 | 1ª pessoa travada no mobile | média | alto | sensibilidade baixa; teste cedo |
| R7 | Humanoids R6 + personagens em ragdoll (só atropelamento) pesam no celular | média | médio | pool, estados desligados, LOD; desmaio ancorado (sem física); plano B |
| R8 | Schema Lync só validado em runtime | média | alto | `Validate()` das tabelas; boot nos dois places no QA |
| R9 | Vazamento em 6 h | média | alto | disposers, conexões, soak |
| R10 | Trapaça (Gaze, não reportar atropelamento) | baixa | baixo | co-op; plausibilidade |
| R11 | Spam de packets | média | médio | taxa por jogador; distância; estado |
| R12 | Gating por papel errado | baixa | médio | `PlaceService` falha alto |
| R13 | Service esquece de registrar snapshot | média | **alto** (afeta noite repetida e retomada) | checklist; teste de QA "perder a noite e comparar" e "sair todos, voltar, comparar" |
| R14 | VFX/SFX do AnimalPlane fora do repo | certa | baixo | `Q-045` |
| R15 | MemoryStore indisponível | baixa | médio | sem oferta e sem retomada (log); run viva não é afetada |
| R16 | **Cota de memória do MemoryStore** (64 KB + 1,2 KB × usuários): snapshot de run solo (~1 KB) + ponteiros chega perto da contribuição de 1 jogador; runs suspensas ocupam sem usuário | média em escala baixa | médio | snapshot compacto (≤ 2 KB, chaves curtas); jogadores do lobby somam cota sem usar; mitigação de reserva: gravar o snapshot só ao suspender (mesmo conteúdo, perde só a queda de servidor) |
| R17 | **Robux na janela de 10 s**: fluxo de compra leva 2–8 s; recibo pode atrasar | alta | alto (paga e perde) | DEC-118 (congelar a janela até +20 s) + DEC-117 (crédito no perfil) |
| R18 | **Recibo noutro place/servidor** (comprou e saiu) | média | médio | `MonetizationService` nos dois places; crédito (DEC-117) |
| R19 | **Snapshot de versão antiga após atualização** | média | médio | campo `V`; migração de snapshot ou "can't be resumed" |
| R20 | **Ragdoll R6 com física no client**: personagem preso em parede/trailer apertado ao levantar | média | baixo | levantar com `PivotTo` para o ponto livre mais próximo do grafo se preso > 1 s |
| R21 | **Atropelamento visto diferente por cada jogador** (latência 100–200 ms) | certa | baixo | tom pastelão; o servidor valida com folga de 8 studs |
| R22 | **Trânsito x rota trailer ↔ Mart**: o atropelamento no reabastecimento agora é **intencional** (DEC-130 + rodada 17: CW-1 cruza a Juniper Sul sem semáforo). Risco técnico = **dosagem errada**: frequente demais frustra o restock; raro demais apaga a mecânica | média | médio | dosar só por tabela, sem código: `Traffic.Crossing.JuniperSouthInterval` (12–20 s por sentido, DEC-133; referência ~16% por travessia sem olhar) e `RouteWeight` das TR-7..TR-10; Juniper Sul sem carros à noite; spawn ≥ 55 studs da faixa (~2,5 s de aviso, motor audível); imunidade 5 s; só a Tool da mão cai e pode ser pega (DEC-103, FEAT-036); playtest mede atropelamentos por ida ao Mart |
| R25 | **Paradas de carro x latência** (DEC-133): a arrancada chega ao client depois do servidor; carro "salta" ou hit validado contra posição diferente | média | baixo | PARE de 1 s já sai com `HeldUntil` no registro (sem segundo pacote); mistura de ≤ 0,2 s no client; validação ± 8 studs; teste de QA com 200 ms de latência simulada |
| R26 | **NPC preso na pista** com reserva expirando (Humanoid travado) | baixa | médio | expiração em 4 s + `PivotTo` do NPC ao meio-fio de destino; log para o QA |
| R23 | **Cutscene com personagens do client**: `MoveTo` do servidor num personagem cuja física é do client pode desalinhar | média | baixo | `PivotTo` na marca no início de cada plano; controles desligados |
| R24 | **Day 100 entre sessões**: contador por evento depende da definição de "modo infinito" | baixa | baixo | definição em tabela, game-designer |

## 17. Perguntas técnicas: estado

| Antiga | Q | Situação |
|---|---|---|
| P1 | `Q-066` | respondida (DEC-080); mecânica em §5.5, §7 |
| P2 | `Q-061` | respondida (DEC-085) |
| P3 | `Q-061` | respondida (DEC-085, emendada por DEC-104) |
| P4 | `Q-067` | game-designer; proposta de FEAT-009 adotada na tabela (`Flow.PartySource = "ActiveAtShiftStart"`); fluxo recalculado no `ShiftStarted` |
| P5 | `Q-068` | game-designer |
| P6 | `Q-069` | game-designer + narrative-writer; `AnomalyCue` suporta |
| P7 | `Q-070` | level-designer + game-designer |
| P8 | `Q-071` | respondida (DEC-098); detalhes em `Q-112`, §5.6 |

Respostas técnicas deste documento para Qs com o architect como dono ou co-dono: `Q-058` (§5; gatilho de queda do
servidor decidido em DEC-119), `Q-086` (§1.1, T26), `Q-087` (§12.5), `Q-091` a (§2.3, §12.2), `Q-102` (§8.1;
sem travessia segura: DEC-130 e rodada 17), `Q-112` (§5.6; (a) decidido em DEC-121), `Q-122` (§8.2; (b) decidido em
DEC-133), `Q-130` (§14, §15). `Q-129` fechada por DEC-133; **`Q-131` (lado técnico) resolvida nesta versão**: §8.1, T21,
T30, `network.md` §3.11, `content-data.md` §3.14 (as linhas de `levels/MAP-01.md` são do level-designer).
Fechadas por DEC e já aplicadas aqui: `Q-121` (DEC-111), `Q-125` (DEC-112), `Q-126` (DEC-113), `Q-116`/`Q-117`/`Q-118`
(DEC-106/107/108), `Q-044` (DEC-127), partes de `Q-107` (DEC-115, DEC-116, DEC-129).
Restrições técnicas para o que segue aberto: `Q-120` f (§6.4, §9), `Q-103` (§8.1: 0 ou 1 carro à noite suportados).

## 18. Binding do MAP-01, kits de asset e layout de módulos (TASK-002)

Status da seção: **Provisória** (DEC-193: base para construir). Técnicas T32–T39 aguardam o usuário em `Q-130`;
altura da bancada do carrinho depende de `Q-153`; posições de vaga da grelha L2/L3 dependem de `Q-134` (c).
Fontes: `levels/MAP-01.md` §5, §7, §9.1; `tools/assetplace/MAP-01_placements.luau`, `place_assets.luau`,
`build_crew.luau`; `tools/blockout/MAP-01_blockout.luau`; `Assets/import/_asset_ids.json`,
`Assets/textures/character/_texture_ids.json`; encaixes lidos dos `.fbx` de `Assets/import/` nesta sessão; DEC-142,
DEC-146, DEC-151, DEC-156, DEC-157, DEC-166 a DEC-169, DEC-174, DEC-181, DEC-184, DEC-186, DEC-190, DEC-201, DEC-207.

Quem usa: level-designer (TASK-005), modeler-3d (TASK-006, TASK-007), backend e frontend (TASK-010 em diante).
Chaves de `Content` citadas aqui (`StationKind`, ações, pacotes, itens) são as de `content-data.md`; onde a tabela
ainda não fechou, a chave proposta está marcada e a nota ao dono está em §18.14.

### 18.0 Princípios

1. **O código acha coisas por tag + atributo**, nunca por caminho de pasta. `workspace.MAP01_Assets`, `Cart`,
   `MartInterior` são organização do level-designer e podem mudar sem tocar em código.
2. **Três camadas.** Tag = *o que é* (§18.1). Atributo autorado = *qual* (estação, ação, vaga, ponto) (§18.2).
   Nome de encaixe = peça **dentro de um dono já achado por tag** (nomes dos `.fbx` e de `asset-list.md`). Busca global
   por nome é proibida.
3. **Autorado × runtime.** O level-designer escreve só atributo autorado; o código escreve só atributo de runtime.
   Nunca os dois no mesmo atributo.
4. **Valores são chaves.** Atributo semântico guarda chave de `Content` (minúsculas_com_underscore) ou ID do
   `MAP-01.md` **literal** (`Q1`, `PS-3`, `SP-A`).
5. **Só o `Workspace` conta.** Instância tagueada fora do `Workspace` (`ServerStorage`, `nil`, kits em
   `ReplicatedStorage`) é ignorada pelos registros.
6. **Streaming:** todo `Model` que contém tag de gameplay tem `ModelStreamingMode = Persistent` (T26). A checagem
   (§18.7) recusa o que não tiver.
7. **Snapshot usa chave estável** (`StationKind` + veículo + `Slot`/`Ingredient`; `PointId`), nunca `EntityId` nem
   `StationId` (que nascem a cada servidor).
8. `MapId` e `Asset` (escritos por `place_assets.luau` em todo modelo colocado) são **metadado de ferramenta**:
   o código não lê. Vários modelos têm o mesmo `MapId` (`MKT`), por isso ponto usa `PointId`, não `MapId`.

### 18.1 Tags reservadas (`CollectionService`)

Nenhum Modux Component usa uma tag desta lista (Component usa o próprio nome como tag, como `Vital`). Isso evita que o
`ComponentManager` construa um objeto para cada estação ou ponto sem querer.

| Tag | Vai em | Quem lê | Onda |
|---|---|---|---|
| `MapBinding` | **um** `Model` raiz (`workspace.MapBinding`, Persistent) que agrupa pontos e nós | `MapIndex` (§18.8) | 1 |
| `MapPoint` | `Part` invisível (1 × 1 × 1) com `PointId` | `MapIndex` → Character, Customer, Npc, Opal, Ambulance, Cutscene | 1 |
| `NpcNode` | `Part` invisível com `NodeId`/`Links` (pode ser a mesma `Part` de um `MapPoint`) | `MapIndex` → `NpcService` (servidor), `AmbulanceController` (client, T28) | 1 |
| `Vehicle` | `Model` do veículo (`cart`; `trailer` na onda 2) | `VehicleService`, `KitchenService`, `ThiefService`, `EconomyController` | 1 |
| `Station` | `Model` de uma estação da cozinha, **descendente** do `Model` do veículo | `KitchenService`, `KitchenController` | 1 |
| `Interactable` | âncora de prompt (`Attachment`, ou `BasePart` invisível) | `InteractionService`, `PromptController` | 1 |
| `AnimalRig` | modelo montado por `CrewRig.Build` (crew e NPC; Opal local também) | client: veste textura e rosto a partir dos atributos (`network.md` §5.1, T40), inclusive modelo que chega por streaming | 1 |
| `UpgradePiece` | peça visível de nível de upgrade | `UpgradeService` | 1 (Cooler, Grill) |
| `LightZone` | volume de luz de jogo (LZ-1..5) | `VitalService`, `AnomalyService` | 2 |
| `StreetLight` | poste (JL-01..09, P-01) | `AnomalyController`, corte local T31 | 2 |

### 18.2 Atributos

**Autorados** (level-designer na TASK-005; modeler-3d nos kits):

| Atributo | Tipo | Em | Valores | Obrigatório |
|---|---|---|---|---|
| `PointId` | string | `MapPoint` | ID do MAP-01 (`PS-1`, `Q1`, `D1`, `OP-1`…), único no place | sim |
| `NodeId` | string | `NpcNode` | ID único; se a `Part` também é `MapPoint`, omitir (vale o `PointId`) | sim, salvo nesse caso |
| `Links` | string | `NpcNode` | `NodeId`s vizinhos separados por vírgula, sem espaço (`Q2,N-Z02-04`) | sim (≥ 1) |
| `Crosswalk` | string | `NpcNode` | `CW-1`..`CW-4`, só nos dois nós de meio-fio de cada faixa | não |
| `Vehicle` | string | `Vehicle` | chave de `Content.Vehicles` (`cart`, `trailer`) | sim |
| `StationKind` | string | `Station` | chave de `Content.Stations` (§18.4) | sim |
| `Ingredient` | string | `Station` (estação de um ingrediente só) ou `Interactable` (tigela) | chave de `Content.Ingredients` | conforme §18.4 |
| `PromptAction` | string | `Interactable` | chave de `Content.Actions` | sim |
| `Slot` | int ≥ 1 | `Attachment` de vaga (grelha, trilho, tábua) e o `Interactable` que age numa vaga | 1..n, da esquerda para a direita vista do corredor | conforme §18.4 |
| `Level` | int ≥ 1 | âncora cuja posição muda por nível de upgrade | nível em que a âncora vale; sem `Level` = vale em todos | não |
| `Package` | string | `Interactable` de prateleira do Mart | chave de `Content.Packages` | sim, nas prateleiras |
| `BenchSlot` | string | `Interactable` da bancada | `B1`..`B5`, `S1` (MAP-01 §7.4) | sim, na bancada |
| `Upgrade`, `Level` | string, int | `UpgradePiece` | chave de `Content.Upgrades`, nível que a peça mostra | sim |
| `TopHeight` | number (studs) | cobertura em `Assets.Items.Toppings` | altura do pivô ao topo real (DEC-142) | sim |

**De runtime** (escritos pelo dono; lidos por quem está na coluna):

| Atributo | Tipo | Em | Escreve | Lê |
|---|---|---|---|---|
| `EntityId` | int 1..65535 | `Interactable` | `InteractionService` (registro, T33) | `PromptController` → `Interact{Id}` |
| `PromptEnabled` | bool | `Interactable` | dono da ação (Kitchen, Market, Round, Customer…) | `PromptController` (falso = não aparece) |
| `PromptText` | string | `Interactable` | dono da ação, quando o texto muda ("Restock (7/12)", "Grill Lv2 — $60") | `PromptController`; ausente = `Content.Actions[PromptAction].Text` |
| `PromptHold` | number (s) | `Interactable` | dono da ação, só quando **difere** da tabela | `PromptController`; ausente = `Content.Actions[...].Hold` |
| `PromptAction` | string | `Interactable` **criado em runtime** (cliente NPC) | dono (ex.: `take_order` → `serve`) | `PromptController` reage à mudança |
| `StationId` | int | `Station` | `KitchenService` | `KitchenController` (liga instância ↔ registro do set `Stations`, §18.14) |
| `Species`, `Outfit`, `CustomerType`, `LookPack` | string | modelo com tag `AnimalRig` (crew e NPC) | servidor: `CharacterService` (crew), `NpcService` (NPC) — `network.md` §5.2 | client que veste (`CrewRig.Dress`, T40); `CameraController` |
| `NpcId` | int | rig de NPC | `NpcService`, novo a cada spawn (`network.md` regra 5) | `CustomerController`; `InteractionService` (âncora → rig → `NpcId`) |
| `Item`, `Count`, `Toppings` | string, int, string | Tool clonada | `ItemService` | `ItemController`, `HotDogVisual`, `PromptController` (pré-checagem de "Add X") |

Raio do prompt: sempre `Content.Actions[PromptAction].Radius` (FEAT-005: estações 7, clientes 10, placas 10), lido
pelos dois lados; o servidor soma a folga na validação (TASK-011).

### 18.3 Âncoras de prompt (`Interactable`)

- **Tipo:** `Attachment` (preferido; `BillboardGui.Adornee` aceita, posição = `WorldPosition`). `BasePart` invisível é
  aceita (`Transparency 1`, `CanCollide`/`CanQuery`/`CanTouch` falsos); o código usa um só helper para os dois casos.
- **Origem:** os empties `Prompt_*` dos `.fbx` (lista em §18.4). Onde o `.fbx` não tem (caixa de pães, placa OPEN,
  gôndolas), a TASK-005 cria um `Attachment` com o mesmo padrão de nome (`Prompt_<Ação>`), só para leitura humana: o
  código não lê o nome, lê a tag e os atributos. **A TASK-005 confere no place** se os empties chegaram como
  `Attachment`; nome divergente se corrige no place, não no código.
- **Uma âncora, uma ação por vez.** Duas ações no mesmo objeto = duas âncoras (ex.: tigela com `Prompt_Use_<Ing>` e
  `Prompt_Restock_<Ing>`). Âncora de runtime pode trocar `PromptAction` (cliente: "Take Order" → "Serve").
- **Dono da âncora** = o `Station` ancestral; se não houver, o `Model` ancestral mais próximo. Encaixes por nome
  (`Price_Anchor_B1`, `Fill_Ketchup`, `Value_Anchor`) são buscados **só dentro do dono** (ou do `Vehicle`, §18.4).
- **Registro (servidor, T33):** `InteractionService` no `OnStart` varre `GetTagged("Interactable")` dentro do
  `Workspace`, ordena por `GetFullName()` e dá `EntityId` 1, 2, 3…; escuta `GetInstanceAddedSignal`/`Removed` para
  âncoras de runtime (NPC, item derrubado). Id liberado volta ao uso só depois de 10 s (evita `Interact` atrasado cair
  no alvo errado).
- **Registro (client):** `PromptController` usa a mesma tag; âncora sem `EntityId` ainda não existe para ele (espera
  `GetAttributeChangedSignal("EntityId")`).
- **Visibilidade por jogador** (FEAT-005: "Add Ketchup" só com Hot Dog na mão) é pré-checagem **local** do client
  (`Content.Actions[...].Requires` + Tool na mão + atributo `Toppings`); `PromptEnabled` é o estado **global**. O
  servidor sempre revalida (TASK-011).

### 18.4 Estações e âncoras da onda 1 (carrinho, Mart)

Prefixo de modelo = `id` de `MAP-01_placements.luau`. Na TASK-005 os modelos `CART-*` viram **descendentes** do modelo
`CART` (tag `Vehicle`, `Vehicle = "cart"`): o veículo da estação é o `Vehicle` ancestral (sem atributo repetido) e o
conjunto anda junto no `PivotTo` (T36).

`StationKind` proposto (dono da tabela: TASK-001, §18.14). Ações = chaves de `content-data.md` §3.18.

| MAP-01 §7.1 | Modelo | `StationKind` | `Ingredient` da estação | `Interactable` (âncora → `PromptAction`, extras) | Vagas (`Slot`) | Encaixes por nome lidos |
|---|---|---|---|---|---|---|
| S estoque | `CART-S` AST-018 CoolerL1 | `sausage_stock` | `sausage` | `Prompt_Take` → `grill_place` ("Grill", FEAT-006 passo 1); `Prompt_Restock` → `restock` | — | `Fill`, `Lid`, `VFX_Upgrade` |
| G grelha | `CART-G` AST-012 RollerGrill | `grill` | — | cada vaga é também âncora: `Att_Slot<n>` → `grill_collect`, `Slot = n` | `Att_Slot1..4` → `Slot` 1..4 (L1 usa 1–2, L2 1–3, L3 1–4, DEC-201). O `.fbx` tem 6: a TASK-005 escolhe as 4 dos rolos usados e marca `Level` se a posição mudar (`Q-134` c) | — (barra = `ProgressBar` na vaga) |
| R trilho | `CART-R` AST-013 `Rail_6` | `rail` | — | nenhuma (`Prompt_Rail` fica **sem tag**: "Add Sausage" é na tábua) | `Slot1..6` → 1..6 (trailer 8) | — |
| B pão | `CART-B` AST-015 BunCrate | `bun_crate` | `bun` | `Prompt_Take` → `bun_cut` ("Slice Bun", hold 0,5); `Prompt_Restock` → `restock`. **O `.fbx` não tem empties: TASK-005 cria** | — | `Fill` (se existir) |
| T tábua | `CART-T` AST-014 CuttingBoard | `board` | — | `Prompt_Board` → `board_add_sausage` (**um** prompt; o servidor escolhe a vaga com pão cortado mais antiga, DEC-190) | **2 vagas compartilhadas** (DEC-190): `Att_Bun1`, `Att_Bun2` com `Slot` 1, 2, criadas pela TASK-005 a partir de `Att_Bun` | — |
| K complementos | `CART-K` AST-017 ToppingGrid | `toppings` | — (por âncora) | por ingrediente: `Prompt_Use_<Suf>` → `topping_add` ("Add {item}") + `Ingredient`; `Prompt_Restock_<Suf>` → `restock` + `Ingredient` | — (a "vaga" é o ingrediente) | `Fill_<Suf>`, `Label_<Suf>` (SurfaceGui + ícone, DEC-156), `Lid_<Suf>`, `Att_Lock_<Suf>` (cadeado do bloqueio; **novo**, no modelo de tigelas da DEC-156; até lá o cadeado vai no centro de `Lid_<Suf>`) |
| H/$ entrega + gaveta | `DRAWER` AST-020 | — (**não é `Station`**) | — | nenhuma na onda 1: "Serve" é **no cliente** (DEC-190). `Prompt_Serve`/`Prompt_Drawer` ficam sem tag | — | buscados dentro do `Vehicle`: `Value_Anchor` (valor da gaveta, TASK-024; **o `.fbx` atual não tem: TASK-005 cria** no topo da POS), `Bar_Thief`, `VFX_Coins` |
| lixeira BIN-C | `BIN-C` AST-025 | `trash` | — | `Prompt_Discard` → `discard` ("Throw Away", hold 0,5) | — | `Lid` |
| placa OPEN | `OPEN` AST-024 | — (**não é `Station`**; fica no mapa, não no veículo: MAP-01 §7.3) | — | `Prompt_Open` → `open_sign` (**criar**; `RoundService`, TASK-012) | — | — |
| veículo | `CART` AST-026 | — | — | — | — | `Zone_Center` (raio 14 do ladrão, DEC-050), `Mount_*` (só ferramenta) |

`<Suf>` = chave do ingrediente em PascalCase (`ketchup` → `Ketchup`, `potato_sticks` → `PotatoSticks`,
`cream_cheese` → `CreamCheese`), que é exatamente o sufixo dos `.fbx`. Regra fixa, sem tabela.
Grade (MAP-01 §7.1): frente `Ketchup`, `Mustard`, `Cheese` (X 45, 47, 49); fundo `Bacon`, `PotatoSticks`,
`CreamCheese`. Os empties `Att_Cell_F1..B3` são internos do asset: o código não lê (e `B1..B3` ali não têm relação com
a bancada nem com o prédio B1).

**Mart (MAP-01 §7.4).** Não há `Station`: são `Interactable` soltos, dono = o `Model` ancestral.

| Âncora | Onde | `PromptAction` | Extras |
|---|---|---|---|
| 9 prateleiras | `Attachment`/`Part` `BUY-<Nome>` nas posições da tabela "Ponto de compra" (as gôndolas e geladeiras **não** têm empties; a TASK-005 cria dentro de um `Model` `MKT-SHELVES`, Persistent), altura ~4,5 do piso | `buy_package` | `Package` = `pack_sausages`, `pack_buns`, `pack_ketchup`, `pack_mustard`, `pack_cheese`, `pack_bacon`, `pack_potato_sticks`, `pack_cream_cheese`, `pack_coffee` (chaves de `Content.Packages`; TASK-001 confirma) |
| bancada B1–B5 | `Prompt_Buy_B1..B5` do AST-049 (`GEAR_WALL`) | `bench_buy_upgrade` | `BenchSlot` = `B1`..`B5`. Qual upgrade está em cada vaga é **dado** (`Content.Upgrades.BenchSpot`), não atributo do place |
| bancada S1 | `Prompt_Buy_S1` do AST-049 | `bench_buy_item` | `BenchSlot = "S1"` |

Encaixes do AST-049 lidos pelo `MarketController` dentro do dono: `Price_Anchor_<Slot>`, `PriceTag_<Slot>`,
`Slot_<Slot>` (miniatura), `Light_S1`, `VFX_Rare`. Prateleira usa a própria âncora como lugar do preço.

**Âncoras de runtime** (mesmo contrato, criadas pelo dono): cliente NPC = `Attachment` `Prompt_Customer` no
`HumanoidRootPart` do rig do pool (criado uma vez por rig pelo `NpcService`; `PromptAction` trocado pelo
`CustomerService`: `take_order` → `serve`; "Refuse" numa segunda âncora `Prompt_Refuse`, 1,5 abaixo); item derrubado =
a própria Tool no `Workspace` com `pick_up_item` (`network.md` §7).

**Onda 2 (mesmo padrão, sem detalhar agora):** trailer (`Vehicle = "trailer"`, estações iguais às do carrinho com
`Rail_8`; `Prompt_Brew`/`Prompt_Restock` da cafeteira; `Prompt_Switch`; `Hide_1..4` → `hide` + `Slot`; `Prompt_Buy` no
trailer à venda → `buy_trailer`; `Prompt_Answer` do telefone; lixeiras de rua com `Prompt_Discard`, DEC-200, `Q-166`).

**Peças de upgrade (T38).** `UpgradePiece` com `Upgrade`/`Level`; o `UpgradeService` mostra a do nível atual e
esconde as outras (guarda `Transparency`/`CanCollide`/`CanQuery` originais em atributos, como `place_assets.hide`),
**sem reparentar**. Peça não contém `Interactable` nem `Attachment` de vaga: esses ficam na raiz da estação (com
`Level` se a posição muda). Nível é **por veículo** (DEC-184): a peça do trailer é outra instância.

### 18.5 Pontos (`MapPoint`)

- `Part` 1 × 1 × 1, `Anchored`, `Transparency 1`, `CanCollide`/`CanQuery`/`CanTouch` falsos, dentro de
  `workspace.MapBinding` (pasta livre). **Posição** = no chão onde se pisa (Y do piso, por raycast; os marcadores do
  blockout ficam a Y 1,2 e precisam descer). **Frente** = `LookVector`, horizontal (os marcadores do blockout já usam
  `CFrame.lookAt` com `face`: copiar o giro).
- Os marcadores de `MAP01_Blockout.Markers` têm os mesmos IDs e servem de fonte; o binding **não** fica dentro do
  blockout (ele sai em produção).
- Spawn de personagem: `HumanoidRootPart` em `ponto.Position + (0, 3, 0)` com a frente do ponto.

| `PointId` (MAP-01) | § | Quem lê | Uso | Onda |
|---|---|---|---|---|
| `PS-1`..`PS-4` | 5.1 | `CharacterService` | spawn de dia, reconexão, atrasado; olhando para o norte | 1 |
| `Q1`..`Q5` | 5.1 | `CustomerService` (fila), também `NpcNode` | vagas do balcão; `Q1` olha para o sul (carrinho), `Q2..Q5` para o leste | 1 |
| `D1`, `SP-A`, `EX-E` | 5.3 | `NpcService`, também `NpcNode` | chegada/saída | 1 |
| `OP-1` | 7.4 | `OpalController` (client, TASK-038) | onde a Opal é montada, olhando para dentro da loja; raio de fala 8 a partir dele | 1 |
| `PS-N1..4`, `REV-1..4`, `AMB-M`, `AMB-P`, `SPEC-P`, `SPEC-M`, `SS`, `SP-B`, `L1..L3`, `ST-R`, `H1..H4`, `CS-*`, `WALKER-0..10`, `AN-*`, `AS-*`, `W-IN`…`JS-OUT`, `CART`, `TRL`, `TRL-SALE` | 5.1–5.6, 9, 11 | Services da onda 2 | mesma regra | 2 |

Bancada (`B1`..`B5`, `S1`) **não** é `MapPoint`: é valor de `BenchSlot`. Assim `B1` nunca vira `PointId` e não colide
com o prédio B1 (MAP-01 §4, Z-09) nem com a letra "B" do pão. Ponto novo que não existe no MAP-01 (ex.: pivô do
carrinho sob a lona, DEC-199) ganha ID novo registrado pelo level-designer no MAP-01 antes de ser usado.

### 18.6 Grafo `NpcNode`

| Regra | Valor |
|---|---|
| Nó | `Part` invisível (como `MapPoint`), Y no piso; `NodeId` = `N-<zona>-<nn>` (`N-Z02-03`) ou o `PointId` quando o nó é ponto (`SP-A`, `D1`, `EX-E`, `Q1`..`Q5`) |
| Aresta | `Links` em pelo menos um dos lados; o `MapIndex` simetriza (não direcionado) |
| Aresta válida | reta caminhável, sem obstáculo, **≤ 40 studs** (`Humanoid:MoveTo` desiste em 8 s; cliente anda ~8 studs/s) |
| Pista | nenhuma aresta cruza pista, **salvo** a aresta de faixa: os dois nós de meio-fio de uma faixa têm o mesmo `Crosswalk` (`CW-4`) e se ligam; essa aresta pede reserva ao `TrafficService` (DEC-133). Onda 1: sem trânsito, a aresta é livre (TASK-031) |
| Fila | `Q5`–`Q4`–`Q3`–`Q2`–`Q1` em cadeia; a chegada liga só em `Q5` (ponta oeste); saídas saem de `Q1` (→ `EX-E` pela LANE-E; → `D1`) |
| Tamanho | ≤ 80 nós (§12.3) |
| Busca | A* com custo euclidiano, desempate por `NodeId` (ordem de string): mesmo caminho no servidor e no client (T28, T39) |
| Ladrão | evita arestas de faixa (nunca cruza pista, MAP-01 §9.2) |
| Onda 1 obrigatório | um componente conexo com `SP-A`, `D1`, `EX-E`, `Q1`..`Q5`, seguindo `ROUTE-SP-A`, `ROUTE-D1-IN`, `ROUTE-QUEUE`, `ROUTE-EXIT-E`, `ROUTE-EXIT-D1` do blockout. `SP-B`, `ST-R`, espreitas: onda 2 |

### 18.7 Checagem (aceite da TASK-005)

Ferramenta de edição `tools/assetplace/check_binding.luau` (protótipo da TASK-005, roda no Command Bar) e, em runtime,
`MapIndex.Validate` (§18.8) com a **mesma lista** (`src/Place/shared/MapIndex/Required.luau`). Falha = lista de
problemas; zero problema = aceite.

1. Toda tag de §18.1 da onda 1 presente; `MapBinding` exatamente 1; `PointId` e `NodeId` únicos.
2. Todo `PointId`/`Station`/`Interactable` exigido por §18.4–§18.6 existe (lista em `Required.luau`).
3. Atributo com valor fora de `Content` (`StationKind`, `PromptAction`, `Ingredient`, `Package`) = erro.
4. Âncoras de **estações vizinhas** a ≥ 2,5 studs (MAP-01 §7); dentro da grade de complementos vale 2,0 (uma
   ação aparece por vez: "Add" exige Hot Dog, "Restock" exige pacote).
5. `Station` descendente de um `Vehicle`; todo `Model` com tag de gameplay `Persistent`; nada tagueado fora do
   `Workspace`.
6. Grafo conexo; `Links` sem id desconhecido; nenhuma aresta > 40 studs; nenhuma aresta cruza os retângulos de pista
   do MAP-01 (Z-03, Z-07, Z-08) fora de aresta de faixa.
7. Pivôs das estações do carrinho a y 3,45 (bancada 3,0, DEC-157; **Provisório até `Q-153`**: se a altura mudar,
   mudam os pivôs, o binding não).
8. Ao passar, grava na raiz `MapBinding`: `BindingVersion` (int, +1 por mudança), `PointCount`, `NodeCount`,
   `InteractableCount`. O client usa as contagens para saber que o streaming entregou tudo (§18.8).

### 18.8 `MapIndex` (código compartilhado de leitura do mapa)

`src/Place/shared/MapIndex/` → `ReplicatedStorage.shared.Place.MapIndex`. Puro: sem Modux, Lync, Vide nem `self.Libs`;
cache preenchido na primeira chamada. Nota ao task-planner: **nenhuma task da onda 1 tem este módulo**; o natural é
a TASK-010 (Place), antes da TASK-031.

```lua
MapIndex.WaitReady(timeout: number?): boolean          -- client: espera as contagens da raiz MapBinding
MapIndex.Point(id: string): CFrame                     -- error se faltar
MapIndex.FindPoint(id: string): CFrame?
MapIndex.Points(prefix: string): { [string]: CFrame }  -- "PS-", "Q", "REV-"
MapIndex.Node(id: string): { Position: Vector3, Links: { string }, Crosswalk: string? }
MapIndex.Path(from: string, to: string, opts: { AvoidCrossings: boolean? }?): { string }?
MapIndex.Validate(required: Required.List): { string } -- problemas (vazio = ok)
```

`PlaceService` (servidor) roda `Validate` no `OnStart`: no Studio, problema = `error` (falha alta, R8); em servidor
publicado, `warn` e segue. Registro de `Interactable` e `Station` **não** passa pelo `MapIndex`: é do
`InteractionService` e do `KitchenService` (donos únicos, §4 regra 1).

### 18.9 Kits de asset

**Regras (T34).**
1. **Proibido `InsertService` em código de `src/`** (QA: `rg InsertService src` vazio). Ele fica só nas ferramentas
   de edição (`tools/assetplace/`).
2. `MeshPart.MeshId` não é gravável em runtime: **malha só existe como instância** num kit e é clonada.
3. `TextureID` e imagem **são** graváveis: ids `rbxassetid://` ficam em **módulo de dados** versionado no git
   (`CrewLooks`, `Content.Ingredients.Icon`).
4. `SurfaceAppearance.ColorMap` não é gravável em runtime: cada expressão é uma `SurfaceAppearance` pronta, clonada.
5. Os kits ficam **fora do Rojo**: `ReplicatedStorage.Assets` e `ReplicatedStorage.CrewExpressions` (o
   `default.project.json` não dá `$path` ao `ReplicatedStorage`, então instâncias do place sobrevivem ao `rojo serve`).
   **Nunca dentro de `ReplicatedStorage.shared`** (tem `$ignoreUnknownInstances = false`: o Rojo apaga).
6. Kit montado **em modo de edição** por script reproduzível (`tools/assetplace/build_kits.luau`, TASK-006/007, mesmo
   padrão de `place_assets.luau`: `InsertService` + `_asset_ids.json`, idempotente, `PackageLink` removido). O place
   não está no git; o script é a receita para refazer.
7. Rastreio: cada peça de kit tem atributo `Asset = "AST-###_<nome>"`; a raiz `ReplicatedStorage.Assets` tem
   `KitVersion` (int). `CrewLooks.KitVersion` diferente do place = aviso alto no Studio.
8. Kits em `ReplicatedStorage` porque os dois lados clonam (servidor: rigs e Tools; client: Opal, visuais de estação,
   prévia na tela "Crew", troca local de NPC). Custo de memória: malhas pequenas (≈ 2–2,5k tris por personagem,
   DEC-164); texturas só baixam quando aplicadas.

#### 18.9.1 Árvore

```
ReplicatedStorage
├─ Assets                       (Folder, KitVersion)
│  ├─ Crew
│  │  ├─ Body                   AST-053_CrewTex sem Head: Torso, Left/Right Arm, Left/Right Leg, Apron, Cap
│  │  ├─ CivilArms              AST-053_CivilArms (braços retos de civil, DEC-161)
│  │  ├─ CapEarsUp              AST-053_CrewCap_EarsUp
│  │  ├─ Hats/ThiefHat          AST-053_ThiefHat
│  │  ├─ Animals/<Animal>       AST-053_Animal_<A> (18): Head_<A>, Face_<A>, Ears_<A>, Tail_<A>, extras
│  │  └─ Accessories/<chave>    AST-054 (crachá, mochila, capacete…), quando existirem
│  ├─ Items
│  │  ├─ Tools/<item>           Tool por chave de Content.Items: hot_dog, pack_sausages … pack_coffee
│  │  ├─ Toppings/<ingrediente> ketchup, mustard, cheese, bacon, potato_sticks, cream_cheese (TopHeight)
│  │  └─ Food                   SausageRaw, SausageGrilled (AST-002), BunClosed, BunOpen (AST-001)
│  └─ Equipment                 Padlock (AST-020_Padlock, Att_Hang); variantes que não estão no place
└─ CrewExpressions              SurfaceAppearance: Normal, Happy, Smile, Sad, Fainted, Skeptical, Exhausted,
                                Stressed, Thief, Normal_Night (só esta tem _Night, DEC-207)
```

`AST-053_CrewBase` (rig de referência + `_joints.json`) **não** entra no kit de runtime: as juntas são resolvidas pela
pose de repouso (abaixo). Nome de cada `SurfaceAppearance` = nome em `Content.Looks.Expressions` (= sufixo das chaves
`T_Expr_<Nome>` do JSON: `Smile`, não `Smiling`). Só `Normal_Night` tem versão de noite (DEC-207).

#### 18.9.2 Personagem (referência: `build_crew.luau`; produção: `CrewRig`, TASK-016)

- Todas as peças do kit guardam a **pose de repouso importada** (origem comum nos pés, frente −Z). `CrewRig.Build`
  resolve o `C1` de cada `Motor6D` pela pose, como `Crew.build`: as animações R6 padrão funcionam no rig custom.
- `Head_<Asset>` vira `Head`; `Face_<Asset>` vira `Face` (casca do rosto). Civil (`Outfit ≠ crew`): troca os braços
  por `CivilArms`, tira `Apron`; boné só se pedido. Orelha em pé: `CapEarsUp` no lugar do `Cap` (só crew, salvo
  pedido). Chapéu (`ThiefHat`) substitui o boné, sem subir. Acessório do tipo de cliente soldado onde foi modelado.
  Pelagem = `MeshPart.Color` (dado de `CrewLooks`), escrita no `Build`.
- **Divisão servidor × client (T40, `network.md` §5.1; vale sobre a antiga T35, retirada):**
  - `CrewRig.Build(species, outfit, opts)` roda no **servidor** (crew: `CharacterService`; NPC: `NpcService`):
    monta a geometria, põe a tag `AnimalRig` e os atributos `Species`, `Outfit`, `CustomerType`, `LookPack` (e
    `NpcId` no NPC). As peças clonadas já vêm com o pack **Day** do kit. Depois disso o servidor **só muda atributos**
    (ex.: `LookPack` pela faixa de sanidade ou na virada do turno); **nunca** escreve `TextureID` nem
    `SurfaceAppearance`.
  - `CrewRig.Dress(model, pack, expression)` roda no **client** (equivalente de `Crew.applyTime` + `setExpression`):
    `TextureID` da roupa (`CrewLooks.Outfits[outfit][pack]`) e da cabeça (`CrewLooks.Species[species].Head[pack]`),
    atlas `T_Atlas_Kitchen_<Mid|Night>` nas peças de atlas (guardam `DayTextureID`), e clone da `SurfaceAppearance`
    do rosto (`TextureID` da casca = ""). Pack/rosto efetivos saem dos atributos + camada local (`network.md` §5.3:
    NPC em Night + `Normal_Night` só no client cujo personagem está com `LookPack = "Night"`; rosto da crew pelo pack,
    do NPC pelo `Customers.Mood`).
  - O client veste ao ver um modelo `AnimalRig` (inclusive por streaming) e reveste quando muda um atributo ou a camada
    local. Quem chama: um Controller do client (TASK-016 decide entre `CharacterController`/`NpcController` ou um
    `RigController` único; Opal pelo `OpalController`, que monta e veste localmente).
- API para a TASK-016: `Build` (servidor) e `Dress` (client); `ApplyPack`/`SetExpression` da board viram partes do
  `Dress`. `Expression`, se o `CrewRig` escrever, é atributo **local** de debug.

#### 18.9.3 `CrewLooks` (`src/Crew/shared/CrewLooks.luau`, TASK-006)

Módulo de dados, sem lógica, indexado pelas **chaves de `Content`** (`content-data.md` §1.3 regra 8; §18.0 item 4).
Gerado de `Assets/textures/character/_texture_ids.json` (cópia fiel; chave que não existe no JSON não entra).

```lua
export type Pack = "Day" | "Mid" | "Night"
export type SpeciesLook = { Fur: Color3, EarsUp: boolean, CapRaise: number, Head: { [Pack]: string } }
return table.freeze({
	KitVersion = 1,
	Species = {                                   -- chaves de Content.Species (18)
		dog = { Fur = Color3.fromHex("C98B5A"), EarsUp = false, CapRaise = 0.30,
			Head = { Day = "rbxassetid://…", Mid = "…", Night = "…" } },   -- T_Head_Dog[_Mid|_Night]
		-- …
	},
	Outfits = {                                   -- chaves de Content.Outfits
		crew = { Day = "…", Mid = "…", Night = "…" },     -- T_Crew_Uniform_<Pack>
		civil_a = { Day = "…", Mid = "…", Night = "…" },  -- T_Civil_A_<Pack> … civil_h
		thief = { Day = "…" },                            -- T_Civil_Thief_Day (só dia, DEC-159)
	},
	Atlas = { Mid = "…", Night = "…" },           -- T_Atlas_Kitchen_*; Day = textura original da peça
})
```

Pack ausente → Day. Cor, orelha em pé e subida do boné são **dados por espécie** aqui (o protótipo recebia por
parâmetro). A chave do animal no kit é `Content.Species[k].Asset` (`Dog`). `Validate` da TASK-006: toda chave de
`Content.Species`/`Content.Outfits` tem entrada; todo id existe no JSON. A chave da roupa do ladrão é a de
`Content.Outfits` (`thief` em `content-data.md` §3.10b na data desta versão; se a tabela mudar para `civil_thief`,
o `CrewLooks` acompanha).

#### 18.9.4 Quem aplica o visual (T40, Aprovada pela DEC-208 delegada; T35 retirada)

| Caso | Servidor (atributo) | Client (veste) | Regra |
|---|---|---|---|
| Crew: pack pela faixa de sanidade | `LookPack` no personagem: onda 1 sempre `Day` (`CharacterService`); onda 2 pela faixa (`VitalService`) | todos os clients vestem o mesmo pack | DEC-167, DEC-169 |
| NPC: Day de dia, Mid à noite | `LookPack` no rig (`NpcService`, ao montar e na virada do turno) | veste o pack do atributo | DEC-181 |
| NPC: Night para quem está na faixa baixa | nada (é local) | só o client cujo personagem está com `LookPack = "Night"` à noite veste NPCs em Night + `Normal_Night` | DEC-168, DEC-169 |
| Opal | — | `OpalController` monta e veste localmente | DEC-191, TASK-038 |

Por que T40 e não a T35 desta seção (versão anterior): é o texto da DEC-169 ("servidor replica a faixa; cada client
aplica a textura daquele personagem"); com o servidor escrevendo textura, a troca local da DEC-168 seria desfeita a
cada escrita (virada Day → Mid, rig reaproveitado do pool). Pré-carga e memória: `network.md` §5.1, `Q-144` (g).

#### 18.9.5 Itens e comida (TASK-007; usados pelas TASK-022, 023, 030)

| Peça | Contrato |
|---|---|
| Tool `hot_dog` (AST-003, versão **sem molho**) | `Handle` = peça raiz com origem na pegada (style guide, Tool); `Att_Topping1` no topo da salsicha; `Att_Serve`; `Grip` ajustado para o `RightGripAttachment` do braço da crew (a TASK-007 confere no rig custom); `CanBeDropped = false`. `Att_Topping2/3` do `.fbx` **não** são usados (DEC-142 trocou o passo fixo pela altura real) |
| Tools de pacote `pack_*` (AST-011) | mesmo padrão; forma por pacote = ficha AST-011 (art-director); nome da Tool clonada = `Content.Items[key].Name` (texto da hotbar); atributo `Item` = chave, `Count` = sobra |
| Coberturas `Toppings/<ing>` | `Model` com pivô = ponto de apoio (`Att_Topping` do `.fbx`); `TopHeight` = do pivô ao topo real, **medido** (Bacon 0,115 e Potato Sticks 0,119 já medidos, DEC-142; os outros pela TASK-007) |
| `HotDogVisual` (TASK-023) | 1ª cobertura no `Att_Topping1`; cada seguinte no pivô anterior + `TopHeight` anterior, no eixo para cima do `Att_Topping1`; **queijo sempre antes dos cordões** (Ketchup, Mustard, Cream Cheese), resto na ordem de montagem. Chamado pelo `ItemService` no servidor (replica) |
| `Toppings` na Tool | string com chaves na ordem de montagem, separadas por vírgula (`"ketchup,cheese"`); a ordem visual é do `HotDogVisual`. Formato final: `content-data.md` (TASK-001) |
| Comida de estação (`Food/*`) | pivô = centro da base, apoiada no `Attachment` da vaga; clonada **no client** pelo `KitchenController` a partir do set `Stations` (não cria instância no servidor) |

### 18.10 Onde ficam os ids em produção

| Id | Onde | Gravável em runtime? | Origem |
|---|---|---|---|
| Malha (`MeshId`) | só nas instâncias dos kits e do mapa | não | import no Studio / `build_kits.luau` |
| Modelo (`_asset_ids.json`) | só `tools/assetplace/` | — (nunca em runtime) | upload do grupo |
| Textura de personagem (`TextureID`) | `CrewLooks.Textures` | sim | `_texture_ids.json` |
| Expressão (`SurfaceAppearance.ColorMap`) | `ReplicatedStorage.CrewExpressions` | não | `Crew.ensureExpressions` em modo de edição |
| Ícone de ingrediente, imagens de UI | `Content.Ingredients.Icon` e tabelas de conteúdo | sim | art-director (`Q-152`) |
| Developer product | `Content.Products` | — | Creator Hub (§10.1) |

### 18.11 Layout de módulos

Verificado nesta sessão com `rogen 1.4.4` num projeto de teste (scratchpad): `src/<F>/shared/` vira
`ReplicatedStorage.shared.<F>`; `server/` e `client/` seguem como hoje; arquivo solto na raiz da feature e pasta
`shared/` se fundem no mesmo `shared.<F>`.

| O quê | Onde | DataModel | Regras |
|---|---|---|---|
| Service/Controller de um arquivo | `src/<F>/server/<Nome>Service.luau`, `src/<F>/client/<Nome>Controller.luau` | `ServerScriptService.server.<F>` / `…client.<F>` | padrão atual |
| Service/Controller com ajudantes | `src/<F>/server/<Nome>Service/init.luau` + filhos (precedente: `ProfileService/Template.luau`) | idem | filho é `ModuleScript` comum: **não** chama `Modux.Service/Controller/Component` (o `modux generate` o registraria), não registra responder, **não fala com a rede** (devolve dados; quem publica é o Service). Recebe dependências por parâmetro. Pode requerer `Content`, `shared.Libs.*` (servidor: Charm, Signal) e `shared.<F>`; no client pode requerer Vide |
| Component | `src/<F>/server/<Nome>.luau` (precedente: `Vital`) | idem | tag = nome do Component, nunca uma tag de §18.1 |
| Código dos dois lados | `src/<F>/shared/<Módulo>.luau` ou `src/<F>/shared/<Módulo>/init.luau` | `ReplicatedStorage.shared.<F>.<Módulo>` | **puro**: sem Modux, Lync, Vide, átomo Charm ou `self.Libs`; só Luau + API do Roblox + `Content`. Não criar arquivo solto na raiz da feature (`src/Net/Log.luau` é legado) |
| Tabelas | `src/Shared/Content/` | `ReplicatedStorage.shared.Content` | `content-data.md` |
| Componentes de UI | `src/Interface/client/Components/<Nome>/init.luau` + `.story.luau` | | só props (TASK-013) |

Nome de feature proibido (colide em `ReplicatedStorage.shared`): `Types`, `tablejs`, `Content`, `Libs`, `Modux`.

Onda 1, arquivos novos por feature (dono = task da board):

| Feature | server | client | shared |
|---|---|---|---|
| `Place` | `PlaceService.luau` | `PlaceController.luau` | `MapIndex/` (`init`, `Graph`, `Required`) |
| `Interaction` | `InteractionService/` (`init`, `Registry`) | `PromptController.luau`, `Prompt.luau` | — |
| `Kitchen` | `KitchenService/` (`init`, `StationApi`, `Stations/*.luau`) | `KitchenController/` (`init`, `Stock`, `Grill`, `Rail`, `Board`) | — |
| `Crew` | — | quem chama `CrewRig.Dress` (Controller a definir na TASK-016, §18.9.2) | `CrewLooks.luau`, `CrewRig/` (`Build` no servidor, `Dress` no client) |
| `Item` | `ItemService/` | `ItemController` | `HotDogVisual/` |
| `Customer` | `CustomerService/` (`init`, `Queue`, `Orders`) | `CustomerController` | — |
| `Npc` | `NpcService/` (`init`, `Pool`, `Walker`): monta com `CrewRig.Build`, escreve atributos e `NpcId` | `NpcController` (veste; troca local Night na onda 2) | — |
| `Character`, `Class`, `Economy`, `Upgrade`, `Market`, `Run` | `<Nome>Service/` | `<Nome>Controller` | — |
| `Camera`, `Hud`, `Opal` | — | `<Nome>Controller.luau` | — |

O `KitchenController` lista os filhos **explicitamente** no `init` (TASK-029 → TASK-030 são sequenciais). O
`KitchenService` **descobre** `Stations/` (TASK-026/027/028 correm em paralelo e não podem disputar o init; regra da
board).

### 18.12 Contrato `KitchenService/Stations/*.luau` (T37)

`KitchenService/StationApi.luau` (escrito pela TASK-025, junto com o init) define os tipos; cada arquivo de
`Stations/` devolve um `StationApi.Module`.

```lua
--!strict
export type Station = {
	Kind: string,                          -- StationKind
	Vehicle: string,                       -- do Vehicle ancestral
	Instance: Model,
	Id: number,                            -- StationId (runtime)
	Ingredient: string?,
	Slots: { [number]: Attachment },       -- Attachment com Slot, filtrado pelo Level do upgrade atual
	State: any,                            -- estado privado do módulo, criado em Bind
}
export type Context = {                  -- só funções: o módulo nunca vê Lync, átomo nem outro Service inteiro
	Now: () -> number,                     -- workspace:GetServerTimeNow()
	TakeStock: (ingredient: string, n: number) -> boolean,
	GetStock: (ingredient: string) -> (number, number),     -- atual, capacidade
	Give: (player: Player, item: string, attrs: { [string]: any }?) -> boolean,
	Held: (player: Player) -> Tool?,
	Consume: (player: Player, tool: Tool) -> (),
	Modifier: (player: Player, stat: string) -> number,     -- ClassService
	Effect: (stat: string) -> number,                       -- UpgradeService, veículo atual
	Publish: (station: Station) -> (),                      -- o KitchenService grava o set Stations
	Notify: (player: Player, notice: string, value: number?) -> (),
	SetPrompt: (anchor: Instance, enabled: boolean, text: string?) -> (),
}
export type Action = {
	Validate: (ctx: Context, station: Station, player: Player, anchor: Instance) -> (boolean, string?),
	Run: (ctx: Context, station: Station, player: Player, anchor: Instance) -> (),
}
export type Module = {
	Kinds: { string },
	Actions: { [string]: Action },         -- chave de Content.Actions
	Bind: (ctx: Context, station: Station) -> (),
	Tick: ((ctx: Context, station: Station, now: number) -> ())?,  -- 10 Hz, só se tiver timer
	Capture: (ctx: Context, station: Station) -> any,              -- chaves estáveis (Slot, Ingredient)
	Restore: (ctx: Context, station: Station, data: any) -> (),
}
return nil
```

Ciclo:
1. `OnInit` (prioridade 650 < `InteractionService` 730): `require` de cada `ModuleScript` de `script.Stations`
   (cast para `Module`, forma conferida em runtime); `Kind` repetida em dois módulos = `error`. Para cada **chave de
   ação** distinta (união de todos os módulos), **uma** chamada a `InteractionService:RegisterAction`.
   `RegisterSnapshot("Kitchen", …)` no `RunStateService`.
2. `OnStart`: varre `GetTagged("Station")` no `Workspace`; monta `Station`; `StationKind` sem módulo = `error` no
   Studio; chama `Bind`; escreve `StationId`.
3. `Interact` chega → `InteractionService` resolve a âncora → `KitchenService` acha a `Station` dona → módulo da
   `Kind` → `Actions[ação].Validate` e `Run`, serializados por estação (critério "só um recebe" da FEAT-006).
4. `restock` é do **núcleo** (TASK-025, por `Ingredient`), não de módulo. Estação de veículo que não é o atual:
   prompts desligados e ações recusadas (T36).

Arquivos da onda 1: `Grill.luau` + `Rail.luau` (TASK-026; `Rail` sem ações, só a fila FIFO e `Capture`),
`BunCrate.luau` + `Board.luau` (TASK-027), `Toppings.luau` + `Trash.luau` (TASK-028). O estoque do cooler
(`sausage_stock`) é atendido pelo `Grill.luau` (`Kinds = { "grill", "sausage_stock" }`, ação `grill_place`).

### 18.13 Contrato `CustomerService/*.luau`

| Arquivo | Conteúdo | Task |
|---|---|---|
| `init.luau` | Service: estado por cliente (tabela por id), átomos, set `Customers`, `RegisterAction` de `take_order`, `serve`, `refuse` no `OnInit`, snapshot | TASK-032 (+ registro da TASK-033) |
| `Queue.luau` | puro: vagas ativas pelo nível de Counter (`Q1..Q3/Q4/Q5`), quem avança para onde, `PointId` de cada vaga | TASK-032 |
| `Orders.luau` | puro: sorteio de K e dos complementos com `Random` da semente (§4 regra 6), paciência, janela de gorjeta, `Validate(order, toppings) -> Result` e valor; nenhum `Spend`/`AddToDrawer` aqui (quem paga é o init via `EconomyService`) | TASK-033 |

Rotas: o `NpcService` pede `MapIndex.Path`; o `CustomerService` só diz o destino (`PointId`).

### 18.14 Conciliação com a TASK-001 (`network.md`, `content-data.md`, `data.md` v4)

Conferido com a versão final da TASK-001 (2026-10-10). Este documento não edita aqueles três.

| Ponto | Situação |
|---|---|
| Chaves de `Stations` | adotadas por `content-data.md` §3.6: `sausage_stock`, `grill`, `rail`, `bun_crate`, `board`, `toppings`, `trash` (+ `coffee_machine`). Gaveta, placa, prateleiras e bancada não são estação |
| Instância ↔ registro de `Stations` | atributo `StationId` (≤ 99) no `Model`; id do registro = `StationId × 100 + Slot` (`Slot = 0` no trilho), `network.md` §3.5 |
| `EntityId` | `InteractionService` para toda âncora (mapa e runtime), T33; `NpcId` separado no rig (`network.md` regra 5) |
| Ações | `topping_add` (sai `board_add_topping`); `bench_buy_item` existe sem prompt ativo na onda 1; `pick_up_item` ("Take", toque) ativo na onda 1 só no pacote grátis (N-03, `network.md` §7) |
| `BenchSpot`, `Vehicles.Model`, `Species.Asset`, sufixo PascalCase | adotados como aqui (§18.4, T36, §18.9.3) |
| Aparência | **vale a T40** (`network.md` §5): servidor monta e escreve atributos, client veste; T35 retirada (§18.9.4) |
| Valores de `Outfit` | chaves de `Content.Outfits` (`crew`, `civil_a`..`civil_h`, `thief`); `CrewLooks` indexado por elas |
| Expressões | `Smile` (nome do JSON) em `Content.Looks.Expressions` |
| Nome do atributo da chave do item na Tool | **`Item`** em todos (`network.md` §7.1/§11, `content-data.md` §3.5, este §18.2); fechado na TASK-003 |
| Chave da roupa do ladrão | **`thief`** (`content-data.md` §3.10b, `network.md` §5.2, `Content.Outfits`); `CrewLooks` segue a tabela. Fechado na TASK-003 |
| Numeração | T32–T40 no §14 (T35 retirada; T40 detalhada em `network.md` §5.1). Decididas pelo architect por delegação da DEC-208 (técnica que não muda regra de jogo) |
