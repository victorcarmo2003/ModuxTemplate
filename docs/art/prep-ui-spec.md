Status: Rascunho (Provisório; só o dono aprova, `CLAUDE.md`). Base: DEC-223 (modo focado V1), `docs/tech/prep-mode.md`, FEAT-039, `docs/research/good-pizza-great-pizza.md`, `style-guide.md` §2/§7 (Aprovado, DEC-126).

> **Nota de layout novo (2026-10-12, revisão do dono; `docs/tech/prep-3d.md` §5 e §3.0, Provisório):** o minigame passa a ser **todo 3D** (toppings inclusive) e a navegação é por **4 seções em sequência** (Grill, Board, Toppings, Serve). Isto **supera** neste spec: (1) a **barra superior com Leave + abas** (§4, §6.1): as **abas/seções vão para BAIXO** (centradas, logo acima da faixa da hotbar) e o **Leave embaixo à esquerda**, porque no topo eram cobertas pelo menu do Roblox e cobriam relógio e dinheiro; o **topo esquerdo (sanidade) e o direito (dinheiro/relógio) ficam livres e visíveis**; (2) o **ticket continua à esquerda** (abaixo da sanidade); (3) a **tábua 2D** (§5.1 a §5.4), o **painel de ingredientes** (§6.3) e o StrokeCanvas: viram objetos 3D (a barra de condimentos 2D à direita é só atalho opcional, Q-237); (4) um **indicador de progresso fino no topo, centrado**, no estilo da referência `Assets/reference/prep-mode/roblox-peeling-3d-board.png`; (5) a aba **Order** deixa de existir (Take no ticket). **Continuam valendo:** tokens, cores, contraste, tipografia, sem vermelho (o Leave da referência é vermelho; o nosso é Mustard/Ink), acessibilidade (§11), saídas (§12), regras de rig e NPCs (§13), selos de nota (§7). Medidas do layout novo em 667x375, 844x390 e desktop: `prep-3d.md` §5. Sprites AST-109, 110, 111, 114 e 116 perdem a razão de existir (o mundo é a arte).

# Modo de preparo focado: spec visual de UI, câmera e cena

Autor: art-director · 2026-10-12 · Só documentação (sem código). Mockup navegável: `docs/art/mockups/prep-ui.html` (abrir no navegador, offline).
Nada aqui reproduz layout, arte, nome ou fala de jogo de terceiros: as referências (estações de preparo em 2D; pizzaria mobile com caixas de ingrediente em grade) valem só como estrutura de uso.
Identidade própria: toy low-poly aconchegante, Mustard / Cream / Ink / Teal, Fredoka (a mesma do kit, `Theme.Font`), sem vermelho de alerta.

> **Honestidade sobre as fontes.** Não tenho acesso às imagens de referência do dono nem aos screenshots recentes do jogo (não estão em `Assets/reference/`). O que segue sobre as referências vem da descrição do dono, de `prep-mode.md` (Referência 1 e 2) e da pesquisa; o que segue sobre a UI atual vem do **código** (`HudController`, `InteractionMenu`, `TutorialPanel`, `Theme`) e dos registros do dia. O que não pude ver está marcado "não verificado".

## Índice

1. Veredito: o padrão está no estilo das referências?
2. Princípios e hierarquia (no máximo 5 persistentes)
3. Tokens: unidade, escala, safe area, cor por estado, tipografia
4. Layout do chrome por dispositivo (desktop, celular paisagem, retrato)
5. Wireframes por estação: Order, Grill, Build, Serve
6. Componentes e estados
7. Indicadores de nota (Perfect, Good, Messy)
8. Feedback: partículas, pop, som
9. Animação
10. Ordem de leitura e navegação
11. Acessibilidade
12. O que fica FORA da tela
13. Câmera e cena: regras anti-sobreposição
14. Revisão crítica da UI atual
15. Sprites e ícones (AST-108 a AST-119)
16. Checklist visual de aceite e pendências para o dono

---

## 1. Veredito: o padrão está no estilo das referências?

**Estrutura: sim.** O desenho de `prep-mode.md` §2 e da Referência 2 já bate com o que o dono mostrou:

| Referência (conceito) | O que o projeto já definiu | Veredito |
|---|---|---|
| Estações em abas no topo (Order, Grill, Build) | Abas Order / Grill / Build / Serve no topo (`Content.Prep.Tabs`) | Igual em estrutura |
| Ticket sempre à mão | Ticket na lateral esquerda, troca por toque | Igual |
| Lixeira embaixo à esquerda, Next embaixo à direita | Idem (`Texts.Trash`, `Texts.Next`) | Igual |
| Caixas de ingrediente em grade à direita | Painel 2x3 à direita, alvos >= 44 px | Igual |
| Prato no centro-esquerda | Superfície central (PlateView) | Igual |
| Diálogo do cliente (2 botões) | "Got it" / "Come again?", opcional atrás de flag (Q-227 sugerida) | Igual, adiado |

**Visual: ainda não.** Hoje o modo focado só tem placeholders (`Icon = ""`, formas Mustard/Cream/Ink). Três riscos de "ficar com cara de HUD de debug":

1. **Pílulas Ink translúcidas** do HUD (`Theme.Tone.Ink`, 70%) leem como sobreposição de status, não como "mesa de trabalho". As referências são de superfícies **claras, grandes, saturadas e opacas**. Regra deste spec: no foco, o chrome é **Cream/Mustard/Teal**; Ink só em contorno, texto e na pílula de status.
2. **Muita coisa ao mesmo tempo.** Dinheiro, dia, relógio, sanidade, ordem, tutorial, prompts e toasts competem com o miolo. Regra: **5 persistentes** (§2) e o resto por contexto.
3. **O mundo 3D atrás** compete com a tábua 2D se estiver nítido. Regra: fundo **desfocado** (DOF) ou, em qualidade <= 3, **vinheta Ink 35%** (§13).

**O que é nosso (não copiar):** animais da crew como clientes nos tickets, ícones renderizados dos **modelos 3D do jogo** (consistência mundo, balão, hotbar, tábua), o selo Perfect/Good/Messy por **forma + cor + texto**, o fundo 3D do trailer, a regra "um único Mustard sólido por vez" (§2), a saída forçada por anomalia, os chips de co-op.

---

## 2. Princípios e hierarquia

### 2.1 No máximo 5 persistentes

"Persistente" = bloco com painel próprio visível o tempo todo em foco. São **cinco**, nem um a mais:

| # | Persistente | Papel | Peso visual |
|---|---|---|---|
| 1 | **Barra superior** (Leave + 4 abas) | onde estou, como saio | 3 |
| 2 | **Ticket** (esquerda) | o que preciso fazer | 2 |
| 3 | **Tábua** (centro; é o conteúdo, não "chrome") | onde faço | 1 (dominante) |
| 4 | **Next / Serve** (embaixo à direita) | o único botão de avançar | 2 |
| 5 | **Status** (topo direito: dinheiro + relógio; tira de sanidade à noite) | só leitura, passivo | 4 |

**Por contexto (aparecem e somem, 220 ms):** painel de ingredientes (**só na aba Build**), lixeira (**só com prato em montagem**), dica de uma linha (**dentro do cabeçalho da tábua**, não é bloco à parte), selo de nota, toast (1 por vez), chips dos colegas (**só em co-op**), medidor de molho (**só durante o traço**), cursor do gesto, tooltip de nome, diálogo do cliente (flag).

### 2.2 Regras de composição

- **Uma tarefa por tela.** A aba é a tarefa; o cabeçalho da tábua diz o verbo em uma linha (16 px, <= 36 caracteres).
- **Regra do 1 Mustard.** Mustard **sólido** só no que se pode/deve tocar **agora**: aba ativa, Next habilitado, item selecionado. Nunca mais de 2 áreas Mustard sólidas ao mesmo tempo. Todo o resto é Cream, Teal ou Slate. Isto é o que faz a tela "respirar".
- **Nada no centro-inferior além da tábua e do toast.** Terço inferior direito = Next. Nada sobre a mira (não há mira em foco).
- **Sem painel sobre painel.** Nenhum bloco persistente sobrepõe outro (conferido nas tabelas de retângulos, §4). Toast e selo são os únicos que podem cobrir a tábua, por <= 1,2 s, e nunca o miolo do gesto em curso.
- **Margem e respiro.** Margem de tela 12 px (+ safe area), espaço entre blocos >= 8 px, padding interno de painel >= 8 px, de texto >= 10 px na horizontal. Nenhuma linha de texto encosta na borda (sem texto apertado).
- **Texto curto, em inglês** (DEC-022). Cada rótulo de botão <= 12 caracteres, cada dica <= 36, cada fala de ticket <= 2 linhas de ~16 caracteres. Texto longo vira tooltip ou expansão do ticket por toque.

### 2.3 Hierarquia (de cima para baixo na atenção)

