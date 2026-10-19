Status: Rascunho

# Cozinha com esteira: plano de teste (TASK-509)

Autor: qa-tester · 2026-10-18 · Executa: **TASK-510** (Studio, 1 e 2 jogadores, PC e celular 667×375; 4 jogadores na §15).
Fontes, pela ordem de autoridade do `CLAUDE.md`:
1. **DEC-302** (modo focado volta com esteira), **DEC-303** (Q-379 a Q-383, todas A), **DEC-304** (prato nasce na mesa central
   com o ticket; ticket no HUD), **DEC-305** (dois prompts, grelha 8/6/4 s, Perfect = base + $1, UPG-016 fora de venda,
   Provisórias aceitas por padrão).
2. `tech/prep-conveyor.md` (TASK-512, Rascunho, com as "Aceita (dono)") e `tech/network.md` §19.
3. `levels/MAP-01-r4-restaurant.md` §16 (TASK-503), `design/restaurant-flow.md` FEAT-044/045 rev. 3 (TASK-508),
   `design/kitchen-redesign.md` §0 e os critérios da §5 que continuam valendo.
4. Board, tabela "Cozinha com esteira": critérios da **TASK-510** (1) a (10) e os aceites de 513 a 522.

**Regra deste plano: quando dois documentos discordam, o caso mede o que diz a fonte de maior autoridade e a coluna "Nota"
cita a divergência.** A lista completa está na §17; o executor reporta a divergência, não a "corrige" no teste.

> **Estado do código em 2026-10-18 (HEAD `da396b58`).** Nada da onda C existe: `Restaurant.luau:338-359` ainda faz
> `PrepEnabled = not on`; não há `Prep.Rules.Mode`, `PrepBelt`, `PrepStage`, `CenterPut`, item `plate`, `prep_grill`,
> `Belt.luau`, `CenterTable.luau`, `TicketHud.luau`, `/dev belt` nem `/dev center`. Todo caso traz a coluna **Dep.** (TASK
> que precisa estar fechada). Sem a dependência o caso fica **Bloqueado**, não "Falhou". Compilação limpa não fecha nenhum
> caso **M**.

Tipos: **E** estático (diff, grep, leitura de `Content`) · **S** script (`/dev`, Command Bar) · **M** manual no Studio ·
**R** rede (Output, snippets de set, contagem de pacotes) · **V** vídeo (gravar a tela e contar quadros, 60 fps).

Prefixos dos casos: `E` gate estático · `L` layout (conferência da 504) · `CH` chave dupla e um fluxo · `GR` grelha e mesa de
descanso · `PT` prato, mesa central e HUD · `ES` esteira e etapas · `DU` dois montadores · `EN` entrega e contagem · `NT` nota
e gorjeta · `SO` solo · `SA` saídas · `TR` trailer · `CE` celular · `AB` abuso · `BO` bordas · `Q4` 3 e 4 jogadores.

---

## 0. Pré-condições

### 0.1 Ambiente

| # | O quê | Como |
|---|---|---|
| P1 | Chave no repositório | depois da TASK-513: `Content.Restaurant.Rules.Enabled = true` **commitado**; nada editado à mão em `Prep.luau`/`Seating.luau`/`Vehicles.luau` (são derivados; o `Validate` acusa) |
| P2 | Build | `rogen build` → `modux generate` → `modux check` → `powershell tools/analyze.ps1 -Detail` (0 erro, 0 ciclo) → `rojo serve` |
| P3 | Studio | uma sessão por vez (board: não junto com 449/454/465/477/480). Antes: sincronizar as edições à mão do dono no `restaurant_bind.luau`, `Place.diff` = 0, o dono salva. **Nunca `Place.run`** (`AGENT-BRIEF.md` §3) |
| P4 | Jogadores | Test > Clients and Servers: **1**, **2** e **4** clients. Output do servidor e de cada client abertos |
| P5 | Celular | Test > Device: dispositivo personalizado **667 × 375** (paisagem), entrada por toque. Um client em 667×375 e o outro em PC na dupla |
| P6 | Dev mode | `DevService` carregado; atalhos: `/dev tutorial intro`, `/dev day 2`, `/dev skip`, `/dev customer off`, `/dev customer pair ketchup mustard`, `/dev tablet [state\|talk\|finish]`, `/dev pickup [serve\|ticket <npc>]`, `/dev prep grade`, `/dev prep seats`, `/dev smoke`, `/dev debug interact`, `/dev upgrade` (nível da grelha), `/dev trigger <key>`, `/dev sanity <n>`; da **TASK-505**: `/dev belt`, `/dev center`, `/dev plate` |
| P7 | Preparo padrão | `/dev tutorial intro` → `/dev day 2` → `/dev skip` → esperar `Open` → `/dev customer off` → um cliente por vez com `/dev customer pair ketchup mustard` (K = 2, pedido conhecido) |

### 0.2 Snippets de medição (Command Bar)

Os nomes de campo são os do contrato (`prep-conveyor.md` §3.4, §7.1). Se a TASK-513 mudar um nome, ajuste o snippet e anote.

**S1 — prompts ativos (visão Server).** Lista toda âncora `Interactable` com o prompt ligado no servidor:

```lua
local CS = game:GetService("CollectionService")
local n = 0
for _, a in CS:GetTagged("Interactable") do
	if a:IsDescendantOf(workspace) and a:GetAttribute("PromptEnabled") ~= false then
		n += 1
		print(a:GetAttribute("PromptAction"), a:GetFullName())
	end
end
print("ativos:", n)
```

**S2 — log da esteira (visão Client).** Imprime cada mudança de parada dos 3 assentos e acusa 2 pratos na mesma parada:

```lua
local Net = require(game.ReplicatedStorage.shared.Libs.Net)
local last = ""
task.spawn(function()
	for _ = 1, 1200 do -- 2 min
		local parts, seen, bad = {}, {}, nil
		for s = 1, 3 do
			local r = Net.PrepSeats:get(s)
			if r and r.Stop and r.Stop > 0 then
				table.insert(parts, `{s}:{r.Stop}/{r.Wait or 0}{if r.Away then "A" else ""} t{r.Ticket}`)
				if (r.Wait or 0) == 0 and r.Stop <= 3 then
					if seen[r.Stop] then bad = r.Stop end
					seen[r.Stop] = true
				end
			end
		end
		local line = table.concat(parts, "  ")
		if line ~= last then
			print(string.format("%.2f", workspace:GetServerTimeNow()), line, if bad then `DUPLICADA parada {bad}` else "")
			last = line
		end
		task.wait(0.1)
	end
end)
```

