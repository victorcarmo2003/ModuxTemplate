Status: Rascunho (Provisório)

# Thumbnails de anúncio, lote 2: 10 conceitos (16:9)

Autor: art-director, 2026-10-17. Público de 6 a 13 anos, mobile primeiro, terror **Mild** (DEC-172), sem sangue nem violência (DEC-023).
Base: `thumbnails-pesquisa-roblox.md`, `thumbnails-pesquisa-externa.md`, `thumbnails-conceitos.md` (T-04 a T-07), `design/features.md`,
`design/anomalies-v2-proposal.md`, `story/anomalies.md`, `design/upgrades.md`, `design/classes.md`, `design/npcs.md`.

Os IDs `T-##` são só rótulos deste documento, não são prefixo oficial do `CLAUDE.md`. Nada aqui foi aprovado pelo dono; as prioridades são recomendação do agente.

## 0. O que já existe e o que este lote cobre

Thumbs já feitas (não repetir a ideia):

| # | Já existe | Monstro | Protagonista |
|---|---|---|---|
| 1 | urso sorrindo, Walker atrás, dentro do trailer | Walker | urso |
| 2 | raposa correndo na rua noturna, carro comprido de faróis acesos atrás | carro comprido | raposa |
| 3 | Sorriso gigante na janela de serviço, cachorro escondido atrás do balcão | Sorriso | cachorro |
| 4 | fila de 3 clientes, o do meio com a cabeça virada 180° | cliente errado | — |
| 5 | gato escondido no corredor da loja de brinquedos, Rastejador na prateleira | Rastejador | gato |

Os 10 do lote 2. T-05 e T-07 já estão com o modelador e estão descritos em `thumbnails-conceitos.md`.

| Prioridade | # | Gancho | Feature que vende | Ameaça | Protagonista |
|---|---|---|---|---|---|
| 1 | T-08 | "Tem algo no teto" | família B, Sombra no teto (ANM-019) | Sombra | pinguim |
| 2 | T-09 | "Fica na luz!" | escuro e zonas de luz, sanidade (FEAT-020, FEAT-019, UPG-005) | olhos no escuro | hamster |
| 3 | T-10 | "Que nojo!" | modo de preparo + comida errada (FEAT-039, ANM-002) | cliente de olhos brancos | porco |
| — | T-05 | "Religa a luz!" (já em produção) | família C, falha de energia (ANM-020, UPG-014) | vulto | coruja |
| — | T-07 | "A cópia" (já em produção) | a cópia + batida na porta (ANM-004, DEC-247) | cópia | panda |
| 4 | T-11 | "Olha a câmera" | câmera de segurança (FEAT-040) | Rastejador no monitor | guaxinim |
| 5 | T-12 | "ESCONDE!" | família B: chefe no telefone + esconder nos fundos (FEAT-018, V2 §3.B) | sombra do Walker | sapo |
| 6 | T-13 | "Um café, rápido!" | co-op, sanidade, café (FEAT-019, FEAT-021, DEC-167) | Walker pequeno no fim da rua | macaco + coala |
| 7 | T-14 | "Corre pro letreiro!" | The Hush, postes apagando, Mart como abrigo (N10, FEAT-020) | escuro avançando | tartaruga |
| 8 | T-15 | "Vende de dia..." (controle fofo) | loop de venda, fila, pôr do sol (FEAT-009, FEAT-011) | um par de olhos numa janela | leão |

Espécies sem repetição entre si nem com as thumbs já existentes. Monstros: a Sombra é o único que nenhuma thumb mostrou ainda, por isso T-08 vem primeiro.
Walker e Rastejador voltam, mas só de forma indireta (sombra, monitor, figura pequena ao fundo), não como "monstro grande atrás do herói".

---

## 1. Regras de produção do lote (estilo aprovado pelo dono)

