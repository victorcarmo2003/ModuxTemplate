Status: Rascunho

# Sell Hotdogs! — Resumo executivo

Para quem chega de fora e precisa entender o jogo sem ler `docs/`. Escrito em 2026-10-11 a partir dos documentos de design, arte, mapa, história, áudio e do board de tarefas.
Este resumo **não decide nada**. Vale o que está em `docs/decisions.md` (DEC-001 a DEC-222). Onde o documento-fonte ainda é Rascunho, o texto diz **Provisório**.
Trechos marcados **[SPOILER]** revelam a história; pule se este documento for para público externo.

---

## 1. Em uma frase e pitch

**Uma frase:** jogo cooperativo de Roblox em que você faz e vende hot dogs numa esquina de cidade pequena, de dia, e sobrevive aos turnos da noite, quando coisas que não deveriam estar ali começam a aparecer.

**Pitch:**
- Você é um desempregado que vê um panfleto de vaga num poste, liga e vira **funcionário** do Walt, dono do carrinho Bramble's Corner Dogs.
- De dia o jogo é gerenciamento físico e fofo: grelhar, montar, atender, comprar estoque, melhorar o carrinho.
- Do 2º dia em diante, depois do turno do dia, a party segue direto para o **turno da noite, no próprio carrinho** (Provisório, pedido do dono 2026-10-12). Mais tarde (depois da noite 2) o Walt oferece o **Food Trailer**, um desbloqueio opcional que ajuda contra as anomalias (janela que fecha, luzes, café).
- A noite é a mesma cidade, o mesmo trabalho, mas com **regras ditas por telefone** e **anomalias** que é preciso observar, lembrar e tratar do jeito certo.
- Pilares (DEC-002): Vender, Progredir, Gerenciar, Observar, Sobreviver, Descobrir.
- North Star: "Estou construindo uma vida melhor vendendo hot dogs... mas alguma coisa está muito errada aqui."
- Não é: jogo de salas e corredores, simulator de "clicar e o número sobe", horror puro nem tycoon passivo (DEC-004). O jogador precisa **fazer** os hot dogs.

## 2. Público e plataforma

| Item | Valor | Fonte |
|---|---|---|
| Plataforma | Roblox, **mobile primeiro** + PC; console sem teste no MVP | DEC-014, DEC-171 |
| Público | infantojuvenil, sem violência; classificação alvo **Mild** | DEC-023, DEC-172 |
| Modo | **co-op de 1 a 4** (solo permitido), um carrinho só, dinheiro e progressão da party | DEC-012, DEC-032 a DEC-034 |
| Sessão | lobby, depois **squad** numa plataforma física, depois servidor privado da run | DEC-034, DEC-179 |
| Câmera | **primeira pessoa** travada na run; lobby em 3ª pessoa (Provisório) | DEC-013, DEC-039 |
| Idioma | inglês, sem localização | DEC-022 |
| Duração | run longa, **~6 h**, sem save entre runs | DEC-035, DEC-057 |
| Celular mínimo | **adiado** (otimização depois) | DEC-090 |

Inspiração de estrutura: "Animal Hospital" (Roblox). Só inspiração, nada de cópia de nomes, visuais ou assets (DEC-013, DEC-210).

## 3. Core loop

### 3.1 Momento a momento (um cliente)

1. O cliente chega na fila e mostra o **pedido em um balão** com ícones.
2. O jogador pega a salsicha do estoque, que vai sozinha para a **grelha**.
3. Salsicha pronta vai para a **esteira de descanso**. O pão vai para a **tábua** e é cortado.
4. Salsicha no pão, depois **complementos** (cada um segura 1 s).
5. Entrega ao cliente, que paga. O dinheiro cai na **gaveta do caixa**.
6. Se faltar ingrediente, o jogador corre ao **Mart** do outro lado da rua (e a rua tem trânsito).

### 3.2 Loop de turno e de sessão

