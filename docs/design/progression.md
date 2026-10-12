Status: Rascunho

# Progressão

Autor: game-designer, 2026-10-08. Consolida **[DEC-024, DEC-025, DEC-027, DEC-028, DEC-036, DEC-037, DEC-047, DEC-048, DEC-052, DEC-053, DEC-057, DEC-058, DEC-060, DEC-065, DEC-067, DEC-069, DEC-070, DEC-071]**.
Conciliado até a rodada 15: **[DEC-080 a DEC-084, DEC-086, DEC-091 a DEC-094, DEC-098, DEC-101, DEC-102, DEC-104, DEC-106, DEC-107, DEC-110 a DEC-113, DEC-115, DEC-121, DEC-127, DEC-129]**. Anomalias por `ANM-###` (DEC-096; Nk = ANM-00k).
Sistemas: FEAT-002 (run), FEAT-003 (relógio), FEAT-022 a FEAT-026 e FEAT-034 (noite), FEAT-015/035 (bancada), FEAT-028/029 (meta). Números = tabela `RunConfig`; os marcados **(proposta)** dependem de aprovação.
Chances do chefe: **1 por run inteira** **[DEC-110, DEC-112]**. Noite repetida: todos voltam, inclusive espectadores **[DEC-111, DEC-113]**.

## 0. Fluxo da run — NOVO (pedido do dono 2026-10-12, **Provisório**, Q-207)

> Este bloco **substitui** o que os §1–§3, §4.1, §6 e §8 dizem sobre "nights só com trailer", "trailer no Day 5" e "modo dia infinito".
> Eles ficam abaixo como histórico, marcados. Nada aqui é **Aprovado**: depende de DEC do usuário (Q-207).

**Sequência:** D1 → D2 → N1 → D3 → N2 → D4 → N3 → … → D11 → N10 → Final. A noite *k* acontece no fim do dia *k + 1*
(`RunParams.NightsFromDay = 2`). Continuam **10 noites** e o final (DEC-060, DEC-065).

| Turno | Onde | O que muda em relação ao dia anterior |
|---|---|---|
| Day 1 | carrinho | tutorial narrado pelo Walt; **só dia**, sem noite depois (`PriceParty` fixa no fim dele, DEC-121) |
| Day 2 | carrinho | dia completo; Walt avisa que "hoje você trabalha até tarde" (`call_day_2`); logo depois do resumo a party segue **direto** para a Night 1 |
| Night k (k ≥ 1) | **carrinho** até a compra do trailer | Call do Walt → Prep (7→8 PM, 90 s) → Night (8 PM → 6 AM) → NightEnd → Closing → Summary |
| Day k + 2 | carrinho (ou trailer, se comprado) | dia normal; a manhã seguinte à Night `Content.Trailer.OfferAfterNight` (= 2, manhã do Day 4) traz a oferta do trailer |
| Day 11 → Night 10 | idem | a Night 10 vencida vai para o Final (FEAT-027) |

**Duração das noites (Provisório, coerente com o dia de ~4,6 min do Q-200):** 540 s na Night 1 (9 min reais), +40 s por noite,
900 s na Night 10 (15 min). Era 20 → 30 min (DEC-127: o formato "crescente" continua, só os números mudam).
`MinGap` e `MaxSimultaneous` não mudaram (a janela de anomalias 9 PM–5 AM tem 432 s na N1 e 720 s na N10; 14 inícios na N10 = ~51 s por vaga).

| Turno | Duração (min) | Termina em (min) | Termina em (h) |
|---|---|---|---|
| Intro | 2,0 | 2,0 | 0:02 |
| Day 1 (tutorial) | 4,6 | 6,6 | 0:06 |
| Day 2 | 4,6 | 11,2 | 0:11 |
| Night 1 | 11,9 | 23,1 | 0:23 |
| Day 3 | 4,6 | 27,7 | 0:27 |
| Night 2 | 12,6 | 40,3 | 0:40 |
| Day 4 (oferta do trailer) | 4,6 | 44,9 | 0:44 |
| Night 3 | 13,2 | 58,1 | 0:58 |
| Day 5 | 4,6 | 62,7 | 1:02 |
| Night 4 | 13,9 | 76,6 | 1:16 |
| Day 6 | 4,6 | 81,2 | 1:21 |
| Night 5 | 14,6 | 95,8 | 1:35 |
| Day 7 | 4,6 | 100,4 | 1:40 |
| Night 6 | 15,2 | 115,6 | 1:55 |
| Day 8 | 4,6 | 120,2 | 2:00 |
| Night 7 | 15,9 | 136,1 | 2:16 |
| Day 9 | 4,6 | 140,7 | 2:20 |
| Night 8 | 16,6 | 157,3 | 2:37 |
| Day 10 | 4,6 | 161,9 | 2:41 |
| Night 9 | 17,2 | 179,1 | 2:59 |
| Day 11 | 4,6 | 183,7 | 3:03 |
| Night 10 + Final | 17,9 + 2,5 | 204,1 | **3:24** |

