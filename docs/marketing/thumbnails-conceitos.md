Status: Rascunho (Provisório)

# Thumbnails de anúncio — 4 conceitos novos (16:9)

Autor: game-designer, 2026-10-17. Público: crianças de 6 a 13 anos, mobile primeiro (DEC-014), classificação **Mild** (DEC-172), sem violência (DEC-023).
Base: `docs/vision.md`, `docs/design/anomalies-v2-proposal.md` (V2: famílias A Recusar, B Esconder, C Religar a luz, D Sustos), `docs/story/anomalies.md` (histórico).

Referências de estilo que o dono aprovou em conversa (sem DEC):
- **(a)** urso funcionário sorrindo em primeiro plano, Walker escuro com olhos brilhando logo atrás, sem que o urso perceba;
- **(b)** gato escondido no corredor da loja de brinquedos, Rastejador espiando por cima da prateleira;
- **(c)** raposa correndo para a câmera numa rua noturna, carro comprido de faróis acesos atrás.

Os 4 conceitos abaixo **não repetem** o que essas três já mostram (Walker, Rastejador, carro comprido; urso, gato, raposa como protagonistas).
Cada um vende uma família diferente da V2 e usa outro funcionário.

| # | Nome de trabalho | Família / verbo que vende | Ameaça | Protagonista |
|---|---|---|---|---|
| T-04 | "Qual está errado?" | A · **Recusar** cliente errado | cliente de pescoço invertido na fila | coelho |
| T-05 | "Religa a luz!" | C · **Falha de energia** (disjuntor nos fundos) | vulto no escuro | coruja |
| T-06 | "Tem alguém na janela" | B · **Esconder** | O Sorriso na janela de serviço | cachorro |
| T-07 | "Quem bate é a cópia" | A + D · **A cópia** e **batida na porta** | dois clientes idênticos, um de olhos brancos | panda |

> Os IDs `T-04` a `T-07` são só rótulos deste documento (a, b, c = T-01 a T-03). Não são prefixo oficial do `CLAUDE.md`.

---

## 0. Regras comuns a todas as thumbs

| Regra | Valor |
|---|---|
| Resolução | 1920 × 1080, conferir legibilidade reduzida a **320 × 180** (tamanho de card no celular) |
| Elementos | **no máximo 3** focos: protagonista, ameaça, um prop que conta a mecânica. Resto é silhueta ou escuro |
| Rosto do protagonista | ocupa **≥ 12 %** da altura do quadro; expressão exagerada (olhos grandes, boca aberta), lida a 320 px |
| Regra dos terços | protagonista num terço, ameaça no terço oposto; ponto focal nunca no centro exato (o ícone do Roblox e o botão de play cobrem o centro e os cantos em alguns layouts) |
| Zona segura | nada importante nos **8 % de cada borda** e no canto inferior direito (selo/contador do Roblox) |
| Contraste | **quente** (laranja/âmbar 2700–3200 K: trailer, hot dog, letreiro) = seguro; **frio** (azul-petróleo 7000–9000 K, lua) = noite; **ameaça** = branco puro ou ciano-pálido brilhante nos olhos, nunca vermelho-sangue |
| Marca do jogo | todo quadro tem **algo de hot dog visível** (boné vermelho, avental, hot dog na mão, letreiro do trailer). Sem isso, vira "mais um jogo de terror" |
| Texto | opcional, **no máximo 2 palavras** em inglês (o jogo é em inglês, DEC-022), fonte grossa arredondada, contorno preto; nunca cobrindo rosto. Ex.: "DON'T SERVE!", "LIGHTS OUT!" |
| Estilo | toy low-poly (DEC-105), iluminação Future, profundidade de campo leve (fundo desfocado 20–30 %) |
| Pós | vinheta suave, saturação +10 % nos quentes, bloom leve nos olhos da ameaça e nas lâmpadas |
| Proibido em todas | sangue, faca, arma, dentes com sangue, corpo caído, grito em close de boca aberta da ameaça ocupando o quadro todo, texto "SCARY"/"HORROR"/"18+", qualquer personagem/logo/fonte de outro jogo, clickbait que não existe no jogo (Roblox recusa anúncio enganoso) |
| Verdade | toda ameaça e todo prop mostrado **existe no jogo** (V2). Se algo da thumb for cortado do jogo, a thumb sai de rotação |

---

## T-04 — "Qual está errado?" (Recusar)

