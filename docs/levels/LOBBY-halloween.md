Status: Rascunho (Provisório)

# LOBBY — Overlay de Halloween (Fase 1: auditoria + plano)

Autor: orquestrador (sessão 2026-10-21), a partir do brief "Halloween Lobby Transformation" colado pelo dono.
**Plano aprovado na DEC-346** (P-HW1..6 como recomendado; o dono delegou as fases 2–6 e revisa no fim). **Aplicado no
place em 2026-10-21** (pasta `workspace.HalloweenEvent`, §10). §1–§9 = auditoria e plano da Fase 1 (histórico); as
posições finais estão em `tools/assetplace/HALLOWEEN_placements.luau`, que vale sobre as coordenadas do §5. Fontes: place aberto no Studio (`[🎃] Sell Hotdogs`, placeId 77238662189454, modo Edit, lido via MCP em
2026-10-21), `levels/LOBBY.md`, `art/direcao-ambiente-lobby-mapa.md` (DEC-289), `Content.Lobby`, `Content.LightPresets`.

Capturas de referência (antes): `art/mockups/halloween-2026-10-21/base_*.jpg` (topo + 4 direções a partir do spawn).
Atenção: são do modo **Edit**, com o `Lighting` do Studio; no Play o `LightController` aplica o preset `Lobby` (frio,
Brightness 0,5, Exposure −0,35). A QA visual da Fase 5 tem que ser no Play.

---

## 1. Acesso real nesta sessão

| Ferramenta | Estado |
|---|---|
| Roblox Studio (MCP) | **conectado**, leitura/execução no Edit; caiu 1× e voltou |
| Blender (MCP) | desconectado o tempo todo; a modelagem rodou no **Blender 5.2 headless** (skill `roblox-asset-pipeline`, `bl.sh`) |
| Repositório | completo (`src/`, `docs/`, `tools/assetplace/`) |

## 2. O que existe hoje (medido no Studio, WORLD)

O `levels/LOBBY.md` (v2) está **desatualizado** em vários pontos; a tabela abaixo é a fonte para este overlay.

| Elemento | Posição / limites medidos | Observação |
|---|---|---|
| `LOBBY-SPAWN` | (−1,5, 0, −620), olha +Z | doc diz (5, −620) |
| Disco central `HubDisc` | Ø ~33–36 em volta do spawn, 4 caminhos radiais (N HQ, L squads, O Gem Shop, S Codes) | é o "anel" de chão das capturas |
| HQ / carrinho / palco de classes | carrinho X −20..19, Z −561..−548; palco Z −568..−558; zona Classes (−1,5, −576,5), retângulo 23,2 × 16,6 | letreiro "CORNER DOGS / HQ" |
| Food court (trailer listrado + mesas) | X −73..−24, Z −692..−546 (pasta inteira); NPCs `food_pig`/`food_dog` em (−38/−34, −584) | |
| Gem Shop | X −71..−33, Z −640..−605; zona (−39,2, −620), avental 13 × 31 | vendedor `shop_keeper` (−41,8, −620) |
| Codes | zona real = Part `Zone_Codes` (−1,6, 0,2, −675,4), giro 139,5°; mural `CodesBooth` (−2, ·, −682) | o `MapPoint LOBBY-CODES` ainda aponta para (−19,8, −599,2) (fallback antigo; ver §7) |
| Squads | **4** pads Ø 16 em X ~39, Z −655 / −631 / −608 / −585, sob o pórtico `LobbyStartGantry` (X 27..52) | doc diz 8 pads |
| START / van | `LOBBY-START` (56,3, 0, −620); motorista `van_driver` | |
| Fonte | centro (−46, ·, −664), raio ~11, 4 bancos N/S/L/O, 4 floreiras | ícone neon de hot dog no topo |
| Cabine de foto | `Neon_Photo` (39, 12, −559), canto NE | |
| Mastro / topper | `Mast_Topper` (28, 18, −620) | **duplicado** (2 × 58 peças Neon no mesmo lugar) |
| Mascote gigante | `LobbyMascot` X −9..6, Y 40..61, Z −707..−696 (no prédio atrás do Codes) | |
| Névoa | `PlazaFog` (11, −1, −637) | partículas |

