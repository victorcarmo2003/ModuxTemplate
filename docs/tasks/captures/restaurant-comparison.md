Status: Rascunho (TASK-382, level-designer, 2026-10-17; números Provisórios, sem DEC nova além das citadas)

# MAP-01 r4 — trailer atual × trailer expandido "Corner Dogs"

Fontes: `docs/levels/MAP-01-r4-restaurant.md` (planta rev. 2), DEC-269..282 (DEC-281: não é prédio, é **trailer expandido** com o visual do AST-027; DEC-282: porta externa nos fundos), `docs/tech/restaurant-flow.md` §4.1. Montagem: `tools/assetplace/restaurant_bind.luau` (snippet idempotente, com `undo` e modo `diff`). Verificação: `tools/assetplace/zfight_scan.luau`, `tools/assetplace/restaurant_walk_check.luau`.

Prints (mesma câmera antes/depois, FOV 70, Edit):

| Vista | Antes (trailer) | Depois (trailer expandido) |
|---|---|---|
| De cima | `restaurant-before/01_top.jpg` | `restaurant-after/01_top.jpg` |
| 1ª pessoa no balcão | `restaurant-before/02_first_person_counter.jpg` | `restaurant-after/02_first_person_counter.jpg` |
| Cliente chegando (calçada, portão) | `restaurant-before/03_customer_arriving.jpg` | `restaurant-after/03_customer_arriving.jpg` |
| Rua (3/4 alto) | `restaurant-before/04_street.jpg` | `restaurant-after/04_street.jpg` |
| Blockout (passo 2) | — | `restaurant-after/00_blockout_top.jpg`, `00_blockout_first_person.jpg` |
| Z-fighting (parede leste, friso) | `restaurant-after/10_zfight_before.jpg` | `restaurant-after/11_zfight_after.jpg` |
| Estoque / despensa | `restaurant-after/20_stock_before.jpg` | `restaurant-after/21_stock_after.jpg` |
| Fundos, porta, escotilha | `restaurant-after/30_door_back_before.jpg` | `restaurant-after/31_door_exit_after.jpg`, `32_back_after.jpg` |
| Janela do drive-thru | `restaurant-after/40_window_dt_before.jpg` | `restaurant-after/42_window_dt_after.jpg` |
| Janela de serviço (frente) | — | `restaurant-after/41_window_front.jpg` |
| Depósito por produto (rev. 2) | `restaurant-after/21_stock_after.jpg` | `restaurant-after/50_stock_aisle.jpg`, `51_stock_bays_north.jpg` |
| Lote do Mart (vazio: o Mart foi para o ServerStorage) | — | `restaurant-after/60_mart_lot_empty.jpg` |
| Portas DOOR-P / DOOR-B fechadas e abertas (rev. 2) | `restaurant-after/31_door_exit_after.jpg` | `restaurant-after/70_doorP_closed_kitchen.jpg`, `71_doorP_open_doorB_closed.jpg`, `72_doorB_outside.jpg` |
| Faixa de menu = quadro de pedidos (rev. 2) | — | `restaurant-after/80_menustrip_orderboard.jpg` |

## 1. Design visual

| | Trailer atual (AST-027) | Trailer expandido |
|---|---|---|
| Casca | malha única 28 × 10 × 12, branca, cantos arredondados, faixa mostarda/vermelha, toldo, varal de luz | **dois módulos acoplados** com a mesma leitura: cozinha 35 × 18 + despensa 25 × 7 atrás, cantos e beiral arredondados, saia escura, faixa mostarda + linha ketchup, rodas em tandem com caixa de roda, macacos estabilizadores. A malha do AST-027 não pôde ser esticada: janela de 21,75 e paredes de fundo/lateral sólidas (medido por raycast), sem lugar para drive-thru nem porta de despensa |
| Peças do AST-027 reaproveitadas | — | aba/persiana `Shutter_Panel` (esticada para a janela de 31,8), varal `Detail_*` (agrupado pelo dono), barra/mastro `TRL-LIGHTS`, logo, rodas `Wheel_*`, neon OPEN/CLOSED, letreiro CORNER DOGS, todas as estações e prompts (clonados com tags) |
| Janela de serviço | 22 de largura, 5,4 de altura | 31,8 × 5 (de X 26,6 a 58,4): o balcão é "de ponta a ponta" na prática |
| Interior | cozinha do trailer | azulejo off-white até 4,45 + creme acima, friso mostarda, piso em ladrilho (textura já enviada `PaveLight`, sem textura nova), bancadas KayKit AST-019, coifa, faixa de menu |
| Pátio | Pad escuro com borda laranja, 4 mesas | pavers com textura em tile + caminho claro do portão ao balcão, cerca baixa creme/ketchup, arco CORNER DOGS no portão, 4 luminárias-guarda-sol, arbustos BUSH-R |
| Fundos | porta do AST-027 com degrau (saída por teleporte) | porta externa real **DOOR-B** 5 × 8 com chapa de degrau, escotilha de carga com moldura mostarda, lixeiras afastadas |

