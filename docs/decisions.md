# Decisões

Append-only. Decisão revertida ganha nova entrada que cita a anterior; a antiga não é apagada.

Formato: `DEC-### — AAAA-MM-DD — título` + o que foi decidido + impacto.

---

Origem das DEC-001 a DEC-011: afirmações explícitas e firmes do usuário no GDD V1
(`docs/source/gdd-v1-usuario.md`), entregue em 2026-10-08. `§N` = seção do original.
O que no GDD estava como "exemplo", "sugerido" ou "pode" **não** virou decisão; foi para `open-questions.md`.

### DEC-001 — 2026-10-08 — Multiplayer não é requisito do MVP

- Decidido: o MVP não exige multiplayer. Co-op com funções é possibilidade futura. (§21)
- Não decidido: se o MVP roda em servidor compartilhado ou instância individual (`Q-001`).
- Impacto: arquitetura não precisa de sincronização de cozinha entre jogadores no MVP; `vision.md` §9 e §12.

### DEC-002 — 2026-10-08 — Seis pilares definitivos

- Decidido: os pilares definitivos são os da §23: **VENDER, PROGREDIR, GERENCIAR, OBSERVAR, SOBREVIVER, DESCOBRIR**, com os subpilares listados lá.
- A numeração de 8 pilares das §3–§10 é detalhamento, não a lista oficial.
- Impacto: `vision.md` §6. Toda feature nova cita qual pilar serve.

### DEC-003 — 2026-10-08 — North Star

- Decidido: "Estou construindo uma vida melhor vendendo hot dogs... mas alguma coisa está muito errada aqui." (§24)
- Arco de motivação: ganhar dinheiro → comprar o trailer → entender as anomalias → terminar o turno e descobrir o que acontece.
- Impacto: critério de corte de conteúdo. `vision.md` §2.

### DEC-004 — 2026-10-08 — O que o jogo não é

- Decidido (§18): não é clone de jogo de salas/corredores de terror; não é simulator genérico ("clicar → número sobe"); não é horror puro; não é tycoon passivo.
- O jogador precisa estar fisicamente envolvido e **fazer** os hot dogs.
- Impacto: preparo não pode ser automático nem clique único repetido. Ver `Q-004`. `vision.md` §7 e §11.

### DEC-005 — 2026-10-08 — Horror não depende de jumpscare

- Decidido (§17): a tensão principal é "sei que existe algo errado, mas não sei o quê". O horror vem da quebra de padrões.
- Não decidido: se jumpscare é proibido ou só não pode ser a base (o texto diz "não deve depender").
- Impacto: anomalias, áudio e arte priorizam sutileza. `vision.md` §4.

### DEC-006 — 2026-10-08 — Upgrades com efeito real e uso duplo

- Decidido (§3.4, §11): progressão muda velocidade e capacidade do jogador, não só números abstratos. Upgrades têm utilidade real.
- Upgrades comprados para o negócio também podem servir de ferramenta de sobrevivência à noite.
- Impacto: `design/upgrades.md` precisa definir efeito diurno e noturno de cada equipamento.

### DEC-007 — 2026-10-08 — Food Trailer é o marco que abre a noite

- Decidido (§1, §10): o Food Trailer é o principal marco de progressão e representa sucesso econômico + início do horror. Depois dele o jogador começa a trabalhar à noite (pedido do chefe).
- Não decidido: se o trailer é comprado ou dado como promoção (`Q-009`); se a noite é obrigatória (`Q-005`).
- Impacto: `design/progression.md`, `story/`.

### DEC-008 — 2026-10-08 — Narrativa por descoberta

- Decidido (§8): o jogo começa sem revelar o sobrenatural. A história é descoberta pelo jogador, não explicada. O chefe cria perguntas, não explica tudo (§9).
- Impacto: tutorial e textos do início sem pistas explícitas de horror. `story/`.

### DEC-009 — 2026-10-08 — Identidade e tom

- Decidido (§22): identidade **Cute / Casual / Satisfying / Progression / Mystery / Horror**. Apresentação inicial propositalmente inocente.
- Impacto: `art/style-guide.md`, áudio, UI. `vision.md` §4.

### DEC-010 — 2026-10-08 — Regras de dia, noite e anomalias

- Decidido (§6, §7, §14):
  - Dia: trabalho normal e progressão; confortável e previsível.
  - Noite: risco e anomalias; o jogador **continua trabalhando** enquanto percebe o que está errado. Objetivo não é matar monstros.
  - Anomalias: observar → lembrar → decidir → agir. Erros têm consequência; nem toda anomalia mata.
  - Escalonamento: primeiras noites = perceber uma coisa estranha; intermediárias = lembrar regras; avançadas = múltiplas anomalias simultâneas.
  - Clientes normais são repetitivos o bastante para estabelecer padrão.
- Não decidido: quais consequências entram no MVP (`Q-006`), ações do jogador (`Q-013`), como as regras chegam ao jogador (`Q-012`).
- Impacto: `design/features.md`, `design/npcs.md`.

### DEC-011 — 2026-10-08 — Escopo do MVP

- Decidido (§19, §5): MVP pequeno para validar o conceito, com:
  - Mapa: uma pequena região (mercado, rua, trailer, alguns prédios, estacionamento).
  - Progressão: desempregado → primeiro emprego → carrinho → algumas receitas → trailer.
  - Receitas: Classic, Cheese, Bacon.
  - Equipamentos: Grill, Cooler, Counter.
  - Clientes: 4–6 tipos básicos.
  - Anomalias: 3–5 (a lista da §19 é exemplo, não fechada).
  - Ciclo: dia, noite, turno, pagamento.
  - Tiers 5+ (Food Truck, estabelecimento, restaurante) fora do MVP.
- Não decidido: quais tiers de carrinho entram (`Q-015`), anomalias exatas, ferramentas noturnas (`Q-014`).
- Impacto: `vision.md` §9 e §12; base para `PIPELINE.md` e roadmap.

---

Origem das DEC-012 a DEC-029: respostas do usuário à rodada 1 de bloqueantes, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, transcrição de voz). Só entrou o que foi afirmado com firmeza.
Exemplos e "a gente pode" viraram `Q-###`.

### DEC-012 — 2026-10-08 — Lobby + servidor privado por party de até 4 (substitui DEC-001)

- Decidido: o jogo tem um **lobby**. Jogadores montam uma **party de até 4** e são levados a um **servidor privado** daquela party. (Usuário disse 5 e corrigiu para 4.)
- Substitui **DEC-001**: co-op de até 4 jogadores faz parte do jogo, não é mais "fora do MVP". DEC-001 fica no histórico.
- Responde `Q-001`.
- Não decidido: carrinho compartilhado ou por jogador, dinheiro/progresso por jogador ou da party, solo permitido, dono do save (`Q-031`). Funções no co-op (`Q-030`).
- Impacto: `tech/architecture.md` (lobby, TeleportService, servidor reservado, sincronização da cozinha entre jogadores), `vision.md` §5 e §9, `levels/` (lobby é um mapa).

### DEC-013 — 2026-10-08 — Câmera em primeira pessoa

- Decidido: jogo em **primeira pessoa**. Referência de sensação citada pelo usuário: "Animal Hospital" (Roblox) — inspiração, não cópia.
- Responde `Q-003`.
- Impacto: arte (mãos/ferramentas em primeira pessoa, escala das estações), preparo, detecção de anomalias, `art/style-guide.md`.

### DEC-014 — 2026-10-08 — Foco em mobile

- Decidido: **mobile é a plataforma principal**. Design, input, UI e performance são pensados primeiro para celular.
- Responde `Q-002` em parte. Suporte a PC/console como secundário: `Q-042`.
- Impacto: orçamento de performance, tamanho de alvos de toque, `art/style-guide.md`, `tech/architecture.md`.

### DEC-015 — 2026-10-08 — Interação no mundo; HUD só de status

- Decidido:
  - Interação por **Tools nativas do Roblox** + **ProximityPrompt** no mundo. A interface em tela praticamente não tem interação.
  - HUD mostra só status: **sanidade**, **horário atual**, **turno/noite atual**, **dinheiro**.
  - Fim de turno: tela com **quanto dinheiro o jogador fez** no turno.
  - Feedback de preparo fica no mundo. Ex.: **barra de progresso sobre a salsicha** na grelha; coleta via ProximityPrompt.
- Não decidido: o que é sanidade como mecânica (`Q-034`).
- Impacto: `design/features.md` (seção UI), frontend (HUD em Vide só leitura), arte.

### DEC-016 — 2026-10-08 — Preparo por estações

- Decidido: o hot dog é montado passando por estações, cada passo um ProximityPrompt:
  1. **Estoque de salsicha**: interage; a salsicha vai **automaticamente para a grelha** e começa a grelhar.
  2. **Grelha**: barra de progresso sobre a salsicha. Pronta: interage; a salsicha vai para a **esteira/área de descanso**. Pode **acumular** várias.
  3. **Pão**: interage; o pão vai para a **tábua** e é **cortado**.
  4. **Esteira**: interage; a salsicha vai **para dentro do pão**.
  5. **Condimentos/complementos**: ketchup, mostarda e outros desbloqueados.
- Responde `Q-004`. Atende DEC-004 (jogador fisicamente envolvido).
- Não decidido: se o estoque é comprado no clique ou reabastecido no mercado (`Q-037`); receitas fixas x complementos livres (`Q-038`).
- Impacto: `design/features.md`, `design/items.md`, `design/upgrades.md`, layout do carrinho em `levels/`.

### DEC-017 — 2026-10-08 — Gestão de estoque é a prioridade; ingredientes desbloqueados por progressão

- Decidido:
  - **Gerenciar recursos para não faltar ingrediente é o mais importante** do loop de dia.
  - Faltou ingrediente que o cliente pediu: o jogador **entrega incompleto e o cliente reclama**, ou **sai correndo para comprar** no mercado.
  - Ingredientes/complementos são **desbloqueados com a progressão**; com o avanço vêm mais clientes e mais coisas para servir.
- Não decidido: lista de ingredientes (exemplos do usuário, não fechados: queijo, ovo cozido, purê de batata, batata palha, uva passa, chili, cheddar, "catupiry" — ver `Q-041`), quais entram no MVP (`Q-038`).
- Impacto: `design/items.md`, `design/economy.md`, pilar GERENCIAR.

### DEC-018 — 2026-10-08 — Evento: ladrão

- Decidido: existe evento de **ladrão**. Ele fica **de espreita, visível**, esperando o jogador sair. Se o jogador sai do carrinho (ex.: para o mercado), o ladrão **rouba o dinheiro**.
- Não decidido: dia ou noite, quanto rouba, como prevenir, como funciona em party (`Q-036`).
- Impacto: `design/features.md`, `design/npcs.md`, `design/economy.md`.

### DEC-019 — 2026-10-08 — Jogador é funcionário; trailer comprado pelo jogador

- Decidido:
  - O jogador é **funcionário**, não dono.
  - O **carrinho inicial é dado pelo chefe**.
  - O **trailer é concedido pelo chefe, mas o jogador compra** (sensação de conquista). Na ficção, o dinheiro é do chefe. **Não precisa explicar** isso ao jogador.
- Responde `Q-009`. A fantasia "Eu tenho meu próprio negócio" / "Dono de Trailer" do GDD V1 §2 deixa de valer como papel literal.
- Impacto: `vision.md` §3, `story/`, `design/progression.md`.

### DEC-020 — 2026-10-08 — Carrinho fixo na esquina

- Decidido: o carrinho **não se move**. Fica **numa esquina de rua**. O jogador não dirige nem empurra.
- Responde `Q-016`.
- Impacto: `levels/`, sem física de veículo.

### DEC-021 — 2026-10-08 — Introdução por cutscene

- Decidido: "arrumar emprego" é uma **cutscene introdutória**: o personagem anda pela cidade, vê um **panfleto de contratação num poste de luz** (vaga para cuidar de um carrinho de hot dog), **liga** para o contratante, se candidata, e o jogo começa.
- Responde `Q-011`. Não é sistema de vagas.
- Impacto: `story/`, `art/asset-list.md` (panfleto, poste), frontend (câmera de cutscene).

### DEC-022 — 2026-10-08 — Jogo todo em inglês

- Decidido: todo texto do jogo em **inglês**. Sem localização PT-BR prevista. Código e comentários em inglês (já era regra do `CLAUDE.md`). Documentação e conversa seguem em pt-BR.
- Responde `Q-008`.
- Impacto: todo texto do `narrative-writer`, nomes de itens/receitas.

### DEC-023 — 2026-10-08 — Público infantojuvenil, sem violência

- Decidido: público **infantojuvenil**. Conteúdo **sem violência**. O usuário rejeitou a anomalia de exemplo "carro de vidro fumê cujo motorista atira no jogador" por ser violenta demais para crianças; anomalias usam análogos não violentos.
- Responde `Q-010` em parte. Classificação de maturidade Roblox: `Q-043`.
- Impacto: teto de intensidade de anomalias, arte e áudio; "morte" do GDD V1 §7.3 precisa ser reinterpretada (`Q-035`).

### DEC-024 — 2026-10-08 — Turnos: dia primeiro, noite depois do trailer

- Decidido:
  - O jogador **começa trabalhando de manhã** (turnos de dia).
  - **Do meio para o fim do jogo** passa a pegar o **turno da noite**, com o sistema de anomalias.
  - **Turno da noite dura entre 20 e 30 minutos reais.**
  - A noite é **obrigatória após o trailer**. O **chefe liga** esporadicamente pedindo que o jogador fique no turno da noite.
- Responde `Q-005` em parte. Em aberto: alternância dia/noite após o trailer, duração do turno de dia, relógio (`Q-033`); duração exata de cada noite (`Q-044`).
- Impacto: `design/features.md`, `design/progression.md`.

### DEC-025 — 2026-10-08 — Regras da noite pelo chefe; escalonamento cumulativo

- Decidido:
  - O **chefe liga e explica** a regra: "quando acontecer tal evento, faça tal coisa". O jogador precisa **memorizar**.
  - Escalonamento **cumulativo, +1 anomalia por noite**: noite 1 = anomalia A; noite 2 = A + B; noite 3 = A + B + C; e assim por diante.
- Responde `Q-012`. Compatível com DEC-010.
- Impacto: `design/features.md`, `design/npcs.md`, `story/` (roteiro das ligações).

### DEC-026 — 2026-10-08 — Como se vence a noite

- Decidido: o jogador vence a noite **não cometendo erros**. Cada anomalia/evento tem um **comportamento correto**; agir errado faz o jogador **perder**.
- Responde `Q-006` em parte. Em aberto: o que "perder" significa (`Q-035`), sanidade (`Q-034`).
- Impacto: `design/features.md`.

### DEC-027 — 2026-10-08 — 10 noites no total

- Decidido: o jogo tem **10 noites** no total.
- Responde `Q-024` em parte. Em aberto: contradição com DEC-011 (3–5 anomalias no MVP) (`Q-039`); o que acontece depois da 10ª noite e quanto do mistério é revelado (`Q-040`).
- Impacto: `design/progression.md`, `story/`, quantidade de anomalias.

### DEC-028 — 2026-10-08 — Modo dia jogável indefinidamente

- Decidido:
  - O trailer fica disponível para compra a partir de um marco (ver `Q-032`).
  - Se o jogador não comprar, recebe uma **notificação** (não tutorial) sugerindo a compra.
  - Se ignorar, pode **jogar o modo de dia indefinidamente**, juntando dinheiro, com progressão própria (ainda há recursos para comprar). Jogar sem o modo de terror é válido.
- Impacto: `design/progression.md` (progressão do modo dia precisa ter conteúdo além do trailer), `design/economy.md`.

### DEC-029 — 2026-10-08 — Reaproveitar sistemas do projeto AnimalPlane

- Decidido: reaproveitar do projeto do próprio usuário `C:\Users\hakor\Documents\ModuxGames\AnimalPlane` o **sistema de ProximityPrompt**, o **sistema de barra de progresso de cozimento** e o **VFX com ParticleEmitter**. Visual **cartunizado**.
- Não decidido: se o VFX foi instanciado por script ou colocado no Studio, e como portar (`Q-045`; investigação em andamento).
- Impacto: `tech/architecture.md`, frontend, `art/style-guide.md`.

---

Origem das DEC-030 a DEC-038: respostas do usuário à rodada 2, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 2"). Resposta curta e escrita; só entrou o que foi afirmado.
Leituras do secretário que precisam de confirmação viraram `Q-###`.

### DEC-030 — 2026-10-08 — Mais anomalias no MVP (emenda DEC-011)

- Decidido: "vamos aumentar o número de anomalias". O limite de **3–5 anomalias** do MVP (DEC-011) **deixa de valer**. DEC-011 fica no histórico; o resto dela segue valendo.
- Direção: comportar as **10 noites** (DEC-027) com **+1 anomalia por noite** (DEC-025).
- Responde `Q-039`.
- Não decidido: número exato de anomalias no MVP e se o MVP já tem as 10 noites (`Q-050`).
- Impacto: `vision.md` §9, `design/features.md`, `design/npcs.md`, orçamento de assets e de tarefas (escopo do MVP cresce).

### DEC-031 — 2026-10-08 — Estoque reabastecido no mercado

- Decidido: o estoque do carrinho é **abastecido no mercado**. A interação na estação de estoque **consome**, não cobra na hora.
- Responde `Q-037` em parte (opção 2). Em aberto: capacidade do estoque, distância/tempo até o mercado (`Q-037`).
- Impacto: `design/economy.md`, `design/items.md`, `levels/` (rota carrinho ↔ mercado), reforça DEC-017 e DEC-018 (sair do carrinho tem risco).

### DEC-032 — 2026-10-08 — Um carrinho para a party

- Decidido: **um carrinho só, compartilhado** por todos os jogadores da party.
- Responde `Q-031` (a).
- Impacto: `tech/architecture.md` (estado da cozinha sincronizado entre até 4 jogadores), `levels/`, `design/features.md`.

### DEC-033 — 2026-10-08 — Dinheiro e progressão globais

- Decidido: **dinheiro e progressão são globais** — não por jogador.
- Leitura do secretário (a confirmar em `Q-049`): compartilhados pela party dentro da partida.
- Responde `Q-031` (b).
- Impacto: `design/economy.md`, `design/progression.md`, `tech/architecture.md`, HUD (dinheiro é da party).

### DEC-034 — 2026-10-08 — Solo permitido

- Decidido: **dá para jogar solo** (party de 1).
- Responde `Q-031` (c).
- Impacto: balanceamento precisa funcionar com 1 a 4 jogadores no mesmo carrinho (`design/economy.md`, anomalias, ladrão — `Q-036`).

### DEC-035 — 2026-10-08 — Sem save de partida; só recompensa off-game (gemas → classes)

- Decidido:
  - **Não há save** da partida. Cada partida é uma **run**.
  - Entre sessões persistem só **recompensas off-game**, como **gemas**.
  - Gemas servem para **comprar classes**.
- Responde `Q-031` (d) e `Q-007` em parte.
- Não decidido: o que são classes (`Q-046`); duração e fim da run, modo dia infinito sem save (`Q-047`); sair/entrar no meio (`Q-048`); relação com monetização (`Q-017`).
- Impacto: `tech/architecture.md` (persistência só de gemas/classes; estado da run em memória), `design/progression.md`, `design/economy.md`, DEC-028 (modo dia infinito passa a durar só a sessão).

### DEC-036 — 2026-10-08 — Turnos alternados após o trailer

- Decidido: **depois do trailer, turnos alternados** (dia, noite, dia, noite...).
- Responde `Q-033` (a). Em aberto: duração do turno de dia, relógio do HUD, como o dia termina (`Q-033`).
- Impacto: `design/progression.md`, `design/features.md`, duração da run (`Q-047`).

### DEC-037 — 2026-10-08 — Trailer a partir do 5º dia

- Decidido: o trailer fica disponível para compra **a partir do 5º dia** (turno de dia). Resolve a ambiguidade "5ª noite" da rodada 1.
- **Preço não definido** pelo usuário: fica com o game-designer (número, não decisão de design).
- Responde `Q-032` em parte. Preço em `Q-032` (não bloqueante).
- Impacto: `design/progression.md`, `design/economy.md`, DEC-028.

### DEC-038 — 2026-10-08 — Sanidade baixa causa terror psicológico

- Decidido: **sanidade baixa** causa **terror psicológico**: **sons, sustos, vultos e alucinações**.
- Nota (sem contradição): "sustos" convive com DEC-005 enquanto forem **consequência** da sanidade baixa e não a **base** do horror. Intensidade limitada por DEC-023 (infantojuvenil). Ver `Q-023`.
- Responde `Q-034` em parte. Em aberto: o que reduz, o que recupera, o que acontece em zero, se existe de dia (`Q-034`); nome do medidor (`Q-054`).
- Impacto: `art/style-guide.md` (áudio, VFX de alucinação), frontend (efeitos client-side por sanidade), `design/features.md`.

---

Origem das DEC-039 a DEC-043: respostas do usuário à rodada 3, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 3"). Resposta curta e escrita.
"Sanity" como nome **não** foi decidido: o usuário não entendeu a pergunta (Q-054 segue aberta).
O nome "sanidade/Sanity" abaixo é **provisório**.

### DEC-039 — 2026-10-08 — Primeira pessoa travada (emenda DEC-013)

- Decidido: câmera **travada em primeira pessoa**, sem zoom para terceira pessoa. Vale de dia e de noite (o usuário não separou; a opção "travada só à noite" não foi escolhida).
- Emenda **DEC-013** (que só dizia "primeira pessoa"). DEC-013 fica no histórico.
- Responde `Q-052`.
- **Risco conhecido** (registrado, decisão é do usuário): a pesquisa `docs/research/animal-hospital.md` aponta que o jogo de referência começou em primeira pessoa travada e **adicionou zoom para terceira pessoa ~3 meses depois**, aparentemente por pressão do mobile. Se testes em mobile mostrarem desconforto (enjoo, orientação, alcance de prompts), reabrir com nova DEC.
- Impacto: frontend (`CameraMode = LockFirstPerson`, mãos/Tools visíveis em 1ª pessoa), `art/style-guide.md` (escala das estações e legibilidade do prompt de perto), `levels/` (espaço do carrinho para até 4 jogadores em 1ª pessoa), cutscene (DEC-021) usa câmera própria.

### DEC-040 — 2026-10-08 — Hotbar nativa do Roblox

- Decidido: itens na mão usam a **hotbar nativa** do Roblox (Tools / Backpack padrão). Sem mochila própria. Reforça **DEC-015**.
- Responde `Q-053`.
- Não decidido: limite de itens carregados (`Q-056`, não bloqueante; número com o game-designer).
- Impacto: frontend (não esconder `CoreGui` Backpack), `design/items.md` (o que é Tool), ícones de Tool em `art/asset-list.md`.

### DEC-041 — 2026-10-08 — O que reduz a sanidade

- Decidido: a sanidade **cai** quando o jogador:
  1. **vê uma anomalia**;
  2. **quebra uma regra** (age errado diante de uma anomalia — DEC-025, DEC-026);
  3. **fica no escuro**.
- Responde `Q-034` (a).
- Não decidido: quanto cai em cada caso, o que conta como "ver" e "escuro" (números e critérios com o game-designer); se existe de dia; se é por jogador ou da party (`Q-034`).
- Impacto: `design/features.md` (detecção de "ver anomalia" e de "escuro" por jogador), iluminação do mapa (`levels/`), ligação com ferramentas noturnas de luz (`Q-014`, DEC-006).

