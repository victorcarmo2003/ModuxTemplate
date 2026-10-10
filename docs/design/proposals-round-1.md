Status: Aprovado

> **Aprovado pelo usuário em 2026-10-08** ("aprovar tudo", rodada 4): DEC-044 a DEC-056. Vale a **opção recomendada** de cada seção.
> Variantes de cenário L/C valem conforme `Q-047`. Números = valores iniciais ajustáveis em playtest (§0.1 data-driven, §0.2 "números iniciais").
> A frase "Nada aqui é decisão" abaixo era o estado antes da aprovação.
>
> **Superado em (anotação de conciliação, 2026-10-08; o conteúdo aprovado abaixo não foi alterado; vale a DEC):**
> - Q-035 (§ chances do chefe, tabela de rodapé "3 chances"): **1 chance por run inteira** — DEC-110, DEC-112.
> - Representação da noite perdida ("acorda no banco do trailer ao amanhecer"): todos acordam **em pé na calçada ao lado do trailer** — DEC-122.
> - Jogador fora durante a noite ("senta no banco do fundo e assiste; volta no próximo turno com sanidade cheia"): desmaio → ambulância → reviver ou **espectador** até o fim da run (DEC-091, DEC-093); o espectador só volta se a party perder a noite e ela for repetida, e aí **todos** voltam (DEC-111, DEC-113). Fichas atuais: `features.md` FEAT-025, FEAT-026, FEAT-034.

# Propostas do game-designer — rodada 1

Autor: game-designer, 2026-10-08. Autorização do usuário: o game-designer propõe opções com recomendação
para perguntas que são número ou proposta de design. **Nada aqui é decisão.** Só o usuário aprova; o secretário registra.

Cobre: Q-032, Q-033, Q-037, Q-036, Q-018, Q-015, Q-035, Q-013, Q-014.
Respeita DEC-001 a DEC-043. Inspiração, não cópia: nenhum nome, número ou estrutura fechada do Animal Hospital
(sem persiana de recepção, sem CCTV como mecânica central, sem "Sanidade" como nome final — ver Q-054).
Nomes em inglês entre aspas são **placeholders** para o narrative-writer.

---

## 0. Premissas comuns

### 0.1 Dois cenários de run (Q-047 ainda aberta)

Cada proposta abaixo diz se funciona nos dois ou se depende de um deles.

| Parâmetro | Cenário L — "Longo" (decisões atuais) | Cenário C — "Campanha curta" (recomendação do orquestrador) |
|---|---|---|
| Dias antes do trailer | dias 1–4 + compra no dia 5 (DEC-037) | ~3 dias (**exige emenda de DEC-037**) |
| Noites | 10 (DEC-027) | 5 (**exige emenda de DEC-027**) |
| Duração da noite | 20–30 min (DEC-024) | 8–10 min (**exige emenda de DEC-024**) |
| Total de dias jogados | 14 (dias 1–5, depois 9 dias alternados) | 3 + 4 alternados = 7 |
| Duração do dia (proposta Q-033) | ~7,5 min | ~7,5 min |
| Run total estimada | 14 × 7,5 + 10 × 25 ≈ **355 min (~6 h)** | 7 × 7,5 + 5 × 9 ≈ **100 min** (cortar 1 dia → ~90 min) |

Os números são definidos como **parâmetros de tabela** (data-driven). Trocar de cenário muda a tabela, não o sistema.

### 0.2 Economia de referência (necessária para Q-032, Q-036, Q-037)

Números iniciais para balancear. As receitas dependem de Q-038; o modelo vale para "pedido = receita fixa".

| Receita | Ingredientes | Custo | Preço | Margem | Desbloqueio (proposta) |
|---|---|---|---|---|---|
| Classic | pão + salsicha + ketchup **ou** mostarda | $1,45 | $5 | $3,55 | dia 1 |
| Cheese | Classic + queijo | $2,45 | $7 | $4,55 | dia 2 |
| Bacon | pão + salsicha + bacon + mostarda | $2,95 | $8 | $5,05 | dia 3 |

Gorjeta: +$1 se o pedido sai **completo** em até 20 s depois de anotado. Paciência do cliente no balcão: 45 s.

