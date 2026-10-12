Status: Rascunho (Provisório até DEC do dono; nada aqui é código)

# Preparo 3D-first: o minigame é o mundo, não um painel

Autor: architect · 2026-10-12 · Base: feedback do dono (abaixo), DEC-223, `docs/tech/prep-mode.md` (continua valendo para rede, assentos, nota, saídas e migração dos prompts), `docs/art/prep-ui-spec.md` (a parte de HUD e câmera continua; a parte "tábua 2D" é superada aqui), FEAT-039, o código atual de `src/Prep/**`, `src/Kitchen/**` e `Content.Prep`. Tudo **Provisório**. `DT-n` = decisão técnica proposta (o secretário numera; o dono pode vetar), lista em §14. Não implementa feature nenhuma; o plano de execução está em `docs/tasks/board.md` (TASK-194 a TASK-219).

**Rev. 2 (2026-10-12, revisão do dono):** TUDO 3D com os assets reais e animação de verdade (§6A: swap x EditableMesh, recomendação e spike); **toppings também 3D** (§3.4), navegação **só por seções em sequência** Grelha, Tábua, Toppings, Servir (§3.0); **abas embaixo** e topo livre (§5); highlight, cursor virtual e ferramentas dinâmicas (§2.6); referências novas em `Assets/reference/prep-mode/`. O 2D que sobra: ticket (esquerda), selo/nota, Leave/Next, barra de condimentos opcional (direita), progresso fino no topo.

## 0. O pedido do dono e como o lemos

