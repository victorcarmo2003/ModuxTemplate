Status: Rascunho

# Economia

Autor: game-designer, 2026-10-08 (conciliado até a rodada 15). Consolida **[DEC-045, DEC-047, DEC-049, DEC-050, DEC-051, DEC-062, DEC-070, DEC-071, DEC-072, DEC-081 a DEC-085, DEC-092, DEC-098, DEC-100, DEC-101, DEC-104, DEC-106 a DEC-110, DEC-115 a DEC-117, DEC-121, DEC-127 a DEC-129]**
e `proposals-round-1.md` §0 / `proposals-round-2.md` §2–§3 (Aprovados). Números novos desta ficha estão marcados **(proposta)**.
Tudo é tabela de dados; mudar número não exige DEC, mudar regra exige.

## 1. Recursos

| Recurso | Escopo | Persistência | Origem |
|---|---|---|---|
| Money | party | só na run | DEC-033, DEC-059 |
| Gaveta do caixa | party, por turno | só no turno; depositada no resumo | DEC-050 |
| Stock | party | só na run; passa entre turnos | DEC-049 |
| Gemas | por jogador | **entre runs** (DataStore) | DEC-035, DEC-070 |
| Sanidade | por jogador | só na noite | DEC-056 |
| Robux (reviver pela ambulância, só para si) | por jogador | conta Roblox | DEC-092, DEC-116 |
| Crédito de reviver (`ReviveCredits`) | por jogador | **perfil persistido** (recibo de Robux não aplicado) | DEC-117 |

Recursos do MVP: **Money, Stock, Gems** (+ sanidade como medidor de noite). **Sem XP nem níveis** **[DEC-081]**.
Dinheiro é inteiro **[DEC-072]**. Sem reputação **[DEC-051]**.

## 2. Fontes e sumidouros de Money

| Fontes | Valor |
|---|---|
| Dinheiro inicial | $30 **[DEC-045]** |
| Pedido completo | $4 + Σ complementos **[DEC-071]** |
| Pedido incompleto | floor(50%) **[DEC-072]** |
| Gorjeta | $1 na janela 16 + 4K s **[DEC-072]** (Hawker $2) |
| Bônus do chefe (nota) | A +20%, B +10% da gaveta **[DEC-051]** (Shift Lead +5 p.p.) |
| "Nice catch!" | +$5 por Quick Quentin impedido **[DEC-050]** |
| Raincoat Lady (N5) | +$1 extra, 1× por noite, se servida na janela de gorjeta (`npcs.md` NPC-013) **(proposta)** |

| Sumidouros | Valor |
|---|---|
| Pacotes do mercado (prateleiras do Mart, nunca rotacionam) | `items.md` ITM-011 a ITM-019 |
| Upgrades (bancada do Mart, sempre à venda) | $790 (Grill $210, Cooler $170, Counter $230, Lock $80, Lights $100) **[DEC-101, DEC-106]** |
| Trailer (compra fixa no trailer) | $300 × party **[DEC-047, DEC-107]** |
| Rescue Whistle (ITM-021; slot especial, 15%/turno) | $200 × party **[DEC-100, DEC-108, DEC-129]** |
| Ladrão | floor(50%/30% da gaveta) **[DEC-050]** |
| Desperdício | Hot Dog errado ou alterado (ANM-002) na lixeira; Hot Dog e café derrubados por atropelamento (FEAT-036); noite perdida (faturamento descartado; só 1 por run, a 2ª encerra a run) **[DEC-053, DEC-110]** |
| Validade | não existe no MVP: estoque não estraga **[DEC-128]** |

## 3. Preço e custo por pedido **[DEC-071]**

Preço = $4 + Σ complementos (molho $1 · Cheese $2 · Bacon $3 · Potato Sticks $2 · Cream Cheese $2).
Custo = $1,25 (pão + salsicha) + Σ custo por uso. Tabela por ingrediente: `items.md`.

