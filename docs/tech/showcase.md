# Showcase (painel de teste do dono)

Status: Rascunho (Provisório, sem DEC). Pedido do dono em 2026-10-12: testar cada anomalia, cada susto/alucinação e cada
mecânica ligada a elas sem jogar a run inteira. Feature `src/Showcase/{server,client}` + componente
`src/Interface/client/Components/ShowcasePanel`.

**Só existe em dev.** `ShowcaseService` só liga com `PlaceService:IsDev()` (Run place no Studio, sem PrivateServerId) e
reconfere `IsDev` + `AdminSettings.IsAllowed(player)` **em toda requisição**. Em servidor publicado o `OnInit` retorna
antes de registrar o responder: os packets existem no schema mas ninguém escuta nem envia. Nada é salvo.

## Como abrir

| Jeito | |
|---|---|
| tecla **F9** | liga/desliga (só em dev, `ShowcaseController`) |
| chat `/dev showcase` | pede ao servidor para abrir o painel do chamador |
| Conch (F2) `showcase` | idem |
| Conch `anomaly <ANM-###, chave ou noite> trigger, resolve, wrong ou stop` | age numa anomalia sem abrir o painel |
| Conch `scare <id>` | toca uma alucinação (`fake_call`, `whisper`...) ou `sting:<som>` (`sting:jumpscare`) no seu client |
| `/dev revive [player]` | traz um Down/Spectator de volta (ver "Limitações") |

Ao abrir, o painel libera o mouse (botão `Modal`), recebe o catálogo e, a 2 Hz, o estado. Ao abrir, a **agenda natural de
anomalias fica retida** (senão sortearia anomalia no meio do teste); ao fechar volta (o botão "Agenda held" alterna).

## O que o painel cobre

Barra de controles (sempre no topo):

| Controle | Efeito |
|---|---|
| Night 1..10 | vai para a fase Night da noite k (`night k` + `skip` até Night) |
| Clock 9 PM .. 5:45 | reescreve o início da fase (`RoundService:DevSetPhaseElapsed`) para o relógio marcar a hora |
| Freeze | congela o relógio (reaplica o tempo da fase a 5 Hz); some se a fase mudar |
| Skip to dawn | `skip` na Night: passa pelo veredito normal e vai ao NightEnd |
| Sanity -10 / +10 / Max / 0 | `VitalService:DevSetSanity` (0 = desmaia) |
| No faint | `VitalService:DevGod`: a sanidade nunca chega a 0 sozinha (queda forçada pelo painel continua valendo) |
| Dark auto / Force dark / Force lit | `sanity dark ...` (regra do escuro) |
| Agenda held | segura/solta a agenda natural (`AnomalyService:DevHoldAgenda`) |
| Stop all | para todas as anomalias, devolve luz/janela/cozinha, para alucinação |
| Reset all | Stop all + escuro auto, sem god, agenda solta, relógio rodando |

Aba **Anomalies** (ANM-001..010): cada cartão mostra nome, Ref, o que deve acontecer, o verbo correto (vindo de `Rules/`,
só pelo packet dev), o estado vivo (`idle`, `ACTIVE step n (Ns)`, `last: RESOLVED (Ns ago)`) e os botões:

| ID | Trigger | Correct verb (automático) | Wrong verb | Extras |
|---|---|---|---|---|
| ANM-001 blank folks | sim | `CustomerService:Refuse` no ator (real) | `TakeOrder` no ator | |
| ANM-002 wrong food | sim (`Alter` na esteira/tábua) | **simulado**: evento `Discard` com `Altered` + `ClearAltered` | não automatizável | |
| ANM-003 stopped clock | sim | `LightService:SetSwitch` off, espera `DarkHold`+0,7 s, on (real) | não (é omissão de 60 s) | |
| ANM-004 copies | sim | `Refuse` na cópia (real) | `TakeOrder` na cópia | |
| ANM-005 raincoat lady | sim | **simulado**: evento `serve` Complete (servir de verdade exige hot dog pronto) | `Refuse` | |
| ANM-006 wavers | sim | não: o certo é **não olhar** (some em `AutoOff`) | não | |
| ANM-007 walker (crítica) | sim | não: o certo é não olhar | não | Step 1..4 (`walker n`; 4 perde a noite) |
| ANM-008 long car | sim | `VehicleService:SetShutter(true)`; no carrinho (sem janela) sai da zona indo ao Mart | janela aberta + volta ao trailer | Go to Mart / Go to trailer |
| ANM-009 knock | sim | idem 008 | idem | idem |
| ANM-010 hush | sim | teleporta ao ponto seguro `SS` | fica no `TRL` | idem |

`Trigger` leva o jogo à fase Night (da noite atual, ou da noite de estreia se ainda é dia), para a ocorrência anterior da mesma
anomalia, limpa o mundo e chama `AnomalyService:DevForce` (usa as âncoras e o `Start` reais do módulo). `Reset` = `DevStopKey`
(Stop "Restore") + limpeza do mundo (luz, janela, item alterado).

