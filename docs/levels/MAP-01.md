Status: Rascunho

# MAP-01 — "Ninth & Juniper" (a esquina do carrinho)

Autor: level-designer. Versão 1: 2026-10-08. **Revisão 2 (2026-10-08): conciliação com DEC-086 a DEC-099, `story/anomalies.md` (Aprovado), `story/ending.md` (Aprovado), `story/world.md`, `story/characters.md` e `story/script.md` (Rascunho).**
**Revisão 3 (2026-10-08): conciliação com DEC-100 a DEC-129 e `art/style-guide.md` (Aprovado, DEC-126); corrige os itens LD-1 a LD-21 de `consistency-report.md`.**
**Revisão 3, ajuste final (2026-10-08): DEC-130 (sem semáforo no MVP, revoga DEC-120); rodada 17 (`Q-128`, opção B, secretário registrando); postes da Juniper a 8 studs com JL-09 a ~135 (LD-15 / P33); nota de P35.**
**Binding da onda 2 (2026-10-10, TASK-083): ponto novo `DROP-T` e `SIGN-T` como ponto (§5.1); poses `CART`/`TRL`/`TRL-SALE` = pivô do modelo; L1 e L3 ajustados para fora do poste e do banco (§5.3); grafo do ladrão (§9.1); §16 (binding no place); P40–P45. Provisório.**
**Binding da onda 3 (2026-10-10, TASK-098): esconderijos H1..H4 com `Slot` e `Hide_Pose` (§7.2); passantes com 7 caminhos de calçada e 17 nós novos (§9.3, `Content.WalkPaths`); `CutsceneMark1..4` e `CS-5W`/`CS-5E` (§11.1); AN/AS/WALKER-10/SS como pontos (§10.3); trânsito com `TrafficPath`/`TrafficLine`/`TrafficBox` (§9.5); §16.5–§16.6; P46–P50. Provisório.**
**Spawn e despawn (2026-10-10, level-designer, pedido do usuário; tudo Provisório):** regra "NPC nunca aparece nem some à vista" com pontos novos/movidos e contrato `Spawn`/`Despawn`/`SpawnKind`/`Door` (§9.8, `Content.Flow.Spawns`, `Content.WalkPaths`); **5 postes na Juniper** (JL-01..05 a cada 16, passos 0–4 + WALKER-10, §5.6); peças de balcão sem visual; ajudantes travados no Studio; `AutoDoor` nas portas; ângulo da aba recalculado (§16.8; P52–P59).
**DEC-221 (2026-10-10, architect a pedido do orquestrador):** esconderijos `H1..H4` (AST-041) **saem**; entra o botão da janela de serviço `TRL-SHUTTER` (`Prompt_Shutter` → `shutter_toggle`) ao lado de `TRL-SWITCH` e a aba `Awning` do AST-027 como peça animável (§7.2, §16.2, §16.5, §16.6, P51). Provisório.
Nomes de lugares vêm de `story/world.md` (`Q-096`): cidade **Bellmoor**, esquina **Ninth & Juniper**, **Ninth Avenue**, **Juniper Street**, **Ninth Street Mart**, **Bellmoor Savings**. O nome do mapa, a lavanderia, B1 e B4 seguem placeholders para o narrative-writer (DEC-022: textos do jogo em inglês).
Números de gameplay citados são valores iniciais ajustáveis (DEC-044). Medidas de mapa são **proposta do level-designer**; o que tem `[DEC-###]` é requisito decidido. `Provisório` = recomendação do level-designer que depende de pergunta aberta.
Anomalias: `ANM-001`…`ANM-010` = N1…N10 (DEC-096).

### O que mudou na revisão 2 (resumo)

| Tema | Antes | Agora | Fonte |
|---|---|---|---|
| Trailer | proposta "no Pad" | decidido: no Pad, no lugar do carrinho | DEC-086 |
| Trânsito | sem trânsito | carros andando de dia; zero depois das 9 PM (revisto na revisão 3: 1 carro raro à noite, FEAT-033); atropelamento com ragdoll fora da faixa | DEC-087, DEC-095 |
| Mercado | fim da Main St, porta para o leste em (−56, 0) | Ninth Street Mart no lado **sul** da Ninth, a oeste da Juniper Sul; porta na quina NE (−62, 34). Rota Pad ↔ Mart **de costas para a Juniper Norte**. (Na revisão 2 a rota não cruzava trânsito; **revisto na revisão 3**: cruza a Juniper Sul na faixa CW-1; o semáforo de DEC-120 saiu no ajuste final, DEC-130) | DEC-049, DEC-095, DEC-120, ANM-007 × ANM-010 |
| Ponto seguro | beco (18, 72), 39 studs | **sob o letreiro "OPEN 24 HOURS" do Mart**, (−58, 30), ~110 studs | `anomalies.md` N10 (Aprovado), `Q-093` |
| Relógio C-01 | relógio de poste | relógio da fachada do **Bellmoor Savings** | `anomalies.md` N3 |
| Janelas (N6) | B1 atrás do Pad | apartamentos **sobre o banco**, do outro lado da Ninth | `anomalies.md` N6, `world.md` §3 |
| Juniper Street | "Cross St", barreira em Z −96 | rua longa com fila de postes **JL-01..JL-09** (Walker e Hush) | `anomalies.md` N7, N10 |
| AN-08 | funcionário do Mercado | **retirada** (Opal é fixa e amigável). Âncora nova **AN-12** = vaga do long car | DEC-079, DEC-099, `Q-091` |
| Queda (sanidade 0) | banco do fundo | ambulância, reviver pago, spectate | DEC-091 a DEC-094 |
| Cutscene | POV sem avatar | POV compartilhada; jogadores da party se veem | DEC-088 |
| Personagens | R15 provisório | **R6** para todos; sem braços em 1ª pessoa | DEC-089, DEC-097 |
| Final | "a definir" | Walt sai do Mart; party sob o letreiro | DEC-075, DEC-076 |

### O que mudou na revisão 3 (resumo)

| Tema | Antes (revisão 2) | Agora | Fonte |
|---|---|---|---|
| Upgrades | prompt no próprio equipamento | **bancada na parede do fundo do Mart** (B1–B5 + S1); nenhum prompt de compra no veículo | DEC-101, DEC-106, FEAT-015 (LD-1) |
| Interior do Mart | só gôndolas, caixa e prateleiras de fundo | prateleiras + **expositor de frutas/verduras (cenário)** + **bancada de upgrades** + Opal no balcão; 36 × 32 mantido | DEC-101, DEC-109 (LD-2) |
| Juniper Sul | beco fechado; rota do Mart sem trânsito; T com PARE | **rua com trânsito de dia**; cruzamento de 4 braços com **semáforo**; travessia trailer ↔ Mart em **CW-1 com semáforo de pedestre**; CW-2, CW-3, CW-4 com semáforo. **Ajuste final: todos os semáforos saem** (DEC-130); Juniper Sul segue aberta (`Q-128` B) | DEC-120 (LD-4, LD-5), DEC-130 |
| Noite perdida | party acorda no banco do fundo | **todos em pé na calçada ao lado do trailer** (REV-1..4), ambulância indo embora sem sirene; banco é cenário | DEC-122 (LD-3) |
| Walker, passo 10 | mudava com Trailer Lights | **fixo** em (28, 29) | NPC-015, UPG-005 (LD-7) |
| Luzes | ≤ 10 à noite, JL-02..09 só emissivos | orçamento do style guide: **≤ 18 locais (alvo 14), ≤ 3 com sombra**, postes com `SpotLight` | style guide §5.1, DEC-126 (LD-14) |
| Trailer | "teto 10" | pé-direito **8,5**, altura externa **~11** (AST-027) | AST-027 (LD-17, AD-8) |
| Ambulância | ~3 s; luzes âmbar/brancas; médicos no teto de NPCs | tempos de FEAT-034 (8 s); barra **Mustard/Teal**; médicos descem na ida (DEC-114) e ficam **fora** do teto | FEAT-034, DEC-114, style guide (LD-10, LD-12, LD-13) |

### O que mudou no ajuste final da revisão 3 (resumo)

| Tema | Antes (revisão 3) | Agora | Fonte |
|---|---|---|---|
| Semáforos | SIG-T no cruzamento, SIG-1 em CW-1, SIG-3 em CW-3; linhas de parada por sinal | **nenhum semáforo**. SIG-T, SIG-1, SIG-3 **retirados** (IDs não reaproveitados). SL-W, SL-E, SL-1N, SL-1S, SL-3W, SL-3E ficam como **linhas de faixa**: carro só para nelas com reserva de NPC ativa (proposta `Q-129`). Jogador atravessa por conta e risco | DEC-130 (revoga DEC-120), DEC-095, DEC-103 |
| Juniper Sul | aberta a carros por causa do semáforo | **continua aberta** (TR-7..TR-10 mantidas); rota trailer ↔ Mart atravessa CW-1 sem semáforo | rodada 17, `Q-128` opção B (secretário registrando) |
| Regra de travessia | carro obedece ao sinal; NPC só no verde | **proposta**, alinhada com FEAT-033 `Traffic.Crossing` (Rascunho): PARE nas duas bocas da Juniper (Ninth preferencial); carro nunca para por jogador; NPC só atravessa em faixa com reserva, e com reserva os carros param na linha da faixa (§9.5) | `Q-129` (Provisório) |
| Ida ao Mart | ~28 s (com espera de verde) | **~25 s** (espera de brecha, média ~1 s, máx. ~5 s por travessia) | §6, FEAT-033 |
| Postes da Juniper | a 12 studs; JL-09 em Z −120, ~165 da janela | a **8 studs**; JL-09 em **Z −88, ~135** da janela | LD-15 / P33 (usuário); emenda o ~110 do style guide |
| BAR-N | Z −100 | **Z −76** (JL-08 e JL-09 continuam além do limite) | consequência dos postes |
| Semáforo (asset) | L01-39, ficha nova (AST-077) | **sai**; AST-077 obsoleto | DEC-130 |

---

## 1. Resumo

| Item | Valor |
|---|---|
| Tema | Esquina de Bellmoor, cidade pequena e simpática: cruzamento da Ninth Avenue com a Juniper Street (sem semáforo, DEC-130), banco com relógio e apartamentos em cima, estacionamento, mercadinho 24 h, prédios baixos de tijolo. De dia, cartunizado e movimentado (carros, pedestres); à noite, a mesma esquina vazia e silenciosa (DEC-009, `world.md` §5) |
| Função no loop | **Único mapa da run no MVP** [DEC-011, DEC-020]: cutscene inicial, todos os turnos de dia (carrinho), compra do trailer, todas as 10 noites (trailer no mesmo Pad) [DEC-086], final [DEC-075] |
| Jogadores | 1–4 da mesma party, servidor privado, **um carrinho/trailer para todos** [DEC-012, DEC-032, DEC-034]. Membro atrasado entra depois [DEC-098] |
| Desbloqueio | Disponível desde o início da run. O lobby é outro place (`Q-085`) |
| Turnos | Dia (carrinho, dias 1–5 e dias entre noites) e noite (Food Trailer) [DEC-036, DEC-037, DEC-052] |
| Área jogável | X −112..112, Z −88..80 (~224 × 168 studs; a Juniper Norte vai até BAR-N, Z −76; o estacionamento até Z −88) ao ar livre + interior do Mart (36 × 32) + interior do trailer (26 × 10). Ruas continuam visualmente até X ±136, Z −152 (Juniper Norte) e Z 120 (Juniper Sul); carros entram e saem fora de vista |
| Câmera | 1ª pessoa travada, câmera padrão do Roblox, sem braços [DEC-039, DEC-097]; cutscenes em POV compartilhada [DEC-088] |
| Personagens | todos R6 (jogadores e NPCs) [DEC-089, DEC-097] |
| Não é | labirinto, corredores ou salas para vasculhar (DEC-004). Rua aberta; só **dois** interiores (Mart e trailer), ambos de um cômodo |

## 2. Convenções e escala

- Origem `(0, 0)` = centro da pista da Juniper no eixo da Ninth (cruzamento), no chão (Y = 0).
- **+X = leste**, **+Z = sul**, **norte = −Z**. Coordenadas no texto são `(X, Z)` em studs.
- **Referencial do place (2026-10-10, decisão do usuário):** o mapa inteiro foi girado 180° em Y no Studio em volta de `(0, 33,94)`. Todas as coordenadas deste documento (e das tabelas das ferramentas) continuam no referencial MAP-01 acima; no place, um ponto `(x, y, z)` daqui fica em **`(−x, y, 67,887287 − z)`**, e as direções viram (norte = +Z do mundo, leste = −X do mundo). A transformação única é `MAP_FRAME` em `tools/assetplace/map_frame.luau` (§16.9).
- Personagem **R6** [DEC-089, DEC-097]: altura 5 studs (pernas 2, tronco 2, cabeça 1), olho ~4,5, largura 2. WalkSpeed padrão 16 studs/s (classes: Runner 18, Line Cook 15, DEC-069).
- Altura de bancada: **3,5 studs**, igual ao `art/style-guide.md` §4 (Aprovado, DEC-126: R6, olho 4,5, bancada 3,5). Proposta: fechar `Q-095` por DEC-126. **Exceção, DEC-157 (2026-10-10): bancada do carrinho (AST-026) a 3,0** do Pad (y 3,45 no mapa; Pad 0,45); trailer e demais bancadas seguem 3,5; style guide em `Q-153`. Trailer: pé-direito **8,5** sobre o piso a +2, altura externa **~11** (AST-027). Porta: 4 × 7,5.
- Trânsito em **mão direita**: na Ninth, sentido oeste (WB) na metade norte da pista, sentido leste (EB) na metade sul. Na Juniper (Norte e Sul), sentido sul (SB) no lado oeste, sentido norte (NB) no lado leste.
- Diagramas ASCII são **aproximados** (±4 studs). As tabelas de coordenadas (§5) são a fonte da verdade.

## 3. Mapa geral (ASCII)

Escala: **1 coluna = 4 studs (X)**, **1 linha = 8 studs (Z)**. Norte para cima. Cada linha começa no Z indicado e cobre os 8 studs seguintes.

```
  X →  -120      -80       -40       0         40        80
       |         |         |         |         |         |
 -152  ============================================================   rua do fundo (só visual; JN-IN / JN-OUT nas pontas)
 -144  ============================================================
 -136  ########################:::=v==^=:::########################
 -128  ########################:::=v==^=:::########################
 -120  ########################:::=v==^=:::########################
 -112  ########################:::=v==^=:::########################
 -104  ########################:::=v==^=:::#A######################   A = SP-A (beco lateral leste, além de BAR-N)
  -96  ########################:::=v==^=:::########################
  -88  ########################::W=v==^=:::#######.............####   W = JL-09 (−16, −88), ponto de partida do Walker
  -80  ########################::j=v==^=:::#######..........V..####   JL-08; estacionamento (V = van, AS-1)
  -76  ########################xxxxxxxxxxxx#######.............####   x = BAR-N (Z −76), limite do jogador (linha, não ocupa altura)
  -72  ########################::j=v==^=:::#######.............####
  -64  ########################::j=v==^=:::#######.....TTTT....####   T = trailer à venda (dias 1–5)
  -56  ########################::j=v==^=:::#######.....TTTT....####
  -48  ########################::j=v==^=:::#######.............####
  -40  ####################b###::j=v==^=:::###c###......!......####   b = lavanderia (SP-B); c = relógio do banco C-01
  -32  ::::::::::::::::::::::::::j=v==^=:::::::::::::...:::::::::::   calçada norte da Ninth (JL-02); ... = entrada do estacionamento
  -24  :::::::::::*::::::::::::::j=v==^=:::::::::::::.L.:::::::::::   L = AN-12 (long car); * = RL-END (final)
  -16  ==pppppppppppppppppppp==%%%======%%%=======%%====ppppppp====   NINTH AVENUE: faixa de estacionar (p) / meio-fio vermelho
   -8  <<<<<<<<<<<<<<<<<<<<<<<<%%%<<<<<<%%%<<<<<<<%%<<<<<<<<<<<<<<<   sentido oeste (WB)
    0  >>>>>>>>>>>>>>>>>>>>>>>>%%%>>>>>>%%%>>>>>>>%%>>>>>>>>>>>>>>>   sentido leste (EB)
    8  ===============mmmmm====%%%======%%%===aaaa%%=======XXXXX===   faixa do meio-fio sul (sem estacionar)
   16  :::::::::::::::::::::::::::=v==^=::F:::rrrr::::::::l::::::::   calçada sul; boca da Juniper Sul (PARE em SL-S, proposta `Q-129`)
   24  ::::::::::::::SSS::::::::::=v==^=::::5:432:1:::::::::::::::E   fila Q5..Q1; S = ponto seguro
   32  #####MMMMMMMMDSSS_______:::%%%%%%:::oCCCCCCC,,##############   Mart / praça / CW-1 (sem semáforo) / Pad
   40  #####MMMMMMMMM__________:::=v==^=:::,,,@@@@,u,d#############
   48  #####MMMMMMMMM__________:::=v==^=:::,,,,,,,,,,##############
   56  #####MMMMMMMMM##########:::=v==^=:::,,,,,,,,l,##############
   64  ########################:::=v==^=:::########################
   72  ########################:::=v==^=:::########################
   80  ########################xxxxxxxxxxRx########################   x = limite do jogador BAR-S (Z 80); R = ST-R além do limite (18, 92)
                                  ^ JUNIPER STREET (norte e sul: trânsito de dia; sul continua até Z ~120)
```

Legenda:

| Símbolo | Significado |
|---|---|
| `#` | prédio não enterável (fachada). Norte-oeste: B3 + lavanderia (B2). Nordeste: **Bellmoor Savings** com apartamentos em cima (Z-11) e B4. Sul-leste: B1 (prédio atrás do Pad). Sul-oeste: B5 atrás da praça |
| `M` / `D` | Ninth Street Mart (enterável) / porta na quina NE |
| `:` | calçada; `=` pista; `p` faixa de estacionar (carros parados); `<` `>` faixas da Ninth; `v` `^` faixas da Juniper |
| `%` | faixa de pedestre pintada, **sem semáforo** [DEC-130] (CW-1 na Juniper Sul; CW-2, CW-3, CW-4 na Ninth). Se a pintura fica e como NPC atravessa: proposta em §9.5 (`Q-129`) |
| `x` | limites do jogador na Juniper Norte (BAR-N, Z −76) e na Juniper Sul (BAR-S, Z 80): parede só para personagens; carros e NPCs passam |
| `_` | praça em frente ao Mart (piso de pedra clara) |
| `S` | **ponto seguro** sob o letreiro "OPEN 24 HOURS" (SS) |
| `.` | estacionamento; `T` trailer à venda (dias 1–5); `!` placa "Available on Day 5"; `V` van (AS-1) |
| `,` | **Pad** (piso pintado); `C` carrinho (dia) / trailer (noite) na mesma área [DEC-086] |
| `1`–`5` | vagas da fila Q1–Q5; `@` spawn de jogador; `o` placa OPEN/CLOSED; `u` lixeira; `d` porta D1 |
| `F` | poste **P-01** (panfleto; último poste do Hush; espreita L1) |
| `j` / `W` | postes da Juniper JL-01..JL-08 / JL-09 (Walker parte daqui) |
| `l` | espreitas do ladrão L2 (poste leste) e L3 (banco do Pad) |
| `c` | relógio do Bellmoor Savings (C-01) |
| `L` | AN-12: vaga do long car (boca da entrada do estacionamento, de frente para o trailer) |
| `m` / `a` | parada da ambulância AMB-M (Mart) / AMB-P (em frente ao trailer) |
| `r` | REV-1..4: onde o jogador revivido aparece |
| `X` | caminhão de entrega estacionado (TRUCK) |
| `E` | saída leste de clientes EX-E (vira a esquina de B1) |
| `A` / `b` / `d` | chegadas de cliente SP-A / SP-B / D1 |
| `R` | spawn do ladrão ST-R (calçada leste da Juniper Sul, além de BAR-S, escondido pela quina de B1) |
| `*` | RL-END: onde a Raincoat Lady some na poça (final) |

Três linhas que organizam o mapa:
1. **Porta do Mart → carrinho**, reta para o leste a Z ~34–42, pela praça, pela faixa **CW-1** sobre a Juniper Sul e pela borda do Pad. Uma única travessia, **sem semáforo**: o jogador olha, espera a brecha ou arrisca (DEC-130, DEC-095; rodada 17, `Q-128` opção B).
2. **Janela do trailer → Juniper Norte**, para o norte-noroeste, até JL-09 (~135 studs). É onde o Walker aparece e onde os postes do Hush apagam (ANM-007, ANM-010).
3. **Carrinho → trailer à venda**, para o norte-nordeste, por cima da Ninth e do meio-fio vermelho (DEC-047).

## 4. Zonas nomeadas

| ID | Zona | Limites (X; Z) | Dia | Noite |
|---|---|---|---|---|
| Z-01 | **The Pad** (esquina do carrinho) | X 24..64; Z 32..64 | carrinho, estações, Q1, placa OPEN, espreita L3 | trailer [DEC-086], mesma fila; luz do trailer; parte de trás do trailer escura fora do raio |
| Z-02 | Calçada sul da Ninth | X −112..112; Z 16..32 | fila Q2–Q5, faixas de caminhada, espreita L1/L2, REV | mesma fila; REV-1..4 (reviver) |
| Z-03 | Ninth Avenue (pista) | X −136..136; Z −16..16 | **trânsito** nos dois sentidos; faixa de estacionar no norte; cruzamento sem semáforo, Ninth com preferência (PARE na Juniper, proposta `Q-129`) | trânsito raro (1 carro, FEAT-033, `Q-103`); ambulância; long car (ANM-008) |
| Z-04 | **Ninth Street Mart** | X −100..−64; Z 32..64 | prateleiras (pacotes) [DEC-049], frutas/verduras (cenário) [DEC-109], **bancada de upgrades** na parede do fundo [DEC-101, DEC-106]; **Opal** no caixa [DEC-079, DEC-099] | aberto 24 h, aceso (ilha de luz) [DEC-049]; bancada aberta; Opal no caixa |
| Z-05 | Estacionamento | X 52..104; Z −88..−32 | trailer à venda + placa; carros parados | vaga vazia (carrinho com lona, `Q-082`); escuro; reserva AN-01 |
| Z-06 | Calçada norte da Ninth | X −112..112; Z −32..−16 | passagem de clientes do norte; fachadas com vitrines "NO HELP WANTED" (cutscene) | escura; AN-12 na boca do estacionamento |
| Z-07 | Juniper Norte | X −24..24; Z −76..−32 (visual até −152) | **trânsito**; chegada de clientes SP-A pela calçada leste; postes JL na calçada oeste | postes JL acesos; Walker (ANM-007) e Hush (ANM-010) |
| Z-08 | Juniper Sul | X −24..24; Z 16..80 (visual até Z ~120) | **trânsito** (rotas TR-7..TR-10); travessia **CW-1 sem semáforo** (rota do Mart) [DEC-130, `Q-128` B]; ladrão chega pela calçada leste | **sem trânsito** (proposta, §9.5); travessia CW-1 (rota do Mart e do ponto seguro); sem âncora de anomalia |
| Z-09 | B1 (prédio atrás do Pad) | X 64..112; Z 32..88 e X 24..64; Z 64..88 | porta D1 (clientes entram/saem) | janelas emissivas; porta D1 |
| Z-10 | Lavanderia B2 (placeholder) | X −72..−24; Z −64..−32 | porta SP-B (clientes) | fechada e escura; reserva AN-10 |
| Z-11 | **Bellmoor Savings + apartamentos** | X 24..52; Z −64..−32 | banco no térreo; relógio C-01 na fachada sul; apartamentos nos andares 2–3 | relógio com tique-taque (ANM-003); janelas WV-1..3 (ANM-006) |
| Z-12 | **Praça do Mart + ponto seguro** | X −64..−24; Z 24..56 | rota Pad ↔ Mart; mesas baixas | **ponto seguro SS** sob o letreiro (ANM-010); parada AMB-M; palco do final |
| Z-13 | Fundo da Juniper (só visual) | X −24..24; Z −152..−76 | rua some numa rua transversal; carros entram/saem | JL-08, JL-09; névoa |

