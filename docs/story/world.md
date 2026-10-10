Status: Rascunho

# Mundo e ambientação

Autor: narrative-writer, 2026-10-08. Nada aqui é decisão; o usuário aprova, o secretário registra.
Base: DEC-003, DEC-005, DEC-008, DEC-009, DEC-019 a DEC-023, DEC-025, DEC-027, DEC-049, DEC-052, DEC-060, DEC-065; rodadas 7–11: DEC-073 a DEC-079, DEC-086 a DEC-088, DEC-091, DEC-095, DEC-096, DEC-099, DEC-101, DEC-103, DEC-105; rodadas 12–15: DEC-106, DEC-109, DEC-114, DEC-124, DEC-126; rodada 16: DEC-130 (sem semáforo, revoga DEC-120); rodada 17: rota trailer ↔ Mart cruza a Juniper Sul (resposta a `Q-128`; DEC a registrar pelo secretário); GDD V1 §1, §8, §9, §17, §22.
Conciliado com `consistency-report.md` (2026-10-08, NW-7, NW-8, NW-14 a NW-16, NW-24).
Texto do jogo em inglês (DEC-022); documentação em pt-BR. Tudo original: nenhum nome, lugar ou fala de outro jogo ou marca.

Documentos irmãos em `docs/story/`:

| Arquivo | Conteúdo | Status |
|---|---|---|
| `world.md` | este: cidade, esquina, lugares, trânsito, tom, verdade escondida | Rascunho |
| `characters.md` | fichas `CHR-###` | Rascunho |
| `script.md` | cutscene de abertura (party 1–4), tutorial, ligações do chefe, queda/ambulância/spectate, noite perdida | Rascunho |
| `anomalies.md` | as 10 anomalias `ANM-001`–`ANM-010` (N1–N10) | **Aprovado** (DEC-073, DEC-074) |
| `ending.md` | final A1 "The Light on the Corner" e trilha de pistas | **Aprovado** (DEC-075, DEC-076) |
| `ui-text.md` | prompts, placas, notificações, telas, nomes | Rascunho |

---

## 1. Tom

| Fase | Sensação | Como o texto ajuda |
|---|---|---|
| Dias 1–5 | aconchegante, engraçado, "primeiro emprego" | chefe animado, piadas leves, nenhuma pista explícita de sobrenatural (DEC-008) |
| Noites 1–3 | "isso foi estranho?" | regras ditas como se fossem normais ("house rules"); o chefe minimiza |
| Noites 4–6 | "ele sabe de alguma coisa" | o chefe hesita, desvia de perguntas ("Next question.") |
| Noites 7–10 | "eu preciso terminar este turno" | regra crítica (só o Walker, DEC-074); o chefe fala sério, pede desculpa, promete o nascer do sol |

Dois registros de humor convivem com o terror e **não se misturam**:
- **Pastelão** (dia e noite): atropelamento em ragdoll (DEC-095), Quick Quentin, mariposa na carteira. Tom de desenho animado: estrelinhas, "BONK!", buzina cômica. Nunca dor, nunca ferida.
- **Inquietante** (só noite): anomalias. Sem piada visual nelas.

Regras de escrita (valem para todo texto de jogo):

- Fala de NPC: **uma linha, até ~70 caracteres**. Ligação: **até 7 linhas**, uma por vez, avançando sozinha (sem toque, DEC-077).
- Tutorial: **um passo por linha**, verbo no imperativo.
- Sem violência (DEC-023). Palavras proibidas em texto de jogo: *die, dead, death, kill, blood, hurt, injured, gun, shoot, weapon, monster, demon, corpse, body*. Use: *out, rest, fainted, gone, the late crowd, things*.
- Queda por sanidade (DEC-091) é **desmaio** e **resgate**: "fainted", "ambulance", "Bellmoor Rescue". Nunca "died", nunca "body" em texto de jogo (o "corpo" da documentação é só o avatar caído).
- O chefe **nunca explica** o que são as anomalias antes da 10ª noite. Ele cria perguntas (DEC-008, GDD §9).
- O chefe só fala **por telefone** durante a run (DEC-076). Em pessoa, uma vez: amanhecer da 10ª noite (`ending.md`).
- Nada de jumpscare escrito no roteiro (DEC-005). O medo vem de regra + sinal + "e se eu errar?".
- Linguagem simples: público infantojuvenil e muita gente que não tem inglês como língua materna.
- Sem XP, sem nível (DEC-081): nenhum texto fala em "level up", "XP" ou "rank". Progresso = dinheiro, upgrades, ingredientes, trailer, gemas.

