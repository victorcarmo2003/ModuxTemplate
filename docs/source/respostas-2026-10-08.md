# Respostas do usuário — rodadas 1 a 12 (2026-10-08)

Fonte primária. Somente leitura. Transcrição fiel de fala (voz para texto); erros de transcrição preservados.
Respondeu às perguntas bloqueantes levantadas na leitura do GDD V1. Registro derivado: DEC-012 a DEC-029 em `docs/decisions.md`.

Notas de leitura (não alteram o texto):
- "aba de carne" = tábua de carne.
- "eco proximity prompt" = ProximityPrompt.
- "hambúrguer incompleto" = hot dog incompleto.
- "crescente introdutória" = cutscene introdutória.

---

> Sobre o servidor, na verdade, vai, ser um, vai ter um lobby onde até 5 jogadores podem jogar juntos. Tá, o limite vão ser 5 jogadores. E aí... Vai ser individual, né? Os servidores privados. Entrou no lobby, montou a party e foi pro jogo. Na verdade, reduz pra 4 jogadores. 4 é melhor, porque 5 é muito. Vai ser 4 jogadores, montou a party e foi pra dentro do jogo. O jogo vai ser em primeira pessoa, igual o Animal Hospital do Roblox, se quiser pode dar uma pesquisada. E o foco vai ser mobile, obviamente, né? Porque a gente vai pegar um elemento bem semelhante ao do Animal Hospital, que a interface em si, dentro do jogo, ela praticamente não tem interação. A gente vai utilizar tools, ou seja, ferramentas pra, do próprio Roblox nativo mesmo para interação. E as interfaces vão ser somente para mostrar alguns status, tipo sanidade, é, horário atual, qual é o shift que ela tá, né? no caso qual é a noite, o turno que ela tá, quanto de dinheiro ela tem, e no final do, dos turnos, né? quanto de dinheiro que ela fez vendendo as coisas e tal, e por aí vai. E o restante das coisas a gente vai tentar priorizar um pouco mais dentro do jogo. Então, por exemplo, ela vai colocar um cachorro quente e uma salsicha na grelha. Aí em cima da salsicha vai ter uma barra de progresso mostrando se ela tá pronta ou não. E aí ele vai clicar lá com o Proximity Prompt e vai fazer a coleta. Inclusive, eu já tenho um sistema de Proximity Prompt e um sistema de progressão de barra de cozinha em um outro projeto, que é esse daqui. C:\Users\hakor\Documents\ModuxGames\AnimalPlane Eu quero aproveitar, pegar esse sistema de barra de progresso aí e pegar também a, a, a partícula emitter na VFX. Eu acho bem legal fazer isso. Eu não sei se foi instanciado via script ou se a gente colocou fisicamente, né? Mas você me avisa aí que a gente pega e aplica lá sem problema nenhum. Ou então, se você conseguir fazer, o script pode fazer, a gente só lapida também, né? Então a gente ele fica bem cartunizado, bonitinho Sobre como ele monta o hot dog, é, a gente pode fazer por estação, Então, por exemplo, ele foi no estoque de hot dog deles, clicou, comprou proximity prompt, o hot dog automaticamente vai para a grelha. Ele já começa a grelhar. Aí ele pegou o hot dog que já estava pronto ali, clicou de novo no eco proximity prompt, o hot dog foi para a esteira, onde ele fica ali descansando, né? Aí ele pode iniciar a montagem ou acumular alguns hot dogs ali. E aí depois ele vai no pão, é, clica no pão, o pão vai para a tua aba de carne, aí na tua aba de carne o pão é cortado, e depois ele vai lá no hot dog, clica de novo, e hot, é, hot dog da esteira, no caso, né? Aí o hot dog da esteira vai para dentro do pão, e aí ele vai poder colocar os condimentos, os complementos ali, seja ketchup, mostarda, é, aí a gente pode colocar o sistema de mercado que eu comentei antes, né? A gente pode adicionar mais coisas, como por exemplo, queijo, é, ovos cozidos, a gente pode fazer um negócio paulista mesmo, sabe? Ovos cozidos, purê de batata, é, batata palha, uva passa e por aí vai, né? Que a gente vai aumentando o conforme a progressão do jogo. Então, tipo, ele vai melhorando o trailer dele, ele vai desbloqueando mais coisas, né? Tipo, chili, coisas também até da, da própria cultura americana mesmo, dos Estados Unidos, né? Não sei se eles colocam os cachorros quentes turbinados lá com bastante coisa, tipo catupiry e cheddar. Mas a gente vai implementando bastante coisa conforme a progressão do jogo. Ele vai desbloqueando mais recursos, vão vindo mais clientes, ele vai servindo mais coisas, né? Tendo o gerenciamento dos recursos dele, para não faltar ingredientes. Isso é o mais importante. Porque se faltar o ingrediente e o cliente pedir aquele ingrediente, ou ele entrega um hambúrguer incompleto e o cliente reclama, ele vai ter que sair correndo para comprar. E a gente pode des é, dar gatilho em alguns eventos assim, como por exemplo, um ladrão que estava ali na espreita só olhando, esperando ele sair. Ele consegue ver o ladrão, mas se ele precisar sair pelo mercado, o ladrão vai chegar e vai roubar o dinheiro dele. Por aí vai. Sobre o dia e a noite correr em tempo real, o jogador na verdade ele vai iniciar de manhã, tá? Ele vai trabalhar sempre de manhã. E aí mais pro meio assim, pro final do jogo, ele vai começar a pegar o turno da noite. Aí vai ter o sistema de anomalia. Como que ele vence o turno da noite? É só ele não cometer alguns erros. Por exemplo, vamos supor, vai chegar uma anomalia que vai ser um cara em um carro, com o vidro todo fumê. Quando chegar esse cara, ele tem que, por exemplo, sair correndo do, do, do carrinho de cachorro quente. Senão ele vai perder o jogo. O cara vai atirar nele, por exemplo. Algo assim, sabe? A gente vai colocar alguns gatilhos, alguns eventos específicos, ele só tem que se comportar da maneira correta, de acordo com cada evento. Esse do carro, por exemplo, eu não quero colocar porque eu acho que é muito violento para criança, né? Mas a gente pode fazer umas coisas parecidas com isso. E sobre quanto dura cada turno da noite, a gente pode colocar... É, sei lá, de, entre 20 a 30 minutos, vai. Tá bom. Entre 20 a 30 minutos. E a noite ela passa a ser obrigatória sim após o trailer. O chefe vai ligar para ele esporadicamente e vai solicitar para ele ficar no turno da noite. É, a minha intenção seria com que o player desbloqueasse o trailer a partir da quinta noite, né? Então ele vai jogando aí as primeiras noites, vai desbloqueando recursos, tá? E a partir da quinta noite ele consegue comprar o trailer. Mas se ele não comprar o trailer, né, o tutorial vai falar, ó, você pode comprar o trailer, compra o trailer. E aí se ele só ignorar o tutorial, né, não quiser comprar o trailer, a... tutorial não, né, vai ser mais uma notificação. Aí ele pode ficar jogando aquele modo ali infinitamente e tal, juntando mais dinheiro. E a gente pode fazer depois uma progressão nesse sentido aí, tá? Aí vai se divertir no, no jogo, não tem problema nenhum. Tem gente que não quer jogar o modo... De terror, vai querer só jogar o modo normal de jogar, eles podem continuar sem problemas. Até porque ainda terão recursos que ele precisará comprar. Então, dá para ele manter uma progressão ali ainda. No caso, o, o, o jogador ele é funcionário, ele não é dono. E o trailer... A, o carrinho de cachorro quente inicial é dado pelo chefe. E o trailer, no caso, vai ser concedido pelo chefe também. Porém, o jogador que vai comprar, só para ele ter uma sensação ali um pouco diferente. Tipo, ah, é, agora você pode ter um trailer. Bum, ele comprou o trailer ali, mas não foi o dinheiro dele, foi o dinheiro do chefe. Resumindo, vai ser mais ou menos isso, né? Não precisa explicar muito isso pro jogador, não. Não tem problema. Sobre como ele fica sabendo das regras da noite, na verdade o chefe vai ligar para ele, vai explicar. Quando tiver algum evento específico, ele tem que fazer tal coisa. E ele precisa memorizar isso. Aí conforme as noites estão passando, a gente vai adicionando mais as anomalias. Então começa com anomalia, ele aprende aquela anomalia e segue. Na próxima noite vai ter aquela anomalia e mais uma extra. Aí ele precisa memorizar aquela extra e seguir. Aí na próxima noite vai ter as duas anomalias passadas, mais uma anomalia nova. Ele precisa memorizar também e seguir. jogo ele vai ser totalmente em inglês, tá? É, inclusive comentários aqui do próprio código mesmo, a gente vai fazer tudo em inglês também. E a faixa etária do público, a gente pode colocar um infanto juvenil aí mesmo. Vou arrumar um emprego, na verdade vai ser uma cutscene, tá? Então, ele, eu vou fazer uma cutscene, ele vai estar andando pela cidade, vai ver um panfletinho de alguém contratando em um poste de luz que alguém está contratando pessoas para cuidar de uma carrinho de cachorro quente, aí ele vai ligar pro cara, vai se aplicar e aí vai começar o, o jogo. De fato, já começa aí, só vai ter uma crescente introdutória mesmo. Sobre o carrinho se mover, não, ele não se move, ele vai ficar na esquina de uma rua mesmo. Sobre quantas noites vão ter, é, vamos fazer com que tenham 10 noites no total.