## 5. Pontos-chave (coordenadas)

### 5.1 Carrinho, trailer e fila

| ID | O quê | Posição (X, Z) | Observação |
|---|---|---|---|
| CART | Carrinho do chefe (centro) | (41, 40) | linha de estações X 28..54, Z 36..39; corredor de trabalho Z 39..45 |
| TRL | Food Trailer no Pad (centro) | (40, 41) | casco X 26..54, Z 35..47; piso +2 studs; engate a oeste até X 22. Trabalha aqui [DEC-086] |
| TRL-SALE | Trailer à venda (dias 1–5) | (78, −58) | janela de serviço virada para o sul; visível do carrinho [DEC-047]. Depois da troca: carrinho com lona nesta vaga (`Q-082`) |
| SIGN-T | Placa "Available on Day 5" | (78, −40) | só leitura; o prompt de compra fica no trailer [DEC-047] |
| DRAWER | Gaveta do caixa | (52, 37) | fim da linha (entrega). Valor visível no mundo [DEC-050] |
| Q1 | Vaga 1 (balcão) | (52, 33) | na frente da entrega/gaveta; 8 studs do jogador na entrega |
| Q2–Q5 | Vagas 2 a 5 | (46, 29) · (41, 29) · (36, 29) · (31, 29) | fila corre para oeste na calçada. Counter 1 = Q1–Q3; Counter 2 = +Q4; Counter 3 = +Q5 [DEC-046] |
| OPEN | Placa OPEN/CLOSED (prompt) | (25, 35) | canto NO do Pad; altura ≤ 3 (fica na faixa de visão do Mart) [DEC-048] |
| BIN-C | Lixeira do carrinho | (56, 42) | ponta direita do corredor |
| PS-1..4 | Spawn dos jogadores (dia) | (32, 42) · (38, 42) · (44, 42) · (50, 42) | olhando para o norte. Também reconexão [DEC-063] e membro atrasado [DEC-098] |
| PS-N1..4 | Spawn dos jogadores (noite) | (32, 41) · (38, 41) · (44, 41) · (50, 41) | dentro do trailer. Também reconexão e atrasado à noite |
| DROP-T | Itens do espectador (FEAT-025, §19.12 do `architecture.md`) | (51.5, 44.5), piso do trailer (+2) | **novo (TASK-083)**. Canto de trás à direita, ao lado da porta dos fundos, dentro de LZ-1: os pacotes e o apito de quem virou espectador caem aqui às 6:00 AM. Fora da linha de estações (nenhum prompt de estação a < 5 studs) e visível de quem entra pela porta. Provisório |

Poses dos veículos (`MapPoint`, T36): `CART` = pivô do carrinho **(41, 37.5)** (o "centro (41, 40)" da tabela é o visual; o código usa o pivô do modelo, base-centro do AST-026), `TRL` = pivô do trailer no Pad (40, 41), virado para o norte; `TRL-SALE` = (78, −58), virado para o sul. O `VehicleService` faz `PivotTo` do modelo para o ponto: carrinho em `CART` e trailer em `TRL-SALE` no começo da run; depois da troca, trailer em `TRL` e carrinho (com a lona) em `TRL-SALE`. `SIGN-T` também vira `MapPoint` (78, −40), virado para o sul: é onde o `VehicleController` desenha "Available on Day 5" (§16.3).

### 5.2 Mart, ruas e marcos

| ID | O quê | Posição (X, Z) | Observação |
|---|---|---|---|
| MKT-DOOR | Porta do Ninth Street Mart | (−62, 34) | quina NE chanfrada, vidro nas fachadas norte e leste. Letreiro **"OPEN 24 HOURS"** na marquise sobre a quina, emissivo à noite (nunca apaga, ANM-010) |
| MKT | Interior do Mart | X −100..−64; Z 32..64 | §7.4 |
| SS | **Ponto seguro** (sob o letreiro) | centro (−58, 30), raio 6 (X −64..−52, Z 24..36) | marcação amarela no chão + marquise. Conta como luz [`anomalies.md` N10]. Nunca recebe anomalia (§10.4, `Q-092`) |
| P-01 | Poste da esquina com panfleto | (20, 20) | quina SE do cruzamento. Cutscene, espreita L1, **último poste do Hush** e passo 9 do Walker |
| JL-01..05 | Postes da Juniper (calçada oeste, X −16), **5 postes a cada 16 studs** (usuário, 2026-10-10: menos postes, 5 passos; antes 9 a cada 8) | Z −24, −40, −56, −72, −88 | acendem um por um às 8 PM (`world.md` §2). JL-05 fica além de BAR-N (Z −76); **JL-04 (−72) fica 4 studs dentro** (P53). Distância do centro da janela (41, 35): JL-01 82 · JL-02 94 · JL-03 107 · JL-04 121 · **JL-05 ~135** (mesma ponta da antiga JL-09). IDs JL-06..09 aposentados (não reaproveitar) |
| C-01 | Relógio do Bellmoor Savings | (39, −33), Ø 6, centro a ~14 de altura (AST-044) | fachada sul do banco, de frente para o Pad (~73 studs). Mesma hora do HUD [DEC-048]; tique-taque audível no Pad. Âncora AN-11 (ANM-003) |
| WV-1..3 | Janelas dos apartamentos | fachada sul, X 28..48, alturas 19–28 (andares 2–3, AST-045, sobre o térreo do banco AST-044 de ~18) | âncora AN-04 (ANM-006) |
| CW-1 | **Travessia trailer ↔ Mart**: faixa sobre a Juniper Sul, meio da quadra | X −12..12; Z 34..42 | rota Pad ↔ Mart e Pad ↔ SS; SP-B; ladrão não cruza. **Sem semáforo** [DEC-130]; Juniper Sul com carros de dia (rodada 17, `Q-128` B). Pista de 24: 1,5 s a 16 studs/s. Nenhum carro para dentro dela; carro só para na linha (SL-1N/SL-1S) com reserva de NPC e nunca pelo jogador [DEC-133] |
| CW-2 | Faixa sobre a Ninth (lado oeste do cruzamento) | X −24..−12; Z −16..16 | SP-B e cutscene. Sem semáforo [DEC-130] |
| CW-3 | Faixa no meio da quadra (Pad ↔ estacionamento) | X 54..60; Z −16..16 | ida ao trailer à venda. Sem semáforo [DEC-130] |
| CW-4 | Faixa sobre a Ninth (lado leste do cruzamento) | X 12..24; Z −16..16 | SP-A. Sem semáforo [DEC-130] |
| ~~SIG-T, SIG-1, SIG-3~~ | ~~semáforos~~ | — | **retirados** no ajuste final (DEC-130 revoga DEC-120). IDs não reaproveitados |
| PARE-N / PARE-S | Placas PARE nas bocas da Juniper (proposta `Q-129`, Provisório) | PARE-N na calçada oeste em (−14, −20); PARE-S na calçada leste em (13, 17), sem tapar o panfleto de P-01 (face SO) | carro da Juniper para na linha SL-N / SL-S e só entra com a caixa do cruzamento livre (§9.5). Placa ≤ 8 de altura. PARE-N fica ~1 stud ao lado da linha janela → JL-01, mas abaixo dela (a linha passa ali a ~13 de altura, a caminho da luminária) |
| TRUCK | Caminhão de entrega parado | X 88..108; Z 10..16 | faixa do meio-fio sul; decoração e cobertura de AS-2 |
| BAR-N | Limite do jogador na Juniper Norte | Z −76, X −24..24 | parede só para personagens (carros e NPCs passam); cones nas calçadas como sinal visual. Movida de Z −100 no ajuste final para manter JL-08 e JL-09 fora do alcance (o jogador nunca chega ao Walker no passo 0–1) |
| BAR-S | Limite do jogador na Juniper Sul | Z 80, X −24..24 | parede só para personagens (carros e NPCs passam); cones nas calçadas, igual a BAR-N. A rua faz curva atrás de B5/B1 em Z ~112 (carros somem na curva) |
| BAR-W / BAR-E | Limites na Ninth | X −112 / X 112 | parede só para personagens; a rua faz curva atrás dos prédios (carros somem na curva) |

### 5.3 Spawns, saídas e espreitas de NPC

Velocidade de cliente a pé: ~8 studs/s (texto antigo; `CustomerTypes` usa 9–18, a maioria 13–14).

**2026-10-10 (§9.8):** pontos de spawn/despawn revistos. Os pesos por turno estão em `Content.Flow.Spawns`; tempos a 13 studs/s (velocidade usual de cliente; o tipo mais lento anda 9).

| ID | Tipo | Posição (X, Z) | Quando | Rota |
|---|---|---|---|---|
| SP-A | chegada de cliente (norte), passantes | **(29, −92)** (era (30, −104)): faixa ao norte do fundo do banco, além de BAR-N, na sombra do prédio vista do Pad **e** da porta do Mart | peso 0 para clientes (~136 studs, 10,5 s > 10 s); passantes de dia; atores | calçada leste da Juniper → **CW-4** → LANE-E → Q5 |
| SP-B | **porta** da lavanderia | (−40, −31), medido na porta AST-046 | passantes de dia (clientes: peso 0, ~151 studs) | calçada norte → **CW-2** → … |
| D1 | **porta** de B1, chegada **e** saída | (88.6, 31) — **2026-10-11 (pedido do usuário):** saiu da parede oeste de B1 (ao lado do carrinho) para a fachada da Ninth do bloco do meio | dia e noite | calçada sul (N-Z02-08) → Q1..Q5. **~71–81 studs, ~6–9 s** |
| **DR-APT** | **porta** do Bellmoor Savings / apartamentos (novo) | (32, −31), medido no AST-044 se houver peça "Door" | dia e noite (de noite = moradores) | calçada norte → **CW-4** → LANE-E → Q5. **~80 studs, 6,1 s** |
| **SP-S** | ponta de rua (novo): calçada leste da Juniper Sul além de BAR-S, depois da curva | (21, 100) | dia e noite | calçada leste da Juniper Sul → LANE-E → Q5. **~93 studs, 7,1 s** (nunca cruza pista) |
| EX-E | saída leste, passantes | **(116.5, 40)** (era (116, 24), visível de Q1..Q5 pela calçada): beco X 113..120 atrás de B1, além de BAR-E | dia e noite | Q1 → LANE-E → beco. **~85 studs, 6,5 s** |
| **DR-B3** | **porta** de B3b (vidro "NO HELP WANTED") (novo) | (−93.3, −31.2) | passantes, dia e noite | calçada norte oeste → CW-2 → Mart |
| MKT-DOOR | **porta** do Mart (agora também nó) | (−62, 34) | passantes (24 h) | praça / borda do SS |
| L1 | espreita do ladrão (P-01) | (20, 20) → ponto em **(21.5, 22)** (TASK-083: fora do poste, que tem o pé em (20, 20)) | dia 2+ | 34 studs até a gaveta |
| L2 | espreita do ladrão (poste leste) | (84, 22) | dia 2+ | 35 studs até a gaveta |
| L3 | espreita do ladrão (banco do Pad) | (58, 58) → ponto em **(58, 56.5)** (TASK-083: na frente do banco, não em cima) | dia 2+ | 20 studs até a gaveta |
| ST-R | spawn/fuga do ladrão | **(21, 108)** (era (18, 92), que Q5 via pela quina de B1): depois da curva, colado na linha dos prédios X 24 | dia 2+ | só pela calçada leste da Juniper Sul (**nunca cruza pista**); de L2 foge para EX-E |
| AS-1..4 | spawns ocultos de atores de anomalia | §10.3 | só noite | — |

### 5.4 Trânsito: entradas, faixas e linhas de parada (DEC-087)

| ID | O quê | Posição | Nota |
|---|---|---|---|
| W-IN / W-OUT | entrada/saída oeste da Ninth | (−136, 5) EB / (−136, −5) WB | atrás da curva da Ninth, fora de vista |
| E-IN / E-OUT | entrada/saída leste da Ninth | (136, −5) WB / (136, 5) EB | atrás da curva, depois de B4/B1 |
| JN-IN / JN-OUT | entrada/saída norte da Juniper | (−6, −140) SB / (6, −140) NB | carros chegam pela rua do fundo (Z −152..−136), viram e descem |
| JS-IN / JS-OUT | entrada/saída sul da Juniper | (6, 116) NB / (−6, 116) SB | atrás da curva da Juniper Sul (Z ~112), fora de vista |
| LANE-NB/SB | faixas da Juniper (Norte e Sul) | SB X −6; NB X 6 | sem estacionar |
| LANE-WB/EB | faixas da Ninth | WB Z −5; EB Z 5 | faixa de estacionar no norte (Z −13); faixa do meio-fio sul (Z 13) sem estacionar |
| SL-N | linha de parada (Juniper SB, chegando ao cruzamento) | Z −20 | **PARE** (proposta `Q-129`, Provisório; FEAT-033): carro para 1 s e só entra com a caixa do cruzamento livre |
| SL-S | linha de parada (Juniper NB, chegando ao cruzamento) | Z 20 | idem. Fica fora da linha de visão Mart → carrinho (Z 30..47) |
| SL-W / SL-E | linhas de faixa da Ninth (antes do cruzamento) | X −28 (EB) / X 28 (WB) | **sem semáforo** (DEC-130). Carro da Ninth só para nelas com reserva de NPC ativa em **CW-2 ou CW-4** (a reserva de uma dessas faixas segura os dois lados, para nenhum carro parar dentro do cruzamento). [DEC-133] |
| SL-1N / SL-1S | linhas da faixa CW-1 | Z 30 (SB) / Z 46 (NB) | só param com reserva de NPC em CW-1. Ficam fora da linha de visão Mart → carrinho (carro parado ocupa Z 18..30 ou Z 46..58). Anti-bloqueio de FEAT-033: NB só passa de SL-1S com espaço até o PARE SL-S |
| SL-3W / SL-3E | linhas da faixa CW-3 | X 50 (EB) / X 64 (WB) | só param com reserva de NPC em CW-3 |
| PARK-N | estacionar (carros parados) | Ninth norte: X −112..−32 e X 76..104 | **meio-fio vermelho** X −32..76: nada estaciona na frente do T, do banco e do estacionamento (visão do trailer à venda, do relógio e da Juniper) |

### 5.5 Ambulância, reviver e espectador (DEC-091 a DEC-094)

| ID | O quê | Posição | Nota |
|---|---|---|---|
| AMB-IN | entrada da ambulância | W-IN (−136, 5) | sempre pelo oeste, sentido leste. **Nunca entra na Juniper** |
| AMB-M | parada "Mart" | (−50, 13), faixa do meio-fio sul, frente para o leste | serve quem caiu a oeste da Juniper Sul (X < −24): praça, SS, Mart, calçadas oeste |
| AMB-P | parada "em frente ao trailer" | (44, 13), faixa do meio-fio sul, frente para o leste; ambulância 18 × 7,5 (AST-052), portas traseiras em X 35 | serve todo o resto (trailer, Pad, calçadas leste, estacionamento, Juniper Norte). **É a parada do reviver** ("para em frente", DEC-091) |
| AMB-OUT | saída | E-OUT (136, 5) | segue reto pela Ninth |
| REV-1..4 | onde o revivido aparece; **também onde a party acorda depois da noite perdida** [DEC-122] | (38, 20) · (42, 20) · (46, 20) · (50, 20), calçada sul ao lado da ambulância e do trailer | virado para o sul (para o Pad). Até a porta do trailer: ~40 studs, ~2,5 s |
| SPEC-P | câmera fixa de espectador | (66, altura 20, 28), olhando para o Pad e AMB-P | usada durante a coleta do próprio corpo e quando não há colega de pé (janela de 10 s, DEC-094) |
| SPEC-M | câmera fixa de espectador | (−48, altura 14, 40), olhando para a praça e AMB-M | idem, para quedas do lado do Mart |

### 5.6 Walker e Hush (ANM-007, ANM-010)

**2026-10-10, pedido do usuário (Provisório): os postes do Walker saíram da Juniper e foram para a Ninth.** De dentro do trailer (janela de serviço) a fileira da Juniper Norte não era vista. Medição com raycast no Studio (trailer posto no Pad): **a malha `Awning` do AST-027 é uma placa vertical que tapa a janela inteira** (Y 5,9..10,7 na face da parede, Z 34,6..34,8), ou seja, a aba já vem *fechada* no FBX; como o `ClosedAngle` medido sai degenerado, o `Bind` usa o `Shutter_Panel` como aba e a `Awning` ficava fixa na frente do vidro — **nenhum raio saía da janela** (PS-N1..4 e centro). Correção no `bind_map01` (`bindShutterPiece`): no caminho do `Shutter_Panel`, a `Awning` fixa é **escondida** (Transparency 1, sem colisão/consulta, `Orig*` guardados; volta se um dia a `Awning` servir de aba). Com isso, a janela enxerga a rua.

A fileira nova fica na **calçada norte da Ninth, lado do banco / estacionamento** (o lado que a janela encara), **4 postes a cada 20 studs**, vindo na direção do trailer. Braço sobre a pista (rotY 0), poste no meio-fio como os outros da Ninth. A boca do estacionamento (X 62..78, long car AN-12) fica livre; os carros PARK-N 5 e 6 (X 84 / 98) foram para o oeste (X −133 / −118), para nada estacionar entre a janela e os postes.

| Passo | Posição (cabeça do poste) | Distância / direção da janela (41,5; 36,6) | Nota |
|---|---|---|---|
| 0 (início) | **NL-01** (118, −14,4) | ~92 studs, 56° a leste do norte | além de BAR-E (fora da área jogável); zumbe ~2 s [DEC-123] |
| 1 | **NL-02** (98, −14,4) | ~76, 48° | |
| 2 | **NL-03** (78, −14,4) | ~63, 36° | borda leste da boca do estacionamento |
| 3 | **NL-04** (58, −14,4) | ~54, 18° | em frente à cerca do estacionamento |
| 4 (perde a noite) | **WALKER-10 = (48, 14), fixo** | ~24, 16° | sarjeta sul da Ninth bem em frente à janela; fora de LZ-3 (28 do centro do trailer), de CW-3 e da faixa EB (Z 5). Não muda com interruptor nem Trailer Lights |

`StreetLight.Order`: NL-01 = 1 … NL-04 = 4, **P-01 = 5** (só o poste da esquina do Hush). Passo = `Order − 1` para Order 1..4; passo 4 = `WALKER-10` (o id continua o mesmo: é o exigido pelo `Required.luau`). `Steps = 4` em `Rules/ANM-007` (e `DEFAULT_STEPS` / `STEPS` no servidor e no client; comando dev `walker <0..4>`). Group continua `juniper_posts` (nome antigo, lido por código e binding; não renomeado de propósito).

Hush: apaga NL-01 → NL-04 → **P-01** (**5 postes × 3 s** = **15 s**, `Content.LightGroups.juniper_posts.Step = 3`; `PostsOff = 15` continua certo). Quando P-01 apaga, quem não está em SS errou.

Juniper Norte: ficaram **2 postes decorativos** (`Post_JuniperN_1/2`, Z −40 e −72; sem tag, sem luz); as luzes do blockout JL-01..09 e do antigo `Post_NinthN_E1` (que ficava entre NL-01 e NL-02) são desligadas pelo `Bind` (`RETIRED_POSTS`).

**Linha de visão (raycast no Studio, trailer no Pad, carrinho fora, `Awning` escondida):** do centro da janela, NL-01..04 e WALKER-10 vistos em todos os raios (pé +1, cintura, cabeça e lâmpada). Dos olhos PS-N1..4 (a 4,5 do piso, colados ao balcão): PS-N1 vê os quatro (o pé de NL-01/02 some atrás do trilho); PS-N2 vê a parte alta de todos; **PS-N3 não vê NL-01** e **PS-N4 (X 50, ponta leste) não vê NL-01..03** — a parede leste da janela tapa (basta um passo para oeste). WALKER-10 até 6 de altura fica atrás das estações para quem está colado ao balcão em PS-N2..4 (PS-N1 vê); a figura (~7) aparece por cima do balcão. `check_map01` **regra 14** confere isso a cada rodada: posto/WALKER-10 invisível do centro da janela = **erro**; PS-N cego = aviso.

Cada passo anda ~20 studs (o último, ~32, atravessa a Ninth). Correr para o Mart (oeste) deixa os postes nas costas: o N7 × N10 do §6 continua valendo (melhor que antes: nem a CW-1 obriga a olhar para eles).

## 6. Distâncias e linhas de visão (checagem dos requisitos)

| Requisito | Fonte | Medida neste layout | OK |
|---|---|---|---|
| Mercado a 100–120 studs do carrinho | DEC-049 | MKT-DOOR → CART: **103** em linha reta; **~106** caminhando (reto para oeste pela borda do Pad, CW-1 e praça) | sim |
| Ida + volta + compra ~25 s | DEC-049 | 2 × 106 / 16 ≈ 13 s andando + ~10 s comprando + espera de brecha em CW-1 sem semáforo. De dia, ~1 carro a cada 12–20 s por sentido (FEAT-033), ~1 a cada 8 s somando os dois; cada um ocupa a faixa ~2,5 s (1,5 s para atravessar 24 studs + passagem do carro + margem): espera média **~1 s** por travessia, pior caso ~5 s. Total ≈ **25 s** de dia (pior caso ~33 s), igual à conta de FEAT-033. À noite a Juniper Sul fica sem carros (proposta §9.5): ~23 s | sim |
| Ida à bancada de upgrades | DEC-101 | porta → B1..B5/S1 ~40 studs a pé dentro do Mart (~2,5 s) | sim |
| Porta do Mart com linha de visão para o carrinho | DEC-049, DEC-018 | reta MKT-DOOR → CART passa pela praça, por CW-1 e pela borda do Pad. Carros da Juniper Sul **cruzam** a linha em < 1 s e **nunca param nela** (não há linha de parada em CW-1; o PARE SL-S fica em Z 20, fora dela). L1, L2, L3 visíveis da porta e dos corredores (vidro leste) | sim |
| Travessia trailer ↔ Mart sem semáforo | DEC-130, DEC-095, DEC-103; rodada 17 (`Q-128` B) | **uma** travessia (CW-1), 24 studs de pista, 1,5 s a 16. Sem semáforo: o jogador olha e escolhe a brecha; pode ser atropelado (item cai, sem sanidade) | sim |
| Zona anti-ladrão raio 14 | DEC-050 | L1/L2/L3 a 29 / 47 / 25 do centro do carrinho (fora) | sim |
| ~4 s da espreita até a gaveta | DEC-050 | L1 36, L2 35, L3 22 studs (`Q-089`) | proposta |
| Trailer à venda visível desde o dia 1 | DEC-047 | TRL-SALE a ~105 studs, linha passa pelo meio-fio vermelho e a leste do banco | sim |
| Luz do trailer raio 18 | DEC-055 | cobre Q1–Q5 e a frente do Pad; não cobre P-01 (29), a rua nem a praça | sim |
| Ponto seguro sob o letreiro do Mart, ~100–120 studs | `anomalies.md` N10 (Aprovado) | porta do trailer → SS: **~103** até a borda, ~110 até o centro. 6,5 s a 16 (Line Cook 15: 6,9 s; Runner 18: 5,7 s). Janela do Hush ~15 s; durante o Hush não há trânsito (FEAT-033), então CW-1 não exige esperar | sim |
| Correr para o Mart sem precisar olhar a Juniper | `anomalies.md` N7 × N10 | rota sai pela traseira do Pad e anda para oeste (≤ 14° ao norte do oeste). Com JL-09 mais perto (Z −88), a folga caiu: atrás do trailer o casco (altura ~11) tapa a linha para a Juniper; saindo de trás dele (borda oeste do Pad, X ~24) o fim da Juniper fica a **~59°** da direção de marcha, e passa de 75° depois de CW-1 (meia largura da visão no celular deitado: ~51–57°). Dentro de SS, olhando para o Mart ou para o Pad, a Juniper fica fora da tela. **Atenção:** sem semáforo, quem espera em CW-1 olha para o **norte** para ver carro saindo do cruzamento, e o fim da Juniper entra na tela. De dia não há Walker; à noite a proposta é **zero carro na Juniper** (§9.5, P32), então não há o que olhar. Se `Q-102`/`Q-103` puserem carro na Juniper à noite, esse olhar vira risco N7 × N10 | sim (depende da noite sem carros na Juniper) |
| Linha de visão longa da janela para a Juniper (**histórico**: desde 2026-10-10 os postes do Walker estão na Ninth, §5.6) | `anomalies.md` N7, N10 | janela (X 30..53, Z 35) → JL-09: **~135** studs, ~25° a oeste do norte (dentro da tela enquanto se trabalha). Postes na calçada **oeste**: a linha mais crítica (da ponta leste da janela para JL-09) passa ~8 studs a oeste da quina do banco (antes 1) | sim |
| Fim da Juniper legível do trailer (**histórico**; desde 2026-10-10 o passo 0 é NL-01 a ~92 studs, §5.6) | `art/style-guide.md` §5 (~110) **emendado pelo usuário para ~135** (LD-15 / P33) | JL-09 a ~135; JL-06 a ~114; JL-05 a ~107. Todos os passos dentro de ~135 | sim (com a emenda; art-director anota no style guide) |
| Janelas do N6 "lá em cima" | `anomalies.md` N6, `world.md` §3 | WV-1..3 a ~70 studs e 19–28 de altura (olho a ~6,5 dentro do trailer): **10–17° acima do horizonte**. Ficam no alto da tela, não fora dela (ver §15 P25) | parcial |
| Relógio do banco visível do balcão | `anomalies.md` N3 | C-01 a ~73 studs, ~6° acima do horizonte (centro a ~14) | sim |
| Teto de 12 NPCs | DEC-045 | §9.4 (médicos, Opal e veículos fora do teto) | sim |

