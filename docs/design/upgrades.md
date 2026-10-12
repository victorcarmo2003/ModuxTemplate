Status: Rascunho

# Upgrades e equipamentos (UPG-###)

Autor: game-designer, 2026-10-08 (conciliado até a rodada 15). Fontes: **[DEC-006, DEC-046, DEC-047, DEC-050, DEC-052, DEC-055, DEC-057, DEC-082, DEC-086, DEC-101, DEC-106, DEC-107, DEC-121, DEC-125, DEC-128, DEC-129]**,
`proposals-round-1.md` §0.3 (Aprovado). Preços e efeitos aprovados como valores iniciais (DEC-046); o resto é proposta.
DEC-006 exige efeito de **dia e de noite** para cada equipamento: toda ficha declara os dois (ou "nenhum", justificado).
Nomes de nível propostos pelo narrative-writer (`ui-text.md` §3, Rascunho): Old Grill → Double Grill → Big Sizzle Grill · Small Cooler → Big Cooler → Deep Chill Cooler · Little Counter → Wide Counter → Long Counter · Drawer Lock · Trailer Lights · Coffee Maker.
Tabela `Upgrades` (id, nível, preço, efeitos tipados, peça visível, pré-requisito, `benchSlot`).

**Onde se compra (rodadas 11–12):** todos os upgrades UPG-001 a UPG-005 são comprados na **bancada da parede do fundo do Ninth Street Mart** **[DEC-101]**, sempre à venda, sem rotação **[DEC-106]** (FEAT-015). O efeito e a peça aparecem no veículo na hora.
O **Food Trailer** (UPG-006) **não** está na bancada: compra fixa no próprio trailer, a partir da manhã depois da noite `Content.Trailer.OfferAfterNight` (= 2; antes: Day 5; pedido do dono 2026-10-12, Provisório, Q-206) **[DEC-107]**; o prompt de compra fica na **placa FOR SALE**, não no trailer; o Walt liga, repassa o dinheiro que falta e manda olhar a placa (`script.md` §4.1b). A **cafeteira** (UPG-007, "Coffee Maker") vem com o trailer e não é vendida **[DEC-055, DEC-125]**.
**Pad vazio (pedido do dono 2026-10-12, Provisório, `Q-216`):** com o trailer em uso o carrinho, o `PadDecor` e as mesas do Pad (UPG-008, TBL-1..5; e a placa Patio Lights, UPG-009) somem por completo do Pad; o nível comprado fica guardado (Pad scope) e só volta a valer se o carrinho voltar. As mesas do trailer (UPG-011) seguem como estão.

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
| UPG-008 | Patio Tables (mesas do Pad) — Provisório | 0–5 (1 mesa por nível) | $315 | **Pad** (as duas, não recomeça na troca, `Q-179`) | na própria mesa fantasma no Pad (`Q-178`) | não |
| UPG-009 | Patio Lights — Provisório | 0–1 | $120 | Pad | na mesa `TBL-1` (placa) no Pad (`Q-178`) | não |
| UPG-011 | Trailer Table (4 mesas do trailer, `TBL-6..9`) — Provisório (`Q-209`) | 0–4 (1 mesa por nível) | $330 ($50 / $70 / $90 / $120) | **só trailer** (`Scope = "Vehicle"`) | na própria mesa fantasma, só depois de comprar o trailer (`Q-209`) | não |
| UPG-010 | Back Bar (bancada externa do trailer) — Provisório, cortável | 0–1 | $90 | só trailer | na própria bancada dobrada, no trailer (`Q-178`, `Q-179`) | não |

Soma de tudo que se compra com dinheiro (solo): $210 + $170 + $230 + $80 + $100 + $300 = **$1.090**.
Com as mesas (2026-10-11, Provisório): + $315 + $120 + $90 = **$1.615** (ainda abaixo dos ~$2.860 ganhos numa run solo; sobra ~$1.245, `economy.md` §7).

