Status: Aprovado (DEC-073 — lista N1–N10; DEC-074 — regra crítica fixa só na N7; rodada 7, 2026-10-08). Anotações posteriores: DEC-096 (IDs `ANM-###` na visão geral), DEC-087 (nota N8 × trânsito em "Interações"), DEC-123 (sinal sonoro de início da N7, nota na ficha), DEC-122 (onde se acorda na noite perdida, nota na ficha N7), DEC-054 (interruptor da N3, nota na ficha). **2026-10-10, DEC-149:** clientes e pedestres passam a ser **animais** (emenda DEC-146); ANM-001, ANM-004, ANM-005 e ANM-007 descrevem humanos. **Regras, verbos e sinais aprovados não mudam** sem DEC; adaptação para clientes animais → `Q-147` (narrative-writer + game-designer propõem; usuário decide). **DEC-150:** clientes com variante noturna "um pouco assustadora" por textura; o normal da noite não pode parecer anomalia → `Q-147` (c). **DEC-177 (2026-10-10):** o **ponto seguro pode receber anomalia** (não existe a regra "nunca"; este documento não a continha). A N10 não muda: o verbo segue "estar no ponto seguro". O que pode acontecer lá → `Q-161`. **DEC-178:** personagens com nome são animais, incluindo Pickett (ANM-004), Raincoat Lady (ANM-005) e o Walker (ANM-007); espécies `Q-160`, leitura `Q-147`. **DEC-181:** NPC à noite usa o pack **Mid**; pack **Night** reservado à tensão, inclusive "clima de terror de anomalia" (gatilhos `Q-159`). **DEC-172/173:** classificação Mild; jumpscare só raro e leve. Regras, verbos e sinais aprovados **não mudam**. **DEC-221 (2026-10-10, usuário):** o verbo **"esconder"** da N8 e da N9 vira **"fechar a janela"** (botão ao lado do interruptor do trailer fecha a aba sobre a janela de serviço); sinal, conceito, tempos e consequência não mudam. Falas do chefe e formas curtas que diziam "Hide"/"get down" foram trocadas pelo narrative-writer em 2026-10-10 (Provisório, `Q-173` d; ver N8 e N9).

# As 10 anomalias (uma nova por noite)

Autor: narrative-writer, 2026-10-08. Aprovado pelo usuário: conceito, sinal, regra do chefe, forma curta, verbo correto, erro, tipo e escopo de cada anomalia.
Tempos citados = valores iniciais (game-designer ajusta). "Consequências de sabor" = sugestões cortáveis (`Q-065`). Prefixo de ID: `ANM-###` (DEC-096). Interruptor antes do Trailer Lights: `Q-064`.
Base: DEC-010, DEC-023, DEC-025, DEC-026, DEC-041, DEC-053, DEC-054, DEC-056, DEC-060; GDD V1 §7.1, §7.2, §17, §19.
Este documento é o **lado narrativo** das anomalias. Frequência, tempos exatos, detecção e números finais são do game-designer
(`design/npcs.md` / `design/features.md`); os tempos citados aqui são **sugestões** para o texto fazer sentido.

IDs: **DEC-096** (rodada 10) aprovou o prefixo **`ANM-###`** (tabela de IDs do `CLAUDE.md`). Mapeamento fixo, mesma ordem:
N1 = ANM-001, N2 = ANM-002 … N10 = ANM-010. Os rótulos N1–N10 no corpo deste documento seguem válidos como apelido.

## 0. Regras comuns

- Noite N = anomalias N1..N(N-1) + a nova (DEC-025). Na noite 10 as 10 estão ativas (respeitando o teto de 3 atores de anomalia simultâneos, DEC-045).
- Ver qualquer anomalia: −5 de sanidade, uma vez por anomalia por jogador (DEC-056). Isso vale também para as de "não olhar": **olhar de relance não é erro**; o erro é continuar olhando.
- Erro em regra **comum**: −35 de sanidade para quem errou (DEC-053). Erro na regra **crítica**: noite perdida.
- "Consequência de sabor" = efeito visual/sonoro extra, sem violência, **sugerido** para reforçar o erro. Se custar sistema novo, o game-designer pode cortar.
- **Regra crítica**: DEC-053 permite no máximo 1 por noite. Como as anomalias são cumulativas, se a regra crítica for fixa, **só uma anomalia do conjunto pode ser crítica**. **Decidido (DEC-074): N7 (The Walker)**, fixa, que estreia junto com o 5º estágio do chefe ("Whatever you do, never..."). Noites 1–6 não têm regra crítica. Alternativa (crítica rotativa) descartada.