| Regra | Valor |
|---|---|
| Captura | cena montada no mapa real, luz real do Studio (`PointLight`/`SpotLight`/`SurfaceLight`), 1920 × 1080 |
| Pós | **só** blur leve nas bordas e vinheta suave. Sem outline, sem glow artificial, sem cel shading, sem duotone. O brilho dos olhos vem de `Neon`/`PointLight` pequeno na própria cena, não de pós |
| Herói | fofo, bem iluminado, na frente, rosto legível a **250 px** de largura |
| Monstro | escuro, olhos brancos brilhando, parcialmente escondido |
| Fundo | quente sutil **ou** frio com o herói integrado (rim light frio no herói) |
| Figuras | **máx. 3** (par de olhos solto conta como figura) |
| Zona segura | nada importante nos **15 % de baixo** (y > 918 px) nem nos 5 % laterais |
| Marca | boné vermelho e avental sempre visíveis e iluminados; algo de hot dog no quadro |
| Testes antes de entregar | reduzir para 250 px e olhar 1 s (quem, qual emoção, qual perigo); escala de cinza (herói precisa destacar); squint (2 a 3 massas) |
| Expressões | só as do rig: Normal, Happy, Smile, Sad, Stressed, Exhausted, Fainted, Skeptical, Angry, EyesWhite, Blank, EyesClosed. "Medo" = **Stressed** + pose |
| Proibido | sangue, faca, arma, corpo caído/desmaiado em destaque, gosma vermelha, vermelho-sangue como cor dominante, texto "SCARY"/"HORROR", qualquer elemento que o jogo não tem |
| Depois da captura | remover as pastas de cena, restaurar `Lighting` e câmera (memória do projeto) |

Convenção de direção nas descrições: "frente do trailer" = lado da janela de serviço, virado para a calçada; "fundos" = porta dos fundos e disjuntor.

---

## T-08 — "Tem algo no teto" (prioridade 1)