**S3 — grelha (visão Client).** `id` = atributo `StationId` da grelha no Explorer (record = `StationId * 100 + vaga`):

```lua
local Net = require(game.ReplicatedStorage.shared.Libs.Net)
local id = 0 -- StationId da grelha
local prev = {}
task.spawn(function()
	for _ = 1, 1200 do
		for slot = 1, 4 do
			local r = Net.Stations:get(id * 100 + slot)
			local key = if r then `{r.State} {r.StartedAt} {r.Duration} flip={r.Flip}` else "nil"
			if prev[slot] ~= key then
				print(string.format("%.2f", workspace:GetServerTimeNow()), "vaga", slot, key)
				prev[slot] = key
			end
		end
		task.wait(0.05)
	end
end)
```

**S4 — mesa central e tablet (visão Client).** Mostra quando o tablet sai de `Talking` e quando a vaga ganha o ticket:

```lua
local R = require(game.ReplicatedStorage.shared.Libs.Net.Restaurant)
local prev = {}
task.spawn(function()
	for _ = 1, 2400 do
		local t = R.Tablets:get(1)
		local rows = { `tab={if t then t.State else "nil"}` }
		for v = 1, 8 do
			local p = R.Plates:get(v)
			table.insert(rows, if p then `{v}:{p.Npc}{if p.Bun then "B" else ""}{if p.Sausage then "S" else ""}{p.Grade or ""}{if p.Orphan then "?" else ""}` else `{v}:-`)
		end
		local line = table.concat(rows, " ")
		if prev[1] ~= line then
			print(string.format("%.2f", workspace:GetServerTimeNow()), line)
			prev[1] = line
		end
		task.wait(0.05)
	end
end)
```

**S5 — contagem de pratos.** Preferido: `/dev plate` da TASK-505 imprimindo `PlateService:AliveCount()` e cada prato (id, ticket,
forma, vaga/assento/dono). Sem ele: soma de (vagas de S4 com `Npc ≠ 0` ou `Orphan`) + (assentos de S2 com `Stop > 0`) +
(Tools com atributo `PlateId` em `Backpack` e `Character` de cada jogador, visão Server). **Cada `PlateId` aparece uma vez.**

### 0.3 Pedidos de testabilidade (Provisório, para a TASK-505 e as da onda C)

Sem estes, o caso é feito no ritmo real e anotado; não bloqueia.

| # | Pedido | Casos | Onde caberia |
|---|---|---|---|
| PR-1 | `/dev plate` com `AliveCount` e a lista por forma (Table/Hand/Belt) | EN-6, SA-*, BO-*, DU-6 | `Commands/Plate.luau` (505) |
| PR-2 | `/dev belt` põe o prato do chamador numa parada e força ocupação de outra (já no board) | DU-3, DU-4, AB-3 | `Commands/Belt.luau` (505) |
| PR-3 | `/dev center fill <n>` / `clear` (já no board) | PT-3, Q4-3 | 505 |
| PR-4 | Nota forçada no `/dev smoke` e um `/dev prep finish force <banda>` no modo esteira | NT-1..NT-3 | 505 |
| PR-5 | Print de `[Sale]` com preço, gorjeta base, `TipExtra`, `FlipBonus` separados | NT-1..NT-4, GR-5 | 517 |
| PR-6 | Atalho para envelhecer o prato parado (`ParkMax`) sem esperar 120 s | SA-6 | 505 ou 514 |

---

## 1. Gate estático (antes de qualquer caso M)

| ID | Verificação | Esperado | Tipo | Dep. |
|---|---|---|---|---|
| E-1 | P2 inteiro | 0 erro, 0 ciclo | E | toda task de código |
| E-2 | `git diff` em `src/Modux`, `*/Manifest/init.luau`, `*/Modules.luau`, `shared/Libs.luau`, `src/ModuxTypes/**` | nenhuma linha à mão (gerados só pelo `modux generate`) | E | idem |
| E-3 | `src/Profile/server/ProfileService/Template.luau` | **sem mudança** nesta rodada (o prato não persiste) | E | 513–522 |
| E-4 | Pontos de conflito: `Net/init.luau`, `Net/Restaurant.luau`, `Content/*` | só a 513 (e depois a 506) mexe neles; `git log --format=%s -- <arquivo>` | E | 513, 506 |
| E-5 | Rede | `PrepBelt`, `PrepStage` em `Net/init.luau` (ou `Net/Belt.luau`, P23); `CenterPut` em `Net/Restaurant.luau`; campos `Stop`/`Wait`/`Line`/`Away` opcionais em `PrepSeats`; `Grade` opcional em `Plates`; **nenhum `keyBy`**; nenhum Remote fora do Lync | E | 513 |
| E-6 | Responders | `PrepBelt`/`PrepStage` só no `PrepService:OnInit`; `CenterPut` só no `PlateService:OnInit`; nenhum Component registra responder | E | 514, 516 |
| E-7 | `--!strict` e lados | todo arquivo novo com `--!strict`; Charm só no servidor, Vide só no client; Lync/Vide requeridos direto | E | 513–522 |
| E-8 | Nota | calculada só em `src/Prep/shared/Grade.luau`; client e `CustomerService` não reimplementam `Score`/`Band` (grep de limites literais vazio) | E | 517, 520 |
| E-9 | Requires | `PrepService` requer `PlateService`; `PlateService` **não** requer `PrepService` (ciclo); `analyze -Detail` 0 ciclo | E | 514, 516 |
| E-10 | `Content` com a chave ligada | `Prep.Rules.Enabled == true`, `Prep.Rules.Mode == "Conveyor"`, `Prep.Rules.WorldKitchenPrompts == false`, `Conveyor.Rest.Capacity == 8`, `CenterTable.Slots == 8`, `Grades.Effects.Perfect.TipExtra == 1`, `GrillTime` 8/6/4 em `Upgrades`, `plate_take.Hold`/`pickup_serve.Hold` = 0,5, linha `prep_grill` | E | 513 |
| E-11 | `Content` com a chave desligada (build local) | `Prep.Rules.Enabled == true`, `Mode == "Trailer"`, `WorldKitchenPrompts == false`; boot sem erro do `Validate` | E/S | 513 |
| E-12 | `/dev prep grade` | `N/N ok` (anotar N) nos dois modos | S | 513, 517 |
| E-13 | `/dev smoke` | trailer verde; restaurante verde depois da 505 (imprime tempo do pedido K = 2 e nº de interações) | S | 505 |

