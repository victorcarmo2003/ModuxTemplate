Status: Rascunho

# Revisão do fluxo de gameplay: anomalias legíveis e ritmo da noite (2026-10-21)

Pedido do dono (2026-10-21): "tem muitas anomalias e muitos NPCs; fica difícil o player entender o que fazer quando a
anomalia aparece (ex.: a do pão). Não quero cortar conteúdo, quero simplificar." Levantamento feito por 4 agentes
(Explore, game-designer ×2, researcher). Perguntas ao dono: `Q-445` a `Q-451`.

## 1. Diagnóstico

1. **Respostas demais e contraditórias.** A DEC-254 prometia 3 respostas (recusar, esconder, religar); hoje são 18
   anomalias e ~10 respostas: fechar a janela, atender, atender com hot dog puro (ANM-011), apagar a luz (ANM-022,
   ANM-010), segurar o disjuntor (ANM-020), não olhar (ANM-006), não olhar para cima (ANM-019), sair do chão
   (ANM-017), trancar a porta (ANM-009), ficar dentro (ANM-008, ANM-021).
2. **O mesmo objeto diz coisas opostas.** Janela: fechar resolve (família A), fechar é erro (ANM-005, ANM-011),
   fechar não adianta (ANM-022). Luz: religar (ANM-020) × apagar (ANM-010, ANM-022). Olhar: preciso para identificar
   o cliente esquisito, punido em ANM-006, ANM-019 e no `Stare` de ANM-004/012/013.
3. **A Noite 2 desfaz a Noite 1.** N1 ensina "cliente esquisito = feche a janela"; N2 estreia o Shaker (ANM-011),
   cliente esquisito em que fechar a janela derruba.
4. **Textos que mandavam o contrário da regra** (corrigidos na fase 1, §3).
5. **Densidade.** O corte de 60% da duração das noites (2026-10-21) manteve Events/Scares: 1 batida a cada 16–20 s
   contra a meta de ~45–55 s da TASK-341. O fluxo de clientes (commit 05a905c0, intervalo 30→22 s) já ocupa o jogador
   ~100% no solo; anomalias pediam de 43% (N1) a 71% (N10 solo) do tempo por cima disso.
6. **Fila e agendador não conversam.** O Scheduler fatia a janela Shift em partes iguais; a paciência dos pedidos
   corre durante a anomalia (`PausePatience` só existe na conversa do tablet). Parar para olhar custa dinheiro: o
   jogo ensina a ignorar a anomalia. Fechar a janela também manda embora os clientes normais.
7. **A falha não ensina.** Jumpscare + −35 (DEC-277) sem dizer o que era nem o que fazer; o cartão "WHAT GOT YOU" só
   aparece com a sanidade a zero.
8. **Estreias caladas.** Raincoat, Floater, Starer, Head banger entram sem linha na ligação.

## 2. Referências do gênero (researcher)

Exit 8: 1 resposta para ~36 anomalias, regra numa placa. I'm on Observation Duty: 6–8 categorias de relatório.
Papers, Please / That's Not My Neighbor: 2 respostas, livro de regras que cresce por dia. FNaF: 3 respostas, um recurso.
Scary Shawarma Kiosk (Roblox, o mais próximo): ~3 respostas, regras coladas no quiosque, a noite só anda atendendo
cliente legítimo [1 guia de fã, não confirmado]. Padrão: **poucas respostas, muitas aparências**; regra escrita no
mundo; 1–2 novidades por noite, anunciadas; janelas de calma; erro com margem e explicado.

## 3. Fase 1 aplicada (2026-10-21, Provisória)

- Textos alinhados às regras em vigor: ANM-009 "tranque a porta" (Journal, ligações N2/N9 do restaurante, falas de
  Walt/rádio, whispers da cena); ANM-010 "apague a luz da loja" (Journal; o Mart saiu, DEC-307); ANM-017 "suba no
  balcão" (Journal); lista `shaker` antiga dos whispers.
- Cena do Shaker (`HorrorScenes/Scenes/anm_011_shaker.luau`): saíram o passo no teto e o "olhar para cima" (sinal da
  ANM-019).
- `Content.Nights`: Events 4,6,6,7,7,8,8,9,10,12 → 2,3,4,4,5,6,6,7,8,8; Scares 4,4,4,5,5,5,5,6,6,6 →
  3,3,3,4,4,4,4,5,5,5; MinGap 30..22 → 40..30 s. Toda anomalia continua estreando e no sorteio; caem as repetições.
- Falas novas sem voz pré-gerada até rodar `tools/voice` (tocam como texto).

## 3b. Fase 2 (pedido do dono 2026-10-21, Provisória)

- `Restaurant.Flow.NightInterval` 30..22 → **34..26 s** (cozinha solo de ~90–110% para ~75–85% no modelo).
- **Diretor de batidas** (`AnomalyService/Director.luau`, `Content.Nights.Beats`): um orçamento único para tudo que
  pede ação. Anomalias regulares da agenda (não a estreia fixa nem as roteirizadas), desarmes do disjuntor, tarefas
  (`ChoreService`) e suspense (`SuspenseService`) perguntam `BeatClear` antes de começar e marcam `BeatBegin`.
  `Gap` 25/22/18/15 s entre duas batidas (1–4 jogadores); `MaxActive` 1/1/2/2 batidas pedindo ação ao mesmo tempo
  (anomalias rodando + tarefas até o prazo + desarme por `Hold` 20 s); `Reserve` 15 s: tarefa, desarme e suspense
  esperam se uma anomalia da agenda vence em menos de 15 s. Sustos da família D e sustos pessoais da pressão não são
  batidas. Efeito: o número configurado de tarefas/desarmes vira **teto**; nas noites cheias parte delas não cabe e
  não acontece. `/dev beats` mostra o estado.