Leitura geral: de longe continua sendo "o trailer do Corner Dogs" (mesma paleta e silhueta), só que maior; de perto o interior lê como lanchonete. O letreiro sobre o teto domina a esquina como antes.

## 2. Jogabilidade (1–4 jogadores)

- **Paralelismo:** quatro postos sem disputa de corredor: caixa (TAB-1 + persiana, ponta leste da frente), grelha/estoque (fundo oeste), pão/corte (fundo meio), condimentos → PICKUP (corredor leste → frente). Corredores: frente 5,4, fundo 5, passagem leste 6, passagem oeste 4,0 (cafeteira). Antes: um corredor de 2–3 studs atrás de um balcão só.
- **Gargalos:** (a) a passagem oeste (4,0) é o caminho de quem vai à despensa e cruza com a grelha; (b) a mesa de montagem tem 8 pratos a 2,6 entre centros: com 4 jogadores pegando pratos vizinhos os prompts ficam encostados (2,6 > 2,5 do mínimo, mas no limite); (c) só um COND (a grade AST-017 tem 7,2 de largura; a variante de 5 ainda não existe), então condimentos é o posto mais lento.
- **Alcance de prompt no mobile:** todos os prompts do balcão e das estações a ≥ 2,5 entre donos diferentes, exceto os herdados do modo de preparo (`Station_1/3 Prompt_Work` × grelha/pão/cooler, 0,99–2,45; já existiam no trailer) e **cafeteira × disjuntor 2,11** (o dono girou o disjuntor). Pratos com alcance 5–6 sem linha de visão.
- **Entrar e sair:** varredura R6 (caixa 2 × 4,6 × 1, `RespectCanCollide`) em 7 rotas: spawn → passagem oeste → DOOR-P → despensa → DOOR-B → calçada (ida e volta), corredor da frente, passagem leste, corredor do fundo, corredor da despensa, portão → fila → PICKUP: **0 bloqueios**. Portas 5 × 8, folhas abertas rentes à parede, molduras/toldos/persianas sem colisão. Única colisão invisível de propósito: `CounterBarrier` (Y 3–8 na janela) e `DTBarrier` (janela do DT), para ninguém pular o balcão.

## 3. Fluxo do cliente e do jogador

- **Cliente:** calçada → portão (meio da cerca) → caminho claro → fila Q5..Q2 corre para oeste rente ao balcão → Q1 no TAB-1 → faixa do balcão (`N-PU-IN`) → PU-1..4 → mesa (TBL-n pelo corredor do meio) → portão. Q e PU nunca são nós intermediários (`N-PU-IN` ↔ `N-PAD-2`).
- **Jogador:** nasce no corredor da frente (PS-1..4) olhando o balcão; REV-1..4 agora no corredor do fundo (Q-317 em parte, Provisório). Sai pela despensa: DOOR-P → corredor livre X 25,5–32 → **DOOR-B** → chapa de degrau → calçada da Juniper → Mart (DEC-282; ponto `DOOR-B` em (29,5; 81,4)).
- **Reposição:** van para atrás (VAN-STOP ainda no recuo LAY-J da Juniper — ver problemas) → escotilha no lado sul da despensa → DROP-R (caixas DOGS/BUNS/MUSTARD em cima) → corredor da despensa → DOOR-P → corredor do fundo. Não cruza o caminho prato → PICKUP.

## 4. Anomalias vistas pela vitrine

