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

> **TASK-467 (2026-10-18):** no restaurante o escuro dura **15 s** até o ataque (`RestaurantWindow`), então a cena real
> comprime a tabela abaixo: HIDE + vinheta 2–11 s, passos 7–13 s, sombra 11 s, maçaneta/empurrão/trinco 13,4–15 s, olhos e
> passos indo embora na fase Failed; luzes, estalo, música e legenda continuam com o efeito ANM-020 e o Score. Fonte da
> verdade: `Content.HorrorScenes`. A porta dos fundos fica travada localmente durante o escuro (`DoorHeld`, Provisório).

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

---

## 6. Roteiro revisado com o dono (2026-10-18, DEC-294)

O apagão virou a referência ("efeito de cinema"). As outras anomalias precisam do mesmo peso. Ajustes do dono sobre o §3:

| Anomalia | Decisão / ajuste | Roteiro proposto |
|---|---|---|
| ANM-018 O Sorriso | não há janela visível de dentro além do **drive-thru**; a janela do drive-thru precisa fechar junto com a principal | Vira o **primeiro evento de suspense** (§7): a criatura preta grande aparece **num lugar que ninguém está olhando** (bancada ou janela do drive-thru); quem olhar de relance tem a **câmera sequestrada** (zoom curto nela) com um som grave; −5 a −10 de sanidade; some. Uma versão "anomalia" do Sorriso fica para depois |
| ANM-017 Rastejador | aprovado ("subir no balcão") | arranhão sob o assoalho → corre pela cozinha → os jogadores precisam **sair do chão** (subir no balcão); quem fica no chão quando ele passa paga |
| ANM-012 Pescoço invertido | gostou, mas falta terror | soma a **pressão de encarar** (§8): encarar demais faz a cabeça girar devagar seguindo o jogador, estalos, coração acelera, bordas da tela escurecem piscando, sanidade cai, whispers "STOP STARING", "DON'T LOOK" |
| ANM-004 A Cópia | gostou; ligar à pressão mental | a cópia vira a cabeça antes; encarar ativa a pressão (§8) com distorção leve do rosto; whispers trocam para "DON'T LOOK AT IT" |
| ANM-019 Sombra no teto | conceito "genial", mas não há nada que leve o jogador para fora | **replanejar**: em vez de punir quem sai, punir **quem olha para cima** ou **quem olha as câmeras** enquanto ela anda no teto (Q-367) |

## 7. Eventos de suspense (novo sistema, DEC-294)

Sustos que **não são anomalias**: sem regra para resolver, sem aviso padrão, aleatórios, para o jogador nunca se sentir seguro
("não sempre aviso e gatilho").

- Um evento escolhe um ponto **fora da tela de todos** (bancada, janela do drive-thru, fim da rua, despensa) e aparece ali.
- Quem o vê de relance (entra no campo de visão perto da borda) tem a câmera puxada para ele: zoom ~0,4 s, som grave
  ("sub drop"), −5 a −10 de sanidade (Provisório). Some em seguida.
- Frequência baixa e aleatória por noite (Provisório: 1–3 por noite a partir da noite 2; nunca durante uma anomalia ativa).
- Usa os modelos de monstro que já existem (silhueta preta, olhos brancos). Mild: o susto é curto.

## 8. Pressão de encarar (novo sistema, DEC-294)

Encarar uma anomalia de cliente (pescoço invertido, cópia, olhos brancos) por tempo demais tem custo:

- Depois de ~2 s olhando direto: coração começa e acelera; bordas da tela escurecem piscando de leve ("glaucoma");
  a cabeça do cliente vira para seguir o jogador; whispers trocam para "STOP STARING", "DON'T LOOK".
- Continuando: sanidade cai aos poucos; o rosto distorce de leve (escala/rotação das partes do rosto; EditableMesh só se
  der certo — Q-368).
- Olhar para longe solta tudo em ~1 s. Respeita `Motion.Reduced()`.
