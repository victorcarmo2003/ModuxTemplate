Status: Rascunho (Provisório) — pilar aprovado pela DEC-290; tempos e números abaixo são proposta

# Terror cinematográfico — anomalias como cena dirigida

Autores: game-designer + art-director (2026-10-18). Fonte: DEC-290 (fala do dono), DEC-283, DEC-286, DEC-287, DEC-289 (M4),
DEC-172 (Mild). Base técnica já existente: `AnomalyController/Effects/Kit` (Blackout, Bell, Hide, Jumpscare, Whispers, Fade…),
`AtmosphereController` (Rain, Lightning), música em passos (TASK-443), apagão de terror (TASK-444), `CameraController`
(Shake/Tilt/FOV).

---

## 1. Ideia

Hoje a anomalia **acontece**. A partir da DEC-290 ela **entra em cena**: cada uma tem um roteiro curto em que som, luz,
efeito de tela e câmera sobem juntos, e o jogador sente que algo está chegando antes de ver. O medo vem da **espera**, não
do susto.

Curva de toda cena (vale para todas as anomalias, com durações diferentes):

| Fase | Para que serve | Ferramentas |
|---|---|---|
| **Calma** | o jogador está trabalhando; contraste para o que vem | música base, luz normal |
| **Aviso** | "algo mudou" — um detalhe, não um susto | um som fora do lugar, luz que pisca, olhos no escuro (M4) |
| **Escalada** | o perigo cresce e o jogador decide o que fazer | "HIDE" na tela em rampa, violinos acelerando, passos, vinheta |
| **Chegada** | a criatura está perto | silêncio curto, passos param, câmera respira |
| **Clímax** | o momento que vira história | maçaneta, batida na porta, jumpscare curto (opcional) |
| **Alívio** | soltar a tensão e voltar ao trabalho | luz volta, música calma, respiro do personagem |

Regras fixas:
- **Mild** (DEC-172): nada de sangue; susto curto (≤ 1 s) e raro; sem grito alto estourado (limitador no mix).
- A câmera **nunca tira o controle** por mais de ~2 s; tudo que mexe a câmera respeita a opção **"Reduzir movimento"**
  (shake e FOV ficam a 25 %).
- **Mesma cena para todos** no servidor: o servidor manda o início e a semente; cada client toca a mesma linha do tempo.
- Toda cena tem **saída clara** (o que fazer) — a regra da anomalia não muda, só a apresentação.

## 2. A cena do apagão (referência do dono, DEC-290)

Duração alvo ~40–55 s da queda até a luz voltar. Tempos em segundos a partir da queda. Tudo **Provisório**.

| t | Passo (fala do dono) | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| −8 a 0 | (aviso, opcional) | zumbido elétrico subindo, lâmpada estalando | 1–2 piscadas das luzes da cozinha | — |
| **0** | **todas as luzes apagam** | **"clunk" do quadro geral** + queda do zumbido para silêncio | blackout total (DEC-286), só a emergência vermelha | tranco curto (shake 0,15 s), FOV −3° e volta |
| 1,5 | **o sino toca** (já existe) | sino com reverb longo | — | texto de aviso na tela (DEC-283) |
| 3 | **o "HIDE" começa a aparecer, pouco** | — | poucas palavras "hide" sussurradas na tela (`Kit/Whispers`) | — |
| 3–18 | escalada | violinos acelerando (TASK-443) | **"HIDE" em rampa**: taxa 0,4 → 3, até as palavras tomarem a tela ("em massa") | vinheta escura entra devagar (0 → 0,35) |
| ~12 | jogadores correm para os fundos | próprios passos ecoam mais | **luz debaixo da porta da despensa** (fresta vermelha/quente no chão) guia o caminho | — |
| 18 | **passos começam** | passos pesados, do lado de fora, se aproximando (pan 3D, cada vez mais perto) | as palavras param de repente | música corta para um pedal grave |
| 18–30 | chegada | passos, respiração do personagem do jogador (abafada) | a fresta de luz debaixo da porta é **cortada por uma sombra** quando a criatura passa | câmera "respira" (FOV ±1° lento), shake mínimo a cada passo |
| ~30 | silêncio | **os passos param** na frente da porta; 2 s de nada | — | vinheta aperta (0,45) |
| **~32** | **a criatura tenta abrir a porta uma vez** | **maçaneta girando e travando** (2 tentativas rápidas), **porta forçando no batente** | a porta treme (anim. de 0,6 s); poeira cai do batente | shake curto na direção da porta |
| ~34 | **não consegue** | **"trava" metálico** + um último empurrão abafado | sombra sai da fresta | — |
| 36–45 | ela vai embora | passos se afastando; coral de horror some (DEC-283) | — | vinheta sai |
| ~45 | alívio | disjuntor/energia volta: "thunk" + zumbido voltando + música calma | luzes voltam piscando em cascata | expiração do personagem; FOV volta |