**Regra da faixa de visão** (para art-director e modeler): na faixa entre MKT-DOOR / vidro leste do Mart e CART (Z 30..47, X −64..41), nada com mais de 3 studs de altura. Postes finos permitidos. Carros só estacionam em PARK-N (§5.4); o meio-fio vermelho (X −32..76) e a faixa do meio-fio sul ficam sempre livres; nenhum carro para dentro de CW-1; carro parado por reserva de NPC fica em Z 18..30 (SB, atrás de SL-1N) ou Z 46..58 (NB, atrás de SL-1S), fora da linha porta → carrinho (Z ~34–40 em X ±6).

**Legibilidade a distância:** a barra de progresso do ladrão sobre a gaveta (DEC-050) precisa ser lida da porta do Mart (~114 studs). Billboard com distância máxima ≥ 130 studs. O ladrão (Quick Quentin, CHR-004) usa silhueta e cor que se destacam.

## 7. Layouts de estação

Ordem de preparo [DEC-016]: **estoque → grelha → esteira → pão/tábua → montagem → complementos**, terminando na **entrega + gaveta**.
**Regra de ouro: tudo anda da esquerda para a direita.** O jogador trabalha olhando para o norte (para a fila); a linha vai de oeste para leste. A fila anda no mesmo sentido: o cliente entra pela esquerda, é atendido em Q1 na ponta direita e sai pela direita. **Carrinho e trailer usam a mesma ordem e os mesmos X**, então o que o jogador aprendeu de dia vale à noite [DEC-086].

Regras de prompt para 1ª pessoa no mobile (DEC-039, DEC-066, DEC-097 — sem braços, só a Tool na mão):
- prompts de estações vizinhas a **≥ 2,5 studs**; cada estação com silhueta e cor diferentes;
- toda estação alcançável do corredor sem pular nem agachar;
- complementos: uma tigela por ingrediente, grade 3 × 2 (6 complementos do MVP, DEC-071, DEC-156): 2 studs entre centros na fileira e 1,5 entre as fileiras no modelo. As âncoras de prompt são afastadas para ficarem ≥ 2,0 entre si (§7.1).

### 7.1 Carrinho (tier 1) — vista de cima

Escala: **1 coluna = 1 stud (X)**, **1 linha = 2 studs (Z)**. X de 12 a 71.

```
 X →  12        22        32        42        52        62
      |         |         |         |         |         |
  14  ============================================================  Ninth Avenue (faixa do meio-fio sul)
  16  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  18  ::::::::::::<---<---<---<---<---<---<---<---<---<---<---<---  faixa oeste (LANE-W)
  20  ::::::::F:::::::::::::::::::::::::::::::::::::::::::::::::::
  22  ::::::::::::--->--->--->--->--->--->--->--->--->--->--->--->  faixa leste (LANE-E)
  24  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  26  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  28  :::::::::::::::::::5::::4::::3::::2:::::::::::::::::::::::::  fila Q5..Q2
  30  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  32  ::::::::::::,,,,,,,,,,,,,,,,,,,,,,,,,,,,1,,,,,,,,,,,########  Q1 / início do Pad
  34  ::::::::::::,o,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,########
  36  ::::::::::::,,,,SSSGGGGGRRRBBTTTKKKKKKHH$H,,,,,,,,,,########  estações
  38  ::::::::::::,,,,SSSGGGGGRRRBBTTTKKKKKKHH$H,,,,,,,,,,########
  40  <<<<<<<<<<<<,,,,..........................,,,,,,,,,,########  corredor; saída oeste = rota do Mart (<<<)
  42  ::::::::::::,,,,....@.....@.....@.....@...,,u,,,,,,,########
  44  ::::::::::::,,,,..........................,,,,,,,,,,########
  46  ::::::::::::,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,d#######  porta D1
  48  ::::::::::::,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,d#######
  50  ::::::::::::,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,########  (52–56 iguais, omitidas)
  58  ::::::::::::,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,l,,,,,########  banco L3 (60–62 iguais à 50)
  64  ::::::::::::################################################  B1
```

| Estação (ordem) | Letra | X | Largura | O que é (visual) | Prompts | Peça visível de upgrade |
|---|---|---|---|---|---|---|
| 1. Estoque de salsicha | S | 28–31 | 3 | caixa térmica com rodinhas | usar (salsicha → grelha), "Restock" | Cooler 2/3: caixa maior [DEC-046] |
| 2. Grelha | G | 31–36 | 5 | chapa; 2 vagas no nível 1 | coletar (→ esteira); barra sobre cada salsicha [DEC-015] | Grill 2/3: 3 e 4 vagas |
| 3. Esteira / descanso | R | 36–39 | 3 | trilho inclinado | usar (salsicha → pão) | — |
| 4. Pão | B | 39–41 | 2 | caixa de pães | usar (pão → tábua), "Restock" | — |
| 5. Tábua / montagem | T | 41–44 | 3 | tábua de corte | fluxo da montagem (`Q-068`) | — |
| 6. Complementos | K | 44–50 | 6 | grade 3 × 2 de tigelas de inox [DEC-071, DEC-156], conforme o modelo AST-017 no place (TASK-005; modelo em produção, **Provisório** até aprovação): **fileira do operador** (Z ~38,1, baixa), de oeste para leste = **Cheese (X 45), Mustard (47), Ketchup (49)**; **fileira de trás** (Z ~36,6, 0,3 mais alta) = **Cream Cheese (45), Potato Sticks (47), Bacon (49)**. Fileiras a 1,5 stud; as âncoras de prompt saem da grade (operador: +0,4 Z e +0,35 Y; trás: +1,25 Y) para ficarem ≥ 2,0 entre si (`bind_map01.luau`) | um prompt hold 1 s por ingrediente [DEC-072], "Restock" | ingrediente bloqueado = tampa com cadeado até o dia de liberação |
| 7. Entrega + gaveta | H / $ | 50–54 | 4 | suporte de entrega e gaveta | gaveta: valor no mundo [DEC-050] | Cash Drawer Lock: cadeado |

Medidas: profundidade da linha 3 (Z 36..39), altura **3,0** do Pad (y 3,45; DEC-157, era 3,5); corredor **6 studs** (Z 39..45) para 4 jogadores. Dois guarda-sóis a 9 de altura (AST-026). Nenhum prompt de compra de upgrade no carrinho: as peças só **mostram** o nível comprado na bancada do Mart [DEC-052, DEC-101]. Saída do corredor pelo **lado oeste** (X 28 → borda do Pad X 24): é o começo da rota do Mart.

### 7.2 Food Trailer (tier 2) — vista de cima

Decidido: depois da compra (fade, DEC-047) o trailer **ocupa o Pad** no lugar do carrinho, janela de serviço para a mesma fila [DEC-086].
Escala: **1 coluna = 1 stud (X)**, **1 linha = 1 stud (Z)**. X de 22 a 56.

```
 X →  22        32        42        52
      |         |         |         |
  33                                1      <- Q1 (52, 33)
  34                            _______    <- balcão dobrável externo (X 48..54)
  35      +---~~~~~~~~~~~~~~~~~~~~~~~~+    <- parede frontal; ~ = janela de serviço (X 30..53); aba `Awning` por fora (DEC-221)
  36      |SSSGGGGGGRRRBBTTTKKKKKKHH$H|
  37      |SSSGGGGGGRRRBBTTTKKKKKKHH$H|    <- estações (mesma ordem e mesmos X do carrinho)
  38      |SSSGGGGGGRRRBBTTTKKKKKKHH$H|
  39      |...........................|    <- (H1..H4 saíram, DEC-221)
  40      |...........................|
  41   <==|.....@.....@.....@.....@...|    <- @ = PS-N1..4; <== engate
  42      |...........................|
  43      |bbbbbbbbb...CCC.uu.........|
  44      |bbbbbbbbb...CCC.uu.........|    <- b = banco (3 lugares, cenário); C = cafeteira; u = lixeira
  45      |bbbbbbbbb...CCC.uu.........|
  46      |...........................|
  47      +-----------------W-IDDDDD--+    <- W = botão da janela (X 43,4); I = interruptor (X 46); D = porta dos fundos (X 47..51)
  48                           ^^^^^       <- degraus (piso +2)
                                 -> rota do Mart / ponto seguro: para oeste pela traseira do Pad (~110 studs)
```

| Elemento | Posição | Verbo / função | Nota |
|---|---|---|---|
| Linha de estações | Z 36..39, X 27..53 | preparo [DEC-016] | grelha com 6 de largura |
| Janela de serviço | parede norte, X 30..53, peitoril 3,5 do piso, topo a 8 | atender / recusar em Q1 [DEC-054] | vê a fila, o relógio C-01, as janelas WV, a Juniper e a vaga AN-12 **enquanto trabalha** |
| ~~Esconder H1..H4~~ | — | **sai (DEC-221)** | armários AST-041, `Prompt_Hide`, `Hide_Pose` e `Slot` saem do place e do binding |
| Botão da janela `TRL-SHUTTER` | parede sul, (43.4, 46.5), mesma altura do interruptor | fechar/abrir a janela (DEC-221; ANM-008, ANM-009) | "ao lado do interruptor": 2,6 de `TRL-SWITCH` (donos diferentes: `VehicleService` × `LightService`, regra ≥ 2,5 do §16.4) e longe do prompt da lixeira (43.5, 44) pela altura. Peça = placa placeholder (0,5 × 0,7 × 0,15, Mustard) com `Prompt_Shutter` (`Interactable`, `PromptAction = "shutter_toggle"`) até a arte desenhar o botão. Hold 0,5, só à noite |
| Aba da janela (`Awning`) | por fora da parede norte, sobre a janela (X 30..53, topo a 8 do piso) | estado `Shutter` do trailer: aberta (toldo levantado, como hoje) ou fechada (cobre a janela, peitoril 3,5 até o topo 8) | malha `Awning` do AST-027 (existe no `.fbx`). `Attachment` `Shutter_Hinge` na borda de cima (eixo X = dobradiça); o `VehicleController` gira a aba no client. Se a malha não for uma `MeshPart` separada no place, ou se abaixada não cobrir os 22,5 × 4,5 da janela: placa placeholder `Shutter_Panel` (Part 22,5 × 4,6 × 0,2, Aluminum, sem colisão) com a mesma dobradiça, e a `Awning` fica fixa (P51) |
| Interruptor | parede sul, (46, 46.5) | luz [DEC-054, DEC-055] (ANM-003) | `Q-064` |
| Lixeira | (43.5, 44) | descartar [DEC-054] (ANM-002) | 3,5 do interruptor e da cafeteira |
| Cafeteira | (40, 44) | café [DEC-055] | barra sobre a cafeteira |
| Banco do fundo | X 27..36, Z 43..46, **3 lugares** (AST-040: 9 × 3) | **cenário** (pode sentar) | não é lugar de queda (DEC-091) nem de acordar: depois da noite perdida a party acorda **em pé na calçada ao lado do trailer**, em REV-1..4 [DEC-122] |
| Porta dos fundos + degraus | parede sul, X 47..51 | saída para o Mart/SS; **batidas da ANM-009** | janelinha da porta = AN-05 (de costas para quem trabalha). A porta não abre por fora (DEC-054) |
| Trailer Lights | mastro (40, 41) + cordão sobre a janela | luz raio 18 [DEC-055] | peça visível do upgrade |
| Upgrades | mesmas peças visíveis do carrinho, versão trailer | **compra só na bancada do Mart** [DEC-101, DEC-106]; nenhum prompt de compra no trailer | níveis passam do carrinho para o trailer (`Q-075`, aberta) |

Medidas (iguais a AST-027): casco 28 × 12 (X 26..54, Z 35..47), interior 26 × 10, piso a +2, **pé-direito 8,5**, **altura externa ~11**. Corredor de 4 studs (Z 39..43). Colisão jogador-jogador **desligada** no carrinho e no trailer (`Q-086`).

### 7.3 Peças que mudam entre os tiers

| Objeto | Carrinho | Trailer |
|---|---|---|
| Fila Q1–Q5, placa OPEN, spawns de cliente, gaveta (52, 37) | iguais | iguais |
| Cafeteira, interruptor, botão e aba da janela (DEC-221), banco, porta dos fundos | não existem | existem |
| Estacionamento | trailer à venda (dias 1–5) | vaga com o carrinho sob lona (`Q-082`) |

### 7.4 Interior do Ninth Street Mart

36 × 32 studs (X −100..−64, Z 32..64), um cômodo, pé-direito 12 (AST-028). Porta na **quina NE** chanfrada. Vidro na fachada **norte** (calçada da Ninth, SS) e na fachada **leste** de Z 32 a Z 56 (praça e Pad). Gôndolas correm **leste-oeste**: quem está num corredor olhando para leste vê o carrinho pelo vidro (DEC-018).

Três áreas [DEC-101]: **prateleiras** de ingredientes (gôndolas e geladeiras), **expositor de frutas/verduras** (só cenário, sem prompt [DEC-109]) e **bancada de upgrades** na parede do fundo [DEC-101, DEC-106]. Opal no balcão do caixa [DEC-079, DEC-099].

**Qual é a "parede do fundo":** a parede **oeste** (X −100). Quem entra pela quina NE olha para oeste, pelos corredores, e a bancada fecha o fim do **corredor do meio**: é a primeira coisa que se vê da porta (landmark "GEAR WALL", `world.md` §3.1). De costas para a bancada, o mesmo corredor mostra o carrinho pelo vidro leste (ladrão, DEC-018). Na parede sul (Z 64) a bancada ficaria escondida atrás das gôndolas e sem linha de visão para o Pad.

Escala: **1 coluna = 1 stud (X)**, **1 linha = 2 studs (Z)**. X de −100 a −64. Aproximado (±1).

```
 X → -100      -90       -80       -70     -64
      |         |         |         |      |
  32  +vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\    vidro norte; \ = quina chanfrada (porta D)
  34  |...PPPPPPPP.............o..........D    P = frutas/verduras (cenário); o = Opal (OP-1)
  36  |...PPPPPPPP........OOOOOOOOOO..c...v    O = balcão do caixa; c = Coffee
  38  |...................................v    corredor da frente
  40  U1..............GGGGGGGGGGGGGGGGGG..v    U = bancada de upgrades (parede oeste); G = gôndola N
  42  U2..............GGGGGGGGGGGGGGGGGG..v      (compra pelas faces Z 40 e Z 44)
  44  U...................................v    corredor do meio: da porta se vê S1 no fim dele
  46  US..................................v  <- S1 = slot especial (vitrine)
  48  U3..............GGGGGGGGGGGGGGGGGG..v    gôndola S (compra pela face Z 48)
  50  U...............GGGGGGGGGGGGGGGGGG..v
  52  U4..................................v
  54  U5..................................v
  56  U...................................|    fim do vidro leste (Z 56)
  58  |...................................|
  60  |...................................|
  62  |===================================|    prateleiras de fundo (decoração, sem prompt)
  64  +-----------------------------------+
```

| Ponto de compra | Posição | Distância da porta |
|---|---|---|
| Sausages | (−69, 40) | 9 |
| Buns | (−69, 44) | 12 |
| Ketchup | (−75, 40) | 14 |
| Mustard | (−75, 44) | 16 |
| Cheese (geladeira baixa) | (−81, 40) | 20 |
| Bacon (geladeira baixa) | (−81, 44) | 22 |
| Potato Sticks | (−75, 48) | 19 |
| Cream Cheese (geladeira baixa) | (−81, 48) | 24 |
| Coffee | (−68, 35), ponta do caixa | 6 |

- 9 pontos de compra (DEC-049, DEC-071), um prompt cada, ≥ 3 studs entre si. Nenhum a mais de 25 studs da porta. Prateleiras **não rotacionam** (FEAT-008).
- Ingrediente ainda não liberado: etiqueta "Out of stock" (`Q-088`).

**Bancada de upgrades** (FEAT-015, FEAT-035; asset AST-049). Balcão encostado na parede oeste, X −100..−98, Z 39..57 (18 de comprimento × 2 de fundo × 3,5 de altura); painel de parede 18 × 6 acima, título "GEAR WALL". Seis posições de 3 studs (módulos de AST-049), prompt hold 1,5 s em cada uma; o jogador fica em X ≈ −96, virado para oeste. Área livre na frente: X −98..−84 (14 studs), cabem 4 jogadores.

| Posição | Oferta (FEAT-015) | Prompt em (X, Z) | Nota |
|---|---|---|---|
| B1 | Grill (UPG-001), próximo nível | (−98, 40.5) | fixo [DEC-106] |
| B2 | Cooler (UPG-002), próximo nível | (−98, 43.5) | fixo |
| S1 | slot especial (hoje só o Revive Kit, ITM-021) | (−98, 46.5) | **sorteio por turno** (FEAT-035, DEC-129). Vitrine com moldura dourada no eixo do corredor do meio: visível da porta. Vazio = "Nothing special today" |
| B3 | Counter (UPG-003), próximo nível | (−98, 49.5) | fixo |
| B4 | Cash Drawer Lock (UPG-004) | (−98, 52.5) | fixo |
| B5 | Trailer Lights (UPG-005) | (−98, 55.5) | fixo; antes do trailer mostra "Trailer only" [DEC-055, DEC-106] |

- Distância da porta: S1 a ~36 studs em linha reta, ~43 a pé (~2,7 s). Título do painel legível da porta a ~40 (AST-049 pedia ~25: ver §15 P34).
- O Food Trailer **não** está na bancada: compra fixa no próprio trailer à venda, Day 5+ [DEC-107].
- A cafeteira não é vendida (vem fixa no trailer, DEC-125); no Mart só o pacote de café (ponto Coffee).

**Frutas/verduras** (AST-050): expositor inclinado 8 × 3 × 3,5 em X −96..−88, Z 34..37, encostado no vidro norte, placa "FRESH PRODUCE". **Sem prompt** [DEC-109]. Fica a oeste do caixa e longe do eixo porta → carrinho, então não tapa o vidro leste.

**Prateleiras de fundo** (parede sul, Z 62..64): decoração, sem prompt.

- **Opal (CHR-003)** [DEC-079, DEC-099]: OP-1 em (−75, 33.5), atrás do balcão do caixa (X −80..−70, Z 34..37), de costas para o vidro norte, virada para dentro da loja. Fixa dia e noite; balão de fala quando um jogador entra num raio de **8 studs** do caixa, uma vez por visita (NPC-020, AST-031). **Não é âncora de anomalia** (`Q-091`). Não vende: a bancada é loja de parede sem vendedor (DEC-101). Fora do teto de NPCs (`Q-091` a).
- Sem depósito, sem porta de fundo acessível (DEC-004).

## 8. Fluxo do jogador

### 8.1 Primeira vez (run nova)

1. Cutscene de abertura em POV compartilhada (§11.1): a party anda junta pela calçada norte da Ninth, espera um carro passar e atravessa CW-2 e CW-1 (ensina sem texto: carro não para, olhe e espere a brecha), para no poste P-01 e lê o panfleto.
2. Fade → jogadores em PS-1..4, atrás do carrinho, 7:00 AM [DEC-048]. Estoque cheio [DEC-049].
3. Primeiro olhar (norte): fila vazia, carros passando, **trailer à venda** com a placa do outro lado da rua (a meta, DEC-003), relógio do banco. À esquerda, o letreiro do Mart.

### 8.2 Turno de dia (tier 1)

| Momento | Onde | O quê |
|---|---|---|
| Preparação 7–8 AM | carrinho; Mart | reabastecer sem ladrão; qualquer jogador abre pela placa OPEN [DEC-048] |
| Loja aberta 8 AM–6 PM | corredor do carrinho | atender em Q1, preparar da esquerda para a direita, entregar, gaveta |
| Faltou ingrediente | carrinho → CW-1 → Mart → CW-1 → carrinho | ~25 s (§6); **uma travessia sem semáforo** (CW-1) em cada perna; o carrinho fica visível o tempo todo; ladrão (dia 2+) |
| Upgrades | **bancada na parede do fundo do Mart** (§7.4) [DEC-101, DEC-106] | B1 Grill, B2 Cooler, B3 Counter, B4 Lock, B5 Trailer Lights (depois do trailer), S1 especial. Efeito imediato no veículo, peça nova visível (FEAT-015). Dá para combinar com a ida de reposição |
| Dia 5+ | estacionamento, por **CW-3** (sem semáforo) | prompt de compra no trailer [DEC-047, DEC-107]; troca no fim do turno |
| 6 PM | carrinho | placa CLOSED; atende quem está na fila; resumo |

Não há semáforo [DEC-130]: o jogador atravessa quando quiser, na faixa ou fora dela, por conta e risco. Atravessar na frente de um carro termina em atropelamento com ragdoll [DEC-095]; o item da mão cai, sem perda de sanidade [DEC-103]. A escolha "esperar a brecha ou arriscar" (FEAT-033) continua, agora sem garantia de travessia segura.

### 8.3 Turno de noite (tier 2)

