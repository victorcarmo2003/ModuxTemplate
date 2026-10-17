Status: Rascunho (researcher, 2026-10-17). Pesquisa web; nada aqui é decisão. Fontes no fim; o que não foi confirmado está marcado **[não confirmado]**.

# Técnicas de design de anomalias (legibilidade, dosagem, resposta, punição, co-op)

## Pergunta

Como os jogos de anomalia desenham e dosam anomalias para que o jogador as perceba, e o que isso pede do Sell Hotdogs? O ponto de partida é a crítica do dono à V3 (`docs/design/anomalies-v3-restaurant.md`): são anomalias demais, e várias se confundem com o fluxo normal ("tablet que chama sozinho", "prato a mais"). Com muita ação rápida, o jogador nem nota.

Contexto novo do dono (2026-10-17, via coordenador) que estas recomendações já consideram:
- o jogador fica sempre **dentro da loja** (balcão fechado, 1 tablet, entrega no balcão);
- a loja é o único ponto seguro; **lá fora** (mesas, rua, drive-thru visto pela janela) é onde a ameaça mora;
- errar uma anomalia tira **sanidade (−35, provisório)**; o jogador só cai quando ela zera.

## Resposta curta

Os jogos do gênero que funcionam seguem três regras:
- a anomalia mora num **canal separado do trabalho**, tem um **"normal" fixo e memorizável** e chega com **regras ditas antes**;
- pede **uma de poucas respostas padronizadas**;
- entra **uma de cada vez**, com respiro entre elas e menos pressão de trabalho enquanto está ativa.

O erro mais citado por críticos e devs é a anomalia sutil demais, ou visível só num ambiente cheio de coisa. O próprio dev do Exit 8 cortou o protótipo "dentro do trem" porque achar anomalias num vagão era difícil demais. Um restaurante em pico de pedidos é esse vagão. Por isso, anomalias "de estação" (prato, tablet, condimento, caixa) competem com o ruído do trabalho e perdem.

## 1. Legibilidade: separar anomalia de ruído

| Técnica | Onde aparece | O que faz |
|---|---|---|
| **Baseline familiar e fixo** | Exit 8 (corredor de metrô que todo japonês conhece; o dev escolheu de propósito); Shift 87; Observation Duty | A pessoa só nota a mudança se sabe como é o normal. Cenário fixo, poucos objetos-âncora |
| **Regras escritas antes** | Exit 8 (placa com as regras no início); Scary Shawarma Kiosk (Roblox: quadro de regras ao lado do guichê, com cota e comportamentos a vigiar); FNAF (o "Phone Guy" ensina a mecânica na noite 1, quando os animatrônicos ficam quase inativos até ~2h) | Cada regra vira um "contrato": o jogador sabe o que procurar e o que fazer |
| **Ambiente limpo, com pouca coisa** | Platform 8: o protótipo no vagão foi descartado porque achar anomalias lá "was really tricky" comparado ao corredor | Lugar cheio de objetos e movimento esconde a anomalia |
| **Prenúncio por canal dedicado** | Doors (Roblox): luz pisca + ruído crescente antes do Rush → esconder no armário. Dead by Daylight: batimento cardíaco (terror radius) que aumenta com a proximidade. FNAF: "você ouve a ameaça antes de ver" | Um som ou luz **reservado só para ameaça** avisa sem o jogador ter que procurar |
| **Pistas por camada de checagem** | Scary Shawarma (olhar o cliente, câmera normal, câmera noturna, áudio); Animal Hospital (Roblox: aparência, foto do documento, CCTV, comportamento) | A suspeita tem um ritual curto e fixo de checagem, num momento calmo (atendimento 1 a 1) |
| **Mudança grande em vez de sutil** | Críticos de Shift 87 ("localizar pequenas mudanças foi muito frustrante") e de Observation Duty ("algo é movido 2 pixels e você não percebe") | Em jogo de ação, a anomalia tem que ser legível em 1 s |
| **Movimento como critério** | The Cabin Factory: a cabana é boa "a menos que algo se mexa" | Um critério único e simples deixa o cenário assustador sem gerar falso positivo |