### DEC-042 — 2026-10-08 — Café recupera sanidade

- Decidido: **café recupera a sanidade**.
- Responde `Q-034` (b).
- Não decidido: como o café é obtido (estação no carrinho, compra no mercado, Tool), quanto recupera, cooldown, custo (game-designer; `Q-034`).
- Impacto: `design/items.md` (café vira `ITM-###`), `design/economy.md`, `art/asset-list.md`.

### DEC-043 — 2026-10-08 — Sanidade zerada: o jogador está fora

- Decidido: se a sanidade **zera**, o jogador **"morre e perde"** — sai do jogo naquela run (palavras do usuário).
- Leitura do secretário, **a confirmar** (`Q-034`): em party, **os outros continuam**; **game over** quando todos caem (ou no solo). O parêntese "(os outros continuam ou game over)" é ambíguo.
- "Morre" precisa ser representado **sem violência** (DEC-023): ver `Q-055`.
- Responde `Q-034` (c) em parte.
- Não decidido: se o jogador zerado volta no dia seguinte ou fica fora da run toda (`Q-034`); relação com derrota por erro de regra (`Q-035`) e com fim da run (`Q-047`).
- Impacto: `design/features.md` (estado "fora" do jogador: espectador?), `tech/architecture.md` (estado por jogador na run), `story/` e `art/` (representação).

---

Origem das DEC-044 a DEC-056: resposta do usuário à rodada 4, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 4"): **"aprovar tudo"** sobre `docs/design/proposals-round-1.md`,
apresentado item por item com as recomendações. Cada DEC abaixo aprova **a opção recomendada** da seção citada,
com os números e critérios de aceite do documento. O detalhe fica no documento; a DEC registra o que vale.

Regras gerais desta rodada:
- **Cenários L e C** (§0.1): onde a proposta tem números diferentes para run longa (L) e campanha curta (C), **vale a variante do cenário que `Q-047` escolher**. Até lá, nenhuma das duas é definitiva. O cenário C exige emendar DEC-024, DEC-027 e DEC-037 (só com nova DEC).
- **Números**: o próprio documento chama os números de §0.2 de "números iniciais para balancear" e os define como **parâmetros de tabela (data-driven)** (§0.1). Os números de sanidade são "usados nesta rodada". Ficam aprovados como **valores iniciais, ajustáveis em playtest** sem nova DEC; mudança de **regra** (não de número) exige DEC.

### DEC-044 — 2026-10-08 — Propostas da rodada 1 aprovadas; cenários de run como tabela

- Decidido: `docs/design/proposals-round-1.md` inteiro aprovado. Status → **Aprovado**.
- §0.1: os parâmetros de run (dias antes do trailer, noites, duração da noite) são **tabela data-driven**; trocar de cenário muda a tabela, não o sistema. Qual cenário vale: `Q-047` (segue aberta e bloqueante).
- Impacto: `tech/architecture.md` (config de run em dados), todas as DECs abaixo.

### DEC-045 — 2026-10-08 — Economia de referência (§0.2)

- Decidido (valores iniciais):
  - Receitas: Classic $5 (custo $1,45, dia 1), Cheese $7 ($2,45, dia 2), Bacon $8 ($2,95, dia 3). Bacon = pão + salsicha + bacon + mostarda.
  - Gorjeta +$1 se o pedido sai completo em até 20 s após anotado. Paciência no balcão: 45 s.
  - Fluxo solo: 1 cliente a cada 22 s no dia 1, +8%/dia até o dia 5 (teto +40%). Multiplicador por party: 1p ×1,0 · 2p ×1,6 · 3p ×2,1 · 4p ×2,5.
  - **Teto de 12 NPCs simultâneos por servidor** (dia: até 8 clientes + 1 ladrão; noite: até 6 clientes + 3 atores de anomalia).
  - Dinheiro inicial: $30 (adiantamento do chefe). Tabela de lucro esperado por dia (dias 1–5) é a meta de balanceamento.
- Condição: a tabela vale para **pedido = receita fixa**. Se `Q-038` decidir combinações livres, a tabela é refeita.
- Impacto: `design/economy.md`, `design/items.md`, `design/npcs.md`, `tech/architecture.md` (orçamento de NPC).

### DEC-046 — 2026-10-08 — Upgrades de referência (§0.3); emenda DEC-011 (equipamentos)

- Decidido (valores iniciais): Grill (2 vagas/12 s → 3/10 s $60 → 4/8 s $150); Cooler (12 → 20 $50 → 30 $120); Counter (fila 3 → 4 +10 s paciência $70 → 5 +20 s $160); **Cash Drawer Lock** $80 (DEC-050); **Trailer Lights** $100, só com o trailer (DEC-055).
- **Emenda DEC-011**: o MVP passa a ter, além de Grill, Cooler e Counter, os upgrades **Cash Drawer Lock** e **Trailer Lights** e a **cafeteira** do trailer (DEC-055). DEC-011 fica no histórico; o resto dela segue valendo.
- Impacto: `design/upgrades.md` (fichas UPG), `art/asset-list.md`, `vision.md` §9 e §12.

### DEC-047 — 2026-10-08 — Preço do trailer: $300 × party (Q-032, opção B)

- Decidido: preço = **$300 × multiplicador da party**: 1p ×1,0 ($300) · 2p ×1,5 ($450) · 3p ×1,9 ($570) · 4p ×2,2 ($660).
- Tamanho da party lido **no início da run**; não muda se alguém sair.
- Regra de escala: preço ≈ 0,8 × lucro líquido acumulado esperado (solo) até o dia de liberação. **Cenário C** (trailer no dia 3) → ≈ $160 — **só vale se `Q-047` escolher C** (exige emenda de DEC-037).
- Trailer visível no estacionamento desde o dia 1, placa "Available on Day 5"; compra por prompt no trailer; troca no fim do turno (fade + ligação do chefe); próximo turno = noite 1.
- Responde `Q-032`.
- Impacto: `design/economy.md`, `design/progression.md`, `levels/` (estacionamento), `story/` (ligação).

### DEC-048 — 2026-10-08 — Turno de dia com relógio fixo (Q-033, opção A)

- Decidido: o dia termina pelo **relógio**. Preparação 7:00→8:00 AM (até 60 s; qualquer jogador abre antes pela placa "OPEN") → loja aberta 8:00 AM→6:00 PM (**360 s**, 1 h do jogo = 36 s) → fechamento às 6:00 PM (placa "CLOSED", fila ainda atendida, até 30 s) → resumo (15 s). Total ~7,5 min.
- HUD: formato 12 h em inglês ("8:00 AM"), atualiza a cada 10 min do jogo (6 s reais), igual para toda a party (servidor).
- Noite usa o mesmo sistema: **8:00 PM → 6:00 AM**; duração real pela tabela da noite (`Q-044`/`Q-047`).
- Modo dia infinito (DEC-028): mesmo formato, contador "Day N" continua.
- Responde `Q-033` (b), (c), (d). Duração do dia igual nos cenários L e C.
- Impacto: `design/features.md`, HUD, `tech/architecture.md` (relógio no servidor).

### DEC-049 — 2026-10-08 — Mercado por pacote físico; estoque apertado; distância média (Q-037, opções A/B/B)

- Decidido:
  - **Compra**: prompt na prateleira compra um pacote → Tool na mão → prompt "Restock" na estação. Pacotes: Sausages 8/$6, Buns 8/$4, Ketchup 20 usos/$4, Mustard 20 usos/$4, Cheese 6/$6, Bacon 6/$9, Coffee 10 doses/$5. Máximo **2 pacotes** por jogador. Restock até a capacidade; sobra fica no pacote. Dinheiro sai do caixa da party na compra (servidor).
  - **Capacidade** nível 1: salsicha 12, pão 12, queijo 8, bacon 8, ketchup 30 usos, mostarda 30 usos. Cooler 2 = 20 (queijo/bacon 14); Cooler 3 = 30 (queijo/bacon 20). Estoque passa de um dia para o outro na run. Run começa com estoque cheio.
  - **Distância** carrinho ↔ mercado: **100–120 studs** (~25 s ida, volta e compra). Porta do mercado com **linha de visão** para o carrinho. Mercado aberto também à noite.
- Responde `Q-037`.
- Impacto: `design/items.md`, `design/economy.md`, `levels/` (distância, linha de visão), `art/asset-list.md` (pacotes como Tool).

### DEC-050 — 2026-10-08 — Gaveta do caixa e ladrão de dia (Q-036, opção B)

- Decidido:
  - **Gaveta do caixa** no carrinho: vendas do turno vão para a gaveta (valor visível no mundo). No fim do turno é depositada no dinheiro da party (HUD). O ladrão só mexe na gaveta.
  - Ladrão **só de dia**. Chance: dia 1 0% · dia 2 50% · dia 3+ 70%. Máx. 1 por dia. Aparece entre 9:00 AM e 3:00 PM, visível, espreita até 120 s reais.
  - Gatilho: nenhum jogador na zona do carrinho (raio 14 studs) por 3 s. ~4 s até a gaveta. Abre em 8 s com barra de progresso.
  - Impedir: qualquer jogador entra na zona durante a abertura → foge sem nada; party ganha +$5 ("Nice catch!").
  - Rouba floor(gaveta × 0,5); nada se gaveta < $5. Com Cash Drawer Lock ($80): abertura 16 s e rouba 30%.
  - Foge com saco de moedas; sem contato, sem briga (DEC-023). Party: basta **um** jogador na zona.
- Responde `Q-036`.
- Impacto: `design/features.md`, `design/npcs.md` (ladrão), `design/upgrades.md`, `art/asset-list.md` (gaveta, saco de moedas).

### DEC-051 — 2026-10-08 — Sem reputação; pagamento por qualidade e nota do turno (Q-018, opção A)

- Decidido: **reputação não existe** como recurso. Recursos seguem Money, XP, Stock (§12).
  - Completo até 20 s: 100% + $1 · completo depois: 100% · incompleto: 50%, sem gorjeta, balão de reclamação · errado: 0%, devolve e vai embora · desistiu: 0%.
  - **Nota do turno** por % de satisfeitos (completos ÷ chegaram ao balcão): **A ≥ 90%** bônus +20% da gaveta · **B ≥ 75%** +10% · **C ≥ 50%** +0% · **D < 50%** +0% e o chefe comenta. Calculada no servidor, igual para a party. Nenhum medidor de reputação no HUD.
  - À noite vale a mesma regra; recusar corretamente um cliente-anomalia não conta como insatisfeito.
- Responde `Q-018` (resolve a contradição §7.3 x §12). Uso da nota para gemas: `Q-046`.
- Impacto: `design/economy.md`, `design/npcs.md`, tela de fim de turno.

### DEC-052 — 2026-10-08 — Dois tiers de veículo no MVP (Q-015, opção A)

- Decidido: MVP com **2 veículos**: carrinho do chefe → Food Trailer. "Ele vai melhorando o trailer dele" = **equipamentos**, não tier. Todo upgrade adiciona peça visível (DEC-006). Tiers "Velho / Improved Cart" do §5 ficam fora do MVP.
- Nomes: placeholders "Boss's Cart", "Food Trailer"; finais com o narrative-writer.
- Responde `Q-015`.
- Impacto: `art/asset-list.md` (2 modelos + peças de upgrade), `levels/` (2 layouts para 4 jogadores), `vision.md` §8.4.

### DEC-053 — 2026-10-08 — Derrota na noite: chances do chefe (Q-035, opção C)

- Decidido:
  - Jogador **fora** = sanidade 0 (DEC-043). Em party, o jogador fora senta no banco do fundo do trailer e assiste pela câmera de um colega; **volta no próximo turno com sanidade cheia**.
  - **Noite perdida** = todos os jogadores da party fora ao mesmo tempo, **ou** alguém quebra a **regra crítica** (no máximo 1 por noite, marcada pelo chefe com "whatever you do, never...").
  - Quebrar regra **comum** tira 35 de sanidade (DEC-056). Leitura de DEC-026 ("agir errado faz perder") aprovada: erro comum derruba pela sanidade; erro na regra crítica perde a noite direto.
  - **Chances por run**: cenário L = 3, cenário C = 2 (**vale conforme `Q-047`**). Perder consome 1 chance e repete a noite com o estado do início dela (snapshot em memória); perde o faturamento da noite. Sem chances = fim da run, gemas pelas noites vencidas (`Q-046`).
  - Representação sem violência: luzes do trailer piscam e apagam, tela escurece, jogador acorda no banco ao amanhecer, chefe liga ("Rough night. Let's try that again."). Chances só na ligação e na tela de fim de noite, não no HUD.
- Responde `Q-035` e `Q-034` (f) e (g): os outros continuam; quando todos caem, a noite é perdida (consome chance), não o fim direto da run. Completa DEC-043.
- Impacto: `design/features.md`, `tech/architecture.md` (snapshot de início de noite), `story/` (falas), `Q-047` (b) e `Q-055` parcialmente respondidos.

### DEC-054 — 2026-10-08 — Sete verbos contra anomalia (Q-013, opção B)

- Decidido: verbos do MVP: **atender, recusar, não olhar, luz (interruptor), esconder, descartar, ponto seguro**. Telefone e trancar porta ficam fora do MVP.
  - Todo verbo usa só o botão de interagir ou a câmera; nenhum botão exclusivo na tela (DEC-014).
  - Cada anomalia tem **exatamente um** verbo correto; a ficha declara sinal, regra do chefe, verbo correto, verbo errado mais provável.
  - Em party, o verbo vale para a party quando o alvo é compartilhado.
  - Distribuição de exemplo para 10 anomalias (não fechada): recusar ×3, não olhar ×2, luz ×1, esconder ×2, descartar ×1, ponto seguro ×1.
- Responde `Q-013`.
- Impacto: `design/features.md`, `design/npcs.md` (fichas de anomalia), `levels/` (ponto seguro, interruptor, esconderijo).

### DEC-055 — 2026-10-08 — Café + Trailer Lights no MVP (Q-014, opção B)

- Decidido:
  - **Café**: cafeteira fixa no trailer (prompt hold 1 s), preparo 6 s com barra, gera Tool "Coffee"; +25 de sanidade ao beber; cooldown 60 s por jogador; estoque de café (pacote 10 doses $5; trailer começa com 10); pode ser entregue a outro jogador.
  - **Trailer Lights** ($100, só com o trailer): dia +10% de fluxo; noite área iluminada de raio 18 studs (dentro não conta como escuro); desligável pelo interruptor.
  - Lanterna fica **fora do MVP**.
- Responde `Q-014`. Cumpre DEC-006 (uso duplo) e DEC-042.
- Impacto: `design/items.md` (ITM café), `design/upgrades.md` (UPG Trailer Lights), `levels/` (iluminação), `art/asset-list.md`.

### DEC-056 — 2026-10-08 — Sanidade: só à noite, por jogador; números iniciais

- Decidido:
  - Sanidade **existe só à noite** (some do HUD de dia). É **por jogador**.
  - Números iniciais: começa a noite em 100 · ver anomalia −5 (alvo no campo de visão por 1 s; uma vez por anomalia por jogador) · quebrar regra comum −35 · escuro −1/s (fora de luz por mais de 3 s) · café +25 (cooldown 60 s) · 0 = jogador fora (DEC-043, DEC-053).
- Responde `Q-034` (d), (e) e os números que ficavam com o game-designer. Com DEC-053, `Q-034` fecha.
- Impacto: `design/features.md`, HUD, frontend (efeitos de DEC-038 por jogador).

---

Origem das DEC-057 a DEC-066: resposta do usuário à rodada 5, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 5", transcrição de voz). Só entrou o que foi afirmado.
O nome do medidor (`Q-054`) **não** foi decidido: o usuário não entendeu a pergunta pela segunda vez; "Sanity" segue provisório.

### DEC-057 — 2026-10-08 — Run longa: cenário L vale (Q-047 a)

- Decidido: "estrutura longa". Vale o **cenário L** de `design/proposals-round-1.md` §0.1: trailer no dia 5, **10 noites de 20–30 min**, run de ~6 h.
- Onde DEC-044 a DEC-056 têm variante L/C, **vale a L**:
  - DEC-047: trailer **$300 × party** (1p $300 · 2p $450 · 3p $570 · 4p $660). Variante C (≈ $160) descartada.
  - DEC-053: **3 chances** do chefe por run. Variante C (2) descartada.
  - DEC-044: a tabela de run segue data-driven; o valor padrão é L.
- O cenário C não vale. DEC-024, DEC-027 e DEC-037 seguem sem emenda.
- Responde `Q-047` (a). (b) já respondida por DEC-053; (c) em DEC-058.
- Ainda aberto: noite com duração fixa ou crescente dentro de 20–30 min (`Q-044`, não bloqueante).
- Impacto: `design/progression.md`, `design/economy.md`, `tech/architecture.md` (run de várias horas; ver DEC-063 e `Q-057`/`Q-058`), `vision.md` §8.

### DEC-058 — 2026-10-08 — Modo dia infinito: sem fim, achievement secreto aos 100 dias, dá gemas (Q-047 c)

- Decidido:
  - O modo dia infinito (DEC-028) **não acaba** (termina só quando a party sai).
  - Existe um **achievement secreto aos 100 dias**.
  - O modo dia infinito **dá gemas**.
- Não decidido: quantas gemas e por quê (por dia, por marco) — proposta do game-designer (`Q-046`). Recompensa do achievement além do registro: não dita.
- Responde `Q-047` (c).
- Impacto: `design/progression.md`, `design/economy.md` (gemas), achievement/badge (`tech/architecture.md`), `story/` (texto do achievement, narrative-writer).

### DEC-059 — 2026-10-08 — Dinheiro e progressão são da party (confirma DEC-033; Q-049)

- Decidido: "dinheiro e progressão são da party". Um caixa, um conjunto de upgrades/ingredientes, uma noite atual, compartilhados pela party dentro da run.
- Confirma a leitura de **DEC-033**. Coerente com DEC-047, DEC-049, DEC-050.
- Responde `Q-049`.
- Impacto: `design/economy.md`, `tech/architecture.md` (estado da run por party, não por jogador; exceção: sanidade por jogador, DEC-056).

### DEC-060 — 2026-10-08 — MVP com 10 noites e 10 anomalias (Q-050, opção 1)

- Decidido: **10 noites com 10 anomalias** — uma nova por noite, cumulativo (DEC-025).
- O MVP traz as 10 noites. Sem sorteio/variação entre runs.
- Responde `Q-050`. Completa DEC-030.
- Impacto: `design/npcs.md` (10 fichas de anomalia com sinal, regra, verbo correto — DEC-054), `art/asset-list.md`, `story/` (10 ligações do chefe), escopo de tarefas.

### DEC-061 — 2026-10-08 — Classes são bônus de atributo (dão vantagem); lista com o game-designer (Q-046 a, c)

- Decidido:
  - Uma **classe dá bônus de atributo**. Exemplos do usuário (não é lista fechada): mais agilidade (velocidade de movimento), cozinhar mais rápido, rendimento maior por pedido entregue, mais dinheiro, mais sanidade.
  - Classes **dão vantagem** (poder), não só estilo. A sugestão anterior do secretário (efeito leve de estilo) **não** foi escolhida.
  - "Não precisa definir quais vão ser as classes": a **lista recomendada fica com o game-designer**, com base na temática. Proposta entra como **Rascunho** até o usuário aprovar.
- Risco conhecido (registrado; decisão é do usuário): `docs/research/animal-hospital.md` alerta que classe com vantagem comprada com Robux gera percepção de pay-to-win em co-op. Hoje não se aplica: monetização adiada (DEC-062). Reavaliar quando monetização for planejada.
- Responde `Q-046` (a) e (c). Em aberto (aguardando proposta do game-designer): quantas classes, como se ganham gemas, preço em gemas, se entram no MVP, se bônus de classes empilham na party (`Q-046`).
- Impacto: `design/progression.md`, `design/economy.md`, `tech/architecture.md` (classe persistida; atributo aplicado na run), balanceamento de DEC-045/DEC-056 com classes.

### DEC-062 — 2026-10-08 — Monetização adiada (Q-017)

- Decidido: "depois a gente pode planejar as monetizações, não tem problema." Monetização **não é planejada agora** e **não bloqueia** a bandeira verde.
- Leitura do secretário: o MVP pode ser construído sem monetização; quando ela for planejada, vira nova rodada e nova DEC.
- `Q-017` rebaixada para não bloqueante (não respondida no mérito). `Q-046` (d) (gemas compráveis com Robux) segue junto com `Q-017`.
- Impacto: `design/economy.md` (seção monetização fica "adiada"), `tech/architecture.md` (não precisa de MarketplaceService no MVP, mas não deve impedir adicionar depois).

### DEC-063 — 2026-10-08 — Reconexão à partida em andamento (Q-048 a; emenda parcial de DEC-035)

- Decidido:
  - Jogador que **sai** de uma partida tem o **estado dele salvo naquela partida**.
  - Ao **entrar no jogo de novo**, pode **reconectar** e continuar a mesma partida.
  - Aviso por **notificação no canto superior direito** da tela. O HUD principal será planejado depois; o desenho da notificação fica para essa rodada.
- **Emenda parcial de DEC-035** ("sem save; cada partida é uma run"): a run continua sem save entre runs, mas o estado da run **sobrevive à saída de um jogador** e permite voltar. DEC-035 fica no histórico; o resto segue valendo (persistentes entre runs: gemas e classes).
- A sugestão anterior do secretário em `Q-048` (a) — "quem sai perde a run" — **não** foi escolhida.
- Responde `Q-048` (a). Em aberto: todos saem, prazo da run guardada, amigo novo entra, líder sai (`Q-057`, bloqueante); persistência técnica (`Q-058`, architect).
- Coerente com DEC-047: tamanho da party lido no início da run, não muda se alguém sair.
- Impacto: `tech/architecture.md` (estado da run e por jogador fora da memória do servidor; servidor reservado fecha quando fica vazio), lobby (detectar run pendente e oferecer reconexão), HUD.

### DEC-064 — 2026-10-08 — Pedidos por combinação livre de ingredientes (Q-038; Q-027; emenda DEC-011; revisão de DEC-045)

- Decidido:
  - As receitas são **combinações livres**. O **NPC gera um pedido aleatório** com base nos **ingredientes desbloqueados**; o jogador só **monta** o que foi pedido.
  - O jogador não escolhe cardápio. O cliente pede qualquer combinação dentre o que está desbloqueado.
