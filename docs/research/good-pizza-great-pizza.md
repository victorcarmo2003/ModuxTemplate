Status: Rascunho

# Referência 2: Good Pizza, Great Pizza (Tapblaze), para o modo focado (FEAT-039)

Pesquisador · 2026-10-12 · Pergunta: o que o jogo mobile ensina ao modo de preparo focado e ao pedido "engraçado/ambíguo" do Sell Hotdogs? Tudo abaixo é estrutura, não conteúdo a copiar.

## Resposta curta

O jogo é um loop de um cliente por vez: **diálogo (pedido) -> massa/molho/queijo/coberturas -> forno -> corte -> caixa -> entrega**. A graça está no pedido ambíguo, que o jogador interpreta; a avaliação é binária (certo = paga e dá gorjeta; errado = reembolso), sem estrelas confirmadas. Isso combina com anomalias e com a regra do Walt.

## O que foi confirmado (com fonte)

- Fluxo: massa, molho, coberturas, forno, fatiar, embalar, entregar ([Wikipedia](https://en.wikipedia.org/wiki/Good_Pizza,_Great_Pizza)). Passos do Talk Android: pedido, cozinha, massa, molho e queijo, coberturas, forno, corte (6 fatias por padrão), entrega ([Talk Android](https://www.talkandroid.com/15864-good-pizza-great-pizza-basic-gameplay-guide/)).
- Pedido: o cliente fala; "What" pede para repetir/explicar **uma vez** e **derruba o medidor de felicidade** do cliente ([Talk Android](https://www.talkandroid.com/15864-good-pizza-great-pizza-basic-gameplay-guide/), [Wikipedia](https://en.wikipedia.org/wiki/Good_Pizza,_Great_Pizza)). Não há ticket na tela: o jogador memoriza ([Touch Tap Play](https://www.touchtapplay.com/how-to-play-good-pizza-great-pizza-tips-tricks/)).
- Interpretação: pedidos como "bem passada" = passar pelo forno de novo; "crocante extra" = mais vezes; metade/metade = cobertura só de um lado ([lista de dicas, busca](https://patchmagazine.co.uk/blogs/features/a-guide-to-good-pizza-great-pizza)). Padrão assumido: pão, molho e queijo, salvo dito o contrário.
- Cobertura: cada ingrediente **custa** por uso; exagero gera reclamação e gorjeta menor; colocação limpa rende gorjeta melhor; tocar a caixa de novo para parar ([Touch Tap Play](https://www.touchtapplay.com/how-to-play-good-pizza-great-pizza-tips-tricks/)).
- Corte: arrastar sobre a linha; fatias desiguais não importam se a **contagem** bate. Pedidos ficam mais exigentes (8, 16 fatias) com o progresso.
- Nota: pedido exato = gorjeta; errado = reembolso; alguns clientes pagam depois ou não conseguem pagar tudo (aceitar/recusar) ([Wikipedia](https://en.wikipedia.org/wiki/Good_Pizza,_Great_Pizza)).
- Progressão: capítulos com "dias"; lucro compra ingredientes, forno melhor, reparos e **decoração** (plantas, paredes, piso, placas, mesas); upgrades como forno rápido, dia mais longo e ajudantes ([Talk Android](https://www.talkandroid.com/15864-good-pizza-great-pizza-basic-gameplay-guide/)). Mais de 100 clientes com personalidade; história com rival; ingredientes comprados ou cultivados.
- Sem co-op (jogo solo).

**Não confirmado:** gesto exato de espalhar (os guias só dizem "tocar a caixa para parar", o que sugere segurar/arrastar sobre a massa; só os screenshots do dono mostram isso); fórmula de nota/estrelas; semântica exata de "Okay" vs "What" além do medidor; tamanho dos alvos. Fandom (lista de pedidos) respondeu 402.

## (1) Transferível para o nosso modo focado

- **Pedido como minijogo de leitura:** o cliente fala uma frase; o ticket guarda a interpretação do jogador. Aqui: ticket no topo com o pedido resumido em ícones, mais a frase original em uma linha.
- **Padrões implícitos** (pão + salsicha sempre; só o que foge disso é dito) reduzem texto.
- **Caixas de ingrediente em grade, tocar para ativar, tocar de novo para parar** = custo por uso (já temos `TakeStock`).
- **Pedido literal x estranho:** a frase ambígua tem uma leitura "segura" e uma leitura "estranha"; servir a estranha é a regra do Walt/anomalia. Dá um dilema barato sem mais telas.
- **"What?" com custo** (paciência/humor) = escolha de risco: perguntar clareia, mas gasta paciência (Q-192).
- Decoração como sink de dinheiro no pós-turno (já parcialmente em Upgrades).

## (2) Não copiar

Nomes (Good/Great Pizza, Alicante, Ovenist, Tapblaze), personagens e falas dos pedidos, arte e paleta, o layout idêntico (pá de madeira + grade de caixas), a mecânica de rival/capítulos, ajudantes por diamantes, "Okay/What" literais (usar rótulos próprios).

## (3) Sugestões para a FEAT-039 (Provisório)

- **Layout (paisagem):** ticket no topo (faixa Cream, frase + ícones, anel de paciência); pão/prato no centro-esquerda sobre a tábua; **caixas de molho e complementos em grade 2x3 à direita**, alvos >= 44 px; lixeira embaixo à esquerda; Next/Serve embaixo à direita; Leave sempre visível. Compatível com `prep-mode.md` §2 (painel de ingredientes à direita).
- **Gesto:** molho = **arrastar da caixa e traçar sobre o pão** (zigue-zague, medidor de quantidade; soltar para parar); complemento sólido (queijo, bacon, batata) = **toque único** coloca uma porção, sem regiões livres (ordem livre, até 3). Evita o espalhar livre do pizza (muito dedo no celular). "Segurar" no lugar de arrastar como alternativa de acessibilidade, já prevista.
- **Diálogo como mecânica (opcional, atrás de flag):** ao `Take Order`, mini-cena de 1 tela: fala do cliente + 2 botões. Uma resposta **confirma o pedido literal** ("Got it"); a outra **pergunta** ("Come again?") e revela o detalhe, gastando paciência, ou faz o cliente repetir de forma mais inquietante. A escolha mexe só em (a) qual variante entra no ticket e (b) humor (-1 faixa), nunca em preço (DEC-072 e Q-219 intactos). Ligar a anomalias: clientes "estranhos" (ANM) só oferecem a leitura estranha; servir o literal certo é a regra do Walt.
- **Avaliação:** manter Perfect/Good/Messy e Completo/Incompleto/Errado; o pedido ambíguo não cria categoria nova, só define qual prato é "Completo". Para evitar injustiça, toda frase ambígua precisa de **uma** leitura correta documentada em dados.
- **Ritmo:** pedidos ambíguos só do Dia 3 em diante (Day 1 ensina o literal). Custo: exige conteúdo de texto (narrative-writer) e novo campo no ticket; avaliar contra o orçamento das TASKs P7/P10.

## (4) Cinco pedidos originais (inglês, curtos, aconchegantes + inquietantes)

1. "The usual, please. You know the one." (nunca veio antes; leitura segura: ketchup e mustard)
2. "Mustard, but only on the side facing the window."
3. "Plain. And please don't look while you make it."
4. "Make it taste like Sunday. Not this Sunday."
5. "Whatever she's having. She's right behind me." (ninguém atrás dele)

Cada um precisa de uma leitura canônica em dados (Provisório: o game-designer define).

## Recomendação

Adotar o layout (ticket no topo, caixas em grade à direita, toque para toppings sólidos e arrasto só para molho) agora. Deixar o diálogo com escolhas como extensão da fase seguinte, ligado ao `AnomalyService`, com um campo `Reading` por pedido e sem tocar em preço. Perguntar ao dono: o diálogo entra no V1 ou depois?
