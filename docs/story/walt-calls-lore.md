Status: Rascunho

# Ligações falsas do Walt e voz do rádio: lore em easter egg

Autor: narrative-writer, 2026-10-19. Pedido do dono (2026-10-19): menos ligação falsa "vazia"; cada uma traz uma fala com dica; usar esses áudios para montar a lore, com o Walt como verdadeiro vilão no fim.
Tudo aqui é **Provisório**. Não muda `ending.md` (Aprovado, DEC-075/076) nem regra de jogo. Falas em inglês, documentação em pt-BR.

Canais (já no código):

| Canal | Quando | Quem fala | Legenda | Fonte hoje |
|---|---|---|---|---|
| `fake_call` | sanidade < 60, cooldown 600 s, peso 0,25; prenúncio fixo da N2 | Walt (voz Walt) | "Walt: ..." | `Content/Hallucinations.luau` `WaltLines` |
| `radio_voice` | sanidade < 40, cooldown 600 s, peso 0,25; prenúncio fixo da N8 | o estranho (voz "radio") | "Radio: ..." | `Effects/RadioVoice.luau` `LINES` |

Cada jogador ouve **0 a ~3** falas por noite, só no client dele. Por isso: **toda fala é uma dica útil e esconde uma peça da lore**. Quem não ouve nada perde só a peça, nunca a regra (a regra vem da ligação real da noite).

---

## 1. Lore atual (resumo)

- A esquina é um **cruzamento**; à noite o **late crowd** passa por ali e quer luz, gente e cheiro de comida.
- Existe um **acordo** antigo: luz acesa + comida servida com educação = madrugada educada. As regras do Walt são esse acordo.
- **Walt** fez o turno da noite de **1979** até ficar velho; o negócio de dia serve para achar quem "repara nas coisas".
- Walt **nunca vai ao trailer/loja à noite**: o late crowd conhece o rosto dele. Assiste do Mart.
- Final A1: Hush, sol às 6:00, Walt sai com **dois cafés**, 9 falas calorosas, oferece o turno. "Morning, Marigold." Pós-créditos: panfleto "NIGHT SHIFT — NOW HIRING".
- Nunca explicado: o que é o late crowd, **quem fez o acordo**, quem é a Raincoat Lady.

O que ficou solto (e que esta proposta amarra):

| Ponta solta | Onde aparece |
|---|---|
| "Rookie? It's me. It's Walt. Open up." — a batida usa a voz dele | ANM-009, `anomalies-v3-restaurant.md` §8.3 |
| "I've got a key. I never knock." — a chave | `BossCalls` N2 (restaurante), `WaltLines` |
| o vulto da batida usa o **boné do Walt** | §8.3 (só nas câmeras) |
| "Two coffees tonight? Oh — never mind. Habit." | Opal, noites 4–6 |
| foto de 1979 com uma capa amarela ao fundo | trailer, `ending.md` §3 |
| crachá "WALT — NIGHT SHIFT" | gaveta |
| "Nobody's made it to ten since... well." | ligação N10 (`ending.md` §3) |
| "Nobody's called about that one in years." | abertura |
| quem fez o acordo | `world.md` §6 (nunca explicado) |
| o estranho do rádio ("...don't wait up for me...") | sem dono na lore |

---

## 2. Conflitos com decisões

