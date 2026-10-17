# Pedido do dono — 2026-10-17: trailer vira restaurante ("Overcooked de anomalia")

Fonte primária (fala do dono, transcrita e organizada pelo orquestrador). Esboço: `2026-10-17-restaurante-esboco.webp` (mesma pasta).
Este arquivo é **fonte**, não decisão. O secretário registra a DEC.

## Problema que motivou

- O fluxo atual (trailer pequeno, um balcão) tem um gap no atendimento: com 2 jogadores, um cozinha e o outro fica olhando.
- Meta: **todo mundo trabalhando ao mesmo tempo, em paralelo**, com progressão para todos. Co-op divertido com amigos.
- Mas **solo não pode ficar chato**: precisa de progressão/upgrades que tornem o solo viável mantendo o paralelismo no co-op.
- O jogo já está publicado e com anúncio rodando: prioridade é velocidade.

## Novo layout (esboço, vista de cima)

- O trailer sai; entra um **pequeno restaurante** (prédio retangular, piso claro, paredes rosadas no esboço).
- **Frente (onde hoje fica a área na frente do trailer): MESAS DE CLIENTES** — mesinhas de piquenique (asset que já existe). 4 mesas no esboço. Arbustos/plantas verdes na lateral direita.
- **Parede da frente do restaurante, voltada para as mesas:** linha de **TABLETS DE ATENDIMENTO** (4 pontos azuis no esboço = 4 caixas/tablets) sobre um balcão.
- **À esquerda dos tablets: PORTA SAÍDA** — por ela o jogador sai da cozinha para entregar o pedido na mesa do cliente.
- **Centro da cozinha: MESA DE MONTAGEM** — bancada longa com uma fileira de pratos (8 círculos no esboço).
- **Fundo da cozinha (parede de trás), da esquerda para a direita:** **grelhas**, **salsichas** (estoque), **pão/condimentos**.
- **Lateral direita: DRIVE THROUGH** — pista de carro passando pelo lado direito do prédio, com um **computador de atendimento** (ponto azul) na parede direita.

## Fluxo do cliente de mesa

1. Cliente chega **pelo meio** (entre as mesas), vai a um dos **tablets de atendimento**.
2. Jogador no tablet interage: mini-diálogo ("Olá, bom dia" / cliente: "Olá, bom dia, eu gostaria de um hot dog assim, assim").
3. A **notinha de pedido** (a que já existe, no canto superior esquerdo do HUD) **é construída durante o diálogo**: aparece a nota; cliente diz "vou querer um pão" → pop-up animado do pão entra na nota; "salsicha" → pop-up; cada condimento → pop-up.
4. Pedido confirmado vai **automaticamente para a mesa de montagem**: um **prato meio transparente** (slot) recebe o pedido e ganha uma **BillboardGui** em cima mostrando o papel do pedido.
5. Montagem (qualquer jogador): **cortar o pão e colocar no prato**; **grelhar a salsicha, pegar e colocar no prato**; **pegar o prato e levar à estação de condimentos**, aplicar todos.
6. **Entrega:** levar o prato pela **porta saída** até o cliente **sentado na mesa**.

## Fluxo do drive-thru

- Carro para na janela do lado direito; jogador atende no **computador de atendimento**.
- Se esperar muito: **buzina**, depois fica **estressado e vai embora**.
- **Pets** podem vir de dentro do carro. Abre margem para **anomalias** no drive-thru.

## Papéis paralelos desejados (exemplos do dono)

- alguém grelhando e empilhando várias salsichas;
- alguém cortando pães e colocando nos pratos;
- alguém no caixa/tablet atendendo;
- alguém entregando os pedidos nas mesas;
- (drive-thru como frente extra).

## O que o dono pediu para planejar/fazer

1. Nova construção do mapa (restaurante + mesas + drive-thru).
2. Anomalias condizentes com o novo fluxo.
3. Upgrades novos para esse fluxo (incluindo os que viabilizam o solo).
4. Implementar o quanto der, em paralelo.

## Adendo 2 (mesma data) — estoque com caixas

Imagens: `2026-10-17-mapa-atual-topo.webp` (vista de cima do Pad atual: trailer, 4 mesas xadrez, letreiro CORNER DOGS, rua à direita) e `2026-10-17-caixas-estoque.png` (caixas de papelão com rótulo MUSTARD / DOGS / BUNS que já existem no mapa).

Fala do dono (transcrita): "nova mecânica de estoque [infinito?]". As caixas existentes são usadas para **reabastecer o estoque** dos produtos. Proposta a avaliar com level-designer e secretário: o jogador **pede mais produtos por um telefone**, chega um **carrinho/veículo de entrega** que **despeja as caixas** num ponto do restaurante, o jogador **pega as caixas e reabastece** as estações (interatividade no estoque).

Ambíguo (vai para Q do secretário): a palavra "infinito" — provável que seja "estoque físico"/caixas; e se isso substitui a ida ao Mart para comprar ingredientes ou convive com ela.
