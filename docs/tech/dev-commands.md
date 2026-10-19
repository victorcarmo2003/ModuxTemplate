Status: Rascunho (Provisório) — inventário dos comandos de dev antes da reescrita (pedido do dono, 2026-10-18)

# Comandos de dev (`/dev`)

Código: `src/Dev/server/DevService` (`init.luau`, `Api.luau`, `Commands/*.luau`, `Scenarios/`). Só existe no Studio
(`PlaceService:IsDev`). Entradas: chat `/dev <comando> <args>`, Command Bar `DevService.Run("night", 3)`, console
Conch `dev <comando>` (`AdminService`), painel do showcase (`ShowcaseService:Dev`, lista `DEV_ALLOWED`) e a linha dev
do painel de configurações (`Net.DevTool`, roda `mycoffee` / `infsanity`).

## 1. Inventário (antes, 2026-10-18)

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
| cutscene | `cutscene [play <key>\|vote\|skip\|stop]` | CutsceneService | manter, ganha `intro` |
| intro | `intro skip` | TutorialService/RoundService | fundir → `cutscene intro` |
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
