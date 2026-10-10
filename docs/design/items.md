Status: Rascunho

# Itens, ingredientes e pacotes (ITM-###)

Autor: game-designer, 2026-10-08 (conciliado até a rodada 15). Fontes: **[DEC-016, DEC-040, DEC-042, DEC-049, DEC-055, DEC-064, DEC-071, DEC-072, DEC-092, DEC-100, DEC-103, DEC-106, DEC-108, DEC-109, DEC-116, DEC-121, DEC-125, DEC-128, DEC-129]**,
`proposals-round-2.md` §3 (Aprovado). Não há receitas fixas: todo pedido é pão + salsicha + até 3 complementos **[DEC-064, DEC-071]**.
Rodada 12: frutas/verduras do Mart são **só cenário** — nenhum ITM novo de ingrediente **[DEC-109]**. Item novo: **ITM-021 Rescue Whistle** (DEC-100, DEC-108; chamado "Revive Kit" em DEC-129).
Rodadas 13–15: validade não existe no MVP (DEC-128); cafeteira fixa no trailer (DEC-125); chance e preço do ITM-021 decididos (DEC-129).
Anomalias citadas por `ANM-###` (DEC-096). Tool derrubada no chão: FEAT-036.
Nomes em inglês são placeholders (DEC-022; nome genérico, sem marca — DEC-071). Ícones e modelos: AST com o art-director.
Números são valores de tabela (`Ingredients`, `Packages`), ajustáveis em playtest.

## Template de ficha

```
### ITM-### — Nome
Tipo · É Tool? · Status · Origem
Tabela: estados, estação, custo, preço no pedido, liberação, peso, capacidade
Critérios de aceite
```

## Índice

| ID | Item | Tipo | Tool? |
|---|---|---|---|
| ITM-001 | Bun | base | não (estoque) |
| ITM-002 | Sausage | base | não (estoque) |
| ITM-003 | Ketchup | complemento (molho) | não |
| ITM-004 | Mustard | complemento (molho) | não |
| ITM-005 | Cheese | complemento (cobertura) | não |
| ITM-006 | Bacon | complemento (cobertura) | não |
| ITM-007 | Potato Sticks | complemento (cobertura) | não |
| ITM-008 | Cream Cheese | complemento (cobertura) | não |
| ITM-009 | Coffee | consumível noturno | **sim** |
| ITM-010 | Hot Dog (montado) | produto | **sim** |
| ITM-011 | Sausages pack | pacote | **sim** |
| ITM-012 | Buns pack | pacote | **sim** |
| ITM-013 | Ketchup pack | pacote | **sim** |
| ITM-014 | Mustard pack | pacote | **sim** |
| ITM-015 | Cheese pack | pacote | **sim** |
| ITM-016 | Bacon pack | pacote | **sim** |
| ITM-017 | Potato Sticks pack | pacote | **sim** |
| ITM-018 | Cream Cheese pack | pacote | **sim** |
| ITM-019 | Coffee pack | pacote | **sim** |
| ITM-020 | Altered item (ANM-002 The wrong food) | item de anomalia | **sim** |
| ITM-021 | Rescue Whistle (chave `revive_kit`) | especial (reviver) | **sim** |

## Tabela-mestra de ingredientes (`Ingredients`)