| Ponto da proposta | Bate com | Gravidade | Saída |
|---|---|---|---|
| Walt é o vilão | DEC-075 (A1: tom final "caloroso + mistério"), `ending.md` §1 | alta | opções A/B/C abaixo; A não toca no aprovado |
| Walt fez o acordo | `world.md` §6: "quem fez o acordo" nunca é explicado | média | A e C só **insinuam** (rádio), nunca dizem; B deixa implícito |
| Walt "gosta de verdade do jogador, se sente culpado" | CHR-001 Motivação (Rascunho) | média | A/C: continua verdade na superfície; B: reescrever CHR-001 |
| O vilão aparece em pessoa | DEC-076 (só telefone até o fim) | nenhuma | as falas novas são telefone/rádio; em pessoa só no amanhecer N10, como aprovado |
| Regras novas | DEC-008, regra de jogo | nenhuma | nenhuma fala cria verbo, regra ou penalidade |
| Final no Mart | `ending.md` §2.1 (correr ao letreiro do Mart) vs restaurante (DEC-307; Hush = apagar a luz da loja, "sem Mart no mapa") | **média, já existe** | fora deste doc; registrar `Q-` para adaptar o palco do final ao restaurante |
| `WaltLines` atual "If it won't leave, **kill** the lights." | `world.md` §1 (palavra proibida *kill*) | alta (texto já no código) | trocar por "Won't leave? Shop light off." (ver §4 Default) |
| `BossCalls` N10 "Lamps **dying**..." / `script.md` "The lamps may **die**." | `world.md` §1 (*die*) | baixa, já existe | sugerir "Lamps going out?" na próxima revisão de `ui-text.md` |

**Opções para o dono** (pergunta em lote):

| | A. Releitura (**recomendada, Provisória**) | B. Emenda do final | C. Walt ambíguo |
|---|---|---|---|
| O que muda no final aprovado | nada nas 9 falas; +1 plano mudo no pós-créditos | +1 a 3 falas/planos que revelam claro | nada; +1 plano mudo |
| Walt é vilão? | sim, para quem juntou as peças; quem não ouviu vê o final caloroso | sim, para todos | talvez: fez uma escolha egoísta e se arrepende |
| Precisa DEC? | não para as falas de alucinação; o plano do pós-créditos entra Provisório (DEC na próxima rodada) | **sim**, nova DEC emendando DEC-075 | não (plano Provisório) |
| Risco infantojuvenil | baixo | médio (o herói "ganha" um final triste) | baixo |
| Custo | só texto + voz | texto + voz + 1–3 planos | texto + voz + 1 plano |

**Recomendação (Provisória): A.** Entrega o vilão como easter egg, que é o pedido ("plot de easter egg"), sem tocar no aprovado. As 9 falas aprovadas já soam sinistras na releitura ("That's the deal", "If you want it", dois cafés). Se o dono quiser o vilão explícito para todos, B está pronto (§5) e vira DEC.

---

## 3. Arco proposto: a verdade escondida nova (bíblia)

Não aparece inteira no jogo. Serve para manter as falas coerentes.

- **1979.** Walt era o Rookie da noite. Fez as dez noites. Na 10ª manhã, o acordo pediu o que pede sempre: **quem chega a dez fica com o turno** — "takes the shift" e passa a guardar a luz **do outro lado**, na noite, sem voltar para o dia.
- **Walt não quis ficar.** Foi ele que mudou o acordo (é a resposta escondida para "quem fez o acordo"; nunca dita, só insinuada pelo rádio): "eu trago outro no meu lugar". Desde então, o negócio de dia e o panfleto existem para isso. O turno da noite que ele "fez por 40 anos" é, na verdade, **40 anos achando Rookies**.
- **Por que precisa de um Rookie:** cada um que fecha as dez noites e aceita o café **fica do outro lado**. Enquanto houver alguém lá, a dívida do Walt está paga e ele envelhece de dia, em paz. Quando aquele Rookie "vai sumindo" (vira parte do late crowd), Walt precisa do próximo. "Nobody's made it to ten since... well." = o último chegou a dez. E ficou.
- **Os dois cafés:** todo 10º amanhecer Walt leva dois cafés: um para ele, um para quem vai ficar. Opal já serviu o segundo muitas vezes. "Habit."
- **O estranho do rádio:** é **o último Rookie**. Ficou do outro lado; a única coisa que passa é a voz, pelo alto-falante do drive-thru/rádio, quando a cabeça do jogador está cansada (sanidade baixa). Ajuda com dicas certas e, noite a noite, tenta avisar. Sem nome no jogo.
- **O boné no vulto da batida:** na 10ª manhã Walt dá o **boné velho do uniforme** a quem fica (o crachá ele guarda). O vulto que bate usa esse boné: é o late crowd copiando o último Rookie — e o last Rookie copiando a única voz em que confiou, a do Walt. Por isso "It's me. It's Walt." Abrir continua errado: a noite não volta para dentro.
- **Ter a chave:** só o Walt tem a chave da porta dos fundos. O Rookie **nunca** ganha uma. Na superfície, é segurança ("I never knock"). Por baixo: quem tem a chave decide quem fica do lado de fora.
- **Por que Walt nunca vem à noite:** o late crowd conhece o rosto dele porque ele **deve** a eles. Se pisar fora da luz à noite, a dívida volta para ele. Ele assiste de dentro da luz que nunca apaga.
- **As ligações falsas:** são o Walt de verdade, numa linha "fora do horário", quando o Rookie está cansado. As dicas são certas (ele precisa que o Rookie chegue a dez). O carinho também é meio verdade. É isso que o torna vilão: ele ajuda **para** entregar.
- **Fica sem explicação:** o que é o late crowd, de onde vem, quem é a Raincoat Lady (só se sabe que ela estava lá em 1979 e "lembra"). Gancho de atualizações mantido.

