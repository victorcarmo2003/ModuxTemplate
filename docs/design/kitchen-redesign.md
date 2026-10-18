Status: Rascunho

# Cozinha: diagnóstico e redesenho do fluxo (pedido do dono, 2026-10-18)

Autor: secretário, 2026-10-18. Base: print do dono (MAP01_Restaurant: prompt "E Flip" flutuando à direita da grelha, longe
da salsicha; uma salsicha solta em cima do balcão, fora da grelha; duas barras laranjas sem rótulo no topo da tela) e a
fala "a mecânica de cozinha está toda quebrada e o fluxo está muito esquisito". Perguntas: **Q-369 a Q-377**.
O documento continua **Rascunho**: o dono não aprovou o texto inteiro, só as respostas registradas em DEC.

---

## 0. Rumo atual (DEC-302) — vale sobre todo o resto deste documento

O dono pediu de volta o sistema de cozinha anterior (modo focado, DEC-223), agora com **esteira**. O modo focado
**nunca foi apagado**: no repositório está ligado (`Content.Restaurant.Rules.Enabled = false`); some só no Studio do dono,
onde a chave do restaurante foi ligada à mão e desliga o Prep (`src/Shared/Content/Restaurant.luau:338-341`).

### 0.1 Fluxo novo, passo a passo (Provisório nos pontos das Q-379 a Q-383)

> **DEC-304 (emenda):** o pedido tomado no tablet cria um **prato vazio com o ticket #n** numa vaga da **mesa central**. O
> montador pega esse prato (segurar E), leva à esteira, monta, e devolve à mesa ou leva direto ao `PICKUP`. Enquanto segura
> o prato, o **ticket fica na tela** (HUD). A mesa central é o **início e o fim** do fluxo. Os passos abaixo seguem esta ordem.

| # | Onde | O que o jogador faz | Resultado |
|---|---|---|---|
| 0 | tablet → mesa central | pedido tomado; nasce o **prato vazio com ticket #n** numa vaga livre (8) | — |
| 0b | mesa central | **segurar E** pega o prato | prato no inventário; **ticket na tela** enquanto segura |
| 1 | bancada da cozinha | **um ProximityPrompt único** entra no preparo (câmera focada) | o prato **que ele trouxe** vai para a esteira, embaixo |
| 2 | grelha (bancada alta, **esquerda**) | clica na salsicha para grelhar; pronta, ela vai à **mesa de descanso** | salsicha disponível para qualquer prato |
| 3 | esteira | setas **esquerda/direita** levam o **próprio prato** até a estação | — |
| 4 | pão (bancada alta, **meio**) | clica na cesta de pão e **arrasta o dedo para cortar** | pão aberto no prato |
| 5 | montagem | clica ou segura para **arrastar a salsicha** da mesa de descanso **ao pão** | hot dog no prato |
| 6 | condimentos (bancada alta, **direita**) | clica no condimento e **desenha ketchup/mostarda seguindo o padrão** | hot dog pronto |
| 7 | **mesa central** (grid) ou direto ao passo 9 | **clica** para pôr o prato pronto numa vaga livre | prato pronto na mesa |
| 8 | mesa central | **segurar E** pega o prato de volta | prato no **inventário** (até 2 na mão) |
| 9 | `PICKUP` | ProximityPrompt segurando o prato | entrega ao cliente (DEC-072) |

- Referência de mecânica (só mecânica): o jogo de bolo do Purple Place, com estações em fila em cima, a esteira com o
  produto embaixo e as setas para mover. Nada de nome, arte ou layout copiado.
- Papéis: **grelhador** (passo 2, constante) · **montador** (passos 3–7 na esteira) · **entregador** (8–9) e tablet.
- Esquerda/direita é a da **fala do dono**; o level-designer confere no mapa de que ponto de vista.

### 0.2 O que fica superado

