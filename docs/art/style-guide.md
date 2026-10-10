Status: Aprovado (DEC-126, rodada 15, 2026-10-08: documento inteiro; Future + fallback ShadowMap; roupa de NPC opção A). Exceções que valem por DEC: §4.6 "Ambulância leva" → **DEC-114** (médicos descem e levam o corpo; sem maca automática); §11 sinal do Walker → **DEC-123** (~2 s); §5.3 leitura do fim da Juniper "~110 studs" → **~135 studs**, postes da Juniper a cada 8 studs (**rodada 17**, DEC em registro pelo secretário; trocar "rodada 17" pelo número da DEC quando existir). Texto alinhado com as duas DECs em §4.6 e §11 (art-director, 2026-10-08; fechamento de `Q-127` com o secretário). A proposta de avental (§4.1, CHR-002) segue não decidida. **2026-10-10:** §7.3 moldura da vaga rara → **Mustard** (**DEC-144**; Gold só no AST-051, §2.1). §4.1 e §1.1 (corpo R6 clássico) **emendados por DEC-145**: personagem padrão "HotDog Crew" (`Assets/reference/customrig.png`), malha custom R6 do projeto, animal trocando cabeça/orelhas/cauda sobre a mesma base; quem usa, proporção e técnica em `Q-141` e `Q-144` (texto do §4 a reescrever pelo art-director). **DEC-146:** jogador vira animal da crew, sem avatar próprio; clientes NPC seguem humanos (§4.1 "Jogadores", §4.5 colegas e §4.6 a reescrever; personagens com nome `Q-146`). **DEC-147:** animal = classe (`Q-145`). **DEC-148:** personagens da crew com **textura** de roupa/rosto/pelagem — exceção de personagem a §1.1/§6 e à opção A do §4.1; cenário e props seguem sem textura pintada; orçamento em §9.3 a escrever (`Q-144` g). **DEC-149:** clientes e pedestres **também são animais** (emenda DEC-146): §4.1 opção A, §4.2, §2.4 e §4.4 a rever (`Q-147`, `Q-149`). **DEC-150:** personagem com variante de **dia** e de **noite** por troca de textura; §2.3 ("a noite não troca modelo nem textura") vale para a cidade, não para personagens (`Q-148`).

# Style guide — Sell Hotdogs

Autor: art-director. Criado em 2026-10-08; conciliado com DEC-073 a DEC-105 em 2026-10-08; anotado com DEC-114, DEC-123 e DEC-126 em 2026-10-08; exceção da rodada 17 (postes da Juniper, ~135) anotada em §5.1 e §5.3.
Só o usuário aprova (`CLAUDE.md`). **Decidido:** documento inteiro aprovado (DEC-126), incluindo iluminação Future com fallback ShadowMap (§5.1) e roupa de NPC opção A (§4.1); estilo "toy low-poly" (§1.1, DEC-105); todo personagem em R6, sem braços em 1ª pessoa (DEC-089, DEC-097).
Fichas `AST-###` só vão ao modeler-3d com status **Aprovado** (cada uma com aprovação própria; DEC-126 não aprova `asset-list.md`).

Base: `vision.md`; DEC-009 (identidade), DEC-013/DEC-039 (1ª pessoa travada), DEC-014 (mobile primeiro), DEC-015/DEC-066 (HUD só de status, prompt no mundo),
DEC-021/DEC-088 (cutscene em 1ª pessoa, compartilhada), DEC-022 (texto em inglês), DEC-023 (infantojuvenil, sem violência), DEC-029 (barra e VFX do AnimalPlane),
DEC-038/DEC-041/DEC-055/DEC-056 (sanidade, escuro, luz), DEC-052 (2 veículos), DEC-073/DEC-074 (10 anomalias, `ANM-001`–`ANM-010`, DEC-096),
DEC-075/DEC-076 (Walt em pessoa só no final), DEC-079/DEC-099 (Opal), DEC-086 (trailer na esquina), DEC-087/DEC-095/DEC-103 (trânsito e atropelamento pastelão),
DEC-089/DEC-097 (R6), DEC-090 (celular-alvo adiado), DEC-091 a DEC-094 (desmaio, ambulância, reviver, spectate), DEC-100/DEC-101 (Mart: prateleiras, frutas/verduras, bancada de upgrades, item raro de reviver), DEC-105 (estilo).
Nomes de lugares e personagens: `story/world.md` e `story/characters.md` (Rascunho; textos finais do narrative-writer).
Packs disponíveis: `Assets/KitchenPack` (KayKit Restaurant Bits 1.0, CC0) e `Assets/FoodPack` (Kenney Food Kit 2.0, CC0). Créditos em `credits.md`.

Inspiração, não cópia: nenhum visual, logo, personagem, paleta-assinatura ou layout de outro jogo. A referência "Animal Hospital"
(DEC-013) vale só para estrutura de câmera e UX, nunca para aparência. Nenhum emblema protegido (Cruz Vermelha, Crescente Vermelho, Star of Life) e nenhuma marca real de carro, comida ou loja.

---

## 1. Estilo

### 1.1 "Toy low-poly" com atlas de gradiente — **Decidido (DEC-105)**

Formas grossas e arredondadas, chanfro largo, poucas faces, cor vinda de **um atlas de faixas em gradiente** (sem textura pintada).
Combina com os dois packs, é leve no celular, fica "cute" de dia; à noite a mesma forma simples fica estranha só pela luz.
As opções B (flat facetado) e C (semi-realista) ficam só como histórico.

Regras:
- **Forma primeiro.** Todo objeto se reconhece pela silhueta preta a 10 studs. Se precisa de textura para ser lido, a forma está errada.
- **Chanfro largo** (bevel de 1 segmento, ~8–12% da menor dimensão) em quinas visíveis. Nada de quina viva em objeto interativo.
- **Proporção de brinquedo:** comida e ferramentas ~1,5–2× maiores que o real em relação ao personagem (legibilidade em 1ª pessoa no celular).
- **Cor por UV no atlas**, não por material. Uma faixa do atlas = uma cor com gradiente vertical suave (claro em cima, escuro embaixo), igual aos packs.
- **Sem contorno (outline)** pintado nem `Highlight` permanente. O realce de "posso interagir" vem do prompt custom (DEC-066).
- **Sem texto modelado.** Placas, letreiros e rótulos são decal da folha de placas (AST-072), em inglês (DEC-022), texto final do narrative-writer.
- **Personagens R6** (§4): o "toy" do personagem vem de cor chapada por parte do corpo e acessórios grossos de atlas, não de corpo custom.

### 1.2 Integração dos packs

| Pack | Atlas | Como usar |
|---|---|---|
| KitchenPack (KayKit) | `Assets/KitchenPack/Assets/textures/restaurantbits_texture.png`, 1024², 32 faixas em gradiente | usar direto quando a cor servir. Reduzir o atlas para **512²** no import (gradiente não perde nada) |
| FoodPack (Kenney) | `Assets/FoodPack/Models/FBX format/Textures/colormap.png`, 512², faixas em gradiente | usar direto. Kenney é um pouco mais facetado: preferir as peças mais arredondadas ou suavizar normais |
| Projeto | `Assets/textures/T_Palette_SH.png`, 512², a criar (modeler-3d) | toda peça modelada do zero usa este atlas. Peça de pack **editada** é remapeada para ele |

