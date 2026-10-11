Status: Rascunho (Provisório)

# LOBBY — "Bramble's Corner Dogs HQ"

Autor: level-designer, 2026-10-11 (pedido do usuário para o teste com amigos do mesmo dia). Fontes: DEC-008, DEC-012,
DEC-022, DEC-034, DEC-067, DEC-069, DEC-098, DEC-175, DEC-179, DEC-186, DEC-206, DEC-209; FEAT-001; `art/style-guide.md`
(Aprovado, DEC-126); fichas AST-088, AST-089, AST-090 (Rascunho); `tech/architecture.md` §18.1/§18.5.
Responde ao `Q-085` (documento do lobby) com proposta **Provisória**: documento `levels/LOBBY.md` (sem `MAP-##`).
Tudo sem `[DEC-###]` é proposta do level-designer. Números iniciais, ajustáveis em playtest (DEC-044).

**Versão vigente: v2** (2026-10-11, feedback do usuário: "a v1 de 60 × 60 é pequena demais para 20–30 pessoas").
Placements da v2: `tools/assetplace/LOBBY_v2_placements.luau` (WORLD). Peças procedurais da v2: §V2-12.
A v1 (`LOBBY_placements.luau`, §1–§16 abaixo do anexo) fica só como histórico; a v2 a **substitui** na mesma região.

---

# LOBBY v2 (vigente, Provisório)

Muda o tamanho, o número de plataformas e a distribuição; **mantém** a identidade (noite quente, neon em tubo, varal de
lâmpadas, fachada "CORNER DOGS / HQ", carrinho original exposto) e as mesmas zonas (Classes no palco, Gem Shop, Codes,
Squads, Start Shift). Convenções de eixo, `rotY`, frente dos assets e cores: iguais às da v1 (§2 e §12 do anexo).

## V2-1. Resumo

| Item | v1 | **v2** |
|---|---|---|
| Área andável | 60,4 × 60 (3.624 studs²) | **106,4 × 110** (X −56..50,4; Z −675..−565) = 11.704 studs² (**3,2×**) |
| Centro da praça / spawn | (2, −602) | praça centrada em ~(−3, −620); **`LOBBY-SPAWN` (5, 0, −620)** |
| Jogadores simultâneos | — | **até 30** avatares R15 circulando sem gargalo (corredor mínimo 6, típico 10–20) |
| Plataformas de squad | 4 (passo 10, folga 2) | **8** Ø 8 em **duas fileiras** de 4, passo 18 nos dois eixos = **folga de 10** entre bordas |
| Palco de classes | 12 × 7, zona r 3,5 | **20 × 7**, zona **r 7** em frente ao cordão (várias pessoas ao mesmo tempo) |
| Gem Shop / Codes | zona r 3,5 | **r 5,5 / r 5**, com "avental" de piso livre para fila (§V2-7) |
| Regra de distância | ≤ 25 do spawn | **todo centro de zona a ≤ 40 do spawn** (§V2-6) |
| Pontos de interesse | bancos, piquenique | **Food court** (trailer AST-027 parado + 3 mesas), **Fonte** procedural com 4 bancos, **Cabine de foto** procedural, **Mastro do varal** (marco central), jardim atrás da loja |
| Luzes locais | 10 (1 com sombra) | **14** (1 com sombra) — alvo do style guide §5.1 |

Fronteira com o MAP-01: o MAP-01 fica em Z ≥ −60; a borda norte da v2 (prédios do fundo) termina em Z ~−538. Mais de 470
studs de distância. DevScenes (Z ~4000) intocadas.

## V2-2. Planta (ASCII, aproximada; 1 coluna ≈ 2 studs, 1 linha ≈ 3–6 studs; **as tabelas são a fonte da verdade**)

```
         X→ -56     -40       -20        0        20        40  48 50.4    60      72 73.5
            |       |         |          |         |         |   | |       |       |  |
Z -552   [BK1 A  ][BK2 H  ][BK3 A  ][BK4 H = HQ "CORNER DOGS"][BK5 A  ][BK6 H  ] arb  ===RE-N (cartão)===
Z -565   =======================================  LW-N  =====================================+c+  RUA  |RC1
Z -569   |▓▓▓▓▓▓▓ TRAILER AST-027 ▓▓▓▓▓▓▓ D|▒▒▒▒ CARRINHO AST-026 ▒▒▒▒|E  banco [FOTO]   T |c|        |
Z -575   |▓▓▓▓▓▓▓  (janela p/ -Z)  ▓▓▓▓▓▓▓  |▒▒ ┌──── PALCO 20×7 ────┐ ▒|   ·      ·        |c|  pickup|RC2
Z -579   |~~~~~~~~~ LW-TRUCK ~~~~~~~~~~~~~~ |▒▒ │       ★ RIG        │ ▒|                    |c|        |
Z -580   |                                  |▒▒═╧════ cordão ═══════╧═▒|                    |c|        |
Z -587   |   [M1]      [M2]      [M3]  lix      ░░░░ ◎ CÂMERA ░░░░                        |c|        |
Z -590   |                                       ░ zona CLASSES r7 ░      (4)[B]   (8)[B]  |c|        |RC3
Z -600   |C                                            ^                       F          |c|        |
Z -607   |       ┌─────┐ [vaso]                       ^  [WELCOME]                         |c|        |
Z -611   | jardim│ GEM │ ▣S1..P5               ^        (3)[B]   (7)[B]  ┌─START─┐      |c|  VAN   |RC4
Z -620   |  T  ▒ │SHOP │ ◇LOBBY-SHOP <  <  <  ✚ SPAWN  >  >  >  >  >  >  >  ★START │ SHIFT │|c|AST-035 |
Z -629   |  T    │ 026 │ [vaso]          /    ¶ MASTRO   (2)[B]   (6)[B]  └───────┘      |c|        |
Z -633   |       └─────┘                /                                 G              |c|        |RC5
Z -640   |H                            /                                                   |c|        |
Z -647   |       b                    /         (1)[B]   (5)[B]                          |c|        |
Z -651   |     b ( FONTE )b     ◇ CODES                                          hidrante |c|        |
Z -654   |       (  Ø12   )   [ MURAL CODES ]  lix                                         |c|        |RC6
Z -657   |       b              ················ banco  lix  banco                        |c|        |
Z -666   |  T                        mesa            T                                     |c|  sedan |
Z -671   |A    banco     T                                                  B   placa     |c|        |RC7
Z -675   =======================================  LW-S  =====================================+c+       |
Z -688   [FR1 H  ][FR2 A  ][FR3 H  ][FR4 A  ][FR5 H  ][FR6 A  ] arb  ===RE-S (cartão)===
         (fileira oeste LF1..LF7 em X < -56, fachadas para +X, atrás de toda a borda esquerda)
```

Legenda: `✚` spawn (medalhão Ø 8) · `¶` mastro do varal (§V2-12.9) · `★` rig / start · `◎` câmera de classes ·
`◇` ponto da zona · `▣` pedestais da loja · `(n)[B]` plataforma de squad n Ø 8 + quadro AST-024 · `A..H` postes
SL-A..SL-H · `T` árvore · `b` banco · `[M1..M3]` mesas de piquenique · `░` avental de piso (fila) · `▒` blocos
invisíveis (LW-STAGE / LW-SHOP / LW-TRUCK) · `|c|` meio-fio + parede LW-E · `> ^ < /` setas neon no chão (§V2-12.10).

## V2-3. Zonas nomeadas

| ID | Zona | Limites (WORLD) | Função |
|---|---|---|---|
| LZ-HQ | HQ + palco | X −16..16, Z −580..−565 (bloco invisível LW-STAGE) | vitrine do carrinho original; rig da classe; fundo da câmera de classes |
| LZ-CLASS | frente do palco | círculo r 7 em (0, −587) | zona "Classes": abre a tela de classes ao entrar; avental de piso 18 × 13 |
| LZ-FOOD | food court (POI) | X −56..−16, Z −600..−565 | trailer AST-027 parado (só casca), 3 mesas de piquenique, lixeira |
| LZ-SHOP | Gem Shop | quiosque X −41..−34,3, Z −633..−607; zona r 5,5 em (−29, −620) | quiosque AST-104 sempre aberto + 6 pedestais; avental 10 × 24 para fila |
| LZ-GARDEN | jardim atrás da loja (POI) | X −56..−41, Z −633..−607 | árvores, floreira; canto calmo, aberto nas duas pontas (15 de largura) |
| LZ-FOUNTAIN | fonte (POI) | círculo r ~11 em (−34, −654) | fonte Ø 12 + 4 bancos virados para ela |
| LZ-CODES | canto dos códigos | mural em Z −655,6, X −15,4..−4,6; zona r 5 em (−10, −650,5) | mural "CODES"; avental 12 × 9 |
| LZ-PLAZA | praça central | resto da área andável | spawn, mastro, setas, placa WELCOME |
| LZ-SQUAD | squads | X 12..38, Z −651..−589 | 8 plataformas em 2 fileiras (folga 10), quadros |
| LZ-START | embarque | X 38..50,4, Z −633..−607 | letreiro "START SHIFT" no meio-fio, van da crew na rua |
| LZ-PHOTO | cabine de foto (POI) | X 28..34, Z −573,2..−568,8 | cabine procedural, sem mecânica (decoração; P-L19) |
| LZ-BENCH-SE | arquibancada (POI) | X 12..48, Z −675..−651 | 2 bancos virados para as plataformas, árvore |
| — | cenário fora do limite | prédios (Z > −565, Z < −675, X < −56), rua X 48..72, cartões X ≥ 73,5 | fundo |

## V2-4. Pontos-chave (`MapPoint`, pasta `workspace.MapBinding.Lobby`)

Mesmas regras da v1 (§5 do anexo): `Part` 1³ invisível, `PointId`, `LookVector` horizontal, posição = piso.