| ID | Ingrediente | Pacote | Custo por uso | Preço no pedido | Margem | Libera | Peso no sorteio | Cap. Cooler 1 / 2 / 3 |
|---|---|---|---|---|---|---|---|---|
| ITM-001 | Bun | ITM-012 | $0,50 | base $4 (com a salsicha) | — | Day 1 | — (sempre) | 12 / 20 / 30 |
| ITM-002 | Sausage | ITM-011 | $0,75 | (na base) | base: $2,75 | Day 1 | — (sempre) | 12 / 20 / 30 |
| ITM-003 | Ketchup | ITM-013 | $0,20 | +$1 | $0,80 | Day 1 | 10 | 30 / 50* / 75* |
| ITM-004 | Mustard | ITM-014 | $0,20 | +$1 | $0,80 | Day 1 | 10 | 30 / 50* / 75* |
| ITM-005 | Cheese | ITM-015 | $1,00 | +$2 | $1,00 | Day 2 | 7 | 8 / 14 / 20 |
| ITM-006 | Bacon | ITM-016 | $1,50 | +$3 | $1,50 | Day 3 | 6 | 8 / 14 / 20 |
| ITM-007 | Potato Sticks | ITM-017 | $0,50 | +$2 | $1,50 | Day 4 | 6 | 15 / 25 / 35 |
| ITM-008 | Cream Cheese | ITM-018 | $0,75 | +$2 | $1,25 | Day 6 | 5 | 12 / 20* / 30* |

`*` = número proposto nesta ficha (não estava nas DECs): molhos seguem a proporção do Cooler (×5/3, ×2,5); Cream Cheese idem (resposta proposta para **Q-062**).
Fonte dos demais: DEC-049, DEC-071.

Leitura de margem por complemento (o que o jogador "ganha" ao ter o ingrediente): Bacon $1,50 > Potato Sticks $1,50 > Cream Cheese $1,25 > Cheese $1,00 > molhos $0,80.
Potato Sticks tem a melhor margem por dólar de estoque (300%); Bacon a maior margem absoluta, mas pacote mais caro ($9) — decisão de GERENCIAR.

---

## Base

### ITM-001 — Bun

- Tipo: base · Tool: não · Origem: **[DEC-016, DEC-049, DEC-071]**

| Campo | Valor |
|---|---|
| Estação | caixa de pão (FEAT-006); hold 0,5 s "Slice Bun" → tábua; corte automático 1,5 s |
| Estados | no estoque → na tábua (inteiro) → cortado → dentro do Hot Dog |
| Custo por uso | $0,50 (pacote ITM-012) |
| Capacidade | 12 / 20 / 30 |
| Libera | Day 1; run começa com 12 |

- Critérios de aceite: "Slice Bun" consome 1 e só aparece com tábua livre; a tábua cortada aceita exatamente 1 salsicha.

### ITM-002 — Sausage

- Tipo: base · Tool: não · Origem: **[DEC-016, DEC-046, DEC-049, DEC-071]**

| Campo | Valor |
|---|---|
| Estação | caixa de salsicha → grelha → trilho de descanso (FEAT-006) |
| Estados | crua (estoque) → grelhando (barra) → pronta (na grelha) → descansando (trilho) → no pão |
| Tempo de grelha | 12 s / 10 s / 8 s (UPG-001 níveis 1–3); Line Cook ×0,85 |
| Queima | não no MVP |
| Custo por uso | $0,75 (pacote ITM-011) |
| Capacidade | 12 / 20 / 30; trilho 6 (carrinho) / 8 (trailer) |
| Libera | Day 1; run começa com 12 |

- Critérios de aceite: salsicha pronta não muda de estado sozinha; trilho cheio bloqueia "Collect" na grelha.

## Complementos

Comum aos ITM-003 a ITM-008: aplicado com Hot Dog na mão, hold 1 s na estação do complemento **[DEC-072]**; 1 uso por Hot Dog;
não repete; aparece no modelo do Hot Dog e como ícone no balão do pedido; no dia em que libera, a estação começa com 1 pacote grátis **[DEC-071]**.

### ITM-003 — Ketchup

- Molho · preço +$1 · custo $0,20 · Day 1 · peso 10 · cap. 30 / 50 / 75 usos · pacote ITM-013. Origem **[DEC-049, DEC-071]**.

### ITM-004 — Mustard

- Molho · preço +$1 · custo $0,20 · Day 1 · peso 10 · cap. 30 / 50 / 75 usos · pacote ITM-014. Origem **[DEC-049, DEC-071]**.

### ITM-005 — Cheese

