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

	The real door parts get LocalTransparencyModifier = 1 while a local clone swings (purely visual; restored).
	PROVISIONAL (frontend-coder, TASK-118):
	  - hinge = pivot of `Door_Back` when the model sets one (AST-066 "pivô na dobradiça"), else the door edge on its
	    local -X side; the swing goes outward (away from the vehicle centre);
	  - napkin origin = `VFX_Napkins` attachment when AST-094 is in the vehicle, else a point inside the trailer
	    between the door glass (AN-05) and the vehicle centre;
	  - the subtitle strip is local to this effect (Ink pill, 18 px, no phone badge: it is not a call) and sits above
	    the boss call strip; text copied from anomalies.md N9 (Aprovado) until ui-text.md lists it.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Effect = require(script.Parent.Parent.Effect)

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
const VEHICLE_TAG = "Vehicle"
const DOOR_NAMES = { "Door_Back", "Door_Glass" }
const NAPKIN_ANCHOR = "VFX_Napkins"
const DOOR_POINT = "AN-05"

-- Door swing (state Ajar)
const AJAR_ANGLE = math.rad(10)
const OPEN_TIME = 0.35
const CLOSE_TIME = 0.18 -- shuts "sozinha", a little faster

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

-- Subtitle strip
const TEXT_SIZE = 18 -- >= Theme.MinTextSize on the smallest phone
const BOTTOM_GAP = 150 -- above the boss call strip (84 + its height)
const WIDTH_SCALE = 0.6
const MIN_WIDTH = 300
const MAX_WIDTH = 560

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
			IgnoreGuiInset = false,
			ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
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
				create("UICorner")({ CornerRadius = UDim.new(0, 16) }),
				createRaw("UISizeConstraint")({ MinSize = Vector2.new(MIN_WIDTH, 0), MaxSize = Vector2.new(MAX_WIDTH, 10000) }),
				createRaw("UIPadding")({
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
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

-- World -------------------------------------------------------------------------------------------------------------

local function vehicleModel(ctx: Effect.Context): Model?
	const key = Vide.untrack(ctx.Round.Vehicle)
	for _, instance in CollectionService:GetTagged(VEHICLE_TAG) do
		if instance:GetAttribute("Vehicle") == key and instance:IsA("Model") then
			return instance
		end
	end
	return nil
end

-- Door glass position (AN-05, inside); falls back to the door part, then the vehicle
local function doorPoint(ctx: Effect.Context, vehicle: Model?): Vector3?
	const point = ctx.Point(DOOR_POINT)
	if point then
		return point.Position
	end
	if vehicle then
		const door = vehicle:FindFirstChild("Door_Back", true)
		if door and door:IsA("PVInstance") then
			return door:GetPivot().Position
		end
		return vehicle:GetPivot().Position
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

local function knock(ctx: Effect.Context, cue: Effect.Cue)
	const number = nextSeries(cue)
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

local function doorParts(vehicle: Model): { BasePart }
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

local function hingeOf(vehicle: Model): CFrame?
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

local function makeSwing(ctx: Effect.Context, vehicle: Model): Swing?
	const parts = doorParts(vehicle)
	const hingeFull = hingeOf(vehicle)
	if #parts == 0 or hingeFull == nil then
		return nil
	end
	-- rotate about the world vertical through the hinge
	const hinge = CFrame.new((hingeFull :: CFrame).Position)
	const centre = vehicle:GetBoundingBox().Position
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

local function napkinOrigin(vehicle: Model?, door: Vector3?): Vector3?
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
	const centre = vehicle:GetBoundingBox().Position
	const flat = Vector3.new(centre.X, door.Y, centre.Z)
	return door:Lerp(flat, NAPKIN_FALLBACK_SHARE) - Vector3.new(0, NAPKIN_FALLBACK_DROP, 0)
end

-- Wind direction: from the door into the vehicle (flat)
local function windDirection(vehicle: Model?, door: Vector3?): Vector3
	if vehicle and door then
		const centre = vehicle:GetBoundingBox().Position
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

local function doorCrack(ctx: Effect.Context, cue: Effect.Cue)
	const duration = math.max(cue.Row.Duration, OPEN_TIME + CLOSE_TIME)
	const vehicle = vehicleModel(ctx)
	const door = doorPoint(ctx, vehicle)
	const swing = if vehicle then makeSwing(ctx, vehicle) else nil
	ctx.Audio:Play("door_creak", door)

	const rng = cue.Rng
	const direction = windDirection(vehicle, door)
	const side = direction:Cross(Vector3.yAxis)
	const origin = napkinOrigin(vehicle, door)
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
	while true do
		const now = os.clock()
		const t = now - started
		const dt = now - last
		last = now
		if t >= duration then
			break
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

return {
	Ref = "ANM-009",
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "knock" then
			knock(ctx, cue)
		elseif cue.Cue == "door_crack" then
			doorCrack(ctx, cue)
		end
	end,
} :: Effect.Module
