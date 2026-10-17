Status: Em revisão (DEC-278). Reescrita 2 (game-designer, 2026-10-17); todo o conteúdo é Rascunho, números Provisórios.
Base: DEC-269..280 (restaurante; **DEC-280**: 1 tablet na ponta direita, sem porta de saída, retirada no lado esquerdo do balcão, o jogador nunca sai, a loja é o único ponto seguro, drive-thru atendido de dentro), **DEC-277** (erro = −35 de sanidade; cai só ao zerar), **DEC-278** (vetado: anomalia que se confunde com o fluxo rápido), **DEC-279** (revisar ANM-001..020), `Q-308`, `Q-351`, e as 13 recomendações de `research/anomaly-design-techniques.md`.
A V2 Aprovada (DEC-254..257) continua valendo na estrutura; o que muda regra Aprovada está em §9.

# Anomalias V3 — restaurante (versão enxuta)

**Resumo:** **11 anomalias** no catálogo, **9 regras** no quadro e **3 respostas**, feitas em **3 controles na mesma coluna**, ao lado do tablet.
A ameaça mora **lá fora** e é vista pela vitrine e pela janela do drive-thru. A única exceção é o cliente estranho no tablet, porque o atendimento um a um é um momento calmo.
Nada acontece em prato, grelha, condimento, caixa, nota ou tablet "sozinho".

## 1. As 13 regras aplicadas (checklist de toda ficha)

| # | Regra (pesquisa) | Como fica aqui |
|---|---|---|
| 1 | Canal separado do trabalho | Só **lá fora** (mesas, rua, pista do drive-thru) ou **o cliente no tablet / o motorista na janela**. Proibido: prato, grelha, condimento, caixa, nota, tablet sem cliente |
| 2 | Prenúncio único reservado | **"O Frio"**: sting grave de 1,5 s + os postes e luminárias de fora esfriam (âmbar → azul-acinzentado). Toca **só** antes de anomalia de fora e nunca em outra situação. Família A no tablet não tem prenúncio: o cliente é o sinal |
| 3 | Baseline fixo | 5 âncoras de fora (§2). Cada anomalia muda **uma** âncora de forma **grande** (silhueta, cor ou movimento). Nunca duas mudanças ao mesmo tempo |
| 4 | Regras ditas antes | **Quadro de regras** físico (§3). Ligação do chefe = no máximo **1 regra nova por noite**. Anomalia sem linha no quadro não pune (vira susto D) |
| 5 | ≤ 3 respostas, controles físicos perto do balcão | **FECHAR** (alavanca FRENTE / alavanca DRIVE), **LUZ** (painel: apagar e religar), **NÃO OLHAR**. Esconder sai (`Q-331`) |
| 6 | Calma durante a anomalia | Do prenúncio até resolver: **chegada de clientes pausa** e a **paciência congela** (fila do tablet, retirada e carro). Na noite que estreia uma regra, **−20 % de clientes** |
| 7 | Dosagem | §7: 2–3 eventos na N1, 3–5 na N2–N5, 5–7 da N6 em diante; 1 simultânea até a N5, depois no máximo 2 (canais diferentes); intervalo de 60–90 s + 30 s de respiro |
| 8 | Janela justa | Prenúncio 1,5 s → sinal → resposta em **6–15 s**, e o prazo **aparece no mundo** (vulto anda, luminária apaga). Se ela sumir antes do prazo, não pune |
| 9 | Feedback explícito | §4.2: selo OK no acerto; no erro, jumpscare + barra tremendo + cartão com **a regra quebrada** |
| 10 | Falso positivo custa dinheiro | §4.3: fechar sem anomalia manda clientes embora (venda perdida), **sem sanidade** |
| 11 | Sanidade legível | §5: 100 → 65 → 30 → 0 (3 erros = cai), faixas com efeito leve e recuperação |
| 12 | Perceber é papel | Monitor de câmera de fora em cima das grelhas, prenúncio global e **ping "OUTSIDE!"** de 1 tecla (§6) |
| 13 | Teste de legibilidade | Critério de aceite de toda ficha: num pico de 4 pedidos, um testador que **não sabe** que ela vem nota em **≤ 3 s**, de **2 postos** |

## 2. Âncoras do "normal" lá fora (baseline)

Fixas em toda noite normal, posicionadas pelo level-designer no campo da vitrine (e no monitor das grelhas).

