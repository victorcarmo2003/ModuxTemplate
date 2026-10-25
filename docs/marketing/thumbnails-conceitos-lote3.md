Status: Rascunho

# Thumbnails — lote 3: a receita da A06 "Janela Sorriso"

Autor: orquestrador, 2026-10-25, a pedido do dono. Tudo aqui é **Provisório** até o OK do dono.
Base: dados das campanhas de anúncio de out/2026 (relato do dono no chat, 2026-10-25), vencedoras em
`Assets/thumbnails/final/vencedoras/`, `design/anomalies-v3-restaurant.md`, `levels/MAP-01-r4-restaurant.md`,
`story/characters.md` (CHR-001), DEC-370, DEC-371, DEC-383, DEC-384, `marketing/video-walt-show.md`.

---

## 1. O que os dados disseram

| Criativo | CTR | O que aconteceu depois do clique |
|---|---|---|
| Versões "melhoradas" pelo ChatGPT (cores vivas, neon, brilho, fundo esmaecido, clima Halloween fofo) | ~3 % | o jogador saía em 1,5–5 min, **no momento da 1ª anomalia**: a thumb prometia jogo fofo, o jogo é terror |
| **A06 "Janela Sorriso"** (frame do jogo, luz real, escuro) | **4,5 % em 2 dias, ainda subindo** quando a campanha foi parada por engano | a promessa bate com o jogo |
| A09 "Fica na luz" | bom no começo, depois caiu | — |
| A04 "Fila pescoço" | sem leitura (parada cedo) | — |
| B2 urso + Walker, C16 raposa + carro | vencedoras do lote anterior | — |

Conclusão: **a A06 ganhou nas duas pontas** (mais clique *e* clique honesto). A da ChatGPT só ganhou no clique e
pagou na retenção, que é o que o Roblox usa no ranking (Play-Through Rate e First-Play Bounce).

### 1.1 A régua de mercado da skill reprova a vencedora

`thumb.py check` mede contra a média de 178 thumbs do topo. Resultado:

| Métrica | A06 (vencedora) | A09 | ChatGPT | Faixa "de mercado" da skill |
|---|---|---|---|---|
| dark | 0,47 | 0,94 | 0,21 | ≤ 0,45 |
| bright | 0,007 | 0,001 | 0,12 | ≥ 0,06 |
| contrast | 0,16 | 0,10 | 0,26 | ≥ 0,18 |
| sat | 0,65 | 0,32 | 0,63 | 0,40–0,65 |
| warm / cool | 0,84 / 0,01 | 0,30 / 0,02 | 0,50 / 0,09 | ≤ 0,50 / ≥ 0,10 |
| edges | 0,07 | 0,02 | 0,18 | ≥ 0,09 |

A skill dá **8 avisos** para a A06 e passa a da ChatGPT quase limpa. Para este jogo, a régua de mercado **empurra
para o lado errado**. Leitura provável: no meio de cards claros e saturados, um card escuro com dois olhos brancos
**se destaca por ser diferente**, e ainda diz "terror" em 1 s.

**Regra deste lote:** o gate passa a ser o **perfil A06** (§2.3), não as faixas de mercado. O preview de 250 px em
cinza continua obrigatório.

---

## 2. O DNA da A06 (o que fica igual em todas)

### 2.1 Leitura em 1 segundo

Dois blocos: **um bicho fofo apavorado** em primeiro plano e **uma massa preta com dois olhos brancos** atrás dele.
A pergunta nasce sozinha: *"ele não viu o que está atrás dele?"* (ironia dramática: o espectador sabe, o herói não).

### 2.2 Receita

