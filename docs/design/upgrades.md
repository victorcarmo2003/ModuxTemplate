Status: Rascunho

# Upgrades e equipamentos (UPG-###)

Autor: game-designer, 2026-10-08 (conciliado até a rodada 15). Fontes: **[DEC-006, DEC-046, DEC-047, DEC-050, DEC-052, DEC-055, DEC-057, DEC-082, DEC-086, DEC-101, DEC-106, DEC-107, DEC-121, DEC-125, DEC-128, DEC-129]**,
`proposals-round-1.md` §0.3 (Aprovado). Preços e efeitos aprovados como valores iniciais (DEC-046); o resto é proposta.
DEC-006 exige efeito de **dia e de noite** para cada equipamento: toda ficha declara os dois (ou "nenhum", justificado).
Nomes de nível propostos pelo narrative-writer (`ui-text.md` §3, Rascunho): Old Grill → Double Grill → Big Sizzle Grill · Small Cooler → Big Cooler → Deep Chill Cooler · Little Counter → Wide Counter → Long Counter · Drawer Lock · Trailer Lights · Coffee Maker.
Tabela `Upgrades` (id, nível, preço, efeitos tipados, peça visível, pré-requisito, `benchSlot`).

**Onde se compra (rodadas 11–12):** todos os upgrades UPG-001 a UPG-005 são comprados na **bancada da parede do fundo do Ninth Street Mart** **[DEC-101]**, sempre à venda, sem rotação **[DEC-106]** (FEAT-015). O efeito e a peça aparecem no veículo na hora.
O **Food Trailer** (UPG-006) **não** está na bancada: compra fixa no próprio trailer, do Day 5 em diante **[DEC-107]**. A **cafeteira** (UPG-007, "Coffee Maker") vem com o trailer e não é vendida **[DEC-055, DEC-125]**.
O único item rotativo da bancada é especial, não upgrade: Rescue Whistle (ITM-021, FEAT-035; "Revive Kit" em DEC-129).

## Template de ficha

```
### UPG-### — Nome
Status · Origem · Veículo (carrinho/trailer)
Tabela de níveis: preço, efeito de dia, efeito de noite, peça visível
Pré-requisito
Critérios de aceite
```

## Índice

| ID | Upgrade | Níveis | Custo total | Veículo | Onde se compra | Rotaciona? |
|---|---|---|---|---|---|---|
| UPG-001 | Grill | 1–3 | $210 | ambos | bancada B1 | não |
| UPG-002 | Cooler | 1–3 | $170 | ambos | bancada B2 | não |
| UPG-003 | Counter | 1–3 | $230 | ambos | bancada B3 | não |
| UPG-004 | Cash Drawer Lock | 0–1 | $80 | ambos | bancada B4 | não |
| UPG-005 | Trailer Lights | 0–1 | $100 | só trailer | bancada B5 (após a compra do trailer) | não |
| UPG-006 | Food Trailer (veículo) | — | $300 × party | troca | prompt no trailer, estacionamento | não (DEC-107) |
| UPG-007 | Coffee Maker | incluída | $0 (vem com o trailer) | só trailer | — | — |

Soma de tudo que se compra com dinheiro (solo): $210 + $170 + $230 + $80 + $100 + $300 = **$1.090**.

---

### UPG-001 — Grill

- Origem: **[DEC-046, DEC-016]** · Veículo: ambos (o nível passa para o trailer, proposta para Q-075) · Compra: bancada B1

| Nível | Preço | Vagas | Tempo por salsicha | Dia | Noite | Peça visível |
|---|---|---|---|---|---|---|
| 1 | inicial | 2 | 12 s | base | base | chapa simples |
| 2 | $60 | 3 | 10 s | mais hot dogs na janela de gorjeta | menos tempo de costas para a rua; sobra atenção para anomalias | segunda chapa |
| 3 | $150 | 4 | 8 s | idem | idem | grelha grande com tampa cromada |