## 2. A cidade: **Bellmoor**

Cidade pequena, de prédios baixos de tijolo, toldos coloridos, ônibus amarelo que passa de manhã, pombos. Parece um cartão-postal.
Estilo "toy low-poly" (DEC-105): tudo parece brinquedo bem feito. De dia é o lugar mais normal do mundo. É isso que a noite quebra.

Detalhes que se repetem (o "padrão" que as anomalias quebram — DEC-010, GDD §14):
- o **relógio do banco** do outro lado da rua sempre bate certo e faz tique-taque;
- os **postes da Juniper Street** acendem um por um às 8:00 PM;
- os moradores dos **apartamentos de cima** fecham as cortinas cedo;
- o **Ninth Street Mart** nunca fecha;
- clientes normais pedem, pagam, agradecem e vão embora pela mesma calçada;
- **carros comuns nunca param** no meio-fio em frente ao carrinho/trailer: ali é faixa vermelha com placa "NO PARKING" (base do sinal da N8, §3.1).

## 3. A esquina: **Ninth & Juniper**

Onde o carrinho fica, fixo (DEC-020), e onde o trailer trabalha depois da compra, no mesmo lugar (DEC-086). Cruzamento da **Ninth Avenue** com a **Juniper Street**.
`levels/MAP-01.md` (revisão 2) já adota estes nomes (`Q-096`, fechamento com o secretário) no lugar dos placeholders ("Main St" → Ninth Avenue, "Cross St" → Juniper Street, "Corner Mart" → Ninth Street Mart, "The Corner" → Ninth & Juniper). Nome do mapa: **"Ninth & Juniper"**.

| Lugar (nome no jogo) | O que é | Função de jogo | Uso narrativo |
|---|---|---|---|
| **The corner** (Ninth & Juniper) | calçada larga, esquina | carrinho (dias 1–5) e trailer (depois), mesmo Pad (DEC-086) | "o cruzamento" da revelação |
| **The lamp post** | poste de luz na esquina | panfleto da cutscene (DEC-021) | o panfleto volta no final |
| **Ninth Street Mart** | mercadinho 24 h, neon "OPEN 24 HOURS" | ingredientes e upgrades (DEC-049, DEC-101), 100–120 studs, linha de visão; do outro lado da **Juniper Sul**: a ida cruza a rua (rodada 17, §3.2) | **ponto seguro** da N10; onde Walt assiste às noites (final A1) |
| **Bellmoor Savings** | banco com relógio grande na fachada | cenário | N3 (relógio parado) |
| **Juniper Street** | rua longa e reta, fila de postes | cenário, rota de clientes, faixa de trânsito | N7 (The Walker) e N10 (The Hush) |
| **The apartments** | prédio de 3 andares com janelas sobre a esquina | cenário | N6 (The wavers) |
| **The red curb** | meio-fio vermelho "NO PARKING" em frente ao trailer, do outro lado da rua | cenário; nenhum carro comum para ali | N8 (The long car) para **só** ali |
| **Parking lot** | estacionamento ao lado da esquina | trailer à venda desde o dia 1, placa "Available on Day 5" (DEC-047); depois da compra, o **carrinho** fica ali, coberto por lona | o trailer velho "esperando a pessoa certa" |
| **Suds & Socks** | lavanderia de bairro, máquinas giratórias na vitrine | cenário (luz de vitrine à noite) | — |

### 3.1 Ninth Street Mart por dentro (DEC-101)

