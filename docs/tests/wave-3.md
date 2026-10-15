Status: Rascunho

# Plano de teste — Onda 3 (anomalias, regras, final e rua)

Autor: qa-tester. Versão 1, 2026-10-10 (**TASK-127**). Resultado da execução: **TASK-128** preenche a §11 deste
arquivo e escreve `docs/tests/wave-3-report.md`.

**Versão 1.1, 2026-10-10 (TASK-134, DEC-221):** o esconderijo sai (`HideService`, `HideController`, set `Hides`,
`H1..H4`, ações `hide`/`get_up`, modo de câmera `Hidden`, AST-041). Entra a **janela de serviço do trailer**: atributo
`Shutter` no `Model` do trailer, ação `shutter_toggle`, gate `Shutter` no balcão, `Notice shutter_closed`; protegido
de N8/N9 = janela fechada **e** dentro do trailer. Casos T102-*/T103-* viram histórico (tasks substituídas); casos
novos T129-*, T130-*, T131-*, T132-*, T133-*; T097, T098, T101, T104, T106, T115, T117, X3, Q3, P3, §7, §8, §9 e §10
revistos. Base nova: `architecture.md` v4.2 §19.14, `network.md` §13.6/§13.11, `content-data.md` §6.9 (v5.2),
MAP-01 §7.2/§16, `Q-173` (todos os números da janela são **[P]**).

Base: `docs/tasks/board.md` v2.0 (critérios de aceite TASK-096 a TASK-123, "Notas da v2.0"),
`docs/tech/architecture.md` v4.1 §8 (trânsito, atropelamento, ragdoll), §19.13–§19.17, §19.22, §19.23,
`docs/tech/network.md` v5.1 §6.2, §13.5–§13.7, §13.12, `docs/tech/content-data.md` §3.17, §6.10, §6.11,
Content da onda 3 (`src/Shared/Content/Anomalies.luau`, `Hallucinations.luau`, `Cutscenes.luau`, `Traffic.luau`,
`WalkPaths.luau`, mais `Nights.luau`, `Sanity.luau`, `Items.luau`, `Flow.luau`), `docs/story/anomalies.md` (Aprovado),
`docs/design/npcs.md` NPC-009..018 (parâmetros e critérios de aceite das anomalias), FEAT-004, 019, 022, 023, 024,
025, 026, 027, 033, 036 (`docs/design/features.md`), `tests/wave-1.md` e `tests/wave-2.md` (casos reaproveitados na
regressão), DEC-025, 045, 051, 053, 054, 060, 073, 074, 087, 094, 095, 103, 122, 123, 130, 133, 168, 169, 173, 176,
177, 183, 194, 195, 197, 198, 204, 205, 216, 221 (DEC-176 deixa de valer).

> **Base Provisória (DEC-193).** Onde a spec é Provisória (`Tension` por anomalia `Q-159`/`Q-162`, `ViewRange` de
> N3/N8/N10, densidade de noite DEC-198, intervalo e cooldowns de alucinação, espectador vota, passantes fora do teto
> `Q-162` a, `Traffic.Look = int(1, 32)`, `Stations.Altered` opcional, pitch cíclico do `Gaze`, tags de trânsito,
> leitura animal de N1/N4/N5 `Q-147`), o caso testa o valor **Provisório** e está marcado **[P]**. Se a decisão mudar,
> o caso muda junto.
>
> **Fora da onda 3** (não testar aqui): ambulância, reviver, médicos, Rescue Whistle, bancada S1 (onda 4); lobby,
> party, sessão/retomada de 15 min, roster do lobby (onda 4; em dev o roster = quem entrar). Nas ondas 2–3 **ninguém
> é revivido**: quem cai fica `Down` até as 6:00 AM ou até a noite ser perdida. Assets 124–126 entram como
> placeholder; o plano só confere que a troca não exige código.

---

## 0. Como usar este plano

### 0.1 Tipos de verificação

Iguais aos da onda 1 (`wave-1.md` §0.1): **E** estático, **S** script (Command Bar / lune), **M** manual no Studio.
Compilação limpa **não** fecha nenhum caso **M** ou **S**. Anomalia nenhuma fecha só por **E**: o verbo, o erro, a
omissão e quem paga precisam de **M** com pelo menos 2 jogadores.

### 0.2 Ambiente

| Item | Configuração |
|---|---|
| Build | `rogen build` → `modux generate` → `rojo serve`; place Run com o binding da TASK-098 salvo e os kits da TASK-099 em `ReplicatedStorage.Assets` |
| Modo | **dev** (`PlaceService:IsDev() == true`); `RunParams.BindingWave = 3` **só depois** de `Validate(Required.Wave3)` passar (TASK-097/098). Antes disso, casos de anomalia de servidor rodam com `BindingWave = 2` só para o que não depende do mapa (S de lune) |
| 1 jogador | Test → Play (F5) |
| 2 jogadores | Test → **Clients and Servers**, Clients = 2 |
| 3–4 jogadores | Clients = 3 ou 4 (obrigatório nos casos **3p/4p**: voto de cutscene, Walker com vários olhando, N10 com 4 no ponto seguro, orçamento) |
| PC | teclado + mouse; interagir = **E** |
| Mobile | Test → Device "iPhone SE" (667×375) e "iPad"; 📱real se houver place publicado. Console fora (DEC-171) |
| Rede ruim | `IncomingReplicationLag` = 0,3 s nos casos **lag** (carros, `CarHit`, Walker, voto) |
| Noite curta | para casos que não medem duração: cópia local de `Nights.luau` com `Duration = 600` na noite testada (1 min de jogo = 1 s). **Nunca commitar.** Casos de prazo (N3 60 s, N6 3 s, N7 1 s/passo, N8 8 s, N9 12 s, N10 15 + 20 s) são em **segundos reais** e não mudam com a noite curta |
| Semente fixa | R24 (`/dev seed`) para repetir a mesma agenda entre rodadas |

Ritmo real: 1 min de jogo = `Duration / 600` s (Night 1: 2 s; Night 7: 2,7 s; Night 10: 3 s). Janela de anomalia
9 PM–5 AM = 480 min de jogo (Night 1: 16 min reais). As 10 noites reais somam ≈ 4 h 40 min só de `Night`: sem
`/dev night`, `/dev clock` e `/dev anomaly` a onda não é testável.

### 0.3 Como observar o servidor

Igual às ondas 1–2 (`wave-1.md` §0.3, `wave-2.md` §0.3), mais:

- Sets novos (Command Bar, servidor ou client): `Net.Anomalies:get(id)` (`Anomaly`, `Phase`, `StartedAt`, `Step`,
  `Anchor`), `Net.Cutscene:get(1)` (`Scene`, `Votes`, `Needed`), `Net.Traffic:get(slot)`,
  `Net.Pedestrians:get(slot)`, `Net.Stations:get(id).Altered`.
- Janela do trailer (DEC-221; sem entrada Lync): atributo `Shutter` do `Model` do trailer (tag `Vehicle`), no servidor
  e em cada client: `CollectionService:GetTagged("Vehicle")` → `:GetAttribute("Shutter")` (`true` = fechada).
  `/dev shutter` imprime o estado; `/dev shutter in` imprime `IsInside`/`IsProtected` de quem chamou (TASK-130).
- Packets s → c (`AnomalyCue`, `LifeEvent{Hit}`): listener no Command Bar do **client** antes do passo.
- Packets c → s (`Gaze`, `CarHit`, `SkipVote`): contar no servidor com um responder de teste **só em cópia local**
  ou pelo log R16/R19; nunca registrar responder extra no código entregue.
- Sanidade: `Net.Vitals:get(uid)` + packet `Sanity` no dono; −5 = "ver", −35 = falha (`Sanity.RuleBroken`).
- Comandos de dev já previstos nas tasks: `/dev anomaly <key>` (106), `Commands/Shutter.luau` (130:
  `shutter`, `shutter open`/`close`, `shutter in`; substitui o `Commands/Hide.luau` da 102),
  `Commands/Traffic.luau` (104), `Commands/Cutscene.luau` (120); mais os das ondas 1–2 (`night`, `lose`, `win`,
  `sanity`, `down`, `spectate`, `light`, `trailer`, `cash`, `call`, `thief`).

### 0.4 Pedidos de testabilidade (R15–R26)

Continuação dos R1–R14. **Recomendação Provisória** do qa-tester ao task-planner: cada pedido cabe no arquivo de
comando que a própria task já cria (`DevService/Commands/<X>.luau`), sem mexer em arquivo de outro dono.
**R6 (`/dev clock <h:mm>`) ainda não existe** em `Commands/Round.luau` (conferido 2026-10-10) e é pré-requisito de
quase todo o §8: pedir junto.

| # | Pedido | Casos que dependem | Onde caberia |
|---|---|---|---|
| R6 | (onda 2, pendente) `/dev clock <h:mm>` | 5:45 AM da Night 10, janela 9 PM–5 AM, densidade de trânsito, §8 inteiro | TASK-054 (`Commands/Round.luau`) — se a 054 já fechou, task de ajuste curta |
| R15 | `/dev anomaly <key> [now]` (já no aceite da 106) + `/dev anomaly stop` + `/dev anomaly list` (imprime ocorrências ativas com `Phase`/`Step`) | T106-*, T111..T118, §8 | TASK-106 (`Commands/Anomaly.luau`) |
| R16 | log de dev de anomalia: uma linha por `Start`, `Succeed`, `Fail(who)`, `SeeAnomaly(player)`, `Stop(reason)`, `Tension(on)` | "quem paga" de todas as anomalias, T106-07..10 | TASK-106 (mesmo arquivo) |
| R17 | `/dev agenda` imprime a agenda da noite atual (`Key`, `At` em h:mm) e a semente | T106-01..05, §8 passo 14 | TASK-106 |
| R18 | `/dev walker <0..10>` grava `Step` pelo mesmo caminho do módulo | T115-04..08, T116-02/03 | TASK-115 (arquivo novo `Commands/Walker.luau`) |
| R19 | `/dev traffic car <TR-n>` (nasce um carro na rota), `/dev traffic hold <reason> on\|off`, `/dev traffic log` (registros e `ReserveCrossing`) | T104-*, T105-*, T122-03 | TASK-104 (`Commands/Traffic.luau`) |
| R20 | `/dev hit [player]` chama o mesmo caminho do `CarHit` válido (sem carro) | T100-01..04, T104-10..14, T066 da onda 2 pelo caminho real | TASK-104 (mesmo arquivo) |
| R21 | `/dev cutscene intro\|finale\|credits` e `/dev cutscene stop` | T120-*, T121-* sem rodar a run inteira | TASK-120 (`Commands/Cutscene.luau`) |
| R22 | `/dev alter rail\|board` chama `KitchenService:Alter` | T109-*, T113-01..05 | TASK-113 (arquivo novo `Commands/Kitchen.luau`) ou 109 |
| R23 | `/dev gaze [player]`: imprime 1×/s, por 10 s, `Looking(p, alvo, range)` de cada ocorrência ativa | T101-04, T106-06, T115-* | TASK-106 |
| R24 | `/dev seed <n>` fixa `RunSeed` da run atual (próximo `ShiftStarted` recalcula a agenda) | repetição determinística, T106-01 | TASK-106 |
| R25 | client: `HallucinationController.Debug(key)` só em Studio (`RunService:IsStudio()`), chamado pelo Command Bar do client | T119-* | TASK-119 |
| R26 | `/dev tension on\|off` força o sinal `Tension` | T108-06, T122-02 | TASK-106 |

---

## 1. Portão estático (vale para **toda** task de código da onda 3)

G-01 a G-21 (ondas 1–2) continuam, com os donos de arquivo da v2.0 ("Regras do board", "Ondas 2 e 3"). Novos:

