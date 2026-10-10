Status: Rascunho

# Classes jogáveis (CLS-###)

Autor: game-designer, 2026-10-08 (conciliado até a rodada 15). Conteúdo aprovado em **[DEC-061, DEC-069, DEC-070]** (`proposals-round-2.md` §1–§2, Aprovado); ajustes de leitura por DEC-081, DEC-083, DEC-091 a DEC-095, DEC-104, DEC-110 a DEC-129 (nenhuma muda classe; limite de 2 revives/noite, prazo de 6:00 AM e Robux só para si valem igual para todas as classes; sanidade inicial da classe também na noite repetida, DEC-111).
Esta ficha organiza o aprovado no formato de ficha e acrescenta só detalhes de implementação (tipos de efeito, critérios por classe),
marcados como proposta. Nomes são placeholders (narrative-writer). Sistema: FEAT-028. Gemas: FEAT-029, `economy.md` §6.

## Regras gerais **[DEC-069]**

| Regra | Valor |
|---|---|
| Escolha | no lobby; travada até o fim da run |
| Escopo | pessoal (ações do próprio jogador); no máximo 1 efeito de party (Shift Lead), não acumula |
| Repetir na party | permitido |
| Teto | lucro/min solo entre −12% e +12% do Rookie; nenhuma classe toca regra de anomalia (verbo, crítica, chances, −35) |
| Contrapeso | toda classe paga tem um, em outro eixo |
| Obtenção | só com gemas ganhas jogando (gemas creditadas e salvas por evento, DEC-104; anti-AFK, DEC-083) |
| Preço | tier 1 = 45 · tier 2 = 120 · tier 3 = 180 gemas **[DEC-070]** |
| Reviver, ambulância, atropelamento (rodadas 9–15) | nenhuma classe muda: limite de revives (DEC-129), janela de 10 s, prazo de reviver (DEC-115), preço do Rescue Whistle (DEC-129), tempo no chão do atropelamento, proteção de 5 s. Mesmo espírito de "nenhuma classe toca regra de anomalia" (DEC-069) e da guarda contra pay-to-win (Q-017) |
| Sem XP | classes não têm nível nem XP **[DEC-081]** |

### Interação com as regras novas (rodadas 8–12)

| Classe | Efeito indireto (sem regra nova) |
|---|---|
| Runner | cruza a pista mais rápido (18 studs/s): menos exposição ao trânsito (FEAT-033) e chega antes ao Mart para comprar na bancada ou o Rescue Whistle. Sanidade ao reviver: 50 (50% de 100) |
| Line Cook | mais lento (15): um pouco mais exposto na travessia. Sanidade ao reviver: 50 |
| Night Owl | sanidade ao reviver: **60** (50% de 120); de dia, 15 studs/s na travessia |
| Rookie | sanidade ao reviver: 50 |

Nenhum desses efeitos muda o teto de ±12% (a travessia é ~2 × 4 s por ida ao Mart).

## Template de ficha

```
### CLS-### — Nome
Chave · Tier/preço · MVP? · Fantasia
Efeitos (tipo, valor, escopo) · Contrapeso · Turno onde brilha · Papel na party
Δ lucro estimado · Critérios de aceite
```

## Tipos de efeito (tabela `Classes.effects`, proposta)

| Tipo | Parâmetro | Usado por |
|---|---|---|
| `walkSpeed` | studs/s (sempre) | Runner |
| `daySpeed` | studs/s (só de dia) | Night Owl |
| `speedWhileCarrying` | studs/s com N pacotes | Hauler |
| `grillTimeMult` | multiplicador nas salsichas do dono | Line Cook |
| `packageLimit` | nº de pacotes | Hauler |
| `tipValue` | $ por gorjeta nos pedidos do dono | Hawker, Shift Lead ($0) |
| `tipWindowDelta` | s na janela dos pedidos do dono | Hawker |
| `nightSanityStart` / `nightSanityMax` | pontos | Runner, Night Owl |
| `coffeePrepTime` / `coffeeRestore` | s / pontos, cafés feitos pelo dono | Barista |
| `seeLoss` | pontos por anomalia vista pelo dono | Barista |
| `partyGradeBonus` | p.p. no bônus da nota; não acumula | Shift Lead |

## Índice

| ID | Chave | Nome | Tier | Preço | MVP |
|---|---|---|---|---|---|
| CLS-001 | `class_rookie` | "Rookie" | 0 | grátis | **sim** |
| CLS-002 | `class_runner` | "Runner" | 1 | 45 | **sim** |
| CLS-003 | `class_line_cook` | "Line Cook" | 1 | 45 | **sim** |
| CLS-004 | `class_hauler` | "Hauler" | 1 | 45 | não |
| CLS-005 | `class_hawker` | "Hawker" | 2 | 120 | não (5ª se houver folga) |
| CLS-006 | `class_night_owl` | "Night Owl" | 2 | 120 | **sim** |
| CLS-007 | `class_barista` | "Barista" | 2 | 120 | não |
| CLS-008 | `class_shift_lead` | "Shift Lead" | 3 | 180 | não |

---

### CLS-001 — "Rookie"

- Chave `class_rookie` · Tier 0, grátis · MVP · Fantasia: primeiro dia de trabalho.
- Efeitos: nenhum · Contrapeso: nenhum. É a régua do balanceamento.
- Critérios de aceite: todo jogador novo tem Rookie desbloqueado e selecionado; atributos = valores base de todas as tabelas.

