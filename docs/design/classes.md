Status: Rascunho

# Classes jogáveis (CLS-###)

Autor: game-designer, 2026-10-08 (conciliado até a rodada 15). Conteúdo aprovado em **[DEC-061, DEC-069, DEC-070]** (`proposals-round-2.md` §1–§2, Aprovado); ajustes de leitura por DEC-081, DEC-083, DEC-091 a DEC-095, DEC-104, DEC-110 a DEC-129 (nenhuma muda classe; limite de 2 revives/noite, prazo de 6:00 AM e Robux só para si valem igual para todas as classes; sanidade inicial da classe também na noite repetida, DEC-111).
Esta ficha organiza o aprovado no formato de ficha e acrescenta só detalhes de implementação (tipos de efeito, critérios por classe),
marcados como proposta. Nomes são placeholders (narrative-writer). Sistema: FEAT-028. Gemas: FEAT-029, `economy.md` §6.

> **DEC-145 (2026-10-10):** personagem padrão "HotDog Crew" (animais em rig R6 custom, `Assets/reference/customrig.png`; a prancha diz "várias classes com personalidades diferentes"). **Não decidido:** cada animal é uma classe ou só visual → `Q-142` (sugestão do secretário: só visual, sem mexer em DEC-069). Até a resposta, nenhuma classe muda.
>
> **DEC-147 (2026-10-10, fecha `Q-142`):** **cada animal = uma classe `CLS-###` com habilidade própria**; escolher o animal é escolher a classe. **DEC-146:** o jogador escolhe o bicho e não usa mais o avatar do Roblox. O desenho das classes por animal é do **game-designer** (opções com recomendação, Rascunho); o usuário decide depois. Nenhuma DEC de classe foi revogada: DEC-061, DEC-069, DEC-070, DEC-081 seguem valendo até lá. Conflitos a resolver na proposta (nº de animais × 8 classes, animal grátis = Rookie, animais pagos com gemas, "habilidade" passiva × ativa, nomes/fantasias humanas, escolha no lobby) → `Q-145`. Até a proposta ser decidida, as fichas abaixo não mudam.
>
> **Proposta do game-designer para `Q-145` (Rascunho, 2026-10-10):** seção **"Proposta Q-145 — Classes por animal"** no fim deste documento. Opções com recomendação; nada ali vale antes de DEC do usuário.
>
> **Rodada 3 (Rascunho, 2026-10-10, 18 espécies, DEC-158/163):** a proposta vigente para `Q-145` está em **`docs/design/proposals-round-3.md` §1** e **substitui** a seção "Proposta Q-145" abaixo onde as duas divergem (mapa P2 e lista do MVP). Recomendação: **6 classes no MVP** (Cachorro, Coelho, Gato, Urso, Raposa, Coruja), **Coruja = Night Owl**, **Leão = Shift Lead**, Panda = Barista; Tartaruga vira cliente; guaxinim exclusivo do Quentin; efeitos e preços de DEC-069/070 sem mudança. P3 (desbloqueio), P4 (passiva), P6 (tela "Crew") e P7 (regras do modelo) seguem como estão.
>
> **DEC-186 (2026-10-10, fecha `Q-145`), nota do secretário:** usuário escolheu as recomendadas de `proposals-round-3.md` §1. **6 classes no MVP:** CLS-001 Cachorro "Rookie" (grátis), CLS-002 Coelho "Runner" (45), CLS-003 Gato "Line Cook" (45), CLS-004 Urso "Hauler" (45), CLS-005 Raposa "Hawker" (120), CLS-006 Coruja "Night Owl" (120); **1ª atualização:** CLS-007 Panda "Barista" (120), CLS-008 Leão "Shift Lead" (180). Habilidades = bônus/contrapeso **passivos** de DEC-069, sem mudança de número. Escolha na tela **"Crew"** do lobby, travada na run. **Guaxinim não é jogável** (só Quentin). Emendas: DEC-069 (MVP 4 → 6), DEC-070 (375 gemas para as 5 pagas). A seção "Proposta Q-145" abaixo é histórico; vale a DEC. Nomes finais com o narrative-writer. Fichas a reescrever pelo game-designer (animal por ficha, coluna MVP).

## Regras gerais **[DEC-069]**