| Elemento | Como é na A06 | Regra do lote |
|---|---|---|
| Origem | captura real do Studio, luz do jogo | **frame que existe no jogo**. Sem pintar, sem neon, sem glow no herói, sem IA de imagem por cima |
| Câmera | dentro da cozinha, altura de olho, lente aberta (~70°), leve barril | 1ª pessoa "de colega": FOV 65–75, altura 4–5 studs |
| Herói | 1º plano, terço direito, cortado pela borda de baixo, cabeça ~35 % da altura | cabeça 30–40 % da altura, num terço lateral, encostado na câmera |
| Expressão | olhos arregalados, gota de suor, dente cerrado, mãos para cima | rosto de medo da crew (suor + dente), corpo reagindo |
| Ameaça | silhueta preta grande, olhos brancos que brilham, dentes de tubarão, boca rosa | **os olhos são o único branco da imagem**. Boca rosa = o único acento quente forte fora do herói |
| Moldura | a ameaça está **dentro da janela** (quadro dentro do quadro) | sempre uma abertura: janela, vitrine, porta, para-brisa, vão do teto |
| Profundidade | 1º plano desfocado (pote verde à esquerda), fundo de rua com DOF | 3 planos: objeto desfocado / herói nítido / ameaça e rua |
| Cor | interior quente (teto marrom, armários creme, piso xadrez); rua roxa/azul de noite com varal de lâmpadas coloridas | quente dentro × noite roxa fora; lâmpadas coloridas pequenas dão vida sem neon |
| Acabamento | vinheta + borrão nas bordas, sem texto, sem outline | igual. **Sem texto** neste lote (variável fica para o lote 4) |

### 2.3 Perfil A06 (gate do lote)

Faixas aceitas, tiradas da A06 com folga: **dark 0,35–0,60 · bright ≤ 0,03 · sat 0,50–0,72 · warm ≥ 0,55 ·
edges 0,05–0,10**. Para as variações "ilha de luz" (família A09): dark até 0,90, sat ≥ 0,30.
Fora da faixa = rever. No preview cinza de 250 px: **herói e os dois olhos brancos legíveis**; mais nada compete.

### 2.4 Honestidade

O **gênero e o tom** precisam bater com o jogo: terror com bicho fofo, não jogo fofo. Foi isso que a ChatGPT quebrou.
Cenas, lugares e o comportamento das anomalias vêm do build atual.
**Exceção do dono (2026-10-25):** o monstro **Sorriso** pode aparecer nas thumbs mesmo fora do catálogo V3. O
objetivo da thumb é o clique, e dentro do jogo ele vai estar ocupado com as outras anomalias e não vai cobrar o
Sorriso.

### 2.5 Mãos da cor da espécie

O dono achou roupas com a mão de outra espécie (sapo com a mão do gato). Thumb mostra mão em close, então
**nenhuma captura sai antes da correção das skins** (agente rodando desde 2026-10-25). Conferir a mão do herói no
zoom a 100 % antes de entregar.

---

## 3. Os 10 conceitos

Cada um troca **uma coisa principal** em relação à A06, para o resultado dizer o que funcionou.
Espécies do herói revezam (cachorro, raposa, hamster, gato, porco, urso, pinguim) para não ficar sempre o mesmo.

| # | Nome | Anomalia | Onde (mapa atual) | Variável testada |
|---|---|---|---|---|
| L3-01 | Janela Sorriso 2.0 | Sorriso (estilo `Grin`) | balcão do restaurante, vitrine | **controle**: mesma receita no mapa novo |
| L3-02 | Ninguém viu | Sorriso | cozinha, 4 da crew | **grupo** (co-op) × herói solo |
| L3-03 | Alguém atrás da porta | ANM-020 apagão, sombra na fresta | porta dos fundos `DOOR-B`, faixa de luz `DOOR-GAP-B` | ameaça **só sugerida** (nenhum monstro à vista) |
| L3-04 | Cliente sorridente | ANM-013 olhos brancos | tablet / balcão | ameaça **disfarçada de fofo**, de perto |
| L3-05 | Segura o disjuntor | ANM-020 apagão | coluna de controle, escuro | **luz vermelha** de emergência (a régua do dono) |
| L3-06 | A última mesa | ANM-010 The Hush | pátio, mesas de piquenique | família **A09** (ilha de luz) no mapa novo |
| L3-07 | Tem alguém no estacionamento | Walt sombrio (DEC-371) | estacionamento visto da vitrine | **lore** / mistério sem monstro de dentes |
| L3-08 | É ele na linha | Walt sombrio + telefone (DEC-372) | balcão, telefone | lore + ironia "quem está ligando?" |
| L3-09 | Fecha a janela | ANM-021 névoa vermelha | trailer do onboarding (DEC-384) | **paleta vermelha** + a 1ª coisa que o novato vive |
| L3-10 | Não olha pra cima | ANM-019 sombra no teto | cozinha, câmera baixa | ameaça **em cima**, ângulo de baixo |

### L3-01 — Janela Sorriso 2.0 (controle)
- **Cena:** dentro do restaurante, atrás do balcão corrido. A vitrine ocupa o centro; lá fora, pátio e rua de noite
  com o varal de lâmpadas.
