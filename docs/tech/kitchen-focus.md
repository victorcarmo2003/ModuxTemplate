Status: Rascunho (2026-10-19). Pedido do dono na conversa de 2026-10-19 (a registrar como DEC pelo secretário). Números Provisórios.

# Cozinha em foco por estação

Volta o diferencial do preparo focado (DEC-223), **enxuto e por estação**, sobre a cozinha de mundo (`kitchen-world.md`). O
prompt da estação só **entra no foco**; dentro do foco a câmera sai do personagem e olha a estação de cima, e o jogador faz os
gestos nos objetos 3D (mouse, toque, controle). Respostas do dono (2026-10-19):

| Pergunta | Resposta |
|---|---|
| Base | enxuto, por estação; do código antigo só as peças puras (gestos, ponteiro, traço do molho, câmera Prep) |
| Salsicha → prato | arrastar a salsicha pronta da grelha direto ao prato (o descanso deixa de ser passo) |
| Nota | **precisão conta**: corte, salsicha no pão, virar e cada condimento dão nota por gesto |
| Sair do foco | os dois: botão Voltar (B / Backspace) ou andar, **e** sai sozinho ao terminar o passo |

> **DEC-310 (2026-10-19) vale sobre §1, §4 e §5:** tábua e grelha são **pré-preparo** (sem prato). O corte vai para a
> pilha de pães cortados (`TLR_BUN_CUT`, cesta da direita) e a salsicha pronta, com um toque, vai para o descanso
> (`TRL-SAUSAGE_RAIL`). Montar é pegar o que está pronto: **Add Bun** na cesta de cortados e **Add Sausage** no descanso
> (prompts de mundo; levam a nota do corte e a do virar para o prato), depois os condimentos em foco com o prato **pousado
> na laje da mesa** (raycast). Pacote `Cook`: `Dog` vira `Collect`. Câmera: encaixa a caixa da estação na tela (grelha +
> descanso; tábua + as duas cestas), olhando de frente para a bancada e abaixo do teto.

## 1. Fluxo (ordem fixa: prato → pão → salsicha → condimentos)

| # | Onde | Prompt | No foco | Servidor |
|---|---|---|---|---|
| 1 | Pilha de pratos | **Take Plate** (sem foco) | — | Tool `plate` com o ticket mais antigo |
| 2 | Tábua `TLR-CUTTING_BOARD` | **Cut Bun** (`cook_focus`) | pão inteiro no prato; **arrastar da esquerda para a direita** na linha (toque/mouse); controle: segurar R2 e empurrar o analógico para a direita | `Cut`: 1 pão do estoque, `Bun` no prato, nota do corte |
| 3 | Grelha `TLR-GRILLS` | **Grill** (`cook_focus`) | tocar numa vaga vazia põe salsicha; tocar na salsicha cozinhando vira; **arrastar a pronta até o prato** (aparece ao lado da grelha) | `Place` / `Flip` / `Dog`; salsicha só com pão no prato (`plate_needs_bun`) |
| 4 | Mesa de condimentos `PRODUCTION` | **Toppings** (`cook_focus`) | tocar na panela escolhe; molho = **desenhar** no pão; queijo, bacon, batata = **arrastar** até o pão | `Topping`: estoque, sem repetir, máx. 3, molho desenhado fica no pão (`Sauce`) |
| 5 | `PICKUP` | **Hand Over** (sem foco) | — | venda; nota (§3) |

O prato com pão e salsicha vira o Tool `hot_dog` e **o prato continua debaixo** (peça `Dish` soldada).

## 2. Foco (cliente, `src/Cook/client`)

- Entrada: o servidor aceita `cook_focus` (prompt da estação) e manda `CookOpen` ao jogador com a estação; a câmera usa o modo
  `Prep` do `CameraController` (já existe). Pose = acima e à frente da estação, olhando o centro do modelo, do lado de onde o
  jogador está (calculada da caixa do modelo; `CamAnchor_Cook`/`Focus_Cook` no modelo vencem se existirem).
