Status: Rascunho

# Referência: Animal Hospital (Anomaly), Roblox

Pesquisa feita em 2026-10-08. O jogo recebe atualização toda semana, então os números e detalhes podem mudar.
Uso: só **estrutura** (câmera, UX mobile, loop, ritmo do terror). Nada de nomes, falas, personagens ou assets dele.

## Pergunta

Que jogo é o "Animal Hospital" citado pelo usuário? Como ele resolve a interação em primeira pessoa, o HUD, o lobby/party e o terror por anomalias? O que disso serve para o Sell Hotdogs?

## Resposta curta

- O jogo é **Animal Hospital (Anomaly)**, do grupo **Animal Anomaly**. Lançado em 2026-05-10. Tem cerca de 2,4 bi de visitas e chegou a ~1,27 mi de jogadores simultâneos (10/jul/2026). Servidores de 30 jogadores, party de até 5 (antes era 4). É um jogo de co-op de terror leve: um turno da noite numa clínica veterinária. A pessoa recebe pacientes, trata e **barra anomalias disfarçadas** na recepção. O medidor central é a **Sanidade**.
- Tem certeza razoável de que é o jogo certo: ele bate com os três pontos (primeira pessoa, mobile, anomalias no turno da noite). O único possível engano é uma recriação para navegador ("Night Shift (Animal Hospital)", kbhgames), que é fan-made e não é o jogo do Roblox.
- **Observação:** o terror dele não segue o formato "lista de regras para sobreviver". É **inspeção e triagem** (comparar aparência, foto, CCTV e papelada) somada a eventos com timer. As "regras" que existem são implícitas, tipo "sem consulta marcada = suspeito".

## Detalhes

### 1. Identidade e loop
| Item | Dado | Fonte |
|---|---|---|
| Nome / criador | Animal Anomaly (grupo) | página Roblox, Rolimons |
| Place ID | 78515283254292 (no op.gg aparece 10148749921, provavelmente é o universe ID; **não confirmado**) | Rolimons, op.gg |
| Lançamento | 2026-05-10 | op.gg, GosuGamers |
| Visitas / favoritos | ~2,40 bi / ~3,13 mi | Rolimons, op.gg (out/2026) |
| Pico de jogadores simultâneos | 1.273.105 (10/jul/2026). Hoje fica em ~34 mil | Rolimons |
| Aprovação | ~94% | op.gg |
| Plataformas | PC, mobile, console (controle chegou em jun/2026) | wiki fan, animalhospital.blog |

**Loop de um turno:** recepção (check-in ou recusa com a "persiana") → tratamento em salas com itens certos (básico, raio-X, monitor cardíaco, cirurgia com timer) → emergências com timer (incêndio, desmaio, "ritual") → manter a Sanidade com café grátis a cada 180 s ou comida → fim do turno com nota.
**Entre turnos:** dinheiro do turno vai para a loja de suprimentos (taser, scanner, café). Uma moeda permanente compra classes com perks. Algumas classes são só com Robux.
**Falha:** Sanidade em 0, ou 3 mortes de pacientes, encerra a run. Começar um jogo novo volta ao dia 1. "Total de turnos" aparece acima do avatar no lobby, como status social.
**Escalada:** mecânicas são liberadas por turno (persiana e CCTV no turno 2, taser no 4, eventos de chuva no 3, ambulância a cada 5 turnos, "slime" no 10). As fontes não concordam sobre o turno exato de cada uma.
**Terror:** a anomalia que entra vira uma ameaça que caça pelos corredores. Cada inimigo tem **um** contra-ataque específico. Olhar demais uma imagem amaldiçoada no CCTV drena Sanidade e pode matar.

