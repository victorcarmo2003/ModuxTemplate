Status: Aprovado (DEC-068 a DEC-072, rodada 6, 2026-10-08; opções recomendadas; números são valores iniciais ajustáveis em playtest. IDs de classe CLS-001 a CLS-008 em DEC-069. Capacidade do Cream Cheese nos Coolers 2/3 em `Q-062`.)

> **Superado em (anotação de conciliação, 2026-10-08; o conteúdo aprovado abaixo não foi alterado; vale a DEC):**
> - "Convenções", cenário de referência L com "3 chances": **1 chance por run inteira** — DEC-110, DEC-112.
> - Duração das noites "20–30 min": fechada como crescente 20, 21, 22, 23, 24, 26, 27, 28, 29, 30 — DEC-127.

# Propostas do game-designer — rodada 2

Autor: game-designer, 2026-10-08. Base: respostas da rodada 5 do usuário (run longa = cenário L; 10 noites / 10 anomalias;
dinheiro e progressão da party; modo dia infinito sem fim com achievement secreto de 100 dias que dá gemas; gemas off-game
compram classes; monetização adiada; **receitas por combinação livre**).

Cobre: **Q-046** (classes e gemas), **Q-038** (combinação livre: economia e geração de pedido), e de carona **Q-027** (cardápio)
e **Q-020** (variação de pedido). Respeita DEC-001 a DEC-056 e `proposals-round-1.md` (Aprovado).
**Nada aqui é decisão.** Só o usuário aprova; o secretário registra.

Inspiração, não cópia: nomes, números e bônus de classe são originais. Nada de classe, nome ou valor do Animal Hospital
(ver `docs/research/animal-hospital.md`, linha "Não copiar").
Nomes em inglês entre aspas são **placeholders** para o narrative-writer.

Convenções:
- Tudo aqui é **parâmetro de tabela** (data-driven): classes, recompensas de gema, ingredientes, pesos e fases do gerador de pedido.
  Mudar número = mudar a tabela, não o código.
- "Solo mediano" e "lucro líquido" seguem a definição de `proposals-round-1.md` §0.2.
- Cenário de referência: **L** (trailer no dia 5; 10 noites de 20–30 min; ~14 dias jogados; run ~6 h; 3 chances).

---

## 1. Classes (Q-046)

### 1.1 Regras gerais (valem para qualquer opção)

| Regra | Valor proposto | Por quê |
|---|---|---|
| Escolha | no **lobby**, antes da run; travada até o fim da run | sem UI de interação durante o turno (DEC-015) |
| Escopo do efeito | **por jogador**: o bônus vale para as ações **do próprio jogador** (o que ele grelha, entrega, compra, bebe) | não acumula de forma absurda numa party de 4; dinheiro continua da party (DEC-033) |
| Efeitos de party | no máximo 1 classe com efeito de party (Shift Lead); **não acumula** com outra igual | evita "4 do mesmo = +20%" |
| Repetir classe na party | permitido | todo efeito é pessoal, então repetir não quebra nada |
| Teto de poder | nenhuma classe muda o lucro/min de um solo em mais de **±12%**; nenhuma classe mexe nas **regras das anomalias** (verbo correto, regra crítica, chances) | o terror não se compra; classe é sabor, não atalho |
| Contrapeso | toda classe paga tem um contrapeso leve, em outro eixo | escolha, não upgrade puro |
| Classe inicial | **Rookie**, grátis, neutra (sem bônus, sem contrapeso) | é a régua: o balanceamento base (§3) é feito com ela |
| Obtenção | toda classe é comprável **só com gemas ganhas jogando** no MVP | monetização adiada (Q-017); ver 1.6 |

### 1.2 Opções