| Pedido de exemplo | Preço | Custo | Margem |
|---|---|---|---|
| base (K = 0) | $4 | $1,25 | $2,75 |
| + Ketchup | $5 | $1,45 | $3,55 |
| + Ketchup + Cheese | $7 | $2,45 | $4,55 |
| + Bacon + Mustard | $8 | $2,95 | $5,05 |
| + Bacon + Cheese + Potato Sticks | $11 | $4,25 | $6,75 |
| máximo (Bacon + Cheese + Cream Cheese ou Potato Sticks) | $11 | $4,25–4,50 | $6,50–6,75 |

## 4. Fluxo de clientes

| Parâmetro | Dia | Noite |
|---|---|---|
| Intervalo base solo | 22 s **[DEC-045]** | 40 s (N1–5) · 36 s (N6–10) **(proposta)** |
| Crescimento | taxa × min(1 + 0,08(d − 1), 1,4) **[DEC-045]** | — |
| Party | ×1,0 / 1,6 / 2,1 / 2,5 na taxa **[DEC-045]**; jogadores **ativos** (conectados e não espectadores) no início do turno **(proposta, Q-067)**; atrasado conta a partir do turno seguinte à chegada (Q-112 d) | igual |
| Trailer Lights | ×1,1 **[DEC-055]** | — |
| Vagas | Counter 3 / 4 / 5 | igual |
| Dados | `Flow.BaseInterval` etc. | `Flow.NightInterval` 40; `Nights[k].Customers` = { `BaseInterval` 40/36, `Max` 6 } (TASK-081, Provisório; FEAT-009) |

## 5. Lucro esperado (solo mediano, Rookie)

### 5.1 Dias **[DEC-071; proposals-round-2 §3.7]**

| Dia | Liberados | K médio | Atendidos | Margem + gorjeta | Lucro líquido | Acumulado (+$30 iniciais) |
|---|---|---|---|---|---|---|
| 1 | K, M | 1,2 | 13 | $4,31 | $56 | $86 |
| 2 | + Cheese | 1,55 | 15 | $4,65 | $70 | $156 |
| 3 | + Bacon | 1,55 | 17 | $4,82 | $82 | $238 |
| 4 | + Potato Sticks | 1,75 | 18 | $5,15 | $93 | $331 |
| 5 | — | 1,75 | 19 | $5,09 | $97 | $428 |
| 6+ | + Cream Cheese | 2,0 | ~20 | $5,35 | ~$107 | — |

Trailer $300 solo = 0,75 × lucro acumulado até o Day 5 ($398) — regra "≈ 0,8×" mantida **[DEC-047, DEC-071]**.

### 5.2 Noites (duração da noite: DEC-127; resto **(proposta)**)

Premissas: K médio 2,0; margem + gorjeta $5,35 por completo; % de completos cai com as anomalias (atenção dividida).

| Noite | Duração (min) | Intervalo | Chegadas | % completos | Completos | Lucro líquido |
|---|---|---|---|---|---|---|
| 1 | 20 | 40 s | 30 | 75% | 22 | $120 |
| 2 | 21 | 40 s | 31 | 74% | 23 | $123 |
| 3 | 22 | 40 s | 33 | 73% | 24 | $129 |
| 4 | 23 | 40 s | 34 | 72% | 24 | $131 |
| 5 | 24 | 40 s | 36 | 70% | 25 | $135 |
| 6 | 26 | 36 s | 43 | 69% | 30 | $159 |
| 7 | 27 | 36 s | 45 | 68% | 31 | $164 |
| 8 | 28 | 36 s | 47 | 67% | 31 | $168 |
| 9 | 29 | 36 s | 48 | 66% | 32 | $170 |
| 10 | 30 | 36 s | 50 | 65% | 33 | $174 |
| **Total** | 250 | | 397 | | 275 | **$1.473** |

Nota da noite típica: C (65–75% satisfeitos) → sem bônus. Nota A à noite é rara de propósito.
Estoque por noite: 22–33 salsichas → 1 a 3 idas ao mercado pela rua escura, conforme o Cooler (uso duplo do Cooler, DEC-006).

### 5.3 Run completa (solo)

