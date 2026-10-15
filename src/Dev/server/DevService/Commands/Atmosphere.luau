--!strict
-- Atmosphere commands (TASK-275; DEC-257). Goes through AtmosphereService:Force, so every client fades it in like a
-- night start. The force stays across phases until "atmosphere auto".
--   atmosphere                 active key, forced or not, and the key of every night
--   atmosphere <ATM-n | n>     forces that atmosphere now (day or night)
--   atmosphere off             forces no atmosphere
--   atmosphere auto            back to the night's own key (nil during the day)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "atmosphere [ATM-n|n|off|auto]"

type Atmospheres = {
	Get: (self: any) -> string?,
	IsForced: (self: any) -> boolean,
	KeyFor: (self: any, night: number) -> string,
	Force: (self: any, key: string?) -> (),
}

const Atmosphere: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("AtmosphereService") :: Atmospheres

	local function status(): string
		const nights: { string } = {}
		for night = 1, Content.RunParams.Nights do
			table.insert(nights, `{night}={service:KeyFor(night)}`)
		end
		const key = service:Get()
		const row = if key then Content.Atmospheres.ByKey[key] else nil
		return `atmosphere {key or "none"}{if row then ` ({row.Name})` else ""}{if service:IsForced()
			then " [forced]"
			else ""}; nights {table.concat(nights, " ")}`
	end

	return {
		{
			Name = "atmosphere",
			Usage = USAGE,
			Help = "forces a night atmosphere (ATM-1..ATM-7) on every client, off, or auto (the night's own)",
			Run = function(args: { string }, _caller: Player?): string?
				const arg = args[1]
				if arg == nil then
					return status()
				end
				const word = string.lower(arg)
				if word == "auto" then
					service:Force(nil)
				elseif word == "off" or word == "none" then
					service:Force("")
				else
					const number = tonumber(word) or tonumber(string.match(word, "^atm%-(%d+)$") or "")
					const key = if number then `ATM-{number}` else string.upper(arg)
					if Content.Atmospheres.ByKey[key] == nil then
						error(`unknown atmosphere "{arg}" ({table.concat(Content.Atmospheres.Keys, ", ")})`, 0)
					end
					service:Force(key)
				end
				return status()
			end,
		},
	}
end

return Atmosphere