**Onde se compra — mesas (2026-10-11, Provisório, `Q-178`):** UPG-008 a UPG-010 **não** vão para o Gear Stand (os 6
pedestais B1–B5 + S1 estão ocupados e o layout 3 + Opal + 3 é simétrico, FEAT-015 v2). Compra **no lugar**, como o
trailer (DEC-107): a mesa ainda não comprada aparece "fantasma" no Pad com o prompt "Buy Table — $N". Isso contraria a
leitura literal de DEC-101 ("upgrades na bancada do Mart") e por isso volta ao usuário; a mesa não é equipamento do
veículo, então o critério da FEAT-015 "nenhum prompt de compra em equipamento do veículo" segue valendo.

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
| 0 | — | — | lâmpada de fábrica (DEC-189): interior do trailer (LZ-1) **e varanda do balcão (LZ-2, cobre Q1)** são `LightZone`, sem raio extra (`Sanity.BasicLampRadius = 0`, Provisório, TASK-081); o interruptor ("Lights") controla as duas | — |
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

### UPG-008 — Patio Tables (mesas do Pad)

- Status: Rascunho (Provisório, 2026-10-11) · Origem: pedido do usuário 2026-10-11; regras em **FEAT-037** · Veículo: **Pad** (vale para carrinho e trailer; `Scope = "Pad"`, não recomeça na troca, `Q-179`) · Compra: na mesa fantasma, hold 1,5 s, ordem fixa `TBL-1` → `TBL-5` · Libera: Day 2

| Nível (mesas) | Preço | Efeito de dia | Efeito de noite | Peça visível |
|---|---|---|---|---|
| 0 | — | ninguém senta | ninguém senta | 5 mesas fantasma (só a próxima com prompt) |
| 1 | $30 | 1 mesa: clientes Completos sentam (`SitChance`), deixam $2/pessoa na mesa | igual, `SitChance` × 0,75; `MaxDiners` 2 | `TBL-1` sólida (AST-100) |
| 2 | $45 | 2 mesas | igual | + `TBL-2` |
| 3 | $60 | 3 mesas | igual | + `TBL-3` |
| 4 | $80 | 4 mesas (= `MaxDiners` de dia: cada diner pode ter mesa própria) | igual | + `TBL-4` |
| 5 | $100 | 5 mesas (a 5ª serve de folga para mesa suja) | igual | + `TBL-5` |

- DEC-006: efeito de dia e de noite declarados (à noite pesa mais: limpar fora da luz custa escuro, ligação com UPG-005/UPG-009).
- Critérios de aceite: os da FEAT-037; comprar não mexe em diners já sentados; a mesa nova nasce limpa e livre.

### UPG-009 — Patio Lights

- Status: Rascunho (Provisório, 2026-10-11) · Origem: pedido do usuário ("decoração ligada às mesas") · Veículo: Pad · Compra: placa ao lado de `TBL-1`, hold 1,5 s · Pré-requisito: **UPG-008 nível ≥ 2** · Libera: Day 2

| Nível | Preço | Efeito de dia | Efeito de noite | Peça visível |
|---|---|---|---|---|
| 0 | — | — | mesas no escuro (salvo as que caem no raio do Trailer Lights) | — |
| 1 | $120 | `SitChance` **+0,10** (pátio decorado) | `SitChance` +0,10 **e** `LightZone` `LZ-PATIO` cobrindo todas as mesas compradas, ligada pelo **mesmo interruptor** do trailer (FEAT-020; a ANM-003 apaga junto; o Hush apaga) | cordão de lâmpadas em postes baixos sobre as mesas + vaso por mesa |

- Antes do trailer o efeito de noite não existe (não há noite); a compra no Day 2–5 é só pelo dia.
- Critérios de aceite: com Patio Lights e interruptor ligado, jogador limpando qualquer mesa comprada não perde sanidade por escuro; interruptor desligado apaga `LZ-PATIO`; mesa comprada depois da luz entra na zona na hora.

### UPG-011 — Trailer Table (mesas do trailer)