Aba **Scares**: as 8 alucinações de `Content.Hallucinations` (Play ignora sanidade, fase, cooldown e `CanRun`; avisa se o
`CanRun` era falso) e os stings/jumpscares (`jumpscare`, `horror_sting`, `horror_chase_stop`, `anomaly_see`,
`horror_dramatic`, `scary_violins`, `car_honk_goofy`), no teto de susto da DEC-173 (menos o `car_honk_goofy`, que é fora do
teto). Rodam **no client** do dono (`ShowcaseScare` -> `HallucinationController:DevPlay` / `AudioController:Play`).

Aba **Mechanics**: Sanity (-10/+10/50/25/5), Faint/Down/Spectator/Revive, Ambulância (ver limitações), perda/vitória da
noite (wipe, critical, win), regra do escuro + interruptor + Hush, café, ladrão (`thief now L1..L3`), carro e atropelamento
(`Run me over` = `traffic spawn` + `traffic hit`), janela do trailer (close/open/inside), carrinho/trailer (`trailer swap`/`reset`),
teleportes (SS, TRL), item alterado (`alter rail|board|clear`) e clientes (aleatório e pares de dia/noite do
`Content.Flow.Groups.Pairs`).

## Arquitetura

```
ShowcaseController (client) --ShowcaseDo--> ShowcaseService (server, dev only) --> AnomalyService / DevService / Vital / Round / ...
        ^                                        |
        +--- ShowcaseCatalog | ShowcaseState | ShowcaseLog | ShowcaseScare ---+
```

- Packets em `src/Libs/Net/init.luau` (packets, não sets): `ShowcaseDo` (c->s: `Action`, `Id`, `Arg`, `Value`),
  `ShowcaseCatalog` (lista de itens; **só em dev**, porque contém o verbo correto: T10), `ShowcaseState` (2 Hz),
  `ShowcaseLog` (resultado de cada ação; `Kind = "open"` pede ao client abrir), `ShowcaseScare` (toca no client).
- `ShowcaseService/init.luau`: gate (`Allowed`), dispatcher `Run(player, action, id, arg, value)` (usado também pelo Conch),
  `EnsureNight`, relógio, sanidade, estado do painel e memória das anomalias que acabaram (`Ended`, 20 s).
- `ShowcaseService/Catalog.luau`: os itens e botões. `ShowcaseService/Resolve.luau`: verbo certo/errado por anomalia.
- Reuso, sem duplicar lógica: `DevService:Execute` (só os comandos de `DEV_ALLOWED`) e `AnomalyService:DevForce`.
- Hooks novos, todos com `IsDev`: `AnomalyService:DevHoldAgenda / DevIsHeld / DevRuns / DevOccurrence / DevStopKey / DevEmit`,
  `VitalService:DevGod / IsDevGod / DevDarkMode / DevRevive`, `RoundService:DevPhaseElapsed / DevSetPhaseElapsed`,
  `HallucinationController:DevPlay / DevStop / DevActive`, comandos `showcase` e `revive` em `Dev/.../Commands/`.

## Como adicionar um item

1. **Item novo de mecânica ou susto**: uma entrada em `Catalog.luau` (`mech(...)` ou `scareItems`). Um botão é
   `act("dev", "Label", "comando dev")` (o comando precisa estar em `DEV_ALLOWED`), `act("sc", "Label", "helper")` (novo
   helper em `ShowcaseService:Helper`) ou `act("scare", ...)`.
2. **Anomalia nova**: `Content.Anomalies` + módulo/regra normais; o painel já lista a linha. Descrição em `ANOMALY_DESC`;
   verbo certo/errado em `Resolve.luau` (`correct["ANM-0xx"]`, `wrong[...]`). Sem entrada = o botão não aparece.
3. **Controle global novo**: `ShowcaseService:Control` + botão em `ShowcasePanel`.

## Limitações (conhecidas)

- **Ambulância e médicos não existem neste build** (wave 4: `AmbulanceService`, Revive Kit). O corpo caído só some após
  `Revive.BodyFallback` (20 s). `Revive` (painel / `/dev revive`) é um substituto: volta Active com metade da sanidade, novo
  personagem e o stash devolvido; um Down gasta um revive da noite.
- ANM-002 (descartar) e ANM-005 (servir) são **simulados por evento**: o módulo julga como no jogo, mas a ação real
  (lixeira, hot dog pronto) não acontece. ANM-006 e ANM-007 não têm verbo automático (o certo é não olhar).
- Anomalias de cliente precisam do ator na fila: se `Correct verb` disser "still walking", tente de novo em alguns segundos.
- O congelamento do relógio só segura o relógio e o fim da fase; os timers das anomalias seguem em tempo real.
- Trocar de noite reinicia o turno (`night k`): perde o estado da run atual (é um teste).
- Com 2+ admins com o painel aberto, a agenda só volta a rodar quando todos fecham.
- Não foi testado no Studio (sem Studio MCP nesta tarefa): o gate foi `modux check` e `tools/analyze.ps1`.