| Regra | Valor |
|---|---|
| Escolha | no lobby; travada até o fim da run |
| Escopo | pessoal (ações do próprio jogador); no máximo 1 efeito de party (Shift Lead), não acumula |
| Repetir na party | permitido |
| Teto | lucro/min solo entre −12% e +12% do Rookie; nenhuma classe toca regra de anomalia (verbo, crítica, chances, −35) |
| Contrapeso | toda classe paga tem um, em outro eixo |
| Obtenção | só com gemas ganhas jogando (gemas creditadas e salvas por evento, DEC-104; anti-AFK, DEC-083) |
| Preço | tier 1 = 45 · tier 2 = 120 · tier 3 = 180 gemas **[DEC-070]**. **Vigente (TASK-308, Provisório, 2026-10-15):** Coelho/Gato 2.000, Urso 3.000, Raposa/Coruja 10.000, Panda 15.000, Leão 20.000 (`economy.md` §9) |
| Reviver, ambulância, atropelamento (rodadas 9–15) | nenhuma classe muda: limite de revives (DEC-129), janela de 10 s, prazo de reviver (DEC-115), preço do Rescue Whistle (DEC-129), tempo no chão do atropelamento, proteção de 5 s. Mesmo espírito de "nenhuma classe toca regra de anomalia" (DEC-069) e da guarda contra pay-to-win (Q-017) |
| Sem XP | classes não têm nível nem XP **[DEC-081]** |

### Interação com as regras novas (rodadas 8–12)

| Classe | Efeito indireto (sem regra nova) |
|---|---|
| Runner | cruza a pista mais rápido (18 studs/s): menos exposição ao trânsito (FEAT-033) e chega antes ao Mart para comprar na bancada ou o Rescue Whistle. Sanidade ao reviver: 50 (50% de 100) |
| Line Cook | mais lento (15): um pouco mais exposto na travessia. Sanidade ao reviver: 50 |
| Night Owl | sanidade ao reviver: **60** (50% de 120); de dia, 15 studs/s na travessia |
| Rookie | sanidade ao reviver: 50 |

Nenhum desses efeitos muda o teto de ±12% (a travessia é ~2 × 4 s por ida ao Mart).

### Compra com gemas ou Robux (pedido do usuário 2026-10-11, **Provisório**)

- Toda classe paga do MVP pode ser comprada com **gemas** (preço DEC-070, sem mudança) **ou Robux** (developer product
  por classe; preço sugerido em `economy.md` §9, `Q-190`). Cachorro segue grátis para toda conta (DEC-186).
- Classes possuídas = campo `Classes` do perfil (`data.md` §1.7); só classe possuída pode ser selecionada; a classe da
  run continua travada (DEC-069), mesmo que um recibo chegue no meio da run.
- Classe também pode vir de **código** (`CodesService`, `Q-191`). Já possuída → vira as gemas do preço.
- Contradiz DEC-069 ("só com gemas ganhas jogando"): registrado em `Q-190` (a) para virar DEC.

## Template de ficha

```
### CLS-### — Nome
Chave · Tier/preço · MVP? · Fantasia
Efeitos (tipo, valor, escopo) · Contrapeso · Turno onde brilha · Papel na party
Δ lucro estimado · Critérios de aceite
```

## Tipos de efeito (tabela `Classes.effects`, proposta)

| Tipo | Parâmetro | Usado por |
|---|---|---|
| `walkSpeed` | studs/s (sempre) | Runner |
| `daySpeed` | studs/s (só de dia) | Night Owl |
| `speedWhileCarrying` | studs/s com N pacotes | Hauler |
| `grillTimeMult` | multiplicador nas salsichas do dono | Line Cook |
| `packageLimit` | nº de pacotes | Hauler |
| `tipValue` | $ por gorjeta nos pedidos do dono | Hawker, Shift Lead ($0) |
| `tipWindowDelta` | s na janela dos pedidos do dono | Hawker |
| `nightSanityStart` / `nightSanityMax` | pontos | Runner, Night Owl |
| `coffeePrepTime` / `coffeeRestore` | s / pontos, cafés feitos pelo dono | Barista |
| `seeLoss` | pontos por anomalia vista pelo dono | Barista |
| `partyGradeBonus` | p.p. no bônus da nota; não acumula | Shift Lead |

## Índice

