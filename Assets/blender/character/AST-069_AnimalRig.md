Status: Em revisão

# AST-069 — Rig de animação dos bichos (AnimalRig)

`AST-069_AnimalRig.blend` é uma cópia do rig R6 IK/FK da comunidade **CommunityR6** (autor: Aeresei / "Fancy Ducc").
Os controles, scripts de UI, IK/FK, poles, LookTo e grab points continuam os dele; as malhas genéricas do Roblox
saíram e entraram as nossas: corpo crew (AST-053) + cabeça, rosto, orelhas, rabo e extras das 18 espécies.
É **ferramenta de animação**: nada deste arquivo vai para o jogo, só as animações que saem dele.

## Abrir

1. Blender 4.5 ou mais novo (montado e testado no 5.2).
2. Ao abrir, aceite **Allow Execution** (auto-run de scripts). Se recusou: aba *Scripting* > Text Editor >
   `RigBootstrap.py` > **Run Script**.
3. Viewport > `N` > aba **R6 Rig**: painéis *Active Rig*, *Rig Settings* e *Utilities*.

Pose mode no `__PrimaryArmature` (controles coloridos). O `InternalArmature` fica oculto: são os **7 ossos com os
nomes das partes R6** (`HumanoidRootPart`, `Torso`, `Head`, `Left Arm`, `Right Arm`, `Left Leg`, `Right Leg`), que
seguem os controles e viram a animação do Roblox. Não anime nele.

## Controles

| Controle | O que faz |
|---|---|
| `MasterControl` (círculo no chão) | move/gira o personagem inteiro |
| `LowerTorso-FK` | quadril/raiz: subir, descer, girar o corpo (pés em IK ficam no chão) |
| `UpperTorso-IKTarget` | inclina o tronco (IK do tronco, pole `Torso-Pole`) |
| `Head` | gira a cabeça; com **Track Object** = 1 ela olha para o `LookToPoint` |
| `RightArm-IK` / `LeftArm-IK` | mão em IK (com IK/FK = 1) |
| `RightArm_GrabPoint` / `LeftArm_GrabPoint` | ponto de pegada: com **Grab** = 1 a mão em IK vai até ele (anime o ponto junto do objeto segurado) |
| `RightArm_FK` / `LeftArm_FK`, `RightLeg_FK` / `LeftLeg_FK` | rotação direta do membro (com IK/FK = 0) |
| `RightLeg-IK` / `LeftLeg-IK` | pé em IK |

## Rig Settings (painel R6 Rig)

| Objeto | Propriedade | Uso |
|---|---|---|
| Body | **Species** | 0 Dog, 1 Cat, 2 Rabbit, 3 Fox, 4 Bear, 5 Panda, 6 Turtle, 7 Owl, 8 Lion, 9 Penguin, 10 Hamster, 11 Mouse, 12 Frog, 13 Monkey, 14 Sheep, 15 Koala, 16 Pig, 17 Raccoon (troca cabeça, acessórios, boné certo e cor das mãos) |
| Body | Cap / Apron | liga/desliga boné e avental |
| Head | Track Object, Ignore Rotation | olhar para o `LookToPoint`; cabeça não herda a rotação do tronco |
| Left/Right Arm | **IK/FK** (1 = IK, 0 = FK), Grab, Torso Influence | troca IK/FK; mão segue o grab point; braço segue ou não o tronco |
| Left/Right Arm e Leg | **Pin Joint** (novo) | 1 (padrão): em IK o membro rígido gira no pivô R6 e mira o controle, sem abrir fresta na junta. 0: comportamento original do CommunityR6 (o bloco acompanha o antebraço/canela e se desloca da junta) |
| Left/Right Leg, Torso | IK/FK, Torso Influence | idem para pernas e tronco |

**Troca IK/FK:** o valor é animável (keyframe no slider). Não há "snap" automático: antes de trocar, deixe o controle
do outro modo na mesma pose, senão o membro salta.

## Animar

- Cada animação = uma **Action** no `__PrimaryArmature` (Dope Sheet > Action Editor > New). O arquivo traz a
  `ArmatureAction` do original com a pose de repouso no frame 0; não a use para animação de verdade.
