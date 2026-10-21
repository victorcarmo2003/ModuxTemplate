Status: Rascunho (Provisório) — conjunto de comandos de dev reescrito a pedido do dono (2026-10-18)

# Comandos de dev (`/dev`)

Código: `src/Dev/server/DevService` (`init.luau`, `Api.luau`, `Commands/*.luau`, `Scenarios/`). Ligado também no jogo
publicado (DEC-351): roda para quem está no modo dev do Studio (`PlaceService:IsDev`) ou na lista
`AdminSettings.AdminUserIds` (a mesma do console admin); qualquer outro jogador é recusado no servidor. As respostas
saem no Output do servidor (no jogo publicado: F9 → Server). Entradas: chat `/dev <comando> <args>`, Command Bar `DevService.Run("night", 3)`, console
Conch `dev <comando>` (`AdminService`), painel do showcase (`ShowcaseService:Dev`, lista `DEV_ALLOWED`) e a linha dev
do painel de configurações (`Net.DevTool`, roda `mycoffee` / `infsanity`).
No jogo publicado, um comando de admin roda com `PlaceService:AsAdmin` (2026-10-21): as checagens "dev mode only" dos
serviços (`DevRevive`, `DevSetPhaseElapsed`...) deixam passar só aquele comando. Atalhos no console Conch, com autocomplete
(o `dev ...` não tem): `revive [player]` (jogadores do servidor), `reviveall` e `time <h:mm>` (de 30 em 30 min).

Estrutura: cada arquivo de `Commands/` registra verbos vivos; os comandos antigos de um sistema só viraram
`Parts/*.luau` (não carregados sozinhos) e o verbo repassa o subcomando para eles (`Kit.luau`: `group`, `forward`,
`alias`). `help` lista só os vivos (uma linha cada); `help <cmd>` mostra um; nomes `Hidden` rodam mas não aparecem.

## 2. Comandos atuais

Anomalia = key, `ANM-###`, número (o do ANM) ou parte do nome (`blackout`, `knock`, `crawler`, `red fog`).
`trigger` e `scene` fora da fase Night pulam para ela antes (noite do turno atual, ou a noite do dia).

| Comando | O quê |
|---|---|
| `help [cmd]` | lista viva, ou uso de um comando |
| `night [n] [prep]` | direto na fase Night da noite n (padrão: a atual); `prep` = para no começo do turno |
| `day [n]` | turno do Dia n (padrão 1 = turno de dia, já em Open; Dia n ≥ 2 = Noite n − 1) |
| `skip` | encerra a fase atual pelo caminho do timer |
| `time <h:mm>` | move o relógio da fase (24 h; `3:30` na Night = 3:30 da manhã) |
| `win` · `lose [wipe\|critical]` | resolve a noite atual |
| `trigger <anomalia> [example]` (`t`) | dispara agora; `trigger stop [anomalia]`; `trigger list` = agenda + catálogo (cortes do restaurante marcados); sem args = o que roda |
| `scene <anomalia>` · `scene stop` · `scene score <stage\|auto>` | cena de horror da anomalia; estágio da trilha (era `score`) |
| `scare [list\|all\|<key>...]` | susto família D |
| `pressure [now]` | escada de sanidade (DEC-352): faixa de cada jogador, próximo susto pessoal, extras da noite; `now` = rolagem/sustos já |
| `atm <ATM-#\|n\|nome\|off\|auto>` | atmosfera da noite (era `atmosphere`) |
| `bolt [near\|far]` | relâmpago forçado em todos (Q-453): `far` = flash + trovão atrasado; `near` = o susto (flash forte, trovão na hora, tranco de câmera). Precisa de atmosfera ligada (noite ou `atm <key>`) |
| `suspense [list\|status\|<spot>\|<event> [spot]]` | evento de suspense agora |
| `trip [now]` | disjuntor desarma sozinho (Q-435): contagem da noite e o próximo; `now` = desarma assim que estiver calmo |
| `beats` | diretor de batidas (2026-10-21): última batida, o que conta como ativo agora (anomalias, tarefas, desarme), intervalo e a próxima anomalia |
| `chore [<key>\|now\|end [<key>\|all]]` | tarefas da noite (Q-436): `grill_fire`, `back_door`, `rats`, `camera_static`; sem args = estado; `<key>` liga agora |
| `sanity [<n>\|hint\|dark on\|off\|auto] [player]` | sanidade |
| `god [on\|off]` · `god me [on\|off] [player]` | ninguém desmaia (party) · sanidade infinita de um jogador |
| `revive [player\|all]` · `revive auto [on\|off] [player]` | volta Active (um jogador, ou `all` = todos Down/Spectator) · levanta 2 s após desmaio |
| `faint [spectator] [player]` | cai agora como Down (ou Spectator) |
| `coffee [n \| give \| take \| cup fill\|empty\|sip\|give\|auto]` | doses da máquina, café na mão, pegar o pronto, copo do balcão |
| `kitchen rail [n] \| gift [topping\|all] \| stock [state\|take <pkg>\|test]` | trilho, potes de brinde, estoque |
| `prep grade\|ray\|kitchen\|plate\|seats\|ui\|enter\|leave\|finish` | modo focado (inalterado; `/dev prep grade` segue valendo) |
| `plate` · `tablet` · `pickup` | pratos, tablet, retirada (inalterados) |
| `customer pair\|group\|sit\|quality \| on\|off \| spawns \| tables [buy\|sit]` | clientes |
| `money cash <n> \| gems <n> [player] \| tips ... \| ledger` | dinheiro |
| `shop receipt\|code\|reward\|market\|gear ...` | loja, códigos, recompensas, Gear Stand |
| `upgrade [key] [level]` | upgrade grátis (inalterado) |
| `call [<key>\|answer\|stop\|list]` · `cutscene [play\|vote\|skip\|stop]` | telefone do chefe · cutscenes |
| `tutorial [reset\|step <k>\|voice ...\|debug]` | tutorial (`voice`, `tutdebug` entraram aqui; `intro skip` removido, DEC-309) |
| `ui hud\|offer\|journal\|rejoin\|showcase ...` | interface |
| `street cars\|walkers\|thief ...` | rua: carros, pedestres, ladrão |
| `debug audio\|interact\|movement\|drop\|light ...` | leituras de debug |
| `smoke [status]` | smoke do loop do restaurante |
| `track [list\|stop\|here\|<key>]` | câmera de captura do trailer (TASK-C1, `marketing/trailer-blackout-60s.md` §7): sem args = o que toca no caller (ou a lista); `list` = `key — nome (duração s, n keys)`; `<key>` = toca a track de `src/Dev/shared/CameraTracks.luau` na câmera do caller (atributos `DevCameraTrack`/`DevCameraTrackAt` do Player, lidos por `Dev/client/DevCameraController`; `HideUi` esconde a UI, menos cena de horror e prompts); `stop` = câmera e UI de volta; `here` = a câmera atual do caller como linha de `Key` pronta para colar (packet `DevCameraHere`, 2 Hz) |