| ID | Chave | Nome | Tier | Preço | MVP |
|---|---|---|---|---|---|
| CLS-001 | `class_rookie` | "Rookie" | 0 | grátis | **sim** |
| CLS-002 | `class_runner` | "Runner" | 1 | 45 | **sim** |
| CLS-003 | `class_line_cook` | "Line Cook" | 1 | 45 | **sim** |
| CLS-004 | `class_hauler` | "Hauler" | 1 | 45 | não |
| CLS-005 | `class_hawker` | "Hawker" | 2 | 120 | não (5ª se houver folga) |
| CLS-006 | `class_night_owl` | "Night Owl" | 2 | 120 | **sim** |
| CLS-007 | `class_barista` | "Barista" | 2 | 120 | não |
| CLS-008 | `class_shift_lead` | "Shift Lead" | 3 | 180 | não |

---

### CLS-001 — "Rookie"

- Chave `class_rookie` · Tier 0, grátis · MVP · Fantasia: primeiro dia de trabalho.
- Efeitos: nenhum · Contrapeso: nenhum. É a régua do balanceamento.
- Critérios de aceite: todo jogador novo tem Rookie desbloqueado e selecionado; atributos = valores base de todas as tabelas.

### CLS-002 — "Runner"

- Chave `class_runner` · Tier 1, 45 gemas · MVP · Fantasia: entregador de bicicleta que virou atendente.
- Efeito: `walkSpeed` 16 → 18 (+12,5%). Contrapeso: `nightSanityStart` 90 (máx. 100).
- Brilha: dia (mercado e reposição; ida ao mercado ~25 s → ~22 s). Δ lucro solo dia 3: +$3 (+4%).
- Critérios de aceite: velocidade 18 de dia e de noite; cada noite começa em 90; café pode levar a 100.

### CLS-003 — "Line Cook"

- Chave `class_line_cook` · Tier 1, 45 · MVP · Fantasia: ex-cozinheiro de lanchonete de estrada.
- Efeito: `grillTimeMult` 0,85 nas salsichas que **ele** põe na grelha (12 → 10,2 s; 10 → 8,5 s; 8 → 6,8 s). Contrapeso: `walkSpeed` 15.
- Brilha: dia e noite (grelha). Δ lucro solo dia 3: +$3 (+4%).
- Critérios de aceite: a barra da salsicha dele mostra o tempo reduzido e só ela.

### CLS-004 — "Hauler"

- Chave `class_hauler` · Tier 1, 45 · fora do MVP · Fantasia: estoquista do mercado da esquina.
- Efeito: `packageLimit` 3. Contrapeso: `speedWhileCarrying` 14 com 3 pacotes.
- Brilha: dia (estoque). Δ lucro solo dia 3: +$2 a +$4 (+3–5%).
- Critérios de aceite: 3º pacote permitido; velocidade 14 só enquanto segura 3.

### CLS-005 — "Hawker"

- Chave `class_hawker` · Tier 2, 120 · fora do MVP (5ª se houver folga) · Fantasia: vendedor de rua que sabe agradar.
- Efeito: `tipValue` $2 nos pedidos que ele entrega. Contrapeso: `tipWindowDelta` −4 s nesses pedidos.
- Brilha: dia (balcão). Δ lucro solo dia 3: +$5 (+6%).
- Critérios de aceite: gorjeta $2 só quando ele faz o "Serve"; janela 16 + 4K − 4 s.

### CLS-006 — "Night Owl"

- Chave `class_night_owl` · Tier 2, 120 · MVP · Fantasia: quem sempre trabalhou de madrugada.
- Efeito: `nightSanityStart` e `nightSanityMax` 120. Contrapeso: `daySpeed` 15.
- Brilha: noite (rua escura, ponto seguro). Δ lucro solo dia 3: −$1 (−1%); à noite +20 de folga ≈ 20 s de escuro ou 4 anomalias vistas.
- Critérios de aceite: noite começa em 120; café não passa de 120; de dia velocidade 15, à noite 16.

### CLS-007 — "Barista"

- Chave `class_barista` · Tier 2, 120 · fora do MVP · Fantasia: anos numa cafeteria 24 h.
- Efeito: cafés feitos por ele — `coffeePrepTime` 3 s, `coffeeRestore` +35 para quem beber. Contrapeso: `seeLoss` −8 para ele.
- Brilha: noite (suporte). Δ lucro: 0.
- Critérios de aceite: o Coffee guarda quem o fez; +35 vale para qualquer jogador que beba esse café.

### CLS-008 — "Shift Lead"

- Chave `class_shift_lead` · Tier 3, 180 · fora do MVP · Fantasia: o funcionário em quem o chefe confia.
- Efeito (party): `partyGradeBonus` +5 p.p. (A 25%, B 15%, C 5%, D 0%), não acumula. Contrapeso: `tipValue` $0 nos pedidos dele.
- Brilha: dia, em party. Δ lucro solo dia 3: −$2 (−2%); party de 4: +$12 (+4–5%).
- Critérios de aceite: 2 Shift Leads na party = +5 p.p., não +10.