| ID | Verificação | Esperado |
|---|---|---|
| G-22 | T10: nada de verbo, prazo, passo ou crítica em shared | `Content.Anomalies` sem `Verb`, `Window`, `IsCritical`, `Steps`; `Rules/` só em `src/Anomaly/server/` (grep `CorrectVerb\|IsCritical\|LookLimit\|HoldFor` fora de `server` = 0) |
| G-23 | T43: anomalias descobertas; ninguém edita o núcleo | `git diff` das 111–118 sem `AnomalyService/init.luau` nem `AnomalyController/init.luau`; um arquivo por `ANM` em `Anomalies/` e `Effects/` |
| G-24 | alucinação sem rede e sem prompt | `HallucinationController/**`: 0 `require` de `Net`, 0 `ProximityPrompt`, 0 `Interactable`, 0 `CollectionService:AddTag` de tag de servidor |
| G-25 | servidor sem animação e sem som (G-19) | única exceção: `CharacterService/Ragdoll.luau` (juntas, não animação). `LoadAnimation`/`Sound` em `src/*/server` = 0 |
| G-26 | sem Humanoid nem física de carro/passante no servidor (T46, §8.1) | `TrafficService`/`PedestrianService` não criam `Model`/`Humanoid`/`BasePart`; só registros 1D |
| G-27 | módulos puros rodam em lune | `Traffic/shared/Motion.luau`, `AnomalyService/Scheduler.luau`, `Vision.luau` sem `game:GetService` nem `Instance` (Vision recebe o raycast injetado) |
| G-28 | responders de rede só em Service/Controller no `OnInit` | `Gaze` → só `AnomalyService`; `CarHit` → só `TrafficService`; `SkipVote` → só `CutsceneService`; componente nenhum registra |
| G-29 | comandos de dev em arquivo próprio, só `IsDev()` | `Commands/Anomaly`, `Shutter`, `Traffic`, `Cutscene` (+ R18/R22 se aceitos); `Commands/Hide.luau` apagado (130) |
| G-30 | `RunParams.BindingWave = 3` só depois de `Validate(Required.Wave3)` 0 erro | commit que muda o valor vem depois do PASS da 098 |
| G-31 | sets novos sem `keyBy` de campo infinito | `Anomalies`, `Pedestrians`, `Traffic`, `Cutscene`: sem `keyBy` (`Hides` sai na 133) |
| G-32 | nenhum número de design no código (G-18): prazos 5/60/3/20/8/15/12/20, passos 10, raios 6/15/55, 300 studs | vêm de `Rules/` (servidor) ou `Content` |
| G-33 | `CameraController` não envia `Gaze` de dia, `Down`/`Spectator` nem em cutscene (DEC-221: sem condição de "escondido"; a janela fechada é filtrada no servidor, T130-15) | leitura do código + T101-04 |
| G-34 | esconderijo fora do código (DEC-221) | depois da 130/131: `src/Hide/**` não existe; depois da 133: `grep -r "Hides\|HideService\|HideController\|hide_taken\|HidePoints" src/` = 0 fora de gerados; `Actions.hide`/`get_up` e `Animations.hide` fora; `Animations.get_up` **fica** (atropelamento) |
| G-35 | atributo `Shutter` escrito só pelo `VehicleService` (T61) | `grep -rn "\"Shutter\"" src/` → `SetAttribute("Shutter"` só em `src/Vehicle/server/`; client só `GetAttribute`/`GetAttributeChangedSignal`; nenhuma entrada `Shutter` em `Net/init.luau` |
| G-36 | gate `Shutter` registrado no `OnInit` do `VehicleService` | `AddGate("Shutter", …)` dentro de `OnInit`; nenhum outro Service/componente registra; `AnomalyService` usa `VehicleService` por `Require`, não por rede |

---

## 2. Casos por task

Colunas: **Tipo** (E/S/M) · **Jog.** (1p/2p/3p/4p) · **Plat.** (PC/Mob/ambos). Mob = emulador; 📱real quando marcado.
Em toda anomalia, os casos seguem a mesma ordem: **sinal → ver (−5) → verbo certo → erro por ação → omissão → quem
paga → sabor → reconexão**.

### TASK-096 — Content da onda 3 (Em QA)

| ID | Critério | Tipo | Passos | Esperado |
|---|---|---|---|---|
| T096-01 | `Validate()` passa e é rápido | S | require de `Content` no servidor e no client, `os.clock()` antes/depois | sem erro; < 0,003 s |
| T096-02 | 10 anomalias, 1 estreia por noite | S/E | `Anomalies.List`; `Nights[k].NewAnomaly` | `ANM-001..010`, `Night` = k, `NewAnomaly` de cada noite existe em `Anomalies` |
| T096-03 | T10 | S | cópia local com `Verb = "refuse"` numa linha | `error` cita o campo |
| T096-04 | `Scripted` só na Night 10 | S | `Scripted = { Night = 7, … }` na N3 | `error` |
| T096-05 | `ExclusiveWith` simétrico | S | tirar `anm_010_hush` do `ExclusiveWith` da N3 | `error` |
| T096-06 | custo de atores roteirizados ≤ `MaxActorsNight` | E | `walker` (1) + `hush` (0) na Night 10 às 1785 | ≤ 3 |
| T096-07 | cues | E | `Anomalies.Cues` | 18 chaves (16 do §6.10 + `curtain`, `car_flash`); cada `Cues` de anomalia ⊂ lista; nenhum cue de "congelar relógio" nem "+$1" (DEC-195) |
| T096-08 | 8 alucinações por faixa | E | `Hallucinations` | 2 em < 60, 3 em < 40, 3 em < 20; `post_flicker` comentado "sem zumbido"; `Interval {20, 45}` **[P]**; `NightOnly = true` |
| T096-09 | cutscenes | E | `Cutscenes` | `none`, `intro` (45/cap 50), `finale` (60/60, `Next = credits`), `credits` (75/75); `Skippable`; `Participants = "ConnectedAtStart"`; beats ordenados por `At` |
| T096-10 | `Traffic` | E/S | `DensityAt(1100)`, `DensityAt(1200)`, `DensityAt(1300)`, `DensityAt(1800)` | 2 carros; 1 carro; 0 carro; `nil`. Rotas noturnas (`DayNight`) só TR-1/TR-2 |
| T096-11 | `LookOf`/`LookIndex` | S | ida e volta de 1..20 | bijeção; `LookIndex(4,5) = 20`; nenhum look "preto e comprido" |
| T096-12 | `WalkPaths` vazia é válida | S | `Validate` com a tabela vazia (antes da 098) | passa; `Rules.Slots = 8 ≥ DayWalkers[2]` |
| T096-13 | nenhuma tabela da onda 2 mudou | E | `git diff` das tabelas da 047 | só `init.luau` e as tabelas novas |

### TASK-097 — Net v3 + `Required.Wave3` (Em QA)

| ID | Critério | Tipo | Passos | Esperado |
|---|---|---|---|---|
| T097-01 | entradas = `network.md` §13.5–§13.7 | E | diff de `Net/init.luau` | `Anomalies`, `AnomalyCue`, `Gaze` (`:newest(10)`), `Cutscene`, `SkipVote`, `Traffic`, `CarHit`, `Pedestrians`; nada da onda 1/2 removido ou renomeado. `Hides` existe até a 133 e então sai (T133-01) |
| T097-02 | `Stations.Altered` | E | ler | `Lync.optional(Lync.int(0, 30))` **[P]** (doc diz não opcional: L3-06) |
| T097-03 | `Traffic.Look` | E | ler | `int(1, 32)` **[P]** (doc diz 16: L3-06) |
| T097-04 | `Gaze` com pitch negativo | S | client manda pitch −30; servidor lê | lido como 330 e convertido para −30 pelo leitor (> 180 → −) **[P]** |
| T097-05 | boot sem erro de `Lync.start()` | M | 1p e 2p, F5 | Output limpo (G-13). **Pendente da 097** |
| T097-06 | `Required.Wave3` | S | `BindingWave = 3` numa cópia local, place sem binding da 098 | `Validate` acusa por nome `SS`, `AN-*`, `AS-*`, `WV-*`, `CutsceneMark*`, `CS-*`, `Prompt_Shutter` do trailer (DEC-221; era `H1..H4` `Slot`), `TrafficPath/Line/Box`; com `BindingWave = 2` nada disso é pedido |
| T097-07 | ~~`Slotted`~~ | — | — | **Superado (DEC-221):** `Slotted = { hide = 4 }` saiu do `Required` na 129; ver T129-04 |
| T097-08 | `BindingWave` segue 2 | E | `RunParams.luau` | 2 até a 098 passar (G-30) |

### TASK-098 — Binding do MAP-01, onda 3 + `WalkPaths`

| ID | Critério | Tipo | Esperado |
|---|---|---|---|
| T098-01 | `check_map01` PASS e `Validate(Required.Wave3)` 0 erro | S | lista vazia; place reaberto mantém o binding |
| T098-02 | ~~esconder~~ | — | **Superado (DEC-221):** `H1..H4` saem do place; a janela é binding da TASK-132 (T132-*) |
| T098-03 | ponto seguro | M | `SS` sob o letreiro "OPEN 24 HOURS"; raio 6 cabe 4 jogadores parados; a área conta como luz (`IsLit` verdadeiro, R12) |
| T098-04 | anomalia | S | `AN-04/05/11/12`, `AS-1..4`, `WV-1..3` (`AnomalyAnchor`, `AnchorId`), `WALKER-10` |
| T098-05 | Walker | M | 10 posições sob os postes da Juniper, passo 10 na borda da luz do trailer; **a rota Pad ↔ Mart não exige olhar a Juniper** (`anomalies.md` "N10 × N7") |
| T098-06 | cutscene | S | `CutsceneMark1..4`, `CS-2..CS-5`, `CS-P1..4`, `P-01`, `CART`, `SS-1..4`, `MKT-DOOR`, `WALT-1`, `RL-1`, `RL-END` |
| T098-07 | trânsito | S | `TrafficPath` TR-1..10, `TrafficLine` `SL-*`, `TrafficBox` `X-T` e CW-1..4; spawn de cada rota a ≥ 55 studs da 1ª faixa (mede o mapa, §8.1) |
| T098-08 | `WalkPaths` | S | toda linha com nós existentes; faixa = par de nós `Crosswalk`; `Validate` passa |
| T098-09 | linha de visão | M | do balcão: janelas `WV` e Juniper visíveis dentro dos `ViewRange` (80 / 300); de dentro do trailer com a janela fechada, a aba cobre a janela (T131-01) e o servidor não conta "olhar" para fora (T130-15) |

### TASK-099 — Kits da onda 3 (Em QA)

| ID | Critério | Tipo | Esperado |
|---|---|---|---|
| T099-01 | `check()` 0 problema; idempotente | S | 2 execuções seguidas sem diferença; ids dos 4 `_Paints.fbx` presentes |
| T099-02 | 4 formas × 5 pinturas | S | `Assets.Vehicles.Cars/<Shape>` com `Paints/<Cor>`; 20 looks ≤ 32 (`Traffic.Look`) |
| T099-03 | frente | M | carro posto com o `CFrame` da rota anda de **frente** (LookVector = frente) |
| T099-04 | long car | M | `LongCar` preto, comprido, vidro 0,15; `Light_HighL/R` desligados no kit; nenhum carro de trânsito igual a ele |
| T099-05 | `altered_item` | S | `Variants/altered_item/{Sausage,Bun}` (Tools, `Item = altered_item`); `Food/SausageWrong`, `Food/BunBitten` com as caixas de `SausageGrilled`/`BunOpen` |

### TASK-100 — `CharacterService` onda 3: `Knock`, `Ragdoll`, `CanSpawn`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T100-01 | juntas pré-montadas | S | 1p | depois do spawn, Explorer | `BallSocketConstraint` desligadas em pescoço, braços e pernas; `Motor6D` guardados |
| T100-02 | `Knock` replica | M | 2p | R20 em A | A em ragdoll com impulso (frente + cima); B vê igual; sem som/animação de servidor |
| T100-03 | levanta em 2–3 s (DEC-197) | M | 1p | cronometrar | 2,5 s no chão + 0,5 levantando = 3 s ± 0,2; controles voltam; Humanoid nunca morre (`Health` igual) |
| T100-04 | `Knock` em respawn | M | 1p | knock → resetar personagem | personagem novo com juntas novas; nenhum constraint órfão |
| T100-05 | `CanSpawn` na `Intro` | M | 3p | C entra durante a intro (R21) | C sem personagem até o fim; spawna no fim, no trabalho (DEC-205) |
| T100-06 | desmaio (DEC-216) | M | 2p | `/dev down` em A | ragdoll + `Fainted` sem arremesso (fecha L2-13 se usar o `Ragdoll.luau`) |
| T100-07 | regressão | M | 2p | T018-01..07, T061-01..09 | ok |

### TASK-101 — `CameraController` onda 3: `Cutscene`, `Gaze` (`Hidden` sai na 131, DEC-221)

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T101-01 | ~~`Hidden`~~ → sem modo novo | E/M | 1p | ambos | **Revisto (DEC-221):** o modo `Hidden`, `HIDE_DROP` e o listener de `Hides` saem na 131 (T131-05). Esperado: com a janela fechada a câmera segue em 1ª pessoa normal, sem `CameraOffset` baixo |
| T101-02 | `Cutscene` POV | M | 2p | ambos | câmera na própria cabeça; olhar livre ±60° do eixo do plano; corpo próprio invisível, colegas visíveis (FEAT-004) |
| T101-03 | `Gaze` 10 Hz | S | 1p | — | à noite, `Active`, de pé: ~10 envios/s (R16 ou contador local); com a câmera parada continua ≤ 10/s |
| T101-04 | `Gaze` cortado | S | 2p | — | 0 envio: de dia, `Down`, `Spectator`, em cutscene; em ragdoll de atropelamento **envia** (jogador continua ativo, FEAT-023). Dentro do trailer com a janela fechada **envia** normalmente (o corte é do servidor, T130-15) |
| T101-05 | yaw/pitch certos | S | 1p | PC | olhar para `WV-1`: R23 mostra `Looking = true` para N6; olhar para baixo: pitch negativo correto (T097-04) |
| T101-06 | regressão | M | 1p | ambos | T019-01..03, T064-01..06 |

