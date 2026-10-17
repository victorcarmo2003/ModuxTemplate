Status: Rascunho

# Restaurante: fluxo "Overcooked de anomalia" (FEAT-043 a FEAT-050, UPG-015 a UPG-034)

Autor: game-designer, 2026-10-17 (rev. 2 no mesmo dia, com a mudança do dono "1 tablet, retirada no balcão, ninguém sai da
loja"). Dono único deste arquivo. Fontes: `source/2026-10-17-restaurante-brief.md` (com o Adendo 2, caixas), esboço
`source/2026-10-17-restaurante-esboco.webp`, `source/2026-10-17-caixas-estoque.png` e a **mudança do dono repassada pelo
orquestrador em 2026-10-17** (vale sobre o brief e o esboço onde discordam):

> Só **1 tablet**, na **ponta direita** do balcão. A **porta de saída sai**. O balcão vai até a **ponta esquerda**, onde ficam o
> **pote de gorjetas** e o **ponto de retirada**. Clientes fazem fila no tablet, são atendidos um por um e esperam
> **empilhados na retirada**; o jogador monta e **entrega o prato no balcão** ao cliente certo; o cliente senta, come e vai
> embora. **O jogador não sai da loja** (a loja é o único ponto seguro). Reabastecimento por caixas **sem sair da loja**
> (escotilha de serviço nos fundos). Drive-thru continua.

Decisões que este documento detalha: **DEC-269 a DEC-276**, **DEC-277** (erro de anomalia tira sanidade, só cai com sanidade
zero) e **DEC-280** (1 tablet, retirada no balcão, o jogador não sai da loja). Nomes de mapa, ações, Tools e campos seguem
`tech/restaurant-flow.md` rev. 2 (architect): `TAB-1`/`TAB-2`, fila `Q1..Q5`, `PICKUP` + fila de retirada `PU-1..n`
(`CustomerService/Pickup.luau`), `PLATE-n`, `GRILL-n`, `CUT-n`, `COND-n`, `DT-STOP`/`DT-PC`, `pickup_serve`, `plate_put`,
`plate_take`, `Seating.SitAt = "Served"`, `Seating.DirtyTables = false`. Recomendações
Provisórias do secretário levadas em conta: **Q-307** (híbrido A: cada estação abre só a sua seção da vista focada),
**Q-308** (uma persiana sobre o atendimento + janela do drive-thru), **Q-309** (paga ao confirmar; a parte "espera na mesa"
foi superada pela mudança do dono: agora espera na retirada e senta **depois**), **Q-350** (estoque "infinito" e o Mart).
Base: FEAT-005, FEAT-006, FEAT-009 a FEAT-011, FEAT-014, FEAT-015, FEAT-037 a FEAT-041, `upgrades.md`, `economy.md` §5.0,
`tech/prep-mode.md`, `tech/prep-3d.md`, DEC-045, DEC-051, DEC-072, DEC-101, DEC-174, DEC-223, DEC-226, DEC-238, DEC-239, DEC-259.

Tudo aqui é **Rascunho / Provisório** (fase 1, DEC-193): o trabalho pode seguir com estas recomendações; nada vira Aprovado
sem DEC do dono. Números são valores iniciais de tabela (DEC-044): mudar número = mudar `Content`, nunca código.
Anomalias são de outro agente (`design/anomalies-v3-restaurant.md`, em revisão, DEC-278); aqui só **ganchos** (§9).

> **IDs.** FEAT-042 já é "Os Regulares" (`design/bonds-proposal.md`): este documento usa **FEAT-043 a FEAT-050**.
> UPG-015 a UPG-034. Perguntas Q-320 a Q-329 (§10). IDs de mapa: os do `tech/restaurant-flow.md`; os que só aparecem aqui
> (`HATCH`, `ENTRY`) são sugestão para o level-designer.

---

## 0. O loop em uma tela

Problema (dono): com 2 jogadores um cozinha e o outro olha. Meta (DEC-275): **todo mundo trabalhando em paralelo**, solo
vencível com os upgrades da progressão normal, prioridade de entrega rápida.

```
Cliente entra ─► FILA do tablet (ponta direita) ─► TABLET: mini-diálogo, nota do HUD montada item a item (FEAT-043)
                                                         │ confirma: paga, ganha #n
                                                         ▼
     espera EMPILHADO na RETIRADA (ponta esquerda), número #n sobre a cabeça
                                                         │
Cozinha:  prato-slot #n nasce na Mesa de Montagem (FEAT-044)
          pão: corte ─► pilha ─► prato · salsicha: grelha cru→pronto→queimado ─► pilha ─► prato (FEAT-045)
          prato ─► condimentos ─► balcão de retirada
                                                         ▼
Entrega NO BALCÃO ao cliente #n (FEAT-046) ─► ele senta numa mesa, come e vai embora (gorjeta de mesa no pote)

Drive-thru (FEAT-047): carro na janela direita ─► computador ─► prato-slot com ícone de carro ─► entrega na janela
Estoque (FEAT-050): telefone ─► van atrás da loja ─► caixas na ESCOTILHA dos fundos ─► "Restock" na estação
Escala e automação (FEAT-049): taxa por nº de jogadores; upgrades que cobrem papéis no solo sem matar o co-op
```

### 0.1 Layout (vista de cima)

| Zona | O que tem | Âncoras sugeridas |
|---|---|---|
| Salão (fora, só NPCs) | 4 mesas de piquenique (AST-100); entrada dos clientes pelo meio; plantas à direita | `TBL-1..4`, `ENTRY` |
| Balcão da frente, **ponta direita** | **1 tablet** (2º com UPG-027) + fila única `Q1` (frente do tablet) .. `Q5` | `TAB-1` (`TAB-2`, `Q1B`) |
| Balcão, **ponta esquerda** | **ponto de retirada** (`PICKUP`, prompt `pickup_serve` "Hand Over") + **pote de gorjetas** (DEC-239) ao lado; clientes esperam na fila de retirada `PU-1` (no balcão, ao lado do `PICKUP`) .. `PU-n` (fila lateral) | `PICKUP`, `PU-1..n`, `TRL-TIPJAR` |
| Centro da cozinha | **Mesa de Montagem**: 8 pratos-slot (até 12 com UPG-024) | `PLATE-1..12` |
| Fundo, esquerda → direita | **grelha** de barras (AST-120, DEC-226) + caixa de salsichas (`sausage_stock`), pão + 2 tábuas de corte, 2 lugares de condimentos, lixeira | `GRILL-1` (`GRILL-2`), `CUT-1..2`, `COND-1..2`, `BIN-K` |
| Parede direita | **drive-thru**: computador + janela | `DT-PC`, `DT-STOP` (+ pista `DT-*`) |
| Fundos | **escotilha de serviço** (caixas entram por ela; prateleira de 6 caixas por dentro), **telefone** (DEC-124), cafeteira, disjuntor, tablet de anomalias, zona de esconder (família B) | `HATCH`, `HideZone_Back` (reuso) |

Regras de espaço: **jogador não sai da loja** (sem porta para jogadores; Q-329). NPC nunca entra na cozinha. A janela do
drive-thru e a escotilha são passagens de objeto, não de corpo.

---

## 1. O que reaproveita, o que muda, o que sai

### 1.1 Sistemas existentes

| Sistema atual | No restaurante | Mudança |
|---|---|---|
| Nota do pedido no HUD (`HudOrder`, canto superior esquerdo) | **é a nota do diálogo** (FEAT-043) e, depois, a nota do prato que o jogador segura | pop-up por item e o número #n |
| `CustomerService` (paciência Q-192, `SellLine`, Completo/Incompleto/Errado DEC-072, duplas FEAT-038, `serve` com prompt e arrasto FEAT-041) | **igual na essência**: a entrega no balcão de retirada é o `serve` de hoje com outro ponto | pedido ganha #n; paga ao confirmar (Q-309); estados `Waiting` (na retirada) e `Eating` |
| Fila do balcão (`Q1..`) | vira a **fila do tablet** (até 4) | o Counter (UPG-003) sai |
| `Seating` (FEAT-037, `SitHeadroom`, `MaxDiners`, `EatTime`, gorjeta de mesa) | **o cliente senta depois de receber**, como a FEAT-037 original | sem "Clean Table": o jogador não sai; a bandeja some sozinha |
| `KitchenService` (grelha, trilho, pão, toppings, lixeira, estoque, `TakeStock`, `Restock`) | **base das estações** (FEAT-045) e do reabastecimento (FEAT-050) | grelha ganha `Burnt`; trilho vira bandeja quente do Grill Bot |
| Handlers antigos de prompt (`grill_place`, `grill_collect`, `bun_cut`, `topping_add`, `discard`) + flag `WorldKitchenPrompts` | rollback da onda 0 (opção B da Q-307) | saem pilhas e prato em vez do Tool HotDog |
| `ItemService` (Tools, `Quality`, hotbar 4, DEC-174) | Tools do `tech/restaurant-flow.md`: `bun_sliced`, `sausage_grilled`, `hot_dog` (com atributo `Ticket` = #n); novo aqui: `stock_box` | proposta deste doc: `bun_sliced` e `sausage_grilled` ganham atributo `Count` (pilha); sem ele vale 1 por Tool |
| Pacotes do Mart (ITM-011 a ITM-019) | viram **caixas** com o mesmo conteúdo e preço (FEAT-050) | chegam pela escotilha |
| Gear Stand do Mart (DEC-101) | o jogador não vai mais ao Mart: a bancada **entra na loja** (Q-321) | — |
| Pote de gorjetas, vendas direto no Cash, nota do turno (DEC-238, DEC-239, DEC-051) | **igual** | — |
| Janela do trailer + alavanca (DEC-261) | sai (DEC-269); equivalente: **persiana do balcão (atendimento + retirada) + janela do drive-thru, uma alavanca** (Provisório da Q-308) | gancho de anomalia |

### 1.2 Modo de preparo focado (DEC-223): o que continua e o que sai

A DEC-272 trocou "uma tábua por jogador com todas as etapas" por estações físicas. Segue-se a recomendação Provisória da
**Q-307 (A) híbrido**: **cada estação abre só a sua seção** da vista focada que já existe (grelha = `Grill`, tábua = `Board`,
condimentos = `Toppings`) e sai sozinha quando o item vai para a mão; montagem no prato-slot e entrega ficam no mundo.
Acréscimo deste documento: a grelha ganha **queimado** (brief; responde `Q-222` com "sim"). A **onda 0** pode rodar com as
estações em prompt no mundo (opção B como rollback por flag).

| Peça (`prep-mode.md`, `prep-3d.md`, FEAT-039) | Destino | Por quê |
|---|---|---|
| `Grade.luau` (conta única de nota) | **continua** | + linha `grill_pickup` |
| `Content.Prep.Tolerances` (`bun_cut`, molhos, queijo, bacon, batata, `grill_flip`) | **continuam** | mesmos gestos, mesma nota |
| Gestos `slice`, `trace`, `slide`, `taps`, `hold`; Assist, "segurar", reduced motion, cursor virtual | **continuam** nas seções | miolo divertido, pronto |
| Câmera `Prep`, vistas `Grill`/`Board`/`Toppings`, `CamAnchor`/`Focus` | **continuam**, presas a `GRILL-n`, `CUT-n`, `COND-n` | autoria de mapa |
| Grelha de barras de 8 vagas e **virar** (`grill_flip`, DEC-226) | **continua** | + `Burnt` e coleta para a pilha |
| Dopamina (DEC-229), mão fantasma (DEC-228), selecionar → arrastar (DEC-233), lixeira 2D (DEC-231), arrasto ao vivo com trava (DEC-259) | **continuam** dentro das seções | já decididos |
| `Quality` no Tool e efeito na gorjeta (Q-219 B) | **continua**, no `hot_dog` | — |
| Saídas forçadas por anomalia (`PrepService:Kick`, `CueLock`) | **continuam** | — |
| `PrepSeats`, `PrepEnter/Leave`, `PrepBegin/Finish`, `PrepResult` | **continuam** com `Station` = estação física | — |
| Gesto `place` (salsicha no vão do pão) | **sai** | a salsicha cai no prato por toque na montagem |
| Pan contínuo entre seções (DEC-232), abas Order/Serve, `TicketRail`, cartões | **saem** | uma seção por estação; pedido no tablet; entrega no mundo |
| Next → **Done**; **Leave** | Done fecha a seção; Leave continua | — |
| `Station_1..4` = nº de jogadores (DT-9) | **sai** (DEC-275) | escala por papéis |

---

## 2. Fichas FEAT

### FEAT-043 — Atendimento no tablet

- Status: Rascunho (Provisório) · Pilares: VENDER · Origem: DEC-270; mudança do dono (1 tablet, ponta direita)
- Resumo: os clientes fazem **fila única** no tablet da ponta direita e são atendidos **um por um**. O jogador toca o tablet e
  abre um mini-diálogo curto; a **nota do HUD** se monta item a item com pop-up. Ao confirmar, o cliente **paga**, ganha o
  **número #n** (aparece sobre a cabeça dele) e vai esperar na retirada.

| Regra | Valor (`Content.Restaurant.Tablets`) |
|---|---|
| Tablets | **1** (`TAB-1`); **2º** com UPG-027 (`TAB-2`, à esquerda do 1º, cabeça `Q1B`); kiosk com UPG-028 |
| Fila | fila única atual: `Q1` (frente do `TAB-1`, quem pede) + `Q2..Q5` = **até 5** (`QueueSize`); cheia → tentativa de spawn `SkippedFull` (FEAT-009) |
| Paciência de fila | **45 s** a partir de entrar na fila (Q-192) |
| Abrir | prompt "Take Order" no tablet com cliente, toque 0 s, raio 6 |
| Jogador durante o diálogo | parado (`Freeze` curto), câmera livre; afastar cancela, a paciência volta a correr |
| Roteiro | (1) jogador: "Hi! What can I get you?" · (2) cliente: abertura · (3) "a bun..." → pop-up · (4) "...with a dog" → pop-up · (5) cada complemento → pop-up · (6) "That's it!" → carimbo #n |
| Tempos (1ª vez) | abertura 1,2 s · "I'd like" 0,8 s · **0,45 s por item** · confirmação 0,6 s → **K=0: 3,5 s · K=2: 4,4 s · K=3: 4,9 s**; dupla (FEAT-038) +1,0 s + itens do 2º |
| Acelerar | apertar interagir de novo = **×2** até o fim |
| Quem repete | depois de **8 pedidos** tomados pelo jogador na run, o diálogo dele começa em **×1,6** |
| Upgrade | UPG-034 Quick Greeting −30% / −50% (piso 1,5 s) |
| Pedido | sorteado como hoje (FEAT-010); o diálogo só **mostra** o sorteio do servidor |
| Confirmação | uma transação: cria #n (1–99 por turno), **cobra o preço** no Cash (DEC-238; Q-309), cria o prato-slot (FEAT-044), manda o cliente ao fim da fila de retirada `PU-k` (FEAT-046) |
| Bloqueio | sem prato-slot ativo livre **ou** fila de retirada `PU-1..n` cheia (`pickup_full`): o tablet mostra **"Kitchen full"** (lâmpada Mustard) e não abre o diálogo; o cliente espera em `Q1` com a paciência correndo |
| Nota do HUD | vazia com #n em branco → um pop-up por item (escala 0 → 1,15 → 1 em 0,25 s, SFX `blip`) → carimbo #n; some em 2 s, salvo se o jogador segurar um prato |
| Número na cabeça | ao confirmar, o cliente ganha uma `BillboardGui` "#12" (Mustard sobre Cream, visível a ~40 studs) até receber o prato |
| Voz | MVP: balão + `blip` por sílaba; TTS `frank` opcional depois (Q-327) |
| Classe (gancho) | Hawker −20% no diálogo |

**O atendente é gargalo?** Com 1 tablet o diálogo ocupa 4,4 s por pedido. Ocupação só de diálogo: solo 4,4/30 = 15%; 4p no pico
(N10, 7,7 s por chegada) **57%**, somando o drive-thru, que fica do lado (§FEAT-049). Não trava, mas é o papel mais cheio em
4 jogadores: o 2º tablet (UPG-027) é o 1º upgrade de party; o kiosk (UPG-028) é o de solo.

- Dados: `Content.Restaurant.Tablets` { `Count` 1, `MaxCount` 2, `QueueSize` 5, `QueuePatience` 45, `PayOn` "Confirm", `Times` { `Open` 1,2, `Lead` 0,8, `PerItem` 0,45, `Confirm` 0,6, `PairExtra` 1,0 }, `HurryMult` 2, `VeteranAfter` 8, `VeteranMult` 1,6, `MinTotal` 1,5 }.
- Party: qualquer jogador atende; 2º jogador no mesmo tablet recebe `tablet_busy`.
- Fora do MVP: "Come again?" (Q-227), pedido ambíguo, TTS por item.
- Critérios de aceite:
  - K=2 sem aceleração: do toque ao carimbo #n, **4,4 ± 0,3 s**; apertando no meio, o restante cai pela metade (± 0,2 s).
  - Do 9º pedido do mesmo jogador em diante, o diálogo dura ≤ 62,5% do base (± 0,2 s).
  - A nota mostra exatamente o sorteio do servidor, um pop-up por item, ordem pão → salsicha → complementos.
  - O Cash sobe o preço no instante do carimbo; o cliente mostra "#n" sobre a cabeça até receber.
  - Sem slot ou sem lugar na retirada, "Take Order" não abre e o tablet mostra "Kitchen full" para todos.
  - Andar para longe no meio cancela sem criar pedido nem cobrar.
  - Nunca mais de 5 clientes na fila do tablet (`Q1..Q5`).

### FEAT-044 — Fila de pedidos na mesa de montagem (pratos-slot)

- Status: Rascunho (Provisório) · Pilares: VENDER, GERENCIAR · Origem: DEC-271
- Resumo: cada pedido confirmado vira um **prato meio transparente** num slot da Mesa de Montagem, com **BillboardGui**: #n,
  ícones do pedido e o anel de paciência. O prato fica sólido conforme recebe pão e salsicha. Pegar o prato **libera o slot**.

| Regra | Valor (`Content.Restaurant.Pass`) |
|---|---|
| Slots físicos | 8 (`PLATE-1..8`, `Content.Restaurant.Rules.PlateSlots`), até 12 com UPG-024 |
| Slots ativos por party | 1p **4** · 2p **6** · 3p **8** · 4p **8**; +2 por nível de UPG-024 |
| Ocupação | slot ativo livre **mais à esquerda** (perto da grelha); drive-thru: **mais à direita** (perto da janela) |
| Billboard | "#12" grande · ícone de carro se for drive-thru · ícones de pão, salsicha e complementos (cinza = falta, cheio = feito) · anel de paciência Cream → Mustard → **Ink** (sem vermelho), com **forma** que muda (cheio → meio → 1/4 piscando) |
| Prioridade | sem ordem obrigatória; o mais antigo pulsa em Mustard; paciência ≤ 25% ganha "!" |
| Estados | `Ghost` → `Bun` → `Base` (pão + salsicha) → condimentos (FEAT-045) → `Ready`; K = 0: `Base` já é `Ready` |
| Encher | pilha certa na mão: **toque** no slot = 1 item; **segurar 0,5 s** = "Fill All": 1 item por prato que precisa, do mais antigo ao mais novo, até a pilha acabar |
| Pegar | `plate_take` "Take Plate" (toque), em prato `Base` ou `Ready`; vira Tool `hot_dog` com `Ticket` = #n; o slot fica livre na hora. `plate_put` devolve um `hot_dog` ao slot |
| 9º pedido (slots cheios) | o tablet trava ("Kitchen full", FEAT-043). Nunca há pedido sem prato. Pegar um prato destrava em ≤ 0,5 s |
| Cliente desistiu | o prato vira **órfão** (billboard cinza "?"). Pedido novo **idêntico** reaproveita o órfão mais adiantado; senão fica até alguém jogar fora ou até o `Summary` (descarte, ingredientes perdidos) |
| Órfão na mão | entregável a qualquer cliente com pedido pendente idêntico (reatribuído na entrega) |
| Trava co-op | quem enche um slot o trava 0,6 s (DEC-259, cor do jogador) |
| Rede (architect) | set de pedidos até 14 registros (12 slots + 2 carros): acima de 8, todo campo com ≥ 7 bits (`drop.section`) |

- Dados: `Content.Restaurant.Pass` { `Slots` 8, `MaxSlots` 12, `ActiveByParty` {4,6,8,8}, `FillAllHold` 0,5, `UrgentAt` 0,25, `OrphanReuse` true }.
- Critérios de aceite:
  - Pedido confirmado aparece no slot certo em ≤ 0,5 s, com #n e ícones iguais aos da nota.
  - Solo: o 5º pedido simultâneo não é criado; pegar 1 prato libera e o 5º pode ser tomado.
  - "Fill All" com 3 pães e 5 pratos sem pão enche os 3 mais antigos.
  - Prato de quem desistiu fica cinza e é reaproveitado por pedido idêntico; no `Summary` não sobra órfão.
  - Nenhum anel usa vermelho; a urgência também muda de forma (teste em escala de cinza).

### FEAT-045 — Estações da cozinha e mãos

- Status: Rascunho (Provisório) · Pilares: VENDER, GERENCIAR · Origem: DEC-272; FEAT-006, FEAT-039
- Resumo: grelha, pão e condimentos no fundo; montagem no centro; retirada na frente. O jogador carrega **pilhas**, **pratos** e
  **caixas** como Tools (limite 4, DEC-174). Cada estação abre só a sua seção da vista focada (§1.2).

**Mãos** (recomendação A de Q-322):

| Tool | Conteúdo | Capacidade | Máx. por jogador |
|---|---|---|---|
| `bun_sliced` "Buns ×n" (atributo `Count`) | pães cortados (cada um com sua nota de corte) | **3** (UPG-019: 5 / 8; Hauler +1) | 1 |
| `sausage_grilled` "Dogs ×n" (atributo `Count`; vem do `rail_take`/coleta) | salsichas prontas (cada uma com sua nota) | **3** (UPG-018: 5 / 8; Hauler +1) | 1 |
| `hot_dog` "#12" (atributo `Ticket`) | pedido, pão, salsicha, complementos, nota | 1 prato por Tool | **2** (`HotDog` 2) |
| `stock_box` "DOGS" etc. | caixa de estoque (FEAT-050) | conteúdo da caixa | **2** (Hauler 3; UPG-032 carrinho) |
| Coffee, Revive Kit | como hoje | — | FEAT-005 |
| **Total** | | | **4 Tools**; 5º = `hands_full` |

| Opção (Q-322) | Prós | Contras | Escopo |
|---|---|---|---|
| **A. Pilhas, pratos e caixas como Tools (recomendada)** | reusa `ItemService`, hotbar, snapshot; lote (cortar 3, grelhar 3); solo carrega tudo | hotbar cheia em party | baixo |
| B. Mãos Overcooked (1 coisa) | leitura imediata, caos divertido | quebra DEC-174; solo vira vai-e-volta; sistema novo | alto |
| C. Bandejas compartilhadas, sem carregar ingredientes | simples | some o "pegar e pôr no prato" da DEC-272 | médio |

**Grelha** (`GRILL-1`, barras AST-120, 8 vagas físicas, DEC-226; UPG-001, UPG-015, UPG-016)

| Regra | Valor (`Content.Restaurant.Grill`) |
|---|---|
| Vagas | as **vagas ativas do UPG-001** na grelha de barras (a contagem por nível vigente no `Content` manda); 2ª grelha com UPG-015 |
| Entrar | prompt "Grill" (toque): abre só a seção `Grill`; **Leave** ou pilha cheia sai |
| Pôr | arrastar da caixa de salsichas à vaga, ou toque na caixa = 1ª vaga livre; consome 1 do estoque |
| Cozinhar | **12 / 10 / 8 s** (UPG-001); Line Cook −15% nas dele |
| Virar | janela de 40% a 60% do tempo, `grill_flip` carimbado no servidor; sem virar = Messy |
| Estados | `Raw` → `Ready` (dourada, brilho + check, SFX `grill_ready`) → `Burnt` (preta, fumaça grossa, SFX próprio) |
| Queimar (`BurnAfter`) | **10 s** depois de `Ready` (UPG-016: **18 / 30 s** + apito 3 s antes); vale com o jogador fora da vista |
| Coletar | arrastar ou tocar a pronta → `sausage_grilled`; "Collect All" leva todas até a capacidade. No mundo, "Collect" (toque) também coleta |
| Nota da salsicha | média de `grill_flip` e `grill_pickup` (≤ 3 s depois de pronta = Perfect · ≤ 7 s Good · depois Messy) |
| Queimada | não entra na pilha; ocupa a vaga até ir à lixeira 2D (DEC-231) ou "Scrape" no mundo; estoque perdido |
| Bandeja quente (trilho AST-013, 8) | usada pelo Grill Bot (UPG-021); qualquer um pode "Take Dogs"; ali **não queima** |

**Pão e corte** (caixa de pão + `CUT-1..2`): 2 tábuas. **Alvo:** "Cut Buns" abre a seção `Board`; corta **em sequência** até
encher a pilha ou acabar o pão (`slice` ~1,0 s por pão), **Done** sai; nota `bun_cut` por pão. **Onda 0:** "Cut Bun" segurar
0,6 s por pão, nota Good fixa. 1 pão do estoque por corte.

**Montagem** (FEAT-044): pilha na mão + `plate_put` "Add Bun" / "Add Sausage" (toque) no slot, ou "Fill All". Salsicha só em prato com pão.

**Condimentos** (`COND-1..2`): 2 lugares. Com `hot_dog` em `Base` equipado: "Add Toppings #12" abre a seção `Toppings` com o
prato na tábua; **só as tigelas do pedido acendem**; gestos de FEAT-039 (selecionar → arrastar, DEC-233), ordem livre; **Done**
devolve o prato `Ready`. Complemento não pedido é aplicável (tigela apagada, mas usável) e vira **Errado** na entrega.
Tempo-alvo K=2: **4–6 s** na seção + 0,65 s de entrar/sair. **Onda 0:** prompts antigos "Add {item}" (hold 1 s) no prato na mão.

**Lixeira** (de fábrica, perto da montagem): "Throw Away" (hold 0,5 s) descarta o Tool equipado.

- Dados: `Content.Restaurant.Grill`, `.Bun`, `.Condiments`, `.Stacks` { `Bun` 3, `Sausage` 3, `Plates` 2, `Boxes` 2 }; `Content.Prep.Tolerances` + `grill_pickup`; `Content.Items` + `bun_sliced`, `sausage_grilled`, `hot_dog`, `stock_box`.
- Critérios de aceite:
  - Pronta não coletada vira `Burnt` em `BurnAfter` ± 0,2 s; com UPG-016 nível 2, em 30 s.
  - "Collect All" leva as prontas até a capacidade; a sobra fica e continua o relógio de queimar.
  - Queimada nunca entra em pilha nem em prato; descartá-la não devolve estoque.
  - Com 4 Tools, pegar pilha, prato, caixa ou café é recusado com `hands_full`.
  - Complemento não pedido → entrega Errada (DEC-072), o prato volta à mão.
  - `/dev prep grade` termina `N/N ok` com a linha `grill_pickup`.
  - Dois jogadores no mesmo slot/vaga no mesmo frame: só um efeito; o outro recebe o toast da recusa (FEAT-005).

### FEAT-046 — Entrega no balcão de retirada

- Status: Rascunho (Provisório) · Pilares: VENDER · Origem: mudança do dono 2026-10-17 (supera o "entrega na mesa" de DEC-273 e a espera na mesa de Q-309); FEAT-041
- Resumo (DEC-280): depois de pagar, o cliente entra na **fila de retirada** (`PU-1` no balcão, ao lado do `PICKUP`; `PU-2..n`
  em fila lateral) com **#n sobre a cabeça**. O jogador pega o prato #n e entrega **no balcão**. O cliente leva o prato, senta
  numa mesa, come e vai embora. O jogador nunca sai.

| Regra | Valor (`Content.Restaurant.Rules`, `Content.Seating`) |
|---|---|
| Fila de retirada | `PU-1..n` (`CustomerService/Pickup.luau`, `Customers.Pickup = k`); tamanho `PickupSlots`: proposta deste doc = **slots ativos de FEAT-044** (1p 4 · 2p 6 · 3–4p 8); o `tech` usa 4 fixo no MVP. Cheia → "Take Order" recusado (`pickup_full`, FEAT-043) |
| Ordem | entra no fim da fila; a fila anda quando alguém é servido (quem está em `PU-1` não tem prioridade de venda: qualquer #n pode ser servido) |
| Identificar o dono | o **mesmo #n** em 3 lugares: nota do HUD de quem segura o prato, `PlateTicket` do prato, billboard sobre a cabeça do cliente. Com um `hot_dog` na mão, o cartão DELIVER "#12" (FEAT-041) acende **só** sobre o dono |
| Entregar | `pickup_serve` "Hand Over" (toque, raio 6) no `PICKUP`, ou `serve`/arrasto no rig do `PU-n` (FEAT-041). O servidor procura na fila de retirada o cliente do `Ticket` do prato; senão um com pedido idêntico; senão o `PU-1` (veredito Errado, o prato volta à mão) |
| Validação | `CustomerService:ServeFor` como hoje: Completo / Incompleto / Errado; dupla com 2 pratos, entrega dupla de uma vez (FEAT-038) |
| Depois de receber | `Seating.SitAt = "Served"`: o cliente leva o prato (rig `Carrying`), `SeatingService:Offer` na venda; senta se houver mesa livre **e** folga no teto (`SitHeadroom` 2); senão **leva para viagem** e sai (sem penalidade, sem gorjeta de mesa) |
| Mesa | 4 mesas, **2 grupos por mesa** (um por banco, estranhos nunca no mesmo banco; Q-324) = 8 lugares; `EatTime` **12 s** ± 2; `Seating.DirtyTables = false`: ao levantar, **$1 por pessoa** vai direto ao pote e a mesa volta a livre (sem "Clean Table", Q-351) |
| Ninguém sai | o jogador não tem porta para o salão (Q-329); o salão é só dos NPCs |

- Dados: `Content.Restaurant.Rules.PickupSlots` (por party, proposta) e `.PickupServeRadius` 6; `Content.Seating` { `SitAt` "Served", `DirtyTables` false, `GroupsPerTable` 2, `EatTime` 12, `EatJitter` 2, `TableTip` 1, `SitHeadroom` 2 }.
- Critérios de aceite:
  - Todo cliente que confirmou o pedido entra na fila de retirada em ≤ 8 s e mostra "#n" igual ao do prato.
  - Com um prato na mão, só o dono mostra o DELIVER; sem prato, nenhum.
  - "Hand Over" no `PICKUP` com o prato #12 vende para o cliente #12 onde quer que ele esteja na fila (`PU-1..n`); resultado de DEC-072; a fila anda em ≤ 2 s.
  - Com as 8 vagas de mesa ocupadas, quem recebe sai para viagem; nunca dois grupos no mesmo banco.
  - Cliente que comeu sentado põe exatamente $1 por pessoa no pote.
  - Nenhum jogador consegue chegar ao salão andando.

### FEAT-047 — Drive-thru

- Status: Rascunho (Provisório) · Pilares: VENDER, OBSERVAR · Origem: DEC-274
- Resumo: carro para na janela direita; o pedido é tomado no **computador** (mesmo diálogo do tablet); o prato vai ao slot mais
  à direita com ícone de carro; entrega **na mesma janela**. Espera longa: **buzina**, **estresse**, **vai embora**. Às vezes um
  **pet** sai do carro.

| Regra | Valor (`Content.Restaurant.DriveThru`) |
|---|---|
| Estreia | **Night 2** (Q-326) |
| Parte do fluxo | da N2 em diante, fração das tentativas que vira carro: 1p **15%** · 2p **20%** · 3p **20%** · 4p **25%** (divide o fluxo de FEAT-049, não soma) |
| Carros | 1 na janela + fila: 1p 0 · 2p 1 · 3p 1 · 4p 2; fila cheia = a tentativa vira cliente do salão |
| Modelo | carro do trânsito (NPC-022) com motorista **estático** (sem IA humanoide; teto de veículos) |
| Atender | "Take Order" no `DT-PC` com carro na janela: diálogo de FEAT-043 (balão com chiado de caixa de som); paga ao confirmar |
| Paciência de pedido | **40 s** |
| Paciência de preparo | **70 + 5 × K s** (+15/+30 s com UPG-030) |
| Buzina | em **50%** e **25%** de cada paciência (SFX; ícone na billboard do prato) |
| Estresse | em **25%**: vapor + rosto bravo do motorista (cartoon, Mild) |
| Ir embora | paciência 0: sai cantando pneu; **insatisfeito** e **estorno** do preço (FEAT-048); prato órfão |
| Entregar | `hot_dog` na mão na janela (`DT-STOP`, pista 1): soltar no carro ou "Hand Out #12" (toque) |
| Pet | **20%** dos carros (NPC pequeno a numerar em `npcs.md`; espécie com o art-director). Depois de **15 s** de espera, sobe no **parapeito da janela**, ao alcance de dentro |
| "Pet" | hold 0,5 s, **1× por carro**: +**10 s** de paciência; ignorado 12 s, volta ao carro; nunca sai do raio de 6 studs da janela; máx. **1 pet** por servidor (conta no teto de 12) |

- Dados: `Content.Restaurant.DriveThru` { `UnlockNight` 2, `ShareByParty` {0,15; 0,20; 0,20; 0,25}, `QueueByParty` {0,1,1,2}, `OrderPatience` 40, `PrepBase` 70, `PrepPerK` 5, `HonkAt` {0,5; 0,25}, `StressAt` 0,25, `PetChance` 0,2, `PetAfter` 15, `PetBonus` 10, `PetIgnore` 12, `PetMax` 1 }.
- Party: o computador fica ao lado do tablet: em 3–4 jogadores o **caixa** cuida dos dois; com o 2º tablet, um caixa por frente.
- Critérios de aceite:
  - Antes da N2 nenhum carro; da N2 em diante, 1.000 tentativas solo simuladas: 15% ± 2 p.p. viram carro.
  - Sem ação, a buzina toca exatamente 2 vezes por fase de paciência.
  - Paciência 0: o carro sai da pista em ≤ 6 s, o pedido conta insatisfeito, o preço é estornado, o prato fica cinza.
  - "Pet" soma 10 s uma vez por carro; o pet nunca sai do raio de 6 studs.
  - O motorista não conta no teto de humanoides.

### FEAT-048 — Paciência, gorjeta e avaliação

- Status: Rascunho (Provisório) · Pilares: VENDER, PROGREDIR · Origem: FEAT-011, Q-192, Q-309, DEC-051, DEC-072, DEC-238/239

| Camada | Começa | Dura | Visível em | Ao zerar |
|---|---|---|---|---|
| Fila do tablet | entra na fila | **45 s** | anel sobre o cliente | vai embora (`Left`), insatisfeito, nada cobrado |
| Fila do drive-thru | carro na janela | **40 s** | anel sobre o carro + computador | buzina / estresse / vai embora |
| Preparo (salão) | carimbo #n | **75 + 5 × K s** (+10 s dupla) | billboard do prato + anel sob o "#n" do cliente | sai (`Slow`), insatisfeito, **estorno** |
| Preparo (drive-thru) | carimbo #n | **70 + 5 × K s** (+UPG-030) | idem | idem |
| Janela de gorjeta | carimbo #n | **24 + 4 × K s** (era 16 + 4K, DEC-072; Q-328) | brilho Mustard no anel | — |

Pagamento ao confirmar (Q-309) com o mesmo resultado líquido de DEC-072:

| Resultado na entrega | Dinheiro | Gorjeta | Nota do turno |
|---|---|---|---|
| Completo | fica o preço | $1 na janela (Hawker $2, Shift Lead $0); Perfect $2 e janela +4 s; Messy $0 (Q-219 B) | satisfeito |
| Incompleto | **estorno de 50%** (floor) | — | insatisfeito |
| Errado | nada muda; o prato volta à mão; o cliente segue esperando o certo | — | (só conta se terminar em desistência) |
| Desistiu (preparo) | **estorno integral** | — | insatisfeito |
| Gorjeta de mesa | $1 por pessoa que comeu sentada, no pote | — | — |

- Avaliação por cliente: rosto ao receber (feliz / ok / triste / bravo), só visual. Nota do turno: DEC-051 sem mudança.
- Leitura: o trabalho solo por pedido sem upgrades é ~24 s (FEAT-049); 85 s de paciência cobrem 2 pedidos em lote e uma
  anomalia; 32 s de janela de gorjeta pedem lote curto. Sem a caminhada até as mesas, a janela pôde subir menos que na rev. 1.
- Dados: `Content.Restaurant.Patience` { `Queue` 45, `DtQueue` 40, `PrepBase` 75, `DtPrepBase` 70, `PrepPerK` 5, `PairBonus` 10, `TipBase` 24, `TipPerK` 4, `IncompleteRefund` 0,5, `GiveUpRefund` 1 }.
- Critérios de aceite:
  - Paciências e janela batem com as fórmulas (± 0,2 s) para K = 0..3 e dupla.
  - Incompleto devolve floor(50%) do preço; desistência devolve 100%; saldo da party nunca fica negativo (o estorno sai do Cash; se faltar, sai do pote, depois zera).
  - Gorjeta nunca fora da janela nem em Incompleto.

### FEAT-049 — Escala por party, papéis e automação (solo viável)

- Status: Rascunho (Provisório) · Pilares: VENDER, PROGREDIR · Origem: DEC-275; DEC-045
- Resumo: o fluxo cresce com o nº de jogadores mais que hoje, porque o trabalho agora se divide. Pratos-slot e lugares ativos
  crescem com a party. Automação cobre papéis no solo com **teto abaixo de um jogador**; o ajudante NPC só existe com ≤ 2.

**Papéis** (nenhum fixo; o layout os torna naturais):

| Papel | Onde | Faz | Carga por pedido (s, sem upgrade, K=2) | Coberto no solo por |
|---|---|---|---|---|
| Caixa | tablet + computador do drive-thru (ponta direita) | diálogos; entrega na janela do drive-thru | ~5,4 (4,4 + 1 de passo) | UPG-028 Kiosk, UPG-034, UPG-029 |
| Grelha | fundo esquerdo | pôr, virar, coletar na hora, descartar queimadas | ~3 | UPG-021 Grill Bot, UPG-016 |
| Pão / montagem | fundo + centro | cortar em lote, "Fill All" | ~4 | UPG-020 Auto-Slicer, UPG-019 |
| Condimentos | fundo direito | seção Toppings | ~6,5 | UPG-022, UPG-023 |
| Expedição (retirada) | centro → balcão esquerdo | pegar `Ready`, entregar ao #n | ~3 | UPG-025 Pickup Belt, UPG-026 Now Serving |
| Estoquista | escotilha + telefone (fundos) | pedir caixas, levar, Restock | ~1,5 (sobe em party: mais consumo) | UPG-033 Trainee, UPG-031, UPG-017 |
| Noite | toda a loja | anomalias, café, disjuntor | variável | UPG-013/014 |
| **Total solo** | | | **~24 s por pedido** | |

**Escala por party** (ativos no início do turno, Q-067):

| Party | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| Multiplicador de taxa (era 1,0/1,6/2,1/2,5; Q-323) | **1,0** | **1,8** | **2,5** | **3,1** |
| Intervalo N1 (base 30 s) | 30 s | 16,7 s | 12,0 s | 9,7 s |
| Intervalo N10 (base 24 s) | 24 s | 13,3 s | 9,6 s | 7,7 s |
| Tablets | 1 | 1 | 1 | 1 (2º = UPG-027) |
| Pratos-slot ativos e `PickupSlots` (`PU-1..n`) | 4 | 6 | 8 | 8 |
| Clientes vivos (fila + retirada + mesa; teto) | 5 | 7 | 9 | 9 |
| Grelha / corte / condimentos | 1 (vagas do UPG-001) / 2 / 2 | igual | igual | igual |
| Drive-thru: parte do fluxo · fila | 15% · 0 | 20% · 1 | 20% · 1 | 25% · 2 |
| Cozinha por jogador, N1 (24 s ÷ party ÷ intervalo) | **80%** | 72% | 67% | 62% |
| Cozinha por jogador, N10 | **100%** | 90% | 83% | 78% |

Leitura: em 2–4 jogadores cada um fica 62–90% só com a cozinha; o resto vai a estoque (mais pesado em party), drive-thru e
anomalias: ninguém olha. Solo sem upgrades chega a 100% na N10: só vence com a rota de upgrades (critério da DEC-275).

**Teto de NPC** (DEC-045, 12 humanoides com IA):

| Party | Clientes | Atores de anomalia | Pet | Trainee | Total | Fora do teto |
|---|---|---|---|---|---|---|
| 1 | 5 | 2 | 1 | 1 | 9 | carros, van, motoristas estáticos, Opal |
| 2 | 7 | 2 | 1 | 1 | 11 | idem |
| 3 | 9 | 2 | 1 | 0 | 12 | idem |
| 4 | 9 | 2 | 1 | 0 | 12 | idem |

Teto apertado em 3–4: `SitHeadroom` 2 manda quem recebe para viagem antes de travar o spawn. Plano B: sentado "estacionado"
fora do teto (`Q-180`), em Q-325.

**Automação: ajuda, não substitui** (regra de todo upgrade de automação):

1. **Vazão abaixo de um jogador hábil**: Kiosk 12 s por pedido (jogador 4–5 s); Grill Bot 1 ação a cada 6 s / 4 s;
   Auto-Slicer 1 pão a cada 5 s / 3,5 s; Now Serving: o cliente vem buscar em 4 s; Trainee anda a 70%.
2. **Sempre há um passo humano por pedido** (encher o prato ou condimentos ou a expedição).
3. **Trainee só com ≤ 2 jogadores ativos.**
4. **Escolha, não obrigação**: o Kiosk só pega cliente quando o tablet está sem jogador há 3 s.

Trabalho solo por pedido com a rota de upgrades (K=2; capacidade = 48 ÷ s por pedido, 80% de atenção):

| Conjunto | s por pedido | Pedidos/min | Servidos na N10 (demanda 2,5/min) |
|---|---|---|---|
| Sem upgrades | 24 | 2,0 | ~75–80% (nota C) |
| + Quick Greeting 1, Tongs 1, Heat Lamp 1 | 21 | 2,3 | ~90% |
| + Pickup Belt + Now Serving | 17 | 2,8 | ~100% |
| + Kiosk 1 + Grill Bot 1 | 12 | 4,0 | ~100% com folga para anomalias |
| + Auto-Slicer 1 + Trainee | 10 | 4,8 | ~100%, solo "gerente" |

- Dados: `Content.Restaurant.Flow` { `PartyMult` {1,0; 1,8; 2,5; 3,1}, `NightInterval` {30,29,28,27,26,26,25,25,24,24}, `Day1Interval` 22, `MaxCustomers` {5,7,9,9} }, `Content.Restaurant.Automation`.
- Critérios de aceite:
  - Solo N1: 16–20 tentativas (540 ÷ 30); 4p N1: 50–62.
  - Ativos mudam só no início do turno.
  - Com 3 ativos, nenhum Trainee no mundo; caindo para 2 no turno seguinte, ele volta (se comprado).
  - Nunca mais de 12 humanoides com IA vivos.
  - Playtest 2p e 4p: tempo parado (> 5 s sem ação útil) **< 25%** do turno por jogador (log de servidor).
  - Simulação solo: com a rota de upgrades, N10 ≥ 90% servidos; sem upgrades, 65–85%.

### FEAT-050 — Reabastecimento por caixas (telefone, van, escotilha)

- Status: Rascunho (Provisório) · Pilares: GERENCIAR, VENDER · Origem: DEC-276; Adendo 2; mudança do dono ("sem sair da loja, escotilha de serviço nos fundos")
- Resumo: o estoque das estações vem em **caixas** (DOGS, BUNS, MUSTARD... as que já existem no mapa). O jogador **liga** do
  telefone dos fundos, uma **van** encosta atrás da loja e põe as caixas na **escotilha de serviço**; de dentro, o jogador pega a
  caixa, leva à estação e faz **Restock**. Ninguém sai da loja.

| Regra | Valor (`Content.Restaurant.Supply`) |
|---|---|
| Telefone | o telefone fixo (DEC-124) nos fundos; prompt "Order Stock" (toque) abre o menu de interação (o mesmo do `InteractionMenu`): uma linha por caixa com preço e "+"; "Call" confirma (hold 0,5 s) |
| Caixas por pedido | até **4** (6 com UPG-031 nível 2); **1 pedido em trânsito** por vez (o telefone mostra "On the way 0:32") |
| Custo | **conteúdo = pacote do Mart**, mesmo preço (ITM-011 a ITM-019) + **$2 de entrega por pedido** |
| Conteúdo e preço por caixa | DOGS 8 / $6 · BUNS 8 / $4 · KETCHUP 20 usos / $4 · MUSTARD 20 / $4 · CHEESE 6 / $6 · BACON 6 / $9 · POTATO 10 / $5 · CREAM 8 / $6 · COFFEE 10 doses / $5; só ingredientes já liberados (`UnlockDay`) |
| Tempo de entrega | **45 s** (UPG-017: **30 / 18 s**) |
| Chegada | a van (veículo de roteiro, sem IA humanoide) para atrás da loja; as caixas deslizam para a **prateleira da escotilha** (6 lugares; o resto empilha do lado de fora e entra conforme abre lugar) |
| Pegar | "Take Box" (toque) na escotilha: `stock_box` na mão; **2 por jogador** (Hauler 3); UPG-032 Hand Truck: até **4** num só Tool, −15% de velocidade carregando |
| Restock | hold 1 s na estação do ingrediente (FEAT-007 sem mudança): transfere min(conteúdo, capacidade − atual); sobra fica na caixa; caixa vazia some (achata) |
| Avisos | contador "7/12" em cada estação (existe); com ≤ 25%, ícone de caixa pulsando na estação e toast "Low on Buns" 1× por estação por queda |
| Persistência | caixas na escotilha e na mão entram no snapshot do turno como estoque (DEC-080); não estragam (DEC-128) |
| Mart | recomendação: **o telefone substitui as prateleiras do Mart** como fonte de estoque, porque o jogador não sai da loja (Q-320, liga com Q-350). O Mart vira cenário (e pode seguir como palco de anomalia) |
| Estoque inicial | cheio (capacidade nível 1, DEC-049) + **1 caixa de DOGS e 1 de BUNS** já na escotilha no início da Night 1 (ensina o fluxo) |

Por que funciona em co-op e não pune o solo:

| Party | Consumo de salsichas por noite (N5 → N10) | Caixas DOGS por noite | Ligações | Papel |
|---|---|---|---|---|
| 1 | ~22 → 28 | ~3 → 4 (com Storage 2+ cabe numa ligação no começo e outra no meio) | ~2 | parte da rotina: 1 ligação a cada ~4 min, ~1,5 s de trabalho por pedido |
| 2 | ~38 → 50 | ~5 → 7 | ~3 | quem estiver mais livre |
| 4 | ~65 → 85 | ~8 → 11 | ~5 | **estoquista** quase fixo: telefone, escotilha, Restock e café para a crew |

Solo: o Storage (UPG-002) espaça as ligações; Big Boxes (UPG-031) e Express (UPG-017) reduzem a espera; o Trainee (UPG-033) faz
o estoque sozinho com ≤ 2 jogadores. Nada de estoque é perdido se o solo atrasar: só a estação fica parada.

- Dados: `Content.Restaurant.Supply` { `PhoneHold` 0,5, `MaxBoxes` 4, `MaxBoxesBig` {5,6}, `InTransit` 1, `Fee` 2, `Eta` 45, `EtaExpress` {30,18}, `HatchSpots` 6, `LowAt` 0,25, `StartBoxes` { dogs 1, buns 1 }, `MartShelves` false }; caixas usam `Content.Packages` (mesmo conteúdo e preço).
- Fora do MVP: pedido automático por assinatura, caixa danificada, fornecedor alternativo.
- Critérios de aceite:
  - Pedir 3 caixas debita exatamente Σ preços + $2; sem saldo, o servidor recusa com `not_enough_cash` e nada chega.
  - As caixas chegam à escotilha em 45 ± 1 s (30/18 com UPG-017); com um pedido em trânsito, o telefone não aceita outro.
  - Restock transfere até a capacidade; a sobra fica na caixa; caixa vazia some.
  - Com 2 caixas na mão, "Take Box" é recusado (Hauler: 3; com Hand Truck: 4 num Tool).
  - O jogador consegue fazer todo o ciclo telefone → escotilha → estação sem sair da loja.
  - Ingrediente ainda não liberado não aparece no menu do telefone.

---

## 3. Upgrades novos (UPG-015 a UPG-034)

Preços coerentes com o lucro da §4. DEC-006: o jogo é quase todo de noite; o Day 1 é tutorial. **Onde se compra** (Q-321):
o jogador não sai da loja, então o Gear Stand do Mart (DEC-101) fica fora de alcance. Recomendação: **o Gear Stand entra na loja**
(mesmos pedestais, num canto dos fundos; ferramentas e níveis) e **equipamento físico compra-se no lugar** (fantasma com preço,
`buy_in_place` já existe). Gear Stand mantém o cooldown de 1 turno por linha (Q-203); compra no lugar não tem cooldown.

### Índice

| ID | Upgrade | Níveis | Total | Libera | Onde | Efeito em 1 linha | Papel |
|---|---|---|---|---|---|---|---|
| UPG-015 | Second Grill | $120 | $120 | N2 | no lugar (`GRILL-2`) | 2ª grelha de barras, vagas do UPG-001 | grelha (party) |
| UPG-016 | Heat Lamp | $40 / $80 | $120 | N1 | no lugar | queima em 18 / 30 s (base 10) + apito 3 s antes | grelha |
| UPG-017 | Express Delivery | $40 / $80 | $120 | N2 | Gear Stand | entrega de caixas em 30 / 18 s (base 45) | estoque |
| UPG-018 | Long Tongs | $30 / $60 | $90 | N1 | Gear Stand | pilha de salsichas 5 / 8 (base 3) | grelha |
| UPG-019 | Bread Basket | $30 / $60 | $90 | N1 | Gear Stand | pilha de pães 5 / 8 (base 3) | pão |
| UPG-020 | Auto-Slicer | $110 / $100 | $210 | N3 | no lugar | corta 1 pão / 5 s → 3,5 s numa bandeja de 4 → 6 | pão (solo) |
| UPG-021 | Grill Bot | $150 / $120 | $270 | N4 | no lugar | põe cruas e tira prontas para a bandeja quente, 1 ação / 6 → 4 s | grelha (solo) |
| UPG-022 | Sauce Caddy | $70 | $70 | N2 | no lugar | ketchup e mostarda direto no prato-slot | condimentos (solo) |
| UPG-023 | Squeeze Pro | $50 / $80 | $130 | N3 | Gear Stand | tolerância dos condimentos +15 / +30%, guia −20 / −35% | condimentos |
| UPG-024 | Long Pass | $50 / $90 | $140 | N2 | no lugar | +2 / +4 pratos-slot e lugares de retirada (teto 12) | fila (party) |
| UPG-025 | Pickup Belt | $120 | $120 | N2 | no lugar | prato `Ready` vai sozinho dos condimentos à prateleira da retirada (6 s) | expedição (solo) |
| UPG-026 | Now Serving Board | $90 | $90 | N3 | no lugar | prato na prateleira da retirada chama o dono, que pega sozinho em 4 s | expedição (solo) |
| UPG-027 | Second Tablet | $90 | $90 | N3 | no lugar (`TAB-2`) | 2º tablet: 2ª cabeça `Q1B` na fila única (`Queue` com `Heads`, `TabletCount` 2) | caixa (party) |
| UPG-028 | Self-Order Kiosk | $120 / $140 | $260 | N3 | no lugar | 1 / 2 kiosks: o cliente pede sozinho em 12 s | caixa (solo) |
| UPG-029 | Drive-Thru Menu Board | $120 | $120 | N3 | no lugar | carro sem atendimento por 6 s pede sozinho em 12 s | drive-thru (solo) |
| UPG-030 | Lane Lights | $40 / $70 | $110 | N2 | no lugar | paciência do drive-thru +15 / +30 s; luz na pista | drive-thru |
| UPG-031 | Big Boxes | $50 / $90 | $140 | N2 | Gear Stand | caixa com ×1,5 / ×2 do conteúdo (mesmo preço por unidade); 5 / 6 caixas por ligação | estoque |
| UPG-032 | Hand Truck | $70 | $70 | N3 | Gear Stand | carrega até 4 caixas num Tool (−15% de velocidade) | estoque (party) |
| UPG-033 | Trainee | $140 | $140 | N4 | no lugar (placa "Help Wanted") | ajudante NPC estoquista: liga, pega na escotilha, Restock; só com ≤ 2 jogadores | estoque (solo/dupla) |
| UPG-034 | Quick Greeting | $35 / $70 | $105 | N1 | Gear Stand | diálogo −30 / −50% | caixa |
| | **Total novo** | | **$2.605** | | | | |

### Antigos (UPG-001 a UPG-014)

| ID | Destino | Detalhe |
|---|---|---|
| UPG-001 Grill | **adaptado** | vagas ativas e cozimento 12/10/8 s valem para todas as grelhas (com UPG-015) |
| UPG-002 Storage | **mantido, mais importante** | espaça as ligações de estoque (FEAT-050) |
| UPG-003 Counter | **obsoleto** (já fora de venda) | a fila é a do tablet; o 2º tablet é UPG-027 |
| UPG-004 Cash Drawer Lock | **obsoleto** (já fora de venda) | — |
| UPG-005 Trailer Lights | **adaptado → "Front Lights"** | luz sobre a fila, a retirada e as mesas: o salão fica legível de dentro à noite (OBSERVAR); a taxa ×1,1 de dia sai; $100 |
| UPG-006 Food Trailer | obsoleto (DEC-224) | — |
| UPG-007 / UPG-013 Coffee Maker | **mantidos** | cafeteira nos fundos |
| UPG-008, 009, 010, 011 (mesas, luz das mesas, Back Bar) | **obsoletos** | as 4 mesas são de fábrica e o jogador não vai ao salão |
| UPG-012 Security Camera | mantido (só desenho) | câmeras do salão, pista e escotilha (gancho) |
| UPG-014 Breaker Box | **mantido** | disjuntor nos fundos |

À venda no novo fluxo: mantidos $850 (Grill $210, Storage $340, Lights $100, Coffee $110, Breaker $90) + novos $2.605 =
**$3.455**. Solo compra ~37% (escolha), dupla ~58%, party de 4 ~85% (sem o Trainee, que não usa).

### Fichas

Todas: Status Rascunho (Provisório) · Origem: brief 2026-10-17 + mudança do dono · escopo `Restaurant` (não recomeça).
"Dia" = Day 1 (tutorial); onde não há efeito de dia, é exceção consciente a DEC-006 (como UPG-004).

#### UPG-015 — Second Grill
| Nível | Preço | Noite | Peça |
|---|---|---|---|
| 1 | $120 | +vagas (nível do UPG-001); dois grelhadores sem disputa | 2ª grelha de barras em `GRILL-2` |
- Aceite: vagas novas nascem vazias; comprar o UPG-001 depois sobe as duas.

#### UPG-016 — Heat Lamp
| Nível | Preço | `BurnAfter` | Apito | Peça |
|---|---|---|---|---|
| 0 | — | 10 s | não | — |
| 1 | $40 | 18 s | 3 s antes, só dentro da cozinha | lâmpada quente sobre a grelha |
| 2 | $80 | 30 s | idem | 2 lâmpadas |
- Noite: menos queimadas quando uma anomalia tira o grelhador da grelha. Aceite: salsicha já pronta passa a usar o novo valor, contado desde o `Ready`; o apito toca 1× por salsicha, 3,0 ± 0,2 s antes.

#### UPG-017 — Express Delivery
| Nível | Preço | Entrega | Peça |
|---|---|---|---|
| 1 | $40 | 30 s | ímã "Express" no telefone |
| 2 | $80 | 18 s | van pintada |
- Aceite: pedido feito depois da compra usa o novo tempo; o em trânsito não muda.

#### UPG-018 — Long Tongs · UPG-019 — Bread Basket
| Nível | Preço | Pilha | Peça |
|---|---|---|---|
| 0 | — | 3 | — |
| 1 | $30 | 5 | pegador longo / cesta média (na mão) |
| 2 | $60 | 8 | pegador cromado / cesta grande |
- Hauler +1 por cima. Aceite: coleta/corte enchem até a nova capacidade na hora.

#### UPG-020 — Auto-Slicer
| Nível | Preço | Ritmo | Bandeja | Peça |
|---|---|---|---|---|
| 1 | $110 | 1 pão / 5 s | 4 | fatiador ao lado do pão |
| 2 | $100 | 1 pão / 3,5 s | 6 | fatiador duplo |
- Consome estoque; para com bandeja cheia ou sem pão; nota de corte Good fixa (a mão vale mais). "Take Buns" enche a `bun_sliced`. Aceite: 4 pães em 20 ± 0,5 s (nível 1); sem pão = parado com ícone.

#### UPG-021 — Grill Bot
| Nível | Preço | Ritmo | Peça |
|---|---|---|---|
| 1 | $150 | 1 ação / 6 s | braço sobre a grelha |
| 2 | $120 | 1 ação / 4 s | braço duplo |
- Ação = pôr 1 crua (se a bandeja quente tem < 4) **ou** tirar a pronta mais perto de queimar para a bandeja quente; não vira (nota da salsicha Good fixa). Aceite: nível 2, 4 vagas, cozimento 8 s, ninguém por perto: nenhuma queimada em 5 min.

#### UPG-022 — Sauce Caddy
| Nível | Preço | Efeito | Peça |
|---|---|---|---|
| 1 | $70 | "Add Ketchup/Mustard #12" no prato-slot (hold 0,8 s, nota Good) | carrinho de molhos na ponta da mesa |
- Pedido só de molhos (ou K=0) vai da montagem direto à retirada. Aceite: queijo, bacon, batata e cream cheese ainda exigem a estação.

#### UPG-023 — Squeeze Pro
| Nível | Preço | Tolerância | Guia | Peça |
|---|---|---|---|---|
| 1 | $50 | +15% | −20% | garrafas novas |
| 2 | $80 | +30% | −35% | garrafas cromadas |
- Soma com Assist (teto +60%); `Grade` não muda, só a linha lida. Aceite: coberto por `/dev prep grade`.

#### UPG-024 — Long Pass
| Nível | Preço | Slots e lugares de retirada | Peça |
|---|---|---|---|
| 1 | $50 | +2 | extensão da mesa + 2 marcas no balcão |
| 2 | $90 | +4 (teto 12) | extensão dupla |
- Solo: quase sem efeito. Party: menos "Kitchen full". Aceite: slots e lugares novos ativos na hora.

#### UPG-025 — Pickup Belt
| Nível | Preço | Efeito | Peça |
|---|---|---|---|
| 1 | $120 | prato que fica `Ready` nos condimentos (ou na montagem, com UPG-022) vai sozinho à **prateleira da retirada** (6 lugares atrás do balcão) em 6 s | esteira rasa da parede do fundo ao balcão |
- O prato na esteira não pode ser servido até chegar. Sem UPG-026, alguém ainda entrega da prateleira ao cliente. Aceite: visível a todos; prateleira cheia = o prato espera no fim da esteira.

#### UPG-026 — Now Serving Board
| Nível | Preço | Efeito | Peça |
|---|---|---|---|
| 1 | $90 | prato na prateleira da retirada acende o "#n" no painel; o dono se aproxima e pega sozinho em **4 s**. Jogador entregando na mão continua instantâneo | painel "NOW SERVING" sobre a retirada |
- Ajuda, não substitui: 4 s de paciência por prato; a gorjeta só vale se cair na janela. Aceite: o cliente só pega o próprio #n; dupla pega os 2.

#### UPG-027 — Second Tablet
| Nível | Preço | Efeito | Peça |
|---|---|---|---|
| 1 | $90 | 2º tablet à esquerda do 1º, fila própria de 4 | tablet + suporte |
- Solo: quase nada (uma pessoa, um diálogo). 3–4 jogadores: tira o caixa do gargalo. Aceite: as duas filas dividem as chegadas pela menor fila.

#### UPG-028 — Self-Order Kiosk
| Nível | Preço | Efeito | Peça |
|---|---|---|---|
| 1 | $120 | kiosk no balcão (entre o tablet e a retirada): o cliente pede sozinho em **12 s**; só pega cliente quando o tablet está sem jogador há 3 s | totem amarelo |
| 2 | $140 | 2º kiosk | 2 totens |
- Paga ao confirmar como no tablet; respeita "Kitchen full". Aceite: com jogador no tablet, a fila vai ao tablet; nunca 2 kiosks no mesmo cliente.

#### UPG-029 — Drive-Thru Menu Board
| Nível | Preço | Efeito | Peça |
|---|---|---|---|
| 1 | $120 | carro sem atendimento por 6 s pede sozinho na placa (12 s) | placa iluminada na pista |
- Aceite: jogador no computador tem prioridade.

#### UPG-030 — Lane Lights
| Nível | Preço | Noite | Peça |
|---|---|---|---|
| 1 | $40 | paciência do drive-thru +15 s; `LightZone` na pista | cordão de luz |
| 2 | $70 | +30 s | + neon "Thank you" |

#### UPG-031 — Big Boxes
| Nível | Preço | Conteúdo por caixa | Caixas por ligação | Peça |
|---|---|---|---|---|
| 1 | $50 | ×1,5 (preço da caixa ×1,5) | 5 | caixas maiores (mesma arte, escala 1,2) |
| 2 | $90 | ×2 (preço ×2) | 6 | escala 1,4 |
- Mesmo custo por unidade: o ganho é menos idas. Aceite: DOGS nível 2 = 16 salsichas por $12.

#### UPG-032 — Hand Truck
| Nível | Preço | Efeito | Peça |
|---|---|---|---|
| 1 | $70 | Tool "Hand Truck" na escotilha: carrega até 4 caixas, −15% de velocidade com ele na mão; Restock direto do carrinho | carrinho de mão |
- Aceite: ocupa 1 vaga da hotbar; soltar devolve à escotilha.

#### UPG-033 — Trainee
| Nível | Preço | Efeito | Peça |
|---|---|---|---|
| 1 | $140 | NPC ajudante (avental) faz o **estoque**: liga quando uma estação cai a ≤ 25% (gasta o Cash da party, no máximo 1 ligação a cada 90 s), pega na escotilha, faz Restock; 70% da velocidade de um jogador | placa "Help Wanted" vira "Trainee on shift" |
- Só com **≤ 2 jogadores ativos** (em 3–4 fica fora e não conta no teto). Nunca monta nem entrega. Some 10 s nos fundos em anomalia de família B. Aceite: 3 ativos → nenhum Trainee; nunca liga com Cash < custo do pedido.

#### UPG-034 — Quick Greeting
| Nível | Preço | Efeito | Peça |
|---|---|---|---|
| 1 | $35 | diálogo −30% | cartão "Menu" ao lado do tablet |
| 2 | $70 | diálogo −50% (piso 1,5 s) | cartão plastificado |

---

## 4. Balanceamento

### 4.1 Lucro da run (solo; planilha, conferir no playtest)

Premissas: intervalos de FEAT-049; 80% completos (75% na N10 sem upgrades); margem + gorjeta **$5,60** por completo (preço
médio $7,67 − custo $2,63 + gorjetas ~$0,56, `economy.md` §5.0); ~10% das chegadas são anomalia; ~2 ligações de estoque por
noite (−$4).

| Noite | Duração | Intervalo | Chegadas | Completos | Lucro | Acumulado ($30 + Day 1 $56) |
|---|---|---|---|---|---|---|
| — | | | | | | $86 |
| 1 | 540 s | 30 | 18 | 14 | $76 | $162 |
| 2 | 580 s | 29 | 20 | 16 | $86 | $248 |
| 3 | 620 s | 28 | 22 | 18 | $95 | $343 |
| 4 | 660 s | 27 | 24 | 20 | $106 | $449 |
| 5 | 700 s | 26 | 27 | 21 | $116 | $565 |
| 6 | 740 s | 26 | 28 | 23 | $124 | $689 |
| 7 | 780 s | 25 | 31 | 25 | $136 | $825 |
| 8 | 820 s | 25 | 33 | 26 | $142 | $967 |
| 9 | 860 s | 24 | 36 | 29 | $156 | $1.123 |
| 10 | 900 s | 24 | 37 | 28 | $153 | **$1.276** |

Party (≈ multiplicador × 0,9): 2p ~$2.000 · 3p ~$2.600 · 4p ~$3.000 (hoje solo ~$820). Pacotes de Robux (`cash_*` $60/$150/$330)
ficam como estão até o primeiro playtest (Q-323 c).

### 4.2 Lucro por minuto por upgrade (solo, Night 6; comparável com `upgrades.md`)

Modelo: capacidade solo = 48 ÷ (s por pedido); base 24 s → 2,0/min = **$11,20/min**; demanda N6 2,3/min (o ganho satura nela;
nas N9–N10 a demanda é 2,5/min e os ganhos grandes rendem mais). Payback em minutos de noite (a run tem ~120).

| Upgrade | Preço | s poupados por pedido | Δ $/min solo | Payback (min) | Ganho estimado 4p |
|---|---|---|---|---|---|
| (base) | — | — | $11,20 | — | ~$34/min |
| UPG-034 Quick Greeting 1 | $35 | 1,3 | +0,64 | 55 | +3% (caixa é o mais cheio) |
| UPG-016 Heat Lamp 1 | $40 | ~1 + desperdício | +0,65 | 62 | +3% |
| UPG-018 Long Tongs 1 | $30 | 0,8 | +0,39 | 77 | +2% |
| UPG-019 Bread Basket 1 | $30 | 0,8 | +0,39 | 77 | +2% |
| UPG-022 Sauce Caddy | $70 | 1,5 | +0,75 | 93 | +2% |
| UPG-023 Squeeze Pro 1 | $50 | 0,8 + Perfect | +0,55 | 91 | +3% |
| UPG-025 Pickup Belt | $120 | 2,5 | +1,30 | 92 | +4% |
| UPG-026 Now Serving | $90 | 2 | +1,02 | 88 | +2% |
| UPG-028 Kiosk 1 | $120 | 2,7 | +1,40 | 86 | +4% |
| UPG-021 Grill Bot 1 | $150 | 3 + queimadas | +1,60 | 94 | +6% (libera 1 jogador) |
| UPG-020 Auto-Slicer 1 | $110 | 2 | +1,02 | 108 | +4% |
| UPG-033 Trainee | $140 | 1,5 + atenção | +0,75 | 187 | — (não existe em 3–4p) |
| UPG-017 Express 1 | $40 | ~0,5 (menos estação parada) | +0,24 | 167 | +3% |
| UPG-031 Big Boxes 1 | $50 | ~0,5 | +0,24 | 208 | +4% |
| UPG-032 Hand Truck | $70 | ~0,4 | +0,19 | 368 | +4% |
| UPG-029 Menu Board | $120 | 0,8 | +0,39 | 308 | +3% |
| UPG-030 Lane Lights 1 | $40 | — (menos carros perdidos) | +0,30 | 133 | +3% |
| UPG-015 Second Grill | $120 | ~0 solo | +0,10 | sumidouro | +6% |
| UPG-024 Long Pass 1 | $50 | ~0 solo | ~0 | sumidouro | +6% |
| UPG-027 Second Tablet | $90 | ~0 solo | ~0 | sumidouro | +8% (melhor de party) |

Leitura: no solo rendem mais **Quick Greeting**, **Heat Lamp**, **Kiosk**, **Grill Bot** e a dupla **Pickup Belt + Now
Serving**; na party, **Second Tablet**, **Second Grill**, **Long Pass** e os de estoque (o gargalo de 4 é espaço, caixa e
caixas). Paybacks (55–368 min) na faixa da tabela atual (37–293). No solo, o ganho que mais importa à noite é **atenção livre**
para as anomalias (menos sanidade perdida, DEC-277).

### 4.3 Tempo até cada desbloqueio (rota solo esperada)

Sem XP nem níveis (DEC-081): progresso = dinheiro + noite de liberação. Rota de planilha (compra no fim da noite):

| Fim de | Compra | Custo acumulado | Dinheiro acumulado | Sobra |
|---|---|---|---|---|
| Day 1 | Storage 2 ($40, lição das 18h) + Long Tongs 1 ($30) | $70 | $86 | $16 |
| Night 1 | Heat Lamp 1 ($40) + Quick Greeting 1 ($35) | $145 | $162 | $17 |
| Night 2 | Big Boxes 1 ($50) | $195 | $248 | $53 |
| Night 3 | Pickup Belt ($120) | $315 | $343 | $28 |
| Night 4 | Now Serving ($90) + Coffee 2 ($40) | $445 | $449 | $4 |
| Night 5 | Kiosk 1 ($120) | $565 | $565 | $0 |
| Night 6 | Grill 2 ($60) + Breaker 1 ($30) | $655 | $689 | $34 |
| Night 7 | Grill Bot 1 ($150) | $805 | $825 | $20 |
| Night 8 | Auto-Slicer 1 ($110) | $915 | $967 | $52 |
| Night 9 | Trainee ($140) | $1.055 | $1.123 | $68 |
| Night 10 | Express 1 ($40) + Storage 3 ($70) | $1.165 | $1.276 | $111 |

Party de 4 (~2,3× o dinheiro): fim da N3 ~$790 → Second Tablet, Second Grill, Long Pass 1, Heat Lamp, Tongs, Basket, Big Boxes;
fim da N6 ~$1.600 → quase todo o catálogo de party; sobra na N10 ~$300–600 (aceito, DEC-082).

### 4.4 Custo por tier

| Tier | Faixa | Upgrades | Quando o solo compra |
|---|---|---|---|
| T1 "primeira noite" | $30–$50 | 016-1, 017-1, 018-1, 019-1, 030-1, 031-1, 034-1, 023-1, 024-1 | Day 1–N3 |
| T2 "a loja anda sozinha" | $60–$100 | 022, 026, 027, 032, 016-2, 017-2, 018-2, 019-2, 023-2, 024-2, 030-2, 031-2, 034-2, 020-2 | N3–N6 |
| T3 "automação" | $110–$150 | 015, 020-1, 021, 025, 028, 029, 033 | N3–N9 |

---

## 5. Ordem de implementação recomendada (para o task-planner)

Princípio: cada onda deixa o jogo jogável e publicável; flag `Content.Restaurant.Enabled` volta ao trailer até o dono aprovar.

### Onda 0 — MVP: o loop novo roda numa noite curta (solo e 2p)

| # | Peça | Dono provável | Aceite mínimo |
|---|---|---|---|
| M1 | Blockout: prédio, balcão contínuo (`TAB-1` + `Q1..Q5` à direita, `PICKUP` + `PU-1..n` + pote à esquerda), 4 mesas, mesa de montagem 8 slots, grelha de barras, caixa de salsicha, pão + 1 tábua, 1 condimento, lixeira, fundos (telefone, escotilha, café, disjuntor, esconderijo); **sem porta para o salão** | level-designer | `/dev smoke` ok; NPC chega à fila, à retirada e às mesas pelo grafo; jogador não alcança o salão |
| M2 | `Content.Restaurant` (Flow, Tablets, Pass, Pickup, Grill, Stacks, Tables, Patience) + pedido #n e set de pedidos | architect | `modux check` limpo; set ≤ 14 registros, campos ≥ 7 bits |
| M3 | Pedido + prato-slot + fila de retirada (`Pickup.luau`) no servidor: confirmar e cobrar, órfão, "Kitchen full", estorno | backend | FEAT-044 aceites 1, 2, 4; FEAT-048 aceite 2 |
| M4 | Tablet: diálogo (texto + `blip`), nota do HUD com pop-up, acelerar, "#n" na cabeça | frontend + backend | FEAT-043 aceites 1, 3, 4, 5 |
| M5 | Estações **em prompt no mundo** (rollback B): grelha cru/pronto/queimado, corte por hold, pilhas, "Fill All", condimentos pelos prompts antigos | backend + frontend | FEAT-045 aceites 1–5 |
| M6 | Entrega no balcão: `pickup_serve` no `PICKUP` (e `serve` no rig do `PU-n`) com DELIVER "#n"; `Seating.SitAt = "Served"`, `DirtyTables = false`; senta/para viagem, 12 s, $1 no pote | backend + frontend | FEAT-046 aceites 1–5 |
| M7 | Fluxo por party, paciência e janela nova | backend | FEAT-049 aceites 1, 2, 4; FEAT-048 aceite 1 |
| M8 | Estoque mínimo: telefone com menu, van sem animação (caixas aparecem na escotilha após o tempo), "Take Box", Restock existente | backend + level | FEAT-050 aceites 1–3, 5 |

Fora do MVP: drive-thru, seções focadas, upgrades novos, tutorial novo (usar `/dev` para começar na Night 1). Anomalias: só as
que não dependem da janela/porta do trailer (Q-308) e respeitam DEC-277/278.

### Onda 1 — co-op redondo e progressão básica

Seções focadas por estação (Grill com queimar, Board em lote, Toppings) sobre o código atual; 2ª tábua e 2º condimento; Gear
Stand dentro da loja (Q-321); upgrades T1 + UPG-027, UPG-015, UPG-024 (`buy_in_place`); UPG-001/005 adaptados; métrica de
tempo parado; Mart sem prateleiras.

### Onda 2 — drive-thru e solo viável

FEAT-047 completo (carro, computador, buzina, estresse, pet); UPG-025, 026, 028, 022, 030, 031, 017; van animada; tutorial do
Day 1 reescrito (narrative-writer).

### Onda 3 — automação pesada e acabamento

UPG-020, 021, 029, 032, 033, 023; balanceamento por simulação (solo e 4p) e ajuste das tabelas.

---

## 6. Dados (resumo para o architect)

| Tabela `Content.Restaurant.*` | Campos principais |
|---|---|
| `Rules` | `Enabled`, `Sections` { `Grill`, `Board`, `Toppings` } (false na onda 0), `PlayersStayInside` true |
| `Flow` | `PartyMult`, `NightInterval[10]`, `Day1Interval`, `MaxCustomers[4]`, `Jitter` 0,25 |
| `Tablets`, `Pass`, `Pickup` | FEAT-043, FEAT-044, FEAT-046 |
| `Grill`, `Bun`, `Condiments`, `Stacks` | FEAT-045 |
| `Tables` | FEAT-046 |
| `DriveThru` | FEAT-047 |
| `Patience` | FEAT-048 |
| `Supply` | FEAT-050 |
| `Automation` | `KioskTime` 12, `KioskIdle` 3, `GrillBotEvery` {6,4}, `SlicerEvery` {5; 3,5}, `SlicerTray` {4,6}, `BeltTime` 6, `PickupShelf` 6, `NowServingWalk` 4, `TraineeSpeed` 0,7, `TraineeMaxPlayers` 2, `TraineeCallGap` 90, `MenuBoardAfter` 6, `MenuBoardTime` 12 |
| `Content.Upgrades` | UPG-015 a UPG-034 com `SoldAt` ("InPlace" / "Bench"), `UnlockNight`, `Scope = "Restaurant"`, `Effects` tipados (`BurnAfter`, `StackCap`, `PassSlots`, `DialogMult`, `DtPatience`, `SupplyEta`, `BoxMult`, `BoxCarry`, ...) |
| `Content.Prep.Tolerances` | + `grill_pickup` |
| `Content.Items` | + `bun_sliced`, `sausage_grilled`, `hot_dog`, `stock_box`, `hand_truck` |

---

## 7. Riscos

| Risco | Mitigação |
|---|---|
| Velocidade de entrega (prioridade do dono) | onda 0 em prompts no mundo, reusando handlers, `Seating`, `serve` e Restock |
| Caixa único vira gargalo em 4p | diálogo curto e acelerável; Second Tablet é T2 e "melhor de party"; medir fila média do tablet |
| Solo sobrecarregado nas noites finais | intencional até ~N5 (DEC-275); se o playtest mostrar < 65% servidos na N5, sobe-se `NightInterval` |
| Teto de NPC em 3–4p (fila + retirada + mesas) | `SitHeadroom` manda para viagem; plano B `Q-180` (Q-325) |
| Hotbar cheia | 2 pilhas + 2 pratos = 4; caixas e café disputam vaga: escolha visível; Hand Truck junta 4 caixas em 1 |
| Celular: muitos prompts na mesa de montagem e na retirada | prompt mais perto do centro da tela (DEC-066), "Fill All", DELIVER só no dono, lugares a ≥ 2,5 studs |
| Automação deixa a party ociosa | tetos de vazão, Trainee só ≤ 2p, métrica de tempo parado |
| Mart sem papel | vira cenário/palco de anomalia; Gear Stand dentro da loja |

---

## 8. Ganchos de classe (proposta; dono = `classes.md`)

| Classe | Hoje | No restaurante (teto ±12% mantido) |
|---|---|---|
| Rookie | régua | régua |
| Runner (Coelho) | velocidade | expedição e estoque |
| Line Cook (Gato) | grelha −15% | grelha −15% e `BurnAfter` +20% nas dele |
| Hauler (Urso) | 3 pacotes | 3 caixas e +1 nas pilhas |
| Hawker (Raposa) | gorjeta $2, janela −4 s | diálogo −20%, gorjeta $2, janela −4 s |
| Night Shift, Barista, Shift Lead | — | sem mudança |

---

## 9. Ganchos para anomalias (só citação; desenho em `anomalies-v3-restaurant.md`, em revisão)

Respeitar **DEC-278**: nada que se confunda com o fluxo normal (tablet que chama sozinho, prato a mais estão vetados).

- **Família A (cliente errado)**: o sinal pode estar no **diálogo do tablet** (frase estranha, item que não existe); recusa =
  **persiana do balcão** (Q-308 A), que manda embora a fila e a retirada.
- **Retirada**: número sobre a cabeça que não bate com nenhum pedido, cliente que nunca pagou parado na fila de retirada.
- **Drive-thru**: carro sem motorista, pet que não devia estar ali, carro que não vai embora.
- **Escotilha e van**: caixa que bate de dentro, van que chega sem ninguém ter ligado (o telefone mostra "no order").
- **Família B (esconder)** e **C (disjuntor)**: fundos da loja; a escotilha fecha junto.
- Kiosk (UPG-028) e Menu Board (UPG-029) atendem sem jogador: anomalia de família A não deve entrar por eles sem sinal visível.
- Saída forçada das seções focadas continua (`prep-mode.md` §5). Erro de anomalia = −sanidade (DEC-277).

---

## 10. Perguntas abertas (Q-320 a Q-329)

Nenhuma bloqueia o MVP; vale a recomendação, marcada **Provisória**. O secretário copia para `open-questions.md`.
Já abertas pelo secretário e seguidas aqui: **Q-307** (A), **Q-308** (A, com a persiana cobrindo atendimento + retirada),
**Q-309** (paga ao confirmar; "espera na mesa" superada pela mudança do dono), **Q-350** (ver Q-320).

| Q | Pergunta | Opções | Recomendação (Provisória) | Toca |
|---|---|---|---|---|
| **Q-320** | "Estoque infinito" e o Mart (detalha **Q-350**) | (a) **caixas pagas pelo telefone, mesmo preço do Mart + $2 de entrega; as prateleiras do Mart saem** · (b) caixas pelo telefone **e** Mart (mais barato, mas exige sair) · (c) estoque **infinito de verdade**: estações nunca acabam, sem custo de ingrediente · (d) caixas **grátis e ilimitadas**: só o trabalho de levar | **(a)**: o jogador não sai da loja, então o Mart fica fora; mantém o custo de ingrediente (maior sumidouro da economia) e cria o estoquista. (d) é o plano B se a economia apertar; (c) apaga um papel do co-op | DEC-276, DEC-049, DEC-101, DEC-131 |
| **Q-321** | Onde se compram os upgrades, se ninguém vai ao Mart? | (a) **Gear Stand entra na loja (fundos) + equipamento físico no lugar** · (b) tudo no lugar (fantasmas) · (c) tudo por um catálogo no telefone/computador | **(a)**; emenda DEC-101 (bancada do Mart) | DEC-101, Q-178, Q-203 |
| **Q-322** | Como se carrega na cozinha? | (A) **pilhas, pratos e caixas como Tools (hotbar 4)** · (B) mãos estilo Overcooked · (C) bandejas compartilhadas | **(A)** (FEAT-045) | DEC-174, FEAT-005 |
| **Q-323** | Escala por party e ritmo | (a) **1,0 / 1,8 / 2,5 / 3,1; noite 30 → 24 s** · (b) manter 1,0/1,6/2,1/2,5 e 40/36 s · (c) pacotes de Robux sobem com o fluxo maior | **(a)**; (c) só depois do 1º playtest | DEC-045, DEC-185, `economy.md` §5.0 |
| **Q-324** | Mesas depois da retirada | (a) **senta se houver mesa livre e folga no teto, senão para viagem; 2 grupos por mesa (nunca no mesmo banco); sem "Clean Table"** · (b) 1 grupo por mesa (FEAT-037) · (c) todos levam para viagem (mesas só cenário) | **(a)**, igual a `SitAt = "Served"` + `DirtyTables = false` do tech; responde a parte de mesa da **Q-351** (Clean Table); emenda FEAT-037 ("nunca estranhos na mesma mesa") | FEAT-037, Q-180, Q-309, Q-351 |
| **Q-325** | Ajudante NPC e teto | (a) **Trainee estoquista só com ≤ 2 jogadores; sentado conta no teto** · (b) Trainee para todos · (c) sentado fora do teto (`Q-180`) | **(a)**; (c) só se o playtest 4p tiver > 15% de `SkippedCap` | DEC-045, Q-180 |
| **Q-326** | Drive-thru: estreia e pet | (a) **Night 2; pet em 20% com "Pet" +10 s** · (b) desde o Day 1 · (c) pet só ambiente | **(a)** | DEC-274 |
| **Q-327** | Diálogo do tablet | (a) **texto + blip, ~4,4 s, ×2 apertando, ×1,6 depois de 8 pedidos** · (b) TTS por item (`frank`) · (c) com "Come again?" (`Q-227`) | **(a)** no MVP | DEC-270, Q-227 |
| **Q-328** | Paciência, gorjeta e estorno | (a) **preparo 75 + 5K (salão) / 70 + 5K (carro); janela de gorjeta 24 + 4K; estorno de 50% no Incompleto e 100% na desistência; gorjeta de mesa $1** · (b) manter 16 + 4K e pagar só na entrega | **(a)**: segue o "paga ao confirmar" da Q-309 com o mesmo líquido da DEC-072 | DEC-072, Q-192, Q-309 |
| **Q-329** | "O jogador não sai da loja" é absoluto? | (a) **sem porta para jogadores, dia e noite (Day 1 inclusive); só a escotilha e a janela do drive-thru passam objetos** · (b) porta existe, mas fora da loja à noite a sanidade cai rápido · (c) porta só de dia | **(a)**: mais simples, a loja é o ponto seguro único e o mapa externo vira só cenário; afeta ANM-010 (ponto seguro no Mart) e a família B, que o agente de anomalias revisa | DEC-279, DEC-196, Q-308 |