| Peça | Situação |
|---|---|
| DEC-297 (tudo no mundo, sem foco) e §5 Opção A deste doc | **superados** |
| DEC-301 (layout pão → grelha → condimentos) e §7 deste doc | **superados no layout** (fica o fato da Q-377) |
| DEC-298 (sem queima, sem barra, virar opcional) | **a revisar** na grelha focada (Q-381) |
| DEC-299: nota removida | **em dúvida** (Q-382) · "segurar 0,5 s por topping": **cai** · 2 pratos na mão: **continua** |
| `tech/prep-mode.md`, `tech/prep-3d.md` | **voltam a ser base**, com a esteira a desenhar no lugar de abas/pan e da tábua única |
| `tech/restaurant-flow.md` §3.3, FEAT-044/045 | seguem desatualizados |
| TASK-494 a TASK-511 | **Em revisão (DEC-302)**; replanejar depois das respostas |

### 0.3 Decididas pela DEC-303 (Q-379 a Q-383, todas opção A)

| ID | Pergunta | Decisão |
|---|---|---|
| Q-379 | Esteira: foco por jogador ou física compartilhada? | **foco por jogador**; câmera travada; setas movem só o próprio prato |
| Q-380 | Quantos na esteira e dois pratos na mesma vaga? | **até 2**; cada estação atende um prato por vez; o 2º espera ao lado |
| Q-381 | Grelhador em vista focada ou no mundo? Regras da DEC-298? | **vista focada**; sem queimar, virar opcional com bônus, sem barra |
| Q-382 | Nota e padrão de desenho voltam? | **voltam**; Perfect dá gorjeta extra |
| Q-383 | Grid da mesa central e ticket no prato? | **8 vagas**; prato leva ticket #n; o PICKUP entrega ao dono do ticket |

Com isso, na §0.2: DEC-298 fica **confirmada dentro da grelha focada** e a remoção da nota (DEC-299) **cai**.

### 0.4 Daqui para baixo: histórico

As seções 1 a 7 são o diagnóstico e as decisões anteriores (DEC-297 a DEC-301). O diagnóstico de bugs (§2) continua útil:
as barras laranjas de mundo, a âncora do Flip e a salsicha solta são do fluxo de mundo que o Studio do dono roda hoje.

> **Histórico — decidido pelo dono em 2026-10-18 (recomendação em todas), depois superado em parte pela DEC-302:** **DEC-297** (Q-369 A: tudo no mundo 3D, prato viaja,
> sem modo focado; Q-370 A: o modo focado sai do restaurante, código guardado), **DEC-298** (Q-371 B: virar opcional com
> bônus; Q-372 A: não queima na onda 1; Q-375 B: só cor, fumaça e ícone "pronto", sem barra), **DEC-299** (Q-373 A: sem nota
> Perfect/Good/Messy, gorjeta pela rapidez; Q-374 A: segurar 0,5 s por topping, só as tigelas do pedido acendem; Q-376 B: 2
> pratos na mão), **DEC-301** (bancada reorganizada: o fluxo anda da esquerda para a direita do cozinheiro, §7; Q-377
> respondida: chave do restaurante ligada no repositório na onda 1). Q-307 superada.
>
> **Desatualizados até a reescrita** (não seguir nestes pontos): `tech/prep-mode.md`, `tech/prep-3d.md` (modo focado inteiro
> no restaurante), `tech/restaurant-flow.md` (§3.3 pilhas, passa, `plate_take` com pão e salsicha), `design/restaurant-flow.md`
> FEAT-044/045 (seções focadas, pilhas, "Fill All", queima), `design/prep-stations-proposal.md` (seções focadas por estação).

Legenda: **[código]** = lido no código · **[doc]** = lido em documento · **[inferido]** = hipótese a confirmar em Play.

---

## 1. Como a cozinha funciona hoje

### 1.1 A chave que decide tudo

| Chave | Valor no repositório | Efeito | Fonte |
|---|---|---|---|
| `Content.Restaurant.Rules.Enabled` | **false** | fluxo do trailer: sem tablet, sem pratos-slot, sem retirada | [código] `src/Shared/Content/Restaurant.luau:182` |
| `Prep.Rules.Enabled` | **true** (derivado: `not on`) | modo focado (DEC-223) ativo | [código] `Restaurant.luau:338-341`, `Prep.luau:733` |
| `Prep.Rules.WorldKitchenPrompts` | **false** (derivado: `on`) | prompts de mundo da cozinha escondidos | [código] `Prep.luau:735` |
| `Prep.Rules.ThreeD` | true | grelha 3D; Board/Toppings/Serve ainda nos estágios 2D via `TabAlias` | [código] `Prep.luau:738` |
| `PlateController`, `TabletController` | inertes com a chave desligada | — | [código] `src/Plate/client/PlateController.luau:23`, `src/Tablet/client/TabletController.luau:25` |
| Prompt `grill_flip` | só aparece com a chave **ligada** | — | [código] `src/Kitchen/server/KitchenService/Stations/Grill.luau:24, 294` |