| ID | Âncora | Normal | Quem mexe nela |
|---|---|---|---|
| AN-A | **4 mesas de piquenique** com guarda-sol creme e luminária âmbar | acesas, clientes sentados comendo | 010 (apagam mesa por mesa), 017 (algo passa por baixo) |
| AN-B | **Ponto de ônibus** do outro lado da rua (banco + placa) | vazio | 006 (figura alta em pé) |
| AN-C | **Poste da esquina** | âmbar, firme | prenúncio "O Frio"; 020 (apaga) |
| AN-D | **Pista do drive-thru** + janela | um carro comum por vez, motorista visível | 031, 033, 008 |
| AN-E | **Letreiro OPEN** do restaurante (visto refletido na vitrine) | aceso fixo | 020 (apaga com tudo) |

## 3. Controles e quadro (a "coluna de controle")

Tudo numa **coluna** entre a ponta direita do balcão (tablet) e a janela do drive-thru: quem atende alcança tudo em 1–2 passos. Posição exata com o level-designer em `levels/MAP-01-r4-restaurant.md`.

| Controle | Ação | O que faz | Custo se usado sem anomalia (§4.3) |
|---|---|---|---|
| **Alavanca FRONT** | puxar (instantâneo); reabrir = puxar de novo | persiana desce sobre o balcão **e** a vitrine. A **fila do tablet vai embora** (DEC-261); quem está na retirada fica | clientes da fila perdidos (~$8 cada) |
| **Alavanca DRIVE** | puxar | persiana da janela do drive-thru. O carro da janela vai embora | 1 venda perdida (~$8) |
| **Painel LIGHT** | interruptor (toque) + disjuntor (segurar E 3 s) | apaga ou acende a loja; o disjuntor religa no apagão | luz apagada: estações sem prompt enquanto estiver apagada (tempo perdido) |
| **Quadro de regras** (acima da coluna) | — | 1 linha por regra já apresentada, com o ícone do controle. A linha nova da noite brilha na primeira hora | — |

Texto do quadro (inglês na UI; o narrative-writer ajusta):

| Linha | Regra | Estreia |
|---|---|---|
| 1 | Wrong face or head at the tablet? **Pull FRONT.** | N1 |
| 2 | No driver at the window? **Pull DRIVE.** | N2 |
| 3 | Power out? **Hold the breaker.** | N3 |
| 4 | Something crawling to the glass? **Pull FRONT before it gets here.** | N4 |
| 5 | Yellow raincoat? **Serve her. Fast. Never close on her.** | N5 |
| 6 | Tall one at the bus stop? **Don't look at it.** | N6 |
| 7 | A pet that's wrong in the car? **Pull DRIVE. Don't pet it.** | N7 |
| 8 | Long car with lights on you? **Pull DRIVE. Keep it shut.** | N8 |
| 9 | Table lights going out? **Lights OFF until they're back.** | N10 |

## 4. Regras comuns

### 4.1 Erro, omissão e quem paga (DEC-277, DEC-204)

- **Erro de ação** (fez a coisa errada): jumpscare cartoon 0,6 s (DEC-256) e **−35 de sanidade em quem agiu**.
- **Omissão** (o prazo acabou sem resposta): o mesmo efeito em **todos os ativos dentro da loja**. Provisório até `Q-330`.
- Ninguém cai na hora: só cai quando a sanidade **zera** (DEC-091, Revive Kit DEC-258).
- Uma ocorrência tira no máximo uma vez de cada jogador.

### 4.2 Feedback

| Resultado | O que o jogador vê e ouve |
|---|---|
| Acerto | som de alívio + as luzes de fora voltam ao âmbar + selo **"OK"** pequeno 1 s perto da coluna (sem moeda, para não confundir com venda); **+5 de sanidade** para todos na loja |
| Erro | jumpscare 0,6 s → barra de sanidade treme e cai 35 → **cartão de 2 s** com a linha do quadro quebrada e o ícone do controle certo ("No driver? Pull DRIVE.") |
| Sumiu sem resposta (sem prazo) | nada; o prenúncio se desfaz |

### 4.3 Falso positivo (custa dinheiro, não sanidade)

