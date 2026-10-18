Status: Rascunho

# Cozinha com esteira: contrato de rede e de serviços (TASK-512)

Autor: architect · 2026-10-18 · Base: **DEC-302** (o modo focado volta ao restaurante, com esteira), **DEC-303** (Q-379 a
Q-383, todas A), **DEC-304** (o prato nasce na mesa central com o ticket; ticket no HUD), `design/kitchen-redesign.md` §0,
`tech/prep-mode.md` e `tech/prep-3d.md` (voltam a ser base), código lido em `src/Prep`, `src/Plate`, `src/Tablet`,
`src/Kitchen`, `src/Customer/server/CustomerService` (Pickup), `src/Shared/Content/Prep.luau`, `Restaurant.luau` e
`src/Libs/Net/*`. Nada aqui é código: é o contrato que a **TASK-513** grava em `Content`/`Net` e que as tasks da onda C
(496, 514 a 522) implementam em paralelo.

> **Emenda (decisão do dono de 2026-10-18 sobre este documento; a secretária registra a DEC):** **dois prompts** (esteira
> e grelha) no lugar do prompt único; P3 e P5 caem; no solo o montador sai da esteira, usa o prompt da grelha e volta,
> e o prato dele fica **parado e reservado na esteira** (§2.3, §2.4). Tempo de grelha 8/6/4 s; Perfect = gorjeta base
> + $1 (`TipExtra` 1); UPG-016 sai de venda no restaurante; mesa de descanso com 8 salsichas. P6 a P8, P11 a P13 e as
> técnicas (DT-E1..E10 e as P técnicas do §12) ficam **aceitas**. Marcadas abaixo como "Aceita (dono)".

Convenções deste documento:
- **Decidido** = está em DEC do dono (citada ao lado).
- **Provisória** = escolha do architect, não decidida pelo dono. As que restam estão no §12.
- **Aceita (dono)** = era Provisória e o dono aceitou em 2026-10-18 (DEC a registrar pela secretária).
- `DT-E#` = decisão técnica proposta (veto livre do dono; o secretário numera como DEC quando registrar).
- Números novos são Provisórios até a TASK-508 fechar e a TASK-506 aplicar.

---

## 0. Resumo em uma tabela

| Peça | Contrato | Onde |
|---|---|---|
| Chave dupla | `Restaurant.Rules.Enabled = true` no repositório; `Switch.PrepEnabled = true` sempre; `Switch.PrepMode = "Conveyor"` com o restaurante, `"Trailer"` sem ele; `WorldKitchenPrompts = false` sempre | §1 |
| Assentos | 3 registros de `PrepSeats` no modo esteira: 1 e 2 = esteira (montador), 3 = grelha (grelhador) | §2 |
| Dois prompts | `prep_work` em `Prompt_Work` (esteira, exige prato) e `prep_grill` em `Prompt_Grill` (grelha) | §2.2 |
| Posição do prato | campos novos `Stop`, `Wait`, `Line` no set `PrepSeats`; seta = packet `PrepBelt` | §3 |
| Reserva | 1 prato por parada de trabalho (Grelha, Tábua, Condimentos); o 2º espera ao lado (`Wait` 1 ou 2) e entra sozinho quando libera | §4 |
| Mesa de descanso | o **rail** que já existe (`Stations` kind `rail`, `PrepClaims` `Rail`), capacidade 8, sem queima | §5 |
| Prato e ticket | pedido tomado → prato vazio com ticket #n numa vaga livre da mesa central; registro de pratos em `PlateService` | §6 |
| Mesa central | set `Plates` (já existe) = vagas 1..8; segurar E pega (`plate_take`); clicar põe (packet `CenterPut`) | §7 |
| PICKUP | `pickup_serve` segurando; entrega só ao cliente dono do ticket e só prato montado | §8 |
| Rede | 2 packets novos em `Net/init.luau` (`PrepBelt`, `PrepStage`), 4 campos novos em `PrepSeats` (`Stop`, `Wait`, `Line`, `Away`); 1 packet novo em `Net/Restaurant.luau` (`CenterPut`), 1 campo novo em `Plates` | §9, `network.md` §19 |
| Serviços | `PrepService` → `PlateService` (pegar/devolver prato) e → `KitchenService` via `Bridge` (pão, salsicha do descanso, toppings, grelha) | §10 |
| Content | chaves novas e mortas para a 513 e a 506 | §11 |

---

## 1. Chave dupla: restaurante ligado e Prep focado ligado juntos

**Hoje** (`src/Shared/Content/Restaurant.luau`, `Switch`): `PrepEnabled = not on` e `WorldKitchenPrompts = on`. Ligar o
restaurante desliga o Prep e liga os prompts de mundo da cozinha (fluxo F2). Por isso o Prep "some" no Studio do dono
(DEC-302, fato técnico).

**Novo** (TASK-513 grava; DT-E1):

| Chave | Trailer (`Rules.Enabled = false`) | Restaurante (`Rules.Enabled = true`) |
|---|---|---|
| `Restaurant.Rules.Enabled` | false | **true no repositório** (igual ao Studio do dono) |
| `Switch.PrepEnabled` → `Prep.Rules.Enabled` | true | **true** |
| `Switch.PrepMode` → `Prep.Rules.Mode` (novo) | `"Trailer"` | `"Conveyor"` |
| `Switch.WorldKitchenPrompts` → `Prep.Rules.WorldKitchenPrompts` | false | **false** |
| `Prep.Rules.ThreeD` | true | true |
| `Prep.Rules.Delivery` | `"Prompt"` | `"Prompt"` (o prato volta à mão ao sair do foco) |

- `Prep.Rules.Mode` é o único lugar que o código lê para escolher entre "abas/pan + tábua por assento" (Trailer) e
  "esteira + paradas" (Conveyor). Nenhum módulo lê `Restaurant.Rules.Enabled` para decidir o modo do Prep.
- `Validate.luau` (513): troca o check da TASK-390 por `Prep.Rules.Enabled == true`, `Prep.Rules.Mode == (on and
  "Conveyor" or "Trailer")` e `Prep.Rules.WorldKitchenPrompts == false`, nos dois modos.
- Rollback: só para o trailer (`Rules.Enabled = false`). O fluxo F2 (prompts de mundo) **não** tem rollback por chave depois
  da TASK-506 (ela remove o código morto). **Aceita (dono) P1.**

### 1.1 O que some no restaurante (lista exata)

`KitchenService:HiddenByPrep` e o `KITCHEN_ACTIONS` do `PrepController` passam a esconder, com `Mode = "Conveyor"`, o
conjunto abaixo. Os handlers ficam registrados (o trailer usa os mesmos módulos); só o `PromptEnabled` fica `false`.

| Ação (`Content.Actions`) | Onde estava no MAP-01 | Por quê some |
|---|---|---|
| `grill_place` | `STOCK` / grelha ("Grill") | a grelha é focada (`PrepGrill Place`) |
| `grill_collect` | `Att_Slot<n>` da grelha ("Collect") | a pronta vai sozinha à mesa de descanso (§5) |
| `grill_flip` | `Att_Flip<n>` ("Flip") | virar é na vista focada (`PrepGrill Flip`) |
| `bun_cut` | cesta de pão do trailer ("Slice Bun") | corte é gesto na parada Tábua |
| `bun_slice` | `CUT-n` ("Slice Bun", segurar) | idem |
| `board_add_sausage` | tábua ("Add Sausage") | arrastar a salsicha é gesto na parada Tábua |
| `rail_take` | rail ("Take Dogs") | a salsicha sai do descanso só pelo foco (`PrepStage Dog`) |
| `topping_add` | `COND-n` ("Add {topping}") | condimentos são gesto na parada Condimentos |
| `plate_put` | passa `PLATE-n` ("Put Plate") | a passa sai; a mesa central põe por clique (`CenterPut`) |
| `plate_take` **da passa** | passa `PLATE-n` | a passa não é mais ligada (`PlateService` liga `CenterSlot`, §7.4) |