Leitura: **existem dois fluxos de cozinha inteiros no código**, trocados por uma chave, e um terceiro aprovado só no papel.

| Fluxo | Onde está | Estado |
|---|---|---|
| F1. Modo focado do trailer ("mesa de trabalho", `Station_n`, `PrepService:StepNear`) | `src/Prep/**`, `tech/prep-mode.md`, `tech/prep-3d.md` | ligado no repositório (chave off) |
| F2. Restaurante por prompts de mundo + pilhas (`bun_sliced`, `sausage_grilled`) + pratos-slot | `src/Plate`, `src/Tablet`, `Kitchen/Stations/*`, `tech/restaurant-flow.md` | código pronto, chave off; é o fluxo que o print mostra |
| F3. "Prato viaja" (DEC-295, Q-361 C) | `design/prep-stations-proposal.md`, TASK-487 | **sem código** (Pendente, "depois das anomalias") |

### 1.2 Passo a passo de um pedido no F2 (o do print) [doc + código]

Fonte: `tech/restaurant-flow.md` §3.3, `tests/restaurant-e2e.md` §2.1–2.4.

| # | Onde | Prompt / ação | Na mão depois |
|---|---|---|---|
| 1 | `TAB-1` | "Take Order" (toque) → fala 2–4 s | — |
| 2 | passa | ticket cai sozinho num `PLATE-n` (fantasma) | — |
| 3 | `CUT-n` | "Slice Bun" (segurar 0,6–0,8 s) | Tool `bun_sliced` ×1..3 |
| 4 | passa | "Add Bun" (só com o Tool **equipado**) | — |
| 5 | `STOCK` | "Grill" (toque) | — |
| 6 | grelha | esperar o 1º lado; a salsicha **para** e espera | — |
| 7 | grelha | "Flip" (toque); +1 s | — |
| 8 | grelha | "Collect" (toque) → vai à pilha (rail) | — |
| 9 | pilha | "Take Dogs" (toque) | Tool `sausage_grilled` ×1..3 |
| 10 | passa | "Add Sausage" (equipado) | — |
| 11 | passa | "Take Plate" (mão livre; exige pão **e** salsicha) | Tool `hot_dog` |
| 12 | `COND-n` | "Add {topping}" (segurar 1 s) × K | `hot_dog` com toppings |
| 13 | `PICKUP` | "Hand Over" | — |

Total: **12 + K prompts, 5 lugares, 3 tipos de Tool**, ~4 trocas de equipar na hotbar. O jogador volta à passa 3 vezes.

### 1.3 Passo a passo no F1 (modo focado, chave off) [doc + código]

"Work" na mesa de trabalho → câmera focada → abre a aba mais perto (`StepNear`) → Grill (pôr, virar, coletar ao trilho)
→ Board (cortar, arrastar a salsicha) → Toppings → Next/Serve → `hot_dog` na mão → entrega no mundo. Uma bancada faz
tudo; o restaurante físico (grelha, tábuas, condimentos separados) fica só de cenário.

---

## 2. O que está quebrado (por tema)