Palavras da lore: *gone, stayed, kept, took the shift, the other side, faded*. Nunca morte, nunca violência.

---

## 4. Falas por noite

Legenda: **W** = `fake_call` (Walt), **R** = `radio` (o estranho). Dica = qual anomalia da Noite-assinatura (`horror-cinematic.md` §10.2) ou do eco ela ajuda, dita igual à ligação real do restaurante (`BossCalls`, variante restaurante).
Walt: simpático, curto, "Rookie", "heh". O rádio: reticências, voz fraca; mais claro e urgente noite a noite.

| Noite | O que revela | Canal | Fala | Dica embutida? | Pista de lore |
|---|---|---|---|---|---|
| 1 | nada claro; "já houve outros" | W | "Blank face? Window shut. I've taught plenty." | sim, ANM-001 | "plenty": onde estão os outros Rookies? |
| | | W | "First night's easy, Rookie. Heh. Mostly." | não (calma) | ele já viu muitas primeiras noites |
| | | R | "...hello...? Is the light still on over there...?" | não | alguém do outro lado procura a luz |
| 2 | a chave; o rádio já trabalhou aqui | W | "I've got a key, Rookie. I never knock." | sim, ANM-009 | a chave (só ele tem) |
| | | W | "Shaky one's just hungry. Feed him plain." | sim, tremedor (estreia da ligação N2) | — |
| | | R | "...lock it... I never had a key either..." | sim, ANM-009 | "either": o rádio foi Rookie |
| 3 | o rádio fez as mesmas regras | W | "Lights out? Breaker. Hold it. Don't let go." | sim, ANM-020 | "don't let go": ele também não solta |
| | | W | "Keep that light on. It's all they want. Heh." | sim, ANM-020 / Hush | "they": ele sabe o que querem |
| | | R | "...hold the breaker... I counted too, back then..." | sim, ANM-020 | "back then": outro turno, outro Rookie |
| 4 | o late crowd conhece o rosto do Walt | W | "Head on backwards? Window. Don't stare." | sim, ANM-012 | — |
| | | W | "Who are they? ...Next question. Window shut." | sim, ANM-012 / ANM-001 | eco do "Next question.": ele sabe |
| | | R | "...don't stare... they learn faces... like his..." | sim, pressão de encarar | "like his": conhecem o rosto do Walt |
| 5 | Marigold estava lá; o rádio esperou por ela | W | "Yellow raincoat? Serve her. Old friend." | sim, ANM-005 | "old friend": a foto de 1979 |
| | | W | "Someone just standing there? Eyes down." | sim, ANM-006 | — |
| | | R | "...serve the lady... she waited for me too..." | sim, ANM-005 | o rádio também viveu a N5 |
| 6 | o segundo café | W | "Red out there? Stay in. Opal's pouring two." | sim, ANM-021 | dois cafés, de novo |
| | | W | "I can see your window from here. Good work." | sim, eco ANM-006 (fique dentro) | ele assiste; de onde? |
| | | R | "...stay inside... the second coffee was mine once..." | sim, ANM-021 | o 2º café era do último Rookie |
| 7 | o "último" Rookie; o panfleto | W | "Feet off the floor. The last one forgot." | sim, ANM-017 | "the last one": existiu um antes |
| | | W | "You're better than the last one. Much better." | não | comparação: ele mede Rookies |
| | | R | "...get up high... he sent me the flyer too..." | sim, ANM-017 | o panfleto é isca antiga |
| 8 | o carro procura o Walt; ele mandou outro no lugar | W | "Long car? Keep it shut. It's not here for me." | sim, ANM-008 | negação estranha |
| | | W | "Window shut till the brights go. Good Rookie." | sim, ANM-008 | — |
| | | R | "...keep the window shut... don't let it see you..." | sim, ANM-008 | — |
| | | R | "...it came for Walt once... he sent me instead..." | não | primeira vez que o rádio diz "Walt" |
| 9 | o boné; o café é a armadilha | W | "Steps up top? Don't look up. Trust me." | sim, ANM-019 | "trust me" |
| | | W | "My old cap out back? Lock the door. Next question." | sim, ANM-009 | o boné do vulto é dele |
| | | R | "...the cap... he gave it to me on my tenth morning..." | não | o boné vai para quem fica |
| | | R | "...don't look up... and don't take his coffee..." | sim, ANM-019 | o café = aceitar o turno |
| 10 | tudo, menos o "porquê" do late crowd | W | "Lamps going out? Shop light off. Keep it off." | sim, ANM-010 | — |
| | | W | "Almost morning. I'll bring the coffee myself." | não | ele vem, com dois cafés |
| | | R | "...it's me... the last Rookie... I took the shift..." | não | quem é o rádio |
| | | R | "...lights off... at sunrise he'll offer you the shift..." | sim, ANM-010 | prevê a fala 9 do final aprovado |