---

## Tabela comparável (Δ lucro, dia 3) **[proposals-round-2 §1.4]**

| Classe | Solo | Party de 4 (por classe) | Noite |
|---|---|---|---|
| Rookie | 0 | 0 | 0 |
| Runner | +4% | +1% | −10 sanidade inicial |
| Line Cook | +4% | +2% | igual de dia |
| Hauler | +3–5% | +2% | — |
| Hawker | +6% | +2% | — |
| Night Owl | −1% | 0 | +20 sanidade |
| Barista | 0 | 0 | café do grupo +40% e 2× mais rápido |
| Shift Lead | −2% | +4–5% | — |

Critério de aceite global: simulação solo dia 3 de cada classe dentro de ±12% do Rookie; nenhuma altera verbo, crítica, chances ou −35; nenhuma altera limite de revives, janela de 10 s, prazo de reviver ou tempo no chão do atropelamento.

## Proposta Q-145 — Classes por animal

Status da seção: **Rascunho** (game-designer, 2026-10-10). Responde `Q-145` (a)–(g). Base: DEC-145, DEC-146, DEC-147.
Nada aqui vale antes de DEC do usuário. Nomes entre aspas são placeholders (narrative-writer, inglês, DEC-022).

### P0. Princípio da recomendação

**Trocar a identidade e manter os números.** As 8 classes de DEC-069 já estão balanceadas (±12%), com preço (DEC-070) e critérios de aceite.
A recomendação dá a cada classe um animal cuja personalidade **explica** o bônus e o contrapeso.
Assim nenhum número aprovado muda, e a DEC nova só aprova "qual animal é qual classe" e os nomes.

### P1. Quantos e quais animais (Q-145 a)

| Opção | O quê | Prós | Contras | Impacto no escopo |
|---|---|---|---|---|
| **A — 8 animais, 1:1 com as 8 classes** | os 6 da prancha + tartaruga (citada pelo usuário) + coruja; MVP = os mesmos 4 de DEC-069 | não muda DEC-061/069/070; balanceamento e critérios já prontos; cada contrapeso tem justificativa na fantasia | 2 animais fora da prancha (tartaruga no MVP, coruja depois) precisam de referência nova do art-director | MVP: 4 conjuntos de peças (cão, coelho, gato, tartaruga). Pós-MVP: +4 |
| B — 7 animais (prancha + tartaruga), Shift Lead cortado | CLS-008 sai (ID aposentado, não reaproveitado) | só animais que o usuário mostrou ou citou; tira o único efeito de party (o mais difícil de testar) | **emenda DEC-069** (lista de 8); perde o papel de party; coleção cai para 6 pagas | igual ao A no MVP; −1 animal depois |
| C — só os 6 da prancha | Night Owl vira panda (olheiras); Barista e Shift Lead cortados; tartaruga fica de fora | todo o MVP com referência pronta na prancha | **emenda DEC-069** (2 classes cortadas); deixa de fora a tartaruga, citada pelo usuário; panda fica sem papel próprio depois | MVP: cão, coelho, gato, panda; pós-MVP: +2 |

**Recomendação: A.** É a única opção que não emenda nenhuma DEC de classe e já cobre os exemplos do usuário (tartaruga, raposa, cachorro).
Reservas sem ID (DEC-069: "Lookout", "Bargain Hunter") viram candidatas a animal de atualização: suricato (vigia) e guaxinim (pechincha). Ficam fora de qualquer lista até haver DEC.

### P2. Mapa classe → animal (opção A)