```
LOBBY -> squad (1-4) -> RUN
cutscene -> dia 1 (tutorial) -> dia 2 -> noite 1 (carrinho) -> dia 3 -> noite 2 -> ... -> dia 11 -> noite 10 -> final
-> gemas -> lobby (classes)       (a noite k é jogada no fim do dia k + 1; trailer oferecido depois da noite 2, opcional)
```

- Turno de dia: ~4,6 min reais (preparação 7:00 AM, loja aberta 8:00 AM a 6:00 PM, fechamento, resumo; Q-200).
- Noite: relógio 8:00 PM a 6:00 AM, **9 min reais na noite 1 até 15 min na noite 10** (+40 s por noite; Provisório, Q-207). Run perfeita ~3,4 h.
- **Dia 1** é o tutorial e não tem noite. **Nights 1 e 2** só têm anomalias simples e compatíveis com o carrinho (recusar, descartar).
- **Trailer (opcional):** oferecido na manhã seguinte à noite 2 (`Content.Trailer.OfferAfterNight`), comprado na placa FOR SALE. Dá janela de serviço, luzes e café; sem ele as 10 noites seguem no carrinho, com dificuldade maior.
- Fim de turno: gaveta vira dinheiro da party, **nota A–D** com bônus do chefe (A +20%, B +10%), compra de upgrades.
- Sem save entre runs. Persistem só gemas, classes e o contador do "Day 100".
- Quem cai da conexão pode voltar enquanto houver alguém da party na run. Se todos saem, a run fica guardada **15 min** num snapshot.
- **Não existe mais "modo dia infinito"**: não comprar o trailer não pula as noites (Provisório, Q-207; o contador "Day 100" fica parado até uma decisão).

## 4. Mecânicas principais

### 4.1 Cozinha e pedidos (FEAT-006, FEAT-010)
- Base sempre **pão + salsicha**. Pedido = combinação **livre** de 0 a 3 complementos distintos, sem quantidade e sem cardápio fixo.
- Complementos: Ketchup e Mustard (dia 1), Cheese (dia 2), Bacon (dia 3), Potato Sticks (dia 4), Cream Cheese (dia 6).
- Preço = **$4 + complementos** (molho $1, Cheese $2, Bacon $3, Potato Sticks $2, Cream Cheese $2).
- Entrega incompleta paga 50% sem gorjeta. Entrega **errada** (complemento não pedido) paga $0.

### 4.2 Clientes e paciência em duas fases (FEAT-009, FEAT-011)
- Paciência = **40 + 5K s** (K = número de complementos). Dentro de **16 + 4K s** o cliente dá **+$1 de gorjeta**. Exemplo K = 1: 45 s de paciência, 20 s para a gorjeta.
- Teto de **12 NPCs** simultâneos. Primeiro cliente do dia 1 chega a cada ~22 s e o fluxo cresce 8% por dia.
- **Ladrão** (Quick Quentin, só de dia, a partir do dia 2): sem ninguém a 14 studs do carrinho, abre a gaveta (4 s, DEC-182) e leva 50%. Quem entra na zona impede e ganha $5.
- Pedestres da rua podem **virar clientes** (imersão; Provisório, TASK-163).
- Humor dinâmico dos NPCs decidido (DEC-187); desenho ainda em `Q-164`.

### 4.3 Estoque e Mart (FEAT-007, FEAT-008, FEAT-015)
- O carrinho **não se reabastece sozinho**. Ingredientes vêm em **pacotes físicos** do Ninth Street Mart, 100–120 studs adiante, máximo 2 por jogador.
- A rota **cruza a rua** (faixa CW-1, sem semáforo): o carro nunca para por jogador. Ser atropelado é **pastelão**: ragdoll, estrelinhas, o item cai, sem dano e sem perder sanidade.
- Dentro do Mart: prateleiras, frutas/verduras (só cenário) e, na parede do fundo, a **bancada de upgrades**.

