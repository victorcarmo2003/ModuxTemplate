--!strict
-- night_opening (Scripted; owner 2026-10-20, Provisional Q-415; horror-cinematic.md crescendo): the first ~40 s of
-- Night 1, played once for everyone as the Night phase starts (Nights.Opening, AnomalyService). No verb, no sanity cost,
-- no jumpscare (DEC-256): it only tells the player "tonight is different" before the first anomaly.
--   0   silence (BEAT s): the street as it is
--   1   the street posts go out one by one, from the far end towards the player, a breath of dark, back on near to far
--   2   a dark figure stands still across the street at the edge of the view; once the player has looked at it and
--       turned away, it is gone when the camera comes back (never seen within FIGURE_LIFE s: removed quietly)
--   3   the phone line crackles: Walt's voice cut by static (subtitle only, English placeholder until ui-text.md)
--   4   a held breath (breath_held) closes it
-- LightController owns the posts' Material/Color/Enabled: only Context.Dim (restored on cleanup). Never the post buzz
-- (DEC-123). Lines are original, short and Mild.
local Workspace = game:GetService("Workspace")
local Actors = require(script.Parent.Parent.Actors)
local Context = require(script.Parent.Parent.Context)

const TAG = "StreetLight"
const CLICK = "post_click"
const BREATH = "breath_held"
const SPEAKER = "Walt"
const BEAT = 2.5 -- s of silence first
const POST_RANGE = 220 -- studs
const POST_MAX = 8 -- the nearest posts only: the cascade stays ~2 s (the street has ~35)
const POST_STEP = 0.22 -- s between two posts going out
const POST_DARK = 1.4 -- s all out (silence)
const POST_BACK = 0.12 -- s between two posts coming back
const DIM = 0.92
const FIGURE_AT = 2 -- s after the posts are back
const FIGURE_LIFE = 24 -- s
const FIGURE_HEIGHT = 5.4
const FIGURE_QUERY: Context.SpotQuery = {
	MinDistance = 30,
	MaxDistance = 95,
	MinAngle = 20, -- at the edge of the view: found, not shown
	MaxAngle = 80,
	Height = FIGURE_HEIGHT * 0.8,
}
-- no map point fits (inside the restaurant, a wall in the way): the figure stands under a street lamp instead
const LAMP_MIN = 30
const LAMP_MAX = 140
const SEEN_CONE = 22
const SEEN_TIME = 0.6
const AWAY_TIME = 0.5
const CALL_AT = 9 -- s after the figure appeared
const LINES = {
	{ Text = "Rookie? ...one more thing about the lamps—", Time = 2 },
	{ Text = "...if one of them... ksshh... don't wave back.", Time = 2.4 },
}
const END_PAUSE = 1.5
const STEP = 0.1

type Post = { Instance: Instance, Distance: number, Restore: (() -> ())? }

local function posts(): { Post }
	const out: { Post } = {}
	for _, post in Context.Tagged(TAG) do
		const at = Context.PositionOf(post)
		if at and #Context.LitParts(post) > 0 then
			const _, distance = Context.ViewAngle(at)
			if distance <= POST_RANGE then
				table.insert(out, { Instance = post, Distance = distance })
			end
		end
	end
	table.sort(out, function(a: Post, b: Post): boolean
		return a.Distance < b.Distance
	end)
	while #out > POST_MAX do
		table.remove(out)
	end
	-- far end first: the dark walks towards the player
	const ordered: { Post } = {}
	for index = #out, 1, -1 do
		table.insert(ordered, out[index])
	end
	return ordered
end

local function flickerPosts(env: Context.Env, run: Context.Run): boolean
	const list = posts()
	run:Cleanup(function()
		for _, post in list do
			if post.Restore then
				post.Restore()
				post.Restore = nil
			end
		end
	end)
	for index, post in list do
		post.Restore = Context.Dim(Context.LitParts(post.Instance), Context.Lights(post.Instance), DIM)
		if index % 2 == 1 then
			env.Sound(CLICK, post.Instance, { Volume = 0.7 })
		end
		if not run:Wait(POST_STEP) then
			return false
		end
	end
	if not run:Wait(POST_DARK) then
		return false
	end
	for index = #list, 1, -1 do
		const post = list[index]
		if post.Restore then
			post.Restore()
			post.Restore = nil
		end
		if not run:Wait(POST_BACK) then
			return false
		end
	end
	return true