### TASK-102 — `HideService` · TASK-103 — `HideController` (**Substituídas**, DEC-221)

T102-01..10 e T103-01..05 **não rodam mais**: as tasks foram substituídas pela TASK-130/131 e o código não entra
(board: "Não fazer merge"). O que deles continua valendo foi movido: `InZone(p, "SS", 6)` (era T102-08) → T130-18;
gate que recusa ações (era T102-06) → T130-07; solta sozinho no fim da noite / noite perdida (era T102-07) → T130-10;
reconexão (era T103-04) → T131-04; prompt no celular (era T103-01) → T131-03. Histórico dos casos antigos: git
(`docs/tests/wave-3.md` v1).

Pré comum das TASK-129..133: trailer comprado e atual (`/dev trailer buy` + `/dev trailer swap`, T056-12), noite
(`/dev night k`, `/dev clock 9:30 PM`), A e B `Active`. "Fechada" = atributo `Shutter == true` (§0.3). Números
**[P]** (`Q-173`): hold 0,5 s, raio 7, cooldown 1 s, `Notice` 1 a cada 2 s, tween 0,6 s, zona do trailer raio 24.

### TASK-129 — Contrato aditivo da janela (W3-0c)

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T129-01 | `Actions.shutter_toggle` | E | — | ler `Actions.luau` | `Hold = 0.5`, `Radius = 7`, `NightOnly = true`, `Wave = 3`, `Text = "Close Window"` **[P]** |
| T129-02 | `Notices.shutter_closed` | E | — | ler `Notices.luau` | texto "The window is closed.", escopo `Player`, som `None`, `Wave = 3` |
| T129-03 | `Vehicles.HasShutter` | E/S | — | ler / require no Command Bar | `cart = false`, `trailer = true`; `HidePoints` ainda presente (sai na 133) |
| T129-04 | `Required.Wave3` | S | — | `Validate` com `BindingWave = 3` numa cópia local: (a) place sem `Prompt_Shutter`; (b) com 1; (c) com 2 no trailer | (a) erro cita `shutter_toggle`/trailer; (b) passa; (c) erro (esperado = 1). Nenhum pedido de `hide`, `Slot` ou `H1..H4`; `Slotted = { hide = 4 }` fora |
| T129-05 | só adiciona | E | — | `git diff` da 129 | `Actions.hide`/`get_up`, `Notices.hide_taken`, set `Hides` continuam (código da 102/103 ainda compila até a 130/131) |
| T129-06 | `Content.Validate()` | S | — | require no servidor e no client | sem erro; `Validate` não exige `HidePoints` |
| T129-07 | boot sem erro de `Lync.start()` (enum do `Interact` mudou) | M | 1p, 2p | F5 e Clients and Servers = 2 | Output limpo (G-13). **Pendente** (architect não testou no Studio) |

### TASK-130 — Janela no `VehicleService` + N8/N9 + retirada do `HideService`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T130-01 | fechar à noite | M | 1p | A segura "Close Window" 0,5 s no `TRL-SHUTTER` | `Shutter = true`; `PromptText` vira "Open Window"; `ShutterChanged(true, A)` 1× (R16 ou `/dev shutter`) |
| T130-02 | abrir | M | 1p | depois de 1 s, A segura "Open Window" | `Shutter = false`; texto volta a "Close Window"; `ShutterChanged(false, A)` 1× |
| T130-03 | só à noite (`NightOnly`) | M | 1p | de dia (Open, Closing, Summary): olhar o botão; forjar `shutter_toggle`; `/dev shutter close` | sem prompt; forjado recusado; dev de dia: nada (aceite da 130). Prep da noite: registrar (L3-18) |
| T130-04 | cooldown 1 s da party | M | 2p | A fecha; B forja `shutter_toggle` 0,5 s depois; de novo 1,1 s depois | 1ª recusada sem mudar estado (sem estrobo); 2ª aceita. A sozinho forjando 10× em 1 s → 1 troca (L3-19 sobre toast) |
| T130-05 | qualquer membro `Active` | M | 3–4p | A fecha; B abre; C `Down` (`/dev down`) forja; D `Spectator` forja (4p) | B abre normalmente; C e D recusados (`Active`) |
| T130-06 | raio e âncora | M | 1p | forjar a 10 studs do botão; forjar com o `EntityId` de outra âncora (interruptor, estação) | recusado (raio 7 / âncora errada); estado igual |
| T130-07 | balcão recusado com janela fechada | M | 2p | fechada, cliente no balcão com pedido: forjar `take_order`, `serve` (HotDog certo na mão), `refuse` | os 3 `Rejected(... "Shutter:Closed")`; sem `Sale`, sem `Refused`. `grill_place`, `board_*`, `switch_light`, `give_coffee`, `restock` **aceitos** (gate só no balcão) |
| T130-08 | fila espera, paciência corre | M | 1p | fechar com 3 clientes na fila; esperar | ninguém atende; paciência desce; quem esgota vai embora como insatisfeito normal (sem mudança no `CustomerService`; L3-21); ao abrir, quem sobrou é atendido normal |
| T130-09 | toast de corrida | M | 2p | A segura "Take Order" (hold) e B fecha a janela antes de A soltar | A recebe `Notice shutter_closed` ("The window is closed."); B não recebe nada; A forja `serve` 5× em 1 s → no máx. 1 toast a cada 2 s |
| T130-10 | abre sozinha | M | 1p | fechar e então: (a) `NightEnd` → próximo turno; (b) `/dev lose wipe` (`NightLost` → repetição); (c) próximo `ShiftStarted` noturno | (a)(b)(c) `Shutter = false` no início do turno/repetição; nenhum turno começa fechado. Snapshot sem `Shutter` (`data.md` §5.3; ler o snapshot em dev) |
| T130-11 | troca de veículo | M | 1p | antes de comprar: trailer em `TRL-SALE`; depois `/dev trailer swap` | à venda: `Shutter = true` (`ForSale`); depois da troca: trailer atual aberto; carrinho (`HasShutter = false`) sem botão e sem gate: vende sempre |
| T130-12 | `IsInside` | M | 1p | `/dev shutter in` em: meio do trailer; atrás do balcão; na porta (meio dentro); calçada sob a aba; em cima do teto | dentro → `true`; calçada → `false`; porta/aba/teto → registrar (L3-20) |
| T130-13 | `IsProtected` | S | 2p | 4 combinações (fechada/aberta × dentro/fora) | `true` só em fechada **e** dentro |
| T130-14 | 4 jogadores | M | 4p | os 4 seguram o botão ao mesmo tempo; depois fechar com 3 dentro e 1 na calçada | uma troca só (cooldown); estado igual nos 4 clients; `IsProtected` = 3 `true`, 1 `false` |
| T130-15 | visão com a janela fechada | S/M | 2p | R23. N6: A dentro, fechada, de frente para `WV`; N7: A olhando a Juniper; N2: A olhando o trilho | N6/N7: `Looking = false` (sem −5, sem contagem, `Step` não sobe); N2 (alvo dentro): `Looking` normal. Abrir: N6/N7 voltam a contar. B na calçada, mesma hora: conta normal |
| T130-16 | estado da party na saída | M | 2p | A fecha e sai do jogo | continua fechada; B abre normalmente; A volta → vê o estado atual (T131-04) |
| T130-17 | dev | M | 1p | `/dev shutter`, `shutter open`, `shutter close`, `shutter in`; e com `IsDev()` falso (cópia local) | dev: funcionam pelo mesmo `SetShutter`; sem dev: comando não existe |
| T130-18 | `InZone(p, "SS", 6)` (era T102-08) | S | 1p | andar até `SS` | falso a 6,5; verdadeiro a 5,5 studs (± 0,3); só `Active`. `anm_010_hush` sem regressão (T117-11..16) |
| T130-19 | `HideService` fora | E | — | `src/Hide/server/**`, `Commands/Hide.luau` | apagados; `AnomalyService` `Require` = `VehicleService`; servidor sobe sem warn de `Require` |
| T130-20 | `Context` e evento | E/S | — | ler `AnomalyService/init`, `Api`; `/dev anomaly anm_008_long_car` com log R16 | `Context.Vehicle` (`IsShutterClosed`/`IsInside`/`IsProtected`), `Context.InZone`; evento `{ Kind = "Shutter", Closed, Player }` chega ao módulo ativo a cada troca; Rules N8/N9 com `Verb = "shutter"`, `CloseWindow` |

Os casos de N8/N9 com a janela (verbo, erro, quem paga) estão em T117-02..05, T117-10 e T117-17..22.

### TASK-131 — Aba da janela no client + prompts de balcão

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T131-01 | aba desce e sobe | M | 2p | PC + Mob | A fecha: a aba gira em ~0,6 s nos 2 clients e **cobre** a janela (de dentro não se vê a rua pela janela; de fora não se vê o balcão); abrir: volta à posição aberta. A aba não atravessa teto nem balcão |
| T131-02 | prompts de balcão somem | M | 2p | ambos | fechada: "Take Order", "Serve", "Refuse" somem nos 2 clients (`SetShutterProbe`); grelha, tábua, interruptor, "Open Window" continuam; ao abrir, voltam |
| T131-03 | botão no celular e no PC | M | 1p | ambos | "Close Window"/"Open Window" com hold 0,5 visível; toque ≥ 44 px no iPhone SE; tecla E no PC; não sobrepõe o prompt do interruptor (T132-01) |
| T131-04 | reconexão com a janela fechada | M | 2p | — | B sai; A fecha; B volta: aba **já** fechada, sem tween, e sem prompts de balcão. B entra no meio do tween → estado final |
| T131-05 | `HideController` e `Hidden` fora | E | — | — | `src/Hide/client/HideController.luau` apagado; `CameraController` sem `Hidden`, `HIDE_DROP`, listener de `Hides`; `PromptController/Rules` sem `SetHideProbe`, regra de `get_up` e de vaga ocupada |
| T131-06 | sem `Shutter_Hinge` | S | 1p | — | cópia local do place sem o attachment: nada gira, 1 warn só (não repete a cada troca), sem erro |
| T131-07 | som placeholder | M | 1p | PC | sem chave em `Sounds` = silêncio, sem warn repetido |
| T131-08 | carrinho e veículo à venda | M | 1p | ambos | carrinho atual: sem aba, prompts de balcão sempre; trailer à venda (`TRL-SALE`) aparece fechado |
| T131-09 | atributo alterado no client não vale | M | 2p | — | Command Bar do client de B: `SetAttribute("Shutter", false)` com a janela fechada → aba abre e prompts aparecem **só em B**; "Take Order" de B é recusado pelo servidor (`Shutter:Closed`); A segue vendo fechada (X3-10) |
| T131-10 | regressão | M | 1–2p | ambos | T014-01..08, T078-01..06, T058-01..05, T019-01..03, T064-01..06 |

### TASK-132 — Binding da janela no MAP-01

| ID | Critério | Tipo | Esperado |
|---|---|---|---|
| T132-01 | botão | S/M | `TRL-SHUTTER` dentro do trailer, ao lado de `TRL-SWITCH`, na altura do interruptor; `Prompt_Shutter` `Interactable`, `PromptAction = "shutter_toggle"`; ≥ 2,5 studs de `Prompt_Switch` e de outros donos; dentro do `Model` do trailer (anda com ele na troca, T130-11) |
| T132-02 | dobradiça | S/M | `Shutter_Hinge` (`Attachment`) na `Awning` do AST-027 **ou** `Shutter_Panel` placeholder (P51); girada, cobre a janela 22,5 × 4,5 (T131-01) |
| T132-03 | esconderijo fora do place | S | nenhum `H1..H4`, `Prompt_Hide`, `Hide_Pose`, `HIDE_*`, `Hide_1..4` no `Workspace` nem em `MAP-01_placements.luau`/`bind_map01.luau` |
| T132-04 | checagem | S | `check_map01` espelha `Required.Wave3` (`shutter_toggle` = 1; `Shutter_Hinge` ausente = aviso; `hide`/`Slot` fora); `Check.run({ wave = 3 })` 0 erro; place salvo e reaberto mantém o binding |
| T132-05 | alcance só de dentro | M | 1p: segurar o botão de dentro do trailer (ok); tentar pela janela aberta e pela porta, da calçada → registrar se o prompt aparece/aceita (L3-17) |

### TASK-133 — Limpeza do contrato do esconderijo