- Cena a **60 fps**, frames 0–60 (ajuste o fim por animação).
- A espécie não muda a animação: as juntas são as mesmas em todos os bichos.

## Exportar para o Roblox

O CommunityR6 é feito para o add-on **Roblox Animations Importer/Exporter (rbxanims)** + o plugin de Studio dele: o
`InternalArmature` foi gerado por esse add-on (metadados `__RigMeta` v1.2, configuração `rbx_anim_settings` da cena
com o servidor local na porta **31337**). Caminho:

1. Instale o add-on no Blender e o plugin correspondente no Studio (mesma versão).
2. No Blender, painel do add-on: armature = `InternalArmature`; exporte/bake a Action ativa (o add-on lê a pose
   avaliada, então IK, poles e LookTo saem "assados").
3. No Studio, selecione um rig da crew montado pelo `CrewRig` (ou `tools/assetplace/build_crew.luau`) e importe
   pelo plugin (sincronia pela porta 31337 ou colando os dados). Sai um `KeyframeSequence` com poses `Torso`, `Head`,
   `Left Arm`... (R6 padrão).
4. Animation Editor > **Publish to Roblox** > o `AnimationId` vai para o código.

Os nomes exatos dos botões variam com a versão do add-on. Alternativa sem add-on (não testada aqui): bake da Action
no `InternalArmature` (Object > Animation > Bake Action, *Visual Keying*), exportar FBX só dessa armature com
animação e importar no Animation Editor (*Import > From FBX Animation*) sobre o rig da crew.

**Por que bate com o jogo:** os pivôs dos 7 ossos são os das Motor6D do jogo (`AST-053_CrewBase_joints.json`):
raiz (0, 3, 0), pescoço (0, 4, 0), ombros (±1, 3,5, 0), quadris (±1, 2, 0) em studs Roblox. Erro medido: **0,0006**
stud (tolerância 0,02). Os centros das malhas no repouso batem com os centros das MeshParts (C1 resolvido igual ao
`CrewRig`, inclusive o `Neck.C1` da cabeça grande). A animação exportada é a `Transform` de cada Motor6D no frame da
junta (C0, padrão R6), então vale para qualquer espécie.

## Verificação (2026-10-10)

Pose de teste (braço direito em IK pegando um ponto à frente, perna esquerda levantada, cabeça olhando para o lado,
e uma segunda com o tronco inclinado): separação nas 5 juntas **0,0000** stud; mão a 0,04 stud do grab point;
acessórios (orelhas, rosto, boné, rabo, avental) sem deslocamento relativo. Renders em `Assets/reference/rig/`:
`AST-069_pose_34.png`, `_front`, `_side`, `_top` e `AST-069_rest_<Dog|Cat|Turtle|Owl>.png` (troca de espécie).
Reconstruir/verificar: `tools/animrig/build_animal_rig.py` e `tools/animrig/verify_animal_rig.py` (instruções no
topo de cada um).

## Limitações

- **R6 = partes rígidas**, sem deformação: não existe cotovelo nem joelho. "Perna dobrada" é a perna inteira girando
  no quadril; o IK só mira o membro no alvo (se o alvo estiver longe, a mão para no alcance). Com Pin Joint = 1 o
  braço em IK não tem torção: use FK para girar o punho.
- Orelhas, rosto, boné, rabo, casco, juba etc. são rígidos na cabeça/tronco (nada de movimento secundário).
- **Expressões** são troca de textura em código (`Crew.setExpression` / CrewRig), não vão na animação. O arquivo
  mostra só a expressão Normal e as texturas de **dia**; noite e roupas civis são do jogo.
- **Desmaio = ragdoll em código** (AST-069: atropelamento é física); a animação cobre só o "levantar" curto.
- Translação em Motor6D é aceita pelo Roblox, mas evite mover braços/pernas para fora da junta (Pin Joint = 0 faz isso).
- 17 drivers do arquivo original apontam para ossos que não existem ("Show Anchor Points"); vieram do CommunityR6 e
  não afetam nada.
