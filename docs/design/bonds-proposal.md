Status: Rascunho

# Os Regulares: vínculo com os NPCs que têm nome (FEAT-042, proposta)

Autor: game-designer, 2026-10-16. Pedido do dono (2026-10-16): o jogo tem elenco com nome, mas nenhuma relação com o jogador;
falta apelo emocional. A ideia é ter interações pequenas com escolha sim/não que, ao longo da run, criem vínculo e deem
recompensas (benefício, atalho ou porta secreta, presente), como fazem outros jogos do gênero.
**Tudo aqui é Provisório.** Nada vale como Aprovado sem DEC do dono. A feature ganha o ID **FEAT-042**. A ficha em
`features.md` só será escrita depois da resposta às perguntas `Q-276` a `Q-279`.

Fontes lidas: `CLAUDE.md`, `AGENT-BRIEF.md`, `README.md`, `vision.md` §6 (pilares), `story/characters.md` (CHR-001, 003, 004, 005, 006),
`design/npcs.md` (NPC-007, NPC-013, NPC-020, NPC-021), `design/anomalies-v2-proposal.md`, `design/economy.md` §5.0,
`research/animal-hospital.md`, `decisions.md` até a DEC-260. Para medir o escopo li também, sem editar, `src/`:
`OpalController`, `ThiefService`, `Content.RunParams`, `Nights`, `Anomalies`, `Sanity`, `Thief` e `Journal`.
**Inspiração, não cópia:** a referência de gênero só serviu para lembrar o que o jogo ainda não tem (NPC fixo com quem se cria laço).
Nenhum nome, fala ou mecânica foi tirado dela. A pesquisa (`animal-hospital.md`) nem descreve um sistema assim.

---

## 0. Resumo

- **3 NPCs no MVP** (`Q-279`): Opal (CHR-003 / NPC-020), Mr. Pickett (CHR-005 / NPC-021) e Quick Quentin (CHR-004 / NPC-007).
- Cada NPC tem um **arco de 3 a 4 batidas** espalhadas pela run (Day 1 + Nights 1–10). Uma **batida** é um balão com a fala
  dele e **2 botões**: um gentil (soma **+1** de vínculo) e um neutro (**0**). Não existe escolha que tire vínculo.
- **Nenhum medidor na tela** (coerente com DEC-051, que proíbe medidor de reputação). O jogador percebe o vínculo pelo que o NPC
  faz e fala depois: rosto `Happy`, um bilhete, um objeto que aparece no trailer, uma frase nova.
- A recompensa é **utilidade leve somada a uma lembrança**. Ela **nunca** resolve uma anomalia sozinha e nunca deixa ninguém imune
  a jumpscare ou desmaio (`Q-278`). O dinheiro extra fica em no máximo ~4% de uma run solo (§7).
- **Co-op:** quem estiver perto vê a batida, e **o primeiro clique decide pela party**. O efeito vale para todos (`Q-277`).
- **Escopo:** o vínculo vale **para a run** e zera na run nova (`Q-276`). Fica guardado em `RunState.Counters`, que já tem snapshot.
- **Dados:** a tabela `Content.Bonds` guarda NPC, batidas, opções e efeitos. Os efeitos vêm de um catálogo genérico, sem código
  específico por NPC (§8).
- **Extensão de 2026-10-16 (pedido do dono):** a §14 trata dos **segredos do bairro**: a chave escondida embaixo da mostarda, a loja
  de brinquedos com um pet que voa sobre o ombro (cosmético persistente) e um segredo por prédio. A §15 trata das **consequências
  (sandbox)**: uma escolha **rude** explícita por NPC, com consequência leve e temporária. O neutro continua sem perda nenhuma.
  Perguntas novas: `Q-280` a `Q-282`.

## 1. Conflitos e premissas: ler antes

O orquestrador recomendou partir de "10 dias e 10 noites" e de "ANM-007 crítica". O jogo mudou, e a proposta foi ajustada:

| # | Fato atual | Fonte | Efeito na proposta |
|---|---|---|---|
| C1 | A run de hoje é **Day 1 (tutorial) + Nights 1–10**. Depois do Day 1 não há mais turno de dia | `RunParams` (decisão do dono 2026-10-12, Provisória), `economy.md` §5.0 | O "almoço diário" do Pickett não existe mais. **Proposta:** o Pickett vira o **regular da noite**. Ele chega toda noite na janela **Calm (8:00–9:00 PM)**, antes das anomalias, e isso combina com a fala que já é dele: "Couldn't sleep. Is the grill still on?" (CHR-005). |
| C2 | O ladrão é **só de dia** e **nunca aparece à noite** | **DEC-050**, **DEC-159** | Hoje o Quentin não entra em cena nenhuma: no Day 1 a chance é 0% e o ladrão está desligado no modo anomalia (`Q-266`). **Proposta:** ele aparece **no anoitecer (Calm)** das noites 2, 4, 6 e 8. **Isso exige uma DEC que emende DEC-050 e DEC-159**, e por isso o ponto entra em `Q-279` (b). Sem essa DEC, a Raincoat Lady substitui o Quentin no MVP (§5.4). |
| C3 | **Não existe mais regra crítica.** Errar = jumpscare + desmaio; a noite só se perde se todos desmaiarem | **DEC-255** (emenda DEC-074) | A regra "não resolve a ANM-007 crítica" vira "**não resolve nem atenua sozinha nenhuma anomalia**: não muda prazo, não dá imunidade, não pula verbo" (§6). |
| C4 | A cópia (ANM-004) **estreia na Night 5**, não na 4 | `Anomalies.luau` (`copies.Night = 5`), `anomalies-v2-proposal.md` §8.2 | O aviso do Pickett vale na N5. `npcs.md` NPC-021 ainda diz N4 e precisa de ajuste quando a ficha for revisada. |
| C5 | O NPC-021 (Pickett) **não existe no código**. Hoje a primeira cópia não usa o Pickett como original | grep em `src/` | O escopo inclui o spawn do regular e a regra "1ª cópia da N5 = Pickett" (§9). |
| C6 | Proibido medidor de reputação no HUD; reputação não é recurso | **DEC-051** | O vínculo é um contador **escondido, por NPC e por run**. Não aparece no HUD nem entra na nota do turno. Se o dono ler isso como "reputação", a proposta cai. Ver `Q-276`. |
| C7 | O esconderijo é por jogador, em 4 pontos | **DEC-176** (V2: `HideZone` atrás do trailer) | O esconderijo do Quentin (§5.3) seria uma zona **a mais**. Se o dono ler a DEC-176 como "exatamente 4", o recanto passa a ser um dos 4 pontos: fica onde está e só ganha a recompensa de ficar mais perto. O level-designer confere. |
| C8 | A Opal **não vende** e nunca é anomalia | **DEC-079**, **DEC-191** | Respeitado. Café de cortesia, garrafa térmica e porta destrancada são presentes, não vendas. Ela continua atrás do balcão do Gear Stand e não vira âncora de anomalia. |
| C9 | Cliente comum à noite: fila de 1 | TASK-287 | A conversa do Pickett acontece **fora da vaga do balcão** (ponto `CHAT-1`, §4), para não segurar a fila. |

Ajuste em relação à recomendação do orquestrador: **Opal e Quentin não dão o mesmo tipo de recompensa.** A Opal dá o **atalho**
(porta lateral do Mart). O Quentin dá um **esconderijo secreto** no beco, um recanto mais perto da porta dos fundos do trailer.
Dois atalhos seriam redundantes, e o esconderijo combina com um guaxinim ladrão.

## 2. Pilares

DESCOBRIR (o vínculo revela quem são os personagens e dá pistas, sem explicar, como manda a DEC-008), OBSERVAR (o relógio do Pickett
ensina o sinal da cópia) e SOBREVIVER (recompensas leves para a noite). Também encosta em GERENCIAR: o hot dog grátis do Quentin custa estoque.

## 3. Regras gerais

