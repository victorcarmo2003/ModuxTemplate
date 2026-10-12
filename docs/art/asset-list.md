Status: Rascunho

# Lista de assets — MVP

Autor: art-director. Criada em 2026-10-08; conciliada com DEC-073 a DEC-105, `story/`, `design/` e `levels/MAP-01.md` §12 em 2026-10-08.
Revisão 2026-10-08 (`consistency-report.md` §4): DEC-106 a DEC-129 (médicos na ida, DEC-114; semáforo, DEC-120; noite perdida sem banco, DEC-122; telefone, DEC-124; bancada, DEC-106; Revive Kit, DEC-108/DEC-129), medidas e nomes do `MAP-01.md` revisão 2. Fichas novas: AST-076, AST-077.
Ajuste final 2026-10-08: **DEC-130** (sem semáforo; revoga DEC-120) → AST-077 **Obsoleto**; **rodada 17** (postes da Juniper a cada 8 studs, último a ~135; DEC em registro) → AST-036 e AST-064; Juniper Sul aberta a carros, sem cerca do beco → AST-047; MAP-01 revisão 3 §15 P34/P36 → AST-028, AST-040, AST-044, AST-049.
2026-10-10, **DEC-140**: versões modeladas aprovadas — AST-013, 016, 020, 022, 023, 025, 037, 038, 039, 042, 051, 068 → Aprovado; peças avulsas de AST-034, AST-036 (cúpula) e AST-052 (maca); garrafas AST-004/005 translúcidas com `Fill` animado.
2026-10-10, **DEC-141**: rodada 3 de modelados aprovada — modelos de AST-001 a 010, 061 (comida editada e coberturas), 014, 017, 018, 019, 049 (equipamentos), 035, 065, 052, 045 (+ volume do AST-044), 050 (otimizações da DEC-139), **AST-026 (casca)** e **AST-027 (trailer, Rascunho → Aprovado)**. AST-066 segue Rascunho (porta está no arquivo do trailer). Pendências em `Q-138`, `Q-139`, `Q-140`; AST-043 em `Q-082`.
Regras de estilo, paleta, escala, nomes, encaixes e orçamento: `style-guide.md` (**Aprovado**, DEC-126; estilo toy low-poly decidido em DEC-105; R6 em DEC-089/DEC-097).
Toda ficha começa **Rascunho**. Só vai para a fila do `modeler-3d` com status **Aprovado** pelo usuário.

Status por ficha: `Rascunho` → `Aprovado` → `Modelando (modeler-3d)` → `Em revisão` → `Pronto p/ import` (ou `Reprovado: <nota>`). `Obsoleto` = ficha revogada por DEC; fica no documento como histórico, não vai ao modelador e o ID não é reaproveitado.

Origem:
- **Pack** = arquivo do pack sem mexer na malha (só escala, pivô, attachments).
- **Pack + edição** = parte do pack, com recorte, recolor, peça nova ou remapeamento para o atlas do projeto.
- **Modelar** = do zero (o pack pode servir só de referência de estilo).
- **Plataforma** = rig/corpo R6 do Roblox; a ficha pede só acessórios, decals e configuração.

Prioridade: **P0** = dia jogável (vertical slice) · **P1** = trailer, noite, anomalias, final · **P2** = pode entrar como placeholder cinza.

Espaço jogável manda o level design: medidas de veículo, estações e ruas seguem o `MAP-01.md` (Rascunho, em atualização pelo level-designer).
Quando o MAP-01 mudar, a ficha acompanha. Nomes de rua: Ninth Avenue e Juniper Street (`story/world.md`, iguais no MAP-01 revisão 2). Coordenadas `(X, Z)` copiadas do MAP-01 (fonte da verdade espacial).

Caminhos dos packs (abreviados nas fichas):
- `KP/` = `Assets/KitchenPack/Assets/fbx/`
- `FP/` = `Assets/FoodPack/Models/FBX format/`
- `CK/`, `CR/`, `CC/`, `CS/`, `MM/` = `Assets/CarKit`, `Assets/CityKitRoads`, `Assets/CityKitCommercial`, `Assets/CityKitSuburban`, `Assets/MiniMarket` (cada um em `Models/FBX format/`; ver `asset-sourcing.md`)

## Resumo