Meta: no máximo **3 atlases de cor** no jogo inteiro (projeto + 2 packs). Pack sem edição mantém o atlas original.
Cor de pack que bate com a identidade de outro jogo ou marca (combinação icônica, logotipo) não entra sem recolor.

Antes de pedir modelo novo, conferir os packs. Achados úteis já mapeados nas fichas: caixotes de feira do KitchenPack (`crate_lettuce`, `crate_tomatoes`,
`crate_carrots`, `crate_onions`, `crate_potatoes`) e frutas/verduras do FoodPack (`apple`, `banana`, `orange`, `pear`, `lemon`, `grapes`, `watermelon`,
`pineapple`, `cabbage`, `broccoli`, `carrot`, `corn`, `tomato`, `eggplant`, `paprika`) para a área de frutas/verduras do Mart (AST-050), sem modelar nada.

---

## 2. Paleta

Valores iniciais; o modeler-3d monta o atlas com estas faixas. `Sat` = saturação relativa: **interativo ~85%**, **decorativo ~55%**.

### 2.1 Núcleo (comida e marca Bramble's)

| Nome | Hex | Uso |
|---|---|---|
| Bun | `#F4D9A0` (topo) → `#D9A35E` (base) | pão |
| Sausage Raw | `#E9A08F` → `#C9706A` | salsicha crua |
| Sausage Grilled | `#C2602F` → `#7E3519` | salsicha pronta (com marcas de grelha) |
| Sausage Wrong (ANM-002) | `#8E9AAE` → `#5F6B80` | salsicha cinza-azulada da anomalia; nunca usada em outro lugar |
| Ketchup | `#E2402E` → `#A8261B` | molho, garrafa, corpo do carrinho Bramble's |
| Ketchup Faded | `#C7685C` → `#9C4A42` | faixa desbotada do trailer velho |
| Mustard | `#F6C12B` → `#C98E12` | molho, acabamento, acento interativo |
| Cheese | `#FFD45A` → `#E8A92A` | queijo |
| Bacon | `#C9533E` / `#F3B7A0` (gordura) | bacon |
| Potato Sticks | `#F7D27A` → `#D9A440` | batata palha |
| Cream Cheese | `#FFF8EC` → `#E8DCC8` | cream cheese |
| Coffee | `#5A3A2A` | café; copo `#FFFFFF` com cinta `#3FA7B5` |
| Steel | `#C9D1D8` → `#7C8792` | grelha, cooler, metais |
| Aluminum | `#E3E7EB` → `#A9B1B9` | casca do trailer (alumínio velho, `world.md` §4) |
| Cream | `#FFF1D6` → `#EAD6B0` | listras do carrinho, frisos do trailer |
| Teal | `#3FA7B5` → `#256E7A` | acento secundário (tampas, cafeteira, ambulância) |
| Gold (raro) | `#FFD86B` → `#D9A21E` com brilho | **só** no item raro de reviver (AST-051); nenhum outro objeto usa |

### 2.2 Paleta por área — dia

Nomes de rua: `story/world.md` (Ninth Avenue, Juniper Street), os mesmos do `levels/MAP-01.md` (revisão 2).

| Área | Cores dominantes | Acento | Nota |
|---|---|---|---|
| Esquina Ninth & Juniper (carrinho, dias 1–5) | Ketchup, Cream, Steel | Mustard (bordas, guarda-sóis) | ponto mais saturado do mapa: o olho volta sempre para ele |
| Open Late Trailer (no Pad depois da compra, DEC-086) | Aluminum (corpo), Ketchup Faded + Cream (faixa) | Mustard (letreiro "BRAMBLE'S — OPEN LATE") | mesma marca do carrinho, mais velha e desbotada (Sat ~65% na casca; estações seguem Sat ~85%) |
| Ninth Street Mart | Sage `#A8C69F`, Off-white `#F1EEE6`, toldo `#5FA36A` / `#F1EEE6` listrado | prateleiras e frutas saturadas; bancada de upgrades com moldura Mustard | porta com linha de visão para o Pad (DEC-049) |
| Bellmoor Savings (banco) | Brick `#B8664F`, pedra Cream | mostrador do relógio Cream, ponteiros `#2B2233` | landmark: o relógio é lido do balcão (ANM-003) |
| Apartamentos | Peach `#F2B8A0`, janelas `#9FD3E8`, cortinas Butter `#F3DFA2` | — | janelas de cima acima da linha do olhar (ANM-006) |
| Lavanderia | Mint-gray `#B7CFC6`, Off-white | toldo Lilac `#BFB2D9` | decorativo |
| Rua | Asfalto `#4A4E58`, Calçada `#CFC8B8`, Meio-fio `#9A948A`, faixa de pedestre `#F1EEE6` | sinalização Mustard; meio-fio vermelho `#B8664F` (proibido estacionar) | neutra, para o Pad saltar |
| Pad (piso do trabalho) | concreto pintado `#E8D9B5` com borda Mustard | — | "aqui é o lugar do trabalho" (MAP-01 L01-21) |
| Estacionamento | asfalto mais claro `#5A5F69`, faixas `#F1EEE6` | placa "Available on Day 5" Mustard | trailer à venda é o único objeto saturado ali |
| Trânsito | Peach, Butter, Lilac, Mint-gray, Teal claro `#8FC9D1` | faróis Cream | Sat ~55%; **nunca preto** nem branco com faixa Teal (§2.4) |
| Ambulância | Cream `#FFF1D6`, faixa Teal larga | barra de luz Mustard/Teal | lê "resgate" pela forma e pela barra de luz; sem emblema protegido |
| Vegetação | `#6DBE6A` → `#3E8A4A` | — | pouca; vasos e árvores redondas |
| Céu | `#8FD3F4` (via Sky/Atmosphere) | — | |

### 2.3 Noite

A noite **não troca o modelo nem a textura**. A mesma cidade muda por iluminação e pós-processo (DEC-010: "a cidade continua a mesma").

> **DEC-150 (2026-10-10):** a regra acima vale para **cidade, cenário e props**. **Personagens** animais trocam de **textura** à noite (mesma malha): dia fofo, noite um pouco assustadora. Intensidade e quem troca: `Q-148`; convivência com os traços reservados de §2.4: `Q-147`.

| Elemento | Cor | Nota |
|---|---|---|
| Ambiente geral | `#1B2140` (azul-violeta) | sombras nunca pretas puras: criança precisa enxergar a forma |
| Sombras profundas | `#0B0D1E` | só onde não há luz nenhuma |
| Postes da Juniper (sódio) | `#FFB25A` | acendem às 8:00 PM (`world.md` §2); poças de luz com escuro entre elas; o Hush apaga um por um (ANM-010) |
| Interior do trailer / Trailer Lights | `#FFE7C2` (branco quente) | a "ilha" segura; o raio visual bate com os 18 studs de DEC-055 |
| Ninth Street Mart, interior | `#D8FFE6` (fluorescente frio, levemente verde) | claro mas não acolhedor |
| Neon "OPEN 24 HOURS" | `#FF8A65` (coral) | nunca apaga, nem no Hush; cor que **nenhuma outra luz do mapa usa** (é o ponto seguro) |
| Relógio do banco | mostrador emissivo Cream fraco | legível no escuro, não ilumina |
| Janelas dos apartamentos | faixa "acesa" `#F3DFA2` no atlas | sem luz real; a janela da ANM-006 acende por troca de cor |
| Faróis do trânsito | Neon Cream + `Beam` curto | sem luz real (§5.1) |
| Farol alto do long car (ANM-008) | `#F4F7FF` (branco frio) | **única** luz de veículo que ilumina de verdade; cor distinta dos faróis comuns |

