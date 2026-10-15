--!strict
-- The CCTV monitor screen in the world (TASK-285; owner request 2026-10-14: "enfeite o monitor"). A local SurfaceGui (PlayerGui,
-- Adornee = the screen Part of the monitor) replaces the authored "CAMERAS" card while it lives, in the same green and font:
--   channel loop   CAM 1 -> CAM 2 every Rules.Channel s with a short static burst between them (while someone watches here,
--                  it holds the camera being watched and says LIVE)
--   REC            Mustard dot blinking (never red), grain jumping, scanlines crawling, a bright band rolling, the game clock
-- It animates at TICK_HZ only while the camera is within NEAR studs of the monitor (otherwise it freezes on its last frame).
-- The authored SurfaceGui is only disabled locally, and comes back if the local one goes away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)

const security = Content.Security
const rules = security.Rules
const textures = security.Textures

const create = Vide.create
const source = Vide.source
const untrack = Vide.untrack
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const TICK_HZ = 15
const NEAR = 60 -- studs from the camera to animate
const BURST = 0.3 -- s of static between two channels
const PIXELS_PER_STUD = 200
const RESOLVE_EVERY = 2 -- s between two lookups of the monitor (streaming, the move into the folder)
const GREEN = Color3.fromRGB(0, 112, 22) -- the authored card colour
const DEEP = Color3.fromRGB(4, 42, 14)
const PHOSPHOR = Color3.fromRGB(196, 255, 200)
const MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
const TITLE = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

export type Owner = {
	Open: () -> boolean, -- this client watches the cameras
	Cam: () -> string, -- Key of the camera watched
	Clock: () -> string,
}

const Screen = {}

