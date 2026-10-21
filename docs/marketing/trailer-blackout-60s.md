Status: Rascunho (Provisório)

# Trailer "Blackout" — roteiro de 60 s (+ cortes de 30 s e 15 s, todos 16:9)

Autor: cinematographer. v1 em 2026-10-20; v2 em 2026-10-20. Base de técnica: `marketing/research-trailer-cinematografia.md`
(esqueleto §7, checklist §8). Fontes do que existe: `design/anomalies-v2-proposal.md`, `design/horror-cinematic.md` §2–§8,
`design/faint-screen-flow.md`, `levels/MAP-01-r4-restaurant.md`, `audio/sound-list.md` §5.19–§5.20, `decisions.md`
(DEC-269 a DEC-320) e o código em `src/` (conferido em 2026-10-20; arquivos citados em cada linha do §2).

Nada aqui é aprovado como documento. As respostas do dono de 2026-10-20 estão aplicadas abaixo como **Provisório**; o
secretário registra em `decisions.md` se o dono quiser.

## Changelog

**v2 — 2026-10-20** (respostas do dono às perguntas TQ da v1):

| Resposta | O que mudou |
|---|---|
| TQ-1 lanterna: **não** | fica o halo branco + vermelho de emergência; lanterna saiu das perguntas e dos riscos (R1 fechado) |
| TQ-2 vulto | #41 mantém o vulto parado como licença de trailer (Provisório); resta a pergunta curta "só no trailer ou no jogo também?" |
| Música | o dono tem permissão de uso da música: risco de licença da música removido (R3 e TASK-C8 ficam só com SFX sem garantia) |
| Slogan **"Cook. Serve. Survive the night."** aprovado | usado no title card em EN; PT como alternativa |
| Jogo **só horizontal** | removido todo conteúdo 9:16 (corte vertical, terço central, margem de recorte, TQ-5, R10). O 15 s agora é **horizontal 16:9** e abre no apagão |
| Tela de queda fora | novo **plano-ponte #43A**: plano geral frontal do food truck, câmera alta e afastada, no escuro, antes do título. O mesmo enquadramento ("FRENTE") vira o estabelecimento #9 (aceso) e o stinger #46 (luz voltando) |
| Dono grava **sozinho** | §6 reescrito: técnicas para uma pessoa, viabilidade plano a plano, sessões de gravação em ordem; #22 e #31 reescritos para não depender de ação simultânea; nova proposta TASK-C9 (figurante parado) |

**v1 — 2026-10-20:** primeira versão.

**Legenda de existência** (vale para todo o documento):

| Marca | Significado |
|---|---|
| **[JOGO]** | existe no código hoje e aparece em Play (pode estar Provisório no design, mas roda) |
| **[ENCENAÇÃO]** | só setup de captura: posição de câmera, personagem parado, comando `/dev`. Não muda o que o jogo é |
| **[FALTA]** | precisa ser construído (ferramenta de captura, arte, som). Vira proposta de TASK no §8, sem código aqui |
| **[NÃO EXISTE]** | não está no jogo. **Não mostrar** no trailer |

---

## 1. Logline e objetivo

**Logline (interna):** um turno da noite fofo numa lanchonete de hot dog de bichinhos vai ficando errado, cliente a cliente,
até a energia cair — e alguém precisa atravessar o escuro até o disjuntor enquanto **algo** tenta abrir a porta dos fundos.

**O que o espectador precisa sentir, em ordem:** aconchego (chapa, bichinhos, amigos) → estranhamento (um rosto liso) →
pressão (regras simples, cada vez mais rápido) → **escuro** (só a luz vermelha e a respiração) → pavor de **espera**
(o anel do "segurar" enchendo, a maçaneta girando) → o susto → o trailer pequeno no escuro → um alívio falso → o arrepio final.

**O que ele precisa querer ao final:** "quero jogar isso hoje à noite **com meus amigos**". O co-op aparece duas vezes: na
cozinha (todo mundo fazendo uma coisa) e no apagão (um no monitor das câmeras, outro no disjuntor — a simultaneidade é
feita na montagem, ver §6).

**Promessa central (uma frase):** *as tarefas são simples; fazer no escuro é que não é.*

**Destaque:** ANM-020 The blackout ocupa **21 s dos 60** (29–50 s), é o único susto grande e é o plano-assinatura.

---

## 2. O que existe de verdade (levantamento para não prometer o que não há)

### 2.1 O apagão (ANM-020) — o que roda hoje

| Peça | Estado | Onde |
|---|---|---|
| Aviso: telefone com glitch (`phone_glitch`, 6,5 s); a luz cai 2 s depois | [JOGO] | `Rules/ANM-020` `OmenFor = 2`; `Content.HorrorScenes` blackout |
| Corte: "clunk" do quadro (`power_cut`, SFX-233) + zumbido morrendo (`hum_die`, SFX-235) + **sino** (`church_bell`) + tranco de câmera + FOV −3° | [JOGO] | HorrorScenes, DEC-290/293 |
| Apaga **tudo** (loja, letreiro fica fraco, tochas das mesas, postes); fica só a **luz de emergência vermelha** (EMERG-P) | [JOGO] | `Kit/Blackout` (letreiros: `SignBrightness`, ainda legíveis e fracos), DEC-286/287 |
| Barras de cinema; HUD some (moedas, loja, hotbar, chat); prompts ficam | [JOGO] | passo `Cinema`, DEC-296 |
| Legenda do Score: **"POWER OUT / FIX THE BREAKER"** | [JOGO] | `Content.Score` |
| Palavras na tela em rampa, na voz do personagem: "HE'S COMING", "WHERE'S THE BREAKER?", "FIX THE LIGHTS", "hurry...", "don't let him in" | [JOGO] | `HorrorScenes.Words.blackout`, DEC-293 |
| Luz branca fraca em volta do próprio jogador (alcance 5,6 studs) — o **halo** | [JOGO] | `Effects/ANM-020` `GLOW_*` |
| Brilho mostarda pulsando no disjuntor; prompt **"Reset Breaker"**, **segurar 3 s** | [JOGO] | `Content.Actions` `breaker_reset` |
| **Vulto** no canto do olho (60–80° fora do olhar), some quando olhado; mais perto com o tempo | [JOGO] (feito de Parts; arte final [FALTA]) | `Effects/ANM-020` |
| Violino: notas em loop subindo + uma nota longa subindo, **cortada seca aos 30 s** | [JOGO] (música: uso permitido, dono 2026-10-20) | `Content.Score`, DEC-292 |
| Coração 62 → 150 BPM a partir de 14 s; **para morto em 29,4 s** (0,6 s só de violino) | [JOGO] | HorrorScenes |
| **The Walker** (AST-064) anda do beco até a porta da despensa — **visto só pelas câmeras de segurança** | [JOGO] | HorrorScenes `Seen = "Cameras"`, DEC-292 |
| Sombra dele **corta a fresta de luz debaixo da porta** da despensa | [JOGO] | passo `Shadow` |
| Maçaneta girando (`handle_rattle` SFX-238), porta forçada (`door_force` SFX-239), trava segura (`latch_hold` SFX-240) aos 27–29 s | [JOGO] | passos `Door` |
| Falhou aos 30 s: **rosto cartoon em tela cheia 0,6 s** (cabeça escura, olhos brancos enormes, sorriso de dentes) + desmaio | [JOGO] | `Kit/Jumpscare`, DEC-255/256 |
| Religou a tempo: `power_up` (SFX-242) + lâmpadas em cascata (`lamps_cascade` SFX-243) | [JOGO] | passo `Resolved` |
| Walt avisa na ligação da noite: "Lights might go out tonight. Breaker's out back. Hold it." | [JOGO] (voz gerada) | `Content.BossCalls` |
| A cena roda em **todos os clientes** (o escuro é local de cada um, a linha do tempo é a mesma) | [JOGO] | `Dev/Commands/Scene.luau`, `Kit/Blackout` |
| **Lanterna** (cone) | **[NÃO EXISTE]** e não vai existir para o trailer (dono, 2026-10-20) | `Effects/ANM-020` |
| Walker visto em 1ª pessoa / entrando na loja | **[NÃO EXISTE]** — só nas câmeras | DEC-292 |
| Esconder salvando do apagão | **[NÃO EXISTE]** desde DEC-292 (só o disjuntor salva) | DEC-292 |

