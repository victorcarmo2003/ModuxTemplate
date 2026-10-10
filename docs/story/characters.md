Status: Rascunho

# Personagens

Autor: narrative-writer, 2026-10-08. Nada aqui é decisão.
Conciliado com DEC-106, DEC-111, DEC-113, DEC-114, DEC-122, DEC-124, DEC-126, DEC-130 (revoga DEC-120) e `consistency-report.md` (2026-10-08, NW-7, NW-8, NW-12, NW-24, NW-25).
Fichas `CHR-###` (personagens da história). NPCs de gameplay (tipos de cliente, ladrão como sistema, atores de anomalia) ganham `NPC-###`
em `docs/design/npcs.md` (game-designer); aqui fica o lado narrativo e a aparência para o art-director.
Visual geral: estilo **toy low-poly** (DEC-105), cores quentes de dia. **Todo personagem é R6** — NPCs (DEC-089) e jogadores (DEC-097).
Aparência pensada para R6: leitura por **silhueta, cor, chapéu e acessório**, não por detalhe de rosto ou dedo. Nada de sangue, ferida ou arma (DEC-023).

> **DEC-145 (2026-10-10):** o padrão de personagem do projeto é o **"HotDog Crew"** (`Assets/reference/customrig.png`): animais humanoides (cachorro, gato, coelho, raposa, urso, panda; tartaruga citada) em rig R6 custom, uniforme boné vermelho + avental vermelho com hot dog + camisa creme + calça preta. Conflita com CHR-002 ("usa o avatar Roblox do próprio jogador") e com a aparência **humana** de CHR-001 e CHR-003 a CHR-008. **Não decidido** quem vira animal → `Q-141`; logo do avental → `Q-143`. Até a resposta, as fichas abaixo não mudam.
>
> **DEC-146 (2026-10-10, fecha `Q-141`):** **CHR-002 (cada jogador) é um animal da HotDog Crew**, escolhido pelo jogador; **não usa mais o avatar do Roblox**. Os trechos de CHR-002 sobre "avatar do próprio jogador", "avental por cima" e "colegas veem os avatares" **não valem** (reescrita → narrative-writer). Animal = classe (DEC-147, `Q-145`). Clientes seguem humanos. **Personagens com nome (CHR-001, CHR-003 a CHR-006, CHR-008): não decidido → `Q-146`**; até lá, seguem humanos como abaixo.
>
> **DEC-148 a DEC-150 (2026-10-10):** a crew tem **textura** de roupa, rosto e pelagem (DEC-148). **Clientes e pedestres sem nome também são animais** (DEC-149, emenda DEC-146): o mundo deixa de ser misto para os NPCs comuns. Personagens com nome **seguem em `Q-146`** (Pickett e Raincoat Lady também dependem de `Q-147`). Variante de **dia fofa** e de **noite um pouco assustadora**, por textura (DEC-150; intensidade `Q-148`). Reescrita de CHR-002 e do mundo (`world.md`) → narrative-writer.

| ID | Nome | Papel | Aparece |
|---|---|---|---|
| CHR-001 | Walt Bramble | o chefe | **só por telefone** durante a run; em pessoa **uma vez**, na cutscene do amanhecer da 10ª noite (DEC-075, DEC-076) |
| CHR-002 | The Rookie | protagonista (cada jogador) | sempre |
| CHR-003 | Opal | atendente do Ninth Street Mart | dia e noite (DEC-079, confirmada em DEC-099) |
| CHR-004 | Quick Quentin | o ladrão do dia | dias 2+ (DEC-050) |
| CHR-005 | Mr. Pickett | o cliente regular | dias; noite 4 (ANM-004) |
| CHR-006 | The Raincoat Lady | a mais antiga do late crowd | noites 5+ (ANM-005); final |
| CHR-007 | The late crowd | nome coletivo das anomalias | noites 1–10 (`anomalies.md`, ANM-001–ANM-010) |
| CHR-008 | Bellmoor Rescue crew | médicos da ambulância | noites, quando alguém desmaia (DEC-091) |

---

## CHR-001 — Walt Bramble ("the Boss")

- **Papel**: dono do Bramble's Corner Dogs. Contrata o jogador, liga no começo de cada turno, dá as regras da noite (DEC-025). Arco de 5 estágios do GDD §9.
- **Como aparece**: **só voz, por telefone**, durante toda a run (DEC-076). Legenda "Walt". Sem retrato na ligação. A ligação **não se repete** (DEC-077).
  Em pessoa **uma única vez**: sai do Mart ao amanhecer da 10ª noite (`ending.md` §2.2). Nunca no modo dia infinito.
