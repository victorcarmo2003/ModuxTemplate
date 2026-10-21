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

## 3. O padrão do apagão em todas as anomalias do restaurante (roteiros, 2026-10-18, Provisório)

Autores: game-designer + art-director. Substitui o resumo antigo deste § (Walker e Sorriso saíram do restaurante, TASK-390;
Rastejador, Pescoço e Cópia já têm roteiro em §6/§9). Nenhuma regra muda: o verbo, o prazo e a penalidade continuam os de
`Rules/ANM-xxx`; o roteiro só dirige a apresentação. As anomalias que já têm cena curta em dados (`oddScene`, §9) ganham aqui
a versão completa; ANM-006, 008, 010 e 021 já têm cena em `Content.HorrorScenes` e aqui sobem para o padrão do apagão.

**O padrão (régua do dono, DEC-290):** poucos sinais → muitos sinais → **um silêncio** → pico alto e monstruoso → alívio.
Sempre: respiração/coração, borrão ou cor (Grade/Blur), e **uma tarefa simples sob nervos** (fechar, recusar, apagar,
servir, não olhar). Jumpscare só no **Failed** para quem errou (`Who = Caught`), ≤ 1 s, Mild (DEC-172).

Notação do `t`: **S+n** = n s depois do início do Signal; **A+n** = do Active; **R+n** / **F+n** = do Resolved / Failed.
"Fora" = o que muda para quem está fora da loja (§3.0).

### 3.0 Jogador fora da loja (mesas, drive-thru, rua)

O restaurante tem jogador do lado de fora (mesas da calçada, pista do drive-thru, rua; a cena pessoal do `OutsideController`
começa quando ele sai). Quando uma anomalia começa com alguém fora:

| Regra | O que faz |
|---|---|
| Quem decide "fora" | o atributo que o servidor já põe (`OutsideStage` ≠ nil no LocalPlayer, `OutsideService`). Nada novo no fio |
| Passo novo `Where` | cada passo pode dizer `Where = "Inside"` ou `"Outside"` (nil = os dois). A cena padrão serve aos dois; as linhas **Fora** abaixo são os passos `Outside` |
| A cena manda na tela | enquanto uma cena de anomalia toca, a subida do `OutsideController` (Rise) **pausa** suas camadas de tela (palavras, coração, barras) para não dobrar; o relógio de 30 s do servidor não muda |
| Som | as fontes 3D ficam nos pontos do mundo (sino, vidro, carro): de fora se ouve **mais perto e sem parede**; o coração começa +15 BPM |
| Palavras | nas cenas de "dentro" (recusar, fechar) a lista troca para `outside` ("GET INSIDE", "IT'S NOT SAFE OUT HERE") até ele entrar |
| Tarefa | sempre a mesma: **voltar para dentro**; a seta 3D (`Interface/Arrow3D`, a da ANM-010) aponta a porta mais perto nos primeiros 4 s |
| Mesas da calçada | vê pelo vidro o que acontece no balcão (a luz e o cliente), mas de costas para a rua: a cena põe **um sinal atrás dele** (som 3D na rua, olhos no escuro 1 s) |
| Pista do drive-thru | é o lugar mais exposto nas anomalias de rua (008, 021): farol/névoa chegam nele primeiro |
| Rua | longe da loja: recebe só som distante + palavras `outside`; a regra da anomalia e a caçada do `OutsideService` seguem como estão |

### 3.1 ANM-001 Sem rosto (família A, tablet, recusar = FRONT, sem prazo; estreia N1)

Estreia da primeira noite: é a aula do padrão em versão suave (sem passos, sem monstro).

| t | Passo | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| S+0 | o tablet toca o pedido "errado" | `phone_glitch` curto, ding do tablet com pitch caindo | a lâmpada sobre o tablet pisca 2× (`Lights` Point) | — |
| A+0 | cliente parado no tablet, cabeça baixa | música Uneasy | — | barras finas (`Cinema` 0,08) |
| A+2 | **ele levanta o rosto: liso** | sub grave curto (`horror_sting` 0,4) | `Pose` Lift: a cabeça sobe devagar; rosto sem traços | `Nudge` 1,5° para ele (só a < 20 studs) |
| A+3–10 | escalada | coração 70→115 | palavras `blank` 0,3→1,3 ("HE HAS NO FACE / DON'T TAKE IT") | vinheta 0→0,2, `Grade` Cold 0→0,3 |
| A+10 | **silêncio** | `Silence` 1→0,4 em 1,5 s; palavras param | `Pose` Tilt: a cabeça inclina para o lado, 2 s parada | — |
| R+0 (FRONT desceu) | alívio com réplica | batida metálica da persiana; **1,5 s depois uma batida de dedo do outro lado** | luz do tablet volta | tranco leve (`Shake` Jolt 0,5), `breath_held` |
| F+0 (aceitou) | pico | — | o rosto liso enche a tela | Caught: `Kit/Jumpscare` 0,6 s + `Grade` Red + `Blur` 12→0; Safe: tranco |
| Fora | — | ding do tablet ouvido pela porta | olhos na rua atrás dele, 1 s | palavras `outside` |

### 3.2 ANM-005 Raincoat Lady (família A, exceção: **servir**, paciência 60 s; estreia N5)

A tensão é o prazo visível: a poça cresce. Ela não é ameaçadora — o erro é fechar nela ou demorar.

| t | Passo | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| A+0 | ela chega pingando | chuva aumenta perto da porta, trovão longe (`Lightning` 1 raio distante) | — | — |
| A+2 | a poça começa | goteira em loop na retirada | `Prop` Puddle: poça cresce dos pés dela | — |
| A+5 | dica | — | palavras `raincoat` 0,3→0,8 ("SERVE HER / DON'T CLOSE ON HER") | barras finas |
| A+30 | meia paciência | coração 80→130 em 25 s; goteira mais alta | a poça chega à borda do balcão | vinheta 0,1→0,3, `Grade` Cold 0,25 |
| A+52 | **silêncio** | a goteira **para**; `Silence` 0,35 | `Pose` Lift: ela ergue o capuz devagar (só a boca, sorriso fechado) | — |
| R+0 (servida) | alívio | goteira volta baixa, porta, chuva | ela acena e sai; a poça seca em 10 s | `breath_held` |
| F+0 (fechou / tempo) | pico | trovão perto, água correndo | a poça corre sob o balcão até os pés de quem errou; luzes piscam | Caught: rosto sob o capuz (Jumpscare 0,6 s) + Blur; Safe: Shake |
| Fora | — | goteira atrás dele | em A+30 ela aparece **de pé na chuva perto das mesas** olhando para ele (olhos 1,5 s) | palavras "SHE'S WAITING / GET INSIDE" |

### 3.3 ANM-006 O da parada (stalker, família B, **não olhar**; fechar a janela quando ele chega, 20 s; estreia N6)