---

## Rodada 2

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração.
Registro derivado: DEC-030 a DEC-038 em `docs/decisions.md`.

Perguntas a que respondeu (feitas pelo orquestrador):
1. Contradição DEC-011 (3–5 anomalias no MVP) x 10 noites com +1 anomalia/noite (Q-039).
2. Estoque cobra na hora ou é reabastecido no mercado? (Q-037)
3. Party: um carrinho para todos ou um por jogador? Dinheiro/progresso por jogador ou da party? Solo? Dono do save? (Q-031, Q-007)
4. Depois do trailer: só noite ou dia e noite alternados? (Q-033)
5. "A partir da 5ª noite" = 5º dia? Preço? (Q-032)
6. Sanidade: o que reduz, recupera, o que acontece em zero? (Q-034)

> vamos aumentar o numero de anomalias. O estoque é abastecido no mercado. um carrinho para todos. dinheiro e progressão global.  dá pra jogar solo, não tem save, apenas recompensas para offgame como gemas para comprar classes. após o trailer, turnos alternados. trailer a partir do 5o dia, sem preço definido. sanidade baixa causa terror psicológico como sons, sustos, vultos e alucinações.

---

## Rodada 3

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração.
Registro derivado: DEC-039 a DEC-043 em `docs/decisions.md`.