| Momento | Onde | O quê |
|---|---|---|
| Início 8 PM | dentro do trailer, PS-N | ligação do chefe no telefone fixo do trailer [DEC-025, DEC-124]; postes da Juniper acendem um por um; trânsito vira raro (§9.5) |
| Trabalho | estações + janela | mesma rotina, olhando para a rua escura |
| Café | cafeteira (fundo) | +25 de sanidade [DEC-055] |
| Anomalias | janela (fila, relógio, janelas de cima, Juniper, AN-12), porta dos fundos, interior | verbos de DEC-054 (§10.3) |
| Faltou ingrediente / upgrade | porta dos fundos → traseira do Pad → CW-1 → praça → Mart (prateleiras ou bancada) | ~2–4 de sanidade por perna (§10.2); à noite a Juniper Sul não tem carros (proposta §9.5) |
| Ponto seguro (ANM-010) | porta dos fundos → SS sob o letreiro | ~110 studs, ~6,5 s; o trailer fica vazio; sem trânsito durante o Hush (FEAT-033) |
| Caiu (sanidade 0) | onde estava | corpo cai → ambulância chega, **médicos descem e levam o corpo** [DEC-114] → reviver (Robux só pelo próprio caído, DEC-116; ou Revive Kit) até 6:00 AM [DEC-115], no máx. 2 por noite [DEC-129]: volta por AMB-P, aparece em REV, sem médicos. Senão, espectador [DEC-093, DEC-113] (§9.6) |
| Todos caídos | — | janela de 10 s para reviver [DEC-094], congela com prompt de compra aberto (até +20 s, DEC-118); câmera SPEC-P. Ninguém reviveu: **noite perdida** [DEC-102] → todos acordam em pé em REV-1..4 [DEC-122] (§11.2) |
| Fim 6 AM | trailer | pagamento, resumo. Noite 10: final (§11.3) |

### 8.4 Para onde vai depois

O MVP só tem este mapa. Fim da run → tela final → lobby [DEC-053, DEC-065, DEC-075]. Modo dia infinito fica neste mapa com o carrinho [DEC-058].

## 9. NPCs e veículos

Tipos e comportamento: `design/npcs.md`. Aqui só o espacial. Todos os NPCs são R6 [DEC-089].

### 9.1 Clientes — rotas

**Faixas da calçada sul:** LANE-E (Z ≈ 23, sentido leste) para quem chega do oeste e para quem sai; LANE-W (Z ≈ 18, sentido oeste) só para quem sai da porta D1. A fila fica em Z 29 (Q2–Q5) e Q1 em Z 33.

| Etapa | Dia | Noite |
|---|---|---|
| Chegada | **2026-10-10 (§9.8):** D1 35, DR-APT 35, SP-S 30 (SP-A e SP-B peso 0: > 10 s). Antes: SP-A 30, SP-B 40, D1 30 | **D1 50, SP-S 30, DR-APT 20** (antes SP-A 60, D1 40); lavanderia fechada |
| Travessias | SP-A cruza CW-4; SP-B cruza CW-2 e CW-1. Proposta (`Q-129`, Provisório): **clientes só atravessam em faixa e com reserva** (§9.5); esperam no nó de meio-fio em cada ponta da faixa até a reserva | SP-A cruza CW-4 com reserva; quase sem trânsito (§9.5) |
| Entrar na fila | vaga livre mais à esquerda, avança até Q1 | igual |
| Fila cheia | spawner não gera cliente novo | igual |
| Pedido | balão em Q1 [DEC-071] | igual |
| Saída | Q1 → LANE-E → EX-E (60%) ou D1 (40%) | igual |

**Grafo de NPC (TASK-005, `workspace.MapBinding`).** 25 nós, que seguem as rotas ROUTE-SP-A, ROUTE-D1-IN, ROUTE-QUEUE, ROUTE-EXIT-E e ROUTE-EXIT-D1. Fonte: `tools/assetplace/bind_map01.luau`; checagem: `check_map01.luau`. D1 fica 1 stud a oeste da porta, em (63, 48), para o NPC não nascer dentro da parede.
**Onda 2 (TASK-083): ROUTE-THIEF**, +8 nós (33 no total): `ST-R`, `L1`, `L2`, `L3` (pontos e nós) e `N-Z08-01` (18, 70), `N-Z08-02` (18, 56), `N-Z08-03` (18, 38) na calçada leste da Juniper Sul, `N-Z01-04` (38, 56) na faixa sul do Pad. Arestas novas: ST-R–N-Z08-01–N-Z08-02–N-Z08-03–N-Z02-02–L1; N-Z08-02–N-Z01-04–L3 (por trás do carrinho/trailer, nunca na frente do balcão); N-Z02-06–N-Z02-08–L2 (LANE-W até o poste leste; também a fuga de L2 para EX-E). Nenhuma aresta nova cruza pista nem toca a fila; as rotas de cliente da onda 1 não mudam (o A* continua achando os mesmos caminhos). A aresta ST-R–N-Z08-01 passa por BAR-S (parede só de jogador: o NPC passa pelo collision group, como SP-A em BAR-N).
**Onda 3 (TASK-098): calçadas dos passantes**, +17 nós (50 no total) e as faixas CW-1, CW-2 e CW-3 com seus pares de meio-fio (§9.3).
**Nota para a TASK-031 e o `MapIndex.Path` (Provisório):** **um nó Q (Q1–Q5) nunca é ponto intermediário de um caminho**, só origem ou destino. Sem essa regra, o A* sem direção leva a chegada D1 → Q5 por dentro da fila (Q1 → Q2 → … → Q5), porque é mais curto que a rota pela calçada (LANE-W). Dentro da fila, o `CustomerService` move o cliente vaga a vaga. Quem sai do meio da fila sem ser atendido é caso da TASK-032: ou anda até Q1 e sai por lá, ou ganha uma ligação própria. Os pontos de chegada continuam ligados só a Q5 (`architecture.md` §18.6).

Clientes normais são repetitivos para criar padrão [DEC-010]: chegam pela esquerda, saem pela direita, pelos mesmos pontos. À noite, NPC fora dessas rotas é quebra de padrão legível.

### 9.2 Ladrão (Quick Quentin, CHR-004; só de dia, dia 2+) [DEC-050]

| Etapa | Onde |
|---|---|
| Chega | de ST-R, pela calçada leste da Juniper Sul (não cruza pista) |
| Espreita | L1, L2 ou L3, visíveis do corredor do carrinho e da porta/corredores do Mart |
| Gatilho | ninguém no raio 14 de CART por 3 s |
| Abre a gaveta | até (52, 37) em ~4 s; barra de 8 s (16 s com Lock) |
| Foge | volta para ST-R pela calçada leste da Juniper Sul; de L2 foge para EX-E pela calçada |

### 9.3 Passantes (DEC-183; `Q-162`)

DEC-183: **6–8 de dia, 1–2 à noite, 0 em tensão** (a proposta antiga de 2/0 caiu). Passantes andam pelas calçadas e atravessam só nas faixas **com reserva** (§9.5), nunca entram na fila. Caminhos em `src/Shared/Content/WalkPaths.luau` (TASK-098, Provisório): cada um é uma cadeia de `NpcNode` do grafo (§9.1), na ordem de caminhada.

**2026-10-10 (§9.8, Provisório):** os 7 caminhos foram trocados por **10 de mão única** que começam e terminam numa porta ou numa ponta de rua escondida. O laço `ninth_east_loop` saiu (nascia à vista); as pontas (−108, 24), (−108, −22) e (110, −22) saíram (visíveis da fila pela calçada).

| Caminho (ida / volta) | Turno | Trajeto | Faixas |
|---|---|---|---|
| `apt_to_east` / `east_to_apt` | dia | porta DR-APT → calçada norte → **CW-3** → LANE-W leste → beco EX-E | CW-3 |
| `juniper_north_to_east` / `east_to_juniper_north` | dia | SP-A (além de BAR-N) → calçada leste da Juniper Norte → calçada norte → **CW-3** → beco EX-E | CW-3 |
| `east_to_mart` / `mart_to_east` | dia | beco EX-E → LANE-W atrás da fila → calçada leste da Juniper Sul → **CW-1** → praça → porta do Mart | CW-1 |
| `laundry_to_east` / `east_to_laundry` | dia | porta SP-B → **CW-2** → calçada oeste da Juniper Sul → **CW-1** → LANE-W → beco EX-E | CW-2, CW-1 |
| `b3_to_mart` / `mart_to_b3` | **dia e noite** | porta DR-B3 → calçada norte oeste → **CW-2** → calçada sul oeste → borda do SS → porta do Mart | CW-2 |

Regras do desenho:
- Todo caminho começa e termina **numa porta** (regra a) **ou numa ponta de rua além dos limites e fora de vista** (regra b, §9.8): o passante nunca nasce nem some à vista.
- **À noite só o caminho do oeste** (DR-B3 ↔ CW-2 ↔ Mart): nenhum passante noturno usa as rotas de cliente (D1, DR-APT, SP-S, SP-A) nem a calçada dos postes da Juniper Norte. Ele passa pela borda do SS (o Mart é 24 h; passantes saem em tensão, então nunca estão lá durante o Hush). Assim um NPC noturno fora das rotas de cliente continua sendo sinal de anomalia (§9.1) e nada puxa o olhar para o Walker. `check_map01` avisa se um caminho `Night`/`Any` tocar nó de rota de cliente.
- De dia, CW-1 recebe passantes nos dois sentidos: quem atravessa junto com eles atravessa mais seguro (FEAT-033, §9.5).
- Nós novos (17): `N-Z06-02` (57, −17) e `N-Z02-10` (57, 17) = CW-3; `N-Z08-04` (13, 38) e `N-Z08-05` (−13, 38) = CW-1; `N-Z02-14` (−18, 17) e `N-Z06-06` (−18, −17) = CW-2; `N-Z06-03` (38, −22), `N-Z06-04` (84, −22), `N-Z06-05` (110, −22), `N-Z12-01` (−34, 40), `N-Z12-02` (−54, 30), `N-Z02-11` (−72, 24), `N-Z02-12` (−108, 24), `N-Z02-13` (−40, 22), `N-Z06-07` (−40, −22), `N-Z06-08` (−76, −22), `N-Z06-09` (−108, −22). CW-4 reusa os nós da onda 1. Grafo: **50 nós** (teto 80). A aresta `N-Z02-14`–`N-Z08-05` (calçada oeste da Juniper Sul) já serve à rota SP-B quando ela entrar no grafo.
- Nenhuma aresta nova toca vaga de fila; as rotas de cliente e do ladrão das ondas 1–2 continuam com os mesmos caminhos A* (todo atalho novo é mais longo).

### 9.4 Teto de NPCs [DEC-045]

| Turno | Clientes | Ladrão | Passantes | Anomalias | Total | Teto |
|---|---|---|---|---|---|---|
| Dia | ≤ 8 | ≤ 1 | ≤ 2 | 0 | ≤ 11 | 12 |
| Noite | ≤ 6 | 0 | 0 | ≤ 3 | ≤ 9 | 12 |

Fora do teto: **médicos (2) e maca**, atores visuais da ambulância dirigidos pela linha do tempo do servidor (FEAT-009, FEAT-034, NPC-024, `tech/architecture.md` §6.3); Opal (estática, `Q-091` a); Walt (só na cutscene final, DEC-076). **Veículos não contam** no teto de NPCs: têm teto próprio (§9.5). Motoristas são silhuetas fixas dentro do carro (não são NPC).

### 9.5 Trânsito e travessias (DEC-087, DEC-095, DEC-103, DEC-130) — proposta do level-designer, `Q-102`, `Q-129`

**Ajuste final da revisão 3:** DEC-130 tira **todos** os semáforos (revoga DEC-120). Rodada 17 (`Q-128`, opção B; secretário registrando): a Juniper Sul **continua aberta** a carros de dia e a rota trailer ↔ Mart atravessa CW-1 **sem semáforo**. O cruzamento segue com 4 braços (a menção a "T" em DEC-130 vem da revisão 2, quando a Juniper Sul era beco). O Mart, o Pad e a linha de visão não mudam.

**Rotas** (cadeias de waypoints nomeados; mantidas, sem sinal). `(SL-x)` = linha de faixa: o carro só para nela se há reserva de NPC ativa naquela faixa; `PARE` = para sempre 1 s.

| ID | Rota | Comprimento aprox. | Turno |
|---|---|---|---|
| TR-1 | W-IN → Ninth EB → (SL-W) → cruzamento reto (preferencial) → (SL-3W) → E-OUT | 272 | dia e noite |
| TR-2 | E-IN → Ninth WB → (SL-3E) → (SL-E) → cruzamento reto (preferencial) → W-OUT | 272 | dia e noite |
| TR-3 | JN-IN → Juniper SB → PARE SL-N → vira à esquerda (leste) → (SL-3W) → E-OUT | 280 | dia |
| TR-4 | JN-IN → Juniper SB → PARE SL-N → vira à direita (oeste) → W-OUT | 280 | dia |
| TR-5 | W-IN → Ninth EB → (SL-W) → vira à esquerda (norte) → JN-OUT | 280 | dia |
| TR-6 | E-IN → Ninth WB → (SL-3E) → (SL-E) → vira à direita (norte) → JN-OUT | 280 | dia |
| TR-7 | JS-IN → Juniper NB → (SL-1S) → PARE SL-S → reto → JN-OUT | 256 | dia |
| TR-8 | JN-IN → Juniper SB → PARE SL-N → reto → (SL-1N) → JS-OUT | 256 | dia |
| TR-9 | W-IN → Ninth EB → (SL-W) → vira à direita (sul) → (SL-1N) → JS-OUT | 252 | dia |
| TR-10 | JS-IN → Juniper NB → (SL-1S) → PARE SL-S → vira à direita (leste) → (SL-3W) → E-OUT | 252 | dia |

Distância do spawn até a 1ª faixa da rota (regra de FEAT-033: ≥ 55): W-IN → SL-W 108; E-IN → SL-3E 72; JN-IN → CW-2/CW-4 (virando no cruzamento) ~150; JS-IN → SL-1S 70. Todas atendem.

**Regra sem semáforo — proposta para `Q-129`** (game-designer + level-designer; **Provisório** até resposta). Os números são os de FEAT-033 `Traffic.Crossing` (Rascunho, game-designer); aqui fica a parte espacial:

| Tema | Proposta | Parte espacial (este mapa) |
|---|---|---|
| Cruzamento | **Ninth preferencial**, nunca para. **PARE nas duas bocas da Juniper**: carro para 1 s em SL-N / SL-S e entra quando a caixa do cruzamento está livre | placas PARE-N (−14, −20) e PARE-S (13, 17). SL-S em Z 20 fica fora da linha de visão Mart → carrinho; a ambulância (Ninth) nunca para |
| Faixas CW-1..CW-4 | **continuam pintadas**: guia de rota e landmark no celular, e o único lugar onde NPC cruza a pista. **Não protegem o jogador** | a cutscene (§11.1, CS-4) mostra um carro passando sem parar antes da party atravessar. Alternativa: tirar a pintura (perde o guia de rota) |
| Jogador | atravessa quando e onde quiser; carro nunca para nem desvia por ele (DEC-095, DEC-130) | — |
| NPCs (clientes, passantes) | só atravessam **em faixa**, com **reserva** pedida no nó de meio-fio (dada se nenhum carro está a < 15 studs da linha); com a reserva, os carros que chegam **param na linha da faixa** até o NPC sair (máx. 4 s). NPC nunca é atropelado | linhas de faixa: CW-1 → SL-1N / SL-1S; CW-3 → SL-3W / SL-3E; **CW-2 e CW-4 → SL-W e SL-E juntas** (a reserva de uma faixa da Ninth junto ao cruzamento segura os dois lados, para nenhum carro parar dentro da caixa) e a caixa conta como ocupada para o PARE. Nó de espera em cada ponta de faixa, na calçada, a 2 studs do meio-fio |
| Ladrão | não cruza pista | chega e foge pela calçada leste da Juniper Sul (inalterado) |
| Ambulância e long car | roteirizados; Ninth, sem parar no cruzamento | à noite não há carro na Juniper |

**Regra de conversão (debugger, 2026-10-10; registrada aqui, Provisório):** rota da Juniper que **vira para a Ninth** (TR-3, TR-4, TR-10) para na **linha de PARE** (SL-N / SL-S) também quando há reserva de NPC em **CW-4 / CW-2**, antes de entrar no cruzamento: a faixa que ela vai cruzar depois da curva fica logo na saída do cruzamento e não há linha própria entre os dois. Por isso `Content.Traffic` lista a mesma linha duas vezes em seguida (`Pare` e `Crosswalk` em SL-N/SL-S) e o `check_map01` aceita a repetição.

Efeito aceito por FEAT-033: atravessar junto com um NPC é mais seguro (os carros param para ele). No mapa, isso acontece sobretudo em CW-1 (SP-B) e CW-4 (SP-A), longe da linha de visão Mart → carrinho.

**Densidade por fase** (números de FEAT-033 para o teto; distribuição por fase é proposta):

| Fase (hora do jogo) | Carros em movimento ao mesmo tempo | Intervalo entre spawns | Rotas |
|---|---|---|---|
| Preparação 7–8 AM | ≤ 2 | ~15 s | TR-1..TR-10 |
| Loja aberta 8 AM–6 PM | ≤ 4 | 6–10 s por rota (FEAT-033) | TR-1..TR-10 |
| Fechamento 6 PM | ≤ 2 | ~15 s | TR-1..TR-10 |
| Noite, 8–9 PM | **≤ 1** | ~30 s (FEAT-033; `Q-103` aberta) | **só TR-1 e TR-2** (Ninth reta): a Juniper Norte e a Juniper Sul ficam sem carros à noite (proposta, §15 P32) |
| Noite, depois das 9 PM | **0** (FEAT-033) | — | só ambulância e ANM-008 |
| Sem trânsito | — | — | durante ANM-008 ativa (nenhum carro nasce), Hush (ANM-010), cutscenes e Final (FEAT-033) |
| Exceções noturnas | ambulância (§9.6) e long car (ANM-008, §9.7) | roteirizados | — |

**Binding (TASK-098, Provisório; tags da TASK-097):** `MapBinding/Traffic`. **Rotas** = `Folder` `TR-n` (tag `TrafficPath`, `PathId` = `Content.Traffic.Routes[].Path`) com `Part` filhas `01..nn` (`Index` 1..n, cada uma virada para a próxima, no topo da pista): faixas EB Z 5, WB Z −5, SB X −6, NB X 6; curvas com 2–3 nós dentro de `X-T`; o 1º nó fica no ponto de entrada (`W-IN` etc.) e o último num `*-OUT`. **Linhas** `SL-*` = `Part` atravessando a(s) faixa(s) que param ali (tag `TrafficLine`, `LineId`; `LookVector` = sentido de quem para; largura 12 na Juniper, 16 na Ninth). **Caixas** `X-T` (X −12..12, Z −16..16) e `CW-1..4` (as listras de §5.2), 10 de altura (tag `TrafficBox`, `BoxId`). Tudo invisível, sem colisão. O `TrafficService` acha `StopDist` cruzando o caminho com o plano da linha; a velocidade de cruzamento (12) vale dentro de `X-T`. Distâncias do spawn até a 1ª linha de faixa: TR-1/5/9 108, TR-2/6 72, TR-7/10 70, TR-3/8 ≥ 120 (todas ≥ 55).

Carros parados (estáticos, ancorados): ~4 em PARK-N oeste, ~2 em PARK-N leste, ~4 no estacionamento (inclui a van de AS-1). Nunca no meio-fio vermelho.

**Comportamento** (FEAT-033, Rascunho; resto em `Q-122`):
- Velocidade 22 studs/s na reta, 12 no cruzamento (FEAT-033). Sem semáforo [DEC-130]; para só no PARE da Juniper e na linha de faixa com reserva de NPC (proposta `Q-129`).
- **O carro não para** por jogador, na faixa nem fora dela [DEC-095, DEC-130]. Não há travessia garantida: o jogador olha e escolhe a brecha.
- Contato a ≥ 6 studs/s → ragdoll; **o item da mão cai** e **não há perda de sanidade** [DEC-103]. Tempo no chão, proteção e regra exata do item: `Q-122` (FEAT-033 propõe 2,5 + 0,5 s e 5 s de proteção).
- NPCs: faixa + reserva (tabela acima, `Q-129`), então nunca cruzam com carro.

**Por que o desenho é assim:** a rota que o jogador faz dezenas de vezes por dia (Pad ↔ Mart) cruza a pista **uma vez**, em CW-1, no meio da quadra e de costas para a Juniper Norte. Sem semáforo, a pista a atravessar é curta (24 studs, 1,5 s) e o fluxo da Juniper Sul é baixo (FEAT-033: 1 carro a cada 12–20 s por sentido, ~1 a cada 8 s somando os dois), então "esperar a brecha ou arriscar" custa ~1 s em média. A fila (Pad ↔ calçada sul) não cruza pista. À noite, sem carros na Juniper, a corrida para o Mart e para o SS não exige olhar para o norte (§6).

### 9.6 Ambulância, reviver e espectador (DEC-091 a DEC-094)

Sanidade só existe à noite (DEC-056), então a ambulância só aparece à noite, com trânsito raro (§9.5). Tempos e regras de jogo: **FEAT-034** (game-designer, tabela `Ambulance`); aqui só o espacial.

| Fase | Onde | O que acontece |
|---|---|---|
| Queda | onde o jogador estava | corpo cai no chão (pose deitada, sem ferimento). Colegas veem. O servidor **despacha a ambulância na hora** para a parada mais próxima do corpo (FEAT-034) |
| Chegada | AMB-IN → Ninth EB | entra pelo oeste e chega à parada em **~8 s** (FEAT-034). Barra de luz **Mustard/Teal** girando (`art/style-guide.md`, Aprovado; AST-052), sirene curta e suave, nunca acima do ambiente (DEC-005). Passa pelo cruzamento **sem parar** (Ninth tem preferência; sem semáforo, DEC-130; `tech/architecture.md` §6.3); cruza a Juniper em < 1 s, sem entrar nela |
| Parada | AMB-M (queda a oeste de X −24) ou AMB-P (resto) | encosta na faixa do meio-fio sul |
| Coleta (ida) | 2 médicos R6 com maca | **os médicos descem** pelas portas traseiras, vão até o corpo, levam e sobem [DEC-114]. Coleta (`CollectTime`, FEAT-034): até 10,5 s, alcance 80 studs a 20 studs/s; não é a janela de reviver. Caminhos (portas traseiras em X 35): AMB-P → porta dos fundos do trailer pela lateral leste do Pad **~52**; corpo **dentro** do trailer: +5 a +23 (até **~75** no fundo oeste, X ~27); AMB-P → Pad e calçada (≤ 30); AMB-M → SS, praça ou Mart (~10–35). FEAT-034 propõe `MedicReach` 60: ver §15 P35 |
| Saída | AMB-OUT | segue reto para o leste |
| Reviver [DEC-092, DEC-100] | AMB-IN → **AMB-P** → REV-1..4 | a ambulância volta, para em frente ao trailer, o jogador aparece **de pé** em REV ao lado dela, a ambulância vai embora. **Ninguém desce** [DEC-091, DEC-114] |
| Noite perdida [DEC-102, DEC-122] | REV-1..4 | tela escura → **todos acordam em pé na calçada ao lado do trailer** (REV-1..4, virados para o Pad) enquanto a ambulância sai de AMB-P **com a sirene desligada** → noite repetida (FEAT-026). Banco do fundo não é usado |
| Espectador [DEC-093, DEC-113] | sem personagem no mundo | câmera: SPEC-P ou SPEC-M enquanto o próprio corpo é levado, depois a 1ª pessoa de um colega de pé (toque troca o alvo). Sem colega de pé (janela de 10 s, DEC-094): SPEC-P |