---

## 2. Matriz: critério → casos

### 2.1 Critérios da TASK-510 (o aceite da 509 é "cada um tem um caso")

| Critério 510 | Resumo | Casos |
|---|---|---|
| (1) | Prep e restaurante ligados juntos; tablet, mapa, pickup e prompts da cozinha funcionam; nenhum prompt de mundo do F2 | CH-1 a CH-7 |
| (2) | Grelhador na vista focada abastece a mesa de descanso; nada queima; virar dá bônus; não virar não trava; nenhuma barra | GR-1 a GR-10 |
| (3) | Pedido → 1 prato vazio #n na mesa; pegar segurando E (HUD); esteira; salsicha do descanso; cortar, montar, desenhar, nota; sem prato = recusa | PT-1 a PT-8, ES-1 a ES-11 |
| (4) | Cada um vê o prato do outro andar; setas só o próprio; nunca 2 na mesma estação, o 2º espera; 3º jogador recusado | DU-1 a DU-9 |
| (5) | Prato volta à mesa (outro entrega) ou direto ao `PICKUP`; máx. 2 na mão; `PICKUP` só ao dono e recusa sem montar; contagem | EN-1 a EN-9 |
| (6) | Perfect paga gorjeta extra | NT-1 a NT-5 |
| (7) | Solo fecha um pedido K = 2 | SO-1 a SO-5 |
| (8) | Sair ou desmaiar no meio devolve reserva e ticket | SA-1 a SA-8 |
| (9) | Trailer sem regressão | TR-1 a TR-6 |
| (10) | 10 de 10 toques no celular nas setas e nas vagas | CE-1 a CE-6 |

### 2.2 Aceites de outras fontes cobertos aqui

| Fonte | Aceite | Caso |
|---|---|---|
| FEAT-044 | 1 prato em ≤ 0,5 s com #n e ícones iguais aos da nota do HUD | PT-1 |
| FEAT-044 | mesa cheia: "Kitchen full" para todos; pegar 1 destrava em ≤ 0,5 s | PT-3 |
| FEAT-044 | segurar E pega; 3º prato `hands_full`; pôr devolve com o mesmo estado e ticket | PT-4, EN-3, EN-4 |
| FEAT-044 | HUD segue o equipado em ≤ 0,2 s; some sem prato | PT-5, PT-6 |
| FEAT-044 | 20 ciclos pôr/pegar com 2 jogadores sem duplicar nem sumir | EN-6 |
| FEAT-044 | prato de quem desistiu: vazio some, com conteúdo fica órfão; `Summary` sem órfão | BO-3, BO-4 |
| FEAT-044 | jogar fora o prato #7 com o cliente esperando faz nascer prato vazio #7 | BO-5 |
| FEAT-044 | nenhum anel vermelho; urgência muda de forma (escala de cinza) | PT-8 |
| FEAT-045 | todos os 14 aceites | GR-*, ES-*, DU-*, NT-*, SO-2, SA-*, TR-* (ver Nota de cada caso; os que a DEC-305 mudou estão na §17) |
| MAP-01-r4 §16.11 | 7 aceites do layout (da TASK-504) | L-1 a L-7 |
| kitchen-redesign §5 (critérios da Opção A que continuam) | um fluxo só; nenhuma salsicha solta; nenhuma barra; 10 de 10 toques | CH-3, GR-8, GR-9, CE-* |
| 514 / 515 / 516 / 518 / 519 / 520 / 521 / 522 | aceites de cada task | citados na coluna Dep. dos casos |

---

## 3. Layout: conferência da TASK-504 (antes do 1º Play da 510)

| ID | Passo | Esperado (medida) | Onde olhar | Dep. |
|---|---|---|---|---|
| L-1 | print de cima do MAP01_Restaurant | igual à §16.3 do MAP-01-r4 (±0,5 stud) | Studio, câmera de cima | 504 |
| L-2 | `restaurant_walk_check.luau` | 0 bloqueios entre DOOR-P, assentos, mesa central, `PICKUP`, TAB-1, DT-WIN; corredor da frente ≥ 4,4, do fundo ≥ 4,5 | Output | 504 |
| L-3 | entrar no foco da esteira em 1280×720 e em 667×375 | 3 estações, mesa de descanso, cruas e a esteira de ponta a ponta no quadro, ≥ 5% de margem lateral | tela, print | 504, 518 |
| L-4 | câmeras de parada e da grelha | estação e prato inteiros no quadro; alvos ≥ 44 px em 667×375 | print com régua | 504, 518, 521 |
| L-5 | prompts de mundo da cozinha | ≥ 2,5 studs entre vizinhos (tabela §16.7: `Prompt_Work`↔`Prompt_Grill` 5,8, `Prompt_Take` vizinhos 2,6…); `Click_Slot` sem sobreposição; `anchor spacing (rule 4)` vazio no boot | Output do boot, Explorer | 504 |
| L-6 | console no boot | nenhum `[RailSlot] … may float`; nenhum `[MapIndex] … missing`; nenhuma peça do rail flutuando | Output servidor | 504, 515 |
| L-7 | em pé no `Seat_Belt_1`, olhando a bancada | grelha à **esquerda** (leste), pão no meio, condimentos à **direita** (oeste) | tela | 504 |

---

## 4. Critério (1): chave dupla e um fluxo de cozinha

Jogadores: 1 (PC). Preparo P7.

