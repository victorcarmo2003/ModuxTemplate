Status: Andamento

# Registro da rodada 2026-10-25: mãos e orelhas das skins

Legenda: **Commit** = no git e passou no gate · **Código** = no working tree, sem commit ou sem teste em jogo · **Andamento** · **Estúdio** = aplicado no Studio, precisa de Ctrl+S · **Falta** = depende do dono.
Separado do registro principal do dia (`playtest-2026-10-25.md`, na branch `feat/anomalies-v2-shop-2026-10-14`) para os dois entrarem no `main` sem conflito.

## Mãos e orelhas na cor do personagem (relato do dono: "o sapo tá com a mão do gato")

- Causa: o Roblox desenha `MeshPart.TextureID` ignorando o alpha. As folhas de roupa têm a pele (mãos, antebraço, canela) em alpha 0 com cinza-bege (206,196,182) guardado embaixo, e era isso que aparecia em toda espécie; o `MeshPart.Color` (pelo) nunca aparecia. À noite, o navy α68 aparecia sólido. Prova em `docs/tasks/captures/skin-hands/03_probe_TextureID_vs_SurfaceAppearanceOverlay.jpg`.
- Correção (código): as peças `OutfitPart` vestem a folha por `SurfaceAppearance` AlphaMode Overlay (template por id em `ReplicatedStorage.CrewOutfitSheets`, `Kit.ApplySheet`), e `Dress` pinta `MeshPart.Color` com a cor que a cabeça mostra no pack (Day = Fur; Mid/Night = `CrewLooks.PackFur`, gerado; skins com cabeça própria = `SkinLooks.HandFur`). Nenhuma folha de roupa foi reenviada.
- [ ] **Dono: salvar o place (Ctrl+S)**: a pasta `ReplicatedStorage.CrewOutfitSheets` (45 SurfaceAppearance) foi criada no Studio por `tools/assetplace/build_outfit_sheets.luau` e não está no git. Sem ela as mãos voltam ao cinza (aviso `[CrewRig] no ReplicatedStorage.CrewOutfitSheets...`). Rodar de novo após subir folha nova de roupa/skin.
- [ ] Dono: testar em Play (cliente real) mãos de jogador, cliente e pedestre nos três packs; a verificação foi em modo Edit com cópia do código (o rojo não estava sincronizando).
- Orelhas de skin com pelo próprio: o atlas Mid/Night de Ghost/Witch/Franken/Skeleton recoloria a célula de pelo a partir do atlas noturno e o Franken ficava com orelha preta sob cabeça verde. `gen_skin_textures.py` agora usa o sombreado do Day com a cor da cabeça da skin no pack. Reenviados (Studio `upload_image`), antigo → novo:
  - T_Skin_FrankenAtlas_Mid 75852604627872 → 109560919735848; _Night 84754145774998 → 76121764927295
  - T_Skin_GhostAtlas_Mid 131371122271677 → 88537369990599; _Night 84410288153109 → 132575915730622
  - T_Skin_SkeletonAtlas_Mid 79773283279821 → 104952927553009; _Night 95954020052660 → 121949315393916
  - T_Skin_WitchAtlas_Mid 100335129047369 → 139381989756151; _Night 83364511646446 → 78743611408850

| Valor | Onde | Antes | Depois | Precisa decidir? |
|---|---|---|---|---|
| Cor da mão por pack | `CrewLooks.PackFur` (gerado), `SkinLooks.HandFur` | cinza-bege da folha em toda espécie (Day/Mid), navy (Night) | Day = pelo da espécie/skin; Mid = pelo Mid da cabeça; Night = navy da cabeça (espécie) ou pelo noturno da skin | Não |
- NPCs (clientes, pedestres, motoristas do drive-thru, atores de cutscene, alucinações, Opal, extras do lobby, Walt sombrio): todos passam por `CrewRig.Build` + `Dress`, então já recebem o template e a cor da mão do pack. Os NPCs do servidor via `RigController`; os rigs locais chamam `Dress` direto. No place não há rig de NPC montado fora do `CrewRig`: só `ServerStorage.DevScenes` e `__Preview_Anomalias`, cenas de teste antigas que não vão para o jogo. Variante Blank (ANM-001/004): a mão usa o pelo Day, igual à cabeça Blank. Capturas `3x_` em `docs/tasks/captures/skin-hands/`.
- Pack Mid (N4–N6): muda a folha da roupa (~16% mais escura, com sujeira), a cabeça Mid, o atlas Mid (orelhas e cauda), o rosto `Exhausted` e a cor da mão (`PackFur.Mid`). Crew, civil_a..h e as 6 skins já têm folha Mid enviada; nada novo para subir (o raincoat continua pendente de aprovação).
