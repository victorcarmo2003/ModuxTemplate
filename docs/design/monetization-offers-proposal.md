Status: Rascunho (decisões do dono: DEC-262 a DEC-268, 2026-10-17)

# Ofertas contextuais (monetização) — proposta

Pedido do dono, 2026-10-17 (resumo): "preciso de um plano para aumentar a monetização; sinto que está fraca". Ideia
dele: ofertas **não intrusivas** — nada de abrir o prompt de compra sozinho; aparece **a notificação do canto superior
direito** (a mesma da loja) oferecendo algo **na hora certa**. Exemplos dele: café baixo → café por 1 Robux; um
ingrediente acabou → refil daquele ingrediente; vários acabaram → restock de todos. Ele quer uma lista de "coisinhas
que dá pra ofertar ali" para **testar o que vende**.

Autor: game-designer (via sessão de planejamento). Tudo aqui é **Provisório** até DEC do dono. Perguntas em
`open-questions.md` **Q-293 a Q-299**; tasks **TASK-361 a TASK-369** (`tasks/board.md`).

**2026-10-17, implementação:** o dono mandou seguir o plano ("pode seguir com esse plano") sem responder Q-293 a Q-299;
a P0 (O1–O8, orçamento, métricas, grupo de controle, A/B do clique, "Shop tips", `/dev offer`) foi feita com as
recomendações deste documento como **Provisórias** (TASK-361 a TASK-366; teste em `tests/offers.md`). Diferenças do
texto: o clique manda só `offer_click` (no lugar do `product_prompt`, que o limite de 0,5 s do `MetricUi` derrubaria);
o O7 conta os registros `Failed` do set `Anomalies` no client (sem aviso novo do servidor). Fora: produtos novos
(TASK-368, precisa do dono no Creator Hub) e ofertas do lobby (TASK-369).

---

## 1. O que já existe (levantamento 2026-10-17)

### 1.1 Catálogo (`src/Shared/Content/Shop.luau`; Creator Hub em `docs/monetization/*.csv`)

| Grupo | Itens (preço sugerido; o real é o do Creator Hub) | Onde se compra | Estado |
|---|---|---|---|
| Gemas (Developer Product) | 1.000 / 2.400 / 4.800 / 10.000 gemas por 99 / 229 / 449 / 899 R$ | lobby, `GemShop` (B) | ids criados |
| Classes (Game Pass) | Coelho, Gato, Urso 79 R$; Raposa, Coruja 199 R$ | lobby, `ClassSelect` | ids criados; preço × gemas em aberto (`Q-274` c) |
| Utilidades da run (Developer Product) | Hot Coffee 10, Anomaly Radar 20 (só noite), Wild Restock 25 (1 ingrediente, escolhe), Full Pantry 59, Revive Kit 39, Scare a Friend 50, Tip Bag $60 / 29, Coin Pile $150 / 69, Coin Chest $330 / 149 | run, carrinho do HUD (B) → `ShopPanel` | todos com id |
| Presentes (Developer Product) | um por pacote de gemas e por classe, mesmo preço | lobby, botão de presente | ids criados (TASK-352/353) |
| Códigos | grátis | lobby | — |

### 1.2 Pontos de venda e "empurrões" que já existem

| Mecanismo | Arquivo | Comportamento hoje |
|---|---|---|
| **HudNudge** (a "notificação do canto superior direito") | `Interface/Components/HudNudge`, posição em `HudScreen` (`NUDGE_TOP`, embaixo da coluna engrenagem/carrinho) | botão Mustard clicável; texto `""` = escondido. Dono do texto: `ShopController.Nudge` |
| Nudge do Scare | `ShopController:StepNudge` | 1ª vez 120 s após o HUD, depois a cada 240 s, 1,2 s na tela, só com outro jogador no servidor, fora do preparo/cutscene. Clique abre a loja e o card do Scare pisca 1 s |
| Recibo na nota | `ShopController:Note` | "+$60 for the crew!" por 2,5 s no mesmo slot |
| Compra da diferença em Cash | `EconomyService:Spend` → `PromptCashPack` (`Shop/shared/TopUp.luau`) | faltou dinheiro numa compra da run → **abre o prompt sozinho** do menor pacote que cobre; 1 por `TOP_UP_COOLDOWN` |
| Compra da diferença em gemas | `ClassService` (TopUp.Gems) | idem no lobby, ao comprar classe sem gemas |
| Revive now | `ReviveKitController` (TASK-330) | caído sem crédito vê "Revive now · R$ n" na tela de desmaio (clique = prompt) |
| Comemoração | `PurchaseFxController` | confete + faixa com o nome do item |
| Métrica | `MetricsService` (RoMetrics) + packet `MetricUi` (`Content.Metrics.UiEvents`) | `shop_open`/`shop_close`, `product_prompt`, prompt fechado sem compra, recibo (`Log.receipt`) |

