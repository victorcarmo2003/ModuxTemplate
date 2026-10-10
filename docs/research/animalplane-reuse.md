Status: Rascunho

# Reaproveitamento do AnimalPlane — prompt, barra de progresso, VFX

Levantamento read-only de `C:\Users\hakor\Documents\ModuxGames\AnimalPlane\src\` (2026-10-08).
Pedido do usuário: reaproveitar ProximityPrompt, barra de progresso de cozimento e ParticleEmitter.
Porte só depois da bandeira verde (Fase 0).

Stack lá: Modux, Vide 0.4.1, Lync 4.0.2. Charm não usado nesses sistemas. Tudo client-side; estado de cozimento vem do server via Lync.

## 1. Prompt — custom, não ProximityPrompt nativo

| Arquivo:linha | O quê |
|---|---|
| `Prompt/client/ProximityPromptController.luau:22` | `Modux.Controller`, Priority 620, deps `CharacterController`, `PlaneController` |
| `...:55-88` | hold: `task.delay(holdDuration * 0.65)` então `Prompt.Trigger` |
| `...:127-134` | `ContextActionService` E / ButtonX |
| `...:141-231` | tick 10 Hz, alvo mais próximo do centro da tela, histerese |
| `Prompt/client/Prompt.luau:57-151` | mixin; atributos `PromptRadius`, `HoldDuration`; `Triggered(cb)`, `CreateUI`, `Teardown` |
| `Prompt/client/PromptInterface.luau:68-133` | BillboardGui Vide, estados Hidden/Indicator/Prompt, fill do hold |
| `Prompt/shared/PromptTrigger.luau` | Sources Vide das teclas |

Deps: `shared/Interface/UseTween.luau`, `shared/Audio/GetSFX.luau`, `shared/Input/DeviceSettings.luau`; SFX `ChargeUp`, `ClickHover`, `Pop`.
Acoplamento: guarda `PlaneController.HasControl` (144-148), `CharacterController:GetRigRoot()` (150), DI `Dependencies.ProximityPromptController`.
**Portabilidade alta.**

## 2. Barra de progresso de cozimento

| Arquivo:linha | O quê |
|---|---|
| `Kitchen/client/CookInterface.luau:20-74` | BillboardGui Vide, StudsOffset (0,2,0), fill tween laranja→verde, texto. **Puro** (props Visible, Percentage, TextSource, Adornee) |
| `Kitchen/client/Boil.luau:20,34-56,116-121` | Component tag `Boil`; Idle/Cooking/Ready; progresso `(GetServerTimeNow() - StartedAt) / Duration` a 15 Hz |
| `Kitchen/client/Fry.luau` | cópia do Boil |
| `Kitchen/server/Boil.luau:30-67`, `CookService.luau:155-160` | lógica server, `task.delay(Duration)` |
| `Kitchen/shared/Net.luau:13-21` | `Lync.replicate` `Pots` (Pot, State, StartedAt, Duration) + packet `PotInteract` |

UI: **muito portável** (copiar `CookInterface` + `UseTween`). Lógica: padrão server manda `StartedAt/Duration`, client interpola — reaproveitar padrão; código amarrado a `CookingRecipes`, componente `Cook`, `PlayerService`.

## 3. VFX ParticleEmitter

| Arquivo:linha | O quê |
|---|---|
| `Effects/shared/GetVFX.luau:1-11` | clona `ReplicatedStorage.Assets.VFX[Name]` |
| `Kitchen/client/Boil.luau:23-30,87` | `ReadyVFX` no filho `Attachment`, `:Emit(10)`, Debris 2s, som `Bell` |

**Template não está no repositório.** `Assets/VFX` e `Assets/SFX` são Folders vazios em `default.project.json`; conteúdo vive só no place.
Para portar: abrir place no Studio, exportar `ReplicatedStorage.Assets.VFX.ReadyVFX` e SFX (`ChargeUp`, `ClickHover`, `Pop`, `Bell`, `BoilSound`, `FrySound`) como `.rbxm`. Modelo precisa de `Attachment` filho.
Só rajada no Ready; sem fumaça contínua durante cozimento.

## Resumo

| Sistema | Portabilidade | Cortar/ajustar |
|---|---|---|
| Prompt | alta | PlaneController, CharacterController |
| Barra UI | muito alta | nada |
| Barra lógica | média | receitas, Cook, CookService, schema Lync |
| VFX | código alta, asset manual | exportar .rbxm do place, `Attachment` no modelo |