| t | Passo | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| S+0 | aviso | zumbido do poste da parada sobe | o poste da parada pisca 3× | — |
| S+2 | olhos no fim da rua | — | `Actor` olhos em AN-B, 1,5 s | — |
| A+0–14 | escalada | coração 72→150 em 18 s; **cada olhada = um passo** com eco (já na regra) | palavras `stalker` 0,4→2,5 | `Grade` Cold 0→0,4; a cada passo dele um pulso de `Blur` 3→0 (0,4 s) e de vinheta |
| A+14 | **silêncio** | `Silence` 0,3; palavras cortam | — | vinheta aperta 0,45 |
| A+16 | ele está no vidro | respiração lenta do outro lado | `Glass` Fog: o vidro embaça na altura do rosto | `Text` "CLOSE THE WINDOW!" |
| A+18 | **uma batida de dedo no vidro** | `Glass` Knock | — | tranco mínimo |
| R+0 (fechou) | alívio | persiana desce; **a palma escorrega do outro lado** (rangido); passos indo | `Glass` Hand: marca da palma que some | `breath_held`, tudo volta em 2 s |
| F+0 | pico | — | o rosto prensado no vidro para onde ele olha | Caught: Jumpscare 0,6 s + Grade Red; Safe: `Glass` Bang na vitrine |
| Fora | — | passos dele **atrás** do jogador, não na rua | olhos na borda da luz mais perto do jogador | palavras "DON'T LOOK BACK / GET INSIDE"; o Rise do `OutsideController` salta para o fim (só tela) |

### 3.4 ANM-008 Carro comprido (drive-thru, DRIVE e manter, 8 s + 15 s; estreia N8)

| t | Passo | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| S+0 | aviso | motor grave longe, pan lento; rádio da loja chia 1 s (`Kit/Radio`) | faróis no fim da rua | — |
| S+3 | buzina | buzina longa, **lenta e grave** (pitch 0,7) | — | barras (`Cinema` 0,1) |
| S+4–8 | escalada | coração 70→140 | palavras `car` 0,5→2 ("CLOSE THE WINDOW / KEEP IT SHUT") | `Shake` Rumble contínuo fraco crescendo |
| A+0 | entra na pista | pneus no cascalho, motor alto | `Glare` Sweep: a luz do farol varre o teto pela janela do drive | vinheta 0,2→0,4 |
| A+6 | **freia na janela** | freio guinchando, tranco; motor **desliga** | — | `Shake` Jolt; **`Silence` 0,2, 2 s de nada** |
| A+8 | pico | uma buzinada curta, seca | `Glare` Flash: farol alto pela janela (branco, `Blur` 6→0 em 0,6 s) | `Fov` −3 e volta |
| A+8–23 | segurar | batidas na persiana do drive a cada 3–4 s, cada vez mais fortes | `Glass` Rattle na persiana do drive | tranco curto em cada batida |
| R+0 | alívio | motor liga; **o carro passa por 6 s** (comprido demais) | a luz varre e vai embora | `breath_held` |
| F+0 | pico | porta do carro abrindo | — | Caught: Jumpscare (motorista) 0,6 s; Safe: Glare 1 s |
| Fora | — | o motor vem **atrás dele** na pista | o farol fixa nele; a sombra dele se estica para a frente | palavras "GET OFF THE ROAD / GET INSIDE"; seta para a porta |

### 3.5 ANM-010 The Hush (família C, apagar a luz da loja e manter, 15 s + 15 s; estreia N10)

O inverso do apagão: o jogador **escolhe** o escuro. O som some todo — é a cena do silêncio.

| t | Passo | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| S+0–6 | aviso | a cada poste que apaga um "tunk" e o ambiente cai um degrau (`Silence` 1→0,5) | postes da rua apagam um a um, do fim da rua para a loja (já existe) | — |
| S+6 | hush | **vento e chuva param**; só o coração, lento (55) | — | barras |
| S+8 | tarefa | — | seta no interruptor (já existe); palavras `hush` 0,3→1,5 | `Text` "TURN OFF THE LIGHTS" |
| A+0 | o último poste apaga | — | `Grade` Cold 0,4 | vinheta 0,3 |
| A+? (apagou) | escuro escolhido | `Silence` 0,1: só respiração e coração | palavras param (o Hush não fala) | — |
| A+6–12 | ele passa | drone grave baixo cresce | `Silhouette` Pass: uma forma enorme cruza as vitrines por fora | `Fov` +1 lento |
| A+12 | **silêncio** | o drone **corta**; 2 s de nada | a forma para na vitrine maior | vinheta 0,45 |
| A+15–30 | segurar | um rangido de vidro a cada ~4 s; coração 55→90 | — | — |
| R+0 | alívio | ambiente volta de longe para perto | postes acendem em cascata | `breath_held` |
| F+0 (luz acesa) | pico | estalo elétrico | luzes de dentro dão um **flash branco** e morrem | Caught: Jumpscare 0,6 s; Safe: Shake |
| Fora | — | os "tunks" vêm **na direção dele** | os postes apagam até o poste dele | palavras "GET INSIDE, IT'S TOO QUIET"; seta para a porta |

### 3.6 ANM-011 O que treme (família A, recusar; estreia N2)

A v3 (§8.1) marcou "sai: tremor ilegível no celular". A cena resolve a leitura com o **ambiente tremendo**, não o corpo (Q-389).

| t | Passo | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| A+0 | chega | xícara/garrafas vibrando no balcão | `Prop` Shake: garrafas e copos perto do tablet tremem | — |
| A+2 | dica | — | palavras `shaker` 0,3→1 | barras finas |
| A+4–8 | escalada | vibração sobe de tom; coração 75→120 | a lâmpada sobre o tablet balança (`Prop` Sway) | `Shake` Tremor (micro) a < 15 studs |
| A+8 | **silêncio** | **para tudo de uma vez** | ele olha para cima, imóvel (`Pose` Lift) | — |
| R+0 | réplica | **uma pancada forte na persiana** do lado de fora | — | `Shake` Jolt, `breath_held` |
| F+0 | pico | — | rosto vibrando rápido | Caught: Jumpscare 0,6 s; Safe: tranco |
| Fora | — | a vibração chega pelo chão | as mesas da calçada vibram | palavras `outside` |

### 3.7 ANM-013 Olhos brancos (família A, linha 1, recusar; estreia N5 calada)

| t | Passo | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| S+0 | a luz do tablet cai a 30 % | zumbido baixa | — | — |
| A+0 | **os olhos acendem** | "whoom" suave | `Pose` Lift + olhos brancos | — |
| A+1 | **todos os clientes Night viram para o jogador** juntos | um estalo seco | `Pose` Turn em grupo | `Grade` Cold 0→0,3 |
| A+2–8 | escalada | coração 70→125 | palavras `white_eyes`; **pares de olhos aparecem nas vitrines**, um a um (`Actor` olhos, 4 pontos, 1,5 s cada) | vinheta 0→0,25 |
| A+9 | **silêncio** | `Silence` 0,3 | todos os olhos de fora apagam juntos; só os do tablet ficam | — |
| R+0 | réplica | persiana | os olhos **brilham entre as lâminas** 1 s e apagam | `breath_held` |
| F+0 | pico | — | clarão branco e os olhos na tela | Caught: Jumpscare 0,6 s; Safe: tranco |
| Fora | — | — | os olhos aparecem nas janelas **olhando para fora**, para ele | palavras `outside` |

