Status: Rascunho (Provisório; plano escrito antes do código 3D existir)

# Plano de teste: preparo 3D-first (TASK-211)

Autor: qa-tester · 2026-10-12. Base: `docs/tech/prep-3d.md` (§2 a §13, riscos R2 a R15), `docs/tech/prep-mode.md` (rede, assentos, saídas, nota), `docs/AGENT-BRIEF.md` §3b, `docs/tasks/board.md` (TASK-194 a 219), `docs/tasks/playtest-2026-10-12.md`. A **TASK-214** executa este plano e escreve os resultados na §14 (em branco até lá).

> **Estado do código em 2026-10-12.** Existem: preparo 2D (`Stages/*`), `Grade`, `PrepService`, `/dev prep grade|seats|enter|leave|finish|ui|kitchen`. **Ainda não existem** (viram testáveis quando a TASK citada fechar): `Rules.ThreeD`, `Rules.World.Stages`, abas `Board`/`Toppings` (TASK-194), `World/*` e `/dev prep ray` (TASK-196), `Stations.Flip`/`PrepTab.Plate`/`Slot` preferido (TASK-195), Grill 3D (203), Board (204), Toppings (205), Window (206). Cada caso traz a coluna **Dep.**: sem a dependência, o caso fica **Bloqueado**, não "Falhou". Compilação limpa não fecha nenhum caso **M**.

Tipos: **E** estático (diff, grep), **S** script/Command Bar (`/dev ...`, `Grade` em Luau puro), **M** manual no Studio, **R** rede (Output do servidor, Network Monitor / contagem de pacotes), **P** perf (MicroProfiler, Stats). Ambiente padrão: `rogen build` → `modux generate` → `rojo serve`; place **dev** com loja aberta, estoque de salsicha e pão, tutorial pulado (`/dev intro skip`, `/dev tutorial reset` só quando o caso pedir). Sempre `list_roblox_studios` antes de usar o MCP; **nunca `Place.run`**; antes de qualquer sync, `Place.diff` = 0 e o dono salva (memória `studio-hand-edits`).

IDs: `G-n` grelha, `B-n` tábua, `T-n` toppings, `S-n` servir/janela, `GE-n` gesto, `FE-n` ferramenta, `PL-n` plataforma, `AIM-n` ponteiro, `FR-n` enquadramento, `RB-n` rollback, `CO-n` co-op, `AB-n` abuso, `PF-n` perf, `OUT-n` Output, `HUD-n` HUD. Esperado de nota: Perfect/Good/Messy por `Content.Prep.Tolerances`; nunca copie número deste plano para o código.

---

## 0. Porta de entrada (gate estático, antes de qualquer M)

| ID | Verificação | Esperado | Tipo | Dep. |
|---|---|---|---|---|
| E-1 | `rogen build`, `modux generate`, `modux check`, `tools/analyze.ps1 -Detail` | 0 erro, 0 ciclo | E | tudo |
| E-2 | `git diff`: nada em `src/Modux`, `*/Manifest/init.luau`, `*/Modules.luau`, `shared/Libs.luau`, `src/ModuxTypes/**` | zero linhas | E | tudo |
| E-3 | `--!strict` no topo de todo arquivo novo em `src/Prep/client/PrepController/World/**` | presente | E | 196+ |
| E-4 | Rede só em `src/Libs/Net/init.luau`; **nenhum** `ProximityPrompt`, `ClickDetector`, `ViewportFrame`, `SurfaceGui`/`BillboardGui` por alvo em `World/**` (prep-3d §2.1, §8) | grep vazio | E | 196+ |
| E-5 | Respondedores de rede **só** em Service/Controller dentro de `OnInit` (Component não registra) | ok | E | 195+ |
| E-6 | Pacotes `Prep*`: **nenhum pacote novo** pelo 3D (N1 a N3 usam os existentes); `Stations.Flip` = `optional(int(0,101))`; `PrepTab.Plate`/`PrepSeats.Plate` = `int(0,255)` (nada de `int(0,7)`: `drop.section`, AGENT-BRIEF §2) | schema confere | E | 195 |
| E-7 | Nota calculada só em `src/Prep/shared/Grade.luau`; `World/**` não reimplementa `Score`/`Band`; números de tolerância só em `Content/Prep.luau` | grep por `Perfect`/limites literais vazio | E | 196+ |
| E-8 | Charm só no servidor, Vide só no client; `derive`/`effect`/`source` dentro de root | ok | E | 196+ |
| E-9 | `Rules.ThreeD`, `Rules.World.Stages`, `Rules.World.Editable`, `Rules.World.GhostHand` nascem `false` (até a TASK-203 ligar `Stages.Grill`) | valores conferem | E | 194 |
| E-10 | `/dev prep grade` em Play termina em **N/N ok** (hoje 93 casos) e `Spec` dos gestos imprime `gestures spec: 89/89 ok`; `Grade` e `Prep.luau` **inalterados** pelo 3D (diff vazio, salvo linhas de `Tabs`/`Steps`/`Views`/`Rules`) | ok | S | 194 |
| E-11 | `/dev prep kitchen` termina sem FAIL (N1: `Slot` livre usa, ocupado usa o primeiro livre, `Slot 0` igual a hoje; N2: `Flip` = nota+1 depois do Flip, nil depois do Collect/Place) | ok | S | 195 |
| E-12 | `/dev smoke` (`tools/studio/smoke.md`) sem falha após mudança de servidor | ok | S | 195 |
| E-13 | Strings de UI em inglês, sem vermelho de alerta, texto >= 14 px, alvo >= 44 px, nada centralizado em 1ª pessoa | revisão do diff | E | 198+ |

---

## 1. Casos por seção

Convenção: "1p" = Test > Play; "Nj" = Test > Clients and Servers com N clientes. Entrada padrão: `/dev prep enter 1 Grill` (ou prompt Work da grelha). **Entrada na seção `Board`** usa o prompt da tábua (`PromptStep = Board`) ou `/dev prep enter <n> Board` (hoje `Build`; ver TASK-194).

### 1.1 Grill (vista Grill, TASK-203)