Problema de ambiguidade que vale evitar (Shift 87): duas mudanças no mesmo ciclo deixam o jogador sem saber qual o jogo quer. Em *Who's At the Door?*, anomalia passageira, que some em segundos, não conta, para não punir quem piscou.

## 2. Dosagem

| Jogo | Número observado |
|---|---|
| Scary Shawarma Kiosk (Roblox, 2025; dado de guia de fã) | primeiros turnos: 8–10 clientes com **1–2 anomalias**, até 3–4 erros tolerados. Turnos finais: 15–20 clientes com **5–8 anomalias**, só 1–2 erros tolerados |
| I'm on Observation Duty 6 (guia de fã) | **1 anomalia a cada 15 min de jogo**; os primeiros 15 min são carência; perde quem acumula anomalias não reportadas |
| FNAF 1 (wiki) | noite de ~9 min (hora = 1 min 30 s); noite 1 quase sem ameaça (tutorial); a dificuldade sobe pela agressividade (IA 0–20) dos mesmos inimigos, não por inimigo novo a cada noite |
| Shift 87 (review) | 22 anomalias por ambiente, 66 no total, mas uma por ciclo e alguns ciclos sem anomalia |
| Alien: Isolation (Game Developer) | o "menace gauge" sobe com a presença do alien; no limite, o alien recua para os dutos (respiro). O designer regula cooldown, tempo até o pico e quantas ameaças por sequência |
| Overcooked (post-mortem MCV) | "toda vez que introduzíamos uma receita nova, tinha que haver um recuo" na dificuldade do ambiente. É um **orçamento de complexidade**: novidade de um lado, alívio do outro |
| Left 4 Dead AI Director (entrevista Valve 2007) | ataca quando a ação acalma e deixa a situação assentar depois de combate intenso longo. **[o modelo "build-up / peak / relax" com esse nome não foi confirmado nesta busca]** |

Padrões:
- **uma ou duas famílias por vez**;
- **novidade só com recuo** em outra coisa;
- **respiro depois do pico**;
- a dificuldade sobe mais por **frequência e tolerância a erro** do que por variedade.

## 3. Resposta

- **Poucas respostas, sempre as mesmas.** Exit 8 tem 2 (seguir / voltar). Scary Shawarma tem 1 principal (fechar a persiana com o botão ao lado da porta; a anomalia vai embora). Doors tem uma por entidade, e o Rush tem uma só (esconder). Observation Duty tem uma (reportar tipo + sala).
- **Controle físico dedicado** perto do jogador (o botão da persiana no Shawarma, o armário no Doors).
- **Janela de tempo visível**: o Rush dá aviso de luz e som antes de chegar; a água vermelha do Exit 8 dá alguns segundos para voltar.
- **Falso positivo também custa.** No Shawarma, fechar a persiana para cliente humano conta erro. Sem esse custo, o jogador fecha tudo.
- **Feedback de acerto/erro claro.** Elogios de jogadores: o *False Mall* mostra onde estava a anomalia perdida e deixa revisitar ("felt SO much better"). Críticas: o *Twisted Gallery* não avisa que você achou tudo, e o *The 5th Door* tem pistas que "geralmente não" indicam a porta certa.

## 4. Punição gradual

- **Medidor em vez de morte instantânea.**
  - Observation Duty: perde quem acumula anomalias, não quem erra uma.
  - Shawarma: cota de erros por turno, que diminui nas noites finais.
  - Animal Hospital: anomalias e erros reduzem a sanidade.
  - Phasmophobia (wiki/fórum): abaixo de ~50% de sanidade o jogador vê luzes piscando "imaginárias". Segundo jogadores, a caçada usa a sanidade média do grupo. **[limiares divergem entre fontes]**
- **Consequência que se acumula no mundo**: no Shawarma, servir o cliente de terceiro olho faz o "monstro da geladeira" crescer.
- **Crítica recorrente**: reset total por um erro sutil irrita (Nintendo Life sobre o Exit 8; Hospital 666 sobre o hardcore). Funciona em jogo curto de 20 min, não em noite longa de co-op.

