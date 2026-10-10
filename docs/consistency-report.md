Status: Rascunho

# Relatório de consistência entre documentos

Checagem cruzada, 2026-10-08, ~18:00. Só leitura: nenhum outro arquivo foi editado.
Base: `decisions.md` DEC-001 a **DEC-129** (rodada 15 já registrada: DEC-114 a DEC-129), `open-questions.md` (até `Q-127`).
Lidos: `vision.md`, `design/*.md` (inclui `proposals-round-1/2.md`, Aprovados), `story/*.md`, `levels/MAP-01.md`, `art/*.md`, `tech/*.md`.
Ordem de autoridade (`CLAUDE.md`): `decisions.md` > documento Aprovado > Rascunho.

Avisos:
- `vision.md` e `open-questions.md` estavam sendo editados pela secretária durante a checagem. As linhas citadas são as de ~18:00. A maior parte de `vision.md` já tinha sido conciliada com a rodada 15 nesse horário; sobrou só o que está em §6.
- "Linha" = número da linha no arquivo no momento da leitura. Faixas (`10–14`) cobrem o trecho todo.

Gravidade:
- **A** = contradiz uma DEC e vai virar código ou asset errado se ninguém corrigir.
- **M** = dois documentos dizem coisas diferentes (número, nome, lugar) e alguém vai ter que escolher; ou texto de jogo que engana o jogador.
- **B** = referência velha (Q fechada, "proposta" que já virou DEC, cabeçalho desatualizado). Não muda comportamento.

## Resumo

| Dono | Conflitos | A | M | B |
|---|---|---|---|---|
| game-designer | 33 | 6 | 7 | 20 |
| narrative-writer | 25 | 3 | 11 | 11 |
| level-designer | 21 | 4 | 7 | 10 |
| art-director | 21 | 3 | 7 | 11 |
| architect | 24 | 6 | 7 | 11 |
| secretário (extra: `vision.md`, `open-questions.md`) | 5 | 0 | 1 | 4 |
| **Total** | **129** | **22** | **40** | **67** |

## Os 10 mais graves

| # | Conflito | Onde | Vale |
|---|---|---|---|
| 1 | **Chances do chefe = 3** na tabela de run e nos textos de derrota ("restam 2", "That's three") | `tech/content-data.md:131`, `design/features.md:166`, `:651`, `:536`, `story/script.md:326–328`, `story/ui-text.md:133` | DEC-110, DEC-112: **1 por run inteira** |
| 2 | Noite repetida devolve só quem caiu naquela noite (opção A de `Q-121`); o snapshot restaura `Spectator` | `design/features.md:865`, `:899`, `design/progression.md:203`, `tech/architecture.md:425–427`, `:681`, `tech/data.md:176`, `:260`, `story/script.md:319` | DEC-111, DEC-113: **todos voltam**, inclusive espectadores de noites anteriores |
| 3 | Ambulância na ida **sem médicos descendo** (maca automática); não existe ficha de asset dos médicos | `art/asset-list.md:481`, `:486` (AST-052), `art/style-guide.md:238` (Aprovado; `Q-127`) | DEC-114: médicos descem e levam o corpo |
| 4 | Reviver por Robux **por qualquer um** e **sem limite por noite** | `tech/content-data.md:310`, `:314`, `tech/architecture.md:407–408`, `tech/network.md:240`, `story/ui-text.md:144` | DEC-116 (Robux só para si), DEC-129 (2 revives por jogador por noite) |
| 5 | Noite perdida: **acordar no banco** do trailer | `story/anomalies.md:154` (Aprovado), `levels/MAP-01.md:346`, `:630`, `art/asset-list.md:406`, `design/features.md:897` | DEC-122: todos acordam em pé ao lado do trailer |
| 6 | MAP-01: upgrade comprado **no próprio equipamento**; Mart sem bancada de upgrades e sem frutas/verduras | `levels/MAP-01.md:413`, `:361–396` (§7.4) | DEC-101, DEC-106, DEC-109 |
| 7 | MAP-01 não tem **semáforo** (T com PARE; rota Pad ↔ Mart "sem trânsito"); o architect põe o semáforo em CW-1, que no mapa é o beco sem carros | `levels/MAP-01.md:16`, `:207–212`, `:243`, `:448`, `:512`; `tech/architecture.md:446–447` | DEC-120 |
| 8 | Tamanho da party para preços = `Joined` que **cresce** e é lido **na hora da compra** | `tech/architecture.md:345`, `tech/content-data.md:129`, `tech/data.md:154`, `tech/network.md:140`, `vision.md:139` | DEC-121: quem entrou **até o fim do Day 1**, fixo |
| 9 | Estados de vida do architect: `Spectator` ainda pode ser revivido; a queda é `Ragdoll(∞)` | `tech/architecture.md:356–359`, `:366`, `:370` | DEC-115 (reviver só até 6:00 AM; depois espectador), `style-guide.md` §4.6 (Aprovado: desmaio é animação, não ragdoll) |
| 10 | Bancada do Mart descrita como "oferta que muda a cada turno" / "New stock every shift" / "Gear changes every shift"; AST-049 com 5 vagas e "SOLD até o próximo turno" | `story/world.md:84`, `story/ui-text.md:75`, `story/script.md:94`, `:109`, `:130`, `art/asset-list.md:542–544` | DEC-106: básicos **sempre** à venda; só o especial sorteia (FEAT-015: B1–B5 + S1) |

Logo abaixo destes: recibo atrasado vira crédito "na run" (`design/features.md:1136`; DEC-117 manda guardar **no perfil**) e o passo 10 do Walker mudando com Trailer Lights (`levels/MAP-01.md:232` contra NPC-015 e UPG-005).

## Pontos pedidos especificamente