- **DEC-138 (2026-10-10):** a peça visível do Grill (AST-012) passou a ser uma **roller grill** (máquina de rolos). A coluna "Peça visível" acima ficou desatualizada; leitura dos 3 níveis (nº de rolos / tamanho) em `Q-134`. Vagas, tempos e preços não mudam.
- Line Cook (CLS-003): ×0,85 sobre o tempo do nível, só nas salsichas dele.
- Critérios de aceite: comprar o nível 2 com salsichas grelhando não reinicia as barras em andamento; a vaga nova aparece vazia.

### UPG-002 — Cooler

- Origem: **[DEC-046, DEC-049, DEC-071]** · Veículo: ambos

| Nível | Preço | Capacidade (unidades / coberturas un. / molhos / coberturas em uso / Cream Cheese) | Dia | Noite | Peça visível |
|---|---|---|---|---|---|
| 1 | inicial | 12 / 8 / 30 / 15 / 12 | base | base | caixa térmica pequena |
| 2 | $50 | 20 / 14 / 50* / 25 / 20* | ~1 ida a menos ao mercado por dia | menos idas pela rua escura (sanidade, anomalias de rua) | caixa térmica dupla |
| 3 | $120 | 30 / 20 / 75* / 35 / 30* | ~2 idas a menos | idem, forte | geladeira de inox |

`*` proposto (`items.md`, Q-062). Café não muda com o Cooler.
- Conservação/validade (§11 do GDD V1): fora do MVP **[DEC-128]**; o Cooler só aumenta capacidade.
- Critérios de aceite: capacidade sobe na hora; o estoque atual não muda.

### UPG-003 — Counter

- Origem: **[DEC-046, DEC-072]** · Veículo: ambos

| Nível | Preço | Vagas no balcão | Paciência extra | Dia | Noite | Peça visível |
|---|---|---|---|---|---|---|
| 1 | inicial | 3 | +0 s | base | base | balcão curto |
| 2 | $70 | 4 | +10 s | mais clientes simultâneos; menos spawns pulados (forte em party) | dá tempo de resolver uma anomalia sem perder clientes | balcão estendido + banquinhos |
| 3 | $160 | 5 | +20 s | idem | idem | balcão em L com toldo |

- Paciência final = 40 + 5 × K + extra **[DEC-072]**.
- Critérios de aceite: cliente já no balcão recebe a paciência extra na hora da compra.

### UPG-004 — Cash Drawer Lock

- Origem: **[DEC-050]** · Veículo: ambos

| Nível | Preço | Efeito de dia | Efeito de noite | Peça visível |
|---|---|---|---|---|
| 0 | — | ladrão abre em 8 s, rouba 50% | — | gaveta simples |
| 1 | $80 | Quick Quentin abre em **16 s**, rouba **30%** | **nenhum** (não há ladrão à noite, DEC-050); exceção consciente a DEC-006 | cadeado na gaveta |

- Critérios de aceite: os de `proposals-round-1.md` Q-036 (valor exato floor(gaveta × 0,3)).

### UPG-005 — Trailer Lights

- Origem: **[DEC-055, DEC-006, DEC-106]** · Veículo: só trailer · Compra: bancada B5, que mostra "Trailer only" até a compra do trailer e fica **fixa** à venda dali em diante (sem rotação: fecha o risco de `Q-064`)

| Nível | Preço | Efeito de dia | Efeito de noite | Peça visível |
|---|---|---|---|---|
| 0 | — | — | só o interior do trailer é `LightZone`; o interruptor ("Lights") já existe e controla a lâmpada interna | — |
| 1 | $100 | taxa de clientes ×1,1 | `LightZone` de raio 18 studs ao redor do trailer, ligada pelo mesmo interruptor | cordão de lâmpadas + refletor no teto |

- A ANM-003 (The stopped clock, verbo luz) **não depende** deste upgrade: a sequência "lights off, count five, lights on" funciona com o interruptor do trailer em qualquer nível (FEAT-020).
- O Walker (ANM-007) mira um ponto fixo (passo 10, borda da luz do trailer); comprar Trailer Lights **não** encurta o caminho dele.
- Critérios de aceite: os de `proposals-round-1.md` Q-014; desligar o interruptor apaga também o raio externo.

### UPG-006 — Food Trailer (veículo)