> "Ajusta por favor essa interface, eu quero que seja tudo 3d, n tem pq ter essa interface da grelha, é tudo 3d mano" (olhando a aba Grill: painéis 2D com células "Add +", "Flip when the ring glows", trilho "Rail empty", cartão do pedido #1).

Leitura (a validar com as perguntas Q-228 a Q-234):

1. O minigame passa a ser **interação direta com os objetos reais do trailer** sob a câmera focada: salsichas na grelha, pão e faca na tábua, tigelas de molho, queijo, bacon, batata, lixeira, janela de entrega.
2. O feedback é **3D**: anel que converge, brilho/contorno, mudança de cor da salsicha, fumaça, partículas, sombras, sons. Nada de barras e células 2D que dupliquem o que o mundo já mostra.
3. Fica de 2D **só o mínimo**: ticket/pedido, abas/estágio, Leave, Next/Serve, Assist (e o modo "tocar e tocar"), nota/selo, uma linha de dica, o toast e o status (dinheiro e relógio). §5.
4. **Não muda**: servidor autoritativo, `Grade` (única conta de nota), `Content.Prep` (tolerâncias), pacotes `Prep*`, set `PrepSeats`, assentos 1 a 4, saídas forçadas, `WorldKitchenPrompts`, DEC-072 (Completo/Incompleto/Errado), estoque e dinheiro. Só muda **a entrada** (de "ponteiro sobre Frames" para "raio do ponteiro sobre objetos") e **a saída visual** (de Frames para modelos, anéis e partículas).

O que já existe e ajuda muito: o mundo **já desenha** a grelha, o trilho, a tábua e o estoque por registros replicados (`KitchenController`: `Slots.Food`, barra, fumaça, sizzle, `Fx`), a câmera `Prep` e as vistas por aba (`Poses`), o `Pointer`/`Cursor` unificados (mouse, toque, gamepad), os gestos e suas medidas puras (`Gestures/*` + `Grade`), e o `Feed` (retrato reativo da fila e da grelha, os cinco atos, o `Flipped` por slot). A migração é, na maior parte, **trocar a entrada e esconder o 2D**, não reescrever o jogo.

## 1. Resumo do desenho

| Camada | Antes (2D sobre 3D borrado) | Agora (3D-first) |
|---|---|---|
| Entrada | `Pointer` + `Gestures` sobre `GuiObject` (região normalizada) | `Pointer` + **raio** (`World/Aim`) sobre hitboxes `PrepTarget`; arrasto por **plano**; `Gestures` aceita região de plano (`PlaneRegion`) |
| Grelha | 8 células "Add +" com barra e anel em Frame | as 8 posições reais dos roletes: salsicha fantasma convida, cor sobe com o tempo do servidor, **anel 3D** converge na janela de virar, toque vira (a salsicha gira), pronta pula para o trilho real |
| Tábua | `PlateView` 2D + `StrokeCanvas` | pão real no `Att_Bun n`, faca real como ferramenta, guia de corte 3D, salsicha arrastada do trilho real ao pão, molho em segmentos 3D |
| Ingredientes | `IngredientPanel` 2x3 | **toppings 3D**: as tigelas reais (AST-017) e as ferramentas dinâmicas na mão (garrafa que inclina e escorre, concha, fatia, tira de bacon, pitada); atalho 2D só opcional (Q-237) |
| Navegação | 4 abas no topo (Order, Grill, Build, Serve) | 4 **seções em sequência** (Grill, Board, Toppings, Serve) em abas **embaixo**; topo livre; progresso fino no topo |
| Animação | Frames | assets reais: cross-fade/textura e, como camada opcional, EditableMesh (morph do pão, tubo de molho), §6A |
| Entrega | cartões de cliente 2D | prato com o hot dog arrastado até a **janela**; destino = ticket fixado |
| Pedido | cartões de ticket 2D | cliente na janela (vista Window) pulsa; toque pega o pedido; ticket 2D mínimo |
| Nota | pips e selo 2D | mantém **pips e selo** (2D mínimo, permitido) + estouro 3D (estrelas, poeira) no objeto |
| Cursor | anel 2D no gamepad/toque | **marcador 3D** no ponto onde o raio toca o plano; ferramenta na mão |
| Servidor | `PrepGrill/Begin/Finish/Trash/Order` | **igual**, com três ajustes pequenos (§7) |

## 2. Arquitetura da interação 3D (cliente)

Tudo em `src/Prep/client/PrepController/World/` (pasta nova; um dono por arquivo). O `PrepController` ganha um gancho, ligado por `Prep.Rules.ThreeD` (§11).

```
Pointer (mouse/toque/gamepad, já existe) ─► World/Aim ──► Targets (registro, hover, press, drop) ─► Stage3D (Order/Grill/Bun/Build/Serve)
                                              │                                                       │
                                              ├─► World/Plane (raio→plano→uv do pão / da tábua)       ├─► Feed / Session (rede, notas)  [reuso]
                                              └─► Gestures (PlaneRegion)  ─► slice/place/trace/slide/taps/hold ─► Grade [reuso]
                                                                          Feedback: World/Fx (Highlight, anéis, partículas, ferramentas)
```

### 2.1 Do ponteiro ao alvo

- **Um raio por evento de movimento, no máximo um por frame.** `Pointer` já entrega Down/Move/Up em px. `World/Ray` converte para um raio da `CurrentCamera`. Atenção ao espaço: `InputObject.Position` de mouse e toque vem no espaço do GUI (com o inset do topo), então o par correto é `Camera:ScreenPointToRay`; o cursor virtual do gamepad (px na viewport) usa o mesmo caminho depois de somar o inset. É exatamente a pendência já aberta no registro do dia ("conferir o espaço de coordenadas do toque/cursor"); a TASK-196 fecha com `/dev prep ray` (imprime hit e uv por clique) em mouse, toque emulado e gamepad.
- **`RaycastParams` em modo `Include`** com **só** os hitboxes `PrepTarget` (CollectionService, listados uma vez no Enter, dezenas de partes). Decoração, pratos, NPCs e o rig nunca bloqueiam o raio e o raio custa quase nada. Hitbox = `Part` invisível (`Transparency 1`, `CanQuery true`, `CanCollide false`, `CanTouch false`, `Massless`), filho do objeto real (acompanha o `PivotTo` do trailer).
- **`ProximityPrompt` e `ClickDetector` NÃO**: o prompt não arrasta, o `ClickDetector` não é confiável com câmera `Scriptable` nem no toque e no gamepad. O único prompt do modo continua o `Prompt_Work` que entra na estação.
- **Tamanho do hitbox.** A 2,5 studs da câmera com FOV vertical 55, o quadro tem 2,6 studs de altura: em 667x375 isso dá **~144 px por stud** (844x390: ~150; 1280x720: ~277). Alvo mínimo de toque 44 px = **0,31 stud**. Regra: `hitbox = max(tamanho visual, 0,31 stud) x 1,3 se Assist`; a salsicha (0,24 de espessura, 1,0 de comprimento) ganha hitbox de 1,1 x 0,5. Provisório; a TASK-212 afina em Play.
- **Hover** (só mouse e cursor do gamepad): contorno no alvo sob o ponteiro; no toque não há hover, então o **alvo acionável pulsa sozinho** (o convite é o feedback).
- **Offset de toque** (28 px acima do dedo, `Rules.TouchOffset`) fica, para arrastos; o marcador 3D mostra exatamente o ponto que vale. Para toques discretos o alvo é o do ponto deslocado (o contorno já indica qual vai ser acionado antes de soltar). Validar em Play (risco R4).

### 2.2 Alvos (`PrepTarget`)

Contrato de autoria (level-designer, TASK-200): tag `PrepTarget` num hitbox filho do objeto real, atributos `TargetKind` e, quando couber, `Slot`/`Key`. O client monta o registro no Enter; se faltar hitbox, gera um fallback pela caixa do modelo (`Model:GetBoundingBox`) e avisa uma vez.

| `TargetKind` | Objeto real (existe?) | Atributos | Habilitado quando | Ação |
|---|---|---|---|---|
| `GrillSlot` | rolete `Att_Slot<i>` do roller grill (AST-012; sim) | `Slot` = i | vista Grill | alvo de soltar (Place) e de toque (Flip/Collect por estado) |
| `SausageStock` | caixa/estoque de salsicha (`sausage_stock`; sim) | — | estoque > 0 | fonte de arrasto, ou toque = Place no primeiro livre |
| `Rail` | trilho AST-013, `Slot1..8` (sim) | `Slot` | `Count` > 0 | fonte da salsicha da frente (Build); alvo de soltar da salsicha pronta (Collect) |
| `BunCrate` | caixa de pães AST-015 (sim) | — | estoque de pão > 0 e sem prato aberto | toque/arrasto = `PrepBegin` e o pão vai à tábua |
| `Board` | `Att_Bun<n>` da vaga do assento (sim) | `Slot` = assento | prato aberto | pose do pão e alvo de soltar do pão |
| `Knife` | faca AST-014 (deitada na tábua; sim) | — | seção Board, passo `bun` | ferramenta presa ao ponteiro |
| `Topping` | tigela da grade AST-017 (sim; molhos também em tigela, DEC-218) | `Key` (ketchup, mustard, ...) | seção Toppings, topping livre, sem bloqueio, estoque, prato < `MaxToppings` | pega a ferramenta do topping |
| `Bin` | lixeira (AST-025; sim, precisa estar no quadro: §4.3) | — | prato aberto | alvo de soltar do prato (descarta) |
| `Hatch` | balcão da janela de entrega (sim, sem hitbox) | — | prato pronto | alvo de soltar do prato (Serve) |
| `Customer` | cliente em `Q1` (rig do `NpcService`) | `NpcId` (lido do rig) | estado `Ordering` no balcão | toque = Take |

O registro (`Targets`) guarda por alvo: `Kind`, `Id`, `Parts`, `Enabled()`, `Highlight`, `OnHover/OnPress/OnDrop`. Cada estágio liga e desliga alvos; o resto é genérico.

### 2.3 Arrasto: plano, não pixel

Todo arrasto 3D é "o raio do ponteiro cortado por um plano":

- **Plano de trabalho** = o topo da bancada (Y da `Focus` da vista) mais a **altura de segurar** (`Rules.World.Lift`, 0,35 stud) quando se carrega algo; a ferramenta (faca, garrafa) segue o ponto e **inclina na direção do movimento** (suavizado, sem física).
- **`PlaneRegion`**: a mudança única em `Gestures/init.luau`. Hoje o reconhecedor normaliza px contra um `GuiObject` (0,0 a 1,1 na região). Passa a aceitar também uma região de plano `{ Inside(px), Normalise(px): Vector2, Aspect }`, onde `Normalise` faz raio, interseção com o plano do **topo do pão**, e converte para o espaço do pão (x ao longo do comprimento, y na largura, 0..1). Como `Content.Prep.Build` já está **no espaço do pão** (corte em y 0,5, vão em (0,5; 0,5), zigue-zague de 5 pontos, anéis do bacon, barra da batata), `slice`, `place`, `trace`, `slide`, `taps`, `hold`, `Score` e o `Spec` (89 casos) **não mudam**. `Aspect` = largura/altura do pão, para o `Length` do reconhecedor.
- **Ímã e assist**: o ímã de 20% do comprimento do pão (`Build.Magnet`) vira um **encaixe visual**: o objeto carregado desliza para o vão quando entra na zona. `Assist` = +30% de tolerância (`Rules.Assist`) **e** hitboxes x1,3 e guia sempre visível.

### 2.4 Vocabulário de feedback 3D

| Momento | Visual 3D | Som | Háptico (gamepad) |
|---|---|---|---|
| Alvo acionável (convite) | `Highlight` (fill Mustard 0,6 a 0,85 pulsando; contorno) ou anel de piso Neon (qualidade baixa) | tique suave no hover | — |
| Pegar | objeto sobe 0,35 stud, sombra circular no plano, marcador 3D vira anel fechado | "pick" | pulso curto |
| Soltar válido | encaixe com squash 0,9, 1,05, 1; faíscas x4 | "thunk" | pulso |
| Soltar inválido | volta ao lugar em arco curto + tremida 6 px de mundo | `error` | duplo pulso |
| Salsicha cozinhando | cor sobe de crua a pronta pelo **tempo do servidor**; vapor leve; o sizzle existente | `grill_sizzle` (já existe) | — |
| Janela de virar | **anel 3D converge** sobre a salsicha (escala 1,8 a 1,0 entre 40% e 60%, alvo em 50%); contorno Mustard; seta de virar | tique que acelera até o alvo | tique no gamepad |
| Virar | giro de 180 graus em 0,2 s com hop de 0,25 stud + puff x4; estouro de nota (estrelas Perfect, faíscas Good, poeira Messy) | "flip" + sizzle forte | pulso |
| Pronta | brilho Mustard + subida suave; contorno Green com marca de check ao lado (forma, não só cor) | `grill_ready` (já existe) | — |
| Coletar | salsicha salta ao próximo slot do trilho (arco de 0,22 s) | `grill_collect` (já existe) | — |
| Corte | linha de corte preenche (parte Neon que cresce), migalhas, faca afunda; ao fechar o pão troca `BunClosed` por `BunOpen` com hop | faca | — |
| Molho | gotas no bico; **segmentos** de molho no pão; pontos guia somem ao serem cobertos | esguicho com pitch pela vazão (já planejado: SFX de TASK-185) | contínuo fraco |
| Queijo, bacon, batata | fatia cai e dá squash; anéis do bacon encolhem sobre o pão; **monte** de batata cresce até o anel-alvo (o próprio monte é o medidor) | queda / tap / polvilhar | pulso |
| Estágio concluído | estouro 3D no pão; o pip 2D vira a forma da nota | sino / pop / boing baixo | pulso |
| Selo do prato | selo 2D (permitido) + chuva de partículas Cream/Mustard sobre o prato | acorde curto | pulso |

**Nunca só cor.** Forma e tamanho (anel que converge, marca de check, silhueta do selo), som e háptico carregam a informação (daltonismo). Nada de vermelho de alerta; o vermelho do ketchup é cor de comida.

### 2.5 Predição e reconciliação

O cliente **só prevê a apresentação**, nunca dinheiro, estoque, venda ou nota final.

| Ato | Previsão local | Verdade | Se o servidor recusar |
|---|---|---|---|
| `Place` na grelha | salsicha fantasma "assando" no slot do soltar | registro do slot em `Stations` | a salsicha sobe, treme e some; toast da razão (`NoStock`, `Full`) |
| `Flip` | giro começa já | `PrepResult Grill` com nota; `Stations.Flip` (§7) | giro volta; selo some (`Empty`, `Flipped`) |
| `Collect` | salto ao trilho já | `Stations`/`Rail` | volta ao rolete |
| `PrepBegin` (pão sai da caixa) | pão aparece na tábua | `PrepResult Begin` | pão vira poeira; toast (`NoStock`, `NotSelling`) |
| `PrepFinish` | só uma animação de "fechando" de 0,4 s | `PrepResult Finish` (nota, recusas) | prato volta ao estado anterior (`Parked`), como hoje |
| `Serve` | prato desliza à janela | `Sale` do `CustomerService` | volta à tábua |

A regra de ouro: **o que o set `Stations` e o `PrepResult` dizem sempre vence**; uma divergência se corrige em 0,15 s (snap com tween), sem travar.

### 2.6 Highlight, cursor virtual e ferramentas dinâmicas (rev. 2)

Referências do dono (`Assets/reference/prep-mode/`): `papas-hotdoggeria-condiments.jpg` (pão grande ao centro, concha derramando chili num fio contínuo, tigelas com colher nas laterais, garrafas embaixo, ticket à direita), `papas-hotdoggeria-grill.jpg` (grelha cheia de listras com salsichas, botões laterais), `roblox-peeling-3d-board.png` (objeto 3D grande sobre a tábua, ferramenta com brilho no ponto de contato, barra de progresso "Peeling 10%" no topo central, Leave embaixo no centro, dinheiro e hora livres no topo). Só estrutura de uso: nada de nome, arte ou layout idêntico (`CLAUDE.md`).

- **Highlight/outline no hover** (mouse), no **foco** do gamepad (X ou stick com atração) e no **alvo pulsante** do toque: `Highlight` (contorno + fill Mustard leve) no objeto clicável; é o equivalente 3D de um `ClickDetector` com `MouseHoverEnter`, mas por raio (§2.1). Um alvo em hover cresce 4% e sobe 0,05 stud.
- **Cursor virtual** (gamepad e toque): o marcador 3D no plano; a ferramenta e o marcador usam o mesmo ponto.
- **Ferramenta 3D que segue o cursor, com dinâmica** (mola amortecida, sem física): faca (desce e inclina na direção do corte), **concha** (`FoodPack/cooking-spoon.fbx`, para cream cheese e a pitada de batata), **garrafa que inclina e escorre** (o ângulo cresce com a vazão; o fio sai do bico; `Fill` baixa), fatia de queijo que balança ao ser levada, **salsicha que se arrasta** (inclina, projeta sombra e "pinga" vapor). Brilho no ponto de contato (como a ferramenta da referência do descascador): `PointLight` **não** (orçamento de luzes); material `Neon` mínimo + partícula.
- **Dinamismo do mundo:** o fio de molho cai em arco (partículas + segmentos), as gotas pingam, o pão afunda 0,03 stud sob a salsicha, a fumaça da grelha acompanha o que está assando.

## 3. Por estágio: o que o jogador vê e faz

### 3.0 Fluxo por seções em sequência (rev. 2)

O dono pediu navegação **só por seções em sequência**, tudo em 3D no mundo: **1 Grelha, 2 Tábua (pão + salsicha), 3 Toppings (garrafas, tigelas, queijo, bacon, batata), 4 Servir o cliente**. `Content.Prep.Tabs` passa a ter **quatro chaves: `Grill`, `Board`, `Toppings`, `Serve`** (a chave `Build` se divide em `Board` e `Toppings`; `Order` sai das abas). Isso muda os enums de `PrepTab.Step` e `PrepSeats.Step` (derivados de `Tabs.Keys`) e o atributo `PromptStep` do `Prompt_Work` da tábua (`Build` -> `Board`): contrato da TASK-194, ajuste de mapa na TASK-200.

| Seção | Vista | Objetos 3D (alvos) | Passos de `Content.Prep.Steps` | Libera o Next |
|---|---|---|---|---|
| 1 Grill | `Grill` | caixa de salsichas, 2 a 8 roletes, trilho | `grill` | sempre (a grelha cozinha em paralelo) |
| 2 Board | `Board` | caixa de pães, tábua, faca, trilho (pegar a salsicha) | `bun`, `place` (o antigo `build` perde os toppings) | pão cortado e salsicha no vão |
| 3 Toppings | `Toppings` | tigelas e ferramentas, queijo, bacon, batata, lixeira | `toppings` | sempre (0 a K toppings; "plain" é válido) |
| 4 Serve | `Window` | prato com o hot dog, balcão/janela, cliente | `serve` | prato servido |

- **Take Order** deixa de ser aba: o cliente em `Q1` pronto para pedir faz aparecer o **Take** no ticket 2D (esquerda) e, na vista `Window`, o cliente também é tocável (§3.1). Em jogo o prompt do mundo continua valendo antes de entrar (DT-6). Q-236.
- As abas são **livres** para voltar (a grelha cozinha enquanto se monta; o jogador volta a virar); o **Next** avança na ordem; o Serve só habilita com prato pronto.
- A nota vem das mesmas tolerâncias de `Content.Prep.Tolerances`; `Prep.Steps` ganha `Tab` e `View` por linha.

### 3.1 Order (sem aba: ticket + cliente na janela)

- **Vê:** a janela de serviço do trailer, de dentro. O cliente em `Q1` (estado `Ordering`) **pulsa** (contorno Mustard); os outros ficam normais, sem balão 3D de pedido.
- **Faz:** toque/clique/A no cliente = `PrepOrder Take` (`CustomerService:TakeOrderFor`, só aceita o de `Q1`). O ticket 2D desliza para o trilho de tickets (feedback) e o cliente reage com a animação que o mundo já usa. Fixar outro ticket = toque no ticket 2D (guia, vai em `PrepTab.Ticket`).
- **Fallback** (se a vista Window não couber, risco R6): o `Take` volta a ser o botão do ticket pendente (2D mínimo). O estágio funciona sem 3D na janela.
- **Sai do 2D:** `Stages/Order` (cartões, rolagem, anel de paciência por cartão). **Fica:** `TicketRail`.

### 3.2 Grill (vista Grill): a fatia vertical

- **Vê:** o roller grill com 2 a 8 roletes (nível do upgrade), o trilho e a caixa de salsichas. Cada rolete livre mostra uma **salsicha fantasma** (cópia de `SausageRaw`, Transparency 0,7, respiração lenta) só quando há estoque; sem estoque, a caixa fecha e o fantasma some.
- **Põe:** toque na caixa (vai ao primeiro livre) **ou** arrasto da caixa ao rolete desejado (`PrepGrill Place`, **Slot preferido**, §7).
- **Cozinha:** a cor sobe de crua a pronta com `progresso = (GetServerTimeNow() - StartedAt) / Duration` do registro do slot (o mesmo número do servidor, sem rede nova): cross-fade entre `Sausage_Raw` e `Sausage_Grilled` (ou tint, decide o spike S1), vapor e o sizzle atuais. Sem queimar (Q-222).
- **Vira:** entre 40% e 60% da `Duration` (`Rules.Grill`) a salsicha ganha o **anel que converge** (alvo em 50%) e o contorno; tocar = `PrepGrill Flip` (o servidor carimba o relógio dele e devolve a nota); antes da janela o toque só faz um tremor leve e **não envia nada**; depois da janela vira "tarde" (anel pequeno e opaco, ainda vale). Virada: giro de 180 graus, marcas de grelha no lado de cima (a malha `Sausage_Grilled` já tem as marcas no UV), estouro da nota.
- **Coleta:** pronta (progresso 1 ou `Ready`) = brilho e contorno com marca de check; toque ou arrasto ao trilho = `PrepGrill Collect`; a salsicha salta ao trilho real (`Rail`), que já mostra `Count`.
- **Falhas:** sem estoque = caixa balança + toast "Out of sausages"; grelha cheia = toast; trilho cheio = a salsicha pronta balança e fica.
- **Mede/Envia:** `grill_flip` (taps, a distância a 50% da `Duration` é calculada no servidor por `Grade.FlipScore`). Pacotes: `PrepGrill {Place|Flip|Collect, Slot}` (já existem).
- **Sai do 2D:** `Stages/Grill` (células, barra, selo mini por célula), chip "Rail empty", "Add +". **Fica:** o badge de prontas na aba.

### 3.3 Seção Board, parte 1: cortar o pão (vista Board)

- **Vê:** a tábua do assento (`Att_Bun n`), a caixa de pães e a faca.
- **Faz:** toque/arrasto na caixa de pães = `PrepBegin` (reserva pão e vaga); o pão **fechado** (`BunClosed`) pousa na tábua. A faca vira ferramenta presa ao ponteiro; **arrastar a faca ao longo da guia 3D** (linha tracejada, `Beam` ou dois `Part` Neon) da esquerda para a direita, `slice` normalizado no espaço do pão, cobertura de 94% (`Build.Cut.Done`) fecha o corte.
- **Resultado:** `BunClosed` troca por `BunOpen` com hop, migalhas, pip "Cut" vira a forma da nota. Modo "segurar" (acessibilidade): manter a faca sobre a linha 1 s corta sozinho (`Build.Cut.Hold`).
- **Mede:** `bun_cut` (desvio médio da guia, % da largura do pão). **Sai do 2D:** `PlateView`, `Overlay` (faca 2D), `Parts.Plate`.

### 3.4 Seção Board, parte 2 (salsicha no pão) e Seção Toppings (vista Toppings, mais larga)

- **Toppings são 3D, sempre** (rev. 2): as tigelas, a garrafa na mão, a fatia, as tiras de bacon e a pitada de batata são objetos do mundo; a barra 2D de condimentos do §5 é só atalho opcional.
- **Vê:** o pão aberto, o trilho com as salsichas prontas, a grade de tigelas (6; na referência, flanqueando o pão), a lixeira.
- **Salsicha (seção Board):** arrastar a da **frente do trilho** até o vão do pão (alvo fantasma no vão, encaixe por ímã de 20%); o rolete do trilho fica oculto localmente (`LocalTransparencyModifier`) enquanto ela está na mão; soltar fora devolve. Mede `sausage_place`.
- **Toppings** (ordem livre, até 3, sem repetir; uma ferramenta por vez):

| Topping | Ferramenta na mão | Gesto | O que se vê no pão | Medida (`Tolerances`) |
|---|---|---|---|---|
| ketchup, mustard, cream_cheese | garrafa (AST-004/005; creme = variante branca) | `trace`: traçar o zigue-zague guia | segmentos de molho (cilindros baixos, pool) e **pontinhos guia** que somem quando cobertos; o nível `Fill` da garrafa desce com a vazão | cobertura e excesso, `Grade.CoverageError` |
| cheese | fatia (`Cheese_Slice`) | `slide`: soltar sobre o alvo | a fatia cai com squash no vão | desvio % |
| bacon | tira (`Bacon_Pile`) | `taps`: 3 anéis encolhem sobre o pão, tocar quando fecham | uma tira por toque | erro médio em ms |
| potato_sticks | lata/tigela (pitada) | `hold`: segurar e soltar na faixa | o **monte** cresce; soltar quando toca o anel-alvo (70%) | % da barra |

- **Next** fecha o pão (`BunOpen` volta a envolver, 0,4 s) e manda o **resumo** `PrepFinish` (inalterado); o selo do prato aparece (2D) com estouro 3D sobre o prato; o prato fica pronto na vista Window.
- **Lixeira:** arrastar o prato (ou o pão) até a lixeira real = `PrepTrash`; a alternativa sem arrasto é o botão 2D "Trash" só se a lixeira não couber no quadro (§4.3).
- **Sai do 2D:** `IngredientPanel`, `StrokeCanvas` (traço e medidor), pílula Hold dentro do tabuleiro, fantasma do queijo, anéis do bacon em Frame, `Rail` chip.

### 3.5 Serve (vista Window)

- **Vê:** o prato com o hot dog pronto no balcão da janela e o selo da nota; o cliente do ticket fixado fora da janela quando visível.
- **Faz:** **arrastar o prato até a janela** (ou tocar o prato com o ticket certo fixado) = `PrepOrder Serve` com o `Npc` do ticket fixado (a escolha de quem recebe continua sendo o ticket, `Feed.Pinned`). O servidor decide Completo/Incompleto/Errado (DEC-072, `CustomerService:ServeFor`); o veredito chega no `Sale` e vira estouro 3D na janela e carimbo no ticket 2D (círculo+check, meio círculo, quadrado+X; sem vermelho).
- **Variante B (depois, Q-228):** tocar o próprio cliente na janela para escolher quem recebe (exige o cliente visível da vista Window).
- **Sai do 2D:** `Stages/Serve` (cartões de cliente), `Cards`. **Fica:** `TicketRail` e o selo.

## 4. Câmera, vistas e amarração com o mapa

### 4.1 Vistas

Hoje há duas vistas por estação: **Grill** (Order e Grill; `CamAnchor`/`Focus`) e **Build** (Build e Serve; `CamAnchor_Build`/`Focus_Build`), escolhidas por `Poses.ViewOf(tab)`. **Rev. 2 (dono): a navegação é só por SEÇÕES em sequência** (§3.0) e cada seção tem a **sua vista** (`Content.Prep.Views`, TASK-194), com a mesma regra de nome e cadeia de reserva:

| Vista = seção | Âncoras (por `Station_n`) | Enquadra | Reserva |
|---|---|---|---|
| `Grill` (1) | `CamAnchor`, `Focus` (existem) | roletes 1..8, caixa de salsichas, trilho | — |
| `Board` (2) | `CamAnchor_Board`, `Focus_Board` (novos; hoje `_Build` serve) | tábua do assento, caixa de pães, faca, trilho (para pegar a salsicha) | `Build` |
| `Toppings` (3) | `CamAnchor_Toppings`, `Focus_Toppings` (novos; **mais larga**, `Fov` por âncora) | o pão aberto **com a salsicha** no centro e as tigelas/queijo/bacon/batata **dos dois lados** (como na referência `papas-hotdoggeria-condiments.jpg`), lixeira | `Board` |
| `Window` (4, Serve) | `CamAnchor_Window`, `Focus_Window` (novos) | janela de serviço, balcão do prato, cliente em `Q1` | `Board` |

Cada âncora pode trazer o atributo `Fov` (padrão `Rules.Camera.Fov` 55). A câmera desliza entre vistas em `Rules.Camera.Travel` (0,35 s; corte com movimento reduzido). **A mudança de vista é o único "movimento de câmera"**: nada de câmera livre em V1 (Q-232).

### 4.2 Estações, prompts e assentos

- 4 `Station_n` lógicas (`PrepSeats`), mas só **2 prompts Work no mundo**: `Station_1/Prompt_Work` na **grelha** (`PromptStep = Grill`) e `Station_3/Prompt_Work` na **tábua** (`PromptStep = Build`; passa a `Board` quando a chave da seção mudar, §3.0) (`tools/assetplace/stations_prep.luau`, V2 do level-designer; `PrepService:StepOfAnchor` lê o atributo). Quem usa qualquer um ocupa o próximo assento livre e **abre na vista do passo** do prompt. Nada muda aqui para o 3D-first: o jogador entra já olhando para o objeto que apertou.
- O assento `n` só tem **um alvo de tábua**: o `Att_Bun n`. Os outros assentos são **marionetes** (§10), não alvos (o raio só inclui os alvos do assento próprio).
- A tábua do trailer tem 4 vagas a 0,8 stud, e o pão tem 1,0: **os pães se encostam por 0,2** (`MAP-01.md` §19). Em 3D, com faca e mão por cima, isso é apertado. Pedido ao level-designer: espaçamento ≥ 1,1 (trocar a malha para uma tábua maior ou escalonar em duas fileiras). Spike S3.

### 4.3 Enquadramento (aceite de mapa)

Para cada vista, em **667x375** e 844x390: todos os alvos do estágio visíveis com hitbox ≥ 44 px, nenhuma sobreposição de alvos, a lixeira e a janela no quadro nas vistas em que são alvo. Conta de partida: quadro 2,6 x 4,6 studs em 16:9 (§2.1); a vista `Toppings` precisa de ~4,5 studs de largura útil para 6 tigelas dos dois lados + pão: se não couber a FOV 55, a âncora leva `Fov` 62 a 65 (as seções já são vistas separadas, não há mais subdivisão por passo). Medido por captura (checklist da TASK-200).

### 4.4 Rig, NPCs, DOF e luz

- `Rig.luau` (rig próprio escondido, NPCs cortados/fantasma) continua; exceção: na vista `Window`, o cliente em `Q1` **não é cortado** (é o alvo do Take). Pergunta ao dono: isso conta como "ver" anomalia (Q-228)?
- DOF e vinheta (`Rules.Camera`, qualidade > 3 ou vinheta) continuam; com objetos 3D no primeiro plano, `NearIntensity = 0` e `FocusDistance` na bancada (já é assim). Sem luz nova (o orçamento de luzes do trailer está em 17/18): o "foco de luz" à noite é material `Neon`/emissivo nas bordas dos alvos, não uma luz local.

## 5. HUD mínimo (o que fica em 2D) e layouts

**Rev. 2 (revisão do dono, 2026-10-12):** (1) as **abas/seções vão para BAIXO**, na faixa logo acima de onde ficaria a hotbar/barra de ferramentas (a hotbar nativa continua escondida em foco, mas a faixa é a mesma); no topo elas eram cobertas pelo ícone/menu do Roblox e cobriam relógio e dinheiro; (2) **o topo esquerdo e o topo direito ficam LIVRES e visíveis**: a sanidade compacta (esquerda) e o status de dinheiro/relógio (direita) **não somem** em foco (`Isolate` deixa de esconder o `Hud`; só o cartão do pedido `HudOrder` sai, porque o ticket o substitui); (3) um **indicador de progresso fino no topo, centrado**, no estilo da referência `roblox-peeling-3d-board.png` ("Peeling 10%" com barra): aqui "Cutting 40%", "Sauce 2/3"; (4) **ticket do pedido à esquerda**; (5) uma **barra de condimentos 2D opcional à direita**, só como atalho (Q-237), nunca como o jeito principal de pôr topping, que é 3D.

Persistentes, e **só** estes:

1. **Progresso (topo, centro)**: cartão com o verbo da seção atual + barra de 10 px com 4 divisões (Grill, Board, Toppings, Serve) e os 3 pips de nota (Cut, Place, Top) à direita do cartão. Progresso do **prato**: Grill = salsicha pronta no trilho, Board = corte + encaixe, Toppings = toppings feitos / K, Serve = entregue (Provisório).
2. **Ticket** (esquerda, abaixo da sanidade): `TicketRail`, o ticket fixado e o "+N"; e o **Take** do cliente em `Q1` (a seção Order sai das abas, §3.0).
3. **Barra de seções (embaixo, centro)**: 4 abas Grill, Board, Toppings, Serve, com badges (Grill = prontas, Serve = prato). Livres para voltar (a grelha cozinha em paralelo); o **Next** avança na sequência (Q-236).
4. **Next / Serve** (embaixo à direita) e **Leave** (embaixo à esquerda; mesmo papel do "LEAVE X" da referência, em Mustard/Ink, **sem vermelho**).
5. **Selo do prato** (2D, transitório), **dica** de uma linha (acima da barra de seções) e **toast** (um por vez).
6. **Assist** e **Tap mode** (dois chips de 44 px ao lado do Leave), com glifos no gamepad.
7. Opcional (Q-237): **barra de condimentos** à direita, 6 atalhos que **apenas pegam a ferramenta** daquele topping (o resto é 3D).

Já existem e **ficam livres para o jogador ver**: sanidade (topo esquerdo), dinheiro e relógio (topo direito), nada nosso no topo além do cartão central de progresso.

**Saem de tela:** `PlateView`, `IngredientPanel` como painel principal, `StrokeCanvas`, trilho/células da grelha, cartões de Order e Serve, lixeira 2D (exceto o fallback do §3.4), cursor 2D (vira marcador 3D), barra de abas e Leave do topo. Texto >= 14 px, alvos >= 44 px, sem vermelho, nada centralizado em 1ª pessoa (mantidos do spec). O centro da tela fica **livre**: é o jogo.

Layouts (px de UI, origem no canto superior esquerdo, `i` = `DeviceSafeInsets`; o escalonamento é o `Theme.ScaleOf`):

| Elemento | 667x375 (mínimo) | 844x390 | Desktop 1280x720 (canvas ~1371x771) |
|---|---|---|---|
| Progresso (topo centro) | (200, 8) 267x40: rótulo 14 px + barra 10 px + pips | (290, 8) 264x40 | (545, 12) 280x44 |
| Status (Hud existente) | topo direito, `right 12+i`, y 10, 148x32 (começa em 507: não toca o progresso, que termina em 467) | igual | right 16, y 14 |
| Sanidade (Hud existente) | topo esquerdo sob o menu do Roblox (y ~52 a 90, só à noite) | igual | igual |
| Ticket | (12+i, 100) 136x120 (abaixo da sanidade) | (12+i, 100) 152x140 | (16, 130) 184x152 |
| Condimentos (opcional) | (563, 56) 92x140: 2 colunas x 3 linhas de 44, vão 4 (não toca o status, que termina em y 42, nem o Next, que começa em y 311) | (700, 60) | (1204, 84) 168x... |
| Leave | (12+i, 319) 44x44 | igual | (16, 700) 96x48 com texto |
| Assist / Tap mode | (60+i, 319) e (108+i, 319), 44x44 (terminam em x 152) | igual | (120, 700) e (172, 700) |
| **Seções (abas) embaixo** | 4 de 84x44, vão 4, **centradas**: x 160 a 508, y 319 (termina em y 363 = base - 12) | 4 de 104x44, vão 6, centradas, y 334 | 4 de 128x48, vão 8, centradas, y 700 |
| Next / Serve | (527, 311) 128x52, right 12+i, bottom 12 (as abas terminam em x 508: vão de 19) | (700, 326) 132x52 | (1204, 696) 152x56 |
| Dica | (168, 281) 332x32, 1 linha <= 36 caracteres, sobre superfície Cream, logo acima das abas | igual | y 664 |
| Toast | (168, 243), 1 por vez (substitui a dica por 2,2 s se faltar espaço) | igual | y 626 |
| Selo do prato | 96, canto direito do campo (x 440, y 110), só ao fechar o prato, <= 1,2 s, nunca sobre o gesto em curso | igual | 120 |

Sem sobreposição (667x375, conferido): Leave 12..56, Assist 60..104, Tap 108..152, abas 160..508, Next 527..655; progresso 200..467 x 8..48 contra status 507..655 x 10..42 e menu do Roblox (<= 110); ticket 12..148 x 100..220 contra condimentos 563..655 x 56..196; dica y 281..313 contra abas y 319. Zonas livres (nunca ocupadas): o retângulo central (x 168 a 520, y 56 a 275 em 667x375) é só mundo; a base de gestos (`DeviceSafeInsets`) segue o `prep-ui-spec` §3.2. **Gamepad:** os mesmos blocos; glifos nos botões (Y = Next, B = Leave, LB/RB = seções, D-pad = ticket, **X = próximo alvo**, A = pegar/soltar); o foco visual segue o alvo 3D e o chip 2D em foco. Sem controles de toque do Roblox, hotbar, chat e `PlayerList` em foco (já feito em `Isolate`; o `Hud` passa a ficar visível).

## 6. Modelos 3D, VFX e o que falta

Prioridade: **usar o que existe** (`Assets/FoodPack`, `Assets/KitchenPack`, `Assets/models/**`) antes de modelar (`CLAUDE.md`). Os 3 estados da salsicha e do pão saem do que já existe; o resto são ferramentas e VFX simples.

| Necessidade | Existe? | Onde | Falta |
|---|---|---|---|
| Salsicha crua / pronta | **Sim** | `Assets/models/food/AST-002_Sausage.fbx` (`Sausage_Raw` 92 / `Sausage_Grilled` 164) | — |
| Salsicha "meia" | Não | — | opcional: `Sausage_Half` (crossfade resolve sem modelo; spike S1 decide) |
| Salsicha fantasma | Não (é o `Sausage_Raw` com material fantasma) | — | só material/código |
| Pão fechado / aberto | **Sim** | `AST-001_Bun.fbx` (`Bun_Closed` 128 / `Bun_Open` 152); mordido AST-061 | — |
| Pão "cortado" (animação de abrir) | Não (malhas não deformam) | — | resolvido com guia + migalhas + troca `Closed -> Open` com hop; modelo extra só se o dono achar seco (metades separadas, opcional) |
| Hot dog montado / prato | **Sim** (hot dog), prato sim | `AST-003_HotDog.fbx`; prato `KitchenPack/plate.fbx` / `FoodPack/plate.fbx` | recolor Cream; AST-088 já usa `plate.fbx` |
| Garrafa ketchup / mostarda (ferramenta) | **Sim** | `AST-004_KetchupBottle`, `AST-005_MustardBottle` (translúcidas com `Fill`; edição em andamento) | confirmar `Fill` animável; pivô do bico |
| Cream cheese (ferramenta) | Parcial (pote AST-009) | `AST-009_CreamCheese.fbx` (`CreamCheese_Jar`) | variante **garrafa branca** (recolor do AST-004) |
| Queijo (fatia) | **Sim** | `AST-006_Cheese.fbx` (`Cheese_Slice`, `Cheese_Topping`) | — |
| Bacon | **Sim** | `AST-007_Bacon.fbx` (`Bacon_Pile`, `Bacon_Topping`) | — |
| Batata palha | **Sim** | `AST-008_PotatoSticks.fbx` (`Pile` 344, `Topping` 240) | monte escalável (pivô na base) |
| Tigelas dos toppings | **Sim** | AST-017 tigelas (`Fill_<Suf>`, `Label_<Suf>`, `Lid`, `Lock`) | hitbox por tigela |
| Tábua e faca | **Sim** | `AST-014_CuttingBoard.fbx` (tábua 38 + faca 104, deitada) | **faca separável** como ferramenta (peça própria com pivô na lâmina) |
| Espátula (cursor da grelha) | Parcial | `FoodPack/cooking-spatula.fbx` | recolor Mustard/Ink, pivô na ponta (ficha nova) |
| Caixa de pães, trilho, grelha, lixeira | **Sim** | AST-015, AST-013, AST-012, AST-025 | hitbox; trilho de 8 vagas |
| Anel de virar (VFX) | Não | — | `Ring` disco fino Neon (2 espessuras: Good, Perfect); pode ser `Part` cilíndrico sem malha |
| Seta de virar, guia de corte, pontos guia | Não | — | `Part`/`Beam` simples; seta opcional (ficha) |
| Marcador 3D do ponteiro | Não | — | disco/anel de 0,12 stud, 2 estados; sem malha |
| Sombra circular | Não | — | `Decal`/disco achatado |
| Segmento de molho | Não | — | cilindro baixo (uma `Part`, sem malha), pool de 80 |
| Fumaça, faíscas, migalhas, gotas | **Sim** | `KitchenController/Fx.luau` (`Ready`, `Drops`, `Dust`, `Confetti`; teto de 150 partículas e 8 emissores) | presets `Crumbs` e `Sparkle` pequenos |

Fichas e ids: **AST-120 em diante** (livres; o art-director confirma no `asset-list.md`, TASK-201). Os sprites 2D AST-108 a AST-119 ficam **parcialmente superados**: seguem úteis só para ticket, selos, pips, abas, ícones de ingrediente do ticket e glifos (AST-108, 112, 113, 117, 118, 119); AST-109, 110, 111, 116 e o cursor AST-114 perdem a razão de existir (o mundo é a arte). Nada disso bloqueia o código: o jogo roda inteiro com `Part`/Neon placeholders.

## 6A. Animação com os assets reais: swap de MeshPart/textura x EditableMesh (rev. 2)

O dono quer os **assets reais** (salsicha, pão, molhos, queijo, bacon, batata de `Assets/models/food/`) com **animação de verdade** (troca de textura/cor; `EditableMesh` onde fizer sentido). Fatos conferidos na documentação da Roblox (`EditableMesh`, consultada em 2026-10-12; **nada abaixo foi medido no nosso jogo**):

- **Desligado por padrão em experiências publicadas**: exige ligar "Allow Mesh / Image APIs" (Experience Settings > Security, ou Creator Dashboard > Settings) e rever os Termos de Uso: é uma chave **do dono** (Q-235).
- Limites por malha: **60.000 vértices e 20.000 triângulos** (nossas malhas têm 66 a 344 tris). **Memória do cliente com orçamento estrito**, sem número publicado ("editable assets are currently expensive"); um relato de fórum fala de estouro com 8 malhas (anedota, não confirmada).
- `CreateEditableMeshAsync` (a partir do `MeshId` de um asset nosso) só funciona se o dono do jogo, ou o jogador logado, for dono do asset ou tiver acesso: **precisa testar com uma segunda conta** (risco de permissão no cliente de quem não é o dono). Malha vinda de asset é **FixedSize** (move vértices e atributos, não cria nem apaga); `CreateEditableMesh()` em branco é livre (cria do zero).
- `ApplyMesh` mostra o resultado na hora; colisão não atualiza (não precisamos: `CanCollide false`).
- A documentação não descreve replicação; como toda a nossa animação é **local**, não depende disso.

| Efeito | Asset real | A) Swap / cor / textura (MeshPart) | B) EditableMesh | Recomendação |
|---|---|---|---|---|
| Cozimento da salsicha | `Sausage_Raw`/`Sausage_Grilled` (AST-002) | cross-fade das duas malhas (Transparency), ou tint `Color`, ou troca de `TextureID` entre 3 texturas pré-assadas (crua, a meio, pronta); 10 Hz | pintar marcas numa `EditableImage` (mesma chave "Mesh / Image") | **A**; B só como brilho extra depois |
| Virar | idem | giro 180 graus por tween; troca o lado das marcas | não precisa | **A** |
| **Cortar o pão** | `Bun_Closed`/`Bun_Open` (AST-001) | `BunClosed` troca por `BunOpen` com hop, migalhas e linha de corte que cresce (**não abre aos poucos**) | **morph**: um par `Bun_Morph` (fechado e aberto com a **mesma topologia**, ~150 vértices) carregado FixedSize; a cada amostra da faca os vértices fazem `lerp` com máscara por x (abre **atrás da faca**, de verdade) | **B como camada** (maior ganho), com A como padrão |
| Salsicha encaixa / amassa | `Sausage_Grilled` | squash por escala e `CFrame` | deformar vértices | **A** |
| **Molho escorrendo** | `*_Topping` (66 a 126 tris) são fios prontos, não traçáveis | cilindros baixos em `Part` (<= 24 por traço) + gotas; instâncias demais, aparência "de Lego" | **tubo extrudado** gerado do zero (`CreateEditableMesh()` em branco, ~6 lados x 24 anéis = ~300 tris, 1 malha por traço, cresce com o ponteiro, afina e pinga) | **B como camada** (segundo ganho), A como padrão |
| Queijo, bacon, batata | AST-006/007/008 | modelos posados; monte da batata por escala | — | **A** |