Quem **não** se escondeu: quando os passos param, a criatura "olha" pela janela (olhos brancos no vidro, 1 s) e o erro da
anomalia acontece pela regra que já existe (o pacote de erro não muda). Jumpscare só aqui, curto e Mild.

## 3. O mesmo pilar nas outras anomalias (resumo para o roteiro de cada uma)

| Anomalia | Aviso | Escalada | Clímax |
|---|---|---|---|
| ANM-007 The Walker | olhos brancos sob o poste do fim da rua (M4) | a cada piscar do poste ele está um poste mais perto; passos com eco | para do lado de fora da janela, a luz da janela recorta a silhueta |
| ANM-018 O Sorriso | um zumbido grave, os letreiros piscam | o sorriso aparece rápido na janela e some (1 frame mais a cada vez) | rosto inteiro na janela de serviço, câmera puxa 2° para ele |
| ANM-017 Rastejador | arranhado no telhado/assoalho | arranhado corre de um lado ao outro | algo passa rápido por baixo do balcão (só a sombra) |
| ANM-012 Pescoço invertido | o cliente da fila para de mexer | a cabeça gira devagar com estalos | encara a câmera do jogador quando ele olha |
| ANM-020 Apagão | ver §2 | | |

## 4. Kit técnico (o que precisa existir uma vez e serve a todas)

1. **Sequenciador de cena** (`HorrorScene`): linha do tempo em dados (`Content.HorrorScenes.<Key>` = lista de passos
   `{t, kind, args}`), tocada no client a partir de `startTime` + `seed` mandados pelo servidor. Tipos de passo: `Sound`,
   `Light` (preset/flicker/cascata), `Lightning` (rampa de intervalo), `Vignette`, `CameraShake`, `CameraFov`,
   `CameraNudge` (olhar puxado ≤ 3°), `Text`, `Actor` (criatura/sombra em ponto do mapa), `Door` (tranco/maçaneta).
2. **Câmera de terror**: perfis de shake (tranco, passo, porta), "respiração" de FOV, nudge leve; todos atenuados pela
   opção "Reduzir movimento".
3. **Efeitos de tela**: vinheta animada, leve grão/aberração só no clímax (≤ 0,3 s), clarão do raio.
4. **"HIDE" em rampa**: o `Kit/Whispers` (palavras na tela) tocado com taxa que sobe ao longo da cena (DEC-291).
   Os raios do `Lightning` seguem disponíveis para outras cenas, mas não entram no apagão.
5. **Porta da despensa "viva"**: fresta de luz no chão (Neon fino + `SurfaceLight` fraca), sombra que cruza a fresta,
   animação de tranco e sons de maçaneta.
6. **Banco de sons** (entradas em `audio/sound-list.md`): quadro geral caindo, zumbido elétrico (subir/cair), trovão
   perto/longe, passos pesados (madeira/asfalto), passos parando, maçaneta travada, porta forçando, trava metálica,
   respiração abafada do personagem, energia voltando, cascata de lâmpadas acendendo.

## 5. Perguntas (lote, não bloqueiam)

- ~~"Raid, devagar" = raios?~~ **Respondida (DEC-291):** é o texto **"HIDE"** na tela, pouco no começo e em massa no fim.
- Quem não se escondeu: jumpscare curto na janela (proposta) ou só o erro da regra, sem susto?
- Opção "Reduzir movimento": o jogo **já tem** `Motion.Reduced()` (Interface/Components/Motion); a câmera de terror usa ela
  (Provisório, Q-357).