### 2.4 Cores e traços reservados para anomalias

Quebra de padrão só funciona se o normal **nunca** usa o traço da anomalia (DEC-010). Nenhum cliente normal, pedestre, carro ou prop usa:

| Reservado | Para | Regra para o normal |
|---|---|---|
| Capa de chuva amarela `#F2C230` cobrindo o corpo + botas verdes | Raincoat Lady (ANM-005) | nenhum NPC normal com casaco amarelo; amarelo só em detalhe pequeno (boné, bolsa) |
| Silhueta muito escura `#14162A` de corpo inteiro, alta | Walker (ANM-007) | roupas normais com valor ≥ `#4B4F63`; nenhum NPC normal maior que o R6 padrão |
| Carro preto comprido | long car (ANM-008) | nenhum carro de trânsito preto ou mais longo que 16 studs |
| Cabeça sem rosto | blank folks (ANM-001) | todo NPC normal tem olhos e boca |
| Texto e lado invertidos | copies (ANM-004) | todo texto de roupa normal é **assimétrico** e legível (nada de "WOW", "MOM", "OXO", número 8); todo cliente normal tem um lado marcado (relógio, bolsa, bordado) |
| Cinza-azulado na comida | wrong food (ANM-002) | nenhuma comida ou embalagem nessa cor |
| Coral do neon do Mart | ponto seguro (ANM-010) | nenhuma outra luz ou letreiro coral |

Cada traço reservado difere dos vizinhos em **luminância ou forma**, não só em matiz (daltonismo vermelho-verde).

---

## 3. Linguagem de forma

| Classe | Forma | Cor | Leitura |
|---|---|---|---|
| **Interativo** (estação, prateleira, bancada de upgrades, placa OPEN, interruptor, lixeira, cafeteira, telefone) | volume simples e grosso; "boca" ou superfície de uso virada para o jogador; nenhuma peça fina < 0,2 stud | Sat ~85%, sempre com 1 acento Mustard ou Teal | reconhecível a 10 studs; alvo de prompt com face frontal ≥ 0,8 × 0,8 stud |
| **Item na mão** (Tool) | silhueta única por item, sem dois Tools parecidos de lado | cor da comida + rótulo grande | legível na hotbar como ícone e na mão em 1ª pessoa |
| **Decorativo perto** (≤ 30 studs: bancos, hidrante, vasos, frutas) | arredondado, menos chanfro | Sat ~55% (frutas ~70%: são cenário, mas é o canto alegre do Mart) | não compete com interativos |
| **Decorativo longe** (> 30 studs: prédios, fundo) | caixas com recortes de janela; prédios de fundo em "cartão" | Sat ~45%, mais claro (perspectiva atmosférica) | legível de longe pela massa, não pelo detalhe |
| **Veículo em movimento** (trânsito, ambulância) | caixa arredondada, para-choque grosso "de espuma", rodas grandes | Sat ~55% | lê "carro de brinquedo": atropelamento fica pastelão, não real |

Escala (fecha `Q-095` do lado da arte, alinhada ao MAP-01 §2):

| Medida | Valor | Motivo |
|---|---|---|
| Personagem R6 | ~5 studs de altura (pernas 2, tronco 2, cabeça 1) | rig padrão R6 (DEC-089, DEC-097) |
| Olho / câmera em 1ª pessoa | **4,5 studs** | `HumanoidRootPart` (3,0) + deslocamento padrão da câmera (1,5) |
| Superfície de estação e bancada | **3,5 studs** do chão (ou do piso do trailer) | 1 stud abaixo do olho: com o FOV padrão (70°), um item a 2 studs de distância fica ~27° abaixo do centro, dentro da tela sem inclinar a câmera. A 3,0 ficaria na borda (~37°) |
| Profundidade útil da estação | 2,5–3 studs | MAP-01 §7.1 (linha de 3 studs) |
| Peitoril da janela do trailer | 3,5 do piso interno | MAP-01 §7.2 |
| Câmera escondido ("Hide") | ~2 studs | abaixo do peitoril (MAP-01 §7.2) |
| Porta | 4 × 7,5 | MAP-01 §2 |

> **Nota do secretário, DEC-157 (2026-10-10):** o usuário baixou a bancada do **carrinho** (AST-026) para **3,0**. Vale a DEC para o carrinho; trailer segue 3,5. Conferência da leitura em 1ª pessoa e texto desta tabela: `Q-153` (art-director).

Regras gerais:
- Objeto interativo nunca encostado em decorativo da mesma cor.
- Estoque visível: toda estação de ingrediente tem uma peça `Fill` que sobe e desce com o nível (GERENCIAR, DEC-017). O jogador lê "está acabando" sem HUD.
- Todo upgrade aparece como peça física (DEC-006, DEC-052). Nunca só um número. A **compra** é na bancada do Mart (DEC-101); a **peça** aparece no veículo.

---

## 4. Personagens (R6 para todos — DEC-089, DEC-097)

### 4.1 Base R6

> **Emenda DEC-145 (2026-10-10):** o padrão de personagem do projeto passa a ser o **"HotDog Crew"** (`Assets/reference/customrig.png`): animal humanoide em **rig R6 custom** (bones `Head`, `Torso`, `LeftArm`/`RightArm`, `LeftLeg`/`RightLeg`), corpo base comum modelado primeiro; cada animal troca cabeça, orelhas, cauda e cores. Uniforme da prancha: boné vermelho, avental vermelho com hot dog, camisa creme, calça preta. R6 continua (DEC-089/DEC-097). Para quem usar o rig novo, "cabeça clássica R6 + decal" e "proporção R6 fixa" abaixo não valem. **Em aberto:** quem usa (jogadores, NPCs; avatar próprio do Roblox) `Q-141`; proporção, rosto, orçamento e técnica `Q-144`; logo do avental `Q-143`.
>
> **DEC-146 (2026-10-10, fecha `Q-141`):** **o jogador joga com um animal da crew e não usa mais o avatar do Roblox.** O parágrafo "Jogadores: usam o avatar do próprio Roblox…" e a "Proposta (CHR-002)" abaixo **não valem**: o jogador é corpo base R6 custom + peças do animal + uniforme da crew (AST-073 vira parte do personagem). **Clientes NPC seguem humanos R6** desta seção (opção A, §4.2) por enquanto. Personagens com nome (§4.3) não mudam até `Q-146`. Animal = classe (DEC-147, `Q-145`). Reescrita do §4.1, §4.5 e §4.6 → art-director.
>
> **DEC-151 e DEC-152 (2026-10-10):** roupa texturizada e rig R6 do corpo base da crew **aprovados** (DEC-151). **Cabeça** de cada animal = **malha única oval** com **focinho em volume** (ref. `customrig.png`); **olhos, nariz e boca por textura**; **expressões por troca de textura** (normal, feliz, sorridente, triste, desmaiado com X nos olhos/boca; lista aberta); estilo mais cartunizado (DEC-152). Vale também para clientes animais (DEC-149). Teto de §4.4 e DEC-023 valem para as expressões. Técnica (casca de rosto com UV padrão, troca por `TextureID`) **Provisória** em `Q-144` (h); versão noite das expressões `Q-150`; memória em §9.3 (`Q-144` g).