1. Tábua (o que fazer agora) · 2. Next quando habilitado (pulsa) · 3. Ticket e patience ring · 4. Aba ativa · 5. Painel de ingredientes (Build) · 6. Status (nunca pulsa, exceto +$ ao ganhar).

---

## 3. Tokens

### 3.1 Unidade e escala

Todas as medidas abaixo estão em **px de UI** (o que o código do kit usa, antes de `Theme.Scale`). O modo focado **não cria escala própria**: usa `Theme.ScaleOf(viewport)`.

| Dispositivo | Janela real | Escala | Canvas em px de UI | Observação |
|---|---|---|---|---|
| Desktop 16:9 | 1280x720 | 0,93 | ~1371 x 771 | qualquer 16:9 até 2160p dá o mesmo canvas (a escala é proporcional à altura; teto 1,6) |
| Celular paisagem | 844x390 | 1,00 (piso de toque) | 844 x 390 | alvo mínimo: 667x375 (`TASK-174`); tudo cabe também lá |
| Celular retrato | 390x844 | ~1,09 | ~358 x 774 | |

Alvo de toque: **>= 44 px** (`Theme.MinTouch`) em tudo que se toca, também no desktop (mesmo componente). Chips não tocáveis: altura >= 32 (`Theme.MinChip`). Texto >= 14 px (`Theme.MinTextSize`); o "11 px" da sanidade compacta **não vale** no foco (`board.md`, TASK-174/175).

### 3.2 Safe area e zonas reservadas

- Margem = 12 px + `DeviceSafeInsets` (entalhe e barra de gestos): lateral 0 a 47, base 0 a 24, em px reais; converter por `/ Scale`.
- **Zona Roblox topo-esquerdo** (menu + chat): ~0..270 x 0..60 px reais no desktop, ~0..110 x 0..52 no celular (`HudController.TOPBAR_REAL = 60`). **Nada nosso nessa zona.** A barra superior é centrada e começa depois dela.
- **Controles de toque do Roblox** (joystick embaixo-esquerda, pulo embaixo-direita): **escondidos em foco** (requisito do P5, verificar em Play; o `Frozen` já trava o movimento mas não prova que o `TouchGui` some). Se não sumirem, Trash e Next colidem com eles em paisagem.
- **Desktop:** `PlayerList` (topo direito) e `Backpack` (hotbar, centro-baixo) **escondidos em foco**; chat recolhido (ver §14). Sem isso, Status e Next colidem.

### 3.3 Cor por estado (sem vermelho de alerta)

Tons de `Theme.Tone` reaproveitados (`Cream`, `Mustard`, `Teal`, `Green`, `Slate`, `Ink`, `White`). **Ketchup/`Theme.Color.Low`/`NoCash` não são usados em estado de UI**; o vermelho do ketchup existe só como **cor de comida** nos ícones.

| Estado | Superfície | Contorno | Texto | Pista que não é só cor |
|---|---|---|---|---|
| Normal (tocável) | Cream `#FFF8EA` > `#FBE3B8`, lip `#D9B57A` | Ink 3 px | Ink `#2B2233` | lip de 4 px embaixo |
| Hover / foco (teclado, gamepad) | igual | Ink 3 px + **anel externo Mustard 4 px** | Ink | anel + escala 1,05 |
| Selecionado / ativo | **Mustard** `#FFDA5C` > `#F6B71B`, lip `#B97F0A` | Ink 4 px | Ink | **triângulo/entalhe** na borda (aba) ou **check** no canto (cartão) |
| Pressionado | igual ao normal | Ink 3 px | Ink | escala 0,95 + lip some (afunda 3 px) |
| Desabilitado | Slate `#A9AEBF` > `#8A8FA3` | Ink 3 px, **tracejado** | Ink 60% | contorno tracejado + ícone 50% |
| Bloqueado (dia futuro) | Slate | Ink 3 px | — | **cadeado** (`Notice/lock`) |
| Sem estoque | Slate | Ink 3 px | "0" em chip Ink | risco diagonal + "0" |
| Aviso (ex.: pouco estoque, paciência baixa) | Cream | Ink 3 px | — | **triângulo "!" Mustard** (forma) |
| Erro (ação recusada) | igual ao normal | **tremida** (3 x 6 px, 180 ms) | — | tremida + som `error` + toast |
| Sucesso | Green `#86CF8F` > `#5FA36A` (chip) | Ink 3 px | Ink | **check** |
| Dica ao jogador (anel de tutorial) | — | Mustard 4 px pulsando | — | anel, não preenchimento |

Contraste medido (WCAG, luminância relativa): Ink sobre Cream **13,6:1**; Ink sobre Mustard **9,1:1**; Ink sobre Green `#5FA36A` **5,0:1**; Ink sobre Teal `#3FA7B5` **5,4:1**; Ink sobre Slate `#8A8FA3` **4,7:1**. **Branco sobre Teal = 2,8:1 (reprova)**: no foco, superfícies Teal levam **texto Ink** (ou branco só com contorno Ink 3 px e >= 20 px). Mustard e Cream são parecidos entre si (1,5:1): a separação vem do **contorno Ink 3 px** (13,6:1), nunca da diferença de cor. Texto sobre o 3D nunca; texto sempre sobre superfície sólida.

### 3.4 Tipografia (Fredoka One via `Theme.Font`)

| Uso | Tamanho (px de UI) | Cor | Traço Ink |
|---|---|---|---|
| Rótulo de aba | 16 (desktop 18) | Ink | não (superfície clara) |
| Next / Serve | 20 (desktop 22) | Ink | não |
| Dica do cabeçalho da tábua | 16 | Ink | não |
| Ticket: número "#12" | 16 | Ink | não |
| Ticket: fala do cliente | 15, máx. 2 linhas | Ink | não |
| Chip de estoque / contador | 14 | Ink | não |
| Status (dinheiro, relógio) | 16 | branco | sim (pílula Ink, `TextStroke(16)` = 2 px) |
| Toast | 16 | Ink sobre Cream | não |
| Selo "Perfect!" | 30 (desktop 34) | Ink | contorno Cream 3 px para destacar do selo |
| Nome em tooltip | 14 | branco sobre Ink | sim |

Entrelinha 1,25. Sem sublinhado, sem itálico, sem caixa alta contínua (só rótulos curtos). Pior caso testado nas stories: "Potato Sticks", "$9,999", "Come again?", nome de cliente com 16 caracteres.

### 3.5 Forma

`CartoonPanel` em tudo: raio `Card` 14 px (cartões, tábua), `Pill` (botões, abas, status), `Chip` 10 px (caixas de ingrediente), lip 4 px, brilho (gloss) ligado, contorno 3 px (4 em foco). Ícones 2D chapados com contorno Ink e sombra suave, **renderizados dos modelos 3D** (estilo do AST-071). Nada de contorno pintado no 3D.

---

## 4. Layout do chrome por dispositivo

Convenções: `(x, y, w, h)` em px de UI, origem no canto superior esquerdo do canvas; `i` = somar `DeviceSafeInsets`. Lip de 4 px está **incluído** na altura.

### 4.1 Celular paisagem 844 x 390 (referência de projeto)

```
ASCII: 1 coluna = 8 px, 1 linha = 16 px (precisão +/- 8 px; vale a tabela)
col:  0         1         2         3         4         5         6         7         8         9         10
      0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345
r0                  +----+ +-----------+ +-----------+ +-----------+ +-----------+      +------------------+
r1                  |exit| | Order  (2)| | Grill (v3)| |[  Build  ]| | Serve  (.)|      | $128   o 9:41 AM |
r2                  +----+ +-----------+ +-----------+ +-----------+ +-----------+      +------------------+
r3                                                                                           [==========--------]
r4    +-----------------+ +------------------------------------------------------------+ +------------------+
r5    | #12  (o)    +3  | | o Cut  o Place  o Top    Drag the knife along the line     | | Toppings         |
r6    | [ket][mus][che] | |                                                            | | +------+ +------+|
r7    |                 | |                                                            | | | KET  | | MUS  ||
r8    |  'The usual,    | |        << TABUA / PLATE VIEW (conteudo da aba) >>          | | | x12  | | x9   ||
r9    |  please.'       | |                      492 x 256                             | | +------+ +------+|
r10   |                 | |                                                            | | +------+ +------+|
r11   |                 | |                                                            | | | CRM  | | CHE  ||
r12   \/\/\/\/\/\/\/\/\/\ |                                                            | | | x4   | | [L]  ||
r13                       |                                                            | | +------+ +------+|
r14   ( )( )( )  crew     |                                                            | | +------+ +------+|
r15                       |                                                            | | | BAC  | | POT  ||
r16                       |                                                            | | | x7   | | x10  ||
r17                       |                                                            | | +------+ +------+|
r18                       |                                                            | +------------------+
r19                       +------------------------------------------------------------+
r20   +-----+
r21   |trash|                                                                                   +---------------+
r22   | bin |                  [! Add the bun first        ]                                    | Next        > |
r23   +-----+                                                                                   +---------------+
```

