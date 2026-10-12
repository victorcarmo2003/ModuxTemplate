# Relatorio de limpeza do Workspace (somente leitura, 2026-10-12)

Nada foi apagado ou movido. Varredura em Edit (place salvo pelo dono): raiz do Workspace, MAP01_Assets, LOBBY_Assets, MapBinding,
ServerStorage. Para agir: revise, depois `tools/assetplace/cleanup_stray.luau` (DRY = true por padrao; `ALLOW_DELETE` vazio).

Nao ha: Highlight, SelectionBox, Trail, Beam de teste solto no Map, MapId duplicado (MAP01_Assets e LOBBY_Assets: 0), parts na origem, Attachments
orfaos fora da fonte do lobby. `MAP01_Blockout` e `DevScenes` (ServerStorage) estao ok.

| # | Caminho completo | Tipo | Posicao (mundo) | Motivo | Recomendacao |
|---|---|---|---|---|---|
| 1 | `Workspace.AST-100_PicnicTable` (TableIndex 6) | Model (SeatTable, TableGroup Trailer) | (-61.3, 0.0, 112.2) | mesa do trailer solta na raiz | MOVER para `MAP01_Assets.TrailerTables` (so Parent): `cleanup_stray.luau` faz isso (MOVE_TABLES = true) |
| 2 | `Workspace.AST-100_PicnicTable` (TableIndex 7) | idem | (-61.3, 0.0, 104.9) | idem | idem |
| 3 | `Workspace.AST-100_PicnicTable` (TableIndex 8) | idem | (-87.6, 0.0, 113.3) | idem | idem |
| 4 | `Workspace.AST-100_PicnicTable` (TableIndex 9) | idem | (-87.6, 0.0, 106.0) | idem | idem. Ja gravadas como `TTBL-6..9` em MAP-01_placements.luau |
| 5 | `Workspace.Model` | Model, 6 MeshParts + Attachments / Beams (82 descendentes) | (-45.7, 4.5, -664.2) | fonte (Water, Beams, "Space wave") vinda do Toolbox (mesh rbxassetid 70456xxxxx), solta na raiz, no lugar da fonte do lobby; `docs/art/credits.md` NAO a cita | NAO apagar. Mover para `LOBBY_Assets.LobbyFountain` (renomear `Fountain_Toolbox`, entrada MOVE_OPTIONAL, `on = false`) e verificar a LICENCA (regra do CLAUDE.md: so entra com licenca comercial registrada) |
| 6 | `Workspace.Model.Mesh.Water.*`, `Workspace.Model.Beams.*` | 21 Attachments cujo pai nao e BasePart + 26 Beams | idem | parte da fonte do item 5 (estrutura do Toolbox) | manter junto com o item 5 |
| 7 | `ServerStorage.BeamExample` | Part com 4 Attachments (P1..P4), sem Beam | n/a | sobra de teste de Beam (copiado do exemplo da fonte) | candidato a apagar depois de revisar (`ALLOW_DELETE = { "ServerStorage.BeamExample" }`) |
| 8 | `Workspace.MAP01_Assets.Trailer` | Folder vazio | n/a | pasta do grupo "Trailer": o trailer vive em `Night_Trailer` (layer night) | manter (o Place.run recria; `showLayer` usa) |
| 9 | `Workspace.MAP01_Assets.StreetLights.Model` (x15) | Model generico com poste + LampHead | varios (y 7.5) | o dono agrupou (Ctrl+G) poste e cabeca; Place.diff ja trata | manter; opcional renomear `Post_<id>`; um Place.run desfaz o agrupamento |
| 10 | `MAP01_Assets.MartInterior.Model`, `MartDecor.Model`, `MAP01_Assets.Model` (+ `.Model`), `LOBBY_Assets.LobbyProcedural.Model` (x5) | Models genericos | (83.6, 2.2, 34.2), (93.6, 10.1, 19.9), (57.6, 11.8, 41.5), squads | agrupamentos manuais: banca de verduras (ProduceStand + 2 LettuceCrate), neons, marquise, plataformas de squad | manter (conteudo valido); nomear quando virar placement |
| 11 | `MAP01_Assets.MartDecor.*` `Neon_*` com 2 filhos de mesmo nome e posicao (7 pares `Joint`) | Parts | varios | juncoes de neon (cantos) criadas por decor_mart.luau | normal, nao e duplicata |
| 12 | `ServerStorage.__AssetCache`, `__AssetPlaceTool`, `MAP01_Assets_Night` | Folders | n/a | infra do place_assets (cache de templates, ferramenta, camada noite) | manter |
| 13 | `MAP01_Assets` entradas 185-202 dos placements (GEAR_WALL, OP-1, gondolas antigas) | nao existem vivas | n/a | tiradas a mao; o placement ainda as recria vazias num Place.run | ver STUDIO_LAYER.md (nao e lixo vivo) |

## Como usar

1. Rode `cleanup_stray.luau` em DRY (padrao): lista o que moveria.
2. Para mover as 4 mesas: troque nada (MOVE_TABLES ja e true) e ponha `DRY = false`. Salve o place depois.
3. Para apagar algo: escreva o caminho exato em `ALLOW_DELETE`, `DRY = false`. O snippet recusa 0 ou >1 correspondencia.
4. Depois das mesas moveridas: `Place.diff` deixa de listar #797-#800 como MISSING.