Todo personagem é **R6**: jogadores (avatar do próprio jogador, forçado R6), clientes, Quick Quentin, Opal, Walt, atores de anomalia.

| Opção de roupa do NPC | O que é | Prós | Contras |
|---|---|---|---|
| **A. Cor por parte + acessórios de atlas + decals pequenos** (recomendada) | `BodyColors` dão a cor da "camisa" (tronco e braços) e da "calça" (pernas); volume vem de **acessórios MeshPart** do atlas do projeto (casaco, colete, capacete, mochila, maleta, cabelo, chapéu); texto e logo são **decals pequenos** (128²–256²) no tronco | visual de brinquedo coerente com o cenário; quase zero textura nova; troca de variante por dados; o espelhamento da ANM-004 fica barato (decal espelhado + acessório no outro lado) | acessórios de malha custam tris (orçamento em §9.1) |
| B. Roupa clássica (`Shirt`/`Pants`, template 585 × 559) | camisa e calça pintadas em textura | detalhe pintado; padrão do Roblox | ~1,3 MB por textura; 6 tipos × 4 variantes × 2 peças + especiais ≈ 60 texturas — estoura o orçamento de memória (§9.2); visual "pintado" destoa do cenário de atlas |

Regras da opção A:
- Cabeça: cabeça clássica R6 + **decal de rosto** próprio (256², um arquivo por rosto; `Decal` não usa folha).
- Corpo: proporção R6 fixa (sem escala de corpo). Diferença de idade e tipo vem de cabelo, chapéu, óculos, postura (animação) e acessório.
- Acessórios presos nos attachments padrão do R6: `HatAttachment`, `HairAttachment`, `FaceFrontAttachment`, `BodyFrontAttachment`, `BodyBackAttachment`,
  `LeftCollarAttachment`/`RightCollarAttachment`, `WaistFrontAttachment`/`WaistBackAttachment`, `LeftGripAttachment`/`RightGripAttachment` (pulso e mão), `LeftFootAttachment`/`RightFootAttachment`.
- Cada acessório usa o atlas do projeto (`T_Palette_SH`), sem textura própria.
- Escala diferente só por `Model:ScaleTo` para o Walker (ANM-007), que **deve** sair do tamanho normal (§2.4).

Jogadores: usam o avatar do próprio Roblox em R6. A arte não controla roupa nem acessório do jogador.
Proposta (CHR-002, não decidida): avental Bramble's como acessório aplicado na run (AST-073, P2), sem substituir a roupa do avatar.

### 4.2 Clientes normais: padrão forte

DEC-010: o normal precisa ser repetitivo para a quebra ser notada. Tipos de `design/npcs.md` (NPC-001 a NPC-006, NPC-019, NPC-021).
- Cada tipo tem **acessório de silhueta próprio** (escritório: crachá e pasta; estudante: mochila e boné; corredor: faixa e fone; operário: capacete e colete; avô/avó: cardigã e bengala; plantão noturno: jaqueta de uniforme genérica e garrafa térmica; pedestre: sacola).
- **4 variantes de cor** por tipo (npcs.md, invariante 3). Nenhuma usa traço reservado (§2.4).
- **Detalhe assimétrico legível no celular** em toda variante (invariante 10): texto no peito de um lado, relógio num pulso, bolsa numa mão. É o que a cópia da ANM-004 inverte.
- Rostos: **8 decals** originais simples (olhos de ponto, boca em linha), sempre com olhos e boca; + 3 reações (feliz, reclamação, bufando) trocadas na reação.
- Convivência: dois normais iguais nunca ao mesmo tempo; idle com **fase aleatória**. O "duplicado" fica reservado à anomalia.
- **Mr. Pickett** (CHR-005): terno marrom, gravata-borboleta verde, relógio grande no pulso **esquerdo**, maleta na mão **direita**, cabelo repartido à **esquerda**, bordado "PICKETT & SONS" no peito **esquerdo**.

### 4.3 Personagens com nome

| Quem | Quando aparece | Silhueta (de `characters.md`) | Nota de arte |
|---|---|---|---|
| Quick Quentin (CHR-004) | dia 2+ | magro, sobretudo grande demais, chapéu de aba baixa, óculos escuros redondos, bigodinho, tênis muito brancos; saco com "$" | sobretudo **cinza-arroxeado `#7A6FB0`**, mesma família da barra do ladrão (`#6A5ACD`): lido a 110 studs do Mart (MAP-01 §6). Vilão de desenho, sem máscara, sem arma |
| Opal (CHR-003) | Mart, dia e noite | senhora, coque grisalho com lápis espetado, cardigã verde, colete do Mart, óculos na corrente | idle de palavras cruzadas atrás do caixa (AST-031); nunca é anomalia |
| Walt Bramble (CHR-001) | **só** na cutscene final (DEC-075, DEC-076) | ~70 anos, baixo, barriga redonda (acessório de tronco), bigode branco grosso, boné vermelho com a salsicha sorridente, jaqueta creme e vermelha desbotada, crachá "WALT — NIGHT SHIFT", óculos grossos, dois cafés | modelo só no client; nenhum retrato dele em outra tela |
| Raincoat Lady (CHR-006) | noite 5+ e final | senhora pequena, capa amarela com capuz, botas verdes, guarda-chuva fechado, **olhos fechados**, rosto completo e gentil | nunca assustadora: o estranho é a água (pingos e poça), não ela |

### 4.4 Como sinalizar anomalia

Princípio: **a anomalia é feita das mesmas peças do normal**. Nada de brilho, partícula ou som que "aponte" o alvo (DEC-005: "sei que tem algo errado, mas não sei o quê").

| Camada | Distância de leitura | Anomalias (DEC-073) |
|---|---|---|
| 1. Silhueta | 15+ studs | Walker alto e escuro sob o poste (ANM-007); carro comprido demais (ANM-008); silhueta acenando na janela (ANM-006) |
| 2. Cor | 8–15 studs | capa amarela pingando (ANM-005); salsicha cinza-azulada (ANM-002) |
| 3. Detalhe | 4–8 studs (balcão) | rosto liso + balão vazio (ANM-001); texto invertido e lado trocado (ANM-004); mordida em meia-lua no pão (ANM-002) |
| 4. Ambiente / som | qualquer | relógio do banco parado e sem tique-taque (ANM-003); batidas na porta dos fundos (ANM-009); postes apagando um a um (ANM-010) |

