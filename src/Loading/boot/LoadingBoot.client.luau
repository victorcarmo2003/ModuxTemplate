--!strict
--[[
	LoadingBoot (ReplicatedFirst.LoadingBoot): the first thing the client runs. Removes the stock Roblox loading screen and puts
	up our own curtain right away, before the rest of the game has replicated:

	  1. an instant cover (plain instances, no dependency: Mustard backdrop + title), this very frame;
	  2. as soon as Vide and the kit have replicated, the animated cartoon LoadingScreen component on top of it
	     (Interface/Components/LoadingScreen: hot dog, title, real progress bar, step, rotating tips).

	The ScreenGui "LoadingScreen" (PlayerGui, DisplayOrder above everything, ResetOnSpawn off) is the contract with
	LoadingController (Modux, client), which writes its attributes:
	  Progress  number 0..1   real progress of the loading steps
	  Status    string        current step
	  Done      boolean       true = lift the curtain; this script then destroys the ScreenGui
	Before the controller exists the bar shows the engine join (game:IsLoaded) only. Safety: HARD_CAP s without Done
	lifts the curtain anyway (a broken boot never leaves the player behind a loading screen).
	Skip (playtest 2026-10-14): after SKIP_AFTER s with the curtain still down, a "Skip loading" button shows in the bottom
	right corner (LoadingScreen Skip; a plain one on the instant cover if the kit never mounted). Click, tap or gamepad
	ButtonX lifts the curtain at once and sets the local attribute LoadingSkipped = true on the LocalPlayer (and
	Skipped on the ScreenGui): LoadingController lets the player in (ClientReady, Ready) while its steps keep loading
	in the background.
]]
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
-- texts: src/Loading/replicatedfirst/Tips.luau (ReplicatedFirst.client.Loading.Tips, replicated with this script).
-- This file sits in src/Loading/boot, mapped by .rogen.json straight into ReplicatedFirst (rogen would route any
-- *.client.luau to StarterPlayerScripts, too late for a loading screen).
type Texts = {
	Title: string,
	Tagline: string,
	Tips: { string },
	Status: { [string]: string },
}
const Tips = (require :: any)(ReplicatedFirst:WaitForChild("client"):WaitForChild("Loading"):WaitForChild("Tips")) :: Texts

const GUI_NAME = "LoadingScreen"
const DISPLAY_ORDER = 1000 -- above HUD, cutscene fade (51/52) and everything else
const WAIT = 30 -- s for one dependency of the kit to replicate
const HARD_CAP = 120 -- s without Done before the curtain lifts anyway
const LIFT_TIME = 0.9 -- s of the curtain lift before the gui is destroyed
const BOOT_PROGRESS = 0.04 -- the bar before the engine join finishes
const JOIN_PROGRESS = 0.1 -- the bar once game:IsLoaded() (until the controller writes its own)
const COMPONENTS = {
	"LoadingScreen",
	"Theme",
	"Icons",
	"Motion",
	"CartoonPanel",
	"CartoonLabel",
	"CartoonButton",
	"KeyChip",
}
const SKIP_AFTER = 10 -- s of curtain before "Skip loading" shows
const SKIP_KEY = Enum.KeyCode.ButtonX -- gamepad key of the skip button (its chip reads SKIP_CHIP)
const SKIP_CHIP = "X"
const SKIP_TEXT = "Skip loading"
const SKIPPED_ATTRIBUTE = "LoadingSkipped" -- on the LocalPlayer (local only), read by LoadingController
const BACKDROP = Color3.fromHex("#F6B71B")
const INK = Color3.fromHex("#2B2233")

-- Only the ReplicatedFirst copy runs: a stale copy left in StarterPlayerScripts by an old sync made a second curtain
-- that nothing lifted (2026-10-11). One curtain per player, whoever comes second leaves.
if not script:IsDescendantOf(ReplicatedFirst) then
	return
end

ReplicatedFirst:RemoveDefaultLoadingScreen()

const player = Players.LocalPlayer
const playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild(GUI_NAME) then
	return
end

const gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = DISPLAY_ORDER
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui:SetAttribute("Progress", 0)
gui:SetAttribute("Status", Tips.Status.Boot)
gui:SetAttribute("Done", false)