| ID | Passos | Esperado | Dep. |
|---|---|---|---|
| G-1 | Entrar na grelha, loja aberta, estoque > 0 | Câmera `Prep` na vista Grill; 2 a 8 roletes (nível do upgrade); cada rolete livre mostra salsicha **fantasma** (Transparency ~0,7); **nenhum painel 2D no centro** (sem células "Add +", sem "Rail empty") | 203 |
| G-2 | Estoque = 0 | Fantasmas somem, caixa fecha/balança; toque na caixa dá toast "Out of sausages"; nada é enviado (ou `NoStock` do servidor desfaz a predição) | 203 |
| G-3 | Tocar a caixa de salsichas | `PrepGrill Place` com `Slot 0`; salsicha vai ao **primeiro livre**; estoque -1 em `Stock` | 203 |
| G-4 | Arrastar da caixa a um rolete livre específico (ex.: o 5) | `Slot = 5` honrado (N1); fantasma local no 5 bate com o registro do servidor, sem pulo | 195, 203 |
| G-5 | Soltar sobre rolete **ocupado** | Servidor usa o primeiro livre; a predição corrige em <= 0,15 s (snap), sem travar | 195, 203 |
| G-6 | Grelha cheia, tocar a caixa | Toast `Full`; salsicha de predição sobe, treme e some | 203 |
| G-7 | Observar cozimento 0 a 100% | Cor sobe de crua a pronta pelo `StartedAt`/`Duration` do servidor (`GetServerTimeNow`); 10 Hz; vapor + sizzle; **sem queimar** | 203 |
| G-8 | Tocar **antes** de 40% da `Duration` | Tremor leve, **nenhum pacote** (conferir contador de pacotes) | 203 |
| G-9 | Janela 40% a 60%: anel 3D converge (escala 1,8 para 1,0, alvo em 50%), contorno Mustard; tocar em ~50% | `PrepGrill Flip`; giro 180 graus em ~0,2 s; `PrepResult Grill` com nota **Perfect**; estouro de estrelas; `Stations.Flip` = nota+1 | 195, 203 |
| G-10 | Tocar em ~42% / ~58% | Nota **Good** (faíscas) | 203 |
| G-11 | Tocar depois da janela (> 60%) | "Tarde": anel pequeno e opaco, ainda vale; nota **Messy** (poeira) | 203 |
| G-12 | Não virar nunca, deixar chegar a pronta e coletar | Coleta permitida; nota da salsicha = `Grades.Unflipped` (hoje 0 / Q-222: **confirmar com o dono** se Messy); sem queimar | 203 |
| G-13 | Virar duas vezes a mesma salsicha | 2ª recusada `Flipped`; giro volta, selo some; sem nota duplicada | 203 |
| G-14 | Pronta: contorno Green **com marca de check** (forma, não só cor); tocar ou arrastar ao trilho | `PrepGrill Collect`; salsicha salta em arco 0,22 s ao slot do trilho **real**; `Rail.Count` +1; `Stations.Flip` zerado | 203 |
| G-15 | Trilho cheio (8), coletar | A salsicha pronta balança e **fica** no rolete; sem perda; toast | 203 |
| G-16 | Reentrar (sair e voltar) com salsichas cozinhando e uma já virada | Estado reconstruído de `Stations` (cor, anel, `Flip` virado visível); **selo/nota da virada sobrevive** (N2) | 195, 203 |
| G-17 | Grelha continua cozinhando em outra seção (ir a Board e voltar) | Progresso contínuo, badge de prontas na aba correto | 203 |
| G-18 | Sair de foco com salsicha na mão (arrastando) | Soltou/devolveu; **nenhuma** salsicha fantasma, hitbox ou Highlight sobra no mundo | 203 |

### 1.2 Board (tábua: pão e salsicha, TASK-204)

| ID | Passos | Esperado | Dep. |
|---|---|---|---|
| B-1 | Entrar na tábua (prompt da tábua) | Vista Board: tábua do assento (`Att_Bun n`), caixa de pães, faca, trilho; sem `PlateView` 2D | 204 |
| B-2 | Tocar/arrastar a caixa de pães | `PrepBegin`: pão -1 no `Stock`, vaga `n` da tábua `Working`; `BunClosed` pousa na tábua | 204 |
| B-3 | Sem pão (estoque 0) / loja fechada | `PrepResult Begin` recusa `NoStock`/`NotSelling`; pão de predição vira poeira; toast | 204 |
| B-4 | Dois toques seguidos na caixa (sem prato aberto + com prato aberto) | Só **um** prato; o 2º é ignorado ou recusado; **pão reservado uma vez** | 204 |
| B-5 | Pegar a faca e arrastar ao longo da guia 3D, esquerda para direita | Linha de corte preenche, migalhas; cobertura >= 94% (`Build.Cut.Done`) fecha; `BunClosed` -> `BunOpen` com hop | 204 |
| B-6 | Corte torto / curto / só parte | Corte não fecha antes de 94%; desvio vira nota `bun_cut` (Perfect <= 6, Good <= 15 por `Tolerances`) | 204 |
| B-7 | Salsicha: arrastar a **da frente do trilho** ao vão do pão | Fantasma no vão, ímã de 20% encaixa; rolete do trilho oculto localmente enquanto está na mão; mede `sausage_place` | 204 |
| B-8 | Trilho vazio | Alvo `Rail` desabilitado; dica de uma linha; Next bloqueado; **nenhum** pacote | 204 |
| B-9 | Soltar a salsicha fora do pão | Volta ao trilho em arco + tremida; nada enviado | 204 |
| B-10 | Pão com 4 jogadores (4 tábuas a 0,8 stud, pães de 1,0) | Os raios só incluem o alvo do **próprio** assento; mão por cima de pão vizinho não aciona o do colega (R5) | 204, 208 |
| B-11 | Leave com pão aberto e sem Finish | Pão **devolvido** ao estoque (+1); vaga da tábua liberada; sem modelo órfão | 204 |
| B-12 | Prato aberto por mais de `PlateMax` (90 s) | Prato descartado pelo servidor; cliente sincroniza (`Parked`/volta); sem travar | 204 |

### 1.3 Toppings (vista Toppings, TASK-205)

| ID | Passos | Esperado | Dep. |
|---|---|---|---|
| T-1 | Seção Toppings com o pão aberto e salsicha | 6 tigelas (AST-017) dos dois lados + pão central + lixeira, **todas no quadro**; clicáveis; nenhuma 2D principal (a barra à direita é só atalho opcional, Q-237) | 205 |
| T-2 | Ketchup: pegar garrafa, traçar o zigue-zague | Garrafa inclina e escorre; segmentos (pool de 80, <= 24 por traço, <= 72 por prato); pontos guia somem ao cobrir; `Fill` baixa; nota por `Grade.CoverageError` (cobertura e excesso) | 205 |
| T-3 | Mustard e cream cheese (variante branca) | Idem T-2; ferramentas distintas por **forma/rótulo**, não só cor | 205 |
| T-4 | Cheese: fatia, soltar no alvo (`slide`) | Cai com squash; desvio % vira nota | 205 |
| T-5 | Bacon: 3 anéis que encolhem, tocar quando fecham (`taps`) | Uma tira por toque; erro médio em ms | 205 |
| T-6 | Potato sticks: segurar e soltar na faixa (`hold`) | Monte cresce, anel-alvo 70%; % da barra vira nota | 205 |
| T-7 | Tentar 4º topping / repetir topping | Bloqueado no cliente (alvo desabilitado) e, se forjado, recusado no servidor (`Invalid`) | 205, AB |
| T-8 | Topping sem estoque / `Blocked` / não liberado pelo dia | Tigela desabilitada (tampa/`Lock`), sem pacote; se passar, `NoStock` no `Finish` **sem mudar nada** (prato `Parked`) | 205 |
| T-9 | Zero toppings ("plain") e Next | Válido; Finish aceito | 205 |
| T-10 | Lixeira: arrastar o prato à lixeira (no quadro) | `PrepTrash`: pão e salsicha perdidos (como `Trash.luau`); `Discarded` mantido; vaga livre | 205 |
| T-11 | Trocar ferramenta no meio de um gesto | Uma ferramenta por vez; gesto anterior descartado sem nota parcial | 205 |
| T-12 | **Next** fecha o pão (0,4 s) e envia `PrepFinish` | Selo 2D + estouro 3D; `hot_dog` com `Toppings`, `Quality`, `Altered` na hotbar; salsicha sai do trilho (`Rail.Pop`), toppings -1 | 205 |
| T-13 | `Finish` com hotbar cheia / trilho vazio / topping sem estoque | Recusa **sem mutação**; prato fica `Parked` até resolver; nenhum item duplicado | 205 |