(Leitura: `exit` = Leave, ícone de porta com seta; `(2)` = clientes aguardando no pedido; `(v3)` = 3 salsichas prontas; `[L]` = cadeado de dia futuro; `[==---]` = tira de sanidade, só à noite; `r20-r23` Trash só com prato; toast em r22.)

| Elemento | (x, y, w, h) | Notas |
|---|---|---|
| Barra superior | (150, 8, 486, 48) | Leave 44x44 em x 150; abas 104x44 em x 202, 312, 422, 532 (vão 6). Deslocada 29 px à esquerda do centro para dar largura ao status; não depende de `i` |
| Status | **ancorado à direita** (`right = 12 + i`), y 10, largura **automática 148..190**, altura 32 | pílula Ink: moeda + `$128` + sol/lua + `9:41 AM` (15-16 px). Pior caso "$9,999" cabe em 179 px e termina a >= 12 px da barra (x 636). À noite, tira de sanidade com a **mesma largura** (y 46, h 10) |
| Ticket | (12+i, 60, 152, 140) | altura variável 120..140 (2 linhas de fala) |
| Chips de colegas | (12+i, 208, 132, 36) | só co-op; até 3 chips 36x36, vão 6 |
| Tábua | (176, 60, 492, 256) | com painel de ingredientes. **Sem painel** (Order/Grill/Serve): x = 252 (centrada entre ticket e margem direita), mesma largura |
| Painel de ingredientes | (682, 60, 150, 246) | só Build. Cabeçalho 22; grade 2x3 de caixas **64x64**, vão 6, padding 8; cada caixa: ícone 40 + chip de estoque 14 px no canto |
| Next / Serve | (700, 326, 132, 52) | alinhado à borda direita e à base (12 px) |
| Lixeira | (12+i, 322, 56, 56) | só com prato em montagem |
| Toast | (262, 336, <= 320, 32) | centro-baixo, 1 por vez |

Sem sobreposição (conferido): ticket termina em x 164, tábua começa em 176; tábua termina em 668, painel começa em 682; painel termina em y 306, Next começa em 326; barra superior termina em y 56, tábua/ticket/painel começam em 60; status (largura máx. 190, x >= 642) não toca a barra (termina em 636); a barra começa em x 150, depois da zona do Roblox (~0..110).

### 4.2 Desktop 16:9 (canvas ~1371 x 771; ex.: 1280x720)

```
ASCII: 1 coluna = 16 px, 1 linha = 32 px
col:  0    5    10   15   20   25   30   35   40   45   50   55   60   65   70   75   80   85
r0                           +----------+ +----------+ +----------+ +----------+ +----------+            +----------+
r1                           |Leave|     | Order  (2)| | Grill (v3) | |[ Build ]  | | Serve  (.)|            | $128  9:41|
r2                           +-----------------------------------------------------------+                [=======---]
r3    +----------+       +---------------------------------------------------+               +----------+
r4    | #12  (o) |       |  o Cut   o Place   o Top      Drag the knife ...  |               | Toppings |
r5    | [k][m][c]|       |                                                   |               | [KET][MUS]|
r6    | 'The     |       |                                                   |               | [CRM][CHE]|
r7    |  usual'  |       |           TABUA / PLATE VIEW 780 x 480            |               | [BAC][POT]|
r8    \/\/\/\/\/\/       |                                                   |               +----------+
r9    ( )( )( ) crew     |                                                   |
r10                      |                                                   |
...                      |                                                   |
r17                      +---------------------------------------------------+
r22   +----+                                                                                    +----------+
r23   |bin |                    [! Add the bun first]                                           | Next   > |
      +----+                                                                                    +----------+
```

| Elemento | (x, y, w, h) | Notas |
|---|---|---|
| Barra superior | (366, 12, 640, 52) | Leave **com texto** 96x48 (ícone + "Leave"); abas 128x48 em x 470, 606, 742, 878 (vão 8) |
| Status | ancorado à direita (`right` 16), y 14, largura automática 168..220, altura 36 | tira de sanidade com a mesma largura (y 54, h 10) à noite |
| Ticket | (16, 84, 184, 152) | **se o chat do Roblox não puder ser recolhido** (§14): y = 252 |
| Chips de colegas | (16, 244, 140, 40) | só co-op |
| Tábua | (304, 84, 780, 480) | com painel; sem painel: x = 388 |
| Painel de ingredientes | (1188, 84, 168, 260) | caixas **72x72**, vão 8, cabeçalho 24 |
| Next / Serve | (1204, 696, 152, 56) | |
| Lixeira | (16, 692, 60, 60) | |
| Toast | (506, 704, <= 360, 36) | |

O vazio entre o painel (termina em y 344) e o Next (começa em 696) é **intencional** (respiro; nada ali).

### 4.3 Celular retrato 390 x 844 (canvas ~358 x 774)

```
ASCII: 1 coluna = 8 px, 1 linha = 16 px (recortado: linhas de respiro omitidas com "...")
        0         1         2         3         4
col:    012345678901234567890123456789012345678901234
r0      [Roblox menu/chat]      +--------------+       status (196,14,150,32)
r1                              | $128 o 9:41  |
r2                              +--------------+
r3                              [======-------]  (sanidade, so a noite)
r4      +--+ +-------------+ +--+ +--+ +--+            barra (12,64,334,48)
r5      |ex| |[ Build    ] | |Or| |Gr| |Se|            aba ativa 100 px com rotulo; as outras 48 px so icone
r6      +--+ +-------------+ +--+ +--+ +--+
r7      +----------------------------------------+    ticket em FAIXA (12,120,334,82)
r8      | (face) #12 (o)  [k][m][c]   +3         |
r9      | 'The usual, please.'                   |
r10     \/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
r11     +----------------------------------------+    tabua (12,210,334,268)
r12     | o Cut  o Place  o Top   Drag the knife |
r13     |                                        |
...     |        << TABUA 334 x 268 >>           |
r29     +----------------------------------------+
r30        +------------------------+                  painel 3x2 (67,486,224,176)
r31        | Toppings               |
r32        | [KET] [MUS] [CRM]      |
r33        | [CHE] [BAC] [POT]      |
...        +------------------------+
r42     +----+      ( )( )( )      +-----------+       Trash (12,676,54,54)  Next (214,676,132,54)
r43     |bin |   (toast aqui)      | Next    > |
r44     +----+                     +-----------+
```

| Elemento | (x, y, w, h) | Notas |
|---|---|---|
| Status | ancorado à direita (`right` 12), y 14, largura automática 150..190, altura 32 | na faixa do topo do Roblox, à direita (o cluster do Roblox fica à esquerda, ~0..120); tira de sanidade com a mesma largura (y 50, h 10) |
| Barra superior | (12, 64, 334, 48) | Leave 44; **aba ativa** 100 px (ícone + rótulo), **demais** 48 px (só ícone) |
| Ticket (faixa) | (12, 120, 334, 82) | linha 1: rosto 40 + "#12" + ring 36 + ícones 3x36 + "+N"; linha 2: fala em 1 linha |
| Tábua | (12, 210, 334, 268) | **sem painel** (Order/Grill/Serve): altura 452 (até y 662) |
| Painel de ingredientes | (67, 486, 224, 176) | grade **3x2**, caixas 64x64, vão 8 |
| Trash / Next | (12, 676, 54, 54) / (214, 676, 132, 54) | base do canvas deixa >= 40 de folga (gestos) |
| Chips de colegas | (80, 684, 120, 36) | **somem enquanto há toast** (o toast ocupa o mesmo lugar, (39, 684, 280, 36)) |

---

## 5. Wireframes por estação

O chrome (§4) é o mesmo nas 4 abas; muda o conteúdo da **tábua** e o que está por contexto. Os desenhos abaixo são da tábua em **celular paisagem (492 x 256)**, 1 coluna = 8 px, 1 linha = 16 px. Desktop = a mesma composição em 780 x 480 (mais respiro, caixas e cartões 12% maiores); retrato = ver notas de cada estação.

### 5.1 Order (ticket)

Propósito: ver quem espera e pegar o pedido. Nada além dos cartões.

```
+------------------------------------------------------------+
| Take a ticket                                         (o) 3|  cabecalho 28 px: dica + fila
|                                                            |
| +-------------+ +-------------+ +-------------+ +----------+
| | (face)  (o) | | (face)  (o) | | (face)  (o) | |(face)    |  cartao 116 x 176, vao 8
| | [k][m][c]   | | [k][c]      | | [b]         | |          |  icones <= 3 (28 px)
| |             | |             | |             | |          |  pao + salsicha sao implicitos
| | 'The usual, | | 'Two, no    | | 'Plain.'    | |          |
| |  please.'   | |  onions.'   | |             | |          |
| |             | |             | |             | |          |
| | [   Take  ] | | [ Taken  v] | | ( waiting ) | |          |  Take 100 x 44 (Mustard)
| +-------------+ +-------------+ +-------------+ +----------+
+------------------------------------------------------------+
```

