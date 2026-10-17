Status: Em revisão (DEC-278, 2026-10-17: excessivo e confuso; a refazer com menos anomalias e mais claras; tipos que se confundem com o fluxo vetados; erro tira sanidade, não derruba, DEC-277). Antes: Rascunho (game-designer, 2026-10-17). Base: pedido do dono `source/2026-10-17-restaurante-brief.md` + esboço `source/2026-10-17-restaurante-esboco.webp`. Valores **Provisórios** até DEC.
Mantém a estrutura Aprovada da V2 (`anomalies-v2-proposal.md`: 4 famílias DEC-254, erro = jumpscare + desmaio DEC-255, jumpscare cartoon DEC-256, atmosfera fixa por noite DEC-257) e DEC-261 (recusar = fechar a janela). Nada aqui emenda DEC; onde a mudança pede DEC, há `Q-330..Q-339` no §8.

# Anomalias V3 — o restaurante ("Overcooked de anomalia")

O trailer vira um pequeno restaurante: **4 tablets de atendimento** no balcão da frente, **mesa de montagem** com 8 pratos no centro, **grelhas / estoque de salsichas / pão e condimentos** na parede do fundo, **porta saída** à esquerda dos tablets, **4 mesas de piquenique** na frente e **drive-thru** na lateral direita com computador de atendimento.
Objetivo deste documento: (1) dizer o que acontece com ANM-001..020 no novo layout, (2) propor ANM-021+ que usem o novo fluxo e o co-op, (3) atmosferas, (4) pacote MVP.

## 0. Regras de projeto (valem para todas as fichas)

1. **Sinal em 1 s, resposta em 5–30 s** (V2 §2). Nenhuma anomalia pede mais de 1 verbo.
2. **Respostas permitidas** (sem verbo novo de sistema): **RECUSAR** (fechar o guichê), **ESCONDER** (zona `HideZone`), **RELIGAR** (disjuntor / válvula / interruptor = prompt de segurar), **DESCARTAR** (lixeira, já existe da ANM-002) e **NÃO MEXER** (não abrir, não tocar, não sair: o "nada" com risco que ANM-006/008/009 já usam). Ver `Q-339`.
3. **Erro = jumpscare cartoon 0,6 s + desmaio** (`Fainted`, revivível com Revive Kit) de **quem agiu** (DEC-204). Omissão: custo de jogo (pedido perdido, slot ocupado, fila parada), não desmaio, salvo onde a ficha diz.
4. **Mild** (DEC-172): sem sangue, sem arma, sem ferimento; criaturas e comida "errada" em estilo cartoon (gosma verde, olhos a mais). Câmera corta antes do contato (DEC-248). Jumpscare é consequência de erro, não susto aleatório (DEC-256 sobre DEC-173): os sustos sem verbo (família D) **não** usam rosto em tela cheia.
5. **Data-driven**: cada anomalia é uma linha em `Content.Anomalies` + uma regra em `Rules/<Ref>.luau` + no máximo um módulo fino sobre um Kit. Variação nova = linha nova.
6. **Teto de atores** (DEC-045, `Flow.MaxActorsNight = 3`): continua 3 atores de anomalia por servidor. Teto de NPCs da noite no restaurante: §6.3.

### 0.1 Escala de custo

| Custo | Definição |
|---|---|
| **P** | 1 linha de dado + regra + ≤ 50 linhas sobre Kit existente; ≤ 1 dia de agente |
| **M** | um prompt/estado novo ou VFX/rig simples novo + módulo fino; 1–3 dias |
| **G** | sistema novo (NPC com IA própria, rede nova); > 3 dias |

Todos os custos **supõem que o restaurante já existe** (tablets, pratos, mesas, drive-thru e porta saída são features do mapa/fluxo, fora deste doc) e que cada interação nova passa por `InteractionService.Performed` → evento `Action` do `AnomalyService` (já existe, `Api.luau`). Assim, quase toda anomalia nova escuta `Action` com o nome da ação e a âncora, sem contrato novo.

### 0.2 Peças do mapa que as anomalias exigem (para o level-designer)

| Peça | Para quê | Anomalias |
|---|---|---|
| **Guichê por tablet** (persiana de enrolar, 4) + **persiana da janela do drive-thru** | verbo RECUSAR (DEC-261): fechar o guichê manda embora quem está naquele tablet/janela | família A, 021, 022, 031, 032 |
| **Lixeira da cozinha** (BIN-K), perto da montagem | DESCARTAR | 002, 024, 027 |
| **Despensa / câmara fria** (canto do fundo, porta própria) com `HideZone` | ESCONDER dentro do prédio | 007, 017, 018, 019 |
| **Disjuntor externo** na parede de fora (lado da porta saída) | RELIGAR fora da cozinha (tira alguém do posto) | 020, 035 |
| **Interruptor da cozinha** (parede, ao lado da montagem) | luz (ANM-003), 2ª chave da 035 | 003, 035 |
| **Válvula de gás** da grelha (parede, 4 studs da grelha) | RELIGAR/desligar | 025 |
| **Postes / luminárias das mesas** em grupos `HushOff` (1 por mesa + 1 na entrada) | escuro gradual, zona de luz | 010, 020, 028 |
| **Porta saída** com estado aberta/fechada e tranca de anomalia | não abrir / tranca | 004, 009, 028, 030 |
| **Ponto de luz externo** (`LIT-OUT`, luminária sobre a porta saída) | zona segura lá fora | 028 |

## 1. ANM-001..020 no restaurante

Legenda: **Mantém** = muda só a âncora/posição (dado). **Adapta** = gatilho ou resposta reescritos. **Sai** = fora do restaurante.

