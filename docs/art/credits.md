Status: Rascunho

# Créditos e licenças de assets de terceiros

Regra (`CLAUDE.md`): asset de terceiros só entra com licença verificada que permita uso comercial.

| Pack / asset | Autor | Licença | Arquivo de licença | Crédito obrigatório? | Usado em |
|---|---|---|---|---|---|
| Food Kit 2.0 (`Assets/FoodPack`) | Kenney (www.kenney.nl) | CC0 1.0 | `Assets/FoodPack/License.txt` | não (crédito voluntário, damos mesmo assim) | `asset-list.md`, origem `FP/`: AST-001 a AST-007, AST-008 (`fries`), AST-009 (`whipped-cream`), AST-010, AST-011, AST-021, AST-029, AST-050 (frutas e verduras; pães do AST-001 no expositor de pão de hot dog, DEC-139), AST-061 |
| KayKit Restaurant Bits 1.0 (`Assets/KitchenPack`) | Kay Lousberg (www.kaylousberg.com) | CC0 1.0 | `Assets/KitchenPack/License.txt` | não (crédito voluntário, damos mesmo assim) | `asset-list.md`, origem `KP/`: AST-004 a AST-006, AST-009, AST-014, AST-015, AST-027, AST-029, AST-031, AST-040, AST-041, AST-044 (`pillar_A`, coluna; DEC-139), AST-049, AST-050 (caixotes; `crate_lettuce` aprovado em DEC-139) |
| Car Kit 3.1 (`Assets/CarKit`) — https://kenney.nl/assets/car-kit | Kenney (www.kenney.nl) | CC0 1.0 | `Assets/CarKit/License.txt` | não (crédito voluntário, damos mesmo assim) | **aprovado (DEC-139)**, origem `CK/`: AST-034 e AST-047 (`cone`), AST-035 (`sedan`, `hatchback-sports`, `van`, `truck`), AST-048 (`delivery`), AST-052 (`ambulance`), AST-065 (`sedan` esticado) |
| City Kit Roads 2.1 (`Assets/CityKitRoads`) — https://kenney.nl/assets/city-kit-roads | Kenney (www.kenney.nl) | CC0 1.0 | `Assets/CityKitRoads/License.txt` | não (crédito voluntário, damos mesmo assim) | **aprovado (DEC-139)**, origem `CR/`: AST-032 (`road-straight`, `road-crossroad`), AST-034 (`road-sign-street`), AST-036 (`light-curved`, `light-square`), AST-047 (`construction-fence`, `construction-light`) |
| City Kit Commercial 2.1 (`Assets/CityKitCommercial`) — https://kenney.nl/assets/city-kit-commercial | Kenney (www.kenney.nl) | CC0 1.0 | `Assets/CityKitCommercial/License.txt` | não (crédito voluntário, damos mesmo assim) | **aprovado (DEC-139)**, origem `CC/`: AST-026 (`detail-parasol-a`), AST-028 (`detail-awning-wide`), AST-033 (`building-a`, `building-h`), AST-044/045 (`building-j`), AST-046 (`building-e`); candidato: AST-034 (ponto de ônibus, só se AST-074 entrar) |
| City Kit Suburban 2.0 (`Assets/CityKitSuburban`) — https://kenney.nl/assets/city-kit-suburban | Kenney (www.kenney.nl) | CC0 1.0 | `Assets/CityKitSuburban/License.txt` | não (crédito voluntário, damos mesmo assim) | **aprovado (DEC-139)**, origem `CS/`: AST-034 (`planter`, `tree-large`); candidato: AST-032 (cerca baixa) |
| Mini Market 1.0 (`Assets/MiniMarket`) — https://kenney.nl/assets/mini-market | Kenney (www.kenney.nl); créditos adicionais no License.txt: Fleur Keijsers, Guus Vermeulen | CC0 1.0 | `Assets/MiniMarket/License.txt` | não (crédito voluntário, damos mesmo assim) | **aprovado**, origem `MM/`: AST-018 (`freezer`, base L1–L2; DEC-138), AST-028 (`wall`, `wall-window`, `wall-door-rotate`, `wall-corner`), AST-029 (`shelf-boxes`, `shelf-bags`, `shelf-end`), AST-030 (`freezers-standing`), AST-031 (`cash-register`), AST-050 (`display-fruit`, `display-bread`; também no expositor de pão de hot dog) (DEC-139) |
| "Trashcan" (modelo avulso) — https://poly.pizza/m/eoC8NFaafh | Kenney (www.kenney.nl), via Poly Pizza | CC0 1.0 (conforme a página do Poly Pizza) | página do modelo no Poly Pizza (sem arquivo de licença no repositório) | não (crédito voluntário, damos mesmo assim) | **aprovado (DEC-140)**: AST-025 lixeira de descarte — editado (tampa basculante, pedal novo, recolor Teal); `Assets/blender/equipment/AST-025_Trashcan.blend`, `Assets/models/equipment/AST-025_Trashcan.fbx` |

Licenças conferidas pelo art-director em 2026-10-08 (leitura dos `License.txt`); reconferidas na conciliação de 2026-10-08 — sem asset de terceiros novo.
2026-10-09: o usuário baixou os 5 packs Kenney acima (Car Kit, City Kit Roads/Commercial/Suburban, Mini Market) e conferiu o `License.txt`; o art-director releu os 5 arquivos (todos CC0 1.0, uso comercial livre, crédito opcional). Nada desses packs foi importado para o Studio ainda: a coluna "Usado em" lista só candidatos.
2026-10-10 (DEC-138, DEC-139): prévias no Studio e aprovação do usuário; a coluna "Usado em" passa a marcar **aprovado** onde houver DEC. Arquivo derivado novo no repositório: `Assets/blender/market/AST-050_BunDisplay.blend` e `Assets/models/market/AST-050_BunDisplay.fbx` (`MM/display-bread` + pão de `FP/hot-dog`; ambos CC0). Sem pack novo.
2026-10-10 (DEC-140): lote de modelados aprovado. Modelos próprios no estilo (cor pelo atlas KitchenPack ou City Kit Roads, CC0) não exigem linha nova. Único asset de terceiros novo: **"Trashcan" by Kenney** (Poly Pizza, CC0), usado no AST-025.
Sugestão de texto nos créditos do jogo: "Food Kit, Car Kit, City Kit and Mini Market by Kenney (kenney.nl) · Restaurant Bits by Kay Lousberg (kaylousberg.com)".

## Recursos da plataforma (não são asset de terceiros no repositório)

| Recurso | Origem | Nota |
|---|---|---|
| Rig e corpo R6, animações padrão de andar/idle | Roblox | usados por DEC-089/DEC-097; nada é copiado para `Assets/` |
| Fontes Fredoka One e Builder Sans | catálogo de fontes do Roblox | sugestão do style guide §7.1; uso dentro da plataforma |

Nenhum modelo do Sketchfab ou de outra biblioteca entrou até agora. **Poly Pizza:** só o "Trashcan" by Kenney (CC0, AST-025, DEC-140). Se entrar outro, a linha vai nesta tabela **antes** do arquivo ir para `Assets/`.
