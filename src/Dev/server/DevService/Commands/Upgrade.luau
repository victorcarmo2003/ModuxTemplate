--!strict
-- Upgrade level command (board TASK-035 note / TASK-036). Free level change on the current vehicle, for testing the
-- bench, the pieces and the effects without cash. Goes through UpgradeService:SetLevel, so the Upgrades set, the
-- pieces and the Changed signal behave as after a purchase (no Spend, no "upgrade_bought" notice).
--   upgrade                  list every upgrade with its level on the current vehicle
--   upgrade <key>            next level (refused when maxed or not on this vehicle)
--   upgrade <key> <level>    exact level, must be a row of Content.Upgrades on the current vehicle
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "upgrade [key] [level]"

type Upgrades = {
	GetVehicle: (self: any) -> string,
	GetLevel: (self: any, key: string, vehicle: string?) -> number?,
	NextLevel: (self: any, key: string) -> Content.UpgradeLevel?,
	SetLevel: (self: any, vehicle: string, key: string, level: number) -> (),
}

local function hasRow(upgrade: Content.Upgrade, vehicle: string, level: number): boolean
	for _, row in upgrade.Levels[vehicle] or {} do
		if row.Level == level then
			return true
		end
	end
	return false
end

const Upgrade: Api.Module = function(ctx: Api.Context): { Api.Command }
	const upgrades = ctx.Get("UpgradeService") :: Upgrades

	local function list(): string
		const vehicle = upgrades:GetVehicle()
		const parts: { string } = {}
		for _, upgrade in Content.Upgrades.List do
			const level = upgrades:GetLevel(upgrade.Key)
			const off = if Content.Mode.IsOff(upgrade.Key) then " (off)" else ""
			table.insert(parts, `{upgrade.Key}={if level == nil then "-" else tostring(level)}{off}`)
		end
		return `{vehicle}: {table.concat(parts, " ")}`
	end

	return {
		{
			Name = "upgrade",
			Usage = USAGE,
			Help = "free upgrade level on the current vehicle (next level, or an exact one); no key lists the levels",
			Run = function(args: { string }, _caller: Player?): string?
				const key = args[1]
				if key == nil then
					return list()
				end
				const upgrade = Content.Upgrades.ByKey[key]
				if upgrade == nil then
					error(`unknown upgrade "{key}" (keys: {table.concat(Content.Upgrades.Keys, ", ")})`, 0)
				end
				const vehicle = upgrades:GetVehicle()
				const before = upgrades:GetLevel(key)
				if before == nil then
					error(`{key} does not exist on {vehicle}`, 0)
				end
				local target: number
				if args[2] ~= nil then
					const value = tonumber(args[2])
					if value == nil or value ~= math.floor(value) or not hasRow(upgrade, vehicle, value) then
						error(`{key} on {vehicle} has no level "{args[2]}"`, 0)
					end
					target = value
				else
					const nextRow = upgrades:NextLevel(key)
					if nextRow == nil then
						error(`{key} is maxed on {vehicle} (level {before})`, 0)
					end
					target = nextRow.Level
				end
				upgrades:SetLevel(vehicle, key, target)
				return `{key} on {vehicle}: {before} -> {target}`
			end,
		},
	}
end

return Upgrade