Fluxo de clientes (solo): 1 cliente a cada 22 s no dia 1, +8% por dia até o dia 5 (teto +40%).
Multiplicador de fluxo por tamanho da party: **1p ×1,0 · 2p ×1,6 · 3p ×2,1 · 4p ×2,5**.
Teto de NPCs simultâneos por servidor: **12** (dia: até 8 clientes + 1 ladrão; noite: até 6 clientes + 3 atores de anomalia).

Lucro líquido esperado de um jogador solo mediano (dia com 360 s de loja aberta):

| Dia | Clientes atendidos | Margem média + gorjeta | Lucro líquido do dia | Acumulado |
|---|---|---|---|---|
| 1 | 13 | $4,10 | $53 | $53 |
| 2 | 15 | $4,50 | $68 | $121 |
| 3 | 17 | $4,80 | $82 | $203 |
| 4 | 18 | $4,90 | $88 | $291 |
| 5 | 19 | $5,00 | $95 | $386 |

Dinheiro inicial: $30 (adiantamento do chefe). Upgrades típicos comprados até o dia 5: $110–180 (ver 0.3).

### 0.3 Upgrades de referência (só para as contas; fichas vão para `upgrades.md`)

| Upgrade | Nível 1 (inicial) | Nível 2 | Nível 3 | Efeito no lucro/min (solo, estimado) |
|---|---|---|---|---|
| Grill | 2 vagas, 12 s | 3 vagas, 10 s — $60 | 4 vagas, 8 s — $150 | +12% / +22% |
| Cooler (capacidade, Q-037) | 12 por ingrediente | 20 — $50 | 30 — $120 | +5% / +8% (menos idas ao mercado) |
| Counter | fila de 3 | fila de 4, paciência +10 s — $70 | fila de 5, +20 s — $160 | +8% / +14% |
| Cash Drawer Lock (Q-036) | — | $80 | — | evita perda média de ~$10/dia |
| Trailer Lights (Q-014) | — | $100 (só no trailer) | — | dia: +10% fluxo; noite: área iluminada |

Lucro/min base solo no dia 3: $82 / 6 min ≈ **$13,7/min**.

---

## Q-032 — Preço do trailer

Cita: DEC-019 (jogador compra), DEC-028 (modo dia infinito), DEC-033 (dinheiro da party), DEC-034 (solo), DEC-037 (5º dia).

| Opção | Preço solo | Quando o solo mediano compra | Prós | Contras |
|---|---|---|---|---|
| A. Fixo baixo | $200 | dia 5, sempre | ninguém trava antes da noite | sem tensão "upgrade ou trailer" (§12) |
| **B. Médio, escalado pela party** | **$300** (× party) | fim do dia 5 se gastou ≤$110 em upgrades; dia 6 se gastou mais | cria a escolha econômica; party não compra trivialmente | precisa da tabela de multiplicador |
| C. Alto | $600 | dia 8–9 | trailer vira meta forte | atrasa a noite; ruim para run sem save (DEC-035) |

**Recomendação: B.**

- Preço = **$300 × multiplicador da party**: 1p ×1,0 ($300) · 2p ×1,5 ($450) · 3p ×1,9 ($570) · 4p ×2,2 ($660).
  O multiplicador de preço é menor que o de fluxo (0.2), então a party sobra dinheiro para upgrades e o co-op compensa.
- Tamanho da party é lido **no início da run** (não muda se alguém sair; ver Q-048).
- Regra de escala para qualquer cenário: preço ≈ **0,8 × lucro líquido acumulado esperado dos dias anteriores ao dia de liberação** (solo).
  No cenário C, com liberação no dia 3, o preço fica ≈ $160 (depende de emendar DEC-037).
- O trailer fica **visível no estacionamento desde o dia 1**, com placa "Available on Day 5". A compra é um prompt no próprio trailer.
  Comprado durante o dia, a troca acontece no fim do turno (fade + ligação do chefe) e o próximo turno é a noite 1 (DEC-024, DEC-036).

Critérios de aceite:
- Antes do dia 5 o prompt de compra aparece desabilitado com o dia de liberação.
- No dia 5, com saldo ≥ preço, a compra debita o valor exato do caixa da party e agenda a troca para o fim do turno.
- Em simulação de 1 jogador seguindo a tabela 0.2, gastando $110 em upgrades, a compra é possível até o fim do dia 5.

---

