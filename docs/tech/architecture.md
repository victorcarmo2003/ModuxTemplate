Status: Rascunho

# Arquitetura técnica

Autor: architect. Versão 3.1, 2026-10-08 (conciliação com DEC-106 a DEC-130, rodada 17 e `consistency-report.md` §5;
alinhada à **DEC-133** — PARE na Juniper, reserva de faixa para NPC — fechando o lado técnico de `Q-131`).
**Versão 3.2, 2026-10-10 (Fase 1, TASK-002):** §18 novo (binding do MAP-01, kits de asset, layout de módulos), T32–T39.
**Versão 4.0, 2026-10-10 (pós onda 1):** §19 novo — contratos das ondas 2–4 sobre o código entregue na onda 1 (commit
`e7ee154`): run completa, noite, sanidade, luz, café, chefe, ladrão, gemas, anomalias, esconder, cutscenes, trânsito,
passantes, ambulância/reviver, lobby/sessão, animação e áudio; pontos de extensão dos Services da onda 1; ondas
sugeridas; T42–T58. Onde §2–§13 divergem do §19, **vale o §19**.
**Versão 4.1, 2026-10-10 (TASK-049):** divergências da onda 1 fechadas no texto (`wave-1-report.md` D-01, D-07;
§19.26 A5 conferido); `Gems` da run no `RunReport` por passo registrado no `RoundService` (T59); dono do `discard`
na lixeira de rua = `KitchenService` (T60, DEC-200). Ver §0.-3.
**Versão 4.2, 2026-10-10 (DEC-221):** esconderijo sai; janela de serviço do trailer (estado `Shutter` do `VehicleService`,
ação `shutter_toggle`) vira o estado protegido de N8/N9 (§19.14 reescrito, T61; T52 superada).
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

### 0.-3 Versão 4.1 (TASK-049, 2026-10-10)

Só documento; nenhum contrato de código da onda 1 muda. Tudo **Provisório** (DEC-193; T59 e T60 decididas pelo
architect por delegação da DEC-208: técnica, sem regra de jogo nova).

| # | Antes | Agora | Onde |
|---|---|---|---|
| D-01 / A5 | §4.1 com `ShiftEnded(info, report)`; §3.1 com `RoundService` requerendo `VitalService` | conferido contra o código (`RoundService.luau`, `EconomyService/init.luau`): `ShiftEnded(info)` + `EconomyService.Reported(info, report)`; Round **não** requer Vital. Corrigido no próprio §3.1 e §4.1 (antes só havia nota apontando para o §19) | §3.1, §4.1 |
| D-07 | `UpgradeController` no mapa de features (§2.3) e no boot do client (§3.2) | **não existe**: a peça de upgrade é alternada pelo servidor por visibilidade (`UpgradeService/Pieces.luau`, T38), que replica como instância; o client só lê o set `Upgrades` no `MarketController` | §2.3, §3.2; `network.md` §3.7 |
| §19 aberto | `RunReport.Gems` sem caminho (o `RewardService`, 550, requer o `RoundService`, 750; o contrário seria ciclo) | `RoundService:AddRunReportStep(name, fn)`: o `RewardService` registra no `OnInit` um passo que preenche `report.Gems` a partir de `RunRewards.Gems` do perfil (T59) | §19.3, §19.4, §19.11, §19.16; `network.md` §13.1; `data.md` §1.1, §1.3 |
| §19 aberto | lixeira de rua (DEC-200) sem dono de código | `discard` continua com **um** dono, o `KitchenService` (TASK-057): âncora `Prompt_Discard` dentro de `Model` com tag `StreetBin`, fora de `Station` e de `Vehicle` (T60) | §19.3, §19.5, §19.22, §19.25 |

### 0.-2 Versão 4.0 (pós onda 1, 2026-10-10)

| Tema | Antes | Agora | Onde |
|---|---|---|---|
| Relatório do turno | `ShiftEnded(info, report)` (§4.1) | código da onda 1 manda: `ShiftEnded(info)` + `EconomyService.Reported(info, report)`; gemas/AFK/última chance entram por `EconomyService:AddReportStep` antes do envio | §19.3, T48 |
| Ciclos de `Require` | Round ↔ Vital (§3.1) | **proibidos**; central expõe probe/registro, periférico requer o central (Vital → Round, Vehicle → Round) | §19.0, T42 |
| Escuro | dentro do `VitalService` | feature `Light` própria (`LightService`, set `Lights`); Vital só pergunta `IsLit` | §19.6, T45 |
| Esconder | dentro do `AnomalyService` | feature `Hide` (set `Hides`) → **v4.2 (DEC-221): sai**; janela do trailer no `VehicleService` (atributo `Shutter`) | §19.14, T61 |
| Passantes | NPC R6 de servidor no pool de 12 | **ator de client** com cinemática 1D no servidor (set `Pedestrians`), fora do teto de 12 (Provisório, `Q-162` a) | §19.17, T46 |
| Ligação do chefe | packet `BossCall` | **set `Call`** (quem reconecta ouve só as linhas restantes) | §19.9, T44 |
| Anomalias | só packet `AnomalyCue` | set `Anomalies` (estado) + packet `AnomalyCue` (efeito de um instante); sinal visto por todos (DEC-204) | §19.13, T53 |
| Tools no snapshot | `M[uid].T` (RunState) | chave `T` própria do `ItemService` | §19.12, T50 |
| Ambulância antes da onda 4 | — | desmaio na onda 2 sem ambulância: corpo some por `PickupHandler` padrão; Ambulance assume na onda 4 | §19.7, T54 |
| Animação e áudio | sem contrato | `Content.Animations` + `AnimController`; `Content.Sounds`/`Music` + `AudioController`; sem rede | §19.20, §19.21, T47, T55 |
| Streaming (DEC-209) | ligado, raio mínimo (T26) | **desligado** no place Run (mapa sempre carregado); `Persistent` continua exigido pela checagem, sem custo | T57 |
| Técnicas T1–T31 | Provisórias (`Q-130`) | **Aprovadas por DEC-208**; T32+ decididas pelo architect por delegação (DEC-208) | §14 |

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

> **v4.3 (2026-10-11, TASK-154):** substituído por **uma place com papéis de servidor** (`Lobby` público, `Game`
> reservado por squad, `PrivateLobby`): ver **§20**. `Workspace.PlaceRole` só vale no Studio como legado.

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
| `Players.CharacterAutoLoads` | true | **false** (spawn controlado: atrasado, revive, retomada, spectate) | DEC-091, DEC-098  Hoje a place tem `true` (uma place só, DEC v4.3): o `CharacterService` troca qualquer personagem que não seja da crew, então o efeito é o mesmo (auditoria multiplayer 2026-10-20) |
| `StreamingEnabled` | true | true, `StreamingMinRadius` 256, `StreamingTargetRadius` 512; gameplay `Persistent` (§12.4, `Q-087`) | |
| Grupos de colisão | `Players` não colide com `Players` | idem + `Npc` não colide com `Players`/`Npc` | `Q-086` |
| Developer product "Revive" | criado no Creator Hub (id em `Content.Products`) | mesmo | DEC-092 |
| Badge "Day 100" | criado no Creator Hub | — | DEC-070, DEC-084 |

> **DEC-146 / DEC-147 (2026-10-10), nota do secretário — a resolver pelo architect:** o jogador **não usa o avatar do Roblox**; joga com o animal da HotDog Crew (corpo base R6 custom + peças do animal + uniforme), e **animal = classe** (`CLS-###`). Pontos: personagem por **StarterCharacter custom** ou montagem no `CharacterService` (com T25 `CharacterAutoLoads = false`); **Humanoid R6**; nenhuma aparência do avatar aplicada (sem `HumanoidDescription` do jogador); animal escolhido no lobby e levado à run (classe já persistida, DEC-069); ragdoll T22, Tool (`RightGripAttachment`), maca (DEC-143) e animações no rig custom; cutscene "avatares visíveis" → personagens da crew. NPCs clientes seguem R6 de plataforma (T11). Técnica nova vai à lista da `Q-130` como Provisória. Medidas do corpo: `Q-144`.

## 2. Mapa de features

> Versão 4.0: a tabela atualizada (features novas `Light`, `Hide`, `Pedestrian`, `Anim`, `Audio`, `Vehicle`, `Thief`
> etc., e o que muda nas da onda 1) está no **§19.1**; prioridades e `Require` no **§19.2**.

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
| `Market` (N) | `MarketService` (prateleiras e vagas da bancada são âncoras `Interactable`, §18.4) | `MarketController` | prateleiras (pacotes), **bancada** (upgrades básicos à venda, com cooldown por linha após a compra, Q-203 + **1 vaga especial** sorteada por turno, DEC-106). O Food Trailer **não** passa aqui (DEC-107) |
| `Upgrade` (N) | `UpgradeService` (+ `Pieces.luau`) | — (v4.1, D-07: sem controller; a peça visível é alternada pelo servidor, T38, e o nível chega ao client pelo set `Upgrades`, lido no `MarketController`) | nível por upgrade, efeito, peça visível; **compra delegada pela bancada** |
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

> Versão 4.0: tabelas completas (com os Services da onda 1 como foram entregues) no **§19.2**. Mudou: sem ciclo de
> `Require` (o `RoundService` **não** requer o `VitalService`; é o contrário), `LightService` 618, `HideService` 575,
> `PedestrianService` 545; consumidor de sinal de Service de prioridade **menor** conecta no `OnStart`.

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
| 790 | `MonetizationService` → **`ShopService`** (TASK-160) | ProfileService, NetService | L+R | `ProcessReceipt` no `OnStart`; handlers registrados por outros no `OnInit` (prioridade menor) |
| 780 | `SessionService` | PlaceService, PlayerService, NetService | L+R | MemoryStore, TeleportService |
| 760 | `RunStateService` | PlaceService, SessionService, PlayerService, ProfileService, NetService | R | roster, membros, registro de snapshot |
| 750 | `RoundService` | PlaceService, NetService, RunStateService, InteractionService (v4.1, A5: **sem** `VitalService`; o Vital entra por probe, §19.2, T42) | R | sinais de fase criados no `Setup` |
| 740 | `EconomyService` | RunStateService, RoundService, NetService | R | |
| 730 | `InteractionService` | PlayerService, RunStateService, NetService | R | |
| 720 | `ItemService` | PlayerService, RunStateService, InteractionService | R | stash, item derrubado |
| 715 | `CharacterService` | PlayerService, RunStateService, ItemService | R | spawn, desmaio (animação), ragdoll (só atropelamento), colisão |
| 700 | `VitalService` | PlayerService, RunStateService, RoundService, CharacterService, NetService | R | sanidade + vida |
| 690 | `ClassService` | ProfileService, PlaceService, NetService | L+R | |
| 680 | `PartyService` | PlaceService, SessionService, ProfileService, NetService | L | |
| 670 | `CodesService` (TASK-161) | ProfileService, NetService | L+R | resgate de códigos; tabela só no servidor |
| 650 | `KitchenService` | InteractionService, ItemService, EconomyService, ClassService | R | |
| 630 | `UpgradeService` | EconomyService, RunStateService | R | sem prompt próprio (DEC-101) |
| 620 | `VehicleService` | InteractionService, EconomyService, UpgradeService, RunStateService | R | compra do trailer pelo prompt no próprio trailer (DEC-107) |
| 615 | `MarketService` | InteractionService, ItemService, EconomyService, UpgradeService, VehicleService, RoundService, RunStateService | R | prateleiras + bancada; `VehicleService` só para saber se o trailer já foi comprado (Trailer Lights e Revive Kit, DEC-106, DEC-129) |
| 610 | `NpcService` | TrafficService (reserva/liberação de faixa em jogo, DEC-133) | R | |
| 600 | `TrafficService` | RoundService, CharacterService, ItemService, RunStateService, NetService | R | |
| 590 | `CustomerService` | NpcService, KitchenService, EconomyService, RoundService, InteractionService | R | |
| 580 | `ThiefService` | NpcService, EconomyService, RoundService | R | |
| 570 | `AnomalyService` | NpcService, RoundService, VitalService, InteractionService, CustomerService | R | |
| 568 | `SeatingService` (TASK-145, §19.28) | PlaceService, NetService, RunStateService, RoundService, EconomyService, InteractionService, UpgradeService, NpcService, CustomerService, AnomalyService | R | mesas do Pad, sentar, limpar (FEAT-037) |
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
| 680 | `ItemController`, `KitchenController`, `CustomerController`, `NpcController`, `MarketController`, `TrafficController` | v4.1 (D-07): sem `UpgradeController` |
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
| `ShiftStarted(info)` / `ShiftEnded(info)` | RoundService | início/fim de turno | Economy, Reward, Vital, Market (nova oferta), RunState (snapshot) |
| `Reported(info, report)` | EconomyService | `ShiftReport` montado e enviado (dentro do `Deposit`, no `ShiftEnded`) | quem precisa do relatório pronto. v4.1 (D-01): o relatório **não** viaja no `ShiftEnded`; campos de outras features entram antes do envio por `AddReportStep` (T48) |
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

> **Descartado (DEC-314, 2026-10-20):** a ambulância e os médicos não serão feitos; o corpo fica no chão até o reviver ou o fim da noite (`Revive.BodyFallback`). Texto abaixo sobre ambulância é histórico.

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

> **2026-10-11 (TASK-160, Provisório):** implementado como **`ShopService`** (`src/Shop/server/ShopService.luau`,
> prioridade 790, L+R; Require ProfileService, NetService), com pacotes de gemas e classe por Robux de
> `Content.Shop`. `RegisterProduct(productId, nome, handler)`; detalhes em `data.md` §1.4/§1.7. Códigos:
> `CodesService` (`src/Codes/server/CodesService/`, prioridade 670, L+R). Rede: `network.md` §15.

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

