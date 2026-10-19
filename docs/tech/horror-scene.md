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
Duration?, Point?, Burst?, Text?, Sound?, Seen? }` (`Sound` no `Actor` e no `Roof`, `Seen` só no `Actor`, TASK-472/484) · `Rules { Latency, ReduceMotion, MaxControlLock, MaxVignette, MaxFov, MaxNudge,
MaxPull, Shakes }` (`MaxPull` = teto do puxão de câmera dos eventos de suspense, `CameraController:HorrorPull`; não é passo de cena).

Eventos de suspense (TASK-481, DEC-294) usam o mesmo kit de câmera/tela/whispers fora de cena: contrato em `tech/suspense.md`.

Tipos de passo: `Sound`, `Music`, `Lights`, `Lightning`, `Whispers` (palavras HIDE na tela em rampa, DEC-291), `Vignette`, `Shake`, `Fov`, `Nudge`, `Text`, `Actor`, `Door`,
`Shadow`, `Roof`, `HeadDown` (TASK-484; semântica no cabeçalho de `HorrorScenes.luau`). `Point` é nome de `MapPoint` (`SCENE-DOOR`, `SCENE-DOOR-OUT`,
`SCENE-STEPS-FAR`, `SCENE-WINDOW-EYES` no restaurante — criados pela TASK-465).

## 3. Limites (checados pela validação)

- `Sound`/`Music` só com chaves de `Content.Sounds` (`Music` aceita `"Stop"`); `Shake` só com perfis de `Rules.Shakes`.
- `Vignette` ≤ `MaxVignette` (0,6); `Fov` |valor| ≤ `MaxFov` (6°); `Nudge` ≤ `MaxNudge` (3°) e duração ≤
  `MaxControlLock` (2 s): a câmera nunca é tomada do jogador.
- Com `Motion.Reduced()` (opção que o jogo já tem): `Shake`, `Fov` e `Nudge` multiplicados por `Rules.ReduceMotion` (0,25).

## 4. Quem implementa

- **TASK-462** player de cena (client): lê `Anomalies`, agenda os passos, `/dev scene <key>`.
- **TASK-463** câmera (perfis, FOV, nudge, opção). **TASK-464** vinheta e o passo `Whispers` (HIDE em rampa).
  API (`CameraController`, camada por cima do modo; só em `FirstPerson`/`Spectate`/`Fixed`, some em cutscene, monitor
  de segurança/`Prep` e `External`): `HorrorShake(perfil, escala?)`, `HorrorFov(delta, volta?, duração)` (sem `volta`
  segura o delta), `HorrorNudge(ponto, graus, duração)` (só 1ª pessoa, solta no fim) e `HorrorClear()` para cancelar.
  Tudo com clamp em `Rules` e × `ReduceMotion` com `Motion.Reduced()`.
  Chamadas (`Effects/Kit`, TASK-464): `Vignette` → `Screen.SetVignette(Value, To, Duration, sceneKey)` (um canal por
  cena, vale o mais forte, teto `MaxVignette`; `Screen.ClearVignette(sceneKey)` ao cancelar). `Whispers` →
  `local stop = Whispers.Ramp(Duration, Value, To)` (não bloqueia; `stop()` ao cancelar). Clímax: `Screen.Pulse(≤ 0,3)`.
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
- `/dev scene [<anomalia>|stop]` (`Dev/Commands/Scene.luau`; anomalia = key, ANM-###, número ou nome, e pula para a fase Night): marca o atributo `ReplicatedStorage.DevHorrorScene`
  e força a anomalia (fase Night). No dev o efeito do ANM-020 roda junto, então alguns sons/luzes saem dobrados até a
  TASK-467.
- QA pendente (Play, 2 clients): passos < 150 ms de diferença; entrar atrasado aplica luz/música; cancelar limpo ao
  terminar; `MapPoint`s `SCENE-*` ainda não existem (TASK-465) — som 3D cai para 2D com aviso.

### 4.2 The Walker nas câmeras (TASK-472, 2026-10-18; Provisório)

- Pedido do dono: os passos do apagão são do **The Walker** de verdade (AST-064), mas ele só aparece pelas câmeras de
  segurança; quem sai pela porta da despensa em 1ª pessoa não vê nada (só ouve).
- Sem tipo novo: o `Actor` ganhou dois campos (`Step.Sound`, `Step.Seen`). `Target` nil = os olhos de antes;
  `Target` = nome de `Model` em qualquer lugar de `ReplicatedStorage.Assets` (pivô nos pés, frente −Z, como no
  `Kit/Hide`; sem o modelo, silhueta escura de placeholder com aviso). Anda pelo chão (raycast sob o `MapPoint`) de onde
  está — ou de `Point`, onde surge — até `To` em `Duration`, e fica parado; `Value = 1` some ao chegar; sem `Point` só
  anda se já estiver lá. Um ator por `Target` e por run. `Actor` passou a ser tipo "segurado" (quem entra atrasado o
  recebe no ponto certo do caminho).
- Passos no modelo: `Sound` toca numa peça `Feet` do modelo a cada passo (mesma cadência do antigo som andante: repete
  pela duração do arquivo, mín. 0,3 s). Substitui as linhas `Sound walker_step` andantes da cena (Active 18→26,
  Failed 1→7) — mesmo tempo; `steps_stop` em 26 continua.
- Visibilidade (`Seen = "Cameras"`): `LocalTransparencyModifier = 1` em todas as peças e decals, luzes/partículas/guis
  desligados e `CastShadow = false` sempre; volta a 0 só enquanto `Kit/Watch.Watching()` (atributo `SecurityView` do
  `SecurityController`). Troca ao vivo por `Watch.Changed(fn)` (novo).
- Linhas: Active 18 entra em `SCENE-STEPS-FAR` → `SCENE-DOOR-OUT` (8 s) e fica; Failed 1 volta (6 s) e some; Resolved 0
  volta (6 s, só se já tinha vindo). Janela de 30 s e porta 27–29,4 iguais.
- Atenção: `Effects/ANM-020` corta quem está no monitor no início do apagão (`Watch.Interrupt`, "sem energia, sem
  câmera"), mas o servidor não bloqueia reabrir — o jogador volta ao monitor no escuro e vê o Walker. Se o dono quiser
  câmera desligada no apagão, isto conflita (pergunta para o lote).
- Asset: o modelo real está em `ServerStorage.DevScenes.AssetReview.D_Characters["AST-064_Walker"]` (só Studio); precisa
  de cópia em `ReplicatedStorage.Assets` (o `Kit/Hide` da ANM-007 procura o mesmo nome). Rig parado (sem animação de
  andar ainda; só balanço) — animação fica para depois.