## Q-033 — Duração do dia, relógio do HUD, fim do dia

Cita: DEC-015 (HUD com horário), DEC-024, DEC-036 (alternância), DEC-028 (modo dia infinito).

| Opção | Como termina | Duração | Prós | Contras |
|---|---|---|---|---|
| **A. Relógio fixo** | loja fecha às 6:00 PM do jogo | ~7,5 min | previsível; mesmo ritmo para solo e party; relógio vira ferramenta da noite ("relógio alterado", §7.1) | jogador lento não "compensa" com mais tempo |
| B. Cota de clientes | após N clientes | variável | ritmo do jogador | party rápida pula o dia; relógio perde sentido |
| C. Jogador encerra | prompt "Close" | livre | controle | party discorda; fecha cedo para fugir do ladrão |

**Recomendação: A.**

Estrutura do turno de dia:

| Fase | Relógio do jogo | Tempo real | O que acontece |
|---|---|---|---|
| Preparação | 7:00 → 8:00 AM | até 60 s | loja fechada, sem clientes e sem ladrão; mercado aberto; upgrades. Qualquer jogador abre antes pelo prompt da placa "OPEN" |
| Loja aberta | 8:00 AM → 6:00 PM | 360 s (1 h do jogo = 36 s) | clientes, ladrão |
| Fechamento | 6:00 PM | até 30 s | placa vira "CLOSED"; não entra cliente novo; quem está na fila ainda é atendido |
| Resumo | — | 15 s | tela de faturamento (DEC-015) |

- HUD: horário em formato 12 h em inglês ("8:00 AM"), atualiza a cada 10 min do jogo (6 s reais).
- Noite usa o mesmo sistema: **8:00 PM → 6:00 AM**, duração definida pela tabela da noite (Q-044/Q-047).
- Modo dia infinito (DEC-028): dias repetem o mesmo formato até a party sair; o contador "Day N" continua.
- Funciona nos dois cenários (a duração do dia não muda; muda a quantidade de dias).

Critérios de aceite:
- Nenhum cliente nasce antes de 8:00 AM nem depois de 6:00 PM.
- Às 6:00 PM a placa muda para "CLOSED" e o turno termina em no máximo 30 s.
- O HUD mostra o mesmo horário para todos os jogadores da party (estado do servidor).

---

## Q-037 — Capacidade do estoque, distância do mercado, como comprar

Cita: DEC-016, DEC-017, DEC-031 (mercado), DEC-040 (hotbar nativa), DEC-018 (ladrão), DEC-015 (sem UI de interação).

### Como comprar

| Opção | Fluxo | Prós | Contras |
|---|---|---|---|
| **A. Pacote físico** | prompt na prateleira compra um pacote → vira Tool na mão → prompt "Restock" na estação do carrinho | atende DEC-015 e DEC-040; o co-op carrega mais; viagem tem peso | mais idas que um menu |
| B. Menu no caixa do mercado | UI de carrinho de compras, entrega direto no estoque | rápido | fere DEC-015 (UI com interação) |
| C. Pedido por telefone com entrega | sem viagem | conveniente | mata a tensão do ladrão (DEC-018) e do GERENCIAR |

**Recomendação: A.**

| Item no mercado | Pacote | Preço | Custo por unidade |
|---|---|---|---|
| Sausages | 8 un. | $6 | $0,75 |
| Buns | 8 un. | $4 | $0,50 |
| Ketchup | 20 usos | $4 | $0,20 |
| Mustard | 20 usos | $4 | $0,20 |
| Cheese | 6 un. | $6 | $1,00 |
| Bacon | 6 un. | $9 | $1,50 |
| Coffee (Q-014) | 10 doses | $5 | $0,50 |

- Cada jogador carrega no máximo **2 pacotes** ao mesmo tempo (limite de Tools de pacote; ajuda a fechar Q-056).
- "Restock" coloca no estoque até a capacidade. A sobra fica no pacote (o Tool guarda a contagem).
- O dinheiro sai do caixa da party na hora da compra, pelo servidor.

### Capacidade

| Opção | Salsicha/pão no nível 1 | Idas ao mercado por dia (solo, dia 3) | Avaliação |
|---|---|---|---|
| A. Generosa | 30 | 0 | GERENCIAR fica fraco |
| **B. Apertada** | **12** | **1** | tensão real, ladrão relevante |
| C. Muito apertada | 8 | 2–3 | pune demais o solo |