- FRONT sem anomalia: a fila do tablet vai embora sem pagar (venda perdida; não conta como "insatisfeito" no ranking).
- DRIVE sem anomalia: o carro vai embora.
- LIGHT apagada sem motivo: as estações ficam sem prompt.
- Recusar um cliente normal no tablet: mesma coisa que FRONT.
- Valores de referência: hot dog médio ~$8 (número final em `design/restaurant-flow.md`).

## 5. Sanidade (DEC-277 + regra 11)

| Faixa | Efeito (Mild) |
|---|---|
| 100–66 | nenhum |
| 65–31 | vinheta suave, som de fora abafado |
| 30–1 | vinheta mais forte + **relances**: um vulto some no canto de uma âncora. **Nunca** usa o prenúncio "O Frio" e não pune |
| 0 | cai (desmaio, reviver) |

- **3 erros = cai** (100 → 65 → 30 → 0).
- Recuperação: **+5 por anomalia acertada** (todos na loja) e **+20 ao amanhecer**, teto 100.
- A perda é **por jogador**; o grupo só perde a noite se **todos** caírem (DEC-255 mantida nesse ponto).

## 6. Co-op: perceber é papel

- **Monitor de fora** em cima das grelhas: mostra a vitrine e as mesas, para quem trabalha de costas ver o mesmo que o atendente. Reusa a câmera de segurança (TASK-285). Vem **de fábrica**; o upgrade "Lookout" é um 2º monitor com o drive-thru (game-designer, UPG-015+).
- **Ping "OUTSIDE!"**: tecla **Q** no PC, **D-pad cima** no controle, botão de olho no HUD do mobile.
  - Marca por 3 s o ponto para onde o jogador olha.
  - Todos veem uma seta na borda da tela e ouvem um "tic" curto (não é o sting).
  - Recarga de 4 s.
  - Não usa E/X (prompts) nem G/Y (ofertas, DEC-262).
- O prenúncio é **global**: todos ouvem e todos veem o poste esfriar.
- **Solo**: tudo funciona igual. Monitor e ping não são obrigatórios.

## 7. Catálogo final (11 anomalias)

Todas usam os Kits de `src/Anomaly` (só leitura): **CustomerActor** (família A, verbo refuse/serve, evento Shutter), **Hide** (aviso → passagem → teste; o teste muda de "dentro da HideZone" para "FRONT fechada"), **ANM-006** (`ctx.Looking`), **ANM-020** (blackout do LightService), **ANM-010** (luzes uma a uma).

| ID | Nome | Canal / âncora | Resposta | Janela | Estreia | Custo |
|---|---|---|---|---|---|---|
| ANM-001 | Sem rosto | tablet | FRONT | sem prazo | N1 | P |
| ANM-013 | Olhos brancos | tablet | FRONT (linha 1) | sem prazo | calada N2 | P |
| ANM-012 | Pescoço invertido | tablet | FRONT (linha 1) | sem prazo | calada N3 | P |
| ANM-031 | Carro sem motorista | AN-D | DRIVE | sem prazo | N2 | P |
| ANM-020 | Apagão | AN-C, AN-E | LIGHT (disjuntor 3 s) | 15 s | N3 | P |
| ANM-017 | O rastejador | AN-A | FRONT | 10 s | N4 | P/M |
| ANM-005 | Raincoat Lady | tablet + retirada | servir (não fechar) | paciência 60 s | N5 | P |
| ANM-006 | O da parada (stalker) | AN-B | NÃO OLHAR | 20 s | N6 | P |
| ANM-033 | Pet errado | AN-D | DRIVE | 12 s | N7 | M |
| ANM-008 | Carro comprido | AN-D | DRIVE (e manter) | 8 s + 15 s | N8 | M |
| ANM-010 | The Hush | AN-A | LIGHT (apagar e manter) | 15 s + 15 s | N10 | M |

### 7.1 Fichas

Campos de todas: **Aceite** inclui sempre o teste da regra 13 (≤ 3 s, 2 postos, pico de 4 pedidos). "Pausa" = §1 regra 6.

**ANM-001 — Sem rosto** (família A)
- Sinal: cabeça lisa, sem olhos nem focinho, no tablet. A nota do HUD abre **vazia**.
- Resposta: **FRONT** (com ele na fila).
- Erro: "Take Order" nele → −35 em quem atendeu.
- Omissão: nenhuma (fica até a paciência de 45 s e vai embora).
- Falso positivo: §4.3.
- Engaja: 1 (atendente). Solo: sim.
- Pausa: chegada de clientes pausa enquanto ele está no tablet.
- Kit: `CustomerActor` (Variant blank), já existe. **P**.
- Aceite: FRONT resolve; Take Order tira 35 de quem atendeu; a nota abre vazia.