| Bloco | Lucro |
|---|---|
| Dias 1–5 | $398 |
| Dias 6–14 (9 dias × ~$107) | ~$963 |
| Noites 1–10 | ~$1.473 |
| + inicial | $30 |
| **Total ganho** | **~$2.860** |
| Gasto em upgrades + trailer | $1.090 |
| **Sobra no fim da run** | **~$1.770** (aceito, DEC-082) |
| Rescue Whistle, se comprar todas as ofertas (~2,85 × $200) | −~$570 (opcional) |
| Sobra com todos os apitos | ~$1.200 |

Lucro por minuto de turno: dias ~$13–18/min de loja aberta; noites ~$5,8–6,0/min (menos clientes, mais tempo de atenção).

### 5.4 Rescue Whistle no orçamento (preço e chance: DEC-129)

| Party | Preço do apito | Lucro por ciclo dia+noite (estimado) | Apito ÷ ciclo | Ofertas esperadas por run |
|---|---|---|---|---|
| 1 | $200 | ~$250 | 0,80 | 2,85 |
| 2 | $300 | ~$400 | 0,75 | 2,85 |
| 3 | $380 | ~$525 | 0,72 | 2,85 |
| 4 | $440 | ~$625 | 0,70 | 2,85 |

Leitura: "bem caro" (DEC-092) = quase um ciclo inteiro de lucro. Antes de ~Day 8 compete com Grill 3/Counter 3; depois usa a sobra. Party grande paga um pouco menos por cabeça e tem mais gente para reviver: incentivo leve ao co-op, igual ao trailer.

Reviver por Robux (developer product, DEC-092): só o próprio caído compra, para si **[DEC-116]**; preço **adiado** com a monetização (**Q-098**). Não entra no balanço de Money. Recibo que não pode ser aplicado vira 1 crédito de reviver no perfil **[DEC-117]**.

## 6. Gemas **[DEC-070, DEC-083, DEC-084, DEC-104]**

Creditadas e **salvas no instante de cada evento**, para quem está no servidor naquele instante (inclusive caído e espectador) **[DEC-104]**. A tela de resumo só mostra.

| Evento | Gemas |
|---|---|
| Turno de dia concluído (run e dia infinito) | 2, só se a party entregou **≥ 3 pedidos completos** no turno **[DEC-083]** |
| Nota A no dia | +1, com o mesmo mínimo de ≥ 3 completos (confirmação da leitura do secretário) |
| Noite N vencida | 15 + 2 × (N − 1) → 15, 17, 19, 21, 23, 25, 27, 29, 31, 33 (soma 240) |
| Final (Night 10 vencida) | +100, 1× por run |
| Achievement "Day 100" | +300, 1× por conta, badge; 100 dias de modo infinito somados entre sessões **[DEC-084]** |
| Fim da run por 2ª noite perdida (chance já usada, DEC-110) | 0 extra (ficam as já creditadas) |

| Momento (solo mediano) | Tempo | Gemas acumuladas | Compra possível |
|---|---|---|---|
| Fim do Day 5 | ~39 min | ~12 | — |
| Fim da Night 2 | ~95 min | ~47 | 1ª classe tier 1 (45) |
| Fim da Night 5 | ~3 h | ~120 | tier 2 ou 2 de tier 1 |
| Run completa | ~6,4 h | ~375 (perfeita: 382) | ~3 classes |
| Dia infinito | — | ~24/h | — |

Classes do MVP (Runner 45 + Line Cook 45 + Night Owl 120 = 210) cabem numa run completa. Coleção das 7 pagas: 675 gemas ≈ 1,8 run.

Anti-AFK **[DEC-083]**: sem o mínimo, dia infinito parado renderia ~16 gemas/h só com o relógio; com ele, rende 0.
Desconectado no instante do evento não recebe aquele evento; quem sai mantém o já ganho **[DEC-104]**. Atrasado (DEC-098) recebe a partir do primeiro evento em que está no servidor.

## 7. Dinheiro depois do trailer **[DEC-082]**

