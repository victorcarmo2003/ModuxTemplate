Status: Aprovado (DEC-315)

# Badges (emblemas do Roblox)

Pedido do dono em 2026-10-20: "monta uma lista de emblemas pro jogo, pelo menos uns 10". Lista e ícones aprovados
pela **DEC-315** (15 badges; os do ladrão e da ambulância saíram com DEC-313 e DEC-314). Regras da §1 e gatilhos seguem
**Provisórios**. Aberta: **Q-404** (quem é o Hunter).

Base: `Achievements.luau` (`content-data.md` §3.11), `RewardService` + `BadgesAwarded` (`tech/data.md`, `tech/architecture.md` §10.4).
Textos em inglês (texto de jogo); nomes já sugeridos em `story/ui-text.md` §9 foram mantidos.

## 1. Regras gerais (Provisório)

- Badge é **1× por conta**, dado pelo `RewardService` com retry (`BadgeService:AwardBadge` até `UserHasBadgeAsync`).
- **Gema só no `day_100`** (+300, DEC-084). Os outros badges não dão gema: a economia (`economy.md`) não muda.
- `Hidden = true`: o nome aparece como "???" na lista do jogo até desbloquear. No Roblox o badge fica visível na página
  do jogo de qualquer jogo; descrição dos secretos é vaga de propósito para não dar spoiler.
- Cada jogador da party ganha o seu (badge de noite/run vale para todos os vivos da party no fim da noite).
- Anti-AFK: badges de noite e run exigem que o jogador tenha **≥ 3 pedidos completos** no turno (mesma regra da DEC-083).
- Contadores (`Stats`) ficam no perfil; badge de contador dispara quando o valor chega ao alvo.

## 2. Lista

Ordem = ordem em que o jogador costuma ganhar.

| # | Key | Nome | Descrição (no Roblox) | Condição | Secreto | Gatilho |
|---|---|---|---|---|---|---|
| 1 | `welcome` | **Welcome to the Corner** | "Join the crew for the first time." | entrar no jogo | não | `Loaded` do perfil |
| 2 | `tutorial_done` | **Clocked In** | "Finish your first training shift." | concluir as 3 tarefas do tutorial (DEC-311) | não | último `hint_<passo>` do tutorial |
| 3 | `first_hotdog` | **First Dog Served** | "Hand a customer their very first hot dog." | 1º pedido **completo** entregue | não | `Stats.OrdersCompleted` = 1 |
| 4 | `golden_flip` | **Golden Flip** | "Nail a Perfect on the grill." | 1ª nota Perfect na grelha (DEC-305) | não | evento de nota `Perfect` em `Grade` |
| 5 | `first_night` | **First Night Shift** | "Survive your first night." | vencer N1 | não | `N1:night` |
| 6 | `not_today` | **Not Today** | "Turn away a customer who wasn't quite right." | recusar 1 cliente anômalo (família A) corretamente | não | recusa certa em `AnomalyService` |
| 7 | `lights_back` | **Lights Back On** | "Get the power back before it finds you." | religar o disjuntor no apagão (ANM-020) antes dos 30 s | não | apagão resolvido |
| 8 | `held_breath` | **Held My Breath** | "Hide in time when something comes knocking." | estar no ponto seguro quando o Walker (ANM-007) passa | não | `Hide` concluído sem desmaio |
| 9 | `eyes_down` | **Eyes Down** | "Don't look up." | passar pela Sombra no teto (ANM-019) sem olhar para cima | sim | ANM-019 terminou sem penalidade de olhar |
| 10 | `met_hunter` | **Met the Hunter** | "Some things wait for you outside." | ficar **tempo demais fora do restaurante** à noite e encontrar o Hunter (Q-404) | sim | evento do Hunter |
| 11 | `halfway` | **Halfway to Dawn** | "Survive five nights." | vencer N5 | não | `N5:night` |
| 12 | `hot_dog_hundred` | **Hot Dog Hundred** | "Serve 100 complete orders. Any run counts." | 100 pedidos completos somados entre sessões | não | `Stats.OrdersCompleted` = 100 |
| 13 | `kept_light` | **Kept the Light On** | "Survive all ten nights." | vencer N10 (final) | não | `finale` |
| 14 | `not_a_scratch` | **Not a Scratch** | "Survive all ten nights without fainting once." | vencer a run sem nenhum desmaio do próprio jogador | sim | `finale` + `Stats.RunFaints` = 0 |
| 15 | `day_100` | **Never Clocked Out** | "Work 100 days on the corner. Any run counts." | 100 dias de modo infinito (DEC-084) | sim | `EndlessDays` = 100 (já desenhado) |

