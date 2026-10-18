Status: Rascunho

# Pesquisa: pipeline de produção de thumbnail e ícone no Roblox (para automação)

Data: 2026-10-17 (researcher). Complementa `thumbnails-pesquisa-roblox.md` (regras oficiais, padrões de gênero) e
`thumbnails-pesquisa-externa.md` (psicologia, composição). Aqui o foco é **como os artistas produzem** e **o que dá
para automatizar por script**. Restrição do projeto (memória `thumbnail-style`): o dono aprovou luz real no Studio e
pós leve; **sem outline, glow neon, cel shading ou duotone**. As técnicas de outline/glow abaixo ficam documentadas
porque a skill pode precisar delas em variações A/B, mas não são o padrão da casa.

## Pergunta

Qual é o pipeline real dos artistas profissionais de thumb/ícone de Roblox (render, captura, composição, IA,
mercado) e quais etapas podem ser reproduzidas por script (bpy, Pillow/OpenCV)?

## Resposta curta

O pipeline dominante é: **posar no Studio → exportar OBJ → Blender (Cycles, 3 luzes + HDRI, fundo transparente,
PNG RGBA) → Photoshop/Photopea (recorte, rim/glow, grading, texto) → 1920×1080 e 512×512**. Não existe captura
nativa em alta resolução no Studio; o truque padrão é o **Device Emulator em resolução custom (4K) + View > Screen
Shot**, que é o caminho mais compatível com o estilo "foto no mapa com luz real" que o projeto adotou. Quase toda
a etapa de composição é reproduzível em Python; a etapa de render em Blender é 100% automatizável por bpy, mas a
**pose** continua manual (ou feita no Studio antes de exportar). IA generativa é permitida pela Roblox desde que
passe nas Community Standards; na prática é usada para fundos, e a comunidade a vê com desconfiança em thumbs
"estilo Roblox". Preços no Talent Hub variam de **~500 a 4.000 Robux** no histórico de portfólios até ofertas de
**25.000–30.000 Robux por thumb orientada a CTR** em 2026.

---

## 1. Render dos personagens (Studio → Blender)

### 1.1 Exportar o personagem

