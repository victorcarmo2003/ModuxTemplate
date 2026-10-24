Status: Rascunho

# Pesquisa: ícone, thumbnails e criativos de anúncio no Roblox (público 6–13)

Data da pesquisa: 2026-10-17. Fontes oficiais: Creator Hub (create.roblox.com/docs), páginas sem data visível. Confira de novo antes de publicar.

## Pergunta

Que padrão de ícone (quadrado), thumbnail (16:9) e criativo de anúncio dá mais clique (e play qualificado) para um jogo de terror leve com animais fofos, e quais regras oficiais limitam isso?

## Resposta curta

Um assunto só, rosto grande, contraste forte (personagem fofo e claro na frente, ameaça escura com olhos brilhando atrás) e gênero óbvio à primeira vista. Ícone sem texto (ou só um logo curto), legível em 150×150. Thumbnails 16:9 em 1920×1080, de 2 a 5 ativas para a Thumbnail Personalization testar sozinha, mostrando só o que existe no jogo. Nada de sangue realista, rosto desfigurado nem texto de promessa ou promoção.

---

## 1. Regras oficiais (Creator Hub)

### Ícone
- Quadrado, template de **512×512**. Em vários lugares ele é reduzido para **150×150**: teste nesse tamanho. ([game icons](https://create.roblox.com/docs/production/promotion/game-icons))
- Boas práticas oficiais: imagem nítida, conteúdo que mostra o que o jogador vai encontrar, sem "símbolo ambíguo no canto". A cor passa o tom do jogo, e para terror a doc recomenda "**heavy color balance and contrast**". Não deixe o ícone auto-gerado.
- Um ícone por idioma (locale). Todo ícone passa por moderação.
- **Não existe A/B test de ícone** (não confirmado como lançado até 2026-10). Há só um pedido no DevForum ([Icon A/B Testing](https://devforum.roblox.com/t/icon-ab-testing/3274267)). Teste de ícone é manual: troca e compara o período.

### Thumbnail (16:9)
- **16:9, idealmente 1920×1080.** Formatos jpg/gif/png/tga/bmp. Imagem fora de 16:9 é **esticada** (distorce). Até **10** imagens ou vídeos por jogo. ([thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails))
- **Safe area:** deixe o essencial (texto, rostos) **longe da borda de baixo**, porque a contagem de jogadores e os metadados cobrem essa faixa. A doc não dá medida em pixels. Recomendação nossa (não oficial): reservar uns 15% de baixo e uns 5% das laterais.
- **Thumbnail Personalization (o "A/B" oficial):** liga com **2 a 5** thumbnails ativas, arquivos de até **3 MB** e 1920×1080. Cada uma é mostrada a grupos aleatórios, a que ganha em cada segmento recebe mais impressões e as outras ficam com tráfego mínimo. Métricas: impressões, qualified plays, playtime médio, **qualified play-through rate**, segmento vencedor. Resultado aparece em poucas horas. Média relatada pela Roblox: **+8,5%** de qualified play-through rate, com casos de até **+50%**. Recomendação oficial: manter várias ativas e testar thumbnails novas a cada update grande.
- **Vídeo:** 3 uploads por mês (vídeo reprovado também gasta a cota). Não aparece em Xbox, PlayStation nem VR. Proibido: gameplay ou tema que o jogo não tem, gráfico melhor que o real, filmagem da vida real, narração ou música com letra, e "ads, promotions or subjective claims" (ex.: "MELHOR JOGO"). Pode ter logo, UI do jogo e cortes de highlight.
- **Discovery:** thumbnail que mostra coisa que não está no jogo **reduz recomendação e busca**. Imagem e nome originais ajudam a destacar. Metadados parecidos com os de outro jogo também derrubam. Play-through rate é o sinal "most important" do Home. ([discovery](https://create.roblox.com/docs/discovery))

### Moderação e maturidade
- Ícone e thumbnail são assets moderados pelas Community Standards. Violência, sangue ou tema realista ou excessivo "may be moderated regardless of your content maturity label". ([content maturity](https://create.roblox.com/docs/production/promotion/content-maturity))
- **Fear Mild** cobre: NPC com cara assustadora, jump scare, respiração pesada, grito, música ameaçadora. **Moderate** já inclui "boca desfigurada com sangue realista" e "falta de carne com tecido conectivo realista". Para o Walker isso quer dizer: boca de dentes **cartoon, sem sangue, sem gengiva ou carne realista**.
- **Minimal e Mild** são elegíveis para **Roblox Kids (5–8)** e **Roblox Select (9–15)**, com requisitos extras de publicação. Se a arte for pesada, o jogo perde o público-alvo. A doc não diz que a thumbnail precisa "bater" com o rótulo, mas o risco de moderação é real.
- Referência: Animal Hospital (lançado em 2026-05-10, pico de ~737k CCU) roda como **Minimal**, com light blood, mild violence e jump scares ocasionais. ([GosuGamers](https://www.gosugamers.net/entertainment/news/78741-animal-hospital-becomes-roblox-s-latest-horror-sensation-here-s-everything-you-need-to-know))

### Anúncios (Ads Manager)
- O criativo do Sponsored Experience **é uma thumbnail 16:9** que aparece no Home. Até **10** por campanha, com tráfego distribuído por igual (não otimiza sozinho como a Personalization). Fontes: thumbnails já existentes, upload novo ou geração por IA (3 variações). Moderação do anúncio em até ~24h, do asset em até ~48h. ([ads manager](https://create.roblox.com/docs/production/promotion/ads-manager))
- Métricas: impressions, clicks, plays, CPP, playtime, earnings, ROAS. A conta precisa ter 13+.
- **Menores de 13:** a política mudou várias vezes (2023 bloqueou anúncio para menores de 13; em 2026 a Roblox abriu esse público via SuperAwesome para display e vídeo). Se Sponsored Experiences chegam ou não a menores de 13 hoje **não está confirmado**: fontes conflitam ([AdExchanger](https://www.adexchanger.com/marketers/roblox-opens-up-advertising-to-kids-under-13/), [Toy World](https://toyworldmag.co.uk/?p=224073)). Verifique no próprio Ads Manager antes de gastar.
- Um relato no DevForum mostra CTR de **0,134%** em ícone patrocinado (CPC de 10,54 Robux), e os comentários dizem que patrocínio costuma render pouco. Isso é anedota, não benchmark. ([DevForum](https://devforum.roblox.com/t/is-my-game-icon-actually-this-bad-horrible-click-rate/2625742))

---

## 2. Padrões dos jogos grandes (terror, anomalia, simulador)

**Aviso:** não achei análise escrita confiável das artes de Doors, Pressure, Dead Rails, Grow a Garden, 99 Nights, Forsaken, Piggy ou Animal Hospital. O que segue é observação de padrão recorrente no gênero, **não confirmada por fonte**. Esses ícones mudam a cada update, então confira as páginas atuais antes de decidir.

- **Composição:** 1 herói em primeiro plano (40–60% da altura do quadro) e 1 ameaça grande atrás ou acima, ocupando o fundo. Raramente passa de 3 figuras. Em terror, a ameaça costuma ser **silhueta escura com olhos ou boca brilhando** (alto contraste branco, amarelo ou vermelho sobre azul-escuro ou preto).
- **Rosto:** grande e com expressão exagerada (susto, boca aberta, olhos arregalados), virado para a câmera ou olhando para a ameaça.
- **Cor:** terror usa fundo azul-noite, verde ou preto, mais 1 cor quente de destaque (fogo, lanterna, letreiro, olhos). Simuladores (tipo Grow a Garden) usam saturação alta e cores quentes. Para nós cabe o híbrido: **trailer quente e iluminado (laranja/amarelo) contra noite fria (azul/roxo)**.
- **Outline e rim light:** contorno claro ou luz de recorte no herói para separar do fundo escuro. Muito comum em renders feitos para ícone.
- **Texto:** no ícone, quase sempre ausente ou só um logo curto ou um selo de evento ("UPDATE", "HALLOWEEN"). Na thumbnail 16:9 aparece mais: logo e, às vezes, um gancho de 1 a 3 palavras.
- **Setas e círculos vermelhos** (estilo YouTube): aparecem em jogos menores. Nos grandes são raros (observação). Correm risco de cair em "subjective claims" no vídeo e confundem quando reduzidos.
- **Render com rig do Roblox:** o DevForum (ago/2026) recomenda personagem em rig Roblox em vez de desenho, porque fica mais claro o que é o jogo. ([DevForum](https://devforum.roblox.com/t/how-to-get-playthrough-rate-up/4772142))

## 3. Ícone x thumbnail: o que funciona em cada

| | Ícone (1:1, 512) | Thumbnail (16:9, 1920×1080) |
|---|---|---|
| Onde | Busca, listas e grades. No celular fica ~150 px ou menos | Home (cards largos), topo da página do jogo, anúncio Sponsored |
| Conteúdo | 1 rosto e 1 ameaça, no máximo 2 elementos legíveis | Cena: herói, ameaça e cenário (trailer) com o gênero claro |
| Texto | Não, ou só o logo | Logo e no máximo 3 palavras, grandes |
| Teste | Manual (sem A/B oficial) | Personalization com 2 a 5 ativas |
| Risco | Detalhe que some em 150 px | Borda de baixo coberta pela contagem de jogadores. Esticar se não for 16:9 |

- Regra prática de terceiro (não oficial): texto com menos de ~40 px na arte original some no tamanho de card. Mais de 5 elementos vira ruído. ([RoWatcher](https://rowatcher.com/news/the-roblox-thumbnail-is-a-conversion-ad-stop-designing-it-like-art))

## 4. CTR: o que criadores relatam

- **Um assunto com alto contraste em fundo simples** bateu cena complexa por **+20–40% de CTR** em testes informais (anedota, não verificado). ([RoWatcher](https://rowatcher.com/news/the-roblox-thumbnail-is-a-conversion-ad-stop-designing-it-like-art))
- **Rosto de personagem** supera paisagem (relatos do fórum). Emoção explícita (perigo, surpresa) supera "clima" vago.
- **Gênero óbvio**: thumbnail colorida que não mostra o gênero perde quem gosta do gênero (DevForum, 2026-08).
- **Texto que nomeia mecânica ou recompensa** rende mais que repetir o nome do jogo (opinião de terceiro).
- Mude **uma variável por vez** e meça pelo **qualified play-through rate**, não pelo clique bruto. Thumbnail "clickbait" com bounce alto derruba a recomendação.

---

## Implicações para o Sell Hotdogs

1. **Ícone:** rosto grande do urso ou da raposa assustado(a), em close, iluminado pela luz quente do trailer. Atrás, o **Walker** em silhueta azul-escura com **olhos brancos brilhando** e sorriso de dentes cartoon, sem sangue. Um hot dog na mão do herói indica o tema "comida". Sem texto.
2. **Thumbnails (4 para a Personalization):**
   - A: herói e Walker (versão em 16:9 do ícone).
   - B: trailer aceso na noite, fila de clientes e uma anomalia escondida na fila (gancho "spot the anomaly").
   - C: os 3 animais juntos no balcão, com os faróis do carro comprido chegando.
   - D: close no preparo do hot dog, com o rastejador no canto escuro.
3. Tudo precisa existir no jogo de verdade, com render a partir de cena do Studio ou de rig compatível. Logo no topo, nada nos ~15% de baixo.
4. **Anúncio:** use as mesmas thumbnails que ganharem na Personalization. Comece com orçamento baixo e meça CPP e playtime.
5. **Classificação:** mantenha o alvo Minimal/Mild. Arte de marketing não pode ser mais pesada que o jogo (misrepresentation e risco de moderação).

## Recomendação

Produzir 1 ícone e 4 thumbnails conforme acima, ativar as 4 na Thumbnail Personalization no lançamento e revisar depois de 7 dias pelo qualified play-through rate. Fazer de 2 a 3 variantes de ícone e trocar manualmente a cada 1 a 2 semanas, uma variável por vez (expressão, personagem, cor da ameaça). Antes de qualquer gasto, confirmar no Ads Manager se o Sponsored alcança menores de 13 (status não confirmado).

## Fontes

- https://create.roblox.com/docs/production/publishing/thumbnails
- https://create.roblox.com/docs/production/promotion/game-icons
- https://create.roblox.com/docs/production/promotion/ads-manager
- https://create.roblox.com/docs/production/promotion/content-maturity
- https://create.roblox.com/docs/discovery
- https://devforum.roblox.com/t/icon-ab-testing/3274267
- https://devforum.roblox.com/t/how-to-get-playthrough-rate-up/4772142
- https://devforum.roblox.com/t/is-my-game-icon-actually-this-bad-horrible-click-rate/2625742
- https://rowatcher.com/news/the-roblox-thumbnail-is-a-conversion-ad-stop-designing-it-like-art (terceiro, anedótico)
- https://www.gosugamers.net/entertainment/news/78741-animal-hospital-becomes-roblox-s-latest-horror-sensation-here-s-everything-you-need-to-know
- https://www.adexchanger.com/marketers/roblox-opens-up-advertising-to-kids-under-13/
- https://toyworldmag.co.uk/?p=224073