### 3.8 ANM-014 Cabeça errada (família A, recusar; apresenta a N6 no restaurante)

| t | Passo | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| A+0 | cliente normal | — | — | — |
| A+2/5/8 | **a cabeça cresce aos degraus**, sempre quando o jogador desvia o olhar | rangido de couro esticando a cada degrau | `Pose` Scale 1→1,3→1,6→1,9 | `Fov` −1 a cada degrau |
| A+3–9 | escalada | coração 70→120 | palavras `big_head`; a cabeça encosta na luminária, que balança | barras, `Grade` Sick 0→0,2 |
| A+9 | **silêncio** | `Silence` 0,35 | a cabeça inclina para olhar pela janela de serviço | `Nudge` 2° para ela |
| R/F | como §3.1 | | | |
| Fora | — | — | a cabeça vira 180° para seguir o jogador pela vitrine | palavras `outside` |

### 3.9 ANM-015 Flutuando (família A, recusar)

A v3 marcou "sai: 20 cm é sutil". A cena torna legível com o **entorno** subindo junto (Q-389).

| t | Passo | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| A+0 | os pés saem do chão | zumbido subindo de tom | `Pose` Float até 0,6 stud (mais que a regra; só visual) | — |
| A+2–8 | escalada | coração 70→115 | guardanapos e copos perto **sobem devagar** (`Prop` Float); **a sombra dele fica no chão** | palavras `floater`, `Grade` Sick 0,2 |
| A+8 | **silêncio** | o zumbido corta | — | — |
| A+9 | queda | baque seco | tudo cai junto | `Shake` Jolt 0,4 |
| R/F | como §3.1 | | | |

### 3.10 ANM-016 Não pisca (família A, recusar; pressão de encarar §8)

| t | Passo | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| A+0 | chega | relógio da loja tiquetaqueando alto | os outros clientes piscam juntos (textura do olho, a cada 3 s); ele não | — |
| A+2–9 | escalada | o tique **desacelera**; coração 70→120 | palavras `starer`; encarar ativa a pressão (§8) | vinheta 0→0,2 |
| A+9 | **silêncio** | o relógio **para** | — | — |
| A+10 | pico | — | **ele pisca uma vez — e todas as luzes piscam com ele** (`Lights` Flicker 0,1 s) | tranco mínimo |
| R/F | como §3.1 | | | |

### 3.11 ANM-019 Sombra no teto e ANM-021 Névoa vermelha

- **ANM-019**: roteiro completo em §6.1 (TASK-484). Falta só **Fora**: o jogador fora vê **a forma em cima do telhado**
  (silhueta contra o céu, 2 s) e os passos andam para a borda do lado dele; "GET INSIDE / DON'T LOOK UP" ao mesmo tempo
  (olhar para cima continua contando).
- **ANM-021** (cena já em dados, aqui a tabela para o doc):

| t | Passo | Som | Luz / VFX | Câmera / tela |
|---|---|---|---|---|
| S+0 | a névoa sobe vermelha na rua | sino (1ª) | névoa (Effects/ANM-021) | `Grade` Red 0→0,55 em 11 s, barras |
| S+1–11 | escalada | sino em S+4 e S+8, mais alto; coração 70→145 | palavras `red_fog` 0,4→2,4 ("CLOSE THE WINDOW") | vinheta 0→0,35 |
| S+8–11 | **silêncio** | `Silence` 1→0,4; palavras param em S+11 | — | — |
| A+0–14 | as pancadas | batidas fortes nos vidros com silêncio entre elas, **a maior por último** | `Glass` Bang nas vitrines (hoje no Effects) | tranco em cada pancada |
| R/F | alívio / pico | a névoa recua (Linger 5 s) | — | Caught: Jumpscare + desmaio (regra) |
| Fora | — | as pancadas **em volta dele** (passos na névoa) | névoa mais densa, `Blur` 0→8 | palavras "GET INSIDE"; a regra já cobra quem está fora |

### 3.12 Família D — mini-cenas (sustos sem verbo, 4–8 s)

Mesmo arco em miniatura: **detalhe → silêncio de 1 s → pico pequeno → solta**. Sem jumpscare (DEC-256), sem sanidade
extra. Só para os que valem uma cena; os outros (`grill_hiss`, `bottle_fall`, `sign_word`, `mart_sign_blink`) ficam como estão.
Cada um também serve de **prenúncio** de uma Noite-assinatura (§10).

| Susto | Arco (t em s) | Kit | Fora | Prenuncia |
|---|---|---|---|---|
| `roof_knock` | 0 três batidas no teto · 1,5 silêncio (`Silence` 0,5) · 2,5 **uma 4ª batida bem em cima** + poeira | Roof Thud, Silence | ouve no telhado da loja | ANM-019 |
| `window_face` | 0 vitrine embaça · 1 silêncio · 1,6 rosto 0,3 s · some | Glass Fog, Silence | rosto no vidro **de dentro** olhando para fora | ANM-006 |
| `monster_glimpse` | 0 poste do fim da rua pisca · 1 forma sob ele · 2 apaga e some | Lights Point, Actor | mais perto (meio da rua) | ANM-021 / Noite 6 |
| `street_watcher` | 0 figura parada longe · 3 ela vira a cabeça junto com a câmera · 4 some no piscar | Actor, Pose Turn | ele está entre o jogador e a porta (só visual) | ANM-006 |
| `radio_voice` | 0 estática · 1,5 silêncio · 2 uma frase lenta · 3,5 estática corta | Kit/Radio, Silence | sai do drive-thru | ANM-008 |
| `fake_call` | 0 toca · ao atender, respiração e "it's me" (eco de Walt) · desliga | FakeCall | toca o celular dele | ANM-009 (cena da sessão irmã) |
| `ghost_customer` | 0 cliente na fila · desviar e voltar: some · 1 s depois **o sino da porta toca sozinho** | GhostCustomer + Sound | uma cadeira da calçada arrasta | ANM-001 |
| `post_flicker` | postes piscam sem zumbido (DEC-123) · o último fica apagado 3 s | Lights Point | o poste dele | ANM-010 |

### 3.13 Peças novas do kit (além do que existe em `Scene/Kits` e `Effects/Kit`)

Reaproveitado sem mudança: Sound, Music, Lights, Text, Whispers, Heartbeat, Cinema, Vignette, Shake, Fov, Nudge, Actor (olhos e
modelo), Door, Shadow, Roof, HeadDown, Grade, Blur, Silence; `Kit/Jumpscare`, `Kit/Radio`, `Kit/Bell`, `Interface/Arrow3D`.