- Cartões em fileira com rolagem horizontal (toque, roda, D-pad); mais antigo à esquerda. 3 cartões inteiros + 1 "espiando" (sinal de que há mais).
- Estados do cartão: **Ordering** (cliente no balcão): botão Take Mustard; **Taken** (já na fila de preparo): chip Slate com check; **Waiting** (ainda a caminho): ring de paciência apenas, sem botão; **Mine** (fixado por mim): contorno Mustard 4 px + pino no canto; **Taken by crew** (fixado por colega): chip com o avatar dele.
- Anel de paciência no canto: Teal > Mustard (< 40%) > Mustard pulsando + ampulheta (< 15%). **Nunca vermelho.**
- **Next** nesta aba: habilita quando há um ticket pego ("Next" vai para Grill).
- **Retrato:** cartões 2 colunas x 2 linhas rolando na vertical (altura 452), mesmo conteúdo.
- **Variante com diálogo (flag, Q-227 sugerida):** ao tocar Take, a tábua vira

```
+------------------------------------------------------------+
|                                                            |
|  (face 64)   +---------------------------------------+     |
|              | "Whatever she's having.               |     |  balao Cream, 18 px, <= 3 linhas
|              |  She's right behind me."              |     |
|              +---------------------------------------+     |
|                                                            |
|            [  Got it  ]        [ Come again? ]             |  2 botoes 44 px (Mustard / Cream)
|                                                            |
+------------------------------------------------------------+
```
  "Come again?" gasta paciência e revela o detalhe (humor -1 faixa); nunca mexe no preço. O botão que gasta paciência leva o ícone de ampulheta (forma, não só cor). Cliente estranho (anomalia) só oferece a leitura estranha.

### 5.2 Grill

Propósito: pôr salsichas, virar na janela, coletar. **O painel de ingredientes não aparece** (a caixa de salsicha é o próprio slot vazio "+").

```
+------------------------------------------------------------+
| Flip when the ring glows                          Ready x3 |  chip do trilho (14 px)
|                                                            |
| +-----------+ +-----------+ +-----------+ +-----------+    |
| | ~~sausage | | ~~sausage | |  FLIP!    | |     +     |    |  slot 112 x 64
| | [==|##|==]| | [=|##|===]| |  (ring)   | |  (vazio)  |    |  barra com janela 40-60% (##)
| +-----------+ +-----------+ +-----------+ +-----------+    |
| +-----------+ +-----------+ +-----------+ +-----------+    |
| |  DONE  v  | |     +     | |     +     | |     +     |    |
| |  Collect  | |           | |           | |           |    |
| +-----------+ +-----------+ +-----------+ +-----------+    |
|                                                            |
| rail: [s][s][s] ......                                     |
+------------------------------------------------------------+
```

- **Slots 4x2** (até 8, `PrepGrill.Slot 0..8`), toque na célula inteira (112x64). Estados (forma + cor + texto):

| Estado | Visual | Toque faz |
|---|---|---|
| Vazio | contorno tracejado, "+" | `Place` (gasta 1 salsicha do estoque) |
| Cozinhando | salsicha rosada > marcada, barra com **colchete** na janela de virar (40-60%), marcador andando | nada |
| **Pronto para virar** | anel Mustard pulsando + seta de virar + rótulo "Flip" | `Flip` (nota da salsicha, §7) |
| Virada | salsicha com marcas dos dois lados, barra continua | nada |
| **Pronta** | check Green + rótulo "Collect" | `Collect` (vai ao trilho) |
| Sem estoque | "+" cinza com "0" | recusa: tremida + toast |
| Não virada (Q-222) | sem selo de virada; ao coletar a nota da salsicha é Messy | |

- A janela de virar é um **colchete com entalhes** (forma), não só uma cor. A cozinha segue em paralelo com o jogador em outra aba; a aba Grill mostra **badge Green com check e número** quando há salsicha pronta (§6.1).
- O trilho é um **chip** "Ready x3" (14 px) + 3 miniaturas; sem fileira de 8 slots (menos poluição).
- Sem queimar na fase 1: nunca aparece cinza-carvão nem vermelho.
- **Retrato:** slots em 2 colunas x 4 linhas (150 x 48), cabeçalho 28, chip do trilho 24; altura 452 sobra folga.

### 5.3 Build (a aba principal)

Propósito: cortar o pão, encaixar a salsicha, aplicar até 3 complementos, **ordem livre**. É a única aba com painel de ingredientes.

```
+------------------------------------------------------------+
| o Cut  o Place  o Top      Drag the knife along the line   |  3 pips (forma do selo) + dica 16 px
|                                                            |
|  +-----------+                                             |
|  | sausage   |           .--------------------------.      |  salsicha pronta da frente do trilho:
|  | (ready)   | ~~~~~~~~~>|   [  bun  ]              |      |  chip arrastavel 96 x 44 (com sua nota)
|  | Perfect*  |           | - - - - - - - - - - - -  |      |  guia tracejada do corte
|  +-----------+           '--------------------------'      |  pao 260 x 84 sobre o "mat" Cream
|                                                            |
|                       [ sauce meter  ====|##|== ]          |  so durante o traco do molho (160 x 10)
|                                                            |
+------------------------------------------------------------+
```

Sub-etapas (3 pips no cabeçalho, não tocáveis; cada pip vira o **mini-selo** da nota da etapa):

| Pip | Gesto | O que se vê | Cursor |
|---|---|---|---|
| Cut | arrastar a faca na guia tracejada | linha preenche, pão abre ao fim | faca (64) |
| Place | arrastar a salsicha do chip ao vão do pão; ímã a 20% | salsicha encaixa com "thunk" | mão que pega |
| Top | por complemento (até 3) | molho: segurar e traçar zigue-zague com **medidor** de quantidade; queijo: arrastar a fatia; bacon: 3 toques nos anéis que fecham; batata: segurar e soltar na faixa verde | garrafa / mão / pitada |

- **Painel de ingredientes (2x3):** ketchup, mustard, cream cheese, cheese, bacon, potato sticks (ordem fixa = ordem de `Ingredients.ToppingKeys`, nunca reordenar). Cada caixa: ícone 40 (AST-071) + **chip de estoque** no canto + estados (§6.3). Já usado no prato = caixa **afundada** com check (não repete). Chegou em 3 = as demais ficam desabilitadas (tracejado). Nome só em **tooltip/legenda** (hover, long-press, foco): "Ketchup · 12 left".
- **Falta de salsicha pronta:** a tábua mostra "Waiting for the grill" (§6.9) com o ghost da salsicha; o jogador pode ir à aba Grill (o prato fica **Parked**).
- **Lixeira (contextual):** aparece no canto inferior esquerdo com o primeiro item no prato. **Segurar 0,5 s** (anel enchendo) ou **soltar o prato arrastado em cima**; toque simples **não** descarta (evita perder ingredientes por acidente). Perde pão e salsicha (`Trash.luau`).
- **Next:** habilita ao cumprir `Needs` (`BunCut`, depois `PlateBuilt`); ao tocar, fecha o pão (0,4 s), mostra o selo do prato e vai para Serve.
- **Retrato:** tábua 334 x 268 acima, painel 3x2 abaixo (§4.3). O medidor de molho fica logo abaixo do pão.
- **Desktop:** a mesa Cream (mat) é 520 x 300; a dica e os pips ficam num cabeçalho de 36 px.

### 5.4 Serve (entrega)

Propósito: conferir o prato contra os clientes e entregar. A entrega continua Completa/Incompleta/Errada pelo servidor (DEC-072); a UI só mostra e atalha.

```
+------------------------------------------------------------+
| Pick the matching customer                                 |
|                                                            |
|  +---------------+     +----------+ +----------+ +--------+|
|  |  YOUR PLATE   |     | (face) o | | (face) o | |(face) o||  cartao 100 x 128
|  |  (hot dog)    |     | [k][m]   | | [k][c]   | |[b]     ||
|  |  [k][m]       |     |          | |  v MATCH | |        ||  o que combina: contorno Mustard
|  |   (Perfect*)  |     |   .      | | ^ lift   | |        ||  + check + sobe 6 px
|  +---------------+     +----------+ +----------+ +--------+|
|                                                            |
+------------------------------------------------------------+
```