| Regra | Valor (Provisório) |
|---|---|
| Vínculo por NPC | inteiro de 0 até o número de batidas (Opal 4, Pickett 4, Quentin 2 para virar aliado). Começa em 0 a cada run |
| Botão gentil | +1 de vínculo, mais o efeito imediato da batida (se houver) |
| Botão neutro | 0. O NPC responde com uma fala neutra e simpática. **Nada é tirado** (nem dinheiro, nem sanidade, nem vínculo). A única perda é não ganhar o extra |
| Botão rude (só em 1 batida por NPC, §15) | 3º botão, rotulado de forma explícita e com **segurar 1 s**. Tira 1 de vínculo (mínimo 0) e deixa o NPC **"frio"** por um tempo curto (§15). Nunca é o padrão e nunca acontece por tempo esgotado |
| Ninguém respondeu | a batida fica **pendente** e volta na próxima oportunidade do mesmo NPC. Batida de NPC com hora marcada (Pickett, Quentin) volta na noite seguinte da agenda |
| Batidas por noite | no máximo **1 por NPC por noite** |
| Tempo para escolher | **20 s** com os botões à vista (Quentin: 12 s, porque ele foi pego no flagra). Depois disso a batida conta como "ninguém respondeu" |
| Quando pode acontecer | Pickett e Quentin: só na janela **Calm** (8:00–9:00 PM, sem anomalia por desenho; 54 s reais na N1, 90 s na N10). Pode transbordar até **9:15 PM** se ninguém tiver respondido e não houver anomalia ativa. Opal: a qualquer hora em que a persiana do Gear Stand estiver aberta, **menos** durante anomalia ativa das famílias B ou C e durante o Hush |
| Anomalia começa no meio de uma batida | a batida **cancela sem custo** e volta a ficar pendente |
| Noite perdida / noite repetida | batida respondida continua respondida. Na repetição, só as batidas pendentes voltam |
| Mostrar o vínculo | sem número nem barra. Sinais: rosto `Happy` na resposta gentil, balão de resposta, objetos-presente no trailer, fala nova nas visitas seguintes e uma página "Regulars" no diário (`Content.Journal`) com uma linha por batida respondida com gentileza |
| Interface | o balão do NPC (componente `SpeechBalloon`, que já existe) mais **2 ProximityPrompts** no NPC: tecla **E** para o gentil e **R** para o neutro (gamepad **X / Y**; no mobile, toque em cada um). Sem botão novo na tela, sem nada centralizado, sem vermelho. Texto da UI em inglês |
| Jogador no modo de preparo focado | vê um aviso curto na borda da tela ("Mr. Pickett wants a word"). Para responder, sai do foco |

## 4. Co-op (`Q-277`)

| Ponto | Regra (Provisória) |
|---|---|
| Quem vê | todo jogador **ativo** a até **12 studs** do NPC (Opal: 8, o raio do balão dela hoje). Quem está longe não vê os botões |
| Quem decide | **o primeiro clique**. O servidor trava a batida no primeiro pedido válido; os cliques seguintes são ignorados e os botões somem para todos |
| Efeito | vínculo e recompensa valem **para a party**. Efeito imediato "na mão" (ex.: o café da Opal) vai só para quem clicou |
| Aviso para a party | só na escolha **gentil**: aviso curto para todos ("Alex shared a hot dog with Quentin."). A escolha neutra não gera aviso, para ninguém se sentir apontado |
| Jogador que entra atrasado | herda o vínculo da party (o estado é da run) |
| 1 jogador | igual; não existe balanceamento por tamanho da party |

## 5. Arcos do MVP

Agenda da run (D1 = Day 1; N = noite):

| Turno | Opal (visita ao Mart) | Mr. Pickett (Calm, ~8:05–8:15 PM) | Quick Quentin (Calm, ~8:25–8:35 PM) |
|---|---|---|---|
| D1 | `opal_1` a partir do fim do dia (persiana aberta, Closing) | — | — |
| N1 | (`opal_1` se ainda pendente) | `pickett_1` | — |
| N2 | `opal_2` | `pickett_2` | `quentin_1` |
| N3 | — | visita sem batida | — |
| N4 | `opal_3` | `pickett_3` (o relógio) | `quentin_2` |
| N5 | — | **aviso** (vínculo ≥ 2) + original da 1ª cópia | — |
| N6 | `opal_4` | visita | `quentin_2` (se ainda faltar) |
| N7 | **presentes** (vínculo ≥ 2 / ≥ 3) | `pickett_4` | — |
| N8 | — | visita | última chance (se ainda faltar) |
| N9 | — | visita | — |
| N10 | aceno no Hush (vínculo ≥ 3) | **presente** (vínculo ≥ 3) | — |

### 5.1 Opal: "a vizinha da vitrine" (4 batidas)

Gatilho: um jogador entra no raio de 8 studs do balcão dela com a persiana aberta e a batida da vez já liberada.
Fica no lugar do balão sorteado daquela visita. O resfriamento de 90 s por jogador não muda (NPC-020).

| ID | Liberada a partir de | Situação (intenção) | Gentil (+1) | Neutro (0) | Efeito imediato |
|---|---|---|---|---|---|
| `opal_1` | D1 Closing | ela trava numa palavra da cruzada (dica de comida) e pede ajuda | ajudar | "not now" | gentil: ela escreve a palavra e sorri (`Happy`) |
| `opal_2` | N2 | oferece um café da garrafa dela ("long night?") | aceitar | recusar com educação | gentil: **+10 de sanidade** para quem aceitou (só à noite; um café normal dá 25) |
| `opal_3` | N4 | o Walt esqueceu o cachecol no Mart; ela pede para levar ao trailer | levar | "can't leave the grill" | gentil: o cachecol aparece no gancho do trailer quando quem aceitou entrar nele. A ligação seguinte do Walt usa a variante "scarf" (mesmo mecanismo da variante "quentin" de `BossCalls`) |
| `opal_4` | N6 | ela comenta que vê a rua da vitrine e pergunta se a party está bem | "we're okay, thanks" | "just busy" | — |

Recompensas, entregues **no começo da N7** (Prep), sem a party precisar ir ao Mart:

| Vínculo | Recompensa | Números | Por que não decide nada |
|---|---|---|---|
| ≥ 2 | **"Opal's thermos"**: garrafa térmica no balcão do trailer com um bilhete "From O." | +2 doses na cafeteira no início de cada noite, N7–N10 (8 doses, 200 de sanidade possíveis para a party; custo equivalente ~$4 em café, ITM-019) | é café, que já existe e já se compra |
| ≥ 3 | **Porta lateral do Mart** (`MKT-STAFF`, nova) destrancada de N7 a N10, com o bilhete "Side door's open. —O." | caminho porta dos fundos do trailer → prateleiras **≤ 70%** do atual (~110 → ≤ 77 studs; o level-designer mede) | encurta idas de reposição e a corrida do Hush, mas o verbo continua o mesmo (entrar e ficar no Mart) |
| ≥ 3, N10 | No **Hush**, a luz sobre a porta lateral pisca em Mustard e a Opal acena da vitrine (só visual) | — | guia o olhar, não muda zona nem prazo |

Opal continua sem vender, sem prompt de compra e nunca é anomalia (DEC-191). Os dois prompts da batida ficam numa âncora
invisível do servidor no ponto `Att_Opal` / OP-1; o modelo dela segue só no client (`OpalController`).

### 5.2 Mr. Pickett: "o regular da noite" (4 batidas + aviso + presente)

Spawn (proposta para o NPC-021 no fluxo atual): **1 vez por noite**, chegada sorteada entre **8:05 e 8:15 PM** (Calm). Ele substitui
o spawn normal mais próximo e conta **1 no teto de clientes**. Pedido sorteado como o de qualquer cliente (DEC-064).
Depois de servido, ele vai ao ponto **`CHAT-1`** (ao lado da janela, fora da vaga do balcão; o level-designer marca) e fica lá
até 20 s para a batida. Sem batida, ele vai embora.

| ID | Noite | Situação (intenção) | Gentil (+1) | Neutro (0) | Efeito imediato |
|---|---|---|---|---|---|
| `pickett_1` | N1 | não consegue dormir; pergunta se a grelha vai estar ligada para ele toda noite | "every night" | "till six, like always" | gentil: `Happy` e ele diz o nome dele |
| `pickett_2` | N2 | conta do dia no escritório ("numbers, numbers") e pergunta como é o turno | ouvir | "busy night, sorry" | gentil: gorjeta extra de **$2**, uma vez |
| `pickett_3` | N4 | mostra o relógio de pulso **no braço esquerdo**, que era do pai ("never late, never early") | elogiar | "nice" | — (a cena ensina o sinal que a cópia espelha: relógio, bordado, maleta) |
| aviso | N5 | **se o vínculo for ≥ 2**: na visita do Calm ele comenta, de passagem, que viu "um sujeito vestido igual a ele, mas ao contrário" descendo a rua. Sem escolha | — | — | só a fala; regras da ANM-004 e DEC-247 intactas |
| `pickett_4` | N7 | conta que "alguém com a cara dele" apareceu; pergunta se o jogador percebeu | "I knew it wasn't you" | "didn't notice" | a fala muda se a party serviu a cópia na N5 (contador `pickett_copy_served`): ele consola ("it fooled me too") |
| presente | N10 | **se o vínculo for ≥ 3**: na visita do Calm ele deixa o relógio ("last night of your shift, huh?") | — | — | o relógio fica pendurado no trailer e vira uma linha na página "Regulars" |