## 3. Notas por badge

- **`met_hunter`**: o Hunter **não existe** nos docs nem no código ainda. Leitura do pedido do dono: entidade que aparece
  quando o jogador fica fora do restaurante por muito tempo durante a noite. Proposta (Provisório, Q-404): depois de
  **45 s fora** à noite, passos e respiração atrás do jogador; aos **60 s** o Hunter aparece no fim da rua e vem; quem
  volta para dentro antes sobrevive e **ganha o badge por ter visto**; quem não volta desmaia (e ainda ganha o badge).
  Pune o "passeio" sem regra nova para o jogador decorar. Desenho final: game-designer + narrative-writer.
- **`eyes_down`**, **`not_a_scratch`**, **`met_hunter`**, **`day_100`**: secretos, para premiar quem explora.
- **`not_today`** só conta recusa **certa**; recusar cliente normal não dá.
- **`welcome`** é barato e aumenta a contagem de "badges ganhos" na página do jogo; opcional.
- Badge do lore do Walt (achar todos os easter eggs, DEC-312) fica para quando a lista de easter eggs estiver fechada.

## 4. Custo e upload (Creator Hub)

- Cada badge precisa de **imagem quadrada 512×512** (o Roblox recorta em círculo; nada importante nos cantos).
- Criar badge tem cota grátis diária por experiência; acima dela custa Robux. Conferir no Creator Hub na hora do upload
  (a regra muda de tempos em tempos). Com 15 badges, subir em lotes ao longo de alguns dias.
- **Ícones prontos (aprovados, DEC-315):** `Assets/ui/badges/<nn>_<key>.png` (512×512, fundo transparente, medalha redonda;
  a numeração segue a §2). Fonte: `Assets/ui/badges/source/make_badges.py` (SVG gerado + render no Chrome headless);
  prancha de revisão em `source/board.png`. Tema por grupo: dia (amarelo/Ketchup), noite (azul/Teal), secreto de terror
  (vinho/vermelho), marco (creme/Teal), amanhecer (laranja-lilás/Mustard).
- O `BadgeId` de cada um vai em `Achievements.luau`. Sem id, o `RewardService` só marca `Achievements` e não chama o
  `BadgeService`.

## 5. No Roblox e no código (2026-10-20)

Criados no Creator Hub (IDs em `Content/Achievements.luau`): 1 `welcome` 2319638173193014 · 2 `tutorial_done`
1723416246988299 · 3 `first_hotdog` 2233023475659459 · 4 `golden_flip` 2104755363239074 · 5 `first_night`
579574344858433 · 6 `not_today` 664777349866945. Faltam 7–15 (5 grátis por dia; a cota zera às 21h de Brasília).

Gatilhos ligados (`RewardService:Unlock`, 1× por conta, sem gema): `welcome` (perfil carregou), `tutorial_done`
(`TutorialService:Complete` com "done"; pular não conta), `first_hotdog` (`CustomerService.Acted` serve Perfect/Complete),
`golden_flip` (`KitchenService.Emitted` "grill_flip" com nota Perfect), `not_today` (recusa de cliente com `Variant`),
`first_night` / `halfway` / `kept_light` (`NightResolved` "Won" na N1 / N5 / última). Sem gatilho ainda: `lights_back`,
`held_breath`, `eyes_down`, `met_hunter`, `hot_dog_hundred`, `not_a_scratch`. Badge sem ID fica só marcado no perfil e é
dado no próximo login, quando o ID entrar.

## 6. Implementação (pendente)

- `Content/Achievements.luau`: uma entrada por linha da §2 (`Key`, `Name`, `Hidden`, `Counter`/evento, `Target`, `Gems`, `BadgeId`).
- `RewardService`: além do `Counter`, aceitar **gatilho por evento** (`Reward:Award(player, key)`) chamado pelos services
  (Anomaly, Round, Kitchen, Revive).
- `Stats` ganha `OrdersCompleted` (persistido) e `RunFaints` (da run).
- TASK-605.