- Origem: **[DEC-007, DEC-019, DEC-037, DEC-047, DEC-052, DEC-057]** · detalhe da compra em FEAT-016

| Campo | Valor |
|---|---|
| Preço | $300 × party: 1p $300 · 2p $450 · 3p $570 · 4p $660 (tamanho = roster que entrou até o fim do Day 1, fixo **[DEC-121]**; FEAT-001) |
| Disponível | Day 5 em diante; visível desde o Day 1 ("Available on Day 5"); **fora da rotação** da bancada, compra fixa por prompt no trailer **[DEC-107]** |
| Troca | fim do turno da compra; o trailer passa a trabalhar **na esquina, no Pad do carrinho** **[DEC-086]**; próximo turno = Night 1 |
| Leva junto | níveis de UPG-001 a UPG-004, estoque, dinheiro |
| Acrescenta | UPG-007 (cafeteira, 10 doses), interruptor "Lights", esconderijo atrás do balcão (4 jogadores), banco do fundo, telefone fixo, porta dos fundos sem prompt (N9), 3 tábuas, trilho 8; libera UPG-005 |
| Nome proposto | "Open Late Trailer", letreiro "BRAMBLE'S — OPEN LATE" (`world.md` §4, `ui-text.md` §3); o carrinho: "Corner Cart", letreiro "BRAMBLE'S CORNER DOGS" |
| Dia | mesmo trabalho, layout maior para 4 jogadores |
| Noite | abre o turno da noite (DEC-007) |

- Critérios de aceite: os de `proposals-round-1.md` Q-032 e FEAT-016.

### UPG-007 — Coffee Maker

- Origem: **[DEC-055, DEC-125]** · Veículo: só trailer · Preço: $0 (vem com o trailer; não é vendida na bancada **[DEC-125]**). Nome de exibição "Coffee Maker" (`ui-text.md`).

| Campo | Valor |
|---|---|
| Uso | hold 1 s; 6 s de preparo; 1 dose → 1 Coffee (ITM-009) |
| Doses | começa com 10; capacidade 20; Restock com ITM-019 |
| Dia | nenhum efeito útil (sanidade só existe à noite) |
| Noite | única fonte de recuperação de sanidade **[DEC-042]** |
| Upgrade | nenhum nível no MVP |

- Critérios de aceite: um café por vez; sem dose, o prompt mostra "Out of coffee".

---

## Tabela de balanceamento comparável

Base: Rookie solo, **dia 3**, lucro líquido $82 em 6 min de loja aberta = **$13,7/min** (`proposals-round-2.md` §3.7).
Ganho percentual de cada upgrade = estimativa aprovada em `proposals-round-1.md` §0.3; colunas de payback e party são novas (estimativa de mesa;
a simulação de balanceamento manda).

| Upgrade | Preço | Ganho solo (vs. nível anterior) | Lucro/min depois | Δ $/min | Payback (min de loja aberta) | Payback (dias, só dia) | Ganho estimado party de 4 |
|---|---|---|---|---|---|---|---|
| — (base) | — | — | $13,7 | — | — | — | — |
| Grill 2 | $60 | +12% | $15,3 | +$1,64 | 37 | 6,1 | +10% |
| Grill 3 | $150 | +10 p.p. (total +22%) | $16,7 | +$1,37 | 109 | 18 | +12 p.p. |
| Cooler 2 | $50 | +5% | $14,4 | +$0,69 | 73 | 12 | +8% (4 jogadores esvaziam o estoque mais rápido) |
| Cooler 3 | $120 | +3 p.p. (total +8%) | $14,8 | +$0,41 | 293 | 49 | +6 p.p. |
| Counter 2 | $70 | +8% | $14,8 | +$1,10 | 64 | 11 | +15% (balcão é o gargalo da party) |
| Counter 3 | $160 | +6 p.p. (total +14%) | $15,6 | +$0,82 | 195 | 33 | +10 p.p. |
| Cash Drawer Lock | $80 | evita ~$10/dia (dia 3+) | — | +$1,67 equiv. | 48 | 8 | menor (party sempre deixa alguém) |
| Trailer Lights | $100 | +10% de chegadas ≈ +6% servidos | $14,5 | +$0,82 | 122 | 20 | +8% |