| ID | Nome | Fam. | Veredito | Gatilho no restaurante | Resposta correta no restaurante | Custo da adaptação |
|---|---|---|---|---|---|---|
| ANM-001 | Sem rosto | A | **Mantém** | cliente chega a um **tablet** (ou motorista na janela do drive-thru) | **fechar o guichê daquele tablet** (ou a persiana do drive-thru). Erro: "Take Order" no tablet. Extra barato: a nota do HUD abre **em branco**, sem pop-ups | P (evento `Shutter` passa a levar o índice do guichê) |
| ANM-002 | Comida errada | A | **Adapta** | o item alterado nasce **na grelha** (salsicha cinza-azulada) ou **num prato da montagem** (pão mordido com mofo cartoon) | **descartar** na lixeira BIN-K. Erro: **entregar na mesa** o prato com o item; desmaia quem entregou | M (`KitchenService:Alter` troca `rail/board` por `grill/plate`) |
| ANM-003 | Relógio parado + sino | C | **Adapta** | igual (relógio do banco, visto pela frente); os postes **e as luminárias das mesas** apagam | **apagar o interruptor da cozinha** antes do 3º sino. Erro: luz acesa no 3º sino → enxame cartoon de mariposas entra pelos tablets; desmaia **quem está dentro do prédio** | P (troca o switch do trailer pelo da cozinha) |
| ANM-004 | A cópia | A | **Adapta** | o original pede no tablet e senta; 8–12 s depois a **cópia** (olhos brancos, roupa espelhada, DEC-245) vem a **outro tablet** | **fechar o guichê** da cópia. Erro (servir a cópia): **porta saída tranca** (DEC-247 trocando "porta do trailer" por "porta saída"); a cópia bate 3× nela; **abrir** = agarrão + desmaio. Efeito co-op: entregas param ~12 s | M (tranca de anomalia passa para a porta saída) — `Q-336` |
| ANM-005 | Raincoat Lady | A | **Mantém** | pede no tablet e **senta numa mesa** pingando (DEC-251: só noite sem chuva) | **atender e entregar na mesa** antes da paciência. Erro: fechar o guichê nela; paciência esgotada = desmaio de todos os ativos (como hoje) | P (paciência passa a contar até a entrega na mesa) |
| ANM-006 | The stalker | D | **Adapta** | figura alta do outro lado da rua, visível pelo vidro dos tablets e de quem entrega nas mesas | **não encarar**. Passo a cada 1,2 s de olhar; 6 passos até o **balcão dos tablets**; pula e ataca o mais próximo. Se **os 4 guichês** estiverem fechados, bate no vidro e vai embora | P (`StalkerPath` no quadro `RestaurantFront`) |
| ANM-007 | The Walker | B | **Adapta** | aviso (luzes piscam, rádio "Hide!"); o Walker vem pela rua até o vidro dos tablets | **esconder na despensa** (`HideZone`) em 9 s. Quem estiver nas mesas tem que entrar pela porta saída: corrida boa | P (zona + caminho) — `Q-331` |
| ANM-008 | Carro comprido | D | **Adapta → drive-thru** | o carro comprido **entra na pista do drive-thru** e para na janela, farol alto para dentro da cozinha | **fechar a persiana do drive-thru** antes do farol (8 s) e não reabrir até ele sair (15 s). Erro: persiana aberta = desmaia quem está no cone do farol (zona da janela + 10 studs); reabrir antes = desmaia quem abriu | M (caminho do carro e zona trocados; persiana do drive-thru no lugar do shutter) |
| ANM-009 | A batida | D | **Adapta** | batidas e "Rookie? It's me." na **porta saída** | **não abrir** a porta saída por 12 s. Erro: abrir = desmaio de quem abriu. Quem está lá fora espera na luz `LIT-OUT` (sem risco) | P (escuta `Action` da porta saída) |
| ANM-010 | The Hush | C | **Adapta** | as luminárias das mesas apagam **uma por uma**, da rua para o prédio (~15 s) | **estar dentro do prédio** (cozinha ou despensa) quando a última apaga, e ficar até voltarem (~20 s). Clientes sentados somem e voltam. Erro: estar fora = desmaio | P (`safe_spot` via `InZone` do prédio, ponto `RST`) — `Q-337` |
| ANM-011 | Tremendo | A | **Mantém** | tablet ou drive-thru | fechar o guichê | P (dado) |
| ANM-012 | Pescoço invertido | A | **Mantém** | tablet ou drive-thru | fechar o guichê | P |
| ANM-013 | Olhos brancos | A | **Mantém** | tablet ou drive-thru | fechar o guichê | P |
| ANM-014 | Cabeça errada | A | **Mantém** | tablet; no drive-thru a cabeça **não cabe** na janela do carro (bom sinal) | fechar o guichê | P |
| ANM-015 | Flutuando | A | **Mantém** | só **tablet** (no carro não se vê o chão) | fechar o guichê | P |
| ANM-016 | Não pisca | A | **Mantém** | tablet ou drive-thru; segue o jogador mais próximo | fechar o guichê | P |
| ANM-017 | Rastejador | B | **Adapta** | vem de quatro **entre as mesas** até o vidro | esconder na despensa | P (caminho) |
| ANM-018 | O Sorriso | B | **Adapta** | o rosto enorme sobe **na janela do drive-thru** (era a janela de serviço) | esconder na despensa | P (âncora) |
| ANM-019 | Sombra no teto | B | **Adapta** | passos no teto do restaurante, desce pela **porta saída** | esconder na despensa | P (caminho) |
| ANM-020 | Falha de energia | C | **Adapta** | tudo apaga (cozinha, mesas, letreiro) | **religar o disjuntor externo** (sair pela porta saída, segurar E 3 s). 30 s sem religar = vulto ataca **quem está dentro do prédio**. Força alguém a largar o posto | P (ponto do disjuntor) — `Q-332` |

