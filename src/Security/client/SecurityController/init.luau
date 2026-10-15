--!strict
--[[
	SecurityController (TASK-285; FEAT-040; owner request 2026-10-14; Provisional)

	The client of the security cameras. The CCTV monitor of the trailer has the prompt `Prompt_Cameras` (watch_cameras, made by
	SecurityService); when the server accepts it (`SecurityOpen`, the body is frozen meanwhile) the view cuts to a camera:

	  View      CameraController Prep mode (a scripted cut, Travel 0) on the PIVOT of the camera model
	            (`Workspace.<Folder>.<Cam.Model>`, Content.Security; the owner stored his camera CFrame in the pivot), with the
	            camera's Fov. A small hand-held drift (Look.Wobble) runs through PrepGoal every frame. The own rig is left alone
	            (the body stays at the monitor, so it shows on a camera that sees the trailer).
	  Looks     Normal: light grain + stamps. Night (night vision): green ColorCorrectionEffect (local, under Lighting), heavy
	            grain, scanlines, vignette, rolling band, and a local infrared illuminator (a PointLight at the eye that only
	            this client sees) so the dark street reads. Numbers in Content.Security.Looks.
	  Switch    1 / 2 (gamepad LB / RB, arrows) pick a camera, N (gamepad Y) toggles Night / Normal; each switch fires a short
	            static burst (Rules.Switch). Buttons on screen do the same (touch).
	  Leave     Q / Backspace (gamepad B) or the Exit button: the view cuts back to the head (first person comes back through the
	            CameraController driver) and `SecurityLeave` releases the freeze. A life state other than Active leaves too;
	            a camera takeover (cutscene) drops the mode without touching the camera.
	  Isolate   Hud, TouchGui, the Roblox hotbar and the chat window hidden (restored), input context `Menu`, world prompts gated
	            (PromptController:AddGate("Security")).

	Anomaly hook: the LocalPlayer attributes `SecurityView` ("" | "Normal" | "Night") and `SecurityCam` (Cam Key, "" outside).
	Read them in the AnomalyController (GetAttributeChangedSignal) to show a sign only, or more, in night vision. No anomaly
	rule depends on them (presentation only).

	The CCTV screen in the world (channel loop, REC, grain, clock) is Screen.luau.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local TextChatService = game:GetService("TextChatService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local SecurityFeed = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SecurityFeed)
local Screen = require(script.Screen)

const untrack = Vide.untrack
const security = Content.Security
const rules = security.Rules

const GATE = "Security"
const EFFECT_NAME = "SecurityLook"
const LOOK_AHEAD = 20 -- studs: the point the camera looks at, along the pivot
const WOBBLE_SPEED = 0.7 -- Hz of the hand-held drift

type Saved = { [string]: any }

const SecurityController = Modux.Controller("SecurityController", {
	Require = { "CameraController", "VitalController", "InputController", "PromptController", "RoundController" },
	Priority = 600,
})

function SecurityController:Setup()
	self.Open = Vide.source(false) :: Vide.Source<boolean>
	self.Cam = Vide.source(security.Cams.List[1].Key) :: Vide.Source<string>
	self.View = Vide.source(rules.DefaultView :: Content.SecurityView) :: Vide.Source<Content.SecurityView>
	self.Time = Vide.source(0) :: Vide.Source<number>
	self.Since = Vide.source(0) :: Vide.Source<number>
	self.Static = Vide.source(0) :: Vide.Source<number>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.Clock = Vide.source("") :: Vide.Source<string>
	self.NightText = Vide.source("") :: Vide.Source<string>

	self.SwitchedAt = 0 :: number
	self.Frame = nil :: CFrame?
	self.Fov = 70 :: number
	self.Effect = nil :: ColorCorrectionEffect?
	self.Light = nil :: Part?
	self.Saved = {} :: Saved
	self.BoundNames = {} :: { string }
	self.PreviousContext = "Gameplay" :: string
	self.Unmount = nil :: (() -> ())?
	self.Connection = nil :: RBXScriptConnection?
	-- parts of the camera model being looked through, hidden locally (the eye sits inside the housing)
	self.Hidden = {} :: { BasePart }
end

-- Camera model of a Cam row: in the security folder, else loose in the Workspace (owner layout before the move).
function SecurityController:ModelOf(cam: Content.SecurityCam): PVInstance?
	const folder = workspace:FindFirstChild(rules.Folder)
	const model = (if folder ~= nil then folder:FindFirstChild(cam.Model) else nil) or workspace:FindFirstChild(cam.Model)
	return if model ~= nil and model:IsA("PVInstance") then model else nil
end

-- The view of a camera: the pivot of its model (eye and facing).
function SecurityController:FrameOf(key: string): CFrame?
	const cam = security.Cams.ByKey[key]
	if cam == nil then
		return nil
	end
	const model = self:ModelOf(cam)
	return if model ~= nil then model:GetPivot() else nil
end

function SecurityController:Look(): Content.SecurityLook
	return security.Looks[untrack(self.View)]
end

-- Enters the camera view (after SecurityOpen). Gives the freeze back when it cannot.
function SecurityController:Enter()
	if untrack(self.Open) then
		return
	end
	const camera = self.Dependencies.CameraController
	const key = untrack(self.Cam)
	const frame = self:FrameOf(key)
	if frame == nil or untrack(camera.Mode) ~= "FirstPerson" or untrack(self.Dependencies.VitalController.LocalState) ~= "Active" then
		if frame == nil then
			warn(`[SecurityController] camera {key} not found (Workspace.{rules.Folder}): no view`)
		end
		self.Libs.Net.SecurityLeave:fireServer()
		return
	end
	self:Cut(key, frame)
	if untrack(camera.Mode) ~= "Prep" then
		self.Libs.Net.SecurityLeave:fireServer()
		return
	end

	const now = os.clock()
	Vide.batch(function()
		self.Open(true)
		self.Time(now)
		self.Since(now)
		self.Static(1)
	end)
	self.SwitchedAt = now
	self:Isolate(true)
	const input = self.Dependencies.InputController
	self.PreviousContext = input.Context
	input:SetContext("Menu")
	self:Bind(true)
	self:Mount()
	self:ApplyLook()
	self:Publish()
	self.Connection = RunService.RenderStepped:Connect(function()
		self:Update()
	end)
end

-- Cut of the camera to a view (also a retarget while open).
function SecurityController:Cut(key: string, frame: CFrame)
	const cam = security.Cams.ByKey[key]
	self:HideHousing(self:ModelOf(cam))
	self.Frame = frame
	self.Fov = cam.Fov
	self.Dependencies.CameraController:Prep(true, frame, {
		Fov = cam.Fov,
		Travel = rules.Enter,
		Look = frame.Position + frame.LookVector * LOOK_AHEAD,
	})
end

-- The eye sits inside the camera model: its parts are hidden on this client while looking through it (nil = show all back).
function SecurityController:HideHousing(model: PVInstance?)
	for _, part in self.Hidden do
		part.LocalTransparencyModifier = 0
	end
	table.clear(self.Hidden)
	if model == nil then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 1
			table.insert(self.Hidden, part)
		end
	end
end

-- Leaves on the player's request or a life state change: the camera cuts back, the freeze is released.
function SecurityController:Leave()
	if not untrack(self.Open) then
		return
	end
	const camera = self.Dependencies.CameraController
	if untrack(camera.Mode) == "Prep" then
		camera:Prep(false, nil, { Travel = 0 })
	end
	self:Teardown()
end

-- Gives everything back (camera untouched: Leave cut it already, or someone else owns it).
function SecurityController:Teardown()
	if not untrack(self.Open) then
		return
	end
	self.Open(false)
	if self.Connection ~= nil then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	self:Bind(false)
	self:Isolate(false)
	self.Dependencies.InputController:SetContext(if self.PreviousContext == "Menu" then "Menu" else "Gameplay")
	if self.Effect ~= nil then
		self.Effect:Destroy()
		self.Effect = nil
	end
	if self.Light ~= nil then
		self.Light:Destroy()
		self.Light = nil
	end
	if self.Unmount ~= nil then
		self.Unmount()
		self.Unmount = nil
	end
	self.Frame = nil
	self:HideHousing(nil)
	self:Publish()
	self.Libs.Net.SecurityLeave:fireServer()
end

function SecurityController:SetCam(key: string)
	if not untrack(self.Open) or security.Cams.ByKey[key] == nil or key == untrack(self.Cam) then
		return
	end
	const frame = self:FrameOf(key)
	if frame == nil then
		return
	end
	self.Cam(key)
	self:Cut(key, frame)
	self:Burst()
	self:Publish()
end

function SecurityController:Step(delta: number)
	const list = security.Cams.List
	const index = security.Cams.IndexOf[untrack(self.Cam)] or 1
	self:SetCam(list[(index - 1 + delta) % #list + 1].Key)
end

function SecurityController:ToggleView()
	if not untrack(self.Open) then
		return
	end
	self.View(if untrack(self.View) == "Night" then "Normal" else "Night")
	self:ApplyLook()
	self:Burst()
	self:Publish()
end

function SecurityController:Burst()
	self.SwitchedAt = os.clock()
	self.Static(1)
end

-- Colour grade and the infrared illuminator of the current look (local only).
function SecurityController:ApplyLook()
	const look = self:Look()
	local effect = self.Effect
	if effect == nil then
		const made = Instance.new("ColorCorrectionEffect")
		made.Name = EFFECT_NAME
		made.Parent = Lighting
		effect = made
		self.Effect = made
	end
	const grade = effect :: ColorCorrectionEffect
	grade.TintColor = look.Tint
	grade.Brightness = look.Brightness
	grade.Contrast = look.Contrast
	grade.Saturation = look.Saturation

	if look.Illuminator <= 0 then
		if self.Light ~= nil then
			self.Light:Destroy()
			self.Light = nil
		end
		return
	end
	local holder = self.Light
	if holder == nil then
		const part = Instance.new("Part")
		part.Name = "SecurityIlluminator"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = Vector3.one * 0.2
		const light = Instance.new("PointLight")
		light.Shadows = false
		light.Parent = part
		part.Parent = workspace.CurrentCamera
		holder = part
		self.Light = part
	end
	const part = holder :: Part
	const light = part:FindFirstChildOfClass("PointLight")
	if light ~= nil then
		light.Brightness = look.Illuminator
		light.Range = math.min(look.Range, 60)
		light.Color = look.Tint
	end
	if self.Frame ~= nil then
		part.CFrame = self.Frame
	end
end

-- Attributes read by the AnomalyController (and anything else that wants to know what this client watches).
function SecurityController:Publish()
	const player = Players.LocalPlayer
	const open = untrack(self.Open)
	player:SetAttribute(rules.ViewAttribute, if open then untrack(self.View) else "")
	player:SetAttribute(rules.CamAttribute, if open then untrack(self.Cam) else "")
end

-- Every frame while open: animation clock, static decay, the drift of the view and the ways out.
function SecurityController:Update()
	const camera = self.Dependencies.CameraController
	if untrack(camera.Mode) ~= "Prep" then
		-- a cutscene (or another owner) took the camera: drop without touching it
		self:Teardown()
		return
	end
	if untrack(self.Dependencies.VitalController.LocalState) ~= "Active" then
		self:Leave()
		return
	end
	const now = os.clock()
	const static = if rules.Switch > 0 then math.clamp(1 - (now - self.SwitchedAt) / rules.Switch, 0, 1) else 0
	const round = self.Dependencies.RoundController
	Vide.batch(function()
		self.Time(now)
		if untrack(self.Static) ~= static then
			self.Static(static)
		end
		self.Clock(untrack(round.ClockText))
		self.NightText(if untrack(round.IsNight) then `NIGHT {untrack(round.Night)}` else `DAY {untrack(round.Day)}`)
	end)
	const frame = self.Frame
	if frame == nil then
		return
	end
	const wobble = self:Look().Wobble
	const t = now * WOBBLE_SPEED * math.pi * 2
	const drift = frame.RightVector * math.sin(t) * wobble + frame.UpVector * math.sin(t * 0.73 + 1.3) * wobble
	const look = frame.Position + frame.LookVector * LOOK_AHEAD + drift * LOOK_AHEAD
	camera:PrepGoal(frame.Position, look, self.Fov, 0)
	if self.Light ~= nil then
		self.Light.CFrame = frame
	end
	const viewport = workspace.CurrentCamera
	if viewport ~= nil then
		const scale = Theme.ScaleOf(viewport.ViewportSize)
		if math.abs(scale - untrack(self.Scale)) > 0.01 then
			self.Scale(scale)
		end
	end
end

-- Hud, touch controls, hotbar and chat window out of the way while watching (restored as they were).
function SecurityController:Isolate(on: boolean)
	const saved = self.Saved
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if on then
		table.clear(saved)
		if playerGui ~= nil then
			for _, name in { "Hud", "TouchGui" } do
				const gui = playerGui:FindFirstChild(name)
				if gui ~= nil and gui:IsA("ScreenGui") then
					saved[name] = gui.Enabled
					gui.Enabled = false
				end
			end
		end
		const ok, hotbar = pcall(function(): boolean
			return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
		end)
		if ok then
			saved.Backpack = hotbar
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
		end
		const chat = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if chat ~= nil then
			saved.Chat = chat.Enabled
			chat.Enabled = false
		end
		return
	end
	if playerGui ~= nil then
		for _, name in { "Hud", "TouchGui" } do
			const gui = playerGui:FindFirstChild(name)
			if gui ~= nil and gui:IsA("ScreenGui") and saved[name] ~= nil then
				gui.Enabled = saved[name]
			end
		end
	end
	if saved.Backpack ~= nil then
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, saved.Backpack)
	end
	const chat = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if chat ~= nil and saved.Chat ~= nil then
		chat.Enabled = saved.Chat == true
	end
	table.clear(saved)
end

function SecurityController:Bind(on: boolean)
	const input = self.Dependencies.InputController
	if not on then
		for _, name in self.BoundNames do
			input:Unbind(name)
		end
		table.clear(self.BoundNames)
		return
	end
	local function bind(name: string, key: Enum.KeyCode, keys: { Enum.KeyCode | Enum.UserInputType }?, press: () -> ())
		input
			:Bind({
				Name = name,
				Key = key,
				Keys = keys,
				Priority = Enum.ContextActionPriority.High.Value,
				Context = "Menu",
			})
			.OnPress(press)
		table.insert(self.BoundNames, name)
	end
	bind("SecurityLeave", Enum.KeyCode.Q, { Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB }, function()
		self:Leave()
	end)
	bind("SecurityView", Enum.KeyCode.N, { Enum.KeyCode.ButtonY }, function()
		self:ToggleView()
	end)
	bind("SecurityPrev", Enum.KeyCode.Left, { Enum.KeyCode.ButtonL1, Enum.KeyCode.DPadLeft }, function()
		self:Step(-1)
	end)
	bind("SecurityNext", Enum.KeyCode.Right, { Enum.KeyCode.ButtonR1, Enum.KeyCode.DPadRight }, function()
		self:Step(1)
	end)
	const digits = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
	for index, cam in security.Cams.List do
		const key = digits[index]
		if key ~= nil then
			bind(`SecurityCam{index}`, key, nil, function()
				self:SetCam(cam.Key)
			end)
		end
	end
end

function SecurityController:Mount()
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	const cams = {}
	for _, cam in security.Cams.List do
		table.insert(cams, { Key = cam.Key, Label = cam.Label })
	end
	const input = self.Dependencies.InputController
	-- the root's cleanup destroys the gui (Vide.mount only parents it and stops the reactive scope)
	self.Unmount = Vide.mount(function()
		const gui = Vide.create("ScreenGui")({
			Name = "SecurityFeed",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 20,
			SecurityFeed({
				Cams = cams,
				Cam = self.Cam,
				View = self.View,
				Look = function()
					return security.Looks[self.View()]
				end,
				Time = self.Time,
				Since = self.Since,
				Static = self.Static,
				Clock = self.Clock,
				Night = self.NightText,
				Device = input.Device,
				Scale = self.Scale,
				OnCam = function(key: string)
					self:SetCam(key)
				end,
				OnView = function()
					self:ToggleView()
				end,
				OnExit = function()
					self:Leave()
				end,
			}),
		})
		Vide.cleanup(function()
			gui:Destroy()
		end)
		return gui
	end, playerGui)
end

SecurityController:OnInit(function(self)
	self:Setup()
	self.Libs.Net.SecurityOpen:onClient(function()
		self:Enter()
	end)
end)

SecurityController:OnStart(function(self)
	self:Publish()
	-- the world prompts are quiet while watching (the body is far from the view)
	self.Dependencies.PromptController:AddGate(GATE, function(_anchor: Instance): boolean
		return not untrack(self.Open)
	end)
	Screen.start({
		Open = self.Open,
		Cam = self.Cam,
		Clock = self.Dependencies.RoundController.ClockText,
	})
end)

return SecurityController
