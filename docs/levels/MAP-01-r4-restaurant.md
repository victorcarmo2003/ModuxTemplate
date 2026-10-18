Status: Rascunho

# MAP-01 r4 — Restaurante "Corner Dogs" no lugar do trailer

Autor: level-designer, 2026-10-17 (rev. 2 no mesmo dia: **DEC-280**). Dono único deste arquivo.
Fontes: `docs/source/2026-10-17-restaurante-brief.md` (com o **Adendo 2**: estoque com caixas), esboço `2026-10-17-restaurante-esboco.webp`, vista de cima `2026-10-17-mapa-atual-topo.webp`, caixas `2026-10-17-caixas-estoque.png`; **DEC-269 a DEC-275, DEC-276, DEC-280**; `Q-307`, `Q-308`, `Q-309`, `Q-351`; `design/anomalies-v3-restaurant.md` §0.2 (peças de mapa); `tech/restaurant-flow.md` rev. 2 §3.1 e **§4.1 (binding e pontos legados)**; `levels/MAP-01.md` (rev. 3 + bindings); `art/style-guide.md` (R6, olho 4,5).
Números são valores iniciais (DEC-044). O que não tem `[DEC-###]` é **proposta do level-designer (Provisório)**. Este doc **não edita** o `MAP-01.md`: o secretário concilia no fim da rodada.

**O que a DEC-280 mudou nesta revisão:** 1 tablet só (`TAB-1`, ponta direita do balcão); **sem porta saída** (`DOOR-K` saiu antes de nascer); balcão da frente inteiro, da parede oeste à leste; na ponta esquerda o pote de gorjetas e o ponto de retirada `PICKUP` com a fila lateral `PU-1..4`; fila `Q1..Q5` atrás do tablet; o cliente leva o prato e senta sozinho. **O jogador não sai da loja**: a loja é o ponto seguro, então disjuntor, esconderijo, válvula, interruptor e descarga das caixas ficam **por dentro**.

**Rev. 3 (2026-10-17, TASK-382, DEC-281 e DEC-282, Provisório):** a casca é um **trailer expandido** (dois módulos acoplados com o visual do AST-027), não um prédio. A **despensa foi ampliada** para X 25..50, Z 72..79 (era 9 × 7) e ganhou uma **porta externa `DOOR-B`** no lado sul: o jogador sai pela despensa (DOOR-P → passagem livre X 25,5..32 → DOOR-B → calçada) para ir ao Mart. DOOR-P passa a 5 × 8 (X 25,5..30,5); a escotilha `HATCH-L` e o `DROP-R` foram para o lado sul da despensa (X 44..47). Detalhes e medidas: §5.9; comparação e prints: `docs/tasks/captures/restaurant-comparison.md`.

**Rev. 4 (2026-10-18, TASK-503, DEC-302 a DEC-304, Provisório):** a cozinha volta ao modo focado, agora com **esteira**. A bancada do fundo vira **bancada em dois níveis** (estações em cima, esteira embaixo), a mesa de montagem vira a **mesa central** de 8 vagas onde o prato nasce com o ticket, e o `PICKUP` fica onde está. Tudo na **§16**; ela vale sobre §5.4, §5.5, §6 e §7.1 onde discordarem.

---

## 1. Resumo

| Item | Valor |
|---|---|
| Tema | O trailer sai; no mesmo canto da esquina Ninth & Juniper entra um restaurante pequeno de hot dog (o letreiro **CORNER DOGS** que já está no place vira o letreiro do prédio). Pátio com 4 mesas de piquenique na frente, cozinha "Overcooked" atrás de um balcão corrido, drive-thru pela lateral leste [DEC-269, DEC-280] |
| Função no loop | Único posto de trabalho da run (dia e noite). Rua, Mart, ambulância e lobby seguem iguais |
| Jogadores | 1–4 da party, todos em paralelo [DEC-275] |
| Desbloqueio | Desde o Dia 1 (substitui o trailer único da DEC-224) |
| Câmera / escala | 1ª pessoa, R6 (altura 5, olho 4,5, largura 2), WalkSpeed 16 [DEC-089, DEC-097]. Mobile-first: prompts a ≥ 2,5 entre vizinhos, corredores ≥ 4 |
| Tamanho | Lote **52 × 48** (X 24..76, Z 32..80); prédio **35 × 18** + despensa **9 × 7**; pátio 36 × 22 |

## 2. Convenções e escala

- Coordenadas no **referencial MAP-01** (`MAP-01.md` §2): origem no cruzamento, **+X = leste**, **+Z = sul**, norte = −Z. Piso do pátio e da loja = **Y 0,45** (sem degrau).
- **No place** (mapa girado 180°): ponto `(x, y, z)` daqui = **`(−x, y, 67,887 − z)`** do mundo (`tools/assetplace/map_frame.luau`).
- **Casamento com o Pad real (vista de cima).** O trailer (28 de comprimento) mede ~170 px → **~6 px/stud**. O Pad (borda laranja) mede ~255 × 200 px → **~42 × 33** = o Pad do doc (X 24..64, Z 32..64). Em volta há **ladrilho livre**: ~12 studs a leste (na imagem, à esquerda) e ~16 ao sul (na imagem, acima, até a fileira de prédios). Ao norte, a calçada da Ninth (Z 16..32); a oeste, a calçada leste da Juniper Sul (X 12..24, na imagem à direita). Daí o lote **X 24..76, Z 32..80** sem mexer em prédio. **Medir no place** (`Q-310`).
- **Divergência doc × place:** o `MAP-01.md` diz `TRL` (40, 41); no place o trailer está no pivô de mundo (−44,92; 9,10) (`trailer_only_map.luau`) = **(44,9; 58,8)** aqui, no fundo do Pad, com as 4 mesas xadrez na frente. O r4 usa os limites do lote, não o pivô velho.
- Alturas: **bancadas e balcão 3,0** (precedente DEC-157; `Q-312`), abertura do balcão de 3,0 a 7,0, **pé-direito 10**, telhado ~11,5, letreiro até ~15. Portas internas 3,5 × 7,5.
- ASCII aproximado (±1–2). **As tabelas são a fonte da verdade.**

## 3. Planta (ASCII)

Escala: **1 coluna = 1 stud (X)**, **1 linha = 2 studs (Z)**. Norte para cima. Cada linha começa no Z indicado.

```
  X →  12          24          36          48          60          72
        |           |           |           |           |           |
  24   :::::::::::::::::::::::::::::::::::::::::::::::::^^^^^^^:vvvvvvv::   calçada sul da Ninth; ^ saída DT, v entrada DT
  30   :::::::::::::::::::::::::::::::::::::::::::::::::^^^^^^^:vvvvvvv::   DT-SL-OUT / DT-SL-IN antes da calçada
  32   ::::::::::::ffffffffffGGGGGfffffffffffffffffffff|^^^^^^^|vvvvvvv##   cerca baixa f; R-GATE (pelo meio)
  34   ::::::::::::f.TTTTTTT......TTTTTTT............**|^^^^^^^|vvvvvvv##   TBL-3 (oeste) · TBL-4 (leste)
  36   ::::::::::::f.TTTTTTT......TTTTTTT............**|^^^^^^^|vvvvvvv##   (X 47..54 livre: TBL-5/6 futuras)
  38   ::::::::::::f.................................**|^^^^^^^|vvvvvvv##
  40   ::::::::::::f.TTTTTTT......TTTTTTT............**|^^^^^^^|vvvvvvv##   TBL-1 (oeste, perto da retirada) · TBL-2
  42   ::::::::::::f.TTTTTTT......TTTTTTT............**|^^^^^^^|vvvvvvv##
  44   ::::::::::::f.TTTTTTT......TTTTTTT............**|^^^^^^^|vvvvvvv##
  46   ::::::::::::f.................................**|^^^^^^^|vvvvvvv##   corredor de clientes (Z 46,2..49,6)
  48   ::::::::::::f.................................**|^^^^^^^|vvvvvvv##
  50   ::::::::::::f.....................5..4.3..2...**|^^^^^^^|vvvvvvv##   fila do tablet Q5..Q2 (corre para oeste)
  52   ::::::::::::f...k..k.k..K...................1.**|^^^^^^^|vvvvvvv##   K = PU-1, k = PU-2..4 (empilha à esquerda); 1 = Q1
  54   :::::::::::::Wc$ccccccccPccccccccccccccccLccTccW|^^^^^^^|vvvvvvv##   balcão inteiro: $ pote · P PICKUP · L persiana · T TAB-1
  56   :::::::::::::W..........p...................p..W|CCCCCCC|vvvvvvv##   p = poses do jogador (PICKUP, TAB-1); C = DT-STOP
  58   :::::::::::::W....o..@....@....@....@..........J|CCCCCCC|vvvvvvv##   o = TRL-OUT; @ = PS-1..4; J = DT-WIN (parede leste)
  60   :::::::::::::Wc..............................mPJ|CCCCCCC|vvvvvvv##   c = R-COFFEE; m/P = DT-PC (pose / computador)
  62   :::::::::::::W......AOAAOAAOAOAAOAOAAOAAOA.....J|CCCCCCC|vvvvvvv##   mesa de montagem, O = PLATE-1..8
  64   :::::::::::::Wu.............................r..S|CCCCCCC|vvvvvvv##   u = BIN-K; r = DROP-T; S = KSW (interruptor)
  66   ======:::::::Y.................................F|CCCCCCC|vvvvvvv##   = recuo LAY-J; Y = GAS-1; F = PHONE-R
  68   ==VV==:::::::W....GGGGGGGGSSSBBBXXXXXXMMMMMMMMMW|CCCCCCC|vvvvvvv##   G GRILL-1/2 · S STOCK · B BUN · X CUT-1/2 · M COND-1/2
  70   ==VV==:::::::W....GGGGGGGGSSSBBBXXXXXXMMMMMMMMMW|^^^^^^^|vvvvvvv##   V = DLV-STOP (van de entrega)
  72   ==VV==:::::::WPPPPWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW|^^^^^^^ivvvvvvv##   parede do fundo; PPPP = DOOR-P (despensa, por dentro)
  74   ==VV==:::::::HR......W___________________________~~~~~~~~~~~~~~~##   H = HATCH-L (escotilha de carga); R = DROP-R; ~ retorno DT
  76   ==VV==:::::::H.......W___________________________~~~~~~~~~~~~~~~##   _ = faixa de serviço (canteiro, sem uso)
  78   :::::::::::::WWWWWWWWW___________________________~~~~~~~~~~~~~~~##
  80   xxxxxxxxxxxx######################################################   BAR-S (Z 80); B1 sul
```

Leitura em 3D: quem chega pela calçada vê a cerca baixa com o **portão no meio**, as duas colunas de mesas com luminária, e ao fundo a fachada rosa com **um balcão corrido** de ponta a ponta: o tablet com a fila à direita, o pote e a retirada à esquerda, o letreiro CORNER DOGS em cima. Do lado de dentro a cozinha é **um cômodo** com duas faixas de trabalho (frente e fundo) separadas pela mesa de montagem, e a despensa atrás. Nenhuma porta do prédio dá para fora (DEC-280).

## 4. Zonas nomeadas