Teto de intensidade (DEC-023): sem sangue, ferimento, arma, esqueleto, dente exposto, olho fora do lugar, contato físico, carro funerário.
O estranho vem de **algo que falta, sobra, se repete ou está do lado errado**.
- **Sem rosto (ANM-001):** cabeça com a cor de pele lisa, sem decal; sem animação de respiração. Nunca rosto deformado.
- **Cópia (ANM-004):** mesma variante do original com decal de texto **espelhado**, acessórios de pulso e mão no lado oposto, cabelo repartido do outro lado (malha espelhada). Nada mais muda.
- **Walker (ANM-007):** R6 escalado ~1,35×, sobretudo e chapéu `#14162A`, rosto na sombra da aba (decal escuro liso, sem olhos brilhando).

### 4.5 Jogador em 1ª pessoa (DEC-097)

> **DEC-146 (2026-10-10):** sem braços, câmera padrão travada e Tool na mão **continuam** (DEC-097). Muda: o corpo do jogador é o **personagem da crew** (rig R6 custom), não o avatar; "colegas veem o avatar R6 inteiro" → colegas veem o **animal da crew** inteiro (também na cutscene, DEC-088). A conferir pelo art-director com `Q-144`: cabeça maior × altura do olho (4,5) e se orelhas/cabeça grande aparecem na câmera; ocultação do próprio corpo com malha custom e acessórios (orelhas, cauda).

- Câmera em 1ª pessoa **padrão do Roblox**, travada (DEC-039). **Sem braços** (sem viewmodel).
- O corpo do próprio jogador some na câmera padrão; a **Tool continua visível** na mão (o controle de transparência padrão não esconde peças de Tool).
- Com a pose padrão de segurar Tool do R6 (braço direito à frente), o item aparece no **terço inferior direito** da tela. Cada Tool define o `Grip` para não cobrir o centro (ver §8, `Handle`).
- Colegas de party veem o avatar R6 inteiro, inclusive na cutscene compartilhada (DEC-088).

### 4.6 Ragdoll pastelão (DEC-095, DEC-103) e queda por sanidade (DEC-091)

| Evento | Corpo R6 | VFX/SFX (AST-070) | Proibido |
|---|---|---|---|
| Atropelamento | ragdoll R6 (juntas soltas), arremesso curto em arco, quica 1× | anel de estrelinhas Mustard no impacto, 3 estrelinhas girando sobre a cabeça enquanto está no chão, nuvem de poeira ao levantar; buzina "honk-honk" e "boing" | som de impacto realista, osso, grito, amassado no carro, mancha |
| Item derrubado | Tool cai e quica 1× no chão | mini poeira; o item no chão mantém a mesma malha | — |
| Desmaio (sanidade 0) | personagem senta e deita de lado (animação, não ragdoll) | balão "Zzz" cartunizado sobre a cabeça (lê "dormiu", não "morreu"); visão de quem caiu embaça e escurece | olhos em X, cruz, caveira, poça, fita de cena |
| Ambulância leva (ida) — **DEC-114** | os 2 médicos R6 (CHR-008, AST-076) descem pelas portas traseiras com a maca, vão até o corpo, deitam o personagem nela com "poof", levam a maca de volta e sobem; portas fecham (ver AST-052) | luzes Mustard/Teal giram; sirene curta e suave | equipamento médico realista, sangue (DEC-023) |
| Reviver (volta) — DEC-091, DEC-114 | ambulância para, **ninguém desce**, jogador "aparece" ao lado | nuvem "poof" + brilho curto | médico descendo na volta |

---

## 5. Iluminação

### 5.1 Tecnologia — **Future com fallback** (decidido, DEC-126)

Celular mínimo foi adiado (DEC-090): não há aparelho de referência para medir agora. A decisão protege as duas saídas:

| Item | Valor |
|---|---|
| `Lighting.Technology` | **Future** |
| Fallback automático | o motor já reduz a qualidade das luzes locais (sombra e precisão) em aparelho fraco ou qualidade gráfica baixa; o mapa precisa continuar correto nesse modo |
| Fallback manual | se a otimização posterior (DEC-090) reprovar Future no celular, troca para **ShadowMap** mudando só a propriedade; nenhum asset muda |
| Regra que garante o fallback | **nenhuma mecânica e nenhuma leitura de anomalia depende de sombra de luz local**. Escuro de jogo = `LightZone` marcada no mapa (MAP-01 §10.2, FEAT-020), não cálculo de luz |
| Por que Future | poças de luz dos postes da Juniper, o interior do trailer como "ilha" e o Hush apagando poste por poste ficam muito mais fortes com luz local de verdade |

Orçamento de luz (qualquer tecnologia). Revisa o §13 do MAP-01 (≤ 10 luzes ativas, com JL-02..09 só emissivos), que é anterior aos postes da Juniper exigidos por `anomalies.md` (Aprovado) e FEAT-020:

| Luz | Tipo | Sombra | Quantidade |
|---|---|---|---|
| Interior do trailer | `SpotLight` no teto | **sim** | 1 |
| Trailer Lights (UPG-005) | `SpotLight` do mastro + cordão com `PointLight` fraca | mastro **sim**; cordão não | 1 + 2 |
| Mart (interior + neon) | `SurfaceLight` interior + `PointLight` no letreiro | letreiro **sim** (opcional) | 2–3 |
| Postes da Juniper / Ninth | `SpotLight` para baixo, Range 16–20 | não | ≤ 10 (um por passo do Walker visível + esquina; com postes a cada 8 studs, rodada 17, os excedentes ficam só com `Neon` + decal de poça, §5.3) |
| Long car (ANM-008) | 2 `SpotLight` frios | não | 0–2 (só na anomalia) |
| Ambulância | 1 `PointLight` Range 10 alternando cor | não | 0–1 (só no evento) |
| Faróis do trânsito | **sem luz real**: Neon + `Beam` curto | — | 0 |
| Janelas, relógio do banco, letreiros secundários | emissivo (Neon pequeno / faixa clara no atlas) | — | 0 |

Teto: **≤ 3 luzes com sombra** visíveis ao mesmo tempo; **≤ 18 luzes locais** ativas no mapa à noite; dia: 0–2.
Lâmpadas visíveis são peças `Neon` pequenas; nunca `Neon` em área grande.

### 5.2 Dia

O `ClockTime` segue o relógio do jogo (7:00 AM → 6:00 PM, DEC-048), mas os valores são **travados no "dia bonito"** até 4:00 PM;
das 4:00 PM às 6:00 PM entra a hora dourada (laranja suave), única pista de que o dia acaba.

| Propriedade | Valor inicial |
|---|---|
| `Brightness` | 2,2 |
| `Ambient` / `OutdoorAmbient` | `#8C8378` / `#A89E8E` |
| `ColorShift_Top` | `#FFF1D6` |
| `EnvironmentDiffuseScale` / `EnvironmentSpecularScale` | 0,5 / 0,15 (pouco brilho especular: visual de brinquedo) |
| `GlobalShadows` / `ShadowSoftness` | true / 0,35 |
| `Atmosphere` | Density 0,25 · Haze 1 · Color `#C7E6F5` · Decay `#F2D8B0` |
| `ColorCorrection` | Saturation +0,10 · Contrast +0,05 |
| `Bloom` | Intensity 0,35 · Size 24 · Threshold 1,8 |
| `SunRays` | Intensity 0,04 |

