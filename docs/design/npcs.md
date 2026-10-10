Status: Rascunho

# NPCs: clientes, ladrão, atores de anomalia (NPC-###)

Autor: game-designer, 2026-10-08. Fontes: **[DEC-010, DEC-018, DEC-023, DEC-045, DEC-050, DEC-051, DEC-054, DEC-060, DEC-071, DEC-072]**,
`proposals-round-1.md`, `proposals-round-2.md` §3.4 (campo de multiplicador por tipo de cliente).
Nomes de personagem vêm de `docs/story/characters.md` (Quick Quentin CHR-004, Opal CHR-003, Mr. Pickett CHR-005, Raincoat Lady CHR-006);
nomes de tipo de cliente seguem placeholders. Aparência, falas e o **conteúdo das 10 anomalias** são do narrative-writer (`docs/story/anomalies.md`, N1–N10) e do art-director.
Aqui fica o comportamento-base e o contrato mecânico. Tabela de dados: `CustomerTypes`, `Thief`, `Anomalies`, `AmbientNpcs`.

Conciliação da rodada 7 (DEC-073, DEC-074): os slots NPC-009 a NPC-018 seguem a **ordem e os verbos de `anomalies.md`**; regra crítica **fixa: só ANM-007 (The Walker)**.

Conciliação das rodadas 8–12 (DEC-080 a DEC-109):

- Anomalias têm ID **`ANM-###`** (DEC-096): N1 = ANM-001 … N10 = ANM-010. Os atores de servidor seguem NPC-009 a NPC-018 e referenciam o `ANM-###`. Onde o texto ainda diz "Nk", leia ANM-00k.
- Todo personagem é **R6** (DEC-089, DEC-097).
- NPCs novos: **NPC-022** carro de trânsito (DEC-087, DEC-095), **NPC-023** ambulância e **NPC-024** paramédicos (DEC-091).
- Orçamento: veículos ganham **teto próprio**; Opal sai do teto de 12 (proposta para Q-091 a); paramédicos são atores visuais.

Conciliação das rodadas 13–15 (DEC-110 a DEC-129):

- Ambulância na ida: **médicos descem e levam o corpo**; na volta do reviver ninguém desce (DEC-114). NPC-023, NPC-024.
- ~~Semáforo~~ (DEC-120 revogada por **DEC-130**: sem semáforo no MVP). Rodadas 16–17: rota trailer ↔ Mart cruza a Juniper Sul em CW-1, o jogador atravessa na sorte. **DEC-133** (Q-129 B; FEAT-033, tabela `Traffic.Crossing`): faixas continuam pintadas; NPC só cruza a pista na faixa, com **reserva de faixa** no servidor; carros param para NPC com reserva e **nunca** para jogador; PARE nos braços da Juniper. NPC-019, NPC-022, NPC-024, clientes.
- Paradas da ambulância com os IDs do `MAP-01.md` (AMB-M, AMB-P, REV-1..4).
- Trânsito à noite: ≤ 1 carro até 9 PM, 0 depois (recomendação para Q-103, FEAT-033).

## Template de ficha

```
### NPC-### — Nome
Papel · Turno · Libera · Custo no teto de NPC · Origem
Comportamento (estados)
Números: velocidade, peso de spawn, ajuste de pedido
Invariantes (o que é sempre igual — base para anomalias)
Critérios de aceite
```

## Índice

| ID | NPC | Papel | Turno |
|---|---|---|---|
| NPC-001 | "Office Worker" | cliente | dia e noite |
| NPC-002 | "Student" | cliente | dia |
| NPC-003 | "Jogger" | cliente | dia |
| NPC-004 | "Construction Worker" | cliente | dia e noite |
| NPC-005 | "Grandparent" | cliente | dia |
| NPC-006 | "Night Shift Worker" | cliente | noite |
| NPC-007 | Quick Quentin (CHR-004) | ladrão | dia |
| NPC-008 | Ator de anomalia (base) | modelo para os slots | noite |
| NPC-009 a NPC-018 | Anomalias N1–N10 (`anomalies.md`) | anomalia | noite |
| NPC-019 | "Pedestrian" | ambiente | dia |
| NPC-020 | Opal (CHR-003) | atendente do Ninth Street Mart (ambiente + falas) | dia e noite |
| NPC-021 | Mr. Pickett (CHR-005) | cliente regular | dia (e noite 4) |
| NPC-022 | Carro de trânsito | ambiente (atropela jogador) | dia (denso) e noite (≤ 1 até 9 PM; 0 depois) |
| NPC-023 | Ambulância | veículo roteirizado de resgate | noite |
| NPC-024 | Médicos da ambulância (2) | atores visuais da coleta | noite |

## Orçamento de NPC por servidor **[DEC-045]**

Teto de **12 humanoides com IA de servidor** (DEC-045). Proposta: **teto próprio de veículos** e Opal fora do teto (estática, sem pathfinding; Q-091 a).