| ID | Zona | Limites (X; Z) | Dia | Noite |
|---|---|---|---|---|
| ZR-01 | Pátio (só clientes) | X 24..60; Z 32..54 | chegada pelo meio, fila do tablet, retirada, mesas | luminárias por mesa (`HushOff`); anomalias das mesas |
| ZR-02 | Cozinha | X 25,5..59,5; Z 54,5..71,5 | balcão, montagem, estações, DT | = `LZ-1` (luz pelo KSW); **ponto seguro** [DEC-280] |
| ZR-03 | Despensa / câmara fria (rev. 3: ampliada) | X 25,5..49,5; Z 72..78,5 | caixas chegam aqui (DROP-R); saída DOOR-B | `HideZone` (família B), também segura |
| ZR-04 | Drive-thru (laço leste) | X 61..75,5; Z 16..80 | carros entram e saem pela Ninth, param na janela | ANM-008 e família A no carro |
| ZR-05 | Recuo de carga LAY-J | X 12..18; Z 66..78 (calçada leste da Juniper Sul) | van para aqui | igual |
| ZR-06 | Faixa de serviço | X 34..61; Z 72..80 | canteiro, sem uso (folga do retorno do DT) | escura |

Zona `RST` ("dentro do prédio", ANM-010 / ANM-020) = ZR-02 ∪ ZR-03.

## 5. Pontos-chave (coordenadas)

### 5.1 Prédio (casca)

| ID | O quê | Posição / medidas | Nota |
|---|---|---|---|
| `TRL` (legado) | **Pivô do prédio** (Model com `Vehicle = "trailer"`, restaurant-flow §4.1) | (42,5; 63), Y 0,45, virado para o norte | o prédio herda o pivô do veículo para o boot não quebrar |
| REST | Prédio (externo) | X 25..60, Z 54..72 (**35 × 18**), paredes 0,5, pé-direito 10 | interior X 25,5..59,5, Z 54,5..71,5 (**34 × 17**) |
| PANTRY | Despensa anexa | X 25..34, Z 72..79 (9 × 7) | interior 8 × 5,5; cabem os 4 jogadores escondidos |
| FRONT | Fachada norte = **balcão inteiro** | Z 54..54,5, X 25..60 | abertura de 3,0 a 7,0 de ponta a ponta, montantes a cada ~5,5 só visuais |
| SIGN-CD | Letreiro CORNER DOGS | sobre a fachada, centro (42,5; 54), Y 12–15 | o do place, movido; emissivo à noite |
| R-OPEN-NEON | "OPEN" neon | vidro sobre o pote, (28; 54,2), Y 7,5 | acende com R-OPEN |

### 5.2 Pátio, chegada, fila do tablet, retirada e mesas

| ID | O quê | Posição (X, Z) | Nota |
|---|---|---|---|
| R-GATE | Portão norte ("pelo meio", entre as colunas de mesas) | (36, 32), vão X 33,5..38,5 | único acesso de cliente; arco com LIT-GATE |
| FENCE-R | Cerca baixa | Z 32 (X 24..60) e X 24 (Z 32..54), altura ≤ 3 | sem portão oeste: ninguém da loja sai (DEC-280) |
| BUSH-R | Arbustos (esboço) | X 57,5..60, Z 33..53 | separa o pátio da pista do DT |
| `Q1` (legado) | **Cliente no tablet** | (56,5; 52,6), virado para o sul (balcão) | frente do `TAB-1` |
| `Q2..Q5` (legado) | Fila atrás do tablet | (54; 50,1) · (51,5; 50,1) · (49; 50,1) · (46,5; 50,1) | 2,5 entre vagas; corre para oeste, a cauda Q5 fica na boca do corredor do meio. Tamanho pelo upgrade `counter` |
| `Q1B` (reserva) | Cliente do 2º tablet (upgrade, fora do MVP) | (50; 52,6) | só existe com `TAB-2`; a fila Q2.. continua a mesma |
| `CART` (legado) | Frente do `TAB-1` (Adopt, foco de cutscene) | (56,5; 53,3), virado para o norte | |
| `PU-1` | **Cliente na retirada**, no balcão | (36; 52,6), virado para o sul | ao lado do `PICKUP` |
| `PU-2..4` | Fila de retirada, empilhando à esquerda | (33,5; 52,6) · (31; 52,6) · (28,5; 52,6), virados para o sul | `PickupSlots` 4 (restaurant-flow §3.1). Q1 → PU-k anda pela faixa Z ~52,6 rente ao balcão |
| `TBL-1` | Mesa oeste, fileira de trás | centro (29,5; 43,4), X 26..33, Z 40,6..46,2 | a mais perto da retirada (~9 studs) |
| `TBL-2` | Mesa leste, fileira de trás | centro (42; 43,4), X 38,5..45,5 | |
| `TBL-3` | Mesa oeste, fileira da frente | centro (29,5; 35,8), Z 33..38,6 | |
| `TBL-4` | Mesa leste, fileira da frente | centro (42; 35,8) | |
| `TBL-n/Seat1..4` | Assentos | Seat1/2 banco sul (X centro ∓1,7; Z centro +2,1), Seat3/4 banco norte (Z centro −2,1) | AST-100 6,99 (X) × 3,77 × 5,64 (Z). `SeatTable`, `TableIndex 1..4`, sem `ServeAnchor`/`CleanAnchor` ligados |
| `N-TBL-n` | NpcNode de cada mesa | ponta da mesa voltada para o corredor do meio: TBL-1/3 em (34,5; centro Z), TBL-2/4 em (37,5; centro Z) | o cliente chega e sai pelo corredor do meio |
| TBL-5/6 (reserva) | Mesas futuras (upgrade) | centros (50,5; 35,8) e (50,5; 43,4) | cabem sem mexer na fila. **Cabem 6 mesas; o MVP usa 4** |

Assentos: 4 mesas × 4 = 16 físicos; uso padrão 2 por mesa (`MaxDiners` 2) por causa do teto de NPC (§8.4).

### 5.3 Balcão da frente (de oeste para leste)

Tampo a 3,0, 1,8 de fundo (Z 53,8..55,6, atravessa a parede), X 25,5..59,5. Jogador por dentro em **Z 56,6**; cliente por fora em **Z 52,6** (4,0 através do balcão; alcance de prompt 6).

| ID | Peça | Posição (no tampo) | Pose do jogador | Binding (restaurant-flow §4.1) |
|---|---|---|---|---|
| `TRL-TIPJAR` (legado) | **Pote de gorjetas** (AST-121) [DEC-239, DEC-280] | (27,5; 55), Y 3,0 | (27,5; 56,6) | o existente, movido; `Prompt_Collect` |
| `PICKUP` | **Ponto de retirada** | (36; 54,7), Y 3,1 | (36; 56,6) | `Model` tag `Pickup`, filho `Prompt_Serve` (`PromptAction = pickup_serve`), "Hand Over" tap, raio 6 |
| `TAB-2` (reserva) | 2º tablet (upgrade) | (50; 54,7) | (50; 56,6) | ausente no MVP |
| `SHUT-1` / `Prompt_Shutter` | **Persiana do balcão** (enrolar, cobre a abertura toda) + puxador | puxador (53,5; 55,3), Y 5,5 | (53,5; 56,6) | verbo RECUSAR (DEC-261) a 3 do tablet. Com 1 tablet o "guichê por tablet" (Q-330) vira esta persiana única |
| `TAB-1` | **Tablet** (AST-142), colado na ponta direita [DEC-280] | (56,5; 54,7), Y 3,6 | (56,5; 56,6) | `Model` tag `Tablet`, `TabletIndex = 1`, filho `Prompt_Take` (`PromptAction = tablet_take`), `Att_Screen` |

Distâncias de prompt: pote ↔ PICKUP 8,5; PICKUP ↔ TAB-2 14; TAB-2 ↔ puxador 3,6; puxador ↔ TAB-1 3,4 (alturas diferentes).

### 5.4 Mesa de montagem e pratos-slot

> Rev. 4: a mesa vira a **mesa central** (DEC-303, DEC-304), com as mesmas 8 posições; o uso novo está na §16.5.

| ID | O quê | Posição | Binding |
|---|---|---|---|
| ASM | Mesa de montagem | X 31,5..53,5, Z 61..63,5 (**22 × 2,5**), tampo 3,0 | acesso pelos dois corredores e pelas duas pontas |
| `PLATE-1..8` | Pratos-slot meio transparentes [DEC-271] | Z 62,25, Y 3,05; X **33,4 · 36,0 · 38,6 · 41,2 · 43,8 · 46,4 · 49,0 · 51,6** (2,6 entre centros) | `Part` tag `PlateSlot`, `PlateIndex = n`, `Prompt_Put` / `Prompt_Take`, `Att_Ticket` 2,5 acima (BillboardGui). Alcance 6, sem exigir linha de visão. PLATE-8 (leste) fica no caminho mais curto para a retirada |

### 5.5 Estações do fundo

> **Superada pela §16 (rev. 4, DEC-302).** A tabela abaixo é histórico da rev. 2/3 (ordem do fluxo de mundo F2).

Bancada X 30..59,5, Z 68,5..71,5 (3 de fundo), tampo 3,0. Pose em **Z 67,3**, prompt na borda (Z 68,9; Y 3,3), virado para o sul. Cada estação = `Model` tag `Station` + `StationKind`, dentro do Model `TRL`.

| ID | Estação | X (largura) | Prompt | Nota |
|---|---|---|---|---|
| `GRILL-1` | Grelha de barras (AST-120, 8 vagas) | 30..33,75 | (31,9; 68,9) | DEC-226; coifa KP `extractorhood` |
| `GRILL-2` | Grelha 2 | 34..37,75 | (35,9; 68,9) | pode ser upgrade (game-designer) |
| `STOCK` | Estoque de salsicha (cooler AST-018) | 38,25..40,75 | (39,5; 68,9) | recebe as caixas **DOGS** |
| `BUN` | Caixa de pães (AST-015) | 41,25..43,25 | (42,25; 68,9) | recebe as caixas **BUNS** |
| `CUT-1` | Tábua + faca (AST-014) | 43,5..46,25 | (44,9; 68,9) | |
| `CUT-2` | Tábua 2 | 46,5..49,25 | (47,9; 68,9) | |
| `COND-1` | Condimentos (grade AST-017, 5 de largura) | 49,5..54,5 | (52; 68,9) | recebe as caixas **MUSTARD / KETCHUP / …** |
| `COND-2` | Condimentos 2 | 54,5..59,5 | (57; 68,9) | |
| `DOOR-P` | Porta da despensa (interna, com janelinha) | vão X 26..29,5 na parede do fundo (Z 72) | prompt da tranca `LOCK-P` (27,75; 71,2) Y 4 | fora da bancada (que começa em X 30). Recebe a **tranca de anomalia** que era da porta do trailer (ANM-004/009/030; `Q-308`, `Q-351`) |

### 5.6 Paredes internas e peças de anomalia (tudo por dentro, DEC-280)