Custo e risco (ordem de grandeza, a medir no spike): A = **zero permissão, zero orçamento de EditableMesh**, funciona em qualquer dispositivo, 0 dia extra. B-pão = 0,5 dia do modeler (par morph com a mesma topologia) + 1 a 2 dias de código; B-molho = 2 a 3 dias; ambos com `pcall` e queda automática para A. Cada malha editável pesa pouco em bytes (~5 a 10 KB), mas o **orçamento é por contagem/overhead**, não por bytes: é o que o spike mede.

**Recomendação:** entregar **A de ponta a ponta primeiro** (fatia Grill e as seções Board e Toppings jogáveis); EditableMesh entra como **camada opcional** atrás de `Rules.World.Editable` (nasce `false`), só para o **corte do pão (morph)** e o **tubo de molho**, **depois** de um spike que passe (**S1b, TASK-216**): (a) `CreateEditableMeshAsync` funciona para uma **segunda conta** no jogo publicado; (b) 6 malhas por cliente (1 pão + 3 molhos + 2 marionetes) dentro do orçamento, medido em `Stats`; (c) custo do `lerp` de ~150 vértices em 0,8 s < 0,3 ms por frame; (d) o que renderiza (cor de vértice, textura) em celular. Se falhar qualquer item, fica A e nada se perde. O **dono liga "Allow Mesh / Image APIs"** (Q-235) antes do spike.