**Recomendação: B.** Capacidade por ingrediente: salsicha 12, pão 12, queijo 8, bacon 8, ketchup 30 usos, mostarda 30 usos.
Cooler nível 2 = 20 (queijo/bacon 14); nível 3 = 30 (queijo/bacon 20). O estoque passa de um dia para o outro dentro da run.
O chefe entrega o estoque cheio no início da run.

### Distância

| Opção | Distância carrinho ↔ mercado | Ida e volta + compra (WalkSpeed 16) | Avaliação |
|---|---|---|---|
| A. Perto | 50 studs | ~15 s | ladrão quase nunca pega |
| **B. Média** | **100–120 studs** | **~25 s** (15 s andando + 10 s comprando) | sair custa ~7% do dia; janela do ladrão é justa |
| C. Longe | 200 studs | ~40 s | cansativo no mobile em primeira pessoa |

**Recomendação: B.** A porta do mercado precisa ter **linha de visão** para o carrinho (o jogador vê o ladrão, DEC-018). Detalhes com o level-designer.
Mercado aberto também à noite (loja de conveniência): ir ao mercado à noite passa pela rua escura (DEC-041).

Critérios de aceite:
- Comprar sem saldo não é possível; o prompt mostra o preço.
- Restock nunca passa da capacidade; a sobra fica no pacote.
- Um solo no dia 3, sem upgrade de Cooler, precisa de pelo menos 1 ida ao mercado para atender todos os clientes.

---

## Q-036 — Ladrão

Cita: DEC-018, DEC-023 (sem violência), DEC-032/DEC-033 (carrinho e caixa compartilhados), DEC-034 (solo), DEC-010 (dia previsível).

Conceito de apoio: a **gaveta do caixa** no carrinho. As vendas do turno vão para a gaveta (valor visível no mundo, em cima da gaveta).
No fim do turno a gaveta é depositada no dinheiro da party (HUD). Compras no mercado usam o dinheiro da party.
O ladrão só mexe na gaveta, nunca no dinheiro da party.

| Opção | Quando | Quanto rouba | Prós | Contras |
|---|---|---|---|---|
| A. Rouba tudo, sem defesa | dia | 100% da gaveta | simples | punitivo e frustrante |
| **B. Rouba parte, com janela para impedir** | **dia, a partir do dia 2** | **50% da gaveta** | legível, não violento, dá jogada de reação; party tem papel natural ("alguém fica") | precisa de uma barra de progresso a mais |
| C. Dia e noite | ambos | 50% | mais presença | mistura ameaça "normal" com anomalia e quebra a regra "dia previsível / noite estranha" |

**Recomendação: B.**

| Parâmetro | Valor |
|---|---|
| Turnos | só dia (à noite, uma anomalia pode imitar o ladrão pós-MVP) |
| Chance por dia | dia 1: 0% · dia 2: 50% · dia 3+: 70% |
| Máximo | 1 ladrão por dia |
| Aparece | entre 9:00 AM e 3:00 PM, num ponto visível do carrinho (poste, banco) |
| Fica de espreita | até 120 s reais; depois vai embora |
| Gatilho | **nenhum jogador** na zona do carrinho (raio 14 studs) por 3 s seguidos |
| Até a gaveta | ~4 s andando |
| Abrindo a gaveta | 8 s, com barra de progresso visível sobre a gaveta (reusa DEC-029) |
| Impedir | qualquer jogador entra na zona durante a abertura → ele foge sem nada; a party ganha +$5 ("Nice catch!") |
| Rouba | 50% da gaveta, arredondado para baixo; nada se a gaveta tiver < $5 |
| Upgrade Cash Drawer Lock ($80) | abertura 16 s e rouba 30% |
| Representação | foge correndo com um saco de moedas; sem contato físico, sem briga |

Janela de reação: 3 s + 4 s + 8 s = **15 s** (23 s com a trava). Com a ida ao mercado de ~25 s (Q-037), sair com o ladrão de espreita
tem custo real, e a trava torna a volta rápida viável. Perda típica no meio do dia: gaveta de ~$40 → −$20.

Party: basta **um** jogador na zona. Solo: a defesa é comprar no período de preparação (sem ladrão) e escolher a hora de sair.