### 1.3 Diagnóstico — por que a venda parece fraca

1. **A vitrine da run é passiva.** As 9 utilidades só aparecem se a criança aperta B ou clica no carrinho. O único
   empurrão é o Scare, que **só existe com 2+ jogadores** — o solo nunca vê nada.
2. **O momento de necessidade passa sem oferta.** O jogo já sabe quando falta pão, quando a sanidade está no fim,
   quando um colega caiu, quando a noite foi perdida — e não diz nada.
3. **O slot existe e está quase vazio.** O HudNudge já é clicável, está no canto certo e já é do `ShopController`.
   É o lugar mais barato para crescer: gatilho novo = dado + regra, sem tela nova.
4. **Dois pontos fazem o contrário do que o dono quer:** o `PromptCashPack` abre o prompt do Roblox sozinho quando
   falta dinheiro (`Q-294`).
5. **Não há "primeira compra" barata.** O item mais barato custa 10 R$. Em jogos infantis, a 1ª compra é a barreira;
   depois dela a criança (e o responsável) compra de novo com muito mais facilidade (`Q-295`).

---

## 2. Princípios (público infantil e regras do Roblox)

Público **infantojuvenil** (DEC-023). As regras abaixo valem para toda oferta e não se negociam por gatilho:

| # | Regra |
|---|---|
| R1 | **Nunca abrir o prompt do Roblox sem um clique do jogador.** A oferta é só a notificação; o prompt do Roblox (que já pede confirmação) só abre depois do clique nela. |
| R2 | **Preço sempre visível** na notificação ("R$ 25"), lido do Creator Hub (`GetProductInfo`), igual à loja. |
| R3 | **Sem pressão falsa:** sem contador regressivo, sem "só agora!", sem "oferta acaba em", sem escassez inventada, sem desconto falso. |
| R4 | **Sem culpa nem medo como argumento:** nada de "seus amigos precisam de você!", "você vai morrer". Texto neutro e útil ("Out of buns! Refill?"). |
| R5 | **Nunca no meio do susto:** nada durante anomalia em fase `Signal`/`Active`, jumpscare, perseguição, cutscene, cinemática, modo de preparo, nem com a loja ou as configurações abertas. |
| R6 | **Nunca no tutorial:** primeira run, Dia 1 e Noite 1 (a lição do café da Noite 1 é **grátis** e não pode virar venda). |
| R7 | **Sempre dá para ignorar:** some sozinha em poucos segundos, não bloqueia nada, ignorar não tem castigo. |
| R8 | **Liga/desliga** nas configurações ("Shop tips: On/Off", ligado por padrão). |
| R9 | **Uma de cada vez**, com orçamento e cansaço (§4). Ignorou duas vezes o mesmo gatilho → ele se cala na run. |
| R10 | Item da oferta = item da loja (mesmo `ProductId`, mesmo preço, mesmo efeito). A oferta é um **atalho**, não um preço diferente escondido. |

Sem caixa de sorteio pago (nenhum item aleatório por Robux), então `PolicyService.ArePaidRandomItemsRestricted` não
se aplica; se um dia entrar, a oferta respeita esse flag.

---

## 3. Catálogo de gatilhos ("coisinhas para ofertar")

Legenda — **Onde:** o sinal já chega ao client (C) ou precisa de aviso do servidor (S). **Prioridade:** P0 = produto
já existe e o sinal já existe; P1 = falta um pedaço pequeno; P2 = produto novo (o dono cria no Creator Hub).