Notas:
- N2 tem `fake_call` como prenúncio fixo e N8 tem `radio_voice`: são as falas mais prováveis de serem ouvidas. Por isso a chave (N2) e o "it came for Walt" (N8) estão nelas.
- Na N1 a sanidade raramente cai abaixo de 60/40: as falas da N1 são extras, nada essencial.
- Nenhuma fala de rádio dá ordem nova. "Don't take his coffee" não vira escolha: o final aprovado não tem botão; o café é oferecido igual.

### 4.1 Default (noite sem entrada, noites > 10, modo infinito)

Só dicas gerais + ecos de lore já revelada. Sem spoiler novo.

| Canal | Fala | Dica |
|---|---|---|
| W | "Same rules, Rookie. Window, breaker, eyes down." | geral |
| W | "Knocks? Not me. I've got the key." | ANM-009 |
| W | "Don't stare at them too long." | ANM-012 / ANM-006 |
| W | "Won't leave? Shop light off." | substitui a fala com *kill* |
| W | "Keep the light on. I'm watching. Heh." | geral |
| W | "Don't wait for me, Rookie." | — |
| R | "...anyone still open out there...?" | — |
| R | "...is the grill still on...?" | — |
| R | "...keep the window shut..." | família A / ANM-008 |
| R | "...don't wait up for me..." | — |
| R | "...still on the other side... still keeping it lit..." | — |

A fala atual "No head? Better not even look." sai do Default: nenhuma ligação real da noite fala de "no head" (risco de contradizer a regra).

---

## 5. Final N10 sem mudar regra de jogo

Nenhuma opção cria verbo, regra, penalidade ou escolha. Só texto, planos e falas. Hush, sol às 6:00 e as 9 falas aprovadas seguem iguais. O palco (Mart vs restaurante) segue o que vier da `Q-` do §2.