| Tema | Achado |
|---|---|
| Nome do item de reviver | `story/` e `art/` usam **"Rescue Whistle"** / apito (`story/ui-text.md:37`, `:44`, `:62`, `:143`, `story/script.md:372`, `story/world.md:168`, `art/asset-list.md:562`). `design/` e DEC-129 usam **"Revive Kit (ITM-021)"** (`design/items.md:45`, `design/features.md:281`, `:298`). Ver NW-16. |
| Mapa x world | `MAP-01` (revisão 2) **já usa** os nomes de `world.md`. Quem está velho são os documentos que ainda dizem "MAP-01 usa Main St / Cross St": `art/style-guide.md:84`, `art/asset-list.md:20`, `:573`, `tech/architecture.md:445`, `tech/content-data.md:334`. |
| Medidas carrinho/trailer | `asset-list.md` AST-026 e AST-027 **já adotaram** as medidas do MAP-01 (linha de 26 studs; casco 28 × 12). O "conflito de medida" de `MAP-01.md:652`, `:659` e §15 P27 está velho. Sobra a **altura**: MAP-01 "teto 10" (`:48`, `:351`) contra AST-027 "pé-direito 8,5, altura externa ~11" (`asset-list.md:450`). Outras: Mart 36 × 32 (MAP-01) x 36 × 48 (AST-028); ambulância ~16 × 7 x 18 × 7,5 × 8,5; banco 4 lugares 10 × 3 x 3 lugares 9 × 3. |
| Limite de luzes | Quatro números: `MAP-01.md:731` ≤ 10 à noite (postes JL-02..09 sem luz real); `style-guide.md:257` diz que o MAP-01 fala em ≤ 8 (errado); `style-guide.md:270`, `:437` (Aprovado) ≤ 18 locais (alvo 14), ≤ 3 com sombra, postes da Juniper com SpotLight; `tech/architecture.md:622` ≤ 6 com sombra. Vale o style guide (Aprovado, DEC-126). |
| Roteiro da intro em 1ª pessoa sem braços | `story/script.md:29` (plano 1: olhar de cima dos telhados e câmera que "desce" não é POV), `:30` (carteira que "abre" na mão), `:34` (celular flip que "abre" e disca). O level-designer já apontou em `MAP-01.md:798` (P28). DEC-088, DEC-097. Ver NW-11, NW-12. |
| Qs fechadas citadas como abertas | Q-121 (DEC-111), Q-084 (DEC-101), Q-111 (DEC-103), Q-118 (DEC-108), Q-119 (DEC-109), Q-076 (DEC-124), Q-044 (DEC-127), Q-022/Q-025/Q-028 (DEC-128), Q-124 (DEC-125), Q-123 (DEC-126), Q-112 (a) (DEC-121), partes de Q-107 (DEC-115, DEC-116, DEC-129). Linhas nas tabelas abaixo. |
| IDs | Nenhum ID duplicado. Nenhuma referência a ID inexistente (AST-001..075, ITM-001..021, UPG-001..007, NPC-001..024, CLS-001..008, CHR-001..008, FEAT-001..036, ANM-001..010, DEC-001..129, Q-001..127 todos existem; AN-08 aposentado e não reaproveitado). Problemas: placeholder `ITM-0xx` em `tech/content-data.md:183` (é ITM-021); coluna AST do `MAP-01.md` §12 apontando para fichas erradas ou "novo pedido" que já existe; **faltam fichas** de asset para os médicos (CHR-008, NPC-024, L01-54) e para o semáforo (DEC-120). |

---

## 1. game-designer