**Consequência para o roteiro:** a revelação acontece **no halo** do jogador (a luz branca de 5,6 studs + a vermelha de
emergência). No escuro quase total ele lê como uma "bolha" de segurança, e a borda dela é onde o vulto aparece.

### 2.2 O resto do jogo que o trailer pode mostrar

| Conteúdo | IDs | Estado |
|---|---|---|
| Trailer expandido (visual do AST-027), por dentro uma cozinha; mesas de piquenique com tochas na frente | MAP-01 (r4), DEC-281, AST-100 | [JOGO] |
| Run começa **à noite** (Noite 1) — não há turno de dia na run nova | DEC-300, `Shift.RunStartsAtNight = true` | [JOGO] |
| Pedido no tablet com mini-diálogo; ficha do pedido sobre o prato | FEAT-043, DEC-270/311, `PlateOrderCard` | [JOGO] |
| Grelha com minigame de virar (zona Perfect/Nice), salsicha pronta ao descanso | DEC-311, `Cook/Grill`, `FlipMeter` | [JOGO] |
| Pão cortado, montagem no mundo, ketchup/mostarda com bisnaga e guia em S | DEC-308/310/311 | [JOGO] |
| Drive-thru: carro na janela lateral, **cliente visível ao volante** | FEAT-047, DEC-274, TASK-574 | [JOGO] |
| Co-op até 4, todos em paralelo; personagens bichinhos (classes Rookie, Runner, Line Cook, Hauler…) | DEC-275, FEAT-028, `Content.Classes` | [JOGO] |
| Café contra sanidade baixa | FEAT-019, FEAT-021 | [JOGO] |
| Câmeras de segurança com visão noturna verde; monitor CCTV no mundo com REC e grão | FEAT-040, `SecurityController`, `Screen.luau` | [JOGO] |
| Anomalias com cena dirigida: ANM-001 sem rosto, 004 a cópia, 005 Raincoat Lady, 006 stalker, 008 carro comprido, 011 o que treme, 012 pescoço invertido, 013 olhos brancos, 014 cabeça errada, 015 flutuando, 016 não pisca, 017 rastejador, 019 sombra no teto, 021 névoa vermelha, 010 Hush (N10) | `Content.Anomalies`, `HorrorScenes/Scenes/*` | [JOGO] |
| Clientes "Night" viram a cabeça seguindo o jogador durante anomalias de tensão | DEC-296 | [JOGO] |
| Atmosferas por noite: breu, névoa vermelha, chuva, tempestade, neblina, lua de sangue | ATM-1..7 | [JOGO] |
| Eventos de suspense (relance com câmera puxada) e pressão de encarar | DEC-294, `Suspense` | [JOGO] |
| Tela de queda (causa → revive 15 s → Revive all) | DEC-318/319 | [JOGO] — **fora do trailer** (dono, 2026-10-20); no lugar dela entra o plano-ponte #43A |
| Mart / Opal / compra de ingredientes, ladrão, ambulância, cutscene de abertura, turno de dia | DEC-307/308/309/313/314 | **[NÃO EXISTE]** — não mostrar |

> Nota: `marketing/descricao-jogo.md` ainda vende Mart, "by day" e "HIDE… close the window". Está desatualizada em
> relação a DEC-300/307/292; o trailer **não** deve copiar essas promessas (risco R7).

---

## 3. Estrutura em atos