| Turno | Clientes (inclui Mr. Pickett) | Ladrão | Atores de anomalia | Pedestres | Total no teto 12 | Veículos (teto próprio) | Fora de qualquer teto |
|---|---|---|---|---|---|---|---|
| Dia | ≤ 8 | ≤ 1 | 0 | ≤ 2 | 11 (1 de folga) | ≤ 4 carros de trânsito | Opal |
| Noite | ≤ 6 | 0 | ≤ 3 humanoides (N1, N4, N5, N7) | 0 | 9 (3 de folga) | ≤ 1 carro de trânsito (só até 9 PM) + 1 ambulância + ANM-008 (long car) | Opal; médicos e maca (visuais) |

Anomalia de ambiente/objeto/item/som não tem humanoide e custa 0 no teto de 12. A **ANM-008** (NPC-016, `vehicle`) não tem humanoide: conta no **teto de veículos**, não no de 12; continua contando no teto de **3 atores de anomalia simultâneos** do agendador (FEAT-022), que é outro limite.
Alucinações e atores de cutscene (Walt e Raincoat Lady no final, FEAT-027) são só no client e custam 0 no servidor.
Carros de trânsito somem durante ANM-008, ANM-010, cutscenes e Final (FEAT-033).

---

## Clientes normais

### Comportamento comum (todos os clientes, NPC-001 a NPC-006)

| Estado | O que faz | Duração / regra |
|---|---|---|
| Chegar | nasce fora de vista num dos 2 pontos de entrada da calçada; anda pela calçada até a vaga livre do balcão | caminho fixo do level-designer |
| Esperar | para de frente para o balcão; ícone "!" sobre a cabeça; paciência corre | 40 + 5 × K s + Counter **[DEC-072]** |
| Pedido anotado | balão com ícones (pão, salsicha, até 3 complementos); idle de espera | janela de gorjeta 16 + 4 × K s |
| Pagar | animação de entregar dinheiro; "+$" na gaveta | 1 s |
| Reagir | balão feliz / neutro / reclamação / devolve (errado) | 1,5 s |
| Ir embora | mesmo caminho de volta até sumir fora de vista | — |
| Desistir | bufa, vai embora | paciência 0 |
| Recusado | aceno, vai embora | — |

Invariantes (o jogador aprende de dia; as anomalias quebram **um** deles por vez) **[DEC-010]**:

1. Sempre chega **andando pela calçada**, por um dos 2 pontos de entrada; nunca pela rua, nunca aparece do nada; só atravessa a pista na faixa, com reserva de faixa (espera no meio-fio até os carros pararem; FEAT-033, DEC-133).
2. Sempre tem **rosto** com expressão neutra que muda só na reação.
3. **Nunca dois iguais ao mesmo tempo**: cada tipo tem 4 variantes de roupa; o spawner não repete variante viva.
4. Sempre olha para o balcão enquanto espera; pisca; faz idle discreto.
5. Sempre paga **o preço exato** em dinheiro comum.
6. Sempre pede de **1 a 3 complementos** em balão com ícones conhecidos (pão + salsicha sempre presentes).
7. Sempre vai embora pelo mesmo caminho por onde veio.
8. Sempre tem sombra e reflexo; produz passos audíveis.
9. Cada tipo tem um horário de pico fixo (abaixo) — o relógio também é padrão.
10. Toda variante de roupa tem **um detalhe assimétrico legível no celular** (texto na roupa, relógio num pulso, bolsa numa mão). É o que a cópia espelhada da N4 inverte (requisito de arte, `anomalies.md` N4).

Mapa invariante → anomalia (N = `anomalies.md`): 2 → N1 (sem rosto) · 3 e 10 → N4 (cópia espelhada) · 6 → N1 (balão vazio) · 5 → N1 (moeda sem desenho, sabor).
As demais anomalias quebram padrões do **ambiente** (relógio do Bellmoor Savings, postes da Juniper Street, janelas dos apartamentos, rua vazia).

### Tabela `CustomerTypes`

Pesos de complemento multiplicam o peso base (Ketchup 10, Mustard 10, Cheese 7, Bacon 6, Potato Sticks 6, Cream Cheese 5 — DEC-071). `kShift`: chance de K ±1 após o sorteio da fase (limitado a 0–3).
Pesos de `kShift` se compensam no pool de dia (Jogger −1 × 40% × peso 15 = −6; Construction +1 × 30% × peso 20 = +6), então o K médio aprovado (DEC-071) se mantém.

| ID | Nome | Turno | Libera | Peso dia | Peso noite | Velocidade (studs/s) | `kShift` | Multiplicadores de complemento | Pico |
|---|---|---|---|---|---|---|---|---|---|
| NPC-001 | "Office Worker" | dia, noite | Day 1 | 30 | 30 | 14 | — | Mustard ×1,5 · Potato Sticks ×0,7 · Cream Cheese ×1,3 | 12:00–1:00 PM |
| NPC-002 | "Student" | dia | Day 1 | 30 | — | 14 | — | Ketchup ×1,5 · Cheese ×1,4 · Mustard ×0,6 | 3:00–5:00 PM |
| NPC-003 | "Jogger" | dia | Day 1 | 15 | — | 18 | −1 (40%) | Mustard ×1,2 · Bacon ×0,5 · Cream Cheese ×0,5 | 8:00–10:00 AM |
| NPC-004 | "Construction Worker" | dia, noite | Day 2 | 20 | 25 | 13 | +1 (30%) | Bacon ×1,8 · Potato Sticks ×1,3 · Ketchup ×0,8 | 11:00 AM–1:00 PM |
| NPC-005 | "Grandparent" | dia | Day 3 | 10 | — | 9 | — | Cream Cheese ×1,6 · Cheese ×1,2 · Mustard ×0,5 · Bacon ×0,6 | 9:00–11:00 AM |
| NPC-006 | "Night Shift Worker" | noite | Night 1 | — | 45 | 13 | — | Ketchup ×1,2 · Potato Sticks ×1,3 | 11:00 PM–1:00 AM |