### 1.4 Serve / Window (vista Window, TASK-206)

| ID | Passos | Esperado | Dep. |
|---|---|---|---|
| S-1 | Cliente em `Q1` (`Ordering`), vista Window | Cliente **pulsa** (contorno Mustard); outros normais; sem balão 3D | 206 |
| S-2 | Tocar o cliente (Take) | `PrepOrder Take`; ticket desliza ao trilho; só aceita o de `Q1`; fallback: botão **Take** no ticket 2D (R6) | 206 |
| S-3 | Prato pronto, ticket fixado, arrastar o prato à janela | `PrepOrder Serve` com o `Npc` do ticket; `CustomerService:ServeFor`; veredito Completo/Incompleto/Errado (DEC-072) como **estouro 3D** e carimbo no ticket (círculo+check, meio círculo, quadrado+X; sem vermelho) | 206 |
| S-4 | Servir sem prato / sem ticket fixado | Serve desabilitado; `NoTicket`; nada enviado | 206 |
| S-5 | Servir o cliente errado (ticket de outro) | Veredito **Errado** pelo servidor; dinheiro/gorjeta conforme DEC-072 | 206 |
| S-6 | Perfect: gorjeta $2 e janela +4 s; Messy: sem gorjeta, humor -1 faixa | Valores de `Grades.Effects`; **preço nunca muda** | 206 |
| S-7 | Cliente sai/pacienta acabou durante o arrasto | Serve recusado; prato volta à tábua (`Parked`); dinheiro intacto | 206 |
| S-8 | Cliente `Q1` visível na vista Window durante anomalia | **Pergunta aberta Q-228**: contar ou não como "ver"; registrar o comportamento observado, não aprovar | 206 |
| S-9 | Prompts do mundo (`take_order`, `serve`, `refuse`) antes de entrar | Continuam funcionando (DT-6); tutorial intacto | 206 |

---

## 2. Casos por gesto (medida pura + aplicação no plano 3D)

Entrada: raio do ponteiro cortado pelo **plano do topo do pão** (`PlaneRegion`), espaço normalizado do pão. Medida pura = `Gestures/Spec` (89 casos, não muda).

| ID | Gesto | Alvo | Casos manuais | Esperado |
|---|---|---|---|---|
| GE-1 | `slice` | `bun_cut` | reto, torto, rápido (< 0,3 s), parando no meio, saindo do pão e voltando | Nota monotônica com o desvio; sair do pão **não** conta cobertura; `Cut.Hold` (segurar 1 s sobre a linha) corta com Assist/Tap mode |
| GE-2 | `place` | `sausage_place` | no vão, 10%, 20% (ímã), 30% fora | Dentro do ímã encaixa; fora volta; nota por desvio % |
| GE-3 | `trace` | ketchup, mustard, cream cheese | zigue-zague perfeito, só metade, rabisco por cima do pão, **traço fora do pão** | Cobertura/excesso (`CoverageError` = max(100-cob, excesso x 1,5)); traço fora do plano do pão ignorado; `Fill` (hold) como alternativa |
| GE-4 | `slide` | cheese | centro, borda, solta fora | Desvio % |
| GE-5 | `taps` | bacon | no tempo, adiantado, atrasado, 1 toque a mais | Erro médio em ms; toque extra não cria 4º anel |
| GE-6 | `hold` | potato_sticks | soltar no anel, antes, depois, passar de `Meter.Max` | % da barra; teto respeitado |
| GE-7 | `grill_flip` | virar | ver §1.1 (G-8 a G-11, G-13) | Nota carimbada no **servidor** (`Grade.FlipScore`) |
| GE-8 | Todos, **Tap mode** (tocar e tocar) | todos | pega com 1 toque, solta com 2º | Mesma nota esperada; sem arrasto necessário |
| GE-9 | Todos, **Assist** (+30%, hitbox x1,3, guia sempre visível) | todos | repetir GE-1..6 com Assist | Faixa mais folgada (ex.: desvio 7,5 de `bun_cut` vira Perfect só com Assist, ver `/dev prep grade`); guia sempre visível |
| GE-10 | Todos, **Reduced motion** | todos | ligar | Câmera por corte, contorno fixo, sem giro (fade 120 ms), sem rajada |

---

## 3. Casos por ferramenta (ferramenta 3D presa ao ponteiro)

| ID | Ferramenta | Verificar | Esperado |
|---|---|---|---|
| FE-1 | Faca (AST-014, peça separável) | desce e inclina na direção do corte; brilho Neon mínimo no contato | Sem `PointLight`; some ao concluir o corte; volta à tábua ao sair |
| FE-2 | Garrafa (ketchup/mustard) | inclina e escorre; nível `Fill` baixa; fio em arco; gotas | Pivô no bico; segmentos criados só com a garrafa inclinada e sobre o pão |
| FE-3 | Garrafa cream cheese (variante branca) | idem | Distinta por forma/rótulo |
| FE-4 | Fatia de queijo | balança ao ser levada, squash ao cair | Sem física real; solta fora = volta em arco |
| FE-5 | Tira de bacon | segue o ponteiro, 1 por toque | Máx. 3 toques por topping |
| FE-6 | Pitada de batata (concha/lata) | monte cresce com a duração | Monte vira `Topping` ao fechar; escala com pivô na base |
| FE-7 | Salsicha arrastada (grelha e trilho) | inclina, sombra circular, vapor | Rolete do trilho oculto localmente; volta intacto se soltar fora |
| FE-8 | Espátula/cursor da grelha (se houver) | pivô na ponta | Só visual |
| FE-9 | Uma ferramenta por vez, todas destruídas no Leave | Contar `Instance`s `Prep*` no Workspace antes e depois de Leave | Delta zero (ver PF-3) |
| FE-10 | Ferramenta + 4 jogadores | Ferramenta é **local**; os colegas **não** veem (salvo mão fantasma, `GhostHand = false`) | Sem rede por frame |

