--!strict
--[[
	V2 family B "something is coming", client side (DEC-254, DEC-255, DEC-256; TASK-272; anomalies-v2-proposal.md
	§3 B; server: AnomalyService/Anomalies/Kit/Hide.luau). One kit for every family B monster; Effects/<Ref>.luau is
	a thin call to Hide.Effect. Presentation only (T10): the hiding test and the faint are the server's.

	Cues:
	  hide_warn     the warning: trailer lights flicker (local, like ANM-008's blackout), a low rumble, the radio
	                squelch and Walt's line "Hide! Out the back door!" (voice through BossController when it can, and
	                a strip at the bottom of the screen for the cue Duration, WARN_STRIP s when the row has none).
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

const create = Vide.create
const createRaw = Vide.create :: any -- UIStroke is missing from Vide.create's class list (same as Jumpscare)

export type Style = "Walk" | "Crawl" | "Grin" | "Roof"

export type Options = {
	Ref: string,
	Style: Style,
	Asset: string?, -- Model under ReplicatedStorage.Assets that replaces the placeholder
	-- seconds of the pass; Approach ~ server LookFrom, Approach + Look ~ server LookTo (Rules/<Ref>, Provisional)
	Approach: number,
	Look: number,
	Leave: number,
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
const RADIO_KEY = "phone_glitch"
const STEP_KEY = "walker_step"
const ROOF_STEP_KEY = "roof_step"
const LOOK_KEY = "shadow_whoosh"
const STEP_EVERY = 0.55 -- s between two footsteps
const RADIO_LINE = "Hide! Out the back door, now!"
const WARN_STRIP = 8 -- s the strip stays when the cue row has no Duration
const FADE_OUT = 0.6

const INK = Color3.fromHex("#2B2233")
const BODY = Color3.fromHex("#1E1A2B")
const EYE = Color3.fromHex("#F4F1E8")
const CREAM = Color3.fromHex("#FFF1D6")
const MUSTARD = Color3.fromHex("#F6C12B")
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

local function pathOf(ctx: Effect.Context): Path?
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

local function body(ctx: Effect.Context, options: Options): Model
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const found = if assets ~= nil and options.Asset ~= nil then assets:FindFirstChild(options.Asset, true) else nil
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
		clone.Parent = ctx.Folder()
		return clone
	end
	const model = Instance.new("Model")
	model.Name = `{options.Ref}_Monster`
	BUILDERS[options.Style](model)
	model.WorldPivot = CFrame.identity
	model.Parent = ctx.Folder()
	return model
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

-- Walt's voice on the radio when BossController can speak (best effort; the strip always shows).
local function radioVoice(text: string)
	const client = script:FindFirstAncestor("client")
	const feature = if client then client:FindFirstChild("Boss") else nil
	const module = if feature then feature:FindFirstChild("BossController") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return
	end
	pcall(function()
		const boss: any = (require :: any)(module)
		const speak: any = if type(boss) == "table" then boss.Speak else nil
		if type(speak) == "function" then
			(speak :: any)(boss, text)
		end
	end)
end

local function strip(seconds: number)
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	const label = createRaw("TextLabel")({
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.8),
		BackgroundTransparency = 1,
		FontFace = Font.fromEnum(Enum.Font.FredokaOne),
		Text = `<font color="#F6C12B">WALT (radio):</font> {RADIO_LINE}`,
		RichText = true,
		TextScaled = true,
		TextColor3 = CREAM,
	})
	const frame = create("Frame")({
		Name = "Strip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.new(0.5, 0, 0, 46),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.12,
		create("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
		createRaw("UIStroke")({ Color = MUSTARD, Thickness = 3 }),
		createRaw("UISizeConstraint")({ MinSize = Vector2.new(280, 0), MaxSize = Vector2.new(640, 46) }),
		label,
	}) :: Frame
	const gui = create("ScreenGui")({
		Name = "HideWarning",
		ResetOnSpawn = false,
		DisplayOrder = 40,
		frame,
	}) :: ScreenGui
	gui.Parent = playerGui
	task.delay(seconds, function()
		const fade = TweenInfo.new(0.3)
		TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		task.wait(0.35)
		gui:Destroy()
	end)
end

function Hide.Warn(ctx: Effect.Context, cue: Effect.Cue)
	const rumble = firstSound(RUMBLE_KEYS)
	if rumble ~= nil then
		ctx.Play(rumble)
	end
	task.spawn(flicker, ctx)
	task.delay(0.5, function()
		if Content.Sounds.ByKey[RADIO_KEY] ~= nil then
			ctx.Play(RADIO_KEY)
		end
		radioVoice(RADIO_LINE)
		strip(if cue.Row.Duration > 0 then cue.Row.Duration else WARN_STRIP)
	end)
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
	const path = pathOf(ctx)
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
				Hide.Warn(ctx, cue)
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
