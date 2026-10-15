--!strict
--[[
	ANM-003 bell and swarm, client side (TASK-340, owner 2026-10-15). Presentation only: the strokes, the switch test
	and the faint are the server's (Anomalies/ANM-003).

	  Stroke(ctx, n)  cue `bell` (Entity = stroke 1..3): the `church_bell` SFX (ReplicatedStorage.Assets.SFX
	                  "Very scary bell sound/church bell", on screen), a short camera shudder, and a small Ink pill at
	                  the top "BELL n / 3" (Mustard on the 3rd). The first stroke cuts a security camera view (Kit/Watch).
	  Swarm(ctx)      cue `swarm`: SWARM_COUNT cartoon moths (cream wings) and bats (ink wings) pour out of the dark
	                  from every side towards the trailer light and the local player, flapping, for SWARM_TIME s.
	Reduced motion (Motion.Reduced): no camera shudder; the swarm still flies (it is the sign of the error).
	PROVISIONAL (TASK-340): placeholder creatures made of Parts (no blood, no alert red).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Effect = require(script.Parent.Parent.Parent.Effect)
local Watch = require(script.Parent.Watch)

const BELL_KEY = "church_bell"
const STROKES = 3
const SHUDDER = math.rad(0.9)
const SHUDDER_TIME = 0.5
const PILL_TIME = 1.6
const INK = Color3.fromHex("#2B2233")
const CREAM = Color3.fromHex("#FFF1D6")
const MUSTARD = Color3.fromHex("#F6C12B")

const SWARM_COUNT = 46
const SWARM_TIME = 1.9 -- s (Rules/ANM-003 SwarmFor ~1.8)
const SWARM_FROM = { 34, 60 } -- studs from the target where they come out of the dark
const SWARM_HEIGHT = { 2, 14 }
const FLAP_SPEED = 22 -- rad/s
const MOTH_SHARE = 0.55
const MOTH_WING = Color3.fromHex("#EFE3C6")
const BAT_WING = Color3.fromHex("#1E1A2B")
const EYE = Color3.fromHex("#F4F1E8")
const TRAILER_POINT = "TRL"
const LIGHT_LIFT = 6 -- studs above the trailer pivot: the lamp

const Bell = {}

local function between(rng: Random, range: { number }): number
	return range[1] + (range[2] - range[1]) * rng:NextNumber()
end

local function pill(stroke: number)
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	const gui = Instance.new("ScreenGui")
	gui.Name = "BellStroke"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 41
	const frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 140)
	frame.Size = UDim2.fromOffset(150, 40)
	frame.BackgroundColor3 = INK
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	const stroke3 = stroke >= STROKES
	const outline = Instance.new("UIStroke")
	outline.Color = MUSTARD
	outline.Thickness = if stroke3 then 4 else 2
	outline.Parent = frame
	const label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 1, -8)
	label.Position = UDim2.fromOffset(8, 4)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextScaled = true
	label.Text = `BELL {stroke} / {STROKES}`
	label.TextColor3 = if stroke3 then MUSTARD else CREAM
	label.Parent = frame
	gui.Parent = playerGui
	task.delay(PILL_TIME, function()
		const fade = TweenInfo.new(0.3)
		TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(outline, fade, { Transparency = 1 }):Play()
		task.wait(0.35)
		gui:Destroy()
	end)
end

local function shudder()
	const camera = Workspace.CurrentCamera
	if camera == nil or Motion.Reduced() then
		return
	end
	const started = os.clock()
	local last = 0
	const connection = RunService.RenderStepped:Connect(function()
		const t = (os.clock() - started) / SHUDDER_TIME
		const angle = if t < 1 then SHUDDER * math.sin(t * math.pi * 6) * (1 - t) else 0
		camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, angle - last)
		last = angle
	end)
	task.delay(SHUDDER_TIME + 0.05, function()
		connection:Disconnect()
	end)
end

function Bell.Stroke(ctx: Effect.Context, stroke: number)
	if stroke <= 1 then
		Watch.Interrupt()
	end
	ctx.Play(BELL_KEY)
	pill(math.clamp(stroke, 1, STROKES))
	shudder()
end

-- One creature: body + two wings (+ eyes on a bat), pivot at the body, facing -Z
type Flyer = { Model: Model, Wings: { BasePart }, From: Vector3, To: Vector3, Phase: number }

