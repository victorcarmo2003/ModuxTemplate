Status: Rascunho

# Propostas do game-designer — rodada 3 (múltipla escolha)

Autor: game-designer, 2026-10-10. Cobre **Q-145** (classes por animal), **Q-154** (humor dos NPCs) e **Q-149** (a)(b) (cliente × jogável; tipo de cliente × animal/roupa).
Formato para decisão rápida: cada pergunta tem título curto, 2–3 opções de 1 linha e **uma recomendada (★)**. Detalhe e números logo abaixo de cada bloco.
**Nada aqui é decisão.** Só o usuário aprova; o secretário registra.

> **Escolhas do usuário (2026-10-10, secretário):** documento segue **Rascunho**; vale o que está nas DECs.
>
> | Pergunta | Escolhida | DEC | Com a recomendação? |
> |---|---|---|---|
> | Q-145-1 | B (6 classes) | DEC-186 | sim |
> | Q-145-2 | A (mapa mnemônico) | DEC-186 | sim |
> | Q-145-3 | A (passivas de DEC-069) | DEC-186 | sim |
> | Q-145-4 | A (Cachorro grátis, gemas 45/120/180) | DEC-186 | sim |
> | Q-145-5 | A (guaxinim só Quentin) | DEC-186 | sim |
> | Q-154 | **C (humor dinâmico completo)** | DEC-187 | **não** (rec. B); desenho em `Q-164` |
> | Q-149-a | **B (jogável pode ser cliente)** | DEC-188 | **não** (rec. A); lacuna em `Q-165` |
> | Q-149-b | A (espécies fixas + acessório) | DEC-188 | sim |
> | Q-149-c | **B (porco cliente normal)**, confirmado | DEC-192, DEC-214 | **não** (rec. A) |
>
> Sem efeito por essas escolhas: §2 tabela de humor de chegada e regras da B; §3 tabela "Grupo" (jogáveis e porco também podem ser cliente) e o critério "nenhum cliente com `playable = true`". A regra "Pack Mid nunca em NPC" (§2) já caiu por DEC-181.

Base: DEC-061, DEC-069, DEC-070 (classes e gemas), DEC-072 (paciência/gorjeta), DEC-145 a DEC-147, DEC-149, DEC-158 a DEC-169.
Nomes em inglês entre aspas são placeholders (narrative-writer, DEC-022). Números são valores iniciais de tabela (regra de DEC-044).

Esta rodada **substitui** a seção "Proposta Q-145" de `classes.md` (escrita quando só havia 8 espécies). Lá fica só um ponteiro.

---

## 0. Resumo das recomendações

| Pergunta | Recomendada | Emenda DEC? |
|---|---|---|
| Q-145-1 Quantas classes no MVP | **6** | sim, só a lista do MVP de DEC-069 (4 → 6) |
| Q-145-2 Quais animais são as 8 classes | **Mapa mnemônico** (Coruja = Night Owl, Leão = Shift Lead) | não (nomes já são placeholder) |
| Q-145-3 Habilidades | **Efeitos de DEC-069, passivos** | não |
| Q-145-4 Como desbloqueia | **Cachorro grátis, resto com gemas (45/120/180)** | não |
| Q-145-5 Guaxinim jogável? | **Não, exclusivo do Quentin** | não |
| Q-154 Humor dos NPCs | **Humor de chegada só de dia + reações** | não (muda só invariante 2 de `npcs.md`, Rascunho) |
| Q-149-a Cliente × jogável | **Espécie jogável nunca é cliente** | não |
| Q-149-b Tipo de cliente | **Tipo = 1–2 espécies fixas + acessório; roupa sorteada** | não |
| Q-149-c Porco é cliente? | **Só pedestre** | não |

---

## 1. Q-145 — Classes por animal

### Q-145-1 — Quantas classes jogáveis no MVP?

| | Opção | Descrição (1 linha) |
|---|---|---|
| A | 4 classes | Como DEC-069: Cachorro, Coelho, Gato, Coruja; as outras 4 na 1ª atualização. |
| **B ★** | **6 classes** | DEC-069 + Urso (Hauler) e Raposa (Hawker); Panda e Leão na 1ª atualização. |
| C | 8 classes | Todas as 8 de DEC-069 já no MVP, incluindo café (Panda) e efeito de party (Leão). |

Por que B: os modelos das 18 espécies já estão aprovados (DEC-163), então o custo de classe a mais é só efeito em tabela + cartão no lobby + teste.
Urso e Raposa usam efeitos simples e pessoais (limite de pacotes; gorjeta). Panda (café marcado por quem fez) e Leão (efeito de party, não acumula) são os mais caros de testar e ficam fora.
Bônus: as 5 pagas somam **375 gemas = uma run completa** (DEC-070, ~375), meta clara para o MVP.