## 7. Replicação, autoridade e rede

Princípio: **o cliente desenha o cozimento e o ponto da salsicha pelo tempo do servidor; o servidor segue autoritativo** (`PrepGrill`, `PrepFinish`, `PrepResult`, `Stations`). Nenhum `Heartbeat` de rede, nenhum pacote por frame.

### 7.1 O que já basta

- `Stations` (replicate) já carrega por slot `State`, `StartedAt` (f64, hora do servidor), `Duration`, `Count`, `Altered`. O cliente calcula `progresso = (workspace:GetServerTimeNow() - StartedAt) / Duration` localmente (já é o que `Feed.applyGrill` e `Slots.Progress` fazem, a 15 Hz). Dois clientes concordam dentro da diferença de relógio (dezenas de ms).
- Carimbo do virar é no relógio do **servidor** quando o pacote chega: com 100 ms de ida e volta o viés é ~50 ms; numa `Duration` de 8 s e Perfect de +-5% (+-0,4 s), isso é ~1%. Sem compensação por ora; se o p90 de ping mostrar viés (TASK-212/214), um campo `At` opcional em `PrepGrill` resolve. **Sem predição de nota**: a nota é a que o servidor devolve.

### 7.2 Ajustes pequenos (nenhum pacote novo)

| # | Mudança | Onde | Por quê | Custo |
|---|---|---|---|---|
| N1 | `PrepGrill.Place` honra `Slot` 1..8 como **preferência** (livre = usa; ocupado = o primeiro livre; `Slot 0` = como hoje) | `PrepService`/`Bridge`, `KitchenService` `Grill.PlaceFor` | o soltar da salsicha no rolete escolhido tem de bater com o registro, senão a predição pula | 0 byte (o campo já existe, `Slot` 0 a 8) |
| N2 | `Stations.Flip = Lync.optional(Lync.int(0, 101))` (0/nil = não virada, n = nota + 1); escrito no `Flip`, zerado no `Collect`/`Place` | `Net/init.luau`, `Grill.luau` | fecha a lacuna do registro do dia ("o flip já feito não vem na rede"): quem entra tarde e **os colegas** veem a salsicha virada; o selo sobrevive ao reentrar | 1 byte opcional por slot, 1 escrita por virada; o set já tem mais de 8 registros e o campo cabe em 7 bits (`drop.section` não se aplica) |
| N3 | `PrepTab.Plate = Lync.int(0, 255)` e `PrepSeats.Plate = Lync.int(0, 255)`: **máscara cosmética do prato**: bit 0 cortado, bit 1 salsicha posta, bits 2 a 7 os 6 toppings na ordem de `Ingredients.ToppingKeys` | `Net/init.luau`, `PrepService` (valida: só cresce, <= `MaxToppings` bits de topping, zera ao Begin/Finish/Trash), `Validate` exige `#ToppingKeys <= 6` | os colegas veem o prato de quem trabalha ao lado (marionete, §10) sem canal novo; **não é autoridade** (o `PrepFinish` revalida tudo) | `PrepTab` já voa a 4/s no máximo e só quando algo muda; `PrepSeats` <= 4 registros, escrita ~1/s no total |