-- 1. instant cover --------------------------------------------------------------------------------------------------
const cover = Instance.new("Frame")
cover.Name = "Cover"
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundColor3 = BACKDROP
cover.BorderSizePixel = 0
cover.Active = true
cover.ZIndex = 1
cover.Parent = gui

const coverTitle = Instance.new("TextLabel")
coverTitle.Name = "Title"
coverTitle.AnchorPoint = Vector2.new(0.5, 0.5)
coverTitle.Position = UDim2.fromScale(0.5, 0.45)
coverTitle.Size = UDim2.new(0.8, 0, 0, 60)
coverTitle.BackgroundTransparency = 1
coverTitle.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
coverTitle.Text = Tips.Title
coverTitle.TextSize = 48
coverTitle.TextColor3 = Color3.new(1, 1, 1)
coverTitle.Parent = cover
const coverStroke = Instance.new("UIStroke")
coverStroke.Color = INK
coverStroke.Thickness = 4
coverStroke.LineJoinMode = Enum.LineJoinMode.Round
coverStroke.Parent = coverTitle

-- free cursor while loading: a visible Modal button overrides the first-person / POV mouse lock; destroyed on lift
const cursor = Instance.new("TextButton")
cursor.Name = "FreeCursor"
cursor.Modal = true
cursor.Text = ""
cursor.BackgroundTransparency = 1
cursor.AutoButtonColor = false
cursor.Selectable = false
cursor.Size = UDim2.fromScale(0, 0)
cursor.Parent = gui

-- plain skip on the instant cover (the cartoon one replaces it when the kit mounts)
const coverSkip = Instance.new("TextButton")
coverSkip.Name = "Skip"
coverSkip.AnchorPoint = Vector2.new(1, 1)
coverSkip.Position = UDim2.new(1, -24, 1, -34)
coverSkip.Size = UDim2.fromOffset(184, 48)
coverSkip.BackgroundColor3 = Color3.fromHex("#FFF4DC")
coverSkip.AutoButtonColor = true
coverSkip.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
coverSkip.Text = SKIP_TEXT
coverSkip.TextSize = 18
coverSkip.TextColor3 = INK
coverSkip.Visible = false
coverSkip.ZIndex = 3
coverSkip.Parent = cover
const coverSkipCorner = Instance.new("UICorner")
coverSkipCorner.CornerRadius = UDim.new(0.5, 0)
coverSkipCorner.Parent = coverSkip
const coverSkipStroke = Instance.new("UIStroke")
coverSkipStroke.Color = INK
coverSkipStroke.Thickness = 3
coverSkipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
coverSkipStroke.Parent = coverSkip

gui.Parent = playerGui

local lifted = false
local unmount: (() -> ())? = nil
-- kit mounted: its Shown source (false = lift)
local shown: ((boolean?) -> boolean)? = nil
-- kit mounted: its skip Visible source and the key chip text
local skipShown: ((boolean?) -> boolean)? = nil
local skipKey: ((string?) -> string)? = nil
local skippable = false
local skipInput: RBXScriptConnection? = nil
local lastInput: RBXScriptConnection? = nil

local function finish()
	if lifted then
		return
	end
	lifted = true
	cursor:Destroy()
	if skipInput ~= nil then
		skipInput:Disconnect()
	end
	if lastInput ~= nil then
		lastInput:Disconnect()
	end
	const setShown = shown
	if setShown ~= nil then
		setShown(false)
	else
		cover.Visible = false
	end
	task.delay(LIFT_TIME, function()
		const stop = unmount
		unmount = nil
		if stop ~= nil then
			pcall(stop)
		end
		gui:Destroy()
	end)
end

gui:GetAttributeChangedSignal("Done"):Connect(function()
	if gui:GetAttribute("Done") == true then
		finish()
	end
end)
task.delay(HARD_CAP, function()
	if not lifted then
		warn(`[Loading] no Done after {HARD_CAP} s: lifting the loading screen anyway`)
		finish()
	end
end)