| ID | Critério | Tipo | Jog. | Esperado |
|---|---|---|---|---|
| T133-01 | `Net` sem `Hides` | E/M | 1p, 2p | entrada `Hides` fora de `Net/init.luau`; boot sem erro de `Lync.start()` (G-13) |
| T133-02 | Content sem esconderijo | E/S | — | `Actions.hide`, `Actions.get_up`, `Notices.hide_taken`, `Vehicles.HidePoints`, `Animations.hide` fora; `Animations.get_up` **fica**; `Content.Validate()` passa |
| T133-03 | `safe_spot.Text` | E | — | "Safe Spot"; ação continua sem prompt (X3-11) |
| T133-04 | grep | E | — | G-34 = 0 ocorrência |
| T133-05 | `Slotted` | E/S | — | removido de `MapIndex` só se ficou sem uso; `Validate(Required.Wave3)` segue 0 erro |
| T133-06 | regressão | M | 1–2p | T100-03 (levantar do atropelamento usa `get_up`), T051-01..05, X2-10 (texto novo §9), T129-04 |

### TASK-104 — `TrafficService` + `Motion` + atropelamento

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T104-01 | `Motion` puro | S | — | lune: tabela de casos (sem parada, `StopDist` com `HeldUntil` futuro, `HeldUntil = 0`, arrancada) | posição contínua; para **exatamente** em `StopDist`; arranca com `PullAway` |
| T104-02 | teto de dia | S | 1p | Open (8 AM–6 PM), contar `Traffic` a cada 1 s por 5 min | ≤ 4; intervalo por rota 6–10 s; Juniper Sul 12–20 s por sentido |
| T104-03 | noite (DEC-198) **[P]** | S | 1p | Night 1: 7 PM–9 PM e depois (R6) | ≤ 1 carro de 7 a 9 PM, só TR-1/TR-2; 0 depois das 9 PM |
| T104-04 | PARE 1 s | M | 1p | olhar TR-3/TR-8 no `SL-N`/`SL-S` | para 1 s ± 0,2; Ninth nunca para no cruzamento; 1 carro de braço da Juniper por vez em `X-T` |
| T104-05 | carro × jogador | M | 1p | ficar parado na faixa CW-1 | carro **não** para nem desvia (DEC-133); atropela |
| T104-06 | `ReserveCrossing` | S | 1p | R19 log; cliente atravessando CW-1 | concedida só com nenhum carro a < 15 studs; carros param na linha `SL-1N/1S`; nenhum para dentro da faixa; nova reserva só 4 s depois |
| T104-07 | espera máxima 4 s | S | 1p | NPC parado na pista (forçar pelo Command Bar) | reserva expira em 4 s; `PivotTo` do NPC para o meio-fio (logado); carros arrancam |
| T104-08 | fila | M | 1p | 2 carros atrás de um parado | 2º para a 14 studs; arranca 0,5 s depois do líder |
| T104-09 | `Hold` | S | 1p | `/dev traffic hold anm_008 on` (R19) | nenhum carro nasce; os que existem terminam a rota; `off` volta; 2 motivos ao mesmo tempo: só volta quando os 2 saem |
| T104-10 | `CarHit` válido | M | 2p | A com pacote `Count = 5` na mão é atropelado | `Knock` + `SetKnocked` + `DropHeld(A, "Hit")` + `LifeEvent{Hit}` aos 2; sanidade de A **igual** (DEC-103); pacote no chão com `Count = 5` |
| T104-11 | só a Tool equipada | M | 1p | HotDog equipado + 2 pacotes na hotbar | só o HotDog cai (splat 2 s); pacotes ficam (FEAT-036) |
| T104-12 | item na pista | M | 1p | atropelado no meio da pista | item aparece na calçada mais próxima |
| T104-13 | imunidade 5 s e 1× por carro | M | 1p | ficar na pista depois de levantar | nenhum novo hit por 5 s; o mesmo carro nunca 2× |
| T104-14 | velocidade mínima | M | 1p | encostar num carro parado no PARE / na faixa | sem hit (< 6 studs/s) |
| T104-15 | invalidações | S | 2p | `CarHit` de `Down`, `Spectator`, em cutscene, carro inexistente, carro a 20 studs | todos ignorados sem erro; client se levanta sozinho no fim do tempo local |
| T104-16 | spawn | S | 1p | R19 | só nas pontas `W/E/JN/JS-IN`, ≥ 3 s entre carros da mesma faixa; não nasce com fila na ponta |
| T104-17 | fases sem carro | S | 1p | `NightEnd`, `NightLost`, `Summary` noturno, `Finale`, `RunEnd` | 0 carro (`DensityAt` = nil) |
| T104-18 | `Look` | S | 1p | 50 carros | `Look` 1..20, todos válidos em `LookOf` |
| T104-19 | regressão | M | 1–2p | T066-07..10 (agora pelo caminho real), T062 (sanidade não muda) | ok |

### TASK-105 — `TrafficController`

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T105-01 | sincronia | M | 2p | PC | mesma posição nos 2 clients (≤ 1 stud; medir com marcador no chão e screenshot simultâneo, ou log de posição por `Motion` no mesmo `workspace:GetServerTimeNow()`) |
| T105-02 | lag | M | 2p | — | `IncomingReplicationLag` 0,3: arrancada com mistura ≤ 0,2 s; nunca teleporte > 6 studs |
| T105-03 | `CarHit` só do próprio personagem | E/M | 2p | — | o client testa só o próprio HRP; B não manda hit de A |
| T105-04 | previsão local | M | 1p | ambos | ragdoll local imediato no contato; servidor confirma ou o client se levanta no fim do tempo local |
| T105-05 | LOD | M | 1p | PC | carro longe sem pop perceptível perto do jogador |
| T105-06 | 60 FPS | M | 1p | Mob (+📱real) | 4 carros + 8 passantes de dia na esquina: ≥ 60 no aparelho de referência; ≥ 30 no emulador |
| T105-07 | reconexão | M | 2p | — | B entra com 3 carros na rua e vê os 3 na posição certa |
| T105-08 | estilo (DEC-023) | M | 1p | ambos | estrelinhas/"boing", sem som de impacto realista |

### TASK-106 — `AnomalyService` núcleo

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T106-01 | `Scheduler` determinístico | S | — | lune: `Build(k, attempt, rng)` 2× com a mesma semente; e com `Attempt` diferente | agendas iguais; `Attempt` muda a agenda |
| T106-02 | ocorrências por idade | S | — | lune, Nights 1..10 | estreia 3, 1–2 noites depois 2, 3+ noites depois 1. Night 7 = 11 ocorrências; Night 10 = 14 (6 antigas + N7 1 + N8 2 + N9 2 + N10 3, sendo a 3ª da N10 roteirizada; ver L3-02 sobre a N7) |
| T106-03 | janela e 1º terço | S | — | lune, 200 sementes | nenhuma ocorrência não roteirizada fora de 9 PM–5 AM (L3-01); 1ª da estreia entre 9:00 PM e 11:40 PM |
| T106-04 | `MinGap` e simultâneas | S | — | lune | inícios separados por ≥ 60/60/60/60/40/40/40/25/25/25 s; simultâneas ≤ 1/1/1/2/2/2/2/3/3/3 |
| T106-05 | exclusões e atores | S | — | lune + R17 | N10 × N3/N8/N9 e N5 × N8/N9/N10 nunca ao mesmo tempo; soma de `NpcCost` ativo ≤ 3 |
| T106-06 | `Gaze` validado | S | 2p | R23 | só aceita de noite, `Active`; `Looking` falso para protegido (janela fechada e dentro) com alvo fora do trailer (T130-15); `Looking` = cone 40° (20° de cada lado) + alcance + raycast; parede no meio → falso |
| T106-07 | "ver" −5 | M | 2p | A olha um ator por 1 s acumulado (0,5 + 0,5) | A −5 uma vez; olhar de novo na mesma noite: nada; B que não olhou: nada |
| T106-08 | quem paga (DEC-204) | M | 2p | ver N1 (ação), N5 (omissão), N6 (pessoal) | ação → quem agiu; omissão em alvo party → todos os ativos; pessoal → cada um que falhou |
| T106-09 | ativo | M | 3p | A `Active`, B `Down`, C desconectado; omissão de party | só A paga; B e C nunca (FEAT-023, FEAT-025) |
| T106-10 | 1 falha por jogador por ocorrência | S | 1p | N1: Take Order 2× no mesmo ator (forjado) | −35 uma vez |
| T106-11 | só ANM-007 crítica | S/E | 1p | `Fail` em cada uma das 10 (R15) | −35 nas 9 comuns; só a N7 chama `LoseNight("critical")` |
| T106-12 | `Stop` | S | 1p | ocorrência ativa no `NightEnd`; ocorrência ativa no `NightLost` | `Stop(NightOver)` / `Stop(Restore)`; `Anomalies` vazio; nenhum efeito sobra no client |
| T106-13 | agenda recalculada | S | 1p | perder a noite | noite repetida com `Attempt = 1` e agenda nova (R17); nada de agenda no snapshot |
| T106-14 | `Tension` | S | 1p | N7 ativa (R15) | sinal `Tension(true)` enquanto dura; `false` ao acabar; N1 não liga **[P]** |
| T106-15 | sem módulo | S | 1p | pasta `Anomalies/` vazia (cópia local) | servidor sobe; noite roda sem erro; agenda só com o que existe |
| T106-16 | `Start` falso | S | 1p | N1 com balcão cheio | a agenda tenta de novo; não perde a ocorrência nem trava |
| T106-17 | dev | M | 1p | `/dev anomaly anm_001_blank_folks` de dia; à noite | de dia recusa com mensagem; à noite começa pelo mesmo caminho da agenda |

### TASK-107 — `AnomalyController` núcleo

| ID | Critério | Tipo | Jog. | Esperado |
|---|---|---|---|---|
| T107-01 | descobre `Effects/*` | S | 1p | um efeito de teste numa cópia local é ligado sem editar o `init` |
| T107-02 | set + cue | S | 1p | `Anomalies` (Phase) e `AnomalyCue` chegam ao efeito certo com `Entity`/`Seed` |
| T107-03 | reconexão | M | 2p | B entra no meio da N6 (janela acesa) e da N7 (passo 4): vê o estado; cue perdido não quebra nada |
| T107-04 | sem efeito | S | 1p | anomalia sem `Effects/<Ref>` | nada acontece, sem erro nem warn repetido |
| T107-05 | limpeza | M | 1p | `NightEnd` e `NightLost` | todo efeito some (sem névoa, janela, Walker ou carro sobrando) |

### TASK-108 — Ganchos de cliente + `NpcService` `Actor`/`SetTension`

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T108-01 | `SpawnActor` | S | 1p | `Spawn({ Variant = "blank" })` | NPC com `Role = "Actor"`, `Variant`; ocupa vaga; conta no teto de 12 |
| T108-02 | sem `CountArrival` | S | 1p | ator recusado | `Arrived` igual; `Refused` não conta como insatisfeito (DEC-051) |
| T108-03 | `AddServeRule` | S | 1p | regra de teste que devolve `Wrong` | `Sale` com `Wrong`, sem pagamento; regra chamada antes do cálculo de preço |
| T108-04 | teto à noite | S | 1p | N1 com 6 clientes no balcão | ver L3-10 (ator dentro ou fora dos 6); registrar o que acontece |
| T108-05 | variantes | M | 2p | `blank`, `mirror`, `raincoat` | B vê as 3 variantes (TASK-110) |
| T108-06 | `SetTension` **[P]** | M | 2p | R26 | clientes normais trocam para o pack Night; voltam ao Mid no `off` (DEC-181) |
| T108-07 | regressão | M | 1p | T031-01..06, T032-01..08, T033-01..20, T053-01..07, T072-03/11 | ok |

### TASK-109 — Ganchos de cozinha: item alterado

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T109-01 | `Alter("rail")` | S | 1p | R22 | salsicha cinza **na próxima posição a ser usada** do trilho; `Stations[rail].Altered` = posição |
| T109-02 | `Alter("board")` | S | 1p | R22 | pão mordido já cortado numa vaga livre da tábua; `Altered = 1` na vaga |
| T109-03 | sem lugar | S | 1p | trilho cheio / tábua cheia | `Alter` devolve `false`; nada muda |
| T109-04 | montado leva `Altered` | M | 1p | `board_add_sausage` com a salsicha alterada | HotDog com atributo `Altered = true` |
| T109-05 | `Discarded` | S | 1p | ouvir; descartar HotDog normal e alterado; `altered_item` sozinho | `(p, item, false)`, `(p, item, true)`, `(p, "altered_item", true)` |
| T109-06 | `Context.Emit` | S | 1p | N2 ativa | evento `Discard` chega ao módulo |
| T109-07 | snapshot | M | 1p | perder a noite com item alterado no trilho | restauração sem alterado (snapshot do início da Prep) |
| T109-08 | regressão | M | 1p | T025-01..10, T026-01..08, T027-01..06, T028-01..09, T057-01..07, T068-01..08, T080-01..04 | ok |