### 2. Interação
- **Câmera:** primeira pessoa. A zoom para terceira pessoa (scroll ou pinça) só **foi adicionada em ago/2026**, o que sugere que antes a primeira pessoa era travada. **Não confirmei** se hoje ela é o padrão ou continua forçada.
- **Itens:** inventário com 4 slots (teclas 1–4 no PC, LB/RB no console, ícone de mochila no mobile, canto superior direito). Clique esquerdo/RT usa o item na mão. Q pega ou solta. Isso combina com Tools nativas no Backpack, mas **não confirmei se é a hotbar nativa ou uma UI própria**: a mochila abre com Tab e fica num ícone, e isso indica UI customizada.
- **Interagir:** tecla E, ou "segurar E" (apagar fogo, limpar slime, segurar inimigo). E é a tecla padrão do ProximityPrompt e "segurar" corresponde ao `HoldDuration`. Mesmo assim, **não confirmei** que é ProximityPrompt. No mobile o guia descreve um **botão de interagir fixo embaixo no centro**, e não o toque no prompt flutuante. Isso aponta para um prompt com `Style = Custom` ou para um botão próprio.
- **Mobile:** joystick à esquerda, arrastar à direita para a câmera, botão de interagir embaixo no centro, ícone de mochila, ícone de CCTV, toque duplo no joystick para correr. Tamanho em px e alcance em studs **não foram encontrados** em nenhuma fonte.
- **Ações modais** (CCTV, foto, carimbo na recepção) têm botão ou tecla dedicados (C, clique direito, Espaço, R para o scanner). As tarefas complexas viram modos de tela, não menus.

### 3. HUD
- **Sanidade** em percentual. O valor inicial varia com a classe (ex.: 61% na classe inicial).
- **Eventos/emergências numa lista do lado direito com timer** (ex.: desmaio 60 s, crítico 120 s). O timer do paciente crítico aparece através das paredes.
- Dinheiro e moeda permanente (onde aparecem na tela: **não confirmado**).
- Relógio do turno: **nenhuma fonte descreve**. O turno "vai até o amanhecer".
- **Fim de turno:** tela de resultado com nota (Excelente, Bom, Ruim, Crítico) calculada com tratados, check-ins, anomalias recusadas e mortes. Ela mostra o contador de anomalias e paga as duas moedas. Antes do turno há um briefing de NPC que pode ser pulado segurando E.

### 4. Lobby e party
- Servidor de 30 jogadores com um **lobby compartilhado**. Lá se forma a party, que hoje tem **até 5** (subiu de 4 na atualização de 2026-10-03). No fim do turno todos voltam ao lobby e podem repetir com a mesma party ou formar outra.
- Lobby também tem loja de classes e, desde 2026-10-03, um "modo roleplay".
- **Servidor privado:** nenhuma fonte confirma preço ou regras. Modo solo dedicado também **não foi confirmado**.

## Lições para o Sell Hotdogs

Aplicáveis (estrutura, não conteúdo):
1. **Interação com uma única ação primária.** Uma tecla ou botão grande e fixo no mobile para "interagir", e "segurar" para ações de esforço. No nosso caso, cada estação do carrinho (grelha, pão, molho, entrega) é um ProximityPrompt com `HoldDuration` curto. Docs oficiais: no mobile o jogador **sempre** pode tocar no prompt, e `RequiresLineOfSight` vem como true. Se o carrinho for apertado, use `Exclusivity = OnePerButton` para não empilhar prompts (create.roblox.com/docs/ui/proximity-prompts, consultado em 2026-10-08).
2. **Inventário pequeno** (até 4 itens). Funciona em tela de celular e com crianças. Ingredientes na mão podem ser Tools. Avaliar a hotbar nativa contra uma mochila própria (ver Q a abrir).
3. **HUD só de status:** um medidor principal (para nós, algo como "calma" ou "coragem", com nome original) e uma **lista de pedidos/eventos com timer** num canto. Nada de menu durante o turno.
4. **Terror por triagem, não por susto.** O cliente-anomalia disfarçado que precisa ser **recusado no balcão** cabe direto num carrinho fixo: o "balcão" é o nosso ponto de decisão. Sinais em camadas (visual, pedido estranho, horário). Cada ameaça tem **um** contra-ataque simples, o que é legível para o público infantojuvenil.
5. **Liberar mecânicas por noite** (noite 2 libera X, noite 4 libera Y). Funciona como tutorial embutido e cria retenção.
6. **Tela de fim de noite com nota em 4 faixas** e um contador de "anomalias recusadas". Recompensa clara e motivo para repetir.
7. **Lobby compartilhado com party pequena (4–5) e instância por party.** Contador de noites visível acima do avatar como status social.
8. **Recurso de alívio grátis com cooldown** (o equivalente ao café de 180 s). Evita frustração sem precisar de loja.