Decidido: **opção A** — o dinheiro sobrando depois de ~Day 8 é aceito no MVP; nada novo entra para resolver.
Solo termina a run com ~$1.770 sem uso (~$1.200 se comprar todos os Rescue Whistles); no dia infinito, tudo está comprado por volta do Day 10–12.
Futuro (fora do MVP, sem data): decoração do veículo com dinheiro (opção C), respeitando DEC-006.
Uso opcional que já existe no MVP: Rescue Whistle (§5.4), sem ter sido criado para isso.

## 8. Escala por party

| Party | Taxa de clientes | Preço do trailer | Rescue Whistle | Razão trailer ÷ taxa |
|---|---|---|---|---|
| 1 | ×1,0 | $300 | $200 | 1,00 |
| 2 | ×1,6 | $450 | $300 | 0,94 |
| 3 | ×2,1 | $570 | $380 | 0,90 |
| 4 | ×2,5 | $660 | $440 | 0,88 |

Party grande chega ao trailer um pouco antes por jogador (incentivo ao co-op). Upgrades não escalam com a party (preço fixo; o ganho da party com Counter já é maior).

Tamanho da party para trailer e Rescue Whistle: membros do roster que entraram até o fim do Day 1, fixo dali em diante **[DEC-121, DEC-129]** (FEAT-001). A taxa de clientes usa os **ativos no início de cada turno** (Q-067): uma party que perde membros para o spectate (DEC-093) passa a faturar menos, mas os preços não caem.

## 9. Monetização

Adiada, com uma exceção **[DEC-062, DEC-092]**:

| Produto | Tipo | Preço | Estado |
|---|---|---|---|
| Reviver pela ambulância | developer product (repetível), só o próprio caído compra, para si **[DEC-116]**; recibo não aplicado = crédito no perfil **[DEC-117]** (FEAT-034) | adiado (**Q-098**) | definido como regra; preço adiado |
| Resto (gemas, passes, cosméticos) | — | — | adiado (**Q-017**) |

Guardas de design: classe sempre comprável com gemas de jogo; teto ±12%; nenhuma classe só paga; preferir cosmético **[DEC-069]**. Para o reviver (contra "pay-to-skip-horror"): limite de 2 revives por jogador por noite, Robux + apito **[DEC-129]**; prazo até 6:00 AM **[DEC-115]**; Robux só para si **[DEC-116]**; (proposta) oferta discreta só no spectate, sem pop-up nem contador fora da janela de 10 s, nunca na regra crítica (ANM-007).

## 10. Critérios de aceite

- Simulação solo Rookie, dias 1–5: acumulado entre $360 e $420 **[DEC-071]**.
- Simulação solo: Night 1 rende entre $100 e $140; Night 10 entre $150 e $200.
- A party nunca tem saldo negativo; toda transação é do servidor.
- Soma de gemas de uma run perfeita = 382 **[DEC-070]**.
- Dia com < 3 pedidos completos credita 0 gemas.
- Rescue Whistle custa exatamente $200 × multiplicador (party do fim do Day 1); aparece em 15% ± 1 p.p. dos turnos elegíveis (simulação).

## 11. Propostas pendentes (economia)

| Q | Opções | Recomendação | Precisa do usuário? |
|---|---|---|---|
| **Q-120 h** Limite do Rescue Whistle | sem limite · 1 por turno · N por run | 1 unidade por aparição, sem limite por run (a raridade de 15% limita) | não |
| **Q-067** Fluxo com desconectados | início da run · conectados · **ativos no início do turno** | ativos (conectados e não espectadores) | não |

Decididas: **Q-120 e** (preço $200 × party, chance 15%/turno) → **DEC-129**; **Q-112 a** (party para preços = roster até o fim do Day 1) → **DEC-121**; **Q-025** validade → **DEC-128**; **Q-044** duração da noite → **DEC-127**.
| **Q-098** Preço do reviver em Robux | fixo · cresce por noite · cresce por reviver | quando a monetização for planejada: **fixo**, com o limite de 2/noite segurando o abuso | adiada (usuário) |
| Nota A e anti-AFK (leitura de DEC-083) | — | o +1 da nota A exige o mesmo mínimo de 3 completos | não (confirma a leitura) |
