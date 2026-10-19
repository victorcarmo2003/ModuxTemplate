Status: Rascunho

# Auditoria de status das anomalias (modo restaurante)

Autor: qa-tester (sessão de auditoria) · 2026-10-18 · só leitura de código e docs, nada rodado no Studio.
Régua: o apagão (ANM-020, `HorrorScenes` `anm_020_blackout`, `design/horror-cinematic.md` §2) — pedido do dono 2026-10-18 de
fechar toda anomalia nesse nível. Tudo **Provisório** até o Play do dono.

Fontes lidas: `src/Shared/Content/{Anomalies,Nights,Restaurant,Hallucinations,Atmospheres,HorrorScenes}.luau`,
`src/Anomaly/server/AnomalyService/{Anomalies,Rules}/ANM-0xx.luau`, `src/Anomaly/client/AnomalyController/Effects/ANM-0xx.luau`,
`src/Dev/server/DevService/Commands/{Anomaly,Scene,Scare,Blackout,Suspense}.luau`, `docs/design/horror-cinematic.md` (§2, §3, §6,
§9, §10), `docs/design/anomalies-v3-restaurant.md` §8, `docs/tasks/board.md`, `docs/tests/*.md`. Branch `claude/anm-audit-b15897`
(HEAD `8b97dbc5`, com o merge da TASK-561 e dos roteiros §3/§10).

## 1. Catálogo real com o restaurante ligado

`Restaurant.Rules.Enabled = true` ⇒ `Restaurant.Switch`:

- `CutAnomalies` = `anm_002_wrong_food`, `anm_003_stopped_clock`, `anm_007_walker`, `anm_018_grin` → `Family = nil`,
  `Scripted = nil` (fora da agenda; módulo e página do Journal ficam, dev ainda força).
- `DebutNights = {}` (nenhuma estreia muda por chave).
- `NewAnomalies`: N6 = `anm_014_big_head`, N8 = `anm_008_long_car` (as estreias da família B cortadas). N7 volta a ser o
  rastejador (TASK-483), N9 o roof walker (TASK-484).

**17 anomalias ativas** (ordem de estreia; família; noite que a chefe apresenta):

| Estreia | Anomalia | Família | Apresentada na noite | Observação |
|---|---|---|---|---|
| N1 | ANM-001 Sem rosto (`anm_001_blank_folks`) | A | N1 | |
| N2 | ANM-011 O que treme (`anm_011_shaker`) | A | N2 | |
| N2 | ANM-009 A batida (`anm_009_knock`) | D | — (calada; ligação N2 avisa) | Ref ANM-009, `Night = 2` (TASK-341) |
| N3 | ANM-020 Apagão (`anm_020_blackout`) | C | N3 | |
| N4 | ANM-012 Pescoço invertido (`anm_012_turned_neck`) | A | N4 | |
| N4 | ANM-006 O da parada (`anm_006_stalker`) | D | — | |
| N5 | ANM-004 A cópia (`anm_004_copies`) | A | — | `Stare` |
| N5 | ANM-005 Raincoat Lady (`anm_005_raincoat_lady`) | A | — | nunca em ATM-4/ATM-5 (N4 chuva, N7 tempestade) |
| N5 | ANM-013 Olhos brancos (`anm_013_white_eyes`) | A | N5 | `Stare` |
| N5 | ANM-021 Névoa vermelha (`anm_021_red_fog`) | C | — | |
| N6 | ANM-014 Cabeça errada (`anm_014_big_head`) | A | N6 (restaurante) | |
| N7 | ANM-015 Flutuando (`anm_015_floater`) | A | — | |
| N7 | ANM-017 Rastejador (`anm_017_crawler`) | B | N7 | "suba no balcão" (Kit/Hide `Floor`) |
| N8 | ANM-016 Não pisca (`anm_016_starer`) | A | — | |
| N8 | ANM-008 Carro comprido (`anm_008_long_car`) | D | N8 (restaurante) | |
| N9 | ANM-019 Sombra no teto (`anm_019_roof_walker`) | B | N9 | "não olhe para cima" |
| N10 | ANM-010 The Hush (`anm_010_hush`) | C | N10 | `Scripted` N10 5:45 AM |

