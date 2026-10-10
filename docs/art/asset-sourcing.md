Status: Rascunho

# Mapeamento de fontes — fichas AST ativas → Kenney / KayKit

Autor: art-director, 2026-10-09. Base: **DEC-136** (malha do pack + atlas de cor original, sem textura pintada; família Kenney + KayKit; mapear todas as fichas antes de importar).
Teste do usuário no Studio: `FP/hot-dog.fbx` com o colormap original foi o escolhido.
Este documento **não** muda status de ficha nem o style guide. Nada foi importado para o Studio.

**DEC-137 (2026-10-09):** linhas da **comida** aprovadas pelo usuário após o lote de teste no Studio (`workspace.__ImportTest`; pranchas em `sourcing-boards/board_1_Comida.png`): **AST-001 a AST-011 e AST-061**. Essas fichas estão **Aprovado** em `asset-list.md`. Demais linhas seguem Rascunho. `Q-133` segue aberta.

**DEC-138 (2026-10-10):** linhas de **equipamento** aprovadas após o lote de teste no Studio (`workspace.__ImportTest_Equip`): **AST-014, 015, 017, 018, 019, 024, 040, 041, 049** → **Aprovado** em `asset-list.md`. Ajustes do teste: faca deitada (AST-014); pães de hambúrguer do `crate_buns` trocados pelos de hot dog do AST-001 e tris cortados até ≤ 800 (AST-015; candidato tem 2.772); `KP/chair_stool` com **assento plano**, sem rebaixo central, em todo uso (AST-019, AST-040); `KP/menu` confirmado como cavalete (AST-024); AST-018 = `KP/fridge_A` no L3 e `MM/freezer` como base dos L1–L2. Partes sem candidato (cubas/grade do 017, pedestais/toldo/marcas do 019, L1–L2 do 018, painel/S1 do 049) seguem para modelar no estilo. **AST-012: candidato `KP/stove_*_countertop` recusado** (lê fogão); vira **roller grill** modelada (ref. `Assets/reference/AST-012_roller_grill_ref.png`, sem marca; Steel + painel Ketchup). Níveis do grill: `Q-134`.

**DEC-139 (2026-10-10):** linhas de **veículos, mercado e cidade** aprovadas em bloco após a prévia no Studio (`workspace.__Preview_Veiculos`, `__Preview_Mercado`, `__Preview_Cidade`): **AST-026 (só guarda-sóis `CC/detail-parasol-a`; casca segue modelar), 028, 029, 030, 031, 032, 033, 034, 035, 036, 044 (só a coluna `KP/pillar_A`; resto da fachada segue modelar), 045, 046, 047, 048, 050, 052, 065** → **Aprovado** em `asset-list.md`. Candidatos efetivamente usados na prévia: AST-028 `MM/wall`, `wall-window`, `wall-door-rotate`, `wall-corner` + `CC/detail-awning-wide`; AST-029 `MM/shelf-boxes`, `shelf-bags`, `shelf-end`; AST-030 `MM/freezers-standing`; AST-031 `MM/cash-register`; AST-032 `CR/road-straight`, `road-crossroad`; AST-033 `CC/building-a`, `building-h`; AST-034 `CR/road-sign-street`, `CS/tree-large`, `CS/planter`, `CK/cone`; AST-035 `CK/sedan`, `hatchback-sports`, `van`, `truck` (escala única da família); AST-036 `CR/light-curved`, `light-square`; AST-044/045 `CC/building-j` (+ `KP/pillar_A` na coluna do 044, no lugar do `MM/column`); AST-046 `CC/building-e`; AST-047 `CR/construction-fence`, `construction-light`; AST-048 `CK/delivery`; AST-050 `MM/display-fruit`, `MM/display-bread`, `KP/crate_lettuce` + **variante nova "expositor de pão de hot dog"** (`MM/display-bread` com 10 pães AST-001, 918 tris; `Assets/models/market/AST-050_BunDisplay.fbx`); AST-052 `CK/ambulance`; AST-065 `CK/sedan` esticado. **Medidas novas** (ajuste do usuário): gôndola AST-029 **4,5 × 6 × 2,5** (a linha da tabela abaixo diz 8 × 2,5 × 6: vale a DEC); expositor de frutas AST-050 **4 × 3,5 × 3**; long car AST-065 **19,5 × 7,1 × 4,0** (a linha abaixo diz ~22 × 6: vale a DEC). Faces invertidas (escala negativa) corrigidas no exportador. Edições pendentes na fila do modeler-3d: recolor `#14162A` do long car; `building-j` 5.246 → ≤ 2.500; carros ~2.030–2.090 → ≤ 2.000; `crate_lettuce` 1.980 → ≤ 1.200; paredes MM do Mart (art-director avalia); lado oculto da ambulância. **AST-074 segue a confirmar** (KayKit City Builder Bits não baixado). `Q-133`, `Q-134` seguem abertas; novas `Q-135` (layout do Mart), `Q-136` (medidas dos carros).

**Segunda passada (2026-10-09):** o usuário baixou e extraiu 5 packs Kenney (License.txt CC0 conferido; linhas em `credits.md`). As 15 linhas "pack a baixar" foram reclassificadas com o arquivo real.
As formas foram conferidas nas prévias `Assets/<Pack>/Previews/*.png` (64 px) e nas imagens `Preview*.png` / `Sample.png` de cada pack. Todos os caminhos foram conferidos por listagem da pasta.
O KayKit **City Builder Bits** não foi baixado (o itch.io exige clique do usuário): só a linha que dependia apenas dele segue "a confirmar".