| Opção | O que é | Prós | Contras | Escopo |
|---|---|---|---|---|
| **A. 8 classes leves com contrapeso** | bônus de ~10–25% num eixo, contrapeso leve noutro; papéis que se complementam na party | atende as ideias do usuário (agilidade, cozinhar, rendimento, dinheiro, sanidade); co-op ganha papéis sem obrigar funções (Q-030); risco de pay-to-win baixo se um dia gemas forem vendidas | 8 ícones/descrições; precisa de teste de balanceamento por classe | 1 tabela de classes + ~6 ganchos de efeito no código (velocidade, tempo da grelha, gorjeta, café, sanidade, pacotes) |
| B. 5 classes de um eixo, sem contrapeso | uma por ideia do usuário, bônus puro | simples de explicar | toda classe paga é estritamente melhor que a grátis; pay-to-win se gemas forem vendidas | menor |
| C. Classes como funções fortes | Cook / Cashier / Stocker / Watcher com bônus de ~30% | identidade forte no co-op | solo fica fraco com qualquer escolha; vantagem grande demais; conflita com "todo mundo faz tudo" sugerido em Q-030 | médio, mais balanceamento |

**Recomendação: A.**

### 1.3 As 8 classes (opção A)

ID provisório = chave da tabela (`class_*`). Sugestão ao secretário: prefixo `CLS-###` para classes, se o usuário quiser IDs estáveis
(não está na tabela de prefixos do `CLAUDE.md`).

| Chave | Nome (placeholder) | Fantasia | Bônus | Contrapeso leve | Turno onde brilha | Papel na party |
|---|---|---|---|---|---|---|
| `class_rookie` | "Rookie" | primeiro dia de trabalho | — | — | — | qualquer |
| `class_runner` | "Runner" | entregador de bicicleta que virou atendente | velocidade de andar **16 → 18** (+12,5%) | começa a noite com sanidade **90** (máx. 100) | dia | mercado e reposição |
| `class_line_cook` | "Line Cook" | ex-cozinheiro de lanchonete de estrada | salsichas que **ele** põe na grelha ficam prontas **15% mais rápido** (12 s → 10,2 s no nível 1; vale sobre o tempo do upgrade) | velocidade **16 → 15** | dia e noite | grelha |
| `class_hauler` | "Hauler" | estoquista do mercado da esquina | carrega **3 pacotes** em vez de 2 (DEC-049) | com 3 pacotes na mão, velocidade **16 → 14** | dia | estoque |
| `class_hawker` | "Hawker" | vendedor de rua que sabe agradar | gorjeta dos pedidos que **ele entrega** = **$2** (em vez de $1) | a janela de gorjeta dos pedidos dele é **4 s menor** (§3.6) | dia | balcão |
| `class_night_owl` | "Night Owl" | quem sempre trabalhou de madrugada | sanidade inicial e máxima **120** | de dia, velocidade **16 → 15** (sono) | noite | ponto seguro, rua escura |
| `class_barista` | "Barista" | trabalhou anos numa cafeteria 24 h | café que **ele prepara**: preparo **6 s → 3 s** e recupera **+35** (em vez de +25) de quem beber | "ver anomalia" tira **−8** dele (em vez de −5) — nervoso de tanto café | noite | suporte |
| `class_shift_lead` | "Shift Lead" | o funcionário em quem o chefe confia | **party**: bônus do chefe pela nota +5 p.p. (A 25%, B 15%, C 5%, D 0%); não acumula | pedidos entregues **por ele** não dão gorjeta | dia (party) | coordenação |

Reserva para depois do MVP (mesmo formato): "Lookout" (zona anti-ladrão de raio 22 para ele; ver anomalia −2), "Bargain Hunter" (pacote −$1 quando ele compra; compra com hold 2 s).

### 1.4 Impacto estimado (comparável)

Base: Rookie solo, dia 3, lucro líquido $82 (§3.7). Números de simulação de mesa; validar em playtest.

| Classe | Δ lucro/dia solo (dia 3) | Δ lucro/dia party de 4 (por classe) | Efeito à noite | Comentário |
|---|---|---|---|---|
| Rookie | 0 | 0 | 0 | régua |
| Runner | +$3 (+4%) | +1% | −10 sanidade inicial | ida ao mercado 25 s → ~22 s |
| Line Cook | +$3 (+4%) | +2% | igual de dia | mais pedidos dentro da janela de gorjeta |
| Hauler | +$2 a +$4 (+3–5%) | +2% | — | cresce com Cooler 2–3 (menos viagens) |
| Hawker | +$5 (+6%) | +2% | — | gorjeta dobrada menos a janela menor |
| Night Owl | −$1 (−1%) | 0 | +20 sanidade ≈ 20 s de escuro ou 4 anomalias vistas | classe de noite |
| Barista | 0 | 0 | café do grupo +40% e 2× mais rápido | só rende com outros bebendo; solo serve a si mesmo |
| Shift Lead | −$2 (−2%) | +$12 (+4–5% da party) | — | **classe de party**: ruim solo de propósito |

