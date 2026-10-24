# Visão

Status: Rascunho

Fontes primárias: `docs/source/gdd-v1-usuario.md` (GDD V1 do usuário; `§N` = seção) e `docs/source/respostas-2026-10-08.md` (rodada 1, DEC-012 a DEC-029; rodada 2, DEC-030 a DEC-038; rodada 3, DEC-039 a DEC-043; rodada 4, DEC-044 a DEC-056 — aprovação de `design/proposals-round-1.md`; rodada 5, DEC-057 a DEC-066; rodada 6, DEC-067 a DEC-072 — reconexão e aprovação de `design/proposals-round-2.md`; rodada 7, DEC-073 a DEC-079 — anomalias, final, ligações, cutscenes, Opal; rodada 8, DEC-080 a DEC-085 — snapshot de 15 min, sem XP, dinheiro sem uso, anti-AFK, Day 100 acumulado, desconectado; rodada 9, DEC-086 a DEC-091 — trailer na esquina, trânsito andando, cutscene POV compartilhada, NPCs R6, celular-alvo adiado, queda com ambulância e reviver pago; rodada 10, DEC-092 a DEC-099 — reviver por Robux, spectate até o fim da run, janela de 10 s, atropelamento com ragdoll, prefixo `ANM-###`, sem braços e jogador R6, membro atrasado entra depois, Opal confirmada; rodada 11, DEC-100 a DEC-105 — item de reviver no Mart e na hotbar, bancada de upgrades com oferta por turno, noite perdida após 10 s, atropelamento derruba item, gemas salvas por evento, estilo toy low-poly; rodada 12, DEC-106 a DEC-109 — básicos sempre à venda na bancada, trailer fora da rotação, item de reviver com dinheiro da party, frutas/verduras só cenário; rodada 13, DEC-110 e DEC-111 — chances do chefe = 1 por run, todos voltam na noite repetida; rodada 14, DEC-112 e DEC-113 — confirmações: chance por run inteira, espectador só volta na noite repetida; rodada 15, DEC-114 a DEC-129 — médicos descem na ida, reviver até 6:00 AM e só para si, crédito de reviver, janela congela na compra, retomada após queda do servidor, semáforo, preço pela party do fim do Day 1, acorda ao lado do trailer, zumbido do Walker, telefone fixo, cafeteira fixa, style guide aprovado, noite 20 → 30 min, fora do MVP (eventos, validade, missões), 2 revives por noite e Revive Kit; rodada 16, DEC-130 — semáforo removido, revoga DEC-120; rodada 17, DEC-131 e DEC-132 — rota até o Mart cruza a rua, postes da Juniper a 8 studs e Walker a ~135).
Números citados aqui são valores iniciais ajustáveis em playtest (DEC-044). Vale o **cenário L** (run longa) **[DEC-057]**; o cenário C foi descartado.
Itens marcados **[DEC-###]** já são decisão do usuário. O resto é rascunho derivado do GDD V1 e ainda precisa de aprovação.
Lacunas: ver `Q-###` citadas em cada seção (`docs/open-questions.md`).

---

> **Decisões do dono de 2026-10-12 (DEC-223, DEC-224, DEC-225), a ler antes do resto deste documento:**
> - **DEC-224:** o **Food Trailer é o veículo único desde o Day 1**; o **carrinho saiu** da run; **sem compra do trailer** (sem preço $300 × party, sem "5º dia", sem placa FOR SALE, sem troca de veículo). Onde este documento diz "carrinho", "comprar o trailer", "trailer a partir do 5º dia", "modo dia infinito" ou "§12 upgrade ou trailer?", vale o histórico marcado: lê-se **trailer desde o início** (o modo dia infinito já saiu por `Q-207`). A motivação 2 do §2 ("comprar o trailer") deixa de ser meta; a ficção segue: o chefe liga e pede o **turno da noite**.
> - **DEC-223:** o preparo do hot dog vira o **modo de preparo focado (FEAT-039, V1)**, 100% focado, com abas de estação; substitui o preparo por prompts no mundo.
> - **DEC-225:** a cutscene de abertura é **curta** e começa na calçada em frente ao trailer, sem carros.
> Nada disto torna o documento **Aprovado**.

## 1. Pitch

**Sell Hotdogs!** — jogo de Roblox de progressão e gerenciamento de um negócio de hot dogs que vira, aos poucos, uma experiência de anomalias e terror. (§1)

- Começa como desempregado sem dinheiro. (§1)
- Cutscene: vê um panfleto de vaga num poste, liga e é contratado para cuidar de um carrinho de hot dog. **[DEC-021]**
- É **funcionário** do chefe. O carrinho fica fixo numa esquina. **[DEC-019, DEC-020]**
- Compra ingredientes, prepara por estações, atende, ganha dinheiro, desbloqueia ingredientes, melhora equipamento. (§1) **[DEC-016, DEC-017]**
- Compra o **Food Trailer** (dinheiro do chefe, na ficção). O chefe liga pedindo que cubra o **turno da noite**. **[DEC-007, DEC-019, DEC-024]**
- Mesma cidade, mesmo trabalho. Mas agora há coisas que não deveriam estar ali. (§1)
- **10 noites**, cada uma com uma anomalia nova somada às anteriores (10 anomalias, `story/anomalies.md`). Na 10ª noite, **final com revelação**: "The Light on the Corner" — ao amanhecer, o chefe Walt aparece em pessoa pela única vez. **[DEC-025, DEC-027, DEC-060, DEC-065, DEC-073, DEC-075, DEC-076]**
- Até 4 amigos jogam juntos numa party, **um carrinho só**, dinheiro e progressão da party. Solo permitido. **[DEC-012, DEC-032, DEC-033, DEC-034, DEC-059]**
- Cada partida é uma **run longa** (~6 h) sem save entre runs; quem sai pode **reconectar** enquanto ao menos 1 jogador da party seguir na partida; se todos saem, a run fica guardada **15 min** (retoma no início do turno) e depois acaba. **[DEC-035, DEC-057, DEC-063, DEC-067, DEC-080]**
- Entre runs ficam só **gemas** (ganhas por turno, noite e final), usadas para comprar **classes** leves com contrapeso (vantagem até ±12%, nunca nas regras do terror). **[DEC-061, DEC-069, DEC-070]**

## 2. North Star  **[DEC-003]**

> "Estou construindo uma vida melhor vendendo hot dogs... mas alguma coisa está muito errada aqui." (§24)

Motivação do jogador ao longo do jogo (§24):

1. ganhar dinheiro;
2. comprar o trailer;
3. entender as anomalias;
4. terminar o turno e descobrir o que realmente está acontecendo.

## 3. Fantasia e arco do jogador (§2)

| Etapa | Fantasia | Papel |
|---|---|---|
| 1 | "Eu preciso arrumar um emprego." | Desempregado → Funcionário |
| 2 | "Meu carrinho está crescendo." | Funcionário → responsável pelo Trailer |
| 3 | "Eu preciso sobreviver ao meu turno." | Trabalhador Noturno → Sobrevivente |

Mudança gradual. **[DEC-019]**: o jogador é sempre funcionário, nunca dono. A etapa 2 do GDD V1
("Eu tenho meu próprio negócio" / "Dono de Trailer") foi reescrita aqui como rascunho; a frase final
precisa de aprovação.

## 4. Identidade e tom  **[DEC-009]**

- Identidade: **Cute / Casual / Satisfying / Progression / Mystery / Horror**. (§22)
- Apresentação inicial propositalmente inocente. (§22)
- Horror não depende de jumpscare. Tensão vem de "sei que algo está errado, mas não sei o quê". **[DEC-005]** (§17)
- Jumpscare só **pontual e leve**: raro, só como efeito de sanidade baixa ou de anomalia, sem gore. **[DEC-173]**
- Jogo começa sem revelar o sobrenatural. História é descoberta, não explicada. **[DEC-008]** (§8)

Hábitos que o jogador deve desenvolver (§17): olhar clientes, observar ambiente, lembrar regras, verificar horários, conferir ingredientes, ouvir sons, verificar o trailer.

## 5. Público e plataformas

| Item | Valor | Origem |
|---|---|---|
| Plataforma | Roblox | §1 |
| Dispositivos alvo | **mobile primeiro** + **PC suportado**; console sem teste dedicado no MVP. Celular de referência e otimização para aparelho mínimo **adiados** ("otimizamos depois") | **[DEC-014, DEC-090, DEC-171]**, `Q-074` |
| Personagens e estilo | **NPCs e jogadores com rig R6**; sem braços em 1ª pessoa, câmera 1ª pessoa padrão do Roblox. Estilo visual **"toy low-poly"**; `art/style-guide.md` **Aprovado**: iluminação Future com fallback ShadowMap, roupa de NPC por cor por parte do corpo | **[DEC-089, DEC-097, DEC-105, DEC-126]** |
| Público | **infantojuvenil, sem violência** | **[DEC-023]** |
| Classificação Roblox | **Mild** (sustos leves, sem violência) | **[DEC-172]** |
| Nome oficial | **"Sell Hotdogs!"** (com exclamação) | **[DEC-170]** |
| Idioma do jogo | **inglês** (sem localização) | **[DEC-022]** |
| Sessão | **lobby → party de até 4 (solo permitido) → servidor privado** | **[DEC-012, DEC-034]** |
| Party | **um carrinho**; dinheiro e progressão **da party** | **[DEC-032, DEC-033, DEC-059]** |
| Persistência | **sem save entre runs**; só gemas, classes desbloqueadas e contador do "Day 100" (por jogador). Estado da run fica **na memória do servidor**: quem sai pode **reconectar** enquanto ≥1 jogador da party seguir na partida; ninguém novo entra; sem líder dentro da run. **Snapshot** da run no MemoryStore no início de cada turno (TTL 15 min, mesmo roster): party inteira saiu → se alguém volta em 15 min, retoma no início do turno corrente; senão, run encerrada. Desconectado: relógio não pausa, não conta para "todos fora", só recebe a gema de um evento se estiver no servidor no instante do evento; mantém as gemas de eventos já ocorridos | **[DEC-035, DEC-063, DEC-067, DEC-080, DEC-084, DEC-085, DEC-104]**; técnica `Q-058` |
| Classes | **8 classes leves com contrapeso** (`CLS-001` a `CLS-008`), efeito pessoal, teto ±12% de lucro solo, nunca tocam regras de anomalia; escolha no lobby, travada na run. **MVP: Rookie (grátis), Runner, Line Cook, Night Owl** | **[DEC-061, DEC-069]** |
| Gemas | dia concluído 2 (+1 com nota A), só com **≥ 3 pedidos completos** da party no turno (anti-AFK) · noite N 15 + 2(N−1) · final +100 · "Day 100" +300 (badge), **100 dias de modo infinito somados entre sessões** · **creditadas e salvas no DataStore no instante de cada evento** (a tela de resumo só mostra), igual para a party presente no evento · classes custam 45 / 120 / 180 | **[DEC-058, DEC-070, DEC-083, DEC-084, DEC-104]** |
| Monetização | **reviver por Robux** (developer product, preço adiado `Q-098`); resto **adiado**; não bloqueia o MVP. Item raro de reviver vendido no Mart, pago com **dinheiro da party** (não é monetização) | **[DEC-062, DEC-092, DEC-100, DEC-108]**; `Q-017` |
| Perspectiva de câmera | **primeira pessoa travada**, sem zoom (risco mobile anotado) | **[DEC-013, DEC-039]** |
| Interação | **Tools nativas na hotbar nativa + prompt custom do AnimalPlane no mundo**; HUD só de status; hotbar com **até 4 Tools** | **[DEC-015, DEC-040, DEC-066, DEC-174]** |
| Referências | "Animal Hospital" (Roblox) — inspiração, não cópia; outras a definir | **[DEC-013]**, `Q-021` |

### 5.1 HUD **[DEC-015]**

| Elemento | Quando |
|---|---|
| Sanidade (nome provisório "Sanity"; `Q-054` arquivada) | **só à noite**, por jogador **[DEC-056]**. Baixa → sons, sustos, vultos, alucinações **[DEC-038]** |
| Horário atual | sempre; formato 12 h em inglês ("8:00 AM"), atualiza a cada 10 min do jogo, igual para a party **[DEC-048]** |
| Turno / noite atual | sempre |
| Dinheiro (da party) | sempre **[DEC-033]** |
| Faturamento do turno | tela de fim de turno, com **nota A–D** e bônus do chefe **[DEC-051]** |

Sem reputação no HUD **[DEC-051]**. Chances do chefe não aparecem no HUD (só na ligação e na tela de fim de noite) **[DEC-053]**.
Valor da gaveta do caixa aparece no mundo, sobre a gaveta **[DEC-050]**.
Notificação de **reconexão** a uma run em andamento no **canto superior direito** **[DEC-063]**. Desenho do HUD principal: rodada futura.

Sem botões de ação em tela. Feedback de preparo no mundo (barra de progresso sobre a salsicha).
Visual cartunizado, estilo **toy low-poly** **[DEC-105]**; reaproveita barra de progresso, **prompt custom** e VFX do projeto AnimalPlane **[DEC-029, DEC-066]** (`Q-045`).

## 6. Pilares  **[DEC-002]**

Pilares definitivos (§23). Todo conteúdo novo precisa servir a pelo menos um.

| # | Pilar | Frase | Subpilares |
|---|---|---|---|
| 1 | **VENDER** | Preparar e vender hot dogs. | receitas, clientes, pedidos, preparação, atendimento, eficiência |
| 2 | **PROGREDIR** | Construir uma carreira e um negócio. | dinheiro, upgrades, equipamentos, ingredientes, carrinhos, trailer, gemas/classes (~~XP, níveis~~: fora do MVP, **[DEC-081]**) |
| 3 | **GERENCIAR** | Tomar decisões sobre o negócio. | estoque, ingredientes, compras, capacidade, velocidade, economia, demanda |
| 4 | **OBSERVAR** | Identificar quando algo está errado. | padrões, comportamento dos NPCs, ambiente, regras, memória, percepção |
| 5 | **SOBREVIVER** | Lidar com as anomalias. | regras, decisões, consequências, risco, segurança, escalonamento |
| 6 | **DESCOBRIR** | Entender por que o turno da noite é diferente. | chefe, diálogos, acontecimentos, pistas, mistério, lore |

Nota: as §3–§10 do GDD V1 usam uma numeração antiga de 8 pilares (Trabalho e Venda, Progressão, Evolução do Negócio, Ciclo Dia/Noite, Anomalias, Descoberta, Chefe, Trailer). Vale a lista da §23. O conteúdo das §3–§10 é tratado como detalhamento.

## 7. Princípios de design (do GDD V1)

| Princípio | Origem | Status |
|---|---|---|
| Jogador fisicamente envolvido: precisa **fazer** hot dogs. Nada de tycoon passivo nem "clicar → número sobe". | §18 | **[DEC-004]** |
| Progressão muda **velocidade e capacidade** do jogador, não só números abstratos. Upgrades têm utilidade real. | §3.4, §11 | **[DEC-006]** |
| Upgrades do negócio podem virar ferramentas de sobrevivência à noite. | §11 | **[DEC-006]** |
| Receitas são progressão horizontal: mais coisas para vender, não só "mais forte". | §4.3 | Rascunho |
| ~~Dia confortável e previsível.~~ (sem dia: DEC-360) Noite = risco e anomalias, mas o jogador continua trabalhando. | §6 | **[DEC-010, DEC-360]** |
| Clientes normais repetitivos o bastante para criar padrão; anomalia é quebra de padrão. | §14 | **[DEC-010]** |
| Anomalias: observar → lembrar → decidir → agir. Escalonam de simples para múltiplas simultâneas. Nem toda anomalia mata. | §7 | **[DEC-010]** |
| Economia simples. Recursos principais: Money, Stock (e Gems entre runs). Sem reputação. Sem XP no MVP. | §12 | **[DEC-051, DEC-081]** |
| Dinheiro sem uso depois de comprar tudo (~Day 8 solo) é aceito no MVP. | — | **[DEC-082]** |
| Tensão econômica: "compro ingrediente ou guardo para o upgrade?"; "upgrade ou trailer?" | §12 | **[DEC-045, DEC-047]** |

## 8. Loop de jogo

### 8.1 Loop macro (carreira) — §15

**Vale (DEC-360, 2026-10-23, Aprovado pelo dono): a run é 100% noite e começa de noite.** Motivo do dono: "Os primeiros 90 segundos do jogador ali no jogo são muito importantes" (entrar e já ver anomalia).

```
LOBBY → PARTY (1–4) → RUN (restaurante, DEC-307):
NOITE 1 (ligação do Walt às 7 PM; tutorial dentro dela) → 6 AM resumo + lição de upgrade
→ NOITE 2 … NOITE 10 (cada uma: ligação 7 PM → compra 30 s → noite 8 PM–6 AM → resumo)
→ 10ª NOITE: FINAL → CRÉDITOS → FIM DE RUN (gemas) → LOBBY
   ↘ noite perdida = fim da run (`Chances = 0`, DEC-319)
```

- Sem turno de dia, sem Prep/Open/Last call de dia, sem ligação da manhã, sem modo dia infinito. **[DEC-360]**
- A única ligação do Walt por turno é a da noite (fase Call, 7 PM). **[DEC-360]**
- Final: hoje vale o A1 (DEC-075); o ending "O Segundo Café" está em teste pelo dono (`Q-480`, Provisório).
- Ganhos e desbloqueios que eram "de dia" (gemas de dia concluído, DEC-070; ingredientes por dia, DEC-071): a rever com o game-designer (Provisório: o contador `Day` do código sobe um por noite).

**Superado por DEC-360** (histórico; não vale mais, junto com DEC-224/DEC-307 para carrinho, trailer e Mart):

```
LOBBY → PARTY (1–4) → RUN:
CUTSCENE (ARRUMAR EMPREGO) → TURNOS DE DIA → VENDER HOT DOGS → GANHAR DINHEIRO → COMPRAR UPGRADES
→ DESBLOQUEAR INGREDIENTES → (5º DIA) COMPRAR TRAILER → DIA / NOITE ALTERNADOS (10 noites)
→ PERCEBER ANOMALIAS → SOBREVIVER → GANHAR MAIS → 10ª NOITE: FINAL COM REVELAÇÃO → GEMAS → CLASSES
                     ↘ (não comprou o trailer) MODO DIA INFINITO (sem fim; dá gemas; achievement secreto aos 100 dias)
```

- Introdução: cutscene. **[DEC-021]**
- Trailer disponível a partir do **5º dia**, visível no estacionamento desde o dia 1. Preço **$300 × party** (1p $300 · 2p $450 · 3p $570 · 4p $660; tamanho = quem entrou até o **fim do Day 1**, fixo depois disso, não lido na hora da compra). Compra por prompt, **fixa** (fora do sorteio da bancada do Mart); troca no fim do turno; próximo turno = noite 1. Se o jogador não compra, recebe notificação e pode jogar o dia indefinidamente. **[DEC-028, DEC-037, DEC-047, DEC-107, DEC-121]**
- Depois do trailer a noite é obrigatória; o chefe liga pedindo. Turnos **alternados** dia/noite. **[DEC-024, DEC-036]**
- Sem save entre runs; persistem gemas e classes. **[DEC-035]**
- Quem sai mantém o estado na partida e pode **reconectar**; notificação no canto superior direito. **[DEC-063]**
- Reconexão enquanto ≥1 jogador da party segue na partida; ninguém novo entra; sem líder na run. **[DEC-067]**
- Party inteira saiu: snapshot do início do turno fica **15 min** no MemoryStore; alguém do roster volta → retoma no início do turno corrente; ninguém volta → run encerrada. **[DEC-080]** (técnica `Q-058`)
- Desconectado: relógio não pausa; não conta para "todos fora"; recebe a gema de um evento só se estiver no servidor no instante do evento; mantém as de eventos já ocorridos. **[DEC-085, DEC-104]**
- Gemas creditadas e salvas **a cada evento**: sair da run (inclusive espectador) não perde gema já ganha. **[DEC-104]**
- Run acaba em falha quando acaba a **única chance do chefe** (2ª noite perdida); ficam as gemas já creditadas. **[DEC-053, DEC-110, DEC-112, DEC-070, DEC-104]** (por run inteira, confirmado)
- Run acaba com sucesso na **10ª noite**, com **final com revelação** (opção A1 de `story/ending.md`): cutscene do amanhecer com Walt em pessoa → créditos → pós-créditos → fim de run (+100 gemas) → lobby. **[DEC-065, DEC-070, DEC-075]**
- Cutscenes (abertura e final) **puláveis**; em party, pula com **50% dos votos**. **[DEC-078]** (detalhes `Q-077`)
- Cutscenes em **1ª pessoa**; em party a cena é **compartilhada** e cada jogador vê os avatares dos colegas. **[DEC-088]** (roteiro para 1–4 avatares: `Q-106`)
- Depois da compra, o trailer funciona **na esquina**, no lugar do carrinho. **[DEC-086]**
- Modo dia infinito **não acaba**, **dá gemas** (2 por dia, +1 com nota A, com ≥ 3 pedidos completos no turno), tem **achievement secreto aos 100 dias** (+300, badge), contando dias de modo infinito **somados entre sessões**, por jogador. **[DEC-058, DEC-070, DEC-083, DEC-084]**
- Parâmetros de run em tabela de dados **[DEC-044]**; vale o cenário **L** **[DEC-057]**:

| Cenário | Trailer | Noites | Noite | Chances | Run |
|---|---|---|---|---|---|
| **L (vale — DEC-057)** | dia 5, $300 × party (party contada no fim do Day 1, DEC-121) | 10 | crescente 20 → 30 min (DEC-127) | **1** (DEC-110; era 3) | ~6 h |
| ~~C~~ (descartado) | — | — | — | — | — |

- Membro da party que não chega ao servidor em 60 s: a run começa; ele spawna quando chegar. **[DEC-098]** Preços que usam o multiplicador de party contam quem entrou até o fim do Day 1. **[DEC-121]** (resto em `Q-112`)
- Retomada de 15 min vale também se o **servidor** cair. **[DEC-119]**

Pendências (nenhuma bloqueante): `Q-112` (membro atrasado: até quando entra, cutscene, voto), `Q-058` (técnica da reconexão e do snapshot), `Q-106` (cutscenes com party visível).

### 8.2 Loop de turno (dia) — §3, §6, DEC-016, DEC-017

> **Superado por DEC-360 (2026-10-23):** não existe mais turno de dia. O loop de venda (pedido, preparo, entrega, gorjeta) continua valendo **dentro da noite**; os horários e fases de dia abaixo são histórico.

0. Turno pelo relógio: preparação 7:00–8:00 AM (até 60 s, placa "OPEN" abre antes) → loja aberta 8:00 AM–6:00 PM (360 s) → fechamento "CLOSED" (até 30 s) → resumo (15 s). ~7,5 min. **[DEC-048]**
1. Garantir estoque: o estoque do carrinho é **reabastecido no mercado**; a estação só consome. Gestão de estoque é o mais importante. **[DEC-017, DEC-031]**
   - Mercado a 100–120 studs, com linha de visão para o carrinho; compra por **pacote físico** (Tool), máx. 2 por jogador, prompt "Restock" na estação. **[DEC-049]**
   - Interior do Mart: **prateleiras** (ingredientes), **área de frutas/verduras** (**só cenário** no MVP; cebola/pickles em atualização futura) e, **na parede do fundo, a bancada de upgrades**. **[DEC-101, DEC-109]**
   - Capacidade nível 1: salsicha 12, pão 12, queijo 8, bacon 8, ketchup 30, mostarda 30, Potato Sticks 15, Cream Cheese 12 usos; Cooler aumenta. Estoque passa entre dias; run começa cheia. **[DEC-049, DEC-046, DEC-071]** (Cream Cheese nos Coolers 2/3: `Q-062`)
2. Pedido: o cliente faz um **pedido aleatório** combinando ingredientes **desbloqueados**; o jogador monta. Sem cardápio, sem receitas fixas. **[DEC-064]**
   - Base sempre **pão + salsicha**; 0–3 complementos distintos, sem quantidade. Complementos: Ketchup e Mustard (dia 1), Cheese (dia 2), Bacon (dia 3), Potato Sticks (dia 4), Cream Cheese (dia 6); liberação automática com 1 pacote grátis. **[DEC-071]**
   - Nº de complementos K por fase (média 1,2 no dia 1 → 2,0 do dia 6 e à noite) + pesos por ingrediente. Pedido no balão sobre o cliente, com ícones. **[DEC-071]**
3. Preparar por estações **[DEC-016]**:
   1. Estoque de salsicha → salsicha vai sozinha para a grelha.
   2. Grelha (barra de progresso) → pronta → vai para a esteira de descanso (acumula).
   3. Pão → tábua → cortado.
   4. Esteira → salsicha no pão.
   5. Complementos (ketchup, mostarda, desbloqueáveis).
4. Atender: identificar pedido → montar (cada complemento = hold 1 s) → entregar → receber. (§3.3) Preço = **$4 + complementos** (molho $1, Cheese $2, Bacon $3, Potato Sticks $2, Cream Cheese $2). Paciência **40 + 5K s**; gorjeta +$1 se completo em até **16 + 4K s** (K = 1: 45 s e 20 s). Venda vai para a **gaveta do caixa**. **[DEC-050, DEC-071, DEC-072]**
5. Faltou ingrediente: entrega incompleta (falta complemento, nada a mais: **floor(50%)**, sem gorjeta, cliente reclama) ou corre ao mercado. **Errado** (complemento não pedido ou sem pão/salsicha) = $0; desistiu = $0. Dinheiro sempre inteiro. **[DEC-017, DEC-051, DEC-072]**
6. Ruas com **trânsito de carros andando** (MVP). Carro **atropela**: jogador é arremessado em **ragdoll**, fica um tempo no chão e volta a andar normal; tom pastelão, sem dano. Atropelamento **derruba o item da mão** e **não tira sanidade**. Rotas, quantidade e dia/noite em aberto. **[DEC-087, DEC-095, DEC-103]** (`Q-102`, `Q-122`)
7. Sair do carrinho tem risco: ladrão (só de dia, a partir do dia 2) espreita e, sem ninguém a 14 studs do carrinho, abre a gaveta (8 s) e leva 50%. Entrar na zona impede (+$5). Cash Drawer Lock: 16 s, 30%. **[DEC-018, DEC-050]**
8. Fim do turno: gaveta vai para o dinheiro da party; tela de faturamento com **nota A–D** (A +20%, B +10% de bônus do chefe). **[DEC-015, DEC-050, DEC-051]**
9. Gastar em upgrades e desbloqueios. (§6) Upgrades de referência: Grill, Cooler, Counter (3 níveis), Cash Drawer Lock, Trailer Lights. **[DEC-046]**
   - Upgrades são comprados na **bancada do fundo do Mart**. **[DEC-101]**
   - Upgrades **básicos sempre à venda** (Grill, Cooler, Counter, Cash Drawer Lock; Trailer Lights a partir da compra do trailer). Só itens **especiais** entram no **sorteio** que muda a cada turno novo; hoje o único especial é o item raro de reviver. **[DEC-100, DEC-106]**
   - Food Trailer **fora da rotação**: compra fixa a partir do dia 5. **[DEC-107]**
   - Cafeteira: **fixa no trailer**, não vendida na bancada; no Mart só o pacote de café. **[DEC-055, DEC-125]**
   - Especial: Revive Kit com **15% por turno** após o trailer, **$200 × party**. **[DEC-129]** Slots, pesos e uso: `Q-120`.

Economia de referência (valores iniciais, **[DEC-045]**): 1 cliente a cada 22 s no dia 1 (+8%/dia, teto +40%); party ×1,0/1,6/2,1/2,5; dinheiro inicial $30; teto de 12 NPCs simultâneos.
~~Preço por receita (Classic $5, Cheese $7, Bacon $8)~~ — revisto por **DEC-071**: preço por complemento (as três combinações antigas mantêm $5/$7/$8). Lucro esperado solo (Rookie): dia 1 $56 · dia 3 $82 · acumulado até o dia 5 $398 (`design/proposals-round-2.md` §3.7).

- Ingrediente **não estraga** no MVP. **[DEC-128]**
- ~~Travessia trailer ↔ Mart e cruzamentos com semáforo e faixa de pedestre~~ **[DEC-120, revogada]**. **Sem semáforo** no MVP: o jogador atravessa a rua por conta e risco e pode ser atropelado. **[DEC-130, DEC-095, DEC-103]** A rota trailer ↔ Mart **cruza a rua**: travessia no meio da quadra (CW-1), Juniper Sul aberta a carros; cada ida ao Mart arrisca atropelamento e o pacote cai. **[DEC-131]** Travessia: PARE nos dois braços da Juniper (Ninth preferencial); faixas CW-1..4 pintadas; NPC só cruza na faixa com reserva e os carros param para ele; **carro nunca para nem desvia por jogador**, nem na faixa; carro nasce a ≥ 55 studs da faixa (aviso ~2,5 s); Juniper Sul de dia com 1 carro a cada 12–20 s por sentido. **[DEC-133]**
- Postes da Juniper Norte a cada **8 studs**; o Walker começa sob o último poste, a **~135 studs** da janela do trailer (exceção ao "~110" do style guide). **[DEC-132, emenda DEC-126]**

Pendências: `Q-062` (capacidade do Cream Cheese nos Coolers 2/3).

### 8.3 Estrutura de uma noite — §16, DEC-024 a DEC-026

```
Ligação do chefe (regra nova) → Abrir trailer → Clientes normais → Pedidos → Primeiros sinais → Anomalias
→ Aumento de dificuldade → Últimos clientes → Encerramento → Pagamento → Gemas → Upgrade/Progressão
```

Nota: o GDD V1 (§16) tinha "→ XP →" nesta linha; XP saiu do MVP **[DEC-081]**.

- Duração **crescente**: N1→N10 = 20, 21, 22, 23, 24, 26, 27, 28, 29, 30 min reais (tabela ajustável) **[DEC-024, DEC-057, DEC-127]**. Relógio 8:00 PM → 6:00 AM **[DEC-048]**.
- Ligações do chefe tocam no **telefone fixo do veículo** (carrinho de dia, trailer à noite); celular flip só na cutscene de abertura. **[DEC-124]**
- Sinal de início do Walker (N7): o último poste da Juniper **zumbe ~2 s**. **[DEC-123]**
- **10 noites, 10 anomalias**, uma nova por noite. **[DEC-060]**
- Verbos do jogador: **atender, recusar, não olhar, luz, esconder, descartar, ponto seguro**. Cada anomalia tem um verbo correto. Tudo com o botão de interagir ou a câmera. **[DEC-054]**
- Ferramentas noturnas do MVP: **café** (cafeteira no trailer, +25, cooldown 60 s) e **Trailer Lights** (raio 18 studs sem escuro; de dia +10% fluxo). Lanterna fora do MVP. **[DEC-055]**
- Mercado aberto também à noite; o caminho passa pela rua escura. **[DEC-049, DEC-041]**
- Regras: o chefe liga e explica; o jogador memoriza. Noite N = anomalias das noites anteriores + 1 nova. **[DEC-025]**
- A ligação **não pode ser ouvida de novo** (sem replay, sem lista de regras). **[DEC-077]** O chefe só aparece por telefone durante a run. **[DEC-076]**
- As 10 anomalias **[DEC-073]**: N1 The blank folks (recusar) · N2 The wrong food (descartar) · N3 The stopped clock (luz) · N4 The copies (recusar a cópia) · N5 The Raincoat Lady (**atender**) · N6 The wavers (não olhar) · N7 The Walker (não olhar, **crítica**) · N8 The long car (esconder) · N9 The knock (esconder) · N10 The Hush (ponto seguro).
- **Regra crítica fixa: só N7 (The Walker)**; noites 1–6 sem regra crítica. **[DEC-074]**
- Opal, atendente do Mart, fica atrás do balcão dia e noite com falas curtas (não vende). **[DEC-079, confirmada em DEC-099]**
- IDs das anomalias: N1–N10 = **ANM-001 a ANM-010**. **[DEC-096]**
- Vitória: não cometer erros; cada anomalia tem um comportamento correto. **[DEC-026]**
- Sem violência: anomalias usam análogos não violentos. **[DEC-023]**
- Sanidade baixa → terror psicológico: sons, sustos, vultos, alucinações. Susto é consequência, não base do horror; jumpscare raro e leve. **[DEC-038, DEC-005, DEC-173]**

#### Sanidade (nome provisório "Sanity"; `Q-054` arquivada sem decisão)

| Regra | Valor | Origem |
|---|---|---|
| Cai quando | vê anomalia; quebra regra; fica no escuro | **[DEC-041]** |
| Recupera com | café | **[DEC-042]** |
| Baixa | sons, sustos, vultos, alucinações | **[DEC-038]** |
| Zerada | jogador **desmaia**, o corpo cai; **ambulância** chega, os **médicos descem e levam o corpo** (DEC-114). Pode **reviver** com **Robux**, só para si (DEC-116), ou com o **Revive Kit** (item raro do Mart, na hotbar, pago com **dinheiro da party**, 15% por turno, $200 × party; DEC-100, DEC-108, DEC-129): a ambulância volta, para em frente ao trailer, o jogador aparece ao lado e ela vai embora (**ninguém desce**). Prazo: até **6:00 AM** da noite da queda (DEC-115). Limite: **2 revives por jogador por noite**; na 3ª queda vira espectador na hora (DEC-129). Recibo de Robux sem alvo vira **crédito de reviver** no perfil (DEC-117). Se não revive: **spectate até o fim da run**, **exceto** se a party perder a noite e ela for repetida: aí **todos voltam**, inclusive espectadores de noites anteriores (DEC-111, DEC-113). ~~Banco do fundo do trailer~~ e ~~volta no próximo turno~~ (DEC-053) substituídos. Espectador pode sair sem perder gemas (DEC-104). Em aberto: preço em Robux `Q-098` (adiado), tempos `Q-107` | **[DEC-043, DEC-053, DEC-091, DEC-092, DEC-093, DEC-100, DEC-104, DEC-108, DEC-111, DEC-113 a DEC-117, DEC-129]** |
| Escopo | **só à noite**; **por jogador** | **[DEC-056]** |
| Números iniciais | início 100 · ver anomalia −5 (1 s no campo de visão, 1× por anomalia) · regra comum quebrada −35 · escuro −1/s (após 3 s) · café +25 | **[DEC-056, DEC-055]** |
| Por classe | Runner começa com 90; Night Owl começa e vai até 120; Barista perde −8 por anomalia vista e faz café de +35. Nenhuma classe muda o −35 | **[DEC-069]** |

#### Perder a noite **[DEC-053]**

| Regra | Valor |
|---|---|
| Noite perdida | todos da party fora ao mesmo tempo, **ou** alguém quebra a **regra crítica** (máx. 1 por noite, "whatever you do, never..."). Quando o último cai, **janela de 10 s** para reviver (o contador congela enquanto há compra de reviver aberta, até +20 s, DEC-118); senão a party **perde a noite** (gasta a chance), não a run **[DEC-094, DEC-102, DEC-118]** |
| Erro em regra comum | −35 de sanidade (3 erros tiram o jogador) |
| Chances do chefe | **1** por run inteira (era 3); 2ª noite perdida = fim da run **[DEC-110, DEC-112]** |
| Ao perder com chance | repete a mesma noite com o estado do início dela; perde o faturamento da noite. **Todos voltam a jogar**, inclusive espectadores de noites anteriores **[DEC-111, DEC-113]** |
| Espectador com noite vencida | **não** volta no dia seguinte; segue espectador até o fim da run. Só a noite repetida devolve **[DEC-093, DEC-113]** |
| Sem chances | fim da run; ficam as gemas já creditadas (noites vencidas e dias), sem extra **[DEC-070]** |
| Representação | luzes do trailer piscam e apagam, tela escurece, todos acordam **em pé ao lado do trailer** ao amanhecer (~~banco~~), chefe liga. Sem violência **[DEC-023, DEC-122]** |

Começa quase como turno normal, termina muito mais tensa.

Pendências: `Q-098`, `Q-107` (reviver: tempos), `Q-120` (item raro: slots, pesos, uso), `Q-122` (atropelamento: detalhes), `Q-115` (risco: noites 1–6 fáceis), `Q-104`/`Q-106` (ambulância: assets e roteiro), `Q-103` (N8 com trânsito).

### 8.4 Progressão do negócio — §5, **[DEC-052]**

MVP com **2 tiers**. O crescimento entre eles vem de **equipamentos**, cada um com peça visível no veículo (DEC-006).

| Tier | Nome (placeholder) | Resumo | MVP? |
|---|---|---|---|
| 1 | "Boss's Cart" | dado pelo chefe; cresce com upgrades | **sim** [DEC-052] |
| — | Carrinho Velho / Improved Cart (§5) | tiers intermediários | **não** [DEC-052] |
| 2 | "Food Trailer" | comprado no dia 5; abre a noite | **sim** [DEC-007, DEC-052] |
| 5+ | Food Truck, estabelecimento, restaurante, operações especiais | expansões futuras | **não** [DEC-011] |

## 9. MVP  **[DEC-011]**

Primeiro lançamento jogável, pequeno, para validar o conceito. (§19)

| Área | Conteúdo | Observação |
|---|---|---|
| Mapa | uma pequena região: mercado, rua, trailer, alguns prédios, estacionamento; carrinho fixo numa esquina, trailer no mesmo lugar; **trânsito de carros andando**; lobby | **[DEC-020, DEC-012, DEC-086, DEC-087]** |
| Queda na noite | ambulância + reviver por Robux (ou item raro do Mart, na hotbar) ou spectate até o fim da run (noite vencida não devolve; todos voltam só se a noite for repetida); todos caídos: janela de 10 s, senão noite perdida | **[DEC-091 a DEC-094, DEC-100, DEC-102, DEC-111, DEC-113]** |
| Mart | prateleiras, área de frutas/verduras (só cenário), bancada de upgrades no fundo: básicos sempre à venda, especiais (item de reviver) por sorteio a cada turno; trailer fora da rotação, fixo a partir do dia 5; cafeteira fixa no trailer | **[DEC-049, DEC-101, DEC-106, DEC-107, DEC-109, DEC-125, DEC-129]**; `Q-120` |
| Progressão | cutscene → carrinho do chefe → ingredientes → trailer (2 tiers) | **[DEC-052]** |
| Pedidos | **combinação livre** de ingredientes desbloqueados, gerada pelo NPC (sem receitas fixas; emenda DEC-011). Base pão + salsicha; 6 complementos: Ketchup, Mustard, Cheese, Bacon, Potato Sticks, Cream Cheese | **[DEC-064, DEC-071, DEC-072]** |
| Equipamentos | Grill, Cooler, Counter + **Cash Drawer Lock** + **Trailer Lights** + **cafeteira** + estações de DEC-016 | **[DEC-046, DEC-055]** (emenda DEC-011) |
| Clientes | 4–6 tipos básicos + ladrão; teto de 12 NPCs simultâneos | **[DEC-018, DEC-045, DEC-050]** |
| Verbos da noite | 7 (atender, recusar, não olhar, luz, esconder, descartar, ponto seguro) | **[DEC-054]** |
| Anomalias | **10** (N1–N10, uma nova por noite, 10 noites); regra crítica só N7; final A1 na 10ª | **[DEC-030, DEC-025, DEC-027, DEC-060, DEC-065, DEC-073, DEC-074, DEC-075]** |
| Ciclo | **só noites** (ligação 7 PM → compra 30 s → noite 8 PM–6 AM → resumo); ~~dia (~7,5 min, relógio fixo), dia/noite alternados após trailer (5º dia)~~ | **[DEC-360]** (supera DEC-036, DEC-037, DEC-048) |
| Multiplayer | **party de 1–4** em servidor privado, um carrinho, dinheiro comum | **[DEC-012, DEC-032 a DEC-034]** (DEC-012 substitui DEC-001) |
| Persistência | sem save entre runs; gemas → classes; reconexão à run em andamento enquanto ≥1 jogador segue nela; snapshot de 15 min se todos saem | **[DEC-035, DEC-063, DEC-067, DEC-070, DEC-080]**; técnica `Q-058` |
| Classes | 4 no MVP: Rookie (grátis), Runner (45), Line Cook (45), Night Owl (120). Outras 4 aprovadas para atualização (Hawker pode ser a 5ª se houver folga) | **[DEC-069, DEC-070]** |
| Run | 10 noites, começa de noite (DEC-360); noite perdida = fim da run (`Chances = 0`, DEC-319); ~~cenário L ~6 h, 1 chance, modo dia infinito~~ | **[DEC-057, DEC-058, DEC-110, DEC-112]** |
| Monetização | reviver por Robux (developer product); resto adiado | **[DEC-062, DEC-092]** |

## 10. Pós-lançamento (não é MVP) — §20

- Receitas: Chili Dog, Korean Dog, Mexican Dog, Mega Dog, Halloween Dog, receitas raras.
- Equipamentos: grills, freezers, câmeras, iluminação, ferramentas de segurança.
- Veículos: carts, trailers, food trucks.
- Áreas: parque, posto, praia, centro, estacionamento, área industrial.
- Anomalias e regras novas a cada atualização.
- Eventos: Halloween, Christmas, festival, concert, sports night. Eventos de demanda da §13 (Game Night, Concert, Rain, Halloween, Special Night). **[DEC-128]**
- Co-op com funções exclusivas: **não** no MVP — todos fazem tudo; classes dão papéis suaves **[DEC-069]**. Co-op em si já entrou (DEC-012).
- Classes Hauler, Hawker, Barista, Shift Lead (aprovadas, fora do MVP) e reservas "Lookout", "Bargain Hunter". **[DEC-069]**
- Decoração do veículo comprada com dinheiro (uso para o dinheiro que sobra). **[DEC-082]**
- Ingredientes extras citados pelo usuário (exemplos, não fechados): ovo cozido, purê de batata, uva passa, chili, cheddar. Batata palha (Potato Sticks) e cream cheese já estão no MVP **[DEC-071]**. Todo ingrediente com nome genérico em inglês **[DEC-071]**.

## 11. Fora de foco  **[DEC-004]**

O jogo **não** deve virar (§18):

| Não é | Porque |
|---|---|
| Clone de jogo de terror de salas e corredores (§18 cita um jogo específico como anti-referência) | não queremos "entrar em salas → procurar item → fugir de monstro" |
| Simulator genérico | não queremos "clicar infinitamente → número sobe" |
| Horror puro | o jogador não passa o jogo inteiro só tentando sobreviver |
| Tycoon passivo | o jogador precisa estar fisicamente envolvido e fazer os hot dogs |

## 12. Fora de escopo do MVP

- Tiers 5+ (Food Truck, estabelecimento, restaurante, operações especiais). **[DEC-011]**
- ~~Multiplayer como requisito. [DEC-001]~~ — substituído: co-op de até 4 está no jogo **[DEC-012]**.
- Carrinho móvel / física de veículo. **[DEC-020]**
- Localização além do inglês. **[DEC-022]**
- Violência. **[DEC-023]**
- ~~Receitas além de Classic, Cheese, Bacon. [DEC-011]~~ — substituído: pedidos por combinação livre **[DEC-064]**; lista de ingredientes do MVP em `Q-059`.
- Monetização além do reviver por Robux (adiada). **[DEC-062, DEC-092]**
- Equipamentos além de Grill, Cooler, Counter, Cash Drawer Lock, Trailer Lights e cafeteira. **[DEC-011, DEC-046, DEC-055]**
- Lanterna, telefone como verbo, trancar porta. **[DEC-054, DEC-055]**
- Tiers intermediários de carrinho (Carrinho Velho, Improved Cart). **[DEC-052]**
- Reputação como recurso. **[DEC-051]**
- Ladrão à noite. **[DEC-050]**
- Save entre runs (cada run recomeça do zero). **[DEC-035]** Reconexão à run **em andamento** está no jogo **[DEC-063]**; se todos saem, a run sobrevive só **15 min** (snapshot, DEC-080); ninguém novo entra numa run em andamento. **[DEC-067]**
- Pedido com quantidade ("extra mostarda") ou complemento repetido. **[DEC-071]**
- Classes além de Rookie, Runner, Line Cook, Night Owl. **[DEC-069]**
- Eventos de demanda, validade de ingrediente e missões/objetivos diários. **[DEC-128]**
- XP e níveis (de jogador ou de carreira). **[DEC-081]**
- Uso para o dinheiro depois de comprar tudo (decoração fica para atualização). **[DEC-082]**