## 3. Renomeados, fundidos e removidos

| Antes | Agora |
|---|---|
| `anomaly ...` · `anomaly agenda` | `trigger ...` · `trigger list` (`anomaly` segue como nome oculto) |
| `blackout` · `blackout stop` | `trigger blackout` · `trigger stop blackout` |
| `atmosphere` | `atm` |
| `score <stage>` | `scene score <stage>` |
| `down` · `spectate` | `faint` · `faint spectator` |
| `autorevive` · `infsanity` | `revive auto` · `god me` |
| `mycoffee` · `coffeemachine take` · `coffeecup ...` | `coffee give` · `coffee take` · `coffee cup ...` |
| `railfeed` · `gift` · `supply` | `kitchen rail` · `kitchen gift` · `kitchen stock` |
| `arrivals on\|off` · `spawns` · `seating [buy\|sit]` | `customer on\|off` · `customer spawns` · `customer tables [buy\|sit]` |
| `cash` · `gems` · `tips` · `economy ledger` | `money cash` · `money gems` · `money tips` · `money ledger` |
| `receipt` · `code` · `reward` · `market` · `gear` | `shop receipt` · `shop code` · `shop reward` · `shop market` · `shop gear` |
| `voice` · `tutdebug` | `tutorial voice` · `tutorial debug` (`intro skip` removido, DEC-309) |
| `hud` · `offer` · `journal` · `rejoin` · `showcase` | `ui hud` · `ui offer` · `ui journal` · `ui rejoin` · `ui showcase` |
| `traffic` · `walkers` · `thief` | `street cars` · `street walkers` · `street thief` |
| `audio` · `interactlog` · `movement` · `drop` · `light` | `debug audio` · `debug interact` · `debug movement` · `debug drop` · `debug light` |
| `day <n>` / `night <k>` | `day [n]` (padrão Dia 1, já em Open) / `night [n]` (cai na fase Night; `night n prep` = antigo) |
| `lose wipe\|critical` | `lose [wipe\|critical]` (padrão wipe) |

**Removidos** (sistema cortado com o restaurante ou só do trailer): `walker` (ANM-007 cortada), `alter` (ANM-002
cortada), `closed` (interruptor da loja do trailer; use `customer off`), `shutter` (janela de serviço), `trailer`
(status/reset do veículo), `trash` e `seating trailer|dirty|clean` (mesas não sujam), e os passos do trailer do `smoke`
(boot, trailer ready, trailer seating, tip jar + ledger — `smoke restaurant` virou o `smoke`).