Dia = Prep 30 + Open 216 + Closing ≤ 20 + Summary 8 s. Noite = Call ~35 s + Prep 90 s + Night + NightEnd 3 s + Closing ≤ 30 s + Summary 10 s (~2,9 min fora a noite em si).
Run perfeita ≈ **3,4 h** (era ≈ 6,4 h; o "~6 h" do DEC-057 deixa de valer: Q-207). A noite perdida (1 por run, DEC-110) acrescenta 12–18 min.

**Trailer (opcional, depois):** deixa de ser compra obrigatória do Day 5. É oferecido na manhã depois da Night
`Content.Trailer.OfferAfterNight` (2) e comprado na placa FOR SALE (preço DEC-047 × party). Ele **ajuda** contra as anomalias
(janela que fecha, luzes, café, ponto seguro). Antes da compra todas as noites são no carrinho; **quem nunca compra** joga as 10 noites no carrinho,
com dificuldade maior (sem janela e sem interruptor; ver tabela abaixo). **O modo dia infinito acaba**: nunca ocorre "dia sem noite"
(`RoundService` chama `SetEndless(false)`; `RunParams.EndlessFromDay`/`EndlessRequiresNoTrailer` ficam sem uso e o contador "Day 100" do DEC-084 não anda:
decisão pendente em Q-207).

**Anomalias no carrinho** (cada linha de `Content.Anomalies` tem `Trailer`):

| Anomalia | Noite | `Trailer` | No carrinho | No trailer |
|---|---|---|---|---|
| ANM-001 blank folks | 1 | None | recusar | idem |
| ANM-002 wrong food | 2 | None | descartar | idem |
| ANM-003 stopped clock | 3 | **Needs** | **não acontece**: o agendador joga no lugar a anomalia "reserva" (a mais nova com `None` antes dela: ANM-002, mesmas 3/2/2/1 ocorrências) | luz apagada 5 s e acesa de novo |
| ANM-004 copies | 4 | None | recusar a cópia | idem |
| ANM-005 raincoat lady | 5 | None | atender sempre | idem |
| ANM-006 wavers | 6 | None | não olhar | idem |
| ANM-007 walker | 7 | None | não olhar (**única regra crítica**, só N7, mantida) | idem |
| ANM-008 long car | 8 | Helps | **sair da zona do carrinho** (ir ao Mart; só quem está na zona é testado) | fechar a janela |
| ANM-009 knock | 9 | Helps | **sair da zona do carrinho** (Mart) | fechar a janela |
| ANM-010 hush | 10 | None | ponto seguro (Mart) | idem |

Regra de conteúdo (`Validate`): as noites até `OfferAfterNight` (1 e 2) têm de ser `None` (são sempre no carrinho). 1 anomalia nova por noite, ocorrências 3/2/1,
`MaxSimultaneous` e `MinGap` por noite: iguais. Pendência de design: o ganho do trailer na N3 é a anomalia que só ele tem; no carrinho a N3 é só "mais da N2".

## 1. Camadas de progressão

| Camada | O que cresce | Dura | Fonte |
|---|---|---|---|
| Ingredientes | 2 → 6 complementos, automático por dia | Day 1–6 | DEC-071 |
| Equipamentos | Grill, Cooler, Counter, Lock, Lights — bancada do Mart, sempre à venda | Day 2 → ~Day 8 (solo) | DEC-046, DEC-101, DEC-106 |
| Veículo | carrinho → trailer (compra fixa, fora da rotação; trabalha na esquina) | Day 5 | DEC-047, DEC-052, DEC-086, DEC-107 |
| Seguro (opcional) | Rescue Whistle (ITM-021) no slot especial da bancada, 15%/turno | Night 1 → fim da run | DEC-100, DEC-108, DEC-129 |
| Noites | 1 anomalia nova por noite, cumulativo | Night 1–10 | DEC-025, DEC-060 |
| Mistério | ligações de Walt Bramble → pistas (`ending.md` §3) → Walt em pessoa no final | Night 1–10 | DEC-065, rodada 7 |
| Meta (entre runs) | gemas → classes | contas | DEC-069, DEC-070 |