Orçamento atual do `LOBBY_Assets` (contagem de instâncias, não FPS): **2.107 Parts** (271 MeshParts),
**1.054 Neon**, **81 luzes locais**, **48 emissores** (45 só no `Garden`). O alvo do `LOBBY.md` era 14–18 luzes: o lobby já
está muito acima. Conclusão: **o overlay de Halloween não adiciona nenhuma luz real nova**; brilho só por material Neon
pontual e, se preciso, reaproveitando/recolorindo luzes que já existem.

## 3. Diagnóstico (contra o brief)

Pontos fortes: layout radial claro, 4 marcos cardeais legíveis (HQ, Gem Shop, Codes, pórtico de squads), fonte e
food court já dão vida, NPCs de cenário (TASK-452) e teaser de janela já previstos (TASK-453, DEC-289 L6).

Problemas que o overlay deve resolver ou não piorar:

1. **Centro sem marco próprio.** O spawn é um disco de cobblestone vazio; o mastro está fora do eixo (X 28). Falta um
   "isso é Halloween" nos primeiros 3 segundos.
2. **Neon demais** (1.054 peças) — a DEC-289 já pediu menos neon. Abóboras e lanternas **não podem** virar mais
   papel de parede luminoso: brilho só nos focos.
3. **Fachadas escuras e grandes** sem detalhe na altura dos olhos (O e S). Bom lugar para teias, morcegos, janelas.
4. **Dados velhos**: doc v2 e `MapPoint LOBBY-CODES` não batem com o place (§7).
5. **Iluminação do Edit ≠ Play.** Qualquer decisão de cor tem que ser conferida no Play com o preset `Lobby`.

## 4. Princípios do overlay

- **Um só root removível:** `workspace.HalloweenEvent` (Folder), irmão do `LOBBY_Assets`, nunca dentro dele. Nada do
  lobby é apagado, movido ou recolorido. Desligar o evento = `Parent = nil` (ou apagar a pasta).
- Subpastas por zona: `HW_Spawn`, `HW_HotDogs`, `HW_Fountain`, `HW_GemShop`, `HW_Codes`, `HW_Classes`, `HW_Edges`,
  `HW_Photo`. Atributos no root: `Event = "Halloween2026"`, `EndsAt` = mesmo `EndsAt` das skins (DEC-316, 2026-11-06 03:00 UTC).
- Toda peça decorativa: `Anchored`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `CastShadow = false`
  (exceto o caldeirão, que colide por um proxy simples). Nada entra num raio de **3 studs** de zona, avental, pad, spawn
  (`HubDisc`) ou caminho radial.
- Brilho: só Neon pontual (olhos/boca das abóboras-lanterna, chama de lanterna, líquido do caldeirão). **0 luzes novas.**
  Partículas: no máximo **3 emissores** novos (bolhas, névoa roxa, brilho da fonte), Rate baixo.
- Paleta (style guide + brief): abóbora `#F28C28`, âmbar `#FFB25A`, violeta `#7B4BC4`, magenta suave `#C45BB8`,
  verde-poção `#5FD38D`, creme `#FFF3DC`, ferro do caldeirão `#3A2E4F`. Nada de vermelho de alerta (style guide §2.4).
- Tom: fofo primeiro, estranho depois. Sem caveira, sem sangue, sem susto, sem som alto.
- Liga/desliga em código: `Content.Events.Halloween.Enabled` (data) + client mostra/esconde o root. Opcional: preset de
  luz `LobbyHalloween` (só Tint/Atm um pouco mais roxos) aplicado pelo `LightController` quando ligado.

## 5. Plano por zona (coordenadas WORLD, Provisórias até conferir no Play)