- **Emenda DEC-011** (receitas Classic, Cheese, Bacon): o MVP deixa de ter receitas nomeadas fixas como pedido; tem **ingredientes desbloqueáveis**. DEC-011 fica no histórico; o resto segue valendo.
- **DEC-045 precisa ser revista** (a própria DEC condicionava: "se Q-038 decidir combinações livres, a tabela é refeita"). Os preços por receita (Classic $5, Cheese $7, Bacon $8) **deixam de valer como regra de preço**; falta o modelo de preço por ingrediente/combinação (`Q-059`, game-designer, em andamento). O resto de DEC-045 (gorjeta, paciência, fluxo, multiplicador por party, teto de 12 NPCs, $30 iniciais) **segue valendo**.
- **DEC-051** usa "errado = receita diferente". Com combinação livre, "errado" e "incompleto" precisam de definição por ingrediente (ex.: faltou um ingrediente pedido = incompleto; ingrediente não pedido = ?). Fica com o game-designer em `Q-059`.
- Responde `Q-038` e `Q-027`. Absorve parte de `Q-020` ("sem ketchup" vira combinação); "extra mostarda" (quantidade) segue em `Q-020`.
- Não decidido: quais ingredientes entram no MVP e em que dia desbloqueiam; quantos ingredientes por pedido; como o pedido é mostrado ao jogador (balão, ícones) (`Q-059`).
- Impacto: `design/items.md` (ingredientes como ITM, não receitas), `design/economy.md`, `design/npcs.md` (gerador de pedido), DEC-049 (pacotes do mercado seguem por ingrediente), `art/asset-list.md` (ícones de ingrediente no balão).

### DEC-065 — 2026-10-08 — Final com revelação na 10ª noite (Q-040)

- Decidido: na **10ª noite** o jogo tem um **final com revelação**.
- Conteúdo da revelação (quanto do mistério e qual) fica com o **narrative-writer**, como Rascunho para aprovação. Compatível com DEC-008 (descoberta).
- Responde `Q-040` em parte. Em aberto (não bloqueante): conteúdo da revelação; o que acontece depois do final (créditos, volta ao lobby, gemas de conclusão) (`Q-040`).
- Impacto: `story/`, `design/progression.md`, cutscene/câmera (frontend).

### DEC-066 — 2026-10-08 — Prompt custom do AnimalPlane (Q-051, opção 1)

- Decidido: usar o **prompt custom do AnimalPlane** (BillboardGui em Vide, tecla E/ButtonX, alvo mais próximo do centro da tela, hold), portado. Ver `docs/research/animalplane-reuse.md` §1.
- **DEC-015** passa a ser lida como "prompt no mundo", não a classe nativa `ProximityPrompt`. Emenda de leitura; DEC-015 segue valendo no resto.
- Responde `Q-051`. Cumpre DEC-029. Porte só depois da bandeira verde (cortar acoplamento com `PlaneController`/`CharacterController`, `Q-045`).
- Impacto: frontend (controller de prompt), `tech/architecture.md`, botão de interagir fixo no mobile (DEC-014, DEC-054).

---

Origem das DEC-067 a DEC-072: resposta do usuário à rodada 6, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 6", transcrição de voz). Duas partes:
regras de reconexão (`Q-057`) e **"Pode aprovar tudo"** sobre `docs/design/proposals-round-2.md`, apresentado com 4 pontos
(classes até ±12%; ingrediente a mais = $0 e faltando = 50% floor; 4 classes no MVP; prefixo `CLS-###`).
Cada DEC de aprovação aprova **a opção recomendada** da seção citada, com números e critérios de aceite do documento.
Mesma regra de números de DEC-044: valores iniciais em tabela data-driven, ajustáveis em playtest sem nova DEC; mudar **regra** exige DEC.

### DEC-067 — 2026-10-08 — Reconexão: run vive enquanto houver ≥1 jogador; sem entrada nova; sem líder na run (Q-057; emenda DEC-063)

- Decidido:
  - **Party inteira saiu = run encerrada.** Não há retomada depois que o último jogador sai.
  - **Reconexão só é possível enquanto pelo menos 1 jogador da party continua na partida.** Prazo da run guardada = enquanto o servidor tiver alguém.
  - **Ninguém novo entra** numa run em andamento. Só reconecta quem começou a run.
  - **Líder sai = a partida continua normalmente.** Dentro da run **não existe líder**; o lobby só serve para formar a party.
- **Emenda DEC-063**: "estado salvo naquela partida" = estado mantido **na memória do servidor da run** enquanto ele vive; não sobrevive ao servidor vazio. DEC-063 fica no histórico; notificação no canto superior direito e reconexão seguem valendo.
- Consequências diretas (sem regra nova):
  - Solo: se o jogador sai ou cai a conexão, a run acaba.
  - Jogador "fora" por sanidade 0 (DEC-053) conta como presente.
  - Tamanho da party para o trailer segue fixo no início da run (DEC-047); com entrada bloqueada, nunca cresce.
- Não dito pelo usuário (leitura do secretário, **não decisão**): o relógio do turno não pausa quando alguém sai. Ver `Q-061`.
- Responde `Q-057`. Simplifica `Q-058` (architect): **não é preciso persistir o estado da run fora do servidor** (DataStore/MemoryStore da run). Resta só o lobby saber para qual servidor reservado o jogador volta.
- Risco registrado (decisão é do usuário): run solo de ~6 h e achievement de 100 dias (~12 h contínuas) se perdem em qualquer queda de conexão. Ver `Q-060`.
- Impacto: `tech/architecture.md` (estado da run só em memória; servidor reservado fecha vazio = run encerrada; teleporte de volta ao mesmo servidor), lobby (oferecer reconexão só se o servidor da run ainda existe), `design/features.md` (sem liderança na run).

### DEC-068 — 2026-10-08 — Propostas da rodada 2 aprovadas

- Decidido: `docs/design/proposals-round-2.md` inteiro aprovado. Status → **Aprovado**. Opções recomendadas: §1.2 A, §1.5 B, §2.2 B, §3.1 B, §3.2 A, §3.4 B (com campo de multiplicador por tipo de cliente previsto).
- Os 4 pontos apresentados ao usuário ficam confirmados (detalhe em DEC-069 a DEC-072).
- Tabelas data-driven de §3.8 (Ingredients, OrderPhases, OrderRules, CustomerTypes, Classes, GemRewards) aprovadas como formato.
- Impacto: `design/progression.md`, `design/economy.md`, `design/items.md`, `design/npcs.md`, `tech/architecture.md`, `tech/` (dados de conteúdo).

### DEC-069 — 2026-10-08 — Classes: 8 leves com contrapeso; 4 no MVP; prefixo CLS-### (Q-046 b, f)

- Decidido (§1, opção A):
  - Regras: escolha no **lobby**, travada na run; efeito **pessoal** (ações do próprio jogador); repetir classe na party é permitido; no máximo 1 efeito de party (Shift Lead), **não acumula**; toda classe paga tem **contrapeso** leve.
  - **Teto de poder: nenhuma classe muda o lucro/min solo em mais de ±12%.** **Nenhuma classe mexe nas regras das anomalias** (verbo correto, regra crítica, chances do chefe, −35 por quebrar regra).
  - Classe inicial **Rookie**, grátis, neutra: é a régua do balanceamento.
  - Classes só se compram com **gemas ganhas jogando** (monetização adiada, DEC-062). Guarda contra pay-to-win de §1.6 vira critério fixo para classe nova.
- IDs (prefixo **`CLS-###`**, aprovado; ficha em `docs/design/classes.md`):

| ID | Chave | Nome (placeholder) | Bônus | Contrapeso | Tier | MVP |
|---|---|---|---|---|---|---|
| CLS-001 | `class_rookie` | "Rookie" | — | — | 0 (grátis) | **sim** |
| CLS-002 | `class_runner` | "Runner" | velocidade 16 → 18 | sanidade inicial 90 | 1 | **sim** |
| CLS-003 | `class_line_cook` | "Line Cook" | grelha 15% mais rápida (salsichas dele) | velocidade 16 → 15 | 1 | **sim** |
| CLS-004 | `class_hauler` | "Hauler" | 3 pacotes em vez de 2 | com 3 pacotes, velocidade 14 | 1 | não |
| CLS-005 | `class_hawker` | "Hawker" | gorjeta $2 nos pedidos dele | janela de gorjeta −4 s | 2 | não (5ª se houver folga) |
| CLS-006 | `class_night_owl` | "Night Owl" | sanidade inicial e máx. 120 | de dia, velocidade 16 → 15 | 2 | **sim** |
| CLS-007 | `class_barista` | "Barista" | café dele: 3 s e +35 | ver anomalia −8 para ele | 2 | não |
| CLS-008 | `class_shift_lead` | "Shift Lead" | party: bônus do chefe +5 p.p., não acumula | pedidos dele sem gorjeta | 3 | não |

- **MVP (§1.5 B): Rookie + Runner + Line Cook + Night Owl.** Hawker entra como 5ª só se o plano de tarefas tiver folga; incluir exige registro. As outras ficam para a 1ª atualização. "Lookout" e "Bargain Hunter" são reserva, sem ID.
- Nomes são placeholders para o narrative-writer (DEC-022: inglês).
- Responde `Q-046` (b), (f) e "empilha na party?" (não, para efeito de party). Completa DEC-061. Fecha `Q-030`: **sem funções exclusivas**; todos fazem tudo; classes dão papéis suaves.
- Emenda leitura de **DEC-049** (máx. 2 pacotes): Hauler carrega 3. **DEC-056** (sanidade 100): Runner começa com 90; Night Owl 120; Barista −8 por anomalia vista. **DEC-051** (bônus da nota): Shift Lead +5 p.p.
- Impacto: `design/classes.md` (novo), lobby (seleção), `tech/architecture.md` (classe persistida por jogador; efeitos por tabela), `art/asset-list.md` (ícones), `story/` (nomes e descrições).

### DEC-070 — 2026-10-08 — Gemas: fontes, valores e preço das classes (Q-046 e)

- Decidido (§2, opção B):
  - Gemas **por jogador**, persistidas; moeda off-game única. Todo jogador da party recebe **o mesmo valor** pelo mesmo evento, inclusive quem está fora (sanidade 0).
  - Creditadas **no fim de cada turno** (tela de resumo) e salvas na hora.
  - Valores: turno de dia concluído **2** (run e dia infinito) · nota A no dia **+1** · noite N vencida **15 + 2 × (N − 1)** (15…33; soma 240) · final da 10ª noite **+100** (1× por run) · achievement secreto **"Day 100" +300**, 1× por conta, também **badge** do Roblox · fim da run por falta de chances: 0 extra.
  - Noite perdida não dá gema; vencida depois dá o valor normal, uma vez.
  - Preço das classes: tier 1 **45** · tier 2 **120** · tier 3 **180**. MVP: 210 gemas para as 3 pagas (cabe numa run completa, ~375).
- Responde `Q-046` (e) e o preço; completa DEC-058 (quanto o dia infinito dá) e responde em parte `Q-040` (gemas de conclusão: +100).
- `Q-046` (d) (gemas com Robux) segue com `Q-017` (DEC-062).
- Impacto: `design/economy.md`, `design/progression.md`, `tech/architecture.md` (DataStore de gemas e classes; badge), tela de fim de turno.

### DEC-071 — 2026-10-08 — Ingredientes do MVP, preço por complemento e gerador de pedido (Q-059 a, b, c, e; revisa DEC-045; emenda DEC-011 e DEC-049)

- Decidido (§3.1 B, §3.2 A, §3.3, §3.4 B):
  - Base de todo pedido: **pão + salsicha**. Complementos do MVP: **Ketchup, Mustard** (dia 1), **Cheese** (dia 2), **Bacon** (dia 3), **Potato Sticks** (dia 4), **Cream Cheese** (dia 6). Liberação **automática por dia**, com **1 pacote grátis** na estação nova no dia da liberação.
  - **Preço do pedido = $4 + soma dos complementos**: molho $1, Cheese $2, Bacon $3, Potato Sticks $2, Cream Cheese $2. Os antigos "Classic $5 / Cheese $7 / Bacon $8" continuam com o mesmo preço como combinações.
  - Pacotes novos: Potato Sticks 10 usos / $5 (cap. nível 1: 15 usos; Cooler 2/3: 25/35); Cream Cheese 8 usos / $6 (cap. nível 1: 12 usos). Capacidade do Cream Cheese nos Coolers 2/3: o documento se contradiz (ver `Q-062`).
  - Gerador: **K por fase + pesos por ingrediente**; **máx. 3 complementos**, sem repetição; ingrediente do dia com peso ×1,5; pedido no **balão sobre o cliente com ícones**. Campo de multiplicador por tipo de cliente já previsto.
  - Tabela de lucro esperado de §3.7 **substitui** a de `proposals-round-1.md` §0.2. Trailer $300 solo segue (DEC-047).
- **Revisa DEC-045** (não a edita): o preço por receita sai; vale o preço por complemento. O resto de DEC-045 (fluxo, multiplicador por party, teto de 12 NPCs, $30 iniciais) segue; gorjeta e paciência em DEC-072.
- **Emenda DEC-011**: ingredientes do MVP são os 8 acima (base + 6 complementos). **Emenda DEC-049**: pacotes e capacidades de Potato Sticks e Cream Cheese.
- Nome genérico em inglês para todo ingrediente (marca não entra): fecha `Q-041` ("Cream Cheese" no lugar da marca citada).
- Pedido é a lista exata, sem quantidade e sem complemento repetido: fecha `Q-020` (sem "extra mostarda" no MVP) e o resto de `Q-027`.
- Responde `Q-059` (a), (b), (c), (e).
- Impacto: `design/items.md` (ITM por ingrediente), `design/economy.md`, `design/npcs.md` (gerador), `art/asset-list.md` (2 pacotes, 2 estações, ícones), `levels/` (espaço para 2 estações a mais).

### DEC-072 — 2026-10-08 — Completo, incompleto, errado; gorjeta e paciência por tamanho do pedido (Q-059 d; revisa DEC-051 e DEC-045)

- Decidido (§3.5, §3.6):
  - **Completo**: pão + salsicha + exatamente os complementos pedidos → 100% (+ gorjeta na janela).
  - **Incompleto**: falta ≥1 complemento pedido e nada a mais → **50% arredondado para baixo** (floor; $5 → $2, $7 → $3), sem gorjeta.
  - **Errado**: tem complemento **não pedido**, ou falta pão/salsicha → **$0**, devolve e vai embora.
  - Desistiu: $0.
  - **Dinheiro é inteiro** (sem centavos no HUD).
  - Janela de gorjeta **16 + 4 × K s**; paciência **40 + 5 × K s** (K = nº de complementos). K = 1 mantém 20 s e 45 s. Gorjeta fixa $1. Counter soma +10/+20 s.
  - Montagem: cada complemento é prompt hold de **1 s**.
- **Revisa DEC-051** (não a edita): "incompleto paga 50%" vira floor(50%); "errado" passa a ser definido por ingrediente. Nota do turno A–D segue igual.
- **Revisa DEC-045**: gorjeta "até 20 s" e paciência "45 s" passam a ser o caso K = 1 da fórmula.
- Responde `Q-059` (d). Com DEC-071, `Q-059` fecha.
- Impacto: `design/economy.md`, `design/npcs.md`, `design/features.md` (validação de entrega no servidor).

---

Origem das DEC-073 a DEC-079: resposta do usuário à rodada 7, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 7"). Resposta curta e escrita, numerada 1–6.
Perguntas feitas pelo orquestrador a partir das fichas do narrative-writer (`docs/story/`).
Mesma regra de números de DEC-044: tempos e números das fichas são valores iniciais; o game-designer ajusta na tabela sem nova DEC; mudar **regra** exige DEC.

### DEC-073 — 2026-10-08 — As 10 anomalias aprovadas (N1–N10)

- Decidido: "Aprovo a lista". `docs/story/anomalies.md` → **Aprovado**. Valem, por anomalia: conceito, sinal, regra do chefe, forma curta, verbo correto, erro, tipo (comum/crítica) e escopo (party/por jogador).

| Noite | Rótulo | Nome (no jogo) | Verbo correto | Tipo | Escopo |
|---|---|---|---|---|---|
| 1 | N1 | The blank folks | Recusar | comum | party |
| 2 | N2 | The wrong food | Descartar | comum | party |
| 3 | N3 | The stopped clock | Luz | comum | party |
| 4 | N4 | The copies | Recusar (a cópia) | comum | party |
| 5 | N5 | The Raincoat Lady | **Atender** | comum | party |
| 6 | N6 | The wavers | Não olhar | comum | por jogador |
| 7 | N7 | The Walker | Não olhar | **crítica** (DEC-074) | party |
| 8 | N8 | The long car | Esconder | comum | por jogador |
| 9 | N9 | The knock | Esconder | comum | por jogador |
| 10 | N10 | The Hush | Ponto seguro | comum | por jogador |

- Distribuição de verbos: recusar ×2, atender ×1, não olhar ×2, luz ×1, esconder ×2, descartar ×1, ponto seguro ×1. Aprovada a troca de um "recusar" por **"atender"** (N5). O exemplo de DEC-054 era "não fechado"; DEC-054 segue valendo (7 verbos, um verbo correto por anomalia).
- Tempos citados na ficha (prazos, passos do Walker, janelas de esconder, ~15 s do Hush etc.) = **valores iniciais**; números finais com o game-designer.
- "Consequências de sabor" (efeitos extras sem violência) ficam como na ficha: **sugestões que o game-designer pode cortar** se custarem sistema novo (`anomalies.md` §0). Quais entram no MVP: `Q-065`.
- Rótulos N1–N10 são locais. Prefixo de ID para anomalia: `Q-063`. Interruptor antes do Trailer Lights (N3): `Q-064`.
- Responde `Q-050` em conteúdo (DEC-060 já fixava 10 noites, 10 anomalias).
- Impacto: `design/npcs.md` e `design/features.md` (fichas técnicas por anomalia), `story/script.md` (ligações das noites), `art/asset-list.md` (variantes: rosto liso, comida alterada, cópia espelhada, capa amarela, silhueta na janela, Walker, carro comprido), `levels/` (linha de visão da Juniper, rota trailer → Mart pela Ninth, janela alta, porta dos fundos, ponto seguro sob o letreiro do Mart).

### DEC-074 — 2026-10-08 — Regra crítica fixa: só N7 (The Walker)

- Decidido: "pode seguir com o recomendado". A regra crítica (DEC-053) é **fixa**: **só N7 — The Walker** é crítica. As outras 9 são comuns (erro = −35 de sanidade).
- Consequência direta: noites 1–6 **não têm** regra crítica (a noite só é perdida se todos caírem). A partir da noite 7, toda noite tem a mesma regra crítica: "Whatever you do, never watch the Walker."
- Alternativa descartada: crítica rotativa (o chefe escolhe "a de hoje").
- Compatível com DEC-053 (no máximo 1 por noite) e com o estágio 5 do arco do chefe (noites 7–10).
- Impacto: `design/features.md` (flag de regra crítica por anomalia, não por noite), `story/script.md` (lembrete do Walker nas noites 8–10).

### DEC-075 — 2026-10-08 — Final A "The Light on the Corner", variante A1 (Q-040)

- Decidido: o final da 10ª noite é a **opção A** de `docs/story/ending.md`, **variante A1** (Walt aparece em pessoa ao amanhecer, sai do Mart com dois cafés). `ending.md` → **Aprovado**.
- **Leitura do secretário (anotada):** a resposta 1 ("Aprovo a lista") não cita o final; a escolha da opção A é lida pela resposta 3 ("Walt aparece em pessoa mesmo"), porque A1 só existe dentro da opção A. Se o usuário quiser outro final, reabre com nova DEC.
- Vale: clímax roteirizado (Hush final ~5:45 AM, Walker parado, 6:00 AM sol e postes voltam) · cutscene do amanhecer com as 9 falas de Walt · Raincoat Lady passa, "Morning, Marigold." · créditos · cena pós-créditos (panfleto "NIGHT SHIFT — NOW HIRING") · tela de fim de run (gemas, +100 pelo final, DEC-070) · volta ao lobby (§2.4).
- Revelado: a esquina é um cruzamento; luz e regras mantêm a madrugada "educada"; Walt fez o turno da noite desde 1979 e escolheu o jogador. **Nunca** explicado: o que é o late crowd, de onde vem, quem fez o acordo, quem é a Raincoat Lady (`world.md` §6).
- Critérios de aceite (§4): revelação depois das 6:00 AM da noite 10; até ~60 s; pulável (DEC-078); sem palavras proibidas (`world.md` §1); mesma cena para toda a party; funciona solo.
- Opções B, C e a variante A2 ficam no documento só como histórico; não valem.
- Responde `Q-040` (conteúdo da revelação e pós-final).
- Impacto: `story/`, `art/asset-list.md` (modelo do Walt CHR-001, foto de 1979, crachá, panfleto novo), frontend (câmera de cutscene), `levels/` (porta do Mart, lado oposto da rua para a Raincoat Lady), `design/progression.md` (fim da run com sucesso).

### DEC-076 — 2026-10-08 — Walt: só telefone durante o jogo; em pessoa só no final (Q-026)

- Decidido: Walt Bramble (CHR-001), o chefe, fala com o jogador **só por telefone** (ligações) durante toda a run. Aparece **em pessoa uma única vez**: na cutscene do amanhecer da 10ª noite (DEC-075, A1).
- Fonte: resposta 3 ("Walt aparece em pessoa mesmo"), lida junto da variante A1 de `ending.md` ("chefe em pessoa só no final") e da ficha CHR-001 ("só por telefone até a 10ª noite").
- Consequências: a regra da N9 ("I never come to the trailer at night") nunca é quebrada pelo próprio Walt; o modo dia infinito não tem Walt em pessoa.
- Responde `Q-026`.
- Impacto: `art/asset-list.md` (Walt é asset só da cutscene final; sem retrato nas ligações — `style-guide.md` §7.4), `story/characters.md`.

### DEC-077 — 2026-10-08 — A ligação do chefe não pode ser ouvida de novo

- Decidido: "Jogador não pode ouvir novamente." Não existe botão, menu, registro ou log para **repetir** uma ligação do chefe. A regra precisa ser **memorizada** (reforça DEC-025).
- Consequências: nenhuma tela mostra a lista de regras; nenhum item (papel, caderno) guarda as regras no MVP.
- Leitura do secretário (**não decisão**): a regra trata de repetição **pedida pelo jogador**. A versão curta tocada pelo chefe na **noite repetida** após derrota (`script.md` §5.11, Rascunho) é uma ligação nova, não replay. Confirmação em `Q-077`.
- Impacto: frontend (legenda da ligação sem "replay"), `story/script.md` (a última linha de cada ligação é a forma curta da regra), `design/features.md`.

### DEC-078 — 2026-10-08 — Cutscenes puláveis; em party, pula com 50% dos votos

- Decidido: **cutscenes podem ser puladas**. Em party, a cutscene é pulada quando **50% dos votos** pedem. Solo: o jogador pula sozinho.
- Vale para: cutscene de abertura (DEC-021) e cutscene do final (DEC-075). Cumpre o critério de `ending.md` §4.
- Leitura do secretário (**não decisão**, detalhes em `Q-077`): voto de cada jogador **conectado** na run; pula com **≥ 50%** (1 de 2, 2 de 3, 2 de 4); voto não pode ser retirado.
- Em aberto (`Q-077`): se ligações do chefe também são puláveis (com DEC-077, pular uma ligação perde a regra).
- Impacto: frontend (prompt/toque de "Skip" com contador de votos — exceção pontual a DEC-015, só durante cutscene), `tech/architecture.md` (voto no servidor).

### DEC-079 — 2026-10-08 — Opal (CHR-003) entra no jogo, como na ficha

