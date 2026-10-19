--!strict
--[[
	ANM-009 The knock: client effect (TASK-118; anomalies.md N9; AST-066, AST-094, AST-095 row 009; sound-list
	SFX-155..158; T117-08, T118-02).

	Presents only. AnomalyService (TASK-117) decides the window, who hid and who pays. The back door never opens for
	real and has no prompt (DEC-054): everything here is a local copy.

	Cues (no Mount: the knock is a sound, nothing persists on screen; a late joiner just hears the next series):
	  * `knock`: one series of three knocks on the back door (AN-05) + the "???" subtitle. Entity = series number
	    (1 = "Rookie? It's me. It's Walt. Open up.", 2+ = "It's cold out here, Rookie."); Entity 0 = counted here per
	    occurrence. Speaker is always "???", never the boss's name (anomalies.md N9 notes).
	  * `door_crack` (Duration 3): the door opens a finger (~10 degrees, state `Ajar`) and slams shut by itself, 6
	    napkins fly in from the counter holder (AST-094 `VFX_Napkins`), 3 bluish wind wisps. Nobody comes in.

	  * `jumpscare` (TASK-333): Entity = UserId % 65536 of who opened the back door during the knocks; only that client
	    shows the face (Kit/Jumpscare). The faint is the server's.

	Mount (TASK-333, owner 2026-10-15): while the record is Active a local figure stands OUTSIDE the back door (a tall
	dark silhouette with white eyes and Walt's cap, cartoon and Mild), facing it, knocking. It is drawn only while the
	local player watches camera 2 (LocalPlayer attributes `SecurityView` ~= "" and `SecurityCam` = KNOCKER_CAM, TASK-285):
	from the door itself nobody is there.

	The real door parts get LocalTransparencyModifier = 1 while a local clone swings (purely visual; restored).
	PROVISIONAL (frontend-coder, TASK-118):
	  - hinge = pivot of `Door_Back` when the model sets one (AST-066 "pivô na dobradiça"), else the door edge on its
	    local -X side; the swing goes outward (away from the vehicle centre);
	  - napkin origin = `VFX_Napkins` attachment when AST-094 is in the vehicle, else a point inside the trailer
	    between the door glass (AN-05) and the vehicle centre;
	  - the subtitle strip is local to this effect (Ink pill, 18 px, no phone badge: it is not a call) and sits above
	    the boss call strip; text copied from anomalies.md N9 (Aprovado) until ui-text.md lists it.

	Restaurant (TASK-561, owner 2026-10-18; anomalies-v3-restaurant.md §8.3). Four series from the server, each its own
	SERIES row: 1 far and soft (slow, quiet, no voice), 2 closer and rhythmic, 3 Walt's voice ("It's me. It's Walt."),
	4 the voice wrong (lower knocks, uneven gaps, the line typed out word by word with dead pauses). The knocker stands
	at SCENE-DOOR-OUT facing SCENE-DOOR and is drawn on any security camera (Kit/Watch) or for a local player OUTSIDE
	within OUTSIDE_RANGE of the door (from the street it is right there). door_crack: the leaf is really open (the
	player opened it), so no swing; the napkins and the wind blow in from SCENE-DOOR-OUT through SCENE-DOOR. The
	silence, the handle, the latch and the hit are the scene's (Content.HorrorScenes anm_009_knock).
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local UiScale = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.UiScale)
local Haptics = require(StarterPlayer.StarterPlayerScripts.client.Input.Haptics)
local Effect = require(script.Parent.Parent.Effect)
local Jumpscare = require(script.Parent.Kit.Jumpscare)
local Watch = require(script.Parent.Kit.Watch)
local VehicleRoot = require(ReplicatedStorage.shared.Vehicle.VehicleRoot)

const create = Vide.create
const spring = Vide.spring
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const SPEAKER = "???"
const LINES = {
	"Rookie? It's me. It's Walt. Open up.",
	"It's cold out here, Rookie.",
}
const SUBTITLE_TIME = 3.5 -- seconds a line stays
const SERIES_RESET = 20 -- seconds without a knock: the next one starts a new count (Entity 0 only)

const KNOCKS = 3
const KNOCK_GAP = 0.42
const DOOR_NAMES = { "Door_Back", "Door_Glass" }
const NAPKIN_ANCHOR = "VFX_Napkins"
-- restaurant (owner 2026-10-18, Walt knocking on the back door): the pantry's exit door DOOR-B, from outside
const RESTAURANT = Content.Restaurant.Rules.Enabled
const DOOR_POINT = if RESTAURANT then "SCENE-DOOR-OUT" else "AN-05"
const DOOR_IN_POINT = "SCENE-DOOR" -- restaurant: the inside of DOOR-B (the blackout's door point)
const OUTSIDE_RANGE = 40 -- studs: a local player outside this near DOOR-B sees the knocker

-- Restaurant series (TASK-561; PROVISIONAL): volume scale, gaps between knocks (s; uneven = wrong), playback speed,
-- line (nil = no voice); Typed = the line comes word by word with this pause (s) between words
type Series = { Volume: number, Gaps: { number }, Speed: number, Line: string?, Typed: number? }
const SERIES: { Series } = {
	{ Volume = 0.3, Gaps = { 0.75, 0.75 }, Speed = 0.92 },
	{ Volume = 0.75, Gaps = { 0.38, 0.38, 0.38 }, Speed = 1 },
	{ Volume = 1, Gaps = { 0.42, 0.42 }, Speed = 1, Line = "Rookie? It's me. It's Walt. Open up." },
	{ Volume = 1.1, Gaps = { 0.9, 0.25, 1.4 }, Speed = 0.78, Line = "Rookie. Open. The. Door.", Typed = 0.55 },
}

-- Door swing (state Ajar)
const AJAR_ANGLE = math.rad(10)
const OPEN_TIME = 0.35
const CLOSE_TIME = 0.18 -- shuts "sozinha", a little faster
const SLAM_RANGE = 30 -- studs: the own player this near the door feels the slam (TASK-268 haptics)

-- Napkins (AST-094: Cream) and wind wisps (AST-095: 3 bluish)
const NAPKIN_COUNT = 6
const NAPKIN_SIZE = Vector3.new(0.6, 0.03, 0.6)
const NAPKIN_COLOR = Color3.fromHex("#FFF1D6")
const NAPKIN_SPEED = { 5, 9 } -- studs/s into the trailer
const NAPKIN_UP = { 3, 6 } -- initial upward speed
const NAPKIN_GRAVITY = 9
const NAPKIN_FADE = 0.6 -- last seconds fade out
const NAPKIN_FLOOR_DROP = 3 -- studs from the counter down to the trailer floor
const NAPKIN_FALLBACK_SHARE = 0.45 -- AN-05 -> vehicle centre
const NAPKIN_FALLBACK_DROP = 2.5 -- studs under the door glass (counter height)
const WISP_COUNT = 3
const WISP_COLOR = Color3.fromHex("#C7E6F5")
const WISP_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

-- The knocker outside (TASK-333)
const KNOCKER_CAM = "CAM2" -- Content.Security.Cams key that sees the back door
const KNOCKER_OUT = 3.2 -- studs out from the door glass
const KNOCKER_DROP = 7.45 -- studs from the door glass (AN-05) down to the ground when no raycast hits (MAP-01)
const KNOCKER_BODY = Color3.fromHex("#1E1A2B")
const KNOCKER_EYE = Color3.fromHex("#F4F1E8")
const KNOCKER_CAP = Color3.fromHex("#3A4A6B") -- Walt's cap, faded
const KNOCK_SWAY = math.rad(6)
const ENTITY_MOD = 65536

-- Subtitle strip
const TEXT_SIZE = 16 -- >= Theme.MinTextSize on the smallest phone
const BOTTOM_GAP = 150 -- above the boss call strip (84 + its height)
const WIDTH_SCALE = 0.55
const MIN_WIDTH = 260
const MAX_WIDTH = 460

type Subtitle = {
	Text: Vide.Source<string>,
	Token: number,
}

local subtitle: Subtitle? = nil

-- occurrence id (or 0) -> { count, last knock clock }
const series: { [number]: { Count: number, At: number } } = {}

local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- Lazily mounts the local "???" strip in PlayerGui (kept for the session; empty text = hidden).
local function strip(): Subtitle
	const existing = subtitle
	if existing then
		return existing
	end
	const text = Vide.source("")
	const made: Subtitle = { Text = text, Token = 0 }
	subtitle = made
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	Vide.root(function()
		local last = ""
		const shown = function(): string
			const value = text()
			if value ~= "" then
				last = value
			end
			return last
		end
		const alpha = spring(function()
			return if text() ~= "" then 0 else 1
		end, 0.18, 1)
		const gui = create("ScreenGui")({
			Name = "AnomalySubtitle",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 2,

			create("CanvasGroup")({
				Name = "Strip",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -BOTTOM_GAP),
				Size = UDim2.fromScale(WIDTH_SCALE, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Color.Ink,
				BackgroundTransparency = Theme.Transparency.Panel,
				GroupTransparency = alpha,
				Visible = function()
					return text() ~= "" or alpha() < 0.99
				end,
				create("UICorner")({ CornerRadius = UDim.new(0, 14) }),
				createRaw("UIScale")({ Scale = UiScale.Current }), -- global UI scale (Theme.ScaleOf)
				createRaw("UISizeConstraint")({ MinSize = Vector2.new(MIN_WIDTH, 0), MaxSize = Vector2.new(MAX_WIDTH, 10000) }),
				createRaw("UIPadding")({
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				}),
				create("TextLabel")({
					Name = "Line",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					FontFace = Theme.Font.Body,
					TextSize = TEXT_SIZE,
					TextColor3 = Theme.Color.Text,
					TextWrapped = true,
					RichText = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = function()
						return `<font color="#{Theme.Color.Mustard:ToHex()}">{escape(SPEAKER)}:</font> {escape(shown())}`
					end,
					createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
				}),
			}),
		})
		gui.Parent = playerGui
		return nil
	end)
	return made
end

local function say(line: string)
	const target = strip()
	target.Token += 1
	const token = target.Token
	target.Text(line)
	task.delay(SUBTITLE_TIME, function()
		if target.Token == token then
			target.Text("")
		end
	end)
end

-- The wrong voice: the line grows word by word, a dead pause between words, then holds
local function sayTyped(line: string, pause: number)
	const target = strip()
	target.Token += 1
	const token = target.Token
	const words = string.split(line, " ")
	local shown = ""
	for index, word in words do
		if target.Token ~= token then
			return
		end
		shown = if index == 1 then word else `{shown} {word}`
		target.Text(shown)
		task.wait(pause * (if index % 2 == 0 then 1.6 else 1))
	end
	task.delay(SUBTITLE_TIME, function()
		if target.Token == token then
			target.Text("")
		end
	end)
end

-- World -------------------------------------------------------------------------------------------------------------

local function vehicleModel(ctx: Effect.Context): Instance?
	return VehicleRoot.Find(Vide.untrack(ctx.Round.Vehicle))
end

-- Door glass position (AN-05, inside); falls back to the door part, then the vehicle
local function doorPoint(ctx: Effect.Context, vehicle: Instance?): Vector3?
	const point = ctx.Point(DOOR_POINT)
	if point then
		return point.Position
	end
	if vehicle then
		const door = vehicle:FindFirstChild("Door_Back", true)
		if door and door:IsA("PVInstance") then
			return door:GetPivot().Position
		end
		return VehicleRoot.Pivot(vehicle).Position
	end
	return nil
end

local function nextSeries(cue: Effect.Cue): number
	if cue.Entity >= 1 then
		return cue.Entity
	end
	const id = if cue.Occurrence then cue.Occurrence.Id else 0
	const now = os.clock()
	local entry = series[id]
	if entry == nil or now - entry.At > SERIES_RESET then
		entry = { Count = 0, At = now }
		series[id] = entry
	end
	const current = entry :: { Count: number, At: number }
	current.Count += 1
	current.At = now
	return current.Count
end

local function knockRestaurant(ctx: Effect.Context, number: number)
	const row = SERIES[math.clamp(number, 1, #SERIES)]
	const point = ctx.Point(DOOR_POINT)
	const at = if point then point.Position else nil
	const line = row.Line
	if line ~= nil then
		const typed = row.Typed
		if typed ~= nil then
			task.spawn(sayTyped, line, typed)
		else
			say(line)
		end
	end
	for i = 1, #row.Gaps + 1 do
		ctx.Audio:Play("door_knock", at, { Volume = row.Volume, Speed = row.Speed, Vary = 0.02 })
		const gap = row.Gaps[i]
		if gap ~= nil then
			task.wait(gap)
		end
	end
end

local function knock(ctx: Effect.Context, cue: Effect.Cue)
	const number = nextSeries(cue)
	if RESTAURANT then
		knockRestaurant(ctx, number)
		return
	end
	say(LINES[math.min(number, #LINES)])
	const at = doorPoint(ctx, vehicleModel(ctx))
	for i = 1, KNOCKS do
		ctx.Audio:Play("door_knock", at)
		if i < KNOCKS then
			task.wait(KNOCK_GAP)
		end
	end
end

-- Door Ajar ---------------------------------------------------------------------------------------------------------

type Swing = {
	Originals: { BasePart },
	Clones: { BasePart },
	Offsets: { CFrame }, -- clone CFrame in hinge space
	Hinge: CFrame,
	Sign: number,
}

local function doorParts(vehicle: Instance): { BasePart }
	const out: { BasePart } = {}
	for _, name in DOOR_NAMES do
		const found = vehicle:FindFirstChild(name, true)
		if found == nil then
			continue
		end
		if found:IsA("BasePart") then
			table.insert(out, found)
		end
		for _, d in found:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function hingeOf(vehicle: Instance): CFrame?
	const door = vehicle:FindFirstChild("Door_Back", true)
	if door == nil then
		return nil
	end
	if door:IsA("Model") then
		return door:GetPivot()
	elseif door:IsA("BasePart") then
		if door.PivotOffset ~= CFrame.identity then
			return door:GetPivot()
		end
		-- no pivot set: the edge on the local -X side of its widest horizontal axis
		const size = door.Size
		if size.X >= size.Z then
			return door.CFrame * CFrame.new(-size.X / 2, 0, 0)
		end
		return door.CFrame * CFrame.new(0, 0, -size.Z / 2)
	end
	return nil
end

local function makeSwing(ctx: Effect.Context, vehicle: Instance): Swing?
	const parts = doorParts(vehicle)
	const hingeFull = hingeOf(vehicle)
	if #parts == 0 or hingeFull == nil then
		return nil
	end
	-- rotate about the world vertical through the hinge
	const hinge = CFrame.new((hingeFull :: CFrame).Position)
	const centre = (VehicleRoot.Box(vehicle)).Position
	local doorCentre = Vector3.zero
	for _, part in parts do
		doorCentre += part.Position
	end
	doorCentre /= #parts
	-- outward = the sign that moves the door centre away from the vehicle centre
	const plus = (hinge * CFrame.Angles(0, AJAR_ANGLE, 0) * hinge:Inverse() * doorCentre - centre).Magnitude
	const minus = (hinge * CFrame.Angles(0, -AJAR_ANGLE, 0) * hinge:Inverse() * doorCentre - centre).Magnitude
	const clones: { BasePart } = {}
	const offsets: { CFrame } = {}
	const folder = ctx.Folder()
	for _, part in parts do
		const copy = part:Clone()
		copy:ClearAllChildren()
		for _, child in part:GetChildren() do
			if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceAppearance") then
				child:Clone().Parent = copy
			end
		end
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.Parent = folder
		table.insert(clones, copy)
		table.insert(offsets, hinge:Inverse() * part.CFrame)
		part.LocalTransparencyModifier = 1
	end
	return {
		Originals = parts,
		Clones = clones,
		Offsets = offsets,
		Hinge = hinge,
		Sign = if plus >= minus then 1 else -1,
	}
end

local function poseSwing(swing: Swing, angle: number)
	const turned = swing.Hinge * CFrame.Angles(0, angle * swing.Sign, 0)
	for i, clone in swing.Clones do
		clone.CFrame = turned * swing.Offsets[i]
	end
end

local function endSwing(swing: Swing)
	for _, clone in swing.Clones do
		clone:Destroy()
	end
	for _, part in swing.Originals do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
end

-- Napkins and wind --------------------------------------------------------------------------------------------------

local function napkinOrigin(vehicle: Instance?, door: Vector3?): Vector3?
	if vehicle then
		const anchor = vehicle:FindFirstChild(NAPKIN_ANCHOR, true)
		if anchor and anchor:IsA("Attachment") then
			return anchor.WorldPosition
		elseif anchor and anchor:IsA("BasePart") then
			return anchor.Position
		end
	end
	if door == nil then
		return nil
	end
	if vehicle == nil then
		return door - Vector3.new(0, NAPKIN_FALLBACK_DROP, 0)
	end
	const centre = (VehicleRoot.Box(vehicle)).Position
	const flat = Vector3.new(centre.X, door.Y, centre.Z)
	return door:Lerp(flat, NAPKIN_FALLBACK_SHARE) - Vector3.new(0, NAPKIN_FALLBACK_DROP, 0)
end

-- Wind direction: from the door into the vehicle (flat)
local function windDirection(vehicle: Instance?, door: Vector3?): Vector3
	if vehicle and door then
		const centre = (VehicleRoot.Box(vehicle)).Position
		const flat = Vector3.new(centre.X - door.X, 0, centre.Z - door.Z)
		if flat.Magnitude > 1e-3 then
			return flat.Unit
		end
	end
	return Vector3.new(0, 0, -1)
end

type Napkin = {
	Part: BasePart,
	Velocity: Vector3,
	Spin: Vector3,
	Floor: number,
}

local function wisps(ctx: Effect.Context, at: Vector3, direction: Vector3)
	const holder = Instance.new("Part")
	holder.Name = "KnockWind"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.lookAt(at, at + direction)
	const emitter = Instance.new("ParticleEmitter")
	emitter.Texture = WISP_TEXTURE
	emitter.Color = ColorSequence.new(WISP_COLOR)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 2.4),
	})
	emitter.Squash = NumberSequence.new(-0.6) -- stretched along the motion: a wisp, not a puff
	emitter.Lifetime = NumberRange.new(1, 1.4)
	emitter.Speed = NumberRange.new(10, 14)
	emitter.SpreadAngle = Vector2.new(12, 8)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.LightEmission = 0.3
	emitter.LightInfluence = 0.5
	emitter.Rate = 0
	emitter.Parent = holder
	holder.Parent = ctx.Folder()
	emitter:Emit(WISP_COUNT)
	task.delay(2, function()
		holder:Destroy()
	end)
end

-- Restaurant: DOOR-B is really open; the wind comes from outside through it (nil when the points are not streamed)
local function restaurantGust(ctx: Effect.Context): (Vector3?, Vector3?)
	const outside = ctx.Point(DOOR_POINT)
	const inside = ctx.Point(DOOR_IN_POINT)
	if outside == nil or inside == nil then
		return nil, nil
	end
	const flat = Vector3.new(inside.X - outside.X, 0, inside.Z - outside.Z)
	return inside.Position, if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
end

local function doorCrack(ctx: Effect.Context, cue: Effect.Cue)
	const duration = math.max(cue.Row.Duration, OPEN_TIME + CLOSE_TIME)
	const vehicle = if RESTAURANT then nil else vehicleModel(ctx)
	local door = doorPoint(ctx, vehicle)
	const swing = if vehicle then makeSwing(ctx, vehicle) else nil
	local direction = windDirection(vehicle, door)
	local origin = napkinOrigin(vehicle, door)
	if RESTAURANT then
		const gustAt, gustDirection = restaurantGust(ctx)
		door = gustAt
		origin = gustAt
		direction = gustDirection or direction
	end
	ctx.Audio:Play("door_creak", door)

	const rng = cue.Rng
	const side = direction:Cross(Vector3.yAxis)
	const napkins: { Napkin } = {}
	if origin then
		const folder = ctx.Folder()
		for _ = 1, NAPKIN_COUNT do
			const part = Instance.new("Part")
			part.Name = "Napkin"
			part.Size = NAPKIN_SIZE
			part.Color = NAPKIN_COLOR
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.CFrame = CFrame.new(origin + side * rng:NextNumber(-0.3, 0.3))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			part.Parent = folder
			const forward = rng:NextNumber(NAPKIN_SPEED[1], NAPKIN_SPEED[2])
			table.insert(napkins, {
				Part = part,
				Velocity = direction * forward
					+ side * rng:NextNumber(-2.5, 2.5)
					+ Vector3.new(0, rng:NextNumber(NAPKIN_UP[1], NAPKIN_UP[2]), 0),
				Spin = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-4, 4), rng:NextNumber(-6, 6)),
				Floor = origin.Y - NAPKIN_FLOOR_DROP,
			})
		end
		wisps(ctx, door or origin, direction)
	end

	const started = os.clock()
	local last = started
	local slammed = false
	while true do
		const now = os.clock()
		const t = now - started
		const dt = now - last
		last = now
		if t >= duration then
			break
		end
		-- the door slams shut: a medium kick for the own player near it (TASK-268)
		if not slammed and t > duration - CLOSE_TIME then
			slammed = true
			const character = Players.LocalPlayer.Character
			const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if door and root and root:IsA("BasePart") and (root.Position - door).Magnitude <= SLAM_RANGE then
				Haptics.Play("Slam")
			end
		end
		if swing then
			local angle: number
			if t < OPEN_TIME then
				angle = AJAR_ANGLE * (t / OPEN_TIME)
			elseif t > duration - CLOSE_TIME then
				angle = AJAR_ANGLE * math.max(0, (duration - t) / CLOSE_TIME)
			else
				angle = AJAR_ANGLE
			end
			poseSwing(swing, angle)
		end
		const fade = math.clamp((duration - t) / NAPKIN_FADE, 0, 1)
		for _, napkin in napkins do
			const part = napkin.Part
			if part.Parent == nil then
				continue
			end
			napkin.Velocity -= Vector3.new(0, NAPKIN_GRAVITY * dt, 0)
			local position = part.Position + napkin.Velocity * dt
			if position.Y < napkin.Floor then
				position = Vector3.new(position.X, napkin.Floor, position.Z)
				napkin.Velocity = Vector3.new(napkin.Velocity.X * 0.5, 0, napkin.Velocity.Z * 0.5)
			end
			const spin = napkin.Spin * dt
			part.CFrame = CFrame.new(position) * (part.CFrame - part.Position) * CFrame.Angles(spin.X, spin.Y, spin.Z)
			part.Transparency = 1 - fade
		end
		RunService.Heartbeat:Wait()
	end
	if swing then
		endSwing(swing)
	end
	for _, napkin in napkins do
		napkin.Part:Destroy()
	end
end

-- Knocker ------------------------------------------------------------------------------------------------------

local function knockerPart(model: Model, name: string, shape: Enum.PartType, size: Vector3, at: CFrame, color: Color3)
	const part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = at
	part.Color = color
	part.Material = if color == KNOCKER_EYE then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
end

-- Feet pose outside the back door, facing it (nil when the door is not known on this client)
local function knockerPose(ctx: Effect.Context): CFrame?
	if RESTAURANT then
		-- SCENE-DOOR-OUT outside DOOR-B, facing SCENE-DOOR; feet on the ground under it
		const outside = ctx.Point(DOOR_POINT)
		const inside = ctx.Point(DOOR_IN_POINT)
		if outside == nil or inside == nil then
			return nil
		end
		const params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { ctx.Folder() }
		const hit = workspace:Raycast(outside.Position + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), params)
		const feet = if hit then hit.Position else outside.Position
		const look = Vector3.new(inside.X, feet.Y, inside.Z)
		return if (look - feet).Magnitude > 1e-3 then CFrame.lookAt(feet, look) else CFrame.new(feet)
	end
	const vehicle = vehicleModel(ctx)
	const door = doorPoint(ctx, vehicle)
	if door == nil or vehicle == nil then
		return nil
	end
	const centre = VehicleRoot.Pivot(vehicle).Position
	local out = Vector3.new(door.X - centre.X, 0, door.Z - centre.Z)
	out = if out.Magnitude > 1e-3 then out.Unit else Vector3.zAxis
	const at = door + out * KNOCKER_OUT
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { vehicle, ctx.Folder() }
	const hit = workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), params)
	const ground = if hit then hit.Position.Y else door.Y - KNOCKER_DROP
	const feet = Vector3.new(at.X, ground, at.Z)
	return CFrame.lookAt(feet, feet - out)