-- Skip loading ----------------------------------------------------------------------------------------------------
local function isGamepad(inputType: Enum.UserInputType): boolean
	return string.find(inputType.Name, "Gamepad", 1, true) ~= nil
end

-- the chip of the gamepad key while the last input was a gamepad; that button also takes the gamepad selection
local function refreshSkipKey()
	const gamepad = isGamepad(UserInputService:GetLastInputType())
	const setKey = skipKey
	if setKey ~= nil then
		setKey(if gamepad then SKIP_CHIP else "")
	end
	if gamepad and skippable and not lifted then
		const button = gui:FindFirstChild("SkipButton", true) or coverSkip
		if button ~= nil and button:IsA("GuiObject") and button.Visible then
			pcall(function()
				GuiService.SelectedObject = button
			end)
		end
	end
end

local function skip()
	if lifted or not skippable then
		return
	end
	player:SetAttribute(SKIPPED_ATTRIBUTE, true)
	gui:SetAttribute("Skipped", true)
	if GuiService.SelectedObject ~= nil and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	finish()
end

local function showSkip()
	if lifted then
		return
	end
	skippable = true
	coverSkip.Visible = true
	const setShown = skipShown
	if setShown ~= nil then
		setShown(true)
	end
	skipInput = UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == SKIP_KEY then
			skip()
		end
	end)
	lastInput = UserInputService.LastInputTypeChanged:Connect(refreshSkipKey)
	refreshSkipKey()
end

coverSkip.Activated:Connect(skip)
task.delay(SKIP_AFTER, showSkip)

-- 2. the cartoon kit, once it replicated ---------------------------------------------------------------------------
local function waitPath(root: Instance, path: { string }): Instance?
	local node: Instance? = root
	for _, name in path do
		if node == nil then
			return nil
		end
		node = node:WaitForChild(name, WAIT)
	end
	return node
end

task.spawn(function()
	const packages = waitPath(ReplicatedStorage, { "Packages", "Vide" })
	const components = waitPath(StarterPlayer, { "StarterPlayerScripts", "client", "Interface", "Components" })
	if packages == nil or components == nil or lifted then
		return
	end
	for _, name in COMPONENTS do
		if components:WaitForChild(name, WAIT) == nil then
			return
		end
	end
	const ok, problem = pcall(function()
		const Vide = (require :: any)(packages)
		const LoadingScreen = (require :: any)(components:FindFirstChild("LoadingScreen"))
		if lifted then
			return
		end
		const start = gui:GetAttribute("Progress")
		const progress = Vide.source(math.max(if type(start) == "number" then start else 0, BOOT_PROGRESS))
		const status = Vide.source(gui:GetAttribute("Status") or Tips.Status.Boot)
		const visible = Vide.source(true)
		const skipVisible = Vide.source(skippable)
		const skipLabel = Vide.source("")
		const stop, frame = Vide.root(function()
			return LoadingScreen({
				Name = "Screen",
				Progress = progress,
				Status = status,
				Tips = Tips.Tips,
				Title = Tips.Title,
				Tagline = Tips.Tagline,
				Shown = visible,
				Skip = {
					Visible = skipVisible,
					KeyLabel = skipLabel,
					Text = SKIP_TEXT,
					OnSkip = skip,
				},
			})
		end)
		frame.ZIndex = 2
		frame.Parent = gui
		unmount = stop
		shown = visible
		skipShown = skipVisible
		skipKey = skipLabel
		cover.Visible = false
		refreshSkipKey()
		gui:GetAttributeChangedSignal("Progress"):Connect(function()
			const value = gui:GetAttribute("Progress")
			if type(value) == "number" then
				progress(value)
			end
		end)
		gui:GetAttributeChangedSignal("Status"):Connect(function()
			const value = gui:GetAttribute("Status")
			if type(value) == "string" then
				status(value)
			end
		end)
		-- the engine join, until the controller writes its own progress
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		const now = gui:GetAttribute("Progress")
		if type(now) ~= "number" or now < JOIN_PROGRESS then
			progress(JOIN_PROGRESS)
		end
	end)
	if not ok then
		warn(`[Loading] cartoon loading screen unavailable, plain cover kept: {problem}`)
	end
end)
