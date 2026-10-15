--!strict
-- monster_glimpse (< 20, family D; anomalies-v2-proposal.md §3 D; DEC-254, DEC-256): a monster stands at the far end
-- of the street, in the corner of the view, and is gone the moment the player looks straight at it. No verb, no
-- damage, no sound, no jumpscare; it only sets up family B ("something is out there").
--   * spawns on a MapPoint MIN..MAX studs away, at the EDGE of the view (MinAngle..MaxAngle), in clear line;
--   * gone as soon as it sits within DIRECT degrees of the look, when the player gets closer than CLOSE, or after
--     LIFETIME (the player may never notice it: that is fine).
-- Asset: ReplicatedStorage.Assets...Monster_Glimpse when it exists (pivot at the feet, facing -Z; the family B
-- monsters can be dropped in here later). Until then a cartoon placeholder: tall, thin, hunched, long arms, dark
-- plum (#1E1A2B), two round pale eyes; no hat and not the Walker's #14162A (the Walker stays family B's).
local Workspace = game:GetService("Workspace")
local Context = require(script.Parent.Parent.Context)

const ASSET_NAME = "Monster_Glimpse"
const COLOR = Color3.fromHex("#1E1A2B")
const EYES = Color3.fromHex("#F2E6B8")
const HEIGHT = 9 -- studs (placeholder)
const QUERY: Context.SpotQuery = {
	MinDistance = 70,
	MaxDistance = 220,
	MinAngle = 22, -- the edge of the view: seen out of the corner of the eye
	MaxAngle = 42,
	Height = HEIGHT * 0.8,
}
const DIRECT = 9 -- degrees: looked straight at -> gone
const CLOSE = 50 -- studs
const LIFETIME = 9 -- s
const STEP = 1 / 30

local function placeholder(): Model
	const model = Instance.new("Model")
	model.Name = ASSET_NAME
	const legs = Context.Prop("Legs", Vector3.new(1.2, 4, 0.8), COLOR)
	legs.CFrame = CFrame.new(0, 2, 0)
	legs.Parent = model
	const body = Context.Prop("Body", Vector3.new(1.8, 3.4, 1.1), COLOR)
	body.CFrame = CFrame.new(0, 5.4, -0.25) * CFrame.Angles(math.rad(-14), 0, 0) -- hunched forward
	body.Parent = model
	const head = Context.Prop("Head", Vector3.new(1.9, 1.9, 1.9), COLOR, Enum.PartType.Ball)
	head.CFrame = CFrame.new(0, 7.7, -0.75)
	head.Parent = model
	for _, x in { -1.25, 1.25 } do
		const arm = Context.Prop("Arm", Vector3.new(0.45, 5.2, 0.45), COLOR)
		arm.CFrame = CFrame.new(x, 4.3, -0.4) * CFrame.Angles(math.rad(-8), 0, math.rad(if x < 0 then -6 else 6))
		arm.Parent = model
	end
	for _, x in { -0.4, 0.4 } do
		const eye = Context.Prop("Eye", Vector3.new(0.5, 0.5, 0.5), EYES, Enum.PartType.Ball)
		eye.Material = Enum.Material.Neon
		eye.CFrame = CFrame.new(x, 7.85, -1.55)
		eye.Parent = model
	end
	model.PrimaryPart = legs
	model.WorldPivot = CFrame.new()
	return model
end

const MonsterGlimpse: Context.Effect = {
	CanRun = function(_env: Context.Env): boolean
		return #Context.FarSpots(QUERY) > 0
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const spots = Context.FarSpots(QUERY)
		if #spots == 0 then
			return
		end
		const feet = spots[env.Random:NextInteger(1, #spots)].Position
		const model = Context.Asset(ASSET_NAME, placeholder)
		run:Cleanup(function()
			model:Destroy()
		end)
		model:PivotTo(Context.FacingCamera(feet))
		model.Parent = Workspace
		const head = feet + Vector3.new(0, QUERY.Height, 0)
		const started = os.clock()
		while os.clock() - started < LIFETIME do
			const angle, distance = Context.ViewAngle(head)
			if angle == nil or angle <= DIRECT or distance < CLOSE then
				return -- looked at (or too close): gone
			end
			if not run:Wait(STEP) then
				return
			end
		end
	end,
}

return MonsterGlimpse