Famílias abertas por noite (`Nights.luau`): N1–2 A+D; N3–5 A+C+D; N6–10 A+B+C+D. Atmosferas: N1–2 ATM-1, N3 ATM-2, N4 ATM-4,
N5 ATM-6, N6 ATM-3, N7 ATM-5, N8 ATM-2, N9 ATM-3, N10 ATM-7.

> **Achado:** na N6 a família B abre, mas no restaurante não há nenhuma linha B elegível (Walker cortado, rastejador estreia na
> N7). A N6 roda sem B; não quebra (o agendador só sorteia o que existe), mas a coluna `Families` da N6 promete algo que não vem.

**Família D sem verbo** (`Content.Hallucinations`, todas `FamilyD = true`, efeitos em `HallucinationController/Effects/`): 15
sustos — `fake_call`, `grill_hiss`, `bottle_fall`, `roof_steps`, `roof_knock`, `ghost_customer`, `post_flicker`, `radio_voice`,
`street_watcher`, `whisper`, `mart_sign_blink`, `sign_word`, `window_shadow`, `window_face`, `monster_glimpse`. Todos têm módulo.
`mart_sign_blink` e `post_flicker` foram escritos para o Mart/postes da Juniper do trailer: conferir no Play se aparecem no
restaurante (o Mart saiu do mapa, `MartShelves = false`). Mini-cenas da §3.12: TASK-553 **Pendente**.

**Atmosferas** (`Content.Atmospheres`, `AtmosphereController`): ATM-1..ATM-7 em dados, uma por noite. Não há anomalia nelas;
só o filtro `SkipAtmospheres` da Raincoat.

## 2. Matriz por anomalia

Colunas: **Srv** = `AnomalyService/Anomalies/ANM-0xx` + `Rules/ANM-0xx`; **Cli** = `Effects/ANM-0xx` (linhas; 6 = só o
`Kit/OddCustomer`); **Cena** = entrada em `Content.HorrorScenes` (`oddScene` = a cena curta padrão da TASK-491); **Curva** = segue
calma → aviso → escalada → silêncio → clímax → alívio; **§3** = roteiro no padrão do apagão em `horror-cinematic.md`.