### 5.3 Noite

`ClockTime` fixo próximo de 0 (o relógio do HUD anda; o céu não precisa). A tensão cresce **por noite** com valores de tabela
(atmosfera mais densa, um poste da Ninth que pisca), não por mudança de modelo. Os postes da **Juniper** ficam acesos (são o palco do Walker e do Hush).

| Propriedade | Noite 1 | Noite 10 |
|---|---|---|
| `Brightness` | 0,6 | 0,4 |
| `Ambient` / `OutdoorAmbient` | `#262B4A` / `#2A3058` | `#1E2240` / `#202546` |
| `Atmosphere` | Density 0,35 · Haze 1,5 · Color `#1E2448` · Decay `#0B0D1E` | Density 0,45 · Haze 2,2 |
| `ColorCorrection` | Saturation −0,20 · Contrast +0,08 · Tint `#D2DAFF` | Saturation −0,30 · Tint `#C8D2FF` |
| `Bloom` | Intensity 0,8 · Threshold 1,2 | igual |
| Postes que piscam (ambiente) | 0 | até 2 (nunca os da Juniper fora de anomalia, para não confundir com o Walker) |

Mínimo de leitura: um NPC parado a 15 studs fora de qualquer luz ainda mostra a silhueta contra o fundo (ambiente nunca abaixo de `#1B2140`).
O fim da Juniper precisa ser legível do trailer a até ~110 studs: o Walker só existe sob um poste aceso (o poste é a moldura dele).
**Exceção (rodada 17, decisão do usuário; número da DEC pendente no secretário):** os postes da Juniper ficam **a cada 8 studs** e o **último fica a ~135 studs** da janela; a regra de leitura vale até **~135** para a Juniper. Como a arte garante a leitura a 135 sem mudar nenhum valor aprovado acima:
- Silhueta do Walker e lâmpada do poste reforçadas nas fichas (AST-064, AST-036): forma pela silhueta, nunca por brilho no personagem.
- Postes a 8 studs dão uma fila contínua de lâmpadas; o "escuro entre as poças" vem de cone estreito, não de distância: poça de **~5–6 studs** de diâmetro com ~2–3 de escuro entre elas.
- Orçamento de luz (§5.1) mantido: **≤ 10** `SpotLight` nos postes. Os mais próximos do trailer e o poste onde o Walker está ganham luz real; os demais ficam só com lâmpada `Neon` + **decal de poça** no chão (círculo Cream translúcido, sem luz). O script troca qual poste tem luz real quando o Walker avança.
- Teste obrigatório antes de `Pronto p/ import` do AST-064: celular de tela pequena, noite 10 (névoa mais densa), Walker no último poste a ~135; tem que ser identificado como "figura alta parada sob a luz" em ≤ 2 s.
Amanhecer da noite 10 (FEAT-027): rampa de 6 s do valor da noite para o "dia bonito" com hora dourada, sol atrás dos prédios.

---

## 6. Materiais

| Uso | Material Roblox | Observação |
|---|---|---|
| Padrão (tudo com atlas) | `SmoothPlastic` + `TextureID` do atlas | um atlas por pack/projeto; instâncias com a mesma malha e textura são agrupadas pelo motor |
| Lâmpadas, letreiro aceso, faróis | `Neon` | só áreas pequenas |
| Vidro (vitrine, janela do trailer, para-brisa) | `SmoothPlastic`, Transparency 0,4–0,6, cor `#9FD3E8` | evitar `Glass` e vários transparentes sobrepostos (overdraw no celular). Vidro embaçado do long car: Transparency 0,15, cor `#5F6B80` |
| Piso de rua, calçada | MeshPart do kit com atlas | não usar `Terrain` no MVP (mapa pequeno, urbano) |
| `SurfaceAppearance` | **não usar no MVP** | memória; o estilo não precisa de PBR |

Proibido: textura de foto, normal map, ruído/sujeira pintada (o estilo é limpo; a "sujeira" da noite vem da luz).

---

## 7. UI e HUD (visual mínimo)

Interação é toda no mundo (DEC-015, DEC-066). A tela só mostra status. Exceções decididas: botão "Skip" com votos na cutscene (DEC-078) e oferta de reviver no spectate (DEC-092).

### 7.1 Tipografia e forma

- Títulos e números: fonte arredondada e grossa disponível no Roblox (sugestão: **Fredoka One**). Texto corrido: **Builder Sans** Bold.
- Painéis em "pílula": cantos de raio 50%, fundo `#2B2233` a 70% de opacidade, texto branco com contorno `#2B2233` de 2 px.
- Ícones: 2D chapados, contorno grosso, mesma paleta do §2. Ícones de comida são **renders dos modelos 3D** do jogo (consistência entre mundo, balão e hotbar). Folha em AST-071.
- Tamanho mínimo de texto no celular: altura equivalente a ~3,5% da altura da tela (relógio e dinheiro ~5%).

### 7.2 Layout (mobile primeiro)

| Elemento | Posição | Quando | Visual |
|---|---|---|---|
| Dinheiro da party | topo esquerdo, **abaixo** da barra superior do Roblox (respeitar o inset da topbar) | sempre | pílula com moeda + "$123"; ao ganhar, número pula (escala 1,15, 0,2 s) |
| Dia / Noite | logo abaixo do dinheiro | sempre | pílula "Day 3" com sol, ou "Night 2" com lua |
| Horário | topo centro | sempre | pílula larga "8:00 AM" (DEC-048) |
| Sanidade ("Sanity", provisório) | topo centro, abaixo do horário | só à noite (DEC-056) | barra de 30% da largura; cheia `#FFD45A` → vazia `#6A5ACD`; abaixo de 25 pulsa devagar. Sem vermelho, sem coração, sem caveira |
| Notificação | topo direito (DEC-063) | quando houver | cartão pequeno, some sozinho |
| Hotbar | rodapé centro (nativa, DEC-040) | sempre | não esconder |
| Botão de interagir (prompt custom) | inferior direito, perto do pulo | ao mirar um alvo | do AnimalPlane (DEC-066) |
| Legenda de ligação | faixa inferior, acima da hotbar | durante ligação | ícone do telefone do veículo + "Walt:" + uma linha; **sem retrato** (DEC-076) e sem botão de repetir (DEC-077) |
| "Skip" da cutscene | inferior direito | só em cutscene (DEC-078) | pílula "Skip (1/2)" com contador de votos |
| Spectate | rodapé, acima da hotbar | jogador caído (DEC-093) | rótulo "Watching: <nome>" + setas grandes para trocar de colega |
| Oferta de reviver | cartão central-inferior | spectate / janela de 10 s (DEC-092, DEC-094) | cartão Cream com ícone da ambulância e botão grande; na janela de 10 s, anel de contagem Mustard (sem vermelho, sem tique-taque alarmante) |

Zona livre: centro da tela e terço inferior direito (Tool na mão, alvo do prompt). Nenhum HUD ali.

### 7.3 UI no mundo