## 2. Linha do tempo da run (solo mediano, cenário L) — HISTÓRICO, substituída pelo §0 (2026-10-12)

Turno de dia = 4,6 min (Provisório Q-200; era 7,5). Noite N = 1,5 min de Preparação/ligação + D_N + 1 min de fechamento/resumo. Final ≈ 3 min.

| Turno | Duração (min) | Termina em (min) | Termina em (h) |
|---|---|---|---|
| Intro | 1 | 1 | 0:01 |
| Day 1 | 7,5 | 8,5 | 0:09 |
| Day 2 | 7,5 | 16 | 0:16 |
| Day 3 | 7,5 | 23,5 | 0:24 |
| Day 4 | 7,5 | 31 | 0:31 |
| Day 5 (compra do trailer) | 7,5 | 38,5 | 0:39 |
| Night 1 | 22,5 | 61 | 1:01 |
| Day 6 | 7,5 | 68,5 | 1:09 |
| Night 2 | 23,5 | 92 | 1:32 |
| Day 7 | 7,5 | 99,5 | 1:40 |
| Night 3 | 24,5 | 124 | 2:04 |
| Day 8 | 7,5 | 131,5 | 2:12 |
| Night 4 | 25,5 | 157 | 2:37 |
| Day 9 | 7,5 | 164,5 | 2:45 |
| Night 5 | 26,5 | 191 | 3:11 |
| Day 10 | 7,5 | 198,5 | 3:19 |
| Night 6 | 28,5 | 227 | 3:47 |
| Day 11 | 7,5 | 234,5 | 3:55 |
| Night 7 | 29,5 | 264 | 4:24 |
| Day 12 | 7,5 | 271,5 | 4:32 |
| Night 8 | 30,5 | 302 | 5:02 |
| Day 13 | 7,5 | 309,5 | 5:10 |
| Night 9 | 31,5 | 341 | 5:41 |
| Day 14 | 7,5 | 348,5 | 5:49 |
| Night 10 + Final | 35,5 | 384 | **6:24** |

Run perfeita ≈ **6,4 h** (o "~6 h" de DEC-057 inclui esta margem). A única noite perdida que a run tolera (DEC-110, DEC-112) acrescenta 22–35 min; a 2ª encerra a run.
Queda de todos com retomada pelo snapshot (DEC-080) acrescenta o tempo já jogado do turno interrompido (até ~35 min no pior caso).
Membro atrasado (DEC-098): a run começa no máximo 60 s depois do 1º a chegar; a linha do tempo não muda.

## 3. Tempo até cada desbloqueio (solo mediano) — HISTÓRICO nas linhas de trailer/noites (§0 vale); o resto fica

| Desbloqueio | Quando | Min. de jogo | Como |
|---|---|---|---|
| Ketchup, Mustard | Day 1 | 0 | inicial |
| Cheese | Day 2 | 8,5 | automático + 1 pacote grátis |
| Ladrão possível | Day 2 | 8,5 | 50% |
| Grill 2 ($60) | fim do Day 2 | 16 | compra (acumulado $156) |
| Bacon | Day 3 | 16 | automático |
| Cash Drawer Lock ($80) | fim do Day 3 | 23,5 | compra |
| Potato Sticks | Day 4 | 23,5 | automático |
| Trailer disponível | Day 5 | 31 | — |
| Trailer comprado ($300) | fim do Day 5 (Day 6 se gastou > $140 antes) | 38,5 | compra |
| Night 1, café, Trailer Lights fixo na bancada (B5), Rescue Whistle entra no sorteio (15%/turno, DEC-129) | após a troca | 38,5 | — |
| Counter 2 ($70) | após Night 1 | 61 | compra |
| Cream Cheese | Day 6 | 61 | automático |
| Trailer Lights ($100) | fim do Day 6 | 68,5 | compra |
| Grill 3 ($150) | após Night 2 | 92 | compra |
| Cooler 2 ($50) | fim do Day 7 | 99,5 | compra |
| Primeira (e única) regra crítica: The Walker (ANM-007) | Night 7 | 234,5 | FEAT-024 |
| Counter 3 ($160) | após Night 3 | 124 | compra |
| Cooler 3 ($120) | fim do Day 8 | 131,5 | compra |
| Tudo comprado | ~Day 8 | ~132 | — |
| 1ª classe paga (45 gemas) | fim da Night 2 | 92 | gemas |
| Final com revelação | Night 10 | ~381 | DEC-065 |