### 3.1 P0 — produtos existentes, testar primeiro

| # | Momento do jogo | Oferta (texto na nota, inglês) | Produto | Limite | Sinal |
|---|---|---|---|---|---|
| O1 | **Sanidade baixa** à noite: ≤ 35% do máximo, sem café na mão, cafeteira longe ou limpando | "Sanity low! Hot coffee · R$ 10" | `util_coffee` | 1 por noite | C: packet `Sanity`, `Stations` (cafeteira), hotbar |
| O2 | **Um ingrediente acabou** (Amount 0, aberto: não `Blocked` nem `Wrapped`) durante a venda | "Out of buns! Refill · R$ 25" (nome do ingrediente) | `util_restock` com o **alvo já escolhido** (o que acabou; `ShopPick` antes do prompt) | 1 por ingrediente por turno; até 2 por turno | C: set `Stock` |
| O3 | **Vários acabaram:** 2+ ingredientes em 0 **ou** 3+ abaixo de 20% | "Running out! Refill everything · R$ 59" | `util_pantry` | 1 por turno; **substitui** O2 quando os dois valem | C: set `Stock` |
| O4 | **Faltou dinheiro** numa compra da run (Gear Stand, Mart) | "Need $40 more? Tip Bag +$60 · R$ 29" | o menor pacote Cash que cobre (`TopUp.Cash`) | o cooldown atual do TopUp | S: hoje `Spend` abre o prompt sozinho; vira aviso para a nota (`Q-294`) |
| O5 | **Um colega caiu** (Down) e eu estou de pé, sem Revive Kit | "Max fainted! Revive Kit · R$ 39" | `util_revive` (DEC-258: o kit vale no colega) | 1 por queda de colega | C: set `Vitals` |
| O6 | **Noite perdida:** começo da noite repetida | "Try again with the Anomaly Radar · R$ 20" | `util_radar` | 1 por noite repetida | C: fase da rodada |
| O7 | **Errou uma anomalia** (2ª falha da mesma noite) — quando a fase calma voltar | "Spot them all: Anomaly Radar · R$ 20" | `util_radar` | 1 por noite, cooldown **dividido** com O6 | S/C: `LifeEvent` (Hit/Down) ou aviso de falha da `AnomalyService` |
| O8 | **Levei um susto de um colega** (recebi `util_scare`) — 20 s depois | "Scare Lia back! · R$ 50" | `util_scare` com o alvo = quem assustou | 1 a cada 10 min | C: `ShopGrant` (From) |
| O9 | Nudge do Scare (já existe) | "Press B to scare your friends" | `util_scare` | o de hoje, mas **entra no orçamento** (§4) e cede a vez a O1–O8 | C |

Por que esses primeiro: são exatamente os momentos em que a criança **já quer** aquilo (falta pão, sanidade no fim,
amigo caído). Converte melhor e irrita menos que oferta aleatória.

### 3.2 P1 — pequeno trabalho a mais

| # | Momento | Oferta | Produto | Observação |
|---|---|---|---|---|
| O10 | **Fila cheia e grelha lenta** (3+ clientes esperando, pedido saindo devagar) | "Busy night! +$60 for upgrades · R$ 29" | `cash_100` | precisa de uma regra de "pressão" (fila + paciência); medir se não vira ruído |
| O11 | **Quase pagando um upgrade** perto do Gear Stand (faltam ≤ $60) **sem** clicar em comprar | "Only $35 to the Grill! Tip Bag · R$ 29" | o menor Cash que cobre | estende O4 para antes do clique; só olhando o pedestal |
| O12 | **Fim do dia com caixa baixo** para a noite (Cash abaixo do preço do próximo upgrade útil) | "Get ready for the night: Coin Pile · R$ 69" | `cash_300` | 1 por run, no Closing |
| O13 | **Cliente foi embora por falta de ingrediente** (pedido recusado / desistiu por estoque) | igual a O2 | `util_restock` | reforço de O2 quando o pedido falhou; precisa do motivo no `CustomerService.Acted` |

### 3.3 P2 — produtos novos para testar o que vende (o dono cria no Creator Hub)