- **No máximo 2 estreias por noite** (Validate `MAX_DEBUTS`): ANM-004 cópias N5 → **N3**; ANM-021 névoa vermelha N5 →
  **N6**; ANM-016 starer N8 → **N9**; ANM-023 câmera N4 → **N10**. Estreias: N1 001 · N2 011, 009 · N3 020, 004 ·
  N4 012, 006 · N5 013, 005 · N6 014, 021 · N7 017, 015 · N8 008, 022 · N9 019, 016 · N10 010, 023. Ligações das
  noites 3, 5 e 6 (restaurante) ajustadas.
- Não testado em Play; os números são Provisórios.

## 3c. Sons pelas costas (pedido do dono 2026-10-21, Provisório)

O jogador prepara o lanche de costas para a janela. Numa calmaria (nenhuma anomalia rodando, nenhuma batida ativa,
≥ 12 s desde a última, nenhuma anomalia da agenda vencendo em < 15 s, luz acesa), o servidor escolhe um jogador a até
22 studs do ponto `Q1` (o balcão do lado de fora da janela) olhando a mais de 110° dele, e toca **só para ele** um de
três sustos roteirizados da família D: `behind_steps` (passos vêm da janela até logo atrás e param), `behind_creak`
(o piso range logo atrás, duas vezes) e `behind_tap` (batidinhas no vidro). Quando ele vira, não há nada. Sem verbo,
sem custo, não é batida do diretor. **1/1/2/2/2/2/2/2/2/2** por noite, a cada 50–100 s; nunca o mesmo duas vezes
seguidas. O client confere a própria câmera de novo antes de tocar. `Content.Nights.Behind`,
`AnomalyService/Behind.luau`, `HallucinationController/Behind.luau` + `Effects/Behind*`; `/dev behind [now]`.
Sons provisórios: `walker_step`, `floor_creak`, `door_knock` agudo (falta um "toque no vidro" próprio).

## 4. Propostas (dependem do dono)

### 4.1 Quatro respostas pela direção do perigo (`Q-445`)

| Resposta | Objeto | De onde vem | Sinal padrão |
|---|---|---|---|
| JANELA | alavanca da janela | pela frente: cliente, rua, drive-thru | ding do tablet desafinado; persiana chacoalha |
| LUZ | disjuntor | tudo apaga | estalo + "POWER OUT" + seta (já existe, molde) |
| OLHOS | câmera (olhar para baixo/longe) | de cima ou de longe | coração + vinheta, só nesta resposta |
| PORTA | tranca dos fundos | por trás | batidas/arranhões na porta; prompt Lock aceso |

Cliente esquisito = JANELA sempre; LUZ = sempre religar; exceção única: Raincoat Lady (atender), com assinatura
própria. Primeira vez guiada por **resposta** (4 lições), no máximo 1 resposta nova por noite, cartão de erro depois
do susto ("WRONG MOVE · The Floater → SHUT THE WINDOW"), elenco de até 6 anomalias por noite.

| ANM | Hoje | Proposto |
|---|---|---|
| 001, 012, 013, 014, 015, 016, 004 | janela | JANELA |
| 011 Shaker | servir puro | JANELA (o "só o pão" vira pedido de cliente normal) |
| 022 Head banger | apagar a luz | JANELA (bate 3–4 s e vai embora) |
| 010 Hush | apagar a luz | JANELA |
| 021 Red fog, 008 Long car | fechar e ficar dentro | JANELA |
| 020 Blackout | disjuntor | LUZ |
| 006 Stalker, 019 Roof walker | não olhar | OLHOS |
| 009 Knock | trancar | PORTA |
| 017 Crawler | sair do chão | PORTA |
| 005 Raincoat | atender | exceção |

### 4.2 Noite em onda e pausa (`Q-449`, `Q-450`)

Calmaria → N × [Onda → Pausa] → última hora. Onda: só clientes e no máximo 1 cliente esquisito. Pausa: sem chegadas
novas, paciência de todos congelada, 1 anomalia "focal" com prenúncio 3–8 s antes; folga preenchida com o que já
existe (pré-preparo, depósito, lâmpada). Pede um relógio de ritmo comum a `CustomerService` e `Scheduler` (absorve
a TASK-342). Números de referência no relatório do game-designer (Modelo A); critérios: nenhum focal fora da pausa,
0 chegadas na pausa, 1º cliente ≤ 6 s depois dela.

## 5. Pendências técnicas achadas

- `Pressure.luau` cita "DEC-351" para a pressão de sanidade; a DEC-351 é a dos comandos `/dev`.
- `Nights.luau` `Customers.BaseInterval` é dado morto (o restaurante usa `Restaurant.Flow.NightInterval`).
- `docs/design/economy.md` §4–5 ainda calcula com noites de 540–900 s; `docs/tech/prep-mode.md` descreve a esteira
  que saiu (DEC-308/310).
- Duas punições convivem (desmaio por `Kit.Scare` × −35 por `ctx.Fail`); a DEC-277 pede só −35.