- **Motivação**: manter a luz da esquina acesa toda noite. Fez o turno da noite de 1979 até não aguentar mais; precisa de alguém que repare nas coisas. Gosta de verdade do jogador, e se sente culpado por não contar tudo.
- **Personalidade**: avô simpático, frases curtas, piadas de tio, chama o jogador de **"Rookie"** (em party, todos são "Rookie"; "you" serve para 1–4). Quando perguntado o que não quer responder: "Next question." Nunca grita. Fica mais sério noite após noite.
- **Voz (para texto e áudio)**: calma, rouca, ri baixo ("heh"). Começa animado (dias), fica hesitante (noites 4–6), sério e protetor (7–10).
- **Arco** (GDD §9): 1 "Good job today!" → 2 "You're doing great." → 3 "Can you cover the night shift?" → 4 "There's something you should know..." → 5 "Whatever you do, never..." Mapeamento por turno em `script.md` §2.
- **Aparência** (só na cutscene final, R6): homem de uns 70 anos, baixo, barriga redonda (malha de torso R6 arredondada), bigode branco grosso, boné de feltro vermelho com o logo do carrinho (salsicha sorridente), jaqueta de uniforme creme e vermelha desbotada, crachá de metal "WALT — NIGHT SHIFT". Óculos grossos. Dois copos de café.
- **Assets ligados**: telefone fixo do veículo (AST-042, mesma peça no carrinho e no trailer, toque próprio; todas as ligações da run, DEC-124, `world.md` §4.1); foto de 1979 no trailer; crachá antigo na gaveta (`ending.md` §3).

## CHR-002 — The Rookie (protagonista)

- **Papel**: o jogador. Usa o avatar Roblox do próprio jogador, forçado em **R6** (DEC-097); sem nome fixo, sem voz. Em party de 1–4, **cada jogador é um Rookie**; não existe líder dentro da run (DEC-067). Ninguém é "o protagonista" e os outros "ajudantes".
- **Câmera**: 1ª pessoa travada, padrão do Roblox, **sem braços** (DEC-039, DEC-097). Só a Tool aparece na mão. Nas cutscenes também em 1ª pessoa; cada um vê os avatares dos colegas (DEC-088).
- **Motivação** (DEC-003): arrumar dinheiro → comprar o trailer → entender a noite → terminar o turno e descobrir a verdade.
- **Arco** (vision §3): desempregado → funcionário → responsável pelo trailer → trabalhador noturno → sobrevivente. No final A1, recebe a oferta de herdar o turno da noite.
- **Aparência**: o avatar do jogador + **avental do Bramble's** por cima (vermelho e creme com a salsicha sorridente). Sugestão ao art-director: o avental é acessório aplicado na run, não substitui roupa do avatar.
- **Estados com leitura visual** (para art e animação):
  - **Atropelado** (DEC-095): ragdoll R6 cômico, estrelinhas girando sobre a cabeça, levanta e sacode a cabeça.
  - **Desmaiado** (DEC-091): cambaleia, senta e tomba de lado devagar; espiral de estrelinhas sobre a cabeça; nunca de bruços, nunca imóvel "assustador". Levado na maca pelos médicos (CHR-008).
  - **Revivido**: aparece em pé ao lado da ambulância, sacode a cabeça como quem acorda de um cochilo.
  - **Noite perdida**: todos acordam em pé na calçada ao lado do trailer, inclusive quem estava em spectate (DEC-111, DEC-113, DEC-122).
- **Detalhe de cutscene**: bolso vazio — uma mariposa sobe voando da borda de baixo da tela (piada visual, sem carteira nem gesto de mão, DEC-097) e balão "Empty. Again.". Em party, sai uma mariposa de cada um (`script.md` §1).

## CHR-003 — Opal (atendente do Mart)