| Peça | O que é | Usada em |
|---|---|---|
| campo `Where` no passo | `"Inside"` / `"Outside"` / nil; lê `OutsideStage`; e a pausa das camadas do `OutsideController` enquanto uma cena toca | todas (§3.0) |
| `Pose` | mexe o `CustomerActor` da anomalia: Lift (ergue a cabeça), Tilt, Turn (um ou todos os clientes Night viram para o jogador), Scale (cabeça), Float, Blink | 001, 005, 011, 013, 014, 015, 016, D |
| `Glass` | vidro no MapPoint: Fog (embaça), Knock, Bang (vidro flexiona + poeira), Hand (palma escorrendo), Rattle (persiana do drive) | 006, 008, 021, D |
| `Prop` | objetos locais perto do Point: Shake, Float, Sway (luminária), Puddle (Grow / Flood) | 005, 011, 014, 015 |
| `Glare` | farol: Flash (bloom + Blur curto se o ponto está na vista) e Sweep (SpotLight que varre o teto) | 008 |
| `Silhouette` | forma grande que cruza por fora das vitrines (placa escura com recorte, só local) | 010, 019 Fora |
| `Lights` com Point | um poste/luminária só, e `Flash` (branco e apaga) | 001, 006, 010, 016, D |
| perfis de Shake | `Rumble` (contínuo baixo) e `Tremor` (micro) em `Rules.Shakes` | 008, 011 |
| `Echo` no passo | o passo entra na versão curta (retorno, §10) | todas |
| sons novos (`sound-list.md`, com placeholder até ter Id) | engine_rumble, tire_gravel, brake_squeal, horn_slow, glass_breath, glass_knock, palm_squeak, drip_loop, puddle_rush, cup_rattle, stretch_creak, float_hum, eyes_on, post_tunk, drone_low, clock_tick | — |

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
- Roteiros do §3, caso "fora da loja" e Noite-assinatura (§10): **Q-384..Q-389** em `open-questions.md`; tasks TASK-533..554.
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
| ANM-019 Sombra no teto | conceito "genial", mas não há nada que leve o jogador para fora | **Implementado (TASK-484, Q-367 A / DEC-295): "não olhe para cima"** — enquanto ela anda no teto, quem olha para cima paga; roteiro em §6.1 |

### 6.1 ANM-019 Sombra no teto — "não olhe para cima" (TASK-484, Provisório)

Regra (servidor, `Rules/ANM-019`, T10): enquanto ela anda, o servidor lê o `Gaze` de cada jogador ativo (pitch da câmera,
10 Hz). Câmera **acima de 35°** por **1,2 s seguidos** = pegou (era 0,6 s; Q-396: a contagem precisa dar para ler; olhada mais curta é perdoada; sem `Gaze` fresco —
terceira pessoa, câmeras de segurança, lag — nunca conta). O 1º segundo da caminhada também é perdoado (o reflexo de olhar
no baque). Quem é pego paga **−RuleBroken** de sanidade (`ctx.Fail`, como toda regra quebrada; sem desmaio por si só) e a
caminhada acaba ali. Ninguém olhou até o fim = **Resolved**. Sem ator, sem HideZone: funciona no trailer e no restaurante
(a caminhada passa sobre a cabeça de cada jogador). Volta à agenda do restaurante (sai do corte da TASK-390) e é de novo a
estreia da noite 9; nunca junto com o apagão (`ExclusiveWith`).

| Fase (s) | Todos | Só quem olhou (Caught) | Os outros (Safe) |
|---|---|---|---|
| Signal 0–3 | **baque** numa ponta do teto (poeira, lâmpadas balançam, solavanco), barras de cinema, whispers "DON'T LOOK UP / KEEP YOUR HEAD DOWN / IT'S ON THE ROOF", coração 70→90, respiração; quem estava nas câmeras volta para a cabeça | — | — |
| Active 0–7 | passos pesados atravessando o teto até **em cima do jogador**, poeira a cada passo, **mancha escura molhada atravessando o forro e seguindo os passos, pegadas de sangue vazando atrás, gotas vermelhas pingando no chão (as poças ficam), rangidos** (Q-396; a mancha já aparece no Signal), lâmpadas perto balançando, tranco leve da câmera quando perto; whispers sobem; coração 90→140; bordas escurecem; **empurrão suave para baixo** se a câmera passa de 20° (3° por vez, nunca trava) | — | — |
| Active 7–9,5 | **para em cima**: silêncio das palavras, coração 150–160, respiração, depois uma rajada de DON'T LOOK UP em massa | — | — |
| Active 9,5–16 | segue até a outra ponta, palavras e coração baixando | — | — |
| Olhando (Active ≥ 1 s, câmera > 35°) | — | **na hora, só no client dele (Q-396):** a mancha desliza para onde ele olha e **abre olhos brancos**, chiado, respiração; em ~0,95 s sobem borrão, vermelho, cor drenada, coração acelerando e tremor; as gotas aceleram. Baixou o olhar antes de 1,2 s: olhos fecham, rangido, ela volta para a caminhada, nada pago | — |
| Failed (alguém olhou) | barras saem aos 3,5 s | a sombra **cai de cabeça para baixo do teto, de onde a mancha estava (onde ele olhou), na frente da cara**, pendura com olhos brancos, tranco + FOV + puxão leve para ela, depois o rosto (`Kit/Jumpscare`, 0,6 s) e ela é puxada de volta (~1,4 s, `Effects/ANM-019`) | baque dela pulando do teto, whoosh, passos correndo e sumindo |
| Resolved (ninguém olhou) | baque dela saltando da outra ponta, bordas e barras voltam | — | — |

Kit novo (`Scene/Kits`): passos `Roof` (Walk / Leave / Thud ao longo de uma linha pela posição do jogador; som acima do
forro, poeira caindo, lâmpadas balançando localmente) e `HeadDown` (empurrão para baixo enquanto dura). Música: Uneasy no
aviso, Tension (rampa de 16 s) na caminhada. Números todos Provisórios até o Play do dono.

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

## 9. Roteiros entregues em 2026-10-18 (TASK-483, 490, 491; Provisórios até o Play do dono)

Todas as cenas estão em `Content.HorrorScenes` (`/dev trigger ANM-xxx` numa noite em andamento).