| Área | O que tem | Texto |
|---|---|---|
| Prateleiras | pacotes de ingrediente (DEC-049) | etiquetas por item |
| Frutas e verduras | caixotes coloridos | placa "FRESH PRODUCE"; **só cenário** (DEC-109) |
| Balcão do caixa | **Opal** (CHR-003), palavras cruzadas, sininho da porta | Opal não vende (DEC-079) |
| **Parede do fundo: bancada de upgrades** | peças de equipamento penduradas em ganchos, com etiquetas de preço. Os **básicos** (Grill, Cooler, Counter, Drawer Lock, Trailer Lights) estão **sempre** à venda (DEC-106); cada gancho mostra o próximo nível. Ao lado, uma **vitrine pequena de vidro** (slot especial S1): é a única coisa que muda por turno, quase sempre vazia | placa pintada à mão: **"GEAR WALL"** (nome único em `docs/story/`; MAP-01 diz "TODAY'S GEAR" e AST-072 "UPGRADES": alinhar, ver `ui-text.md` §4) · placa da vitrine: "SPECIAL" · "Changes every shift." |

A bancada é loja de parede, sem vendedor: compra por prompt (DEC-015, DEC-066). Quando o Rescue Whistle (item raro de reviver, DEC-100, DEC-129) aparece na vitrine, ela acende (texto em `ui-text.md`).
Pista leve: ninguém sabe quem põe coisas na vitrine. Opal dá de ombros ("Shows up. I don't ask.").

### 3.2 Trânsito (DEC-087, DEC-095) — e a N8 (proposta para `Q-103`)

De dia: carros de brinquedo coloridos (sedã, picape, van, táxi amarelo, ônibus amarelo de manhã) andando pela Ninth e pela Juniper. Atropelamento é **pastelão**: buzina cômica, jogador arremessado em ragdoll, estrelinhas, "BONK!", levanta e segue (DEC-095); o item da mão cai no chão (DEC-103). O motorista nunca desce.
**Não há semáforo** em Bellmoor no MVP (DEC-130, revoga DEC-120). Os carros andam e **não param para ninguém**; o jogador atravessa quando quiser, **na sorte**, e pode ser atropelado (pastelão acima). A rota trailer ↔ Mart **cruza a Juniper Sul** (rodada 17): é a travessia que o jogador mais faz, então é ali que o "olhe antes de atravessar" pesa. O texto ajuda sem regra nova: Walt avisa no tutorial ("Look both ways!") e Opal repete no Mart (`characters.md` CHR-003). Se as faixas continuam pintadas, se algum carro para nelas e como os clientes atravessam fica com `Q-129` (game-designer + level-designer); o texto não promete nada disso.

À noite o padrão de trânsito precisa ser simples, porque é o padrão que a N8 quebra. Proposta (narrative-writer; números e densidade com game-designer/level-designer em `Q-102`):

| Regra de padrão | Carro comum (noite) | The long car (N8) |
|---|---|---|
| Quantidade | rareia ao longo da noite (sugestão: poucos até ~11 PM, quase nenhum depois) | um só, só na ocorrência |
| Movimento | velocidade constante; **não para** (sem semáforo, DEC-130) | desacelera e **para** no **red curb** |
| Onde para | em lugar nenhum (se `Q-129` decidir que param na faixa para o jogador, só ali); **nunca** no red curb ("NO PARKING") | **só** no red curb |
| Faróis | baixos, amarelados, apontando para a rua | apagados ao chegar; depois **farol alto direto no trailer** (sinal aprovado) |
| Forma | carros de brinquedo curtos, coloridos | preto, **comprido demais** (~2× um sedã), vidros embaçados (sinal aprovado) |
| Som | motor de brinquedo, buzina cômica | zumbido grave contínuo; sem buzina até o erro (sabor aprovado) |
| Rua ao redor | normal | **a rua esvazia**: ~3 s antes de chegar, os carros comuns já na pista seguem e nenhum novo aparece enquanto ele estiver ali; os sons da cidade abafam |
| Atropela? | sim, pastelão (DEC-095) | **não**: nunca encosta em jogador (sugestão: atravessa como névoa ou espera; game-designer) |