| # | Tema | Sintoma | Causa provável | Tipo |
|---|---|---|---|---|
| Q1 | **Chave / build** | o print mostra "Flip" de mundo, que só existe com a chave ligada; o repositório está com a chave desligada | o Studio roda uma build diferente do repositório (outra sessão com `Enabled = true`) ou a chave foi ligada à mão; os dois fluxos se misturam | [inferido] a partir de `Grill.luau:294` × `Restaurant.luau:182` |
| Q2 | **Prompt Flip longe da salsicha** | pílula "E Flip" à direita, fora da vaga | **hipótese principal (relatório Explore):** client e servidor escolhem peças `Slot = n` diferentes. O client (`KitchenController/Slots.luau:123-179`, `Slots.Spots`) aceita qualquer `Attachment` ou `BasePart` com `Slot` e prefere a **sem** `Level`; o servidor (`KitchenService/init.luau:545-578`, `CollectParts`) aceita só `Attachment` e prefere a de `Level` exato. Com mais de uma instância `Slot = n` no `GRILL-1`, o prompt fica numa e a salsicha em outra [código; a duplicata no place é inferida]. Causa somada: a âncora `Att_Flip<n>` é criada pelo bind 0,35 stud acima do Collect (`tools/assetplace/restaurant_bind.luau:1648-1659`); só é movida para a vaga se a chave estiver ligada **e** `station.Slots[slot]` existir (`Grill.luau:328-341`). Se a grelha foi movida/editada à mão (TASK-477, layout novo) a âncora fica no lugar antigo. `MapIndex` não confere distância entre âncoras do mesmo dono (`src/Place/shared/MapIndex/init.luau:637-668`, risco R-3 do e2e) | [código] + [inferido] |
| Q3 | **Salsicha solta no balcão** | salsicha fora da grelha, sobre o tampo | **mais provável (relatório Explore):** salsicha do rail sem `Rail_<N>`/`Part` de apoio; o console avisa "[RailSlot] ... sausages may float" (`RailSlot.luau:86-89`). Nenhuma âncora de `rail_take` existe nos scripts de `tools/assetplace` [código]. Outras candidatas: (a) a **pilha/trilho** (`rail`, "pilha quente") que o `KitchenController` desenha ao lado da grelha depois do Collect: sem o modelo do trilho no restaurante ela parece solta; (b) visual do modo focado (`Att_Bun`/salsicha no trilho do `Station_n`) aparecendo fora do foco; (c) peça decorativa do pack | [inferido]; confirmar qual Model é em Play (Explorer do Studio) |
| Q4 | **Duas barras laranjas sem rótulo** | barras no topo, uma à esquerda e uma à direita | a grelha desenha uma `ProgressBar` **laranja por vaga cozinhando** (BillboardGui, 0,8×0,15 stud, `src/Kitchen/client/KitchenController/Grill.luau:5`, `Slots.luau:376-395`), sem texto; só some quando o modo focado está na tela (`Slots.SetBarsHidden`, `Slots.luau:366-374`). **Confirmado (relatório Explore):** é a `ProgressBar` de cada vaga (`Slots.luau:376-395`, chamada em `KitchenController/Grill.luau:150`), BillboardGui em studs, sem texto, cor `Theme.Color.Cooking`; fica **presa em 0,5** durante a pausa do Flip (`Grade.luau:165-178`); no fluxo de mundo está sempre visível. Com 2 salsichas e a câmera perto, as duas ficam grandes no alto do quadro. **A DEC-298 tira essas barras.** | [código] |
| Q5 | **Grelha trava sem virar** | salsicha não virada nunca fica pronta | o cozimento pausa no 1º lado até o Flip (`Grill.luau:6-8`); sem aviso claro, parece bug | [código] |
| Q6 | **Caminho duplo de montagem** | com a chave ligada, os 5 prompts antigos do trailer voltam | `WorldKitchenPrompts = on` liga os prompts de mundo do trailer. **Correção:** o risco R-4 do e2e ("`PendingStationKind = cut` não é lido") está **velho**: `KitchenService:ApplyPendingKind` existe (`KitchenService/init.luau:678-690`, chamado em `:615`) | [código] |
| Q7 | ~~Pedido some~~ (**corrigido no código**) | — | O R-8 do e2e está **velho**: o `TabletService` agora cancela a conversa e mantém o cliente na `Q1` (`src/Tablet/server/TabletService.luau:19-23, 243-247, 274-275`) | [código] |
| Q8 | **Doc × código (números e chaves)** | critérios de aceite lidos ao pé da letra falham | `bun_slice` é **0,6 s** (doc diz 0,8); rótulo **"Take Dogs"** (doc: "Take Sausage"); raio de `pickup_serve` **7** (doc: 6). `BurnAfter`, `FlipFrom/To`, `PickupPerfect/Good`, `FillAllHold`, `SlotLock` são declarados no `Content` e **nunca lidos**. Nenhuma âncora de `rail_take` nos scripts de `tools/assetplace` | [código, relatório Explore] |