| Anomalia | Resposta (restaurante) | O que a cena faz |
|---|---|---|
| ANM-017 Rastejador | **subir no balcão** (pés fora do chão no momento em que ele empina) | arranhões e tábuas sob o piso, "GET OFF THE FLOOR / CLIMB ON THE COUNTER", coração 72→165, ele sai na ponta leste do corredor da cozinha e empina no meio |
| ANM-012 Pescoço invertido | recusar | estalos do pescoço no balcão, "DON'T TAKE HER ORDER / SEND HER AWAY"; o terror de encarar é a pressão (§8) |
| ANM-004 A cópia | recusar | "THAT'S NOT THEM / THEY ALREADY LEFT"; encarar = pressão com "DON'T LOOK AT IT" |
| ANM-006 Stalker | não olhar; fechar a janela quando ele chega | "DON'T LOOK AT IT / IT MOVES WHEN YOU LOOK", e no vidro "CLOSE THE WINDOW!" |
| ANM-008 Carro comprido | fechar a janela (as duas persianas, TASK-480) antes do farol | vem pela rua, entra na pista e **freia no drive-thru**; tranco, silêncio, farol alto; "CLOSE THE WINDOW / KEEP IT SHUT" |
| ANM-010 Hush | **apagar a luz da loja** e manter (sem Mart no mapa) | postes de fora apagam um a um, seta no interruptor, "TURN OFF THE LIGHTS"; depois silêncio e coração lento |
| 001, 005, 011, 013–016 | recusar (Raincoat: servir rápido) | cena curta padrão: sting, barras finas, dica nos primeiros segundos |

Durante as barras de cinema os contornos e as pílulas do mundo apagam (DEC-296), e nas anomalias de mundo os clientes Night encaram o jogador.

## 10. Noite-assinatura (proposta, 2026-10-18, Provisório — Q-384..Q-389)

Autores: game-designer + art-director. Ideia do dono: **cada noite tem um evento cinematográfico próprio** (a novidade) e, com
as noites, os eventos se acumulam até uma noite que junta vários.

### 10.1 Regras

- **Assinatura**: 1 por noite, a cena completa (§2, §3, §6). Hora marcada no **pico** (~1:00 AM de jogo, dentro do "pico"
  11 PM–3 AM da TASK-342), nunca sorteada. Antes dela, **20–40 s antes**, um susto D de **prenúncio** (§3.12) — é o
  `FeaturedScares` da TASK-343, escolhido pela assinatura.
- **Retorno (eco)**: a partir da noite N+1 a assinatura volta como **versão curta**: mesmo verbo, mesmo prazo de resposta,
  mesma penalidade (Q-386); o aviso cai para ~40–50 %, a música de subida não entra, **o silêncio antes do pico fica**
  (1 s), o pico fica. Duração ~40–60 % da completa. Os passos marcados `Echo` formam a versão curta.
- **Acúmulo**: retornos por noite = N2 1 · N3–N4 2 · N5–N6 3 · N7–N8 4 · N9 5 · N10 6 + final. Escolha: a assinatura da
  noite anterior **sempre** volta; o apagão volta em noites alternadas (é a referência); nunca dois de "fechar" seguidos.
- **Respiro**: depois da assinatura **90 s** sem evento B/C (só clientes e A leve); depois de cada eco 45 s; entre dois
  eventos vale o `MinGap` da noite. O orçamento de `Events` continua o total: assinatura + ecos são escolhas forçadas, o resto
  segue sorteado por idade.
- Cortadas do restaurante (`Restaurant.Switch.CutAnomalies`: 002, 003, 007, 018) não entram.

### 10.2 Tabela

| Noite | Evento-assinatura | Retornos (eco) | Atmosfera | Duração alvo (assinatura) | Intervalos / respiro |
|---|---|---|---|---|---|
| 1 | ANM-001 Sem rosto (aula do padrão, suave) | — | ATM-1 normal | ~20 s | prenúncio `ghost_customer`; 90 s depois; noite curta, 4 eventos |
| 2 | **ANM-009 A batida do Walt** (cena da sessão irmã; o tremedor segue como estreia da ligação) | 001 | ATM-1 | ~40 s | prenúncio `fake_call`; 90 s / 45 s |
| 3 | ANM-020 **Apagão** (a referência) | 001, 009 | ATM-2 breu | ~45 s (30 s de escuro) | prenúncio `post_flicker`; 90 s / 45 s |
| 4 | ANM-012 Pescoço invertido + pressão de encarar | 009, 020 (eco: 12 s de escuro, passos, maçaneta) | ATM-4 chuva | ~25 s | prenúncio `street_watcher`; 90 s / 45 s |
| 5 | **ANM-006 O da parada** (não olhar; na névoa branca) | 020, 012, 001 | ATM-6 névoa branca | ~40 s | prenúncio `window_face`; 90 s / 45 s |
| 6 | **ANM-021 Névoa vermelha** (casa com a atmosfera vermelha) | 006, 020, 009 | ATM-3 névoa vermelha | ~31 s | prenúncio `monster_glimpse`; 90 s / 45 s |
| 7 | ANM-017 Rastejador (subir no balcão) | 021, 006, 012, 020 | ATM-5 tempestade | ~25 s | prenúncio arranhão sob o piso (variante de `roof_steps`); 90 s / 45 s |
| 8 | ANM-008 Carro comprido | 017, 021, 006, 009 | ATM-2 breu | ~30 s | prenúncio `radio_voice`; 90 s / 45 s |
| 9 | ANM-019 Sombra no teto | 008, 017, 021, 020, 006 | ATM-3 | ~25 s | prenúncio `roof_knock`; 90 s / 45 s; nunca junto do apagão (`ExclusiveWith`) |
| 10 | **Final: ANM-010 The Hush → eco do apagão → eco da névoa** (uma corrente) | 019, 008, 017, 006, 009, 012 (antes da corrente) | ATM-7 lua de sangue | ~3 min (Hush 35 s · 60 s · apagão 20 s · 45 s · névoa 20 s) e o amanhecer | ecos na 1ª metade do pico; a corrente começa ~3:00 AM; depois dela só clientes até 6 AM |

O que muda frente ao `Nights.luau` de hoje: a assinatura é a `NewAnomaly` nas noites 1, 3, 4, 7, 8, 9, 10; nas noites
2, 5 e 6 ela é outra (N2 Walt em vez do tremedor; N5 o stalker em vez dos olhos brancos, que estreiam calados como hoje;
N6 a névoa vermelha em vez da cabeça errada) — Q-385. `NewAnomaly` continua sendo só a novidade da ligação do chefe.

### 10.3 Comparação com `Content/Nights.luau` e o que o código precisa

Hoje cada noite tem `NewAnomaly`, `Families`, `Atmosphere`, `Events`, `Scares`, `MaxSimultaneous`, `MinGap`; a estreia só pesa
mais no sorteio (`Occurrences.Premiere = 3`), sem hora marcada; não existe versão curta de cena; a TASK-342 (curva calmo →
pico → respiro, campo `Curve`) e a TASK-343 (`FeaturedScares`) estão **Pendentes**.