| Campo | Conteúdo |
|---|---|
| Gancho | "Ele não viu o que está em cima dele." A criança vê a mão descendo e quer avisar |
| Vende | família **B, Sombra no teto** (ANM-019, `anomalies-v2-proposal.md` §3.B; estreia na noite 9, §8.2). Também mostra o atendimento na janela (FEAT-011) |
| Cena e props | **frente do trailer, vista de fora**, à noite. Janela de serviço aberta e acesa; balcão externo com 1 hot dog grande (ketchup e mostarda) sendo entregue, sino de balcão. Teto do trailer recortado contra o céu escuro. Ao fundo, desfocado: 1 poste aceso e a fachada de um prédio |
| Personagens | **Pinguim** funcionário (boné vermelho, avental) **na janela, terço esquerdo-centro**, corpo inclinado para fora, as duas mãos estendendo o hot dog para a câmera (para o cliente). Expressão **Happy**, olhando para a câmera. **Sombra**: deitada de bruços no teto, **de cabeça para baixo** na borda da frente, só cabeça, ombros e **um braço longo** aparecendo; a mão de dedos compridos desce pelo batente direito da janela e para **a ~1 stud acima do boné**, sem tocar. Olhos brancos voltados para o pinguim |
| Câmera | **na calçada, na posição do cliente**, a ~1,5 m da janela, **baixa** (altura do balcão), inclinada ~20° para cima: pega o pinguim de frente e a borda do teto em cima. Contra-plongée leve deixa a Sombra maior |
| FOV | **40°** (comprime a distância teto–cabeça; a mão parece "logo ali") |
| Ponto focal | o **rosto feliz do pinguim** (terço esquerdo, altura de 40 % do quadro); segundo olhar: **olhos da Sombra** no terço superior direito, seguindo a linha do braço |
| Luz | **quente** de dentro: `PointLight` âmbar (≈ #FFB15A, Brightness 2, Range 10) sobre o balcão, banha o pinguim e o hot dog pela frente/baixo. **Frio** de fora: `SpotLight` azul-petróleo (≈ #6E9BD6) vindo de cima-direita (poste) recorta o contorno da Sombra e do teto. Olhos da Sombra em `Neon` branco com `PointLight` minúsculo (Range 1,5). A Sombra **não** recebe luz quente: o batente da janela é a fronteira quente/frio |
| O que fica escuro | céu, o corpo da Sombra (só silhueta + olhos), laterais do trailer, rua atrás. ~50 % do quadro escuro |
| Por que funciona a 250 px | duas massas fortes: retângulo quente da janela com o pinguim (branco e preto contrastam sozinho) e um traço escuro descendo da borda de cima com 2 pontos brancos. Olhar do pinguim para a câmera prende; o braço leva ao monstro |
| Risco de moderação | **baixo**. Cuidados: mão sem garras pontudas de lâmina, sem tocar o pinguim (evita leitura de "agarrar"); rosto da Sombra sem boca aberta |
| Variante B | troca só o olhar: pinguim **Stressed**, olhando para cima por cima do ombro (gaze cueing para o monstro). Testa "herói olha a câmera" × "herói olha a ameaça" (`pesquisa-externa` §5, item 4) |

## T-09 — "Fica na luz!" (prioridade 2)

| Campo | Conteúdo |
|---|---|
| Gancho | "Fora da luz, alguém está olhando." Ilha quente num mar escuro: a regra do jogo em uma imagem |
| Vende | **escuro e zonas de luz** (FEAT-020: fora de `LightZone` > 3 s perde sanidade), **sanidade** (FEAT-019) e o upgrade **Trailer Lights** (UPG-005, raio 18 studs) |
| Cena e props | **frente do trailer e calçada**, noite breu (ATM-2). Chão iluminado em **círculo** pela luz do trailer; fora do círculo, asfalto preto. Na borda do círculo: 1 mesa de piquenique meio na luz, meio no escuro. Hamster segurando um pacote de pães (volta do Mart) |
| Personagens | **Hamster** funcionário no **terço esquerdo**, em pé **exatamente na borda** do círculo de luz, um pé dentro, outro fora, abraçando o pacote de pães; corpo virado para o trailer, **cabeça virada para trás** olhando o escuro. Expressão **Stressed**. No escuro, terço direito: **dois pares de olhos brancos** em alturas diferentes (um alto, de Walker, a ~5 studs do chão; um baixo, de Rastejador, rente ao chão), sem corpo visível |
| Câmera | **alta, atrás e acima do trailer** (no teto, canto traseiro), olhando para a frente e para baixo ~40° (plongée): o trailer entra na borda esquerda, o círculo de luz ocupa o centro-esquerdo, o escuro ocupa a direita. Hamster a ~6 studs da câmera, grande o bastante para o rosto ler |
| FOV | **60°** (precisa caber trailer + círculo + escuro com os olhos) |
| Ponto focal | **rosto do hamster** na fronteira luz/escuro (terço esquerdo, ~45 % da altura) |
| Luz | **quente**: `SpotLight` âmbar (≈ #FFB866, Angle 70, Range 22) apontado para o chão a partir da marquise do trailer, cria o círculo de borda nítida. Rim light frio fraco (≈ #5A7FB8) da direita no hamster para integrá-lo ao azul. Olhos em `Neon` branco. Nada de luz ambiente: `Ambient`/`OutdoorAmbient` quase preto, `Brightness` baixo |
| O que fica escuro | tudo fora do círculo (≥ 55 % do quadro), corpos das ameaças |
| Por que funciona a 250 px | é o "notan" perfeito: um disco claro e uma massa preta; o hamster é a única figura na fronteira; 4 pontos brancos no preto leem mesmo borrados |
| Risco de moderação | **muito baixo** (nenhum monstro visível, só olhos) |
| Variante B | **mesmo enquadramento, luz apagada**: só a lanterna do hamster (cone branco-frio) apontada para o lado errado, olhos mais perto. Testa "seguro na luz" × "luz acabou" |

## T-10 — "Que nojo!" (prioridade 3)

| Campo | Conteúdo |
|---|---|
| Gancho | "Você serviria esse hot dog?" Humor nojento (barata, minhoca, gosma) + um cliente que sorri demais esperando |
| Vende | **modo de preparo focado** (FEAT-039, DEC-223: tábua, molhos, coberturas) e a **comida errada** (ANM-002, DEC-242 a DEC-246; descartar = certo, servir = ele agarra e o jogador desmaia) |
| Cena e props | **bancada de preparo dentro do trailer**, como na câmera do jogo. Na tábua: **hot dog grande** aberto com **salsicha cinza** e coberturas nojentas (1 barata, 2 minhocas, gosma **verde**); garrafa de ketchup e de mostarda ao lado; lixeira no canto direito da bancada. Atrás, a janela de serviço aberta (fora de foco) |
| Personagens | **Porco** funcionário **atrás da bancada, terço esquerdo**, segurando a garrafa de mostarda parada no ar, corpo recuando, focinho torcido. Expressão **Skeptical**. **Cliente** na janela, **terço direito superior**, levemente desfocado: civil tipo *night_shift*, rosto com **EyesWhite**, sorriso parado, mãos apoiadas no parapeito da janela |
| Câmera | **acima da bancada, do lado do cliente** (dentro do vão da janela, um pouco acima), olhando para baixo ~45° para a tábua e o porco. O hot dog nojento fica no primeiro plano, grande; o porco atrás dele; o cliente aparece na borda superior direita, próximo da câmera (fora de foco leve) |
| FOV | **55°** (o mesmo do modo de preparo; o quadro "parece o jogo") |
| Ponto focal | **o hot dog nojento** (centro-esquerda, ~45 % da altura, acima da faixa segura); segundo: cara do porco; terceiro: olhos brancos do cliente |
| Luz | **quente**: `PointLight` âmbar sobre a tábua (≈ #FFC070) deixa a comida apetitosa e o nojo legível; o porco recebe a mesma luz de baixo. **Frio**: `SpotLight` azul de fora da janela no cliente; olhos `EyesWhite` com `PointLight` minúsculo. Fundo do trailer em penumbra quente |
| O que fica escuro | teto e cantos do trailer, rua atrás do cliente |
| Por que funciona a 250 px | hot dog é forma única e reconhecível (marca do jogo); a gosma verde e a salsicha cinza contrastam com o pão laranja; nojo é emoção que criança lê em 1 s |
| Risco de moderação | **baixo**. Cuidados: só gosma **verde** (vermelha lê como sangue), insetos cartoon, sem faca na cena (DEC-242 tirou a faca), sem mão do cliente tocando o porco |
| Variante B | sem cliente: só o porco e o hot dog nojento em close maior (2 figuras). Testa "comida engraçada" × "comida + ameaça" |

## T-11 — "Olha a câmera" (prioridade 4)

| Campo | Conteúdo |
|---|---|
| Gancho | "O que está na tela está atrás dele." O monstro aparece no monitor, a porta real está às costas do herói |
| Vende | **câmera de segurança noturna** (FEAT-040, implementada na TASK-285; câmeras de rua, Mart e porta dos fundos) e o esconder da família B (Rastejador, ANM-017) |
| Cena e props | **interior do trailer, canto dos fundos**: monitor CRT na prateleira (assets de câmeras/disjuntor), mostrando a imagem da câmera da **porta dos fundos** com o **Rastejador** de quatro patas no chão (imagem com chiado de verdade: renderizar a cena da porta, aplicar o chiado só **dentro** do monitor). Atrás do guaxinim, a **porta dos fundos real**, fechada, com uma fresta de luz fria embaixo. Na bancada, um copo de café |
| Personagens | **Guaxinim** funcionário no **terço direito**, sentado/inclinado para o monitor, de 3/4 para a câmera, as duas mãos na borda da prateleira. Expressão **Stressed**, olhando o monitor. O **Rastejador só existe dentro da tela** |
| Câmera | **ao lado do monitor**, à esquerda, na altura do rosto do guaxinim, olhando para ele em 3/4: o monitor entra no **terço esquerdo**, em primeiro plano e virado ~35° para a câmera (a tela é legível); o guaxinim no terço direito; a porta dos fundos atrás dele, no fundo |
| FOV | **45°** |
| Ponto focal | **a tela do monitor** (Rastejador) no terço esquerdo; segundo: rosto do guaxinim iluminado pela tela; terceiro: fresta da porta |
| Luz | a tela é a fonte principal: `SurfaceLight` frio (≈ #8FC6E0) no monitor ilumina o rosto do guaxinim pela frente. **Quente** fraco: lâmpada âmbar distante no teto do trailer, só de contorno no boné e nas orelhas. Fresta da porta: `PointLight` azul baixo fora da porta, linha fina no chão |
| O que fica escuro | o resto do trailer, a porta (só a fresta), o teto |
| Por que funciona a 250 px | retângulo claro com moldura (monitor) é lido como "tela" mesmo pequeno; rosto azulado do guaxinim com máscara preta tem contraste natural; um só monstro, pequeno e enquadrado |
| Risco de moderação | **muito baixo** (monstro pequeno, dentro de tela) |
| Variante B | o monitor mostra a porta dos fundos **vazia**, e a porta real atrás do guaxinim está **aberta um dedo** com os olhos brancos do Rastejador no vão, rente ao chão. Testa "ameaça na tela" × "ameaça já aqui" |

## T-12 — "ESCONDE!" (prioridade 5)

| Campo | Conteúdo |
|---|---|
| Gancho | "O chefe gritou para esconder. Deu tempo?" Corrida para o esconderijo com a sombra do monstro chegando |
| Vende | família **B, esconder nos fundos** (`anomalies-v2-proposal.md` §3.B: luzes piscam, o chefe grita no rádio "ESCONDE!", 8–10 s para sair pela porta dos fundos e entrar no esconderijo) e as **ligações do chefe** (FEAT-018, telefone fixo do trailer) |
| Cena e props | **fundos do trailer, lado de fora**: porta dos fundos aberta (interior com luz piscando), caixotes e lixeiras formando o esconderijo, asfalto. Na parede lateral do trailer, iluminada pelo poste: a **sombra alongada do Walker** (chapéu, braços longos) projetada, vindo da esquina. Na porta aberta, pendurado no gancho, o **telefone** do trailer balançando no fio |
| Personagens | **Sapo** funcionário **no terço esquerdo**, agachado entrando atrás dos caixotes, uma mão puxando a tampa da lixeira, olhando por cima do ombro para a sombra. Expressão **Stressed**, olhos enormes. **Walker**: só a **sombra** na parede (terço direito) e, na quina do trailer, **meia cabeça com chapéu e um olho branco** espiando |
| Câmera | **atrás dos caixotes, baixa** (altura do sapo agachado), olhando ao longo da parede lateral do trailer em direção à esquina; a parede corre em diagonal do primeiro plano esquerdo ao fundo direito (linha guia) |
| FOV | **50°** |
| Ponto focal | **rosto do sapo** (terço esquerdo); a diagonal da parede leva à **sombra** e ao olho na quina |
| Luz | **frio** dominante: `SpotLight` branco-azulado (≈ #9DB8E8) do poste atrás do Walker, rasante na parede, projeta a sombra longa (usar `Shadows` ligadas e um modelo do Walker fora de quadro como "gobo"). **Quente**: a porta aberta joga luz âmbar (≈ #FFAA55) sobre o sapo (key). A lâmpada interna "piscando" = deixar a luz da porta mais fraca que o normal |
| O que fica escuro | o chão perto da câmera, os caixotes (silhueta), a rua, o Walker em si |
| Por que funciona a 250 px | sombra humana enorme numa parede clara é um ícone universal de "alguém vem vindo"; o sapo verde de boné vermelho é a única mancha saturada |
| Risco de moderação | **baixo**. Cuidados: a sombra sem dentes visíveis, braços abaixados (não "atacando") |
| Variante B | troca o monstro pela **Sombra no teto** só como silhueta em cima do trailer contra o céu. Não rodar ao mesmo tempo que T-08 (mesma ameaça) |

## T-13 — "Um café, rápido!" (prioridade 6)

| Campo | Conteúdo |
|---|---|
| Gancho | "Seu amigo está ficando estranho." Co-op fofo: um colega salva o outro com café, enquanto algo espera na rua |
| Vende | **co-op** (party de até 4), **sanidade** (FEAT-019; DEC-167: o rosto do personagem muda com a faixa), **café** (FEAT-021: preparar, entregar ao colega com "Give", +25) e a cafeteira (UPG-007/UPG-013) |
| Cena e props | **interior do trailer**, balcão com a **máquina de café** soltando vapor, caixa de pães, janela de serviço aberta para a rua escura. Ao fundo, pela janela, a Juniper: fileira de postes, o **último** aceso, com o **Walker pequeno** embaixo (é o sinal real dele no jogo, DEC-123) |
| Personagens | **Coala** funcionário, **terço direito**, debruçado no balcão, cabeça apoiada numa mão, skin **Mid** (pack da faixa média). Expressão **Exhausted**. **Macaco** funcionário, **terço esquerdo**, chegando pela esquerda com o braço estendido oferecendo um **copo de café fumegante** ao coala. Expressão **Happy**. Walker: figura de ~5 % da altura do quadro, na janela, entre os dois |
| Câmera | **dentro do trailer, de frente para a janela de serviço**, no nível do balcão, um pouco atrás e entre os dois (eles ficam de 3/4 para a câmera, de costas parciais para a janela) |
| FOV | **35°** (tele: comprime e puxa o Walker distante para perto das cabeças) |
| Ponto focal | **o copo de café** entre as mãos (centro-esquerda, ~45 % da altura); segundo: o rosto exausto do coala; terceiro: o Walker minúsculo na janela |
| Luz | **quente** dominante e aconchegante: `PointLight` âmbar no teto do trailer + luz verde-âmbar da máquina de café no copo e nos rostos. **Frio**: a janela é um retângulo azul-escuro; o último poste com `PointLight` branco-azulado no Walker; olhos do Walker em `Neon` |
| O que fica escuro | a rua toda, menos o último poste; cantos do trailer |
| Por que funciona a 250 px | duas figuras grandes e fofas, um gesto claro (dar algo); o retângulo escuro da janela com um ponto branco faz a pergunta "o que é aquilo?" |
| Risco de moderação | **muito baixo** |
| Variante B | trocar o café pelo **Rescue Whistle** (ITM-021, revive): macaco soprando o apito, coala de pé de novo com **EyesClosed** (sem corpo no chão). Só se o apito tiver modelo pronto |

## T-14 — "Corre pro letreiro!" (prioridade 7)

| Campo | Conteúdo |
|---|---|
| Gancho | "A rua está apagando atrás dele. Vai dar tempo?" Corrida contra a escuridão, com graça: o funcionário é uma tartaruga |
| Vende | **The Hush** (N10, `story/anomalies.md`; mantido na V2 §8.2 como roteiro da noite 10): postes apagam um a um, o letreiro "OPEN 24 HOURS" do Mart nunca apaga (FEAT-020). Também o **Mart** (FEAT-008) |
| Cena e props | **calçada entre a rua e o Mart**, vista **de lado**. À esquerda, a fachada do Mart com o letreiro aceso e a vitrine com gôndolas e pães. À direita, a rua com **4 postes em fila**: o mais perto do Mart aceso, os outros **apagados**, o último sumindo na névoa baixa (ATM-6, branca, não vermelha). Um pacote de café caído no chão atrás da tartaruga |
| Personagens | **Tartaruga** funcionária no **centro-esquerda**, de **perfil correndo** para a esquerda (para o Mart), passo largo, braços em movimento, **cabeça virada para a câmera**. Expressão **Stressed**. No escuro da direita, entre os postes apagados: **um par de olhos brancos** à altura de um adulto (vulto genérico, sem corpo) |
| Câmera | **do outro lado da calçada, lateral**, na altura do peito da tartaruga, eixo paralelo à fachada: o Mart na esquerda, a rua escura na direita, a tartaruga no meio da transição |
| FOV | **45°** |
| Ponto focal | **rosto da tartaruga** (centro-esquerda, ~45 % da altura); o gradiente luz → escuro da esquerda para a direita é a história |
| Luz | **quente** à esquerda: `SurfaceLight`/`PointLight` âmbar do letreiro e da vitrine (≈ #FFC46B) cobre a tartaruga pela frente-esquerda. **Frio** à direita: só a névoa azulada e um contra-luz fraco (≈ #5E7FAE) recortando o casco. Olhos em `Neon` |
| O que fica escuro | metade direita do quadro, postes apagados (só silhueta), céu |
| Por que funciona a 250 px | divisão claro/escuro em duas metades, figura única no meio; a tartaruga correndo é cômica e identificável pelo casco |
| Risco de moderação | **muito baixo**. Não usar a atmosfera vermelha (ATM-3/ATM-7) nesta thumb: vermelho dominante foge da regra do lote |
| Variante B | mesmo quadro com **névoa vermelha** só no fundo direito (desaturada, mais vinho que sangue), herói inalterado. Testa atmosfera; só sobe se passar no teste de cinza e na revisão Mild |
| Custo | médio-alto: montar a fileira de postes apagando e a névoa no ponto certo |

## T-15 — "Vende de dia..." (prioridade 8, controle fofo)

| Campo | Conteúdo |
|---|---|
| Gancho | "...e sobrevive à noite." Fofo e quente, com uma única pista estranha. Serve de **controle** no teste A/B (`pesquisa-externa` §5, item 1: "herói vendendo feliz") |
| Vende | o **loop de venda**: fila, pedido, entrega (FEAT-009, FEAT-010, FEAT-011, FEAT-041) e a virada para a noite (FEAT-003) |
| Cena e props | **frente do trailer ao pôr do sol**, céu laranja-rosado à esquerda virando azul-escuro à direita. Postes acendendo. Mesas de piquenique. No balcão, hot dog grande, ketchup e mostarda |
| Personagens | **Leão** funcionário na janela, **terço esquerdo**, segurando o **hot dog grande** com as duas mãos para a câmera, peito estufado, juba iluminada pelo sol. Expressão **Smile**. **Cliente** civil (*office*), **terço direito**, de costas 3/4 para a câmera, recebendo o hot dog, segurando uma nota. Na **fachada do prédio ao fundo, lado azul**: **uma janela escura com dois olhos brancos** |
| Câmera | **na calçada, atrás e à direita do cliente** (over-the-shoulder do cliente), altura do ombro, olhando para a janela do trailer; o prédio do fundo aparece por cima do teto do trailer |
| FOV | **50°** |
| Ponto focal | **o leão com o hot dog** (terço esquerdo); pista: olhos na janela do prédio, terço superior direito, pequenos |
| Luz | **sol baixo** (`Lighting.ClockTime` ≈ 18,2, cor laranja-rosada) vindo da esquerda: key no leão e no hot dog. Do lado direito, o céu já frio dá rim azul no cliente. Lâmpada âmbar do trailer acesa. Olhos com `PointLight` minúsculo, únicos pontos brancos do lado frio |
| O que fica escuro | pouco: só a fachada do prédio à direita e o interior da janela com os olhos (é a thumb mais clara do lote, de propósito) |
| Por que funciona a 250 px | cores quentes e saturadas (preferência infantil, `pesquisa-externa` §1), rosto grande e alegre, hot dog enorme; os olhos são bônus para quem olhar de novo |
| Risco de moderação | **nenhum** |
| Variante B | o mesmo quadro **de noite** (ClockTime 0, leão Stressed, os olhos agora na janela do trailer). Antes × depois em duas thumbs, uma variável (hora) |

---

## 2. Comparação e plano de teste

| # | Leitura a 250 px | Tensão | Fofura / marca | Mostra mecânica | Custo de cena |
|---|---|---|---|---|---|
| T-08 | alta | alta | alta | esconder (B) | médio: pose do braço da Sombra |
| T-09 | **muito alta** (notan) | média | média | luz e sanidade | baixo |
| T-10 | alta | média | **muito alta** (hot dog) | preparo + descartar | médio: coberturas na tábua |
| T-11 | média-alta | alta | média | câmera de segurança | médio: render da porta dentro do monitor |
| T-12 | alta | alta | média | esconder + chefe | médio-alto: sombra projetada |
| T-13 | média | baixa | **muito alta** | co-op, café, sanidade | baixo |
| T-14 | alta | média | alta (gag da tartaruga) | ponto seguro, Mart | médio-alto: postes e névoa |
| T-15 | alta | baixa | **muito alta** | loop de venda | baixo |

**Recomendação (Provisória):**
- Rodada 1 da Thumbnail Personalization (2 a 5 ativas): **T-08, T-09, T-10** contra a thumb (1) urso + Walker como controle. Três conceitos bem diferentes (monstro novo, composição de luz, comida).
- Rodada 2: **T-05, T-07, T-11, T-12** contra a vencedora da rodada 1.
- Rodada 3: **T-13, T-14, T-15** (tons mais leves) contra a vencedora. Se T-15 ganhar em QPTR, o público responde mais ao fofo do que ao susto e os próximos lotes mudam de rumo.
- Medir por **qualified play-through rate**, não por clique; não mexer nas variantes durante a rodada.

## 3. Critérios de aceite (de cada captura)

1. A 250 px, alguém que não conhece o jogo diz em até 3 s quem é o funcionário, onde está a ameaça e que tem hot dog.
2. Ameaça, prop e mecânica mostrados existem no build atual. Se algo for cortado do jogo, a thumb sai de rotação.
3. Sem outline, glow artificial, cel shading ou duotone; pós só blur de borda e vinheta.
4. Nada importante nos 15 % de baixo nem nos 5 % laterais; no máximo 3 figuras.
5. O herói destaca do fundo também em escala de cinza.
6. Nenhum item da lista "Proibido" (§1); passa na revisão Mild.

## 4. Pendências

- Sombra no teto (ANM-019), Rastejador (ANM-017) e Sorriso seguem com aparência em Rascunho. Se mudarem, T-08, T-11 e T-12 (variante B) mudam junto.
- T-13 variante B depende de existir modelo do Rescue Whistle (ITM-021).
- T-14 depende de o Hush continuar no roteiro da noite 10 na V2.
- Uso de texto sobre as thumbs (sim/não, quais palavras) continua sendo decisão do dono.