Perguntas a que respondeu (feitas pelo orquestrador):
1. Câmera: primeira pessoa travada ou padrão com zoom? (Q-052)
2. Itens: hotbar nativa ou mochila própria? (Q-053)
3. Nome do medidor de sanidade (evitar copiar o Animal Hospital). (Q-054)
4. Sanidade: o que reduz, o que recupera, o que acontece em zero? (Q-034)

> camera travada em 1a pessoa. hotbar nativas, nome da sanidade? como assim?. café recupera a sanidade. se zerar ele morre e perde (os outros continuam ou game over) sanidade cai ao ver anomalia, ao quebrar regras e ficar no escuro

---

## Rodada 4

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração.
Registro derivado: DEC-044 a DEC-056 em `docs/decisions.md`.

O que foi apresentado (pelo orquestrador): todo o `docs/design/proposals-round-1.md` (propostas do game-designer), item por item, com as recomendações:
1. §0.1 dois cenários de run (L e C, Q-047 aberta); §0.2 economia de referência (inclui teto de 12 NPCs simultâneos); §0.3 upgrades de referência.
2. Q-032 preço do trailer; Q-033 turno de dia e relógio; Q-037 estoque e mercado; Q-036 ladrão (com a gaveta do caixa).
3. Q-018 sem reputação + nota A–D; Q-015 dois tiers no MVP; Q-035 chances do chefe e derrota sem violência.
4. Q-013 sete verbos contra anomalia; Q-014 café + Trailer Lights; números de sanidade (só à noite, por jogador; −5 ver anomalia, −35 quebrar regra, −1/s escuro).

> aprovar tudo, quais perguntas restantes?

---

## Rodada 5

Fonte primária. Somente leitura. Transcrição fiel de fala (voz para texto), texto do usuário sem alteração.
Registro derivado: DEC-057 a DEC-066 em `docs/decisions.md`.

Perguntas a que respondeu (feitas pelo orquestrador): Q-047, Q-049, Q-050, Q-046, Q-017, Q-048, Q-038, Q-040, Q-051 e Q-054 (esta não foi entendida, pela segunda vez).

Notas de leitura (não alteram o texto):
- "Animal Plane" = projeto AnimalPlane do usuário (DEC-029).
- "estrutura longa" = cenário L de `design/proposals-round-1.md` §0.1.

> estrutura longa, o modo de dia infinito não acaba mas tem um achievement secreto com 100 dias, sim ele dá gemas, dinheiro e progressão são da party. 10 noites com 10 anomalias Não precisa definir quais vão ser as classes, mas eu pensei em classes como mais agilidade, cozinhar mais rápido, é, ter um rendimento um pouco maior quando entregar um pedido para um cliente, né? uma classe que dá mais dinheiro, uma classe que tem mais sanidade e por aí vai. Você pode criar umas recomendadas também para mim com base na temática do jogo. Sobre a monetização, é, depois a gente pode planejar as monetizações, não tem problema. Sobre a partida, é, se um cara sair de uma partida, o status dele fica salvo naquela partida ali. E aí se ele entrar novamente do jogo e quiser reconectar, dando continuidade naquela partida, ele pode também. Vai aparecer uma notificação na parte direita em cima da tela, mas por enquanto deixa como decisão e depois a gente planeja o HUD principal. As receitas, elas vão ser combinações livres mesmo, né? Conforme o NPC vai gerar um pedido aleatório e ele só vai montar mesmo. Com base nos ingredientes. Na décima noite a gente faz um final com revelação. Sobre o prompt a gente pega o do Animal Plane mesmo, não tem problema não. Sobre esse nome da sanidade, como assim nome da sanidade? Eu não entendi essa pergunta.

---

## Rodada 6

Fonte primária. Somente leitura. Transcrição fiel de fala (voz para texto), texto do usuário sem alteração.
Registro derivado: DEC-067 a DEC-072 em `docs/decisions.md`.

Perguntas a que respondeu (feitas pelo orquestrador):
1. Q-057 — regras de reconexão: todos saem, prazo, amigo novo entra, líder sai, relógio pausa.
2. Aprovação de `docs/design/proposals-round-2.md` (classes, gemas, economia de combinação livre), apresentada com 4 pontos: (a) classes com vantagem pequena, até ±12%, sem tocar regras do terror; (b) ingrediente a mais = pedido errado ($0), faltando = 50% arredondado para baixo; (c) 4 classes no MVP: Rookie, Runner, Line Cook, Night Owl; (d) prefixo `CLS-###` para classes.