**Nomes ocultos** (rodam, fora do `help`; mantidos por quem chama pelo nome): `t`, `anomaly` (docs e planos de teste);
`down`, `spectate`, `light`, `traffic`, `thief` (botões do showcase, `ShowcaseService` `DEV_ALLOWED` / `Catalog`);
`cash`, `gems`, `arrivals`, `autorevive` (atalhos do console Conch, `AdminService`); `mycoffee`, `infsanity` (linha dev
do painel de configurações, `Net.DevTool`).

Os documentos históricos (`docs/tasks/board.md`, playtests, `docs/tests/wave-*.md`, `decisions.md`) citam os nomes
antigos; a tabela acima traduz.

## 4. Inventário anterior

### Antes da reescrita (2026-10-18)

53 arquivos, 69 comandos. Modo restaurante ligado (`Content.Restaurant.Rules.Enabled = true`): anomalias cortadas
ANM-002, ANM-003, ANM-007, ANM-018 (`Restaurant.Switch.CutAnomalies`); sem porta dos fundos do trailer, sem janela de
serviço, sem Mart, mesas não sujam (`DirtyTables = false`).

Destino: **manter**, **renomear** (novo nome), **fundir** (vira subcomando de outro), **remover** (sistema morto,
duplicado ou debug de uma TASK). "Chamado por código" = Admin / Showcase / DevTool / Smoke chamam pelo nome.