Leitura: depois de ~2 h 12 min (solo) não há mais nada **obrigatório** a comprar com dinheiro; aceito no MVP **[DEC-082]**. O Rescue Whistle (opcional, raro) é o único uso de dinheiro depois disso, além de estoque e café.
Upgrades são comprados na bancada do Mart (DEC-101) e nunca saem da oferta (DEC-106): a tabela acima não depende de sorteio.

## 4. Noites: duração e agendador de anomalias

### 4.1 Duração — decidido: crescente 20 → 30 **[DEC-127]** (números substituídos em 2026-10-12: 9 → 15 min, §0, Provisório)

| Opção | N1 | N10 | Total das 10 | Prós | Contras |
|---|---|---|---|---|---|
| A. Fixa 20 min | 20 | 20 | 200 | run mais curta (~5,6 h) | noite 10 com 14 ocorrências fica apertada (1 a cada 1,1 min) |
| B. Fixa 25 min | 25 | 25 | 250 | simples | noite 1 com 3 ocorrências fica vazia (1 a cada 6,7 min) |
| **C. Crescente 20 → 30** (escolhida) | 20 | 30 | 250 | começa calma, termina longa e densa (§16 do GDD: "termina muito mais tensa") | uma coluna a mais na tabela |

**Decidido: C [DEC-127].** D_N = 20, 21, 22, 23, 24, 26, 27, 28, 29, 30 min (tabela `RunConfig`; números ajustáveis sem DEC, mudar para fixa exige DEC). A e B ficam como histórico.

### 4.2 Agendador por noite (proposta)

Regras em FEAT-022. Ocorrências: estreia 3 · 1–2 noites depois 2 · 3+ noites depois 1. Crítica: **só N7 (The Walker)**, das Nights 7 a 10 (FEAT-024; rodada 7).
Anomalias N1–N10 = ordem de `story/anomalies.md` (NPC-009 a NPC-018).

| Noite | Ativas | Ocorrências | Janela (min reais, 9 PM–5 AM) | Média entre ocorrências | Simultâneas máx. | Intervalo mín. | Regra crítica | Verbo novo |
|---|---|---|---|---|---|---|---|---|
| 1 | N1 | 3 | 16,0 | 5,3 min | 1 | 60 s | — | recusar (The blank folks) |
| 2 | N1–N2 | 5 | 16,8 | 3,4 min | 1 | 60 s | — | descartar (The wrong food) |
| 3 | N1–N3 | 7 | 17,6 | 2,5 min | 1 | 60 s | — | luz (The stopped clock) |
| 4 | N1–N4 | 8 | 18,4 | 2,3 min | 2 | 60 s | — | (recusar: The copies) |
| 5 | N1–N5 | 9 | 19,2 | 2,1 min | 2 | 40 s | — | atender (The Raincoat Lady) |
| 6 | N1–N6 | 10 | 20,8 | 2,1 min | 2 | 40 s | — | não olhar (The wavers) |
| 7 | N1–N7 | 11 | 21,6 | 2,0 min | 2 | 40 s | **N7** | (não olhar: The Walker) |
| 8 | N1–N8 | 12 | 22,4 | 1,9 min | 3 | 25 s | N7 | esconder (The long car) |
| 9 | N1–N9 | 13 | 23,2 | 1,8 min | 3 | 25 s | N7 | (esconder: The knock) |
| 10 | N1–N10 | 14 (inclui o clímax roteirizado: N10 + N7 às 5:45 AM) | 24,0 | 1,7 min | 3 | 25 s | N7 | ponto seguro (The Hush) |

Na Night 10, a única ocorrência da N7 é a do clímax (5:45 → 6:00 AM, FEAT-027), e a 3ª ocorrência da N10 é o mesmo clímax; as outras 12 caem na janela normal.

