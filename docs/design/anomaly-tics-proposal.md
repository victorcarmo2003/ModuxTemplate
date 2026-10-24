Status: Rascunho (game-designer, 2026-10-21). Todos os números são Provisórios até o Play do dono. Nenhuma regra de acerto/erro muda.
Piloto ANM-012 aplicado no código em 2026-10-21 (Provisório, sem DEC): ver §4.2.
ANM-013, ANM-004 e ANM-014 aplicados no código em 2026-10-22 (Provisório, sem DEC): ver §4.3.
A tensão das anomalias com tique começa na conversa, sincronizada com o tique (2026-10-22, Provisório, sem DEC): ver §4.4.
ANM-001 ganhou o tique "rosto que apaga", chegando com rosto normal, e a pele da espécie no sem-rosto (2026-10-22, Provisório, sem DEC): ver §4.5.

# Tiques das anomalias de cliente no diálogo

Pedido do dono (2026-10-21): "em vez de a gente quebrar o pescoço dela quando ela aparecer ali, a gente vai quebrar o
pescoço dela quando ele falar com ela ali direto. E vai ter a mesma mecânica de fechar as cortinas, fechar as coisas."

**Tique** = um comportamento esquisito, curto e roteirizado, que a anomalia de cliente faz **de perto, durante o diálogo**
do Take Order (close no rosto, DEC-353 2ª passada). Serve para duas coisas:

1. **Pista:** deixa a anomalia mais fácil de identificar, no momento em que o jogador decide (ACCEPT / REFUSE).
2. **Susto pequeno:** silêncio, um estalo, um tranco. Não é o jumpscare: o jumpscare continua sendo só a punição do erro
   (DEC-255, DEC-256).

Base: DEC-254..257 (famílias), DEC-353 (diálogo SERVE/REFUSE, close), DEC-352 (escada de sanidade), DEC-172/173 (Mild,
susto leve), `anomalies-v2-proposal.md`, `horror-cinematic.md` §11 (régua do apagão), `gameplay-flow-review.md` §3d e §4.1,
`Q-445`..`Q-448`, `Q-455`..`Q-458`. Estilo: crescendo curto, **silêncio antes do pico**, respiração, uma tarefa simples
(apertar REFUSE / fechar) sob nervos.

## 1. O que muda e o que não muda

| Não muda | Muda |
|---|---|
| A resposta certa de cada anomalia (`Rules/ANM-xxx`), o erro (jumpscare + punição em vigor) e a omissão | **Onde** o sinal principal aparece: parte dele sai da chegada e vai para o close do diálogo |
| A cena de horror de cada anomalia (`Content.HorrorScenes`) — o tique é uma camada a mais | A tela de diálogo ganha eventos (§5) para a cena tocar passos sincronizados com a fala |
| Teto de NPCs: o tique usa o ator que já existe, sem NPC novo | O ator ganha um **estado de tique** replicado (o que ficou depois do tique: pescoço virado, olhos brancos) |
| Servidor decide; o client só apresenta (T10) | O servidor passa a impor o **tempo mínimo de escolha** (§2.3), para o tique sempre caber antes dos botões |

**Resposta certa, em todo este documento**, = a que estiver em vigor para aquela anomalia. Para a família A hoje são
duas formas aceitas (`Q-456` a): **REFUSE no diálogo** ou **fechar a janela/persiana** ("fechar as cortinas"). Exceções
atuais: ANM-005 (servir), ANM-011 (servir puro, `Q-446`), ANM-022 (apagar a luz, `Q-447`). Se o dono mudar uma
resposta por `Q-445`..`Q-447`, o tique **não muda**.

## 2. Regras gerais

### 2.1 Linha do tempo do diálogo (referência para todos os tiques)

Tempos a partir do **T0 = a câmera do close chega** (`OrderTalk.CloseUp.Travel` 0,45 s depois do Take Order).

| Momento | Evento (§5) | O que acontece |
|---|---|---|
| T0 | `Arrive` | close parado no rosto; o "oi" do jogador aparece |
| T0 + 0,4 s | `LineStart` | o cliente começa a fala (máquina de escrever) |
| durante a fala | `LineAt(f)` | fração `f` da fala (0..1); âncora da maioria dos picos |
| fim da fala | `LineEnd` | — |
| `ChoiceAt` | `Choice` | ACCEPT / REFUSE ficam ativos |
| `ChoiceAt` + 4 s / + 8 s | `Idle1` / `Idle2` | o jogador hesitou (só se ainda não escolheu) |
| a qualquer momento | `Leave` | saiu do diálogo sem escolher (botão de sair ou movimento, sessão paralela) |
| escolha | `Refuse` / `Accept` | resolve ou erra pelas regras de sempre |

### 2.2 Tipos de tique

| Tipo | Para que | Teto de intensidade | Exemplo |
|---|---|---|---|
| **Pista** | mostrar o sinal | sem sting alto; no máx. 1 `Shake` Step; sem `Silence` | olhos que ficam brancos numa piscada |
| **Susto** | pista + um susto pequeno | 1 silêncio ≤ 0,6 s, 1 sting ≤ 0,6 de volume, 1 `Jolt`, FOV ≤ 3°, blur ≤ 3 por ≤ 0,5 s | o pescoço que quebra em três estalos |

O pico de todo tique termina **antes** de `ChoiceAt`. Nunca há rosto em tela cheia, vermelho de dano ou "Caught" num
tique: isso é exclusivo do erro.

### 2.3 Tempo de escolha (os botões esperam o tique)

- `ChoiceAt = max(LineEnd + 0,25 s, T0 + ChoiceMin)`, com **`ChoiceMin` = 1,8 s** para **todos** os clientes (normal ou não).
- Duração máxima de um tique (do primeiro passo ao fim do pico): **`TicMax` = 2,4 s** a partir de `LineStart`.
- O **servidor** rejeita `TabletDecide` antes de `ChoiceAt` (o client não pula o tique).
- Efeito colateral aceito: o cliente esquisito fala mais (embolado/quase normal) e por isso demora ~0,5–1 s a mais. Isso é
  pista, não vazamento indesejado: o pedido do dono é ajudar a identificar.

### 2.4 Frequência e anti-spam

| Regra | Valor |
|---|---|
| Tique completo | **1 vez por jogador por ator** (a primeira vez que aquele jogador abre o diálogo com aquele cliente) |
| Reabrir o diálogo com o mesmo ator | só o **resíduo** (§2.6): o estado final, sem silêncio nem sting; botões em `ChoiceMin` |
| Recarga de **Susto** por jogador | **45 s**. Dentro da recarga o tique toca na versão **Pista** (mesmo sinal, sem silêncio/sting/jolt) |
| Noite de estreia da anomalia (`Night` da linha) | versão **Susto** (ensina) |
| Noites seguintes | **Susto** com 40 % de chance, senão **Pista** (sorteio com semente do `NpcId`, igual para o servidor e o client) |
| Noites 7–10 (falas "Almost") | o tique continua 100 % (é a pista que compensa a fala quase normal) |
| Cliente normal | **nunca** tem tique (DEC-278: anomalia não pode se confundir com o fluxo). Ver `Q-463` (tique falso com sanidade muito baixa) |
| Tique × cena da anomalia | a cena (`HorrorScenes`) continua tocando no mundo; durante o close, os passos de câmera da cena (`Fov`, `Shake`, `Nudge`, `Cinema`) ficam **mudos para quem está no close** e os do tique mandam |

