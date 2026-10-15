--!strict
--[[
	V2 jumpscare (DEC-255, DEC-256; TASK-269; anomalies-v2-proposal.md §2.4). The server sends the cue `jumpscare`
	(Entity = actor NpcId) when someone takes the order of an odd customer; every player whose character is within
	RANGE studs of the actor sees a cartoon monster face full screen for ~0.6 s with the `jumpscare` sound (Scare cap,
	DEC-173). The faint itself is the server's (VitalService:Fall ~0.7 s after the cue): nothing is decided here.

	Cartoon and Mild (DEC-172, DEC-256): an Ink-dark head with two huge white eyes and a wide toothy grin, no blood,
	no alert red, no strobe. Placeholder made of Frames until the art-director's face sheet exists (a `Jumpscare_Face`
	ImageLabel anywhere under ReplicatedStorage.Assets replaces the drawing). Provisional.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Parent.Effect)

const create = Vide.create
-- the type definitions miss UIStroke in Vide.create's class list (same workaround as BossController)
const createRaw = Vide.create :: any

const RANGE = 24 -- studs from the actor: the counter and the trailer
const HOLD = 0.6 -- s on screen (DEC-256)
const POP = 0.12 -- s of the zoom-in
const SHAKE = 18 -- px of screen jitter while it holds
const FACE_NAME = "Jumpscare_Face"
const INK = Color3.fromHex("#2B2233") -- Theme Ink: the house outline colour, never alert red
const SKIN = Color3.fromHex("#4A3F55")
const WHITE = Color3.fromHex("#FFFFFF")
const TEETH = 7

const Jumpscare = {}

local busy = false

local function kitFace(): ImageLabel?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const found = if assets then assets:FindFirstChild(FACE_NAME, true) else nil
	return if found ~= nil and found:IsA("ImageLabel") then found else nil
end

local function corner(scale: number): Instance
	return create("UICorner")({ CornerRadius = UDim.new(scale, 0) })
end

local function eye(x: number): Instance
	return create("Frame")({
		Name = "Eye",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, 0.36),
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = WHITE,
		corner(0.5),
		createRaw("UIStroke")({ Color = INK, Thickness = 6 }),
		create("Frame")({
			Name = "Pupil",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(0.16, 0.16),
			BackgroundColor3 = INK,
			corner(0.5),
		}),
	})
end

local function mouth(): Instance
	const teeth: { Instance } = {}
	for index = 1, TEETH do
		table.insert(
			teeth,
			create("Frame")({
				Name = `Tooth{index}`,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale((index - 0.5) / TEETH, 0),
				Size = UDim2.fromScale(0.8 / TEETH, 0.45),
				Rotation = 45,
				BackgroundColor3 = WHITE,
			})
		)
	end
	return create("Frame")({
		Name = "Mouth",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.74),
		Size = UDim2.fromScale(0.78, 0.2),
		BackgroundColor3 = INK,
		ClipsDescendants = true,
		corner(0.4),
		teeth,
	})
end

-- The drawn face (placeholder) or the kit's ImageLabel.
local function face(): GuiObject
	const kit = kitFace()
	if kit ~= nil then
		const clone = kit:Clone()
		clone.AnchorPoint = Vector2.new(0.5, 0.5)
		clone.Position = UDim2.fromScale(0.5, 0.5)
		clone.Size = UDim2.fromScale(1, 1)
		return clone
	end
	return create("Frame")({
		Name = "Head",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = SKIN,
		corner(0.45),
		createRaw("UIStroke")({ Color = INK, Thickness = 10 }),
		eye(0.3),
		eye(0.7),
		mouth(),
	}) :: Frame
end

-- true when the local character stands within RANGE of the actor (actor not streamed in = too far: no scare).
local function near(ctx: Effect.Context, npcId: number): boolean
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	const model = ctx.Npc(npcId)
	if root == nil or not root:IsA("BasePart") or model == nil then
		return false
	end
	return (model:GetPivot().Position - root.Position).Magnitude <= RANGE
end

-- Shows the face once (one at a time). Yields for ~HOLD s.
function Jumpscare.Show(ctx: Effect.Context)
	if busy then
		return
	end
	busy = true
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		busy = false
		return
	end
	const holder = create("Frame")({
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundTransparency = 1,
		create("UIAspectRatioConstraint")({ AspectRatio = 1 }),
		face(),
	}) :: Frame
	const gui = create("ScreenGui")({
		Name = "Jumpscare",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		create("Frame")({
			Name = "Shade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.15,
		}),
		holder,
	}) :: ScreenGui
	gui.Parent = playerGui

	ctx.Play("jumpscare", nil, true)
	TweenService
		:Create(holder, TweenInfo.new(POP, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(1.25, 1.25),
		})
		:Play()
	const rng = Random.new()
	const shake = RunService.RenderStepped:Connect(function()
		holder.Position = UDim2.new(0.5, rng:NextInteger(-SHAKE, SHAKE), 0.5, rng:NextInteger(-SHAKE, SHAKE))
	end)
	task.wait(HOLD)
	shake:Disconnect()
	gui:Destroy()
	busy = false
end

-- Cue handler for the `jumpscare` cue of any family A anomaly.
function Jumpscare.Cue(ctx: Effect.Context, cue: Effect.Cue)
	if cue.Cue ~= "jumpscare" or not near(ctx, cue.Entity) then
		return
	end
	Jumpscare.Show(ctx)
end

return table.freeze(Jumpscare)