### Distribuição de verbos (DEC-054)

| Verbo | Exemplo de DEC-054 | Proposta | Anomalias |
|---|---|---|---|
| Recusar | 3 | **2** | N1, N4 |
| Atender | 0 | **1** | N5 |
| Não olhar | 2 | 2 | N6, N7 |
| Luz | 1 | 1 | N3 |
| Fechar a janela (era "Esconder", DEC-221) | 2 | 2 | N8, N9 |
| Descartar | 1 | 1 | N2 |
| Ponto seguro | 1 | 1 | N10 |

Desvio do exemplo (que DEC-054 diz "não fechada"): troquei um "recusar" por **"atender"** (N5). Motivo: depois de 4 noites aprendendo a desconfiar,
o jogador tende a recusar tudo que é estranho; uma anomalia que **exige** atender quebra esse vício e obriga a lembrar a regra, não só reagir (GDD §7.2: observar → lembrar → decidir → agir).

### Visão geral

Coluna ID: rótulo N# + ID estável `ANM-###` (anotado por DEC-096; conteúdo aprovado não muda).

| Noite | ID | Nome (no jogo) | Sinal principal | Verbo correto | Errado provável | Tipo | Escopo |
|---|---|---|---|---|---|---|---|
| 1 | N1 · ANM-001 | The blank folks | cliente sem rosto | Recusar | Atender | comum | party (alvo compartilhado) |
| 2 | N2 · ANM-002 | The wrong food | salsicha cinza / pão mordido | Descartar | Atender (servir com o item) | comum | party |
| 3 | N3 · ANM-003 | The stopped clock | relógio do banco para, tique-taque some | Luz | ignorar | comum | party |
| 4 | N4 · ANM-004 | The copies | dois clientes iguais; um espelhado | Recusar (a cópia) | Atender a cópia | comum | party |
| 5 | N5 · ANM-005 | The Raincoat Lady | capa amarela pingando em noite seca | **Atender** | Recusar / deixar esperar | comum | party |
| 6 | N6 · ANM-006 | The wavers | alguém acena da janela de cima | Não olhar | olhar / ficar olhando | comum | por jogador |
| 7 | N7 · ANM-007 | The Walker | figura no fim da Juniper que chega mais perto quando é olhada | Não olhar | olhar | **crítica** | party (qualquer olhar conta) |
| 8 | N8 · ANM-008 | The long car | carro comprido estaciona com o farol no trailer | Fechar a janela | continuar trabalhando | comum | por jogador |
| 9 | N9 · ANM-009 | The knock | batidas na porta dos fundos + "it's me" | Fechar a janela | ignorar / ir até a porta | comum | por jogador |
| 10 | N10 · ANM-010 | The Hush | postes da Juniper apagam um por um | Ponto seguro | ficar no trailer | comum | por jogador |

Escalonamento (DEC-010, GDD §7.4): N1–N3 = perceber uma coisa estranha, sinal óbvio; N4–N6 = lembrar regras, sinal sutil ou contraintuitivo;
N7–N10 = pressão, regra crítica, eventos que tiram o jogador do balcão enquanto o resto continua acontecendo.

---

## N1 — The blank folks (noite 1)

| Campo | Conteúdo |
|---|---|
| Conceito | Um cliente comum, mas o rosto é liso, como manequim. Não terminaram o rosto. Origem: GDD §7.1 "cliente sem rosto". |
| Sinal | Na fila, rosto sem olhos, boca ou sobrancelha. O balão de pedido aparece **vazio** (sem ícones). Fica parado, sem animação de respiração. |
| Regra do chefe | "If someone walks up with no face — no eyes, no mouth — don't serve them." / "Just refuse. They'll wander off." |
| Forma curta | **No face? Refuse them.** |
| Verbo correto | Recusar (prompt "Refuse"). Ele vira e vai embora andando devagar. |
| Erro | Usar "Take Order" nele. |
| Omissão | Deixar esperando: não é erro; ocupa uma vaga do balcão até a paciência acabar (custo de fila). |
| Consequência | −35 de sanidade. Sabor: o pedido sai, ele "paga" com uma moeda **sem desenho** que some da gaveta no fim do turno. |
| Notas | Recusar corretamente não conta como insatisfeito (DEC-051). Asset: variante de cliente com rosto liso. |