Abreviações (todas as pastas `Models/FBX format/`, menos o KitchenPack):
- `FP/` = `Assets/FoodPack/Models/FBX format/` (Kenney Food Kit 2.0, CC0)
- `KP/` = `Assets/KitchenPack/Assets/fbx/` (KayKit Restaurant Bits 1.0, CC0)
- `CK/` = `Assets/CarKit/Models/FBX format/` (Kenney Car Kit 3.1, CC0)
- `CR/` = `Assets/CityKitRoads/Models/FBX format/` (Kenney City Kit Roads 2.1, CC0)
- `CC/` = `Assets/CityKitCommercial/Models/FBX format/` (Kenney City Kit Commercial 2.1, CC0)
- `CS/` = `Assets/CityKitSuburban/Models/FBX format/` (Kenney City Kit Suburban 2.0, CC0)
- `MM/` = `Assets/MiniMarket/Models/FBX format/` (Kenney Mini Market 1.0, CC0)

O KitchenPack não tem prévias: forma deduzida do nome, a conferir no Blender.

## Contagem (76 fichas ativas; AST-077 Obsoleto fica de fora)

| Encaixe | Fichas | Qtd |
|---|---|---|
| **Coberto direto** (arquivo do pack; só escala, pivô e attachments) | AST-007, 014, 050 | **3** |
| **Com edição** (recorte, recolor por UV, juntar peças, peça pequena nova) | AST-001, 002, 003, 004, 005, 006, 008, 009, 010, 011, 012, 015, 019, 021, 024, 028, 029, 030, 031, 032, 033, 034, 035, 036, 040, 041, 045, 046, 047, 048, 049, 052, 061, 065 | **34** |
| **A confirmar** (depende só do KayKit City Builder Bits, não baixado) | AST-074 | **1** |
| **Modelar no estilo Kenney/KayKit** | 38 no total, assim: | **38** |
| ↳ modelagem 3D de fato | AST-013, 016, 017, 018, 020, 022, 023, 025, 026, 027, 037, 038, 039, 042, 043, 044, 051, 063, 066, 068, 073, 075 | 22 |
| ↳ plataforma R6 + acessórios/decals | AST-053, 054, 055, 056, 057, 058, 059, 060, 062, 064, 076 | 11 |
| ↳ animação, VFX, 2D | AST-067, 069, 070, 071, 072 | 5 |

Soma: 3 + 34 + 1 + 38 = 76.

Mudança desta passada: das 15 "pack a baixar", **13 viraram edição**, **1 virou modelar** (AST-020: o `MM/cash-register` é balcão de caixa com maquininha, não registradora retrô) e **1 segue a confirmar** (AST-074: o Car Kit não tem ônibus).
Nenhuma ficha "modelar" mudou de grupo, mas 3 ganharam peça de pack de apoio: AST-018 (`MM/freezer` como ref. do L3), AST-026 (`CC/detail-parasol-a/b` para os guarda-sóis), AST-044 (`MM/column` para as colunas). AST-025 foi reconferida: nada serve.
Duas fichas que já eram edição trocaram o candidato principal para o Mini Market: AST-030 (`MM/freezers-standing`) e AST-031 (`MM/cash-register`).

## Packs (todos CC0, baixados, License.txt conferido)

| Pack | Pasta local | Usado nas fichas | Fora do mapeamento (não entra) |
|---|---|---|---|
| Kenney **Car Kit** 3.1 (50) | `Assets/CarKit` | AST-035, 048, 052, 065 (+ cone alt. para AST-034/047) | `police`, `taxi`, `tractor-police`, `firetruck`, `garbage-truck`, `race*`, `kart-*`, `tractor*`, `debris-*` (nenhuma ficha pede) |
| Kenney **City Kit Roads** 2.1 (95) | `Assets/CityKitRoads` | AST-032, 034, 036, 047 | `traffic-light*` (**DEC-130**, sem semáforo), `sign-highway*` (placa de rodovia, fora da cidade pequena), `road-sign-stop` (sem ficha), `bridge-*`, `road-slant*`, `road-roundabout*` |
| Kenney **City Kit Commercial** 2.1 (41) | `Assets/CityKitCommercial` | AST-026 (ref.), 028, 033, 045, 046 | `building-skyscraper-*` (alto demais para Bellmoor), `building-n` (traz **cruz verde** de farmácia na lateral, vista no `Sample.png`) |
| Kenney **City Kit Suburban** 2.0 (40) | `Assets/CityKitSuburban` | AST-032 (cerca baixa), AST-034 (vaso, árvore) | `building-type-*` (casas de telhado de duas águas, não é o centro de Bellmoor), `fence*` de madeira laranja, `path*`, `driveway*` |
| Kenney **Mini Market** 1.0 (20) | `Assets/MiniMarket` | AST-018 (ref.), 028, 029, 030, 031, 044 (ref.), 050 (alt.) | `character-employee` (personagens são R6, **DEC-089**), `bottle-return`, `shopping-cart`, `shopping-basket`, `fence`, `fence-door-rotate`, `floor` (sem ficha; podem virar decoração se o level-designer pedir) |
| KayKit **City Builder Bits** | não baixado | AST-074 (única dependência) | — |

## Atlases de cor dos packs (alimenta a pergunta do secretário sobre o limite de 3)

Cada formato (FBX, GLB, OBJ) traz uma cópia do mesmo `colormap.png` na sua pasta `Textures/`. Para o import vale a do FBX.