| ID | Animal | Papel (placeholder) | Tier · gemas | MVP | Por que esse animal |
|---|---|---|---|---|---|
| CLS-001 | **Cachorro** | "Rookie" | 0 · grátis | **sim** | mascote óbvio da "HotDog Crew", 1º da prancha; leal, faz de tudo, sem mania. Neutro = régua |
| CLS-002 | **Coelho** | "Runner" | 1 · 45 | **sim** | pernas rápidas (+velocidade); assustadiço (começa a noite com 90 de sanidade) |
| CLS-003 | **Gato** | "Line Cook" | 1 · 45 | **sim** | patas precisas na grelha (−15% no tempo); não corre por ninguém (velocidade 15) |
| CLS-004 | **Urso** | "Hauler" | 1 · 45 | não | forte, carrega 3 pacotes; carregado, fica lento (14) |
| CLS-005 | **Raposa** | "Hawker" | 2 · 120 | não (5ª se houver folga) | esperta e de boa lábia (gorjeta $2); apressa o cliente, que dá a gorjeta só se for rápido (janela −4 s) |
| CLS-006 | **Tartaruga** | "Night Shift" (era "Night Owl") | 2 · 120 | **sim** | calma, o casco protege (sanidade 120); devagar de dia (15) |
| CLS-007 | **Panda** | "Barista" | 2 · 120 | não | as "olheiras" vêm do café: faz o melhor café (3 s, +35); cansado, impressiona mais fácil (−8 por anomalia vista) |
| CLS-008 | **Coruja** | "Shift Lead" | 3 · 180 | não | sábia, organiza o turno (+5 p.p. na nota da party); séria demais, não recebe gorjeta |

Notas:
- "Night Owl" numa tartaruga confunde com a coruja (CLS-008). Placeholder trocado para "Night Shift"; o nome final é do narrative-writer.
- Variante possível (mesma opção A): **tartaruga ↔ coruja** (coruja = sanidade e lenta de dia, porque dorme de dia; tartaruga velha e sábia = Shift Lead). Não recomendo: tira do MVP o animal que o usuário citou e põe nele um animal sem referência na prancha.
- Chaves de dados: proposta `class_dog`, `class_rabbit`, `class_cat`, `class_bear`, `class_fox`, `class_turtle`, `class_panda`, `class_owl` (o código ainda não existe, Fase 0). **Os IDs CLS-001..008 não mudam.** Se o architect já usa as chaves antigas em `tech/content-data.md`, ele alinha.

### P3. Animal grátis e desbloqueio (Q-145 b, c)

| Opção | O quê | Conflito | Prós | Contras |
|---|---|---|---|---|
| **F1 — só o Cachorro é grátis** | Cachorro = Rookie, neutro; os outros 7 com gemas (45/120/180) | nenhum | régua de balanceamento intacta; meta de gemas igual | party de 4 jogadores novos = 4 cachorros iguais por ~95 min |
| F2 — Cachorro + 1 animal de tier 1 grátis à escolha no 1º login | ganho de 45 gemas na entrada | **emenda DEC-069** (só o Rookie é grátis) e **DEC-070** (meta de gemas) | variedade desde o 1º minuto | dá poder de graça; a 1ª compra perde valor |
| F3 — todos os animais grátis como visual, classe comprada à parte | — | **contraria DEC-147** (animal = classe) | — | descartada; listada só para registro |

**Recomendação: F1**, com uma sub-proposta opcional para o problema dos "4 cachorros iguais":

- **V (opcional, Rascunho) — pelagens:** cada animal tem **3 pelagens** (ex.: cachorro caramelo / preto e branco / dourado), todas grátis, escolhidas na mesma tela. **Só cor**, mesma classe, sem efeito. Custo: troca da faixa de pelo no atlas (o corpo base já prevê isso). Ajuda a party a se distinguir. Se o usuário não quiser escopo extra, sai sem afetar o resto.

Tempo até cada desbloqueio (solo mediano, `economy.md` §6; valores aproximados):

| Meta | Gemas | Quando (fim de) | Tempo de run |
|---|---|---|---|
| 1º animal tier 1 (Coelho ou Gato) | 45 | Night 2 | ~1 h 35 |
| 2 animais tier 1 | 90 | Night 4 | ~2 h 30 |
| Tartaruga direto (sem tier 1 antes) | 120 | Night 6 (na Night 5 faltam ~3) | ~3 h 30 |
| MVP completo (Coelho + Gato + Tartaruga) | 210 | Night 9 | ~5 h 20 |
| Coleção dos 7 pagos (pós-MVP) | 675 | ~1,8 run | ~11–12 h |

### P4. Habilidade passiva × ativa (Q-145 d)