| ID | Passo | Esperado (medida) | Onde olhar | Dep. | Nota |
|---|---|---|---|---|---|
| CH-1 | Play; primeiros 10 s | nenhum `error`; `Lync.start()` sem erro de schema (`PrepSeats`, `PrepBelt`, `PrepStage`, `Plates`, `CenterPut`); `Validate` sem falha | Output servidor e client | 513 | |
| CH-2 | S1 com a fase em `Open` | aparecem `prep_work` (1, no `Prompt_Work`), `prep_grill` (1, no `Prompt_Grill`), `tablet_take`, `plate_take` (âncoras `CenterSlot`, só vagas com prato), `pickup_serve`, `discard` da BIN-C, `take_box`/`restock`/telefone/portas | S1 | 496, 513, 514, 516 | |
| CH-3 | S1, procurar os rótulos do F2 | **nenhum** `grill_place`, `grill_collect`, `grill_flip`, `bun_cut`, `bun_slice`, `board_add_sausage`, `rail_take`, `topping_add`, `plate_put`, nem `plate_take` em `PLATE-n` da passa | S1 | 496 | lista exata: `prep-conveyor.md` §1.1 |
| CH-4 | andar pela cozinha inteira (CUT-1, cesta, grelha, rail, COND-1, passa) olhando os prompts do client | nenhum prompt de mundo do F2 visível; as peças ficam como cenário | tela | 496, 522 | |
| CH-5 | jogar um pedido inteiro (SO-1) e, no fim, procurar Tools | nenhum Tool `bun_sliced` ou `sausage_grilled` foi criado em nenhum momento | Explorer (Backpack), Output | 496 | aceite da 496 |
| CH-6 | `/dev tablet`, `/dev pickup`, telefone (`Order Stock`) | tablet `TAB-1` Idle, pickup ligado com `PU-k`, pedido de estoque funciona; nada disso foi desligado pela volta do Prep | Output client | 513 | R-1 do e2e continua valendo para `PU-1..8` |
| CH-7 | `/dev prep seats` | 3 registros no modo esteira (1, 2 esteira; 3 grelha), publicados desde o `ShiftStarted`, sem crescer com a party | Output | 514 | DT-E2 |

---

## 5. Critério (2): grelha focada e mesa de descanso

Jogadores: 1 (grelhador), depois a dupla. Nível da grelha 1 (`GrillTime` 8 s, janela 3,2–4,8 s), salvo onde dito.
S3 rodando no client do grelhador.

| ID | Passo | Esperado (medida) | Onde olhar | Dep. | Nota |
|---|---|---|---|---|---|
| GR-1 | prompt **Grill** com a mão vazia | entra no assento 3, câmera `CamAnchor_Grill`; vê cruas, grelha e mesa de descanso | tela | 514, 521 | DEC-305: prompt próprio |
| GR-2 | Grill com o assento 3 ocupado (2º jogador) | recusa `GrillBusy` (toast `prep_busy`); nada muda | toast, S2 | 514 | |
| GR-3 | pôr 1 crua e não tocar mais | `Working` em S3; `Ready` em **8,0 ± 0,1 s** (StartedAt → troca de estado); repetir em nível 2 (6 s) e 3 (4 s) com `/dev upgrade` | S3 | 515 | aceite da 515 |
| GR-4 | deixar a salsicha pronta por 3 × `GrillTime` (24 s) com o descanso cheio (GR-7) | continua `Ready`; nunca `Burnt`; cor não escurece | S3, tela | 515 | |
| GR-5 | virar a **50%** (4,0 s), a **30%** (2,4 s) e a **70%** (5,6 s), uma salsicha cada; levar as três até a venda Completa na janela de gorjeta | só a de 50% carrega `Flip = true` no rail e `FlipBonus = true` no prato; na venda ela paga **exatamente $1 a mais**, 1 vez | S3, atributo do Tool, PR-5 | 515, 517 | aceite FEAT-045 |
| GR-6 | não virar nenhuma de 3 salsichas | as 3 ficam prontas no tempo, vão ao descanso; a nota do prato que usar uma delas **não** muda por isso (`Grade` sem etapa de salsicha) | S3, nota | 515, 517 | P13 |
| GR-7 | encher a mesa de descanso (8) e ter mais 1 pronta na grelha | a 9ª fica na grelha em `Ready` sem queimar; o aviso "Rest table full" sai **1×**; pegar 1 do descanso (montador) faz a da grelha descer sozinha em ≤ 0,5 s, na ordem em que ficaram prontas | S3, tela, toast | 515, 521 | FEAT-045 diz 6 lugares; vale 8 (DEC-305) |
| GR-8 | durante GR-3..GR-7, na visão Server: procurar `BillboardGui`/`ProgressBar`/`GrillBar` de cozinha no `Workspace` e no HUD dos dois clients | **nenhuma** barra de cozinha no modo esteira | Explorer, tela | 521 | aceite 521 e kitchen-redesign §5 |
| GR-9 | depois de 10 salsichas: Explorer no `Workspace` | nenhuma salsicha fora de grelha, mesa de descanso, prato ou mão; nada solto no balcão | Explorer, tela | 515, 521 | bug do print do dono |
| GR-10 | colega fora do foco olhando a grelha e o descanso de 10 studs (PC e 667×375) | vê a salsicha mudar de cor, a fumaça e a pronta chegar ao descanso; a pronta é legível no celular | tela do colega | 521 | aceite 521 |

---

## 6. Critério (3): o prato nasce, vai à mão e é montado na esteira

Jogadores: 1 (PC), depois repetir PT-1..PT-6 e ES-1..ES-11 no client 667×375. S4 e S2 rodando.

### 6.1 Mesa central e HUD

| ID | Passo | Esperado (medida) | Onde olhar | Dep. | Nota |
|---|---|---|---|---|---|
| PT-1 | tomar o pedido no tablet (K = 2) | no fim da fala nasce **exatamente 1** prato vazio com o ticket #n numa vaga livre em **≤ 0,5 s** (tempo entre `tab=Talking→Idle` e a vaga ganhar `Npc` em S4); billboard da vaga com #n e ícones iguais aos da nota do HUD | S4, tela | 516, 522 | vaga = a livre de **maior** índice (P14, aceita); FEAT-044 diz menor (§17 D-5) |
| PT-2 | dupla (`/dev customer pair ketchup mustard`) | 2 pratos, um por linha (`Line` 1 e 2), mesmo #n | S4 | 516 | |
| PT-3 | tomar pedidos até o teto e tentar mais um | "Kitchen full" no tablet para todos, `Take Order` não abre; cliente espera em `Q1` com a paciência correndo; vender ou jogar fora 1 prato destrava em ≤ 0,5 s | S4, tela dos 2 clients | 516 | teto = `TicketCap` = min(`ActivePlates[party]`, 8) (P20): 4 solo, 6 dupla. DEC-304/FEAT-044 dizem "8 ocupadas" (§17 D-10) |
| PT-4 | segurar E (0,5 s) no `Prompt_Take` de uma vaga | o prato vai para a mão como Tool `plate` com `PlateId`, `Ticket`, `TicketLine`; a vaga fica livre na hora; soltar antes de 0,5 s não pega | Explorer (atributos), S4 | 516 | FEAT-044 diz 0,4 s; contrato 0,5 (Provisório) |
| PT-5 | equipar o prato | o HUD do ticket (posição do `HudOrder`) mostra #n, itens e toppings do pedido; guardar o Tool esconde | tela | 522 | DEC-304 |
| PT-6 | com 2 pratos de tickets diferentes, trocar o equipado 5 vezes | HUD e prompt seguem o equipado em **≤ 0,2 s** (≤ 12 quadros) | V | 522 | |
| PT-7 | vagas vizinhas: segurar E entre duas | só o prompt da vaga mais próxima aparece | tela | 522 | MAP §16.7 |
| PT-8 | anel de paciência na vaga até < 25%; print em escala de cinza | nenhum vermelho; a forma muda (cheio → meio → 1/4 piscando) e "!" abaixo de 25% | print | 522 | FEAT-044 |

