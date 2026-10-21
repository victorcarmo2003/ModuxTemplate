--!strict
-- post_figure (< 20, family D from Night 1; owner 2026-10-20, Provisional Q-415): a street post the player is looking at
-- flickers, and when it comes back on a dark figure stands right under its lamp, still, facing the player. Once seen
-- (or after HOLD s) the lamp drops out for a breath of silence and comes back on an empty sidewalk. No verb, no sanity
-- cost, no jumpscare (DEC-256): the click of the lamp and one soft whoosh. Never the Walker's buzz (DEC-123), and the
-- figure is the ink silhouette (Actors.Silhouette), never the Walker's look.
-- LightController owns Material/Color/Enabled of the posts; the flicker only dims (Context.Dim) and restores.
local Workspace = game:GetService("Workspace")
local Actors = require(script.Parent.Parent.Actors)
local Context = require(script.Parent.Parent.Context)

const TAG = "StreetLight"
const CLICK = "post_click" -- SFX-131; never "post_buzz" (DEC-123)
const WHOOSH = "shadow_whoosh" -- SFX-134, very low: the figure leaves with the dark
const CONE = 45 -- degrees: the post is in view
const MIN_RANGE = 25 -- studs: far enough to read as "under that lamp"
const MAX_RANGE = 160
const DIM = 0.92
const HEIGHT = 5.6 -- studs: a little taller than a customer
const TRANSPARENCY = 0.05
const SEEN_CONE = 14 -- degrees: looking at it
const SEEN_TIME = 0.45 -- s in the cone to count as seen
const HOLD = 4 -- s it waits to be seen before the lamp takes it anyway
const DARK = 0.6 -- s of silence with the lamp out before it comes back empty
const STEP = 1 / 20
-- off/on seconds before the reveal: the lamp "struggles" (style guide: Flicker of AST-036)
const LEAD = { 0.1, 0.12, 0.08, 0.1, 0.32 }

type Candidate = { Post: Instance, Lamp: Vector3, Distance: number }

local function lampOf(post: Instance): Vector3?
	const parts = Context.LitParts(post)
	if #parts == 0 then
		return nil
	end
	local sum = Vector3.zero
	for _, part in parts do
		sum += part.Position
	end
	return sum / #parts
end

local function candidates(): { Candidate }
	const out: { Candidate } = {}
	for _, post in Context.Tagged(TAG) do
		const lamp = lampOf(post)
		if lamp then
			const angle, distance = Context.ViewAngle(lamp)
			if angle ~= nil and angle <= CONE and distance >= MIN_RANGE and distance <= MAX_RANGE then
				table.insert(out, { Post = post, Lamp = lamp, Distance = distance })
			end
		end
	end
	return out
end

-- Ground right under the lamp (the post itself and the local character ignored); nil over a drop.
local function groundUnder(post: Instance, lamp: Vector3): Vector3?
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = { post }
	const root = Context.Root()
	if root and root.Parent then
		table.insert(ignore, root.Parent)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	const hit = Workspace:Raycast(lamp, Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else nil
end

const PostFigure: Context.Effect = {
	CanRun = function(_env: Context.Env): boolean
		return #candidates() > 0
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const chosen = Context.Pick(env.Random, candidates(), function(candidate: Candidate): number
			return candidate.Distance
		end)
		if chosen == nil then
			return
		end
		const feet = groundUnder(chosen.Post, chosen.Lamp)
		if feet == nil then
			return
		end
		const parts = Context.LitParts(chosen.Post)
		const lights = Context.Lights(chosen.Post)
		local restore: (() -> ())? = nil
		local function on()
			if restore then
				restore()
				restore = nil
			end
		end
		local function off()
			if restore == nil then
				restore = Context.Dim(parts, lights, DIM)
			end
		end
		run:Cleanup(on)

		-- 1. the lamp struggles
		for index, seconds in LEAD do
			if index % 2 == 1 then
				off()
				if index == 1 then
					env.Sound(CLICK, chosen.Lamp)
				end
			else
				on()
			end
			if not run:Wait(seconds) then
				return
			end
		end

		-- 2. back on: someone is standing under it
		const model = Actors.Silhouette(HEIGHT, TRANSPARENCY)
		run:Cleanup(function()
			model:Destroy()
		end)
		model:PivotTo(Context.FacingCamera(feet))
		model.Parent = Workspace
		on()
		env.Sound(CLICK, chosen.Lamp, { Volume = 0.6 })

		-- 3. it waits to be seen (or HOLD s), facing the player
		const head = feet + Vector3.new(0, HEIGHT * 0.8, 0)
		const started = os.clock()
		local seenFor = 0
		local last = started
		while os.clock() - started < HOLD and seenFor < SEEN_TIME do
			if not run:Wait(STEP) then
				return
			end
			const now = os.clock()
			model:PivotTo(Context.FacingCamera(feet))
			seenFor = if Context.Sees(head, SEEN_CONE, MAX_RANGE + 20, { model, chosen.Post })
				then seenFor + (now - last)
				else 0
			last = now
		end

		-- 4. the lamp takes it: a breath of dark and silence, then the sidewalk is empty
		off()
		env.Sound(CLICK, chosen.Lamp)
		env.Sound(WHOOSH, feet, { Volume = 0.25, Speed = 0.8 })
		model:Destroy()
		if not run:Wait(DARK) then
			return
		end
		on()
	end,
}

return PostFigure