| # | arquivo:linha | Conflito | Decisão/fonte que vale | Dono | Grav. | Correção sugerida |
|---|---|---|---|---|---|---|
| GD-1 | `design/features.md:166` | `RunConfig` "Chances do chefe = 3 (DEC-057)" | DEC-110, DEC-112 | game-designer | A | Valor 1, origem DEC-110/DEC-112. |
| GD-2 | `design/features.md:651` | `call_lost_<k>` "com k chances restantes (k = 2, 1)" | DEC-110, DEC-112 | game-designer | A | Uma chave só: `call_lost_last_chance` (chance usada; noite repete) + `call_run_over`. |
| GD-3 | `design/features.md:536` | Resumo de noite com exemplo "Chances left: 2" | DEC-110 | game-designer | B | Exemplo "Last chance used" / sem número. |
| GD-4 | `design/features.md:865` | `Spectator` sai "no fim da run (ou noite repetida, se Q-121 = A)" | DEC-111, DEC-113 | game-designer | A | "Sai no fim da run **ou** no início da noite repetida (todos voltam)". |
| GD-5 | `design/features.md:899` | Espectadores na noite repetida "dependem de Q-121"; recomendação A (só quem caiu nesta noite) | DEC-111, DEC-113 | game-designer | A | Na noite repetida todos os membros voltam `Active` com a sanidade inicial da classe, inclusive espectadores de noites anteriores. |
| GD-6 | `design/features.md:897` | "Onde se acorda (banco x ao lado da ambulância): Q-106 b" | DEC-122 | game-designer | M | "Todos acordam em pé na calçada ao lado do trailer enquanto a ambulância vai embora". |
| GD-7 | `design/features.md:1136` | Recibo atrasado vira "crédito de reviver do jogador **na run**" | DEC-117 (crédito **no perfil** persistido) | game-designer | A | Trocar por "1 crédito em `ReviveCredits` no perfil". |
| GD-8 | `design/features.md:869`, `:1085`, `:1113`, `:1122`, `:1123`, `:1223` | Prazo até 6:00 AM, Robux só para si e limite de 2 por noite ainda marcados como "proposta para Q-107" | DEC-115, DEC-116, DEC-129 | game-designer | B | Marcar as DECs; deixar como proposta só o uso do Kit por colega (`Q-120` f) e os tempos. |
| GD-9 | `design/features.md:1156`, `:1165`, `:1168`, `:1225` | FEAT-035: 15% e $200 × party "proposta para Q-120" | DEC-129 (multiplicador contado como DEC-121) | game-designer | B | Marcar DEC-129. |
| GD-10 | `design/features.md:113–115`, `:136`, `:1224` | Tamanho da party até o fim do Day 1 como "proposta para Q-112 a … precisa do usuário" | DEC-121 | game-designer | B | Marcar DEC-121; tirar de "Propostas pendentes". |
| GD-11 | `design/features.md:365`, `:1246–1248` | Q-025, Q-044, Q-022/Q-028, Q-124 listadas como "precisa do usuário" | DEC-125, DEC-127, DEC-128 | game-designer | B | Mover para decididas. |
| GD-12 | `design/features.md:1062–1063`, `:1069` | Semáforo como "sugestão"; carros "freiam para clientes, ladrão, pedestres" | DEC-120 (semáforo; carros obedecem; NPC só atravessa no verde) | game-designer | M | FEAT-033: semáforo decidido; carros param no vermelho deles; NPC só atravessa no verde (carro não freia por NPC fora disso). Jogador pode atravessar no vermelho e ser atropelado. |
| GD-13 | `design/features.md:1101`; `design/npcs.md:349` | Paradas AMB-1 (trailer), AMB-2 (Mart), AMB-3 (meio da rota) | `levels/MAP-01.md:217–221` (AMB-P, AMB-M, REV-1..4; 2 paradas) | game-designer | M | Adotar os IDs do MAP-01 (AMB-P = parada do reviver); AMB-3 sai ou o level-designer cria. |
| GD-14 | `design/features.md:1095–1097` | Ambulância chega em 8 s, coleta 8–18 s | `levels/MAP-01.md:521`, `:528` (~3 s; 20–25 s); `tech/content-data.md:322–324` (4 + 6 s) | game-designer | B | Fixar os números na tabela `Ambulance` e pedir que MAP-01 e `content-data` citem a tabela. |
| GD-15 | `design/features.md:1043–1044`; `design/npcs.md:58`, `:329` | À noite 1 carro, 1 a cada 45–75 s | `levels/MAP-01.md:500` (0 depois das 9 PM), `tech/architecture.md:441–442` (0–2), `story/world.md:97` ("quase nenhum"); `Q-103` aberta | game-designer | M | Fechar um número em `Q-103` e alinhar os quatro documentos. |
| GD-16 | `design/features.md:1197–1199`, `:1206`, `:302` | Item no chão: "Pick Up" (toque), some em 120 s, só a Tool equipada cai, Hot Dog é perdido | `tech/architecture.md:469–470`, `tech/content-data.md:187–188` ("Take" hold 0,5 s, 60 s, "tudo cai", Hot Dog recuperável); DEC-103 "derruba o item **da mão**" | game-designer | M | O game-designer fecha `Q-122` e/f (é o dono) e o architect copia. A leitura "só a Tool equipada" é a de DEC-103. |
| GD-17 | `design/features.md:1113` | Kit usado por colega revive "o caído mais antigo" | `tech/architecture.md:404` (seletor quando há mais de um caído) | game-designer | B | Escolher um comportamento em `Q-120` f. |
| GD-18 | `design/features.md:123`, `:249` | Atrasado que chega durante a intro entra na cutscene no ponto atual | `story/script.md:62` (não vê a cutscene; aparece na esquina); `Q-112` c aberta | game-designer | M | Fechar `Q-112` c com o narrative-writer; um dos dois textos muda. |
| GD-19 | `design/items.md:76`, `:82` | Prompt "Place Bun" | `design/features.md:323`, `story/ui-text.md:28` ("Slice Bun") | game-designer | B | Usar "Slice Bun". |
| GD-20 | `design/items.md:98` | "trilho cheio bloqueia 'Take' na grelha" | `design/features.md:322` ("Collect") | game-designer | B | "Collect". |
| GD-21 | `design/items.md:173`; `design/upgrades.md:12`, `:124`, `:191` | Cafeteira: "contradição em Q-124 (recomendação A)" | DEC-125 | game-designer | B | Citar DEC-125. |
| GD-22 | `design/items.md:263`; `design/upgrades.md:65` | Validade "proposta para Q-025 … precisa do usuário" | DEC-128 | game-designer | B | Citar DEC-128. |
| GD-23 | `design/items.md:228`, `:262`; `design/economy.md:40`, `:120`, `:203` | Revive Kit $200 × party e 15% "proposta, Q-120" | DEC-129 | game-designer | B | Citar DEC-129. |
| GD-24 | `design/upgrades.md:8` x `:35`, `:122` | "Coffee Maker" (lista de nomes) x "Coffee Machine" (UPG-007) | `story/ui-text.md:61` ("Coffee Maker", proposta) | game-designer | B | Um nome só. |
| GD-25 | `design/upgrades.md:111`; `design/economy.md:177`, `:205` | Tamanho da party "proposta para Q-112 a … precisa do usuário" | DEC-121 | game-designer | B | Citar DEC-121. |
| GD-26 | `design/progression.md:203` | `Q-121` com recomendação A, "precisa do usuário" | DEC-111, DEC-113 | game-designer | A | Remover a linha; citar as DECs. |
| GD-27 | `design/progression.md:88`, `:96`, `:201` | Duração crescente como "proposta para Q-044" | DEC-127 | game-designer | B | Marcar DEC-127. |
| GD-28 | `design/progression.md:133` | Critério "vence a Night 10 na 1ª **ou 2ª** tentativa em ≥ 60%" | DEC-110, DEC-112 (2ª tentativa só existe se a chance da run ainda não foi usada) | game-designer | B | Reescrever o critério (ex.: "na 1ª tentativa em ≥ 50%"). |
| GD-29 | `design/npcs.md:58` | ANM-008 "conta" no teto de 12 humanoides | `design/features.md:1043` e `tech/architecture.md:441` (veículos têm teto próprio); NPC-016 é veículo sem humanoide | game-designer | B | Mover a ANM-008 para o teto de veículos. |
| GD-30 | `design/npcs.md:150` | "Nenhum cliente normal quebra um dos **9** invariantes" | a lista de `:83–92` tem **10** | game-designer | B | "10 invariantes". |
| GD-31 | `design/npcs.md:331` | Carro freia "no semáforo (se o level-designer usar)" | DEC-120 | game-designer | M | Semáforo é obrigatório. |
| GD-32 | `design/proposals-round-1.md:315`, `:318`, `:419`; `design/proposals-round-2.md:21` (Aprovados) | 3 chances, banco do trailer, "volta no próximo turno" | DEC-091, DEC-093, DEC-110, DEC-111, DEC-122 | game-designer | B | Sem mexer no conteúdo aprovado: nota no topo "superado em: …" (mesmo padrão das anotações de `anomalies.md`). |
| GD-33 | cabeçalhos `design/features.md:5`, `design/items.md:5`, `design/upgrades.md:5`, `design/economy.md:5`, `design/progression.md:6`, `design/classes.md:5` | "conciliado até a rodada 12" | DEC-110 a DEC-129 | game-designer | B | Conciliar com as rodadas 13–15 (as linhas acima). |

