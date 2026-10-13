# tools/studio: atalhos baratos para o Studio MCP

## Carregar um snippet do repo (sem colar o código no prompt)

Funciona (testado em 2026-10-12): `HttpService.HttpEnabled` já está ligado no place, `loadstring` e `GetAsync` rodam em Edit via `execute_luau`.

1. Servidor HTTP na raiz do repo (uma vez por sessão; a porta 8772 já responde se alguém subiu antes):
   `python -m http.server 8772 --bind 127.0.0.1 --directory "D:/UserData/Documents/ModuxGames/Sell Hotdogs"` (em background).
   `curl http://127.0.0.1:8772/README.md` deve dar 200.
2. `mcp__Roblox_Studio__execute_luau` (Edit, `studio_id` do `list_roblox_studios`) com 2 linhas:

```lua
local run = loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8772/tools/studio/run_snippet.luau", true))()
return run("trailer_tables")   -- tools/assetplace/trailer_tables.luau; "outra/pasta/x" = tools/outra/pasta/x.luau
```

O snippet roda com `...` = os argumentos extras de `run(name, ...)` e devolve o que ele devolver. `true` no `GetAsync` evita cache. Snippets que são módulos (`place_assets`, `map_frame`) retornam a tabela; chame as funções depois (`run("place_assets").run(...)`).

Regras: só snippets idempotentes (ver `STUDIO_LAYER.md`); nunca `Place.run` sem o dono. `mcp__Roblox_Studio__http_get` só aceita URLs de docs da Roblox, não serve para isto.

## Teste de fumaça

`smoke.md`: `/dev smoke` roda boot, intro, tutorial, dia, mesas, noite 1, anomalia, troca de trailer e imprime `SMOKE: N ok, M falhas, K avisos`.

## Teste de sobreposição do chrome do preparo (puro, sem Studio)

`tools/studio/prep_layout_check.luau` roda o `Layout.luau` real do `PrepShell` em 7 telas (667x375, 844x390, 932x430, desktop, retrato) e confere sobreposição entre nossos blocos, a zona do Hud (relógio, dinheiro, sanidade), o menu do Roblox, o centro livre do mundo, alvos >= 44 px e tudo dentro do canvas. O `lune` não está no `rokit.toml`: rode o binário do `rokit` direto, da raiz do repo:
`"~/.rokit/tool-storage/lune-org/lune/<versão>/lune.exe" run tools/studio/prep_layout_check` (esperado `LAYOUT: 7 ok, 0 failures`).