| Onde | Mudança |
|---|---|
| `Content/Nights` (campos) | `Signature` (chave da anomalia; padrão = `NewAnomaly`), `SignatureAt` (minuto de jogo; padrão 1:00 AM), `Echoes` (lista explícita, Provisória, a tabela acima), `Respite = { Signature = 90, Echo = 45 }`, `Finale` (N10: lista `{ Key, Gap }`) |
| `Content/Validate` | assinatura existe, não está cortada e a família está aberta; cada eco foi assinatura de uma noite anterior; `1 + #Echoes + #Finale ≤ Events`; tudo cabe no Shift com `MinGap` e os respiros; `ExclusiveWith` respeitado |
| `AnomalyService/Scheduler` (`BuildAgenda`) | 1) assinatura em `SignatureAt` (como o evento roteirizado das 5:45); 2) o susto de prenúncio 20–40 s antes (o `FeaturedScares` da 343 vira derivado da assinatura); 3) os ecos no pico/respiro da `Curve` (342), fora do respiro da assinatura; 4) o resto sorteado por idade; a assinatura sai do peso `Premiere` (já é garantida) |
| Registro `Anomalies` (Lync) | campo `Echo: boolean` no registro replicado (o client toca a versão curta) — architect revisa o contrato |
| `Rules/ANM-xxx` | `Params.Echo` com os tempos curtos (`OmenFor`, aviso) — o verbo, a janela de resposta e a penalidade não mudam |
| `Content.HorrorScenes` | passo com `Echo = true` entra na versão curta; `Where` (§3.0) |
| TASK-342 / 343 | a assinatura é a âncora do pico da curva; o "susto D de prenúncio antes de cada C/B" da 342 vira, na assinatura, o prenúncio fixo da tabela; `FeaturedScares` (343) recebe por padrão o prenúncio da assinatura |

---

## 11. Régua do apagão em todas as anomalias (pedido do dono, 2026-10-19, Provisório — Q-397)

Fala do dono: o apagão é o evento de que ele mais gostou; **todas** as anomalias devem subir para o mesmo nível de conteúdo,
"bem completinho, com muitos detalhes". Ele citou do apagão: a **sombra debaixo da porta**, o monstro **só visível pelas
câmeras**, ter que **ir lá fora** (disjuntor), o **efeito do sino**, o **FOV subindo e depois descendo**, as **cores se
perdendo**, as **luzes apagando**, a **luz branquinha ao redor do jogador** que ilumina o que está perto.

### 11.1 Os ingredientes do apagão (a régua)

Toda anomalia do restaurante precisa ter **todos** os itens ● e pelo menos **um** dos ○. Nenhuma regra muda: verbo, prazo e
penalidade continuam os de `Rules/ANM-xxx`; só a apresentação sobe.

| # | Ingrediente | No apagão | Peça |
|---|---|---|---|
| R1 ● | **Gatilho-assinatura**: um som marcante + um pulso de câmera no primeiro segundo | estalo do quadro + sino, tranco, FOV −3° e volta | Sound, Shake, Fov |
| R2 ● | **O mundo muda de verdade** (não só a tela): luz, cor e som ambiente | luzes apagam, cor drena (Grade Cold 0→0,6), zumbido morre | Lights, Grade, Silence, `Prop`, `Glass` |
| R3 ● | **Presença indireta do monstro**: sente antes de ver | passos lá fora, sombra na fresta, vulto no canto do olho | Shadow, Roof, Actor, `Silhouette` |
| R4 ● | **Camada das câmeras**: as câmeras de segurança mostram algo que o olho não vê | o Walker só existe nas câmeras | Actor `Seen = "Cameras"`, `Seen` em `Pose`/`Prop`/`Silhouette` |
| R5 ● | **Pista diegética da saída**: o cenário aponta o que fazer | brilho mostarda + Highlight no disjuntor, palavras com dica | Text, Whispers, `Lantern` Beacon, Arrow3D |
| R6 ● | **Tarefa sob nervos que mexe o corpo** (ir, segurar, não olhar, recusar, fechar) | ir aos fundos no escuro e segurar E | regra existente |
| R7 ● | **Escalada em camadas**: palavras em rampa, coração, vinheta, cor, FOV que "respira" | HIDE 0,4→3, coração 62→150, vinheta 0→0,5 | Whispers, Heartbeat, Vignette, Fov |
| R8 ● | **Silêncio de 1–2 s** antes do pico | coração para, só o violino | Silence, Heartbeat 0 |
| R9 ● | **Clímax físico no mundo** + Caught = rosto ≤ 1 s, Red, Blur | maçaneta, porta força, trinco | Door, `Glass`, `Prop`, Kit/Jumpscare |
| R10 ● | **Alívio em cascata**: luz, cor e som voltam aos degraus, respiração | `lamps_cascade`, Grade 0,6→0, `breath_held` | Lights Cascade, Grade, Sound |
| R11 ○ | **Consolo local do jogador**: algo que ajuda e conforta só ele | a luz branca de 5,6 studs ao redor dele | `Lantern` |
| R12 ○ | **Fora** (§3.0): versão para quem está fora da loja | — (falta no apagão também) | `Where` |

`Peça` em `código` = passo novo (§11.3). As demais já existem em `Scene/Kits`.

### 11.2 Auditoria (o que cada anomalia tem hoje × o que ganha)

Legenda: ✔ tem · ◐ fraco/genérico · ✘ falta. **Assinatura nova** = o "detalhe de apagão" próprio de cada uma, o equivalente da
sombra debaixo da porta.

