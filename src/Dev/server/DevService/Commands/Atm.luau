--!strict
-- Night atmosphere (TASK-275 `atmosphere`, renamed 2026-10-18; docs/tech/dev-commands.md). Resolves a name to its
-- ATM-# key and forwards to Parts/Atmosphere.luau (AtmosphereService:Force, every client fades it in).
--   atm                          active key, forced or not, and the key of every night
--   atm <ATM-#|n|name>           forces that atmosphere now ("rain", "red mist", "storm")
--   atm off | auto               no atmosphere / back to the night's own key
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const USAGE = "atm [ATM-#|n|name|off|auto]"

-- a part of an atmosphere name -> its key (unique match), else the word unchanged (the part validates it)
local function keyOf(word: string): string
	const needle = string.lower(word)
	const found: { string } = {}
	for _, row in Content.Atmospheres.List do
		const name = string.lower(row.Name)
		if name == needle then
			return row.Key
		end
		if string.find(name, needle, 1, true) then
			table.insert(found, row.Key)
		end
	end
	if #found == 1 and tonumber(word) == nil then
		return found[1]
	end
	return word
end

const Atm: Api.Module = function(ctx: Api.Context): { Api.Command }
	const atmosphere = Kit.parts(ctx, "Atmosphere").atmosphere

	return {
		{
			Name = "atm",
			Usage = USAGE,
			Help = "forces a night atmosphere on every client (ATM-#, number or name), off, or auto",
			Run = function(args: { string }, caller: Player?): string?
				if #args == 0 then
					return Kit.forward(atmosphere)({}, caller)
				end
				return Kit.forward(atmosphere)({ keyOf(table.concat(args, " ")) }, caller)
			end,
		},
	}
end

return Atm