Pico: peso do tipo ×2 na faixa de horário (dá ritmo previsível ao dia; o "horário errado" vira matéria-prima de anomalia).
Antes de liberar, o peso do tipo é 0 (o Day 1 tem 3 tipos; o Day 3 já tem os 5 de dia).

### NPC-001 — "Office Worker"

- Papel: cliente · Turno: dia e noite ("hora extra") · Libera: Day 1 · Custo: 1 · Origem: DEC-045, DEC-071
- Fantasia: almoço apressado; à noite, saindo tarde do escritório. Silhueta: camisa social, crachá, pasta.
- Números: tabela acima.
- Critérios de aceite: comuns (abaixo).

### NPC-002 — "Student"

- Papel: cliente · Turno: dia · Libera: Day 1 · Custo: 1
- Fantasia: saída da escola, mochila; gosta de ketchup e queijo. Silhueta: mochila, boné.

### NPC-003 — "Jogger"

- Papel: cliente · Turno: dia · Libera: Day 1 · Custo: 1
- Fantasia: pedido leve, pressa; anda mais rápido (18). Silhueta: roupa esportiva, fone.

### NPC-004 — "Construction Worker"

- Papel: cliente · Turno: dia e noite (turno de obra noturna) · Libera: Day 2 · Custo: 1
- Fantasia: fome grande, pede mais complementos, adora bacon. Silhueta: capacete, colete refletivo.

### NPC-005 — "Grandparent"

- Papel: cliente · Turno: dia · Libera: Day 3 · Custo: 1
- Fantasia: anda devagar (9), paciente, gosta de cream cheese. Silhueta: cardigã, bengala (sem conotação negativa).
- Nota: anda devagar mas a paciência só começa ao chegar no balcão; não é punido pela lentidão.

### NPC-006 — "Night Shift Worker"

- Papel: cliente · Turno: noite · Libera: Night 1 · Custo: 1
- Fantasia: trabalhador de plantão (uniforme genérico, sem marca); é o "cliente normal da noite" que define o padrão noturno.
- Nota: é o tipo mais comum à noite (peso 45), para o jogador saber como é um cliente normal **da noite** antes de ver a anomalia.

Critérios de aceite (clientes normais):

- Nenhum cliente normal quebra um dos 10 invariantes em 1.000 spawns simulados.
- Com os multiplicadores, a frequência de cada complemento por tipo fica a ±3 p.p. do esperado (1.000 pedidos).
- O K médio do pool de dia fica a ±0,05 do K médio aprovado da fase.
- Nenhum tipo aparece antes do dia de liberação nem fora do seu turno.

---

## Ladrão

### NPC-007 — Quick Quentin (o ladrão)

- Papel: ladrão · Turno: só dia · Custo: 1 · Origem: **[DEC-018, DEC-050, DEC-023]**; personagem CHR-004 (aparência e falas em `characters.md`)
- Falas: 1 balão por evento (espreitar, pego, fugindo), pool do narrative-writer.
- Gancho de roteiro: se Quentin foi impedido no dia D, a ligação do dia D+1 (a partir do Day 3) usa a variante "Heard you caught Quentin" (`script.md` §4.1; condição na tabela `BossCalls`, FEAT-018).

| Estado | Regra | Números |
|---|---|---|
| Sorteio | no início da Loja aberta | Day 1 0% · Day 2 50% · Day 3+ 70%; máx. 1 por dia |
| Aparecer | horário aleatório entre 9:00 AM e 3:00 PM; anda até um ponto de espreita visível (poste, banco) | ponto marcado pelo level-designer, 20–30 studs do veículo, visível da porta do mercado |
| Espreitar | parado, olhando para a gaveta; idle "disfarçado" (lê jornal, mexe no celular) | até 120 s; depois vai embora |
| Gatilho | nenhum jogador conectado e de pé a ≤ 14 studs do veículo por 3 s seguidos | — |
| Ir à gaveta | anda até a gaveta | ~4 s |
| Abrir | barra de progresso sobre a gaveta | 8 s (16 s com UPG-004) |
| Impedido | jogador entra na zona durante "Ir" ou "Abrir" → foge sem nada; gaveta +$5 ("Nice catch!") | cancelamento ≤ 0,5 s |
| Roubar | floor(gaveta × 0,5) (× 0,3 com UPG-004); nada se gaveta < $5 | — |
| Fugir | corre com saco de moedas até sumir; sem contato, sem briga | — |