| Comando | Uso | Serviço | Destino |
|---|---|---|---|
| anomaly | `anomaly [agenda\|stop\|<key\|ANM-###\|n> [example]]` | AnomalyService:DevForce/DevStop/DevStatus/DevAgenda | renomear → `trigger` (alias `t`); `anomaly` alias oculto (docs/testes) |
| blackout | `blackout [stop]` | AnomalyService:DevForce("ANM-020") | remover (= `trigger blackout`) |
| walker | `walker <0..4>` | módulo ANM-007 | remover (ANM-007 cortada no restaurante) |
| alter | `alter [rail\|board [slot]\|clear]` | KitchenService (ANM-002) | remover (ANM-002 cortada) |
| scene | `scene [stop\|<anomalia>]` | AnomalyService:DevForce + atributo DevHorrorScene | manter (resolver comum) |
| scare | `scare [list\|all\|<key>...]` | HallucinationService:Scare | manter |
| atmosphere | `atmosphere [ATM-n\|n\|off\|auto]` | AtmosphereService:Force | renomear → `atm` (aceita nome) |
| suspense | `suspense [list\|status\|<spot>\|<event> [spot]]` | SuspenseService | manter |
| score | `score <stage\|auto>` | Net.DevAudio (client) | fundir → `scene score` |
| light | `light [on\|off\|hush [s]\|end\|here]` | LightService | fundir → `debug light`; `light` alias oculto (showcase) |
| day | `day <n>` | RoundService:DevSetDay | manter (`day [n]`, padrão = próximo dia) |
| night | `night <k>` | RoundService:DevSetNight | manter (`night [n]`, cai direto na fase Night) |
| skip | `skip` | RoundService:DevSkipPhase | manter |
| win | `win` | RoundService:DevWinNight | manter (showcase) |
| lose | `lose wipe\|critical` | RoundService:LoseNight | manter (showcase) |
| closed | `closed [on\|off]` | RoundService:SetPaused | remover (interruptor da loja do trailer; `customer off` cobre) |
| sanity | `sanity [<n>\|hint\|dark on\|off\|auto] [player]` | VitalService | manter |
| down | `down [player]` | VitalService:DevFall | fundir → `faint`; alias oculto (showcase) |
| spectate | `spectate [player]` | VitalService:DevFall | fundir → `faint spectator`; alias oculto (showcase) |
| autorevive | `autorevive [on\|off] [player]` | VitalService:DevSetAutoRevive | fundir → `revive auto`; alias oculto (Admin) |
| revive | `revive [player]` | VitalService:DevRevive | manter |
| infsanity | `infsanity [on\|off] [player]` | VitalService:DevInfiniteSanity | fundir → `god me`; alias oculto (DevTool) |
| mycoffee | `mycoffee [player]` | ItemService | fundir → `coffee give`; alias oculto (DevTool) |
| coffee | `coffee [n]` | KitchenService (doses) | manter, ganha subcomandos |
| coffeecup | `coffeecup [fill\|empty\|sip\|give\|auto]` | ItemService | fundir → `coffee cup ...` |
| coffeemachine | `coffeemachine take` | KitchenService | fundir → `coffee take` |
| railfeed | `railfeed [n]` | KitchenService | fundir → `kitchen rail [n]` |
| gift | `gift [<topping>\|all]` | KitchenService | fundir → `kitchen gift ...` |
| supply | `supply [state\|take <pkg>\|test]` | SupplyService | fundir → `kitchen stock ...` |
| prep | `prep grade\|ray\|kitchen\|plate\|seats\|ui\|enter\|leave\|finish` | PrepService, TutorialService | manter (`/dev prep grade` do CLAUDE.md segue válido) |
| plate | `plate [list\|assign\|fill\|prep\|clear\|test]` | PlateService | manter |
| pickup | `pickup [test\|take\|serve\|ticket\|pause]` | CustomerService, ItemService | manter |
| tablet | `tablet [state\|talk\|finish\|time <k>]` | TabletService | manter |
| customer | `customer group\|pair\|sit\|quality` | CustomerService, SeatingService | manter, ganha `on\|off`, `spawns`, `tables` |
| arrivals | `arrivals [on\|off]` | CustomerService | fundir → `customer on\|off`; alias oculto (Admin) |
| spawns | `spawns` | CustomerService, RoundService | fundir → `customer spawns` |
| seating | `seating [buy\|trailer [buy]\|sit\|dirty <n>\|clean <n>]` | SeatingService | fundir → `customer tables [buy]`; `trailer`/`dirty`/`clean` removidos |
| trash | `trash [table]` | (mapa) | remover (mesas não sujam no restaurante) |
| cash | `cash <n>` | EconomyService | fundir → `money cash`; alias oculto (Admin) |
| gems | `gems <n> [player]` | ClassService/EconomyService | fundir → `money gems`; alias oculto (Admin) |
| tips | `tips [state\|add <n>\|collect]` | TipJarService | fundir → `money tips` |
| economy | `economy ledger` | EconomyService | fundir → `money ledger` |
| receipt | `receipt <key> [id]` | ShopService | fundir → `shop receipt` |
| code | `code <text>` | CodesService | fundir → `shop code` |
| reward | `reward endless\|forget\|status` | RewardService | fundir → `shop reward` |
| market | `market [reset]` | UpgradeService | fundir → `shop market` |
| gear | `gear [open\|close\|state]` | GearStandService | fundir → `shop gear` |
| upgrade | `upgrade [key] [level]` | UpgradeService | manter (Admin) |
| call | `call [<key>\|answer\|stop\|list]` | BossService | manter |
| cutscene | `cutscene [play <key>\|vote\|skip\|stop]` | CutsceneService | manter |
| intro | ~~`intro skip`~~ | — | removido (DEC-309) |
| tutorial | `tutorial [reset\|step <k>]` | TutorialService | manter, ganha `debug`, `voice` |
| tutdebug | `tutdebug` | Net (client) | fundir → `tutorial debug` |
| voice | `voice ...` | Net (client) | fundir → `tutorial voice` |
| hud | `hud reveal all\|reset\|status` | TutorialService | fundir → `ui hud` |
| offer | `offer list\|status\|reset\|<key>` | TutorialService | fundir → `ui offer` |
| journal | `journal [all\|reset\|open\|<ANM>]` | JournalService | fundir → `ui journal` |
| rejoin | `rejoin [resume\|hide\|status]` | RoleService, SessionService | fundir → `ui rejoin` |
| showcase | `showcase` | ShowcaseService | fundir → `ui showcase` |
| thief | `thief [now [L1..L3]\|sim <day> [n]]` | ThiefService | fundir → `street thief`; alias oculto (showcase) |
| traffic | `traffic [spawn\|clear\|hold\|reserve\|release\|hit]` | TrafficService | fundir → `street cars`; alias oculto (showcase) |
| walkers | `walkers [spawn\|clear\|adopt]` | PedestrianService | fundir → `street walkers` |
| movement | `movement [debug on\|off]` | (Content.Movement) | fundir → `debug movement` |
| interactlog | `interactlog [on\|off]` | InteractionService | fundir → `debug interact` |
| audio | `audio` | Net.DevAudio | fundir → `debug audio` |
| drop | `drop` | ItemService | fundir → `debug drop` |
| shutter | `shutter [open\|close\|in]` | VehicleService | remover (janela de serviço do trailer) |
| trailer | `trailer [status\|reset]` | VehicleService | remover (trailer fora do mapa) |
| smoke | `smoke [status\|restaurant]` | Scenarios/RestaurantSmoke | manter; passos do trailer removidos (só o loop do restaurante) |

Referências encontradas: `docs/tests/*` (planos de teste por onda), `docs/tasks/board.md` e playtests (histórico),
`docs/tech/*` (prep, showcase, horror-scene, suspense, admin), `tools/studio/*`, `CLAUDE.md` (`/dev prep grade`).
