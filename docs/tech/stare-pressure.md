Status: Rascunho (TASK-482; DEC-294, DEC-295 Q-368 A; design/horror-cinematic.md §8). Números Provisórios até o Play do dono.

# Pressão de encarar (stare pressure)

Encarar demais uma anomalia de cliente tem custo. Vale para as linhas de `Content.Anomalies` com `Stare = true`:

| Anomalia | Por quê |
|---|---|
| ANM-012 Pescoço invertido (`anm_012_turned_neck`) | a cabeça virada passa a seguir quem encara |
| ANM-004 A cópia (`anm_004_copies`) | whispers próprias: "DON'T LOOK AT IT" (`Words.stare_copy`) |
| ANM-013 Olhos brancos (`anm_013_white_eyes`) | olhos brancos + rosto distorcendo |

`Validate` exige ator `Customer` com `SeeMode Cone` (o alvo é a cabeça do rig).

## 1. Linha do tempo

Mesmo cone e mesmos tempos nos dois lados (`Content.Sanity.Stare`, partilhado):

| t encarando (cone `Angle` = 18°, até `ViewRange`, linha de visão) | O que acontece |
|---|---|
| 1 s (`Sanity.SeeTime`, cone largo `SeeAngle`) | "viu a anomalia": −5 uma vez por noite (`SeeAnomaly`, já existia) |
| 2 s (`Delay`) | começa a pressão no client: coração, bordas, whispers, cabeça seguindo, rosto |
| 3 s (`DrainAfter`) | servidor começa a drenar: −1,5/s (`PerSecond`), no máximo −20 por ocorrência por jogador (`Cap`) |
| 2 s + 6 s (`HorrorScenes.Stare.Build`) | pressão no pico |
| olhou para longe | pressão cai a 0 em 1 s (`Release`); 1 s longe zera a contagem (servidor e client) |

Sem cobrança dupla: a visão (−5) é uma vez por noite e acontece antes; o encarar só drena depois de `DrainAfter` (> `SeeTime`
e ≥ `Delay`, o `Validate` cobra) e tem teto por ocorrência. Encarar ~10 s custa ~−10 além da visão.

## 2. Servidor (`AnomalyService`)

- Nada de rede nova: usa o `Gaze` (c→s, 10 Hz) que a câmera já envia em primeira pessoa à noite.
- `SeenTick` (chamado pelo `Kit/CustomerActor` a 5 Hz com a cabeça do ator) chama `StareTick` quando a linha tem `Stare` e o
  registro está `Active`. `StareTick` usa `Looking(player, cabeça, ViewRange, Stare.Angle)` (mesmas regras: Active, não
  protegido no trailer, não nas câmeras de segurança, linha de visão).
- Estado por ocorrência e por `UserId` (`Run.Stares`: `Time`, `Away`, `Owed`, `Taken`). A sanidade só muda em pontos
  inteiros (`VitalService:AddSanity` arredonda), então a fração fica em `Owed`. Causa: `stare:<key>`.

## 3. Client (`AnomalyController/Stare.luau`)

Só apresentação (T10). Alvo = cabeça do ator (`Anchor`) da ocorrência `Active` com `Stare`, com a câmera própria em primeira
pessoa (`CameraController:IsFirstPerson`), personagem vivo, dentro do cone e com linha de visão (lido a cada 0,1 s).
A pressão 0..1 conduz:

- **coração**: batidas soltas (`Content.Sounds.heartbeat`, como o passo `Heartbeat` da cena) de 72 a 140 BPM;
- **bordas "glaucoma"**: canal `stare` do `Kit/Screen` até 0,42 com tremulação ±0,08 (sem tremulação com `Motion.Reduced()`);
- **whispers**: `Kit/Whispers.Stream` com a lista `Words.stare` ("STOP STARING", "DON'T LOOK"…) ou a da anomalia;
- **cabeça seguindo**: a cabeça gira devagar para a câmera (28°/s no pico, até 150° além da pose), pelo `C1` do `Neck`
  (os modificadores da família A escrevem o `C0`, então o pescoço do ANM-012 continua valendo);
- **rosto**: a casca `Face` do CrewRig fica mais alta e estreita (até 14 %) e balança ±9° (Q-368 A, sem EditableMesh).

Cabeça e rosto voltam à pose do servidor quando a pressão cai. Números em `Content.HorrorScenes.Stare`.

## 4. Como testar (Play)

1. Noite em andamento: `/dev anomaly ANM-012` (depois `ANM-004`, `ANM-013`). Ficar em primeira pessoa no balcão.
2. Olhar direto para a cabeça do cliente: ~2 s depois coração, bordas e whispers; a cabeça começa a seguir; o rosto distorce.
3. Ficar mais ~1 s: a sanidade cai 1–2 por segundo e para em −20 (mais os −5 da visão, uma vez por noite).
4. Desviar o olhar: tudo some em ~1 s; voltar a olhar antes de 1 s retoma de onde estava.
5. Com movimento reduzido ligado: sem tremulação das bordas; o resto igual.