### 6.2 Esteira e etapas (um montador)

| ID | Passo | Esperado (medida) | Onde olhar | Dep. | Nota |
|---|---|---|---|---|---|
| ES-1 | prompt **Work** sem prato na mão (nem parado) | recusa `NoPlate` (toast `need_plate`); não entra no foco; nenhum prato criado (S5 igual) | toast, S5 | 514 | FEAT-045 dizia "sem prato abre a grelha": superado (DEC-305) |
| ES-2 | Work com o prato do ticket #n equipado | entra no assento 1; o Tool sai da mão; o prato aparece em `Stop_1` (S2 `1:1/0 t<npc do #n>`); o ticket do preparo é o do prato | S2, Explorer | 514, 518 | aceite da 514 |
| ES-3 | Work com um `hot_dog` já montado equipado (e nenhum `plate`) | recusa `PlateDone`; o hot dog fica na mão | toast, S2 | 514 | |
| ES-4 | dentro do foco: abas antigas, `Pan`, tábua única | nenhuma aba/pan do trailer no modo esteira; câmera larga `CamAnchor_Belt` | tela | 518 | |
| ES-5 | seta direita 1 vez | o prato vai a `Stop_2` (1 parada por toque); chega em **≤ 0,4 s** (≤ 24 quadros); câmera desliza para a vista da parada | S2, V | 514, 518 | |
| ES-6 | na parada 2: arrastar a salsicha antes de cortar o pão | recusa com motivo; estoque e mesa de descanso iguais | toast, `Stock`, S3 | 514, 520 | FEAT-045 ordem fixa |
| ES-7 | tocar a cesta e arrastar para cortar (mouse; depois toque 667×375) | `Bun = true` no prato (`Plates`/`PrepSeats.Plate`); −1 pão no `Stock`; guia de corte visível | tela, `Stock` | 514, 520 | |
| ES-8 | arrastar a salsicha da mesa de descanso para o pão | `Dog = true`; descanso −1 (aquela posição); `FlipBonus` do prato = carimbo da salsicha | S3, atributos | 514, 515, 520 | |
| ES-9 | seta direita até a parada 3; escolher ketchup, depois mostarda | guia **Zigzag** (ketchup) e **Wave** (mostarda) sobre o pão; só as tigelas do pedido acendem; cream cheese mostra **Line** | tela | 520 | DEC-305 padrão fixo |
| ES-10 | desenhar seguindo a guia exatamente; seta direita na parada 3 (Finish) | selo de nota; a nota mostrada = `Quality` do `hot_dog` e `Grade` gravado pelo servidor; prato vai a `Stop_4` e o foco termina em `DoneHold`; o `hot_dog` volta à mão equipado | tela, Explorer, S2 | 514, 517, 520 | aceite 520 |
| ES-11 | repetir ES-10 traçando mal de propósito | nota Good ou Messy; a mostrada = a do servidor | tela, Explorer | 517, 520 | |

---

## 7. Critério (4): dois montadores na esteira

Jogadores: 2 (J1 PC, J2 667×375), cada um com um prato. S2 rodando nos dois clients.

| ID | Passo | Esperado (medida) | Onde olhar | Dep. | Nota |
|---|---|---|---|---|---|
| DU-1 | J1 e J2 entram pelo Work (J1 primeiro) | J1 no assento 1 em `Stop_1`; J2 no assento 2 em `WaitL_1` (`1/1`), aviso "Waiting"; quando J1 anda, J2 entra em `Stop_1` sozinho em **≤ 0,3 s** | S2, tela de J2 | 514, 518 | |
| DU-2 | J1 e J2 martelam as setas por 60 s (cada um no seu ritmo) | o log S2 **nunca** imprime `DUPLICADA`; nunca dois pratos com `Wait = 0` na mesma parada 1..3 | S2 | 514 | aceite 514 / FEAT-045 |
| DU-3 | J1 parado na parada 2; J2 manda seta para a 2 | J2 fica ao lado (`Wait` = lado de onde veio: 1 se veio da 1); entra sozinho quando J1 sai da 2 | S2, tela | 514, 518 | FEAT-045 diz "espera à esquerda"; contrato: lado de onde veio (§17 D-8) |
| DU-4 | J2 esperando ao lado da 2 manda outra seta direita | passa ao lado e vai para a 3 (se livre) | S2 | 514 | |
| DU-5 | J1 e J2 olhando a esteira, dentro e fora do foco | cada um vê o prato do outro mudar de parada em **≤ 0,3 s**, com a cor do jogador (`Presence.Palette`) e o #n; o prato esperando aparece ao lado da estação | V (duas janelas lado a lado) | 519 | aceite 519 |
| DU-6 | J3 (fora do foco, ou o 1º jogador antes de entrar) vê os 2 pratos | os 2 pratos visíveis na esteira do mundo | tela | 519 | |
| DU-7 | um 3º jogador com prato aperta Work | recusa `BeltFull` (toast `belt_full`); o prato fica na mão | toast, S5 | 514 | 3 clients; ver também Q4-1 |
| DU-8 | J2 sai do jogo com o prato na esteira | nenhum prato fantasma dele na tela de J1 depois de 1 s; o prato vai para uma vaga livre da mesa (SA-4) | tela de J1, S4 | 514, 519 | |
| DU-9 | J1 e J2 arrastam a **mesma** salsicha do descanso no mesmo instante | só um leva (claim); a salsicha sai do alcance do outro na hora; o outro pode pegar outra | tela, S3 | 514, 520 | aceite 520 |

---

## 8. Critério (5): devolver à mesa, entregar e não perder prato

Jogadores: 2 (montador + entregador). S4 e S5.

