Status: Rascunho

# Ofertas contextuais — plano de teste (TASK-367)

Fonte: `design/monetization-offers-proposal.md`; código em `src/Shop/client/OfferController.luau`,
`src/Shop/client/ShopController.luau` (`Offer`, `PromptOffer`, `ShowCard`), `Content.Shop.Offers` / `OfferRules`,
`EconomyService:PromptCashPack` (agora `ShopOffer`). Valores Provisórios (`Q-293` a `Q-299`).

## 0. Ferramentas

- `/dev ui offer status`: grupo (control / shopClick), o que bloqueia agora (tips, tutorial, calma, orçamento, `CanOffer`),
  contagem do turno, pausa, ofertas caladas. Saída no Output do **client**.
- `/dev ui offer list` · `/dev ui offer reset` (zera tudo) · `/dev ui offer <chave>` (força a oferta, sem orçamento).
- Sem grupo de controle (DEC-268). Conch: comandos de estado em `design/monetization-offers-proposal.md` §9 (TASK-376, ainda não feitos).
- Dia/Noite 1 bloqueiam por regra: para os gatilhos naturais, avance (`/dev day 2`, `/dev night 2` ou o comando de
  rodada do projeto).

## 1. Visual (feito em 2026-10-17)

| # | Passo | Esperado | Resultado |
|---|---|---|---|
| V1 | `/dev ui offer offer_restock` | nota Mustard abaixo do carrinho: ícone do produto + "Out of Bun! Refill · R$ n" (preço do Creator Hub) por 6 s | ok (antes do "·": "Refill R$ 23") |
| V2 | `/dev ui offer offer_revive_mate` | "{nome} fainted! Revive Kit · R$ n" com ícone do kit | ok (R$ 36) |
| V3 | as 8 chaves em celular (emulador 844×390) e controle | cabe na tela, não cobre relógio/dinheiro/joystick; no controle a nota é clicável pelo cursor virtual | a fazer |

## 2. Clique

| # | Passo | Esperado |
|---|---|---|
| C1 | jogador do braço "Prompt" clica numa oferta | abre o prompt do Roblox do produto **só depois do clique**; restock e scare já vão com o alvo (`ShopPick`) |
| C1b | nota na tela, apertar **G** (teclado) / **Y** (controle) | mesmo efeito do clique; a nota mostra "[G]" ou a imagem do Y; fora da nota a tecla não faz nada (DEC-262) |
| C2 | jogador do braço "Shop" (`/dev ui offer status` mostra `shopClick=true`) clica | abre a loja com o card do produto piscando 1 s |
| C3 | comprar pelo prompt | recibo normal (`ShopGrant`), confete (`PurchaseFxController`); 60 s sem oferta depois |
| C4 | fechar o prompt sem comprar | 60 s sem oferta; nada é concedido |
| C5 | uma nota de recibo / o nudge do Scare aparece em cima de uma oferta | o clique na nota nova **não** compra a oferta antiga |

## 3. Gatilhos naturais (a partir do Dia/Noite 2)

| # | Gatilho | Como provocar | Esperado |
|---|---|---|---|
| G1 | Sanidade (O1) | noite, deixar a sanidade cair abaixo de 35% sem café na mão | "Sanity low! Hot coffee" 1×/noite; com café na mochila não aparece |
| G2 | Acabou ingrediente (O2) | vender até zerar um ingrediente aberto | "Out of {ingrediente}!" uma vez por ingrediente por turno; tigela trancada/presente não conta |
| G3 | Vários (O3) | 2 zerados ou 3 abaixo de 20% | "Refill everything" no lugar do O2 |
| G4 | Cash (O4) | tentar comprar no Gear Stand sem dinheiro | **não** abre prompt sozinho; aparece "Need $X more? +$Y" (se o orçamento deixar) |
| G5 | Colega caído (O5) | 2 jogadores, um desmaia à noite, o outro sem kit | "{nome} fainted! Revive Kit" para quem está de pé; com kit no perfil não aparece |
| G6 | Noite repetida (O6) | perder a noite | na noite repetida, depois de 10 s sem anomalia viva: "Try again with the Anomaly Radar" |
| G7 | Falhas (O7) | errar 2 anomalias na noite | "Spot them all" quando ficar calmo |
| G9 | Night Kit | noite 3+, depois de criar o produto | "Long night ahead? Get the Night Kit" 1×/noite; com id 0 nunca aparece |
| G8 | Scare back (O8) | colega compra Scare em você | 20 s depois "Scare {nome} back!" com o alvo = quem assustou |

## 4. Regras que não podem falhar

| # | Situação | Esperado |
|---|---|---|
| R1 | qualquer caminho | nenhum `PromptProductPurchase` sem clique (grep: só `ShopController:Prompt/PromptOffer`, `ReviveKitController`, lobby, presentes) |
| R2 | anomalia em `Signal`/`Active`, modo de preparo, cutscene, loja/configurações abertas, jogador caído | nenhuma oferta |
| R3 | Dia 1 e Noite 1 | nenhuma oferta (lição do café grátis intacta) |
| R4 | "Shop tips: Off" nas configurações | nenhuma oferta; o nudge do Scare segue; métrica `offers_off` |
| R5 | duas ofertas seguidas | ≥ 120 s entre elas; ≤ 3 por turno contando o Scare |
| R6 | ignorar a mesma oferta 2× | ela some até o fim da run (`offer_muted`); 4 ignoradas seguidas = pausa de 15 min |
| R7 | produto com `ProductId` 0 | nunca oferecido |

## 5. Métricas (RoMetrics)

Funil por oferta: `ui_offer_shown` → `ui_offer_click` → recibo (`Log.receipt`, sku = produto) ou
`product_prompt_closed`. Props `key` (produto) e `offer` (chave). Sem grupo de controle (DEC-268): comparar antes × depois das ofertas e os braços do A/B do clique. Critério do §5 da proposta: conversão ≥ 1% sem
irritação maior que o controle, depois de ~500 exibições por oferta.
