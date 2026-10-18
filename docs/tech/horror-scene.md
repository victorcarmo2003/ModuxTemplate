Status: Rascunho (Provisório) — contrato da TASK-461 (DEC-290)

# HorrorScene — anomalias como cena dirigida (contrato técnico)

Autor: architect, 2026-10-18. Design: `design/horror-cinematic.md`. Dados: `src/Shared/Content/HorrorScenes.luau`
(`Content.HorrorScenes`), validação em `Validate.luau` (`checkHorrorScenes`).

## 1. Decisão de arquitetura: nenhum pacote novo

A cena é **apresentação** (T10). O relógio dela já existe: o registro replicado `Anomalies` (Libs/Net) tem `Phase` e
`StartedAt`, e muda de fase pelo servidor. Cada passo da cena é ancorado ao instante em que o registro **entrou** na
fase do passo (`Step.Phase`, `Step.At` segundos depois). Todos os clients tocam a mesma linha do tempo sem rede extra.

- **Semente**: o índice do registro (ocorrência 1..255) — mesmos raios e mesmos pans em todos os clients.
- **Ramo "pego"** (`Who = "Caught"`): só o client que recebeu o cue de pego da anomalia (`AnomalyCue` `jumpscare` com
  `Entity = UserId % 65536`, já enviado pelo servidor) toca esses passos; `Who = "Safe"` = todos os outros.
- **Quem entra atrasado**: one-shots com mais de `Rules.Latency` de atraso não tocam; os tipos persistentes (`Lights`,
  `Vignette`, `Lightning`, `Music`) aplicam o estado de onde a cena está.
- A regra da anomalia (quem erra, quem desmaia, quando resolve) continua 100 % no servidor; a cena nunca decide nada.

## 2. Tipos (resumo; a fonte é o arquivo de dados)

`Scene { Key = <chave de Content.Anomalies>, Name, Steps }` · `Step { At, Phase, Kind, Who?, Target?, Value?, To?,
Duration?, Point?, Burst?, Text? }` · `Rules { Latency, ReduceMotion, MaxControlLock, MaxVignette, MaxFov, MaxNudge,
Shakes }`.

Tipos de passo: `Sound`, `Music`, `Lights`, `Lightning`, `Whispers` (palavras HIDE na tela em rampa, DEC-291), `Vignette`, `Shake`, `Fov`, `Nudge`, `Text`, `Actor`, `Door`,
`Shadow` (semântica no cabeçalho de `HorrorScenes.luau`). `Point` é nome de `MapPoint` (`SCENE-DOOR`, `SCENE-DOOR-OUT`,
`SCENE-STEPS-FAR`, `SCENE-WINDOW-EYES` no restaurante — criados pela TASK-465).

## 3. Limites (checados pela validação)

- `Sound`/`Music` só com chaves de `Content.Sounds` (`Music` aceita `"Stop"`); `Shake` só com perfis de `Rules.Shakes`.
- `Vignette` ≤ `MaxVignette` (0,6); `Fov` |valor| ≤ `MaxFov` (6°); `Nudge` ≤ `MaxNudge` (3°) e duração ≤
  `MaxControlLock` (2 s): a câmera nunca é tomada do jogador.
- Com `Motion.Reduced()` (opção que o jogo já tem): `Shake`, `Fov` e `Nudge` multiplicados por `Rules.ReduceMotion` (0,25).

## 4. Quem implementa

- **TASK-462** player de cena (client): lê `Anomalies`, agenda os passos, `/dev scene <key>`.
- **TASK-463** câmera (perfis, FOV, nudge, opção). **TASK-464** vinheta e o passo `Whispers` (HIDE em rampa).
- **TASK-465** porta da despensa e `MapPoint`s. **TASK-466** sons novos. **TASK-467** liga a cena do apagão no jogo,
  convivendo com `Effects/Kit/Blackout` (TASK-444) sem duplicar som/luz: o kit passa a ler os passos da cena.

### 4.1 Player (TASK-462, Em QA, 2026-10-18)

- Código: `src/Anomaly/client/AnomalyController/Scene/` (`init.luau` relógio/filas/`Who`, `Steps.luau` despachante,
  `Lights.luau`). Dentro do AnomalyController (sem controller novo): `Write`/`Unmount`/`OnCue` alimentam
  `Scene.Record`/`Scene.Remove`/`Scene.Cue`; `OnStart` chama `Scene.Start`.
- Âncora: fase vista mudando ao vivo = hora do servidor na chegada; primeira fase vista = `StartedAt` (exato se o
  registro nasceu nela; para quem entra depois do `Signal` erra para "mais atrasado": pula one-shot em vez de repetir).
  `StartedAt` não muda com a fase no servidor, por isso a âncora é local.
- Implementados: `Sound` (2D, ou 3D em peça local no `MapPoint`, andando até `To` e repetindo som não-loop),
  `Music` (`Score.Scene(key|"Stop"|nil)`, novo no diretor da TASK-443; com o score desligado, `AudioController:Loop`),
  `Lights` (fixtures do LightController marcadas + `Kit/Blackout.Darken/Look`; `Cascade` usa o novo `Handle.Sweep`,
  aditivo — o comportamento do kit não mudou), `Text` (`HorrorCaption` da TASK-444, título/linha cortados no 1º ". ").
- Stubs (log uma vez no Studio): `Shake`/`Fov`/`Nudge` TASK-463, `Vignette`/`Whispers` TASK-464, `Door`/`Shadow`
  TASK-465, `Actor`/`Lightning` TASK-467. Cada task pluga o seu com `Scene.Handle(kind, handler)` — assinatura
  `(ctx, state, step, late)`; `late` > 0 = aplicar estado de onde a cena está.
- **Flag `Live`** por cena (`Content.HorrorScenes`): `nil` = só toca via `/dev scene`. A cena do apagão fica sem `Live`
  até a TASK-467, porque `Effects/ANM-020` + `Kit/Blackout` + `Score/` já fazem luz/som/legenda (evita duplicar).
- `/dev scene [<key|ANM-###|n>|stop]` (`Dev/Commands/Scene.luau`): marca o atributo `ReplicatedStorage.DevHorrorScene`
  e força a anomalia (fase Night). No dev o efeito do ANM-020 roda junto, então alguns sons/luzes saem dobrados até a
  TASK-467.
- QA pendente (Play, 2 clients): passos < 150 ms de diferença; entrar atrasado aplica luz/música; cancelar limpo ao
  terminar; `MapPoint`s `SCENE-*` ainda não existem (TASK-465) — som 3D cai para 2D com aviso.
