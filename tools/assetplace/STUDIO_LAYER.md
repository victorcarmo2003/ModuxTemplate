# Camada do Studio (o que um Place.run NAO recria sozinho)

Atualizado em 2026-10-12 (captura das edicoes a mao do dono; Place.diff MAP-01: 29 diferencas restantes, todas
explicadas abaixo; lobby: 2 -> 1, explicada). Ferramentas de rede: `python -m http.server 8772` na raiz do repo
(os snippets carregam `place_assets.luau`, placements e ids por HTTP).

`Place.run` reconstroi `workspace.MAP01_Assets` inteiro a partir de `MAP-01_placements.luau` e apaga qualquer edicao que nao
esteja la. Tudo o que o dono fez a mao esta agora nos placements (campos `parts`, `drop`, `copies`, entradas novas) EXCETO o
que esta listado aqui, que vive em snippets que rodam DEPOIS do Place.run.

## Ordem depois de um Place.run (MAP-01)

1. `Place.run(placements, ids)` (so depois de `Place.diff` = 0 reais e o dono salvar o place; ver memoria `studio-hand-edits`).
2. `bind_map01.luau` (`Bind.run()`): ancoras, MKT-SHELVES (BUY-*), portas, trailer, luzes.
3. `swap_mart_door.luau`: divide a porta do Mart (ver tabela).
4. `bind_pieces.luau` (`Pieces.run()`): pecas de upgrade. O Bind.run desfaz o Pieces: sempre depois dele.
5. `fix_trailer_height.luau`: **NAO rodar apos um Place.run** (ver tabela). So num place que ainda tenha os meshes antigos.
6. `fix_mart_shelf_packs.luau`: packs AST-011 nas gondolas (le os BUY-* do passo 2).
7. `fix_mart_fridge.luau`: packs de queijo / cream cheese nas geladeiras (le os BUY-* do passo 2).
8. `trailer_tables.luau`: **OBSOLETO** desde o trailer unico (2026-10-12); nao rodar (o passo 9 renumera as mesas 1..4).
9. `trailer_only_map.luau`, depois **`trailer_ground.luau`**, **`trailer_serving_panel.luau`**, **`trailer_side_neon.luau`** (secao "Trailer rente ao chao" abaixo) e por fim `trailer_only_lights.luau` (secao "Trailer unico" abaixo): carrinho e venda para o backup, pontos Q / PS / DROP-T / L3 / TRL-OUT no referencial do trailer, nos TBL-1..4 e N-PAD-1..3, mesas 1..4, varais ligados ao trailer. Se o `Place.run` recolocou o trailer no lote de venda (Z > 60) o snippet o leva a `DEFAULT_POSE`.
9b. `streetlights_bind.luau` (`run("assetplace/streetlights_bind", "dry" | nil | "undo")`): postes decorativos (Post_*, POST-OUT*, Post_L2). O `bind_map01` ja faz isto sozinho (`bindDecorLamps`, depois de `bindStreetLights`); rode o snippet quando o place foi mexido a mao sem novo bind. Move a tag `StreetLight` do `Bulb` para o Model `LampHead`, `PostId = DECOR-<MapId>-<x>_<z>` + `Decor = true` (sem Group/Order), e poe `ModelStreamingMode = Persistent` nos Models com tag (inclusive os "Model" de agrupamento do dono). Nunca apaga; so reporta duplicatas. Sem isto o `PlaceService` falha com "map binding (wave 3) has N problem(s)".
10. `check_map01.luau` (`Check.run({ wave = 3 })`) e, no fim, `Place.diff` outra vez (esperado: so as linhas da secao "Diferencas esperadas").

Lobby: **nunca** `Place.runInto(..., true)` (force) sem sincronizar antes; sem `force` o runInto recusa (`[skip]`). A ordem do lobby, quando
for reconstruir de proposito: `runInto(LOBBY_v2_placements, ids, "LOBBY_Assets", true)` -> `Decor.runLobby(true)` (decor_mart.luau) ->
`bind_map01` (bindLobby) -> `warm_lobby.luau`.

## Trailer unico (2026-10-12, DEC-224, Provisorio)

O Food Trailer e o veiculo unico; o carrinho saiu da run. Dois snippets de Studio, idempotentes, nada e apagado (o que sai vai para `ServerStorage.CART_Backup_20261012`, com `OrigPath` e `OrigTags`; as tags de gameplay saem do backup para nenhum servico ler fantasma; o `CARRINHO BACKUP` do dono so perde as tags):