## N2 — The wrong food (noite 2)

| Campo | Conteúdo |
|---|---|
| Conceito | Alguém "ajudou" na cozinha e copiou a comida errado. GDD §7.1 "ingredientes alterados"; hábito "conferir ingredientes" (§17). |
| Sinal | Na esteira de descanso ou na tábua aparece **um item que o jogador não pôs ali**: salsicha **cinza-azulada**, ou pão **com uma mordida**. Som de "chiado" curto quando surge. |
| Regra do chefe | "Check your food before it goes out." / "A gray sausage, or a bun with a bite in it you didn't take — toss it." |
| Forma curta | **Wrong food? Throw it away.** |
| Verbo correto | Descartar (levar à lixeira, prompt "Throw Away"). |
| Erro | Entregar um hot dog montado com o item alterado. |
| Omissão | Deixar o item na esteira: não é erro, mas ocupa espaço e pode ser montado por engano (por um colega). |
| Consequência | −35 de sanidade para quem entregou. Sabor: o cliente dá uma mordida, o hot dog **vira fumaça** na mão dele, ele franze a testa e vai embora sem pagar. |
| Notas | A mordida é desenho cartunizado (meia-lua), nada nojento. Pede 2 variantes de asset (salsicha, pão). |

## N3 — The stopped clock (noite 3)

| Campo | Conteúdo |
|---|---|
| Conceito | O tempo emperra na esquina. GDD §7.1 "relógio preso no mesmo horário"; hábito "verificar horários" e "ouvir sons" (§17). |
| Sinal | O relógio do Bellmoor Savings **para** (ponteiros congelados) e o **tique-taque some**. O relógio do HUD continua andando — a diferença é o sinal. |
| Regra do chefe | "Keep an eye on the bank clock." / "If it stops, flip the trailer lights off. Count to five. Then back on." |
| Forma curta | **Clock stops? Lights off, count five, lights on.** |
| Verbo correto | Luz: desligar o interruptor, esperar ~5 s no escuro, religar. O tique-taque volta. |
| Erro | Não fazer isso dentro de ~60 s depois que o relógio parou (sugestão). |
| Omissão | É o próprio erro (prazo). |
| Consequência | −35 de sanidade para **todos** da party (alvo compartilhado). Sabor: o relógio do HUD também congela por ~30 s (a noite fica mais longa) e a grelha para de chiar. |
| Notas | 5 s no escuro custam ~2 de sanidade (escuro −1/s depois de 3 s, DEC-056): pequeno preço intencional. Precisa do interruptor (DEC-054) e do Trailer Lights; sem o upgrade, o interruptor controla a lâmpada básica do trailer (pergunta para o game-designer). |

> Anotação **DEC-054** (não muda o conteúdo aprovado acima): o verbo da N3 é o **interruptor** (DEC-054). Pelos Rascunhos do game-designer (`design/features.md` FEAT-020, `design/upgrades.md`), o interruptor vem com o trailer, sem depender do Trailer Lights. Fechamento em `Q-064`.

## N4 — The copies (noite 4)

| Campo | Conteúdo |
|---|---|
| Conceito | Algo copia um cliente, mas copia **ao contrário**, como espelho. GDD §7.1 "cliente duplicado". Estreia com Mr. Pickett (CHR-005). |
| Sinal | Dois clientes **idênticos** ao mesmo tempo (fila ou calçada). A cópia é **espelhada**: letras da camisa **ao contrário**, relógio no outro pulso, maleta na outra mão, risca do cabelo do outro lado. O sinal mais legível no celular: **o texto invertido na roupa**. |
| Regra do chefe | "Sometimes a customer shows up twice. Same face, same clothes." / "One of them is a copy. The copy is backwards." / "Refuse the backwards one. Serve the real one." |
| Forma curta | **Two of them? Refuse the backwards one.** |
| Verbo correto | Recusar **a cópia**. |
| Erro | "Take Order" na cópia. |
| Omissão | Recusar o original: não é erro de regra; é venda perdida e conta como cliente insatisfeito. |
| Consequência | −35 de sanidade. Sabor: a cópia sorri, o sorriso fica parado um segundo a mais, ela anda de costas até sumir na esquina. |
| Notas | Todo tipo de cliente que pode ser copiado precisa de um detalhe com texto ou lado bem visível. O original e a cópia ocupam 2 dos 3 atores de anomalia? A cópia conta como 1 ator; o original é cliente comum. |