### 2.5 Grupo / co-op

- O close e as camadas de tela (silêncio, coração, FOV, blur, texto) são **só de quem atende** (`Who = "Taker"`).
- O **corpo** do tique (o pescoço virando, a cabeça crescendo) é estado do ator, replicado: **todos veem** de onde
  estiverem, e o som principal (estalo, baque) é posicional a ≤ 25 studs. É o "olha o que ela fez!" do grupo.
- Quem assiste pelas câmeras de segurança vê o mesmo corpo (camada `Seen` normal).
- Um diálogo por ator por vez (o tablet já tem um atendente); com 4 jogadores cada um tem a própria recarga de Susto.
- Se outro jogador **fecha a janela** enquanto alguém está no close com a anomalia: resolve como hoje; o close fecha com o
  resíduo do Refuse (§3) para quem atendia.

### 2.6 Sair do diálogo no meio (`Leave`)

Regra única, com variações por ficha:

| Saiu… | O que acontece |
|---|---|
| antes do pico (`LineAt` do pico não chegou) | o tique é **cancelado**; o ator fica no estado de antes; não conta como "visto" (a próxima abertura toca o tique completo) |
| depois do pico | o **resíduo fica** no mundo para todos (ex.: cabeça virada) e a anomalia passa a ter o sinal visível de longe, como era antes desta proposta |
| em qualquer momento | **não é resposta**: não resolve nem erra. Sem penalidade. A paciência volta a correr (`Q-458`). Clientes normais idem |

Sair é seguro de propósito: o jogador que levou um susto pode recuar, chamar o colega e fechar a janela.

### 2.7 Acessibilidade

- **Movimento reduzido** (`Motion.Reduced`, já existe): `Shake`/`Fov`/`Nudge` × `Rules.ReduceMotion`; o corpo do ator
  continua igual (o sinal não depende da câmera).
- **Legenda de som** curta no cartão do diálogo para todo tique com som (ex.: `[neck cracks]`, `[thud]`), em itálico,
  inglês (DEC-022). Opção ligada por padrão.
- **Nenhum tique depende só de cor** (vermelho/verde) nem só de som: todo tique tem um sinal de **forma ou movimento**.
- Piscadas de luz ≤ 3 por segundo e ≤ 0,4 s cada (fotossensibilidade).
- Volume do sting ≤ teto de susto (DEC-173).
- **Mobile:** o rosto ocupa ~35–45 % da altura da tela no close atual (`CloseUp.Distance` 6,5); todo sinal tem que caber
  nessa moldura. Tiques que saem da moldura (cabeça grande, flutuante) fazem a câmera **seguir** (§5.3).
- **Console:** nada novo; X/Y já escolhem.
- Proposta de opção "Close-up scares: Full / Soft" (Soft = sempre a versão **Pista**): `Q-464`.

## 3. Fichas por anomalia

Legenda: **Antes** = sinal sutil antes do diálogo (fila, balcão, câmeras). **Tique** = o que acontece no close, com o
momento e a duração. **Tipo** = Pista ou Susto (na noite de estreia). **Resposta** = a de hoje (não muda).
**Saiu** = o que fica se o jogador sai no meio.

### 3.1 ANM-012 Pescoço invertido — PILOTO

| Campo | Valor |
|---|---|
| Antes | Chega **normal** (cabeça para frente). Sinais sutis: (1) **nas câmeras** a cabeça já está virada e gira devagar (já existe na cena, `Pose Turn Seen = "Cameras"`); (2) **tique de pescoço**: a cada 5–8 s a cabeça dá um repuxão de 6° para o lado e volta em 0,12 s, com um estalinho baixo (volume 0,15) audível a ≤ 8 studs |
| Fala | começa normal, do nível da noite (`OrderTalk`), ex.: "Evening. One hot do—" |
| Tique | `LineAt(0,55)`: a máquina de escrever **congela** no meio da palavra; o som ambiente cai para 0 em 0,15 s (silêncio 0,5 s, só uma respiração). Depois **três estalos**: a cabeça gira 60° + 60° + 60° (0,1 s cada, 0,25 s entre eles), cada estalo pisca a lâmpada sobre o balcão (0,1 s) e dá um `Shake` Step pequeno; no terceiro, 1 `Jolt` + FOV −2,5° volta em 0,8 s. Agora o jogador vê a **nuca**. 0,3 s depois a fala termina **de costas**: "...g. Please." (sem o rosto). Duração: ~1,9 s do congelar ao fim |
| Tipo | **Susto** (estreia N4) |
| Resposta | a de hoje: **REFUSE** no diálogo ou **fechar a janela** (`Rules/ANM-012`, `Q-456`). O que acontece depois: ver `Q-460` |
| Refuse | o close solta; ela sai **andando para a rua com a cabeça olhando para trás**, para o jogador, até o fade (`Kit/Fade`). O `neck_snap` atual (que hoje é a reação ao Refuse) já aconteceu no tique e não repete. Fechar a janela na cara dela mantém o `window_slam` atual (TASK-336) |
| Accept | erro de sempre: jumpscare (o rosto dela de cabeça para baixo) + punição em vigor |
| Hesitou | `Idle1` (4 s): a cabeça inclina 25° de lado, devagar, com um rangido. `Idle2` (8 s): ela sussurra de costas "turn around" (legenda); nada mais |
| Saiu | antes de `LineAt(0,55)`: nada aconteceu, ela segue normal. Depois: cabeça fica **virada para todos** (resíduo `Reversed`) e passa a **seguir o jogador que saiu** (modificador `stare` sobre a cabeça virada) |
| Reabrir | close já mostra a nuca; ela diz "..." ; botões em 1,8 s |
| Custo | **P**: o giro e o `NeckSnap` já existem (`Effects/Kit/OddCustomer`); falta o tique de pescoço, o congelar da fala e o gancho §5 |

### 3.2 ANM-001 Sem rosto

| Campo | Valor |
|---|---|
| Antes | **N1–N3:** cabeça lisa desde a chegada (é a lição da Noite 1; não muda). **N4+:** chega **com rosto normal**; sinal sutil: não pisca e não mexe a expressão (o idle de rosto parado, `HoldStill`) |
| Tique | **N1–N3:** `LineStart`: a fala é "..." e a cabeça lisa **se inclina 20°** devagar enquanto os pontos aparecem (1,2 s); no terceiro ponto a lâmpada do tablet pisca 2× (0,1 s). **N4+ ("o rosto que apaga"):** `LineAt(0,3)` a `LineAt(0,9)`: olhos, focinho e boca **esmaecem** até sumir (1,2 s, crossfade da casca do rosto para a textura lisa), a fala vai perdendo letras junto ("Hi, c-n I g-t a…" → "...") |
| Tipo | N1–N3 **Pista**; N4+ **Susto** leve (no fim do esmaecer: silêncio 0,4 s e um `Jolt`) |
| Resposta | REFUSE / janela |
| Saiu | antes do esmaecer: rosto normal; depois: fica **liso** para todos |
| Custo | N1–N3 **P** (`Pose Tilt`); N4+ **M** (crossfade de duas texturas de rosto; precisa do art-director para a casca lisa casar com o rosto, DEC-152) |