Armadilhas a evitar:
- **Primeira pessoa travada no mobile:** o próprio jogo cedeu e adicionou terceira pessoa 3 meses depois. Proposta: primeira pessoa como padrão, com opção de zoom.
- **Sustos fatais por olhar** (imagem que mata se você continuar olhando) são pesados para crianças. Mantenha só no nível "drena o medidor".
- **Rituais ou temas de morte de pacientes:** use uma falha mais leve (cliente vai embora bravo, carrinho bagunçado).
- **Reset total da run** ao falhar pode frustrar. Considere checkpoint por noite.
- **Muitas teclas exclusivas** (C, R, Espaço, Q, Tab). Isso não escala para o mobile, porque cada uma vira um ícone.
- **Classes só com Robux que dão vantagem** podem gerar percepção de pay-to-win num co-op. Prefira cosmético.
- **Não copiar:** a ambientação de clínica veterinária, a persiana da recepção, a "Sanidade" como nome, nomes de NPCs/anomalias, classes, a estrutura de recepção-foto-CCTV-papelada como pacote fechado.

## Recomendação

Adotar o modelo "**um botão de interagir + prompts por estação + HUD de um medidor e uma lista de pedidos com timer + triagem de cliente-anomalia no balcão + desbloqueio por noite + nota no fim da noite**". Abrir em `docs/open-questions.md`:
- Câmera: primeira pessoa travada ou padrão com zoom?
- Itens na mão: hotbar nativa do Roblox ou mochila própria de 4 slots?
- Tamanho da party (4 ou 5) e se haverá modo solo.

Antes de fechar o design, vale um teste prático (jogar 1 turno no celular). Ele confirmaria os pontos que ficaram em aberto: se usa ProximityPrompt nativo, alcance, tamanho do botão e posição do HUD.

## Fontes

- Página do jogo: https://www.roblox.com/games/78515283254292
- Rolimons (estatísticas, 2026-10-08): https://www.rolimons.com/game/78515283254292
- op.gg Roblox: https://op.gg/roblox/games/10148749921
- GosuGamers (popularidade, party, lobby): https://www.gosugamers.net/entertainment/news/78741-animal-hospital-becomes-roblox-s-latest-horror-sensation-here-s-everything-you-need-to-know
- Controles PC/console/mobile (fan): https://animalhospital.blog/controls/
- Destructoid, walkthrough (2026-06-17): https://www.destructoid.com/animal-hospital-walkthrough-guide/
- Guia de turno, HUD e fim de turno (fan): https://newgame.co.jp/metaverse/en/roblox/78515283254292/animal-hospital/guide/
- Wiki fan (salas, classes, monetização): https://animal-hospital.wiki/
- The Spike (loop, party 4): https://www.thespike.gg/roblox/animal-hospital
- Log de updates (party 5, 2026-10-03): https://animal-hospital.fandom.com/wiki/Updates
- Evento oficial Halloween: https://www.roblox.com/events/6148078963681002030
- Roblox docs, ProximityPrompt (consultado em 2026-10-08): https://create.roblox.com/docs/ui/proximity-prompts e https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt
- Roblox docs, Tool: https://create.roblox.com/docs/reference/engine/classes/Tool

Quase todas as fontes de detalhe são wikis e guias de fãs, e às vezes divergem (tamanho da party, turno em que cada mecânica é liberada, papel do jogador). Os números de popularidade vêm de agregadores, não de dados oficiais.