## 5. Co-op

- **Papéis declarados.** O Animal Hospital (Roblox, co-op até 4) separa Recepção (inspecionar e admitir), Médico, Suporte e **Observador (vigia o CCTV e avisa os colegas)**. "Quem vigia" vira papel, não acaso.
- **Mais olhos ajudam.** Jogadores relatam que em grupo alguém sempre nota o que o outro perdeu (selectbutton, Hospital 666). Por isso a anomalia deve ser **visível de mais de um posto**.
- **Comunicação mínima embutida.** O Overcooked 2 adicionou emotes junto do chat de voz no online; muitos jogadores de Roblox não usam voz.
- **Overcooked quebra a rotina de propósito** (o nível se mexe para "tirar as pessoas de posição"), mas a mudança é **grande e física**: a cozinha inteira se mexe, ou começa um incêndio que exige pegar o extintor. Não é um detalhe dentro da estação.
- **Problema citado**: progresso e recompensa só para o host (Hospital 666). Todos os jogadores precisam ganhar.

## 6. Erros comuns citados

1. Anomalia sutil demais ou em ambiente poluído (Shift 87, Observation Duty, Platform 8 no vagão).
2. Duas mudanças ao mesmo tempo, sem saber qual responder (Shift 87).
3. Pista enganosa ou inconsistente (The 5th Door).
4. Pouco feedback: não mostrar o que foi perdido (Twisted Gallery vs False Mall).
5. Repetição ou anomalias sempre no mesmo lugar (Stairway 7, Hospital 666).
6. Anomalia óbvia demais, só vitrine de arte (Shinkansen 0, segundo um crítico).
7. Mecânica demais em cima do conceito (comentário no selectbutton).
8. Reset total por um único erro em sessão longa.

## Exemplos que funcionam e por quê

- **Água vermelha (Exit 8)**: grande, inconfundível, com alguns segundos para reagir; a resposta (voltar) é a mesma de todas.
- **Rush (Doors)**: prenúncio em canal dedicado (luz + som crescente), uma resposta (armário), janela curta e justa. A luz às vezes pisca sem Rush, o que mantém a tensão sem punir.
- **Persiana do Shawarma**: um botão, uma regra no quadro, checagem em camadas num atendimento 1 a 1 (momento calmo), custo para os dois lados do erro.
- **Observador do Animal Hospital**: transforma "perceber" em papel de co-op.

---

## Recomendações para o Sell Hotdogs

Valem sobre a V2 aprovada (DEC-254..257), sem emendá-la. Onde mudam regra aprovada, viram Q para o secretário.

1. **Canal separado do trabalho.** A anomalia nunca usa um objeto que, no fluxo normal, pede ação rápida (prato, grelha, condimento, caixa de estoque, nota, tablet tocando).
   - Com o jogador sempre dentro da loja, a anomalia mora **lá fora** (mesas, rua, drive-thru), vista pela **vitrine e pela janela**.
   - Exceção: o **cliente no tablet** (família A), porque o atendimento 1 a 1 é um momento calmo.
   - Saem ou vão para revisão: ANM-021, 023, 024, 026, 027 e 034.
2. **Prenúncio único reservado.** Toda anomalia de fora começa com o mesmo aviso de 1–2 s, que **nunca** toca em outra situação: um "sting" sonoro e uma mudança de luz lá fora (postes esfriam). Ele é o "Rush piscando" do jogo. Só depois vem o sinal específico.
3. **Baseline de fora fixo e memorizável.**
   - Escolher **4–6 objetos-âncora** (poste, banco, placa, carro estacionado, mesa 1–4, guarda-sol) que nunca mudam numa noite normal.
   - A anomalia altera **um** deles de forma **grande** (silhueta, cor ou movimento), nunca sutil.
   - Uma anomalia por vez: nunca duas mudanças ao mesmo tempo.
4. **Regras ditas antes.**
   - Um **quadro de regras** físico na loja, com 1 linha por anomalia já apresentada.
   - A ligação do chefe apresenta **uma regra nova por noite**.
   - Anomalia sem regra no quadro não pune: só assusta (família D sem verbo).
