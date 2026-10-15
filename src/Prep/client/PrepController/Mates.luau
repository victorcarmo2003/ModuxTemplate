--!strict
-- Mates: the OTHER players while the focused prep mode is up (presentation only, local only; the user's request of 2026-10-12).
--   every other player   whole character hidden (LocalTransparencyModifier 1: body, head, accessories, Tool handles), their
--                        name tag (Humanoid.DisplayDistanceType) and their own billboards / emitters off
--   co-op                a colleague who works at a seat of the trailer (attribute `Working` = station, set by PrepService on
--                        the character) keeps ONE ARM visible: the right arm (R6 "Right Arm", R15 right arm parts) plus the
--                        Tool he holds (the hot dog). The arm is the real one, frozen at his seat: no pointer data travels
--                        (Rules.World.GhostHand stays false; a moving hand needs the PrepPointer packet, see prep-3d.md §10).
--                        That arm gets a Highlight in his colour and a BillboardGui with his username (Adornee = the arm).
-- Colour: Rules.World.Presence.Palette[station] (stable per seat, never red). `Mates.ColorOf(station)` is exported for UI chips.
-- The own rig is NOT handled here (Rig.luau hides it whole). Everything is restored on Release / Destroy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

export type Mates = {
	Enter: (self: Mates) -> (),
	Release: (self: Mates) -> (),
	Step: (self: Mates, dt: number) -> (),
	-- True once everything is back (nothing to restore).
	Idle: (self: Mates) -> boolean,
	Destroy: (self: Mates) -> (),
}

type Mate = {
	Model: Model,
	Player: Player,
	Body: { BasePart },
	Arm: { BasePart },
	ArmPart: BasePart?,
	ToolRoot: Instance?,
	At: number,
	BodyAlpha: number,
	ArmAlpha: number,
	Written: boolean,
	Display: Enum.HumanoidDisplayDistanceType?,
	Disabled: { [Instance]: boolean }, -- Enabled values of what we switched off
	Seat: number?,
	Gui: BillboardGui?,
	Light: Highlight?,
	ToolLight: Highlight?,
}

const rules = Content.Prep.Rules.World
const presence = rules.Presence
const FADE = 0.15
const REFRESH = 0.5 -- s: parts / tool / seat re-read
const ARM_NAMES: { [string]: boolean } = {
	["Right Arm"] = true,
	RightHand = true,
	RightLowerArm = true,
	RightUpperArm = true,
}
const SWITCHABLE = { "BillboardGui", "ParticleEmitter", "Trail", "Beam", "SurfaceGui", "Highlight" }

const Mates = {}

-- Colour of a seat (1..4 take the first palette entries); any number maps into the palette.
function Mates.ColorOf(station: number): Color3
	const palette = presence.Palette
	return palette[(math.max(station, 1) - 1) % #palette + 1]
end

local function lowQuality(): boolean
	const ok, saved = pcall(function(): any
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok then
		return false
	end
	const value = (saved :: Enum.SavedQualitySetting).Value
	return value ~= 0 and value <= rules.Budget.LowQuality
end

local function setAlpha(parts: { BasePart }, value: number)
	for _, part in parts do
		if part.Parent ~= nil and part.LocalTransparencyModifier ~= value then
			part.LocalTransparencyModifier = value
		end
	end
end

local function makeGui(mate: Mate, color: Color3, folder: Folder)
	const gui = Instance.new("BillboardGui")
	gui.Name = "MateTag"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Active = false
	gui.Size = UDim2.fromScale(presence.Tag.Width, presence.Tag.Height) -- scale = studs
	gui.StudsOffsetWorldSpace = Vector3.new(0, presence.Tag.Lift, 0)
	gui.MaxDistance = presence.Range
	gui.Adornee = mate.ArmPart :: Instance
	const card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Theme.Color.Cream
	card.BorderSizePixel = 0
	card.Parent = gui
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = card
	const stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = card
	const chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.Position = UDim2.fromScale(0.05, 0.5)
	chip.Size = UDim2.fromScale(0.16, 0.56)
	chip.SizeConstraint = Enum.SizeConstraint.RelativeYY
	chip.BackgroundColor3 = color
	chip.BorderSizePixel = 0
	chip.Parent = card
	const chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(1, 0)
	chipCorner.Parent = chip
	const chipStroke = Instance.new("UIStroke")
	chipStroke.Color = Theme.Color.Ink
	chipStroke.Thickness = 2
	chipStroke.Parent = chip
	const label = Instance.new("TextLabel")
	label.Name = "Name"
	label.AnchorPoint = Vector2.new(1, 0.5)
	label.Position = UDim2.fromScale(0.96, 0.5)
	label.Size = UDim2.fromScale(0.68, 0.7)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font.Title
	label.Text = mate.Player.Name
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.Color.Ink
	label.Parent = card
	gui.Parent = folder
	mate.Gui = gui
end

local function makeLight(adornee: Instance, color: Color3, folder: Folder): Highlight
	const light = Instance.new("Highlight")
	light.Name = "MateLight"
	light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	light.FillColor = color
	light.FillTransparency = presence.Fill
	light.OutlineColor = color
	light.OutlineTransparency = 0
	light.Adornee = adornee
	light.Parent = folder
	return light
end

function Mates.new(): Mates
	const folder = Instance.new("Folder")
	folder.Name = "PrepMates"
	local entered = false
	local released = false
	local lights = 0
	const low = lowQuality()
	const tracked: { [Model]: Mate } = {}

	local function classify(mate: Mate)
		const body: { BasePart } = {}
		const arm: { BasePart } = {}
		local armPart: BasePart? = nil
		local toolRoot: Instance? = nil
		for _, descendant in mate.Model:GetDescendants() do
			if descendant:IsA("BasePart") then
				const tool = descendant:FindFirstAncestorOfClass("Tool")
				if tool ~= nil and tool.Parent == mate.Model then
					table.insert(arm, descendant)
					toolRoot = tool
				elseif ARM_NAMES[descendant.Name] and descendant.Parent == mate.Model then
					table.insert(arm, descendant)
					if armPart == nil or descendant.Name == "Right Arm" or descendant.Name == "RightUpperArm" then
						armPart = descendant
					end
				else
					table.insert(body, descendant)
				end
			end
		end
		mate.Body, mate.Arm, mate.ArmPart, mate.ToolRoot = body, arm, armPart, toolRoot
		-- own billboards / emitters of that character stay off while the mode is up
		if not released then
			for _, descendant in mate.Model:GetDescendants() do
				for _, class in SWITCHABLE do
					if descendant:IsA(class) and mate.Disabled[descendant] == nil then
						const item = descendant :: any
						mate.Disabled[descendant] = item.Enabled
						item.Enabled = false
						break
					end
				end
			end
		end
	end

	local function restoreDisabled(mate: Mate)
		for instance, value in mate.Disabled do
			if instance.Parent ~= nil then
				(instance :: any).Enabled = value
			end
		end
		table.clear(mate.Disabled)
	end

	local function dropUi(mate: Mate)
		if mate.Gui ~= nil then
			mate.Gui:Destroy()
			mate.Gui = nil
		end
		if mate.Light ~= nil then
			mate.Light:Destroy()
			mate.Light = nil
			lights -= 1
		end
		if mate.ToolLight ~= nil then
			mate.ToolLight:Destroy()
			mate.ToolLight = nil
			lights -= 1
		end
	end

	local function forget(model: Model, mate: Mate)
		dropUi(mate)
		restoreDisabled(mate)
		setAlpha(mate.Body, 0)
		setAlpha(mate.Arm, 0)
		if mate.Display ~= nil then
			const humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid ~= nil then
				humanoid.DisplayDistanceType = mate.Display
			end
			mate.Display = nil
		end
		tracked[model] = nil
	end

	-- the arm UI of a seated colleague: re-synced at REFRESH (tool in / out, seat change)
	local function syncUi(mate: Mate)
		const armPart = mate.ArmPart
		const seated = mate.Seat ~= nil and armPart ~= nil and not released
		if not seated then
			dropUi(mate)
			return
		end
		const color = Mates.ColorOf(mate.Seat :: number)
		if mate.Gui == nil then
			makeGui(mate, color, folder)
		else
			mate.Gui.Adornee = armPart :: Instance
		end
		if low then
			return
		end
		if mate.Light == nil and lights < presence.Highlights then
			mate.Light = makeLight(armPart :: BasePart, color, folder)
			lights += 1
		elseif mate.Light ~= nil then
			mate.Light.Adornee = armPart
		end
		if mate.ToolRoot ~= nil then
			if mate.ToolLight == nil and lights < presence.Highlights then
				mate.ToolLight = makeLight(mate.ToolRoot, color, folder)
				lights += 1
			elseif mate.ToolLight ~= nil then
				mate.ToolLight.Adornee = mate.ToolRoot
			end
		elseif mate.ToolLight ~= nil then
			mate.ToolLight:Destroy()
			mate.ToolLight = nil
			lights -= 1
		end
	end

	local function refresh(now: number)
		const seen: { [Model]: boolean } = {}
		for _, player in Players:GetPlayers() do
			const model = player.Character
			if player == Players.LocalPlayer or model == nil or model.Parent == nil then
				continue
			end
			seen[model] = true
			local mate = tracked[model]
			if mate == nil then
				mate = {
					Model = model,
					Player = player,
					Body = {},
					Arm = {},
					ArmPart = nil,
					ToolRoot = nil,
					At = -1,
					BodyAlpha = 0,
					ArmAlpha = 0,
					Written = false,
					Display = nil,
					Disabled = {},
					Seat = nil,
				} :: Mate
				tracked[model] = mate
			end
			const entry = mate :: Mate
			if now - entry.At >= REFRESH then
				entry.At = now
				classify(entry)
				const working = model:GetAttribute("Working")
				entry.Seat = if type(working) == "number" then working else nil
				syncUi(entry)
			end
			const humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid ~= nil and entry.Display == nil and not released then
				entry.Display = humanoid.DisplayDistanceType
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
		for model, mate in tracked do
			if not seen[model] or model.Parent == nil then
				forget(model, mate)
			end
		end
	end

	local judgeIn = 0
	const self = {} :: any

	function self.Enter(_: any)
		entered = true
		released = false
		judgeIn = 0
		folder.Parent = workspace.CurrentCamera
	end
	function self.Release(_: any)
		released = true
		for _, mate in tracked do
			dropUi(mate)
		end
	end
	function self.Step(_: any, dt: number)
		if not entered then
			return
		end
		judgeIn -= dt
		if judgeIn <= 0 then
			judgeIn = REFRESH / 2
			refresh(os.clock())
		end
		const rate = dt / FADE
		local busy = false
		for model, mate in tracked do
			const bodyTarget = if released then 0 else 1
			const armTarget = if released or mate.Seat ~= nil then 0 else 1
			mate.BodyAlpha = if mate.BodyAlpha < bodyTarget then math.min(mate.BodyAlpha + rate, bodyTarget) else math.max(mate.BodyAlpha - rate, bodyTarget)
			mate.ArmAlpha = if mate.ArmAlpha < armTarget then math.min(mate.ArmAlpha + rate, armTarget) else math.max(mate.ArmAlpha - rate, armTarget)
			setAlpha(mate.Body, mate.BodyAlpha)
			setAlpha(mate.Arm, mate.ArmAlpha)
			if released and mate.BodyAlpha == 0 and mate.ArmAlpha == 0 then
				forget(model, mate)
			elseif mate.BodyAlpha > 0 or mate.ArmAlpha > 0 then
				busy = true
			end
		end
		if released and not busy then
			entered = false
			folder.Parent = nil
		end
	end
	function self.Idle(_: any): boolean
		return not entered
	end
	function self.Destroy(_: any)
		for model, mate in tracked do
			forget(model, mate)
		end
		entered = false
		folder.Parent = nil
	end
	return self :: Mates
end

return Mates