| Anomalia | Srv | Cli | Cena | Curva | Roteiro | TASKs (board) | Evidência de teste | Status |
|---|---|---|---|---|---|---|---|---|
| ANM-020 Apagão | sim (270 + Rules 48) | sim (693) | sim, completa | **sim** (é a régua; o silêncio é "os passos param", sem passo `Silence`) | §2 (referência) | 273 Feito estático · 444 **Em andamento** · 467 Em QA · 431 Backlog | Play do agente na TASK-467 (porta 13,4 s, sombra 11,0 s, prints `play_apagao_*`); susto aos 30,00 s (rodada 472–479); plano `restaurant-e2e.md` H1–H8 sem resultado anotado | **Pronta+testada** (falta Play do dono) |
| ANM-009 A batida | sim (223 + Rules com `Restaurant`) | sim (786) | sim, refeita | **sim** (silêncio antes do pico, maçaneta/empurrão, clímax blur/vermelho) | `anomalies-v3-restaurant.md` §8.3 (não está no §3) | 561 Em QA · 333 Feito estático | nenhuma; plano de Play só no relatório da 561 | **Pronta sem teste** |
| ANM-019 Sombra no teto | sim (152 + Rules 26) | sim (214) | sim | **sim** (Signal, `Silence`, `HeadDown`, Failed forte) | §6.1 (+ §3.11 Fora) | 484 **Pendente** (código já cita) · 551 Pendente | nenhuma | **Pronta sem teste** (falta Fora + eco) |
| ANM-017 Rastejador | sim (Kit/Hide `Floor`, Rules com `Restaurant`) | sim (25 + Kit/Hide) | sim, `Live` só no restaurante | **sim** (Signal, `Silence`, empina no meio) | §9 | 483 Em QA · 272 Feito estático · 432 Backlog | nenhuma | **Pronta sem teste** |
| ANM-012 Pescoço invertido | sim (128 + Rules 21) | sim (6 + Kit, cues `neck_snap`/`window_slam`) | sim | **adaptada**: sem Signal (cliente não tem aviso); `Silence` no Active; pico só no Failed | §9 | 483 Em QA · 336 Feito estático (Studio pendente) · 354 · 430 Backlog | nenhuma | **Pronta sem teste** |
| ANM-004 A cópia | sim (349 + Rules 31) | sim (524) | sim | **não**: sem silêncio no Active (só em Resolved/Failed), sem coração | §9 | 483 Em QA · 347 Feito estático · 287 | nenhuma | **Parcial** |
| ANM-006 O da parada | sim (229 + Rules 26) | sim (343) | sim | **sim** (Signal com coração, `Silence` no Active) | §3.3 (versão completa) | 490 Em QA · 351 "Falta Play" · 543 Pendente · 434 Backlog | nenhuma | **Pronta sem teste** (versão §3 pendente) |
| ANM-008 Carro comprido | sim (257 + Rules 37) | sim (586) | sim | **sim** (Signal, `Silence`, farol) | §3.4 | 490 Em QA · 331/348 "Falta Play" · 480 **Pendente** (código já tem `Shutter_Panel_DT`) · 544 Pendente · 437 Backlog | nenhuma | **Pronta sem teste** (versão §3 pendente) |
| ANM-010 The Hush | sim (428 + Rules 39) | sim (456) | sim, palavras `hush_shop` | **sim** (`Silence` x3 no Active) | §3.5 | 490 Em QA · 284 Feito (Studio) · 334 Studio pendente · 545 Pendente · 438 Backlog | 284 "Estático + Studio" (era trailer, antes do restaurante) | **Pronta sem teste** no restaurante |
| ANM-021 Névoa vermelha | sim (179 + Rules 25) | sim (281) | sim | **sim** (sino em rampa, `Silence` S+8–11, pancadas) | §3.11 | **nenhuma task de criação** · 552 Pendente (Fora + eco) | nenhuma | **Pronta sem teste** |
| ANM-001 Sem rosto | sim (Kit) | sim (174) | `oddScene` | **não** (sting, barras, palavras; sem silêncio, sem coração, sem pico) | §3.1 | 491 Em QA · 292 Feito estático · 541 Pendente · 535 `Pose` Pendente · 430 Backlog | nenhuma no restaurante | **Parcial** |
| ANM-005 Raincoat Lady | sim (Kit) | sim (356) | `oddScene` | **não** | §3.2 | 491 Em QA · 326 Feito · 542 Pendente · 433 Backlog | 326 "conferido no Play" (`/dev anomaly ANM-005`, capa e pingos, era trailer) | **Parcial** |
| ANM-011 O que treme | sim (Kit) | 6 (Kit) | `oddScene` | **não** | §3.6 | 491 Em QA · 292 · 276 · 546 Pendente (só se Q-389 ≠ B) | nenhuma | **Parcial** |
| ANM-013 Olhos brancos | sim (Kit) | 6 (Kit) | `oddScene` + `Stare` | **não** | §3.7 | 491 Em QA · 292 · 547 Pendente · 430 Backlog | nenhuma | **Parcial** |
| ANM-014 Cabeça errada | sim (Kit) | 6 (Kit) | `oddScene` | **não** | §3.8 | 491 Em QA · 292 · 548 Pendente · 492 Em QA (ligação N6) | nenhuma | **Parcial** |
| ANM-015 Flutuando | sim (Kit) | 6 (Kit) | `oddScene` | **não** | §3.9 | 491 Em QA · 292 · 549 Pendente (só se Q-389 ≠ B) | nenhuma | **Parcial** |
| ANM-016 Não pisca | sim (Kit) | 6 (Kit) | `oddScene` | **não** | §3.10 | 491 Em QA · 292 · 337 · 550 Pendente (só se Q-389 ≠ B) | nenhuma | **Parcial** |

Cortadas (não auditadas a fundo, fora da agenda): ANM-002, 003, 007, 018 — módulos existem; 007 e 018 têm `Effects` de 15 linhas.
Nenhuma anomalia ativa está em "Só trailer" ou "Não feita".

Resumo: **1** Pronta+testada (020) · **8** Pronta sem teste (009, 019, 017, 012, 006, 008, 010, 021) · **8** Parcial (004, 001,
005, 011, 013, 014, 015, 016).

Peças do kit da §3.13 que **não existem** no código (grep em `Scene/`): campo `Where`, passos `Pose`, `Glass`, `Prop`, `Glare`,
`Silhouette`, `Echo`, perfis `Rumble`/`Tremor` — TASK-534..539 todas Pendente. Sem elas nenhuma cena do §3 pode ser feita como
está escrita.