Ficam ligados no restaurante: `prep_work` (esteira) e `prep_grill` (grelha), `tablet_take`, `plate_take` **da mesa central** (âncoras
`CenterSlot`), `pickup_serve`, `discard` da BIN-C (jogar fora hot dog na mão), `take_box`, `restock`, `brew_coffee`,
`collect_tips`, portas, luz, telefone e o resto do mundo. As peças físicas da cozinha do F2 (`CUT-n`, `COND-n`, passa)
viram cenário e âncora de câmera (TASK-496 e TASK-504).

---

## 2. Assentos, dois prompts e caso solo

### 2.1 Assentos (DT-E2, aceita)

`PrepSeats` continua com id = assento 1..`Content.Prep.Stations` (4 no fio, sem mudança de schema de id). No modo
esteira o servidor publica **3 registros fixos** desde o `ShiftStarted` (não crescem com a party):

| Assento | Papel | Máx. | Pé do rig (TASK-503 §16.5 c) | Decisão |
|---|---|---|---|---|
| 1, 2 | **esteira** (montador, um prato cada) | 2 | `Seat_Belt_1`, `Seat_Belt_2` | Decidido: até 2 na esteira (Q-380 A) |
| 3 | **grelha** (grelhador, sem prato) | 1 | `Seat_Grill` | **Provisória P2** (1 assento de grelha) |

`Content.Prep.Conveyor.Seats = { Belt = { 1, 2 }, Grill = { 3 } }` e `Conveyor.Binding.Seats = { "Seat_Belt_1",
"Seat_Belt_2", "Seat_Grill" }` (índice = assento). O modo Trailer segue com `clamp(membros, 1, 4)` registros e os
`Station_n`/`Att_Stand` de hoje.

### 2.2 Dois prompts (Decidido pelo dono, 2026-10-18; supera o "prompt único" da DEC-302 neste ponto)

| Prompt | Ação (`Content.Actions`) | Âncora (TASK-503 §16.5 c) | Leva a | Recusa |
|---|---|---|---|---|
| **Work** (toque, raio 5) | `prep_work` (já existe) | `Prompt_Work`, frente do deck baixo | assento de **esteira** livre (1, depois 2) | `NoPlate` sem prato não montado na mão e sem prato parado; `BeltFull` com os 2 assentos tomados |
| **Grill** (toque, raio 5) | `prep_grill` (**nova**, texto "Grill") | `Prompt_Grill` (a reserva da 503 vira âncora fixa) | assento de **grelha** (3) | `GrillBusy` com o assento ocupado |

- O prompt escolhe o assento; o que está na mão não decide mais nada (a antiga P3 cai). Com prato na mão o jogador pode
  entrar na grelha: o prato fica na mão.
- `prep_work` com prato **parado** do mesmo jogador na esteira (§2.3) retoma esse assento e esse prato, mesmo com outro
  prato na mão (o da mão fica na mão). Sem prato parado, o prato da esteira é o `plate` **equipado**; sem equipado, o de
  ticket mais antigo do inventário. Hot dog já montado não entra (`PlateDone`).
- `PrepGrill` só é aceito do assento 3 (a antiga P5 cai: o montador não grelha da parada 1).
- `PrepEnter { Station }` (dev e cliente antigo) continua: o `Station` é pedido e passa pelas mesmas regras de cada prompt.
- Entrar: igual ao trailer (`Freeze`, `Working = n`, `PivotTo` no pé do assento, `PrepResult Enter`). No assento de
  esteira o prato sai da mão e vai para a esteira (§3.2, §6.1); nenhum prato novo é criado (DEC-304).
- Os outros `Prompt_Work` do mapa seguem silenciados (`SilenceSpareWork`); `Prompt_Grill` é uma âncora à parte.

### 2.3 Sair, desmaiar, anomalia, desconexão: o prato fica parado na esteira

Regra nova (pedido do dono para o solo; **Provisória P24**, recomendação do orquestrador): ao sair do assento de esteira
com o jogador ainda no servidor, o prato **não montado** fica **parado na esteira**, na parada (ou espera) onde estava, com
a reserva mantida. O registro do assento continua com o mesmo `User` e ganha `Away = true`; o assento fica guardado para
esse jogador (ninguém mais senta nele).

| Saída | Prato não montado fora de `Out` | Prato em `Out` (com ou sem nota) | Grelha (assento 3) |
|---|---|---|---|
| `PrepLeave` (Leave) | **parado na esteira**, reservado (`Away = true`) | volta **à mão**, equipado; assento e parada liberam | só libera; as salsichas seguem cozinhando |
| Fim automático depois do Finish (`DoneHold`) | — (o Finish já levou o prato a `Out`) | volta **à mão** | — |
| Saída forçada `Kick*` (sinal de anomalia, sanidade, `Down`, cutscene, ligação, ladrão, `Idle`) | **parado na esteira** (mesma regra do Leave); `KickSignal` mantém o `CueLock` de 6 s | volta à mão | idem |
| `KickClosing` (a venda acabou) | volta **à mão** | volta à mão | idem |
| `KickAway` ou desconexão (`Release(silent)`) | vai para a **vaga livre da mesa central** com ticket e conteúdo (§7.3 garante vaga) | idem | idem |
| Parado há mais de `Conveyor.ParkMax` (120 s, **Provisória P25**) | vai para a mesa central; o assento libera | — | — |
| Fim do turno (`ShiftStarted` seguinte) | `PlateService:Clear()` apaga pratos e tickets (como hoje) | idem | — |

- Prato parado: continua dono da parada (`Wait = 0`) ou da espera onde estava; o outro montador passa ao lado e é
  promovido quando ela liberar (§4). Ao voltar pelo `prep_work`, o jogador retoma o prato do ponto em que estava
  (`Away` sai).
- Para levar um prato pela metade de volta à mesa: seta até `Out` e sair (vai à mão), depois clicar numa vaga.
- O `Parked` da TASK-260 (prato na tábua do trailer) não é usado: no modo esteira o "parado" é o registro do assento.
  (P4 aceita, agora com esta forma.)
- Claims de `PrepGrab` do jogador caem na saída (já é assim). Nada de estoque é devolvido: pão e salsicha já entraram no
  prato no commit da etapa (§6.5).

### 2.4 Caso solo (DT-E3, revisto)

Um jogador sozinho fecha um pedido assim (Decidido pelo dono: sai da esteira, usa o prompt da grelha e volta):

1. Pega o prato vazio na mesa central (segurar E) e entra pelo **Work**: o prato carrega na parada 1.
2. Leva o prato à Tábua e corta o pão.
3. Sai (Leave): o prato fica **parado e reservado** na Tábua (§2.3).
4. Entra pelo **Grill**, põe a salsicha (pronta sozinha em 8/6/4 s, vai ao descanso, §5), sai.
5. Entra pelo **Work**: retoma o prato na Tábua, arrasta a salsicha do descanso para o pão, segue aos Condimentos, desenha,
   recebe a nota; o prato vai a `Out` e volta à mão.

Também vale grelhar antes de pegar o prato (Grill → mesa central → Work). Nada trava: o prato parado não expira antes de
`ParkMax`, e a salsicha pronta espera no descanso ou na grelha sem queimar.

---

## 3. Posição do prato por jogador

### 3.1 Paradas (DT-E4)

`Content.Prep.Conveyor.Stops` (ordem = esquerda → direita da fala do dono; a TASK-503 confere o ponto de vista):

