Status: Rascunho

# Pesquisa: tipografia, cor, filtros e acabamento em thumbnails (Roblox e YouTube, público 6–13)

Pesquisa: 2026-10-17 (researcher). Complementa `thumbnails-pesquisa-roblox.md` (regras oficiais, padrões dos grandes) e `thumbnails-pesquisa-externa.md` (psicologia, composição, testes). Aqui o foco é **fonte, texto, cor, grading e números para a skill de produção**.

## Pergunta

Que fontes, tratamento de texto, paletas e acabamento usam os artistas de thumbnail de Roblox e YouTube infantil, o que é livre para uso comercial, e quais números concretos a skill pode adotar?

## Resposta curta

Use fonte display gorda e arredondada (Luckiest Guy, Lilita One, Titan One, Fredoka Bold) para fofo/simulator e Bangers ou Anton para ação; para terror, a mesma fonte gorda com textura e glow em vez de contorno branco. Todas as recomendadas são OFL ou Apache 2.0 (Google Fonts): livres para comercial sem crédito. Burbank (Fortnite), Gotham e Impact são pagas ou de licença incerta: **não usar**. Texto: 1–3 palavras, altura de letra 12–20% da altura da imagem, stroke escuro ~1% da altura (10–12 px em 1080p) mais stroke branco externo opcional ~2%, sombra deslocada e dura. Cor: 2–3 matizes dominantes + 1 destaque; terror = fundo frio (azul/ciano/roxo) + um quente (laranja/amarelo); valor separado em 3 massas (teste em cinza). Acabamento: rim light, vinheta leve, glow nos olhos, unsharp mask após reduzir (raio 0,3–0,5 px, 100–200%). Tudo o que tem número de CTR em blog é anedota; os únicos dados primários são Roblox (+8,5% QPTR médio com Personalization), vidIQ 2026 (69% dos breakouts têm rosto; 24% usam 1–3 palavras; 28% sem texto) e 1of10 (rosto não garante performance em 300k vídeos).

**Nível de evidência:** não existe levantamento publicado de "fontes mais usadas em thumbnails de Roblox". A lista de fontes vem de guias de criadores e threads do DevForum; a prevalência é observação de ofício, **não confirmada**. Números de stroke/sombra/tamanho em % são **recomendação do pesquisador** derivada de prática comum (nenhuma fonte dá esses valores), marcados como tal.

---

## 1. Fontes

### 1.1 Livres para uso comercial (Google Fonts: OFL 1.1 ou Apache 2.0)