### Z-A. Caldeirão (marco do spawn)
- **Onde:** quadrante NE do disco, **(16, 0, −603)**: fora do `HubDisc` (24 studs do spawn), entre o caminho do HQ e o
  pórtico de squads. Varredura no Studio: nenhum objeto num raio de 9. Do spawn olhando +Z (câmera inicial) ele fica à
  frente-direita, sem tapar o HQ nem o pórtico.
- **Alternativa** se tapar visão no Play: quadrante SO (−19, 0, −637), entre Gem Shop e Codes (tem um objeto a 3,1 —
  conferir o que é antes).
- **Peças:** `HW_Cauldron_Main` (~Ø 7 × 5 de altura, 3 pés curtos, borda grossa laranja), líquido verde-poção Neon,
  `HW_Cauldron_Bubble` ×6–8 (esferas Neon animadas no client, sobe-e-some lento), 1 `ParticleEmitter` de névoa roxa
  (Rate ≤ 4), 3 abóboras + 1 balde de doces + 2 lanternas de chão na base. Colisão: 1 cilindro invisível Ø 7.
- **Placa "HALLOWEEN EVENT":** **não** na v1 (competiria com "CORNER DOGS"). Reavaliar depois do Play.

### Z-B. Hot Dogs (HQ + food court)
- Varal curto novo de lâmpadas laranja/roxo (Neon, **sem luz real**) entre os postes do palco. Recolorir um varal que
  já existe seria mais barato, mas mexe no lobby original (P-HW4).
- `HW_Hotdog_Pumpkin_Sign`: placa pequena (abóbora segurando hot dog) **ao lado** do "CORNER DOGS", nunca cobrindo.
  Posição a medir no Play (candidato: telhado do carrinho, X ~14).
- 2 pilhas de abóboras (3 cada) nas pontas do carrinho, fora do retângulo da zona Classes (Z > −568 é carrinho, zona vai
  até −584,8 → pilhas em Z −560, X ±22).
- 2 `HW_Candy_Bucket` + 2 `HW_Crate` junto ao trailer do food court, encostados no trailer (lado de fora das mesas).
- Anomalia fofa: **usar a TASK-453** (olhos na janela, já aprovada na DEC-289 L6) apontada para uma janela acima do HQ,
  com olhos em forma de abóbora durante o evento. Sem NPC fantasiado na v1 (o brief pede aprovação).

### Z-C. Fonte
- Não mexer em nada da fonte. Overlay: `ParticleEmitter` de brilho violeta/ciano sobre a água (Rate ≤ 3, Lifetime 2),
  4 abóboras pequenas sobre as floreiras existentes (`FountainPlanter_1..4`), 2 lanternas nos bancos N e S.
- Olhos piscando na água: **fase 2**, só se a TASK-453 ficar pronta e leve.

### Z-D. Gem Shop / Codes / Classes
- **Gem Shop:** 2 `HW_Crystal_Cursed_A/B` (violeta/laranja, Neon só na ponta) nos cantos do telhado, faixa de tecido
  roxo na marquise (abaixo do letreiro, sem cobrir "GEM SHOP"), 2 abóboras pequenas no balcão. Nada dentro do
  avental 13 × 31.
- **Codes:** 3 `HW_Bat_Silhouette` de papel presos no mural (bordas, fora do texto), 2 lanternas nas laterais, 1
  `HW_Ghost_Cute` pequeno espiando atrás do poste direito (o "segredo" do canto).
- **Classes:** `HW_Pennant_String` laranja/roxo entre os postes do palco, **acima** do enquadramento da câmera de classes
  (`LOBBY-CLASS-CAM` (−1,5, 5,8, −577,8) → conferir no Play que nada entra no quadro).