**Saem:** nenhuma. Todas cabem com troca de âncora; o que muda de natureza é ANM-008 (vira anomalia do drive-thru) e a ANM-004 (a tranca passa a travar as entregas).
**Ordem de adaptação sugerida:** onda R1 = 001, 005, 007, 009, 011–020; onda R2 = 002, 003, 004, 006, 008, 010 (dependem de cozinha/porta/drive-thru prontos).

## 2. Anomalias novas (ANM-021 a ANM-035; ANM-036..040 ficam reservadas)

Resumo:

| ID | Nome | Onde | Fam. / verbo | Engaja | Solo | Custo | Estreia |
|---|---|---|---|---|---|---|---|
| ANM-021 | A nota que se escreve sozinha | tablet → montagem | A / recusar ou descartar | 2 (atendente + montador) | sim | M | N4 |
| ANM-022 | Cliente que fala errado | tablet | A / recusar | 1 | sim | P | N1 |
| ANM-023 | Tablet que chama sozinho | tablet vazio | D / não mexer | 1 | sim | P | N2 |
| ANM-024 | O prato a mais | montagem | A / descartar | 1–2 | sim | M | N3 |
| ANM-025 | Chama verde | grelha | C / desligar a válvula | 1–2 | sim | M | N5 |
| ANM-026 | A caixa que bate | estoque de salsichas | D / não mexer | 1 | sim | P | N2 |
| ANM-027 | Condimento errado | condimentos | A / descartar | 1 | sim | P | N3 |
| ANM-028 | Trancado lá fora | porta saída + mesas | C / ficar na luz (+ colega abre) | 2 | sim (mais lento) | M | N6 |
| ANM-029 | O convidado sentado | mesas | D / não chegar perto | 1–2 | sim | M | N5 |
| ANM-030 | Todas as mesas olham | mesas + porta saída | D / não sair | 1–4 | sim | P | N3 |
| ANM-031 | Carro sem motorista | drive-thru | A / recusar | 1 | sim | P | N2 |
| ANM-032 | A fila que não acaba | drive-thru | A / recusar | 1 | sim | M | N6 |
| ANM-033 | Não faça carinho | drive-thru → cozinha | D / não tocar | 1–4 | sim | M | N4 |
| ANM-034 | O ajudante | qualquer estação | D / largar o posto | 1–2 | sim | M | N7 |
| ANM-035 | Queda dupla | disjuntor externo + interruptor | C / religar em dupla | 2 | sim (janela maior) | M | N8 |

---

### ANM-021 — A nota que se escreve sozinha

| Campo | Conteúdo |
|---|---|
| Família / verbo | A / **recusar** no tablet **ou descartar** o prato depois |
| Gatilho | Durante o mini-diálogo de um cliente comum no tablet, depois do 2º pop-up, a nota do HUD ganha um pop-up que **ninguém disse**: ícone fora do cardápio (olho, chave, meia, dente de leite — cartoon). O tablet dá um chiado e a fala do cliente para 1 s |
| Sinais | pop-up com moldura **tinta escorrida**; o texto da linha vira rabisco; som de lápis riscando sozinho |
| Resposta correta | (1) atendente **fecha o guichê** antes de confirmar; ou (2) se confirmou, o prato chega à montagem com billboard **preto**: qualquer um **descarta** o prato na BIN-K em até **15 s** |
| Punição | 15 s sem descarte: o billboard "abre um olho" e **desmaia quem confirmou o pedido** (DEC-204) + quem estiver segurando o prato. Montar e entregar o prato preto = desmaio de quem entregou |
| Omissão | não existe: o prazo de 15 s é a omissão (ver punição) |
| Engaja | 2: atendente (primeira chance) e montador (segunda chance). Bom momento co-op: "joga fora o prato preto!" |
| Solo | sim: o mesmo jogador tem as duas chances |
| Números | pop-up falso no passo 3 de 3–5; prazo 15 s; peso 1; NpcCost 0 (cliente comum, a anomalia é a nota) |
| Custo | **M**: cliente comum + hook no diálogo do tablet (inserir 1 pop-up de `Content`) + prato marcado `Altered` (reusa o fluxo de descarte da ANM-002) |
| Aceite | (a) o pop-up falso usa ícone que não existe em `Content.Items`; (b) fechar o guichê antes de confirmar resolve sem desmaio; (c) descartar o prato preto em ≤ 15 s resolve; (d) aos 15 s desmaia quem confirmou, uma vez; (e) entregar o prato preto desmaia quem entregou |

### ANM-022 — Cliente que fala errado

| Campo | Conteúdo |
|---|---|
| Família / verbo | A / **recusar** |
| Gatilho | Cliente no tablet responde ao "Hello!" com falas trocadas: repete **exatamente** a fala do jogador, diz as palavras de trás para frente ("dog hot a like I'd") ou pede "the one who works here" |
| Sinais | legenda com letras espelhadas ou a fala do jogador ecoada; voz um tom abaixo; a nota fica parada (nenhum pop-up entra) |
| Resposta correta | **fechar o guichê** daquele tablet |
| Punição | confirmar o pedido ("Take Order") = desmaio de quem confirmou |
| Omissão | deixar esperando: sem desmaio; ocupa o tablet até a paciência acabar (45 s) |
| Engaja | 1 (atendente) |
| Solo | sim |
| Números | 3 variantes de fala (texto em `Content`, sem voz nova obrigatória); paciência 45 s; peso 2; NpcCost 1 |
| Custo | **P**: Kit `CustomerActor` (Verb refuse) + variante de diálogo como dado. É a anomalia de tutorial do tablet |
| Aceite | (a) as falas vêm de uma tabela; (b) fechar o guichê resolve; (c) confirmar desmaia quem confirmou; (d) a nota não recebe pop-up |