**ANM-013 — Olhos brancos** (família A, linha 1)
- Sinal: olhos totalmente brancos, cartoon (textura da DEC-245).
- Resposta, erro e omissão: iguais à 001. Herda o visual da antiga cópia (ANM-004).
- Kit: existente. **P**.

**ANM-012 — Pescoço invertido** (família A, linha 1)
- Sinal: cabeça virada 180°, olhando para a rua.
- Resposta, erro e omissão: iguais à 001. Mantém o estalo ao recusar (TASK-336).
- Kit: existente. **P**.

**ANM-031 — Carro sem motorista** (drive-thru)
- Prenúncio: O Frio.
- Sinal: o carro para na janela com o **banco vazio**, a janela aberta e o volante girando sozinho. O alto-falante pede mesmo assim.
- Resposta: **DRIVE**. O carro sai de ré.
- Erro: confirmar o pedido no computador → −35 em quem confirmou.
- Omissão: nenhuma (vai embora em 40 s).
- Engaja: 1. Solo: sim.
- Kit: `CustomerActor` (Variant "empty" do carro do drive-thru; o carro é feature do fluxo, DEC-274) + evento Shutter com âncora DRIVE. **P**.
- Aceite: DRIVE resolve; confirmar tira 35; o banco vazio é legível a partir do tablet e do monitor.

**ANM-020 — Apagão** (família C)
- Prenúncio: O Frio. Depois, um estalo e **tudo apaga** (loja, mesas, poste, letreiro). Lanterna do jogador.
- Prazo visível: um vulto **acende os olhos** na mesa 4 e vem mesa por mesa até a vitrine (4 mesas, uma a cada ~3,5 s).
- Resposta: **segurar o disjuntor 3 s** no painel LIGHT, dentro da loja (`Q-351`), em **15 s**.
- Omissão: 15 s → −35 em todos na loja. A luz volta 3 s depois.
- Engaja: 1–2 (um religa, outro avisa). Solo: sim.
- Kit: ANM-020 existente; só o ponto do disjuntor muda. **P**.
- Aceite: religar em ≤ 15 s resolve; aos 15 s tira 35 de todos na loja; o disjuntor fica a ≤ 2 passos do tablet.

**ANM-017 — O rastejador** (ex-família B, agora FECHAR)
- Prenúncio: O Frio.
- Sinal: algo de quatro sai de baixo da mesa 1 e atravessa as mesas, rápido, em direção à vitrine. Os guarda-sóis balançam por onde passa.
- Prazo: **10 s** até encostar na vitrine.
- Resposta: **FRONT** antes de ele chegar. Com a persiana descida, ele arranha e vai embora. Reabrir só depois do selo OK.
- Omissão: FRONT aberta quando ele chega → −35 em todos na loja.
- Engaja: 1–4 (quem vê pinga). Solo: sim.
- Kit: `Hide` com o teste trocado (persiana FRONT fechada no lugar da HideZone) + caminho novo. **P/M**.
- Aceite: FRONT fechada antes de 10 s resolve; aberta tira 35 de todos; visível pela vitrine e pelo monitor.

**ANM-005 — Raincoat Lady** (família A, exceção)
- Sinal: ovelha de capa amarela pingando numa noite **seca** (DEC-251..253). Só em atmosfera sem chuva.
- Resposta: **atender e entregar na retirada**.
- Prazo visível: a poça aos pés dela **cresce** (paciência de 60 s; as dos outros congelam).
- Erro: FRONT com ela na fila → −35 em quem puxou.
- Omissão: paciência acabou → −35 em todos na loja.
- Engaja: 2–4 (a cozinha inteira prioriza o pedido). Solo: sim (60 s bastam para 1 pedido).
- Kit: existente (verbo serve). **P**.
- Aceite: entregue em ≤ 60 s resolve; FRONT tira 35 de quem puxou; não aparece em ATM-4/5.