Bônus contínuo: com vínculo ≥ 2, ele deixa **+$2 de gorjeta por visita** da N5 à N10 (até $12).
Na N5, a **1ª ocorrência da ANM-004 usa o Pickett como original** (já pedido em NPC-021; falta código). O aviso não diz o que fazer.
Quem confere o diário já sabe ("Refuse the mirrored one"). O aviso só faz o jogador **olhar** para o Pickett.

### 5.3 Quick Quentin: "o guaxinim que aprende" (2 gentilezas viram aliado)

Proposta para o fluxo atual (**depende de `Q-279` (b)**, que emenda DEC-050 e DEC-159): o Quentin aparece **no anoitecer (Calm)**
das noites **2, 4, 6 e 8**, chegando entre 8:25 e 8:35 PM. Depois que vira aliado, para de roubar. Ele reaproveita o `ThiefService`
(spawn, espreita, aproximação) com duas mudanças de dado:

| Estado | Regra no anoitecer (Provisória) | Números |
|---|---|---|
| Espreitar | parado no ponto de espreita, visível da janela | até **40 s** (de dia eram 120 s; o Calm é curto) |
| Ir ao pote | anda até o lado de fora da janela e estica a mão para o **pote de gorjetas** (DEC-239) | 4 s fixos (DEC-182) |
| Pegar | barra sobre o pote | **8 s** |
| Pego | qualquer jogador **olha para ele** (cone de visão de `Vision`, 1 s acumulado) ou chega a até 14 studs durante "ir" ou "pegar". O gatilho "zona vazia por 3 s" do dia não vale no anoitecer, porque a party fica dentro do trailer | cancelamento ≤ 0,5 s |
| Roubou | floor(pote × 50%) e foge; **sem batida**. Volta na próxima data da agenda | pote enche em $20 (`TipJar.FullAt`), então ≤ $10 por roubo |

| ID | Quando | Situação (intenção) | Gentil (+1) | Neutro (0) |
|---|---|---|---|---|
| `quentin_1` | 1ª vez que é pego | ele trava no flagra ("wrong jar!"), sem graça | **deixa ir e dá um hot dog**: tira 1 pão + 1 salsicha do estoque (~$1,25). Sem estoque, ele vai embora com "next time, then" e o vínculo sobe mesmo assim | **enxota**: ele foge e a party ganha o **+$5 "Nice catch!"** (DEC-050) |
| `quentin_2` | próxima data com vínculo 1 | ele **não rouba**: vai até a janela, encabulado, e pergunta se a oferta ainda vale | **"on the house"**: mesmo custo de estoque | **"pay like everyone"**: ele vira cliente pagante comum (pedido base, $4) e o vínculo não sobe |
| (vínculo 0) | próxima data | volta a tentar o pote; se for pego, repete o `quentin_1` | — | — |

Vínculo **2 = aliado**, na hora, na mesma visita:
- **Devolve as moedas:** tudo o que ele roubou na run (contador `quentin_stolen_total`), com mínimo de **$5** "pelo incômodo".
  Entra como venda do tipo "Gift" no `EconomyService` (o mesmo caminho do "Catch").
- **Dá a "Alley Key":** destranca o **recanto do Quentin** (`QN-NOOK`), uma tábua solta na cerca do beco que abre um esconderijo.
  Funciona como `HideZone` da família B para **até 2 jogadores** e fica a **≤ 6 studs** da porta dos fundos do trailer
  (o level-designer mede o esconderijo atual e confirma que o recanto economiza **1 a 2 s** numa janela de 8–10 s).
  Vale da noite seguinte até a N10.
- Nas datas que sobram na agenda, ele aparece como **cliente pagante** e deixa **$2** de gorjeta.

Visual: no anoitecer ele usa `T_Civil_Thief_Day` (sem textura nova). O Calm ainda é 8 PM, e o tom é de "vilão de desenho" amigável.
Se o dono quiser a variante Mid (DEC-181), o art-director cria `T_Civil_Thief_Mid` (≈ 1 textura).

### 5.4 Reserva e fase 2 (só citados)

- **Raincoat Lady (CHR-006 / NPC-013 / ANM-005, ovelha, DEC-252):** servi-la na janela de gorjeta nas noites secas soma vínculo,
  e um vínculo alto muda uma linha do final (`ending.md`, "Marigold"). **Reserva do MVP** se o Quentin não puder aparecer à noite (C2).
  Cuidado: ela é anomalia de "atender". Uma escolha sim/não com ela não pode ensinar o contrário do verbo ("Never refuse her").
  Por isso o arco dela seria **sem botões**: o vínculo vem só de servi-la bem.
- **Walt por telefone (CHR-001):** respostas sim/não em 2 ou 3 ligações mudam falas dele e o tom do final. Isso exige voz nova
  (`frank`, sem número de telefone) e mexe em `script.md` e `ending.md` (Aprovado). Fica para a fase 2.

## 6. Regras das recompensas (`Q-278`)

1. **Utilidade leve + lembrança.** Cada arco dá no máximo uma utilidade de sobrevivência ou economia e uma lembrança (objeto no trailer
   e linha no diário).
2. **Nunca decide uma anomalia:** não muda prazo, verbo, sinal ou zona. Não dá imunidade a jumpscare nem a desmaio. Não pula
   ocorrência. Não revive (o Revive Kit continua sendo a única forma, DEC-258).
3. **Nunca aparece no HUD** como número.
4. **Teto econômico:** a soma do dinheiro de todos os arcos fica em **≤ 5%** do ganho de uma run solo (~$820, `economy.md` §5.0). Ver §7.
5. **Nenhuma Tool nova:** as recompensas são passivas ou objetos do mundo. A hotbar de 4 (DEC-174) não muda.

## 7. Balanceamento comparável

| Arco | Dinheiro extra (máx.) | Custo da gentileza | Utilidade de sobrevivência | Lembrança |
|---|---|---|---|---|
| Opal | $0 (+$4 em café equivalente) | $0 | +10 de sanidade uma vez (N2+); +2 doses de café por noite (N7–N10); atalho ≤ 70% do caminho (N7–N10) | garrafa térmica, bilhetes, cachecol do Walt |
| Pickett | $2 + $12 = **$14** | $0 | uma pista de leitura na N5 (atenção, não resposta) | relógio |
| Quentin | devolução ≤ ~$10–20 + gorjetas ≤ $6 ≈ **$26** | ~$1,25 de estoque por gentileza (≤ 2) + o $5 do "Nice catch!" que não ganha (1×) ≈ **$7,50** | recanto 1–2 s mais perto na família B (2 vagas) | Alley Key |
| **Total** | **≤ ~$40** | ≤ ~$7,50 | — | — |
| % da run solo (~$820) | **≤ ~4,9%** (líquido ≤ ~3,9%) | | | |

Comparação: um pacote de dinheiro em Robux pequeno dá $60 (`cash_100`, `economy.md` §5.0). Os três arcos completos juntos rendem menos que isso.

Linha do tempo das recompensas (quando o jogador começa a sentir cada uma):

| Recompensa | Primeira noite possível | Batidas gentis necessárias |
|---|---|---|
| Café da Opal (+10) | N2 | 0 (é o efeito da própria batida) |
| Gorjeta extra do Pickett | N2 (+$2); N5 em diante (+$2 por visita) | 1; 2 |
| Aviso da cópia | N5 | 2 de 3 (`pickett_1` a `pickett_3`) |
| Quentin aliado + recanto | N4 (recanto a partir da N5) | 2 |
| Garrafa térmica | N7 | 2 de 4 |
| Porta lateral do Mart | N7 | 3 de 4 |
| Relógio do Pickett | N10 | 3 de 4 |