Critérios de aceite:
- O ladrão nunca aparece no dia 1, na preparação, no fechamento nem à noite.
- Com qualquer jogador na zona, o ladrão não sai da espreita.
- Entrar na zona durante a abertura cancela o roubo em até 0,5 s; a gaveta não muda.
- O valor roubado é exatamente floor(gaveta × 0,5), ou × 0,3 com a trava.

---

## Q-018 — Reputação e reclamação

Cita: DEC-017 (entrega incompleta → reclama), DEC-015 (HUD só com 4 itens), §7.3 e §12 do GDD V1.

| Opção | O que é | Prós | Contras |
|---|---|---|---|
| **A. Sem recurso de reputação; reclamação pesa no pagamento e na nota do turno** | incompleto paga 50% e sem gorjeta; a tela de fim de turno dá uma nota que vira bônus do chefe | mantém Money/XP/Stock (§12); não cria item novo no HUD | a reclamação não afeta o próximo dia |
| B. Reputação por turno | estrelas 1–5 no mundo que mexem no fluxo de clientes do próprio turno | feedback imediato | espiral negativa dentro do turno; mais um medidor |
| C. Reputação persistente na run | 0–100 que muda o fluxo de todos os dias | profundidade | bola de neve; fere DEC-015; difícil de balancear com party |

**Recomendação: A.**

| Situação | Pagamento | Gorjeta | Reação |
|---|---|---|---|
| Completo, até 20 s | 100% | +$1 | balão feliz |
| Completo, depois de 20 s | 100% | — | neutro |
| Incompleto (faltou ingrediente) | 50% | — | balão de reclamação + fala curta |
| Errado (receita diferente) | 0% | — | devolve e vai embora |
| Desistiu (paciência acabou) | 0% | — | vai embora bufando |

Nota do turno (tela de fim de turno), por % de clientes satisfeitos (completos ÷ clientes que chegaram ao balcão):
**A ≥ 90%: bônus do chefe +20% da gaveta · B ≥ 75%: +10% · C ≥ 50%: +0% · D < 50%: +0% e o chefe comenta.**
A nota também pode ser usada pelo sistema de gemas (Q-046). À noite vale a mesma regra; "recusar" um cliente-anomalia correto não conta como insatisfeito.

Critérios de aceite:
- Pedido incompleto paga exatamente 50% do preço e nunca gorjeta.
- A nota do turno é calculada só no servidor e é igual para toda a party.
- Nenhum medidor de reputação aparece no HUD.

---

## Q-015 — Tiers de carrinho/veículo no MVP

Cita: DEC-011, DEC-007, DEC-019, DEC-020, DEC-006.

| Opção | Tiers | Prós | Contras | Escopo |
|---|---|---|---|---|
| **A. 2 tiers** | carrinho do chefe → Food Trailer; o crescimento entre eles vem dos equipamentos | menos assets e layouts; cada upgrade aparece no carrinho (toldo, grelha maior) | menos "troca de veículo" | 2 modelos, 2 layouts |
| B. 4 tiers (§5) | Velho → Cart → Improved → Trailer | fiel ao GDD | 4 modelos e 4 layouts para 1–4 jogadores em 1ª pessoa; não cabe em 4 dias (DEC-037) | ~2× arte e level design |
| C. 3 tiers | carrinho → carrinho reformado (dia 3) → trailer | um marco no meio | o tier do meio repete o que os upgrades já fazem | 3 modelos |

**Recomendação: A.** "Ele vai melhorando o trailer dele" = **equipamentos**, não tier. Cada upgrade comprado adiciona uma peça visível
(DEC-006: efeito real e visível). Funciona nos dois cenários; no cenário C é a única opção que cabe. Os nomes ficam com o narrative-writer
(placeholders: "Boss's Cart", "Food Trailer").

Critérios de aceite:
- O MVP tem exatamente 2 modelos de veículo, cada um com layout de estações para 4 jogadores.
- Todo upgrade de equipamento muda o modelo do veículo de forma visível.

---

## Q-035 — Perder a noite

Cita: DEC-026 (errar = perder), DEC-035 (sem save), DEC-041/DEC-043 (sanidade zero = fora), DEC-023 (sem violência), DEC-034.

