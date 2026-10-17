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
| `help` / `help <comando>` | lista TODOS os comandos do console (nome, args, descrição) e, em dev, os do `/dev`; `help <cmd>` mostra um. **Mora no client** (ver abaixo) |
| `dev-help` | servidor devolve o texto de ajuda do DevService (usado pelo `help`) |
| `dev <comando> [args]` | ponte para o `DevService`: os mesmos comandos, args e help do chat `/dev` (`dev help` lista) |
| `day <n>`, `night <n>`, `cash <n>`, `gems <n> [player]`, `upgrade [key] [level]` | atalhos tipados; encaminham ao comando homônimo do DevService |
| `showcase` | abre o painel de showcase (testar anomalias, sustos e mecânicas; também F9 e `/dev showcase`). Ver `showcase.md` |
| `anomaly <id> <trigger, resolve, wrong ou stop>` | `<id>` = `ANM-###`, chave ou número da noite; passa pelo `ShowcaseService` (mesmo gate dev + whitelist) |
| `scare <id>` | alucinação (`fake_call`, `whisper`...) ou `sting:<som>` no seu client |
| `tp <player>` / `tp <alvo> <player>` | teletransporte |
| `content item\|ingredient\|class <key>` | mostra uma linha de `Content` (somente leitura) |

Zero lógica duplicada: a ponte chama `DevService:Execute(nome, args, caller)`. O chat `/dev` segue igual.
Comando novo em `src/Dev/server/DevService/Commands/` aparece sozinho em `dev <comando>`.

`showcase`, `anomaly` e `scare` falam com o `ShowcaseService` (feature `src/Showcase`), que só liga em modo dev e reconfere
`IsDev` + `AdminSettings.IsAllowed` em cada chamada; publicado respondem "showcase is not available here". Comandos novos do
`DevService` ligados a eles: `/dev showcase` e `/dev revive [player]`.

**Política de produção:** o `DevService` só existe em modo dev (`PlaceService:IsDev()`: Run em Studio sem
PrivateServerId). Publicado, `dev ...`, `day`, `night`, `cash`, `gems`, `upgrade` respondem "dev commands are off"
e só `tp`/`content` funcionam. Não há flag "seguro p/ admin" nos comandos Dev; expor um em produção exige
decisão do architect (os hooks `Dev*` dos donos também checam `IsDev()`).

## Por que `help` é local (armadilha do Conch 0.4.0)

O Conch **não tem comando `help` nativo**: só `clear`, `ansi`, `close-ui` (ConchUI) e `print`, `sleep`, `set`, `license`,
`error`/`warn`/`info` (bootstrap). `help` registrado no servidor depende de role, replicação e round trip, e falhou
na prática ("non-existent command" = o nome não está em `globals` do VM do client). Por isso `AdminController`
registra `help` **no client** (`permissions = {}`), monta a lista de `conch.console.commands` (inclui os replicados do
servidor; args vêm do `type` do comando) e pede o texto dev ao comando de servidor `dev-help`. Não registre outro
`help` no servidor: sobrescreveria o do client nos globals. Ao abrir, o console imprime "Type help".

## Argumentos tipados (`shared/AdminArguments.luau`)

`ItemKey`, `IngredientKey`, `ClassKey`, `UpgradeKey` (enums vindos de `Content.*.Keys`), `Day`, `Money`,
`Player`. O callback valida de novo (inteiro, faixa) — o servidor não confia no valor parseado.

## Setup (usuário)

```sh
wally install
wally-package-types --sourcemap sourcemap.json Packages/ ServerPackages/ DevPackages/
rogen build && modux generate
```
Depois reconecte o Rojo (`rojo serve` + Connect no Studio). Teste: Play no Studio, F2 (aparece "Type help"), `help`, `help day`, `dev help`, `day 3`.
