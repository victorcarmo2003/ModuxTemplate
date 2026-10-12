--!nocheck
-- Studio snippet loader (Edit/Play via execute_luau). Fetches tools/<path>.luau from the repo HTTP server and runs it.
-- Call: loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8772/tools/studio/run_snippet.luau"))()("trailer_tables")
-- Returns whatever the snippet returns. Name without extension; "assetplace/x" or just "x" (= assetplace/x).
local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8772/tools/"
return function(name: string, ...: any): any
	local path = if string.find(name, "/", 1, true) then name else "assetplace/" .. name
	local source = HttpService:GetAsync(BASE .. path .. ".luau", true)
	local fn, err = loadstring(source, "=" .. path)
	assert(fn, err)
	return fn(...)
end
