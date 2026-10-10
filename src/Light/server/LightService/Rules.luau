--!strict
-- Pure rule of "is this light group on now" (architecture.md §19.6; FEAT-020; Content.LightGroups). No Instance, no
-- Modux: LightService feeds it the current inputs at every refresh.
--   zone active = night AND group on AND not put out by the Hush (HushOff groups).
--   Always  -> on every night.
--   Switch  -> the party switch is on and group.Vehicle (if any) is the current vehicle.
--   Upgrade -> Switch rule + group.Upgrade level >= 1 on group.Vehicle + a radius > 0 (LightRadius).
--   Posts   -> on every night; the Hush puts them out from its start (client: post by post, Order x Step).
-- Hush on the other HushOff groups (the trailer): dark from the moment the last post goes out (FEAT-020 "do poste
-- da esquina apagar até os postes voltarem") until the Hush ends.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Hush = {
	StartedAt: number, -- server time the first post goes out
	DarkAt: number, -- server time the last post is out: trailer zones go dark
	HoldUntil: number, -- server time the Hush ends by itself; 0 = only EndHush
}

export type Input = {
	Night: boolean,
	Switch: boolean,
	Vehicle: string, -- current vehicle key
	Now: number,
	Hush: Hush?,
	Level: (upgrade: string, vehicle: string) -> number, -- 0 when the upgrade is not on that vehicle
	Radius: (group: Content.LightGroup) -> number, -- LightRadius effect for Upgrade groups
}

const Rules = {}

-- The Hush is putting this group out right now.
function Rules.hushed(group: Content.LightGroup, input: Input): boolean
	const hush = input.Hush
	if hush == nil or not group.HushOff then
		return false
	end
	if group.Kind == "Posts" then
		return true
	end
	return input.Now >= hush.DarkAt
end

function Rules.groupOn(group: Content.LightGroup, input: Input): boolean
	if not input.Night or Rules.hushed(group, input) then
		return false
	end
	const kind = group.Kind
	if kind == "Always" or kind == "Posts" then
		return true
	end
	if not input.Switch then
		return false
	end
	if group.Vehicle ~= nil and group.Vehicle ~= input.Vehicle then
		return false
	end
	if kind == "Switch" then
		return true
	end
	-- Upgrade
	const upgrade = group.Upgrade
	if upgrade == nil then
		return false
	end
	return input.Level(upgrade, group.Vehicle or input.Vehicle) >= 1 and input.Radius(group) > 0
end

-- Delay between the first post going out and the last one (largest Order x Step of the Posts groups).
function Rules.cornerDelay(maxOrder: { [string]: number }): number
	local delay = 0
	for _, group in Content.LightGroups.List do
		if group.Kind == "Posts" and group.HushOff then
			delay = math.max(delay, (maxOrder[group.Key] or 0) * group.Step)
		end
	end
	return delay
end

return Rules