| Campo | Conteúdo |
|---|---|
| Vende | família **A — cliente errado**: o loop básico de "olhar a fila e recusar o estranho". É o que a criança faz na noite 1 |
| Cena e props | vista de **dentro do trailer**, por cima do balcão de serviço; janela de serviço aberta emoldurando a fila na calçada. Balcão com 2 hot dogs prontos (ketchup e mostarda bem visíveis), sino de balcão, ticket de pedido. Fora: rua noturna com 2 postes acesos ao fundo, prédio desfocado |
| Personagens | **Coelho** funcionário (boné vermelho, avental) no **terço esquerdo**, em primeiro plano, de 3/4, segurando um hot dog estendido para a janela; expressão **"opa, peraí"**: sobrancelhas levantadas, olhos arregalados, boca em "o", mão livre parada no ar. **Fila** com 3 clientes animais: 1º e 3º normais e sorrindo (cachorro, ovelha); o **2º, no centro-direita, é o pescoço invertido** — corpo virado para o trailer, **cabeça virada 180°** olhando para trás, com a nuca para a câmera |
| Câmera | atrás-e-acima do ombro do coelho (over-the-shoulder baixo), altura do peito do coelho; distância: coelho em plano médio (cintura para cima), fila em plano americano |
| FOV | ~50° (achata um pouco a fila e deixa os 3 clientes do mesmo tamanho, reforça "igual, igual, diferente") |
| Ponto focal | a **nuca do cliente invertido**, alinhada ao terço direito, no cruzamento do olhar do coelho com a linha do braço estendido |
| Luz | **quente** de dentro do trailer (lâmpada sobre o balcão, âmbar) banha o coelho e os hot dogs; luz de **contorno azul-fria** da rua nos clientes. O cliente invertido recebe **menos** luz quente (um passo atrás da linha da fila) e um rim light ciano mais forte |
| O que fica escuro | laterais internas do trailer, céu, rua atrás dos postes; o rosto dos clientes normais fica em meia-luz quente (amigáveis), o invertido em azul |
| Gancho para criança | **jogo dos 7 erros em 1 segundo**: "um deles está errado… qual?" A criança acha sozinha e se sente esperta. Depois vem "e se eu der o hot dog pra ele?" |
| Evitar | rosto do invertido virado para a câmera com expressão assustadora (estraga o "achar"); mais de 3 clientes (no celular vira ruído); deformação de pescoço torcido realista (é giro limpo de 180°, sem pele torcida); hot dog fora do quadro |
| Variante B | troca a anomalia pelo **cliente sem rosto** (ANM-001): cabeça lisa, sem olhos nem focinho, **de frente** para a câmera, segurando uma nota de dinheiro **em branco**. Coelho com hot dog já quase entregue. Testa se "sem rosto" (mais limpo, mais estranho) bate o "pescoço invertido" (mais engraçado-estranho) em CTR |

## T-05 — "Religa a luz!" (Falha de energia)

| Campo | Conteúdo |
|---|---|
| Vende | família **C — falha de energia**: tudo apaga, só a lanterna; o funcionário vai aos fundos e segura o disjuntor |
| Cena e props | **fundos do trailer**, lado de fora, à noite: porta dos fundos aberta (interior escuro), **caixa do disjuntor** amarela com alavanca e um raio desenhado, presa na lateral do trailer. Chão de asfalto com uma lixeira e caixotes. Ao fundo, a rua com **postes todos apagados** (silhuetas) e o letreiro do trailer apagado e torto |
| Personagens | **Coruja** funcionária no **terço esquerdo**, corpo de lado, uma mão **puxando a alavanca** do disjuntor, a outra segurando a **lanterna** apontada para a frente (para fora do quadro, à esquerda); cabeça **virada para a câmera / para trás**, olhos enormes de coruja arregalados, penas da cabeça arrepiadas, boca em careta "estressada" (dentes cerrados). **Vulto** no **terço direito**, ao fundo, entre os caixotes: silhueta preta lisa da altura de uma porta, só os **dois olhos brancos** visíveis, levemente inclinada para a coruja |
| Câmera | baixa (altura do joelho da coruja), olhando levemente para cima; plano médio da coruja; vulto em plano geral ao fundo |
| FOV | ~65° (um pouco largo para caber disjuntor + vulto + escuro em volta, sensação de espaço aberto e perigoso) |
| Ponto focal | **mão da coruja no disjuntor** (o único objeto bem iluminado) → os olhos do vulto puxam o segundo olhar |
| Luz | quase tudo **frio e escuro**. Única fonte quente: **faísca/brilho âmbar** saindo da caixa do disjuntor iluminando a mão e o rosto da coruja por baixo. Cone da lanterna **branco-frio** indo para a esquerda (para longe do vulto: a criança vê o erro). Lua azul fraca recorta o contorno do trailer |
| O que fica escuro | o vulto (exceto os olhos), o interior do trailer pela porta, a rua inteira, o chão atrás da coruja. Pelo menos **55 % do quadro** em preto/azul-escuro |
| Gancho para criança | **"vira a lanterna!"** — a criança vê o que a coruja não vê e quer avisar; e **"vai dar tempo de religar?"** (a mão está no meio do puxão) |
| Evitar | vulto com garras, boca ou braços esticados; escuro demais a ponto de a coruja sumir no celular (testar a 320 px); lanterna apontando para o vulto (mata o gancho); mostrar barra de progresso/UI do jogo |
| Variante B | **dia-e-noite no mesmo quadro**: corte diagonal. Metade esquerda: trailer **aceso**, quente, fila feliz, coruja sorrindo servindo. Metade direita: **o mesmo trailer apagado**, coruja com lanterna na boca do disjuntor, vulto atrás. Vende o contraste "fofo → assustador" do pitch, menos tensão, mais informação |