Regras de convivência:
- **Uma ambulância por servidor** (FEAT-034, NPC-023). Quem cai durante uma viagem entra nela se ela ainda está parada na mesma parada; senão, na próxima viagem (FEAT-034). Várias quedas dos dois lados: AMB-M e depois AMB-P na mesma passada (oeste → leste).
- **Nunca atropela** (sem colisão; `Q-122` c); FEAT-033 propõe que pare diante de jogador na frente.
- **Nunca entra na Juniper** e não para no cruzamento: o fim da Juniper só aparece no fundo da tela por menos de 1 s quando a ambulância cruza. Risco residual de um passo do Walker para quem segue a ambulância com os olhos (§15 P30).
- **ANM-008:** a ambulância **não é despachada** enquanto ANM-008 ou ANM-010 estão ativas; despacha quando terminam (FEAT-034). O long car fica no lado norte (AN-12) e a ambulância usa a faixa do meio-fio sul.
- **ANM-010:** médicos podem entrar em SS para buscar um corpo; não são anomalia (§10.4).
- **Todos caídos** (DEC-094, DEC-118): a ambulância já foi despachada na queda de cada um (FEAT-034); a janela de 10 s corre ao mesmo tempo. Se ninguém revive, é noite perdida (linha acima).
- Espectador não tem personagem: não conta para "ver anomalia" nem para os passos do Walker.

### 9.7 Atores de anomalia com rota (ANM-007, ANM-008, ANM-005)

| Anomalia | Rota no mapa |
|---|---|
| ANM-007 The Walker | aparece em JL-09 (além de BAR-N, fora do alcance). Avança poste a poste pela calçada oeste (§5.6). Nunca usa a rota de clientes (eles descem pela calçada **leste**) |
| ANM-008 The long car | entra por E-IN, Ninth WB, passa da entrada do estacionamento, **dá ré na boca da entrada** e para em AN-12 (70, −22), **de frente para o sul**, farol alto na janela do trailer (~63 studs). Sai virando à esquerda para a Ninth EB → E-OUT. Nunca entra na Juniper nem passa pelo Mart. À noite o trânsito é raro (1 carro, só na Ninth reta, §9.5) e **nenhum carro nasce enquanto a ANM-008 está ativa**; a quebra de padrão é ser o **único carro que para no meio-fio** e o único com farol alto (`design/npcs.md` N8, FEAT-033, `Q-103`) |
| ANM-005 The Raincoat Lady | rota normal de cliente (SP-A ou D1), deixando poças pelo caminho |

### 9.8 Spawn e despawn (2026-10-10, level-designer; Provisório)

**Regra:** NPC (cliente, ladrão, passante, ator de anomalia) **nunca aparece nem some à vista do jogador**. Ele nasce/some:
- **(a) numa porta de prédio** — D1 (B1), DR-APT (Bellmoor Savings / apartamentos), SP-B (lavanderia), DR-B3 (B3b), MKT-DOOR (Mart). O ponto fica na soleira, 0,8 à frente da folha; a folha tem tag `AutoDoor` e abre por proximidade no client (§16.8). Vale mesmo à vista: quem olha vê "alguém saiu/entrou pela porta";
- **(b) numa ponta de rua além dos limites do jogador** (BAR-N, BAR-S, BAR-E) **e fora da linha de visão** do Pad (PS-1..4), da fila (Q1..Q5), da porta do Mart e do SS — SP-A, SP-S, ST-R, EX-E, e os AS-1..4 dos atores.

Rota até a fila **≤ ~100 studs** (≤ 10 s a 13 studs/s); ponto mais longe fica com peso 0 em `Content.Flow.Spawns` (SP-A 136, SP-B 151). Distribuição por turno em `Content.Flow.Spawns` (chegadas e saídas de cliente); ladrão em `Content.Thief` (ST-R); passantes nas pontas de `Content.WalkPaths` (§9.3); atores de anomalia usam as chegadas de cliente ou os AS-1..4.

**Contrato no place** (`bind_map01.luau`, W6): o `MapPoint` (que também é `NpcNode`) leva `Spawn` (lista separada por vírgula: `customer`, `thief`, `pedestrian`, `actor`), `Despawn` (bool), `SpawnKind` (`door` | `edge`) e, nas portas, `Door` (id da porta). O código lê os pontos pelo id em `Content`; os atributos servem ao `check_map01` (regras 12 e 13) e a quem edita o place.

Escala: **1 coluna = 8 studs (X)**, **1 linha = 8 studs (Z)**. Norte para cima. Aproximado (±4).

```
  X →  -128      -96      -64      -32       0        32       64       96      128
         |        |        |        |        |        |        |        |        |
 -104  ##########################~~~~::=v^=::A###############################       A  SP-A (29,-92) pedestre/ator (cliente peso 0)
  -88  ##########################a~~~:5=v^=::######......................####       a  AS-3 (-30,-104) ator   5 JL-05 (passo 0)
  -76  ##########################xxxxxxxxxxxxx######......V...............####       x  BAR-N (Z -76)          V AS-1 atrás da van
  -72  ##########################::::::4=v^=::######.........................####       4  JL-04 (passo 1)
  -56  ##########################::::::3=v^=::######.........................####       3  JL-03 (passo 2)
  -40  ################b#########::::::2=v^=::#P####.........................####       2  JL-02 (passo 3)  b SP-B porta lavanderia  P DR-APT porta banco/apart.
  -32  #####G####################::::::1=v^=::#################################       G  DR-B3 porta B3b        1 JL-01 (passo 4)
  -24  :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::      calçada norte
  -16  ====================%%=============%%=========%%==========================      NINTH (CW-2 | CW-4 | CW-3)
    8  =========================================================================
   16  ::::::::::::::::::::::::::::::::::::P::::::::::::::::::::::::::2:::::::::::     P  P-01 (Hush, fora do Walker)   2 AS-2 atrás do caminhão
   24  ::::::::::::::::::::::S:::::::::::::::5432:1:::::::::::::::::::::::::::::E:      fila Q5..Q1; S = SS
   32  ############MMMMMMMMMM_m________::%%%%%%::,,,,,,,,,,,,,########################E     m  MKT-DOOR porta Mart   E  EX-E (116.5,40) beco além de BAR-E
   48  ############MMMMMMMMMM__________::=v^=::,,,,,,,,,,,,d#########################.      d  D1 porta B1
   64  ############MMMMMMMMMM##########::=v^=::##########################################
   80  ##############################xxxxxxxxxxx############################################   x  BAR-S (Z 80)
  100  ##############################::=v^=::S#############################################   S  SP-S (21,100) cliente/ator
  108  ##############################::=v^=::R#############################################   R  ST-R (21,108) ladrão
```

| Ponto | Tipo | Posição | Papéis (`Spawn`) | Some aqui | Por que fica fora de vista |
|---|---|---|---|---|---|
| D1 | porta | (63, 48) | customer, actor | sim (saída 40%) | regra (a); `AutoDoor` |
| DR-APT | porta | (32, −31) ou medida no AST-044 | customer, pedestrian | sim | regra (a) |
| SP-B | porta | (−40, −31) medida no AST-046 | pedestrian (clientes peso 0) | sim | regra (a); fechada à noite |
| DR-B3 | porta | (−93.3, −31.2) | pedestrian (dia e noite) | sim | regra (a) |
| MKT-DOOR | porta | (−62, 34) | pedestrian (24 h) | sim | regra (a); folha placeholder `Door_Leaf` se o AST-028 não tiver folha |
| SP-A | ponta | (29, −92) | customer (peso 0), pedestrian, actor | sim | além de BAR-N; o fundo do banco (X 24..52, Z −88..−64) tapa da porta do Mart e do SS; o banco tapa do Pad |
| SP-S | ponta | (21, 100) | customer, actor | sim | além de BAR-S; o prédio de trás de B1 (X 24..40, Z 64..83) tapa de Q5 (raio passa em X ~26 em Z 64) e do Pad; B5 tapa do Mart |
| ST-R | ponta | (21, 108) | thief | sim | idem SP-S, mais fundo |
| EX-E | ponta | (116.5, 40) | pedestrian | sim (saída 60%) | beco X 113..120 atrás de B1 (X 64..113, Z 32..50): da fila, do Pad e da porta do Mart o raio entra em B1 |
| AS-1..4 | ponta / porta | §10.3 | actor | sim | já existentes; o `check_map01` regra 13 mede |

Tempos (A*, AvoidQueue, a 13 / 9 studs/s): D1 → Q5 ~79 (6,1 / 8,8 s); DR-APT → Q5 ~80 (6,1 / 8,9 s); SP-S → Q5 ~93 (7,1 / 10,3 s); SP-A → Q5 ~136 (10,5 / 15 s, peso 0); Q1 → EX-E ~85 (6,5 s); Q1 → D1 ~25.

**Conferência** (`check_map01` regra 13, só no Studio): raycast do olho (4,5) de PS-1..4, Q1..Q5, MKT-DOOR e SS até um corpo R6 no ponto (3 alturas × 3 deslocamentos), até 200 studs (fim da névoa); peças ≥ 30% transparentes não tapam; veículos, NPCs, binding e marcadores ignorados. Ponta à vista = aviso; porta à vista = info. Conta de mesa (antes do Studio): SP-A, SP-S, ST-R e EX-E escondidos de todos os 11 pontos; a margem mais apertada é SP-S/ST-R vistos de Q5 (o raio passa ~1,5–2,6 studs dentro da quina do prédio em X 24).

## 10. Dia × noite

### 10.1 Tabela por zona

| Zona | Dia | Noite |
|---|---|---|
| Pad | sol, sombra do guarda-sol | trailer aceso; Trailer Lights (raio 18) se comprado |
| Ninth Avenue | trânsito; postes apagados | postes **apagados** entre o Pad e o Mart (a rota escura de DEC-049; `Q-090`); trânsito raro (1 carro, §9.5) |
| Juniper Norte | trânsito | postes JL-01..09 e P-01 **acesos** (amarelos, `world.md` §5), até o Hush; sem carros (proposta §9.5) |
| Mart + praça | aberto | aberto 24 h, interior aceso, letreiro "OPEN 24 HOURS" sempre aceso |
| Estacionamento | trailer à venda, carros | escuro; carrinho sob lona |
| Juniper Sul | trânsito; ladrão pela calçada leste | escura, sem carros (proposta §9.5); CW-1 só pintada |
| Banco/apartamentos | relógio, janelas neutras | relógio com mostrador emissivo e tique-taque; janelas apagadas ("ninguém mora lá em cima", `ending.md` §3) |
| B1 | janelas neutras | algumas janelas emissivas |

### 10.2 Zonas de luz (regra de sanidade "escuro", DEC-041, DEC-056)

A regra do escuro usa **volumes de luz marcados no mapa**, não o cálculo de luz do motor (style guide §5.1: nenhuma mecânica depende de sombra). Fora deles = escuro. Postes da Juniper e P-01: proposta do level-designer = **luz visual**, não volume; FEAT-020 (Rascunho) propõe que sejam volume e o Hush os apague. Decide `Q-090` (§15 P19).

| ID | Volume | Centro / limites | Raio | Condição |
|---|---|---|---|---|
| LZ-1 | interior do trailer | X 27..53, Z 36..46 | — | **interruptor ligado** (FEAT-020; é o que faz a ANM-003 custar escuro). Apagada do Hush até os postes voltarem (FEAT-020). `Q-064` |
| LZ-2 | varanda do balcão | X 44..56, Z 30..35 (cobre Q1) | — | mesma condição de LZ-1 (proposta; FEAT-020 não lista a varanda: game-designer confirma em `Q-064`) |
| LZ-3 | **Trailer Lights** | (40, 41) | 18 | upgrade + interruptor ligado [DEC-055]; apagada durante o Hush (FEAT-020) |
| LZ-4 | interior do Mart | X −100..−64, Z 32..64 | — | sempre |
| LZ-5 | **ponto seguro SS** sob o letreiro | (−58, 30) | 6 | sempre [`anomalies.md` N10] |

| Trajeto | Com LZ-3 | Sem LZ-3 |
|---|---|---|
| Porta do trailer → Mart (uma perna) | ~85 studs no escuro ≈ 5,3 s → **~2** de sanidade | ~110 ≈ 6,9 s → **~4** |
| Porta do trailer → SS | ~75 ≈ 4,7 s → **~2** | ~103 ≈ 6,4 s → **~3** |

Ir ao ponto seguro agora custa um pouco de sanidade (antes era zero, com o SS a 39 studs). Fica com o game-designer (`Q-090`).

### 10.3 Âncoras de anomalia

O mapa oferece **pontos nomeados**; a ficha técnica da anomalia (game-designer, `design/`) escolhe. Mapeamento com as anomalias aprovadas (`anomalies.md`, DEC-073, DEC-096):

| ID | Ponto | Posição | Visto de | Anomalia |
|---|---|---|---|---|
| AN-01 | vaga do estacionamento (carrinho sob lona à noite) | (78, −58) | janela, à frente | reserva |
| AN-02 | caminhão leste | (98, 13) | janela, à direita | reserva |
| AN-03 | poste P-01 e o panfleto | (20, 20) | janela, à esquerda | reserva (pista DESCOBRIR); P-01 é também o último poste de ANM-010 e o passo 9 de ANM-007 |
| AN-04 | janelas WV-1..3 dos apartamentos sobre o banco | X 28..48, Z −33, alturas 19–28 | janela, acima do horizonte | **ANM-006** The wavers |
| AN-05 | porta dos fundos do trailer | (49, 47) | **de costas** | **ANM-009** The knock |
| AN-06 | objetos do trailer (esteira, tábua, gaveta) | interior | trabalho | **ANM-002** The wrong food |
| AN-07 | fila Q1–Q5 e calçada sul | §5.1 | janela | **ANM-001**, **ANM-004**, **ANM-005** |
| AN-08 | ~~funcionário do Mercado~~ | — | — | **retirada** na revisão 2: a atendente é Opal (CHR-003), fixa e amigável [DEC-079, DEC-099]. Substituída por AN-12. ID não será reaproveitado |
| AN-09 | Juniper Norte, cadeia JL-09 → JL-01 → P-01 | §5.6 | janela, ~25° à esquerda, 82–135 studs | **ANM-007** The Walker; **ANM-010** The Hush |
| AN-10 | porta da lavanderia fechada | (−40, −32) | janela, longe à esquerda | reserva |
| AN-11 | relógio C-01 do Bellmoor Savings | (39, −33) | janela | **ANM-003** The stopped clock |
| AN-12 | **boca da entrada do estacionamento** ("o meio-fio do outro lado da rua") | (70, −22), de frente para o sul | janela, à frente | **ANM-008** The long car |

Teto de 3 atores simultâneos [DEC-045]: atores = ANM-001, 004, 005, 006, 007, 008 (`anomalies.md`). ANM-003 e ANM-010 são eventos de ambiente; ANM-002 e ANM-009 são objeto/som.

Spawns ocultos de atores (fora de vista do Pad, da janela e do Mart): AS-1 atrás da van no canto NE do estacionamento (92, −80); AS-2 atrás do TRUCK (100, 18); AS-3 atrás de BAR-N, no beco lateral oposto a SP-A (−30, −104); AS-4 atrás da porta da lavanderia (−40, −36). O long car usa E-IN; o Walker aparece em JL-09 (além do limite e na névoa).

**Binding (TASK-098, Provisório).** `MapPoint`: `AN-04` (38, altura 26,3, −31; centro de WV-2), `AN-11` (39, altura 14, −31; mostrador do C-01), `AN-05` (49, altura 7,45, 46,5; vidro da porta dos fundos, por dentro, trailer no Pad), `AN-12` (70, −22) no chão com a frente para o sul (pose do long car), `AS-1..4` no chão virados para o Pad (AS-4 para a rua), `WALKER-10` (28, 29) virado para a janela, `SS` (−58, 30) no centro de LZ-5. As demais âncoras desta tabela (AN-01..03, 06, 07, 09, 10) não viram ponto: são objetos já tagueados (postes, fila, estações) ou reserva. Janelas: tag `AnomalyAnchor` + `AnchorId` WV-1..3 em `Window_Up_1..3` do AST-045 (X 31 / 38 / 45, vidro 24,6–28); sem o modelo novo no place, o bind cria uma `Part` invisível `WV-n` em `MapBinding/Anomaly` e avisa (P49).

### 10.4 Regra do ponto seguro (`Q-092`)

> **Secretário, 2026-10-10 — DEC-177 (fecha `Q-092`, contra a proposta abaixo):** o SS **pode** receber anomalia. A proposta "nunca recebe" **não vale**; também caem a tabela SS ("Nunca recebe anomalia"), o critério de aceite ("nunca recebe anomalia") e P15. Outras pendências fechadas na mesma sessão: P8 colisão **desligada** (DEC-175; alcance todo o mapa Provisório), P10 **"Out of stock"** (DEC-180), P16 esconder **por jogador, 4 pontos** (DEC-176). Reescrita → level-designer, com `Q-161`.

Proposta: **SS nunca recebe anomalia nem ator de anomalia.** Médicos (§9.6), Opal e Walt (final) não são anomalia. Nenhuma rota de anomalia passa por Z-12. O long car não passa pela Ninth Oeste.

## 11. Cutscenes [DEC-021, DEC-075, DEC-088]

POV em 1ª pessoa; em party, cena **compartilhada**: cada jogador vê pela própria cabeça e vê os avatares dos colegas [DEC-088]. Personagens dirigidos pelo servidor ao longo dos pontos abaixo; câmera presa na cabeça de cada um. Pulável com 50% dos votos [DEC-078]. Sem braços [DEC-097].

### 11.1 Abertura (~35–45 s)

Formação: 2 × 2 (colunas a ±2 studs do eixo, fileiras a 3 studs). Solo: no eixo.

| Ponto | Posição | Beat (`script.md` §1) |
|---|---|---|
| CS-1 | (−100, −24), calçada norte da Ninth, indo para o leste | manhã; carros passando; pombos |
| CS-2 | (−60, −24) | três vitrines com "NO HELP WANTED" em B3 e na lavanderia (X −92, −56, −32) |
| CS-3 | (−18, −22), quina NO | vira para o sul |
| CS-4 | CW-2 → (−18, 22) | a party para no meio-fio; **um carro roteirizado passa na frente sem parar** (Ninth EB); depois a party atravessa a Ninth na faixa (ensina sem texto: carro não para, olhe e espere a brecha) [DEC-130]. Trânsito normal desligado na cutscene (FEAT-033) |
| CS-5 | calçada oeste da Juniper Sul → **CW-1** (sem carro) → P-01 | a party olha para os dois lados e atravessa: é a travessia que o jogador vai usar para ir ao Mart. Slots CS-P1..P4: (16, 25) · (19, 27) · (23, 26) · (13, 22), todos virados para o panfleto (face SO do poste) |
| CS-6 | mesmo lugar | close no panfleto (FOV fecha); ligação para Walt (legenda) |
| CS-7 | mesmo lugar | todos viram para o SE: o **carrinho** no Pad, sob o sol |
| FIM | fade → PS-1..4 | 7:00 AM, Day 1 |

**Binding (TASK-098, Provisório).** Marcas de partida `CutsceneMark1..4` (`Content.Cutscenes` intro `Marks`) em volta de CS-1, 2 × 2 virado para o leste: (−100, −26) · (−100, −22) · (−103, −26) · (−103, −22). `CS-1..5`, `CS-P1..4` como na tabela (CS-3 → CS-4 corre dentro de CW-2; CS-5 = meio de CW-1). `CS-5W` (−14, 38) e `CS-5E` (14, 38), meios-fios de CW-1, já no place e usados pela intro desde P46 (CS-4 → CS-5W → CS-5E → CS-P{slot}).

### 11.2 Outros momentos de câmera

- **Troca carrinho → trailer** (DEC-047): fade; plano do trailer já no Pad (C-01 marcando 6 PM) + ligação.
- **Noite perdida** (DEC-053, emendada por DEC-122): luzes piscam e apagam → tela escura → **todos acordam em pé na calçada ao lado do trailer** (REV-1..4, virados para o Pad), enquanto a ambulância sai de AMB-P com a sirene desligada → ligação do chefe → noite repetida (§9.6). O banco do fundo não entra na cena.
- **Queda e espectador** (DEC-091, DEC-093): SPEC-P / SPEC-M (§5.5).

### 11.3 Final (noite 10, `ending.md` A1)

| Momento | Onde |
|---|---|
| ~5:45 AM, Hush roteirizado | P-01 apaga; o trailer fica escuro; a party corre para SS |
| Walker parado | JL-09 (fim da Juniper). De SS, ele fica **fora da tela** se a party olhar para o Mart ou para o Pad |
| 6:00 AM | sol nasce a leste; postes religam; o Walker some; o relógio do banco bate seis vezes (som) |
| Cutscene (fade de encaixe) | party em slots SS-1..4: (−54, 26) · (−52, 30) · (−54, 34) · (−56, 23), virados para o oeste. **Walt (CHR-001)** sai por MKT-DOOR com dois cafés e para em WALT-1 (−60, 30) [DEC-075, DEC-076] |
| Plano final | Raincoat Lady pela calçada norte da Ninth Oeste, de RL-1 (−100, −22) a **RL-END (−76, −22)**, some numa poça. Todos olham para o norte-noroeste; o Walker já sumiu |
| Binding (TASK-098) | `SS-1..4` virados para o oeste; `WALT-1` virado para o leste; `MKT-DOOR` (−62, 34) virado para WALT-1; `RL-1` e `RL-END` virados para o leste (Provisório) |
| Pós-créditos | close no P-01 com o panfleto novo (AN-03) |

## 12. Assets necessários (pedido ao art-director)

Chaves `L01-##` são provisórias; coluna AST = ficha de `art/asset-list.md` (todas Rascunho), conferida com a tabela "Conciliação com MAP-01 §12" daquele documento na revisão 3. Packs no repositório (CC0): **FoodPack** e **KitchenPack**. **Não há kit de cidade nem de veículo no repositório.** "Ficha nova" = ainda não existe ficha: pedido ao art-director.

### 12.1 Veículos e estações (heróis)

| Chave | Asset | Medidas (studs) | AST | Nota |
|---|---|---|---|---|
| L01-01 | Carrinho do chefe | linha de 26 × 3 × **3,0** (DEC-157; era 3,5); 2 guarda-sóis a 9 | AST-026 | medidas iguais nos dois documentos |
| L01-02 | Estoque de salsicha + Cooler 2/3 | 3 × 3 | AST-018 | o Cooler é a própria caixa que cresce |
| L01-03 | Grelha (2 / 3 / 4 vagas) | 5 (carrinho), 6 (trailer) | AST-012 | |
| L01-04 | Esteira de descanso | 3 | AST-013 | |
| L01-05 | Caixa de pães + tábua | 2 + 3 | AST-015, AST-014 | |
| L01-06 | Grade de complementos 3 × 2 | 6 × 3 | AST-017 (tigelas, DEC-218) | 6 ingredientes [DEC-071] |
| L01-07 | Entrega + gaveta (+ cadeado) | 4 | AST-020 | |
| L01-08 | Food Trailer (2 estados: à venda / em operação) | casco 28 × 12, altura externa ~11, pé-direito 8,5 | AST-027 | medidas iguais nos dois documentos |
| L01-09 | Trailer Lights | — | AST-023 | |
| L01-10 | Cafeteira (fixa no trailer, DEC-125) | 3 × 3 | AST-022 | |
| L01-11 | Interruptor | contraste alto | AST-039 | |
| L01-12 | Banco do fundo (3 lugares, **cenário**) | 9 × 3 | AST-040 | DEC-122: não é lugar de acordar. Uso "amanhecer da noite perdida" em AST-040 está velho (AD-9) |
| ~~L01-13~~ | ~~Armário baixo "Hide" (×4)~~ | — | AST-041 | **sai (DEC-221)**; no lugar, botão da janela (placeholder, sem AST) ao lado do AST-039 e aba `Awning` do AST-027 |
| L01-14 | Lixeiras | 2 × 2 | AST-025 | |
| L01-15 | Placa OPEN / CLOSED | ≤ 3 de altura | AST-024 | |
| L01-16 | Pedestais + marcas Q1–Q5 | — | AST-019 | |
| L01-17 | Placa "Available on Day 5" | 4 × 5 | AST-024 (variação) | |
| L01-18 | Lona do carrinho | veste 26 × 4 × 4 | AST-043 | uso depende de `Q-082`; a cutscene §11.1 não tem lona (AD-15) |
| L01-19 | Telefone fixo do veículo (carrinho e trailer) | 0,9 × 0,5 × 1,3 | AST-042 | todas as ligações [DEC-124] |