Invariante própria: o ladrão é **sempre o mesmo personagem**, Quick Quentin (mesma roupa) — o jogador o reconhece; ele nunca aparece à noite (uma anomalia que imite o ladrão à noite seria pós-MVP).

- Critérios de aceite: os de `proposals-round-1.md` Q-036, mais: o ladrão nunca nasce se o teto de NPC estiver cheio (o sorteio do dia é refeito 30 s depois, até 3:00 PM).

---

## Anomalias

### NPC-008 — Ator de anomalia (base)

- Papel: modelo de comportamento para os slots NPC-009 a NPC-018 · Turno: noite · Origem: **[DEC-010, DEC-023, DEC-054]**; sistema em FEAT-022, verbos em FEAT-023

| `actorKind` | Base de comportamento | Custo no teto |
|---|---|---|
| `customer` | igual a um cliente normal (estados acima); ocupa vaga do balcão; quebra 1 invariante | 1 |
| `walker` | figura na rua; posições, parada e saída próprias; nunca vai ao balcão | 1 |
| `vehicle` | veículo que estaciona/passa; ninguém sai, nada é disparado (DEC-023) | 1 |
| `environment` | objeto, relógio, poste, janela com silhueta animada, interior do trailer muda de estado | 0 |
| `audio` | só som (batidas, voz com legenda "???") num ponto do veículo | 0 |
| `item` | item alterado (ITM-020) aparece no trilho de descanso ou numa tábua | 0 |

Contrato de cada slot (a ficha de anomalia do narrative-writer precisa preencher):

| Campo | Exigência |
|---|---|
| Sinal observável | quebra de **um** invariante (lista acima) ou de um padrão do ambiente visto de dia; perceptível antes do prazo do verbo |
| Regra do chefe | uma frase curta em inglês ("If…, …") que leva ao verbo correto sem nomeá-lo de forma ambígua |
| Verbo correto | exatamente 1 (tabela de slots) **[DEC-054]** |
| Verbo errado mais provável | declarado (para teste e para a regra) **[DEC-054]** |
| Consequência de erro | regra comum: −35 em quem falhou; regra crítica (só N7): noite perdida (FEAT-024) |
| Consequência visível sem violência | luz pisca, som, cliente some, item vira fumaça, chuva sobre o trailer — nunca ferimento, arma ou contato **[DEC-023]**. Efeito "de sabor" de `anomalies.md` é cortável se pedir sistema novo |
| Duração | 12–60 s por ocorrência (paciência, no caso de cliente) |

### Anomalias N1–N10 (NPC-009 a NPC-018)

Conteúdo (sinal, fala, forma curta, sabor): `docs/story/anomalies.md`. Aqui ficam os **números** que lá são "sugestão". Ocorrências por noite: FEAT-022 e `progression.md` §4.
Distribuição de verbos (substitui o exemplo de DEC-054, que a própria DEC chamou de "não fechado"): recusar 2 · atender 1 · não olhar 2 · luz 1 · esconder 2 · descartar 1 · ponto seguro 1.

Correspondência de IDs **[DEC-096]**: NPC-009 = ANM-001 · NPC-010 = ANM-002 · NPC-011 = ANM-003 · NPC-012 = ANM-004 · NPC-013 = ANM-005 · NPC-014 = ANM-006 · NPC-015 = ANM-007 · NPC-016 = ANM-008 · NPC-017 = ANM-009 · NPC-018 = ANM-010. A coluna "N" abaixo é o rótulo curto.

| ID | N | Nome no jogo | `actorKind` | Custo | Verbo correto | Alvo | Prazo / janela | Falha por ação | Falha por omissão | Duração | Crítica |
|---|---|---|---|---|---|---|---|---|---|---|---|
| NPC-009 | N1 | The blank folks | customer | 1 | recusar | shared | paciência | "Take Order" nele (paga quem tocou) | **não** (ocupa a vaga até a paciência acabar) | paciência | não |
| NPC-010 | N2 | The wrong food | item | 0 | descartar | shared | até ser usado ou descartado; some às 6:00 AM | servir Hot Dog com o item (paga quem serviu) | **não** | até resolver | não |
| NPC-011 | N3 | The stopped clock | environment | 0 | luz (sequência) | shared | 60 s após o relógio parar | — (sequência errada não falha; só não conta) | **sim**: todos os ativos | ≤ 60 s | não |
| NPC-012 | N4 | The copies | customer (a cópia) | 1 | recusar (a cópia) | shared | paciência | "Take Order" na cópia (paga quem tocou) | **não** | paciência | não |
| NPC-013 | N5 | The Raincoat Lady | customer | 1 | atender | shared | paciência (40 + 5K s + Counter) | "Refuse" (paga quem recusou) | **sim**: paciência zerada → todos os ativos | paciência | não |
| NPC-014 | N6 | The wavers | environment (silhueta animada na janela, sem humanoide) | 0 | não olhar | personal | 20 s | — | quem manteve a janela no cone por **≥ 3 s contínuos** | 20 s | não |
| NPC-015 | N7 | The Walker | walker | 1 | não olhar | shared (aproximação) | 45 s | — | o Walker chega ao passo 10 | 45 s | **sim (a única)** |
| NPC-016 | N8 | The long car | vehicle | 1 | esconder | personal (zona do trailer) | 8 s após o farol alto acender | levantar antes do carro sair | não escondido quando o farol pisca 2× | ~25 s (2 + 8 + 15 s) | não |
| NPC-017 | N9 | The knock | audio | 0 | esconder | personal (zona do trailer) | fim da última batida (~12 s) | — | não escondido quando a última batida termina | ~12 s | não |
| NPC-018 | N10 | The Hush | environment | 0 | ponto seguro | personal | 15 s (do 1º poste ao poste da esquina) | sair da zona antes dos postes voltarem | fora da zona quando o poste da esquina apaga | ~35 s (15 + 20 s) | não |