| Parada | Chave | Etapa aberta | Reservável | Âncoras (nomes da TASK-503 §16.5 a) | Vista (câmera de parada) |
|---|---|---|---|---|---|
| 1 | `Grill` | entrada; grelha e mesa de descanso à vista em cima (o montador não grelha daqui) | sim | `Stop_1`; espera `WaitL_1` / `WaitR_1` | `Rest` |
| 2 | `Board` | pão (cortar arrastando) + montar (arrastar a salsicha do descanso ao pão) | sim | `Stop_2`; `WaitL_2` / `WaitR_2` | `Board` |
| 3 | `Toppings` | condimentos (desenhar o padrão) + **Finish** (nota) | sim | `Stop_3`; `WaitL_3` / `WaitR_3` | `Toppings` |
| 4 | `Out` | saída: nada a fazer; o foco termina | **não** (cabe os 2) | `Stop_4` (sem espera) | — |

Câmera larga da bancada: `CamAnchor_Belt`/`Focus_Belt`; grelhador: `CamAnchor_Grill`/`Focus_Grill`. As âncoras ficam
na bancada (`BENCH2`/`Mount_Belt`), não por assento. **Aceita (dono) P6** (paradas e o que cada uma faz; bate com a TASK-503,
a TASK-508 e a TASK-520: corte e montagem na parada do meio).

### 3.2 Carga do prato na esteira

Ao entrar no assento de esteira, o prato carrega na **parada 1** (`Stop_1`); ocupada → espera em `WaitL_1` (ao lado,
na frente da grelha). Vale para prato vazio e para prato já começado (pão e/ou salsicha); prato já com nota não entra
(`PlateDone`). **Aceita (dono) P7** (igual à TASK-503 e à TASK-508; alternativa: carregar direto na 1ª parada com trabalho).

### 3.3 Regra das setas

- Packet `PrepBelt { Dir = "Left" | "Right" }`: **uma parada por toque**, só o **próprio** prato (o servidor nunca aceita
  mover o prato de outro assento: o packet nem tem campo de alvo). Decidido: setas movem só o próprio prato (Q-379 A).
- `Left` = parada − 1 (rumo à grelha, a esquerda do cozinheiro, leste no MAP-01), `Right` = parada + 1; preso em 1..4 (na ponta não faz nada: `PrepResult Belt` com `Ok = false`, `Reason = Invalid`).
- Alvo livre → o prato vai para lá (`Wait = 0`). Alvo ocupado por outro prato → o prato fica **ao lado** do alvo, do lado
  de onde veio (`Wait = 1` esquerda / `2` direita, `WaitL_n` / `WaitR_n`), e entra sozinho quando a parada liberar.
  Decidido: o 2º espera ao lado, sem empurrar (Q-380 A).
- Um prato esperando pode seguir com outra seta (passa ao lado da parada ocupada); nunca há dois pratos na mesma parada
  reservável com `Wait = 0`.
- **Seta direita na parada 3** com pão e salsicha no prato: o cliente manda `PrepFinish` (é o "Done", TASK-508) em vez de
  `PrepBelt`. Finish aceito → o servidor move o prato sozinho para `Out` (4), liberando a parada, e o foco termina em
  `Rules.DoneHold`. Sem pão ou salsicha, a seta direita é um `PrepBelt` comum e o prato sai em `Out` sem nota (o foco
  termina e o prato volta à mão como está). **Aceita (dono) P8.**
- Ritmo: `Content.Prep.Conveyor.Rates.Belt = 6` por segundo por jogador (Provisório). O cliente anima a ida em ≤ 0,4 s
  (TASK-518) e pode prever o passo; a verdade é o registro do set.

### 3.4 Onde fica a posição: extensão do `PrepSeats` (DT-E5)

Sem set novo. O registro do assento ganha quatro campos opcionais (escreve só o `PrepService`):

| Campo | Tipo no fio | Valor |
|---|---|---|
| `Stop` | `optional(int(0, 15))` | parada 1..4 do prato desse assento; nil/0 = sem prato na esteira (assento de grelha, ou trailer) |
| `Wait` | `optional(int(0, 2))` | 0/nil = na parada; 1 = esperando à esquerda dela (`WaitL_n`); 2 = à direita (`WaitR_n`). Lado no fio para quem entra tarde desenhar certo |
| `Line` | `optional(int(0, 2))` | linha do ticket (1 líder, 2 parceiro de dupla, FEAT-038); 0/nil = única |
| `Away` | `optional(bool)` | true = o dono saiu e o prato está **parado e reservado** (§2.3); o assento é dele; nil/false = sentado |

Campos que já existem e passam a valer na esteira: `User` (quem), `Ticket` (= NpcId do ticket **do prato**, não mais
"fixado"), `Step` (= aba da parada atual: `Grill`, `Board`, `Toppings`; `Out` usa `Toppings`), `Plate` (máscara do
conteúdo: o servidor escreve os bits de pão e salsicha no commit da etapa e aceita do cliente só os bits de topping que
crescem, como hoje), `Since`.

- Máximo de registros: **3** no modo esteira, 4 no trailer. Abaixo de 8, sem risco de `drop.section`; o registro já é
  largo (`User` e `Since` são `f64`).
- Taxa: uma escrita por seta aceita, uma por commit de etapa, uma por promoção de quem esperava. Pior caso (2 montadores
  martelando setas) ≈ 12 escritas/s no set; típico < 1/s. Cada escrita manda só o campo mudado (`Stop`/`Wait`, ~1 byte).
- Por que estender o `PrepSeats` e não um set `Belt` novo: o registro é por assento e o prato é 1:1 com o assento; os
  clientes (StationTag, `Mates`, `Ghost`) já leem esse set; um set novo seria um 2º lugar com a mesma chave. E cada entrada
  nova no `define` "game" pesa no orçamento de tipos do LuauSolverV2 (§9.3).

---

## 4. Reserva de estação

- **Uma reserva por parada reservável** (1, 2, 3). O dono da reserva é o assento cujo prato está na parada com
  `Wait = 0`. `Out` não reserva. Decidido: cada estação atende um prato por vez (Q-380 A).
- **Quem libera e quando** (sempre o `PrepService`, na mesma chamada síncrona):
  - o prato sai da parada por seta;
  - o Finish aceito move o prato para `Out` (P8);
  - o prato sai da esteira: à mão (`Out`, `KickClosing`) ou à mesa (desconexão, `ParkMax`). Prato **parado** (§2.3) mantém a reserva;
  - o prato vai ao lixo inteiro? **Não**: a lixeira esvazia o prato e ele **fica** na parada (§6.6).
- **Promoção:** ao liberar a parada `s`, se o outro prato está com `Stop = s` e `Wait ≠ 0`, ele vira `Wait = 0` na
  mesma chamada (uma escrita no set). Com no máximo 2 pratos não existem 2 esperando na mesma parada.
- **Desempate no mesmo tick:** não existe "mesmo instante" no servidor. Os responders do Lync rodam um por vez, na ordem
  em que os pacotes chegaram no flush; checagem e escrita são síncronas (sem `yield`). O primeiro processado reserva; o
  segundo fica esperando ao lado (`Wait ≠ 0`). Igual ao `PrepEnter` de hoje. (A regra "empate = ticket menor" da TASK-508
  nunca chega a valer: não há empate real no servidor.)
- **Trabalho só com reserva:** `PrepStage` e `PrepFinish` exigem o prato na parada certa com `Wait = 0` (senão
  `WrongStop`); `PrepGrill` só do assento 3 (§2.2).
- Módulo puro novo `src/Prep/server/PrepService/Belt.luau` (TASK-514), sem Modux/Lync/Instance, com teste de tabela:

```
Belt.new(stops: { BeltStop }) -> Belt
Belt.load(belt, seat: number, stop: number) -> (stop: number, wait: number)          -- wait 0 / 1 (esquerda) / 2 (direita)
Belt.move(belt, seat: number, dir: "Left" | "Right") -> (ok: boolean, stop: number, wait: number, promoted: number?)
Belt.leave(belt, seat: number) -> promoted: number?        -- tira o prato da esteira; devolve o assento promovido
Belt.finish(belt, seat: number) -> promoted: number?       -- move para Out (P8)
Belt.at(belt, seat: number) -> (stop: number?, wait: number)
Belt.canWork(belt, seat: number, stopKey: string) -> boolean
```

---

## 5. Mesa de descanso compartilhada

- **É o rail que já existe** (`Kitchen/Stations/Rail.luau`, `Stations` kind `rail`, `RailSlot`, `PrepClaims` com
  `From = Rail`). Nenhuma estrutura paralela (DT-E6). No MAP-01 o rail é a peça "mesa de descanso" ao lado da grelha
  (nomes de âncora com a 503/504; `Rail_<n>` como hoje).
- **Capacidade:** `Content.Prep.Conveyor.Rest.Capacity = 8` (= `Vehicles.trailer.RailSlots`; teto do fio `PrepGrab.Slot`
  1..8). **Aceita (dono): 8 salsichas.**
- **Estoque compartilhado:** qualquer montador pega qualquer salsicha do descanso. **Ordem de pegar:** qualquer posição livre
  (sem claim de outro); o cliente sugere a da frente (mais antiga). **Aceita (dono) P10.** Fluxo: o arrasto começa com
  `PrepGrab { From = Rail, Slot = n, On = true }` (claim, já existe) e termina com `PrepStage { Stage = Dog, Slot = n }`;
  o servidor tira **aquela** posição (`Rail.PopAt(n)`, função nova da 515) e reindexa os claims (`SausageLeft`, já existe).
- **Grelha no modo esteira** (TASK-515; Decidido Q-381 A: sem queimar, virar opcional com bônus, sem barra):
  - a salsicha fica pronta sozinha em `GrillTime` = **8 / 6 / 4 s** pelo nível do UPG-001 (Decidido pelo dono; são os
    valores que `Upgrades.luau` já tem), sem a pausa de "esperar virar" do trailer;
  - **virar** é opcional e só vale enquanto cozinha; virar dentro da janela `Restaurant.Grill.FlipFrom..FlipTo` (40% a
    60%, relógio do servidor) carimba `Flip = true` na salsicha;
  - pronta, ela vai **sozinha** para o fim da fila do descanso (sem "Collect"). **Aceita (dono) P11** (alternativa: tocar
    para mandar);
  - **descanso cheio:** a pronta fica na grelha em `Ready`, sem queimar, e desce sozinha quando abre lugar (ordem: a que
    ficou pronta primeiro). `PrepGrill Place` continua aceito enquanto houver vaga livre na grelha. **Aceita (dono) P12.**
- **Carimbo do bônus de virar:** a entrada do rail ganha `Flip: boolean` ao lado do `Score` que já existe
  (`Entry = { At, Altered, Score?, Flip? }`). No `PrepStage Dog` o carimbo passa ao prato (`FlipBonus`, §6.3). O bônus é
  pago uma vez por prato, na venda (TASK-517; valor `Content.Prep.Conveyor.Grill.FlipBonus`, Provisório $1).
- **Nota da salsicha fora da nota do prato:** no modo esteira a salsicha não entra em `Grade.Plate` (não virar não pode
  virar Messy: virar é opcional). A nota do prato = corte + montagem + condimentos (Q-382). `Grades.Unflipped` fica só no
  trailer. **Aceita (dono) P13.**
- Set `Stations` sem mudança de schema: a grelha segue com `State`/`StartedAt`/`Duration`/`Flip`; o rail com `Count`.
  `Burnt` nunca é escrito no modo esteira.

---

## 6. O prato: nasce pelo ticket, viaja entre mesa, mão e esteira

### 6.1 Um prato = uma linha de ticket (DT-E7)

O prato é um objeto **lógico** do servidor, dono único **`PlateService`** (registro de pratos). Ele existe em exatamente
uma de três formas ao mesmo tempo:

| Forma | Onde aparece para os clientes | Quem segura |
|---|---|---|
| `Table` | registro da vaga no set `Plates` | `PlateService` |
| `Hand` | Tool no inventário do jogador (`plate` ou `hot_dog`) | `ItemService` (Tool) + `PlateService` (estado) |
| `Belt` | registro do assento no `PrepSeats` (`Stop`, `Plate`, `Ticket`) | `PrepService` (posição) + `PlateService` (estado) |

Toda passagem entre formas é uma chamada síncrona do `PlateService` (§10): nunca há o mesmo prato em duas formas nem
nenhuma. Isto é o que torna testável "pôr/pegar não duplica nem some prato" (contagem `PlateService:AliveCount()`).

### 6.2 Nascimento (Decidido: DEC-304)

- Gatilho que já existe: `CustomerService.Acted(id, "take_order")` (o tablet chama `TakeOrderFor` no fim da fala) →
  `PlateService:Assign(npc)`. A TASK-516 só troca o que o `Assign` faz: **cria um prato vazio com o ticket** (uma por linha
  de dupla) numa vaga livre da mesa central. O `TabletService` não ganha chamada nova; continua consultando
  `PlateService:HasRoomFor(npc)` antes da fala.
- Vaga escolhida: a livre de **maior** índice (leste, perto do tablet e da entrada da esteira; TASK-503 §16.5 d). Antes de criar um prato novo, um prato **órfão já montado** que sirva ao pedido
  (`Slots.fits`) adota o ticket (regra `OrphanReuse`/`PreppedFirst` que já existe). **Aceita (dono) P14.**
- Mesa cheia: **o tablet não toma o pedido** ("Kitchen full", lâmpada `Full`), como já é hoje. Provisório na própria
  DEC-304; a contagem muda (§7.3).

### 6.3 Atributos do prato-Tool (DT-E8)

Item novo **`plate`** em `Content.Items` (Category `HotDog`, `Stackable = false`, `DropOnHit = "Keep"`, `KeepOnSpectate =
false`, `Use = false`): o prato **não montado** na mão. O prato **montado** (Finish aceito) vira `hot_dog`, para que
venda, `HotDogVisual`, bandeja e lixeira sigam o caminho de hoje. Os dois na categoria `HotDog`: **máx. 2 pratos na mão**
(Decidido: DEC-299, `CategoryLimits.HotDog = 2`). **Aceita (dono) P15** (item novo em vez de `hot_dog` vazio).

| Atributo | Tools | Tipo | Escreve | Uso |
|---|---|---|---|---|
| `Item` | ambos | `"plate"` / `"hot_dog"` | `ItemService` | já existe |
| `PlateId` | ambos | int | `PlateService` | chave do registro do servidor (o cliente só lê) |
| `Ticket` | ambos | int (NpcId) | `PlateService` | já existe no `hot_dog`; HUD do ticket e `PICKUP` |
| `TicketLine` | ambos | int 1..2 | `PlateService` | qual pedido da dupla (Order / Order2) |
| `Orphan` | ambos | bool | `PlateService` | o cliente do ticket foi embora (HUD mostra "?") |
| `Bun` | `plate` | bool | `PlateService` | pão cortado no prato |
| `Dog` | `plate` | bool | `PlateService` | salsicha no prato |
| `Toppings` | ambos | string (como §7.1 de `network.md`) | `PlateService` / `ItemService` | já existe no `hot_dog` |
| `Quality` | `hot_dog` | `"Perfect"`/`"Good"`/`"Messy"` | `ItemService` | **é a "Grade" da TASK-512**: o nome que já existe |
| `FlipBonus` | ambos | bool | `PlateService` | bônus de virar a pagar na venda (517) |
| `Sauce` | `hot_dog` | string | `ItemService` | já existe (linha desenhada) |
| `Altered` | ambos | bool | `ItemService` | já existe (ANM-002) |