## N5 — The Raincoat Lady (noite 5)

| Campo | Conteúdo |
|---|---|
| Conceito | A mais antiga do late crowd (CHR-006). Não é ameaça: é o acordo. Servi-la é respeito. Variação de GDD §7.1 "roupa proibida", invertida para "roupa que exige atenção". |
| Sinal | Capa de chuva **amarela**, botas verdes, olhos fechados; **pinga água e deixa poça numa noite seca**. Pedido normal no balão. |
| Regra do chefe | "A lady in a yellow raincoat might come by. It won't be raining. She'll be dripping anyway." / "Serve her. Always. Don't refuse her. Don't make her wait." |
| Forma curta | **Yellow raincoat? Always serve her.** |
| Verbo correto | **Atender** (e entregar completo). |
| Erro | Usar "Refuse" nela **ou** deixar a paciência dela acabar. |
| Omissão | Entregar incompleto: não é erro de regra (ela paga 50%, como qualquer cliente), mas não diz "Thank you, dear." |
| Consequência | −35 de sanidade para quem recusou (ou para todos, se a paciência acabou). Sabor: começa a **chover só em cima do trailer** por ~20 s; as luzes piscam uma vez. |
| Notas | Recompensa de sabor quando servida rápido: moeda extra (+$1) e "Thank you, dear." uma vez por noite. Ela tem rosto completo: o jogador treinado na N1 precisa notar que ela **não** é sem rosto. |

## N6 — The wavers (noite 6)

| Campo | Conteúdo |
|---|---|
| Conceito | Alguém que só quer ser notado. Quanto mais é notado, mais quer. |
| Sinal | Uma janela dos apartamentos de cima **acende** e uma silhueta **acena** devagar, sem parar. Som: cortina correndo. |
| Regra do chefe | "Folks upstairs might wave at you." / "Don't wave back. Don't even look up. They just want to be noticed." |
| Forma curta | **Someone waving upstairs? Don't look up.** |
| Verbo correto | Não olhar (tirar a janela do campo de visão). |
| Erro | Manter a janela no campo de visão por **mais de ~3 s seguidos** (sugestão; 1 s de relance só custa o −5 de "ver"). |
| Omissão | Nenhuma: se ninguém olhar, a luz apaga sozinha em ~20 s. |
| Consequência | −35 de sanidade para quem ficou olhando. Sabor: a silhueta passa a acenar com **as duas mãos** e mais duas janelas acendem por alguns segundos. |
| Notas | Por jogador. Ensina "não olhar" num caso **comum** antes da crítica N7. |

## N7 — The Walker (noite 7) — **REGRA CRÍTICA**

| Campo | Conteúdo |
|---|---|
| Conceito | Alguém lá no fim da Juniper Street vem na direção da luz do trailer. Só anda quando é olhado. GDD §7.1 "pessoa que nunca chega ao trailer", invertido: ela **chega** se você deixar. |
| Sinal | Figura alta e escura sob o **último poste** da Juniper. Quando alguém olha, ela dá um passo (o poste onde está pisca). Som: um passo pesado e abafado por avanço. |
| Regra do chefe | "Down Juniper Street, someone walks toward the trailer." / "Every time you look at them, they get closer." / "Whatever you do, never let them reach your light." / "Don't watch the Walker. Not for a second." |
| Forma curta | **Whatever you do, never watch the Walker.** |
| Verbo correto | Não olhar. |
| Erro | O Walker chegar à luz do trailer. Ele avança 1 passo a cada ~1 s em que **qualquer** jogador o mantém no campo de visão; sugestão: **10 passos** do fim da rua até a luz. Sem olhares, recua 1 passo a cada ~10 s. |
| Omissão | Não existe: ignorar é o certo. |
| Consequência | **Noite perdida** (DEC-053): as luzes do trailer piscam e apagam, a tela escurece, todos acordam no banco ao amanhecer, o chefe liga. |
| Notas | Party: a regra é compartilhada; um jogador olhando muito pode perder a noite para todos — é o momento co-op "não olha pra rua!". Relance de 1 s custa 1 passo, então há margem para erro honesto. Precisa de linha de visão longa na Juniper e de a rota até o Mart não passar por ela (`world.md` §3). |