### Z-E. Bordas, fachadas, céu
- 8–10 clusters `HW_Pumpkin_*` (2–3 cada) nas floreiras e cantos **já existentes** (bordas O e S, pé dos prédios).
- 4 `HW_Cobweb_Corner` em quinas de marquise baixas (Gem Shop, Codes, food court, HQ lateral).
- 6–8 `HW_Bat_Silhouette` em pares nos telhados do fundo (Y 30–45), estáticos; 1 par com voo em loop lento (client).
- Lua: conferir no Play se o `Sky` atual aceita uma lua maior; se não, nada (não trocar o céu na v1).
- Janelas: **reaproveitar** a TASK-453 (2–3 janelas com olhos/silhueta), não acender mais janelas.

### Z-F. Canto de foto
- Já existe a cabine "PHOTO" no NE (39, −559). Overlay: `HW_Moon_Arch` (arco de lua crescente Ø ~8) **ao lado** da
  cabine, voltado para a praça, + `HW_Ghost_Cute` + 3 abóboras + `HW_Photo_Sign` "SPOOKY SNAPSHOT" (texto a validar com
  o narrative-writer, `story/ui-text.md`). Espaço livre de 6 × 6 à frente. Posição exata depende de conferir o
  corredor entre a cabine e o pad 4 (Z −585).

### Interações opcionais (todas para depois da v1 visual)
| Ideia | Recomendação |
|---|---|
| Caça aos doces (5–8) | **v2**, sem recompensa até o dono decidir (P-HW3) |
| NPC "gostosuras ou travessuras" | não na v1; daria pra reaproveitar `Content.Lobby.Extras` com uma skin de Halloween (AST-123) |
| Olhos nas janelas | sim, via TASK-453 (já aprovada) |
| Caldeirão reage ao chegar perto | **v1.5**: só client, `ProximityPrompt` não, só distância < 8 → burst de bolhas, cooldown 6 s |

## 6. Inventário de assets (Fase 3)

Regra do projeto: cada asset vira ficha `AST-###` em `art/asset-list.md` antes de modelar (próximo ID livre: AST-167).
Origem: modelado no Blender do zero (low-poly, atlas da paleta), ou pack CC0 com licença registrada em
`art/credits.md`. Nenhum dos packs locais (`FoodPack`, `KitchenPack`) tem abóbora/caldeirão (conferido por nome).

| Prioridade | Asset | Tris alvo | Materiais | Colisão |
|---|---|---|---|---|
| **Must (lote 1)** | `HW_Cauldron_Main` | ≤ 1.500 | atlas 1 + Neon (líquido) | proxy cilindro |
| Must | `HW_Pumpkin_Small` / `_Medium` / `_Large` | ≤ 300 / 400 / 500 | atlas 1 | nenhuma |
| Must | `HW_Pumpkin_Face_A/B/C` (variações de rosto, Neon interno) | ≤ 500 | atlas 1 + Neon | nenhuma |
| Must | `HW_Lantern_Post` / `HW_Lantern_Hanging` | ≤ 400 | atlas 1 + Neon | nenhuma |
| Must | `HW_Cauldron_Bubble` | esfera Roblox (procedural) | Neon | nenhuma |
| Should | `HW_Candy_Bucket`, `HW_Candy_Cluster`, `HW_Crate` | ≤ 300 | atlas 1 | nenhuma |
| Should | `HW_Bat_Silhouette`, `HW_Cobweb_Corner`, `HW_Pennant_String` | ≤ 150 (planos) | atlas 1 | nenhuma |
| Should | `HW_Ghost_Cute` | ≤ 600 | atlas 1 | nenhuma |
| Nice | `HW_Moon_Arch`, `HW_Photo_Sign`, `HW_Hotdog_Pumpkin_Sign` | ≤ 800 | atlas 1 + Neon | nenhuma |
| Nice | `HW_Crystal_Cursed_A/B`, `HW_Autumn_Shrub`, `HW_Leaf_Cluster` | ≤ 300 | atlas 1 | nenhuma |

Uma textura atlas 512² compartilhada por todo o kit (`T_HW_Atlas`), cores chapadas por UV (padrão do
`roblox-asset-pipeline`). Estimativa total colocada: ~60–80 instâncias, ≤ 25 mil tris, 0 luzes, ≤ 3 emissores.
Fontes em `Assets/blender/props/AST-###_HW_<Nome>.blend`, exportados em `Assets/models/props/AST-###_HW_<Nome>.fbx`.