### ANM-023 — Tablet que chama sozinho

| Campo | Conteúdo |
|---|---|
| Família / verbo | D / **não mexer** |
| Gatilho | Um tablet **sem cliente na frente** acende, toca o "ding" de cliente e a tela mostra "Hello? I'd like…" |
| Sinais | ninguém no tapete do tablet; a tela pisca em verde-água; o prompt "Take Order" aparece mesmo assim |
| Resposta correta | **ignorar** por 12 s; o tablet apaga sozinho |
| Punição | interagir com o tablet durante os 12 s = desmaio de quem interagiu |
| Omissão | — (ignorar é o certo) |
| Engaja | 1 (atendente) |
| Solo | sim |
| Números | duração 12 s; só em tablet livre; peso 1; NpcCost 0 |
| Custo | **P**: estado do tablet + escuta `Action` "tablet_take" naquela âncora (mesmo padrão da ANM-009) |
| Aceite | (a) só dispara em tablet livre; (b) interagir nele em ≤ 12 s desmaia quem interagiu; (c) aos 12 s volta ao normal |

### ANM-024 — O prato a mais

| Campo | Conteúdo |
|---|---|
| Família / verbo | A / **descartar** |
| Gatilho | Aparece na mesa de montagem um **9º prato** (fora dos 8 slots, na ponta da bancada), já montado, com billboard de pedido em **letra de mão tremida** e nome de mesa que não existe ("TABLE 5") |
| Sinais | o prato é opaco (os slots vazios são meio transparentes); vapor sobe **para baixo**; som de talher batendo sozinho |
| Resposta correta | **descartar** na BIN-K |
| Punição | levar o prato pela porta saída = desmaio de quem carrega, assim que cruza a porta |
| Omissão | sem desmaio; fica na bancada atrapalhando (ocupa a ponta) até descartarem ou a noite acabar |
| Engaja | 1–2 (montador; entregador se ninguém descartou) |
| Solo | sim |
| Números | prazo nenhum; peso 1; NpcCost 0 |
| Custo | **M**: spawn de prato `Altered` fora de slot + checagem na porta saída (zona) + descarte reaproveitado da ANM-002 |
| Aceite | (a) o prato extra não ocupa nenhum dos 8 slots; (b) descartar resolve; (c) cruzar a porta saída com ele desmaia quem carrega; (d) some no fim da noite |

### ANM-025 — Chama verde

| Campo | Conteúdo |
|---|---|
| Família / verbo | C / **desligar a válvula de gás** (segurar E 2 s) |
| Gatilho | Uma grelha sobe numa **chama verde** alta com rostinhos cartoon na fumaça; a fumaça se espalha pela cozinha |
| Sinais | luz verde no teto, chiado vira risada baixa, salsichas daquela grelha param de dourar |
| Resposta correta | **fechar a válvula** na parede em até **10 s**; reabrir depois de 5 s volta ao normal |
| Punição | 10 s sem fechar: a fumaça "abraça" (cartoon) e desmaia **quem está a até 8 studs da grelha**. Salsichas daquela grelha viram carvão (perdidas) |
| Omissão | é o próprio erro (prazo) |
| Engaja | 1–2 (grelhador; qualquer colega pode fechar) |
| Solo | sim |
| Números | prazo 10 s; raio 8 studs; segurar 2 s; peso 1; NpcCost 0 |
| Custo | **M**: prompt de válvula + VFX de chama/fumaça; servidor no padrão ANM-020 (prazo + vítimas por raio) |
| Aceite | (a) fechar a válvula ≤ 10 s resolve; (b) aos 10 s desmaia quem está no raio, e só ele; (c) salsichas da grelha viram "burnt" no erro |

### ANM-026 — A caixa que bate

| Campo | Conteúdo |
|---|---|
| Família / verbo | D / **não mexer** |
| Gatilho | A caixa de estoque de salsichas **sacode** e bate de dentro, 3 vezes, em 10 s |
| Sinais | tampa pulando, som abafado de batidas, a caixa anda 1 stud |
| Resposta correta | **não pegar** salsicha dessa caixa até parar (10 s). Pegar da outra caixa (se houver) ou esperar |
| Punição | interagir com a caixa durante as batidas = algo cartoon pula na cara (jumpscare) e desmaio de quem abriu |
| Omissão | — |
| Engaja | 1 (grelhador); custo de ritmo para a cozinha |
| Solo | sim |
| Números | 3 batidas em 10 s; peso 2; NpcCost 0 |
| Custo | **P**: escuta `Action` da estação de estoque (padrão ANM-009) + tween de sacudir no cliente |
| Aceite | (a) abrir durante as batidas desmaia quem abriu; (b) depois de 10 s a caixa funciona normal; (c) não bloqueia a caixa no servidor (o risco é a escolha) |

### ANM-027 — Condimento errado

| Campo | Conteúdo |
|---|---|
| Família / verbo | A / **descartar** a garrafa |
| Gatilho | Uma garrafa da estação de condimentos fica **errada**: rótulo espelhado, cor roxa, dois olhinhos na tampa, pinga gosma |
| Sinais | o que pinga sobe em vez de cair; o rótulo lê ao contrário |
| Resposta correta | **jogar a garrafa na BIN-K**; uma garrafa nova aparece em 5 s |
| Punição | usar a garrafa num prato = a gosma salta (cartoon) e desmaio de quem usou |
| Omissão | sem desmaio; aquele condimento fica indisponível (a garrafa ruim ocupa o lugar) |
| Engaja | 1 (quem está nos condimentos) |
| Solo | sim |
| Números | reposição 5 s; peso 1; NpcCost 0 |
| Custo | **P/M**: garrafa como item `Altered` (já existe o atributo); prompt de descarte existente |
| Aceite | (a) descartar resolve e repõe em 5 s; (b) aplicar desmaia quem aplicou; (c) o condimento fica sem uso enquanto ela está lá |