## 3. O que está esquisito no fluxo (por tema)

| # | Tema | Esquisitice |
|---|---|---|
| E1 | **Quantidade** | 12 + K prompts e 5 lugares por hot dog (§1.2); o "pedido" não anda: é um fantasma na passa até o fim |
| E2 | **Três coisas na mão** | pão em pilha, salsicha em pilha e prato: o jogador pensa em hotbar, não em hot dog (`prep-stations-proposal.md` §1) |
| E3 | **Equipar para ver prompt** | "Add Bun/Sausage" só aparece com o Tool **equipado** (e2e K3): parece que o prompt sumiu. A trava é só do client (`Interaction/client/PromptController/Rules.luau:104`, `plateAllows`); o servidor (`PlateService/init.luau:355-368`, `PickPut`) já aceita a mão vazia e puxa da hotbar |
| E4 | **Grelha com 3 prompts por vaga** | Grill, Flip, Collect + "Take Dogs" na pilha; vagas a < 1 stud uma da outra: no celular erra a vaga (R-3) |
| E5 | **Modo focado × mundo** | DEC-223 diz "foco é o único jeito"; DEC-272/280/295 pedem estações físicas; o código liga um ou outro pela chave. O mundo 3D desenha a grelha, mas no F1 quem trabalha é a tela focada |
| E6 | **Feedback sem rótulo** | barras laranjas sem texto, sem ícone; o OrderBoard (painel de pedidos) e o HudOrder repetem informação |
| E7 | **Ritmo** | F1: 12–18 s por prato numa tela fechada; F2: muita caminhada de volta à passa |

## 4. Documentos desatualizados ou em conflito

| Documento | Diz | Realidade |
|---|---|---|
| `tech/prep-mode.md`, `tech/prep-3d.md` | foco é o fluxo do jogo (DEC-223) | DEC-272/295 superam no restaurante; código ainda o liga |
| `tech/restaurant-flow.md` §3.3 | pilhas + passa + `plate_take` com pão e salsicha | DEC-295 (Q-361 C, Q-362, Q-363, Q-364) trocou por "prato viaja" |
| `design/restaurant-flow.md` FEAT-044/045 | seções focadas por estação (Q-307 A), queima, "Fill All", pilhas | código sem queima, sem estorno, paga na entrega (e2e R-5); FEAT-045 superada pela DEC-295 |
| `design/prep-stations-proposal.md` | opção C aceita (DEC-295) | sem código; TASK-487 Pendente |
| `open-questions.md` Q-307 | aberta (A/B/C) | na prática respondida pela DEC-295 (C ⊃ A); falta fechar formalmente |

---

## 5. Proposta de fluxo novo

Peças comuns às três opções: tablet (FEAT-043) e entrega no `PICKUP` (FEAT-046) sem mudança; estoque infinito na despensa
(DEC-285); uma chave só, sem segundo fluxo vivo; nada de barra solta na tela.

### Opção A — Tudo no mundo 3D, prato viajando, sem modo focado

| Parada | Ação | Tempo |
|---|---|---|
| Passa | "Take Plate #12" (prato vazio) | toque |
| Pão | "Cut Bun" com o prato na mão: pão cai no prato | segurar 0,6 s |
| Grelha | "Grill" põe crua (sem prato). Com prato e pão: "Add Dog" pega a pronta mais antiga | toque |
| Condimentos | só as tigelas do pedido acendem; "Add {topping}" | segurar 0,5 s cada |
| PICKUP | "Hand Over" | toque |

- Grelha: 1 prompt por grelha (não por vaga); salsicha muda de cor e solta fumaça; virar é **opcional** (bônus, DEC-298); não queima; sem barra.
- Prompts: 4 + K por pedido; 1 tipo de Tool (o prato, até 2).
- **Prós:** rápido de jogar, fácil no celular, reaproveita F2 (`PlateService`, `Grill`, `Toppings`), um só fluxo; atende DEC-275 e DEC-295.
- **Contras:** perde o minigame de precisão (DEC-229, Perfect/Good/Messy); o código do `Prep` (~25 mil linhas) fica parado.