- **Papel**: atendente do Ninth Street Mart, atrás do balcão do caixa, dia e noite (DEC-079, DEC-099). **Não vende**: ingredientes por prompt nas prateleiras (DEC-049), upgrades na bancada da parede do fundo (DEC-101). Opal é ambiente + **1 fala curta em balão por visita**, sorteada pela fase.
- **Motivação**: conhece o Walt há 40 anos. Sabe de tudo, fala quase nada.
- **Personalidade**: seca, gentil, curiosa. Faz palavras cruzadas.
- **Falas** (uma por visita, aleatória por fase; ≤ 70 caracteres):
  - Dia: "Mustard again? You're a mustard family." · "Walt's cart, huh? Good cart." · "Ketchup's on aisle two. Always has been." · "Back wall's got gear. Who stocks it? I don't ask." · "Look both ways out there. Twice." · "Cars won't wait for you, hon. Look first."
  - Ao sair do Mart (**proposta**, a confirmar; balão, 1ª saída de cada turno; a rota cruza a Juniper Sul, rodada 17): "Look both ways, Rookie."
  - Turno com Rescue Whistle na vitrine especial (DEC-100, DEC-129): "Something shiny in the glass case. Just saying."
  - Noite 1–3: "Night shift? Huh. Bring a jacket." · "Coffee's fresh. You'll want it."
  - Noite 4–6: "Two coffees tonight? Oh — never mind. Habit." · "Don't mind the windows upstairs."
  - Noite 7–10: "Sign's on. Sign's always on." · "If the lamps go out, you come here. Got it?"
  - Noite, depois que alguém da party desmaiou: "Rescue came by. Your friend's fine. Resting."
- **Aparência** (R6): senhora de uns 65 anos, cabelo grisalho num coque com lápis espetado, cardigã verde, colete do Mart, óculos pendurados numa corrente.
- **Por que existe**: dá pistas sem explicar (DEC-008), ensina o ponto seguro da N10 antes da hora, e aponta a bancada e o item raro sem ser vendedora.

## CHR-004 — Quick Quentin (o ladrão do dia)

- **Papel**: o ladrão de DEC-018/DEC-050. Só de dia, a partir do dia 2. Espreita visível, mexe na gaveta se ninguém está na zona do carrinho, foge com saco de moedas. Sem contato, sem briga.
- **Motivação**: guloso por moedas, não é malvado. Rouba e sai na ponta dos pés.
- **Personalidade**: cômico, exagerado, "vilão de desenho". Assobia fingindo que não está ali.
- **Falas** (balão, uma por evento):
  - Espreitando: "Nice day. Very nice. Not looking at anything." · "Just... waiting for a bus."
  - Pego (jogador entra na zona): "Whoops! Wrong drawer!" · "I was just admiring it!"
  - Fugindo com o saco: "Thanks for the tip!" · "See you tomorrow!"
- ~~**Aparência** (R6): magro e comprido, sobretudo cinza grande demais, chapéu de aba baixa, óculos escuros redondos, bigodinho fino, tênis muito brancos. Saco de pano com "$" costurado.~~ (substituída por DEC-159)
- **Aparência** (**DEC-159**, 2026-10-10): **guaxinim** da HotDog Crew (rig da crew, DEC-145/DEC-149). Mantém a aparência anterior, adaptada:
  - sobretudo grande demais **cinza-arroxeado `#7A6FB0`** e tênis muito brancos → textura `T_Civil_Thief_Day`;
  - chapéu de aba baixa → malha `AST-053_ThiefHat`;
  - óculos escuros redondos + bigodinho → textura de rosto `T_Expr_Thief`;
  - saco de pano com "$" costurado (AST-021).
  - **Só textura de dia**: nunca aparece à noite. Modelo em produção, não aprovado. Texto final → narrative-writer.
- **Pista leve**: o chefe comenta o ladrão no dia seguinte, sem ter estado lá ("Heard you caught Quentin. Nice.") — como ele sabe? (resposta implícita: Opal conta tudo.)
- Atropelamento de NPC: sem semáforo (DEC-130, revoga DEC-120); como NPC atravessa fica com `Q-129`, e `design/features.md` propõe que NPC nunca é atropelado. Fala **de reserva** (só entra se isso mudar em `Q-122` b / `Q-129`): "Not my day!"

## CHR-005 — Mr. Pickett (o cliente regular)