Nenhuma passa de +12% solo. Melhor para solo: Hawker; melhor para party: Shift Lead + Barista à noite. Isso dá motivo para variar.

### 1.5 Classes no MVP

| Opção | No MVP | Prós | Contras |
|---|---|---|---|
| A. Nenhuma (gemas acumulam, loja abre depois) | 0 | escopo mínimo | gema sem uso no lançamento: recompensa vazia |
| **B. Rookie + 3** | Rookie, Runner, Line Cook, Night Owl | cobre as 3 ideias mais claras do usuário (agilidade, cozinhar, sanidade), uma de dia, uma de cozinha, uma de noite; efeitos são os mais baratos de implementar (WalkSpeed, multiplicador de timer, sanidade máx.) | Hawker e Shift Lead ("mais dinheiro") ficam para a 1ª atualização |
| C. Todas as 8 | 8 | conteúdo de longo prazo desde o dia 1 | mais teste; Barista e Shift Lead dependem de party para fazer sentido |

**Recomendação: B.** Se sobrar folga no plano de tarefas, Hawker é o 5º (efeito de 1 linha de tabela).

### 1.6 Guarda contra pay-to-win (para quando Q-017 voltar)

Não é decisão agora; é limite de design que esta proposta respeita:
- toda classe continua comprável com gemas de jogo, sempre;
- teto de ±12% (1.1) e "classe nunca toca regra de anomalia" ficam como critério fixo de qualquer classe nova;
- se gemas um dia forem vendidas, o ganho máximo de quem paga é **antecipar** uma classe que dá no máximo +12%, nunca uma que só exista paga.
Sugestão para a rodada de monetização: vender **cosmético** (uniforme, boné, cor do carrinho), não classe.

### 1.7 Critérios de aceite (classes)

- O lobby mostra as classes com nome, bônus e contrapeso em uma linha cada; a escolha fica travada ao entrar na run.
- Todo jogador novo tem Rookie desbloqueado e selecionado.
- Os efeitos vêm de uma tabela de classes; adicionar uma classe nova com efeitos já existentes não exige código novo.
- Com 2 Shift Leads na party, o bônus do chefe sobe +5 p.p., não +10.
- O tempo de grelha do Line Cook aparece na barra de progresso da salsicha que ele colocou (e só nela).
- Nenhuma classe altera verbo correto, regra crítica, chances do chefe ou dano de sanidade de "quebrar regra" (−35).
- Simulação de 1 jogador, dia 3, com cada classe: lucro líquido entre −12% e +12% do Rookie.

---

## 2. Gemas (Q-046)

### 2.1 Regras gerais

| Regra | Valor proposto |
|---|---|
| Dono | **por jogador**, persistido entre sessões (único dado persistido além das classes, DEC-035) |
| Party | todo jogador da party recebe **o mesmo valor** pelo mesmo evento; tamanho da party não muda a recompensa |
| Jogador fora (sanidade 0) | recebe as gemas da noite se a party vence (co-op não pune quem caiu) |
| Quando credita | **no fim de cada turno** (tela de resumo), e salva na hora; sair da run depois não tira o que já foi creditado |
| Noite repetida (chance gasta) | a noite perdida não dá gema; a mesma noite vencida depois dá o valor normal, uma vez |
| Moeda única | gemas; sem segunda moeda off-game |

### 2.2 Opções de fonte

| Opção | Fontes | Prós | Contras |
|---|---|---|---|
| A. Só noites + final | noite vencida, fim da run | foca no terror | modo dia infinito não dá gema (usuário disse que dá) |
| **B. Noite + dia + final + achievement** | tabela 2.3 | atende tudo que o usuário disse; terror rende ~2,5× mais por hora que o dia infinito | um número a mais para balancear |
| C. Por desempenho | gemas por nota A–D e por cliente | recompensa habilidade | farm de dia infinito com nota A; complica a tela de resumo |

**Recomendação: B.**

### 2.3 Tabela de recompensas (opção B)

