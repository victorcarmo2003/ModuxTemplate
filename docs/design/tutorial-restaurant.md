Status: Rascunho

# Tutorial mínimo do restaurante (TASK-393)

Base: `design/restaurant-flow.md` (FEAT-043..050), `tech/restaurant-flow.md` §5 R2. Tudo **Provisório** até DEC do usuário.
Textos em inglês, curtos (DEC-022); o narrative-writer revisa depois (os textos ficam em
`src/Tutorial/client/TutorialController/Steps.luau`).

Chave: só vale com `Content.Restaurant.Rules.Enabled = true`. Desligada, o tutorial do trailer fica idêntico (mesmos
passos, mesma ordem, mesma lição de upgrade desligada).

## 1. Princípio (o mesmo do tutorial atual)

- Walt conduz pelo telefone; o painel de texto continua desligado (`SHOW_PANEL = false`). Guia na tela = destaque
  pulsante + seta 3D na peça do passo, seta de borda quando fora da tela, lembrete curto falado após 12 s sem progresso.
- O passo é **decidido ao vivo** pelo estado replicado (set `Customers` do cliente do tutorial, `Restaurant.Tablets`,
  `Restaurant.Plates`, `Stations`, `Stock`, `Restaurant.Supply`, atributo `Boxes` das baias, Tool na mão). Nada é
  previsto no client; o servidor decide tudo.
- Cliente do tutorial: o mesmo (`Tutorial.Rules`: pedido fixo ketchup, sem relógio, fora da nota). O Day 1 fica parado
  enquanto alguém tem o tutorial (gancho atual do `TutorialService`).

## 2. Passos

| # | Chave | Gatilho (entra quando) | Seta / destaque | Fala do Walt (Say) |
|---|---|---|---|---|
| 1 | `phone` | telefone tocando | `answer_phone` | (saudação) |
| 2 | `open` | fase Prep | alavanca `shutter_toggle` | "Open the window." |
| 3 | `wait_customer` | cliente chegando / na fila | o rig | "Your first customer's coming." |
| 3 | `r_tablet` | cliente em `Ordering` no `Q1`, `TAB-1` livre | `tablet_take` do `TAB-1` | "Take their order at the tablet." |
| 3 | `r_listen` | `Tablets[n].Npc` = cliente, `Talking` | nenhuma (a nota abre) | "Listen. It's on your note." |
| 4 | `r_cut` | prato de trabalho sem pão, mão sem `bun_sliced` | `bun_slice` do `CUT` | "Slice a bun at the board." |
| 4 | `r_bun_plate` | mão com `bun_sliced`, prato sem pão | `plate_put` do prato de trabalho | "Bun on the plate." |
| 5 | `r_grill` | prato sem salsicha, grelha vazia | `grill_place` | "Frank on the grill." |
| 5 | `r_cooking` | grelha `Working` sem flip aberto | `grill_collect` (a grelha) | (silencioso) |
| 5 | `r_flip` | prompt `grill_flip` ligado | `grill_flip` | "Flip it." |
| 5 | `r_collect` | grelha `Ready` | `grill_collect` | "Done. Off the grill." |
| 5 | `r_rail` | pilha com salsicha | `rail_take` | "Grab the dog." |
| 5 | `r_dog_plate` | mão com `sausage_grilled`, prato sem salsicha | `plate_put` do prato de trabalho | "Dog on the plate." |
| 6 | `r_take_plate` | prato de trabalho com pão e salsicha | `plate_take` do prato de trabalho | "Pick up the plate." |
| 6 | `r_toppings` | `hot_dog` na mão sem o condimento pedido | `topping_add` do ketchup | "Ketchup on it." |
| 6 | `r_discard` | `hot_dog` com condimento não pedido | `discard` | "Not what they asked. Toss it." |
| 7 | `r_pickup` | `hot_dog` certo na mão | `pickup_serve` do `PICKUP` | "Hand it over at pickup." |
| 7 | `r_crew` | nenhum prato em andamento, nada na mão e um colega segurando um `hot_dog` | `PICKUP` | (silencioso) |
| 8 | `money` | `Sale` do cliente do tutorial | holofote no dinheiro | (atual) |
| 9 | `r_call` | depois do `money`, com `Supply` ligado e o telefone `PHONE-R` no mapa | `order_stock` | "Low on stock? Call it in." |
| 9 | `r_boxes` | `Supply[1] = OnTheWay` | nenhuma | "Boxes are on the way." |
| 10 | `r_box` | alguma baia (`StockShelf`, `Boxes > 0`) ou a escotilha com caixa | `take_box` mais perto | "Boxes are in. Grab one." |
| 11 | `r_restock` | mão com caixa (Tool de pacote) | `restock` da estação do ingrediente da caixa | "Restock its station." |
| — | fim | o estoque daquele ingrediente subiu (quem quer que tenha reabastecido) | — | "Stocked up!" + despedida |