Notas de leitura (não alteram o texto):
- "parte" = party.

> Se a parte inteira saiu, o jogo é encerrado. Só é possível reconectar caso fique pelo menos uma pessoa na partida. Um amigo novo não pode entrar em uma partida de andamento. Se o líder sair, não tem líder basicamente, né? A partida continua normalmente. Pode aprovar tudo

---

## Rodada 7

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração.
Registro derivado: DEC-073 a DEC-079 em `docs/decisions.md`.

Perguntas a que respondeu (feitas pelo orquestrador, a partir das fichas do narrative-writer em `docs/story/`), na ordem da numeração dele:
1. Aprova a lista das 10 anomalias (`docs/story/anomalies.md`, N1–N10, incluindo a troca de um "recusar" por "atender" na N5) e o final A ("The Light on the Corner", `docs/story/ending.md`)?
2. Regra crítica fixa (só N7, recomendado) ou rotativa?
3. Walt aparece em pessoa no final (variante A1) ou só por telefone (A2)?
4. O jogador pode ouvir a ligação do chefe de novo?
5. Cutscenes são puláveis? Como funciona em party?
6. Opal (CHR-003, atendente do Mart): seguir a recomendação do narrative-writer?

Notas de leitura (não alteram o texto):
- Resposta 1 cita só "a lista". O final A é lido como aprovado pela resposta 3 (A1 é variante do final A). Ver DEC-075.
- "em conjunto com 50% dos votos" = em party, a cutscene é pulada quando 50% dos jogadores votam por pular.

> 1. Aprovo a lista, 2. Sobre a regra crítica, pode seguir com o recomendado, 3. Walt aparece em pessoa mesmo, 4. Jogador não pode ouvir novamente, 5. Cutscene podem ser puladas e em conjunto com 50% dos votos, 6. Sobre o opal pode seguir o recomendado

---

## Rodada 8

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração. Duas mensagens.
Registro derivado: DEC-080 a DEC-085 em `docs/decisions.md`; pergunta nova `Q-078` (leitura ambígua da mensagem A).

### Mensagem A

Perguntas a que respondeu (feitas pelo orquestrador):
1. `Q-066` (architect P1): snapshot da run no MemoryStore no início de cada turno, TTL 15 min, mesmo roster, só para recuperar queda.
2. Aparentemente, o item 5 do game-designer (jogador desconectado e gemas do turno).

Notas de leitura (não alteram o texto):
- "cópia de 15 minutos" = snapshot da run com TTL de 15 min (`Q-066`, opção 1).
- "O ganho de gemas é em tempo real e manda pra data store": **ambíguo**. O orquestrador perguntou de volta: (A) gemas seguem por evento, creditadas e salvas no DataStore no instante do evento; ou (B) gemas por tempo jogado. Sem resposta. Registrado como `Q-078`, não como decisão.

> Pode guardar a cópia de 15 minutos. O ganho de gemas é em tempo real e manda pra data store

### Mensagem B

Perguntas a que respondeu (feitas pelo orquestrador a partir do game-designer, com recomendação):
1. XP e níveis fora do MVP?
2. Dinheiro sobrando depois de ~dia 8 no solo: aceitar no MVP; decoração do veículo com dinheiro numa atualização futura?
3. Anti-AFK: gemas de turno de dia só com ≥3 pedidos completos no turno?
4. Achievement "Day 100": somar dias de modo infinito de várias sessões (persistido por jogador)?
5. Jogador desconectado: relógio não pausa; gema do turno só para quem está no servidor no resumo; desconectado não conta para "todos fora"?

Notas de leitura (não alteram o texto):
- "pode somar o achievement então para dar 100 dias" = item 4 (soma entre sessões).
- "sobre o jogador desconectado, pode incluir isso também" = item 5, recomendação inteira.

> XP E níveis não são necessários, pode retirar. Pode aceitar o dinheiro sobrando no MVP sem problemas. Pode incluir a proteção afk, pode somar o achievement então para dar 100 dias. sobre o jogador desconectado, pode incluir isso também

---

## Rodada 9

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração. Uma mensagem escrita.
Registro derivado: DEC-086 a DEC-091 em `docs/decisions.md`; perguntas novas `Q-097` a `Q-107`.

Perguntas a que respondeu (feitas pelo orquestrador):
1. Onde o trailer funciona: esquina ou estacionamento (`Q-079`, MAP-01 §15 P1).
2. Trânsito no MVP: só carros parados ou carros andando (`Q-080`, P14).
3. Cutscene em 1ª pessoa? Na party, cada um vê a sua? (`Q-081`, P6).
4. Style guide: estilo "toy low-poly" e NPC R15 (`Q-072`).
5. Celular-alvo (`Q-074`).
6. Representação da queda com sanidade zerada (`Q-055`).

