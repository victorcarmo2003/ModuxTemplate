Status: Rascunho

# Sourcing de assets prontos — 2026-10-11

Pedido do usuário: trocar props montados à mão com Parts por modelos de packs low-poly cartoon com licença verificada.
Tudo abaixo é **candidato** (Provisório): nada foi importado nem aprovado. Licenças em `credits.md` (linhas de 2026-10-11).
Não foi usado Sketchfab. Os previews do Poly Pizza (`preview.jpg`) são o pôster oficial da página de cada modelo.

## Packs baixados nesta rodada

| Prefixo | Pasta | Licença | Formatos | Preview |
|---|---|---|---|---|
| `FK/` | `Assets/FurnitureKit` (Kenney Furniture Kit 2.0) | CC0 | FBX, GLTF, OBJ, DAE | `Isometric/<nome>_SW.png` (e NE/NW/SE), `Side/` |
| `NK/` | `Assets/NatureKit` (Kenney Nature Kit 2.1) | CC0 | FBX, GLTF, OBJ, DAE | `Isometric/<nome>_SW.png` |
| `SK/` | `Assets/SurvivalKit` (Kenney Survival Kit 2.0) | CC0 | FBX, GLB, OBJ | `Previews/<nome>.png` |
| `KF/` | `Assets/KayKitFurniture` (KayKit Furniture Bits 1.0) | CC0 | **só GLTF e OBJ** | nenhum |
| `KC/` | `Assets/KayKitCityBits` (KayKit City Builder Bits 1.0) | CC0 | **só GLTF e OBJ** | nenhum |
| `PP/` | `Assets/PolyPizza/<Nome>_<id>/` (modelos avulsos) | CC0 ou **CC-BY 3.0** (ver `License.txt` de cada pasta) | **só GLB** | `preview.jpg` na pasta |

Packs já existentes usados como referência: `MM/` Mini Market, `KP/` KitchenPack (KayKit Restaurant Bits), `FP/` Food Kit, `CC/`/`CS/`/`CR/` City Kits.

**Conversão necessária (modeler-3d, Blender → FBX):** tudo de `KF/`, `KC/` e `PP/` (GLTF/GLB). Kenney Furniture/Nature são
kits antigos com cor por **material** (sem atlas `colormap`), diferentes dos Kenney novos: na importação, cada material vira
uma Part/MeshPart com cor própria ou é remapeado para um atlas existente. KayKit Furniture/City usam atlas de gradiente
**igual ao do KitchenPack** (`furniturebits_texture.png`, `citybits_texture.png`): é o par mais coerente com o que já temos.

Atenção à mistura de autores (skill de pipeline: "mixing authors breaks the style"): J-Toastie, Quaternius, Dave Edwards e
Poly by Google têm sombreamento e paleta diferentes. Recolorir no atlas KayKit (como no AST-042/AST-098) resolve.

---

## 1. Mesa de piquenique / mesa externa com bancos (atrás do carrinho)

| | Candidato | Arquivo | Tris / tamanho | Preview | Licença |
|---|---|---|---|---|---|
| **★ recomendado** | Picnic Table **com toalha xadrez** (mesa + bancos numa peça) | `Assets/PolyPizza/PicnicTable_GQieALI2C4/PicnicTable.glb` | 832 tris | `Assets/PolyPizza/PicnicTable_GQieALI2C4/preview.jpg` | CC-BY 3.0, J-Toastie (crédito obrigatório) |
| alternativa | Picnic Table lisa (madeira clara) | `Assets/PolyPizza/PicnicTable_LM6QWe8kFT/PicnicTable.glb` | 428 tris | `.../PicnicTable_LM6QWe8kFT/preview.jpg` | CC-BY 3.0, J-Toastie |
| alternativa CC0 | mesa + cadeiras KayKit (`table_medium_long` + `chair_A_wood`/`chair_stool_wood`) | `Assets/KayKitFurniture/gltf/table_medium_long.gltf`, `chair_A_wood.gltf` | baixo (KayKit) | — | CC0 |

A toalha vermelho/branco combina com a barraca de hot dog; para ficar só CC0, montar com KayKit Furniture (mesmo atlas do KitchenPack).
Banco solto CC0: `Assets/KayKitCityBits/gltf/bench.gltf` ou `Assets/FurnitureKit/Models/FBX format/bench.fbx` (preview `Assets/FurnitureKit/Isometric/bench_SW.png`).

## 2. Arbustos, plantas em vaso, floreiras