- **Seu prato** (esquerda): hot dog montado (ícone 2D com os complementos), o **selo** da nota pregado no canto. Sem prato pronto: estado vazio "Nothing to serve" com ghost do prato (§6.9).
- **Cartões dos clientes** do balcão e das mesas (ícone da mesa/balcão no canto). O cartão que **combina** com o prato vem **destacado**: contorno Mustard 4 px + check no canto + eleva 6 px. Os demais ficam normais. Quem não combina **não** é escondido (servir errado é permitido, DEC-072).
- Toque no cartão = seleciona (contorno Mustard + marca de seleção); o botão **Serve** (Mustard, ícone de sino) confirma. Dois toques para entregar, nunca um toque acidental.
- **Resultado** (do servidor): selo de entrega no cartão, por forma: **Complete** (círculo Green + check), **Incomplete** (círculo Mustard + metade preenchida), **Wrong** (quadrado Slate + X). Mais "+$2" quando há gorjeta (Perfect). Nenhum vermelho.
- **Retrato:** "Seu prato" vira faixa de 84 px no topo da tábua; cartões em 2 colunas.

### 5.5 Estados por aba

| Aba | Vazio | Ativo | Erro / recusa |
|---|---|---|---|
| Order | "No customers yet" + cliente dormindo (ícone); Take desabilitado | cartões; Take Mustard no mais antigo | Take recusado (outro pegou): cartão vira Taken com tremida |
| Grill | 8 slots tracejados com "+" | slots cozinhando; badge na aba | sem estoque: "+" cinza "0" + toast "Out of sausages" |
| Build | tábua com pão fechado + dica "Cut the bun" | gesto em curso; pips; painel | `NoStock` (complemento): caixa tremida + "0"; `HandsFull`: toast + prato fica Parked; `TooFast`: toast "Take your time" |
| Serve | "Nothing to serve" | cartões + prato | `NotSelling`: toast "We are closed"; cliente foi embora: cartão some com puff |

---

## 6. Componentes e estados

### 6.1 Barra superior (Leave + abas)

- **Aba** (`CartoonButton`, Pill): 104x44 (paisagem), 128x48 (desktop). Ícone 28 + rótulo 16. Ativa = Mustard, sobe 3 px, **entalhe triangular** (6 px) apontando para a tábua. Inativas = Cream. Não há aba desabilitada (todas existem desde o Dia 1; Serve fica "vazia", não bloqueada).
- **Badge** no canto da aba (círculo 22, número 14 px): Order = clientes aguardando (Teal); Grill = salsichas **prontas** (Green com check); Serve = pratos prontos (Mustard). Some quando 0. O badge é o substituto das pílulas de status do HUD.
- **Leave:** 44x44 só com ícone (porta + seta) em celular, "Leave" com texto no desktop. Sai em 0,30 s (instantâneo com movimento reduzido). Sair com prato em curso mantém o prato como **Parked** por 20 s (`ClientIdle`); o toast avisa uma vez ("Plate saved for 20 s").
- Alvo: atalho de teclado `Tab` (próxima aba), `1-4`, `Q`/`Esc` = Leave; gamepad `LB/RB`, `B`.

### 6.2 Ticket

- Papel Cream (`#FFF8EA`), contorno Ink 3 px, borda inferior **rasgada** (serrilha de 8 px), **pino** Teal no topo (pista de "fixado").
- Cabeçalho: rosto do cliente (animal, 32; placeholder = círculo + inicial), "#12", **anel de paciência** (28, cresce com o estado), chip "+N" (14 px) = quantos tickets há atrás (**essa é a fila**: nada de balões no mundo).
- Linha de ícones: **só o que foge do padrão** (pão + salsicha são implícitos, não aparecem): até 3 complementos, ícones 36 (AST-071).
- Fala do cliente: 15 px, <= 2 linhas, entre aspas; reticências se estourar; **toque no ticket** expande por 4 s **sobre o próprio ticket** (nunca sobre a tábua) e alterna para o próximo ticket em toque longo/seta.
- Estados: **vazio** ("No ticket" + tracejado), **ativo**, **pago/servido** (carimbo Green, some em 0,6 s), **urgente** (anel Mustard pulsando, ampulheta).
- Em retrato vira **faixa** (82 px): rosto + "#12" + ring + ícones + "+N" na 1ª linha, fala na 2ª.

### 6.3 Painel de ingredientes e caixas

Cabeçalho 22 px "Toppings". Caixa 64 (celular/retrato) ou 72 (desktop): `CartoonPanel` Cream, raio `Chip`, ícone centrado 40/44, **chip de estoque** (14 px, Ink sobre Cream, canto sup. dir.).

| Estado da caixa | Visual |
|---|---|
| Normal | Cream, lip 4 |
| Hover / foco | anel Mustard 4 px, escala 1,05, tooltip com nome e estoque |
| Segurada / arrastando | caixa fica no lugar; **ghost** 56 px segue o dedo (deslocado 28 px acima), caixa escurece 15% |
| Já usada neste prato | afundada (lip 0), check Green no canto |
| Limite de 3 atingido | tracejado, ícone 50% |
| Sem estoque | Slate, risco diagonal, chip "0" |
| Bloqueada (dia futuro) | Slate + cadeado (`Notice/lock`) |
| Estoque baixo (<= 2) | chip vira **triângulo "!" Mustard** (não vermelho; o `StockCounter` atual usa vermelho: **não reutilizar** no foco) |

### 6.4 Next / Serve

132x52 (celular), 152x56 (desktop). Mustard quando habilitado, **Slate tracejado** quando não. Ícone: seta (Next) ou sino (Serve) + rótulo 20 px. Habilitado pela primeira vez no estágio: **pulso** (escala 1 > 1,05 > 1, 1,2 s, 3 vezes; movimento reduzido = sem pulso, só o anel Mustard fixo). Desabilitado, ao tocar: tremida de 6 px + dica "Cut the bun first" no cabeçalho da tábua.

### 6.5 Lixeira

56x56 (celular), 60x60 (desktop), círculo Cream, ícone de lixeira (fechada; abre ao arrastar algo por cima). Aparece com **pop** quando o prato tem algo; some quando vazio. Segurar 0,5 s: anel Green enche em volta; soltar antes cancela. Sem rótulo permanente (limpeza); o cabeçalho da tábua diz "Hold to trash" enquanto se segura. Ao descartar: poeira (5 partículas), som `prep_trash`, toast só se havia salsicha ("Plate trashed").

### 6.6 Status (passivo)

Pílula Ink (`Theme.Tone.Ink`, 32 px; 36 no desktop): moeda + `$128` à esquerda, **sol/lua** + `9:41 AM` à direita (o ícone sol/lua substitui o chip "Day N"; o dia continua legível no mundo e no resumo). Dinheiro ao ganhar: pulo 1,18 em 0,2 s (`Theme.Motion.Bump`). **Nada de dia, ordem, sanidade grande ou avisos** aqui. À noite, **tira de sanidade** de 10 px de altura embaixo da pílula (gradiente Gold > Violet de §7.2 do style guide, 2 marcas de entalhe em 50% e 25%; abaixo de 25% a tira balança 2 px, 1,2 s, sem som). Sem número.

### 6.7 Chips dos colegas (só co-op)

36x36, círculo Cream com o ícone da classe do colega (`Class/class_*`), **número da estação** (14 px) no canto e **miniatura da aba** em que ele está (Order/Grill/Build/Serve) num canto. Não tocáveis. Substituem as `StationTag` 3D dos vizinhos no foco (§13).

### 6.8 Toast

Um por vez, centro-inferior (§4), 32 px de altura, `Cream` + ícone (check Green ou triângulo Mustard), 16 px Ink, <= 36 caracteres, 1 linha. Entra 220 ms (sobe 12 px + fade), fica 2,2 s (3 s em recusa), sai 200 ms. Um novo **substitui** o atual (sem pilha). Nunca sobre a tábua nem o painel; em retrato ocupa o lugar dos chips.

### 6.9 Estados vazios e de espera (um padrão)

Painel Cream tracejado + **ghost** do objeto (cinza Ink 20%) + 1 linha de texto 16 px. Exemplos: "Waiting for the grill" (+ 3 pontos animados, estático com movimento reduzido), "Nothing to serve", "No ticket yet". Nenhum spinner girando.

---

## 7. Indicadores de nota (Perfect / Good / Messy)

Forma **e** cor **e** texto **e** ícone (daltonismo, §11). Nunca vermelho. Três tamanhos: mini (32, ao fim de cada gesto), pip (14, no cabeçalho) e selo do prato (120, ao fechar).

| Nota | Forma | Cor | Ícone | Texto | Efeito (Content.Prep.Grades) |
|---|---|---|---|---|---|
| **Perfect** | estrela-explosão de 12 pontas | Mustard `#F6C12B` > `#FFDA5C`, contorno Ink 4 px, brilho Gold curto | estrela | "Perfect!" | gorjeta $2 e janela +4 s |
| **Good** | círculo | Teal claro `#63C8D4`, contorno Ink 4 px | check | "Good" | como hoje |
| **Messy** | mancha ondulada (borda irregular) | Slate `#A9AEBF`, contorno Ink 4 px | til/rabisco | "Messy" | sem gorjeta, humor -1 faixa |