Notas de leitura (não alteram o texto):
- "O trailer pode ficar na esquina mesmo" = `Q-079` opção 1 (recomendada).
- "faremos carros andando" = `Q-080`: trânsito com carros andando no MVP. **Oposto** da recomendação do level-designer (só carros parados).
- "Cutscene é em primeira pessoa e cada jogador vê um ao outro" = POV; na party a cena é compartilhada e os avatares dos outros jogadores aparecem.
- "Npcs vão ser R6 mesmo" = NPCs com rig R6 (o art-director recomendava R15). O estilo "toy low-poly" **não** foi respondido.
- "Não me preocupo com celular minimo, essas coisas otimizamos depois" = `Q-074` adiada, não bloqueante.
- Sanidade zerada: desmaio → corpo cai → médicos chegam de ambulância e levam o corpo → pode pagar para reviver (ambulância volta, para em frente, ele aparece ao lado, ambulância vai embora, sem paramédicos descendo) → se não pagar, fica em spectate. Fecha `Q-055` e emenda DEC-053 (banco do trailer).
- Não respondido nesta rodada: gemas A/B (`Q-078`), estilo toy low-poly e iluminação (`Q-072`), braços em 1ª pessoa (`Q-073`), prefixo `ANM-###` (`Q-063`), membro que não chega em 60 s (`Q-071`), confirmação da Opal (DEC-079).

> O trailer pode ficar na esquina mesmo. sobre o transito, faremos carros andando. Cutscene é em primeira pessoa e cada jogador ve um ao outro. Npcs vão ser R6 mesmo. Não me preocupo com celular minimo, essas coisas otimizamos depois. Quando a sanidade zera o jogador desmaia o corpo dele cai, médicos vem de ambulancia e pegam o corpo dele, ele pode pagar para reviver e a ambulancia volta, para em frente e ele spawna ao lado da ambulancia e ambulancia vai embora (sem paramedicos descendo nem nada), do contrário ele fica de spectate.

---

## Rodada 10

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração. Uma mensagem escrita.
Registro derivado: DEC-092 a DEC-099 em `docs/decisions.md`; perguntas novas `Q-108` a `Q-114`.

Perguntas a que respondeu (feitas pelo orquestrador):
1. Reviver: moeda, preço, quem não paga, todos caem (`Q-097` a `Q-100`).
2. Carros atropelam? (`Q-101`).
3. Prefixo `ANM-###` (`Q-063`).
4. Braços em 1ª pessoa (`Q-073`).
5. Membro que não chega em 60 s (`Q-071`).
6. Confirmação da Opal (DEC-079).

Notas de leitura (não alteram o texto):
- "O revive é pago com robux" = developer product. Primeira monetização definida (`Q-017` deixa de ser totalmente adiada). **Oposto** da recomendação (dinheiro da run).
- "raramente na loja é vendido um item de reviver bem caro" = item de reviver raro e caro numa loja do jogo. Loja, moeda, frequência, preço e uso: em aberto.
- "Quem não paga fica só assistindo e não volta mais" = spectate até o fim da run. **Oposto** da recomendação (volta no próximo turno).
- "Todos caem a noite, 10 segundos é o tempo limite para reviver, caso contrário todos perdem" = janela de 10 s. "Todos perdem" ambíguo: noite (chance do chefe) ou run.
- "O carro pode atropelar sim [...] ragdoll [...] continuam andando normal depois de um tempo no chão" = atropelamento com ragdoll, sem morte. **Oposto** da recomendação (carro freia).
- "Prefixo ANM para anomalias" = `Q-063` opção 1.
- "sem braços em 1a pessoa, vamos usar o padrão do roblox mesmo em 1a pessoa R6" = sem viewmodel; câmera 1ª pessoa padrão; jogador R6.
- "Quem não chega em 60s não fica de fora [...] ele apenas spawna depois" = run começa; o atrasado entra quando chegar. **Oposto** da sugestão do architect.
- "Não sei oq é o opal, qo seria ele? pode ser o recomendado." = o orquestrador explicou (atendente do Mart, CHR-003, fala curta, não vende); aprovado o recomendado. Confirma DEC-079.
- Não respondido nesta rodada: gemas A/B (`Q-078`), estilo toy low-poly e aprovação do style guide (`Q-072`).

> O revive é pago com robux, porém raramente na loja é vendido um item de reviver bem caro aonde eles podem pagar e revivar um player. Quem não paga fica só assistindo e não volta mais. Todos caem a noite, 10 segundos é o tempo limite para reviver, caso contrário todos perdem. O carro pode atropelar sim, eles são arremessados em ragdoll mas continuam andando normal depois de um tempo no chão. Prefixo ANM para anomalias, sem braços em 1a pessoa, vamos usar o padrão do roblox mesmo em 1a pessoa R6. Quem não chega em 60s não fica de fora, a partida inicia normalmente e ele apenas spawna depois. Não sei oq é o opal, qo seria ele? pode ser o recomendado.

---

## Rodada 11

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração. Uma mensagem escrita.
Registro derivado: DEC-100 a DEC-105 em `docs/decisions.md`; perguntas novas `Q-116` a `Q-123`.

