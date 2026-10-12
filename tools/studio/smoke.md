# Roteiro do agente: teste de fumaça no Studio

Código: `src/Dev/server/DevService/Commands/Smoke.luau` (comando `/dev smoke`). Muda o estado da run (dia, noite, veículo, mesas, tutorial): só em Play descartável, o place não é salvo.
Duração: cerca de 30 s no servidor. Passos: boot, intro skip, tutorial reset e `tutorial step` (phone, order, grill, assemble, serve, mart, auto), `day 2`, spawn + Take Order, `seating buy` + `customer sit`, `night 1`, café + sanidade, anomalia ANM-002 (trigger e stop pelo `ShowcaseService`), `trailer swap`, mesas do trailer, limpeza.

## Passos

1. `list_roblox_studios` (o id muda ao reabrir) e `get_studio_state` (tem de estar em Edit, com o `rojo serve` conectado e o build em dia: `rogen build` → `modux generate`).
2. `start_stop_play(true)`.
3. `execute_luau` em **Server**, uma chamada (o cliente precisa ter entrado; o `task.wait` cobre o boot e o resultado volta no mesmo retorno):

```lua
task.wait(6)
local D = require(game.ServerScriptService.server.Dev.DevService)
local started = tostring(D.Run("smoke"))
task.wait(50)   -- smoke leva ~35 s; chamadas acima de ~60 s podem cair, nesse caso repita com D.Run("smoke","status")
return started .. "\n" .. tostring(D.Run("smoke", "status"))
```

4. `get_console_output`: o relatório está no fim (`SMOKE: N ok, M failures, K warnings`, mais uma linha por passo que falhou, erro e aviso do servidor). Passos aparecem como `[Dev] [Smoke] ok|FAIL <passo>`.
5. **Erros de cliente não passam pelo servidor.** No mesmo console procure: `Requested module experienced an error`, `Stack Begin`, `Expected`, `attempt to`, `is not a valid member`, `Infinite yield`, `Failed to load sound : NotEnoughQuota` (cota de áudio, pedido 15 do playtest; hoje aparece dezenas de vezes). Qualquer um conta como falha (ex.: boot do cliente quebrado por tipo gerado inválido deixa o smoke do servidor verde).
6. `start_stop_play(false)`.

Resultado a anotar no registro do dia (seção Smoke): `SMOKE: N ok, M falhas, K avisos` + erros de cliente.

## Falhas conhecidas / dicas

- `no player in the server`: o Play abriu sem cliente; pare e reinicie.
- `customer take order`: precisa da fase Open; o passo faz `skip` sozinho. Falhar aqui costuma ser fila/NpcNodes.
- `day 2` depois de `tutorial reset` é de propósito: o smoke não testa o fluxo do tutorial até o fim, só os pulos.

Última execução real (2026-10-12, Play no Studio): `SMOKE: 13 ok, 0 failures, 0 warnings`. No cliente: só `NotEnoughQuota` (áudio) e `LoadQueue ... still running after 8 s`.