### 12.2 Cidade e trânsito

| Chave | Asset | Medidas | AST | Nota |
|---|---|---|---|---|
| L01-20 | Kit de rua: pista, cruzamento de 4 braços, faixa de pedestre, linha de parada, meio-fio normal/vermelho, calçada, curva de saída | Ninth 32, Juniper 24; calçadas 16 / 12 | AST-032 | modular em múltiplos de 4. **Placa PARE** nas bocas da Juniper (PARE-N, PARE-S) e linhas de parada em SL-N/SL-S (PARE) e nas linhas de faixa SL-W, SL-E, SL-1N, SL-1S, SL-3W, SL-3E (proposta `Q-129`); faixas pintadas conforme `Q-129`. Sem semáforo (DEC-130) |
| L01-21 | Piso do Pad | 40 × 32 | AST-032 (`Pad_Tile`) | cor própria |
| L01-22 | Poste de rua: aceso / apagado / piscando | ~14 | AST-036 | JL-01..09 usam este; `SpotLight` (§13) |
| L01-23 | **P-01 com panfleto** (2 panfletos: vaga e "NIGHT SHIFT") | — | AST-036, AST-037 | |
| L01-24 | **Relógio do Bellmoor Savings** (ponteiros controláveis, mostrador emissivo) | Ø 6, centro a ~14 | AST-044 | ANM-003 |
| L01-25 | **Ponto seguro sob o letreiro**: marcação no chão (raio 6) | — | AST-028 + AST-067 | AST-028 desenha 10 × 6; o volume LZ-5 é raio 6 (AD-12) |
| L01-26 | Cones de BAR-N e BAR-S | — | AST-047 | a cerca do beco de AST-047 **sai**: a Juniper Sul agora tem trânsito (§9.5) |
| L01-27 | Caminhão de entrega parado | 20 × 8 | AST-048 | |
| L01-28 | Carros parados + van | — | AST-035 | |
| L01-29 | Cerca baixa do estacionamento (≤ 3) + vagas | — | AST-032 | |
| L01-30 | Mobília urbana: banco L3, hidrante, lixeira, mesas da praça | — | AST-034 | |
| L01-31 | B1 (3 andares, janelas noturnas emissivas, porta D1) | — | AST-033 | montagem do kit. `asset-list.md` mapeia para AST-045, que é o prédio de apartamentos **sobre o banco** (L01-38): ver AD-13 |
| L01-32 | Lavanderia B2 (vitrine, porta SP-B, versão fechada) | fachada 48 | AST-046 | |
| L01-33 | B3 / B4 / B5 fachadas simples, com vitrines "NO HELP WANTED" | — | AST-033 | |
| L01-34 | Fundo de cidade (skyline) | — | AST-033 (`BG_Card`) | |
| L01-35 | **Carros em movimento** (4 formas, motorista em silhueta, faróis só Neon) | 9–13 × 5–6,5 | AST-035 | família de 4 (DEC-087) |
| L01-36 | **Ambulância** (portas traseiras animadas, barra de luz Mustard/Teal) + **maca levada pelos médicos** | 18 × 7,5 × 8,5 | AST-052 | médicos descem na ida [DEC-114]; a ficha ainda descreve maca automática (`Q-127`) |
| L01-37 | **Long car** (ANM-008): preto, comprido demais, vidros embaçados, farol alto | ~22 × 6 | AST-065 | |
| L01-38 | **Bellmoor Savings + apartamentos** (térreo de banco até ~18; andares 2–3 com janelas WV-1..3 a 19–28) | lote 28 de largura, ~30 de altura | AST-044 + AST-045 | AST-044 diz fachada 24 × 18: o lote Z-11 tem 28 (AD-14) |
| ~~L01-39~~ | ~~Semáforos SIG-T, SIG-1, SIG-3~~ | — | ~~AST-077~~ **obsoleto** | **sai** (DEC-130 revoga DEC-120). Chave L01-39 e AST-077 não são reaproveitados; art-director marca AST-077 como obsoleto em `asset-list.md` |

### 12.3 Mart

| Chave | Asset | AST | Nota |
|---|---|---|---|
| L01-40 | Fachada com vidro (norte e leste), quina chanfrada, marquise com letreiro **"OPEN 24 HOURS"** sempre aceso | AST-028 | landmark e ponto seguro. Loja **36 × 32** (AST-028 diz 36 × 48: a planta de §7.4 cabe em 36 × 32, AD-12) |
| L01-41 | Gôndolas (2) + geladeiras baixas | AST-029, AST-030 | |
| L01-42 | Pacotes dos 9 produtos (exposição + Tool) | AST-011 | |
| L01-43 | Etiqueta "Out of stock" | AST-029 (decal), texto AST-072 | |
| L01-44 | Balcão do caixa | AST-031 | raio de fala da Opal 8 |
| L01-45 | **Bancada de upgrades** (parede oeste, 18 × 2 × 3,5 + painel 18 × 6, **6 posições** B1–B5 + S1) | AST-049 | AST-049 propõe 5 vagas em 16; FEAT-015 pede 6: painel cresce para 18 (módulos de 3, regra da própria ficha). Vitrine S1 mostra AST-051 |
| L01-46 | **Expositor de frutas/verduras** (cenário) | AST-050 | 8 × 3 × 3,5, sem prompt [DEC-109] |

### 12.4 Personagens (R6, DEC-089; fichas em `npcs.md` / `characters.md`)

| Chave | Asset | AST | Nota |
|---|---|---|---|
| L01-50 | Quick Quentin (CHR-004) + saco de moedas | AST-056 + AST-021 | silhueta que se lê a 110 studs |
| L01-51 | **Opal (CHR-003)**, pose de balcão + idle | AST-057 | **não** é âncora de anomalia |
| L01-52 | Tipos de cliente | AST-054, AST-055 | DEC-011 |
| L01-53 | **Walt Bramble (CHR-001)** com dois cafés | AST-058 | só na cutscene final [DEC-076] |
| L01-54 | **Médicos (2)** | ficha nova (AD-2; o style guide já cita AST-076) | descem na ida [DEC-114]; fora do teto de NPCs |

### 12.5 VFX, luz e áudio

Fumaça da grelha, vapor do café, VFX "pronto" (`Q-045`); poste piscando; zumbido de ~2 s do último poste no início do Walker (DEC-123); "tunk" do Hush; tique-taque do relógio do banco (audível no Pad); ambiente de rua de dia com motores e buzina leve; noite silenciosa; sininho da porta do Mart; sirene curta e suave da ambulância (desligada na saída da noite perdida, DEC-122); VFX/SFX cômico de atropelamento (DEC-095, AST-070, sem som realista de impacto); poças da Raincoat Lady.

## 13. Requisitos técnicos e orçamento de performance (mobile primeiro, DEC-014)

Proposta do level-designer, para art-director e architect confirmarem. Celular de referência adiado [DEC-090]; metas abaixo são de Rascunho.

| Item | Orçamento / requisito |
|---|---|
| Tamanho | jogável ~224 × 180 + 2 interiores; visual até X ±136, Z −152 (norte) e Z ~120 (Juniper Sul) |
| Streaming | tudo dentro dos limites sempre carregado (linhas de visão de ~135 studs, emenda do usuário ao ~110 do style guide, LD-15). Rotas e faixas `Persistent` (`tech/architecture.md` §8.1). Só o skyline descarrega (`Q-087`) |
| Triângulos na tela | alvo ≤ 100 mil numa vista típica do Pad; cena ≤ 250 mil |
| Heróis | carrinho ≤ 8 mil; trailer ≤ 12 mil; estação ≤ 1,5 mil; carro em movimento ≤ 1,5 mil; ambulância ≤ 2,5 mil |
| Props / prédios | prop ≤ 800; módulo de fachada ≤ 2 mil |
| Instâncias | ≤ 3.000 partes/meshes; tudo ancorado |
| Luzes locais | Orçamento de `art/style-guide.md` §5.1 (Aprovado, DEC-126). Dia: 0–2. Noite: **≤ 18 locais ativas (alvo 14)**, **≤ 3 com sombra** visíveis ao mesmo tempo. Distribuição no MAP-01: interior do trailer 1 `SpotLight` (sombra); Trailer Lights 1 `SpotLight` do mastro (sombra) + 2 `PointLight` fracas do cordão; Mart 1 `SurfaceLight` + 1 `PointLight` do letreiro (sombra opcional); **postes JL-01..JL-09 + P-01 = 10 `SpotLight`** para baixo, Range 16–20, sem sombra (o Hush apaga um por um); long car 0–2 `SpotLight` frios (só na ANM-008); ambulância 0–1 `PointLight` Range 10. Pior caso: 1 + 3 + 2 + 10 + 2 = **18** (ambulância e long car nunca juntos: a ambulância não é despachada com a ANM-008 ativa, FEAT-034). Com sombra: trailer, mastro e letreiro = **3**. Postes da Ninth entre o Pad e o Mart ficam **apagados** (rota escura, §10.1). Semáforos, faróis do trânsito e janelas: só Neon/emissivo, **0** luz real |
| Volumes de luz | LZ-1..LZ-5 separados da iluminação visual (§10.2) |
| Névoa à noite | fim ~200 studs: JL-09 (~135 da janela) bem dentro do alcance; a rua do fundo (Z −152..−136, ~190) some na névoa. Teste de leitura do Walker a 135 no celular: art-director (§15 P33) |
| NPCs | ≤ 12 simultâneos [DEC-045]; rotas como cadeias de waypoints nomeados; colisão NPC-NPC desligada |
| **Veículos** | teto próprio: ≤ 4 em movimento de dia, ≤ 1 à noite + ambulância + long car (FEAT-033). Movidos por CFrame em spline (sem física), ancorados. Servidor agenda, client simula. Sem semáforo [DEC-130]. Proposta (`Q-129`, FEAT-033 `Traffic.Crossing`): PARE de 1 s na Juniper com reserva da caixa do cruzamento; reserva de faixa para NPC faz os carros que chegam pararem na linha da faixa (máx. 4 s) (§9.5). Regra técnica com o architect (`tech/architecture.md` §8.1, `Q-102`) |
| Ragdoll R6 | por jogador, sem dano; paredes de limite seguram o corpo arremessado [DEC-095] |
| Colisão | jogador-jogador desligada no Pad e no trailer (`Q-086`); carro × personagem só pelo detector de atropelamento |
| Partículas | ≤ 4 emissores ativos |
| Prompts | ≤ ~35 no Pad/trailer; ativação 8–10 studs |
| Limites | paredes só para personagens em BAR-N (Z −76), BAR-S (Z 80), BAR-W/BAR-E (X ±112), fachadas; carros e NPCs passam |

## 14. Critérios de aceite do layout

- Porta do Mart → centro do carrinho entre 100 e 120 studs em linha reta; caminho a pé ≤ ~120 (DEC-049).
- O caminho Pad ↔ Mart e Pad ↔ ponto seguro cruza pista **uma só vez**, em CW-1, **sem semáforo** (DEC-130; rodada 17, `Q-128` B). Ida + volta + compra ≤ ~25 s em média de dia.
- **Nenhum semáforo** no mapa (DEC-130). Carros só param no PARE da Juniper e na linha de faixa com reserva de NPC ativa (proposta `Q-129`); nunca dentro de uma faixa nem dentro do cruzamento.
- Da porta do Mart e dos corredores olhando para leste, o carrinho e L1, L2, L3 ficam visíveis sem obstrução; nenhum carro **para** nessa linha.
- Da porta do Mart, o painel da bancada de upgrades (fim do corredor do meio) e o expositor de frutas ficam visíveis. Nenhum prompt de compra de upgrade existe no carrinho nem no trailer (DEC-101).
- Depois da noite perdida, todos aparecem de pé em REV-1..4; ninguém aparece no banco do fundo (DEC-122).
- O passo 10 do Walker é o mesmo ponto (28, 29) com e sem Trailer Lights, com o interruptor ligado ou desligado.
- À noite, ≤ 18 luzes locais ativas e ≤ 3 com sombra em qualquer momento (style guide §5.1).
- Do corredor do carrinho, o trailer à venda é visível nos dias 1–5.
- Espreitas fora do raio 14 e a 20–40 studs da gaveta.
- Carrinho e trailer com as estações na mesma ordem e a gaveta no mesmo X; Q1 é a mesma vaga [DEC-086].
- Quatro jogadores cabem no corredor do carrinho e do trailer sem travar.
- Nenhum spawn de cliente, de carro ou de anomalia é visível do Pad, da janela ou do Mart no momento do spawn.
- O ponto seguro fica **sob o letreiro "OPEN 24 HOURS"**, a ~100–120 studs da porta do trailer, alcançável em ≤ 8 s a 15 studs/s, iluminado, cabe 4 jogadores, nunca recebe anomalia.
- Em todo o trajeto porta do trailer → SS, o fim da Juniper fica ≥ 58° fora da direção de marcha (meia largura da tela ~57°) ou tapado pelo casco do trailer.
- Da janela do trailer, JL-09 e todos os postes JL ficam visíveis sem obstrução (nada estaciona no meio-fio vermelho).
- A ambulância nunca entra na Juniper; para em AMB-M ou AMB-P; o revivido aparece na calçada em REV, nunca na pista.
- Clientes e passantes só atravessam em faixa e com reserva; nenhum NPC é atropelado; nenhum carro freia por jogador (proposta `Q-129`).
- JL-01..JL-09 a 8 studs entre si; JL-09 a ~135 da janela; JL-08 e JL-09 além de BAR-N (LD-15).
- Com Trailer Lights ligado, Q1–Q5 ficam dentro da luz.
- Em celular, o jogador se orienta pelos landmarks: letreiro do Mart a oeste, banco com relógio ao norte, trailer/estacionamento a nordeste, Juniper com a fila de postes, poste do panfleto na esquina.

## 15. Pendências e perguntas

P1–P18 já viraram perguntas no `open-questions.md` (rodada 8). Situação atual:

| # | Tema | Situação |
|---|---|---|
| P1 | Onde o trailer funciona | **Fechada: DEC-086** (no Pad) |
| P2 | Carrinho depois da troca | aberta, `Q-082` (sugestão: lona na vaga AN-01) |
| P3 | Interior do trailer conta como luz | aberta, `Q-064` |
| P4 | Passantes de dia | aberta, `Q-083` |
| P5 | Onde se compram upgrades / níveis passam | onde: **Fechada: DEC-101** (bancada do fundo do Mart; DEC-106 oferta fixa + S1). Níveis passam do carrinho para o trailer: aberta, `Q-075` |
| P6 | Cutscene POV | **Fechada: DEC-088**. Ajuste de roteiro em `Q-106` |
| P7 | Documento do lobby | aberta, `Q-085` |
| P8 | Colisão jogador-jogador | aberta, `Q-086` |
| P9 | Streaming | aberta, `Q-087` |
| P10 | "Out of stock" | aberta, `Q-088` |
| P11 | 4 s do ladrão | aberta, `Q-089` |
| P12 | Custo de sanidade da rota | aberta, `Q-090`. Agora inclui a corrida para SS (~2–3) |
| P13 | Funcionário do Mart | **resolvida no mapa**: Opal (DEC-079, DEC-099) sem âncora de anomalia; AN-08 retirada, AN-12 nova. Falta `Q-091` (a), fora do teto |
| P14 | Trânsito | **Fechada: DEC-087** (andando), **DEC-095** (atropela), **DEC-103** (item cai, sem sanidade), **DEC-130** (sem semáforo; revoga DEC-120). Rotas e densidade em §9.5 para `Q-102`; regra de travessia para `Q-129` |
| P15 | Ponto seguro nunca recebe anomalia | aberta, `Q-092` |
| P16 | Esconder por jogador | fechada por DEC-176; **esconder saiu (DEC-221)** |
| P17 | Escala | `Q-095` pode fechar por **DEC-126**: style guide aprovado com R6, olho 4,5, bancada 3,5, igual a este mapa |
| P18 | Nomes | **resolvida no mapa** com os nomes de `world.md` (`Q-096`); faltam nome do mapa, lavanderia, B1, B4 (narrative-writer) |

Novas, para o secretário registrar (nenhuma bloqueante na minha leitura; P32 muda o layout e pede confirmação do usuário):

| # | Pergunta (dono) | Recomendação do level-designer |
|---|---|---|
| P19 | Postes da Juniper e P-01 contam como volume de luz para a sanidade? (game-designer, `Q-090`) | Não: só luz visual. FEAT-020 (Rascunho) propõe que sim. Se contarem, a rota do Mart fica mais barata (os postes da Ninth entre Pad e Mart seguem apagados) e o Hush passa a mexer na sanidade de quem está perto da esquina |
| P20 | Coleta com médicos andando até o corpo | **Fechada: DEC-114** (médicos descem e levam o corpo). Médicos ficam **fora** do teto de NPCs (FEAT-009, NPC-024). Distância: ver P35 |
| P21 | Carro × pedestre na faixa; NPC atropelado; ambulância atropela | **Fechada em parte**: DEC-130 (sem semáforo; jogador atravessa por conta e risco) e DEC-103 (item cai, sem sanidade). Carro para na faixa? NPC atravessa como? → `Q-129` (proposta em §9.5). Tempo no chão e ambulância seguem em `Q-122` |
| P22 | Densidade do trânsito por fase (level-designer + architect + game-designer, `Q-102`, `Q-103`) | Tabela de §9.5, com os tetos de FEAT-033 (4 de dia, 1 à noite). Proposta nova: à noite o carro só usa TR-1/TR-2 (Ninth reta) |
| P23 | Long car: dá ré na boca da entrada do estacionamento (AN-12) para o farol apontar para o trailer. "Estaciona no meio-fio em frente" (`anomalies.md`, Aprovado) fica atendido? (narrative-writer, `Q-103`) | Sim: é o meio-fio do outro lado da rua. Não muda sinal nem regra |
| P24 | Mart mudou de lugar (lado sul da Ninth, porta na quina NE). Perde o landmark "a rua termina no mercado"; ganha rota curta, com uma travessia sem semáforo (CW-1) e de costas para a Juniper Norte (informativo; art-director) | Manter. O letreiro emissivo na quina segue visível do Pad |
| P25 | Janelas do N6 ficam 10–17° acima do horizonte: no alto da tela, não fora dela. `world.md` sugere "acima da linha do olhar" (game-designer) | Aceitar: o verbo é tirar a janela da tela (olhar para baixo/para o lado). Para ficar literalmente fora da tela seriam ≥ 35°, ou seja, um prédio de ~45 studs, fora da escala da cidade |
| P26 | Escala R6 e bancada | **Resolvida**: `style-guide.md` aprovado (DEC-126) usa R6, olho 4,5, bancada 3,5, igual ao mapa. `Q-105` fechada por DEC-126; `Q-095` pode fechar (P17) |
| P27 | Medidas do carrinho e do trailer | **Resolvida**: AST-026 e AST-027 já usam a linha de 26 e o casco 28 × 12. Altura do trailer: o mapa adotou a de AST-027 (pé-direito 8,5, externa ~11) |
| P28 | `script.md` §1 tem plano aéreo (1), gesto da carteira (2) e "câmera gira" (8), que não funcionam em POV sem braços (DEC-088, DEC-097) (narrative-writer, `Q-106`) | Trocar o plano aéreo pelo começo na calçada (CS-1); carteira vira balão de fala; o giro vira todos olhando para o carrinho (CS-7) |
| P29 | Câmeras fixas SPEC-P/SPEC-M durante a coleta e na janela de 10 s (game-designer + frontend, `Q-107`) | Sim |
| P30 | Ambulância cruzando o cruzamento à noite pode puxar o olhar para a Juniper com o Walker ativo (game-designer, `Q-107`) | Aceitar o risco (cruza em < 1 s, sem parar); se o playtest mostrar perda de noite por isso, a ambulância entra pelo leste e para em AMB-P sem cruzar o cruzamento |
| P31 | Atrasado (DEC-098) e revivido: onde aparecem (architect + game-designer, `Q-112`) | Atrasado em PS (dia) ou PS-N (noite); revivido em REV-1..4; party da noite perdida também em REV-1..4 (DEC-122) |
| P32 | **Fechada pelo usuário na rodada 17** (`Q-128`, opção B; secretário registrando a DEC): Juniper Sul **aberta** a carros de dia, rota trailer ↔ Mart atravessa CW-1 **sem semáforo** (DEC-130). TR-7..TR-10, JS-IN/JS-OUT e SL-1N/SL-1S (agora só linhas de faixa) ficam; SIG-1 sai. À noite, nenhum carro na Juniper (proposta mantida; FEAT-033 já adota). Texto histórico abaixo. — Original: **Juniper Sul aberta ao trânsito para cumprir DEC-120** (usuário confirma; **architect** anota). DEC-120 pede semáforo "na travessia trailer ↔ Mart". Na revisão 2 essa travessia (CW-1) cruzava um beco **sem** carros, e o architect pôs o semáforo em CW-1 (`tech/architecture.md` §8.1). Opções: (a) semáforo em CW-1 sem carros (enfeite, ensina regra falsa); (b) levar a rota para a boca do cruzamento (obriga a andar para o norte, de frente para a Juniper Norte: quebra N7 × N10); (c) **abrir a Juniper Sul ao trânsito de dia e manter CW-1 no meio da quadra, com semáforo** | **(c)**. Para o architect: **CW-1 está certo** como local do semáforo da travessia trailer ↔ Mart; o que mudou é o mapa (Juniper Sul com trânsito, rotas TR-7..TR-10, linhas SL-1N/SL-1S, SL-S, JS-IN/JS-OUT). O cruzamento ganha SIG-T no lugar do PARE; CW-3 ganha SIG-3. Proposta junto: à noite, nenhum carro na Juniper (Norte e Sul): a corrida para o Mart/SS não depende do semáforo e nenhum farol puxa o olhar para o Walker. Custo: a ida ao Mart de dia sobe ~3 s (espera do verde); a cerca do beco (AST-047) sai; o ladrão chega pela calçada leste da Juniper Sul |
| P33 | **Fechada pelo usuário (LD-15)**: postes a **8 studs**, JL-09 em Z −88 a **~135** da janela; emenda o "~110" de `art/style-guide.md` §5 (o art-director anota a emenda; o style guide é Aprovado e só muda com o registro do secretário). Passo 10 do Walker mantido em (28, 29). BAR-N recuou para Z −76 para JL-08/JL-09 seguirem fora do alcance. Pendente: teste de leitura do Walker a 135 no celular (art-director). — Original: JL-09 (início do Walker) a **~165** studs da janela; `art/style-guide.md` (Aprovado) pede o fim da Juniper legível a até **~110** (art-director + usuário) | Manter 165 (superado): com 9 postes a 12 studs e a linha de visão passando a oeste do banco, JL-09 a 110 deixaria os postes a ~4,5 studs um do outro. Pedido ao art-director: teste de leitura no celular do Walker (1,35×) sob o `SpotLight` de JL-09 a 165 e anotação no style guide; se reprovar, alternativa do mapa: aproximar a cadeia com postes a 8 studs (JL-09 em Z −88, a ~135; JL-06 a ~114) e aceitar que os passos 0–3 ficam além de ~110 |
| P34 | Bancada de upgrades: parede **oeste** como "parede do fundo"; **6 posições** (B1–B5 + S1, FEAT-015) contra 5 vagas em 16 studs (AST-049); título legível a ~40 da porta (AST-049 diz ~25) (art-director + game-designer) | Parede oeste (fecha o corredor do meio, landmark da porta e linha de visão para o carrinho). Painel de 18 com 6 módulos de 3, regra da própria AST-049 |
| P35 | Médicos até o corpo dentro do trailer (até ~75 studs) e velocidade da ambulância | **Fechada** no game-designer: FEAT-034 `MedicReach` 80, `MedicSpeed` 20 (coleta ≤ 10,5 s); ambulância 24 studs/s na Ninth, 12 nos últimos 20 (chega a AMB-P em ~8 s). |
| P36 | Medidas cruzadas com fichas de arte (art-director): Mart **36 × 32** (AST-028 diz 36 × 48); marcação do SS 10 × 6 (AST-028) contra volume raio 6; Bellmoor Savings: lote 28 (AST-044 diz 24) com térreo ~18 e apartamentos (AST-045) a 19–28; AST-040 ainda cita o banco como lugar de acordar | Mart fica 36 × 32 (a planta de §7.4 cabe com 14 studs livres na frente da bancada). SS: marcação 12 × 12 ou círculo raio 6. Banco: 28 de largura. AST-040: só cenário (DEC-122) |
| P37 | **`Q-129`**: sem semáforo, carro para na faixa? faixas ficam pintadas? como NPC atravessa? (game-designer + level-designer) | Proposta em §9.5, alinhada com FEAT-033 `Traffic.Crossing` (Rascunho): Ninth preferencial; **PARE de 1 s** nas bocas da Juniper (placas PARE-N, PARE-S); faixas **pintadas**, sem proteger o jogador; carro **nunca** para por jogador; NPC atravessa só em faixa com **reserva**, e com reserva os carros param na linha da faixa (SL-W/SL-E juntas para CW-2/CW-4; SL-1N/SL-1S; SL-3W/SL-3E). **Provisório** |
| P38 | Pedidos ao art-director pelo ajuste final | (1) AST-077 (semáforo) **obsoleto**, L01-39 sai; (2) AST-032 (kit de rua) ganha **placa PARE** (×2), linha de PARE em SL-N/SL-S e linhas de faixa (§5.4); faixas pintadas conforme `Q-129`; (3) style guide §5: anotar a emenda ~110 → **~135** (LD-15), com teste de leitura do Walker no celular sob o `SpotLight` de JL-09 |
| P39 | Novo limite **BAR-N em Z −76** (antes −100): a Juniper Norte jogável fica com 44 studs de comprimento (Z −76..−32). SP-A (30, −104) e AS-3 (−30, −104) seguem atrás do limite; cones de AST-047 mudam de lugar (informativo; architect e art-director) | Manter. Alternativa: BAR-N em Z −84 deixa só JL-09 fora do alcance, mas o jogador chega a 4 studs do Walker no passo 1 |
| P40 | Como o `VehicleController` acha a placa `SIGN-T` (architect; TASK-058). §19.22 cita a placa, mas nenhuma tag nem ponto | **Provisório (TASK-083):** `SIGN-T` vira `MapPoint` (78, −40), virado para o sul; o client desenha o texto ali. Se a placa precisar sumir ao comprar, falta uma tag no modelo (sugestão `SaleSign`): pedido ao architect para o `Required.Wave2` |
| P41 | Estado autorado da lona (`VehicleCover`): visível ou escondida no place? (architect; TASK-056) | **Escondida** (Transparency 1, sem colisão) com `OrigTransparency`/`OrigCanCollide`/`OrigCanQuery` = valores visíveis, mesmos nomes do `place_assets.hide`. Assim o código da onda 1 nunca mostra a lona sobre o carrinho e o `VehicleService` só restaura os `Orig*`. Provisório |
| P42 | `LightZone` do trailer (LZ-1..3) no veículo ou no mapa? (architect; TASK-059) | **No mapa** (`MapBinding/LightZones`), na pose do Pad: a zona só vale com o trailer como veículo atual (condição do grupo), então não precisa andar com ele e o cache do `IsLit` não depende de `Swapped`. Provisório |
| P43 | `SPEC-P`/`SPEC-M` são câmeras a 20 / 14 de altura, mas `MapPoint` exige frente horizontal (architect + frontend; TASK-064) | Ponto com frente horizontal para o alvo (SPEC-P → (44, 30); SPEC-M → AMB-M); o `CameraController` inclina para baixo (sugestão −30°). Provisório |
| P44 | Quantas lixeiras de rua são interativas (`Q-166` b; game-designer) | **As 3** AST-034 do mapa ((−46, 17.5), (66, 17.5), (−30, −17.5)), tag `StreetBin` (T60). Até a TASK-057, o prompt "Throw Away" aparece nelas e o servidor recusa. Provisório |
| P45 | Luz dos postes JL-01..09 e P-01 (TASK-060) | O `SpotLight` do blockout de cada poste foi **copiado** para `LampHead/Light_Lamp` (para baixo, sem sombra) e o do blockout desligado (`DisabledByBind`), para o `StreetLight` conter a própria luz sem dobrar o orçamento (§13). `Place.restore` não religa o do blockout. Troca pela luz do AST-083 quando a ficha for aprovada (TASK-092) |