- Decidido: "pode seguir o recomendado". **Opal**, atendente do Ninth Street Mart, entra no MVP como descrita em `story/characters.md` CHR-003:
  - NPC fixo atrás do balcão do caixa do Mart, **dia e noite**.
  - **Não vende**: a compra continua por prompt nas prateleiras (DEC-049).
  - Função: ambiente + **1 fala curta em balão por visita**, sorteada pela fase (dia, noites 1–3, 4–6, 7–10). Dá pistas sem explicar (DEC-008) e ensina o ponto seguro da N10 antes da hora.
  - Aparência e falas: as da ficha (Rascunho de texto; `characters.md` segue Rascunho).
- **Leitura do secretário (a confirmar pelo orquestrador):** os documentos não trazem a frase de recomendação; registrei "manter Opal" porque a ficha, o roteiro (`script.md` dia 13, "Tell Opal it's for Walt") e a trilha de pistas (`ending.md` §3) já a usam. Se a recomendação entregue ao usuário tiver sido outra, corrigir com nova DEC.
- Impacto: `design/npcs.md` (NPC estático com balão), `art/asset-list.md` (modelo da Opal), `levels/` (balcão do caixa do Mart, AST-031), `story/script.md`.

---

Origem das DEC-080 a DEC-085: resposta do usuário à rodada 8, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 8", duas mensagens escritas).
Mensagem A: `Q-066` (snapshot do architect) + frase ambígua sobre gemas (**não decidida**, ver `Q-078`).
Mensagem B: 5 perguntas do game-designer (`design/progression.md` §5 e §6, `design/economy.md` §6 e §7), cada uma com recomendação; o usuário aceitou as 5.
Mesma regra de números de DEC-044: valores em tabela, ajustáveis sem nova DEC; mudar **regra** exige DEC.

### DEC-080 — 2026-10-08 — Snapshot da run por 15 min para recuperar queda (Q-066, opção 1; emenda DEC-067)

- Decidido: "Pode guardar a cópia de 15 minutos." Proposta do architect (`tech/architecture.md` §12 P1) aprovada:
  - No **início de cada turno**, o servidor salva um **snapshot da run** no **MemoryStore**, **TTL 15 min**.
  - Vale só para o **mesmo roster** (quem começou a run). Ninguém novo entra (DEC-067 segue).
  - Uso: se **todos** os jogadores da party saírem (inclusive solo), a run **não acaba na hora**. Se alguém do roster voltar em até **15 min**, a run é retomada **no início do turno corrente** (estado do snapshot).
  - Ninguém voltou em 15 min = run encerrada.
- **Emenda DEC-067** (não a edita): "party inteira saiu = run encerrada" passa a ser "party inteira saiu **e ninguém do roster voltou em 15 min** = run encerrada". O resto de DEC-067 segue (reconexão enquanto ≥1 está na partida; sem entrada nova; sem líder).
- Consequências diretas (sem regra nova):
  - O turno interrompido recomeça do início: dinheiro, vendas e eventos depois do snapshot se perdem.
  - Gemas do turno interrompido não são creditadas (o turno não terminou). Gemas de turnos já concluídos ficam (DEC-070).
- Detalhes técnicos com o architect em `Q-058`: (a) se a retomada vale também para **saída voluntária** ou só queda (o servidor pode não distinguir); (b) o que o snapshot guarda; (c) como o lobby oferece a retomada.
- Responde `Q-066` e `Q-060` (b). `Q-058` deixa de dizer "não persistir a run fora do servidor".
- Impacto: `tech/architecture.md`, `tech/data.md` (snapshot no MemoryStore), lobby (oferta de retomada), `design/progression.md` §6.2, `vision.md`.

### DEC-081 — 2026-10-08 — XP e níveis fora do MVP

- Decidido: "XP E níveis não são necessários, pode retirar." Opção **A** de `design/progression.md` §5.
- Recursos do MVP: **Money, Stock, Gems**. Sem XP, sem nível de jogador ou de carreira, sem barra de XP.
- Emenda leitura do GDD V1 (§4.1, §12, §16 "→ XP →") e do pilar **PROGREDIR** (DEC-002): o subpilar "XP, níveis" sai do MVP. O pilar segue (dinheiro, upgrades, equipamentos, ingredientes, veículo, gemas/classes). DEC-002 segue valendo.
- Desbloqueios seguem como decidido: ingredientes por dia (DEC-071), upgrades por dinheiro (DEC-046), trailer por dia + dinheiro (DEC-047), classes por gemas (DEC-069).
- Impacto: `vision.md` §6, §7, §8.3; `design/progression.md`; `design/economy.md`; HUD (nada a acrescentar).

### DEC-082 — 2026-10-08 — Dinheiro sem uso depois de ~Day 8 aceito no MVP

- Decidido: "Pode aceitar o dinheiro sobrando no MVP sem problemas."
- No MVP, depois de comprar todos os upgrades (~Day 8 solo, `design/progression.md` §3), o dinheiro não tem mais uso. **Aceito**; nada novo entra no MVP para resolver.
- Futuro (fora do MVP, sem compromisso de data): **decoração do veículo com dinheiro** (`design/economy.md` §7, opção C). Antes de entrar, precisa respeitar DEC-006 (peça com efeito real ou justificativa).
- Impacto: `design/economy.md` §7, `vision.md` §10 (pós-lançamento).

### DEC-083 — 2026-10-08 — Anti-AFK: gema de dia exige ≥ 3 pedidos completos (emenda DEC-070)

- Decidido: "Pode incluir a proteção afk." Como em `design/economy.md` §6: as **2 gemas** do turno de dia concluído só são creditadas se a **party** entregou **≥ 3 pedidos completos** no turno. Vale na run e no modo dia infinito.
- Número 3 é valor inicial em tabela (DEC-044).
- **Emenda DEC-070** (não a edita): "turno de dia concluído 2" passa a ter a condição acima.
- Leitura do secretário (**não decisão**): o **+1 da nota A** do mesmo turno também exige o mínimo (com 1 pedido completo a nota pode ser A). Confirmar com o game-designer; se mudar, ajustar na ficha.
- Impacto: `design/economy.md`, `design/progression.md`, `tech/` (`RewardService`).

### DEC-084 — 2026-10-08 — "Day 100" soma dias de modo infinito entre sessões (Q-060 a; emenda DEC-058 e DEC-070)

- Decidido: "pode somar o achievement então para dar 100 dias." Opção **C** de `design/progression.md` §6.1:
  - Contador **por jogador**, **persistido** junto das gemas.
  - Conta **dias de modo infinito concluídos** (dias sem trailer, a partir do Day 6), **em qualquer run**, somando sessões.
  - Só conta o dia que passou no anti-AFK (DEC-083).
  - Chegou a 100: **+300 gemas** e **badge**, 1× por conta (DEC-070 segue).
- **Emenda DEC-058 e DEC-070** (não as edita): o achievement deixa de exigir 100 dias **numa run só**.
- Responde `Q-060` (a). Com DEC-080, `Q-060` fecha.
- Impacto: `design/progression.md`, `design/features.md` (FEAT-031), `tech/data.md` (contador persistido), `tech/content-data.md`.

### DEC-085 — 2026-10-08 — Jogador desconectado: relógio, gemas e "todos fora" (Q-061)

- Decidido: "sobre o jogador desconectado, pode incluir isso também." Recomendação inteira aceita:
  - (a) O **relógio do turno não pausa** quando um jogador sai; segue para quem ficou.
  - (b) **Gemas do turno só para quem está no servidor no resumo.** Quem reconecta antes do resumo recebe; quem está desconectado no resumo não recebe aquele turno.
  - (c) Jogador desconectado **não conta** para "todos fora" (DEC-053): só presentes contam. Jogador "fora" por sanidade 0 segue contando como presente (DEC-067) e recebe gemas (DEC-070).
- Tensão anotada (**não resolvida**): a mensagem A fala em "ganho de gemas em tempo real". Se a resposta de `Q-078` mudar o momento do crédito, a regra (b) precisa ser relida. Ver `Q-078`.
- Responde `Q-061`. Compatível com DEC-067 e DEC-080.
- Impacto: `design/features.md`, `design/economy.md`, `tech/architecture.md` (§12 P2, P3), `RewardService`.

---

Origem das DEC-086 a DEC-091: resposta do usuário à rodada 9, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 9", uma mensagem escrita).
Não respondido nesta rodada: `Q-078`, estilo "toy low-poly" e iluminação de `Q-072`, `Q-073`, `Q-063`, `Q-071`, confirmação da Opal (DEC-079).
Mesma regra de números de DEC-044: valores em tabela, ajustáveis sem nova DEC; mudar **regra** exige DEC.

### DEC-086 — 2026-10-08 — Trailer funciona na esquina (Q-079, opção 1)

- Decidido: "O trailer pode ficar na esquina mesmo." Depois da compra, o trailer trabalha **na esquina, no Pad onde ficava o carrinho**.
- Opção recomendada pelo level-designer (`levels/MAP-01.md` §15 P1). Mercado segue a 100–120 studs (DEC-049); fila, rotas e padrão de cliente iguais de dia e de noite.
- Coerente com DEC-020 (carrinho fixo na esquina) e `story/world.md` (esquina Ninth & Juniper).
- Responde `Q-079`. Destrava `Q-082` (destino do carrinho depois da troca).
- Impacto: `levels/MAP-01.md` (Pad único para os dois veículos), `art/asset-list.md`.

### DEC-087 — 2026-10-08 — Trânsito com carros andando no MVP (Q-080; contra a recomendação)

- Decidido: "sobre o transito, faremos carros andando." O MVP tem **trânsito de carros andando** nas ruas do mapa.
- **Oposto da recomendação** do level-designer (MVP só com carros parados). Riscos registrados (decisão é do usuário): performance no celular (DEC-014), segurança das rotas de pedestre, orçamento de NPC/entidades (teto de 12 NPCs, DEC-045), contraste com a N8 "The long car" (DEC-073).
- Não decidido: se carro freia ou atropela (`Q-101`, usuário); rotas, quantidade, dia/noite e performance (`Q-102`); convivência com a N8 (`Q-103`).
- Responde `Q-080`.
- Impacto: `levels/MAP-01.md` (faixas, cruzamentos, travessias), `tech/architecture.md` (sistema de trânsito, orçamento), `art/asset-list.md` (carros), `story/anomalies.md` N8 (leitura do sinal).

### DEC-088 — 2026-10-08 — Cutscene em 1ª pessoa, compartilhada; jogadores da party se veem (Q-081)

- Decidido: "Cutscene é em primeira pessoa e cada jogador ve um ao outro."
  - Câmera da cutscene em **1ª pessoa** (POV do próprio personagem).
  - Em party, a cutscene é **compartilhada**: todos assistem à mesma cena ao mesmo tempo, e cada jogador **vê os avatares dos outros** jogadores na cena.
- **Emenda a recomendação** de `Q-081` ("cada client renderiza a sua", sem avatar). Leitura do secretário (**não decisão**): o próprio avatar não aparece (POV); os dos colegas sim. Cada client pode renderizar a cena localmente, desde que mostre todos os avatares e esteja sincronizada pelo servidor.
- Vale para abertura (DEC-021) e final (DEC-075). Compatível com `ending.md` §4 ("mesma cena para toda a party") e com o voto de pular (DEC-078).
- Consequência: a cutscene de abertura (personagem anda, vê o panfleto, liga) precisa comportar 1–4 avatares. Ajuste de roteiro em `Q-106`.
- Responde `Q-081`.
- Impacto: `story/script.md` (abertura), `story/ending.md` (Walt fala com a party), frontend (câmera POV + avatares), `tech/architecture.md` (sincronização da cena).

### DEC-089 — 2026-10-08 — NPCs com rig R6 (Q-072, em parte)

- Decidido: "Npcs vão ser R6 mesmo." Todos os **NPCs** (clientes, ladrão, Opal, atores de anomalia, Walt) usam rig **R6**.
- **Emenda a recomendação** do art-director (R15, `art/style-guide.md` §4.1, Rascunho).
- **Não decidido**: estilo "toy low-poly", iluminação Future e aprovação do style guide como um todo (`Q-072` segue aberta); rig dos **avatares dos jogadores** (fala cita só NPCs; ver `Q-105`).
- Responde `Q-072` em parte.
- Impacto: `art/style-guide.md` §4.1 (proporções, roupas, animações R6), `art/asset-list.md` (fichas de NPC), escala (`Q-095`), animações de NPC.

### DEC-090 — 2026-10-08 — Celular-alvo adiado; otimização depois (Q-074)

- Decidido: "Não me preocupo com celular minimo, essas coisas otimizamos depois."
- O MVP **não fixa** um celular de referência agora. Otimização para aparelho mínimo fica para depois.
- Mobile segue como plataforma principal (DEC-014): design, input e UI continuam pensados para celular. O orçamento de `style-guide.md` §9 vale como meta de Rascunho, sem aparelho de medição.
- `Q-074` rebaixada para **adiada** (não respondida no mérito), como `Q-017` em DEC-062.
- Impacto: `art/style-guide.md` §9, `tech/architecture.md` (orçamento sem aparelho de teste), risco somado ao trânsito (DEC-087).

### DEC-091 — 2026-10-08 — Sanidade zerada: desmaio, ambulância, reviver pago ou spectate (Q-055; emenda DEC-053 e DEC-043)

- Decidido (sequência):
  1. Sanidade chega a 0: o jogador **desmaia** e o **corpo cai**.
  2. **Médicos chegam de ambulância** e **levam o corpo**.
  3. O jogador **pode pagar para reviver**: a ambulância **volta**, **para em frente** (ao trailer), o jogador **aparece ao lado da ambulância** e a ambulância **vai embora**. Na volta, **sem paramédicos descendo**, sem animação extra.
  4. **Se não pagar**, o jogador fica em **spectate**.
- Fecha `Q-055`. A recomendação anterior (desmaio suave → banco do trailer, `story/script.md` §9; `style-guide.md` §10) **não** foi escolhida.
- **O que muda em DEC-053** (não a edita):
  - Sai: "jogador fora senta no banco do fundo do trailer e assiste pela câmera de um colega".
  - Entra: corpo levado pela ambulância; quem não paga fica em **spectate** (assistir à câmera de um colega segue como leitura natural de spectate).
  - Novo: **reviver pago** durante a noite, que não existia.
  - Fica **em aberto**: se quem não paga volta no **próximo turno** com sanidade cheia (como DEC-053) ou fica fora até o fim da run (`Q-099`); se "todos fora = noite perdida" é imediato ou há janela para pagar (`Q-100`).
  - Segue igual (até nova DEC): regra crítica, chances do chefe, repetição da noite, representação da **noite perdida** (luzes piscam, tela escurece, acorda ao amanhecer, ligação do chefe).
- **O que muda em DEC-043**: "morre e perde" ganha a representação da ambulância e a saída pelo reviver pago.
- Sem violência (DEC-023): sem sangue, sem ferimento, sem agressor; ambulância e médicos como resgate. Tom final com narrative-writer e art-director (`Q-104`, `Q-106`).
- Consequências diretas (sem regra nova): jogador em spectate segue **presente** (DEC-067, DEC-085) e recebe gemas (DEC-070). Sanidade só existe à noite (DEC-056), então a sequência só ocorre à noite.
- Não decidido: com o que se paga (`Q-097`), preço (`Q-098`), retorno de quem não paga (`Q-099`), todos caem (`Q-100`), tempos, sanidade ao reviver, ambulância durante anomalias e limite de revives (`Q-107`).
- Impacto: `design/features.md` (estado desmaiado/levado/revivido/spectate), `design/economy.md` (preço do reviver), `levels/MAP-01.md` (rota e parada da ambulância em frente ao trailer, ponto de spawn ao lado), `art/asset-list.md` (ambulância, médicos R6, maca), `story/script.md` §9 (reescrever a queda), `tech/architecture.md` (veículo roteirizado, estado por jogador), HUD/UI (oferta de pagamento — exceção a DEC-015 a definir).

---

Origem das DEC-092 a DEC-099: resposta do usuário à rodada 10, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 10", uma mensagem escrita).
Não respondido nesta rodada: `Q-078` (gemas A/B), estilo "toy low-poly" e aprovação do style guide (`Q-072`).
Mesma regra de números de DEC-044: valores em tabela, ajustáveis sem nova DEC; mudar **regra** exige DEC.

### DEC-092 — 2026-10-08 — Reviver pago com Robux; item raro de reviver na loja (Q-097; contra a recomendação; Q-017 em parte)

- Decidido: "O revive é pago com robux, porém raramente na loja é vendido um item de reviver bem caro aonde eles podem pagar e revivar um player."
  - Forma principal: reviver custa **Robux** (developer product, compra repetível).
  - Alternativa rara: uma **loja do jogo** vende, **raramente**, um **item de reviver caro**, que permite **reviver um jogador**.
- **Oposto da recomendação** de `Q-097` (dinheiro da party na run). Risco anotado (decisão é do usuário): "pay-to-skip-horror" (guarda citada em `Q-017`); a oferta em tela durante o spectate é exceção a DEC-015, como o "Skip" de DEC-078.
- **Emenda DEC-062** (monetização adiada): o reviver é o **primeiro produto de monetização definido**. O resto da monetização segue adiado (`Q-017`, agora parcial).
- Preço em Robux (`Q-098`): **adiado** junto com a monetização; o valor é definido quando a monetização for planejada.
- Não decidido: loja, moeda, frequência, preço e uso do item raro (`Q-108`); quem pode pagar pelo jogador caído (`Q-107`).
- Responde `Q-097`.
- Impacto: `design/economy.md` (seção monetização deixa de estar só "adiada"), `design/features.md` (oferta de reviver, item raro), `tech/architecture.md` (MarketplaceService/`ProcessReceipt` entra no MVP; antes DEC-062 dizia que não precisava), UI (prompt de compra em spectate).

### DEC-093 — 2026-10-08 — Quem não paga fica em spectate até o fim da run (Q-099; contra a recomendação; emenda DEC-053 e DEC-091)

- Decidido: "Quem não paga fica só assistindo e não volta mais."
  - Jogador que caiu e **não reviveu** fica em **spectate até o fim da run**. **Não volta** no próximo turno.
- **Oposto da recomendação** de `Q-099` (voltar no próximo turno com sanidade cheia).
- **O que muda em DEC-053**: sai "volta no próximo turno com sanidade cheia". **O que muda em DEC-091**: o item "fica em aberto" sobre o retorno fecha com "não volta".
- Riscos anotados: espectador pode ficar horas sem jogar numa run de ~6 h (cenário L, DEC-057); a party encolhe pelo resto da run (dia incluso). Saída para o lobby mantendo gemas em `Q-110`. Repetição da noite perdida com espectadores em `Q-109`.
- Consequências diretas (sem regra nova): espectador segue **presente** (DEC-067, DEC-085).
- Responde `Q-099`.
- Impacto: `design/features.md` (estado spectate permanente), `design/economy.md` (fluxo de clientes com party menor, `Q-067`), `tech/architecture.md` (estado por jogador), UI do spectate.

### DEC-094 — 2026-10-08 — Todos caem: janela de 10 s para reviver (Q-100, em parte)

- Decidido: "Todos caem a noite, 10 segundos é o tempo limite para reviver, caso contrário todos perdem."
  - Quando o **último jogador de pé cai**, abre uma **janela de 10 s** para alguém **reviver** (pagar).
  - Se ninguém reviver em 10 s: **"todos perdem"**.
- **Oposto da recomendação** de `Q-100` (A: noite perdida na hora). Corresponde à opção (B), com janela fixa de 10 s.
- **Ambíguo** (não decidido): "todos perdem" = **noite perdida** (gasta 1 chance do chefe e repete a noite, DEC-053) ou **fim da run**? Também: quem paga na janela, se todos estão caídos (cada um por si? qualquer um por qualquer um?). Ver `Q-109`.
- Segue igual até nova DEC: regra crítica perde a noite direto (DEC-053, DEC-074), sem janela.
- Responde `Q-100` em parte.
- Impacto: `design/features.md` (estado "todos caídos" + timer de 10 s), UI (contador), `tech/architecture.md`.

### DEC-095 — 2026-10-08 — Carros atropelam: ragdoll, tempo no chão, volta a andar (Q-101; contra a recomendação)

- Decidido: "O carro pode atropelar sim, eles são arremessados em ragdoll mas continuam andando normal depois de um tempo no chão."
  - Carro do trânsito (DEC-087) que bate no jogador **arremessa** o jogador em **ragdoll**.
  - O jogador fica **um tempo no chão** e depois **volta a andar normal**. Sem morte, sem dano de vida.
- **Oposto da recomendação** de `Q-101` (A: carro freia e espera).
- **Tom**: pastelão (slapstick), sem sangue, sem ferimento, sem som de impacto realista. Tensão com DEC-023 ("sem violência") anotada: leitura do secretário (**não decisão**) é que o arremesso cômico é compatível se mantido em tom de desenho animado. Direção com art-director (VFX/áudio) e narrative-writer.
- Não decidido: tempo no chão; se tira sanidade à noite; se derruba o item da mão; se NPCs também são atropelados (`Q-111`).
- Responde `Q-101`.
- Impacto: `tech/architecture.md` (ragdoll R6 no servidor/client, colisão carro–jogador, `Q-102`), `design/features.md`, `levels/MAP-01.md` (travessia trailer–Mart), `art/` (VFX/SFX cômicos).

### DEC-096 — 2026-10-08 — Prefixo `ANM-###` para anomalias (Q-063, opção 1)

- Decidido: "Prefixo ANM para anomalias."
- `ANM-###` = anomalia. **N1 = ANM-001 … N10 = ANM-010** (mesma ordem de `story/anomalies.md`).
- Linha já adicionada à tabela de IDs do `CLAUDE.md` pelo orquestrador (onde: `docs/story/anomalies.md`).
- Ficha técnica em `design/` continua com o game-designer; ator pode ter `NPC-###` próprio, referenciando o `ANM-###`.
- Responde `Q-063`.
- Impacto: `story/anomalies.md` (cabeçalho anotado), `design/`, `levels/`, `tech/content-data.md`.

### DEC-097 — 2026-10-08 — Sem braços; câmera 1ª pessoa padrão do Roblox; jogador R6 (Q-073; Q-105 em parte)

- Decidido: "sem braços em 1a pessoa, vamos usar o padrão do roblox mesmo em 1a pessoa R6."
  - **Sem viewmodel** de braços em 1ª pessoa. Só a Tool aparece na mão (como `style-guide.md` §4.4 já sugeria).
  - Câmera em 1ª pessoa **padrão do Roblox** (travada, DEC-039).
  - **Avatares dos jogadores em R6** (o jogo força R6). Junto com DEC-089 (NPCs R6), todo personagem é R6.
- Responde `Q-073` e a parte de `Q-105` sobre o rig dos jogadores.
- Impacto: `art/style-guide.md` §4 (R6 para todos), `tech/architecture.md` (configuração de avatar R6), cutscene POV com avatares visíveis (DEC-088), ragdoll (DEC-095), escala (`Q-095`).

### DEC-098 — 2026-10-08 — Membro que não chega em 60 s entra depois (Q-071; contra a sugestão)

- Decidido: "Quem não chega em 60s não fica de fora, a partida inicia normalmente e ele apenas spawna depois."
  - A run **começa** no fim da janela de 60 s com quem chegou.
  - O membro atrasado **entra quando chegar** e spawna normalmente.