| # | Produto novo | Tipo | Preço sugerido | Onde aparece | Por quê |
|---|---|---|---|---|---|
| N1 | **First Coffee** (1ª xícara) | Developer Product, **1 vez por jogador** (flag no perfil) | **1 R$** | O1 na 1ª vez de cada jogador; depois O1 usa o `util_coffee` normal | é o "café por 1 Robux" do dono sem baixar o café para sempre; quebra a barreira da 1ª compra. A receita dele é quase zero — o ganho está na 2ª compra (`Q-295`) |
| N2 | **Night Kit** (Coffee + Radar + Revive Kit) | Developer Product | ~55 R$ (soma 69) | começo da noite 3+ e na noite repetida (O6) | pacote vende mais que avulso; preço abaixo da soma sem ser "desconto falso" (o valor é real e fixo) |
| N3 | **Starter Crate** (2.400 gemas + 2 Revive Kits), **1 vez por jogador** | Developer Product | 99 R$ | lobby, depois da 1ª run terminada (nota no lobby) | oferta de boas-vindas clássica; o lobby é de outras sessões (TASK-369) |
| N4 | **Thermos** (1 café grátis no começo de cada noite) | Game Pass | 149 R$ | O1 a partir do 3º café comprado ("You bought 3 coffees: Thermos gives one every night") | transforma compra repetida em passe; vantagem pequena e só de sanidade |
| N5 | **Cosméticos** (cor do trailer, avental, rastro de confete no servir) | Game Pass / Developer Product | 49–199 R$ | fora das ofertas contextuais: vitrine no lobby | a guarda da DEC-069 prefere cosmético; maior espaço de crescimento sem pay-to-win; precisa de art-director |
| N6 | **Presente contextual** | Developer Product (já existe) | o do item | lobby: amigo do squad sem a classe que eu tenho → "Gift Cat Crew to Lia" | social; lobby de outras sessões |

O dono escolhe quais N criar (`Q-298`); cada um precisa de id no Creator Hub e linha em `Content.Shop`.

---

## 4. Orçamento, prioridade e cansaço

Números **Provisórios** (`Q-296`), num lugar só (`Content.Shop.OfferRules`, TASK-361):

| Regra | Valor |
|---|---|
| Na tela ao mesmo tempo | 1 (o slot do HudNudge) |
| Tempo na tela | 6 s (o Scare segue 1,2 s) |
| Intervalo mínimo entre duas ofertas quaisquer | 120 s |
| Máximo por turno (dia ou noite) | 3 (o Scare conta) |
| Por gatilho | o "Limite" da tabela do §3 |
| Ignorou o mesmo gatilho 2 vezes na run | o gatilho se cala até o fim da run |
| Ignorou 4 ofertas seguidas | pausa de 15 min em todas |
| Depois de um prompt de compra fechado (comprou ou não) | 60 s sem oferta |
| Prioridade quando duas valem juntas | O5 (colega caído) > O1 (sanidade) > O3 > O2 > O4 > O6/O7 > O8 > O9 |
| Bloqueios | R5, R6, R8; `ProductId` 0; jogador Down (já tem o botão "Revive now") |

Clique na nota (`Q-293`): **recomendação = abre direto o prompt do Roblox** do item, com o alvo já escolhido (O2:
o ingrediente; O8: quem assustou). São 2 toques (nota → confirmar do Roblox), e o prompt do Roblox é a confirmação.
Alternativa: abrir a loja com o card piscando (o fluxo do Scare de hoje), que é 3 toques e converte menos. Dá para
testar as duas (§5).

---

## 5. Como medir (o "testar o que vende" do dono)

Eventos novos em `Content.Metrics.UiEvents` (packet `MetricUi`, já vai para o RoMetrics): `offer_shown`,
`offer_click`, `offer_expired`, `offer_muted` (gatilho calado por cansaço) e `offers_off` (desligou nas
configurações). Cada um com a chave da oferta (O1…O9) e o produto. O funil fecha com o `product_prompt` e o recibo
(`Log.receipt`, que já existe).