Por que funciona: o jogador aprende de dia que "carro nunca para" (sem semáforo o padrão fica até mais forte: carro comum não freia por nada) e que trânsito faz barulho engraçado. O carro que **para em silêncio no lugar proibido, com a rua vazia** é quebra de padrão legível mesmo com trânsito, sem mudar o sinal aprovado em `anomalies.md`.
Ambulância (§3.3) também nunca para no red curb: ela para **do lado do trailer** (DEC-091).
A ligação da noite 8 ganha uma linha de apoio sem mudar a regra: "Regular cars never stop there. That one does." (`script.md` §5).

### 3.3 Bellmoor Rescue (ambulância, DEC-091)

- Ambulância **Cream com faixa Teal larga**, barra de luz **Mustard/Teal** (`art/style-guide.md`, Aprovado, DEC-126), letreiro **"BELLMOOR RESCUE"**, sirene curta e suave (não vira jumpscare, DEC-005). Sem marca real.
- Dois médicos (CHR-008) de uniforme Teal e Cream. Chegam, **descem**, levam o colega desmaiado na maca carregada à mão, vão embora (DEC-114). Na volta de um reviver, **não descem**: a ambulância para ao lado do trailer, o jogador aparece ao lado dela e ela vai embora (DEC-091).
- Não faz parte do late crowd. É gente comum, do turno da noite como o jogador. Pista leve: chega rápido demais, como quem já estava esperando por perto. Walt: "They know the corner." (sem explicação).
- Texto de jogo fala em "fainted" e "resting at Bellmoor Rescue"; o jogador que não reviveu "está descansando", nunca "perdido".

## 4. O negócio do chefe: **Bramble's Corner Dogs**

- Dono: **Walt Bramble** (CHR-001). O jogador é funcionário, nunca dono (DEC-019).
- Telefone do panfleto: **555-0179** (faixa 555-01xx é reservada para ficção; "79" é uma pista do ano de 1979).
- Carrinho do dia: pintado de vermelho e creme, letreiro "BRAMBLE'S CORNER DOGS". Tem um **telefone fixo vermelho antigo** (AST-042) preso ao mastro do guarda-sol: é por ele que Walt liga de dia (DEC-124, §4.1).
- Trailer: velho, de alumínio, estacionado no lote há anos, pintura desbotada "BRAMBLE'S — OPEN LATE". Na ficção é o **trailer noturno original** do chefe. O jogador "compra" com o dinheiro do caixa; não precisa explicar (DEC-019). Depois da compra, assume o lugar do carrinho na esquina (DEC-086). Tem o **mesmo telefone fixo** do carrinho (AST-042: vermelho, fone creme, fio enrolado), na parede ao lado da janela de serviço.
- Depois da troca, o carrinho vai para a vaga do lote onde o trailer esperava, **coberto por lona**, com um bilhete preso: "Good cart. Rest up. — W" (proposta para `Q-082`). Troca de lugar simbólica: o velho espera, o novo trabalha.
- Slogan na lateral do carrinho: "Hot dogs on the corner since forever." (piada de dia; pista à noite).

### 4.1 Telefone do chefe — **decidido, DEC-124**

| Momento | Aparelho | Por quê |
|---|---|---|
| Cutscene de abertura | **celular flip** (AST-038), só aqui | o avatar do trilho 1 liga para o panfleto (DEC-021; `script.md` §1). Surge já aberto, sem gesto de mão (DEC-097) |
| Ligações de dia (dias 1–5) | **telefone fixo do carrinho** (AST-042, no mastro do guarda-sol) | um aparelho só para a party: toca no mundo, qualquer um usa "Answer", viva-voz para todos (FEAT-018) |
| Ligações de dia e de noite depois do trailer | **telefone fixo do trailer** (AST-042, mesma peça, na parede) | idem; é também o telefone da alucinação (`script.md` §8) e das falas "I never come to the trailer" (N9) |
| Final A1 | — (Walt em pessoa) | DEC-075 |

Todas as ligações da run tocam no telefone fixo do veículo; o celular nunca aparece na hotbar (DEC-040, DEC-124). Uma **malha só** (AST-042, vermelho com fone creme) nos dois veículos, como na ficha do art-director.

## 5. A noite em Bellmoor