5. **No máximo 3 respostas, cada uma num controle físico perto do balcão:**
   - **FECHAR** (persiana da vitrine ou do drive-thru; também recusa o cliente-anomalia no tablet);
   - **APAGAR** (interruptor da loja);
   - **NÃO OLHAR / NÃO ABRIR** (ignorar com risco).

   "Esconder" e "sair para religar" deixam de fazer sentido se a loja é o ponto seguro: confirmar com o dono (Q).
6. **Calma durante a anomalia (orçamento de complexidade).** Enquanto uma anomalia está ativa, o spawn de clientes **pausa** e a paciência dos clientes na fila **congela**. Isso dá ao jogador o "momento calmo" para olhar para fora. Novidade da noite = recuo em outra coisa: menos clientes na noite que estreia uma regra.
7. **Dosagem por noite (Provisório):**
   - N1: **2–3** eventos, todos da mesma família;
   - N2–N5: **3–5**;
   - N6+: **5–7**;
   - **1 simultânea até a N5, no máximo 2 depois** (nunca no mesmo canal);
   - **intervalo mínimo de 60–90 s** entre eventos, com respiro de 30 s sem nada depois de cada um;
   - catálogo total no relançamento: **8–12 anomalias**, não 35; variar **frequência e prazo**, não a quantidade de tipos.
8. **Janela justa.** Prenúncio (≥1,5 s), depois sinal específico, depois **resposta em 6–15 s**, e o prazo aparece como algo no mundo (o vulto anda, a luz apaga mesa por mesa). Anomalia que some antes do prazo nunca pune.
9. **Feedback explícito.**
   - Acerto: som de alívio, a luz de fora volta e um selo "OK" pequeno, sem moeda que confunda com venda.
   - Erro: jumpscare cartoon curto (DEC-256), **−35 de sanidade com a barra tremendo** e um cartão de 2 s dizendo **qual regra foi quebrada** (lição do False Mall).
10. **Falso positivo custa, mas menos.** Fechar a persiana sem anomalia ou recusar um cliente normal custa **dinheiro/pedido**, não sanidade. Sem custo, o jogador fecha tudo; com custo alto, ele trava.
11. **Sanidade legível e progressiva.**
    - 3 erros = cai (100 → 65 → 30 → 0).
    - Cada faixa tem um efeito leve e Mild: vinheta, som abafado e, abaixo de 30, um "falso aviso" visual que não pune (como as luzes imaginárias do Phasmophobia).
    - Recuperar um pouco por anomalia acertada ou no fim da noite, para evitar o reset frustrante.
    - **[Q: a perda é por jogador ou do grupo?]** Sugestão: ação errada tira de quem agiu; omissão tira de todos que estão na loja.
12. **Co-op: perceber é papel.**
    - A anomalia de fora é visível **de qualquer posto** (vitrine larga atrás da linha de montagem, janela do drive-thru no campo de visão de quem grelha) e o prenúncio é global.
    - Um **ping/emote "LÁ FORA!"** de 1 tecla, porque muitos jogam sem voz.
    - Upgrade opcional de "vigia" (ex.: câmera/monitor externo no balcão) como versão do papel Observador. Também ajuda o solo.
13. **Teste de legibilidade antes de aprovar cada ficha.** Num pico de 4 pedidos, um testador que **não sabe** que a anomalia vem precisa notá-la em ≤3 s, de pelo menos 2 postos. Se não notar, a ficha volta.

### Implicação direta para a V3

O pacote MVP da V3 deve ser refeito sobre as regras 1, 3 e 5. Ficam como candidatas naturais ao "lá fora pela vitrine": ANM-006 (stalker), 008 (carro comprido no drive-thru), 010 (Hush nas mesas), 030 (mesas olham), 031 (carro sem motorista), 033 (pet), mais a família A no tablet. Saem do sorteio, ou viram só susto sem verbo e sem punição: 021, 023, 024, 026, 027 e 034.

---

## Fontes