| Evento | Gemas | Observação |
|---|---|---|
| Turno de dia concluído (qualquer modo) | **2** | inclui dias da run e do modo dia infinito |
| Nota **A** no turno de dia | **+1** | usa a nota de DEC-051 |
| Noite N vencida (N = 1..10) | **15 + 2 × (N − 1)** → 15, 17, 19 … 33 | soma das 10 = **240** |
| Fim da run com a 10ª noite vencida (final) | **+100** | só uma vez por run |
| Achievement secreto "Day 100" (contador "Day N" chega a 100 numa run) | **+300**, uma vez por conta | também vira badge do Roblox; nome final com o narrative-writer |
| Fim da run por falta de chances | 0 extra | fica o que já foi creditado por turno |

### 2.4 Ritmo esperado (jogador mediano, cenário L)

| Momento | Tempo jogado (aprox.) | Gemas acumuladas | Compra possível |
|---|---|---|---|
| Fim do dia 5 (trailer) | ~38 min | ~12 | — |
| Fim da noite 2 | ~95 min | ~47 | **1ª classe paga (tier 1)** |
| Fim da noite 5 | ~3 h | ~120 | tier 2 ou mais 2 de tier 1 |
| Run completa (10 noites + final) | ~6 h | ~375 | ~3 classes |
| Dia infinito | — | ~24 por hora (3 por dia de ~7,5 min com nota A) | — |
| Run interrompida na noite 6 (caso típico de falha) | ~3,5 h | ~145 | — |

Ritmo da run: ~60 gemas/h. Dia infinito: ~24/h. O terror paga mais; o dia infinito nunca é zero.

### 2.5 Preço das classes

| Tier | Gemas | Classes | Alvo |
|---|---|---|---|
| 0 | grátis | Rookie | — |
| 1 | **45** | Runner, Line Cook, Hauler | 2ª classe após **~1h30** (fim da noite 2 da primeira run) |
| 2 | **120** | Night Owl, Hawker, Barista | ~3 h, ou na primeira run completa |
| 3 | **180** | Shift Lead | segunda run |

Todas as 7 pagas: 3 × 45 + 3 × 120 + 180 = **675 gemas ≈ 1,8 run completa (~11 h)**.
MVP (opção 1.5 B): Runner 45 + Line Cook 45 + Night Owl 120 = **210 gemas**, cabem numa run completa.
O achievement de 100 dias (~12 h de dia infinito, depende da reconexão de Q-048) paga quase metade da coleção: recompensa de quem persiste, rara de propósito.

### 2.6 Critérios de aceite (gemas)

- Ao fim de cada turno, a tela de resumo mostra as gemas ganhas no turno e o total; o total persiste mesmo se o jogador sair em seguida.
- Todos os jogadores da party recebem o mesmo valor pelo mesmo turno, inclusive quem estava fora.
- Perder uma noite não credita gemas daquela tentativa; vencê-la depois credita uma vez só.
- A soma das gemas de uma run perfeita (14 dias com nota A + 10 noites + final) é exatamente 42 + 240 + 100 = **382**.
- O achievement "Day 100" credita 300 gemas uma única vez por conta.
- Comprar classe sem saldo não é possível; o preço vem da tabela de classes.

---

## 3. Economia para combinação livre (Q-038; revisa §0.2 de `proposals-round-1.md`)

### 3.1 Ingredientes no MVP

Base de todo pedido: **pão + salsicha** (sempre). O pedido varia nos **complementos**.

| Opção | Complementos no MVP | Combinações possíveis (até 3 complementos) | Prós | Contras |
|---|---|---|---|---|
| A. 4 | ketchup, mustard, cheese, bacon | 15 | mesmos assets e pacotes já aprovados (DEC-049) | pouca variedade para 14 dias + dia infinito |
| **B. 6** | A + **Potato Sticks** (dia 4) + **Cream Cheese** (dia 6) | 42 | novidade antes do trailer e logo depois dele; ingredientes vieram da lista do usuário (DEC-017, Q-041: nome genérico) | +2 pacotes, +2 estações, +2 assets |
| C. 8 | B + Chili + Boiled Egg | 93 | mais variedade | chili pede panela aquecida (estação nova com timer); escopo de arte e tarefa maior |

**Recomendação: B.** Chili, ovo, purê, uva passa, cheddar ficam para atualizações.