---

## 4. Matriz plataforma x jogadores x dia/noite

### 4.1 Plataformas

| ID | Plataforma | Como | Particularidades a observar |
|---|---|---|---|
| PL-A | **Mouse + teclado** (1280x720 e 1920x1080) | F5 | Hover com contorno; arrastar com botão esquerdo; `Tab` troca seção, `Enter` = Next, `Esc`/`Q` = Leave |
| PL-B | **Toque 667x375** (iPhone SE no emulador; real se houver) | Device Emulator | Sem hover: alvo acionável **pulsa**; offset de 28 px nos arrastos; alvo >= 44 px; joystick do Roblox escondido; notch/`DeviceSafeInsets` |
| PL-C | **Toque 844x390** | idem | Idem; abas 104x44 |
| PL-D | **Gamepad sem mouse** (mouse desligado/desconectado) | Controller emulado ou físico | Stick move o marcador com **atração** a < 80 px; **A** pega/solta; **X** próximo alvo na ordem do estágio; **LB/RB** seções; **D-pad** ticket; **Y** Next; **B** Leave; glifos nos botões; tudo jogável **sem tocar no mouse** |

### 4.2 Matriz mínima obrigatória (célula = percurso completo: entrar, Grill, Board, Toppings (K=2), Next, Serve, sair)

Marcar `P` (passou), `F` (falhou, com nota), `B` (bloqueado). **Dia** = loja aberta de dia; **Noite** = fase Night (sanidade visível no topo esquerdo, DOF/luz, emissivo nos alvos).

| Plataforma | 1j dia | 1j noite | 2j dia | 2j noite | 3j dia | 3j noite | 4j dia | 4j noite |
|---|---|---|---|---|---|---|---|---|
| Mouse | | | | | | | | |
| Toque 667x375 | | | | | | | | |
| Toque 844x390 | | | | | | | | |
| Gamepad (sem mouse) | | | | | | | | |

Mínimo para "Feito" na TASK-214: **toda a linha 1j e 4j**, mais 2j e 3j em Mouse e Toque 667x375. Em cada célula conferir:

- Tabelas 1.1 a 1.4 sem regressão (percurso, não todos os casos em todas as células).
- Noite: o alvo continua legível (emissivo/Neon nas bordas; **nenhuma luz nova**, orçamento de 17/18 luzes do trailer, R11); `Highlight` visível.
- 4j: cada jogador aciona só o próprio assento (ver §7).
- Gamepad: o foco visual (contorno) acompanha o alvo 3D **e** o chip 2D em foco; nenhum controle exige mouse.

---

## 5. Coordenada do ponteiro e enquadramento (R2, R3)

### 5.1 Ponteiro (R2, TASK-196)

O risco: `InputObject.Position` (mouse/toque) vem no espaço GUI com inset do topo; o cursor virtual do gamepad vem na viewport. Um raio errado troca o alvo por dispositivo.

| ID | Passos | Esperado | Dep. |
|---|---|---|---|
| AIM-1 | `/dev prep ray`, clicar em 5 pontos conhecidos (cantos e centro de um alvo grande) em **1280x720**, **844x390** e **667x375** | Hit e uv impressos batem com o alvo sob o clique, desvio < 1 px de tela; mesmo resultado nas 3 resoluções | 196 |
| AIM-2 | Repetir em **toque emulado** (com e sem notch/safe insets) | Raio sai do ponto **deslocado** (offset 28 px) só em arrastos; toques discretos usam o ponto do dedo (R4) | 196 |
| AIM-3 | Repetir no **gamepad** (cursor virtual) com a barra do Roblox aberta e fechada | Cursor e marcador 3D coincidem; inset do topo somado uma vez, não duas | 196 |
| AIM-4 | Janela redimensionada no meio do modo (Studio) | Sem salto de alvo; uv e hover se atualizam | 196 |
| AIM-5 | Toque no **limite** entre dois alvos vizinhos (ex.: dois roletes) | Aciona o alvo cujo contorno estava aceso antes de soltar; nunca os dois | 196, 203 |
| AIM-6 | Alvo mínimo: medir em captura o hitbox de cada `TargetKind` em 667x375 | >= 44 px em ambos os eixos (>= 0,31 stud), x1,3 com Assist; salsicha com hitbox 1,1 x 0,5 | 196, 200 |
| AIM-7 | Mover o mouse sem parar por 5 s e contar raios (MicroProfiler / contador) | **<= 1 raio por frame**; **0 raio** com o ponteiro parado | 196 |
| AIM-8 | Decoração, NPC, prato e rig na frente do alvo | O raio (`Include` só em `PrepTarget`) **atravessa** tudo; alvo atrás continua clicável | 196 |
| AIM-9 | Atravessar o botão de UI 2D (Next, Leave, aba) com o ponteiro | A UI 2D tem prioridade; o clique não vaza ao alvo 3D por trás | 196, 198 |
| AIM-10 | Sem hitbox no mapa (apagar um `PrepTarget` de teste, **só em cópia local, sem salvar**) | Fallback pela caixa do modelo + **um aviso** no Output (não erro) | 196, 200 |

### 5.2 Enquadramento (R3, S2, TASK-200)

Captura de tela por vista (Studio, 3 resoluções) anexada ao resultado. Critérios por vista:

| ID | Vista | Deve caber no quadro, em 667x375 **e** 844x390 | Observação |
|---|---|---|---|
| FR-1 | Grill | roletes 1..8, caixa de salsichas, trilho | Hitbox >= 44 px em cada rolete; sem sobreposição de alvos |
| FR-2 | Board | tábua do assento, caixa de pães, faca, trilho | Idem; em 4j, a tábua vizinha não cobre o alvo próprio (R5, espaçamento >= 1,1 stud) |
| FR-3 | Toppings | pão aberto + salsicha **e** 6 tigelas **e** lixeira | Se não couber em `Fov` 55, âncora com `Fov` 62 a 65; documentar o valor |
| FR-4 | Window | janela, balcão do prato, cliente em `Q1` | Luz/NPCs não tampam o cliente (R6) |
| FR-5 | Cada vista, **cada** `Station_n` (1 a 4) | Mesmo enquadramento nas 4 estações | Âncoras `CamAnchor_<Vista>`/`Focus_<Vista>` com cadeia de reserva `Toppings -> Board -> Build` |
| FR-6 | Transição entre vistas | Câmera desliza em `Travel` 0,35 s; corte com Reduced motion; sem atravessar parede | |
| FR-7 | Entrada pelo prompt da grelha (`PromptStep = Grill`) e pelo da tábua (`Board`) | Abre **direto** na vista do passo | |
| FR-8 | DOF/vinheta | `NearIntensity = 0` com objetos 3D; DOF desligado em qualidade <= 3 | |
| FR-9 | Mapa: nada alterado fora do escopo | `Place.diff` = 0 antes e depois do teste; sem `Place.run` | |