| `PointId` | Posição WORLD (X, Y, Z) | Frente | Uso |
|---|---|---|---|
| `LOBBY-SPAWN` | (5, 0, −620) | +Z (olha o palco) | spawn; `LobbyService` espalha ±3 (SPREAD 6) dentro do medalhão Ø 8 |
| `LOBBY-CLASS-STAGE` | (0, 1,02, −575,5) | −Z (olha a câmera) | rig da classe, no centro do palco |
| `LOBBY-CLASS-CAM` | (0, 4,5, −587,5) | +Z; `Pitch` 2,39, `Fov` 50 | câmera da tela de classes (§V2-11) |
| `LOBBY-SHOP` | (−29, 0, −620) | −X (olha o balcão) | centro da zona Shop |
| `LOBBY-CODES` | (−10, 0, −650,5) | −Z (olha o mural) | centro da zona Codes |
| `LOBBY-SQUAD-1` | (16, 0,3, −647) | +X (olha o quadro) | plataforma 1 (fileira de perto) |
| `LOBBY-SQUAD-2` | (16, 0,3, −629) | +X | plataforma 2 |
| `LOBBY-SQUAD-3` | (16, 0,3, −611) | +X | plataforma 3 |
| `LOBBY-SQUAD-4` | (16, 0,3, −593) | +X | plataforma 4 |
| `LOBBY-SQUAD-5` | (34, 0,3, −647) | +X | plataforma 5 (fileira de longe) |
| `LOBBY-SQUAD-6` | (34, 0,3, −629) | +X | plataforma 6 |
| `LOBBY-SQUAD-7` | (34, 0,3, −611) | +X | plataforma 7 |
| `LOBBY-SQUAD-8` | (34, 0,3, −593) | +X | plataforma 8 |
| `LOBBY-START` | (44,5, 0, −620) | +X (olha a van) | âncora do "poof" e da partida da van (não é zona) |

Numeração: da esquerda para a direita de quem está no spawn olhando para a van (+X; esquerda = −Z), fileira de perto
1–4, fileira de longe 5–8. O número fica no piso da plataforma e no quadro.

## V2-5. Zonas (`Content.Lobby.Zones`)

| Key | Panel | Centro (WORLD) / `PointId` | Raio | Cor do anel |
|---|---|---|---|---|
| Classes | Classes | (0, 0, −587) / nenhum | **7** | MUSTARD |
| Shop | Shop | (−29, 0, −620) / `LOBBY-SHOP` | **5,5** | MINT |
| Codes | Codes | (−10, 0, −650,5) / `LOBBY-CODES` | **5** | azul (atual) |
| Squad1..8 | Platform (1..8) | ver §V2-4 / `LOBBY-SQUAD-n` | 4 (= raio do disco) | estado (Free/Busy/Starting) |

A zona Classes encosta no bloco do palco (borda em Z −580) e contém o olho da câmera (−587,5): continua valendo esconder
os personagens enquanto a tela está aberta (v1 §11).

## V2-6. Distâncias do `LOBBY-SPAWN` (5, −620), planas

| Alvo | Centro | Até a borda da zona | ≤ 40? |
|---|---|---|---|
| Classes (0, −587) | 33,4 | 26,4 | sim |
| Shop (−29, −620) | 34,0 | 28,5 | sim |
| Codes (−10, −650,5) | 34,0 | 29,0 | sim |
| Squad 2 / 3 | 14,2 | 10,2 | sim |
| Squad 1 / 4 | 29,2 | 25,2 | sim |
| Squad 6 / 7 | 30,4 | 26,4 | sim |
| Squad 5 / 8 (as mais longe) | **39,6** | 35,6 | sim |
| `LOBBY-START` | 39,5 | — | sim |

Por isso o spawn está em X 5 e não em X 0: com folga de 10 entre plataformas, X 5 é o menor deslocamento que põe as 8 a
≤ 40. O palco continua centrado no HQ (X 0); do spawn ele aparece 9° à esquerda, sem prejuízo.

Linhas de visão (de pé no spawn, olhando +Z): fachada "CORNER DOGS / HQ", carrinho e palco à frente; trailer do food
court à frente-direita; "GEM SHOP" à direita (−X); "START SHIFT" + van à esquerda (+X), atrás das plataformas; mastro e
"CODES" atrás. Os 4 letreiros grandes continuam sendo os 4 marcos cardeais; o mastro com o cachorro-quente neon (19 de
altura) é o "norte" do centro, visível de qualquer canto.

Corredores (larguras mínimas): entre plataformas 10; plataforma 4/8 ↔ bloco do palco 9; mesas ↔ LW-TRUCK 6,8;
food court ↔ quiosque 18; quiosque ↔ fonte 11; fileira de longe ↔ meio-fio 10. Nenhum beco sem saída (o vão entre o
trailer e o palco foi fechado pelo LW-TRUCK).

## V2-7. Layout das áreas

### V2-7.1 HQ e palco de classes (norte)

- Tudo da v1 **deslocado +5 em Z** (fachada em Z −565): carrinho AST-026 em (0, 0, −567,8), mesmas estações de enfeite
  (sem tags), placa OPEN em (−13,5, 0, −574).
- **Palco 20 × 7**: X −10..10, Z −579..−572, topo Y 1,0. Rig no centro (0, 1,02, −575,5). Mesma relação câmera ↔ rig ↔
  filete neon ↔ letreiro da v1 (distâncias 12 / 8,36 / 22,9), então o enquadramento da v1 vale; o palco mais largo
  preenche a largura do quadro.
- Vasos AST-102 no palco em X ±5,3 e ±8,8 (Z −572,6), dentro do quadro como enfeite. Postes de luz do palco **em cima**
  do palco, nos cantos da frente (X ±9,2, Z −578,6): fora do quadro (meia-largura 7,4 nessa profundidade) e fora do piso
  da praça.
- Cordão baixo (y 2,0) de X −10,6 a 10,6 em Z −579,7 (dentro do bloco); floreiras AST-034 em X ±13,5.
- **LW-STAGE** X −16..16, Z −580..−565. **Avental** de piso 18 × 13 em frente (§V2-12.8). Zona r 7.

### V2-7.2 Food court (noroeste, POI)

- Trailer AST-027 (só casca, **sem** tag `Vehicle`), pivô (−36, 0, −571,5), rotY 0: janela para −Z (praça), corpo
  X −50..−22, Z −577,5..−565,5, engate até X −54,5. Bloco **LW-TRUCK** X −56..−16, Z −578..−565 (não se sobe no trailer
  e o vão até o palco some). Árvore pequena e o poste SL-D ficam dentro desse vão, como cenário.
- 3 mesas AST-100 em Z −587, X −46 / −36 / −26; lixeira em (−20, −584). Luz quente L-TRUCK sob a janela.

### V2-7.3 Gem Shop (oeste)

- Quiosque AST-104 **solto na praça** (não encostado na borda, senão passaria de 40 do spawn): pivô (−37,5, 0, −620),
  rotY −90 (frente para +X), sem as portas de enrolar. Fachada X −34,03, Z −632,95..−607,05.
- Pedestais (X −36,375): P1 −610, P2 −613, P3 −616, P4 −624, P5 −627, S1 −630. Gemas neon nos `Mini_Anchor` (y 4,2).
- Letreiro "GEM SHOP" na âncora `Neon_Upgrades` → (−34,0, 9,75, −620); placas laterais (−34,3, 9,75, −609,5 / −630,5).
- **Avental de fila** 10 × 24 (X −34..−24) livre de objetos; zona r 5,5. **LW-SHOP** X −41..−34,3, Z −633..−607.
- **Jardim** atrás (X −56..−41): 2 árvores grandes, floreira de arbustos encostada no fundo do quiosque, caixa de correio.

### V2-7.4 Squads (leste)

- 8 discos Ø 8, topo 0,3, em 2 fileiras: X 16 (1–4) e X 34 (5–8), Z −647 / −629 / −611 / −593. Passo 18 = **folga de
  10** entre bordas nos dois eixos. **Pisar = entrar** (DEC-179); o painel de squad abre ao entrar (zona Platform).
- Quadro AST-024 de cada plataforma a +5,6 em X (X 21,6 e 39,6), virado para −X (para o spawn): "SQUAD n", "n/4",
  nomes, contagem. 4 marcas AST-019 por disco (±1,8).
- A rota "SQUAD UP" (setas Ketchup) passa pelo corredor Z −625..−615 entre as plataformas 2/3 e 6/7 e termina no START.

### V2-7.5 Start Shift (leste, meio-fio)

- Letreiro "START SHIFT" maior (texto altura 2,0, ~19 de largura) no meio-fio, X 49,4, Z −630,5..−609,5; postes SL-F e
  SL-G (X 44, Z −602 / −638) emolduram o embarque.
- Van AST-035 em (54,5, −0,24, −620), lateral para a praça. `LOBBY-START` (44,5, 0, −620).
- Do outro lado da rua: pickup e sedan parados (vida na rua). O trailer saiu da rua e virou o food court.

### V2-7.6 Codes (sul)

- Mural maior (10 × 4,4) em (−10, 3,7, −655,6), virado para +Z, telhado Ketchup, neon "CODES" altura 1,4. Panfletos
  AST-037. Avental 12 × 9 à frente, zona r 5.
- Atrás do mural (Z −657..−675): mesa de piquenique, lixeira.

### V2-7.7 Pontos de interesse

| POI | Onde | O que tem | Por quê |
|---|---|---|---|
| Mastro do varal | (5, −628,5), atrás do spawn | floreira Ø 4, mastro Ø 0,8 até y 18,5, anel neon a y 16 onde os 8 vãos do varal se prendem, cachorro-quente neon dupla-face no topo | marco central; o varal vira uma "tenda de luzes" sobre a praça |
| Fonte | (−34, −654) | bacia Ø 12 (12 segmentos de mureta 1,2), água rasa, coluna + tigela, 4 jatos, ícone neon; 4 bancos AST-034 em volta | lugar para sentar e esperar amigos; enche o sudoeste |
| Food court | noroeste | trailer AST-027 + 3 mesas AST-100 | mostra o veículo do jogo; ponto de encontro |
| Cabine de foto | (31, −571) | cabine procedural 6 × 4,4 × 7,9, cortina, banco, flash neon, letreiro "PHOTO", adesivo no piso | diversão social (screenshot); enche o nordeste |
| Arquibancada | (22 e 30, −657) | 2 bancos virados para as plataformas, árvore, lixeira | quem espera o squad assiste as contagens |

## V2-8. Fluxo do jogador

1. Nasce no medalhão olhando o palco; setas neon saem do medalhão para os 4 destinos.
2. Classes: 26 studs até a borda da zona, painel abre ao entrar.
3. Loja à direita, códigos atrás, ambos opcionais.
4. Squad: segue as setas Ketchup até uma plataforma livre; amigos pisam na mesma; o dono configura e inicia no painel.
5. Contagem (5 s) → "poof" no `LOBBY-START`, a van sai → teleporte. Volta da run: spawn.