## 8. Dados (data-driven)

Proposta de `Content.Bonds` (o architect fecha os nomes no contrato). Só a descrição dos campos; sem código:

| Bloco | Campo | Descrição |
|---|---|---|
| `Rules` | `ResetPerRun` | `true` (`Q-276`) |
| | `ChoiceTime` | 20 s (por NPC dá para sobrescrever: Quentin 12) |
| | `Radius` | 12 studs (Opal 8) |
| | `SpillUntil` | minuto 1275 (9:15 PM) |
| | `BlockedFamilies` | `{ "B", "C" }` mais `anm_010_hush` (sem batida da Opal durante esses eventos) |
| | `Decider` | `"FirstClick"` (`Q-277`) |
| `Npcs[key]` | `Npc`, `Chr` | `NPC-020` / `CHR-003` etc. |
| | `Schedule` | só Pickett e Quentin: noites, janela de chegada (minutos), `ChatPoint` |
| | `Beats[]` | `Id`, `FromNight`, `Trigger` (`Visit` · `Served` · `Caught` · `Arrive`), `Requires` (vínculo mínimo/máximo), `Line`, `Options` {`Warm`, `Neutral`}: `Text`, `Bond` (+1/0), `Effects[]`, `Reply` |
| | `Rewards[]` | `Id`, `MinBond`, `FromNight`, `Effects[]`, `Note` (texto do bilhete) |
| Catálogo de efeitos | `Sanity` | `Amount`, `Target` (`Chooser` · `Party`) |
| | `Money` | `Amount`, `Kind` (`Tip` · `Gift`) |
| | `Stock` | `Item`, `Amount` (negativo = consome) |
| | `CoffeeDoses` | `Amount`, `PerNight` |
| | `UnlockDoor` | `DoorId` (`MKT-STAFF`) |
| | `EnableHideZone` | `ZoneId` (`QN-NOOK`), `Capacity` |
| | `Prop` | `PropId` (objeto que aparece no trailer: térmica, cachecol, relógio) |
| | `CallVariant` | chave de variante em `BossCalls` (ex.: `scarf`) |
| | `LineVariant` | troca o pool de falas de um NPC (ex.: Pickett depois do aviso) |
| | `TipPerVisit` | `Amount` |
| | `Refund` | `Counter` (`quentin_stolen_total`), `Min` |

| Extensão §15 | `Options.Rude` | opcional, no máximo 1 batida por NPC: `Text`, `Bond` (−1), `Hold` (1 s), `Cold` {`Nights`, `Effects[]`}, `Reply` |
| | efeito `Cold` | `Npc`, `Nights` (≤ 2), `ClearOnWarm` (`true`), `Mods` (ex.: `NoBalloon`, `TipPerVisit = 0`, `StealPct`, `Face = "Skeptical"`) |
| Extensão §14: `Content.Secrets` | `Secrets[key]` | `Place` (id do mapa), `Trigger` (`Prompt` · `HasItem` · `RegularsComplete` · `Counter`), `Requires` (ex.: `{ Item = "mustard_key" }`, `{ Regulars = 1, Revived = 1 }`), `Scope` (`Run` · `Profile`), `Effects[]` |
| | efeito `RunItem` | `ItemId` (ex.: `mustard_key`): item da party na run, sem Tool, guardado em `RunState.Counters` |
| | efeito `Cosmetic` | `CosmeticId` (ex.: `pet_pip`), `Scope = "Profile"` (por jogador, DataStore) |
| | efeito `Memento` | linha na página "Regulars"/"Secrets" do diário + objeto no mundo |
| | efeito `Decal` | troca uma textura de cenário (ex.: cartaz da delegacia) |
| `Content.Cosmetics.Pets` (novo) | `Id`, `Model`, `Offset` no ombro, `BobAmp`, `BobHz`, `Source` (`Secret` · `Shop` futuro) | dado do pet; sem atributo de jogo |

Estado (servidor, `RunState.Counters`, que já entra no snapshot): `bond_opal`, `bond_pickett`, `bond_quentin`,
`beat_<id>` (0 pendente · 1 gentil · 2 neutro · 3 rude), `cold_<npc>` (noites que faltam), `quentin_stolen_total`,
`pickett_copy_served`, `item_mustard_key`, `secret_<key>`. No perfil do jogador (persistente, architect): `Cosmetics.Pets`
(lista dos pets que o jogador tem) e `Cosmetics.EquippedPet`.
O `Validate` cobra: toda batida com 2 opções, `Bond` só 0 ou 1, `MinBond` ≤ número de batidas, efeitos só do catálogo,
a soma de `Money` de cada NPC ≤ teto do §6.4.

## 9. Escopo de implementação (estimativa)

| Peça | Reaproveita | Novo | Dono | Tamanho |
|---|---|---|---|---|
| `Content.Bonds` + `Validate` | padrão `Content.*` | tabela, catálogo de efeitos | game-designer + backend-coder | ~250 linhas de dado |
| `BondService` (servidor) | `RunState.Counters`, `EconomyService:AddSale`, estoque, cafeteira, `BossCalls` (variantes), avisos para a party (padrão `thief_caught`) | trava do 1º clique, agenda, efeitos | backend-coder | ~400 linhas |
| Prompts das batidas | `Content.Actions` + `PromptController` (2 ações: `bond_warm`, `bond_neutral`; texto pelo atributo `BondBeat` do NPC) | 2 linhas em `Actions` | backend + frontend | pequeno |
| `BondController` (client) | `SpeechBalloon`, `OpalController` (raio e balão), rosto `Happy` (`CrewRig.Dress`) | balão de resposta, aviso na borda no modo de preparo | frontend-coder | ~250 linhas |
| Pickett regular (NPC-021) | `CustomerService` (spawn que substitui um normal), rig rato (DEC-203), ANM-004 (escolha do original) | regra de horário no Calm, `CHAT-1`, 1ª cópia da N5 = Pickett | backend-coder | ~150 linhas |
| Quentin no anoitecer | `ThiefService` (estados), `Vision` (gatilho "visto"), `TipJar` | `Content.Thief` com janela `Dusk`, agenda fixa, estado `Caught` com espera de 12 s | backend-coder | ~150 linhas |
| Porta lateral do Mart | padrão de tranca do `TrailerDoorService` (`SetLocked`, SFX "Locked door"), `AutoDoor` | porta `MKT-STAFF` (folha + tranca) | level-designer + backend | 1 porta |
| Recanto do Quentin | `HideZone` / `Kit/Hide` da família B | zona `QN-NOOK` travada até o aliado; tábua solta | level-designer + backend | 1 zona |
| Objetos-presente | packs Kenney/KayKit (DEC-136) | térmica, cachecol, relógio na parede, chave (4 miniaturas, fichas `AST-###` novas) | art-director → modeler-3d | 4 peças pequenas |
| Página "Regulars" no diário | `Content.Journal` | 1 página com linhas por batida | frontend + narrative-writer | pequeno |
| Variante "scarf" do Walt | `BossCalls` (variantes) | 1 fala + voz `frank` | narrative-writer | 1 fala |

| Rude + "frio" (§15) | trava do 1º clique, `HoldDuration` do ProximityPrompt, `CrewRig.Dress` (rosto `Skeptical`) | 3ª opção, contador `cold_<npc>`, modificadores temporários | backend + frontend | ~120 linhas |
| Chave da mostarda + loja de brinquedos (§14, MVP) | `Content.Actions`/prompts, padrão de tranca do `TrailerDoorService`, `Fade` | caixa `MUSTARD-CRATE` com prompt, cadeado e correntes gigantes (animação de cair, cartoon), vitrine curta com a prateleira do pet | level-designer + backend + frontend | ~200 linhas + 2–3 peças de arte |
| Pet no ombro (§14, MVP) | padrão T40 (o client aplica o visual por atributo replicado), `ProfileService` (dado persistido), tela da loja/classes para equipar | `Content.Cosmetics.Pets`, `PetController` (segue o ombro com balanço leve, some no jumpscare e na cutscene), migração de perfil | architect + backend + frontend + modeler-3d | ~250 linhas + 1 modelo |
| Cartaz da delegacia (§14, opcional) | `Decal` | 2 texturas de cartaz | art-director + backend | pequeno |