---

## 6. Rollback por camada (sem código)

Mudar o valor em `Content/Prep.luau` (cópia local de teste, **não commitar**), `rojo` sincroniza, **reentrar** no modo.

| ID | Alteração | Esperado | Dep. |
|---|---|---|---|
| RB-1 | `Rules.ThreeD = false` | **Tudo volta ao 2D**; nenhum `World/*` roda; nenhum hitbox `PrepTarget` criado; fluxo completo 2D passa (Order, Grill, Build, Serve) | 194, 203 |
| RB-2 | `ThreeD = true`, `World.Stages.Grill = false` | Grill 2D, demais estágios conforme seu flag; **nenhuma mistura quebrada** (ex.: Grill 2D coleta e o Board 3D vê a salsicha no trilho) | 203 |
| RB-3 | `Stages.Board = false` e `Stages.Toppings = false` (a chave `Build` se divide, §3.0) | Board/Toppings 2D; o 2D aceita a mesma sessão (`PrepBegin`/`Finish`) | 204, 205 |
| RB-4 | `Stages.Serve = false` / `Stages.Order = false` | Cartões 2D de Order/Serve; `PrepOrder` idêntico | 206 |
| RB-5 | Virar o flag **durante** o modo (em Play) | Aceito: vale na **próxima** entrada; modo corrente não quebra nem vaza | 194 |
| RB-6 | `WorldKitchenPrompts = true` | Prompts antigos do mundo voltam (`grill_place`, `bun_cut`, ...), fluxo antigo funciona; **nenhum** duplicado com o modo 3D | 194 |
| RB-7 | Mudar `Tabs` (`Order`/`Build` -> `Board`/`Toppings`) | `PrepTab.Step`/`PrepSeats.Step` enum atualizado; `PromptStep` do mapa (`Build` -> `Board`) coerente; **sem erro de schema Lync** no start | 194, 200 |
| RB-8 | `World.Editable = false` (padrão) | Nenhum `EditableMesh` criado (checar `Stats`); corte por swap `Closed -> Open` | 204 |
| RB-9 | `World.Editable = true` e falha de `CreateEditableMeshAsync` (conta sem acesso, 2ª conta) | `pcall` captura; **queda automática** para swap/segmentos; sem erro no Output | 218 (opcional) |
| RB-10 | Qualidade gráfica <= 3 | Sem `Highlight` (anel de piso Neon), sem rajadas, sem vapor, DOF off; **tudo continua jogável** | 203 |
| RB-11 | `Rules.World.GhostHand = false` | Nenhum pacote `PrepHand` (se existir) | 208 |

---

## 7. Co-op (assentos, Plate, Kick)

Ambiente: Test > Clients and Servers, N = 2, 3, 4. `PrepSeats` ativa `clamp(membros, 1, 4)`; sozinho só a estação 1 (`/dev prep enter 2` responde `NoStation`: esperado).

| ID | Passos | Esperado | Dep. |
|---|---|---|---|
| CO-1 | 2j: ambos usam o prompt Work **no mesmo frame** | Assentos distintos (1 e 2); nenhum assento duplicado; o 2º recebe o próximo livre; `Busy`/`Seated` só se cheio | 170 |
| CO-2 | 4j: quatro entradas; um 5º cliente (se houver) | 4 assentos; 5º recusado `Busy`; `StationTag` com nome e seção de cada um | 170 |
| CO-3 | Cada jogador só enxerga/aciona o alvo do **próprio** `Att_Bun n` | Raio do jogador 2 **não** acerta a tábua do 1 (B-10); sem mão cruzando | 204 |
| CO-4 | **Plate dos colegas** (N3): jogador 1 corta, põe salsicha e 1 topping; jogador 2 observa | Na tábua do 1, o jogador 2 vê pão fechado/aberto, salsicha e topping como **modelos prontos** (sem segmentos de molho); sem rede por frame; a máscara só **cresce** | 195, 208 |
| CO-5 | Entrada tardia: jogador 2 entra com o 1 no meio do prato | Prato do 1 aparece pela máscara `Plate`; grelha/trilho corretos por `Stations`/`Rail` | 195, 208 |
| CO-6 | Dois jogadores tocam a mesma salsicha no mesmo instante (Place/Flip/Collect) | **Um** vence; o outro recebe `Reason` e a predição desfaz com tremida; estoque e trilho sem duplicata (`TakeStock` síncrono) | 203 |
| CO-7 | Jogador 1 vira a salsicha | Jogador 2 **vê** virada (`Stations.Flip`), inclusive entrando depois | 195, 203 |
| CO-8 | Jogador 1 sai (Leave) no meio do prato / desconecta / vai Away | Assento liberado; **pão reservado devolvido**; marionete some nos outros; sem modelo órfão; `SeatIdle` 60 s sem heartbeat também libera | 170, 208 |
| CO-9 | 2j disputam o mesmo ticket | Chip de conflito, sem trava; o servidor serve o primeiro, o 2º recebe recusa limpa | 206 |
| CO-10 | **Kick por anomalia** (`/dev anomaly <ANM-###>` com os jogadores no modo, fase Night) | Sinal expulsa em ~0,4 s com tremor curto e 0,5 s sem input; `PrepResult Kick` (`KickSignal`); prato `Parked`/pão devolvido; ferramenta e hitboxes **destruídos**; reentrada travada só durante `Signal` + `CueLock` (6 s) | 181 |
| CO-11 | Kick: sanidade troca de faixa (`KickSanity`), `Down` (`KickDown`), cutscene/ligação (`KickCutscene`/`KickCall`), fim de turno (`KickClosing`), ladrão (`/dev thief`, `KickThief`) | Cada um expulsa e limpa o 3D; a câmera volta ao normal; o jogador **não** fica com controle travado | 181 |
| CO-12 | Kick **durante um arrasto** (salsicha na mão / gesto em curso) | Gesto cancelado sem nota parcial; nada enviado após o Kick; nenhum erro de "alvo destruído" | 181, 203 |
| CO-13 | Kick de um jogador não afeta os outros assentos | Só quem estava sob o sinal sai (ou todos, se o sinal for global); os demais continuam | 181 |
| CO-14 | Saída por inatividade (`ClientIdle` 20 s sem input) | `Parked` local (`KickIdle`); retomar sem perder o prato | 170 |
| CO-15 | 4j: percurso de 5 pratos cada um, em paralelo | Estoque, dinheiro e trilho coerentes (soma de vendas = soma de `Sale`); sem pão/salsicha criados ou perdidos | tudo |

---

## 8. Abuso e anti-exploit