| Pack | Atlas usado pelos FBX | Variações de cor que vêm junto (mesmo layout de UV, cores trocadas) |
|---|---|---|
| Food Kit (FP) | `Assets/FoodPack/Models/FBX format/Textures/colormap.png` | — |
| Car Kit (CK) | `Assets/CarKit/Models/FBX format/Textures/colormap.png` | — |
| City Kit Roads (CR) | `Assets/CityKitRoads/Models/FBX format/Textures/colormap.png` | `Assets/CityKitRoads/Models/Textures/variation-a.png` |
| City Kit Commercial (CC) | `Assets/CityKitCommercial/Models/FBX format/Textures/colormap.png` | `Models/Textures/variation-a.png`, `variation-b.png` (a variação A deixa os prédios Peach/laranja, ver `Preview (Variation A).png`) |
| City Kit Suburban (CS) | `Assets/CityKitSuburban/Models/FBX format/Textures/colormap.png` | `Models/Textures/variation-a.png`, `-b.png`, `-c.png` |
| Mini Market (MM) | `Assets/MiniMarket/Models/FBX format/Textures/colormap.png` | `Models/Textures/variation-a.png` (troca o verde por azul), `-b.png` |
| KitchenPack (KP, KayKit) | `Assets/KitchenPack/Assets/textures/restaurantbits_texture.png`, 1024² | — |

**Os Kenney compartilham o colormap?** **Não é o mesmo arquivo.** Todos têm o mesmo formato (aparentam 512², quadrados de 64 px com gradiente vertical, faixa de cima preta/vazia) e usam **a mesma família de ~30 cores** Kenney (os mesmos verdes, laranjas, vermelhos, azuis, lilases, cinzas-violeta, peles, branco). Mas **a posição de cada cor muda de pack para pack**, e cada um tem cores a mais ou a menos (o FP tem marrom-escuro e verde-pinho que os City Kits não têm; o CR tem um rosa-velho; o MM tem menos cores e mais área vazia). Commercial e Suburban são quase iguais (linhas 2 e 3 idênticas; a 4ª linha muda de ordem), mas ainda diferentes.
Consequência: sem mexer em UV, cada pack Kenney é um atlas a mais. Os 5 novos somados ao FP, ao KP e ao do projeto dão **8 atlases** (mais as variações, se alguma for usada).

Caminhos possíveis para a Q (decisão do usuário; nada foi feito):
- (a) **Aceitar mais atlases.** São pequenos (512², gradiente comprime bem), mas cada um é uma textura a mais na memória e quebra o agrupamento de draw call entre packs (§9.2).
- (b) **Um atlas Kenney unificado.** Como as cores são da mesma família, as ilhas de UV de cada peça Kenney (FP incluído) podem ser **movidas** para a cor equivalente de um único colormap, sem repintar nada. Resultado: KP + Kenney unificado + projeto = 3. Custo: um passo de remapeamento no Blender por peça importada (já é o que fazemos no "recolor").
- (c) Variante de (b): usar a **faixa preta vazia** do topo do colormap unificado para as cores do projeto (Sage, Peach, Butter, Lilac, Brick, Mint-gray, Teal, Cream, Gold, cinza-azulado da ANM-002). Daria **2 atlases** (KP + Kenney/projeto), mas mistura o atlas do projeto (§1.2) com o de pack.
- Observação: Suburban só fornece 3 peças (`planter`, `fence-low`, árvores). Mesmo na opção (a), essas 3 podem ser remapeadas para outro atlas e o colormap do Suburban fica fora do jogo.

## Riscos gerais (valem para várias linhas)

1. **Atlas a mais.** Ver seção acima. Proposta para o secretário: **Q nova**, não bloqueante para o mapeamento.
2. **"Recolor" aqui = mover UV para outra faixa do colormap do próprio pack.** Não envolve pintar. Se a cor da paleta (§2.1/§2.2) não existir no colormap, a peça é remapeada para o atlas do projeto `T_Palette_SH.png` (§1.2). Sage, Butter, Mint-gray, Brick e Cream **não existem** nos colormaps Kenney do jeito da paleta: prédios, Mart, carros e ambulância vão quase todos para o atlas do projeto (ou para o unificado, se a Q decidir assim).
3. **Escala.** Kenney e KayKit usam unidades diferentes entre si e do Roblox. Medir no import contra a ficha. Comida fica ~1,5–2× o real (§1.1). As peças de pista do CR já trazem uma calçada fina embutida: escala não uniforme deforma o meio-fio (ver AST-032).
4. **Cores reservadas (§2.4).**
   - **Nenhum carro de trânsito preto nem com mais de 16 studs** (exceto AST-065). Nenhum carro do CK escolhido vem preto; `police` é preto e branco e já está fora. O caminhão (AST-048, ~20) e a ambulância (AST-052, 16) não são "carro de trânsito" e não são pretos: mantêm forma e cor bem distintas do long car.
   - Nenhuma comida ou embalagem em cinza-azulado (exceto AST-061). As prateleiras do MM vêm com produtos embutidos em azul-claro e lilás (`shelf-boxes`, `shelf-end`): recorte ou recolor (ver AST-029).
   - **Coral `#FF8A65` só no neon do Mart.** Os colormaps Kenney têm laranja e salmão próximos: nenhuma faixa de letreiro, luz ou vitrine de prédio do CC pode ficar coral (os prédios trazem tiras laranja/amarelas sobre as vitrines, ver `CC/Preview.png`).
   - Nenhum casaco amarelo de corpo inteiro (não afeta estes packs; `character-employee` está fora).
5. **Marca, IP e emblemas.** Rótulos, logos e combinações icônicas saem por decal próprio (AST-072). Nada de viatura (`police`, `tractor-police`) nem táxi (`taxi`): nenhuma ficha pede. Nenhuma cruz (vermelha ou verde) em veículo ou prédio.
6. **Sem semáforo (DEC-130).** Nenhum `CR/traffic-light*` entra, nem como decoração.
7. **Personagens R6 (DEC-089).** `MM/character-employee` não entra.

## Tabela por ficha

