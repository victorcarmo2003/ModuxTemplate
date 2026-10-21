Status: Rascunho (auditoria de leitura, 2026-10-20; correções da DEC-320 no §0)

# Auditoria do multiplayer — como está hoje e o que falta para o lançamento

Pedido do dono (2026-10-20): "não faço ideia de como está no momento. O game suporta até aonde? Verifica tudo do jogo
desde o início". Este documento é **leitura do código atual** (árvore de trabalho de 2026-10-20, com as mudanças sem commit
de outras sessões) mais uma checagem no Studio em modo Edit. Nenhum arquivo de gameplay foi alterado.

**Limite do teste:** o MCP do Studio só abre Play solo; **Test > Clients and Servers com 2–4 jogadores não pôde ser
rodado daqui**. Tudo que depende de dois clientes ao mesmo tempo está marcado como *a confirmar em playtest* e entra no
roteiro do §9 (TASK-610 proposta).

Legenda de severidade: **Alta** = quebra a experiência em grupo ou contradiz DEC; **Média** = estranho/injusto, mas o jogo
segue; **Baixa** = raro, só dev, ou cosmético.

---

## 0. Correções aplicadas (2026-10-20, DEC-320)

O dono aceitou as recomendações (DEC-320), tirou o revive grátis (Q-409 estacionada) e definiu **um Hunter por
jogador** (o perseguidor de fora continua pessoal, Q-414). Código alterado na árvore de trabalho, **sem commit e sem o
gate** (`modux generate/check` e `analyze.ps1` ficam com a sessão principal; o `ModuxTypes` precisa ser regerado porque
`RunStateService:Notify` ganhou um parâmetro).

| Item | Estado | Onde |
|---|---|---|
| B-01 clientes à noite por time | **corrigido**: teto 5/7/9/9, ritmo 1/1,8/2,5/3,1, balcão 1/1/2/2 | `CustomerService`, `Content.Flow.NightQueueByParty` |
| B-02 / B-12 quem comprou | **corrigido**: `Notice.By`; toast "Nome: Grill upgraded!" para os colegas | `Net`, `RunStateService:Notify`, `UpgradeService`, `SeatingService`, `HudController` |
| B-03 revive grátis | estacionado (DEC-320) | — |
| B-04 trava do tutorial | **corrigido**: 180 s por run de espera para quem já terminou, sem reinício por novato atrasado; toast `tutorial_wait` | `TutorialService:CountWait`, `Shift.TutorialWaitMax` |
| B-06 Hunter | como está (decisão: um por jogador, pessoal) | — |
| B-08 ANM-006 | **corrigido**: ataca quem mais olhou | `Anomalies/ANM-006.luau` |
| B-13 colisão do susto | **corrigido**: `AnomalyCue.User` | `AnomalyService`, `Api`, módulos 006/008/009/010/019/020/021 e `Kit/Hide`, `AnomalyController` |
| B-15 5º jogador | **corrigido**: toast `run_full` | `RunStateService:Admit` |
| B-16 anti-AFK | **corrigido**: por jogador (`RunParams.AntiAfkWork`); toast `afk_no_gems_you` | `RewardService` |
| Q-413 anomalias por time | **feito**: +1 com 3, +2 com 4 | `Nights.CrewEvents`, `AnomalyService:CrewEvents` |
| B-14 docs | **corrigido** | `overview.md`, `architecture.md` §1.1, `network.md` |
| B-05, B-07, B-09, B-10, B-11 | ficam para o roteiro de teste (TASK-610/611) | — |

## 1. Resposta curta: até onde o jogo suporta?