### 4.4 Upgrades (`design/upgrades.md`)
| Upgrade | Níveis | Preço base |
|---|---|---|
| Grill | 1–3 | $210 |
| Cooler | 1–3 | $170 |
| Counter | 1–3 | $230 |
| Cash Drawer Lock | 0–1 | $80 |
| Trailer Lights | 0–1 | $100 (só após o trailer) |
| Food Trailer | troca de veículo | **$300 × party** (1p $300, 2p $450, 3p $570, 4p $660) |
| Coffee Maker | incluída | vem fixa no trailer |

- Básicos sempre à venda. Só itens **especiais** entram no sorteio por turno; hoje o único é o **Revive Kit** (15% por turno, $200 × party).
- Upgrades têm **peça visível** no veículo (DEC-006).
- Ideias novas **Provisórias** de 2026-10-11: mesas no Pad (UPG-008), Patio Lights, Back Bar e clientes em dupla (FEAT-037, FEAT-038).

### 4.5 Classes (`design/classes.md`)
- **Cada animal da crew é uma classe** (DEC-147). MVP com **6**: Cachorro "Rookie" (grátis), Coelho "Runner" (45 gemas), Gato "Line Cook" (45), Urso "Hauler" (45), Raposa "Hawker" (120), Coruja "Night Owl" (120). Panda e Leão entram na 1ª atualização (DEC-186).
- Passivas leves com contrapeso, teto de **±12%** de lucro e **nunca** mexem nas regras de anomalia.
- Escolha na tela "Crew" do lobby, travada durante a run.

### 4.6 Sanidade e anomalias (FEAT-019, FEAT-022, FEAT-023)
- **Sanidade** só à noite, por jogador: começa em 100; ver anomalia -5; quebrar regra comum -35; escuro -1/s; **café +25**. Sanidade baixa gera sons, vultos e alucinações. Jumpscare é raro e leve (DEC-173).
- Zerou: o jogador **desmaia** (ragdoll com rosto "X"), a **ambulância** chega e os médicos levam. Dá para **reviver** com Robux (só para si) ou com o Revive Kit, até 6:00 AM, no máximo 2 vezes por noite. Sem reviver, vira espectador até o fim da run.
- **10 anomalias**, uma nova por noite, somadas às anteriores (`story/anomalies.md`, **Aprovado**). Cada uma tem um verbo correto: atender, recusar, não olhar, luz, descartar, ponto seguro e **fechar a janela do trailer** (DEC-221; o "esconder" saiu).
- **Regra crítica fixa só na noite 7** (The Walker). Noites 1 a 6 não têm regra crítica.
- Perder a noite (todos caídos por mais de 10 s, ou quebrar a regra crítica) gasta a **única chance** do chefe da run. Perder uma 2ª noite encerra a run.
- Tensão econômica de design: comprar ingrediente ou guardar para o upgrade; upgrade ou trailer.

### 4.7 Tutorial com o chefe Walt (`story/script.md` §3, Rascunho)
- O dia 1 começa com o **telefone do carrinho tocando**. O prompt "Answer" é a primeira lição.
- Walt **fica na linha em viva-voz** durante o dia 1. Cada dica sai uma vez, quando a party chega ao passo: placa OPEN, salsicha, grelha, pão, pedido, entrega, estoque, "olhe os dois lados" antes de atravessar.
- Sem painel e sem botões em tela: a ação é sempre o **prompt no mundo**.
- A implementação atual usa uma única ligação para o tutorial inteiro, com ferramentas de dev (comandos `/dev tutorial`, `/dev tutorial voice`, painel F8) e vozes pré-carregadas (commit `44131a7`). Desde 2026-10-11 (Provisório, Q-193) ele roda sempre no dia 1 de toda run e não é salvo (`TutorialDone` virou campo legado).

## 5. Progressão e economia