Total estimado: **~1.200 linhas** e **7 a 9 TASKs** (task-planner) para os vínculos, mais **~570 linhas e 4–5 TASKs** para a extensão
recomendada (rude + chave + loja + pet). Hospital e estacionamento ficam fora da conta (§14.4). NPCs a mais: **+1** no Calm de toda noite (Pickett) e **+1**
nas noites 2/4/6/8 (Quentin). Nunca passam de 2 extras, os dois fora da janela de anomalias. O teto de 12 não muda.
Teto proposto para o servidor: **no máximo 2 NPCs de vínculo vivos ao mesmo tempo**. A Opal não conta (é só client, DEC-191).

## 10. Critérios de aceite

Sistema:
- Com `Content.Bonds` vazio, a run roda igual a hoje (nenhum spawn, prompt ou efeito novo).
- Nenhuma batida mostra número de vínculo, barra ou ícone de medidor no HUD.
- A escolha neutra nunca tira dinheiro, sanidade, estoque nem vínculo (teste: 100 escolhas neutras seguidas, saldo igual).
- Em party de 4, dois cliques no mesmo frame aplicam **um** efeito só; o segundo é ignorado sem erro.
- Uma batida em andamento quando começa uma anomalia de família B ou C cancela sem efeito e volta pendente na próxima oportunidade.
- Reconectar ou retomar o servidor (DEC-119) mantém vínculos e batidas respondidas (contadores no snapshot).
- Na run nova, todos os vínculos começam em 0 (`Q-276`).
- Nenhuma recompensa muda prazo, sinal ou verbo de anomalia, nem impede jumpscare ou desmaio. Teste: as 4 famílias com todas as recompensas ligadas dão os mesmos resultados de acerto e erro.
- Soma do dinheiro de todos os efeitos ≤ 5% de $820 (o `Validate` acusa se passar).
- Os prompts funcionam em PC (E/R), mobile (toque) e gamepad (X/Y); nenhum fica centralizado na tela; sem vermelho.

Opal:
- Com a persiana abaixada, nenhuma batida acontece.
- Cada batida aparece no máximo 1 vez por noite e só a partir da noite de liberação; uma pendente reaparece na próxima visita.
- Aceitar o café à noite dá +10 de sanidade só para quem clicou, sem passar do máximo da classe.
- Com vínculo 2, a N7 começa com a garrafa térmica no trailer e +2 doses na cafeteira, e isso se repete até a N10.
- Com vínculo 3, a porta `MKT-STAFF` abre de N7 a N10. Com vínculo menor, ela toca "Locked door" e não abre.
- A Opal nunca vende nada, nunca sai de trás do balcão e nunca vira anomalia.

Pickett:
- Em 10 noites simuladas, ele chega 1 vez por noite entre 8:05 e 8:30 PM e nunca ocupa o balcão depois de servido (vai ao `CHAT-1`).
- Com vínculo ≥ 2 na N5, a fala de aviso aparece **antes** da 1ª ocorrência da ANM-004, e essa ocorrência usa o Pickett como original.
- Com vínculo < 2, a N5 não tem aviso e a ANM-004 segue igual (DEC-247 intacta nos dois casos).
- Com vínculo ≥ 3, o relógio aparece no trailer na N10 e entra na página "Regulars".

Quentin:
- Ele aparece só nas noites da agenda, só no Calm, e nunca depois de virar aliado como ladrão.
- Ser visto por 1 s acumulado ou alguém chegar a 14 studs durante "ir/pegar" = pego em ≤ 0,5 s.
- "Enxotar" dá exatamente +$5 (DEC-050); "deixar ir" consome 1 pão e 1 salsicha se houver.
- Com 2 gentilezas, na mesma visita: devolução ≥ $5 (igual ao total roubado se for maior) e `QN-NOOK` ativo da noite seguinte até a N10.
- O `QN-NOOK` conta como esconderijo válido da família B para até 2 jogadores; o 3º não é protegido lá.

Consequências (§15):
- Escolher **neutro** em todas as batidas termina a run com vínculo 0 e **nenhum** efeito "frio" (nenhum contador `cold_*` acima de 0).
- O botão rude só existe nas 3 batidas marcadas e só dispara segurando 1 s. Tocar rápido não dispara nada.
- Depois de uma escolha rude, o efeito frio dura no máximo 2 noites e acaba antes se houver uma escolha gentil com o mesmo NPC.
- Uma escolha rude nunca tira recompensa já entregue, nunca mexe em sanidade nem em anomalia, e a perda de dinheiro somada fica em ≤ $10 por run.
- Em co-op, o aviso de escolha rude não mostra nome de jogador.

Segredos (§14):
- Olhar a caixa `MUSTARD-CRATE` dá a `mustard_key` para a party, 1 vez por run. Um 2º jogador recebe "Already found" e nada muda.
- Sem a chave, o cadeado da loja de brinquedos toca "Locked door" e não abre. Com a chave, qualquer jogador abre; as correntes caem em ≤ 2 s e a loja fica aberta até o fim da run.
- Cada jogador que usa a prateleira ganha `pet_pip` **uma vez para sempre** (perfil). Quem já tem recebe "Already yours".
- O pet não tem colisão, não bloqueia prompt nem visão, some durante o jumpscare e não mexe em nenhum número (teste: run com e sem pet dá os mesmos valores).
- Os outros jogadores veem o pet de quem o equipou (atributo replicado).

## 11. Falas e textos

Falas e rótulos: narrative-writer, 2026-10-16 (**Rascunho**, Provisório como o resto do documento). Tudo em inglês, sem "sausage",
sem número de telefone (AGENT-BRIEF §4), tom Mild (DEC-023, DEC-172). Limites usados:

| Tipo | Limite | Fonte |
|---|---|---|
| Balão do NPC | ≤ 70 caracteres (todas as falas abaixo ficam em ≤ 57) | NPC-020 / `characters.md` CHR-003 |
| Rótulo de botão (ActionText do ProximityPrompt) | ≤ 16 caracteres (alvo mobile); teto do pedido 18 | `ui-text.md` §1 (DEC-014) |
| Toast / aviso para a party | ≤ 40 caracteres com `{Player}` contado como ~10 | `ui-text.md` §10 |
| Legenda de ligação do Walt | ≤ 42 por linha | `ui-text.md` §10 |

Regra de voz: **Opal** fala seco, frases de 2 a 5 palavras, carinho escondido ("hon"). **Mr. Pickett** é nervoso e educado, exclama
demais, se corrige, sempre agradece. **Quentin** é vilão de desenho: inocência fingida, exagero, nunca ameaça de verdade.
Botão rude = **atrevido**, nunca insulto, nunca sobre aparência, nunca palavra que o filtro do Roblox possa pegar.

### 11.1 Batidas (fala, botões, respostas)

Botões: **E** = gentil, **R** = neutro, **segurar 1 s** = rude (só nas 3 batidas da §15). O `ObjectText` do prompt é o nome do NPC
("Opal", "Mr. Pickett", "Quentin").

| Batida | Fala do NPC | Gentil (+1) | Neutro (0) | Rude (−1, segurar) | Resposta gentil | Resposta neutra | Resposta rude |
|---|---|---|---|---|---|---|---|
| `opal_1` | "Seven letters. 'Yellow, goes on a dog.' Any idea?" | **Help her** | **Not now** | — | "MUSTARD. Huh. Walt always kept things under it." (`Happy`) | "Fine. I'll get it myself." | — |
| `opal_2` | "Long night? Have a cup. It's from my own thermos." | **Yes, please** | **No, thanks** | **Ugh, no way** | "Drink it hot. Cold coffee's just sad." | "Offer stands, hon." | "Suit yourself." (vira de costas, `Skeptical`) |
| `opal_3` | "Walt left his scarf. Again. Hang it in the trailer?" | **I'll take it** | **Can't, sorry** | — | "He'll pretend he didn't miss it. He did." | "I'll keep it here. It's used to waiting." | — |
| `opal_4` | "I see the whole street from here. You all okay?" | **We're okay** | **Just busy** | — | "Good. I'll keep watching." (quase sorri) | "Busy's fine. Keep it that way." | — |
| `pickett_1` | "Couldn't sleep. Will the grill be on every night?" | **Every night!** | **Till six** | — | "Splendid! I'm Pickett. Mr. Pickett. Hello!" (`Happy`) | "Till six. Right. Thank you, truly." | — |
| `pickett_2` | "Numbers all day. Numbers! How's your shift going?" | **Tell me more** | **Busy, sorry** | **Hurry up!** | "A seven looked like a one today. Chaos! Here, a tip." | "Of course! Another time." | "Oh. Sorry to bother." (`Stressed`) |
| `pickett_3` | "My father's watch. Left wrist, always. Never late!" | **Love it!** | **Nice watch** | — | "Never late, never early. That was Dad." | "Hm. Yes. It keeps good time." (ajeita o relógio) | — |
| `pickett_4` | "Someone with my face came by. Did you notice?" | **That wasn't you!** | **Didn't notice** | — | "Oh, thank goodness. I'm the only me. Phew." | "No? Good. Maybe I dreamed it." | — |
| `pickett_4`, variante `pickett_copy_served` ≥ 1 | (mesma fala) | (mesmo) | (mesmo) | — | "Don't worry. It fooled me too, and it's my face!" | "Don't worry. It fooled me too, and it's my face!" | — |
| `quentin_1` | "Whoops! Wrong jar! I was... counting it for you?" | **Have a hot dog** | **Off you go** | **Scram, bandit!** | "For me? Mmf... fank you! Best night ever!" | "Whoops! Going, going, gone!" | "Hmph! You'll see! You'll ALL see!" (foge emburrado) |
| `quentin_1`, sem pão ou salsicha no estoque | (mesma fala) | (mesmo) | — | — | "No buns? Next time, then. Still... thanks!" | — | — |
| `quentin_2` | "Um. Hi. Is that hot dog deal still... a deal?" | **On the house** | **Pay, please** | — | "On the HOUSE? I'll keep an eye out for you!" | "Fair. One, two, three... four coins. Exact!" | — |