| Anomalia | R1 | R2 | R3 | R4 | R5 | R7 | R8 | R9 | R10 | R11/12 | Assinatura nova (o que entra) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **020 Apagão** | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔/✘ | referência; ganha Fora (vulto na janela da rua) e a luz branca vira a peça `Lantern` |
| 001 Sem rosto | ◐ | ✘ | ✘ | ✘ | ◐ | ◐ | ✘ | ✘ | ◐ | ✘ | lâmpada do tablet pisca 2×; ele **levanta o rosto liso** (Pose Lift); **nas câmeras ele tem rosto — e sorri para a câmera**; silêncio com a cabeça inclinada; persiana desce e **um dedo bate do outro lado** — **TASK-587 (Em QA):** `Scenes/anm_001_blank_folks`: lâmpada pisca 2× (`Lights` Flicker), `Pose` Lift do rosto liso, copos tremendo (`Prop` Shake), silêncio com `Pose` Tilt, clímax com a cabeça subindo de golpe; nas câmeras ele encara a lente (`Pose` Turn/Tilt `Seen = "Cameras"`; o rosto com sorriso nas câmeras ficou de fora: a face do variant ganha da expressão no `RigController`); batida de dedo na persiana no Resolved; Fora com olhos na rua |
| 005 Raincoat | ◐ | ✘ | ✘ | ✘ | ◐ | ◐ | ✘ | ✘ | ◐ | ✘ | **poça que cresce** dos pés dela até o balcão (o prazo visível); goteira que **para** no silêncio; ela ergue o capuz (só a boca); **nas câmeras ela está seca**; no erro trovão perto e a água corre até quem errou — **TASK-587 (Em QA):** `Scenes/anm_005_raincoat_lady`: `Prop` Puddle cresce de Q1 até a borda do balcão em 52 s (`Seen = "Eyes"`: nas câmeras ela está seca e olha a lente), goteira gerada a cada 2,4 s que para no silêncio, capuz sobe (`Pose` Lift), **ela encara o jogador sem parar** desde a chegada até ir embora (`Pose` Turn sem prazo, pedido do dono 2026-10-19), trovão e luzes; no erro a água corre até quem errou (`Prop` Puddle Flood `To = "Player"`); Fora: olhos dela na pista do drive-thru |
| 011 Treme | ◐ | ✘ | ✘ | ✘ | ◐ | ◐ | ✘ | ✘ | ◐ | ✘ | **o ambiente treme** (copos, garrafas, luminária balançando), micro-tremor da câmera perto; **nas câmeras ele está parado, olhando para cima**; tudo para de uma vez; **pancada na persiana** depois de recusar — **TASK-587 (Em QA):** `Scenes/anm_011_shaker`: `Prop` Shake nos copos/garrafas (`Seen = "Eyes"`), `Prop` Sway na luminária, chocalho gerado acelerando, micro-tremor da câmera (`Shake` Step); para tudo aos 8 s, um passo no telhado, o balcão inteiro pula; nas câmeras ele olha para cima (`Pose` Lift `Cameras`); pancada na persiana no Resolved; Fora: as mesas perto dele tremem |
| 013 Olhos brancos | ◐ | ✘ | ✘ | ✘ | ◐ | ◐ | ✘ | ✘ | ◐ | ✘ | luz do tablet cai a 30 % e **os olhos dele iluminam o balcão** (o inverso da lanterna); **todos os clientes viram juntos** para o jogador; pares de olhos nas vitrines um a um; **nas câmeras há olhos em todas as janelas** — **TASK-587 (Em QA):** `Scenes/anm_013_white_eyes`: zumbido cai, **todos os clientes viram juntos** (`Pose` Turn Value 1) com estalo, olhos um a um nas aberturas de fora (janela de serviço, parada do drive-thru, porta da despensa, parada da van: `Actor`/`Lantern` Eyes; `TBL-*` são nós, não MapPoints), silêncio com **todas as luzes apagadas e só os olhos dele iluminando o balcão** (`Lights` Off + `Lantern` Eyes em Q1, `Cascade` 2,3 s depois); nas câmeras os olhos ficam em todas as janelas; olhos entre as lâminas no Resolved. A luz do tablet a 30 % precisa de `Lights` por Point (não existe; ficou o apagão curto) |
| 014 Cabeça errada | ◐ | ✘ | ✘ | ✘ | ◐ | ◐ | ✘ | ✘ | ◐ | ✘ | **a cabeça cresce aos degraus só quando ninguém olha** (rangido de couro, FOV −1 por degrau); encosta na luminária, que balança; **nas câmeras ela já bate no teto** — **TASK-587 (Em QA):** `Scenes/anm_014_big_head`: `Pose` Scale em degraus (×1,12/1,24/1,36 sobre o ×1,9 do modificador, depois ×1,5) que **só cresce quando sai da vista** do jogador, com rangido; FOV −1 por degrau; bate na luminária (`Prop` Sway + Flicker); silêncio com `Pose` Tilt; nas câmeras ×1,7 a mais (bate no teto); Fora: a cabeça vira para ele |
| 015 Flutuando | ◐ | ✘ | ✘ | ✘ | ◐ | ◐ | ✘ | ✘ | ◐ | ✘ | guardanapos e copos perto **sobem devagar**; **a sombra dele fica parada no chão**; zumbido que sobe e corta; **tudo cai junto** (baque + tranco); nas câmeras ele está no teto — **TASK-587 (Em QA):** `Scenes/anm_015_floater`: `Pose` Float +0,6, guardanapos e copos sobem girando (`Prop` Float), zumbido sobe; nas câmeras ele está no teto olhando para baixo; zumbido corta, **tudo cai junto** (`Prop` Drop + baque + tranco) e ele recomeça a subir devagar. A sombra parada no chão ficou de fora (sem peça para isso) |
| 016 Não pisca | ◐ | ✘ | ✘ | ✘ | ◐ | ◐ | ✘ | ✘ | ◐ | ✘ | relógio **tiquetaqueando cada vez mais devagar até parar**; os outros clientes piscam juntos, ele não; **ele pisca uma vez e todas as luzes piscam com ele**; nas câmeras ele encara a câmera — **TASK-587 (Em QA):** `Scenes/anm_016_starer`: relógio tiquetaqueando no balcão que para aos 9 s, os outros clientes **piscam juntos a cada 3 s** (`Pose` Blink Value 1), ele não; ele pisca uma vez e as luzes piscam com ele; nas câmeras a sala inteira encara a lente (`Pose` Turn Value 1 `Cameras`). O tique que desacelera espera `clock_tick` (SFX-255) |
| 004 Cópia | ◐ | ✘ | ◐ | ✘ | ✔ | ◐ | ✘ | ✘ | ◐ | ✘ | luz pisca quando a cópia chega; ela **imita o jogador com atraso** (vira a cabeça quando ele vira); **nas câmeras só existe um deles**; no erro o trinco da frente tranca sozinho |
| 012 Pescoço | ✔ | ◐ | ◐ | ✘ | ✔ | ◐ | ✔ | ✘ | ✔ | ✘ | **a sombra dela no chão tem a cabeça do lado certo** (contradiz o corpo); cada estalo **apaga a lâmpada mais perto**; nas câmeras a cabeça gira devagar; no erro a cabeça completa a volta |
| 006 Stalker | ✔ | ◐ | ✔ | ✘ | ✔ | ✔ | ✔ | ◐ | ✔ | ✘ | **vidro embaça** na altura do rosto; batida de dedo; **marca da palma escorregando**; Blur a cada passo dele; **nas câmeras ele está mais perto do que parece** — **TASK-588 (Em QA):** feito em `Scenes/anm_006_stalker` (Fog + Knock na janela ao chegar; Hand e Bang só se embaçado; o stalker parado no vidro nas câmeras desde S+2; Fora com passos atrás). O pulso de Blur "a cada passo" não entrou: os passos dependem do olhar, não do relógio |
| 008 Carro | ✔ | ◐ | ✔ | ✘ | ✔ | ✔ | ✔ | ◐ | ✔ | ✘ | **farol varre o teto** pela janela do drive; freada + motor desliga + 2 s de nada; **farol alto cega** (bloom + Blur); persiana batendo cada vez mais forte; **nas câmeras o carro não tem motorista** — **TASK-588 (Em QA):** `Scenes/anm_008_long_car` (Glare Sweep na arrancada e na saída, Knock + Rattle na espera, Flash no farol alto só para quem olha a janela, Rattle crescente); motorista visível a olho nu e ausente nas câmeras em Effects/ANM-008 |
| 009 Batida | ✔ | ✔ | ✔ | ✘ | ✔ | ✔ | ✔ | ✔ | ✔ | ✘ | já no padrão; ganha **nas câmeras quem bate não é o Walt** (silhueta alta demais) e Fora — **TASK-588 (Em QA):** `Scenes/anm_009_knock`; o batedor das câmeras (Effects/ANM-009) ficou 1,45× mais alto e magro com o boné do Walt; luzes piscam na voz errada; Fora com palavras próprias |
| 010 Hush | ✔ | ✔ | ◐ | ✘ | ✔ | ✔ | ◐ | ◐ | ✔ | ✘ | **forma enorme cruza as vitrines** por fora; drone grave que **corta**; rangido de vidro a cada ~4 s; com a luz apagada o jogador ganha a **luz branca fraca** (R11) |
| 017 Rastejador | ✔ | ◐ | ✔ | ✘ | ✔ | ✔ | ✔ | ◐ | ◐ | ✘ | **tábuas do piso levantam** na passagem dele, poeira subindo; luminárias balançando; **nas câmeras ele está debaixo do balcão** antes de sair |
| 019 Sombra no teto | ✔ | ✔ | ✔ | ✘ | ✔ | ✔ | ✔ | ✔ | ✔ | ✘ | já no padrão; ganha **nas câmeras ela está de pé no telhado** e Fora (silhueta contra o céu) |
| 021 Névoa vermelha | ✔ | ✔ | ◐ | ✘ | ✔ | ✔ | ✔ | ◐ | ✔ | ✘ | **vultos na névoa** que só as câmeras mostram; o vidro **flexiona** em cada pancada (+ poeira), a maior por último; Fora com Blur — **TASK-588 (Em QA):** `Scenes/anm_021_red_fog` (cada pancada é `Glass` Bang com poeira; nas câmeras um vulto vem pela fila até o vidro e uma forma alta cruza atrás das mesas; aviso na tela; Fora com Blur e passos) |