Escalonamento cumpre DEC-010: noites 1–3 = perceber uma coisa (sinais óbvios); 4–6 = lembrar regras (2 simultâneas; a N5 exige **atender** e quebra o vício de recusar); 7–10 = pressão (regra crítica + eventos que tiram o jogador do balcão: esconder, ponto seguro).

Risco de curva (para playtest): sem regra crítica nas Nights 1–6, essas noites só são perdidas quando todos ficam fora por sanidade. Se ficarem fáceis demais, o ajuste é de número (mais ocorrências, intervalo menor), não de regra.

### 4.3 Orçamento de sanidade por noite (solo, Rookie, estimativa)

"Ver" custa −5 **uma vez por anomalia por noite** (DEC-056; vale também para as de "não olhar"). N3 custa ~2 de escuro por ocorrência (5 s com a luz apagada); o Hush custa ~4 por ocorrência (corrida até o Mart com postes apagados).

| Noite | Anomalias vistas | Perda por ver (−5) | Escuro (idas ao Mart) | Escuro (N3 / Hush) | Sem erros, sem café | Cafés para ficar ≥ 50 |
|---|---|---|---|---|---|---|
| 1 | 1 | −5 | −5 | 0 | 90 | 0 |
| 4 | 4 | −20 | −8 | −4 | 68 | 0 |
| 7 | 7 | −35 | −10 | −2 | 53 | 0–1 |
| 10 | 10 | −50 | −12 | −14 | 24 | 1–2 |

Cada erro comum custa −35: na Night 10, 2 erros sem café derrubam o solo. Café (10 doses iniciais, +25) mantém a noite vencível com 1–2 erros. Critério de playtest: solo mediano vence a Night 10 **na 1ª tentativa** em ≥ 50% dos testes (a 2ª tentativa só existe se a chance única da run ainda não foi usada, DEC-110, DEC-112); e chega à Night 10 com a chance ainda disponível em ≥ 60% dos testes.

Efeito do reviver (FEAT-034): revivido volta com 50 (proposta); com limite de 2 revives por noite **[DEC-129]**, um jogador pode "absorver" no máximo 3 quedas por noite antes de virar espectador. O Rescue Whistle aparece ~2,85 vezes por run (15%/turno, DEC-129): a maioria das runs tem 1–3 seguros, nunca um por noite.

### 4.4 Risco "noites 1–6 fáceis" (Q-115): o que medir e como ajustar

Sem regra crítica antes da ANM-007 (DEC-074), com janela de 10 s (DEC-094) e reviver (DEC-092, DEC-100), as Nights 1–6 só se perdem se todos caem e ninguém revive. Não é decisão: é métrica de playtest.

| Métrica (playtest, solo e party de 2) | Alvo | Se ficar fácil demais (alavanca de número, sem DEC) | Se ficar difícil demais |
|---|---|---|---|
| Sanidade mínima média na noite (solo, sem erros) | Night 1 ~85 · Night 4 ~65 · Night 6 ~55 | ocorrências +1 por noite (tabela 4.2); escuro −1 → −1,5/s; janela de luz da ANM-003 60 → 45 s | ocorrências −1; café 10 → 14 doses iniciais |
| Erros comuns por noite (solo mediano) | 0,5–1,5 nas Nights 1–3; 1–2 nas 4–6 | intervalo mínimo entre inícios 60 → 45 s; simultâneas +1 a partir da Night 4 | idem ao contrário |
| Quedas por noite (party de 2) | ≥ 1 queda em 25–40% das Nights 4–6 | idem | idem |
| Uso do reviver por Robux nas Nights 1–6 | < 10% das noites (se for alto, o jogo está empurrando para pagar) | — | baixar perdas de sanidade antes de qualquer outra coisa |
| Noites 1–6 perdidas na 1ª tentativa | 5–15% (com 1 chance por run, acima disso a run acaba cedo demais; DEC-110) | idem | idem |

Mudar **regra** (ex.: regra crítica antes da Night 7) volta ao usuário (Q-115).

## 5. XP e níveis **[DEC-081]**

Decidido: **sem XP e sem níveis no MVP** (opção A). Recursos do MVP: Money, Stock, Gems. Desbloqueios seguem por dia (ingredientes, DEC-071), dinheiro (upgrades, DEC-046), dia + dinheiro (trailer, DEC-047) e gemas (classes, DEC-069). As opções B e C ficam só como histórico.

