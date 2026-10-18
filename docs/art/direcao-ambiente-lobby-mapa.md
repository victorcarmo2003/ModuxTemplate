Status: Aprovado nos itens L1–L6 e M1–M5 (DEC-289, 2026-10-18); números citados seguem Provisórios. Tarefas: TASK-448 a TASK-460.

# Direção de ambiente — Lobby e MAP-01 à noite

Autor: art-director (sessão das thumbnails, 2026-10-18). Pedido do usuário: "o lobby tem muito neon mas parece morto;
talvez excesso de informação, talvez faltem personagens atrás da lojinha com animação em loop; e ampliar o terror dentro
do mapa". Aplica ao cenário a mesma leitura que fez as thumbnails v2 funcionarem (`docs/marketing/`, skill
`roblox-thumbnail`). Nada aqui foi aplicado no place: os mockups foram feitos em cima do mapa e revertidos.

Mockups (antes × depois): `docs/art/mockups/ambiente-2026-10-18/comparativo.jpg` e os JPG soltos da mesma pasta.

---

## 1. Diagnóstico — por que o lobby parece morto

É o mesmo defeito da 1ª leva de thumbnails, agora em 3D:

| Sintoma | O que medimos / vimos | Efeito |
|---|---|---|
| **Tudo é quente** | preset `Lobby` (âmbar + ambiente ameixa), chão laranja, letreiros amarelos | sem contraste quente × frio, o olho não sabe onde parar |
| **Neon por toda parte** | ~1.180 peças Neon no `LOBBY_Assets` (862 só no `LobbyProcedural`), 31 no chão (setas, anéis), 41 janelas acesas | quando tudo brilha, nada brilha; é "excesso de informação" |
| **A coisa mais clara da tela é o chão** | anel do spawn, setas e o medalhão de pedra (textura clara e saturada) são mais claros que os personagens e letreiros | o ponto focal vira o piso, não a loja nem a equipe |
| **Nenhum bolsão escuro** | luz espalhada por igual (praça, mastro, postes, janelas) | sem escuro não existe "luz que acolhe", nem lugar para algo se esconder |
| **Ninguém trabalhando** | carrinho do HQ, Gem Shop e food court vazios quando o servidor tem poucos jogadores | parece cenário de catálogo, não um negócio funcionando |
| **Zero sinal de terror** | o lobby é 100 % "lanchonete fofa" | o jogador não sente o gênero antes de entrar; a thumb promete um monstro e o lobby não confirma |

MAP-01 à noite (`Night1`): o pátio é iluminado por igual (4 lâmpadas de mesa + portão + tochas), o escuro em volta é
um vazio preto sem formas. Confortável e seguro, mas não dá medo: não há borda entre a luz e o escuro onde algo possa
aparecer.

## 2. Princípios (os mesmos das thumbnails)

1. **Um foco por vista.** De cada ponto de chegada (spawn, saída da van, porta da loja) existe UM lugar mais claro e
   quente, e ele é onde queremos o jogador: HQ, Gem Shop, START.
2. **Mundo frio, foco quente.** Céu, prédios e chão em azul-ameixa escuro; luz âmbar só nos pontos de interesse e nos
   personagens. Neon é acento, não papel de parede.
3. **Bolsões de escuro de propósito.** O escuro é o que faz a luz parecer acolhedora (lobby) e o que dá medo (mapa).
4. **Vida = personagens fazendo coisas.** Equipe cozinhando, vendedor atrás do balcão, cliente comendo, em loop.
5. **Um detalhe errado.** O terror do gênero (Animal Hospital, Sell Fries) é um detalhe estranho num lugar fofo, não
   escuridão total: dois olhos numa janela, uma figura parada do outro lado da rua.
6. **O olho branco é o ponto mais claro.** Num canto escuro, dois olhos brancos leem a 30 studs e em qualquer celular.

## 3. Lobby — o que fazer (por prioridade)

### L1. Luz: mundo frio, foco quente (só dados, `Content.LightPresets.Lobby`)
Mockup usou: `OutdoorAmbient (46,56,96)`, `Ambient (42,44,64)`, `ColorShiftTop (110,130,190)`, `ColorShiftBottom
(14,14,28)`, `AtmColor (34,40,66)`, `AtmDecay (44,40,72)`, `AtmHaze 1.4`, `Contrast 0.18`, `Saturation 0.1`, `Tint
(240,242,255)`, `Exposure −0.35`, `Brightness 0.5`. Os prédios viram silhuetas azuis e os letreiros quentes passam a
saltar. Ajuste fino no Play.

### L2. Tirar neon do chão
Setas, contornos de zona e o anel do spawn: trocar Neon por cor sólida (SmoothPlastic) ou por um Decal; o brilho fica
só quando o jogador entra na zona (o `LightController` já acende/apaga por zona). Escurecer a textura do medalhão de
pedra e dos ladrilhos (`AST-032_SidewalkTile`, cor × ~0,6) e baixar as luzes `WarmLobby_Plaza`/`WarmLobby_Spawn` para
~40 %. Resultado: o chão deixa de ser o ponto mais claro.

### L3. Bolsões escuros nos prédios
Das 41 janelas acesas, deixar ~1 em 3 e apagar as luzes dos prédios do fundo. Mockup: apagar 2 de 3 já cria ritmo
(janela acesa / escura) e profundidade.