- Automaton, entrevista com Kotake Create sobre Platform 8 (protótipo no trem cortado; anomalias cortadas por dificuldade): https://automaton-media.com/en/interviews/interview-the-exit-8-developer-kotake-create-on-the-perks-of-being-a-solo-dev-and-how-platform-8-came-to-be/ (corpo completo não carregou; trechos via resultado de busca)
- Automaton, "The Exit 8 dev reveals how he made…" (influência de Observation Duty): https://automaton-media.com/en/news/20240214-27192
- Wikipedia, The Exit 8 (regras na placa, reset, recepção crítica): https://en.wikipedia.org/wiki/The_Exit_8
- SCRMBL, "Year of the 8-like" (baseline familiar, gênero): https://scrmbl.com/post/year-of-the-8-like-japans-indie-game-anomaly
- Selectbutton, thread "Anomaly Walker Games" (False Mall, Who's At the Door?, Cabin Factory, Twisted Gallery, 5th Door, Stairway 7): https://selectbutton.net/t/anomaly-walker-games/16577
- JumpDashRoll, Shift 87 review: https://www.jumpdashroll.com/article/shift-87-review
- KosGames, Observation Duty 6 (ritmo de 15 min, carência): https://kosgames.com/im-on-observation-duty-6-all-anomalies-44946/
- Stash, Observation Duty 6 (anomalias demais = game over): https://stash.games/games/im-on-observation-duty-6
- Earnaldo, guia do Scary Shawarma Kiosk: the ANOMALY (Roblox; números por turno, persiana, quadro de regras; guia de fã): https://earnaldo.com/blog/scary-shawarma-kiosk-free-robux-guide
- The Spike, Animal Hospital (Roblox, co-op 4, papéis, sanidade; guia de terceiros): https://www.thespike.gg/roblox/animal-hospital
- AllThings.How, Spuddy's (Anomaly) (Roblox, diner; famílias por local): https://allthings.how/how-to-identify-all-anomalies-in-spuddy-s-anomaly-on-roblox/
- Doors / Rush (guias de fã, aviso por luz e som, armário): https://www.ginx.tv/en/doors-rush e https://attackofthefanboy.com/guides/roblox-doors-all-entities-and-how-to-survive-them/
- FNAF Wiki, Night 1: https://freddy-fazbears-pizza.fandom.com/wiki/Night_1_(FNaF1)
- Dead by Daylight Wiki, Terror Radius: https://deadbydaylight.wiki.gg/wiki/Terror_Radius
- Phasmophobia Wiki, Light: https://phasmophobia.fandom.com/wiki/Light ; fórum Steam sobre sanidade média: https://steamcommunity.com/app/739630/discussions/0/2984159549083496390
- Game Developer, "Revisiting the AI of Alien: Isolation" (menace gauge): https://www.gamedeveloper.com/design/revisiting-the-ai-of-alien-isolation
- MCV/Develop, post-mortem de Overcooked (recuo a cada receita nova, nível que se mexe): https://mcvuk.com/the-develop-post-mortem-overcooked/
- Push Square, entrevista Overcooked 2 (emotes no online): https://pushsquare.com/news/2018/08/interview_chewing_the_fat_with_overcooked_2_developer_ghost_town_games (403 ao abrir; trecho via busca)
- Red Bull, entrevista Ghost Town Games (níveis dinâmicos): https://www.redbull.com/int-en/overcooked-2-ghost-town-games-interview
- Game*Spark, entrevista Left 4 Dead 2007 (AI Director): https://www.gamespark.jp/article/2007/04/10/11866.html
- Vaporlens, Hospital 666 (co-op, reclamações): https://vaporlens.app/app/2774380/hospital_666

Não confirmado: a busca não achou fonte primária para Chilla's Art *The Convenience Store* (夜勤事件), para *Late Night Mop* (só comentários de itch.io) nem para o modelo nomeado do Director do L4D. Os números do Roblox (Shawarma, Animal Hospital) vêm de guias de terceiros e podem mudar entre versões. Nenhum dado de limite técnico do Roblox foi necessário aqui.