### 3.2 Preço por pedido: opções

| Opção | Regra | Prós | Contras |
|---|---|---|---|
| **A. Base + preço por complemento** | preço = $4 + soma dos complementos | mantém exatamente os preços aprovados (Classic $5, Cheese $7, Bacon $8 viram combinações); ingrediente caro vale mais | jogador precisa intuir o valor (não precisa calcular: o pagamento é automático) |
| B. Preço por quantidade de complementos | 0 = $4, 1 = $5, 2 = $7, 3 = $9 | simples | bacon e ketchup valem igual: compra de ingrediente caro perde sentido (fere GERENCIAR) |
| C. Jogador define preço | — | — | exige UI de interação (fere DEC-015) |

**Recomendação: A.**

### 3.3 Tabela de ingredientes (opção A + 3.1 B)

| Ingrediente (placeholder) | Tipo | Pacote no mercado | Custo por uso | Preço no pedido | Margem | Libera | Peso no sorteio | Cap. nível 1 |
|---|---|---|---|---|---|---|---|---|
| Bun | base | 8 / $4 | $0,50 | base $4 (pão + salsicha) | $2,75 | dia 1 | — | 12 |
| Sausage | base | 8 / $6 | $0,75 | (na base) | — | dia 1 | — | 12 |
| Ketchup | molho | 20 usos / $4 | $0,20 | +$1 | $0,80 | dia 1 | 10 | 30 usos |
| Mustard | molho | 20 usos / $4 | $0,20 | +$1 | $0,80 | dia 1 | 10 | 30 usos |
| Cheese | cobertura | 6 / $6 | $1,00 | +$2 | $1,00 | dia 2 | 7 | 8 |
| Bacon | cobertura | 6 / $9 | $1,50 | +$3 | $1,50 | dia 3 | 6 | 8 |
| Potato Sticks | cobertura | 10 usos / $5 | $0,50 | +$2 | $1,50 | dia 4 | 6 | 15 usos |
| Cream Cheese | cobertura | 8 usos / $6 | $0,75 | +$2 | $1,25 | dia 6 | 5 | 12 usos |

Conferência com DEC-045 (os pedidos antigos continuam com o mesmo preço e custo):
- pão + salsicha + ketchup = $5, custo $1,45 (= "Classic");
- + cheese = $7, custo $2,45 (= "Cheese");
- pão + salsicha + bacon + mustard = $8, custo $2,95 (= "Bacon").

Cooler 2 e 3 (DEC-046) aumentam as capacidades na mesma proporção: unidades 12 → 20 → 30; coberturas em unidade 8 → 14 → 20; coberturas em uso (Potato Sticks, Cream Cheese) 15 → 25 → 35.

Desbloqueio: **automático por dia** (vale no carrinho e no trailer, e no modo dia infinito). No dia em que libera, o chefe deixa **1 pacote grátis** na estação nova (o jogador nunca recebe pedido de algo que nunca teve chance de estocar).
Os nomes "Classic / Cheese / Bacon" saem do sistema como receitas fixas; podem voltar só como apelido falado pelo cliente (narrative-writer).

### 3.4 Como o NPC gera o pedido

| Opção | Regra | Prós | Contras |
|---|---|---|---|
| A. Uniforme | K complementos sorteados com chance igual | simples | molho barato e bacon caem igual; ingrediente novo some no meio |
| **B. K por fase + pesos por ingrediente** | sorteia K pela tabela da fase; depois K complementos **distintos** por peso | dificuldade cresce com a run; o novo aparece; molhos comuns criam o "padrão" que a noite quebra (DEC-010) | duas tabelas para ajustar |
| C. B + preferência por tipo de cliente | cada tipo de NPC multiplica pesos (ex.: um tipo nunca pede molho) | dá personalidade e pista de padrão para anomalia | depende das fichas de NPC (`npcs.md`) |

**Recomendação: B agora, com o campo de multiplicador por tipo de cliente já previsto na tabela (vira C quando `npcs.md` existir).**

Número de complementos K por fase (%):