| ID | O quê | Posição | Anomalias / nota |
|---|---|---|---|
| R-OPEN | Interruptor OPEN/CLOSED (`open_sign`) | parede oeste (25,7; 56) Y 4,5 | |
| `BRK-K` | **Disjuntor** (era "externo" no anomalies-v3; agora por dentro) | parede oeste (25,7; 58,8) Y 4,5, virado para o leste | ANM-020/035. Fica longe das estações: quem religa larga o posto (o objetivo do anomalies-v3 continua), sem sair |
| R-COFFEE | Cafeteira (AST-022) [DEC-125] | balcãozinho X 25,5..27,3, Z 60,2..62,4; prompt (26,6; 61,3) Y 3,5 | |
| `BIN-K` | Lixeira da cozinha (AST-025) | (26,4; 64,2), chão | ponta oeste da montagem |
| `GAS-1` | **Válvula de gás** das grelhas | parede oeste (25,7; 67) Y 4,5 | ~6 de GRILL-1; uma para as duas grelhas (ANM-025) |
| `KSW` | **Interruptor da cozinha** (`LZ-1`) [DEC-189] | parede leste (59,3; 64,2) Y 4,5 | "ao lado da montagem" (ponta leste); ANM-003, 2ª chave da ANM-035 |
| `PHONE-R` | **Telefone fixo**: chefe [DEC-124] **e pedido de reposição** [DEC-276] | parede leste (59,3; 67) Y 4,5 | 2,8 do KSW; 3,2 do COND-2 |
| `HIDE-P` | `HideZone` da despensa | volume X 25,5..49,5, Z 72,5..78,5 (rev. 3) | família B (ANM-007, 017, 018, 019) |
| `LIT-T1..4` | Luminária por mesa | centros de TBL-1..4, Y 8 | `HushOff`, ordem da rua para o prédio: LIT-GATE → LIT-T3/T4 → LIT-T1/T2 |
| `PS-1..4` = `PS-N1..4` (legado) | Spawn dos jogadores (dia, noite, reconexão, atrasado) | (33; 58,5) · (38; 58,5) · (43; 58,5) · (48; 58,5), Y 0,45, virados para o norte | corredor da frente, olhando o balcão |
| `TRL-OUT` (legado) | "Pouso" de quem sai do preparo / do trailer | (30; 59), dentro da loja | não há saída (restaurant-flow §4.1) |
| `DROP-T` (legado) | Itens do espectador | (56; 64,5), chão | ≥ 2,5 de qualquer prompt |
| `AN-05` (legado) | Âncora "porta dos fundos" | janelinha da DOOR-P, (27,75; 71,8) Y 6, por dentro | batidas ANM-009 (agora na porta da despensa ou na escotilha) |
| `REV-1..4` (lido como restaurante, DEC-122) | Acordar depois da noite perdida / reviver | **rev. 3 (Provisório):** dentro do trailer, corredor do fundo (33 · 38 · 43 · 48; 65,9), virados para o norte | a ambulância continua em AMB-P (44; 13); a equipe entra pela `DOOR-B` (`Q-317` resolvida em parte) |

Larguras com essas peças: passagem oeste X 25,5..31,5 com 1,8 ocupados → **4,2 livres**.

### 5.7 Drive-thru (laço só na lateral leste)

Entra e sai pela Ninth, não cruza o pátio. Carro do DT = NPC de roteiro [DEC-274], 8 studs/s.

| ID | O quê | Posição | Nota |
|---|---|---|---|
| `DT-IN` | Entrada (Ninth EB vira à direita) | boca X 69..75,5, Z 16 | sem cruzar contramão |
| DT-SL-IN / DT-SL-OUT | Linhas de parada antes da calçada | Z 15 / Z 31 (entrando), Z 33 (saindo) | para se há pedestre na calçada |
| LANE-DT-S | Faixa de descida (fila) | X 69..75,5, centro 72,25 | ilha X 67,5..69 com `DT-MENU` (68,2; 44) |
| DTQ-1..3 | Vagas da fila de carros | (72,25; 66) · (72,25; 52) · (72,25; 38) | 14 entre vagas |
| DT-UTURN | Retorno | X 61..75,5, Z 72..80 | atrás do prédio, invisível do pátio |
| LANE-DT-N | Faixa de subida (janela) | X 61..67,5, centro 64,25 | motorista do lado oeste = lado da janela |
| `DT-STOP` | **Carro na janela** | centro (64,25; 63), virado para o norte | janela do motorista ≈ (61,4; 61,5) |
| `DT-WIN` + `SHUT-DT` | Janela + persiana | parede leste X 60, vão Z 59..63, peitoril 3,0, topo 7,0; puxador (59,2; 61) Y 6,3 | âncora `drive_serve`; persiana para ANM-008 e família A no carro |
| `DT-PC` | **Computador** | peitoril (59,2; 61) Y 3,4; pose `DT-PC-P` (57,2; 61), virado para o leste | `Model` tag `Tablet`, `TabletIndex = 5`. 4,9 da pose do TAB-1: o caixa cobre os dois |
| `DT-OUT` | Saída (direita para a Ninth EB → E-OUT) | boca X 61..67,5, Z 16 | |
| TR-DT | Rota | W-IN → Ninth EB → DT-IN → DTQ-3..1 → DT-UTURN → DT-STOP → DT-OUT → (SL-3W) → E-OUT | nasce e some fora de vista |

Capacidade: **1 na janela + 3 na fila**. Quem desiste segue o laço sem parar.

### 5.8 Reposição por caixas (Adendo 2, DEC-276) — sem o jogador sair

| ID | O quê | Posição | Nota |
|---|---|---|---|
| `PHONE-R` | Pedido | §5.6 | |
| LAY-J | Recuo de carga | X 12..18, Z 66..78 (na calçada leste da Juniper Sul) | sobra calçada X 18..24 para pedestre/ladrão |
| `DLV-STOP` | **Parada da van** | centro (15; 72), virada para o norte, porta lateral para o leste | 7 studs da escotilha |
| DLV-IN / DLV-OUT | Rota da van | JS-IN (6, 116) → Juniper NB → LAY-J → DLV-STOP → NB → cruzamento → JN-OUT (ou direita → E-OUT) | **não toca o laço do DT nem o pátio**; nasce e some fora de vista |
| `HATCH-L` | **Escotilha de carga** na parede oeste da despensa | vão X 25, Z 74..77, peitoril 3,0, abertura 3 × 2,5 | o entregador empurra as caixas **para dentro**; abre só na descarga (6–8 s). Jogador não passa por ela |
| `DROP-R` | **Ponto de descarga** (prateleira/pallet) | dentro da despensa, (26,5; 75), tampo 3,0 colado à escotilha | aparecem as caixas DOGS, BUNS, MUSTARD… (as que já estão no place) |
| BOX-ROUTE | Caixa → estação | DROP-R → DOOR-P (27,75; 72) → corredor do fundo (Z 66–67) → STOCK / BUN / COND-n | **só corredor do fundo**: não cruza o corredor da frente, o caminho prato → PICKUP nem o balcão |

### 5.9 Despensa ampliada e saída pelos fundos (rev. 3, DEC-282, Provisório)

| ID | O quê | Posição / medidas | Nota |
|---|---|---|---|
| PANTRY | Módulo de trás (mesma altura da cozinha, cantos arredondados) | X 25..50, Z 72..79; interior X 25,5..49,5, Z 72..78,5 | a área verde do dono (até as lixeiras), lixeiras `P2` movidas para Z 83 (X 56 · 63,4) |
| `DOOR-P` | Porta cozinha → despensa | vão X 25,5..30,5, Y 0,45..8,45 (**5 × 8**) | folha aberta rente à parede do lado da despensa, sem colisão; fechadura `LOCK-P` faz parte da folha |
| `DOOR-B` | **Porta externa** despensa → calçada | vão X 27..32 na parede sul (Z 79), **5 × 8**; chapa de degrau X 26,8..32,2, Z 79..80,7 | folha aberta rente à parede de fora; placa "EXIT · MART" por dentro; MapPoint `DOOR-B` (29,5; 81,4), sem nó de NPC |
| Passagem | DOOR-P → DOOR-B | faixa livre X 25,5..32 | conferida com varredura R6 (`restaurant_walk_check.luau`): 0 bloqueios |
| `HATCH-L` | Escotilha de carga | parede sul, vão X 44..47, Y 3..5,5 | tampa fechada; a van ainda está no LAY-J (proposta: faixa de serviço Z 80–84, R3) |
| `DROP-R` | Pallet sob a escotilha | X 43,2..48,2, Z 76,6..78,4, tampo 3,0 | caixas DOGS / BUNS / MUSTARD em cima (uma empilhada); `HatchSpot1..3` |
| Estantes | 5 unidades com caixas e pacotes AST-011 | Shelf_N1/N2 na divisória (Z 72,06..73,24), Shelf_E1 na parede leste, Shelf_S1/S2 na parede sul (Z 77,26..78,44) | corredor ≥ 4 (73,24..77,26) |

## 6. Distâncias e tempos (16 studs/s)

| Trecho | Distância | Tempo |
|---|---|---|
| STOCK → GRILL-2 / GRILL-1 | 3,6 / 7,6 | 0,2 / 0,5 s |
| GRILL-n → PLATE-1 / PLATE-8 | 3–4 / 16–20 | 0,2 / 1,2 s |
| BUN → CUT-1 / CUT-2 | 2,7 / 5,7 | 0,2 / 0,4 s |
| CUT-n → prato | 2,7–14 | 0,2–0,9 s |
| Prato → COND-1 / COND-2 | 3–20 | 0,2–1,3 s |
| COND-1 → PICKUP (corredor leste, frente) | ~26 | 1,6 s |
| COND-2 → DT-WIN (corredor leste) | ~7 | 0,4 s |
| TAB-1 ↔ DT-PC (poses) | 4,9 | 0,3 s |
| DROP-R → STOCK / BUN / COND-1 / COND-2 | 21 / 23 / 31 / 36 | 1,3–2,3 s (com caixa, o game-designer define se anda mais devagar) |
| Qualquer ponto da cozinha → despensa (HIDE-P) | ≤ 38 | ≤ 2,4 s |
| Cliente: Q1 → PU-4 / PU-1 → TBL-1 / → TBL-4 | 28 / 9 / 20 | a 13 studs/s: 2,2 / 0,7 / 1,5 s |

## 7. Fluxo de jogadores e papéis

### 7.1 Papéis (1–4 jogadores) e onde cada um fica

| Papel (DEC-275, DEC-280) | Onde | Corredor | Cruza com |
|---|---|---|---|
| Caixa: TAB-1 + persiana + DT-PC | ponta leste do corredor da frente | frente (Z 55,6..61, **5,4**) | o entregador, só na ponta leste |
| Grelha | GRILL-1/2 + STOCK (X 30..41) | fundo (Z 63,5..68,5, **5**) | quem traz caixa de salsicha |
| Pão / corte | BUN + CUT-1/2 (X 41..49) | fundo | ninguém |
| Condimentos + entrega na retirada | COND-1/2 → corredor leste → frente → PICKUP | leste (X 53,5..59,5, **6**) → frente | o caixa (passa atrás dele) |
| Drive-thru | COND-2 → DT-WIN | leste | ninguém |
| Reposição (qualquer um, quando chega a van) | DROP-R → DOOR-P → fundo | oeste/fundo | só a grelha |

Corredores **≥ 4**, portas internas 3,5. Colisão jogador-jogador desligada (DEC-175): o desenho evita **disputa de prompt** (≥ 2,5 entre vizinhos, duas de cada estação lenta).

