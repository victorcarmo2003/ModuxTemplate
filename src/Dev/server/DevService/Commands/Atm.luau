--!strict
-- Night atmosphere (TASK-275 `atmosphere`, renamed 2026-10-18; docs/tech/dev-commands.md). Resolves a name to its
-- ATM-# key and forwards to Parts/Atmosphere.luau (AtmosphereService:Force, every client fades it in).
--   atm                          active key, forced or not, and the key of every night
--   atm <ATM-#|n|name>           forces that atmosphere now ("rain", "red mist", "storm")
--   atm off | auto               no atmosphere / back to the night's own key
--   bolt [near|far]              one forced lightning strike on every client (AtmosphereService:Strike; default far).
--                                near = the scare: bright flash, thunder at once, camera jolt. Needs an atmosphere on
--                                (night, or `atm <key>` during the day)
--   shower [seconds|off]         forces a rain shower now on every client (default 45 s), opening with its thunder
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const USAGE = "atm [ATM-#|n|name|off|auto]"

type Atmospheres = {
	Get: (self: any) -> string?,
	Strike: (self: any, near: boolean) -> (),
	Shower: (self: any, length: number) -> (),
}

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
	const service = ctx.Get("AtmosphereService") :: Atmospheres

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
		{
			Name = "bolt",
			Usage = "bolt [near|far]",
			Help = "one lightning strike on every client: far (flash + late thunder) or near (the scare)",
			Run = function(args: { string }, _caller: Player?): string?
				const word = string.lower(args[1] or "far")
				if word ~= "near" and word ~= "far" then
					return "usage: bolt [near|far]"
				end
				service:Strike(word == "near")
				const key = service:Get()
				return if key
					then `{word} strike sent ({key})`
					else `{word} strike sent, but no atmosphere is on: nothing shows (atm <key> first)`
			end,
		},
		{
			Name = "shower",
			Usage = "shower [seconds|off]",
			Help = "forces a rain shower now on every client (default 45 s), opening with a loud thunder clap; off stops it",
			Run = function(args: { string }, _caller: Player?): string?
				const word = string.lower(args[1] or "45")
				const length = if word == "off" or word == "stop" then 0 else tonumber(word)
				if length == nil then
					return "usage: shower [seconds|off]"
				end
				service:Shower(length)
				const key = service:Get()
				if length == 0 then
					return "shower stopped"
				end
				return if key
					then `shower for {length} s ({key})`
					else `shower for {length} s, but no atmosphere is on: nothing shows (atm <key> first)`
			end,
		},
	}
end

return Atm