Notas, cortes e o relógio do prato (`Cut`, `Place`, `StartedAt`) ficam **só no registro do servidor**, nunca no Tool.
O `plate` não entra no snapshot da run (como o `Ticket`, que o `Stash` já ignora). **Aceita (dono) P16.**

### 6.4 Ticket no HUD (Decidido: DEC-304)

Sem rede nova. O cliente lê o Tool **equipado** (`Ticket`, `TicketLine`, `Orphan`) e o set `Customers` (`Number` = #n,
`Order`/`Order2`). Com 2 pratos, mostra o do equipado (Provisório na DEC-304). Dentro do foco da esteira o ticket vem do
`PrepSeats.Ticket`/`Line` do próprio assento. Componente: `PlateController/TicketHud` (TASK-522), na posição do `HudOrder`.

### 6.5 Etapas e commits (DT-E9)

Cada etapa grava no prato no momento em que acontece (o prato é visível para todos e pode sair da esteira pela metade):

| Etapa | Packet | Parada | Exige | Servidor faz (síncrono, tudo ou nada) |
|---|---|---|---|---|
| Cortar o pão | `PrepStage { Stage = Cut, Score, Slot = 0 }` | 2 | `Bun = false` | `TakeStock(bun, 1)` (ou adota pão alterado); `Bun = true`, guarda `Cut = Score`, `StartedAt = agora` |
| Pôr a salsicha | `PrepStage { Stage = Dog, Score, Slot = n }` | 2 | `Bun = true`, `Dog = false`, salsicha na posição `n` sem claim de outro | `Rail.PopAt(n)`; `Dog = true`, `Place = Score`, `FlipBonus = entrada.Flip`, `Altered` se for o caso |
| Condimentos + nota | `PrepFinish` (já existe) | 3 | `Bun` e `Dog`, sem nota | valida (`Validate.Summary`, `Grade.Plausible` com relógio desde `StartedAt`), `TakeStock` de cada topping, `Grade.Plate(Cut, Place, Toppings)` → banda; grava `Toppings`, `Grade`, `Sauce`; move para `Out` |

- No modo esteira o servidor **ignora** `PrepFinish.Cut` e `.Place` (usa os que guardou) e não cria Tool no Finish: o
  `hot_dog` é criado quando o prato volta à mão (§6.7). `PrepBegin` fica sem uso no modo esteira (recusa `Invalid`).
- Etapa recusada não muda nada (estoque, rail, prato). Recusas: `NoStock`, `NoSausage`, `Held`, `WrongStop`, `Invalid`.
- Pedido sem complemento (K = 0) também passa pelo Finish (nota de corte + montagem).

### 6.6 Lixeira

`PrepTrash { From = Plate }` com prato na esteira: pão, salsicha, toppings e nota se perdem; o prato **continua** na
esteira, vazio, com o mesmo ticket (o pedido não some). `From = Grill`/`Rail` como hoje. **Provisória P17.**

### 6.7 Volta à mão

`PlateService:Giveback(player, id)` cria o Tool da forma certa (`plate` sem nota, `hot_dog` com nota: `ItemService:Give`
com `Toppings`, `Quality`, `Altered`, depois `Sauce` e os atributos da tabela §6.3), equipa e marca `Hand`. Sempre cabe: o
prato saiu da mão ao entrar na esteira e o jogador congelado não pegou outro.

---

## 7. Mesa central: início e fim do fluxo

### 7.1 Set `Plates` (já existe, `Net/Restaurant.luau`)

Registro = vaga **1..8** (`Content.Restaurant.CenterTable.Slots = 8`, Decidido Q-383 A; fio já aceita 1..12). As 8 vagas são
sempre ativas no modo esteira, um registro por vaga, sempre publicado (vaga livre = `Npc = 0` e sem `Orphan`); o teto por
party vale para os tickets (§7.3), não para as vagas. Campos que já existem: `Npc` (ticket), `Line`,
`Bun`, `Sausage`, `Toppings`, `Since`, `Orphan`, `Altered`. **Campo novo:** `Grade = optional(enum(Content.Prep.GradeKeys))`
(nil = não montado; `Perfect`/`Good`/`Messy` = montado com nota). Estado da vaga para o cliente:

| Estado | Regra |
|---|---|
| livre | `Npc == 0` e `Orphan ~= true` |
| prato vazio com ticket | `Npc ~= 0`, `Bun == false`, `Sausage == false` |
| em montagem | `Bun` ou `Sausage`, `Grade == nil` |
| montado | `Grade ~= nil` |
| órfão | `Orphan == true` (`Npc = 0`; só fica se tiver conteúdo, §7.6) |

### 7.2 Pegar e pôr

- **Pegar = segurar E** no prompt `plate_take` (`Prompt_Take` da vaga, `Hold` 0,5 s, Provisório). Validate: vaga com prato,
  jogador ativo, `ItemService:CanGive(player, "plate")` (categoria `HotDog` < 2; senão `hands_full`). Run:
  `Table → Hand`. Quem pode pegar: **qualquer jogador ativo** (**Aceita (dono) P18**).
- **Pôr = clicar/tocar na vaga livre** → packet `CenterPut { Slot }` (c → s, `Net/Restaurant.luau`, responder
  `PlateService` no `OnInit`). Servidor: jogador ativo, a até `CenterTable.Reach` studs da vaga (12, Provisório), vaga
  ativa e **livre**, o Tool **equipado** é `plate` ou `hot_dog` com `PlateId`. Run: `Hand → Table`. Vaga ocupada →
  Notice `slot_taken`; o cliente nem manda pacote se a vaga já aparece ocupada (TASK-522). No gamepad o mesmo packet vai
  com a vaga livre mais perto do personagem (o cliente escolhe). **Aceita (dono) P19.**
- **Dois jogadores segurando E na mesma vaga:** o `InteractionService` roda os `Run` um por vez; o primeiro leva, o segundo
  falha no `Validate` ("vaga vazia") e recebe Notice `plate_gone`. **Dois cliques na mesma vaga livre:** o primeiro
  `CenterPut` processado põe; o segundo recebe `slot_taken`. Sem trava extra.

### 7.3 Contagem e "Kitchen full" (DT-E10)

`PlateService:AliveCount()` = pratos em qualquer forma. Gate do tablet (`HasRoomFor`): `AliveCount() + linhas do pedido <=
TicketCap()`, com `TicketCap = min(Restaurant.Rules.ActivePlates[party], CenterTable.Slots)` (4/6/8/8, FEAT-044; no modo
esteira substitui o `ActiveCount` de hoje, que a TASK-506 remove).
Consequência: **sempre há vaga livre para devolver um prato** (pratos vivos ≤ vagas), então a desconexão (§2.3) e o "pôr"
nunca ficam sem lugar. **Provisória P20** (usar `ActivePlates` por party como teto de tickets; a alternativa é 8 fixo).

### 7.4 Ligação no mapa

`PlateService` liga `CenterSlot` (não mais `PlateSlot`) quando `Prep.Rules.Mode == "Conveyor"`. Nomes da TASK-503
§16.5 d, dentro do Model `CENTER`:

| Chave (`Content.Restaurant.Binding`) | Valor | Peça |
|---|---|---|
| `CenterModel` | `"CENTER"` | a mesa |
| `CenterTag` | `"CenterSlot"` | tag posta pela 504 em cada `Click_Slot_n` (caixa invisível 2,2 × 1,0 × 2,2): **alvo do clique** |
| `CenterIndex` | `"CenterIndex"` | atributo 1..8 no `Click_Slot_n` |
| `CenterMount` | `"Mount_Plate_%d"` | onde o cliente desenha o prato da vaga |
| `CenterTake` | `"Prompt_Take"` | Attachment filho do `Click_Slot_n`, no centro do prato + 0,4 (prompt **fixo** na vaga, não no modelo do prato) |
| `CenterTicket` | `"Att_Ticket"` | BillboardGui do #n sobre a vaga |