Forjar eventos: no Studio, no **cliente** (Command Bar do cliente, `Players.LocalPlayer`), usando o `Net` do Lync (mesma API que o controller). Cada caso deve terminar com **servidor intacto** (sem erro no Output do servidor, sem estado inconsistente) e **sem punição a jogador legítimo**.

| ID | Ataque | Esperado | Dep. |
|---|---|---|---|
| AB-1 | `PrepGrill` em rajada: 200 pacotes (`Place`) em 1 s | Limite por tipo (`Rules.Rates`) e **`GLOBAL_RATE` 6/s** por jogador: excesso **descartado em silêncio**; no máximo 1 salsicha por pedido válido; estoque cai só pelo que passou | 170 |
| AB-2 | `PrepGrill Flip` em rajada na mesma salsicha | 1 virada; demais `Flipped`; nota única; sem duplicata em `Stations.Flip` | 170, 195 |
| AB-3 | `PrepGrill Flip`/`Collect` com `Slot` de **outro** estado (vazio, 9, 0) | `Empty`/`Invalid`; sem mutação; sem erro | 170 |
| AB-4 | `Flip` fora da janela (adiantado) | Aceito como "cedo" **só** com a nota que o servidor calcula (Messy); jamais Perfect | 170 |
| AB-5 | `PrepOrder` em excesso: `Take`/`Serve` x100 com `Npc` de cliente inexistente, de outro assento, que já saiu | Descartado/`NoTicket`; **nenhuma** venda duplicada nem dinheiro creditado; `Rate` na 2ª rajada | 170 |
| AB-6 | `PrepOrder Serve` **sem** estar sentado, **sem** prato, ou com a loja fechada | Recusa (`NoSession`/`NotSelling`/`Locked`) | 170 |
| AB-7 | `PrepBegin` repetido (x50) | Um prato por assento; pão reservado **uma** vez; excedente recusado | 170 |
| AB-8 | `PrepFinish` **forjado**: `Cut`/`Place` 100, 3 toppings Perfect, `Ms` pequeno | `TooFast` (< `MinPlate` 1,8 + 0,8 x K) no relógio do **servidor**; sem item criado | 170 |
| AB-9 | `PrepFinish` com `Ms` maior que o tempo do servidor + 1,5 s | `Invalid` (`MsSlack`) | 170 |
| AB-10 | `PrepFinish` Perfect **lento**: forjar tudo 100 com tempo plausível | Aceito (pior caso documentado: gorjeta +$1); teto por `PerfectMin` impede Perfect abaixo do piso | 170 |
| AB-11 | `PrepFinish` com topping repetido, 4 toppings, chave inválida, `Blocked`, sem estoque | `Invalid`/`NoStock`; **nada muda** (tudo-ou-nada) | 170 |
| AB-12 | `PrepFinish` **sem** `PrepBegin` / após `PlateMax` / por jogador sem assento | `NoSession`; nenhum `hot_dog` | 170 |
| AB-13 | **Plate forjado** (`PrepTab.Plate`): máscara que diminui, sobe mais de `MaxToppings` bits de topping, usa bit além de `ToppingKeys`, valor 255 | Ignorado sem erro; o `Finish` **revalida tudo** (a máscara é cosmética, nunca autoridade); colegas não veem lixo (máscara só cresce, zera no Begin/Finish/Trash/Leave) | 195 |
| AB-14 | `PrepTab` em excesso (> 4/s) e com `Ticket` de cliente inexistente | Excesso descartado; ticket inválido tratado como 0; assento intacto | 170 |
| AB-15 | **Tempos impossíveis**: `/dev prep finish` sem `force` (0 s) | `TooFast`; com `force` (`/dev prep finish force ketchup`) passa e mostra Perfect | 170 |
| AB-16 | `Grade.Plausible` em Luau puro e `/dev prep grade` | Casos de plausibilidade: sob o piso `TooFast`, no piso `ok`, `Ms` além do slack `Invalid`, > `PlateMax` `NoSession`; **N/N ok** | 170 |
| AB-17 | `PrepGrill Place` com `Slot` preferido = ocupado/negativo/9 | Primeiro livre ou `Invalid`; **nunca** sobrescreve salsicha existente | 195 |
| AB-18 | Jogador **longe** do trailer (> `Reach` 14 + `RANGE_SLACK`) manda qualquer `Prep*` sem assento | Recusa; sem mutação | 170 |
| AB-19 | Cliente mal-intencionado manda `PrepEnter` para a estação de **outro** (já ocupada) | `Busy`; sem troca de dono | 170 |
| AB-20 | Pacotes malformados (struct incompleto, enum fora da lista) | O Lync rejeita antes do handler; sem erro no Output do servidor | 170 |
| AB-21 | Spam de pacote após Kick/Leave | Descartado `NoSession`; sem reentrada | 181 |
| AB-22 | Estoque: dois clientes `Place` simultâneo com 1 salsicha em estoque | Um vence; estoque 0, nunca negativo | 170 |

Todos os casos AB: conferir **dinheiro, estoque, trilho e hotbar** antes e depois (`/dev kitchen`, `/dev economy`); a diferença deve ser exatamente o das ações legítimas.

---

## 9. Performance (P)

Medir em **667x375 qualidade 3 e 8**, 1j e 4j, noite. Ferramentas: MicroProfiler (Ctrl+F6), `Stats` (Performance Stats), Output do servidor, Network Monitor / contador de pacotes.

| ID | Métrica | Alvo | Como | Dep. |
|---|---|---|---|---|
| PF-1 | Quadros no foco | **>= 30 fps** (celular fraco: emulador com throttling/qualidade 3), p5 >= 30 em 2 min de jogo contínuo | `Stats` / MicroProfiler | 203+ |
| PF-2 | Raios | **<= 1 por frame**; 0 parado (AIM-7) | contador | 196 |
| PF-3 | **Vazamento em 20 entradas** | Entrar e sair 20x (`/dev prep enter 1` / `/dev prep leave`, ou prompt): `Instance Count`, memória de `Stats` e nº de `Connections` **sem crescimento** (tolerância: ruído < 1%); 0 hitbox `PrepTarget`, 0 ferramenta, 0 `Highlight`, 0 anel, 0 segmento de molho fora do modo | `Stats`, `#Workspace:GetDescendants()` antes/depois | 196+ |
| PF-4 | Rede | **<= 1 pacote/s por jogador em média, <= 6/s no pico**; `PrepSeats` <= 4 registros; **0 pacote novo** pelo 3D | Network Monitor, 5 min | 195+ |
| PF-5 | Orçamento de instâncias | Hitboxes <= 40; `Highlight` <= 12 vivos (qualidade <= 3: 0); anéis/discos pool de 10; segmentos de molho <= 24 por traço, <= 72 por prato, pool de 80; modelos clonados: 1 ferramenta, 1 prato local, <= 3 fantasmas | contagem por tag/nome | 196+ |
| PF-6 | Partículas | <= 150 vivas e 8 emissores (teto de `Fx`); qualidade <= 3 sem rajadas | `Fx` | 203+ |
| PF-7 | Tweens | <= 6 simultâneos; um único `RenderStepped` no foco; **zero** conexão `RenderStepped` após Leave | `getconnections`/contagem manual | 196+ |
| PF-8 | Cor do cozimento | 10 Hz (não por frame) | MicroProfiler | 203 |
| PF-9 | `ViewportFrame`/`SurfaceGui`/`BillboardGui` por alvo | **nenhum** (E-4) | grep + Explorer | 196+ |
| PF-10 | Servidor | Tick de 2 Hz do `PrepService`; sem salto em `Heartbeat` com 4 jogadores no modo | MicroProfiler servidor | 170 |
| PF-11 | EditableMesh (só se `Editable = true`) | <= 6 malhas por cliente, destruídas no Leave; custo de `lerp` < 0,3 ms/frame | `Stats` | 218 |
| PF-12 | Memória 4j, 30 min de jogo | Sem tendência de alta | `Stats` | tudo |
| PF-13 | Corte de reserva (se PF-1 falhar) | Aplicar, **nesta ordem**: qualidade <= 3 sem Highlight/rajadas; hover do gamepad por quadro alternado; vapor some; reavaliar | prep-3d §8 | 203+ |