| Opção | Efeitos novos a implementar | Gemas para fechar o MVP | Emenda |
|---|---|---|---|
| A | 3 tipos (`walkSpeed`, `grillTimeMult`, sanidade/`daySpeed`) | 210 (Night 9) | nenhuma |
| B | +2 tipos (`packageLimit`/`speedWhileCarrying`, `tipValue`/`tipWindowDelta`) | 375 (fim da run, com +100 do final) | lista do MVP de DEC-069 |
| C | +4 tipos (B + café por autor, `partyGradeBonus`) | 675 (~1,8 run) | lista do MVP de DEC-069 |

### Q-145-2 — Qual animal é qual classe?

| | Opção | Descrição |
|---|---|---|
| **A ★** | **Mapa mnemônico** | Coruja = Night Owl (noturna), Leão = Shift Lead (líder); Tartaruga vira cliente. |
| B | Mapa da proposta anterior | Tartaruga = Night Owl (casco protege), Coruja = Shift Lead; Leão vira cliente. |

Mapa A (recomendado). Números de DEC-069 sem mudança:

| ID | Animal | Classe (placeholder) | Bônus → contrapeso | Tier · gemas | MVP (opção B) | Por quê |
|---|---|---|---|---|---|---|
| CLS-001 | Cachorro | "Rookie" | nenhum (régua) | 0 · grátis | sim | mascote da HotDog Crew |
| CLS-002 | Coelho | "Runner" | velocidade 16 → 18 · sanidade inicial 90 | 1 · 45 | sim | rápido e assustadiço |
| CLS-003 | Gato | "Line Cook" | grelha 0,85× (salsichas dele) · velocidade 15 | 1 · 45 | sim | patas precisas, preguiçoso fora da cozinha |
| CLS-004 | Urso | "Hauler" | 3 pacotes · velocidade 14 com 3 | 1 · 45 | sim | forte, fica lento carregado |
| CLS-005 | Raposa | "Hawker" | gorjeta $2 · janela de gorjeta −4 s | 2 · 120 | sim | boa de lábia, apressa o cliente |
| CLS-006 | Coruja | "Night Owl" | sanidade inicial e máx. 120 · de dia velocidade 15 | 2 · 120 | sim | acordada à noite, sonolenta de dia |
| CLS-007 | Panda | "Barista" | café dele 3 s e +35 · −8 por anomalia vista | 2 · 120 | não | olheiras de quem vive de café |
| CLS-008 | Leão | "Shift Lead" | party: nota +5 p.p., não acumula · pedidos dele sem gorjeta | 3 · 180 | não | líder do turno |

Tabela comparável (de `classes.md`, DEC-069; Δ lucro solo dia 3 vs. Cachorro): Coelho +4% · Gato +4% · Urso +3–5% · Raposa +6% · Coruja −1% (+20 sanidade à noite) · Panda 0 · Leão −2% solo / +4–5% party de 4. Todos dentro de ±12%.

### Q-145-3 — Que habilidade cada animal tem?

| | Opção | Descrição |
|---|---|---|
| **A ★** | **Efeitos de DEC-069, passivos** | Bônus + contrapeso da tabela acima; cobre grelha, mercado, caixa/gorjeta, sanidade, café e party. |
| B | DEC-069 + 2 classes novas pós-MVP | Acrescenta "Assembler" (montagem) e "Lookout" (ladrão) para cobrir as estações que faltam. |
| C | Habilidade ativa com recarga | Botão na tela (ex.: sprint 5 s a cada 60 s); exige DEC nova contra DEC-061 e botão de ação no HUD. |

Detalhe da B (só se escolhida; sem ID até DEC; animais sugeridos saem do pool de clientes quando entrarem, regra de Q-149-a):

| Classe | Animal | Bônus | Contrapeso | Tier | Δ lucro solo dia 3 (estim.) |
|---|---|---|---|---|---|
| "Assembler" | Macaco | hold de "Add {item}" 1 s → 0,7 s nos pedidos dele | grelha 1,15× nas salsichas dele | 1 · 45 | +1 a +3% |
| "Lookout" | Rato | zona que afasta o Quentin 14 → 22 studs quando é ele no veículo | sanidade inicial 95 | 1 · 45 | 0 a +3% (depende do roubo do dia) |

Por que A: cumpre DEC-061 e DEC-069 sem emenda, sem botão novo no mobile e sem risco de habilidade usada contra anomalia (proibido em DEC-069). C é descartável: 1ª pessoa, HUD sem botão de ação durante a run.