end

-- Ground under a lit street lamp LAMP_MIN..LAMP_MAX studs away with a clear line to the figure's head; nil = none.
local function lampSpot(env: Context.Env): Vector3?
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	const found: { Vector3 } = {}
	for _, post in Context.Tagged(TAG) do
		const parts = Context.LitParts(post)
		if #parts == 0 then
			continue
		end
		const lamp = parts[1].Position
		const _, distance = Context.ViewAngle(lamp)
		if distance < LAMP_MIN or distance > LAMP_MAX then
			continue
		end
		const ignore: { Instance } = { post }
		const root = Context.Root()
		if root and root.Parent then
			table.insert(ignore, root.Parent)
		end
		params.FilterDescendantsInstances = ignore
		const hit = Workspace:Raycast(lamp, Vector3.new(0, -40, 0), params)
		if hit and Context.Sees(hit.Position + Vector3.new(0, FIGURE_QUERY.Height, 0), 180, LAMP_MAX + 10, { post }) then
			table.insert(found, hit.Position)
		end
	end
	return if #found > 0 then found[env.Random:NextInteger(1, #found)] else nil
end

-- The figure across the street; returns when it is gone (seen and lost, or FIGURE_LIFE s).
local function figure(env: Context.Env, run: Context.Run)
	const spots = Context.FarSpots(FIGURE_QUERY)
	const feet = if #spots > 0 then spots[env.Random:NextInteger(1, #spots)].Position else lampSpot(env)
	if feet == nil then
		return
	end
	const model = Actors.Silhouette(FIGURE_HEIGHT, 0.05)
	run:Cleanup(function()
		model:Destroy()
	end)
	model:PivotTo(Context.FacingCamera(feet))
	model.Parent = Workspace
	const head = feet + Vector3.new(0, FIGURE_QUERY.Height, 0)
	const started = os.clock()
	local last = started
	local seenFor, awayFor = 0, 0
	local seen = false
	while os.clock() - started < FIGURE_LIFE do
		if not run:Wait(STEP) or model.Parent == nil then
			return
		end
		const now = os.clock()
		const dt = now - last
		last = now
		model:PivotTo(Context.FacingCamera(feet))
		const inView = Context.Sees(head, SEEN_CONE, FIGURE_QUERY.MaxDistance + 10, { model })
		if not seen then
			seenFor = if inView then seenFor + dt else 0
			seen = seenFor >= SEEN_TIME
		else
			awayFor = if inView then 0 else awayFor + dt
			if awayFor >= AWAY_TIME then
				break -- the camera comes back to an empty sidewalk
			end
		end
	end
	model:Destroy()
end

local function call(env: Context.Env, run: Context.Run)
	if not env.CallIdle() then
		return
	end
	const host = env.Vehicle()
	run:Cleanup(function()
		env.Subtitle(SPEAKER, "")
	end)
	-- owner 2026-10-22 ("o áudio do phone glitch toca parece que duas vezes, deixa somente uma vez"): ONE glitch as
	-- the line opens (Context.Glitch, cut in the middle); it played before each line and again at the end
	for index, line in LINES do
		if not env.CallIdle() then
			break
		end
		if index == 1 then
			Context.Glitch(env, host, { Volume = 0.5 })
		end
		env.Subtitle(SPEAKER, line.Text)
		if not run:Wait(line.Time) then
			return
		end
	end
	env.Subtitle(SPEAKER, "")
end

const NightOpening: Context.Effect = {
	Play = function(env: Context.Env, run: Context.Run)
		if not run:Wait(BEAT) then
			return
		end
		if not flickerPosts(env, run) then
			return
		end
		if not run:Wait(FIGURE_AT) then
			return
		end
		local figureDone = false
		task.spawn(function()
			figure(env, run)
			figureDone = true
		end)
		if not run:Wait(CALL_AT) then
			return
		end
		call(env, run)
		-- the figure may still be standing there: the opening ends with it
		while not figureDone do
			if not run:Wait(STEP) then
				return
			end
		end
		if not run:Wait(END_PAUSE) then
			return
		end
		env.Sound(BREATH, nil, { Volume = 0.3 })
	end,
}

return NightOpening