### ANM-028 — Trancado lá fora

| Campo | Conteúdo |
|---|---|
| Família / verbo | C / **ficar na luz** (`safe_spot` em `LIT-OUT` ou luminária de mesa acesa) até a porta abrir |
| Gatilho | Quando um jogador está **lá fora** (entregando), a porta saída bate e **tranca**; as luminárias das mesas apagam, menos a da porta (`LIT-OUT`); algo ronda entre as mesas |
| Sinais | estalo da tranca, luminárias apagando com "tunk", vulto passando entre mesas |
| Resposta correta | quem está fora **fica parado na luz**; quem está dentro **segura a tranca 3 s** para abrir. Sozinho: a tranca abre sozinha em 15 s |
| Punição | sair da luz durante a tranca = desmaio de quem saiu. Ninguém fora no gatilho = não dispara (Start false) |
| Omissão | colega que não abre: só atrasa (vai até os 15 s) |
| Engaja | 2 (preso + quem abre). O "abre pra mim!" do co-op |
| Solo | sim (espera 15 s na luz) |
| Números | tranca 15 s (ou até alguém segurar 3 s); raio de luz 6 studs; peso 1; NpcCost 0 (vulto só no cliente) |
| Custo | **M**: tranca de anomalia da porta (mesma da ANM-004) + `InZone`/`IsLit` existentes + prompt de destrancar |
| Aceite | (a) só dispara com alguém fora; (b) segurar 3 s por dentro destranca; (c) solo destranca em 15 s; (d) sair da luz durante a tranca desmaia quem saiu |

### ANM-029 — O convidado sentado

| Campo | Conteúdo |
|---|---|
| Família / verbo | D / **não chegar perto** |
| Gatilho | À noite, um cliente que **nunca pediu** aparece sentado numa mesa, de costas para a rua, olhando a cozinha |
| Sinais | nenhuma nota/billboard sobre ele; não come, não mexe; a luminária daquela mesa zumbe |
| Resposta correta | **não entregar** nada naquela mesa e **não chegar a menos de 5 studs** dele por 25 s; ele some |
| Punição | chegar a < 5 studs = ele vira a cabeça (cartoon) e desmaio de quem chegou |
| Omissão | — (ignorar é o certo). Pedidos de outros clientes daquela mesa: entregar pelo lado oposto (mesa de piquenique tem 2 bancos) ou esperar |
| Engaja | 1–2 (entregadores) |
| Solo | sim |
| Números | duração 25 s; raio 5 studs; só se a mesa tiver um banco livre; peso 1; NpcCost 1 |
| Custo | **M**: ator sentado (rig de cliente + pose sentada da feature de mesas) + teste de distância a 5 Hz |
| Aceite | (a) ele não tem pedido; (b) < 5 studs desmaia quem chegou, uma vez; (c) some em 25 s; (d) conta 1 no teto de atores |

### ANM-030 — Todas as mesas olham

| Campo | Conteúdo |
|---|---|
| Família / verbo | D / **não sair** pela porta saída |
| Gatilho | Todos os clientes sentados **param de comer ao mesmo tempo** e viram a cabeça para o restaurante |
| Sinais | silêncio dos talheres, cabeças girando juntas (modificador da ANM-016 aplicado em todos), luminárias das mesas ficam frias |
| Resposta correta | **ninguém abre a porta saída** por 10 s; eles voltam a comer |
| Punição | abrir a porta saída durante os 10 s = desmaio de quem abriu. Quem já estava lá fora: **ficar parado** (andar > 2 studs = desmaio) |
| Omissão | — |
| Engaja | 1–4 (todo mundo precisa respeitar; entregas param) |
| Solo | sim |
| Números | duração 10 s; tolerância de movimento 2 studs para quem está fora; exige ≥ 2 clientes sentados; peso 2; NpcCost 0 (reusa NPCs que já existem) |
| Custo | **P**: modificador de pescoço já existe (ANM-016) + escuta da porta (ANM-009) |
| Aceite | (a) só dispara com ≥ 2 sentados; (b) abrir a porta em ≤ 10 s desmaia quem abriu; (c) quem está fora e anda > 2 studs desmaia; (d) depois de 10 s tudo volta |

### ANM-031 — Carro sem motorista

| Campo | Conteúdo |
|---|---|
| Família / verbo | A / **recusar** (fechar a persiana do drive-thru) |
| Gatilho | Um carro para na janela do drive-thru **sem ninguém ao volante**; o alto-falante do computador mesmo assim faz o pedido |
| Sinais | banco vazio com a janela aberta, volante virando sozinho, farol aceso com motor desligado |
| Resposta correta | **fechar a persiana** do drive-thru; o carro sai de ré devagar |
| Punição | confirmar o pedido no computador = desmaio de quem confirmou |
| Omissão | sem desmaio; ocupa a janela até a paciência (40 s) e buzina 2× |
| Engaja | 1 (quem atende o drive-thru) |
| Solo | sim |
| Números | paciência 40 s; peso 2; NpcCost 1 (o carro) |
| Custo | **P**: variante "empty" do carro do drive-thru + Kit `CustomerActor` (Verb refuse, evento `Shutter` com âncora do drive-thru) |
| Aceite | (a) fechar a persiana resolve; (b) confirmar desmaia quem confirmou; (c) paciência esgotada não desmaia ninguém |

### ANM-032 — A fila que não acaba