## V2-9. NPCs

Nenhum NPC de servidor (teto 0). Rig de classe: 1 local por client. Bichos sentados nos bancos/mesas continuam fora do
escopo (P-L14).

## V2-10. Iluminação (14 luzes locais, 1 com sombra; `Lighting` intocado)

| ID | Tipo | Posição WORLD | Mira / dados | Cor | Brilho / alcance | Sombra |
|---|---|---|---|---|---|---|
| L-KEY | SpotLight | (−9,2, 8,0, −578,6) | lookAt (0, 3,6, −575,5); Angle 45 | `#FFE7C2` | 4 / 16 | **sim** |
| L-FILL | SpotLight | (9,2, 6,6, −578,6) | lookAt (0, 3,6, −575,5); Angle 55 | CREAM | 1,5 / 14 | não |
| L-RIM | SpotLight | (0, 6,8, −572,0) | lookAt (0, 4,2, −575,5); Angle 60 | Teal `#3FA7B5` | 1,2 / 8 | não |
| L-HQ | PointLight | (0, 10,5, −567,5) | — | (255, 200, 120) | 1,4 / 18 | não |
| L-SHOP | PointLight | (−36,5, 8,0, −620) | — | `#FFE7C2` | 1,2 / 16 | não |
| L-CODES | SpotLight | (−10, 7,0, −653,6) | lookAt (−10, 3,7, −655,4); Angle 70 | CREAM | 1,5 / 9 | não |
| L-TRUCK | PointLight | (−36, 7,0, −579,0) | sob a janela do trailer | `#FFE7C2` | 1,2 / 16 | não |
| L-FOUNTAIN | PointLight | (−34, 2,0, −654) | — | Teal `#3FA7B5` | 1,0 / 12 | não |
| L-SL-A, B, C, F, G, H | SpotLight na `LampHead`, para baixo | cúpulas de SL-A/B/C/F/G/H | Angle 100 | sódio `#FFB25A` | 1,2 / 18 | não |

SL-D e SL-E (perto do HQ, já iluminado por L-HQ) ficam só com a cúpula Neon, sem luz real. Nenhum coral `#FF8A65`.

## V2-11. Câmera da tela de classes

`CFrame.lookAt(Vector3.new(0, 4.5, -587.5), Vector3.new(0, 5.0, -575.5))`, FOV 50; variante com UI à esquerda: X −3 nos
dois pontos. Igual à v1 deslocada +5 em Z. Conferido no papel: postes de luz do palco (X ±9,2), postes do cordão
(±10,6), floreiras (±13,5) fora do quadro; os vãos do varal SL-D/SL-E passam em |X| ≥ 13,6 depois do plano da câmera
(meia-largura ≤ 15,4 só no fim, onde o vão está em |X| ≥ 18) — **conferir no Studio**; trailer e cabine fora do quadro.

## V2-12. Peças procedurais (`Decor.runLobby`, WORLD)

Mesmas cores, `neonText` / `neonShape`, regras de colisão e glifos da v1 (§12 do anexo). Glifos novos: nenhum
("PHOTO" usa P, H, O, T, já existentes).

### V2-12.1 Letreiro do HQ (fachada do BK4, Z −565)

Todas as peças da v1 §12.1 com **Z +5**: placa (0, 11,6, −564,6) 26 × 4,8 × 0,3; molduras em Z −564,78; neon
"CORNER DOGS" e "HQ" em Z −564,95; ícones de cachorro-quente com origem (−8,42 / 11,48, 9,46, −564,95); placa
"BRAMBLE'S" (0, 14,75, −564,6). Conferir o plano da parede por raycast.

### V2-12.2 Gem Shop

| Peça | Medidas | Posição WORLD | Cor |
|---|---|---|---|
| `Neon_GemShop` | `neonText("GEM SHOP", 1,1)` (pode subir para 1,4 se couber na placa) | `lookAt((−34,0, 9,75, −620), +X)` | MINT |
| `Neon_Gem` ×2 | losango da v1, k 0,3 | (−34,0, 9,3, −609,5 + 0,6) e (−34,0, 9,3, −630,5 + 0,6), frente +X | MINT |
| `Gem_P1..P5` | cubo 0,9³ girado (v1) | (−36,375, 4,2, Z): −610, −613, −616, −624, −627 | Neon MINT, `Spin` |
| `Gem_S1` | 1,2³ | (−36,375, 4,2, −630) | Neon MUSTARD |

### V2-12.3 Plataformas de squad (×8)

Centros (Xc, Zc): 1 (16, −647), 2 (16, −629), 3 (16, −611), 4 (16, −593), 5 (34, −647), 6 (34, −629), 7 (34, −611),
8 (34, −593).

| Peça | Medidas | Posição | Dados |
|---|---|---|---|
| `SquadPad_n` | Cylinder Ø 8 × 0,3 | (Xc, 0,15, Zc) | CREAM, `CanCollide`; tag `PartyPlatform`, `Party` = n |
| `SquadPadRim_n` | Cylinder Ø 8,5 × 0,2 | (Xc, 0,1, Zc) | Neon KETCHUP (estados pelo client) |
| `SquadPadNumber_n` | Part 3,2 × 0,02 × 3,2 invisível + SurfaceGui Top | (Xc, 0,31, Zc), girada −90° | "n" KETCHUP, legível vindo de −X |

### V2-12.4 START SHIFT (meio-fio)

| Peça | Medidas | Posição WORLD | Cor |
|---|---|---|---|
| `Start_Post` ×2 | 0,4 × 11,8 × 0,4 | (49,4, 5,9, −630,5) e (49,4, 5,9, −609,5) | INK, colide |
| `Start_Board` | 0,3 × 4,4 × 21 | (49,4, 9,4, −620) (y 7,2..11,6) | INK |
| `Neon_StartShift` | `neonText("START SHIFT", 2,0)` (~19,3) | `lookAt((49,2, 10,2, −620), −X)` | KETCHUP |
| `Neon_StartArrow` | seta da v1, k 0,6 | origem (49,2, 7,6, −617,5), frente −X | MUSTARD |

### V2-12.5 Mural CODES

| Peça | Medidas | Posição WORLD | Cor |
|---|---|---|---|
| `Codes_Post` ×2 | 0,6 × 6,6 × 0,6 | (−15,4, 3,3, −655,6) e (−4,6, 3,3, −655,6) | madeira, colide |
| `Codes_Frame` | 10,6 × 5,0 × 0,3 | (−10, 3,7, −655,75) | madeira escura |
| `Codes_Board` | 10 × 4,4 × 0,4, face +Z | (−10, 3,7, −655,6) | cortiça; SurfaceGui (texto da v1) |
| `Codes_Roof` | 11,4 × 0,4 × 1,4 | (−10, 6,8, −655,6) | KETCHUP |
| `Codes_SignBack` | 7,0 × 1,8 × 0,2 | (−10, 7,8, −655,6) | INK |
| `Neon_Codes` | `neonText("CODES", 1,4)` (~6,1) | `lookAt((−10, 7,8, −655,4), +Z)` | CREAM |

### V2-12.6 Palco de classes

| Peça | Medidas | Posição WORLD | Cor |
|---|---|---|---|
| `Stage_Body` | 20 × 0,9 × 7 | (0, 0,45, −575,5) | KETCHUP, colide |
| `Stage_Top` | 20,2 × 0,1 × 7,2 | (0, 0,95, −575,5) | PAD `#E8D9B5`, colide |
| `Stage_Edge` | 20,2 × 0,08 × 0,08 | (0, 0,96, −579,14) | Neon MUSTARD |
| `Stage_SpotRing` / `Stage_Spot` | Ø 3,9 × 0,03 / Ø 3,6 × 0,04 | (0, 0,995 / 1,0, −575,5) | Neon CREAM / MUSTARD |
| `Stage_Rope` | 4 segmentos Ø 0,15, barriga 0,35 | de (−10,6, 2,0, −579,7) a (10,6, 2,0, −579,7) | KETCHUP |
| `StageLight_*` ×2 | haste 0,35 × (topo − 1,0) a partir do tampo; pé 1,2 × 0,3 × 1,2 em y 1,15; cabeça 1,0 × 0,8 × 1,2 + lente Neon | cabeças em (−9,2, 8,0, −578,6) e (9,2, 6,6, −578,6), miram (0, 3,6, −575,5) | INK / lente CREAM |

### V2-12.7 Lâmpadas de varal (tenda radial)

Vãos do **anel do mastro (5, 16,0, −628,5)** até o eixo de cada poste a **y 11,5**; barriga **2,5** (`sin(πt)`); fio 0,06
INK; lâmpada Ball Ø 0,32 Neon a cada **~2,6**, 0,22 abaixo do fio, ciclo MUSTARD/CREAM/KETCHUP/MINT. ~180 lâmpadas.

| Vão | Até o pé do poste | Comprimento plano |
|---|---|---|
| V-A | SL-A (−52, −671) | 71,1 |
| V-B | SL-B (44, −671) | 57,7 |
| V-C | SL-C (−52, −600) | 63,7 |
| V-D | SL-D (−19, −569) | 64,2 |
| V-E | SL-E (19, −569) | 61,1 |
| V-F | SL-F (44, −602) | 47,2 |
| V-G | SL-G (44, −638) | 40,1 |
| V-H | SL-H (−52, −640) | 58,1 |

Ponto mais baixo ≈ y 11,25: passa acima das cúpulas (~14,5 no topo do poste, cúpula ~13) e das placas.

### V2-12.8 Aventais de piso (fila)

`Part` 0,04 de altura, `CanCollide` falso, PAD `#E8D9B5` SmoothPlastic, com filete Neon 0,1 × 0,05 na borda da cor da zona.

| Peça | Tamanho (X × Z) | Centro | Filete |
|---|---|---|---|
| `Apron_Classes` | 18 × 13 | (0, 0,02, −586,5) | MUSTARD |
| `Apron_Shop` | 10 × 24 | (−29, 0,02, −620) | MINT |
| `Apron_Codes` | 12 × 9 | (−10, 0,02, −650,5) | CREAM |

### V2-12.9 Mastro do varal