Com o fim da porta saída, o atrito da rev. 1 (prato cruzando a cozinha para a porta oeste) **acabou**: o prato pronto vai pelo corredor leste até o balcão; as caixas entram pelo canto oposto (oeste/fundo). O único cruzamento é o entregador passando atrás do caixa.

**Solo:** tudo a ≤ 2 s; o DT fica a 0,4 s dos condimentos e a 0,3 s do tablet.

### 7.2 Ao chegar, onde vende, onde melhora, para onde vai

1. Abertura curta (DEC-225) termina no P-01; fade → PS-1..4 dentro da loja, olhando o balcão.
2. R-OPEN. Clientes entram pelo R-GATE, fazem fila (Q5 → Q1), pedem no TAB-1 (mini-diálogo, nota montada item a item, DEC-270), vão para a retirada PU-k.
3. Pedido cai num PLATE-n (DEC-271); montagem por estações (DEC-272); "Hand Over" no PICKUP; o cliente leva o prato, senta, come, sai (DEC-280).
4. Faltou estoque: PHONE-R → van → HATCH-L → DROP-R → caixas às estações (DEC-276), sem sair.
5. Upgrades: hoje a compra é no Gear Stand do Mart, lá fora. Com a loja fechada, ver `Q-317`.

## 8. NPCs

### 8.1 Cliente (chegar → fila → tablet → retirada → mesa → sair)

| Etapa | Rota | Nota |
|---|---|---|
| Spawn | portas D1 (88,6; 31), DR-APT (32; −31); ponta SP-S (21; 100) | regra "nunca aparece/some à vista" (MAP-01 §9.8) inalterada |
| Chegada | D1 → LANE-E (Z ~27) para oeste → cruza as bocas do DT com reserva → R-GATE → corredor do meio → Q5. SP-S → calçada X 18 → N-Z02-02 → LANE-E → R-GATE. DR-APT → CW-4 → LANE-E → R-GATE | D1 → Q5 ~60 (4,6 s a 13); SP-S ~100 (7,7 s); DR-APT ~88 (6,8 s) |
| Pedido | Q5 → … → Q1 (vaga a vaga) | só Q1 tem prompt |
| Retirada | Q1 → faixa Z 52,6 → PU-k (último livre) → anda até PU-1 | retirada cheia = "Take Order" recusado (`pickup_full`) |
| Servido | PU-1 → corredor → N-TBL-n → assento → come | sem mesa livre: sai levando o prato (`TakeawayWhenNoTable`) |
| Saída | assento → corredor do meio → R-GATE → LANE-E → EX-E (60%) / D1 (40%) | |

Regra do grafo: **nó Q ou PU nunca é ponto intermediário**. Q5 e PU-4 (caudas) ligam ao corredor; Q1 liga a PU-4..1 pela faixa do balcão (nó `N-PU-IN` em (40; 52,6)).

### 8.2 Carro do drive-thru e pets

Nasce em W-IN, some em E-OUT. Espera longa: buzina, estresse, segue o laço (DEC-274). **Pets** (`Q-316`): proposta = aparecem na janela do carro em DT-STOP (sem andar; não há calçada no laço).

### 8.3 Van de entrega

Nasce em JS-IN, some em JN-OUT/E-OUT. Para 6–8 s em DLV-STOP. Motorista silhueta; o "entregador" é efeito (caixas deslizam pela escotilha). Fora do teto de NPC (veículo).

### 8.4 Teto de NPCs [DEC-045 = 12]

| Turno | Fila Q | Retirada PU | Sentados | Passantes | Anomalias | Total |
|---|---|---|---|---|---|---|
| Dia | ≤ 3 | ≤ 2 | ≤ 5 | ≤ 2 | 0 | 12 |
| Noite | ≤ 2 | ≤ 2 | ≤ 5 | 0 | ≤ 3 | 12 |

Os pontos físicos permitem mais (Q 5 + PU 4 + 8 sentados). Proposta em `Q-315`.

## 9. Luz

| ID | Volume / luz | Onde | Condição |
|---|---|---|---|
| `LZ-1` (legado) | Cozinha = "dentro" (proteção e luz) | ZR-02 | KSW ligado |
| `LZ-2` (legado, reapontado) | Frente do balcão (Q1 e retirada) | X 25..60, Z 50..54 | KSW ligado |
| `LZ-3` (legado, reapontado) | Luz do pátio (o upgrade "Trailer Lights" vira cordão sobre as mesas) | centro (36; 41), raio 18 | upgrade + KSW |
| LZ-P | Despensa | ZR-03 | sempre (lâmpada fraca) |
| LIT-T1..4, LIT-GATE | Luminárias das mesas e do portão | §5.6, (36; 32,5) Y 7 | `HushOff` |
| LIT-DT | Sobre a janela do DT, por fora | (60,5; 61) Y 8 | |

Orçamento: 3 cozinha + 1 despensa + 5 pátio + 1 DT = **10 locais** (teto 18); sombra só em 2.

## 10. Pontos de anomalia (boa leitura)

| ID | Ponto | Visto de | Serve a |
|---|---|---|---|
| AN-R01 | **Janela do drive-thru** (motorista, carro vazio, pets, rosto que sobe) | DT-PC-P, a 2 studs, leitura privada | família A no carro, ANM-008 (farol), 018, 031, 032 |
| AN-R02 | **Balcão / vidro da frente** (Q1, retirada, persiana) | todo o corredor da frente | família A no tablet, ANM-006 (até o balcão), 007 (Walker até o vidro), 017 |
| AN-R03 | **Fila de retirada** (cliente que não pega o prato, cópia na PU) | PICKUP | ANM-004 (cópia vem para a retirada) |
| AN-R04 | **Mesas à noite** TBL-1..4 + LIT-T (todas olham, lugar extra, luminária que apaga) | balcão inteiro | ANM-005, 010, 016, 030 |
| AN-R05 | **Portão** R-GATE (figura que para e não entra) | balcão, reto pelo corredor do meio (~22) | fim de rota do Walker: `WALKER-10` movido para (36; 28) (`Q-319`) |
| AN-R06 | **Fila de carros** e DT-MENU (faróis parados) | janela do DT e pátio entre os arbustos | ANM-031/032 |
| AN-R07 | **Telhado** (passos), descida pela fachada até o balcão | som na cozinha; descida vista pelo vidro | ANM-019 (TASK-484: a caminhada é posta sobre cada jogador pelo client, sem MapPoint; a queda usa o vidro à frente dele) |
| AN-R08 | **Despensa**: DOOR-P (tranca, janelinha) e HATCH-L (batidas, abre sozinha) | corredor do fundo | ANM-009, 004 (tranca), sustos D |
| AN-R09 | **Grelhas** + GAS-1 | corredor do fundo | ANM-025 |
| AN-R10 | **Arbustos** BUSH-R (olhos) | balcão, ponta do tablet | sustos D |
| AN-R11 | **Disjuntor** BRK-K (vulto no vidro atrás de quem religa) | parede oeste | ANM-020, 035 |

Peças do anomalies-v3 §0.2 que **perdem o sentido** com o jogador sempre dentro e ficam para o game-designer (`Q-351`): ANM-028 "trancado lá fora", `LIT-OUT`, disjuntor externo (virou BRK-K), tranca na porta saída (virou DOOR-P), guichê por tablet (virou SHUT-1).

## 11. O que sai, o que fica, o que é reapontado

### 11.1 Pontos legados mantidos e reapontados (restaurant-flow §4.1: o boot falha sem eles)

| ID | Antes (trailer) | Agora |
|---|---|---|
| `TRL` | pivô do trailer | pivô do prédio (42,5; 63) |
| `CART` | frente da janela | frente do TAB-1 (56,5; 53,3) |
| `Q1..Q5` | fila da janela | fila do tablet (§5.2) |
| `PS-1..4`, `PS-N1..4` | dentro do trailer | corredor da frente (§5.6) |
| `DROP-T` | canto do trailer | (56; 64,5) |
| `L3` | espreita do ladrão a leste do trailer | (52; 29) na calçada, em frente aos arbustos (ladrão: `Q-318`) |
| `AN-05` | janelinha da porta dos fundos | janelinha da DOOR-P |
| `TRL-OUT` | pouso na faixa oeste | pouso dentro, (30; 59) |
| `LZ-1` / `LZ-2` / `LZ-3` | trailer / varanda / Trailer Lights | §9 |
| `TBL-1..4` + `SeatTable` | mesas na frente do trailer | §5.2 |
| `Prompt_Shutter` + persiana | aba da janela | SHUT-1 do balcão |
| `TRL-TIPJAR` | pote no balcão do trailer | ponta esquerda do balcão |

Novos obrigatórios: `TAB-1`, `PICKUP`, `PU-1..4`. Novos opcionais: `TAB-2`/`Q1B`, `DT-*`, `PLATE-1..8`, estações.

### 11.2 Sai (obsoletos; IDs não reaproveitados)

- Casca do trailer AST-027 no mapa (a ficha fica, DEC-269), varais presos a ele, `Body.Shelf_Fold`, `Awning`, `TRL-SWITCH` (→ KSW), `TRL-SHUTTER` (→ `Prompt_Shutter` do SHUT-1), `TRL-DRAWER`/`DRAWER` (sem substituto), `OPEN` do Pad (→ R-OPEN), `BIN-C` (→ BIN-K), marcas `Qn_AST-019_QueueMark` velhas (as novas vão para Q1..Q5), `N-PAD-1..3`, mesas `TBL-5` do Pad e `TTBL-6..9`, `PadFloor`, `PadDecor` (as plantas viram BUSH-R), `Focus_n`/`Station_n`/`CamAnchor_*` do trailer (se a `Q-307` mantiver vista focada, as âncoras vão para dentro de cada Model de estação).
- **Desta mesma rodada, nascidos e obsoletos (rev. 1):** `TAB-2..4` como linha de 4 (TAB-2 volta só como reserva de upgrade), `TAB-n-C/P`, `WAIT-1..5`, `DOOR-K`, `DOOR-K-IN/OUT`, `LOCK-K`, `LIT-OUT`, `BRK-OUT`, `R-GATE-W`, `RTBL-*`, `N-RT-*`, `RS-1..4`, `R-DROP`, `R-TIPJAR`, `DOOR-L`, `SHUT-T1..4`.
- Já obsoletos (DEC-224): `TRL-SALE`, `SIGN-T`, `Prompt_Buy`, `H1..H4`, `Pad.CART`.

### 11.3 Fica

Ruas, trânsito TR-1..TR-10 (+ TR-DT, + rota da van), CW-1..4, PARE, BAR-*, Mart + Gear Stand + Opal + SS, Bellmoor Savings (C-01, WV), lavanderia, B1 (sem mexer, se `Q-310` confirmar), D1, DR-APT, SP-S, EX-E, AS-1..4, postes NL-01..04 e P-01, ambulância (AMB-P em frente ao restaurante), SPEC-P (reapontar para o pátio), AN-12, caminhão, lobby. `WALKER-10` (mesmo papel) vai para (36; 28).

## 12. Assets

### 12.1 Reaproveita