- **Oposto da sugestão** do architect (`Q-071`: run começa sem ele, fora).
- Não decidido: tamanho da party para preço do trailer (DEC-047) e fluxo de clientes (party do lobby ou quem chegou?); atrasado vê a cutscene de abertura?; até quando o atrasado pode entrar (`Q-112`).
- Responde `Q-071`.
- Impacto: `tech/architecture.md` (P8; whitelist da party do lobby no servidor reservado), `design/economy.md`.

### DEC-099 — 2026-10-08 — Opal confirmada (DEC-079)

- Decidido: o usuário pediu explicação; o orquestrador descreveu Opal (atendente do Ninth Street Mart, CHR-003, fala curta em balão, não vende). Resposta: "pode ser o recomendado."
- **Confirma DEC-079** e a leitura do secretário registrada nela. Nada muda.
- Impacto: nenhum novo.

---

Origem das DEC-100 a DEC-105: resposta do usuário à rodada 11, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 11", uma mensagem escrita).
Não respondido nesta rodada: `Q-110` (resolvida por consequência de DEC-104), iluminação Future e aprovação do `style-guide.md` (`Q-123`), retorno de espectadores na noite repetida (`Q-121`).
Mesma regra de números de DEC-044: valores em tabela, ajustáveis sem nova DEC; mudar **regra** exige DEC.

### DEC-100 — 2026-10-08 — Item raro de reviver: vendido no Mart, guardado na hotbar (Q-108, em parte)

- Decidido: "O item de reviver aparece na loja normal do jogo aonde se compram ingredientes e upgrades. [...] O item fica guardado na hotbar."
  - O item raro de reviver (DEC-092) é vendido na **loja do Mart** (Ninth Street Mart), a mesma onde se compram ingredientes e upgrades. Não é loja do lobby.
  - É um **item na hotbar** (Tool consumível, DEC-040). Ocupa vaga no limite da hotbar (`Q-056`).
- **Moeda: não dita.** Leitura do secretário (**não decisão**, perguntada ao usuário): **dinheiro da party na run**, porque é a moeda dessa loja. Pendente em `Q-118`. Até a confirmação, vale como **Provisória** só para rascunho de design; nenhuma tarefa de economia do item antes da resposta.
- Lido junto de DEC-101: o item aparece **por sorteio** na oferta rotativa da bancada do Mart ("raramente", DEC-092).
- Não decidido: chance/frequência, preço ("bem caro"), uso (prompt sobre o colega caído ou na ambulância), se funciona na janela de 10 s (DEC-094) → `Q-120` (game-designer).
- Responde `Q-108` (a) e (e). (b) vai para `Q-118`; (c), (d), (f) para `Q-120`.
- Impacto: `design/items.md` (ITM do item de reviver), `design/economy.md`, `design/features.md` (uso do item), `art/asset-list.md` (modelo da Tool e ícone).

### DEC-101 — 2026-10-08 — Mart: prateleiras, frutas/verduras e bancada de upgrades com oferta que muda a cada turno (Q-084; emenda leitura de DEC-046 e DEC-049)

- Decidido: "no mercado vai ter a pareteleira e lugar de frutas / verduras e no fundo vai ter uma loja na parede uma bancada aonde tem upgrades e todo novo turno, os itens ali atualizam."
  - Layout do Mart: **prateleiras** (ingredientes, como DEC-049), **área de frutas/verduras**, e **no fundo, na parede, uma bancada de upgrades** (loja).
  - **Upgrades são comprados na bancada do Mart.** Não no próprio equipamento.
  - A oferta da bancada **muda a cada turno novo** (rotação). O item raro de reviver entra por essa rotação (DEC-100).
- Fecha `Q-084`: a sugestão do level-designer (prompt no próprio equipamento, `MAP-01.md` §15 P5 1ª parte) **não** vale. `Q-075` (nível do equipamento passa do carrinho para o trailer) segue aberta, sem mudança.
- **Emenda leitura de DEC-046** (upgrades de referência): a lista e os preços seguem; muda o **lugar de compra** e, conforme `Q-116`, a **disponibilidade** por turno. **DEC-049** segue (pacote físico nas prateleiras); o Mart ganha a bancada e a área de frutas/verduras. **DEC-079** segue: Opal não vende; a bancada é loja na parede (sem vendedor), por prompt (DEC-015, DEC-066).
- Ambíguo (**não decidido**, perguntado ao usuário):
  - Se **tudo** rotaciona ou se os **upgrades básicos** ficam sempre à venda e só os **especiais** (reviver) entram no sorteio → `Q-116`.
  - Se o **Food Trailer** fica fora da rotação (compra fixa a partir do dia 5, DEC-037, DEC-047) → `Q-117`.
  - Se frutas/verduras são só cenário ou ingredientes novos → `Q-119`.
- Regras da rotação (slots, pesos, garantias) com o game-designer → `Q-120`.
- Riscos anotados (não resolvidos): se upgrades essenciais podem faltar, a curva de `design/progression.md` (tudo comprado ~Day 8, DEC-082) muda; Trailer Lights e a N3 (`Q-064`); compra de upgrade exige ir ao Mart (100–120 studs, também à noite, DEC-049, DEC-041).
- Responde `Q-084`.
- Impacto: `levels/MAP-01.md` (interior do Mart: bancada na parede do fundo, área de frutas/verduras; P5 1ª parte superada), `design/upgrades.md` (compra na bancada, rotação), `design/economy.md`, `design/progression.md`, `art/asset-list.md` (bancada, expositor de frutas/verduras), `tech/` (oferta por turno no servidor, replicada para a party).

### DEC-102 — 2026-10-08 — Ninguém revive em 10 s: a party perde a noite, não a run (Q-109; completa DEC-094)

- Decidido: "A party perde a noite inteira se não reviver após os 10 segundos."
  - Todos caídos e ninguém revive na janela de 10 s (DEC-094) = **noite perdida**: gasta **1 chance do chefe** e repete a noite (DEC-053). Não é fim da run.
  - Fim da run só quando acabam as chances (DEC-053, DEC-057), como antes.
- Opção **A** de `Q-109` (recomendada). Completa DEC-094 ("todos perdem" = noite).
- Não decidido (desdobramentos de `Q-109`, sem resposta):
  - Espectadores permanentes (DEC-093) **voltam** na noite repetida? → `Q-121` (usuário).
  - Quem pode pagar/usar o reviver na janela quando todos estão caídos → `Q-107` (game-designer).
- Responde `Q-109`.
- Impacto: `design/features.md` (estado "todos caídos" → noite perdida), `design/progression.md`, `story/script.md` (representação da noite perdida, `Q-106` b).

### DEC-103 — 2026-10-08 — Atropelamento derruba o item da mão e não tira sanidade (Q-111, em parte)

- Decidido: "o atropelamento pode derrubar o item da mão e não retirar sanidade."
  - Atropelamento (DEC-095) **derruba o item da mão** (pacote, hot dog, café etc.).
  - Atropelamento **não tira sanidade**, nem à noite.
- Recomendação de `Q-111` aceita.
- Leitura do secretário (**não decisão**): "pode derrubar" lido como "derruba"; o item cai no chão e pode ser pego de novo (texto da recomendação). Se o game-designer propuser chance em vez de sempre, é número/regra a confirmar em `Q-122`.
- Não decidido (vai para `Q-122`, game-designer + architect): tempo no chão, NPCs atropelados ou não, ambulância atropela, cooldown, regra exata do item derrubado.
- Responde `Q-111` (a) e (b).
- Impacto: `design/features.md` (ragdoll + drop da Tool), `tech/architecture.md`.

### DEC-104 — 2026-10-08 — Gemas creditadas e salvas a cada evento (Q-078, opção A; emenda DEC-070 e DEC-085)

- Decidido: "gemas salvas a cada evento." Opção **A** de `Q-078` (recomendada).
  - Fontes e valores de DEC-070, DEC-083 e DEC-084 seguem iguais (dia concluído, nota A, noite vencida, final, Day 100).
  - Cada gema é **creditada e salva no DataStore no instante do evento**, sem esperar a tela de resumo.
- **Emenda DEC-070** (não a edita): sai "creditadas no fim de cada turno (tela de resumo)"; entra "creditadas e salvas no instante de cada evento". A tela de resumo **mostra** o que já foi creditado.
- **Emenda DEC-085 (b)** (não a edita): sai "gemas do turno só para quem está no servidor no resumo"; entra "recebe quem está no servidor **no instante do evento**". Quem estava desconectado no evento não recebe aquele evento. Quem desconecta **mantém** as gemas de eventos já ocorridos.
- Consequências diretas (sem regra nova):
  - DEC-080: turno interrompido segue sem gema (o evento "turno concluído" não ocorreu).
  - Espectador (DEC-093) e jogador "fora" seguem recebendo por estarem presentes (DEC-070, DEC-085 c).
  - **Fecha `Q-110` por consequência**: as gemas já ganhas estão salvas, então sair da run (inclusive o espectador) não perde gema. Sair conta como desconectado (DEC-085). Nada além disso foi decidido.
- Responde `Q-078` e `Q-110`. Destrava a tarefa de `RewardService`.
- Impacto: `design/economy.md`, `design/progression.md`, `tech/architecture.md`, `tech/data.md` (save por evento; atenção ao limite de escrita do DataStore — architect agrupa se necessário, sem perder o crédito), `RewardService`.

### DEC-105 — 2026-10-08 — Estilo visual "toy low-poly" aprovado (Q-072, em parte)

- Decidido: "visual low poly aprovado." Estilo **A "toy low-poly"** de `art/style-guide.md` §1.1 (com atlas de gradiente, como na recomendação) é o estilo do jogo.
- Vale junto de DEC-089 e DEC-097 (todo personagem R6).
- **Não aprova** o `style-guide.md` inteiro: o documento segue **Rascunho**. Iluminação **Future** (§5.1) e aprovação do documento → `Q-123`.
- Consequência: fichas `AST-###` podem ser escritas no estilo aprovado; só vão ao modeler-3d com status **Aprovado** (regra de `CLAUDE.md`).
- Responde `Q-072` em parte (estilo).
- Impacto: `art/style-guide.md` (§1.1 marcado como decidido), `art/asset-list.md`, `vision.md` §5.

---

Origem das DEC-106 a DEC-109: resposta do usuário à rodada 12, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 12", uma mensagem escrita: "pode seguir com os recomendados").
Aprovação **em bloco** das recomendações das três perguntas feitas pelo orquestrador (`Q-116` a `Q-119`).
Não perguntado nesta rodada: `Q-121` (espectadores na noite repetida), `Q-123` (iluminação Future e aprovação do style guide).
Mesma regra de números de DEC-044: valores em tabela, ajustáveis sem nova DEC; mudar **regra** exige DEC.

### DEC-106 — 2026-10-08 — Bancada do Mart: upgrades básicos sempre à venda; só especiais no sorteio (Q-116, opção A)

- Decidido: "pode seguir com os recomendados." Opção **A** de `Q-116` (recomendada).
  - Upgrades **básicos** ficam **sempre à venda** na bancada do Mart (DEC-101): Grill, Cooler, Counter (níveis), Cash Drawer Lock, Trailer Lights (DEC-046). Não saem da oferta em nenhum turno.
  - Só itens **especiais** entram no **sorteio** de cada turno. Hoje o único especial é o **item raro de reviver** (DEC-100). Especial novo exige DEC.
- Consequências diretas (sem regra nova):
  - Trailer Lights segue "só com o trailer" (DEC-055): aparece na bancada a partir da compra do trailer e fica fixo dali em diante.
  - A curva "tudo comprado ~Day 8" (DEC-082) não depende de sorteio. Garantias de sorteio para básicos (`Q-120` c) deixam de ser necessárias.
  - Risco da N3 / Trailer Lights (`Q-064`) não aumenta pela rotação.
- Nota: a pergunta do orquestrador listou também a **cafeteira** entre os básicos. Por DEC-055 a cafeteira é **fixa no trailer** (vem com ele, não é comprada). Esta DEC **não** muda DEC-055. Contradição registrada em `Q-124` (não bloqueante).
- Responde `Q-116`.
- Impacto: `design/upgrades.md` (oferta fixa + slot(s) de especial), `design/economy.md`, `design/progression.md`, `levels/MAP-01.md` (layout da bancada), `tech/` (oferta por turno só para especiais), `Q-120`.

### DEC-107 — 2026-10-08 — Food Trailer fora da rotação; compra fixa a partir do dia 5 (Q-117)

- Decidido: "pode seguir com os recomendados." Recomendação de `Q-117` aceita (foi dita ao usuário na mesma pergunta da bancada).
  - O **Food Trailer** **não** entra na rotação da bancada.
  - Compra **fixa**, disponível **a partir do dia 5**, por prompt, como já decidido (DEC-028, DEC-037, DEC-047). Preço segue $300 × party (DEC-047).
- Motivo registrado: o marco do trailer (DEC-007) não pode depender de sorteio.
- Não muda o **lugar** do prompt de compra do trailer (segue o que já está em `vision.md` §8.1 e `levels/MAP-01.md`).
- Responde `Q-117`.
- Impacto: `design/upgrades.md`, `design/progression.md`, `levels/MAP-01.md`.

### DEC-108 — 2026-10-08 — Item raro de reviver pago com dinheiro da party na run (Q-118; confirma leitura de DEC-100)

- Decidido: "pode seguir com os recomendados." O item raro de reviver (DEC-100) é pago com o **dinheiro da party na run** (moeda da loja do Mart). Não é gema nem Robux.
- **Como foi perguntado**: o orquestrador apresentou como **suposição** do secretário ("suponho... confirma?"), não como opções com recomendação. O usuário aprovou **em bloco** ("os recomendados"). Leitura registrada: suposição confirmada.
- Confirma a leitura da DEC-100; o status **Provisória** daquela leitura sai. Tarefas de economia do item ficam liberadas para rascunho com o game-designer.
- Não muda DEC-092: o **reviver pela ambulância** segue pago com **Robux** (preço `Q-098`, adiado). São dois caminhos de reviver com moedas diferentes.
- Não decidido (segue em `Q-120`): chance no sorteio, preço ("bem caro", DEC-092), limite, uso, janela de 10 s.
- Responde `Q-118`.
- Impacto: `design/items.md`, `design/economy.md`, `design/features.md`, `Q-120`.

### DEC-109 — 2026-10-08 — Frutas/verduras do Mart só cenário no MVP (Q-119, opção A)

- Decidido: "pode seguir com os recomendados." Opção **A** de `Q-119` (recomendada).
  - A área de frutas/verduras do Mart (DEC-101) é **só cenário** no MVP: sem prompt de compra, sem ingrediente.
  - Ingredientes do MVP seguem os de DEC-071 (pão, salsicha + 6 complementos). DEC-071 e DEC-011 **não** são emendadas.
  - Ingredientes de fruta/verdura (ex.: cebola, pickles) ficam para **atualização futura**, com DEC própria.
- Responde `Q-119`.
- Impacto: `levels/MAP-01.md` (expositor decorativo), `art/asset-list.md` (props de cenário), `design/items.md` (nada novo).

---

Origem das DEC-110 e DEC-111: resposta do usuário à rodada 13, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 13", duas mensagens escritas).
Pergunta feita: `Q-121` (espectador volta na noite repetida?). O usuário pediu explicação de "repetir noite perdida"; o orquestrador explicou as chances do chefe (DEC-053, DEC-057). Na resposta, o usuário mudou também o número de chances.
Não respondido: `Q-124` (cafeteira; usuário não comentou, segue aberta), `Q-123`.

### DEC-110 — 2026-10-08 — Chances do chefe: 1 por run (emenda DEC-053 e DEC-057)

- Decidido: "eles só tem uma única chance nesse caso."
  - **Chances do chefe = 1** por run (era 3, DEC-057).
  - A party pode perder e repetir **uma** noite **uma vez** na run. A **segunda** noite perdida (a mesma repetida ou qualquer outra) = **fim da run**.
- **Leitura do secretário**: "uma única chance" = **por run**. Leitura alternativa (1 por noite: cada noite pode ser repetida uma vez) **não** vale até confirmação. Ver `Q-125` (não bloqueante).
- **O que muda em DEC-053**: "Chances por run: cenário L = 3" passa a **1**. Resto de DEC-053 igual (repete a noite com o estado do início dela, perde o faturamento da noite; sem chances = fim da run; chances só na ligação e na tela de fim de noite, não no HUD).
- **O que muda em DEC-057**: o item "DEC-053: 3 chances do chefe por run" sai. Resto do cenário L igual (trailer no dia 5, 10 noites de 20–30 min, ~6 h).
- Número de chances segue em tabela de run (DEC-044); valor padrão = 1. Mudar a **regra** (por run x por noite) exige DEC.
- Consequências diretas (sem regra nova):
  - Gemas no fim por falha seguem DEC-070/DEC-104 (ficam as já creditadas).
  - Risco anotado: run de ~6 h que pode acabar na 2ª noite perdida. Contrapeso: janela de 10 s e reviver (DEC-092, DEC-094, DEC-100); risco oposto de noites 1–6 fáceis segue em `Q-115`. Medir em playtest.
  - Texto da ligação "Rough night. Let's try that again." (DEC-053) e a tela de fim de noite precisam deixar claro que **não há outra chance** (narrative-writer).
- Impacto: `design/progression.md`, `design/features.md`, `design/economy.md`, `story/script.md` (ligação de noite perdida e de fim de run), `tech/architecture.md` (contador de chances = 1 na tabela de run), `vision.md` §8.1 e §8.3.

### DEC-111 — 2026-10-08 — Noite repetida: todos voltam, inclusive espectadores (Q-121; contra a recomendação; emenda DEC-093)

- Decidido: "e sim todos voltam."
  - Quando a party perde a noite e ela é **repetida** (DEC-053, DEC-102, DEC-110), **todos** os jogadores da party voltam a jogar no início da noite repetida, **inclusive espectadores permanentes** (DEC-093).
  - Sanidade de todos no início da noite repetida = valor de início de noite (100, ou o da classe; DEC-056, DEC-069). Consequência de DEC-056, não regra nova.
- **Oposto da recomendação** do orquestrador ("não volta"). Vai além da sugestão (A) que estava em `Q-121` (só quem caiu na noite perdida).
- **Leitura do secretário**: "todos" = também quem virou espectador em **noite anterior** (não só na noite perdida). Confirmação em `Q-126` (b).
- **O que muda em DEC-093**: "spectate até o fim da run / não volta mais" passa a ser: spectate **até o fim da run, exceto** se a party perder a noite e ela for repetida; nesse caso o espectador volta a jogar **no início da noite repetida**.
- **Não dito**: se a noite é **vencida**, o espectador segue espectador até o fim da run (DEC-093 como está) — vale assim até nova DEC. Ver `Q-126` (a).
- Com DEC-110 (1 chance), isso acontece **no máximo uma vez** por run.
- Responde `Q-121`.
- Impacto: `design/features.md` (estado spectate: saída na repetição), `tech/architecture.md` (snapshot de início de noite restaura estado de jogo de todos os jogadores; espectador vira ativo), `story/script.md` (cena de recomeço com todos), UI do spectate.

---

Origem das DEC-112 e DEC-113: resposta do usuário à rodada 14, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 14", uma mensagem escrita).
Perguntas feitas: `Q-125` e `Q-126` (a). `Q-126` (b) respondida pela mesma fala.
Não perguntado: `Q-124` (cafeteira), `Q-123` (iluminação e style guide).

### DEC-112 — 2026-10-08 — Chance do chefe é 1 por run inteira (Q-125; confirma DEC-110)

- Decidido: "sim, partida inteira."
  - A chance única do chefe (DEC-110) vale para a **run inteira**, não por noite.
  - Na run, só **uma** noite perdida é repetida. A **segunda** noite perdida (a mesma ou outra) = **fim da run**.
- Confirma a leitura de DEC-110. A leitura alternativa (1 por noite) fica **descartada**.
- Regra nova: nenhuma. Valor padrão segue 1 na tabela de run (DEC-044).
- Responde `Q-125`.
- Impacto: nenhum documento muda além do já listado em DEC-110.

### DEC-113 — 2026-10-08 — Espectador só volta na noite repetida (Q-126; confirma DEC-093 e DEC-111)

- Decidido: "party não volta no turno seguinte, somente se todos perderem e dai ele usa a chance e todos voltam."
  - "party" = o espectador (jogador caído). Leitura do orquestrador.
  - (a) Noite **vencida**: o espectador **não** volta no turno (dia) seguinte. Segue espectador até o fim da run.
  - Única saída do spectate: a party **toda perde** a noite e a chance do chefe é usada (DEC-102, DEC-110, DEC-112). Aí **todos voltam** no início da noite repetida.
  - (b) "Todos" inclui quem virou espectador em **noite anterior**, não só na noite perdida.
- Confirma DEC-093 (como emendada por DEC-111) e a leitura do secretário em DEC-111. Regra nova: nenhuma.
- Com DEC-112, a volta acontece **no máximo uma vez** por run.
- Responde `Q-126` (a) e (b).
- Impacto: nenhum documento muda além do já listado em DEC-093 e DEC-111.

---

Origem das DEC-114 a DEC-129: resposta do usuário à rodada 15, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 15", uma mensagem escrita: "1. médicos descem e pegam o corpo, resto recomendações").
Tabela de 15 itens, cada um com recomendação. Item 1 escolhido explicitamente; itens 2–15 aprovados como recomendados.
DEC-129 registra dois números ditos ao usuário como "confirme só se discordar" — aprovados **em bloco pela leitura** (não contestados).
DEC-117 a DEC-120 são propostas técnicas do architect (`tech/architecture.md` §15, D1–D4), aprovadas pelo usuário nos itens 4–7.

### DEC-114 — 2026-10-08 — Ambulância na ida: médicos descem e levam o corpo (item 1; Q-104 em parte; contra a proposta do art-director)

- Decidido: "médicos descem e pegam o corpo."
  - Na **ida** (coleta do desmaiado), os **médicos descem** da ambulância, vão até o corpo e o levam. Igual a DEC-091 passo 2.
  - Na **volta** do reviver, **ninguém desce** (DEC-091 passo 3, sem mudança).
- **Não escolhida**: proposta do art-director (`art/asset-list.md` AST-052; `art/style-guide.md` §4.6) de **maca automática** saindo pela traseira, sem ninguém descer.
- Regra nova: nenhuma. Confirma DEC-091.
- **Conflito com documento Aprovado**: `style-guide.md` §4.6, linha "Ambulância leva", proíbe "paramédico descendo" e descreve a maca automática. Vale esta DEC (autoridade 1). Alinhamento em `Q-127`.
- Fora do escopo desta DEC: o caso "corpo inacessível" de FEAT-034 (maca aparece na parada e o corpo some em fade) segue **Rascunho** do game-designer; não foi perguntado.
- Responde `Q-104` em parte (forma de levar o corpo). Resto das fichas segue com o art-director.
- Impacto: `art/asset-list.md` AST-052 (médicos R6 com animação de descer/levar; maca carregada à mão), `art/style-guide.md` §4.6, `design/features.md` FEAT-034 (já descreve médicos descendo), `story/script.md` (já descreve).

### DEC-115 — 2026-10-08 — Prazo do reviver: até 6:00 AM da noite da queda (item 2; Q-107 em parte)