- Texto Ink 30 px com contorno Cream 3 px dentro do selo. Rotação -6 / 0 / +4 graus (cada selo tem a sua), pregado no canto do prato na aba Serve.
- **Pips do cabeçalho (Cut, Place, Top):** círculo vazio > ao fim do gesto vira a **forma** da nota (estrela, círculo-check, mancha) em 220 ms. O selo final do prato é a média: o jogador já viu cada parte.
- O selo mostra o **motivo** da pior etapa em uma linha quando Messy ("Sauce missed the bun") — texto do narrative-writer (Provisório).
- Selo de entrega (§5.4) é outro conjunto (Complete / Incomplete / Wrong); não se confunde com a nota porque tem **outra silhueta** (círculo+check / meio-círculo / quadrado+X) e vem escrito.

---

## 8. Feedback: partículas, pop e som

2D (Frames/ImageLabels), **<= 24 partículas simultâneas**, todas máscaras brancas tintáveis (`AST-115`). Sons em `Content.Sounds prep_*` (TASK-185/186); este quadro diz **quando** e **qual caráter**.

| Momento | Visual | Pop | Som (caráter) |
|---|---|---|---|
| Entrar / sair | câmera viaja; chrome entra em 250 ms (escala 0,92 > 1,03 > 1) | sim | whoosh macio curto |
| Trocar aba | crossfade 220 ms; aba nova sobe 3 px | aba | clique "plástico" |
| Pegar ticket (Take) | ticket desliza para a coluna esquerda e "gruda" (220 ms) | pino | estalo + papel |
| Pôr salsicha (Place) | puff Cream x4, slot pulsa | slot | tssss curto |
| Salsicha cozinhando | vapor leve, 1 partícula/s por slot | — | sizzle em loop baixo (só da aba Grill) |
| Janela de virar | anel Mustard + seta | slot | tique suave a cada 0,5 s (até virar) |
| Virar | giro 180 graus 200 ms + puff x4 + mini-selo | mini-selo | "fliip" + sizzle forte |
| Coletar | salsicha voa ao chip do trilho (220 ms) | chip | plink |
| Cortar o pão | migalhas Cream x6, linha preenche | pão abre | faca + abre |
| Encaixar a salsicha | squash 0,9 > 1,05 > 1 + faíscas x4 | prato | "thunk" macio |
| Molho | gotas da cor do molho x6 no fim do traço | medidor | esguicho em loop (pitch pela vazão) |
| Queijo / bacon / batata | queda + squash / anéis fechando / pitada x12 | prato | queda / tap / polvilhar |
| Mini-selo de etapa | burst (Perfect 10 estrelas, Good 4 faíscas, Messy 3 poeiras) | sim | sino / pop / boing baixo |
| Selo do prato | escala 0,4 > 1,15 > 1 em 250 ms, rotação | sim | acorde curto (Perfect) |
| Descartar | poeira x5, lixeira abre e fecha | lixeira | "tum" |
| Recusa / erro | tremida 3 x 6 px, 180 ms | — | `error` existente |
| +$ no status | pulo 1,18 | status | moeda |
| Saída forçada por anomalia | tremor curto da tela (4 px, 0,4 s) + chrome sai | — | sinal da anomalia (DEC-222) |

Háptico (se o aparelho suportar, opcional): 1 pulso curto no selo Perfect e na virada. **Sem screen shake** além do da saída forçada.

---

## 9. Animação

- **Duração:** 200 a 250 ms para entrar/sair/trocar; 120 ms para pressionar; 0,35 s só para a viagem da câmera (`Rules.Camera.Travel`).
- **Curvas:** entrar = `Quad` Out; sair = `Quad` In; pop com sobra = `Back` Out (sobra 8%, 250 ms; mola do kit `Motion.Pop` período 0,32 serve); pulso = seno suave; nada de `Bounce`, nada de linear exceto barras de progresso.
- **Uma coisa se mexe por vez** no fundo da tela; pulsos só no que é a próxima ação (Next habilitado, janela de virar).
- **Movimento reduzido** (`Rules`/configuração do jogador + preferência do sistema quando existir): sem viagem de câmera (corte instantâneo), sem pop com sobra (fade 120 ms), sem tremida (o contorno pisca 2 vezes, < 3 Hz), sem pulso (anel fixo), sem partículas (um brilho estático), sem balanço da tira de sanidade, sem pontos animados. **Informação nunca depende do movimento.**

---

## 10. Ordem de leitura e navegação

**Leitura (olho):** 1. barra superior (onde estou) > 2. cabeçalho/dica da tábua (o que fazer) > 3. ticket (o que pedem) > 4. tábua (fazer) > 5. painel (com o quê) > 6. Next (terminar) > 7. status (de relance).

**Foco de teclado/gamepad (mesma ordem):** Leave > abas > ticket > tábua (itens da aba) > painel (esq.-dir., cima-baixo) > Trash > Next. `Tab`/`Shift+Tab` percorre; setas/D-pad movem dentro do grupo; `Enter`/`A` ativa; `Esc`/`B`/`Q` = Leave; `LB/RB` ou `1-4` trocam de aba; `Y` = Next; D-pad esquerda/direita troca de ticket. Foco visível sempre (anel Mustard). Cada componente é `Selectable` (como `CartoonButton`).

**Toque:** arrasto fora da zona do joystick (que está escondido), cursor 28 px acima do dedo, **Assist** (+30% de tolerância) e **segurar** no lugar de arrastar disponíveis nas opções (obrigatórios na fase 1, DEC-223). **Mouse:** arrastar com o botão esquerdo, hover mostra tooltip após 300 ms.

---

## 11. Acessibilidade

- **Contraste:** todo texto >= 4,5:1 (§3.3); texto nunca sobre o 3D; contorno Ink 3 px em todo componente (limite de 3:1 contra qualquer fundo).
- **Daltonismo:** nenhuma informação só por matiz. Nota = forma+texto+ícone; janela de virar = colchete; bloqueado = cadeado; pouco estoque = triângulo; selecionado = marca + contorno; match = check + elevação. O mockup tem o botão "Escala de cinza" para conferir; deve continuar legível. Vermelho-verde: o Green de "pronto" sempre vem com check; Teal x Mustard diferem em luminância (0,32 x 0,58).
- **Movimento reduzido:** §9.
- **Alvos:** >= 44 px; vão >= 6 px entre alvos; alvo de gesto sem precisão pixel (Assist +30%).
- **Texto:** >= 14 px de UI, sem texto só em ícone para ação destrutiva (lixeira tem dica ao segurar).
- **Tempo:** o foco **não pausa** a paciência do cliente (regra de design); em compensação "Come again?" e a lixeira são escolhas, não armadilhas, e a salsicha não queima.
- **Esquerdistas (opcional, P2):** espelhar painel/ticket (`Rules.MirrorLayout`); tudo é âncora, nada fixo em x.
- **Áudio como legenda:** todo som tem equivalente visual (selo, mini-selo, anel); nenhum som carrega informação única.

---

## 12. O que fica FORA da tela (para não poluir)

| Sai em foco | Por quê / onde fica |
|---|---|
| `HudOrder` (cartão do pedido) | substituído pelo ticket |
| Pílula **Day N** | o sol/lua do status basta; o dia aparece no resumo |
| Pílula de dinheiro grande | fundida no status compacto (topo direito) |
| `HudSanity` padrão (barra com ícone e letra) | vira a **tira de 10 px** sob o status (só noite) |
| `InteractionMenu` / prompts do mundo | `AddGate` fecha; só `Work` por estação, Mart, telefone etc. existem fora do foco |
| `TutorialPanel` (topo central) | **colide com a barra superior**: no foco o `PrepCoach` usa a **dica do cabeçalho da tábua** + anel Mustard no alvo; "Skip tutorial" vira link de 44 px no centro-baixo (onde ficaria o toast; um some quando o outro aparece) |
| Hotbar nativa e `PlayerList` | escondidos em foco (o hot dog pronto vai ao hotbar no Finish, mas a Serve mostra "seu prato" e escolhe a Tool sozinha) |
| Joystick e botão de pulo (toque) | escondidos em foco |
| Chat | recolhido (desktop) |
| Balões 3D (pedido, reação, patience, `SaleSign`, `TableSign`) e `CookInterface` | ocultos em foco (`Enabled = false`, só local); o ticket e os slots mostram o mesmo |
| `StationTag` 3D dos vizinhos | viram os chips de colegas (§6.7) |
| Dica de mira, setas do tutorial no mundo | sem mira em foco |

**Toasts** só do bloco "toast" (§6.8): centro-inferior, 1 por vez; nunca em cima da tábua nem do painel. Tudo o que hoje vira toast de status (loja abrindo, estoque do Mart) entra **em fila de 1** e só se a mensagem ainda for verdade quando chegar a vez.

---

## 13. Câmera e cena: regras para NÃO haver sobreposição