## T-06 — "Tem alguém na janela" (Esconder)

| Campo | Conteúdo |
|---|---|
| Vende | família **B — algo vem vindo → esconder**, com o monstro **O Sorriso** (ANM-018), o único que é "só um rosto" e por isso lê muito bem pequeno |
| Cena e props | **interior do trailer**, câmera no fundo olhando para a janela de serviço. Primeiro plano: **chapa com salsichas** chiando (vapor), potes de ketchup/mostarda, balcão. A **janela de serviço inteira** é ocupada pelo **Sorriso**: rosto enorme, pálido, só vemos da altura dos olhos até o queixo, **sorriso largo demais** (dentes brancos retos, tipo teclas, sem sangue), olhos brancos redondos. Lâmpada do trailer **piscando** (meio acesa) |
| Personagens | **Cachorro** funcionário em primeiro plano no **terço esquerdo-inferior**, **agachado atrás do balcão**, de costas para a janela e de frente para a câmera; as duas mãos tampando a boca, olhos esbugalhados olhando de lado (para cima, em direção ao Sorriso), orelhas para trás, rabo entre as pernas. Expressão **assustado**. Ele está escondido, o Sorriso ainda não o viu |
| Câmera | baixa, quase no chão do trailer (altura do cachorro agachado), contra-plongée suave; plano próximo do cachorro, Sorriso preenchendo o fundo |
| FOV | ~40° (tele: comprime e faz o Sorriso parecer **gigante e perto** do cachorro) |
| Ponto focal | **o sorriso** (terço superior direito); o rosto do cachorro é o contraponto, no terço inferior esquerdo |
| Luz | **quente** dentro: lâmpada âmbar piscando + brilho alaranjado da chapa iluminando o cachorro por baixo. **Fria** fora: o Sorriso é recortado por luz **branco-azulada** de poste, os dentes e olhos com bloom leve. Linha do batente da janela separa quente/frio |
| O que fica escuro | teto do trailer, cantos, metade do corpo do cachorro (só o rosto e as mãos em luz), a rua por trás do Sorriso (preto) |
| Gancho para criança | **"faz silêncio!"** — esconde-esconde, o jogo que toda criança conhece. Pergunta implícita: "ele vai ver o cachorro?" |
| Evitar | dentes pontiagudos/de tubarão ou gengiva vermelha (fica além do Mild); Sorriso olhando direto para o cachorro (mata o suspense: ele procura, não achou); rosto do Sorriso com pele realista; cachorro chorando (tristeza afasta; queremos susto divertido) |
| Variante B | troca para **Sombra no teto** (ANM-019): mesmo interior, cachorro agachado olhando **para cima**, teto do trailer amassado com **marcas de passos** afundando a lata e uma **mão escura de dedos longos** aparecendo pela borda da janela de serviço, de cima para baixo. Testa "ameaça que você vê" (Sorriso) × "ameaça que você imagina" (Sombra) |

## T-07 — "Quem bate é a cópia" (A cópia + batida na porta)