## 2. narrative-writer

| # | arquivo:linha | Conflito | Decisão/fonte que vale | Dono | Grav. | Correção sugerida |
|---|---|---|---|---|---|---|
| NW-1 | `story/anomalies.md:154` (Aprovado) | N7 "Consequência": "todos acordam no banco ao amanhecer" | DEC-122 (a própria DEC registra a pendência) | narrative-writer (secretário registra a anotação) | A | Anotação com DEC-122, igual à de DEC-123 em `:157`, sem mudar o conteúdo aprovado. |
| NW-2 | `story/anomalies.md:99` | N3: "Precisa do interruptor e do Trailer Lights" | `design/features.md:718`, `design/upgrades.md:101` (o interruptor vem com o trailer); `Q-064` aberta | narrative-writer | B | Nota apontando para `Q-064` / FEAT-020. |
| NW-3 | `story/anomalies.md:209` | Atores do teto de 3: inclui N6 | `design/npcs.md:224` (N6 é ambiente, custo 0) | narrative-writer | B | Nota: N6 é silhueta de ambiente, não ator. |
| NW-4 | `story/script.md:326–328` | Ligações "restam 2 chances", "resta 1 … That's two / One more chance", "That's three" | DEC-110, DEC-112; DEC-110 pede que o texto deixe claro que **não há outra chance** | narrative-writer | A | Duas ligações: noite perdida com a chance ("Rough night. Let's try that again. This is the only time I can do this, Rookie.") e fim da run ("That's two, Rookie…"). |
| NW-5 | `story/script.md:319` | Espectadores na cena do amanhecer "dependem de Q-121" | DEC-111, DEC-113 | narrative-writer | A | "Todos acordam juntos, inclusive quem estava assistindo." |
| NW-6 | `story/script.md:318` | Acordar em pé ao lado do trailer como proposta que "precisa do usuário" | DEC-122 | narrative-writer | B | Marcar DEC-122. |
| NW-7 | `story/script.md:10`; `story/characters.md:34`; `story/world.md:121`, `:126–136` | Telefone do veículo como "proposta para Q-076" | DEC-124 | narrative-writer | B | Marcar DEC-124. |
| NW-8 | `story/world.md:121–122`; `story/characters.md:34` | Dois aparelhos: caixinha vermelha no mastro (carrinho) e telefone de parede creme (trailer) | `art/asset-list.md:423–426` (AST-042: **mesma malha** nos dois, Ketchup) | narrative-writer + art-director | M | Escolher: 1 malha (AST-042) ou 2 variantes; registrar na ficha. |
| NW-9 | `story/script.md:229–232`, `:274–286` | Linha 6 da Noite 7 condicionada à proposta do zumbido; §5.12 como proposta | DEC-123 | narrative-writer | B | Tirar a condicional; §5.12 vira "decidido". |
| NW-10 | `story/script.md:24–25` | "Quem liga? Todo mundo" | `design/features.md:250` (só o avatar do trilho 1 liga); `art/asset-list.md:810` (AST-038: "o avatar que liga"); `Q-106` c aberta | narrative-writer (+ game-designer, art-director) | M | Fechar `Q-106` c; FEAT-004 e AST-038 seguem a escolha. |
| NW-11 | `story/script.md:29` (plano 1); também `:32` e `:36` (câmera "vira sozinha") | Fade in olhando os telhados e "a câmera desce para a calçada": plano de grua, não POV | DEC-088, DEC-097; `levels/MAP-01.md:798` (P28) e §11.1 (CS-1 começa na calçada) | narrative-writer | M | Começar na calçada (CS-1); olhar para cima e virar a cabeça é permitido (câmera presa na cabeça olhando um alvo, `tech/architecture.md` §11). |
| NW-12 | `story/script.md:30` (plano 2), `:34` (plano 6) | Carteira que "abre" na mão; celular flip que "abre" e disca — gesto de mão em 1ª pessoa **sem braços** | DEC-097 (só a Tool aparece, sem mão) | narrative-writer (+ art-director) | M | Tool animada sozinha (AST-075 carteira, AST-038 celular), ou trocar o gesto por balão de fala ("Empty. Again.") como sugere MAP-01 P28. |
| NW-13 | `story/script.md:94`, `:109`, `:130` | "Gear's on the back wall. It changes every shift." / "New gear, maybe." / "got new gear" | DEC-106 (básicos fixos; só o especial muda) | narrative-writer | M | Ex.: "Gear's on the back wall. Sometimes there's something special." |
| NW-14 | `story/world.md:84`, `:87`; `story/ui-text.md:75` | Bancada "TODAY'S GEAR" com "New stock every shift."; "a oferta muda a cada turno" | DEC-106 | narrative-writer | M | Placa sem "today"; rodapé sobre o slot especial. |
| NW-15 | `story/world.md:82` | Frutas e verduras: "cenário ou ingrediente: Q-119" | DEC-109 | narrative-writer | B | "Só cenário (DEC-109)". |
| NW-16 | `story/ui-text.md:37`, `:44`, `:62`, `:143`; `story/script.md:372`; `story/world.md:168` | Item raro = **"Rescue Whistle"** (apito; "Buy Whistle", "Blow Whistle", "Use Whistle") | DEC-129 e `design/items.md:45`, `design/features.md:281`, `:298` chamam de **"Revive Kit"** (ITM-021, "nome placeholder"; nome final é do narrative-writer, DEC-022) | narrative-writer (+ game-designer, art-director) | M | Fechar um nome de exibição. Se ficar "Rescue Whistle", o game-designer troca os textos de prompt ("Use Revive Kit") e mantém a chave `revive_kit`. |
| NW-17 | `story/ui-text.md:133` | Tela "Night Lost · Chances left: {n}" | DEC-110 (depois de perder com chance, sobra 0) | narrative-writer | M | "Night Lost · That was your one chance · Same night again…" |
| NW-18 | `story/ui-text.md:144` | "Oferta para colega (se Q-107 permitir)" junto da oferta em Robux | DEC-116 (Robux só para si) | narrative-writer | M | Tirar para Robux; manter só para o Kit, conforme `Q-120` f. |
| NW-19 | `story/ui-text.md:146–147` | "valor em Q-107"; "Revive until 6:00 AM (se Q-107 aceitar a sugestão)" | DEC-115; FEAT-034 (sanidade 50% da classe) | narrative-writer | B | Marcar DEC-115; tirar a condicional. |
| NW-20 | `story/ui-text.md:148`; `story/script.md:377` | "You're out for the rest of the run." | DEC-111, DEC-113 (volta se a noite for perdida e repetida) | narrative-writer | M | Ex.: "You're out for now. Watch your crew!" |
| NW-21 | `story/ui-text.md:33` | Pegar item no chão: "Take" | `design/features.md:277`, `:1206` ("Pick Up") | narrative-writer + game-designer | B | Um prompt só. |
| NW-22 | `story/ui-text.md:36` | Bancada: "Owned" / "Maxed" | `design/features.md:572` ("MAX") | narrative-writer + game-designer | B | Um texto só. |
| NW-23 | `story/ui-text.md:103` | "Something rare is on the Mart's back wall!" | `design/features.md:1171` ("Something special at the Mart.") | narrative-writer + game-designer | B | Um texto só. |
| NW-24 | `story/characters.md:109`; `story/world.md:112` | Ambulância "branca e menta", luz giratória menta e branca | `art/style-guide.md:98`, `:479` (Aprovado, DEC-126): Cream com faixa Teal, barra de luz Mustard/Teal | narrative-writer | M | Adotar a paleta aprovada. |
| NW-25 | `story/characters.md:75` | Atropelamento de NPC "em aberto (Q-122 b)" | `design/features.md:1063` (NPC nunca atropelado, proposta); DEC-120 (NPC só atravessa no verde) | narrative-writer | B | Tirar a fala extra do Quentin ou deixá-la como reserva. |

