Status: Rascunho (game-designer, 2026-10-22). Todos os números são Provisórios até o Play do dono. **Parcialmente aplicado
no código em 2026-10-22 (Provisório, sem DEC), na versão do dono "sem ACCEPT/REFUSE": ver §9.** As §1–§8 continuam a
proposta original (ainda falam em ACCEPT/REFUSE); onde divergem, vale a §9.

# Anomalias de cliente: o ACCEPT nunca é o erro

Pedido do dono (2026-10-22): todo cliente passa pela conversa (oi → ACCEPT/REFUSE → pedido). O tique da conversa só
deixa uma **pista**. Depois do aceite, cada anomalia tem uma **condição** que o jogador precisa perceber e cumprir, ou
uma **saída**. O erro acontece **depois**, em outro contexto: na entrega, ou por não cumprir a condição. Algumas são só
**atenção**: esquisitas, mas inofensivas se feitas do jeito certo ("a anomalia que sacode, ele só quer um
cachorro-quente normal... não é exatamente um erro, mas aumenta a atenção").

Dois problemas que esta proposta resolve:

1. **A chegada entrega a anomalia** (sussurros + barras de cinema em toda chegada de cliente esquisito). §4.
2. **Recusar não custa nada**: recusar tudo (ou fechar a janela) é a estratégia ótima. §5.

Base: DEC-254 (famílias), DEC-255/DEC-277 (erro = jumpscare + −35 de sanidade), DEC-256 (jumpscare cartoon, Mild),
DEC-278 (anomalia não se confunde com o fluxo), DEC-352 (escada de sanidade), DEC-353 (diálogo ACCEPT/REFUSE),
`anomaly-tics-proposal.md` (tiques; piloto 012 e 013/004/014 no código), `anomalies-v2-proposal.md`,
`gameplay-flow-review.md` §4.1, `economy.md` §5.0, `Q-445`..`Q-448`, `Q-451`, `Q-455`, `Q-456`, `Q-460`..`Q-465`.
Estilo: crescendo curto até o clímax na **entrega**, silêncio antes do pico, respiração, uma tarefa simples sob nervos.

---

## 1. O princípio e o loop novo

### 1.1 Cinco regras

1. **ACCEPT nunca dá susto.** Aceitar só anota o pedido (a anomalia também faz um pedido).
2. **O susto só acontece na entrega ou quando a condição falha.** É sempre consequência de uma ação depois do aceite
   (entregar do jeito errado) ou de uma condição que o jogador deixou estourar (cabeça que encosta no vidro).
3. **REFUSE nunca dá susto.** Recusar uma anomalia não custa nada (exceto as duas que querem ser servidas, §2.10 e §2.11,
   que custam pouco e sem jumpscare). Recusar um **cliente normal** custa (§5).
4. **Toda anomalia tem uma saída segura depois do aceite**: não entregar (ela vai embora sozinha) ou fechar a janela
   (ela vai embora; a fila normal também, com o custo do §5).
5. **Atendida certo, a anomalia paga** (×2 o preço, §5.5). Aceitar sabendo que é anomalia passa a ser uma aposta com
   prêmio, não um erro de leitura.

### 1.2 O loop

| Etapa | O que o jogador vê | O que pode dar errado | Tela (camadas) |
|---|---|---|---|
| **Chegada** | um cliente andando até a fila; pista sutil no corpo (às vezes); nas **câmeras** o corpo verdadeiro | nada | **nenhuma** camada de tela (§4) |
| **Conversa** | close; "oi"; **tique** (pista, às vezes ausente, §1.4) | nada (sair do diálogo é seguro, como hoje) | só as do tique, só de quem atende |
| **Escolha** | ACCEPT / REFUSE | REFUSE num cliente normal = reclamação (§5) | — |
| **Pedido** | a anomalia **faz um pedido** (normal, especial, igual ao de outro ou em branco) | — | — |
| **Condição** | o comportamento da anomalia enquanto espera (cabeça que segue, cabeça que cresce, batidas) | condição estourada = susto | crescendo **só** na borda da falha e na entrega (§4.4) |
| **Entrega / saída** | entrega certa = paga e vai embora; saída = vai embora sem pagar | entrega errada = jumpscare + −35 (Erro) ou prato devolvido (Atenção) | silêncio 0,4 s + respiração no instante da entrega (só anomalia, só quem entrega) |

### 1.3 As condições (poucas respostas, muitas aparências)

Sete tipos de condição para onze anomalias. Cada uma cabe numa frase que o Walt diz na estreia.

| Tipo (`Condition.Kind`) | Frase do Walt (rascunho, narrative-writer revisa) | Anomalias | Erro ou Atenção |
|---|---|---|---|
| `NoServe` | "Blank ticket, twin ticket, nothing on the camera? Don't cook it. It'll leave." | 001, 004, 023 | Erro |
| `NoLook` | "If one won't face you, don't look at her when you hand it over." | 012 | Erro |
| `Dark` | "Eyes that glow? Kill the lights, then serve." | 013 | Erro |
| `Hurry` | "If it's growing, or knocking, be quick. Or shut the window." | 014, 022 | Erro |
| `Grounded` | "If its feet aren't on the floor, wait for the thud." | 015 | Erro |
| `Plain` | "The shaky ones? Just bread. Nothing on it." | 011 | Atenção |
| `Serve` | "Some of them just want to be served. Be nice." | 005, 016 | Atenção |

### 1.4 Quanto o tique revela (para o aceite continuar fazendo sentido)

| Regra | Valor (Provisório) |
|---|---|
| Noite de estreia da anomalia | tique **sempre** (ensina) |
| Noites seguintes | tique completo 75 %; **sem tique** 25 % (fala "quase normal" e só) — sorteio do servidor com semente do `NpcId` |
| Noites 7–10 | sem mudança (75 / 25); a fala "Almost" já é mais difícil |
| Cliente normal | nunca tem tique; pode ter uma **pista falsa** (§4.5) |

Com isso, ~1 em 4 anomalias passa pela conversa sem sinal claro e só se revela pela condição, depois do aceite. As
câmeras continuam sendo o **canal da verdade** para quem desconfiar (a anomalia sempre aparece errada nas câmeras;
cliente normal nunca).

### 1.5 Como o jogador aprende

| Canal | Quando | O que diz |
|---|---|---|
| **Ligação do Walt** | começo da noite de estreia | a **condição** em uma frase (§1.3), não a aparência. Uma condição nova por noite no máximo (as estreias de `gameplay-flow-review.md` §3b já respeitam: 2 estreias por noite, condições diferentes) |
| **Bilhete no ticket** | só na **primeira** vez que o jogador aceita aquela anomalia (por perfil, `profile.Journal`) | o ticket do pedido na tela da retirada sai com um rabisco do Walt: "don't look at her. –W" (diegético; some depois da primeira vez) |
| **Anomaly Tablet** (`Content.Journal`) | a página destrava na primeira ocorrência, como hoje | `Signs` = pista sutil + câmeras; `Fight` vira **"When you serve"** (a condição) + **"Way out"** (a saída) |
| **Cartão de erro** (`Q-448` c) | ~1 s depois do jumpscare | "WRONG MOVE · The turned neck → don't look at her when you serve". Atenção: sem cartão; um balão curto do cliente ("...just bread.") |
| **Reclamação** | a cada cliente normal mandado embora (§5) | balão de reclamação (já existe) + contador "Complaints 2/2" no canto do dinheiro por 3 s |

---

## 2. Fichas por anomalia da fila

Legenda. **Chegada** = sinal antes da conversa, a olho nu (sutil) e nas câmeras. **Tique** = o que acontece no close
(`anomaly-tics-proposal.md`; "no código" = já aplicado). **Pedido** = o que ela pede depois do ACCEPT. **Condição** = o
que o jogador precisa perceber e cumprir. **Saída** = como ela vai embora sem pagar e sem susto. **Erro** = contexto e
consequência. **Espera** = paciência dela depois do aceite. Toda anomalia: REFUSE no diálogo = vai embora, sem custo
(salvo indicado); fechar a janela = vai embora (fila normal paga §5).

### 2.1 ANM-012 Pescoço invertido — PILOTO (Erro, `NoLook`)

| Campo | Valor |
|---|---|
| Estreia | N4 |
| Chegada | cabeça para frente; repuxão de 6° a cada 5–8 s com estalinho 0,15 (já no código, `Q-459` a). Câmeras: cabeça virada, girando devagar (já no código) |
| Tique | no código: fala congela, 3 estalos, ela termina de costas |
| Pedido | de costas: "...one hot dog. Please." (pedido normal sorteado, K 0–3) |
| Condição | ela espera **de corpo para a rua e a cabeça virada para dentro**; a cabeça **segue o jogador mais próximo** pela cozinha (≤ 20 studs, ±80°, o `TicFollow` que já existe). **Entregue sem olhar o rosto dela**: no instante do Serve, o rosto dela não pode estar no cone de visão de quem entrega (cone = `Sanity.SeeAngle`, linha de visada; o mesmo `Vision` do ANM-019). Olhar para a bandeja/balcão serve |
| Como perceber | quem olha o rosto dela por ≥ 0,6 s sente o `Stare` (coração, borda) — reaproveita TASK-482, **só depois do aceite** |
| Entrega certa | ela pega o prato sem virar, paga ×2, sai andando com a cabeça olhando para trás até o fade |
| Saída | não entregar: depois da **Espera** ela vai embora com a cabeça virada; janela fechada: `window_slam` atual (TASK-336) |
| Erro | entregou olhando: silêncio 0,4 s, ela **vira o corpo inteiro** para o rosto (o `neck_snap`), jumpscare (o rosto de cabeça para baixo), −35 de quem entregou |
| Espera | 75 + 5K s (igual ao cliente normal; não vaza) |
| Custo | **P/M**: gaze no Serve (o `Vision` existe), Talking da anomalia, fase `Accepted` (§6) |

### 2.2 ANM-013 Olhos brancos (Erro, `Dark`)

| Campo | Valor |
|---|---|
| Estreia | N5 |
| Chegada | olhos normais com brilho frio que não segue a luz (já no código); câmeras: olhos brancos (já) |
| Tique | no código: piscada, abre com os olhos brancos, luz fria no rosto do jogador |
| Pedido | "Extra warm." (pedido normal) |
| Condição | **entregue com a luz da loja apagada** (`Light.IsSwitchOn == false` no instante do Serve). A tarefa: ir ao interruptor, apagar, entregar no escuro, acender de novo |
| Como perceber | enquanto ela espera, os olhos dela **ficam mais fortes quando a luz está acesa** (ela aperta os olhos, a luz fria pisca no balcão a cada 6 s). Com a luz apagada, os olhos dela são a única luz no balcão (o `Lantern Eyes` em Q1 que saiu da cena volta aqui, na fase `Accepted`) e os outros clientes **viram a cabeça para o jogador** (o `Pose Turn` da cena, movido para cá) |
| Entrega certa | no escuro, uma mão pega o prato; os olhos se afastam e apagam; paga ×2 |
| Saída | não entregar / janela |
| Erro | entregou com a luz acesa: silêncio, a luz da loja estoura (flicker 0,3 s), jumpscare (os olhos brancos em tela cheia), −35 |
| Espera | 75 + 5K s |
| Conflitos | `Q-445` recomendava "LUZ = sempre religar, nunca apagar"; o queimar da lâmpada (`Content.Bulb.Toggles`) não pode disparar com o ciclo apagar/acender (2 trocas). Ver `Q-471` |
| Custo | **P**: leitura de `IsSwitchOn` no Serve (o rule da 022 já lê) |

### 2.3 ANM-014 Cabeça grande (Erro, `Hurry` por costas)

| Campo | Valor |
|---|---|
| Estreia | N6 |
| Chegada | cabeça ×1 (já no código, `Q-461`); câmeras ×2,6 (já) |
| Tique | no código: dois degraus ×1 → ×1,45 → ×1,9 |
| Pedido | normal |
| Condição | depois do aceite a cabeça **cresce um degrau** (a) **cada vez que um jogador dentro da loja fica de costas para ela** (câmera > 110° dela, ≥ 1,5 s; reaproveita o teste de `Behind`), no máximo 1 degrau a cada 6 s, e (b) a cada **25 s** de qualquer jeito. Degraus: ×1,9 → ×2,2 → ×2,5 → ×2,8. **No 4º degrau ela encosta no vidro** (falha). Entregue antes |
| Como perceber | rangido de couro a cada degrau (`door_creak` até `stretch_creak` ter Id), a luminária balança no 2º degrau (`Prop Sway`, volta da cena), no 3º degrau começa o crescendo de borda (§4.4: coração + palavras "DON'T TURN AROUND") |
| Entrega certa | a cabeça murcha com um chiado, ela paga ×2 e vai |
| Saída | não entregar até antes do 4º degrau é impossível na maioria dos pedidos; a saída real é **fechar a janela** antes do 4º degrau (ela bate a testa uma vez na persiana e vai) ou REFUSE na conversa |
| Erro | 4º degrau: a cabeça pressiona o vidro, o vidro range, silêncio 0,5 s, jumpscare, −35 em **quem estava de costas por último** (ou quem aceitou, se ninguém) |
| Conta | pedido K2 ≈ 30 s solo: 1 degrau por tempo + 1–2 por costas = 2–3 → passa no limite. Tensão sem ser injusto |
| Custo | **M**: degraus por evento (hoje os degraus são do tique), teste de costas no servidor |

### 2.4 ANM-004 A cópia (Erro, `NoServe`)

| Campo | Valor |
|---|---|
| Estreia | N3 |
| Chegada | **sem** a roupa espelhada + olhos brancos de hoje (gritante). Novo: mesma roupa do original (a pista é perceber os "gêmeos"), olhos normais; chega até 2 clientes depois do original. Câmeras: **ela não aparece** (já na cena, `Pose Scale` 0,01 `Seen = "Cameras"`) |
| Tique | no código: o eco da fala do original + o "oi" do jogador com o nome |
| Pedido | **o mesmo pedido do original**, item por item, na mesma ordem. A tela da retirada mostra dois tickets iguais |
| Condição | **não cozinhe para ela**. Enquanto espera, a cabeça imita a câmera do jogador com atraso (`Pose Mimic`, já existe) e, se o original ainda está na loja, os dois olham para o jogador ao mesmo tempo |
| Saída | não entregar: depois de **45 s** ela vai embora **sorrindo** (`mirror_smile` + `copy_vanish`, já existem); fechar a janela: idem |
| Erro | entregou: ela segura o prato, silêncio, "Which one of us did you feed?" (legenda), o original (se presente) vira a cabeça; jumpscare, −35 |
| Pista falsa natural | dois clientes normais com o mesmo pedido acontecem (~5–8 % por par): a câmera desempata |
| Custo | **P**: ticket = cópia do ticket do original (o servidor já tem `CopyOf`), espera curta |

### 2.5 ANM-011 O que treme (Atenção, `Plain`)

| Campo | Valor |
|---|---|
| Estreia | N2 |
| Chegada | um **inquieto**, não um tremor: bate o pé, esfrega as mãos (o tremor de corpo inteiro de hoje sai da chegada). Câmeras: tremendo forte |
| Tique | fala embolada com o rosto tremendo; para tudo e diz baixo "...just bread." (`anomaly-tics-proposal.md` §3.9, não aplicado) |
| Pedido | ticket **PLAIN** (pão + salsicha, nada em cima; já existe, `Variant "shake"`) |
| Condição | **entregue puro** |
| Como perceber | enquanto espera, o balcão chacoalha perto dele (os `Prop Shake/Sway` da cena, movidos para `Accepted`) |
| Entrega certa | para de tremer de uma vez, suspira, paga ×1 (não é aposta) + gorjeta $1 |
| Erro (atenção) | 1ª entrega com cobertura: **devolve o prato** (bate no balcão, `Prop Shake` forte, sem susto, sem sanidade; o prato é perdido, ~$2,6 de ingrediente) e continua esperando. 2ª: vai embora tremendo, a luz pisca, −5 de quem entregou. **Nunca jumpscare**. **Refeito em 2026-10-22: §9.9** (arremesso na parede, −15 / −5) |
| Saída | não entregar / janela / REFUSE: vai embora tremendo, sem custo |
| Decisão | substitui `Q-446` (a). Fica a ideia da (a) de "JUST THE BUN" como pedido raro de cliente normal (pista falsa, §4.5) |
| Custo | **P**: troca o fail de `WrongServeFails` por devolução |

### 2.6 ANM-001 Sem rosto (Erro, `NoServe`)

| Campo | Valor |
|---|---|
| Estreia | N1 (a lição da noite) |
| Chegada | **N1**: cabeça lisa desde a chegada (é a primeira anomalia do jogo; ensina "olhe as pessoas"). **N2+**: rosto normal que não pisca (`HoldStill`); câmeras: cabeça lisa |
| Tique | N1–3: "..." com a cabeça inclinando (§3.2 dos tiques); N4+: o rosto que apaga |
| Pedido | "..." — o ticket sai **em branco** |
| Condição | **ticket em branco = não cozinhe** |
| Saída | 45 s depois ela vai embora inclinando a cabeça; janela idem |
| Erro | entregou qualquer coisa: uma **boca se abre** onde não havia rosto; jumpscare, −35 |
| Custo | **P** (ticket vazio na retirada) |

### 2.7 ANM-015 Flutuando (Erro, `Grounded`)

| Campo | Valor |
|---|---|
| Estreia | N7 |
| Chegada | flutua 0,15 stud (hoje 0,7) e **não tem passos**; câmeras: 6 studs acima, cabeça para trás (já na cena) |
| Tique | sobe +1,2 stud durante a fala e cai com baque (§3.5 dos tiques, não aplicado) |
| Pedido | normal |
| Condição | depois do aceite ela entra num **ciclo de 11 s**: sobe devagar 5 s (até 1,2 stud), paira 2 s, **cai com um baque** e fica **no chão 4 s**. **Entregue enquanto ela está no chão** |
| Como perceber | zumbido que sobe com ela e corta no baque (`HUM` da cena); os guardanapos sobem junto (`Prop Float`) |
| Entrega certa | paga ×2 e sai andando, agora com passos |
| Erro | entregou flutuando: a câmera de quem entrega **sobe junto** 1 s (o chão some), silêncio, jumpscare, −35 |
| Saída | não entregar / janela |
| Custo | **M**: ciclo replicado (1 atributo de fase com hora do servidor) |

### 2.8 ANM-022 O que bate a cabeça (Erro, `Hurry` por tempo)

| Campo | Valor |
|---|---|
| Estreia | N8 |
| Chegada | cabeça pendendo um pouco (hoje bem baixa); câmeras: cabeça virada para a lente (já) |
| Tique | ergue a cabeça e bate a testa no balcão uma vez (§3.10 dos tiques, não aplicado). A fala "...light... too bright..." **sai** (a luz agora é da 013) → "...hurry... hurry..." |
| Pedido | normal |
| Condição | depois do aceite **bate a testa no balcão a cada 4 s** (cada batida: baque, `Jolt` só para quem está ≤ 12 studs, a lâmpada pisca). Da 8ª batida em diante a cada 3 s. **Na 12ª batida (≈ 44 s) o vidro trinca** = falha. Entregue antes |
| Como perceber | o relógio é audível; da 9ª batida em diante entra o crescendo de borda (§4.4) |
| Entrega certa | para de bater, paga ×2, sai segurando a testa |
| Saída | **fechar a janela**: bate 3× na persiana (`head_bang`, já existe) e vai embora. Apagar a luz deixa de importar (`Q-447` b) |
| Erro | 12ª batida: o vidro trinca, silêncio, jumpscare, −35 em quem aceitou |
| Custo | **P**: o rule já tem `BangEvery`/`BangRamp`; muda o alvo (balcão, depois do aceite) |

### 2.9 ANM-023 A da câmera (Erro, `NoServe` + câmera)

| Campo | Valor |
|---|---|
| Estreia | N10 |
| Chegada | normal pessoalmente; quebrada na CAM3 (já, `Q-437`) |
| Tique | corte de 0,2 s para a CAM3 (§3.8 dos tiques, não aplicado) |
| Pedido | normal (é a mais traiçoeira) |
| Condição | **olhe-a pelas câmeras**: se qualquer jogador a vê pela CAM3 por ≥ 2 s, ela "sabe que foi vista", a cabeça vira para a lente e ela vai embora (resolvida, sem pagar, sem susto). Ou simplesmente não entregue |
| Saída | não entregar (45 s) / janela / câmera |
| Erro | entregou: o corpo dobra na sua frente (o mesmo `oncam`, agora a olho nu, 0,6 s), jumpscare, −35 |
| Custo | **M**: o servidor precisa saber quem está olhando a CAM3 (hoje a visão de câmera é do client; precisa de um sinal de "olhando a câmera n" já existente ou novo) |

### 2.10 ANM-005 Raincoat Lady (Atenção, `Serve`)

| Campo | Valor |
|---|---|
| Estreia | N5 (só noite seca) |
| Chegada | capa pingando, poça (é a assinatura dela; fica — ela é a "boa"); **sem** barras, sussurros, trovão de chegada |
| Tique | gentil (gotas no cartão), nunca Susto |
| Pedido | normal, falado com carinho |
| Condição | **sirva** (qualquer pedido completo) |
| Entrega certa | paga + $1 extra (NPC-013), a poça seca |
| Erro (atenção) | REFUSE, deixar a paciência acabar ou fechar a janela: ela vai embora chorando na chuva que só cai nela; −5 de quem recusou (ou dividido como §5.2). **Sem jumpscare** (hoje recusar = susto) |
| Custo | **P** |

### 2.11 ANM-016 Não pisca (Atenção, `Serve`)

| Campo | Valor |
|---|---|
| Estreia | N9 |
| Chegada | olha fixo, não pisca (os outros piscam); a cabeça **não** segue a câmera antes da conversa (o `stare` de hoje sai da chegada). Câmeras: cabeça seguindo a lente (já) |
| Tique | o jogador pisca e ele está mais perto (§3.6 dos tiques, não aplicado) |
| Pedido | normal |
| Condição | **sirva normalmente e não o encare enquanto espera**: encarar a cabeça dele aciona o `Stare` (coração + dreno de sanidade de `Sanity.Stare`, já existe) |
| Entrega certa | pisca uma vez, devagar ("finally"), paga ×1 + $1 |
| Erro (atenção) | REFUSE ou deixar ir: ele **não vai embora**; fica 20 s colado no vidro olhando (o `stare_front` existente, sem o apagão) e só depois some. Sem jumpscare |
| Custo | **P** |

### 2.12 Resumo

| ANM | Condição | Tipo | Paga | Jumpscare possível | Saída segura |
|---|---|---|---|---|---|
| 001 | `NoServe` (ticket em branco) | Erro | — | sim, se entregar | não entregar |
| 004 | `NoServe` (ticket gêmeo) | Erro | — | sim, se entregar | não entregar |
| 023 | `NoServe` / câmera | Erro | — | sim, se entregar | câmera / não entregar |
| 012 | `NoLook` | Erro | ×2 | sim | não entregar |
| 013 | `Dark` | Erro | ×2 | sim | não entregar |
| 014 | `Hurry` costas | Erro | ×2 | sim | janela antes do 4º degrau |
| 022 | `Hurry` tempo | Erro | ×2 | sim | janela |
| 015 | `Grounded` | Erro | ×2 | sim | não entregar |
| 011 | `Plain` | Atenção | ×1 + $1 | nunca | qualquer |
| 005 | `Serve` | Atenção | ×1 + $1 | nunca | — (recusar custa −5) |
| 016 | `Serve` | Atenção | ×1 + $1 | nunca | — (recusar = 20 s de olhar) |

---

## 3. A cena depois do aceite (onde vai o crescendo)

A cena de horror de cada anomalia ganha a fase **`Accepted`** (âncora: o instante do ACCEPT, gravado no registro da
anomalia). O que hoje toca na chegada e é **diegético** (corpo, objetos, luz do balcão) muda para `Accepted`. O que é
**tela** (barras, sussurros, borda, cor, coração) só toca em dois momentos:

| Momento | O que toca | Para quem |
|---|---|---|
| **Borda da falha** (014 no 3º degrau; 022 da 9ª batida; 012 quando alguém encara o rosto ≥ 0,6 s; 015 quando alguém segura o prato perto dela flutuando) | coração 70 → 120, borda 0 → 0,22, palavras com a **condição** ("DON'T TURN AROUND", "WAIT FOR THE THUD", "DON'T LOOK AT HER"), barras 0,08 | todos dentro da loja (012: só quem encara) |
| **Entrega (hand-off)** de qualquer anomalia, certa ou errada | silêncio 1 → 0,1 em 0,15 s por 0,4 s + `breath_held`; depois alívio (certa) ou o jumpscare (errada) | só quem entrega |

Isto segue a régua do dono: o pico é a entrega, com silêncio antes; a tarefa (apagar a luz, olhar para baixo, esperar
o baque) é simples e feita sob nervos.

---

## 4. A chegada sem barras e sem sussurros (problema 1)

### 4.1 Diagnóstico

Toda anomalia de cliente roda a cena dela na fase **`Active`** a partir do spawn (`Kit/CustomerActor`: Active = nasceu e
anda até o balcão). Quase todas abrem com sting + tranco + barras (`Cinema` 0,07–0,08 em t = 1 s) + sussurros com
dicas ("DON'T TAKE HER ORDER") + borda + cor + coração. Isso diz "é anomalia" antes de o jogador ver o cliente.
Somam-se: o `Stare` (coração + palavras ao olhar a cabeça) na 004 e 013, e modificadores de corpo fortes desde o
spawn (004 roupa espelhada + olhos brancos, 011 tremor, 015 0,7 stud, 016 cabeça seguindo, 022 cabeça baixa).

### 4.2 Regra nova (data + `Validate`)

Para toda cena cuja chave é de `Content.Anomalies` com `Actor = "Customer"`, na fase **`Active`**:

- **Proibido** (Validate rejeita): `Cinema`, `Whispers`, `Vignette`, `Grade`, `Heartbeat`, `Silence`, `Blur`, `Fov`,
  `Shake`, `Nudge`, `Text`, `Lights`; `Sound` com `horror_sting`, `suspense_drop`, `suspense_hiss`, `hum_die`,
  `thunder`, `lights_off`, `whisper`; qualquer passo `Where = "Outside"` com palavras.
- **Permitido**: `Pose`, `Prop`, `Actor`, `Lantern` com `Seen = "Cameras"` (o canal da verdade); `Pose`/`Prop` a olho
  nu só se a ficha (§2) os lista como **pista sutil**; `Sound` diegético com `Point` e volume ≤ 0,3.
- O resto vai para `Accepted` (diegético + borda da falha, §3), `Resolved` ou `Failed` (ficam como estão).
- `Content.Anomalies`: `Stare = false` na 004 e na 013 **antes do aceite** (o `Stare` passa a ligar só em `Accepted`,
  e só na 012 e 016, onde ele é a condição).

### 4.3 Lista exata de passos a tirar ou mudar (fase `Active`)

`T` = tirar; `→A` = mover para `Accepted` (com o `At` relativo ao aceite); `F` = fica.

| Arquivo (cena) | Passos `Active` | Ação |
|---|---|---|
| `HorrorScenes/init.luau` `oddScene` (molde, fallback) | `Sound` sting 0,3 @0; `Cinema` 0,08 @1 e 0 @9,5; `Vignette` @2 e @9,5; `Whispers` @2,5 e @9,5; `Grade Cold` @2 e @9,5 | T (o molde vira só `Resolved`/`Failed`) |
| `init.luau` `turnedNeck` (ANM-012) | `Cinema` @1,5 / @9,5; `Vignette` @2 / @9,5; `Whispers neck` @2,5 / @9,5; `Grade Cold` @2 / @9,5 | T |
| `Scenes/anm_012_turned_neck.luau` | `Shake Jolt` @0; `Fov −2,5` @0; `Whispers neck_outside` (Outside) @1 / @9,5 | T. `Pose Turn Seen Cameras` @1: F |
| `init.luau` `copies` (ANM-004) | `Sound horror_sting 0,35` @0; `Cinema` @0,5 / @10; `Vignette` @2 / @10; `Whispers copy` @2 / @10; `Grade Cold` @2 / @10 | T |
| `Scenes/anm_004_copies.luau` | `Lights Flicker` @0; `Shake Jolt` @0; `Fov −2` @0; `Silence` @8,5 / @10,5 | T. `Pose Scale 0,01 Seen Cameras` @0: F. `Pose Mimic Seen Eyes` @1,5: →A (só depois do aceite). `Pose Tilt` @8,5: →A |
| `Scenes/anm_013_white_eyes.luau` | `Sound hum_die`, `suspense_drop`, `Shake Jolt`, `Fov`, `Grade` @0; `Pose Lift` @1; `Pose Turn` (todos os clientes) + `neck_crack` + `Cinema` @2; `Whispers` Inside/Outside, `Heartbeat`, `Vignette`, `Grade` @3; `Fov` @4; olhos nas janelas (`Actor` front @3 e `Lantern Eyes` @4,5–7,5 + `suspense_hiss`); `Whispers`/`Heartbeat`/`Silence` @9; `Lights Off` + `lights_off` @9,4; `Lights Cascade`, sting, `Pose Turn`, `Jolt`, `Blur`, `Silence` @11,7; `Cinema`/`Vignette`/`Grade` @16 | T todos os de tela e luz. →A: `Pose Turn` dos clientes (quando a luz apaga), olhos nas janelas (idem), `Lantern Eyes` em Q1 (os olhos dela no escuro). F: `Lantern Eyes Seen Cameras` @2 (WATCHED) |
| `Scenes/anm_014_big_head.luau` | sting, `Jolt`, `Fov` @0; `Cinema` @1; `Fov` @3,2/6,2/9,2; `Whispers` Inside/Outside, `Heartbeat`, `Vignette`, `Grade Sick` @3; `Lights Flicker` @7; `Whispers`/`Heartbeat`/`Silence` @10,5; `Pose Tilt` + `Nudge` @10,6; sting/`Jolt`/`Blur`/`Silence` @12,5; `Heartbeat` @13 e @30; `Cinema`/`Vignette`/`Grade` @17; `Pose Turn` Outside @4 | T todos. →A: `Pose Tilt` (no 2º degrau), `Prop Sway` da luminária (no 2º degrau), crescendo de borda no 3º degrau (§3) |
| `Scenes/anm_001_blank_folks.luau` | `Jolt`, `Fov` @0; `Lights Flicker` @0,4; `Cinema` @1; `Pose Lift` com `Sound horror_sting` + `Nudge` @3; `Whispers`/`Vignette`/`Grade` @3,5; `Heartbeat`/`Fov` @4; `Prop Shake` @6; `whisper` @8; `Whispers`/`Heartbeat`/`Silence` @11,5; `Pose Tilt` + `neck_crack` @11,6; `Pose Lift`, sting, `Lights`, `Prop Shake`, `Jolt`, `Blur`, `Vignette`, `Silence` @13,5; `Heartbeat` @14 e @30; `Cinema`/`Vignette`/`Grade` @17; `Lantern Eyes` Outside @3 | T todos de tela/luz/sting e o Outside. F: `Pose Turn`/`Tilt Seen Cameras` @3. →A: `Pose Tilt` + `neck_crack` 0,25 (aos 20 s de espera) |
| `Scenes/anm_011_shaker.luau` | sting, `Jolt`, `Fov` @0; `Cinema` @1; `Whispers` Inside/Outside @2 e @8; `Heartbeat`/`Vignette`/`Grade Sick` @4; `Fov` @5; `Silence` @8; sting, `Lights`, `Jolt`, `Blur`, `Silence` @10; `Heartbeat` @10,5 e @30; `Cinema`/`Vignette`/`Grade` @16; tremores `Shake Step` (Inside) gerados; `Prop Shake Player` Outside @1 | T todos. →A: `Prop Shake/Sway` no balcão (@0, @3, @4, @10) e os chocalhos gerados (volume × 0,5) |
| `Scenes/anm_015_floater.luau` | `HUM` 0,5, `Jolt`, `Fov` @0; `Pose Float 0,6` @0,5; `Cinema` @1; `Prop Float` @2; `Whispers`/`Heartbeat`/`Vignette`/`Grade` @2; `Fov` @4; `HUM` @4,5; `shadow_whoosh` @6; `Whispers`/`Heartbeat`/`Silence` @8; `Prop Drop` + `Pose Float 0` @9,2; `grill_drop`, `Jolt`, `Lights`, `Blur`, `Silence` @9,4; `Heartbeat` @10/@30; `Pose Float 0,5` + `HUM` @12; `Cinema`/`Vignette`/`Grade` @16; as quedas geradas (`Lights Off/On`, `Jolt`, `Fov`, `Blur`) | T todos de tela/luz. `Pose Float` 0,6/0,5 → **0,15**. →A: o ciclo sobe/paira/cai (§2.7) com `HUM`, `Prop Float`, `Prop Drop`, baque. F: `Pose Float 6` e `Lift −30` `Seen Cameras` @2 |
| `Scenes/anm_016_starer.luau` | sting, `Jolt`, `Fov`, `amb_clock_tick` @0; `Cinema` + `Pose Blink` @1; `Whispers`/`Heartbeat`/`Vignette`/`Grade` @2; `Fov` @4; `Nudge` @5; `Whispers`/`Heartbeat`/`Silence` @CLOCK_FOR; `Pose Blink`, `Lights`, `lights_off`, `Jolt`, `Blur` @10,5; sting/`Silence` @10,8; `Heartbeat` @11/@30; `Cinema`/`Vignette`/`Grade` @16 | T todos de tela/luz. F: `Pose Turn/Tilt Seen Cameras` @2. →A: `amb_clock_tick` no balcão (o relógio que só toca perto dele) |
| `Scenes/anm_022_head_banger.luau` | sting, `Jolt`, `Fov` @0; `Cinema` @1; `Whispers banger`/`Heartbeat`/`Vignette`/`Grade` @2; `Lights` @4; `Whispers`/`Cinema` @12; `Heartbeat` @30 | T todos. F: `Pose Turn Seen Cameras` @1. →A: as batidas (§2.8) |
| `Scenes/anm_005_raincoat_lady.luau` | `thunder` 0,45, `Jolt`, `Fov` @0; `Cinema` @1; `Whispers` @4/@14 e @30/@50; `Vignette`/`Grade` @5 e @30; `Cinema` @20 e @48; `thunder`/`Lights` @30; `Heartbeat` @27/@52; `Fov` @40; `Silence` @51,5; `Pose Lift` @52; `thunder`, `Lights`, `Jolt`, `Blur`, `Silence`, `Heartbeat` @54; `Lantern Eyes` Outside @30 | T todos de tela/luz/trovão/Outside. F: `Prop Puddle` (@2, @27), as gotas geradas, `Pose Turn` @0,5, `Pose Turn/Lift Seen Cameras` @6. O escalonamento @27–@54 vira a consequência de **recusar/deixar ir** (§2.10), não de esperar |
| ANM-023 | sem cena | F (já é silenciosa) |

Também saem da chegada (modificadores de corpo, `Effects/Kit/OddCustomer`, `RigController`): roupa espelhada + olhos
brancos da 004 (fica só "mesma roupa do original"), tremor de corpo inteiro da 011 (vira inquietação), `stare` da 016
antes da conversa, cabeça muito baixa da 022 (vira leve). A 001 na N1 mantém a cabeça lisa (é a lição).

### 4.4 O que sobra como pista sutil e o que vira tensão sem dizer "é anomalia"

| Camada | Diz "anomalia"? | O que é |
|---|---|---|
| **Câmeras** (CAM3 e as outras) | sim, para quem olha | o corpo verdadeiro (`Seen = "Cameras"`). É o esforço que dá certeza |
| **Pista sutil no corpo** (§2, coluna Chegada) | às vezes | repuxão, brilho no olho, inquieto, gêmeo, pés sem passo. Clientes normais também têm "manias" (§4.5) |
| **Tique** | quase sempre (75 % depois da estreia) | no close, antes da escolha |
| **Inquietação ambiente** (nova, `Content.Tells.Unease`) | **não** (não diagnóstica) | na chegada de **qualquer** cliente: a lâmpada do balcão treme 0,2 s, o zumbido da geladeira cai 1 s, um cachorro late longe. Chance: cliente normal **12 %**, anomalia **30 %**. Recarga 40 s. Só diegético, nada de tela |
| **Walt** | não por cliente | só na ligação de estreia (§1.5) e nas reclamações (§5). Nunca avisa "chegou uma" |
| **Sustos sem verbo** (família D, `Behind`, `Dread`) | não | seguem como hoje e mantêm a noite tensa entre clientes |

### 4.5 Pistas falsas em clientes normais (com teto)

Cliente normal com uma **mania humana** que lembra a categoria de uma pista, sem nunca repetir a assinatura exata.
Escolhido pelo servidor; o client recebe o mesmo tipo de atributo de "pista sutil" que a anomalia usa (não dá para
distinguir pelos dados replicados, T10). **Câmeras nunca mostram nada** num cliente normal: quem confere, desempata.

| Mania (`Content.Tells.False`) | Lembra | Diferença para quem presta atenção |
|---|---|---|
| alonga o pescoço uma vez, estalo baixo | 012 | uma vez, devagar (a 012 repuxa a cada 5–8 s, rápido) |
| óculos escuros que refletem a lâmpada | 013 | o brilho segue a luz da sala |
| capuz ou chapéu grande | 014 | a cabeça não muda de tamanho na conversa |
| bate o pé, segura um copo de café e treme | 011 | treme o copo, não o corpo; pede com cobertura |
| fala "H-hi... sorry, cold out." | fala embolada | pede normal depois |
| olha o celular e não levanta o rosto | 016 | pisca |
| pede "JUST THE BUN" (pedido especial raro, `Q-446` a) | 011 | não treme; aceita qualquer coisa |

| Noite | Teto de pistas falsas por noite (time) | Chance por cliente normal até o teto |
|---|---|---|
| N1–N2 | 0 | — |
| N3–N6 | 1 | 20 % |
| N7–N10 | 2 | 20 % |
| Sanidade Breaking (< 20) do atendente | +1 (só para ele, `Q-463` b) | 30 % |

Regras: nunca duas seguidas; nunca com uma anomalia de cliente na fila ao mesmo tempo; nunca no cliente do tutorial;
nunca tique no close (no máximo a fala com a mania). O teto de pistas falsas é sempre **menor** que a tolerância de
reclamações da noite (§5.2), para a dúvida honesta não custar sanidade.

**Conflito:** DEC-278 vetou anomalia que se confunde com o fluxo e pede "sinal distinguível em ~2 s". A proposta
reinterpreta: o sinal da anomalia é distinguível **no close (tique) ou nas câmeras**, não na chegada; e a pista falsa é
o inverso (um normal com mania), com teto baixo e com a câmera como desempate. Vai ao dono em `Q-469`.

---

## 5. O custo de recusar (problema 2)

### 5.1 Por que hoje recusar é grátis

Recusar um normal já perde a venda (~$6 líquidos) e baixa a nota do turno (`Ledger.grade` = completos / chegados), mas o
dinheiro e a nota só aparecem no relatório, e a noite só é perdida pela **sanidade**. A anomalia aceita custa −35 na
hora. Resultado: a moeda que importa durante a noite é a sanidade, e recusar não toca nela.

### 5.2 Proposta: reclamações com tolerância, cobradas em sanidade

Uma **reclamação** é um cliente **normal** que a equipe mandou embora sem servir. Por noite há uma **tolerância**
(grátis); acima dela, cada reclamação tira sanidade.

| Evento | Reclamação? | Quem paga |
|---|---|---|
| REFUSE num cliente normal | 1 | quem recusou |
| cliente normal desiste na fila (`Left`, ninguém fez Take Order) | 1 | dividido entre os jogadores dentro da loja |
| pedido aceito de cliente normal que expira (`Slow`) | 1 | quem aceitou (fecha a brecha "aceitar e nunca entregar") |
| janela fechada por jogador manda a fila embora | 1 por cliente com ticket | quem fechou |
| ... durante uma ameaça de fora ativa (021, 008, 010) ou até 10 s depois | 0 | — |
| recusar / não entregar / janela numa anomalia | 0 (exceto 005 e 016, §2.10–2.11) | — |
| última chamada das 6 h, Summary, tutorial | 0 | — |

| Número (Provisório, `Content.Complaints`) | Valor |
|---|---|
| `Free` (tolerância da equipe por noite) | N1–N6: **2**; N7–N10: **3**; +1 por jogador ativo além do primeiro |
| `Sanity` por reclamação acima da tolerância | **−6** (1/6 de um erro de −35) |
| Dividido (desistência na fila) | −6 ÷ jogadores dentro da loja, mínimo −2 cada (solo = −6: ignorar custa o mesmo que recusar) |
| Ligação do Walt | 1ª reclamação paga: "Folks are calling me. You're turning away paying customers. If one's wrong, you'll know when you hand it over." 3ª paga: "I'm docking your shift." → nota do turno no máximo **C** (sem bônus do chefe) |
| Aviso na tela | contador "Complaints 1/2" no canto do dinheiro por 3 s a cada reclamação; acima: "Complaints 3/2 · −6" |
| Relatório (Summary) | linhas novas: "Turned away: 3 (free 2)" e "Strange sales: 1" |

Por que sanidade e não só dinheiro: é a moeda da noite (DEC-277), entra na escada da DEC-352 (sanidade baixa → mais
anomalias: recusar demais **chama** mais anomalias, o que fecha o círculo tematicamente) e o jogador sente na hora.

### 5.3 Comparação de estratégias (solo, Provisório)

Premissas: `economy.md` §5.0 (restaurante); anomalias de cliente por noite = chegadas − reais; ~$6 líquidos por
cliente completo (85 %); anomalia atendida certo = ×2 ≈ **$12** líquidos; tique visível 80 % (média estreia + depois);
pistas falsas no teto. Sanidade inicial 100.

| Noite | Estratégia | Reclamações (pagas) | Sanidade da noite | Dinheiro |
|---|---|---|---|---|
| N3 (13 reais, 2 anomalias, 1 falsa, Free 2) | **Recusa tudo** | 13 (11) | **−66** | $0, nota D |
| | Recusa ao primeiro sinal (inclui a falsa; aceita o resto e acerta 50 % das anomalias sem tique) | 1 (0) | −7 | ~$64 |
| | Aceita tudo e lê a condição (acerta 75 %) | 0 | −18 | ~$84 |
| N5 (15 reais, 3 anomalias, 1 falsa, Free 2) | Recusa tudo | 15 (13) | **−78** | $0, D |
| | Recusa ao primeiro sinal | 1 (0) | −11 | ~$76 |
| | Aceita tudo e lê a condição | 0 | −26 | ~$105 |
| N8 (20 reais, 4 anomalias, 2 falsas, Free 3) | Recusa tudo | 20 (17) | **−102 → desmaio** | $0, D |
| | Recusa ao primeiro sinal | 2 (0) | −14 | ~$99 |
| | Aceita tudo e lê a condição | 0 | −35 | ~$140 |

Leitura: recusar tudo perde sempre e derruba a partir da N7–N8; "recusar ao primeiro sinal" é seguro e paga menos;
"aceitar e ler a condição" paga ~35–40 % mais com mais risco. A dúvida honesta (1–2 recusas erradas por noite) cabe na
tolerância e custa 0.

### 5.4 Alternativas consideradas

| Opção | Prós | Contras | Escopo |
|---|---|---|---|
| **A. Tolerância + sanidade (recomendada)** | mesma moeda do erro; sentida na hora; liga na DEC-352; números simples | mais uma fonte de queda de sanidade (o Mild segura: sem susto) | P/M: contador no `CustomerService`, sanidade via `AnomalyService`/Sanity, 2 falas do Walt, 2 linhas no relatório |
| B. Multa em dinheiro ($5 por reclamação acima da tolerância) | fácil de entender | dinheiro não derruba a noite: recusar tudo continua "seguro" | P |
| C. Cota do Walt (X clientes servidos até as 6 h; abaixo = noite sem bônus e −20 de sanidade na próxima) | forte, estrutura de "turno" | punição atrasada, invisível durante a noite; pressão de cota em criança | M |
| Fila crescendo | — | recusar **libera** o balcão (a fila anda mais rápido): não pune | — |

### 5.5 O prêmio de aceitar

| Resultado | Paga | Nota do turno |
|---|---|---|
| Anomalia `Erro` atendida certo | **×2** o preço do pedido (`AnomalyPayMult` 2) + gorjeta normal; a moeda sai "estranha" (cue `blank_coin`, já existe) | conta como **completo** |
| Anomalia `Atenção` atendida certo | ×1 + $1 | completo |
| Anomalia recusada / deixada ir | $0 | não conta em `Arrived` (não baixa a nota) |
| Erro | $0, prato perdido | não conta |

Impacto na run: ~1,5 anomalias bem atendidas por noite × +$6 extra ≈ **+$9/noite**, ~+$90 na run solo (~+10 % sobre
~$935). Cabe na sobra de `economy.md` §5.0; se o dono quiser a run mais apertada, `AnomalyPayMult` 1,5.

---

## 6. Impacto em decisões, perguntas e código

### 6.1 Decisões e perguntas

| Item | Hoje | Com esta proposta |
|---|---|---|
| **DEC-353** | "ACCEPT numa anomalia = o susto na hora"; "pareceu estranho? REFUSE"; recusar normal = perde a venda | ACCEPT nunca assusta; a anomalia faz pedido; a regra do jogador vira "aceite, leia a condição, entregue certo ou deixe ir"; recusar normal tem custo (§5). **Precisa de DEC nova** (emenda) → `Q-466` |
| **DEC-254** (família A = verbo RECUSAR; princípio "sinal em 1 segundo") | recusar é a resposta | família A vira "cliente errado: condição na entrega"; o sinal sai da chegada e vai para o close e as câmeras. Emenda → `Q-466` |
| DEC-255 / DEC-277 | erro = jumpscare + −35 | igual, só que **na entrega**. Atenção (011, 005, 016) nunca jumpscare |
| DEC-278 | sinal distinguível em ~2 s | reinterpretado: no close ou nas câmeras; pistas falsas com teto → `Q-469` |
| **Q-445** (4 respostas: JANELA/LUZ/OLHOS/PORTA) | família A = JANELA | família A sai da tabela de respostas e ganha as 7 condições (§1.3); a JANELA continua como **saída** universal. Ponto de atrito: a 013 **apaga** a luz (`Q-445` dizia "LUZ = sempre religar") → `Q-471`. Para as famílias B/C/D a Q-445 segue valendo |
| **Q-446** (Shaker) | (a) virar JANELA + susto recomendado | substituída: servir puro; errar = prato devolvido, sem susto (§2.5). O "JUST THE BUN" de (a) vira pista falsa. Recomendo fechar a Q-446 com esta ficha |
| **Q-447** (Crawler, Head banger, Hush) | (b) 022 e 010: janela resolve | 022: a janela é a saída; a condição é entregar antes da 12ª batida; apagar a luz sai da 022. Crawler e Hush: sem mudança aqui |
| **Q-448** (ensinar e explicar o erro) | (a) por resposta, (b) ligação, (c) cartão | (a) vira "por **condição**" (7, uma por estreia), (b) igual, (c) igual com o texto da condição; + bilhete do Walt no ticket da 1ª vez (§1.5) |
| **Q-460** (REFUSE no close resolve) | (a) aplicada | continua: REFUSE é a saída antes do aceite. A diferença: ACCEPT depois do tique deixa de ser erro e abre a condição `NoLook` |
| Q-451 (b) (porta das cópias) | simplificar para JANELA | a cópia vira `NoServe` (não entregar); o fluxo da porta não volta |
| Q-455 / Q-456 (janela) | a janela manda a fila embora; resolve a família A | igual, e agora com custo (§5.2) e isenção durante ameaça de fora |
| Q-458 (tempo para escolher) | sem limite | sem mudança; deixar o cliente normal no close sem escolher não custa (sair do diálogo continua seguro) |
| Q-461 (sinal fora da chegada) | (a) só algumas | superada pela §4 (todas sem tela na chegada; corpo sutil por ficha) |
| Q-463 (tique falso) | (a) nunca | substituída pela §4.5 (mania, não tique) → `Q-469` |
| `anomaly-tics-proposal.md` | campo "Resposta" = REFUSE/janela; "Accept = erro" | o tique não muda; o campo "Accept" das fichas passa a apontar para a condição desta proposta |

### 6.2 O que muda no código (alto nível, sem código)

| Onde | Mudança |
|---|---|
| `Tablet/server/TabletService` | ACCEPT numa anomalia entra em `Talking` com a fala de pedido dela (`Content.OrderTalk` por `Variant`), sem cue `jumpscare`; o tique e o `ChoiceAt` ficam |
| `Customer/server/CustomerService` | ticket para ator anomalia por regra (normal, `Plain`, cópia do original, em branco); Serve num ator anomalia vai para o `AnomalyService` decidir; **contador de reclamações** (RefuseOne normal, `Left`, `Slow`, `SendLineAway` com isenção); `Arrived` não conta anomalia recusada |
| `Anomaly/server/.../Kit/CustomerActor` + `Rules/ANM-xxx` | `Params.Condition = { Kind, ... }` (server-only, T10): `NoServe`, `NoLook` (gaze no Serve via `Vision`), `Dark` (`ctx.Light.IsSwitchOn`), `Hurry` (degraus por costas/tempo, `FailAt`), `Grounded` (fase do ciclo), `Plain` (devolução, `Returns` 1), `Serve`; `Wrong = "take_order"` sai; `Wait`, `PayMult`; omissão = vai embora sem falha |
| `AnomalyService` | fase de registro `Accepted` (hora do servidor do ACCEPT) para a cena; sanidade das reclamações (Pressure já tem o caminho); falas do Walt das reclamações |
| `Shared/Content/HorrorScenes` (+ `Types`, `Validate`) | `Phase` ganha `Accepted`; Validate "chegada quieta" (§4.2); os dados das cenas da §4.3 |
| `Shared/Content` novos | `Content.Complaints` (§5.2), `Content.Tells` (`Unease` §4.4, `False` §4.5) |
| `Effects/Kit/OddCustomer`, `RigController` | modificadores de chegada sutis (§4.3 final); manias falsas com o mesmo atributo |
| `Economy/.../Ledger` + `Net` (ShiftReport) | `Complaints`, `StrangeSales`; `HudSummary` mostra as duas linhas |
| `Content.Journal`, `BossCalls`, `FaintTips`/cartão de erro | textos da condição e da saída (narrative-writer) |
| `/dev` | `/dev complaint [n]`, `/dev tell false|unease`, `/dev cond` (estado da condição do ator: degrau, batida, fase do ciclo, quem está encarando) |

Sem NPC novo, sem parte nova contínua: as manias usam clientes normais que já existem; a inquietação ambiente é luz/som
local. Teto de NPCs inalterado.

---

## 7. Ordem de implementação recomendada

| Ordem | O quê | Por quê | Custo |
|---|---|---|---|
| 0 | **Gancho**: ACCEPT sem susto + anomalia faz pedido + Serve decidido pelo `AnomalyService` + fase `Accepted` + `Validate` chegada quieta (só para linhas marcadas `AfterAccept = true`) | sem ele nada roda; a flag por linha deixa as não migradas como hoje | M |
| 1 | **Reclamações** (§5) | sem custo de recusar, o modelo não segura; independe das fichas | P/M |
| 2 | **ANM-012 `NoLook` (piloto)** + chegada quieta da 012 | tique já está no código; o gaze já existe (`Vision`, `TicFollow`, `Stare`); é o exemplo do dono | P/M |
| 3 | **ANM-011 `Plain`** | ticket puro já existe; é a primeira "atenção" (prova que o modelo não é só susto) | P |
| 4 | **ANM-004 `NoServe`** | ticket = cópia do original (o servidor já tem `CopyOf`); estreia N3, cedo na run | P |
| 5 | **ANM-013 `Dark`** | lê o interruptor como a 022 já faz; resolver `Q-471` antes | P |
| 6 | **ANM-014 `Hurry` costas** | degraus por evento; testa o crescendo de borda | M |
| 7 | 001, 005, 016, 022 | dados + pequenas regras | P cada |
| 8 | 015 `Grounded`, 023 câmera | ciclo replicado; sinal de "olhando a CAM3" no servidor | M cada |
| 9 | Pistas falsas (§4.5) e inquietação ambiente (§4.4) | depois do 1º Play do piloto, para calibrar a dúvida com o modelo já rodando | M |

### 7.1 Critérios de aceite (gancho + reclamações + piloto)

1. `/dev trigger ANM-012`: na chegada não toca nenhum passo de tela (sem barras, palavras, borda, cor, coração, sting);
   nas câmeras a cabeça está virada.
2. `Validate` rejeita uma cena de cliente (linha `AfterAccept`) com `Cinema`/`Whispers`/`Vignette`/`Grade`/`Heartbeat`
   em `Active`.
3. ACCEPT na 012: nenhum cue `jumpscare`; ela diz o pedido de costas; o ticket aparece na retirada.
4. Serve olhando o rosto dela (rosto no cone de visão no instante do Serve): silêncio 0,4 s, jumpscare, −35 em quem
   entregou, cartão "WRONG MOVE · ... don't look at her when you serve".
5. Serve olhando para o balcão: sem susto, paga 2× o preço, conta como completo no `Ledger`.
6. Não entregar: depois de 75 + 5K s ela vai embora, sem susto, sem sanidade, sem reclamação.
7. REFUSE no close: vai embora, sem susto, sem reclamação.
8. REFUSE em cliente normal: reclamação 1/2, sem sanidade; 3ª reclamação da noite (solo, N4): −6 de sanidade, ligação
   do Walt (1ª vez); 5ª: nota do turno limitada a C no relatório.
9. Cliente normal que desiste na fila (`Left`) e pedido aceito que expira (`Slow`) contam reclamação; fechar a janela
   durante a ANM-021 ativa não conta.
10. Relatório mostra "Turned away: n (free f)" e "Strange sales: m".
11. Co-op (2 jogadores): tolerância 3; a reclamação de `Left` tira 3 de cada um dos dois dentro da loja.
12. `modux check` e `tools/analyze.ps1` sem erro.

---

## 8. Perguntas abertas

`Q-466` a `Q-474` em `docs/open-questions.md`.

---

## 9. Aplicado (2026-10-22, Provisório, sem DEC): a anomalia é obrigatória

Decisão do dono em 2026-10-22, por cima desta proposta: **não existe mais ACCEPT/REFUSE**. A conversa termina sozinha e o
`TabletService` chama `CustomerService:TakeOrderFor` para **todo** cliente, anomalia inclusive ("a anomalia chegou,
interagiu com ela, ela vai automaticamente pra fila... ele vai ter que saber como lidar com aquela anomalia a partir das
instruções do Walt"). O "aceite" virou o fim da conversa e não há recusa. O que mudou em relação às §1–§7:

| Proposta original | Aplicado |
|---|---|
| ACCEPT / REFUSE; REFUSE é a saída antes do aceite | sem escolha: o pedido é sempre anotado no fim da conversa |
| fase nova `Accepted` | fase nova **`Queue`** (registro `Anomalies`), do pedido anotado até o fim |
| saída segura universal: não entregar / janela | **não entregar** continua (a paciência acaba, ela vai embora; Hurry é a exceção). A **janela não alcança mais** anomalia de cliente (§9.5) |
| crescendo de tela só na borda da falha e na entrega | todo o crescendo de hoje (barras, sussurros, borda, cor, coração, stings, props) toca **na fila**, ao entrar nela |
| `Validate` cobrando chegada quieta | o **carregador** das cenas move os passos (§9.2); nenhuma cena precisou ser reescrita |

### 9.1 O fluxo (servidor: `AnomalyService/Anomalies/Kit/CustomerActor`)

| Momento | Registro | O que acontece |
|---|---|---|
| Spawn → balcão | `Active` | anda até o tablet como qualquer cliente. **Nada de tela**; só as câmeras mostram o corpo verdadeiro |
| Conversa | `Active` | o tique (Content.Tics), inalterado; é do outro agente (TabletService) |
| Fim da conversa (`TakeOrderFor`) | **`Queue`**, Step 0 | o pedido dela entra na fila de entrega como o de um cliente comum (pickup, prato, #n). O rig ganha `AnomalyQueue` = hora do servidor: todo cliente vê o corpo **desfigurado** (§9.3). A condição de `Rules/<Ref>` `Params.Condition` começa. Legenda + sussurro com a dica (§9.4) |
| Fim certo | `Resolved` | a condição foi cumprida e o pedido foi entregue (Complete / Perfect / Incomplete): ela pega o prato e vai. Paga `PayMult` × o preço da linha (+ `Bonus`) e conta no livro do turno como chegada + resultado (§5.5). O corpo volta ao resíduo do tique ("murcha") |
| Fim errado | `Failed` | a condição quebrou: `Kit.Scare` (jumpscare + desmaio de quem paga) ou −RuleBroken (a 004 sem Scare). Na `Plain` é só atenção: −`Sanity` e nenhum jumpscare |
| Sem fim | — | hot dog errado (não a condição): ela vai embora reclamando, sem resultado. Paciência acabou: vai embora (exceto Hurry, que é o erro; e `OmitSanity` da `Serve`) |

Condições (`Params.Condition.Kind`, números Provisórios; o que não estiver na regra usa o padrão do Kit):

| Kind | Regra | Fim certo | Fim errado | Quem paga o errado |
|---|---|---|---|---|
| `Hurry` | entregar em até `Seconds`; a cada `Seconds/Steps` sobe um degrau (Step no registro + `AnomalyStep` no rig) | entregue antes | `Seconds` esgotado (ou a paciência antes) | quem anotou o pedido (fim da conversa); se saiu, o jogador ativo mais perto dela |
| `NoLook` | no instante do serve, a cabeça dela **não** pode estar no cone de visão (`Angle` graus de cone cheio, até `Range` studs) de quem entrega. Checagem pelo `Gaze` (a mesma do "visto" e do `Stare`): `CustomerService:AddActorJudge` responde "Wrong" antes da venda | entregue sem olhar | entregou olhando: o serve vira `Wrong` ($0, o hot dog fica na mão) | quem entregou |
| `Plain` (atenção) | qualquer cobertura no hot dog: ele **arremessa o prato na parede** (§9.9; `AddActorJudge` "Return": o hot dog é perdido, $0, sem venda; cue `plate_throw`), fica com raiva e continua esperando `Returns` vezes; cada uma custa −`ReturnSanity` | entregue puro (a raiva passa) | a próxima cobertura: arremessa de novo, `Failed`, −`Sanity`, e sai batendo os pés depois de `LeaveDelay` | quem entregou |
| `Serve` (interino) | qualquer pedido entregue resolve; opcional `OmitSanity` quando a paciência acaba | qualquer entrega | — | — |

`NoLook` sem `Gaze` fresco (fora da 1ª pessoa) conta como "não olhando". O `Stare` (coração, borda, "STOP STARING", dreno
leve) agora só liga na fase `Queue` (servidor e cliente) e voltou na 012 como o aviso da condição dela; na 004 e na 013
também saiu da chegada.

### 9.2 Chegada sem efeitos de tela (Q-468 a, na versão "tudo para a fila")

`Content.HorrorScenes` (carregador): em toda cena cuja chave é anomalia com `Actor = "Customer"`, a fase `Active` fica só
com os passos `Seen = "Cameras"` (o canal da verdade). **Todo o resto** da chegada vai para `Queue`, com o mesmo `At`
(contado da entrada na fila): barras (`Cinema`), sussurros, borda, cor, coração, silêncio, blur, FOV, tranco, stings, props,
luzes. Os `Whispers` movidos passam a dizer a dica (`Words` `queue_<key>` = Hint ×3 + Words da linha; a lista "outside"
fica). Com dica `Live`, a fila abre com o SFX `whisper` e a dica sozinha na tela por 2,2 s (`hint_<key>`). Anomalia com
dica ainda não `Live` sussurra uma lista genérica (`queue_generic`). Trilha (`Content.Score`): 012 e 014 tocam `Tension`
só na `Queue` (rampa 30 s / 40 s); na chegada a música não entrega nada. Atualização (2026-10-22, Provisório): nas quatro
anomalias com tique (012, 013, 014, 004) a tensão de **quem atende** começa na conversa, no ápice do tique, e segue para a
fila sem recomeçar; os outros jogadores recebem a fila como aqui (`anomaly-tics-proposal.md` §4.4).

### 9.3 Desfigurada na fila (resíduos dos tiques, `Content.Tics` `Queue`, `Effects/Kit/Tic` e `OddCustomer`)

| ANM | Corpo na fila (todos os clientes veem) |
|---|---|
| 012 | cabeça virada para trás (mesmo sem tique), **pescoço quebrado**: deitada no ombro (Roll 38°) e caída (Pitch 16°), com um tranco a cada 1,4–3,2 s; a nuca segue quem saiu do diálogo (`TicFollow`) |
| 014 | **cabeça estufada**: ×2,2 ao entrar na fila e +0,2 a cada degrau do Hurry (2,4 / 2,6 / 2,8; 3,0 no vidro), com rangido de couro a cada degrau; servida certo, volta ao ×1,9 do tique |
| 013 | olhos brancos (mesmo sem tique), a luz deles em 2 (no resíduo do tique era 0,8) |
| 011 | na chegada só **inquieto** (25 % do tremor); na fila o **tremor inteiro** |

### 9.4 Título e sussurro com a dica (`Content.AnomalyHints`, inglês, Provisório)

Ao entrar na fila: a legenda do "POWER OUT" (`HorrorCaption`, 3 s) com o título e a linha, o SFX `whisper` e a dica nas
palavras da tela. As frases ficam em `Content.AnomalyHints`, uma linha por anomalia de cliente, para o papel de dicas do
Walt (outro agente). `Live = true` = a condição dela roda no código (legenda + sussurro); `false` = planejada.

| ANM | Hint (sussurro, papel) | Título | Linha | Live |
|---|---|---|---|---|
| 014 | BE QUICK | — | SERVE IT BEFORE ITS HEAD HITS THE GLASS | sim (Hurry) |
| 012 | DON'T LOOK AT HER | DON'T LOOK | EYES DOWN WHEN YOU HAND IT OVER | sim (NoLook) |
| 011 | JUST BREAD | — | NOTHING ON IT | sim (Plain) |
| 005 | SERVE HER | — | DON'T LEAVE HER OUT IN THE RAIN | sim (Serve) |
| 013 | LIGHTS OFF | — | SERVE HER IN THE DARK | não (Dark) |
| 001 | DON'T COOK IT | — | A BLANK TICKET LEAVES ON ITS OWN | não (NoServe) |
| 004 | DON'T COOK IT | — | THAT ORDER WAS ALREADY SERVED | não (NoServe) |
| 022 | BE QUICK | — | BEFORE THE GLASS CRACKS | não (Hurry por batidas) |
| 015 | WAIT FOR THE THUD | WAIT FOR IT | SERVE IT WHEN ITS FEET TOUCH THE FLOOR | não (Grounded) |
| 016 | SERVE HIM | — | AND DON'T STARE BACK | não (Serve + Stare) |
| 023 | CHECK THE CAMERAS | CAMERAS | WRONG ON THE SCREEN? DON'T COOK IT | não (NoServe + câmera) |

O "sussurro" é o SFX `whisper` + as palavras na tela; uma **voz** sussurrando a frase precisa de linha nova no
`Content.VoiceLines` (tools/voice), fora desta rodada.

### 9.5 A janela com anomalia na fila (Q-473)

Fechar a janela continua valendo para as ameaças de fora (021, 008, 006...). Com uma anomalia de cliente, **antes ou
depois do pedido**, a janela **não resolve nem pune**: ela não é mandada embora (a fila normal vai, como hoje), ninguém
paga nada pela janela, e a condição continua correndo (o balcão de retirada fica dentro e o caixa segue aberto: dá para
entregar com a janela fechada). Saíram junto: a ANM-012 que reabria a janela na cara (`window_slam`) e o pescoço que
estalava ao ser recusada (`neck_snap`); os cues ficam no Content sem uso.

### 9.6 Linha do tempo dos pilotos (Provisório)

**ANM-014 Hurry ("BE QUICK")** — `Seconds = 40`, `Steps = 4`, `PayMult = 2`.

| t (desde o pedido anotado) | O que acontece |
|---|---|
| 0 | `Queue` Step 0; cabeça incha para ×2,2; legenda BE QUICK + `whisper`; violinos (`Tension`, rampa 40 s); jolt + FOV |
| 1–3 | barras (0,08); palavras BE QUICK / "hurry..."; coração 70→120; borda e cor Sick |
| 10 | degrau 1: ×2,4 + rangido |
| 10,5–12,5 | silêncio, ela inclina a cabeça para dentro (Pose Tilt), sting + tranco + blur |
| 17 | barras saem, borda e cor recuam (o trabalho continua) |
| 20 / 30 | degraus 2 (×2,6) e 3 (×2,8) com rangido |
| entregue antes de 40 s | `Resolved`: paga 2× (preço + 1× extra), murcha para ×1,9, sai com o prato; Release |
| 40 s (ou a paciência antes) | Step 4 (×3,0), `Failed`: jumpscare + desmaio de quem anotou; ela vai embora; Climax |

**ANM-012 NoLook ("DON'T LOOK AT HER")** — `Angle = 30`, `Range = 24`, `PayMult = 2`.

| t | O que acontece |
|---|---|
| 0 | `Queue`; o pescoço quebra (Roll/Pitch em 0,35 s) com a cabeça virada; legenda DON'T LOOK / EYES DOWN... + `whisper`; violinos (rampa 30 s); jolt + FOV |
| 1,5–9,5 | barras, borda 0→0,18, cor fria, palavras "DON'T LOOK AT HER / eyes down..." |
| enquanto espera | encarar a cabeça dela (cone de 18°) ≥ 2 s = pressão do `Stare` (coração, borda, STOP STARING, a cabeça vira para a câmera); ≥ 3 s drena 1/s (teto 20) |
| 9,5–12,5 | barras saem, borda e cor recuam |
| entrega olhando para o balcão/bandeja | `Resolved`: paga 2×, ela sai com o prato |
| entrega com a cabeça dela no cone de 30° | o serve vira `Wrong` ($0, o hot dog fica na mão), `Failed`: jumpscare + desmaio de quem entregou |
| paciência acabou (75 + 5K s) | vai embora, sem custo |

**ANM-011 Plain ("JUST BREAD", atenção)** — `Returns = 1`, `ReturnSanity = 15`, `Sanity = 5` (os dois em `Content.PlateThrow.Sanity`), `PayMult = 1`, `Bonus = 1`. Arremesso e reação: §9.9.

| t | O que acontece |
|---|---|
| chegada | inquieto (25 % do tremor) |
| 0 | `Queue`; tremor inteiro; legenda JUST BREAD / NOTHING ON IT + `whisper`; balcão chacoalha (props), sting, barras |
| 2–8 | palavras "JUST BREAD / nothing on it", coração, borda, cor Sick; para tudo em 8 s; pulo do balcão em 10 s; barras saem em 16 s |
| entrega pura | `Resolved`: para de tremer (e a raiva passa, se já arremessou), paga o preço + $1 |
| 1ª entrega com cobertura | **arremessa o prato na parede** (§9.9), o hot dog é perdido, **−15** de sanidade de quem entregou; TUM, "I ONLY WANT BREAD.", rosto macabro e corpo bugado; ele continua esperando com raiva |
| 2ª entrega com cobertura | arremessa de novo, `Failed`, **−5** de quem entregou; 2,4 s depois sai batendo os pés, ainda com raiva. **Nunca jumpscare** |
| paciência acabou | vai embora, sem custo |

### 9.6b Paciência pela metade nas `NoServe` (pedido do dono 2026-10-22, Provisório, `Q-476`)

As anomalias que o jogador não deve servir (**001, 004, 023**, `NoServe`, §2.12) esperam **metade do tempo**: os dois
relógios (fila e pedido) valem ×0,5 (`Content.OrderRules.UnservablePatienceScale`; flag `Params.Unservable = true` na
regra; o Kit e o `CustomerService` repassam `PatienceScale` no spawn). Antes só a 001 tinha isso
(`VARIANT_PATIENCE`). As que pagam ou deixam servir ficam com a paciência normal.

### 9.7 O que ficou de fora (para depois)

- Condições das outras (rodam com o interino `Serve`, sem erro): **001/004/023 `NoServe`**, **013 `Dark`** (`Q-471`),
  **015 `Grounded`** (ciclo replicado), **022 `Hurry` por batidas**, custo de deixar ir da **016**. As dicas já estão no
  Content com `Live = false`; a tensão da fila toca com sussurros genéricos.
- Quem paga o Hurry "de costas" (§2.3: degrau por quem vira as costas): hoje o degrau é só por tempo.
- Bilhete do Walt no ticket, cartão de erro, ligação do Walt com a condição (§1.5); reclamações (`Q-467`); pistas falsas
  (`Q-469`); inquietação ambiente (§4.4); silêncio de 0,4 s na entrega (§3).
- Voz sussurrada da dica (precisa de `Content.VoiceLines`).
- Cada cena de anomalia não migrada toca na fila a coreografia inteira da chegada antiga (inclusive a 013 que apaga as
  luzes e a 005 com trovões): revisar cena a cena quando cada condição entrar.

### 9.8 Teste (`/dev cond`, `docs/tech/dev-commands.md`)

1. `/dev cond run 14` (ou 12, 11): pula para a Noite, dispara e anota o pedido por você quando ela chega ao balcão.
2. `/dev cond`: fase, condição, relógio, quem anotou, pratos devolvidos.
3. Hurry: monte e entregue antes do fim (fim certo) ou `/dev cond hurry 3` (erro em 3 s).
4. NoLook: `/dev cond look` diz se o seu serve agora seria o erro; entregue olhando para a bandeja (certo) ou para o rosto (erro).
5. Plain: `/dev cond run 11`, e quando ele estiver na fila entregue com mostarda (monte na cozinha, ou `/dev cond serve mustard`):
   arremesso (−15, ele fica); de novo (−5, ele sai batendo os pés) ou puro (`/dev cond serve`: certo). `/dev cond` mostra
   `thrown n/2`.
6. `/dev cond win` / `/dev cond fail` forçam os fins.

### 9.9 A birra do 011 ("só pão", 2026-10-22, Provisório, sem DEC)

Pedido do dono: em vez de devolver o prato no balcão, **ele arremessa o prato longe e diz que só quer pão** (sem voz por
enquanto); o prato bate na parede, fica um segundo, escorre até o chão, cai e some em fade; um "TUM", o texto dele, o
**rosto macabro** (o das thumbnails, com dentes e língua) e o **corpo bugado** (tiques sem suavidade, tremendo). Ajuste do
mesmo dia: **"quando ele arremessar o prato, retira 15 de sanidade e na segunda vez 5"**. Números em `Content.PlateThrow`.

**Servidor** (`Anomalies/Kit/CustomerActor`, condição `Plain`; `Rules/ANM-011`): toda entrega com cobertura vira "Return"
(o hot dog some da mão, $0, sem venda; `CustomerService` manda o `Acted "return"`). A cada arremesso: o rig ganha
`AnomalyThrow` (as coberturas, para o cliente desenhar o mesmo hot dog) e, no primeiro, `AnomalyRage` (hora do servidor:
ele fica com raiva até sair ou ser servido puro); cue `plate_throw`. Arremessos 1..`Returns`: −`ReturnSanity` (15) de
quem entregou, ele continua esperando. O seguinte: `Failed`, −`Sanity` (5), e `LeaveDelay` (2,4 s) depois ele sai
(`Leave`, humor `Complaining`); nesses 2,4 s qualquer entrega é `Wrong` ($0, o hot dog fica na mão, ele sai na hora).
Servido puro: `Resolved`, a raiva e o tremor saem. Paciência acabou: vai embora sem custo. **Nunca jumpscare.**

**Cliente** (`Effects/Kit/Tantrum`, ligado ao `OddCustomer` da variante `shake`), linha do tempo do cue (Provisório):

| t (s) | O que acontece |
|---|---|
| 0 | o braço direito pula para cima (sem tween) e o prato (cópia local do hot dog servido, com as coberturas, no prato do kit) aparece na mão |
| 0,14 | o braço pula para a frente; o prato voa em arco (0,34 s, 1,6 studs acima da reta, girando) até a parede: raycast pela frente dele a partir da mão (depois um leque de ±25°), a primeira face grande, em pé, sólida e que não é personagem: do balcão de retirada, a parede de dentro do trailer atrás do balcão. Sem parede a 40 studs: cai no chão 10 studs à frente |
| 0,48 | bate na parede: `plate_smash` |
| 0,5 | **TUM** (`anger_thud` na cabeça; tranco de câmera em quem está a 18 studs); balão "I ONLY WANT BREAD." digitado letra a letra no estilo `Shake` do `TypedText` (fica 2,6 s depois de digitado); entra a **raiva** |
| 0,48–1,48 | o prato fica grudado na parede |
| 1,48–3,08 | escorre devagar até a borda tocar o chão (acelera no fim) |
| 3,08–3,3 | despenca deitado no chão: `plate_drop` |
| 3,3–4,2 | fade de transparência e some |

**A raiva** (todos os clientes veem, pelo atributo; quem entra depois também): rosto = `TicFace` local `EyesWhite` (os olhos
brancos que já existem em `CrewExpressions`) + a **boca das thumbnails** (`T.addGrin` de
`tools/thumbnails/thumb_project_helpers.luau`: boca escura, vermelho por dentro, garganta, **língua rosa** e duas fileiras
de **dentes** brancos Neon), montada em peças locais soldadas na cabeça, na escala dela. Nenhuma imagem nova. Corpo: a cada
0,1–0,4 s o pescoço, os dois ombros e o tronco (RootJoint) **pulam direto** para uma pose torta nova (até 30/45/35°,
50/35/70°, 12/22/14°), ficam 0,05–0,16 s e pulam de volta, sem interpolação; o tronco treme todo frame (0,12 studs, 5°).
Andando com raiva (indo embora ou subindo na fila): `steps_stop` a cada 0,42 s. **Movimento reduzido** (Settings ou o do
Roblox): ângulos e tremor × 0,3, tiques duas vezes mais espaçados, sem tranco de câmera.

**Sons** (Creator Store, `ProSoundEffects`, `art/credits.md`; `audio/sound-list.md` §5.23): `plate_smash` = Plate Break
Concrete Floor 8 (9117653536), `plate_drop` = Plate Break Concrete Floor 7 (9117653229), `anger_thud` = Body Fall Thud 1
(9113480917); pés = `steps_stop` (Foot Stomp 3).

**O que vem depois (recomendação, Provisório):** ele continua esperando com raiva (a condição continua; pão puro resolve e
paga); na 2ª entrega errada arremessa de novo, −5 de quem entregou e vai embora batendo os pés. Abertos para o dono: o
texto final (e a voz gritando, quando houver `Content.VoiceLines`); se o rosto deve ser `Angry` (existe) em vez dos olhos
brancos (o branco também é o sinal da 013); se −15 no primeiro arremesso não pesa demais para um erro "de atenção".