### 3.3 ANM-013 Olhos brancos

| Campo | Valor |
|---|---|
| Antes | olhos normais. Sinal sutil: **brilho** nos olhos (ponto de luz pequeno que não acompanha a luz da sala); nas câmeras os olhos já são brancos (`Seen = "Cameras"`) |
| Tique | `LineAt(0,5)`: o cliente **pisca** (0,15 s, pálpebra) e abre com os **olhos totalmente brancos**; a luz do balcão cai a 40 % por 0,6 s e os olhos **iluminam o rosto do jogador** (`Lantern Eyes`, alcance 6); um zumbido grave sobe e corta. Duração 1,1 s |
| Tipo | **Susto** leve (estreia N5) |
| Resposta | REFUSE / janela |
| Refuse | os olhos continuam acesos atrás da persiana 1 s (o Resolved da cena já faz) |
| Hesitou | `Idle1`: os **outros clientes** da fila viram a cabeça para o jogador juntos (`Pose Turn Value 1`, já existe) |
| Saiu | depois do pico: olhos brancos ficam para todos |
| Custo | **P**: textura de olho branco já existe (DEC-245); falta a troca no meio da piscada |

### 3.4 ANM-014 Cabeça errada

| Campo | Valor |
|---|---|
| Antes | cabeça **×1,15** (sutil; hoje entra ×1,9). Nas câmeras ela já bate no teto (cena) |
| Tique | durante a fala, a cabeça cresce em **dois degraus** com rangido de couro: `LineAt(0,35)` ×1,15 → ×1,5; `LineAt(0,75)` ×1,5 → ×1,9. A cada degrau a câmera do close **sobe e recua** um pouco para manter o rosto na moldura (§5.3) e o FOV abre 1,5°. No segundo degrau a cabeça encosta na luminária, que balança (`Prop Sway`). Duração 1,8 s |
| Tipo | **Pista** com um susto mínimo (o segundo degrau) |
| Resposta | REFUSE / janela |
| Saiu | antes do 1º degrau: ×1,15; depois: o último degrau atingido |
| Custo | **P**: `bighead` já escala; falta escalar em degraus (hoje é fixo) |

### 3.5 ANM-015 Flutuando

| Campo | Valor |
|---|---|
| Antes | flutua **0,15 stud** (hoje 0,7) e **não tem som de passo** (os outros têm) |
| Tique | `LineStart` até `LineEnd`: o corpo sobe devagar **+1,2 stud**; a câmera do close **acompanha para cima** sem cortar o rosto, então quem atende sente a "câmera" subir e vê o balcão sumir embaixo; guardanapos perto sobem junto (`Prop Float`). `LineEnd`: zumbido corta, **cai de uma vez** de volta a 0,15 com baque e `Jolt`. Duração ≈ duração da fala (≤ 2,4 s) |
| Tipo | **Susto** leve (o baque) |
| Resposta | REFUSE / janela |
| Saiu | fica a 0,7 stud (o sinal atual) |
| Custo | **P/M**: `float` existe; falta a altura animada e a câmera que segue |

### 3.6 ANM-016 Não pisca

| Campo | Valor |
|---|---|
| Antes | a cabeça segue a câmera de quem olha (modificador `stare`, já existe); os outros clientes piscam, ele não |
| Tique | `LineAt(0,6)`: **o jogador pisca** (tela preta 0,12 s, com som de respiração curta). Quando a tela volta, o cliente está **mais perto**: o close avança 0,8 stud e o rosto ocupa mais a tela; ele não mexeu a boca nem os olhos. Duração 0,6 s |
| Tipo | **Susto** (estreia N9) |
| Resposta | REFUSE / janela |
| Hesitou | `Idle1`: nova piscada do jogador e +0,5 stud. Para aí (no máximo 2 avanços) |
| Saiu | a cabeça segue quem saiu; o `stare_front` atual continua valendo |
| Custo | **P**: a piscada é um `Cinema`/tela preta já existente; o avanço é o `Distance` do close |

### 3.7 ANM-004 A cópia (gêmeos)

| Campo | Valor |
|---|---|
| Antes | roupa espelhada + olhos brancos (DEC-245), chega 2 s depois do original (`CopyDelay`) |
| Tique | **eco**: a fala da cópia é **a mesma fala, letra por letra**, que o original disse para o mesmo jogador; no fim ela **repete o "oi" do próprio jogador** ("Hi! How can I help?"). Enquanto fala, a cabeça **imita a câmera com atraso** de 0,4 s (`Pose Mimic`). Duração = a fala |
| Tipo | **Pista** (o arrepio é perceber o eco) |
| Resposta | REFUSE / janela (`Q-451` b) |
| Saiu | nada fica no corpo (a pista é a fala); reabrir repete o eco |
| Custo | **P**: o servidor já sabe quem é o original (`CopyOf`); guarda a última fala dele |

### 3.8 ANM-023 A da câmera

| Campo | Valor |
|---|---|
| Antes | normal pessoalmente; quebrada nas câmeras (Q-437, já existe) |
| Tique | `LineAt(0,5)`: o close **corta** por 0,2 s para a imagem da câmera da frente (CAM3, granulado de CCTV, "REC"): o corpo dela está **todo quebrado e a cabeça encosta na lente**. Volta ao close: ela está normal, sorrindo, terminando a fala. Um chiado de estática acompanha o corte |
| Tipo | **Susto** (estreia N10) |
| Resposta | REFUSE / janela |
| Hesitou | `Idle1`: segundo corte de 0,15 s |
| Saiu | nada fica a olho nu (a regra dela é a câmera) |
| Custo | **M**: o close precisa de um corte para o CFrame de uma câmera de segurança e de marcar `SecurityView` local por 0,2 s (o modificador `oncam` já reage a isso) |

### 3.9 ANM-011 O que treme

| Campo | Valor |
|---|---|
| Antes | o ambiente treme perto dele (cena atual: copos, luminária) |
| Tique | a fala embolada ("H-h-hungry…") vem com o **rosto tremendo** no close (o tremor do corpo, que no celular não se lê de longe, aqui ocupa a tela). Na última palavra **para tudo de uma vez**: silêncio 0,5 s, ele olha direto para o jogador, e a fala termina limpa e baixa: "...just bread." |
| Tipo | **Pista** (o "just bread" é a dica da regra atual) |
| Resposta | a de hoje: **servir puro** (ACCEPT e entregar sem cobertura). Se `Q-446` (a) passar, vira REFUSE/janela e a última fala muda para algo sem dica |
| Saiu | volta a tremer |
| Custo | **P** |

### 3.10 ANM-022 O que bate a cabeça

| Campo | Valor |
|---|---|
| Antes | a cabeça pende para frente (`banger`, já existe) |
| Tique | começa de cabeça baixa, sem falar; `LineStart` ela **ergue a cabeça devagar** (0,8 s); `LineAt(0,6)` **bate a testa no balcão** uma vez (baque, `Jolt`, a lâmpada pisca, o tablet escondido "pula" no som). Fala: "...light... too bright..." |
| Tipo | **Susto** (estreia N8) |
| Resposta | a de hoje: **apagar a luz da loja** (`Q-447` b propõe janela). Pendência técnica: confirmar o que o REFUSE do diálogo faz com ela hoje (o `Verb` do rule é "refuse" só para o kit pegar o ator; §6) |
| Saiu | bate a testa no balcão a cada 2–3 s (só som e balanço da cabeça) até a resposta |
| Custo | **P** |