---

## 10. Output limpo

| ID | Verificação | Esperado |
|---|---|---|
| OUT-1 | Percurso completo (§4.2) em cada plataforma, **cliente e servidor** | **Zero erros** (vermelho) e zero warnings novos do 3D; `warn` só os documentados (ex.: `/dev prep ui: not now`, fallback de hitbox **uma vez**) |
| OUT-2 | Start do Lync | Sem erro de schema (`drop.section`, enum, `keyBy`) |
| OUT-3 | Leave durante qualquer gesto, Kick durante arrasto, desconectar no meio | Sem "attempt to index nil", "destroyed", "invalid member" |
| OUT-4 | Reentrar 20x (PF-3) | Output limpo na 20ª entrada tanto quanto na 1ª |
| OUT-5 | Saída forçada em todas as seções | Idem |
| OUT-6 | Rollback (RB-1 a RB-6), flags no meio | Idem |
| OUT-7 | Nenhum `print` de debug restante em `World/**` | grep `print(` vazio |
| OUT-8 | `modux check` e `analyze.ps1 -Detail` | 0 erro, 0 ciclo |

---

## 11. HUD: topo livre e abas embaixo sem sobreposição

Em **cada** resolução (667x375, 844x390, 1280x720), 1j e 4j, dia e noite, com e sem Assist/Tap mode, e com o **menu do Roblox** visível.

| ID | Verificação | Esperado (px de UI, 667x375, prep-3d §5) |
|---|---|---|
| HUD-1 | **Topo esquerdo livre**: sanidade (noite) visível e legível | Não somem em foco (`Isolate` não esconde `Hud`); nada nosso em y <= 110 à esquerda além do que já existia |
| HUD-2 | **Topo direito livre**: dinheiro e relógio visíveis | 148x32 em right 12+i, y 10; **não** coberto por nada |
| HUD-3 | Topo central: só o cartão de progresso (verbo da seção + barra de 10 px com 4 divisões + 3 pips Cut/Place/Top) | (200, 8) 267x40, termina em x 467 < status 507; **não toca** o menu do Roblox |
| HUD-4 | `HudOrder` (cartão do pedido do mundo) some em foco; ticket 2D à esquerda no lugar | Ticket (12+i, 100) 136x120, abaixo da sanidade |
| HUD-5 | **Abas embaixo**, 4 de 84x44 centradas, vão 4, y 319 (667x375); 104x44 em 844x390 | Cobrem x 160 a 508; **não sobrepõem** Leave (12..56), Assist (60..104), Tap (108..152) nem Next (527..655) |
| HUD-6 | Sem sobreposição entre quaisquer elementos 2D | Dica (y 281..313) acima das abas; toast no lugar da dica; selo do prato nunca sobre o gesto em curso |
| HUD-7 | Centro livre (x 168 a 520, y 56 a 275 em 667x375) | **Só mundo**: nenhum 2D no retângulo central |
| HUD-8 | Alvos 2D >= 44 px, texto >= 14 px, sem vermelho, em inglês | Medir em captura |
| HUD-9 | Hotbar nativa, chat, `PlayerList` e `TouchGui` escondidos em foco | Voltam ao sair (Leave e Kick) |
| HUD-10 | Badges: Grill = nº de prontas; Serve = prato; atualizam em tempo real | Sem "+N" incorreto |
| HUD-11 | Gamepad: glifos (Y Next, B Leave, LB/RB seções, X próximo alvo, A pegar/soltar); D-pad troca ticket | Foco visível |
| HUD-12 | Seções em sequência: Next avança; abas livres para voltar; **Serve só habilita com prato pronto** | `Order` não existe mais como aba |
| HUD-13 | Barra de condimentos opcional (Q-237), se ligada | (563, 56) 92x140; não toca status (y <= 42) nem Next (y >= 311); **só pega a ferramenta**, não aplica topping |
| HUD-14 | Notch/`DeviceSafeInsets` (iPhone emulado) | Nada fica sob o entalhe; bases de gesto respeitam os insets |

---

## 12. Acessibilidade

| ID | Verificação | Esperado |
|---|---|---|
| AC-1 | Daltonismo (simulação deuteranopia no Studio ou captura processada) | Anel, check, silhueta do selo e som carregam a informação; Mustard x Cream separados por contorno Ink e por forma |
| AC-2 | Toda ação tem som **e** equivalente visual | Conferir tabela §2.4 do prep-3d.md |
| AC-3 | Reduced motion | GE-10 |
| AC-4 | Assist/Tap mode alternam em jogo e persistem na sessão | Ver GE-8/GE-9 |
| AC-5 | Háptico no gamepad quando houver motor | Pulso em pegar/soltar/virar; sem erro se não houver |
| AC-6 | Voz/tutorial: sem a palavra "sausage" na fala TTS e sem número de telefone | Revisão de texto |

---

## 13. Roteiro de teste manual para o dono (10 minutos, pt-BR)

**Antes de começar (1 min).** Abra o Studio com o projeto sincronizado (`rojo serve`), salve suas edições à mão. **Não rode `Place.run`.** Abra o Output (View > Output) e deixe-o visível. Para começar limpo: `/dev intro skip` e `/dev tutorial reset` só se quiser ver o tutorial; senão, pule. Garanta loja **aberta** e salsicha e pão no estoque (`/dev kitchen` mostra o estoque).

Marque `[ok]` ou `[falhou: o que viu]` em cada linha. Anote o **horário** do que falhar.