| ID | Passo | Esperado (medida) | Onde olhar | Dep. | Nota |
|---|---|---|---|---|---|
| EN-1 | montador termina (ES-10) e clica numa vaga livre | o `hot_dog` sai da mão e aparece na vaga com #n e a nota (`Grade` em S4) | S4, tela | 516, 522 | |
| EN-2 | entregador pega esse prato (segurar E) e segura E no `PICKUP` | venda ao cliente #n; dinheiro + preço + gorjeta na janela; a vaga já estava livre desde o pegar | `Economy`, Output | 516 | |
| EN-3 | montador, depois do Finish, anda direto ao `PICKUP` e segura E | mesma venda, sem passar pela mesa | Output | 516 | DEC-304 |
| EN-4 | com 2 pratos na mão, segurar E num 3º | recusa `hands_full`; a vaga continua com o prato | toast, S4 | 516 | DEC-299 |
| EN-5 | clicar numa vaga **ocupada** com prato equipado | nada acontece; **nenhum** `CenterPut` sai (Network Monitor / log do responder) | tela, Output | 522 | aceite 522 |
| EN-6 | 20 ciclos pôr/pegar com 2 jogadores, alternando vagas | `AliveCount` igual antes e depois; nenhum `PlateId` repetido; nenhum ticket sem prato | S5 / PR-1 | 516 | FEAT-044 |
| EN-7 | `PICKUP` com `plate` **não montado** | recusa `plate_not_ready`; o prato fica na mão | toast | 516 | |
| EN-8 | `PICKUP` com o `hot_dog` do ticket #3 enquanto só o #2 e o #4 esperam na retirada (o #3 ainda não chegou ao `PU`) | recusa `ticket_other`; nada vendido | toast, Output | 516 | contrato §8 |
| EN-9 | `hot_dog` #3 com um topping não pedido | entrega **Errada** (DEC-072): o hot dog volta à mão, o cliente segue esperando | Output, tela | 516, 517 | FEAT-045 |

---

## 9. Critério (6): Perfect paga gorjeta extra

Jogadores: 1. O mesmo pedido (K = 2, ketchup + mustard), sempre **Completo dentro da janela de gorjeta**. Classe registrada no
resultado (Rookie: base $1). PR-5 ajuda; sem ele, ler a diferença do `Economy.Cash`.

| ID | Passo | Esperado (medida) | Onde olhar | Dep. | Nota |
|---|---|---|---|---|---|
| NT-1 | entregar Perfect e Good, sem bônus de virar | Perfect paga **exatamente $1 a mais** que Good (Rookie: $2 × $1 de gorjeta) | PR-5 / `Cash` | 517 | DEC-305: base + $1 |
| NT-2 | entregar Messy | gorjeta $0; humor do cliente −1 faixa | PR-5, rosto/balão | 517 | |
| NT-3 | Perfect com `FlipBonus` | $1 base + $1 Perfect + $1 virar = **$3** de gorjeta (Rookie); o bônus pago **1 vez** | PR-5 | 517 | |
| NT-4 | Perfect entregue **fora** da janela de gorjeta | sem gorjeta (nem extra nem virar) | PR-5 | 517 | FEAT-045 |
| NT-5 | Hawker (base $2) Perfect; Shift Lead (base $0) Perfect | $3 e $1 | PR-5 | 517 | FEAT-045 |

---

## 10. Critério (7): um jogador solo fecha um pedido K = 2

Jogadores: 1 (PC; depois 667×375). Cronômetro do "segurar E" no prato vazio ao fim do "Hand Over".

| ID | Passo | Esperado (medida) | Onde olhar | Dep. | Nota |
|---|---|---|---|---|---|
| SO-1 | caminho do contrato §2.4: prato → Work → corta na 2 → Leave (prato **parado**) → Grill → põe a crua → sai → Work (retoma na 2) → salsicha → condimentos → Finish → `PICKUP` | pedido vendido; nada trava; ao sair na 2 o prato fica `Away` (S2 `1:2/0A`) e ninguém senta no assento 1 | S2, Output | 514, 515, 516, 518, 520, 521 | DEC-305: solo troca de assento |
| SO-2 | salsicha **já** no descanso (grelhar antes): 5 tentativas | ≤ **15 s** em 4 de 5 (PC e 667×375) | cronômetro, V | 505, 518, 520 | FEAT-045 |
| SO-3 | grelhar **antes** de pegar o prato (Grill → mesa → Work) | também fecha; a pronta espera no descanso sem queimar | S3 | 515 | |
| SO-4 | 1º pedido da noite, grelha vazia, nível 1 | fecha; espera ≈ 8 s a mais (anotar) | cronômetro | 515 | |
| SO-5 | `/dev smoke` com a chave ligada | verde; imprime tempo do pedido K = 2 e nº de interações (anotar ao lado do medido à mão) | Output | 505 | |

---

## 11. Critério (8): sair, desmaiar ou desconectar no meio

Jogadores: 2. Para cada caso, S5 **antes e depois** (`AliveCount`, tickets vivos) e S2.

| ID | Passo | Esperado (medida) | Onde olhar | Dep. | Nota |
|---|---|---|---|---|---|
| SA-1 | Leave com o prato na parada 2 (pão cortado) | prato **parado e reservado** (`Away = true`), mantém pão e ticket; a parada 2 continua dele; o outro montador espera ao lado | S2, S5 | 514 | P24 (Provisória). FEAT-045 e o board dizem "volta à mão" / "devolve a reserva" (§17 D-4) |
| SA-2 | voltar pelo Work com **outro** prato na mão | retoma o prato parado, na mesma parada; o da mão fica na mão | S2, Explorer | 514 | |
| SA-3 | Leave com o prato em `Out` (depois do Finish) | `hot_dog` volta à mão equipado; assento e parada liberam | S2 | 514 | |
| SA-4 | desconectar (fechar o client) com o prato na parada 3 | o prato vai para uma vaga livre da mesa com ticket e conteúdo; assento e parada liberam; quem esperava é promovido | S4, S2, S5 | 514, 516 | §7.3 garante vaga |
| SA-5 | desmaio (`/dev sanity 0` ou `Down`) e uma anomalia que dá `Kick` (`/dev trigger <key>` com sinal) com o prato na parada 2 | prato **parado** como no Leave; `CueLock` de 6 s no sinal; nada some | S2, S5 | 514 | |
| SA-6 | prato parado por mais de `ParkMax` (120 s; PR-6) | vai sozinho à mesa central; o assento libera | S2, S4 | 514 | P25 |
| SA-7 | fim da venda (`KickClosing`) com prato parado na esteira | volta **à mão** | S2, Explorer | 514 | |
| SA-8 | grelhador sai (Leave, desmaio, desconexão) com 2 salsichas cozinhando | o assento 3 libera; as salsichas seguem cozinhando e vão ao descanso | S3 | 514, 515 | |