| ID | Nome | Categoria | Prioridade | Origem | Arquivo de pack | Status |
|---|---|---|---|---|---|---|
| AST-001 | Bun (pão) | food | P0 | Pack + edição | `FP/hot-dog.fbx` (pão recortado; DEC-137); modelo `Assets/models/food/AST-001_Bun.fbx` (`Bun_Closed` 128 / `Bun_Open` 152; DEC-141) | Aprovado (DEC-137; modelo DEC-141) |
| AST-002 | Sausage (crua / grelhada) | food | P0 | Pack + edição | `FP/hot-dog-raw.fbx` (grelhada = recolor; DEC-137); modelo `Assets/models/food/AST-002_Sausage.fbx` (Raw 92 / Grilled 164; DEC-141) | Aprovado (DEC-137; modelo DEC-141) |
| AST-003 | Hot dog montado (Tool) | food | P0 | Pack + edição | `FP/hot-dog.fbx` (Tool sem molho; DEC-137); modelo `Assets/models/food/AST-003_HotDog.fbx` (Tool 316 / `HotDog_Display` 414; DEC-141); empilhamento pela altura real, queijo antes dos cordões (DEC-142) | Aprovado (DEC-137; modelo DEC-141) |
| AST-004 | Ketchup (garrafa + cobertura) | food | P0 | Pack + edição | `FP/bottle-ketchup.fbx` + molho recortado de `FP/hot-dog.fbx` (DEC-137); garrafa **translúcida** + `Fill` animado (DEC-140; edição em andamento); cobertura `Assets/models/food/AST-004_KetchupTopping.fbx` (66; DEC-141) | Aprovado (DEC-137; cobertura DEC-141) |
| AST-005 | Mustard (garrafa + cobertura) | food | P0 | Pack + edição | `FP/bottle-musterd.fbx` + cobertura de 7 dobras (DEC-137); garrafa **translúcida** + `Fill` animado (DEC-140; edição em andamento); cobertura `Assets/models/food/AST-005_MustardTopping.fbx` (86; DEC-141) | Aprovado (DEC-137; cobertura DEC-141) |
| AST-006 | Cheese (fatia + cobertura) | food | P0 | Pack + edição | `FP/cheese-cut.fbx` (DEC-137); modelo `Assets/models/food/AST-006_Cheese.fbx` (Topping 148 / Slice 160; DEC-141) | Aprovado (DEC-137; modelo DEC-141) |
| AST-007 | Bacon | food | P0 | Pack | `FP/bacon.fbx` (DEC-137); modelo `Assets/models/food/AST-007_Bacon.fbx` (Topping 160 / Pile 120; DEC-141) | Aprovado (DEC-137; modelo DEC-141) |
| AST-008 | Potato Sticks | food | P1 | Pack + edição | palitos recortados de `FP/fries.fbx`, sem a caixa (DEC-137); modelo `Assets/models/food/AST-008_PotatoSticks.fbx` (Topping 240 / Pile 344; DEC-141) | Aprovado (DEC-137; modelo DEC-141) |
| AST-009 | Cream Cheese (pote + cobertura) | food | P1 | Pack + edição | `KP/jar_B_medium.fbx` + `FP/whipped-cream.fbx` (cobertura) (DEC-137); modelo `Assets/models/food/AST-009_CreamCheese.fbx` (Topping 126 / Jar 188; DEC-141) | Aprovado (DEC-137; modelo DEC-141) |
| AST-010 | Coffee (copo, Tool) + par de cafés do Walt | food | P1 | Pack + edição | `FP/soda.fbx` sem canudo, recolor (DEC-137); modelo `Assets/models/food/AST-010_Coffee.fbx` (~~236~~ **260** por copo, malha refeita 2026-10-10; `Coffee_Pair` L/R; DEC-141) | Aprovado (DEC-137; modelo DEC-141) · correção de malha Em revisão (modeler-3d, 2026-10-10) |
| AST-011 | Pacotes do mercado (9, Tool) | food | P0 | Pack + edição | `FP/bag.fbx`, `FP/bag-flat.fbx`, `FP/carton.fbx`, `FP/carton-small.fbx`, `FP/can.fbx`, `FP/can-small.fbx` (DEC-137); modelados `Assets/models/food/AST-011_Pack<Nome>.fbx` (9; 44–156 tris) + textura `Assets/textures/props/T_PackLabels.png` | Aprovado (DEC-137) · modelo Em revisão (modeler-3d, 2026-10-10) |
| AST-012 | Grill (3 níveis) — **roller grill** (DEC-138) | equipment | P0 | Modelar | ref. de forma `Assets/reference/AST-012_roller_grill_ref.png` (sem marca); ~~`KP/stove_*_countertop.fbx`~~ recusado (DEC-138) | Em revisão (modelo L1–L3, DEC-201) |
| AST-013 | Trilho de descanso | equipment | P0 | Modelar | modelado: `Assets/models/equipment/AST-013_RestRail.fbx` (`Rail_6` 384 / `Rail_8` 440 tris; DEC-140) | Aprovado (DEC-140) |
| AST-014 | Tábua + faca | equipment | P0 | Pack | `KP/cuttingboard.fbx`, `KP/knife.fbx` (faca deitada; DEC-138); modelo `Assets/models/equipment/AST-014_CuttingBoard.fbx` (tábua 38 + faca 104; DEC-141) | Aprovado (DEC-138; modelo DEC-141) |
| AST-015 | Caixa de pães (estoque de pão) | equipment | P0 | Pack + edição | `KP/crate_buns.fbx`, `KP/crate_lid.fbx` (pães de hot dog do AST-001 no lugar dos de hambúrguer; tris ≤ 800; DEC-138) | Aprovado (DEC-138) |
| AST-016 | Porta-garrafas de molho (2 vagas da grade) | equipment | P0 | Modelar | modelado: `Assets/models/equipment/AST-016_SauceHolder.fbx` (480 + `Fill` 28 cada); garrafas AST-004/005 translúcidas com `Fill` animado (DEC-140) | Aprovado (DEC-140); **fora da grade por DEC-218** (destino `Q-172`) |
| AST-017 | Grade de complementos 3 × 2 + tigelas de inox | equipment | P0 | Pack + edição | base `KP/kitchencounter_straight_A.fbx`; **tigelas `KP/bowl.fbx` com ingrediente dentro + plaquinha `Label_<Ing>` (SurfaceGui/ImageLabel) + Padlock Quaternius (DEC-156)**; modelo antigo `AST-017_ToppingGrid.fbx` (DEC-141) superado; **ketchup e mostarda também em tigela (DEC-218)** | Aprovado (DEC-138; DEC-156); **modelo de tigelas aprovado (DEC-218)** |
| AST-018 | Cooler / estoque de salsicha (3 níveis) | equipment | P0 | Pack + edição | L3 `KP/fridge_A.fbx`; L1–L2 modelados sobre a base `MM/freezer.fbx` (DEC-138); modelos `Assets/models/equipment/AST-018_CoolerL1.fbx` (668) e `_CoolerL2.fbx` (1.106; DEC-141) | Aprovado (DEC-138; N1/N2 DEC-141) |
| AST-019 | Counter (3 níveis) + pedestais e marcas de fila | equipment | P0 | Pack + edição | `KP/kitchencounter_straight_A.fbx`, `KP/kitchencounter_outercorner.fbx`, `KP/chair_stool.fbx` (assento plano); pedestais/toldo/marcas modelados (DEC-138); modelos `Assets/models/equipment/AST-019_QueuePost.fbx` (94 + corda 68) e `_QueueMark.fbx` (34; DEC-141) | Aprovado (DEC-138; pedestal/corda/marca DEC-141) |
| AST-020 | Suporte de entrega + gaveta do caixa + Cash Drawer Lock | equipment | P0 | Pack + edição (DEC-155) | **POS preta "POS Machine" de J-Toastie (CC-BY 3.0, crédito obrigatório; 606 + gaveta 146) + "Padlock" Quaternius (CC0) Mustard `AST-020_Padlock.fbx`**; modelo antigo `AST-020_CashRegister.fbx` (DEC-140) superado | Aprovado (DEC-140; DEC-155); modelo novo em produção |
| AST-021 | Saco de moedas (ladrão) | equipment | P0 | Pack + edição | `FP/bag.fbx` | Rascunho |
| AST-022 | Cafeteira (UPG-007, fixa no trailer) | equipment | P1 | Modelar | modelado: `Assets/models/equipment/AST-022_CoffeeMachine.fbx` (944; DEC-140) | Aprovado (DEC-140) |
| AST-023 | Trailer Lights (UPG-005) | equipment | P1 | Modelar | modelado: `Assets/models/equipment/AST-023_TrailerLights.fbx` (mastro 356 / cordão 486; DEC-140) | Aprovado (DEC-140) |
| AST-024 | Placa OPEN / CLOSED + "Available on Day 5" | equipment | P0 | Pack + edição | `KP/menu.fbx` (cavalete; DEC-138) | Aprovado (DEC-138) |
| AST-025 | Lixeira (descartar) | equipment | P1 | Pack + edição | "Trashcan" by Kenney (CC0, https://poly.pizza/m/eoC8NFaafh) editado: `Assets/models/equipment/AST-025_Trashcan.fbx` (132; DEC-140) | Aprovado (DEC-140) |
| AST-026 | Corner Cart (carrinho do chefe) | vehicle | P0 | Modelar (casca) + Pack (guarda-sóis) | guarda-sóis `CC/detail-parasol-a.fbx` (DEC-139); casca modelada `Assets/models/vehicle/AST-026_CornerCart.fbx` (2.984; ~7.200 montado; DEC-141); guarda-sóis mantidos, reavaliar em playtest (DEC-144); **bancada 3,0 (DEC-157)**; tampo do lado esquerdo refeito 2026-10-10 (`Body` 1.678 tris) | Aprovado (DEC-139; casca DEC-141) · correção Em revisão (modeler-3d, 2026-10-10) |
| AST-027 | Open Late Trailer (casca + interior) | vehicle | P1 | Pack + edição | `KP/kitchencounter_straight_B.fbx`; modelo `Assets/models/vehicle/AST-027_OpenLateTrailer.fbx` (4.452; inclui a porta do AST-066; DEC-141) | Aprovado (DEC-141) |
| AST-028 | Ninth Street Mart — fachada, letreiro e ponto seguro | market | P0 | Pack + edição | `MM/wall.fbx`, `MM/wall-window.fbx`, `MM/wall-door-rotate.fbx`, `MM/wall-corner.fbx` (módulo 8 × 12) + toldo `CC/detail-awning-wide.fbx`; paredes em revisão pelo art-director (DEC-139); **2026-10-11:** `AST-028_MartWallDoor` deixou de ser uma MeshPart única e virou 3 peças no mesmo FBX (`Assets/blender/market/AST-028_MartWallDoor.blend` → `Assets/import/market/AST-028_MartWallDoor.fbx`, 316 tris, mesma malha/UV/atlas, original em `_backup_AST-028_MartWallDoor_single.fbx`): `Door_Frame` (parede + moldura + soleira, fixa, origem na base) + `Door_Leaf_L` / `Door_Leaf_R` (folha com painel de vidro, puxador e dobradiças; origem no eixo da dobradiça, na borda externa; L = x<0 e R = x>0 vistos de dentro da loja). O bind (W8) usa as folhas reais (tag `AutoDoor` + `Door_Hinge` Left/Right) e não cria mais o `Door_Leaf` placeholder | Aprovado (DEC-139) · Em revisão (modeler-3d, 2026-10-10) |
| AST-029 | Prateleira de compra + recheio + "Out of stock" | market | P0 | Pack + edição | gôndola `MM/shelf-boxes.fbx`, `MM/shelf-bags.fbx`, `MM/shelf-end.fbx` (4,5 × 6 × 2,5); recheio FP/KP do sourcing; **sem** `FP/soda-bottle.fbx` (DEC-139) | Aprovado (DEC-139) |
| AST-030 | Geladeira expositora | market | P0 | Pack + edição | `MM/freezers-standing.fbx` (DEC-139) | Aprovado (DEC-139) |
| AST-031 | Balcão do caixa do Mart (posto da Opal) | market | P1 | Pack + edição | `MM/cash-register.fbx` (DEC-139) | Aprovado (DEC-139) |
| AST-032 | Kit de rua (piso, Pad, estacionamento) | street | P0 | Pack + edição | `CR/road-straight.fbx`, `CR/road-crossroad.fbx`; demais peças conforme sourcing (DEC-139) | Aprovado (DEC-139) |
| AST-033 | Kit de prédio (fachadas modulares + cartões de fundo) | building | P0 | Pack + edição | `CC/building-a.fbx`, `CC/building-h.fbx` (DEC-139) | Aprovado (DEC-139) · Em revisão (modeler-3d, 2026-10-10) |
| AST-034 | Mobiliário urbano | street | P1 | Pack + edição | `CR/road-sign-street.fbx`, `CS/tree-large.fbx`, `CS/planter.fbx`, `CK/cone.fbx`; banco, lixeira, hidrante, caixa de correio modelados: `Assets/models/street/AST-034_ParkBench.fbx`, `_TrashCan`, `_Hydrant`, `_Mailbox` (DEC-140); 2026-10-10 (ambientação MAP-01 §17, Rascunho): `_Dumpster` (`CR/dumpster`, 234 tris), `_ACUnit` (190 tris) e `_Clothesline` (192 tris) modelados, `Assets/blender/street/` → `Assets/import/street/` | Aprovado (DEC-139; peças modeladas DEC-140) · Em revisão (modeler-3d, 2026-10-10) |
| AST-035 | Carros de trânsito (família de 4) | vehicle | P1 | Pack + edição | `CK/sedan.fbx`, `CK/hatchback-sports.fbx`, `CK/van.fbx`, `CK/truck.fbx` (DEC-139); modelos `Assets/models/vehicle/AST-035_CarSedan.fbx`, `_CarHatch`, `_CarVan`, `_CarPickup` (+ `_Paints`; 1.360–1.416; 5 cores; DEC-141); medidas `Q-136` | Aprovado (DEC-139; modelos DEC-141) |
| AST-036 | Poste de luz (Juniper, Ninth, P-01) | street | P0 | Pack + edição | `CR/light-curved.fbx` (alt. `CR/light-square.fbx`) + cúpula modelada `Assets/models/street/AST-036_LampHead.fbx` (208; montado 14,45 A, braço 3,6; DEC-140) | Aprovado (DEC-139; cúpula DEC-140) |
| AST-037 | Panfleto (HELP WANTED / NIGHT SHIFT) | story | P0 | Modelar | modelado: `Assets/models/story/AST-037_Flyer.fbx` (`Flyer_Old` 132 / `Flyer_NightShift` 144; DEC-140) | Aprovado (DEC-140) |
| AST-038 | Celular flip (só cutscene de abertura) | story | P1 | Modelar | modelado: `Assets/models/story/AST-038_FlipPhone.fbx` (266; DEC-140) | Aprovado (DEC-140) |
| AST-039 | Interruptor "Lights" do trailer | equipment | P1 | Modelar | modelado: `Assets/models/equipment/AST-039_LightSwitch.fbx` (128; DEC-140) | Aprovado (DEC-140) |
| AST-040 | Banco do fundo do trailer | equipment | P1 | Pack + edição | base `KP/kitchencabinet.fbx` ×3 + almofada modelada (DEC-138) | Aprovado (DEC-138) |
| AST-041 | Pontos de esconder "Hide" (×4) | equipment | P1 | Pack + edição | `KP/kitchencabinet_half.fbx` (DEC-138) | Aprovado (DEC-138) |
| AST-042 | Telefone fixo do veículo (2 variantes) | equipment | P0 | Modelar → **Pack + edição (Poly Pizza, 2026-10-10)** | ~~modelado DEC-140 (aparelho 396 / `Phone_Cart` 528)~~ → "Low poly phone" by Anastasiia Ku (**CC-BY 3.0**) editado: `Assets/models/equipment/AST-042_VehiclePhone.fbx` (aparelho 388 + prateleira 112 por variante) | Aprovado (DEC-140, ficha) · modelo novo **Em revisão** |
| AST-043 | Lona do carrinho | vehicle | P1 | Modelar | `Assets/models/vehicle/AST-043_CartTarp.fbx` (1.152 tris) | Em revisão (ficha DEC-217) |
| AST-044 | Bellmoor Savings (fachada + relógio, ANM-003) | building | P0 | Modelar + Pack (coluna) | coluna `KP/pillar_A.fbx`; volume `CC/building-j.fbx` (com AST-045; reduzido em `Assets/models/building/AST-045_ApartmentBlock.fbx`, DEC-141); resto da fachada segue modelar (DEC-139) | Aprovado (DEC-139; volume DEC-141) · Em revisão (modeler-3d, 2026-10-10) |
| AST-045 | Apartamentos sobre o Bellmoor Savings (ANM-006) | building | P0 | Pack + edição | `CC/building-j.fbx` (DEC-139) reduzido: `Assets/models/building/AST-045_ApartmentBlock.fbx` (2.381; DEC-141) | Aprovado (DEC-139; modelo DEC-141) · Em revisão (modeler-3d, 2026-10-10) |
| AST-046 | Lavanderia | building | P1 | Pack + edição | `CC/building-e.fbx` (DEC-139) | Aprovado (DEC-139) · Em revisão (modeler-3d, 2026-10-10) |
| AST-047 | Barreira "Road Closed" (BAR-N, BAR-S) | street | P1 | Pack + edição | `CR/construction-fence.fbx`, `CR/construction-light.fbx` (DEC-139) | Aprovado (DEC-139) |
| AST-048 | Caminhão de entrega parado | street | P1 | Pack + edição | `CK/delivery.fbx` (DEC-139) | Aprovado (DEC-139) |
| AST-049 | Bancada de upgrades do Mart (parede do fundo) | market | P0 | Pack + edição | `KP/kitchencounter_straight_A.fbx`, `KP/shelf_papertowel.fbx` (nichos); painel e S1 modelados (DEC-138); montado `Assets/models/market/AST-049_GearWall.fbx` (1.208; DEC-141); moldura S1 **Mustard** (DEC-144; recolor pendente) | Aprovado (DEC-138; modelo DEC-141) · Em revisão (modeler-3d, 2026-10-10) |
| AST-050 | Área de frutas e verduras do Mart (+ expositor de pão de hot dog) | market | P1 | Pack + edição | `MM/display-fruit.fbx`, `MM/display-bread.fbx`, frutas FP; variante `Assets/models/market/AST-050_BunDisplay.fbx` (DEC-139); caixote refeito `Assets/models/market/AST-050_LettuceCrate.fbx` (1.159; DEC-141) | Aprovado (DEC-139; caixote DEC-141) |
| AST-051 | Revive Kit — item raro de reviver (Tool, ITM-021) | market | P1 | Modelar | modelado: `Assets/models/market/AST-051_ReviveKit.fbx` (~~apito 300~~ **kit médico 172**, pedido do usuário 2026-10-10; DEC-140) | Aprovado (DEC-140; apito) · kit médico Em revisão (modeler-3d, 2026-10-10; forma nova pede DEC) |
| AST-052 | Ambulância (+ maca levada pelos médicos) | vehicle | P1 | Pack + edição | `CK/ambulance.fbx`; maca modelada `Assets/models/vehicle/AST-052_Stretcher.fbx` (352; DEC-140); ambulância `Assets/models/vehicle/AST-052_Ambulance.fbx` (1.748; DEC-141); carga 8,37 × 5,13 × 4,89, maca cabe sem redução (DEC-143) | Aprovado (DEC-139; maca DEC-140; ambulância DEC-141) |
| AST-053 | Base de personagem R6 (cores, rostos, decals de roupa) | character | P0 | Plataforma + decals | — | Rascunho |
| AST-054 | Clientes normais e pedestre (7 tipos × 4 variantes) | character | P0 | Plataforma + Modelar (acessórios) | — | Rascunho |
| AST-055 | Mr. Pickett | character | P0 | Plataforma + Modelar | — | Rascunho |
| AST-056 | Quick Quentin | character | P0 | Plataforma + Modelar | — | Rascunho |
| AST-057 | Opal | character | P1 | Plataforma + Modelar | — | Rascunho |
| AST-058 | Walt Bramble (só cutscene final) | character | P1 | Plataforma + Modelar | — | Rascunho |
| AST-059 | Raincoat Lady (ANM-005) | anomaly | P1 | Plataforma + Modelar | — | Rascunho |
| AST-060 | ANM-001 The blank folks | anomaly | P1 | decal + Modelar | — | Rascunho |
| AST-061 | ANM-002 The wrong food | anomaly | P1 | Pack + edição | `FP/hot-dog-raw.fbx` recolor + pão do AST-001 (DEC-137); modelo `Assets/models/anomaly/AST-061_WrongFood.fbx` (`Sausage_Wrong` 164 / `Bun_Bitten` 208; DEC-141) | Aprovado (DEC-137; modelo DEC-141) |
| AST-062 | ANM-004 The copies (variantes espelhadas) | anomaly | P1 | decal + Modelar | — | Rascunho |
| AST-063 | ANM-006 The wavers (silhueta na janela) | anomaly | P1 | Modelar | — | Rascunho |
| AST-064 | ANM-007 The Walker | anomaly | P1 | Plataforma + Modelar | — | Rascunho |
| AST-065 | ANM-008 The long car | anomaly | P1 | Pack + edição | `CK/sedan.fbx` esticado (19,5 × 7,1 × 4,0; DEC-139); modelo preto, 4 rodas `Assets/models/anomaly/AST-065_LongCar.fbx` (1.360; DEC-141); 4 rodas (DEC-144) | Aprovado (DEC-139; modelo DEC-141) |
| AST-066 | ANM-009 The knock (porta dos fundos) | anomaly | P1 | Modelar | parte de AST-027 (porta já está em `AST-027_OpenLateTrailer`; **não** aprovada por tabela na DEC-141) | Rascunho |
| AST-067 | ANM-010 The Hush (névoa + marcação) | anomaly | P1 | Modelar + VFX | — | Rascunho |
| AST-068 | Pistas do trailer: foto de 1979 + crachá | story | P1 | Modelar | modelado: `Assets/models/story/AST-068_TrailerClues.fbx` (`Photo_1979` 66 / `Badge_Old` 76; DEC-140) | Aprovado (DEC-140) |
| AST-069 | Pacote de animações R6 | character | P0 | Animar | rig de animação: `Assets/blender/character/AST-069_AnimalRig.blend` (+ `.md`; em revisão); animações: — (usuário anima, DEC-220) | Aprovado (DEC-217: rig IK + 35 clipes) |
| AST-070 | VFX pastelão: atropelamento, desmaio, embarque, reviver | vfx | P1 | Modelar (texturas) | — | Rascunho |
| AST-071 | Folha de ícones de UI (ingredientes, Tools, HUD) | ui | P0 | Render + 2D | `Assets/textures/ui/AST-071_icons.png` + `.json` (54 ícones, 1024², células 128²; 23 placeholders) | Aprovado (DEC-217: 54 ícones) · Em revisão (modeler-3d, 2026-10-10) |
| AST-072 | Folha de placas, letreiros e logos | ui | P0 | 2D | — | Rascunho |
| AST-073 | Avental Bramble's (acessório do jogador) | character | P2 | Modelar | — | Rascunho (proposta Obsoleto, `Q-172`) |
| AST-074 | Ônibus urbano (trânsito + cutscene) | vehicle | P2 | Modelar | → sourcing: KayKit City Builder Bits (a confirmar, não baixado; o Car Kit não tem ônibus) | Rascunho |
| AST-075 | Props da cutscene de abertura (carteira, mariposa, pombos) | story | P2 | Modelar | — | Rascunho |
| AST-076 | Médicos da ambulância — Bellmoor Rescue crew (CHR-008, NPC-024) | character | P1 | Plataforma + Modelar | — | Rascunho |
| AST-077 | ~~Semáforo (carro + pedestre) e faixa de pedestre~~ | street | — | — | — | **Obsoleto** (DEC-130) |
| AST-078 | Balcão externo do trailer (Counter no trailer, 3 níveis) | equipment | P1 · onda 2 | Pack + edição | `KP/kitchencounter_straight_B.fbx`, `KP/chair_stool.fbx`, `CC/detail-awning.fbx` | Rascunho |
| AST-079 | Lâmpada básica do trailer (DEC-189) | equipment | P1 · onda 2 | Modelar | — | Rascunho |
| AST-080 | Ambientação do interior do trailer | equipment | P2 · onda 2 | Pack | `KP/shelf_papertowel_decorated.fbx`, `KP/papertowel.fbx`, `KP/towelrail.fbx`, `KP/jar_*_small.fbx`, `KP/dishrack.fbx` | Rascunho |
| AST-081 | Kit de acessórios de cliente (DEC-188) | character | P0 · onda 2 | Modelar | `Assets/models/character/AST-081_Acc_*.fbx` (13 malhas, 64–272 tris) | Em revisão (ficha DEC-217) |
| AST-082 | Moeda (pagamento, gorjeta, `Coin_Blank`) | vfx | P1 · onda 2 | Modelar | — | Rascunho |
| AST-083 | Kit de luz de rua: poça, cone, arandela | street | P1 · onda 2 | Modelar + 2D | — | Rascunho |
| AST-084 | Pós-processo: dia, noite, escuro e sanidade | vfx | P1 · onda 2 | Código + 2D | — | Rascunho |
| AST-085 | Alucinações de sanidade baixa | vfx | P1 · onda 2 | Modelar + código | — | Rascunho |
| AST-086 | Retratos de faixa de sanidade (HUD) | ui | P1 · onda 2 | Render | renders do AST-053 | Rascunho |
| AST-087 | Jornal de espreita do Quick Quentin | character | P1 · onda 2 | Modelar | — | Rascunho |
| AST-088 | Plataforma de party do lobby (DEC-179) | equipment | P1 · onda 2 | Pack + edição | `KP/plate.fbx`, `KP/menu.fbx`, `AST-019_QueueMark` | Rascunho |
| AST-089 | Cenário do lobby (kit modular) | street | P1 · onda 2 | Pack | AST-026, 032, 033, 034, 036; `KP/kitchencounter_straight_A.fbx`, `CC/detail-awning.fbx` | Rascunho |
| AST-090 | Vitrine de classes "Crew" (lobby) | equipment | P1 · onda 2 | Pack + edição | `KP/pillar_B.fbx`, `AST-020_Padlock` | Rascunho |
| AST-091 | UI kit (painéis, botões, cartões, barras) | ui | P0 · onda 2 | 2D | — | Aprovado (DEC-217) |
| AST-092 | VFX de cozinha e loja | vfx | P1 · onda 2 | 2D + código | — | Rascunho |
| AST-093 | Placa PARE e linha de parada | street | P1 · onda 3 | Pack + edição | `CR/road-sign-stop.fbx` | Rascunho |
| AST-094 | Porta-guardanapos do trailer (ANM-009) | equipment | P2 · onda 3 | Modelar | ref. `KP/papertowel.fbx` | Rascunho |
| AST-095 | VFX de anomalias | vfx | P1 · onda 3 | 2D + código | — | Rascunho |
| AST-096 | Item no chão: marcador, "splat", derramado | vfx | P1 · onda 3 | 2D + código | — | Rascunho |
| AST-097 | Logo do jogo, ícone e thumbnails | ui | P1 · onda 4 | 2D + render | — | Rascunho |
| AST-098 | Bancada de feira do canto FRESH PRODUCE (Mart) | market | P1 | Pack + edição (Poly Pizza) | "Market Stand" by Quaternius (CC0) editado: `Assets/models/market/AST-098_ProduceStand.fbx` (468 tris) | Em revisão (modelo pronto; ficha Rascunho até DEC) |
| AST-103 | Porta de enrolar de ripas de madeira (Gear Stand; avulsa e tripla) | market | P1 | Modelar | — (nenhum pack tem; `asset-sourcing-2026-10-11.md` §6); atlas KitchenPack | Rascunho (modelo entregue 2026-10-11) |
| AST-104 | Gear Stand: estrutura/fachada do quiosque de upgrades | market | P1 | Modelar + pack | `MM/cash-register.fbx` no balcão; resto modelado no atlas KitchenPack | Rascunho (modelo entregue 2026-10-11) |
| AST-105 | Pedestal de vitrine do Gear Stand (B1–B5 e S1) | market | P1 | Pack + edição (Poly Pizza) | "Column Round" by Quaternius (CC0), recolor no atlas KitchenPack | Rascunho (modelo entregue 2026-10-11) |
| AST-106 | Placas de seção do Mart (5: penduradas e de parede, sem texto) | market | P1 | Modelar | — (`asset-sourcing-2026-10-11.md` §5) | Rascunho (modelo entregue 2026-10-11) |
| AST-107 | Expositor refrigerado aberto de carnes (MEAT & DELI) | market | P1 | Modelar + pack | `KP/food_ingredient_steak.fbx`, `KP/food_ingredient_ham.fbx` dentro; `MM/freezer.fbx` recusado | Rascunho (modelo entregue 2026-10-11) |

Totais: **77 IDs**, **76 fichas ativas** (AST-001 a AST-038 existentes, revistas; AST-039 a AST-075 da 1ª conciliação; AST-076 e AST-077 da 2ª revisão; **AST-077 Obsoleto** por DEC-130).
Usam pack: **25** (4 direto, 21 com edição). Plataforma R6 + acessórios: **9**. Modelar / 2D / animação do zero: **43**. (DEC-138: AST-017, 018, 019, 024 passaram de Modelar para Pack + edição; antes 21 / 47.) DEC-140: AST-025 passou de Modelar para Pack + edição ("Trashcan" by Kenney via Poly Pizza, fora dos packs de `Assets/`) — usam pack **26** (4 / 22); Modelar **42**.
**Levantamento pós-onda 1 (art-director, 2026-10-10):** fichas novas **AST-078 a AST-097** (20, todas **Rascunho**) e complementos de onda/dono/orçamento nas fichas antigas ainda abertas. Seção "Levantamento pós-onda 1" no fim do documento. Totais: **97 IDs**, **96 fichas ativas** (AST-077 Obsoleto).
**2026-10-10 (pedido do usuário):** ficha nova **AST-098** (bancada de feira do Mart, Rascunho) e modelo novo do **AST-042** (telefone de mesa de disco), ambos de Poly Pizza; licenças em `credits.md`. Totais: **98 IDs**, **97 fichas ativas**.
**2026-10-11 (Mart v2, MAP-01 §18.9):** fichas novas **AST-103 a AST-107** (Rascunho), modelos entregues pelo modeler-3d (Blender headless). Os FBX `AST-099` a `AST-102` em `Assets/import/` (rodada de sourcing do mesmo dia) ainda não têm ficha aqui.
Mapeamento Kenney/KayKit por ficha (DEC-136, Rascunho): `asset-sourcing.md`. As entradas "→ sourcing:" na coluna "Arquivo de pack" vêm de lá; Origem e Status não mudaram.
**DEC-137 (2026-10-09):** comida aprovada — AST-001 a AST-011 e AST-061 em **Aprovado**, com o candidato do sourcing como arquivo de origem (fila do `modeler-3d`). Demais fichas seguem Rascunho. `Q-133` (limite de atlases) segue aberta.
**DEC-138 (2026-10-10):** equipamentos aprovados após o teste em `workspace.__ImportTest_Equip` — AST-014, 015, 017, 018, 019, 024, 040, 041, 049 em **Aprovado** com o candidato KP/MM como origem (partes sem candidato seguem para modelar no estilo). Banqueta `KP/chair_stool` com **assento plano** em todo uso. **AST-012**: candidato fogão KayKit **recusado**; vira **roller grill** modelada (Steel + painel Ketchup, sem marca), Aprovado na direção; silhueta em reescrita pelo art-director; níveis em `Q-134`.
**DEC-141 (2026-10-10):** rodada 3 de modelados (`workspace.__Preview_Rodada3`) aprovada — modelos de AST-001 a 010, 014, 017, 018 (N1/N2), 019 (pedestal/corda/marca), 026 (casca), 027, 035, 045 (+ volume do AST-044), 049, 050 (caixote), 052, 061, 065. **AST-027 Rascunho → Aprovado.** AST-066 segue Rascunho; AST-043 não modelada (`Q-082`). Empilhamento de coberturas `Q-138`; guarda-sóis em 1ª pessoa, rodas do long car e moldura da S1 `Q-139`; carga da ambulância `Q-140`.

**DEC-142 a DEC-145 (2026-10-10):** AST-003 empilha pela altura real, queijo antes dos cordões (DEC-142); AST-052 carga medida 8,37 × 5,13 × 4,89, maca cabe sem redução, encaixe `Att_Stretcher_Stowed` (DEC-143); AST-026 guarda-sóis mantidos, AST-065 4 rodas, AST-049 moldura S1 Mustard com recolor pendente (DEC-144); personagem padrão "HotDog Crew" em rig R6 custom (`Assets/reference/customrig.png`): fichas do corpo base e dos animais a escrever pelo art-director (DEC-145; `Q-141` a `Q-144`).

**DEC-146 e DEC-147 (2026-10-10):** jogador vira animal da crew, sem avatar do Roblox; clientes NPC seguem humanos (AST-053/054 só para NPC); AST-073 vira uniforme da crew; personagens com nome em `Q-146`; cada animal é uma classe (lista de animais depende de `Q-145`).

**DEC-148 a DEC-150 (2026-10-10):** personagens da crew com **textura** de roupa/rosto/pelagem (exceção de personagem a DEC-105/DEC-136; orçamento `Q-144` g). **Clientes e pedestres também são animais** (DEC-149, emenda DEC-146): AST-053/054 a rever pelo art-director (`Q-149`); atores de anomalia de cliente `Q-147`. Personagem com **textura de dia e de noite**, mesma malha (DEC-150, `Q-148`).

**DEC-151 e DEC-152 (2026-10-10):** **roupa texturizada** (`AST-053_CrewTex`) e **rig R6** do corpo base (`AST-053_CrewBase`) **aprovados** como modelo entregue (DEC-151; texto da ficha AST-053 segue Rascunho até a reescrita). **Cabeças** `AST-053_Animal_*` **substituídas** (DEC-152): malha única oval com focinho em volume, olhos/nariz/boca por textura, expressões por troca de textura (normal, feliz, sorridente, triste, desmaiado com X); orelhas e caudas seguem. Técnica "casca de rosto com UV padrão" Provisória (`Q-144` h); versão noite das expressões `Q-150`. Retratos e ícones (AST-071) podem usar as expressões.

**DEC-153 a DEC-157 (2026-10-10):** cabeças AST-053 **v3** (focinho oval liso, queixo redondo; 728 tris; personagem 1.914–2.104, acima de 1.800, orçamento em `Q-144` g; DEC-153). Noite escurece também orelhas/cauda/acessórios com `T_Atlas_Kitchen_Night` (DEC-154; cor do animal à noite `Q-151`). **AST-020:** POS preta de J-Toastie (**CC-BY 3.0, crédito obrigatório**) + cadeado "Padlock" da Quaternius (CC0) Mustard, reutilizado no AST-017 (DEC-155; modelo em produção). **AST-017:** tigelas de inox `KP/bowl` com ingrediente dentro + plaquinha `Label_<Ing>` para `SurfaceGui`/`ImageLabel` (DEC-156; ícones `Q-152`; modelo em produção). **AST-026:** bancada **3,0** (era 3,5; DEC-157; style guide `Q-153`); AST-019 balcão do carrinho idem.

**DEC-158 a DEC-160 (2026-10-10):** crew com **+10 espécies** (18; AST-053, entregues para revisão, não aprovadas; Sheep ≈ 2.530 tris, `Q-144` g; noite azul-marinho igual em todas, `Q-151`). **Quick Quentin = guaxinim** (AST-056; `T_Civil_Thief_Day` só dia, `AST-053_ThiefHat`, `T_Expr_Thief`; em produção). **Roupas casuais** de cliente/pedestre `T_Civil_C` a `H` (dia e noite), 8 conjuntos com A/B (em produção; `Q-149`).

**DEC-161 a DEC-163 (2026-10-10):** correções (nariz único por espécie na `T_Head_<A>`; braços retos de civil `AST-053_CivilArms`; patinhas rosadas em todas as roupas, inclusive uniforme), expressões **Skeptical / Exhausted / Stressed**, e **aprovação** ("Show gostei de todos") das 10 espécies, peças do Quentin (chapéu cinza-ardósia) e 8 conjuntos casuais. Orçamento `Q-144` (g) e noite `Q-151` **seguem abertos**; fichas AST-053/056 seguem Rascunho no texto.

**DEC-164 e DEC-165 (2026-10-10):** tris do rig animal **aprovados como entregues** (≈ 2,0–2,5k; Sheep ≈ 2.530; vale para AST-053/054/056, nota no style guide §9.1). Noite **azul-marinho igual** para todas as espécies (`Q-151` A); braços/mãos acompanham nas folhas `*_Night` (commit `70094d3`).

**DEC-166 (2026-10-10):** **3º pack "Mid"** (meio-termo dia/noite) e visual por **sanidade**: alta = dia + rosto Normal; média = Mid + Exhausted; baixa = noite + `Normal_Night`. Entregue (commit `d699cf7`, não aprovado): `T_Head_<A>_Mid` (18), `T_Crew_Uniform_Mid`, `T_Civil_A..H_Mid`, `T_Atlas_Kitchen_Mid`. Critério da troca (turno × sanidade) `Q-155`; faixas e quem `Q-156`; memória `Q-144` (g).

Mapa anomalia → asset (DEC-096): ANM-001 AST-060 · ANM-002 AST-061 · ANM-003 AST-044 (estados do relógio) · ANM-004 AST-062 (+ AST-055) ·
ANM-005 AST-059 · ANM-006 AST-063 (+ AST-045) · ANM-007 AST-064 (+ AST-036) · ANM-008 AST-065 · ANM-009 AST-066 · ANM-010 AST-067 (+ AST-036, AST-028).

### Conciliação com MAP-01 §12 revisão 2 (chaves `L01-##` → `AST-###`)

Onde a coluna AST do MAP-01 ainda diz "—" ou "novo pedido", vale esta tabela (atualizar o MAP-01 é do level-designer, `consistency-report.md` LD-19).

| L01 | Pedido | AST | Nota |
|---|---|---|---|
| L01-01 | Carrinho | AST-026 | medidas do MAP-01 |
| L01-02 | Estoque de salsicha + Cooler 2/3 | AST-018 | o Cooler é a própria caixa de salsicha que cresce |
| L01-03 | Grelha 2/3/4 vagas | AST-012 | 5 de largura no carrinho, 6 no trailer |
| L01-04 | Trilho de descanso | AST-013 | |
| L01-05 | Caixa de pães + tábua | AST-015, AST-014 | |
| L01-06 | Grade de complementos 3 × 2 | AST-017 + AST-016 | molhos na fileira da frente |
| L01-07 | Entrega + gaveta (+ cadeado) | AST-020 | |
| L01-08 | Food Trailer | AST-027 | |
| L01-09 | Trailer Lights | AST-023 | |
| L01-10 | Cafeteira | AST-022 | |
| L01-11 | Interruptor | AST-039 | |
| L01-12 | Banco do fundo (3 lugares, 9 × 3, MAP-01 revisão 3) | AST-040 | só cenário e assento; não é mais lugar de acordar (DEC-122) |
| L01-13 | Armário "Hide" ×4 | AST-041 | |
| L01-14 | Lixeiras | AST-025 | |
| L01-15 | Placa OPEN/CLOSED | AST-024 | |
| L01-16 | Pedestais + marcas Q1–Q5 | AST-019 | |
| L01-17 | Placa "Available on Day 5" | AST-024 (variação) | 4 × 5 |
| L01-18 | Lona do carrinho | AST-043 | só no estacionamento depois da troca; uso depende de `Q-082` |
| L01-20 | Kit de rua (pista, T, faixa, linha de PARE, meio-fio, calçada) | AST-032 | sem semáforo (DEC-130; AST-077 Obsoleto). `Crosswalk` e `Stop_Line` ficam no kit AST-032; onde há faixa e se carro para nela: `Q-129` |
| L01-21 | Piso do Pad | AST-032 (`Pad_Tile`) | |
| L01-22 | Poste aceso/apagado/piscando | AST-036 | |
| L01-23 | Poste P-01 com panfleto | AST-036 + AST-037 | |
| L01-24 | Relógio do Bellmoor Savings (C-01) | **AST-044** | Ø 6, centro a ~14, em (39, −33) (MAP-01 revisão 3 §5.2) |
| L01-25 | Ponto seguro sob o letreiro (SS, raio 6) | **AST-028** (`SafeZone_Marking`) + AST-067 | SS em (−58, 30), raio 6, sob o "OPEN 24 HOURS" (`anomalies.md` N10); marcação = disco raio 6 (P36) |
| L01-26 | Cones e cavaletes de BAR-N e BAR-S | AST-047 (+ cone de AST-034) | cerca do beco **sai**: Juniper Sul aberta a carros (MAP-01 revisão 3) |
| L01-27 | Caminhão de entrega | AST-048 | ~20 × 8 × 10 |
| L01-28 | Carros parados + van | AST-035 | a van é uma das 4 formas |
| L01-29 | Cerca baixa + vagas | AST-032 | |
| L01-30 | Mobiliário urbano | AST-034 | |
| L01-31 | B1 (prédio atrás do Pad, porta D1) | **AST-033** (montagem do kit + `Door_D1`) | B1 **não** tem apartamentos da ANM-006 (estão sobre o banco, L01-38) |
| L01-32 | B2 lavanderia | AST-046 | |
| L01-33 | B3/B4/B5 fachadas | AST-033 | montagem do kit |
| L01-34 | Skyline | AST-033 (`BG_Card`) | |
| L01-35 | Carros em movimento | AST-035 | trânsito andando (DEC-087); medidas por forma na ficha |
| L01-36 | Ambulância + maca | AST-052 | ~16 × 7 (medida do MAP-01); médicos em AST-076 |
| L01-37 | Long car (ANM-008) | AST-065 | ~22 × 6 |
| L01-38 | Bellmoor Savings + apartamentos (lote 28 × ~30) | AST-044 (térreo ~18 + relógio) + AST-045 (andares 2–3, WV-1..3 a 19–28) | P36 |
| L01-40 | Fachada do mercado + letreiro | AST-028 | |
| L01-41 | Gôndolas + geladeiras | AST-029, AST-030 | |
| L01-42 | Pacotes | AST-011 | |
| L01-43 | "Out of stock" | AST-029 (decal) | texto em AST-072 |
| L01-44 | Balcão do caixa | AST-031 | |
| L01-50 | Ladrão + saco | AST-056 + AST-021 | |
| L01-51 | Funcionário do mercado | AST-057 (Opal) | DEC-079; nunca âncora de anomalia (`Q-091`) |
| L01-52 | Tipos de cliente | AST-054, AST-055 | |
| L01-53 | Walt Bramble com dois cafés | AST-058 + AST-010 (`Coffee_Pair`) | só na cutscene final (DEC-076) |
| L01-54 | Médicos (2) | **AST-076** | só na ida/coleta (DEC-114); na volta do reviver ninguém desce |
| — | Bancada de upgrades, frutas/verduras (DEC-101, DEC-106, DEC-109) | AST-049, AST-050 | bancada na parede oeste do Mart (MAP-01 revisão 3 §7.4, P34) |
| — | ~~Semáforos e faixas (DEC-120)~~ | ~~AST-077~~ | **Obsoleto** por DEC-130; faixa: `Q-129` (peça `Crosswalk` do AST-032) |
| — | Item de reviver (DEC-100, DEC-108, DEC-129) | AST-051 | |

---

## Comida (`food`)

Escala geral: comida ~1,5–2× o real (style guide §1.1). Todas usam o atlas do pack de origem ou o do projeto (§1.2).

### AST-001 — Bun (pão de hot dog)

- **Status:** Aprovado (DEC-137; **modelo aprovado DEC-141**) · **Prioridade:** P0 · **Origem:** Pack + edição — pão recortado de `FP/hot-dog.fbx` (tirar salsicha e molho → `Bun_Open`; `Bun_Closed` = fechar o corte; se a malha não for separável, modelar seguindo a mesma forma). ~~`FP/hot-dog-raw.fbx`~~ é a salsicha (sourcing)
- **Modelo (DEC-141):** `Assets/blender/food/AST-001_Bun.blend`, `Assets/models/food/AST-001_Bun.fbx`; `Bun_Closed` 128 / `Bun_Open` 152 tris. Pão refeito com corte em V e miolo Cream, mesma seção e cores do pack.
- **Uso:** caixa de pão → tábua → cortado (DEC-016, ITM-001).
- **Dimensões:** 1,0 × 0,45 × 0,35 studs (C × L × A), fechado.
- **Silhueta:** pão comprido arredondado, topo abaulado; aberto mostra o miolo creme em "V".
- **Cores:** Bun, miolo Cream.
- **Estados:** `Bun_Closed`, `Bun_Open`. Variante mordida da anomalia: AST-061.
- **Encaixes:** `Att_Sausage` (dentro do corte), `Att_Hand`.
- **Pivô:** base-centro. **Tris:** 150–250 por estado.

### AST-002 — Sausage (crua / grelhada)

- **Status:** Aprovado (DEC-137; **modelo aprovado DEC-141**) · **Prioridade:** P0 · **Origem:** Pack + edição — crua `FP/hot-dog-raw.fbx`; grelhada = mesma malha com recolor por UV na faixa marrom (~~`FP/sausage.fbx`, `FP/meat-sausage.fbx`~~: forma de linguiça / curva, ver sourcing)
- **Modelo (DEC-141):** `Assets/blender/food/AST-002_Sausage.blend`, `Assets/models/food/AST-002_Sausage.fbx`; `Sausage_Raw` 92 / `Sausage_Grilled` 164 tris.
- **Uso:** estoque → grelha (barra) → trilho → pão (DEC-016, ITM-002).
- **Dimensões:** 1,2 × 0,24 × 0,24 studs.
- **Cores:** Sausage Raw / Sausage Grilled com marcas de grelha (faixas escuras no UV se o pack não tiver). Variante cinza-azulada: AST-061.
- **Estados:** `Sausage_Raw`, `Sausage_Grilled`. Sem "queimada" (ITM-002: queima fora do MVP).
- **Encaixes:** `Bar_Cook` (1,0 acima), `VFX_Ready`, `VFX_Steam`.
- **Pivô:** centro geométrico. **Tris:** 100–200.

### AST-003 — Hot dog montado (Tool)

- **Status:** Aprovado (DEC-137; **modelo aprovado DEC-141**) · **Prioridade:** P0 · **Origem:** Pack + edição — `FP/hot-dog.fbx` (escolhido no teste do Studio); versão do Tool **sem molho** (recorte) para `Att_Topping1..3`; versão com molho para vitrine e ícone. Coerente com AST-001 `Bun_Open` + AST-002 `Sausage_Grilled`
- **Modelo (DEC-141):** `Assets/blender/food/AST-003_HotDog.blend`, `Assets/models/food/AST-003_HotDog.fbx`; Tool sem molho 316 tris (`Att_Topping1..3`) / `HotDog_Display` 414.
- **Empilhamento — decidido (DEC-142, fecha `Q-138`):** cada cobertura apoia no **topo real** da de baixo (altura real do modelo; Bacon 0,115, Potato Sticks 0,119, demais medir nos `.fbx`). **Queijo sempre antes dos cordões** (Ketchup, Mustard, Cream Cheese), qualquer que seja a ordem de montagem; as demais seguem a ordem de montagem. Leitura avaliada em 1ª pessoa (de cima e na mão); vão lateral de cordão não é critério (interpretação a confirmar). Aceite: nenhuma cobertura atravessa, some sob o queijo ou flutua visivelmente.
- **Uso:** ITM-010; Tool na mão (máx. 2), "Serve" no cliente, "Throw Away" na lixeira. Até 3 complementos (DEC-071).
- **Dimensões:** 1,2 × 0,45 × 0,45 sem coberturas.
- **Encaixes:** `Att_Topping1`…`Att_Topping3` (`Att_Topping1` no topo da salsicha; as seguintes pela altura real da cobertura de baixo, DEC-142), `Handle`/`Att_Hand`, `Att_Serve`.
- **Regra de leitura:** cada cobertura tem silhueta e cor próprias (zigue-zague largo = ketchup, zigue-zague fechado = mostarda, placa = queijo, tiras = bacon, monte = batata palha, espiral = cream cheese). O jogador confere olhando de cima, sem UI.
- **Estado alterado (ANM-002):** se montado com item de AST-061, mostra a salsicha cinza ou a mordida na mão (ITM-010).
- **Tris:** montado com 3 coberturas ≤ 900.

### AST-004 — Ketchup (garrafa + cobertura)

- **Status:** Aprovado (DEC-137; **cobertura aprovada DEC-141**) · **Prioridade:** P0 · **Origem:** Pack + edição — garrafa `FP/bottle-ketchup.fbx` (alt. `KP/ketchup.fbx`); cobertura = molho recortado de `FP/hot-dog.fbx`, 5 dobras
- **Cobertura (DEC-141):** `Assets/blender/food/AST-004_KetchupTopping.blend`, `Assets/models/food/AST-004_KetchupTopping.fbx`; 66 tris, 5 dobras.
- **Uso:** garrafa no porta-garrafas (AST-016); cobertura no hot dog.
- **Dimensões:** garrafa 0,35 Ø × 0,9 A; cobertura 1,0 × 0,12.
- **Silhueta:** garrafa de apertar com bico cônico; cobertura em zigue-zague de 5 dobras.
- **Encaixes:** `Att_Nozzle`; cobertura com pivô no início do zigue-zague.
- **Tris:** garrafa ≤ 300; cobertura 40–100.
- **Garrafa translúcida (DEC-140):** corpo da garrafa translúcido (style guide §6; Transparency com o art-director); líquido = peça interna separada **`Fill`**, pivô na base, que **sobe/desce com o estoque** do molho (style guide §3, estoque visível; lê sem HUD). Edição em andamento pelo modeler-3d: arquivos `AST-004_KetchupBottle` (`.blend`/`.fbx`). Animação do `Fill`: frontend-coder.

### AST-005 — Mustard (garrafa + cobertura)

- **Status:** Aprovado (DEC-137; **cobertura aprovada DEC-141**) · **Prioridade:** P0 · **Origem:** Pack + edição — garrafa `FP/bottle-musterd.fbx` (alt. `KP/mustard.fbx`); cobertura da mesma origem do AST-004, recolor + deformação para 7 dobras
- **Cobertura (DEC-141):** `Assets/blender/food/AST-005_MustardTopping.blend`, `Assets/models/food/AST-005_MustardTopping.fbx`; 86 tris, 7 dobras.
- Igual ao AST-004, cor Mustard; cobertura com **7 dobras** (forma diferente do ketchup, não só cor).
- **Garrafa translúcida + `Fill` animado (DEC-140)**, como no AST-004. Edição em andamento: `AST-005_MustardBottle`.

### AST-006 — Cheese (fatia + cobertura)

- **Status:** Aprovado (DEC-137; **modelo aprovado DEC-141**) · **Prioridade:** P0 · **Origem:** Pack + edição — fatia `FP/cheese-cut.fbx` (alt. `KP/food_ingredient_cheese_slice.fbx`); `Cheese_Topping` "derretido" = fatia dobrada com 2 pontas caindo
- **Modelo (DEC-141):** `Assets/blender/food/AST-006_Cheese.blend`, `Assets/models/food/AST-006_Cheese.fbx`; `Cheese_Topping` 148 / `Cheese_Slice` 160 tris (fatia acima do teto de 150 desta ficha; aceito com a aprovação).
- **Dimensões:** fatia 0,6 × 0,6 × 0,06; cobertura 1,0 × 0,4 com 2 pontas caindo.
- **Variações:** `Cheese_Slice` (pilha na cuba), `Cheese_Topping`. **Tris:** fatia ≤ 150; cobertura 60–150.

### AST-007 — Bacon

- **Status:** Aprovado (DEC-137; **modelo aprovado DEC-141**) · **Prioridade:** P0 · **Origem:** Pack — `FP/bacon.fbx` (pilha e cobertura = instâncias da mesma tira)
- **Modelo (DEC-141):** `Assets/blender/food/AST-007_Bacon.blend`, `Assets/models/food/AST-007_Bacon.fbx`; `Bacon_Topping` 160 (tiras de **0,8**, desvio aceito da tira 1,0) / `Bacon_Pile` 120 tris.
- **Dimensões:** tira 1,0 × 0,2 × 0,05, ondulada. **Variações:** `Bacon_Pile` (3 tiras), `Bacon_Topping` (2 tiras cruzadas). **Tris:** tira ≤ 120.

### AST-008 — Potato Sticks

- **Status:** Aprovado (DEC-137; **modelo aprovado DEC-141**) · **Prioridade:** P1 (libera no Day 4, DEC-071) · **Origem:** Pack + edição — palitos recortados de `FP/fries.fbx` (**sem a caixa vermelha**) + escala fina para virar monte
- **Modelo (DEC-141):** `Assets/blender/food/AST-008_PotatoSticks.blend`, `Assets/models/food/AST-008_PotatoSticks.fbx`; `PotatoSticks_Topping` 240 / `PotatoSticks_Pile` 344 tris (Pile acima do teto de 250 desta ficha; aceito com a aprovação).
- **Dimensões:** cobertura 1,0 × 0,35 × 0,15 (monte); na cuba, monte que a enche.
- **Silhueta:** monte baixo de ~20 palitos de 4 lados cruzados. **Variações:** `PotatoSticks_Topping`, `PotatoSticks_Pile`. **Tris:** ≤ 250.

### AST-009 — Cream Cheese (pote + cobertura)

- **Status:** Aprovado (DEC-137; **modelo aprovado DEC-141**) · **Prioridade:** P1 (Day 6, DEC-071) · **Origem:** Pack + edição — pote `KP/jar_B_medium.fbx`, tampa recolor Teal; cobertura = espiral de `FP/whipped-cream.fbx` escalada
- **Modelo (DEC-141):** `Assets/blender/food/AST-009_CreamCheese.blend`, `Assets/models/food/AST-009_CreamCheese.fbx`; `CreamCheese_Topping` 126 / `CreamCheese_Jar` 188 tris. Pote **0,6 × 0,6 × 0,78** (medida escolhida pelo modelador; aceita com a aprovação).
- **Dimensões:** cobertura 1,0 de comprimento, cordão 0,1 em ondas largas. **Variações:** `CreamCheese_Jar`, `CreamCheese_Topping`. **Tris:** cobertura 60–150.

### AST-010 — Coffee (copo, Tool) + par de cafés do Walt

- **Status:** Aprovado (DEC-137; **modelo aprovado DEC-141**) · **Prioridade:** P1 · **Origem:** Pack + edição — `FP/soda.fbx` (copo para viagem com tampa) **sem o canudo**, recolor (copo branco, cinta Teal, tampa Coffee; o roxo original sai). ~~`FP/cup.fbx`~~ é caneca
- **Modelo (DEC-141):** `Assets/blender/food/AST-010_Coffee.blend`, `Assets/models/food/AST-010_Coffee.fbx`; Tool 236 tris, sem canudo; `Coffee_Pair` L/R.
- **Correção de malha (modeler-3d, 2026-10-10, pedido do usuário) — Em revisão:** o sombreamento quebrava porque os anéis da faixa Teal (z ±0,095) eram cortes com vértices em ângulos irregulares, somados às normais customizadas do Kenney. Copo **refeito por revolução** com o mesmo perfil e as mesmas cores do atlas FoodPack (10 lados, laterais suaves, quinas de 90° marcadas como sharp por ângulo de 40°, sem normais customizadas, 0 vértice duplicado, 0 aresta aberta). **260 tris** por copo (≤ 300), bbox 0,33 × 0,35 × 0,55, `Att_Hand`/`VFX_Steam` nos mesmos pontos; `Handle`, `Coffee_Pair_L`/`_R` refeitos. Arquivos: `.blend` acima, `Assets/models/food/AST-010_Coffee.fbx`, `Assets/import/food/AST-010_Coffee.fbx`. Render: `Assets/reference/AST-010_Coffee_fixed_a.png`, `_b.png`.
- **Uso:** ITM-009, Tool "Coffee" da cafeteira (+25 de sanidade, DEC-055). Variante `Coffee_Pair`: os dois copos que Walt segura na cutscene final (DEC-075) e estende ao jogador.
- **Dimensões:** 0,35 Ø × 0,55 A.
- **Cores:** copo branco, cinta Teal, tampa Coffee.
- **Encaixes:** `Handle`/`Att_Hand`, `VFX_Steam`. `Coffee_Pair`: dois `Att_Hand` (um por mão do R6).
- **Tris:** ≤ 300 por copo.

### AST-011 — Pacotes do mercado (Tool)

- **Status:** Aprovado (DEC-137) · **Prioridade:** P0 · **Origem:** Pack + edição — `FP/bag.fbx`, `FP/bag-flat.fbx`, `FP/carton.fbx`, `FP/carton-small.fbx`, `FP/can.fbx`, `FP/can-small.fbx`; recolor por pacote (`carton`/`carton-small` obrigatório; nenhum em cinza-azulado); rótulos novos (AST-072)
- **Uso:** ITM-011 a ITM-019; comprado na prateleira → Tool → "Restock" (DEC-049). Máx. 2 por jogador (Hauler 3).
- **Variações (9):**

  | Pacote | Forma base | Cor dominante |
  |---|---|---|
  | Sausages | caixa deitada (`carton`) | Sausage Grilled |
  | Buns | saco (`bag`) | Bun |
  | Ketchup | lata alta (`can`) | Ketchup |
  | Mustard | lata alta (`can`) | Mustard |
  | Cheese | caixa baixa | Cheese |
  | Bacon | saco plano (`bag-flat`) | Bacon |
  | Potato Sticks | saco (`bag`) | Potato Sticks |
  | Cream Cheese | lata baixa (`can-small`) | Cream Cheese + Teal |
  | Coffee | saco (`bag`) | Coffee |

- **Dimensões:** 0,7–0,9 de maior lado. **Encaixes:** `Handle`/`Att_Hand`.
- **Rótulo:** ícone + nome em inglês, sem marca nem embalagem que imite produto real. **Tris:** ≤ 300 cada.
- **Modelo (modeler-3d, 2026-10-10, pedido do usuário) — Em revisão:** um arquivo por pacote, formas do Food Kit (CC0) na escala de antes, base-centro na origem, rótulo virado para frente/trás (os sacos foram girados 90° para a face larga ficar de frente na mão). Cor e rótulo por **textura** `Assets/textures/props/T_PackLabels.png` (1024², embutida em cada FBX; também usada pelo AST-051): fundo em gradiente da cor do produto, faixa de acento, painel Cream com contorno `#2B2233`, **desenho do produto = ícone do AST-071** e o nome em inglês (fonte Arial Black rasterizada; texto Provisório até o narrative-writer/AST-072). Sem marca.

  | Tool | Arquivo (`AST-011_…`) | Forma | Cor / acento | Tris |
  |---|---|---|---|---|
  | `pack_sausages` | `PackSausages` | `carton` deitado | Sausage Grilled / Mustard (topo Mustard) | 90 |
  | `pack_buns` | `PackBuns` | `bag` | Bun / faixa Teal | 44 |
  | `pack_ketchup` | `PackKetchup` | `can` | Ketchup / listras Cream, tampa Steel | 156 |
  | `pack_mustard` | `PackMustard` | `can` | Mustard / listras Ketchup, tampa Steel | 156 |
  | `pack_cheese` | `PackCheese` | `carton-small` deitado | Cheese / topo Teal | 70 |
  | `pack_bacon` | `PackBacon` | `bag-flat` | Bacon / pontas `#F3B7A0` | 110 |
  | `pack_potato_sticks` | `PackPotatoSticks` | `bag` | Potato Sticks / faixas e laterais Ketchup | 44 |
  | `pack_cream_cheese` | `PackCreamCheese` | `can-small` | Cream Cheese / Teal; rótulo também na tampa | 154 |
  | `pack_coffee` | `PackCoffee` | `bag` | Coffee `#7A4E36`→`#4A2E20` / faixa Cream | 44 |

  Arquivos: `Assets/blender/food/AST-011_Pack<Nome>.blend`, `Assets/models/food/…fbx`, `Assets/import/food/…fbx`. Render: `Assets/reference/AST-011_Packs_back.png`, `_front.png` (caixinhas deitadas como na mão). zfight 0. `tools/assetplace/build_items.luau` já aponta para os 9 nomes novos (sem recolor chapado; caixas medidas). **Obsoletos depois do upload:** `AST-011_Bag/BagFlat/Can/CanSmall/Carton/CartonSmall` (formas sem rótulo). Pendente: re-renderizar os 9 ícones `Item/pack_*` do AST-071 (hoje placeholders).

---

## Equipamentos (`equipment`)

Linha de estações do MAP-01 §7: **estoque de salsicha → grelha → trilho → pão → tábua → complementos → entrega/gaveta**, da esquerda para a direita,
**mesmos X no carrinho e no trailer**. Superfície a **3,5 studs** do chão/piso; profundidade da linha 3 studs (style guide §3).
Todo equipamento tem pegada padronizada para os `Mount_*` dos dois veículos. Os níveis de upgrade passam do carrinho para o trailer (`Q-075`, recomendação: sim).
Compra de upgrade: bancada do Mart (AST-049, DEC-101); a peça visível troca no veículo.

### AST-012 — Grill (3 níveis)

- **Status:** Em revisão (modeler-3d, 2026-10-10; direção Aprovada DEC-138, níveis DEC-201) · **Prioridade:** P0 · **Origem:** Modelar — **roller grill** (máquina de rolos de salsicha), ref. de forma `Assets/reference/AST-012_roller_grill_ref.png` (foto com marca: **sem logo, nome ou marca** no modelo). ~~`KP/stove_single_countertop.fbx` / `KP/stove_multi_countertop.fbx`~~ **recusados** (lê "fogão", DEC-138)
- **Uso:** UPG-001: 2 vagas/12 s → 3/10 s → 4/8 s. Barra de progresso sobre cada salsicha.
- **Dimensões:** pegada 5 L × 3 P no carrinho (X 31–36), 6 L no trailer (folga para o nível 3); altura da chapa 0,4 sobre a bancada.
- **Silhueta (DEC-138, a reescrever pelo art-director):** roller grill — caixa de inox, rolos horizontais em cima com as salsichas, gaveta aquecedora embaixo, painel frontal com botões. ~~chapa com grelhas em relevo, espelho traseiro baixo, 2 botões frontais grandes~~.
- **Níveis visíveis:** pendente de `Q-134` (leitura por nº de rolos / tamanho da máquina; não decidido). ~~`Grill_L1` chapa simples · `Grill_L2` segunda chapa · `Grill_L3` grelha grande com tampa cromada + friso Ketchup~~.
- **Cores (DEC-138):** **Steel** + acento **Ketchup** no painel frontal (style guide §2.1). Detalhe dos botões e rolos → art-director. ~~grelha `#3A3A44`; botões Mustard~~.
- **Encaixes:** `Slot1`…`Slot4` (0,9 entre centros), `Prompt_Grill`, `VFX_Steam1`…`4`.
- **Pivô:** base-centro. **Tris:** 600–1.200 por nível.
- **Modelo (modeler-3d, 2026-10-10, Em revisão; não enviado):** `Assets/blender/equipment/AST-012_RollerGrill.blend` → `Assets/models/equipment/AST-012_RollerGrill.fbx` (substitui o modelo de 6 vagas). Modelado do zero (nenhuma peça de KP/FP servia), atlas KayKit `restaurantbits_texture`. Um objeto por nível, todos na mesma origem (variantes sobrepostas, como `Rail_6`/`Rail_8`): `Grill_L1` 3 rolos **688 tris** (2,71 L) · `Grill_L2` 4 rolos **824** (3,61 L) · `Grill_L3` 5 rolos **960** (4,51 L, cabe nos 5 L). Profundidade 2,36, altura 0,78 (topo a ~4,23 no carrinho, abaixo do olho 4,5). Rolos finos cromados (Ø 0,28, 0,9 entre centros) sobre chapa escura; a salsicha fica deitada na chapa entre o par de rolos (rolo grosso o bastante para a salsicha de 0,24 apoiar no sulco tapava a salsicha em 1ª pessoa). Gaveta aquecedora (cenário), painel Ketchup com 1 botão por vaga + lâmpada Mustard, venezianas nas laterais. **Provisório:** a vaga N fica no mesmo lugar em todo nível (`Slot1`…`Slot4` em X −1,35/−0,45/0,45/1,35, Z 0,52; origem = centro da pegada de 5 L); L1/L2 alinham pela esquerda (−X) e a máquina cresce para +X. Isso casa com o `bind_map01.luau` (4 vagas fixas, sem `Level`). Âncoras (`Slot1`…`4`, `VFX_Steam1`…`4`, `Prompt_Grill`) ficam filhas de `Grill_L1`: o placement precisa manter o `Grill_L1` (com `part = { "Grill_L1" }` as 4 vagas continuam lá). zfight 0 em cada nível; os 2 pares entre níveis são da sobreposição das variantes. Renders: `Assets/reference/AST-012_RollerGrill_L1.png`, `_L2.png`, `_L3.png`, `_L3_firstperson.png`, `_lineup.png`.

### AST-013 — Trilho de descanso

- **Status:** Aprovado (DEC-140) · **Prioridade:** P0 · **Origem:** Modelar — `Assets/blender/equipment/AST-013_RestRail.blend`, `Assets/models/equipment/AST-013_RestRail.fbx`; `Rail_6` 384 / `Rail_8` 440 tris
- **Uso:** salsichas prontas acumulam (DEC-016). Capacidade 6 no carrinho, 8 no trailer (ITM-002).
- **Dimensões:** 3 L × 2,5 P, inclinado para o jogador.
- **Silhueta:** trilho de roletes com bordas laterais. **Cores:** Steel; roletes Mustard.
- **Variações:** `Rail_6` (carrinho), `Rail_8` (trailer, mesma largura, roletes mais próximos).
- **Encaixes:** `Slot1`…`Slot8`, `Prompt_Rail`. **Tris:** 400–900.

### AST-014 — Tábua + faca

- **Status:** Aprovado (DEC-138; **modelo aprovado DEC-141**) · **Prioridade:** P0 · **Origem:** Pack — `KP/cuttingboard.fbx`, `KP/knife.fbx`; **faca deitada** sobre a tábua (no pack vem em pé)
- **Modelo (DEC-141):** `Assets/blender/equipment/AST-014_CuttingBoard.blend`, `Assets/models/equipment/AST-014_CuttingBoard.fbx`; tábua 38 + faca 104 tris; faca deitada na **borda da frente**.
- **Uso:** pão cortado e montagem. Tábuas: 2 no carrinho, 3 no trailer (FEAT-016; `Q-068`).
- **Dimensões:** tábua 1,6 × 0,9 × 0,12; faca 0,9.
- **Encaixes:** `Att_Bun`, `Prompt_Board`. **Tris:** conforme pack.

### AST-015 — Caixa de pães (estoque de pão)

- **Status:** Aprovado (DEC-138) · **Prioridade:** P0 · **Origem:** Pack + edição — `KP/crate_buns.fbx` + `KP/crate_lid.fbx`, recolor e peça `Fill`; **trocar os pães redondos de hambúrguer pelos pães de hot dog do AST-001** (DEC-137) e **cortar tris** até o teto (candidato tem 2.772; teto ≤ 800 com `Fill`)
- **Uso:** "estoque de pão" (DEC-016, ITM-001), "Restock" (DEC-049). Pegada 2 L (X 39–41).
- **Dimensões:** 2,0 × 2,0 × 1,0.
- **Estoque visível:** `Fill` (camada de pães) sobe/desce; vazio = fundo da caixa.
- **Encaixes:** `Prompt_Take`, `Prompt_Restock`. **Tris:** ≤ 800 com `Fill`.

### AST-016 — Porta-garrafas de molho (2 vagas da grade)

- **Status:** Aprovado (DEC-140) · **DEC-218 (2026-10-10):** ketchup e mostarda passam a **tigelas** na grade AST-017; este porta-garrafas sai da grade. Destino (Obsoleto ou outro uso) em **`Q-172`** · **Prioridade:** P0 · **Origem:** Modelar (suporte) — `Assets/blender/equipment/AST-016_SauceHolder.blend`, `Assets/models/equipment/AST-016_SauceHolder.fbx`; 480 tris + `Fill` 28 cada; garrafas AST-004/005
- **Uso:** fileira da frente da grade de complementos (MAP-01 §7.1: frente = ketchup, mostarda, queijo).
- **Dimensões:** cada vaga ocupa a célula 2 × 1,5 da grade AST-017.
- **Silhueta:** suporte de arame com garrafa invertida; nível pela peça `Fill` interna. **DEC-140:** a garrafa opaca escondia o `Fill`; garrafas AST-004/005 passam a **translúcidas**, com o `Fill` animado subindo/descendo com o estoque (frontend-coder).
- **Encaixes:** `Prompt_Ketchup`, `Prompt_Mustard`, `Fill_Ketchup`, `Fill_Mustard`, `Prompt_Restock_*`. **Tris:** ≤ 300 por vaga.

### AST-017 — Grade de complementos 3 × 2 + tigelas de inox

- **Status:** Aprovado (DEC-138; **cubas trocadas por tigelas de inox, DEC-156**) · ~~Modelo novo: em produção, não aprovado~~ **Modelo de tigelas aprovado como está (DEC-218):** comida real, plaquinha, cadeado; **ketchup e mostarda também em tigela** (6 vagas = 6 tigelas; AST-016 sai da grade, `Q-172`) · **Prioridade:** P0 · **Origem:** Pack + edição — base/tampo `KP/kitchencounter_straight_A.fbx` (escala não uniforme para a caixa da ficha); **tigelas `KP/bowl.fbx`** (CC0, DEC-156); ingrediente dentro = peças picadas dos packs; cadeado "Padlock" da Quaternius (CC0, `Assets/models/equipment/AST-020_Padlock.fbx`, DEC-155).
- **Modelo anterior (DEC-141), superado quando o novo for aprovado:** `Assets/blender/equipment/AST-017_ToppingGrid.blend`, `Assets/models/equipment/AST-017_ToppingGrid.fbx`; base 274 tris; cuba + tampa + etiqueta + cadeado 386 tris.
- **Uso:** 6 complementos do MVP (DEC-071). Frente: ketchup, mostarda (~~AST-016~~ tigela, DEC-218), queijo; fundo: bacon, Potato Sticks, Cream Cheese.
- **Dimensões:** base 6 L × 3 P (X 44–50), células com 2 studs entre centros; fileira do fundo 0,3 mais alta (degrau) para o jogador ver as duas fileiras.
- **Silhueta (DEC-156):** **tigelas de inox** com o **ingrediente de verdade dentro**; **plaquinha frontal** `Label_<Ing>` em cada tigela. ~~Cubas de aço com tampa basculante e etiqueta frontal colorida.~~
- **Plaquinha:** o jogo põe `SurfaceGui` + `ImageLabel` com o **ícone do ingrediente** na `Label_<Ing>`. Ícones a definir (`Q-152`).
- **Variações:** uma por ingrediente da grade (`Bin_Cheese`, `Bin_Bacon`, `Bin_PotatoSticks`, `Bin_CreamCheese`; + `Bin_Ketchup`, `Bin_Mustard` por DEC-218): mesma tigela, muda o conteúdo (`Fill`) e o ícone. **Bloqueada** antes do dia de liberação: **tampa + cadeado Mustard** (Padlock, DEC-155).
- **Encaixes:** `Prompt_Use_<Ing>`, `Prompt_Restock_<Ing>`, `Fill_<Ing>`, `Label_<Ing>`. **Tris:** base ≤ 400; cuba ≤ 400 sem conteúdo (teto da ficha antiga; conferir com a tigela — art-director).

### AST-018 — Cooler / estoque de salsicha (3 níveis)

- **Status:** Aprovado (DEC-138) · **Prioridade:** P0 · **Origem:** Pack + edição — **nível 3** `KP/fridge_A.fbx` (reduzido à caixa 3 × 3 × 3,0); **níveis 1–2**: base `MM/freezer.fbx`, **modelados no estilo** sobre essa base (parte não coberta pelo candidato; não bloqueia a aprovação). Silhueta e cores dos níveis abaixo seguem valendo. **Níveis 1 e 2: modelo aprovado DEC-141.**
- **Modelo (DEC-141):** `Assets/blender/equipment/AST-018_CoolerL1.blend` / `_CoolerL2.blend`, `Assets/models/equipment/AST-018_CoolerL1.fbx` / `_CoolerL2.fbx`; L1 668 / L2 1.106 tris (L2 com duas tampas). L3 segue o candidato `KP/fridge_A`.
- **Uso:** estação de estoque de salsicha (início da linha, X 28–31) **e** peça visível do UPG-002 (capacidade 12 → 20 → 30).
- **Dimensões:** pegada 3 × 3. Nível 1: caixa térmica pequena com rodinhas (3 × 2,5 × 1,6); nível 2: caixa térmica dupla (3 × 2,8 × 2,2); nível 3: geladeira de inox baixa com porta (3 × 3 × 3,0, topo vira bancada a 3,5).
- **Cores:** Cream com tampa Teal; nível 3 Steel com friso Ketchup.
- **Estoque visível:** `Fill` (salsichas) na boca da caixa.
- **Encaixes:** `Prompt_Take`, `Prompt_Restock`, `VFX_Upgrade`. **Tris:** 400–1.200 por nível.

### AST-019 — Counter (3 níveis) + pedestais e marcas de fila

- **Status:** Aprovado (DEC-138) · **Prioridade:** P0 · **Origem:** Pack + edição — `KP/kitchencounter_straight_A.fbx` (balcão), `KP/kitchencounter_outercorner.fbx` (L3 em L), escala não uniforme para a caixa da ficha; banquinhos do L2 = `KP/chair_stool.fbx` com **assento plano, sem o rebaixo central** (corta polígonos); ref. `KP/wall_orderwindow.fbx`. **Pedestais com corda, toldo do L3 e marcas de fila seguem para modelar no estilo** (marcas = decal/Part plana; não bloqueiam a aprovação). **Pedestal, corda e marca: modelo aprovado DEC-141.**
- **Modelo (DEC-141):** `Assets/blender/equipment/AST-019_QueuePost.blend` / `_QueueMark.blend`, `Assets/models/equipment/AST-019_QueuePost.fbx` / `_QueueMark.fbx`; pedestal 94 + corda (`Rope`) 68 tris; marca 34 tris. Toldo do L3 segue a modelar.
- **Uso:** UPG-003 (fila 3 → 4 → 5, paciência +10/+20 s). Atender/recusar em Q1.
- **Níveis visíveis (upgrades.md):** `Counter_L1` balcão curto · `Counter_L2` estendido + banquinhos · `Counter_L3` em L com toldo.
- **Dimensões:** no carrinho, o balcão é a frente da linha (prateleira externa 3 × 0,8 a **3,0**, DEC-157; era 3,5); no trailer, balcão dobrável externo X 48–54 (MAP-01 §7.2).
- **Fila:** marcas de piso 2,0 Ø Mustard em Q1–Q5; **pedestais com corda** (Ketchup e Cream) para Q4 e Q5 aparecem com Counter 2/3 (L01-16).
- **Encaixes:** `Att_Serve`, `Prompt_TakeOrder`, `Prompt_Refuse`, `Prompt_Serve`, `Queue1`…`Queue5`.
- **Tris:** 300–900 por nível; marca ≤ 40; pedestal ≤ 150.

### AST-020 — Suporte de entrega + gaveta do caixa + Cash Drawer Lock

- **Status:** Aprovado (DEC-140; **silhueta e cadeado trocados por DEC-155**) · **Modelo novo: em produção, não aprovado** · **Prioridade:** P0 · **Origem:** Pack + edição (DEC-155):
  - Caixa: "POS Machine" de **J-Toastie** (Poly Pizza, https://poly.pizza/m/ju1CrAV1UY), **CC-BY 3.0, crédito obrigatório** (`art/credits.md`); 606 tris + gaveta separada 146.
  - Cadeado: "Padlock" da **Quaternius** (Poly Pizza, https://poly.pizza/m/2ZSHgKVr3F), CC0, recolor Mustard; `Assets/models/equipment/AST-020_Padlock.fbx` (reutilizado no AST-017).
  - **Superado quando o novo for aprovado:** `Assets/blender/equipment/AST-020_CashRegister.blend`, `Assets/models/equipment/AST-020_CashRegister.fbx` (registradora retrô, 860 tris + `Lock` 104; DEC-140).
- **Uso:** fim da linha (X 50–54, gaveta em (52, 37)); vendas vão para a gaveta, valor visível no mundo; alvo do ladrão (DEC-050); UPG-004.
- **Dimensões:** suporte de entrega 2 × 1,5; caixa registradora 1,6 × 1,4 × 1,0; gaveta desliza 0,6. (Medidas da ficha antiga; conferir com a POS no modelo novo — art-director.)
- **Silhueta (DEC-155):** **máquina POS preta** com gaveta. ~~Registradora retrô arredondada com teclas grandes. Cores: Ketchup, teclas Cream, gaveta Steel.~~ **Cores:** POS **preta**, como vem (decidido: "pode deixar a POS preta mesmo"); cadeado Mustard.
- **Estados:** `Drawer_Closed`, `Drawer_Open`. **Lock:** cadeado "Padlock" Mustard (DEC-155), legível do balcão. Gaveta guarda também o **crachá antigo** (AST-068), visível ao abrir.
- **Encaixes:** `Bar_Thief` (1,2 acima), `Value_Anchor`, `VFX_Coins`. **Tris:** ≤ 900; lock ≤ 200.

### AST-021 — Saco de moedas (ladrão)

- **Status:** Rascunho · **Prioridade:** P0 · **Origem:** Pack + edição — `FP/bag.fbx` recolor + 2–3 moedas saindo + "$" costurado (CHR-004)
- **Dimensões:** 0,8 Ø × 1,0 A. **Cores:** saco `#B9A27A`, "$" e moedas Mustard.
- **Encaixes:** `Handle`/`Att_Hand` (para o `RightGripAttachment` do R6). **Tris:** ≤ 300.

### AST-022 — Cafeteira (UPG-007)

- **Status:** Aprovado (DEC-140) · **Prioridade:** P1 · **Origem:** Modelar — `Assets/blender/equipment/AST-022_CoffeeMachine.blend`, `Assets/models/equipment/AST-022_CoffeeMachine.fbx`; 944 tris; jarra oca com café dentro, alça presa por gola/cinta
- **Uso:** só no trailer, **fixa** (vem com ele, não é vendida na bancada; DEC-055, DEC-125), posição (40, 44) (MAP-01 §7.2). Hold 1 s, preparo 6 s com barra, gera Tool Coffee (DEC-055); doses 10/20.
- **Dimensões:** máquina 1,6 × 1,2 × 2,0 sobre bancada a 3,5 (pegada da estação 3 × 3, MAP-01 L01-10).
- **Silhueta:** cafeteira de balcão com bico, jarra de vidro e botão grande; lâmpada de "pronto".
- **Cores:** Teal e Steel; jarra translúcida; lâmpada Neon pequena (verde ao ficar pronta).
- **Estoque visível:** `Fill` (pó na tremonha). **Encaixes:** `Prompt_Brew`, `Bar_Brew`, `Att_Cup`, `VFX_Steam`, `Prompt_Restock`.
- **Tris:** 500–1.000.

### AST-023 — Trailer Lights (UPG-005)

- **Status:** Aprovado (DEC-140) · **Prioridade:** P1 · **Origem:** Modelar — `Assets/blender/equipment/AST-023_TrailerLights.blend`, `Assets/models/equipment/AST-023_TrailerLights.fbx`; mastro 356 / cordão 486 tris
- **Uso:** $100, só no trailer: dia +10% fluxo; noite `LightZone` de 18 studs, ligada pelo interruptor AST-039 (DEC-055, FEAT-020).
- **Peças:** `Lights_Mast` (mastro no teto em (40, 41), refletor triplo) + `Lights_String` (cordão de 12 lâmpadas redondas sobre a janela, malha única).
- **Cores:** carcaça Steel; lâmpadas Neon `#FFE7C2`.
- **Encaixes:** `Light_Main` (SpotLight, sombra, alcance visual alinhado a 18), `Light_String` (2 PointLights fracas sem sombra).
- **Estados:** `On`, `Off` (segue o interruptor). **Tris:** mastro ≤ 600; cordão ≤ 500.

### AST-024 — Placa OPEN / CLOSED + "Available on Day 5"

- **Status:** Aprovado (DEC-138) · **Prioridade:** P0 · **Origem:** Pack + edição — `KP/menu.fbx` (cavalete de chão, conferido no teste), escala da ficha + decal; `Sign_ForSale` = mesma peça
- **Uso:** qualquer jogador abre o dia pelo prompt; vira "CLOSED" às 6:00 PM (DEC-048). Posição (25, 35).
- **Dimensões:** cavalete 2 L × 4 A × 1,2 P (MAP-01 L01-15).
- **Cores:** madeira `#C98B5A`; OPEN em Mustard sobre Teal; CLOSED em Cream sobre `#4B4F63`.
- **Encaixes:** `Prompt_Open`.
- **Variação `Sign_ForSale`:** placa em suporte 4 × 5 no estacionamento, "Available on Day 5" (DEC-047); só leitura (o prompt de compra fica no trailer). **Tris:** ≤ 300 cada.

### AST-025 — Lixeira (descartar)

- **Status:** Aprovado (DEC-140) · **Prioridade:** P1 · **Origem:** Pack + edição — "Trashcan" by Kenney (CC0, https://poly.pizza/m/eoC8NFaafh; `art/credits.md`) editado: tampa basculante, pedal novo, recolor Teal. `Assets/blender/equipment/AST-025_Trashcan.blend`, `Assets/models/equipment/AST-025_Trashcan.fbx`; 132 tris
- **Uso:** verbo "descartar" (DEC-054; ANM-002), pedido errado. Carrinho (56, 42) e trailer (43.5, 44) (MAP-01 §5.1, §7.2).
- **Dimensões:** 2 × 2 de pegada, 1,4 Ø × 2,2 A.
- **Silhueta:** lixeira de pedal com tampa basculante. **Cores:** Teal, pedal Steel.
- **Estados:** `Lid` animável. **Encaixes:** `Prompt_Discard`. **Tris:** ≤ 400.

### AST-039 — Interruptor "Lights" do trailer

- **Status:** Aprovado (DEC-140) · **Prioridade:** P1 · **Origem:** Modelar — `Assets/blender/equipment/AST-039_LightSwitch.blend`, `Assets/models/equipment/AST-039_LightSwitch.fbx`; 128 tris
- **Uso:** verbo "luz" (DEC-054); existe desde a compra do trailer e controla a lâmpada interna; com UPG-005 controla também AST-023 (FEAT-020). N3/ANM-003 depende dele.
- **Posição:** parede sul do trailer, (46, 46.5) (MAP-01 §7.2), perto da porta, com o relógio do banco à vista (FEAT-020).
- **Dimensões:** placa 0,6 × 0,9 × 0,15; alavanca grande 0,4.
- **Silhueta:** caixa de disjuntor antiga com alavanca grossa; lê "ligado/desligado" a 4 studs **no escuro**: a alavanca tem ponta Mustard e a placa tem lâmpada-piloto Neon (verde ligada, apagada desligada).
- **Estados:** `On`, `Off`. **Encaixes:** `Prompt_Switch`. **Tris:** ≤ 150.

### AST-040 — Banco do fundo do trailer

- **Status:** Aprovado (DEC-138) · **Prioridade:** P1 · **Origem:** Pack + edição — base `KP/kitchencabinet.fbx` ×3 (banco-baú); almofada modelada (Ketchup Faded); pés ref. `KP/chair_stool.fbx` (se usados, com o assento plano de DEC-138)
- **Uso:** X 27..36, Z 43..46 (MAP-01 revisão 3 §7.2). **Só cenário** (o jogador pode sentar). **Não é lugar de acordar:** depois da noite perdida a party acorda **em pé na calçada ao lado do trailer**, em REV-1..4 (DEC-122, emenda DEC-053). Nenhuma animação, câmera ou estado de "acordar no banco" usa esta peça. Não é lugar do jogador caído (DEC-091/DEC-093, spectate).
- **Dimensões:** 9 × 3 × 1,8 (assento a 1,6), **3 lugares** (MAP-01 revisão 3, L01-12).
- **Cores:** estofado Ketchup Faded, estrutura Steel.
- **Encaixes:** `Seat_1`…`Seat_3`. **Tris:** ≤ 800.

### AST-041 — Pontos de esconder "Hide" (×4)

- **Status:** Aprovado (DEC-138) · **Prioridade:** P1 · **Origem:** Pack + edição — `KP/kitchencabinet_half.fbx` como armário sob as estações; alça Mustard legível a 4 studs no escuro (sourcing)
- **Uso:** verbo "esconder" (DEC-054; ANM-008, ANM-009), um por jogador (`Q-094`). H1–H4 em (31/37/43/49, 39.5).
- **Forma:** porta de armário baixo integrada à frente interna da linha de estações; prompt "Hide" / "Get Up" (`ui-text.md`). A câmera desce para ~2 studs.
- **Leitura:** cada ponto com uma alça Mustard grande (lê a 4 studs no escuro); sem peça nova saindo do móvel.
- **Encaixes:** `Hide_1`…`Hide_4`, `Prompt_Hide_N`. **Tris:** ≤ 300 por porta.

### AST-042 — Telefone fixo do veículo

- **Status:** Aprovado (DEC-140) · **Prioridade:** P0 · **Origem:** Modelar — `Assets/blender/equipment/AST-042_VehiclePhone.blend`, `Assets/models/equipment/AST-042_VehiclePhone.fbx`; aparelho 396 / `Phone_Cart` 528 tris
- **Uso:** **decidido (DEC-124):** todas as ligações do chefe durante a run (dia no carrinho, noite no trailer) tocam aqui; qualquer jogador atende com "Answer", viva-voz para a party (FEAT-018). Também a alucinação "o telefone do trailer toca" (`script.md` §8). O celular flip (AST-038) fica só na cutscene de abertura.
- **Malha base única + 2 variantes** (alinhado a `story/world.md` §4; resolve `consistency-report.md` NW-8 do lado da arte):
  - `Phone_Cart` — carrinho: telefone **vermelho** antigo dentro de uma **caixinha** com tampa basculante (peça extra `Box`, 1,2 × 0,7 × 1,6), presa ao mastro do guarda-sol, lado do corredor. Cores: Ketchup, fone Cream, caixinha Ketchup com friso Cream.
  - `Phone_Trailer` — trailer: **telefone de parede creme** de fio enrolado, parede interna ao lado da janela de serviço. Cores: corpo e fone Cream, friso Ketchup Faded (mesma marca do trailer).
  - O aparelho (corpo, fone, sino, lâmpada) é a **mesma malha** nas duas; a cor muda por UV e a caixinha é peça à parte. O jogador reconhece "é o telefone do chefe" pela forma, nos dois veículos.
- **Dimensões:** aparelho 0,9 × 0,5 × 1,3 com fone 0,9 e fio enrolado; sino em cima.
- **Silhueta:** telefone de parede antigo, arredondado, fone grande; sino e lâmpada no topo.
- **Lâmpada:** Neon Mustard nas duas variantes (pisca ao tocar).
- **Estados:** `Idle`, `Ringing` (lâmpada + tremida por script), `OffHook` (fone fora do gancho durante a ligação).
- **Desvio aceito (DEC-140):** no modelo, o fio **não acompanha o fone** no `OffHook`. Resolver na implementação: trocar a peça do fio no `OffHook` ou usar `Beam` (frontend-coder).
- **Encaixes:** `Prompt_Answer`, `Light_Ring` (sem luz real, só Neon), `VFX_Ring` (ondinhas de som 2D). **Tris:** ≤ 400 (aparelho); caixinha ≤ 150.
- **Modelo novo (2026-10-10, pedido do usuário; Em revisão, sem DEC):** troca o telefone de parede modelado por um **telefone de mesa de disco** cartoon. Fonte: **"Low poly phone" by Anastasiia Ku**, https://poly.pizza/m/5AzrLGsLUdj, **CC-BY 3.0 (crédito obrigatório)**, 900 tris originais. Edição: escala 1,2 de largura (× 4,52), dedos do disco refeitos como hexágonos (440 → 40 tris), fone reduzido (248 → 88), cor movida para o atlas KayKit (`restaurantbits_texture.png`), lâmpada Mustard numa haste atrás do fone (`*_Lamp`, separada), **prateleira de madeira** com espelho de fixação (raiz `Phone_Cart` / `Phone_Trailer`) no lugar da caixinha com tampa. Fonte `Assets/blender/equipment/AST-042_VehiclePhone.blend`; `Assets/models/equipment/AST-042_VehiclePhone.fbx` (+ `_atts.json`); `Assets/import/equipment/AST-042_VehiclePhone.fbx`. Renders `Assets/reference/AST-042_VehiclePhone_*.png`.
  - Malhas por variante: `Phone_Cart` (prateleira, 112) + `Cart_Body` (corpo + disco + gancho + haste, 272) + `Cart_Handset` (88) + `Cart_Lamp` (28) = aparelho **388** (≤ 400). Trailer igual com prefixo `Trailer_`, deslocado 2,2 em X (mesmo esquema do modelo anterior). Sem `*_Cord` e sem `Lid`: o fio enrolado e a caixinha saíram (desvio da ficha; `OffHook` = fone sobe sozinho, sem fio).
  - Cores: carrinho corpo Ketchup, fone Cream, disco branco; trailer corpo e fone Cream, aro do disco Ketchup Faded (terracota do atlas). Medida do aparelho 1,2 L × 0,86 P × 0,8 A (com lâmpada); prateleira 1,4 × 1,0, altura total 1,07.
  - Empties (não viram Attachment no import; posições em `_atts.json`): `Prompt_Answer` (sobre o fone, lado da frente), `Light_Ring` (centro da lâmpada), `VFX_Ring` (0,35 acima), `Att_Mount` (costas da prateleira, z 0,6). Variante do trailer com sufixo `.001`.
  - Placement (`MAP-01_placements.luau`): `CART-PHONE` y 4,65 → **4,85** (prateleira acima da grade de coberturas, topo 4,75), `TRL-PHONE` (30,7; **7,85**; **36,35**), `Att_Mount` sobre o `Mount_Phone` dos dois veículos. Não verificado no Studio.

---

## Veículos (`vehicle`)

### AST-026 — Corner Cart (carrinho do chefe)

- **Status:** Aprovado (DEC-139; **casca aprovada DEC-141**) · **Prioridade:** P0 · **Origem:** Modelar (casca) + Pack nos guarda-sóis — `CC/detail-parasol-a.fbx` (9 A; tirar a mesinha da base, recolor Mustard/Cream). **Só os guarda-sóis** vêm do pack; a casca foi modelada no estilo.
- **Modelo (DEC-141):** `Assets/blender/vehicle/AST-026_CornerCart.blend`, `Assets/models/vehicle/AST-026_CornerCart.fbx`; casca 2.984 tris (~7.200 montado); linha 26 × 3, bancada ~~3,5~~ **3,0** (DEC-157), guarda-sóis a 9; posição de mundo **(41, 0, 37.5)**.
- **Altura (DEC-157, ajuste do usuário no Studio):** corpo `Body` **3,5 → 3,0**; bancada e encaixes das estações a **3,0** do Pad (y **3,45** no mapa; Pad 0,45). Fonte e posições atualizadas: `Assets/blender/vehicle/AST-026_CornerCart.blend`, `tools/assetplace/MAP-01_placements.luau`. Contradição com `style-guide.md` §3 (bancada 3,5) em `Q-153`.
- **Tampo do lado esquerdo (modeler-3d, 2026-10-10, pedido do usuário) — Em revisão:** sobre a baia do cooler (X −13,0 a −10,0) havia sobra de um boolean: um "bolso" de 18 faces invertidas dentro das chapas do tampo, com tampas viradas para baixo coincidentes com a face de cima (z 3,0), e a tira da borda solta (arestas abertas). Removido o bolso, tira soldada às chapas, fundo da chapa de cima e teto da baia refeitos virados para baixo. Resultado: `Body` **1.678 tris** (era 1.704), nenhuma face invertida no topo, z-fight 0 (antes 1), nenhuma normal de outra parte alterada; fica aberto só o fundo da chapa do meio, escondido sob o topo do corpo (fechar daria z-fight com o teto da baia). **Altura conferida nos FBX exportados: `Body` 29,5 × 3,0 × 4,28** (igual ao Studio), `Mount_*` a 3,0. Arquivos: `Assets/blender/vehicle/AST-026_CornerCart.blend`, `Assets/models/vehicle/AST-026_CornerCart.fbx` (estava com a altura antiga 3,5; reexportado), `Assets/import/vehicle/AST-026_CornerCart.fbx`. Renders: `Assets/reference/AST-026_CornerCart_fix_top_all.png`, `_zoom_back.png`, `_front_left.png`.
- **Guarda-sóis em 1ª pessoa — decidido (DEC-144, fecha `Q-139` a):** aparecem no topo da tela (beiral ~5,8 sobre o corredor); **mantidos** como no modelo aprovado; reavaliar em playtest em 1ª pessoa.
- **Uso:** dado pelo chefe, fixo no Pad da esquina Ninth & Juniper (DEC-019, DEC-020); um para a party (DEC-032). Nome "Corner Cart", letreiro "BRAMBLE'S CORNER DOGS" (`ui-text.md`).
- **Dimensões (MAP-01 §7.1):** linha de estações X 28–54 (**26** de largura) × 3 de profundidade, bancada a **3,0** (DEC-157; era 3,5); corredor de trabalho de 6 atrás; **dois guarda-sóis** a 9 de altura (um só não cobre 26 studs) sem tapar a linha de visão a ~4,5.
- **Silhueta:** carrinho de rua retrô comprido, cantos arredondados, 4 rodas grandes travadas, saia frontal com letreiro e slogan "Hot dogs on the corner since forever." (`world.md` §4). Lê "carrinho", não "barraca": rodas e engate visíveis.
- **Cores:** corpo Ketchup, listras Cream, frisos e guarda-sóis Mustard/Cream, metais Steel. Objeto mais saturado do mapa.
- **Encaixes (`Mount_*`):** `Mount_StockSausage`, `Mount_Grill`, `Mount_Rail`, `Mount_StockBun`, `Mount_Board`, `Mount_Toppings`, `Mount_Drawer`, `Mount_Counter`, `Mount_Phone`, `Mount_Sign`, `Zone_Center` (raio 14 do ladrão, DEC-050).
- **Letreiro e logo:** decals da folha AST-072 (salsicha sorridente original).
- **DEC-206 (2026-10-10, fecha `Q-143`):** o logo do carrinho passa a ser **o hot dog cartoon atual do avental** (`AST-053_CrewTex`), o mesmo dos personagens. Decal/textura sem mudar a forma aprovada (Provisório: posição na lateral/frente, art-director).
- **Estados:** `Open`; `Covered` (com AST-043, só no estacionamento depois da troca, se `Q-082` aceitar).
- **Pivô:** base-centro. **Tris:** carroceria 2.000–3.500; montado ≤ 8.000.

### AST-027 — Open Late Trailer (casca + interior)

- **Status:** Aprovado (**DEC-141**; era Rascunho) · **Prioridade:** P1 · **Origem:** Pack + edição — casca modelar; bancadas internas `KP/kitchencounter_straight_B.fbx` recolor
- **Modelo (DEC-141):** `Assets/blender/vehicle/AST-027_OpenLateTrailer.blend`, `Assets/models/vehicle/AST-027_OpenLateTrailer.fbx`; 4.452 tris; casco 28 × 12 × 11, piso +2, pé-direito 8,5. **Desvio aceito:** janela de serviço com **22,5** de largura (por causa da quina; abaixo diz X 30–53). Inclui a porta dos fundos do AST-066, que **segue Rascunho** (não aprovada por tabela).
- **Uso:** à venda no estacionamento desde o Day 1 (DEC-047); depois da compra trabalha **no Pad da esquina** (DEC-086), mesma fila. Nome "Open Late Trailer", letreiro desbotado "BRAMBLE'S — OPEN LATE". Trailer velho de alumínio "esperando há anos" (`world.md` §4).
- **Dimensões (MAP-01 §7.2):** casco 28 C × 12 L; piso interno a +2 (degraus na porta); interior 26 × 10; **pé-direito interno 8,5** do piso (+2) e **altura externa 11** do chão ao topo do casco (proposta da arte para fechar AD-8: com piso a +2 e janela com topo a 8 do piso, um casco de 10 externo deixaria ~7,5 de pé-direito e não caberia a janela; o level-designer troca "teto 10" / "28 × 12 × 10" no MAP-01 por "28 × 12 × 11 externo; pé-direito 8,5"); corredor de 4; janela de serviço parede norte X 30–53, peitoril 3,5 do piso, topo 8; porta parede sul X 47–51; engate a oeste até X 22.
- **Silhueta:** trailer retrô de cantos muito arredondados, rebites, faixa horizontal, toldo basculante sobre a janela, engate apoiado num calço.
- **Cores:** casca Aluminum; faixa Ketchup Faded + Cream; letreiro Mustard desbotado; interior Cream/Steel, piso xadrez `#2B2233`/`#F1EEE6`.
- **Estados:** `ForSale` (janela fechada, placa AST-024 `Sign_ForSale` ao lado, prompt de compra), `Open` (mesma malha; toldo aberto; luz conforme dia/noite).
- **Interior (peças de outras fichas):** linha de estações, cafeteira AST-022, lixeira AST-025, interruptor AST-039, banco AST-040, pontos de esconder AST-041, telefone AST-042, foto de 1979 no quebra-sol AST-068, porta dos fundos AST-066 (sem prompt, ANM-009).
- **Encaixes:** os `Mount_*` do carrinho + `Mount_Coffee`, `Mount_Lights`, `Mount_Switch`, `Mount_Trash`, `Mount_Phone`, `Seat_Back`, `Hide_1`…`Hide_4`, `Prompt_Buy`, `Light_Interior` (SpotLight com sombra), `Zone_Light` (referência do `LightZone` LZ-1).
- **Colisão:** casca `CanCollide = false`; paredes, piso e degraus como Parts simples.
- **Tris:** casca + interior 6.000–9.000; montado ≤ 16.000.

### AST-043 — Lona do carrinho

- **Status:** **Aprovado (DEC-217)** — ficha como está, com o uso da DEC-199 (carrinho coberto na vaga `TRL-SALE`) · **Prioridade:** P1 · **Origem:** Modelar
- ~~**Não modelada** na rodada 3 (DEC-141): espera `Q-082`.~~ `Q-082` fechada (DEC-199); pronta para o modeler-3d.
- **Uso:** carrinho coberto no estacionamento depois da troca pelo trailer, se `Q-082` aceitar a sugestão (`world.md` §4). **Não** entra na cutscene de abertura (MAP-01 §11.1 e `script.md` §1 não têm lona); se o narrative-writer quiser o beat, pede.
- **Dimensões:** veste o AST-026 (26 × 4 × 4), dobras largas, amarrada com 3 cordas.
- **Cores:** lona Mint-gray `#B7CFC6`, cordas Cream.
- **Estados:** `On`, `Off`. **Tris:** ≤ 1.200.
- **Modelo (modeler-3d, 2026-10-10) — Em revisão:** `Assets/blender/vehicle/AST-043_CartTarp.blend`, `Assets/models/vehicle/AST-043_CartTarp.fbx`, `Assets/import/vehicle/AST-043_CartTarp.fbx`; **1.152 tris**, uma malha `Lona` (lona + 3 cordas + nós). Medida 27,4 × 4,9 × 3,0 (Z 0,95–3,98: cobre o `Body` 26,5 × 3,3 + para-lamas, saia até ~1,3, rodas aparecem embaixo; calombos sobre grelha/tábua/coberturas/gaveta dão a altura 4). Mesmo referencial do AST-026 (origem do carrinho, +Y = frente do carrinho): CFrame da lona = CFrame do `Body` do carrinho. Se o runner usar centro da bbox, centro da lona X ≈ −0,02 contra X ≈ +1,05 do `Body` (Blender). Renders: `Assets/reference/AST-043_CartTarp_*.png`. **Provisório:** Mint-gray aproximado pelo cinza claro do atlas KitchenPack (`#BDC8CC`, o mais perto de `#B7CFC6`); no estado `Covered` os guarda-sóis `Parasol_E/W` e as estações precisam ser escondidos (os postes atravessam a lona); a alça de empurrar (X 13–14,5) sai pela aba da ponta, de propósito.

### AST-035 — Carros de trânsito (família de 4)

- **Status:** Aprovado (DEC-139) · **Prioridade:** P1 · **Origem:** Pack + edição — `Car_Sedan` `CK/sedan.fbx`, `Car_Hatch` `CK/hatchback-sports.fbx`, `Car_Van` `CK/van.fbx`, `Car_Pickup` `CK/truck.fbx`. Prévia aprovada com **uma escala para a família** (sedã 12, demais proporcionais, ≤ 14); medidas finais de hatch/van/picape: `Q-136`. ~~**Pendente (modeler-3d):** reduzir de ~2.030–2.090 para ≤ 2.000 tris~~ (feito, DEC-141). **Modelos aprovados DEC-141.**
- **Modelo (DEC-141):** `Assets/blender/vehicle/AST-035_CarSedan.blend`, `_CarHatch`, `_CarVan`, `_CarPickup`; `Assets/models/vehicle/` idem (+ `_Paints`); 1.360–1.416 tris cada; rodas separadas; 5 cores cada (Butter, Mint-gray e Teal claro **aproximados** no atlas, aceito com a aprovação).
- **Uso:** trânsito andando (DEC-087) e carros parados; atropelam em pastelão (DEC-095). Quantidade, rotas e dia/noite: `Q-102`. Convivência com o long car: `Q-103`.
- **Formas (4):** `Car_Sedan` 12 × 5,5 × 4,5 · `Car_Hatch` 9 × 5 × 4,5 · `Car_Van` 13 × 6 × 6,5 (serve de van parada do estacionamento, L01-28) · `Car_Pickup` 13 × 5,5 × 5.
- **Silhueta:** brinquedo: cabine em bolha, para-choques grossos "de espuma", rodas grandes. **Nenhuma** grade, logo ou forma reconhecível de montadora.
- **Cores:** 5 por remapeamento de UV (Peach, Butter, Lilac, Mint-gray, Teal claro). **Nunca** preto, nunca branco com faixa Teal (§2.4 do style guide).
- **Peças:** `Body`, `Wheel_FL/FR/RL/RR` (giram), `Headlights` (Neon), `Beam_L/R` (cone curto, só à noite), motorista opcional como silhueta lisa no vidro (sem rosto detalhado).
- **Encaixes:** `Hit_Front` (área de colisão do atropelamento), `VFX_Honk`. **Pivô:** base-centro. **Tris:** 800–1.500 cada; teto 2.000.

### AST-052 — Ambulância (+ maca levada pelos médicos)

- **Status:** Aprovado (DEC-139) · **Prioridade:** P1 · **Origem:** Pack + edição — `CK/ambulance.fbx` (16 × 7 × 8); maca, portas traseiras recortadas e barra de luz conforme `asset-sourcing.md`. ~~**Pendente (modeler-3d):** conferir o lado oculto~~ (conferido: sem cruz/emblema, DEC-141). **Ambulância: modelo aprovado DEC-141.**
- **Modelo (DEC-141):** `Assets/blender/vehicle/AST-052_Ambulance.blend`, `Assets/models/vehicle/AST-052_Ambulance.fbx`; 1.748 tris; Cream + faixa Teal; portas traseiras com pivô, vão **5,1 × 4,9**; compartimento de carga **8,37 de fundo × 5,13 de largura × 4,89 de altura** (medido pelo modeler-3d; o "~2 de fundo" da DEC-141 era leitura errada da prévia escura).
- **Maca na carga — decidido (DEC-143, fecha `Q-140`):** a maca aprovada (6,0 × 2,2 × 1,6) **já cabe** com as portas fechadas, folga ≥ 0,3; **não foi reduzida**. Encaixe no arquivo: **`Att_Stretcher_Stowed`**, Roblox **(0, 2.578, 4.454)** relativo ao pivô da ambulância = o `Stretcher_Dock` desta ficha (nome a unificar pelo art-director; até lá, vale o nome do arquivo). Empty antigo `Att_Stretcher` (abaixo do piso) **removido**.
- **Uso — ida (coleta), decidido em DEC-114:** a ambulância chega, para (AMB-M ou AMB-P, MAP-01 §5.5), abre as **portas traseiras** e os **2 médicos R6** (CHR-008, ficha AST-076) **descem** com a maca, vão até o corpo, o personagem deita na maca com "poof" e "Zzz" (style guide §4.6), eles levam a maca **à mão** de volta, sobem e as portas fecham. Lê "resgate de desenho animado", não hospital. Sequência e tempos: FEAT-034 / NPC-024 (game-designer).
- **Uso — volta do reviver (DEC-091, DEC-114):** volta, para em AMB-P em frente ao trailer, o jogador aparece ao lado, vai embora — **ninguém desce**; portas traseiras ficam fechadas.
- **Caso "corpo inacessível"** (FEAT-034, ainda Rascunho do game-designer; fora de DEC-114): a maca aparece na parada atrás das portas e o corpo some em fade. A peça `Stretcher` já serve; nenhuma malha extra.
- **Dimensões:** 16 C × 7 L × 8 A (toy van alta; medida do MAP-01 L01-36, ~16 × 7: com o centro em AMB-P (44, 13), as portas traseiras caem em X 36, como no MAP-01 §5.5); portas traseiras de 2 folhas abrindo 100° para os lados, vão livre 4 L × 5,5 A (2 médicos + maca passam); degrau traseiro a 1,0.
- **Maca (`Stretcher`) — modelada e aprovada (DEC-140):** `Assets/blender/vehicle/AST-052_Stretcher.blend`, `Assets/models/vehicle/AST-052_Stretcher.fbx`, 352 tris, encaixes `Att_Grip_Front`/`Att_Grip_Back` conforme abaixo. 6 × 2,2 × 1,6 (tampo a 1,6), branca com rodinhas pequenas e alças nas duas pontas; **carregada pelos médicos** (um em cada ponta, `Att_Grip_Front` / `Att_Grip_Back` presos no `RightGripAttachment` de cada um). Dentro da ambulância fica presa num trilho no piso; sai solta (sem animação de trilho).
- **DEC-211 (2026-10-10, fecha `Q-104`):** usuário confirma ambulância = **van do Car Kit adaptada**, original, sem marca, tom fofo — este modelo segue como está. Paramédicos: AST-076 (DEC-213).
- **Silhueta:** van arredondada com cabine curta, barra de luz no teto, degrau traseiro.
- **Cores:** Cream, faixa Teal larga, barra de luz Mustard/Teal (style guide §2.2, Aprovado). Texto lateral "BELLMOOR RESCUE" (placeholder do narrative-writer, AST-072).
- **Símbolo:** coração Teal com um "+" Cream arredondado. **Proibido:** cruz vermelha sobre branco, crescente vermelho, Star of Life, padrão xadrez de ambulância real, nome de serviço real.
- **Peças:** `Body`, `Wheel_*`, `Door_RearL/R` (dobradiça), `Stretcher` (peça solta), `Lightbar` (Neon alternando), `Driver` (silhueta lisa na cabine; o motorista não desce).
- **Encaixes:** `Att_Body` (no tampo da maca, onde o corpo do R6 é preso), `Att_Grip_Front`, `Att_Grip_Back` (na maca), `Medic_Exit_L`, `Medic_Exit_R` (no chão atrás das portas: onde os médicos descem e sobem), `Stretcher_Dock` (posição da maca guardada; no arquivo: `Att_Stretcher_Stowed`, DEC-143), `Spawn_Side` (onde o revivido aparece), `Light_Siren` (PointLight Range 10, sem sombra), `VFX_Poof`.
- **Áudio:** sirene curta de duas notas, baixa, fade (style guide §11).
- **Tris:** 1.500–2.500; teto 3.000 (sem a maca); maca ≤ 400.

### AST-074 — Ônibus urbano

- **Status:** Rascunho · **Prioridade:** P2 · **Origem:** Modelar
- **Uso:** "ônibus amarelo que passa de manhã" (`world.md` §2) na cutscene de abertura e, se `Q-102` couber, no trânsito de dia.
- **Dimensões:** 30 × 8 × 10. **Cores:** Butter `#F3DFA2` com faixa Peach (amarelo suave, não o de ônibus escolar real). Sem logo.
- **Tris:** ≤ 2.500.

---

## Mercado (`market`)

Interior do Ninth Street Mart (DEC-101): **prateleiras** de ingredientes, **área de frutas/verduras** (só cenário, DEC-109) e **bancada de upgrades na parede do fundo** (básicos sempre à venda + 1 vaga especial, DEC-106).
Planta do Mart: MAP-01 revisão 3 §7.4 (loja 36 × 32; bancada na parede oeste; frutas no canto NO; caixa da Opal perto da porta).

### AST-028 — Ninth Street Mart — fachada, letreiro e ponto seguro

- **Status:** Aprovado (DEC-139) → **Em revisão (modeler-3d, 2026-10-10)** · **Prioridade:** P0 · **Origem:** Pack + edição — `Wall` `MM/wall.fbx`, `Wall_Window` `MM/wall-window.fbx`, `Wall_Door` `MM/wall-door-rotate.fbx`, canto `MM/wall-corner.fbx` (módulo 8 × 12); `Awning` `CC/detail-awning-wide.fbx`. `Corner` chanfrado, `Roof_Trim`, `Marquee`, letreiros e `SafeZone_Marking` seguem modelar/decal. **Pendente:** as paredes MM esticadas a 12 ficaram pesadas e escuras — **art-director** avalia se servem com recolor Sage/Off-white ou se trocam por fachada CC/modelagem.
- **Modelo (modeler-3d, 2026-10-10, Em revisão; não enviado):** três arquivos novos, modelados no estilo com o atlas `CC/colormap` (CC0). `Assets/blender/market/AST-028_Marquee.blend` → `Assets/models/market/AST-028_Marquee.fbx` (**260 tris**: `Marquee` 196 + `Sign_Open24` 64): marquise 16 × 16 sobre a quina (X −66..−50, Z 22..38, face de baixo a 10,8), 2 postes em (−51, 23) e (−51, 37), faixa verde, caixas do letreiro no topo das bordas norte e leste; `Sign_Open24` = tubos coral separados (pôr `Material = Neon` no import); o texto "OPEN 24 HOURS" fica para `SurfaceGui`/AST-072 nas âncoras `Text_Open24_N` (face norte) e `Text_Open24_E` (face leste), área útil 11,4 × 1,6; `Light_Sign`, `Zone_Safe`. `AST-028_SafeZoneMarking` (**278 tris**): disco raio 6 × 0,04, borda Mustard larga (6→4,7), faixa coral (4,7→4,05), centro Mustard claro, em (−58, 0,4, 30). `AST-028_SignName` (**50 tris**): placa 14 × 2 Off-white com moldura verde na testeira norte (X −84, Z 27,2), texto "NINTH STREET MART" por `SurfaceGui` (`Text_Name`). Âncoras: `Assets/models/market/AST-028_*_atts.json`. Renders: `Assets/reference/AST-028_Marquee.png`, `AST-028_SafeZoneMarking.png`, `MAP01_street_mart_corner.png`, `MAP01_street_fp_pad_to_mart.png`. zfight 0. Não feito nesta rodada: `Corner` chanfrado e `Roof_Trim` (a quina segue o `MartWallDoor` girado 135°), pernas do `MartAwning`.
- **Uso:** compra (DEC-049, DEC-101); porta com linha de visão para o Pad; aberto 24 h; **ponto seguro da ANM-010** sob o letreiro "OPEN 24 HOURS" (`anomalies.md`, Aprovado; `Q-093`).
- **Dimensões:** loja **36 × 32** (X −100..−64, Z 32..64; MAP-01 revisão 3 §7.4 e §15 P36; a medida antiga 36 × 48 está **revogada**), pé-direito 12; módulos de fachada 8 L × 12 A (fachada norte 36 = 4 × 8 + `Corner` chanfrado de 4; fachada leste 32 = 3 × 8 + `Corner` de 4 + 4 de parede cega no fim). Vidro na fachada **norte** inteira e na **leste** de Z 32 a Z 56; parede cega leste Z 56..64 e parede oeste (bancada, AST-049) e sul sem vidro. Porta na **quina NE chanfrada** (−62, 34), marquise com o letreiro sobre a quina.
- **Peças:** `Wall`, `Wall_Window`, `Wall_Door` (porta dupla de vidro sempre aberta, com sininho), `Corner` (chanfrado), `Roof_Trim`, `Awning` (toldo listrado), `Marquee` (marquise da quina), `Sign_Name` ("NINTH STREET MART"), `Sign_Open24` (neon coral "OPEN 24 HOURS", nunca apaga), `SafeZone_Marking` (disco pintado no chão sob o letreiro, **raio 6** (12 de diâmetro) com centro em (−58, 30), igual ao volume do SS no MAP-01 §5.2 / P36; a marcação retangular 10 × 6 antiga está revogada; borda Mustard larga com faixa coral; lê à noite pela luz do neon).
- **Cores:** Sage, Off-white, toldo verde e branco; neon coral `#FF8A65` (exclusivo, style guide §2.3).
- **Encaixes:** `Light_Sign` (PointLight do neon), `Light_Interior` (SurfaceLight fria), `Zone_Safe` (referência do `LightZone` LZ-4 / zona segura).
- **Tris:** módulo 50–400; loja montada ≤ 4.000.

### AST-029 — Prateleira de compra + recheio + "Out of stock"

- **Status:** Aprovado (DEC-139) · **Prioridade:** P0 · **Origem:** Pack + edição — gôndola `MM/shelf-boxes.fbx` (alt. `MM/shelf-bags.fbx`), ponta `MM/shelf-end.fbx`; recheio `FP/can.fbx`, `FP/carton.fbx`, `FP/bottle-oil.fbx`, `FP/honey.fbx`, `FP/peanut-butter.fbx`, `KP/jar_*_small/medium` (**sem** `FP/soda-bottle.fbx`, risco de marca). Faces invertidas (caixas/sacos espelhados por escala negativa) corrigidas no exportador (DEC-139).
- **Uso:** prompt compra um pacote (DEC-049), hold 0,5 s. 9 pontos de compra, ≥ 3 studs entre si; Sausages e Buns a ≤ 15 da porta (MAP-01 §7.4).
- **Dimensões (DEC-139, ajuste do usuário no Studio):** gôndola **4,5 L × 2,5 P × 6 A** (era 8 L), 3 andares; andar de compra entre 3,0 e 4,5 (altura do olhar). Layout do Mart com a gôndola mais estreita: `Q-135` (level-designer).
- **Silhueta:** gôndola de metal, etiqueta de preço grande por ponto; pilha do próprio pacote (AST-011) exposta.
- **Ingrediente ainda não liberado:** etiqueta "Out of stock" (decal AST-072) e prateleira vazia (`Q-088`, recomendação do level-designer).
- **Encaixes:** `Prompt_Buy_<Pacote>`, `Price_Anchor_<Pacote>`. **Variações:** gôndola de 2 faces; ponta de gôndola.
- **Tris:** gôndola ≤ 800; recheio por andar ≤ 600 (instanciar as mesmas malhas).

### AST-030 — Geladeira expositora

- **Status:** Aprovado (DEC-139) · **Prioridade:** P0 · **Origem:** Pack + edição — `MM/freezers-standing.fbx` (4 × 7 × 2,5 na prévia); vidro translúcido, faixa Teal, recolor Off-white
- **Uso:** pacotes refrigerados (Sausages, Cheese, Bacon, Cream Cheese).
- **Dimensões:** 4 L × 2,5 P × 7 A, porta de vidro translúcida. **Cores:** Off-white, faixa Teal; luz interna fria.
- **Encaixes:** `Prompt_Buy_<Pacote>`, `Price_Anchor_<Pacote>`, `Light_Inner` (sem sombra). **Tris:** ≤ 1.000.

### AST-031 — Balcão do caixa do Mart (posto da Opal)

- **Status:** Aprovado (DEC-139) · **Prioridade:** P1 (subiu de P2: Opal fica atrás dele, DEC-079) · **Origem:** Pack + edição — `MM/cash-register.fbx` (balcão de caixa com maquininha; 6 × 3,5 × 2,5 na prévia) recolor Sage; banquinho, revista e caneca conforme sourcing
- **Uso:** cenário; Opal fica atrás (não vende). Raio de fala de 8 studs (NPC-020).
- **Dimensões:** 6 × 2,5 × 3,5. Inclui banquinho atrás, revista de palavras cruzadas e caneca.
- **Encaixes:** `Att_Opal` (posição e frente da Opal), `Balloon_Anchor`. **Tris:** ≤ 1.200.

### AST-049 — Bancada de upgrades do Mart (parede do fundo)

- **Status:** Aprovado (DEC-138; **modelo aprovado DEC-141**) → **Em revisão (modeler-3d, 2026-10-10)** · **Prioridade:** P0 · **Origem:** Pack + edição — tampo `KP/kitchencounter_straight_A.fbx` recolor; nichos `KP/shelf_papertowel.fbx`; painel GEAR WALL e vitrine S1 modelados no estilo
- **Recolor S1 feito (modeler-3d, 2026-10-10, Em revisão; não enviado; DEC-144):** as 66 faces douradas do `Frame_S1` foram para a faixa Mustard do painel (KP linha 2, coluna 3, a mesma das molduras e etiquetas); malha igual, **1.208 tris**. Mesmo nome de asset: precisa ser **reenviado**. Render: `Assets/reference/AST-049_GearWall_S1Mustard.png`, `_closeup.png`.
- **Modelo (DEC-141):** `Assets/blender/market/AST-049_GearWall.blend`, `Assets/models/market/AST-049_GearWall.fbx`; 1.208 tris montado; moldura da S1 modelada em Gold → **recolor para Mustard pendente** (modeler-3d; troca de faixa no atlas, sem mudar malha).
- **Moldura da S1 — decidido (DEC-144, fecha `Q-139` c):** **Mustard**, não Gold. Gold fica reservado ao AST-051 (style guide §2.1); §7.3 emendado.
- **Uso:** compra de upgrades por prompt (DEC-101), sem vendedor. **Básicos sempre à venda** — Grill, Cooler, Counter, Cash Drawer Lock, Trailer Lights — e **só 1 vaga especial** no sorteio por turno (DEC-106). Hoje o único especial é o Revive Kit (AST-051, ITM-021; 15% por turno depois da compra do trailer, DEC-129). Layout de posições: FEAT-015 (B1–B5 + S1). Food Trailer **não** está na bancada (DEC-107). Cafeteira **não** está na bancada (fixa no trailer, DEC-125).
- **Onde:** parede do fundo = parede **oeste** do Mart, X −100..−98, Z 39..57 (MAP-01 revisão 3 §7.4, P34). Jogador usa de X ≈ −96, virado para oeste; 14 studs livres na frente.
- **Dimensões:** balcão 18 L × 2 P × 3,5 A; painel de parede 18 × 6 acima dele com **6 módulos de 3 L** = **6 posições**, de norte para sul: **B1** (Z 40.5), **B2** (43.5), **S1** (46.5), **B3** (49.5), **B4** (52.5), **B5** (55.5). **S1 fica no meio**, no eixo do corredor do meio, para ser vista da porta (substitui "S1 na ponta").
- **Posições fixas B1–B5** (B1 Grill, B2 Cooler, B3 Counter, B4 Cash Drawer Lock, B5 Trailer Lights): nicho com caixa de produto (malha única) que recebe na frente o **ícone do próximo nível** (render da peça, AST-071) + placa com nome do nível, efeito em 1 linha e etiqueta de preço Mustard (texto por `SurfaceGui`, FEAT-015). Nível máximo: a placa mostra **"MAX"** e o prompt some. B5 antes da compra do trailer: placa "Trailer only" (DEC-055). Nenhuma posição fixa fica "SOLD" nem vazia.
- **Posição especial S1:** vitrine pequena de vidro com moldura **Mustard** (DEC-144) e lâmpada Neon que acende quando há Kit; o Revive Kit (AST-051) fica exposto. Vazia: placa "Nothing special today". Vendido: placa **"Sold out"** até o fim do turno (FEAT-035). É a **única** posição com "Sold out".
- **Leitura:** título no topo do painel "GEAR WALL" (`story/ui-text.md` §4), letras de **≥ 1,5 de altura**, legível da porta a **~40 studs** (S1 fica a ~36 em linha reta; P34). Vitrine S1 lê da porta pela lâmpada Neon acesa e pelo Kit exposto (brilhos Gold do próprio AST-051), no fim do corredor (DEC-144).
- **Cores:** painel Teal com moldura Mustard; balcão Off-white; S1 com moldura Mustard (DEC-144; emenda style guide §7.3).
- **Encaixes:** `Slot_B1`…`Slot_B5`, `Slot_S1`, `Prompt_Buy_<Slot>`, `Price_Anchor_<Slot>`, `Light_S1` (Neon, sem luz real), `VFX_Rare`. **Tris:** ≤ 1.500 montado.

### AST-050 — Área de frutas e verduras do Mart

- **Status:** Aprovado (DEC-139) · **Prioridade:** P1 · **Origem:** Pack + edição — expositores `MM/display-fruit.fbx`, `MM/display-bread.fbx`; caixote `KP/crate_lettuce.fbx` refeito: `Assets/blender/market/AST-050_LettuceCrate.blend`, `Assets/models/market/AST-050_LettuceCrate.fbx`, **1.159 tris** (**caixote aprovado DEC-141**); outros caixotes `KP/crate_tomatoes.fbx`, `KP/crate_carrots.fbx`, `KP/crate_onions.fbx`, `KP/crate_potatoes.fbx`; soltos `FP/apple.fbx`, `FP/banana.fbx`, `FP/orange.fbx`, `FP/pear.fbx`, `FP/lemon.fbx`, `FP/grapes.fbx`, `FP/watermelon.fbx`, `FP/pineapple.fbx`, `FP/cabbage.fbx`, `FP/broccoli.fbx`, `FP/corn.fbx`, `FP/eggplant.fbx`, `FP/paprika.fbx`
- **Uso:** **só cenário** no MVP (**DEC-109**; ingredientes seguem os de DEC-071). Sem prompt, sem pacote. Fruta/verdura como ingrediente fica para atualização futura com DEC própria.
- **Dimensões (DEC-139, ajuste do usuário no Studio):** expositor de frutas **4 L × 3,5 A × 3 P** (era 8 L × 3 P × 3,5 A). Layout no Mart: `Q-135`.
- **Montagem:** expositor inclinado de 2 degraus (base madeira `#C98B5A`) com caixotes do KitchenPack e frutas do FoodPack em pilhas; placa de preço decorativa.
- **Variante nova — expositor de pão de hot dog (DEC-139, pedido do usuário):** `MM/display-bread.fbx` com **10 pães AST-001** no lugar dos pães do pack; **918 tris**. Fonte `Assets/blender/market/AST-050_BunDisplay.blend`; exportado `Assets/models/market/AST-050_BunDisplay.fbx`. Lugar no Mart e se é só cenário ou ponto de compra dos Buns: `Q-135`.
- **Cor:** frutas Sat ~70% (canto alegre do Mart); nenhuma em cinza-azulado.
- **Tris:** base ≤ 300; montagem ≤ 3.000 (instanciar as mesmas frutas).

### AST-051 — Revive Kit — item raro de reviver (Tool, ITM-021)

- **Status:** Aprovado (DEC-140) · **Prioridade:** P1 · **Origem:** Modelar — `Assets/blender/market/AST-051_ReviveKit.blend`, `Assets/models/market/AST-051_ReviveKit.fbx`; 300 tris
- **Uso:** vendido na posição especial S1 da bancada do Mart (DEC-100, DEC-101, DEC-106), guardado na hotbar, revive um jogador (DEC-092). Moeda: **dinheiro da party** (DEC-108). Chance **15% por turno**, só depois da compra do trailer; preço **$200 × multiplicador da party** (DEC-129). Limite de 2 revives por jogador por noite (DEC-129). Forma de uso (próprio caído / colega de pé): `Q-120` f (game-designer). Nome "Revive Kit" é placeholder (ITM-021).
- **Proposta de forma (nome final com o narrative-writer):** **apito de resgate dourado** com cordão — "chama a ambulância de volta", o que combina com a sequência do reviver (DEC-091) e com a sugestão de ITM-021 (kit de "acordar" com um apito). Funciona tanto se o uso for "no colega caído" quanto "pelo próprio".
- **Dimensões:** 0,9 C × 0,5 L × 0,5 A (2× o real), cordão em laço 1,0. **Desvio aceito (DEC-140):** com o anel, o apito mede **1,09** (passa dos 0,9).
- **Silhueta:** apito gordo com bocal e anel, única na hotbar (nenhum outro Tool tem anel e cordão).
- **Cores:** Gold (exclusivo, style guide §2.1), cordão Teal.
- **Encaixes:** `Handle`/`Att_Hand`, `VFX_Rare` (brilho lento), `VFX_Use` (ondas de som 2D + "poof").
- **Tris:** ≤ 400.
- **Kit médico (pedido do usuário, 2026-10-10) — Em revisão; substitui o apito no mesmo arquivo:** caixa 0,8 × 0,4 × 0,5 com chanfro 0,04, branca (Cream claro), **alça em arco Gold** com dois apoios no topo, **cruz verde** `#3FA34D` com borda `#2B7A3A` na frente/trás e nas pontas (textura `Assets/textures/props/T_PackLabels.png`, a mesma do AST-011). Cruz verde de primeiros socorros, não é emblema protegido (o style guide proíbe Cruz/Crescente Vermelho). **172 tris.** `Att_Hand` na **origem, como antes** = centro da barra da alça (a caixa pende abaixo da mão: bbox Z −0,68 a +0,04); `VFX_Rare` no centro da caixa, `VFX_Use` 0,12 acima da alça. Arquivos: `Assets/blender/market/AST-051_ReviveKit.blend`, `Assets/models/market/AST-051_ReviveKit.fbx`, `Assets/import/market/AST-051_ReviveKit.fbx`. Renders: `Assets/reference/AST-051_ReviveKit_34.png`, `_end.png`. `build_items.luau` atualizado (caixa e encaixes). **Para o secretário/art-director:** a forma aprovada era o apito (DEC-140); proposta, silhueta e cores acima ficam desatualizadas até a DEC; ícone `Item/revive_kit` do AST-071 a re-renderizar.

### AST-098 — Bancada de feira do canto FRESH PRODUCE (Mart)

- **Status:** Rascunho (ficha nova, 2026-10-10, pedido do usuário) · modelo **Em revisão** · **Prioridade:** P1 · **Origem:** Pack + edição — **"Market Stand" by Quaternius**, https://poly.pizza/m/hts7l0NZxW, **CC0 1.0** (Poly Pizza), 1.132 tris originais.
- **Uso:** só cenário (DEC-109), no canto "FRESH PRODUCE" do Mart (MAP-01 §7.4, X −96..−88, Z 34..37), ao lado do expositor de frutas do AST-050; os dois caixotes de alface (AST-050) saem do chão e vão para cima da bancada. Sem prompt.
- **Edição:** toldo listrado e cortina do fundo removidos; postes cortados logo acima do tampo (tocos de 0,15 nos cantos); pernas esticadas (só o trecho entre o pé e a travessa) para o tampo ficar a **2,5**; tampo com 2 pares de tábuas copiados para trás (profundidade útil 2,0, cabe o caixote 2 × 2); cor movida para o atlas KayKit (tampo madeira clara, estrutura madeira avermelhada).
- **Dimensões:** 4,6 L × 2,65 A × 3,33 P (pés em A); tampo 4,5 × 2,03, entre postes 4,18 livres (dois caixotes de 2,0).
- **Silhueta:** mesa de feira de cavalete, pés em A com sapata, travessa baixa na frente, tampo de tábuas com frestas.
- **Encaixes:** `Slot_1`, `Slot_2` (empties no tampo, x ∓1,05; um caixote em cada; posições em `Assets/models/market/AST-098_ProduceStand_atts.json`).
- **Tris:** 468 (alvo prop médio 200–800, §9.1; proposta de teto da ficha ≤ 600).
- **Arquivos:** `Assets/blender/market/AST-098_ProduceStand.blend`, `Assets/models/market/AST-098_ProduceStand.fbx`, `Assets/import/market/AST-098_ProduceStand.fbx`; renders `Assets/reference/AST-098_ProduceStand*.png`.
- **Placement:** `tools/assetplace/MAP-01_placements.luau` (−89,65; 0,4; 35,807; rotY 180), caixotes em (−90,7 / −88,6; 2,91; 35,5). Não verificado no Studio.
- **Licença:** a referência de sourcing da skill `roblox-asset-pipeline` marca a licença geral da Quaternius como ambígua (página do autor fala em "QAL"); o Poly Pizza publica este modelo como CC0 1.0, e o projeto já usa o "Padlock" da Quaternius pelo mesmo caminho (DEC-155). Confirmar com o usuário se basta a página do Poly Pizza.


### AST-103 — Porta de enrolar de ripas de madeira

- **Status:** Rascunho (2026-10-11) · **Prioridade:** P1 · **Origem:** Modelar (nenhum pack tem porta de enrolar) · cor pelo atlas KitchenPack (`restaurantbits_texture.png`).
- **Uso:** portas do Gear Stand (MAP-01 §18.4/§18.5): sobem em `Prep`…`NightEnd`, descem nas outras fases. Estilo porta de banca de rua: ripas de madeira clara alternando 2 tons, trilhos laterais de aço, caixa do rolo de aço claro com friso Mustard, barra de baixo com pé de aço e puxadores Mustard.
- **Variantes:** `AST-103_RollerShutter` (avulsa: vão 5, 11 ripas de 0,35; 5,14 L × 4,59 A × 0,8 P; 792 tris) e `AST-103_RollerShutterTriple` (as 3 portas do §18.4 no referencial do Gear Stand: vãos 9,5 / 4 / 9,5, 14 ripas de 0,5, rolos em h 6,95–8,4; 24,14 × 8,4 × 1,1; 2.772 tris).
- **Partes animáveis (MeshParts separadas):** `Slat_01..Slat_11` (avulsa) e `L_Slat_01..14`, `C_Slat_01..14`, `R_Slat_01..14` (tripla), numeradas **de cima para baixo** (`Slat_01` logo abaixo do rolo; a última é a barra com puxadores). Fixas: `Rail_L`, `Rail_R`, `Roll` (com prefixo `L_`/`C_`/`R_` na tripla). Animação sugerida: cada ripa sobe até o rolo e some (`Transparency`), a de baixo por último.
- **Posição (tripla):** centro da base do bbox em WORLD (93,7; piso; 20), frente (−Z) para WORLD −X — alinha com o AST-104.
- **Arquivos:** `Assets/blender/market/AST-103_*.blend`, `Assets/import/market/AST-103_*.fbx`, renders `Assets/reference/AST-103_*.png`; script `tools/blender/mart_v2/build_shutter.py`.

### AST-104 — Gear Stand (estrutura/fachada do quiosque)

- **Status:** Rascunho (2026-10-11) · **Prioridade:** P1 · **Origem:** Modelar no atlas KitchenPack + `MM/cash-register` (Kenney, CC0) no balcão.
- **Uso:** substitui o AST-049 (GEAR WALL) no fundo do Mart (§18.4). **Sem** portas (AST-103 tripla) e **sem** pedestais (AST-105): modelos próprios no mesmo referencial.
- **Peças:** testeira Teal 25 × 4 (h 7–11) com campo escuro 16 × 2 e moldura Mustard para o neon **UPGRADES** existente (âncora `Neon_Upgrades`); 2 plaquinhas Cream lisas nas pontas para o nome da bancada (texto por SurfaceGui, TASK-142); cobertura Cream com friso Mustard; 4 postes Cream (0,5 × 0,8 × 7) com pé de aço e capitel Mustard; paredes laterais Teal com cantoneira; grade baixa (h 2,6) nos vãos L/R com rodapé de madeira, montantes e corrimão Mustard; prateleirinhas de fundo com caixas; balcão da Opal 4 × 1,6 × 3,5 (Cream, painéis Teal, tampo de madeira) com caixa registradora, campainha, revista e caneca.
- **Partes:** `Structure`, `OpalCounter`, `CashRegister` (atlas Mini Market), `Glass_L`, `Glass_R` (vidro: Transparency 0,5 no placement). Colisão: colisores simples (Parts) nos postes, grade e paredes; o jogador não entra.
- **Dimensões / tris:** 25,9 L × 11,38 A × 6,95 P; 2.643 tris (Structure 1.964).
- **Posição:** centro da base do bbox em WORLD (96,625; piso; 20), frente (−Z) para WORLD −X. Âncoras (pedestais B1–S1, `Opal_Stand`, `Neon_Upgrades`, `NamePlate_L/R`) em `Assets/import/market/AST-104_GearStand_atts.json`.
- **Arquivos:** `Assets/blender/market/AST-104_GearStand.blend`, `Assets/import/market/AST-104_GearStand.fbx`, renders `Assets/reference/AST-104_GearStand*.png` (inclui `_Assembled` com portas e pedestais); script `tools/blender/mart_v2/build_gearstand.py`.

### AST-105 — Pedestal de vitrine (Gear Stand)

- **Status:** Rascunho (2026-10-11) · **Prioridade:** P1 · **Origem:** Pack + edição — **"Column Round" by Quaternius**, https://poly.pizza/m/n8ZvVFcJhl, CC0 1.0 (Poly Pizza; mesma ressalva "QAL" do AST-098).
- **Edição:** topo escalado para 1,6; só o fuste esticado até a altura **3,0** do §18.4 (o pedido falava em ~1,2; com 1,2 a miniatura ficaria abaixo da grade de 2,6); cores de material trocadas por faixas do atlas KitchenPack por altura (base e capitel no acento, fuste Cream), então não precisa de `palette_bake`; colarinho no encontro fuste/capitel.
- **Variantes:** `AST-105_Pedestal` (B1–B5, acento Teal; 1,52 × 3,06 × 1,6; 536 tris) e `AST-105_PedestalS1` (acento Mustard + `Lamp` com 4 lâmpadas nos cantos, DEC-144; 648 tris).
- **Partes:** `Body`, `Ring` (anel sobre o topo: material **Neon** no Roblox), `Lamp` (só S1, Neon). Âncoras em `AST-105_Pedestal*_atts.json`: `Mini_Anchor` (h 4,2), `Price_Anchor` (face frontal do capitel), `Prompt_Buy`.
- **Arquivos:** `Assets/blender/market/AST-105_*.blend`, `Assets/import/market/AST-105_*.fbx`, renders `Assets/reference/AST-105_*.png`; script `tools/blender/mart_v2/build_pedestal.py`.

### AST-106 — Placas de seção do Mart

- **Status:** Rascunho (2026-10-11) · **Prioridade:** P1 · **Origem:** Modelar (atlas KitchenPack). Sem texto modelado (style guide §1.1): texto e ícone AST-071 por SurfaceGui nas peças `Face_Front`/`Face_Back`.
- **Penduradas** (placa 4 × 1,2 × 0,3, moldura colorida, painel Cream dos dois lados, 2 olhais e 2 hastes de aço `Rod_L`/`Rod_R` — cilindros simples: ajustar `Size.Y` no Roblox se o teto mudar): `AST-106_SignBakery` (Bun, h 8), `AST-106_SignProduce` (Mint, h 8), `AST-106_SignMeatDeli` (Ketchup, h 8,5), `AST-106_SignSaucesSnacks` (frente Mustard "SAUCES", verso Coffee "SNACKS · COFFEE", h 9). 344 tris cada; hastes cortadas para teto a 12 sobre o piso (3,27 / 3,27 / 2,77 / 2,27). Base do modelo = borda de baixo da placa.
- **De parede:** `AST-106_WallSignDairy` (Teal, 6 × 1,4, 2 espaçadores; 144 tris).
- **Arquivos:** `Assets/blender/market/AST-106_*.blend`, `Assets/import/market/AST-106_*.fbx`, renders `Assets/reference/AST-106_*.png`; âncoras `Text_Front`/`Text_Back` em `AST-106_*_atts.json`; script `tools/blender/mart_v2/build_signs.py`.

### AST-107 — Expositor refrigerado aberto de carnes (MEAT & DELI)

- **Status:** Rascunho (2026-10-11) · **Prioridade:** P1 · **Origem:** Modelar (atlas KitchenPack) + `KP/food_ingredient_steak`, `KP/food_ingredient_ham` dentro. Responde a P61 do MAP-01: `MM/freezer.fbx` **não serve** (baú fechado com tampas de vidro; em 4,5 de largura teria 2,0 de altura e esconde o produto).
- **Forma:** ilha baixa aberta 4,62 L × 2,85 A × 3,12 P (borda incluída): corpo esmaltado branco, faixa Ketchup, filete Teal, rodapé escuro, borda de aço, divisória no meio, fundo "gelo", trilhos Cream de etiqueta de preço nas duas faces. Metade com 2 bandejas de salsichas cruas, metade com bacon + bife + pernil. A ilha do §18.2 (9 × 3) = **2 unidades** lado a lado.
- **Partes:** `Case`, `Food`. Âncoras `Prompt_Buy_Sausages`/`Prompt_Buy_Bacon` (h 3,6) em `AST-107_MeatCase_atts.json`. Alcançável dos dois corredores (frente e verso iguais).
- **Tris:** 1.946 (Case 814, Food 1.132) — acima do alvo de prop médio; se pesar, a comida vira uma malha só de bandejas simples.
- **Arquivos:** `Assets/blender/market/AST-107_MeatCase.blend`, `Assets/import/market/AST-107_MeatCase.fbx`, renders `Assets/reference/AST-107_MeatCase*.png`; script `tools/blender/mart_v2/build_meatcase.py`.

---

## Rua, prédios e estacionamento (`street`, `building`)

Grade do kit: **módulo de 4 studs** (MAP-01 L01-20). Ruas: Ninth Avenue (32 de pista) e Juniper Street (24) (`world.md`, MAP-01 revisão 2).

### AST-032 — Kit de rua (piso, Pad, estacionamento)

- **Status:** Aprovado (DEC-139) · **Prioridade:** P0 · **Origem:** Pack + edição — `Road_Straight` `CR/road-straight.fbx`, `Road_Cross` `CR/road-crossroad.fbx`; demais peças conforme `asset-sourcing.md` (meio-fio vermelho, rampa, bueiro, batente modelados)
- **Peças:** `Road_Straight` (larguras 32 e 24, módulo de 8 de comprimento), `Road_Cross` (Ninth × Juniper com 4 braços: Juniper Sul aberta a carros, MAP-01 revisão 3), `Road_End`, `Crosswalk` (decal ou MeshPart plano, faixas Off-white `#F1EEE6` de 1,5 com 1,5 de espaço, 6 de profundidade, cortadas para 32 e 24; especificação herdada do AST-077 obsoleto; onde entra: `Q-129`), `Stop_Line`, `Sidewalk` (larguras 16 e 12), `Sidewalk_Corner`, `Curb` (normal e vermelho), `Curb_Ramp`, `Manhole`, `Pad_Tile` (concreto pintado `#E8D9B5`, 8 × 8, borda Mustard), `Parking_Tile` (16 × 16 com faixas), `Parking_Curb_Stop`, `Parking_Fence_Low` (≤ 3 de altura, não tapa o trailer à venda).
- **Cores:** Asfalto, Calçada, Meio-fio, faixas Off-white e Mustard.
- **Tris:** 12–200 por peça.

### AST-033 — Kit de prédio (fachadas modulares + cartões de fundo)

- **Status:** Aprovado (DEC-139) → **Em revisão (modeler-3d, 2026-10-10)** · **Prioridade:** P0 · **Origem:** Pack + edição — prédios inteiros `CC/building-a.fbx`, `CC/building-h.fbx`, recolor por lote (sourcing: o CC traz prédios inteiros, não módulos 8 × 12)
- **Modelo (modeler-3d, 2026-10-10, Em revisão; não enviado):** peças novas no estilo, atlas `CC/colormap` (CC0). `Assets/blender/building/AST-033_DoorD1.blend` → `Assets/models/building/AST-033_DoorD1.fbx` (**70 tris**: `DoorFrame_D1` 36 + folha `Door_D1` 34, pivô da folha na dobradiça, `Hinge_D1`, `Spawn_D1`): vão 3,6 × 6,5 na parede X 64 do `BuildingA` (topo do batente a 7,4, abaixo da laje do térreo a 7,5); folha azul com visor e puxador Mustard. `AST-033_NoHelpSign` (**42 tris**): cartaz 1,3 × 1,0 colado no vidro, texto "NO HELP WANTED" por `SurfaceGui`/AST-072 (`Text_NoHelp`); 3 instâncias: porta de vidro do B3b (X −93,3), porta do B2b (X −53,9) e janela da lavanderia (X −34,9). `BG_Card` em 3 variantes, **90 / 118 / 64 tris**: `AST-033_BGCard_A` (24 × 22, Brick, casinha no teto), `_B` (16 × 28, Peach, caixa d'água), `_C` (20 × 18, cinza-lilás), 3 de profundidade, janelas escuras com ~18% "acesas" (faixa clara do atlas), térreo com vitrine e toldo. Os cartões **não** entraram na tabela de placements (troca dos `Fill_*` é decisão do level-designer). Renders: `Assets/reference/AST-033_DoorD1.png`, `AST-033_NoHelpSign.png`, `AST-033_BGCard_A.png`/`_B`/`_C`, `MAP01_street_fp_pad_to_D1.png`, `MAP01_street_cs2_nohelp.png`. zfight 0.
- **Uso:** prédios baixos de tijolo e toldos coloridos de Bellmoor (`world.md` §2); **B1** (prédio atrás do Pad, 3 andares, porta D1; MAP-01 Z-09, L01-31) e B3/B4/B5 do MAP-01 montados só com o kit.
- **Peças:** `Facade_Wall` (8 × 12 por andar), `Facade_Window` (moldura e peitoril; faixa "acesa" no atlas), `Facade_Shopfront` (vitrine + toldo; versão com placa "NO HELP WANTED" para a cutscene), `Facade_Door`, `Door_D1` (variante animada de `Facade_Door` para a porta D1 de B1: abre/fecha na entrada e saída de clientes, MAP-01 (64, 48)), `Facade_Corner`, `Roof_Cap`, `Roof_Prop` (caixa d'água, antena), `BG_Card` (prédio de fundo em cartão).
- **Variações:** 5 cores por UV (Peach, Butter, Lilac, Brick, Mint-gray); 2–3 andares.
- **Tris:** módulo 12–300; fachada montada ≤ 2.500; `BG_Card` ≤ 300.

### AST-034 — Mobiliário urbano

- **Status:** Aprovado (DEC-139) → **Em revisão (modeler-3d, 2026-10-10)** · **Prioridade:** P1 · **Origem:** Pack + edição — placa `CR/road-sign-street.fbx`, árvore `CS/tree-large.fbx`, vaso `CS/planter.fbx`, cone `CK/cone.fbx`; banco de praça, lixeira de rua, hidrante e caixa de correio **modelados e aprovados (DEC-140)**:
- **Recolor (modeler-3d, 2026-10-10, Em revisão; não enviado; DEC-200):** `AST-034_TrashCan` ganhou acento **Mustard** (aro da tampa + cinta do meio; troca de faixa no atlas `CR/colormap`, malha igual, **260 tris**) e o vazio `Prompt_Discard` (topo, 2,95). Mesmo nome de asset: precisa ser **reenviado** (o id antigo em `_asset_ids.json` aponta para a versão cinza). Render: `Assets/reference/AST-034_TrashCan_Mustard.png`.

  | Peça | Tris | Arquivo (`.blend` em `Assets/blender/street/`, `.fbx` em `Assets/models/street/`) |
  |---|---|---|
  | Banco de praça | 572 | `AST-034_ParkBench` |
  | Lixeira de rua | 260 | `AST-034_TrashCan` (decorativa ou interativa: `Q-137`) |
  | Hidrante | 300 | `AST-034_Hydrant` |
  | Caixa de correio (genérica, verde, sem marca) | 288 | `AST-034_Mailbox` |

- **Peças:** banco de praça (5 × 1,6 × 2,6; espreita L3 do Quentin), lixeira de rua, hidrante, caixa de correio genérica sem logotipo, placas de nome de rua ("NINTH AVE", "JUNIPER ST", decal AST-072), vaso com arbusto, árvore redonda (6 Ø × 10 A), cone, ponto de ônibus simples (se AST-074 entrar).
- **Cores:** Sat ~55%; hidrante e cone em Mustard/Ketchup suaves.
- **Tris:** 100–800 por peça; árvore ≤ 1.000.

### AST-036 — Poste de luz (Juniper, Ninth, P-01)

- **Status:** Aprovado (DEC-139) · **Prioridade:** P0 · **Origem:** Pack + edição — `CR/light-curved.fbx` (alt. `CR/light-square.fbx`); cúpula Ø 2,0 com disco `Neon` modelada (sourcing) — **cúpula aprovada (DEC-140):** `Assets/blender/street/AST-036_LampHead.blend`, `Assets/models/street/AST-036_LampHead.fbx`, 208 tris, encaixa no `CR/light-curved` escalado a 14
- **Uso:** iluminação noturna; os postes da **Juniper** acendem às 8:00 PM e são o palco do Walker (passos sob os postes, ANM-007) e do Hush (apagam um a um até o da esquina, ANM-010). Poste **P-01** da esquina segura o panfleto (DEC-021, AST-037) e é espreita do Quentin. `LightZone` dos postes: FEAT-020.
- **Dimensões:** ~~14 A, braço 3~~ → **montado 14,45 A, braço 3,6** (desvio aceito, DEC-140); luminária a 13; base 1,2 Ø.
- **Silhueta:** poste curvo de cidade pequena, luminária em cúpula.
- **Leitura a ~135 studs (rodada 17, style guide §5.3):** cúpula larga (**Ø 2,0**, aba 0,3 para fora) com a lâmpada `Neon` **visível por baixo** (disco Ø 1,4, não escondido dentro da cúpula) para a fila de lâmpadas ler como pontos de luz contínuos até o último poste. Braço grosso (0,5) e curva única; nada fino que some na névoa.
- **Cores:** `#4B4F63`; lâmpada Neon `#FFB25A` (de dia, Cream sem Neon).
- **Estados:** `On`, `Off`, `Flicker` (script), `Off_Hush` (apaga com "tunk"; sem malha extra), `On_Fake` (lâmpada `Neon` + decal de poça, sem luz real; style guide §5.3).
- **Encaixes:** `Light_Lamp` (SpotLight sem sombra; nos postes da Juniper cone estreito, **poça de ~5–6 de diâmetro**, para deixar escuro entre postes a 8 studs), `Pool_Decal` (círculo Cream translúcido no chão, usado quando o poste não tem luz real), `Att_Flyer` (a 5,0 de altura, frente), `Walker_Spot` (ponto no chão sob a luz, onde o Walker para), `VFX_Moths`.
- **Quantidade (rodada 17):** Juniper com postes **a cada 8 studs**, o **último a ~135 studs** da janela do trailer; posições exatas e contagem no MAP-01 (level-designer). Mais P-01 da esquina e os da Ninth. Luz real só em ≤ 10 deles ao mesmo tempo (style guide §5.1); os demais em `On_Fake`. Instanciar a mesma malha (1 MeshPart reaproveitado).
- **LOD:** a partir de ~60 studs, versão ≤ 200 tris (cúpula e lâmpada mantidas, base simplificada).
- **Tris:** ≤ 600.

### AST-044 — Bellmoor Savings (fachada + relógio, ANM-003)

- **Status:** Aprovado (DEC-139) → **Em revisão (modeler-3d, 2026-10-10)** · **Prioridade:** P0 (landmark de dia) · **Origem:** Modelar + Pack na coluna — colunas `KP/pillar_A.fbx` (recolor Cream); volume da prévia em `CC/building-j.fbx` junto com AST-045. **Resto da fachada segue modelar** (frontão, relógio, quina chanfrada). ~~**Pendente:** `building-j` 5.246 tris → ≤ 2.500~~ (feito: `AST-045_ApartmentBlock`, 2.381; **volume do prédio aprovado DEC-141**)
- **Modelo (modeler-3d, 2026-10-10, Em revisão; não enviado):** `Assets/blender/building/AST-044_BellmoorSavings.blend` → `Assets/models/building/AST-044_BellmoorSavings.fbx`, modelado no estilo (atlas `CC/colormap`, CC0). **Térreo 912 tris** (`Body` 858 + `BankDoor` 44 + `BankSign` 10) + **relógio 326** (`Clock_Face` 60, `Clock_Frame` 112 com marcas e eixo, `Hand_Hour` 16, `Hand_Minute` 16, `Clock_Bell` 122) = **1.238**. Volume 28 × 32 × 18 (lote inteiro X 24..52, Z −64..−32: fecha o vazio atrás do banco), tijolo com rodapé, faixa e cornija Cream, quina chanfrada (3) na esquina **X 24, Z −32** (a voltada para o cruzamento; a ficha chama de "NO"), pórtico com 4 colunas Cream **modeladas** (substituem o `KP/pillar_A`, que ficava preso dentro da parede), entablamento com a placa `BankSign` (texto "BELLMOOR SAVINGS" por `SurfaceGui`, âncora `Sign_Anchor`), frontão triangular com o relógio C-01: Ø 6, centro em **(39, 14)**, mostrador a Z ≈ −30,3 (o pórtico avança 1,7 sobre a calçada). Ponteiros apontando para 12 h; pivô de giro = vazio `Clock_Center` (o centro da caixa dos ponteiros não é o eixo: usar `Assets/models/building/AST-044_BellmoorSavings_atts.json`). `Clock_Bell` = sino Mustard num braço de parede à direita do frontão (X ≈ 48,4, altura ≈ 13,6). `BankDoor` dupla (4 × 7,5), dobradiças `Hinge_BankDoor_L/R`. Encaixes `Audio_Tick`, `Audio_Bell`. Placement: (38, 0, −46,97) rotY 180 (substitui as 4 `AST-044_Column`). Renders: `Assets/reference/AST-044_BellmoorSavings_front.png`, `_corner.png`, `AST-044_Clock_closeup.png`, `MAP01_street_fp_trailer_to_bank.png`, `MAP01_street_bank_wide.png`. zfight 0.
- **Uso:** banco do outro lado da Ninth (MAP-01 Z-11, X 24..52; Z −64..−32) com relógio grande na fachada sul, visível do balcão e da janela do trailer (`world.md` §3); faz tique-taque. ANM-003: ponteiros param e o tique-taque some. É o relógio C-01 do MAP-01 (L01-24).
- **Dimensões (MAP-01 revisão 3, L01-24, L01-38, §15 P36):** lote de **28 de largura** (a medida antiga de 24 está revogada); o prédio inteiro (banco + apartamentos AST-045) tem fachada **28 L × ~30 A**. Esta ficha é o **térreo do banco**: **28 L × ~18 A** (pé-direito alto, frontão, colunas Cream), quina NO chanfrada (linha de visão janela → Juniper passa a 1 stud dela, MAP-01 §6). Relógio de **Ø 6** com centro a **~14** de altura em (39, −33), dentro do térreo (topo do mostrador a ~17, abaixo das janelas WV a 19).
- **Silhueta:** banco de cidade pequena com frontão e colunas gordas; relógio redondo com moldura grossa (lê a ~73 studs, distância do Pad no MAP-01 §6).
- **Cores:** Brick, pedra Cream, mostrador Cream, ponteiros `#2B2233`, letreiro "BELLMOOR SAVINGS" (AST-072).
- **Peças:** `Clock_Face` (emissivo fraco à noite, legível sem iluminar), `Hand_Hour`, `Hand_Minute` (pivô no centro, giram por script), `Clock_Bell` (bate 6 vezes no amanhecer da noite 10, FEAT-027).
- **Estados:** `Running`, `Stopped` (ANM-003). Sem malha extra.
- **Encaixes:** `Audio_Tick`, `Audio_Bell`. **Tris:** térreo ≤ 1.500 (com AST-045 por cima, prédio ≤ 2.500); relógio ≤ 400.

### AST-045 — Apartamentos sobre o Bellmoor Savings (ANM-006)

- **Status:** Aprovado (DEC-139) → **Em revisão (modeler-3d, 2026-10-10)** · **Prioridade:** P0 · **Origem:** Pack + edição — `CC/building-j.fbx` (andares recortados, recolor Peach) + `Window_Up_<N>` modeladas. ~~**Pendente:** reduzir de 5.246 tris~~ (feito). **Modelo aprovado DEC-141.**
- **Modelo (modeler-3d, 2026-10-10, Em revisão; não enviado):** `Assets/blender/building/AST-045_ApartmentBlock.blend` → `Assets/models/building/AST-045_ApartmentBlock.fbx` **refeito** (substitui o `building-j` reduzido de 22,57): só os andares 2–3, **28 × 18 × 12** (18 → 30 no mundo; casinha do teto até 32,2), **682 tris**; prédio inteiro com o AST-044 = **1.920** (≤ 2.500). Peach com cornija e faixa Cream, 3 janelas por andar na frente (3,0 × 3,6, molduras e floreiras no 2º andar), 2 por andar nas laterais, vidros escuros atrás. Motivo da troca: as janelas do `building-j` esticado mediam 1,35 e não davam leitura para a ANM-006 a ~70 studs. **WV-1..3** = `Window_Up_1` / `_2` / `_3` em X 31 / 38 / 45, vidro de **24,6 a 28,0**; cada uma com `Window_Up_N_Lit` (faixa clara, **atrás** do vidro: estado `Lit` = esconder o vidro), `Curtain_Up_N` (cortina fechada, duas folhas + varão, pivô no topo) e os vazios `Att_Waver_N` (lugar do cartão AST-063, entre a luz e o vidro) e `Light_WV_N`. Camadas a partir da parede: Lit 0,02 · silhueta 0,08 · vidro 0,14 · cortina 0,20 · moldura 0,35. Placement: (38, 18, −40,76) rotY 180. Mesmo nome de asset: precisa ser **reenviado**. Render: `Assets/reference/AST-045_ApartmentBlock_front.png`. zfight 0.
- **Modelo (DEC-141):** `Assets/blender/building/AST-045_ApartmentBlock.blend`, `Assets/models/building/AST-045_ApartmentBlock.fbx` (`building-j` reduzido); 2.381 tris (prédio inteiro, com o volume do AST-044).
- **Uso:** andares 2 e 3 **sobre o banco** (AST-044), do outro lado da Ninth (MAP-01 Z-11, L01-38; `anomalies.md` N6, `world.md` §3). Janelas WV-1..3 na fachada sul, **acima da linha do olhar** do balcão: o jogador ergue a câmera para ver a ANM-006 (MAP-01 §6: 10–17° acima do horizonte). Não tem porta de cliente; B1 (atrás do Pad, porta D1) é montagem do AST-033.
- **Dimensões:** sobre o térreo do AST-044, 28 L, de ~18 a ~30 de altura (2 andares de ~6); janelas WV-1..3 entre X 28 e 48, alturas **19–28** (MAP-01 revisão 3 §5.2, P36).
- **Peças próprias:** `Window_Up_<N>` (janelas WV-1..3 com cortina `Curtain` animável e estado `Lit`).
- **Estados de janela:** `Dark`, `Lit` (troca de cor no atlas, sem luz real), `Curtain_Open/Closed`. A silhueta que acena é AST-063.
- **Tris:** ≤ 1.000 por face (somado ao térreo do AST-044, o prédio fica no teto de fachada montada, 2.500).

### AST-046 — Lavanderia

- **Status:** Aprovado (DEC-139) → **Em revisão (modeler-3d, 2026-10-10)** · **Prioridade:** P1 · **Origem:** Pack + edição — `CC/building-e.fbx` (recolor Mint-gray/Off-white, toldo Lilac); vitrine e `Door_SPB` modeladas
- **Modelo (modeler-3d, 2026-10-10, Em revisão; não enviado):** `Assets/blender/building/AST-046_DoorSPB.blend` → `Assets/models/building/AST-046_DoorSPB.fbx` (**70 tris**: `DoorFrame_SPB` 36 + folha de vidro `Door_SPB` 34, pivô na dobradiça, `Hinge_SPB`, `Spawn_SPB`), entre os pilares da lavanderia, sob o toldo, em (−39,9, 0,4, −33,6) rotY 180. **Limite do `building-e`:** o toldo do pack fica a 4,74, então o vão é só **3,2 × 4,1** (não 4 × 7,5); para porta de altura normal a lavanderia precisa crescer ~1,5× ou trocar de prédio (art-director / level-designer). Vitrine com 4 máquinas não feita nesta rodada. Render: `Assets/reference/AST-046_DoorSPB.png`, `MAP01_street_laundry_spb.png`.
- **Uso:** B2 do MAP-01: porta SP-B de clientes de dia; fechada e escura à noite.
- **Peças próprias:** vitrine com 4 máquinas de lavar (cartão com recorte redondo), `Door_SPB` animada, placa (AST-072). Estados `Open_Day`, `Closed_Night`.
- **Tris:** ≤ 2.500.

### AST-047 — Barreira "Road Closed" (BAR-N, BAR-S)

- **Status:** Aprovado (DEC-139) · **Prioridade:** P1 · **Origem:** Pack + edição — cavalete `CR/construction-fence.fbx`, luz `CR/construction-light.fbx`, cone de AST-034 (`CK/cone.fbx`); listras por UV/decal
- **Uso:** limites do jogador na Juniper (MAP-01 revisão 3: BAR-N em Z −100, BAR-S em Z 80). A parede é só para personagens; **carros e NPCs passam**. A **Juniper Sul é aberta a carros** (rua com trânsito, sem beco): a **cerca do beco saiu** da ficha.
- **Montagem:** cavaletes e cones **só nas calçadas** (fora da pista); a pista fica livre para os carros. Nada atravessa a pista nem tapa a linha de visão janela → postes da Juniper (BAR-N) ou a rota Pad ↔ Mart.
- **Peças:** cavalete listrado Mustard/`#4B4F63` com placa (AST-072) e cone (de AST-034). Como passa carro na pista, "ROAD CLOSED" contradiz a cena: placa de calçada "SIDEWALK CLOSED" + seta "USE OTHER SIDE" (`story/ui-text.md` §4). ~~Cerca de tela 8 × 6 com portão~~ (removida; Juniper Sul aberta).
- **Tris:** ≤ 600 por peça.

### AST-048 — Caminhão de entrega parado

- **Status:** Aprovado (DEC-139) · **Prioridade:** P1 · **Origem:** Pack + edição — `CK/delivery.fbx` (20 C na prévia), recolor baú Off-white e cabine Peach
- **Uso:** oclusor e fim do mapa a leste (MAP-01 TRUCK), esconde a saída EX-E e o spawn AS-2.
- **Dimensões:** ~20 × 8 × 10. **Cores:** baú Off-white, cabine Peach; sem logo (placa genérica "DELIVERY" opcional, AST-072).
- **Tris:** ≤ 2.500.

### AST-077 — Semáforo (carro + pedestre) e faixa de pedestre — OBSOLETO

- **Status:** **Obsoleto** (DEC-130, 2026-10-08: sem semáforo no MVP; jogador atravessa por conta e risco; revoga DEC-120). Não vai ao modelador. ID não é reaproveitado. A peça `Crosswalk` passou para o AST-032 (uso conforme `Q-129`); pictogramas de pedestre saíram do AST-072. Texto abaixo mantido só como histórico.
- ~~**Prioridade:** P1 (entra com o trânsito, DEC-087) · **Origem:** Modelar~~
- **Uso:** **DEC-120** — semáforo com faixa de pedestre na travessia entre trailer e Mart e nos cruzamentos. Carros obedecem; NPCs só atravessam no **verde de pedestre**; jogador pode atravessar no vermelho (risco de atropelamento, DEC-095). Ciclo determinístico por tempo de servidor (`tech/architecture.md` §8.1; proposta em `tech/content-data.md` `Crossings`: carro 20 s, pedestre 10 s).
- **Onde:** posições com o level-designer (`consistency-report.md` LD-4 / AR-8). Candidatas no MAP-01 revisão 2: CW-2, CW-4 (Ninth, lados do T), CW-3 (meio da quadra, Pad ↔ estacionamento) e o T Ninth × Juniper. CW-1 (beco) não tem trânsito; se a travessia trailer ↔ Mart continuar por ele, só leva faixa, sem semáforo de carro.
- **Peças:**
  - `TrafficLight_Car` — poste curvo `#4B4F63` (mesma família do AST-036), 14 A, braço 4 sobre a pista; cabeça arredondada de 3 lentes (1,0 × 1,0 × 3,0) com pala grossa, base a 11 (passa ônibus de 10 e caminhão de 10): vermelho Ketchup, âmbar Mustard, verde `#5FA36A`. Poste fino: não tapa a linha de visão janela do trailer → JL-01..09 nem a faixa Pad ↔ Mart (MAP-01 §6); o level-designer confere na posição.
  - `TrafficLight_Ped` — poste reto 6 A no meio-fio, de frente para a faixa; cabeça 1,0 × 0,8 × 1,6 com 2 lentes: **boneco parado** (Ketchup) e **boneco andando** (verde `#5FA36A`), pictogramas próprios simples de traço grosso (decal AST-072), legíveis do outro lado da pista (~16–32 studs).
  - Variante `TrafficLight_Pole_Combo`: poste único com cabeça de carro no braço e cabeça de pedestre na altura 5, para economizar instâncias nas esquinas.
  - `Crosswalk` — faixas brancas Off-white `#F1EEE6` largas (1,5 de largura, 1,5 de espaço), 6 de profundidade, cortadas no comprimento da pista (Ninth 32, Juniper 24); decal ou MeshPart plano do kit AST-032, sem relevo.
- **Estados (por tempo, sem malha extra):** carro `Green` → `Amber` → `Red`; pedestre `DontWalk`, `Walk`, `Walk_Flash` (boneco andando pisca nos últimos 3 s). A lente acesa é peça `Neon` pequena; as apagadas ficam na faixa escura do atlas. **Sem luz real** (orçamento de luz, style guide §5.1).
- **Leitura:** forma e posição contam antes da cor (daltonismo vermelho-verde, style guide §2.4): vermelho sempre em cima, verde embaixo; boneco parado tem silhueta diferente do andando.
- **Noite:** segue o ciclo a noite toda, sempre igual (é padrão normal; nunca pisca fora do ciclo, para não competir com postes da ANM-007/ANM-010). Não apaga no Hush (só postes apagam). Mudança disso só com o narrative-writer.
- **Proibido:** sinalização ou pictograma copiado de um país ou marca específica; texto "WALK"/"DON'T WALK" modelado (se houver texto, é decal AST-072 em inglês, DEC-022).
- **Encaixes:** `Lamp_Red`, `Lamp_Amber`, `Lamp_Green`, `Lamp_Walk`, `Lamp_DontWalk` (peças trocadas por script), `Crossing_Key` (atributo com o ID da faixa, ex.: `CW-2`, para o `TrafficService`), `Stop_Line_Anchor`.
- **Pivô:** base-centro do poste. **Tris:** poste + cabeça de carro ≤ 600; poste de pedestre ≤ 300; faixa ≤ 50 por trecho.

---

## Personagens (`character`) — todos R6

Regras gerais: style guide §4 (opção A: `BodyColors` + acessórios de atlas + decals pequenos). Comportamento e números: `design/npcs.md`.

### AST-053 — Base de personagem R6 (cores, rostos, decals de roupa)

- **Status:** Rascunho · **Prioridade:** P0 · **Origem:** Plataforma (rig R6 do Roblox) + decals
- **Entrega:**
  - Tabela de `BodyColors`: 6 tons de pele variados + cores de "camisa" e "calça" da paleta (Sat ~55%, nenhuma reservada).
  - **8 rostos** neutros + 3 de reação (feliz, reclamação, bufando) + rosto "olhos fechados" (Raincoat Lady) + rosto escuro liso (Walker), 256² cada.
  - Decals de roupa 128²: textos assimétricos e logos genéricos por variante (sem marca real), e as versões espelhadas da ANM-004 (AST-062).
- **Regra:** todo rosto normal tem olhos e boca (ANM-001).
- **DEC-146 (2026-10-10):** esta base fica **só para NPCs humanos** (clientes; personagens com nome até `Q-146`). O jogador **não** usa esta base nem o avatar do Roblox: corpo base R6 custom da crew + peças por animal = **fichas novas** (art-director; `Q-144`, `Q-145`).
- **DEC-149 (2026-10-10, emenda DEC-146):** clientes e pedestres **também são animais**. "Só para NPCs humanos" acima não vale para clientes/pedestres; esta ficha a rever (provável: mesmo corpo base da crew + roupa de civil; `Q-149`). Textura dia/noite: DEC-148, DEC-150.
- **DEC-151 (2026-10-10):** modelo entregue aprovado: **roupa texturizada** `AST-053_CrewTex` e **rig R6** `AST-053_CrewBase` (+ `_joints.json`). O texto desta ficha (base humana com decals) segue Rascunho até o art-director reescrevê-lo para a crew.
- **DEC-152 (2026-10-10):** cabeças `AST-053_Animal_{Dog,Cat,Rabbit,Fox,Bear,Panda,Turtle,Owl}` **substituídas**: malha única **oval** com **focinho em volume** (ref. `customrig.png`), **olhos, nariz e boca por textura**, **expressões por troca de textura** (normal, feliz, sorridente, triste, desmaiado com X; lista aberta). Orelhas e caudas seguem. "8 rostos neutros + 3 de reação" acima vira o conjunto de expressões da crew/clientes (art-director). Técnica Provisória: casca de rosto com UV padrão comum a todos os animais, troca por `TextureID` (`Q-144` h). Versão noite: `Q-150`.
- **DEC-153 (2026-10-10):** direção de forma do usuário: focinho/boca **oval e liso**, sem nariz pontudo, **queixo redondo e fofinho**. Cabeças **v3** entregues (não aprovadas): focinho oval compacto abaixo dos olhos que continua no queixo; cabeça **728 tris** (antes 440), casca do rosto ~190–220; olhos y 4,86, nariz 4,47, boca 4,33 (UV do rosto v3; notas em `Assets/blender/character/AST-053_Animals_joints.json`). Personagem completo **1.914–2.104 tris**: acima do teto de NPC comum (1.800, style guide §9.1), abaixo do de personagem com nome (2.500). **Orçamento não aprovado**; aceitar ou reduzir a parte de trás da cabeça em `Q-144` (g).
- **DEC-154 (2026-10-10):** a variante de noite troca também orelhas, cauda, casco, bico e boné com furo (peças no atlas KitchenPack): atlas noturno `Assets/textures/character/T_Atlas_Kitchen_Night`, aplicado nos builds Night (`tools/assetplace/build_crew.luau`). Cabeça noturna aparece quase opaca no Roblox (azul-marinho; raposa perde o laranja): manter como está (Provisório) até `Q-151`.
- **DEC-158 (2026-10-10):** **+10 espécies** (18 no total): Pig, Mouse, Raccoon, Koala, Monkey, Lion, Frog, Penguin, Hamster, Sheep. Arquivos `Assets/blender|models/character/AST-053_Animal_<A>`, texturas `T_Head_<A>` / `T_Head_<A>_Night`; demo `workspace.CrewDemo` (`New_<A>_Day/Night`). **Entregues para revisão, não aprovados.** Tris ≈ 2,0–2,5k por personagem; **Sheep ≈ 2.530**, acima do teto 2.500 → `Q-144` (g). À noite todas as espécies ficam do mesmo azul-marinho → `Q-151`.
- **DEC-159 (2026-10-10):** peças do Quick Quentin guaxinim com prefixo desta família: chapéu `AST-053_ThiefHat`, rosto `T_Expr_Thief`, roupa `T_Civil_Thief_Day` (só dia). Ficha do personagem: **AST-056**. Em produção.
- **DEC-160 (2026-10-10):** roupas casuais de cliente/pedestre por textura: **6 conjuntos novos** `T_Civil_C` a `T_Civil_H` (dia e noite), além de `T_Civil_A`/`B` → 8 conjuntos. Em produção, não aprovados. Distribuição por tipo (AST-054) com `Q-149` (b).
- **DEC-161 (2026-10-10):** correções: (1) **um nariz só por espécie** — nariz sai das expressões compartilhadas e vai para a `T_Head_<A>`; quem tem nariz modelado/pintado próprio fica só com ele; (2) braços **retos** de civil `AST-053_CivilArms` (sem manga bufante/elástico; o **uniforme mantém a manga**); (3) **patinhas cartoon rosadas** (almofada + dedinhos) em todas as folhas de roupa, inclusive o uniforme.
- **DEC-162 (2026-10-10):** expressões novas **Skeptical, Exhausted, Stressed** (somam-se às da DEC-152). Sistema de humor dos NPCs: `Q-154` (depois).
- **DEC-163 (2026-10-10):** **aprovados** (modelo/textura): as 10 espécies da DEC-158, `T_Civil_A` a `H` (A/B repintadas), peças do Quentin (DEC-159), correções da DEC-161 e expressões da DEC-162. **Orçamento de tris não aprovado** (`Q-144` g; Sheep ≈ 2.530); cor da noite em `Q-151` (mãos com a cor do bicho, cabeça azul-marinho). Texto desta ficha segue **Rascunho** até a reescrita do art-director.
- **DEC-164 (2026-10-10):** tris **aprovados como entregues**: ≈ 2,0–2,5k por personagem completo, Sheep ≈ 2.530 aceito; sem redução da cabeça. Vale para crew e civil (mesma malha). `Q-144` (g) fechado na parte de tris; memória de textura segue aberta.
- **DEC-165 (2026-10-10):** noite = **azul-marinho igual para todas as espécies** (`Q-151` respondida, opção A). Braços/mãos acompanham: `T_Crew_Uniform_Night` e `T_Civil_A_Night` a `T_Civil_H_Night` com a camada da cabeça noturna (RGB 30, 32, 54; alpha 68) só nos texels de pelo; patinhas e roupa intactas (commit `70094d3`, entregue, não aprovado).
- **DEC-166 (2026-10-10):** **3 packs** por personagem: **dia**, **Mid** (novo, meio-termo) e **noite**. Visual = **sanidade**: alta → dia + `Normal`; média → Mid + `Exhausted`; baixa → noite + `Normal_Night`. Entregue (commit `d699cf7`, **não aprovado**): `T_Head_<A>_Mid` (18 espécies), `T_Crew_Uniform_Mid`, `T_Civil_A_Mid` a `T_Civil_H_Mid`, `T_Atlas_Kitchen_Mid`; protótipo `tools/assetplace/build_crew.luau` (`Crew.applyTime`, `Crew.setSanity`); demo `workspace.CrewDemo` (`Sanity_<A>_<High|Mid|Low>`). Emenda DEC-150 (noite do turno e sanidade baixa = mesmo pack). Abertos: critério da troca `Q-155`; faixas, quem e visibilidade `Q-156`; +1 pack inteiro na memória `Q-144` (g); `Normal_Night` entra em `Q-150`.
- **DEC-207 (2026-10-10, fecha `Q-150`):** só **`Normal_Night`** tem versão de noite. Feliz, sorridente, triste, desmaiado (X), Skeptical, Exhausted, Stressed: **uma versão** (a de dia), usada nos 3 packs. Sem "Assustado".
- **DEC-206 (2026-10-10, fecha `Q-143`):** o hot dog cartoon do avental em `AST-053_CrewTex` é o **logo oficial** do Bramble's (também no carrinho AST-026).

### AST-054 — Clientes normais e pedestre (7 tipos × 4 variantes)

- **Status:** Rascunho · **Prioridade:** P0 · **Origem:** Plataforma + Modelar (acessórios)
- **Tipos (npcs.md):** NPC-001 "Office Worker" (crachá, pasta) · NPC-002 "Student" (mochila, boné) · NPC-003 "Jogger" (faixa de cabeça, fone) · NPC-004 "Construction Worker" (capacete, colete refletivo) · NPC-005 "Grandparent" (cardigã, bengala) · NPC-006 "Night Shift Worker" (jaqueta de uniforme genérica, garrafa térmica) · NPC-019 "Pedestrian" (sacola).
- **Variantes:** 4 por tipo (invariante 3), cada uma com **detalhe assimétrico** legível no celular: texto no peito de um lado, relógio num pulso, bolsa ou pasta numa mão (invariante 10).
- **Acessórios a modelar:** ~16 malhas reaproveitadas entre tipos (crachá, pasta, mochila, boné, faixa, fone, capacete, colete, cardigã, bengala, jaqueta, garrafa térmica, sacola, relógio de pulso, 3 cabelos).
- **Proibido:** traço reservado (style guide §2.4), estereótipo de grupo real, marca.
- **Tris:** NPC montado 600–1.200; acessório ≤ 400.
- **DEC-164 (2026-10-10):** clientes e pedestres usam o rig animal (DEC-149): "NPC montado 600–1.200" acima **não vale**; segue a DEC-164 (≈ 2,0–2,5k).

### AST-055 — Mr. Pickett (CHR-005, NPC-021)

- **Status:** Rascunho · **Prioridade:** P0 · **Origem:** Plataforma + Modelar
- **Visual (characters.md):** baixo (postura), terno marrom (BodyColors + paletó acessório), gravata-borboleta verde, relógio grande no pulso **esquerdo** (`LeftGripAttachment`), maleta na mão **direita**, cabelo repartido à **esquerda**, bordado "PICKETT & SONS" no peito **esquerdo** (decal 128²).
- **Uso na ANM-004:** primeira cópia espelhada é dele (AST-062).
- **Tris:** ≤ 1.500.
- **DEC-203 (2026-10-10):** Pickett é um **rato** (Mouse, rig da crew). Terno marrom, gravata-borboleta verde, relógio no pulso **esquerdo**, maleta na mão **direita**, bordado "PICKETT & SONS" mantidos (por textura/acessório; Provisório, art-director). Rato comum de cliente nunca usa esse conjunto. Tris segue DEC-164 (≈ 2,0–2,5k).

### AST-056 — Quick Quentin (CHR-004, NPC-007)

- **Status:** Rascunho · **Prioridade:** P0 · **Origem:** Plataforma + Modelar
- **Visual:** magro e comprido (postura), sobretudo grande demais **cinza-arroxeado `#7A6FB0`** (lido a 110 studs, MAP-01 §6), chapéu de aba baixa, óculos escuros redondos, bigodinho fino (decal), tênis muito brancos. Carrega AST-021.
- **Tom:** vilão de desenho; sem máscara, sem arma, sem capuz de assalto.
- **Animações (AST-069):** espreita disfarçada (jornal, assobio), andar na ponta dos pés, abrir gaveta, fuga com saco.
- **Tris:** ≤ 2.000.
- **DEC-159 (2026-10-10):** Quentin é um **guaxinim** da crew (base AST-053 Raccoon). Visual acima mantido e adaptado: sobretudo `#7A6FB0` e tênis brancos em `T_Civil_Thief_Day` (**só dia**), chapéu malha `AST-053_ThiefHat`, óculos + bigodinho em `T_Expr_Thief`. "Plataforma + decal" acima não vale mais. Tris ≤ 2.000 × crew ≈ 2,0–2,5k: `Q-144` (g). Em produção, não aprovado; texto da ficha a reescrever pelo art-director.
- **DEC-163 (2026-10-10):** peças entregues **aprovadas**: `T_Civil_Thief_Day`, `AST-053_ThiefHat` (**cinza-ardósia**; o atlas não tem roxo), `T_Expr_Thief`. Sobretudo segue `#7A6FB0`. Tris ≤ 2.000 segue em `Q-144` (g). Ficha segue **Rascunho** no texto.
- **DEC-164 (2026-10-10):** "Tris ≤ 2.000" acima **não vale**: segue a DEC-164 (personagem do rig animal ≈ 2,0–2,5k, aprovado como entregue).

### AST-057 — Opal (CHR-003, NPC-020)

- **Status:** Rascunho · **Prioridade:** P1 · **Origem:** Plataforma + Modelar
- **Visual:** senhora (~65), coque grisalho com **lápis espetado**, cardigã verde, colete do Mart (Sage com crachá), óculos pendurados numa corrente.
- **Pose:** atrás do balcão AST-031, idle de palavras cruzadas (revista na mão), olha para o jogador quando fala.
- **Regra:** nunca é ator nem âncora de anomalia; nunca some (npcs.md).
- **Tris:** ≤ 2.000.
- **DEC-203 (2026-10-10):** Opal é uma **coruja** (Owl, rig da crew). Coque com lápis, cardigã verde, colete do Mart, óculos na corrente: adaptar à coruja (Provisório, art-director). Coruja também é classe jogável (CLS-006); a distinção vem do colete do Mart e do lugar fixo atrás do balcão. Tris segue DEC-164.

### AST-058 — Walt Bramble (CHR-001, só cutscene final)

- **Status:** Rascunho · **Prioridade:** P1 · **Origem:** Plataforma + Modelar
- **Uso:** aparece em pessoa **uma única vez**, na cutscene do amanhecer da noite 10 (DEC-075, DEC-076): sai do Mart com dois cafés. Modelo só no client (FEAT-027).
- **Visual:** ~70 anos, baixo (postura curvada), barriga redonda (acessório de tronco), bigode branco grosso (acessório de rosto), óculos grossos, **boné de feltro vermelho com a salsicha sorridente** (logo original, AST-072), jaqueta de uniforme creme e vermelha desbotada, crachá de metal "WALT — NIGHT SHIFT". Segura AST-010 `Coffee_Pair`.
- **Animações (AST-069):** sair pela porta, andar devagar, estender o café, acenar com a cabeça.
- **Tris:** ≤ 2.500.
- **DEC-202 (2026-10-10):** Walt é uma **tartaruga** (Turtle, rig da crew). Fala literal: "Faz uma tartaruga mesmo, ele vai ter uma animaçào mais corcunda, andando com um bastão de madeira e uma barba branca low poly, além da textura com rugas". Peças novas: **bastão de madeira** (na mão), **barba branca low poly** (substitui o bigode), **textura de cabeça com rugas** (própria do Walt). Animação: **andar corcunda** apoiado no bastão (AST-069). **Provisório** (art-director): bastão na mão esquerda e `Coffee_Pair` na direita; boné vermelho com o logo da DEC-206, óculos, jaqueta e crachá mantidos se couberem com a barba; tris ≤ 2.500 somando barba e bastão.

### AST-076 — Médicos da ambulância: Bellmoor Rescue crew (CHR-008, NPC-024)

- **Status:** Rascunho · **Prioridade:** P1 · **Origem:** Plataforma (R6) + Modelar (acessórios)
- **Uso:** **DEC-114** — na **ida** (coleta do desmaiado) os 2 médicos descem da ambulância (AST-052), vão até o corpo, levam-no na maca e sobem. Na **volta do reviver** não aparecem (DEC-091). Atores **visuais** dirigidos pela linha do tempo do servidor, fora do teto de 12 NPCs (NPC-024, FEAT-034). Não são anomalia nem âncora de anomalia; podem entrar no ponto seguro para buscar um corpo (MAP-01 §9.6).
- **Visual (`characters.md` CHR-008):** R6, uniforme **verde-menta** `#9FD8C4` (tronco e braços por `BodyColors`) com **faixa branca** horizontal no peito (acessório de colete fino), calça Mint-gray `#B7CFC6`, **boné menta**, **crachá redondo "BR"** no peito (decal 128², AST-072). Rostos gentis (decals da AST-053, olhos e boca sempre).
- **Dupla de desenho, "um alto e um baixo":** **sem** escala de corpo (só o Walker sai do tamanho R6, style guide §4.1/§2.4). A diferença vem de acessório e pose: `Medic_A` com boné alto de copa reta + cabelo volumoso (lê "alto"); `Medic_B` sem boné, cabelo curto e idle levemente curvado (lê "baixo").
- **Cores e regras:** Sat ~55%; nenhum traço reservado (§2.4). **Proibido:** cruz vermelha, Star of Life, estetoscópio, seringa, sangue, máscara cirúrgica, equipamento médico realista (DEC-023; CHR-008).
- **Peças:** acessórios `Medic_Vest` (faixa branca), `Medic_Cap`, `Hair_Medic_A`, `Hair_Medic_B`; decal `Badge_BR`. A maca é a peça `Stretcher` do AST-052 (cada médico segura uma ponta pelo `RightGripAttachment`).
- **Animações (AST-069):** descer pela traseira (degrau), andar levando a maca (dois em linha, maca entre eles), abaixar a maca e "colocar" o corpo (o corpo aparece deitado com "poof", sem contato de mão), levantar a maca, voltar, subir pela traseira. Idle calmo. Falas em balão (`characters.md`): uma por evento.
- **Variações:** 2 (`Medic_A`, `Medic_B`); sempre os mesmos dois (padrão fixo, como a ambulância).
- **Tris:** NPC montado 600–1.200 cada; acessório ≤ 400.
- **Máscara (modeler-3d, 2026-10-10, adiantada com a ficha em Rascunho):** `Acc_SurgicalMask_Rabbit` e `_Panda`, 108 tris cada, casca branca com pregas sobre focinho e boca (Z 4,04–4,65, abaixo dos olhos) + elásticos pela lateral da cabeça até a base das orelhas; âncora Head. `Assets/blender/character/AST-076_Acc_SurgicalMask_<Espécie>.blend`, `Assets/models|import/character/` idem. Render `Assets/reference/AST-076_SurgicalMask_*.png` (Day/Mid/Night com `Exhausted`). **Provisório:** branco do atlas (`#FBFCFC`), sem tom menta (o atlas não tem); ficha AST-076 segue Rascunho, malha precisa de aprovação junto.
- **2026-10-10:** espécie dos médicos **ainda aberta** (`Q-160`; propostas: dois porcos, ou coelho alto + panda baixo). Rig da crew (DEC-178); tris seguem DEC-164.
- **DEC-211 e DEC-213 (2026-10-10, fecham `Q-104` e `Q-160`):** `Medic_A` = **coelho** (alto pelas orelhas), `Medic_B` = **panda** (baixo); animais da crew com **roupa de paramédico** (textura no rig, no lugar de `BodyColors`/acessórios R6; não usar o uniforme do Bramble's); tom fofo. Rosto **fixo `Exhausted`** (DEC-162/166) em qualquer hora, sem troca de expressão. **Máscara cirúrgica** cobrindo a boca: **acessório ou textura, decide o art-director**. **Emenda desta ficha:** "máscara cirúrgica" **sai** da lista de proibidos; "olhos e boca sempre" não vale (boca coberta). Seguem proibidos cruz vermelha, Star of Life, estetoscópio, seringa, sangue, equipamento realista. `Medic_Cap`/`Hair_Medic_*` a rever pelo art-director (orelhas do coelho × boné). **Provisório:** com observador de sanidade baixa, expressão e máscara não mudam.

### AST-069 — Pacote de animações R6

- **Status:** **Aprovado (DEC-217)** — rig IK + lista de **35 clipes** do complemento "Rig IK e lista de clipes" (seção do levantamento pós-onda 1); **o usuário anima (DEC-220)**. Onde o texto abaixo divergir do complemento, vale o complemento. Desmaio = ragdoll + `Fainted`, **não é clipe (DEC-216)** · **Prioridade:** P0 · **Origem:** Animar (~~rig R6 padrão; quem produz: modeler-3d ou frontend~~ rig `AST-069_AnimalRig.blend`; animações: usuário)
- **P0 (dia):** cliente: andar (padrão R6), esperar no balcão (idle com fase aleatória), pagar, reações (feliz / reclamação / bufar), ir embora, recusado (aceno). Quentin: espreita, ponta dos pés, abrir gaveta, fugir.
- **P1 (noite e final):** Opal (palavras cruzadas, olhar), Raincoat Lady (aceno de cabeça, ficar parada pingando), cópia andando de costas (ANM-004), blank folk sem respiração (pose parada), ~~desmaio do jogador (sentar e deitar de lado)~~ (ragdoll, DEC-216), jogador na maca, médicos da ambulância (AST-076, DEC-114: descer, levar a maca em dupla, abaixar e levantar a maca, subir), Walt (andar devagar, estender o café), Walker (pose parada; o "passo" é teleporte entre postes, sem ciclo de andar).
- **Ragdoll do atropelamento:** física (juntas soltas), não animação; levantar = animação curta de 0,8 s.
- **DEC-202 (2026-10-10):** Walt (tartaruga) ganha **andar corcunda com bastão de madeira** (P1, cutscene final), além de estender o café e acenar.
- **Regra:** nenhuma animação de violência, queda dolorida ou contato entre personagens.
- **Rig de animação (modeler-3d, 2026-10-10, Em revisão):** `Assets/blender/character/AST-069_AnimalRig.blend` — cópia do rig da comunidade CommunityR6 (IK/FK, poles, LookTo, grab points, scripts de UI; crédito em `credits.md`, ferramenta, não vai ao jogo) com o corpo crew + as 18 espécies (propriedade `Species`), juntas = Motor6D do jogo (erro 0,0006 stud). Guia: `AST-069_AnimalRig.md`; renders `Assets/reference/rig/AST-069_*.png`; scripts `tools/animrig/`. Novo: "Pin Joint" (membro rígido gira no pivô em IK). Animações em si: a fazer.

### AST-073 — Avental Bramble's (acessório do jogador)

- **Status:** Rascunho · **Proposta do art-director: Obsoleto** (coberto por `AST-053_CrewTex` e `AST-053_CrewApron.fbx`), **não decidida** → `Q-172` · **Prioridade:** P2 · **Origem:** Modelar
- **Uso:** sugestão de `characters.md` CHR-002 (não decidida): uniforme aplicado na run por cima do avatar R6, sem trocar a roupa do jogador.
- **DEC-145 (2026-10-10):** o padrão de personagem passa a ser o "HotDog Crew" (`Assets/reference/customrig.png`: boné vermelho, avental vermelho com hot dog, camisa creme, calça preta, sobre corpo base R6 custom). Se o jogador usar o rig animal (`Q-141`), este avental vira parte do uniforme do personagem, não "por cima do avatar". Logo do avental: `Q-143`. Fichas do corpo base e dos animais: a escrever pelo art-director (`Q-144`).
- **DEC-146 (2026-10-10, fecha `Q-141`):** o jogador é animal da crew, sem avatar próprio. Este avental **é o uniforme da crew**, parte do personagem do jogador (não acessório "por cima do avatar"); o "Uso" acima não vale. Junto do avental: boné vermelho, camisa creme, calça preta (DEC-145) — peças/cores do corpo base a definir na ficha nova. Nome, prioridade (P2 → provável P0, já que todo jogador usa) e attachment → art-director. Logo `Q-143`.
- **DEC-148 (2026-10-10):** uniforme (camisa, avental com logo, calça) vem por **textura** no corpo, como na prancha, não por acessório de atlas. Orçamento `Q-144` (g); variante de noite `Q-148` (b).
- **DEC-206 (2026-10-10, fecha `Q-143`):** logo do avental = **o hot dog cartoon atual** da textura `AST-053_CrewTex` (mantido; é o logo oficial, também no carrinho).
- **Forma:** avental vermelho e creme com a salsicha sorridente, preso em `BodyFrontAttachment`.
- **Tris:** ≤ 300.

---

## Anomalias (`anomaly`) — ANM-001 a ANM-010 (DEC-073, DEC-096)

Conteúdo, sinal e verbo: `story/anomalies.md` (Aprovado). Números: `design/npcs.md` (NPC-009 a NPC-018).
Regra de arte: a anomalia usa as mesmas peças do normal e quebra **um** traço (style guide §4.4). "Consequências de sabor" só entram se `Q-065` aprovar.

### AST-059 — Raincoat Lady (CHR-006, ANM-005)

- **Status:** Rascunho · **Prioridade:** P1 · **Origem:** Plataforma + Modelar
- **Visual:** senhora pequena, capa de chuva **amarela `#F2C230`** com capuz (acessório de corpo inteiro), botas de borracha verdes, guarda-chuva fechado na mão, **olhos fechados** (rosto completo e gentil — contraste com ANM-001).
- **Sinal:** pingos constantes e poça que cresce no chão numa noite seca (VFX, style guide §10).
- **Uso no final:** passa do outro lado da rua no sol da manhã, acena com a cabeça e "desaparece numa poça" (`ending.md` §2.2): poça + "poof" de gotas.
- **Regra:** nunca assustadora. **Tris:** ≤ 2.000.
- **DEC-203 (2026-10-10):** Raincoat Lady é um **sapo** (Frog, rig da crew). Capa amarela `#F2C230`, botas verdes, guarda-chuva, **olhos fechados** e o sinal de água mantidos (`anomalies.md`, Aprovado). Sapo comum de cliente nunca usa capa amarela (§2.4). Tris segue DEC-164.

### AST-060 — ANM-001 The blank folks

- **Status:** Rascunho · **Prioridade:** P1 · **Origem:** decal + Modelar
- **Peças:** cliente normal (AST-054) **sem decal de rosto** (cabeça lisa na cor da pele), sem respiração no idle; balão de pedido vazio (UI); `Coin_Blank` (moeda sem desenho, sabor, 0,4 Ø) — mesma malha da moeda de pagamento com a face lisa.
- **Proibido:** rosto deformado, buraco, costura. **Tris:** moeda ≤ 80.

### AST-061 — ANM-002 The wrong food

- **Status:** Aprovado (DEC-137; **modelo aprovado DEC-141**) · **Prioridade:** P1 · **Origem:** Pack + edição — salsicha `FP/hot-dog-raw.fbx` (mesma do AST-002) com recolor cinza-azulado ANM-002; pão de AST-001 com mordida em meia-lua
- **Modelo (DEC-141):** `Assets/blender/anomaly/AST-061_WrongFood.blend`, `Assets/models/anomaly/AST-061_WrongFood.fbx`; `Sausage_Wrong` 164 / `Bun_Bitten` 208 tris.
- **Peças:** `Sausage_Wrong` (mesma malha da grelhada, UV na faixa Sausage Wrong cinza-azulada, sem marcas de grelha) · `Bun_Bitten` (pão aberto com **mordida em meia-lua** cartunizada numa ponta, malha própria).
- **Leitura:** distinguível a 3 studs no celular (ITM-020). Nada nojento.
- **Sabor:** fumaça cinza clara quando o cliente morde (style guide §10).
- **Tris:** ≤ 250 cada.

### AST-062 — ANM-004 The copies (variantes espelhadas)

- **Status:** Rascunho · **Prioridade:** P1 · **Origem:** decal + Modelar
- **Peças:** para cada variante de cliente (AST-054) e para o Mr. Pickett (AST-055): decal de texto **espelhado** (128²), acessórios de pulso e mão presos no attachment do **lado oposto**, cabelo com malha espelhada (só os 3 cabelos com risca).
- **Leitura principal no celular:** o texto invertido na roupa (`anomalies.md` N4).
- **Proibido:** qualquer outra diferença (cor, tamanho, rosto). A cópia nunca é sem rosto.

### AST-063 — ANM-006 The wavers (silhueta na janela)

- **Status:** Rascunho · **Prioridade:** P1 · **Origem:** Modelar
- **Uso:** ator de ambiente sem humanoide (npcs.md NPC-014): uma janela de cima dos apartamentos (AST-045) acende e uma silhueta acena devagar.
- **Peças:** `Silhouette_Card` (cartão escuro `#2B2233` de busto, recortado, atrás da cortina) com braço separado (`Arm_R`, pivô no ombro; variante `Arm_L` para o aceno com as duas mãos do sabor). Som de cortina antes (style guide §11).
- **Leitura:** silhueta lisa contra a janela acesa, lida a 40–80 studs. Sem olhos, sem rosto.
- **Tris:** ≤ 150.

### AST-064 — ANM-007 The Walker

- **Status:** Rascunho · **Prioridade:** P1 · **Origem:** Plataforma (R6 escalado ~1,4×) + Modelar
- **Visual:** figura alta e escura: sobretudo longo e chapéu `#14162A`, rosto na sombra da aba (decal escuro liso), mãos nos bolsos. Silhueta reconhecível sob o **último poste da Juniper a ~135 studs** da janela (rodada 17: postes a cada 8 studs, último a ~135; exceção anotada no style guide §5.3, que antes dizia ~110). O conflito LD-15 (JL-09 a ~165) fica resolvido pela rodada 17.
- **Leitura a ~135 (sem brilho no personagem):**
  - Escala **~1,4×** o R6 (~7 de altura): a cabeça fica perto da cúpula do poste, o que já é a estranheza.
  - Silhueta em "trapézio alto": chapéu de aba larga (Ø ~2,2) + sobretudo que **abre em saia** até o tornozelo (base ~2,6 de largura); sem braços soltos (mãos nos bolsos). Lê como forma única, não como pessoa normal.
  - Contraste por fundo: ele fica **dentro da poça** (luz real ou `Pool_Decal` Cream do AST-036), escuro sobre chão claro. Cor `#14162A` fosca, sem reflexo.
  - Nada fino: sem bengala, cachecol solto ou franja que vira ruído na névoa.
  - LOD: a partir de ~60 studs, versão ≤ 400 tris com a mesma silhueta.
  - Teste do style guide §5.3 (celular, noite 10, ≤ 2 s) antes de `Pronto p/ import`.
- **Comportamento visual:** parado sob o poste (`Walker_Spot` de AST-036); cada avanço = o poste onde estava pisca e ele aparece no próximo (sem ciclo de andar). Recua para o escuro e some.
- **Regra:** não olha nem aponta para o jogador; nada de olhos brilhando, garras ou boca. O medo é a regra, não a forma.
- **Tris:** ≤ 1.500.
- **DEC-212 (2026-10-10, fecha a parte do Walker em `Q-160`):** Walker no **rig da crew** (DEC-178) com **silhueta própria**, que **não lembra nenhuma das 18 espécies** (opção do narrative-writer; o "Leão" proposto não entra). **Art-director propõe** cabeça/orelhas, textura e escala (ponto de partida: orelhas pequenas caídas, pelagem escura lisa); ficha vai a Aprovado com DEC do usuário. "R6 escalado ~1,4×" e o rosto escuro liso seguem, sem confundir com o "sem rosto" da ANM-001 (`Q-147`). Tris do rig animal (DEC-164) substituem o "≤ 1.500"; LOD ≤ 400 segue.

### AST-065 — ANM-008 The long car

- **Status:** Aprovado (DEC-139) · **Prioridade:** P1 · **Origem:** Pack + edição — `CK/sedan.fbx` esticado (mesma base do `Car_Sedan` de AST-035), rodas centralizadas e proporcionais pelo usuário. ~~**Pendente (modeler-3d):** recolor preto; tris ≤ 2.000~~ (feito, DEC-141). **Modelo aprovado DEC-141.**
- **Modelo (DEC-141):** `Assets/blender/anomaly/AST-065_LongCar.blend`, `Assets/models/anomaly/AST-065_LongCar.fbx`; 1.360 tris; 19,5 × 7,1 × 4,0; preto; **4 rodas**.
- **Rodas — decidido (DEC-144, fecha `Q-139` b):** **4 rodas**, como no modelo aprovado.
- **Dimensões (DEC-139, ajuste do usuário no Studio):** **19,5 C × 7,1 L × 4,0 A** (≈ 1,6× o sedã; era ~22 × 6 × 4,5, 1,8×).
- **Visual:** carro preto `#14162A` **comprido demais** (medidas acima), vidros embaçados (translúcido escuro), sem motorista visível, motor com zumbido grave. Farol alto branco frio `#F4F7FF` direto no trailer.
- **Proibido:** forma de carro funerário ou limusine de marca real; ninguém sai, nada é disparado (DEC-023).
- **Peças:** `Body`, `Wheel_*` (4 rodas, DEC-144; o "comprido demais" vem das medidas), `Headlights` (Neon), `Light_HighL/R` (SpotLight real, sem sombra, alcance ~30).
- **Estados:** `Arrive`, `Parked`, `HighBeam`, `Blink2x` (fim da janela), `Leave`. **Tris:** ≤ 2.500.

### AST-066 — ANM-009 The knock (porta dos fundos do trailer)

- **Status:** Rascunho · **Prioridade:** P1 · **Origem:** Modelar (peça do AST-027)
- **Nota (DEC-141):** a porta já está modelada **dentro** de `Assets/models/vehicle/AST-027_OpenLateTrailer.fbx` (trailer aprovado). A ficha AST-066 **não** foi aprovada por tabela: segue Rascunho até decisão própria.
- **Peças:** `Door_Back` com janelinha (âncora AN-05), pivô na dobradiça; estado `Ajar` (abre um dedo, ~10°) para o sabor; **sem prompt** (DEC-054). Porta-guardanapos no balcão com guardanapos que voam (VFX).
- **Áudio:** 3 batidas, pausa, 3 batidas; legenda "???" (FEAT-018).
- **Tris:** porta ≤ 300.

### AST-067 — ANM-010 The Hush (névoa + marcação do ponto seguro)

- **Status:** Rascunho · **Prioridade:** P1 · **Origem:** Modelar + VFX
- **Peças:** camada de névoa baixa (textura de partícula 256² suave, style guide §10); marcação `SafeZone_Marking` está no AST-028 (o letreiro coral nunca apaga); postes apagando = estado `Off_Hush` do AST-036.
- **Leitura:** do trailer, o jogador vê as poças de luz sumindo uma a uma na Juniper; o neon coral do Mart fica como única cor quente diferente no fim da Ninth.
- **Tris:** — (VFX).

---

## História (`story`)

### AST-037 — Panfleto (HELP WANTED / NIGHT SHIFT)

- **Status:** Aprovado (DEC-140) · **Prioridade:** P0 · **Origem:** Modelar — `Assets/blender/story/AST-037_Flyer.blend`, `Assets/models/story/AST-037_Flyer.fbx`; `Flyer_Old` 132 / `Flyer_NightShift` 144 tris
- **Uso:** cutscene de abertura (DEC-021): close no panfleto velho no poste P-01. Pós-créditos (DEC-075): panfleto novo e limpo.
- **Dimensões:** 1,4 L × 2,0 A, papel ondulado, fita nos cantos; 8 tiras destacáveis, **uma faltando**.
- **Textura (512², texto de `script.md` §1):** "HELP WANTED! / Run a hot dog cart. / No experience needed. Must notice things. / Call Bramble's Corner Dogs — 555-0179"; desenho simples de hot dog; o logo da salsicha sorridente.
- **Variações:** `Flyer_Old` (amarelado, bordas gastas, dia 1) e `Flyer_NightShift` ("NIGHT SHIFT — NOW HIRING / Must notice things. / Call 555-0179", limpo, `ending.md` §2.4). Também alvo de AN-03 (panfleto diferente) se alguma ficha usar.
- **Encaixes:** pivô topo-centro (encaixa em `Att_Flyer`). **Tris:** ≤ 150.

### AST-038 — Celular flip (só cutscene de abertura)

- **Status:** Aprovado (DEC-140) · **Prioridade:** P1 · **Origem:** Modelar — `Assets/blender/story/AST-038_FlipPhone.blend`, `Assets/models/story/AST-038_FlipPhone.fbx`; 266 tris
- **Uso:** **só** na cutscene de abertura (**DEC-124**): "o avatar tira o celular e liga" (`script.md` §1, planos 6–7). Na cutscene compartilhada (DEC-088) os colegas veem o celular na mão do avatar; no POV de quem liga, close do celular. **Quem liga** (um avatar ou todos) segue `Q-106` c: a ficha serve aos dois casos (uma instância por avatar que liga). **Não** é usado nas ligações da run (AST-042, DEC-124).
- **Sem braços (DEC-097):** em 1ª pessoa só a Tool aparece. Abrir e discar é **animação da própria Tool** (`Closed` → `Open`, tela acende), sem mão; para os colegas, o avatar R6 usa a pose padrão de segurar Tool. Se o narrative-writer trocar o gesto por balão de fala (`consistency-report.md` NW-12), a ficha não muda.
- **Dimensões:** 0,3 × 0,15 × 0,55 fechado; aberto 1,0 de altura (2× o real, legível em close).
- **Silhueta:** flip phone arredondado e antiquado (combina com "desempregado sem dinheiro"), antena curta.
- **Cores:** Teal com teclas Cream; tela `#9FD3E8` Neon fraco ao discar.
- **Estados:** `Closed`, `Open`. **Encaixes:** `Handle`/`Att_Hand` (prende no `RightGripAttachment` do R6), `Att_Ear`.
- **Tris:** ≤ 300.

### AST-068 — Pistas do trailer: foto de 1979 + crachá

- **Status:** Aprovado (DEC-140) · **Prioridade:** P1 · **Origem:** Modelar — `Assets/blender/story/AST-068_TrailerClues.blend`, `Assets/models/story/AST-068_TrailerClues.fbx`; `Photo_1979` 66 / `Badge_Old` 76 tris
- **Uso:** trilha de pistas (`ending.md` §3, Aprovado): foto presa no quebra-sol do trailer (Walt jovem na frente do trailer; ao fundo, borrada, uma capa amarela) e crachá velho "WALT — NIGHT SHIFT" na gaveta (AST-020).
- **Peças:** `Photo_1979` (0,6 × 0,4, textura 256² em tons sépia desenhados, nada de foto real), `Badge_Old` (0,5 × 0,3, metal Steel gasto, texto em decal).
- **Leitura:** a capa amarela da foto usa o amarelo reservado (é pista da Raincoat Lady). **Tris:** ≤ 100 cada.

### AST-075 — Props da cutscene de abertura

- **Status:** Rascunho · **Prioridade:** P2 · **Origem:** Modelar
- **Peças:** carteira vazia que abre (0,5 × 0,35; Tool, abre por animação da própria Tool, sem mão — DEC-097; se o narrative-writer trocar o gesto por balão de fala, NW-12, a carteira pode sair) com uma **mariposa** que sai voando (piada de `characters.md` CHR-002); jornal de vagas amassado; bando de 5 pombos com ciclo de bicar e voar (`world.md` §2). Placas "NO HELP WANTED" ficam no AST-033 (`Facade_Shopfront`).
- **Tris:** carteira ≤ 150; mariposa ≤ 50; pombo ≤ 200.

---

## VFX e UI (`vfx`, `ui`)

### AST-070 — VFX pastelão: atropelamento, desmaio, embarque, reviver

- **Status:** Rascunho · **Prioridade:** P1 · **Origem:** Modelar (texturas de partícula)
- **Texturas (128², no estilo chapado):** estrelinha Mustard, anel de impacto cartunizado, nuvem de poeira, "Zzz", gota azul clara, guardanapo, fumaça cinza clara, ondinha de som 2D, brilho Gold.
- **Efeitos:** os da tabela do style guide §10 (atropelamento, item derrubado, desmaio, ambulância, reviver, ANM-002/005/009/010).
- **Proibido:** sangue, caveira, "X" nos olhos, fogo em pessoa.

### AST-071 — Folha de ícones de UI (ingredientes, Tools, HUD)

- **Status:** **Aprovado (DEC-217)** — **54 ícones** do complemento "Lista de ícones" (vale o complemento onde divergir) · **Prioridade:** P0 · **Origem:** render dos modelos 3D + 2D
- **Conteúdo:** ícones de pão, salsicha e dos 6 complementos (balão de pedido e hotbar); Tools (hot dog, 9 pacotes, café, item raro); upgrades para as vagas da bancada (Grill, Cooler, Counter, Lock, Trailer Lights); HUD (moeda, sol, lua, telefone, ambulância, votos de "Skip"); reações do cliente (estrela, nuvem rabiscada, vapor); gema.
- **Formato:** 128² cada, folha 1024² com `ImageRectOffset`; contorno grosso; mesma paleta.
- **Folha (modeler-3d, 2026-10-10, Em revisão; não enviada):** `Assets/textures/ui/AST-071_icons.png` (1024², 8 × 8 células de 128², 54 usadas, 10 livres) + `Assets/textures/ui/AST-071_icons.json` (nome → `ImageRectOffset`/`ImageRectSize`, grupo, ID de conteúdo, modelo de origem, flag `placeholder`). Nomes = chaves do `src/Shared/Content`: `Ingredient/<Ingredients.Key>`, `Item/<Items.Key>` (`hot_dog`, `pack_*`, `coffee`, `revive_kit`), `Upgrade/<Upgrades.Key>/<nível>` (grill, cooler, counter 1–3), `Upgrade/cash_drawer_lock`, `Upgrade/trailer_lights`, `Upgrade/food_trailer`, `Upgrade/coffee_machine`, `Class/<Classes.Key>`, `Hud/coin|gem|sun|moon|phone|ambulance`, `Reaction/star|scribble_cloud|steam`, `Notice/lock|trailer|rare`. Revisão: `Assets/reference/AST-071_icons_contact.png` (cada ícone na pílula do HUD, em fundo claro e a 48/32 px). Asset id: upload em lote pelo usuário; `Ingredients.Icon` continua `""` até lá.
- **Como foi feito:** render EEVEE dos `.blend`/FBX do repositório (câmera ortográfica 3/4, luz Cream `#FFF1D6` + contraluz fria, view transform Standard, fundo transparente), contorno `#2B2233` de 4 px (dilatação da silhueta, com preenchimento claro sob vidro), reduzido de 512 para 128. Sem modelo: moeda, gema, sol, lua, estrela, nuvem rabiscada, vapor e brilho do "raro" desenhados em Pillow com a paleta §2.1. Avisos = disco `#2B2233` com anel Mustard. Pacotes = render do AST-011 + ícone do ingrediente no canto (selo). Pipeline para regenerar quando um modelo mudar: `tools/icons/` (`make_jobs.py` → `render_icons.py` via `bl.sh` → `build_sheet.py`).
- **Placeholders (23, marcados no JSON):** 9 pacotes (AST-011 ainda sem recolor/rótulo no modelo: a cor da tabela do AST-011 entrou só no ícone; re-renderizar quando o recolor e os rótulos do AST-072 existirem) · Counter L1–L3 (sem modelo final; composição de peças KayKit, L3 em L **sem toldo**) · 8 classes (render provisório da cabeça Day + `Normal` + boné `REF_Cap` liso, sem logo; trocar pelo retrato High do AST-086) · moeda (AST-082 sem malha; desenho com o hot dog do logo em relevo, DEC-206) · gema (cor não definida no style guide: **Teal**, Provisório) · `Notice/rare` (brilho em **Gold**, cor do AST-051; confirmar com o art-director).
- **Escolhas Provisórias (art-director confere):** ketchup e mostarda = **garrafas** AST-004/005 (lêem melhor que tigela; DEC-218 tirou as garrafas da grade, destino em `Q-172`: se virarem Obsoletas, trocar por tigela com molho); salsicha = `Sausage_Grilled`; café-ingrediente = jarra da cafeteira (AST-022), para não repetir o copo (Tool) nem o saco (pacote); pão = `Bun_Open`; Cooler L3 = FBX importado atual (verde, não o Steel + Ketchup da ficha). "Votos de Skip" do texto acima não está na lista de 54 do complemento (que vale, DEC-217) e ficou fora.

### AST-072 — Folha de placas, letreiros e logos

- **Status:** Rascunho · **Prioridade:** P0 · **Origem:** 2D (texto final do narrative-writer, DEC-022)
- **Conteúdo:** logo **salsicha sorridente** do Bramble's (original); "BRAMBLE'S CORNER DOGS"; slogan "Hot dogs on the corner since forever."; "BRAMBLE'S — OPEN LATE" (versão desbotada); "NINTH STREET MART"; "OPEN 24 HOURS" (desenho para o neon); "BELLMOOR SAVINGS"; placa da lavanderia; "NINTH AVE" / "JUNIPER ST"; "ROAD CLOSED"; "NO HELP WANTED"; "Available on Day 5"; OPEN / CLOSED; "Out of stock"; "GEAR WALL", "MAX", "Trailer only", "Nothing special today" e "Sold out" da bancada (textos finais do narrative-writer); etiquetas de preço; "BELLMOOR RESCUE", o símbolo da ambulância (coração Teal com "+") e o crachá "BR" dos médicos (AST-076); ~~pictogramas do semáforo de pedestre (AST-077, Obsoleto por DEC-130)~~; rótulos dos 9 pacotes.
- **Formato:** 256² por placa (ou folha 1024² recortada por `SurfaceGui`/`Texture`). Nenhuma marca, logotipo ou tipografia-assinatura de terceiros.
- **DEC-206 (2026-10-10):** logo do Bramble's = **o hot dog cartoon do avental** (`AST-053_CrewTex`), nos personagens e no carrinho. **Provisório:** a "salsicha sorridente" desta folha passa a ser esse mesmo desenho (marca única). Art-director confere que o desenho é original (não copiado da prancha `customrig.png`).

---

## Telefone do chefe — decidido (DEC-124, responde `Q-076`)

**Decidido:** **telefone fixo do veículo** (AST-042, variantes `Phone_Cart` e `Phone_Trailer`) para **todas** as ligações da run (dia no carrinho, noite no trailer), e o **celular flip** (AST-038) **só** na cutscene de abertura.

Histórico da recomendação da arte (motivos, mantidos como referência):
- `script.md` §1 (planos 6–7): a cutscene usa o celular do avatar — mantido.
- `script.md` §8 e `characters.md` CHR-001: "o telefone do trailer toca" (alucinação) e "telefone do trailer (som de toque próprio)" — é o AST-042 no trailer.
- `design/features.md` FEAT-018 e FEAT-016: "telefone do veículo toca (som + luz); qualquer jogador atende com 'Answer'", viva-voz para a party, e "telefone fixo" no trailer — é o AST-042.
- DEC-097 (sem braços): um celular na mão em 1ª pessoa durante o trabalho exigiria segurar uma Tool e trocaria o item da mão; o telefone no mundo usa o prompt (DEC-015, DEC-066) e não ocupa a hotbar.
- DEC-076/DEC-077: o telefone no veículo não tem histórico nem "rediscar": não existe lugar para "ouvir de novo".
- A variante A2 do final (telefone do trailer ao amanhecer) não vale (DEC-075); o final é Walt em pessoa — nenhum asset de telefone extra.

Pendência para o narrative-writer: `script.md` §3 (tutorial) e §4 falam em "legenda"; só confirmar que a ligação começa com o toque do AST-042 e o prompt "Answer" (`Q-113` a).

---

## Levantamento pós-onda 1 (2026-10-10)

Autor: art-director. Base: `features.md` (FEAT-001 a 036), `story/` (anomalies Aprovado, script, ending, world, characters), `MAP-01.md`, `decisions.md` até a **DEC-215**, `tasks/board.md` ("Ondas seguintes") e `tools/assetplace/MAP-01_placements.luau` (lista de peças sem asset).
Tudo nesta seção é **Rascunho**. Nada vai à fila do `modeler-3d` sem DEC do usuário (regra do topo).

**Ondas** = as do `tasks/board.md` (task-planner, sobre a arquitetura do architect; `architecture.md` cita onda 2 = trailer e noite):
- **Onda 2 — Noite e meta:** sanidade e faixa visual, escuro e `LightZone`, interruptor e lâmpada básica, café, compra e troca do trailer, ligações do chefe, ladrão, humor, passantes, **lobby com plataformas e party**, gemas.
- **Onda 3 — Anomalias e rua:** ANM-001 a ANM-010, alucinações de anomalia, trânsito com PARE, atropelamento, item no chão.
- **Onda 4 — Queda e monetização:** desmaio, ambulância e médicos, reviver, spectate, Revive Kit, Robux, cutscenes de intro e final.
Diferença para a sugestão padrão (lobby na onda 4): o board põe **lobby e party na onda 2**; segui o board.

**Dono:** `modeler-3d` (malha, textura, render, rig) · **VFX em código** (`frontend-coder`: emissores, `Beam`, pós-processo; a textura da partícula vem do modeler-3d) · **UI** (`frontend-coder` monta em Vide; desenho e folha 2D pelo art-director/modeler-3d).

**Fonte, em ordem de preferência:** pack já no repositório (KP, FP, CK, CR, CC, CS, MM) → peça já modelada do projeto → modelar no estilo. Nenhum asset de terceiros novo é pedido nesta rodada; se algum entrar, a licença vai para `credits.md` **antes** do arquivo.

### Fichas novas

#### AST-078 — Balcão externo do trailer (Counter no trailer, 3 níveis)

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 · **Dono:** modeler-3d · **Origem:** Pack + edição — tampo `KP/kitchencounter_straight_B.fbx` (mesmo do interior do AST-027), escoras e dobradiça modeladas; banquetas `KP/chair_stool.fbx` com assento plano (DEC-138); toldo `CC/detail-awning.fbx` recolor Ketchup Faded/Cream; pedestais e marcas = `AST-019_QueuePost` / `_QueueMark` (já aprovados, DEC-141).
- **Por que ficha nova:** os níveis do AST-019 são do carrinho (L3 em L com toldo próprio). O trailer começa no **nível 1** com peças próprias (**DEC-184**) e o balcão dele é a prateleira dobrável **externa** sob a janela de serviço, X 48–54 (MAP-01 §7.2).
- **Níveis:** `TrailerCounter_L1` prateleira curta 3 L com 2 escoras · `_L2` prateleira 6 L + 2 banquetas · `_L3` prateleira 6 L + toldo extra + pedestais com corda até Q5.
- **Dimensões:** prateleira 1,2 de profundidade, topo **no peitoril** da janela (3,5 do piso interno; conferir com o level-designer a altura de `Att_Serve` em relação ao cliente na calçada).
- **Cores:** Steel com friso Ketchup Faded; toldo Ketchup Faded/Cream (mesma marca desbotada do trailer).
- **Encaixes:** `Att_Serve`, `Queue1`…`Queue5`, `VFX_Upgrade`. **Pivô:** base-centro, rente à parede do trailer.
- **Tris:** 300–900 por nível (§9.1 "peça visível de upgrade", teto 800 sem as banquetas).

#### AST-079 — Lâmpada básica do trailer (luminária de fábrica, DEC-189)

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 · **Dono:** modeler-3d · **Origem:** Modelar (nenhum pack tem luminária de teto).
- **Uso:** luz de fábrica do trailer (**DEC-189**), ligada ao interruptor AST-039; é o volume LZ-3 do interior. Pisca e apaga na noite perdida (FEAT-026), apaga 3 s no sabor da ANM-008 (DEC-195), fica apagada no Hush (FEAT-020).
- **Dimensões:** plafon oval 1,6 × 0,8 × 0,4, no teto, sobre o corredor; encaixa no `Light_Interior` do AST-027.
- **Silhueta:** luminária antiga de grade grossa (barras ≥ 0,2) com a lâmpada `Neon` visível por baixo; lê "lâmpada velha de trailer" no escuro.
- **Cores:** Steel; difusor Cream translúcido (0,4); lâmpada Neon `#FFE7C2`.
- **Estados:** `On`, `Off`, `Flicker` (script). **Encaixes:** `Light_Interior` (SpotLight com sombra, a única com sombra do trailer, §5.1).
- **Tris:** ≤ 300.

#### AST-080 — Ambientação do interior do trailer

- **Status:** Rascunho · **Prioridade:** P2 · **Onda:** 2 · **Dono:** modeler-3d · **Origem:** Pack direto — `KP/shelf_papertowel_decorated.fbx`, `KP/papertowel.fbx`, `KP/towelrail.fbx`, `KP/jar_A_small.fbx`, `KP/jar_C_small.fbx`, `KP/dishrack.fbx`; pacotes AST-011 (Coffee, Buns) instanciados como estoque de reserva visual.
- **Uso:** só cenário, para o interior não parecer vazio à noite. Sem prompt, colisão desligada.
- **Regras:** decorativo Sat ~55%; nada em cinza-azulado (ANM-002); **nenhuma pista nova** (as pistas são só AST-068 e `ending.md` §3); nada encostado nas estações nem nos 4 pontos "Hide" (AST-041).
- **Tris:** ≤ 1.500 somado (instâncias da mesma malha).

#### AST-081 — Kit de acessórios de cliente (DEC-188)

- **Status:** **Aprovado (DEC-217)** · **Prioridade:** P0 (pendência da onda 1: TASK-006 importa "acessórios de cliente que existirem" e não existe nenhum) · **Onda:** 2 · **Dono:** modeler-3d · **Origem:** Modelar no estilo (nenhum pack tem acessório de personagem; `MM/character-employee` fora, DEC-089). UV no atlas KitchenPack, como orelhas e caudas, para herdar `T_Atlas_Kitchen_Mid/Night` (DEC-154, DEC-166).
- **Uso:** tipo de cliente = espécie fixa + acessório, roupa civil sorteada (**DEC-188**; `content-data.md` `CustomerTypes.Accessories`). Substitui a lista de acessórios do AST-054 (que era para corpo humano R6).

  | Peça | Tipo (NPC) | Attachment | Medida | Tris |
  |---|---|---|---|---|
  | `Acc_Badge` | crachá de escritório no peito **esquerdo** (NPC-001) | `BodyFrontAttachment` | cartão 0,5 × 0,7 | ≤ 80 |
  | `Acc_Briefcase` | pasta na mão **direita** (NPC-001; Pickett, AST-055) | `RightGripAttachment` | 1,2 × 0,9 × 0,3 | ≤ 250 |
  | `Acc_Backpack` | mochila (NPC-002) | `BodyBackAttachment` | 1,4 × 1,6 × 0,7 | ≤ 400 |
  | `Acc_Headphones` | fone de arco (NPC-003) | `HatAttachment` + offset por espécie | arco sobre a cabeça, conchas de 0,5 | ≤ 250 |
  | `Acc_HardHat` | capacete com furo de orelha, como `AST-053_CrewCap_EarsUp` (NPC-004) | `HatAttachment` | aba 0,3 | ≤ 300 |
  | `Acc_SafetyVest` | colete por cima da roupa (NPC-004) | `BodyFrontAttachment` | casca do tronco +0,05 | ≤ 300 |
  | `Acc_Cane` | bengala na mão **direita** (NPC-005) | `RightGripAttachment` | 2,6 A | ≤ 150 |
  | `Acc_NightBadge` | crachá de plantão grande, Teal, peito **direito** (NPC-006) | `BodyFrontAttachment` | 0,7 × 0,9 | ≤ 120 |

- **Leitura:** cada peça reconhecível pela silhueta a 10 studs; todo acessório de lado fixo marca a assimetria que a ANM-004 inverte (AST-062).
- **Cores:** Sat ~55%; capacete Mustard (detalhe de cabeça é permitido, §2.4); colete laranja suave com faixas Cream, **nunca** o amarelo `#F2C230` da Raincoat Lady; nada `#14162A`.
- **Encaixe por espécie:** tabela de offsets `Assets/blender/character/AST-081_offsets.json` (capacete e fone mudam com a cabeça de cada espécie de cliente; espécies jogáveis como cliente seguem `Q-165`).
- **Variantes:** versão do lado oposto para a cópia (ANM-004) = troca de attachment; malha espelhada só onde a peça é assimétrica.
- **Tris:** por peça na tabela; personagem montado segue DEC-164 (≈ 2,0–2,5k).
- **Modelo (modeler-3d, 2026-10-10) — Em revisão:** uma malha por peça, modelada no lugar da pose de repouso do kit (como `Ears_`/`Cap`), cor só do atlas KitchenPack (Day = textura importada → `DayTextureID`; Mid/Night = `CrewLooks.Atlas`, sem textura nova). Fontes `Assets/blender/character/AST-081_<Peça>.blend`, export `Assets/models/character/` e `Assets/import/character/` com o mesmo nome. Nomes = `CustomerTypes.Accessories` (`Acc_ShiftBadge`, não `Acc_NightBadge`).

  | Malha | Tris | Âncora (`Anchor`) | Nota |
  |---|---|---|---|
  | `Acc_Badge` / `_Mirror` | 64 | Torso | cartão 0,5 × 0,7, faixa azul + foto, clipe |
  | `Acc_Briefcase` / `_Mirror` | 112 | **Right Arm** / Left Arm | 1,2 × 0,9 × 0,3, alça entra no punho |
  | `Acc_Backpack` | 272 | Torso | **1,36 × 1,42 × 0,6** (Provisório: mais baixa/rasa que 1,4 × 1,6 × 0,7 para a cauda do rato passar por trás e o topo não bater na cabeça) |
  | `Acc_Headphones` | 212 | Head | conchas Ø 0,54 coral, arco inclinado para trás (passa atrás das orelhas e dos olhos do sapo) |
  | `Acc_HardHat` | 178 | Head | Mustard, sem furo: espécies sem orelha no topo (macaco, cachorro, porco, ovelha, pinguim, tartaruga) |
  | `Acc_HardHat_EarsUp` | 205 | Head | mesmo capacete com fendas de orelha (orelhas de todas as espécies "EarsUp" passam sem tocar) |
  | `Acc_SafetyVest` | 190 | Torso | frente em 2 painéis + costas, 2 faixas Cream, alças sob a cabeça |
  | `Acc_Cane` / `_Mirror` | 116 | **Right Arm** / Left Arm | altura 2,38, gancho sai pela frente do punho, ponteira escura |
  | `Acc_ShiftBadge` / `_Mirror` | 98 | Torso | Teal 0,7 × 0,9 com faixa e foto Cream, cordão até o pescoço |

  Encaixe nas 18 cabeças: `Assets/blender/character/AST-081_offsets.json` (medido por sobreposição de malha com cada kit). Fone: sem ajuste em 13 espécies; escala X 1,2–1,36 em cachorro, porco, ovelha, macaco (orelhas laterais); leão 1,5 (juba, não recomendado). Capacete: ok em 16; sapo precisa subir 0,34 (calombos dos olhos) e leão não serve (juba). Mochila: cauda curta fica coberta; caudas longas (gato, raposa, macaco, leão, guaxinim, coruja) atravessam e tartaruga tem casco — só hamster/rato (DEC-188) estão limpos. Renders: `Assets/reference/AST-081_*.png` (Day/Mid/Night, costas, perfil, capacete e fone em 12 espécies, espelhadas). **Provisório:** (1) `Anchor` não vai no FBX: o kit (`build_kits.luau`) tem que gravar `Anchor = "Right Arm"` na pasta e na bengala (pelo centro da bbox o mais perto é a perna) e o `CrewRig` ainda não aplica offset/escala por espécie (o JSON fica pronto para isso); (2) capacete em duas malhas, como `Cap`/`CapEarsUp`; (3) no pacote Night o atlas compartilhado deixa capacete, colete e crachá azul-escuros (mesma regra das orelhas, DEC-154); (4) cores sem número na ficha: pasta marrom com fechos Mustard escuro, mochila azul, fone coral com arco escuro, bengala de madeira.

#### AST-082 — Moeda (pagamento, gorjeta, `Coin_Blank`)

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 · **Dono:** modeler-3d (malha) + VFX em código (tween/emissão) · **Origem:** Modelar (nenhum pack tem moeda solta).
- **Uso:** VFX de pagamento (4 moedas saltam até a gaveta, §10), gorjeta (+1 moeda com brilho), `Coin_Blank` da ANM-001 (moeda sem desenho, DEC-195), base do ícone de moeda (AST-071).
- **Dimensões:** 0,4 Ø × 0,08, borda grossa chanfrada.
- **Peças:** `Coin` (face com o contorno do hot dog do logo em **relevo raso**, DEC-206) · `Coin_Blank` (mesma borda, face **lisa**).
- **Cores:** Mustard, borda Cream. Gorjeta: mesmo Mustard + brilho; **não usar Gold** (Gold é exclusivo do AST-051, §2.1; o "moeda dourada" do §10 fica lido como Mustard brilhante).
- **Encaixes:** pivô no centro. **Tris:** ≤ 80 cada.

#### AST-083 — Kit de luz de rua: poça, cone e arandela

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 · **Dono:** modeler-3d (arandela + texturas) + VFX em código (`Beam`, decal) · **Origem:** Modelar + 2D.
- **Uso:** escuro e zonas de luz (FEAT-020). Lâmpada `Neon` + **poça falsa** nos postes sem luz real (`On_Fake` do AST-036, §5.3); cone curto dos faróis (AST-035) e farol alto frio (AST-065); marcos de luz fora da Juniper.
- **Peças:** `T_LightPool` 256² (disco Cream de borda suave, alpha), `T_LightCone` 128 × 256 (gradiente para `Beam`), `Wall_Sconce` (arandela de fachada 0,6 × 0,8 × 0,5 com Neon pequena) para portas D1, SP-B e entrada do banco.
- **Regras:** **sem luz real** nas arandelas (§5.1); nenhuma arandela na Juniper (a fila de lâmpadas é do Walker, ANM-007); nenhuma luz coral (exclusiva do Mart, §2.4); nada na rota Pad ↔ Mart vira volume de luz (**DEC-196**).
- **Lanterna de mão:** fora do MVP (DEC-055). Não entra.
- **Tris:** arandela ≤ 150; texturas sem malha.

#### AST-084 — Pós-processo: dia, noite, escuro e sanidade

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 · **Dono:** VFX em código (frontend-coder; valores do art-director) + modeler-3d (1 textura `T_Vignette` 512²) · **Origem:** código + 2D.
- **Base:** presets do style guide §5.2 (dia, hora dourada) e §5.3 (Noite 1 → Noite 10 interpolada; amanhecer de 6 s). Camada por jogador, **só no client dele** (DEC-038):

  | Estado | Efeito |
  |---|---|
  | No escuro (> 3 s fora de `LightZone`) | vinheta 25% entra em 1 s; Saturation −0,10 |
  | Sanidade < 60 | vinheta 20% |
  | Sanidade < 40 | vinheta 35%; Saturation −0,15; Tint mais frio |
  | Sanidade < 25 | vinheta pulsando devagar (0,5 Hz); `Blur` ≤ 4 por ≤ 0,5 s, raro |
  | Desmaio | bordas escurecem + `Blur` 4 em 1,5 s → tela escura (`script.md` §9.1) |
  | Hush (ANM-010) | `Atmosphere.Density` +0,15 por ~20 s |
  | Noite perdida | fade preto 1 s (FEAT-026) |

- **Regras:** sem vermelho, sem tremor forte, sem `Blur` grande (§10); a troca de pack da skin pela faixa (DEC-167) é **instantânea, sem VFX** — esta ficha mexe só na tela do próprio jogador.
- **Tris:** —. **Textura:** 1 × 512².

#### AST-085 — Alucinações de sanidade baixa

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 · **Dono:** modeler-3d (`Shadow_Card`) + VFX em código · **Origem:** Modelar + reuso.
- **Uso:** tabela do `script.md` §8 / FEAT-019, só no client, sem prompt, nunca conta como anomalia.

  | Alucinação | Asset |
  |---|---|
  | Telefone toca, legenda "Walt: ..." | AST-042 estado `Ringing` local |
  | Chiado numa grelha vazia | áudio |
  | Passos no teto, sussurro "Rookie..." | áudio |
  | Cliente na fila que some | rig de cliente (AST-053/081) no pack Night, local |
  | Poste da Juniper pisca **sem zumbido** | AST-036 `Flicker` local |
  | Letreiro do Mart pisca uma vez | AST-028 `Sign_Open24` local |
  | Sombra na janela dos fundos / vulto na periferia | **`Shadow_Card`** (novo) |

- **`Shadow_Card`:** 2 planos cruzados 2,5 × 5 com `T_ShadowFigure` 256² (alpha): silhueta lisa de **crew genérica** (cabeça redonda, orelhas pequenas redondas), cor `#2B2233`, altura normal (5). Não pode lembrar o Walker (`#14162A`, alto, chapéu: §2.4).
- **Tris:** `Shadow_Card` ≤ 40.

#### AST-086 — Retratos de faixa de sanidade (HUD)

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 · **Dono:** modeler-3d (render) → UI · **Origem:** render dos personagens AST-053.
- **Uso:** **DEC-167**: retrato do rosto da faixa ao lado do medidor de sanidade. High = pack Day + `Normal`; Mid = pack Mid + `Exhausted`; Low = pack Night + `Normal_Night`. O retrato High também serve de ícone de classe (AST-071, tela "Crew").
- **Quantidade:** 6 espécies jogáveis do MVP (Dog, Rabbit, Cat, Bear, Fox, Owl; DEC-186) × 3 = **18**; Panda e Lion (1ª atualização) +6 depois.
- **Formato:** 128² cada, folha `T_UI_Portraits` 1024²; câmera 3/4 frontal, fundo transparente, luz chapada igual para todos, contorno 4 px `#2B2233`.

#### AST-087 — Jornal de espreita do Quick Quentin

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 (ladrão) · **Dono:** modeler-3d · **Origem:** Modelar (nenhum pack tem jornal).
- **Uso:** espreita disfarçada (AST-056; clipe `Thief_Lurk` do AST-069) no banco de praça e no poste; some quando ele vai à gaveta; o saco AST-021 aparece na fuga. Também serve de "jornal de vagas amassado" da intro (AST-075, variante `Newspaper_Crumpled`).
- **Dimensões:** aberto 1,6 × 1,1, dobra central em V, papel com espessura 0,05.
- **Cores:** papel Cream; manchete e colunas por decal (AST-072; título do jornal com o narrative-writer, sem marca real).
- **Encaixes:** `Handle` no `RightGripAttachment`. **Tris:** ≤ 120 (amassado ≤ 150).

#### AST-088 — Plataforma de party do lobby (DEC-179)

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 · **Dono:** modeler-3d · **Origem:** Pack + edição — disco `KP/plate.fbx` escalado (prato gigante, tema da casa), quadro `KP/menu.fbx` (mesmo cavalete do AST-024), 4 marcas de pé = `AST-019_QueueMark`.
- **Uso:** pisar = entrar na party (**DEC-179**); 1–4 jogadores (DEC-012); contagem e "Start" (FEAT-001). Número de plataformas e posição: documento do lobby (`Q-085`, level-designer).
- **Dimensões:** disco Ø 12 × 0,6; quadro 2 × 4; marcas Ø 2.
- **Cores:** disco Cream com borda Ketchup; marcas Mustard → Neon Mustard quando ocupadas; anel Neon Teal na contagem.
- **Estados:** `Empty`, `Partial` (n/4), `Countdown` (anel gira), `Launching` (poof).
- **Encaixes:** `Slot_1`…`Slot_4`, `Board_Anchor` (`SurfaceGui` com nomes e contagem), `Zone_Party`, `VFX_Launch`.
- **Tris:** ≤ 1.200 montado.

#### AST-089 — Cenário do lobby (kit modular)

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 · **Dono:** modeler-3d (montagem, com o level-designer) · **Origem:** Pack + peças já aprovadas — rua e calçada AST-032, fachadas e `BG_Card` AST-033, mobiliário AST-034, postes AST-036, carrinho AST-026 como peça de vitrine (só a casca), quiosque `KP/kitchencounter_straight_A.fbx` + `CC/detail-awning.fbx`.
- **Proposta (Provisória):** praça de Bellmoor **de manhã**, sempre dia, tom da intro (DEC-008: nada de horror no lobby). Área das plataformas sob um arco com "BRAMBLE'S CREW" (decal AST-072); quiosque "Crew" ao lado da vitrine de classes (AST-090).
- **Peças novas:** `Lobby_Floor` (piso de praça 8 × 8, Cream, ≤ 50 tris), `Lobby_Arch` (arco 16 L × 10 A, Ketchup/Cream, ≤ 600 tris).
- **Orçamento da cena:** ≤ 120 mil tris; ≤ 80 malhas únicas; luzes 0–2 (dia).
- **Depende de:** `MAP-00` / `Q-085` (layout do level-designer).

#### AST-090 — Vitrine de classes "Crew" (lobby)

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 · **Dono:** modeler-3d · **Origem:** Pack + edição — pedestal de `KP/pillar_B.fbx` cortado (base redonda 3 Ø × 1); cadeado `AST-020_Padlock` reaproveitado (DEC-155); placa por `SurfaceGui`.
- **Uso:** escolher a classe na tela "Crew" (DEC-186): 8 pedestais (6 MVP + Panda e Lion "coming soon"), cada um com o animal no uniforme da crew (AST-053), clipe `Lobby_ShowIdle`. **Guaxinim nunca** (DEC-186).
- **Estados:** `Unlocked`, `Locked` (cadeado Mustard no pedestal + preço em gemas), `Selected` (anel Neon Mustard).
- **Encaixes:** `Att_Character`, `Label_Anchor`, `Prompt_Choose`. **Tris:** pedestal ≤ 300; personagem DEC-164.

#### AST-091 — UI kit (painéis, botões, cartões, barras)

- **Status:** **Aprovado (DEC-217)** · **Prioridade:** P0 · **Onda:** 2 (a onda 1 já usa `ProgressBar`, `PromptBillboard`, `Toast` da TASK-013 sem folha própria) · **Dono:** UI (frontend-coder monta em Vide) + art-director (desenho) · **Origem:** 2D.
- **Folha:** `T_UI_Kit` 1024², peças em 9-slice:
  - Pílula de HUD (raio 50%, `#2B2233` a 70%, texto branco com contorno 2 px) — dinheiro, dia/noite, horário.
  - Cartão Cream `#FFF1D6` com sombra curta — resumo do turno, oferta de reviver, fim de run, tela "Crew".
  - Botões: primário Mustard (texto `#2B2233`), secundário Cream, desabilitado `#8A8FA3`, pressionado escala 0,95. **Sem vermelho.** Botão de Robux: pílula Teal com o **ícone oficial da plataforma** (não redesenhar).
  - Barra de sanidade: trilho `#2B2233`, preenchimento `#FFD45A` → `#6A5ACD` (§7.2), retrato AST-086 à esquerda.
  - Barras no mundo: `CookInterface` (laranja → verde) e barra do ladrão `#6A5ACD` (§7.3).
  - Anéis: paciência do balão e contagem de 10 s (Mustard).
  - Balão de pedido (com rabicho) e balão de fala menor.
  - Selo de nota A–D (cores §7.4).
  - Toast (topo direito), "Skip (1/2)", setas de spectate, rótulo "Watching".
  - Cartão de classe (retrato, nome, bônus, contrapeso, preço em gemas, cadeado).
- **Fontes:** Fredoka One (títulos, números) e Builder Sans Bold (§7.1). Alvo de toque ≥ 44 px; texto ≥ 3,5% da altura da tela.
- **Proibido:** vermelho de alerta, caveira, coração de vida, layout ou ícone de outro jogo.

#### AST-092 — VFX de cozinha e loja

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 2 · **Dono:** modeler-3d (folha `T_VFX_Kitchen` 512², células 128² e flipbook 4 × 4) + VFX em código · **Origem:** 2D + código.
- **Efeitos (style guide §10):**

  | Efeito | Visual | Orçamento |
  |---|---|---|
  | Fumaça da grelha | fiapo cinza-claro quente, sobe e some | Rate 3 por vaga ocupada, Lifetime 1,2 s; desliga em qualidade baixa |
  | Vapor | 2 fiapos brancos na salsicha pronta e no café (AST-010/022) | Rate 1 |
  | Brilho de pronto (`ReadyVFX`) | 10 estrelinhas Mustard/branco + sino | `Emit(10)` |
  | Pagamento | 4 moedas AST-082 em tween até a gaveta + "+$7" subindo | `Emit(4)` |
  | Gorjeta | +1 moeda Mustard com brilho (não Gold) | `Emit(1)` |
  | Molho | 6 gotinhas da cor do molho | `Emit(6)` |
  | Restock | lufada de poeira clara | `Emit(5)` |
  | Upgrade instalado | confete 14 peças + pop de escala 0,9 → 1,05 → 1 | `Emit(14)` |
  | "Nice catch!" | poeira na fuga do Quentin | `Emit(6)` |

- **Texturas:** estrela, fiapo (flipbook), gota, poeira, confete (4 formas), brilho.
- **Teto:** ≤ 150 partículas na tela, ≤ 8 emissores perto da câmera (§9.2).

#### AST-093 — Placa PARE e linha de parada (Juniper Norte e Sul)

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 3 · **Dono:** modeler-3d · **Origem:** Pack + edição — `CR/road-sign-stop.fbx` (antes fora do sourcing por falta de ficha); linha de parada = peça `Stop_Line` do AST-032.
- **Uso:** **DEC-133**: braços da Juniper com PARE (PARE-N, PARE-S; MAP-01 §5.4 e P38). O carro para 1 s na linha.
- **Dimensões:** placa octogonal Ø 2,0 no topo de poste de 7 A (poste `#4B4F63`, família do AST-036).
- **Cores:** placa Ketchup, borda e texto Cream; texto "STOP" por decal (AST-072, inglês, DEC-022), sem texto modelado. Octógono é convenção genérica; nenhuma placa de país ou marca específica.
- **Encaixes:** `Stop_Line_Anchor`. **Tris:** ≤ 300.

#### AST-094 — Porta-guardanapos do trailer (ANM-009)

- **Status:** Rascunho · **Prioridade:** P2 · **Onda:** 3 · **Dono:** modeler-3d · **Origem:** Modelar (volume de referência `KP/papertowel.fbx`).
- **Uso:** no balcão do trailer, perto da janela; sabor da ANM-009 (guardanapos voam para dentro; entra pela DEC-195). De resto, cenário.
- **Dimensões:** 0,8 × 0,5 × 0,7; pilha de guardanapos como peça `Fill`.
- **Cores:** Steel; guardanapos Cream.
- **Encaixes:** `VFX_Napkins`. **Tris:** ≤ 200.

#### AST-095 — VFX de anomalias

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 3 · **Dono:** modeler-3d (folha `T_VFX_Anomaly` 512²) + VFX em código · **Origem:** 2D + código.
- **Por anomalia** (só efeitos que entram pela **DEC-195**; "chuva no trailer" e "pedidos esfriam" dependem da classificação do game-designer):

  | ANM | Efeito | Textura / peça |
  |---|---|---|
  | 001 | balão vazio (UI) + `Coin_Blank` | AST-082 |
  | 002 | puff curto ao surgir no trilho; fumaça cinza-clara quando o cliente morde (`Emit(8)`, 0,8 s) | fiapo do AST-092 tingido |
  | 003 | nenhum VFX: ponteiros param por script (AST-044), tique-taque some (áudio) | — |
  | 004 | nenhum VFX: sorriso parado (expressão) e andar de costas (clipe) | — |
  | 005 | pingos azul-claros (Rate 4) + poça que cresce até Ø 2,5; poof de gotas no final; chuva 14 × 16 por 20 s sobre o trailer se classificada | gota, `T_Puddle` 256² |
  | 006 | janela `Lit` (AST-045); +2 janelas acesas por 5 s no sabor | — |
  | 007 | poste `Flicker` a cada passo; **nada** no personagem | — |
  | 008 | farol alto: `Beam` frio (`T_LightCone`, AST-083) + SpotLight real; pisca 2× | — |
  | 009 | porta `Ajar` (AST-066) + 6 guardanapos voando (AST-094) + 3 fiapos azulados de vento | guardanapo |
  | 010 | névoa baixa (AST-067) + postes `Off_Hush` | — |

- **Regra:** nenhum VFX aponta o alvo (§4.4: "sei que tem algo errado, mas não sei o quê"). O pack Night de "clima de anomalia" (DEC-181) é troca de textura, não VFX.

#### AST-096 — Item no chão: marcador, "splat" e derramado

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 3 · **Dono:** modeler-3d (texturas) + VFX em código · **Origem:** 2D + código.
- **Uso:** FEAT-036. Pacote e Rescue Whistle no chão usam **a própria malha**; Hot Dog e café se perdem em 2 s.
- **Peças:** `T_DropRing` 256² (anel Cream com borda Mustard, decal plano sob o item, pulsa devagar; substitui o "contorno leve" sem `Highlight` permanente, §1.1) · `T_Splat_HotDog` (estrela cômica Mustard com pingos Ketchup claros, 2 s; nada vermelho-escuro, §10) · `T_Spill_Coffee` (mancha Coffee, 2 s).
- **Queda:** quique 1× (física) + mini poeira (AST-070).
- **Tris:** — (decais).

#### AST-097 — Logo do jogo "Sell Hotdogs!", ícone e thumbnails

- **Status:** Rascunho · **Prioridade:** P1 · **Onda:** 4 (lançamento) · **Dono:** art-director (direção) + modeler-3d (render das cenas) · **Origem:** 2D + render.
- **Uso:** nome oficial **DEC-170**. Logo para lobby, tela de título e créditos; ícone do jogo 512²; 3 thumbnails 1920 × 1080.
- **Conteúdo proposto:** logo tipográfico próprio, letras arredondadas grossas (sem fonte-assinatura de terceiros), com o hot dog do avental (**DEC-206**). Ícone: o cachorro da crew (CLS-001) segurando um hot dog, metade do quadro de dia e metade de noite. Thumbnails: (1) party servindo a fila de dia; (2) trailer como ilha de luz na esquina à noite, sem mostrar anomalia; (3) a crew alinhada no lobby.
- **Regras:** nada que lembre logo, mascote ou thumbnail de outro jogo ou marca; texto em inglês; classificação Mild (DEC-172).

### Complementos de fichas existentes (onda, dono, orçamento, fonte)

Só acrescenta; não muda texto aprovado. Fichas Rascunho seguem precisando de DEC para ir ao modelador.

| AST | Onda | Dono | O que falta / proposta (Provisória) | Orçamento |
|---|---|---|---|---|
| AST-012 Grill | 2 (trailer começa no L1, DEC-184) | modeler-3d | **Silhueta reescrita (DEC-201):** mesma máquina, mais rolos — L1 3 rolos (2 vagas), L2 4 (3), L3 5 (4), rolos a 0,9 entre centros; L3 ≈ 4,5 L, cabe nos 5 L do carrinho (`Q-134` c fechado do lado da arte); no trailer, a mesma máquina centrada nos 6 L. Gaveta aquecedora só cenário. Steel + painel Ketchup, sem marca | 600–1.200 por nível |
| AST-021 Saco de moedas | 2 | modeler-3d | `FP/bag.fbx` com boca **amarrada** (ajuste de malha) + 2–3 moedas AST-082 saindo + "$" por decal | ≤ 300 |
| AST-043 Lona do carrinho | 2 | modeler-3d | **DEC-199**: carrinho coberto na vaga onde estava o trailer (`TRL-SALE`). Ficha completa como está (26 × 4 × 4, Mint-gray, 3 cordas Cream, `On`/`Off`); pronta para pedir aprovação | ≤ 1.200 |
| AST-044 Bellmoor Savings | 3 (ANM-003), landmark desde já | modeler-3d | **Aprovado e não modelado**: relógio C-01 (`Clock_Face`, `Hand_Hour`, `Hand_Minute`, `Clock_Bell`), frontão, quina chanfrada, `BankSign`, `BankDoor` (lista de pendências do `MAP-01_placements.luau`) | térreo ≤ 1.500; relógio ≤ 400 |
| AST-045 Apartamentos | 3 (ANM-006) | modeler-3d | **Aprovado**; o modelo tem 22,57 de altura e o lote pede ~30 (janelas WV-1..3 a 19–28): esticar os andares ou refazer `Window_Up_<N>` na altura certa | ≤ 2.500 o prédio |
| AST-054 Clientes e pedestre | 2 | modeler-3d | Releitura para animais (DEC-149, DEC-188): espécie fixa + roupa `T_Civil_A..H` (já aprovadas) + acessórios **AST-081**. Pedestre: sem acessório (`content-data.md`) | DEC-164 |
| AST-055 Mr. Pickett (rato) | 2 (regular), espelho na 3 | modeler-3d | `T_Civil_Pickett` Day/Mid (terno marrom, bordado "PICKETT & SONS" no peito esquerdo), gravata-borboleta verde (≤ 80, `NeckAttachment`), relógio grande no pulso **esquerdo** (≤ 80), pasta `Acc_Briefcase` na **direita** | DEC-164 + 160 |
| AST-056 Quick Quentin | 2 | modeler-3d | Peças aprovadas (DEC-163); faltam jornal **AST-087** e saco **AST-021** | DEC-164 |
| AST-057 Opal (coruja) | 2 | modeler-3d | `T_Civil_Opal` Day/Mid/Night (cardigã verde + colete Sage com crachá "MART"), óculos na corrente (≤ 150), lápis preso no tufo da cabeça (≤ 60); revista = peça do AST-031 na mão | DEC-164 + 210 |
| AST-058 Walt (tartaruga) | 4 | modeler-3d | **DEC-202**: bastão de madeira na mão **esquerda** (≤ 150), barba branca low poly (≤ 300), `T_Head_Turtle_Walt` com rugas (só Day: o final é ao amanhecer), `T_Civil_Walt` (jaqueta creme e vermelha desbotada, crachá "WALT — NIGHT SHIFT"), boné vermelho = `CrewCap` + logo DEC-206, óculos grossos (≤ 120); `Coffee_Pair` na direita | ≤ 2.500 total |
| AST-059 Raincoat Lady (sapo) | 3 (final na 4) | modeler-3d | `T_Civil_Raincoat` (capa `#F2C230`, botas verdes pintadas nos pés), capuz (≤ 400, `HatAttachment`), guarda-chuva fechado (≤ 200, `RightGripAttachment`), expressão nova **`T_Expr_EyesClosed`** (só ela usa) | DEC-164 + 600 |
| AST-060 Blank folks | 3 | modeler-3d | `T_Expr_Blank` = casca do rosto **vazia** (sem olhos e sem boca). O nariz fica na `T_Head_<A>` (DEC-161): o sinal aprovado é "sem olhos, boca ou sobrancelha", então o nariz pode ficar (sem textura de cabeça nova). Sem respiração = clipe `Cust_NoBreath`. Balão vazio = UI. `Coin_Blank` = AST-082 | 0 tris; 1 textura |
| AST-062 Copies | 3 | modeler-3d | Espelho por **textura**: `T_Civil_<A..H>_Mid_Mirror` (texto invertido) + `T_Civil_Pickett_Mirror`; acessórios do AST-081 no attachment oposto. Só a variante Mid (NPC à noite = Mid, DEC-181); Night do observador com sanidade baixa usa o normal (a confirmar com `Q-147`) | 9 texturas; memória `Q-144` g |
| AST-063 Wavers | 3 | modeler-3d | `Silhouette_Card` com cabeça redonda **sem orelhas** (num mundo só de animais, a falta de orelha já estranha) + `Arm_R`/`Arm_L` girando por script | ≤ 150 |
| AST-064 Walker | 3 | modeler-3d | **Proposta da DEC-212:** cabeça própria `AST-064_WalkerHead` (oval alongada na vertical, 1,3× a cabeça da crew, **sem focinho em volume**, orelhas pequenas **caídas** sob a aba), pelagem `#14162A` lisa, textura `T_Walker` (um pack só), sobretudo em saia (≤ 500) e chapéu de aba Ø 2,2 (≤ 200), escala 1,4, mãos nos bolsos. Rosto = sombra da aba, não o "sem rosto" da ANM-001. Vai a Aprovado só com DEC | ≤ 2.500; LOD ≤ 400 |
| AST-066 Knock (porta) | 3 | modeler-3d | Porta já no `AST-027_OpenLateTrailer.fbx`: conferir pivô na dobradiça, estado `Ajar` (~10°) e janelinha AN-05; pedir aprovação da ficha | ≤ 300 |
| AST-067 Hush | 3 | modeler-3d (`T_Fog` 256²) + VFX em código | 2 emissores de névoa a 1,5 stud + `Atmosphere` (AST-084) | 0 tris |
| AST-069 Animações | 2–4 por clipe | modeler-3d (rig) + **usuário anima** | Rig IK e lista de clipes abaixo | — |
| AST-070 VFX pastelão | 3 (atropelamento) e 4 (desmaio, embarque, reviver) | modeler-3d (texturas) + VFX em código | Estrelinha, anel de impacto, poeira, "Zzz", poof; ver nota sobre ragdoll no desmaio abaixo | §10 |
| AST-071 Ícones | 2 (ingredientes já fazem falta na onda 1: plaquinhas do AST-017, `Q-152`) | modeler-3d (render) + UI | Lista completa abaixo | 1024², 64 células |
| AST-072 Placas e logos | 2–4 | art-director (2D) | Acrescentar: "STOP" (AST-093), "SIDEWALK CLOSED" / "USE OTHER SIDE" (AST-047), "BRAMBLE'S CREW" (AST-089), manchete do jornal (AST-087), crachá "MART" (Opal), "PICKETT & SONS", "WALT — NIGHT SHIFT", "BR" (médicos), logo "Sell Hotdogs!" (AST-097) | 256² por placa |
| AST-073 Avental | — | — | Coberto pela textura `AST-053_CrewTex` e por `AST-053_CrewApron.fbx` (DEC-148, DEC-151): **propor Obsoleto** por DEC | — |
| AST-074 Ônibus | 4 (intro) | modeler-3d | O Car Kit não tem ônibus; **Pack + edição**: `CK/van.fbx` alongado para 30 (mesma técnica do long car) com fileira de janelas por UV, Butter + faixa Peach. **Só na cutscene de abertura**: no trânsito, 30 studs quebraria a regra "nenhum veículo de trânsito > 16" reservada ao long car (§2.4) | ≤ 2.500 |
| AST-075 Props da intro | 4 | modeler-3d | Carteira **sai** (`script.md` §1). Ficam: mariposa (≤ 50, bater de asas por 2 frames de malha ou flipbook) e 5 pombos (≤ 200 cada; bicar e voar por clipe simples de 2 ossos, fora do R6). Jornal de vagas = `Newspaper_Crumpled` do AST-087 | ver colunas |
| AST-076 Médicos | 4 | modeler-3d | **DEC-211/213**: coelho alto (`Medic_A`) e panda baixo (`Medic_B`), `T_Civil_Medic` Mid e Night (menta `#9FD8C4`, faixa branca, crachá "BR"), rosto fixo `Exhausted`. **Máscara cirúrgica como acessório** (pedido desta rodada): `Acc_SurgicalMask_Rabbit` e `_Panda`, casca sobre o focinho com elásticos até as orelhas, branco-menta, `FaceFrontAttachment`. Boné menta: coelho = `CrewCap_EarsUp` recolor; panda = `CrewCap` recolor | máscara ≤ 150 cada; DEC-164 |

#### AST-069 — Rig IK e lista de clipes (complemento)

- **Rig:** `Assets/blender/character/AST-069_AnimRig.blend`, control rig sobre `AST-053_CrewBase` (modeler-3d monta; usuário anima). R6 não tem cotovelo nem joelho: "IK" aqui = **alvo de mão e pé que gira o membro inteiro** + controles FK de cabeça e tronco; nomes de junta iguais aos `Motor6D` do R6. Formato de exportação para o Roblox (KeyframeSequence) a definir com o architect/frontend.
- **Regra:** nenhum clipe de violência, queda dolorida ou contato entre personagens (AST-069). Prioridade de animação do Roblox entre parênteses quando importa.

| Clipe | Quem | Onda | Loop | Duração |
|---|---|---|---|---|
| `Crew_Idle` | crew (visto por colegas e cutscene) | 2 | sim | 3 s |
| `Crew_Walk` / `Crew_Run` | crew | 2 | sim | 1,0 / 0,7 s |
| `Crew_HoldItem` (Action, só braço direito) | crew | 2 | sim | pose |
| `Crew_Serve` | crew | 2 | não | 0,5 s |
| `Crew_Slice` (cortar o pão) | crew | 2 | não | 0,6 s |
| `Crew_Grill` (pôr/colher salsicha) | crew | 2 | não | 0,5 s |
| `Crew_Restock` | crew | 2 | não | 0,8 s |
| `Crew_Drink` (café, FEAT-021) | crew | 2 | não | 1,5 s |
| `Crew_Wave` (acenar) | crew | 2 | não | 1,2 s |
| `Crew_Sit` (banco AST-040, cutscene) | crew | 2 | sim | pose |
| `Lobby_ShowIdle` (pedestal) | crew | 2 | sim | 4 s |
| `Crew_Hide` (agachado atrás do balcão) | crew | 3 | sim | pose |
| `Crew_GetUp` (levantar do ragdoll do atropelamento) | crew | 3 | não | 0,8 s |
| `Crew_OnStretcher` (deitado de lado na maca) | crew | 4 | sim | pose |
| `Crew_WakeShake` (sacode a cabeça ao reviver e na noite perdida) | crew | 4 | não | 1,0 s |
| `Crew_Startle` / `Crew_Nod` / `Crew_LookUp` (intro) | crew | 4 | não | 0,5 / 0,8 / pose |
| `Cust_WaitIdle` (fase aleatória) | cliente | 2 | sim | 3 s |
| `Cust_Impatient` (bufar, bater o pé) | cliente | 2 | sim | 2 s |
| `Cust_Happy` / `Cust_Complain` | cliente | 2 | não | 1,0 s |
| `Cust_Pay` | cliente | 2 | não | 0,6 s |
| `Cust_RefusedWave` | cliente | 2 | não | 0,8 s |
| `Cust_SitDrive` (sentado: banco de praça, motorista em silhueta) | cliente | 3 | sim | pose |
| `Cust_Eat` (mordida, ANM-002) | cliente | 3 | não | 0,8 s |
| `Cust_NoBreath` (ANM-001, pose parada) | cliente | 3 | sim | pose |
| `Cust_WalkBackward` (ANM-004) | cliente | 3 | sim | 1,0 s |
| `Thief_Lurk` (jornal) / `Thief_Tiptoe` / `Thief_OpenDrawer` / `Thief_Flee` | Quentin | 2 | sim | 2–3 s |
| `Opal_Crossword` (idle) / `Opal_LookTalk` | Opal | 2 | sim / não | 4 s / 1,5 s |
| `Raincoat_Idle` / `Raincoat_Nod` | Raincoat Lady | 3 (aceno na 4) | sim / não | 3 s / 1,0 s |
| `Walker_Stand` (mãos nos bolsos) | Walker | 3 | sim | pose |
| `Medic_StepDown` / `Medic_StepUp` | médicos | 4 | não | 0,5 s |
| `Medic_CarryWalk` (dupla, maca no `RightGripAttachment`) | médicos | 4 | sim | 1,0 s |
| `Medic_LowerStretcher` / `Medic_LiftStretcher` | médicos | 4 | não | 1,0 s |
| `Medic_Idle` (calmo; panda curvado) | médicos | 4 | sim | 3 s |
| `Walt_HunchWalk` (corcunda com bastão) / `Walt_OfferCoffee` / `Walt_Nod` | Walt | 4 | sim / não / não | 1,4 / 1,5 / 0,8 s |

Fora da lista de clipes: **desmaio** = ragdoll em código + rosto `Fainted` (**DEC-216**); atropelamento = ragdoll em código (DEC-197); passo do Walker = teleporte entre postes; aceno das wavers = braço do cartão girando por script.

#### AST-071 — Lista de ícones (complemento)

Folha 1024², células 128², contorno grosso `#2B2233`; comida e equipamento = **render do modelo 3D** (§7.1).

| Grupo | Ícones | Qtd | Onda |
|---|---|---|---|
| Ingredientes | pão, salsicha, ketchup, mostarda, queijo, bacon, batata palha, cream cheese, café | 9 | 2 (ingredientes já pedidos pela onda 1, `Q-152`) |
| Tools | hot dog, 9 pacotes, copo de café, Rescue Whistle | 12 | 2 |
| Upgrades | Grill L1–L3, Cooler L1–L3, Counter L1–L3, Cash Drawer Lock, Trailer Lights, Food Trailer, cafeteira | 13 | 2 |
| Classes | 8 animais (6 MVP + Panda e Lion); usar o retrato High do AST-086 | 8 | 2 |
| HUD | moeda (AST-082), gema, sol, lua, telefone, ambulância | 6 | 2 (ambulância na 4) |
| Reações | estrela, nuvem rabiscada, vapor | 3 | 2 |
| Avisos | cadeado, trailer, "raro" (S1) | 3 | 2 |

Total **54** de 64 células (sobra para a 1ª atualização). Robux usa o ícone oficial da plataforma, fora da folha.

### Notas para o secretário (decisões e conflitos achados)

> **Secretário, 2026-10-10:** fichas AST-069, AST-071, AST-081, AST-043, AST-091 **Aprovadas (DEC-217)**; AST-017 de tigelas aprovada como está, ketchup/mostarda em tigela (**DEC-218**); 1ª pessoa com braços reais (**DEC-219**); usuário anima o AST-069 (**DEC-220**).

- ~~**Desmaio por ragdoll:** o pedido desta rodada diz "desmaio = ragdoll em código"; o style guide §4.6 (Aprovado) e FEAT-034 dizem "animação suave, sem ragdoll". Mantive ragdoll como **Provisório**; precisa de DEC para emendar o §4.6.~~ → **DEC-216**: ragdoll; §4.6 e FEAT-034 emendados.
- ~~**Expressão de desmaio:** DEC-152 aprovou a expressão "desmaiado com X"; o style guide §4.6 proíbe "olhos em X" no desmaio. Uma das duas precisa ceder.~~ → **DEC-216**: rosto `Fainted` com X; "olhos em X" sai dos proibidos.
- **Moeda de gorjeta:** §10 fala em "moeda dourada"; §2.1 reserva Gold ao AST-051. Proposta: Mustard brilhante (AST-082). **Aberta em `Q-171`** (sem decisão).
- **AST-073:** propor **Obsoleto** (coberto pela textura da crew). **Aberta em `Q-172`** (sem decisão; junto do destino do AST-016, DEC-218).
- **Máscara dos médicos:** decidida aqui como **acessório** (DEC-213 deixou acessório ou textura ao art-director).
- **ANM-001 com nariz:** proposta de manter o nariz (o sinal aprovado não cita nariz); evita 1 textura de cabeça por espécie.
- **Memória de textura (`Q-144` g):** esta rodada pede ~3 folhas 1024² de UI (kit, ícones, retratos), 3 de 512² de VFX e ~12 texturas de personagem novas (Pickett, Opal, Walt, Raincoat, Medic ×2, Walker, 9 espelhos da ANM-004). Conferir contra o teto de 30 MB (§9.2) antes de aprovar em bloco. **Segue aberto em `Q-144` (g)**; a aprovação das fichas (DEC-217) não fecha a conta de memória.

### Tabela-resumo por onda

| Onda | Fichas novas | Fichas existentes com trabalho | modeler-3d | VFX em código | UI |
|---|---|---|---|---|---|
| **2 — Noite e meta** (trailer, café, escuro, sanidade, chefe, ladrão, lobby, party) | AST-078, 079, 080, 081, 082, 083, 084, 085, 086, 087, 088, 089, 090, 091, 092 | AST-012 (níveis), 021, 043, 054, 055, 056, 057, 069 (clipes onda 2), 071, 072 | 078, 079, 080, 081, 082 (malha), 083, 085, 086 (render), 087, 088, 089, 090, 012, 021, 043, 054–057, rig do 069, renders do 071 | 082 (tween), 083 (`Beam`), 084, 085, 092 | 086, 091, 071 |
| **3 — Anomalias e rua** (ANM-001 a 010, trânsito, atropelamento, item no chão) | AST-093, 094, 095, 096 | AST-044, 045, 055 (espelho), 059, 060, 062, 063, 064, 066, 067, 069 (clipes onda 3), 070 (atropelamento) | 093, 094, texturas de 095/096, 044, 045, 059, 060, 062, 063, 064, 066, `T_Fog` do 067 | 095, 096, 067, 070 | — |
| **4 — Queda, monetização, cutscenes, final** | AST-097 | AST-058, 059 (final), 069 (clipes onda 4), 070 (desmaio, embarque, reviver), 074, 075, 076 | 097 (render), 058, 074, 075, 076 (+ máscaras) | 070 | 097, botão Robux e telas do 091 |

Contagem: **20 fichas novas** (AST-078 a AST-097) + **25 complementos** em fichas existentes.

## Fora desta lista (próxima rodada)

- ~~Lobby: plataformas de party, seleção de classe, ícones das classes~~ → AST-088, AST-089, AST-090, AST-071 e AST-086 (levantamento pós-onda 1). Layout do lobby segue com o level-designer (`Q-085`).
- Assets de áudio (style guide §11): rodada própria.
- Blockout do MAP-01 no Blender: quando pedido, junto com o level-designer.
- Lanterna de mão: fora do MVP (DEC-055).

## Notas de revisão

(vazio — preenchido pelo art-director quando o modeler-3d entregar)
