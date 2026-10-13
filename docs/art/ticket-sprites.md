Status: Em revisão (art-director, 2026-10-12; arte nova pedida pelo dono para o ticket vertical em camadas, Provisório)

# Sprites do ticket vertical em camadas (AST-109, 110, 111, 112)

Inspiração: ticket de pedido em faixas empilhadas de baixo para cima (pão, salsicha, molho com medalhão, topping). Arte 100% original, estilo toy: contorno Ink `#2B2233` 4 px, paleta Cream/Mustard/Teal, sem vermelho de alerta (ketchup é cor de comida, aplicada por `ImageColor3`), nenhum texto desenhado (rótulos em Fredoka por código).
Fontes: `Assets/ui/source/*.svg` geradas por `Assets/ui/source/build_ticket.py` (reproduz SVG e PNG; requer playwright). PNGs: `Assets/ui/ticket/`. Upload feito pelo Studio MCP (`upload_image`, conta do dono). Todos transparentes, com 2 px de folga. Moderação pode deixar a imagem em branco por alguns minutos.

Ordem de camadas sugerida (de baixo para cima, uma faixa por camada, alternando `band_cream` e `band_mustard`): `bun_base` > `sausage_*` > molho (`sauce_zigzag` tintado + `medallion` ao centro com o ícone do condimento por cima) > toppings > `bun_lid`.

| Nome | Ficha | Arquivo | Tamanho | rbxassetid | Tint | 9-slice (SliceCenter) |
|---|---|---|---|---|---|---|
| bun_base | AST-110 | `Assets/ui/ticket/bun_base.png` | 256x96 | `rbxassetid://123150128305850` | não (cor fixa) | não |
| bun_lid | AST-110 | `bun_lid.png` | 256x96 | `rbxassetid://104749590229546` | não | não |
| sausage_grilled | AST-109 | `sausage_grilled.png` | 256x64 | `rbxassetid://112402250741884` | não | não |
| sausage_raw | AST-109 | `sausage_raw.png` | 256x64 | `rbxassetid://122976884968683` | não | não |
| sauce_zigzag | AST-111 | `sauce_zigzag.png` | 256x64 | `rbxassetid://93105718703873` | **sim**, branco/cinza: ketchup `#E2402E`, mustard `#F6C12B`, cream cheese `#FFF8EC` | não |
| medallion | AST-111 | `medallion.png` | 128x128 (exibir ~48) | `rbxassetid://114660860458809` | não (miolo Cream vazio, anel Teal) | não |
| cheese_shred | AST-111 | `cheese_shred.png` | 256x64 | `rbxassetid://139927057417790` | não | não |
| bacon_strip | AST-111 | `bacon_strip.png` | 256x64 | `rbxassetid://122238322479758` | não | não |
| potato_sticks | AST-111 | `potato_sticks.png` | 256x64 | `rbxassetid://90795375171927` | não | não |
| ticket_paper | AST-112 | `ticket_paper.png` | 128x128 | `rbxassetid://71665440638107` | não (Cream) | `Rect.new(32, 32, 96, 96)` (min x,y e max x,y; cantos chanfrados de 20 px ficam dentro de 32; sombra de 5 px embaixo; `SliceScale` 0.5 dá contorno de 2 px) |
| ticket_pin | AST-112 | `ticket_pin.png` | 64x64 (exibir ~24-28) | `rbxassetid://84992795924518` | não (Teal) | não |
| ticket_band_cream | AST-112 | `ticket_band_cream.png` | 64x64 | `rbxassetid://102719563623924` | opcional | `Rect.new(16, 16, 48, 48)` (esticar na largura e altura; fio de 3 px no topo e na base) |
| ticket_band_mustard | AST-112 | `ticket_band_mustard.png` | 64x64 | `rbxassetid://112934820577899` | opcional | `Rect.new(16, 16, 48, 48)` |

Uso no `ImageLabel`: `BackgroundTransparency = 1`, `ScaleType = Slice` nos 9-slice, `ScaleType = Fit` nos demais. Cores das faixas: Cream `#FFF8EA`, Mustard claro `#FCE7A6`.

## Pendências

- Toppings reais hoje em `Content.Ingredients`: Ketchup, Mustard (molhos), Cheese, Bacon, Potato Sticks, Cream Cheese (cobertura em cordão, usa `sauce_zigzag` tintado). Cebola e picles do pedido do dono **não existem** em `Content`; sem sprite até virarem ingrediente (`Q-` a abrir se forem entrar).
- Ícones dos condimentos dentro do `medallion`: vêm do AST-071 (`Ingredient/*`), sem arte nova.
- Anel de paciência, carimbo e `stack_edge` do AST-112 ficam fora desta leva (o ticket vertical não os usa); pino e papel entregues.
- Aprovação do dono (status passa a Aprovado só por DEC). Verificação no Studio (capture com o componente real) depende do componente de ticket.