| Fase | K = 0 | K = 1 | K = 2 | K = 3 | K médio |
|---|---|---|---|---|---|
| Dia 1 | 10 | 60 | 30 | 0 | 1,2 |
| Dias 2–3 | 5 | 45 | 40 | 10 | 1,55 |
| Dias 4–5 | 5 | 35 | 40 | 20 | 1,75 |
| Dia 6 em diante (inclui dia infinito) | 0 | 30 | 40 | 30 | 2,0 |
| Noites | 0 | 30 | 40 | 30 | 2,0 |

Regras do sorteio:
- Máximo **3 complementos** por pedido (legível no balão do cliente no celular).
- Ingrediente liberado **hoje** tem peso ×1,5 no dia da liberação.
- Só entra ingrediente já liberado. Se K for maior que o número de liberados, K = número de liberados.
- O pedido aparece no **balão sobre o cliente**, com ícones (DEC-015: feedback no mundo).
- Cardápio (Q-027): o cliente pede **qualquer combinação dos liberados**; o jogador não escolhe cardápio. Variações tipo "sem ketchup" (Q-020) não existem: o pedido já é a lista exata.

### 3.5 Pedido certo, incompleto e errado (adapta DEC-051 à combinação livre)

| Situação | Definição | Pagamento | Gorjeta |
|---|---|---|---|
| Completo | pão + salsicha + **exatamente** os complementos pedidos | 100% | +$1 se dentro da janela (3.6) |
| Incompleto | falta 1 ou mais complementos pedidos e **não há** complemento a mais | 50% do preço do pedido, arredondado para baixo ($5 → $2; $7 → $3) | — |
| Errado | tem complemento que **não foi pedido**, ou falta pão/salsicha | 0%, devolve e vai embora | — |
| Desistiu | paciência acabou | 0% | — |

Ponto para o usuário confirmar: o "exatamente 50%" de DEC-051 vira "50% arredondado para baixo" porque o dinheiro é inteiro. Alternativa: dinheiro com centavos ($2,50). Recomendo inteiro (HUD mais limpo para criança; o ladrão já usa floor).

### 3.6 Gorjeta e paciência por tamanho do pedido

Os valores aprovados (gorjeta em até 20 s, paciência 45 s) passam a ser o caso K = 1; pedido maior dá mais tempo.

| K | Janela de gorjeta (16 + 4 × K s) | Paciência no balcão (40 + 5 × K s) |
|---|---|---|
| 0 | 16 s | 40 s |
| 1 | **20 s** (= DEC-045) | **45 s** (= DEC-045) |
| 2 | 24 s | 50 s |
| 3 | 28 s | 55 s |

Counter 2/3 (DEC-046) continuam somando +10 s / +20 s de paciência. Hawker: janela −4 s nos pedidos dele. Gorjeta segue **$1** fixa (Hawker $2).
Tempo de montagem de referência: cada complemento é um prompt de **1 s** (hold). Pedido K = 3 com salsicha já pronta ≈ 2 s (pão) + 1 s (salsicha no pão) + 3 s + entrega ≈ 8–10 s.

### 3.7 Lucro esperado revisado (solo mediano, Rookie; substitui a tabela de §0.2)

Mesmo fluxo de clientes e mesmos atendidos por dia de DEC-045. Valores médios do sorteio (aproximação analítica; a simulação manda).

| Dia | Liberados | K médio | Preço médio | Custo médio | Margem + gorjeta | Atendidos | Lucro líquido | Acumulado | §0.2 antigo |
|---|---|---|---|---|---|---|---|---|---|
| 1 | K, M | 1,2 | $5,20 | $1,49 | $4,31 | 13 | $56 | $56 | $53 |
| 2 | + Cheese | 1,55 | $6,08 | $1,98 | $4,65 | 15 | $70 | $126 | $121 |
| 3 | + Bacon | 1,55 | $6,63 | $2,31 | $4,82 | 17 | $82 | $208 | $203 |
| 4 | + Potato Sticks | 1,75 | $6,92 | $2,27 | $5,15 | 18 | $93 | $301 | $291 |
| 5 | — | 1,75 | $6,87 | $2,28 | $5,09 | 19 | $97 | $398 | $386 |
| 6+ | + Cream Cheese | 2,0 | $7,36 | $2,46 | $5,35 | ~20 | ~$107 | — | — |

