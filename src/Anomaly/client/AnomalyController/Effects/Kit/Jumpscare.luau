--!strict
--[[
	V2 jumpscare (DEC-255, DEC-256; TASK-269; anomalies-v2-proposal.md §2.4). The server sends the cue `jumpscare`
	(Entity = actor NpcId) when someone takes the order of an odd customer; every player whose character is within
	RANGE studs of the actor sees a cartoon monster face full screen for ~0.6 s with the `jumpscare` sound (Scare cap,
	DEC-173). The faint itself is the server's (VitalService:Fall ~0.7 s after the cue): nothing is decided here.

	Cartoon and Mild (DEC-172, DEC-256): an Ink-dark head with two huge white eyes and a wide toothy grin, no blood,
	no alert red, no strobe. The face is FACE_IMAGE (Assets/textures/ui/fx/jumpscare_face.png, drawn by
	tools/icons/jumpscare_face.py in the UI sticker style, 2026-10-15). A `Jumpscare_Face` ImageLabel anywhere under
	ReplicatedStorage.Assets still wins; the Frames drawing is the last fallback (empty FACE_IMAGE).

	Kept warm (owner 2026-10-20: on slower PCs the first jumpscare showed nothing): the ScreenGui is built once at
	start and never destroyed; a KEEP copy of the face is always drawn, so the texture stays resident after the
	loading screen preloaded it. Show only flips the stage on, and waits up to LOAD_WAIT for a face still loading.
	Sharp on console / TV (owner 2026-10-20: "no Xbox fica tudo pixelado"): the engine streams a texture at the mip its
	largest drawn copy needs, and the KEEP copy used to be 1 px, so only a tiny mip stayed resident and the 0.6 s scare
	showed it blown up. The KEEP copy is now drawn at the face's full on-screen size (KEEP_SCALE of the screen height),
	nearly transparent, so the full-resolution mip is the one kept in memory.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Parent.Effect)
local Watch = require(script.Parent.Watch)
local Haptics = require(game:GetService("StarterPlayer").StarterPlayerScripts.client.Input.Haptics)

const create = Vide.create
-- the type definitions miss UIStroke in Vide.create's class list (same workaround as BossController)
const createRaw = Vide.create :: any

const RANGE = 24 -- studs from the actor: the counter and the trailer
const HOLD = 0.6 -- s on screen (DEC-256)
const POP = 0.12 -- s of the zoom-in
const SHAKE = 18 -- px of screen jitter while it holds
const FACE_NAME = "Jumpscare_Face"
const FACE_IMAGE = "rbxassetid://106866610219471" -- jumpscare_face.png: black face, white eyes, macabre grin (TASK-329, 2026-10-15)
const INK = Color3.fromHex("#2B2233") -- Theme Ink: the house outline colour, never alert red
const SKIN = Color3.fromHex("#4A3F55")
const WHITE = Color3.fromHex("#FFFFFF")
const TEETH = 7
const LOAD_WAIT = 0.35 -- s Show waits for a face image still loading (the faint comes ~0.7 s after the cue)
const KEEP_TRANSPARENCY = 0.995 -- the warm copy: drawn (texture kept in memory at full mip) but not visible
const KEEP_SCALE = 0.75 -- of the screen height: the face at the end of the pop (holder 0.6 x 1.25)

const Jumpscare = {}

type Stage = {
	Gui: ScreenGui,
	Stage: Frame,
	Holder: Frame,
	Face: GuiObject,
}

local busy = false
local built: Stage? = nil

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
	if FACE_IMAGE ~= "" then
		return create("ImageLabel")({
			Name = "Head",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = FACE_IMAGE,
			ScaleType = Enum.ScaleType.Fit,
		}) :: ImageLabel
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

-- true when the local character stands within RANGE of the actor (actor not streamed in = too far: no scare). A player
-- watching the security cameras is not "there" (TASK-337): the body is at the monitor, the eyes on a screen.
local function near(ctx: Effect.Context, npcId: number): boolean
	if Watch.Watching() then
		return false
	end
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	const model = ctx.Npc(npcId)
	if root == nil or not root:IsA("BasePart") or model == nil then
		return false
	end
	return (model:GetPivot().Position - root.Position).Magnitude <= RANGE
end

-- The one jumpscare ScreenGui, built on first need and kept: the stage hidden, the full-size warm copy always drawn.
local function stage(): Stage?
	if built ~= nil and built.Gui.Parent ~= nil then
		return built
	end
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	const head = face()
	const holder = create("Frame")({
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundTransparency = 1,
		create("UIAspectRatioConstraint")({ AspectRatio = 1 }),
		head,
	}) :: Frame
	const frame = create("Frame")({
		Name = "Stage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		create("Frame")({
			Name = "Shade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.15,
		}),
		holder,
	}) :: Frame
	const gui = create("ScreenGui")({
		Name = "Jumpscare",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ClipToDeviceSafeArea = false,
		DisplayOrder = 50,
		frame,
	}) :: ScreenGui
	if head:IsA("ImageLabel") then
		const keep = head:Clone()
		keep.Name = "Keep"
		keep.AnchorPoint = Vector2.new(0.5, 0.5)
		keep.Position = UDim2.fromScale(0.5, 0.5)
		keep.Size = UDim2.fromScale(KEEP_SCALE, KEEP_SCALE)
		keep.SizeConstraint = Enum.SizeConstraint.RelativeYY
		keep.ScaleType = Enum.ScaleType.Fit
		keep.ImageTransparency = KEEP_TRANSPARENCY
		keep.Active = false
		keep.Selectable = false
		keep.Parent = gui
	end
	gui.Parent = playerGui
	built = { Gui = gui, Stage = frame, Holder = holder, Face = head }
	return built
end

-- Builds the gui ahead of the first scare (called at require; PlayerGui may come a moment later).
function Jumpscare.Warm()
	task.spawn(function()
		Players.LocalPlayer:WaitForChild("PlayerGui")
		stage()
	end)
end

-- Shows the face once (one at a time). Yields for ~HOLD s.
function Jumpscare.Show(ctx: Effect.Context)
	if busy then
		return
	end
	busy = true
	const parts = stage()
	if parts == nil then
		busy = false
		return
	end
	const head = parts.Face
	if head:IsA("ImageLabel") and not head.IsLoaded then
		const deadline = os.clock() + LOAD_WAIT
		while not head.IsLoaded and os.clock() < deadline do
			RunService.RenderStepped:Wait()
		end
	end
	const holder = parts.Holder
	holder.Size = UDim2.fromScale(0.6, 0.6)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	parts.Stage.Visible = true

	ctx.Play("jumpscare", nil, true)
	Haptics.Play("Scare") -- strong and short, own player only (TASK-268)
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
	parts.Stage.Visible = false
	busy = false
end

-- Cue handler for the `jumpscare` cue of any family A anomaly.
-- Only the player who pays sees it (owner 2026-10-20): with cue.User (the server names him) nobody else does, near or
-- not; an old cue without User keeps the range rule.
function Jumpscare.Cue(ctx: Effect.Context, cue: Effect.Cue)
	if cue.Cue ~= "jumpscare" then
		return
	end
	if cue.User ~= nil then
		if cue.User ~= Players.LocalPlayer.UserId or Watch.Watching() then
			return
		end
	elseif not near(ctx, cue.Entity) then
		return
	end
	Jumpscare.Show(ctx)
end

Jumpscare.Warm()

return table.freeze(Jumpscare)
