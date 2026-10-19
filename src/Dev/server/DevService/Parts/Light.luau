--!strict
-- Light commands (TASK-059; architecture.md §19.6). Goes through the LightService API, so the Lights set, the IsLit
-- cache and SwitchChanged behave as in play (no cooldown, no range check: dev only).
--   light                    switch, Hush and every group (On/At)
--   light on | off           party switch (refused during the Hush, like the prompt)
--   light hush [seconds]     Hush from now; with seconds it ends by itself (default: until "light end")
--   light end                ends the Hush
--   light here               IsLit at the caller's character (Command Bar: no caller, refused)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "light [on|off|hush [seconds]|end|here]"

type Lights = {
	IsLit: (self: any, position: Vector3) -> boolean,
	IsSwitchOn: (self: any) -> boolean,
	IsHush: (self: any) -> boolean,
	SetSwitch: (self: any, on: boolean, player: Player?, force: boolean?) -> boolean,
	BeginHush: (self: any, startedAt: number, holdUntil: number) -> (),
	EndHush: (self: any) -> (),
	Records: { [string]: { On: boolean, At: number } },
}

const Light: Api.Module = function(ctx: Api.Context): { Api.Command }
	const lights = ctx.Get("LightService") :: Lights

	local function status(): string
		const parts: { string } = {}
		const now = workspace:GetServerTimeNow()
		for _, group in Content.LightGroups.List do
			const record = lights.Records[group.Key]
			if record then
				table.insert(parts, `{group.Key}={if record.On then "on" else "off"}@{string.format("%.1f", record.At - now)}s`)
			end
		end
		return `switch {if lights:IsSwitchOn() then "on" else "off"}, hush {if lights:IsHush() then "yes" else "no"}; {table.concat(
			parts,
			" "
		)}`
	end

	return {
		{
			Name = "light",
			Usage = USAGE,
			Help = "trailer switch on/off, Hush start/end, IsLit at your character; no args shows the light groups",
			Run = function(args: { string }, caller: Player?): string?
				const sub = args[1]
				if sub == nil then
					return status()
				elseif sub == "on" or sub == "off" then
					if not lights:SetSwitch(sub == "on", caller) then
						error("the switch has no effect during the Hush (light end first)", 0)
					end
					return status()
				elseif sub == "hush" then
					const now = workspace:GetServerTimeNow()
					local holdUntil = 0
					if args[2] ~= nil then
						const seconds = tonumber(args[2])
						if seconds == nil or seconds <= 0 or seconds ~= seconds then
							error(`invalid seconds "{args[2]}"`, 0)
						end
						holdUntil = now + seconds
					end
					lights:BeginHush(now, holdUntil)
					return status()
				elseif sub == "end" then
					lights:EndHush()
					return status()
				elseif sub == "here" then
					const character = if caller then caller.Character else nil
					const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
					if root == nil or not root:IsA("BasePart") then
						error("needs a caller with a character", 0)
					end
					const position = root.Position
					return `{if lights:IsLit(position) then "LIT" else "DARK"} at {string.format(
						"(%.1f, %.1f, %.1f)",
						position.X,
						position.Y,
						position.Z
					)}`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Light