| Pergunta | Resposta | Onde |
|---|---|---|
| Jogadores por run (squad) | **4** (DEC-012). Vem de `#Content.RunParams.PartyPriceMult` | `PartyRules.Rules.MaxSize`, `RunStateService` `MAX_PARTY` |
| Jogadores por servidor de lobby | o `Players.MaxPlayers` da place: **60** no arquivo aberto no Studio (`PreferredPlayers` 60) | Studio, Edit |
| Servidor da run | **reservado** (`ReserveServer`), mesma place, papel `Game` lido do `TeleportData` do 1º jogador | `RoleService`, `Roles.ParseLaunch` |
| Plataformas de squad no lobby | **4** (`PartyRules.Rules.Platforms = 4`, 4 peças `PartyPlatform` no mapa) | `docs/overview.md` ainda diz 8 (desatualizado) |
| Quem entra na run | só o roster do lobby, sentado em ordem antes de qualquer admissão (DEC-205) | `PartyRunService` |
| Espera pela squad | até todos entrarem ou **60 s** depois do primeiro (DEC-098); atrasado nasce no trabalho | `PartyRunService:SquadIn` |
| Acima do limite (produção) | quem não está na squad é mandado de volta ao lobby em **3 s** com aviso `WrongServer` | `PartyRunService:OnPlayerAdded` |
| Acima do limite (Studio / servidor sem launch) | o 5º jogador **não vira membro**: sem personagem, recebe os pacotes do grupo, sem aviso | `RunStateService:Admit` (Baixa, B-15) |
| Saiu no meio | vira `Away`; a run vive com ≥ 1; volta pelo cartão de reconexão (DEC-063/067) | `SessionService` |
| Todos saíram | snapshot do início do turno no MemoryStore por **15 min** (DEC-080), retomada do começo do turno | `SessionService` |
| Preço por party | fixado no fim do 1º turno (DEC-121) com quem já entrou | `RunStateService:FixPriceParty` |

Studio: sem `Workspace.ServerRoleOverride` o Play roda o papel `Game` em **modo dev** (roster = os 4 primeiros que entram,
sem teleporte, sem MemoryStore). Teleporte, reconexão e retomada **não rodam no Studio**: só no jogo publicado.

---

## 2. Fluxo completo com 2 a 4 jogadores

1. **Lobby** (papel `Lobby`/`PrivateLobby`). Cada um tem perfil, gemas, classes, skins, códigos e configurações próprios
   (packets privados `Profile`, `SkinState`, `Settings`, `CodeRedeemResult`...). O set `Party` é visto por **todo o
   lobby** (cada cliente acha a sua squad pelo próprio UserId). Pisar numa plataforma cria/entra na squad;
   o líder configura `Access` (Setup → Open/Friends/Invite/Closed) e `MaxPlayers` 1..4; membros marcam Ready; o líder dá
   Start → contagem `Content.Lobby.Squad.Countdown` → `ReserveServer` + `TeleportAsync` de todos juntos (3 tentativas
   2/5/10 s). "Play Solo" = squad de 1 já em `Starting`. A tela de classes deixa os outros personagens invisíveis só no
   próprio cliente.
2. **Teleporte.** `TeleportData { Role = "Game", PartyId, Members, Leader }`. O servidor novo espera o 1º jogador
   (até 30 s) para saber o papel; todos os membros são sentados antes de qualquer perfil carregar.
3. **Início.** A intro saiu (DEC-309): a run nova entra direto na **Noite 1, ligação do chefe** (`Shift.RunStartsAtNight =
   true`, DEC-300). O portão de início espera a squad (ou 60 s). O carregamento de cada cliente manda `ClientReady`.