### Q-145-4 — Como se desbloqueia e escolhe?

| | Opção | Descrição |
|---|---|---|
| **A ★** | **Cachorro grátis, resto com gemas** | Preços de DEC-070 (45/120/180); escolha na tela "Crew" do lobby, travada na run. |
| B | Cachorro + 1 de tier 1 grátis | No 1º login o jogador ganha um animal de 45 à escolha (emenda DEC-069/070). |
| C | Todos livres no MVP | Gemas ficam sem uso no MVP (só compram classe); emenda DEC-069/070. |

Tempo até cada desbloqueio (solo mediano, `economy.md` §6): 1º tier 1 = Night 2 (~1 h 35) · 3 tier 1 = Night 6 · os 5 pagos do MVP (375) = fim da run com o final (+100).
Regras de escolha (já em `classes.md` P6, L1): botão "Crew" no lobby; trava na contagem do "Start"; repetir animal na party permitido; conta nova = Cachorro.

### Q-145-5 — O guaxinim (Quick Quentin) é jogável?

| | Opção | Descrição |
|---|---|---|
| **A ★** | **Não; exclusivo do Quentin** | Guaxinim perto do carrinho = sempre o ladrão; nunca jogável nem cliente. |
| B | Jogável depois | Vira classe pós-MVP (ex.: pechincha no mercado); guaxinim deixa de ser sinal de ladrão. |

Por que A: a invariante do ladrão (`npcs.md` NPC-007: "sempre o mesmo personagem") fica mais forte se a espécie for só dele, e o jogador lê o perigo de longe.

---

## 2. Q-154 — Humor dos NPCs

### Q-154 — Como funciona o humor?

| | Opção | Descrição |
|---|---|---|
| A | Só reação | O rosto segue o estado do pedido (esperando, demorando, recebeu, errado); sem efeito em números. |
| **B ★** | **Humor de chegada (só de dia) + reação** | De dia o cliente chega com um humor sorteado que muda paciência/gorjeta; à noite todos chegam Normal. |
| C | Humor dinâmico completo | Medidor de humor por cliente que sobe e desce com fila, espera, erros e noite; muda pagamento. |

Por que B: dá função ao rosto (pilar OBSERVAR: ler o cliente e priorizar o Stressed) com custo baixo (1 tabela + 1 campo). A noite fica com o padrão limpo (todos Normal na chegada), que é o que as anomalias precisam (DEC-010). C é caro e mexe no balanceamento de DEC-072.

Números da B (tabela `Moods`, peso por tipo de cliente ajustável):

| Humor de chegada | Peso (dia) | Paciência | Gorjeta | Rosto na chegada |
|---|---|---|---|---|
| Normal | 50 | ×1,0 | $1 | Normal |
| Happy | 20 | ×1,15 | $2 | Happy |
| Skeptical | 15 | ×1,0 | $1, janela −4 s | Skeptical |
| Stressed | 10 | ×0,75 | $1 | Stressed |
| Exhausted | 5 | ×1,0; anda ×0,8 até o balcão | $1 | Exhausted |

Reações (valem dia e noite, opções A e B):

| Evento | Rosto (1,5 s, depois vai embora) |
|---|---|
| Paciência < 25% | Stressed (fica até o fim da espera) |
| Completo com gorjeta | Smile |
| Completo sem gorjeta | Happy |
| Incompleto | Sad |
| Errado ou desistiu | Sad |
| Recusado | Normal |

Regras:
- À noite: todo cliente chega **Normal**; só as reações mudam o rosto. NPC-006 (Night Shift Worker) sempre Normal na chegada.
- Desmaiado (X) **nunca** é usado por NPC. Pack Mid **nunca** em NPC (DEC-167, Provisório).
- Jogador na faixa baixa de sanidade vê o cliente em Night + `Normal_Night` (DEC-168): esse rosto **vence** o humor no client dele. **Provisório (2026-10-14):** substituído; a faixa baixa não veste mais NPC e o humor vale também nela.
- Ator de anomalia não sorteia humor (rosto vem da ficha da anomalia).
- Efeito na economia: média ±2% de lucro/min de dia (gorjeta +$0,2 por pedido com gorjeta; Stressed com paciência menor). Fica dentro do ruído do playtest.
- Emenda de texto em `npcs.md` (Rascunho, sem DEC): invariante 2 passa a "de dia o rosto mostra o humor de chegada; à noite chega Normal; muda só na reação".