## 7. Achados fora do overlay (não corrigidos aqui)

| # | Achado | Sugestão |
|---|---|---|
| F1 | `Mast_Topper` duplicado (2 × 58 peças Neon no mesmo lugar, (28, 18, −620)) | apagar um no Studio (level-designer), com sync do bind |
| F2 | `MapPoint LOBBY-CODES` em (−19,8, −599,2), mas a zona real é a Part `Zone_Codes` (−1,6, −675,4) | mover o MapPoint ou registrar que é só fallback |
| F3 | `levels/LOBBY.md` v2 diverge do place (spawn, 4 pads em X 39, Codes, mastro) | level-designer atualiza o doc com as medidas da §2 |
| F4 | 81 luzes locais no lobby (alvo 14–18) | auditoria de luz separada (rbx-scene-analysis) |

## 8. Fases e checkpoints

1. **Fase 1 (esta)** — auditoria + plano. Feito, aguardando o dono.
2. **Fase 2** — dono aprova P-HW1..6 → secretário registra DEC, `task-planner` cria as TASKs, art-director escreve as
   fichas AST-167+.
3. **Fase 3** — Blender: caldeirão + 3 abóboras + 1 lanterna primeiro, renders frente/lado/¾, revisão, depois o resto.
4. **Fase 4** — Studio: pasta `HalloweenEvent` por placement table (`tools/assetplace/HALLOWEEN_placements.luau`),
   sem tocar no `LOBBY_Assets`; flag em `Content`.
5. **Fase 5** — QA no Play (preset `Lobby` ativo): mesmas 5 câmeras das capturas `base_*`, simulador de celular, gráfico
   baixo; distâncias de zona e corredores reconferidos por raycast.
6. **Fase 6** — entrega: catálogo, antes/depois, como desligar (apagar `workspace.HalloweenEvent` + `Enabled = false`).

Prazo: hoje é 2026-10-21; Halloween 31/10; skins vão até 05/11 (DEC-316). Lote 1 (caldeirão + abóboras + lanternas
+ clusters de borda) cabe em ~3–4 dias se o Blender estiver disponível; o resto entra se sobrar tempo.

## 9. Perguntas para o dono (lote)

| ID local | Pergunta | Recomendação |
|---|---|---|
| P-HW1 | Caldeirão no quadrante NE (16, −603) ou SO (−19, −637)? | NE (visível da câmera inicial, nada no raio) |
| P-HW2 | O evento liga sozinho por data (até `EndsAt` das skins) ou por flag manual? | flag `Enabled` + `EndsAt` (desliga sozinho em 06/11) |
| P-HW3 | Caça aos doces com recompensa (moeda/gema/badge) ou só visual? | só visual na v1; recompensa = DEC nova |
| P-HW4 | Pode recolorir peças existentes (varais, água da fonte) durante o evento, ou só peças novas por cima? | só peças novas na v1 (reversível por apagar a pasta) |
| P-HW5 | Placa "SPOOKY SNAPSHOT" e "HALLOWEEN EVENT" em inglês no 3D (como os outros letreiros)? | sim, só a do canto de foto |
| P-HW6 | Modelar no Blender do zero ou aceitar pack CC0 (ex.: Kenney/Quaternius) como base? | Blender do zero com atlas próprio (estilo único, sem licença a rastrear) |

---

## 10. Entrega (Fases 2–6, 2026-10-21)

### 10.1 O que está instalado de verdade

