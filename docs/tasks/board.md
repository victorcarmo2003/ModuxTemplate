Status: Rascunho

# Board de tarefas (TASK-###)

Dono do arquivo: task-planner. Versão 1, 2026-10-10. Primeira onda depois da **bandeira verde (DEC-193)**.

Base: `CLAUDE.md`, `README.md` (Modux V3), `docs/PIPELINE.md`, `docs/tech/architecture.md`, `network.md`, `data.md`,
`content-data.md` (v3.1), `docs/design/*.md`, `docs/levels/MAP-01.md`, `docs/art/asset-list.md`, `decisions.md`
(DEC-001 a DEC-193), `tools/assetplace/build_crew.luau`.

> **Base Provisória (DEC-193).** Quase todas as specs de design e de tech estão em **Rascunho**. Pela DEC-193 elas valem
> como **base Provisória** para construir, abaixo das DEC e dos documentos Aprovados. A coluna **Provisória** lista o que
> cada task assume sem decisão do usuário (Q aberta, técnica T# sem aprovação em `Q-130`, ou entrega não aprovada).
> Se a decisão vier diferente, abre-se uma task de ajuste.

---

## Regras do board

- **Status:** `Pronta` (todas as dependências feitas) · `Bloqueada` (falta dependência) · `Em andamento` (dono marca
  antes de começar) · `Em QA` · `Feito` · `Falhou QA` (gera task de correção).
- **Um dono por arquivo.** Duas tasks que tocam o mesmo arquivo nunca ficam em paralelo. Pontos de conflito:
  - `src/Libs/Net/init.luau` e `src/Profile/server/ProfileService/Template.luau`: **só a TASK-004** nesta onda.
  - `src/Shared/Content/init.luau`: **só a TASK-003**. As demais tasks de conteúdo editam só o próprio arquivo de tabela.
  - `src/Kitchen/server/KitchenService/init.luau`: só a TASK-025. Estações novas entram como arquivos em
    `KitchenService/Stations/` (descobertos pelo init), sem editar o init.
  - Arquivos gerados (`src/Modux/*/Manifest/init.luau`, `*/Modules.luau`, `shared/Libs.luau`, `src/ModuxTypes/**`,
    `default.project.json`): **nunca à mão**. Conflito neles no merge se resolve rodando `rogen build` → `modux generate`.
- Coder trabalha em worktree própria por task (`PIPELINE.md`). Entrega exige `modux check` e `tools/analyze.ps1` com
  **zero erro**; task que toca `Net/init.luau` exige também boot no Studio sem erro de `Lync.start()`.
- Backend e frontend da mesma feature correm em paralelo **depois** que o contrato está em `docs/tech/network.md`
  (TASK-001) e o binding do mapa em `docs/tech/architecture.md` (TASK-002).
- Onda 1 roda no **place Run em modo de desenvolvimento** (`architecture.md` §1: sem `PrivateServerId`, roster = quem
  entrar). Lobby, party e teleporte ficam para a onda 2.

---

## Tabela de tasks — Onda 1 (núcleo jogável de dia, carrinho)

| ID | Título | Dono | Depende de | Arquivos / pastas | Spec | Provisória | Status |
|---|---|---|---|---|---|---|---|
| TASK-001 | Contratos de rede, conteúdo e dados da onda 1 (docs) | architect | — | `docs/tech/network.md`, `content-data.md`, `data.md` | DEC-140 a DEC-193; FEAT-003, 005–012, 014, 015, 028, 032 | Q-130 (T6, T13, T14) | Pronta |
| TASK-002 | Contrato de binding do MAP-01, kits de asset e layout de módulos (docs) | architect | — | `docs/tech/architecture.md` (seção nova) | MAP-01 §5, §7; DEC-146, 151, 156, 157, 190 | Q-153 | Pronta |
| TASK-003 | `Content`: scaffold + tabelas que geram enum + stubs tipados | architect | TASK-001 | `src/Shared/Content/` (Table, Validate, init, Ingredients, Packages, Items, Stations, Actions, Notices + stubs) | `content-data.md` §1–§3; DEC-071, 174, 180, 186, 190 | Q-062 | Bloqueada |
| TASK-004 | Net v1 do núcleo + Template do perfil | architect | TASK-003 | `src/Libs/Net/init.luau`, `src/Profile/server/ProfileService/Template.luau`, `.../ProfileService/init.luau`, `src/Profile/client/ProfileController.luau` | `network.md` (pós TASK-001); `data.md` §1.1; DEC-186 | Q-130 (T13, T14) | Bloqueada |
| TASK-005 | Binding do MAP-01 no place (tags, atributos, pontos, grafo de NPC) | level-designer | TASK-002 | place (Studio, fora do Rojo); `tools/assetplace/MAP-01_placements.luau` se preciso | MAP-01 §5.1, §5.3, §7.1, §7.4, §9.1; DEC-157, 190 | Q-153; AN-08 fora (DEC-191) | Bloqueada |
| TASK-006 | Kit de personagem no place + `CrewLooks` | modeler-3d | TASK-002 | `ReplicatedStorage.Assets.Crew`, `ReplicatedStorage.CrewExpressions` (Studio); `src/Crew/shared/CrewLooks.luau` | DEC-145, 151–154, 158–166, 181; `build_crew.luau` | pack Mid entregue sem aprovação (DEC-166); Q-144 h | Bloqueada |
| TASK-007 | Kit de itens e comida no place | modeler-3d | TASK-002, TASK-006 (mesma sessão de Studio) | `ReplicatedStorage.Assets.Items` (Studio) | AST-001–011; DEC-137, 141, 142, 174 | — | Bloqueada |
| TASK-008 | Conteúdo: turno, upgrades, veículos, fluxo e pedidos | backend-coder | TASK-003 | `src/Shared/Content/` Shift, RunParams, Upgrades, Vehicles, Flow, Orders | FEAT-003, 009, 010, 011, 015; `upgrades.md`; DEC-045, 048, 072, 184, 185 | Q-062, Q-163 | Bloqueada |
| TASK-009 | Conteúdo: classes, espécies, tipos de cliente, falas da Opal | backend-coder | TASK-003 | `src/Shared/Content/` Classes, Species, CustomerTypes, OpalLines | DEC-069, 070, 186, 188, 192; `npcs.md`; `characters.md` CHR-003 | Q-165, DEC-192 (porco, a confirmar), Q-160 | Bloqueada |
| TASK-010 | `Place` + `RunState` mínimo (modo dev) | backend-coder | TASK-004 | `src/Place/server/PlaceService`, `src/Place/client/PlaceController`, `src/Run/server/RunStateService/` | `architecture.md` §1, §2.3, §7; `data.md` §2.1 | modo dev; snapshot só em memória | Bloqueada |
| TASK-011 | `InteractionService` (único responder de `Interact`) | backend-coder | TASK-002, TASK-004 | `src/Interaction/server/InteractionService/` | `architecture.md` §4, T6; FEAT-005; DEC-066, 174 | Q-130 (T6) | Bloqueada |
| TASK-012 | `RoundService`: turno de dia, relógio, placa OPEN/CLOSED | backend-coder | TASK-004, TASK-008, TASK-010, TASK-011 | `src/Round/server/RoundService.luau` | FEAT-002, FEAT-003; DEC-048, 085 | noite fora da onda (Day N → Day N+1) | Bloqueada |
| TASK-013 | Interface: `ProgressBar`, `PromptBillboard`, `Toast`, `UseTween` (+ stories) | frontend-coder | — | `src/Interface/client/Components/` (pastas novas) | `animalplane-reuse.md` §1, §2; DEC-015, 029, 066 | — | Pronta |
| TASK-014 | `PromptController` + `Prompt` + bind de interagir | frontend-coder | TASK-002, TASK-004, TASK-013 | `src/Interaction/client/`, `src/Input/client/InputController.luau` | FEAT-005; DEC-039, 066, 097, 171; `architecture.md` §13 | — | Bloqueada |
| TASK-015 | `RoundController`: set `Shift` → sources Vide | frontend-coder | TASK-004 | `src/Round/client/RoundController.luau` | FEAT-003; `network.md` §3.1 | — | Bloqueada |
| TASK-016 | `CrewRig`: montagem de personagem de produção (crew e NPC) | backend-coder | TASK-006 | `src/Crew/shared/CrewRig/` | DEC-146, 152, 161, 165–169, 181; `build_crew.luau` | Q-144 h (casca de rosto) | Bloqueada |
| TASK-017 | `ClassService`: 6 classes, desbloqueio, seleção, modificadores | backend-coder | TASK-004, TASK-009 | `src/Class/server/ClassService/` | FEAT-028; DEC-069, 070, 186 | seleção no Run em modo dev (lobby `Q-085`); gemas de dev | Bloqueada |
| TASK-018 | `CharacterService`: spawn da crew com o animal da classe | backend-coder | TASK-005, TASK-010, TASK-016, TASK-017 | `src/Character/server/CharacterService/` | DEC-146, 147, 167, 175, 186; `architecture.md` §1.1, §8.3, T25, T26 | Q-130 (T25, T26); colisão no mapa todo (DEC-175); animações R6 padrão (AST-069 Rascunho) | Bloqueada |
| TASK-019 | `CameraController`: 1ª pessoa travada, corpo local | frontend-coder | TASK-002 | `src/Camera/client/CameraController.luau` | DEC-039, 097, 146, 171 | — | Bloqueada |
| TASK-020 | Tela "Crew": escolher e comprar animal (`ClassController` + UI) | frontend-coder | TASK-004, TASK-013, TASK-016 | `src/Class/client/`, `src/Interface/client/Components/CrewCard/` | DEC-186; FEAT-001 (parte de classe), FEAT-028 | nomes de classe placeholder; ícones (art-director) | Bloqueada |
| TASK-021 | `EconomyService`: dinheiro da party, gaveta, nota, resumo | backend-coder | TASK-004, TASK-010, TASK-012 | `src/Economy/server/EconomyService/` | FEAT-012, FEAT-014; DEC-045, 050, 051, 072, 083 | — | Bloqueada |
| TASK-022 | `ItemService`: Tools, hotbar de 4, pacotes, Tool HotDog | backend-coder | TASK-004, TASK-007, TASK-011, TASK-017 | `src/Item/server/ItemService/` | FEAT-005, FEAT-007; DEC-040, 049, 174, 190 | — | Bloqueada |
| TASK-023 | `HotDogVisual`: empilhamento das coberturas | frontend-coder | TASK-007 | `src/Item/shared/HotDogVisual/` | DEC-142; AST-003 | — | Bloqueada |
| TASK-024 | `EconomyController` + gaveta no mundo (POS) | frontend-coder | TASK-004, TASK-005, TASK-013 | `src/Economy/client/` | FEAT-012; DEC-050, 155 | modelo novo da POS em produção (AST-020) | Bloqueada |
| TASK-025 | `KitchenService` núcleo + estoque + Restock | backend-coder | TASK-002, TASK-008, TASK-011, TASK-022 | `src/Kitchen/server/KitchenService/init.luau` | FEAT-006, FEAT-007; DEC-049, 071, 184 | Q-062 | Bloqueada |
| TASK-026 | Estações: grelha + trilho de descanso | backend-coder | TASK-025 | `src/Kitchen/server/KitchenService/Stations/Grill.luau`, `Rail.luau` | FEAT-006 passos 1–3; UPG-001; DEC-069 (Line Cook) | — | Bloqueada |
| TASK-027 | Estações: caixa de pão + tábua de 2 vagas → Tool HotDog | backend-coder | TASK-026 | `.../Stations/BunCrate.luau`, `Board.luau` | FEAT-006 passos 4–5; **DEC-190** | — | Bloqueada |
| TASK-028 | Estações: complementos em tigelas (com bloqueio) + lixeira | backend-coder | TASK-025 | `.../Stations/Toppings.luau`, `Trash.luau` | FEAT-006 passo 6; DEC-071, 072, 156 | — | Bloqueada |
| TASK-029 | `KitchenController` núcleo + estoque visual (contadores, `Fill`, ícones, cadeado) | frontend-coder | TASK-004, TASK-005 | `src/Kitchen/client/KitchenController/` (+ `Stock.luau`) | FEAT-007; DEC-140, 156 | Q-152 (ícones placeholder); modelo novo AST-017 em produção | Bloqueada |
| TASK-030 | Visuais de grelha, trilho e tábua (salsichas, barras, pães) | frontend-coder | TASK-013, TASK-029 | `src/Kitchen/client/KitchenController/` (`Grill.luau`, `Rail.luau`, `Board.luau`) | FEAT-006; DEC-015, 029, 190 | — | Bloqueada |
| TASK-031 | `NpcService` mínimo: pool, cliente animal, rota por grafo | backend-coder | TASK-005, TASK-009, TASK-016 | `src/Npc/server/NpcService/` | `architecture.md` §12.3, T11; DEC-045, 149, 181, 188, 191 | Q-130 (T11); Q-162; sem trânsito/reserva de faixa nesta onda | Bloqueada |
| TASK-032 | `CustomerService`: fluxo, fila Q1–Q5, ciclo de vida | backend-coder | TASK-008, TASK-012, TASK-031 | `src/Customer/server/CustomerService/` (`init.luau`, `Queue.luau`) | FEAT-009; DEC-045, 046, 185; MAP-01 §9.1 | recálculo no início do turno (DEC-185) | Bloqueada |
| TASK-033 | Pedido, atendimento e pagamento (Take Order / Serve / Refuse) | backend-coder | TASK-021, TASK-022, TASK-032 | `src/Customer/server/CustomerService/Orders.luau` (+ registro no `init.luau`) | FEAT-010, FEAT-011; DEC-071, 072, 187 | **humor simplificado** (Q-164) | Bloqueada |
| TASK-034 | `CustomerController`: balão do pedido, rosto de humor, reação de venda | frontend-coder | TASK-004, TASK-013, TASK-016 | `src/Customer/client/` | FEAT-010, FEAT-011; DEC-071, 152, 162, 187 | Q-164; Q-152 | Bloqueada |
| TASK-035 | `UpgradeService`: níveis por veículo, efeitos, peça visível | backend-coder | TASK-008, TASK-021 | `src/Upgrade/server/UpgradeService/` | FEAT-015; `upgrades.md`; DEC-046, 052, 101, 106, **184** | Q-163 | Bloqueada |
| TASK-036 | `MarketService`: prateleiras + bancada de upgrades básicos | backend-coder | TASK-011, TASK-022, TASK-035 | `src/Market/server/MarketService/` | FEAT-008, FEAT-015; DEC-049, 101, 106, 109, **180** | S1 sempre vazia nesta onda (Q-120) | Bloqueada |
| TASK-037 | `MarketController`: preços, "Out of stock", bancada no mundo | frontend-coder | TASK-004, TASK-005, TASK-013 | `src/Market/client/` | FEAT-008, FEAT-015; DEC-015, 180 | linha "Day N" sob a etiqueta (Rascunho) | Bloqueada |
| TASK-038 | Opal local: idle e falas por fase | frontend-coder | TASK-009, TASK-016 | `src/Opal/client/OpalController.luau` | DEC-079, 099, 178, 191; NPC-020; `architecture.md` §2.3 | Q-160 (espécie da Opal) | Bloqueada |
| TASK-039 | `HudController` básico: relógio, turno, dinheiro, toasts, resumo | frontend-coder | TASK-013, TASK-015, TASK-024 | `src/Hud/client/HudController.luau`, `src/Interface/client/Components/Hud*/` | FEAT-032, FEAT-014; DEC-015, 048, 051, 053, 081 | textos placeholder até `ui-text.md` | Bloqueada |
| TASK-040 | Plano de teste da onda 1 | qa-tester | TASK-001 | `docs/tests/wave-1.md` | critérios das FEAT da onda; DEC-171 (mobile + PC) | — | Bloqueada |
| TASK-041 | Validação integrada da onda 1 (dia completo, solo e party de 2) | qa-tester | TASK-010 a TASK-039, TASK-040 | `docs/tests/wave-1.md` (resultado) | `tests/wave-1.md` | — | Bloqueada |

---

## Próximas paralelizáveis

O que pode começar **agora**, por agente:

| Agente | Tasks |
|---|---|
| architect | **TASK-001** e **TASK-002** (arquivos diferentes; podem rodar em duas sessões) |
| frontend-coder | **TASK-013** (componentes puros, sem dependência) |
| backend-coder | — (espera TASK-003/TASK-004; ver etapa 1–3) |
| level-designer, modeler-3d, qa-tester | — (esperam TASK-001/TASK-002) |

### Ordem recomendada (etapas)

Cada etapa abre quando as dependências da anterior fecham. Dentro da etapa, tudo é paralelo.

| Etapa | architect | backend-coder | frontend-coder | outros |
|---|---|---|---|---|
| E0 (agora) | 001, 002 | — | 013 | — |
| E1 | 003 | — | 019 | level-designer 005 · modeler-3d 006 · qa-tester 040 |
| E2 | 004 | 008, 009 | (013 se não terminou) | modeler-3d 007 (depois da 006) |
| E3 | — | 010, 011, 016, 017 | 014, 015, 023, 024, 029, 037 | — |
| E4 | — | 012, 018, 022, 031 | 020, 030, 034, 038, 039 | — |
| E5 | — | 021, 025, 032 | — | — |
| E6 | — | 026, 028, 033, 035 | — | — |
| E7 | — | 027, 036 | — | — |
| E8 | — | — | — | qa-tester 041 |

- **Caminho crítico:** 001 → 003 → 004 → 011 → 022 → 025 → 026 → 027 (montagem completa do hot dog) e
  006 → 016 → 031 → 032 → 033 (cliente que paga). Backend tem 19 tasks contra 13 do frontend: rode **2 ou 3 sessões
  de backend-coder** em paralelo a partir da E3 (as tasks de cada etapa não compartilham arquivo).
- Frontend fica à frente a partir da E3: tudo dele lê sets e atributos do contrato (TASK-001/002), então pode ser
  feito e testado com dados de story (UI Labs) antes do backend fechar.

---

## Detalhe das tasks (critérios de aceite)

### TASK-001 — Contratos de rede, conteúdo e dados da onda 1
Atualizar `network.md`, `content-data.md` e `data.md` (v4) para o estado DEC-140 a DEC-193 **no escopo do núcleo**:
- `network.md`: schema final de `Shift`, `RunState`, `Economy`, `Stock`, `Stations`, `Customers`, `Upgrades`,
  `Interact`, `Notice`, `Sale`, `ShiftReport`, `Profile`, `ClassAction`. `Stations` cobre a **tábua de 2 vagas
  compartilhadas** (DEC-190: 2 registros ou slot no registro, decidir) e tigela bloqueada (`Blocked`, DEC-156);
  `Customers.Look` cobre espécie + roupa civil A–H + acessório (DEC-188) e pack Day/Mid (DEC-181); `Customers.Mood`
  serve à versão simplificada da onda 1 (Q-164). Diz explicitamente que `Round`, `Vitals` antigos ficam até a onda 2.
- `content-data.md`: `HotbarSlots` = 4 (DEC-174); `Classes` com campo `Species` e 6 `InMvp` (DEC-186; chaves estáveis
  decididas aqui); tabela nova `Species` (DEC-158/188, guaxinim não jogável); `Upgrades` com nível **por veículo**
  (DEC-184); `Ingredients.Icon` (DEC-156); `Stations` com as chaves da linha do carrinho (MAP-01 §7.1); atributo de
  Tool `Toppings` do HotDog; `Flow.PartySource = "Connected"` (DEC-185).
- `data.md`: Template v1 confirmado (Gems, Classes, SelectedClass com as chaves novas).
- Aceite: toda entrada de `Net/init.luau` da onda 1 tem schema, escritor, leitor e frequência; cada mudança cita a DEC;
  item Provisório marcado como tal; nenhuma entrada usa `keyBy` (T14).

### TASK-002 — Contrato de binding do MAP-01, kits de asset e layout de módulos
Seção nova em `architecture.md`:
- **Binding do mapa:** tags `CollectionService` e atributos que o código lê (`EntityId`, `StationKind`, `Slot`,
  `Ingredient`, `PromptAction`, `PromptHold`), nomes de pontos (`PS-1..4`, `Q1..Q5`, `D1`, `SP-A`, `EX-E`, `OP-1`,
  prateleiras, `B1..B5`, `S1`), formato do grafo `NpcNode`. Usa os `Prompt_*`/`Att_*` que já existem nos modelos
  colocados por `MAP-01_placements.luau`.
- **Kits de asset:** `ReplicatedStorage.Assets.Crew`, `ReplicatedStorage.CrewExpressions`, `ReplicatedStorage.Assets.Items`
  (pastas, nomes, atributos como `TopHeight` nas coberturas); proibido `InsertService` em runtime.
- **Layout de módulos:** onde ficam módulos que não são Service/Controller (`<Service>/init.luau` + filhos, como
  `ProfileService/Template.luau`; `src/<Feature>/shared/`), o contrato `KitchenService/Stations/*.luau` (interface de
  estação descoberta pelo init) e `CustomerService/*.luau`.
- Aceite: level-designer, modeler-3d e coders conseguem trabalhar só com esta seção; nenhum nome conflita com o
  `MAP-01.md`; seção marcada Provisória onde depende de Q-130/Q-153.

### TASK-003 — `Content`: scaffold + tabelas que geram enum
- `Table.luau` (`Table.new` → `List`, `Keys`, `ByKey`, `IndexOf`, congelado), `Validate.luau` (regras de
  `content-data.md` §1.4), `init.luau` reexportando **todas** as tabelas da onda 1.
- Completas: `Ingredients`, `Packages`, `Items` (inclui `hot_dog` e os 9 pacotes; `revive_kit` só como linha), `Stations`,
  `Actions` (textos e holds de FEAT-005), `Notices` (chaves da onda 1).
- Stubs tipados com `Keys` corretas (valores na TASK-008/009): `Classes`, `Shift`, `Upgrades`, `Vehicles`, `RunParams`,
  `Flow`, `Orders`, `CustomerTypes`, `Species`, `OpalLines`.
- Aceite: `require(ReplicatedStorage.shared.Content)` roda `Validate()` sem erro em < 1 ms; chave duplicada ou
  referência quebrada faz `error` com tabela e linha; nenhum `require` de Lync/Vide/`self.Libs`; analyze zero erro.

### TASK-004 — Net v1 do núcleo + Template do perfil
- `src/Libs/Net/init.luau` com as entradas da TASK-001; `Round` e `Vitals` antigos **mantidos** (remoção na onda 2,
  com `VitalService`/`RoundController` novos). Enums gerados de `Content` (T13).
- `Template.luau` = `data.md` §1.1 (sem Coins/Level/Playtime); `ProfileService` replica o `Profile` novo;
  `ProfileController` expõe os campos como sources.
- Aceite: analyze e `modux check` zero erro; boot no Studio sem erro de `Lync.start()`; jogador novo recebe `Profile`
  com `Classes = { class do Cachorro }` e `Gems = 0`; `RoundService`/`VitalService` atuais continuam compilando.

### TASK-005 — Binding do MAP-01 no place
- Taguear/atribuir no place, conforme TASK-002: estações do carrinho (estoque S, grelha G com vagas do nível 1, trilho
  R, pães B, **tábua T com 2 vagas**, 6 tigelas K, entrega/POS + gaveta, lixeira BIN-C, placa OPEN), Q1–Q5, PS-1..4,
  D1/SP-A/EX-E com grafo `NpcNode` até Q1, 9 pontos de compra do Mart, B1–B5 e S1 da bancada, OP-1.
- Aceite: script de checagem (ou checklist) lista 0 tag faltando; distâncias de prompt ≥ 2,5 studs (MAP-01 §7);
  bancada do carrinho a 3,0 (DEC-157); nenhum nó do grafo atravessa pista fora de faixa.

### TASK-006 — Kit de personagem no place + `CrewLooks`
- Importar para `ReplicatedStorage.Assets.Crew`: `AST-053_CrewTex`, `AST-053_CrewBase`, `AST-053_CivilArms`, as 18
  espécies (`AST-053_Animal_<A>`), bonés (normal e `EarsUp`), `AST-053_ThiefHat`, acessórios de cliente que existirem;
  `ReplicatedStorage.CrewExpressions` com uma `SurfaceAppearance` por expressão (Normal, Happy, Smiling, Sad, Fainted,
  Skeptical, Exhausted, Stressed, `Normal_Night`, `_Night` que houver).
- `src/Crew/shared/CrewLooks.luau`: ids de textura `T_*` (Day/Mid/Night por espécie e por roupa, atlas Mid/Night).
- Aceite: todo id citado em `CrewLooks` existe; nada carrega por `InsertService`; uma montagem de teste por espécie
  em Day/Mid/Night sem peça faltando.

### TASK-007 — Kit de itens e comida no place
- `ReplicatedStorage.Assets.Items`: Tool `HotDog` (AST-003, `Att_Topping1..3`, grip na mão R6), coberturas AST-004 a
  009 com atributo `TopHeight` medido (DEC-142), salsicha crua/grelhada (AST-002), pão aberto/fechado (AST-001),
  9 Tools de pacote (AST-011).
- Aceite: cada cobertura tem `TopHeight`; o HotDog equipado aparece na mão do rig da crew; tris dentro das fichas.

### TASK-008 — Conteúdo: turno, upgrades, veículos, fluxo e pedidos
- `Shift` (fases de dia de FEAT-003: Prep 60 s 7→8, Open 360 s 8→18, Closing ≤ 30 s, Summary 15 s; fases de noite
  só como chave), `RunParams` (StartCash 30, estoque cheio, `PartyPriceMult`), `Upgrades` (UPG-001 a 005 com níveis,
  preços, efeitos, `Part`; nível por veículo), `Vehicles` (`cart`, `trailer`), `Flow` (22 s, 0,08/dia até 0,40,
  `PartyMult`, teto 8 clientes de dia), `Orders` (`OrderPhases` e `OrderRules` de FEAT-010/011).
- Aceite: todo número tem a DEC/FEAT de origem em comentário; `Validate()` passa; mudar um número não exige código.

### TASK-009 — Conteúdo: classes, espécies, tipos de cliente, falas da Opal
- `Classes`: CLS-001 a 006 `InMvp = true` e 007/008 `false`, espécie, tier, preço (0/45/45/45/120/120/180), efeitos
  da DEC-069/186. `Species`: 18 espécies, `Playable` (6), raccoon só Quentin. `CustomerTypes`: NPC-001 a 006 com
  espécies e acessórios da DEC-188 (+ porco como cliente, DEC-192, a confirmar). `OpalLines`: fases Day/N1_3/N4_6/N7_10.
- Aceite: `Validate()` recusa classe com `Stat` fora da lista fechada; nenhuma classe jogável usa o guaxinim.

### TASK-010 — `Place` + `RunState` mínimo
- `PlaceService`/`PlaceController`: `Is("Run")`, `IsDev()` (atributo `Workspace.PlaceRole`).
- `RunStateService`: roster de dev (quem entra), `Members` (classe, `EverJoined`), set `RunState`, `Notify(player|all,
  key, value)` → packet `Notice` pelo `NetService.Audience`, `RegisterSnapshot(name, capture, restore)` guardando em
  memória (MemoryStore na onda 2).
- Aceite: 2 jogadores no Studio aparecem em `Members`; `Notify` chega só a quem deve; Service fora do papel retorna no
  topo do `OnInit`.

### TASK-011 — `InteractionService`
- Único responder de `Interact`; registro `EntityId ↔ Instance` pelas tags da TASK-002;
  `RegisterAction(key, { Validate, Run })` chamado por outros Services no `OnInit`; valida membro ativo, distância
  (raio da tabela + folga), taxa ≤ 8/s, requisitos (ex.: Tool na mão); atributos `PromptEnabled`/`PromptText` mantidos
  pelo servidor.
- Aceite: `Interact` com `EntityId` inexistente, fora do raio ou acima da taxa é descartado sem erro; duas ações no
  mesmo alvo no mesmo frame são serializadas (base do critério "só um recebe" da FEAT-006).

### TASK-012 — `RoundService`: turno de dia
- Reescreve o exemplo: fases de `Content.Shift` em atom Charm, set `Shift` por `effect` no `OnStart`, relógio por
  `PhaseStartedAt/ClockFrom/ClockTo`, `Day` crescente, sinais `PhaseChanged`, `ShiftStarted`, `ShiftEnded`; ação
  `open_sign` ("Open Shop", qualquer jogador, só na Preparação); Fechamento termina com balcão vazio ou 30 s.
- Aceite: FEAT-003 (nenhum cliente antes de 8:00 AM nem depois de 6:00 PM; CLOSED às 6:00 e fim em ≤ 30 s; horário igual
  para todos; relógio não pausa com jogador fora). Depois do Summary do Day N começa o Day N+1 (sem noite nesta onda).

### TASK-013 — Componentes de Interface
- Porte de `CookInterface` → `ProgressBar`, `PromptInterface` → `PromptBillboard` (Hidden/Indicator/Prompt, fill do
  hold), `UseTween`, `Toast` (canto superior direito, 3–6 s), cada um com story no UI Labs.
- Aceite: componentes puros (só props), sem `require` de Controller; stories abrem sem erro; analyze zero erro.

### TASK-014 — `PromptController` + `Prompt`
- Porte do AnimalPlane sem `PlaneController`; alvo = prompt mais próximo do centro da tela com histerese; hold pela
  duração do atributo; dispara `Interact{Id, Action}`; teclas por `InputController:Bind` (E no PC, botão fixo no mobile);
  um prompt visível por vez.
- Aceite: FEAT-005 (toda ação executável no mobile só com interagir, hotbar e câmera; prompt com `PromptEnabled = false`
  não aparece); soltar antes do fim do hold não dispara.

### TASK-015 — `RoundController`
- Lê `Shift` → sources Vide `Day`, `Phase`, `ClockText` ("8:00 AM", passo de 10 min, DEC-048), `IsNight`.
- Aceite: relógio local bate com o do servidor (≤ 1 passo de diferença); reconectar mostra a fase atual sem esperar
  troca de fase.

### TASK-016 — `CrewRig`
- Versão de produção de `build_crew.luau`: `Build(species, outfit, opts)` a partir dos kits (sem `InsertService`),
  `ApplyPack(model, "Day"|"Mid"|"Night")`, `SetExpression(model, name)`, acessórios por tipo de cliente; usável no
  servidor (crew, NPC) e no client (troca local).
- Aceite: monta as 18 espécies com roupa Crew e civil A–H; troca de pack e de expressão em runtime sem recriar o modelo;
  sem vazamento de instâncias (teste de 200 montagens/destroys).

### TASK-017 — `ClassService`
- Lê/escreve `Classes`, `SelectedClass`, `Gems` no perfil (cópia, não mutação); `ClassAction{Buy|Select}` validado
  (gemas, `InMvp`, já possui); `GetClass(player)` travada na run; `GetModifier(player, stat)` para `WalkSpeed`,
  `GrillTime`, `PackageLimit`, `TipAmount`, `TipWindow`.
- Provisório: no Run em modo dev, `Select` permitido antes do spawn e um comando de dev dá gemas (sem `RewardService`
  nesta onda).
- Aceite: conta nova = Cachorro; comprar sem gemas falha; classe não muda durante a run fora do modo dev.

### TASK-018 — `CharacterService`
- `CharacterAutoLoads = false`; spawn em `PS-1..4` com `CrewRig` (espécie da classe, uniforme Crew, pack Day, rosto
  Normal); Humanoid R6, `BreakJointsOnDeath = false`; grupo `Players` sem colisão com `Players` (DEC-175, mapa todo);
  `WalkSpeed` pelo modificador da classe; atributos `Species`, `LookPack` no personagem.
- Aceite: 2 jogadores com espécies diferentes se veem com o animal certo; atravessam um ao outro; Coelho anda a 18 e
  Cachorro a 16; nenhum avatar do Roblox aparece.

### TASK-019 — `CameraController`
- `LockFirstPerson`; cabeça, boné, orelhas e acessórios do próprio personagem com `LocalTransparencyModifier = 1`; a Tool
  aparece na mão (DEC-097).
- Aceite: em 1ª pessoa nenhuma peça do próprio rosto/orelha tapa a visão; colegas veem o personagem completo; PC e mobile.

### TASK-020 — Tela "Crew"
- `ClassController` + UI Vide: 6 animais (DEC-186), preço em gemas, estado bloqueado/desbloqueado/selecionado, Buy e
  Select por `ClassAction`, prévia em `ViewportFrame` com `CrewRig`. Guaxinim, Panda e Leão não aparecem como jogáveis
  (Panda/Leão podem aparecer como "coming soon" só se o game-designer pedir).
- Aceite: refletir o `Profile` em ≤ 1 s após compra; botão Buy desabilitado sem gemas; funciona em mobile.

### TASK-021 — `EconomyService`
- Dono único de `Cash` (inicia em 30) e `Drawer`; `Spend(amount): boolean` atômico; `AddToDrawer(amount, kind)`;
  ledger do turno (servidos, completos, gorjetas, roubado = 0 nesta onda); no Summary: nota A–D (DEC-051), bônus
  floor(gaveta × %), depósito, `ShiftReport` ao grupo, gaveta zera; snapshot registrado.
- Aceite: FEAT-012 (dinheiro da party não muda com venda durante o turno); FEAT-014 (bônus inteiro; sem cliente = C);
  duas compras simultâneas nunca deixam `Cash` negativo.

### TASK-022 — `ItemService`
- `Give/Consume/GetHeld/Count`; máximo **4 Tools** (DEC-174) e 2 pacotes (3 com a classe do Urso); `Count` em atributo;
  Tool `HotDog` com atributo `Toppings` e visual por `HotDogVisual`; "Hands full" por `Notice`.
- Aceite: FEAT-005 (5º Tool bloqueado com aviso); pacote com sobra mantém `Count`; HotDog criado pelo servidor aparece
  na mão de quem tocou.

### TASK-023 — `HotDogVisual`
- Módulo compartilhado (chamado pelo `ItemService` no servidor): coloca as coberturas pela `TopHeight` real, **queijo
  sempre antes dos cordões** (Ketchup, Mustard, Cream Cheese), o resto na ordem de montagem.
- Aceite: critério da DEC-142 (qualquer combinação de até 3, vista de cima e na mão em 1ª pessoa: nada atravessa,
  nenhum molho some sob o queijo, nenhum cordão flutua).

### TASK-024 — `EconomyController` + gaveta no mundo
- Sources `Cash`, `Drawer`; BillboardGui do valor da gaveta na POS (igual para todos); "+$N" flutuante na gaveta no
  `Sale`.
- Aceite: valor da gaveta igual para todos (FEAT-012); funciona com o modelo antigo e com a POS nova (DEC-155).

### TASK-025 — `KitchenService` núcleo + estoque
- Registro de estações pelas tags; carrega `Stations/*.luau` (interface da TASK-002); estoque por ingrediente em atom,
  capacidade pelo nível de Cooler **do veículo atual** (DEC-184), set `Stock`; ação `restock` (hold 1 s, pacote na mão,
  transfere min(sobra, capacidade − atual), pacote vazio some); pacote grátis no dia de liberação (DEC-071); snapshot.
- Aceite: FEAT-007 (Restock nunca passa da capacidade; upgrade de Cooler aumenta capacidade sem mudar o atual; estoque
  do Day N+1 = fim do Day N).

### TASK-026 — Grelha + trilho
- "Grill" (toque) consome 1 salsicha para uma vaga livre; tempo 12/10/8 s por nível; Gato (Line Cook) 0,85× só nas
  dele; "Collect" leva ao trilho FIFO (6 no carrinho); registros em `Stations`.
- Aceite: FEAT-006 (sem vaga ou estoque 0 não grelha; estoque cai exatamente 1; barra ±0,2 s do nível).

### TASK-027 — Pão + tábua de 2 vagas
- "Slice Bun" (hold 0,5 s) consome 1 pão para uma das **2 vagas compartilhadas** (DEC-190), corte 1,5 s; "Add Sausage"
  com trilho ≥ 1 e pão cortado vira Tool `HotDog` na mão de quem tocou e libera a vaga.
- Aceite: dois jogadores na mesma vaga no mesmo instante: só um recebe o HotDog (FEAT-006); hotbar cheia bloqueia "Add
  Sausage" com "Hands full".

### TASK-028 — Complementos + lixeira
- "Add {item}" (hold 1 s) com HotDog na mão: consome 1 uso, não repete, máximo pelo pedido de 3; tigela de ingrediente
  não liberado fica `Blocked` (tampa + cadeado, DEC-156); "Throw Away" (hold 0,5 s) descarta o HotDog.
- Aceite: FEAT-006 ("Add X" não aparece para complemento já presente nem com estoque 0); bloqueio some no dia de
  liberação.

### TASK-029 — `KitchenController` núcleo + estoque visual
- Contador "7/12" por estação (vermelho com ≤ 2); `Fill` das garrafas e tigelas proporcional ao estoque com tween curto
  (DEC-140); `SurfaceGui` + `ImageLabel` na `Label_<Ing>` (DEC-156); tampa/cadeado conforme `Blocked`.
- Aceite: contadores iguais para todos; `Fill` acompanha Restock e consumo; ícone placeholder até `Q-152`.

### TASK-030 — Visuais de grelha, trilho e tábua
- Salsicha por vaga (crua → grelhada no fim), `ProgressBar` por `StartedAt/Duration`, salsichas no trilho, pão nas 2
  vagas da tábua (inteiro → cortado).
- Aceite: barra termina junto com o "Ready" do servidor (±0,2 s); quem reconecta vê o estado atual das vagas.

### TASK-031 — `NpcService` mínimo
- Pool ≤ 12 (Opal fora, DEC-191); cliente montado por `CrewRig` com espécie do tipo, roupa civil A–H sorteada,
  acessório, pack Day de dia / Mid à noite (DEC-181); `MoveTo` por A* no grafo `NpcNode`; grupo `Npc` sem colisão com
  `Players`/`Npc`; spawn em D1 e SP-A (sem trânsito nesta onda).
- Aceite: nunca mais de 12 NPCs de servidor; nenhum NPC usa o uniforme da crew nem o guaxinim; pool reaproveita rigs
  (sem crescer em 30 min de soak).

### TASK-032 — `CustomerService`: fluxo e fila
- Intervalo base 22 s ×crescimento ×`PartyMult` pelos **conectados** (DEC-185) recalculado no `ShiftStarted`
  (Provisório), ±25%; só na fase Open; vagas Q1..Q3/Q4/Q5 pelo Counter; fila cheia pula o spawn; avança até Q1; saída
  EX-E/D1; set `Customers` (`Look`, `State`, `Slot`).
- Aceite: FEAT-009 (16 ± 2 clientes no Day 1 solo; fila cheia não gera cliente; ≤ 12 NPCs).

### TASK-033 — Pedido, atendimento e pagamento
- K por `OrderPhases`, pesos × tipo × 1,5 no dia de liberação, ≤ 3, só liberados; paciência 40 + 5K (+Counter) desde a
  chegada; "Take Order" abre a janela de gorjeta 16 + 4K (Raposa −4 s); "Serve" valida Completo / Incompleto (50%) /
  Errado (HotDog volta) e paga na gaveta; "Refuse" (hold 1 s); `Sale` ao grupo; ledger.
- Humor (Provisório, Q-164): `Mood` só visual (Neutral → Annoyed com a paciência; Happy em Completo), **sem** mexer no
  pagamento da DEC-072 até o desenho do game-designer.
- Aceite: FEAT-010 (sem ingrediente não liberado, sem repetição, ≤ 3, distribuição de K ±3 p.p. em 1.000 sorteios);
  FEAT-011 (Serve só com pedido anotado; gorjeta nunca fora da janela nem em incompleto; client não manda preço).

### TASK-034 — `CustomerController`
- Balão com ícones do pedido (bitfield) visível para a party; rosto por `Mood` via `CrewRig.SetExpression` local
  (Normal, Happy, Skeptical, Stressed); reação ao `Sale` (balão feliz/neutro/reclamação).
- Aceite: balão aparece só depois do "Take Order"; ≤ 8 balões; ícone placeholder até `Q-152`.

### TASK-035 — `UpgradeService`
- Nível por upgrade **por veículo** (DEC-184; nesta onda só `cart`); set `Upgrades` do veículo atual; `GetEffect(stat)`
  (GrillSlots, GrillTime, StockCapacityLevel, QueueSize, PatienceBonus, DrawerOpenTime/StealPct); `Buy(key)` por
  `EconomyService:Spend`; troca a peça visível (DEC-052); "Grill upgraded!" para a party.
- Aceite: FEAT-015 (efeito imediato; peça muda para todos em ≤ 1 s; sem prompt de compra no equipamento).

### TASK-036 — `MarketService`
- Prateleiras: `buy_package` hold 0,5 s, preço da tabela, `Spend`, Tool na mão, limite de pacotes; ingrediente não
  liberado = **"Out of stock"** sem compra (DEC-180); Coffee só depois do trailer.
- Bancada: B1–B4 sempre à venda (DEC-106), B5 "Trailer only", `bench_buy_upgrade` hold 1,5 s → `UpgradeService`,
  "Maxed" sem prompt; S1 = "Nothing special today" (sorteio na onda 4).
- Aceite: FEAT-008 (sem saldo não compra; party nunca negativa; frutas/verduras sem prompt); FEAT-015 (B1–B4 em 100% dos
  turnos).

### TASK-037 — `MarketController`
- Billboards de preço nas prateleiras; etiqueta "Out of stock" (+ "Day N" Provisório); bancada com miniatura, nível,
  preço, efeito em 1 linha, "Maxed", "Trailer only"; S1 "Nothing special today". Sem UI de loja em tela (DEC-015).
- Aceite: preço em vermelho sem saldo; etiqueta some no dia de liberação.

### TASK-038 — Opal local
- Modelo da Opal (espécie Provisória, Q-160) montado no client por `CrewRig`, ancorado, `AnimationController`, idle;
  balão de fala de `OpalLines` pela fase ao entrar a 8 studs do caixa, 1× por visita. Zero rede.
- Aceite: não conta no teto de NPC; nunca recebe anomalia (DEC-191); fala muda entre dia e noite.

### TASK-039 — `HudController` básico
- Relógio, "Day N", dinheiro da party, toasts de `Notice`, tela de resumo do `ShiftReport` (some sozinha, 15 s).
- Aceite: FEAT-032 (nenhum elemento clicável para jogador ativo; sem reputação, chances, XP); sanidade não aparece de dia.

### TASK-040 — Plano de teste da onda 1
- `docs/tests/wave-1.md`: casos por critério de aceite das tasks acima, com 1 e 2 jogadores, PC e mobile (DEC-171).

### TASK-041 — Validação integrada da onda 1
- No Studio (modo dev), solo e party de 2: spawn como animal da classe em 1ª pessoa → abre a loja → cliente chega a
  Q1 → anota pedido → monta o hot dog (grelha, trilho, pão, tábua, complementos) → serve → gaveta sobe → resumo
  deposita → compra pacote no Mart, Restock → compra upgrade na bancada → Day 2 libera Cheese e Bacon segue "Out of
  stock".
- Aceite: todos os casos do plano passam; `modux check` e analyze zero erro; falha vira task de correção neste board.

---

## Ondas seguintes (só listadas; viram TASK quando a onda abrir)

| Onda | Escopo | Specs |
|---|---|---|
| 2 — Noite e meta | `VitalService` com sanidade e faixa visual da crew (DEC-166/167/169), troca local de NPC para Night (DEC-168/181), escuro e `LightZone`, interruptor e lâmpada básica (DEC-189), café, **compra do trailer** e troca de veículo (DEC-107/184), noite no `RoundService`, ligações do chefe, snapshot e noite repetida, ladrão (DEC-182), humor dinâmico completo (Q-164), passantes (DEC-183, Q-162), lobby com plataformas (DEC-179), party, sessão/teleporte/reconexão, gemas por evento (`RewardService`). Limpeza de `Round`/`Vitals` antigos no `Net` | FEAT-001, 002, 013, 016–021, 026, 029–031 |
| 3 — Anomalias e rua | `AnomalyService`, 7 verbos, ANM-001 a ANM-010, alucinações, trânsito com PARE e reserva de faixa (DEC-133), atropelamento e item no chão | FEAT-022–024, 033, 036; `anomalies.md` |
| 4 — Queda e monetização | desmaio, **ambulância**, reviver, spectate, janela de 10 s, Revive Kit na S1, `MonetizationService` (reviver por Robux), cutscenes de intro e final, final da 10ª noite | FEAT-004, 025, 027, 034, 035; DEC-091–094, 114–118, 129 |