---

## 12. Critério (9): trailer sem regressão

Build local com `Rules.Enabled = false` (não commitar), mesmo place.

| ID | Passo | Esperado | Onde olhar | Dep. |
|---|---|---|---|---|
| TR-1 | boot | sem erro; `Validate` ok; `Prep.Rules.Mode == "Trailer"` | Output | 513 |
| TR-2 | `/dev smoke` | `SMOKE: N ok, 0 failures` (anotar N) | Output | 505 |
| TR-3 | `/dev prep grade`, `/dev prep kitchen` | `N/N ok`; kitchen sem FAIL | Output | 513 |
| TR-4 | entrar no preparo do trailer | abas/pan e tábua por assento como antes; nenhuma esteira, seta ou `prep_grill`; grelha do trailer com a pausa de virar e as regras de antes | tela | 514, 515, 518 |
| TR-5 | S1 | nenhum `plate_take`/`CenterPut`/`pickup_serve` do restaurante; prompts do trailer iguais ao `restaurant-e2e.md` §8 X3 | S1 | 516 |
| TR-6 | venda no trailer | `Grades.Effects.Perfect.Tip` fixo do trailer continua (não `TipExtra`) | Output | 517 |

---

## 13. Critério (10): celular 667×375, 10 de 10

Client em 667×375 com toque. Cada caso: 10 tentativas seguidas; anotar acertos/10 e o alvo medido em px (print com régua).

| ID | Passo | Esperado | Dep. |
|---|---|---|---|
| CE-1 | setas da esteira (esquerda e direita, 10 cada) | alvo ≥ 44 px (FEAT-045 pede 64); 10/10 movem **uma** parada | 518 |
| CE-2 | pôr o prato numa vaga escolhida (10 vagas sorteadas, de 2 a 6 studs) | 10/10 na vaga certa; nunca na vizinha | 522 |
| CE-3 | segurar E (prompt mobile) num prato entre dois vizinhos | 10/10 pega o certo | 516, 522 |
| CE-4 | cortar e arrastar a salsicha no toque | 10/10 aceitos (o gesto conta) | 520 |
| CE-5 | grelha: tocar a vaga certa para virar | 10/10 na vaga tocada; alvos ≥ 0,65 stud entre centros | 521 |
| CE-6 | botões Leave e o HUD do ticket | não cobrem as setas nem a esteira; nada cortado pela barra do topo (36 px) | 518, 522 |

---

## 14. Abuso: client forjando pacotes

Command Bar da visão **Client** com `local Net = require(game.ReplicatedStorage.shared.Libs.Net)` (e
`require(game.ReplicatedStorage.shared.Libs.Net.Restaurant)`), mesma API do controller. Cada caso termina com o servidor
intacto (nenhum erro no Output), `AliveCount` igual e sem punição a jogador legítimo. `/dev debug interact` ligado.

| ID | Ataque | Esperado | Dep. |
|---|---|---|---|
| AB-1 | `PrepBelt` em rajada (200 em 1 s) | no máximo `Conveyor.Rates.Belt` (6/s) processados; excesso descartado em silêncio; S2 nunca pula mais de 1 parada por pacote | 514 |
| AB-2 | `PrepBelt` de quem não está sentado / sentado na grelha | recusa; nenhum prato se move (o packet não tem alvo: não dá para mover o prato de outro) | 514 |
| AB-3 | `PrepStage { Stage = Cut }` com o prato na parada 1 ou 3 | `WrongStop`, nada muda | 514 |
| AB-4 | `PrepStage Cut` duas vezes | o 2º recusado; −1 pão só uma vez | 514 |
| AB-5 | `PrepStage { Stage = Dog, Slot = n }` com a posição `n` com claim do outro jogador / vazia / `Slot = 0` | `Held` / `NoSausage` / `Invalid`; descanso igual | 514, 515 |
| AB-6 | `PrepStage Dog` sem pão | recusa; descanso e estoque iguais | 514 |
| AB-7 | `PrepFinish` sem pão ou salsicha; `PrepFinish` com `Cut`/`Place` = 100 forjados; `PrepFinish` 0,5 s depois do corte | recusa; os `Cut`/`Place` do pacote são **ignorados** (o servidor usa os gravados); `TooFast` pelo relógio do servidor | 514, 517 |
| AB-8 | `PrepGrill Place` do assento de esteira | recusa (só do assento 3) | 514 |
| AB-9 | `PrepEnter { Station = 1 }` sem prato; `PrepEnter { Station = 3 }` com a grelha ocupada | `NoPlate`; `GrillBusy` | 514 |
| AB-10 | `CenterPut { Slot = 5 }` a 30 studs; numa vaga ocupada; sem prato equipado; `Slot = 13` | recusa por `Reach`; `slot_taken`; recusa; descartado pelo Lync (fora de `int(1, 12)`) ou recusa | 516 |
| AB-11 | `Interact` de `plate_take` a 50 studs e sem segurar o tempo | recusa por raio / hold | 516 |
| AB-12 | editar no client o atributo `Ticket` do `hot_dog` para outro #n e entregar | o servidor usa o próprio atributo (Tool do servidor); entrega só ao dono real ou recusa | 516 |
| AB-13 | `PrepGrab` claim em rajada nas 8 posições | no máximo 1 claim por jogador por vez (regra de hoje); o outro montador continua pegando | 514 |

---

## 15. 3 e 4 jogadores

| ID | Passo | Esperado | Dep. |
|---|---|---|---|
| Q4-1 | 4 clients: J1 grelha, J2 e J3 montam, J4 com prato aperta Work | J4 recebe `BeltFull`; J4 tentando Grill recebe `GrillBusy` | 514 |
| Q4-2 | J4 entrega e toma pedidos enquanto os 3 cozinham por 3 min | nenhum `DUPLICADA` em S2; `AliveCount` coerente com tickets vivos; ninguém > 5 s parado sem tarefa por > 25% do turno (DEC-275, medir à mão) | 514, 516 |
| Q4-3 | teto de tickets com 3–4 jogadores | `TicketCap` = 8; com as 8 vagas cheias e todos os pratos na mesa, "Kitchen full" | 516 |
| Q4-4 | um 5º client entra no meio (late join) | vê a esteira, a mesa e os pratos dos outros no estado certo (paradas, esperas, `Away`) | 519, 522 |