local function flyPart(model: Model, name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = if color == EYE then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

local function buildFlyer(rng: Random): (Model, { BasePart })
	const moth = rng:NextNumber() < MOTH_SHARE
	const scale = between(rng, { 0.7, 1.3 })
	const model = Instance.new("Model")
	model.Name = if moth then "Moth" else "Bat"
	const wingColor = if moth then MOTH_WING else BAT_WING
	const body = flyPart(model, "Body", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.6) * scale, BAT_WING)
	model.PrimaryPart = body
	const wings: { BasePart } = {}
	for _, side in { -1, 1 } do
		const wing = flyPart(model, "Wing", Enum.PartType.Block, Vector3.new(0.9, 0.05, 0.6) * scale, wingColor)
		wing:SetAttribute("Side", side)
		table.insert(wings, wing)
	end
	if not moth then
		for _, side in { -0.09, 0.09 } do
			const eye = flyPart(model, "Eye", Enum.PartType.Ball, Vector3.new(0.1, 0.1, 0.1) * scale, EYE)
			eye:SetAttribute("Eye", side * scale)
		end
	end
	return model, wings
end

-- The swarm, towards the trailer light and the local character (half each)
function Bell.Swarm(ctx: Effect.Context, rng: Random)
	const trailer = ctx.Point(TRAILER_POINT)
	const lamp = if trailer ~= nil then trailer.Position + Vector3.new(0, LIGHT_LIFT, 0) else nil
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	const me = if root ~= nil and root:IsA("BasePart") then root.Position else nil
	const centre = lamp or me
	if centre == nil then
		return
	end
	ctx.Play("swarm_flutter", centre)
	ctx.Play("shadow_whoosh", centre)
	const folder = ctx.Folder()
	const flyers: { Flyer } = {}
	for index = 1, SWARM_COUNT do
		const target = if me ~= nil and (lamp == nil or index % 2 == 0) then me else centre
		const angle = rng:NextNumber() * math.pi * 2
		const distance = between(rng, SWARM_FROM)
		const from = target + Vector3.new(math.cos(angle) * distance, between(rng, SWARM_HEIGHT), math.sin(angle) * distance)
		const jitter = Vector3.new(rng:NextNumber() - 0.5, rng:NextNumber() - 0.5, rng:NextNumber() - 0.5) * 3
		const model, wings = buildFlyer(rng)
		model.Parent = folder
		table.insert(flyers, {
			Model = model,
			Wings = wings,
			From = from,
			To = target + jitter,
			Phase = rng:NextNumber() * math.pi * 2,
		})
	end
	const started = os.clock()
	const connection = RunService.RenderStepped:Connect(function()
		const t = (os.clock() - started) / SWARM_TIME
		for _, flyer in flyers do
			-- they arrive at different moments, wobbling, and circle the target at the end
			const a = math.clamp(t * 1.25 - (flyer.Phase / (math.pi * 2)) * 0.25, 0, 1)
			const e = a * a * (3 - 2 * a)
			const wobble = Vector3.new(math.sin(t * 9 + flyer.Phase), math.cos(t * 11 + flyer.Phase), 0) * 1.2
			const position = flyer.From:Lerp(flyer.To, e) + wobble * (1 - e * 0.5)
			const forward = (flyer.To - flyer.From).Unit
			const frame = CFrame.lookAt(position, position + forward)
			const body = flyer.Model.PrimaryPart
			if body ~= nil then
				body.CFrame = frame
			end
			const flap = math.sin((os.clock() - started) * FLAP_SPEED + flyer.Phase) * math.rad(55)
			for _, wing in flyer.Wings do
				const side = wing:GetAttribute("Side") :: number
				wing.CFrame = frame
					* CFrame.new(side * 0.2, 0, 0)
					* CFrame.Angles(0, 0, side * flap)
					* CFrame.new(side * wing.Size.X / 2, 0, 0)
			end
			for _, child in flyer.Model:GetChildren() do
				const eyeSide = child:GetAttribute("Eye")
				if child:IsA("BasePart") and type(eyeSide) == "number" then
					child.CFrame = frame * CFrame.new(eyeSide, 0.08, -0.28)
				end
			end
		end
	end)
	task.wait(SWARM_TIME)
	connection:Disconnect()
	for _, flyer in flyers do
		for _, part in flyer.Model:GetChildren() do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
	end
	task.wait(0.45)
	for _, flyer in flyers do
		flyer.Model:Destroy()
	end
end

return table.freeze(Bell)