- A janela de 31,8 × 5 abre quase todo o pátio: mesas, luminárias (Hush), portão (Walker em (36; 28)) e a calçada da Ninth ficam no campo de visão do balcão sem girar a câmera (print 02).
- A aba amarela aberta corta o céu acima de Y 8: postes altos (NL-01..04) e janelas altas dos prédios (ANM-006) **não aparecem** da pose do balcão; só abaixando a câmera. Recomendo conferir com raycast das poses PS e, se preciso, inclinar a aba mais para cima.
- O drive-thru (AN-R01) é lido de perto pela janela leste; a placa e a lâmpada não tampam mais o vão.
- A despensa ampliada (AN-R08) tem duas portas abertas e uma escotilha: bom para batidas e "porta que fecha sozinha", mas hoje as folhas são estáticas (sem `Door`/dobradiça animada).

## 5. Sincronização com as edições do dono (2026-10-17)

O modo `diff` do snippet monta tudo numa pasta de rascunho e compara peça a peça com o place. Diferenças achadas e gravadas no bloco `OVERRIDES` do `restaurant_bind.luau` (rodar de novo não desfaz):

- cerca (3 trilhos superiores mais altos/curtos), pilares do portão, ilha e faixa de parada do DT, 2 aparelhos de ar no teto, faixa de menu, neon OPEN/CLOSED movido 4,7, disjuntor girado 180°, alavanca da persiana (TRL-SHUTTER) movida ~6 e girada 90°, tabuleiro da grade de condimentos redimensionado, monitor CCTV movido 28, lixeiras giradas, âncoras do modo de preparo (Station_n, PrepTargets) como estavam.
- peças novas do dono mantidas como estão: `Base` na grade de condimentos, uma 2ª `Floor_Path` no pátio (subida 0,012 para não brigar com a 1ª), o varal agrupado em dois `Model` em `TrailerDeco` (a pasta passa a ser do dono: o snippet não a recria nem compara).
- duas edições substituídas por correção equivalente do gerador: o empurrão de 0,1 no friso `Skin_B_Trim` (o friso agora fica 0,03 saliente) e o giro das lixeiras (que mudaram de lugar por causa da despensa).
- Resultado final: `diff: 0 changed, 0 deleted`.

## 6. Z-fighting

Varredura de faces coplanares sobrepostas (mesma direção, mesmo plano ±0,004, área > 0,01): **97 → 16**. Corrigidos 81: frisos dos 7 trechos de azulejo (os mais visíveis), topo da parede sob o balcão e sob o peitoril do DT, coifa × forro, bancada do fundo e cafeteira × azulejo, trilhos da cerca × pilares do portão, linhas do LAY-J, macacos, moldura e folha das portas, escotilha, tablet do diário (BodyTop), caixas × estantes. Os 16 que sobram são faces escondidas (fundos encostados no chão/parede), caixa envolvente de malha (falso positivo) ou o modelo CCTV do dono.

## 7. Problemas e ajustes recomendados

1. **Boot em Play ainda não testado nesta rodada** (o dono pediu para não mexer mais no Studio): rodar `/dev smoke` e conferir `MapIndex` (regra 4: `Station_n` × estações e cafeteira × disjuntor 2,11 abaixo de 2,5).
2. **COND-2 e CUT-2:** a grade de condimentos AST-017 tem 7,2 de largura; sem a variante de 5 não cabem duas. CUT-2 está como blockout sem tag (`PendingStation`).
3. **Van e escotilha:** a escotilha foi para o lado sul da despensa ampliada; o `VAN-STOP` continua no recuo LAY-J da Juniper, a ~30 studs. Proposta: van entra pela faixa de serviço atrás do trailer (Z 80–84) e para na escotilha; precisa da rota da van (R3) e de DEC.
4. **Porta para fora (DEC-282) muda a regra "jogador não sai":** anomalias que contavam com o jogador sempre dentro (família B, Hide, ANM-028) e o `LZ-1` (proteção) precisam do game-designer; HIDE-P cobre a despensa inteira, inclusive a passagem até a porta aberta.
5. **Aba da persiana e céu:** a aba aberta esconde o alto da rua do balcão (postes do Hush, janelas da ANM-006). Conferir com raycast e, se preciso, aumentar o ângulo de abertura (`ClosedAngle`/pose) ou encurtar a aba.
6. Prep focado (DEC-223) suspenso no restaurante: as âncoras `Station_n`/`PrepTargets` seguem os objetos certos, mas as vistas nunca foram testadas no layout novo.
7. Orçamento: ~490 peças visíveis no conjunto novo (inclui estações clonadas e pacotes nas estantes) contra teto de 450 instâncias novas da ficha; os pacotes AST-011 das estantes (≈ 18) são o primeiro corte se pesar no mobile.
8. Casca em Parts (cantos de cilindro e esfera): leitura certa à distância, mas um modelo AST-140 derivado do AST-027 no Blender (modeler-3d, DEC-281) deixaria os cantos e o beiral contínuos e cortaria ~60 peças.