| Opção | O que entra | Texto |
|---|---|---|
| **A** (releitura) | 1 plano mudo no pós-créditos: a câmera desce no poste; atrás do panfleto novo "NOW HIRING" aparecem **vários panfletos velhos iguais**, amarelados, um por cima do outro. Nenhuma fala nova. | panfleto aprovado, igual |
| **B** (emenda, precisa DEC) | (1) Depois de "Morning, Marigold.", Walt vira as costas, sozinho no sol, e diz baixinho: **"Forty years of nights. Now I get the mornings."** (2) Chiado no alto-falante; legenda **"Radio: ...welcome to the other side, Rookie..."** (3) o plano dos panfletos velhos da opção A. A Raincoat Lady **não** acena para Walt dessa vez: fecha o guarda-chuva e olha para o Rookie. | 2 falas novas (≤ 60 car.) + 2 planos |
| **C** (ambíguo) | 1 plano pós-créditos: noite seguinte, janela do Mart; Walt sentado com **dois cafés**, um intocado. Nenhuma fala. | nenhuma fala nova |

Leitura de cada uma:
- **A:** quem nunca ouviu o rádio vê o final caloroso aprovado. Quem juntou as peças entende: os dois cafés, "That's the deal", "If you want it", o boné, a chave, a pilha de panfletos.
- **B:** todo mundo entende que Walt trocou o próprio turno pelo do Rookie. "Quem fez o acordo" continua não dito em palavras.
- **C:** Walt fez algo egoísta e sente o peso. Nem herói, nem vilão.

---

## 6. Critérios de aceite

- Nenhuma fala usa palavra proibida de `world.md` §1 (*die, dead, death, kill, blood, hurt, injured, gun, shoot, weapon, monster, demon, corpse, body*), nem "dying".
- Cada fala tem **≤ 60 caracteres** (contando reticências).
- **Uma fala por evento** (`fake_call` ou `radio_voice`); nunca duas seguidas no mesmo evento.
- Toda dica repete a regra **igual** à ligação real da noite (variante restaurante de `BossCalls`): "Window shut", "Breaker. Hold it.", "Don't open", "Don't look up", "Up on the counter", "Keep it shut", "Shop light off". Nenhuma contradiz.
- Nenhuma fala de noite N revela peça de noite > N.
- Quem não ouviu nenhuma fala entende o final aprovado sem lacuna (tudo aqui é extra).
- Nenhuma fala cria regra, verbo, escolha ou penalidade.
- O rádio nunca diz o nome do último Rookie; ninguém explica o late crowd nem a Raincoat Lady.
- Walt só por telefone até o amanhecer da N10 (DEC-076).
- Toda fala nova tem voz pré-gerada antes de entrar em `ui-text.md` (sem voz = só texto, aceitável como fallback).

---

## 7. Formato de dado sugerido (para a TASK; sem código aqui)

- Em `Content/Hallucinations.luau`: `WaltLines = { [night] = { Line } , Default = { Line } }`.
- `RadioLines` no mesmo módulo (sai de `RadioVoice.luau` `LINES`), mesmo formato.
- `Line = { Id: string, Text: string }`. `Id` estável, ex. `walt_n2_key`, `radio_n8_instead`. O `Id` serve para "ouvida" e para a voz.
- **Escolha** a cada evento, na noite N:
  1. falas da noite N ainda não ouvidas, na ordem da tabela;
  2. se acabaram: falas não ouvidas de noites < N (nunca > N);
  3. se acabaram: aleatória do `Default`.
  Noite > 10 e modo infinito: direto para o passo 2, depois `Default`.
- **"Ouvida"**: duas opções para o architect.
  - **Por run** (só memória do client; simples): a mesma run não repete; runs novas recomeçam a série.
  - **Por perfil** (recomendada, Provisória): um conjunto pequeno de `Id` no dado salvo; o jogador junta a lore ao longo de várias runs. Custo: campo novo no perfil.
- Cada fala nova precisa voz gerada em `tools/voice`: falas **W** com a voz do Walt, falas **R** com a voz "radio". Chave do arquivo de voz = `Id`.
- Texto final vai para `ui-text.md` depois de aprovado; até lá, placeholders em inglês como hoje.