## 3. level-designer

| # | arquivo:linha | Conflito | Decisão/fonte que vale | Dono | Grav. | Correção sugerida |
|---|---|---|---|---|---|---|
| LD-1 | `levels/MAP-01.md:413` | "Upgrades: no próprio equipamento (Q-084)" | DEC-101, DEC-106 | level-designer | A | "Na bancada do fundo do Mart". |
| LD-2 | `levels/MAP-01.md:361–396` (§7.4) | Interior do Mart sem bancada de upgrades e sem área de frutas/verduras; 36 × 32 | DEC-101, DEC-109; FEAT-015 (B1–B5 + S1); `art/asset-list.md:502–503`, AST-049/AST-050 | level-designer | A | Pôr a bancada na parede do fundo (posições B1–B5 + S1) e o expositor decorativo; conferir o tamanho com AST-028 (36 × 48). |
| LD-3 | `levels/MAP-01.md:346`, `:358`, `:630` | Banco do fundo = onde a party acorda depois da noite perdida | DEC-122 | level-designer | A | Acordar em pé na calçada ao lado do trailer (pode reaproveitar REV-1..4); o banco vira cenário. |
| LD-4 | `levels/MAP-01.md:16`, `:122`, `:207–212`, `:243`, `:412`, `:448`, `:512` | T com PARE nos três braços; rota Pad ↔ Mart "sem cruzar pista com trânsito"; sem semáforo | DEC-120 (semáforo com faixa na travessia trailer ↔ Mart e nos cruzamentos) | level-designer (+ architect) | A | Semáforos nas faixas CW-2, CW-3, CW-4 e nos braços do T. Para a "travessia trailer ↔ Mart": se a rota continua pelo beco sem carros (CW-1), registrar com o architect onde fica o semáforo pedido pela DEC (o architect o põe em CW-1). |
| LD-5 | `levels/MAP-01.md:507–508` | Carro para na faixa se houver **qualquer** personagem; fora da faixa não freia | DEC-120 (carros obedecem ao semáforo; jogador pode atravessar no vermelho) | level-designer | M | Carro para no vermelho dele; no verde dele não para por jogador na faixa. |
| LD-6 | `levels/MAP-01.md:505`, `:508–509`, `:532`, `:791` | Tempo no chão, item na mão e sanidade "em Q-111"; "proposta para Q-111 d/e" | DEC-103 (item cai, sem sanidade); resto em `Q-122` | level-designer | B | Citar DEC-103 e `Q-122`. |
| LD-7 | `levels/MAP-01.md:232` | Passo 10 do Walker muda: com Trailer Lights (28, 29), sem (44, 32) | `design/npcs.md:240` (NPC-015) e `design/upgrades.md:102`: passo 10 **fixo**, não muda com interruptor nem upgrade | level-designer | M | Um ponto fixo para o passo 10. |
| LD-8 | `levels/MAP-01.md:234` | Hush "11 postes" (JL-09 → JL-01 → P-01) | a cadeia tem 10 | level-designer | B | 10 postes (~1,5 s por poste). |
| LD-9 | `levels/MAP-01.md:568` | LZ-1 (interior do trailer) "sempre" é luz | `design/features.md:715–718` (interior ativo só com o interruptor ligado; necessário para a ANM-003 custar escuro); `Q-064` aberta | level-designer | M | LZ-1 condicionada ao interruptor (ou fechar `Q-064` diferente). |
| LD-10 | `levels/MAP-01.md:475` | Médicos (≤ 2) contam no teto de 12 NPCs | `design/features.md:417`, NPC-024, `tech/architecture.md:586` (atores visuais, fora do teto) | level-designer | B | Tirar os médicos do teto. |
| LD-11 | `levels/MAP-01.md:500`, `:544` | 0 carros depois das 9 PM; o long car é "o único carro em movimento" | `design/features.md:1043` (1 carro raro à noite); `Q-103` aberta | level-designer | M | Ver GD-15. |
| LD-12 | `levels/MAP-01.md:521`, `:528` | Ambulância chega ~3 s após a queda; luzes âmbar/brancas | FEAT-034 (8 s; números do game-designer); `art/style-guide.md:98` (Aprovado: barra Mustard/Teal) | level-designer | M | Citar a tabela `Ambulance` e a paleta aprovada. |
| LD-13 | `levels/MAP-01.md:536` | Com todos caídos, a ambulância só entra depois dos 10 s | FEAT-034 (despacha na hora da queda) | level-designer | B | Alinhar com FEAT-034 ou levar ao game-designer. |
| LD-14 | `levels/MAP-01.md:731` | Noite: ≤ 10 luzes; JL-02..09 só emissivo | `art/style-guide.md:264`, `:270`, `:437` (Aprovado): até 18 locais, postes da Juniper com SpotLight (≤ 10), ≤ 3 com sombra | level-designer | M | Adotar o orçamento do style guide. |
| LD-15 | `levels/MAP-01.md:229`, `:250`, `:733` | JL-09 (início do Walker) a ~165 studs; névoa a 200 | `art/style-guide.md:305`, `:456` (Aprovado) e `art/asset-list.md:767`: legível "a até ~110 studs" | level-designer + art-director | M | Aproximar JL-09 de ~110 ou o art-director anotar 165 (com teste de leitura no celular). |
| LD-16 | `levels/MAP-01.md:48`, `:796` (P26) | Bancada 3,5 provisória; "style-guide usa 3,0 e câmera 4,6 (R15)" | `art/style-guide.md:149–157` (Aprovado): R6, olho 4,5, bancada 3,5 | level-designer | B | Tirar "provisório"; propor fechar `Q-095`. |
| LD-17 | `levels/MAP-01.md:652`, `:659`, `:797` (P27) | "Conflito de medida" com 8 × 3,5 e 22 × 9 × 10 | AST-026 e AST-027 já usam 26 e 28 × 12 | level-designer | B | Remover o conflito; sobra só a altura (AD-8). |
| LD-18 | `levels/MAP-01.md:663` | Banco do fundo com 4 lugares, 10 × 3 | `art/asset-list.md:407` (AST-040: 3 lugares, 9 × 3); função obsoleta por DEC-122 | level-designer + art-director | B | Uma medida só (ou cortar o banco para cenário simples). |
| LD-19 | `levels/MAP-01.md:661`, `:663`, `:664`, `:679`, `:686`, `:690–693`, `:713` (§12, coluna AST) | Interruptor → AST-023 (é AST-039); banco e Hide "—" (são AST-040, AST-041); relógio, carros, ambulância, long car, banco+apartamentos "novo pedido" (são AST-044, AST-035, AST-052, AST-065, AST-044/045); B1 → AST-033 (asset-list mapeia L01-31 → AST-045) | `art/asset-list.md:112–158` | level-designer | B | Atualizar a coluna AST. |
| LD-20 | `levels/MAP-01.md:395` | Opal fala a ≤ 6 studs | `design/npcs.md:289` e AST-031 (8 studs) | level-designer + game-designer | B | Um raio só. |
| LD-21 | `levels/MAP-01.md:770` (P5) | `Q-084` "aberta" | DEC-101 | level-designer | B | "Fechada: DEC-101". |

