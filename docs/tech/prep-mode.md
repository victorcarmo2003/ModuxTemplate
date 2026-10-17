Status: Rascunho

> **Nota (2026-10-12, feedback do dono "é tudo 3d"): a interface do minigame mudou de rumo.** `docs/tech/prep-3d.md` (Rascunho, Provisório) supera deste documento **a UI 2D do miolo**: tábua 2D, painel de ingredientes, células da grelha, cartões de Order/Serve e StrokeCanvas (§2 coluna "Cliente", §5 Mobile "arrasto sobre Frames", §6 "UI é 2D (Frames...)", DT-8). O minigame passa a ser interação direta com os objetos 3D do trailer (raio do ponteiro, anéis, brilhos, partículas); só ticket, abas, Leave, Next/Serve, Assist, nota/selo, dica e toast ficam em 2D. **Continua valendo daqui, sem mudança:** rede e autoridade (§3), co-op e assentos (§4), noite e saídas forçadas (§5), mapa `Station_n` e `Content.Prep` (§6), migração dos prompts e `WorldKitchenPrompts` (§7), riscos e métricas (§9). Migração por flag `Prep.Rules.ThreeD`; tasks TASK-194 a TASK-215 (`docs/tasks/board.md`); TASK-174, 175, 177, 178 e 179 marcadas "Substituída parcialmente por 3D".

# Modo de preparo focado (V1): desenho técnico

Autor: architect · 2026-10-12 · Base: decisões do dono D1 (modo focado V1, 100% focado), D2 (Food Trailer é o veículo único), D3 (intro curta), FEAT-039, Q-218 a Q-223. Tudo **Provisório**; nada aqui é código. `DT-n` = proposta de DEC técnica (o secretário numera; o dono pode vetar), lista em §10. Estende `KitchenService`, `ItemService`, `CustomerService`, `CameraController`; **não** cria economia nem estoque paralelos.

## 1. Pesquisa Papa's em 12 linhas

1. Uma tarefa por estação (Hot Doggeria: Order, Grill, Build e uma estação de bebida/pipoca; Pizzeria: Order, Build, Bake, Cut), troca por botões nos cantos. **Lição:** abas curtas, uma tarefa por tela.
2. O ticket fica sempre à mão e troca-se de ticket pelos cantos. **Lição:** ticket fixo na lateral, sem abrir menu.
3. Grelha com anéis: vira quando o anel interno fica laranja, pronto quando o externo chega ao verde. **Lição:** "janela de virar" visível; aqui **sem queimar** na fase 1 (Q-222).
4. Salsicha arrastada ao pão; o prato "desliza" à montagem. **Lição:** arrasto + um botão de avançar (Next).
5. Montagem: número, posição e espaçamento contam; molho usa medidor. **Lição:** nota por precisão do gesto, não pelo preço.
6. Cada estação pontua e o cliente soma precisão, velocidade e apresentação; atender/preparar devagar custa pontos. **Lição:** nota por etapa; a espera já é a paciência (Q-192).
7. Gorjeta e bônus seguem a qualidade; upgrades mudam estações. **Lição:** Perfect paga gorjeta; tolerâncias entram como upgrade depois.
8. Várias comandas em paralelo (a grelha cozinha enquanto se monta). **Lição:** manter a grelha paralela; cortar o pão enquanto a salsicha assa.
9. Não confirmado nas fontes (403 nos sites oficiais): semântica exata de lixeira e de Next; tratados como convenção do gênero.
10. **Não copiar:** nome Papa's/Flipline/Louie, personagens, arte e layout 2D, estrelas/ranks, estação de pipoca, textos de ticket.
11. **Não copiar:** queimar e punir ordem de ingredientes (aqui ordem é livre) nem o loop de tela 2D fechada.
12. **Identidade própria:** mundo 3D do trailer visível atrás da UI (DOF), toy low-poly, Mustard/Cream/Ink, Fredoka (`Theme`), sem vermelho de alerta, co-op de 1 a 4 estações.