## 8. Rev. 2 (2026-10-17, 2ª passada no Studio)

**Edições do dono sincronizadas** (`diff` → `OVERRIDES`, depois `diff: 0 changed, 0 deleted`): faixas e ilha do drive-thru com 56,1 de comprimento, trilho leste da cerca (`Rail_E`) no chão, lâmpadas das 4 luminárias de mesa, `TAB-1` redimensionado (tela 1,9 × 1,05, poste, base, luz piloto, âncora `Prompt_Take`), faixa de menu 27,4 × 4,1, disjuntor `TRL-BREAKER` levado para a parede leste externa da despensa, tablet do diário 1 stud para trás, frisos `Skin_E_N/S_Trim`; apagadas: `DT-PC` (monitor e pé), coifa `Hood`, `Floor_Path` do pátio, as 9 rodas/arcos que sobravam; externas: `BIN-1`, `BIN-2` e o monitor CCTV movidos. Peças novas do dono mantidas: `Rail_E` #2..#4, `Patio/Union`, `Base` da grade de condimentos.

**Depósito:** uma baia por chave de `Content.Packages` (9): DOGS, BUNS, KETCHUP, MUSTARD na divisória (de frente para o sul); CHEESE, BACON, POTATO STICKS, CREAM CHEESE na parede sul; COFFEE na parede leste. Placa grande colorida com texto branco contornado, 6 caixas do produto por baia com o nome na face do corredor. Corredor 4,1; a divisória em frente ao `DROP-R` ficou livre. Contrato: Model com tag `StockShelf`, `Package` = chave, `MapId` `STOCK-<NOME>`, Attachment `Prompt_TakeBox` (atributos `Package`, `PromptAction = take_box`) dentro da `Frame`, 0,7 à frente da baia, Y 3,05. As estantes mistas da rev. 1 foram para `TrailerBackup.Retired`.

**Portas:** fechadas por padrão, tag `AutoDoor` no Model (`DOOR-P`, `DOOR-B`), todas as peças da folha com `DoorLeaf = true` (fechadura incluída), `CanCollide = false` no servidor (NPCs), `DoorRadius 7`. `DOOR-P`: dobradiça no lado oeste (`DoorHinge = "Right"`), 75° (aberta para a cozinha não bate no tablet do diário). `DOOR-B`: **porta de correr embutida** (`DoorSlide = -4,9`, entra na parede sul maciça X 32..37): com dobradiça, ou ela cruzava o corredor da despensa (abrindo para dentro) ou a calçada a caminho do Mart (abrindo para fora), e o `DoorController` abre para longe de quem chega, não dá para travar "só para dentro". Varredura R6 com cada folha aberta (as duas direções) e colisão ligada: 0 bloqueios nas 7 rotas.

**Quadro de pedidos:** `TRL/Kitchen/BackCounter/MenuStrip` com `OrderBoard = true`, `OrderBoardFace = "Back"`; face limpa = `Enum.NormalId.Back` (+Z do mundo = norte do MAP, virada para os cozinheiros e para a janela). Aparada para 26,6 × 3,95 (X do MAP 31,0..57,6, Y 4,4..8,35) para não entrar no batente/verga da `DOOR-P`, no poste de canto e no beiral; o texto antigo de preços ficou desligado.

**Z-fighting:** 49 pares (era 16). 34 deles são os fundos dos postes da cerca e do pilar do portão contra o `Rail_E` e a `Union` que o dono baixou até o chão (faces de baixo, invisíveis); os 15 restantes são do conjunto já conhecido (pilotos dos interruptores, cafeteira, CCTV do dono, `LAY-J`, telefone/interruptor no azulejo leste). Nenhum par envolve as baias, as portas ou o quadro desta passada; não mexi nas peças do dono.