Binding da onda 3 (TASK-098), para o secretário registrar (nenhuma bloqueia o código; todas **Provisório**):

| # | Pergunta (dono) | Recomendação do level-designer |
|---|---|---|
| P46 | Cutscene de abertura: `MoveTo` é reta. CS-4 (−18, 22) → CS-5 (0, 38) e CS-5 → CS-P{slot} cortam a pista da Juniper Sul **fora** das listras de CW-1; e o `MoveTo CS-4` (At 11) leva a party para dentro de CW-2 enquanto o `ToyCarNinth` passa (At 13), o contrário do beat "para no meio-fio, o carro passa, atravessa" (narrative-writer + architect, `Content.Cutscenes`) | **Resolvida** (architect, 2026-10-10, Provisório): `Content.Cutscenes` intro agora espera o carro em CS-3 (`ToyCarNinth` At 13), atravessa CW-2 depois (`MoveTo CS-4` At 15), desce a calçada oeste até `CS-5W` (At 18,5), cruza CW-1 até `CS-5E` (At 20,5) e vai a `CS-P{slot}` (At 22,5); `LookAt`/`Prompt`/`FlipPhone` em 23,5/24,5/25,5. `CS-5` sai da cadeia (o ponto fica no place). O aviso do `check_map01` deve sumir na próxima rodada |
| P47 | **Obsoleta (DEC-221: esconderijo saiu)**. Onde o `HideService` põe o jogador escondido (§19.14 diz `PivotTo` na vaga, sem dizer o ponto) (architect) | `Hide_Pose` (Attachment sem tag) dentro de cada armário `H<n>`: chão do corredor, 1 stud à frente da porta, virado para a janela; o serviço soma a altura do HRP agachado. O `Prompt_Hide` fica baixo na porta (≥ 2,6 dos prompts da bancada) |
| P48 | Formato dos nós de rota de trânsito (a TASK-097 só diz "Folder/Model dos nós ordenados") (architect, TASK-104) | `Folder` `TR-n` com `Part` `01..nn`, atributo `Index`, frente para o próximo nó; linha `SL-*` = `Part` com `LookVector` no sentido de quem para; velocidade de cruzamento por `X-T` (§9.5) |
| P49 | AST-045 novo (com `Window_Up_1..3`) ainda não reenviado (modeler-3d) | Até o reenvio, `WV-1..3` são `Part` invisíveis em `MapBinding/Anomaly` na posição das janelas; o efeito da ANM-006 precisa do modelo novo (cortina, `_Lit`, `Att_Waver_N`) |
| P50 | Passantes à noite (DEC-183: 1–2) × "NPC fora da rota é sinal" (§9.1); pop-in do laço (game-designer + architect, `Q-162`) | À noite só os caminhos do oeste (CW-2), longe das rotas de cliente e da Juniper Norte. O laço `ninth_east_loop` nasce à vista: `PedestrianService` com fade de entrada ou só de dia (já é `Day`) |
| P51 | Peça que fecha a janela (DEC-221): a malha `Awning` do AST-027 serve? (level-designer + art-director) | Usar a `Awning` se for `MeshPart` separada no `TRL` e, girada na dobradiça de cima, cobrir a janela (22,5 × 4,5). Senão, `Shutter_Panel` placeholder (Part 22,5 × 4,6 × 0,2, Aluminum) com a mesma dobradiça e a `Awning` fixa; o art-director desenha a aba de verdade depois. Botão `TRL-SHUTTER` placeholder até ficha de arte |

Spawn/despawn, postes e ajustes do place (2026-10-10), para o secretário registrar (todas **Provisório**):

| # | Pergunta (dono) | Recomendação do level-designer |
|---|---|---|
| P52 | 5 postes: qual é a cadeia do Walker? (usuário + game-designer) | Feito: 5 postes JL (passos 0–4) + WALKER-10 (passo 5); P-01 só no Hush. Alternativa: 4 JL + P-01 como passo 4 (o último salto não cruza o cruzamento inteiro, ~26 studs como antes) |
| P53 | JL-04 (passo 1) fica 4 studs dentro de BAR-N (Z −76): o jogador pode chegar perto do Walker no passo 1 (antes 0–1 ficavam fora) (usuário + game-designer) | Recuar BAR-N para **Z −64** (entre JL-03 e JL-04; mover cones/cercas AST-047 e a parede do blockout). Não aplicado: mexe no limite jogável |
| P54 | Bloqueio: `Required.luau` ainda exige JL-06..09; `ANM-007` server/client com 10 passos (backend-coder + frontend-coder) | Ajustar os arquivos listados em §5.6 **antes** do próximo Play (senão `MapIndex.Validate` erra no Studio) |
| P55 | Porta do banco (DR-APT) como porta de moradores à noite; o AST-045 "não tem porta de cliente" (art-director) | Usar a porta do pórtico do AST-044 (ou uma porta lateral de moradores, se o art-director desenhar); o bind mede uma peça "Door" do AST-044 se existir |
| P56 | SP-A e SP-B ficam com peso 0 para clientes (> 10 s) (game-designer) | Manter; se quiser variedade, SP-B só de dia com peso ≤ 15 (11,6 s a 13 st/s) |
| P57 | Porta do Mart: o AST-028 não tem folha separada? (art-director + frontend) | O bind cria `Door_Leaf` (vidro 4 × 7,5 × 0,2) com `AutoDoor`; a porta pintada na malha continua até o art-director separar a folha. `DoorHinge` "Right" = dobradiça na borda +RightVector da folha (conferir com o `DoorController`) |
| P58 | Balcão (`Counter_L1..L3`) sem modelo próprio (usuário) | Peças existem mas **sem visual** em todos os níveis (`NoVisual`); o upgrade funciona. Volta a aparecer tirando `counter` de `GHOST_UPGRADES` no `bind_pieces.luau` quando o modelo existir |
| P59 | Aba da janela com `ClosedAngle 0` (usuário) | Causa: a `Awning` é `MeshPart` alinhada aos eixos; o lado maior da caixa era a altura e a aba "parecia" pendurada. O bind agora usa a diagonal da caixa + perfil por raycast e pendura a aba 3° para fora; ângulo < 5° ou aba curta demais (não chega ao peitoril) → `Shutter_Panel` |