| Caminho | Como | Prós | Contras | Fonte |
|---|---|---|---|---|
| **Export Selection (OBJ)** | No Studio, selecionar o Model do personagem (em Play, o avatar aparece em Workspace) → botão direito → *Export Selection* → `.obj` + `.mtl` + texturas PNG | Simples, leva roupas e cores; qualquer rig | Malha única, **não posável no Blender**; posar antes, no Studio | [DevForum: Rigging your Roblox character in Blender for GFX](https://devforum.roblox.com/t/rigging-your-roblox-character-in-blender-for-gfx/1002697), [DevForum: Roblox Rig Help](https://devforum.roblox.com/t/roblox-rig-help/841060) |
| **Blender Rig Exporter / Animation Importer (Den_S)** | Plugin Studio exporta rig como `.obj` + metadados; addon Blender recria armature (Motor6D → bones) | Posável no Blender, ferramenta "Create IK constraints" | Não suporta skinned mesh; roupas têm que ser ligadas à mão; addon alvo Blender 2.8x–2.93+, última versão sem data; thread "[Fix] Blender Animations" alerta que versão quebrada já circulou | [Thread original (2017)](https://devforum.roblox.com/t/blender-rig-exporter-animation-importer/34729), [addon 2.80+](https://pastebin.com/raw/V5aBemWL), [Fix thread](https://devforum.roblox.com/t/fix-blender-animations/1690677) |
| **Roblox Blender Plugin (oficial)** | Addon open-source (MIT) via Open Cloud | Oficial, Blender 3.2+ | **Só Blender → Studio** (upload de mesh como package). Não exporta do Studio. Não serve para GFX | [GitHub Roblox/roblox-blender-plugin](https://github.com/Roblox/roblox-blender-plugin), [doc oficial](https://create.roblox.com/docs/en-us/art/modeling/roblox-blender-plugin) |
| **Moon Animator 2** | Pose/animação no Studio; "Export Rig" leva rig entre projetos | Posar rápido no Studio | Pago (~US$ 14,99 no BuiltByBit); exporta para Roblox, **não para Blender** | [BuiltByBit](https://builtbybit.com/resources/moonanimator-2.109718/), [Nilo](https://nilo.io/articles/export-moon-animator-animation-roblox) |
| **Pipeline Motor6D ↔ Bone (2026)** | Tutorial recente com IK/FK switching, compatível com bones | Mais moderno | Autor avisa que parte ficou obsoleta enquanto escrevia | [DevForum (2026)](https://devforum.roblox.com/t/full-roblox-%E2%86%94-blender-rig-animation-pipeline-motor6d-bone-compatible-ikfk-ikfk-switching/4042154) |
| **Rig IK R15 pronto (GitHub)** | `.blend` com controles IK (icosfera/cubo) para R15, usa addon RbxAnimations | Pose por IK no Blender | Depende do addon Den_S | [TK-DZ/Roblox-IK-R15](https://github.com/TK-DZ/Roblox-IK-R15) |

Importação no Blender (doc oficial): `File > Import > OBJ/FBX/glTF`, **Up Axis = Y**, scale 1, forward Z
([create.roblox.com/docs/art/blender](https://create.roblox.com/docs/en-us/art/blender)). Em OBJ a textura chega
via `.mtl`; às vezes é preciso religar a PNG no Principled BSDF. Studs ≠ metros: 1 stud ≈ 0,28 m (convenção; não
confirmado em doc oficial, só em tutoriais).

**Para os personagens do Sell Hotdogs** (animais em rig R6, `roblox-cartoon-animal-char`), a fonte `.blend` já existe
em `Assets/blender/`: **não precisa exportar do Studio**; basta posar a armature no Blender (ou importar uma pose
R6 do Studio via Den_S) e renderizar.

### 1.2 Pose

- Prática comum: posar **no Studio** (Animation Editor, Moon Animator ou arrastar Motor6D) e só então exportar OBJ.
- No Blender: IK gerado pelo addon Den_S ("Create IK constraints", precisa ajustar parâmetros) ou rig IK pronto.
- Poses típicas de thumb (observação de portfólios, não confirmado por fonte escrita): herói em ¾, inclinado para a
  câmera, braços abertos ou segurando o item do jogo; cabeça ligeiramente maior que a proporção (escala do bone
  Head ×1,1–1,2) para reforçar o baby schema.

### 1.3 Iluminação de estúdio

Padrão repetido em todos os guias: **3-point** (key ~45° acima e à frente, fill fraco oposto, **rim/backlight
colorido** atrás para recortar do fundo) + **HDRI** no World com Strength 0,3–1 para reflexos. Fontes:
[Meshy 8-step](https://www.meshy.ai/tutorials/roblox-gfx-thumbnails), [Renderbux](https://www.renderbux.com/guides/how-to-make-a-roblox-thumbnail),
[Vizzbees](https://vizzbees.com/blog/how-to-make-a-roblox-thumbnail) (todos são blogs de fornecedores: use só a
técnica, não a ferramenta). Rim light costuma ser da cor do fundo da thumb (azul/roxo para noite).

### 1.4 Engine, resolução, fundo transparente

- **Cycles** é a escolha dos artistas para a imagem final (sombras suaves, SSS, HDRI correto); **EEVEE** para
  preview. Com denoise (OpenImageDenoise), 128–256 samples bastam para personagem cartoon.
- Renderizar em **2× o tamanho final** (3840×2160 para thumb, 2048 para ícone) e reduzir depois: dá antialias e
  margem para recorte.
- **Fundo transparente:** `Render Properties > Film > Transparent` + `Output > PNG, Color RGBA, 16-bit`. Funciona em
  Cycles e EEVEE. Bug histórico: em EEVEE, Bloom sobre fundo transparente não era salvo no PNG
  ([T88884](https://developer.blender.org/T88884)) e houve relato de PNG todo branco no 3.0
  ([#95066](https://projects.blender.org/blender/blender/issues/95066)); no 4.x o Bloom do EEVEE virou efeito de
  compositor, então **glow é melhor feito na composição**, não no render.
- Opção `cycles.film_transparent_glass` deixa vidro ver o alpha.

### 1.5 Script bpy (prova de conceito)

```python
import bpy, math
scn = bpy.context.scene
try:
    scn.render.engine = "CYCLES"
except TypeError as e:
    print(e)  # lista engines válidas
scn.cycles.samples = 192
scn.cycles.use_denoising = True
scn.render.film_transparent = True
scn.render.resolution_x, scn.render.resolution_y = 3840, 2160
scn.render.image_settings.file_format = "PNG"
scn.render.image_settings.color_mode = "RGBA"
scn.render.image_settings.color_depth = "16"
scn.view_settings.view_transform = "Filmic"  # ou "AgX" no 4.x; ler enum antes

def light(name, kind, loc, energy, color=(1, 1, 1), size=2.0):
    data = bpy.data.lights.new(name, kind)
    data.energy, data.color = energy, color
    if kind == "AREA":
        data.size = size
    ob = bpy.data.objects.new(name, data)
    scn.collection.objects.link(ob)
    ob.location = loc
    return ob

target = bpy.data.objects["Armature"]  # ou o Model do personagem
key = light("Key", "AREA", (3, -3, 4), 800, (1.0, 0.95, 0.9), 3)
fill = light("Fill", "AREA", (-4, -2, 2), 200, (0.9, 0.95, 1.0), 4)
rim = light("Rim", "SPOT", (0, 4, 3), 1200, (0.4, 0.5, 1.0))
for ob in (key, fill, rim):
    c = ob.constraints.new("TRACK_TO"); c.target = target
    c.track_axis, c.up_axis = "TRACK_NEGATIVE_Z", "UP_Y"

# HDRI (World) — apontar para um .hdr do Poly Haven (CC0)
world = scn.world or bpy.data.worlds.new("World"); scn.world = world
world.use_nodes = True
nt = world.node_tree
env = nt.nodes.new("ShaderNodeTexEnvironment")
env.image = bpy.data.images.load(r"D:\path\studio_small_08_2k.hdr")
bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
nt.links.new(env.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 0.5

scn.render.filepath = r"D:\out\hero_pose01.png"
bpy.ops.render.render(write_still=True)
```

Observações: nomes de nós são localizados, buscar por `type`; `view_transform` deve ser lido do enum antes de
atribuir (Blender 4.x usa "AgX"). A pose não entra no script: aplicar via Action/pose library antes.

---

## 2. Captura direto no Studio (sem Blender)

É o caminho que o projeto já usa (`thumbnail-style`). O que a comunidade confirma:

- **Não há screenshot nativo acima da resolução da janela.** Pedido aberto em 2026:
  [Add a dedicated high-quality screenshot tool](https://devforum.roblox.com/t/add-a-dedicated-high-quality-screenshot-tool/4806575).
- **Truque padrão (Device Emulator):** ícone de celular no viewport → *Manage Devices* → adicionar entrada
  **3840×2160** (ou maior) → selecionar → *Scaling: Actual Resolution* → `View > Screen Shot` → arquivo em
  `Pictures\Roblox`. Pesado em máquina fraca. Alternativa: destacar o viewport em janela própria e maximizar.
  Fonte: [Taking high quality screenshots (2019, ainda válido em essência)](https://devforum.roblox.com/t/taking-high-quality-screenshots/330052).
  Nomes de menu podem ter mudado no Studio novo; **não confirmado** no Studio 2026.
- **Esconder UI:** botão *Viewport Options* (canto superior direito) → desligar *GUI Overlay*; ou ferramenta "Show UI"
  numa tab custom ([DevForum](https://devforum.roblox.com/t/how-to-hide-all-screenguis-for-the-studio-client-with-the-new-studio-ui/4115514)).
  O atalho `Ctrl+Shift+H` circula em blogs mas **não foi confirmado** em fonte oficial.
- **Qualidade:** `File > Studio Settings > Rendering > Editor Quality Level = 21`. Efeitos de pós-processamento só
  aparecem no nível máximo ([doc post-processing](https://create.roblox.com/docs/en-us/environment/post-processing-effects)).
- **FOV 50–60** para look menos "grande-angular" (recomendação da thread; para close de personagem alguns usam 30–40).
- **CaptureService / ViewportFrame por script:** `ViewportFrame:CaptureSnapshotAsync()` e
  `CaptureService:CaptureScreenshot()` devolvem `ContentId` temporário que **não pode virar `EditableImage`** em
  plugin ("cannot currently create editable image from temporary texture id"). Não serve para automação de
  thumbnail hoje. Fontes: [Get Pixel Color from Viewport](https://devforum.roblox.com/t/get-pixel-color-from-viewport/3383294),
  [feature request](https://devforum.roblox.com/t/plugin-access-to-screenshot-button-functionalityviewport-image-for-ai-integrationautomation/4223805).
  Plugin "Photobooth" captura em edit mode para textura de MeshPart, não para arquivo
  ([DevForum](https://devforum.roblox.com/t/photobooth-plugin/3401720)).
- **Chroma no Studio:** cercar a cena com Parts `Neon` verde puro (`Color3.fromRGB(0,255,0)`, `Material = Neon`,
  `Lighting.Brightness` baixo para não vazar) e desligar `Lighting.GlobalShadows` nessas Parts via `CastShadow=false`.
  Prática da comunidade (não documentada oficialmente). `Highlight` com `FillTransparency=1` e `OutlineColor` dá
  contorno, mas o dono rejeitou outline; usar só como **máscara** (render 2 vezes: normal e com Highlight preenchido
  em cor sólida `FillTransparency=0`, e usar o segundo como matte). O `Highlight` tem limite de 31 instâncias
  simultâneas (doc oficial da classe).
- **Luz para look cinematográfico** (doc oficial [Lighting](https://create.roblox.com/docs/en-us/environment/lighting)):
  - `LightingStyle = Realistic` (é o que a doc chama agora; `Technology = Future` continua existindo na API e é o que
    faz luzes locais projetarem sombra; o tutorial [Future lighting](https://create.roblox.com/docs/tutorials/3D-art/enhancing-outdoor-environments-with-future-lighting) ainda manda trocar manualmente).
  - `ShadowSoftness` 0–1 (só em Realistic). `EnvironmentDiffuseScale` e `EnvironmentSpecularScale` 0→1 para
    ambiente e reflexo do skybox (padrão 0). `ExposureCompensation` −1…+1,25.
  - Pós: `BloomEffect` (Intensity baixo, Threshold alto para só olhos/letreiro brilharem), `DepthOfFieldEffect`
    (FocusDistance na cabeça do herói, InFocusRadius pequeno, FarIntensity 0,3–0,6), `ColorCorrectionEffect`
    (Contrast +0,1…0,2, Saturation +0,1, TintColor levemente quente), `ColorGradingEffect.TonemapperPreset`
    (Default = look vívido pós-2019). A doc não dá valores padrão numéricos; os acima são prática.
  - Armadilhas já registradas na memória do projeto: luzes só aparecem após mover a câmera; SpotLight pequeno em
    interior às vezes não renderiza (usar PointLight); viewport às vezes renderiza vazio.

---

## 3. Composição (o que o artista faz depois do render)

Ferramentas: **Photoshop** (maioria), **Photopea** (grátis, mesmo fluxo de camadas, no browser), GIMP, Affinity,
Figma/Canva (texto e layout). Fontes gerais: [Vizzbees](https://vizzbees.com/blog/how-to-make-a-roblox-thumbnail),
[Renderbux backgrounds](https://www.renderbux.com/guides/roblox-gfx-backgrounds), [DevForum "glow up my GFX"](https://devforum.roblox.com/t/help-me-glow-up-my-gfx-advanced/3579495).

Ordem de camadas típica (de baixo para cima):

1. **Fundo** (render de cenário, foto tratada, ou gerado) com blur leve (gaussian 2–6 px a 1080p) e grading frio.
2. **Luz volumétrica/gradiente radial** atrás do herói (Screen/Linear Dodge, 20–40%).
3. **Sombra de contato** do herói no chão (elipse preta, blur, Multiply 40–60%).
4. **Herói** (PNG RGBA). "Pop" vem de: rim light pintada à mão (brush soft, flow 5–10%, cor da luz do fundo),
   **Levels/Curves** só no herói (+contraste), **saturação** +10–15% no herói e −10% no fundo, e um
   **outline** fino (Stroke 4–12 px, branco ou cor clara) ou **glow** (Outer Glow, Screen) — ambos vetados aqui.
5. **Ameaça/monstro** atrás com olhos brilhantes (Emission no render ou Color Dodge na pós).
6. **Partículas/props** (faíscas, vapor, migalhas) em Screen.
7. **Grading global**: Color Balance (quente nas luzes, frio nas sombras), Gradient Map em Soft Light 10–20%,
   **vinheta** suave.
8. **Selective sharpening**: Unsharp Mask só no herói (mascarado), nunca no fundo desfocado.
9. **Texto** (se houver): fonte bold arredondada, Stroke grosso, drop shadow deslocada, leve bevel; só na thumb 16:9,
   nunca na faixa inferior (contagem de jogadores).
10. **Export**: 1920×1080 PNG/JPG < 3 MB; ícone 512×512 a partir de um crop quadrado renderizado à parte (não
    recortar da thumb).

Checagem universal: reduzir para **~250 px de largura e em cinza** e ver se herói, ameaça e assunto continuam
legíveis (o ícone chega a 150×150 na doc oficial).

---

## 4. Arte gerada por IA

- **Política oficial:** "todo conteúdo, inclusive o criado por ou com IA generativa, deve seguir as Community
  Standards". Para ferramentas de terceiros o criador é responsável pelo resultado; a imagem passa pela mesma
  moderação de qualquer thumbnail. Não há regra específica contra IA em thumbnails nem menção a Stable Diffusion /
  Midjourney. Orientação de IP (Texture Generator): não usar marcas, logos nem IP de terceiros no prompt.
  Fontes: [Generative AI (doc)](https://create.roblox.com/docs/generative-AI), [Texture Generator (doc)](https://create.roblox.com/docs/en-us/studio/texture-generator), [anúncio beta](https://devforum.roblox.com/t/texture-generator-beta/2880635).
- **Uso real:** comum para **fundos e props** (cenário de rua, céu, textura de parede) com SD/Midjourney, e ControlNet
  (depth/canny) para manter o layout de um blockout. Personagens 100% por IA são raros em jogos grandes: a
  comunidade prefere o rig Roblox reconhecível (ver `thumbnails-pesquisa-roblox.md` §2) e há threads pedindo
  feedback de thumbs com IA com recepção fria ([AI Generated Thumbnails](https://devforum.roblox.com/t/ai-generated-thumbnails/2667653),
  [Question about this AI Image](https://devforum.roblox.com/t/question-about-this-ai-image/2338351)).
  Frequência exata **não confirmada** (não há levantamento).
- **Moderação automática:** relatos em 2026 de falsos positivos e strikes em imagens (inclusive um anúncio gerado
  pela própria IA do Ads Manager) — [AI Moderation false flagging](https://devforum.roblox.com/t/ai-moderation-false-flagging-and-suspending-experience/3830981),
  [Ads Manager AI gerado deletado](https://devforum.roblox.com/t/roblox-ai-moderation-incorrectly-moderating-and-denying-appeals/4827366).
  Anedóticos. Implicação: subir thumbnails novas com antecedência do update e ter backup aprovado.
- **Ferramentas nativas Roblox:** *Texture Generator* (beta; 1024×1024 em MeshPart, 25 previews/dia, aceita imagem de
  estilo). *Assistant* (código/insert). *GenerationService* / Cube (geração de mesh 3D a partir de texto, em beta
  e via API). Um "Mesh Generator" como tela do Studio **não foi confirmado** em doc oficial. Nenhuma delas gera
  imagem 2D para thumbnail; o Ads Manager gera 3 variações de criativo por IA, só para anúncio.
- **Para o projeto:** fundo por IA só se o estilo casar com o render do mapa; é mais seguro usar o próprio mapa
  (cumpre "mostrar o que existe no jogo", que pesa na recomendação).

---

## 5. Mercado (Talent Hub / DevForum / X)

Sem tabela oficial. Dados coletados (Robux; 1.000 Robux ≈ US$ 3,50 no DevEx 2026, não verificado aqui):

| Faixa | Evidência |
|---|---|
| 500–1.000 R$ por thumb | Portfólios 2020–2022 ([GFX Artist For Hire](https://devforum.roblox.com/t/open-gfx-artist-for-hire/340628), [Lukacors](https://devforum.roblox.com/t/lukacors-gfx-portfolio/294612)) |
| 700–1.000 básico / 1.600–2.200 padrão / 3.000–4.200 premium | Tabela de artista ([ShelIIl](https://devforum.roblox.com/t/open-sheliil-gfx-artist-portfolio-for-hire/1164058)) |
| 3.500 R$, prazo "uma semana ou mais" | [Nes](https://devforum.roblox.com/t/open-nes-gfxlogo-artist/1365563) |
| 599 R$ (2 personagens + HDRI) / 999 R$ (cenário completo) | [GFX for hire](https://devforum.roblox.com/t/open-gfx-artist-for-hire/1373389) |
| ~5.000 R$ (dev solo, negociável) | [Hiring Thumbnail/Icon Creator](https://devforum.roblox.com/t/closed-paid-hiring-thumbnailicon-creator/4540550) |
| **25.000–30.000 R$ por thumb**, 50% adiantado, brief orientado a **CTR** | Ofertas 2026 ([25k](https://devforum.roblox.com/t/r-25000-looking-for-thumbnail-artist/4741351), [30k](https://devforum.roblox.com/t/30000-r-looking-for-thumbnail-artist/4757580)) |
| US$ 15 (thumb estilo YouTube) a US$ 35 (meio corpo) | Etsy, anedótico |

- Pedidos de cliente mais frequentes nas ofertas: "estilo do jogo X" (Pet Sim 99, Grow a Garden, Doors), "render
  cartoon", "thumb que aumente CTR", "ícone + thumb", "variações para A/B". Pacote "ícone + thumb + 2–3 variações"
  aparece em portfólios mas **sem preço de bundle publicado** encontrado.
- Prazo: 2–7 dias nos portfólios; os de 25–30k não especificam.
- Reclamação recorrente: Talent Hub cheio de ofertas baratas/não pagas ([thread](https://devforum.roblox.com/t/its-way-too-hard-finding-quality-projects-on-the-talent-hub/1747965?page=2)).
- Oficial sobre A/B: Thumbnail Personalization (2–5 ativas) é o único teste nativo; **ícone não tem A/B**
  ([thumbnails doc](https://create.roblox.com/docs/en-us/production/publishing/thumbnails)).

---

## 6. Automação em Python (Pillow, OpenCV, NumPy, SciPy)

Tudo abaixo é reproduzível sem GPU. `tools/thumbnails/compose.py` já tem `key()` (chroma com despill), `dilate()`,
`radial()`, `cover_crop()`; o que falta está marcado **(novo)**.

| Etapa | Técnica | Nota |
|---|---|---|
| Chroma key + despill | Converter para float; `mask = clamp((G - max(R,B) - lo) / (hi - lo))`; despill: `G = min(G, (R+B)/2 + spill)` nos pixels de borda; alpha suavizado com `cv2.GaussianBlur` 1–2 px | Já em `compose.key()`. Referência de conceito: [Cavalry despill](https://cavalry.studio/docs/nodes/effects/filters/chroma-key-filter/), [OpenCV Q&A](https://answers.opencv.org/question/1246/chroma-key) |
| Matte por Highlight | Render A (normal) e B (Highlight Fill sólido magenta) na mesma câmera; `alpha = key(B)`; aplica em A | **(novo)**; evita franja verde |
| Outline uniforme | `d = scipy.ndimage.distance_transform_edt(alpha < 0.5)`; `outline = clip(1 - (d - w)/feather, 0, 1)` | Uniforme em curvas (dilate morfológico fica quadrado). [docs scipy](https://docs.scipy.org/doc/scipy/reference/generated/scipy.ndimage.distance_transform_edt.html) **(novo)**; vetado no estilo atual, útil em A/B |
| Glow | Dilatar alpha 1–2×, `GaussianBlur` sigma 15–40, multiplicar pela cor, compor em **screen**: `1 - (1-a)(1-b)` | **(novo)**; só para olhos/letreiro no estilo atual |
| Drop shadow / sombra de contato | Alpha deslocado (dx, dy) + blur, preto × 0,5, compor **multiply**; contato: elipse achatada sob os pés | Em `compose.py` parcial |
| Texto com stroke e sombra | `ImageDraw.text(xy, txt, font=ImageFont.truetype(ttf, px), fill, stroke_width=px//10, stroke_fill)`; sombra = mesmo texto em preto em camada separada com blur e offset; `anchor="mm"` para centrar | Pillow ≥ 6.2 ([release notes](https://hugovk-pillow.readthedocs.io/en/stable/releasenotes/6.2.0.html), [ImageDraw](https://pillow.readthedocs.io/en/latest/reference/ImageDraw.html)) **(novo)** |
| Vinheta | `radial()` invertida × 0,25–0,4 em multiply, centro no herói | Já existe |
| Unsharp mask seletivo | `ImageFilter.UnsharpMask(radius=2, percent=120, threshold=3)` só dentro de `alpha` do herói | **(novo)** |
| Grading LUT | `.cube` 3D-LUT: parse em NumPy e `scipy.ndimage.map_coordinates` trilinear; ou curva simples por canal (`np.interp`) + split toning (quente em highlights, frio em sombras pela luminância) | **(novo)** |
| Legibilidade | `img.resize((250, 141))` → `convert("L")` → salvar lado a lado; métrica simples: desvio-padrão da luminância do herói vs fundo (contraste ≥ 0,3 em escala 0–1) | Memória do projeto já exige |
| Variações A/B em lote | Spec JSON com listas (poses, offsets, cor do rim, com/sem texto) → `itertools.product` → nomes `thumb_<pose>_<rim>_<txt>.png` + `contact_sheet.png` | `compose.py` já lê JSON; falta o produto cartesiano **(novo)** |
| Ícone | Render/crop quadrado próprio, 1024 → 512 com `Image.LANCZOS`; prévia 150×150 automática | **(novo)** |

Snippet dos três novos de maior valor:

```python
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy.ndimage import distance_transform_edt, gaussian_filter

def outline(alpha, width, feather=1.5):            # alpha float 0..1
    d = distance_transform_edt(alpha < 0.5)        # distância até o herói
    return np.clip(1 - (d - width) / feather, 0, 1) * (alpha < 0.5)

def glow(alpha, color, sigma=25, gain=1.0):
    g = gaussian_filter(alpha, sigma) * gain
    return np.dstack([g * c for c in color]), g   # rgb premult, alpha

def text_layer(size, txt, ttf, px, fill, stroke, shadow=(6, 8)):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    font = ImageFont.truetype(ttf, px)
    cx, cy = size[0] // 2, int(size[1] * 0.18)   # fora da faixa inferior
    sh = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((cx + shadow[0], cy + shadow[1]), txt, font=font,
                            fill=(0, 0, 0, 180), anchor="mm", stroke_width=px // 10,
                            stroke_fill=(0, 0, 0, 180))
    sh = sh.filter(ImageFilter.GaussianBlur(4))
    ImageDraw.Draw(layer).text((cx, cy), txt, font=font, fill=fill, anchor="mm",
                               stroke_width=px // 10, stroke_fill=stroke)
    return Image.alpha_composite(sh, layer)
```

---

## Implicações para o Sell Hotdogs

- O estilo aprovado ("foto no mapa com luz real") **cabe inteiro no caminho §2** (Studio + Device Emulator 4K +
  Python). Blender só compensa para o **ícone** (close do herói, fundo controlado) ou para poses que o rig R6 no
  Studio não dá.
- Automação de alto retorno: lote de variações A/B por JSON, legibilidade automática (250 px + cinza), ícone com
  prévia 150 px, matte por Highlight (sem franja).
- Risco de moderação: subir com antecedência; evitar IA para personagem; nada na faixa inferior.
- Não dá para automatizar o clique em `View > Screen Shot` por API do Studio (CaptureService não entrega pixels a
  plugin). A captura continua um passo humano ou via automação de desktop (desktop-commander/hotkey), que **não foi
  testada**.

## Recomendação

Montar a skill em dois trilhos: **Trilho A (padrão)** Studio → captura 4K → `compose.py` ampliado (matte por
Highlight, grading, vinheta, legibilidade, lote A/B). **Trilho B (ícone/pose especial)** `.blend` do personagem →
script bpy §1.5 (Cycles, 3 luzes + HDRI CC0, PNG RGBA 2048) → mesmo `compose.py`. Deixar outline/glow como flags
desligadas por padrão. Validar no Studio 2026 os nomes de menu do Device Emulator antes de escrever a skill.

---

## Passo a passo mínimo (reproduzível por scripts)

1. **Cena no Studio:** pasta `ThumbScene` em Workspace com herói posado (Animation Editor), monstro, PointLight quente
   no herói, SpotLight/PointLight frio na parede atrás; `Lighting.LightingStyle=Realistic`, `ShadowSoftness=0.2`,
   `EnvironmentDiffuseScale=1`, `EnvironmentSpecularScale=1`; `DepthOfField` focado na cabeça; Editor Quality 21.
2. **Câmera:** `Scriptable`, FOV 40–55, re-aplicar `CFrame` com offset de 0,01 stud (gatilho das luzes).
3. **Captura:** Device Emulator 3840×2160, Actual Resolution, UI off → `View > Screen Shot` (render A). Trocar
   `Highlight` do herói para Fill sólido magenta, `DepthOfField` off → Screen Shot (render B, matte). Salvar ambos.
4. **Ícone (opcional, Blender):** abrir `Assets/blender/.../AST-###.blend`, aplicar pose, rodar script §1.5 →
   `hero_pose01.png` RGBA 2048.
5. **Compor:** `python tools/thumbnails/compose.py spec.json` com: fundo = render A desfocado 3 px e −10% saturação,
   herói = A mascarado por `key(B)`, sombra de contato, vinheta 0,3, grading quente/frio, unsharp só no herói,
   texto opcional (fora dos 15% de baixo). Exportar 1920×1080 (< 3 MB) e 512×512.
6. **Checar:** gerar `*_250gray.png` e `icon_150.png`; reprovar se herói e ameaça não se distinguem.
7. **Lote A/B:** spec com listas (rim azul/roxo, com/sem texto, herói olhando câmera/monstro) → produto cartesiano →
   `contact_sheet.png`; subir 2–5 na Thumbnail Personalization.
8. **Limpar:** remover `ThumbScene`, restaurar `Lighting` e câmera (memória `thumbnail-style`).

## Fontes principais

- Roblox docs: [Thumbnails](https://create.roblox.com/docs/en-us/production/publishing/thumbnails), [Experience icons](https://create.roblox.com/docs/production/publishing/experience-icons), [Lighting](https://create.roblox.com/docs/en-us/environment/lighting), [Post-processing](https://create.roblox.com/docs/en-us/environment/post-processing-effects), [Future lighting tutorial](https://create.roblox.com/docs/tutorials/3D-art/enhancing-outdoor-environments-with-future-lighting), [Blender ↔ Studio](https://create.roblox.com/docs/en-us/art/blender), [Export requirements](https://create.roblox.com/docs/art/modeling/export-requirements), [Generative AI](https://create.roblox.com/docs/generative-AI), [Texture Generator](https://create.roblox.com/docs/en-us/studio/texture-generator), [Roblox Blender plugin](https://create.roblox.com/docs/en-us/art/modeling/roblox-blender-plugin).
- DevForum: [Taking high quality screenshots](https://devforum.roblox.com/t/taking-high-quality-screenshots/330052), [Blender rig exporter (Den_S)](https://devforum.roblox.com/t/blender-rig-exporter-animation-importer/34729), [Rigging your character for GFX](https://devforum.roblox.com/t/rigging-your-roblox-character-in-blender-for-gfx/1002697), [Pipeline Motor6D↔Bone 2026](https://devforum.roblox.com/t/full-roblox-%E2%86%94-blender-rig-animation-pipeline-motor6d-bone-compatible-ikfk-ikfk-switching/4042154), [HQ screenshot feature request](https://devforum.roblox.com/t/add-a-dedicated-high-quality-screenshot-tool/4806575), [Hide UI no Studio novo](https://devforum.roblox.com/t/how-to-hide-all-screenguis-for-the-studio-client-with-the-new-studio-ui/4115514), [Viewport pixels](https://devforum.roblox.com/t/get-pixel-color-from-viewport/3383294), [AI thumbnails](https://devforum.roblox.com/t/ai-generated-thumbnails/2667653), ofertas [25k](https://devforum.roblox.com/t/r-25000-looking-for-thumbnail-artist/4741351) / [30k](https://devforum.roblox.com/t/30000-r-looking-for-thumbnail-artist/4757580), portfólios [ShelIIl](https://devforum.roblox.com/t/open-sheliil-gfx-artist-portfolio-for-hire/1164058), [Nes](https://devforum.roblox.com/t/open-nes-gfxlogo-artist/1365563).
- Outros: [GitHub roblox-blender-plugin](https://github.com/Roblox/roblox-blender-plugin), [TK-DZ/Roblox-IK-R15](https://github.com/TK-DZ/Roblox-IK-R15), [Blender T88884 (EEVEE bloom + alpha)](https://developer.blender.org/T88884), [scipy distance_transform_edt](https://docs.scipy.org/doc/scipy/reference/generated/scipy.ndimage.distance_transform_edt.html), [Pillow 6.2 stroke](https://hugovk-pillow.readthedocs.io/en/stable/releasenotes/6.2.0.html), [Meshy 8-step (vendor)](https://www.meshy.ai/tutorials/roblox-gfx-thumbnails), [Vizzbees (vendor)](https://vizzbees.com/blog/how-to-make-a-roblox-thumbnail).