| Campo | Conteúdo |
|---|---|
| Vende | a cópia (ANM-004: dois clientes iguais, roupa espelhada, olhos totalmente brancos, DEC-245) e a batida na porta dos fundos (ANM-009 / fluxo DEC-247): **não abra** |
| Cena e props | **corte dividido** do trailer visto **de cima e de lado** (como casa de bonecas, parede lateral removida): à esquerda, a **janela de serviço** com um cliente; à direita, a **porta dos fundos** com o **mesmo** cliente do lado de fora, punho levantado batendo. Dentro, no meio, o funcionário. Props: balcão com hot dog, porta com **olho mágico** e trinco, tapete "WELCOME" com o hot dog do logo, 3 linhas curtas de **"onomatopeia de batida"** desenhadas na porta (traços de movimento, sem texto) |
| Personagens | **Panda** funcionário no **centro-esquerda**, de pé entre as duas aberturas, corpo para a janela (segurando hot dog) mas **cabeça virada para a porta**, uma orelha para cada lado; expressão **confuso → assustado**: um olho mais aberto que o outro, boca torta. **Cliente original**: gato-laranja de camiseta com estampa de texto curto (ex. "HI"), sorrindo normal, na janela. **Cópia**: igual, na porta, estampa **espelhada** ("IH"), **olhos totalmente brancos**, sorriso parado |
| Câmera | lateral, um pouco elevada (~30° de plongée), estilo "corte de maquete"; plano de conjunto que mostra o trailer inteiro (largura do quadro = comprimento do trailer) |
| FOV | ~35° (quase ortográfico: leitura de diagrama, os dois gatos do mesmo tamanho para a comparação ser justa) |
| Ponto focal | os **olhos brancos da cópia** na porta (terço direito); o original serve de "gabarito" à esquerda |
| Luz | interior **quente** e aconchegante (lâmpada âmbar no centro, sobre o panda). Janela: luz **quente** do letreiro do trailer bate no gato original. Porta: luz **fria e baixa** vindo de baixo (poste distante) sobre a cópia, sombra longa da cópia projetada **para dentro** pela fresta da porta |
| O que fica escuro | a área fora da porta dos fundos (só a cópia e sua sombra), o teto, o chão fora do trailer à direita |
| Gancho para criança | **dupla charada**: "qual dos dois é o de verdade?" + "abre ou não abre?". A criança compara os dois gatos e acha a estampa invertida e os olhos |
| Evitar | a cópia com qualquer coisa nas mãos; porta já aberta (o gancho é a dúvida); legenda de fala (o "It's me" é de outra anomalia e não cabe no celular); mais detalhes diferentes que estampa + olhos (fica difícil) |
| Variante B | **sem o corte de maquete**: POV em 1ª pessoa de dentro do trailer olhando **pelo olho mágico** (moldura circular com distorção olho-de-peixe, FOV ~120° dentro do círculo): a cópia de olhos brancos colada ao olho mágico, sorrindo; no canto inferior esquerdo, fora do círculo, a **pata do panda** no trinco. Mais intimista e assustador, mas perde a comparação "dois iguais" |

---

## Comparação e recomendação

| # | Leitura a 320 px | Tensão | Fofura / marca hot dog | Ensina uma mecânica? | Diferença das (a)(b)(c) | Custo de cena |
|---|---|---|---|---|---|---|
| T-04 | alta (3 silhuetas, 1 diferente) | média | alta | sim, Recusar | total (dentro do trailer, sem monstro) | baixo: rig de cliente + `Neck.C0` |
| T-05 | média (risco de escuro demais) | alta | média | sim, Religar | total (fundos, escuro) | médio: vulto e luz pontual |
| T-06 | **muito alta** (um rosto enorme) | alta | alta (chapa, balcão) | sim, Esconder | média (esconder já aparece em b) | médio: modelo do Sorriso pronto |
| T-07 | média (pede comparar detalhes) | média | alta | sim, Recusar + não abrir | total | alto: corte de maquete exige remover parede |

**Recomendação (Provisória):** produzir primeiro **T-06** (maior chance de clique: um rosto gigante na janela + esconde-esconde é legível em qualquer tamanho) e **T-04** (a mais barata e a que mostra o loop real do jogo, com o hot dog em destaque). T-05 e T-07 entram na segunda leva de teste A/B do Roblox.
Para o teste: rodar **T-06 A × T-06 B** e **T-04 A × T-04 B** contra a thumb (a) como controle, ≥ 48 h cada ou ≥ 1.000 impressões por variante, comparar CTR e tempo médio de sessão (thumb que traz clique mas sessão curta está prometendo outro jogo).

## Critérios de aceite (de cada thumb entregue)

1. Em 320 × 180, uma pessoa que não conhece o jogo diz em até 3 s **quem é o funcionário**, **onde está a ameaça** e **que tem hot dog**.
2. A ameaça e o verbo mostrados existem na V2 (`anomalies-v2-proposal.md` §3) no build atual.
3. Nenhum elemento da lista "Proibido em todas" (§0); passa na revisão Mild (DEC-172).
4. Protagonista é funcionário animal com boné vermelho e avental; espécie diferente das três thumbs já aprovadas.
5. Nada importante nos 8 % de borda nem no canto inferior direito.
6. Pelo menos 40 % do quadro escuro e pelo menos uma fonte quente visível (contraste quente/frio).
7. A variante B difere da A em **uma** variável principal (ameaça, enquadramento ou composição), para o teste A/B ser interpretável.

## Pendências

- Uso de texto sobre a thumb (sim/não, quais palavras): decisão do dono.
- Os conceitos assumem os monstros da V2 como estão; ANM-017 a ANM-019 seguem com aparência em Rascunho. Se o Sorriso ou a Sombra mudarem, T-06 muda junto.