4. **Tutorial** (por jogador, em memória, nunca salvo): pendente para todo mundo na 1ª noite. O telefone é **um só**: quem
   atender inicia a ligação para todos; cada cliente marca a sua ligação como atendida e manda `TutorialBegin`. Há **um
   cliente de tutorial** compartilhado. Os passos são decididos **do estado replicado** ("quem fizer o passo, conta para
   todos"): se o colega fritou, o seu passo de fritar já passa; se o colega está com o prato, aparece `r_crew` ("leve ao
   balcão"). O relógio **para para todos** enquanto houver algum novato pendente (até 600 s de trava).
5. **Turno da noite.** Caixa (`Economy`), estoque, estações, upgrades, mesas, clientes, tablets, pratos e carros são sets
   compartilhados: todos veem o mesmo. Sanidade é **privada** (`Sanity` packet só ao dono); os colegas só veem a banda
   pela aparência (LookPack).
6. **Cozinha.** Grelha, tábua e condimentos em foco por jogador (câmera local, gestos validados no servidor dentro de
   trava por estação); pratos e montagem no mundo (`Plates` set); `SlotLock` de 1 s por vaga (DEC-259).
7. **Gear Stand.** Abre no fim de cada turno (Summary), fecha 45 s depois do início do turno seguinte (mínimo 120 s).
   Estado em atributos do Workspace (`GearStandOpen`, `GearStandClosesAt`), visto por todos. Qualquer jogador compra com o
   **caixa do time**.
8. **Fim do turno.** `ShiftReport` ao grupo; gemas por jogador presente (`RewardService:ForPresent`).
9. **Desmaio / derrota.** Queda individual (cartão da causa privado `FaintCause`, 15 s de revive, depois espectador até a
   próxima noite). Todos caídos = tela da vida do time: com vida, a noite recomeça; sem vida, "Revive all" 15 s
   (DEC-318). `LifeEvent` ao grupo.
10. **Fim da run.** `RunReport` por jogador; 12 s depois todos voltam a um lobby público (`LobbyReturn` a qualquer hora).

---

## 3. Tabela por sistema

"Quem vê" = **Eu** (só o próprio jogador), **Grupo** (todos do servidor), **Ninguém** (só o servidor).

| Sistema | Estado | Quem vê | Rede (Lync / atributos) | Entrada tardia / reconexão | Falhas e riscos |
|---|---|---|---|---|---|
| Papel do servidor | servidor, 1× no boot | Grupo | atributo `ReplicatedStorage.ServerRole` | lê ao entrar | cliente cai para "Game" se o atributo não chegar em X s (warn) |
| Squad no lobby | servidor (`PartyService`) | todo o lobby | set `Party`; packets `PartyCreate/Invite/Respond/Leave/Kick/Ready/Start/Configure/QuickPlay/Cancel`, `PartyNotice` (Eu) | set pronto ao entrar | 4 plataformas (doc diz 8, B-14) |
| Reconexão | MemoryStore | Eu | `Reconnect`, `ReconnectReply` | é o próprio mecanismo | **nunca testado** em servidor publicado com 2 contas (B-05) |
| Online | MemoryStore | lobby | set `Online` | — | — |
| Roster / vida | servidor (`RunStateService`, `VitalService`) | Grupo | sets `RunState`, `Vitals` (id = UserId); `LifeEvent` (Grupo) | sets prontos; volta com o estado salvo | — |
| Sanidade | servidor por UserId | **Eu** (número); Grupo vê só a banda no visual | `Sanity`, `SanityCue`, `FaintCause` (Eu) | reenviado em `OnJoined` | — |
| Turno / relógio | servidor (`RoundService`) | Grupo | set `Shift` | pronto | trava do tutorial vale para todos (B-04) |
| Ligação do chefe | servidor (`BossService`) | Grupo | set `Call` | pronto | um telefone: qualquer um atende por todos |
| Tutorial | **cliente** (passos) + servidor (trava, cliente do tutorial, novatos) | Eu (painel, seta, voz) | `TutorialBegin`, `TutorialComplete`, `TutorialLessonSkip`, `MetricTutorial` | quem entra na 1ª noite começa o tutorial do zero | novato que chega depois **reabre a trava** do relógio (B-04) |
| Caixa / gorjeta | servidor (`EconomyService`) | Grupo | set `Economy`; `CashCollected`, `Sale` (Grupo) | pronto | qualquer um gasta tudo (B-02) |
| Estoque / estações | servidor (`KitchenService`) | Grupo | sets `Stock`, `Stations` | pronto | — |
| Foco de cozinha | cliente (câmera, props) + servidor (gesto) | Eu | `Cook` (c→s), `CookOpen` (Eu); atributo local `CookStation` | — | sem exclusividade por estação: dois na mesma grelha não veem os props locais do outro (B-09, a confirmar) |
| Pratos | servidor (`PlateService`) | Grupo | set `Restaurant.Plates` | pronto | — |
| Clientes | servidor (`CustomerService`) | Grupo | set `Customers`; `CustomerComplain`, `CustomerNoticed` (Grupo) | pronto | escala por jogador incompleta à noite (B-01) |
| Tablets | servidor (`TabletService`) | Grupo | set `Restaurant.Tablets` (`User` = quem atende) | pronto | — |
| Drive-thru | servidor | Grupo | set `Restaurant.DriveCars` | pronto | `QueueByParty`/`ShareByParty` lidos por party (ok) |
| Mesas | servidor | Grupo | set `Tables` | pronto | — |
| Upgrades / Gear Stand | servidor | Grupo | set `Upgrades`; atributos `GearStandOpen/ClosesAt`; notices `gear_*`, `upgrade_bought` (Grupo) | pronto | aviso não diz **quem** comprou (B-12) |
| Janela / luz / portas | servidor (`VehicleService`, `LightService`) | Grupo | atributo `Shutter` no veículo; set `Lights` | pronto | interruptor e janela são do time: quem mexe decide por todos (B-07) |
| Câmeras de segurança | servidor congela o corpo | Eu | `SecurityOpen`, `SecurityLeave` | — | — |
| Tablet de anomalias (Journal) | perfil | Eu | `Journal`, `JournalOpen`, `JournalClaim` | reenviado | — |
| Anomalias (estado) | servidor (`AnomalyService`) | Grupo | set `Anomalies` (sem verbo, T10); `AnomalyCue` (Grupo) | set pronto; **cues perdidos** (B-10) | — |
| Olhar | cliente → servidor 10 Hz | Ninguém | `Gaze` (newest) | — | — |
| Sustos família D | cliente | Eu ou alguns | `HallucinationScare` | perde | por design |
| Suspense | servidor (custo) + cliente (visual) | Grupo vê, cada um paga | `Suspense` (Grupo), `SuspenseSeen` (c→s) | perde (comentário no Net: por design) | — |
| Perseguidor de fora | servidor (`OutsideService`) | **Eu** | atributos `OutsideStage`, `OutsideAt`, `ChasePos` no Player | atributos prontos | colega e espectador **não veem** o monstro (B-06) |
| Atmosfera | servidor | Grupo | atributos do Workspace | pronto | — |
| Trânsito / pedestres | servidor | Grupo | sets `Traffic`, `Pedestrians`; `CarHit` (c→s) | pronto | — |
| Revive | servidor (`VitalService`, `ReviveKitService`) | Grupo | `ReviveKits` (Eu), `ReviveKitUse`; prompt `revive_mate` só com crédito | — | revive de colega só pago (B-03) |
| Espectador | cliente (câmera POV do colega `Active`) | Eu | lê `Vitals` | — | não vê efeitos locais do colega (B-11) |
| Cutscene | servidor | Grupo | set `Cutscene` + `CutsceneSnapshot`, `SkipVote`, `ClientReady` | snapshot cobre backlog perdido | só finale e créditos (DEC-309); voto ≥ 50% dos conectados (DEC-194) |
| Resumo / fim | servidor | Grupo (`ShiftReport`), Eu (`RunReport`) | — | quem entrar depois perde o resumo | — |
| Loja Robux no HUD | servidor | Eu; `util_scare` assusta um colega escolhido | `ShopPick`, `ShopGrant`, `ShopOffer` | — | susto pago num colega: aceitável, mas pode irritar (Q) |
| Toasts | servidor | `Notify(player)` = Eu, `Notify("all")` = Grupo | `Notice` | perde | o campo `Audience` de `Content.Notices` é só documentação: quem decide é o chamador (B-12) |

---

## 4. Anomalias com vários jogadores

Regra geral (DEC-204): **o sinal é visto por todos** (`AnomalyCue` ao grupo, set `Anomalies`); **erro e custo por
jogador** onde a anomalia é "por jogador"; "active" = todos os membros ativos. O jumpscare em tela cheia é **privado**
(Entity = `UserId % 65536`) ou para **quem está perto** do cliente-anomalia (Entity = NpcId, raio). Espectador nunca vê
jumpscare (`Watch.Watching`).

| Anomalia | Família / verbo | Quem resolve | Quem sofre o erro | Susto | Observação multiplayer |
|---|---|---|---|---|---|
| ANM-001, 012, 013, 014, 015, 016 (cliente estranho) | A / recusar (fechar a janela na cara) | quem fechou a janela | **quem anotou o pedido** (desmaio) | quem está perto do cliente vê a cara; só quem errou cai | colega novato pode errar por todos? Não: só ele cai. Ok |
| ANM-004 (cópia) | A / recusar a cópia | idem | quem anotou o pedido da cópia | idem | — |
| ANM-005 (moça de capa) | A / atender | quem serviu | recusar = quem recusou; paciência acabou = **todos ativos** | — | punição coletiva por omissão: coerente com "omissão = grupo" |
| ANM-011 (tremendo) | A / servir puro | quem serviu | quem serviu com cobertura ou fechou a janela | privado/perto | — |
| ANM-022 (bate cabeça) | A / apagar a luz da loja | qualquer um que apague | quem anotou o pedido | — | a luz é do time |
| ANM-006 (perseguidor da calçada) | olhar faz andar | ninguém precisa agir; fechar janela no salto | **o mais perto da janela**, não quem olhou | privado | **injusto em grupo** (B-08): um olha, outro paga |
| ANM-008 (carro comprido) | fechar janela e ficar dentro | — | cada jogador na zona sem proteção; quem abrir a janela depois | privado | um colega que abre a janela só pune a si mesmo (ok) |
| ANM-009 (batidas) | trancar a porta dos fundos | o primeiro que tranca | quem abre; porta estourada = todos ativos | privado | — |
| ANM-010 (Hush) | apagar a luz da loja | o time (interruptor) | todos ativos se a luz estiver acesa no momento da cabeça | privado | um jogador religando a luz pune **todos** (B-07) |
| ANM-017 (rastejador) | sair do chão | cada um | cada um no chão | privado | justo |
| ANM-019 (teto) | não olhar para cima | cada um | cada um que olhou | privado | justo; espectador não conta |
| ANM-020 (apagão) | disjuntor | qualquer um | **todos ativos** (−35 sanidade) | privado | bom gancho para co-op (DEC-306 tem a ideia de 2 quadros) |
| ANM-021 (névoa vermelha) | fechar janela, ficar dentro | — | cada um desprotegido; quem abrir | privado | — |
| Perseguidor de fora (`OutsideService`) | voltar para dentro | cada um | cada um, após 30 s fora | privado | monstro invisível aos colegas (B-06) |
| Suspense / família D | nenhum | — | quem olhou paga sanidade (uma vez por jogador por evento) | — | — |

Quantidade de anomalias **não escala** com o número de jogadores (o `Scheduler` não lê o roster). Com 4 pessoas cada
anomalia é mais fácil (mais olhos, alguém sempre perto do disjuntor). Decisão de design (Q-413).

---

## 5. Interfaces: o que aparece certo e errado

| Elemento | Hoje | Avaliação |
|---|---|---|
| Sanidade no HUD | só a própria | certo (DEC-167) |
| Nome dos colegas | cartão creme com a cor do colega, até 60 studs, sempre por cima (`MateTag`) | certo |
| Cash no HUD | caixa do time | certo; falta dizer quem gastou (B-12) |
| Toasts de compra/upgrade | "{upgrade} upgraded!" para todos, sem nome | **falta autor** (B-12) |
| Painel do tutorial / seta / voz | por jogador, só novatos | certo; o veterano espera sem saber por quê (B-04) |
| Tela de queda | cartão da causa privado; revive 15 s; coração do time só nas telas de queda | certo (DEC-318) |
| Espectador | POV do colega `Active`, troca de alvo, `SPEC-P` sem ninguém | ok; efeitos do colega não aparecem (B-11) |
| Jumpscare | privado ou por proximidade; nunca no espectador | ok; colisão rara de `UserId % 65536` (B-13) |
| Resumo do turno | `ShiftReport` ao grupo; gemas = o maior valor entre os jogadores | ok |
| Aviso "No gems today" | ao grupo quando o **time** completou menos de 3 pedidos | AFK ganha igual se o time trabalhar (B-16) |
| Lobby: tela de classes | esconde todos os personagens localmente | certo |
| Gear Stand aberto/fechado | toasts ao grupo + portas | certo |

---

## 6. Bugs e riscos

| ID | Sev. | O quê | Evidência | Proposta |
|---|---|---|---|---|
| B-01 | **Alta** (a confirmar) | **Clientes não escalam de verdade à noite** (o jogo é quase todo à noite). DEC-306 pede mais clientes com mais jogadores. Hoje: só o **intervalo** cai (`Content.Flow.PartyMult` 1/1,6/2,1/2,5); o teto noturno é fixo **6** (`Flow.MaxCustomersNight`), o balcão noturno tem **1 vaga** (`Flow.NightQueueSize = 1`), e `Restaurant.Flow.MaxCustomers {5,7,9,9}` e `Restaurant.Flow.PartyMult {1,1.8,2.5,3.1}` **não são lidos** por ninguém (só pelo `Validate`) | `CustomerService:MaxCustomers`, `:QueueSize`, `:MeanInterval` | TASK-612 |
| B-02 | **Alta** (design) | **Caixa do time sem regra**: qualquer jogador compra qualquer upgrade com todo o dinheiro, sem aviso de quem | `MarketService` (bench), `Notices.upgrade_bought` | Q-408, TASK-616 |
| B-03 | Média (design) | Reviver colega só com **Revive Kit pago** (créditos); sem crédito, o colega caído vira espectador até a próxima noite. Em grupo, ajudar o amigo depende de Robux | `ReviveKitService`, `Actions.revive_mate` | Q-409 |
| B-04 | Média | **Trava do tutorial para o grupo**: o relógio para para todos enquanto houver novato pendente (até 600 s); um novato que entra depois **zera** o contador e trava de novo; a lição de upgrade segura o Summary da N1 por até 600 s e termina para todos na compra de qualquer um | `TutorialService:ShouldHold`, `:LessonHold` | Q-412, TASK-613 |
| B-05 | Média | Teleporte, retorno, reconexão e retomada **nunca rodam no Studio**; sem registro de teste publicado com 2 contas | `PartyRunService:CanReturn`, `SessionService` | TASK-611 |
| B-06 | Média | **Perseguidor de fora invisível** para colegas e espectador (só atributos no próprio Player, só o `LocalPlayer` desenha) | `OutsideController` | Q-414, TASK-614 |
| B-07 | Média | Interruptor e janela são do time: na ANM-010 um jogador acendendo a luz derruba **todos**; na família A quem fecha a janela "recusa" por todos | ANM-010, Kit/CustomerActor | aceitar (é co-op) ou aviso claro; entra no roteiro de teste |
| B-08 | Média | ANM-006: qualquer olhar faz o vulto andar e ele ataca **o mais perto da janela**, não quem olhou | ANM-006 | Q-410 |
| B-09 | Média (a confirmar) | Foco de cozinha sem exclusividade: dois jogadores no foco da mesma grelha/tábua; props são locais | `Kitchen/Cook.luau`, `CookController` | roteiro TASK-610 |
| B-10 | Média (a confirmar) | Quem entra/reconecta **no meio de uma anomalia** recebe o set `Anomalies`, mas não os `AnomalyCue` já disparados (ex.: `blackout_start`); a cena pode faltar | `AnomalyService` cues | TASK-621 |
| B-11 | Baixa | Espectador vê a POV do colega sem os efeitos locais dele (perseguidor, mancha da ANM-019, cenas) | `CameraController` Spectate | TASK-620 |
| B-12 | Baixa | `Notice` não tem autor; `Content.Notices.Audience` não é aplicado (quem chama decide) | `RunStateService:Notify` | TASK-615 |
| B-13 | Baixa | Jumpscare privado por `UserId % 65536`: dois jogadores com os mesmos 16 bits baixos veem o susto um do outro | Effects ANM-006/008/009/010/019 | TASK-622 |
| B-14 | Baixa | Docs: `overview.md` fala em 8 plataformas (são 4); `architecture.md` §1.1 diz `CharacterAutoLoads = false` (a place tem `true`; o `CharacterService` troca o personagem) | docs | TASK-624 |
| B-15 | Baixa | 5º jogador num servidor `Game` sem launch (Studio, Team Test, override): sem personagem e sem aviso | `RunStateService:Admit` | TASK-623 |
| B-16 | Baixa (design) | Anti-AFK é do time (`Completed` do grupo ≥ 3): um AFK ganha as gemas do dia/noite | `RewardService:ReportStep` | Q-411 |

---

## 7. O que é Provisório (sem DEC)

- Trava do tutorial em grupo e lição de upgrade (pedido do dono 2026-10-11/14, sem DEC).
- Squad: plataformas, `Access`, cancelamento da contagem, Play Solo (pedidos 2026-10-11/12).
- Reconexão/retomada (TASK-360, Provisional; DEC-063/067/080 dão a regra, a técnica é Provisória).
- Escala de clientes: `PartyMult`, `MaxCustomers`, `NightQueueSize = 1` (TASK-287), drive-thru por party.
- `OutsideService` (perseguidor de fora) e a zona segura da Gear Stand (2026-10-18/20).
- Números de revive (`CauseTime`, `DownWindow`, `ReviveAllWindow` vêm da DEC-318; o "Revive all" de 99 R$ ainda sem ProductId).
- Alvos de erro por anomalia (todas as linhas "Provisional" dos módulos `Anomalies/ANM-*`).

---

## 8. Checagem feita no Studio (Edit, só leitura)

| Item | Valor |
|---|---|
| `Players.MaxPlayers` / `PreferredPlayers` | 60 / 60 |
| `CharacterAutoLoads` | true |
| `Workspace.ServerRoleOverride` / `PlaceRole` | ausentes (Play = papel `Game`, modo dev) |
| Pontos de spawn | `PS-1..4`, `PS-N1..N4`, `REV-1..4`, `SPEC-P`, `SPEC-M` (4 de cada: bate com o limite de 4) |
| Fila e retirada | `Q1..Q5`, `PU-1..PU-8` (`PickupSlots` 4 jogadores = 8: bate) |
| `HideZone` | 1 |
| `PartyPlatform` | 4 |

---

## 9. Plano em lotes (TASK propostas, não gravadas no board)

Números a partir de **TASK-610** como reserva; o task-planner confirma ao gravar.

**Lote 0 — medir (sem código)**
- **TASK-610** (qa-tester) Roteiro de Team Test com 2, 3 e 4 clientes no Studio: tutorial com 2 novatos e com 1 novato + 1
  veterano; 2 jogadores no foco da mesma grelha; cada família de anomalia com um colega perto e outro longe; desmaio de um,
  revive com kit, todos caídos; espectador; entrada tardia (3º cliente entra na metade da noite). Registro em
  `docs/tests/multiplayer-YYYY-MM-DD.md`.
- **TASK-611** (qa-tester + dono) Teste publicado com 2 contas: lobby → squad → teleporte → fim da run → volta; sair e
  voltar no meio (Rejoin); todos saírem e retomar (Resume).

**Lote 1 — corrigir o que quebra o grupo**
- **TASK-612** (backend) Escala noturna por jogador: ler `Restaurant.Flow.PartyMult`/`MaxCustomers` por party e decidir
  `NightQueueSize` por party (depende de Q-413).
- **TASK-613** (backend) Trava do tutorial em grupo conforme Q-412 (no mínimo: novato que entra depois não reinicia a
  trava; teto único por run; toast para o veterano "Waiting for the rookie").
- **TASK-614** (frontend) Perseguidor visível para colegas e espectador (desenhar o `ChasePos` dos outros Players, sem a cena
  pessoal) — depende de Q-414.
- **TASK-615** (backend + frontend) `Notice` com autor opcional (`UserId`) e texto "{name} bought {upgrade}".

**Lote 2 — regras de grupo (dependem das Q)**
- **TASK-616** regra de gasto do caixa (Q-408). **TASK-617** revive cooperativo (Q-409). **TASK-618** alvo da ANM-006
  (Q-410). **TASK-619** anti-AFK por jogador (Q-411).

**Lote 3 — polimento**
- **TASK-620** espectador vê o essencial do colega. **TASK-621** entrada tardia no meio de anomalia (cena montada a partir
  do set). **TASK-622** alvo do jumpscare sem colisão. **TASK-623** aviso + câmera para jogador excedente no modo dev.
  **TASK-624** docs (`overview.md` 4 plataformas, `architecture.md` §1.1).

**Lote 4 — carga**
- **TASK-625** sessão de 4 jogadores por 2 noites medindo rede (Lync), NPCs ativos e FPS; anomalias por noite com 4
  (Q-413).

Perguntas ao dono: **Q-408 a Q-414** em `docs/open-questions.md`.