| Peça | Medidas | Posição WORLD | Cor |
|---|---|---|---|
| `Mast_Planter` | Cylinder Ø 4 × 1,2 (vertical) | (5, 0,6, −628,5) | madeira escura, colide |
| `Mast_Soil` | Cylinder Ø 3,6 × 0,1 | (5, 1,2, −628,5) | (95, 70, 50) |
| `Mast_Pole` | Cylinder Ø 0,8 × 17,3 (vertical) | (5, 9,85, −628,5) (y 1,2..18,5) | INK, colide |
| `Mast_Ring` | Cylinder Ø 2,4 × 0,25 (deitado) | (5, 16,0, −628,5) | Neon MUSTARD (amarração dos vãos) |
| `Mast_Topper` | 2 `Neon_HotDog` (traços do HQ, k 0,55, ~3,7 × 1,4) costas com costas | origem (6,65, 18,8, −628,4) virado +Z e (3,35, 18,8, −628,6) virado −Z | pão/salsicha/mostarda; tag `NeonSign`, `Flicker` falso |

Arbusto AST-102_Bush sobre a floreira (placements).

### V2-12.10 Setas neon no chão (do spawn (5, −620))

Chevron e rótulo como na v1 (§12.8). Rótulo = 4,5 ao longo da rota, centro a 6,6 do spawn.

| Destino | Cor | Pontas dos chevrons (X, Z) | Direção | Rótulo (centro) |
|---|---|---|---|---|
| Classes | MUSTARD | (3,50, −610,11), (2,75, −605,17), (2,00, −600,22), (1,25, −595,28) | (−0,150; 0,989) | "CLASSES" (4,01, −613,47) |
| Squads/Start | KETCHUP | (16, −620), (21, −620), (25, −620), (30, −620), (35, −620), (40, −620) | +X | "SQUAD UP" (11,6, −620) |
| Gem Shop | MINT | (−5, −620), (−10, −620), (−15, −620), (−20, −620) | −X | "GEM SHOP" (−1,6, −620) |
| Codes | CREAM | (0,15, −629,87), (−2,06, −634,35), (−4,26, −638,84), (−6,47, −643,32) | (−0,441; −0,897) | "CODES" (2,09, −625,92) |

O rótulo CODES passa a 3,9 do eixo do mastro (raio da floreira 2): livre.

### V2-12.11 Medalhão do spawn

Cylinder Ø 8 × 0,04 CREAM em (5, 0,02, −620) sobre anel Neon MUSTARD Ø 8,4 × 0,02 em (5, 0,01, −620); rótulo
"SELL HOTDOGS!" 5 × 2 girado 180° (v1).

### V2-12.12 Fonte (−34, ·, −654)

| Peça | Medidas | Posição | Cor / dados |
|---|---|---|---|
| `Fountain_Floor` | Cylinder Ø 12 × 0,3 | (−34, 0,15, −654) | pedra (200, 190, 170), colide |
| `Fountain_Wall` ×12 | bloco 3,1 × 1,2 × 0,8, tangente ao círculo | raio 5,6, ângulos 0°, 30°, …, 330°, y 0,6 | PAD, colide |
| `Fountain_Cap` ×12 | 3,3 × 0,2 × 1,0 | sobre cada mureta, y 1,3 | CREAM, colide |
| `Fountain_Water` | Cylinder Ø 10,6 × 0,1 | (−34, 0,85, −654) | Teal (63, 167, 181), Transparency 0,35, Reflectance 0,1, sem colisão; atributo `Ripple` (client opcional) |
| `Fountain_Column` | Cylinder Ø 1,6 × 3,4 (vertical) | (−34, 2,0, −654) | PAD, colide |
| `Fountain_Bowl` | Cylinder Ø 5 × 0,5 | (−34, 3,95, −654) | PAD, colide |
| `Fountain_BowlWater` | Cylinder Ø 4,4 × 0,06 | (−34, 4,21, −654) | Teal, Transparency 0,35 |
| `Fountain_Jet` ×4 | 0,25 × 0,25 × 3,2 inclinado, da borda da tigela (raio 2,2, y 4,3) ao raio 4,4, y 1,0 | 4 direções (±X, ±Z) | Neon (150, 230, 235), Transparency 0,4, sem colisão |
| `Fountain_Icon` ×2 | `Neon_HotDog` k 0,4 costas com costas | centro (−34, 4,9, −654), frentes +X e −X | cores do HQ |

Dentro da bacia o piso fica em y 0,3 e a água em 0,85: dá para entrar "com os pés na água".

### V2-12.13 Cabine de foto (31, ·, −571), frente −Z

| Peça | Medidas | Posição WORLD | Cor |
|---|---|---|---|
| `PB_Floor` | 6 × 0,3 × 4,4 | (31, 0,15, −571) | INK, colide |
| `PB_Back` | 6 × 7,2 × 0,4 | (31, 3,9, −569,0) | KETCHUP, colide |
| `PB_Side` ×2 | 0,4 × 7,2 × 4,4 | (28,2, 3,9, −571) e (33,8, 3,9, −571) | KETCHUP, colide |
| `PB_Roof` | 6,6 × 0,4 × 5,0 | (31, 7,7, −571) | CREAM |
| `PB_Lintel` | 6 × 1,2 × 0,4 | (31, 6,9, −573,0) | KETCHUP |
| `PB_Curtain` | 2,6 × 5,2 × 0,1 | (29,7, 3,6, −573,1) | MINT `Fabric`, sem colisão |
| `PB_Seat` | 4,6 × 1,4 × 1,2 | (31, 1,0, −569,8) | madeira, colide |
| `PB_Screen` | 2,4 × 1,6 × 0,1, face −Z | (31, 4,6, −569,15) | INK + SurfaceGui "SMILE!" |
| `PB_Flash` | 0,6 × 0,6 × 0,1 | (31, 5,8, −569,15) | Neon CREAM, atributo `Flicker` |
| `PB_SignBack` | 7 × 1,8 × 0,3 | (31, 9,0, −572,9) | INK |
| `Neon_Photo` | `neonText("PHOTO", 1,2)` (~5,3) | `lookAt((31, 9,0, −573,1), −Z)` | CREAM |
| `PB_FloorSticker` | 3 × 0,04 × 3, SurfaceGui Top | (31, 0,03, −576) | "SAY CHEESE!" KETCHUP (texto: narrative-writer) |

### V2-12.14 Paredes invisíveis (altura 30, como na v1)

| ID | Centro WORLD | Tamanho (X × Y × Z) | Limite |
|---|---|---|---|
| LW-N | (−2,8, 15, −564,5) | 108,4 × 30 × 1 | Z −565 |
| LW-S | (−2,8, 15, −675,5) | 108,4 × 30 × 1 | Z −675 |
| LW-W | (−56,5, 15, −620) | 1 × 30 × 112 | X −56 |
| LW-E | (50,9, 15, −620) | 1 × 30 × 112 | X 50,4 (fim do meio-fio) |
| LW-STAGE | (0, 15, −572,5) | 32 × 30 × 15 | palco + carrinho (X −16..16, Z −580..−565) |
| LW-SHOP | (−37,65, 15, −620) | 6,7 × 30 × 26 | quiosque (X −41..−34,3, Z −633..−607) |
| LW-TRUCK | (−36, 15, −571,5) | 40 × 30 × 13 | trailer + vão até o palco (X −56..−16, Z −578..−565) |

## V2-13. Assets (todos já uploadados, `Assets/import/_asset_ids.json`)

Os mesmos da v1 §13.1, mais: `AST-034_TreeLarge` (107743358507003), `AST-100_PlanterBushes` (128106434462936),
`AST-102_Bush` (115530885982613), `AST-035_CarPickup` (121980743977812); o `AST-027_OpenLateTrailer` passa da rua para
o food court. Nada novo para o art-director/modeler-3d. Fonte e cabine de foto são procedurais (sem malha nova).
Crédito: **AST-100** (CC-BY 3.0, J-Toastie) passa a ter 4 mesas no lobby → art-director confere a linha "Usado em" do
`credits.md`.

## V2-14. Requisitos técnicos e orçamento

| Item | Valor |
|---|---|
| NPCs de servidor | 0 |
| Avatares | 30 R15, colisão jogador × jogador desligada (DEC-175) |
| Triângulos (estimativa) | ~85 mil: 19 prédios ~47k, cartões ~3k, carrinho 7,2k, trailer 4,5k, quiosque + pedestais 6k, 3 veículos ~4k, árvores/bancos/mesas ~12k ≤ 120 mil (AST-089) |
| Instâncias | ~170 assets + ~950 Parts procedurais (~180 lâmpadas + ~190 fios, ~350 tubos de neon, fonte ~35, cabine 13, plataformas 24, setas ~40) |
| Luzes locais | 14, 1 com sombra |
| VFX de zona | 11 zonas (3 + 8 plataformas); sugerir `Rings.ActiveDistance` / `ZoneVfx.ActiveDistance` 110 (diagonal da praça ~150) |
| Streaming | igual à v1: raiz do lobby e `MapBinding.Lobby` **Persistent** (P-L9) |

## V2-15. Pendências novas (secretário registra como `Q-###`; todas com valor Provisório já aplicado)

| ID | Pergunta | Provisório |
|---|---|---|
| P-L15 | 8 plataformas: `PartyRules.Platforms` = 8, `Net` `Platform = Lync.int(0, 8)`, comentários "1..4" no PartyService/ModuxTypes | architect + backend-coder |
| P-L16 | "Espaçadas ≥ 10": folga entre bordas (adotado, passo 18) ou centro a centro (passo 10)? | folga de 10 |
| P-L17 | Trailer AST-027 parado no food court (sem tag, só casca) em vez de teaser do outro lado da rua | sim |
| P-L18 | Spawns extras `LOBBY-SPAWN-2..n` (o `LobbyService` já aceita) para 30 entradas ao mesmo tempo | 1 spawn + SPREAD 6 basta (colisão desligada) |
| P-L19 | Cabine de foto vira mecânica (pose/screenshot)? | só decoração |
| P-L20 | Água da fonte animada (partículas no client) | estática; atributo `Ripple` reservado |
| P-L21 | Edições à mão do usuário no lobby v1 em Studio se perdem no rebuild | sincronizar/registrar antes de `runInto(..., true)` |

## V2-16. Critérios de aceite do layout v2

1. Todas as zonas com centro a ≤ 40 do `LOBBY-SPAWN` (§V2-6).
2. 30 avatares R15 em pé ao mesmo tempo (8 × 4 nas plataformas, sobra no avental de classes) sem bloquear nenhum corredor
   da §V2-6.