### TASK-110 — Client: comida alterada, `Variant`, rigs locais

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T110-01 | AST-061 na vaga | M | 2p | ambos | os 2 veem a salsicha cinza / pão mordido; HotDog alterado mostra o sinal na mão (`npcs.md` N2) |
| T110-02 | `Variant` | M | 2p | ambos | `blank` sem rosto e sem respiração; `mirror` com acessório/texto no lado oposto; `raincoat` capa amarela |
| T110-03 | rig local tagueado | M | 2p | PC | passante local e cliente na faixa < 40 vestidos pelo `RigController` com o Night só no client do dono (DEC-169) |
| T110-04 | regressão | M | 1p | ambos | T029, T030, T034, T037, T069, T079 |

### TASK-111 — N1, N4, N5 (servidor) · TASK-112 — efeitos (client)

Pré: noite k ≥ estreia, `/dev clock 9:30 PM`, `/dev anomaly <key>`. Jogadores A e B ativos no trailer.

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T111-01 | N1 sinal | M | 2p | ator chega a Q1 | rosto liso, sem respiração, balão **vazio**; cliente normal ao lado mantém rosto (Q-147 **[P]**) |
| T111-02 | N1 ver | M | 2p | A olha 1 s | A −5 (1×/noite); B que olhou também −5; quem não olhou: nada |
| T111-03 | N1 verbo certo | M | 2p | A "Refuse" (hold 1 s) | ator vira e vai embora devagar; `Succeed`; ninguém −35; `Arrived`/insatisfeitos iguais |
| T111-04 | N1 erro | M | 2p | B "Take Order" no ator | B −35 (só B); `CountArrival` + `Wrong`; cue `blank_coin` (moeda $0 visual na gaveta, some no resumo; `npcs.md`); `Drawer` não muda |
| T111-05 | N1 omissão | M | 2p | ninguém age | paciência acaba; ninguém perde sanidade; vaga liberada |
| T111-06 | N4 sinal | M | 2p | — | original e cópia com ≤ 10 s de diferença; cópia espelhada (texto da roupa invertido); exige 2 vagas livres, senão espera |
| T111-07 | N4 certo / erro | M | 2p | A recusa a cópia; outra ocorrência: B "Take Order" na cópia | `Succeed`; B −35 + `mirror_smile` |
| T111-08 | N4 recusar o original | M | 2p | — | sem −35; conta como insatisfeito (cliente normal) |
| T111-09 | N5 sinal | M | 2p | — | capa amarela, olhos fechados, pinga e deixa poça (`raincoat_drip`); rosto completo |
| T111-10 | N5 certo | M | 2p | atender e servir completo; outra: servir incompleto | `Succeed` nos 2 (incompleto paga floor 50%, sem "Thank you, dear."); **sem +$1** (DEC-195) |
| T111-11 | N5 entrega errada | M | 2p | servir HotDog sem o pedido | devolve e continua esperando (`wrongServeRetry`) |
| T111-12 | N5 erro por ação | M | 2p | B "Refuse" | B −35, só B |
| T111-13 | N5 omissão | M | 3p | ninguém atende; C `Down` | A e B −35; C nada |
| T111-14 | exclusão N4 × N1 | S | 1p | N1 e N4 juntas | nunca no mesmo cliente |
| T112-01 | efeitos não apontam o alvo (§4.4) | M | 2p | ambos | nenhum contorno, seta ou VFX que identifique o ator; só o traço da ficha |
| T112-02 | placeholders | E | — | — | troca para AST-059/060/062/082 (124/125) sem mudar código |

### TASK-113 — N2, N3 (servidor) · TASK-114 — efeitos

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T113-01 | N2 sinal | M | 2p | `/dev anomaly anm_002_wrong_food` | item alterado no trilho **ou** na tábua; chiado curto ao surgir |
| T113-02 | N2 certo | M | 2p | A pega ("Take", hold 0,5) e "Throw Away"; outra: monta o HotDog com ele e descarta o HotDog | `Succeed` nos 2 casos |
| T113-03 | N2 erro | M | 2p | B serve o HotDog alterado | `Wrong`, sem pagamento, cue `smoke`; B −35 (só B) |
| T113-04 | N2 omissão | M | 1p | ninguém mexe | sem falha; item some às 6:00 AM |
| T113-05 | N2 item no chão | M | 1p | A com `altered_item` na mão é atropelado (R20) | item some na hora; ocorrência fecha sem sucesso nem falha (FEAT-036; L3-09) |
| T113-06 | N2 na lixeira de rua | M | 1p | descartar `altered_item` no `StreetBin` | `Succeed` (`Q-166` **[P]**) |
| T113-07 | N3 sinal | M | 2p | — | ponteiros do relógio do banco param, tique-taque some (`clock_stop`); relógio do HUD **continua** (DEC-195) |
| T113-08 | N3 certo | M | 2p | A desliga, 5 s, religa dentro de 60 s; repetir **com e sem** UPG-005 | `Succeed`; `clock_resume` |
| T113-09 | N3 religar com 4 s | M | 1p | desliga 4 s, religa; depois desliga 5 s, religa | 1ª não falha nem conta; 2ª `Succeed` |
| T113-10 | N3 omissão | M | 3p | ninguém mexe 60 s; C `Down` | A e B −35; C nada |
| T113-11 | N3 escuro | M | 1p | 5 s no escuro | ~2 de sanidade (3 s de atraso + −1/s) |
| T113-12 | N3 já desligado | M | 1p | luz já desligada há 10 s quando o relógio para | ver L3-11; registrar |
| T113-13 | N3 cooldown do interruptor | M | 1p | desligar e religar em 0,3 s | 2ª troca ignorada (T059-06); contagem coerente |
| T114-01 | fumaça ao morder | M | 2p | ambos | `smoke` 2 s, visto pelos 2; cliente vai embora |
| T114-02 | relógio para | M | 2p | ambos | ponteiros param nos 2 clients; quem reconecta vê parado |

### TASK-115 — N6, N7 (servidor) · TASK-116 — efeitos

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T115-01 | N6 sinal | M | 2p | — | som `curtain` **antes** da silhueta; janela `WV` acende; sinal para todos (DEC-204) |
| T115-02 | N6 relance | M | 1p | olhar 1 s e desviar | −5 só; sem falha |
| T115-03 | N6 limite 3 s | M | 2p | A olha 2,9 s contínuos e desvia; B olha 3,0 s | A só −5; B −35 + `waver_more` (+2 janelas, 2 mãos, 5 s); só B |
| T115-04 | N6 contínuo | M | 1p | 2 s + desvia 0,5 s + 2 s | sem falha (contagem zera ao desviar) |
| T115-05 | N6 `AutoOff` | M | 1p | ninguém olha | apaga sozinha em 20 s ± 0,5 |
| T115-06 | N6 com a janela fechada (DEC-221) | M | 2p | A dentro do trailer com a janela fechada, de frente para `WV` por 4 s; B na calçada olhando 3 s | A não "vê" nem falha; B −5 e −35 normal (protegido é só quem está dentro) |
| T115-07 | N7 sinal | M | 2p | — | `post_buzz` ~2 s no último poste, para seco; ouvido pelos 2 (DEC-123) |
| T115-08 | N7 avanço | M | 2p | A olha 3 s | `Step` 0 → 3; `post_flicker` + `walker_step` a cada passo |
| T115-09 | N7 tempo da party | M | 4p | os 4 olham juntos 3 s | `Step` 3 (no máx. 1 passo/s, não 4) |
| T115-10 | N7 recuo | M | 1p | `Step` 4, ninguém olha 40 s | volta a 0 (1 a cada 10 s) |
| T115-11 | N7 crítica | M | 2p | olhar até 10 | `LoseNight("critical")` em ≤ 3 s, **sem** janela de 10 s; com chance: `call_lost_critical` + `call_lost_last_chance` e repetição; sem chance: fim de run |
| T115-12 | N7 janela fechada / `Down` / espectador | M | 3p | B dentro do trailer com a janela fechada olhando a Juniper; C `Spectator` assistindo A (A não olha) | `Step` não sobe (custo aceito: venda parada, `Q-173` e) |
| T115-13 | N7 fim da ocorrência | M | 1p | `Step` 3, esperar 45 s | Walker recua para o escuro e some; próxima ocorrência começa do 0 |
| T115-14 | N7 depois do veredito | S | 1p | `Step` 9 às 5:59 AM, olhar até 6:00 | `NightEnd` vence; nenhum `LoseNight` depois do `Verdict` (só vale em Call/Prep/Night) |
| T115-15 | N7 nas Nights 1–6 | S | 1p | R15 forçado na Night 3 | recusado (não ativa antes da 7); nenhuma noite 1–6 termina por crítica |
| T116-01 | janelas `WV` | M | 2p | ambos | acesas nos 2; quem reconecta vê |
| T116-02 | Walker no poste do `Step` | M | 2p | ambos | figura sob o poste certo (`StreetLight.Order`); quem reconecta vê o passo |
| T116-03 | Walker legível no celular | M | 1p | Mob | a 300 studs a figura é visível como silhueta (não some no LOD) |
| T116-04 | Walker não lembra espécie | E | — | — | placeholder neutro (124) |

### TASK-117 — N8, N9, N10 (servidor) · TASK-118 — efeitos

| ID | Critério | Tipo | Jog. | Passos | Esperado |
|---|---|---|---|---|---|
| T117-01 | N8 sinal | M | 2p | depois das 9 PM | trânsito parado (`Hold("anm_008")`); long car estaciona no meio-fio oposto; farol alto 2 s depois (`car_highbeam`) |
| T117-02 | N8 certo (DEC-221) | M | 2p | A e B dentro do trailer; A fecha a janela até 8 s depois do farol; ninguém abre até o carro sair (`StayFor` 15 s) | nada perdido; `Resolved`; janela pode ser aberta depois que o carro foi embora sem custo |
| T117-03 | N8 erro (não protegido) | M | 2p | (a) janela fechada a tempo, B na calçada dentro de 24 studs do `TRL`; (b) ninguém fecha | no `car_flash` (fim dos 8 s) + `trailer_blackout` 3 s + `car_honk`: (a) só B −35; (b) A e B −35 (cada um, alvo pessoal) |
| T117-04 | N8 abrir antes de o carro ir embora | M | 2p | fechada a tempo, A e B dentro; A abre aos 10 s (antes do fim do `StayFor`); outra rodada: A abre e fecha de novo (1,1 s) | **só A** −35 (quem abriu, DEC-204); B nada. Reabrir/refechar não cobra 2× (1 falha por jogador por ocorrência, T106-10) |
| T117-05 | N8 fora da zona | M | 2p | B no Mart; outra: B a 23 e a 25 studs do `TRL`, fora do trailer | Mart e 25: B não é testado; 23: B −35 (raio 24 **[P]**, §19.14; fecha L3-03/L3-15 se bater) |
| T117-06 | N8 blackout não drena | M | 1p | — | 3 s de luz apagada sem perda de escuro |
| T117-07 | N8 não atropela | M | 1p | ficar na frente do long car | sem `CarHit` (não é carro de trânsito) |
| T117-08 | N9 sinal | M | 2p | — | 3 batidas, pausa, 3 batidas (~12 s); legenda "???: Rookie? It's me. It's Walt. Open up." (nunca "Walt:") |
| T117-09 | N9 ver por zona | M | 2p | A no trailer, B no Mart na 1ª batida | A −5; B nada (`AudioZone`) |
| T117-10 | N9 certo / erro (DEC-221) | M | 2p | janela fechada no fim dos 12 s; A dentro; B sai e fica na porta (fora) | A nada; B −35 + `door_crack`; a porta não tem prompt |
| T117-11 | N10 sinal | M | 2p | — | postes da Juniper apagam um a um em 15 s (`Step` = apagados); névoa (`hush_fog`); `Hold("anm_010")`; LZ do trailer apagam quando o da esquina apaga; interruptor sem efeito |
| T117-12 | N10 certo | M | 4p | os 4 no `SS` (raio 6) quando o da esquina apaga e até os postes voltarem (20 s) | nada perdido; área conta como luz (sem dreno) |
| T117-13 | N10 erro | M | 2p | B chega depois do último poste; outra: A sai aos 10 s | B −35; A −35 |
| T117-14 | N10 dentro do Mart | M | 1p | dentro da loja, fora do raio 6 | ver L3-12; registrar |
| T117-15 | N10 roteirizada | M | 2p | Night 10, `/dev clock 5:44 AM` | às 5:45 AM Hush + Walker sob o último poste; Walker não avança sem olhar; 6:00 AM vence → `Finale` |
| T117-16 | exclusões | S | 1p | R15 N3/N8/N9 durante um Hush | não começam (`npcs.md` aceite N10) |
| T117-17 | N9 só o fim conta | M | 2p | (a) janela aberta até 11 s e fechada antes dos 12 s, A e B dentro; (b) fechada desde a 1ª batida e aberta aos 11,5 s; (c) fechar e abrir no meio, fechada no fim | (a) nada; (b) A e B −35 (abertura no fim = não protegidos; N9 não cobra "quem abriu", só o estado no fim); (c) nada |
| T117-18 | N8/N9 com a janela já fechada antes do sinal | M | 1p | fechar às 9:29 PM e `/dev anomaly anm_008_long_car` / `anm_009_knock` | conta como protegido; nada perdido |
| T117-19 | N8/N9 vigiado sai do trailer | M | 2p | N8 fechada a tempo, B sai pela porta aos 10 s (carro ainda lá); N9: B sai aos 6 s e volta aos 10 s | N8: B −35 (tick 5 Hz), A nada; N9: B nada (só o fim é medido) |
| T117-20 | N8/N9 com 4 jogadores | M | 4p | N8: A, B, C dentro e D na calçada; janela fechada a tempo; C abre aos 12 s | D −35 no prazo; C −35 ao abrir; A e B nada. N9: os 4 dentro com a janela fechada → nada |
| T117-21 | falas do chefe | E/M | 1p | ler `BossCalls.luau` e ouvir a `Call` da Night 8/9 | N8: "…close the service window. Stay inside." / "Long car? Close the window. Keep it shut."; N9: "…Close the window. Stay inside." / "Knocking? It's not me. Close the window."; nenhuma fala com "get down behind the counter"/"Hide" (`Q-173` d; commit 05a074e) |
| T117-22 | balcão durante N8/N9 | M | 2p | 3 clientes na fila; fechar para a N8 | prompts de balcão somem (T131-02); paciência corre; quem esgota vai embora (T130-08). Registrar quantos clientes se perdem por ocorrência (L3-21) |
| T118-01 | farol alto | M | 2p | ambos | cone de luz no trailer nos 2; sem luz real (Beam) |
| T118-02 | porta `Ajar` + guardanapos | M | 2p | ambos | 3 s; fecha sozinha |
| T118-03 | névoa + `Atmosphere` | M | 1p | Mob | volta ao preset no fim; ≥ 60 FPS no aparelho de referência |