Perguntas a que respondeu (feitas pelo orquestrador):
1. Item raro de reviver: loja, moeda, hotbar (`Q-108`).
2. "Todos perdem" depois dos 10 s: noite ou run (`Q-109`).
3. Espectador volta ao lobby mantendo gemas (`Q-110`) — **não respondida** diretamente.
4. Atropelamento: sanidade e item da mão (`Q-111`).
5. Gemas A/B (`Q-078`).
6. Estilo "toy low-poly" (`Q-072`).

Notas de leitura (não alteram o texto):
- "O item de reviver aparece na loja normal do jogo aonde se compram ingredientes e upgrades" = item raro na loja do **Mart** (mesma loja de ingredientes e upgrades). Moeda **não dita**; leitura do secretário = dinheiro da party na run (é a moeda dessa loja). Pendente de confirmação (`Q-118`).
- "no mercado vai ter a pareteleira e lugar de frutas / verduras e no fundo vai ter uma loja na parede uma bancada aonde tem upgrades" = layout novo do Mart: prateleiras, área de frutas/verduras, **bancada de upgrades na parede do fundo**. Muda onde se compram upgrades (antes: sugestão de prompt no próprio equipamento, `Q-084`, MAP-01 §15 P5).
- "todo novo turno, os itens ali atualizam" = a oferta da bancada **rotaciona a cada turno**. Escopo da rotação em `Q-116`, `Q-117`, `Q-120`.
- "O item fica guardado na hotbar" = item de reviver é Tool consumível na hotbar.
- "A party perde a noite inteira se não reviver após os 10 segundos" = `Q-109` opção A: perde a noite (gasta chance do chefe), não a run.
- "o atropelamento pode derrubar o item da mão e não retirar sanidade" = derruba o item; não tira sanidade (recomendação aceita).
- "gemas salvas a cada evento" = `Q-078` opção A.
- "visual low poly aprovado" = estilo "toy low-poly" aprovado. Não aprova o `style-guide.md` inteiro nem a iluminação Future.
- Não respondido nesta rodada: `Q-110` (dada como resolvida por consequência da opção A de `Q-078`), iluminação e aprovação do style guide, retorno de espectadores na noite repetida.

> O item de reviver aparece na loja normal do jogo aonde se compram ingredientes e upgrades. no mercado vai ter a pareteleira e lugar de frutas / verduras e no fundo vai ter uma loja na parede uma bancada aonde tem upgrades e todo novo turno, os itens ali atualizam. O item fica guardado na hotbar. A party perde a noite inteira se não reviver após os 10 segundos. o atropelamento pode derrubar o item da mão e não retirar sanidade. gemas salvas a cada evento, visual low poly aprovado

---

## Rodada 12

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração. Uma mensagem escrita.
Registro derivado: DEC-106 a DEC-109 em `docs/decisions.md`; pergunta nova `Q-124`.

Perguntas a que respondeu (feitas pelo orquestrador):
1. Bancada de upgrades no Mart: upgrades básicos (Grill, Cooler, Counter, luz, trava, cafeteira) sempre à venda; só especiais (ex.: revive) no sorteio de cada turno; Food Trailer fixo a partir do dia 5 (`Q-116`, `Q-117`).
2. Item raro de reviver pago com dinheiro da party na run? Apresentado como **suposição** ("suponho... confirma?") (`Q-118`).
3. Frutas/verduras no Mart: só cenário no MVP; cebola/pickles numa atualização (`Q-119`).

Notas de leitura (não alteram o texto):
- "pode seguir com os recomendados" = aprovação **em bloco** das recomendações das três perguntas.
- Pergunta 1 = `Q-116` opção A + `Q-117` (trailer fora da rotação, fixo a partir do dia 5).
- Pergunta 2 = leitura do secretário confirmada (dinheiro da party). Não tinha opções com recomendação; aprovada junto, em bloco.
- Pergunta 3 = `Q-119` opção A.
- A pergunta 1 listou "cafeteira" entre os básicos à venda; por DEC-055 ela é fixa no trailer. Não tratado como mudança de regra; registrado em `Q-124`.
- Não perguntado nesta rodada: `Q-121`, `Q-123`.

> pode seguir com os recomendados

---

## Rodada 13

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração. Duas mensagens escritas.
Registro derivado: DEC-110 e DEC-111 em `docs/decisions.md`; perguntas novas `Q-125` e `Q-126`.

Pergunta a que respondeu (feita pelo orquestrador):
1. Espectador permanente (DEC-093) volta a jogar quando a noite perdida é repetida? Recomendação do orquestrador: **não** (`Q-121`).

Entre as duas mensagens, o orquestrador explicou: pelas "chances do chefe" (DEC-053; run longa = 3 chances, DEC-057), perder uma noite gasta uma chance e a mesma noite recomeça do início, com dinheiro/estoque do início dela; sem chances, a run acaba.

