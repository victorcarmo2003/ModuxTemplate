# Roteiro do agente: teste de fumaça no Studio

Código: `src/Dev/server/DevService/Commands/Smoke.luau` (comando `/dev smoke`) + `Scenarios/RestaurantSmoke.luau`. Muda o estado da run (dia, pratos, mesas): só em Play descartável, o place não é salvo.
Desde 2026-10-18 (`docs/tech/dev-commands.md`) o smoke é só o loop do restaurante, um cliente de ponta a ponta: setup (`tutorial intro`, `day 2`, `customer off`, `skip`, `plate clear`), customer, tablet, cut, plate bun, grill, rail, plate dog, condiments, pickup, table. Os passos do trailer (troca de veículo, mesas do trailer, gorjeta + ledger) saíram; o ledger roda à parte com `/dev money ledger` (precisa fechar `N/N ok`).

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

4. `get_console_output`: o relatório está no fim (`RESTAURANT SMOKE: N/M PASS`, uma linha `PASS|FAIL <passo>` por passo; um FAIL pula os seguintes).
5. **Erros de cliente não passam pelo servidor.** No mesmo console procure: `Requested module experienced an error`, `Stack Begin`, `Expected`, `attempt to`, `is not a valid member`, `Infinite yield`, `Failed to load sound : NotEnoughQuota` (cota de áudio, pedido 15 do playtest; hoje aparece dezenas de vezes). Qualquer um conta como falha (ex.: boot do cliente quebrado por tipo gerado inválido deixa o smoke do servidor verde).
6. `start_stop_play(false)`.

Resultado a anotar no registro do dia (seção Smoke): `RESTAURANT SMOKE: N/M PASS` + erros de cliente.

## Falhas conhecidas / dicas

- `no player in the server`: o Play abriu sem cliente; pare e reinicie.
- `setup`: precisa chegar a uma fase de venda com a gaveta aberta; falhar aqui costuma ser fase presa (veja `/dev night` / `/dev skip`).

Última execução real do smoke antigo (2026-10-12, trailer): `SMOKE: 13 ok, 0 failures, 0 warnings`. No cliente: só `NotEnoughQuota` (áudio) e `LoadQueue ... still running after 8 s`.