`network.md` ganha a seção "Preparo 3D" na TASK-194. **Opcional (Q-233)**: `PrepHand` (c->s, 5 Hz, `{Target: int(0,31), U: int(0,255), V: int(0,255)}` ~4 bytes) + retransmissão para os colegas do mesmo trailer = a "mão fantasma". Estimativa: 4 jogadores x 5 Hz x ~6 bytes = ~120 B/s no servidor, trivial, mas **só** se o dono quiser; fica atrás de `Rules.World.GhostHand` (false).

### 7.3 O que NÃO vira rede

Posição do ponteiro, hover, ferramenta na mão, anéis, partículas, segmentos de molho, nota por gesto (só o resumo), animações. Tudo é apresentação local.

## 8. Performance (orçamento por jogador, no cliente)

| Recurso | Orçamento | Observação |
|---|---|---|
| Hitboxes `PrepTarget` | <= 40 partes (grelha 8, caixa 1, trilho 8, pães 1, tábua 1, faca 1, tigelas 6, lixeira 1, janela 1, cliente 1) | criadas no Enter e destruídas no Leave; `CanQuery` só |
| Raios | **<= 1 por frame**, só quando o ponteiro mexe ou durante arrasto | `Include` sobre o conjunto de alvos; sem raio em parado |
| `Highlight` | <= 12 vivos (limite do motor: 31) | só nos alvos acionáveis e no hover; **qualidade <= 3: nenhum**, anel de piso Neon no lugar |
| Anéis/discos Neon | pool de 10 (8 salsichas + hover + marcador) | escala/transparência por frame só dos que estão na janela de virar |
| Segmentos de molho | <= 24 por traço, <= 72 por prato, pool de 80 `Part` | simplificação do traço (descarta amostras a < 0,08 stud) |
| Modelos clonados | 1 ferramenta, 1 prato local, <= 3 fantasmas, <= 8 salsichas do mundo adotadas (sem duplicar: `KitchenController` expõe `FoodAt(kind, slot)`) | malhas já carregadas pelo mundo |
| Partículas | **dentro do teto atual de `Fx`** (150 vivas, 8 emissores perto da câmera); qualidade <= 3 pula rajadas | presets novos pequenos (<= 10) |
| Tweens | <= 6 simultâneos, todos por um único `RenderStepped` ligado só no foco | sem `TweenService` por objeto; zero alocação por frame no caminho quente |
| Atualização de cor do cozimento | 10 Hz | não por frame |
| `ViewportFrame`, `SurfaceGui` por alvo, `BillboardGui` por alvo | **nenhum** | |
| `EditableMesh` (opcional, `Rules.World.Editable`) | <= 6 por cliente (1 pão + <= 3 tubos de molho + <= 2 marionetes), todas destruídas no Leave | medido no spike S1b (TASK-216); `pcall` e queda para swap; nunca no caminho crítico |
| Memória | sem aumento após 20 entradas e saídas | pools destruídos no Leave |
| Rede | <= 1 pacote/s por jogador em média e <= 6/s no pico (`Rates`); `PrepSeats` <= 4 | acréscimo do 3D: 0 pacote novo (N1 a N3 usam os existentes) |