Notas de leitura (não alteram o texto):
- "eles só tem uma única chance nesse caso" = **chances do chefe = 1**. Leitura do secretário: **1 por run** (a party pode repetir uma noite perdida uma única vez na run; perder de novo = fim da run). Leitura alternativa: 1 por noite (cada noite pode ser repetida uma vez). Confirmação em `Q-125` (não bloqueante).
- "e sim todos voltam" = na noite repetida, **todos voltam a jogar**, inclusive espectadores permanentes (DEC-093). `Q-121` fechada **contra a recomendação** do orquestrador ("não").
- "todos" lido de forma literal: inclui quem caiu em noite **anterior** (não só na noite perdida). Confirmação em `Q-126` (b).
- Não dito: se a noite é **vencida**, o espectador segue espectador até o fim da run (DEC-093 como está)? → `Q-126` (a).
- `Q-124` (cafeteira): o orquestrador recomendou "fixa no trailer" e disse que, se o usuário concordasse, não precisava responder. O usuário **não comentou**. Silêncio não é decisão: `Q-124` segue aberta.

> Como assim quando repete uma noite perdida?

> Ah, eles só tem uma única chance nesse caso, e sim todos voltam

---

## Rodada 14

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração. Uma mensagem escrita.
Registro derivado: DEC-112 e DEC-113 em `docs/decisions.md`; `Q-125` e `Q-126` fechadas. Nenhuma pergunta nova.

Perguntas a que respondeu (feitas pelo orquestrador):
1. `Q-125`: a chance única do chefe (DEC-110) vale para a **partida inteira** (run) ou **por noite**?
2. `Q-126` (a): se a party **vence** a noite, o espectador volta no turno seguinte ou segue assistindo até o fim da run?

Notas de leitura (não alteram o texto):
- "sim, partida inteira" = 1 chance por **run**. Confirma a leitura de DEC-110.
- "party" na resposta 2 = o **espectador** (jogador caído). Leitura do orquestrador, aceita pelo secretário.
- "party não volta no turno seguinte" = noite vencida **não** devolve o espectador. Confirma DEC-093 como emendada por DEC-111.
- "somente se todos perderem e dai ele usa a chance e todos voltam" = só a repetição da noite perdida devolve. "Todos voltam" responde também `Q-126` (b): inclui quem virou espectador em noite **anterior**. Confirma a leitura de DEC-111.
- `Q-124` e `Q-123`: não perguntadas nesta rodada.

> 1. sim, partida inteira. 2. party não volta no turno seguinte, somente se todos perderem e dai ele usa a chance e todos voltam

---

## Rodada 15

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração. Uma mensagem escrita.
Registro derivado: DEC-114 a DEC-129 em `docs/decisions.md`; fechadas `Q-022`, `Q-025`, `Q-028`, `Q-044`, `Q-076`, `Q-105`, `Q-123`, `Q-124`; parciais `Q-058`, `Q-102`, `Q-104`, `Q-106`, `Q-107`, `Q-112`, `Q-113`, `Q-120`; nova `Q-127`.

Tabela a que respondeu (feita pelo orquestrador; cada item com recomendação):
1. Ambulância na ida: **médicos descem e pegam o corpo** (como DEC-091) x **maca automática** (proposta do art-director, AST-052). Na volta do reviver, ninguém desce (DEC-091).
2. Quem cai pode ser revivido até **6:00 AM** daquela noite; depois vira espectador (game-designer, FEAT-034). Recomendação: sim.
3. Reviver com Robux **só para o próprio jogador**. Recomendação: sim.
4. Recibo de Robux que não dá para aplicar vira **crédito de reviver** guardado no perfil (architect D1). Recomendação: sim.
5. Janela de 10 s **congela até +20 s** enquanto alguém está com o prompt de compra aberto (architect D2; emenda leitura de DEC-094). Recomendação: sim.
6. Retomada de 15 min vale também para **queda do servidor** (architect D3). Recomendação: sim.
7. **Semáforo com faixa de pedestre** na travessia trailer ↔ Mart e nos cruzamentos (architect D4). Recomendação: sim.
8. Preço do trailer conta membros que entraram **até o fim do Day 1** (`Q-112` a; reinterpreta DEC-047). Recomendação: sim.
9. Depois de perder a noite, o jogador acorda **em pé ao lado do trailer**, não no banco (`Q-106` b; emenda DEC-053). Recomendação: sim.
10. Sinal de início do Walker: o **último poste da Juniper zumbe ~2 s** (`Q-113` b; anotação em `anomalies.md`, Aprovado). Recomendação: sim.
11. Ligações pelo **telefone fixo do veículo**; celular flip só na cutscene de abertura (`Q-076`). Recomendação: sim.
12. **Cafeteira fixa no trailer** (`Q-124`). Recomendação: sim.
13. `art/style-guide.md` **inteiro aprovado**, com iluminação **Future + fallback ShadowMap** e roupa de NPC por **cores por parte do corpo** (`Q-123`). Recomendação: sim.
14. Noite com duração **crescente 20 → 30 min** (`Q-044`). Recomendação: sim.
15. Eventos de demanda, validade de ingrediente e missões diárias **fora do MVP** (`Q-022`, `Q-025`, `Q-028`). Recomendação: sim.

Dito ao usuário como "confirme só se discordar" (game-designer): limite de **2 revives por jogador por noite**; Revive Kit com **15% por turno** após o trailer, preço **$200 × multiplicador da party**.