### Opção B — Modo focado único por pedido (uma tela)

- O jogador pega o pedido na passa, vai à **mesa de trabalho** e faz tudo numa tela focada (grelha, corte, condimentos).
- **Prós:** reaproveita o F1 inteiro; minigame com nota.
- **Contras:** contradiz DEC-272/280/295 (estações físicas, prato viaja); co-op fica 1 pessoa por mesa; o restaurante vira cenário; é o "uma coisa só" que o dono rejeitou no Play de 2026-10-18.

### Opção C — Híbrido: prato viaja (A) + foco curto só nos condimentos

- Igual à A, mas em `COND-n` abre a seção `Toppings` focada (molho em zigue-zague, nota), Done devolve o prato.
- **Prós:** mantém um pouco da dopamina (DEC-229) onde ela rende mais; reaproveita parte do `Prep`.
- **Contras:** duas linguagens de interação; câmera entra/sai a cada pedido (+0,65 s); mais código a manter.

### Comparação

| Critério | A | B | C |
|---|---|---|---|
| Segue DEC-295 (prato viaja) | sim | não | sim |
| Prompts por pedido (K = 2) | ~6 | ~2 + tela | ~5 + tela |
| Celular | ótimo | médio (arrasto) | bom |
| Co-op (DEC-275) | bom | fraco | bom |
| Risco de bug / prazo | baixo | médio | médio |
| Minigame de precisão | não | sim | só condimentos |

### Decisão — **DEC-297** (opção A)

O dono escolheu a **Opção A** (Q-369) e tirou o modo focado do restaurante (Q-370). Com DEC-298/299: a salsicha fica
pronta sozinha e virar na hora dá bônus; não queima; sem barra (cor, fumaça, ícone "pronto"); sem nota de precisão;
condimentos por segurar 0,5 s, só as tigelas do pedido acendem; até 2 pratos na mão. Texto original da recomendação:

**Opção A** na onda 1, com a chave única ligada e o F1 desligado de vez no restaurante. Motivo: o dono pediu
velocidade (DEC-275) e chamou o fluxo de quebrado e esquisito; A tem menos peças, um caminho só e já é quase todo o
código do F2. A Opção C fica como **onda 2** se o playtest pedir "mais gosto" no preparo.

### Critérios de aceite da Opção A (Provisórios)

- Um pedido K = 2 sai com **≤ 6 prompts** e ≤ 4 lugares; solo hábil em **≤ 15 s** de cozinha.
- Cada prompt da grelha aparece **a ≤ 0,5 stud** da peça que ele afeta; nenhuma pílula fora do móvel.
- Nenhuma salsicha visível fora de grelha, prato, ou mão; nenhum visual de cozinha sem dono no `Workspace`.
- Nenhuma barra de progresso sem rótulo/ícone; nenhuma barra no HUD da tela pela cozinha.
- Só **um** fluxo de cozinha ligado no restaurante (os prompts antigos do trailer e o `Work` não aparecem).
- Celular 667×375: tocar a estação certa em 10 de 10 tentativas.

---

## 6. Perguntas ao dono (Q-369 a Q-376) e técnica (Q-377)

Texto completo e opções em `docs/open-questions.md`.

| ID | Pergunta | Situação |
|---|---|---|
| Q-369 | Qual fluxo: A (mundo), B (foco único) ou C (híbrido)? | **DEC-297: A** |
| Q-370 | O modo focado sai do restaurante de vez (código guardado)? | **DEC-297: sim** |
| Q-371 | Virar a salsicha: some, opcional com bônus, ou obrigatório? | **DEC-298: opcional com bônus** |
| Q-372 | Salsicha queima? | **DEC-298: não na onda 1** |
| Q-373 | Nota Perfect/Good/Messy continua? | **DEC-299: sai; gorjeta pela rapidez** |
| Q-374 | Condimentos: segurar por topping ou um toque que aplica o pedido todo? | **DEC-299: segurar 0,5 s por topping** |
| Q-375 | Feedback de cozimento: barra sobre a vaga, só cor/fumaça, ou anel? | **DEC-298: cor + fumaça + ícone "pronto"** |
| Q-376 | Quantos pratos na mão (DEC-295 disse 2): mantém? | **DEC-299: 2** |
| Q-377 | (técnica) Qual build roda no Studio do dono: chave ligada ou desligada? | **respondida (DEC-301):** Studio com a chave ligada à mão; repositório com `false`; na onda 1 a chave fica ligada no repositório |

