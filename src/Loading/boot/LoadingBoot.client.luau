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
]]
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
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
const COMPONENTS = { "LoadingScreen", "Theme", "Icons", "Motion", "CartoonPanel", "CartoonLabel" }
const BACKDROP = Color3.fromHex("#F6B71B")
const INK = Color3.fromHex("#2B2233")

ReplicatedFirst:RemoveDefaultLoadingScreen()

const player = Players.LocalPlayer
const playerGui = player:WaitForChild("PlayerGui")

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

gui.Parent = playerGui

local lifted = false
local unmount: (() -> ())? = nil
-- kit mounted: its Shown source (false = lift)
local shown: ((boolean?) -> boolean)? = nil

local function finish()
	if lifted then
		return
	end
	lifted = true
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
		const stop, frame = Vide.root(function()
			return LoadingScreen({
				Name = "Screen",
				Progress = progress,
				Status = status,
				Tips = Tips.Tips,
				Title = Tips.Title,
				Tagline = Tips.Tagline,
				Shown = visible,
			})
		end)
		frame.ZIndex = 2
		frame.Parent = gui
		unmount = stop
		shown = visible
		cover.Visible = false
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
