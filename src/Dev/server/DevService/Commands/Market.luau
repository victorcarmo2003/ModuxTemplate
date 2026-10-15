--!strict
-- Gear Stand commands (Q-203; FEAT-015 v2). Thin wrappers over UpgradeService, same state as play.
--   market          pedestals B1..B5 (upgrade, level, next price, shifts left on cooldown, ON SALE / SOLD OUT) and the counter
--   market reset    every line on sale again (cooldowns cleared)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "market [reset]"

type Upgrades = {
	GetVehicle: (self: any) -> string,
	GetLevel: (self: any, key: string, vehicle: string?) -> number?,
	NextLevel: (self: any, key: string) -> Content.UpgradeLevel?,
	GetWait: (self: any, key: string, vehicle: string?) -> number,
	CooldownReport: (self: any) -> (number, { [string]: number }),
	ResetCooldowns: (self: any) -> (),
}

const Market: Api.Module = function(ctx: Api.Context): { Api.Command }
	const upgrades = ctx.Get("UpgradeService") :: Upgrades

	local function list(): string
		const turn, resting = upgrades:CooldownReport()
		const lines: { string } = { `{upgrades:GetVehicle()} - shift counter {turn}, cooldown {Content.Mart.Cooldown.Turns} shifts` }
		for _, row in Content.Mart.Pedestals do
			local found: Content.Upgrade? = nil
			for _, candidate in Content.Upgrades.List do
				if candidate.BenchSpot == row.Slot and not Content.Mode.IsOff(candidate.Key) then
					found = candidate
				end
			end
			if found == nil then
				table.insert(lines, `{row.Slot}: {row.Offer} (empty)`)
				continue
			end
			const level = upgrades:GetLevel(found.Key)
			const nextRow = upgrades:NextLevel(found.Key)
			const wait = upgrades:GetWait(found.Key)
			const state = if level == nil
				then "TRAILER ONLY"
				elseif nextRow == nil then "MAXED"
				elseif wait > 0 then `SOLD OUT ({wait} left)`
				else "ON SALE"
			table.insert(
				lines,
				`{row.Slot}: {found.Key} lvl {if level == nil then "-" else tostring(level)}`
					.. `{if nextRow then ` next ${nextRow.Price}` else ""} - {state}`
			)
		end
		for name, left in resting do
			table.insert(lines, `cooldown {name}: {left}`)
		end
		return table.concat(lines, "\n")
	end

	return {
		{
			Name = "market",
			Usage = USAGE,
			Help = "Gear Stand: pedestals and cooldowns; 'reset' puts every line back on sale",
			Run = function(args: { string }, _caller: Player?): string?
				const verb = args[1]
				if verb == nil then
					return list()
				elseif verb == "reset" then
					upgrades:ResetCooldowns()
					return "cooldowns cleared: every line on sale"
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Market