### 3.11 ANM-005 Raincoat Lady (exceção, servir)

| Campo | Valor |
|---|---|
| Antes | capa amarela pingando em noite seca, poça que cresce (cena atual) |
| Tique | **tique gentil**, para não ensinar "recuse": gotas caem **sobre o cartão do diálogo** e escorrem pelo texto (3–4 gotas, 1,5 s); ela fala de olhos fechados, carinhosa (`ByVariant raincoat`); som de chuva baixinho que só existe no close |
| Tipo | **Pista** (nunca Susto) |
| Resposta | **servir** (ACCEPT e entregar) |
| Saiu | a poça volta a crescer (a paciência dela volta a correr) |
| Custo | **P** (sobreposição de gotas na UI) |

### 3.12 Fora desta proposta

- **Carro do drive-thru com diálogo** (sessão "Restaurar UI de conversa"): as anomalias de carro (ANM-031 no V3, ANM-008)
  podem ganhar tique no mesmo gancho depois (ex.: o alto-falante responde com a voz do jogador). Não entra agora.
- Famílias B, C, D: não têm diálogo; ficam como estão.

## 4. Os primeiros a fazer

| Ordem | Tique | Por quê | Custo |
|---|---|---|---|
| 1 | **ANM-012 pescoço (piloto)** | pedido literal do dono; peças já existem (`neck`, `NeckSnap`, estalo); exercita todo o gancho (congelar fala, silêncio, resíduo, `Leave`) | P + gancho |
| 2 | **ANM-013 olhos que viram brancos** | a troca de textura já existe; tique de 1,1 s, muito legível no celular | P |
| 3 | **ANM-004 eco da cópia** | só texto + dado que o servidor já tem; dá arrepio sem efeito caro | P |
| 4 | **ANM-014 cabeça em degraus** | testa a câmera que segue o ator (§5.3), que o 015 também usa | P |
| 5 | **ANM-001 rosto que apaga (N4+)** | a anomalia mais frequente do jogo ganha variação tardia; depende do art-director | M |

O gancho (§5) é feito uma vez com o piloto; os outros são só dado + passos de cena.

### 4.1 Critérios de aceite (piloto e gancho)

1. Com `/dev` forçando ANM-012, o cliente chega com a cabeça para frente a olho nu e virada nas câmeras.
2. O repuxão de pescoço acontece a cada 5–8 s na fila e não acontece em cliente normal.
3. No Take Order, a fala congela em ~55 % e os três estalos tocam antes de ACCEPT/REFUSE ficarem ativos; o servidor
   recusa `TabletDecide` antes de `ChoiceAt` (testar mandando o pacote cedo).
4. Um segundo jogador a ≤ 25 studs **vê** a cabeça girar e ouve os estalos, sem silêncio, FOV ou texto na tela dele.
5. Sair do diálogo antes do congelar: ela continua normal e a próxima abertura toca o tique inteiro. Sair depois: a
   cabeça fica virada para todos e segue quem saiu. Nenhum dos dois casos resolve, erra ou tira sanidade.
6. Reabrir depois do tique: sem silêncio nem estalo; botões em 1,8 s.
7. Segundo tique de Susto do mesmo jogador em < 45 s toca a versão Pista (sem silêncio, sem sting, sem jolt).
8. REFUSE resolve como hoje; ACCEPT erra como hoje; fechar a janela resolve como hoje.
9. Com movimento reduzido ligado, nenhum `Shake`/`Fov` passa de `Rules.ReduceMotion` × o valor; o giro da cabeça é igual.
10. Legenda `[neck cracks]` aparece no cartão durante os estalos.
11. Cliente normal: `ChoiceAt` = `T0 + 1,8 s` (mesma regra); nenhum passo de tique toca.
12. `modux check` e `tools/analyze.ps1` sem erro; `Validate` rejeita tique com pico depois de `TicMax`.

### 4.2 Piloto aplicado (2026-10-21, Provisório, sem DEC)

O dono mandou implementar o piloto conforme as recomendações. Aplicado no código (estático: `analyze.ps1` 0 erro; falta
o Play do dono):

| Item | Como ficou | Onde |
|---|---|---|
| Dados | `Content.Tics` (módulo novo): linha da ANM-012 por `Variant = "neck"`, `Rules` (`ChoiceMin` 1,8 · `ChoiceAfter` 0,25 · `TicMax` 2,4 · `TypeRate` 28 letras/s · `HearRange` 25), `Timing` e `LineAt` puros (servidor e clients usam o mesmo relógio, sem pacote novo). `Validate` (`checkTics`): chave em `Content.Anomalies` com `Actor = "Customer"`, um `Variant` por linha, último estalo dentro de `TicMax`, passos só `Silence`/`Shake`/`Fov`/`Blur`/`Sound` dentro dos tetos do §2.2, nunca `Scare` na ANM-005 | `src/Shared/Content/Tics.luau`, `Validate.luau` |
| Antes (Q-459 a) | chega com a cabeça para frente; repuxão de 6° a cada 5–8 s (0,12 s, estalinho 0,15 a ≤ 8 studs); pelas câmeras a cabeça aparece virada e balançando. Sem a linha em `Content.Tics` volta o modificador antigo (rollback sem código) | `Effects/Kit/Tic.luau`, `Kit/OddCustomer.luau` |
| Fala | "Evening. One hot dog, please." digitada a 28 letras/s, **congela** em "Evening. One hot do" (Freeze 0,65 ≈ 0,68 s), 0,5 s de silêncio, 3 estalos de 60° (0,1 s cada, 0,25 s entre eles; pico = 1º estalo ≈ 1,18 s), legenda `[neck cracks]` no cartão durante os estalos, 0,3 s depois termina de costas ("g, please."). Fim da fala ≈ 2,64 s depois do início dela | `TabletController` (`lineOf`) |
| Camadas | corpo (giro) e estalos (`neck_crack` 0,8 a ≤ 25 studs) para **todos**; silêncio, `Shake` Step ×2 + `Jolt` + FOV −2,5° só para quem atende, e só enquanto o close dele está aberto | `Kit/Tic.luau` |
| Botões (Q-462 a) | `ChoiceAt = max(fim da fala + 0,25 s, chegada do close 0,45 s + 1,8 s)` para **todo** cliente: normal 2,25 s (era 2,0), ANM-012 com tique ≈ 4,1 s. O servidor ignora `TabletDecide` antes disso | `TabletService` |
| Resposta (Q-460 a) | igual a hoje: REFUSE no diálogo e fechar a janela resolvem; ACCEPT = susto + punição. Depois do tique o `neck_snap` da recusa não repete (a cabeça já está virada); ela sai andando com a cabeça olhando para trás | `Rules/ANM-012` intocado; `OddCustomer` |
| Sair | antes do pico: o tique é cancelado (atributos saem, ela volta ao normal, a próxima abertura toca inteiro); depois: resíduo `Reversed` para todos e a nuca segue quem saiu enquanto essa pessoa estiver na frente dela (≤ 20 studs, ±80°). Sair nunca resolve, erra nem custa sanidade (é o mesmo Cancel) | `TabletService` (`settleTic`) |
| 1 vez | o tique completo toca uma vez por cliente (o resíduo no rig vale para todos; reabrir = fala "..." e botões em 2,25 s). O pool de NPC limpa os atributos ao reusar o rig | `TabletService`, `NpcService/Pool.luau` |
| Teste | `/dev trigger ANM-012`, `/dev tic` (estado, `ChoiceAt`, atributos), `/dev tic early [accept]` (escolha antecipada, deve ser ignorada), `/dev tic reset` | `Dev/.../Commands/Tic.luau`, `docs/tech/dev-commands.md` |