| Snippet | O que faz |
|---|---|
| `trailer_only_map.luau` | backup de `MAP01_Blockout.Pad.CART`, `Trailer.TRL-SALE` / `SIGN-T`, MapPoints `TRL-SALE` / `SIGN-T`, `Prompt_Buy` (buy_trailer) do trailer. Pontos no referencial do pivo do trailer: `TRL` = pivo, `CART` (nome legado, janela de servico; a cutscene e os clientes ainda o leem), `Q1..Q5` (3,4 studs da gaveta, sob a aba), `PS-1..4` = `PS-N1..4` (dentro, piso 2,6), `DROP-T`, `AN-05`, `L3` (espreita do ladrao, fora do trailer, a leste), novo `TRL-OUT` (pouso do Exit Trailer, faixa oeste). `LZ-1/2/3` acompanham o trailer. NpcNodes novos `N-PAD-1..3` e `TBL-1..4`; `Q5 <-> N-PAD-2`, `Q1 <-> N-PAD-3`; `N-Z01-02/03` vao para o backup. Mesas: os 4 `SeatTable` do Workspace viram `TableIndex` 1..4 por X (oeste = 1), `MapId` `TTBL-n`, `TableGroup` "Trailer". Marcas `Qn_AST-019_QueueMark` vao para os Q. Tudo deriva do pivo atual do trailer: se o dono o mover, rodar de novo. |
| `trailer_only_lights.luau` | varais: 3 arcos (trailer -> poste oeste, trailer -> poste leste, poste -> poste) com as mesmas `Wire` / `Bulb` (clones), minimo 9,5 studs, sem luzes novas (17/18). Pecas antigas (83) vao para `ServerStorage.PadLights_Backup_20261012`; novas em `Workspace.MAP01_Assets.PadDecor.TrailerStringLights_V1` (refeito a cada execucao; reler as pontas do `TRL-LIGHTS` e das duas `LightPole`). |

Pos-`Place.run`: o run recria `MAP01_Assets.Cart`, o carrinho, `TRL-SALE` e o trailer no lote; os dois snippets acima o desfazem (rodar depois do `bind_map01` e do `bind_pieces`). `tools/studio/sync_src.luau` e so um substituto do botao Connect do Rojo (copia o Source dos scripts do `sourcemap.json`).

## Snippets pos-run, um a um