| Peça | Asset | Medidas |
|---|---|---|
| Mesas | `AST-100_PicnicTable` × 4 (CC-BY 3.0 J-Toastie, crédito já em `credits.md`) | 6,99 × 3,77 × 5,64 |
| Arbustos | `AST-100_PlanterBushes` × 4 | 5,2 × 2,46 × 1,68 |
| Estações | AST-120 × 2, AST-018, AST-015, AST-014 × 2, AST-017 × 2 (variante de 5 de largura), AST-025, AST-022 | |
| Pote | AST-121 (`TRL-TIPJAR`) | |
| Persianas | AST-103 (porta de enrolar) como base: 34 × 4 (balcão), 4 × 4 (DT) | |
| Letreiro / caixas | CORNER DOGS e as caixas DOGS / BUNS / MUSTARD do place | caixa ~2 × 1,6 × 2 |
| Kit | KitchenPack: `wall*`, `wall_orderwindow` (base do balcão), `door_A` (DOOR-P), `kitchencounter_*`, `kitchencabinet*`, `extractorhood`, `shelf_papertowel`, `plate` (base do prato-slot), `menu`; AST-093 (linhas de parada) | |
| Telefone | o do trailer (DEC-124) | |

### 12.2 Novo (AST-140..AST-156; fichas em `art/asset-list.md`)

Renumerado pela TASK-395 (art-director, 2026-10-17): a reserva AST-123..139 da rev. 2 colidia com as skins (AST-123/124, TASK-373). Mesma ordem, +17; AST-125..139 ficam queimados (não usar). Origem: P = reaproveita pack/asset do place com edição, N = modelagem nova.

| AST | Asset | Medidas (studs) | Origem |
|---|---|---|---|
| AST-140 | Casca do restaurante (paredes rosadas, platibanda, telhado, piso claro) + despensa | 35 × 18 × 11,5; despensa 9 × 7 | P (KP `wall*`/`pillar_A`; platibanda e telhado N) |
| AST-141 | Balcão corrido com abertura e montantes | 34 × 3,0 (tampo) × 1,8; abertura Y 3..7 | P (KP `kitchencounter_*`, `pillar_B`) |
| AST-142 | Tablet em suporte giratório | tela 0,9 × 0,65 (face ≥ 0,8 × 0,6), 1,2 sobre o tampo | N |
| AST-143 | Ponto de retirada PICKUP (bandeja/campainha + placa "PICK UP") | 2 × 0,6 × 1,5 | P (placa AST-106; bandeja e campainha N) |
| AST-144 | Mesa de montagem inox com 8 marcas | 22 × 3,0 × 2,5 | P (KP `kitchencounter_straight_A`, AST-019 `QueueMark`) |
| AST-145 | Prato-slot meio transparente (vazio / com pedido) | Ø 2,0 × 0,15 | P (KP `plate`) |
| AST-146 | Janela do drive-thru + placa "DRIVE-THRU" | vão 4 × 4, peitoril 4 × 1 | P (KP `wall_orderwindow`, AST-103, AST-106) |
| AST-147 | Computador do drive-thru (monitor + headset) | 1,2 × 1,0 × 0,8 | P (POS do AST-020; headset N) |
| AST-148 | Kit da pista DT (meio-fio, ilha, setas, `DT-MENU`) | menu 3 × 6 × 0,5 | P (CityKitRoads, AST-032, AST-093) |
| AST-149 | Cerca baixa do pátio + arco do portão | módulos 4 × 2,5; arco 5 × 7 | P (CS `fence-low`, KP `pillar_A`) |
| AST-150 | Luminária de mesa (guarda-sol com lâmpada) | poste Ø 0,2, Y 8, copa Ø 5 | P (CC `detail-parasol-b`; lâmpada N) |
| AST-151 | Disjuntor de parede (caixa com alavanca) | 1,2 × 1,6 × 0,4 | P (alavanca do AST-039; caixa N) |
| AST-152 | Válvula de gás de parede | volante Ø 0,8 | N |
| AST-153 | Interruptor de parede (KSW e OPEN) | 0,6 × 0,9 × 0,15 | P (= AST-039, sem mexer) |
| AST-154 | Van de entrega (porta lateral) | ~12 × 6 × 7 | P (AST-035 `CarVan`) |
| AST-155 | Despensa: estantes, porta com janelinha e tranca, **escotilha de carga** com tampa | estantes 4 × 6 × 1,5; escotilha 3 × 2,5 | P (MM `shelf-boxes`, KP `door_A`/`crate`; escotilha e tranca N) |
| AST-156 | Pisos: ladrilho da cozinha, pavers do pátio, faixa da pista | sem atlas novo (style guide §9.2) | P (KP `floor_kitchen`, AST-032, Parts) |

## 13. Requisitos técnicos

- **NPCs:** teto 12 (§8.4, `Q-315`); carros do DT ≤ 4 e van ≤ 1 fora do teto.
- **Streaming:** mesmo bloco do Pad; um cômodo + despensa, sem streaming à parte.
- **Prompts:** ≥ 2,5 entre vizinhos (conferido nas tabelas); pratos com alcance 6 sem linha de visão.
- **Binding:** tag + atributo decidem, nome = ID deste doc (restaurant-flow §4.1). Prédio = Model `TRL` com `Vehicle = "trailer"`; estações dentro dele. Luminárias `HushOff` + `Order`; `HideZone` HIDE-P; `AnomalyAnchor` + `AnchorId` = AN-R##. Snippet novo, idempotente, sem `Place.run` (AGENT-BRIEF §3); `check_map01` + `/dev smoke` antes de entregar.
- **Colisão:** o prédio é fechado para jogador (balcão com parede invisível de Y 3 a 7 só para personagem, para ninguém pular pelo balcão); NPC nunca entra.

## 14. Critérios de aceite do layout

1. Do R-GATE, olhando para o sul, vê-se o balcão inteiro (pote, retirada, tablet) sem girar a câmera (FOV 70).
2. Corredores ≥ 4; portas internas 3,5.
3. **Nenhum fluxo normal exige sair** (DEC-280): pedido, montagem, entrega, DT, reposição, esconderijo, disjuntor, válvula e interruptor estão dentro.
4. A rota da caixa não cruza o caminho prato → PICKUP; a van não cruza o laço do DT nem o pátio; o DT não cruza o pátio.
5. Spawn/despawn de NPC continua em porta ou ponta fora de vista (`check_map01` regra 13 com os pontos novos).
6. Todos os pontos legados da tabela §11.1 existem no place.

## 15. Perguntas abertas (o secretário consolida)

| ID | Pergunta | Recomendação (Provisória) |
|---|---|---|
| Q-310 | **Lote real:** o place tem piso livre até X ~76 (face de B1) e Z ~80 (fundo)? A vista de cima sugere que sim (±3) | Medir com snippet. Se o leste tiver < 15 livres, o DT vira faixa única que entra pela Juniper por trás do prédio e sai na Ninth (a van passa para a Ninth) |
| Q-311 | Fila do tablet: corre para **oeste** rente ao balcão (Q5 na boca do corredor do meio) ou para o **norte** ao lado dos arbustos? | Oeste: a cauda fica onde o cliente chega "pelo meio" e libera o lado leste para TBL-5/6 |
| Q-312 | Altura do balcão e bancadas: 3,0, 3,5 (style guide) ou 2,6 (trailer)? | 3,0 (DEC-157) |
| Q-313 | Mesas: 4 no MVP e TBL-5/6 como upgrade no lado leste? | Sim |
| Q-314 | Barreira invisível sobre o balcão (Y 3..7) para o jogador não pular para fora e o cliente não entrar | Sim, só para personagens; o prato passa pelo prompt |
| Q-315 | Teto de NPCs: 12 (clientes ≤ 10 de dia / ≤ 9 à noite) ou 14 com clientes sentados ancorados? | 12 no lançamento |
| Q-316 | Pets do carro: só na janela ou saem andando? | Só na janela |
| Q-317 | **Sem porta para fora**, como o jogador vai ao Mart / Gear Stand, e onde acorda (REV) e é recolhido pela ambulância? | **Resolvida em parte (rev. 3, DEC-282, Provisório):** saída pela `DOOR-B` da despensa até a calçada e o Mart; REV-1..4 dentro do trailer (corredor do fundo); a ambulância chega pela `DOOR-B`. Falta: regras de anomalia com a porta aberta (família B, Hide, ANM-028) e a rota da equipe da ambulância |
| Q-318 | Ladrão de dia sem gaveta e sem jogador fora: alvo vira o pote (ponta esquerda, visto pelo vidro) ou sai? | Sai na 1ª versão; `L3` fica só como ponto legado |
| Q-319 | Walker / postes: a "janela" agora é o vidro do balcão (Z 54). Mover `WALKER-10` para (36; 28) e reconferir NL-01..04 com raycast das poses do balcão? | Sim; se B1 tapar NL-01, puxar a fileira 10 studs para oeste |

---

## 16. Cozinha com esteira: bancada em dois níveis, esteira e mesa central (rev. 4, TASK-503)

Fontes: **DEC-302** (modo focado volta com esteira; grelha + mesa de descanso à esquerda, tábua e pão no meio, condimentos à
direita; estações numa bancada mais alta, prato embaixo na esteira), **DEC-303** (foco por jogador, até 2 pratos na esteira,
1 prato por estação e o 2º espera ao lado, grelha focada, mesa central de 8 vagas com ticket), **DEC-304** (o prato vazio nasce
na mesa central com o ticket; a mesa é o início e o fim). Medidas das peças: fichas **AST-157 a AST-163** (`art/asset-list.md`,
TASK-523). Posições atuais lidas em `tools/assetplace/restaurant_bind.luau` (CLONES l. 1004-1020, PICKUP l. 1621-1654,
ASM/PLATE l. 1656-1701, BackCounter l. 1703-1733) e nas edições à mão do dono no topo do mesmo arquivo.
**Tudo nesta seção é Provisório** (proposta do level-designer), menos o que cita DEC. Nomes de âncora conferidos com as fichas
da TASK-523 e com o contrato `tech/prep-conveyor.md` (TASK-512) e o `Content` da TASK-513 (§16.10). O mundo da referência de
mecânica não entra: nenhuma forma, nome ou tela copiada.

> **Rev. 4.1 (game-designer, 2026-10-18):** alinhada com a **DEC-305** (dois prompts, `Prompt_Grill` passa a valer, fileira de
> 8, descanso de 8), o contrato da TASK-512 e o `Content` da TASK-513 (divergências D-1 a D-14 de `tests/kitchen-redesign.md`
> §17): prompts, raios, holds, alcance do clique, `Prompt_Take` fixo na vaga e a regra do solo. Posições e medidas não mudaram.

### 16.1 Qual é a "esquerda" (conferido)

- O cozinheiro na bancada do fundo fica no corredor do fundo **olhando para o sul** (+Z do MAP). Olhando para o sul, a **esquerda
  é o leste (X maior)** e a **direita é o oeste (X menor)**.
- A câmera do foco (§16.6) também fica ao norte da bancada olhando para o sul. Então **a esquerda da tela = a esquerda do
  cozinheiro = leste**. Não há ambiguidade entre os dois pontos de vista.
- Confere com a fala do dono na DEC-301: "condimentos lá na esquerda" quando o `COND-1` estava em X 54,6 (leste).
- Marcos para o dono: **esquerda = lado do tablet e da janela do drive-thru (parede leste)**; **direita = lado da porta da
  despensa e do `PICKUP` (oeste)**.