## 4. art-director

| # | arquivo:linha | Conflito | Decisão/fonte que vale | Dono | Grav. | Correção sugerida |
|---|---|---|---|---|---|---|
| AD-1 | `art/asset-list.md:481`, `:486` (AST-052) | Na ida "ninguém desce"; maca automática; só um motorista | DEC-114 | art-director | A | Médicos R6 descem e levam o corpo (maca carregada à mão); tirar a maca automática (o caso "corpo inacessível" de FEAT-034 segue Rascunho). |
| AD-2 | `art/asset-list.md` (ficha ausente) | Não há ficha para os médicos (CHR-008, NPC-024; MAP-01 L01-54) | DEC-114, DEC-089 | art-director | A | Ficha nova (ex.: AST-076): 2 médicos R6, uniforme, animações de descer/levar/subir (AST-069). |
| AD-3 | `art/style-guide.md:238` (§4.6, Aprovado) | "Ambulância leva": maca automática; "paramédico descendo" proibido | DEC-114 (vale a DEC; `Q-127`) | art-director | A | Anotar a linha com DEC-114 sem mexer no resto. |
| AD-4 | `art/style-guide.md:501` (§11, Aprovado) | Sinal do Walker: sobe "~1,5 s" e corta com estalo | DEC-123: ~2 s, "para seco" (`Q-127`) | art-director | M | Anotar com DEC-123. |
| AD-5 | `art/style-guide.md:5–7`, `:245` | "Em aberto: iluminação Future e aprovação do documento (Q-123)"; "proposta" | DEC-126 (a linha 1 já foi atualizada) | art-director | B | Ajustar o parágrafo de abertura e o título de §5.1. |
| AD-6 | `art/style-guide.md:84`; `art/asset-list.md:20`, `:573` | "O MAP-01 ainda usa placeholders (Main St / Cross St)" | `levels/MAP-01.md` revisão 2 já usa Ninth/Juniper | art-director | B | Tirar a ressalva. |
| AD-7 | `art/style-guide.md:257` | "Revisa o §13 do MAP-01 (≤ 8 luzes)" | `levels/MAP-01.md:731` diz ≤ 10 | art-director | B | Corrigir a citação. |
| AD-8 | `art/asset-list.md:450` (AST-027) | Pé-direito 8,5; altura externa ~11 | `levels/MAP-01.md:48`, `:351` ("teto 10") | art-director + level-designer | M | Definir: 10 é interno ou externo? Registrar um só número nos dois documentos. |
| AD-9 | `art/asset-list.md:406–407` (AST-040) | Banco "amanhecer da noite perdida (DEC-053)"; 3 lugares | DEC-122; MAP-01 (4 lugares) | art-director | M | Tirar o uso de DEC-053; alinhar lugares (LD-18). |
| AD-10 | `art/asset-list.md:542–544` (AST-049) | "Oferta muda a cada turno"; 5 vagas (4 comuns + 1 especial); comprado mostra "SOLD" até o próximo turno | DEC-106; FEAT-015 (B1–B5 fixas + S1; mostra o próximo nível ou "MAX") | art-director | M | 6 posições; vagas comuns mostram o próximo nível; só S1 tem "Sold out". |
| AD-11 | `art/asset-list.md:561` (AST-051) | "Moeda: Q-118; uso, chance e preço: Q-120" | DEC-108, DEC-129 | art-director | B | Citar as DECs; `Q-120` fica só para o uso. |
| AD-12 | `art/asset-list.md:509` (AST-028) | Loja ~36 × 48 "(MAP-01 §7.4)"; marcação do ponto seguro 10 × 6 | `levels/MAP-01.md:363` (36 × 32), `:168` (SS raio 6) | art-director + level-designer | M | Uma medida (depende de LD-2: a bancada pode exigir loja maior). |
| AD-13 | `art/asset-list.md:620–624` (AST-045) | Apartamentos "sobre o Pad (B1)", com porta D1 | `levels/MAP-01.md:140` (Z-11) e L01-38: apartamentos **sobre o Bellmoor Savings**; B1 é o prédio atrás do Pad | art-director | M | Separar: AST-045 = apartamentos sobre o banco (ANM-006); B1 = fachada do kit AST-033 com porta D1. |
| AD-14 | `art/asset-list.md:613` (AST-044) | Fachada 24 × 18; relógio Ø 6 a ~14 | `levels/MAP-01.md:171`, `:679`, `:693` (Ø ~5 a 12; fachada 28 × 30) | art-director + level-designer | B | Um conjunto de medidas. |
| AD-15 | `art/asset-list.md:462` (AST-043), `:443` | "A lona sai do carrinho na ligação (MAP-01 §11)" | `levels/MAP-01.md` §11.1 e `story/script.md` §1 não têm lona | art-director | B | Tirar o uso na cutscene ou pedir o beat ao narrative-writer. |
| AD-16 | `art/asset-list.md:482` (AST-052) | 18 × 7,5 × 8,5 | `levels/MAP-01.md:691` (~16 × 7) | art-director + level-designer | B | Uma medida (afeta a parada AMB-P). |
| AD-17 | `art/asset-list.md:361`, `:389`, `:398` | Cafeteira (38, 44), lixeira do trailer (42, 44), interruptor (45, 46.5) | `levels/MAP-01.md:343–345` ((40, 44), (43.5, 44), (46, 46.5)) | art-director | B | Copiar as coordenadas do MAP-01 (fonte da verdade espacial). |
| AD-18 | `art/asset-list.md` (ficha ausente) | Sem ficha de semáforo e faixa de pedestre | DEC-120 ("ficha nova") | art-director | M | Ficha nova (semáforo de carro + de pedestre, estados por tempo). |
| AD-19 | `art/asset-list.md:422`, `:855–867` | AST-042 e seção final como "recomendação para Q-076" | DEC-124 | art-director | B | Marcar decidido. |
| AD-20 | `art/asset-list.md:502`, `:553` (AST-050) | "Recomendação de Q-119"; "se Q-119 virar ingredientes…" | DEC-109 | art-director | B | Citar DEC-109. |
| AD-21 | `art/asset-list.md:139`, `:112–158` | L01-25 "Safe Spot no beco"; tabela de conciliação sem L01-35..38, L01-53, L01-54 | `levels/MAP-01.md` revisão 2 (§12) | art-director | B | Atualizar a tabela de conciliação. |