- **Herói:** cachorro (o mesmo da A06), terço direito, de frente para a câmera, mãos para cima, rosto de medo.
- **Ameaça:** o Sorriso enorme encostado na vitrine, centro-esquerda, olhos brancos, dentes, boca rosa.
- **Câmera/luz:** igual à A06. Pote/garrafa desfocada no canto esquerdo.
- **Por quê:** mede se a receita sobrevive ao mapa novo. Se a L3-01 empatar com a A06 original, a receita vale e o
  resto do lote é leitura limpa.

### L3-02 — Ninguém viu
- **Cena:** cozinha, 4 da crew trabalhando (grelha, esteira, mesa central), felizes, rosto `Happy`.
- **Herói:** só **um** (raposa, 1º plano direito) virou e viu: rosto de medo. Os outros 3 de costas para a janela.
- **Ameaça:** Sorriso na janela de serviço, atrás do grupo.
- **Pergunta:** "eles não perceberam?". Mostra o co-op ("You and three friends") sem texto.

### L3-03 — Alguém atrás da porta (ideia do dono)
- **Cena:** apagão (ANM-020), tudo escuro. A porta dos fundos `DOOR-B` no centro, com a **faixa de luz branca**
  embaixo dela (`DOOR-GAP-B`). No meio da faixa, o **bloco preto** da sombra de quem está do outro lado, já largo
  (o momento em que ele cresce). Câmera baixa, quase no chão, a faixa de luz atravessando o quadro.
- **Herói:** hamster no 1º plano direito, de costas para a porta ou olhando para ela, mão na boca, iluminado só pela
  lanterna/luz vermelha de emergência.
- **Ameaça:** nenhum monstro visível. Só a sombra cortando a luz. A faixa branca é o único branco da imagem (faz o
  papel dos olhos da A06).
- **Por quê:** é o frame mais fiel ao jogo do lote inteiro e o mais minimalista. Testa se a ameaça **sugerida** puxa
  clique tanto quanto a ameaça mostrada. Referência de movimento: `Dev/shared/CameraTracks.luau` (track do apagão:
  "the shadow leaves the slit") e `Cutscene/.../Finale.luau` (`doorShadow`).
- **Variante:** se a leitura a 250 px ficar fraca, dois olhos brancos pequenos acima da faixa, por trás da fechadura.

### L3-04 — Cliente sorridente
- **Cena:** tablet na ponta direita do balcão, fila atrás.
- **Herói:** gato no 1º plano esquerdo, dedo parado no tablet, suor.
- **Ameaça:** o cliente da vez, corpo fofo de civil, **olhos totalmente brancos e sorriso largo demais** (ANM-013),
  inclinado sobre o balcão, perto demais da câmera.
- **Por quê:** a quebra de expectativa vira a promessa: fofo por fora, errado por dentro. Testa ameaça humana × monstro.

### L3-05 — Segura o disjuntor
- **Cena:** apagão. Só a luz vermelha de emergência e a lanterna. Coluna de controle com o disjuntor.
- **Herói:** porco no 1º plano direito, as duas mãos no disjuntor, olhando para a câmera, apavorado.
- **Ameaça:** no vão da porta atrás dele, a sombra do apagão, alta, olhos brancos. Halo vermelho nas bordas.
- **Por quê:** é a anomalia que o dono chamou de perfeita (ANM-020). Testa vermelho no lugar do quente/roxo.

### L3-06 — A última mesa
- **Cena:** pátio. As luminárias das mesas de piquenique apagadas, menos **uma**. Câmera alta, de longe (como a A09).
- **Herói:** urso sozinho na única mesa acesa, encolhido, hot dog na mão.
- **Ameaça:** 3–4 pares de olhos brancos no escuro em volta, em alturas diferentes.
- **Por quê:** é a A09 no mapa novo, com a regra do The Hush. Mede se a "ilha de luz" segura o CTR além do começo.

### L3-07 — Tem alguém no estacionamento
- **Cena:** de dentro da loja, câmera atrás do balcão, olhando a vitrine. Dentro: quente, aconchegante, crew feliz.
- **Herói:** pinguim no 1º plano esquerdo, sorrindo, servindo um prato (não viu nada).
- **Ameaça:** no estacionamento, debaixo de um poste, a **silhueta alta do Walt sombrio** de boné, parado, olhando
  para a câmera. Sem dentes. Dois olhos brancos pequenos.
