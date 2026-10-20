Status: Aprovado (DEC-318; substitui o roteiro da DEC-317)

# Tela de queda: causa, contagem do revive e vida do time

Pedido do dono, 2026-10-20. A 1ª versão (DEC-317) tinha "muito texto e muita animação". A 2ª é objetiva: **três telas,
uma de cada vez**, e a tela **limpa** durante as contagens, com **só o produto no centro e a contagem**.

## 1. As três telas

| Tela | Quando | O que aparece | Tempo |
|---|---|---|---|
| 1. Causa | sempre, logo depois da queda | "WHAT GOT YOU", a causa e como passar dela (`Content.FaintTips`) | `Revive.CauseTime` = 3 s |
| 2. Revive | caí e **ainda tem alguém de pé** | o número da contagem e o botão de revive ("Use Revive Kit (n)" ou "Revive · R$ 39"); nada mais | `Revive.DownWindow` = 15 s |
| 3. Vida do time | caiu **o último** | com vida: o coração parte (1 → 0), **LAST CHANCE**, a noite recomeça. Sem vida: a contagem + **Revive all · R$ 99** para todos | com vida: só a tela 1, depois a noite perdida; sem vida: `Revive.ReviveAllWindow` = 15 s |

- Quando caio e **não tem mais ninguém de pé**, a tela 2 não aparece: depois da causa vem direto a tela 3.
- Se a contagem da tela 2 zera sem revive, o jogador vira **espectador até a próxima noite** (spectate normal, sem
  oferta). Se depois cair o último, a tela 3 vale para todos.
- Com vida: a noite **recomeça do início** (como a noite perdida de hoje), gastando a vida (DEC-053, DEC-110).
- Sem vida: **Revive all** levanta o time inteiro (quem está caído e quem já é espectador) e a noite **continua**.
  Ninguém comprou em 15 s: fim da run ("Shift's over").
- Comprado tarde demais (a janela fechou), o Revive all vira **1 crédito de Revive Kit** para quem pagou.
- O "Revive all" não aparece na loja, só na tela 3.

## 2. Etapa D: a dica (tela 1)

A causa vem do servidor (`VitalService.LastCause`, pacote `FaintCause`) e vira cartão em `Content.FaintTips`:

| Causa | Título | Dica |
|---|---|---|
| `anomaly:` / `see:` | título da página do Journal | 1ª linha "Fight" da página |
| `stare:` | título da anomalia | "Don't stare. Look away when your heart starts racing." |
| anomalia ainda não vista | "Something you haven't met yet" | dica genérica (sem spoiler) |
| `suspense:` | "Something was watching" | "Don't look where you hear it breathing." |
| `dark` | "The dark got you" | "Stay in the light. Fix the breaker fast." |
| outras | "Your nerves gave out" | "Drink coffee before your sanity runs low." |

## 3. Ícones

- **AST-165** coração da vida do time (branco, tingido no client) e **AST-166** ícone do revive (coração rosa com "+",
  brilho arredondado no lobo esquerdo). Gerados por `tools/icons/life_hearts.py`; ids em `Icons` (`Life/heart`,
  `Life/revive`).

## 4. Onde está no código

| Peça | Arquivo |
|---|---|
| tempos | `Content.Revive` (CauseTime, DownWindow, ReviveAllWindow) |
| Down vira espectador em 15 s; janela de quem cai por último; Revive all | `VitalService` (ExpireDowns, EvaluateWipe, ReviveAll) |
| produto `util_revive_all` (ProductId a criar no Creator Hub, 99 R$) | `Content.Shop`, `ShopUtilityService`, `ReviveKitService:Grant` |
| telas 1, 2 e 3 (sem vida) | `ReviveKitController` (`Stage`: Cause, Countdown, Wait, ReviveAll) |
| tela 3 (com vida e fim de run) | `NightLostController` + `NightLostScreen` + `LifeHeart` |
| HUD do espectador escondido durante as telas | `HudSpectate` (prop `Hidden`), `HudController` |

## 5. Pendente

- **Criar o produto "Revive All" (99 R$) no Creator Hub** e colocar o ProductId em `Content.Shop` (`util_revive_all`).
  Até lá o botão aparece, mas a compra não abre.
- A tela 2 (contagem com alguém de pé) precisa de 2 jogadores para testar no Studio.
- A legenda da ligação do Walt pode aparecer por cima da tela 3; decidir se ela some durante as contagens.