| Tema | Regra |
|---|---|
| Ordem da run | D1 (tutorial), D2, N1, D3, N2 … D11, N10, final; trailer opcional depois da noite 2 (Provisório 2026-10-12, Q-207) |
| Dinheiro inicial | $30 (da party). Sem XP, sem níveis, sem reputação no MVP |
| Desbloqueios | ingredientes por dia (§4.1) e upgrades por compra; trailer só depois da noite 2 |
| Dinheiro sem uso | aceito após comprar tudo (~dia 8 solo); decoração fica para depois |
| Gemas (por jogador, salvas a cada evento) | dia concluído 2 (+1 com nota A, e só com 3 ou mais pedidos completos); noite N dá 15 + 2(N-1); final +100; "Day 100" +300 |
| Uso das gemas | classes (45, 120, 180) |
| Robux | **reviver** é a 1ª monetização (preço adiado, `Q-098`). Pedido de 2026-10-11, **Provisório**: pacotes de gemas (50, 130, 300, 700 no código), classe por Robux e **códigos** de resgate |
| Loja e códigos | `ShopService` e `CodesService` em QA; ids de produto ainda 0 até o Creator Hub; contradiz DEC-069 ("classes só com gemas ganhas jogando"), registrado em `Q-190` |
| Fora do MVP | eventos de demanda, validade de ingrediente, missões diárias (DEC-128) |

## 6. Mapa e ambiente

**MAP-01 "Ninth & Juniper"** (Rascunho): único mapa da run no MVP, na cidade de **Bellmoor**.
- Esquina da **Ninth Avenue** com a **Juniper Street**. O carrinho fica fixo no "Pad"; o trailer ocupa o mesmo lugar depois da compra (DEC-086).
- Banco com relógio, apartamentos em cima, estacionamento, lavanderia e o **Ninth Street Mart** 24 h com letreiro neon coral.
- Área jogável ~224 × 168 studs, ao ar livre, mais dois interiores de um cômodo (Mart e trailer). Rua aberta, não labirinto.
- Trânsito de carros andando de dia; rareia à noite (DEC-198). Postes da Juniper a cada 8 studs.
- Mapa sempre carregado (DEC-209).

**Lobby "Bramble's Corner Dogs HQ"** (`levels/LOBBY.md`, v2, Provisório): praça noturna quente com varal de lâmpadas e neon em tubo, para até ~30 jogadores.
- **Palco de classes** com o carrinho original exposto e a tela "Crew".
- **Gem Shop** (quiosque com pedestais) e canto dos **Codes** (mural).
- **8 plataformas de squad** (duas fileiras de 4): pisar numa cria ou entra no squad, com opções "Friends only" e "Max players", contagem de 5 s e a van "START SHIFT".
- Extras de ambiente: food court com trailer parado, fonte, cabine de foto, jardim.

## 7. História e tom

**Tom:** aconchegante e engraçado de dia, inquietante só à noite. Dois humores que não se misturam: **pastelão** (atropelamento, ladrão, mariposa na carteira) e **inquietante** (anomalias, sem piada visual). Sem violência; texto de jogo evita palavras como "die" e "body".

**Personagens-chave (todos animais da crew, DEC-178):**

| Personagem | Papel | Espécie |
|---|---|---|
| Walt Bramble ("the Boss") | dono do carrinho; liga por telefone, chama o jogador de "Rookie" | tartaruga corcunda, bastão, barba branca (DEC-202) |
| The Rookie | cada jogador | animal da crew, sem avatar Roblox (DEC-146) |
| Opal | atendente do Mart; fala curta, seca e gentil, não vende | coruja (DEC-203) |
| Quick Quentin | ladrão cômico, só de dia | guaxinim (DEC-159) |
| Mr. Pickett | cliente regular, pontual e nervoso | rato (DEC-203) |
| Médicos da Bellmoor Rescue | descem da ambulância quando alguém desmaia | coelho + panda, rosto cansado e máscara (DEC-213) |

**Anomalias (N1 a N10, aprovadas):** blank folks, wrong food, stopped clock, the copies, Raincoat Lady, the wavers, The Walker, long car, the knock, The Hush. O jogador observa, lembra a regra do Walt, escolhe o verbo certo.