As peças `PLATE-n` da passa deixam de ser ligadas (viram cenário; a 504 decide se tira a tag `PlateSlot`).

### 7.5 Do fim da esteira à mesa ou ao PICKUP

Depois do Finish o prato vai a `Out` e o foco termina sozinho em `DoneHold` (ou no Leave): o `hot_dog` volta à mão
(§6.7). Daí o montador **clica numa vaga livre** (fica na mesa para outro entregar) **ou** anda até o `PICKUP`
(Decidido: DEC-304). Um prato em montagem também pode ser devolvido à mesa (sai do foco, clica na vaga).

### 7.6 Cliente que foi embora (ticket órfão)

`CustomerService.Left`/`Removed` → `PlateService:Release(npc)` (já existe): em qualquer forma o prato vira órfão
(`Orphan = true`, `Npc = 0` no set; atributo `Orphan` no Tool; `PrepSeats.Ticket = 0`). Prato órfão **vazio** some (na
mesa: a vaga libera; na mão: o Tool é consumido; na esteira: o assento fica sem prato e o foco termina). Prato órfão com
conteúdo fica e pode ser adotado por um pedido novo que ele satisfaça (§6.2) ou jogado fora. **Aceita (dono) P21.**

Perda do prato por fora (lixeira BIN-C com hot dog na mão, `ClearAltered` no fim da noite): o Tool destruído fora do
`PlateService` encerra o prato; se o cliente do ticket ainda espera, nasce **um prato vazio novo** com o mesmo ticket numa
vaga livre (o pedido não fica sem prato). **Aceita (dono) P22.**

---

## 8. PICKUP

