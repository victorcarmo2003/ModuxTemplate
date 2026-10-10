Status: Rascunho

# Fontes de assets gratuitos low-poly stylized com textura pintada à mão

Autor: researcher. Pesquisa feita em 2026-10-09 (páginas consultadas nessa data). Nada foi baixado nem importado.
Pedido: trocar os assets por low-poly gratuitos com **textura pintada à mão** (cartoon, sem PBR), cobrindo `docs/art/asset-list.md`.

## Pergunta

Que famílias gratuitas e com licença comercial (CC0, ou CC-BY com crédito) cobrem comida, cozinha/food truck, carrinho e trailer, mercado, rua/cidade e props de história, com textura pintada à mão e um estilo só?

## Resposta curta

- **Não encontrei nenhuma família gratuita com textura pintada à mão que cubra mais do que uma categoria.** A única confirmada como hand-painted + CC0 + grátis é o **styloo 3D Food Asset Pack**, que é só comida e **não tem** hot dog, pão, salsicha, bacon nem café.
- As famílias grátis, coesas e amplas (**Kenney**, **KayKit**, **Quaternius**) usam **atlas de cor/gradiente ou cor chapada**. Não são textura pintada.
- Recomendação: usar a geometria **Kenney + KayKit** (CC0, as duas já estão no repositório) e pintar à mão **um atlas próprio do projeto**. Isso dá o visual pintado com um estilo só. Juntar packs pintados de vários autores não fecha a lista e mistura estilos.

## Conflito com documento aprovado (ler antes)

`docs/art/style-guide.md` está **Aprovado** (DEC-126) e diz o contrário do pedido novo:
- §1.1 (DEC-105): "cor vinda de um atlas de faixas em gradiente (**sem textura pintada**)".
- §6: proíbe "ruído/sujeira pintada".
- §9.2: no máximo **3 atlases de cor** e **24 MB** de textura (teto 30).

Para valer, a troca precisa de uma **DEC nova** que substitua a DEC-105 e revise §1.1, §6 e §9. Quem registra é o secretário.

## 1. Fontes verificadas