3. A câmera da §V2-11 mostra o rig inteiro e o "CORNER DOGS" inteiro, sem poste, cordão, vão do varal ou planta cortando o rig.
4. Ninguém sai da área, sobe no palco, no quiosque ou no trailer (§V2-12.14); nenhum beco sem saída.
5. No celular, do spawn, os 4 letreiros e o mastro aparecem girando a câmera, sem andar.
6. ≤ 14 luzes locais, 1 com sombra; `Lighting` sem alteração.

---

# Anexo — LOBBY v1 (substituída pela v2; só histórico)

## 1. Resumo

| Item | Valor |
|---|---|
| Tema | quarteirão do QG da Bramble's ao entardecer: o **Corner Cart original** exposto como vitrine, letreiros de neon em tubo, lâmpadas de varal, prédios baixos de Bellmoor em volta. Fofo e acolhedor, sem horror (DEC-008) |
| Função no loop | formar party de 1–4 por **plataformas físicas** (DEC-179), escolher classe (DEC-069, DEC-186), loja de gemas, códigos, iniciar o turno ("Start Shift") → teleporte para o servidor reservado (FEAT-001) |
| Jogadores | 1 a N no servidor de lobby; parties de 1–4 (DEC-012, DEC-034) |
| Desbloqueio | sempre aberto; é onde todo jogador nasce e para onde volta no fim da run |
| Turnos | nenhum (sem relógio de jogo) |
| Lugar no place | **mesma place**, região isolada: centro ~ WORLD (0, 0, −600). MAP-01 fica em Z ≥ −60 (atrás da fileira do HQ); DevScenes em Z ~4000 não são tocadas |
| Tamanho jogável | **60,4 × 60** (X −30..30,4; Z −630..−570); piso da praça X −30..28 + meio-fio 28..30,4 |
| Regra de distância | todo ponto de interação a **≤ 25 studs** do spawn (§6) |

## 2. Convenções e escala

- **Coordenadas WORLD** (sem o `MAP_FRAME` do MAP-01). +Y para cima. Neste documento "fundo" = +Z (lado do HQ, do lado do
  MAP-01), "frente" = −Z, "oeste" = −X (loja), "leste" = +X (rua, van).
- Piso da praça: topo em **Y 0**. Asfalto da rua: **Y −0,24**. Palco: topo **Y 1,0**. Plataformas de squad: topo **Y 0,3**.
- `rotY` em graus, pose = `CFrame.new(x, y, z) * CFrame.Angles(0, rad(rotY), 0)`. Frente de assets modelados = `LookVector`
  (rotY 0 → −Z, 90 → −X, 180 → +Z, −90 → +X). Prédios Kenney e cartões: fachada = local +Z (oposto). Detalhes no cabeçalho
  do `LOBBY_placements.luau`.
- Personagem R6 ~5 de altura, olho a 4,5 (style guide §3). Diagrama: 1 coluna ≈ 2 studs, aproximado; **a tabela de
  coordenadas é a fonte da verdade**.
- Quem nasce no spawn olha para **+Z**: a direita dele é **−X** (loja) e a esquerda é **+X** (squads, van).

## 3. Mapa geral (ASCII, aproximado)

```
          X → -30      -20       -10        0        10        20    28 30.4   40      52
              |         |         |         |         |         |     | |      |       |
Z -556    [BK-1 H ][ BK-2 A  ][   BK-3 H  (HQ)  ][ BK-4 A  ] arbusto   RE-N (cartão)
Z -570   =====+================= LW-N (parede invisível) ==================+=+==BAR====+
              |SL-C  BN-2   ~~ NEON "CORNER DOGS / HQ" (y 9,2-14,0) ~~  SL-D|c|┌─────┐ |RC-1
Z -573        |      ▓▓▓▓▓▓▓ CARRINHO AST-026 (X -14,75..14,75) ▓▓▓▓▓▓▓     |c|│ TRL │ |
Z -577        | T1   sinal  [vaso] ┌── PALCO 12 × 7 ──┐ [vaso]       T2     |c|│ 027 │ |RC-2
Z -580.5      |                    │     ★ RIG        │                     |c|│     │ |
Z -585        |   PL  ░░░░░░░ Q ───┴─ cordão y 2,0 ───┴─ Q ░░░░░░ PL  (SQ1)[B]|c|└─────┘ |
Z -588   ┌────┤ (luz K)                ◎ CÂMERA            (luz F)     (SQ1)[B]|c|        |
Z -590   │    │P1                      ^                                     |c|        |
Z -596   │ L  │P3                      ^ CLASSES                     (SQ2)[B]|c|  VAN   |RC-3
Z -600   │ O  │▣ SHOP   <  <  <  GEM SHOP                                   |c|▄▄▄▄▄▄  |
Z -602   │ J  │                        ✚ SPAWN   >  >  >  SQUAD UP     ★ START |c|AST-035|
Z -604   │ A  │P4                     /                              (SQ3)[B]|c|▀▀▀▀▀▀  |
Z -610   │    │S1                   /  CODES                                 |c|        |RC-4
Z -614   └────┤vaso               /                                  (SQ4)[B]|c| sedan  |
Z -618        |caixa correio    /                                            |c|        |
Z -622.5      |  PICNIC      ◇ CODES                       BN-1      hidrante|c|        |
Z -626        |SL-A     [ MURAL CODES ]  lixeira                      SL-B   |c|        |RC-5
Z -630   =====+================= LW-S (parede invisível) ==================+=+==BAR====+
Z -643    [FR-1 A ][ FR-2 H  ][ FR-3 A  ][ FR-4 H  ] arbusto              RE-S (cartão)
```

Legenda: `✚` spawn · `★` ponto de rig / start · `◎` câmera da tela de classes · `◇` ponto dos códigos · `▣` balcão da loja ·
`P1..P5, S1` pedestais da loja · `(SQn)` plataforma de squad Ø 8 · `[B]` quadro da plataforma (AST-024) · `Q` poste de fila ·
`PL` floreira · `T1/T2` árvores · `SL-A..D` postes (cordões de lâmpadas entre eles, §12.7) · `|c|` meio-fio + parede LW-E ·
`░` bloco invisível do palco · `> ^ < /` setas neon no chão (§12.8).

## 4. Zonas nomeadas

| ID | Zona | Limites (WORLD) | Função |
|---|---|---|---|
| LZ-HQ | HQ + palco de classes | X −16..16, Z −585..−570 (bloco invisível) | vitrine do carrinho original; rig da classe escolhida; fundo da câmera de classes |
| LZ-SHOP | loja de gemas (Gear Stand) | X −29..−22, Z −613..−587 (jogador não entra) | quiosque "GEM SHOP" com balcão no meio e 6 pedestais |
| LZ-SQUAD | fila de squads | X 16..26, Z −622..−584 | 4 plataformas Ø 8 + quadros; pisar = entrar (DEC-179) |
| LZ-START | embarque | meio-fio X 26..30,4, Z −611..−595 | letreiro "START SHIFT", van da crew estacionada |
| LZ-CODES | canto dos códigos | X −16..−4, Z −630..−620 | mural "CODES" + panfletos |
| LZ-PLAZA | praça | resto da área jogável | spawn, setas, bancos, mesa de piquenique |
| — | cenário fora do limite | prédios (Z < −630, Z > −570, X < −30), rua X 28..52, cartões X ≥ 52 | fundo; esconde o MAP-01 e o vazio |

## 5. Pontos-chave (`MapPoint`)

`Part` 1 × 1 × 1 invisível, `PointId` abaixo, `LookVector` horizontal (architecture §18.5). Como a regra 5 do `MapIndex`
exige `MapPoint` dentro da raiz `MapBinding`, propõe-se a pasta `workspace.MapBinding.Lobby` (Provisório, architect).
Posição = piso onde se pisa (spawn de personagem = ponto + (0, 3, 0)).

| `PointId` | Posição WORLD (X, Y, Z) | Frente (`LookVector`) | Uso |
|---|---|---|---|
| `LOBBY-SPAWN` | (2, 0, −602) | +Z (olha o palco) | spawn de quem entra e de quem volta da run; medalhão no chão (§12.9) |
| `LOBBY-CLASS-STAGE` | (0, 1,02, −580,5) | −Z (olha a câmera) | onde o rig da classe fica em pé (topo do disco do palco) |
| `LOBBY-CLASS-CAM` | (0, 4,5, −592,5) | +Z; atributos `Pitch` = 2,39 (graus, para cima), `Fov` = 50 | câmera da tela de classes (§11). Ponto em altura de olho, como `SPEC-P` do MAP-01 (P43) |
| `LOBBY-SHOP` | (−19,5, 0, −600) | −X (olha o balcão) | onde o jogador fica para abrir a loja; prompt no balcão (§7.2) |
| `LOBBY-CODES` | (−10, 0, −622,5) | −Z (olha o mural) | onde o jogador fica para abrir os códigos |
| `LOBBY-SQUAD-1` | (20, 0,3, −588) | +X (olha o quadro) | centro da plataforma 1 |
| `LOBBY-SQUAD-2` | (20, 0,3, −598) | +X | plataforma 2 |
| `LOBBY-SQUAD-3` | (20, 0,3, −608) | +X | plataforma 3 |
| `LOBBY-SQUAD-4` | (20, 0,3, −618) | +X | plataforma 4 |
| `LOBBY-START` | (26,5, 0, −603) | +X (olha a porta da van) | embarque: VFX "poof" e partida da van no início do turno; prompt alternativo (P-L1) |

Tag `PartyPlatform` (architecture §18.1) vai na **base** de cada plataforma (§12.3), com atributo `Party` = 1..4.

## 6. Distâncias (verificação de requisitos)

Do `LOBBY-SPAWN` (2, −602), distância plana:

| Alvo | Distância | ≤ 25? |
|---|---|---|
| `LOBBY-CLASS-STAGE` | 21,6 | sim |
| `LOBBY-SHOP` | 21,5 | sim |
| `LOBBY-CODES` | 23,8 | sim |
| `LOBBY-SQUAD-1` / `-2` / `-3` / `-4` | 22,8 / 18,4 / 18,4 / 24,1 | sim |
| `LOBBY-START` | 24,5 | sim |
| Prompt do palco (`Prompt_Classes`, §7.1) | 17,3 | sim |