Fora deste documento, mas dependem dele: fichas técnicas `ANM-###` (escolher âncoras de §10.3), `design/npcs.md`, `art/asset-list.md` (converter L01-## sem AST em fichas), blockout no Blender (quando pedido, combinado com o modeler-3d).

## 16. Binding no place (TASK-005 onda 1, TASK-083 onda 2, TASK-098 onda 3)

Contrato: `tech/architecture.md` §18 e §19.22. Ferramentas (modo de edição, fora do Rojo): `tools/assetplace/bind_map01.luau` (aplica) e `check_map01.luau` (confere; espelho de `MapIndex/Required.luau`). Tudo **Provisório** (DEC-193).

### 16.0 Edições à mão no Studio gravadas nos placements (2026-10-10)

O usuário ajustou o place à mão; `MAP-01_placements.luau` agora reproduz o estado (campos novos `drop`, `parts`, `copies`, `pivot`, aplicados por `place_assets.luau`):
trailer sem a extensão de entrega (`DeliveryStand` do AST-020), registradora (`TRL-DRAWER`) e mesa de coberturas (`TRL-K`) viradas para o operador (rotY 180) com pivô da registradora movido, tábua `TRL-T` virada (rotY 0) e maior (2,6 × 1,4), bancos `TRL-BENCH-1..3` girados 180 em grupo (pivôs no lugar), duas camadas extras de pão em `TRL-B`, malha dos armários `H1..H4` removida (modelos vazios ficam).
Carrinho: `Body` com 3,0 de altura (topo em 3,45); `DRAWER` sem extensão e virado para o operador; `CART-K` espelhado do trailer (rotY 180, z 37,352). Conferência sem rodar `Place.run`: `Place.diff(placements, ids)` (só leitura) — resultado 0 diferenças.
**DEC-221 / TASK-132 (2026-10-10, ferramentas prontas, place ainda não rodado):** as 4 entradas `H1..H4` saíram de `MAP-01_placements.luau`; o `Bind.run` destrói os modelos vazios `H1..H4` que ainda estão no place (e qualquer `Prompt_Hide`/`Hide_Pose` que sobrou) e não recria mais nada de esconderijo. Depois do `Bind.run`, `Place.diff` volta a 0 diferenças. Provisório.

### 16.1 Como rodar (Command Bar, repositório servido na porta 8772)

As ferramentas carregam `map_frame.luau` (§16.9) do mesmo servidor na hora do `require` (o loader abaixo deixa o `HttpEnabled` ligado durante os `get`). Não precisa mudar nada no comando.

Ordem: `Place.run` (se os assets mudaram) → `Bind.run()` → `Pieces.run()` (`bind_pieces.luau`, TASK-085) → `Check.run({ wave = 3 })` → salvar o place. Depois de qualquer `Place.run`, rodar o `Bind` de novo; depois de qualquer `Bind`, o `Pieces`. Depois do `Bind`, **não** usar `Place.showLayer`: os dois veículos ficam no `Workspace` (T36). O `check` da onda 3 lê `Content` (`Cutscenes`, `WalkPaths`, `Traffic`) do `ReplicatedStorage`: rode com o `rojo serve` sincronizado.

```lua
local H=game:GetService("HttpService") local w=H.HttpEnabled H.HttpEnabled=true local function get(p) local ms=Instance.new("ModuleScript") ms.Source=H:GetAsync("http://127.0.0.1:8772/tools/assetplace/"..p,true) return require(ms) end local Bind=get("bind_map01.luau") local Pieces=get("bind_pieces.luau") local Check=get("check_map01.luau") H.HttpEnabled=w print(Bind.run()) print(Pieces.run()) Check.run({ wave = 3 })
```

### 16.2 O que a onda 2 põe no place

| Peça | Onde | Tag / atributos |
|---|---|---|
| Trailer | AST-027 do Pad (`TRL`) + todo `TRL-*` dentro dele (H1..H4 saem, DEC-221); estacionado em `TRL-SALE` no fim do bind (a casca vazia `TRL-SALE` sai) | `Vehicle = "trailer"`; estações como o carrinho, `rail` com 8 vagas (`Rail_8`), `board` com 3 (`Att_Bun1..3`), `coffee_machine` (`Ingredient = coffee`; `Prompt_Brew` → `brew_coffee`, `Prompt_Restock` → `restock`); `Zone_Center`; gaveta `TRL-DRAWER` com `Value_Anchor` |
| Telefone | `CART-PHONE` (no poste do guarda-sol) e `TRL-PHONE` (parede da frente) | `Prompt_Answer` → `answer_phone`; a âncora sobe até ficar ≥ 2,6 de qualquer prompt de outra estação |
| Compra | `Prompt_Buy` na casca do trailer, fora da janela (anda com ele; em `TRL-SALE` fica virado para o Pad) | `buy_trailer` |
| Interruptor | `TRL-SWITCH`, parede sul (46, 46) | `Prompt_Switch` → `switch_light` |
| Janela (onda 3, DEC-221) | botão `TRL-SHUTTER` (43.4, 46.5) ao lado do interruptor; aba `Awning` do AST-027 | `Prompt_Shutter` → `shutter_toggle`; `Shutter_Hinge` (`Attachment`, atributo `ClosedAngle`) na `Awning` (ou no `Shutter_Panel`, P51); atributo `Shutter` é do `VehicleService` (não autorar). Detalhe do binding: §16.7 |
| Lona | `Model` `VehicleCover` dentro do carrinho (caixa cinza do tamanho da bancada, AST-043 pendente) | tag `VehicleCover`; escondida, `Orig*` com os valores visíveis (P41) |
| Luz (volumes) | `MapBinding/LightZones`: LZ-1 (X 27..53, Z 36..46, piso +2 até o teto), LZ-2 (X 44..56, Z 30..35), LZ-3 (bola r 18 em (40, 41)), LZ-4 (Mart), LZ-5 (bola r 6 no SS) | tag `LightZone`, `ZoneId`, `Group` (`trailer_interior`, `trailer_lights`, `mart`); nenhum volume na rota Pad ↔ Mart (DEC-196) |
| Postes | um `Model` por poste (haste + cabeça) JL-01..09, P-01 | tag `StreetLight`, `PostId`, `Group = juniper_posts`, `Order` 1..10 (JL-09 = 1 … JL-01 = 9, P-01 = 10 = ordem do Hush; passo do Walker = `Order − 1`) |
| Lixeiras de rua | as 3 AST-034 (P44) | tag `StreetBin`; `Prompt_Discard` → `discard` (T60) |
| Pontos | §5.1, §5.3, §5.5 | `PS-N1..4`, `REV-1..4`, `TRL`, `TRL-SALE`, `CART`, `SPEC-P`, `SPEC-M`, `DROP-T`, `L1..L3`, `ST-R`, `SIGN-T` |
| Grafo | §9.1 | ROUTE-THIEF (33 nós) |

### 16.3 Decisões de binding (Provisório)

- **Pose do veículo = pivô do modelo** (o `PivotTo` do T36 usa o ponto como está). `CART` (41, 37.5), `TRL` (40, 41) norte, `TRL-SALE` (78, −58) sul. As mesmas constantes estão em `MAP-01_placements.luau`: mudar nos dois.
- **Trailer no place = começo de run**: estacionado em `TRL-SALE` com o interior completo; o carrinho fica no Pad. O bind amarra as âncoras com o trailer no Pad (coordenadas deste documento) e só no fim o estaciona.
- **Fallback das âncoras do trailer** = o do carrinho + diferença de pivô da mesma estação (mesmo asset, mesma ordem, DEC-086).
- **`SIGN-T` é ponto** (P40); **lona escondida** (P41); **zonas de luz no mapa** (P42); **câmeras SPEC com frente horizontal** (P43).

### 16.4 Lista que o `check_map01` cobra na onda 2 (para o `Required.Wave2` da TASK-048)

| Item | Valor |
|---|---|
| Tags | onda 1 + `LightZone`, `StreetLight`, `VehicleCover` (`StreetBin` só avisa; `UpgradePiece` fica com a TASK-085) |
| Pontos | onda 1 + `PS-N1..4`, `REV-1..4`, `TRL`, `TRL-SALE`, `CART`, `SPEC-P`, `SPEC-M`, `DROP-T`, `L1`, `L2`, `L3`, `ST-R` (+ `SIGN-T`, P40) |
| Nós | onda 1 + `ST-R`, `L1`, `L2`, `L3`; rotas do ladrão com `AvoidQueue` e `AvoidCrossings` existem (ST-R → L1/L2/L3, L1/L3 → ST-R, L2 → EX-E) |
| Veículos | 1 `cart` (7 estações da onda 1) e 1 `trailer` (as 7 + `coffee_machine`); vagas de `rail`/`board` por `Vehicles[v].RailSlots`/`BoardSlots` (6/2 e 8/3) |
| Âncoras do veículo (dono sem `Station`) | carrinho: `answer_phone` = 1; trailer: `answer_phone` = 1, `switch_light` = 1, `buy_trailer` = 1 |
| Distâncias | dentro de cada veículo, âncoras de donos diferentes ≥ 2,5; complementos ≥ 2,0 |
| Luz | LZ-1..5 únicos com o `Group` da tabela acima; JL-01..09 + P-01 únicos com `Order` do Hush |
| Lona | exatamente 1 `VehicleCover` |
| Bancada | pivôs do carrinho a y 3,45; do trailer a pivô + 5,5 |

### 16.5 O que a onda 3 põe no place (TASK-098)

| Peça | Onde | Tag / atributos |
|---|---|---|
| ~~Esconderijos~~ → Janela (DEC-221) | botão `TRL-SHUTTER` ao lado de `TRL-SWITCH`; aba `Awning` do AST-027 (§7.2) | `Prompt_Shutter`: `Interactable`, `PromptAction = "shutter_toggle"`; `Shutter_Hinge` (`Attachment`) na peça que gira. `H1..H4`, `Prompt_Hide`, `Hide_Pose` saem |
| Janelas N6 | `Window_Up_1..3` do AST-045 (`Z-11`); fallback `MapBinding/Anomaly/WV-n` (P49) | `AnomalyAnchor`, `AnchorId` WV-1..3 |
| Pontos | §5.2, §5.4, §5.6, §10.3, §11 | `SS`, `AN-04/05/11/12`, `AS-1..4`, `WALKER-10`, `W/E/JN/JS-IN/OUT`, `CutsceneMark1..4`, `CS-1..5`, `CS-5W`, `CS-5E`, `CS-P1..4`, `SS-1..4`, `MKT-DOOR`, `WALT-1`, `RL-1`, `RL-END` |
| Calçadas | §9.3 | 17 `NpcNode` novos; `Crosswalk` CW-1, CW-2, CW-3 (pares de meio-fio); `Content.WalkPaths` com 7 caminhos |
| Trânsito | `MapBinding/Traffic/{Paths,Lines,Boxes}` (§9.5) | `TrafficPath`/`PathId` TR-1..10 (nós `Index`), `TrafficLine`/`LineId` SL-N/S/W/E/1N/1S/3W/3E, `TrafficBox`/`BoxId` X-T, CW-1..4 |

### 16.6 Lista que o `check_map01` cobra na onda 3 (espelho do `Required.Wave3` da TASK-097)

| Item | Valor |
|---|---|
| Tags | onda 2 + `AnomalyAnchor`, `TrafficPath`, `TrafficLine`, `TrafficBox` |
| Pontos | onda 2 + `SS`, `AN-04/05/11/12`, `AS-1..4`, `WALKER-10`, entradas/saídas, pontos de cutscene **derivados de `Content.Cutscenes`** (`Marks`, `MoveTo` com `{slot}` 1..4, `LookAt` fora de poste) + `MKT-DOOR`, `WALT-1`, `RL-1`, `RL-END` |
| Nós | onda 2 + todos os de `Content.WalkPaths`; regra 10: nós ligados na ordem, laço fecha, nenhuma vaga Q; caminho `Night`/`Any` em nó de rota de cliente só avisa |
| Trailer | `shutter_toggle` = 1 âncora (`Prompt_Shutter`) dentro do trailer, ≥ 2,5 das âncoras de outros donos (erro). Avisos: `Prompt_Shutter` fora do modelo `TRL-SHUTTER`, a mais de 4 do `Prompt_Switch` ou com desnível > 1; `Shutter_Hinge` ausente, duplicado, fora de `BasePart` ou sem `ClosedAngle`; sobra de `H1..H4`/`Prompt_Hide`/`Hide_Pose`. Âncora com `hide`/`get_up` = erro. `hide`/`Slot` saem (DEC-221) |
| Ids tagueados | WV-1..3; TR-1..10; as 8 `SL-*`; X-T e CW-1..4 (lidos de `Content.Traffic` quando sincronizado) |
| Trânsito (regra 11) | nós `Index` 1..n sem buraco; 1º nó no ponto de entrada da rota, último num `*-OUT` (aviso); cruza as linhas das `Stops` na ordem; 1ª linha de faixa ≥ `SpawnMinDist` (55); passa pela caixa do conflito; linhas e caixas invisíveis sem colisão |
| Cutscene | trecho `MoveTo` da intro fora das listras só avisa (P46) |

### 16.7 Janela de serviço no binding (TASK-132, DEC-221) — Provisório

Tudo amarrado com o trailer no Pad (coordenadas deste documento) e estacionado em `TRL-SALE` no fim, como o resto do interior.

| Peça | O que o `Bind.run` faz |
|---|---|
| Botão `TRL-SHUTTER` | `Model` criado pelo bind (`MapId = "TRL-SHUTTER"`, `BindCreated`, `Persistent`) dentro do trailer, com a placa `Button` (0,5 × 0,7 × 0,15, Mustard `#F6C12B`, sem colisão) em X 43,4, encostada na mesma face de parede e na mesma altura da placa do `TRL-SWITCH` (sem interruptor: ponto fixo no referencial do Pad). `Prompt_Shutter` = `Attachment` 0,3 à frente da placa (lado do corredor), `Interactable`, `PromptAction = "shutter_toggle"`. Se ficar < 2,6 de âncora de outro dono, a placa anda para oeste (até 1,0) e depois sobe (até 1,0). Por construção fica a 2,6 do `Prompt_Switch`. Reexecução mantém a placa onde está (ajuste à mão sobrevive), salvo `resetCreated` |
| Aba | O bind **mede** a `MeshPart` `Awning` do casco no referencial do Pad: largura ao longo de X, borda do lado da parede = dobradiça, comprimento inclinado. Usa a `Awning` se ela cobrir a janela X 30,25..52,75 e, pendurada da dobradiça, for do topo (piso + 8) ao peitoril (piso + 3,5), com folga 0,3 e dobradiça a ≤ 1,5 da face da parede. Senão cria `Shutter_Panel` (Part 22,5 × 4,6 × 0,2, Metal cor Aluminum, sem colisão nem query) com dobradiça no topo da janela por fora da parede, **autorada aberta** (horizontal, para fora, debaixo do toldo) e a `Awning` fica fixa (P51). O relatório do bind diz qual caminho tomou e as medidas |
| `Shutter_Hinge` | `Attachment` na peça que gira, eixo X = dobradiça (ao longo da janela), pose autorada = **aberta**. Atributo `ClosedAngle` (graus em volta do X do hinge, aberta → fechada; `Shutter_Panel` = −90). Para o `VehicleController` (TASK-131): guardar `H = Shutter_Hinge.WorldCFrame` e `open = peça.CFrame` ao achar o veículo; fechada = `H * CFrame.Angles(math.rad(ClosedAngle), 0, 0) * H:Inverse() * open`. Um `Shutter_Hinge` feito à mão (sem `BindCreated`) não é tocado |
| Esconderijos | modelos `H1..H4` (AST-041) destruídos onde estiverem; `Prompt_Hide`/`Hide_Pose` que sobraram, idem. Os encaixes `Hide_1..4` do próprio `.fbx` do AST-027 ficam, sem tag |

Proposta para o frontend-coder (TASK-131) e o architect: o atributo `ClosedAngle` no `Shutter_Hinge` deixa o ângulo no place e não no código (a aba real do art-director pode ter outro). Provisório.

**Correção 2026-10-10 (P59):** a medida da aba usava o lado maior da caixa da `MeshPart` como comprimento; numa aba inclinada a caixa é mais alta que funda, então a aba "já estava pendurada" e saía `ClosedAngle 0`. Agora a inclinação é a **diagonal da caixa** no plano YZ do Pad (dobradiça = aresta do lado da parede; o sentido da diagonal vem de um raycast no topo da malha: mais alta na parede = toldo descendo para fora) e a aba fechada fica **pendurada 3° para fora**. Ângulo < 5° ou aba que não chega ao peitoril → `Shutter_Panel`. O relatório mostra caixa, perfil e o caminho escolhido.

### 16.8 Spawn/despawn, postes, portas, peças sem visual e ajudantes travados (2026-10-10) — Provisório

| Item | O que muda | Onde |
|---|---|---|
| Spawn/despawn (§9.8) | pontos novos DR-APT, SP-S, SP-B, DR-B3, nó N-Z06-10; SP-A, EX-E, ST-R movidos; MKT-DOOR vira nó; atributos `Spawn`/`Despawn`/`SpawnKind`/`Door`. Arestas novas: DR-APT–N-Z06-10–(N-Z06-01, N-Z06-03), SP-S–N-Z08-01, N-Z02-10–N-Z02-06, SP-B–N-Z06-07, DR-B3–N-Z06-08, MKT-DOOR–N-Z12-02; SP-A liga direto em N-Z13-02. Grafo: **56 nós** (teto 80) | `bind_map01.luau` W6; `Content.Flow.Spawns`, `Content.WalkPaths`; `NpcService:PickSpawnPoint` e `CustomerService:ExitRoute` leem `Flow.Spawns` (ponto sem nó no binding é pulado) |
| Postes (§5.6) | 5 postes JL-01..05 a cada 16 (Z −24..−88); `Order` JL-05 = 1 … JL-01 = 5, P-01 = 6; luzes do blockout de JL-06..09 desligadas (`DisabledByBind`); Hush 6 × 2,5 s | `MAP-01_placements.luau` (pede `Place.run`), `bind_map01.luau`, `Content.LightGroups`; código pendente em §5.6 (P54) |
| Portas `AutoDoor` (contrato do `DoorController`) | folha(s) de MKT-DOOR (placeholder `Door_Leaf` vidro 4 × 7,5 × 0,2 se a malha não tiver folha), D1 (`Door_D1`, dobradiça `Hinge_D1`) e SP-B: tag `AutoDoor`, `DoorId`, `DoorLeaf`, `DoorHinge` (Left/Right), `DoorAngle` (sinal = abre para dentro), `DoorRadius` 8, `CanCollide` falso no servidor (NPCs passam; só o client anima) + `Attachment` `Door_Hinge` informativo | `bind_map01.luau` W8 |
| Balcão sem visual | `Counter_L1..L3` continuam `UpgradePiece` (o upgrade funciona), mas escondidos em todos os níveis: os `UpgOrig*` guardados são os escondidos, então o `UpgradeService` "mostra" invisível. Atributo `NoVisual`; o check informa em vez de avisar | `bind_pieces.luau` `GHOST_UPGRADES`, `check_map01` regra 9 |
| Ajudantes travados | tudo de `MapBinding`, peças invisíveis dos assets (âncoras, porta-luz, lona) e do blockout (`Markers`, `Limits`, peças escondidas e fantasmas ≥ 75% transparentes) com `Locked = true` e `CanTouch` falso; `CanQuery` falso só onde não colide (os limites BAR-* mantêm colisão). Nenhum código lê essas peças por raycast/toque | `bind_map01.luau` W7 |
| Check | regra 12 (rotas de spawn ≤ 130 studs, saídas) e 13 (linha de visão + `AutoDoor`) | `check_map01.luau` |

**Command Bar** (a mudança dos postes pede `Place.run`, que refaz `MAP01_Assets` a partir dos placements — as edições do §16.0 estão gravadas neles; confira antes com `Place.diff`; feito em 2026-10-10, §16.9):

```lua
local H=game:GetService("HttpService") local w=H.HttpEnabled H.HttpEnabled=true local B="http://127.0.0.1:8772/" local function get(p) local ms=Instance.new("ModuleScript") ms.Source=H:GetAsync(B.."tools/assetplace/"..p,true) return require(ms) end local Place=get("place_assets.luau") local P=get("MAP-01_placements.luau") local ids=H:JSONDecode(H:GetAsync(B.."Assets/import/_asset_ids.json",true)) local Bind=get("bind_map01.luau") local Pieces=get("bind_pieces.luau") local Check=get("check_map01.luau") H.HttpEnabled=w print(Place.run(P, ids)) print(Bind.run()) print(Pieces.run()) Check.run({ wave = 3 })
```

### 16.9 Referencial girado e ruas AST-032 completas (2026-10-10) — Provisório

**Referencial.** O usuário girou o place 180° em Y (MAP01_Blockout, MAP01_Assets, MapBinding, SpawnLocation) e quer essa orientação. Medido em 73 placements (pivô vivo + placement): `K = 67,887287` (dispersão < 1e-5), centro `(0, 33,9436)`. O pipeline continua escrevendo números MAP-01 e converte só na fronteira com o Workspace:

| Ferramenta | Onde entra o `MAP_FRAME` |
|---|---|
| `map_frame.luau` (novo) | `FRAME = CFrame.new(0, 0, K, −1,0,0, 0,1,0, 0,0,−1)` (matriz exata); `F`/`M` (ponto), `FD`/`MD` (direção), `FCF`/`MCF` (CFrame), `box` (retângulo X0..X1, Z0..Z1) |
| `place_assets.luau` | cada placement (e `pivot`) vira `MAP_FRAME * CFrame(x, y, z, rotY)`; `parts`/`copies` são relativos à entrada e não mudam; `Place.diff` usa a mesma conta (regra do trailer: pivô vivo × (MAP_FRAME × placement)⁻¹) |
| `bind_map01.luau` | tabelas (POINTS, NODES, ZONES, TRAFFIC_*, SHELVES, poses CART/TRL/TRL-SALE, janela do trailer) e a lógica (norte = −Z, "oeste primeiro" = X menor, caixas, sondas de raycast) ficam em MAP-01; leituras do Workspace passam por `M`/`MCF` (`partsBox`, `mapPos`, `mapPivot`, posição das cubas), escritas por `F`/`FCF` (`WorldCFrame`, `CFrame`, `PivotTo`, origem de raycast); `inward` das portas por `FD` |
| `bind_pieces.luau` | `PAD_POSE`/`COUNTER_POSE` por `FCF`; ordem oeste → leste dos slots da chapa lida em X MAP-01 |
| `check_map01.luau` | N/S/L/O do `FACING` por `FD`; `ROADS`/`CROSSWALKS` por `box`; amostra da rota Pad ↔ Mart (Z 44) por `F`; janelas WV pelo `M` |
| `src/Place/shared/MapIndex/Required.luau` | `ROADS`/`CROSSWALKS` viram retângulos do mundo (`mapRect`, mesmo K); usados por `MapIndex` (regra de travessia) e `ItemService/Drops` (item na pista vai para a calçada) |
| `src/Anomaly/client/.../ANM-008.luau` | rota do long car lida das faixas do binding (`E-IN` = faixa WB, `E-OUT` = faixa EB: posição + LookVector), não mais `Z ±5`/`X 140`; fallbacks pelo mesmo K |

Mudar `K` (outro giro) = mudar `map_frame.luau` e o `MAP_K` de `Required.luau` / `ANM-008.luau`. O resto do `src/` lê pontos/tags do binding (conferido: Content, Traffic, Cutscene, Light, Thief, Npc, Pedestrian, Door, Vehicle).

**Ruas (pedido do usuário, print da esquina: Kenney de um lado, asfalto liso do blockout do outro).** Toda pista e calçada da Ninth agora é AST-032 (`MAP-01_placements.luau` §1), com `parts.size` para escalar a malha:

| Trecho | Peças | Escala | Esconde |
|---|---|---|---|
| Ninth (X −136..136, Z −16..16) | 10 `RoadStraight` rotY 0, 24,8 de comprimento | atravessado 40: asfalto (19,2 de 24) = 32; meio-fio (topo 0,24) em \|Z\| 16..20, embaixo da calçada | `Roads/NinthAvenue` |
| Cruzamento (X −12..12) | `RoadCrossroad` 24 × 40 | quinas do meio-fio em X ±9,6..12, \|Z\| 16..20 continuam o meio-fio da Juniper | idem |
| Juniper: 1º trecho norte e sul | `RoadStraight` encurtado 24 → 20 (Z −40..−20 e 20..40) | ao longo da pista | — |
| BackStreet (Z −152..−136) | 10 `RoadStraight` 24,8 × 20 + `RoadCrossroad` 24 × 20 em (0, −144); último trecho da Juniper Norte encurtado para 22 (Z −134..−112) | asfalto 16 | `Roads/BackStreet` |
| Calçadas da Ninth (Z-02, Z-06) | 20 `SidewalkTile` 24,8 × 16 em y −0,08 | topo 0,4 (igual ao blockout: postes, lixeiras e pontos a 0,4 continuam no chão) | `Sidewalks/Z-0x_Ninth*` |

Asfalto no Y 0 em toda parte (pista y −0,24): faixas CW-1..4, linhas SL-* e linhas amarelas/brancas do blockout continuam por cima (0,01–0,05), nas mesmas posições do trânsito. Degrau de 0,16 entre calçada da Juniper (0,24) e da Ninth (0,4) continua como antes.

**Rodado em 2026-10-10:** `Place.diff` antes (referencial novo, placements antigos): só os postes esperados (JL-02..05 a 8/16/24/32 do lugar novo, JL-06..09 sobrando). `Place.run` 244/244 → `Bind.run` (err 0) → `Pieces.run` (21/21, err 0) → `Check.run({ wave = 3 })` **PASS, 0 erros**, 24 avisos (fittings de arte, barreiras, AS-1/2/3 e SP-S à vista — SP-S do SS através do vidro do B5; giro rígido, então já valia antes). `Place.diff` depois: **0 diferenças** (243 iguais). `Shutter_Hinge` no `Shutter_Panel` (`ClosedAngle −90`: a `Awning` medida deu ângulo degenerado). `Workspace.Model` (CrewDemo) e `Workspace.Rig` foram para `ServerStorage.DevScenes`.

### 16.10 Walker na Ninth, aba do trailer e ambientação (2026-10-10) — Provisório

| Item | O que muda | Onde |
|---|---|---|
| Postes do Walker | NL-01..04 na calçada norte da Ninth (X 118 / 98 / 78 / 58), Order 1..4, P-01 = 5; `WALKER-10` em (48, 14); 2 postes decorativos na Juniper; `RETIRED_POSTS` = JL-01..09 + `Post_NinthN_E1`; NL sem gêmeo no blockout ganha `SpotLight` padrão (log `new`) | `MAP-01_placements.luau` §3, `bind_map01.luau` (`POSTS`, `RETIRED_POSTS`, ponto `WALKER-10`) |
| Aba da janela | no caminho `Shutter_Panel`, a `Awning` fixa do AST-027 (placa vertical sobre a janela) é escondida (`AwningHiddenByBind`, `OrigAwning*`) | `bind_map01.luau` `bindShutterPiece` |
| Código | `Steps = 4` (`Rules/ANM-007`), `DEFAULT_STEPS = 4`, `STEPS = 4` (client), Hush `Step = 3` (`LightGroups`), lista de postes `NL-01..04, P-01` em `Required.luau` (onda 2 `Tagged` e onda 3 `STREET_POSTS`), comando dev `walker <0..4>` | `src/` (`tools/analyze.ps1` 0 erro) |
| Check | regra 14: linha de visão do centro da janela (trailer no Pad, MAP-01 (41,5; 8,2; 36,6)) até cada poste do Walker (pé +1, cintura, cabeça, lâmpada) e WALKER-10 — **erro** se nenhum raio passa; PS-N1..4 cego = aviso. Lista de postes NL | `check_map01.luau` |
| Spawn de teste | o `SpawnLocation` padrão do Roblox (placa 12 × 1 × 12 com decal de estrela) que estava no meio do cruzamento (X-T) vai para `ServerStorage.DevScenes` (W9). Personagens nascem pelo `CharacterService` em PS-* / PS-N*; o `SpawnLocation_PS` do blockout no Pad continua | `bind_map01.luau` W9 |
| `collide = false` | campo novo da tabela: todas as `BasePart` do modelo sem colisão (props de fachada, varais) | `place_assets.luau` `build` |

## 17. Ambientação (2026-10-10, pedido do usuário: "mapa muito pequeno, precisa de mais ambiente") — Provisório

Tudo na seção 8 de `MAP-01_placements.luau` (números gerados por um script descartável do level-designer a partir das regras abaixo; dali em diante a tabela é a fonte e pode ser editada à mão). Nada de gameplay muda: nenhum nó, rota, faixa ou ponto novo.

**17.1 Massas de fundo (`Fill_*`).** Os 7 volumes cinza do blockout ficam escondidos (`replaces`) e viram prédios:

| Fill | O que entra |
|---|---|
| `Fill_N_BankRear` (X 24..52, Z −88..−64) | 4 Kenney (2 de frente para a Juniper, 2 para o estacionamento), alturas 0 / −0,3 / −0,6 / −0,9 para os telhados sobrepostos não brigarem; 0,6 de folga do fundo do banco. Continua tapando SP-A |
| `Fill_N_ParkingRear` (X 32..104, Z −136..−88) | 5 Kenney de frente para o estacionamento (Z −88), cartões na BackStreet e cartões altos (×1,5–2,0) no meio. Beco de SP-A (X 24..32) aberto |
| `Fill_NW` (X −136..−36, Z −136..−64) | 5 Kenney de frente para a faixa AS-3 / Juniper (X −36), cartões na BackStreet, duas fileiras de cartões altos atrás de B3 (skyline vista da Ninth) |
| `Fill_SW_West` (X −136..−100, Z 32..120) | 2 Kenney na Ninth (fecham a quina NO do Mart), cartões na avenida oeste, cartões altos atrás do Mart (vistos do Pad por cima do telhado) |
| `Fill_SW_MartRear` | cartões ×1,3 de frente para o norte atrás do Mart + cartões na South Street |
| `Fill_SE_B1Rear` | 2 Kenney na Juniper Sul (X 24; continuam tapando SP-S / ST-R), cartões altos atrás de B1, cartões na South Street |
| `Fill_E` | Kenney na esquina da Ninth, 2 Kenney no beco EX-E, cartões na avenida leste |

**`Block_*` invisíveis** (`B1.Block_East`, `B1.Block_Rear` e os blocos de B2–B5 / banco): são os volumes do blockout que os prédios de asset substituíram. Já estão escondidos (Transparency 1), **sem colisão e sem consulta**, e travados (`Locked`, W7). **Nenhum código lê** (conferido: `src/` não cita; só `MAP-01_placements.luau` os esconde) e **não servem de limite**: os limites do jogador são `Limits/BAR-*` (com colisão) e as fachadas dos assets. Ficam no place só para o `Place.restore()` voltar ao blockout; pode ignorar. (Os de B1 estão deslocados em relação ao lote — movidos à mão em algum momento; como são invisíveis, não importa.)

**17.2 Cidade além dos limites (só visual).** Ruas novas, todas AST-032 escaladas, sem rota de trânsito nem nó de NPC:
- avenidas em **X ±154** (pista X 144..164) de Z −250 a 250, com cruzamentos na Ninth, na BackStreet e na **South Street** nova (Z 124..144);
- a Ninth continua até X ±250 depois das avenidas; a BackStreet e a South Street também; a Juniper continua ao norte da BackStreet e ao sul da South Street até Z ±250;
- placa de chão (SidewalkTile 900 × 900, topo −0,3) embaixo de tudo e placas de calçada (topo 0,24) nos quarteirões.

Prédios: **Kenney A/H onde uma rua vista da área jogável termina** (Ninth leste/oeste depois das avenidas, Juniper norte/sul depois das ruas transversais) e **cartões AST-033 BG_Card** (90–118 tris) no resto: frentes a 6 studs do meio-fio, miolo dos quarteirões com fileiras de cartões a cada 26, e um **anel de skyline** de cartões ×1,8–2,6 em X ±262 / Z ±262. Postes decorativos e 8 carros estacionados nas ruas de fora (estáticos).

Aviso (trânsito): os carros continuam nascendo em W/E-IN (X ±136) e JN/JS-IN; agora há rua depois desses pontos, então um carro que aparece em X ±136 pode ser notado do Pad a ~95 studs (antes ele surgia na borda do mundo). Proposta para o architect / `Q-102`: levar W/E-IN/OUT para as avenidas (X ±154, virando a esquina) — não feito aqui.

**17.3 Ruas jogáveis.** Conferido por script contra o grafo `NpcNode` (folga ≥ raio + 1,5 da aresta), rotas TR-* (≥ raio + 4), caixas CW-1..4 / X-T, pontos Q / PS / REV / CS / SS / spawn (≥ raio + 2) e linhas de visão (janela → NL-01..04 e WALKER-10, Pad → WV-1..3, câmeras da abertura → vitrines NO HELP WANTED, carrinho → trailer à venda):

| Tipo | Onde |
|---|---|
| Árvores (TreeLarge / TreeSmall) | T-07..T-16: pontas da Ninth além de BAR-W / BAR-E, Ninth sul X −60, Juniper Sul (X ±20..22, Z 62..74), praça do Mart (X −47 e −33) |
| Bancos | B3a (−80, −29,5) e B1 (100, 29,5), de frente para a rua |
| Vasos | B4 (100, −30,5), B1 (76 e 106, 30,8) |
| Hidrantes / correio / placas | hidrantes (−100, 17,5), (96, −17,5), (22,5, 48); correio (58, −29,5) na cerca do estacionamento; placas de rua nas quinas NO e SE |
| Caçambas (novo `AST-034_Dumpster`) | beco EX-E (116,5, 66), vão B3a/B2b (−68,7, −45,5), faixa AS-3 (−32, −70) |
| Ar-condicionado (novo `AST-034_ACUnit`, sem colisão) | 12 nas fachadas de B3, B2b, B4, B1, B5 e fundo do banco, a 9,5–12 de altura (fora do alcance) |
| Varais (novo `AST-034_Clothesline`, sem colisão) | vão B3a/B2b (Z −40, y 13) e beco EX-E (Z 58 e 72) |
| Carros parados no estacionamento | (76, −81) e (100, −64) |

Não entrou: lixeiras novas (o `Bind` transforma toda `AST-034_TrashCan` em `StreetBin` com prompt de descarte — seria gameplay) e toldos de fachada (o `detail-awning` do pack é só uma prancha com pés).

**17.4 Orçamento.** Seção 8: ~490 entradas (≈ 490 instâncias), **≈ 104 mil tris no total** da cidade nova (37 Kenney ≈ 51 mil, ~300 cartões ≈ 30 mil, carros ≈ 11 mil; o resto < 1 mil por tipo); só a parte perto das ruas visíveis entra na tela ao mesmo tempo (a névoa da noite termina em 200; de dia a `Atmosphere` apaga o anel de skyline). Malhas repetidas (mesmo `MeshId` + textura) são instanciadas pelo motor. Nenhuma luz nova além dos 4 NL (5 postes na cadeia com P-01; antes 6). A conferir no MicroProfiler do celular (art-director, §13).

**Rodado em 2026-10-10 (ids AST-034_ACUnit / _Clothesline / _Dumpster recebidos):** `Place.diff` antes: 229 iguais, diferenças só nas entradas novas, nos postes JL / `Post_NinthN_E1` substituídos e nos carros PARK-N 5/6 movidos (edições à mão do §16.0 presentes). `Place.run` 737/737 → `Bind.run` (err 0; W9 moveu o `SpawnLocation`; `Awning` escondida; NL-01..04 com `SpotLight` padrão) → `Pieces.run` 21/21 (err 0) → `Check.run({ wave = 3 })` **PASS, 0 erros**, 23 avisos (os mesmos de antes, menos SP-S; regra 14: NL-01..04 e WALKER-10 vistos da janela, 4/4 e 3/3 raios). `Place.diff` depois: **0 diferenças** (736 iguais). Lighting não foi tocado.