Contagem dos botões (o mais longo): "That wasn't you!" = 16, "Scram, bandit!" = 14, "Have a hot dog" = 14.

### 11.2 Recompensas, avisos e estados

| Momento | Texto | Onde aparece |
|---|---|---|
| Garrafa térmica (N7, vínculo ≥ 2) | Bilhete: "From O. Keep warm." · objeto: "Opal's Thermos" | bilhete no balcão do trailer; nome do prop |
| Porta do Mart (N7, vínculo ≥ 3) | Bilhete: "Side door's open. Quicker. —O." · placa da porta: "STAFF ONLY" | bilhete no trailer; placa da porta `MKT-STAFF` (sem vínculo, só o SFX "Locked door", sem texto novo) |
| Aceno no Hush (N10) | sem texto (só luz e aceno) | — |
| Walt, variante `scarf` (voz `frank`, 2 linhas) | "Found my scarf on the hook." / "Wasn't cold anyway. Heh. Thanks, Rookie." | ligação seguinte, legenda "Walt" |
| Aviso do Pickett (N5, vínculo ≥ 2, sem botões) | "Saw a fellow dressed just like me. Backwards, though." | balão no `CHAT-1` |
| Pagamento do Pickett com vínculo ≥ 2 (`LineVariant`, N5–N10) | "Keep the change. Yes. All of it." | balão ao pagar |
| Relógio (N10, vínculo ≥ 3) | Fala: "Last night of your shift, huh? Keep this for me." · objeto: "Mr. Pickett's Watch" | balão; prop no trailer |
| Quentin aliado (2 balões seguidos) | "Okay. Here's every coin I took. Plus extra." → "And this key. Loose board in the alley. Good hiding spot." | balão, mesma visita |
| Quentin aliado (toasts) | "Quentin paid you back! +${amount}" · "Got the Alley Key!" | toast da party |
| Recanto `QN-NOOK` | prompt: ObjectText "Loose Board" (o verbo é o mesmo do `HideZone` atual) | tábua da cerca |
| Quentin pagante (aliado, datas que sobram) | "Paying like a gentleman! Keep the change." | balão ao pagar |
| Opal fria (≤ 2 noites) | **sem balão**, de costas, olhando a cruzada (§15) | — |
| Fim do frio da Opal (1ª visita depois) | "Coffee's still hot. If you want it." | balão sorteado da visita |
| Pickett frio (sem gorjeta) | **sem balão**: paga em silêncio e vai embora rápido (`Stressed`) | — |
| Fim do frio do Pickett | "Evening! Sorry about before. Long day." | balão ao chegar |
| Quentin ousado (volta depois do rude) | Espreitando: "Don't mind me. Going straight for it!" · fugindo: as falas atuais ("Thanks for the tip!") | balão |
| Aviso na borda (modo de preparo) | "Opal wants a word" · "Mr. Pickett wants a word" · "Quentin wants a word" | borda da tela |

### 11.3 Avisos para a party (toast, ≤ 40)

| Batida (gentil) | Toast | Rude (sem nome de jogador) |
|---|---|---|
| `opal_1` | "{Player} helped Opal." | — |
| `opal_2` | "{Player} had coffee with Opal." | "Opal looks hurt." |
| `opal_3` | "{Player} took Walt's scarf." | — |
| `opal_4` | "{Player} checked on Opal." | — |
| `pickett_1` | "{Player} said hi to Mr. Pickett." | — |
| `pickett_2` | "{Player} listened to Mr. Pickett." | "Mr. Pickett leaves quietly." |
| `pickett_3` | "{Player} liked the old watch." | — |
| `pickett_4` | "{Player} cheered up Mr. Pickett." | — |
| `quentin_1` | "{Player} shared a hot dog with Quentin." | "Quentin storms off." |
| `quentin_2` | "{Player} fed Quentin for free." | — |

### 11.4 Diário: páginas "Regulars" e "Secrets"

Título "Regulars", subtítulo "Folks who know your name." Título "Secrets", subtítulo "Only the curious find these."
Uma linha por batida gentil ou segredo achado:

| Chave | Linha |
|---|---|
| `opal_1` | "Helped Opal with her crossword." |
| `opal_2` | "Had coffee from Opal's thermos." |
| `opal_3` | "Hung Walt's scarf in the trailer." |
| `opal_4` | "Told Opal we're okay." |
| `pickett_1` | "Met Mr. Pickett. He can't sleep either." |
| `pickett_2` | "Heard about Mr. Pickett's numbers." |
| `pickett_3` | "Mr. Pickett's watch: left wrist, always." |
| `pickett_4` | "Told Mr. Pickett he's the only one." |
| relógio N10 | "Mr. Pickett left his dad's watch with us." |
| `quentin_1` | "Gave Quentin a hot dog, not a scolding." |
| Quentin aliado | "Quentin is on our side. Ask about the alley." |
| `mustard_key` | "Walt did say 'keys.' Found the other one." |
| loja aberta | "The toy shop's chains came right off." |
| pet | "{PetName} picked me. Or I picked it." |
| cartaz REFORMED | "Quentin's poster says REFORMED now." |

A linha do `pickett_3` repete de propósito o sinal da cópia (pulso esquerdo) sem dizer o que fazer (DEC-008).

### 11.5 Segredos (§14)

**Ligação com a cutscene:** a fala "Start today. Keys under the mustard." **não muda**. Ela ganha sentido em três passos, sem fala nova
do Walt: (1) na `opal_1` a resposta da cruzada é MUSTARD e a Opal comenta "Walt always kept things under it" (pista para quem
não lembrou da ligação); (2) o achado diz "keys" no plural com a chave velha; (3) a linha do diário fecha a piada ("Walt did say 'keys.'").

| Segredo | Texto | Onde |
|---|---|---|
| Caixa de mostarda | ObjectText "Mustard Crate" · ActionText **"Look under"** (segurar 1 s) | prompt da `MUSTARD-CRATE` |
| Achado | "An old brass key!" | balão/toast de quem achou |
| Achado (party) | "{Player} found an old key!" | toast da party |
| Já achada | "Already found" | prompt |
| Nome do item | **"Old Brass Key"** (etiqueta de papel amarrada, com um ursinho desenhado; o art-director decide se aparece) | diário, ícone |
| Cadeado, sem chave | ObjectText "Giant Padlock" · ActionText **"Unlock"** → "Locked tight. Needs a key." + SFX "Locked door" | prompt da porta `TOY-SHOP` |
| Cadeado, com chave | ActionText **"Unlock"** (segurar 1,5 s) → "Clunk! The chains fell off!" | toast da party |
| Letreiro da loja (sugestão) | "JUNIPER TOY BOX" | fachada (art-director/level-designer) |
| Prateleira do pet | ObjectText "Winged Plush" · ActionText **"Take"** | prompt |
| Pegou o pet | "{PetName} joined you!" | toast de quem pegou |
| Já tem | "Already yours" (+ apito de brinquedo) | prompt |
| Descrição do pet (tela de equipar) | "Found behind a giant lock. Very loyal. Very fluffy." | lobby |

