# Admin / Conch (console de dev)

Status: Rascunho (Provisório, sem DEC). Feature `src/Admin/{server,client,shared}`.

## O que é

Console do [Conch](https://github.com/alicesaidhi/conch) + ConchUI, aberto com **F2** (`AdminSettings.ToggleKey`).
Pacotes no `wally.toml`: `Conch = alicesaidhi/conch@0.4.0`, `ConchUI = alicesaidhi/conch-ui@0.4.0`.
Os dois são requeridos direto (`ReplicatedStorage.Packages.Conch/ConchUI`), nunca em `src/Libs`
(mesma regra de Lync/Vide: ver README, "A armadilha do `self.Libs`").

## Política de acesso (autoritativa no servidor)

- `AdminSettings.IsAllowed(player)`: **Studio sempre libera**; servidor publicado só libera `UserId` em
  `AdminSettings.AdminUserIds` (vazio por padrão: o dono põe o próprio id).
- `AdminService` dá o role Conch `super-user` só a quem passa, no `PlayerService.PlayerAdded`. O Conch só replica
  comandos a quem tem a permissão, e cada callback reconfere `IsAllowed` no servidor.
- O client só decide se liga a tecla (UX); jogador comum não vê o console nem a lista de comandos.

## Comandos

| Comando | O que faz |
|---|---|
| `dev <comando> [args]` | ponte para o `DevService`: os mesmos comandos, args e help do chat `/dev` (`dev help` lista) |
| `day <n>`, `cash <n>`, `gems <n> [player]`, `upgrade [key] [level]` | atalhos tipados; encaminham ao comando homônimo do DevService |
| `tp <player>` / `tp <alvo> <player>` | teletransporte |
| `content item\|ingredient\|class <key>` | mostra uma linha de `Content` (somente leitura) |

Zero lógica duplicada: a ponte chama `DevService:Execute(nome, args, caller)`. O chat `/dev` segue igual.
Comando novo em `src/Dev/server/DevService/Commands/` aparece sozinho em `dev <comando>`.

**Política de produção:** o `DevService` só existe em modo dev (`PlaceService:IsDev()`: Run em Studio sem
PrivateServerId). Publicado, `dev ...`, `day`, `cash`, `gems`, `upgrade` respondem "dev commands are off"
e só `tp`/`content` funcionam. Não há flag "seguro p/ admin" nos comandos Dev; expor um em produção exige
decisão do architect (os hooks `Dev*` dos donos também checam `IsDev()`).

## Argumentos tipados (`shared/AdminArguments.luau`)

`ItemKey`, `IngredientKey`, `ClassKey`, `UpgradeKey` (enums vindos de `Content.*.Keys`), `Day`, `Money`,
`Player`. O callback valida de novo (inteiro, faixa) — o servidor não confia no valor parseado.

## Setup (usuário)

```sh
wally install
wally-package-types --sourcemap sourcemap.json Packages/ ServerPackages/ DevPackages/
rogen build && modux generate
```
Depois reconecte o Rojo (`rojo serve` + Connect no Studio). Teste: Play no Studio, F2, `dev help`, `day 3`.