**[SPOILER]** Final "The Light on the Corner" (`story/ending.md`, Aprovado, DEC-075):
- Ao amanhecer da 10ª noite, Walt aparece **em pessoa pela única vez**. Ele fez aquele turno desde 1979 e escolheu o jogador como sucessor.
- A esquina é um cruzamento que a luz do carrinho e as regras mantêm "educado". O que é o late crowd continua em aberto de propósito.
- A **Raincoat Lady** é a única que se deve **atender**; Walt a chama de "Marigold" uma vez.
- Há pós-créditos e gancho para outras esquinas em atualizações.

## 8. Identidade visual e áudio

**Visual** (`art/style-guide.md`, **Aprovado**, DEC-126):
- Estilo **toy low-poly**: formas grossas, chanfro largo, cor por atlas de gradiente, sem contorno pintado nem texto modelado.
- Packs base **Kenney + KayKit (CC0)**, com licenças registradas em `art/credits.md`.
- **Personagens = animais cartoon** em rig R6 custom ("HotDog Crew"): cabeça oval com focinho, rosto e **expressões por textura**, uniforme com boné vermelho e avental com hot dog. 18 espécies no catálogo, 6 jogáveis no MVP.
- **Três pacotes de textura** por personagem: dia (fofo), "Mid" (cansado) e noite (azul-marinho, um pouco assustador), ligados à **sanidade** da crew (DEC-166, DEC-167). NPCs usam Mid à noite; o pacote Night fica reservado à tensão (DEC-181).
- **Paleta:** Ketchup, Mustard, Cream, Teal, Aluminum; dia saturado e quente. Noite com ambiente azul-violeta `#1B2140` e postes de sódio `#FFB25A`.
- **Neon coral `#FF8A65`** do Mart é cor exclusiva do ponto seguro. Interior do trailer em branco quente `#FFE7C2`.
- Iluminação Future com fallback ShadowMap; orçamento de ~14 luzes locais (máx. 18).
- **UI kit** (AST-091, aprovado): pílulas de HUD, cartões Cream, botões Mustard, **sem vermelho de alerta**, fontes Fredoka One e Builder Sans. HUD só de status; prompt custom no mundo.

**Áudio** (`audio/sound-list.md`, Rascunho; DEC-222):
- **Música uma vez no início de cada turno** (dia: "Sunny Town" ou "Small Town"; noite: "Night Town" ou "Night Fall"). Resto do turno é **ambiente em loop com crossfade** (cidade, grilos, supermercado).
- Sons de terror dedicados (ver anomalia, início de anomalia, último passo do Walker, janela 5–6 AM) e uma **buzina goofy** na chegada do long car.
- Sem música nos créditos; "Melancolic City" no final.
- O usuário separa os arquivos de áudio pela lista e **faz as animações** do rig (DEC-220).

## 9. Stack técnica (5 linhas)

1. Roblox em **Luau `--!strict`**, framework **Modux V3** (`src/Modux`), estrutura por feature (`src/<Feature>/server` e `client`).
2. Rede com **Lync** (sets para estado compartilhado, packets para eventos); definições em `src/Libs/Net`.
3. **Charm** no servidor para estado reativo, **Vide** no client para UI.
4. Dados do jogo em tabelas (`src/Shared/Content`) validadas no boot; persistência com ProfileStore e snapshot de run no MemoryStore.
5. **Feito 100% com IA:** agentes especializados (secretário, game-designer, architect, coders, modelador no Blender, QA) seguem `docs/PIPELINE.md`. Só o usuário aprova.

## 10. Estado atual (2026-10-11)