Leitura:

- **Antes do trailer** (dias 1–5, horizonte de ~30 min de loja aberta), só Grill 2 e o Lock se pagam. Isso é a tensão aprovada "upgrade ou trailer?" (DEC-045, DEC-047): o solo que compra Grill 2 + Lock ($140) ainda compra o trailer no Day 5 ou 6.
- **Depois do trailer**, cada ciclo dia + noite rende ~$250 solo (`economy.md`); os percentuais valem também à noite. Grill 3 se paga em ~6 ciclos, Counter 3 em ~10, Cooler 3 em ~19 ciclos. Por isso Cooler 3 se justifica pela **noite** (menos idas pela rua escura, DEC-006), não pelo lucro.
- **Em party**, Counter vira o melhor upgrade (gargalo é a vaga no balcão); em solo, Grill.
- Ordem ótima esperada (solo): Grill 2 → Lock → (trailer) → Counter 2 → Trailer Lights → Grill 3 → Cooler 2 → Counter 3 → Cooler 3.
- Gasto total esperado até o fim da run solo: $1.090 de ~$2.860 ganhos — sobra dinheiro no fim da run; **aceito no MVP** **[DEC-082]** (`economy.md` §7). O Rescue Whistle (ITM-021) dá um uso opcional a essa sobra.
- **Bancada no Mart (DEC-101)**: comprar custa uma ida ao Mart (~25 s de dia, ~0,4% da loja aberta do dia; à noite ~2–4 de sanidade por perna). Como a ida já acontece para repor estoque (1–3 por turno), o custo marginal é ~0 se combinada. A tabela de payback não muda; a curva "tudo comprado ~Day 8" segue (`progression.md` §3). Sem rotação de básicos (DEC-106), não há atraso por sorteio.

### Custo por tier e item especial (comparável)

| Compra | Preço solo | Party de 4 | Δ $/min solo | Payback solo (min de loja aberta) | Uso |
|---|---|---|---|---|---|
| Grill 2 / 3 | $60 / $150 | igual | +1,64 / +1,37 | 37 / 109 | lucro |
| Cooler 2 / 3 | $50 / $120 | igual | +0,69 / +0,41 | 73 / 293 | lucro + menos idas no escuro |
| Counter 2 / 3 | $70 / $160 | igual | +1,10 / +0,82 | 64 / 195 | lucro (melhor em party) |
| Cash Drawer Lock | $80 | igual | +1,67 equiv. | 48 | proteção de dia |
| Trailer Lights | $100 | igual | +0,82 | 122 | lucro + luz à noite |
| Food Trailer | $300 | $660 | — | — | marco; abre a noite |
| Rescue Whistle (ITM-021, especial, 15%/turno, DEC-129) | $200 | $440 | 0 | — | seguro: evita espectador permanente / noite perdida |

## Critérios de aceite (balanceamento)

- Simulação solo Rookie, dias 1–5: com Grill 2 + Lock comprados até o Day 3, o trailer ($300) é comprável até o fim do Day 6.
- Simulação solo: cada upgrade fica a ±3 p.p. do ganho da tabela; se ficar fora, ajusta-se o número na tabela, não o código.
- Simulação party de 4: Counter 2 rende mais que Grill 2 em lucro/min.
- Simulação solo com compras na bancada do Mart combinadas com reposição: tudo comprado até o fim do Day 8 em ≥ 80% das execuções.

## Propostas pendentes (upgrades)

| Q | Recomendação | Precisa do usuário? |
|---|---|---|
| **Q-075** Nível passa ao trailer | sim, mesmo nível; peça visível nos dois veículos | não |
| **Q-120 a, g, h** Bancada | 5 posições fixas (B1–B5) + 1 slot especial (S1); prateleiras não rotacionam; impacto na curva: nenhum para básicos, Rescue Whistle custa ~$570/run solo da sobra (chance e preço: DEC-129) | não |
| **Q-064** Interruptor x Trailer Lights | interruptor vem com o trailer; Trailer Lights fixo em B5 depois da compra | não |

Decidida: **Q-124** cafeteira → **DEC-125** (fixa no trailer, não vendida).