local function hash(n: number, salt: number): number
	const x = math.sin(n * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- The monitor's screen Part: in the security folder, else a loose monitor model.
local function findScreen(): BasePart?
	const folder = workspace:FindFirstChild(rules.Folder)
	const monitor = (if folder ~= nil then folder:FindFirstChild(rules.Monitor) else nil) or workspace:FindFirstChild(rules.Monitor)
	const screen = if monitor ~= nil then monitor:FindFirstChild(rules.Screen) else nil
	return if screen ~= nil and screen:IsA("BasePart") then screen else nil
end

local function build(screen: BasePart, owner: Owner, time: () -> number): SurfaceGui
	const channel = function(): number
		return math.floor(time() / rules.Channel)
	end
	const burst = function(): number
		if owner.Open() then
			return 0
		end
		const into = time() % rules.Channel
		return if into < BURST then 1 - into / BURST else 0
	end
	const label = function(): string
		if owner.Open() then
			const cam = security.Cams.ByKey[owner.Cam()]
			return if cam ~= nil then cam.Label else ""
		end
		const list = security.Cams.List
		return list[channel() % #list + 1].Label
	end
	const tick = function(): number
		return math.floor(time() * TICK_HZ)
	end

	return create("SurfaceGui")({
		Name = "SecurityScreen",
		Adornee = screen,
		Face = rules.Face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		LightInfluence = 0,
		Brightness = 1.4,
		ResetOnSpawn = false,
		ClipsDescendants = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		create("Frame")({
			Name = "Back",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = GREEN,
			BorderSizePixel = 0,
			createRaw("UIGradient")({
				Rotation = 90,
				Color = ColorSequence.new(GREEN, DEEP),
			}),
		}),
		-- grain (stronger during the channel burst)
		create("ImageLabel")({
			Name = "Grain",
			Size = UDim2.new(1, 256, 1, 256),
			Position = function()
				const n = tick()
				return UDim2.fromOffset(-math.floor(hash(n, 3) * 256), -math.floor(hash(n, 9) * 256))
			end,
			BackgroundTransparency = 1,
			Image = textures.Noise,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(128, 128),
			ImageColor3 = PHOSPHOR,
			ImageTransparency = function()
				return 1 - math.clamp(0.18 + burst() * 0.8, 0, 0.95)
			end,
			ZIndex = 2,
		}),
		create("ImageLabel")({
			Name = "Scanlines",
			Size = UDim2.new(1, 0, 1, 8),
			Position = function()
				return UDim2.fromOffset(0, -8 + (time() * 16) % 8)
			end,
			BackgroundTransparency = 1,
			Image = textures.Scanlines,
			ImageColor3 = Color3.new(0, 0, 0),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(8, 8),
			ImageTransparency = 0.65,
			ZIndex = 3,
		}),
		create("Frame")({
			Name = "Band",
			Size = UDim2.fromScale(1, 0.18),
			Position = function()
				return UDim2.fromScale(0, (time() / 4) % 1 * 1.4 - 0.2)
			end,
			BackgroundColor3 = PHOSPHOR,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			ZIndex = 4,
			createRaw("UIGradient")({
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		}),
		create("TextLabel")({
			Name = "Title",
			Position = UDim2.fromOffset(24, 16),
			Size = UDim2.fromOffset(400, 44),
			BackgroundTransparency = 1,
			FontFace = TITLE,
			TextSize = 38,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "CAMERAS",
			ZIndex = 6,
		}),
		create("Frame")({
			Name = "Rec",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -112, 0, 26),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Color3.fromHex("#F6C12B"),
			BorderSizePixel = 0,
			BackgroundTransparency = function()
				return if time() % rules.Rec < rules.Rec / 2 then 0 else 1
			end,
			ZIndex = 6,
			createRaw("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),
		create("TextLabel")({
			Name = "RecText",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -24, 0, 16),
			Size = UDim2.fromOffset(80, 44),
			BackgroundTransparency = 1,
			FontFace = MONO,
			TextSize = 36,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.new(1, 1, 1),
			Text = function()
				return if owner.Open() then "LIVE" else "REC"
			end,
			ZIndex = 6,
		}),
		create("TextLabel")({
			Name = "Channel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(0.9, 0.4),
			BackgroundTransparency = 1,
			FontFace = MONO,
			TextSize = 120,
			TextColor3 = PHOSPHOR,
			TextStrokeColor3 = DEEP,
			TextStrokeTransparency = 0.3,
			Text = label,
			TextTransparency = function()
				return burst() * 0.9
			end,
			ZIndex = 6,
		}),
		create("TextLabel")({
			Name = "Clock",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 24, 1, -14),
			Size = UDim2.fromOffset(360, 40),
			BackgroundTransparency = 1,
			FontFace = MONO,
			TextSize = 32,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = owner.Clock,
			ZIndex = 6,
		}),
		create("TextLabel")({
			Name = "Hint",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24, 1, -14),
			Size = UDim2.fromOffset(360, 40),
			BackgroundTransparency = 1,
			FontFace = MONO,
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = PHOSPHOR,
			Text = function()
				return `CH {channel() % #security.Cams.List + 1}/{#security.Cams.List}`
			end,
			ZIndex = 6,
		}),
	}) :: SurfaceGui
end

-- Starts the screen: looks the monitor up every RESOLVE_EVERY s, mounts the local SurfaceGui on it and ticks it while near.
function Screen.start(owner: Owner)
	const player = Players.LocalPlayer
	const time = source(os.clock())
	local screen: BasePart? = nil
	local gui: SurfaceGui? = nil
	local stop: (() -> ())? = nil
	local hidden: { SurfaceGui } = {}
	local nextResolve = 0
	local nextTick = 0

	local function release()
		if stop ~= nil then
			stop()
			stop = nil
		end
		gui = nil
		for _, authored in hidden do
			if authored.Parent ~= nil then
				authored.Enabled = true
			end
		end
		table.clear(hidden)
	end

	local function attach(part: BasePart)
		release()
		const playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui == nil then
			return
		end
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceGui") and child.Enabled then
				child.Enabled = false
				table.insert(hidden, child)
			end
		end
		stop = Vide.root(function(destroy)
			const made = build(part, owner, time)
			made.Parent = playerGui
			gui = made
			Vide.cleanup(function()
				made:Destroy()
			end)
			return destroy
		end)
	end

	RunService.Heartbeat:Connect(function()
		const now = os.clock()
		if now >= nextResolve then
			nextResolve = now + RESOLVE_EVERY
			const found = findScreen()
			if found ~= screen or (found ~= nil and gui == nil) then
				screen = found
				if found ~= nil then
					attach(found)
				else
					release()
				end
			end
		end
		const part = screen
		if part == nil or gui == nil or now < nextTick then
			return
		end
		nextTick = now + 1 / TICK_HZ
		const camera = workspace.CurrentCamera
		if camera ~= nil and (camera.CFrame.Position - part.Position).Magnitude > NEAR and not untrack(owner.Open) then
			return
		end
		time(now)
	end)
end

return Screen