## 6. Achievement "Day 100" e queda de sessão **[DEC-080, DEC-084]**

### 6.1 Meta do achievement — decidido: opção C **[DEC-084]** (sem dia infinito desde 2026-10-12: o contador não anda, Q-207)

Contador **por jogador, persistido** junto das gemas; +1 por **dia de modo infinito concluído** (sem trailer, a partir do Day 6) que passou no anti-AFK (DEC-083), em qualquer run, somando sessões. Chegou a 100: +300 gemas e badge, 1× por conta (FEAT-031).

| Ritmo | Dias de modo infinito por hora | Tempo total até 100 |
|---|---|---|
| Só dia infinito | 8 | ~12,5 h, em quantas sessões quiser |
| Run completa (sem dia infinito) | 0 | não conta (os dias depois do trailer não são modo infinito) |

### 6.2 Queda de sessão — decidido: snapshot de 15 min **[DEC-080]**

Snapshot no início de cada turno, TTL 15 min, mesmo roster. Se todos saem e alguém volta em 15 min, a run recomeça no início do turno corrente. Pior perda numa queda: o turno em curso (≤ 7,5 min de dia; ≤ 35 min na Night 10). Gemas já creditadas nunca se perdem (DEC-104). Técnica com o architect (Q-058).

## 7. Meta-progressão (classes)

| Marco | Tempo (solo mediano, 1ª run) | Gemas | Classe possível |
|---|---|---|---|
| Fim da Night 2 | ~1 h 32 min | ~47 | Runner ou Line Cook (45) |
| Fim da Night 6 | ~3 h 47 min | ~150 | + 2ª tier 1, ou Night Owl (120) |
| Run completa | ~6 h 24 min | ~375 | as 3 pagas do MVP (210) com sobra |
| 2ª run completa | ~12 h 48 min | ~750 | todas as 7 pagas (675), quando existirem |

## 8. Modo dia infinito — REMOVIDO em 2026-10-12 (§0; o trailer deixou de ser condição das noites)

| Dia | O que muda |
|---|---|
| 5 | trailer disponível; notificação no fim do dia |
| 6 | Cream Cheese libera; fase de pedido "Dia 6+" (K médio 2,0); fluxo no teto (+40%) |
| 6–~12 | upgrades restantes na bancada do Mart (exceto Trailer Lights, que exige o trailer); slot especial vazio (sem trailer não há Rescue Whistle, DEC-129) |
| 12+ | nada novo; dinheiro sem uso, aceito (DEC-082); gemas 2–3 por dia com anti-AFK (DEC-083); +1 no contador "Day 100" da conta por dia (DEC-084) |

## 9. Critérios de aceite

- `RunConfig` troca nº de noites, durações e agendador sem código novo.
- Simulação solo mediano: a run perfeita fica entre 6 h e 6 h 45 min.
- Night N tem exatamente as ocorrências e a regra crítica da tabela 4.2 (crítica só nas Nights 7–10, sempre ANM-007).
- Simulação solo: trailer comprado até o fim do Day 6 em ≥ 90% das execuções.
- Simulação solo com compras na bancada do Mart: tudo comprado até o fim do Day 8 em ≥ 80% das execuções.
- Métricas de §4.4 medidas em playtest antes de fechar os números das Nights 1–6.

## 10. Propostas pendentes (progressão)

| Q | Opções | Recomendação | Precisa do usuário? |
|---|---|---|---|
| **Q-115** Noites 1–6 fáceis | aceitar · ajustar números · crítica antes da ANM-007 | ajustar números pela tabela §4.4; regra só se o playtest falhar. Com 1 chance por run (DEC-110), o risco oposto (noite perdida cedo encerrar a run) também é medido em §4.4 | só se mudar regra |
| **Q-112 b, c, d** Membro atrasado | ver FEAT-001 | entra a qualquer momento; não vê a intro (spawna na esquina quando ela acaba) | não |

Decididas: **Q-044** → **DEC-127** (crescente 20 → 30); **Q-121** → **DEC-111, DEC-113** (na noite repetida todos voltam, inclusive espectadores de noites anteriores); **Q-125** → **DEC-112** (1 chance por run inteira); **Q-112 a** → **DEC-121** (party para preços = roster até o fim do Day 1).