| Elemento | Visual |
|---|---|
| Barra de progresso da salsicha | `CookInterface` do AnimalPlane (laranja → verde), 0,8 × 0,15 stud, 1,0 stud acima da salsicha (DEC-015, DEC-029) |
| Balão de pedido do cliente | balão branco arredondado acima da cabeça; ícone base (pão + salsicha) + até 3 ícones de complemento em linha; borda vira **anel de paciência** que esvazia. Vazio = ANM-001 |
| Valor da gaveta | "$23" com moeda, acima da gaveta (DEC-050) |
| Reação do cliente | ícones originais: feliz (estrela), reclamação (nuvem rabiscada), irritado (vapor). Sem emoji de fonte |
| Barra do ladrão | mesma barra da salsicha, cor `#6A5ACD`, acima da gaveta; legível do Mart (billboard ≥ 130 studs, MAP-01 §6) |
| Falas em balão (Opal, Quentin, Raincoat Lady) | balão branco menor, sem ícone, 3 s |
| Preço na bancada de upgrades | etiqueta Mustard "$60" em cada vaga; vaga rara com moldura **Mustard** (DEC-144; era Gold) |

### 7.4 Telas

- **Fim de turno:** cartão central; letra da nota enorme (A `#F6C12B`, B `#5FA36A`, C `#3FA7B5`, D `#8A8FA3`; sem vermelho), linhas de faturamento, gemas do turno (já creditadas, DEC-104).
- **Ligação do chefe:** faixa inferior (§7.2). Walt só por telefone durante a run, sem retrato (DEC-076).
- **Noite perdida (DEC-053, emendada por DEC-122: todos acordam em pé ao lado do trailer, sem banco):** luzes do trailer piscam e apagam (no mundo) → fade preto → amanhecer.
- **Fim de run / final:** "You Kept the Light On" (FEAT-027), mesma linguagem do fim de turno, fundo do amanhecer.

---

## 8. Convenções técnicas para o modeler-3d

| Item | Regra |
|---|---|
| Unidade | 1 unidade do Blender = 1 stud. Antes do primeiro asset, exportar um cubo de 1 × 1 × 1 e conferir no Studio; ajustar o fator de exportação uma vez e registrar aqui |
| Eixos | frente do asset = lado que o jogador usa/vê. Pivô conforme a ficha: base-centro (props, estações, veículos), ponto de pegada (Tools) |
| Nomes de arquivo | `Assets/blender/<categoria>/AST-###_<Nome>.blend` → `Assets/models/<categoria>/AST-###_<Nome>.fbx` |
| Categorias | `food`, `equipment`, `vehicle`, `market`, `street`, `building`, `story`, `character`, `anomaly`, `vfx`, `ui` |
| Nomes de partes | PascalCase em inglês: `Body`, `Bun`, `Sausage`, `Fill`, `Lid`, `Door`, `Wheel_FL` |
| Encaixes | Attachments: `Att_Hand` (pegada), `Att_<Coisa>` (encaixe de peça, ex.: `Att_Topping`), `Mount_<Estação>` (vaga no veículo), `Prompt_<Ação>` (âncora do prompt), `Bar_<Nome>` (âncora da barra de progresso), `Light_<Nome>` (âncora de luz), `VFX_<Nome>` (âncora de partícula), `Seat_<Nome>`, `Hide_<N>` |
| Tool | peça raiz chamada `Handle`, com origem no ponto de pegada (`Att_Hand` coincide com ela); o `Grip` da Tool é ajustado no import para o item ficar no terço inferior direito em 1ª pessoa |
| Acessório R6 | malha com `Handle` e um Attachment com o **mesmo nome** do attachment R6 de destino (ex.: `HatAttachment`); usa o atlas do projeto |
| Estados | malha separada por estado só quando a forma muda (ex.: salsicha crua x grelhada; pão inteiro x mordido). Mudança só de cor = troca de UV/textura ou `Color` |
| Veículo | rodas como peças separadas (`Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`) com pivô no eixo; portas animáveis com pivô na dobradiça |
| Colisão | malha visual com `CanCollide = false` quando complexa; colisores invisíveis simples (Part) por cima. Props: `CollisionFidelity = Box`. Decorativo: `CanQuery`/`CanTouch` false |
| `RenderFidelity` | `Automatic` (LOD do motor). `Performance` para decorativo longe |

---

## 9. Orçamento técnico (mobile)

Valores iniciais, como **meta de Rascunho** (DEC-090: celular-alvo adiado; medir quando a otimização for feita, `Q-074`).
Alinhado com o MAP-01 §13 onde os dois documentos tratam da mesma coisa (vale o mais restrito).

### 9.1 Triângulos por categoria

| Categoria | Alvo | Teto |
|---|---|---|
| Comida / ingrediente (inclui Tool na mão) | 100–400 | 600 |
| Cobertura (malha que encaixa no hot dog) | 30–150 | 250 |
| Pacote do mercado / item raro (Tool) | 80–300 | 400 |
| Estação / equipamento | 400–1.200 | 1.500 |
| Peça visível de upgrade | 100–600 | 800 |
| Prop pequeno (copo, placa, interruptor, telefone) | 50–300 | 500 |
| Prop médio (banco, poste, hidrante, lixeira, caixote de frutas) | 200–800 | 1.200 |
| Carrinho, só a carroceria | 2.000–3.500 | 4.000 |
| Carrinho montado com todas as estações | — | 8.000 |
| Food Trailer, casca + interior, sem estações | 6.000–9.000 | 10.000 |
| Food Trailer montado com tudo | — | 16.000 |
| Peça modular de cenário (piso, parede, janela) | 12–300 | 600 |
| Fachada de prédio montada | 1.000–2.000 | 2.500 |
| Prédio de fundo ("cartão") | 50–300 | 400 |
| Carro de trânsito (cada) | 800–1.500 | 2.000 |
| Ambulância / long car / caminhão | 1.500–2.500 | 3.000 |
| NPC comum (R6 + acessórios) | 600–1.200 | 1.800 |
| Personagem com nome (Walt, Opal, Quentin, Raincoat Lady, Walker) | 1.000–2.000 | 2.500 |
| Acessório R6 isolado | 50–400 | 600 |

### 9.2 Cena

| Métrica | Alvo | Teto |
|---|---|---|
| Triângulos visíveis no quadro (1ª pessoa, no Pad) | 100 mil | 200 mil |
| Triângulos da cena inteira | 250 mil | 350 mil |
| NPCs humanoides simultâneos | 12 (DEC-045) | — |
| Carros de trânsito visíveis ao mesmo tempo | 4 | 6 (quantidade total com `Q-102`) |
| Malhas **únicas** (MeshId distintos) por mapa | 130 | 160 |
| Instâncias de MeshPart + Part no mapa | 2.500 | 3.000 |
| Draw calls (MicroProfiler) | 300 | 500 |
| Texturas de cor (atlas) | 3 | 4 |
| Memória de textura total | 24 MB | 30 MB |
| Partículas na tela | 100 | 150 |
| Emissores ativos perto da câmera | 4 | 8 |
| Luzes locais ativas (noite) | 14 | 18 (3 com sombra, §5.1) |

### 9.3 Texturas