Meta de quadros: >= 30 fps no foco no celular fraco (TASK-193/214); se faltar, o corte é, nesta ordem: qualidade <= 3 liga o fallback sem `Highlight` e sem rajadas, o hover do gamepad vira por quadro alternado, o vapor some.

## 9. Acessibilidade

- **Alvo grande:** hitbox >= 44 px e x1,3 com Assist; o alvo certo **pulsa** sozinho (sem depender de hover); ímã de encaixe visual.
- **Assist** (obrigatório na fase 1, DEC-223): +30% de tolerância (`Rules.Assist`), hitboxes x1,3, **guia sempre visível** (corte, pontos do molho, anel-alvo da batata), ímã maior. A virada continua pelo relógio do servidor; o Assist só amplia o anel visual e liga o tique sonoro desde o início da janela.
- **Tap mode ("tocar e tocar")**: no lugar de arrastar: toque no objeto (pega, ele "gruda" no marcador), toque no destino (solta). Cobre toque, gamepad e quem não arrasta bem; também é o modo "segurar" já existente nas medidas (`HoldPlace`, `Cut.Hold`, `Sauce.Fill`).
- **Gamepad:** stick esquerdo move o marcador com **atração** a alvos a < 80 px; **A** pega e solta; **X** salta ao próximo alvo acionável (na ordem do estágio); D-pad = ticket; LB/RB = abas; Y = Next; B = Leave. Teclado e mouse como já estão; setas movem o marcador como alternativa (TASK-207).
- **Vibração:** `HapticService` no gamepad quando houver motor; no celular só se a plataforma expuser (sem promessa). **Som** de cada ato e **forma** (anel que converge, marca de check, silhueta do selo) no lugar de cor; todo som tem equivalente visual.
- **Movimento reduzido:** câmera por corte, sem pulso (contorno fixo), sem giro (a salsicha troca de lado com fade 120 ms), sem rajada (brilho estático). **Daltonismo:** nada só por matiz; Mustard x Cream separados por contorno Ink e por forma.

## 10. Co-op (1 a 4 assentos)

- **Posição e alvos:** cada jogador só enxerga e aciona os alvos do **próprio assento** (a tábua `Att_Bun n`); a grelha, o trilho e o estoque são **compartilhados** e o servidor decide quem leva: duas pessoas que tocam a mesma salsicha no mesmo instante, o primeiro `Place`/`Flip`/`Collect` vence e o segundo recebe `Reason` (a predição dele desfaz com tremida).
- **Marionete do colega (barato):** o prato de quem trabalha ao lado aparece **na tábua dele** pela máscara `Plate` (N3): pão fechado/aberto, salsicha, toppings como modelos prontos (sem segmentos de molho: o topping molho vira o modelo `*_Topping`). Sem física, sem rede por frame. A etiqueta `StationTag` (nome e aba, de `PrepSeats`) continua.
- **Mão fantasma (opcional, Q-233):** contorno Teal fino da ferramenta do colega, 5 Hz interpolado; desligada por padrão.
- **Salsicha virada pelo colega:** todos veem (N2).
- **Entrada tardia:** o estado vem de `Stations` e `PrepSeats` (sem estado perdido, ao contrário do selo da virada hoje).

## 11. O que do código atual aproveita e o que sai; migração e flag

### 11.1 Aproveita (sem reescrever)

| Peça | Papel no 3D-first |
|---|---|
| `Grade`, `Content.Prep` (`Tolerances`, `Grades`, `Rules`, `Gestures`, `Build`), `/dev prep grade` | **intactos**; a nota segue sendo calculada só em `Grade` |
| `PrepService` (assentos, `Validate`, `Session`, `Bridge`), `KitchenService` (`Plate`, `Grill`, `Rail`, `Board`) | intactos exceto N1 a N3 |
| `Pointer`, `Cursor` (lógica), `Rig`, `Isolate`, `Bind`, `Enter/Leave/Finish`, câmera `Prep`, `Poses` (+ vistas por passo) | ficam; o `Cursor` perde o anel 2D e ganha o marcador 3D |
| `Gestures/{slice,place,trace,slide,taps,hold,Score,Geometry,Spec}` | ficam; só `Gestures/init` ganha `PlaneRegion` |
| `Feed` (fila, grelha, os cinco atos, `Flipped`) | fica e vira a **fonte única** dos estágios 3D (nada de ler `KitchenController` em dois lugares) |
| `Build/Session` (`PrepBegin`/`PrepFinish`/`PrepTrash`, pips, notas) | fica |
| `PrepShell`, `TicketRail`, `StationTag` (barra, abas, Next, Leave, status, toast, Assist) | ficam; `PrepShell` ganha modo mínimo (sem Board/Panel/Trash) |
| `KitchenController` (`Slots.Food`, `Fx`, sizzle, fumaça, estoque, barras) | fica; ganha `FoodAt(kind, slot)` e um sinal de troca de modelo (a TASK-203 o pede) |

### 11.2 Joga fora (só depois do QA e de um release com o flag ligado)

`Stages/Grill.luau`, `Stages/Order.luau`, `Stages/Serve.luau` (versões 2D), `Cards.luau`, `Parts.luau`, `Stages/Build/Overlay.luau`, `Stages/Build/Rail.luau` (a lógica de contagem vira `Feed`), `Stages/Build/Director.luau` (substituído por `Director3D`, mas reaproveita as funções puras de gesto), `Components/IngredientPanel`, `Components/PlateView`, `Components/StrokeCanvas` (e suas stories), o anel 2D do `Cursor`, o mock 2D de `FeedMock` que só servia à UI. Ficam como histórico no git; **a limpeza é a TASK-215** e só roda com o QA da TASK-214 aprovado e a resposta de Q-234.

### 11.3 Migração incremental (a cada passo o jogo roda)