| AST | Nome | Candidato | Encaixe | Nota de risco |
|---|---|---|---|---|
| AST-001 | Bun (pão) | `FP/hot-dog.fbx` (separar o pão) | edição: recorte (tirar salsicha e molho → `Bun_Open`); `Bun_Closed` = fechar o corte | **Correção da ficha:** pela prévia, `FP/hot-dog-raw.fbx` é a **salsicha crua sozinha**, não o pão. Conferir no Blender se pão, salsicha e molho são objetos separados |
| AST-002 | Sausage crua/grelhada | crua `FP/hot-dog-raw.fbx`; grelhada = mesma malha com UV na faixa marrom (alt. `FP/meat-sausage.fbx`) | edição: recolor | `FP/meat-sausage.fbx` é **curva** e não encaixa reta no pão nem na vaga da grelha. `FP/sausage.fbx` é um gomo com pontas amarradas (forma de linguiça), não serve de salsicha de hot dog. Marcas de grelha: faixa escura no UV se o colormap tiver |
| AST-003 | Hot dog montado (Tool) | `FP/hot-dog.fbx` (escolhido no teste do Studio) | edição: recorte do molho que já vem na malha | A prévia mostra molho em cima. O Tool precisa de uma versão **sem molho** para os `Att_Topping1..3`. A versão com molho serve para vitrine e ícone |
| AST-004 | Ketchup | garrafa `FP/bottle-ketchup.fbx` (alt. `KP/ketchup.fbx`); cobertura = molho recortado de `FP/hot-dog.fbx` | edição: juntar peças (garrafa direta + cobertura recortada, 5 dobras) | Preferir a garrafa FP para a comida ficar toda Kenney. Garrafa vermelha lisa, sem rótulo: ok |
| AST-005 | Mustard | garrafa `FP/bottle-musterd.fbx` (alt. `KP/mustard.fbx`); cobertura = mesma origem do AST-004, deformada para 7 dobras | edição: recolor + deformação | A forma tem de diferir do ketchup, não só a cor (ficha) |
| AST-006 | Cheese | fatia `FP/cheese-cut.fbx` (alt. `KP/food_ingredient_cheese_slice.fbx`) | edição: `Cheese_Slice` direto; `Cheese_Topping` = fatia dobrada com 2 pontas caindo | Fatia com furos lê bem como queijo. Sem risco de marca |
| AST-007 | Bacon | `FP/bacon.fbx` (crua: `FP/bacon-raw.fbx`) | **direto** (pilha e cobertura = instâncias da mesma tira) | nenhum |
| AST-008 | Potato Sticks | `FP/fries.fbx` (só os palitos) | edição: recorte dos palitos + escala fina para virar monte | **Não usar a caixa vermelha das fritas** (vermelho + amarelo de fast food é combinação icônica, §1.2) |
| AST-009 | Cream Cheese | pote `KP/jar_B_medium.fbx`; cobertura `FP/whipped-cream.fbx` | edição: recolor da tampa para Teal; cobertura = espiral escalada | A espiral do `whipped-cream` cobre a regra "espiral = cream cheese" do AST-003. Conferir se a cor não confunde com o pão aberto |
| AST-010 | Coffee + `Coffee_Pair` | `FP/soda.fbx` (copo para viagem com tampa e canudo) | edição: recorte do canudo + recolor (copo branco, cinta Teal, tampa Coffee) | `FP/cup.fbx` e `FP/cup-coffee.fbx` são **canecas**, não copo de viagem. O roxo original do `soda` sai |
| AST-011 | Pacotes do mercado (9) | `FP/bag.fbx`, `FP/bag-flat.fbx`, `FP/carton.fbx`, `FP/carton-small.fbx`, `FP/can.fbx`, `FP/can-small.fbx` | edição: recolor por pacote + rótulo decal (AST-072) | `carton` e `carton-small` vêm como caixa de leite (roxa/rosa): recolor obrigatório. Nenhum pacote em cinza-azulado (§2.4) |
| AST-012 | Grill (3 níveis) | base `KP/stove_single_countertop.fbx` (L1) e `KP/stove_multi_countertop.fbx` (L2/L3) | edição: juntar peças (chapa com grelhas e tampa cromada modeladas por cima) | Fogão com bocas lê "fogão", não "chapa": a chapa precisa cobrir as bocas. Se não ler, vira modelar |
| AST-013 | Trilho de descanso | — | modelar | Modelar no estilo Kenney/KayKit: rampa curta de roletes com bordas laterais, cantos chanfrados |
| AST-014 | Tábua + faca | `KP/cuttingboard.fbx`, `KP/knife.fbx` (alt. `FP/cutting-board.fbx`, `FP/cooking-knife.fbx`) | **direto** | Escolher um pack só para os dois |
| AST-015 | Caixa de pães | `KP/crate_buns.fbx` + `KP/crate_lid.fbx`; `Fill` = instâncias do pão do AST-001 | edição: trocar o recheio | O `crate_buns` deve vir com pão **redondo de hambúrguer** (KayKit é de restaurante): trocar por pão de hot dog. Conferir no Blender |
| AST-016 | Porta-garrafas | — (garrafas do AST-004/005) | modelar | Modelar no estilo: suporte de arame grosso que segura a garrafa de ponta-cabeça, 1 por célula |
| AST-017 | Grade de complementos + cubas | — (base pode usar `KP/kitchencounter_straight_A.fbx`) | modelar | Modelar no estilo: grade 3 × 2 com degrau e cuba de aço de tampa basculante; tampos KP servem de base |
| AST-018 | Cooler (3 níveis) | L3 ref. `KP/fridge_A.fbx`; alt. L3 `MM/freezer.fbx` (freezer horizontal de tampa de vidro) | modelar | Modelar no estilo: caixa térmica pequena com rodinhas (L1) e dupla (L2). Para o L3, testar `KP/fridge_A.fbx` reduzido a 3 de altura ou o `MM/freezer.fbx` em Steel (se um servir, vira edição) |
| AST-019 | Counter (3 níveis) + pedestais | `KP/kitchencounter_straight_A.fbx` / `_B`, `KP/kitchencounter_outercorner.fbx` (L3 em L), `KP/chair_stool.fbx` (banquinhos do L2), `KP/wall_orderwindow.fbx` (ref.) | edição: juntar peças + recolor; pedestal com corda e toldo modelados | Marcas de fila são decal/Part plana, sem malha |
| AST-020 | Entrega + gaveta + Lock | — | **modelar** (era "pack a baixar") | Conferido: `MM/cash-register.fbx` é um **balcão de caixa de mercado com maquininha** (prévia), não registradora retrô de teclas grandes nem tem gaveta. Modelar registradora retrô arredondada 1,6 × 1,4 × 1,0, gaveta separada, Ketchup. O `MM/cash-register` serve ao AST-031 |
| AST-021 | Saco de moedas | `FP/bag.fbx` | edição: recolor `#B9A27A` + 2–3 moedas + "$" decal | O `bag` é saco de papel de boca reta. A silhueta de "saco de ladrão" pede boca amarrada: ajuste pequeno de malha |
| AST-022 | Cafeteira | — | modelar | Modelar no estilo: máquina de balcão com bico, jarra translúcida, botão grande e lâmpada de pronto |
| AST-023 | Trailer Lights | — | modelar | Modelar no estilo: mastro com refletor triplo + cordão de 12 lâmpadas redondas (malha única) |
| AST-024 | Placa OPEN/CLOSED + "Available on Day 5" | `KP/menu.fbx` | edição: escala para 2 × 4 + decal; `Sign_ForSale` = mesma peça em 4 × 5 | Conferir no Blender se `menu` é cavalete de chão ou cardápio de mesa. Se for de mesa, vira modelar. `CR/road-sign-empty` (placa de rua sem face) não tem cara de cavalete: não serve |
| AST-025 | Lixeira (pedal) | — | modelar | Conferido nos packs novos: só `CR/dumpster.fbx` (caçamba de rua, grande e de tampa dupla), que não lê como lixeira de pedal de cozinha. Modelar no estilo: lixeira de pedal Teal, tampa basculante separada |
| AST-026 | Corner Cart | casca: —; guarda-sóis `CC/detail-parasol-a.fbx` / `CC/detail-parasol-b.fbx` | modelar (casca) + pack nos guarda-sóis | Modelar no estilo: carrinho retrô comprido, 4 rodas grandes, saia com letreiro. Os parasóis do CC são de mesa (verdes, com mesinha na base): tirar a base, recolor Mustard/Cream. Peças internas vêm das outras fichas |
| AST-027 | Open Late Trailer | casca: —; interior `KP/kitchencounter_straight_B.fbx` | modelar (casca) + KP no interior | Modelar no estilo: casca de alumínio de cantos muito arredondados com faixa, rebites grandes, toldo basculante. **Sem** forma de trailer de marca real |
| AST-028 | Ninth Street Mart (fachada, letreiro, ponto seguro) | `Wall` `MM/wall.fbx`, `Wall_Window` `MM/wall-window.fbx`, `Wall_Door` `MM/wall-door-rotate.fbx` (vão de porta com folhas; o `-rotate` sugere folhas separadas: conferir), canto reto `MM/wall-corner.fbx`; `Awning` `CC/detail-awning-wide.fbx` (alt. `CC/detail-overhang-wide.fbx`); portas alt. `KP/door_B.fbx` | edição: escala para módulo 8 × 12 + recolor Sage/Off-white; `Corner` chanfrado, `Roof_Trim`, `Marquee`, `Sign_Name`, `Sign_Open24` e `SafeZone_Marking` modelados/decal | As paredes do MM são escuras com faixa verde (interior de loja): recolor obrigatório. O toldo do CC é **chapa lisa sobre pés**, não toldo listrado de parede: tirar os pés e fazer as listras verde/branco por UV. **Coral `#FF8A65` exclusivo:** nenhuma peça de pack com luz ou faixa coral |
| AST-029 | Prateleira de compra + recheio | gôndola de 2 faces `MM/shelf-boxes.fbx` (alt. `MM/shelf-bags.fbx`); ponta de gôndola `MM/shelf-end.fbx`; recheio `FP/can.fbx`, `FP/carton.fbx`, `FP/bottle-oil.fbx`, `FP/honey.fbx`, `FP/peanut-butter.fbx`, `KP/jar_*_small/medium` | edição: recorte dos produtos embutidos + escala para 8 × 2,5 × 6 + 3º andar se faltar; recheio direto | As prateleiras do MM vêm **com produtos na malha** (caixas laranja/amarelas, sacos, frascos azuis e lilás): tirar no Blender (se não forem objetos separados, recorte manual) e pôr o recheio das fichas. Prévia mostra 2 andares: conferir se dá 3 andares com andar de compra a 3,0–4,5. `shelf-end` traz placa verde no topo: serve de suporte para o preço. **Não usar `FP/soda-bottle.fbx`** (lembra garrafa de refrigerante de marca) |
| AST-030 | Geladeira expositora | `MM/freezers-standing.fbx` (geladeira de 2 portas de vidro); alt. `KP/fridge_B.fbx` | edição: escala para 4 × 2,5 × 7 + vidro translúcido + faixa Teal | Troca do candidato principal: o MM já tem porta de vidro e deixa o mobiliário do Mart todo de um pack só. Recolor Off-white (vem cinza-lilás) |
| AST-031 | Balcão do caixa do Mart | `MM/cash-register.fbx` (balcão de caixa com maquininha); alt. `KP/kitchencounter_straight_A.fbx`; `KP/chair_stool.fbx`, caneca `FP/mug.fbx` | edição: escala para 6 × 2,5 × 3,5 + recolor Sage | O balcão do MM já é um caixa de mercado: a ficha pede "registradora = malha do AST-020 em Sage". Decidir no import se fica a maquininha do MM ou a registradora do AST-020 (a ficha diz AST-020; a maquininha poupa uma dependência) |
| AST-032 | Kit de rua | `Road_Straight` `CR/road-straight.fbx` (+ `CR/road-straight-half.fbx`), `Road_Cross` `CR/road-crossroad.fbx` (4 braços), `Road_End` `CR/road-end.fbx`, `Crosswalk` `CR/road-crossing.fbx` (ou `CR/road-crossroad-path.fbx`, cruzamento já com faixas), `Stop_Line` ref. `CR/road-crossroad-line.fbx`, `Sidewalk`/`Pad_Tile`/`Parking_Tile` `CR/tile-low.fbx`, `Parking_Fence_Low` `CS/fence-low.fbx` | edição: escala + recolor (Asfalto `#4A4E58`, Calçada, Pad `#E8D9B5` com borda Mustard, estacionamento `#5A5F69`); `Curb` vermelho, `Curb_Ramp`, `Manhole`, `Parking_Curb_Stop` modelados (peças de 12–200 tris) | As pistas do CR são **ladrilhos quadrados com calçada fina embutida**. Ninth (32 de pista + 16 de calçada) e Juniper (24 + 12) não batem com a proporção: escala não uniforme estica o meio-fio. Testar no Blender; se deformar, usar só o miolo da pista e a calçada como `tile-low`. Faixa só conforme `Q-129`. **Nenhum `CR/traffic-light*`** (DEC-130). `road-sign-stop` fica fora |
| AST-033 | Kit de prédio | prédios baixos `CC/building-a.fbx` a `CC/building-h.fbx` (2–4 andares, vitrine no térreo; `building-e` e `building-h` com toldo verde), largos `CC/building-j.fbx`, `CC/building-k.fbx`; `BG_Card` `CC/low-detail-building-a.fbx` a `-n.fbx` e `-wide-a/b.fbx` | edição: recolor Peach/Butter/Lilac/Brick/Mint-gray + `Door_D1` recortada de um térreo + placa "NO HELP WANTED" por decal | **Mudança de forma em relação à ficha:** o CC traz **prédios inteiros**, não módulos de fachada 8 × 12 por andar. B1, B3–B5 viram "um prédio do CC recolorido por lote"; os lotes do MAP-01 precisam caber nas larguras do pack (o level-designer confere). Se a ficha mantiver o kit modular, o CC só serve de referência e vira modelar. Visual do CC é moderno (branco, telhado plano, janelas largas): o tijolo de Bellmoor vem do recolor Brick. **Não usar `building-n`** (cruz verde de farmácia) nem `building-skyscraper-*`. O Suburban fica fora (casas de telhado inclinado) |
| AST-034 | Mobiliário urbano | placa de nome de rua `CR/road-sign-street.fbx` (2 lâminas); vaso com arbusto `CS/planter.fbx`; árvore `CS/tree-large.fbx` / `CS/tree-small.fbx`; cone `CR/construction-cone.fbx` (alt. `CK/cone.fbx`); ponto de ônibus `CC/detail-overhang.fbx` (só se AST-074 entrar) | edição (parcial): pack + recolor + decal; **modelar** banco de praça, lixeira de rua, hidrante e caixa de correio | Placas de rua com decal próprio "NINTH AVE" / "JUNIPER ST" (AST-072), sem padrão de sinalização de país real. A árvore do CS é **cônica** (pinheiro), a ficha pede **redonda** 6 Ø × 10: testar; se não ler, modelar. `CR/dumpster.fbx` não é lixeira de rua (é caçamba), mas pode ir como decoração de beco se o level-designer quiser. Caixa de correio sem logo de serviço postal real |
| AST-035 | Carros de trânsito (4) | `Car_Sedan` `CK/sedan.fbx`; `Car_Hatch` `CK/hatchback-sports.fbx`; `Car_Van` `CK/van.fbx`; `Car_Pickup` `CK/truck.fbx` (picape) | edição: escala para as medidas da ficha + recolor nas 5 cores (Peach, Butter, Lilac, Mint-gray, Teal claro) + `Headlights` Neon | **Nunca preto, nunca mais de 16 studs** (§2.4): as 4 escolhidas vêm vermelha, verde, azul e verde; a maior (van/picape) fica em 13. **Não usar** `police`, `taxi`, `sedan-sports` (aerofólio de corrida), `suv-luxury`, `race*`, `kart-*`. Conferir no Blender se as rodas vêm como objetos separados (`Wheel_*` giram). Silhuetas são genéricas de brinquedo, sem grade de montadora |
| AST-036 | Poste de luz | `CR/light-curved.fbx` (poste curvo de braço único); alt. `CR/light-square.fbx` | edição: manter o fuste, engrossar o braço para 0,5, **trocar a cabeça** por cúpula Ø 2,0 com disco `Neon` Ø 1,4 por baixo; recolor `#4B4F63` | A cabeça do pack é pequena e fina (some a ~135 studs): a cúpula é peça nova. O cinza-lilás do CR fica perto de `#4B4F63`. Instanciar a mesma malha; LOD ≤ 200 tris. Os `CR/electricity-*` ficam fora (não pedidos) |
| AST-037 | Panfleto | — | modelar | Modelar no estilo: plano ondulado 1,4 × 2,0 com 8 tiras (uma faltando); o resto é decal |
| AST-038 | Celular flip | — | modelar | Modelar no estilo: flip arredondado de 2 partes com dobradiça e antena curta |
| AST-039 | Interruptor "Lights" | — | modelar | Modelar no estilo: caixa de disjuntor com alavanca grossa de ponta Mustard e lâmpada-piloto |
| AST-040 | Banco do fundo do trailer | base `KP/kitchencabinet.fbx` (×3, banco-baú); pés ref. `KP/chair_stool.fbx` | edição: juntar peças + almofada modelada em Ketchup Faded | Almofada é caixa chanfrada simples. Conferir a altura do assento (1,6) |
| AST-041 | Pontos "Hide" (×4) | `KP/kitchencabinet_half.fbx` | edição: recolor da alça para Mustard (ou alça maior) | A alça tem de ler a 4 studs no escuro |
| AST-042 | Telefone fixo (2 variantes) | — | modelar | Modelar no estilo: telefone de parede antigo, fone grande, sino e lâmpada no topo, caixinha à parte |
| AST-043 | Lona do carrinho | — | modelar | Modelar no estilo: lona de dobras largas sobre o volume do AST-026, 3 cordas |
| AST-044 | Bellmoor Savings + relógio | — (colunas: testar `MM/column.fbx`, coluna gorda redonda, ou `KP/pillar_A.fbx` / `KP/pillar_B.fbx`) | modelar | Modelar no estilo: frontão, colunas gordas e relógio Ø 6 com ponteiros separados. Landmark próprio. Letreiro por decal. A `MM/column` vem escura com faixa verde: recolor Cream |
| AST-045 | Apartamentos sobre o banco | 2 andares recortados de um prédio largo do CC (`CC/building-j.fbx` ou `CC/building-k.fbx`) + `Window_Up_<N>` | edição: recorte de 2 andares + largura ajustada a 28 + recolor Peach; janelas WV modeladas | Janelas WV precisam de cortina e estado `Lit` próprios (peça do projeto). O andar do CC tem de casar com o pé-direito de ~6 e as WV a 19–28: conferir no Blender |
| AST-046 | Lavanderia | `CC/building-e.fbx` (2 andares, térreo com vitrine e toldo; alt. `CC/building-c.fbx`) | edição: recolor Mint-gray/Off-white + toldo Lilac por UV; vitrine com 4 máquinas (cartão) e `Door_SPB` modeladas | Placa por decal, sem marca |
| AST-047 | Barreira (BAR-N, BAR-S) | cavalete `CR/construction-fence.fbx` (barreira de tubo); listra ref. `CR/construction-light.fbx`; cone `CR/construction-cone.fbx` (alt. `CK/cone.fbx`) | edição: recolor listrado Mustard/`#4B4F63` + placa "SIDEWALK CLOSED" por decal | A `construction-fence` é barreira de tubo lisa: as listras vêm por UV/decal. `CR/construction-barrier.fbx` é **mureta de concreto** (tipo New Jersey) e tapa a visão: não usar. Tudo só nas calçadas |
| AST-048 | Caminhão de entrega | `CK/delivery.fbx` (caminhão-baú) | edição: escala para ~20 × 8 × 10 + recolor (baú Off-white, cabine Peach) | Vem com baú verde e cabine branco-lilás, sem logo. Placa "DELIVERY" opcional por decal. Não é carro de trânsito (parado, oclusor) |
| AST-049 | Bancada de upgrades (GEAR WALL) | `KP/kitchencounter_straight_A.fbx` (×6), `KP/shelf_papertowel.fbx` (nichos) | edição: juntar peças + recolor; painel e vitrine S1 modelados | **Gold** só na moldura S1 (§2.1). Textos por `SurfaceGui` |
| AST-050 | Frutas e verduras do Mart | `KP/crate_lettuce.fbx`, `crate_tomatoes`, `crate_carrots`, `crate_onions`, `crate_potatoes`; `FP/apple.fbx`, `banana`, `orange`, `pear`, `lemon`, `grapes`, `watermelon`, `pineapple`, `cabbage`, `broccoli`, `corn`, `eggplant`, `paprika`; base: `KP/kitchentable_A.fbx` ou caixotes empilhados; alt. de base `MM/display-bread.fbx` | **direto** | `MM/display-bread.fbx` é **expositor inclinado de 2 degraus** (a forma que a ficha pede para a base), mas vem com pães na malha: se for escolhido, vira edição (tirar os pães, recolor madeira `#C98B5A`). `MM/display-fruit.fbx` é um cesto pequeno de frutas laranja: decoração opcional. Nada em cinza-azulado (§2.4) |
| AST-051 | Revive Kit (apito dourado) | — | modelar | Modelar no estilo: apito gordo com bocal, anel e cordão. Gold exclusivo |
| AST-052 | Ambulância + maca | `CK/ambulance.fbx` (van-baú alta) | edição: escala para 16 × 7 × 8 + recolor (Cream, faixa Teal larga) + barra de luz Mustard/Teal + **recorte das portas traseiras** em 2 folhas com dobradiça + degrau; `Stretcher` modelada | Vem **branca com faixas vermelhas** e luzes vermelhas: o recolor tira o vermelho todo. Nas prévias (64 px de lado e `CK/Preview.png`) **não aparece cruz**, mas só um lado é visível: conferir no Blender; se houver cruz, Star of Life ou xadrez, **remover por recolor/edição**. Símbolo próprio (coração Teal com "+") e "BELLMOOR RESCUE" por decal |
| AST-053 | Base de personagem R6 | plataforma R6 | modelar (decals de rosto e roupa) | Fora de pack |
| AST-054 | Clientes (7 × 4) | plataforma R6 | modelar acessórios no estilo | ~16 acessórios grossos de atlas. Sem marca nem traço reservado |
| AST-055 | Mr. Pickett | plataforma R6 | modelar acessórios no estilo (maleta, relógio, gravata) | Maleta: nenhum candidato nos packs locais |
| AST-056 | Quick Quentin | plataforma R6 | modelar acessórios no estilo (sobretudo, chapéu, óculos) | Sobretudo em `#7A6FB0`, não `#14162A` (Walker) |
| AST-057 | Opal | plataforma R6 | modelar acessórios no estilo | Caneca do balcão: `FP/mug.fbx` |
| AST-058 | Walt Bramble | plataforma R6 | modelar acessórios no estilo | Segura AST-010 `Coffee_Pair` |
| AST-059 | Raincoat Lady (ANM-005) | plataforma R6 | modelar acessórios no estilo (capa, botas, guarda-chuva) | Amarelo `#F2C230` reservado |
| AST-060 | ANM-001 blank folks | plataforma R6 + `Coin_Blank` | modelar (moeda, cabeça sem decal) | Moeda: nenhum candidato nos packs locais |
| AST-061 | ANM-002 wrong food | `FP/hot-dog-raw.fbx` (salsicha) + pão do AST-001 | edição: recolor cinza-azulado + recorte de mordida no pão | O colormap Kenney provavelmente não tem a faixa `#8E9AAE`. Se não tiver, a faixa vai para o atlas do projeto (cor exclusiva, §2.4) |
| AST-062 | ANM-004 copies | decals espelhados + acessórios do AST-054 | modelar (decal + espelhamento) | Fora de pack |
| AST-063 | ANM-006 wavers | — | modelar | Modelar no estilo: cartão de busto `#2B2233` com braço separado |
| AST-064 | ANM-007 Walker | plataforma R6 (~1,4×) | modelar acessórios no estilo (chapéu de aba larga, sobretudo em saia) | `#14162A` reservado |
| AST-065 | ANM-008 long car | `CK/sedan.fbx` esticado (mesma base do `Car_Sedan` do AST-035) + 2 rodas a mais de `CK/wheel-default.fbx` | edição: alongar para ~22 × 6 + recolor preto + 3º eixo | Única exceção a "preto" e "> 16 studs". 6 rodas. Sem forma de limusine ou carro funerário de marca. Farol alto `#F4F7FF` é peça própria |
| AST-066 | ANM-009 porta dos fundos | — (peça da casca do AST-027) | modelar | Modelar no estilo: porta arredondada de trailer com janelinha, pivô na dobradiça. `KP/door_A.fbx` é porta de restaurante, não serve |
| AST-067 | ANM-010 Hush | — | modelar (VFX) | Textura de partícula 256²; o resto reaproveita AST-028 e AST-036 |
| AST-068 | Foto 1979 + crachá | — | modelar | Modelar no estilo: 2 placas finas chanfradas; arte por decal |
| AST-069 | Animações R6 | — | modelar (animação) | Fora de pack |
| AST-070 | VFX pastelão | — | modelar (texturas de partícula) | Fora de pack |
| AST-071 | Ícones de UI | renders das peças de pack (FP/KP/CK/CC/MM) | modelar (render + 2D) | Ícones saem dos mesmos modelos importados: fazer depois do import |
| AST-072 | Placas, letreiros, logos | — | modelar (2D) | Fora de pack |
| AST-073 | Avental Bramble's | — | modelar | Modelar no estilo: avental de 1 peça grossa preso em `BodyFrontAttachment` |
| AST-074 | Ônibus urbano | KayKit **City Builder Bits** (a confirmar, não baixado) | a confirmar → senão modelar | **O Car Kit não tem ônibus** (conferido na listagem e no `CK/Preview.png`). `CK/delivery.fbx` esticado a 30 não lê como ônibus (cabine separada do baú). Se o KayKit não tiver ou não for baixado, modelar caixa arredondada 30 × 8 × 10 com janelas em fila. Butter `#F3DFA2` com faixa Peach; **não** o amarelo de ônibus escolar. Sem logo |
| AST-075 | Props da cutscene (carteira, mariposa, pombos, jornal) | — | modelar | Modelar no estilo: carteira de 2 abas, mariposa de 2 asas planas, pombo low-poly de corpo em gota |