Rede: atributos no rig (`TicAt` = hora do servidor do início da fala, `TicUser`, `Tic = "Done"`, `TicFollow`), 2–4
escritas por tique. Não entrou no piloto: Susto/Pista por noite e a recarga de 45 s (sempre Susto), `Idle1`/`Idle2`,
pisca da lâmpada a cada estalo, eventos genéricos `LineAt`/`Phase = "Talk"` nas cenas, silenciar os passos de câmera da
cena durante o close (§2.4), opção Full/Soft (`Q-464`), demais anomalias.

### 4.3 Próximos tiques aplicados (2026-10-22, Provisório, sem DEC)

Pedido do dono: "Implementa os próximos tiques da proposta na conversa: ANM-013 (olhos brancos), ANM-004 (cópia repete
a fala) e ANM-014 (cabeça cresce), no mesmo molde do piloto ANM-012." Fluxo da conversa em vigor: o cliente diz só o
"oi" (Greeting), o jogador escolhe ACCEPT/REFUSE (Deciding) e só o cliente comum faz o pedido depois (Talking). A fala
estranha e o tique tocam no Greeting, antes da escolha. Estático (`analyze.ps1` 0 erro); falta o Play do dono.

Molde comum (generalizado a partir do piloto): a linha de `Content.Tics` ganhou `Body` (`Neck` / `Eyes` / `Head` /
`Echo`); os estalos viraram `Beats` (contagem, duração, intervalo, volume e **som** da batida); `Said` dá a fala de cada
conversa (o eco depende do original e de quem atende) e `Timing`/`LineAt` usam ela. Resíduo novo: `White`, `Big`, `None`.
Atributos novos no rig: `TicEnd` (hora em que saiu entre o pico e a última batida: a cabeça fica no degrau atingido) e
`TicEcho` (NpcId do original). Locais (só no client, nunca replicados): `TicFace` (lido pelo `RigController`) e
`TicScale` (lido pelo close do `TabletController`). Sem pacote novo. Tempos a partir do início da fala do cliente
(`Talk.Open` 1,2 s depois do Take Order).

| Tique | Antes do diálogo | Tempo a tempo | Camada de tela (só quem atende) | Sair | Onde |
|---|---|---|---|---|---|
| **ANM-013** olhos brancos (Susto leve) | olhos **normais** com um brilho frio no rosto que não segue a luz da sala; **pelas câmeras** os olhos já são brancos. Antes chegava com os olhos brancos (`RigController` `VARIANT_FACE`); a cena não acende mais os olhos **dela** no escuro do balcão (Lantern Eyes em Q1). Ficam: a fila virando a cabeça, os olhos lá fora, o `Stare` | "Hi. One hot dog, please. Extra warm." digitada; **0,64 s** congela em "Hi. One hot dog, p"; 0,64–0,79 a pálpebra desce (casca do rosto some); **0,79 = pico**: abre com os olhos brancos para todos, `hum_rise` (0,5, ≤ 25 studs), luz fria (SpotLight, alcance 6, 70°) dos olhos para a frente, 3 → 0,8 em 0,6 s; 1,39 o zumbido corta; 1,74 retoma; fim 2,39; botões ≈ 3,84 s após o Take Order | silêncio 0,45 s, 1 `Jolt` (0,5), `Grade Cold` 0,45, `Vignette` 0,3 (a "luz do balcão a 40 %"), `hum_die` no corte; fica um frio leve (0,15) enquanto o close dura; legenda `[low hum]` | antes do pico: cancela (olhos normais, toca inteiro na próxima); depois: olhos brancos + luz fraca para todos | `Content.Tics` (`eyes`), `Kit/Tic` (`Eyes`), `Kit/OddCustomer`, `RigController` (`TicFace`), cena `anm_013` |
| **ANM-004** eco da cópia (Pista) | como a ficha: roupa espelhada + olhos brancos; a cena (Mimic, câmeras sem ela) e o `Stare` ficam | a cópia diz, letra por letra, o "oi" com que o **original** abriu a conversa com **este** jogador (o último cliente comum que ele atendeu; sem nenhum, o "oi" da própria cópia); pausa de **0,6 s** (pico); depois o "oi" do próprio jogador com o **nome** dele: "Hi! What can I get you, Victor?"; enquanto diz a fala do jogador a cabeça inclina 14° e volta no fim. Ex.: "Hi!" (0,11 s) → pico 0,71 → fim ≈ 1,85–2,9 s conforme o nome; botões ≈ 3,3–4,4 s | `breath_held` (0,5) no pico, `Grade Cold` 0,15; sem silêncio nem tranco (Pista); o balão de quem está perto mostra a fala inteira, com o nome | nada fica no corpo (`Residue None`): sair ou terminar apaga os atributos; reabrir repete o eco | `Content.Tics` (`mirror`), `TabletService` (`TicEcho`), `TabletController` (`lineOf`), `Kit/Tic` (`Echo`), `Effects/ANM-004` |
| **ANM-014** cabeça cresce (Pista + susto mínimo) | `Q-461` a: chega **×1** (sem o ×1,15 da ficha e sem o ×1,9 de antes); **pelas câmeras** já está ×2,6. Saíram da cena: o crescimento enquanto ninguém olha (`Pose Scale` 1,12/1,24/1,36/1,5), o `Pose Scale` das câmeras (agora é o corpo do tique) e a luminária que ela batia (`Prop Sway`) | "Evening. I'd like a hot dog. Please."; **0,5 s** congela em "Evening. I'd l"; **0,6 = pico**: rangido (`door_creak` 0,6, no lugar de `stretch_creak`) e ×1 → ×1,45 em 0,25 s; **1,3**: segundo rangido, ×1,45 → ×1,9; 1,8 retoma; fim 2,59; botões ≈ 4,0 s | o close **sobe e recua** com a cabeça (a mira segue a cabeça, a lente recua 0,6 × o crescimento, FOV +3° por 1,0 de crescimento ≈ +2,7° no ×1,9); 1 `Shake Step` no 2º degrau; legenda `[leather creaks]` | antes do pico: ×1; depois: fica no último degrau atingido (`TicEnd`), para todos | `Content.Tics` (`bighead`), `Kit/Tic` (`Head`), `Kit/OddCustomer`, `TabletController` (close que segue), cena `anm_014` |