| Fase | O que entra | Flag |
|---|---|---|
| F0 | contratos: `Rules.ThreeD = false`, `Rules.World`, `Views`, N1 a N3 | desligado |
| F1 | **fatia vertical Grill 3D** (TASK-203) atrás do flag; Order/Build/Serve ainda 2D | `ThreeD` liga **só o estágio Grill 3D** (`Rules.World.Stages.Grill = true`) |
| F2 | Bun + Place + Toppings 3D (TASK-204, 205) | `Stages.Board = true`, `Stages.Toppings = true` (a chave `Build` se divide, §3.0) |
| F3 | Order e Serve na janela (TASK-206) | `Stages.Order/Serve = true` |
| F4 | co-op, tutorial, acessibilidade | — |
| F5 | QA integrada; `ThreeD = true` por padrão | `true` |
| F6 | limpeza do 2D (TASK-215) | o flag some |

Mecanismo: **`Prep.Rules.ThreeD`** (bool) mais `Rules.World.Stages` (mapa por estágio) escolhem, por estágio, o módulo 3D (`World/Stages/<Nome>.luau`, contrato `Stage3D`: `Enter/Leave/Step/Hint/Next/OnResult/OnEvent` e sem `Board/Panel`) ou o 2D atual (`Stages/<Nome>.luau`). `LoadStages` já descobre arquivos; o 3D usa outra pasta e o mesmo registro. **Rollback por camadas, sem código**: `Stages.<X> = false` volta o estágio ao 2D; `ThreeD = false` volta tudo ao 2D; `WorldKitchenPrompts = true` volta ao modo antigo de prompts no mundo (DEC-223, intacto).

## 12. Fatia vertical e ordem recomendada

**Fatia vertical = Grill 3D de ponta a ponta** (TASK-203), porque: (a) é onde o dono apontou o problema; (b) o mundo já desenha a grelha (menor trabalho novo); (c) exercita **todas** as peças novas (raio, hitboxes, alvos, anel, predição, rollback, replicação do virar, marionete), sem tocar na nota nem no `Finish`; (d) o servidor já tem tudo (só N1 e N2). Critério de pronto: no trailer, com a loja aberta, o jogador **põe, vira (nota Perfect/Good/Messy), coleta** e vê o resultado no trilho real, sem nenhum painel 2D no centro, em 667x375 com toque, no mouse e no gamepad, e um segundo jogador **vê** a salsicha virar.

## 13. Riscos e spikes (cada um com saída)

| # | Risco | Mitigação / spike |
|---|---|---|
| R1 | Cor da salsicha: `MeshPart.Color` pode não tingir a malha com textura como se espera | **S1 (meio dia)**: comparar tint, cross-fade de duas malhas, troca de `TextureID` e 3 trocas de modelo em Play; escolher o mais barato que lê bem a 144 px/stud |
| R13 | `EditableMesh`: chave "Allow Mesh / Image APIs" desligada, asset sem permissão para quem não é dono, memória do cliente | **S1b (TASK-216)** com segunda conta num jogo publicado; camada opcional com queda para A; decisão do dono em Q-235 |
| R14 | Abas embaixo colidem com a hotbar nativa ou com os controles de toque | hotbar e `TouchGui` escondidos em foco; faixa y 319 a 363 reservada; conferir com `DeviceSafeInsets` (TASK-199) |
| R15 | Hud do topo ficar visível pode competir com o cartão de progresso | cartão centrado (200..467) entre o menu do Roblox e o status (507..); medido em 667x375 |
| R2 | Espaço do ponteiro (inset) trocar o alvo em alguns dispositivos | `Ray.luau` único + `/dev prep ray`; teste em mouse, toque emulado, gamepad (TASK-196) |
| R3 | Enquadramento: grelha de 8, 6 tigelas + tábua + trilho + lixeira não cabem no quadro em 667x375 | **S2**: capturas por vista; `Fov` por âncora; vista `Build` dividida por passo; lixeira 2D de reserva |
| R4 | Offset de toque (28 px) confunde o alvo em toques discretos | Play em celular; opção de desligar o offset em toques discretos |
| R5 | Pães a 0,8 stud se encostam com 4 jogadores | **S3**: espaçamento >= 1,1 ou tábua nova (level-designer) |
| R6 | Vista `Window`: aba/janela, NPCs e luz podem tampar o cliente | fallback do §3.1 (Take no ticket 2D); Rig com exceção só para o cliente `Q1` |
| R7 | `Highlight` fino demais no celular e custo em GPU fraca | fill pulsando + anel de piso sempre; qualidade <= 3 sem `Highlight` |
| R8 | Traço do molho em segmentos pode parecer "de Lego" | simplificação + largura variável; o modelo `*_Topping` substitui ao fechar o prato se for preciso |
| R9 | Tempo-alvo 9 a 12 s sobe com arrastos físicos | TASK-212 mede e retoca os números (nada é constante no código) |
| R10 | Anomalia: ver o cliente na janela vira fuga ou não conta como "ver" | Q-228; `Rig`/saída forçada inalterados até a resposta |
| R11 | Limite de luzes do trailer (17/18) | sem luz local; material emissivo |
| R12 | Agente corrigindo bugs do `PrepController` e dos prompts Work no mesmo momento | tasks que editam `PrepController/init.luau`, `Poses.luau`, `Parts.luau`, `PrepService/{init,Session}`, `KitchenService/init.luau` só começam depois do commit dele (hoje há mudança sem commit nesses arquivos); arquivos novos em `World/` são independentes |

## 14. Decisões técnicas propostas (veto livre) e perguntas

- **DT-11** Interação por **raio** sobre hitboxes `PrepTarget` (Include), sem `ProximityPrompt`, `ClickDetector` nem `ViewportFrame`. **DT-12** Flag `Prep.Rules.ThreeD` + `Rules.World.Stages`; o 2D fica até o QA e some depois (TASK-215). **DT-13** `Gestures` aceita `PlaneRegion`; as medidas e a `Grade` não mudam. **DT-14** Vistas de câmera **por passo** (`Content.Prep.Views`), âncoras `CamAnchor_<Vista>`/`Focus_<Vista>`, atributo `Fov`. **DT-15** Cozimento desenhado no cliente pelo tempo do servidor; `Stations.Flip` (optional) replica o virar. **DT-16** `PrepGrill.Place` honra `Slot` como preferência. **DT-17** `PrepTab.Plate`/`PrepSeats.Plate`: máscara cosmética de 8 bits, sem pacote novo. **DT-18** Serve por arrastar o prato à janela, destino = ticket fixado. **DT-19** HUD mínimo de 6 blocos (§5). **DT-20** `Highlight` + anéis com orçamento e fallback em qualidade <= 3. **DT-21** Predição só visual, com rollback pelo registro. **DT-22** (rev. 2) Seções em sequência: `Tabs` = `Grill`, `Board`, `Toppings`, `Serve` (`Order` sai das abas), uma vista por seção. **DT-23** Abas embaixo; topo livre; `Hud` visível em foco (só `HudOrder` sai). **DT-24** Animação: swap/cross-fade/textura como base; EditableMesh só como camada opcional (morph do pão, tubo de molho) atrás de `Rules.World.Editable`, decidida pelo spike S1b.
- Perguntas ao dono (em lote, não bloqueantes; o trabalho segue com a recomendação Provisória): **Q-228**, **Q-229**, **Q-231** a **Q-237** em `docs/open-questions.md` (**Q-230** ferramentas visíveis e a pergunta "toppings 2D ou 3D" foram **respondidas pelo dono**: sim ferramentas 3D; toppings 3D; falta a DEC do secretário). (`Q-227`, o diálogo "Got it / Come again?", continua reservada ao `prep-mode.md`.)

## 15. Contratos finais (TASK-194; nomes que as TASK-195 a 219 usam)

Tudo em `Content.Prep` (`src/Shared/Content/Prep.luau`) salvo onde indicado. **Provisório**.

**Flag e conjuntos.** `Rules.ThreeD` (nasce `false`). `Tabs` e `Steps` são o conjunto do modo atual (2D enquanto `ThreeD = false`, então nenhum código 2D muda); os conjuntos fixos são `TabsLegacy` (`Order, Grill, Build, Serve`), `Tabs3D` (`Grill, Board, Toppings, Serve`), `StepsLegacy` (`grill, bun, build, serve`) e `Steps3D` (`grill, bun, place, toppings, serve`). `WireTabs` = união das chaves (enum de `PrepTab.Step` e `PrepSeats.Step`). `TabAlias` = chave equivalente do outro modo (`Order->Grill`, `Build->Board`, `Board->Build`, `Toppings->Build`); resolver com `Tabs.ByKey[k] and k or TabAlias[k]`. `Step` ganhou `View`; `Need` ganhou `SausagePlaced` (passo `place`).

**Vistas.** `Views` (`Grill`, `Board`, `Toppings`, `Window`), linha = `{ Key, Tab, Label, Anchor, Focus, Fallback, Fov }`: `CamAnchor` / `Focus`, `CamAnchor_Board` / `Focus_Board` (reserva `"Build"` = `LegacyView`, o par `CamAnchor_Build` / `Focus_Build`), `CamAnchor_Toppings` (reserva `Board`, `Fov` 62), `CamAnchor_Window` (reserva `Board`); `Fov` 0 = `Rules.Camera.Fov`; atributo `Fov` na âncora vence. Sem reserva: `Grill`, depois o `TRL` de `Poses`. `Validate` falha o boot se uma vista de `Steps.View` não existir ou a cadeia girar.

**Mundo.** `Rules.World`: `Tag` (`PrepTarget`), `Attr` (`TargetKind`, `Slot`, `Key`, `Fov`), `Hitbox` (`MinPx` 44, `MinStuds` 0,31, `AssistScale` 1,3, `Sausage`), `Lift`, `Ring` (`From` 1,8, `To` 1, `Good`, `Perfect`, `Late`, `Turn`, `Hop`), `Hover`, `Attract`, `Marker`, `Settle`, `Budget` (a tabela do §8), `Stages` (`Grill, Board, Toppings, Order, Serve`, todos `false`), `Editable = false`, `GhostHand = false`. Estágio 3D só roda se `Rules.ThreeD` e `Stages.<aba>`: `Stage.Armed(rules, tab)`.