- Cobertura · preço +$2 · custo $1,00 · Day 2 · peso 7 · cap. 8 / 14 / 20 un. · pacote ITM-015. Origem **[DEC-049, DEC-071]**.

### ITM-006 — Bacon

- Cobertura · preço +$3 · custo $1,50 · Day 3 · peso 6 · cap. 8 / 14 / 20 un. · pacote ITM-016. Origem **[DEC-049, DEC-071]**.
- Nota: já vem pronto (sem estação de fritura no MVP).

### ITM-007 — Potato Sticks

- Cobertura · preço +$2 · custo $0,50 · Day 4 · peso 6 · cap. 15 / 25 / 35 usos · pacote ITM-017. Origem **[DEC-071]**.

### ITM-008 — Cream Cheese

- Cobertura · preço +$2 · custo $0,75 · Day 6 · peso 5 · cap. 12 / 20* / 30* usos · pacote ITM-018. Origem **[DEC-071]**; níveis 2/3 propostos (**Q-062**).
- Nota: libera no Day 6, primeiro dia depois da Night 1 numa run com trailer no Day 5 (novidade logo após a virada).

- Critérios de aceite (todos os complementos):
  - "Add X" só aparece com Hot Dog na mão, sem X, e estoque de X ≥ 1.
  - Ingrediente não liberado não tem estação ativa nem aparece em pedido.
  - No dia da liberação a estação tem exatamente 1 pacote grátis.

## Produto

### ITM-010 — Hot Dog (montado)

- Tipo: produto · Tool: sim · Origem: **[DEC-016, DEC-040, DEC-071, DEC-072]**

| Campo | Valor |
|---|---|
| Nasce | toque "Add Sausage" na tábua com pão cortado e trilho com salsicha (FEAT-006) |
| Conteúdo | pão + salsicha + lista de complementos (0–6 possíveis; o pedido usa até 3) |
| Máx. na hotbar | 2 por jogador (FEAT-005) |
| Uso | "Serve" no cliente com pedido anotado; "Throw Away" na lixeira |
| Alterado (N2) | se montado com salsicha ou pão alterado (ITM-020), o Hot Dog guarda a flag `altered` e mostra o sinal na mão (salsicha cinza-azulada / meia-lua de mordida) |
| Errado devolvido | volta para a mão de quem serviu (FEAT-011) |
| Derrubado (atropelamento) | perdido, "splat" cômico, some em 2 s (FEAT-036) |
| Validade | não estraga no MVP **[DEC-128]** |
| Valor | $4 + Σ complementos se completo **[DEC-071]** |

- Critérios de aceite: o modelo na mão mostra todos os complementos; o servidor guarda a lista (o client não decide o conteúdo).

## Consumível noturno

### ITM-009 — Coffee

- Tipo: consumível · Tool: sim · Origem: **[DEC-042, DEC-055, DEC-069]**

| Campo | Valor |
|---|---|
| Onde | cafeteira do trailer (UPG-007); hold 1 s; preparo 6 s (Barista 3 s); consome 1 dose |
| Efeito | +25 sanidade ao beber (+35 se feito por Barista) |
| Cooldown | 60 s por jogador, a partir do gole |
| Estoque | doses na cafeteira: começa com 10 ao comprar o trailer; capacidade 20 (proposta) |
| Máx. na hotbar | 1 |
| Entregar | prompt "Give" no colega, hold 0,5 s |
| Custo | $0,50 por dose (pacote ITM-019) |
| De dia | pode ser preparado, mas não tem efeito (sanidade não existe de dia) — prompt de beber some de dia |
| Derrubado (atropelamento) | derrama e some em 2 s; dose perdida (FEAT-036) |
| Cafeteira | **fixa no trailer**, não é comprada na bancada **[DEC-055, DEC-125]** |

- Critérios de aceite: os de `proposals-round-1.md` Q-014; cafeteira sem dose não prepara.

## Pacotes do mercado (`Packages`)