Critérios de aceite (B):
- 1.000 spawns de dia: frequência de cada humor a ±3 p.p. do peso.
- 1.000 spawns de noite: 100% Normal na chegada.
- Paciência e janela de gorjeta do pedido refletem o multiplicador do humor (servidor).
- Gorjeta Happy = $2; nenhuma gorjeta fora da janela.
- Nenhum NPC normal mostra Desmaiado ou pack Mid.
- Com sanidade < 40, o client do jogador mostra `Normal_Night` em todo cliente, qualquer que seja o humor; os outros jogadores da party continuam vendo o humor. **Provisório (2026-10-14):** critério obsoleto; todos veem o humor, inclusive na faixa baixa.

---

## 3. Q-149 (a)(b) — Animais clientes × jogáveis

Divisão das 18 espécies com as recomendações acima:

| Grupo | Espécies |
|---|---|
| Jogáveis (classes) | Cachorro, Coelho, Gato, Urso, Raposa, Coruja (MVP) · Panda, Leão (1ª atualização) |
| Clientes (e pedestres) | Pinguim, Hamster, Rato, Sapo, Macaco, Tartaruga, Ovelha, Coala |
| Só pedestre | Porco |
| Só personagem com nome | Guaxinim (Quick Quentin) |

### Q-149-a — Espécie jogável pode aparecer como cliente?

| | Opção | Descrição |
|---|---|---|
| **A ★** | **Não; jogável nunca é cliente** | Cachorro no balcão é sempre colega; clientes usam as 8 espécies não jogáveis. |
| B | Sim; todas podem ser cliente | 17 espécies no pool; a roupa civil (sem uniforme) separa cliente de colega. |

Por que A: leitura imediata em 1ª pessoa (espécie = papel), menos texturas de cliente na memória (`Q-144` g), e o campo `customer` por espécie na tabela resolve classes futuras sem código.

### Q-149-b — O que define o tipo de cliente?

| | Opção | Descrição |
|---|---|---|
| **A ★** | **1–2 espécies fixas + acessório; roupa sorteada** | Ex.: Vovô = Tartaruga ou Ovelha com bengala; variante = espécie × roupa (A–H). |
| B | Roupa fixa por tipo; espécie qualquer | Cada tipo tem seus conjuntos A–H; as 8 roupas são parecidas (troca de cor), tipo fica pouco legível. |
| C | Espécie e roupa sorteadas; só o acessório marca o tipo | Máxima variedade; o padrão por tipo (DEC-010) depende só de um acessório pequeno. |

Mapa da A (sugestão; acessórios de silhueta já descritos nas fichas de `npcs.md`, ficha de arte com o art-director):

| ID | Tipo | Espécies | Acessório | Roupas | Variantes (≥ 4, invariante 3) |
|---|---|---|---|---|---|
| NPC-001 | "Office Worker" | Pinguim | crachá + pasta | 4 de A–H | 1 × 4 |
| NPC-002 | "Student" | Hamster, Rato | mochila | 2 cada | 2 × 2 |
| NPC-003 | "Jogger" | Sapo | fone | 4 | 1 × 4 |
| NPC-004 | "Construction Worker" | Macaco | capacete + colete | 4 | 1 × 4 |
| NPC-005 | "Grandparent" | Tartaruga, Ovelha | bengala | 2 cada | 2 × 2 |
| NPC-006 | "Night Shift Worker" | Coala | crachá de plantão | 4 | 1 × 4 |
| NPC-019 | "Pedestrian" | Porco + qualquer espécie de cliente | nenhum | qualquer | — |

Notas: as roupas A–H podem se repetir entre tipos (o tipo se lê pela espécie + acessório). Mr. Pickett (NPC-021) depende de `Q-146`. Invariante 10 (detalhe assimétrico) segue valendo nas 8 roupas (art-director confere).

### Q-149-c — O porco compra hot dog?

| | Opção | Descrição |
|---|---|---|
| **A ★** | **Só pedestre** | Porco anda na rua, nunca pede salsicha; evita a piada de mau gosto num jogo infantojuvenil (DEC-023). |
| B | Cliente normal | Entra no pool de clientes (ex.: 2ª espécie do Construction Worker). |

Critérios de aceite (Q-149 A/A/A):
- 1.000 spawns: nenhum cliente com espécie `playable = true`, nenhum guaxinim fora do Quentin, nenhum porco no balcão.
- Cada tipo gera só as espécies da sua linha e sempre com o seu acessório.
- Nunca 2 clientes vivos com a mesma variante (espécie + roupa) do mesmo tipo.

Dados (tabela `Species`, proposta): `key`, `playable`, `customer`, `pedestrianOnly`, `reservedFor` (ex.: `NPC-007`). `CustomerTypes` ganha `species` (lista), `accessory`, `outfits` (lista), `moodWeights` (Q-154 B).