**Alvos e ferramentas.** `TargetKinds` (10 do §2.2), tipo `PrepTarget = { Kind, Id, Slot, Topping }` (`Id` = `Types.IdOf`: `GrillSlot:3`, `Topping:ketchup`, `Bin`), `ToolKinds` (`None, Knife, Sausage, Bottle, Ladle, Slice, Strip, Pinch, Plate, Spatula`), `ToolOf[topping]` (ketchup, mustard, cream_cheese = `Bottle`; cheese = `Slice`; bacon = `Strip`; potato_sticks = `Pinch`), `SlotPhases` (`Free, Ghost, Cooking, FlipWindow, Late, Flipped, Ready`). Tipos reexportados em `Content` como `PrepTarget`, `PrepTargetKind`, `PrepToolKind`, `PrepSlotPhase`, `PrepView`, `PrepViewKey`, `PrepWorldRules`.

**Rede (N2, N3).** `Stations.Flip = optional(int(0, 101))` (nota + 1), `PrepTab.Plate` e `PrepSeats.Plate = optional(int(0, 255))` (opcionais por compatibilidade; a TASK-195 pode apertar). `PlateMask` (dados em `Content.Prep.PlateMask`; funções em `src/Prep/shared/PlateMask.luau`: `Pack`, `Unpack`, `Count`, `ToppingBit`, `Valid(old, new, maxToppings)`). `Validate` exige `#ToppingKeys <= 6` e `MaxToppings <= 6`. Ver `network.md` §17.

**Cliente.** `Stage.luau`: tipo `Stage3D` (`Tabs, Enter, Leave, Step, Hint, Next, OnNext?, OnAim?, OnResult?, OnEvent?`; sem `Board`/`Panel`), `Stage.check3D`, `Stage.Armed`. `PrepController/World/Types.luau`: `PointerKind`, `Target`, `Hit`, `AimMsg` (`Hover, Press, Move, Release, Drop, Tap, Cancel`), `SlotState`, `WorldMsg` (`Slot, Tool, Plate, Pulse, Burst, Rollback, Settle`), `PlaneRegion`, `FolderName`, `IdOf`, `Target`. `World/init.luau`: `Active`, `Enter(station)`, `Leave`, `Send(msg)` (stub).

## 16. O que a fatia Grill ensinou (TASK-203, 2026-10-12; Provisorio)

- **Cor da salsicha (S1 decidido na pratica):** `MeshPart.Color` so multiplica a textura (um atlas de cores compartilhado pelas duas malhas), entao tint nao serve. Funcionou o **crossfade das duas malhas reais**: `Sausage_Raw` opaca e `Sausage_Grilled` (escala 1,012, sem z-fight) por cima, com `Transparency` descendo de 1 a 0 do inicio ate o fim do cozimento; no pronto a crua some. Custo: 2 clones por rolete ocupado, uma escrita de propriedade por degrau (50 degraus), nenhuma permissao. O par e criado uma vez quando o rolete enche e vive ate esvaziar: contorno, giro e voo nunca perdem o modelo no instante "pronto". O modelo "meia" (`Sausage_Half`) nao e necessario.
- **Giro do virar:** o pivo do alimento e o centro da base, entao o giro de 180 graus passa pelo meio do corpo (`FlipCenter` 0,12, metade de 0,24) ou a salsicha afunda no rolete. A animacao solta as soldas, move por `PivotTo` e solda de novo onde terminou.
- **Anel:** `CylinderHandleAdornment` com `InnerRadius` (um anel de verdade, 1 por rolete, sem Part) sobre a parte do grill; raio 0,62 x escala 1,8 a 1,0 entre 40% e 50% da Duration (alvo em 50%), espessura 0,06 e 0,10 no Perfect (+-5%), pequeno e opaco depois de 60%.
- **Hitboxes:** os do trailer (TASK-200) bastam; `Targets.Scan` agora entrega tudo **desligado** e cada estagio liga so os seus (senao o contorno aparecia em alvos de outras secoes). `Targets:Touch()` acorda o `Highlight` quando o estagio muda `Pulse` ou `Model`.
- **Rede:** nenhum pacote novo; `Place` com `Slot` honrado pelo servidor (N1), `Flip` devolve a nota e `Stations.Flip` (N2) chega ao cliente (`SlotRecord.Flip`). O toque antes da janela nao envia nada (conferido pelo Output). Previsao = giro, fantasma "assando" e voo; o `PrepResult` recusado desfaz com tremor; a fila de envios e FIFO (a ordem de resposta do servidor e a de envio).
- **Fluxo:** com `ThreeD = true` a aba Order sai; o `Take` do cliente do balcao virou o rotulo do botao Next da grelha. Board, Toppings e Serve ainda sao 2D (barra no topo, chrome 2D), entao a troca de aba muda o chrome: aceito ate as TASK-204 a 206.
- **Duracao observada:** ~8 s no nivel atual; a janela 40% a 60% dura ~1,6 s e a de Perfect ~0,8 s. Com latencia de toque de 100 a 200 ms e viavel, mas e estreita para o primeiro contato: a TASK-212 decide se o anel entra antes (From 0,35) ou se o Assist alarga.
- **Ficou de fora:** espatula (nao ha asset importado: o marcador 3D do ponteiro faz o papel), gamepad e X (TASK-207), animacao do colega (TASK-208); a barra de progresso 2D do mundo sobre a salsicha continua (e do `KitchenController`).

## 17. O que Board e Toppings ensinaram (TASK-204 e 205, 2026-10-12; Provisorio)

- **Um modulo, duas abas.** O prato vive entre Board e Toppings, entao `World/Stages/Build.luau` serve as duas (`Tabs = Board, Toppings`) e a sessao (`BoardView`, `ToolView`, `Strokes`, `Director3D`) sobrevive a troca de aba: `Leave` so desarma e agenda a limpeza para o mesmo quadro (`task.defer`), o `Enter` da outra aba a cancela; ir a Grill ou Serve destroi o prato do mundo (o estado fica na `Session` 2D). Se o modo acabar com outra aba na frente, a pasta `PrepWorld` morre e o que foi escondido do mundo volta (`Destroying`).
- **Pao real, escala de trabalho.** `BunClosed` / `BunOpen` do kit, x2,1: a 5 studs da camera o pao do kit tem ~60 px, pequeno demais para uma faca. O mundo desenha o proprio pao da tabua pelo registro `Stations` (e o abre sozinho em 0,8 s); ele e a barra de progresso sao escondidos so no cliente (`LocalTransparencyModifier`, reaplicado a 4 Hz porque o mundo refaz os modelos) e a faca da tabua e clonada como ferramenta. `KitchenController/Board.luau` ganhou `Slots.Track` (uma linha) para o estagio achar a estacao.
- **Plano do pao, nao do mundo.** `Plane.Region` sobre o topo do pao (X = direita da tela, Z = para o jogador); `Director3D` e o `Director` 2D com a mesma matematica e a mesma `Grade`. Um arrasto que comeca na tigela fica longe do pao: o gesto so e armado quando o ponteiro entra na "esteira" (pao e margem), senao o caminho da tigela ate o pao contava como excesso de molho.
- **O plano se move.** A vista Toppings olha para as tigelas e deixa o pao na borda; o prato desliza 0,9 stud (`BoardView:MoveTo`, `Strokes:Shift`) e o plano de gesto e mutavel (`plane.Frame`). A lixeira PLACEHOLDER so aparece nessa vista.
- **Ordem de leitura.** Uma ligacao reativa (`Next`) que le uma fonte atras de `and` nao reage quando ela muda: leia todas antes de decidir. `Session.Cut()` nao e fonte; use `Needs.BunCut`.
- **Registro.** Um alvo re-adicionado por um estagio substitui o escaneado; quem precisa do hitbox autorado deve acha-lo pela tag (`CollectionService`), nao por `registry:Get`, e a sessao remove os alvos feitos com as proprias partes ao sair.
- **Molho.** Segmentos cilindricos deitados sobre a salsicha (o plano do pao fica abaixo do topo dela); passo minimo = comprimento do zigue-zague / 24, para o traco inteiro caber no teto por traco. Legivel; o aspecto "de Lego" so se ve de perto (R8). Nada de `EditableMesh`: `BoardView.swapBun` e o unico ponto onde o morph da TASK-218 entra.
- **Harness.** O Studio MCP e compartilhado com outro agente: um `/dev prep finish force` dele fecha o prato no meio do teste (planeje sequencias curtas); o mouse virtual usa y = y da captura - 58 (inset do topo) e o botao pode ficar "preso" (`duplicate button state`): termine todo arrasto com `mouseButtonUp`; `Return` avanca o `Next` por teclado.

## 17. O que o Serve e o Take ensinaram (TASK-206, 2026-10-12; Provisorio)

- **Overlay:** `Order` nao e aba no 3D, entao `World/Stages/Order.luau` e um `Stage3D` com `Overlay = true` e `Tabs = {}` (so recebe os eventos de `Broadcast`); o `Serve` o arma (`Order.Enter/Leave`) porque a vista Window e a aba Serve. O 2D `Stages/Order.luau` continua sendo quem inicia o `Feed` e encaminha `PrepResult`/`Sale`/`Cycle`: trocar isso exige o `PrepController.Enter` chamar um gancho do overlay.
- **O prato carregado nao pode ser um alvo ligado:** o hitbox do proprio prato, preso ao ponteiro, esconde o `Hatch` do raio (o soltar virava `Release`). Enquanto `Carry`, o alvo `Plate` fica desligado (`Enabled`). Vale para qualquer objeto arrastado que tenha hitbox.
- **Vista Window:** olha quase de cima (pitch 40, ~4 studs): o prato do jogador fica ao lado da bandeja (esquerda), nao entre a camera e a janela (saia do quadro). O cliente de Q1 enche a tela; o de mesa nao aparece.
- **`Feed.OnServed` tem um dono so:** o estagio 3D encadeia o gancho do 2D uma vez (`hooked`), nao o substitui; o 2D limpa a tabua e volta a Grill depois de 1,2 s (o veredito 3D dura 1,0 s).
- **`Targets.Scan(..., enabled)`** ignorava o parametro; corrigido (ver registro do dia).
- **BillboardGui:** na PlayerGui com `Adornee` na parte de ancora (sob a camera nao desenha); e a unica excecao ao "nenhum BillboardGui" do §8.
- **Entrada em Play:** a coordenada de `user_mouse_input` e a da captura menos 58 px em Y (inset do topo); um `Down` sem `Up` deixa o botao virtual preso (`duplicate button state`); chamadas de ferramenta no mesmo bloco rodam em paralelo.