| Métrica | Conta | Para quê |
|---|---|---|
| CTR da oferta | `offer_click` ÷ `offer_shown` | a nota chama atenção? |
| Conversão | recibos ÷ `offer_shown`, por gatilho | o que vende de verdade |
| R$ por 1.000 exibições | Robux ÷ exibições × 1.000 | compara gatilhos de preços diferentes |
| Irritação | saída do jogo até 2 min depois de uma oferta; `offers_off`; `offer_muted` | o custo de cada gatilho |
| Saúde | tempo de sessão, runs terminadas, volta no D1, entre grupo com e sem ofertas | a oferta não pode derrubar o jogo |
| 1ª compra | jogadores com ≥ 1 compra ÷ jogadores ativos; tempo até a 1ª compra | efeito do First Coffee (N1) |

**Grupo de controle:** 10% dos jogadores (por `UserId`, fixo) **não veem ofertas contextuais** (`Q-299`). Sem isso
não dá para saber se a oferta criou venda nova ou só mudou de lugar a venda da loja.

**Teste A/B do clique:** metade abre o prompt direto, metade abre a loja com o card piscando (`Q-293`).

**Critério para manter um gatilho** (após ~500 exibições dele): conversão ≥ 1% **e** irritação não pior que o
grupo de controle. Abaixo disso: muda o texto/momento uma vez; se continuar ruim, desliga (é uma linha de dado).

---

## 6. Desenho técnico em uma frase por peça (detalhe nas tasks)

- **Dados:** `Content.Shop.Offers` (chave, produto, gatilho, limites, texto, prioridade, `Enabled`) e
  `Content.Shop.OfferRules` (§4). Gatilho novo = linha nova; desligar = `Enabled = false`, sem código.
- **Cérebro:** `OfferController` (client, `src/Shop/client/`) lê o que já replica (`Stock`, `Sanity`, `Vitals`,
  `Stations`, fase da rodada, `ShopGrant`, fase das anomalias) e decide; não muda nada no servidor.
- **Vitrine:** `ShopController` ganha um modo "oferta" no mesmo slot do HudNudge (ícone + texto + preço, 6 s; clique
  = `ShopPick` do alvo + prompt). O Scare cede a vez.
- **Servidor:** só O4 (troca o `PromptProductPurchase` automático do `Spend` por um aviso `ShopOffer` para o dono da
  compra) e, se precisar, o aviso de falha de anomalia para O7. O recibo continua todo no `ShopService` /
  `ShopUtilityService` (autoridade do servidor; o client nunca concede nada).
- **Configuração:** "Shop tips" no painel de configurações.
- **Dev:** `/dev offer <chave>` força uma oferta para testar no Studio.

Fora do escopo das tasks P0: `src/Lobby`, `src/Session`, `src/Round`, `src/Run` e `ClassSelect` (outras sessões).
As ofertas de lobby (N3, N6) ficam para depois (TASK-369).

---

## 7. Ordem recomendada

1. **Semana 1 (P0):** O1, O2, O3, O5, O6, O8 + orçamento + métricas + grupo de controle + "Shop tips". Tudo com os
   produtos que já existem.
2. **Junto, se o dono aprovar:** O4 (Cash vira oferta, sem prompt automático) e **N1 First Coffee** (precisa do id).
3. **Depois de ~2 semanas de dados:** desliga o que não vende, testa P1 (O10–O13) e os produtos novos N2/N4.
4. **Em paralelo e fora das ofertas:** cosméticos (N5) e decidir o preço dos passes de classe (`Q-274` c) — é o
   maior item de ticket alto do jogo e hoje está barato frente às gemas.

---

## 8. Decisões do dono (2026-10-17) e o que mudou no código