Comum: comprado no Ninth Street Mart (FEAT-008) com hold 0,5 s; vira Tool com contador; "Restock" (hold 1 s) na estação transfere até a capacidade;
sobra fica no pacote; pacote vazio some; máx. 2 por jogador (Hauler 3) **[DEC-049, DEC-069]**.

| ID | Pacote | Conteúdo | Preço | Custo por uso | Libera no mercado | Origem |
|---|---|---|---|---|---|---|
| ITM-011 | Sausages | 8 un. | $6 | $0,75 | Day 1 | DEC-049 |
| ITM-012 | Buns | 8 un. | $4 | $0,50 | Day 1 | DEC-049 |
| ITM-013 | Ketchup | 20 usos | $4 | $0,20 | Day 1 | DEC-049 |
| ITM-014 | Mustard | 20 usos | $4 | $0,20 | Day 1 | DEC-049 |
| ITM-015 | Cheese | 6 un. | $6 | $1,00 | Day 2 | DEC-049 |
| ITM-016 | Bacon | 6 un. | $9 | $1,50 | Day 3 | DEC-049 |
| ITM-017 | Potato Sticks | 10 usos | $5 | $0,50 | Day 4 | DEC-071 |
| ITM-018 | Cream Cheese | 8 usos | $6 | $0,75 | Day 6 | DEC-071 |
| ITM-019 | Coffee | 10 doses | $5 | $0,50 | após comprar o trailer | DEC-049, DEC-055 |

Prateleiras **não** rotacionam: todos os pacotes liberados estão sempre à venda pelo preço da tabela (FEAT-008; proposta para Q-120 g). Pacote derrubado mantém a contagem e pode ser pego com "Take" por qualquer jogador da party (FEAT-036).

- Critérios de aceite:
  - Pacote de ingrediente não liberado não pode ser comprado; a prateleira mostra "Out of stock" e "Day N".
  - A contagem do pacote é mantida no servidor e sobrevive à reconexão (FEAT-030) e à queda no chão (FEAT-036).
  - Restock em estação de outro ingrediente não aparece.

## Item de anomalia

### ITM-020 — Altered item (genérico)

- Tipo: item de anomalia · Tool: sim (depois de pego) · Origem: **[DEC-054]** (verbo descartar); anomalia **ANM-002 (N2) — The wrong food** (NPC-010, `anomalies.md`)
- Derrubado por atropelamento: some com o chiado; a ocorrência fecha sem sucesso nem falha (FEAT-036).

| Campo | Valor |
|---|---|
| Aparece | só em ocorrência da N2 (FEAT-022/023), com chiado curto |
| Variantes | **salsicha cinza-azulada**: entra no trilho de descanso na **próxima posição a ser usada** (o próximo "Add Sausage" a pega) · **pão mordido** (meia-lua cartunizada, nada nojento): aparece já cortado numa tábua livre |
| Ocupa | 1 vaga do trilho ou 1 tábua até sair |
| Pegar | hold 0,5 s "Take" no item; vira Tool (máx. 1) |
| Correto | "Throw Away" (hold 0,5 s) com o item **ou** com o Hot Dog que o contém |
| Errado | "Serve" do Hot Dog com flag `altered` → −35 em quem serviu; o hot dog vira fumaça na mão do cliente, ele vai embora sem pagar (conta como insatisfeito) |
| Omissão | não é erro; o item some às 6:00 AM |
| Valor | $0; não conta no estoque |

- Critérios de aceite:
  - O item alterado é distinguível de um normal por um sinal visível a 3 studs no celular; nunca aparece de dia.
  - Com a salsicha alterada no trilho, o próximo "Add Sausage" (de qualquer jogador) a coloca no pão.
  - Descartar o Hot Dog alterado fecha a ocorrência com sucesso e não tira sanidade.

## Item especial

### ITM-021 — Rescue Whistle

