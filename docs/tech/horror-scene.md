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

Tipos de passo: `Sound`, `Music`, `Lights`, `Lightning`, `Vignette`, `Shake`, `Fov`, `Nudge`, `Text`, `Actor`, `Door`,
`Shadow` (semântica no cabeçalho de `HorrorScenes.luau`). `Point` é nome de `MapPoint` (`SCENE-DOOR`, `SCENE-DOOR-OUT`,
`SCENE-STEPS-FAR`, `SCENE-WINDOW-EYES` no restaurante — criados pela TASK-465).

## 3. Limites (checados pela validação)

- `Sound`/`Music` só com chaves de `Content.Sounds` (`Music` aceita `"Stop"`); `Shake` só com perfis de `Rules.Shakes`.
- `Vignette` ≤ `MaxVignette` (0,6); `Fov` |valor| ≤ `MaxFov` (6°); `Nudge` ≤ `MaxNudge` (3°) e duração ≤
  `MaxControlLock` (2 s): a câmera nunca é tomada do jogador.
- Opção "Reduzir movimento" (Q-357): `Shake`, `Fov` e `Nudge` multiplicados por `Rules.ReduceMotion` (0,25).

## 4. Quem implementa

- **TASK-462** player de cena (client): lê `Anomalies`, agenda os passos, `/dev scene <key>`.
- **TASK-463** câmera (perfis, FOV, nudge, opção). **TASK-464** vinheta, clarão, raios em rampa no `Lightning`.
- **TASK-465** porta da despensa e `MapPoint`s. **TASK-466** sons novos. **TASK-467** liga a cena do apagão no jogo,
  convivendo com `Effects/Kit/Blackout` (TASK-444) sem duplicar som/luz: o kit passa a ler os passos da cena.