| Opção | O quê | Prós | Contras | Escopo |
|---|---|---|---|---|
| **P — passiva (como hoje)** | "habilidade própria" = bônus de atributo + contrapeso já aprovados | cumpre DEC-061 sem emenda; sem botão novo no mobile; balanceamento medido; servidor só aplica números da tabela | menos "momento de destaque" por animal | zero sistema novo |
| A — ativa com recarga | ex.: Coelho "sprint" 5 s a cada 60 s; Urso "carrega tudo" 10 s | sensação de poder; identidade forte | **DEC nova** (DEC-061 diz atributo); **botão em tela**, que DEC-015 e FEAT-032 não preveem durante a run ("sem botões de ação"); vira verbo novo perto de DEC-054; risco de mexer em anomalia (sprint para fugir do Walker, ANM-007), contra DEC-069; teto de ±12% difícil de medir | 8 habilidades × rede, VFX, UI, testes; recarga persistida na reconexão |
| H — passiva + "assinatura" cosmética | P + 1 animação própria por animal (idle no lobby, pose na tela de resumo do turno) | personalidade sem tocar em regra | mais 8 animações (AST-069) | pequeno; pode entrar depois do MVP |

**Recomendação: P no MVP; H como atualização.** Motivo principal: o jogo é de 1ª pessoa, mobile primeiro, e o HUD não tem botão de ação durante a run. Uma habilidade ativa exige um botão novo e cria a tentação de usá-la contra anomalias, o que DEC-069 proíbe.
A personalidade vem da fantasia (P2), do modelo (P7) e, depois, da animação (H).

Regras que seguem valendo para todos os animais, sem mudança: teto de ±12% de lucro/min solo · nenhum animal mexe em regra de anomalia (verbo, crítica, chances, −35) · repetir animal na party é permitido · efeito de party só da Coruja, sem acumular · sem XP nem nível (DEC-081) · obtenção só com gemas ganhas jogando, nunca com Robux (DEC-062, DEC-069) · reviver, ambulância e atropelamento iguais para todos (DEC-129, DEC-115).

### P5. Fantasia e personalidade (Q-145 e)

Uma linha de fantasia e uma de "como joga". O texto final em inglês é do narrative-writer.

| Animal | Personalidade | Como joga (bônus → contrapeso) | Brilha em |
|---|---|---|---|
| Cachorro | animado, leal, primeiro dia no emprego e quer ajudar em tudo | sem bônus, sem contrapeso | qualquer coisa; é a referência |
| Coelho | elétrico, sempre com pressa, leva susto com qualquer barulho | 18 studs/s sempre → noite começa com 90 | idas ao Mart de dia, travessia mais curta |
| Gato | perfeccionista na cozinha, preguiçoso fora dela | grelha 0,85× nas salsichas dele → 15 studs/s | grelha, dia e noite |
| Urso | forte e tranquilo, o "estoquista" | 3 pacotes → 14 studs/s carregando 3 | reposição de estoque de dia |
| Raposa | vendedora nata, sorriso fácil, sempre com pressa de fechar a venda | gorjeta $2 → janela de gorjeta −4 s | balcão de dia |
| Tartaruga | calma, nada a abala; leva o casco consigo | sanidade inicial e máx. 120 → 15 studs/s de dia | rua escura, noites longas |
| Panda | vive de café, as olheiras são marca registrada | café dele 3 s e +35 → −8 por anomalia vista | suporte da party à noite |
| Coruja | veterana, vê o turno inteiro, mantém todo mundo no ritmo | +5 p.p. no bônus da nota da party → pedidos dele sem gorjeta | party de 3–4, de dia |

### P6. Onde e como escolhe (Q-145 f)

| Opção | O quê | Prós | Contras |
|---|---|---|---|
| **L1 — tela "Crew" no lobby** | botão "Crew" abre grade de 8 cartões (prévia 3D girando, papel, bônus/contrapeso em 2 linhas, preço); "Select" ou "Buy" | funciona igual em mobile, PC e console; não depende do layout do lobby (`Q-085`, `Q-070` abertas) | menos "mundo físico" |
| L2 — vestiário físico no lobby | 8 manequins com prompt "Pick"/"Buy" | coerente com o prompt no mundo (DEC-066) | depende do mapa do lobby; andar até cada manequim no mobile é lento; 8 modelos no lobby |
| L3 — escolha na tela de "Start" | confirmação antes do teleporte | sem tela extra | pressa e conflito com a contagem de 5 s; o colega não vê a escolha antes |

**Recomendação: L1**, com estas regras:

| Regra | Valor (proposta) |
|---|---|
| Onde | só no lobby; botão "Crew" (botões são permitidos no lobby, FEAT-032) |
| Personagem no lobby | o jogador **já anda no lobby como o animal escolhido**; trocar na tela troca o corpo na hora (sem avatar, DEC-146) |
| Compra | só no lobby; o servidor confere o saldo, desconta e salva numa operação; "Buy" pede confirmação ("Buy Rabbit for 45 gems?"); animal já comprado não aparece como "Buy" |
| Bloqueado | cartão com cadeado e preço; o servidor recusa selecionar animal não comprado |
| Trava | a escolha congela quando começa a contagem de 5 s do "Start"; vale até o fim da run (DEC-069). Reconexão e atrasado usam o animal do "Start" (FEAT-001) |
| Padrão | último animal usado (salvo no perfil); conta nova = Cachorro |
| O que o colega vê | no lobby: o corpo do animal + ícone do animal na lista da party; na run: o corpo do animal (DEC-088, DEC-146); repetidos se distinguem pelo nome sobre a cabeça (e pela pelagem, se V entrar) |
| Onde o próprio jogador se vê | em 1ª pessoa sem braços (DEC-097) ele **não vê o próprio bicho na run**. Proposta: retrato do animal de cada membro na tela de resumo do turno e no spectate (nome do colega assistido + ícone). Sem elemento novo no HUD de jogo |

### P7. O que muda no modelo por animal (para art-director e modeler-3d)

Base comum: `Assets/blender/character/AST-053_CrewBase.blend` (R6 custom; Torso e membros com caixas R6 padrão; cabeça chibi 2,3 × 1,75 × 1,9; attachments `EarLeft`/`EarRight`/`Snout` na cabeça e `Tail` no torso; uniforme = `Cap` + `Apron` como Accessories; uma faixa de "pelo" recolorível usada pela cabeça e pelos antebraços/mãos).

| Animal | Orelhas (`EarLeft`/`EarRight`) | Focinho (`Snout`) | Cauda (`Tail`) | Extra | Pelo (cabeça / mãos / detalhe) |
|---|---|---|---|---|---|
| Cachorro | caídas, longas, arredondadas | curto, arredondado, nariz preto | curta, curvada para cima | máscara clara no focinho | marrom-caramelo / caramelo / creme |
| Coelho | **longas, em pé** (atravessam o boné) | pequeno, nariz rosa | pompom | interior da orelha rosa | branco / branco / rosa |
| Gato | triangulares pontudas | pequeno, nariz rosa | longa, curvada | listras opcionais (decal) | cinza / cinza / branco |
| Urso | redondas pequenas | largo, claro, nariz preto | bolinha mínima | — | marrom / marrom / bege |
| Raposa | triangulares grandes, ponta escura | **pontudo, alongado** | **grande, volumosa, ponta branca** | bochechas brancas | laranja / **preto** / branco |
| Tartaruga | **nenhuma** (attachments vazios) | achatado, sem nariz destacado | curtinha | **casco** nas costas (`BodyBackAttachment`) | verde-oliva / verde-oliva / casco marrom |
| Panda | redondas pretas | curto, branco, nariz preto | bolinha branca | **manchas pretas nos olhos** | branco / **preto** / preto |
| Coruja | tufos de pena | **bico** | leque curto de penas | olhos grandes (decal) | marrom-acinzentado / marrom / creme |

Pedidos e alertas para o art-director (donos: art-director e modeler-3d; números são sugestão, o orçamento final é da `Q-144` d):

1. **Faixa de pelo dupla.** O corpo base tem **uma** faixa para cabeça e mãos. Panda (cabeça branca, mãos pretas) e raposa (mãos pretas) precisam de **duas faixas**: `FurHead` e `FurHands`. Sugestão: separar as duas faixas no corpo base agora, antes de exportar as variantes.
2. **Orelhas × boné.** Orelhas em pé (coelho, gato, raposa) saem em ±0,94 e o boné cobre até ±1,22: atravessam o boné. Na prancha elas atravessam por cima (aceitável no estilo toy). Definir se fica assim ou se há um offset de orelha por animal.
3. **Casco da tartaruga** sem colisão, dentro de 2 × 2 × 0,6 nas costas, sem cobrir as alças do avental.
4. **Orçamento por animal (sugestão):** peças somadas ≤ 400 tris (orelhas 2 × ≤ 60, focinho ≤ 80, cauda ≤ 120, extra ≤ 200 só para o casco).
5. **Paleta:** verde da tartaruga e tons da coruja não estão na prancha; o art-director encaixa no `style-guide.md`.
6. **ID do arquivo.** Os arquivos se chamam `AST-053_CrewBase`, mas no `asset-list.md` o **AST-053** é a base R6 de **NPC** (DEC-146: "AST-053 fica só para NPCs; o corpo do jogador é ficha nova"). Precisa de ID próprio para o corpo da crew e para cada conjunto de peças por animal (sugestão: 1 ficha por animal) → art-director + secretário.