| | Candidato | Arquivo | Tris / tamanho | Preview | Licença |
|---|---|---|---|---|---|
| **★ recomendado (floreira)** | Planter & Bushes (caixote de madeira com 3 arbustos) | `Assets/PolyPizza/PlanterBushes_wn85Xr9lM3/PlanterBushes.glb` | 622 tris | `.../PlanterBushes_wn85Xr9lM3/preview.jpg` | CC-BY 3.0, J-Toastie |
| **★ recomendado (vaso)** | Potted plant Kenney | `Assets/FurnitureKit/Models/FBX format/pottedPlant.fbx` | ~24 KB | `Assets/FurnitureKit/Isometric/pottedPlant_SW.png` | CC0 |
| alternativa (arbusto solto) | Bush (Quaternius, cheio, folhas) / Bush with Flowers | `Assets/PolyPizza/Bush_ooG6CkLyE8/Bush.glb`; `Assets/PolyPizza/BushWithFlowers_U1ymDy8tbY/BushWithFlowers.glb` | 360 / 1368 tris (o com flores tem 810 KB, textura) | `preview.jpg` de cada pasta | CC0 |

Outros CC0 leves: `Assets/NatureKit/Models/FBX format/plant_bush.fbx`, `plant_bushDetailed.fbx`, `plant_bushLarge.fbx`, `pot_large.fbx`, `pot_small.fbx`,
`flower_redA.fbx` (previews `Assets/NatureKit/Isometric/<nome>_SW.png`); `Assets/KayKitCityBits/gltf/bush.gltf` (arbusto redondo no atlas KayKit);
cactos `Assets/KayKitFurniture/gltf/cactus_medium_A.gltf`, `cactus_small_A.gltf`. Já aprovado antes: `CS/planter` (DEC-139).

## 3. Caixa registradora / balcão de checkout do mercado

| | Candidato | Arquivo | Tris / tamanho | Preview | Licença |
|---|---|---|---|---|---|
| **★ recomendado** | Balcão KayKit `kitchencounter_straight_A` (ou `_B`) + `MM/cash-register` em cima | `Assets/KitchenPack/Assets/fbx/kitchencounter_straight_A.fbx` + `Assets/MiniMarket/Models/FBX format/cash-register.fbx` | baixo | `Assets/MiniMarket/Previews/cash-register.png` | CC0 (packs já aprovados) |
| alternativa | Counter Straight Quaternius (madeira, frente de tábuas) como base do checkout | `Assets/PolyPizza/CounterStraight_zpURbFzEbv/CounterStraight.glb` | 464 tris | `.../CounterStraight_zpURbFzEbv/preview.jpg` | CC0 |
| alternativa "bonita" | Cash register antiga (preta e dourada, teclas) | `Assets/PolyPizza/CashRegister_crXBxFOkCIp/CashRegister.glb` | 3194 tris, 523 KB | `.../CashRegister_crXBxFOkCIp/preview.jpg` | CC-BY 3.0, Poly by Google |

A registradora antiga é a mais "charmosa", mas pesa 3,2k tris e destoa do POS preto do carrinho (AST-020, DEC-155).
Para o caixa do mercado (AST-031), a combinação KayKit + `MM/cash-register` mantém o estilo dos packs aprovados.
O balcão `FK/kitchenBar.fbx` (preview `Assets/FurnitureKit/Isometric/kitchenBar_SW.png`) também serve como módulo.

## 4. Máquina de café (trailer e mercado)

| | Candidato | Arquivo | Tris / tamanho | Preview | Licença |
|---|---|---|---|---|---|
| **★ recomendado** | Coffee Machine espresso (preta, braço de porta-filtro, bandeja) | `Assets/PolyPizza/CoffeeMachine_7kKSsnCcNC/CoffeeMachine.glb` | 872 tris | `.../CoffeeMachine_7kKSsnCcNC/preview.jpg` | CC-BY 3.0, J-Toastie |
| alternativa | Coffee Machine de filtro (jarra) | `Assets/PolyPizza/CoffeeMachine_EWVe4TaOiB/CoffeeMachine.glb` | 1786 tris | `.../CoffeeMachine_EWVe4TaOiB/preview.jpg` | CC-BY 3.0, J-Toastie |
| alternativa CC0 | Kenney kitchenCoffeeMachine | `Assets/FurnitureKit/Models/FBX format/kitchenCoffeeMachine.fbx` | ~34 KB | `Assets/FurnitureKit/Isometric/kitchenCoffeeMachine_SW.png` | CC0 |

Mesmo autor do POS do carrinho (J-Toastie, já creditado): coerência boa. A de filtro com jarra lê melhor "café de lanchonete" no trailer; a espresso fica melhor no mercado.

## 5. Mobiliário de mercado por seção