### Parte A: sozinho, mouse (4 min)

1. (0:30) Aperte F5. Com a loja aberta, vá à **grelha** e use o prompt **Work**. Esperado: a câmera vai para a grelha e **não aparece nenhum painel 2D no centro** (nada de "Add +", nada de "Rail empty"). Você vê as salsichas e a grelha de verdade; as salsichas "fantasmas" convidam nos roletes livres. Abas **embaixo**, dinheiro e relógio **livres no topo**.
2. (0:30) Passe o mouse sobre a caixa de salsichas e sobre um rolete: devem acender (contorno). Arraste uma salsicha da caixa até o rolete 5 e solte. Esperado: ela cai **no rolete 5**; estoque -1.
3. (0:40) Espere a cor subir. Quando o **anel converge**, toque na salsicha quando ele fechar (meio do tempo). Esperado: giro de 180 graus e estouro de estrelas (Perfect) ou faíscas (Good). Toque cedo demais em outra: só treme, nada acontece. Anote a nota que aparece.
4. (0:30) Quando uma ficar pronta (contorno verde **com check**), toque nela: ela salta ao **trilho**. Esperado: o trilho real mostra +1.
5. (0:40) Clique na aba **Board**. Arraste um pão da caixa para a tábua. Pegue a faca e **arraste ao longo da linha tracejada** da esquerda à direita. Esperado: migalhas, o pão abre. Depois arraste a salsicha da frente do trilho até o vão do pão. Esperado: ela encaixa; se soltar fora, volta.
6. (0:50) Clique em **Toppings**. Esperado: pão, **6 tigelas** e a lixeira todos no quadro. Pegue a garrafa de ketchup e trace o zigue-zague (a garrafa inclina). Pegue o queijo e solte no alvo. Tente um **4º topping**: não deve deixar. Aperte **Next**. Esperado: o pão fecha, aparece o selo de nota.
7. (0:30) Aba **Serve**. Arraste o prato até a **janela** com o cliente certo fixado no ticket (ou toque o cliente para pegar o pedido antes). Esperado: veredito (círculo+check) e dinheiro/gorjeta sobem.
8. Saia com **Leave** (embaixo à esquerda). Esperado: a câmera volta, nenhuma ferramenta ou contorno fica solto no mundo.

### Parte B: comandos e abuso (2 min)

9. Com `/dev prep grade`: precisa terminar com **N/N ok** (hoje 93/93). Se aparecer FAIL, anote e pare.
10. `/dev prep ray`: clique no centro de um alvo e em dois cantos; o alvo impresso deve ser o que você clicou. (Disponível depois da TASK-196.)
11. `/dev prep enter 1` e depois `/dev prep finish` (sem `force`): deve responder **TooFast**. Repita com `/dev prep finish force ketchup`: passa e dá Perfect.
12. `/dev prep kitchen`: sem nenhum FAIL (estoque e trilho são restaurados no fim).
13. Abuso: na Command Bar do **cliente**, dispare `PrepGrill` com `Place` 50 vezes seguidas. Esperado: só poucas salsichas na grelha (limite de 6 pacotes/s), servidor sem erro vermelho.

### Parte C: toque e gamepad (2 min)

14. Troque o emulador para **iPhone SE (667x375)**. Entre no modo. Esperado: nada se sobrepõe; os botões embaixo (Leave, Assist, Tap, abas, Next) estão separados; alvos fáceis de tocar com o dedo; o alvo certo **pulsa** sozinho.
15. Ligue **Tap mode** e faça uma salsicha com **toque, toque** (pegar, soltar). Esperado: funciona sem arrastar. Ligue **Assist**: a guia fica sempre visível.
16. Desligue o mouse e use o **gamepad**: stick move o marcador (gruda nos alvos), **A** pega/solta, **X** salta ao próximo alvo, **LB/RB** trocam de seção, **Y** Next, **B** Leave. Esperado: você faz um prato **sem tocar no mouse**.

### Parte D: 2 jogadores e saída forçada (2 min)

17. Test > Clients and Servers, 2 clientes. Os dois entram no modo ao mesmo tempo. Esperado: **assentos diferentes**, cada um vê o nome do outro (`StationTag`).
18. Jogador 1 vira uma salsicha. Esperado: o jogador 2 **vê a salsicha virada**. Jogador 1 monta um prato: o jogador 2 vê o prato na tábua dele (cru, só modelos prontos).
19. Os dois tocam a mesma salsicha ao mesmo tempo: só um leva; o outro vê um tremor.
20. À noite, `/dev anomaly <ANM-###>` (ou `/dev anomaly agenda` e o nome que aparecer): em ~0,4 s os jogadores **saem do modo** (tremor curto). Aguarde ~6 s e tente reentrar: só então volta a deixar. Esperado: nada ficou travado nem no mundo.

### Fechamento (30 s)

21. **Output**: zero linhas vermelhas no cliente e no servidor. Conte os `warn`.
22. Rollback: em `Content/Prep.luau` ponha `Rules.ThreeD = false`, reentre: o 2D antigo volta. Volte para `true`. (Vale só em cópia local, não commitar.)
23. Anote **três coisas** que mais atrapalharam (fps, alvo difícil de tocar, câmera ruim, texto ilegível) para a TASK-212.

---

## 14. Resultados (preenchidos pela TASK-214)

Ainda **não executado**. Cada caso recebe `Passou`, `Falhou` (arquivo:linha ou captura) ou `Bloqueado (TASK-###)`; o veredito da TASK-214 sai em `Feito` ou `Falhou`. Pendências herdadas do registro do dia: espaço de coordenadas do toque/cursor (AIM-1 a AIM-3) e o flip já feito que não vinha na rede (G-16, CO-7).

| Seção | Passou | Falhou | Bloqueado |
|---|---|---|---|
| §0 gate | | | |
| §1 seções | | | |
| §2 gestos | | | |
| §3 ferramentas | | | |
| §4 matriz | | | |
| §5 ponteiro e enquadramento | | | |
| §6 rollback | | | |
| §7 co-op | | | |
| §8 abuso | | | |
| §9 perf | | | |
| §10 Output | | | |
| §11 HUD | | | |
| §12 acessibilidade | | | |

## 15. Perguntas ao dono que mudam o resultado esperado

- **Q-222** (G-12): salsicha **não virada** é Messy ou Good? Hoje `Unflipped` em `Grades` (confirmar valor).
- **Q-228** (S-8): cliente em `Q1` visível na vista Window conta como "ver" anomalia?
- **Q-234**: o 2D é removido depois do QA (TASK-215). Enquanto não houver resposta, RB-1 a RB-4 permanecem obrigatórios.
- **Q-235** (RB-8, RB-9): a chave "Allow Mesh / Image APIs" só importa se `Editable` for ligado.
- **Q-237** (HUD-13): barra de condimentos opcional.
