--!strict
-- Hide commands (TASK-102; architecture.md §19.14). Goes through the HideService API, so the Hides set, the freeze
-- and Changed behave as in play (no phase, range or hold check: dev only).
--   hide                     who is hidden in which slot
--   hide <slot>              hides the caller in that spot of the current vehicle (taken spot refused)
--   hide up                  gets the caller up (same path as get_up)
--   hide all                 gets everyone up
--   hide zone [point] [r]    InZone of the caller (default point SS, radius 6)
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

const USAGE = "hide [<slot>|up|all|zone [point] [radius]]"
const DEFAULT_POINT = "SS"
const DEFAULT_RADIUS = 6 -- architecture.md §19.14 InZone(p, "SS", 6); the real radius comes from the anomaly rule

type Hides = {
	IsHidden: (self: any, player: Player) -> boolean,
	SlotOf: (self: any, player: Player) -> number?,
	InZone: (self: any, player: Player, pointId: string, radius: number) -> boolean,
	IsLiveSpot: (self: any, anchor: Instance) -> boolean,
	Hide: (self: any, player: Player, anchor: Instance) -> boolean,
	Release: (self: any, player: Player) -> (),
	ReleaseAll: (self: any) -> (),
	Anchors: { [Instance]: boolean },
}

const Hide: Api.Module = function(ctx: Api.Context): { Api.Command }
	const hides = ctx.Get("HideService") :: Hides

	local function status(): string
		const parts: { string } = {}
		for _, player in Players:GetPlayers() do
			const slot = hides:SlotOf(player)
			if slot ~= nil then
				table.insert(parts, `{player.Name}=H{slot}`)
			end
		end
		return if #parts == 0 then "nobody hidden" else table.concat(parts, " ")
	end

	local function needCaller(caller: Player?): Player
		if caller == nil then
			error("needs a caller (run from the chat)", 0)
		end
		return caller
	end

	return {
		{
			Name = "hide",
			Usage = USAGE,
			Help = "hide in a spot of the current vehicle, get up, release all, safe spot check; no args lists hidden",
			Run = function(args: { string }, caller: Player?): string?
				const sub = args[1]
				if sub == nil then
					return status()
				elseif sub == "up" then
					hides:Release(needCaller(caller))
					return status()
				elseif sub == "all" then
					hides:ReleaseAll()
					return status()
				elseif sub == "zone" then
					const player = needCaller(caller)
					const point = args[2] or DEFAULT_POINT
					const radius = if args[3] ~= nil then tonumber(args[3]) else DEFAULT_RADIUS
					if radius == nil or radius ~= radius or radius < 0 then
						error(`invalid radius "{args[3]}"`, 0)
					end
					return `{if hides:InZone(player, point, radius) then "IN" else "OUT"} {point} r={radius}`
				end
				const slot = tonumber(sub)
				if slot == nil then
					error(`usage: {USAGE}`, 0)
				end
				const player = needCaller(caller)
				if hides:IsHidden(player) then
					error("already hidden (hide up first)", 0)
				end
				for anchor in hides.Anchors do
					if anchor:GetAttribute("Slot") == slot and hides:IsLiveSpot(anchor) then
						if not hides:Hide(player, anchor) then
							error(`H{slot} is taken`, 0)
						end
						return status()
					end
				end
				error(`no live spot H{slot} in the current vehicle`, 0)
			end,
		},
	}
end

return Hide