- Tipo: especial (reviver) · Tool: sim · Status: Rascunho · Origem: **[DEC-092, DEC-100, DEC-106, DEC-108, DEC-121, DEC-129]**; seguem como proposta: uso por colega (**Q-120 f**), sem "Give" (**Q-120 i**).
- Nome de exibição: **"Rescue Whistle"** (narrative-writer, `ui-text.md`; nome final é do narrative-writer, DEC-022). DEC-129 o chama de "Revive Kit": é o mesmo item. Chave de dados `revive_kit`, ID ITM-021 mantidos. Apito da Bellmoor Rescue que chama a ambulância de volta (fantasia de resgate, sem tom médico, DEC-023). Ícone e modelo com o art-director.

| Campo | Valor |
|---|---|
| Onde se compra | slot especial S1 da bancada do Ninth Street Mart, quando sorteado (FEAT-035) **[DEC-100, DEC-106]**; prompt "Buy Whistle (${preço})" |
| Moeda | dinheiro da party **[DEC-108]** |
| Preço | **$200 × multiplicador da party** (party contada no fim do Day 1, DEC-121): 1p $200 · 2p $300 · 3p $380 · 4p $440 **[DEC-129]** |
| Chance de aparecer | 15% por turno (dia e noite), só depois da compra do trailer **[DEC-129]**; 1 unidade por aparição |
| Hotbar | Tool; máx. **1 por jogador**; ocupa 1 das 4 vagas (FEAT-005) **[DEC-100]** |
| Uso pelo próprio | caído (`Down`) com o apito na hotbar: botão "Use Whistle" no spectate; vale também na janela de 10 s |
| Uso por colega (proposta, Q-120 f) | jogador `Active` com o apito na mão: "Blow Whistle", hold 1,5 s, revive o caído mais antigo da party; a Tool mostra "Revive {name}"; sem caído revivível, a Tool mostra "No one to revive" e não gasta |
| Efeito | o caído volta pela ambulância em AMB-P, aparece em REV-1..4, com 50% da sanidade máxima (FEAT-034) |
| Limite | conta no limite de 2 revives por jogador por noite **[DEC-129]**; respeita o prazo de 6:00 AM **[DEC-115]** |
| De dia | pode ser comprado e carregado; não tem uso (ninguém cai de dia) |
| Validade | não estraga (DEC-128); passa de turno para turno; entra no snapshot como Tool do jogador |
| Derrubado (atropelamento) | intacto, pode ser pego com "Take" por qualquer jogador da party (FEAT-036) |
| Dono vira espectador | o apito vai para o balcão do trailer como item no chão (FEAT-025) |
| Pode dar a outro jogador? | não por "Give" (só derrubando); proposta: sem "Give" no MVP para não criar prompt novo |

- Critérios de aceite:
  - O apito nunca aparece na bancada antes da compra do trailer.
  - Comprar debita exatamente $200 × multiplicador do caixa da party; com a hotbar cheia ou já tendo 1 apito, o prompt mostra "Hands full" e não cobra.
  - Usado pelo próprio caído na janela de 10 s, a noite continua.
  - Usado por um colega com 2 caídos, revive o que caiu primeiro.
  - Ativar sem caído revivível não consome o apito.
  - Caído que já usou 2 revives na noite não recebe a opção "Use Whistle".
  - Noite perdida devolve o apito a quem o tinha no início da noite (snapshot) e desfaz compra feita durante ela.

---

## Propostas pendentes (items)

| Q | Recomendação | Precisa do usuário? |
|---|---|---|
| **Q-062** Capacidade do Cream Cheese | 12 / **20 / 30** (mesma proporção ×5/3 e ×2,5 dos outros) | não (número) |
| **Q-120 f, i** Rescue Whistle | ficha ITM-021 acima: máx. 1 por jogador, uso pelo próprio (inclusive na janela de 10 s) e por colega de pé (caído mais antigo), sem "Give". Preço e chance já decididos (DEC-129) | não |

Decididas: **Q-025** validade → **DEC-128** (nenhum item estraga no MVP); **Q-124** cafeteira → **DEC-125** (fixa no trailer); **Q-120 e** (chance e preço) → **DEC-129**.