> Anotação **DEC-122** (rodada 15; emenda DEC-053; não muda a regra aprovada acima): na **Consequência**, "todos acordam no banco ao amanhecer" passa a ser **todos acordam em pé na calçada, ao lado do trailer, enquanto a ambulância vai embora com a sirene desligada**. Sem banco. Pelas DEC-111 e DEC-113, acordam **todos**, inclusive espectadores. Pelas DEC-110 e DEC-112, a chance do chefe é **1 por run**: se ela já foi usada, essa noite perdida é o fim da run.

> Anotação **DEC-123** (rodada 15; não muda o conteúdo aprovado acima): **sinal de início** da N7 — o **último poste da Juniper zumbe** (zumbido elétrico grave que sobe por ~2 s e para seco), ouvido por todos da party. A alucinação do poste (sanidade < 40) pisca **sem** zumbir.

## N8 — The long car (noite 8)

| Campo | Conteúdo |
|---|---|
| Conceito | Um carro procura quem cuida da esquina. Análogo não violento do exemplo do usuário (carro de vidro fumê), que foi rejeitado por violência (DEC-023): aqui **ninguém sai do carro e nada é disparado**; só a luz. |
| Sinal | Carro preto, comprido demais, vidros embaçados, estaciona no meio-fio em frente. Motor fazendo um zumbido grave. Depois de ~2 s, **acende o farol alto direto no trailer**. |
| Regra do chefe | "If a long car parks across the street with its lights on you —" / "close the service window. Stay inside." / "Don't open it till you hear it drive away." / "Can't serve with it shut. Folks will wait." (DEC-221; texto trocado pelo narrative-writer em 2026-10-10, Provisório. Era: "get down behind the counter. Stay down." / "Wait till you hear it drive away.") |
| Forma curta | **Long car? Close the window. Keep it shut.** (DEC-221; Provisório. Era: "Long car's lights on you? Hide.") |
| Verbo correto | **Fechar a janela** (DEC-221: botão "Close Window" ao lado do interruptor) dentro de ~8 s depois do farol, ficar dentro do trailer e manter a janela fechada até o carro ir embora (~15 s). |
| Erro | Janela aberta, ou estar perto do trailer do lado de fora, quando o farol **pisca duas vezes** (fim do prazo de ~8 s). |
| Omissão | Abrir a janela antes do carro ir embora conta como erro de quem abriu (DEC-204). |
| Consequência | −35 de sanidade para quem estava exposto. Sabor: o farol pisca, a luz do trailer **apaga por 3 s** e o carro buzina baixinho, como quem achou alguém, e vai embora devagar. |
| Notas | Por jogador. Os clientes na fila esperam (paciência continua correndo). |

## N9 — The knock (noite 9)

| Campo | Conteúdo |
|---|---|
| Conceito | Algo bate na porta dos fundos fingindo ser o chefe. Prepara o final: o chefe **nunca** vai ao trailer à noite. Sinal **sonoro** (hábito "ouvir sons", §17). |
| Sinal | Três batidas na porta dos fundos, pausa, mais três. Legenda sem nome: **"???: Rookie? It's me. It's Walt. Open up."** Segunda série: **"???: It's cold out here, Rookie."** |
| Regra do chefe | "I never come to the trailer at night. Never." / "If someone knocks on the back door and says it's me —" / "it isn't. Close the window. Stay inside." / "Keep it shut till the knocking stops." (DEC-221; texto trocado pelo narrative-writer em 2026-10-10, Provisório. Era: "it isn't. Get down and stay quiet till it stops.") |
| Forma curta | **Knocking? It's not me. Close the window.** (DEC-221; Provisório. Era: "Knock at the back? It's not me. Hide.") |
| Verbo correto | **Fechar a janela** (DEC-221) e ficar dentro do trailer até as batidas pararem (~12 s). |
| Erro | Janela aberta, ou estar perto do trailer do lado de fora, quando a última batida termina. |
| Omissão | Ir até a porta: a porta **não abre** (trancar e abrir porta estão fora do MVP, DEC-054); sair por ela deixa o jogador exposto. |
| Consequência | −35 de sanidade para quem ficou exposto. Sabor: a porta range e abre **um dedo**, entra vento frio, os guardanapos voam, a porta fecha sozinha. Ninguém entra. |
| Notas | Por jogador. Legenda com "???" e não com o nome do chefe: o jogador não pode ter certeza pela interface. |

## N10 — The Hush (noite 10)