Linhas de visão do spawn (olhando +Z): palco, carrinho e neon do HQ à frente; neon "GEM SHOP" à direita; plataformas,
"START SHIFT" e a van à esquerda; neon "CODES" atrás (girar 180°). **Um neon por lado** = 4 marcos cardeais, lidos no
celular sem minimapa.

## 7. Layout das áreas

### 7.1 HQ e palco de classes

- **Carrinho AST-026** com pivô em (0, 0, −572,8), rotY 0: lado da fila e saia com o logo (DEC-206) virados para a praça;
  fundo encostado em LW-N (Z −570). Estações da cozinha em cima como enfeite (mesmos offsets do MAP-01, **sem** tags
  `Vehicle`/`Station`): grill, trilho, caixa de pães, tábua, grade de coberturas, POS, telefone. Placa "OPEN" (AST-024) na
  ponta oeste.
- **Palco** 12 × 7 (X −6..6, Z −584..−577), topo Y 1,0, corpo Ketchup, tampo concreto `#E8D9B5`, filete Neon Mustard na
  borda da frente, disco Mustard Ø 3,6 com anel Neon Cream onde o rig pisa (§12.6). Vasos AST-102 nos cantos de trás.
- **Cordão baixo** (y 2,0) entre dois postes AST-019 em X ±7, Z −584,7; floreiras em X ±11,5. O **bloco invisível**
  LW-STAGE (X −16..16, Z −585..−570) impede subir no palco e passar atrás do carrinho.
- **Prompt "Choose Class"** (`Prompt_Classes`): `Interactable` em (0, 3,0, −585,3), na frente do cordão. Abre a tela de
  classes (câmera do §11). Botão de HUD equivalente fica a critério do frontend.
- Rig: só no client (cada jogador vê a própria classe selecionada parada no palco, idle `Lobby_ShowIdle`, AST-090). Guaxinim
  nunca (DEC-186).

### 7.2 Loja de gemas (oeste)

- **Gear Stand AST-104** reaproveitado como quiosque, pivô (−25,5, 0, −600), rotY −90 (frente para +X), **sem** as portas de
  enrolar (sempre aberto). Fachada em X −22,03, Z −612,95..−587,05, altura 11,4.
- Balcão do meio (o da Opal no Mart; **sem NPC**) = balcão da loja. `Prompt_Shop` em (−22,4, 3,5, −600) (conferir a face do
  balcão no Studio).
- 6 pedestais AST-105 (S1 + P1..P5) com uma **gema neon** procedural em cada `Mini_Anchor` (y 4,2) (§12.2). O que cada
  pedestal vende é do game-designer (P-L13); o layout aceita 6 ofertas + balcão.
- Letreiro neon **"GEM SHOP"** na âncora `Neon_Upgrades` → WORLD (−22,0, 9,75, −600); placas laterais `NamePlate_L/R` →
  (−22,3, 9,75, −589,5) e (−22,3, 9,75, −610,5).
- Bloco invisível LW-SHOP na frente dos pedestais (o jogador fica no `LOBBY-SHOP`).

### 7.3 Squads (leste)

- 4 plataformas Ø 8 em fila ao longo do meio-fio, centros X 20, Z −588 / −598 / −608 / −618 (10 de passo, 2 de folga),
  topo Y 0,3. **Pisar = entrar** (DEC-179). 4 marcas de vaga AST-019 por plataforma (±1,8 do centro).
- Quadro AST-024 de cada plataforma em X 25,3 (lado do meio-fio), virado para a praça: "SQUAD n", "n/4", nomes, e o prompt
  **"Start Shift"** (`Prompt_Start_n`, anexo a (25,0, 3,0, Z do centro)) para o dono da party.
- Proposta de estados (Provisório; alinhado com AST-088): borda neon **Ketchup** parada → marca da vaga ocupada acende
  **Mustard** → contagem de 5 s (FEAT-001) com borda **Mint** piscando → "poof" e teleporte.

### 7.4 Start Shift (leste, meio-fio)

- Letreiro neon **"START SHIFT"** (Ketchup) sobre o meio-fio em X 29,4, Z −610..−596, y 7,1..9,7 (§12.4), por cima da van.
- **Van da crew** AST-035 estacionada no asfalto em (34,5, −0,24, −603), lateral para a praça. Cores de marca pendentes (P-L7).
- `LOBBY-START` (26,5, 0, −603): onde a party "embarca" na animação de partida. O início em si é no quadro da plataforma
  (P-L1).
- Trailer AST-027 parado do outro lado (44, −0,24, −580), janela para a praça: teaser do "Open Late". Pode sair sem perder nada.

### 7.5 Códigos (frente-oeste)

- Mural freestanding 8 × 4,4 em (−10, 3,7, −626,6), virado para +Z, telhadinho Ketchup e neon **"CODES"** Cream em cima
  (§12.5). Panfletos AST-037 pregados (piscadela para a cutscene de abertura).
- `Prompt_Codes` em (−10, 3,2, −626,1). Mesa de piquenique AST-100, lixeira e caixa de correio fazem o canto.

## 8. Fluxo do jogador

1. **Chega** no `LOBBY-SPAWN` olhando para o palco: vê o carrinho original, o neon "CORNER DOGS / HQ" e o próprio bicho no
   palco. Setas neon no chão saem do medalhão do spawn para os 4 destinos (§12.8).
2. **Classe**: anda 17 studs até o cordão, prompt "Choose Class" → tela de classes com a câmera fixa (§11). Fecha e volta à
   praça.
3. **Gemas / códigos** (opcional): loja à direita (oeste), mural atrás (frente).
4. **Squad**: segue as setas Ketchup até uma plataforma livre; quem pisa primeiro é o dono (Provisório). Amigos pisam na mesma.
5. **Start Shift**: o dono aciona no quadro da plataforma → contagem de 5 s → "poof", a van buzina e sai (só client) →
   teleporte do roster (FEAT-001, DEC-067, DEC-098).
6. **Volta** da run: nasce de novo no `LOBBY-SPAWN`.

## 9. NPCs

- **Nenhum NPC de servidor** no lobby. Teto de NPC do lobby = 0.
- Rig da classe no palco: **1 por client**, local, ancorado, fora de qualquer teto (como a Opal local).
- Opcional futuro (não MVP): bichos da crew sentados nos bancos como cenário (P-L14).

## 10. Iluminação

O `Lighting` do place é do usuário e **não muda** (nem `ClockTime`, nem pós-processo). O clima de entardecer vem só de
**luzes locais e Neon**; tudo lê de dia e de noite. Nenhuma luz ou letreiro coral `#FF8A65` (reservado ao ponto seguro,
style guide §2.4); o rosa do letreiro do Mart também fica fora.

| ID | Tipo | Posição WORLD | Mira / dados | Cor | Brilho / alcance | Sombra |
|---|---|---|---|---|---|---|
| L-KEY | `SpotLight` (Part invisível, `Face Front`) | (−6,5, 8,0, −588,5) | `lookAt` (0, 3,6, −580,5); Angle 45 | `#FFE7C2` | 4 / 16 | **sim** (única) |
| L-FILL | `SpotLight` | (6,5, 6,6, −588,5) | `lookAt` (0, 3,6, −580,5); Angle 55 | Cream `#FFF1D6` | 1,5 / 14 | não |
| L-RIM | `SpotLight` | (0, 6,8, −577,0) | `lookAt` (0, 4,2, −580,5); Angle 60 | Teal `#3FA7B5` | 1,2 / 8 | não |
| L-HQ | `PointLight` | (0, 10,5, −572,5) | brilho quente no letreiro e nos guarda-sóis | (255, 200, 120) | 1,4 / 18 | não |
| L-SHOP | `PointLight` | (−24,5, 8,0, −600) | sob a cobertura do quiosque | `#FFE7C2` | 1,2 / 16 | não |
| L-CODES | `SpotLight` | (−10, 7,0, −624,6) | `lookAt` (−10, 3,7, −626,4); Angle 70 | Cream | 1,5 / 9 | não |
| L-SL-A..D | `SpotLight` na `LampHead` de cada poste, para baixo | cúpula dos postes SL-A..D (§12.7) | Angle 100 | sódio `#FFB25A` | 1,2 / 18 | não |

Total **10 luzes locais, 1 com sombra** (style guide §5.1: ≤ 18, alvo 14, ≤ 3 com sombra). Lâmpadas de varal, setas e
letreiros são só `Neon` (sem luz real).

## 11. Câmera da tela de classes

| Item | Valor |
|---|---|
| CFrame | `CFrame.lookAt(Vector3.new(0, 4.5, -592.5), Vector3.new(0, 5.0, -580.5))` (≈ 2,39° para cima) |
| FieldOfView | **50** (vertical) |
| Distância ao rig | 12 |
| Enquadramento (16:9) | rig de pé ocupa ~45% da altura, borda de baixo no filete neon do palco; atrás: carrinho inteiro com guarda-sóis, vasos do palco, neon "CORNER DOGS / HQ" e "BRAMBLE'S" inteiros; prédios do HQ preenchem o topo (sem céu) |
| Variante com UI à esquerda | mesma câmera deslocada 3 em −X: `CFrame.lookAt(Vector3.new(-3, 4.5, -592.5), Vector3.new(-3, 5.0, -580.5))` → rig a ~65% da largura da tela |
| Close-up (opcional) | FOV 40 com o mesmo CFrame: rig ~56% da altura, letreiro cortado em cima |

Conferido no papel: postes do cordão (X ±7) e floreiras ficam fora do quadro; o cordão (y 2,0) projeta abaixo dos pés do
rig; os cordões de lâmpadas diagonais (§12.7) passam fora do quadro; o ápice dos guarda-sóis (y ~9,1) fica abaixo da placa
do neon (y ≥ 9,2) na linha de visão.
**Requisito para o frontend:** enquanto a tela de classes está aberta, esconder localmente os personagens dos outros
jogadores e o próprio (`LocalTransparencyModifier`): o olho da câmera fica na área andável, a 9,7 do spawn.

## 12. Peças procedurais (geradas por script)