### TASK-119 — Alucinações

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T119-01 | faixas | S | 1p | — | `/dev sanity 70`: nenhuma; 55: só `fake_call`/`grill_hiss`; 35: + 3 de < 40; 15: as 8 |
| T119-02 | intervalo e cooldown **[P]** | S | 1p | — | 10 min em 15: intervalos 20–45 s; mesmo efeito nunca antes do `Cooldown` |
| T119-03 | só local | M | 2p | PC | A em 15 vê/ouve; B nada; nenhum packet nem set muda (G-24) |
| T119-04 | nunca prompt | M | 1p | ambos | `ghost_customer` sem "Take Order"/"Refuse"; não entra em `Customers`; some no 2º olhar |
| T119-05 | poste sem zumbido | M | 1p | PC | `post_flicker` pisca **sem** `post_buzz` (DEC-123) |
| T119-06 | não conta como anomalia | S | 1p | — | olhar a alucinação do poste: `Step` do Walker igual; nenhum −5 (R16) |
| T119-07 | `fake_call` | M | 1p | ambos | "Walt: ..." local; telefone sem prompt; `Call` set igual |
| T119-08 | só à noite | S | 1p | — | dia: nenhuma |
| T119-09 | `Down`/`Spectator` | M | 2p | — | A `Down` (sanidade 0): ver L3-04; registrar |
| T119-10 | jumpscare leve (DEC-173) | M | 1p | ambos | sem tremor, sem som acima do ambiente |

### TASK-120 — `CutsceneService` · TASK-121 — `CutsceneController`

| ID | Critério | Tipo | Jog. | Plat. | Passos | Esperado |
|---|---|---|---|---|---|---|
| T120-01 | intro por probe | M | 2p | ambos | run nova | `Intro` toca `intro`; `Freeze("Cutscene")`; avatares nas `CutsceneMark1..4`; `MoveTo` nos beats; Day 1 ≤ 50 s depois do início |
| T120-02 | voto 1p | M | 1p | ambos | hold 1 s em "Skip" | pula na hora |
| T120-03 | voto 2p **[P]** | M | 2p | — | A vota | `Needed = 1`; pula para os 2 ao mesmo tempo |
| T120-04 | voto 4p | M | 4p | — | 1 voto; depois 2 | 1 não pula ("Skip (1/2)"); 2 pulam |
| T120-05 | limiar recalculado | M | 3p | — | 1 voto (1/2); C sai | `Needed` cai para 1 sem reiniciar → pula |
| T120-06 | voto não se desfaz e conta 1× | S | 2p | — | A manda `SkipVote` 5× | `Votes = 1` |
| T120-07 | voto por segmento | M | 2p | — | `finale` pulado | `credits` começa com 0 votos |
| T120-08 | atrasado | M | 3p | — | C entra no meio da intro | C não vê a intro, não vota, spawna no trabalho no fim (DEC-205) |
| T120-09 | `Cap` | S | 1p | — | travar um beat (cópia local) | servidor encerra em 50/60/75 s |
| T120-10 | trânsito parado | S | 1p | — | intro / finale | `Hold("cutscene")`; 0 carro; `CarHit` ignorado |
| T120-11 | final | M | 2p | ambos | `/dev night 10` + `/dev win` | +33 +100 creditadas **antes**; `finale` → `credits` → tela "You Kept the Light On" 15 s → `RunEnd(Success)` |
| T120-12 | espectador vota **[P]** | M | 2p | — | B `Spectator` na vitória da Night 10 | B está na cena e vota |
| T120-13 | nada mais oferece Skip | M | 1p | ambos | fade da troca, `NightLost`, ligações | sem "Skip" (FEAT-004) |
| T121-01 | atores locais | M | 2p | PC | Walt, Raincoat Lady, carrinhos, telefone, panfleto: locais, animados pelo `AnimController` |
| T121-02 | Solo × Party | M | 1p/2p | ambos | linhas `Variant = Solo` com 1 jogador; `Party` com 2+ |
| T121-03 | legenda | M | 2p | Mob | ≥ 14 px no iPhone SE; mesma linha nos 2 (≤ 0,5 s) |
| T121-04 | botão Skip no celular | M | 1p | Mob | hold 1 s no botão; contador "Skip (1/2)" não cobre a legenda |
| T121-05 | reconexão | M | 2p | — | B (participante) sai e volta no meio: entra no ponto atual, no trilho |
| T121-06 | intro sem sobrenatural | M | 1p | — | nenhum elemento de anomalia (FEAT-004) |

### TASK-122 — `PedestrianService` · TASK-123 — `PedestrianController`

| ID | Critério | Tipo | Jog. | Plat. | Esperado |
|---|---|---|---|---|---|
| T122-01 | quantidade | S | 1p | — | dia 6–8; noite 1–2; contar `Pedestrians` a cada 5 s por 5 min |
| T122-02 | tensão | S | 1p | — | R26 / N7 ativa: 0 passantes (os que existem saem da tela ou somem fora de vista); `off` volta |
| T122-03 | `ReserveCrossing` | S | 1p | — | passante pede reserva em toda faixa (R19 log); nunca na pista sem reserva |
| T122-04 | fora do teto de 12 **[P]** | S | 1p | — | 8 passantes + 8 clientes + ladrão: Humanoids do servidor ≤ 12 e passantes não contam |
| T122-05 | `WalkPaths` vazia | S | 1p | — | antes da 098: 0 passante, sem erro |
| T122-06 | registros por travessia | S | 1p | — | ≤ 3 registros por passante por travessia; ≤ ~4/min |
| T122-07 | espécie e roupa | S | 1p | — | só espécies com `Pedestrian = true`; roupa civil (DEC-188) |
| T122-08 | `Walker` com reserva | M | 1p | — | cliente que vem pela calçada cruza CW-1 com reserva (antes: sem) |
| T123-01 | rig local vestido | M | 2p | PC | `CrewRig.Build` local com tag; `RigController` veste; faixa < 40 de A: A vê Night, B não |
| T123-02 | anda por `Motion` | M | 2p | — | mesma posição nos 2 clients (≤ 1 stud) |
| T123-03 | LOD > 120 | M | 1p | PC | some além de 120 studs; volta sem pop perto |
| T123-04 | sem colisão | M | 1p | ambos | jogador atravessa o passante; carro nunca o atinge |
| T123-05 | sem prompt | M | 1p | ambos | passante não tem "Take Order" |

> TASK-124 a TASK-126 (assets dependentes de DEC) não têm caso aqui: validam pelo `check()` do kit e pela troca do
> placeholder **sem mudar código** (T112-02, T116-04, T118-03). A TASK-128 só confere a troca se a entrega chegar antes.

---

## 3. Client mal-intencionado (pacotes forjados, onda 3)

Mesmo método das ondas 1–2. Esperado comum: descarte **sem erro** no Output, estado igual, nenhum `Notice` falso a
outros jogadores (`Notice` D-04 ao próprio autor é permitido).

| ID | Pacote / ação | Esperado |
|---|---|---|
| X3-01 | `Gaze` de dia, de `Down`/`Spectator`, em cutscene; `Gaze` "olhando a `WV`" de protegido (janela fechada, dentro) | ignorado / `Looking` falso; `Step`/−5/N6 iguais |
| X3-02 | `Gaze` a 100 Hz | só o último por janela (`:newest(10)`); servidor estável; contagem do N6/N7 igual à de 10 Hz |
| X3-03 | `Gaze` falso "olhando para o chão" o tempo todo | aceito (co-op, R10: só prejudica a si; sem plausibilidade além do formato) |
| X3-04 | `CarHit` com carro inexistente, carro longe, durante imunidade, durante cutscene, de `Down` | ignorado; nenhum `Knock` |
| X3-05 | `CarHit` em nome de outro jogador | impossível pelo schema (só `Car`); vale o personagem do remetente |
| X3-06 | `CarHit` 20× no mesmo carro | 1 `Knock` (imunidade + 1× por carro) |
| X3-07 | `SkipVote` sem cutscene, de atrasado fora da cena, 5× do mesmo jogador | ignorado / ignorado / conta 1 |
| X3-08 | `shutter_toggle` de dia, a 30 studs, de `Down`/`Spectator`, dentro do cooldown, com `EntityId` de outra âncora | recusado (`NightOnly` / raio / `Active` / cooldown / âncora); `Shutter` igual (T130-03..06) |
| X3-09 | `take_order`/`serve`/`refuse` com a janela fechada (também de quem está fora do trailer, na calçada) | `Rejected(... "Shutter:Closed")`; `Notice shutter_closed` só ao autor, ≤ 1 a cada 2 s (T130-07/09) |
| X3-10 | client muda o atributo `Shutter` local ou apaga a aba local | só local; prompts de balcão aparecem só nele e o servidor recusa; N8/N9 usam o estado do servidor (T131-09) |
| X3-19 | `hide`/`get_up` forjados depois da 130 (antes e depois da 133) | descartado sem erro (sem dono até a 133; ação inexistente depois) |
| X3-20 | `shutter_toggle` 20× em 1 s por 2 clients | no máx. 1 troca por s; servidor estável; nenhum −35 de N8 para quem não teve a troca aceita |
| X3-11 | `safe_spot` forjado | descartado (sem prompt; a regra é `InZone`) |
| X3-12 | `serve` com HotDog alterado sabendo do atributo | servidor lê o atributo da Tool do servidor; `Wrong` + falha de quem serviu |
| X3-13 | `discard` de `altered_item` que não está na mão | recusado |
| X3-14 | client tenta disparar `AnomalyCue` | sem handler no servidor; nada muda |
| X3-15 | client muda local `Anomalies`, atributo `Shutter`, posição do Walker ou do long car | só local; servidor e outros clients iguais |
| X3-16 | client apaga a própria névoa / janela / Walker local | só local; a regra do servidor não muda (o cone usa a âncora do servidor) |
| X3-17 | teleporte para dentro do `SS` | aceito (posição é do client; anti-teleporte fora do escopo, como X-19/X2-16) |
| X3-18 | `take_order`/`refuse` em ator com `Variant` | mesmos caminhos do cliente normal; as regras do módulo valem |

---

## 4. Jogador sai no meio (onda 3)