- **Por quê:** testa se o mistério da lore puxa clique sem monstro "gritando". É também a sequência do trailer
  (0:48–0:55 do roteiro B1).

### L3-08 — É ele na linha
- **Cena:** balcão, telefone fixo tocando (o do Walt).
- **Herói:** cachorro no 1º plano direito, fone no ouvido, olhos arregalados.
- **Ameaça:** pela vitrine, o Walt sombrio **também com um telefone na orelha**, olhando para dentro.
- **Por quê:** DEC-372 ("ele está falando sem o telefone?"). Pergunta forte: quem está ligando? É a mais "história".
- **Modelo do Walt sombrio (L3-07 e L3-08):** o mesmo da cutscene final, que existe no jogo: skin de **sapo** com a
  textura de **noite** (confirmado pelo dono, 2026-10-25). O telefone na mão é licença de thumb.

### L3-09 — Fecha a janela
- **Cena:** trailer do onboarding (DEC-384), névoa vermelha densa lá fora. A janela de serviço meio fechada.
- **Herói:** raposa no 1º plano, as duas mãos puxando a janela para baixo, rosto de medo.
- **Ameaça:** do outro lado do vidro, na névoa, uma mão enorme espalmada e dois olhos brancos.
- **Por quê:** é **exatamente** o que o jogador novo vive nos primeiros minutos (onboarding). Melhor alinhamento
  de promessa possível. Testa paleta vermelha.

### L3-10 — Não olha pra cima
- **Cena:** cozinha, câmera bem baixa olhando para cima (contra-plongée).
- **Herói:** gato no 1º plano, cabeça baixa, olhos para baixo, tremendo (a regra "não olhe para cima").
- **Ameaça:** no teto, a mancha escura da Sombra com olhos se abrindo, logo acima da cabeça dele.
- **Por quê:** ameaça vinda de cima, composição vertical diferente de tudo que já rodou.

### Reservas (se algum conceito cair na checagem de honestidade)
- **R1 — Rastejador no pátio** (ANM-017): de dentro pela vitrine, de quatro debaixo de uma mesa de piquenique, olhos brancos.
- **R2 — O da parada** (ANM-006): figura alta parada no ponto de ônibus, refletida na vitrine atrás do herói.
- **R3 — O Hunter** (badge `met_hunter`): herói fora da loja de noite, passos atrás, olhos no fim da rua.
- **R4 — Drive-thru vazio** (ANM-031; era a L3-03): carro na pista com o banco do motorista vazio, hamster
  entregando o saco congelado, dois olhos brancos no banco de trás.

---

## 4. Plano de teste dos anúncios

1. **Relançar a A06 original como controle**, no mesmo lote e com o mesmo orçamento. Sem controle, diferença de
   dia/leilão se confunde com diferença de thumb.
2. **Mesmo público, mesmo orçamento diário, mesma data de início** para as 10 + controle.
3. **Não matar antes de 72 h** uma campanha que está subindo (a lição da A06). Corte só por número:
   CTR abaixo de 2,5 % depois de ~5.000 impressões.
4. Ler **três** números por campanha: CTR, custo por play e **retenção** (tempo de sessão / saída antes da 1ª
   anomalia). A thumb só "ganha" se não piorar a retenção em relação ao controle.
   Conferir no Ads Manager e no Analytics se a retenção sai separada por campanha; se não sair, rodar as finalistas
   em janelas separadas e comparar a retenção da janela.
5. As **2–3 melhores** vão para a capa (Thumbnail Personalization), uma rodada por semana, mexendo só na thumb.
6. Registrar o resultado neste doc (§6) e na skill: o que ganhou, CTR, retenção.

---

## 5. Produção

1. **Bloqueio:** só capturar depois da correção das mãos das skins (§2.5). Sorriso liberado pelo dono; Walt
   sombrio = modelo da cutscene final (sapo, textura de noite). Falta só ver se a mão na névoa (L3-09) existe; se
   não, a L3-09 fica só com os olhos na névoa.
2. Montagem no Studio pelo `thumbnail-artist` com a skill `roblox-thumbnail`, mas com **luz real e sem passes de
   chroma/outline**: a A06 é um frame direto. Pós só o que ela tem: DOF, vinheta, borrão de borda.