Cores (mesmas do `decor_mart.luau`): INK (43, 36, 64) · MUSTARD (255, 200, 61) · CREAM (255, 244, 214) ·
KETCHUP (235, 70, 60) · MINT (64, 224, 170) · madeira (196, 132, 84) / escura (150, 92, 58) · Pad `#E8D9B5`.
Neon em tubo = `neonText` / `neonShape` do `decor_mart.luau` (cilindros + juntas `Ball`, tag `NeonSign`, atributo `Color`).
Todas as peças: `Anchored`; enfeites com `CanCollide`/`CanQuery`/`CanTouch` falsos e `CastShadow` falso, salvo nota.
**Glifos que faltam** no `GLYPHS` e são usados aqui: **Q** e **F** (proposta na grade 2 × 3: `Q` = contorno do `O` +
traço `{1.2, 0.8, 2.2, -0.2}`; `F` = `{2, 3, 0, 3, 0, 0}` + `{0, 1.5, 1.4, 1.5}`).

### 12.1 Letreiro "CORNER DOGS / HQ" (fachada do BK-3)

| Peça | Medidas | Posição WORLD (centro) | Cor / material |
|---|---|---|---|
| `HQ_SignBoard` | 26 × 4,8 × 0,3 | (0, 11,6, −569,6), face para −Z | INK, SmoothPlastic (encostar na parede: conferir o plano por raycast, ~Z −569,3 no prédio A e −568,6 no H) |
| `HQ_SignTrim` | moldura de 4 barras 0,2 × 0,2 (2 de 26,4 e 2 de 5,2) | contorno da placa, Z −569,78 | Neon MUSTARD |
| `Neon_CornerDogs` | `neonText("CORNER DOGS", altura 2,0)` → 19,3 de largura | cf = `lookAt((0, 12,5, −569,95), (0, 12,5, −570,95))` | MUSTARD |
| `Neon_HQ` | `neonText("HQ", altura 1,4)` | cf em (0, 10,15, −569,95), mesma frente | CREAM (precisa do glifo Q) |
| `Neon_HotDog` ×2 | `neonShape` com os traços do `PadDecor` (pão, salsicha, mostarda), k 0,55 → 3,5 × 1,4 | origem do ícone em (−8,42, 9,46, −569,95) e (11,48, 9,46, −569,95), mesma frente | pão (255, 176, 80), salsicha KETCHUP, mostarda MUSTARD; atributo `Flicker` só no da direita |
| `HQ_TopPlate` | 9 × 1,2 × 0,2 | (0, 14,75, −569,6) | CREAM; `SurfaceGui` na face −Z "BRAMBLE'S" (Fredoka One, KETCHUP; texto final: narrative-writer) |

### 12.2 Loja de gemas

| Peça | Medidas | Posição WORLD | Cor |
|---|---|---|---|
| `Neon_GemShop` | `neonText("GEM SHOP", altura 1,1)` → 7,7 de largura | cf = `lookAt((−22,0, 9,75, −600), (−21,0, 9,75, −600))` | MINT |
| `Neon_Gem` ×2 (placas) | `neonShape` losango: `{0,2, 1,3, 3,3, 4,2, 2,0, 0,2}`, `{0,2, 4,2}`, `{1,3, 1.4,2, 2,0}`, `{3,3, 2.6,2, 2,0}`; k 0,3 | sobre `NamePlate_L/R`: (−22,0, 9,3, −589,5) e (−22,0, 9,3, −610,5), frente +X | MINT |
| `Gem_P1..P5` | `Part` bloco 0,9³ girado `CFrame.Angles(rad(45), 0, rad(35.26))` (cubo na ponta = gema) | (−24,375, 4,2, Z do pedestal): −590, −593, −596, −604, −607 | Neon MINT; giro lento opcional (client) |
| `Gem_S1` | idem, 1,2³ | (−24,375, 4,2, −610) | Neon MUSTARD (melhor oferta) |
| `Prompt_Shop` | `Part` invisível 1³, tag `Interactable` | (−22,4, 3,5, −600) | `PromptAction` a definir (architect) |

### 12.3 Plataformas de squad (×4) — centro (20, ·, Zc), Zc = −588 / −598 / −608 / −618

| Peça | Medidas | Posição | Cor / dados |
|---|---|---|---|
| `SquadPad_n` | `Cylinder` Ø 8 × 0,3 (Size (0,3, 8, 8), `CFrame.Angles(0, 0, rad(90))`) | (20, 0,15, Zc) → topo 0,3 | CREAM SmoothPlastic, `CanCollide` true; tag **`PartyPlatform`**, atributo **`Party` = n** |
| `SquadPadRim_n` | `Cylinder` Ø 8,5 × 0,2 | (20, 0,1, Zc) (sobra 0,25 em volta) | Neon; estados: parado KETCHUP, ocupado MUSTARD, contagem MINT piscando (frontend) |
| `SquadPadNumber_n` | `SurfaceGui` na face de cima da base | centro | "1".."4" Fredoka One ~3 de altura, KETCHUP, legível para quem vem de −X |
| `Zone_Party_n` | `Cylinder` Ø 8 × 6, invisível | (20, 3,3, Zc) | `CanCollide`/`CanQuery` falsos, `CanTouch` conforme o architect (ou detecção por distância ao `LOBBY-SQUAD-n`) |
| `Prompt_Start_n` | `Attachment`/`Part` invisível, tag `Interactable` | (25,0, 3,0, Zc) | prompt "Start Shift" só para o dono (P-L1) |
| quadro | AST-024 (placements) | (25,3, 0, Zc) | `SurfaceGui` na face de leitura: "SQUAD n", "n/4", nomes, contagem |

### 12.4 Letreiro "START SHIFT"

| Peça | Medidas | Posição WORLD | Cor |
|---|---|---|---|
| `Start_Post` ×2 | 0,4 × 9,8 × 0,4 | (29,4, 4,9, −610,5) e (29,4, 4,9, −595,5) | INK, `CanCollide` true |
| `Start_Board` | 0,3 × 2,6 × 15 (X × Y × Z) | (29,4, 8,4, −603) | INK |
| `Neon_StartShift` | `neonText("START SHIFT", altura 1,3)` → 12,6 de largura | cf = `lookAt((29,2, 8,4, −603), (28,2, 8,4, −603))` (lê da praça) | KETCHUP (precisa do glifo F) |
| `Neon_StartArrow` | `neonShape` seta `{0,1, 3,1}`, `{2,2, 3,1, 2,0}`; k 0,4 | abaixo do texto, (29,2, 7,4, −601,5), mesma frente | MUSTARD |

### 12.5 Mural "CODES"

| Peça | Medidas | Posição WORLD | Cor |
|---|---|---|---|
| `Codes_Post` ×2 | 0,6 × 6,6 × 0,6 | (−14,4, 3,3, −626,6) e (−5,6, 3,3, −626,6) | madeira, `CanCollide` true |
| `Codes_Frame` | 8,6 × 5,0 × 0,3 | (−10, 3,7, −626,75) | madeira escura |
| `Codes_Board` | 8 × 4,4 × 0,4 | (−10, 3,7, −626,6) (y 1,5..5,9), face +Z | cortiça (205, 160, 110); `SurfaceGui` (Front para +Z): título e instrução (texto: narrative-writer) |
| `Codes_Roof` | 9,4 × 0,4 × 1,4 | (−10, 6,8, −626,6) | KETCHUP |
| `Codes_SignBack` | 5,2 × 1,4 × 0,2 | (−10, 7,6, −626,6) | INK |
| `Neon_Codes` | `neonText("CODES", altura 1,0)` → 4,3 | cf = `lookAt((−10, 7,6, −626,4), (−10, 7,6, −625,4))` | CREAM |
| `Prompt_Codes` | invisível, tag `Interactable` | (−10, 3,2, −626,1) | `PromptAction` a definir (architect) |

### 12.6 Palco de classes

| Peça | Medidas | Posição WORLD | Cor |
|---|---|---|---|
| `Stage_Body` | 12 × 0,9 × 7 | (0, 0,45, −580,5) | KETCHUP, `CanCollide` true |
| `Stage_Top` | 12,2 × 0,1 × 7,2 | (0, 0,95, −580,5) → topo 1,0 | `#E8D9B5` |
| `Stage_Edge` | 12,2 × 0,08 × 0,08 | (0, 0,96, −584,14) | Neon MUSTARD |
| `Stage_SpotRing` | `Cylinder` Ø 3,9 × 0,03 | (0, 0,995, −580,5) | Neon CREAM |
| `Stage_Spot` | `Cylinder` Ø 3,6 × 0,04 | (0, 1,0, −580,5) → topo 1,02 (= Y do `LOBBY-CLASS-STAGE`) | MUSTARD SmoothPlastic |
| `Stage_Rope` | 3 segmentos `Cylinder` Ø 0,15, de (−7, 2,0, −584,7) a (7, 2,0, −584,7), barriga 0,25 | — | KETCHUP |
| `StageLight_K` / `_F` | haste 0,35 × 8 × 0,35 em (∓6,5, 4, −588,5); pé 1,2 × 0,3 × 1,2; cabeça 1,0 × 0,8 × 1,2 INK com lente Neon CREAM 0,7 × 0,5 × 0,05 virada para o rig | cabeça em (−6,5, 8,0, −588,5) e (6,5, 6,6, −588,5) | INK; a `SpotLight` L-KEY/L-FILL fica na cabeça (§10) |
| `Prompt_Classes` | invisível, tag `Interactable` | (0, 3,0, −585,3) | "Choose Class" |

### 12.7 Lâmpadas de varal

Amarradas no eixo de cada poste (o pé), a **y 11,5**; barriga 1,5 no meio (perfil `sin(πt)`, como o `PadDecor`); fio
`Part` 0,06 INK; lâmpada `Ball` Ø 0,32 Neon a cada ~2,2 studs, 0,22 abaixo do fio; cores em ciclo MUSTARD, CREAM, KETCHUP,
MINT. ~108 lâmpadas.

| Vão | De | Até |
|---|---|---|
| S1 (leste, sobre as plataformas) | SL-B (24, 11,5, −626) | SL-D (24, 11,5, −576) |
| S2 (frente, sobre o mural) | SL-A (−26, 11,5, −626) | SL-B (24, 11,5, −626) |
| S3 (diagonal) | SL-A (−26, 11,5, −626) | SL-D (24, 11,5, −576) |
| S4 (diagonal) | SL-B (24, 11,5, −626) | SL-C (−26, 11,5, −576) |

Não há vão ao longo do HQ (cruzaria o letreiro na câmera de classes) nem sobre a loja (bate na cobertura de 11,4).

### 12.8 Setas neon no chão