Numeração local (T#). **T1 e T3–T31 Aprovadas pela DEC-208** (em bloco, como estavam; T2 e T35 fora). T32 em diante:
decididas pelo architect por **delegação da DEC-208** (técnica que não muda regra de jogo); técnica que mude regra volta
ao usuário. T42–T58 (versão 4.0) estão no §19.25. A coluna "Histórico" diz de que versão a proposta vem.

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
| `VehicleCover` | lona AST-043 do carrinho (DEC-199) | `VehicleService` (visibilidade, T38) | 2 (v4.0) |
| `AnomalyAnchor` | âncora de anomalia que não é ponto de chão (janelas `WV-1..3`; atributo `AnchorId`) | `AnomalyController` | 3 (v4.0) |
| `PartyPlatform` | plataforma de party no lobby (atributo `Party`, DEC-179) | `PartyService`, `PartyController` | 4 (v4.0) |

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

**Mart v2 "Gear Stand" (TASK-135/139/140/141, Provisório; MAP-01 §18.4; `Content.Mart`, `content-data.md` §3.22).**
As âncoras de compra **não mudam**: `Interactable` + `PromptAction` (`bench_buy_upgrade` / `bench_buy_item`) +
`BenchSlot` (`Prompt_Buy_<Slot>`). Peças novas, todas **opcionais** para o código (o client tem fallback e avisa 1 vez;
`MapIndex.KioskNotes` lista o que falta e o `PlaceService` só dá `warn`, nunca erro):

| Peça | Tag / nome | Atributos | Quem lê |
|---|---|---|---|
| Pedestal | `Model` (ou `BasePart`) com tag `GearPedestal` | `Slot` = `B1`..`B5` / `S1` | `MarketController` (mini, placa, anel), `OpalController` (procura `Att_Opal` nos ancestrais) |
| Centro da mini | `Slot_<Slot>` (`Attachment`/`Part`) dentro do pedestal ou do dono da âncora; sem ele: topo do pedestal + `Mini.Lift` | — | `Minis.luau` |
| Placa de preço | `Price_Anchor_<Slot>` ou `Price_Anchor` dentro do pedestal; senão `Price_Anchor_<Slot>` no dono da âncora; senão embaixo da âncora do prompt | — | `MarketController` (`BenchCard` com `Plate = true`, pendurado **abaixo** do encaixe) |
| Anel de luz | `BasePart`s com nome começando em `Ring` dentro do pedestal | — | aceso (material/cor do autor) só "à venda"; apagado em MAX, Trailer only, vazio |
| Porta de enrolar | `Model` com tag `GearShutter`, **montada fechada** | `Slot` = `L` / `C` / `R` | `Kiosk.luau` |
| Ripas | `BasePart`s `Slat_*` (sobem e somem dentro do rolo) **ou** `Door_Panel` (painel com `Texture`, encolhe por baixo) | — | `Kiosk.luau` |
| Rolo | `BasePart` `Roll` ou `Door_Drum` (gira no eixo mais longo) | — | `Kiosk.luau` |
| Balcão da Opal | `Att_Opal` (`Attachment`/`Part`, frente = `LookVector`) dentro de um `Model` ancestral de um `GearPedestal`; senão `MapPoint` `OP-1` | — | `OpalController` |

Pedestal e porta precisam ser `ModelStreamingMode = Persistent` (como o resto do Mart). A porta é derivada da fase
(`Content.Mart.KioskClosedPhases`) nos dois lados; o servidor recusa compra de bancada com ela fechada (`Validate` e
`Run`), prateleiras nunca fecham.

**Âncoras de runtime** (mesmo contrato, criadas pelo dono): cliente NPC = `Attachment` `Prompt_Customer` no
`HumanoidRootPart` do rig do pool, no peito à frente do torso (offset (0; 0,5; −0,6), TASK-474: nunca sobre o rosto) (criado uma vez por rig pelo `NpcService`; `PromptAction` trocado pelo
`CustomerService`: `take_order` → `serve`; "Refuse" numa segunda âncora `Prompt_Refuse`, 1,5 abaixo); item derrubado =
a própria Tool no `Workspace` com `pick_up_item` (`network.md` §7).

**Onda 2 (mesmo padrão, sem detalhar agora):** trailer (`Vehicle = "trailer"`, estações iguais às do carrinho com
`Rail_8`; `Prompt_Brew`/`Prompt_Restock` da cafeteira; `Prompt_Switch`; `Prompt_Shutter` → `shutter_toggle` (DEC-221; `Hide_1..4` saem); `Prompt_Buy` no
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

## 19. Contratos das ondas 2–4 (pós onda 1)

Status da seção: **Provisória** (DEC-193). Base: código entregue na onda 1 (`src/`, commit `e7ee154`; o que cada Service
expõe hoje está citado em §19.3), `features.md` FEAT-001..036, DEC até DEC-215. Rede: `network.md` v5 §13. Dados:
`data.md` v5. Tabelas: `content-data.md` v5. Técnicas novas T42–T58 (§19.25): decididas pelo architect por delegação
da DEC-208 (nenhuma muda regra de jogo). Onde §2–§13 divergem, vale esta seção.

### 19.0 Regras novas

1. **Sem ciclo de `Require`** (T42). O periférico requer o central (Round, RunState, Economy, Interaction, Item,
   Character, Vital, Upgrade). Quando o central precisa de algo do periférico, o periférico injeta **probe ou registro**
   (precedentes: `RoundService:SetCounterProbe`, `RunStateService:RegisterSnapshot`, `InteractionService:RegisterAction`).
   Probe = função sem yield; erro vira `warn` + valor padrão.
2. **Sinal para "aconteceu", método para "faça"** (§4 regra 5). Sinal nasce no `Setup()` chamado no `OnInit`. Quem
   consome sinal de Service de prioridade **menor** conecta no `OnStart` (o `Setup` dele ainda não rodou no seu `OnInit`).
3. **Descoberta de módulos** (padrão T37) onde o conteúdo cresce em paralelo: `KitchenService/Stations/*`,
   `AnomalyService/Anomalies/*`, `AnomalyController/Effects/*`, `HallucinationController/Effects/*`,
   `DevService/Commands/*`. Task nova acrescenta arquivo; nunca edita o `init`.
4. **Fase sem dono pula** (T42): fase com `SkipWithoutProbe = true` (Intro, Call, Finale) é pulada se ninguém
   registrou probe para ela. Cada onda roda sem a seguinte.
5. **Ator só de client** (sem Humanoid no servidor) quando o servidor só precisa de tempo e posição lógica: carros
   (T21), ambulância e médicos (T23), passantes (T46), Walker e long car (§19.13), Walt e Raincoat Lady da cutscene.
   Não contam no teto de 12 (DEC-045 mede Humanoid de servidor).
6. Toda fase, número e lista nova é **tabela** (`content-data.md` v5). Código não tem número de design.

### 19.1 Mapa de features (E = existe e muda; N = nova)

| Feature | Server | Client | Shared | Onda | FEAT / DEC |
|---|---|---|---|---|---|
| `Round` (E) | `RoundService/` (`init`, `Flow`) — vira pasta | `RoundController` (+ `Night`, `Attempt`, `NightWindow`) | — | 2 | 002, 003, 017, 026 |
| `Run` (E) | `RunStateService/` (+ `SetLifeState`, `SetStash`, `SpendChance`, `SetEndless`, `ResetDev`) | — | — | 2 | 002 |
| `Vehicle` (N) | `VehicleService/` | `VehicleController` (placa de venda, fade, lona) | — | 2 | 016, 017; DEC-107, 184, 199 |
| `Light` (N) | `LightService/` | `LightController` (lâmpadas, postes, Hush visual) | `Zones.luau` | 2 | 020; DEC-189, 196 |
| `Vital` (E, reescrito) | `VitalService/` (`init`, `Sanity`, `Life`); **componente `Vital` sai** | `VitalController` (reescrito) | — | 2 (+4) | 019, 025, 034; DEC-166–169 |
| `Character` (E) | `CharacterService/` (+ `Faint`, `RemoveBody`, `Freeze`, `SetLookPack`, `SpawnPointFor`; `Ragdoll.luau` na 3) | `CharacterController` (N: controles travados, ragdoll previsto) | — | 2/3 | 025, 033, 034 |
| `Kitchen` (E) | `Stations/CoffeeMachine.luau` (N); init reage à troca de veículo | `KitchenController/Coffee.luau` | — | 2 | 021 |
| `Item` (E) | `ItemService/` + `Stash.luau`, `Drops.luau`, `Uses.luau` | `ItemController` (N: item no chão, splat) | — | 2 | 021, 036 |
| `Boss` (N) | `BossService/` | `BossController` (toque, legenda) | — | 2 | 018; DEC-124, 194 |
| `Thief` (N) | `ThiefService/` | `ThiefController` (barra sobre a gaveta) | — | 2 | 013; DEC-050, 182 |
| `Reward` (N) | `RewardService/` | — (toasts por `Notice`) | — | 2 | 017, 029, 031 |
| `Anim` (N) | — | `AnimController/` | — | 2 | — (rig IK do usuário) |
| `Audio` (N) | — | `AudioController/` | — | 2 | — |
| `Camera` (E) | — | `CameraController` (+ `Spectate`, `Fixed`, `Cutscene`; `Hidden` sai, DEC-221) | — | 2/3 | 004, 025 |
| `Hud` (E) | — | `HudController` (+ sanidade e retrato, Night k, contador 10 s, spectate, fim de run) | — | 2 | 032 |
| `Customer` (E) | + noite, `Acted`, `AddServeRule`, `SpawnActor` (3) | `CustomerController` (+ `Variant`) | — | 2/3 | 009, 011, 022 |
| `Economy` (E) | + `AddReportStep`, `Steal`, `Selling` | — | — | 2 | 012, 014 |
| `Interaction` (E) | + `AddGate`, `Performed` | — | — | 2 | 005 |
| `Npc` (E) | + `Role` (ladrão, ator), `SetTension`, reserva de faixa | — | — | 2/3 | 009 |
| `Anomaly` (N) | `AnomalyService/` (`init`, `Scheduler`, `Vision`, `Anomalies/*`, `Rules/*`) | `AnomalyController/` (`init`, `Effects/*`) | — | 3 | 022, 023, 024 |
| ~~`Hide` (N)~~ | **sai (DEC-221)**: janela do trailer no `VehicleService` (§19.14); ponto seguro no `AnomalyService` | aba no `VehicleController` | — | 3 | 023; DEC-221 |
| `Hallucination` (N) | — | `HallucinationController/` (`Effects/*`) | — | 3 | 019; DEC-038, 173 |
| `Cutscene` (N) | `CutsceneService/` | `CutsceneController/` | — | 3 | 004, 027; DEC-194, 205 |
| `Traffic` (N) | `TrafficService/` | `TrafficController` | `Motion.luau` | 3 | 033 (§8) |
| `Pedestrian` (N) | `PedestrianService/` | `PedestrianController` | — | 3 | DEC-183, `Q-162` |
| `Market` (E) | + vaga S1 (set `Bench`) | + S1 | — | 4 | 035 |
| `Ambulance` (N) | `AmbulanceService/` | `AmbulanceController/` | — | 4 | 034 (§6.3) |
| `Revive` (N) | `ReviveService/` | `ReviveController` | — | 4 | 034 (§6.4) |
| `Monetization` (N) | `MonetizationService` | — | — | 4 | DEC-092 (§10) |
| `Session` (N) | `SessionService/` | `SessionController` | — | 4 | 030 (§5) |
| `Party` (N) | `PartyService/` | `PartyController` | — | 4 | 001; DEC-179 |
| `Class` (E) | `Select` no lobby | tela "Crew" no lobby | — | 4 | 001, 028 |
| `Dev` (E) | `Commands/<Feature>.luau` (um por task) | — | — | 2–4 | — |

Nomes proibidos de feature seguem (§18.11): `Types`, `tablejs`, `Content`, `Libs`, `Modux`.

### 19.2 Prioridades e `Require`

Servidor ("=" = igual à onda 1):

| Prio | Service | Require | Place | Onda |
|---|---|---|---|---|
| 1000 | `NetService` | = | L+R | — |
| 950 | `PlaceService` | = | L+R | — |
| 900 | `PlayerService` | = | L+R | — |
| 800 | `ProfileService` | = | L+R | — |
| 790 | `MonetizationService` | ProfileService, PlaceService | L+R | 4 |
| 780 | `SessionService` | PlaceService, PlayerService, NetService, ProfileService | L+R | 4 |
| 760 | `RunStateService` | = + SessionService (onda 4) | R | E |
| 750 | `RoundService` | = (PlaceService, NetService, RunStateService, InteractionService) | R | E |
| 740 | `EconomyService` | = | R | E |
| 730 | `InteractionService` | = | R | E |
| 720 | `ItemService` | = + VehicleService | R | E |
| 715 | `CharacterService` | = + RoundService | R | E |
| 700 | `VitalService` | PlaceService, PlayerService, NetService, RunStateService, RoundService, CharacterService, ItemService, InteractionService, ClassService, LightService | R | 2 |
| 690 | `ClassService` | = (Select no lobby na onda 4) | L+R | E |
| 680 | `PartyService` | PlaceService, PlayerService, SessionService, ProfileService, NetService | L | 4 |
| 650 | `KitchenService` | = + VehicleService | R | E |
| 630 | `UpgradeService` | = | R | E |
| 620 | `VehicleService` | PlaceService, NetService, RunStateService, RoundService, InteractionService, EconomyService, UpgradeService | R | 2 |
| 618 | `LightService` | PlaceService, NetService, RoundService, InteractionService, UpgradeService, VehicleService | R | 2 |
| 615 | `MarketService` | = + VehicleService (onda 4) | R | E |
| 610 | `NpcService` | = + TrafficService (onda 3) | R | E |
| 600 | `TrafficService` | PlaceService, NetService, RoundService, RunStateService, CharacterService, ItemService, VitalService | R | 3 |
| 590 | `CustomerService` | = | R | E |
| 580 | `ThiefService` | PlaceService, NetService, RoundService, RunStateService, NpcService, EconomyService, UpgradeService | R | 2 |
| ~~575~~ | ~~`HideService`~~ | sai (DEC-221) | — | — |
| 570 | `AnomalyService` | PlaceService, NetService, RoundService, RunStateService, VitalService, LightService, VehicleService (era HideService, DEC-221), CustomerService, NpcService, KitchenService, ItemService, EconomyService, TrafficService | R | 3 |
| 568 | `SeatingService` | PlaceService, NetService, RunStateService, RoundService, EconomyService, InteractionService, UpgradeService, NpcService, CustomerService, AnomalyService | R | 3 (§19.28) |
| 565 | `AmbulanceService` | PlaceService, NetService, RoundService, VitalService, CharacterService, TrafficService, AnomalyService | R | 4 |
| 560 | `BossService` | PlaceService, NetService, RoundService, RunStateService, InteractionService, VehicleService, ThiefService | R | 2 |
| 555 | `ReviveService` | PlaceService, NetService, VitalService, AmbulanceService, MonetizationService, ItemService, RunStateService, EconomyService | L+R (handler) / R | 4 |
| 550 | `RewardService` | PlaceService, ProfileService, RoundService, RunStateService, EconomyService | R (+ L: retry de badge) | 2 |
| 545 | `PedestrianService` | PlaceService, NetService, RoundService, TrafficService, AnomalyService, CustomerService (TASK-163: registra `CustomerService:SetAdopter`, T42; o Customer nunca requer o Pedestrian) | R | 3 |
| 540 | `CutsceneService` | PlaceService, NetService, RoundService, RunStateService, CharacterService | R | 3 |
| 100 | `DevService` | = | R (dev) | E |

Conexões que exigem `OnStart` (§19.0 regra 2): `KitchenService`, `ItemService` e `LightService` →
`VehicleService.Swapped`. `RoundService` não escuta Service abaixo dele: só lê probes.

Client:

| Prio | Controller | Require (além do que já tem) | Onda |
|---|---|---|---|
| 1000 | `NetController` | — | — |
| 950 | `PlaceController` | — | — |
| 900 | `InputController` | — | — |
| 800 | `ProfileController`, `RoundController`, `VitalController` (reescrito) | — | 2 |
| 795 | `LightController` | RoundController | 2 |
| 790 | `EconomyController` | — | — |
| 780 | `SessionController` (L) | — | 4 |
| 760 | `VehicleController` | RoundController | 2 |
| 720 | `CharacterController` | InputController, VitalController | 2 |
| 690 | `CameraController` | VitalController | E |
| 685 | `AnimController` | — | 2 |
| 680 | `KitchenController`, `MarketController`, `RigController`, `ItemController`, `ThiefController`, `TrafficController`, `PedestrianController` | `RigController`/`AnimController` onde montam rig local | 2/3 |
| 670 | `CustomerController`, `AmbulanceController`, `ReviveController` | — | E/4 |
| 660 | `AnomalyController`, `BossController`, `CutsceneController` (`HideController` sai, DEC-221) | RoundController, CameraController | 2/3 |
| 650 | `PartyController` (L) | — | 4 |
| 640 | `AudioController` | RoundController | 2 |
| 620 | `PromptController` | = | E |
| 600 | `HallucinationController`, `OpalController` | VitalController | 3/E |
| 500 | `HudController` | + VitalController, BossController | E |
| 450 | `ClassController` | = | E |

Quem toca som ou animação chama `AudioController`/`AnimController` em tempo de jogo (injeção, sem ordem).

### 19.3 Pontos de extensão nos Services da onda 1

O que existe hoje (código) e o que muda. "Ajuste A#" = task pequena no início da onda 2 (§19.26).

| Service | Hoje (onda 1) | Muda para | Quem |
|---|---|---|---|
| `RoundService` | arquivo único; `Phase` = Prep/Open/Closing/Summary; `NEXT` fixo; `Info()` com `Night = 0`; `Record().Vehicle = RunParams.StartVehicle`; `RestoreShift(data)` ignora `mode`; sinais `PhaseChanged`, `ShiftStarted(info)`, `ShiftEnded(info)`; `SetCounterProbe` | pasta com `Flow.luau`; FSM completa (§19.4). **`ShiftEnded(info)` fica com essa assinatura**: o relatório sai por `EconomyService.Reported(info, report)`, não por `ShiftEnded(info, report)` como dizia o §4.1. + `BeforeShift`, `NightResolved`, `RunEnded`, `LoseNight`, `SetPhaseProbe`, `SetVehicleProbe`, `SetVerdict`, `SetWipe`, `IsSelling`, `NightEndsAt`, `AddRunReportStep` (v4.1, T59) | W2 Round |
| `EconomyService` | `Deposit` monta e dispara `ShiftReport` com `Gems = 0`, `AfkLocked = false`, `LastChanceUsed = false`; `SHOP_PHASES` fixo; sinal `Reported(info, report)` | `AddReportStep(name, fn(info, report))` (na ordem de registro, **antes** do envio; T48); `IsShopOpen()` = `Content.Shift.ByKey[phase].Selling`; `Steal(amount): number` (ledger `Stolen`); `DrawerKind` + `"Catch"` | ajuste A1 |
| `InteractionService` | gate de taxa + personagem vivo | `AddGate(name, fn(player, action, anchor) -> (boolean, string?))`: todas passam ou recusa com o motivo (Down, Spectator, janela fechada nas ações de balcão, atropelado, cutscene); sinal `Performed(player, action, anchor, id)` depois do `Run` (T49) | ajuste A2 |
| `RunStateService` | `Member` com `Sanity`, `CoffeeReadyAt`, `SeenAnomalies`, `RevivesTonight` sem uso; snapshot `M[uid].T` (stash); sem API de vida/chances | + `SetLifeState(userId, state)` (só `VitalService`), `SetStash(userId, entries)` (só `ItemService`), `SpendChance(): boolean`, `SetEndless(on)`, `ResetDev()` (volta à 1ª captura em modo `Resume`, `Chances = RunParams.Chances`); sinal `LifeChanged(userId, old, new)`; `M` perde `T` (T50); os 4 campos sem uso saem do `Member` (cada dono guarda por `UserId`) | ajuste A3 |
| `ItemService` | sem stash (quem sai perde as Tools); `CurrentVehicle()` = `StartVehicle`; `Pickup.luau` (pacote grátis) | `Stash/Unstash`, snapshot `T`, `Drops.luau` (FEAT-036), `RegisterUse(item, handler)` (T51), ação `give_coffee`; `CurrentVehicle()` = `VehicleService:Current()` | W2 Item |
| `CharacterService` | spawn em `PS-<seat>`; `LookPack = "Day"` fixo; Animate R6 padrão do `LoadCharacter` | `SpawnPointFor(player, info)` (PS / PS-N / REV); `SetLookPack(player, pack)`; não spawna `Down`/`Spectator`/`Away`; `Faint`, `RemoveBody`, `Freeze(player, reason, on)`; âncora de runtime `Prompt_Give` no HRP; ids de locomoção de `Content.Animations` no `Animate` (§19.20); `Knock` + juntas de ragdoll (onda 3) | W2 Vital (+W3 Traffic) |
| `KitchenService` | veículo por `UpgradeService:GetVehicle()`; estação de veículo não atual já recusa (`IsCurrent`) | `VehicleService.Swapped` (no `OnStart`) → `Capacity`/`Blocked`/prompts; módulo `CoffeeMachine.luau`; `discard` também na lixeira de rua (v4.1, T60: âncora fora de `Station`, dentro de `StreetBin`; TASK-057); onda 3: `Alter(kind, slot)`, campo `Altered` no set, sinal `Discarded(player, item, altered)`, `StationApi.Context.Emit` | W2 Vehicle, W2 Coffee, W3 Anomaly |
| `UpgradeService` | `Vehicle` atom + `SetVehicle(v)` prontos (DEC-184) | sem mudança; chamado pelo `VehicleService` | — |
| `CustomerService` | spawn só em `Open`; `Party` lido no `Open`; sinais `Joined`, `Fronted`, `Left`, `Removed` | spawn em fase `Selling` (Open, Night) com `Flow` de noite; sinal `Acted(id, action, player, result)`; `AddServeRule(fn(customer, tool, player) -> SaleResult?)`; `SpawnActor(spec)` (onda 3) | ajuste A4 / W3 |
| `NpcService` | só clientes; `SpawnRequest` sem papel | `SpawnRequest.Role = "Customer" \| "Thief" \| "Actor"` (+ `Variant`); `raccoon`/`thief` só com `Role = "Thief"`; `SetTension(on)` (pack Night de clima, `Q-159`); reserva de faixa no `Walker` (onda 3, §8.1) | W2 Thief, W3 |
| `MarketService` | B1–B5 | S1 (onda 4) | W4 |
| `VitalService` + `Vital` | exemplo Health/Armor/Stamina | reescrito (§19.7); componente `Vital`, set legado `Vitals` e packet legado `Round` saem | W2 Vital |
| `RoundController` | sources `Day`, `Phase`, `IsNight`, `Vehicle`, `ClockText` | + `Night`, `Attempt`, `NightWindow`; `ClockText` parado na `Call` (ClockFrom = ClockTo) | W2 Round |
| `CameraController` | `FirstPerson`/`External`, `SetArmsVisible` | + `Spectate(userId)`, `Fixed(pointId)`, `Cutscene`; braços visíveis à noite com o pack da faixa (DEC-167) | W2 / W3 |
| `RigController` | camada local Night (DEC-168/169) | + atributo `FixedFace` (médicos `Exhausted` sempre, DEC-213), `Variant` (onda 3), rigs **locais** tagueados no client (passantes) | W3/W4 |
| `HudController` | dia | + sanidade e retrato da faixa, "Night k", contador da janela de 10 s, spectate, tela de fim de run | W2 |
| `DevService` | `Commands/*` | + um arquivo por task nova | cada task |
| `src/Libs/Net/init.luau` | 14 entradas + legado | `network.md` v5 §13 (uma task de contrato por onda) | W2-0 / W3-0 / W4-0 |

### 19.4 Run completa (`RoundService`; FEAT-002, 003, 017, 026)

Arquivos: `src/Round/server/RoundService/init.luau` (Service, atoms, set `Shift`, tick 10 Hz) e `Flow.luau` (puro:
próxima fase e próximo turno; testável em lune).

**Fases** (`Content.Shift`; durações e relógio na tabela, com override de noite):

| Fase | Turno | Relógio | Duração (s) | Termina | Próxima |
|---|---|---|---|---|---|
| `Intro` | 1º turno de run nova (só o Day 1) | 7:00 AM parado | cap 70 (Provisório 2026-10-11, era 50) | probe `Intro` (Cutscene) ou cap | `Prep` |
| `Call` | noite | 7:00 PM parado (FEAT-018: relógio não corre na ligação) | cap 60 | probe `Call` (Boss: fila vazia) ou cap | `Prep` |
| `Prep` | dia / noite | 7→8 AM / 7→8 PM | 60 / 90 | "Open Shop" ou cap | `Open` / `Night` |
| `Open` | dia | 8 AM→6 PM | 360 | cap | `Closing` |
| `Night` | noite | 8 PM→6 AM | `Nights[k].Duration` (540 s na N1 → 900 s na N10, +40 s por noite; era 1200 → 1800, Provisório 2026-10-12) | cap → `Verdict()`; antes, só `LoseNight` | `NightEnd` ou `NightLost` |
| `NightEnd` | noite | 6:00 AM | 3 | cap | `Closing`; Night 10 → `Finale` |
| `Closing` | ambos | 6 PM / 6 AM | ≤ 30 | balcão vazio (probe existente) ou cap | `Summary` |
| `Summary` | ambos | parado | 15 / 20 | cap | fronteira |
| `NightLost` | noite | parado | 6 | cap | restaura `RepeatNight` ou `RunEnd` |
| `Finale` | Night 10 vencida | 6:00 AM | cap 150 | probe `Finale` (Cutscene) ou cap | `RunEnd` |
| `RunEnd` | fim | parado | 15 | cap | lobby (onda 4) / `ResetDev` |
| `Resume` | retomada | parado | 15 | probe `Resume` (roster conectado) ou cap | 1ª fase do turno |

Fase com `Selling = true` (Open, Night) é quando nasce cliente e a gaveta conta (Economy, Customer). As janelas da
noite (FEAT-003: Calma 8–9 PM, Turno 9 PM–5 AM, Últimos 5–6 AM) **não são fases**: `RoundService:NightWindow()` deriva
do relógio (`Content.Nights` registro `Windows`); usam Anomaly (agenda) e Traffic (densidade).

**Fronteira** (fim do `Summary`), ordem fixa:
1. `BeforeShift:Fire(prev)` — `VehicleService` aplica a troca pendente (§19.5).
2. `next = Flow.Next(prev, LAST_NIGHT, MAX_DAY, RunParams.NightsFromDay)` (**novo fluxo, pedido do dono 2026-10-12, Provisório,
   Q-207**): `prev.IsNight` → Day(D+1); dia com `prev.Day >= NightsFromDay (2)` e `prev.Night < LAST_NIGHT` → Night(N+1) **no mesmo Day**,
   qualquer veículo (o veículo não decide mais); senão Day(D+1). Sequência D1, D2, N1, D3, N2 … D11, N10, `Finale`.
   `Flow.NightsBefore(day)` e `Flow.DayOfNight(k)` (= k + 1) servem os comandos de dev. Antes: noite só com `HasNight` (trailer).
3. `RunStateService:SetEndless(false)`: o modo dia infinito (DEC-084) acabou; `RunParams.EndlessFromDay` / `EndlessRequiresNoTrailer`
   ficam sem uso e `Vehicles.cart.HasNight = true` (a API `RoundService:VehicleHasNight()` continua só por compatibilidade de tipos).
4. `StartShift(next, capture = true)`: atoms em `batch` → `ShiftStarted(info)` → `PhaseChanged(first)` → `Capture()`.
   Primeira fase: dia → `Prep` (`Intro` antes, só no 1º turno de run nova); noite → `Call`.

**Noite perdida e fim da run:**
- `LoseNight(reason: "wipe" | "critical")`: aceito em `Call`, `Prep`, `Night`; idempotente. Entra em `NightLost`;
  `NightResolved(info, "Lost", reason)`.
- Fim do `NightLost`: `RunStateService:SpendChance()` → `true`: `RunStateService:Restore("RepeatNight")` (o `Sh`
  restaura com `Attempt = A + 1` e chama `StartShift(capture = true)`); `false`: `RunEnd` + `RunEnded("Failed")`.
- Fim da `Night` (cap): `Verdict()` (probe do Vital: algum presente `Active`/`Reviving`) → `true`: `NightEnd` +
  `NightResolved(info, "Won")`; `false`: `LoseNight("wipe")` (FEAT-026: vitória exige ≥ 1 de pé às 6:00).
- Night 10 vencida: `NightEnd` → `Finale` → `RunEnd` + `RunEnded("Success")` (sem Closing/Summary, FEAT-027).
- Fim do `RunEnd`: ondas 2–3 → `RunStateService:ResetDev()` (volta ao Day 1 da mesma run, sem lobby); onda 4 →
  `SessionService:EndRun(result)` (remove registros, teleporta ao lobby).

**API (servidor):**

```lua
-- leitura
RoundService:GetPhase(): Phase                     -- chave de Content.Shift
RoundService:GetDay(): number ; RoundService:GetNight(): number ; RoundService:IsNight(): boolean
RoundService:Info(): ShiftInfo                     -- { Day, Night, IsNight, Attempt } (tipo da onda 1, inalterado)
RoundService:Minutes(): number ; RoundService:NightWindow(): ("Calm" | "Shift" | "Last")?
RoundService:IsSelling(): boolean                  -- Content.Shift.ByKey[phase].Selling
RoundService:NightEndsAt(): number                 -- instante de servidor das 6:00 AM desta noite (prazo do Down, DEC-115)
-- hooks (registrados no OnInit/OnStart do dono)
RoundService:SetPhaseProbe(phase: Phase, probe: () -> boolean)  -- "pode terminar agora"; SetCounterProbe = alias de "Closing"
RoundService:SetVehicleProbe(probe: () -> string)               -- VehicleService
RoundService:SetVerdict(probe: () -> boolean)                   -- VitalService
RoundService:SetWipe(endsAt: number, frozen: boolean)           -- VitalService (Shift.WipeEndsAt/WipeFrozen)
RoundService:LoseNight(reason: "wipe" | "critical")             -- VitalService, AnomalyService
RoundService:AddRunReportStep(name: string, step: (player: Player, report: RunReport) -> ())  -- v4.1, T59: RewardService (Gems)
-- sinais (Setup)
PhaseChanged(phase, day, night) ; ShiftStarted(info) ; ShiftEnded(info)          -- existentes, mesma assinatura
BeforeShift(prev: ShiftInfo)
NightResolved(info, result: "Won" | "Lost", reason: string?)
RunEnded(result: "Success" | "Failed")
```

`ShiftEnded(info)` continua no início do `Summary` (dia e noite). Snapshot `Sh` = `{ D, N, Ni, A }` (sem mudança);
restore `RepeatNight` → `A + 1` e captura nova; `Resume` → fase `Resume` e captura nova no início do turno.
**Sequência de turnos (2026-10-12):** `Day = k + 1` para a noite *k* (`RunParams.NightsFromDay = 2`); o snapshot `Sh` aceita qualquer
`(D, N, Ni)` dessa sequência (`D` 1..10000, `N` 0..10): nenhuma mudança de formato, e o `Resume`/`RepeatNight` reentram na noite no veículo
que estiver em uso (`Veh` restaura o veículo antes). `Shift.Night` (Lync `int(0, 10)`) e `Shift.Day` continuam como estão; nenhum campo de rede novo.
`Shift.Vehicle` vem do `VehicleProbe` (`RunParams.StartVehicle` sem probe); `Shift.Chances` de
`RunStateService.Chances()` (não vai ao HUD, DEC-053). Comandos de dev (`Commands/Round.luau`, existente):
+ `night <k>` (a noite k no **seu** dia, Day k + 1; `day <n>` deriva as noites jogadas do dia: Day 3 vem depois da Night 1), `lose wipe|critical`, `win`.

### 19.5 Trailer e troca de veículo (`VehicleService`; FEAT-016, 017; DEC-047, 086, 107, 121, 184, 199)

| Item | Contrato |
|---|---|
| Estado | `Current` (atom, chave de `Vehicles`), `Bought` (bool), `Pending` (troca no fim do turno); **`Shutter`** por veículo (janela de serviço, DEC-221, §19.14) |
| Posições (T36) | os dois veículos vivem no `Workspace` e mudam por `PivotTo`. Antes: carrinho em `CART`, trailer em `TRL-SALE`. Depois: trailer em `TRL` (Pad, DEC-086), carrinho em `TRL-SALE` com a lona (`VehicleCover`, AST-043, DEC-199) visível |
| Compra | âncora `Prompt_Buy` no trailer à venda → ação `buy_trailer` (hold 2). `PromptEnabled` = `Day ≥ Vehicles.trailer.BuyFromDay`, não comprado, fase de dia. `PromptText` = "Buy Trailer — $X", X = `TrailerBasePrice × PartyPriceMult[PriceParty]` (DEC-121). `Run`: `EconomyService:Spend(X, player)` → `Bought = true`, `Pending = true`, `Notice trailer_bought` (todos) |
| Troca | `RoundService.BeforeShift` com `Pending`: packet `Transition{ Kind = "VehicleSwap" }` (fade 1,5 s no client) → `PivotTo` → `UpgradeService:SetVehicle("trailer")` → sinal `Swapped(from, to)` → `Pending = false`. A ligação `call_trailer_bought` é do `BossService` (escuta `Swapped`) e toca na `Call` da Night 1 |
| Quem reage a `Swapped` | `KitchenService` (`Capacity`, `Blocked` do café, prompts T36; estoque passa inteiro, excesso → `Q-169`), `ItemService` (pacote grátis), `LightService` (zonas do trailer), `BossService` |
| Avisos (FEAT-017) | `ShiftEnded` do Day `TrailerDay` sem compra → `Notice trailer_available`; depois, a cada 3 dias → `trailer_waiting` (dados em `Vehicles.trailer.Reminder`) |
| Probe | `RoundService:SetVehicleProbe(function() return Current() end)` no `OnInit` |
| Snapshot | `Veh` = chave do veículo atual (data.md §3.3). Restore: posições + `UpgradeService:SetVehicle` + `Bought = (Veh ~= StartVehicle)` |
| API | `Current(): string`, `IsBought(): boolean`, `Price(): number`; sinais `Bought(player)`, `Swapped(from, to)`; janela (v4.2): `IsShutterClosed`, `IsInside`, `IsProtected`, `SetShutter`, sinal `ShutterChanged` (§19.14) |
| Client | `VehicleController`: placa "Available on Day 5" (`SIGN-T`), fade do `Transition`, aba da janela pelo atributo `Shutter` (§19.14), nada de estado próprio (lê `Shift.Vehicle`) |

**Lixeira de rua (v4.1, T60; DEC-200; TASK-057; Provisório).** Fica aqui porque a TASK-057 é a mesma que reage ao
`Swapped`. O verbo `discard` tem **um** dono, o `KitchenService` (`InteractionService:RegisterAction` recusa chave
repetida; feature nova para a lixeira seria segundo dono do mesmo verbo).

| Item | Contrato |
|---|---|
| Binding | `Model` AST-034 interativo com tag `StreetBin` (§19.22), âncora `Prompt_Discard` com `PromptAction = "discard"`; sem `Station`, sem `Vehicle` |
| Descoberta | `KitchenService` indexa `StreetBin` no `OnStart` (como as estações) e liga o prompt pelo padrão do `InteractionService:Track` |
| `Evaluate` | âncora sem `StationOf` e com ancestral `StreetBin` → ramo de rua: membro ativo, `Requires` da linha `discard` (`Held`, `Phase`, `Night`) e a mesma regra de mão do `Trash.luau` (função exportada do módulo, sem duplicar); **não** passa por `IsCurrent` (não é do veículo) nem por trava de estação |
| Efeito | igual ao BIN-C: `Consume` da Tool, sem reembolso, sem registro em `Stations`, nada no snapshot |
| O que aceita | `Q-166` a, recomendação Provisória do board: **só HotDog** (igual ao BIN-C na onda 1). Se o game-designer ampliar, muda só a regra de mão no `Trash.luau` |
| Onda 3 | o sinal `Discarded(player, item, altered)` sai igual nos dois lugares (+ campo `Where = "Vehicle" \| "Street"`); se descarte de item alterado na rua conta para a anomalia é regra do game-designer (`Q-166` e). A lixeira nunca vira âncora de anomalia sem DEC |
| Rede | nada novo: `Interact` já leva `discard`; texto "Throw Away" vem de `Content.Actions` |

### 19.6 Escuro e luz (`LightService`; FEAT-020; DEC-041, 055, 056, 189, 196)

| Item | Contrato |
|---|---|
| Binding | tag `LightZone` (`Part` volume, invisível, `CanCollide/CanQuery/CanTouch` falsos; atributos `ZoneId` = `LZ-1..5`, `Group` = chave de `Content.LightGroups`; `Shape` Block = caixa orientada, Ball = esfera). Tag `StreetLight` (poste; `PostId` = `JL-01..09`/`P-01`, `Group`, `Order` 1..10 na ordem do Hush). Interruptor = `Interactable` `Prompt_Switch` → `switch_light` |
| Grupos (`Content.LightGroups`) | `mart` (LZ-4, LZ-5: sempre), `trailer_interior` (LZ-1, LZ-2: interruptor, só com `Vehicle = trailer` atual), `trailer_lights` (LZ-3: interruptor + `trailer_lights` ≥ 1; raio = efeito `LightRadius`), `juniper_posts` (visual; volume só se o level-designer marcar, DEC-196 proíbe volume na rota Pad ↔ Mart) |
| Zona ativa | noite **e** grupo ligado **e** não apagado pelo Hush (`HushOff = true` no grupo). De dia nada é escuro |
| Interruptor | toque, cooldown 0,5 s (`LightGroups.trailer_interior.Cooldown`), estado da party; **liga sozinho no `ShiftStarted` de noite**; durante o Hush não tem efeito (FEAT-020) |
| API | `IsLit(position: Vector3): boolean` (puro sobre o cache, `Zones.luau` em `shared`); `IsSwitchOn(): boolean`; `SetSwitch(on, player?)`; `BeginHush(startedAt, holdUntil)` / `EndHush()` (só `AnomalyService`, ANM-010); sinal `SwitchChanged(on, player?)` (ANM-003 observa) |
| Rede | set `Lights` (id = `IndexOf` de `LightGroups`): `{ On, At }` (`network.md` §13.2). Postes do Hush: client apaga por `Order × Step` desde `At` |
| Snapshot | `Lt` = `{ S = switch }` (FEAT-020: entra no snapshot; na prática sempre ligado no início da noite) |
| Client | `LightController`: liga/desliga `SpotLight`/emissiva (T31), corte por distância, Hush poste a poste, flicker do Walker (via `Anomalies`, onda 3) |

### 19.7 Sanidade e estado de vida (`VitalService` reescrito; FEAT-019, 025, 034; DEC-056, 091–094, 115, 129, 166–169)

Arquivos: `VitalService/init.luau` (Service, set `Vitals`, packet `Sanity`), `Sanity.luau` (puro: faixas, regras de
variação), `Life.luau` (puro: transições §6.1). Estado por **`UserId`** (sobrevive a `Away`).

| Item | Contrato |
|---|---|
| Por jogador | `Sanity`, `Max`, `DarkSince`, `ProtectUntil`, `CoffeeReadyAt`, `RevivesTonight`, `Seen[anm]`, `State`, `StateEndsAt`, `KnockedUntil`, `Band` |
| Início da noite (`ShiftStarted` noturno) | `Sanity = Max = ClassService:GetModifier(p, "SanityStart"/"SanityMax", Sanity.Start)`; `RevivesTonight = 0`; `Seen = {}`; packet `Sanity` |
| Dia | sem sanidade: packet `Sanity{ Value = 0, Max = 0 }` (HUD esconde), `LookPack = "Day"` |
| Escuro (1 Hz) | `Active`, conectado, com personagem, fase noturna (`Call`, `Prep`, `Night`, `NightEnd`): `LightService:IsLit(HRP)` falso por > `Sanity.DarkDelay` → `−DarkPerSecond` por s; sem perda durante `ProtectUntil` |
| Faixa (DEC-167) | `Sanity.Bands`: ≥ 60 `Day`, 40–59 `Mid`, < 40 `Night`; de dia sempre `Day` → `CharacterService:SetLookPack(player, band)` (também no respawn) |
| 0 de sanidade | `RevivesTonight < Revive.MaxPerNight` → `Down`; senão `Spectator` (DEC-129). `Down`: `CharacterService:Faint`, `ItemService:Stash`, `StateEndsAt = RoundService:NightEndsAt()`, `LifeEvent{Down}`, `PickupHandler(userId, bodyPos)` |
| `PickupHandler` (T54) | padrão (ondas 2–3): `CharacterService:RemoveBody(player)` após `Revive.BodyFallback` s (fade). Onda 4: `AmbulanceService` troca por `SetPickupHandler(fn)` |
| 6:00 AM (`NightEnd`) | todo `Down` → `Spectator`; `ItemService:DropStash(userId, "DROP-T")` (pacotes e apito no balcão; HotDog/café somem, FEAT-025); `LifeEvent{Spectating}` |
| Janela de 10 s | nenhum presente `Active`/`Reviving` → `RoundService:SetWipe(now + Revive.WipeWindow, false)` + `LifeEvent{Wipe}`; esgotou → `RoundService:LoseNight("wipe")`; alguém volta `Active` → `SetWipe(0, false)` + `WipeCleared`. Ondas 2–3 sem reviver: a janela só fecha por atrasado/reconexão. Congelamento (DEC-118) na onda 4 |
| Veredito | `RoundService:SetVerdict(fn)` = algum presente `Active`/`Reviving` |
| Noite repetida | `RunStateService` põe todos `Active`; Vital reinicia a noite no `ShiftStarted`; `CharacterService` spawna em `REV-1..4` (DEC-122) |
| Gate | `InteractionService:AddGate("Vital", …)`: só `Active` interage |
| API | `GetSanity(player): (number, number)`; `AddSanity(player, delta, cause)`; `Penalize(player, cause)` (−`Sanity.RuleBroken`); `SeeAnomaly(player, key): boolean` (−5 uma vez por anomalia por noite; `SeeAnomalyLoss` da classe); `GetState(userId)`; `IsActive(player)`; `SetKnocked(player, untilT)` (Traffic); `SetPickupHandler(fn)`; `Revive(userId, source)` (onda 4, só `ReviveService`); sinais `MemberStateChanged(userId, old, new)`, `Wipe(started, endsAt)` |
| Uso do café | `ItemService:RegisterUse("coffee", …)` (§19.8) |
| Rede | set `Vitals` (id = `UserId`) e packet `Sanity` (só o dono; `network.md` §6.1, §13.1). Estado de vida também em `RunStateService` via `SetLifeState` (fonte do snapshot) |
| Client | `VitalController`: sources `Sanity`, `Max`, `Band`, `State[uid]`; `CameraController` spectate (colega `Active`, troca no botão de interagir; sem colega: `SPEC-P`/`SPEC-M`); `HudController` medidor + retrato do rosto da faixa, contador da janela |

### 19.8 Café (FEAT-021; DEC-055, 069, 125)

| Peça | Contrato |
|---|---|
| Estação | `KitchenService/Stations/CoffeeMachine.luau`, `Kinds = { "coffee_machine" }`, registro `Single` no set `Stations` (Empty → Working → Ready). Âncora `Prompt_Brew` → `brew_coffee` (hold 1, FEAT-021) |
| Preparo | `Empty` + `Stock.coffee ≥ 1` → `TakeStock` → `Working` (`Duration = ClassService:GetModifier(p, "CoffeeBrewTime", Stations.coffee_machine.Params.BrewTime)`) → `Ready`. Em `Ready` o mesmo prompt (`PromptText = "Take Coffee"`) dá a Tool `coffee` a quem toca, com atributo `Restore` = `CoffeeRestore` de quem preparou (25 / Barista 35) |
| Beber | `ItemService:RegisterUse("coffee", { Validate, Run })` registrado pelo **VitalService**: só à noite (Provisório, `Q-170`), `CoffeeReadyAt ≤ now`, `Sanity < Max` → anima 1,5 s (`drink`, owner) → `AddSanity(+Restore)`, `Consume`, `CoffeeReadyAt = now + Sanity.CoffeeCooldown` |
| Dar | âncora `Prompt_Give` no HRP de cada membro (criada pelo `CharacterService`); ação `give_coffee` (hold 0,5, FEAT-021) do **ItemService**: doador segura `coffee`, alvo `Active` sem café (`CategoryLimits.Coffee = 1`) → move a Tool. O client esconde a própria âncora |
| Estoque | `coffee` é ingrediente (`Stock`), repõe com `pack_coffee` (`restock` do núcleo); `Blocked` até o trailer |

### 19.9 Ligações do chefe (`BossService`; FEAT-018; DEC-077, 124, 194)

| Item | Contrato |
|---|---|
| Fila | prioridade de `BossCalls.Priority`; uma por vez; nenhuma em `Intro`/`Finale`/`NightLost`/`RunEnd` |
| Gatilhos | `PhaseChanged("Prep")` de dia → `call_day_<N>` (variante `_quentin` se `RunState.Counters.quentin_caught_day == N − 1`), dia infinito → pool `call_day_infinite`; `PhaseChanged("Call")` → `call_night_<N>` ou `call_night_short` (`Attempt > 0`); `VehicleService.Swapped` → `call_trailer_bought`; `NightResolved("Lost")` → `call_lost_critical` (se `critical`) + `call_lost_last_chance`/`call_run_over`; dicas `hint_<passo>` → `InteractionService.Performed` (1ª vez da ação na run, `BossCalls.Trigger.Action`) |
| Telefone | `Interactable` `Prompt_Answer` no carrinho e no trailer (DEC-124) → `answer_phone` (toque). Toca até alguém atender ou `BossCallRules.AutoAnswer` (15 s) |
| Ritmo | servidor só grava `StartedAt`; linha atual = `floor((now − StartedAt) / LineTime)` (2,5 s), igual para todos; sem pular, sem repetir |
| Probe | `RoundService:SetPhaseProbe("Call", fn)` = fila vazia e nada tocando |
| Rede | set `Call` (registro 1; `network.md` §13.3): quem reconecta ouve só as linhas restantes (T44) |
| Snapshot | `Bs` = chaves `Once` já tocadas (data.md §3.3) |
| Client | `BossController`: toque e luz do telefone, legenda "Walt: …" (2,5 s/linha), viva-voz por distância (`AudioController`). Alucinação de telefone é do `HallucinationController` |

### 19.10 Ladrão (`ThiefService`; FEAT-013; DEC-050, 182)

> **Removido (DEC-313, 2026-10-20):** o ladrão saiu do jogo e do código (`src/Thief`, `Content.Thief`, `Net.Thief`, UPG-004, notices `thief_*`, ligações "quentin"). Texto abaixo é histórico.

| Item | Contrato |
|---|---|
| Sorteio | `ShiftStarted` de dia: `Random(seed, Day, "thief")` contra `Thief.ChanceByDay`; hora na janela `Thief.WindowClock` (9 AM–3 PM); 1 por dia |
| Spawn | `NpcService:Spawn{ Role = "Thief", From = "ST-R" }` (guaxinim, roupa `thief`, NPC-007); conta no teto de 12 |
| Rota | `ST-R` → ponto de espreita `L1..L3` (`AvoidCrossings = true`, nunca cruza pista) |
| Espreita | ≤ `LurkMax` (120 s); 4 Hz: nenhum membro `Active` com HRP a ≤ `ZoneRadius` (14) de `Zone_Center` do veículo atual por `ZoneEmptyTime` (3 s) → `Approach` |
| Aproximação | 4 s fixos (DEC-182): `WalkSpeed = distância / ApproachTime` |
| Abertura | `OpenTime` = efeito `DrawerOpenTime` (8 / 16 com UPG-004). Membro entra na zona → `Caught`: foge, `EconomyService:AddToDrawer(CatchReward, "Catch")`, `Notice thief_caught` (todos), `RunState.Counters.quentin_caught_day = Day`. Sem interrupção → `EconomyService:Steal(floor(Drawer × StealPct / 100))` se `Drawer ≥ MinDrawer`; foge para `ST-R`/`EX-E` |
| Rede | set `Thief` (registro 1; `network.md` §13.4) → barra sobre `Bar_Thief` |
| Snapshot | nenhum (vivo); o contador vai em `RunState.Counters` |

### 19.11 Gemas, dia infinito e Day 100 (`RewardService`; FEAT-017, 029, 031; DEC-070, 083, 084, 104)

| Evento | Quando | Chave | Regra |
|---|---|---|---|
| Dia concluído | passo de relatório (`AddReportStep`, = início do Summary) | `D{day}:day` | `GemRewards.DayShift` se `ledger.Completed ≥ AntiAfkMinCompleted` |
| Nota A | mesmo passo | `D{day}:gradeA` | `DayGradeA` com o mesmo mínimo (`AntiAfkAppliesToGradeA`) |
| Dia infinito | mesmo passo, `RunState.Endless` | `D{day}:endless` | `EndlessDays += 1` com anti-AFK; ao chegar a `Achievements.day_100.Target` → `achievement:day_100` (300 + badge) |
| Noite vencida | `NightResolved("Won")` | `N{night}:night` | `NightBase + NightPerIndex × (N − 1)` |
| Final | `NightResolved("Won")` da última noite (antes do `Finale`) | `finale` | `GemRewards.Finale` (FEAT-027: 33 + 100 antes da cutscene) |

- Quem recebe: membros conectados com perfil carregado, em qualquer estado de vida (DEC-104). Idempotência por
  `RunRewards` (§10.4, `data.md` §1.3).
- O passo de relatório preenche `report.Gems` (soma creditada no turno, incluindo a da noite às 6:00) e
  `report.AfkLocked`; o passo do `RoundService` preenche `LastChanceUsed` (noite com `Chances = 0`).
- **Gemas da run no `RunReport`** (v4.1, T59, Provisório). O `RewardService` (550) requer o `RoundService` (750);
  o Round **não** requer o Reward (T42). Contrato:
  - `RoundService:AddRunReportStep(name, step: (player, report) -> ())`, registrado no `OnInit` do dono (o Round já
    criou a lista no `Setup`, prioridade maior). Passos rodam na ordem de registro, sem yield, em `pcall`: erro vira
    `warn` e o campo fica com o padrão.
  - No `RunEnded(result)` o Round monta, **por jogador conectado** (membro do roster com `Ready`),
    `report = { Result, Day, Night, Gems = 0 }`, roda os passos e manda o packet `RunReport` só a ele.
  - Passo do `RewardService`: `report.Gems = rr.Gems` se `rr = profile.RunRewards()` tem `rr.RunId == RunId`; senão 0
    (sem perfil carregado também 0). `RunRewards.Gems` soma no mesmo `batch` de cada `Credit` (`data.md` §1.3), então
    sobrevive a noite repetida, reconexão e retomada em outro servidor (onda 4) sem estado novo na run.
  - Ordem garantida: o último crédito possível (`finale`, `N10:night`) acontece no `NightResolved("Won")`, antes do
    `Finale`; na derrota não há crédito no `NightLost`. O `RunEnded` nunca corre antes do crédito do turno.
  - Sem `RewardService` (antes da TASK-074) a run termina com `Gems = 0` (fase sem dono não quebra, §19.0 regra 4).
- Toasts: `Notice gems_gained` (jogador), `afk_no_gems` (party), `achievement` (jogador; achievement secreto, DEC-058).
- Badge: `BadgeService:AwardBadge` com retry; `BadgesAwarded`. No lobby (onda 4) o `RewardService` também roda o retry
  no `Loaded` (L+R só nessa parte).

### 19.12 Tools: stash, snapshot, usos e item no chão (`ItemService`; FEAT-021, 025, 036; DEC-103, 197)

| Peça | Contrato |
|---|---|
| `Stash.luau` | `Stash(player)`: Tools → `RunStateService:SetStash(uid, entries)` (`{ Kind, Count, Extra }`), destrói. `Unstash(player)`: recria. Chamado em `PlayerRemoving` (Away), `Down`, respawn |
| Snapshot `T` (T50) | `{ [uid] = { { item, count, extra? } } }` de todos os membros (conectado: Backpack + mão; Away/Down: stash). Restore: conectado `Active` → recria depois do spawn; resto → stash |
| `Uses.luau` (T51) | `RegisterUse(item, { Validate(player, tool) -> (boolean, string?), Run(player, tool) })`; o servidor escuta `Tool.Activated` só das Tools que ele criou. Usos: `coffee` (Vital), `revive_kit` (Revive, onda 4) |
| `give_coffee` | ação do ItemService (§19.8) |
| `Drops.luau` (FEAT-036) | `DropHeld(player, reason)`: Tool da mão por `Items[k].DropOnHit` → `Keep`: modelo de exibição (não `Tool`, como o pacote grátis) com âncora `pick_up_item` (`PromptHold = 0.5`), atributos `Item/Count/Toppings` no servidor por `EntityId`; na pista vai ao `NpcNode` de calçada mais próximo; some em `Items[k].DropDespawn` (60 s). `Lost`: modelo `Splat` 2 s (o client faz o VFX). `DropStash(userId, pointId)`: espectador (`DROP-T`, some no fim do turno seguinte) |
| Altered (onda 3) | Tool `hot_dog` com `Altered = true` quando montada com item alterado (`KitchenService`, §19.13) |
| Snapshot | itens no chão **não** entram (FEAT-036) |
| Client | `ItemController`: contorno do item no chão, splat, derrame do café |

### 19.13 Anomalias, verbos e regras (`AnomalyService`; FEAT-022, 023, 024; DEC-054, 060, 073, 074, 195, 204)

Arquivos: `AnomalyService/init.luau` (Service, sets, `Gaze`, contexto, fan-out de eventos), `Scheduler.luau` (puro),
`Vision.luau` (puro: cone + raycast), `Anomalies/<Ref>.luau` (um por `ANM-###`, **descobertos**, T43),
`Rules/` (servidor: verbo, janela, `IsCritical`; T10). Client: `AnomalyController/init.luau` + `Effects/<Ref>.luau`
(descobertos). `Content.Anomalies` (shared) só tem o que o client precisa ver (sem verbo correto).

**Agenda** (`Scheduler.Build(night, attempt, rng) -> { { Key, At } }`, semente `RunSeed, Day, Night, Attempt,
"anomaly"`): ativas `Night ≤ N`; ocorrências estreia 3 / 1–2 noites depois 2 / 3+ 1 (`progression.md` §4.2, tabela
`Anomalies.Occurrences`); janela 9 PM–5 AM (`NightWindow = "Shift"`), 1ª da estreia no 1º terço; intervalo mínimo e
simultâneas por faixa de noite (`Nights[k].MinGap`, `MaxSimultaneous`); `ExclusiveWith`; atores ≤ `Flow.MaxActorsNight`
(3) por `NpcCost`; ocorrência `Scripted` (N10 às 5:45 AM da Night 10 + Walker) fora da janela. Recalculada no
`ShiftStarted` (não entra no snapshot, data.md §2.2).

**Módulo** (`Anomalies/<Ref>.luau` devolve `Module`):

```lua
export type Occurrence = { Id: number, Key: string, StartedAt: number, Rng: Random, State: any }
export type Event =
	{ Kind: "Customer", Npc: number, Action: string, Player: Player, Result: string? }  -- CustomerService.Acted
	| { Kind: "Switch", On: boolean, Player: Player? }                                  -- LightService.SwitchChanged
	| { Kind: "Discard", Player: Player, Item: string, Altered: boolean }               -- KitchenService.Discarded
	| { Kind: "Shutter", Closed: boolean, Player: Player? }                            -- VehicleService.ShutterChanged (v4.2)
export type Context = {
	Now: () -> number,
	Publish: (occ: Occurrence, fields: { Phase: string?, Step: number?, Anchor: number? }) -> (), -- set Anomalies
	Cue: (occ: Occurrence, cue: string, entity: number?) -> (),          -- packet AnomalyCue, todos (DEC-204)
	Fail: (occ: Occurrence, who: { Player } | "active") -> (),           -- −35 cada (Vital:Penalize); IsCritical → LoseNight("critical")
	Succeed: (occ: Occurrence) -> (),
	Finish: (occ: Occurrence) -> (),
	Active: () -> { Player },                                            -- FEAT-023: conectado, Active, com personagem
	Looking: (player: Player, target: Vector3, range: number) -> boolean, -- cone + linha de visão; protegido e alvo fora do trailer = false
	SeenTick: (occ: Occurrence, target: Vector3, range: number, dt: number) -> (), -- acumula 1 s → Vital:SeeAnomaly
	Rule: (key: string) -> any,                                          -- Rules/ (prazos, passos)
	Spawn: (spec: CustomerActorSpec) -> number?,                         -- CustomerService:SpawnActor
	Light: { BeginHush: (number, number) -> (), EndHush: () -> () },
	Vehicle: { IsShutterClosed: () -> boolean, IsInside: (Player) -> boolean, IsProtected: (Player) -> boolean }, -- v4.2
	InZone: (Player, pointId: string, radius: number) -> boolean,        -- v4.2: do próprio AnomalyService (era Hide.InZone)
	Kitchen: { Alter: (kind: "rail" | "board") -> boolean },
	Traffic: { Hold: (reason: string, on: boolean) -> () },
}
export type Module = {
	Ref: string,                                       -- "ANM-007"
	Start: (ctx: Context, occ: Occurrence) -> boolean, -- false = sem vaga/ator agora: a agenda tenta de novo
	Tick: ((ctx: Context, occ: Occurrence, now: number) -> ())?,   -- 5 Hz
	OnEvent: ((ctx: Context, occ: Occurrence, event: Event) -> ())?,
	Stop: (ctx: Context, occ: Occurrence, reason: "Done" | "NightOver" | "Restore") -> (),
}
```

| Verbo (FEAT-023) | Peça do sistema que mede |
|---|---|
| Recusar / Atender | `CustomerService.Acted` (take_order, serve, refuse) + `SpawnActor` com `Variant` (`blank`, `mirror`, `raincoat`) |
| Não olhar | `Gaze` (c → s, 10 Hz, só à noite) + `Vision` (cone `Sanity.SeeAngle`, alcance `ViewRange`, raycast) |
| Luz | `LightService.SwitchChanged` (N3: desligado ≥ 5 s e religado no prazo) |
| Fechar a janela (era Esconder, DEC-221) | `VehicleService` `IsProtected` + `ShutterChanged` (§19.14) |
| Descartar | `KitchenService:Alter` + `Discarded`; `CustomerService:AddServeRule` (servir com item alterado → `Wrong`, sem pagamento, `Cue smoke`, falha de quem serviu) |
| Ponto seguro | `AnomalyService:InZone(p, "SS", 6)` + `LightService:BeginHush` |

| Regra | Contrato |
|---|---|
| "Ver" (−5) | 1× por anomalia, por jogador, por noite (`VitalService:SeeAnomaly`); 1 s acumulado no cone; N9 `SeeMode = audioZone` |
| Quem paga | ação → quem agiu; omissão em alvo party → todos os ativos; alvo pessoal → cada um que falhou (DEC-204) |
| Crítica | só `ANM-007` (`Rules.IsCritical`, `Validate`): `Fail` → `RoundService:LoseNight("critical")` sem janela (DEC-094) |
| Walker (ANM-007) | `Step` 0..10 no set `Anomalies`; +1 por s com qualquer ativo olhando (alcance 300); −1 a cada 10 s sem olhar; 10 = crítica. Ator só de client sob o poste do `Step` (`StreetLight.Order`) |
| Long car (ANM-008) | ator só de client (timeline por `StartedAt` até `AN-12`); `TrafficService:Hold("anm_008", true)` durante |
| Cliente-anomalia | ocupa vaga de balcão e conta no teto de 12; **não** chama `EconomyService:CountArrival` (DEC-051 exclui) — o módulo chama `CountArrival` + `CountResult("Wrong")` só na falha |
| Tensão (`Q-159`, `Q-162`) | sinal `Tension(on)` enquanto houver ocorrência com `Anomalies[k].Tension = true` → `NpcService:SetTension` (pack Night de clima) e `PedestrianService` (rua deserta). Quais anomalias: tabela, Provisório |
| Limpeza | `Stop(…, "NightOver")` no `NightEnd`; `"Restore"` no `NightLost`/restore; `Anomalies:clear()` |
| Efeitos de sabor | só os da DEC-195 (N1 moeda, N2 fumaça, N6 janelas, N8 luz 3 s, N9 porta, N10 névoa); **sem** congelar relógio nem +$1 |

Rede: set `Anomalies`, packets `AnomalyCue` e `Gaze` (`network.md` §13.5). Uma task por grupo de 2–3 módulos
(server + `Effects/` do client) depois do núcleo.

### 19.14 Janela de serviço do trailer e ponto seguro (`VehicleService`; FEAT-023; DEC-054, 177, 204, 221)

**v4.2 (DEC-221):** o esconderijo (`HideService`, `HideController`, set `Hides`, âncoras `H1..H4`, ações `hide`/`get_up`,
AST-041, modo de câmera `Hidden`) **sai**. O estado protegido de N8/N9 passa a ser **a janela de serviço fechada**.
Sem feature nova: a janela é estado do veículo (princípio "estender o que existe"), dona = `VehicleService`.
O ponto seguro (N10) não dependia do esconderijo: `InZone` passa para o próprio `AnomalyService`.
Tudo abaixo é **Provisório** (`Q-173`).

| Item | Contrato |
|---|---|
| Estado | `Shutter` por veículo: `false` = aberta, `true` = fechada. Só o veículo com `Vehicles[v].HasShutter` (trailer) tem botão. O veículo **à venda** (fora de uso) fica fechado: é o estado `ForSale` do AST-027 ("janela fechada") |
| Réplica (T61) | atributo `Shutter` (bool) no `Model` do veículo (tag `Vehicle`), escrito **só** pelo `VehicleService`. Sem entrada Lync (`network.md` §13.6) |
| Binding | âncora `Prompt_Shutter` (`Interactable`, `PromptAction = "shutter_toggle"`) no botão `TRL-SHUTTER` ao lado do interruptor `TRL-SWITCH`; peça animada = malha `Awning` do AST-027 com `Attachment` `Shutter_Hinge` (eixo da dobradiça); MAP-01 §7.2, §16.5 |
| Ação | `shutter_toggle`: hold 0,5, `NightOnly`, raio 7; `Validate`: membro `Active`, âncora do veículo atual, cooldown 1 s (da party, evita estrobo); `Run`: inverte `Shutter`, `PromptText` = "Open Window" / "Close Window" (`Content.Actions`, placeholder até o `ui-text.md`); sinal `ShutterChanged(closed, player)` |
| Abre sozinha | `ShiftStarted` (todo turno, dia ou noite), `NightLost`, restore (`RepeatNight`/`Resume`), `Swapped` (o novo atual abre, o à venda fecha). Não entra no snapshot (`data.md` §5.3) |
| Venda com a janela fechada | `InteractionService:AddGate("Shutter", …)` registrado pelo `VehicleService` no `OnInit`: recusa `take_order`, `serve` e `refuse` com motivo `Shutter:Closed` quando o veículo atual está fechado. Recusa de corrida (colega fechou durante o toque) → `Notice shutter_closed` só para quem agiu (FEAT-005, no máximo 1 a cada 2 s). Fila espera, paciência corre (sem mudança no `CustomerService`) |
| Dentro do trailer | `VehicleService:IsInside(player): boolean` = raiz do personagem dentro da caixa do `Model` do veículo atual (`GetBoundingBox` guardado no `OnStart`/`Swapped`; o veículo não anda à noite) |
| Protegido | `IsProtected(player)` = `IsShutterClosed()` **e** `IsInside(player)` |
| Visão | `Context.Looking` (§19.13) devolve `false` quando o jogador está protegido e o alvo está **fora** da caixa do trailer (não vê nada pela janela fechada; a janelinha da porta dos fundos não conta). Alvo dentro do trailer (N2, N9) segue normal |
| N8 (long car) | `Phase = Active` + farol; em `+ Rules.CloseWindow` (8 s) cada `Active` na zona do trailer (raio 24 do `TRL`) **não protegido** → `Fail` (−35, alvo pessoal). Depois, até `StayFor` (15 s): `ShutterChanged(false, p)` → `Fail({ p })` (**quem abriu**, DEC-204); vigiado que sai do trailer pela porta → `Fail` dele (tick 5 Hz). Tempos, cues e ator não mudam |
| N9 (knock) | no fim da janela (`Window` 12 s) cada `Active` na zona do trailer não protegido → `Fail`; nada medido antes do fim |
| N10 (ponto seguro) | `AnomalyService:InZone(player, "SS", 6)` (distância plana ao `MapPoint`, só `Active`; mesmo cálculo que estava no `HideService`) + `LightService:BeginHush`. A ação `safe_spot` segue sem prompt |
| API | `IsShutterClosed(): boolean`, `IsInside(player)`, `IsProtected(player)`, `SetShutter(closed, player?, force?)`; sinal `ShutterChanged(closed: boolean, player: Player?)` |
| Client | `VehicleController`: lê o atributo `Shutter` do veículo (`GetAttributeChangedSignal`), gira a `Awning` em volta do `Shutter_Hinge` (tween local 0,6 s; quem entra no meio vê o estado final) e toca o som; `PromptController`: com o veículo atual fechado esconde "Take Order"/"Serve"/"Refuse" (`Rules.SetShutterProbe`). Câmera sem modo novo |
| Animação | sem clipe de personagem (o clipe `hide` sai de `Content.Animations`; `get_up` fica: é o levantar do atropelamento) |
| Dev | `Commands/Shutter.luau`: `shutter` (estado), `shutter open` / `shutter close`, `shutter in` (IsInside/IsProtected de quem chamou) |

### 19.15 Alucinações (`HallucinationController`; FEAT-019; DEC-038, 168, 169, 173)

Só client, prioridade 600. Lê `VitalController` (faixa e número próprio) e `RoundController.IsNight`. Sorteia em
`Content.Hallucinations` (faixa `< 60 / < 40 / < 20`, `Cooldown`, `Weight`), semente local. `Effects/<Key>.luau`
descobertos: telefone falso ("Walt: ..."), passos no teto, cliente fantasma na fila, poste piscando **sem** zumbido
(DEC-123), sussurro, letreiro piscando, sombra na janela. Nunca prompt, nunca rede, nunca muda estado de servidor. O NPC
em Night da faixa baixa já é do `RigController` (DEC-168/169), não daqui.

### 19.16 Cutscenes, final e fim de run (`CutsceneService`; FEAT-004, 027; DEC-078, 088, 194, 205)

| Item | Contrato |
|---|---|
| Cenas | `Content.Cutscenes`: `none`, `intro`, `finale`, `credits` (`Beats`, `Marks`, `Duration`, `Skippable`) |
| Disparo | probes `Intro` e `Finale` no `RoundService` (§19.4); `Finale` toca `finale` e depois `credits` |
| Participantes | conectados no início da cena; atrasado durante a intro **não** entra: espera e spawna no fim (DEC-205; `CharacterService:CanSpawn` falso na `Intro` para não participante) |
| Personagens | `CharacterService:Freeze(p, "Cutscene", true)`, `PivotTo` nas marcas `CutsceneMark1..4`, `MoveTo` nos beats de caminhada (R23) |
| Voto | packet `SkipVote`; `Needed = ceil(0,5 × participantes conectados)` (DEC-194; espectador vota, Provisório); recalcula ao sair; voto vale para o segmento atual |
| Atores | Walt (tartaruga, bastão, barba, DEC-202), Raincoat Lady (sapo, DEC-203), panfleto: locais ao client (`CutsceneController`), animados pelo `AnimController` |
| Câmera | `CameraController` modo `Cutscene`: POV da própria cabeça, olhar livre ±60° |
| Fim de run | packet `RunReport` (`network.md` §13.1), enviado pelo `RoundService` no `RunEnded` (já na onda 2, derrota); `Gems` preenchido pelo passo do `RewardService` (`AddRunReportStep`, §19.11, T59); tela "You Kept the Light On" / derrota no `HudController` (15 s) |

### 19.17 Trânsito, atropelamento e passantes (FEAT-033, 036; DEC-087, 095, 103, 130, 133, 183, 197, 198)

Trânsito: §8 vale inteiro (T21, T30). Acréscimos:

| Item | Contrato |
|---|---|
| `TrafficService:Hold(reason, on)` | nenhum carro nasce enquanto houver `reason` ativo (`anm_008`, `anm_010`, `cutscene`, `ambulance`) |
| Densidade da noite (DEC-198) | `Traffic.SpawnInterval` por `NightWindow` (Calma ≤ 1 carro; 0 depois das 9 PM; Provisório) |
| Atropelamento válido | `CharacterService:Knock(player, KnockTime, impulse)` (juntas pré-montadas no `Prepare`, `Ragdoll.luau`) → `VitalService:SetKnocked(player, until)` → `ItemService:DropHeld(player, "Hit")` → imunidade `ImmuneTime`. `LifeEvent{Hit}` |
| Motion compartilhado | `src/Traffic/shared/Motion.luau` (puro: posição 1D por `{ AnchorAt, AnchorDist, StopDist, HeldUntil }` + perfil de velocidade). Usado por carros **e** passantes |
| Faixa para NPC | `NpcService`/`Walker` e `PedestrianService` pedem `ReserveCrossing` (§8.1) |

Passantes (DEC-183; T46, Provisório até `Q-162` a):

| Item | Contrato |
|---|---|
| Modelo | **sem Humanoid no servidor**: `PedestrianService` mantém cada passante como cinemática 1D sobre um caminho autorado (`Content.WalkPaths`: listas de `NodeId` de calçada; faixas pedem reserva) |
| Quantos | `Flow.DayWalkers` {6, 8}, `Flow.NightWalkers` {1, 2}, 0 com `AnomalyService.Tension` (rua deserta) |
| Aparência | espécie com `Pedestrian = true`, roupa civil sorteada (DEC-188); vai no set (exceção à regra 9 do `network.md`: não há modelo de servidor para pôr atributo) |
| Client | `PedestrianController` monta rig local (`CrewRig.Build` com `Tag = true` **local**, para o `RigController` vestir, incluindo o Night da faixa baixa, DEC-169) e anda por `Motion`; LOD > 120 studs; sem colisão |
| Teto | fora dos 12 Humanoids (como carros e Opal); se o usuário decidir que contam (`Q-162` a), o mesmo set serve com teto de 12 somado |

### 19.18 Ambulância, reviver, monetização e oferta S1 (onda 4; FEAT-034, 035; §6, §10)

> **Descartado (DEC-314, 2026-10-20):** a ambulância e os médicos não serão feitos; o corpo fica no chão até o reviver ou o fim da noite (`Revive.BodyFallback`). Texto abaixo sobre ambulância é histórico.

§6 e §10 valem. Integração com o que a onda 2 deixa pronto:

| Peça | Contrato |
|---|---|
| Coleta | `AmbulanceService` chama `VitalService:SetPickupHandler(fn)` no `OnInit`; `fn(userId, bodyPos)` entra na fila (§6.3) e, no `Load`, `CharacterService:RemoveBody` |
| Reviver | `ReviveService` valida (§6.4) e chama `VitalService:Revive(userId, source)`; `Reviving → Active` no `Drop` com `CharacterService:Spawn` em `REV-n` |
| Congelamento (DEC-118) | `ReviveService` informa `VitalService:SetPurchaseOpen(userId, open)`; Vital empurra `WipeEndsAt` e grava `WipeFrozen` por `RoundService:SetWipe` |
| Médicos | atores locais (coelho alto + panda baixo, rosto `Exhausted` fixo + máscara, DEC-211, 213): atributo local `FixedFace = "Exhausted"` → `RigController` não troca o rosto, nem na faixa baixa (pelagem/roupa trocam, Provisório) |
| Espera | `AnomalyService:IsActive("anm_008" \| "anm_010")` → não despacha (`Ambulance.HoldDuring`) |
| S1 (FEAT-035) | `MarketService` sorteia no `ShiftStarted` (semente, `BenchItems`, `RequiresTrailer` via `VehicleService:IsBought()`), set `Bench`, snapshot `Bn`; compra `bench_buy_item` → `ItemService:Give("revive_kit")`; uso `ItemService:RegisterUse("revive_kit", …)` do `ReviveService` |
| Produtos | `MonetizationService:RegisterProduct("Revive", handler)` (§10.1) |

### 19.19 Lobby, party, sessão e reconexão (onda 4; FEAT-001, 030; DEC-067, 080, 098, 119, 179, 205)

> **v4.3:** lobby, squad por convite e teleporte implementados como no **§20** (sem plataformas, sem MemoryStore). A
> tabela abaixo segue como plano para reconexão/retomada.

§5 vale. Contratos de código:

| Peça | Contrato |
|---|---|
| Place Lobby | mesmo código, `Workspace.PlaceRole = "Lobby"`; Services `R` retornam no topo |
| Party (DEC-179) | tag `PartyPlatform` (`Part`, atributo `Party` 1..n); pisar = entrar (servidor por `GetPartsInPart` 4 Hz); sair da plataforma = sair; `PartyAction{ Start }` só do dono (1º a pisar); contagem `Party.Countdown` (5 s) → `SessionService:ReserveRun(members)` |
| Set `Parties` | `network.md` §13.8 |
| Sessão | `SessionService`: `ReserveRun`, `ClaimRun` (boot da run), `Heartbeat`, `Suspend`, `Resume`, `EndRun(result)`, `WriteSnapshot(snap)`; `RunStateService` passa a ler roster e semente dela e entrega cada captura a `WriteSnapshot` |
| Roster (DEC-205) | só roster entra; fora → teleporte ao lobby com `Notice`; atrasado spawna direto ao lado do veículo atual, sem cutscene |
| Reconexão | packets `Reconnect`/`ReconnectReply` (§5.4) |
| Classe | `ClassService:Select` liberado no lobby; travada na run (DEC-069) |

### 19.20 Animação (rig IK do usuário; T47)

| Item | Contrato |
|---|---|
| Fonte | o usuário anima no rig IK e exporta `Animation` R6; ids `rbxassetid://` (do grupo) em **`Content.Animations`** (`content-data.md` §3.20). Id `""` = fallback do Roblox (locomoção R6 padrão) ou nada (one-shot) |
| Crew | `CharacterService:Prepare` grava os ids de `Locomotion.crew` nos `StringValue` do `Animate` R6 do personagem (id vazio mantém o padrão). One-shots (`faint`, `get_up`, `drink`, `give`, `answer_phone`, `knock_getup`) tocados pelo **client dono** no próprio `Animator` (replica a todos). Servidor nunca toca animação de jogador |
| NPC de servidor | servidor **não** toca animação; cada client toca locomoção (`idle`/`walk` pela velocidade do HRP) num `Animator` local do rig (Provisório: protótipo em `Q-167` d; plano B = `Motor6D.Transform` procedural, como a nota da DEC-183) e one-shots por evento (`Sale`, `Customers.Mood`, `Variant`) |
| Atores locais | Opal, passantes, médicos, Walt, Walker, long car: `AnimationController` + `Animator` locais (padrão do `OpalController`) |
| `AnimController` | `Bind(model, set: string)` (locomoção automática; LOD: pausa > 120 studs e fora da tela), `Play(model, key, opts?) -> AnimationTrack?`, `Stop(model, key)`, `PlayOwn(key)`; pré-carga por `ContentProvider` |

### 19.21 Áudio (T55)

| Item | Contrato |
|---|---|
| Tabelas | `Content.Sounds` (efeitos, ambiente, voz, UI e faixas de música) e `Content.Music` (cue → faixa e condição) (`content-data.md` §3.21). Id `""` = silêncio sem erro |
| `AudioController` | cria `SoundGroup` Master/Music/Ambient/Sfx/Voice/Ui em `SoundService`; `Play(key, at?: Vector3 \| Instance, opts?) -> Sound?` (pool, teto `SoundRules.MaxVoices` = 12, §12.5), `Loop(key, at, on)`, `PushMusic(cue)`/`PopMusic(cue)`; música padrão pela fase/turno do `RoundController` (`Music.When`) com fade |
| Rede | **nenhuma**: cada controller toca som no evento que já recebe (`Sale` moeda, `Notice` UI, `Call` toque, `AnomalyCue`, timeline da ambulância, motor dos carros, `Lights` do Hush). Servidor não cria `Sound` |
| Regras | sirene e sustos nunca acima do ambiente (DEC-005, DEC-173); ducking da música durante a ligação (`SoundRules.DuckOnCall`) |

### 19.22 Binding de mapa das ondas 2–3 (pedido ao level-designer; mesmo contrato do §18)

| Onda | O quê | Tag / atributo / ponto |
|---|---|---|
| 2 | Estações do trailer | como §18.4 (`Vehicle = "trailer"`, `Rail_8`, tábua `Att_Bun1..3`), `coffee_machine` com `Prompt_Brew` (`brew_coffee`) e `Prompt_Restock` |
| 2 | Telefone | `Prompt_Answer` → `answer_phone` no carrinho **e** no trailer (DEC-124) |
| 2 | Compra do trailer | `Prompt_Buy` → `buy_trailer` no trailer à venda; placa `SIGN-T` |
| 2 | Lona | `Model` com tag `VehicleCover` (AST-043, DEC-199), escondida até a troca (visibilidade, T38) |
| 2 | Luz | `LightZone` LZ-1..5 (`ZoneId`, `Group`); `StreetLight` JL-01..09 + P-01 (`PostId`, `Group`, `Order`); `Prompt_Switch` → `switch_light` |
| 2 | Pontos | `PS-N1..4`, `REV-1..4`, `TRL`, `TRL-SALE`, `CART`, `SPEC-P`, `SPEC-M`, **`DROP-T`** (novo: balcão do trailer para os itens do espectador, FEAT-025; o level-designer registra no MAP-01), `L1..L3`, `ST-R` (+ nós de grafo até as espreitas, `MAP-01` §9.2) |
| 2 | Lixeiras de rua | `Model` da lixeira AST-034 interativa com tag **`StreetBin`** (v4.1, T60; fora de qualquer `Station` e de `Vehicle`), âncora `Prompt_Discard` (`Interactable`, `PromptAction = "discard"`). Dono do verbo: `KitchenService` (TASK-057). Quantas e onde: `Q-166` b; **não** entram em `Required.Wave2` (número aberto) — a checagem só avisa `StreetBin` sem âncora (DEC-200; o que aceita: `Q-166`) |
| 3 | Janela do trailer (DEC-221) | `Prompt_Shutter` (`Interactable`, `shutter_toggle`) no botão `TRL-SHUTTER` ao lado de `TRL-SWITCH`; `Awning` + `Shutter_Hinge` no AST-027; `SS` (`MapPoint`). `H1..H4` saem |
| 3 | Anomalias | `AN-04`, `AN-05`, `AN-11`, `AN-12`, `AS-1..4` (`MapPoint`); janelas `WV-1..3` (tag `AnomalyAnchor`, `AnchorId`) |
| 3 | Cutscene | `CutsceneMark1..4`, `CS-*` (`MapPoint`) |
| 3 | Trânsito e passantes | §8 (rotas, `SL-*`, `X-T`, faixas) + caminhos `WalkPaths` (cadeias de `NodeId` de calçada) |
| 4 | Ambulância | `AMB-M`, `AMB-P`, `AMB-IN`, `AMB-OUT` |

`src/Place/shared/MapIndex/Required.luau` ganha uma lista por onda (`Required.Wave2`, `Wave3`, `Wave4`); o
`PlaceService` valida a onda configurada em `RunParams.BindingWave` (Provisório).

### 19.23 Orçamento (atualiza §12.2–§12.4)

| Entidade | Teto | Onde roda | Conta nos 12 |
|---|---|---|---|
| Clientes (dia / noite) | 8 / 6 | servidor | sim |
| Ladrão | 1 (só dia) | servidor | sim |
| Clientes-anomalia (N1, N4, N5) | dentro de `MaxActorsNight` (3) | servidor | sim |
| Walker, long car, janelas, relógio, Hush | — | client (estado no set `Anomalies`) | não |
| Passantes | 8 dia / 2 noite / 0 em tensão | client (1D no servidor) | não (Provisório, `Q-162` a) |
| Carros | 4 dia / ≤ 1 na Calma / 0 depois das 9 PM | client (1D no servidor) | não |
| Ambulância + 2 médicos | 1 | client | não |
| Opal, Walt (cutscene) | 1 cada | client | não |

IA e custo de servidor: tick de cliente 5 Hz, visão (Gaze → cone) 5 Hz por jogador, escuro 1 Hz, Walker 5 Hz, trânsito
e passantes 10 Hz (só aritmética, ≤ 12 entidades), A* ≤ 2 por frame. Animação de NPC só no client com LOD (T47).

Replicação extra por client (pior caso: noite, 4 jogadores): `Vitals` < 30 B/s; `Sanity` ≤ 1/s; `Lights`,
`Thief`, `Call` eventos (< 10 B/s); `Anomalies` ≤ 2 eventos/s com Walker ativo (< 30 B/s); `AnomalyCue` < 10 B/s;
`Pedestrians` ≤ 8 × ~4 registros/min (< 15 B/s); `Gaze` c → s 10 Hz × ~6 B. Total de Lync segue < 1,5 KB/s.

### 19.24 Ondas sugeridas (para o task-planner)

Regra: dentro de uma onda, cada linha é uma task paralelizável; pontos de conflito (um dono por arquivo) entre
parênteses. Toda onda começa pela **task de contrato** (Net + Content + `Required.luau`), como a TASK-003/004 na onda 1.

**Onda 2 — a noite existe (run completa sem anomalia).** Saída: comprar o trailer, jogar Night 1..10 com sanidade,
escuro, café, ligação, cair e virar espectador, perder/repetir a noite, gemas, ladrão de dia.

| Lane | Conteúdo | Depende de | Arquivos (dono único) |
|---|---|---|---|
| W2-0 | Contrato: `Net/init.luau` v2 (§13.1–13.4 do `network.md`), Content novo (Shift noite, Nights, LightGroups, Sanity, Thief, BossCalls/Rules, GemRewards, Achievements, Animations, Sounds, Music, WalkPaths vazio, Actions/Notices novos), `Required.Wave2` | — | `src/Libs/Net/init.luau`, `src/Shared/Content/init.luau` + tabelas novas |
| W2-A1..A4 | Ajustes de extensão (§19.26) | W2-0 | `EconomyService`, `InteractionService`, `RunStateService`, `CustomerService` (um por task) |
| W2-L | Binding do trailer, telefone, luz, pontos, lona (level-designer) + kits (café, lona) (modeler-3d) | — | place; `tools/` |
| W2-B | Run completa (`RoundService/` pasta, `Flow`, `RoundController`) | W2-0, A3 | `src/Round/**` |
| W2-C | Trailer e troca (`VehicleService`, `VehicleController`, reação do `KitchenService` à troca) | W2-0, W2-B (sinal `BeforeShift`) | `src/Vehicle/**`, `KitchenService/init.luau` |
| W2-D | Luz (`LightService`, `LightController`, `Zones`) | W2-0 | `src/Light/**` |
| W2-E | Sanidade e vida, servidor (`VitalService/`, `CharacterService` Faint/RemoveBody/Freeze/SetLookPack/SpawnPointFor/`Prompt_Give`) | W2-0, A2, A3, W2-D (`IsLit`; pode começar com stub) | `src/Vital/server/**`, `src/Character/**` |
| W2-F | Sanidade e vida, client (`VitalController`, spectate na `CameraController`, `HudController` noturno, `CharacterController`) | W2-0 | `src/Vital/client/**`, `src/Camera/**`, `src/Hud/**`, `src/Character/client/**` |
| W2-G | Tools: stash, snapshot `T`, usos, `give_coffee`, item no chão (`ItemService` + `ItemController`) | W2-0, A3 | `src/Item/**` |
| W2-H | Café (`Stations/CoffeeMachine.luau`, `KitchenController/Coffee.luau`) | W2-0, W2-G (`RegisterUse` só para o beber, que é do Vital) | os dois arquivos novos |
| W2-I | Chefe (`BossService`, `BossController`) | W2-0, A2 (`Performed`) | `src/Boss/**` |
| W2-J | Ladrão (`ThiefService`, `ThiefController`, `NpcService.Role`) | W2-0, A1 (`Steal`) | `src/Thief/**`, `NpcService/` (só `Role`) |
| W2-K | Gemas, dia infinito, Day 100 (`RewardService`) | W2-0, A1 (`AddReportStep`) | `src/Reward/**` |
| W2-M | Animação e áudio (`AnimController`, `AudioController`, locomoção de NPC no client) | W2-0 | `src/Anim/**`, `src/Audio/**` |

**Onda 3 — anomalias, regras, final e rua.** Saída: as 10 anomalias com verbos, regra crítica, final da 10ª noite,
cutscenes com voto, trânsito com atropelamento, passantes, alucinações.

| Lane | Conteúdo | Depende de | Arquivos |
|---|---|---|---|
| W3-0 | Contrato: Net v3 (§13.5–13.7), Content (Anomalies, Rules, AnomalyCues, Hallucinations, Cutscenes, Traffic, WalkPaths), `Required.Wave3` | onda 2 | Net, Content |
| W3-A | Núcleo de anomalias (`AnomalyService` init/Scheduler/Vision/Gaze, `AnomalyController` init; ganchos `CustomerService.SpawnActor/AddServeRule`, `KitchenService.Alter/Discarded` + campo `Altered`) | W3-0 | `src/Anomaly/server/AnomalyService/init.luau`, `Scheduler`, `Vision`; Customer e Kitchen (só os ganchos) |
| W3-B | ~~Esconder e ponto seguro~~ → v4.2: janela do trailer no `VehicleService` + aba no `VehicleController` (DEC-221) | W3-0 | `VehicleService/`, `VehicleController` |
| W3-C1..C4 | Módulos de anomalia + efeitos de client: (N1, N4, N5) clientes; (N2, N3) cozinha e luz; (N6, N7) não olhar + crítica; (N8, N9, N10) janela fechada, ponto seguro, Hush | W3-A, W3-B | `Anomalies/ANM-00k.luau` + `Effects/ANM-00k.luau` |
| W3-D | Alucinações | W3-0 | `src/Hallucination/**` |
| W3-E | Cutscenes, final da 10ª noite, `RunReport` | W3-0 | `src/Cutscene/**` |
| W3-F | Trânsito + atropelamento (`TrafficService`, `TrafficController`, `Motion`, `CharacterService.Knock`/`Ragdoll`, `ItemService.DropHeld` já existe) | W3-0 | `src/Traffic/**`, `CharacterService/Ragdoll.luau` |
| W3-G | Passantes (`PedestrianService`, `PedestrianController`) + reserva de faixa do `NpcService` | W3-F (`Motion`, `ReserveCrossing`) | `src/Pedestrian/**`, `NpcService/Walker.luau` |

**Onda 4 — meta, sessão e monetização.** Saída: lobby com party por plataformas, teleporte, reconexão e retomada,
ambulância com médicos, reviver por Robux/apito/crédito, oferta S1.

| Lane | Conteúdo | Depende de | Arquivos |
|---|---|---|---|
| W4-0 | Contrato: Net v4 (§13.8–13.9), Content (Revive, Ambulance, Products, MarketBench/BenchItems), `Required.Wave4` | onda 3 | Net, Content |
| W4-A | Lobby e party (`PartyService`, `PartyController`, `ClassService` no lobby; place Lobby) | W4-0 | `src/Party/**`, `ClassService` |
| W4-B | Sessão, teleporte, reconexão, retomada, atrasado (`SessionService`, `SessionController`, `RunStateService` com roster/snapshot remotos, fase `Resume`) | W4-0 | `src/Session/**`, `RunStateService/` |
| W4-C | Ambulância e médicos (`AmbulanceService`, `AmbulanceController`) | W4-0 | `src/Ambulance/**` |
| W4-D | Reviver + monetização + S1 (`ReviveService`, `ReviveController`, `MonetizationService`, `MarketService` S1) | W4-C (`RequestReturn`) | `src/Revive/**`, `src/Monetization/**`, `MarketService/` |

Por que essa ordem: a noite (onda 2) é pré-requisito de anomalia, ambulância e reviver; trânsito e passantes não
dependem da noite, mas dependem do sinal de tensão e do `DropHeld` (onda 2) e somam risco de performance que convém
medir depois da noite; lobby/sessão não tocam gameplay e podem ir para qualquer onda — ficam na 4 porque precisam do
place Lobby e do MemoryStore, e o modo dev cobre o teste das ondas 2–3. Se faltar paralelismo na onda 3, **W4-A e W4-B
podem subir para a onda 3** sem conflito de arquivo (só `RunStateService/` com W2 já fechado).

### 19.25 Técnicas novas (delegadas ao architect pela DEC-208)

| # | Técnica | Alternativa descartada |
|---|---|---|
| T42 | Sem ciclo de `Require`; central expõe probe/registro (`SetPhaseProbe`, `SetVehicleProbe`, `SetVerdict`, `SetPickupHandler`, `AddGate`, `AddReportStep`, `AddServeRule`); fase com `SkipWithoutProbe` pula sem dono | `Require` mútuo (tipos do `SelfOf.Build` recursivos; ordem de `OnInit` frágil) |
| T43 | Anomalias como módulos descobertos (`Anomalies/*.luau`) com contexto só de funções, como as estações (T37) | um arquivo com as 10 (conflito entre tasks paralelas) |
| T44 | Ligação do chefe como **set** `Call` com `StartedAt`; linha calculada no client | packet por linha (quem reconecta perde a ligação; mais pacotes) |
| T45 | Luz de jogo numa feature própria (`LightService`, set `Lights`), Vital só consulta `IsLit` | escuro dentro do `VitalService` (Hush e N3 mexeriam no Vital) |
| T46 | Passantes como cinemática 1D no servidor + rig local no client (set `Pedestrians`), fora do teto de Humanoids | 6–8 Humanoids de servidor (estoura DEC-045; custo de física) |
| T47 | Animação: servidor nunca toca; crew pelo `Animate` com ids da tabela + one-shot do dono; NPC e atores locais no client com LOD | servidor tocando todas as animações (custo e replicação de tracks) |
| T48 | Campos do `ShiftReport` de outras features entram por `EconomyService:AddReportStep` antes do envio | segundo packet de relatório; `ShiftEnded(info, report)` com ciclo Reward ↔ Economy |
| T49 | `InteractionService:AddGate` + sinal `Performed` | cada dono revalidar estado de vida/esconder; dicas do chefe ouvindo cada Service |
| T50 | Tools no snapshot sob a chave `T` do `ItemService` | `M[uid].T` (capturado antes de o Item sincronizar o stash) |
| T51 | Uso de Tool por `Tool.Activated` no servidor via `ItemService:RegisterUse` | packet novo por item |
| T52 | ~~`Hides` como set próprio (id = `UserId`)~~ **superada pela DEC-221** (esconderijo saiu; ver T61) | campo no `Vitals` (dois escritores no mesmo registro) |
| T53 | Anomalia = set `Anomalies` (estado, para quem reconecta) + packet `AnomalyCue` (instantâneo), sinal para todos (DEC-204) | só packet (quem reconecta não vê o Walker no passo atual) |
| T54 | Coleta do corpo por `PickupHandler` trocável (padrão = remoção com fade; onda 4 = ambulância) | noite da onda 2 sem queda (não testa a derrota) |
| T55 | Áudio sem rede: `Content.Sounds/Music` + `AudioController`; cada controller toca no evento que já recebe | packet `Sound` genérico (tráfego e acoplamento com o servidor) |
| T56 | `RunEnd` em modo dev volta à 1ª captura (`ResetDev`) até o lobby existir | servidor parado no `RunEnd` |
| T57 | `StreamingEnabled = false` no place Run (DEC-209: mapa sempre carregado; não há decoração distante listada) | ligado com `Persistent` em tudo (mesmo resultado, mais regra) |
| T58 | `Transition` (packet) para o fade da troca de veículo; a sequência da noite perdida sai da fase `NightLost` (`PhaseStartedAt`), sem packet | fase nova no `Shift` só para o fade |
| T59 | (v4.1) `RunReport.Gems` por passo registrado: `RoundService:AddRunReportStep`; o `RewardService` lê `RunRewards.Gems` do perfil (soma gravada no mesmo `batch` do crédito) | `Require` Round → Reward (ciclo); Round somando gemas (dois donos de gema); total só em memória do Reward (perde na retomada em outro servidor, onda 4); recalcular a partir de `RunRewards.Keys` (depende de a tabela não mudar entre sessões) |
| T60 | (v4.1) `discard` com dono único `KitchenService` também na lixeira de rua: âncora sem `Station`, dentro de `Model` `StreetBin`; ramo próprio no `Evaluate` (pula `IsCurrent`), mesma regra de mão do `Trash.luau` | dono novo (`RegisterAction` recusa chave repetida; dois donos do mesmo verbo); estação `trash` falsa fora do veículo (entraria em `Stn`, troca de veículo e `IsCurrent`) |
| T61 | (v4.2, DEC-221) Janela do trailer como **atributo `Shutter` no `Model` do veículo**, escrito só pelo `VehicleService` (exceção declarada à regra 9 do `network.md`, como o atributo `Bought`): 1 bool por veículo, estado de objeto do mundo (como porta), muda ≤ 1/s, `StreamingEnabled = false` (T57) garante o atributo em todo client, quem entra no meio recebe pronto; a regra (protegido, gate) é só do servidor. Gate de venda pelo `InteractionService:AddGate("Shutter")`, sem tocar o `CustomerService` | set novo `Shutter` (entrada no `Net` e no enum só para 1 bool); campo no `Lights` (dono e semântica de outra feature); campo no `Shift` (dois escritores no registro do `RoundService`); `ShutterService` próprio (feature para 1 bool, mais um `Require` no `AnomalyService`) |

### 19.26 Divergências com a onda 1 (tasks de ajuste)

| # | Divergência | Ajuste | Bloqueia |
|---|---|---|---|
| A1 | `EconomyService` envia `ShiftReport` sem gemas/AFK/última chance; `SHOP_PHASES` fixo em `Open`; sem roubo | `AddReportStep`, `IsShopOpen` por `Shift.Selling`, `Steal`, `DrawerKind "Catch"` | W2-B, W2-J, W2-K |
| A2 | `InteractionService` não conhece estado de vida/esconder; não avisa ação concluída | `AddGate`, sinal `Performed` | W2-E, W2-I, W3-B |
| A3 | `RunStateService`: sem `SetLifeState`/`SetStash`/`SpendChance`/`SetEndless`/`ResetDev`; `M.T` no snapshot; campos mortos no `Member` | API nova, `T` sai do `M`, `Member` enxuto | W2-B, W2-E, W2-G |
| A4 | `CustomerService` só vende em `Open`; sem `Acted` | spawn em `Selling` (noite), `Flow` noturno, sinal `Acted` | W2-B (noite jogável), W3-A |
| A5 | `architecture.md` §4.1 dizia `ShiftEnded(info, report)`; §3.1 dizia Round requer Vital | doc corrigido aqui (§19.3, §19.2); código não muda. **v4.1 (TASK-049): conferido** no código e corrigido também no §3.1 e no §4.1 | — |
| A6 | `ItemService.CurrentVehicle()`, `RoundService.Record().Vehicle` e `MapIndex/Required.luau` usam `RunParams.StartVehicle` | trocar por `VehicleService:Current()` / probe; `Required` por onda | W2-C, W2-G |
| A7 | `Actions`: `brew_coffee` e `give_coffee` com hold 0 (FEAT-021 diz 1 e 0,5); faltam `answer_phone`, `get_up` | tabela (W2-0) | W2-H, W2-I |
| A8 | `CharacterService` usa só o `Animate` padrão; `OpalController` com id de idle fixo no código | ids em `Content.Animations` | W2-M |
| A9 | Legado `Vitals` (Health/Armor) e `Round` (packet) no `Net`; componente `Vital` de exemplo | removidos na W2-0/W2-E (o `VitalController` antigo sai junto) | W2-E |
| A10 | `content-data.md` `Items.DropDespawn` 120 s × FEAT-036/DEC-197 60 s | 60 s (FEAT-036 é a fonte) | W2-G |

### 19.27 Perguntas novas (registradas em `open-questions.md`)

| Q | Tema | Recomendação Provisória |
|---|---|---|
| `Q-167` | Lista de animações do rig IK, convenção de export/upload e teste do `Animator` local em NPC de servidor | lista em `content-data.md` §3.20; ids vazios até o upload; protótipo do `Animator` local antes da W2-M |
| `Q-168` | Fonte e licença de música e SFX; lista de cues | ids vazios; lista em `content-data.md` §3.21; só áudio com licença verificada (`credits.md`) |
| `Q-169` | Estoque acima da capacidade na troca carrinho → trailer (DEC-184: trailer volta ao Cooler 1) | manter o excesso (sem perda); `Restock` bloqueado até cair abaixo da capacidade |
| `Q-170` | Café de dia (sanidade não existe de dia) | só bebe à noite; de dia a Tool fica guardada (não ativa) |

### 19.28 Mesas do Pad e duplas (TASK-144 a TASK-146; FEAT-037, FEAT-038; Provisório)

**Grupos de mesa (2026-10-12, `Q-209`):** `Content.Seating.Groups` = { Pad: `TBL-1..5`, UPG-008 (`TableCount`), cart + trailer; Trailer: `TBL-6..9`, UPG-011 (`TrailerTableCount`), só trailer, mostra só a próxima à venda }. `Seating.Tables` = 9. O `SeatingService` guarda o `Group` de cada `Spot`, calcula o estado por grupo (`Tables.Idle/Next` ganham `ghostAll`), esconde (`Locked`, sem colisão) o grupo cujo veículo não é o atual e só deixa sentar no grupo que manda (`SeatingGroup()`: Trailer com o trailer e ≥ 1 mesa comprada, senão Pad). Binding: `TableIndex` global 1..9 (+ `TableGroup` opcional conferido); `bindTables` e `tools/assetplace/trailer_tables.luau` só acrescentam, nunca movem. Dev: `/dev customer tables trailer [buy]`, `/dev customer tables buy [pad|trailer]`.

Feature nova `src/Seating/server/SeatingService/` (`init.luau`, `Tables.luau` puro, `Diner.luau`), prioridade **568**
(abaixo do `AnomalyService` 570), `Require` PlaceService, NetService, RunStateService, RoundService, EconomyService,
InteractionService, UpgradeService, NpcService, CustomerService, AnomalyService. Client (TASK-147):
`src/Seating/client/SeatingController/`, prioridade 680 (com os outros controllers de mundo).

| Ponto | Contrato |
|---|---|
| Customer → Seating | sem `Require` de volta (T42): `CustomerService:SetSeater(fn(party) -> boolean)`, chamado no fim do pedido (não pode ceder: roda dentro do `Run` do Serve). `party = { Leader, Partner?, Couple, CustomerType }`. `true` = o Seating reservou a mesa; o cliente vira `Leaving` com `Dining = true` (sem caminhada de saída, sem `LEAVE_TIMEOUT`) até `CustomerService:Dismiss(leader)` |
| Quem pode sentar | `CustomerService:Conclude`: sozinho Completo/Perfeito, ou dupla com ≥ 1 Completo e nenhum Errado/Desistiu/Recusado; ator (`Variant`) nunca |
| Condições (`SeatingService:TrySeat`) | fase em `SitPhases`; sem tensão (`AnomalyService:IsRunning` de `TensionAnomalies` ou `CustomerService:HasActor()`); diners + tamanho ≤ `MaxDiners`; `CustomerService:Count() ≤ MaxCustomers() − SitHeadroom`; mesa `Free` de menor índice com os assentos do grupo; depois a chance (`Tables.Chance`, Random do turno, domínio `"seating"`) |
| Caminho | Q1 → `NpcNode` `TBL-n` (se o bind tiver) ou o nó mais perto da mesa que não é vaga de fila (`MapIndex.NearestNode`, **fallback**) → ponto de aproximação (2,5 studs atrás do assento) → assento. Volta: ponto de aproximação → nó → `Dismiss` → saída normal pelo grafo. `NpcService` ganhou `WalkToPosition`, `MoveToward`, `Teleport`, `SetNode`, `Face`, `SetWalkSpeed`, `GetRig` |
| Sentado | `Diner.Sit`: HRP ancorado no `CFrame` do `SeatN` (posição = torso, frente = `LookVector` achatado); sem Id em `npc_sit`, quadris/ombros a ±90° por `Motor6D.C0` (replica, `RestC0` guardado); atributo `Seated`. `Pool.release` desancora e restaura `RestC0` |
| Levantar | `EatTime` vencido, tensão (≤ 1 tick de 5 Hz), fase fora de `SitPhases` que não seja `Closing`: `Dirty`, `Tip += TableTip × pessoas` |
| Fim de turno | gaveta fechada (Summary, fim de noite): todas as mesas `Free`, gorjeta perdida; `ShiftStarted`: idem (o `CustomerService:RemoveAll` derruba os diners, `Removed` limpa a pose) |
| Compra | `buy_in_place` (dono `SeatingService`): âncora com `Upgrade` vendido aqui (`patio_tables` na próxima mesa `Ghost`, `patio_lights` na placa); `UpgradeService:CanBuy` + `Buy(key, player, quiet = true)`; notice `table_added` (mesa) ou `upgrade_bought` (luzes). Back Bar recusado (sem TBL-6) |
| Upgrade escopo Pad | `UpgradeService:SetLevel` grava o nível em todo veículo da linha; `Restore` normaliza; `CanBuy` respeita `Requires` ("locked") |
| Duplas | `CustomerService/Group.luau` (puro): `Roll` (chance do turno + par ponderado), `PartnerLook` (nunca espécie+roupa iguais; à noite nunca a mesma espécie), `Spot`. Parceiro = registro com `Leader`, fora da fila (`Occupants` não conta), sem prompt, movido por `StepPairs` a 10 Hz (`MoveToward`, sem A*; `Teleport` além de `Leash`). Ticket com 2 linhas (`Orders.Ticket(lines)`, `Orders.Match`), `Sale`/`CountResult` por linha, `CountArrival` 2 |
| Dev | `/dev customer tables [buy|sit]` (dirty / clean saíram com o restaurante, 2026-10-18), `/dev customer group [leader+partner]` |
| Fallbacks registrados | mesas por nome em `MAP01_Assets.PadDecor` ordenadas pela distância a Q1 (warn 1×, escreve tag/atributo); âncora runtime `Prompt_Table`; nó mais próximo; notas do `MapIndex.SeatingNotes` só avisam (`PlaceService`) |
| Pendente | `LZ-PATIO` (UPG-009 à noite) precisa de linha em `LightGroups` + volume no bind, e o `Required` cobra toda zona de `LightGroups`: entra junto com a TASK-149. Medir 4 NPCs sentados no MicroProfiler do celular (`Q-180` B) |

## 20. Uma place, papéis de servidor; squad no lobby (v4.3, TASK-154 a TASK-156; pedido do usuário 2026-10-11; Provisório)

Pedido do usuário (2026-10-11, testes com amigos): **uma única place** com papéis de servidor. Substitui a topologia
"dois places" do §1 e o `Workspace.PlaceRole` autoral; o §5 (MemoryStore, reconexão, retomada) **segue como plano** e
não foi implementado (a run continua só em memória; quem sai não volta à mesma run). Onde o §1, §5.2 e §19.19 divergem
deste §20, **vale o §20**.

### 20.1 Papel do servidor (`src/ServerRole/`)

| Papel | Quando | O que roda |
|---|---|---|
| `Lobby` | servidor **público** publicado | Profile, Class, Shop/Codes, `PartyService`, `LobbyService` (spawn); nenhum Service de run |
| `Game` | servidor **reservado** criado pelo lobby (`TeleportData.Role = "Game"`, ou sem TeleportData) | a run inteira (como hoje) + `PartyRunService` |
| `PrivateLobby` | reservado com `TeleportData.Role = "PrivateLobby"` (ou `"Lobby"`), ou servidor VIP | igual ao `Lobby` |

Resolução (uma vez, no `OnInit` do `RoleService`, prioridade **990**):

1. Reservado (`PrivateServerId ~= ""` e `PrivateServerOwnerId == 0`): espera o 1º jogador (até 30 s; o servidor só
   existe porque um teleporte está chegando) e lê `player:GetJoinData().TeleportData`. Sem dados válidos → `Game` (solo).
2. VIP (`PrivateServerOwnerId ~= 0`) → `PrivateLobby`.
3. Resto (público publicado, Studio, Team Test): atributo de Workspace **`ServerRoleOverride`** (`"Lobby"`, `"Game"`,
   `"PrivateLobby"`) se válido — vale também publicado, com `warn`; **no Studio**, sem override: `Workspace.PlaceRole`
   legado (`"Lobby"` → Lobby) ou **`Game`** (padrão, para os testes atuais não mudarem); publicado → `Lobby`.

Publicado: **deixe `ServerRoleOverride` vazio** (ou `"Lobby"`). Com `"Game"` todo servidor público vira run, sem lobby
— útil só como "botão de pânico" para jogar como antes se o fluxo de lobby falhar.

Exposição: atributo **`ReplicatedStorage.ServerRole`** (escrito pelo `RoleService`). Server: `RoleService:Get()`,
`Is(role)`, `IsLobby()`, `IsGame()`, `IsReserved()`, `GetLaunch()`. Client: `PlaceController:GetServerRole()` (o
`OnInit` espera o atributo até 30 s; fallback `Game`). Módulo puro `ReplicatedStorage.shared.ServerRole.Roles`
(`Parse`, `ParseLaunch`, `Read`, `Wait`, `IsLobby`, `PlaceRole`).

**Ponto único de corte do loop da run:** `PlaceService`/`PlaceController` passam a derivar `"Lobby" | "Run"` do papel
(`Game` = `"Run"`). Todo Service de gameplay já retorna no topo quando `not PlaceService:Is("Run")` (§3.1), então no
lobby **nada** de run sobe (Round, Customer, Npc, Traffic, Pedestrian, Kitchen, Vital, Character, Cutscene, Anomaly,
Boss, Thief, Light, Market, Upgrade, Vehicle, Seating, Item, Interaction, Economy, Reward, Tutorial, RunState) e
`Profile`, `Class` (escrita liberada fora da Run), `Shop`, `Codes` continuam. `PlaceService:ValidateMap` só roda no `Game`.

Nomes: `RoleService` e `Roles.luau` (não `ServerRoleService`/`ServerRole.luau`) porque o rogen tira o prefixo
"Server" do nome do arquivo e o joga no `ServerScriptService`; e não há `src/ServerRole/client`, porque o gerador do
Modux lê caminho com "Server" como código de servidor.

O que mudou em código existente (mínimo):

| Arquivo | Mudança |
|---|---|
| `src/Place/server/PlaceService.luau` | `Require = { "RoleService" }`; papel vem de `Roles.PlaceRole(RoleService:Get())`; não lê mais `PlaceRole` |
| `src/Place/client/PlaceController.luau` | papel de `Roles.Wait(30)`; `GetServerRole()` novo |
| `src/Place/shared/MapIndex/init.luau` | `Validate`: `MapPoint` com `PointId` começando em `LOBBY-` pode ficar fora do `MapBinding` (mapa do lobby na mesma place) |
| `src/Round/server/RoundService/init.luau` | `SetStartGate(gate)`: `StartRun` espera `gate()`; `Step` testa o portão a 10 Hz enquanto houver membro. Sem portão = comportamento antigo |

### 20.2 Squad no lobby (`PartyService`, prioridade 680, papéis de lobby)

**Emenda Provisória da DEC-179** (plataformas físicas): o usuário pediu em 2026-10-11 squad por **convite** (clique no
jogador ou lista), líder, pronto e botão Start. Registrar com o secretário.

| Regra | Valor (Provisório) |
|---|---|
| Tamanho máximo | `PartyRules.Rules.MaxSize` = `#Content.RunParams.PartyPriceMult` = **4** (DEC-012) |
| Criar | `PartyCreate`; recusado se já está numa squad. Convidar sem squad cria uma |
| Convidar | só o líder; alvo neste servidor, fora da squad, squad `Forming` e com vaga; mesmo alvo a cada 3 s; convite vale 60 s |
| Aceitar | sai da squad atual (se `Forming`) e entra; `Ready = false` |
| Sair / cair | sai; squad vazia some; líder saiu → 1º membro restante lidera (`NewLeader`) |
| Expulsar | só o líder, só em `Forming` |
| Pronto | membros não-líderes; o líder é sempre pronto |
| Start | só o líder, todos prontos, `Forming` → `Starting` |
| Taxa | 8 pacotes de squad por jogador por segundo (`TooFast`) |

Start (thread própria): `ReserveServer(game.PlaceId)` → `TeleportOptions{ ReservedServerAccessCode = code }` +
`SetTeleportData{ Role = "Game", PartyId, Members, Leader }` → `TeleportAsync(game.PlaceId, membros presentes, options)`.
Reserva ou teleporte falhando: nova tentativa após 2/5/10 s (`TeleportRetry`); todas falharam → volta a `Forming`
(não-líderes despronto) + `TeleportFailed`. Aceito pelo Roblox mas falhou para um membro depois
(`TeleportInitFailed`): ele tenta sozinho com as **mesmas** opções (mesmo servidor), 3 vezes; depois `TeleportFailed`.
Vigia: 45 s em `Starting` sem ninguém em voo → reabre. **Studio não teleporta**: Start responde `StudioNoTeleport`.
`TeleportData` não é autorização (só o servidor tem o código do reservado); é só o roster.

### 20.3 Squad no servidor `Game` (`PartyRunService`, prioridade 745)

- Lê `RoleService:GetLaunch()` (TeleportData do 1º jogador). Senta os membros no roster do `RunStateService`
  (`Seat`, na ordem da squad) **antes** de qualquer admissão: o roster é a squad (DEC-205).
- Portão do `RoundService`: a run começa quando todos os membros da squad estão no servidor, ou
  `Content.RunParams.JoinWindow` (60 s, DEC-098) depois do 1º; quem chega depois spawna no trabalho, sem intro
  (DEC-205, já no `CharacterService`). Participantes da cutscene = conectados no início (§19.16, sem mudança).
- Sem launch (Studio, Team Test, reservado sem TeleportData) = **solo/dev**: quem entra vira membro, run começa no 1º.
- Jogador fora da squad num servidor com squad → `PartyNotice WrongServer` e volta ao lobby em 3 s (DEC-205).
- Fim da run: `RunEnded` → 12 s depois (`RunEnd` dura 15 s) todos vão para um servidor **público** da place
  (`TeleportAsync(game.PlaceId, players)` sem código = `Lobby`), com retry 2/5/10 s e `ReturnFailed`. Packet
  `LobbyReturn` manda um jogador a qualquer momento (botão da tela de fim de run; sair sempre pode, DEC-067). Só em
  servidor reservado; Studio responde `StudioNoTeleport`. Se o teleporte falhar, o `EndRun` de sempre recomeça a run.

### 20.4 Spawn no lobby (`LobbyService`, prioridade 675, papéis de lobby)

**Atualizado 2026-10-11 (pedido do usuário, Provisório; §20.6):** no lobby o personagem é o **avatar Roblox do jogador
em R15**, não o rig da crew: `CharacterAutoLoads = true` só nos papéis de lobby (o `Game` segue `false` e a classe pelo
`CharacterService`); um `StarterPlayer.StarterCharacter` esquecido na place é tirado no servidor de lobby; se a
experiência forçar R6, o personagem carregado é trocado uma vez por `Players:CreateHumanoidModelFromDescription(..., R15)`.
O rig da classe aparece só no palco da tela de classes (client). Texto original, substituído: ~~`CharacterAutoLoads =
false`; o personagem é o rig da crew da classe selecionada (mesma técnica do `CharacterService`:
`CrewRig.Build` como `StarterCharacter` por um `LoadCharacter`, um por vez).~~ Ponto: `MapPoint` com `PointId`
**`LOBBY-SPAWN`** (vários: qualquer id começando com `LOBBY-SPAWN`, sorteado, ±3 studs). Sem ponto: `warn` 1× e o 1º
`SpawnLocation` do Workspace; sem ele, onde o `LoadCharacter` puser. Trocar de classe no lobby reconstrói o rig no
lugar; morrer renasce no ponto. No `Game` o spawn segue o fluxo atual (`PS-*`, `CharacterService`); não existe
`MAP-SPAWN`.

Para o level-designer: o mapa do lobby fica na mesma place, longe do MAP-01, **fora** do `MapBinding` e sem a tag
`MapBinding`; só pontos `LOBBY-*` são aceitos fora da raiz pelo `MapIndex.Validate`. `check_map01` (edit-time) ainda
não conhece essa exceção.

### 20.6 Zonas do lobby, anéis, plataformas de squad e câmera (pedido do usuário 2026-10-11; Provisório)

Dados: `Content.Lobby` (`src/Shared/Content/Lobby.luau`: `Zones`, `Trigger`, `Rings`, `Squad`, `Camera`). Geometria
compartilhada: `ReplicatedStorage.shared.Lobby.LobbyZones` (`src/Lobby/shared/LobbyZones.luau`): centro = `MapPoint`
(`PointId`) quando existe, senão `Center` do Content; `Inside(zone, pos, was)` com histerese.

| Zona | Centro (WORLD) | Raio | Abre | Anel |
|---|---|---|---|---|
| Classes | (0, 0, −587,5), na frente do cordão do palco | 3,5 | tela de classes | amarelo |
| Gem Shop | `LOBBY-SHOP` (−19,5, 0, −600) | 3,5 | loja de gemas | verde |
| Codes | `LOBBY-CODES` (−10, 0, −622,5) | 3,5 | códigos | azul |
| Squad 1..4 | `LOBBY-SQUAD-1..4` (20, 0,3, −588/−598/−608/−618) | 4 | janela da plataforma (`SquadSetup`) | branco livre / vermelho com squad / verde `Starting` |

- **Gatilho (client, `LobbyController`)**: a cada `Trigger.Poll` (0,1 s) o `HumanoidRootPart` local contra cada zona;
  entrar abre o painel, sair fecha (se ainda for o aberto). Fechar no X não reabre até sair e entrar.
- **Anéis (client, `LobbyController/Rings.luau`)**: por zona, `Rings.Count` partes invisíveis ancoradas com
  `Points` `Attachment`s tangentes num círculo e um `Beam` curvo entre vizinhos (textura da referência do usuário);
  um `Heartbeat` só, um `BulkMoveTo` por frame; sobem em loop, giram (alternando o sentido), wobble de inclinação e
  deriva; fade na base e no topo; zona a > 80 studs da câmera sai do Workspace.
- **Plataformas (servidor, `PartyService`)**: detecção, criação/entrada/saída de squad, `FriendsOnly`
  (`Player:IsFriendsWith`), `MaxPlayers`, contagem de 5 s antes do teleporte (`network.md` §16.6).
- **Câmera**: no lobby, `CameraController` em `External` e `CameraMode Classic` (terceira pessoa, zoom 0,5..30,
  empurrada a 12 uma vez); a 1ª pessoa travada continua no `Game`. Com a tela de classes aberta todos os personagens
  ficam invisíveis localmente (LOBBY.md §11).

### 20.5 Configuração no site (Creator Hub)

Nada obrigatório para teleporte na mesma place: `ReserveServer`/`TeleportAsync` funcionam no jogo publicado sem
liberar nada. Conferir: place publicada (não só salva), jogo com acesso para os amigos (público ou amigos), e
`Max Players` (Places → Settings) ≥ o lobby desejado (o reservado usa o mesmo valor; a squad é 4).
Teleporte **não** funciona no Studio (nem Play Solo, nem Team Test).