| Snippet | O que repoe | Por que nao esta nos placements | Estado apos Place.run |
|---|---|---|---|
| `swap_mart_door.luau` | porta do Mart separada: `Door_Frame` + `Door_Leaf_L` + `Door_Leaf_R` (modelo 140495801903917) e o contrato AutoDoor das folhas | a entrada #165 (`AST-028_MartWallDoor`) constroi o mesh unico antigo; o split e uma troca de MeshPart (MeshId nao e scriptable). A captura NAO grava `drop` + 3 partes extras para essa entrada (quebraria o swap) | idempotente: se `Door_Frame` existe so reconfigura as folhas |
| `fix_mart_shelf_packs.luau` | `ShelfPacks` (3 packs x 2 andares por face) nas 4+ gondolas `AST-029_GondolaBoxesBare` | os packs sao Parts clonadas dos modelos AST-011, nao mesh do placement; a entrada ja usa `GondolaBoxesBare` (mesh sem estoque) | idempotente (pula gondola com pasta `ShelfPacks`; `FORCE = true` refaz; obrigatorio se um BUY-* mudou) |
| `fix_mart_fridge.luau` | `ShelfPacks` + `Light_Inner` das geladeiras `AST-030_FridgeDisplayShelves` (queijo / cream cheese) | idem; as entradas #193/#194 ja constroem a geladeira nova (Body/Trim/Doors/Shelves/Led, estilo em `FRIDGE_STYLE` do place_assets) | idempotente (pula quem tem `ShelfPacks`) |
| `trailer_tables.luau` (OBSOLETO, trailer unico) | tag `SeatTable`, `TableIndex` 6..9, `TableGroup`, Seat1..4 invisiveis das mesas `TTBL-6..9` | o placement so cria o mesh (`AST-100_PicnicTable`); build() nao grava tags nem atributos | idempotente; ordena por distancia ao Q1 (6 = mais perto). Os indices originais eram 6 (-61.3,112.2) 7 (-61.3,104.9) 8 (-87.6,113.3) 9 (-87.6,106.0), mundo |
| `fix_trailer_height.luau` | trailer rebaixado (Counters topo +4.6, Body, Awning, Shelf_Fold novos; bancos AST-040 novos; estacoes -0.9) | JA ESTA nos placements: `_asset_ids.json` aponta para o AST-027 / AST-040 novos e as entradas TRL-S/G/R/B/T/K/DRAWER/COFFEE ja usam y 5.05 (antes 5.95) | **perigo**: depois de um Place.run as estacoes nao tem o atributo `TrailerLoweredV1`, entao o passo 3 do snippet baixaria 0.9 de novo. Nao rodar apos rebuild. Conferir com Place.diff (entrada #79 = so o deslocamento do trailer) |

Constantes ja alinhadas: `bind_map01.luau` SHELVES confere com as ancoras BUY-* vivas (9 de 9, x/z/h iguais; lidas do Studio em 2026-10-12).

## Diferencas esperadas do Place.diff (MAP-01) apos esta captura

- `#79 TRL [moved]`: o trailer vive em `Night_Trailer`; o diff compara depois do deslocamento do trailer (`d=148.093` igual em todas as partes = pose relativa identica).
- `#165 MKT-DOOR`: mesh unico no placement vs. Door_Frame / Leaf_L / Leaf_R vivos (swap_mart_door).
- `#178-180, #740-742 MartAwning`: `a=17.0`. O pivo vivo esta inclinado 17 graus (rotX), o placement grava a inclinacao em `parts` (a mesma geometria; as partes batem).
- `#193, #194, #199, #794-796`: so "part extra live ... ShelfPacks" (fix_mart_shelf_packs / fix_mart_fridge).
- `#185-#192, #195-#198, #200-#202` (15 entradas "MISSING"): GEAR_WALL, checkout OP-1 e as gondolas antigas (Boxes / Bags / End) que o dono tirou do Mart. Ficam nos placements de proposito:
  elas tem `drop` do mesh inteiro e o `replaces` mantem o blockout escondido. Efeito de um Place.run: nascem 15 Models vazios (so Attachments) que o `bind_map01` ja avisa (GEAR_WALL).
  Opcional apos o run (nao testado em Place.run real): destruir os Models sem BasePart com MapId em { GEAR_WALL, OP-1 } ou Asset em AST-029_GondolaBoxes / Bags / End.
- `#797-#800 TTBL-6..9`: MISSING ate o `cleanup_stray.luau` mover as mesas soltas para `MAP01_Assets.TrailerTables` (ele tambem grava MapId / Asset nelas).

## O que a captura gravou (2026-10-12)

MAP-01 (`MAP-01_placements.luau`, 793 -> 800 entradas): 24 registros de mudanca (6 sao as marquises, sem mudanca real; o resto: poste NinthS_W2, GondolaBoxesBare, FruitDisplay, ProduceStand,
2 LettuceCrate, TreeLarge T-03, GearStand `Structure` size, 3 sinais, BunDisplay, 2 MeatCase, 2 sinais), 3 entradas novas (`GondolaBoxesBare` x3), 4 entradas novas
das mesas do trailer (`TTBL-6..9`, group `TrailerTables`), 15 entradas "removidas" mantidas (acima), 1 pulada (trailer, segue o trailer).

Lobby (`LOBBY_v2_placements.luau`): o lobby foi escalado x1.3 em torno do spawn (5, 0, -620) e ficou com 4 plataformas de squad (o `bind_map01` ja descreve isso). Capturadas
148 entradas (x/y/z/rotY e `parts` com size / pos em escala), 37 entradas comentadas como removidas (squads 5..8, slots de fila, LB-WELCOME), 1 `pivot` obsoleto removido (LB-CART-DRAWER).
LB-TRL (trailer do lobby): so a pose; o mesh vivo ainda e o AST-027 ANTIGO x1.3 com partes de nome duplicado, entao um runInto reconstroi o trailer novo SEM escala (ajustar a mao depois).
Floor / estrada / predios: os tamanhos viraram `parts.size` em cada entrada (por isso as linhas ficaram grandes).

## Lobby: praca desimpedida (2026-10-12, `declutter_lobby_plaza.luau`)

Pedido do dono: o mastro central (poste + floreira laranja + varais radiais) bloqueava a travessia e poluia o ceu. Snippet de Studio, idempotente,
com `UNDO = true`; **roda DEPOIS** de `Decor.runLobby` / `warm_lobby.luau` (o `decor_mart.luau` ainda recria o mastro: um `runInto` + `Decor.runLobby` o traz de volta,
reaplicar o snippet).

- Movidos para `ServerStorage.LOBBY_Backup_20261012` (nada apagado, atributo `OrigFolder`): `Mast_Pole`, `Mast_Planter`, `Mast_Soil`, `LB-MAST-BUSH` (entrada comentada em `LOBBY_v2_placements.luau`), 171 `Wire` + 163 `Bulb` radiais.
- `Mast_Ring` virou disco achatado no chao (5, -631), Ø 6,6; novos: `Emblem_Disc` (tinta) e `Floor_HotDogEmblem` (clone achatado de um `Mast_Topper`), tudo y 0,10..0,18, CanCollide false.
- Os 2 `Mast_Topper` (neon do cachorro-quente, costas com costas) foram para cima do `Start_Board` (x 62,7, y 17,6, z -620), escala 1,7, + 2 `Portico_Strut`.
- Novos varais: `LobbyProcedural.LobbyDeclutter_V1` (94 Wire + 89 Bulb): so postes do perimetro, 5 vaos (C-H, H-A, A-B, B-G, F-E), fio no minimo y 12,0, longe do centro (>= 54 do spawn).
- Intactos: SpawnLocation, MapPoints LOBBY-*, PartyPlatform, piso, 17 luzes (`WarmLobby_Plaza` segue em (5, 14,5, -628,5), agora sem o mastro).

## Lighting salvo igual ao Day (2026-10-12, `lighting_edit_default.luau`)

Pedido do dono: o Studio (Edit) aparecia estourado. O Lighting salvo do place era Brightness 3, Ambient/OutdoorAmbient cinza (70,70,70), Atmosphere azul fria (Color 70,98,199; Decay 92,76,125; Haze 0),
ColorCorrection Sat 0.5 / Contrast 0.1 / Tint branco, Bloom 1.0, SunRays 0.01. O snippet (idempotente, `UNDO = true` restaura) grava o look do preset Day: Brightness 2.0, ExposureCompensation -0.15 (so Edit),
Ambient (104,90,78), OutdoorAmbient (132,112,94), ColorShift_Top (255,226,186), EnvSpecular 0.8, ShadowSoftness 0.25, Atmosphere (0.4 / 1 / 1.6 / 0.6, cores quentes), CC (0.03 / Sat 0.2 / Contrast 0.05 / Tint 255,244,228), Bloom 0.5, SunRays 0.04.
Backup nos atributos de `ServerStorage.Lighting_Backup_20261012` (prefixos L_ A_ C_ B_ R_; criado so na primeira vez). Sky, DepthOfField e VitalColor/VitalBlur intactos. Nenhum script de runtime.
O preset Day em Content tambem baixou (Brightness 2.8 -> 2.0, Sat 0.4 -> 0.2, Contrast 0.1 -> 0.05, Bloom 0.8 -> 0.5; Golden e Cinematic em proporcao): com 2.8 fachadas e o caminhao clipavam em branco. O dono salva (Ctrl+S).

## Lighting passo 2 + `tone_down_whites.luau` (2026-10-12, "ainda estourado")

`lighting_edit_default.luau` agora grava o Day novo: Brightness 1.3, ExposureCompensation -0.5 (agora tambem escrito pelo `LightController` via `preset.Exposure`; noites 0), Ambient (86,74,64), OutdoorAmbient (110,94,80), EnvDiffuse 0.6, EnvSpecular 0.6, Atmosphere (0.35 / 1 / 1.2 / 0.35), CC (0 / Sat 0.1 / Contrast 0.1), Bloom 0.22 (Threshold 2), SunRays 0.03. Backup novo: `ServerStorage.Lighting_Backup_20261012b` (o `..._20261012` guarda o estado do passo 1).
`tone_down_whites.luau` (DRY / UNDO, backup no atributo `ToneDownOrig`, idempotente): x0.85 quente em Parts com min(RGB) >= 205 e lado > 6 studs, fora Neon/Glass/UI/letreiros/aneis/faixas/pads/texturas. Rodado: 58 pecas (Mart Roof/Floor, CarTunnel pilares/WingCap/WallTile, ToyStore Floor/Shell/Interior, Parking Fence, PB_Roof). Pad do lobby, faixas de pista e vagas ficaram de fora de proposito.

## Trailer rente ao chao, painel "Open Shop" e neon lateral (2026-10-12, Provisorio)

Pedido do dono: clientes na fila nao viam o rosto do cozinheiro pela janela (o trailer estava ~2,1 acima da calcada), "Open Shop" so na placa de fora, e um letreiro OPEN / CLOSED na lateral. Tres snippets de Studio, idempotentes, nada e apagado (o que sai vai para `ServerStorage.Trailer_Backup_20261012`, com `OrigPath`); cada um tem `UNDO`: `run("trailer_ground", "undo")` etc.

Ordem num rebuild (depois do `trailer_only_map`, que le o atributo `TrailerGroundV1` e escreve as alturas certas): `trailer_only_map` -> `trailer_ground` -> `trailer_serving_panel` -> `trailer_side_neon` -> `trailer_only_lights` (religa os varais na ponta que desceu).

| Snippet | O que faz |
|---|---|
| `trailer_ground.luau` | Medido: piso do Pad 0,45; `Body.Floor` do trailer 2,56 (delta 2,11). `DROP = 2,08` deixa o piso em 0,48 (um fio acima do Pad, sem z-fight), bancada a 3,08 (2,6 sobre o piso). `Body.Wheel_DoorSide`, `Wheel_WindowSide`, `Chassis` (braco de engate) e `Steps` (unicas pecas de suspensao / degrau do modelo) -> backup. `PivotTo` -DROP no Model inteiro (estacoes, ancoras de prompt, aba, luzes, bancos, porta). Pontos que seguem: `TRL` (= pivo, y -1,52), `PS-1..4`, `PS-N1..4`, `DROP-T` (0,52), `AN-05` (5,37), zona `LZ-1` (4,62). Nao mudam (chao do Pad): Q1..Q5, CART, TRL-OUT, L3, NpcNodes, mesas. `Zone_Center` fica na altura de mundo 0,66. Duas saias `Skirt_Arch_Front/Back` (2,8 x 0,5 x 0,3, cor do rodape) tapam o entalhe do arco de roda. Marca `TrailerGroundV1` no Model e em cada ponto. O Body fica em Y 0,08..9,93: a base esta enterrada no Pad, sem buraco. Conferido por raycast: piso interno 0,48, Pad / fila 0,45. |
| `trailer_serving_panel.luau` | Model `TRL-OPEN` (MapId, Persistent) dentro do trailer com `Plate` invisivel e o `Attachment Prompt_Open` (`Interactable`, `PromptAction = open_sign`) na face interna da aba de servico fechada: `Shutter_Hinge` - 2,7 em Y - 0,3 contra o `LookVector` do pivo. E ponto fixo (a aba se mexe so no client; o servidor valida a distancia contra a placa). Mesma acao, mesmo handler do `RoundService` (nada duplicado); `Content.Actions.open_sign`: Hold 0,3, Radius 6. Stand `OPEN_AST-024_SignStand` (e `Prompt_Open`) -> backup sem tags gameplay (`OrigTags`). De dia o painel abre / fecha a LOJA (`VehicleController` baixa a aba enquanto a fase nao vende e a sobe na fase Open); a noite o botao `TRL-SHUTTER` (`shutter_toggle`, "Close Window", `Shutter` do servidor) segue fechando a JANELA como antes: sao ancoras e fases diferentes (`open_sign` so em Prep), a aba obedece `Shutter` OU loja fechada. |
| `trailer_side_neon.luau` | Pasta `TRL-SIDENEON` dentro do trailer, no flanco +X (direita de quem olha para a janela). `Neon_ShopOpen` "OPEN" verde (70,255,120, h 1,9, y 7,9) e `Neon_ShopClosed` "CLOSED" vermelho neon (255,50,70, h 1,5, y 5,8): fonte de tubos do `decor_mart.luau` (glifos O P E N C L S D copiados), 0,35 da parede (raycast), tags `NeonSign` (Flicker) + `ShopNeon`, atributo `ShopState`. `OpenSignController` acende o que bate com a fase (`Content.Shift` `Selling`) e apaga o outro (SmoothPlastic, cor x 0,2, `NeonOverride = true`). Sem luz nova (17/18). Estado salvo: loja fechada (CLOSED aceso). |

Codigo: `OpenSignController` (neon), `VehicleController` (`WantClosed` + tick 4 Hz), `MapIndex/Required.luau` (`open_sign` sai de `MapActions`, entra em `Actions` do trailer), `check_map01` (regra 2 e `own[1]`), `Steps.luau` (Hint de `open_first` / `open`).

Constantes que um rebuild precisa: `trailer_ground.DROP = 2,08` e `trailer_only_map.TRAILER_DROP = 2,08` (iguais); `bind_map01` nao muda (alturas relativas ao pivo: `TRAILER_COUNTER_DY = 4,6` continua valendo, pivo -1,52 + 4,6 = 3,08; `floor = 2,45` dos PS-N e so semente, o `trailer_only_map` regrava). `fix_trailer_height` nao e afetado (rebaixa as estacoes do modelo antigo, antes deste).

## Interruptor de abrir/fechar o trailer (2026-10-12)

Pedido do dono: segundo interruptor no trailer, no estilo do da luz, em outra cor. `trailer_open_switch.luau` (idempotente, `run("trailer_open_switch", "undo")`): clona o `TRL-SWITCH` (AST-039 LightSwitch) como `TRL-SWITCH-OPEN` (MapId, Persistent), 5,1 studs ao longo da parede para +X (depois do botao amarelo `TRL-SHUTTER`, que fica a 2,6). Anchor `Prompt_Open` na `Box` (`Interactable`, `PromptAction = open_sign`). Cores: a `Lever` vira cor solida (`TextureID` vazio + `Color`, porque `MeshPart.Color` nao tem efeito com `TextureID`; o MeshId nao e tocado): **VERMELHO** (235,70,60) no da loja, **AZUL** (70,130,245) no da luz (`OrigColor` / `OrigTexture` guardam o original). O `TRL-OPEN` (painel da janela) sai do trailer para `ServerStorage.Trailer_Backup_20261012` com a tag `Interactable` removida; o painel (`Shutter_Panel`) continua descendo/subindo sozinho (client).

Codigo: `RoundService` (`Paused` no set `Shift`, `SetPaused`, texto Open Shop / Close Shop, cooldown 1 s), `CustomerService:IsPaused` (para spawn, garantia, adocao, anomalia), `RoundController.Paused`, `OpenSignController` (neon CLOSED) e `VehicleController.WantClosed` (aba desce), `SwitchLeverController` (alavanca dos dois interruptores vira para cima/baixo), `Steps.luau` (passo `open` antes do cliente), dev `/dev closed [on|off]`.

## Rota da intro para o cartaz movido (2026-10-12, `cutscene_points.luau`, Provisorio)

O dono moveu `MAP01_Blockout.Signs.P-01_Flyer` para (-36,11, 4,61, 50,08), LookVector +X (SurfaceGui Front: a face impressa olha para leste). Snippet idempotente `assetplace/cutscene_points` (marca `CutsceneIntroD3c`), rodado em Edit: move so MapPoints existentes de `MapBinding.Points`. Desfazer: Ctrl+Z ("cutscene_points: before/after") ou voltar os valores antigos em `TARGET` (marcas (-33/-36, 93,5/90,5), CS-1 (-21, 90), CS-2 (-21, 66), CS-3 (-15,5, 53,5)) e rodar de novo.

| Ponto | Antes | Depois |
|---|---|---|
| CutsceneMark1..4 (+X) | (-33/-36, 93,5/90,5) | (-43/-46, 93,5/90,5), de frente para o trailer (X -44,9) |
| CS-1 / CS-2 / CS-3 (-Z) | (-21, 90) / (-21, 66) / (-15,5, 53,5) | (-19, 90) / (-19, 66) / (-19, 53,5) |
| Stand (calculado do cartaz ao vivo) | (-15,1, 48,1) | (-33,1, 50,1), olhando para oeste |

Faixa: CW-4 continua a mais proxima (listras X -24..-12; CW-3 fica em X -60..-54, 6 de largura, a 21 studs do stand). Depois da faixa a rota segue 14 studs para oeste ate o cartaz. Validado por Spherecast (raio 1, alturas 2,2 e 4,5) nos 4 corpos: sem colisor. `bind_map01.luau` (POINTS, coordenadas MAP) acompanha; so vale no proximo Bind.run.

## Semaforos funcionais (2026-10-12, feitos a mao no Studio; NAO estao nos placements)

`workspace.MAP01_Assets.TrafficLights` (criado pelo dono / outro agente direto no Studio): 4 modelos `Signal_WB` (x 16,5; z 50..58), `Signal_EB` (x -11; z 77..86), `Signal_NB` (x -11..-2; z 50), `Signal_SB` (x 1..11; z 85,5), cada um com 3 `SignalHead` (tag `TrafficSignal`, atributo `Axis` = EW | NS) e 2 `PedSignal` (tag `PedSignal`, `Axis`). Lentes: Parts separadas `Red` / `Yellow` / `Green` (head) e `Walk` / `Hand` (ped), Neon quando acesas.
Logica: `TrafficLightCycle` (Script, `RunContext = Client`, dentro da pasta) com `workspace:GetServerTimeNow()`; `GREEN_TIME` 10, `YELLOW_TIME` 3, `ALL_RED_TIME` 1,5, `PED_FLASH_TIME` 4, `OFF_DIM` 0,18 (tabela `PHASES` no topo). Acende = Neon + `OnColor`; apaga = SmoothPlastic + cor x 0,18. Pedestre e visual (nada no servidor le isso).
**Risco**: `Place.run` reconstroi `MAP01_Assets` e apaga esta pasta (junto com o script). Antes de qualquer `Place.run`, salvar o place e exportar `TrafficLights` (ou capturar nos placements). **Atualizado 2026-10-12**: o ciclo agora e codigo (`Content.TrafficLights` + `TrafficLightController`, sobrevive a Place.run se a pasta existir); o snippet `traffic_lights_rebuild.luau` (modos `capture`, `dry`, `apply`, `disable-old`, `enable-old`, `undo`) recria a pasta a partir do espelho `data/traffic_lights.luau` (gerado por `capture`, ainda por gerar). Script antigo: so desligar (`disable-old`) depois de ver o Controller funcionando em Play.

**Verificado no Studio (2026-10-12)**: `TrafficLightCycle` lido e igualado ao `Content.TrafficLights` (so o piscar mudou: 0,4 s por passo). Espelho `data/traffic_lights.luau` capturado (268 nos; `capture` aceita `from`, `n` para fatiar saida acima de 100 kB); `dry` = 0 mudancas. Controller testado em Play com o antigo junto e depois com `disable-old`: fase, Walk e Hand batem com `phaseAt`. `TrafficLightCycle` fica **Enabled = false** (`enable-old` reverte); o dono precisa salvar o place. `Signal_NB/SignalHead~2/Backplate` esta `Anchored = false` no Studio (edicao do dono, espelhada como lida).

## Faixas movidas pelo dono: nos de NPC, caixa e linhas de CW-1 (2026-10-12, `crosswalk_paths.luau`, Provisorio)

O dono moveu as listras de `MAP01_Blockout.Crosswalks.CW-1` da Juniper Sul para a boca da Ninth (centro Z 43,89; antes Z 29,89), copiou uma faixa igual na Juniper Norte (2o modelo tambem chamado "CW-1", Z 92,49, sem nos) e tirou o modelo `CW-3`. Snippet de Studio, idempotente, nunca mexe nas listras: `run("crosswalk_paths")` (relatorio), `"apply"`, `"undo"` (restaura pelos atributos `CwOrig*`; marca `CwPathsV1`). Nao e Place.run: so toca `MapBinding` (nos `N-Z08-04/05`, elos de `N-Z08-04`/`N-Z02-02`/`N-Z08-03`, `Traffic.Boxes.CW-1`, `Traffic.Lines.SL-1N/SL-1S`).

| Peca | Antes | Depois |
|---|---|---|
| `N-Z08-04` / `N-Z08-05` | (-13 / 13; 29,89) | (-13 / 13; 42,49), 1,4 studs ao sul do centro das listras (poste do letreiro SW em X >= 12,2 Z 47,0..47,5; regra 6 do check exige >= 1,2 das caixas dos letreiros) |
| elos | `N-Z08-03` <-> `N-Z08-04` | `N-Z02-02` <-> `N-Z08-04` (`N-Z08-03` fica ligado a `N-Z08-02` / `N-Z02-02`) |
| `TrafficBox CW-1` | centro Z 29,89, comprimento 8 | centro Z 43,89, comprimento 8 |
| `SL-1N` / `SL-1S` | Z 37,89 / 21,89 | Z 49,89 / 35,89 |

Depois de um `Place.run` + `bind_map01`: o bind ja grava estes valores (nos z 25,4 MAP, caixa z 20..28, linhas z 18 / 32); rodar `crosswalk_paths` em seguida so confere (relatorio). Pendente do dono: CW-3 sem listras, faixa da Juniper Norte sem path, PARE `SL-S` / `SL-N` (ver `playtest-2026-10-12.md`).

## Estações do preparo focado (2026-10-12, `stations_prep.luau`, TASK-172, Provisório)

Snippet de Studio, idempotente, nada apagado: `run("stations_prep", "dry")` (relatório + validação por raycast), `run("stations_prep")` (aplica), `run("stations_prep", "undo")` (move `Station_1..4` para `ServerStorage.Trailer_Backup_20261012` sem tags, restaura `Att_Bun1..3` por `PrepOrigX` e manda `Att_Bun4` para o backup). Cria `Station_1..4` dentro do Model do trailer (segue `PivotTo` e `trailer_ground`) e põe a tábua em 4 vagas; números e desenho em `docs/levels/MAP-01.md` §19. Não está nos placements: depois de um `Place.run` rodar **`bind_map01`** (que agora recria as 4 estações por `bindPrepStations`) ou este snippet, antes do `check_map01`. O dono precisa salvar o place (Ctrl+S).

## Xicara de cafe do dono (2026-10-12, `coffee_cup.luau`, Provisorio)

O dono acrescentou `Workspace.ManFaceMug` (raiz do Workspace, fora de `MAP01_Assets` e dos placements: o `Place.run` nao a apaga nem a recria). Partes: `Part` (cilindro marrom = superficie do cafe, interno), `Intersection` (corpo bege com a cara), `Union` (alca, a direita). Fica ao lado da `TRL-COFFEE_AST-022_CoffeeMachine` (1,2 studs).

`run("coffee_cup")` relata; `"apply"` grava; `"undo"` desfaz (tag, atributos, Anchored). Idempotente (marca `CoffeeCupV1`; a pose cheia lida na primeira vez nao e relida). Nada e movido nem apagado. Grava na xicara: tag `CoffeeCup`; `CupStation` (MapId da cafeteira mais proxima), `CupFillSurface` (`Part`), `CupBody` (`Intersection`), `CupFullCFrame` (pose da superficie no espaco do corpo, a que o dono deixou = cheia), `CupFullY` (so informativo), `CupEmptyOffset` (0,34). Ancora a `Intersection` (estava solta e cairia no Play; original em `CupOrigAnchored`).

Ao mover a xicara com o corpo a pose acompanha (relativa ao corpo). Se o dono trocar o nome das partes, rodar `apply` de novo depois de ajustar `SURFACE` / `BODY` no topo do snippet. O visual vive em `CoffeeCupController` (`Content.CoffeeCup`); `/dev coffeecup fill|empty|auto`.

## Caçambas do lixo da mesa (2026-10-12, `trash_bins.luau`, Provisorio)

O dono acrescentou duas caçambas em `workspace.MAP01_Assets.Extra` (duas Parts `P2`, malha unica, sem tampa, frente +Z): fora dos placements, entao um `Place.run` as apaga (capturar antes). `run("trash_bins")` relata; `"apply"` grava; `"undo"` desfaz (idempotente, marca `TrashBinsV1`). Nada e movido nem apagado. Grava: tag `TrashBin`, `BinId` (BIN-1 oeste, BIN-2), Attachments `DropPoint` (topo + 0,4) e `ApproachPoint` (1,8 a frente, no chao), `MapDrop` / `MapApproach` (coordenadas MAP, so registro). Hoje: BIN-1 drop (-36,5; 5,0; -3,23) approach (-36,5; 0,45; 0,82); BIN-2 idem com x -29,4. O visual vive em `TrashController` (`Content.Trash`); `/dev trash [mesa]`. Tampa: se o dono modelar `Lid` (BasePart) e um Attachment `LidHinge` dentro da caçamba, o controller a abre sozinho; sem tampa ele faz um solavanco de escala na malha. `MapIndex/Required.luau` e `WalkPaths` nao mudaram (nenhum NPC limpa mesa).

### Estacoes do preparo V2: dois prompts naturais (2026-10-12, `stations_prep.luau`, Provisorio)

`run("stations_prep")` agora aplica a V2: assentos continuam 4 e logicos, mas so `Station_1/Prompt_Work` (grelha, `PromptStep = Grill`) e `Station_3/Prompt_Work` (tabua, `PromptStep = Build`) existem, a Y 4,3 (altura de peito; a Y 2,2 o prompt saia da tela em primeira pessoa). Os `Prompt_Work` de Station_2 e Station_4 vao para `ServerStorage.Trailer_Backup_20261012` (`StashedBy = "stations_prep: v2 extra prompt"`). Cada estacao ganha `Att_Stand_Build`, `CamAnchor_Build`, `Focus_Build` (vista da tabua); `Att_Stand` escalonado 1,0 stud em torno do centro da vista. `run("stations_prep", "undo")` volta ao layout V1 (4 prompts, tira os anexos `_Build` para o backup, devolve os prompts); `"remove"` e o antigo undo (estacoes e vaga 4 para o backup); `"dry"` so relata. `bind_map01` (`bindPrepStations`) e `check_map01` (regra 17) espelham a V2. Depois de um `Place.run`: `bind_map01` ou este snippet. O dono precisa salvar (Ctrl+S).