Definições propostas (dependem de Q-034):
- Jogador **fora**: sanidade chegou a 0 (DEC-043).
- **Noite perdida**: todos os jogadores da party estão fora ao mesmo tempo, ou alguém quebra uma **regra crítica**
  (no máximo 1 por noite, marcada pelo chefe com "whatever you do, never...").
- Quebrar uma regra comum tira 35 de sanidade (ver "Apoio: números de sanidade", em Q-014). Assim DEC-026 ("errar faz perder") e DEC-041 convivem: 3 erros tiram o jogador.

| Opção | O que acontece | Prós | Contras | Cenário |
|---|---|---|---|---|
| A. Repete sempre | volta ao início da mesma noite, sem custo | nunca frustra | sem tensão; a noite vira tentativa e erro | L e C |
| B. Fim da run | volta ao lobby; gemas pelas noites vencidas | tensão máxima, combina com DEC-035 | perder 5 h de run (cenário L) é inaceitável para criança no mobile | só C |
| **C. Chances do chefe** | a run tem N chances; perder consome 1 e repete a noite; sem chances = fim da run com gemas | tensão + proteção; número ajusta por cenário | mais um número para mostrar | L e C |

**Recomendação: C.**

| Parâmetro | Cenário L | Cenário C |
|---|---|---|
| Chances por run | 3 | 2 |
| Ao repetir | estado volta ao **início da noite** (dinheiro, estoque, upgrades — snapshot em memória); perde o faturamento da noite | igual |
| Sem chances | fim da run; gemas pelas noites vencidas (Q-046) | igual |

Representação sem violência: as luzes do trailer piscam e apagam, a tela escurece, o jogador "acorda" no banco do trailer ao amanhecer
e o chefe liga ("Rough night. Let's try that again."). Chances aparecem só na ligação e na tela de fim de noite, não no HUD.

Jogador fora durante a noite (party): senta no banco do fundo do trailer e assiste pela câmera de um colega; volta no próximo turno com sanidade cheia.

Critérios de aceite:
- Perder uma noite com chances restantes reinicia a mesma noite com o estado idêntico ao do início dela.
- Perder sem chances leva a party à tela de fim de run e depois ao lobby.
- Nenhuma representação de derrota mostra ferimento, arma ou contato físico.

---

## Q-013 — Ações do jogador diante de anomalia

Cita: DEC-010 (observar → lembrar → decidir → agir), DEC-015 (prompt no mundo), DEC-025 (regra do chefe), DEC-026, DEC-039 (1ª pessoa travada), DEC-041 (escuro).

Regra de design: todo verbo usa **o mesmo botão de interagir** ou só a câmera. Nenhum botão exclusivo na tela (mobile, DEC-014).

| Verbo | Como | Custo |
|---|---|---|
| Atender | prompt "Take Order" no cliente (já existe no dia) | — |
| Recusar | prompt "Refuse" no cliente; ele vai embora | perde a venda |
| Não olhar | virar a câmera; o servidor mede se o alvo está no campo de visão | perde a visão do resto |
| Apagar/acender a luz do trailer | interruptor (prompt) | escuro tira sanidade (DEC-041) |
| Esconder | prompt "Hide" atrás do balcão; câmera abaixa; não atende | fila espera |
| Descartar | prompt na lixeira para ingrediente/dinheiro alterado | perde o item |
| Ir ao ponto seguro | sair do trailer até um ponto marcado (exemplo do usuário, DEC-026) | trailer sem ninguém |
| Ligar para o chefe | Tool "Phone" | cooldown |
| Trancar a porta | prompt na porta do trailer | ninguém entra nem sai |

| Opção | Verbos no MVP | Prós | Contras |
|---|---|---|---|
| A. Mínimo | atender, recusar, não olhar | barato | 10 noites com 3 respostas repetem demais |
| **B. Médio** | atender, recusar, não olhar, luz, esconder, descartar, ponto seguro | 7 respostas para 10 anomalias; cada verbo reaproveita um prompt; a luz liga com a sanidade e com Q-014 | ~4 prompts novos no trailer |
| C. Amplo | B + telefone + trancar porta | mais variedade | escopo e ensino maiores; o telefone duplica a ligação do chefe |