Em todos: corpo para todos, camada de tela só de quem atende e só com o close dele aberto; a resposta certa não mudou
(`Rules/ANM-004/013/014` intocados: REFUSE ou janela resolvem, ACCEPT = erro); sair nunca resolve, erra nem custa
sanidade (é o mesmo Cancel do piloto). `ChoiceAt` segue `max(fim da fala + 0,25 s, chegada do close + 1,8 s)`.
`Validate` (`checkTics`) cobra os campos de cada `Body`, o pior caso do eco (o "oi" mais longo + nome de 20 letras) dentro
de `TicMax`, Pista sem silêncio e com no máximo 1 `Shake Step`, `Grade` ≤ 0,5, `Vignette` ≤ 0,35, som de passo ≤ 0,6.
Teste: `/dev trigger ANM-013|ANM-004|ANM-014`, Take Order, `/dev tic` (agora mostra o `Body`, o relógio da fala, o
texto e `TicEnd`/`TicEcho`), `/dev tic reset`. Não entrou: Susto/Pista por noite e recarga de 45 s, `Idle1`/`Idle2` (ex.:
a fila virando a cabeça na 013), luminária balançando no 2º degrau da 014, imitar a câmera com atraso na 004 (no close a
câmera fica parada, então virou a inclinação), queda real da luz do balcão (virou `Vignette`), silenciar os passos de
câmera da cena durante o close, `Q-464`. Pergunta nova: `Q-465` (o nome do jogador no eco).

### 4.4 A tensão começa na conversa, sincronizada com o tique (2026-10-22, Provisório, sem DEC)

Pedido do dono: "Executou o take order, ele começa falando normal. Aí, dependendo do tipo da anomalia, por exemplo, quebra o
pescoço: no meio da fala do texto sendo gerado, coloca 3 pontinhos no texto, trava a geração dos textos por 1 segundo, 2
segundos, faz a animação do pescoço quebrado. Só que antes da animação acontecer começa a aparecer as barras, aí quebra o
pescoço, e na hora que quebra — bum — começa os sussurros na mesma hora, junto com o heartbeat. O heartbeat começa lento
quando aparecem as barras e vai acelerando até chegar no ápice; aí fica na velocidade normal dele." Também as "paradinhas"
(silêncios), o efeito de tela e o título com a dica no mesmo momento. Antes disso a tensão (barras, sussurros, borda, cor,
coração, título) só começava quando a anomalia entrava na fila (`Queue`, `anomalies-after-accept-proposal.md` §9.2).
Estático (`analyze.ps1`); falta o Play do dono.

**Molde (os quatro tiques: 012, 013, 014, 004), dados em `Content.Tics`:**

| Peça | Como ficou | Onde |
|---|---|---|
| Fala | no ponto do `Freeze` entra `Rules.Trail` = "..." **no próprio texto** (digitado com ele) e a digitação trava `Hold` = **1,5 s** em todos (era 0,5 / 0,15 / 0,6 / 0,1). Ex.: "Evening. One hot do...g, please." Depois do ápice o resto sai desfigurado (o `Break` do estilo, como antes). O servidor continua decidindo o tempo: `Timing`/`EndsAt` já cobrem a trava; sair antes do ápice (`Peak`) cancela o tique, como antes | `Tics.luau` (`Said`, `Echo`, `Timing`) |
| Construção (trava) | `Rules.Tension` (+ `Tension` da linha) vira passos de cena (`Tics.Layers[key]`, `At` = s a partir do ápice): no começo da trava as **barras** entram (0,09 em 0,6 s), a sala abaixa (`Silence` → 0,55), a borda cresce até metade e o **coração começa lento e acelera** (86 → 170 BPM em 1,25 s: três batidas, ~A−1,5 / A−0,8 / A−0,35 s) | `Tics.luau` (`layerOf`), `Effects/Kit/Tic` |
| Paradinha | **0,25 s antes do ápice** a sala vai a 0 e o coração para | idem |
| Ápice ("bum") | é a 1ª batida do tique (o pescoço quebra, os olhos abrem brancos, a cabeça cresce; no eco, o fim da pausa). No mesmo instante: SFX `whisper` + **sussurros com a dica** (`hint_<key>` 2,2 s, depois `queue_<key>`; dica não `Live` = lista genérica, como na fila), **título com a dica** (`Title`/`Hint` + `Line` de `Content.AnomalyHints`, 3 s, só dica `Live`), **tranco** (`Jolt`; Pista = `Step`) + FOV (−2,5°; Pista −1,5°) + blur 2,5 (Pista 0), **cor** (`Cold`, 014 `Sick`) e borda cheia; o **coração volta ao ritmo normal** (96 BPM) e segue | idem |
| Depois | a sala volta 0,4 s após o ápice; aos 2,2 s os sussurros ficam baixos (0,12) **até a entrega**; o coração a 96 **até a entrega**; aos **8 s** as barras saem e cor/borda descem a 40 % e ficam até a entrega; teto de 180 s (`Tension.Max`) | idem |
| Batidas próprias | `Steps` da linha agora contam a partir do ápice: 012 `Step` no 2º e 3º estalo; 013 `hum_die` 0,6 s depois; 014 `Step` no 2º degrau; 004 `breath_held` no ápice. A 013 fica de **olhos fechados** a trava inteira (a piscada virou a construção) | `Tics.luau` |
| Tranco no close | o close da conversa é modo `Prep` da câmera, onde a camada de horror (`HorrorShake`/`HorrorFov`) não tocava: os `Shake`/`Fov` dos tiques nunca apareciam. Agora tocam no `Prep` **enquanto o close da conversa está aberto** (atributo `TalkCloseUp`); foco de cozinha e monitor de segurança ficam como estavam | `CameraController` |
| Cartão | o cartão da conversa e o Back ficam **por cima** das barras (DisplayOrder 42; barras 40) | `TabletController` |

**Quem vê o quê (decisão do agente, Provisória):** a camada de tela (barras, coração, paradinha, sussurros, título,
tranco, cor) é **só de quem atende** e só com o close dele aberto. Os outros jogadores **não** recebem barras nem sussurros
na conversa: veem o corpo (o tique) e ouvem as batidas posicionais (≤ 25 studs), como antes. Quando o pedido é anotado,
eles recebem a tensão da fila do zero, como hoje (precisam da dica para entregar em co-op).

**Fila sem recomeçar:** do ápice em diante a tensão de quem atendeu é **carregada** (`Scene/Carry`): sobrevive ao fim do
close e da conversa (ou a ele sair depois do ápice) e termina quando o registro dela vira `Resolved`/`Failed`/some. Enquanto
carrega, a cena dela na `Queue` **não toca para esse cliente** os passos de tela (`Rules.Carry`: Cinema, Whispers,
Heartbeat, Vignette, Grade, Silence, Blur, Fov, Shake, Nudge, Text, e os stings sem `Point` de `Rules.CarrySounds`) e o
`Score` não repete o título; corpo, props, luzes, `Pose` e sons no mundo da cena continuam. Música (`Tension` da 012/014)
igual para todos. Sair **antes** do ápice: nada começa (barras saem, coração para, a sala volta).

**Linha do tempo (s desde o Take Order; fala começa em 0,5; A = ápice):**

