Status: Rascunho

# Upgrades V3, blocos ABC, loja de brinquedos e pelúcias (proposta)

Autor: agente principal, 2026-10-20, a partir do pedido do dono na mesma data. Tudo **Provisório**: nada aqui vira Aprovado sem DEC.
Perguntas `Q-417` a `Q-422` respondidas em 2026-10-20: **DEC-329 a DEC-334** (ver `decisions.md`). Modelos dos verdes: os reais do trailer (DEC-331). Substitui, se aprovado, o índice de `upgrades.md` no modo anomalia
e a §14 de `bonds-proposal.md` (chave da mostarda + pet sem vantagem, `Q-280`).

## 0. O que existe hoje (conferido no código e no Studio, 2026-10-20)

| O quê | Onde | Estado |
|---|---|---|
| 5 upgrades à venda (Grill, Storage, Coffee Maker, Breaker Box, Trailer Lights) | `Content/Upgrades.luau`, `Content/Mode.luau` | funcionam; soma $850 |
| `trailer_lights` com `Name = "Patio Lights"` | `Upgrades.luau:179` | **bug de texto**: o pedestal B5 mostra o nome do UPG-009 |
| Storage = um nível só para **todos** os ingredientes (pão, salsicha, molhos, toppings) | `Ingredients.luau` `Capacity` | café fica fixo em 20 |
| Pedestal dourado S1 = Rescue Whistle (ITM-021, `revive_kit`), único item rotativo | `Content/Mart.luau:146` | funciona |
| Loja de brinquedos | `Workspace.MAP01_Assets.Extra.ToyStore` (≈ 60 × 45 studs, em −53, 171) | modelada, com prateleiras, caixa, área de brincar e **blocos de letras** (`LetterBlock`, `ToyBlock`). Sem mecânica |
| "Upgrade ABCD" relatado | — | **não existe** no código nem no Studio (busca por nome, atributo e texto). A leitura mais provável: o relato viu os `LetterBlock` da vitrine da loja. Não é upgrade |
| Espécies jogáveis | `Content/Species.luau` | dog, rabbit, cat, bear, fox, owl, panda, lion. **Não há lobo** |
| Gemas | `GemRewards.luau`, `Classes.luau` | escala ×75 (TASK-308): run perfeita ≈ 28.650; classes de 2.000 a 20.000. **Vendidas por Robux** (`Shop.luau`) |

## 1. Gear Stand novo

Regra visual: **pedestais verdes = upgrade simples** (3 níveis, o nível 1 vem de fábrica, compra-se o 2 e o 3).
**Pedestal dourado (S1) = especial**, com raridade, um por dia.

### 1.1 Pedestais verdes (B1–B5)

| Slot | Upgrade | Nível 1 (fábrica) → 2 → 3 | Preço 2 / 3 | Modelos novos |
|---|---|---|---|---|
| B1 | **Grill** (UPG-001, mantém) | 2 → 3 → 4 espaços; 8 → 6 → 4 s | $60 / $150 | grelha L1, L2, L3 (troca dos atuais) |
| B2 | **Bun Box** (UPG-035; pão + salsicha juntos, um por pão) | 12 → 20 → 28 | $50 / $110 | caixa de pão L1–L3 |
| B3 | **Topping Rack** (UPG-036; todos os molhos e toppings juntos) | molhos 15 → 25 → 35; toppings ≈ metade → dobro (tabela da §1.3) | $50 / $110 | prateleira de potes L1–L3 |
| B4 | **Coffee Shelf** (UPG-037; estoque de café) | 20 → 30 → 40 | $40 / $80 | prateleira de copos L1–L3 |
| B5 | **Breaker Box** (UPG-014, mantém o efeito) | segurar 3 → 2 → 1 s no apagão | $30 / $60 | Breaker_L1/L2 já existem; padronizar com os outros |

Soma dos verdes: **$740** (hoje $850). Saem de venda (código fica, como no `DayOnly`): **Storage** (vira Bun Box + Topping Rack),
**Coffee Maker de velocidade** (UPG-013; vira Coffee Shelf + máquina dupla) e **Trailer Lights** (UPG-005; o efeito de dia não
serve a um jogo de noite). Recomendação em `Q-417`.

**IDs (TASK-607, Provisório):** Bun Box **UPG-035**, Topping Rack **UPG-036**, Coffee Shelf **UPG-037** (UPG-015 a UPG-034 estão
reservados em `restaurant-flow.md` §3). Chaves `bun_box`, `topping_rack`, `coffee_shelf`; o Breaker Box vai de B4 para B5.