**ANM-006 — O da parada** (stalker, DEC-260)
- Prenúncio: O Frio.
- Sinal: figura alta em pé no **ponto de ônibus** (AN-B), que estava vazio.
- Resposta: **não olhar**. Ela avança **1 passo a cada 1,2 s de olhar** de qualquer jogador (vitrine ou monitor); são 6 passos até a vitrine. Sem olhar, ela some em **20 s**.
- Erro: chegou à vitrine → bate no vidro, jumpscare em quem olhava por último, −35 nele.
- FRONT também a manda embora (DEC-260), mas custa a fila (§4.3): resposta de emergência, não a regra.
- Engaja: 1–4 (é o "não olha pra rua!" do co-op). Solo: sim.
- Kit: ANM-006 existente, com o caminho trocado para AN-B → vitrine. **P**.
- Aceite: 20 s sem olhar resolve; 6 passos de olhar tiram 35 de quem olhou por último; olhar pelo monitor conta.

**ANM-033 — Pet errado** (drive-thru)
- Prenúncio: O Frio.
- Sinal: um bichinho de estimação sobe no parapeito da janela do drive-thru. É fofo, mas **grande e errado**: olhos demais, anda de costas, sombra de outro bicho.
- Prazo: **12 s**, e ele vai se espremendo para dentro.
- Resposta: **DRIVE**.
- Erro: usar o prompt "Pet" nele → −35 em quem tocou.
- Omissão: entra aos 12 s → −35 em todos na loja.
- Os **pets normais** do drive-thru (DEC-274) existem e aceitam carinho (+$2, uma vez por carro). O sinal do errado tem que ser **grande** (regra 3); se no teste da regra 13 for confundido com um pet normal, a ficha volta.
- Engaja: 1–2. Solo: sim.
- Kit: rig pequeno novo + caminho de 3 pontos + prompt "Pet". **M**.
- Aceite: DRIVE em ≤ 12 s resolve; Pet tira 35 de quem tocou; o pet normal nunca tem os sinais do errado.

**ANM-008 — Carro comprido** (drive-thru)
- Prenúncio: O Frio.
- Sinal: carro preto comprido demais entra na pista, para na janela e o motor faz um zumbido grave.
- Prazo: **8 s** até o farol alto.
- Resposta: **DRIVE** antes do farol, e manter fechada até ele sair (15 s, ele vai embora devagar).
- Erro: reabrir antes → −35 em quem reabriu.
- Omissão: farol com DRIVE aberta → −35 em todos na loja.
- Engaja: 1–2. Solo: sim.
- Kit: ANM-008 existente (caminho até a janela do drive-thru, teste da persiana DRIVE). **M**.
- Aceite: DRIVE em ≤ 8 s e mantida resolve; reabrir tira 35 de quem reabriu.

**ANM-010 — The Hush** (família C)
- Prenúncio: O Frio. Depois, a rua emudece.
- Sinal e prazo: as luminárias das mesas **apagam uma a uma**, da mesa 4 até a 1, uma a cada ~3,5 s (15 s no total).
- Resposta: **LIGHT apagada** antes da última e mantida até as luminárias voltarem (15 s).
- Erro: reacender antes → −35 em quem reacendeu.
- Omissão: loja acesa quando a mesa 1 apaga → −35 em todos na loja.
- Na N10, uma ocorrência é roteirizada às ~5:45 e leva ao final.
- O dreno do escuro (DEC-056) **não corre** durante a anomalia (Provisório).
- Engaja: 1–4. Solo: sim.
- Kit: ANM-010 existente (luminárias como grupos `HushOff`; o teste troca o ponto seguro pela luz da loja apagada). **M**.
- Aceite: apagada antes da última e mantida resolve; acesa tira 35 de todos; a contagem das mesas é visível de dentro.

## 8. Revisão de ANM-001..040

### 8.1 ANM-001..020 (DEC-279)