| ANM | Texto | "..." / trava | barras + coração | paradinha | A (bum: batida, sussurros, título) | depois | pedido anotado (fila) |
|---|---|---|---|---|---|---|---|
| 012 pescoço | "Evening. One hot do...g, please." | 1,51 → 3,01 | 1,51 (batidas ~1,51 / 2,2 / 2,67) | 2,76 | **3,01** 1º estalo (+ 3,36, 3,71) · título DON'T LOOK / EYES DOWN… | sala 3,41 · retoma 4,11 · fim 4,56 · sussurro baixo 5,21 · barras saem 11,01 | 5,46 |
| 013 olhos | "Hi. One hot dog, p...lease. Extra warm." | 1,57 → 3,07 (olhos fechados) | 1,57 | 2,82 | **3,07** abre branco + `hum_rise` · sem título (dica não Live), sussurro genérico | `hum_die` 3,67 · retoma 4,02 · fim 4,88 · barras saem 11,07 | 5,78 |
| 014 cabeça | "Evening. I'd l...ike a hot dog. Please." | 1,33 → 2,83 | 1,33 | 2,58 | **2,83** 1º degrau ×1,45 (+ 3,53 ×1,9) · título BE QUICK / SERVE IT BEFORE… | retoma 4,03 · fim 5,03 · barras saem 10,83 | 5,93 |
| 004 cópia | "Hi!... Hi! What can I get you, Victor?" (o "oi" do original varia) | 0,71 → 2,21 ("Hi!") a 1,39 → 2,89 ("Hi, how's it going?") | idem | A − 0,25 | **2,21–2,89** fala do jogador + `breath_held` · sem título, sussurro genérico | fim 3,7–4,9 · barras saem A + 8 | 4,6–5,8 |

**Anomalias sem tique** (005, 011, 015, 016, 022, 023; a 001 ganhou o dela em §4.5): ficam como estão (tensão ao entrar na fila). Aplicar o molde
com uma batida genérica não é trivial: cada uma precisaria de linha de fala própria em `Content.Tics`, um corpo novo e o
servidor passaria a tocar o tique nela (a 011 é de outro agente nesta rodada).

Teste: `/dev trigger ANM-012` (ou 013, 014; a 004 precisa falar antes com o original), esperar no balcão, **Take Order**
e olhar: "..." no texto, barras + coração lento acelerando, silêncio curto, estalo + tranco + sussurros + título, coração
a 96, fala termina desfigurada; depois da anotação a fila **não** repete barras/título para quem atendeu, e as barras saem
~8 s após o ápice; sussurros e coração até entregar. Sair (Back) antes do ápice: nada fica. Um 2º jogador perto: só o
corpo e as batidas na conversa, a tensão da fila do zero. `/dev tic` mostra freeze/hold/ápice/fim da fala desta conversa.

### 4.5 ANM-001 "rosto que apaga" e a pele no sem-rosto (2026-10-22, Provisório, sem DEC)

Relato do dono (2026-10-22): "quando o cliente anomalia chega, ele já tá chegando sem rosto... E por que o sem rosto dele tá
com a pele branca? Não deveria ser assim. Ele deveria manter a cor de pele dele." Pelo modelo novo (DEC-354/355) a chegada
não pode entregar o sinal. A ficha §3.2 previa cabeça lisa desde a chegada nas N1–N3 e o "rosto que apaga" só na N4+; o
pedido do dono passa por cima: **o rosto que apaga vale desde a N1**. Estático (`analyze.ps1`); falta o Play do dono.

**Pele branca (causa):** o `RigController` vestia a variante `blank` com `Dress(..., blank = true)`, que trocava a textura
da cabeça pela `T_Head_<A>_Blank` (AST-060: **uma cor só, opaca, a pelagem do Dia**, sem manchas, focinho nem nariz) e o
atlas por uma cópia com orelhas/rabo/nariz repintados; e ainda forçava o pacote **Night** (`NIGHT_VARIANTS`). Com o corpo
escurecido do Night, aquela cabeça chapada do Dia virava um bloco claro; nas espécies claras (panda, coelho, ovelha) fica
**toda branca**, orelhas cinza (o print do dono; reproduzido no Studio com panda, gato e cachorro). Correção: a variante
usa só a face `Blank` (casca do rosto transparente: some olhos, boca e bochechas) sobre a **cabeça da própria espécie** no
pacote que ela veste (pelagem, manchas e nariz ficam), e saiu de `NIGHT_VARIANTS` (veste o pacote de todo cliente, Mid à
noite). `BLANK_HEAD = false` no `RigController` desliga a troca antiga (rollback = `true`); as texturas AST-060 ficam sem uso.

**Chegada normal:** com a linha `Body = "Face"` em `Content.Tics`, o `RigController` mostra o **rosto comum** (o humor dele)
até o `TicFace` local nomear outro, então ele nunca chega sem rosto, nem antes do efeito montar. Pelas **câmeras** já
aparece sem rosto. Fica o sinal sutil de antes: não respira (`HoldStill`).

**Linha do tempo (s desde o Take Order; fala começa em 0,5):**

| t | O que acontece |
|---|---|
| 0,5 → 1,26 | "Hi. Can I ge" digitado normal, rosto e humor dele |
| 1,26 | **"..."** entra ("Hi. Can I ge...") e a digitação trava 1,5 s; barras + sala abaixa (0,55) + coração 86 → 170 + borda até a metade (só quem atende) |
| 1,26 → 2,76 | o **rosto apaga** (a casca do rosto some aos poucos, devagar e depois rápido, `t²`) e as **letras caem** uma a uma, em ordem sorteada fixa (~80 % das letras; a pontuação fica: sobra algo como ". ...") e piscam |
| 2,51 | paradinha: sala e coração em silêncio (o rosto já ~70 % apagado) |
| **2,76** | **ápice**: o rosto some de vez para **todos** (face `Blank`), `suspense_hiss` (0,5, ≤ 25 studs), legenda `[soft hiss]`; só quem atende: `whisper` + sussurros (lista genérica: a dica da 001 ainda não é `Live`, sem título), `Jolt` + FOV −2° + blur 1,5 + cor `Cold` 0,35 + borda 0,25, coração a 96 |
| 3,16 | a sala volta |
| 3,51 → 4,32 | o resto sai **perdendo letras** ("t a hot dog, please?": metade das letras cai 0,35 s depois de digitada, texto mais apagado e piscando) |
| 4,96 | sussurros baixos até a entrega |
| **5,22** | pedido anotado; ele vai para a fila **sem rosto** (resíduo, para todos) |
| 10,76 | barras saem; cor e borda ficam a 40 % até a entrega |

Sair antes do ápice: cancela (rosto volta inteiro, a próxima conversa toca de novo). Depois: fica sem rosto para todos.
Reabrir depois: fala "...". Tipo **Susto leve** (é a primeira anomalia da run): tranco e blur menores que os da 012.