Parâmetros por anomalia (colunas extras da tabela `Anomalies`, FEAT-022):

| N | Parâmetros |
|---|---|
| N1 | balão de pedido **vazio**; sem idle de respiração; falha → vai embora devagar e deixa uma "moeda sem desenho" na gaveta ($0, visual, some no resumo) |
| N2 | 2 variantes: salsicha cinza-azulada (entra no trilho de descanso **na próxima posição a ser usada**) e pão mordido (aparece já cortado numa tábua livre); chiado curto ao surgir; detalhes em ITM-020 |
| N3 | sequência: interruptor **desligado ≥ 5 s contínuos** e depois **religado**, dentro de 60 s; religar antes de 5 s zera a contagem (sem falha). Funciona **com ou sem** Trailer Lights (o interruptor sempre controla a lâmpada interna, FEAT-020). Falha → o relógio do HUD e o do Bellmoor Savings **congelam só no client** por 30 s e depois saltam para a hora certa (o relógio do servidor não para, DEC-048; proposta para Q-065) e a grelha para de chiar (áudio) |
| N4 | spawna o original (cliente normal, conta no teto de clientes) e a cópia espelhada (ator, custo 1) com ≤ 10 s de diferença; exige 2 vagas livres no balcão, senão espera. Na estreia, o 1º original é Mr. Pickett (NPC-021); depois, qualquer tipo |
| N5 | entrega **incompleta não é erro** (paga floor 50%, sem "Thank you, dear."); entrega **errada** → devolve o Hot Dog e **continua esperando** (`wrongServeRetry`); servida na janela de gorjeta → +$1 extra e "Thank you, dear." (1× por noite). Rosto completo (não confundir com N1). Falha → chuva só sobre o trailer 20 s, luzes piscam 1× |
| N6 | som de cortina correndo **antes** da silhueta aparecer; alcance de "ver" 80 studs; falha → aceno com as duas mãos e +2 janelas acesas por 5 s |
| N7 | 10 passos (posições sob os postes da Juniper Street, marcadas pelo level-designer); o passo 10 é a borda da luz do trailer, **fixo** (não muda com o interruptor nem com Trailer Lights — resolve a interação N3 × N7); avança 1 passo a cada 1 s acumulado em que **qualquer** jogador ativo o tem no cone (tempo da party, não soma por jogador); sem olhares, recua 1 passo a cada 10 s; alcance de "ver" 300 studs; sinal sonoro no início: o último poste da Juniper zumbe ~2 s e para seco, ouvido por toda a party (DEC-123); a alucinação do poste pisca sem zumbir e passo abafado a cada avanço; no fim da ocorrência recua para o escuro e some; passos não acumulam entre ocorrências |
| N8 | farol alto acende 2 s após estacionar; esconder = "Hide" atrás do balcão do trailer; jogador fora da zona do trailer (ex.: no Mart) não é testado. Falha → luz interna apaga 3 s (não chega a drenar), buzina baixa. **Com trânsito (DEC-087, proposta para Q-103)**: à noite há ≤ 1 carro de trânsito até 9 PM (farol baixo) e **nenhum** depois das 9 PM (FEAT-033, alinhado com `MAP-01.md` §9.5); **nenhum carro de trânsito para no meio-fio**; nenhum modelo de trânsito é preto e comprido. A ANM-008 (só depois das 9 PM) é o único carro em movimento, o único que estaciona e o único com farol alto. Não atropela ninguém (estaciona no meio-fio oposto ao trailer) |
| N9 | 3 batidas, pausa, 3 batidas (~12 s) com legenda "???"; a porta dos fundos **não tem prompt** (trancar/abrir fora do MVP, DEC-054); jogador no Mart não é testado. Falha → a porta abre um dedo, guardanapos voam |
| N10 | apaga os postes da Juniper um a um; quando o poste da esquina apaga, desliga também as `LightZone` do trailer até os postes voltarem; zona segura = área marcada sob o letreiro "OPEN 24 HOURS" **e** o interior do Ninth Street Mart (proposta: quem está comprando não falha); a zona conta como luz. Night 10: a 3ª ocorrência é **roteirizada às 5:45 AM** e dura até 6:00 AM (FEAT-027) |

Exclusões do agendador (campo `exclusiveWith`, sem código específico):