| ID | Veredito | Motivo (regra) |
|---|---|---|
| ANM-001 | **Fica** | família A no tablet (momento calmo); sinal grande |
| ANM-002 Comida errada | **Sai** | mora em salsicha/pão/prato, o canal do trabalho (regra 1); o tipo é vetado pela DEC-278 |
| ANM-003 Relógio + sino | **Sai** | o relógio do banco é âncora pequena e distante (regra 3); LIGHT já tem a 010. O sino pode voltar como susto D sem verbo |
| ANM-004 A cópia | **Sai** | sinal comparativo (dois clientes, regra 3); a tranca dependia da porta, que não existe (DEC-280); o visual vive na 013 |
| ANM-005 | **Fica** (adapta: espera na retirada) | exceção "servir" já aprovada; poça como prazo visível |
| ANM-006 | **Adapta** | ponto de ônibus → vitrine; resposta NÃO OLHAR |
| ANM-007 Walker | **Sai** | "esconder" sai (loja = ponto seguro, `Q-331`); figura alta já é a 006 |
| ANM-008 | **Adapta** | vai para o drive-thru; DRIVE |
| ANM-009 A batida | **Sai** | sem porta (DEC-280); vira susto D sem verbo (batida no vidro) |
| ANM-010 | **Adapta** | luminárias das mesas; resposta = apagar a loja (era ir ao Mart) |
| ANM-011 Tremendo | **Sai** | tremor pequeno, ilegível no celular a 15 studs (regra 3) |
| ANM-012 | **Fica** | família A, grande; dentro da linha 1 |
| ANM-013 | **Fica** | família A, grande; dentro da linha 1 |
| ANM-014 Cabeça errada | **Sai do lançamento** | catálogo enxuto; vira variante reserva da linha 1 sem regra nova |
| ANM-015 Flutuando | **Sai** | 20 cm é sutil e o balcão esconde os pés (regra 3) |
| ANM-016 Não pisca | **Sai** | sutil ("olhar fixo" se confunde com o cliente normal olhando o jogador) |
| ANM-017 | **Adapta** | ex-família B: em vez de esconder, FRONT antes de ele chegar |
| ANM-018 O Sorriso | **Sai** | o rosto na vitrine já é susto D (`window_face`); sem verbo próprio |
| ANM-019 Sombra no teto | **Sai** | o teto não é visível de dentro (regra 3) |
| ANM-020 | **Adapta** | disjuntor dentro da loja, na coluna de controle |

### 8.2 ANM-021..040 (da versão 1)

| ID | Veredito |
|---|---|
| ANM-021, 023, 024, 025, 026, 027, 034 | **Retirada (DEC-278)**: canal do trabalho (nota, tablet sem cliente, prato, grelha, caixa, condimento, estação) |
| ANM-022, 028, 029, 032, 035 | **Retirada (DEC-278)**: catálogo enxuto / dependiam de sair da loja ou de resposta composta |
| ANM-030 Mesas olham | **Retirada (DEC-278)** como anomalia; a ideia vira **susto D** sem verbo e sem punição (`Content.Hallucinations`) |
| ANM-031, ANM-033 | **Ficam** (§7) |
| ANM-036..040 | reservadas, sem uso. IDs retirados nunca são reaproveitados |

Sustos D (sem verbo, sem punição, sem prenúncio "O Frio") reapontados para as âncoras de fora: `window_face`, `street_watcher`, `post_flicker` (só flicker; o esfriar é do prenúncio), batida no vidro (ex-009), sino distante (ex-003), mesas olham (ex-030). Os sustos de dentro da loja que mexem em objeto de trabalho (`grill_hiss`, `bottle_fall`) **saem** (regra 1).

## 9. Ritmo das noites (dado, `Content/Nights.luau`)

Mesma ideia da V2 §8: duas famílias desde a N1 (A + sustos D), **1 regra nova por noite no máximo**, curva calmo → pico → respiro.
A atmosfera **nunca cobre a âncora da novidade da noite**: neblina e névoa com alcance ≥ 30 studs (as mesas ficam a 10–25 studs).

| Noite | Regra nova (ligação) | Entra calada | ATM | Eventos | Sustos D | MaxSim | Intervalo mín. | Clientes |
|---|---|---|---|---|---|---|---|---|
| 1 | linha 1 (001) | — | ATM-1 | 3 | 3 | 1 | 90 s | −20 % |
| 2 | linha 2 (031) | 013 | ATM-1 | 3 | 3 | 1 | 90 s | −20 % |
| 3 | linha 3 (020) | 012 | ATM-2 | 4 | 4 | 1 | 80 s | −20 % |
| 4 | linha 4 (017) | — | ATM-3 | 4 | 4 | 1 | 80 s | −20 % |
| 5 | linha 5 (005) | — | ATM-6 | 5 | 4 | 1 | 70 s | −20 % |
| 6 | linha 6 (006) | — | ATM-4 | 5 | 5 | 2 | 70 s | −20 % |
| 7 | linha 7 (033) | — | ATM-5 | 6 | 5 | 2 | 60 s | −20 % |
| 8 | linha 8 (008) | — | ATM-2 | 6 | 5 | 2 | 60 s | −20 % |
| 9 | — (frequência sobe) | — | ATM-3 | 7 | 6 | 2 | 60 s | normal |
| 10 | linha 9 (010, roteirizada ~5:45) | todas | ATM-7 | 7 + Hush | 6 | 2 | 60 s | normal |