| Pergunta | Decisão | No código |
|---|---|---|
| Q-293 | **DEC-262**: clique abre o prompt com o alvo; A/B de 2 semanas (metade abre a loja com o card piscando). Tecla na nota: **G** (teclado) e **Y** (controle), só enquanto a nota está na tela; nunca E / X (prompts do mapa). Texto sempre com verbo de compra e preço, nunca "Collect"/"Free" | `OfferRules.ShopShare = 0.5`; `ShopController` (`OFFER_KEY`, `OFFER_PAD`, dica "[G]" / imagem do Y) |
| Q-294 | **DEC-263**: run vira nota; lobby mantém o prompt da classe | `EconomyService:PromptCashPack` → `ShopOffer`; `ClassService` intocado |
| Q-295 | **DEC-264**: café fica 10 R$, sem First Coffee | nada |
| Q-296 | **DEC-265**: números do §4 | `OfferRules` |
| Q-297 | **DEC-266**: oferta do kit para quem está de pé | O5; nota em FEAT-034 |
| Q-298 | **DEC-267**: Night Kit, Starter Crate, Thermos (id 0 até o Creator Hub), cosméticos depois | `util_night_kit` (+ oferta `offer_night_kit` da noite 3 em diante), `Content.Shop.Bundles.starter_crate` (perfil `OneTimeBought`), `Content.Shop.Passes.pass_thermos` (café na mão no começo de cada noite) |
| Q-299 | **DEC-268**: sem grupo de controle | `OfferRules.ControlShare = 0` |

Textos das notas (inglês, com o preço real do Creator Hub): "Need a coffee? Get one · R$ 10 [G]", "Out of Bun! Refill it ·
R$ 25 [G]", "{nome} fainted! Get a Revive Kit · R$ 39 [G]", "Need $40 more? Tip Bag +$60 · R$ 29 [G]", "Long night ahead?
Get the Night Kit · R$ 55 [G]".

Ainda sem tela (TASK-369): a vitrine do Starter Crate no lobby e a compra do Thermos (Game Pass) em algum card.

## 9. Comandos de teste no Conch (pedido do dono 2026-10-17; TASK-376, só desenho)

Pedido: "testar algumas dessas coisas através do Conch para conseguir forçar alguns eventos, só para ver como aparece a
notificação, ou até mesmo forçar alguns status também". Conch = console F2 (`src/Admin/server/AdminService.luau`); os
comandos novos seguem a regra dele: atalho tipado que **encaminha ao DevService** (só existe no modo dev do Studio), sem
lógica nova no AdminService. Argumentos tipados em `AdminArguments` a partir do `Content` (autocompletar).

| Comando Conch | Faz | Encaminha para |
|---|---|---|
| `offer <chave>` | mostra a nota dessa oferta na hora, ignorando orçamento e cooldown (`offer_coffee`, `offer_restock`, …) | `/dev offer <chave>` (já existe, TASK-366) |
| `offer list` / `offer status` / `offer reset` | lista as chaves e os gatilhos; mostra o que bloqueia agora (tips, tutorial, calma, orçamento); zera contadores | `/dev offer …` (já existe) |
| `stock <ingrediente> <n>` | põe o estoque de um ingrediente em n (0 = acabou: dispara O2 de verdade) | **novo** `/dev stock` (KitchenService, só dev) |
| `stock empty <n>` / `stock low` | zera n ingredientes abertos / deixa todos abaixo de 20% (dispara O3) | **novo** `/dev stock` |
| `sanity <n>` | sanidade do jogador (ex.: 20 = abaixo de 35%, dispara O1 à noite) | `/dev sanity` (já existe) |
| `coffee <n>` | doses da cafeteira (café da máquina baixo) | `/dev coffee` (já existe) |
| `cash <n>` | caixa da party (0 + tentar comprar = O4) | Conch `cash` (já existe) |
| `down [player]` | o jogador desmaia (num segundo jogador, dispara O5 para quem está de pé) | `/dev down` (já existe) |
| `night <n>` | pula para a noite n (a partir da 2 as ofertas valem; 3+ = Night Kit) | Conch `night` (já existe, feito pela sessão do tablet) |
| `scareme [player]` | simula receber um Scare de um colega (dispara O8 em 20 s) | **novo**: `ShopGrant` falso só no dev |
| `failanomaly` | marca 2 anomalias como erradas na noite (dispara O7) | `anomaly <id> wrong` (já existe) 2× |
| `receipt <chave>` | concede um produto sem Robux (Night Kit, Starter Crate…) para ver o efeito | `/dev receipt` (já existe, `ShopService:DevReceipt`) |

Novos de fato: `stock` e `scareme` (DevService) e os atalhos Conch `offer`, `stock`, `sanity`, `coffee`, `down`,
`scareme`, `receipt`. O resto já existe e só ganha atalho tipado.