### 1.2 Pedestal dourado (S1): especial do dia

Cada manhã sorteia **um** especial. A raridade aparece na cor do brilho do pedestal e na etiqueta.

| Especial | Raridade | Chance no sorteio | Preço | Efeito | Compra |
|---|---|---|---|---|---|
| **Rescue Whistle** (ITM-021, já existe) | Rara (azul) | 50% | o atual | revive (consumível) | várias vezes |
| **Double Coffee Machine** | Épica (roxo) | 35% | $250 | 2ª máquina ao lado da atual; dois cafés ao mesmo tempo | 1 por run; depois sai do sorteio |
| **ABC Blocks** | Mítica (dourado) | 15% | $150 | easter egg: abre a loja de brinquedos (§2) | 1 vez; depois sai do sorteio |

Garantia: se a run chegar ao **Dia 4** sem os ABC Blocks terem aparecido, eles aparecem no Dia 4 (o achado continua raro, mas
ninguém fica sem). Modelo da 2ª máquina: **clone da cafeteira atual** posto ao lado (pedido do dono; sem modelo novo).

**Balanço do café com duas máquinas.** Hoje: 1 máquina, 6 s por café = 10 cafés/min. Proposta: com a máquina dupla, **cada máquina
leva 8 s** (2 × 7,5 = 15 cafés/min, +50%, não +100%). Sem máquina dupla, continua 6 s. O ganho vem de poder fazer dois de uma vez,
não de cada um ficar mais rápido.

### 1.3 Topping Rack: capacidades por nível

| Ingrediente | N1 | N2 | N3 |
|---|---|---|---|
| ketchup, mustard | 15 | 25 | 35 |
| cheese, bacon | 5 | 7 | 9 |
| potato sticks | 6 | 12 | 18 |
| cream cheese | 6 | 10 | 14 |

(Os mesmos números de hoje, nos níveis 1, 3 e 5 do Storage.)

## 2. ABC Blocks e a loja de brinquedos

| Regra | Valor (Provisório) |
|---|---|
| Visual no pedestal | três blocos de madeira cartoon, cores vivas, letras A, B, C (um pouco tortos, empilhados) |
| Ao comprar | os blocos somem do pedestal; som de brinquedo; Opal: "Toy store's been shut for years. Huh." (narrative-writer revisa) |
| O que abre | a porta da `ToyStore` destranca (correntes caem, ≤ 2 s) |
| Persistência | **para sempre, por jogador** (campo no perfil). Em co-op, a porta abre se **qualquer** jogador da party tiver. Quem já tem vê o pedestal com "Owned" e os blocos não entram mais no sorteio dele (`Q-418`) |
| Chave da mostarda (§14 de `bonds-proposal.md`) | **sai do escopo**. A fala do Walt fica como sabor. Alternativa em `Q-418` |
| Quando dá para entrar | qualquer turno. À noite atravessar a rua tem o risco normal; a loja não é ponto seguro |

## 3. Gacha de pelúcias (dentro da loja)

### 3.1 Como funciona

- Na loja há um **baú de brinquedos** grande (ou máquina de cápsula, decisão do art-director). Prompt "Open — {preço} gems".
- Abrir = animação curta do baú sacudindo, luz da raridade, a pelúcia pula para fora.
- A pelúcia fica **flutuando sobre o ombro** (balanço 0,15 stud a 1,2 Hz, olha para onde o dono olha). Sem colisão, sem som em loop.
- **Uma equipada por vez.** Trocar na própria loja e na tela de perfil do lobby.
- Pelúcias ficam **no perfil, para sempre**.
- Repetida: sobe uma **estrela** (máx. 3; o perk ×1,5 com 2★ e ×2 com 3★). Repetida de pelúcia já 3★ devolve 30% das gemas.
- Garantia: o **10º baú** seguido sem Épica ou Mítica entrega uma Épica.
- **As chances aparecem na tela antes de abrir.** Como as gemas também são vendidas por Robux, é obrigatório pelas regras do Roblox
  para itens aleatórios pagos. Não é opcional.

### 3.2 Preço

O dono pediu 100 gemas. Na escala atual (×75, TASK-308), 100 gemas são **0,3% de uma run perfeita**: daria para abrir quase 300 baús
por run. Equivalente na escala de hoje: **100 × 75 = 7.500**. Recomendação: **2.500 gemas** por baú (abaixo da classe mais barata,
2.000–3.000, ou seja, um baú por run boa). Escolha em `Q-419`.