## 5. architect

| # | arquivo:linha | Conflito | Decisão/fonte que vale | Dono | Grav. | Correção sugerida |
|---|---|---|---|---|---|---|
| AR-1 | `tech/content-data.md:131` | `RunParams.Chances = 3 (DEC-057)` | DEC-110, DEC-112 | architect | A | 1. |
| AR-2 | `tech/content-data.md:310`; `tech/architecture.md:407–408` | `AllowOthers = true`: "qualquer presente paga por qualquer caído" | DEC-116 | architect | A | Robux: comprador = alvo. O Kit (item) segue `Q-120` f; separar as flags por método. |
| AR-3 | `tech/content-data.md:314` | `Revive.MaxPerNight = 0` (sem limite) | DEC-129 (2 por jogador por noite, Robux + Kit) | architect | A | 2. |
| AR-4 | `tech/architecture.md:425–427`, `:681` (D5); `tech/data.md:176`, `:260`, `:272` | Snapshot da noite repetida mantém quem já era `Spectator` (opção A); "aguardando o usuário" | DEC-111, DEC-113 | architect | A | No restore da **noite repetida** todos os membros voltam `Active` (Away continua Away); na retomada de 15 min o estado de vida volta como estava. |
| AR-5 | `tech/architecture.md:356–359`, `:370` | `Spectator → Reviving` ("reviver em spectate: Q-107"); `Revive.OfferWindow` | DEC-115 (até 6:00 AM da noite da queda; depois espectador sem oferta) | architect | A | Tirar a seta Spectator → Reviving; janela = até 6:00 AM. |
| AR-6 | `tech/architecture.md:366`, `:36` | Queda = `CharacterService:Ragdoll(player, ∞)` | `art/style-guide.md:237` (Aprovado: desmaio é animação, não ragdoll); `design/features.md:1092` | architect | M | Down = animação de desmaio + corpo ancorado; ragdoll só para atropelamento. |
| AR-7 | `tech/architecture.md:345`; `tech/content-data.md:129`; `tech/data.md:154`; `tech/network.md:140` | `Joined` só cresce; preço do trailer lido na hora da compra; `TrailerPartySource = Joined` | DEC-121 (quem entrou até o fim do Day 1, fixo) | architect | A | Congelar `PriceParty` no fim do Day 1; vale também para o Revive Kit (DEC-129). |
| AR-8 | `tech/architecture.md:446–447`, `:680` (D4) | Semáforo "precisa de OK"; travessia trailer ↔ Mart em CW-1 | DEC-120; no `MAP-01` CW-1 é o beco **sem** trânsito | architect + level-designer | M | Marcar DEC-120; acertar com o level-designer quais faixas têm semáforo (LD-4). |
| AR-9 | `tech/architecture.md:381–384`, `:518–522`, `:677–679`; `tech/data.md:45`; `tech/content-data.md:312`, `:316` | D1, D2, D3 como "precisa do usuário" / "proposta" | DEC-117, DEC-118, DEC-119 | architect | B | Marcar as DECs; mover T16 para decidida. |
| AR-10 | `tech/architecture.md:393`, `:586` | "Uma ambulância por jogador caído; no máximo 4 simultâneas" | `design/features.md:1103`, NPC-023 (`design/npcs.md:344`), `levels/MAP-01.md:531`: uma por servidor | architect | M | Uma ambulância; fila de coletas. |
| AR-11 | `tech/architecture.md:107`, `:490`; `tech/content-data.md:226` | Food Trailer listado na bancada; ponto de compra "bancada ou placa" | DEC-107; FEAT-015 (`design/features.md:549`), FEAT-016: prompt **no próprio trailer**, fora da bancada | architect | M | Tirar o trailer do `MarketService`; `BuySpot` = o trailer no estacionamento. |
| AR-12 | `tech/architecture.md:469–470`; `tech/content-data.md:187–188`, `:382` | Item derrubado: "Take" hold 0,5 s, some em 60 s, "tudo cai", Hot Dog recuperável | DEC-103 ("derruba o item **da mão**"); FEAT-033/FEAT-036 | architect | M | Ver GD-16: só a Tool equipada; prazo e prompt do game-designer. |
| AR-13 | `tech/architecture.md:622` | Noite: ≤ 6 luzes dinâmicas com sombra | `art/style-guide.md:270`, `:437` (Aprovado): ≤ 3 com sombra, ≤ 18 locais | architect | M | Adotar o style guide. |
| AR-14 | `tech/architecture.md:441–442`; `tech/content-data.md:336–338` | Trânsito à noite 0–2; `Speed` 24–32 | `design/features.md:1043–1045` (1 carro; 22 na reta, 12 no cruzamento); `levels/MAP-01.md:506` (20 / 10) | architect | B | Tabela com os números do game-designer (GD-15). |
| AR-15 | `tech/architecture.md:445`; `tech/content-data.md:334` | Rotas "Main St / Cross St (Q-096)" | `levels/MAP-01.md` revisão 2 (Ninth / Juniper; TR-1..TR-6) | architect | B | Usar os IDs de rota do MAP-01. |
| AR-16 | `tech/architecture.md:5–6`, `:10–14` | "DEC-001 a DEC-105"; rodada 12 "registro em andamento" (R12) | DEC-106, DEC-107, DEC-108 registradas; DEC-110 a DEC-129 | architect | B | Trocar R12-a/b/c por DEC-108/106/107; conciliar rodadas 13–15. |
| AR-17 | `tech/content-data.md:183` | `revive_kit` com `Ref = ITM-0xx` | ITM-021 (`design/items.md:226`) | architect | B | ITM-021. |
| AR-18 | `tech/content-data.md:322–325` | Tempos da ambulância (4 + 6 s…) e paradas `AMB-STOP-n` | FEAT-034 (tempos); `levels/MAP-01.md:217–219` (AMB-M, AMB-P) | architect | B | Copiar números do game-designer e IDs do MAP-01. |
| AR-19 | `tech/content-data.md:372` | `Nights.Duration (Q-044)` | DEC-127 (20, 21, 22, 23, 24, 26, 27, 28, 29, 30) | architect | B | Preencher. |
| AR-20 | `tech/content-data.md:342`; `tech/architecture.md:468` | `ImmuneTime` 4 s | `design/features.md:1061` (5 s) | architect | B | Número do game-designer. |
| AR-21 | `tech/network.md:240` | `Revive{Target, Method}` aceita qualquer alvo também para Robux | DEC-116 | architect | M | Validar `Target == sender` quando `Method = Robux`. |
| AR-22 | `tech/data.md:183`, `tech/architecture.md:493` | Oferta da bancada **fora** do snapshot (re-sorteada pela semente) | `design/features.md:159`, `:1163` (oferta **entra** no snapshot) | architect + game-designer | B | Mesmo efeito para o jogador; alinhar o texto num dos dois. |
| AR-23 | `tech/content-data.md:389` | `Cutscenes` com `trailer_swap` e `night_lost` | `design/features.md:235` (não são cutscene: transições no mundo, sem "Skip") | architect | B | Tirar da tabela `Cutscenes` ou marcar como transição. |
| AR-24 | `tech/architecture.md:348`; `tech/content-data.md:361` | Fluxo de clientes pelos "conectados" | `design/features.md:421` (ativos no início do turno, sem espectadores); `Q-067` | architect + game-designer | B | Fechar `Q-067`; `PartySource = "ActiveAtShiftStart"`. |