| Seção | ★ recomendado | Alternativas |
|---|---|---|
| Laticínios (queijo, cream cheese) — geladeira vertical com porta de vidro | **Can Fridge** Quaternius, `Assets/PolyPizza/CanFridge_8OHbykvREu/CanFridge.glb` (2784 tris; já vem com produtos coloridos; preview `.../preview.jpg`), CC0 | `MM/freezers-standing.fbx` (já aprovado AST-030; preview `Assets/MiniMarket/Previews/freezers-standing.png`); Supermarket Freezer Dave Edwards `Assets/PolyPizza/SupermarketFreezer_94OfwJ1WL5t/SupermarketFreezer.glb` (573 tris, vitrine branca vazia, CC-BY) |
| Pães (rack) | **`MM/display-bread.fbx`** (já aprovado; preview `Assets/MiniMarket/Previews/display-bread.png`) + pães `FP/` | Shelf Tall Quaternius `Assets/PolyPizza/ShelfTall_TDgvIuorcX/ShelfTall.glb` (536 tris, CC0); Shelves J-Toastie (rack metálico com tábuas) `Assets/PolyPizza/Shelves_OD78iJOQoN/Shelves.glb` (2632 tris, CC-BY) |
| Carnes/salsichas (refrigerado) | **`MM/freezer.fbx`** horizontal (já usado no AST-018) com `FP/` salsichas/bacon dentro | KayKit `KP/fridge_A_decorated.fbx`; caixotes `KP/crate_ham.fbx`, `KP/crate_steak.fbx` ao lado |
| Molhos/condimentos (ketchup, mostarda) | **`MM/shelf-boxes.fbx`** + `KP/ketchup.fbx`, `KP/mustard.fbx`, `FP/` garrafas nas prateleiras | Shelf Tall Quaternius (acima); `KF/shelf_B_large.gltf` |
| Batata palha / salgadinhos | **`MM/shelf-bags.fbx`** (já vem com sacos; preview `Assets/MiniMarket/Previews/shelf-bags.png`) | `MM/shelf-end.fbx` como ponta de gôndola |
| Bacon | `MM/freezer.fbx` (mesmo da carne) ou `KP/fridge_B.fbx` | `KP/crate_ham.fbx` |
| Placas de seção de corredor | **não há modelo pronto adequado** nos packs nem no Poly Pizza (só placas de madeira medievais) | placa suspensa simples (caixa chanfrada + 2 correntes) feita pelo modeler-3d, texto por decal da folha AST-072 (style guide §1.1: sem texto modelado) |

## 6. Porta de enrolar (roller shutter / persiana de loja)

**Não encontrada** em Kenney, KayKit, Quaternius nem Poly Pizza (buscas "shutter", "roller door", "garage door": só portas
comuns e "Window blinds"). O modeler-3d faz no Blender: lâminas horizontais (10–14 réguas, chanfro), caixa do rolo em cima,
trilhos laterais; cor pelo atlas do projeto/KitchenPack. Alternativa provisória: `KP/wall_window_closed.fbx` (janela com persiana fechada do KayKit).

## 7. Pedestais/expositores de vitrine (item de upgrade flutuando)

| | Candidato | Arquivo | Tris | Preview | Licença |
|---|---|---|---|---|---|
| **★ recomendado** | Column Round (coluna baixa com capitel largo) | `Assets/PolyPizza/ColumnRound_n8ZvVFcJhl/ColumnRound.glb` | 332 | `.../ColumnRound_n8ZvVFcJhl/preview.jpg` | CC0 (Quaternius) |
| alternativa | `MM/column.fbx` (coluna cilíndrica do Mini Market) | `Assets/MiniMarket/Models/FBX format/column.fbx` | baixo | `Assets/MiniMarket/Previews/column.png` | CC0 |
| alternativa | `KP/pillar_A.fbx` (já aprovado no AST-044) cortado na altura da cintura | `Assets/KitchenPack/Assets/fbx/pillar_A.fbx` | baixo | — | CC0 |

Recolorir no atlas (topo Mustard/creme) para combinar com a bancada de upgrades; o pedestal grego "Pedestal" da Quaternius foi descartado (ornamentado demais).

## 8. Barril (opcional)

| | Candidato | Arquivo | Tris / tamanho | Preview | Licença |
|---|---|---|---|---|---|
| **★ recomendado** | Kenney Survival `barrel` | `Assets/SurvivalKit/Models/FBX format/barrel.fbx` | ~34 KB | `Assets/SurvivalKit/Previews/barrel.png` | CC0 |
| alternativa | Barrel Quaternius (madeira com aros) | `Assets/PolyPizza/Barrel_ONdghDBByN/Barrel.glb` | 1384 | `.../Barrel_ONdghDBByN/preview.jpg` | CC0 |

O barril Kenney é atlas `colormap` (estilo dos Kenney novos, igual ao Mini Market) e é o único com FBX direto.

---

## Resumo de crédito obrigatório (se escolhidos)

J-Toastie (Picnic Table, Planter & Bushes, Coffee Machine, Shelves) — já está nos créditos pelo POS ·
Dave Edwards (Supermarket Freezer) · Poly by Google (Cash register). Texto padrão em `credits.md`.

## Próximo passo

1. Usuário escolhe por necessidade (board de aprovação, skill `roblox-asset-pipeline`).
2. modeler-3d converte os GLB/GLTF escolhidos para FBX (`Assets/blender/<cat>/AST-###_*.blend` → `Assets/models/<cat>/`), recolor se preciso.
3. Escolhas viram fichas/linhas em `asset-list.md` e `credits.md` "Usado em"; os não escolhidos podem ser apagados de `Assets/PolyPizza/`.