Compatibilidade com o aprovado:
- Trailer **$300 solo** (DEC-047) = 0,75 × acumulado até o dia 5 ($398). A regra "≈ 0,8 × acumulado" continua valendo (diferença de 3%); **preço do trailer não muda**.
- Party: multiplicadores de fluxo e de preço do trailer (DEC-045, DEC-047) não mudam.
- Ladrão, gaveta, nota A–D, Cash Drawer Lock: não mudam (dependem do valor da gaveta, não da receita).
- Custo de estoque sobe ~10% nos dias 4–5 (mais complementos por pedido): reforça a decisão "compro ou guardo" (GERENCIAR, DEC-017) sem quebrar a meta.

Lucro/min de referência (dia 3, solo): $82 / 6 min ≈ **$13,7/min** (igual ao aprovado; tabelas de upgrade de §0.3 continuam válidas).

### 3.8 Tabelas data-driven envolvidas

| Tabela | Campos principais |
|---|---|
| Ingredients | id, nome, tipo (base/molho/cobertura), pacote (qtd, preço), preço no pedido, dia de liberação, peso, capacidade por nível de Cooler, ícone |
| OrderPhases | faixa de dias/noite, distribuição de K, máximo de complementos |
| OrderRules | janela de gorjeta (16 + 4K), paciência (40 + 5K), % incompleto (50, floor), gorjeta ($1) |
| CustomerTypes (futuro) | multiplicador de peso por ingrediente |
| Classes | id, nome, tier/preço em gemas, lista de efeitos (tipo, valor, escopo pessoal/party, acumula?) |
| GemRewards | evento, valor, fórmula (noite N) |

### 3.9 Critérios de aceite (economia de combinação livre)

- Nenhum pedido contém ingrediente ainda não liberado, nem mais de 3 complementos, nem complemento repetido.
- O preço pago por um pedido completo é exatamente $4 + soma dos complementos da tabela.
- Os pedidos "pão + salsicha + ketchup", "+ cheese" e "bacon + mustard" custam $5, $7 e $8.
- Entregar com complemento a mais paga $0; com complemento faltando (e nada a mais) paga floor(50%).
- No dia de liberação de um ingrediente, a estação nova começa com 1 pacote grátis.
- Em 1.000 pedidos simulados por fase, a distribuição de K fica a ±3 p.p. da tabela.
- Simulação de 1 jogador Rookie (dias 1–5) fecha o acumulado entre $360 e $420; o trailer ($300) é comprável até o fim do dia 5 gastando $110 em upgrades (mesmo critério de DEC-047).
- Gorjeta e paciência variam com K conforme 3.6; para K = 1 são 20 s e 45 s.

---

## 4. Resumo das recomendações

| Tema | Recomendação | Números-chave |
|---|---|---|
| Classes | 8 classes leves com contrapeso; efeito pessoal; teto ±12% solo; nunca tocam regra de anomalia | Rookie grátis; Runner, Line Cook, Hauler, Hawker, Night Owl, Barista, Shift Lead |
| Classes no MVP | Rookie + Runner + Line Cook + Night Owl | 210 gemas para as 3 pagas |
| Gemas | dia 2 (+1 nota A); noite N 15 + 2(N−1); final +100; Day 100 +300; por jogador, igual na party, creditadas por turno | run completa ~375; ~60/h na run, ~24/h no dia infinito |
| Preço das classes | 45 / 120 / 180 por tier | 2ª classe ~1h30; coleção ~11 h |
| Ingredientes MVP | 6 complementos (+ Potato Sticks dia 4, Cream Cheese dia 6) | liberação automática + 1 pacote grátis |
| Preço do pedido | $4 base + complemento (molho $1, queijo $2, bacon $3, Potato Sticks $2, Cream Cheese $2) | preços antigos preservados |
| Geração de pedido | K por fase + pesos; máx. 3 complementos | K médio 1,2 → 2,0 |
| Gorjeta / paciência | $1; janela 16 + 4K s; paciência 40 + 5K s | K = 1 igual ao aprovado |

## 5. Pontos para o usuário (curtos)

1. Classes dão **vantagem pequena** (até ±12%) e não mexem nas regras do terror. Ok?
2. Ingrediente **a mais** no pedido = pedido errado (paga $0); **faltando** = 50% arredondado para baixo. Ok?
3. Quais classes no lançamento: recomendação Rookie + Runner + Line Cook + Night Owl.