- **Papel**: cliente de dia que aparece **todo dia, mais ou menos no mesmo horário** (sugestão: 12:00 PM), para criar o padrão (GDD §14). O pedido dele é sorteado como de qualquer cliente (DEC-064); o que é fixo é a fala e a roupa.
- **Motivação**: almoço. Sempre com pressa, sempre educado.
- **Personalidade**: contador nervoso, pontual, gentil.
- **Falas**: chegada "Same as always, please! Well — whatever's good." · pagamento "Keep the change. No — wait. Okay, keep it." · noite "Couldn't sleep. Is the grill still on?"
- **Aparência** (R6): baixo, terno marrom, gravata-borboleta verde, **relógio de pulso grande no braço esquerdo**, maleta na **mão direita**, cabelo repartido à **esquerda**, camisa com bordado "PICKETT & SONS" no **peito esquerdo**. Tudo isso é proposital: a cópia da ANM-004 é espelhada (texto do bordado ao contrário). Em R6, o bordado e a maleta são os sinais legíveis; o resto é bônus.
- **Uso na noite**: na estreia da ANM-004 (noite 4), a primeira cópia é dele. Depois, qualquer cliente pode ser copiado.

## CHR-006 — The Raincoat Lady

- **Papel**: figura recorrente do late crowd e a única que se deve **atender** (ANM-005). Aparece no final (`ending.md` §2.2).
- **Motivação**: comer um hot dog quente numa esquina iluminada, como faz "há muito tempo". É a guardiã silenciosa do acordo.
- **Personalidade**: calma, sorridente, **olhos sempre fechados**, nunca fala no balcão; só faz um aceno com a cabeça. Ao receber o pedido, deixa uma moeda a mais.
- **Falas**: nenhuma no balcão. Um único balão, na estreia: "..." (três pontos) e, se o jogador a servir rápido, "Thank you, dear." (uma vez por noite).
- **Aparência** (R6): senhora pequena, capa de chuva **amarelo-vivo** com capuz, botas de borracha verdes, guarda-chuva fechado. **Pinga água numa noite seca** e deixa uma poça no chão. Rosto gentil e completo (contraste com ANM-001).
- **Regra de segurança**: nunca deve ser assustadora no visual. O estranho é a água, não ela.
- **Nome**: no jogo é só "the Raincoat Lady". No final A1, Walt a chama uma única vez de **"Marigold"** (`ending.md` §2.2); ninguém explica.

## CHR-007 — The late crowd (coletivo)

- **Papel**: nome que o chefe usa para tudo que aparece à noite e não deveria estar ali. Cada um tem ficha em `anomalies.md` (ID `ANM-###`, DEC-096).
- **Regra visual comum** (para o art-director): mesmo estilo toy low-poly e R6 dos clientes normais; o estranho vem de **um detalhe errado** (sem rosto, espelhado, molhado, parado demais, longe demais, comprido demais), nunca de gore ou deformação.
- **Nomes que o chefe usa** (texto de jogo): "the blank folks" (ANM-001), "the wrong food" (ANM-002), "the stopped clock" (ANM-003), "the copies" (ANM-004), "the Raincoat Lady" (ANM-005), "the wavers" (ANM-006), "the Walker" (ANM-007), "the long car" (ANM-008), "the knock" (ANM-009), "the Hush" (ANM-010).

## CHR-008 — Bellmoor Rescue crew (médicos da ambulância)

- **Papel**: dois médicos que chegam de ambulância quando um jogador desmaia por sanidade 0, **descem** e o levam na maca carregada à mão (DEC-091, DEC-114). Não são anomalia, não são ameaça: são **resgate**. No reviver, a ambulância volta e **ninguém desce** (DEC-091).
- **Motivação**: turno da noite, como o jogador. Já conhecem a esquina.
- **Personalidade**: calmos, gentis, rápidos. Um alto e um baixo (dupla de desenho).
- **Falas** (balão curto, só ao buscar; uma por evento): "Easy now. We've got you." · "Just a little nap. Up you go." · "Bellmoor Rescue, coming through!"
- **Aparência** (R6): uniforme **Teal** com faixa Cream (mesmas cores da ambulância), boné Teal, crachá redondo "BR". Maca Cream, carregada pelos dois. Nada de seringa, sangue ou equipamento médico realista. Ficha de asset dos médicos: pendente com o art-director (AD-2).
- **Ambulância** (AST-052; paleta de `art/style-guide.md`, Aprovado, DEC-126): **Cream com faixa Teal larga**, letreiro "BELLMOOR RESCUE", **barra de luz Mustard/Teal**, sirene curta e suave.
- **Regra de segurança**: a cena é de **cuidado**, não de acidente. Colegas que assistem devem ler "ele está sendo cuidado", nunca "algo terrível aconteceu".