end

-- Tall silhouette, pivot at the feet, facing -Z (the door)
local function buildKnocker(pose: CFrame): Model
	const model = Instance.new("Model")
	model.Name = "Knocker"
	knockerPart(model, "Body", Enum.PartType.Block, Vector3.new(2, 4.6, 1.1), pose * CFrame.new(0, 2.3, 0), KNOCKER_BODY)
	knockerPart(model, "Head", Enum.PartType.Ball, Vector3.new(1.8, 1.8, 1.8), pose * CFrame.new(0, 5.4, 0), KNOCKER_BODY)
	knockerPart(model, "Cap", Enum.PartType.Cylinder, Vector3.new(0.5, 1.9, 1.9), pose * CFrame.new(0, 6.3, 0) * CFrame.Angles(0, 0, math.rad(90)), KNOCKER_CAP)
	for _, side in { -0.42, 0.42 } do
		knockerPart(model, "Eye", Enum.PartType.Ball, Vector3.new(0.5, 0.62, 0.3), pose * CFrame.new(side, 5.55, -0.82), KNOCKER_EYE)
	end
	knockerPart(model, "Arm", Enum.PartType.Block, Vector3.new(0.5, 2.6, 0.5), pose * CFrame.new(0.9, 4.1, -0.9) * CFrame.Angles(math.rad(70), 0, 0), KNOCKER_BODY)
	model.PrimaryPart = model:FindFirstChild("Body") :: BasePart
	return model