**Recomendação: B.** Cada anomalia tem **um** comportamento correto, e é um destes verbos. A ficha de cada anomalia (`npcs.md`/`features.md`)
declara em tabela: sinal, regra do chefe, verbo correto, verbo errado mais provável. Exemplo de distribuição para 10 anomalias:
recusar ×3, não olhar ×2, luz ×1, esconder ×2, descartar ×1, ponto seguro ×1.

Critérios de aceite:
- Toda anomalia do MVP tem exatamente um verbo correto da lista B.
- Todo verbo funciona no mobile só com o botão de interagir e a câmera.
- Em party, o verbo de um jogador vale para a party quando o alvo é compartilhado (ex.: recusar um cliente).

---

## Q-014 — Ferramenta noturna no MVP

Cita: DEC-006 (uso duplo), DEC-042 (café recupera sanidade — **decidido**), DEC-041 (escuro tira sanidade), DEC-011.

| Opção | O que entra | Prós | Contras |
|---|---|---|---|
| A. Só café | cafeteira no trailer | escopo mínimo | nenhum upgrade de dia com uso noturno (DEC-006 sem exemplo) |
| **B. Café + Trailer Lights** | cafeteira + upgrade de luz com uso duplo | cumpre DEC-006 com um item; conversa com o escuro (DEC-041) e com o verbo "luz" (Q-013) | um upgrade a mais para balancear |
| C. Café + Lights + Lanterna | B + Tool de lanterna com bateria | dá ao jogador fora do trailer uma defesa contra o escuro | mais um Tool na hotbar; risco de "lanterna resolve tudo" |

**Recomendação: B.** Lanterna fica para depois do MVP.

Café (ITM a criar em `items.md`):

| Parâmetro | Valor |
|---|---|
| Onde | cafeteira fixa no trailer (prompt, hold 1 s) |
| Preparo | 6 s, barra de progresso; gera Tool "Coffee" |
| Consumo | estoque de café: pacote de 10 doses, $5 no mercado; trailer começa com 10 |
| Efeito | +25 de sanidade, ao beber (usar o Tool) |
| Cooldown | 60 s por jogador |
| Party | cada um bebe o seu; um jogador pode fazer café e entregar a outro |

Trailer Lights (UPG a criar em `upgrades.md`), $100, só compra com o trailer:
- Dia: +10% de fluxo de clientes.
- Noite: área iluminada de raio 18 studs ao redor do trailer; dentro dela não conta como escuro. Pode ser desligada pelo interruptor (verbo de Q-013).

### Apoio: números de sanidade usados nesta rodada (Q-034 ainda aberta)

| Evento | Variação |
|---|---|
| Início da noite | 100 |
| Ver uma anomalia (alvo no campo de visão por 1 s, uma vez por anomalia por jogador) | −5 |
| Quebrar regra comum | −35 |
| Escuro (fora de luz por mais de 3 s) | −1 por s |
| Café | +25, cooldown 60 s |
| 0 | jogador fora (DEC-043) |

Sanidade só existe à noite (some do HUD de dia). É por jogador.

Critérios de aceite:
- Com a luz ligada, um jogador parado dentro do raio não perde sanidade por escuro.
- Beber café dentro do cooldown não é possível (o Tool não aparece ou fica bloqueado).
- A cafeteira não funciona sem estoque de café.

---

## Resumo das dependências

| Proposta | Funciona em L | Funciona em C | Depende de |
|---|---|---|---|
| Q-032 preço $300 × party | sim | sim, com preço ≈ $160 se o trailer sair no dia 3 | emenda de DEC-037 no cenário C |
| Q-033 dia de ~7,5 min com relógio | sim | sim | Q-044/Q-047 (duração da noite) |
| Q-037 pacote físico, cap. 12, 110 studs | sim | sim | level-designer (distância, linha de visão) |
| Q-036 ladrão de dia, 50% da gaveta | sim | sim (menos dias, menos ladrões) | — |
| Q-018 sem reputação, nota do turno | sim | sim | Q-046 se a nota der gemas |
| Q-015 2 tiers | sim | sim (única que cabe) | — |
| Q-035 chances do chefe | 3 chances | 2 chances | Q-034, Q-046, Q-047 |
| Q-013 7 verbos | sim | sim (5 anomalias usam um subconjunto) | Q-050 |
| Q-014 café + luz | sim | sim | Q-034 (números de sanidade) |