| Campo | Conteúdo |
|---|---|
| Conceito | A rua inteira se cala e apaga, poste por poste, até a esquina. Só o letreiro do Mart nunca apaga. Clímax do final (`ending.md`). |
| Sinal | Os postes da Juniper apagam **um por um**, do fim da rua para a esquina, cada um com um "tunk" abafado; os sons da cidade somem; névoa baixa. Uns ~15 s do primeiro ao último poste. |
| Regra do chefe | "Tonight the street might go dark. Lamp by lamp." / "When the lamps start going out, leave the trailer." / "Go to the Mart. Stand under the OPEN sign. It never goes out." / "Come back when the lamps come back." |
| Forma curta | **Lamps going out? Go to the Mart sign.** |
| Verbo correto | Ponto seguro: estar na área marcada sob o letreiro "OPEN 24 HOURS" quando o poste da esquina apaga; ficar até os postes voltarem (~20 s). |
| Erro | Não estar no ponto seguro quando o poste da esquina apaga, ou sair antes dos postes voltarem. |
| Omissão | — |
| Consequência | −35 de sanidade para quem ficou de fora. Sabor: a névoa passa por dentro do trailer, os pedidos na esteira esfriam (vapor some). |
| Notas | Por jogador. A área do letreiro conta como luz (sem dreno de escuro). Ida a 100–120 studs (~12 s andando, DEC-049): a janela de ~15 s é apertada de propósito; o game-designer ajusta. Na noite 10, o último Hush é **roteirizado** perto das 5:45 AM e leva direto ao final. Como só estreia na 10ª noite, é a anomalia menos treinada: a ligação deve ser muito clara. |

---

## Anotação PROVISÓRIA (2026-10-12, Q-207): noites no carrinho × trailer

Não altera o conteúdo aprovado acima (conceito, sinal, verbo, erro, tipo, escopo, ordem N1–N10, regra crítica só na N7). Registra **onde cada anomalia é jogada**
com o novo fluxo (D1, D2, N1, D3, N2 … N10; a noite começa no carrinho, o trailer é um desbloqueio opcional depois da noite 2):

| Anomalia | Verbo | `Trailer` (Content) | No carrinho |
|---|---|---|---|
| N1 blank folks | recusar | None | igual |
| N2 wrong food | descartar | None | igual |
| N3 stopped clock | luz | **Needs** | o interruptor é do trailer; sem ele a noite 3 repete a N2 no lugar (mesmo número de ocorrências); a ligação diz "No trailer yet? Then the clock behaves" |
| N4 copies | recusar | None | igual |
| N5 raincoat lady | atender | None | igual |
| N6 wavers | não olhar | None | igual |
| N7 walker | não olhar (crítica) | None | igual |
| N8 long car | fechar a janela | Helps | **sair da zona do carrinho e ficar no Mart**: só quem está na zona (raio 24 do ponto TRL) é testado no 2º clarão do farol |
| N9 knock | fechar a janela | Helps | idem |
| N10 hush | ponto seguro | None | igual (Mart) |

As noites 1 e 2 (sempre no carrinho) só têm anomalias `None`: recusar e descartar. A ordem não mudou porque DEC-096 liga `ANM-00k` à noite de estreia.

## Interações que o game-designer deve checar

- **N3 × N7**: desligar a luz (N3) diminui a área iluminada; o Walker (N7) mede "chegar à luz". Sugestão: com a luz desligada o alvo do Walker é a porta do trailer.
- **N8/N9 × fila**: com a janela fechada não se atende (DEC-221, Provisório `Q-173`): clientes esperando; com Counter 2–3 a paciência maior ajuda (uso duplo, DEC-006).
- **N10 × N7**: correr até o Mart não deve exigir olhar a Juniper.
- **N1 × N5**: a Raincoat Lady tem rosto; o jogador não deve confundi-la com N1.
- **N4 × N1**: a cópia nunca é sem rosto; um evento por cliente.
- **N8 × trânsito** (anotado por DEC-087, trânsito andando no MVP): a ficha da N8 não muda. Como manter o carro comprido legível no meio do trânsito é proposta em Rascunho (`world.md` §3.2, `Q-103`); se exigir mudar o sinal, volta ao usuário.
- Teto de 3 atores simultâneos (DEC-045): N3 e N10 são eventos de ambiente (não ocupam ator); N2 e N9 são objeto/som. Atores: N1, N4, N5, N6, N7, N8.