Resumo: **sete** anomalias de cliente (001, 005, 011, 013–016) estão na cena curta genérica (`oddScene`) e sobem do zero;
**seis** (004, 006, 008, 010, 012, 017) têm cena própria mas faltam mundo físico, câmeras e clímax; **três** (009, 019, 021)
estão perto e ganham câmeras e Fora. O apagão ganha Fora.

### 11.3 Peças novas do kit (uma vez, servem a todas)

Complementa §3.13. Cada peça é um módulo em `AnomalyController/Scene/Kit/<Peça>.luau` que se registra sozinho
(`Kits.Register` percorre a pasta), para as tasks correrem em paralelo sem tocar o mesmo arquivo. Cena nova ou reescrita vai
em `Content/HorrorScenes/Scenes/<key>.luau` e substitui a embutida de mesma `Key`.

| Peça | O que faz | `Seen` |
|---|---|---|
| `Pose` | mexe o `CustomerActor` da anomalia: Lift, Tilt, Turn (um ou todos os clientes Night), Scale, Float, Blink, Mimic (imita a câmera com atraso) | sim |
| `Prop` | objetos locais perto do Point: Shake, Float, Sway (luminária), Puddle (Grow / Flood), Lift (tábua do piso), Drop | sim |
| `Glass` | vidro no MapPoint: Fog, Knock, Bang (flexiona + poeira), Hand (palma escorrendo), Rattle (persiana) | — |
| `Glare` | farol: Flash (bloom + Blur se o ponto está na vista) e Sweep (SpotLight varrendo o teto) | — |
| `Silhouette` | forma grande escura que cruza por fora das vitrines (placa com recorte, só local) | sim |
| `Lantern` | a luz branca do apagão como peça: Glow (ao redor do jogador), Beacon (pulso mostarda + Highlight num MapPoint), Eyes (luz branca nos olhos de um ator) | — |
| `Where` (campo) | `"Inside"` / `"Outside"`; lê `OutsideStage` (§3.0) | — |
| `Seen` (campo, ampliado) | `"Cameras"` = só pela câmera de segurança; `"Eyes"` = só a olho nu; nil = sempre | — |

Durante o modo câmera (`Kit/Watch`) a camada `Cameras` aparece e a `Eyes` some — o "só dá para ver pelas câmeras" do apagão,
generalizado.

### 11.4 Tasks (TASK-586..TASK-590, Provisório)

| ID | O quê | Dono | Depende | Status |
|---|---|---|---|---|
| TASK-586 | **Preparo**: `Content.HorrorScenes` vira pasta (`init` + `Types` + `Scenes/`); tipos `Pose`, `Prop`, `Glass`, `Glare`, `Silhouette`, `Lantern`, campos `Where` e `Seen` ampliado; `Scene/Kit/` auto-registrado; stubs | backend-coder | — | Feito |
| TASK-587 | **Família A no padrão**: peças `Pose` + `Prop`; cenas completas de 001, 005, 011, 013, 014, 015, 016 | frontend-coder | 586 | Em QA |
| TASK-588 | **Vidro e farol**: peças `Glass` + `Glare`; 006, 008, 021 e 009 no padrão | frontend-coder | 586 | Em QA |
| TASK-589 | **Forma, lanterna e Fora**: peças `Silhouette` + `Lantern`, campo `Where` e camada `Seen` no player; 010, 017, 019, 020 (Fora) no padrão | frontend-coder | 586 | Pendente |
| TASK-590 | **Cliente com corpo**: 004 e 012 no padrão (Mimic, sombra contraditória, lâmpadas que morrem nos estalos); usa `Pose`/`Prop` da 587 | frontend-coder | 587 | Pendente |

As TASK-535..537 e 541..552 ficam **absorvidas** por estas (mesmo conteúdo, agrupado por peça para não haver dois donos no
mesmo arquivo).

## Noite 1: terror mais cedo (pedido do dono 2026-10-20, Provisório — Q-415)

A Noite 1 ficava ~3 min sem nada (carência até 23h segurava eventos e sustos). Agora, sem aumentar a punição:

- **Abertura roteirizada** (`night_opening`, `Nights.Opening[1]`, só na 1ª tentativa): silêncio de 2,5 s; os 8 postes
  mais perto apagam um a um do fundo para o jogador; 1,4 s de escuro e silêncio; voltam de perto para longe. Um vulto
  parado do outro lado da rua (ponto do mapa na borda da visão, ou sob um poste) some depois de visto, quando a câmera
  volta. A linha do Walt chia com duas falas cortadas (placeholder). Fecha com uma respiração presa. Sem verbo, sem custo.
- **Carência só para quem pune**: `Nights.Grace` segura só os eventos regulares; os sustos D valem desde as 20h
  (`Nights.ScaresFrom`), um por vez (`HallucinationRules.ScareGap`). O tutorial de novato segue segurando tudo.
- **Estreia fixa**: `anm_001_blank_folks` às 22h da Noite 1 (`Nights.PremiereAt`), logo depois da ligação, fora da carência.
- **Sustos D novos** (desde a Noite 1): `post_figure` (o poste em vista falha e, quando volta, há um vulto sob a lâmpada;
  visto, a lâmpada apaga e volta sem ninguém) e `shop_shadow` (vulto dentro da loja na borda da visão; ao virar para ele,
  some com um tranco curto de câmera `Jolt` e um sopro; às vezes outro pisca do lado oposto).
