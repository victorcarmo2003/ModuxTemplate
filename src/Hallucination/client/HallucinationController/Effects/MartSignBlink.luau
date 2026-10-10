--!strict
-- mart_sign_blink (< 20; script.md §8, AST-028 `Sign_Open24`, sound-list.md SFX-133): the Mart's "OPEN 24 HOURS"
-- (the safe spot, "it never goes out") blinks ONCE on this client. Only when the sign is in view. Dims the neon
-- tubes and `Light_Sign` locally (Context.Dim) and restores; the neon click `neon_click` has no key yet (Q-168).
local Workspace = game:GetService("Workspace")
local Context = require(script.Parent.Parent.Context)

const SIGN_NAME = "Sign_Open24"
const LIGHT_NAME = "Light_Sign"
const KEY = "neon_click" -- SFX-133
const CONE = 50 -- degrees
const RANGE = 250 -- studs
const OFF_TIME = 0.4 -- s (sound-list: 0.4 s)
const DIM = 0.95
const RESCAN = 15 -- s: the Workspace walk is cached (rolls are rare, but the map is big)

local cached: { Instance } = {}
local scannedAt = -math.huge

local function signs(): { Instance }
	if os.clock() - scannedAt < RESCAN then
		return cached
	end
	scannedAt = os.clock()
	const out: { Instance } = {}
	for _, descendant in Workspace:GetDescendants() do
		if descendant.Name == SIGN_NAME and (descendant:IsA("BasePart") or descendant:IsA("Model")) then
			table.insert(out, descendant)
		end
	end
	cached = out
	return out
end

-- The sign in view, its lit parts and its lights (Light_Sign beside it, under the same model).
local function target(): (Instance?, { BasePart }, { Light })
	for _, sign in signs() do
		const at = if sign:IsDescendantOf(Workspace) then Context.PositionOf(sign) else nil
		if at then
			const angle, distance = Context.ViewAngle(at)
			const parts = Context.LitParts(sign)
			if angle ~= nil and angle <= CONE and distance <= RANGE and #parts > 0 then
				const lights = Context.Lights(sign)
				const parent = sign.Parent
				if parent then
					for _, descendant in parent:GetDescendants() do
						if descendant:IsA("Light") and descendant.Parent and descendant.Parent.Name == LIGHT_NAME then
							table.insert(lights, descendant)
						end
					end
				end
				return sign, parts, lights
			end
		end
	end
	return nil, {}, {}
end

const MartSignBlink: Context.Effect = {
	CanRun = function(_env: Context.Env): boolean
		return (target()) ~= nil
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const sign, parts, lights = target()
		if sign == nil then
			return
		end
		const restore = Context.Dim(parts, lights, DIM)
		run:Cleanup(restore)
		const at = Context.PositionOf(sign)
		if at then
			env.Sound(KEY, at)
		end
		run:Wait(OFF_TIME)
	end,
}

return MartSignBlink