**Nome do pet** (o id `pet_pip` não muda, só o nome exibido):

| Opção | Por quê |
|---|---|
| **Bunwing** (recomendado) | "bun" + "wing": diz o que ele é (pelúcia de hot dog com asinhas), fácil de ler e falar, combina com o jogo. Uma busca rápida não achou personagem com esse nome |
| Relish | tema de condimento; mas criança mais nova pode não conhecer a palavra |
| Dottie | fofo e curto; mas não liga com hot dog nem com asa |

### 11.6 Outros prédios (§14.3)

| Lugar | Texto |
|---|---|
| Delegacia, cartaz antes | "WANTED" / "QUICK QUENTIN" / "For: snack crimes" |
| Delegacia, cartaz depois | "REFORMED!" / "QUICK QUENTIN" / "Now a paying customer" |
| Hospital (fase 2), prompt | ObjectText "Card" · ActionText "Read" |
| Hospital, cartão | "Get well soon! Next nap, try a bed. —Bellmoor Rescue" (os dois médicos assinam com um carimbo "BR") |
| Estacionamento (fase 2), prompt | ObjectText "Old Cart" · ActionText "Look" |
| Estacionamento, verso da foto | "Ninth & Juniper, 1979. First night." |
| Estacionamento, bilhete no carrinho | "Still runs. Like me. Welcome to the regulars. —W." |
| Diário, fecho da página "Regulars" (3 completos) | "Walt's old cart. He kept it all this time." |

### 11.7 Notas do narrative-writer

1. **Opal sem balão sorteado no frio:** a §15 tira o balão dela; a fala de "fim do frio" (11.2) usa o balão sorteado da visita seguinte,
   sem regra nova. O mesmo para o Pickett (fala ao chegar). Se o game-designer preferir não ter fala de volta, basta apagar as 2 linhas.
2. **`opal_1` vira pista da chave:** a resposta da cruzada (MUSTARD) e a fala gentil apontam para a caixa. Isso não muda regra, mas
   enfraquece um pouco o "sem dica nenhuma" de §14.1 (só quem escolhe ajudar ouve). Recomendo manter; o dono decide junto com `Q-280`.
3. **"Pay, please"** troca o "pay like everyone" da intenção para caber e não soar como bronca. O efeito (cliente pagante, $4) é o mesmo;
   a resposta "four coins" supõe o pedido base de $4 da §5.3. Se o preço mudar, trocar a resposta por "Fair. Exact change, see?".
4. **Relógio do Pickett** é "Keep this for me" (empréstimo, não presente definitivo): deixa o gesto forte sem o Pickett abrir mão do
   relógio do pai. Não muda a mecânica (prop no trailer + linha no diário).
5. **Estacionamento (fase 2):** o bilhete do Walt e a foto de 1979 conversam com `ending.md` (Aprovado). Os textos de 11.6 são só
   rascunho e só entram com DEC e revisão do final.
6. **Toast de devolução do Quentin** usa `${amount}` (moeda do jogo, não Robux). O frontend confere a formatação da casa.
7. Todas as falas e rótulos precisam passar pelo `TextService`/filtro de chat do Roblox antes de ir para `Content.Bonds` (`Content.Secrets`).

## 12. Fora do MVP

Raincoat Lady e Walt (§5.4). Álbum persistente de lembranças entre runs (`Q-276`, alternativa). Médicos (CHR-008). Vínculo individual
por jogador (`Q-277` (C)). Batida com mais de 3 opções (a 3ª, rude, só nas 3 batidas da §15). Presente que vire Tool.
Segredos do hospital e do estacionamento (§14.4). Mais de um pet. Pet à venda.

## 13. Pendências

- `Q-276`: vínculo por run (recomendado) × persistente.
- `Q-277`: o primeiro clique decide pela party (recomendado) × voto × individual.
- `Q-278`: utilidade leve + lembrança, nunca decisiva (recomendado) × recompensas fortes.
- `Q-279`: elenco do MVP (Opal + Pickett + Quentin, recomendado) × incluir Raincoat Lady e Walt. Inclui (b): **Quentin no anoitecer**, que emenda DEC-050 e DEC-159.
- `Q-280`: chave da mostarda e pet da loja de brinquedos (chave por run e por party; pet persistente e por jogador).
- `Q-281`: segredos nos outros prédios (recomendado: só a loja no MVP; o cartaz da delegacia é opcional barato; hospital e estacionamento ficam para depois).
- `Q-282`: consequências sandbox (escolha rude explícita, leve e temporária × sem rude × penalidade forte); conflito com DEC-051.
- Ligadas: `Q-266` (ladrão desligado no modo anomalia), `Q-161` (ponto seguro), `Q-164` (humor dinâmico: o rosto `Happy` da resposta gentil é só de reação).
- Para os donos, depois das respostas: level-designer (`CHAT-1`, `MKT-STAFF`, `QN-NOOK`, medições; `MUSTARD-CRATE` e a fachada da loja de brinquedos no MAP-01), architect (contrato `Content.Bonds`/`Content.Secrets`, ações, contadores, `Cosmetics` no perfil), art-director (4 miniaturas + cadeado e correntes gigantes + pet + cartaz), narrative-writer (§11), task-planner (TASKs), secretário (ficha FEAT-042 em `features.md`; nota em NPC-007/020/021).

---

## 14. Segredos do bairro (extensão, 2026-10-16)

Pedido do dono: a fala do Walt "a chave está embaixo da mostarda" vira um segredo de verdade. Atrás do trailer há uma caixa de
mostarda; ali fica uma **chave secreta**, que abre a **loja de brinquedos** trancada com cadeado e correntes gigantes. Dentro dela
está um **pet pequeno que voa sobre o ombro**. Os outros prédios do mapa podem ter segredos parecidos.

### 14.0 O que já existe (conferido só por leitura)

| Item | Onde | Estado |
|---|---|---|
| Fala "Start today. **Keys under the mustard.**" | `script.md` §1 (ligação da cutscene, fala 3); `Content/Cutscenes.luau` (fala do Walt aos 27,1 s); voz gerada em `VoiceLines` | existe, **sem mecânica**: nada no jogo usa essa chave. O roteiro antigo (§1.1, histórico) dizia "Keys are under the mustard" |
| Caixa de mostarda atrás do trailer | — | **não aparece** em `MAP-01.md` nem em `src/` (grep). Deve ser edição à mão no Studio ou peça de decoração sem nome. O level-designer confere e dá o id `MUSTARD-CRATE` |
| Loja de brinquedos, hospital, delegacia | — | **não aparecem** em `MAP-01.md`. Devem estar nos prédios do reagrupamento do Studio (`Buildings`, commit `5f19741`). O level-designer registra os ids `TOY-SHOP`, `HOSP`, `POLICE` |
| Estacionamento | `MAP-01.md` Z-05 | existe. Tem a vaga AN-01 (era o carrinho sob lona, que saiu com DEC-224/DEC-250) e o spawn oculto AS-1. **Nada de segredo perto do AS-1**, porque ali nascem atores de anomalia |

Leitura adotada (Provisória): a fala continua igual. "Keys" no plural vira a piada: uma chave é a do trailer (implícita, como hoje)
e a outra, velha e de latão, é o segredo. Sem fala nova e sem voz nova.

### 14.1 Chave da mostarda (MVP)

| Regra | Valor (Provisório) |
|---|---|
| Gatilho | prompt **"Look under"** (segurar 1 s) na caixa `MUSTARD-CRATE`, a qualquer hora de qualquer turno. **Sem dica na tela**: a única pista é a fala do Walt (DEC-008, descoberta) |
| Achado | "An old brass key!" + som curto. Vira o item `mustard_key` **da party, na run** (sem Tool, sem slot da hotbar, DEC-174). Um ícone pequeno de chave aparece no diário |
| Quantas vezes | 1 por run. Depois, o prompt diz "Already found" |
| Em co-op | quem achar primeiro, acha para todos. Aviso para a party: "{Player} found an old key!" (achado positivo, pode ter nome) |

### 14.2 Loja de brinquedos e pet (MVP)