| Item | Onde | Verificado |
|---|---|---|
| 21 modelos do kit (AST-167..176) | `Assets/blender/props/AST-1[67]*_HW_*.blend` → `Assets/import/props/*.fbx` → Roblox (grupo 773736808), ids em `Assets/import/_asset_ids.json` | escala 1:1 e frente −Z conferidas por `LoadAsset` no Studio; texturas embutidas |
| Overlay no place | `workspace.HalloweenEvent` (subpastas `HW_Spawn`, `HW_HotDogs`, `HW_Fountain`, `HW_GemShop`, `HW_Codes`, `HW_Edges`, `HW_Photo`), 103 Parts, montado por `tools/assetplace/HALLOWEEN_placements.luau` | capturas no Edit e no Play; **o place ainda não foi salvo** (Ctrl+S é do dono) |
| Flag do evento | `Content.Events.Halloween` (`src/Shared/Content/Events.luau`): `Enabled = true`, `EndsAt` = 2026-11-06 03:00 UTC (mesmo das skins) | `analyze` 0 erro, `modux check` ok |
| Animação no client | `src/Lobby/client/LobbyController/Halloween.luau` (Heartbeat do `LobbyController`): 7 bolhas no caldeirão, burst a < 8 studs (cooldown 6 s), 3 morcegos balançando, 2 pares de olhos piscando | Play: 7 bolhas visíveis, morcego mexendo, nenhum erro no console |
| Fontes da modelagem | `tools/halloween/` (`gen_atlas.py`, `hwlib.py`, `lot1.py`, `lot2.py`, `sheet.py`); atlas `Assets/textures/props/T_HW_Atlas.png` | renders em `art/mockups/halloween-2026-10-21/renders/` |

Nada fora de `workspace.HalloweenEvent` foi tocado no place (P-HW4). O `Lighting` e o preset `Lobby` não mudaram.

### 10.2 Catálogo

| AST | Modelo | Tamanho (studs) | Tris | Brilho (Neon) | Onde está |
|---|---|---|---|---|---|
| 167 | `HW_Cauldron_Main` | 7,3 × 4,6 × 6,9 (colocado em ×1,3) | 1.000 | `Glow_Liquid` verde | oeste da praça, (−35, −590,4), virado para o spawn (DEC-347, edição do dono) |
| 168 | `HW_Pumpkin_Small/Medium/Large` | Ø 1,4 / 2,2 / 3,2 | 392 | — | bordas, pilhas, base do caldeirão |
| 168 | `HW_Pumpkin_Face_A/B/C` | Ø 2,2 × 1,8 | 484–508 | `Glow_Face` âmbar | todas as zonas |
| 169 | `HW_Lantern_Post` / `_Hanging` | 1 × 4,9 × 1,8 / 1 × 2 × 1 | 368 / 256 | `Glow_Lamp` | caldeirão, Classes, fonte, Codes |
| 170 | `HW_Candy_Bucket` / `_Cluster` | Ø 1,5 × 1,8 / 1,6 × 0,6 | 544 / 476 | — | caldeirão, food court |
| 171 | `HW_Crate` | 2,1 × 1,6 × 2,1 | 356 | — | food court |
| 172 | `HW_Bat_Silhouette` / `HW_Cobweb_Corner` | 2,4 × 0,8 / 2 × 2 | 164 / 190 | — | telhados e Codes / quinas |
| 173 | `HW_Pennant_String` | 8 × 1,4 | 148 | — | viga oeste do pórtico dos squads (6×) |
| 174 | `HW_Ghost_Cute` | 2,3 × 2,0 | 388 | — | Codes (espiando), canto de foto |
| 175 | `HW_Moon_Arch` / `HW_Photo_Sign` / `HW_Hotdog_Pumpkin_Sign` | 7,1 × 8,3 / 5,4 × 3,6 / 2,5 × 2,5 | 404 / 232 / 396 | lua Neon suave + `Glow_Stars` | canto de foto / ao lado do "CORNER DOGS" (×2) |
| 176 | `HW_Crystal_Cursed_A/B` | 1,9 × 2,5 | 184 | `Glow_Tips` | telhado da Gem Shop |

Orçamento colocado: 103 Parts, **0 luzes**, **3 ParticleEmitters** (névoa e burst do caldeirão, brilho da fonte). Um só
atlas (`T_HW_Atlas`, 512 × 256) para o kit inteiro.