Prato de trabalho: o cliente do tutorial não recebe ticket de prato (`CustomerService` não dispara `Acted` para ele) e
o veredito é pelos condimentos, então qualquer prato serve. O tutorial aponta o prato mais adiantado (pão e salsicha >
um dos dois > vazio; empate = menor índice), preferindo os sem ticket.

Sem `Supply` ligado (ou sem `order_stock` no mapa) o tutorial termina no `money`, como hoje.

Reabastecimento: o depósito está sendo refeito (salsicha/bacon no freezer, queijos na geladeira, secos na prateleira,
tudo de um lado da parede). O tutorial só depende do contrato: tag `StockShelf` + atributo `Package` + âncora
`Prompt_TakeBox` (`take_box`); a seta vai na âncora ligada mais perto. Caixa na mão → a seta vai no `restock` da estação
cujo `Ingredient` é o do pacote (pão = `CUT`, salsicha = grelha, condimentos = `COND`).

Dinheiro: depois que o cliente do tutorial foi atendido, com um novato pendente e nenhuma ligação a caminho, o servidor
completa o caixa até o preço do pedido rápido do telefone (`EconomyService:TopUp`, uma vez), como o tutorial já faz com o
pacote de pão. A ligação nunca trava por falta de dinheiro.

Espera da entrega (`Supply.Eta`, 45 s): o Day 1 continua parado; Walt avisa e repete a fala a cada 20 s.

## 3. Fim do Day 1: Gear Stand

A lição de upgrade das 18h (já existente, desligada no trailer desde 2026-10-17) volta **só no restaurante**
(`Tutorial.Rules.Upgrade.Enabled = Restaurant.Rules.Enabled`): no `Closing` do Day 1, com um novato no servidor e nada
comprado, o relógio segura as 18h, Walt liga (`call_tutorial_upgrade`, texto "Gear Stand, in the back.") e os passos
`upg_go` → `upg_buy` levam ao Gear Stand para comprar Storage (`cooler`); falta de dinheiro é coberta. Acaba com
qualquer compra, ao sair do Day 1 ou após `Shift.TutorialHoldMax`. A janela de abertura do Gear Stand (abre no fim do
turno, fecha pouco depois do começo do próximo) é do Mart/Market, não deste tutorial; a lição cai dentro dela.

## 4. Co-op e solo

- **Solo:** o jogador faz tudo na ordem da tabela.
- **Co-op:** cada novato vê o próprio tutorial, mas os passos vêm do estado compartilhado: se um colega corta o pão, o
  prato fica com pão e o passo de todos pula para a salsicha; quem está com o prato na mão vê condimento/entrega; os
  outros veem `r_crew` (seta no `PICKUP`, sem fala). Um veterano no grupo não vê tutorial; o dia fica parado até o
  último novato terminar (regra atual). O telefone e as caixas também valem para quem fizer primeiro.
- Os prompts mostrados durante o tutorial: os do passo + os da cozinha inteira do restaurante (cortar, prato, grelha,
  pilha, condimento, lixo, retirada) a partir do tablet, para quem adiantar ou ajudar não ficar travado.

## 5. Se o jogador pular ou sair da ordem

- Não há botão de pular (decisão do dono 2026-10-14). Fazer fora de ordem nunca trava: o passo segue o estado (grelhar
  antes de cortar mostra o passo do prato certo; segurar a caixa antes de ligar pula a ligação).
- Jogar o hot dog no lixo devolve o fluxo ao corte (nenhum prato em andamento).
- Ficar parado: lembrete falado a cada 12 s; o Day 1 solta sozinho depois de `Shift.TutorialHoldMax` s.
- O turno acabar antes do fim: o tutorial termina (`over`), como hoje.
