Status: Rascunho (Provisório)

# Trailer "Blackout" — 3 camera tracks de 60 s para gravação solo

Autor: cinematographer, 2026-10-20. Base: `marketing/trailer-blackout-60s.md` (v2, planos #4–#48 e o enquadramento
**FRENTE**), `marketing/research-trailer-cinematografia.md` (§4 câmera, §2 silêncio). Dados das tracks em
`src/Dev/shared/CameraTracks.luau` (só dados; o player é o `DevCameraController`, frontend-coder, contrato fixo).
Geometria conferida no Studio em 2026-10-20 (eixos: +Z = norte = frente do trailer/pátio; +X = oeste; piso y 0,45;
teto da cozinha y≈9,4; olhos ≈ 4,5).

Nada aqui é aprovado. Comandos de câmera (`/dev track <key>`, `/dev track stop`) são os que o frontend-coder está
escrevendo contra o contrato; a sintaxe final sai do `/dev help track` [A CONFIRMAR].

---

## 1. Como uma track funciona na gravação

| Item | Como |
|---|---|
| O que é | um caminho de câmera por keyframes (posição, ponto olhado, FOV, easing, roll). Roda sozinho no cliente que digitou `/dev track <key>`; a tela desse cliente **é** a câmera do trailer |
| Easing | `Ease` diz como chegar **nesta** key vindo da anterior. `Hold` = a câmera fica parada na key anterior e **salta** (corte seco) nesta. Keys de corte vêm 0,1 s depois do fim do plano anterior (T crescente) |
| UI | `HideUi = true` esconde o HUD do jogo (`front`, `kitchen`); `false` mantém (`blackout` precisa das palavras, da legenda POWER OUT e do anel do prompt) |
| Chat | o chat é CoreGui e aparece por cima. Para disparar `/dev scene blackout` no meio da track: digite antes, dê Enter no segundo marcado e clique fora; o chat esmaece. Na montagem, a região do chat fica no preto ou é mascarada. Proposta de automatizar em §6 (TASK-C10) |
| Movimento do personagem | WASD é **relativo à câmera**. Com a câmera olhando para oeste, W anda para oeste; "esquerda da tela" = norte. Cada track diz onde o bichinho fica para **não** entrar no quadro |
| Halo do apagão | a luz branca de 5,6 studs (`Effects/ANM-020` `GLOW_RANGE`) é um PointLight **preso ao personagem local**, não à câmera. Na track `blackout` o bichinho precisa andar junto da câmera (toques curtos de W, §4.3) para o halo iluminar o que a câmera vê |
| Linha do tempo real do apagão | `/dev scene blackout` em S → telefone com glitch (Signal) → **corte em S+2** → palavras S+7 → coração S+16 → Walker nas câmeras S+20–28 → sombra na fresta S+26,8 → maçaneta S+29 · porta forçada S+30,2 · trava S+31 → coração para S+31,4 → **Failed (rosto) em S+32**. Fonte: `Content.HorrorScenes` (ANM-020) |
| Proteções | `/dev god me on` (sanidade infinita; era `infsanity`), `/dev revive auto on` (levanta 2 s após o susto; era `autorevive`). Entre tomadas: `/dev scene stop` |
| OBS | captura de janela do cliente-câmera, viewport só, 60 fps, 1440p se der. Áudio do jogo em faixa separada |

### 1.1 Setup comum (uma vez por sessão)

```
/dev god me on
/dev revive auto on
/dev customer off           (liga de novo só quando a track pede fila)
```

Gráficos no máximo, iluminação Future, sem FPS cap (roteiro §6.1).

---

## 2. Track `front` — "A noite de fora" (60 s)

**Intenção.** Tudo visto do pátio/rua: o lugar aconchegante de longe, as mesas e tochas de perto, a fila, a janela de
atendimento em close, e então o **mesmo** enquadramento FRENTE apagado e, no fim, acendendo. Entrega os planos **#9**
(FRENTE aceso, 0–10 s), as mesas (#47-like, 20–28 s), a janela (#9/#13 material de corte, 28–40 s), **#43A** (FRENTE
no escuro, 46–54 s) e **#46** (luz voltando em cascata, 54–60 s). O stinger #48 (cabeças virando) continua dependendo
de TASK-C4 e fica fora desta track.