- Depois de cada evento: **30 s sem nada**.
- Com MaxSim 2, as duas nunca no mesmo canal (vitrine × drive-thru × tablet).
- A família A não conta no MaxSim de fora, mas nunca estreia junto com um prenúncio.
- `Validate`: eventos × intervalo ≤ janela do turno (N10: 7 × 60 = 420 s).

## 10. Pacote MVP do restaurante (6)

Cobre as estreias da N1 à N6, só com Kits existentes (5 P + 1 P/M):

| # | Anomalia | Por quê |
|---|---|---|
| 1 | **ANM-001** (+013 e 012 como variantes da linha 1) | ensina o tablet e a alavanca FRONT; já implementada |
| 2 | **ANM-031** Carro sem motorista | estreia o drive-thru e a alavanca DRIVE com um sinal inconfundível |
| 3 | **ANM-020** Apagão | estreia o painel LIGHT e o prenúncio; só muda o ponto do disjuntor |
| 4 | **ANM-017** O rastejador | primeira ameaça vista pela vitrine, com prazo visível |
| 5 | **ANM-005** Raincoat Lady | quebra o vício de fechar tudo; já implementada |
| 6 | **ANM-006** O da parada | "não olhar" no co-op; já implementada, só troca o caminho |

Segunda onda: 033, 008, 010 (as noites 7–10 rodam com frequência maior até elas chegarem).
Pré-requisitos (fora deste doc): coluna de controle (2 alavancas + painel + quadro), prenúncio "O Frio", pausa de clientes durante anomalia, cartão de erro, ping, monitor das grelhas.

## 11. Critérios de aceite do conjunto

1. Nenhuma anomalia do catálogo usa prato, grelha, condimento, caixa, nota ou tablet sem cliente (regra 1, DEC-278).
2. O prenúncio "O Frio" só toca antes das anomalias de fora: um log de uma noite inteira sem anomalia tem **0** prenúncios.
3. Toda resposta usa um dos 3 controles da coluna ou "não olhar"; nenhuma pede sair da loja (DEC-280).
4. Durante uma anomalia de fora, o spawn de clientes fica em 0 e a paciência congelada (medido no servidor).
5. Erro tira 35, mostra o cartão com a linha do quadro e só derruba com a sanidade em 0 (DEC-277).
6. Falso positivo não mexe na sanidade.
7. Toda ficha passa no teste da regra 13 antes de sair do Rascunho.
8. Teto de NPCs à noite: fila do tablet 3 + retirada 3 + mesas 4 + 1 carro + 1 ator de anomalia lá fora = **≤ 12 rigs animados**.

## 12. Perguntas ao dono (só as essenciais)

| ID | Pergunta | Recomendação (Provisória) |
|---|---|---|
| Q-330 | A sanidade perdida por erro é **por jogador** ou **do grupo**? | **Por jogador**: ação errada tira de quem agiu; omissão (ninguém respondeu no prazo) tira de todos na loja. A noite só se perde se todos caírem |
| Q-331 | **Respondida pelo dono (DEC-283, 2026-10-17): esconder VOLTA no apagão — todos se escondem na despensa, luzes apagam, aviso na tela, música em passos. A recomendação abaixo está superada.** **"Esconder" sai?** (família B, DEC-254: sair e esconder nos fundos) | **Sai**: a loja é o único ponto seguro (DEC-280). Os monstros que vêm até a vitrine passam a ser resolvidos **puxando FRONT antes de chegarem** (ANM-017) |
| Q-332 | Duas alavancas (FRONT e DRIVE) lado a lado, ou uma só que fecha tudo? (fecha a parte de anomalias da `Q-308`) | **Duas**: o falso positivo custa menos, e o atendente aprende "frente × drive-thru" pelo lugar onde a coisa está |
| Q-333 | O catálogo de lançamento fica em **11 anomalias / 9 regras**, com o MVP de 6 (§10)? | **Sim** |

`Q-334..Q-339`: sem uso nesta versão (nunca registradas; ficam reservadas, não reaproveitar).