3. Ordem (do mais seguro ao mais arriscado): L3-01, L3-05, L3-03, L3-09, L3-02, L3-04, L3-06, L3-10, L3-07, L3-08.
4. Entrega em **3 lotes** (4 + 3 + 3) para o dono aprovar antes do próximo.
5. Gate de cada uma: perfil A06 (§2.3) + preview cinza de 250 px lado a lado com a A06.
6. Saída: `Assets/thumbnails/lote3/` (1920×1080 PNG < 3 MB) e a folha de comparação com a A06.
7. `T.cleanup()` no fim de cada sessão de Studio.

---

## 6. Resultados

### 6.1 Produção (2026-10-25)

Os 10 em `Assets/thumbnails/lote3/` (1920×1080 PNG < 1,4 MB), folha `compare_lote3.png` (com a A06 de controle) e
`compare_lote3_250px.png` (cor + cinza no tamanho do card). Passes em `layers/`, um JSON por thumb; pós em
`tools/thumbnails/cine_post.py` (crop 16:9, upscale, glow atrás do monstro via matte, borda borrada, vinheta, ganho).
Tudo frame cru do Studio no restaurante atual, sem outline e sem texto; mãos já na cor da espécie.

| # | Leitura no card | Nota |
|---|---|---|
| L3-01 | forte | quase gêmea da A06; glow roxo atrás do Sorriso (pós) |
| L3-02 | boa | o Sorriso aparece entre as cabeças da equipe feliz |
| L3-03 | média | a faixa de luz lê; o bloco preto fica pequeno a 250 px |
| L3-04 | boa | macaco civil com `EyesWhite` + sorriso de dentes (licença de thumb) |
| L3-05 | forte | corredor da despensa vermelho, vulto com olhos no fundo |
| L3-06 | boa | A09 no pátio: panda na única luz, 4 pares de olhos |
| L3-07 | média | Walt sombrio pequeno no fundo; ganhou olhos brancos e halo frio (licença) |
| L3-08 | fraca | o telefone não lê no card; candidata a sair do teste |
| L3-09 | boa | névoa vermelha + olhos sob a persiana meio fechada |
| L3-10 | forte | olhos na mancha do teto logo acima do gato |

**Rodada 2 (pedido do dono, mesmo dia):** L3-01 com o Sorriso maior ocupando o vazio da esquerda; **L3-02 descartada**;
L3-03 com luz suave no rosto inteiro; L3-04 sem a boca de dentes (só `EyesWhite` na pele natural); L3-05 com luz de
lanterna por baixo do queixo (história de fogueira); L3-07 trocada pelo **Hunter** (réplica do `Runner.luau`: preto,
olhos vermelhos em fenda) espiando pela beirada da vitrine, arquivo `L3-07_hunter_espiando.png`; L3-08 com o Walt
grande colado na vitrine; L3-09 com o monstro forçando a persiana (uma mão segura o metal, a outra agarra a borda do
balcão, cabeça entrando); L3-10 com o gato mais à esquerda/baixo e olhos estreitos de raiva olhando de lado.
**Rodada 3:** L3-01 com a rua no ar ATM-2 "Pitch black" (`Content.Atmospheres`); L3-07 com o Hunter de volta à beirada da
vitrine e a rua tomada pela névoa vermelha da ANM-021 (arquivo `L3-07_hunter_espiando.png`); L3-08 com o boné do Walt erguido para liberar os olhos e o ar
`LightPresets.Night1` (névoa azul-acinzentada das primeiras noites).
L3-06 ficou como estava. `cine_post.py` ganhou `inpaint` (apaga linha de gizmo do Studio que vaza na captura).

Limites: o viewport do Studio entrega 1259×794, então o 1920 é upscale (nítido o bastante para o card; para a capa
4K, emular 3840×2160 no Device Emulator). O Walt sombrio do jogo é tartaruga `civil_c` Night (`WaltDark.luau`),
não sapo; a thumb usa o mesmo modelo.

### 6.2 Campanhas

(preencher depois dos anúncios)

## 7. Pendências para o dono

- Aprovar a lista dos 10 (ou trocar algum pelas reservas R1–R4). A fresta da porta entrou no lugar do drive-thru,
  que virou a R4.
- O lote vai **sem texto**, para isolar a imagem. Texto entra como variável no lote 4. OK?
- A L3-09 usa o **trailer** do onboarding; as outras, o restaurante. OK misturar?