- Decidido (recomendação do game-designer, FEAT-034, aprovada):
  - Quem cai pode ser revivido (Robux ou Revive Kit) até as **6:00 AM** da **mesma noite** em que caiu.
  - Às 6:00 AM, quem ainda está caído vira **espectador** (DEC-093, como emendada por DEC-111 e DEC-113).
  - Exceção: quando **todos** caem, a janela de 10 s decide a noite (DEC-094, DEC-102, DEC-118).
- Responde a parte "oferta durante todo o spectate ou só na noite da queda" de `Q-107`.
- Impacto: `design/features.md` FEAT-025 e FEAT-034 (já descrevem), UI do spectate.

### DEC-116 — 2026-10-08 — Reviver com Robux: só o próprio jogador (item 3; Q-107 em parte)

- Decidido: o reviver por **Robux** (DEC-092) só pode ser comprado pelo **próprio caído**, para si mesmo. Ninguém paga Robux pelo colega.
- Motivo registrado (game-designer): público infantojuvenil (DEC-023), sem pressão social para pagar pelo amigo.
- Não muda: o **Revive Kit** (item da loja, dinheiro da party) segue a proposta de uso de FEAT-034 (próprio caído ou colega de pé com o Kit), ainda **Rascunho** em `Q-120` (f).
- Na janela de 10 s: cada caído compra só para si (consequência, não regra nova).
- Responde a parte "quem pode pagar" de `Q-107`.
- Impacto: `design/features.md` FEAT-034, `tech/architecture.md` (`MonetizationService`: comprador = alvo), UI do spectate.

### DEC-117 — 2026-10-08 — Recibo de Robux sem alvo vira crédito de reviver no perfil (item 4; architect D1)

- Decidido (proposta D1 do architect, aprovada):
  - Recibo de reviver por Robux que **não pode ser aplicado** (janela fechou, jogador já revivido, comprador saiu, noite já perdida) é sempre concedido como **1 crédito de reviver** guardado no **perfil persistido** do jogador.
  - O crédito pode ser usado num reviver futuro do mesmo jogador (uso exato: architect + game-designer, sem regra nova).
- Motivo: sem isso o jogador paga e não recebe.
- Substitui a proposta de FEAT-034 "crédito de reviver do jogador **na run**": vale **no perfil** (persistido).
- Impacto: `tech/architecture.md` §10.2 e §15, `tech/data.md` (campo `ReviveCredits`), `tech/content-data.md` (`CreditOnUnapplied = true`), `tech/network.md` (`Notice` de crédito recebido), `design/features.md` FEAT-034.

### DEC-118 — 2026-10-08 — Janela de 10 s congela com prompt de compra aberto, até +20 s (item 5; architect D2; emenda leitura de DEC-094)

- Decidido (proposta D2 do architect, aprovada):
  - Durante a janela de 10 s (todos caídos, DEC-094), se um caído está com o **prompt de compra de reviver aberto**, o contador **congela**.
  - Teto de extensão: **+20 s** no total. Depois do teto, o contador volta a correr.
- **O que muda na leitura de DEC-094**: "10 segundos é o tempo limite" passa a ser **10 s de contador**, que pode parar por até 20 s enquanto há compra em andamento (máximo real 30 s). DEC-094 não é editada.
- Motivo: o fluxo de compra do Roblox leva 2–8 s; sem isso o jogador paga e perde a noite (risco R17).
- Impacto: `tech/architecture.md` §6.2, `tech/content-data.md` (`WipeFreezeOnPrompt = true`, extensão máx. 20 s), `design/features.md` FEAT-034 (já descreve), UI do contador.

### DEC-119 — 2026-10-08 — Retomada de 15 min vale também para queda do servidor (item 6; architect D3; completa DEC-080)

- Decidido (proposta D3 do architect, aprovada):
  - Se o **servidor** da run cair (não só os jogadores saírem), a run pode ser retomada pelo mesmo mecanismo de DEC-080: snapshot do início do turno, TTL **15 min**, mesmo roster.
- Regra nova: só amplia o gatilho de DEC-080. Resto igual (recomeça no início do turno corrente; ninguém novo entra).
- Responde `Q-058` em parte. Segue aberto em `Q-058`: (e) saída **voluntária** de todos, e os itens técnicos (a)–(d), (f), (g).
- Impacto: `tech/architecture.md` T16/T17, `tech/data.md`.

### DEC-120 — 2026-10-08 — Semáforo com faixa de pedestre na travessia trailer ↔ Mart e nos cruzamentos (item 7; architect D4)

- Decidido (proposta D4 do architect, aprovada):
  - **Semáforo com faixa de pedestre** na travessia entre trailer e Mart e nos cruzamentos.
  - **Carros obedecem** ao semáforo. **NPCs** só atravessam no **verde** de pedestre.
  - Jogadores **não** são impedidos de atravessar no vermelho (o risco de atropelamento, DEC-095, segue). Leitura do secretário: a proposta só restringe carros e NPCs.
- Motivo: dá rota segura e evita simular fila de carros.
- Responde `Q-102` em parte (travessia segura). Seguem abertos em `Q-102`: rotas, quantidade, dia/noite, teto, simulação.
- Impacto: `levels/MAP-01.md` (posição das faixas e semáforos), `art/asset-list.md` (semáforo, faixa; ficha nova), `tech/architecture.md` §8.1, `design/npcs.md` (NPC atravessa no verde), `Q-103` (N8 com trânsito: checar com semáforo).

### DEC-121 — 2026-10-08 — Tamanho da party para preços: quem entrou até o fim do Day 1 (item 8; Q-112 a; reinterpreta DEC-047)

- Decidido:
  - O multiplicador de party do **preço do trailer** conta os membros do roster que **entraram no servidor até o fim do Day 1**. Fixo dali em diante; não muda se alguém sair.
  - Mesmo multiplicador vale para o preço do Revive Kit (DEC-129).
- **O que muda em DEC-047**: "tamanho da party lido **no início da run**" passa a ser "lido **no fim do Day 1**". Valores (×1,0 / 1,5 / 1,9 / 2,2) não mudam.
- Motivo: com DEC-098 (atrasado entra depois), o "início da run" podia contar menos gente do que joga.
- Responde `Q-112` (a). Seguem abertos (b), (c), (d).
- Impacto: `design/features.md` FEAT-001, `design/economy.md`, `design/upgrades.md`, `tech/architecture.md`.

### DEC-122 — 2026-10-08 — Noite perdida: todos acordam em pé ao lado do trailer, não no banco (item 9; Q-106 b; emenda DEC-053)

- Decidido (proposta do narrative-writer, `story/script.md`, aprovada):
  - Na representação da **noite perdida**, todos acordam **em pé na calçada, ao lado do trailer**, enquanto a ambulância vai embora com a sirene desligada. Sem banco.
- **O que muda em DEC-053**: "jogador acorda no banco ao amanhecer" sai. O resto da representação fica (luzes piscam e apagam, tela escurece, chefe liga).
- **Conflito com documento Aprovado**: `story/anomalies.md` N7 "Consequência" diz "todos acordam no banco ao amanhecer". Vale esta DEC. Anotação no `anomalies.md` não foi feita nesta rodada (instrução limitou a anotação ao sinal do Walker); registrar na próxima edição autorizada.
- Responde `Q-106` (b). Seguem abertos (a) e (c).
- Impacto: `story/script.md`, `story/anomalies.md` (N7, consequência), `design/features.md` FEAT-026, `vision.md` §8.3.

### DEC-123 — 2026-10-08 — Sinal de início do Walker: o último poste da Juniper zumbe ~2 s (item 10; Q-113 b)

- Decidido (proposta do narrative-writer, `story/script.md`, aprovada):
  - Quando a ANM-007 (The Walker) começa, o **último poste da Juniper zumbe** (zumbido elétrico grave que sobe por **~2 s** e para seco), ouvido por **todos** da party.
  - A alucinação do poste (sanidade < 40) **pisca sem zumbir**; o zumbido só existe no Walker real.
- Não muda a regra aprovada da N7 (DEC-073, DEC-074): só acrescenta o sinal sonoro de início. `anomalies.md` (Aprovado) recebe **anotação** com esta DEC, sem mudar o conteúdo.
- **Conflito com documento Aprovado**: `art/style-guide.md` §11 diz "sobe por ~1,5 s e corta com um estalo". Vale esta DEC (**~2 s**). Alinhamento em `Q-127`.
- Responde `Q-113` (b). Segue aberto (a) (prompts "Answer"/"Take").
- Impacto: `story/anomalies.md` (anotação), `art/style-guide.md` §11, áudio.

### DEC-124 — 2026-10-08 — Ligações pelo telefone fixo do veículo; celular flip só na cutscene de abertura (item 11; Q-076)

- Decidido:
  - **Todas** as ligações da run (dia no carrinho, noite no trailer) tocam no **telefone fixo do veículo** (AST-042). Qualquer jogador atende com "Answer"; viva-voz para a party (FEAT-018).
  - O **celular flip** (AST-038) aparece **só** na cutscene de abertura.
- Motivo: em party, telefone no mundo evita "de quem é o celular?" e não ocupa vaga na hotbar (DEC-040).
- Responde `Q-076`.
- Impacto: `art/asset-list.md` AST-038 e AST-042, `story/script.md`, `story/characters.md`, `story/world.md` §4.1, `design/features.md` FEAT-018.

### DEC-125 — 2026-10-08 — Cafeteira fixa no trailer (item 12; Q-124; confirma DEC-055)

- Decidido: a **cafeteira** vem **fixa no trailer** (DEC-055). Não é vendida na bancada.
  - No Mart, só o **estoque de café** (pacote 10 doses $5, DEC-055).
- A menção à "cafeteira" na pergunta da rodada 12 (DEC-106) fica **sem efeito**. DEC-106 segue para Grill, Cooler, Counter, Cash Drawer Lock e Trailer Lights.
- Regra nova: nenhuma.
- Responde `Q-124`.
- Impacto: `design/upgrades.md` (UPG-007), `design/features.md` FEAT-015.

### DEC-126 — 2026-10-08 — `art/style-guide.md` aprovado: Future + fallback ShadowMap, roupa de NPC por cor por parte do corpo (item 13; Q-123; Q-105)

- Decidido: `art/style-guide.md` **inteiro aprovado**. Status → **Aprovado**.
  - Iluminação: `Lighting.Technology = Future`, com **fallback manual para ShadowMap** se a otimização futura (DEC-090) reprovar Future no celular (§5.1). Nenhuma mecânica nem leitura de anomalia depende de sombra de luz local.
  - Roupa de NPC: **opção A** de §4.1 — `BodyColors` por parte do corpo + acessórios MeshPart do atlas + decals pequenos. Opção B (`Shirt`/`Pants`) descartada.
- **Exceções** (vale a DEC, autoridade 1; texto a alinhar em `Q-127`):
  - §4.6, linha "Ambulância leva": maca automática e "paramédico descendo" proibido → substituídos por **DEC-114** (médicos descem e levam o corpo).
  - §11, sinal do Walker "~1,5 s" → substituído por **DEC-123** (~2 s).