| Anomalia | Não começa enquanto estiver ativa | Motivo |
|---|---|---|
| N10 | N3, N8, N9 (e vice-versa) | verbos em lugares opostos (trailer × Mart); o interruptor fica sem efeito durante o Hush |
| N5 | N8, N9, N10 (e vice-versa) | a paciência da Raincoat Lady correria enquanto a party se esconde ou sai; falha injusta |
| N4 | N1 no mesmo cliente | "um evento por cliente" (`anomalies.md`) |
| ambulância (NPC-023) | não é despachada durante N8 e N10 | carro parado no meio-fio e rua apagada são sinais das anomalias; a ambulância espera (FEAT-034) |

Pico de atores simultâneos: no máximo 3 com custo 1 (candidatos: N1, N4, N5, N7, N8); o agendador nunca passa do teto.

Critérios de aceite (anomalias):

- A tabela `Anomalies` tem as 10 linhas acima, na ordem de `anomalies.md`; só NPC-015 (N7) tem `critical = true`.
- N1/N4: "Take Order" no ator dá −35 só em quem tocou; deixar esperar até a paciência acabar não tira sanidade de ninguém.
- N2: o Hot Dog montado com o item alterado mostra o sinal na mão; servi-lo dá −35 em quem serviu; descartar o item ou o Hot Dog fecha a ocorrência com sucesso.
- N3: desligar 5 s e religar dentro de 60 s é sucesso **com e sem** UPG-005; religar com 4 s não falha nem conta; passar de 60 s dá −35 em todo jogador ativo.
- N5: "Refuse" nela dá −35 em quem recusou; paciência zerada dá −35 em todos os ativos; entrega incompleta não tira sanidade.
- N6: olhar 2,9 s contínuos não falha; 3,0 s falha só para quem olhou.
- N7: com 1 a 4 jogadores olhando ao mesmo tempo, o Walker avança no máximo 1 passo por segundo; no passo 10 a noite é perdida em ≤ 3 s.
- N8/N9: jogador escondido do início ao fim não perde nada; jogador no Mart não é testado.
- N10: na Night 10 a ocorrência das 5:45 AM sempre acontece; nenhuma N3, N8 ou N9 começa durante um Hush.
- Com o conteúdo ligado, um testador que ouviu a regra identifica o sinal em ≥ 80% das ocorrências de estreia (playtest).
- Nenhuma anomalia usa violência ou contato físico como sinal ou consequência.

---

## Ambiente

### NPC-019 — "Pedestrian"

- Papel: ambiente (não interage) · Turno: só dia · Custo: 1 (máx. 2) · Origem: proposta aceita pelo level-designer (Q-083 a; enche Bellmoor de dia; a rua vazia à noite é contraste)
- Comportamento: atravessa a cena por caminhos fixos da calçada; cruza a pista só em faixa de pedestre, com reserva de faixa (carros que chegam param na linha; FEAT-033, DEC-133); nunca para no balcão; obedece aos invariantes 1, 2, 3, 7, 8.
- Corte de escopo: é o primeiro item a sair se o orçamento de performance apertar no mobile.
- Critérios de aceite: pedestre nunca ocupa vaga do balcão; à noite não nasce.

### NPC-020 — Opal (atendente do Ninth Street Mart)

- Papel: ambiente + falas · Turno: dia e noite · Custo: **0 no teto de 12** (humanoide R6 estático, sem pathfinding; proposta para Q-091 a) · Origem: CHR-003, **[DEC-079, DEC-099]**
- Não vende nada, nem na bancada de upgrades (loja na parede, sem vendedor, DEC-101). Não é âncora de anomalia (a âncora AN-08 do `MAP-01.md` sai dela, Q-091 b).
- Comportamento: fica atrás do caixa do Mart, idle de palavras cruzadas; **não vende** (compra continua por prompt na prateleira, DEC-049); sem prompt.

| Regra | Valor |
|---|---|
| Gatilho de fala | jogador entra num raio de 8 studs do caixa |
| Frequência | 1 balão por visita; cooldown de 90 s por jogador; balão visível só para quem entrou no raio |
| Pool | por fase (dia · noites 1–3 · 4–6 · 7–10), texto do narrative-writer; sorteio sem repetir a última fala do jogador |
| Duração do balão | 3 s |
| Anomalias | nunca é alvo nem ator de anomalia; nunca some, nem no Hush (o Mart nunca apaga) |
| Corte de escopo | 2º a sair (depois dos pedestres); se cortada, só somem as falas; nada do roteiro quebra |

- Critérios de aceite:
  - Opal nunca sai de trás do caixa e não tem prompt.
  - Um jogador que fica parado no raio recebe no máximo 1 fala a cada 90 s.
  - A fala sorteada é sempre da fase do turno atual.

### NPC-021 — Mr. Pickett (cliente regular)

- Papel: cliente · Turno: dia (todo dia) e noite 4 (estreia da N4) · Custo: 1 (conta no teto de clientes) · Origem: CHR-005
- Comportamento: igual aos clientes normais (estados e invariantes acima); pedido sorteado como o de qualquer cliente **[DEC-064]**; fixos são a roupa e as falas.