- Prompt `pickup_serve` ("Hand Over") com **segurar** (`Hold` 0,5 s, Provisório) no `PICKUP` (Decidido: DEC-302 "a entrega
  no pickup é igual: ProximityPrompt segurando o prato").
- O prato é o `hot_dog` **equipado** (sem equipado: o primeiro `hot_dog` com `Ticket` do inventário, como hoje).
- **Entrega só ao dono do ticket** (Decidido: Q-383 A): `Pickup.choose` passa a aceitar só `TicketOwner(tool)`, e só se esse
  cliente está na fila de retirada em `Waiting`. Caem os ramos "oldest exact", "target" e "PU-1" no modo esteira.
- Recusas (Notice, nada muda): `plate` não montado na mão → `plate_not_ready`; ticket de cliente que não está na retirada
  → `ticket_other`; prato órfão → `ticket_gone` (devolva à mesa; §7.6).
- Veredito, pagamento, gorjeta e `Sale` seguem o `ServeCustomer` (DEC-072). Hot dog que não bate com o pedido (Errado)
  segue a regra de hoje. Venda feita: `CustomerService.Acted(id, "serve")` → `PlateService` encerra o prato (registro sai).
- Gorjeta da nota (TASK-517): `Quality = Perfect` paga a gorjeta base **+ $1** (`Grades.Effects.Perfect.TipExtra = 1`,
  Decidido pelo dono; substitui o `Tip = 2` fixo no modo esteira); `FlipBonus`
  soma `Conveyor.Grill.FlipBonus` uma vez por prato.

---

## 9. Rede: pacotes e Sets

Detalhe completo (direção, campos, escritor, leitor, ritmo, arquivo) em `docs/tech/network.md` §19. Resumo:

### 9.1 `src/Libs/Net/init.luau` (namespace "game", Prep)

| Entrada | Tipo | Mudança |
|---|---|---|
| `PrepBelt` | packet c → s | **novo**: `{ Dir = enum(Content.Prep.BeltDirs) }` |
| `PrepStage` | packet c → s | **novo**: `{ Stage = enum(Content.Prep.BeltStages), Score = int(0, 100), Slot = int(0, 8) }` |
| `PrepSeats` | set | **+** `Stop`, `Wait`, `Line`, `Away` (opcionais) |
| `PrepResult` | packet s → dono | sem schema novo; `Content.Prep.Acts` ganha `Belt`, `Stage`; `Reasons` ganha `NoPlate`, `BeltFull`, `GrillBusy`, `WrongStop`, `PlateDone` |
| `PrepEnter`, `PrepLeave`, `PrepTab`, `PrepGrill`, `PrepFinish`, `PrepTrash`, `PrepGrab`, `PrepClaims`, `PrepPointer`, `PrepGhost` | — | sem mudança de schema; regras do modo esteira no §2 a §6 |
| `PrepBegin`, `PrepOrder` | — | sem uso no modo esteira (recusa `Invalid` / `Locked`) |

### 9.2 `src/Libs/Net/Restaurant.luau` (namespace "restaurant", mesa central)

| Entrada | Tipo | Mudança |
|---|---|---|
| `Plates` | set | **+** `Grade = optional(enum(Content.Prep.GradeKeys))`; registro = vaga 1..8 da mesa central |
| `CenterPut` | packet c → s | **novo**: `{ Slot = int(1, 12) }` |
| `Tablets`, `DriveCars`, `Supply`, `Hatch` | — | sem mudança |

### 9.3 Regras para a TASK-513

- `keyBy`: nenhum. Os campos novos são enums/ints/bools pequenos dentro de registros largos.
- `drop.section`: `PrepSeats` ≤ 4 registros; `Plates` ≤ 12 registros com `Npc` de 16 bits e `Since` `f64`. Nenhum risco.
- Orçamento de tipos do LuauSolverV2: o `define` "game" já esteve no limite ("too complex to typecheck", comentário de
  `Net/Restaurant.luau`). Os structs novos (`PrepBelt`, `PrepStage`, o registro de `PrepSeats`) são montados **fora** da
  tabela do `define` em funções locais (padrão `cutsceneRecord`). Se mesmo assim o analisador recusar, as duas entradas
  novas de Prep vão para um namespace próprio `src/Libs/Net/Belt.luau` ("belt"), requerido pelo `init.luau` como o
  `Restaurant`. **Aceita (dono) P23** (decisão do implementador da 513, registrada no relatório dela).
- Nenhum Remote fora do Lync. Clique e prompts de segurar não criam pacote além de `CenterPut` (o resto é `Interact`).

---

## 10. Assinaturas entre serviços

Prioridades e `Require` (sem ciclo; `architecture.md`: ciclos proibidos):

| Serviço | Prioridade | `Require` novo | Por quê |
|---|---|---|---|
| `PrepService` | 645 | **+ `PlateService`** | pegar o prato da mão ao entrar, devolver ao sair, gravar etapas |
| `PlateService` | 566 | nenhum (`ItemService`, `CustomerService`, `InteractionService` já estão) | não conhece o Prep |
| `KitchenService` | 650 | nenhum | segue dono de estoque, grelha e rail |
| `TabletService` | 564 | nenhum | segue chamando `PlateService:HasRoomFor` |
| `CustomerService` | 590 | nenhum | `PlateService` escuta `Acted`/`Left`/`Removed` (já faz) |

`PlateService` não requer `PrepService` (seria ciclo): o que ele precisa saber da esteira chega pelas chamadas do
`PrepService`.

### 10.1 `PlateService` (TASK-516 implementa; TASK-514 chama)

```lua
export type PlateForm = "Table" | "Hand" | "Belt"
export type PlateState = {
	Id: number,            -- PlateId (atributo do Tool)
	Ticket: number,        -- NpcId, 0 = órfão
	Line: number,          -- 1 | 2
	Since: number,         -- server time do nascimento do ticket
	Bun: boolean,
	Dog: boolean,
	Toppings: { string },
	Grade: string?,        -- "Perfect" | "Good" | "Messy"; nil = não montado
	FlipBonus: boolean,
	Altered: boolean,
	Sauce: string,         -- Sauce.Encode; "" = nenhuma
	Cut: number?,          -- 0..100, gravado no commit Cut
	Place: number?,        -- 0..100, gravado no commit Dog
	StartedAt: number?,    -- os.clock() do commit Cut (relógio de plausibilidade)
	Form: PlateForm,
	Slot: number?,         -- vaga (Table)
	Holder: Player?,       -- Hand / Belt
}
export type PlatePatch = {
	Bun: boolean?, Dog: boolean?, Toppings: { string }?, Grade: string?, FlipBonus: boolean?,
	Altered: boolean?, Sauce: string?, Cut: number?, Place: number?, StartedAt: number?,
}

PlateService:Of(id: number): PlateState?                             -- cópia congelada
PlateService:WorkablePlate(player: Player): PlateState?              -- prato `plate` da mão pela regra do §2.2
PlateService:Borrow(player: Player, id: number): PlateState?         -- Hand -> Belt; tira o Tool sem vender; nil = não é dele
PlateService:Commit(id: number, patch: PlatePatch): boolean          -- só na forma Belt; publica Tool/set conforme a forma
PlateService:Empty(id: number): boolean                              -- lixeira (§6.6): zera conteúdo, mantém ticket
PlateService:Giveback(player: Player, id: number): Tool?             -- Belt -> Hand (plate ou hot_dog), equipa
PlateService:Shelve(id: number): number?                             -- Belt/Hand -> Table, menor vaga livre; devolve a vaga
PlateService:AliveCount(): number                                  -- pratos em qualquer forma
PlateService:TicketCap(): number                                   -- min(ActivePlates[party], CenterTable.Slots)
PlateService:HasRoomFor(npc: number?): boolean                       -- já existe; passa a contar AliveCount (§7.3)
PlateService.Changed: Signal<number>                                 -- id do prato (dev, QA, Metrics)
```

Já existem e mudam de comportamento: `Assign(npc, lines?)` (cria prato vazio, §6.2), `Release(npc)` (órfão, §7.6),
`Clear()`. Ações registradas: `plate_take` (mesa central, segurar). Responder novo: `CenterPut`.

### 10.2 `PrepService` → `KitchenService` (via `Bridge.luau`, TASK-514 e TASK-515)

`Bridge` continua o único arquivo que conhece a forma dos métodos de outro serviço (serviços como `any`):

```lua
-- novos no modo esteira
Bridge.Cut(kitchen, player): (ok: boolean, reason: string, preCut: boolean)
	-> kitchen:BeginPlate(player, nil, { Belt = true })     -- só o pão (TakeStock ou pão alterado), sem vaga de tábua
Bridge.Dog(kitchen, player, slot: number): (ok: boolean, reason: string, entry: { Score: number?, Flip: boolean, Altered: boolean }?)
	-> kitchen:TakeRest(player, slot)                       -- Rail.PopAt(slot); NoSausage se vazio
Bridge.Toppings(kitchen, player, keys: { string }): (ok: boolean, reason: string)
	-> kitchen:FinishPlate(player, { Toppings = keys, Belt = true })  -- só estoque dos toppings, tudo ou nada, sem Give, sem rail
-- sem mudança
Bridge.Grill(kitchen, player, act, slot): Outcome           -- Place / Flip / Collect; no modo esteira a grelha não pausa nem queima
Bridge.TrashSausage(kitchen, player, from, slot)
Bridge.Reason(reason): string
```

- `KitchenService/Plate.luau` (TASK-514): `BeginPlate`/`FinishPlate` ganham a opção `Belt = true` descrita acima; o caminho
  do trailer não muda. `KitchenService:TakeRest(player, slot)` é novo (TASK-515 escreve `Rail.PopAt`; a 514 expõe o
  método em `Plate.luau`). `RefundPlate` não é usado no modo esteira (nada fica reservado).
- `Stations/Grill.luau` (TASK-515) lê `Content.Prep.Rules.Mode == "Conveyor"` para: sem pausa de virar, sem queima,
  `Flip` só carimba bônus, ida automática ao rail com fila de espera quando cheio.

### 10.3 `PrepService` → `PlateService`

| Momento | Chamada |
|---|---|
| `prep_work` / `PrepEnter` em assento de esteira | prato parado do jogador: só retoma o assento (nenhuma chamada); senão `WorkablePlate(player)` → `Borrow(player, id)`; nil = recusa `NoPlate` |
| `prep_grill` | nenhuma (o assento 3 não tem prato) |
| `PrepStage Cut` / `Dog` aceito | `Commit(id, { Bun = true, Cut, StartedAt })` / `Commit(id, { Dog = true, Place, FlipBonus, Altered })` |
| `PrepFinish` aceito | `Commit(id, { Toppings, Grade, Sauce })` |
| `PrepTrash Plate` | `Empty(id)` |
| Leave / `Kick*` com o prato fora de `Out` | nenhuma: o prato fica `Belt` (parado, `Away = true`) |
| saída com o prato em `Out`, ou `KickClosing` | `Giveback(player, id)` |
| `KickAway`, desconexão, `ParkMax` vencido | `Shelve(id)` |

`PrepService` guarda só `seat.PlateId` no `Session.Seat` (campo novo; `seat.Plate`/`Parked` ficam para o trailer). O prato
parado vive numa tabela `self.Away[player] = { Seat, PlateId, Since }` do `PrepService`, varrida no tick de 2 Hz para o
`ParkMax`.

### 10.4 `CustomerService` (TASK-516 em `Pickup.luau`, TASK-517 em `init.luau`/`Orders.luau`)

Sem assinatura nova pública. `ServeAtPickup` aplica a regra do §8 quando `Prep.Rules.Mode == "Conveyor"`; a venda lê
`ItemService:QualityOf(tool)` (já existe) e o atributo `FlipBonus` do Tool.

---

## 11. Content: chaves novas e mortas

### 11.1 Novas (TASK-513 grava; todos os números Provisórios)

| Arquivo | Chave | Valor | Leitor |
|---|---|---|---|
| `Restaurant.luau` | `Rules.Enabled` | `true` | todos |
| `Restaurant.luau` | `Switch.PrepEnabled` | `true` (os dois modos) | `Prep.Rules.Enabled` |
| `Restaurant.luau` | `Switch.PrepMode` | `on and "Conveyor" or "Trailer"` | `Prep.Rules.Mode` |
| `Restaurant.luau` | `Switch.WorldKitchenPrompts` | `false` (os dois modos) | `Prep.Rules.WorldKitchenPrompts` |
| `Restaurant.luau` | `CenterTable` | `{ Slots = 8, Reach = 12, PutRate = 4 }` | `PlateService`, `PlateController` |
| `Restaurant.luau` | `Binding.CenterModel/CenterTag/CenterIndex/CenterMount/CenterTake/CenterTicket` | `"CENTER"`, `"CenterSlot"`, `"CenterIndex"`, `"Mount_Plate_%d"`, `"Prompt_Take"`, `"Att_Ticket"` (§7.4) | `PlateService`, `PlateController`, `MapIndex/Required` |
| `Prep.luau` | `Rules.Mode` | `Restaurant.Switch.PrepMode` | todo o `src/Prep`, `Grill.luau`, `KitchenService` |
| `Prep.luau` | `Conveyor.Stops` | linhas `{ Key, Tab, Reserve }`: `Grill/Grill/true`, `Board/Board/true`, `Toppings/Toppings/true`, `Out/Toppings/false` | `Belt.luau`, `PrepController` |
| `Prep.luau` | `Conveyor.Seats` | `{ Belt = { 1, 2 }, Grill = { 3 } }` | `PrepService` |
| `Prep.luau` | `Conveyor.Rates` | `{ Belt = 6, Stage = 2 }` | `PrepService` |
| `Prep.luau` | `Conveyor.ParkMax` | `120` (s: prato parado na esteira antes de ir à mesa central) | `PrepService` |
| `Prep.luau` | `Conveyor.Rest` | `{ Capacity = 8 }` | `Rail.luau`, `PrepService` |
| `Prep.luau` | `Conveyor.Grill` | `{ Burn = false, FlipRequired = false, AutoRest = true, FlipBonus = 1 }` | `Grill.luau`, venda (517) |
| `Prep.luau` | `Conveyor.Binding` | `{ Model = "Mount_Belt", Stop = "Stop_%d", WaitLeft = "WaitL_%d", WaitRight = "WaitR_%d", Seats = { "Seat_Belt_1", "Seat_Belt_2", "Seat_Grill" }, GrillPrompt = "Prompt_Grill", Camera = "CamAnchor_Belt", Focus = "Focus_Belt", Grill = "CamAnchor_Grill" }` | `PrepController`, `BeltMates`, 504 |
| `Prep.luau` | `Views` + linhas `Belt` (larga), `Rest` (parada 1) e `Grill` do grelhador (`CamAnchor_Grill`/`Focus_Grill`); `Board`/`Toppings` já existem | âncoras e números da TASK-503 §16.5 c (`Fov` 70 na larga, 55 nas de parada) | `PrepController` |
| `Prep.luau` | `BeltDirs` | `{ "Left", "Right" }` | `Net PrepBelt.Dir` |
| `Prep.luau` | `BeltStages` | `{ "Cut", "Dog" }` | `Net PrepStage.Stage` |
| `Prep.luau` | `Acts` | + `"Belt"`, `"Stage"` | `PrepResult.Act` |
| `Prep.luau` | `Reasons` | + `NoPlate` (`need_plate`), `BeltFull` (`belt_full`), `GrillBusy` (`prep_busy`), `WrongStop` (silencioso), `PlateDone` (silencioso) | `PrepResult.Reason` |
| `Prep.luau` | `Texts` | + `Left`, `Right`, `BeltFull`, `NoPlate` (textos da 511) | UI |
| `Actions.luau` | `plate_take.Hold`, `pickup_serve.Hold` | `0.5`, `0.5` | `InteractionService` |
| `Actions.luau` | linha `prep_grill` | `Text = "Grill"`, `Hold = 0`, `Radius = 5`, `Requires = { Phase = { "Open", "Closing", "Night" } }` (como `prep_work`) | `PrepService` (registra no `OnInit`), `PromptController` |
| `Prep.luau` | `Grades.Effects.Perfect.TipExtra` | `1` (Decidido pelo dono: gorjeta base + $1) | venda (517) |
| `Items.luau` | linha `plate` | ver §6.3 | `ItemService` |
| `Notices.luau` | `need_plate`, `belt_full`, `slot_taken`, `plate_gone`, `ticket_other`, `ticket_gone` | textos da 511 | servidor |

`Items.luau` e `Notices.luau` não estão na lista de arquivos da TASK-513 no board: entram nela (continuam sendo
`Content/*`, ponto de conflito da 513). O orquestrador ajusta a linha da task se quiser.

### 11.2 Mortas no restaurante (TASK-506 remove sem quebrar o trailer)

`Restaurant.Stacks.Bun`/`Sausage`, `Restaurant.Grill.BurnAfter`/`PickupPerfect`/`PickupGood`, `Restaurant.Bun.CutHold`,
`Restaurant.Rules.FillAllHold`, `Restaurant.Rules.SlotLock`, `Binding.PlateTag`/`PlateIndex`/`PlatePut`/`PlateTake`/`PlateTicket`
(trocadas pelas `Center*`), `Actions.bun_slice`, `Actions.grill_flip`, `Actions.rail_take`, `Actions.plate_put`, os itens
`bun_sliced`/`sausage_grilled` e `CategoryLimits.Ingredient` (sem uso no restaurante e no trailer), o estado `Burnt` do set
`Stations` (fica no fio até a 506 conferir que ninguém lê). `Restaurant.Grill.FlipFrom`/`FlipTo` **ficam** (janela do bônus).

**UPG-016 sai de venda no restaurante** (Decidido pelo dono): sem queima ele não tem efeito. Hoje ele não tem linha em
`Content.Upgrades` (só o comentário de `Restaurant.Grill.BurnAfter`), então a 506 só tira o comentário junto com
`BurnAfter`; se a linha entrar algum dia, ela fica fora da loja com o restaurante ligado (`Switch`). O `Grades.Effects.Perfect.Tip`
fixo fica só para o trailer.

---

## 12. Provisórias que restam

Aceitas pelo dono em 2026-10-18 e fora desta lista: P6, P7, P8, P9 (8 salsichas), P11, P12, P13 e todas as técnicas (P1,
P4, P10, P14, P15, P16, P18, P19, P21, P22, P23 e DT-E1..E10). P3 e P5 **caíram** (dois prompts, §2.2). As antigas Q-a, Q-b
e Q-c estão respondidas e saíram.

| ID | Escolha | Recomendação |
|---|---|---|
| P2 | 1 assento de grelha | perguntar no próximo lote só se o playtest 3–4p mostrar grelha gargalo; até lá fica |
| P17 | Lixeira esvaziando o prato na esteira mantém o ticket | técnica, veto livre (ficou fora da lista aceita; mesma família da P22) |
| P20 | Teto de tickets = `ActivePlates` por party (4/6/8/8), contando pratos em qualquer forma | número, TASK-508 |
| P24 | Sair da esteira (Leave ou `Kick*`, jogador presente) deixa o prato não montado **parado e reservado** na esteira (`Away`); só `Out` e `KickClosing` devolvem à mão | recomendação do orquestrador para o solo; virar Q curta no próximo lote: "o prato parado também bloqueia a parada para o outro montador?" (recomendo sim, como está) |
| P25 | `Conveyor.ParkMax` = 120 s: prato parado além disso vai à mesa central | número, TASK-508 |
| — | Holds de 0,5 s (`plate_take`, `pickup_serve`), `FlipBonus` $1, `Conveyor.Rates`, `CenterTable.Reach` 12 | números, TASK-508 fecha e TASK-506 aplica |
| — | Mesa cheia = o tablet não toma pedido; HUD mostra o ticket do prato equipado | já Provisórias na própria DEC-304; sem Q nova |

## 13. Decisões técnicas propostas (veto livre)

- **DT-E1** Chave dupla por `Switch.PrepMode`; `Prep.Rules.Mode` é o único seletor do modo do Prep.
- **DT-E2** Assentos fixos no modo esteira: 1–2 esteira, 3 grelha; `PrepSeats` sem id novo.
- **DT-E3** Solo por troca de assento (Work → Grill → Work), com o prato parado e reservado na esteira (dono, 2026-10-18).
- **DT-E4** Paradas em `Content.Prep.Conveyor.Stops`; reserva por parada; `Out` sem reserva.
- **DT-E5** Posição do prato como campos opcionais do `PrepSeats` (sem set novo).
- **DT-E6** Mesa de descanso = rail existente (`Rail`, `RailSlot`, `PrepClaims`), com `PopAt` e carimbo `Flip`.
- **DT-E7** Prato lógico com dono único `PlateService` e três formas (Table, Hand, Belt).
- **DT-E8** Item `plate` para o prato não montado; montado vira `hot_dog`; `Quality` é a nota.
- **DT-E9** Commit por etapa (Cut, Dog no `PrepStage`; toppings e nota no `PrepFinish`).
- **DT-E10** Teto de tickets conta pratos vivos em qualquer forma: sempre há vaga para devolver.