- **Fase 1, Produção**, desde a bandeira verde (DEC-193, 2026-10-10). Última decisão registrada: **DEC-222**.
- **Documentos:** só `art/style-guide.md`, `story/anomalies.md`, `story/ending.md` e as propostas das rodadas 1 e 2 estão **Aprovados**. `vision.md`, `design/*`, `levels/*`, `tech/*`, `tasks/board.md` e o resto são **Rascunho** e valem como base **Provisória**.
- **Assets:** a maioria das fichas de comida, equipamentos, veículos, cidade, rig da crew e UI kit está **Aprovada**. Restam fichas em Rascunho para aprovação (lote de ondas 2 e 3).
- **Board:** 160 linhas de TASK. Aproximadamente **9 Feito**, **109 Em QA**, **5 em andamento**, **23 a fazer ou bloqueadas** e **14 substituídas ou em outros estados** (contagem por busca no texto, não exata).
- **Perguntas abertas:** **0 bloqueantes**. A tabela "Abertas" de `open-questions.md` lista cerca de **49** não bloqueantes; o índice de `docs/README.md` ainda diz "32" (desatualizado). Há 1 arquivada (Q-054).
- **Principais pendências (todas não bloqueantes):**
  - Q-190 e Q-191: classe por Robux, preços, códigos.
  - Q-098: preço do reviver em Robux (adiado pelo usuário).
  - Q-120: sorteio e uso do Revive Kit.
  - Q-159, Q-147, Q-148: gatilhos e intensidade do pacote Night.
  - Q-162 a Q-165: teto de NPCs, trailer no nível 1, humor dinâmico.
  - Q-167 e Q-168: animações do rig e licença dos áudios.
  - Q-173: números da janela do trailer.
  - Q-175 a Q-182: Mart v2, mesas e clientes em dupla.
- **Dependem do usuário:** aprovar fichas em Rascunho, criar produtos no Creator Hub, animações e arquivos de áudio.
- **Inconsistências conhecidas (vale a DEC):** `vision.md` ainda cita jogador com avatar R6 sem braços e 4 classes no MVP; valem DEC-146, DEC-219 e DEC-186 (6 classes, braços reais em 1ª pessoa). `story/characters.md` ainda descreve personagens humanos; vale DEC-178.

## 11. Glossário curto

| Termo | Significado |
|---|---|
| Run | uma partida completa (~3,4 h, Provisório): dia 1 (tutorial), dia 2, depois noite e dia alternados até a noite 10 |
| Party / squad | grupo de 1 a 4 jogadores, uma plataforma no lobby |
| Pad | piso de concreto na esquina onde ficam o carrinho e o trailer |
| Carrinho / Food Trailer | veículos de trabalho; o trailer é um desbloqueio opcional depois da noite 2; a noite começa no carrinho |
| Mart | Ninth Street Mart, mercadinho 24 h (estoque, upgrades, ponto seguro) |
| Crew / HotDog Crew | animais jogáveis; cada um é uma classe |
| Gemas | moeda entre runs, compra classes |
| Anomalia (ANM-###) | evento estranho da noite, com sinal e verbo correto |
| Regra crítica | regra do Walt que, se quebrada, perde a noite (só noite 7) |
| Sanidade | medidor noturno por jogador; zerar causa desmaio |
| Revive Kit | item raro do Mart que traz a ambulância de volta |
| Chance do chefe | única chance por run de repetir uma noite perdida |
| Late crowd | nome do Walt para tudo que aparece à noite |
| DEC / Q / TASK | decisão do usuário / pergunta aberta / tarefa de implementação |

## Documentos-fonte (para se aprofundar)

- Índice e progresso: `docs/README.md`, `docs/PIPELINE.md`, `CLAUDE.md`
- Visão e loop: `docs/vision.md`, `docs/decisions.md`, `docs/open-questions.md`
- Design: `docs/design/features.md`, `items.md`, `npcs.md`, `upgrades.md`, `progression.md`, `economy.md`, `classes.md`
- Mapas: `docs/levels/MAP-01.md`, `docs/levels/LOBBY.md`
- História: `docs/story/world.md`, `characters.md`, `script.md`, `anomalies.md`, `ending.md`, `ui-text.md`
- Arte e áudio: `docs/art/style-guide.md`, `asset-list.md`, `credits.md`, `docs/audio/sound-list.md`
- Técnica e tarefas: `docs/tech/architecture.md`, `network.md`, `data.md`, `content-data.md`, `docs/tasks/board.md`
- Fontes originais do usuário: `docs/source/gdd-v1-usuario.md`, `docs/source/respostas-2026-10-08.md`