## Sem candidato de pack (vão para o modelador como modelagem nova)

AST-013, 016, 017, 018, 020, 022, 023, 025, 026 (casca), 027 (casca), 037, 038, 039, 042, 043, 044, 051, 063, 066, 068, 073, 075 — mais as peças novas **dentro** de fichas de edição: cúpula do poste (AST-036), banco de praça, lixeira de rua, hidrante e caixa de correio (AST-034), meio-fio vermelho, rampa, bueiro e batente de vaga (AST-032), maca (AST-052), `Corner` chanfrado, marquise e letreiros do Mart (AST-028), janelas WV (AST-045), vitrine da lavanderia (AST-046).
AST-074 depende do KayKit; sem ele, entra nesta lista.

## Próximos passos (não executados)

1. Usuário aprova este mapeamento (ou parte dele).
2. KayKit City Builder Bits: só vale baixar se o usuário quiser tentar o ônibus (AST-074); nenhuma outra ficha depende dele agora.
3. Conferir no Blender os pontos marcados "conferir": AST-001/003 (objetos separados no `hot-dog.fbx`), AST-015 (pão do `crate_buns`), AST-024 (`menu`), AST-029 (produtos embutidos nas prateleiras do MM), AST-032 (proporção pista/calçada do CR), AST-035/052/065 (rodas separadas; lado oculto da ambulância), AST-045 (pé-direito do CC).
4. AST-033: decidir com o level-designer se os lotes aceitam prédios inteiros do CC (a ficha hoje pede kit modular).
5. Secretário: Q sobre o limite de 3 atlases (seção "Atlases de cor dos packs").
6. `asset-list.md`: as colunas "Fonte" das fichas reclassificadas ainda dizem "a confirmar, não baixado". Atualizar quando o usuário aprovar este mapeamento (sem mudar status).