Licença confirmada pelo diretório do repositório `google/fonts` (pasta `ofl/` ou `apache/`) em 2026-10-17. OFL: pode usar em qualquer trabalho comercial, embutir em imagem, sem crédito obrigatório; só não pode vender o arquivo da fonte sozinho ([OFL FAQ 1.1, 1.6, 1.13](https://openfontlicense.org/ofl-faq/)). Apache 2.0: mesmo efeito prático para artwork.

| Fonte | Licença | Vibe / uso | Link |
|---|---|---|---|
| **Luckiest Guy** (Astigmatic) | Apache 2.0 ([repo](https://github.com/google/fonts/tree/main/apache/luckiestguy)) | O "padrão simulator" Roblox: gorda, cartoon, irregular. Fofo, caótico, comédia. Guias a chamam de "gold standard" para o look clássico | https://fonts.google.com/specimen/Luckiest+Guy |
| **Lilita One** | OFL ([repo](https://github.com/google/fonts/tree/main/ofl/lilitaone)) | Gorda e arredondada, mais limpa que Luckiest Guy. Fofo, reação, títulos curtos | https://fonts.google.com/specimen/Lilita+One |
| **Titan One** | OFL ([repo](https://github.com/google/fonts/tree/main/ofl/titanone)) | Bolha brilhante, arcade. Simulator, pets, cores vivas | https://fonts.google.com/specimen/Titan+One |
| **Bangers** | OFL ([repo](https://github.com/google/fonts/tree/main/ofl/bangers)) | Quadrinho, inclinada, pontas. Ação, anime, impacto. Recomendada no DevForum para jogo cartoon | https://fonts.google.com/specimen/Bangers |
| **Fredoka** (variável, peso até Bold) | OFL ([repo](https://github.com/google/fonts/tree/main/ofl/fredoka)) | Arredondada, geométrica, limpa. Fofo, infantil, UI. Substitui "Fredoka One" (hoje é o peso Bold da variável) | https://fonts.google.com/specimen/Fredoka |
| **Bubblegum Sans** (Sudtipos) | OFL ([repo](https://github.com/google/fonts/tree/main/ofl/bubblegumsans)) | Condensada, retrô, fofa. Nome reservado (não renomear derivados) | https://fonts.google.com/specimen/Bubblegum+Sans |
| **Baloo 2** (Ek Type, variável até ExtraBold) | OFL ([repo](https://github.com/google/fonts/tree/main/ofl/baloo2)) | Arredondada, gorda, amigável. Fofo, família multi-script | https://fonts.google.com/specimen/Baloo+2 |
| **Chewy** (Sideshow) | Apache 2.0 ([repo](https://github.com/google/fonts/tree/main/apache/chewy)) | Cartoon irregular, "mastigada". Fofo, comida, comédia | https://fonts.google.com/specimen/Chewy |
| **Boogaloo** | OFL ([repo](https://github.com/google/fonts/tree/main/ofl/boogaloo)) | Condensada, pincel, anos 60. Casual, menos gorda | https://fonts.google.com/specimen/Boogaloo |
| **Montserrat** (variável, inclui Black 900) | OFL ([repo](https://github.com/google/fonts/tree/main/ofl/montserrat)) | Geométrica, séria. Substituto livre de Gotham Black | https://fonts.google.com/specimen/Montserrat |
| **Anton** | OFL | Condensada pesada. Substituto livre de Impact/Burbank para "URGENTE", ação | https://fonts.google.com/specimen/Anton |
| **Komika Axis** (Apostrophic Labs) | Freeware, comercial permitido, não pode revender ([Font Squirrel license](https://www.fontsquirrel.com/license/Komika-Axis)) | Quadrinho inclinada, a "fonte do MrBeast". Ação, reação. Licença **não é OFL**: texto cortado no Font Squirrel, conferir arquivo antes de usar | https://www.fontsquirrel.com/fonts/komika-axis |

Pares úteis: título em Luckiest Guy/Titan One + subtítulo em Fredoka Bold ou Montserrat ExtraBold (contraste gorda × limpa).

### 1.2 Pagas ou de licença incerta (não usar)

| Fonte | Situação | Alternativa livre |
|---|---|---|
| **Burbank Big Condensed Black** (House Industries, Tal Leming 2006) | Comercial. Fonte do logo/UI antiga do Fortnite; licença por dispositivo, preço sob consulta ([Fonts In Use](https://www.fontsinuse.com/uses/54645/fortnite)). Sites "free download" são pirataria | Anton, Oswald Bold, Archivo Black |
| **Gotham Black** (Hoefler&Co / Monotype) | Comercial; relatos de ~US$199 (pacote básico) a ~US$1000 (família); fontes grátis "Gotham" são personal-use ([madegooddesigns](https://madegooddesigns.com/gotham-alternatives/)) | Montserrat Black |
| **Impact** (Monotype) | Vem no Windows, mas direito comercial é controverso: FAQ da Microsoft permite logo com fontes do Windows, resposta de staff sobre Arial diz que não é licença comercial; licença individual US$49 no MyFonts ([Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/1625128/clarification-on-microsoft-fonts-commercial-usage)). **Não confirmado**; evitar | Anton |
| **Obelix Pro** (Valentin Antonov) | Maioria das fontes diz personal-use only; dois sites dizem comercial. Conflito = não usar sem contato com autor ([FontRiver](https://www.fontriver.com/font/obelix_pro/)) | Luckiest Guy, Lilita One |
| Komika Title / Display | Mesma licença Apostrophic (freeware), ok, mesma ressalva de texto cortado | — |

Regra para a skill: só `ofl/` e `apache/` do Google Fonts, ou arquivo de licença lido e guardado em `docs/art/credits.md`.

---

## 2. Tratamento de texto

Fontes para esta seção: guias de criadores ([Roblox Thumbnail Text Styles](https://roblox-thumbnail-text-styles.pages.dev/), [vizzbees](https://vizzbees.com/blog/how-to-make-a-roblox-thumbnail), [Simplified](https://simplified.com/blog/ai-design/proven-techniques-for-roblox-thumbnail-design)), doc oficial Roblox e dados vidIQ. **Nenhuma fonte dá px ou %**; os números abaixo são recomendação do pesquisador para 1920×1080, a validar no teste de 250 px.

### 2.1 Quantidade e tamanho
- **Palavras:** 1–3 (máx. 4). vidIQ 2026: 28% dos breakouts sem texto, 24% com 1–3 palavras, mediana 5 entre os que têm texto ([vidIQ](https://vidiq.com/research/youtube-thumbnail-study/)). Roblox oficial: texto "sparingly", só para descrever gameplay; sem promoção ou afirmação subjetiva ([thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)). Público 6–7 lê devagar: a imagem tem que funcionar sem texto.
- **Altura da letra (caixa alta):** 12–20% da altura da imagem (130–215 px em 1080p) para a palavra principal; 7–10% para a secundária. Abaixo de ~6% (65 px) o texto some no card de celular (~250 px de largura, fator ~7,7×: 65 px vira ~8 px). Regra prática de terceiro em `thumbnails-pesquisa-roblox.md`: menos de ~40 px na arte original é invisível.
- **Ícone 512×512:** sem texto ou só logo; em 150×150 (exibição real, doc oficial) qualquer palavra com menos de 25% da altura some.

### 2.2 Stroke (contorno)
- **Stroke 1 (escuro):** 0,8–1,2% da altura (9–13 px em 1080p), cor preto ou a cor da letra escurecida (azul-marinho, marrom), posição outside, cantos arredondados.
- **Stroke 2 (branco, "sticker", estilo simulator):** 1,8–2,5% (20–27 px), fora do primeiro. Padrão do look simulator: "stroke escuro grosso, depois stroke branco mais grosso" ([Text Styles](https://roblox-thumbnail-text-styles.pages.dev/)).
- Cuidado: stroke grosso fecha as contras de A, O, B, R. Use fonte com aberturas grandes (Lilita, Titan) ou reduza o stroke.
- **Terror:** substituir o stroke branco por **outer glow** suave (cor fria ou vermelha, 1,5–3% de raio, opacidade 50–70%) e manter stroke escuro fino.

### 2.3 Sombra
- **Drop shadow dura (cartoon):** offset 0,6–1% da altura (6–11 px), blur 0, opacidade 80–100%, preto ou cor escura do fundo. Dá leitura em 250 px melhor que sombra difusa.
- **Sombra difusa:** só como segunda camada (blur 1–2%, opacidade 40%). Sombra escura e borrada demais "obscurece" (Simplified).
- **Sombra longa diagonal** (ação/anime): extrusão repetida a 45°, 2–4% de comprimento.

### 2.4 Preenchimento
- **Gradiente vertical** na letra: claro no topo, saturado embaixo (ex. amarelo #FFE94A → laranja #FF8A00; branco → ciano gelo para terror). O look simulator é "laranja embaixo → amarelo claro no topo".
- **Bevel/3D:** extrusão escura para baixo (3–6 px repetidos) ou texto 3D no Blender com luz. Evitar bevel padrão de Photoshop (plástico anos 2000).
- **Highlight de brilho:** faixa branca a 30–40% de opacidade no terço superior da letra (estilo bolha/Titan One).
- **Textura:** grunge/metal multiplicado sobre a letra para terror; evitar em fofo.

### 2.5 Inclinação e layout
- Inclinação **-5° a -12°** (sobe à direita) para energia; 0° para fofo calmo. Bangers já é inclinada: não inclinar de novo.
- Alinhar o texto ao herói sem cobrir o rosto. Posição: terço superior ou lateral oposta ao rosto. **Nunca nos ~15% de baixo** (contagem de jogadores cobre; a doc oficial não dá medida, o 15% é nossa reserva).
- Em 16:9 o texto costuma ocupar 30–50% da largura; em ícone 1:1, até 80% da largura num bloco só.

### 2.6 Cor do texto por gênero
| Gênero | Letra | Stroke | Sombra/glow |
|---|---|---|---|
| Fofo / cozinha | Branco ou amarelo-creme, gradiente para laranja | Marrom-escuro ou vermelho-escuro | Sombra dura marrom |
| Simulator / caos | Amarelo→laranja ou arco-íris | Preto + branco externo | Sombra dura preta |
| Terror leve | Branco frio ou vermelho | Preto fino | Glow ciano/azul ou vermelho, sem branco |
| Ação / urgência | Vermelho ou branco | Preto | Sombra longa |
| Universal (iniciante) | Branco | Preto grosso | Sombra dura |

Evitar: letra na mesma matiz do fundo (azul sobre céu), vermelho+verde juntos (daltonismo), e as cores institucionais do YouTube (vermelho/branco/preto puro) que se confundem com a UI (nota vidIQ).

---

## 3. Cor e grading

Base: `thumbnails-pesquisa-externa.md` §3 (rim light, quente×frio, vinheta). Aqui, números e paletas.

### 3.1 Paletas por gênero
- **Terror leve (Sell Hotdogs):** fundo 70–80% frio (azul-noite #0B1A3A → ciano #1FA3C6 ou roxo #2B1055) + 1 quente de 10–20% (laranja/âmbar da lâmpada do trailer #FFA629, amarelo da mostarda) + branco dos olhos do monstro como acento máximo. Doc oficial Roblox pede "heavy color balance and contrast" para terror e mostra exemplo "dark, stormy". Pôsteres de terror: fundo preto/azul/verde escuro com acento vermelho ou laranja (fontes fracas, estudantis).
- **Simulator / caos:** saturação alta (HSB S 80–100%), 3–5 matizes, céu azul-saturado, verde-grama, amarelo, rosa, "hot pinks, electric blues, fluorescent greens" (vendedores). Arco-íris em texto/efeitos, não no fundo.
- **Fofo / pastel:** fundo pastel (S 30–50%, B 90%+) + herói saturado (S 80%+). Contraste por saturação em vez de valor.
- **Preferência infantil:** quentes (vermelho, laranja, amarelo) com leve vantagem em 4–7 anos; brilho alto atrai; relação com saturação não linear ([Frontiers 2023](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2023.1205213/text)). Adultos e crianças pequenas preferem cores saturadas (Pitchford 2011). Para 6–13 **não confirmado** diretamente.

### 3.2 Valor (notan)
- Estruturar em **3 valores**: escuro (fundo/monstro, L 5–25%), médio (cenário, L 40–60%), claro (rosto do herói, texto, olhos, L 80–100%). O rosto deve ser a maior massa clara.
- Teste: converter para cinza e reduzir a 250 px; se herói e fundo se fundem, falha. Teste de blur (gaussian 20 px em 1080p): devem sobrar 2–3 massas.
- vidIQ 2026: "alto contraste" em 56% dos 500 breakouts, mas cai para 46% no top 50; rosto **ou** contraste em 89–92%. Não é lei: se todos os cards são contrastados, um card calmo destaca (Thumbnail Creator).

### 3.3 Saturação seletiva e temperatura
- Dessaturar o fundo 20–40% (Hue/Sat global −30 com máscara invertida no herói) e manter herói/boné/comida em saturação total. O vermelho do boné é a assinatura.
- **Teal & orange:** empurrar sombras para ciano/teal e luzes para âmbar; pele/pelo quente separa do fundo frio automaticamente ([explicação](https://morphic.com/br/ai-glossary/teal-and-orange)). Em Photoshop: Color Balance, Shadows −10/0/+15 (mais azul), Highlights +15/+5/−10 (mais quente), ou gradient map teal→laranja em Soft Light 20–30%.
- **Split toning** (alternativa): sombras H 200–220 S 20–30%, luzes H 35–45 S 15–25%.

### 3.4 Luz e acabamento
- **Rim light:** contorno claro de 0,3–0,6% da altura (3–6 px) em Screen/Add, cor complementar ao lado oposto da luz principal (herói com luz quente da frente, rim ciano atrás). Essencial no monstro escuro (senão vira mancha).
- **Glow/bloom:** olhos do monstro: núcleo branco + outer glow 1–2% de raio, opacidade 70–90%, cor branca ou ciano. Lâmpadas do trailer: glow laranja 3–5%, opacidade 40–60%. Limite: 2–3 pontos de glow por imagem; mais que isso compete com o rosto. Aviso de terceiro: gradientes e glows suaves "viram blob cinza no celular" ([bloxgfx](https://bloxgfx.com/roblox-thumbnail-ideas)).
- **Vinheta:** escurecer bordas 20–35%, feather 50%+, forma elíptica; mais forte embaixo (ajuda a esconder a faixa coberta pelo contador).
- **Nitidez:** sempre **depois** de reduzir para o tamanho final. Unsharp Mask: raio 0,2–0,5 px, amount 100–200% (até 400% para imagens pequenas), threshold 0–4 ([PetaPixel](https://petapixel.com/2009/05/19/sharpening-your-photos-like-flickr/), Cambridge in Colour). Em 1080p que será exibida a ~250 px, aplicar Smart Sharpen leve (0,8 px, 80%) na arte e exportar PNG-24 (Adobe Community). Para o ícone, desenhar em 1024 e reduzir para 512 antes de aplicar.
- **Grão/ruído:** raro em thumbnail infantil; se usar, 1–3% monocromático só para disfarçar banding de gradiente. Não usar em fofo.
- **Aberração cromática / glitch:** só terror e só em borda, 1–2 px; some em 250 px, custo baixo, ganho baixo.
- **Exportar:** PNG para texto nítido se < 3 MB (limite da Personalization); senão JPG q 85–92. 1920×1080 exato (fora de 16:9 a Roblox **estica**).

---

## 4. Psicologia (só o que não está nos docs anteriores)

- **Rosto:** vidIQ 2026 (500 breakouts, 30 nichos, jun/2026): rosto humano em 69% de todos, 75% do top 100, 80% do top 50. Só 5–6% com expressão exagerada: o "grito" não é o padrão dos que explodem. Layout mais comum no top 50: rosto ocupando ~1/3 do quadro ([vidIQ](https://vidiq.com/research/youtube-thumbnail-study/)). Correlação, não causa.
- **Contraponto:** 1of10 Media, 300k+ vídeos virais de 2025: com e sem rosto "performam parecido"; rosto ajuda só canais grandes (familiaridade); múltiplos rostos melhores que um ([SEJ](https://www.searchenginejournal.com/do-faces-help-youtube-thumbnails-heres-what-the-data-says/563944/)). Para um jogo novo: o rosto do **personagem** importa pela emoção, não pelo reconhecimento.
- **MrBeast / YouTube:** boca fechada venceu em ~30 testes (diferença pequena); ~50 conceitos por vídeo; "se levar 10–20 s para decodificar, rola pra baixo"; manter cores e layout consistentes entre uploads e variar um elemento (cor da camisa, objeto) nos testes; entregar o que a thumbnail promete ([Social Media Today](https://www.socialmediatoday.com/news/youtube-shares-insights-mrbeasts-team-creates-compelling-thumbnail/709817/)). O "7,41% CTR com rosto vs 5% sem (vidIQ, 3.214 canais)" que circula em blogs **não foi localizado em fonte primária**.
- **Roblox:** Personalization (bandit multi-braço, 2–5 ativas, redistribui por hora): média **+8,5% QPTR**, casos **+50%**; update de 2025 que preserva a vencedora: +0,19% QPTR e 21% menos impressões em perdedoras ([DevForum](https://devforum.roblox.com/t/live-now-personalize-your-thumbnails-to-attract-more-users/3257233), [update](https://devforum.roblox.com/t/thumbnail-personalization-now-remembers-your-existing-winning-thumbnails/3793665)). **Atenção (2026-06-15):** QPTR foi aposentada; entram **Play-Through Rate** e **First Play Bounce Rate** (saída nos primeiros ~60 s); a Roblox vai testar mover a Personalization para PTR ([DevForum](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575)). Anedota de dev: QPTR de 1–1,5%; benchmark oficial não publicado.
- **YouTube Test & Compare:** até 3 thumbs, vencedor por **watch time share** (não CTR), dias a 2 semanas, rótulos Winner / Preferred / None ([YouTube Help](https://support.google.com/youtube/answer/13861714)).
- **Curiosity gap / "antes do evento":** só prática de criadores; nenhum estudo direto com thumbnails. Base teórica em Loewenstein (ver doc externo).
- **Legibilidade:** teste em 100×100 (guia), 150×150 (ícone real, doc oficial), ~250 px de largura (card de celular). Elementos: 1–3; cores: 2–3 primárias.

---

## 5. Limites do Roblox (resumo; detalhe em `thumbnails-pesquisa-roblox.md`)

- **Ícone:** quadrado, 512×512 (template oficial), exibido até ~150×150; 1 por locale; moderado; sem spec oficial de formato/peso/cantos ([experience icons](https://create.roblox.com/docs/production/publishing/experience-icons)).
- **Thumbnail:** 16:9, ideal 1920×1080; jpg/gif/png/tga/bmp; fora de 16:9 **estica**; até 10 mídias; < 3 MB para Personalization; nada essencial na faixa de baixo ("player count"); sem medida oficial, reserva nossa de 15% ([thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)).
- **Vídeo:** 3/mês, reprovado conta; sem narração, música com letra, filmagem real, "ads, promotions or subjective claims".
- **Moderação de imagem:** Community Standards proíbem "deceptive, sensational, duplicative, or otherwise misleading content or metadata" para ganhar descoberta; "realistic or real-world depictions of extreme gore, graphic violence, or death"; texto com palavrão em imagem ([Community Standards](https://about.roblox.com/community-standards)). Thumbnail que mostra o que não existe no jogo derruba recomendação (discovery doc).
- **Maturidade:** Mild Fear = "creepy-looking NPCs, jump scares, ominous music"; Moderate Fear = "disfigured mouths with realistic blood, lack of flesh"; sangue irrealista (cor/forma diferente, pixelado) = Minimal/Mild; sangue realista = Moderate+ ([content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)). A doc não exige que a thumbnail "bata" com o rótulo, mas misrepresentação gera moderação. Para 5–8 (Roblox Kids) e 9–15 (Select) precisa Minimal/Mild: monstro cartoon, sem sangue, boca sem carne.
- **YouTube (se houver canal):** 1280×720 mínimo recomendado (doc atual lista 3840×2160 ideal, 640 px mínimo), 2 MB no mobile, JPG/PNG; strike por violência/sexual/ódio ([YouTube Help](https://support.google.com/youtube/answer/72431)). Test & Compare não roda em "made for kids".

---

## Implicações para o Sell Hotdogs

1. **Fonte oficial do jogo para marketing:** Luckiest Guy ou Lilita One para o título (fofo-caótico, casa com comida e animais) e Fredoka Bold para subtítulo/UI. Registrar em `docs/art/style-guide.md` e `credits.md` (Apache/OFL, sem crédito obrigatório, mas anotar).
2. **Texto na thumb:** 1–2 palavras de gameplay ("NOITE 3", "ANOMALIA?") ou nenhum; nunca "MELHOR", "NOVO!!!", "GRÁTIS" (subjective claims / misleading). Terço superior, longe dos 15% de baixo.
3. **Look terror leve:** letra branco-frio com stroke preto fino + glow ciano; cena 75% fria, trailer quente, olhos brancos com bloom; vinheta mais forte embaixo.
4. **Pipeline de acabamento:** render → grading (teal/orange leve, saturação seletiva no boné) → texto → vinheta → reduzir para 1920×1080 → sharpen leve → testes (cinza, blur, 250 px, 150 px) → PNG < 3 MB.
5. **Medição:** 3–4 thumbs ativas na Personalization; acompanhar PTR e First Play Bounce (QPTR aposentada em 2026-06).

## Recomendação

Codificar na skill: lista branca de fontes (tabela 1.1), tabela de estilos de texto por gênero (2.6) com os valores do cheat sheet, e checklist de testes de legibilidade. Rodar a primeira leva (A: herói+monstro, B: fila com anomalia, C: trio no balcão) com a **mesma** fonte e grading e variar só o conceito; só depois testar texto × sem texto.

---

## Cheat sheet numérico (1920×1080; ícone 1024→512)

| Item | Valor | Confiança |
|---|---|---|
| Palavras | 1–3 (máx. 4) | Dados vidIQ + doc Roblox |
| Altura da letra principal | 12–20% H (130–215 px) | Recomendação |
| Altura mínima legível | ≥ 6% H (65 px); ícone ≥ 25% | Recomendação |
| Stroke escuro | 0,8–1,2% H (9–13 px), outside, round | Recomendação |
| Stroke branco externo (simulator) | 1,8–2,5% H (20–27 px) | Recomendação |
| Drop shadow dura | offset 0,6–1% H (6–11 px), blur 0, 80–100% | Recomendação |
| Outer glow (terror) | raio 1,5–3% H, 50–70% | Recomendação |
| Inclinação | −5° a −12° (ação); 0° (fofo) | Prática |
| Gradiente da letra | claro topo → saturado base (amarelo→laranja) | Guias |
| Elementos na cena | 1–3 | Consenso |
| Matizes dominantes | 2–3 + 1 destaque | Consenso |
| Rosto do herói | ~1/3 da altura do quadro | vidIQ (layout mais comum) |
| Proporção frio:quente (terror) | ~75:25 | Recomendação |
| Valores (notan) | 3 massas: L 5–25 / 40–60 / 80–100 | Prática |
| Dessaturação do fundo | −20 a −40% | Recomendação |
| Rim light | 0,3–0,6% H (3–6 px), Screen | Recomendação |
| Glow nos olhos | raio 1–2% H, 70–90%, máx. 3 pontos | Recomendação |
| Vinheta | −20 a −35% nas bordas, feather ≥ 50% | Prática |
| Unsharp mask (após reduzir) | raio 0,2–0,5 px, 100–200%, threshold 0–4 | Fontes de foto |
| Grão | 0 (fofo) / 1–3% mono (terror) | Prática |
| Safe area inferior | 15% H livre (oficial: "bottom", sem medida) | Doc + reserva nossa |
| Safe area lateral | 5% | Reserva nossa |
| Testes de redução | 250 px (card), 150 px (ícone), 100 px (sanidade) | Doc + guias |
| Exportação | PNG-24 < 3 MB, 1920×1080 exato; ícone 512×512 | Doc oficial |
| Personalization | 2–5 ativas; métrica PTR/bounce (ex-QPTR) | Doc oficial |
| Resultado esperado | +8,5% médio (QPTR), até +50% | Roblox, não independente |

---

## Fontes

Oficiais
- https://create.roblox.com/docs/production/publishing/thumbnails
- https://create.roblox.com/docs/production/publishing/experience-icons
- https://create.roblox.com/docs/production/promotion/content-maturity
- https://about.roblox.com/community-standards
- https://devforum.roblox.com/t/live-now-personalize-your-thumbnails-to-attract-more-users/3257233
- https://devforum.roblox.com/t/thumbnail-personalization-now-remembers-your-existing-winning-thumbnails/3793665
- https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575
- https://support.google.com/youtube/answer/72431
- https://support.google.com/youtube/answer/13861714
- https://openfontlicense.org/ofl-faq/
- https://github.com/google/fonts (pastas `ofl/` e `apache/` citadas na tabela)
- https://www.fontsquirrel.com/license/Komika-Axis

Dados e estudos
- https://vidiq.com/research/youtube-thumbnail-study/ (500 breakouts, jun/2026)
- https://www.searchenginejournal.com/do-faces-help-youtube-thumbnails-heres-what-the-data-says/563944/ (1of10, 300k vídeos)
- https://www.socialmediatoday.com/news/youtube-shares-insights-mrbeasts-team-creates-compelling-thumbnail/709817/
- https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2023.1205213/text
- https://petapixel.com/2009/05/19/sharpening-your-photos-like-flickr/

Guias de criadores (opinião, sem dados)
- https://roblox-thumbnail-text-styles.pages.dev/
- https://devforum.roblox.com/t/what-is-a-good-roblox-font-to-use-for-a-cartoony-style-game/2320642
- https://vizzbees.com/blog/how-to-make-a-roblox-thumbnail
- https://simplified.com/blog/ai-design/proven-techniques-for-roblox-thumbnail-design
- https://bloxgfx.com/roblox-thumbnail-ideas
- https://www.fontsinuse.com/uses/54645/fortnite
- https://madegooddesigns.com/gotham-alternatives/
- https://learn.microsoft.com/en-us/answers/questions/1625128/clarification-on-microsoft-fonts-commercial-usage
- https://www.fontriver.com/font/obelix_pro/
- https://morphic.com/br/ai-glossary/teal-and-orange