Fonte dos números: `Content.Prep.Rules.Camera` (`Fov 55`, `Distance 2.5`, `Pitch -55`, `Travel 0.35`, `Leave 0.30`) e `prep-mode.md` §6 (`Station_n` com `Att_Stand`, `CamAnchor`, `Focus`). Tudo **Provisório**; o level-designer (P4) valida em Play.

### 13.1 Princípio

A tábua é **2D** (`PlateView`); o 3D do trailer é **cenário desfocado** atrás dela, mostrando o resultado pelos registros `board`/`rail`. Logo, o que pode "tampar" é: (1) o **rig do próprio jogador** passando pela câmera, (2) **NPCs e outros jogadores** que entrem no quadro, (3) **billboards** (balões, barras, tags) desenhados por cima do 3D. Os três têm regra.

### 13.2 Pose de câmera por estação

Para cada `Station_n` (n = 1..4), com `F = Focus.Position` (centro do prato, na superfície da bancada) e `D = 2,5`, `pitch = -55 graus`:

```
CamAnchor.Position = F + (0, D * sin(55 graus), D * cos(55 graus)) em espaco local da estacao
                   = F + (0, +2,05, +1,43)        -- "+Z local" = lado do jogador, 1,43 stud para tras de F
CamAnchor.CFrame   = CFrame.lookAt(CamAnchor.Position, F)   -- yaw = o da bancada (olha de frente para a parede/janela)
FieldOfView        = 55 (vertical)
```

Com a bancada a 3,5 studs do chão (trailer): a câmera fica a **5,55** do chão e **1,43 stud à frente** do jogador. Quadro visível no plano do prato: **2,6 x 4,6 studs** em 16:9 (x 5,6 em 844x390). Consequências usadas nas regras:

- A câmera está **acima e à frente** da cabeça do jogador em `Att_Stand` (olho 4,5; `Att_Stand` ~1,8 stud atrás de `F`): a cabeça fica a **~1,1 stud** da câmera, dentro do raio da cabeça grande da crew (~0,7) + plano próximo. **Sem esconder o rig, a cabeça corta a parte de baixo do quadro.**
- Atrás da bancada, o topo do quadro (-27,5 graus) cruza a altura 3,5 a ~2,5 studs além de `F`. Cabeça e tronco de um cliente **a menos de ~2,5 studs da parede da janela** entram no alto do quadro.
- Vizinhos: com `Focus` espaçados **>= 3,5 studs** entre si, o prato do vizinho fica fora do quadro (meia largura 2,3). Quem está em `Att_Stand` ao lado fica **atrás do plano da câmera**, fora do quadro, mas os braços esticados podem entrar.
- Em retrato o quadro 3D tem ~1,2 stud de largura: é só pano de fundo.

Pedido ao level-designer (P4): `Focus` das 4 estações **a >= 3,5 studs** uma da outra; `CamAnchor` **dentro** do trailer (nunca atravessando a parede); janela da bancada sem objeto alto (placa, luz) entre `CamAnchor` e `F`.

**Deslocamento na tela** (opcional, sem mudar o CFrame): centro 3D deslocado 12% à esquerda em paisagem (para a tábua cair sobre o miolo do 3D) e 8% para cima em retrato.

### 13.3 Rig do jogador

- **Escondido por inteiro** durante o foco, **só localmente**: `LocalTransparencyModifier = 1` em todas as partes (corpo, cabeça, orelhas, cauda, acessórios, `Handle` de Tool), com fade de **0,15 s** no início da viagem e de volta a **60%** da viagem de saída. Não mexer em `Transparency` (replicada e usada por anomalias/animações).
- Motivo: a cabeça fica a ~1,1 stud da câmera (§13.2); mostrar só "mãos" exigiria viewmodel (DEC-219 proíbe animação extra de viewmodel) e a tábua 2D já faz o papel das mãos.
- **Outros jogadores veem o rig normal** em `Att_Stand` com o clipe `work` (DEC-220).

### 13.4 NPCs (clientes na fila e sentados)

Avaliado a **10 Hz** no cliente, só para os <= 12 NPCs (DEC-045). Referência: o **segmento S** de `CamAnchor` até `F + 8 studs` no sentido da câmera para a janela (cobre quem está depois da janela). Distância `d` = do `HumanoidRootPart` do NPC a `S`:

| Zona | Condição | Efeito local | Fade |
|---|---|---|---|
| **Corte** | `d <= 2,5` studs, **ou** dentro da caixa da janela da estação (5 x 6 x 4, do lado de fora) | `LocalTransparencyModifier = 1` (some) | 0,15 s |
| **Fantasma** | `2,5 < d <= 4,5` | `0,75` (silhueta fraca, não tampa) | 0,15 s |
| **Normal** | `d > 4,5` | `0` | 0,15 s |

Histerese de 0,4 stud (não pisca). Vale para **todas** as partes e acessórios, e para o texto de cima: no corte, `Humanoid.DisplayDistanceType = None`. Clientes **sentados nas mesas** (> 6 studs) ficam na zona normal e **só desfocados** (DOF).

Compatibilidade com anomalias: o corte é local e só dentro do quadro; a anomalia continua sendo percebida **fora** do foco e pela saída forçada (DEC-222); esconder um NPC no corte **não** conta como "ver". Nada brilha nem aponta o alvo.

### 13.5 Outros jogadores em estações vizinhas

- Rig vizinho **dentro de 5 studs da câmera**: corte total (some). Fora disso: regra de NPC (fantasma/normal).
- A presença deles aparece como **chip pequeno** (36 px, §6.7) no canto esquerdo sob o ticket, com a estação e a aba. Nunca um avatar 3D sobre a tábua.

### 13.6 Fila de clientes

No foco a fila **só existe como ticket + contador "+N"** (e a aba Order). Nenhum cliente 3D com balão aparece no quadro, nem barra de paciência 3D, nem `OrderBubble`. Ao sair do foco, tudo volta em 0,2 s.

### 13.7 DOF, vinheta e luz

| Qualidade gráfica | Fundo |
|---|---|
| > 3 | `DepthOfFieldEffect`: `FocusDistance = D` (2,5), `InFocusRadius = 0,4`, `NearIntensity = 0`, `FarIntensity = 0,7`; desligado ao sair |
| <= 3 | sem DOF; **vinheta Ink 35%** (gradiente de 120 px nas 4 bordas) e a mesa Cream da tábua opaca |

Sem mudar `Lighting`; sem bloom novo; nada de `Blur` grande (style guide §10). À noite a tábua continua clara (Cream): é a "ilha de luz" do foco.

### 13.8 Ordem de eventos (entrar e sair)

Entrar: `Frozen` > fade do rig (0,15 s) > viagem da câmera (0,35 s) > gate de prompts/billboards > chrome em pop (250 ms). Sair: chrome sai (200 ms) > câmera volta (0,30 s) > rig reaparece a 60% > billboards e prompts voltam. **Saída forçada por anomalia**: 0,4 s total, tremor curto, chrome some junto, 0,5 s sem input. Nenhum passo é pulado em movimento reduzido (só vira instantâneo).

---

## 14. Revisão crítica da UI atual (o que o modo focado deve evitar)

Evidência: código (`src/Hud/client/HudController.luau`, `Components/InteractionMenu`, `Components/TutorialPanel`, `Components/Theme`) e registros do dia. **Não vi screenshots** (não estão no repositório): os itens sobre o Pad/lobby são **não verificados**.