### L4. Luz-chave só nos 3 focos
Um SpotLight quente sobre o carrinho do HQ, um PointLight dentro da Gem Shop, um sobre o food court. Mockup: HQ spot
(4, alcance 26, ângulo 50), loja point (2,2, 14), food court point (1,6, 14).

### L5. Vida: NPCs de cenário em loop (responde "faltam personagens atrás da lojinha")
- **HQ:** 2 da equipe atrás do carrinho (urso virando salsicha, coelho servindo), animação curta em loop.
- **Gem Shop:** vendedor atrás do balcão (acenando / limpando o balcão), sempre lá.
- **Food court:** 2–3 clientes nas mesas (comendo, rindo), um na janela do trailer.
- **Rua:** um carro passando de vez em quando, a van do START com motorista.
- Técnica: rigs do `CrewRig` ancorados, só no client, sem rede e sem colisão; uma animação por NPC; desligar a mais de
  ~120 studs. É uma TASK de frontend + uma de arte (lista de poses/animações).

### L6. O "detalhe errado" no lobby (teaser do gênero)
- **Olhos numa janela escura** de um prédio do fundo, visíveis do spawn (mockup: dois Neon brancos Ø 0,9). Opcional:
  piscar de vez em quando, sumir quando o jogador olha muito tempo.
- **The Walker do outro lado da rua**, parado entre os carros, olhando a praça, com contorno frio atrás. Aparece de
  tempos em tempos e some quando alguém chega perto. Mockup confirma que lê bem da altura do jogador.
- Tudo Mild (sem susto, sem som alto). Reforça o que a thumbnail promete (o ranking de 2026 pune clique que quica).

## 4. MAP-01 — ampliar o terror

### M1. Metade do pátio no escuro
Apagar 2 das 4 lâmpadas de mesa (`LIT-T2`, `LIT-T4`) e as tochas desse lado. O balcão continua quente e seguro; a
borda luz/escuro vira o lugar onde as anomalias aparecem.

### M2. O escuro com forma
Luar frio (`ColorShiftTop` azul, `OutdoorAmbient (40,50,86)`) para os prédios aparecerem como silhuetas, e
`AtmDensity` ~0,44 com `Haze 1.6` para a rua sumir na névoa. O vazio preto atual não assusta; uma forma que quase dá
para ver assusta.

### M3. Postes que falham
Um poste apagado no canto do pátio (mockup: o de (−58, 13, 46)) e outro piscando (efeito no client). Os postes
viram "relógio" da noite: quanto mais tarde, mais postes falham.

### M4. Silhuetas na borda da luz
Os monstros físicos (Walker, Sorriso, Rastejador) devem aparecer primeiro como **dois olhos brancos no escuro** além
da cerca do pátio ou no drive-thru, antes de se aproximarem. Mockup: Walker no lado escuro do pátio, só os olhos
visíveis. Isso combina com o `Atmospheres`/`AnomalyController` que já existem: é posição e luz, não mecânica nova.

### M5. Som e ritmo (para o designer de áudio)
Zumbido de neon, lâmpada estalando, um cachorro latindo longe, passos que param. Silêncio antes da aparição.

## 5. Próximos passos sugeridos

1. Usuário escolhe o que entra (L1–L6, M1–M5).
2. `task-planner` quebra em TASKs: preset de luz (dados), neon do chão e janelas (level-designer, no place), NPCs de
   cenário (frontend + arte), teaser do lobby (frontend), postes que falham (frontend), ajustes do pátio (level-designer).
3. Testar no Play em celular: legibilidade dos botões e placas com o mundo mais escuro (mínimo de leitura do style
   guide: luminância ≥ #1B2140).

## 6. Perguntas para o usuário (lote)

- Q: o teaser de terror no lobby (olhos na janela, Walker na rua) pode existir, ou o lobby deve ficar 100 % seguro?
  Recomendação: pode, discreto e Mild.
- Q: NPCs de cenário no lobby sempre ligados, ou só quando o servidor tem poucos jogadores? Recomendação: sempre
  (dão escala e mostram o "trabalho").
- Q: neon do chão só acende ao entrar na zona? Recomendação: sim.

## 7. Ficha dos NPCs de cenário do lobby (TASK-451)

Dados em `Content.Lobby.Extras` (`src/Shared/Content/Lobby.luau`), lidos pela TASK-452. Posições do mockup; a do motorista
é estimada e será medida no Studio.

| Key | Quem | Onde | Ação em loop | Na mão |
|---|---|---|---|---|
| `hq_grill` | urso, equipe, Happy | atrás do carrinho do HQ, esquerda | Grill (vira salsicha) | hot dog |
| `hq_serve` | coelho, equipe, Smile | atrás do carrinho do HQ, direita | Serve (estende o hot dog) | — |
| `shop_keeper` | gato, equipe, Happy | atrás do balcão da Gem Shop | Wave (acena para quem está na zona) | — |
| `food_pig` | porco, civil_b, Happy | mesa do food court | Eat (morde o hot dog) | hot dog |
| `food_dog` | cachorro, civil_e, Smile | mesa do food court | Chat (vira para o vizinho e ri) | — |
| `van_driver` | raposa, equipe | banco do motorista da van do START | Drive (olha em volta) | — |

Visíveis até 120 studs da câmera; sem colisão e sem rede.