| Campo | Conteúdo |
|---|---|
| Família / verbo | A / **recusar** (fechar a persiana) |
| Gatilho | A fila do drive-thru cresce com **carros idênticos** (mesma cor e placa "NITE-00"); cada buzina fica mais grave; o carro da frente não pede, só buzina |
| Sinais | 3–5 carros iguais encostados; buzina em cascata; o computador mostra "ORDER ORDER ORDER" |
| Resposta correta | **fechar a persiana** em até 20 s; os carros somem um a um na névoa |
| Punição | 20 s com a persiana aberta: a buzina da frente vira um rugido e o farol alto entra; desmaia quem está a até 10 studs da janela do drive-thru |
| Omissão | é o próprio erro (prazo). Clientes de drive-thru normais não chegam durante o evento |
| Engaja | 1 |
| Solo | sim |
| Números | 3 carros (N6–N8), 5 (N9–N10); prazo 20 s; raio 10 studs; peso 1; NpcCost 1 (os carros extras são só do cliente, sem física no servidor) |
| Custo | **M**: carros-fantasma no cliente (clones do modelo, como o carro da ANM-008) + prazo e raio no servidor |
| Aceite | (a) os carros extras não são NPCs do servidor; (b) fechar a persiana ≤ 20 s resolve; (c) aos 20 s desmaia quem está no raio |

### ANM-033 — Não faça carinho

| Campo | Conteúdo |
|---|---|
| Família / verbo | D / **não tocar** |
| Gatilho | Um **pet** sai pela janela de um carro do drive-thru e passeia pela cozinha (entra pela janela do drive-thru) por 20 s. À noite, **pets normais** também aparecem (ver `Q-333`): fazer carinho num pet normal dá gorjeta |
| Sinais (anomalia) | algo um pouco errado num bicho fofo: **olhos a mais**, anda **de costas**, sombra de outro bicho, coleira com o nome de um jogador |
| Resposta correta | **não usar o prompt "Pet"** nele; em 20 s ele volta para o carro |
| Punição | "Pet" no pet anômalo = ele pula na cara (cartoon) e desmaio de quem fez carinho. Ele também pode **sentar sobre um prato** da montagem: o prato fica bloqueado até ele sair (custo de ritmo, sem desmaio) |
| Omissão | — |
| Engaja | 1–4 (passa por todo mundo; a isca é o prompt) |
| Solo | sim |
| Números | 20 s; pet normal: gorjeta +$2, 1 por carro; anômalo: 1 a cada ~4 pets a partir da N4; NpcCost 1 |
| Custo | **M**: rig pequeno (gato/cachorro cartoon original) + caminho de 3–4 pontos + prompt "Pet". Pet normal é a mesma peça com outra linha de dado |
| Aceite | (a) o pet anômalo tem pelo menos 1 sinal visível a 10 studs; (b) "Pet" nele desmaia quem tocou; (c) ignorado, volta ao carro em 20 s; (d) pet normal dá gorjeta e não assusta |

### ANM-034 — O ajudante

| Campo | Conteúdo |
|---|---|
| Família / verbo | D / **largar o posto** |
| Gatilho | Um "funcionário" com o uniforme da equipe aparece trabalhando numa estação (grelha, pão ou condimentos) — sempre a estação **mais perto de um jogador** |
| Sinais | tag de nome "???"; mexe as mãos no vazio; a cabeça não acompanha o corpo; a estação para de funcionar (os prompts somem para ele "usar") |
| Resposta correta | **sair de perto** (> 8 studs) daquela estação e não usá-la por 15 s; o ajudante some. Obriga a cozinha a trocar de posto |
| Punição | usar a estação ou ficar a ≤ 3 studs dele por 2 s = ele "cumprimenta" (cartoon) e desmaio |
| Omissão | — |
| Engaja | 1–2 (quem estava no posto; o resto reorganiza) |
| Solo | sim (o solo vai para outra estação ou espera) |
| Números | duração 15 s; raio de perigo 3 studs por 2 s; peso 1; NpcCost 1 |
| Custo | **M**: rig da equipe já existe (`src/Crew`, `CrewRig`) com roupa padrão e tag "???"; bloqueio da estação + teste de distância |
| Aceite | (a) nunca copia a aparência de um jogador real (`Q-338`); (b) a estação fica bloqueada 15 s; (c) ≤ 3 studs por 2 s desmaia; (d) some sozinho |

### ANM-035 — Queda dupla

| Campo | Conteúdo |
|---|---|
| Família / verbo | C / **religar em dupla** |
| Gatilho | Igual à ANM-020, mas o painel do disjuntor externo mostra **duas luzes**: o disjuntor externo e o **interruptor da cozinha** precisam ser segurados **ao mesmo tempo** |
| Sinais | queda de energia + o rádio do chefe: "Both switches. Same time." |
| Resposta correta | um jogador segura o disjuntor externo e outro o interruptor da cozinha, **com sobreposição de 2 s**. Solo: segurar um e depois o outro em até **8 s** |
| Punição | 40 s sem religar = vulto ataca quem está dentro do prédio (igual ANM-020) |
| Omissão | é o próprio erro |
| Engaja | 2 (força a divisão: um sai, outro fica) |
| Solo | sim (8 s entre os dois) |
| Números | prazo 40 s (10 a mais que a ANM-020); sobreposição 2 s; janela solo 8 s; peso 1; NpcCost 0 |
| Custo | **M**: variação de dado da ANM-020 + segundo prompt e checagem de sobreposição |
| Aceite | (a) com 2+ jogadores, só resolve com sobreposição ≥ 2 s; (b) com 1 jogador, resolve com os dois em ≤ 8 s; (c) aos 40 s desmaia quem está dentro |

## 3. Interação com as atmosferas (ATM-1..7)

As atmosferas continuam só ambiente (DEC-257). O que muda é a **leitura** de cada anomalia. Nenhuma atmosfera altera prazo ou punição.