end

-- Restaurant: the local player stands outside DOOR-B (past the door, on the SCENE-DOOR-OUT side) and near it
local function outsideNear(ctx: Effect.Context): boolean
	const outside = ctx.Point(DOOR_POINT)
	const inside = ctx.Point(DOOR_IN_POINT)
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if outside == nil or inside == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	const out = outside.Position - inside.Position
	const from = root.Position - inside.Position
	return from:Dot(out) > out:Dot(out) * 0.5 and (root.Position - outside.Position).Magnitude <= OUTSIDE_RANGE
end

-- Watching camera 2 right now (TASK-285 attributes on the LocalPlayer)
local function onCamera(): boolean
	const player = Players.LocalPlayer
	const view = player:GetAttribute("SecurityView")
	return type(view) == "string" and view ~= "" and player:GetAttribute("SecurityCam") == KNOCKER_CAM
end

local function mountKnocker(ctx: Effect.Context, occ: Effect.Occurrence)
	local model: Model? = nil
	local pose: CFrame? = nil
	local shown = false
	const started = os.clock()
	const connection = RunService.RenderStepped:Connect(function()
		const record = Vide.untrack(occ.Record)
		const live = record.Phase == "Active"
		if live and model == nil then
			pose = knockerPose(ctx)
			if pose ~= nil then
				const built = buildKnocker(pose)
				built.Parent = ctx.Folder()
				model = built
				shown = true -- forces the first visibility write below
			end
		end
		const current = model
		if current == nil then
			return
		end
		const visible = live and (if RESTAURANT then Watch.Watching() or outsideNear(ctx) else onCamera())
		if visible ~= shown then
			shown = visible
			for _, part in current:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = if visible then 0 else 1
				end
			end
		end
		if visible and pose ~= nil then
			-- a slow knocking sway
			current:PivotTo((pose :: CFrame) * CFrame.Angles(math.sin((os.clock() - started) * 5) * KNOCK_SWAY * 0.3, 0, 0))
		end
	end)
	Vide.cleanup(function()
		connection:Disconnect()
		if model ~= nil then
			model:Destroy()
		end
	end)
end

return {
	Ref = "ANM-009",
	Mount = mountKnocker,
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "knock" then
			knock(ctx, cue)
		elseif cue.Cue == "door_crack" then
			doorCrack(ctx, cue)
		elseif cue.Cue == "jumpscare" then
			if cue.Entity == Players.LocalPlayer.UserId % ENTITY_MOD then
				Jumpscare.Show(ctx)
			end
		end
	end,
} :: Effect.Module