| # | Problema | Evidência | Gravidade | O modo focado |
|---|---|---|---|---|
| 1 | **Coluna de HUD no topo esquerdo empilha 3 coisas** (sanidade, cartão de pedido, pílulas), com alturas por constante (`SANITY_ROW_COMPACT 38`, `SANITY_ROW_LARGE 50`, `UNDER_PILL_COLUMN 88`) e "estreito" = `NARROW_WIDTH 560` que muda tudo de lugar | `HudController` linhas 89 a 101, `OrderPosition` | Alta (poluição, layout instável) | uma única zona topo-direita e um único ticket; nada empilhado |
| 2 | **Cluster do Roblox (menu + chat) ocupa ~270 x 60 px** e o HUD já precisa de `TOPBAR_REAL = 60` para fugir dele | `HudController.TopBar` | Média | barra superior centrada, status à direita |
| 3 | **Menu de interação por toque** (círculo 64 + leque de raio 108 a partir de 28/112 px do canto inferior direito) ocupa exatamente onde o Next e o painel moram | `InteractionMenu` cabeçalho; style guide §7.2.1 | Alta se coexistirem | prompts do mundo fechados por `AddGate` em foco; o leque nunca aparece em foco |
| 4 | **Painel do tutorial** no topo centro, 50 px abaixo, largura 50% (260..440) = colide com a barra de abas | `TutorialPanel` (`Position` padrão) | Alta | dica no cabeçalho da tábua + anel; "Skip" separado |
| 5 | **Vermelho em estados de UI** em 11 componentes (`Theme.Color.Low`, `NoCash`, `Tone.Ketchup`: `StockCounter`, `PatienceBar`, `BenchCard`, `ShelfTag`, `GearTag`, `StockPlate`, `TableSign`, `CrewCard`, `ShowcasePanel`, `CallSubtitle`, `LoadingScreen`) | grep em `src/` | Média (viola o "sem vermelho de alerta") | no foco: variantes sem vermelho (Mustard + triângulo); pedir `Tone`/prop `Calm` aos componentes compartilhados, **sem alterar** os usos fora do foco |
| 6 | **Hotbar nativa e controles de toque do Roblox** continuam por cima enquanto o jogador está congelado | `README`/prep-mode §5 só cita `Frozen` | Alta no celular | esconder `Backpack`, `PlayerList`, `TouchGui`; verificar em Play |
| 7 | **Pílulas Ink translúcidas** demais para um modo de "trabalho": leem como camada de debug sobre o 3D | `Theme.Tone.Ink` + `Transparency.Panel 0.06` | Média | só o status usa Ink; resto Cream/Mustard opaco |
| 8 | **Toasts empilhados** (`MAX_VISIBLE 3`, `TOAST_DURATION 4`) | `HudController` linhas 79 a 82 | Média | 1 por vez, centro-inferior, 2,2 s |
| 9 | **Texto menor que 14 px** ainda previsto na sanidade compacta (11 px) | `board.md` TASK-174/175 | Média | proibido no foco; texto >= 14 |
| 10 | **Balões 3D** (OrderBubble, reação, paciência) competem com qualquer UI 2D sobre o mesmo quadro | `Components/OrderBubble`, `ReactionBubble`, `PatienceBar` | Média | ocultos em foco; o ticket os substitui |
| 11 | **Chat do Roblox** (desktop) ocupa ~30% x 25% do canto superior esquerdo, onde o ticket mora | padrão do `TextChatService` (não verificado no jogo) | Média | recolher em foco (`ChatWindowConfiguration.Enabled = false`, **verificar em Play**); se não der, ticket em y = 252 (§4.2) |
| 12 | **Pads do lobby / `LobbyWindow`:** pads de squad ainda brancos (item 54 do dia), capacidade por pad e sala em dois estágios em andamento (itens 46 e 53); billboards sobre pads com texto grande | `playtest-2026-10-12.md` | Baixa para o foco (outro contexto) | **não verificado visualmente**; registrar para a revisão do lobby: não reusar `PromptBillboard` nem texto 3D em foco |
| 13 | **Doc discorda de si mesmo:** `prep-mode.md` §2 põe Leave "abaixo da pilha de HUD de dinheiro/dia" e §5 mantém a sanidade no topo esquerdo; isto colide com o ticket e a zona do Roblox | `prep-mode.md` §2 e §5 | Média | este spec **emenda** (Leave na barra; status topo direito; sanidade em tira); precisa do ok do architect/dono |

---

## 15. Sprites e ícones a produzir (AST-108 a AST-119)

Fichas completas em `docs/art/asset-list.md` (seção "Modo de preparo: sprites 2D (TASK-187)"). **Todas Rascunho** (só vão à fila do modeler-3d com status Aprovado do dono). Reaproveita sem produzir de novo: `Ingredient/*` (8), `Item/hot_dog`, `Hud/coin|sun|moon`, `Reaction/star`, `Notice/lock`, `Class/*` do AST-071 (54 ícones, DEC-217).

| ID | O quê | Tamanho | Prioridade | TASK |
|---|---|---|---|---|
| AST-108 | Glifos de comando: 4 abas, Leave, Next, Serve (sino), lixeira (fechada/aberta), virar, aviso "!" | 128 (exibe 28-40) | P0 | 187 > 188 > 189 |
| AST-109 | Salsicha em 4 estados (crua, a meio, pronta, fantasma) + versão horizontal para os slots | 128 e 256x96 | P0 | idem |
| AST-110 | Pão: fechado, aberto, com guia de corte tracejada, mat Cream | 128 e 256x96 | P0 | idem |
| AST-111 | Complementos vistos de cima sobre o prato (3 molhos tintáveis, queijo, bacon, batata) | 256x96 | P0 | idem |
| AST-112 | Ticket: papel 9-slice rasgado, pino, anel de paciência (máscara), pilha "+N" | 9-slice 96x96, anel 64 | P0 | idem |
| AST-113 | Selos de nota: Perfect, Good, Messy + mini-selos e pips | 256, 64, 32 | P0 | idem |
| AST-114 | Cursores de gesto: faca, garrafa (bico), mão que pega, pitada, marcador do dedo | 64 | P1 | idem |
| AST-115 | Partículas 2D de UI: migalha, gota, estrela, poeira, brilho, ponto | 64, brancas | P1 | idem |
| AST-116 | Tábua e grelha em vista de cima: mat Cream 9-slice, rolos 4x2, trilho | 9-slice 128 | P1 | idem |
| AST-117 | Retratos de cliente (animais) para ticket e Serve; placeholder = círculo + inicial | 64 por espécie | P1 | idem; lista depende de `Q-149` |
| AST-118 | Selos de entrega: Complete, Incomplete, Wrong + "+$" | 128 | P1 | idem |
| AST-119 | Vinheta do foco (fallback sem DOF) e entalhe de aba | 512x128 9-slice | P2 | idem |

Entrega: duas folhas (**Prep_Icons** 1024², células 128; **Prep_Board** 1024x512), **<= 6 MB** decodificados no total (cabe em 24 MB de §9.2 com o resto), gerar por `tools/icons/` como o AST-071; nomes `Prep/<grupo>/<nome>`; `Content.Prep.Art` recebe os ids (TASK-189). **O jogo roda inteiro com placeholders** (Frames Mustard/Cream/Ink); 188 e 189 nunca bloqueiam as ondas de código.

---

## 16. Checklist visual de aceite e pendências

### 16.1 Checklist para TASK-174/175 e para o QA visual

1. Os 5 persistentes (§2.1) e mais nenhum; contexto aparece/some em 220 ms.
2. Tabelas de retângulos (§4): **0 sobreposições** nos 3 viewports e em 667x375; conferir com `DeviceSafeInsets` simulado (lateral 47, base 24).
3. Alvos >= 44 px, texto >= 14 px, nenhum vermelho de estado, **nenhum Mustard sólido além de 2 áreas**.
4. Texto de pior caso sem corte: "Potato Sticks", "$9,999", "Come again?", cliente com nome de 16 caracteres, ticket com 2 linhas.
5. Escala de cinza: todas as informações de nota/estado ainda legíveis (forma + texto).
6. Movimento reduzido: nada anima além de fade de 120 ms; câmera instantânea.
7. Rig do jogador, NPCs e vizinhos **nunca** aparecem sobre a tábua (testar com 4 jogadores e 12 NPCs; cliente colado na janela).
8. Toast: 1 por vez; não cobre tábua nem painel; some em 2,2 s.
9. Saída forçada: chrome some em <= 0,4 s, sem fantasma de UI.
10. Controles de toque, hotbar, `PlayerList` e chat do Roblox escondidos em foco (verificação em Play).

### 16.2 Pendências (para o secretário numerar; nenhuma bloqueia)

| # | Pergunta | Recomendação (Provisória) |
|---|---|---|
| UI-1 | Emendar `prep-mode.md` §2/§5: Leave na barra superior, status compacto topo direito (dinheiro + relógio), sanidade em tira de 10 px, sem pílula "Day"? | Sim |
| UI-2 | Esconder hotbar, `PlayerList`, controles de toque e recolher o chat durante o foco? | Sim; se algum não puder, o spec tem posições de reserva |
| UI-3 | Diálogo do cliente ("Got it" / "Come again?") no V1 ou depois? (já é `Q-227` sugerida) | Depois, atrás de flag; o layout acima já reserva |
| UI-4 | Painel de ingredientes **só na aba Build** (nas outras abas some) | Sim (menos poluição); caixa de salsicha = slot "+" |
| UI-5 | Lixeira por **segurar 0,5 s / soltar em cima**, não por toque | Sim (evita perder ingredientes) |
| UI-6 | Sprites: aprovar AST-108 a AST-113 (P0) para o modeler-3d renderizar | Aprovar o lote P0; P1/P2 depois |
| UI-7 | Espelhar layout para canhotos (P2) | Adiar |

### 16.3 Como ver

Abrir `docs/art/mockups/prep-ui.html` no navegador (duplo clique; funciona offline, a fonte Fredoka vem do Google Fonts se houver rede, senão cai em fonte arredondada do sistema). Controles no topo: aba (Order, Grill, Build, Serve ou teclas 1 a 4), dispositivo (desktop 1280x720, celular paisagem 844x390, retrato 390x844), fundo dia/noite, diálogo do cliente (variante), medidas (mostra zonas reservadas e margens), escala de cinza (daltonismo) e movimento reduzido. É um **mock estático** (HTML/CSS + SVG simples), não a arte final.