| ATM | Efeito no restaurante | Ajuda / atrapalha | Regras de sorteio (dado) |
|---|---|---|---|
| ATM-1 Noite normal | — | — | todas liberadas |
| ATM-2 Breu | mesas só iluminadas pelas luminárias; drive-thru só pelo farol | 028, 029, 030 ficam mais tensas; 033 (pet) fica difícil de ler | 033 com peso ×0,5; luminárias das mesas sobem 1 nível de brilho para os sinais de 029 continuarem legíveis |
| ATM-3 Névoa vermelha | a rua some a ~40 studs; os carros "saem" da névoa | 032 (fila que não acaba) brilha aqui; 006 (stalker) quase não se vê de longe | 032 peso ×2; 006 com `ViewRange` −20 % |
| ATM-4 Chuva | som de chuva no telhado; poças nas mesas; clientes sentam só nas mesas com guarda-sol (ou sentam menos) | chuva **abafa** batidas (026, 009) | 026 e 009 ganham sinal visual mais forte (sacudir maior / maçaneta mexendo); **ANM-005 não sorteia** (DEC-251) |
| ATM-5 Tempestade | relâmpago 0,2 s ilumina as mesas | relâmpago revela o convidado (029) e o vulto da 028 por um instante | 029 peso ×2; ANM-005 não sorteia |
| ATM-6 Neblina branca | a fila de carros e os clientes "surgem" a 20 studs | 031 e 032 ficam surpresa; 030 fica difícil de ver de dentro | 030 com sinal sonoro extra (talheres param) |
| ATM-7 Lua de sangue | tudo dessaturado, céu vermelho | noite final: todas | todas, com MinGap menor (tabela de noites) |

## 4. Ritmo das 10 noites no restaurante (Provisório, só dado)

Mesma lógica do §8 da V2: duas famílias desde a N1, algo novo por noite, curva calmo → pico → respiro. "Estreia" = apresentada pela ligação do chefe; o resto entra calado no sorteio.

| Noite | Novidade (ligação) | Entra calada | Atmosfera | Eventos | Sustos D | MaxSim |
|---|---|---|---|---|---|---|
| 1 | sem rosto no tablet + **cliente que fala errado (022)** | — | ATM-1 | 4 | 4 | 1 |
| 2 | **carro sem motorista (031)** | 023, 026, 009 | ATM-1 | 6 | 4 | 1 |
| 3 | falha de energia (020, disjuntor lá fora) | 024, 027, 030 | ATM-2 | 6 | 4 | 1 |
| 4 | **não faça carinho (033)**, pescoço invertido | 021 | ATM-4 | 7 | 5 | 2 |
| 5 | **chama verde (025)**, Raincoat Lady | 029, 013 | ATM-6 | 7 | 5 | 2 |
| 6 | Walker (esconder na despensa) | 028, 032 | ATM-3 | 8 | 5 | 2 |
| 7 | **o ajudante (034)**, rastejador | 008 (drive-thru) | ATM-5 | 8 | 5 | 2 |
| 8 | **queda dupla (035)**, sorriso no drive-thru | 006 | ATM-2 | 9 | 6 | 3 |
| 9 | sombra no teto | 004 | ATM-3 | 10 | 6 | 3 |
| 10 | Hush nas mesas (roteirizado) | todas | ATM-7 | 12 | 6 | 3 |

## 5. Pacote MVP (lançar com o mapa novo)

Critério: custo **P** ou M barato × uso do fluxo novo × cobertura de estações × co-op. Já vai junto o **pacote adaptado** da onda R1 (§1: família A nos tablets e no drive-thru, 005, 007, 009, 017–020), que só pede troca de âncora.

| # | ID | Por quê | Custo |
|---|---|---|---|
| 1 | **ANM-022** Cliente que fala errado | ensina o tablet e o novo "recusar" (guichê); só dado | P |
| 2 | **ANM-031** Carro sem motorista | primeira anomalia do drive-thru; usa o mesmo Kit da família A | P |
| 3 | **ANM-030** Todas as mesas olham | dá vida às mesas à noite; trava as entregas (co-op); reusa o pescoço da ANM-016 e a porta da ANM-009 | P |
| 4 | **ANM-026** A caixa que bate | risco na cozinha do fundo, sem modelo novo | P |
| 5 | **ANM-024** O prato a mais | usa a mesa de montagem; reusa o descarte da ANM-002 | M |
| 6 | **ANM-033** Não faça carinho | o "pet saindo do carro" que o dono pediu; a isca do prompt é o gancho; pet normal reaproveita a mesma peça | M |

Próxima onda (R2): 028 (trancado lá fora), 035 (queda dupla), 034 (o ajudante), 021, 025, 029, 032, 027, 023.
Esforço estimado do MVP novo: 4 P + 2 M ≈ 6–8 dias de agente, depois de tablet, pratos, mesas, porta saída e drive-thru existirem.

## 6. Notas técnicas para o architect / task-planner (sem código)

### 6.1 O que o Kit já cobre

| Peça existente | Serve para |
|---|---|
| `Kit/CustomerActor` (Verb refuse/serve, `Shutter` = recusa, `Scare`) | família A no tablet e no drive-thru, 022, 031, 032 (com âncora no `Shutter`) |
| `Kit/Hide` (zonas `HideZone`, caminho do monstro) | família B: só zonas e caminhos novos |
| ANM-020 / `LightService` (blackout, disjuntor) | 020, 035, 028 (luzes das mesas) |
| ANM-009 (escuta de porta por `Action`) | 009, 023, 026, 030 |
| ANM-002 (`Altered`, descarte FIFO) | 002, 021, 024, 027 |
| ANM-016 (cabeça segue alvo) | 030 |
| ANM-006 (`ctx.Looking`) | 006 |
| `src/Crew` `CrewRig` | 034 |
| `Hallucinations` família D | sustos de ambiente; reescrever 3 âncoras do trailer (`roof_steps`, `window_face`, `window_shadow`) para o restaurante |