- Status: Rascunho (Provisório, 2026-10-12) · Origem: pedido do dono 2026-10-12 (4 mesas colocadas por ele junto do trailer; ver `Q-209`) · Veículo: **só trailer** (`Scope = "Vehicle"`: no carrinho o nível nem existe) · Compra: na mesa fantasma, hold 1,5 s (`buy_in_place`, "Buy Table — $N"), ordem fixa `TBL-6` → `TBL-9` (a mais perto da fila primeiro) · Libera: assim que o trailer é o veículo
- Mesmas regras de sentar, comer, gorjeta e limpar do UPG-008/FEAT-037 (`SitChance`, `EatTime`, `TableTip`, `MaxDiners`). Outro grupo de mesas (`Content.Seating.Groups`): **não mistura** com as mesas do Pad (com o trailer e ≥ 1 mesa comprada aqui, só estas sentam).

| Nível (mesas) | Preço | Efeito de dia | Efeito de noite | Peça visível |
|---|---|---|---|---|
| 0 | — | antes do trailer: nada aparece (mesas escondidas, sem colisão); depois: só a 1ª aparece como fantasma com preço | igual | — |
| 1 | $50 | 1 mesa do trailer | igual (`SitChance` × 0,75; `MaxDiners` 2) | `TBL-6` sólida; `TBL-7` fantasma |
| 2 | $70 | 2 mesas | igual | + `TBL-7`; `TBL-8` fantasma |
| 3 | $90 | 3 mesas | igual | + `TBL-8`; `TBL-9` fantasma |
| 4 | $120 | 4 mesas | igual | + `TBL-9` |

- Fantasma esmaecido (mais transparente, com o preço) enquanto a party não tem o dinheiro, como a bancada do Gear Stand.
- Cada mesa precisa de `NpcNode` `TBL-n` perto e aresta até a fila (os clientes caminham até lá); sem isso a party volta depois de 30 s (`Seating.StandTimeout`).
- Preços **do agente** (o trailer chega depois da Noite 2: mais dinheiro que no carrinho). Ajuste fino na simulação.
- Critérios de aceite: no carrinho as 4 mesas estão invisíveis e sem colisão; ao comprar o trailer a 1ª vira fantasma com preço; comprar torna a mesa sólida e a próxima fantasma; cliente `Completo` senta na mesa do trailer, come, deixa gorjeta, a bandeja suja e "Clean Table" limpa; nunca senta numa mesa do Pad enquanto o grupo Trailer manda.

### UPG-010 — Back Bar (bancada externa do trailer)

- Status: Rascunho (Provisório, **cortável**, 2026-10-11) · Origem: pedido do usuário ("mesas do trailer; ele tem um banco/bancada traseira"); leitura em `Q-179` · Veículo: **só trailer** (`Scope = "Vehicle"`) · Compra: na própria bancada dobrada, hold 1,5 s · Libera: depois da compra do trailer

| Nível | Preço | Efeito de dia | Efeito de noite | Peça visível |
|---|---|---|---|---|
| 0 | — | — | — | bancada dobrada contra a parede externa (fantasma da banqueta) |
| 1 | $90 | +1 lugar de mesa (`TBL-BAR`, 3 banquetas; 1 cliente ou 1 dupla; `TBL-6..9` são as mesas do trailer, UPG-011) | igual, e já dentro da luz do trailer (LZ-2 ou raio do Trailer Lights; o level-designer garante): limpar não custa escuro | bancada aberta + 3 banquetas (AST-014 reaproveitada) |

- Posição (level-designer, TASK-149): parede **externa** do trailer, lado oeste (engate) ou traseira, **a ≥ 6 studs da porta dos fundos e da janelinha AN-05** (a ANM-009 bate ali e ninguém pode estar "do lado de fora da porta") e fora da linha janela → Juniper (ANM-007). Clientes **nunca** entram no trailer (DEC-054: porta dos fundos não abre por fora).
- Conta em `MaxDiners` como qualquer mesa; não entra no teto de mesas do UPG-008.
- Critérios de aceite: só aparece depois da troca; durante a ANM-009 ninguém senta no Back Bar e quem está sentado sai (regra de tensão da FEAT-037).

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
| Patio Table 1 / 2 / 3 / 4 / 5 (UPG-008, Provisório) | $30 / $45 / $60 / $80 / $100 | igual | +1,17 / +0,47 / +0,23 / +0,12 / +0,02 | 26 / 96 / 261 / 667 / — | lucro (1–2) → sumidouro/decoração (3–5 solo; 3–4 ainda rendem em party) |
| Patio Lights (UPG-009) | $120 | igual | +0,28 | ~430 | decoração + luz nas mesas à noite |
| Back Bar (UPG-010, trailer) | $90 | igual | só depois do trailer | ~45 ciclos | decoração + mesa iluminada |