Depois das 8:00 PM, a mesma esquina, os mesmos prédios. Mas:
- a luz dos postes fica mais amarela e "pesada";
- os sons de cidade somem aos poucos (cada vez menos carros, sem pombos), sobra o zumbido da grelha e o tique-taque do banco;
- os clientes normais continuam vindo (trabalhadores de turno, gente saindo do cinema) e são **iguais aos do dia** — isso é o padrão;
- e às vezes chega alguém, ou alguma coisa, que **não deveria estar ali**.

O chefe chama esses visitantes de **"the late crowd"** (o pessoal da madrugada). Nunca diz "monstro" nem "fantasma".

### 5.1 Quem vê o sinal (proposta narrativa para `Q-069`)

O sinal de toda anomalia é **visto/ouvido por todos** da party; o que é "por jogador" é o erro e a penalidade. Motivo: o momento co-op ("não olha pra janela!", "fecha a janela, o carro!") só existe se todos podem perceber. Exceção nenhuma no MVP.

### 5.2 O ponto seguro (proposta para `Q-092`)

> **DEC-177 (2026-10-10, fecha `Q-092`, contra esta proposta):** o ponto seguro **pode** receber anomalia. "Nunca apaga" segue (style guide); "nunca recebe anomalia" **não vale**. Reescrita do parágrafo abaixo → narrative-writer, junto com `Q-161`.

O letreiro "OPEN 24 HOURS" **nunca apaga e nunca recebe anomalia**. É regra de mundo: a luz que o late crowd respeita. Se uma anomalia pudesse aparecer ali, a revelação ("luz educada") perde sentido.

## 6. A verdade escondida (bíblia do roteirista — **não aparece no jogo antes da 10ª noite**)

Serve para manter as anomalias e as falas coerentes. Vale a opção **A / A1** (`ending.md`, DEC-075):

- A esquina Ninth & Juniper é um **cruzamento**: à noite, coisas de "algum outro lugar" passam por ali. Ninguém sabe de onde vêm.
- Elas são atraídas por **luz, gente e cheiro de comida**. Não querem machucar ninguém; querem **imitar** a vida do dia e não sabem fazer direito:
  rosto que não terminaram (ANM-001), comida copiada errada (ANM-002), tempo que emperra (ANM-003), cópia de cliente ao contrário (ANM-004), quem só quer ser notado (ANM-006), carro que imita trânsito e não sabe onde não pode parar (ANM-008).
- Algumas são perigosas do jeito delas (sem violência): o **Walker** quer chegar à luz do trailer e apagá-la (ANM-007); o **long car** procura quem cuida da esquina (ANM-008); o **knock** imita a voz do chefe para entrar (ANM-009); o **Hush** apaga a rua inteira (ANM-010).
- Existe um acordo antigo, nunca escrito: **enquanto alguém mantiver a luz da esquina acesa e servir comida com educação, a madrugada fica educada.** As regras do chefe são esse acordo, aprendido na prática.
- A **Raincoat Lady** (CHR-006) é a mais antiga do "late crowd" e a mais gentil. Servi-la é sinal de respeito ao acordo (ANM-005).
- **Walt Bramble** fez o turno da noite de **1979** até ficar velho demais. O negócio de dia paga as contas e serve para achar a próxima pessoa: alguém que **repara nas coisas**. O panfleto só "funciona" com quem para para ler.
- Walt nunca vai ao trailer à noite porque o late crowd conhece o rosto dele. Ele assiste de dentro do Mart, o lugar de luz que nunca apaga (ANM-010 usa isso). Ele liga do telefone do Mart (Opal finge não ver).
- A bancada da parede do fundo ("GEAR WALL") é abastecida por Walt de madrugada, com peças do trailer antigo e coisas que ele guardou em 40 anos. Nunca dito no jogo; só explica por que a parede nunca fica sem peça e por que o apito de resgate (Rescue Whistle) às vezes "aparece" na vitrine.

O que **nunca** é explicado, nem no final: o que o late crowd é, de onde vem, quem fez o acordo, quem é de fato a Raincoat Lady.
Isso fica como mistério e como gancho para atualizações (outras esquinas: parque, posto, praia — vision §10).