- Saída: botão Voltar, B, Backspace/Q, mover o personagem, ou sozinho ~0,8 s depois do passo terminar (pão cortado, salsicha
  no prato). Na grelha o passo só termina com a salsicha no prato; nos condimentos, com todos os do pedido.
- Ponteiro único (mouse, primeiro toque, cursor virtual do controle no analógico esquerdo + R2/A como clique).
- Gestos puros do código antigo: `slice`, `place`, `trace` (`Geometry`), nota pela mesma `Grade.Score` em servidor e cliente.

## 3. Nota

Cada gesto dá 0..100 (`Grade.Score` com `Content.Prep.Tolerances`): `bun_cut`, `sausage_place`, `grill_flip` (dentro da janela
100, fora 40, não virou 0), um por condimento. O prato guarda as notas no atributo `Scores` (`cut=92,dog=80,...`).
`Grade.Assembly`: condimentos diferentes do pedido = Messy; senão a média das notas dá a banda (Perfect ≥ 85, Good ≥ 55) e o
Perfect ainda pede o tempo (`PerfectTime`). O servidor só limita (0..100, um corte por prato); confiar na nota do cliente é
Provisório (como o preparo antigo).

## 4. Rede (`Net.Restaurant`)

- `Cook` c → s: `Act` (Cut, Place, Flip, Dog, Topping), `Slot` 0..8, `Score` 0..100, `Key` (topping, opcional), `Points`
  (molho, até 24 ints, `HotDogVisual.Sauce`). Responder: `KitchenService` (`Cook.luau`).
- `CookOpen` s → jogador: `Station` (Board, Grill, Toppings) e o modelo (`Target`, Instance).

## 5. Prompts de mundo

Somem `grill_place`, `grill_flip`, `grill_collect`, `bun_cut`, `plate_add_bun`, `plate_add_sausage`, `topping_add` (o foco faz
tudo). Ficam `cook_focus`, `plate_take`, `restock`, `topping_unwrap`, `discard`, `pickup_serve`.

## 6. Mapa

Nada obrigatório no Studio: o servidor acha as estações e cria um `Prompt_Cook` (PromptAction `cook_focus`, atributo `Cook`)
sobre o meio de cada uma — grelha = a estação `grill`; condimentos = a pasta que guarda as estações `toppings` (`PRODUCTION`);
tábua = Model com `CookStation = "Board"`, senão o de nome `Restaurant.Binding.CookBoard` (`TLR-CUTTING_BOARD`). Um
`Prompt_Cook` autorado dentro da estação vence; `CamAnchor_Cook` / `Focus_Cook` (Attachments) fixam a câmera.
As vagas da grelha ficam sobre as barras do nível 1 (`restaurant_bind` modo `kitchen_world`; aplicado no Studio em 2026-10-19).

## 7. Código

| Lado | Onde |
|---|---|
| servidor | `Kitchen/server/KitchenService/Cook.luau` (prompts, pacote `Cook`, gestos), `Stations/Grill.luau` (`PlaceAt`, `FlipAt`, `TakeReady`, nota do virar) |
| cliente | `Cook/client/CookController/` (`init` foco/câmera/saída, `Board`, `Grill`, `Toppings`, `Pointer`, `Gestures`, `Kit`, `Hud`) |
| nota | `Prep/shared/Grade.luau` (`Score`, `Mean`, `Assembly`), `Content.Prep` (`Tolerances`, `Build`), atributo `Scores` (`Plate/shared/PlateTool`) |
| tutorial | `r_take_plate` → `r_cut` → `r_grill`/`r_cooking`/`r_flip`/`r_dog_plate` → `r_toppings` → `r_pickup`; a seta aponta o `Prompt_Cook`, dentro do foco o HUD guia |
| dev | `/dev smoke restaurant` faz o fluxo pelo mesmo caminho do pacote (`KitchenService.Cook.Act`) |
