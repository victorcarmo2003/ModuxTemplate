Status: Rascunho (Provisório) — contrato da TASK-481 / TASK-486 (DEC-294)

# Eventos de suspense (contrato técnico)

Autor: backend-coder + frontend-coder (sessão TASK-481), 2026-10-18. Design: `design/horror-cinematic.md` §7.
Dados: `src/Shared/Content/Suspense.luau` (`Content.Suspense`), validação em `Validate.luau` (`checkSuspense`).
Servidor: `src/Suspense/server/SuspenseService.luau`. Client: `src/Suspense/client/SuspenseController.luau`.
Dev: `src/Dev/server/DevService/Commands/Suspense.luau`.

## 1. O que é

Susto que **não é anomalia**: sem regra, sem verbo, sem aviso, sem registro `Anomalies`. Uma criatura aparece **na hora**
num ponto que **ninguém está olhando**; quem a pega de relance tem a câmera puxada para ela (~0,4 s), ouve um "sub drop",
perde sanidade (o servidor sorteia 5–10) e ela some. Mild (DEC-172): curto, sem sangue, sem vermelho.

## 2. Dados (`Content.Suspense`)

- **Linhas = eventos** (criaturas): `Key`, `Ref` (referência de design), `Style` (`Grin` / `Walk` / `Crawl` / `Roof`,
  corpos placeholder do kit da família B, `Hide.Build`), `Asset?` (Model em `ReplicatedStorage.Assets` que substitui o
  placeholder), `Spots`, `FromNight`, `Weight`, `Scale`, `Head` (altura do alvo "visto", antes da escala).
  - `sorriso` (ANM-018, o primeiro evento, DEC-294): rosto redondo enorme com sorriso branco; `drive_thru`, `prep_counter`.
  - `figure` (ANM-007): a figura alta escura; `pantry`, `street_end`; a partir da noite 3.
- **`Spots`**: `Key`, `Point` (MapPoint que manda quando existir no place: pose = pés, LookVector = para onde olha),
  `Position` / `Face` (coordenadas do MAP-01 rev. 4, usadas sem o ponto), `Scale`. Os pés descem até o chão por raycast
  (servidor e client).

  | Spot | MapPoint (a criar) | Sem o ponto | Escala |
  |---|---|---|---|
  | `prep_counter` | `SUS-PREP` | (57,5; 66,2), ponta leste do corredor do fundo, olhando a cozinha | 0,55 |
  | `drive_thru` | `SUS-DT` | (63,2; 61), lado de fora da `DT-WIN`, o rosto enchendo a janela | 0,75 |
  | `pantry` | `SUS-PANTRY` | (29; 75,5), dentro da despensa, visto pela `DOOR-P` | 1 |
  | `street_end` | `SUS-STREET` | (112; 9), fim da Ninth, visto pelas janelas da frente | 1,3 |

- **`Rules`** (tudo Provisório): `FromNight` 2, `PerNight` {1, 3}, `Window` {1290, 1710} (21h30–4h30), `MinGap` 90 s,
  `AfterAnomaly` 20 s, `Retry` 4 s, `Life` 12 s, `Cost` {5, 10}, `HiddenAngle` 110°, `HiddenRange` 160, `MinDistance` 10,
  `SeenRange` 140, `SeenAngle` 150°, `ScreenMargin` 0,04, `Hijack` { `Duration` 0,4, `Pull` 25°, `Fov` −6, `Shake` `Jolt`,
  `Vignette` 0,45, `VignetteFor` 1,6, `Pulse` 0,25, `Linger` 0,35, `Words` 2,5 }.
- `Content.HorrorScenes.Rules.MaxPull` = 30° (teto do puxão; o `MaxNudge` 3° dos passos de cena não muda).
- `Content.HorrorScenes.Words.suspense`: "WHAT WAS THAT?", "DON'T TURN AROUND", "DID YOU SEE IT?", "it's gone...",
  "keep working".

## 3. Rede (`src/Libs/Net`)

| Entrada | Direção | Formato | Quem |
|---|---|---|---|
| `Suspense` | s → Audience | `{ Id = int(0,255), Event = enum(Suspense.Keys), Spot = enum(Suspense.SpotKeys), Seed = int(0,65535) }` | escreve `SuspenseService`; lê `SuspenseController` |
| `SuspenseSeen` | c → s | `{ Id = int(0,255) }` | envia `SuspenseController`; responde `SuspenseService` (`OnInit`) |