Chevron = 2 barras Neon 1,4 × 0,05 × 0,28 em "V" (±40° da direção), ponta para o destino, centro em y 0,025. Rótulo =
`Part` invisível 4,5 × 0,04 × 1,1 com `SurfaceGui` Top (Fredoka One, mesma cor), legível para quem anda na rota.

| Destino | Cor | Pontas dos chevrons (X, Z) | Direção | Rótulo |
|---|---|---|---|---|
| Palco | MUSTARD | (1,6, −597,5), (1,2, −594,5), (0,8, −591,5) | +Z | "CLASSES" em (1,9, −600) |
| Squads | KETCHUP | (7,5, −602,6), (10,5, −602,8), (13,5, −603) | +X | "SQUAD UP" em (6, −604,6) |
| Loja | MINT | (−2,5, −601,6), (−6,0, −601,2), (−9,5, −600,8) | −X | "GEM SHOP" em (−1, −599,6) |
| Códigos | CREAM | (−0,6, −607,0), (−3,4, −611,2), (−6,2, −615,4) | (−0,555; −0,832) | "CODES" em (0,8, −605,3) |

### 12.9 Medalhão do spawn

`Cylinder` Ø 6 × 0,04 CREAM em (2, 0,02, −602) sobre anel Neon MUSTARD Ø 6,4 × 0,02 em (2, 0,01, −602); `SurfaceGui` Top
com o logo "Sell Hotdogs!" (AST-097, se já existir; senão texto) legível para quem olha +Z.

### 12.10 Paredes invisíveis

`Part` `Transparency 1`, `CanCollide` true, `CanQuery`/`CanTouch` falsos, `CastShadow` falso, altura 30 (não dá para pular
por cima; o jogador também não alcança o teto do quiosque, 11,4).

| ID | Centro WORLD | Tamanho (X × Y × Z) | Limite |
|---|---|---|---|
| LW-N | (0,7, 15, −569,5) | 62,4 × 30 × 1 | Z −570 (fundo) |
| LW-S | (0,7, 15, −630,5) | 62,4 × 30 × 1 | Z −630 (frente) |
| LW-W | (−29,5, 15, −600) | 1 × 30 × 64 | X −30 (atrás da loja) |
| LW-E | (30,9, 15, −600) | 1 × 30 × 64 | X 30,4 (fim do meio-fio; ninguém desce para a rua) |
| LW-STAGE | (0, 15, −577,5) | 32 × 30 × 15 | palco + carrinho (X −16..16, Z −585..−570) |
| LW-SHOP | (−25,65, 15, −600) | 6,7 × 30 × 26 | quiosque (X −29..−22,3, Z −613..−587) |

## 13. Assets

### 13.1 Já uploadados (ids de `Assets/import/_asset_ids.json`)

| Asset | Id | Onde no lobby | Nota |
|---|---|---|---|
| `AST-032_SidewalkTile` | 106065580947318 | piso da praça (9) + 2 faixas | escalado por `parts.size` |
| `AST-032_RoadStraight` | 128844222664789 | rua leste (4) | |
| `AST-047_Barrier` | 117449074898077 | pontas da rua | |
| `AST-033_BuildingA` / `_BuildingH` | 100043502770043 / 135775815831946 | 12 prédios em 3 lados | |
| `AST-033_BGCard_A` / `_B` / `_C` | 80688595324183 / 93430239356839 / 72273208007989 | outro lado da rua + pontas | |
| `AST-102_BushLarge` / `_PottedPlant` | 95749471949635 / 88677038559461 | frestas, palco, loja | |
| `AST-026_CornerCart` | 125618844389927 | vitrine do HQ | |
| `AST-012_RollerGrill`, `AST-013_RestRail`, `AST-015_BunCrate`, `AST-014_CuttingBoard`, `AST-017_ToppingGrid`, `AST-020_CashRegister`, `AST-042_VehiclePhone` | 120193794249419, 89812717458331, 104525965300985, 116481887243365, 85202632595664, 140686867523674, 70616818643340 | bancada do carrinho (enfeite) | AST-042 e AST-020 são CC-BY (crédito já em `credits.md`) |
| `AST-024_SignStand` | 87423080095373 | 4 quadros de squad, OPEN, WELCOME | |
| `AST-019_QueuePost` / `_QueueMark` | 95546998114592 / 76929317628513 | cordão do palco, 16 vagas | |
| `AST-034_Planter`, `_ParkBench`, `_TreeSmall`, `_TrashCan`, `_Mailbox`, `_Hydrant`, `_StreetSign` | 122469293427245, 140564552524757, 70574598056933, 115176311696425, 139590895707464, 87841888013714, 80086026176746 | praça | |
| `AST-104_GearStand` | 128032041613976 | quiosque da loja | |
| `AST-105_Pedestal` / `_PedestalS1` | 95986356945439 / 112726919509556 | 6 pedestais | Column Round (Quaternius CC0) |
| `AST-035_CarVan` / `_CarSedan` (+ `_Paints`) | 75116537691175 / 122844071213000 | van da crew, carro parado | |
| `AST-027_OpenLateTrailer` | 78288102155940 | teaser do outro lado da rua | |
| `AST-037_Flyer` | 113262761926943 | mural de códigos | |
| `AST-100_PicnicTable` | 116266597707465 | canto dos códigos | **CC-BY 3.0 J-Toastie**: conferir linha "Usado em" no `credits.md` |
| `AST-036_StreetLightCurved` / `_LampHead` | 98239970632237 / 109449892945893 | 4 postes | |

~38 malhas únicas.

### 13.2 Pendências de asset (nada bloqueia o teste de hoje)

| Pendência | Para quem | Hoje fica |
|---|---|---|
| Variante de cor **Ketchup/Cream** da van (+ decal do logo DEC-206) = "Crew Van" | art-director → modeler-3d | van `Butter` |
| AST-088 (plataforma de party) com **Ø 8** em vez de Ø 12 (lobby compacto) | art-director | disco procedural §12.3 |
| Gema 3D (malha) e cor oficial da gema | art-director | cubo Neon MINT §12.2 |
| AST-089: ficha diz "praça de manhã, sempre dia"; o pedido do usuário é entardecer com neon | art-director (atualizar ficha) | vale o pedido do usuário |
| AST-090 (vitrine de 8 pedestais): substituída pelo palco + câmera | usuário decide se a ficha fica Obsoleta | palco §12.6 |
| Logo "Sell Hotdogs!" (AST-097) para o medalhão | art-director | texto |
| Glifos `Q` e `F` no gerador de neon | quem roda o script | §12 (proposta de traço) |

## 14. Requisitos técnicos e orçamento

| Item | Valor |
|---|---|
| NPCs de servidor | **0**; rig de classe: 1 local por client |
| Triângulos da cena (estimativa) | ~60 mil (prédios ≤ 30k, carrinho montado ~7,2k, trailer 4,5k, quiosque + pedestais ~6k, veículos ≤ 4k, resto ~8k) ≤ 120 mil (AST-089) |
| Instâncias | ~110 assets + ~500 Parts procedurais (lâmpadas ~108, tubos de neon ~300) |
| Luzes locais | 10, 1 com sombra (§10) |
| Streaming | região a ~460 studs do MAP-01. Raiz do lobby e `MapBinding.Lobby` **Persistent** (o spawn e a câmera de classes não podem esperar stream). No servidor de lobby o MAP-01 não precisa carregar; no servidor da run o lobby pode ser destruído no boot. Os dois conflitam com o "MAP-01 sempre carregado" (DEC-209) só em memória: decisão do architect (P-L9) |
| Ambiente especial | nenhum; `Lighting` intocado |
| Colisão | jogador × jogador desligada (DEC-175): vários nascem no mesmo spawn sem empurrão |

## 15. Pendências e perguntas (a registrar como `Q-###` pelo secretário; todas não bloqueantes, valor Provisório já aplicado)

| ID | Pergunta | Provisório |
|---|---|---|
| P-L1 | Onde se aciona o início: quadro da plataforma, van, ou os dois? | prompt "Start Shift" no **quadro** da plataforma, só para o dono (quem pisou primeiro); a van é marco e animação de partida; `LOBBY-START` ancora o "poof" (game-designer + architect) |
| P-L2 | Cor da gema | MINT (64, 224, 170) (art-director) |
| P-L3 | Diâmetro da plataforma | Ø 8 (AST-088 diz 12) |
| P-L4 | Lobby ao entardecer × AST-089 "sempre dia" | entardecer por luzes locais (pedido do usuário) |
| P-L5 | AST-090 vira Obsoleta? | sim, substituída pelo palco (usuário decide) |
| P-L6 | Glifos Q/F | proposta no §12 |
| P-L7 | Cores da van da crew | Butter até a variante existir |
| P-L8 | Frentes e pivôs não medidos: AST-035 (van, sedan), AST-037, AST-019, AST-047, BG cards; malha do AST-024 (+2,0); plano da parede do BK-3 para a placa | conferir no Studio e girar 180 se preciso |
| P-L9 | Lobby no servidor da run e MAP-01 no servidor de lobby (memória, DEC-209) | architect |
| P-L10 | Esconder personagens na tela de classes | requisito ao frontend (§11) |
| P-L11 | Textos: "CORNER DOGS / HQ", "BRAMBLE'S", "WELCOME, CREW!", "SQUAD UP", quadros, mural, placa de rua (inglês, DEC-022) | placeholders do level-designer; final do narrative-writer |
| P-L12 | `Q-085`: documento do lobby | `levels/LOBBY.md`, sem `MAP-##` |
| P-L13 | O que a loja vende (6 pedestais + balcão) | game-designer / economia |
| P-L14 | Bichos da crew como cenário nos bancos | fora do teste de hoje |

## 16. Critérios de aceite do layout

1. Todos os pontos do §5 a ≤ 25 studs do `LOBBY-SPAWN` (§6).
2. Do spawn, em 1ª pessoa no celular, os 4 letreiros neon são identificáveis girando a câmera, sem andar.
3. A câmera do §11 mostra o rig inteiro (pés no disco) e o letreiro "CORNER DOGS" inteiro, sem poste, cordão ou planta
   cortando o rig.
4. Nenhum jogador consegue sair da área (paredes do §12.10), subir no palco ou entrar no quiosque.
5. Nada do MAP-01 aparece atrás dos prédios do HQ na altura do olho.
6. ≤ 10 luzes locais, 1 com sombra; `Lighting` sem alteração.