### 3.3 Pelúcias e perks

Miniatura fofa de cada espécie jogável + **Lobo** como Mítica exclusiva (não é classe; modelo novo). Perks pequenos (≤ 10%): o jogo é
para crianças e em co-op, e a pelúcia não pode valer mais que a classe.

| Pelúcia | Raridade | Chance | Perk (1★) |
|---|---|---|---|
| Dog | Comum | 18,3% | +5% dinheiro por venda |
| Cat | Comum | 18,3% | +10% chance de gorjeta |
| Rabbit | Comum | 18,3% | +5% velocidade de andar |
| Bear | Rara | 10% | −10% perda de sanidade |
| Fox | Rara | 10% | +10% gemas no fim da noite |
| Owl | Rara | 10% | +10% paciência dos clientes |
| Panda | Épica | 6% | café 15% mais rápido |
| Lion | Épica | 6% | +10% dinheiro por venda |
| **Wolf** | **Mítica** | 3% | +10% dinheiro e +10% gorjeta; brilho leve |

Totais: Comum 55%, Rara 30%, Épica 12%, Mítica 3%. Perks valem só para o dono da pelúcia (não para a party) e não somam com
o perk igual da classe além de um teto (game-designer define). Conflito: `Q-280` (d) dizia "o pet não dá vantagem nenhuma".
O pedido de 2026-10-20 inverte isso → `Q-420`.

## 4. NPC da banca (Gear Stand)

Hoje ninguém atende a banca; a Opal fica no caixa do Mart. Opções (`Q-421`):

- **(a) Quick Quentin reformado** [recomendado]: o guaxinim ladrão saiu do jogo (DEC-313), mas o modelo, o chapéu e as texturas
  existem. Volta "de bem", vendendo equipamento: liga à história sem ser personagem-chave e custa quase nada de arte. Falas novas
  com o narrative-writer ("Totally legal gear. Receipts and everything.").
- **(b) Personagem novo**: um mecânico (coala ou macaco, espécies de NPC já existentes) que conserta o trailer do Walt há anos.
  Precisa de ficha CHR, roupa e falas.
- A Raincoat Lady **não** (é personagem-chave, `ending.md`).

## 5. Lista de modelos (para o art-director → modeler-3d)

| Asset | Qtd. | Observação |
|---|---|---|
| Grill L1–L3 | 3 | troca dos atuais; a diferença de nível tem que ler de longe (mais bocas, mais cromado) |
| Bun Box L1–L3 | 3 | caixa de pão + bandeja de salsicha |
| Topping Rack L1–L3 | 3 | potes de molho e toppings |
| Coffee Shelf L1–L3 | 3 | prateleira de copos/pacotes |
| Breaker Box L0–L2 | 2 | já existem; padronizar com o resto |
| Double Coffee Machine | 0 | clone da cafeteira atual, ao lado |
| ABC Blocks | 1 | display do pedestal + versão grande na vitrine |
| Correntes e cadeado da porta da loja | 1 | estilo cartoon, cai na animação |
| Baú de brinquedos (gacha) | 1 | com tampa animável |
| Pelúcias | 9 | 8 espécies + lobo; ≈ 0,8 stud; costura e botão visíveis |
| NPC da banca | 0–1 | 0 se for o Quentin |
| Display do pedestal (versão miniatura de cada upgrade) | 5 | ou reaproveitar o L2 em escala reduzida |

Antes de modelar do zero: conferir `Assets/KitchenPack` e `Assets/FoodPack` (`CLAUDE.md`).

## 6. Ordem sugerida de implementação

1. **Feito (TASK-607, 2026-10-20; falta o Studio).** Bug de texto do B5 (`Name = "Trailer Lights"`) e troca dos upgrades verdes
   (dados em `Upgrades.luau`, `Ingredients.luau`, `Mode.luau`, `Stats.luau`; `Mode.RetiredUpgrades`). Usa os modelos atuais até
   chegarem os novos. Pendente no Studio: pedestais e peças (lista em `tasks/board.md`, TASK-607).
2. Pedestal dourado com sorteio por raridade + Double Coffee Machine (clone).
3. ABC Blocks + porta da loja + flag no perfil (architect: migração de perfil).
4. Gacha: baú, tabela `Content.Plushies`, perfil (`Plushies`, `EquippedPlush`), seguidor no ombro, perks via `Stats`.
5. NPC da banca.
6. Modelos novos entram conforme ficam prontos (a troca é só de `Part` na tabela de níveis).