---

## 7. Layout da bancada (DEC-301)

Regra do dono: o hot dog anda **da esquerda para a direita do cozinheiro**, na ordem das etapas
(passa/prato → pão → grelha → condimentos → pickup).

Referencial: `levels/MAP-01-r4-restaurant.md` (+X leste, +Z sul). O cozinheiro fica na bancada do fundo **olhando para o
sul**, então a **esquerda dele é o leste (X maior)** e a **direita é o oeste (X menor)**. Fonte das posições atuais:
`tools/assetplace/restaurant_bind.luau:1006-1011, 1668, 1746, 1633`.

### 7.1 Hoje (fora de ordem)

| Peça | X | Lado do cozinheiro | Etapa |
|---|---|---|---|
| `BIN-K` (chão) | 26,5 | direita (canto) | — |
| `GRILL-1` | 33,5 | **direita** | 3 |
| `RAIL` (pilha quente) | 37,6 | direita | 3 |
| `STOCK` (salsichas cruas) | 40,6 | centro-direita | 3 |
| `BUN` (caixa de pães) | 43,9 | **centro** | 2 |
| `CUT-1` | 46,6 | centro | 2 |
| `CUT-2` (prompt de corte) | 48,9 | centro-esquerda | 2 |
| `COND-1` | 54,6 | **esquerda** | 4 |
| Passa `PLATE-1..8` | 33,4 → 51,6 (Z 62,25) | toda a largura | 1 |
| `PICKUP` (balcão da frente) | 36 (Z 54,9) | — (oeste) | 5 |

Rota de um pedido hoje: passa → pão (centro) → grelha (direita) → **volta à esquerda** nos condimentos → atravessa a
cozinha até o `PICKUP` a oeste. Duas travessias inteiras.

### 7.2 Ordem nova (proposta Provisória; posições finais com o level-designer)

| Ordem (esquerda → direita do cozinheiro) | Peça | X proposto (leste → oeste) |
|---|---|---|
| 1 | início da passa: pratos novos nascem no apoio mais a leste | `PLATE` a partir de ~51 |
| 2 | `BUN` + `CUT-1` (+ `CUT-2`) | ~48,5..56 |
| 3 | `STOCK` + `GRILL-1` (+ `GRILL-2` de upgrade) + saída das prontas | ~37,5..47,5 |
| 4 | `COND-1` | ~32..36,5 |
| 5 | `PICKUP` (balcão da frente, X 36): o corredor oeste liga `COND-1` ao `PICKUP` | 36 (sem mudança) |

- Bate com o layout da `prep-stations-proposal.md` §4 (COND-1 32..36,5 · grelha 37,5..47,5 · pão 48,5..55,75): o
  level-designer pode partir dele.
- A rota fica em **um sentido só** (leste → oeste no mundo = esquerda → direita do cozinheiro) e termina perto do `PICKUP`.
- **Em aberto para o level-designer:** a parada de condimentos do drive-thru (`COND-2`, janela a leste) quebra o sentido
  para os pedidos de carro; proposta da `prep-stations-proposal.md`: `COND-2` a leste do pão, só para pratos com carro.
- Folga da porta da despensa (`DOOR-P`, X 25,5..30,5) e corredores ≥ 4 studs seguem valendo.

### 7.3 Critérios de aceite do layout

- Um pedido de salão percorre passa → pão → grelha → condimentos → `PICKUP` **sem voltar** para um X já passado.
- Do ponto de vista do cozinheiro de frente para a bancada, o pão está à esquerda da grelha e a grelha à esquerda dos condimentos.
- Placa com ícone em cada móvel; prompts vizinhos a ≥ 2,5 studs (DEC-066).
- Antes de mexer no place: sincronizar as edições à mão do dono no Studio (nunca `Place.run` sem pedido).