| Tipo | Resolução |
|---|---|
| Atlas de cor do projeto | 512² |
| Atlas KayKit (reduzido) / Kenney | 512² / 512² |
| Folha de placas, letreiros e logos (AST-072) | 1024² (decals de mundo recortados por `Texture`/`SurfaceGui` quando preciso) ou 256² por placa |
| Panfleto (close-up da cutscene) | 512² |
| Rostos de NPC | 256² **cada** (Decal não usa folha) |
| Texto/logo de roupa (decal no tronco) | 128² cada; versão espelhada da ANM-004 é outro arquivo 128² |
| Foto de 1979 (pista) | 256² |
| Ícones de UI / hotbar | 128² cada, em folha 1024² (`ImageRectOffset`) |
| Partículas | 128² ou flipbook 4×4 em 512² |
| Textura de personagem animal (DEC-148; variante dia + noite, DEC-150) | **a definir pelo art-director** (`Q-144` g): resolução por peça, nº por animal/tipo, memória total dentro de §9.2 |

### 9.4 LOD e streaming

- LOD de malha: automático (`RenderFidelity = Automatic`). Não modelar LODs manuais, exceto prédios de fundo (cartão).
- Streaming é do architect (`Q-087`). Pedido da arte: Pad, trailer, Mart, banco, apartamentos e postes da Juniper sempre carregados (linha de visão de ~135 studs na Juniper, rodada 17, ANM-003, ANM-006, ANM-007); só o skyline de fundo pode descarregar.

---

## 10. VFX

Cartunizado, curto e "satisfatório" de dia; contido e ambiental à noite. Reaproveita `ReadyVFX` do AnimalPlane (DEC-029; template ainda não exportado, `Q-045`).

| Efeito | Gatilho | Visual | Orçamento |
|---|---|---|---|
| Salsicha pronta | grelha termina | `ReadyVFX` portado: rajada de 10 estrelinhas Mustard/branco + sino, 0,6 s | `Emit(10)` |
| Vapor da grelha | salsicha na grelha | 1 emissor por vaga ocupada, Rate 3, Lifetime 1,2 s | desligar em qualidade gráfica baixa |
| Molho | complemento aplicado | 6 gotinhas da cor do molho | `Emit(6)` |
| Pagamento | entrega completa | 4 moedas saltam até a gaveta + "+$7" subindo | `Emit(4)` |
| Gorjeta | +$1 | moeda dourada extra com brilho | `Emit(1)` |
| Upgrade instalado | compra na bancada | confete 14 peças na peça nova do veículo + "pop" de escala (0,9 → 1,05 → 1) | `Emit(14)` |
| Restock | pacote descarregado | lufada de poeira clara na estação | `Emit(5)` |
| "Nice catch!" | ladrão impedido | texto pulando + poeira na fuga | `Emit(6)` |
| Café pronto | cafeteira | 2 fiapos de vapor + sino suave | — |
| Item raro na bancada | vaga rara ocupada | 3 brilhos Gold lentos | Rate 1 |
| Atropelamento | carro x jogador (DEC-095) | anel de estrelinhas + 3 estrelinhas girando sobre a cabeça + poeira ao levantar (§4.6) | `Emit(8)` + 1 emissor |
| Item derrubado | DEC-103 | mini poeira | `Emit(3)` |
| Desmaio | sanidade 0 (DEC-091) | "Zzz" sobre a cabeça (visível aos colegas); para quem caiu, vinheta + fade | 1 emissor |
| Ambulância | chegada / saída | barra de luz Neon alternando Mustard/Teal; "poof" ao embarcar e ao reviver | `Emit(6)` |
| Mariposas no poste | noite | 2–3 partículas circulando cada poste aceso perto | Rate 1, só postes perto |
| Fumaça do hot dog (ANM-002, sabor) | servir comida errada | puff cinza claro, some em 0,8 s | `Emit(8)` |
| Pingos e poça (ANM-005) | Raincoat Lady presente | pingos azuis claros + decal de poça que cresce | Rate 4 |
| Chuva só no trailer (ANM-005, sabor) | erro | chuva em área de 14 × 16 sobre o trailer, 20 s | 1 emissor |
| Guardanapos (ANM-009, sabor) | erro | 6 guardanapos voando para dentro | `Emit(6)` |
| Névoa baixa (ANM-010) | Hush | camada de névoa a 1,5 stud do chão (partícula grande e lenta) + Atmosphere mais denso | 2 emissores |
| Sanidade baixa | < 50 / < 25 | vinheta escura (UI), saturação cai (ColorCorrection) | sem `Blur` grande; `Blur` ≤ 4 por ≤ 0,5 s |
| Vulto / alucinação | sanidade baixa (DEC-038) | silhueta escura **lisa** na visão periférica, some quando olhada | só client, 1 por vez |

Proibido em qualquer VFX: sangue, respingo vermelho escuro, fogo em pessoa, explosão, caveira, cruz de cemitério.

---

## 11. Áudio (direção mínima)

Seção a completar em rodada própria (README tema 13). Direção inicial:
- Dia: ukulele/xilofone leves, loop curto e alegre; SFX "plásticos" e redondos (pop, sino, chiado de grelha fofo); buzinas de trânsito curtas e engraçadas.
- Noite: mesma melodia do dia, **mais lenta e com notas faltando**; zumbido constante dos postes; tique-taque do relógio do banco (ANM-003 é o silêncio dele).
- Telefone do veículo (AST-042): toque de campainha antiga, próprio, nunca usado em outro lugar (a alucinação reaproveita o mesmo som).
- Atropelamento: "honk-honk" + "boing" (DEC-095); nada de batida realista.
- Ambulância: sirene curta de duas notas, volume baixo, entra e sai em fade (não é susto, DEC-005).
- Sinal de início do Walker (**DEC-123**): o último poste da Juniper zumbe — zumbido elétrico grave que **sobe** por **~2 s** e **para seco**, ouvido por todos da party. A alucinação do poste (sanidade < 40) pisca sem zumbir. Difere do zumbido constante dos postes normais. Passo do Walker: batida abafada e grave.
- Sustos sonoros só como consequência da sanidade baixa (DEC-038), com volume limitado; nada de grito.
- SFX do AnimalPlane a portar: `ChargeUp`, `ClickHover`, `Pop`, `Bell` (`Q-045`).

---

## 12. Checklist de revisão (art-director, ao receber do modeler-3d)

1. Escala em studs igual à ficha (±5%); pivô no lugar pedido; altura de trabalho 3,5 onde a ficha pede.
2. Tris dentro do alvo da categoria (§9.1); teto nunca.
3. Nomes de arquivo, partes e attachments conforme §8 (Tools com `Handle`; acessórios com o attachment R6 certo).
4. Atlas correto; nenhuma textura extra não prevista.
5. Silhueta legível a 10 studs (interativo) ou pela massa (decorativo); conferida em 1ª pessoa a 4,5 studs.
6. Todos os attachments e estados da ficha presentes.
7. Nada que lembre marca, logo, personagem de outra IP ou emblema protegido; nenhum traço reservado (§2.4) em asset normal.
8. Licença registrada em `credits.md` se veio de pack ou biblioteca.

Aprovado → ficha vai para `Pronto p/ import`. Reprovado → nota objetiva na ficha.