- No place (mapa girado 180°, §2) o leste do MAP é o −X do mundo. A rotação de 180° não espelha nada: esquerda e direita
  continuam as mesmas para quem está dentro.
- **Atenção na planta da §16.3:** ela tem o norte para cima, então a esquerda do cozinheiro aparece à **direita do desenho** e o
  prato anda para a esquerda do desenho (`<`). A vista da §16.4 é a do cozinheiro, e nela o prato anda da esquerda para a direita
  (`>`).

Fluxo de um pedido, de leste para oeste: o prato entra na esteira pela ponta da grelha, passa pelo descanso, pelo pão e pelos
condimentos, e sai na ponta oeste, a ~4 studs da mesa central e a ~21 do `PICKUP`, sem voltar a um X já passado.

### 16.2 Profundidade: o conflito do AST-158 e a resolução

A bancada do AST-158 tem **4,4 de fundo** (deck baixo da esteira 1,6 + prateleira alta 2,8). A bancada atual já está colada na
parede do fundo (tampo até Z 71,4; a face interna da parede fica em 71,5), então **recuar até a parede não ganha nada**. Estreitar
o deck baixo para 1,4 também não basta: a frente iria a Z 67,2 e o corredor do fundo ficaria com 3,7.

**Resolução (Provisória):** a bancada fica com os 4,4 do AST-158 (Z 67,0..71,4) e a **mesa central anda 1,0 para o norte**
(Z 60,0..62,5, era 61..63,5). Larguras:

| Faixa | Z | Largura | Mínimo (§1) |
|---|---|---|---|
| Balcão da frente (tampo) | 53,8..55,6 | — | — |
| Corredor da frente (caixa, entregador, spawns PS-1..4) | 55,6..60,0 | **4,4** (era 5,4) | 4 |
| Mesa central | 60,0..62,5 | 2,5 | — |
| Corredor do fundo (montadores, grelhador, rota das caixas) | 62,5..67,0 | **4,5** (era 5,0) | 4 |
| Bancada: deck baixo (esteira) | 67,0..68,6 | 1,6 | — |
| Bancada: prateleira alta (estações) | 68,6..71,4 | 2,8 | — |

Os dois corredores comportam **2 jogadores lado a lado** (R6 tem 2 de largura: 2 × 2 + folga 0,4 = 4,4). A colisão
jogador-jogador está desligada (DEC-175), então ninguém trava ninguém. O deck baixo segue com 1,6 e o AST-157 não muda.

### 16.3 Vista de cima (ASCII)

Escala: **1 coluna = 0,5 stud (X)**, **1 linha = 1 stud (Z)**, com X de 25 a 60 e Z de 54 a 72. Norte para cima. ASCII com
erro de ±0,5; **as tabelas da §16.5 são a fonte da verdade**.

```
  X →  25        30        35        40        45        50        55        60
       |         |         |         |         |         |         |         |
  54   W====$==============PPPPP================================L=====T======W   balcão: $ pote · P PICKUP · L persiana · T TAB-1
  55   W=====================================================================W
  56   W.....................p........................................p......W   p = poses (PICKUP, TAB-1)
  57   W...................................C.................................W   C = câmera larga do foco (Z 58,1, Y 8,9)
  58   W...............@.........@.........@.........@.......................W   @ = PS-1..4
  59   W.....................................................................J   J = janela do drive-thru
  60   Wccccc.......aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa............J   a = MESA CENTRAL (Z 60,0..62,5)
  61   Wccccc.......aaaa1aaaa2aaaa3aaaa4aaaaa5aaaa6aaaa7aaaa8aaaa......m.....J   1..8 = vagas (Mount_Plate_n); m = DT-PC
  62   Wccccc.......aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa............J   c = cafeteira
  63   W.....................................................................W   corredor do fundo (Z 62,5..67,0)
  64   W..u............r.........r.........r.........r......................SW   u = BIN-K; r = REV-1..4 (movidos, §16.8); S = KSW
  65   W............................b.........b..........g...................W   b = Seat_Belt_2 / _1; g = Seat_Grill
  66   W.....................................................................W
  67   W..........._<<<<<<<<<<<<<<<<<<<<<<<<<!<<<<<<<<<<<?__________________FW   deck baixo: < esteira (o prato anda para oeste); ! = Prompt_Work; ? = Prompt_Grill; F = PHONE-R
  68   W..........._<<<4<<<<<<<<3<<<<<<<<2<<<<<<<1<<<<w<<<__________________.W   4..1 = Stop_4..1; w = WaitL_1 (entrada)
  69   W...........^^^^^^^KKKKKKKKKKKKTTTBBBBBRRRRRRGGGGGGGGGGDDDD^^^^^^^^^^.W   prateleira alta (Y 3,9): K condimentos · T tábua · B pães
  70   W...........^^^^^^^KKKKKKKKKKKKTTTBBBBBRRRRRRGGGGGGGGGGDDDD^^^^^^^^^^YW   R mesa de descanso · G grelha · D salsichas cruas; Y = GAS-1 (movido)
  71   W...........^^^^^^^KKKKKKKKKKKKTTTBBBBBRRRRRRGGGGGGGGGGDDDD^^^^^^^^^^.W
  72   W+++++++++++WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW   + = DOOR-P (despensa)
```

Leitura em 3D: de qualquer ponto do corredor do fundo vê-se a bancada inteira, em degrau: embaixo a esteira escura com as
marcas Mustard de parada e em cima as três massas de estação (aço da grelha, madeira do pão, aço com friso Teal dos
condimentos, AST-158). A mesa central fica entre o fundo e o balcão e é vista dos dois corredores. Ninguém precisa sair do
cômodo.

### 16.4 Vista do cozinheiro e da câmera larga (elevação, olhando para o sul)

Escala: 1 coluna = 0,5 stud, **X diminui para a direita** (esquerda = leste). Fora de escala na altura.

```
  X:       55      51      47      43      39      35      31
  Y 4–5,2   DDDDDGGGGGGGGGGRRRRRRBBBBBTTTKKKKKKKKKKKK          estações na prateleira alta (D cruas · G grelha · R descanso · B pães · T tábua · K condimentos)
  Y 3,9    =================================================  tampo alto (degrau de 0,9)
  Y 3,08   _________>>>>w>>>>1>>>>>>>2>>>>>>>>3>>>>>>>>4>>>_  esteira: o prato anda da ESQUERDA para a DIREITA (w entrada, 1..4 paradas)
  Y 4,2              ?           !                            Prompt_Grill (?) · Prompt_Work (!) (frente do deck)
  pés                g          b         b                   Seat_Grill · Seat_Belt_1 · Seat_Belt_2 (Z 65,8)
           ← ESQUERDA (leste: tablet, DT)        DIREITA (oeste: despensa, PICKUP) →
```

### 16.5 Posições e rotações (referencial MAP; no place = `(−x, y, 67,887 − z)`)

Convenções: "frente para o norte" = a frente da peça olha para o cozinheiro (`DIR.N` do bind, como hoje); "olha para o sul"
= LookVector +Z do MAP = **−Z do mundo** (yaw 0 no place). Y = altura no mundo (piso 0,45).

**a) Bancada e esteira**

| Âncora (AST) | O quê | Posição / medidas | Rotação | No place (x; z) |
|---|---|---|---|---|
| `BENCH2` (AST-158) | Bancada de dois níveis (substitui o `BackCounter`) | X 31,0..59,42 (a ponta oeste segue a TASK-477: livre do batente da DOOR-P); deck baixo Z 67,0..68,6, tampo Y 3,0; prateleira alta Z 68,6..71,4, tampo Y 3,9; espelho até Y 5,2 colado na parede | frente para o norte | X −31,0..−59,42; Z 0,887..−3,513 |
| `Mount_Belt` (AST-157) | Origem da esteira | esteira X 31,2..50,4 (19,2 = 4 × `Straight_4` + `Straight_2` + 2 pontas), centro da lona Z 67,8, lona Y 3,0 | ao longo de X; ponta "L" no leste (50,4) | (−40,8; 0,087) |
| `Stop_1` | Parada 1 (`Grill`): **entrada**, grelha + descanso à vista (o montador não grelha daqui, DEC-305; a salsicha vai ao pão na `Stop_2`) | (46,2; 3,08; 67,8) | — | (−46,2; 0,087) |
| `Stop_2` | Parada 2: **tábua e pão** (cortar, pôr a salsicha no pão) | (42,0; 3,08; 67,8) | — | (−42,0; 0,087) |
| `Stop_3` | Parada 3: **condimentos** (desenhar) | (37,35; 3,08; 67,8) | — | (−37,35; 0,087) |
| `Stop_4` | Parada 4: **saída** (o prato volta à mão) | (33,0; 3,08; 67,8) | — | (−33,0; 0,087) |
| `WaitL_n` / `WaitR_n` | Espera ao lado (DEC-303), ±2,1 de `Stop_n`; **L = leste** (esquerda do cozinheiro), **R = oeste** | WaitL: 48,3 · 44,1 · 39,45 · 35,1; WaitR: 44,1 · 39,9 · 35,25 · — (`WaitR_4` cairia fora da esteira: não existe, o prato sai) | — | x negativo, z 0,087 |
| (entrada) | O prato entra em `Stop_1`; se ela está ocupada, entra em `WaitL_1` (48,3), na frente da grelha | — | — | — |

Distâncias entre paradas: 1–2 **4,2** · 2–3 **4,65** · 3–4 **4,35** (≥ 4,2, mínimo do AST-157). Algumas esperas vizinhas
coincidem (`WaitR_1` = `WaitL_2` = X 44,1) ou quase (`WaitR_2` 39,9 × `WaitL_3` 39,45). Com no máximo 2 pratos na esteira
isso não gera conflito: um prato que espera tem o outro numa parada, nunca em outra espera.

**b) Estações na prateleira alta** (base-centro no tampo Y 3,9; centro Z 70,0; todas com a frente para o norte)

| Âncora | Estação | X (largura) | Centro | Peça de origem (bind) | Prompt de mundo |
|---|---|---|---|---|---|
| `Mount_Stock` (novo, sem ficha) | Salsichas cruas (cooler AST-018) | 52,3..54,3 (2,0) | (53,3; 70,0) | clone `STOCK` (TRL-S) | `Prompt_Restock` (53,3; 4,8; 70,4), só com caixa DOGS |
| `Mount_Grill` | **Grelha** AST-120 (vista focada, DEC-303) | 47,5..52,1 (4,6) | (49,8; 70,0) | clone `GRILL-1` (TRL-G) | nenhum (`grill_collect`/`grill_flip` desligados, TASK-496/515) |
| `Mount_Rest` | **Mesa de descanso** AST-160 (`Rail_8`, capacidade 8) | 44,3..47,3 (3,0) | (45,8; 70,0) | clone `RAIL` (TRL-R), que passa a se chamar `REST` | nenhum (`Prompt_Rail` desligado no modo esteira) |
| `Mount_BunCrate` | **Caixa de pães** AST-015 | 42,1..44,1 (2,0) | (43,1; 70,0) | clone `BUN` | `Prompt_Restock` (43,1; 4,8; 70,4), só com caixa BUNS |
| `Mount_Board` | **Tábua + faca** AST-014 | 40,3..41,9 (1,6) | (41,1; 70,0) | clone `CUT-1` | nenhum |
| `Mount_Sauce` | **Condimentos** AST-017 (~5,5) | 34,6..40,1 (5,5) | (37,35; 70,0) | clone `COND-1` | `Prompt_Restock` (37,35; 4,8; 70,4), só com caixa de condimento |
| (livre) | Tampo sem estação | 31,0..34,4 e 54,5..59,42 | — | — | — |