Fontes: [Flipline Blog](https://www.flipline.com/blog/?p=9841), [Papa's Pizzeria (wiki)](https://papasia.fandom.com/wiki/Papa%27s_Pizzeria), [Flipline Order Station](https://fliplinestudios.fandom.com/wiki/Order_Station), [App Store Hot Doggeria HD](https://apps.apple.com/app/id1292787392) (via busca; páginas sem acesso direto).

## 2. Fluxo do jogador e do servidor

**Ativar.** Prompt `Work` (`prep_work`, tap, raio 5) no `Prompt_Work` de cada `Station_n`; no mobile o botão de interagir já serve (sem botão novo). Servidor (`PrepService`): membro Active, fase de venda, estação ativa e livre, veículo corrente, jogador sem outra estação, sem trava de reentrada (§5). Se ok: grava o assento no set `PrepSeats`, `CharacterService:Freeze(player, "Prep", true)` (o `CharacterController` já trava controles por `Frozen`), `PivotTo` em `Att_Stand`, atributo `Working = n` no personagem. Cliente (`PrepController`): `CameraController:Prep(on, camCFrame, focus, fov)` (modo novo, Scriptable, tween 0,35 s, instantâneo com "reduced motion", DOF só em qualidade > 3), `InputController:SetContext("Menu")`, gate de prompts do mundo, monta a UI Vide.

**Aba de entrada (pedido do dono 2026-10-17, Provisório).** O modo abre na parte da bancada onde o jogador está, não sempre na grill: `PrepService:StepNear` escolhe, entre as abas ativas, a vista (`Content.Prep.Views`) cujo `Focus` no `Station_n` fica mais perto do jogador no plano do chão. Perto da grill = `Grill`, da tábua de pães = `Board`, das coberturas = `Toppings` (abre com o aviso "corte o pão e ponha a salsicha primeiro" se não há prato). O `Step` vai no registro de `PrepSeats` e o cliente abre nessa aba e câmera; o personagem vai para `Att_Stand_Build` em Board e Toppings. Sem `Focus` no mapa vale o `PromptStep` do prompt. `/dev prep enter <n>` sem aba usa a mesma regra.

**UI (paisagem, ref. 667x375).** Abas no topo (Order, Grill, Build, Serve), ticket na lateral esquerda, superfície de trabalho no centro, painel de ingredientes à direita, lixeira embaixo à esquerda, botão **Next** (vira **Serve** na entrega) embaixo à direita, pílula **Leave** sempre visível (Mustard, abaixo da pilha de HUD de dinheiro/dia, respeitando `DeviceSafeInsets`). Alvos >= 44 px.

| Etapa | Cliente (local) | Servidor (autoridade) |
|---|---|---|
| **Order** (aba) | fila de tickets (set `Customers`, `Waiting`, mais antigo primeiro, anel de paciência, marca de quem fixou); botão "Take" no cliente em `Ordering`; fixar ticket = guia | `PrepOrder Take` chama `CustomerService:TakeOrderFor`; fixar vai no `PrepSeats.Ticket` |
| **(a) Grill** (aba) | slots do set `Stations` (`grill`, `rail`); "+ Sausage"; janela de virar em 40% a 60% da `Duration`; "Collect" | `PrepGrill`: `Place`/`Collect` pelas ações existentes (`Perform`), `Flip` carimbado com o **relógio do servidor**; nota da salsicha pela distância a 50%; sem virar = Messy; sem queimar |
| **(b) Bun** | `PrepBegin`; arrastar a faca na linha tracejada; o pão abre | reserva 1 pão (`TakeStock`) e a vaga `n` da tábua (registro `Working`); altered (ANM-002) vira o pão mordido já pronto |
| **(c) Build** | arrastar a salsicha da frente do trilho ao pão (imã a 20%); toppings por gesto em **ordem livre**, até 3, sem repetir (lista pelo `UnlockDay`/`Blocked` do set `Stock`); lixeira descarta o prato; **Next** | só no **Finish** (abaixo) |
| **(d) Serve** | selo Perfect/Good/Messy; aba Serve: cartões dos clientes do balcão e das mesas, o que combina vem destacado; toque = `PrepOrder Serve` | `CustomerService:ServeFor` reaproveita `ServeCustomer` (`PickServeTool` escolhe o hot dog exato do hotbar): Completo/Incompleto/Errado (DEC-072) inalterados |

**Finish (transação única, tudo ou nada).** Cliente manda o RESUMO; o servidor valida (§3), e só então: tira a salsicha da frente do trilho (`Rail.Pop`, com a nota dela), toma 1 uso de cada topping (`TakeStock`), cria o `hot_dog` (`ItemService:Give` com `Toppings`, `Quality`, `Altered`), libera a vaga da tábua e emite `assembled`. Falta de estoque ou trilho vazio = recusa **sem mudar nada**; o prato continua no cliente (`Parked`) até haver salsicha. Hotbar cheia (`hands_full`) idem. **Leave** devolve o pão reservado (se não houve Finish); **lixeira** perde pão e salsicha (como `Trash.luau`) e, com prato na mão, dispara `Perform("discard")` na BIN-C para manter o sinal `Discarded` do ANM-002.

**Nota.** Pontos por etapa Perfect 100, Good 70, Messy 30 (FEAT-039); prato Perfect se média >= 88 e nenhuma Messy, Good se >= 60. O cliente envia medidas 0 a 100; o **servidor** converte em faixa (`Content.Prep.Grades`), então retocar números é só dados. Efeito (Q-219 B, só gorjeta e humor, nunca o preço): Perfect = gorjeta $2 e janela +4 s; Messy = sem gorjeta, humor -1 faixa. Ponto de extensão único: `CustomerService:SellLine` lê `ItemService:QualityOf(tool)`.

## 3. Autoridade e rede

O cliente roda o minijogo e manda **um resumo por prato**. O servidor valida por plausibilidade: (1) sessão aberta (assento + `PrepBegin`), (2) tempo medido **no servidor** de `PrepBegin` a `PrepFinish` >= `MinPlate + PerTopping x K` (o `Ms` do cliente só cruza: `Ms <= tempo do servidor + 1,5 s`), (3) toppings únicos, <= `OrderRules.MaxToppings`, chave válida, não `Blocked`, com estoque, (4) notas inteiras 0 a 100, (5) **teto de nota por tempo**: abaixo de `PerfectMin` o prato não passa de Good, (6) limite de pacotes por segundo. O pior caso de um resumo forjado é "Perfect lento", que vale +$1 de gorjeta por prato: abuso barato de limitar, não precisa de anti-cheat pesado. Latência não pune: a nota da salsicha é carimbada no servidor e o resto é medida local.

Entradas novas em `src/Libs/Net/init.luau` (donos: `PrepService` responde todas, no `OnInit`; ritmo máximo por jogador):

| Entrada | Dir. | Schema (resumo) | Ritmo | Por quê |
|---|---|---|---|---|
| `PrepEnter` / `PrepLeave` | c->s | `{Station: int(1,4)}` / vazio | 2/s | pacote simples, nada a replicar além do assento |
| `PrepTab` | c->s | `{Step: enum(Order,Grill,Build,Serve), Ticket: int(0,65535)}` | 4/s + 1 a cada 15 s (batimento) | atualiza o assento e vale como "estou vivo" (timeout de 60 s) |
| `PrepGrill` | c->s | `{Act: enum(Place,Flip,Collect), Slot: int(0,8)}` | 6/s | o servidor decide slot livre e nota |
| `PrepBegin` | c->s | vazio | 1/s | reserva pão e vaga |
| `PrepFinish` | c->s | `{Cut, Place: int(0,100), Toppings: array({Key: enum(ToppingKeys), Score: int(0,100)}, 0, 3), Ms: int(0,65535)}` | 1/s | o resumo (~12 bytes) |
| `PrepTrash` | c->s | vazio | 2/s | lixeira |
| `PrepOrder` | c->s | `{Act: enum(Take,Serve,Refuse), Npc: int(1,65535)}` | 4/s | atalhos das abas Order e Serve; mesmo caminho do `CustomerService` |
| `PrepResult` | s->dono | `{Act, Ok, Reason: enum, Grade: enum(None,Messy,Good,Perfect), Value: int(0,255)}` | uma por pedido | resposta privada (packet, não set); `Kick` carrega o motivo da saída forçada |
| `PrepSeats` | set | id = estação 1..4 (só as ativas): `{User: f64, Step: enum, Ticket: int(0,65535), Since: f64}` | ~0,5 escrita/s no total | todos precisam ver quem trabalha onde (e quem entra tarde recebe o estado); 4 registros, **sem** risco de `drop.section` (menos de 8) |

Sem `keyBy`. Sem Remote novo fora do Lync. Os sets `Stations`, `Stock`, `Customers`, `Tables`, `Thief` e `Anomalies` já existem e alimentam a UI inteira.

## 4. Co-op (1 a 4 estações)

- **Quantas:** `PrepSeats` só tem registro para as estações ativas = `clamp(membros conectados, 1, 4)`, recalculado no `ShiftStarted` e em `MemberJoined`; **só cresce** durante o turno (assento ocupado nunca some). Cada `Station_n` é uma posição de câmera e de uso sobre a mesma bancada (Q-220 C); a vaga `n` da tábua é do assento `n`.
- **Vínculo:** jogador <-> assento é 1:1 (`PrepEnter` recusa com `Busy` ou "já está sentado"); a checagem e a escrita são síncronas, então dois toques no mesmo frame nunca ocupam o mesmo assento. Saída/queda/Away libera e devolve o pão reservado.
- **Fila compartilhada:** o set `Customers` é a fila. Ao entrar, o servidor sugere o ticket mais antigo sem marca; fixar é só guia (a entrega segue Completo/Incompleto/Errado). Dois no mesmo ticket mostram um chip de conflito, sem trava.
- **Compartilhado:** grelha, trilho e estoque (um `TakeStock` síncrono evita pegar a mesma unidade).
- **O que os outros veem:** o rig parado em `Att_Stand` com `Working` (clipe "work", cai no idle até o usuário animar, DEC-220), etiqueta `StationTag` sobre a estação (nome + ícone da aba, a partir de `PrepSeats`), o pão na tábua pelo registro `board` e o hot dog na mão.

## 5. Noite, sanidade, tutorial, HUD e plataformas

- **Saída forçada (Q-221 A):** sinal de anomalia (0,4 s, tremor curto, 0,5 s sem input), troca de faixa de sanidade, `Down`, cutscene/ligação do chefe, fase `Summary` ou `Closing` terminada, ladrão `Approaching`/`Opening` (ícone no HUD do foco antes). O servidor executa (`PrepService:Kick`) e avisa por `PrepResult Kick`; o cliente também sai ao ver o sinal (apresentação). Ponto de extensão pedido: `AnomalyService.Cued(anomaly)` (sinal ao lado do `AnomalyCue`) e `HasLive()`. **Reentrada:** travada só durante `Signal` + `CueLock` (6 s, Provisório); "até resolver" (A literal) deixaria o jogador fora da cozinha em anomalias longas (§9).
- **Sanidade:** continua descendo; HUD de sanidade segue visível no topo esquerdo. Atropelamento só ocorre na rua; dentro da estação não há risco. O "ver" -5 e o "não olhar" contam depois da saída.
- **Tutorial (reescrita):** telefone, abrir loja e Take Order continuam no mundo. O passo "preparar" vira: Work -> Grill (`+ Sausage`, virar, Collect) -> Bun (cortar) -> Build (arrastar, um molho) -> Next -> Serve. `TutorialController` ganha um `PrepCoach` que lê `PrepController.Step` e eventos (`placed`, `flipped`, `cut`, `built`, `served`) e pulsa o alvo da UI; o `TutorialPromptGate` passa a gatear `prep_work`. Vozes e `Steps` novos são texto do narrative-writer.
- **HUD:** em foco, `HudOrder` some (o ticket da UI o substitui); dinheiro, dia, relógio, sanidade e avisos ficam. Prompts de preparo saem do mundo (§7); ficam Work por estação, Mart, telefone, caixa, café, restock, lixeira de rua.
- **Mobile:** arrasto fora da área do joystick (travado pelo `Frozen`), cursor deslocado 28 px acima do dedo, "Assist" (+30% de tolerância), "segurar" no lugar de arrastar e "Reduced motion" **obrigatórios** na fase 1 (DEC-223: não há modo rápido de reserva). **Gamepad:** stick esquerdo move o cursor virtual, A segura/solta, B = Leave, Y = Next, LB/RB = trocar aba, D-pad = trocar ticket. **Teclado/mouse:** arrastar com o botão esquerdo, `Tab` troca aba, `Enter` = Next, `Esc`/`Q` = Leave.

## 6. Mapa, dados e serviços

**Mapa (level-designer).** Em cada `Station_1..4` do trailer, Model com tag `Station` e `StationKind = "prep"`, filhos: `Att_Stand` (onde o rig fica), `CamAnchor` (CFrame da câmera, ~2,5 studs da bancada, pitch ~-55°), `Focus` (alvo do DOF), `Prompt_Work` (tag `Interactable`, `PromptAction = prep_work`), `Att_Bun` (a vaga `Slot = n` da tábua). `Vehicles.trailer.BoardSlots = 4`.

**Content novo** (`src/Shared/Content/Prep.luau`, no padrão `Table`, requerido por `Net` para os enums; `Validate.luau` cruza chaves com `Ingredients`/`Stations`/`Actions`):

| Tabela | Conteúdo |
|---|---|
| `Rules` | `Enabled`, `WorldKitchenPrompts` (false), câmera (`Fov` 55, `Travel` 0,35, `Leave` 0,30), `ForcedExit`, `CueLock`, tempos (`ClientIdle` 20, `SeatIdle` 60, `PlateMax` 90), `Reach` (14), plausibilidade (`MinPlate`, `PerTopping`, `PerfectMin`, `MsSlack`), `Assist` 1,3, `TouchOffset` 28 |
| `Steps` | linhas ordenadas: `grill`, `bun`, `build`, `serve` (aba, rótulo, o que habilita o Next) |
| `Gestures` | `slice`, `place`, `trace`, `slide`, `taps`, `hold`: amostragem (30 Hz) e mínimo de pontos |
| `Tolerances` | por alvo (`bun_cut`, `sausage_place`, `ketchup`, `mustard`, `cream_cheese`, `cheese`, `bacon`, `potato_sticks`, `grill_flip`): gesto, limites Perfect/Good (números de FEAT-039). Topping novo = uma linha |
| `Grades` | pontos, faixas e efeitos (gorjeta, janela, humor) |

Mais: `Content.Actions` ganha `prep_work`; `Content.Stations` ganha `prep` (`Record = "None"`); `Content.Animations` ganha `work`; `Content.Sounds` ganha `prep_*` (cortar, esguicho, virar, selos); `Content.Notices` ganha os motivos de recusa. Atributo de Tool novo: `Quality`.

**Código** (um dono por pasta; tipos de `ModuxTypes` são gerados):

| Peça | Papel | Prioridade / `Require` |
|---|---|---|
| `src/Prep/server/PrepService` (+ `Session`, `Validate`, `Exits`) | assentos, sessão, validação, saídas forçadas, gate de `Interact` | 645; `PlaceService, NetService, RunStateService, RoundService, InteractionService, CharacterService, ItemService, KitchenService, CustomerService, AnomalyService`; sinais de serviço de prioridade menor conectam no `OnStart` |
| `KitchenService/Plate.luau` + métodos públicos | `BeginPlate`, `FinishPlate`, `RefundPlate`, `GrillAct`; nota da salsicha no `Entry` do `Rail`; `Flip` no `Grill`; flag `WorldKitchenPrompts` | já 650, sem dependência nova |
| `CustomerService` (pequeno) | `TakeOrderFor`, `ServeFor`, `Refuse`, gorjeta/humor por `Quality` | sem dependência nova |
| `ItemService` (pequeno) | `Quality` no `Give`, `QualityOf`, entra no snapshot `T` | idem |
| `src/Prep/client/PrepController` (+ `Session`, `Gestures/*`, `Stages/{Order,Grill,Build,Serve}`, `Cursor`) | estado, rede, gestos, nota local | 675; `InputController, CameraController, PromptController, KitchenController, CustomerController, RoundController, VitalController` |
| `src/Prep/shared/Grade` | pontuação pura (cliente e servidor usam a mesma conta) | sem Modux |
| `Interface/client/Components/Prep*` | `PrepShell`, `TicketRail`, `IngredientPanel`, `PlateView`, `StrokeCanvas`, `StationTag`, com stories | Vide, sem rede |
| `CameraController` | modo `Prep` (CFrame fixo, DOF `PrepFocus`) e saída | prioridade existente |
| `PromptController` | `AddGate(name, fn)` (hoje há um único `SetGate`, do tutorial) | idem |

**Persistência:** nenhuma nova (sem Template, sem migração). Só `Quality` entra no snapshot de Tools da run (`data.md` §3.3). **Performance:** rede < 1 pacote/s por jogador; `PrepSeats` <= 4 registros; servidor com tick de 2 Hz só para timeouts; cliente com uma captura de arrasto (amostra a 30 Hz), traço do molho em <= 64 pontos reaproveitados, um `DepthOfFieldEffect`, DOF desligado em qualidade <= 3. A UI é 2D (Frames, sem `ViewportFrame` na fase 1); o 3D do mundo mostra o resultado pelos registros `board`/`rail`.

## 7. Migração dos prompts de cozinha

| Item | Destino |
|---|---|
| `grill_place`, `grill_collect`, `bun_cut`, `board_add_sausage`, `topping_add`, `discard` da BIN-C | **ocultos** com `Prep.Rules.WorldKitchenPrompts = false` (`KitchenService:RefreshPrompts` força `PromptEnabled = false`; os handlers continuam registrados). Ligar o flag devolve o fluxo antigo: **rollback sem código** |
| Módulos `Grill`/`Board`/`BunCrate`/`Toppings`/`Rail`/`Trash` | ficam (a transação do Prep usa as mesmas funções; `Rail`/`Board` ganham nota e `Occupy`) |
| `KitchenController` (visuais de grelha, trilho, tábua, estoque, tampas) | ficam: o mundo continua refletindo o estado |
| Hotbar | não há Tool de salsicha/pão (verificado em `Content.Items`); o `hot_dog` é a única saída; pacotes seguem para restock |
| `restock`, lixeira de rua, `brew_coffee`, `collect_cash`, `answer_phone`, `open_sign`, Mart, luz/janela/porta | **ficam no mundo** |
| `take_order`, `serve`, `refuse`, `serve_table`, `clean_table` | **ficam no mundo** (o tutorial os usa antes do foco); as abas Order/Serve são atalhos pelo mesmo caminho do `CustomerService` (DT-6) |
| `Tutorial/Steps` | reescrito (§5) |
| Carrinho (D2) | fora do escopo desta peça: `Vehicles`, `Vehicle` e fluxo de compra são da D2; o Prep assume só o trailer, `BoardSlots = 4` |

## 8. Ondas de TASK (sugestão para o task-planner)

| Onda | Task (trilha) | Aceite | Depende |
|---|---|---|---|
| **0** | **P0** contratos (architect): `Content/Prep.luau`, linhas de `Actions/Stations/Animations/Notices`, entradas de `Net`, `Prep/shared/Grade` com testes de tabela | `modux check` e `analyze` limpos; start do Lync sem erro de schema | DECs |
| 1 | **P1** backend Kitchen: `Plate.luau`, API pública, nota da salsicha, `Flip`, flag | `BeginPlate`/`FinishPlate` atômicos (estoque, trilho, vaga) com recusa limpa; flag liga/desliga o fluxo antigo | P0 |
| 1 | **P2** backend `PrepService`: assentos, validação, `Freeze`, gate, `PrepSeats`, batimento | 2 jogadores nunca ocupam o mesmo assento; resumo inválido recusado; sai ao desconectar | P0 (mock do P1 por tipo) |
| 1 | **P3** backend Customer/Item: `Quality`, gorjeta/humor, `TakeOrderFor`/`ServeFor`, snapshot | Completo/Incompleto/Errado idênticos; Perfect paga $2; Messy sem gorjeta | P0 |
| 1 | **P4** level: `Station_1..4`, âncoras, 4 vagas, esconder âncoras antigas, snippet idempotente (nunca `Place.run` sem pedido) | `modux check` + `/dev smoke`; câmera de cada estação enquadra a tábua | P0 |
| 1 | **P5** frontend núcleo: `PrepController`, modo `Prep` da câmera, `AddGate`, cursor virtual, captura de arrasto, saída | entra/sai sem vazar câmera, controles ou contexto de input; sai em 0,4 s | P0 |
| 1 | **P6** UI kit: `PrepShell`, `TicketRail`, `IngredientPanel`, `PlateView`, `StrokeCanvas`, `StationTag` + stories (UI Labs) | alvos >= 44 px, sem vermelho, texto >= 14 px, 667x375 sem sobreposição | P0 |
| 2 | **P7** estágios: Grill (virar), Bun (cortar), Build (arrastar, molhos, queijo, bacon, batata), Serve, Order | prato hábil em 9 a 12 s; o resumo passa na validação; Assist funciona | P1, P2, P5, P6 |
| 2 | **P8** co-op e presença: `PrepSeats` no cliente, `Working`, clipe, chip de ticket | 4 jogadores veem quem está em qual estação; entrar tarde mostra o estado | P2, P6 |
| 2 | **P9** saídas e dev: `AnomalyService.Cued`/`HasLive`, saídas por Vital/Cutscene/Thief, `/dev prep` | sinal de anomalia expulsa em 0,4 s; reentrada travada só no `CueLock` | P2 |
| 3 | **P10** tutorial reescrito + `PrepCoach` + áudio `prep_*` | rookie completa o primeiro hot dog no foco, pulável | P7 |
| 3 | **P11** QA e balanceamento: plano do qa-tester, teste de ritmo (solo e 4), mobile, perf | métricas de §9 dentro do alvo | tudo |

## 9. Riscos e métricas

| Risco | Mitigação |
|---|---|
| Ritmo: foco 12 a 18 s contra 8 a 10 s hoje; solo com cliente a cada 14 s deixa o balcão sem atendente | abas Order e Serve (atender sem sair), grelha paralela, estação fixa tira as caminhadas, medir `Left`/`Slow` antes e depois |
| Arrasto no celular | Assist, cursor deslocado, alvos grandes; flag `WorldKitchenPrompts` religa o fluxo antigo se a taxa de abandono passar do alvo |
| Fuga das anomalias (olhar só a tábua) | saída forçada (Q-221 A); "ver" mede a câmera de quem voltou |
| Reentrada travada demais | `CueLock` curto; decisão do dono se vale "até resolver" |
| Falta de sprites 2D (Q-152, `Icon = ""`) | formas Frames em Mustard/Cream/Ink como placeholder; ficha de asset ao art-director |
| D2 (carrinho sai) mexe em `Vehicles`, tutorial e Mart ao mesmo tempo | P0/P4 só assumem trailer; integração marcada na D2 |
| Conflito de modos de câmera (Cutscene, Spectate, Fixed, External) | `Prep` é exclusivo; qualquer saída forçada vem antes de trocar de modo |
| Hotbar cheia, estoque no meio do prato, desconexão | `Parked`, recusa sem mutação, devolução do pão reservado |

**Métricas** (log de servidor + `/dev smoke`): tempo de prato p50/p90 por dia e por plataforma; % Perfect/Good/Messy; clientes `Left`/`Slow` contra o baseline do modo antigo; saídas forçadas por noite; recusas por motivo; abandono do foco (Leave sem Finish); desperdício (lixeira); pacotes/s por jogador.

## 10. Decisões técnicas propostas (veto livre) e perguntas

- **DT-1** Uma feature `Prep` (`server`, `client`, `shared`); sem serviço paralelo de estoque/dinheiro: o `KitchenService` segue dono de estoque e estações. **DT-2** Resumo por prato com validação por plausibilidade e nota carimbada no servidor onde há tempo (virar). **DT-3** Rede: 7 pacotes c->s pequenos, 1 resposta privada, 1 set `PrepSeats` (4 registros). **DT-4** Câmera `Prep` como modo próprio do `CameraController`. **DT-5** Flag `WorldKitchenPrompts` como rollback sem código. **DT-6** Prompts de cliente (Take/Serve/Refuse/mesa) ficam no mundo; as abas são atalhos pelo mesmo caminho (resolve "atender no mundo" x "Serve no foco"). **DT-7** Sem persistência nova; `Quality` no snapshot. **DT-8** UI 2D na fase 1. **DT-9** Estações = membros conectados (1 a 4), só crescem no turno. **DT-10** `Content.Prep` em `Shared/Content`.
- **Nomes:** DEC-223 sugere `Focus*` (`FocusController`, `FocusService`, `FocusBoards`, `Content.Focus`); aqui valem os nomes `Prep*` do pedido (`PrepSeats` faz o papel de `FocusBoards`) e a aba de entrega é **Serve** (DEC-223). Renomear é barato antes da P0.
- Perguntas ao dono (não bloqueantes, secretário numera): (1) DT-6 vale? (2) reentrada após anomalia: `Signal` + `CueLock` ou "até resolver"? (3) salsicha **não virada** = Messy? (4) números de Perfect/Good/Messy e tolerâncias (todos Provisórios).

## Referência 2: Good Pizza, Great Pizza (pesquisa de 2026-10-12, Provisório)

Relatório completo: `docs/research/good-pizza-great-pizza.md`. Só inspiração de mecânica; nada de nomes, arte, falas ou layout idêntico.

- **Fluxo do jogo de referência:** pedido falado pelo cliente, montar, forno, cortar, caixa, entrega. "What?" faz o cliente repetir uma vez e derruba o humor. Não há ticket na tela: o jogador memoriza. O pedido ambíguo é interpretado pelo jogador, com padrão implícito (massa, molho e queijo).
- **Ingredientes:** caixas em grade; cada uso custa estoque. Exagero reclama e reduz gorjeta; pedido exato dá gorjeta; pedido errado vira reembolso.
- **O que é transferível:** ticket com frase do cliente + ícones; padrões implícitos (pão e salsicha sempre presentes, só o que foge disso é dito); caixas em grade com toque; custo por uso (já existe no `TakeStock`); "Come again?" com custo de paciência; pedido literal contra pedido estranho (liga com anomalias e a regra do Walt).
- **Layout sugerido (Provisório):** ticket no topo; pão e prato no centro-esquerda; caixas de molho e complementos em grade 2x3 à direita (alvos ≥ 44 px); lixeira embaixo à esquerda; Next/Serve embaixo à direita; Leave sempre visível.
- **Gesto:** molho se arrasta da caixa e se traça em zigue-zague sobre o pão, com medidor de quantidade; queijo, bacon e batata entram por um toque cada; "segurar" como alternativa ao arrasto no mobile.
- **Diálogo ao Take Order (opcional, atrás de flag):** tela com a fala do cliente e 2 botões ("Got it" confirma o pedido literal; "Come again?" gasta paciência e revela o detalhe). A escolha muda a variante do ticket e o humor (-1 faixa), nunca o preço. Clientes estranhos só oferecem a leitura estranha. Cada frase ambígua precisa de uma leitura correta registrada (`Reading`). Ambíguos só a partir do Dia 3.
- **Pedidos originais de exemplo (inglês):** "The usual, please. You know the one."; "Mustard, but only on the side facing the window."; "Plain. And please don't look while you make it."; "Make it taste like Sunday. Not this Sunday."; "Whatever she's having. She's right behind me."
- **Não confirmado:** gesto de espalhar e fórmula de nota (Fandom deu erro 402). **Pergunta ao dono:** o diálogo entra no V1 ou numa fase seguinte? (Q-227 sugerida.)