### 10.3 Antes / depois

`art/mockups/halloween-2026-10-21/comparativo.jpg` (mesmas 4 câmeras a partir do spawn, modo Edit) e `play_*.jpg` (Play,
preset `Lobby`). Os `*_v1.jpg` são de uma iteração anterior (teias espelhadas, caldeirão menor), guardados como registro.

### 10.4 Achados do QA e o que foi corrigido

| Achado (captura) | Correção |
|---|---|
| Teias crescendo para fora das quinas | a teia corre no +X local do modelo; rotações trocadas |
| Placa hot dog atrás da árvore / atrás do balcão | subiu para a fachada, ao lado do "CORNER DOGS", ×2 |
| Pilha de abóboras em cima do canteiro com árvore | movida para (24, −575,5) |
| Poção do caldeirão invisível da altura do jogador | `Glow_Liquid` vira domo acima da borda no placement |
| Caldeirão na linha reta spawn → pad 4 | movido para (14, −597,5) |
| À noite (preset `Lobby`) só as abóboras com rosto aparecem | 7 abóboras lisas trocadas por rostos acesos |
| Bolhas não nasciam (StreamingEnabled: a pasta chega depois do controller) | modelos `Persistent` + o client procura as peças por 30 s |

Folga medida por script (bbox × zonas `LobbyZone`, zona Classes, pads, disco do spawn r 18): tudo ≥ 3 studs, exceto
bordas de piso sem função (disco de pedra do spawn 1,9–3,0; avental da Gem Shop 2,7–2,9; Codes 2,9), sem fechar corredor.
Câmera de classes: as lanternas do Classes ficam em |X| ≥ 14,5, fora do quadro calculado.

### 10.5 Riscos e limites (sem números inventados)

- **FPS não medido.** O custo previsto é baixo (0 luzes, 3 emissores com Rate ≤ 3, 7 bolhas, ≤ 3 `PivotTo` por frame), mas
  não houve teste em celular real nem no simulador de dispositivo (fica na TASK-630).
- **Lobby escuro.** O preset `Lobby` (DEC-289, frio) deixa abóboras lisas, cristais e teias pouco visíveis à noite. O brief
  pedia "mais claro"; mudar a luz contrariaria a DEC-289, então não foi feito. Opção para o dono: um preset
  `LobbyHalloween` (um pouco de `Ambient` roxo) ligado pela flag.
- Texto "SPOOKY SNAPSHOT" (inglês) fora do `story/ui-text.md`: narrative-writer confere.
- Olhos nas janelas = versão simples do teaser L6; a TASK-453 segue aberta para a versão completa ("somem se o jogador
  olhar fixo").

### 10.6 Como desligar / reverter

1. Desligar sem mexer no mapa: `Content.Events.Halloween.Enabled = false` (o client tira a pasta do mundo localmente).
   Depois de 2026-11-06 03:00 UTC isso acontece sozinho.
2. Remover de vez: no Studio, `workspace.HalloweenEvent:Destroy()` e salvar. Nada mais no place depende dela.
3. Reinstalar / ajustar: rodar `tools/assetplace/HALLOWEEN_placements.luau` no Edit (idempotente: apaga e refaz a pasta).

### 10.7 Ideias que dependem de nova autorização

Caça aos doces com recompensa (DEC nova, P-HW3); NPC fantasiado reaproveitando `Content.Lobby.Extras` + skins AST-123;
placa "HALLOWEEN EVENT" (P-HW5); preset de luz de Halloween (10.5); olhos piscando na água da fonte.

### 10.8 Ajuste do dono no Studio (DEC-347)

Depois da entrega, o dono moveu o grupo do caldeirão para (−35, −590,4), entre o food court e a Gem Shop, e as duas
lanternas do grupo para perto do pórtico dos squads. A tabela do placement foi atualizada com os valores lidos do place
(diff 0). As linhas da §10.4 sobre a posição (14, −597,5) e sobre o pad 4 ficam como histórico.