## 6. secretário (extra: documentos de registro)

| # | arquivo:linha | Conflito | Decisão/fonte que vale | Dono | Grav. | Correção sugerida |
|---|---|---|---|---|---|---|
| SC-1 | `vision.md:139` (§8.1) | "tamanho lido no início da run" (a tabela de `:157` já diz fim do Day 1) | DEC-121 | secretário | M | "contado no fim do Day 1 (DEC-121)". |
| SC-2 | `open-questions.md:111` (Q-034, Respondidas) | "DEC-053: volta no próximo turno com sanidade cheia" | DEC-093, DEC-111, DEC-113 | secretário | B | Anotar a emenda. |
| SC-3 | `open-questions.md:112` (Q-035, Respondidas) | "chances do chefe (3, cenário L)" | DEC-110, DEC-112 | secretário | B | Anotar a emenda. |
| SC-4 | `open-questions.md:71`, `:74` (Q-093, Q-096) | Abertas | `levels/MAP-01.md` revisão 2 já moveu o ponto seguro para o Mart e adotou os nomes de `world.md` | secretário | B | Confirmar com o level-designer e mover para Respondidas (resolvidas em documento, sem DEC nova). |
| SC-5 | `open-questions.md:73` (Q-095) | Aberta; cita `style-guide.md` como Rascunho com câmera 4,6 | `art/style-guide.md:149–157` (Aprovado, DEC-126): 4,5 e 3,5, igual ao MAP-01 | secretário | B | Pode fechar por DEC-126. |