| Peça | Onde |
|---|---|
| Linha `blank` (`Body = "Face"`, `Face = "Blank"`, `Residue = "Blank"`, fala, `Hold` 1,5, 1 batida `suspense_hiss` 0,4 s, `After` 0,35, `Tension`) | `src/Shared/Content/Tics.luau` (+ `Validate` `checkTics`) |
| Corpo `Face`: rosto comum antes, apaga na trava (`LocalTransparencyModifier` da casca), `Blank` do ápice em diante, na fila e nas câmeras | `Effects/Kit/Tic.luau` (`faceBody`), montado por `Effects/ANM-001.luau` |
| Letras que caem: efeito novo `Drop`/`DropTime` (letra some de vez, uma a uma, pontuação fica); estilo `Blank` (`Tic`: Drop 0,8 em 1,5 s + Flicker 0,3; `Break`: Drop 0,5 em 0,35 s + Fade 0,3 + Flicker 0,2) | `Content.OrderTalk` (`Styles.Blank`, `StyleByVariant.blank`), `Interface/.../TypedText` |
| Rosto comum até o tique, pele da espécie, fora do Night | `src/Crew/client/RigController.luau` (`FACE_WAITS`, `BLANK_HEAD`, `NIGHT_VARIANTS`) |

Teste: `/dev trigger ANM-001`, esperar no balcão (rosto normal a olho nu; sem rosto pelas câmeras), **Take Order**: "..."
no texto, barras + coração, o rosto apagando com as letras caindo, ápice com o chiado e o tranco, o resto da fala sem
letras; na fila ele fica sem rosto, com a pele da espécie. `/dev tic` mostra o relógio; `/dev tic reset` devolve o rosto.

## 5. Esboço de dados e gancho técnico (alto nível, sem código)

### 5.1 Dados: `Content.Tics` (módulo novo, replicado, só apresentação)

Separado de `Content.Anomalies` (que não pode ter verbo, T10) e no mesmo estilo de `Content.HorrorScenes`: uma linha por
anomalia, chave = chave da anomalia.

| Campo | Tipo | Exemplo (ANM-012) | Para quê |
|---|---|---|---|
| `Key` | string | `anm_012_turned_neck` | = `Content.Anomalies` |
| `Kind` | `"Clue"` \| `"Scare"` | `Scare` | tipo na noite de estreia |
| `ScareChance` | número 0..1 | 0,4 | chance de Susto nas noites seguintes |
| `Pre` | `{ Kind, Every, Value, Seen }?` | `{ Kind = "Twitch", Every = {5, 8}, Value = 6 }` | sinal sutil antes do diálogo |
| `Arrive` | string? | `"Normal"` | estado do ator ao chegar (substitui o modificador pleno até o tique; nil = como hoje) |
| `Peak` | número (fração da fala) | 0,55 | onde o tique "acontece"; define o corte do `Leave` |
| `Line` | `{ Freeze: número?, After: string?, Echo: string? }` | `{ Freeze = 0,55, After = "...g. Please." }` | o que o cartão faz com a fala |
| `Steps` | lista de `HorrorScenes.Step` | passos com `Phase = "Talk"` / `"Idle"` / `"Leave"` e `Who = "Taker"` | a cena do tique, no mesmo formato das cenas |
| `Residue` | string | `"Reversed"` | estado do ator depois do pico (visto por todos) |
| `OnLeave` | `"Cancel"` \| `"Residue"` \| `"Follow"` | `"Follow"` | o que fica se sair depois do pico |
| `Caption` | string? | `"[neck cracks]"` | legenda do som |
| `Nights` | `{ [night]: overrides }?` | — (ANM-001 usa N4+) | variação por noite |

`Content.Tics.Rules`: `ChoiceMin` 1,8 · `TicMax` 2,4 · `ScareCooldown` 45 · `Idle1` 4 · `Idle2` 8 · `HearRange` 25 ·
`CaptionDefault` true · tetos de Susto (§2.2). `Validate`: todo passo `Talk` com `At` ≤ `TicMax`; `Key` existe em
`Content.Anomalies` com `Actor = "Customer"`; `Kind = "Scare"` proibido na ANM-005.

Extensões de tipos que isso pede: `Phase` ganha `"Talk"`, `"Idle"`, `"Leave"` (tempo relativo ao evento do diálogo);
`Who` ganha `"Taker"`; `Pose` ganha `Target = "Step"` (escala/altura em degraus) se ainda não houver.

### 5.2 Servidor

- Ao entrar em `Greeting` com um ator que tem linha em `Content.Tics`: sorteia Susto/Pista (semente `NpcId`), calcula
  `ChoiceAt` e grava no ator atributos curtos: `Tic` (estado: `""`, `"Pre"`, `"Peak"`, `"Done"`), `TicAt` (tempo de
  servidor do pico), `TicKind`. Nada por frame na rede.
- Gate: `TabletDecide` antes de `ChoiceAt` é ignorado.
- `Leave` antes de `TicAt`: volta `Tic = "Pre"`. Depois: `Tic = "Done"` (resíduo).
- Guarda por jogador quem já viu o tique completo daquele ator e a recarga de Susto.
- ANM-004: guarda a última fala do original por atendente para o eco.

### 5.3 Client (tela de diálogo e close)

O `TabletController` / `TabletDialog` precisam expor, numa interface só, os eventos `Arrive`, `LineStart`,
`LineAt(f)`, `LineEnd`, `Choice`, `Idle1/2`, `Leave` (com motivo: botão, movimento, forçado), `Refuse`, `Accept`. O
tocador de cenas (`AnomalyController/Scene`) assina esses eventos e roda os `Steps` do tique só para quem atende. Peças
novas no close:

| Peça | Para quem | Uso |
|---|---|---|
| Cartão: **congelar** a máquina de escrever num índice, **trocar o resto** da fala, **eco**, **letras sumindo**, **gotas** por cima | taker | 012, 001, 004, 005 |
| Close: **seguir o ator** (alvo = cabeça, limites de `Rules.MaxFov` e da moldura) e **avançar** `Distance` | taker | 014, 015, 016 |
| Close: **corte para câmera de segurança** por ≤ 0,2 s (com `SecurityView` local) | taker | 023 |
| Tela: **piscada do jogador** (preto 0,12 s) | taker | 016 |
| Silenciar os passos de câmera da cena da anomalia enquanto o close está aberto (§2.4) | taker | todos |

A outra sessão (botão de sair e saída por movimento) só precisa emitir o `Leave` com o motivo; o resto é deste gancho.

### 5.4 Custo de rede e desempenho

3–4 escritas de atributo por tique; nenhum NPC, parte ou som contínuo novo além do ator; o close já existe. Sem impacto
no teto de NPCs nem no orçamento de partes.

## 6. Pendências e riscos

- **Head banger e REFUSE:** o rule da ANM-022 usa `Verb = "refuse"` só para o kit pegar o ator; precisa confirmar (QA)
  se o REFUSE do diálogo resolve, falha ou não faz nada com ela hoje. Ligado a `Q-447`.
- **Sinal em 1 segundo** (princípio 1 da V2) fica mais fraco **antes** do diálogo para 012, 014, 015 e 001 N4+. Como todo
  cliente passa pelo diálogo antes de ser servido, o sinal chega no momento da decisão. Risco: quem fecha a janela
  "por olho" na fila perde essa leitura → `Q-461`.
- Tiques que mexem na câmera do close (014, 015, 016, 023) precisam passar no teste de celular 667×375.
- Falas novas ("turn around", "...just bread.", "...light... too bright...") são do agente; passam ao narrative-writer
  junto com `Q-457`.

## 7. Perguntas abertas

`Q-459` a `Q-464` em `docs/open-questions.md`.