Notas de leitura (não alteram o texto):
- "1. médicos descem e pegam o corpo" = item 1, opção **contra a proposta do art-director** (maca automática) e igual a DEC-091.
- "resto recomendações" = itens **2 a 15** aprovados como recomendados.
- Os dois números "confirme só se discordar" não foram contestados. Registrados como aprovados **em bloco pela leitura** (instrução do orquestrador), com essa nota na DEC.
- Itens 4–7 são propostas técnicas do architect (`tech/architecture.md` §15 D1–D4) aprovadas pelo usuário nesta tabela: viram DEC.
- O style guide aprovado (item 13) tem dois trechos que conflitam com itens desta mesma rodada: §4.6 linha "Ambulância leva" (maca automática; conflita com o item 1) e §11 sinal do Walker "~1,5 s" (conflita com "~2 s" do item 10). Vale a DEC (ordem de autoridade do `CLAUDE.md`). Alinhamento do texto em `Q-127`.

> 1. médicos descem e pegam o corpo, resto recomendações

---

## Rodada 16

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração. Uma mensagem escrita.
Registro derivado: DEC-130 em `docs/decisions.md` (revoga DEC-120); `Q-102`, `Q-103`, `Q-122` anotadas; novas `Q-128`, `Q-129`, `Q-130`.

Contexto (explicado pelo orquestrador): DEC-120 pedia semáforo com faixa na travessia trailer ↔ Mart e nos cruzamentos. No MAP-01 rev.2 a rota trailer ↔ Mart não cruza rua com trânsito (o Mart mudou de lado para evitar atropelamento); por isso o architect pôs semáforos nas faixas CW-2/3/4 e no T. Pergunta: o usuário prefere que o caminho até o Mart cruze a rua?

Notas de leitura (não alteram o texto):
- "remove o semáforo" = sem semáforo em lugar nenhum no MVP. Revoga DEC-120.
- "ele atravessa na sorte" = o jogador atravessa por conta e risco; pode ser atropelado (DEC-095, DEC-103).
- A pergunta "a rota até o Mart deve cruzar a rua?" **não** foi respondida de forma explícita. Aberta em `Q-128` (orquestrador perguntando).
- Faixa de pedestre e travessia de NPC não foram ditas: `Q-129`.

> remove o semáforo, ele atravessa na sorte

---

## Rodada 17

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração. Uma mensagem escrita.
Registro derivado: DEC-131 e DEC-132 em `docs/decisions.md`; fechadas `Q-128` (DEC-131) e `Q-127` (resolvida em documento, conferida pelo secretário); anotadas `Q-090`, `Q-102`, `Q-103`.

Perguntas a que respondeu (feitas pelo orquestrador):
1. `Q-128` — caminho trailer ↔ Mart: (A) sem cruzar rua x (B) cruza a rua (Juniper Sul aberta a carros, travessia no meio da quadra CW-1, MAP-01 rev.3), sem semáforo (DEC-130); cada ida ao Mart arrisca atropelamento e o pacote cai.
2. LD-15 / P33 do MAP-01 — Walker começa a ~165 studs da janela; style guide aprovado (DEC-126) pede fim da Juniper legível a ~110. Opção 1 (recomendada): postes da Juniper a cada 8 studs, último a ~135. Opção 2: testar no celular.

Notas de leitura (não alteram o texto):
- "B" = item 1, opção B. Confirma P32 do MAP-01 (abrir a Juniper Sul) sem o semáforo.
- "postes mais juntos" = item 2, opção 1 (8 studs, JL-09 a ~135). Exceção ao "~110" do style guide aprovado: registrada como emenda de DEC-126 só nesse ponto (DEC-132).

> B, e postes mais juntos

---

## Rodada 18

Fonte primária. Somente leitura. Transcrição fiel, texto do usuário sem alteração. Uma mensagem escrita.
Registro derivado: DEC-133 em `docs/decisions.md`; fechada `Q-129`; anotadas `Q-122` (b), `Q-130` (lista T1–T31); nova `Q-131` (alinhamento técnico com DEC-133, não volta ao usuário).

Pergunta a que respondeu (feita pelo orquestrador):
1. `Q-129` — regra de travessia sem semáforo. Opção B (recomendada pelo game-designer, `design/features.md` FEAT-033): PARE só nos dois braços da Juniper (carro para 1 s, entra com cruzamento livre; Ninth preferencial nunca para); faixas CW-1..4 pintadas; NPC só cruza na faixa com reserva do servidor (nenhum carro a < 15 studs), carros esperam no máx. 4 s, nova reserva só após 4 s; carro nunca para nem desvia por jogador, nem na faixa; spawn de carro ≥ 55 studs da primeira faixa (aviso ~2,5 s, motor audível), ≥ 3 s de intervalo na mesma faixa; Juniper Sul de dia 1 carro a cada 12–20 s por sentido (~16% de atropelamento por travessia sem olhar, ajustável em `Traffic.Crossing`).

Notas de leitura (não alteram o texto):
- "B" = opção B de `Q-129`, inteira.
- "pode seguir" = autoriza os especialistas a aplicar a opção B nos documentos; não aprova documento nenhum como um todo.

> B, pode seguir