### Mesas: tabela comparável (2026-10-11, Provisório; FEAT-037)

Estimativa de mesa (a simulação manda). Base: solo Day 6 (~20 Completos em 6 min, $107/dia) e Night 5 (~25 Completos
em 24 min, $135). `SitChance` médio 0,43 dia / 0,30 noite → ~8,6 candidatos de dia e ~7,5 à noite. "Diners" =
candidatos que acharam mesa limpa e livre, com limpeza a cada ~60 s. Líquido = bruto × 0,7 de dia (tempo longe do
balcão) e × 0,8 à noite (menos fila, mas escuro). Gorjeta de mesa $2/pessoa.

| Mesas | Diners/dia | Líquido/dia | % do dia | Δ $/min (dia) | Diners/noite (`MaxDiners` 2) | Líquido/noite | Δ por ciclo dia+noite | Payback do nível |
|---|---|---|---|---|---|---|---|---|
| 1 | 5,0 | $7,0 | +6,5% | +1,17 | 5,0 | $8,0 | +$15,0 | **4,3 dias** antes do trailer · 2 ciclos depois |
| 2 | 7,0 | $9,8 | +9,2% | +0,47 | 6,5 | $10,4 | +$5,2 | ~9 ciclos |
| 3 | 8,0 | $11,2 | +10,5% | +0,23 | 7,2 | $11,5 | +$2,5 | ~24 ciclos |
| 4 | 8,5 | $11,9 | +11,1% | +0,12 | 7,2 | $11,5 | +$0,7 | sumidouro |
| 5 | 8,6 | $12,0 | +11,2% | +0,02 | 7,2 | $11,5 | ~0 | sumidouro |

Party de 4 (Day 6, lucro ~$230/dia; balcão cheio no pico, então `SitHeadroom` barra boa parte):

| Mesas | Provisório (diners dentro do teto) | Com `Q-180` B (sentado fora do teto, `MaxSeated` 4) |
|---|---|---|
| 1 | 7 diners · +5,5% | 8 · +6,3% |
| 2 | 10 · +7,8% | 14 · +11% |
| 3 | 12 · +9,4% | 19 · +15% |
| 4 | 12 · +9,4% | 22 · +17% |
| 5 | 12 · +9,4% | 24 · +19% |

Leitura:

- Mesa 1 é uma compra boa cedo ($30, paga em ~4 dias), no nível do Grill 2 e do Lock; mesa 2 paga depois do trailer.
  Mesas 3–5, Patio Lights e Back Bar são, no solo, **uso para o dinheiro que sobra** (DEC-082, `economy.md` §7 "decoração"),
  com efeito real pequeno. Em party, as mesas 3–4 rendem como o Counter 3.
- Teto de efeito: 5 mesas + Patio Lights ≈ **+12–13%** solo, abaixo de Grill 3 + Counter 3 somados (+36%) e do mesmo
  porte de um upgrade grande; não quebra a curva (o lucro extra exige trabalho fora do balcão).
- Duplas (FEAT-038) somam ~+7% de pessoas e sentam mais (+0,20), o que puxa as mesas 2–3 para cima de dia.
- Ordem esperada (solo): Grill 2 → **Mesa 1** → Lock → (trailer) → Counter 2 → Trailer Lights → **Mesa 2** → Grill 3 → … → mesas 3–5, Patio Lights, Back Bar.

## Cooldown da bancada (Gear Stand) — Provisório, Q-203

Feedback do usuário (2026-10-11): o momento ideal de comprar é o **fim do expediente**, não correndo no meio do turno.