- O que segue **não decidido** dentro do documento aprovado: a linha de §4.1 marcada "Proposta (CHR-002, não decidida)" (avental Bramble's no avatar). Aprovar o documento não decide essa proposta.
- Destrava: fichas `AST-###` podem ir a **Aprovado** uma a uma (cada uma ainda precisa de aprovação própria; DEC-126 não aprova `asset-list.md`).
- Responde `Q-123` (a) e (b) e fecha `Q-105` (§4 reescrito para R6, ragdoll em §4.6). A escala de bancadas segue em `Q-095`.
- Impacto: `art/style-guide.md` (status), `art/asset-list.md`, `README.md` linhas 11 e 13.

### DEC-127 — 2026-10-08 — Noite com duração crescente: 20 → 30 min (item 14; Q-044)

- Decidido (proposta do game-designer, `progression.md` §4.1, aprovada):
  - A duração da noite **cresce** ao longo das 10 noites, de **20** a **30 min** reais.
  - Tabela inicial (min, N1→N10): **20, 21, 22, 23, 24, 26, 27, 28, 29, 30**. Valores em tabela de run (DEC-044); ajustáveis em playtest sem DEC. Mudar para fixa exige DEC.
  - Relógio segue 8:00 PM → 6:00 AM (DEC-048); o que muda é quanto tempo real dura cada hora do jogo.
- Responde `Q-044`. Completa DEC-024 e DEC-057.
- Impacto: `design/progression.md` §4.1, `design/features.md`, `tech/content-data.md`, `vision.md` §8.1 e §8.3.

### DEC-128 — 2026-10-08 — Fora do MVP: eventos de demanda, validade de ingrediente, missões diárias (item 15; Q-022, Q-025, Q-028)

- Decidido:
  - **Eventos de demanda** (Game Night, Concert, Rain, Halloween, Special Night; GDD §13): **fora do MVP**. Pós-lançamento.
  - **Validade de ingrediente**: **não existe** no MVP. Estoque não estraga; passa de um dia para o outro (DEC-049). O Cooler só aumenta capacidade (DEC-046).
  - **Missões / objetivos diários**: **fora do MVP**. Fonte de bônus no MVP segue só o bônus do chefe pela nota do turno (DEC-051).
- Responde `Q-022`, `Q-025`, `Q-028`.
- Impacto: `vision.md` §10 e §12, `design/economy.md`, `design/upgrades.md` (Cooler).

### DEC-129 — 2026-10-08 — Limite de 2 revives por noite; Revive Kit 15% por turno, $200 × party (aprovado em bloco pela leitura; Q-107 e Q-120 em parte)

- Decidido (propostas do game-designer, ditas ao usuário como "confirme só se discordar"; **não contestadas**; registradas como aprovadas **em bloco pela leitura**, por instrução do orquestrador):
  - **Limite: 2 revives por jogador por noite**, somando Robux e Revive Kit. Na 3ª queda da mesma noite não há oferta: o jogador vira espectador na hora.
  - **Revive Kit** (ITM-021) aparece no slot especial da bancada com **15% de chance por turno** (dia e noite), só **depois da compra do trailer**.
  - Preço: **$200 × multiplicador da party** (mesmo de DEC-047, contado como em DEC-121): 1p $200 · 2p $300 · 3p $380 · 4p $440.
- Nota: aprovação por silêncio a pedido do orquestrador. Se o usuário contestar depois, vira DEC nova.
- Números em tabela (DEC-044); ajuste de número sem DEC, mudança de regra (ex.: limite por run) com DEC.
- Responde `Q-107` (limite por noite) e `Q-120` (e) em parte (chance e preço). Seguem com o game-designer: `Q-120` (a), (b), (d), (f), (h), (i); limite por turno/run do Kit.
- Impacto: `design/features.md` FEAT-034 e FEAT-035, `design/economy.md`, `design/items.md` ITM-021, `tech/content-data.md`.

---

Origem da DEC-130: resposta do usuário à rodada 16, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 16": "remove o semáforo, ele atravessa na sorte").

### DEC-130 — 2026-10-08 — Sem semáforo no MVP; jogador atravessa a rua por conta e risco (revoga DEC-120)

- Decidido: "remove o semáforo, ele atravessa na sorte."
  - **Não existe semáforo** no MVP: nem na travessia trailer ↔ Mart, nem nas faixas CW-2/3/4, nem no cruzamento em T.
  - O **jogador** atravessa a rua quando quiser, **por conta e risco**: pode ser atropelado (DEC-095, DEC-103).
  - **Carros não param por semáforo** para o jogador (não há semáforo).
- **Revoga DEC-120** inteira (semáforo, "carros obedecem", "NPCs só no verde"). DEC-120 não é editada.
- Fica **sem regra** (não decidido nesta DEC): se carros param para o jogador **na faixa de pedestre**, se as faixas continuam pintadas, e como **NPCs** atravessam. Dono: game-designer + level-designer → `Q-129`.
- Leitura do secretário: "na sorte" não define se a rota trailer ↔ Mart deve cruzar a rua. O MAP-01 rev.2 pôs o Mart do lado do trailer (rota pela CW-1, sem carros). Pergunta ao usuário em `Q-128`; até a resposta, vale o MAP-01 rev.2.
- Reabre a parte "travessia segura" de `Q-102` (agora sem semáforo).
- Impacto (cada dono edita o seu):
  - `levels/MAP-01.md`: tirar semáforos de CW-2/3/4 e do T; faixas ficam ou saem conforme `Q-129`.
  - `art/asset-list.md`: **AST-077 (semáforo) → obsoleto** (art-director; ID não é reaproveitado). Ficha de faixa conforme `Q-129`.
  - `tech/architecture.md` §8.1, T21 ("semáforo determinístico por tempo"), §15 D4, R22 (mitigação "semáforo nas faixas"); `tech/network.md`, `tech/data.md`, `tech/content-data.md` (architect).
  - `design/npcs.md`, `design/features.md` (NPC atravessa no verde → `Q-129`; game-designer).
  - `story/world.md` (cita DEC-120; narrative-writer).
  - `Q-103` (N8 com trânsito): a nota "checar com semáforo" cai.

---

Origem de DEC-131 e DEC-132: resposta do usuário à rodada 17, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 17": "B, e postes mais juntos").

### DEC-131 — 2026-10-08 — Rota trailer ↔ Mart cruza a rua com trânsito; Juniper Sul aberta a carros (Q-128 B; MAP-01 P32)

- Decidido: opção **B** de `Q-128`.
  - A rota trailer ↔ Mart **cruza a rua com trânsito**: travessia no **meio da quadra (CW-1)**, com a **Juniper Sul aberta a carros** (layout do MAP-01 rev.3, proposta P32 do level-designer).
  - **Sem semáforo** (DEC-130): o jogador atravessa por conta e risco.
  - Cada ida ao Mart **arrisca atropelamento**; atropelado derruba o item carregado (DEC-095, DEC-103), inclusive o pacote comprado.
- Confirma P32 do MAP-01 na parte **"abrir a Juniper Sul ao trânsito"**. A parte "com semáforo" de P32 não vale (DEC-130).
- **Não decidido** nesta DEC (segue com especialistas):
  - Densidade do trânsito na Juniper Sul por fase, e se há carro na Juniper (Norte e Sul) **à noite** (proposta do level-designer em P32: nenhum) → `Q-102`, `Q-103`.
  - Carro para na faixa CW-1? NPC atravessa como? → `Q-129`.
  - Item derrubado: some, fica, quem pega → `Q-122` (e).
- Substitui a leitura provisória de DEC-130 ("até a resposta vale o MAP-01 rev.2", rota sem carros).
- Responde `Q-128`.
- Impacto (cada dono edita o seu): `levels/MAP-01.md` (Juniper Sul, CW-1, rotas TR-7..TR-10, cerca do beco AST-047 sai, ladrão pela calçada leste; P24/P32 fechados); `tech/architecture.md` R22 (frustração no restock, agora sem mitigação por semáforo), §8.1; `design/features.md` FEAT-033 (trânsito); `design/economy.md` (perda de pacote no caminho); `art/asset-list.md` (AST-047); `Q-090` (rota do Mart à noite).

### DEC-132 — 2026-10-08 — Postes da Juniper a cada 8 studs; início do Walker (JL-09) a ~135 studs da janela (MAP-01 P33/LD-15; emenda DEC-126)

- Decidido: opção **1** (recomendada) de LD-15 / P33: "postes mais juntos."
  - Postes da Juniper Norte **a cada 8 studs** (eram 12).
  - **Último poste (JL-09)**, início do Walker (ANM-007), a **~135 studs** da janela do trailer (era ~165). Referência do level-designer: JL-09 em Z −88; JL-06 a ~114.
  - Os passos 0–3 do Walker ficam **além de ~110 studs**. Aceito.
- **Emenda DEC-126** (`art/style-guide.md`, Aprovado) **só neste ponto**: "fim da Juniper legível do trailer a até ~110 studs" (§5 e §9 streaming) passa a ser **~135 studs** para a cadeia de postes da Juniper e o Walker. O resto do style guide segue aprovado sem mudança.
- Teste de leitura no celular (opção 2) **não** é pré-requisito. Se o playtest mostrar Walker ilegível a 135, mudar distância exige DEC nova; ajuste de intensidade de luz/névoa não.
- Impacto (cada dono edita o seu): `levels/MAP-01.md` (§5 cadeia JL-01..JL-09, §6 linha de visão, linhas "Streaming" e "Névoa à noite", P33 fechado); `art/style-guide.md` §5 e §9 (anotação com esta DEC, art-director); `art/asset-list.md` ficha do Walker ("Conflito em aberto (LD-15)" fecha) e contagem de postes; `story/anomalies.md` N7 (distâncias, se citadas; anotação só); `tech/architecture.md` (streaming/linha de visão).

---

Origem da DEC-133: resposta do usuário à rodada 18, 2026-10-08
(`docs/source/respostas-2026-10-08.md`, seção "Rodada 18": "B, pode seguir").

### DEC-133 — 2026-10-08 — Travessia sem semáforo: PARE na Juniper, faixa com reserva só para NPC, carro nunca para por jogador (Q-129, opção B)

- Decidido: opção **B** de `Q-129` (recomendada pelo game-designer; tabela `Traffic.Crossing` em `design/features.md` FEAT-033).
  - **Cruzamento Ninth & Juniper**: Ninth é **preferencial** e nunca para. Os dois braços da Juniper (Norte e Sul) têm **placa PARE**: o carro para **1 s** na linha (SL-N / SL-S) e só entra com a caixa do cruzamento livre.
  - **Faixas CW-1..CW-4 continuam pintadas.** São o único lugar onde NPC cruza a pista. Não protegem o jogador.
  - **NPC** (clientes, passantes, médicos) só cruza na faixa, com **reserva do servidor**. A reserva só é dada sem carro a **< 15 studs** da linha da faixa. Com reserva ativa, carros que chegam **param na linha** da faixa até o NPC sair da pista.
  - Carro espera **no máx. 4 s** por reserva. Depois de liberar a faixa, nova reserva só após **4 s**. Nenhum carro fica parado dentro da faixa.
  - **Carro nunca para nem desvia por jogador**, nem na faixa (DEC-095, DEC-130: "na sorte").
  - **Spawn de carro**: só nas pontas de entrada das rotas, a **≥ 55 studs** da primeira faixa (aviso ~2,5 s a 22 studs/s; motor audível desde o spawn); **≥ 3 s** entre carros da mesma faixa de rolagem.
  - **Fluxo na Juniper Sul (CW-1), dia**: **1 carro a cada 12–20 s por sentido** (média 16 s). Referência: ~16% de atropelamento por travessia sem olhar; ~0% olhando antes. Ajustável em `Traffic.Crossing` sem nova DEC (número, não regra).
- Os demais valores da tabela `Traffic.Crossing` (tempo de NPC na pista 3 s, anti-bloqueio, noite sem carros na Juniper Sul) seguem a proposta do game-designer como **Provisórios** dentro de FEAT-033 (Rascunho). Mudar a regra acima exige DEC nova.
- Responde `Q-129` (a, b, c, d). Toca `Q-122` (b): NPCs **não** são atropelados (carros param para NPC com reserva).
- **Contradição a alinhar** (não volta ao usuário): `tech/architecture.md` T30 e §8.1, `tech/network.md` ("carro nunca para", sem campo de parada) e `levels/MAP-01.md` (linhas "Nenhum carro para em CW-1..CW-4") descartam carro parando para NPC; esta DEC exige parada na linha com reserva de NPC e parada de 1 s no PARE → `Q-131`.
- Impacto (cada dono edita o seu): `design/features.md` FEAT-033 (proposta Q-129 vira "DEC-133"), `design/npcs.md` (NPC-019, NPC-022, NPC-024, clientes, carros); `levels/MAP-01.md` §9.5, PARE-N/PARE-S, SL-*, L01-20, critérios (de "proposta Q-129 / Provisório" para DEC-133); `art/asset-list.md` AST-032 (`Crosswalk`, `Stop_Line`, placa PARE); `tech/architecture.md` §8.1, T21, T30, `tech/network.md`, `tech/content-data.md` (`Crosswalks`, estado de parada); `story/world.md` (onde o carro para), `story/characters.md` (fala de reserva de NPC atropelado não entra).

---

Origem da DEC-134: mensagem do usuário, 2026-10-09, em resposta ao pedido do orquestrador de aprovar o pacote final de fichas AST (transcrição fiel):

> ah pode modelar todos e colocar no workspace em um lugar mais afastado dai eu analiso e separamos. Ou se preferir, pode faezr no blender

### DEC-134 — 2026-10-09 — Modelagem de revisão de todas as fichas AST ativas no Studio (`workspace.AssetReview`), sem aprovar fichas

- Decidido: o usuário **autoriza modelar todas as fichas AST ativas** de `art/asset-list.md` como **versão de análise** (protótipo para revisão).
  - Exceção: **AST-077 (semáforo), obsoleto** por DEC-130. Não modelar.
  - Local: **direto no Roblox Studio**, em `workspace.AssetReview`, **afastado** do blockout `MAP01_Blockout`.
  - O usuário analisa no Studio e depois "separamos" (escolhe o que fica). O usuário ofereceu o Blender como alternativa ("se preferir"); o orquestrador escolheu o Studio.
- Exceção autorizada à regra da Fase 0 (`CLAUDE.md`: "modelagem 3D de assets cuja ficha já esteja Aprovada"), **só para esta modelagem de revisão**.
- **Não decidido** nesta DEC:
  - **Não aprova** nenhuma ficha AST nem o pacote final. As 76 fichas ativas **seguem Rascunho**.
  - Modelo de revisão **não é** asset final: não vai para `Assets/models/` nem `Assets/blender/` como entrega, e não conta como critério de aceite de ficha.
  - **Bandeira verde segue pendente.**
- Registro de contexto (não é decisão): o blockout do MAP-01 já foi rodado no Studio pelo script `tools/blockout/MAP-01_blockout.luau` (~1027 instâncias, em `MAP01_Blockout`).
- Impacto: `art/asset-list.md` (sem mudança de status); `docs/README.md` (anotação). Separação dos modelos aprovados → DEC futura, ficha a ficha ou em bloco.

---

Origem da DEC-135: conversa do usuário com o orquestrador, 2026-10-09, depois de ver no Studio a versão de análise de DEC-134 (`workspace.AssetReview`, feita de Parts primitivas). Transcrição literal não repassada ao secretário; registro a partir do resumo do orquestrador. Palavras do usuário citadas no resumo: assets atuais "feios e artificiais".

### DEC-135 — 2026-10-09 — Textura stylized pintada à mão; preferir assets gratuitos prontos (emenda DEC-105 e DEC-126)

- Contexto: o usuário achou **todos** os assets da versão de análise (DEC-134) "feios e artificiais" e decidiu trocar a abordagem.
- Decidido pelo usuário:
  1. **Direção de textura: stylized pintada à mão** (textura low-res, cartoon) nos assets.
     - **Revoga** a parte de DEC-105 e de `art/style-guide.md` §1.1 que diz "cor por UV no atlas de gradiente, **sem textura pintada**".
     - **Continua valendo** o resto de DEC-105: forma toy low-poly, chanfro largo, silhueta primeiro. Muda só com DEC nova.
  2. **Fonte: preferir assets gratuitos prontos** em vez de modelar do zero.
     - Licença: **CC0** ou **CC-BY com crédito**, verificada, registrada em `art/credits.md` **antes** do arquivo entrar em `Assets/` (regra do `CLAUDE.md`).
     - **Mapear todas as fichas AST ativas de uma vez** (candidato de asset gratuito por ficha) **antes** de importar qualquer coisa.
- **Emenda DEC-126** (não a edita): o `style-guide.md` segue **Aprovado**, exceto o trecho de §1.1 revogado acima. As seções reescritas pelo art-director (§1.1, §1.2, §6, §9.3) entram como **Rascunho** até nova DEC do usuário.
- **Não decidido** nesta DEC → `Q-132` (não bloqueante para o mapeamento; dono: art-director):
  - novo orçamento de textura (§9.3; hoje 24 MB / 3 atlases);
  - resolução por categoria;
  - textura por asset ou atlas compartilhado;
  - regra de consistência visual entre autores diferentes.
- Também **não** decide: o destino dos modelos de revisão de DEC-134 nem o status das fichas AST (todas seguem **Rascunho**); bandeira verde segue pendente.
- Impacto (cada dono edita o seu):
  - `art/style-guide.md` §1.1, §1.2 (packs com atlas de gradiente), §6 (materiais: `SmoothPlastic` + atlas), §9.3 (texturas) → **art-director**. Conferir também §4.1 (roupa de NPC opção A; o motivo "visual pintado destoa do cenário de atlas" da opção B perde a base) e §9.2 (linha "Texturas de cor (atlas): 3") → anotado em `Q-132`.
  - `art/asset-list.md`: coluna **Origem** passa a ter **candidato de asset gratuito** (link, autor, licença) por ficha ativa; legenda de "Origem" ganha a categoria → **art-director** (+ researcher para a busca).
  - `art/credits.md`: uma linha por asset de terceiros novo, antes do import → **art-director**.
  - `docs/README.md` linhas 11 e 12 (anotação) → secretário.

---

Origem da DEC-136: mensagem do usuário, 2026-10-09, depois do teste lado a lado no Roblox Studio com o hot dog do Kenney Food Kit (`Assets/FoodPack`, CC0) em 3 versões: **(A)** malha Kenney com textura "repintada" por bake procedural no Blender; **(B)** malha Kenney com o atlas de cor original (colormap); **(atual)** hot dog de Parts primitivas (DEC-134). Contexto: o researcher concluiu (`docs/research/asset-sources-handpainted.md`) que não existe família gratuita com textura pintada à mão que cubra a lista de assets. Transcrição fiel:

> Gostei mais do segundo mesmo o B_ kanney

### DEC-136 — 2026-10-09 — Atlas de cor dos packs (versão B, Kenney); revoga o item 1 da DEC-135; família base Kenney + KayKit

- Decidido pelo usuário: **versão B** — malha do pack com o **atlas de cor original** (colormap), **sem textura pintada**.
- **Revoga o item 1 da DEC-135** (textura stylized pintada à mão).
  - Volta a valer **DEC-105** e `art/style-guide.md` §1.1 **como estavam**: cor por atlas de cor/gradiente dos packs, sem textura pintada.
  - **Desfaz a emenda da DEC-135 à DEC-126**: §1.1, §1.2, §6 e §9.3 do style guide **não** voltam a Rascunho e **não** precisam de reescrita. O `style-guide.md` segue **Aprovado** por inteiro (DEC-126, com as exceções já registradas em DEC-114, DEC-123, DEC-132).
- **Mantém o item 2 da DEC-135** (fonte: assets gratuitos prontos), com a família definida:
  - Licença **CC0** ou **CC-BY com crédito**, verificada e registrada em `art/credits.md` **antes** do arquivo entrar em `Assets/` (regra do `CLAUDE.md`).
  - **Família base: Kenney + KayKit** (CC0, estilo coeso).
  - **Mapear todas as fichas AST ativas** (candidato Kenney/KayKit por ficha) **antes** de importar qualquer coisa.
  - Ficha **sem candidato** nos packs: **modelar no mesmo estilo** (toy low-poly, cor por atlas).
- Fecha **`Q-132`** inteira (superada): (a)–(d) perdem o objeto (não há textura pintada); (e) roupa de NPC volta à premissa original — **opção A** de §4.1 (cor por parte do corpo, DEC-126) segue sem mudança, e o motivo "visual pintado destoa do cenário de atlas" volta a valer.
- **Não decidido** nesta DEC: a versão A (bake "repintado") e o hot dog de Parts saem do teste sem uso; destino dos modelos de revisão de DEC-134 e status das fichas AST (todas seguem **Rascunho**); bandeira verde segue pendente.
- Impacto (cada dono edita o seu):
  - `art/asset-list.md`: coluna **Origem** com **candidato Kenney/KayKit** (pack, arquivo, licença) por ficha ativa; "modelar no estilo" quando não houver → **art-director** (trabalho em andamento).
  - `art/credits.md`: uma linha por pack/asset usado (Kenney, KayKit), antes do import → **art-director**.
  - `art/style-guide.md`: **sem mudança** (se algum rascunho de reescrita por DEC-135 tiver sido aplicado, desfazer) → art-director.
  - `docs/README.md` linhas 11 e 12 e `open-questions.md` (`Q-132` → Respondidas) → secretário.

---

Origem da DEC-137: conversa do usuário com o orquestrador, 2026-10-09, depois do lote de teste de comida no Roblox Studio (pasta `workspace.__ImportTest`): candidatos Kenney/KayKit de `art/asset-sourcing.md` em escala de ficha, pivô na base, prévia via EditableMesh, lado a lado com as versões atuais em Parts (DEC-134). Pranchas: `docs/art/sourcing-boards/board_1_Comida.png`. Palavras do usuário (repassadas pelo orquestrador):

> eu gostei das novas, estão bem bonitas

Perguntado se podia registrar a aprovação dos candidatos da comida (AST-001 a 011 e 061) e levar as fichas a Aprovado:

> Sim pode aprovar

### DEC-137 — 2026-10-09 — Comida aprovada: candidatos Kenney/KayKit e fichas AST-001 a AST-011 e AST-061 → Aprovado

- Decidido pelo usuário: **aprovados os candidatos de origem** das linhas de `art/asset-sourcing.md` abaixo e as **fichas** correspondentes de `art/asset-list.md` → status **Aprovado**.

  | Ficha | Candidato aprovado (arquivo de origem) | Edição prevista (do sourcing) |
  |---|---|---|
  | AST-001 Bun | pão recortado de `FP/hot-dog.fbx` | recorte (tirar salsicha e molho → `Bun_Open`); `Bun_Closed` = fechar o corte |
  | AST-002 Sausage | `FP/hot-dog-raw.fbx` | grelhada = recolor por UV na faixa marrom |
  | AST-003 Hot dog montado (Tool) | `FP/hot-dog.fbx` | versão do Tool **sem molho** (para `Att_Topping1..3`); com molho fica para vitrine/ícone |
  | AST-004 Ketchup | `FP/bottle-ketchup.fbx`; cobertura = molho recortado de `FP/hot-dog.fbx` | juntar peças; cobertura 5 dobras |
  | AST-005 Mustard | `FP/bottle-musterd.fbx`; cobertura da mesma origem do AST-004 | recolor + deformação para 7 dobras |
  | AST-006 Cheese | `FP/cheese-cut.fbx` | `Cheese_Slice` direto; `Cheese_Topping` derretido com 2 pontas caindo |
  | AST-007 Bacon | `FP/bacon.fbx` | direto (pilha e cobertura = instâncias da tira) |
  | AST-008 Potato Sticks | `FP/fries.fbx` (só os palitos) | recorte dos palitos, sem a caixa vermelha; monte |
  | AST-009 Cream Cheese | `KP/jar_B_medium.fbx` (+ `FP/whipped-cream.fbx` como cobertura) | tampa recolor Teal; cobertura = espiral escalada |
  | AST-010 Coffee + `Coffee_Pair` | `FP/soda.fbx` | sem canudo; recolor (copo branco, cinta Teal, tampa Coffee) |
  | AST-011 Pacotes do mercado (9) | `FP/bag`, `bag-flat`, `carton`, `carton-small`, `can`, `can-small` (`.fbx`) | recolor por pacote + rótulo decal (AST-072) |
  | AST-061 ANM-002 wrong food | `FP/hot-dog-raw.fbx` (salsicha) + pão do AST-001 | recolor cinza-azulado (ANM-002) + mordida em meia-lua no pão |

- As 12 fichas **entram na fila do `modeler-3d`** (`Aprovado` → `Modelando`) para as edições acima, conforme `art/asset-sourcing.md` e a ficha. Arquivo entra em `Assets/` com a licença já registrada em `art/credits.md` (Kenney Food Kit e KayKit Restaurant Bits, CC0).
- Fica dentro da regra da Fase 0 (`CLAUDE.md`: modelagem permitida para ficha **Aprovada**).
- **Não decidido** nesta DEC:
  - **`Q-133`** (limite de atlases de cor com vários packs) **segue aberta**, sem decisão.
  - As demais fichas AST (fora da comida) e o resto de `asset-sourcing.md` **seguem Rascunho**.
  - `asset-list.md` como documento segue **Rascunho** (aprovação é por ficha).
  - Destino dos modelos de revisão em Parts (DEC-134) e da pasta `workspace.__ImportTest`: não decidido.
  - Bandeira verde segue pendente.
- Impacto:
  - `art/asset-list.md`: linha **Status:** das 12 fichas e coluna Status do Resumo → `Aprovado (DEC-137)`; coluna Origem/arquivo com o candidato aprovado → secretário (feito).
  - `art/asset-sourcing.md`: anotação de que as linhas da comida estão aprovadas → secretário (feito).
  - `art/credits.md`: incluir AST-008 e AST-009 (`FP/fries`, `FP/whipped-cream`) na coluna de uso do Food Kit → secretário (feito).
  - `docs/README.md` linha 12 → secretário.

---

Origem da DEC-138: conversa do usuário com o orquestrador, 2026-10-10, depois do lote de teste de equipamentos no Roblox Studio (pasta `workspace.__ImportTest_Equip`): candidatos KayKit (`KP/`) e Kenney Mini Market (`MM/`) de `art/asset-sourcing.md` em escala de ficha — AST-012 `KP/stove_multi_countertop` e `KP/stove_single_countertop`; AST-014 `KP/cuttingboard` + `KP/knife` (faca veio em pé); AST-015 `KP/crate_buns` (pães redondos de hambúrguer, 2.772 tris contra teto de 800); AST-017/019 `KP/kitchencounter_straight_A` e `KP/kitchencounter_outercorner` (escala não uniforme para a caixa da ficha); AST-019 `KP/chair_stool`; AST-018 `KP/fridge_A` (nível 3) + `MM/freezer` (ref. níveis 1–2); AST-024 `KP/menu` (cavalete); AST-040 `KP/kitchencabinet`; AST-041 `KP/kitchencabinet_half`; AST-049 `KP/shelf_papertowel`. Palavras do usuário (repassadas pelo orquestrador):

> Aprovo a táubua, esse pão ali de hamburguer, a gente iria colocar os pães de cachorro quente no lugar. Esssa banqueta não precisa desse afundado no centro (isso só aumenta polígonos, melhor só planificar em cima mesmo, os demais eu gostei, exceto pelo fogão, afinal vamos usar uma grill, uma chapa, não um fogão, seria algo mais parecido com essa foto

A foto: máquina comercial de rolos de salsicha (roller grill) — caixa de inox, ~7 rolos horizontais em cima com salsichas, gaveta aquecedora embaixo, painel frontal vermelho com 3 botões. Tem marca de fabricante: vale **só como referência de forma**. Salva em `Assets/reference/AST-012_roller_grill_ref.png`.

### DEC-138 — 2026-10-10 — Equipamentos aprovados (AST-014, 015, 017, 018, 019, 024, 040, 041, 049); AST-012 vira roller grill

- Decidido pelo usuário: **aprovados os candidatos de origem** abaixo e as **fichas** correspondentes de `art/asset-list.md` → status **Aprovado**.

  | Ficha | Candidato aprovado | Edição (em **negrito** = pedida pelo usuário/teste; demais = prevista no sourcing) | Parte da ficha fora do candidato (segue para modelar no estilo, sem bloquear a aprovação) |
  |---|---|---|---|
  | AST-014 Tábua + faca | `KP/cuttingboard.fbx` + `KP/knife.fbx` | **faca deitada** sobre a tábua (veio em pé) | — |
  | AST-015 Caixa de pães | `KP/crate_buns.fbx` (+ `KP/crate_lid.fbx`) | **trocar os pães redondos de hambúrguer pelos pães de hot dog do AST-001** (DEC-137); **cortar tris** até o teto da ficha (≤ 800 com `Fill`; o candidato tem 2.772) | — |
  | AST-017 Grade de complementos | `KP/kitchencounter_straight_A.fbx` como base/tampo | escala não uniforme para a caixa da ficha | grade 3 × 2 com degrau, cubas de aço com tampa basculante, etiquetas, cadeado |
  | AST-019 Counter + fila | `KP/kitchencounter_straight_A.fbx`, `KP/kitchencounter_outercorner.fbx` (L3 em L), `KP/chair_stool.fbx` (banquinhos) | escala não uniforme para a caixa da ficha; **banqueta com assento plano**, sem o rebaixo central (corta polígonos) | pedestais com corda, toldo do L3, marcas de fila (decal/Part plana) |
  | AST-018 Cooler (3 níveis) | `KP/fridge_A.fbx` = **nível 3**; `MM/freezer.fbx` = **base dos níveis 1–2** | L3 reduzido à caixa da ficha (3 × 3 × 3,0) | níveis 1–2 modelados no estilo sobre a base do `MM/freezer` |
  | AST-024 Placa OPEN/CLOSED | `KP/menu.fbx` (cavalete de chão) | escala da ficha + decal; `Sign_ForSale` = mesma peça | — |
  | AST-040 Banco do fundo | `KP/kitchencabinet.fbx` ×3 (banco-baú) | almofada Ketchup Faded; pés ref. `KP/chair_stool` (com o mesmo assento plano, se usado) | almofada |
  | AST-041 Pontos "Hide" | `KP/kitchencabinet_half.fbx` | alça Mustard legível no escuro (sourcing) | — |
  | AST-049 Bancada de upgrades | `KP/kitchencounter_straight_A.fbx` + `KP/shelf_papertowel.fbx` (nichos) | juntar peças + recolor | painel GEAR WALL e vitrine S1 |

- **Banqueta (`KP/chair_stool`)**: a edição "assento plano, sem rebaixo" vale em **todo** uso da peça (AST-019; AST-040 se usar os pés).
- **AST-012 Grill**:
  - Candidato KayKit (`KP/stove_single_countertop`, `KP/stove_multi_countertop`) **recusado**: lê "fogão", não chapa.
  - **Nova silhueta: roller grill** (máquina de rolos de salsicha), como a referência `Assets/reference/AST-012_roller_grill_ref.png`.
  - **Modelar** no estilo toy low-poly (DEC-105, família Kenney/KayKit, DEC-136). Cores: **Steel** + acento **Ketchup** no painel frontal (paleta `style-guide.md` §2.1). **Sem marca, logo ou nome** do fabricante da foto (regra "inspiração, não cópia").
  - Ficha **Aprovada na direção**; a linha **Silhueta** (e o que dela depende: níveis visíveis, cores, encaixes) é reescrita pelo **art-director**. Modelo de análise em andamento.
- Fichas aprovadas **entram na fila do `modeler-3d`** (`Aprovado` → `Modelando`), dentro da regra da Fase 0 (modelagem de ficha **Aprovada**). Licença: KayKit Restaurant Bits e Kenney Mini Market, CC0 (`art/credits.md`).
- **Não decidido** nesta DEC:
  - **`Q-134`** (não bloqueante): como os **3 níveis do Grill** (UPG-001: 2/3/4 vagas, "chapa simples → segunda chapa → grelha grande com tampa") leem na roller grill — ex.: nº de rolos / tamanho da máquina por nível. Dono: game-designer + art-director.
  - Demais fichas AST e o resto de `asset-sourcing.md` **seguem Rascunho**. `asset-list.md` como documento segue **Rascunho** (aprovação é por ficha).
  - **`Q-133`** (limite de atlases) segue aberta — agora com 2 packs de equipamento aprovados (KP e MM).
  - Destino da pasta `workspace.__ImportTest_Equip` e dos modelos de revisão (DEC-134): não decidido.
  - Bandeira verde segue pendente.
- Impacto:
  - `art/asset-list.md`: linha **Status:**/**Origem** das 10 fichas e colunas Origem/Arquivo/Status do Resumo → secretário (feito). Linha Silhueta, Níveis e Cores do AST-012 → **art-director**.
  - `art/asset-sourcing.md`: nota de aprovação das linhas de equipamento e recusa do candidato do AST-012 → secretário (feito).
  - `design/upgrades.md` UPG-001 coluna "Peça visível" e `levels/MAP-01.md` L01-03 ("Grelha 2/3/4 vagas") → depois de `Q-134` (game-designer, level-designer).
  - `docs/README.md` → secretário.

---

Origem da DEC-139: conversa do usuário com o orquestrador, 2026-10-10, depois da prévia no Roblox Studio (pastas `workspace.__Preview_Veiculos`, `workspace.__Preview_Mercado`, `workspace.__Preview_Cidade`) dos candidatos de `art/asset-sourcing.md` em escala de ficha. Transcrição não literal; registro a partir do resumo do orquestrador.

Prévia mostrada:
- **Veículos:** AST-035 `CK/sedan`, `CK/hatchback-sports`, `CK/van`, `CK/truck` (uma escala para a família: sedã 12 studs, demais proporcionais, ≤ 14); AST-048 `CK/delivery` (20 C); AST-052 `CK/ambulance` (16 × 7 × 8); AST-065 long car = `CK/sedan` esticado; AST-026 guarda-sol `CC/detail-parasol-a` (9 A).
- **Mercado:** AST-028 `MM/wall`, `MM/wall-window`, `MM/wall-door-rotate`, `MM/wall-corner` (módulo 8 × 12) + `CC/detail-awning-wide`; AST-029 `MM/shelf-boxes`, `MM/shelf-bags`, `MM/shelf-end`; AST-030 `MM/freezers-standing` (4 × 7 × 2,5); AST-031 `MM/cash-register` (6 × 3,5 × 2,5); AST-050 `MM/display-fruit`, `MM/display-bread`, `KP/crate_lettuce`.
- **Cidade:** AST-032 `CR/road-straight`, `CR/road-crossroad`; AST-033 `CC/building-a`, `CC/building-h`; AST-044/045 `CC/building-j`; AST-046 `CC/building-e`; AST-036 `CR/light-curved`, `CR/light-square`; AST-034 `CR/road-sign-street`, `CS/tree-large`, `CS/planter`, `CK/cone`; AST-047 `CR/construction-fence`, `CR/construction-light`; AST-044 `KP/pillar_A` (coluna).

O usuário editou a prévia no Studio e escreveu (repassado pelo orquestrador):

> Precisa de mais um expositor de pães com os pães de cachorro quente. Alguns itens estavam com face invertida, eu corrigi. Os expositores também estavam muito esticados, corrigi. Ajustei o Sedã esticado também pois as rodas estavam muito esticadas, centralizei e deixei mais normal proporcional, porém ainda esticado

Medidas lidas do Studio depois dos ajustes dele: gôndola AST-029 **4,5 L × 6 A × 2,5 P**; expositor de frutas AST-050 **4 × 3,5 × 3**; long car AST-065 **7,1 L × 4,0 A × 19,5 C**. Faces invertidas = caixas/sacos espelhados (escala negativa) nas gôndolas; corrigido na origem (exportador). Item novo feito pelo orquestrador: variante do AST-050 "expositor de pão de hot dog" = `MM/display-bread` com 10 pães AST-001 (918 tris): `Assets/blender/market/AST-050_BunDisplay.blend`, `Assets/models/market/AST-050_BunDisplay.fbx`.

Pendências apresentadas antes da pergunta: paredes do Mart pesadas/escuras esticadas a 12; long car ainda sem recolor preto `#14162A`; `CC/building-j` com 5.246 tris (teto de fachada montada 2.500); carros com ~2.030–2.090 tris (teto 2.000); `KP/crate_lettuce` com 1.980 tris (teto 1.200). Perguntado se aprovava em bloco veículos, mercado e cidade:

> sim

### DEC-139 — 2026-10-10 — Veículos, mercado e cidade aprovados em bloco (18 fichas); medidas novas de AST-029, AST-050 e AST-065; expositor de pão de hot dog no AST-050

- Decidido pelo usuário: **aprovados os candidatos de origem** abaixo e as **fichas** correspondentes de `art/asset-list.md` → status **Aprovado**.

  | Ficha | Candidato aprovado | Parte da ficha fora do candidato (segue para modelar no estilo, sem bloquear a aprovação) |
  |---|---|---|
  | AST-026 Corner Cart | **só os guarda-sóis**: `CC/detail-parasol-a.fbx` (9 A) | **casca do carrinho segue modelar** (ficha inteira, menos os guarda-sóis) |
  | AST-028 Ninth Street Mart | `MM/wall`, `MM/wall-window`, `MM/wall-door-rotate`, `MM/wall-corner` (módulo 8 × 12) + toldo `CC/detail-awning-wide` | `Corner` chanfrado, `Roof_Trim`, `Marquee`, letreiros e `SafeZone_Marking` (sourcing) |
  | AST-029 Gôndola + recheio | `MM/shelf-boxes`, `MM/shelf-bags`, `MM/shelf-end` | recheio das fichas (sourcing) |
  | AST-030 Geladeira expositora | `MM/freezers-standing` (4 × 7 × 2,5) | — |
  | AST-031 Balcão do caixa | `MM/cash-register` (6 × 3,5 × 2,5) | banquinho, revista, caneca (sourcing) |
  | AST-032 Kit de rua | `CR/road-straight`, `CR/road-crossroad` | demais peças do sourcing (meio-fio, rampa, bueiro, batente) |
  | AST-033 Kit de prédio | `CC/building-a`, `CC/building-h` | recolor por lote, `Door_D1`, decal (sourcing) |
  | AST-034 Mobiliário urbano | `CR/road-sign-street`, `CS/tree-large`, `CS/planter`, `CK/cone` | banco de praça, lixeira de rua, hidrante, caixa de correio (sourcing) |
  | AST-035 Carros (4) | `CK/sedan`, `CK/hatchback-sports`, `CK/van`, `CK/truck`; uma escala para a família (sedã 12, demais proporcionais, ≤ 14) | — |
  | AST-036 Poste | `CR/light-curved` (alt. `CR/light-square`) | cúpula nova (sourcing) |
  | AST-044 Bellmoor Savings | **só a coluna**: `KP/pillar_A.fbx`; volume da prévia em `CC/building-j` | **resto da fachada segue modelar** se a ficha pedir (frontão, relógio, quina chanfrada) |
  | AST-045 Apartamentos | `CC/building-j` | janelas WV (sourcing) |
  | AST-046 Lavanderia | `CC/building-e` | vitrine e `Door_SPB` (sourcing) |
  | AST-047 Barreira | `CR/construction-fence`, `CR/construction-light` (+ cone de AST-034) | placa por decal |
  | AST-048 Caminhão de entrega | `CK/delivery` (20 C) | — |
  | AST-050 Frutas e verduras | `MM/display-fruit`, `MM/display-bread`, `KP/crate_lettuce` + **variante nova "expositor de pão de hot dog"** (`MM/display-bread` com 10 pães AST-001, 918 tris; `Assets/blender/market/AST-050_BunDisplay.blend`, `Assets/models/market/AST-050_BunDisplay.fbx`) | — |
  | AST-052 Ambulância | `CK/ambulance` (16 × 7 × 8) | maca, portas traseiras, barra de luz (sourcing) |
  | AST-065 Long car | `CK/sedan` esticado (mesma base do AST-035) | — |

- **Medidas novas, por ajuste do usuário no Studio** (substituem as da ficha):
  - **AST-029 gôndola: 4,5 L × 6 A × 2,5 P** (era 8 L).
  - **AST-050 expositor de frutas: 4 L × 3,5 A × 3 P** (era 8 L × 3 P × 3,5 A).
  - **AST-065 long car: 19,5 C × 7,1 L × 4,0 A** (≈ 1,6× o sedã; era ~22 × 6 × 4,5, 1,8×). Rodas centralizadas e proporcionais; segue "esticado".
- **Faces invertidas** (caixas/sacos espelhados por escala negativa nas gôndolas): corrigidas na origem (exportador). Vale para todo import.
- **Edições pendentes** — entram na fila do `modeler-3d` (`Aprovado` → `Modelando`); **não bloqueiam a aprovação**:
  1. AST-065: **recolor preto `#14162A`** (style guide §2.4).
  2. AST-044/045: reduzir `CC/building-j` (5.246 tris) ao teto da ficha (prédio ≤ 2.500).
  3. AST-035: reduzir os carros (~2.030–2.090) a **≤ 2.000 tris** (rodas mais simples). Vale para a base do AST-065.
  4. AST-050: refazer o caixote de alface (`KP/crate_lettuce`, 1.980) a **≤ 1.200 tris**, como no AST-015.
  5. AST-028: revisar as paredes do Mart (pesadas/escuras esticadas a 12) — **art-director** avalia se servem com recolor ou se trocam por fachada CC/modelagem.
  6. AST-052: conferir o lado oculto da ambulância (sem cruz/emblema, §2.4).
- Licença: Kenney Car Kit, City Kit Roads/Commercial/Suburban, Mini Market e KayKit Restaurant Bits, CC0 (`art/credits.md`). Dentro da regra da Fase 0 (modelagem de ficha **Aprovada**).
- **Não decidido** nesta DEC:
  - **AST-074 (ônibus)** segue **Rascunho**, a confirmar (KayKit City Builder Bits não baixado).
  - Onde o expositor de pão de hot dog fica no Mart e se é só cenário (como o AST-050, DEC-109) ou ponto de compra dos Buns → `Q-135`.
  - Layout do Mart com gôndola e expositor mais estreitos → `Q-135` (level-designer).
  - Medidas de hatch, van e picape do AST-035 (ficha 9 / 13 / 13 x prévia em escala única) → `Q-136` (art-director).
  - **`Q-133`** e **`Q-134`** seguem abertas.
  - Destino das pastas `workspace.__Preview_*` e dos modelos de revisão (DEC-134): não decidido.
  - `asset-list.md` e `asset-sourcing.md` como documentos seguem **Rascunho** (aprovação é por ficha). Bandeira verde segue pendente.
- Impacto:
  - `art/asset-list.md`: Status/Origem das 18 fichas e do Resumo; Dimensões de AST-029, AST-050, AST-065; variante nova no AST-050 → secretário (feito).
  - `art/asset-sourcing.md`: nota de aprovação → secretário (feito).
  - `art/credits.md`: colunas de uso (CK, CR, CC, CS, MM, KP) com as fichas aprovadas → secretário (feito).
  - `levels/MAP-01.md` §7.4 e L01-41/L01-46 (gôndolas e expositor 8 × 3 × 3,5) → level-designer, depois de `Q-135`.
  - `docs/README.md` → secretário.

---

Origem da DEC-140: conversa do usuário com o orquestrador, 2026-10-10, depois da prévia no Roblox Studio (`workspace.__Preview_Novos`) e da prancha `docs/art/sourcing-boards/board_6_Modelados.png`. Transcrição não literal; registro a partir do resumo do orquestrador.

Prévia mostrada: 4 lotes de **versões de análise** (DEC-134) modelados no estilo DEC-136 (toy low-poly; cor só pelo atlas KitchenPack ou City Kit Roads). Arquivos em `Assets/blender/<cat>/` e `Assets/models/<cat>/`. Pendência apresentada: no porta-garrafas (AST-016) o `Fill` interno ficava escondido pela garrafa opaca. Palavras do usuário:

> Faz translúcida, dai a gente anima subindo o líquido

Perguntado se aprovava o lote:

> pode dar ok

### DEC-140 — 2026-10-10 — Lote de modelados aprovado (12 fichas + peças avulsas de AST-034, 036, 052); garrafas de molho translúcidas com `Fill` animado

- Decidido pelo usuário: as **versões de análise** abaixo passam a **Aprovado** (modelo aceito, não só a ficha). Fichas que estavam **Rascunho** → **Aprovado**. Peças avulsas de AST-034, AST-036 e AST-052 entram **dentro das fichas já aprovadas na DEC-139**.

  | Ficha | Peça / variante | Tris | Arquivo (`.blend` em `Assets/blender/`, `.fbx` em `Assets/models/`) |
  |---|---|---|---|
  | AST-013 Trilho de descanso | `Rail_6` / `Rail_8` | 384 / 440 | `equipment/AST-013_RestRail` |
  | AST-016 Porta-garrafas | suporte + `Fill` (cada) | 480 + 28 cada | `equipment/AST-016_SauceHolder` |
  | AST-020 Entrega + gaveta | registradora + `Lock` | 860 + 104 | `equipment/AST-020_CashRegister` |
  | AST-022 Cafeteira | máquina; jarra oca com café dentro; alça presa por gola/cinta | 944 | `equipment/AST-022_CoffeeMachine` |
  | AST-023 Trailer Lights | `Lights_Mast` / `Lights_String` | 356 / 486 | `equipment/AST-023_TrailerLights` |
  | AST-025 Lixeira | edição de **"Trashcan" by Kenney** (CC0, https://poly.pizza/m/eoC8NFaafh): tampa basculante, pedal novo, recolor Teal | 132 | `equipment/AST-025_Trashcan` |
  | AST-037 Panfleto | `Flyer_Old` / `Flyer_NightShift` | 132 / 144 | `story/AST-037_Flyer` |
  | AST-038 Celular flip | — | 266 | `story/AST-038_FlipPhone` |
  | AST-039 Interruptor | — | 128 | `equipment/AST-039_LightSwitch` |
  | AST-042 Telefone do veículo | aparelho / `Phone_Cart` | 396 / 528 | `equipment/AST-042_VehiclePhone` |
  | AST-051 Revive Kit | apito | 300 | `market/AST-051_ReviveKit` |
  | AST-068 Pistas do trailer | `Photo_1979` / `Badge_Old` | 66 / 76 | `story/AST-068_TrailerClues` |
  | AST-034 Mobiliário urbano (DEC-139) | banco de praça / lixeira de rua / hidrante / caixa de correio (genérica, verde, sem marca) | 572 / 260 / 300 / 288 | `street/AST-034_ParkBench`, `_TrashCan`, `_Hydrant`, `_Mailbox` |
  | AST-036 Poste (DEC-139) | cúpula `LampHead` (encaixa no `CR/light-curved` escalado a 14) | 208 | `street/AST-036_LampHead` |
  | AST-052 Ambulância (DEC-139) | maca `Stretcher` (`Att_Grip_Front` / `Att_Grip_Back` conforme a ficha) | 352 | `vehicle/AST-052_Stretcher` |

- **Garrafas de molho translúcidas (AST-004, AST-005; usadas no AST-016):**
  - Garrafa **translúcida** (material de vidro/plástico do style guide §6: `SmoothPlastic` com Transparency; valor exato com o art-director).
  - Líquido = **peça interna separada `Fill`**, dentro da garrafa.
  - `Fill` **anima subindo/descendo** com o estoque do molho. Leitura sem HUD (style-guide §3, "estoque visível").
  - Edição **em andamento** pelo `modeler-3d`: `AST-004_KetchupBottle`, `AST-005_MustardBottle`.
- **Desvios aceitos** com a aprovação (substituem a medida da ficha):
  1. **AST-036:** poste montado com **14,45 de altura** e **braço 3,6** (ficha: 14 / 3), resultado do `CR/light-curved` escalado a 14 + `LampHead`.
  2. **AST-051:** anel do apito **1,09** (ficha 0,9 de comprimento total do apito).
  3. **AST-042:** o fio do telefone **não acompanha o fone** no estado `OffHook`. Resolver na implementação: trocar a peça (fio em outra posição no `OffHook`) ou `Beam`.
- Dentro da regra da Fase 0 (modelagem de ficha **Aprovada**). Licenças: KayKit Restaurant Bits, City Kit Roads e "Trashcan" by Kenney, CC0 (`art/credits.md`).
- **Não decidido** nesta DEC:
  - Lixeira de rua (AST-034): só decorativa ou interativa (se interativa, ganha acento Mustard, style guide §3) → **`Q-137`** (art-director).
  - Destino de `workspace.__Preview_Novos` e dos modelos de revisão (DEC-134): não decidido.
  - **`Q-133`** a **`Q-136`** seguem abertas. `asset-list.md` como documento segue **Rascunho** (aprovação é por ficha). Bandeira verde segue pendente.
- Impacto:
  - `art/asset-list.md`: Status/Origem/arquivo/tris das 12 fichas, das peças avulsas de AST-034/036/052 e do Resumo; nota da garrafa translúcida em AST-004/005/016; desvios de AST-036/042/051 → secretário (feito).
  - `art/credits.md`: linha "Trashcan" by Kenney (Poly Pizza) → secretário (feito).
  - **frontend-coder:** animação do `Fill` das garrafas (AST-004/005) — escala/posição em Y proporcional ao estoque do molho vindo do servidor, tween curto ao mudar; mesma lógica dos demais `Fill` (AST-015, 017, 018, 022). Também: fio do telefone no `OffHook` (AST-042).
  - **modeler-3d:** terminar `AST-004_KetchupBottle` e `AST-005_MustardBottle` (garrafa translúcida + `Fill` separado, pivô na base do `Fill` para escalar em Y).
  - **art-director:** valor de Transparency da garrafa; `Q-137`.
  - `docs/README.md` → secretário.

---

Origem da DEC-141: conversa do usuário com o orquestrador, 2026-10-10, depois da prévia no Roblox Studio (`workspace.__Preview_Rodada3`) da rodada 3 de **versões de análise** (DEC-134) no estilo DEC-136. Transcrição não literal; registro a partir do resumo do orquestrador. Arquivos em `Assets/blender/<cat>/` e `Assets/models/<cat>/`; todos com **zfight 0**; licenças: só packs CC0 já registrados em `art/credits.md`.

Pendências apresentadas na prévia (sem escolha do usuário): empilhamento das coberturas no hot dog; guarda-sóis do carrinho no topo da tela em 1ª pessoa; lona AST-043 não modelada; long car com 4 rodas (ficha pede 6); carga da ambulância rasa para a maca; cor da moldura da vitrine S1 do GEAR WALL. Palavras do usuário ao ver a rodada:

> pode aprovar

### DEC-141 — 2026-10-10 — Rodada 3 de modelados aprovada (comida editada, coberturas, otimizações, equipamentos, AST-026 casca e AST-027 trailer)

- Decidido pelo usuário: as **versões de análise** abaixo passam a **Aprovado** (modelo aceito, não só a ficha). **AST-027** estava **Rascunho** → **Aprovado** por esta DEC. As demais fichas já eram Aprovadas (DEC-137/138/139); esta DEC aprova o **modelo entregue**.

  | Ficha | Peça / variante | Tris | Arquivo (`.blend` em `Assets/blender/`, `.fbx` em `Assets/models/`) |
  |---|---|---|---|
  | AST-001 Bun (DEC-137) | `Bun_Closed` / `Bun_Open` — pão refeito com corte em V e miolo Cream (mesma seção e cores do pack) | 128 / 152 | `food/AST-001_Bun` |
  | AST-002 Sausage (DEC-137) | `Sausage_Raw` / `Sausage_Grilled` | 92 / 164 | `food/AST-002_Sausage` |
  | AST-003 Hot dog (DEC-137) | Tool sem molho (`Att_Topping1..3`) / `HotDog_Display` | 316 / 414 | `food/AST-003_HotDog` |
  | AST-004 Ketchup (DEC-137) | cobertura, 5 dobras | 66 | `food/AST-004_KetchupTopping` |
  | AST-005 Mustard (DEC-137) | cobertura, 7 dobras | 86 | `food/AST-005_MustardTopping` |
  | AST-006 Cheese (DEC-137) | `Cheese_Topping` / `Cheese_Slice` | 148 / 160 | `food/AST-006_Cheese` |
  | AST-007 Bacon (DEC-137) | `Bacon_Topping` (tiras 0,8) / `Bacon_Pile` | 160 / 120 | `food/AST-007_Bacon` |
  | AST-008 Potato Sticks (DEC-137) | `PotatoSticks_Topping` / `PotatoSticks_Pile` | 240 / 344 | `food/AST-008_PotatoSticks` |
  | AST-009 Cream Cheese (DEC-137) | `CreamCheese_Topping` / `CreamCheese_Jar` (pote 0,6 × 0,6 × 0,78, medida escolhida pelo modelador) | 126 / 188 | `food/AST-009_CreamCheese` |
  | AST-010 Coffee (DEC-137) | Tool sem canudo / `Coffee_Pair` (L/R) | 236 por copo | `food/AST-010_Coffee` |
  | AST-061 Wrong food (DEC-137) | `Sausage_Wrong` / `Bun_Bitten` | 164 / 208 | `anomaly/AST-061_WrongFood` |
  | AST-014 Tábua + faca (DEC-138) | tábua / faca (deitada na borda da frente) | 38 / 104 | `equipment/AST-014_CuttingBoard` |
  | AST-017 Grade de complementos (DEC-138) | base / cuba + tampa + etiqueta + cadeado (cadeado em cima da tampa) | 274 / 386 | `equipment/AST-017_ToppingGrid` |
  | AST-018 Cooler (DEC-138) | `CoolerL1` / `CoolerL2` (duas tampas) | 668 / 1.106 | `equipment/AST-018_CoolerL1`, `_CoolerL2` |
  | AST-019 Counter + fila (DEC-138) | pedestal + corda / marca de fila | 94 + 68 / 34 | `equipment/AST-019_QueuePost`, `_QueueMark` |
  | AST-049 Bancada de upgrades (DEC-138) | GEAR WALL montado (moldura da S1 em Gold, conforme ficha) | 1.208 | `market/AST-049_GearWall` |
  | AST-035 Carros (DEC-139) | `CarSedan`, `CarHatch`, `CarVan`, `CarPickup`; rodas separadas; 5 cores cada (Butter, Mint-gray e Teal claro **aproximados** no atlas) | 1.360–1.416 cada | `vehicle/AST-035_CarSedan`, `_CarHatch`, `_CarVan`, `_CarPickup` (+ `_Paints`) |
  | AST-065 Long car (DEC-139) | 19,5 × 7,1 × 4,0, preto, **4 rodas** | 1.360 | `anomaly/AST-065_LongCar` |
  | AST-052 Ambulância (DEC-139) | Cream + faixa Teal, **sem cruz/emblema** (lado oculto conferido); portas traseiras com pivô (vão 5,1 × 4,9; carga ~2 de fundo) | 1.748 | `vehicle/AST-052_Ambulance` |
  | AST-045 Apartamentos (DEC-139) + AST-044 (parte do prédio) | `building-j` reduzido (`ApartmentBlock`) | 2.381 | `building/AST-045_ApartmentBlock` |
  | AST-050 Frutas e verduras (DEC-139) | caixote de alface refeito | 1.159 | `market/AST-050_LettuceCrate` |
  | AST-026 Corner Cart (DEC-139) | **casca** (linha 26 × 3, bancada 3,5, guarda-sóis a 9; posição de mundo (41, 0, 37.5)) | 2.984 (~7.200 montado) | `vehicle/AST-026_CornerCart` |
  | AST-027 Open Late Trailer | casco 28 × 12 × 11, piso +2, pé-direito 8,5, janela de serviço **22,5** de largura (por causa da quina); inclui a porta dos fundos (AST-066) | 4.452 | `vehicle/AST-027_OpenLateTrailer` |

- **Pendências da DEC-139 resolvidas** por estes modelos: AST-035 ≤ 2.000 tris (rodas mais simples); AST-065 recolor preto e base ≤ 2.000; AST-044/045 `building-j` ≤ 2.500; AST-050 caixote ≤ 1.200; AST-052 lado oculto sem cruz/emblema.
- **AST-026:** com a casca aprovada, a ficha inteira tem modelo aprovado (guarda-sóis já em DEC-139).
- **AST-044:** aprovado aqui só o **volume do prédio** (dentro do `AST-045_ApartmentBlock`). Frontão, relógio e quina chanfrada seguem a modelar.
- **AST-066 (porta dos fundos):** está **dentro** do arquivo do trailer, mas **não** é aprovada por tabela. Ficha AST-066 **segue Rascunho**.
- **Desvios aceitos com a aprovação** (substituem a medida da ficha): AST-027 janela de serviço **22,5** de largura (ficha: X 30–53, 23); AST-009 pote **0,6 × 0,6 × 0,78**; AST-007 tiras da cobertura **0,8** (ficha: tira 1,0); AST-008 `PotatoSticks_Pile` **344** tris (ficha ≤ 250); AST-006 `Cheese_Slice` **160** tris (ficha ≤ 150); AST-035 Butter/Mint-gray/Teal claro **aproximados** no atlas.
- Licenças: só packs CC0 já registrados em `art/credits.md` (nenhuma linha nova). Dentro da regra da Fase 0 (modelagem de ficha **Aprovada**).
- **Não decidido** nesta DEC (o usuário aprovou a rodada sem escolher):
  - Empilhamento das coberturas no hot dog (passo fixo 0,05 da ficha AST-003 não funciona) → **`Q-138`** (game-designer + frontend-coder).
  - Guarda-sóis do carrinho em 1ª pessoa; long car 4 × 6 rodas; moldura da S1 Gold × Mustard → **`Q-139`** (art-director).
  - Carga da ambulância (~2 de fundo) × maca de 6 → **`Q-140`** (level-designer + art-director).
  - AST-043 (lona) **não modelada**; ficha segue Rascunho, depende de `Q-082` (pendência anotada lá).
  - Destino de `workspace.__Preview_Rodada3` e dos modelos de revisão (DEC-134): não decidido.
  - `Q-133` a `Q-137` seguem abertas. `asset-list.md` como documento segue **Rascunho** (aprovação é por ficha). Bandeira verde segue pendente.
- Impacto:
  - `art/asset-list.md`: Status/Origem/arquivo/tris de AST-001 a 010, 014, 017, 018, 019, 026, 027, 035, 044, 045, 049, 050, 052, 061, 065 e do Resumo; nota em AST-003, 026, 043, 049, 052, 065, 066 → secretário (feito).
  - `open-questions.md`: `Q-138`, `Q-139`, `Q-140`; nota em `Q-082` → secretário (feito).
  - **level-designer:** MAP-01 §7.2 janela do trailer 22,5 (era X 30–53).
  - `docs/README.md` → secretário.