---

## 16. Bordas

| ID | Caso | Esperado | Dep. |
|---|---|---|---|
| BO-1 | sem pão (`Stock.bun` 0) e corte na parada 2 | `NoStock`; o prato não muda; nenhum dinheiro debitado na cozinha (o pagamento é na entrega; telefone sem saldo é o e2e S3) | 514 |
| BO-2 | sem um topping do pedido no estoque e Finish | recusa tudo ou nada: nenhum topping descontado | 514 |
| BO-3 | cliente desiste com o prato **vazio** (na mesa, na mão, na esteira) | some nas 3 formas; na esteira o foco termina; nada trava | 516, 514 |
| BO-4 | cliente desiste com prato com pão/salsicha | vira órfão (cinza "?", `Orphan`); `PICKUP` com ele = `ticket_gone`; um pedido novo idêntico adota o órfão em vez de nascer vazio; no `Summary` não sobra órfão | 516 |
| BO-5 | jogar o prato #7 na BIN-C com o cliente #7 esperando | nasce um prato vazio #7 numa vaga livre | 516 |
| BO-6 | lixeira 2D no foco com o prato montado pela metade | pão, salsicha e toppings se perdem; o prato fica **vazio na esteira com o mesmo ticket** | 514 |
| BO-7 | jogador sai do servidor com um prato **na mão** (Hand) | o ticket nunca fica sem prato: ou o prato volta à mesa com o conteúdo, ou nasce um vazio com o mesmo #n (P22). Anotar qual | 516 |
| BO-8 | jogador sai **segurando E no `PICKUP`** | nenhuma venda, nenhum dinheiro; o prato segue BO-7 | 516 |
| BO-9 | atendente do tablet sai no meio da fala | fala cancelada na hora, sem pedido e sem prato; cliente fica em `Q1` (e2e C6, R-8 corrigido) | — (já no código) |
| BO-10 | fim do turno (`ShiftStarted`) com pratos na mesa, mão e esteira | `PlateService:Clear()`: nenhum prato nem ticket no turno seguinte; salsichas da grelha e do descanso somem no `Summary` | 514, 516 |
| BO-11 | `/dev trigger anm_020_blackout` com 2 pratos na esteira | saída forçada = pratos parados (SA-5); luz volta, retoma | 514 |
| BO-12 | resume de snapshot no meio do turno | nenhum `plate` volta do snapshot (P16); tickets e pratos zerados sem erro | 516 |

---

## 17. Divergências entre documentos (o teste mede a coluna "vale")

| # | Ponto | Fontes em conflito | Vale (por quê) | Casos |
|---|---|---|---|---|
| D-1 | Prompt único × dois prompts | DEC-302, FEAT-045 rev. 3 ("Work sem prato abre a grelha"), MAP §16.5 c/§16.8, kitchen-redesign §0.1 passo 1, critério (1) da 510 ("prompt único") | **dois prompts** `prep_work` e `prep_grill` (DEC-305) | CH-2, ES-1, GR-1 |
| D-2 | Solo | FEAT-045 (o montador usa a grelha da parada 1) | **troca de assento** Work → Grill → Work (DEC-305) | SO-1 |
| D-3 | Lugares da mesa de descanso | FEAT-045: 6 | **8** (DEC-305) | GR-7 |
| D-4 | Leave / Kick no meio | FEAT-045 ("volta à mão"), critério (8) da 510 ("devolve reserva") | prato **parado e reservado** (contrato P24, Provisória); só desconexão, `ParkMax` e `KickClosing` liberam | SA-1, SA-5 |
| D-5 | Vaga em que nasce o prato | FEAT-044: menor índice | **maior** índice (contrato P14 "Aceita (dono)", MAP §16.5 d) | PT-1 |
| D-6 | Tempo de segurar E | FEAT-044: 0,4 s | 0,5 s (contrato, Provisório; 508 fecha, 506 aplica): medir o que estiver no `Content` | PT-4 |
| D-7 | Alcance do clique de pôr | FEAT-044: 8 · contrato: 12 · MAP §16.7: 6 | o do `Content` (Provisório); o toque a 6 precisa de ≥ 44 px | AB-10, CE-2 |
| D-8 | Lado da espera | FEAT-045: à esquerda da parada | **lado de onde o prato veio** (contrato §3.3, P6 aceita) | DU-3 |
| D-9 | Empate no mesmo tick | FEAT-045: ticket menor | ordem de processamento no servidor (contrato §4) | DU-1 |
| D-10 | Teto de tickets / "Kitchen full" | DEC-304 Provisório e FEAT-044: 8 vagas ocupadas | `TicketCap` = min(`ActivePlates[party]`, 8) (P20, Provisória): 4 solo, 6 dupla | PT-3, Q4-3 |
| D-11 | Órfão na mão | FEAT-044: entregável a pedido idêntico | só ao dono do ticket; órfão = `ticket_gone` (Q-383 A, contrato §8) | BO-4 |
| D-12 | Mesa central | FEAT-044 e DEC-303: grid 4 × 2 | **fileira de 8** (DEC-305 Provisória aceita, MAP §16.7) | L-1 |
| D-13 | Raio do Work | FEAT-045: 6 · contrato: 5 | o do `Content` (`Actions.prep_work`) | CH-2 |
| D-14 | Prato na mão de quem sai do servidor | contrato não diz (só a forma Belt e a perda "por fora", P22) | lacuna: BO-7 anota o comportamento; se o ticket ficar sem prato, **Falhou** | BO-7 |

O executor da 510 reporta qualquer divergência nova aqui; quem resolve é o architect/game-designer com o secretário.

---

## 18. Resultados (a TASK-510 preenche)

Build testado: `____` (hash) · data: `____` · Studio: `____` · clients: PC `____`, celular 667×375 `____`.

| Caso | PC | 667×375 | Resultado (Passou / Falhou / Bloqueado) | Medida | Evidência (print, vídeo, linha do Output) | Bug / task de correção |
|---|---|---|---|---|---|---|
| | | | | | | |

Regra: cada **Falhou** vira uma linha com arquivo:linha quando der para achar, e uma task de correção no board (pelo orquestrador).