- **Regra:** comprar um upgrade da bancada (B1–B5, `SoldAt = "Bench"`) tira **aquela linha** de venda (chave `veículo/upgrade`) por `Content.Mart.Cooldown.Turns = 2` turnos **contando o atual**. Comprou no turno T → a linha volta no **início do turno T+2**; o turno T+1 passa inteiro. Comprar no Closing ou no Prep/Open do mesmo turno dá o mesmo retorno (T+2); a vantagem de comprar no fim é gastar o caixa do dia já, sem esperar.
- **Só aquela linha trava.** Outras linhas (Grill, Cooler, Counter, Lock...) continuam à venda; níveis múltiplos da mesma linha (Cooler 2 → 3) respeitam o cooldown entre si. Upgrades `InPlace` (mesas, Patio Lights) e a compra do veículo (Food Trailer) **não** têm cooldown. Slot especial S1 (FEAT-035) ficará fora até existir.
- **Visível:** o miniatura da linha some (pedestal vazio), a plaquinha vira cinza com "Sold out" e "Back next shift" (ou "Back in 2 shifts" no turno da compra), o prompt some. Ao voltar, o mini do próximo nível sobe do pedestal.
- **Trailer:** o cooldown é por veículo; a troca carrinho → trailer começa com todas as linhas livres.
- **Turno repetido:** um turno é identificado por (dia, noite, noturno?); repetir a noite perdida não conta como turno novo, e a restauração do snapshot desfaz a compra **e** o cooldown.
- **Dica de fechamento:** no início do Closing, uma vez por turno, toast "Closing time. Upgrades are on sale at the Mart." (só com caixa + gaveta para a linha mais barata à venda, ou se nunca comprou) e seta guia ao Mart até o início do Open ou até o jogador chegar. Nunca bloqueia compra durante o turno.
- **Dev:** `/dev market` lista pedestais, contador de turnos e cooldowns; `/dev market reset` zera os cooldowns.

## Critérios de aceite (balanceamento)

- Simulação solo Rookie, dias 1–5: com Grill 2 + Lock comprados até o Day 3, o trailer ($300) é comprável até o fim do Day 6.
- Simulação solo: cada upgrade fica a ±3 p.p. do ganho da tabela; se ficar fora, ajusta-se o número na tabela, não o código.
- Simulação party de 4: Counter 2 rende mais que Grill 2 em lucro/min.
- Simulação solo com compras na bancada do Mart combinadas com reposição: tudo comprado até o fim do Day 8 em ≥ 80% das execuções.
- Mesas (Provisório): simulação solo com Grill 2 + Mesa 1 + Lock até o Day 3: o trailer continua comprável até o fim do Day 6.
- Mesas: simulação solo Day 6 com 5 mesas + Patio Lights fica entre +9% e +15% de lucro/dia; se passar de +15%, baixa-se `TableTip` ou `SitChance` na tabela.

## Propostas pendentes (upgrades)

| Q | Recomendação | Precisa do usuário? |
|---|---|---|
| **Q-075** Nível passa ao trailer | sim, mesmo nível; peça visível nos dois veículos | não |
| **Q-120 a, g, h** Bancada | 5 posições fixas (B1–B5) + 1 slot especial (S1); prateleiras não rotacionam; impacto na curva: nenhum para básicos, Rescue Whistle custa ~$570/run solo da sobra (chance e preço: DEC-129) | não |
| **Q-064** Interruptor x Trailer Lights | interruptor vem com o trailer; Trailer Lights fixo em B5 depois da compra | não |
| **Q-178** Onde/como se compra mesa | compra no lugar (mesa fantasma no Pad), uma mesa por vez, ordem fixa | **sim** (DEC-101) |
| **Q-203** Cooldown da bancada | 1 turno cheio parado por linha (`Cooldown.Turns = 2`) | **sim** (confirmar o número) |
| **Q-179** Mesas na troca de veículo; bancada do trailer | mesas são do Pad e ficam; Back Bar externo, trailer-only, cortável | **sim** (DEC-184) |

Decidida: **Q-124** cafeteira → **DEC-125** (fixa no trailer, não vendida).