| Fonte | Licença (link) | Estilo | Formatos | Pacotes relevantes |
|---|---|---|---|---|
| **styloo, 3D Food Asset Pack** | CC0 1.0, declarado na página: [styloo.itch.io/3dfood](https://styloo.itch.io/3dfood) | **Pintado à mão** (confirmado na página). 40 texturas 512², não embutidas. HD 2048² + .blend custa US$ 3 ou mais | FBX, glTF | +125 itens: hambúrguer, pizza, batata frita, queijo, ketchup, carne crua e cozida, legumes, frutas, pratos. **Não lista** hot dog, pão, salsicha, bacon nem café. Os outros packs do autor (cidade, cozinha) não são pintados: [styloo.itch.io](https://styloo.itch.io/) |
| **CrazyDrPants (MadeByYeshe), Street Props Pack** | CC BY 4.0, crédito "MadeByYeshe": [página](https://crazydrpants.itch.io/street-props-pack) | "Hand Painted **PBR**": 101 texturas 1024² com normal, roughness e metallic | OBJ, GLB, FBX | Lixeiras, sacos de lixo, cones, hidrante, banco, poste, barreira, caixa de correio. **É PBR**: vai contra o style guide §6 e é pesado para celular |
| **Kenney** | CC0, válido para o site todo: [kenney.nl/support](https://kenney.nl/support). Não usar o logo Kenney | Atlas `colormap` com faixas de cor (FoodPack do repo). **Não é pintado** | OBJ, FBX, glTF ([Car Kit](https://kenney-assets.itch.io/car-kit)) | [Food Kit](https://opengameart.org/content/food-kit) (já no repo), [Mini Market](https://kenney.nl/assets/mini-market), [City Kit Commercial](https://kenney.nl/assets/city-kit-commercial), City Kit Suburban e Roads, [Car Kit](https://kenney.nl/assets/car-kit). A lista de modelos do Mini Market e do Car Kit não aparece na página: **conferir se há ambulância, van e caminhão** |
| **KayKit (Kay Lousberg)** | CC0, na página de cada pack ("não revender cópias sem modificação"): [Restaurant Bits](https://kaylousberg.itch.io/restaurant-bits), [City Builder Bits](https://kaylousberg.itch.io/city-builder-bits) | Atlas de **gradiente** 1024², pode descer para 128². **Não é pintado** | OBJ, FBX, glTF (.blend é pago) | Restaurant Bits (140+, já no repo). City Builder Bits (32+ grátis): prédios, ruas, carros. Postes não confirmados |
| **Quaternius** | **Ambígua.** As páginas dos packs dizem CC0 ([Downtown City MegaKit](https://quaternius.com/packs/downtowncitymegakit.html), [Junk Food](https://quaternius.com/packs/junkfood.html)). A [página de licença](https://quaternius.com/license.html) agora traz a **Quaternius Asset License v1.0** (atualizada em 28/08/2026): uso comercial liberado sem crédito, redistribuir é proibido e o autor mantém a propriedade intelectual. Ela não diz se packs antigos continuam CC0 | Maioria em cor chapada ou "texture sets" simples. Junk Food aparece como "textured", mas não está confirmado como pintado | FBX, OBJ, glTF, Blend | Junk Food (16 itens, **tem hot dog**), Ultimate Food, Downtown City MegaKit (315 peças, parte paga), Cars, Public Transport, Modular Streets |
| **Poly Pizza** | Agregador. Os [termos](https://poly.pizza/docs/tos) mandam seguir a licença CC **de cada modelo**. Modelos "Poly by Google" costumam ser CC-BY (não confirmei por modelo) | Varia por autor | glTF/FBX | A busca "hot dog" dá vários autores (Google Poly, Kenney, Quaternius, Polygonal Mind): estilos misturados |
| **OpenGameArt** | Varia por item. A [coleção "Stylized Hand-Painted"](https://opengameart.org/content/assets-stylized-hand-painted) não mostra licença por item | Pintado à mão, mas temática medieval/RPG | Varia | Para nós só serve caixote, barril, poste avulso e algumas frutas. Sem comida de rua, cozinha nem veículo |
| **Sketchfab** | Só com botão de download e licença CC explícita. CC-BY pede crédito ao autor e link para o Sketchfab | Varia | glTF/FBX | Achados: [Food Truck Textured](https://sketchfab.com/3d-models/food-truck-textured-3fc12b9392af4cffb9faf2546b73c369) (CC-BY, ~2,8k tris, **baseado no Mercedes T1**: risco de marca) e [Low Poly Street Food Cart](https://sketchfab.com/3d-models/low-poly-street-food-cart-a74ed86472c945328f3f2cf98fb26977) (CC-BY, estilo não confirmado). [City Props Collection](https://sketchfab.com/3d-models/city-props-collection-volume-1-32b8b82bb1e9489c993799c91967a916) é PBR, 70,8k tris, "Free Standard", e tem caixa de correio USPS: **descartar** |
| ithappy, Cartoon City Free | Página diz só "Creative Commons", sem versão: [Superhive](https://superhivemarket.com/products/cartoon-city-free). **Não confirmada** | Cartoon, com normal e roughness | FBX, glTF e outros | 80 modelos: carros, ruas, postes, lixeiras, prédios. Tem outdoors de produto. Não usar sem confirmar a licença |

Busquei carrinho de hot dog e food truck gratuitos, pintados e com licença clara. **Nada confirmado.** Os carrinhos de hot dog achados são pagos (Sketchfab Store) ou têm licença "royalty free" sem detalhes (BlenderKit, Free3D).

## 2. Recomendação de famílias

**Quais são de fato pintadas:** styloo Food (sim, CC0), CrazyDrPants Street Props (sim, mas PBR, CC-BY) e itens avulsos do OpenGameArt (sim, temática medieval).
**Quais não são:** Kenney (atlas de cor), KayKit (gradiente), Quaternius (chapado ou texture set simples), ithappy (cartoon PBR leve).

- **Recomendada: Kenney + KayKit como base de malha, com atlas pintado do projeto.**
  - As duas já estão no repo, são CC0, têm a mesma escala de detalhe e juntas cobrem comida, cozinha, mercado, cidade e carros.
  - O "pintado à mão" sai de **um atlas por categoria pintado pelo projeto**, por exemplo 512² para comida, equipamento e cidade.
  - Custo real: o UV desses packs aponta para faixas de cor, então cada malha precisa de **re-UV** para receber pintura com detalhe. É trabalho do modeler-3d no Blender, não é trocar uma imagem.
- **Alternativa (não recomendada): styloo Food para a comida + Kenney/KayKit para o resto.**
  - A comida ficaria pintada e o cenário com gradiente: dois estilos lado a lado, que é o que o usuário quer evitar.
  - O styloo não tem hot dog, pão, salsicha nem bacon, então os itens centrais do jogo seriam modelados de qualquer jeito.
- Descartar como base: CrazyDrPants (PBR), Sketchfab avulso (um autor por item) e Quaternius até a licença ficar clara.

## 3. Cobertura por categoria da asset-list

| Categoria (fichas) | Pack candidato | Cobertura | Nota |
|---|---|---|---|
| Comida: pão, salsicha, hot dog, molhos, queijo, bacon, café (AST-001 a 011) | Kenney Food Kit (repo); Quaternius Junk Food (hot dog) | **Coberto** em malha; **pintado: parcial** | styloo tem queijo, ketchup, carne e batata frita pintados, mas não tem pão, salsicha, bacon nem café |
| Equipamentos: grill, cooler, cafeteira, balcão, lixeira (AST-012 a 025, 039 a 042) | KayKit Restaurant Bits (repo) | **Parcial** | Fogão, geladeira, bancada, caixotes e tábua servem como base ou referência. Grill de 3 níveis, trilho, grade de complementos, cafeteira e telefone: modelar |
| Carrinho de hot dog (AST-026, 043) | nenhum | **Não coberto** | Nenhum gratuito com licença clara. Modelar |
| Food trailer (AST-027) | Sketchfab Food Truck Textured (CC-BY) | **Não coberto** na prática | Baseado em modelo real (Mercedes T1). Modelar |
| Mercado: prateleiras, geladeira, caixotes, frutas (AST-028 a 031, 049, 050) | Kenney Mini Market + Food Kit; KayKit crates | **Parcial/coberto** | Conteúdo do Mini Market não listado na página: conferir antes de usar. Frutas e caixotes já estão mapeados no style guide §1.2 |
| Rua: postes, hidrante, banco, lixeira, cone, barreira (AST-032, 034, 036, 047) | Kenney City Kit Roads; KayKit City Builder Bits | **Parcial** | Postes e hidrante não confirmados nesses packs. Pintados só no CrazyDrPants (PBR) |
| Prédios e fachadas (AST-033, 044 a 046) | Kenney City Kit Commercial/Suburban; KayKit City Builder Bits | **Parcial** | Os landmarks (banco com relógio, Mart, lavanderia) continuam como peças próprias |
| Carros, caminhão, ambulância, ônibus (AST-035, 048, 052, 065, 074) | Kenney Car Kit; KayKit City Builder Bits | **Parcial** (não confirmado) | Conferir se o Car Kit tem ambulância, van e caminhão. Recolor obrigatório (style guide §2.4: nenhum carro preto) |
| Props de história: panfleto, celular flip, foto, crachá (AST-037, 038, 068, 075) | nenhum | **Não coberto** | São pequenos e específicos. Modelar |
| Personagens (AST-053 a 064, 076) | Plataforma R6 | n/a | Fora do escopo de pack |

## 4. Riscos

1. **Licença ambígua.**
   - Quaternius: as páginas dos packs dizem CC0, mas a página de licença diz QAL v1.0 (28/08/2026). Registrar em `credits.md` a versão e a data do download.
   - Poly Pizza e Sketchfab: a licença vale por modelo e muitos são CC-BY, o que exige crédito no jogo.
   - ithappy: licença sem versão. Não usar.
2. **Peso de textura no celular.**
   - O styloo base sozinho tem 40 texturas de 512². Em RGBA sem compressão são ~1 MB cada, então ~40 MB contra o teto de 30 MB do §9.2 (estimativa; não medi a compressão do Roblox).
   - CrazyDrPants tem 101 texturas de 1024² PBR: inviável.
   - Roblox aceita até 4096² e faz streaming de qualidade conforme o aparelho. A doc sugere 512² para objeto de ~10×10 studs ([Texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications), consultada em 2026-10-09).
   - Atlas pintado por categoria (3 a 4 × 512²) mantém o orçamento.
3. **Escala e paleta.**
   - Cada autor usa unidade e escala diferentes. A comida "toy" é 1,5–2× o real (§1.1).
   - Misturar pintado com gradiente quebra a coesão.
   - A paleta do §2, incluindo as cores reservadas a anomalias (§2.4), precisa ser repintada nos packs.
4. **Marcas reais.**
   - Food truck "Mercedes T1" e caixa de correio "USPS" (City Props) são descartados.
   - Outdoors de produto (ithappy) e rótulos de comida e bebida precisam de recolor e decal próprio (§1.2, checklist §12 item 7).
5. **Pagos disfarçados.** Vários packs "free" têm a fonte .blend, o HD ou parte das peças em nível pago (styloo HD, KayKit Source/Extra, Downtown City MegaKit). Ver na página o que vem no nível grátis.

## Implicações e próximo passo

- Antes de qualquer troca, o usuário precisa registrar uma DEC que substitua a DEC-105, porque o style guide hoje proíbe textura pintada.
- Se aprovar o caminho recomendado, o art-director revisa §1.1, §1.2, §6 e §9.3 (atlas pintado por categoria, 512²). O modeler-3d faz um teste de re-UV + pintura em 3 peças (pão, salsicha, grill) antes de escalar.
- **Não confirmado:** lista de modelos do Kenney Mini Market e do Car Kit; se KayKit City Builder Bits tem postes; tris do styloo; se o Junk Food da Quaternius é pintado; licença do ithappy.