Packet, não set: é evento; quem entra atrasado simplesmente perde o susto. Nada de `keyBy`.

## 4. Servidor (`SuspenseService`, só no place Run)

1. **Agenda**: no `ShiftStarted` de uma noite ≥ `FromNight`, sorteia `PerNight` eventos (semente RunSeed, Day, Night,
   Attempt), um por fatia igual da `Window`, com jitter dentro da fatia. Só roda na fase `Night`; Call/Prep guardam a
   agenda, as outras fases a descartam.
2. **Quando começa**: entrada vencida espera enquanto **qualquer ocorrência de anomalia** roda
   (`AnomalyService.Running` / `IsTension`), por `AfterAnomaly` s depois dela, por `MinGap` s depois do último evento,
   enquanto há um evento vivo (um por vez) e enquanto o showcase segura a agenda (`AnomalyService.DevHeld`).
3. **Onde**: sorteia um evento aberto na noite (`Weight`) e embaralha os spots dele; vale o primeiro em que **nenhum
   jogador Active** olha (`AnomalyService:Looking`, cone `HiddenAngle` até `HiddenRange`, linha de visão: atrás de
   parede = não olha) e ninguém está a menos de `MinDistance`. Nenhum livre = tenta de novo em `Retry` s; passou da
   janela = cai.
4. **Vivo** `Life` s. A 5 Hz guarda quem teve o Gaze dentro de `SeenAngle` (o Gaze é 10 Hz e chega atrasado).
5. **Visto**: `SuspenseSeen` vale se o `Id` é o do evento vivo (+1 s de folga), o jogador está Active, ainda não pagou e
   o Gaze é plausível (dentro de `SeenAngle` agora ou em algum tick do evento). Custo sorteado **uma vez por evento** em
   `Cost`; `VitalService:AddSanity(player, -custo, "suspense:<key>")`; sinal `Caught(key, player, custo)`.
   Coop: só checagem de formato e plausibilidade (R10), como o `Gaze`.

## 5. Client (`SuspenseController`)

- No packet: `Hide.Build(Style, Asset)` na pasta `Workspace.SuspenseEvents`, `ScaleTo(Event.Scale × Spot.Scale)`, pose do
  spot. Sem som ao aparecer (o susto é o relance).
- **Relance** (RenderStepped): câmera em `FirstPerson`, a cabeça na tela (fora da margem `ScreenMargin` das bordas), até
  `SeenRange` e com linha livre da câmera. Uma vez por evento:
  - `SuspenseSeen` ao servidor;
  - `CameraController:HorrorPull(cabeça, Pull, Duration)` (novo: o mesmo puxão do `HorrorNudge`, teto `MaxPull`),
    `HorrorFov(Fov, 0, Duration + 0,5)`, `HorrorShake(Shake)`;
  - `suspense_drop` na tela + `suspense_hiss` na criatura (ambos `Scare`, DEC-173);
  - `Screen.Pulse(Pulse)` + `Screen.SetVignette(Vignette → 0, VignetteFor, "suspense")`;
  - depois do puxão, `Whispers.Play(Words, Words.suspense)`;
  - a criatura some `Linger` s depois.
- Sem relance até o fim de `Life`: some sozinha.
- `Motion.Reduced()`: a API de câmera já escala por `ReduceMotion` e `Screen.Pulse` não roda.
- Reset do personagem: criatura e bordas somem.

## 6. Dev

`/dev suspense` (evento aleatório num spot livre) · `/dev suspense <spot>` (força o spot, mesmo com alguém olhando) ·
`/dev suspense <evento> [spot]` · `/dev suspense list` · `/dev suspense status` (agenda da noite, evento vivo, anomalia
segurando). Funciona em qualquer fase/noite, mas a sanidade só cai à noite (fora dela o Gaze não chega ao servidor).

## 7. Pendências (Provisório)

- Level-designer: criar os MapPoints `SUS-PREP`, `SUS-DT`, `SUS-PANTRY`, `SUS-STREET` (até lá valem as coordenadas).
- Art-director: arte da criatura (`Asset`) no lugar do placeholder; o Sorriso pode ganhar modelo próprio.
- `floor_scratch` (SFX-246) sem candidato seguro (Id vazio).