### 6.2 Contratos que faltam (mínimos)

1. Evento `Shutter` ganha **qual guichê** (`Anchor`: tablet 1–4 ou drive-thru) — hoje é um shutter só.
2. Ações novas emitidas pelo `InteractionService` com âncora: `tablet_take`, `plate_pick`, `plate_deliver`, `door_exit_open`, `stock_take`, `condiment_apply`, `gas_valve`, `pet_pet`, `drive_take`.
3. `ctx.InZone` com um ponto `RST` (prédio inteiro) e `LIT-OUT`.
4. Tranca de anomalia na porta saída (a mesma que a ANM-004 usava na porta do trailer).

### 6.3 Teto de NPCs à noite (proposta, `Q-334`)

| Quem | Teto | Observação |
|---|---|---|
| Clientes em tablets | 2 tablets ativos à noite (4 de dia) | legibilidade da anomalia; hoje `NightQueueSize = 1` |
| Clientes sentados | 4 (1 por mesa) | pose sentada, idle barato |
| Carros no drive-thru | 1 parado + 1 na fila | motorista é parte do modelo |
| Pets | 1 | NpcCost 1 se anômalo |
| Atores de anomalia | 3 (DEC-045) | já contam dentro dos tetos acima quando ocupam um lugar de cliente |
| **Total de rigs animados** | **≤ 9** | mobile: manter abaixo de 10 rigs animados por servidor |

## 7. Critérios de aceite do pacote (nível documento)

1. Cada anomalia do MVP resolve em 5–30 s e tem exatamente 1 resposta certa listada.
2. Nenhuma anomalia nova usa sangue, arma ou ferimento; jumpscare só no erro (DEC-255/256).
3. As 6 do MVP funcionam com 1 jogador sem mudar os números (só ANM-028/035, fora do MVP, têm ajuste solo).
4. Teto de 3 atores respeitado no pior caso de MaxSim (3): 029 + 031 + 033 = 3.
5. Toda anomalia é uma linha de `Content.Anomalies` + `Rules/<Ref>.luau`; nenhuma pede mudar `AnomalyService/init`.

## 8. Perguntas abertas (para o secretário levar a `open-questions.md`)

| ID | Pergunta | Opções | Recomendação (Provisória) |
|---|---|---|---|
| Q-330 | Recusar no restaurante (DEC-261): fechar **o guichê daquele tablet** ou **uma persiana única** que fecha os 4 tablets e manda todos embora? | (a) guichê por tablet; (b) persiana única (custo de fila como hoje); (c) persiana única + guichê do drive-thru separado | **(a)**: mantém o verbo "fechar a janela" e o custo cai para 1 cliente; com 4 tablets, (b) puniria demais e quebraria o paralelismo |
| Q-331 | Onde se esconde (família B) sem a porta dos fundos do trailer? | (a) despensa/câmara fria dentro do prédio; (b) atrás de arbustos do lado de fora; (c) ambos | **(a)**: quem está nas mesas precisa correr para dentro (tensão boa) e a zona fica sempre ao alcance de quem cozinha |
| Q-332 | Disjuntor (ANM-020/035) dentro ou fora do prédio? | (a) fora, ao lado da porta saída; (b) dentro, na despensa | **(a)**: força alguém a largar o posto (pedido do dono: todos trabalhando, ninguém parado) |
| Q-333 | Pets normais à noite (isca da ANM-033) com gorjeta? | (a) sim, +$2 por carinho, 1 por carro; (b) só pets anômalos | **(a)**: sem pet normal, "nunca tocar" vira regra fixa e a anomalia perde a decisão |
| Q-334 | Teto de NPCs à noite no restaurante | (a) §6.3 (≤ 9 rigs, 2 tablets à noite); (b) 4 tablets também à noite (≤ 11 rigs) | **(a)**: mobile e legibilidade das anomalias de tablet |
| Q-335 | Prato preto da ANM-021 desmaia **quem confirmou** (DEC-204, quem agiu) ou **quem segura** o prato? | (a) quem confirmou; (b) quem segura; (c) ambos | **(c)**: quem confirmou errou primeiro; quem segura teve a segunda chance de descartar |
| Q-336 | ANM-004: a tranca passa para a **porta saída** e bloqueia as entregas por ~12 s? | (a) sim; (b) a cópia bate na janela do drive-thru (sem bloquear entregas) | **(a)**: custo de errar sentido pela equipe toda, mesma lógica da DEC-247 |
| Q-337 | ANM-010 (Hush): ponto seguro vira **dentro do prédio** em vez do letreiro do Mart? | (a) dentro do prédio; (b) continua o Mart | **(a)**: o Mart pode ficar longe no mapa novo; dentro do prédio mantém a corrida (quem está nas mesas) |
| Q-338 | O ajudante (ANM-034) pode copiar a roupa de um jogador real? | (a) nunca, uniforme padrão + tag "???"; (b) copia a roupa de um jogador ausente do posto | **(a)**: evita confusão de quem é quem e qualquer leitura de "imitar o amigo" no público infantil |
| Q-339 | O verbo **"não mexer"** (não abrir, não tocar, não sair) vira uma 5ª resposta oficial ao lado de recusar/esconder/religar/descartar? A V2 prometia "só 3 respostas" | (a) sim, oficializar; (b) não, manter como família D com verbo | **(a)**: já existe na prática (006, 008, 009) e é o verbo mais barato do restaurante; a ligação do chefe ensina "If it's wrong, don't touch it" |
