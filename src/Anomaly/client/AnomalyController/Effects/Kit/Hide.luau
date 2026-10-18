--!strict
--[[
	V2 family B "something is coming", client side (DEC-254, DEC-255, DEC-256; TASK-272; anomalies-v2-proposal.md
	§3 B; server: AnomalyService/Anomalies/Kit/Hide.luau). One kit for every family B monster; Effects/<Ref>.luau is
	a thin call to Hide.Effect. Presentation only (T10): the hiding test and the faint are the server's.

	Cues:
	  hide_warn     the warning, ONE sign per monster (TASK-339, owner 2026-10-15: Walt no longer shouts "Hide!" every
	                time; each sign is explained once in the debut call, Content.BossCalls):
	                  Buzz     (Walker)  the trailer lights flicker and buzz, heavy steps come closer, and the
	                                     "hide" words whispered on screen (Kit/Whispers, owner 2026-10-16)
	                  Scratch  (crawler) fast scratching under the trailer, low rumble, no light change
	                  Whisper  (grin)    SILENT: only "hide" words whispered on screen (Kit/Whispers)
	                  Roof     (roof walker) slow heavy steps on the trailer roof
	                A player watching the security cameras is cut back to the head first (Kit/Watch, TASK-337).
	  monster_pass  the pass starts (also the record turning Active): the monster is built and walks its path.
	  jumpscare     Entity = UserId % 65536 of a player caught outside the HideZone: only that client shows the
	                cartoon face (Effects/Kit/Jumpscare, API unchanged).
	Record:
	  Signal        nothing in the world yet (the warning is the cue).
	  Active/Failed the monster passes: Approach s from the start of the street to the window, Look s leaning on the
	                window looking inside, Leave s to the other end of the street. A late joiner joins the pass where
	                it is (pass clock = when this client saw it begin).
	  Resolved/end  the monster fades out and is destroyed.

	Path (2-4 points): MapPoints HIDE-START, HIDE-WINDOW and HIDE-EXIT when the place has them; else derived from the
	trailer pose TRL (window side = towards WALKER-10, across the street; else the pose's LookVector): start and exit
	ON_STREET studs out and SIDE studs to each side, window spot WINDOW_OUT studs out. Feet at the height of TRL.

	PROVISIONAL (frontend-coder, TASK-272): placeholder monsters made of Parts, original, cartoon and Mild (DEC-172,
	DEC-256: dark rounded shapes, big white eyes, no blood, no alert red). A Model named Options.Asset anywhere under
	ReplicatedStorage.Assets (pivot at the feet, facing -Z) replaces the drawing when the art exists.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Parent.Effect)
local Jumpscare = require(script.Parent.Jumpscare)
local Watch = require(script.Parent.Watch)
local Whispers = require(script.Parent.Whispers)


export type Style = "Walk" | "Crawl" | "Grin" | "Roof"
-- the warning sign of the monster (TASK-339)
export type Signal = "Buzz" | "Scratch" | "Whisper" | "Roof"

export type Options = {
	Ref: string,
	Style: Style,
	Signal: Signal,
	Asset: string?, -- Model under ReplicatedStorage.Assets that replaces the placeholder
	-- seconds of the pass; Approach ~ server LookFrom, Approach + Look ~ server LookTo (Rules/<Ref>, Provisional)
	Approach: number,
	Look: number,
	Leave: number,
	-- TASK-483: a path of its own instead of the street (the crawler in the restaurant kitchen): MapPoints
	-- { from, to } of a straight line; it comes in Extend studs before `from`, rears up at the middle facing the
	-- MapPoint Face, and leaves Extend studs past `to`. Missing points = the street path.
	Path: { string }?,
	Extend: number?,
	Face: string?,
}

const ENTITY_MOD = 65536
const TRAILER_POINT = "TRL"
const ACROSS_POINT = "WALKER-10" -- across the street from the window (MAP-01 §5.6)
const START_POINT = "HIDE-START"
const WINDOW_POINT = "HIDE-WINDOW"
const EXIT_POINT = "HIDE-EXIT"
const WINDOW_OUT = 9 -- studs from the trailer pivot to the window spot (window wall ~6 out, MAP-01 TRL)
const ON_STREET = 24 -- studs out to the street lane
const SIDE = 34 -- studs to each side where the pass starts and ends
const ROOF_HEIGHT = 11 -- studs above the trailer pivot (floor +2, ~9 inside)
const LEAN = math.rad(14) -- forward lean while it looks in

const WARN_FLICKER = { 0.12, 0.08, 0.2, 0.1, 0.3, 0.12, 0.15, 0.25, 0.1, 0.4, 0.12, 0.2 } -- off/on/off... s
const FLICKER_GROUPS = { "trailer_interior", "trailer_lights" }
const LAMP_OFF_COLOR = Color3.fromHex("#EAD6B0")
const RUMBLE_KEYS = { "hide_rumble", "horror_dramatic" } -- first key Content.Sounds has
const BUZZ_KEY = "post_buzz"
const SCRATCH_KEYS = { "crawler_scratch", "floor_scratch", "shadow_whoosh" } -- first key Content.Sounds has
const SCRATCH_COUNT = 14 -- quick scratches over the warning
const SCRATCH_SPEED = 1.7
const APPROACH_STEPS = 6 -- heavy steps of the Walker coming closer
const ROOF_STEPS = 7
const UNDER_DROP = 3 -- studs below the trailer pivot where the scratches sound
const STEP_KEY = "walker_step"
const ROOF_STEP_KEY = "roof_step"
const LOOK_KEY = "shadow_whoosh"
const STEP_EVERY = 0.55 -- s between two footsteps
const WARN_FOR = 8 -- s the sign lasts when the cue row has no Duration
const FADE_OUT = 0.6

const INK = Color3.fromHex("#2B2233")
const BODY = Color3.fromHex("#1E1A2B")
const EYE = Color3.fromHex("#F4F1E8")
const TOOTH = Color3.fromHex("#FFFFFF")

type Path = { Start: Vector3, Window: CFrame, Exit: Vector3, Roof: Vector3 }

type Pass = {
	Model: Model,
	Path: Path,
	StartedAt: number, -- os.clock of the pass start on this client
	LastStep: number,
	Looked: boolean,
	Connection: RBXScriptConnection?,
	Done: boolean,
}

const Hide = {}

-- Small helpers -------------------------------------------------------------------------------------------------

local function smooth(t: number): number
	const x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function flat(vector: Vector3): Vector3
	const out = Vector3.new(vector.X, 0, vector.Z)
	return if out.Magnitude < 1e-3 then Vector3.new(0, 0, -1) else out.Unit
end

local function facing(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + flat(direction))
end

local function firstSound(keys: { string }): string?
	for _, key in keys do
		if Content.Sounds.ByKey[key] ~= nil then
			return key
		end
	end
	return nil
end

-- Path --------------------------------------------------------------------------------------------------------------

-- Options.Path (TASK-483): a line between two MapPoints, extended at both ends; the look spot at its middle.
local function linePath(ctx: Effect.Context, options: Options): Path?
	const ids = options.Path
	if ids == nil or #ids < 2 then
		return nil
	end
	const from, to = ctx.Point(ids[1]), ctx.Point(ids[2])
	if from == nil or to == nil then
		return nil
	end
	const along = flat(to.Position - from.Position)
	const extend = options.Extend or 0
	const middle = from.Position:Lerp(to.Position, 0.5)
	const face = if options.Face ~= nil then ctx.Point(options.Face) else nil
	const look = if face ~= nil then face.Position - middle else along:Cross(Vector3.yAxis)
	return {
		Start = from.Position - along * extend,
		Window = facing(middle, look),
		Exit = to.Position + along * extend,
		Roof = middle + Vector3.new(0, ROOF_HEIGHT, 0),
	}
end

local function pathOf(ctx: Effect.Context, options: Options?): Path?
	if options ~= nil then
		const line = linePath(ctx, options)
		if line ~= nil then
			return line
		end
	end
	const trailer = ctx.Point(TRAILER_POINT)
	if trailer == nil then
		return nil
	end
	const across = ctx.Point(ACROSS_POINT)
	const out = if across ~= nil then flat(across.Position - trailer.Position) else flat(trailer.LookVector)
	const side = out:Cross(Vector3.yAxis).Unit
	const base = trailer.Position
	const startPoint = ctx.Point(START_POINT)
	const windowPoint = ctx.Point(WINDOW_POINT)
	const exitPoint = ctx.Point(EXIT_POINT)
	const windowPosition = if windowPoint ~= nil then windowPoint.Position else base + out * WINDOW_OUT
	return {
		Start = if startPoint ~= nil then startPoint.Position else base + out * ON_STREET + side * SIDE,
		-- faces the trailer (into the window)
		Window = facing(windowPosition, -out),
		Exit = if exitPoint ~= nil then exitPoint.Position else base + out * ON_STREET - side * SIDE,
		Roof = base + Vector3.new(0, ROOF_HEIGHT, 0) - out * 4,
	}
end

-- Placeholder bodies (feet at the origin, facing -Z) -----------------------------------------------------------------

local function part(model: Model, name: string, shape: Enum.PartType, size: Vector3, at: CFrame, color: Color3): Part
	const piece = Instance.new("Part")
	piece.Name = name
	piece.Shape = shape
	piece.Size = size
	piece.CFrame = at
	piece.Color = color
	piece.Material = if color == EYE or color == TOOTH then Enum.Material.Neon else Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = color ~= EYE
	piece.Parent = model
	return piece
end

local function eyes(model: Model, head: CFrame, radius: number, size: number)
	for _, x in { -1, 1 } do
		part(
			model,
			"Eye",
			Enum.PartType.Ball,
			Vector3.one * size,
			head * CFrame.new(x * radius * 0.42, radius * 0.15, -radius * 0.82),
			EYE
		)
	end
end

local function grin(model: Model, head: CFrame, radius: number)
	const width = radius * 1.3
	part(model, "Mouth", Enum.PartType.Block, Vector3.new(width, radius * 0.32, 0.3), head * CFrame.new(0, -radius * 0.38, -radius * 0.9), INK)
	const teeth = 6
	for index = 1, teeth do
		const x = (index - (teeth + 1) / 2) * (width / teeth)
		part(
			model,
			"Tooth",
			Enum.PartType.Block,
			Vector3.new(width / teeth * 0.7, radius * 0.18, 0.2),
			head * CFrame.new(x, -radius * 0.3, -radius * 0.98),
			TOOTH
		)
	end
end

local function buildWalk(model: Model)
	-- tall dark figure (the Walker's long coat and wide hat), round head with two white eyes
	part(model, "Coat", Enum.PartType.Block, Vector3.new(2.6, 5, 1.6), CFrame.new(0, 2.5, 0), BODY)
	part(model, "Shoulders", Enum.PartType.Cylinder, Vector3.new(1.8, 1.8, 3.2), CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(90), 0), BODY)
	const head = CFrame.new(0, 6.3, 0)
	part(model, "Head", Enum.PartType.Ball, Vector3.one * 1.9, head, BODY)
	eyes(model, head, 0.95, 0.42)
	part(model, "Brim", Enum.PartType.Cylinder, Vector3.new(0.15, 3.4, 3.4), CFrame.new(0, 7.1, 0) * CFrame.Angles(0, 0, math.rad(90)), INK)
	part(model, "Crown", Enum.PartType.Cylinder, Vector3.new(1, 1.7, 1.7), CFrame.new(0, 7.6, 0) * CFrame.Angles(0, 0, math.rad(90)), INK)
end

local function buildCrawl(model: Model)
	-- long low body on four thin legs, round head in front
	part(model, "Body", Enum.PartType.Cylinder, Vector3.new(4.2, 1.6, 1.6), CFrame.new(0, 1.7, 0.4) * CFrame.Angles(0, math.rad(90), 0), BODY)
	for _, x in { -0.7, 0.7 } do
		for _, z in { -1.3, 1.9 } do
			part(model, "Leg", Enum.PartType.Block, Vector3.new(0.35, 1.8, 0.35), CFrame.new(x, 0.9, z) * CFrame.Angles(0, 0, x * 0.4), BODY)
		end
	end
	const head = CFrame.new(0, 2.2, -2.2)
	part(model, "Head", Enum.PartType.Ball, Vector3.one * 1.8, head, BODY)
	eyes(model, head, 0.9, 0.5)
end

local function buildGrin(model: Model)
	-- a huge round face that fills the service window
	const head = CFrame.new(0, 6.5, 0)
	part(model, "Head", Enum.PartType.Ball, Vector3.one * 7, head, BODY)
	eyes(model, head, 3.5, 1.5)
	grin(model, head, 3.5)
	part(model, "Neck", Enum.PartType.Block, Vector3.new(1.6, 3.5, 1.6), CFrame.new(0, 1.75, 0), BODY)
end

local function buildRoof(model: Model)
	-- thin long-limbed figure, low round head
	part(model, "Body", Enum.PartType.Block, Vector3.new(1.4, 3.2, 1), CFrame.new(0, 3.9, 0), BODY)
	for _, x in { -0.45, 0.45 } do
		part(model, "Leg", Enum.PartType.Block, Vector3.new(0.4, 2.4, 0.4), CFrame.new(x, 1.2, 0), BODY)
	end
	for _, x in { -1, 1 } do
		part(model, "Arm", Enum.PartType.Block, Vector3.new(0.35, 3.6, 0.35), CFrame.new(x, 3.4, -0.3) * CFrame.Angles(math.rad(-15), 0, x * 0.15), BODY)
	end
	const head = CFrame.new(0, 5.9, -0.2)
	part(model, "Head", Enum.PartType.Ball, Vector3.one * 1.5, head, BODY)
	eyes(model, head, 0.75, 0.4)
end

const BUILDERS: { [Style]: (Model) -> () } = {
	Walk = buildWalk,
	Crawl = buildCrawl,
	Grin = buildGrin,
	Roof = buildRoof,
}

-- The monster model (feet at the origin, facing -Z), parented to `parent`: the Model named `asset` under
-- ReplicatedStorage.Assets when it exists, else the placeholder of `style`. Also used by the suspense events
-- (Suspense/client/SuspenseController, TASK-481).
function Hide.Build(style: Style, asset: string?, parent: Instance, name: string): Model
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const found = if assets ~= nil and asset ~= nil then assets:FindFirstChild(asset, true) else nil
	if found ~= nil and found:IsA("Model") then
		const clone = found:Clone()
		for _, piece in clone:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = true
				piece.CanCollide = false
				piece.CanQuery = false
				piece.CanTouch = false
			end
		end
		clone.Parent = parent
		return clone
	end
	const model = Instance.new("Model")
	model.Name = name
	BUILDERS[style](model)
	model.WorldPivot = CFrame.identity
	model.Parent = parent
	return model
end

local function body(ctx: Effect.Context, options: Options): Model
	return Hide.Build(options.Style, options.Asset, ctx.Folder(), `{options.Ref}_Monster`)
end

-- Pose of the pass at `t` seconds: (pivot, moving, looking) ------------------------------------------------------

local function walkTo(from: Vector3, to: Vector3, alpha: number, bob: number): CFrame
	const position = from:Lerp(to, smooth(alpha))
	return facing(position + Vector3.new(0, bob, 0), to - from)
end

local function pose(options: Options, path: Path, t: number): (CFrame, boolean, boolean)
	const approach, look, leave = options.Approach, options.Look, options.Leave
	const window = path.Window
	const ground = window.Position.Y
	const start = Vector3.new(path.Start.X, ground, path.Start.Z)
	const exit = Vector3.new(path.Exit.X, ground, path.Exit.Z)
	const style = options.Style
	const bob = math.abs(math.sin(t * 6)) * 0.25

	if t < approach then
		const alpha = t / approach
		if style == "Grin" then
			-- rises from below the window sill
			return window * CFrame.new(0, -9 * (1 - smooth(alpha)), 0), false, false
		elseif style == "Roof" then
			const roof = path.Roof
			if alpha < 0.6 then
				-- steps across the roof towards the window side
				const to = Vector3.new(window.Position.X, roof.Y, window.Position.Z) + window.LookVector * 3
				return walkTo(roof, to, alpha / 0.6, bob), true, false
			end
			-- drops down at the front, in an arc
			const drop = smooth((alpha - 0.6) / 0.4)
			const top = Vector3.new(window.Position.X, roof.Y, window.Position.Z) + window.LookVector * 3
			const position = top:Lerp(window.Position, drop) + Vector3.new(0, math.sin(drop * math.pi) * 1.5, 0)
			return CFrame.new(position) * window.Rotation, false, false
		end
		return walkTo(start, window.Position, alpha, if style == "Crawl" then bob * 0.4 else bob), true, false
	end

	if t < approach + look then
		const inside = t - approach
		const lean = smooth(inside / 0.5)
		const sway = math.sin(inside * 2.2) * math.rad(6)
		if style == "Crawl" then
			-- rears up on the back legs to look in
			return window * CFrame.new(0, 1.2 * lean, 0) * CFrame.Angles(math.rad(35) * lean, sway, 0), false, true
		elseif style == "Grin" then
			return window * CFrame.Angles(0, 0, sway * 0.6), false, true
		end
		return window * CFrame.Angles(-LEAN * lean, sway, 0), false, true
	end

	const alpha = math.clamp((t - approach - look) / leave, 0, 1)
	if style == "Grin" then
		return window * CFrame.new(0, -9 * smooth(alpha), 0), false, false
	end
	return walkTo(window.Position, exit, alpha, bob), true, false
end

-- Warning ------------------------------------------------------------------------------------------------------------

-- Trailer lights flicker locally (same trick as ANM-008's blackout: fixtures marked so LightController leaves them,
-- then unmarked so it repaints).
local function flicker(ctx: Effect.Context)
	const light = ctx.Light
	local off = true
	for _, wait in WARN_FLICKER do
		for _, key in FLICKER_GROUPS do
			const fixtures = light.Fixtures[key]
			if fixtures == nil then
				continue
			end
			for _, fixture in fixtures do
				if off then
					for _, lamp in fixture.Lamps do
						lamp.Part.Material = Enum.Material.SmoothPlastic
						lamp.Part.Color = LAMP_OFF_COLOR
					end
				else
					for _, lamp in fixture.Lamps do
						lamp.Part.Material = lamp.Material
						lamp.Part.Color = lamp.Color
					end
				end
				for _, item in fixture.Lights do
					item.Enabled = not off
				end
				fixture.Lit = true
				fixture.Live = true
			end
		end
		off = not off
		task.wait(wait)
	end
	for _, key in FLICKER_GROUPS do
		const fixtures = light.Fixtures[key]
		if fixtures == nil then
			continue
		end
		for _, fixture in fixtures do
			fixture.Lit = nil
			fixture.Live = nil
		end
	end
end

-- Sounds around the trailer, spread over `seconds` (`count` hits, louder towards the end when `grow`)
local function series(ctx: Effect.Context, key: string?, at: Vector3?, count: number, seconds: number, speed: number?, grow: boolean)
	if key == nil then
		return
	end
	for index = 1, count do
		const volume = if grow then 0.35 + 0.65 * (index / count) else nil
		ctx.Audio:Play(key, at, { Speed = speed, Volume = volume })
		task.wait(seconds / count)
	end
end

function Hide.Warn(ctx: Effect.Context, cue: Effect.Cue, options: Options)
	Watch.Interrupt()
	const seconds = if cue.Row.Duration > 0 then cue.Row.Duration else WARN_FOR
	const trailer = ctx.Point(TRAILER_POINT)
	const base = if trailer ~= nil then trailer.Position else nil
	const signal = options.Signal
	if signal == "Whisper" then
		-- the silent one: nothing in the world, only the words on screen
		Whispers.Play(seconds)
		return
	end
	const rumble = firstSound(RUMBLE_KEYS)
	if rumble ~= nil and signal ~= "Roof" then
		ctx.Play(rumble)
	end
	if signal == "Buzz" then
		-- the Walker also gets the whispered words on screen (owner request 2026-10-16)
		Whispers.Play(seconds)
		task.spawn(flicker, ctx)
		if Content.Sounds.ByKey[BUZZ_KEY] ~= nil then
			ctx.Play(BUZZ_KEY, base)
		end
		const path = pathOf(ctx, options)
		series(ctx, STEP_KEY, if path then path.Start else base, APPROACH_STEPS, seconds * 0.8, nil, true)
	elseif signal == "Scratch" then
		const under = if base ~= nil then base - Vector3.new(0, UNDER_DROP, 0) else nil
		series(ctx, firstSound(SCRATCH_KEYS), under, SCRATCH_COUNT, seconds * 0.85, SCRATCH_SPEED, false)
	elseif signal == "Roof" then
		const roof = if base ~= nil then base + Vector3.new(0, ROOF_HEIGHT, 0) else nil
		series(ctx, ROOF_STEP_KEY, roof, ROOF_STEPS, seconds * 0.85, 0.85, true)
	end
end

-- Pass -----------------------------------------------------------------------------------------------------------

local function fadeAway(model: Model)
	const info = TweenInfo.new(FADE_OUT)
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			TweenService:Create(piece, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(FADE_OUT, function()
		model:Destroy()
	end)
end

local function endPass(pass: Pass, fade: boolean)
	if pass.Done then
		return
	end
	pass.Done = true
	const connection = pass.Connection
	if connection ~= nil then
		connection:Disconnect()
		pass.Connection = nil
	end
	if fade then
		fadeAway(pass.Model)
	else
		pass.Model:Destroy()
	end
end

local function beginPass(ctx: Effect.Context, options: Options): Pass?
	const path = pathOf(ctx, options)
	if path == nil then
		return nil
	end
	const pass: Pass = {
		Model = body(ctx, options),
		Path = path,
		StartedAt = os.clock(),
		LastStep = 0,
		Looked = false,
		Connection = nil,
		Done = false,
	}
	const total = options.Approach + options.Look + options.Leave
	const stepKey = if options.Style == "Roof" then ROOF_STEP_KEY else STEP_KEY
	pass.Connection = RunService.RenderStepped:Connect(function()
		const t = os.clock() - pass.StartedAt
		if t >= total then
			endPass(pass, true)
			return
		end
		const pivot, moving, looking = pose(options, path, t)
		pass.Model:PivotTo(pivot)
		if moving and options.Style ~= "Crawl" and t - pass.LastStep >= STEP_EVERY then
			pass.LastStep = t
			ctx.Play(stepKey, pivot.Position)
		end
		if looking and not pass.Looked then
			pass.Looked = true
			ctx.Play(LOOK_KEY, pivot.Position)
		end
	end)
	return pass
end

-- Effect module of one family B monster.
function Hide.Effect(options: Options): Effect.Module
	const passes: { [number]: Pass } = {}

	return {
		Ref = options.Ref,

		Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
			const id = occ.Id
			Vide.effect(function()
				const phase = occ.Record().Phase
				const current = passes[id]
				if (phase == "Active" or phase == "Failed") and current == nil then
					task.defer(function()
						if passes[id] == nil then
							passes[id] = beginPass(ctx, options)
						end
					end)
				elseif phase == "Resolved" and current ~= nil then
					endPass(current, true)
				end
			end)
			Vide.cleanup(function()
				const current = passes[id]
				passes[id] = nil
				if current ~= nil then
					endPass(current, true)
				end
			end)
		end,

		Cue = function(ctx: Effect.Context, cue: Effect.Cue)
			if cue.Cue == "hide_warn" then
				Hide.Warn(ctx, cue, options)
			elseif cue.Cue == "jumpscare" then
				if cue.Entity == Players.LocalPlayer.UserId % ENTITY_MOD then
					Jumpscare.Show(ctx)
				end
			end
			-- monster_pass: the record turning Active builds the monster (Mount); nothing else to do here
		end,
	}
end

return table.freeze(Hide)