| ID | Situação | Jog. | Esperado (fonte) |
|---|---|---|---|
| Q3-01 | quem fechou a janela sai | 2p | janela segue fechada (estado da party); B abre/fecha normal; ao voltar vê fechada, sem tween (T130-16, T131-04) |
| Q3-13 | N8: quem fechou sai durante o `StayFor`; depois B abre | 2p | desconectado não paga; B −35 (quem abriu) |
| Q3-14 | N8/N9: jogador protegido sai antes do prazo e volta depois do prazo | 2p | não é testado no prazo (não estava conectado); ao voltar, nascendo fora do trailer, não paga retroativo |
| Q3-15 | todos saem com a janela fechada e um volta na mesma noite | 2p | registrar o estado (fica fechada até o próximo `ShiftStarted`/`NightLost`; T130-10) |
| Q3-02 | quem tocou "Take Order" no N1 sai antes de servir | 2p | falha já cobrada; ninguém mais paga |
| Q3-03 | sai durante a omissão de N3/N5 | 2p | desconectado não paga (FEAT-023) |
| Q3-04 | sai depois de olhar o Walker | 2p | passos dados ficam; quem volta vê o `Step` (T116-02) |
| Q3-05 | sai e volta durante o long car / Hush | 2p | vê o carro estacionado / os postes apagados pelo `StartedAt`; volta fora da zona → testado no prazo como qualquer um (registrar) |
| Q3-06 | sai durante a cutscene | 3p | `Needed` recalculado; voto dele sai (T120-05) |
| Q3-07 | atrasado durante a intro | 3p | espera e spawna no fim (T120-08) |
| Q3-08 | sai em ragdoll | 2p | volta de pé, sem constraint ligado |
| Q3-09 | sai com `altered_item` na mão | 2p | ver L3-13; registrar se volta com o item |
| Q3-10 | sai com item derrubado no chão | 2p | item continua para a party; some em 60 s |
| Q3-11 | último `Active` sai com N7 em `Step` 9 | 2p | sem ninguém olhando, recua; janela de 10 s da onda 2 (Q2-04) |
| Q3-12 | todos saem durante o `finale` | 2p | servidor fecha sem erro (`BindToClose`) |

---

## 5. Saldo e economia (onda 3)

| ID | Onde | Esperado |
|---|---|---|
| $3-01 | N1 servido | moeda $0 visual; `Drawer` e `ShiftReport` sem o valor (`npcs.md` N1) |
| $3-02 | N2 servido | `Wrong`, sem pagamento |
| $3-03 | N5 servida rápido | **sem** +$1 (DEC-195) |
| $3-04 | pacote derrubado e perdido (60 s) | dinheiro não volta; estoque não muda |
| $3-05 | noite perdida por crítica | `Cash`, estoque e níveis voltam ao snapshot (FEAT-026) |

---

## 6. Desempenho e orçamento (§19.23, `network.md` §13.12)

Pior caso: noite, 4 jogadores, Walker e Hush ativos (Night 10 às 5:45 AM). Medir com Stats → Network (por client) e
MicroProfiler (servidor).

| ID | Medida | Jog. | Esperado |
|---|---|---|---|
| P3-01 | replicação Lync por client | 4p | meta < 0,5 KB/s (`network.md` §13.12); **falha** ≥ 1,5 KB/s (§19.23, aceite da 128). Entre 0,5 e 1,5: registrar e abrir nota ao architect (L3-05) |
| P3-02 | por fonte | 4p | `Anomalies`+`AnomalyCue` < 40 B/s (Walker ≤ 2 eventos/s); `Traffic`+`Pedestrians` < 50; atributo `Shutter` ≤ 1 troca/s (cooldown); `Lights`/`Call`/`Thief`/`Transition` < 15; `Vitals`/`Sanity`/`LifeEvent` < 40 |
| P3-03 | `Gaze` c → s | 4p | ~60 B/s por jogador (10 Hz × ~6 B) |
| P3-04 | custo de servidor | 4p | visão 5 Hz × 4, Walker 5 Hz, trânsito + passantes 10 Hz, A* ≤ 2/frame: sem pico no MicroProfiler |
| P3-05 | Humanoids no servidor | 2p | ≤ 12 (clientes 6 à noite + atores ≤ 3 + ladrão 0); carros, passantes, Walker, long car, Opal e Walt fora |
| P3-06 | atores de anomalia | 1p | ≤ 3 por `NpcCost` (R15 forçando 4) |
| P3-07 | FPS | Mob +📱real | dia: 4 carros + 8 passantes; noite: Hush + névoa + Walker: 60 no aparelho de referência, ≥ 30 no emulador |
| P3-08 | memória N1 → N10 | 1p | com `/dev`: sem crescimento contínuo (efeitos, rigs locais, carros, passantes, sons) |
| P3-09 | snapshot | 4p | ≤ 2 KB (R10); nada de agenda nem de `Anomalies` no snapshot |

---

## 7. Matriz de plataforma (DEC-171)

Mínimo no **mobile** (emulador iPhone SE; 📱real se publicado): T101-02 (olhar ±60° pelo toque), T131-03 ("Close
Window"/"Open Window" ≥ 44 px, hold 0,5 no toque), T131-01/02 (aba e prompts de balcão no celular), T105-04/06, T111-01/06/09 (sinais legíveis em tela pequena: texto invertido da
N4), T113-07, T115-01/07 (sinais sonoros com legenda/indicador se houver), T116-03, T117-08 (legenda "???"), T118-03,
T120-02 e T121-03/04 (Skip e legenda), T123-03. Party de 2: A no PC, B no mobile no roteiro §8. Console: fora.

---

## 8. Roteiro integrado N1 → N10 (base da TASK-128)

Rodar **party de 2 (PC + mobile)** inteiro; **solo (PC)** dos passos 1, 2, 3, 5, 9, 12 e 15; **party de 4** nos passos
1, 9, 12, 13. Pré: G-01..G-36; `BindingWave = 3`; R6 e R15 disponíveis; `/dev seed 1234` (R24). Em cada noite:
`/dev night k` → ouvir a regra na `Call` (o texto bate com a "Forma curta" de `anomalies.md`) → `Prep` →
`/dev clock 9:30 PM` → `/dev anomaly <nova>`; os casos citados fecham no passo.

1. **Run nova:** intro toca (T120-01); na party de 2, A segura "Skip" → pula para os 2 (T120-03); 2ª run: assistir
   inteira, legenda e Solo/Party (T121-02/03); party de 4: 1 voto não pula, 2 pulam (T120-04); C entra no meio e
   spawna no fim (T120-08, T100-05).
2. **Dia, rua:** passantes 6–8 com rig vestido e LOD (T122-01, T123-*); carros ≤ 4, PARE 1 s, Ninth sem parar
   (T104-02/04); cliente cruza CW-1 com reserva e os carros param (T104-06, T122-08). B atravessa CW-1 com pacote
   `Count = 5` até ser atropelado: ragdoll 3 s, pacote no chão, A pega com 5 (T104-10, T100-03); B de novo com HotDog:
   splat (T104-11); imunidade (T104-13). Sanidade não muda (de dia não existe; à noite, R20: igual).
3. **Night 1 (N1):** às 7–9 PM ≤ 1 carro, depois 0 (T104-03); A recusa o sem-rosto (T111-03); B dá Take Order no
   próximo: B −35, moeda $0 (T111-04, $3-01); 3ª ocorrência: deixar esperar (T111-05). "Ver" −5 1× por jogador
   (T106-07).
4. **Night 2 (N2):** salsicha cinza no trilho → A pega e descarta (T113-02); pão mordido → B monta e serve: fumaça,
   sem pagamento, B −35 (T113-03, T114-01); 3ª: deixar e conferir que some às 6 AM (T113-04).
5. **Night 3 (N3):** relógio para e HUD continua (T113-07); A desliga 4 s e religa (não conta), depois 5 s (T113-09);
   2ª ocorrência: ninguém mexe 60 s → A e B −35 (T113-10).
6. **Night 4 (N4):** original + cópia espelhada; A recusa a cópia (T111-07); 2ª: B Take Order na cópia → −35 e
   sorriso parado; recusar um original → só insatisfeito (T111-08).
7. **Night 5 (N5):** servir incompleto → sucesso sem +$1 (T111-10, $3-03); entrega errada → continua esperando
   (T111-11); 2ª: B recusa → B −35 (T111-12); 3ª: deixar a paciência acabar → A e B −35 (T111-13).
8. **Night 6 (N6):** cortina antes da silhueta (T115-01); A olha 2,9 s, B 3,0 s (T115-03); 3ª: ninguém olha → apaga
   em 20 s (T115-05). Alucinações: `/dev sanity 15` em A → efeitos locais só em A (T119-01/03/04/05).
9. **Night 7 (N7, crítica):** zumbido do poste (T115-07); A olha 3 s → `Step` 3 (T115-08); B entra durante (Q3-04,
   T116-02); 40 s sem olhar → 0 (T115-10); party de 4: os 4 olham 3 s → `Step` 3 (T115-09). Por fim olhar até 10 →
   noite perdida ≤ 3 s, sem janela, `call_lost_critical` + `call_lost_last_chance`, repetição com agenda nova
   (T115-11, T106-13, $3-05).
10. **Night 8 (N8):** antes: A (PC) fecha e abre a janela, aba nos 2 clients, prompts de balcão somem e voltam
    (T130-01/02, T131-01/02); B (mobile) segura "Take Order" enquanto A fecha → toast só em B (T130-09). Sem trânsito
    depois das 9 PM; long car + farol (T117-01); A fecha a janela, B fica na calçada → B −35, blackout sem dreno
    (T117-03/06); 2ª: A e B dentro, A abre aos 10 s → só A −35 (T117-04); B no Mart não é testado (T117-05). B sai e
    volta com a janela fechada → aba já fechada (T131-04).
11. **Night 9 (N9):** A no trailer, B no Mart na 1ª batida: só A −5 (T117-09); A fecha a janela e fica dentro até o
    fim, B volta e fica na porta: B −35, porta abre um dedo (T117-10); 2ª: abrir aos 11,5 s → os 2 −35 (T117-17).
    Fim da noite: janela abre sozinha no turno seguinte (T130-10).
12. **Night 10 (N10):** `/dev anomaly anm_010_hush`: postes apagam, névoa, LZ do trailer apagam, interruptor sem
    efeito (T117-11); party de 4 no `SS` (T117-12); A sai aos 10 s → −35 (T117-13). `/dev clock 5:44 AM`: Hush
    roteirizado + Walker (T117-15); correr ao Mart sem olhar a Juniper (T098-05); 6:00 AM vence; +33 +100 antes do
    `finale` (T120-11); `finale` pulado por voto, `credits` com 0 votos (T120-07); tela de fim 15 s.
13. **Party de 4, Night 10 com espectador:** B `Spectator` desde a Night 9 (`/dev spectate`): na vitória B assiste e
    vota (T120-12); 3p com C saindo na cutscene: limiar cai (T120-05).
14. **Uma noite real sem `/dev anomaly`** (Night 8, ~28 min, `/dev seed 1234`): R17 imprime a agenda; conferir que
    cada ocorrência começa no horário da agenda, exclusões e atores ≤ 3 respeitados (T106-02..05), `Tension` liga e
    passantes somem (T106-14, T122-02).
15. **Fim:** G-01..G-36; P3-01..09 medidos na party de 4 no passo 12; §3 forjados; §4 saídas.

---

## 9. Regressão das ondas 1–2 nos arquivos que a onda 3 toca

Rodar o bloco depois que a task da coluna 2 estiver `Em QA`. Falha aqui = a task da onda 3 volta.

| Arquivo / pasta tocado | Task(s) da onda 3 | Casos a repetir (`wave-1.md` / `wave-2.md`) |
|---|---|---|
| `src/Libs/Net/init.luau`, `Place/shared/MapIndex/Required.luau` | 097 | T004-03, T005-01..06, T010-03, G-13; T048-01..05 |
| `src/Shared/Content/init.luau` + tabelas novas | 096 | T047-01, T047-14 |
| place (`Workspace`) | 098 | T083-01..09, T085-01..03 (binding da onda 2 intacto) |
| `CharacterService/` (+ `Ragdoll`) | 100 | T018-01..07, T061-01..09 |
| `CameraController` | 101 | T019-01..03, T064-01..06 |
| `InteractionService` (gate `Shutter` registrado pelo `VehicleService`, `Wave = 3` ativa) | 130 (era 102) | T011-01..09, T051-01..05 |
| `VehicleService/` (janela, `IsInside`, gate) | 130 | T056-01..12 (compra, troca, snapshot `Veh`), T057-01..07 |
| `VehicleController` (aba) | 131 | T058-01..05 |
| `PromptController/Rules.luau` | 131 (era 103) | T014-01..08, T078-01..06 |
| `AnomalyService/` (`Require` `VehicleService`, `Context.Vehicle`/`InZone`, evento `Shutter`) | 130 | T106-06..12, T115-*, T117-11..16 |
| `Net/init.luau`, `Content` (`Actions`, `Notices`, `Vehicles`, `Animations`), `Required` | 129, 133 | T004-03, T005-01..06, G-13, T048-01..05, T097-06, T100-03 |
| `CustomerService/`, `NpcService/` | 108 | T031-01..06, T032-01..08, T033-01..20, T053-01..07, T072-03/11 |
| `KitchenService/init`, `StationApi`, `Stations/Grill`, `Rail`, `Board` | 109 | T025-01..10, T026-01..08, T027-01..06, T028-01..09, T057-01..07, T068-01..08, T080-01..04 |
| `KitchenController/`, `CustomerController/`, `RigController` | 110 | T029-01..04, T030-01..03, T034-01..05, T037-01..03, T069-01..04, T079-01..06 |
| `NpcService/Walker.luau` | 122 | T031, T033 (filas e rotas), T072-03 (ladrão sem cruzar pista) |
| `RoundService` (probes `Intro`/`Finale` registradas pela 120) | 120 | T054-01..16 com os esperados novos abaixo |
| `LightService` (`BeginHush` pela N10) | 117 | T059-08, T060-02 |
| `VitalService` (`SeeAnomaly`, `Penalize`, `SetKnocked`) | 104, 106 | T062-01..17 |
| `ItemService` (`DropHeld` pelo trânsito) | 104 | T066-07..12 |