| Regra | Valor |
|---|---|
| Horário | 1 vez por dia de loja, chegada sorteada entre 11:50 AM e 12:10 PM (do Day 1 ao fim do dia infinito) |
| Spawn | substitui o spawn normal mais próximo do horário; se o balcão estiver cheio, tenta de novo a cada 10 s até 12:30 PM |
| Perfil | `kShift` 0; multiplicadores do "Office Worker" (NPC-001) |
| Detalhe assimétrico | relógio no pulso esquerdo, maleta na mão direita, risca à esquerda, bordado "PICKETT & SONS" no peito esquerdo (invariante 10) |
| Noite | só na Night 4 (e na repetição dela), como original da 1ª ocorrência da N4 |

- Critérios de aceite:
  - Em 10 dias simulados, Mr. Pickett chega ao balcão 1 vez por dia, sempre entre 11:50 AM e 12:30 PM.
  - Nunca há dois Mr. Pickett normais vivos; a única exceção é a cópia espelhada da N4.
  - Na Night 4, a 1ª ocorrência da ANM-004 usa Mr. Pickett como original.

---

## Veículos e resgate (rodadas 9–12)

### NPC-022 — Carro de trânsito

- Papel: ambiente que atropela jogador · Turno: dia (denso) e noite (≤ 1 até 9 PM; 0 depois) · Custo: teto de veículos (dia ≤ 4, noite ≤ 1), fora do teto de 12 · Origem: **[DEC-087, DEC-095, DEC-103, DEC-130, DEC-133]** (DEC-120 revogada); sistema em FEAT-033; travessia = DEC-133; rotas com o level-designer (Q-102)

| Estado | Regra | Números (tabelas `Traffic`, `Traffic.Crossing`) |
|---|---|---|
| Nascer | ponta de entrada da rota, fora da área jogável e fora de vista do Pad e do Mart; ≥ 55 studs antes da 1ª faixa | dia: 1 a cada 6–10 s por rota, Juniper Sul 12–20 s por sentido; intervalo ≥ 3 s na mesma faixa de rolagem; noite 8–9 PM: ~1 a cada 30 s (só Ninth); depois das 9 PM: nenhum |
| Andar | segue a rota fixa (Ninth Avenue, Juniper Street); nunca muda de faixa | 22 studs/s na reta; 12 no cruzamento |
| PARE | só nos braços da Juniper: para na linha SL-N/SL-S e entra com a caixa do cruzamento livre; Ninth é preferencial | 1 s parado; desacelera em 1 s |
| Frear para NPC | para na linha da faixa enquanto um NPC tem a reserva dela | espera ≤ 4 s; reserva só dada com o carro a ≥ 15 studs da linha |
| Frear para jogador | **nunca** **[DEC-095, DEC-130]** | — |
| Faixa | nunca para dentro da faixa (só passa de SL-1S se há espaço até SL-S) | — |
| Encostar no jogador | arremessa em ragdoll (FEAT-033); não freia, não desvia | limiar ≥ 6 studs/s |
| Sair | some na outra ponta da rota | — |

Invariantes (base para a ANM-008): **nunca para no meio-fio**; nunca estaciona; 3 modelos × 4 cores, **nenhum preto e comprido**; à noite só farol **baixo**; sempre com motor audível e sem buzina.

- Critérios de aceite:
  - Em 1 h simulada, nenhum carro de trânsito para fora do PARE e das faixas com reserva de NPC; nenhum para no meio-fio nem dentro de faixa.
  - Nenhum NPC é atropelado (NPC só entra na pista com reserva); jogador na pista, inclusive na faixa, é atropelado se o carro chega a ≥ 6 studs/s.
  - Nenhum carro nasce a menos de 55 studs de uma faixa.
  - Depois das 9 PM, nenhum carro de trânsito nasce.
  - Com ANM-008 ou ANM-010 ativa, 0 carros novos.

### NPC-023 — Ambulância

- Papel: veículo roteirizado de resgate · Turno: noite (só quando alguém cai) · Custo: 1 no teto de veículos; no máximo 1 por servidor · Origem: **[DEC-091, DEC-023, DEC-114]**; sequência e tabela `Ambulance` em FEAT-034 (fonte única dos números); assets com o art-director (Q-104)

| Estado | Regra | Números (tabela `Ambulance`, FEAT-034) |
|---|---|---|
| Despachar | jogador cai (sanidade 0); espera se ANM-008 ou ANM-010 ativa | — |
| Chegar | entra por AMB-IN e para na parada do corpo: **AMB-M** (Mart, quedas a oeste de X −24) ou **AMB-P** (em frente ao trailer, o resto) — IDs do `MAP-01.md`. Ninth é preferencial: não para no cruzamento | chega em 8 s após a queda; 24 studs/s, 12 nos últimos 20 studs; entra em t = 0 (AMB-P, ~8,3 s de viagem) ou t ≈ 3,6 s (AMB-M, ~4,4 s); freia para jogador a ≤ 15 studs na frente |
| Coleta | os 2 médicos (NPC-024) **descem**, andam até o corpo e o levam na maca **[DEC-114]** | `CollectTime` ≤ 10,5 s (t = 8 → 18,5); alcance 80 studs; médicos a 20 studs/s |
| Partir | sai por AMB-OUT em t = 20 s | ~4,5 s (AMB-P) / ~8 s (AMB-M) até sumir |
| Reviver | volta só com o motorista; para em **AMB-P**; o jogador aparece de pé em REV-1..4; parte 2 s depois; **ninguém desce** **[DEC-091, DEC-114]** | entra 2 s após a confirmação; ~8,3 s até AMB-P |