| Ato | Tempo | Função | Conteúdo |
|---|---|---|---|
| 0. Gancho | 0,0–3,0 | prender antes do pulo | escuro + luz vermelha + palavra "WHERE'S THE BREAKER?" + sombra na fresta → corte seco para a chapa |
| 1. Normalidade | 3,0–12,0 | o aconchego que vai ser violado | grelha, virar Perfect, ketchup, mesas, drive-thru, amigos cozinhando; fecha no plano FRENTE aceso |
| 2. Algo errado | 12,0–19,0 | inciting incident + falso alívio | match cut no tablet: o cliente levanta o rosto liso (ANM-001); recusa; alívio |
| 3. Escalada | 19,0–29,0 | regras + ameaças, corte acelerando | cartelas de regra; 6 anomalias em cortes de 1,5 → 0,4 s; luzes começam a falhar |
| 4. **Blackout** | 29,0–50,4 | o ponto alto | telefone → apagão → caminho no escuro → câmeras (Walker) → segurar 3 s × maçaneta → silêncio → revelação → susto → preto |
| 5. Ponte + título | 50,4–55,6 | assentar o medo, marca | **plano FRENTE no escuro** (#43A): o trailer pequeno, apagado, o vermelho de emergência; o título acende sobre ele; CTA |
| 6. Stinger | 55,6–60,0 | falso alívio + arrepio | mesmo plano FRENTE: a luz volta em cascata, mesas cheias… todos os clientes viram a cabeça juntos; corte seco |

O enquadramento **FRENTE** (câmera alta, afastada, de frente para o food truck) aparece três vezes: **aceso** (#9),
**apagado** (#43A) e **voltando** (#46). É a rima visual do trailer e um único ponto de câmera para gravar (§6).

Os **3 momentos-chave**:
1. **14,5 s — o rosto liso** (ANM-001): primeira quebra, pequena e legível em 1 s.
2. **40–47 s — o "segurar E" contra a maçaneta**: tarefa banal (segurar um botão 3 s) cortada com a porta sendo forçada; é
   a promessa do jogo em um plano.
3. **58,5 s — as cabeças viram juntas** (stinger): depois do alívio, a lanchonete inteira olha para a câmera. Corte.

---

## 4. Curva de tensão (por segundo)

Escala 0–10. `S` = silêncio total no som (a tensão continua no máximo).

```
10 |                                                ###
 9 |                                            #######
 8 |                              ##        ###########         ##
 7 |                            ####    ###############         ##
 6 |##                      ##  ####  ##################        ##
 5 |##                  ##  #############################       ##
 4 |##            ####  #################################       ##
 3 |##          ###########################################     ##
 2 |####    ####################################################
 1 |############################################################
   +------------------------------------------------------------
    0         10        20        30        40        50        60 s
    ^gancho   ^normal  ^rosto ^regras ^APAGÃO      S^ ^susto ^FRENTE/título ^stinger
```

| s | Tensão | Evento da curva |
|---|---|---|
| 0–3 | 6 → 1 | gancho no escuro; o corte para a chapa derruba a tensão (contraste) |
| 3–12 | 1–2 | vale longo, quente; fecha no plano FRENTE aceso (o lugar seguro) |
| 12–17 | 3 → 4 | o rosto liso; drone entra |
| 17–19 | 3 | **falso alívio 1**: janela fechada, o cliente some, a fila segue |
| 19–29 | 4 → 7 | serra crescente: cada anomalia sobe 1, cada cartela respira meio ponto |
| 29–31 | 7 → 6 | **falso alívio 2**: só o telefone tocando, cozinha ainda acesa |
| 31 | 8 | clunk + sino: o apagão |
| 31–35 | 5 → 6 | escuro, mas parado: respiração, palavras poucas |
| 35–47 | 6 → 9 | caminho até o disjuntor, câmeras, maçaneta × anel enchendo; corte acelera |
| 47,0–48,5 | 9 (`S`) | **silêncio**: só respiração abafada e o zumbido do anel |
| 48,5–50,0 | 10 | revelação no halo + rosto (o único susto grande) |
| 50,0–50,4 | 10 | preto, silêncio |
| 50,4–53,4 | 6 → 4 | **plano FRENTE no escuro**: nada acontece; o medo assenta. O lugar seguro do #9 agora é uma caixinha apagada no breu |
| 53,4–55,6 | 3 → 2 | título e CTA |
| 55,6–58,5 | 2 | **falso alívio 3**: a luz volta em cascata no mesmo plano, tudo quente de novo |
| 58,5–60 | 8 | cabeças viram; corte seco no pico |

---

## 5. Shot list — 60 s, 16:9

Captura em 60 fps, montagem em 30 fps. Tempos em segundos. "POV" = câmera do jogador em 1ª pessoa (padrão do jogo, sem
braços, DEC-097). "Free" = câmera livre (Shift+P). "Script" = câmera de captura ([FALTA], TASK-C1). "FRENTE" = o
enquadramento fixo do food truck descrito no #9 e guardado para #43A e #46.
**Grading** no editor de vídeo, por cima do look do jogo: *Quente* (âmbar, saturação média), *Frio* (ciano, −20 % sat.,
vinheta), *Breu* (quase mono, vermelho de emergência preservado, branco do halo levemente quente).

### Ato 0 — Gancho (0,0–3,0)

| # | Tempo | Plano / câmera | Luz / cor | Ação (IDs) | Áudio | Texto na tela | Transição | Existe |
|---|---|---|---|---|---|---|---|---|
| 1 | 0,0–1,6 | POV parado no corredor dos fundos, olhando a porta da despensa; leve respiração de câmera (handheld 0,3°) | Breu; só EMERG-P vermelha e a fresta de luz sob a porta | apagão ativo (ANM-020) | silêncio → **respiração** próxima | palavra do jogo pulsando no canto: **WHERE'S THE BREAKER?** | — | [JOGO] + [ENCENAÇÃO] |
| 2 | 1,6–2,4 | detalhe da fresta sob a porta | Breu | uma **sombra** corta a fresta (passo `Shadow`) | respiração para | — | — | [JOGO] |
| 3 | 2,4–3,0 | preto | — | — | **clunk** do disjuntor ao contrário: `power_up` (SFX-242) cortado em 0,3 s | — | smash cut para #4 (som da chapa entra no corte) | [JOGO] |

> Regra: o gancho usa o **segundo** melhor plano (sombra na fresta). O melhor (revelação + rosto) fica para 48,5 s.

### Ato 1 — Normalidade (3,0–12,0)

| # | Tempo | Plano / câmera | Luz / cor | Ação (IDs) | Áudio | Texto | Transição | Existe |
|---|---|---|---|---|---|---|---|---|
| 4 | 3,0–4,6 | detalhe da grelha, câmera baixa, dolly in lento | Quente | salsicha cai e chia; o minigame de virar abre e o clique cai em **Perfect** | `grill_sizzle`, SFX-020 `grill_drop`; música do trailer entra (tema fofo, ver §7) | — | corte | [JOGO] (Script ou POV focado) |
| 5 | 4,6–5,4 | POV focado na mesa de condimentos | Quente | bisnaga desenha o S de ketchup seguindo o guia; "Perfect" | `topping_squirt` | **EN** THE NIGHT SHIFT IS HIRING · **PT** O TURNO DA NOITE ESTÁ CONTRATANDO (cartela segue sobre o #6) | corte | [JOGO] |
| 6 | 5,4–6,0 | detalhe do prato pousado na bancada, ficha do pedido em cima | Quente | pão + salsicha + ketchup completos batem com a ficha (DEC-311) | `serve` | (continua) | corte | [JOGO] |
| 7 | 6,0–7,8 | plano geral de dentro, câmera alta no canto (Free, fixa) | Quente | 3 bichinhos na cozinha: um ativo (o que o dono controla no take) e dois parados em estações — grelha, pão, tablet (co-op, DEC-275) | burburinho, `order_take` | — | corte | [JOGO] + [ENCENAÇÃO] (3 clientes, §6) |
| 8 | 7,8–9,4 | plano médio pelo vidro do drive-thru | Quente + faróis | carro para na janela, o cliente bichinho ao volante acena (FEAT-047) | motor, `car_honk_soft` curto | — | corte | [JOGO] |
| 9 | 9,4–12,0 | **FRENTE**: plano geral frontal do food truck, câmera **alta e afastada** (≈ 30 studs à frente, ≈ 15 acima, leve plongée de 15–20°), o trailer no terço inferior e as mesas com tochas em primeiro plano; **push-in** muito lento | Quente no trailer, no letreiro e nas tochas; rua escura em volta (espaço negativo) | trailer iluminado, mesas cheias de clientes comendo; letreiro aceso | música no auge fofo; **no último 0,5 s a música perde uma nota** | **EN** SERVE THE LINE · **PT** ATENDA A FILA | match cut de forma para #10 (retângulo aceso da janela do balcão → tela do tablet) | [JOGO] + [ENCENAÇÃO] |

### Ato 2 — Algo errado (12,0–19,0)

| # | Tempo | Plano / câmera | Luz / cor | Ação (IDs) | Áudio | Texto | Transição | Existe |
|---|---|---|---|---|---|---|---|---|
| 10 | 12,0–14,5 | POV no tablet, cliente de cabeça baixa no balcão; câmera parada | Quente, a lâmpada do tablet pisca 2× | ANM-001 (`Pose` Lift começando) | música some em 1 s; `phone_glitch` curto no tablet; **drone** entra | — | — | [JOGO] |
| 11 | 14,5–16,0 | close no cliente, dolly in curto | **Frio** entra em 1 s | **ele levanta o rosto: liso**; barras finas do jogo | sub grave curto (`horror_sting`) | — | — | [JOGO] — momento-chave 1 |
| 12 | 16,0–17,2 | POV: a persiana da frente desce (recusar = fechar a janela, DEC-261) | Frio | o jogador fecha | batida metálica da persiana | **EN** REFUSE THE WRONG ONES · **PT** RECUSE OS ERRADOS | corte | [JOGO] |
| 13 | 17,2–19,0 | plano médio, mesmo enquadramento do #7 (match cut) | volta a Quente | cozinha segue; um amigo serve um prato — **falso alívio** | 1,5 s depois da persiana, **uma batida de dedo do outro lado** (réplica da cena ANM-001) | — | corte no toque | [JOGO] + [ENCENAÇÃO] (técnica T1, §6) |

### Ato 3 — Escalada (19,0–29,0)

Cortes de 1,5 s caindo até 0,4 s. Cada plano é **uma** anomalia legível em 1 s. Cartelas de 1 s entre eles. Riser contínuo
de 19 a 29 s, com **pico exatamente no corte de 29,0**.

| # | Tempo | Plano / câmera | Luz / cor | Ação (IDs) | Áudio | Texto | Existe |
|---|---|---|---|---|---|---|---|
| 14 | 19,0–20,4 | over-the-shoulder no balcão | Frio | **pescoço invertido** (ANM-012): a cabeça gira devagar para trás | estalo seco | — | [JOGO] |
| 15 | 20,4–21,4 | cartela sobre preto | — | — | hit grave | **EN** DON'T STARE · **PT** NÃO ENCARE | — |
| 16 | 21,4–22,6 | POV da cozinha, olhando a vitrine; câmera parada | Frio, ATM-3 **névoa vermelha** lá fora | **olhos brancos** (ANM-013): todos os clientes Night viram para o jogador juntos (DEC-296) | coração entra (70 BPM) | — | [JOGO] |
| 17 | 22,6–23,6 | plano geral da rua, longe | ATM-2 breu | **stalker** (ANM-006) parado sob o poste da parada; o poste pisca 3× | zumbido de poste | — | [JOGO] |
| 18 | 23,6–24,4 | POV no drive-thru | farol alto branco pela janela (`Glare` Flash) | **carro comprido** (ANM-008) freia na janela | freio guinchando, motor desliga | — | [JOGO] |
| 19 | 24,4–25,0 | detalhe do piso da cozinha, câmera rente | Frio | **rastejador** (ANM-017): as tábuas cedem | `floor_creak` SFX-247 | — | [JOGO] |
| 20 | 25,0–25,6 | POV olhando para cima, dutch 12° | Frio | **sombra no teto** (ANM-019): passos e mancha andando | batidas no teto | **EN** DON'T LOOK UP · **PT** NÃO OLHE PRA CIMA (ver TQ-6) | [JOGO] |
| 21 | 25,6–26,4 | close na caneca de café sendo bebida (POV) | Quente rápido | o jogador bebe café (FEAT-021) — micro-respiro | gole + respiração | — | [JOGO] |
| 22 | 26,4–27,2 | plano geral de dentro (Free, fixa) | as lâmpadas da cozinha **piscam 2×** (omen do apagão, `blackout_warn`) | **um** bichinho para no meio da cozinha e olha o teto (v1 pedia "todos"; reescrito para um ator só) | `hum_rise` SFX-234 | — | [JOGO] + [ENCENAÇÃO] (T1) |
| 23 | 27,2–28,0 | cartela | — | — | riser subindo | **EN** AND NEVER... · **PT** E NUNCA... | — |
| 24 | 28,0–29,0 | cartela | — | — | riser no topo | **EN** ...LET THE LIGHTS GO OUT · **PT** ...DEIXE A LUZ APAGAR | corte seco + **o riser morre no corte** |

### Ato 4 — Blackout, ANM-020 (29,0–50,4) — o ponto alto

Planos longos de novo (contraste com a escalada), depois acelerando até a maçaneta. Tudo é a cena real do jogo, capturada
com `/dev scene blackout` em **tomadas solo** (§6): disjuntor, monitor e porta são tomadas diferentes da mesma cena,
intercaladas na montagem.

| # | Tempo | Plano / câmera | Luz / cor | Ação (IDs) | Áudio | Texto | Transição | Existe |
|---|---|---|---|---|---|---|---|---|
| 25 | 29,0–31,0 | plano médio da cozinha, câmera parada à altura do balcão | Quente (última vez) | o telefone fixo toca com glitch; um bichinho vira a cabeça para ele — **falso alívio 2** (parece só uma ligação) | `phone_glitch` (6,5 s, começa aqui e segue por baixo); silêncio de música | — | — | [JOGO] + [ENCENAÇÃO] (T1) |
| 26 | 31,0 (+12 frames) | mesmo plano | **tudo apaga** num frame; EMERG-P vermelha acende | ANM-020 Active | **clunk** `power_cut` SFX-233 + `hum_die` SFX-235 + **sino** `church_bell`; câmera dá o tranco do jogo (Jolt, FOV −3°) | — | 12 frames de preto total depois do corte | [JOGO] |
| 27 | 31,4–34,0 | POV no escuro, parado; as barras de cinema do jogo fecham | **Breu**: halo branco 5,6 studs + vermelho | a legenda do jogo entra | **silêncio** + respiração do personagem; `phone_glitch` ainda falando baixo | legenda do jogo: **POWER OUT / FIX THE BREAKER** | — | [JOGO] |
| 28 | 34,0–36,6 | POV andando devagar pelo corredor dos fundos; a câmera "respira" (FOV ±1°) | Breu; no fim do corredor, o **brilho mostarda pulsando** no disjuntor | caminho até o disjuntor; as palavras do jogo começam poucas: "WHERE'S THE BREAKER?", "hurry..." | passos do próprio jogador ecoando; violino (notas em loop) entra baixo; coração 62 BPM | palavras do jogo (Whispers, rampa) | — | [JOGO] |
| 29 | 36,6–37,4 | POV: **vulto** no canto do quadro, 70° fora do olhar | Breu | o vulto do ANM-020 aparece e some quando a câmera vira | nada (só o corte da respiração) | — | whip pan para #30 | [JOGO] (vulto em Parts: arte [FALTA], R4) |
| 30 | 37,4–39,4 | **visão das câmeras de segurança**, verde noturno, granulada, carimbo REC | verde | **The Walker** (AST-064) anda pelo beco até a porta da despensa — o único lugar onde ele é visível (DEC-292) | passos pesados (`walker_step`; `heavy_steps` SFX-236 sem asset, R5) | — | corte | [JOGO] — tomada C, o dono no monitor (FEAT-040) |
| 31 | 39,4–40,2 | plano médio **por trás** de um bichinho parado diante do monitor CCTV do mundo (tela com REC e grão); ele recua meio passo | a luz da tela no rosto; o verde é reforçado no grading só sobre a tela e o rosto | o colega viu o Walker | respiração abafada | — | corte | [JOGO] + [ENCENAÇÃO] — **substitui** o OTS da v1 (que pedia a câmera do jogador 2 enquanto o 1 agia): 2 clientes, T1 + T3 |
| 32 | 40,2–41,4 | POV chegando ao disjuntor; o prompt **"Reset Breaker"** aparece | Breu + mostarda | começa a **segurar E**; o anel do prompt começa a encher | violino sobe; coração 100 BPM; palavras do jogo **tomam a tela** ("HE'S COMING") | prompt do jogo (PC: "E") | corte | [JOGO] |
| 33 | 41,4–42,4 | detalhe da fresta sob a porta da despensa | vermelho | a sombra **entra** na fresta e para | `steps_stop` SFX-237 | — | corte | [JOGO] |
| 34 | 42,4–43,2 | detalhe do anel do prompt (≈ 1/3) | mostarda | — | violino | — | corte | [JOGO] |
| 35 | 43,2–44,2 | plano fixo da porta da despensa, de dentro | vermelho | **a maçaneta gira e trava** (`Door` Rattle) | `handle_rattle` SFX-238; câmera do jogo treme na direção da porta | — | corte | [JOGO] |
| 36 | 44,2–44,8 | anel (≈ 2/3) | mostarda | — | violino quase no topo; coração 150 | — | corte | [JOGO] |
| 37 | 44,8–45,6 | porta | vermelho | **a porta é forçada no batente**; poeira cai | `door_force` SFX-239 | — | corte | [JOGO] |
| 38 | 45,6–46,2 | anel (≈ 90 %) | mostarda | — | — | — | corte | [JOGO] |
| 39 | 46,2–47,0 | porta | vermelho | **a trava segura** | `latch_hold` SFX-240 (seco) | — | corte | [JOGO] |
| 40 | 47,0–48,5 | POV no disjuntor, câmera **imóvel**; o anel quase cheio | Breu, vinheta 0,5 do jogo | **SILÊNCIO**: violino corta, coração para (o jogo faz isto em 29,4 s da cena) | **nada** — só uma respiração abafada (`breath_held` SFX-241) e o zumbido mínimo do prompt | as palavras param | — | [JOGO]; o anel parado é **congelamento de quadro na montagem** (R14) |
| 41 | 48,5–49,4 | POV vira devagar para trás (whip lento, 0,5 s), **para no halo** | halo branco + vermelho atrás | **revelação no halo**: o vulto está de pé na borda da luz, a 5 studs, e **não some** | nenhum som até o último frame | — | — | [ENCENAÇÃO] Provisória: no jogo o vulto some ao ser olhado (R4, TQ-2) |
| 42 | 49,4–50,0 | tela cheia | — | **o rosto do jumpscare** (cabeça escura, olhos brancos, sorriso de dentes), 0,6 s, como no jogo | `jumpscare` (com limitador, sem grito; Mild) | — | **smash cut to black** | [JOGO] (Failed aos 30 s) |
| 43 | 50,0–50,4 | preto | — | — | silêncio total | — | — | — |

### Ato 5 — Ponte + título + CTA (50,4–55,6)

No lugar da tela de queda (fora do trailer): o espectador sai da cabeça do personagem e vê **de longe** o lugar onde tudo
aconteceu. Nenhum susto aqui; o plano é para o medo assentar e para a marca entrar.

| # | Tempo | Plano / câmera | Luz / cor | Ação (IDs) | Áudio | Texto | Transição | Existe |
|---|---|---|---|---|---|---|---|---|
| 43A | 50,4–53,4 | **FRENTE** (mesmo ponto do #9): plano geral frontal do food truck, câmera alta e afastada, leve plongée; **quase estático**, dolly-out muito lento (≈ 2 studs em 3 s) | **Breu**: trailer apagado, tochas apagadas, letreiro fraco (como o jogo deixa); o vermelho de emergência só onde ele realmente vazar pela janela/porta (R13); rua preta em volta | o trailer pequeno no escuro, as mesas vazias de luz; nada se mexe | silêncio → vento baixo e um zumbido elétrico morto; em 51,8 o **sub-drop** entra com a primeira letra | em 51,8 o letreiro do título começa a acender letra a letra (neon com mau contato) no **terço superior**, sobre o breu acima do trailer | a imagem escurece sob o título a partir de 53,0 | [JOGO] + [ENCENAÇÃO] (tomada A ou a cena rodando sem ninguém no disjuntor; câmera FRENTE, §6) |
| 44 | 53,4–54,6 | title card sobre preto (a imagem do #43A terminou de sumir) | neon quente do letreiro | — | zumbido de neon | **SELL HOTDOGS!** + linha aprovada: **EN** Cook. Serve. Survive the night. (alternativa **PT**: Cozinhe. Atenda. Sobreviva à noite.) | — | — |
| 45 | 54,6–55,6 | mesmo card | — | — | zumbido do neon | **EN** Play now on Roblox · Up to 4 friends · **PT** Jogue agora no Roblox · Até 4 amigos | corte seco | — |

### Ato 6 — Stinger (55,6–60,0)

| # | Tempo | Plano / câmera | Luz / cor | Ação (IDs) | Áudio | Texto | Transição | Existe |
|---|---|---|---|---|---|---|---|---|
| 46 | 55,6–56,8 | **FRENTE** de novo, estático | Breu → **a luz volta em cascata** (do disjuntor para fora) | o disjuntor religou (Resolved) — alguém da equipe conseguiu | `power_up` SFX-242 + `lamps_cascade` SFX-243 | — | — | [JOGO] (tomada B) |
| 47 | 56,8–58,5 | plano médio das mesas, câmera parada | Quente total — **falso alívio 3** | clientes comendo, tudo normal; música fofa volta 2 compassos, **com a nota faltando** | música fofa baixinha | — | — | [JOGO] |
| 48 | 58,5–59,6 | mesmo plano | Quente, mas a música para | **todos os clientes das mesas viram a cabeça juntos para a câmera** (NightWatch, DEC-296) | silêncio; um único estalo seco | — | — | [JOGO] (só roda durante anomalia de tensão: setup [FALTA], TASK-C4) |
| 49 | 59,6–60,0 | preto | — | — | nada | — | **corte seco** (sem fade) | — |

---

## 6. Mapa de captura no Studio — gravação solo

O dono grava **sozinho**. Nenhum plano depende de duas pessoas agindo ao mesmo tempo: o que parece simultâneo no trailer
é montagem de tomadas da mesma cena, ou um ator ativo com figurantes parados.

### 6.1 Setup geral

| Item | Valor |
|---|---|
| Place | o place do jogo, MAP-01 (r4), pasta `Trailer` (é o restaurante) |
| Sessão | **Studio Test → Clients and Servers**. Padrão **1 cliente** (a maioria dos planos); **2 clientes** para #13, #22, #25, #31 e #46 alternativo; **3 clientes** só para #7. Cada cliente é uma janela; o input só vai para a janela em foco |
| Personagens | em cada cliente escolha uma **classe diferente** (bichinhos diferentes no quadro); se a escolha de classe no Test não ficar livre, aceitar bichinhos repetidos nos planos gerais [NÃO CONFIRMADO] |
| Modo dev | `/dev` via chat ou console Conch (`dev <comando>`); lista e sintaxe: `/dev help` e `docs/tech/dev-commands.md`. Os comandos abaixo vêm da v1 e de `src/Dev` — confirmar a sintaxe no `/dev help` antes da sessão |
| Proteções | `/dev autorevive on` (o susto não derruba a tomada), `/dev infsanity on` (sanidade não distorce a tela fora da hora), `/dev customer off` quando o plano pede fila controlada |
| Câmera livre | **Shift+P** (destaca a câmera e esconde a UI). Ctrl+Shift+G/C/B/N para esconder CoreGui, ScreenGuis, Billboards, nameplates — os planos #1, #27, #28, #32 precisam da UI do jogo (palavras, legenda, prompt): gravar em POV com só CoreGui/nameplates escondidos |
| Gravação | OBS, **captura de janela** do cliente que é a câmera (recortar só o viewport, sem barras do Studio), 60 fps, 1920×1080 no mínimo; **2560×1440** quando a máquina aguentar (folga para reenquadrar e para o dolly-out digital do #43A). Áudio do jogo em faixa separada |
| Gráficos | qualidade máxima, iluminação Future (style guide), sem FPS cap. Com 2–3 clientes, minimizar as janelas que não são a câmera nem o ator (R12) |

### 6.2 Técnicas para uma pessoa

| Código | Técnica | Como |
|---|---|---|
| **T1** | **Câmera parada + ator** | janela A = câmera: Shift+P (ou TASK-C1), enquadra, OBS gravando A. Clique na janela B = ator: age (anda, serve, vira a cabeça). A câmera livre de A não se mexe sem foco, então fica fixa enquanto você joga em B |
| **T2** | **Tomadas da mesma cena** | a cena do apagão tem linha do tempo fixa (porta aos 27–29 s, susto aos 30 s). Grave a cena inteira várias vezes, cada vez em um papel (disjuntor, monitor, porta); a montagem intercala como se fossem pessoas diferentes |
| **T3** | **Figurante parado** | deixe o cliente B/C numa estação (de frente para a grelha, para a tábua, para o monitor) e tire o foco da janela: o bichinho fica parado no lugar. Enquadre largo para que ficar parado leia como "trabalhando" |
| **T4** | **Figurante por comando** [FALTA] | `/dev standin` (TASK-C9): cópia parada do seu bichinho na posição atual. Substitui T3 sem abrir clientes extras |
| **FRENTE** | **ponto de câmera fixo** do food truck | hoje: Shift+P, posicionar ≈ 30 studs à frente da fachada, ≈ 15 acima, plongée de 15–20°, trailer no terço inferior; tirar um print de referência e alinhar a cada tomada pelo print (letreiro e mesa da frente como marcas). Com TASK-C1: `cam save frente` / `cam go frente`, exato nas três tomadas, e o dolly-out lento do #43A sai limpo. Sem TASK-C1, gravar estático e fazer o dolly-out com zoom digital lento na montagem (gravar em 1440p) |

### 6.3 Plano a plano

| Planos | Hora / noite / atmosfera | Setup e comandos | Câmera | Solo: como | Viável solo |
|---|---|---|---|---|---|
| #1, #2 gancho | `/dev night 3`, `/dev atm ATM-2` | `/dev scene blackout`; ficar no corredor dos fundos | #1 POV; #2 Free, rente à fresta | 1 cliente; a sombra passa na fresta sozinha | sim |
| #4–#6 grelha, ketchup, prato | `/dev night 2`, `/dev time 10:30`, `/dev atm ATM-1` | `/dev customer on`; pegar um pedido e preparar | POV focado (ou Script, TASK-C1) | 1 cliente | sim |
| #7 cozinha co-op | mesma | 3 clientes: B na grelha, C na tábua de pão (T3, parados); A no tablet | câmera: Free na janela **A** alta no canto; ou Free numa janela **D** extra se a máquina aguentar | T1 + T3: B e C parados nas estações; A faz o único gesto (pega o pedido no tablet). Alternativa leve: 2 clientes + T4 | sim (3 clientes) / sim com TASK-C9 |
| #8 drive-thru | mesma | `/dev drive car` | Free pelo vidro | 1 cliente | sim |
| #9 FRENTE aceso | mesma | `/dev customer tables sit` repetido até as mesas encherem | **FRENTE**, push-in lento (TASK-C1) ou estático + zoom digital | 1 cliente | sim |
| #10–#12 ANM-001 | mesma | `/dev trigger anm_001_blank_folks`; jogador no tablet | POV | 1 cliente; 3 tomadas, usar a de rosto subindo mais devagar | sim |
| #13 amigo serve | mesma | 2 clientes; câmera em A com o mesmo enquadramento do #7 | Free em A | T1: B pega um prato pronto e serve | sim |
| #14 ANM-012 | `/dev night 4`, `/dev atm ATM-4` (chuva) | `/dev trigger anm_012_turned_neck` | Free, OTS | 1 cliente | sim |
| #16 ANM-013 | `/dev atm ATM-3` (névoa vermelha) | `/dev customer tables sit` antes; `/dev trigger anm_013_white_eyes` | POV | 1 cliente; os clientes Night viram juntos sozinhos (DEC-296) | sim |
| #17 ANM-006 | `/dev atm ATM-2` | `/dev trigger anm_006_stalker` | Free, longe | 1 cliente; não encarar mais de ~2 s (ele avança) | sim |
| #18 ANM-008 | `/dev night 8` | `/dev trigger anm_008_long_car` | POV no computador do drive-thru | 1 cliente | sim |
| #19 ANM-017 | qualquer | `/dev trigger anm_017_crawler` (nome pelo `/dev trigger list`) | Free rente ao chão | 1 cliente | sim |
| #20 ANM-019 | qualquer | `/dev trigger anm_019_roof_walker`; olhar para cima | POV | 1 cliente | sim |
| #21 café | qualquer | `/dev coffeecup fill`, beber | POV | 1 cliente | sim |
| #22 aviso | `/dev night 3`, `/dev atm ATM-2` | 2 clientes; `/dev scene blackout` e gravar só o Signal (piscadas antes do corte) | Free em A, plano geral | T1: B para no meio da cozinha e olha o teto | sim (reescrito para um ator) |
| #25–#26 telefone + corte | mesma | 2 clientes; `/dev scene blackout` | Free em A, altura do balcão | T1: B vira a cabeça para o telefone; o apagão vem sozinho | sim |
| #27–#29, #32, #34, #36, #38, #40, #42 POV do disjuntor | mesma | 1 cliente; **tomada A**: `/dev scene blackout`, andar até o disjuntor, segurar E em trechos parciais (anel a 1/3, 2/3, 90 %) e **soltar antes de encher**; aos ~29 s segurar até ~90 % e soltar → Failed aos 30 s → rosto (#42) | POV, só CoreGui/nameplates escondidos | T2. O anel reseta ao soltar: #40 é congelamento do quadro de ~90 % (R14) | sim |
| #46 luz voltando | mesma | **tomada B**: câmera FRENTE e `/dev anomaly ANM-020 resolve` pelo console (se o comando tocar o passo `Resolved` com a cascata [A CONFIRMAR]); senão 2 clientes: A na FRENTE (T1), B segura E no disjuntor até religar | **FRENTE**, estático | T1 ou comando | sim |
| #30 Walker nas câmeras | mesma | **tomada C**: 1 cliente; antes de disparar, abrir o monitor (`Cameras`), escolher a câmera do beco e visão noturna (N); `/dev scene blackout`; ficar no monitor até o Failed | a própria visão das câmeras (OBS na janela) | T2: neste take ninguém vai ao disjuntor | sim |
| #31 colega no monitor | mesma | 2 clientes; B abre o monitor (o corpo fica preso diante dele) e perde o foco; `/dev scene blackout` | Free em A, por trás de B, a tela CCTV do mundo no quadro | T1 + T3. O verde da visão noturna é local de B e não aparece em A: o verde vem da tela do mundo + grading | sim (substituto da v1) |
| #2, #33, #35, #37, #39 fresta e porta | mesma | **tomada D**: 1 cliente; `/dev scene blackout`, ir para dentro da despensa e Shift+P apontando a porta e a fresta | Free, fixa | a porta é forçada aos 27–29 s sozinha; nenhum ator necessário | sim |
| #41 revelação | mesma | encenação: com TASK-C3, flag de captura e o vulto fica; **sem ela**: durante a tomada, no Explorer da janela do cliente, duplicar o modelo do vulto, tirá-lo do controle do efeito (pôr na Workspace, ancorado) e colocá-lo a 5 studs atrás do POV | POV vira devagar | 1 cliente | sim, [ENCENAÇÃO] Provisória (TQ-2) |
| #43A FRENTE no escuro | mesma | **tomada A ou D** com uma segunda gravação: antes de disparar, a câmera já na FRENTE; `/dev scene blackout`; gravar do corte até ~29 s (ninguém no disjuntor) | **FRENTE**, dolly-out (TASK-C1) ou estático + zoom out digital | 1 cliente com Shift+P; não precisa de ator | sim |
| #44–#45 título | — | arte 2D no editor | — | letreiro: reaproveitar a arte do logo do jogo | sim |
| #47–#48 stinger | `/dev night 3`, ATM-1 | mesas cheias (`/dev customer tables sit`) e **cabeças virando juntas** (`/dev nightwatch on`, [FALTA] TASK-C4) | Free, fixa | 1 cliente | sim com TASK-C4 |

### 6.4 Ordem de gravação (sessões para uma pessoa)

Cada sessão agrupa o que divide a mesma noite, atmosfera e número de clientes, para não reabrir o Test à toa.

| Sessão | Clientes | Planos | Duração estimada | Passos |
|---|---|---|---|---|
| **S0 Preparação** | — | — | 20 min | build normal; OBS com duas cenas (janela A e janela B); conferir `/dev help`; abrir Test com 1 cliente, achar e fotografar o ponto **FRENTE** (ou `cam save frente` com TASK-C1) |
| **S1 Normalidade solo** | 1 | #4, #5, #6, #8, #9, #10–#12 | 45 min | `/dev night 2`, `/dev time 10:30`, `/dev atm ATM-1`, `autorevive on`, `infsanity on`. Primeiro #9 (FRENTE aceso, mesas cheias), depois estações e drive-thru, por fim ANM-001 |
| **S2 Cozinha com figurantes** | 3 (depois 2) | #7, #13 | 30 min | 3 clientes, B e C em estações (T3); gravar #7; fechar C; gravar #13 com B servindo (T1) |
| **S3 Escalada** | 1 | #14, #16–#21 | 45 min | trocar `night`/`atm` por plano como no §6.3; uma anomalia por vez, `/dev trigger stop` entre elas |
| **S4 Apagão solo** | 1 | #1, #2, #27–#30, #32–#42, #43A | 90 min | `/dev night 3`, `/dev time 1:30`, `/dev atm ATM-2`. Ordem: **tomada D** (porta e fresta, Free) → **tomada A** (disjuntor, POV, até o Failed) ×3 → **tomada C** (monitor, Walker) ×2 → **#43A** (FRENTE no escuro) ×2 → #41 encenação. `/dev scene stop` entre tomadas |
| **S5 Apagão com ator** | 2 | #22, #25, #26, #31, #46 | 45 min | mesma noite. #22 e #25–#26 com câmera em A e B como ator; #31 com B preso no monitor; #46 na FRENTE (comando `resolve` ou B no disjuntor) |
| **S6 Stinger** | 1 | #47, #48 | 20 min | depende de TASK-C4; se não estiver pronta, gravar #47 e deixar #48 para depois |
| **S7 Montagem** | — | #3, #15, #23, #24, #43, #44, #45, #49 | — | cartelas, preto, título no editor |

---

## 7. Som e música

| Camada | O que | Origem |
|---|---|---|
| Música fofa (3–12 s, 56,8–58,5 s) | tema curto e leve, com **uma nota que falta** no fim | música com permissão de uso do dono (2026-10-20); a nota faltando é edição |
| Drone (12 s → 29 s) | tom grave contínuo | idem |
| Riser (19–29 s) | pitched + noise, pico no corte de 29,0 | idem |
| Violino do apagão (34–47 s) | o motivo do jogo (notas em loop + uma nota longa subindo, corte seco) | o próprio áudio do jogo (permissão do dono) |
| SFX diegéticos | SFX-020, SFX-233 a SFX-243, `phone_glitch`, `church_bell`, `handle_rattle` etc. | capturados do jogo; os vindos da Creator Store **sem garantia** de uso fora do Roblox são conferidos ou trocados (R3) |
| Silêncio | 31,4–34 s (parcial), **47,0–48,5 s (total)**, 50,0–51,8 s (preto e início do #43A, só vento), 59,6–60 s | — |
| Respiração | #1, #27, #31, #40 | foley original, baixa, sem gemido |
| BRAAAM | **não usar** (clichê; research §2.2) | — |
| Mix | sem clipping; jumpscare com limitador (Mild, DEC-172); testar fone e alto-falante de celular | — |

---

## 8. O que precisa ser construído para capturar (propostas de TASK, sem código)

Dono sugerido entre parênteses. Numeração local (`TASK-C#`); o task-planner dá o `TASK-###` real se o dono aprovar.
Prioridades revistas para gravação solo.

| # | Proposta | Por quê | Prioridade |
|---|---|---|---|
| TASK-C1 | **Câmera de captura** dev-only: `/dev cam` com keyframes (`save`/`go` por nome), dolly e push-in por tween linear/sine, FOV, trava de altura; esconde a própria UI | o ponto **FRENTE** é usado 3× (#9, #43A, #46) e precisa ser idêntico; dolly-out do #43A e push-in do #9; Shift+P manual treme e não guarda posição (frontend-coder) | **P1** (a mais útil para o dono solo) |
| TASK-C2 | **Controle de tempo da cena** dev-only: pausar/retomar a linha do tempo de uma `HorrorScene` e pular para um passo (`/dev scene blackout at 27`) | S4 tem 4 tomadas da mesma cena; sem pular, cada tentativa de maçaneta custa 30 s (frontend-coder + backend-coder) | **P1** |
| TASK-C3 | Flag de captura para o **vulto do ANM-020** ficar parado quando olhado (só com dev ligado) | #41; sem isso, encenação manual pelo Explorer (frontend-coder). Se o dono quiser o comportamento **no jogo**, deixa de ser ferramenta de captura e vira mudança de design (TQ-2) | P2 — depende de TQ-2 |
| TASK-C4 | `/dev nightwatch on|off`: liga a skin Night e a cabeça seguindo a câmera nos clientes **sem** anomalia ativa | stinger #48 (frontend-coder) | P1 |
| TASK-C5 | **Arte final do vulto** (hoje Parts) — ficha AST pelo art-director | #29 e #41 em close; Parts não seguram o plano | P1 (art-director → modeler-3d) |
| TASK-C6 | Asset do `heavy_steps` (SFX-236, sem candidato seguro) | passos do Walker em #30 | P2 (áudio) |
| TASK-C7 | Esconder seletivo de UI para captura: manter palavras/legenda/prompt e tirar o resto (contadores, toasts) | #27, #28, #32 limpos (frontend-coder) | P2 |
| TASK-C8 | Conferir os SFX da Creator Store usados no trailer **sem garantia** de uso fora do Roblox; trocar os duvidosos por biblioteca licenciada | R3 (só SFX; a música está coberta pelo dono) | P3 |
| TASK-C9 | **Figurante de captura** dev-only: `/dev standin [clear]` deixa uma cópia parada do seu bichinho (com a classe/skin) na posição e direção atuais | co-op do #7 e #13 sem abrir 3 clientes; menos peso na máquina (frontend-coder ou backend-coder) | P2 (3 clientes já resolvem hoje) |

---

## 9. Cortes alternativos (todos 16:9 horizontal)

### 9.1 30 s — anúncio do Roblox (≤ 30 s, **autoplay mudo**)

Regras: o melhor momento **antes de 15 s** (click-to-play cobra 15 s de vista); tudo entendível **sem som** (cartelas e
legenda do jogo carregam a história); sem o rosto em tela cheia (risco de política de anúncio, R6) — o clímax é a
**revelação no halo + corte para preto + FRENTE no escuro**.

| Tempo | Planos (do 60 s) | O que conta sem som | Texto |
|---|---|---|---|
| 0,0–1,5 | #2 (sombra na fresta) | algo do outro lado da porta | WHERE'S THE BREAKER? (do jogo) |
| 1,5–5,5 | #4, #7, #9 (cortes de 1,3 s) | cozinha fofa, amigos, o trailer aceso | THE NIGHT SHIFT IS HIRING |
| 5,5–8,0 | #10–#11 | o rosto liso | REFUSE THE WRONG ONES |
| 8,0–10,5 | #14, #16, #18 (0,8 s cada) | escalada | DON'T STARE |
| 10,5–11,5 | #26 | tudo apaga | NEVER LET THE LIGHTS GO OUT |
| 11,5–14,5 | #27, #28 | escuro, legenda do jogo | POWER OUT / FIX THE BREAKER (do jogo) |
| 14,5–20,0 | #30, #32, #35, #36, #37, #38 | Walker nas câmeras; anel × maçaneta (cortes de ~0,9 s) | — |
| 20,0–21,0 | #40 | silêncio (no mudo: imagem parada) | — |
| 21,0–22,0 | #41 | o vulto no halo | — |
| 22,0–22,3 | preto | — | — |
| 22,3–25,0 | #43A | o trailer de longe, apagado (rima com o #9 do começo) | o título começa a acender em 23,5 |
| 25,0–27,0 | #44–#45 | título | SELL HOTDOGS! · Cook. Serve. Survive the night. · Play now on Roblox · Up to 4 friends |
| 27,0–30,0 | #46 + #48 comprimidos | a luz volta… cabeças viram | — |

Idioma: **EN** (anúncio global; o jogo é em inglês, DEC-022).

### 9.2 15 s — horizontal 16:9 (pre-roll, redes, Discord, página)

Abre **no** apagão; uma ideia, um susto, o título. Título e textos na área segura de título padrão (90 % do quadro).

| Tempo | Planos | Texto |
|---|---|---|
| 0,0–1,5 | #26 (apaga) + #27 (vermelho, legenda do jogo) | **EN** YOUR SHIFT. HIS NIGHT. · **PT** SEU TURNO. A NOITE É DELE. |
| 1,5–4,0 | #28 (corredor, palavras do jogo) | — |
| 4,0–5,5 | #30 (Walker nas câmeras) | — |
| 5,5–9,5 | #32–#39 (anel × porta, cortes de 0,5 s) | **EN** HOLD IT... · **PT** SEGURA... |
| 9,5–10,5 | #40 silêncio | — |
| 10,5–11,4 | #41 + #42 (rosto só onde a política da plataforma permite; senão #41 + preto) | — |
| 11,4–14,0 | #43A (FRENTE no escuro), título acendendo em 12,0 | SELL HOTDOGS! · **EN** Cook. Serve. Survive the night. · Play on Roblox · **PT** Cozinhe. Atenda. Sobreviva à noite. · Jogue no Roblox |
| 14,0–15,0 | #48 (cabeças viram) | — |

Idioma: **EN** como padrão; **PT** para canais e perfis brasileiros.

### 9.3 Qual idioma usar onde

| Peça | Cartelas |
|---|---|
| Página do jogo / YouTube (60 s) | EN (legendas PT no YouTube) |
| Anúncio Roblox (30 s) | EN |
| 15 s horizontal | EN; versão PT para canais BR |
| Slogan | **EN** "Cook. Serve. Survive the night." (aprovado pelo dono); PT "Cozinhe. Atenda. Sobreviva à noite." como alternativa |
| Textos **do jogo** (POWER OUT, WHERE'S THE BREAKER?, Reset Breaker) | sempre como estão (inglês), em qualquer versão: são imagem de gameplay |

---

## 10. Riscos e perguntas abertas

Numeração local (`TQ-#`, `R#`); números fechados não são reaproveitados. O secretário converte em `Q-###` se o dono quiser
registrar.

### 10.1 Riscos

| # | Risco | Mitigação |
|---|---|---|
| R1 | — | **fechado** (v2): lanterna não entra; dono, 2026-10-20 |
| R2 | Walker aparece **só nas câmeras**; mostrá-lo em 1ª pessoa seria promessa falsa | ele só aparece no #30 (visão das câmeras). A revelação em 1ª pessoa é o vulto (que existe) |
| R3 | SFX da Creator Store sem garantia de uso fora do Roblox (a música está coberta pela permissão do dono) | conferir só os duvidosos; trocar por biblioteca licenciada se não houver garantia (TASK-C8) |
| R4 | O vulto **some quando olhado**; o #41 o mantém parado — leve encenação | aceita como licença de trailer (Provisório); falta saber se vira comportamento do jogo (TQ-2) |
| R5 | `heavy_steps` (SFX-236) sem asset | usar `walker_step` ou biblioteca licenciada |
| R6 | Política de anúncios do Roblox para susto/imagem assustadora [NÃO CONFIRMADO] | o corte de 30 s não usa o rosto em tela cheia; checar as Advertising Standards antes de subir |
| R7 | `descricao-jogo.md` promete Mart, "by day" e "HIDE": o trailer **não** repete isso, e a página fica incoerente com o trailer | atualizar a descrição (fora deste documento; narrative-writer) |
| R8 | Fotossensibilidade: piscadas de luz (#22, #26, #46) | nada de strobe acima de 3 flashes/s; o preto do #26 é 12 frames contínuos |
| R9 | Mild (DEC-172): o rosto é cartoon, 0,6 s, sem grito — no trailer igual | não alongar o rosto, não adicionar sangue, grito ou distorção extra |
| R10 | — | **fechado** (v2): era do corte vertical, removido |
| R11 | Tempo real da cena (30 s) ≠ tempo do trailer (20 s) | montagem comprime; nenhuma regra nova é sugerida |
| R12 | 2–3 clientes + servidor numa máquina derrubam o fps da janela gravada | usar 3 clientes só no #7; minimizar janelas que não são câmera nem ator; se cair abaixo de 60 fps, gravar em 1080p ou usar TASK-C9 |
| R13 | No #43A o vermelho de emergência pode **não vazar** para fora do trailer (EMERG-P fica dentro) | não pintar luz que não existe: realçar no grading só o vermelho que aparecer; se nada vazar, o plano fica com o letreiro fraco e o halo vermelho do céu da ATM-2, e continua funcionando como silhueta |
| R14 | O anel do prompt **reseta ao soltar** E: não existe "anel parado quase cheio" no jogo | #40 é congelamento do quadro de ~90 % na montagem (a câmera já está imóvel no plano); #34/#36/#38 saem de seguradas parciais |
| R15 | Câmera livre (Shift+P) não guarda posição: o FRENTE pode variar entre #9, #43A e #46 | print de referência e marcas (letreiro, mesa); TASK-C1 resolve de vez |

### 10.2 Perguntas para o dono (pendentes)

| # | Pergunta | Recomendação (Provisória) |
|---|---|---|
| TQ-2 | O vulto que **fica parado quando olhado** (#41): só no trailer ou no jogo também? | só no trailer por agora; se for para o jogo, vira proposta ao game-designer |
| TQ-6 | Os textos "DON'T STARE / DON'T LOOK UP" aparecem como **cartela do trailer** ou só se vierem da UI do jogo? | cartela do trailer (estilo próprio); as palavras do jogo ficam como imagem |

### 10.3 Respondidas (2026-10-20)

| # | Resposta do dono | Onde aplicado |
|---|---|---|
| TQ-1 | sem lanterna | §2.1, R1 fechado |
| TQ-3 | o dono tem permissão de uso da música | §7, R3, TASK-C8 |
| TQ-4 | slogan "Cook. Serve. Survive the night." aprovado (EN; PT alternativa) | #44, §9 |
| TQ-5 | removida: o jogo é só horizontal | §9.2 virou 15 s 16:9 |
| TQ-7 | tela de queda / revive fora do trailer; no lugar, plano FRENTE alto e afastado | #43A, #9, #46 |
| TQ-8 | o dono grava sozinho | §6 inteiro |

---

## 11. Checklist do research §8 aplicado

| # | Item | Onde |
|---|---|---|
| 1 | gameplay nos 3 primeiros s, sem logo | #1–#3 |
| 2 | normalidade antes de quebrar | Ato 1 |
| 3 | uma regra em texto curto | cartelas #12, #15, #23–#24 |
| 4 | primeira anomalia pequena | #11 (rosto liso) |
| 5 | corte acelera, no beat | Ato 3 e #32–#39 |
| 6 | riser termina num corte | 29,0 s |
| 7 | silêncio total antes do susto | #40 |
| 8 | um jump scare grande | #42 |
| 9 | corte seco para preto | #42 → #43, #49 |
| 10 | luz motivada | emergência, halo, mostarda, monitor, faróis, letreiro |
| 11 | grading conta a história | Quente → Frio → Breu → Quente |
| 12 | falso alívio antes do stinger | #46–#47 |
| 13 | título curto + CTA + stinger | #43A–#49 |
| 14 | anúncio funciona mudo, melhor antes de 15 s | §9.1 |
| 15 | plano-ponte que respira antes da marca | #43A (FRENTE no escuro, rima com #9 e #46) |