Esperados que **mudam** na onda 3 (como o D-08 da onda 2):

- **T054-02**: com a probe `Intro` registrada, a 1ª fronteira da run toca a intro (não pula mais); 2ª run em dev
  depois de `ResetDev`: registrar se a intro toca de novo (L3-14).
- **T054-10**: com a probe `Finale`, a Night 10 vencida toca `finale` → `credits` antes do `RunEnd(Success)`.
- **X2-10** (DEC-221): com `BindingWave = 2` `shutter_toggle` é descartada (`Wave = 3`); com `BindingWave = 3` é
  aceita à noite. `hide`/`get_up` nunca são aceitas (sem dono depois da 130; inexistentes depois da 133).
  `safe_spot` continua sem prompt.
- **T051-04**: ações `Wave = 3` aceitas só com `BindingWave = 3`.
- **T066-07..10**: o caminho real é o `CarHit`; o R8 da onda 2 continua como atalho.

---

## 10. Lacunas de spec encontradas ao escrever o plano

Nenhuma bloqueia o início da onda; cada uma vira caso com esperado **a definir** até ser respondida.

| ID | Achado | Onde | Para |
|---|---|---|---|
| L3-01 | Janela das anomalias: FEAT-003 (tabela de fases, "Últimos clientes 5:00 → 6:00 AM: sem estreia; **repetidas permitidas**") × FEAT-022 e §19.13 ("janela 9 PM–5 AM" para todas; só a `Scripted` fora). O plano testa 9 PM–5 AM (T106-03) | `features.md:243` × FEAT-022, `architecture.md` §19.13 | game-designer + architect |
| L3-02 | N7 na Night 10: FEAT-024 diz "a única ocorrência da N7 é a do clímax roteirizado"; o `Scheduler` dá 1 ocorrência por idade (3+ noites) **e** `walker.Scripted` existe. Sem regra, a Night 10 pode ter 2 Walkers. Definir que o `Scripted` **substitui** a ocorrência por idade (recomendação) | `features.md` FEAT-024 × §19.13, `Anomalies.luau` | architect |
| L3-03 | N8: `Rules` (`content-data.md` §6.10) só tem `HideWindow`/`StayFor`, sem `Zone`; `npcs.md` diz "jogador fora da zona do trailer não é testado". A zona precisa estar no `Rules/` da N8 como na N9 (`Zone = "trailer"`). **v1.1:** §19.14 v4.2 define a zona (raio 24 do `TRL`) para N8 e N9; fecha quando T117-05 passar | `content-data.md` §6.10 × `npcs.md` N8 | architect |
| L3-04 | Alucinação de quem está `Down`/`Spectator`: sanidade 0 deixa as 8 elegíveis e o §19.15 não filtra por estado. Recomendação: só `Active` e não em cutscene | `architecture.md` §19.15 | architect + game-designer |
| L3-05 | Orçamento: `network.md` §13.12 "total < 0,5 KB/s" × `architecture.md` §19.23 "segue < 1,5 KB/s" (e o aceite da 128 usa 1,5). O plano usa 0,5 como meta e 1,5 como falha (P3-01) | `network.md` §13.12 × §19.23 | architect |
| L3-06 | Doc atrasado em relação ao código/DEC: `network.md` §6.2 `Traffic.Look = int(1, 16)` (código 32), §13.5 `Stations.Altered` não opcional (código opcional), pitch cíclico do `Gaze`; `architecture.md` §8.2 item no chão "120 s" (DEC-197: 60 s), §8.3 "desmaio não é ragdoll" (DEC-216: ragdoll) | `network.md`, `architecture.md` §8 | architect (passe de doc já previsto na 097) |
| L3-07 | N6 como ator: `anomalies.md` "Interações" lista N6 entre os atores; `Anomalies.luau` e `npcs.md` dão `World` com `NpcCost = 0`. O plano segue `npcs.md` | `anomalies.md:215` × `npcs.md` NPC-014 | narrative-writer (nota) + game-designer |
| L3-08 | N3 com falha: `npcs.md` ainda descreve o relógio do HUD congelando 30 s, cortado pela DEC-195 | `npcs.md` N3 × DEC-195 | game-designer |
| L3-09 | `altered_item` derrubado (FEAT-036: "some na hora; a ocorrência fecha sem sucesso nem falha") não está no aceite da TASK-113 nem da 104 | board TASK-104/113 × FEAT-036 | task-planner |
| L3-10 | Teto de clientes à noite: FEAT-022 diz que o cliente-anomalia "substitui um spawn de cliente normal"; §19.23 lista clientes (6) e atores (≤ 3) em linhas separadas. Com 6 normais no balcão, o ator entra (7º), espera ou substitui? | FEAT-022 × §19.23 | architect + game-designer |
| L3-11 | N3 com a luz já desligada antes do sinal: "desligado ≥ 5 s contínuos e depois religado" conta o tempo anterior ao `clock_stop`? (T113-12) | `npcs.md` N3 | game-designer |
| L3-12 | Ponto seguro da N10: `npcs.md` propõe "área sob o letreiro **e** o interior do Mart"; §19.14 e `Rules` só têm `InZone(p, "SS", 6)`. Quem está comprando dentro do Mart falha? (T117-14) | `npcs.md` N10 × §19.14 | game-designer + architect |
| L3-13 | Jogador que sai com `altered_item`: o stash da onda 2 devolve a Tool na volta? FEAT-025 manda o item alterado sumir só para `Spectator` | §19.12 × FEAT-025 | architect |
| L3-14 | Intro em dev depois de `ResetDev` (2ª run no mesmo servidor): toca de novo? (só "1 vez por run", FEAT-004) | §19.16, §19.4 (`ResetDev`) | architect |
| L3-15 | Zona do trailer da N9 (`AudioZone`, "na zona do trailer quando a 1ª batida soa") e da N8 não tem binding próprio em §19.22 nem em `Required.Wave3`; não está dito se usa as `LightZone` LZ-1/2 ou outro volume. **v1.1:** §19.14 v4.2 usa raio 24 do `TRL` (sem binding novo) **[P]** | §19.22, `Required.luau` | architect + level-designer |
| L3-17 | Botão da janela alcançável de fora? `shutter_toggle` tem raio 7 e o botão fica perto da janela/porta; da calçada, pela janela aberta, um jogador pode alcançar o prompt. Spec não diz se fechar de fora vale (T132-05) | §19.14, MAP-01 §16.6 | architect + level-designer |
| L3-18 | "Só à noite": a ação usa `NightOnly`; não está dito se a **Prep** da noite conta (fechar antes das 7 PM) nem se o `Closing`/`Summary` noturno aceita (T130-03) | `Actions.shutter_toggle`, §19.14 | architect |
| L3-19 | Tentativa dentro do cooldown de 1 s: recusa silenciosa ou `Notice`? O plano espera silêncio (T130-04) | §19.14 | architect |
| L3-20 | `IsInside` pela `GetBoundingBox` do `Model` inteiro: a caixa inclui aba aberta, rodas, engate e teto → quem está na calçada sob a aba ou em cima do teto pode contar como "dentro" e ficar protegido na N8/N9 (T130-12). Recomendação: volume do interior (parte/atributo próprio) | §19.14 "Dentro do trailer" | architect + level-designer |
| L3-21 | Venda parada: N8 pede a janela fechada ~23 s (8 + 15) e N9 até 12 s; clientes cuja paciência esgota contam como insatisfeitos (DEC-051) por causa do verbo da anomalia. `Q-173` aceita o custo, mas não diz se a paciência pausa durante a N8/N9 (T117-22) | `Q-173` a, e | game-designer |
| L3-16 | Sinais sonoros de "não olhar" (N6 cortina, N7 zumbido) sem legenda/indicador para quem joga sem som no celular. Sem acessibilidade, a regra crítica depende de áudio | FEAT-022 regra 2 | game-designer + narrative-writer (`ui-text.md`) |

---

## 11. Resultado (preenchido pela TASK-128)

| Rodada | Data | Build (commit) | Solo PC | Party 2 (PC + Mob) | Party 4 | Casos falhos | Tasks de correção |
|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — |

---

## 12. ANM-004 "A cópia bate na porta dos fundos" (DEC-247, Provisório, 2026-10-14)

Código: `Anomalies/ANM-004.luau`, `Rules/ANM-004.luau` (`Door*`, `Knock*`), `TrailerDoorService` (`SetLocked`), `CustomerService:HoldSpawns`, efeito cliente `Effects/ANM-004.luau` e `Effects/Kit/Fade.luau`. Não marca nada como Aprovado. Pré-requisito: Play descartável em Night 4+ com o trailer (`/dev` conforme `tools/studio/smoke.md`; `anomaly` para iniciar a ANM-004 e `customer`/`seating` para o balcão). Party de 2 para os casos com "dentro" e "fora".

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| T004-01 | Verbo certo não muda | A recusa a cópia ("Refuse") | ocorrência resolvida; porta nunca trava; nenhuma batida; fila normal |
| T004-02 | Erro tranca a porta | A abre a porta (aberta), depois "Take Order" na cópia | −35 em A, cue `mirror_smile`, a porta fecha **na hora** e o prompt "Open door" continua visível |
| T004-03 | Porta trancada | A e B tentam "Open door" na janela de 8 a 12 s | nada abre; só quem tentou ouve `Locked door` (0,96 s); sem toast, sem `error`, sem `prompt_done` extra; a janela de serviço (Window) abre/fecha normal |
| T004-04 | Sem cliente novo | observar a fila durante a espera | nenhum cliente novo (nem passante adotado, nem garantia) entra até a 1ª batida; depois o fluxo volta |
| T004-05 | Atraso sorteado | repetir 5 vezes (`/dev` seed diferente) | 1ª batida entre 8 e 12 s depois do "Take Order"; nunca fixo |
| T004-06 | Batidas | A dentro do trailer | a cópia (rig animal, roupa espelhada, olhos brancos, pele normal) surge **fora** da porta, de frente para ela, e bate 3 vezes com 2 a 3 s entre batidas (`door_knock` no local da porta); sem voz |
| T004-07 | Só quem está dentro vê | B fora do trailer durante as batidas | B não vê a cópia nem ouve a batida; se A sai do trailer a cópia some só para A e volta se A entra |
| T004-08 | Porta destranca nas batidas | tentar abrir logo antes e logo depois da 1ª batida | antes: `Locked door`; depois: abre normal |
| T004-09 | Abriu = agarrado | A abre a porta entre a 1ª batida e 2 s depois da 3ª | a cópia entra, avança até o corpo de A (sem sangue nem arma), A desmaia (ragdoll, mesmo caminho do `Faint`), a cópia some com fade de 2 s; −35 em A (uma vez por ocorrência) |
| T004-10 | Revive | B usa o Revive Kit em A | A volta; não houve noite perdida (`LoseNight` não chamado; a "wipe" só vale se todos caírem, DEC-094) |
| T004-11 | Ninguém abriu | não tocar na porta | 2 s depois da 3ª batida a cópia dá fade de 2 s e é destruída (nenhum resquício na pasta `AnomalyEffects`); a ocorrência fecha **Resolved** e a porta fica livre |
| T004-12 | Quem abre fora | B (fora) usa "Enter" na janela das batidas | B abre a porta e é o agarrado (falha de quem abriu, DEC-204/DEC-247) |
| T004-13 | Carrinho | sem trailer (ou `HasDoor` falso) | só o −35; nada tranca, nenhuma cópia na porta |
| T004-14 | Fim da noite no meio | 6:00 AM / restore durante a tranca ou as batidas | `Stop` destranca a porta e solta o hold de clientes; cópia local some com a pasta de efeitos |
| T004-15 | `Kit/Fade` | `Fade.Out(modelo)` em cliente com BasePart, Decal, SurfaceGui (Frame, Label, Image, UIStroke), partículas e luz; `Restore()` | tudo vai a transparência 1 em 2 s; luz a 0; partículas desligadas; `Restore` devolve os valores originais; reutilizável pela ANM-002 (DEC-246) |