Invariantes: sempre o mesmo modelo, cor e sirene; sirene suave (nunca susto, DEC-005); nunca atropela; nunca é anomalia nem imitada por anomalia no MVP; marcas e textos originais (sem marca real de serviço de saúde).

- Critérios de aceite: os de FEAT-034; nunca há 2 ambulâncias no mapa; nenhuma colisão dela derruba jogador.

### NPC-024 — Médicos da ambulância (2)

- Papel: atores visuais da coleta · Turno: noite · Custo: 0 (dirigidos pela linha do tempo do servidor, renderizados no client, como os atores de cutscene; fora do teto de 12) · Origem: **[DEC-091, DEC-089, DEC-114]**; personagem CHR-008 (`story/characters.md`); ficha de asset com o art-director (ainda não existe, AD-2 do relatório de consistência)

| Regra | Valor |
|---|---|
| Aparência | R6, uniforme de resgate genérico, cores calmas, rosto gentil; sem sangue, sem equipamento médico assustador (DEC-023) |
| Movimento | **descem** pelas portas traseiras na ida **[DEC-114]**, andam pela calçada até o corpo (caminhos do `MAP-01.md` §9.6, ≤ 80 studs) a **20 studs/s** (era 16), põem na maca (2 s), voltam carregando a maca à mão e sobem |
| Alcance | `MedicReach` **80 studs** (era 60; `MAP-01.md` rev.3 P35: AMB-P → porta dos fundos ~52, corpo dentro do trailer até ~75); 0,5 s para descer + ida + 2 s de maca + volta = **≤ 10,5 s** (`CollectTime`, FEAT-034). É tempo de coleta, não a janela de reviver de 10 s (DEC-094/DEC-118), que corre em paralelo |
| Travessia | se o caminho cruza a pista, usam a faixa com reserva, como os outros NPCs (FEAT-033, **DEC-133**); depois das 9 PM não há trânsito |
| Corpo inacessível (exceção, Rascunho) | > 80 studs de caminho ou sem caminho de calçada: não andam; a maca aparece na parada e o corpo some em fade 0,5 s |
| Interação | nenhuma; sem prompt; não são alvo de anomalia nem de "ver" |
| Na volta do reviver | **não aparecem** **[DEC-091, DEC-114]** |

- Critérios de aceite: na ida, os 2 médicos sempre descem e andam até o corpo (salvo corpo inacessível); corpo no fundo oeste do trailer (~75 studs) é coletado a pé, sem fade, e os médicos estão de volta na ambulância em ≤ 10,5 s desde a parada; todos os clients os veem no mesmo ponto da linha do tempo (tolerância ≤ 0,5 s); o servidor esconde o corpo no instante em que a maca o pega; na volta do reviver nenhum médico aparece.

---

## Propostas pendentes (NPCs)

| Q | Recomendação | Precisa do usuário? |
|---|---|---|
| **Q-083** Passantes e NPCs da noite | (a) até 2 pedestres de dia; (b) à noite todo humanoide de servidor é cliente ou anomalia; médicos da ambulância são visuais | não |
| **Q-089** Ladrão até a gaveta | 4 s fixos; a velocidade de Quick Quentin varia por ponto de espreita | não |
| **Q-091** Opal | (a) fora do teto de 12; (b) âncora AN-08 sai da Opal | não |
| **Q-092** Ponto seguro | nenhuma `ANM-###` usa a área sob o letreiro nem o interior do Mart como palco (regra de design) | não |
| **Q-094** Esconder por jogador | sim; 4 pontos atrás do balcão do trailer | não |
| **Q-069** Sinal visto por um só | sinal visível a todos; penalidade por jogador quando o escopo é "por jogador" (ANM-006, ANM-008, ANM-009, ANM-010) | não |
| **Q-103** ANM-008 com trânsito | ≤ 1 carro de trânsito até 9 PM, 0 depois (a ANM-008 é o único carro em movimento); nunca para no meio-fio; nenhum carro de trânsito preto e comprido (co-dono: narrative-writer). FEAT-033 | não |
| **Q-122 b, c** NPCs e ambulância no atropelamento | NPCs nunca atropelados (só atravessam na faixa com reserva; carros param para eles); ambulância nunca atropela | não |
| **Q-129** Travessia sem semáforo (DEC-130) | (B): carros param só para NPC com reserva de faixa, nunca para jogador; PARE nos braços da Juniper; faixas pintadas; spawn ≥ 55 studs da faixa. Opções e prós/contras em `features.md` | **respondida: DEC-133 (B)** |
| **Q-065** Sabor das anomalias | tudo entra como visual/áudio; ANM-003 congela o relógio só no client | não |