A mesa de descanso fica **colada no lado do pão** (borda direita do bloco esquerdo, como pede o AST-160): `Stop_1` fica sob ela
e o `Stop_2` fica a 4,2.

**c) Assentos, dois prompts e câmeras** (DEC-305: um prompt para a esteira e outro para a grelha)

| Âncora | O quê | Posição | Rotação | No place |
|---|---|---|---|---|
| `Seat_Grill` | Pé do grelhador (assento 3) | (49,8; 0,45; 65,8) | olha para o sul | (−49,8; 0,45; 2,087) |
| `Seat_Belt_1` | Pé do montador 1 (assento 1) | (44,6; 0,45; 65,8) | olha para o sul | (−44,6; 0,45; 2,087) |
| `Seat_Belt_2` | Pé do montador 2 (assento 2) | (39,4; 0,45; 65,8) | olha para o sul | (−39,4; 0,45; 2,087) |
| `Prompt_Work` | Prompt da **esteira** (`prep_work`, "Work", toque, **raio 5**), na frente do deck baixo; leva a `Seat_Belt_1`, depois `_2`; exige prato não montado na mão ou prato parado do jogador | (44,0; 4,2; 67,1) | — | (−44,0; 4,2; 0,787) |
| `Prompt_Grill` | Prompt da **grelha** (`prep_grill`, "Grill", toque, **raio 5**; `Conveyor.Binding.GrillPrompt`), âncora fixa (DEC-305); leva a `Seat_Grill` | (49,8; 4,2; 67,1) | — | (−49,8; 4,2; 0,787) |
| `CamAnchor_Belt` / `Focus_Belt` | **Câmera larga** do foco da esteira: as 3 estações e a esteira inteira | câmera (42,75; 8,87; 58,12) → alvo (42,75; 3,8; 69,0); d 12, 25° para baixo, `Fov` **70** | olha para o sul, pitch −25° | (−42,75; 8,87; 9,767) → (−42,75; 3,8; −1,113) |
| `CamAnchor_Rest` / `Focus_Rest` | Vista perto da `Stop_1` | câmera (46,2; 7,14; 65,36) → alvo (46,2; 3,6; 68,9); d 5,0, 45°, `Fov` 55 | sul, −45° | z 2,527 → −1,013 |
| `CamAnchor_Board` / `Focus_Board` | Vista perto da `Stop_2` | câmera (42,0; 7,14; 65,36) → alvo (42,0; 3,6; 68,9) | sul, −45° | idem |
| `CamAnchor_Toppings` / `Focus_Toppings` | Vista perto da `Stop_3` | câmera (37,35; 7,14; 65,36) → alvo (37,35; 3,6; 68,9) | sul, −45° | idem |
| `CamAnchor_Grill` / `Focus_Grill` | Vista do grelhador: cruas + grelha + descanso | câmera (49,3; 8,18; 66,66) → alvo (49,3; 4,2; 70,0); d 5,2, 50°, `Fov` 55 | sul, −50° | (−49,3; 8,18; 1,227) → (−49,3; 4,2; −2,113) |

Rotação de cada câmera = `CFrame.lookAt(CamAnchor, Focus)`. O nome segue a regra de `tech/prep-3d.md` §4.1
(`CamAnchor_<Vista>`/`Focus_<Vista>`, atributo `Fov`). As âncoras ficam na bancada (são de todos), não por assento:
as duas pessoas na esteira usam a mesma câmera larga e a mesma câmera de parada.

**d) Mesa central (DEC-303, DEC-304) e PICKUP**

| Âncora | O quê | Posição | Rotação | No place |
|---|---|---|---|---|
| `CENTER` (AST-161 em fileira; ver §16.7) | Mesa central, tampo 22 × 2,5, Y 3,0 | X 31,5..53,5, **Z 60,0..62,5** (anda 1,0 para o norte) | comprida em X | Z 7,887..5,387 |
| `Mount_Plate_1..8` | Centro de cada vaga (o prato AST-162 pousa aqui) | Z **61,25**, Y 3,05; X **33,4 · 36,0 · 38,6 · 41,2 · 43,8 · 46,4 · 49,0 · 51,6** (2,6 entre centros; **1 = oeste**, igual aos `PLATE-n` de hoje) | prato com o comprimento em X | x negativo, z 6,637 |
| `Click_Slot_1..8` | Alvo do clique de **pôr** (tag `CenterSlot`, atributo `CenterIndex` = n; `Content.Restaurant.Binding`) | caixa invisível **2,2 (X) × 1,0 (Y) × 2,2 (Z)**, de Y 3,0 a 4,0, centrada em cada `Mount_Plate_n` (0,4 de folga entre vizinhas) | — | — |
| `Prompt_Take` (Attachment filho do `Click_Slot_n`) | **Segurar E 0,5 s** pega o prato (`plate_take`, `Hold` 0,5, raio 5). **Fixo na vaga**, não no modelo do prato (contrato §7.4) | centro da vaga + 0,4 (Y ~3,5) | — | — |
| `Att_Ticket` | Billboard do #n sobre a vaga | sobre o `Click_Slot_n` | — | — |
| `PICKUP` (AST-143) | Entrega segurando o prato (sem mudança de lugar) | bandeja (36; 54,7), Y 3,1; `Prompt_Serve` (36; 3,5; 54,9), agora de **segurar 0,5 s** (`pickup_serve`, `Hold` 0,5, raio 7); pose (36; 56,6) | como hoje | (−36; 3,5; 12,987) |

O prato vazio nasce na **vaga livre de maior índice** (leste: perto do tablet e da entrada da esteira; contrato §6.2, P14
aceita pelo dono). O prato pronto volta em qualquer vaga livre (clique), e quem sai da esteira na ponta oeste tende a usar as
vagas 1–3, perto do `PICKUP`. Prato que o servidor manda à mesa sozinho (desconexão, `KickAway`, `ParkMax`) vai para a **vaga
livre de menor índice** (`PlateService:Shelve`, contrato §10.1).

### 16.6 Câmera do foco: o que cabe em 16:9 e em 667 × 375

O aspecto de 667 × 375 é 1,78, o mesmo de 16:9, então o enquadramento é igual no PC e no celular. Contas com o FOV vertical
do Roblox:

- **Câmera larga** (`Fov` 70; tan 35° × 1,78 = 1,245 na horizontal). O ponto mais apertado é a ponta oeste da esteira, na frente
  (X 31,2; Z 67,0), que cai a **88% da meia-largura**. Sobram ~39 px de margem em 667, e a ponta leste das cruas fica a 75%.
  Na vertical, a faixa da bancada vai de ~146 px (topo do espelho) a ~225 px (frente da esteira) numa tela de 375. Ficam
  ~150 px livres embaixo para as setas (AST-159, ≥ 44 px, cantos inferiores) e a barra do topo (36 px) não cobre nada.
  O prato de 1,8 aparece com ~50 px de largura, legível para "qual é o meu", mas nada é tocado nessa vista: só as setas.
  A câmera fica a Y 8,87, abaixo do teto, sobre o corredor da frente. Nenhuma luminária pode ficar no volume entre ela e a
  bancada (X 31..55, Z 58..71, Y 4..9,5).
- **Câmeras de parada** (`Fov` 55, d 5,0, 45°). Mostram 9,3 studs de largura, ou **~72 px/stud** em 667. Pegam o prato
  inteiro na esteira (borda da frente a 67% da meia-altura) e a estação inteira em cima (topo a 86%). A grade de condimentos
  (5,5) inteira na `Stop_3` dá ~400 px. **Alvo mínimo de toque nessas vistas: 0,61 stud** (44 px).
- **Câmera da grelha** (`Fov` 55, d 5,2, 50°). Mostra 9,6 studs, de X 44,5 a 54,1: as cruas, a grelha e a mesa de descanso
  quase inteira, com ~69 px/stud. As vagas da grelha precisam de **≥ 0,65 stud entre centros** (pedido ao modeler/art-director,
  se o AST-120 tiver vagas mais juntas).
- **Proposta para a TASK-518:** a câmera larga é a vista enquanto o prato anda. Quando ele **chega numa parada**, a câmera desliza
  (0,35 s, `Rules.Camera.Travel`) para a câmera daquela parada, onde ficam os gestos. A seta seguinte volta para a larga. Assim
  a vista larga cumpre o aceite ("vê as 3 estações e a esteira inteira") e os gestos ficam grandes no celular.
- **Telas mais estreitas** (4:3, iPad): a meia-largura cai para 0,93 e a ponta oeste sai do quadro. A regra para a TASK-518 é
  calcular o FOV vertical para manter **tan(meia-largura) ≥ 1,245** quando o aspecto for < 1,7.
- **Avatares no caminho:** quem está nos assentos (Z 65,8, cabeça até Y 5,45) fica entre a câmera larga e a esteira. O
  `Rig.luau` já esconde o próprio rig e corta os outros (`tech/prep-3d.md` §4.4); a regra precisa valer também para os colegas
  em pé no corredor do fundo enquanto o jogador está no foco.

### 16.7 Mesa central: fileira de 8, não grid 4 × 2 (divergência com o AST-161)

O AST-161 propõe uma ilha de **11 × 5,4** com grid 4 × 2. **Não cabe** no MAP-01 r4 com a bancada de 4,4. Do fundo do balcão
(Z 55,6) à parede (71,4) há **15,8**, e corredor da frente 4 + ilha 5,4 + corredor do fundo 4 + bancada 4,4 = **17,8**. Girar a ilha
fecha um corredor, e a ponta oeste (X 25,5..31,5) já tem a cafeteira, a lixeira e a passagem para a despensa.
Fica a **fileira de 8** no lugar da mesa de montagem (AST-144, 22 × 2,5), com os mesmos espaçamentos que o AST-161 pede (2,6 entre
centros, marca Ø 2,2) e os mesmos encaixes (`Mount_Plate_n`, `Click_Slot_n`) e estados (`Free`/`Taken`/`Ready`). Uma fileira de 8
é um grid 1 × 8: é acessível dos dois corredores (o montador põe e pega pelo fundo, o entregador pelo da frente), e cada vaga
fica a ≤ 2 studs de quem está no corredor. **Pedido ao art-director:** fundir o AST-161 no AST-144 (fileira) ou criar a variante
"fileira" do AST-161.

**Distância mínima para o toque (mesa central):**