**FRENTE** fixado em `Pos (−47, 17, 54)`, `Look (−43, 4, 10)`: plongée ≈16,5°, trailer no terço inferior, fila (z=39)
rente à borda inferior, postes de z=46,4 fora do quadro (o de x=−36,4 ficaria dentro se a câmera estivesse em x=−42).
O mesmo ponto é reaproveitado como ponte na track `blackout` (§4): as três aparições do FRENTE saem idênticas.

### 2.1 Antes (1 cliente)

```
/dev night 2
/dev time 23:30
/dev atm ATM-1               (céu limpo: tochas e letreiro quentes; o editor escurece o #43A no grading)
/dev customer on             (fila em z=39)
/dev customer tables sit     (repetir até as 4 mesas terem gente)
```

Pegue um prato pronto na bancada, vá para trás do balcão da frente (x≈−42,5, z≈11,5), vire-se para o pátio (norte)
e fique parado. Abra o chat, digite `/dev track front` e Enter; comece o OBS 1 s antes.

### 2.2 Durante

| T (s) | O dono faz | A câmera |
|---|---|---|
| 0–40 | nada: parado atrás do balcão, prato na mão, de frente para a câmera | FRENTE → push-in → descida pelas mesas → corredor entre mesas → close na janela |
| 40 | digita `/dev scene blackout` (sem Enter) | hold no close da janela |
| **44** | **Enter**; clica fora do chat | começa o pull-out para o FRENTE; telefone com glitch 44–46 |
| ≈46 | — | **corte de luz** no exato assentar da câmera no FRENTE (#43A: nada se mexe) |
| **54** | `/dev trigger stop blackout` (Enter em 54) — **[A CONFIRMAR]** se o stop passa pela fase `Resolved` e toca `power_up` + `lamps_cascade`. Se não tocar: gravar com **2 clientes**, B parado no disjuntor segura E de 51 a 54 (T1 do roteiro) | FRENTE: a luz volta em cascata (#46) |
| 60 | fim; `/dev scene stop` se a cena ainda estiver viva | — |

Se a cena não for interrompida, o Failed (rosto) cai em T=78, fora da track: sem risco para a tomada.

### 2.3 Keyframes

| # | T | Pos (x, y, z) | Look | FOV | Ease | Nota |
|---|---|---|---|---|---|---|
| 1 | 0 | (−47, 17, 54) | (−43, 4, 10) | 70 | — | FRENTE aceso (#9): letreiro, tochas, mesas cheias, costas da fila |
| 2 | 10 | (−46,5, 16, 47,5) | (−43, 4,5, 10) | 68 | Sine | push-in 0,7 stud/s |
| 3 | 20 | (−57, 5,5, 28,3) | (−42, 4, 13,2) | 66 | Sine | desce à ponta oeste do corredor entre as duas fileiras de mesas (2,4 stud/s; passa 5 studs acima da mesa (−49,5, 32,1); 6 abaixo da CAM1) |
| 4 | 28 | (−44, 5, 28,3) | (−42,5, 4,6, 13,2) | 64 | Linear | desliza para leste no corredor (1,6 stud/s), 3,8 studs de cada fileira; janela à frente |
| 5 | 36 | (−42,5, 5, 17,5) | (−42,5, 4,6, 13,2) | 55 | Sine | push até a janela (1,4 stud/s); o bichinho atrás do balcão; placa Pick Up à direita |
| 6 | 40 | (−42,5, 5, 17) | (−42,5, 4,8, 13,2) | 52 | Sine | hold no close; dono digita o comando |
| 7 | 46 | (−47, 17, 54) | (−43, 4, 10) | 70 | Sine | pull-out ao FRENTE (6 stud/s, suave nas pontas); **corte de luz** ao assentar |
| 8 | 54 | (−47, 17,2, 55) | (−43, 4, 10) | 70 | Linear | FRENTE no escuro (#43A), dolly-out 0,12 stud/s |
| 9 | 60 | (−47, 17,4, 56) | (−43, 4, 10) | 70 | Linear | luz volta em cascata (#46) no mesmo quadro |

Folgas: todo o percurso é externo (y ≥ 5); nenhum ponto a menos de 2 studs de mesa, tocha, poste, totem ou CAM1.

---

## 3. Track `kitchen` — "A noite de dentro" (60 s)

**Intenção.** A cozinha quente em detalhes (grelha, prato com molho em S, dolly pela bancada), o drive-thru, o
tablet, e um plano geral alto do canto nordeste que **vê o apagão acontecer** com alguém dentro. Entrega #4, #5/#6, #7
(sensação, com um ator), #8, material do #10 (tablet), **#22/#25/#26** (aviso do telefone + corte em plano geral) e a
cozinha vermelha vazia.

**Dois clientes** (recomendado): **A** = câmera (roda a track, grava-se a janela de A), **B** = ator que cozinha de
verdade na própria visão. É a técnica T1 do roteiro: a track não precisa do personagem de A, e o dono cozinha em B
sem ter de agir "às cegas" vendo a imagem da track. Com 1 cliente a track funciona, mas o dono só vê a câmera do
trailer enquanto cozinha — viável só para gestos simples (andar entre estações).

Sobre o "vulto no fundo": o vulto do ANM-020 nasce **60–80° fora do olhar** e some quando olhado; com FOV 72
(≈104° horizontais) ele cai fora do quadro por regra. O "vulto" deste plano é a **silhueta de B** atravessando o
vermelho até a porta da despensa. Se o efeito usar a direção do personagem de A em vez da câmera, ele pode entrar
na borda [A CONFIRMAR em teste].

### 3.1 Antes

```
/dev night 2
/dev time 23:30
/dev atm ATM-1
/dev customer on             (pedidos reais no tablet; o drive-thru vem por comando)
```

- **A**: deixe o bichinho parado no canto nordeste da cozinha, encostado na parede leste, sob a câmera alta
  (x≈−27, z≈11). Está fora de todos os seis quadros. Digite `/dev track kitchen` em A e dê Enter; OBS na janela A.
- **B**: comece na grelha (x≈−55,5, z≈0,5, de frente para a grelha, −Z). Salsicha na mão.
- Janelas lado a lado; o foco vai para B logo depois do Enter em A.

### 3.2 Durante (tudo em B)

| T (s) | B faz | Câmera (A) |
|---|---|---|
| 0–6 | solta a salsicha na grelha; vira no Perfect | detalhe da grelha por cima do trilho |
| 6–10 | já na bancada de montagem (lado **sul**, z≈3,5, marca x≈−40), de frente para a câmera: molho em S sobre o prato; ficha do pedido no prato | prato visto do lado norte |
| 10–18 | trabalha no prato da marca x≈−43 | dolly lateral leste → oeste a 2,3 stud/s; passa por B em ≈14 |
| **12** | digita `/dev drive car` e Enter (o carro nasce e vai para a janela) | — |
| 18–24 | anda do prato para o tablet (−25,6, 5, −1,1) e para em x≈−27,3, z≈0,8 (sul do tablet) | drive-thru por fora da parede oeste; carro chega, cliente ao volante |
| 24–29 | pega o pedido (mini-diálogo) | tablet por cima do ombro de B, B à direita do quadro |
| 29–41 | cozinha de verdade: tablet → grelha → prato (vai e vem na cozinha toda) | plano geral alto do canto NE, creep lento |
| **41** | **Enter** em `/dev scene blackout` (digitado em 39–40); vira o bichinho para o **telefone** (parede oeste) | telefone com glitch 41–43 (falso alívio 2) |
| ≈43 | — | **corte de luz**: só o vermelho de emergência |
| 43–48 | parado (respiração) | creep continua |
| 48–58 | anda **devagar** (toques) para a porta da despensa (x −28, z −3,9): sai do quadro pela esquerda | cozinha vermelha vazia; palavras em 48, coração em 57 são só de A (HUD oculto em A) |
| 60 | fim. `/dev scene stop` | — |

Se ninguém religar, o Failed cai em T=73 (fora da track).

### 3.3 Keyframes

| # | T | Pos | Look | FOV | Ease | Nota |
|---|---|---|---|---|---|---|
| 1 | 0 | (−49,6, 6, 1,2) | (−52,8, 3,3, −2) | 50 | — | grelha (#4) vista do leste; B à oeste da grelha |
| 2 | 6 | (−50,6, 5,5, 0,4) | (−52,8, 3,3, −2) | 50 | Sine | push-in 0,2 stud/s; Perfect |
| 3 | 6,1 | (−40, 5,2, 8,8) | (−40, 4, 5,2) | 50 | **Hold** | CORTE: prato na bancada (#5/#6), do lado norte; B de frente |
| 4 | 10 | (−40,6, 5,1, 8,6) | (−40, 4, 5,2) | 50 | Sine | drift; hot dog bate com a ficha |
| 5 | 10,1 | (−33,5, 6,4, 9,6) | (−36,5, 3,8, 5,6) | 62 | **Hold** | CORTE: início do dolly, ponta leste da bancada |
| 6 | 18 | (−51,5, 6,4, 9,6) | (−48,5, 3,8, 5,6) | 62 | Linear | dolly para oeste 2,3 stud/s (#7) |
| 7 | 18,1 | (−69,5, 6,5, 27) | (−63, 3, 10) | 60 | **Hold** | CORTE: drive-thru (#8) por fora; pista x −63,5, janela ao fundo. **Ajustar** ao ponto real de parada do carro (`/dev drive state`) |
| 8 | 24 | (−68,7, 6,2, 26) | (−63, 3, 10,5) | 60 | Sine | leve push; faróis na parede |
| 9 | 24,1 | (−29,8, 6, −2,4) | (−25,8, 4,9, −1,1) | 50 | **Hold** | CORTE: tablet (FEAT-043) sobre o ombro; B em (−27,3, 0,8) |
| 10 | 29 | (−29,4, 5,9, −2,2) | (−25,8, 4,9, −1,1) | 50 | Sine | drift; pedido tomado |
| 11 | 29,1 | (−27, 8,4, 11,6) | (−45, 2,5, 1) | 72 | **Hold** | CORTE: plano geral alto NE (#7/#22/#25); telefone no fundo |
| 12 | 42 | (−28, 8,3, 11) | (−45, 2,5, 1) | 72 | Linear | creep 0,1 stud/s; glitch 41–43; **corte de luz ≈43** |
| 13 | 60 | (−30,5, 7,7, 9,8) | (−44, 2,5, 0) | 70 | Linear | cozinha vermelha; B sai pela esquerda rumo à despensa |

Folgas (interior x −59,5…−25,5, z −3,7…13,4, teto 9,4): toda key interna fica em x ∈ [−58,9; −26,1], z ∈ [−2,9; 12,6],
y ≤ 8,6. A key 11 (−27, 8,4, 11,6) tem 1,8 da parede leste, 1,8 do balcão e 1,0 do teto. As keys 9–10 ficam a leste das
panelas (x −38…−32). O dolly (z 9,6) corre no corredor entre a bancada (z 5,6) e o balcão (z≈13).

---

## 4. Track `blackout` — "O caminho até o disjuntor" (60 s)

**Intenção.** O bloco 29–51 s do roteiro em altura de olhos, **com a cena real rodando**: corte de luz em plano,
parado no escuro com a legenda, a porta, o corredor da despensa a passo irregular (handheld por micro-oscilações de
posição, altura e roll ±0,6°), hesitação, chegada ao disjuntor e o anel do prompt, whip lento para trás que para no
halo olhando a porta dos fundos, os três golpes na porta, o silêncio e o rosto — ou a luz voltando em cascata pelo
corredor. Entrega #26 (POV), **#27, #28, #29 (parcial), #32, #34/#36/#38 (anel), #40, #41** e o material de **#42**;
a fresta e a porta em close (#2, #33, #35, #37, #39) continuam na tomada D do roteiro (câmera livre rente à porta).

Dois finais na mesma track, o dono escolhe no segundo 32:

- **Final B (susto, padrão):** não completa o "segurar"; o rosto do jogo entra em T=36 em tela cheia; a sombra deixa a
  fresta em 37–38,2.
- **Final A (religar):** segura E de **32,3** sem soltar → religa em ≈35,3; `power_up` + cascata iluminam o corredor
  que a câmera já está olhando. Em uma tomada o editor ganha o #40/#41 (até 35,3) e um "luz volta" de dentro.

Em T=39 há um **corte seco (Hold)** para o FRENTE: o trailer de longe, apagado (final B) ou aceso (final A). A cauda
(39–60) é a ponte #43A/#46 gravada no mesmo ponto exato da track `front`.

### 4.1 Antes (1 cliente)

```
/dev night 3
/dev time 1:30
/dev atm ATM-2               (breu)
/dev customer off
```

- Leve o bichinho ao **canto leste da cozinha**, junto à porta da despensa: pare em x≈−28,4, z≈−0,3 (1 stud ao norte
  da posição inicial da câmera), **de frente para oeste**. Ele fica ao lado da câmera, fora do quadro.
- Confirme que a porta cozinha→despensa (DOOR-P, x −28,1, z −3,9) está aberta ou abre sozinha na aproximação
  [A CONFIRMAR]; a câmera atravessa o vão em T 11,5–14,5.
- Digite `/dev track blackout` e Enter (T=0). **Imediatamente** digite `/dev scene blackout` e dê **Enter em T=4**;
  clique fora do chat. A key inicial é estática até T=9: um erro de ±1,5 s no Enter não estraga o plano.

### 4.2 Durante — segundo a segundo

C = corte de luz = T 6 (se o Enter foi em 4). Os eventos da cena são C + offset da tabela em §1.

| T (s) | O dono faz | O que acontece / a câmera |
|---|---|---|
| 0 | Enter em `/dev track blackout`; começa a digitar `scene blackout` | POV parado no canto leste, olhando o telefone na parede oeste; cozinha acesa |
| **4** | **Enter** em `/dev scene blackout`; clica fora | glitch no telefone (Signal) |
| ≈6 | nada | **corte**: clunk, zumbido morre, sino; vermelho de emergência; barras; legenda POWER OUT |
| 6–11,5 | parado | respiração; a câmera gira devagar para a porta da despensa; palavras começam (≈11) |
| **12,5** | **toque de W (~0,3 s)**: o bichinho entra na despensa antes da câmera; em seguida **um toque de D** (com a câmera virada para o sul, D = oeste: ele sai da linha da porta e fica atrás da câmera quando ela virar para o corredor) | a câmera atravessa o vão (11,5–14,5) |
| 14,5–18,5 | parado | relance para a porta dos fundos e a fresta (nada ainda); vira para oeste: corredor + brilho mostarda ao fundo |
| **20,5 · 22,5 · 24,5 · 26,5** | **4 toques de W de ~0,25 s** (≈4 studs cada, câmera já virada para oeste → W = oeste). Regra: o bichinho fica **atrás** da câmera; se aparecer na borda inferior, atrase o toque seguinte | caminho irregular 18,5–28; coração entra (20); olhar desliza às prateleiras (22); hesitação (23,5); breath_held (26) |
| **27,5** | **toque curto de W+A** → marca ao lado das prateleiras: x≈−48,2, z≈−6,0 (a 3 studs do disjuntor, raio do prompt 4; fora do quadro, 54° fora do eixo) | chegada: detalhe do disjuntor, prompt **Reset Breaker** |
| **28,5–30,0** | **segura E e SOLTA** (anel ≈1/2) | câmera fixa no disjuntor (#34) |
| **30,5–31,8** | **segura E e SOLTA** (anel ≈45 %) — nunca complete 3 s antes de 35,5 se quiser o susto | fixa (#36/#38); sombra chega à porta às costas (30,8); passos param (32) |
| 32–33 | **Final A:** começa a segurar E em **32,3** e não solta. **Final B:** mão fora do E | whip lento (1 s) para leste; para no halo olhando a porta (#41) |
| 33–35,4 | — | maçaneta 33 · porta forçada 34,2 · trava segura 35 · coração para **35,4 = silêncio** |
| 36 | — | **Final B:** rosto em tela cheia 0,6 s (#42); `revive auto` levanta em ≈38. **Final A:** luz voltou em ≈35,3, cascata pelo corredor |
| 37–38,2 | — | a sombra sai da fresta (Failed) — só no final B |
| **39** | — | **corte seco** para o FRENTE (ponte) |
| 39–60 | nada | FRENTE com dolly-out mínimo; `/dev scene stop` depois |

Dica de tempo: a track é a mesma a cada tomada; grave 3 vezes (duas com final B, uma com final A) e escolha a melhor
sincronia dos toques.

### 4.3 Keyframes (altura de olhos 4,5; HUD do jogo visível)

| # | T | Pos | Look | FOV | Ease | Roll | Nota |
|---|---|---|---|---|---|---|---|
| 1 | 0 | (−28,6, 4,5, −1,4) | (−59, 4,9, 0,9) | 70 | — | — | cozinha acesa; POV ao telefone (30 studs) |
| 2 | 6 | (−28,7, 4,48, −1,45) | (−59, 4,8, 0,9) | 70 | Sine | — | drift de respiração; glitch ≈4; **corte ≈6** |
| 3 | 9 | (−28,7, 4,5, −1,5) | (−58, 4,6, 1) | 69 | Sine | — | parado no escuro (#27): legenda, barras |
| 4 | 11,5 | (−28,6, 4,5, −1,8) | (−28,1, 4, −3,9) | 70 | Sine | — | gira para DOOR-P; primeiras palavras |
| 5 | 14,5 | (−28,3, 4,5, −5,6) | (−28,5, 3,9, −9,6) | 70 | Sine | — | atravessa o vão (1,3 stud/s), já na despensa |
| 6 | 16,5 | (−28,6, 4,5, −6,4) | (−29,5, 3,2, −10,9) | 68 | Sine | — | relance à porta dos fundos e à fresta: nada |
| 7 | 18,5 | (−29, 4,5, −7,6) | (−49,5, 4,5, −7,3) | 70 | Sine | — | vira para o corredor: 20 studs de breu + mostarda |
| 8 | 20,5 | (−32,4, 4,42, −7,9) | (−49,5, 4,4, −7,3) | 70 | Linear | 0,6 | passo 1,7 stud/s; coração 62 BPM |
| 9 | 22,3 | (−35,6, 4,55, −7,5) | (−41,5, 4,2, −5,6) | 70 | Sine | −0,5 | olhar desliza às prateleiras; latas no halo |
| 10 | 23,5 | (−36,6, 4,45, −7,7) | (−49,6, 4,6, −7,2) | 70 | Sine | 0,3 | hesitação (0,8 stud/s) |
| 11 | 25,3 | (−41,2, 4,52, −7,5) | (−50, 4,6, −7,2) | 70 | Linear | −0,6 | acelera (2,6 stud/s) |
| 12 | 26,8 | (−45, 4,44, −7,8) | (−50,4, 4,7, −7,2) | 70 | Linear | 0,4 | últimos passos; breath_held |
| 13 | 28 | (−46,8, 4,6, −7,9) | (−50,4, 4,7, −7,2) | 55 | Sine | 0 | chegada (#32): disjuntor + prompt |
| 14 | 32 | (−46,85, 4,58, −7,92) | (−50,4, 4,7, −7,2) | 54 | Sine | — | **fixa 4 s**: seguradas parciais (anel) |
| 15 | 33 | (−46,6, 4,55, −7,5) | (−29,5, 3,4, −10,6) | 62 | Sine | — | whip lento 1 s; **para no halo** (#41), porta a 17 studs |
| 16 | 38,9 | (−46,5, 4,5, −7,5) | (−29,5, 3,5, −10,6) | 62 | Sine | — | **fixa 6 s**: porta 33/34,2/35; silêncio 35,4; rosto ou cascata 36 |
| 17 | 39 | (−47, 17,4, 56) | (−43, 4, 10) | 70 | **Hold** | — | CORTE SECO para o FRENTE (ponte) |
| 18 | 60 | (−47, 17,6, 57,2) | (−43, 4, 10) | 70 | Linear | — | dolly-out mínimo até o fim |

Folgas (despensa x −49,8…−25,2, z −10,9…−3,9): keys 5–16 em x ∈ [−49; −26], z ∈ [−10,1; −4,7]; o corredor (z −7,5…−7,9)
fica ≥1,5 das prateleiras (z −5,2) e 3 da parede sul. A key 13 está a 3,6 studs do disjuntor (que fica embutido na
parede oeste, x −50,4) e 3 da parede. Keys 1–4 na cozinha: x −28,7 (2,5 da parede leste), z ≥ −1,8 (1,9 da parede dos
fundos). O vão da porta (x −28,1) é atravessado pelo centro (x −28,45).

---

## 5. Conferências e riscos

| # | Ponto | Estado |
|---|---|---|
| K1 | `/dev trigger stop blackout` toca `Resolved` (power_up + cascata)? Decide o #46 na track `front` | [A CONFIRMAR] — fallback: 2 clientes, B no disjuntor |
| K2 | DOOR-P abre/está aberta para a câmera e o bichinho passarem em T 11,5–14,5 | [A CONFIRMAR] no Studio |
| K3 | Ponto de parada do carro do drive-thru (key 7–8 da `kitchen`) | ajustar pelo `/dev drive state`; o quadro cobre a pista de z 5 a 27 |
| K4 | Com a câmera Scriptable, o tranco (`Shake Jolt`) e o FOV −3° da cena provavelmente **não** se aplicam à track; o corte de luz fica "limpo" | aceitável; o editor pode adicionar o tranco |
| K5 | O personagem local aparece se a câmera passar por ele (sem o ocultamento de 1ª pessoa) | as marcas em §4 o mantêm fora do quadro; ver TASK-C11 |
| K6 | O vulto nasce 60–80° fora do olhar: não entra em quadro em nenhuma track | #29 continua em POV manual (roteiro §6.3) ou com TASK-C3 |
| K7 | Em `blackout`, `HideUi = false` mantém também contadores/toasts | TASK-C7 do roteiro (esconder seletivo) |
| K8 | Toques de W são humanos: tolerância ±0,5 s; o bichinho na borda = cortar na montagem | gravar 3 tomadas |
| K9 | Fotossensibilidade: nenhum strobe; o único corte de luz é um frame | ok |

---

## 6. Propostas (sem código aqui)

| # | Proposta | Por quê |
|---|---|---|
| TASK-C10 | `/dev track <key> [scene <anomalia> at <t>]`: a track dispara a cena no segundo dado | tira o chat da tela e o erro humano do `Enter` em T 4 / 41 / 44 |
| TASK-C11 | durante uma track, ocultar o personagem local quando a câmera estiver a < 3 studs dele (como a 1ª pessoa) | permite andar colado à câmera na `blackout` sem o bichinho entrar no quadro |
| TASK-C12 | `/dev track <key> from <t>`: começar a track no segundo t | repetir só o trecho 28–39 da `blackout` sem refazer a cena inteira (com TASK-C2 do roteiro) |