| Regra | Valor (Provisório) |
|---|---|
| Fachada | vitrine com brinquedos apagados; porta com **cadeado gigante** (≈ 3 studs) e **correntes gigantes** em X, estilo desenho, Mustard e Ink (sem vermelho). Visível da calçada |
| Sem chave | prompt "Unlock" → "Locked." + SFX "Locked door" (que já existe) |
| Com chave | qualquer jogador da party abre (segurar 1,5 s). O cadeado salta, as correntes caem com som de lata (≤ 2 s) e a porta abre para um **vestíbulo curto** (≈ 6 × 4 studs) com uma prateleira. Fica aberta até o fim da run |
| Quando | em qualquer turno, **menos** durante anomalia ativa das famílias B ou C e durante o Hush. À noite atravessar a rua tem o risco normal (sanidade, anomalias); a loja não é ponto seguro |
| Prateleira | prompt "Take" no pet de brinquedo. **Cada jogador** que usar ganha o pet `pet_pip` **no perfil, para sempre**. Quem já tem: "Already yours" |
| Pet | criatura **original** pequena (≈ 0,8 stud), voa sobre o ombro com balanço leve (amplitude 0,15 stud, 1,2 Hz) e olha para onde o dono olha. Sugestão para o art-director: um bichinho de pelúcia com asinhas e o hot dog do logo (DEC-206) bordado. Nome: **Bunwing** (recomendado pelo narrative-writer, §11.5; o id `pet_pip` não muda) |
| Vantagem | **nenhuma**. Sem colisão, sem som em loop, não acende luz, não avisa de anomalia, não entra no jumpscare nem nas cutscenes. Equipar e desequipar no lobby (tela de classes/perfil). Os outros jogadores veem |
| Exclusivo | não é vendido em Robux nem em gemas. Só existe por este segredo (`Q-280` c) |
| Runs seguintes | a chave e a loja voltam a cada run (é gostoso repetir). Quem já tem o pet ouve um apito de brinquedo e recebe "Already yours". Na fase 2, a prateleira pode sortear um 2º pet |

### 14.3 Segredos nos outros prédios (proposta, 1 por lugar)

"Regular completo" = Opal com vínculo ≥ 3, Pickett com vínculo ≥ 3 ou Quentin aliado (de 0 a 3 na run).

| Lugar | Gatilho | O que acontece | Recompensa | Custo | Quando |
|---|---|---|---|---|---|
| **Delegacia** (`POLICE`) | o Quentin aparece pela 1ª vez (N2) → um cartaz "WANTED" dele surge no mural da fachada. Quando ele vira aliado, o cartaz troca para "REFORMED!" com ele sorrindo | só troca de textura (efeito `Decal`) | lembrança + piada visual; linha no diário | **baixo**: 2 texturas e 1 condição | opcional, logo depois do MVP |
| **Hospital** (`HOSP`) | alguém da party foi revivido na run **e** a party tem ≥ 1 Regular completo → na manhã seguinte à noite do resgate (Prep), um cartão "Get well soon" aparece colado na porta do hospital, assinado pelos médicos (CHR-008) | prompt "Read" no cartão | lembrança (diário) | médio: prop, prompt, condição de reviver | fase 2 |
| **Estacionamento** (vaga AN-01) | **3 Regulares completos** na run → na N10, janela Last (5–6 AM), a lona da vaga AN-01 levanta e mostra o **carrinho antigo do Walt** com a foto de 1979 (`characters.md` CHR-001; `ending.md` cita a foto no trailer) | prompt "Look" | lembrança forte de história; a página "Regulars" fecha com uma frase do Walt | **alto**: o carrinho saiu do jogo (DEC-224/250), mexe na luz da N10 e conversa com `ending.md` (Aprovado) | fase 2, só com aprovação do narrative-writer |

### 14.4 Opinião de custo e benefício (pedida pelo dono)

- **Vale a pena: chave da mostarda + loja + pet.** Usa uma fala que já está gravada e hoje não leva a nada. Dá ao jogador uma
  descoberta "só quem prestou atenção acha", que é o pilar DESCOBRIR e o "Must notice things" do panfleto. O pet persistente e
  visível para os outros é o tipo de status que faz criança contar para o amigo e voltar. O custo é baixo: 1 prompt, 1 tranca,
  1 modelo, 1 campo de perfil.
- **Vale como extra barato: o cartaz da delegacia.** Fecha o arco do Quentin com uma piada visual por quase nada.
- **Não vale agora: hospital e estacionamento.** Ficam longe da rota do trailer. À noite quase ninguém vai lá (custa sanidade e
  arrisca anomalia), então pouca gente veria. Os dois exigem prop, luz e texto novos, e o do estacionamento mexe no final aprovado.
  Melhor medir primeiro se os jogadores acham a loja.
- **Corte recomendado (Provisório, `Q-281`):** MVP = chave + loja + pet. Depois do MVP, se sobrar tempo, o cartaz. Hospital e
  estacionamento ficam na fase 2, decididos pelos dados de playtest (quantos acharam a chave).

## 15. Consequências (sandbox, extensão 2026-10-16)

Pedido do dono: o jeito como o jogador trata certos NPCs deve ter consequência negativa também. **Meio-termo proposto:**

1. **O neutro continua sem perda nenhuma** (§3). Quem só não quis conversar não é punido.
2. **A grosseria é explícita**: em **1 batida por NPC** aparece um 3º botão, rotulado como rude e acionado só **segurando 1 s**
   (os outros dois são toque). Ninguém é rude sem querer.
3. **A consequência é leve, legível e temporária**: o NPC fica **"frio"** por no máximo **2 noites**, ou até a próxima escolha
   gentil com ele. O vínculo cai 1 (nunca abaixo de 0). O jogador vê o resultado no NPC (rosto, silêncio, fala), nunca num número.
4. **Nunca trava progresso**: uma escolha rude tira no máximo 1 ponto, e cada arco tem batidas de sobra para recuperar a recompensa
   menor. Recompensa já entregue não é tirada. Sanidade e anomalias nunca são afetadas.

| NPC | Batida com rude | Consequência "fria" (≤ 2 noites ou até uma escolha gentil) | Custo máximo | O que o jogador vê |
|---|---|---|---|---|
| Opal | `opal_2` (recusar o café com grosseria) | vínculo −1; ela fica **sem balão** e de costas (rosto `Skeptical`) nas visitas; a batida seguinte só libera depois do frio. A porta lateral (≥ 3) fica difícil: precisa das outras 3 gentis | nenhum dinheiro | Opal calada, de costas, olhando a cruzada |
| Mr. Pickett | `pickett_2` (apressar ele) | vínculo −1; **sem gorjeta nenhuma** (nem a normal de $1) nas 2 visitas seguintes; rosto `Stressed`; fala curta de desculpa | ≤ $2–4 | Pickett paga em silêncio e vai embora rápido |
| Quick Quentin | `quentin_1` (enxotar com grosseria) | ainda dá o +$5 (DEC-050); vínculo continua 0; na próxima data ele volta **mais ousado**: espreita 20 s (era 40), rouba **75%** do pote (era 50%) e só é pego chegando perto (o "visto por 1 s" não vale nessa vez) | ≤ +$5 a mais roubado (pote de $20) | balão "You'll see!" e, na volta, o Quentin indo direto ao pote |

Somando os três, a perda máxima é **≤ ~$10 por run** (~1,2% da run solo). O dinheiro do frio nunca entra no HUD como penalidade
nomeada: é só gorjeta que não veio ou moeda que sumiu do pote.

**Co-op:** vale a mesma trava do primeiro clique (`Q-277`). Para um jogador não "estragar" a party por birra, o rude exige segurar
1 s, e o aviso para a party **não mostra o nome** ("Opal looks hurt."). Risco que fica: um jogador pode ser rude de propósito.
O custo máximo de ~$10 e 1 ponto de vínculo limita o estrago.

**Conflito com DEC-051** (sem reputação, sem medidor no HUD): com perda, o vínculo escondido fica mais parecido com "reputação
por NPC". A proposta segue a letra da DEC (nada no HUD, nada na nota do turno, nenhum recurso novo), mas pode ir contra o espírito
dela. **O dono precisa dizer se aceita** (`Q-282`). Também com DEC-023 e DEC-172 (tom Mild, público infantojuvenil): as falas rudes
são grosseria de desenho, nunca insulto, xingamento ou humilhação. O narrative-writer escreve e passa pelo filtro de texto do Roblox.