### CLS-002 — "Runner"

- Chave `class_runner` · Tier 1, 45 gemas · MVP · Fantasia: entregador de bicicleta que virou atendente.
- Efeito: `walkSpeed` 16 → 18 (+12,5%). Contrapeso: `nightSanityStart` 90 (máx. 100).
- Brilha: dia (mercado e reposição; ida ao mercado ~25 s → ~22 s). Δ lucro solo dia 3: +$3 (+4%).
- Critérios de aceite: velocidade 18 de dia e de noite; cada noite começa em 90; café pode levar a 100.

### CLS-003 — "Line Cook"

- Chave `class_line_cook` · Tier 1, 45 · MVP · Fantasia: ex-cozinheiro de lanchonete de estrada.
- Efeito: `grillTimeMult` 0,85 nas salsichas que **ele** põe na grelha (12 → 10,2 s; 10 → 8,5 s; 8 → 6,8 s). Contrapeso: `walkSpeed` 15.
- Brilha: dia e noite (grelha). Δ lucro solo dia 3: +$3 (+4%).
- Critérios de aceite: a barra da salsicha dele mostra o tempo reduzido e só ela.

### CLS-004 — "Hauler"

- Chave `class_hauler` · Tier 1, 45 · fora do MVP · Fantasia: estoquista do mercado da esquina.
- Efeito: `packageLimit` 3. Contrapeso: `speedWhileCarrying` 14 com 3 pacotes.
- Brilha: dia (estoque). Δ lucro solo dia 3: +$2 a +$4 (+3–5%).
- Critérios de aceite: 3º pacote permitido; velocidade 14 só enquanto segura 3.

### CLS-005 — "Hawker"

- Chave `class_hawker` · Tier 2, 120 · fora do MVP (5ª se houver folga) · Fantasia: vendedor de rua que sabe agradar.
- Efeito: `tipValue` $2 nos pedidos que ele entrega. Contrapeso: `tipWindowDelta` −4 s nesses pedidos.
- Brilha: dia (balcão). Δ lucro solo dia 3: +$5 (+6%).
- Critérios de aceite: gorjeta $2 só quando ele faz o "Serve"; janela 16 + 4K − 4 s.

### CLS-006 — "Night Owl"

- Chave `class_night_owl` · Tier 2, 120 · MVP · Fantasia: quem sempre trabalhou de madrugada.
- Efeito: `nightSanityStart` e `nightSanityMax` 120. Contrapeso: `daySpeed` 15.
- Brilha: noite (rua escura, ponto seguro). Δ lucro solo dia 3: −$1 (−1%); à noite +20 de folga ≈ 20 s de escuro ou 4 anomalias vistas.
- Critérios de aceite: noite começa em 120; café não passa de 120; de dia velocidade 15, à noite 16.

### CLS-007 — "Barista"

- Chave `class_barista` · Tier 2, 120 · fora do MVP · Fantasia: anos numa cafeteria 24 h.
- Efeito: cafés feitos por ele — `coffeePrepTime` 3 s, `coffeeRestore` +35 para quem beber. Contrapeso: `seeLoss` −8 para ele.
- Brilha: noite (suporte). Δ lucro: 0.
- Critérios de aceite: o Coffee guarda quem o fez; +35 vale para qualquer jogador que beba esse café.

### CLS-008 — "Shift Lead"

- Chave `class_shift_lead` · Tier 3, 180 · fora do MVP · Fantasia: o funcionário em quem o chefe confia.
- Efeito (party): `partyGradeBonus` +5 p.p. (A 25%, B 15%, C 5%, D 0%), não acumula. Contrapeso: `tipValue` $0 nos pedidos dele.
- Brilha: dia, em party. Δ lucro solo dia 3: −$2 (−2%); party de 4: +$12 (+4–5%).
- Critérios de aceite: 2 Shift Leads na party = +5 p.p., não +10.

---

## Tabela comparável (Δ lucro, dia 3) **[proposals-round-2 §1.4]**

| Classe | Solo | Party de 4 (por classe) | Noite |
|---|---|---|---|
| Rookie | 0 | 0 | 0 |
| Runner | +4% | +1% | −10 sanidade inicial |
| Line Cook | +4% | +2% | igual de dia |
| Hauler | +3–5% | +2% | — |
| Hawker | +6% | +2% | — |
| Night Owl | −1% | 0 | +20 sanidade |
| Barista | 0 | 0 | café do grupo +40% e 2× mais rápido |
| Shift Lead | −2% | +4–5% | — |

Critério de aceite global: simulação solo dia 3 de cada classe dentro de ±12% do Rookie; nenhuma altera verbo, crítica, chances ou −35; nenhuma altera limite de revives, janela de 10 s, prazo de reviver ou tempo no chão do atropelamento.

## Propostas pendentes (classes)

| Tema | Recomendação | Precisa do usuário? |
|---|---|---|
| Classes e reviver/atropelamento | nenhuma classe altera essas regras (tabela de regras gerais) | não (estende a guarda de DEC-069) |
| Sanidade ao reviver por classe | 50% do máximo da classe (Night Owl 60), sem efeito de classe extra | não |