Regras de jogo do modelo (critérios de aceite, valem para todos os animais):

- `HumanoidRootPart` 2 × 2 × 1 e altura do olho **iguais** em todos os animais. Peças de animal com `CanCollide`, `CanQuery` e `CanTouch` desligados e `Massless` ligado: nenhuma cauda, orelha ou casco muda colisão, hitbox de atropelamento, "esconder" (ANM-008/009) ou cálculo de visão (T7).
- Tool na mão (`RightGripAttachment`), ragdoll (T22) e animações (AST-069) iguais para os 8.

### P8. Dados (tabela `Classes`, proposta)

Campos novos ao lado de `effects`: `animal` (chave), `displayName`, `roleName`, `tier`, `price`, `art` = { `ears`, `snout`, `tail`, `extra`, `furHead`, `furHands`, `detail` }, `pelts` (lista de pelagens, só se V entrar), `portrait` (ícone). Adicionar um animal = 1 linha na tabela + 1 conjunto de peças, sem código específico.

### P9. Tabela comparável (opção A; números de DEC-069 sem mudança)

| Animal (classe) | Tier | Solo dia 3 | Party de 4 (por classe) | Noite |
|---|---|---|---|---|
| Cachorro (Rookie) | 0 | 0 | 0 | 0 |
| Coelho (Runner) | 1 | +4% | +1% | −10 de sanidade inicial |
| Gato (Line Cook) | 1 | +4% | +2% | igual ao dia |
| Urso (Hauler) | 1 | +3–5% | +2% | — |
| Raposa (Hawker) | 2 | +6% | +2% | — |
| Tartaruga (Night Shift) | 2 | −1% | 0 | +20 de sanidade |
| Panda (Barista) | 2 | 0 | 0 | café da party +40% e 2× mais rápido |
| Coruja (Shift Lead) | 3 | −2% | +4–5% | — |

### P10. Critérios de aceite da proposta

- Conta nova: Cachorro desbloqueado e selecionado; nenhum traço do avatar do Roblox no personagem.
- No lobby, trocar de animal troca o corpo em ≤ 1 s, e os outros jogadores do lobby veem a troca.
- Selecionar animal não comprado é recusado pelo servidor; comprar com saldo insuficiente é recusado; comprar duas vezes não desconta duas vezes.
- Depois do início da contagem do "Start", a escolha não muda até o fim da run, nem na reconexão.
- 2 jogadores com o mesmo animal na party: permitido, efeitos individuais; 2 Corujas = +5 p.p., não +10.
- Cada animal aplica exatamente os efeitos da classe (tabela P9); a simulação solo do dia 3 fica dentro de ±12% do Cachorro.
- Nenhum animal altera verbo, regra crítica, chances, −35, limite de revives, janela de 10 s, prazo de reviver ou tempo no chão do atropelamento.
- Hitbox, altura do olho e colisão idênticas entre os 8 animais (P7).
- Tela de resumo do turno mostra o retrato do animal de cada membro.

### P11. O que precisa de DEC do usuário

| Ponto | Recomendação | Emenda alguma DEC? |
|---|---|---|
| Lista e mapa de animais | A (8, 1:1, MVP = Cachorro, Coelho, Gato, Tartaruga) | não (só nomes, que DEC-069 já trata como placeholder) |
| Animal grátis | F1 (Cachorro) | não |
| Pelagens grátis por animal | V (opcional) | não; escopo novo pequeno |
| Habilidade | P (passiva) agora; H (animação de assinatura) depois | não (A emendaria DEC-061) |
| Escolha | L1 (tela "Crew" no lobby) | não |

## Propostas pendentes (classes)

| Tema | Recomendação | Precisa do usuário? |
|---|---|---|
| Classes e reviver/atropelamento | nenhuma classe altera essas regras (tabela de regras gerais) | não (estende a guarda de DEC-069) |
| Sanidade ao reviver por classe | 50% do máximo da classe (Night Owl 60), sem efeito de classe extra | não |
| Classes por animal (`Q-145`) | seção "Proposta Q-145": A + F1 + P + L1; V e H opcionais | **respondida: DEC-186** (rodada 3: 6 no MVP, mapa mnemônico, passivas, gemas, guaxinim não jogável) |
| Faixa de pelo dupla e ID do corpo da crew | ver P7 itens 1 e 6 | não (art-director + secretário) |