| Medida | Valor | Por quê |
|---|---|---|
| Entre centros de vaga | **2,6** | ≥ 2,5 entre prompts vizinhos (§1, §13). Prato 1,8 × 1,0 deixa 0,8 de folga |
| Entre `Click_Slot` vizinhos | **0,4** (caixas de 2,2) | o toque nunca cai em duas vagas |
| Altura do `Click_Slot` | **1,0** (a ficha diz 0,2) | em 1ª pessoa (olho a Y 4,95), FOV 70, tela de 375: com 0,2 de altura o alvo tem ~65 px a 4 studs e só **~35 px a 6**. Com 1,0 tem **~68 px a 6 studs**, então passa de 44 px em todo o alcance |
| Alcance do clique de pôr | ≤ **12** do centro da vaga (`Content.Restaurant.CenterTable.Reach` 12, Provisório; contrato §7.2) | o alvo tem ≥ 44 px até ~9 studs (~68 px a 6, ~34 px a 12). Aceito: quem usa a mesa fica a ≤ 2 studs dela no corredor; o teste de toque mede a ≤ 6 |
| Prompt "segurar E" | um por vaga (`Prompt_Take` fixo no `Click_Slot_n`; 0,5 s, raio 5), com só o mais próximo visível (regra do `PromptController/Rules`, TASK-522) | 8 prompts a 2,6 se sobrepõem na tela sem essa regra |

**Distância mínima entre prompts de mundo na cozinha** (≥ 2,5, §13):

| Par | Distância |
|---|---|
| `Prompt_Work` ↔ `Prompt_Restock` da caixa de pães | 3,5 |
| `Prompt_Work` ↔ vaga mais próxima (5) | 5,9 |
| `Prompt_Work` ↔ `Prompt_Grill` | 5,8 (≥ 2,5). Com raio 5 nos dois, entre X ~45 e ~49 do corredor os dois aparecem juntos, com textos diferentes ("Work", "Grill"); é o que o solo usa para trocar de assento |
| `Prompt_Take` ↔ `Prompt_Take` (pratos vizinhos) | 2,6 |
| `PICKUP` ↔ vaga 1 | 6,9 |
| `GAS-1` (novo lugar) ↔ `PHONE-R` | 3,0 |
| `PHONE-R` ↔ `KSW` | 2,8 |
| `Prompt_Restock` das cruas ↔ `GAS-1` | 6,0 |

Os 3 `Prompt_Restock` só aparecem com a caixa certa na mão (regra de hoje). No foco, os alvos de toque seguem
`tech/prep-3d.md` §2.1: ≥ 44 px, ou seja ≥ 0,61 stud nas câmeras de parada e ≥ 0,65 na da grelha (§16.6).

### 16.8 Fluxo, papéis e corredor (DEC-275)

| Papel | Onde fica | Corredor | Cruza com |
|---|---|---|---|
| Caixa | TAB-1 + persiana + DT-PC (leste) | frente | ninguém (o prato vazio nasce sozinho na mesa) |
| **Grelhador** | `Prompt_Grill` → `Seat_Grill` (49,8; 65,8), vista da grelha; a pronta vai sozinha à mesa de descanso (8 lugares) | fundo, ponta leste | ninguém (parado no foco) |
| **Montador** (até 2) | pega o prato na mesa central pelo fundo (≤ 2 studs, segurar E 0,5 s) → `Prompt_Work` (≤ 4) → `Seat_Belt_1/2` | fundo | o outro montador (lado a lado, 5,2 entre assentos) |
| **Entregador** | pega o prato pronto na mesa central pelo corredor da frente → `PICKUP` (4–7 studs) | frente | o caixa, só se cruzar para o leste |
| Reposição | DOOR-P → corredor do fundo atrás dos assentos (Z 63..65) → `Prompt_Restock` | fundo | passa atrás dos montadores; sem colisão |

- **Rota do prato:** tablet → vaga leste da mesa (sozinho) → mão do montador → `Stop_1` … `Stop_4` (leste → oeste) → mão → vaga
  oeste da mesa (≤ 3 studs) **ou** direto ao `PICKUP` (~21 studs contornando a ponta oeste da mesa, 1,3 s a 16/s). Drive-thru:
  `Stop_4` → corredor do fundo → DT-WIN, ~22 studs (1,4 s).
- **Solo (DEC-305, contrato §2.4):** troca de assento. `Prompt_Grill` → `Seat_Grill` para pôr as cruas; `Prompt_Work` →
  `Seat_Belt_1` para montar. Sair da esteira no meio (Leave) deixa o prato **parado e reservado** na parada onde estava; o
  "Work" seguinte retoma esse prato. Mesa → `Prompt_Work` 4 studs (0,25 s); `Prompt_Work` ↔ `Prompt_Grill` 5,8 (0,35 s).
  O que está na mão não escolhe o assento: o prompt escolhe.
- Os avatares ficam parados no assento durante o foco; os colegas veem o prato andar na esteira (TASK-519).

### 16.9 O que muda, sai ou é reapontado

| Peça hoje (bind) | Destino |
|---|---|
| `BackCounter` (mesa de trabalho da TASK-477, X 31,0..59,42, Z 68,5..71,4) | vira o `BENCH2` (AST-158) com a mesma ponta oeste em X 31,0 e a frente em Z 67,0. A TASK-504 aplica junto com a TASK-477 |
| `ASM` + `PLATE-1..8` (AST-144/145) | viram a `CENTER` (mesa central) 1,0 ao norte; `Mount_Plate_n`/`Click_Slot_n`. O contrato (§7.4) usa a tag **`CenterSlot`** + atributo `CenterIndex` = n no `Click_Slot_n`; o `PlateService` deixa de ligar `PlateSlot` no modo esteira (a TASK-504 decide se tira a tag antiga). `Prompt_Put` sai (o pôr vira clique); `Prompt_Take` fica **fixo na vaga** (filho do `Click_Slot_n`), não no modelo do prato |
| `GRILL-1`, `RAIL`, `STOCK`, `BUN`, `CUT-1`, `COND-1` (clones do trailer) | movidos para a prateleira alta (§16.5 b), como **cenário e alvo do foco**; os prompts do F2 ficam desligados no restaurante (TASK-496). `GRILL_SLOTS`/`Att_Flip<n>` acompanham a grelha. `RAIL` passa a se chamar `REST` |
| `CUT-2` (tábua de blockout) | **sai do restaurante** (só existia para o F2) |
| `GRILL-2`, `COND-2` (só no doc) | não nascem: uma grelha, um bloco de condimentos (o upgrade de 2ª grelha volta como pedido ao game-designer) |
| `Station_1..4/Mount` do restaurante (âncoras de prep clonadas do trailer) | substituídos pelas âncoras da §16.5 c. O trailer mantém os dele; o modo trailer não muda |
| `PrepTargets/PT_*` (editados à mão pelo dono) | acompanham a estação de cada um (transformação rígida); a TASK-504 sincroniza antes |
| `MenuStrip` (quadro de pedidos, editado à mão pelo dono: Y 4,4..8,35) | sobe **1,0** (Y 5,4..9,35). Senão o espelho (5,2) e as estações cobrem a faixa de baixo. **Confirmar com o dono** (é edição dele) |
| `Hood` | já apagado pelo dono; não volta |
| `GAS-1` (parede oeste, 25,7; 67) | vai para a **parede leste**, (59,3; 4,8; 70,0), a ~7 da grelha. Onde está ficaria a 24. A AN-R09 vai junto |
| `REV-1..4` (Z 65,9) | vão para **Z 64,5** (mesmos X), para não nascer em cima dos assentos |
| `DROP-T` (56; 64,5), `KSW`, `PHONE-R`, `BIN-K`, `R-COFFEE`, `DOOR-P`, `TRL-OUT`, `PS-1..4` | ficam |
| §6 (tempos), §7.1 (papéis), §5.5 (estações) | superados nos pontos desta seção |

### 16.10 Nomes: conferência com as fichas da TASK-523

Uso os nomes do art-director: `Stop_1..4`, `WaitL_n`/`WaitR_n` (±2,1), `Seat_Belt_1/2`, `Seat_Grill`, `Prompt_Work`,
`Mount_Plate_n`, `Click_Slot_n`, `Mount_Grill/Rest/BunCrate/Board/Sauce`, `Mount_Belt`. Divergências:

1. **`Prompt_Work` não fica no centro do deck baixo** (X 40,8), mas em **X 44,0**, entre o descanso e o pão: a ≤ 5 (raio do
   `prep_work`) dos dois assentos da esteira (`Seat_Belt_2` a ~4,8, no limite) e a ≤ 4 da mesa central. O grelhador usa o
   `Prompt_Grill` (49,8), na frente do `Seat_Grill`.
2. **`Click_Slot_n` com 1,0 de altura** (a ficha diz 0,2), pelo toque a 6 studs (§16.7).
3. **`WaitR_4` não existe** (cairia fora da esteira; o prato sai na `Stop_4`).
4. **Mesa central em fileira** (§16.7), não ilha 4 × 2.
5. Âncoras novas sem ficha: `Mount_Stock` (cruas, AST-018), `Prompt_Grill` (âncora fixa, DEC-305), `CamAnchor_*`/`Focus_*` (§16.5 c),
   `Att_Ticket` e o `Prompt_Take` fixo na vaga (§16.5 d).
6. Mesa de descanso com **capacidade 8** (`Rail_8`; `Content.Prep.Conveyor.Rest.Capacity = 8`, aceita na DEC-305): o espaço
   reservado é de 3,0 × 2,5.

Os nomes batem com o contrato da TASK-512 (`Conveyor.Binding`, `Restaurant.Binding.Center*`) e com o `Content` da TASK-513.

### 16.11 Critérios de aceite (para a TASK-504 conferir no Studio)

1. Print de cima igual à §16.3 (±0,5).
2. Corredores: frente ≥ 4,4, fundo ≥ 4,5. Varredura R6 (`restaurant_walk_check.luau`) com 0 bloqueios entre DOOR-P,
   assentos, mesa central, `PICKUP`, TAB-1 e DT-WIN.
3. Pela `CamAnchor_Belt`, em 1280 × 720 e em 667 × 375: as 3 estações, a mesa de descanso, as cruas e a esteira de ponta a
   ponta no quadro, com ≥ 5% de margem lateral.
4. Pelas câmeras de parada e da grelha: a estação e o prato inteiros no quadro; alvos de toque ≥ 44 px em 667 × 375.
5. Prompts de mundo da cozinha a ≥ 2,5 entre vizinhos (tabela da §16.7); `Click_Slot` vizinhos sem sobreposição.
6. Nenhuma peça do rail flutuando; nenhum "[RailSlot] … may float" no console.
7. Visto do `Seat_Belt_1`, olhando para a bancada: grelha à esquerda, pão no meio, condimentos à direita.

### 16.12 Perguntas para o secretário consolidar (não registradas em `open-questions.md`)

| Pergunta | Recomendação (Provisória) |
|---|---|
| Mesa central: fileira de 8 (cabe) ou ilha 4 × 2 (exige tirar 2 studs de algum corredor ou da bancada)? | **Respondida:** fileira de 8 (Provisória aceita na DEC-305) |
| O quadro de pedidos (`MenuStrip`, edição do dono) pode subir 1,0 para não ficar atrás das estações? | Sim |
| `GAS-1` vai para a parede leste, perto da grelha nova? | Sim (a alternativa é ficar a 24 da grelha, o que ajuda o susto, mas o jogador tem que largar o posto) |
| Prompt único: abre a esteira com prato na mão e a grelha sem prato? | **Respondida:** não; dois prompts, `Prompt_Work` e `Prompt_Grill` (DEC-305) |
| Câmera: larga enquanto o prato anda e perto na parada? | Sim (decisão da TASK-518) |
