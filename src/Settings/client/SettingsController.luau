--!strict
--[[
	SettingsController (TASK-279; owner request 2026-10-14, Provisional)

	Owns the player settings on the client and the settings window. Lobby and Run.
	  - Values (Vide source, SettingsRules.Settings): SettingsRules defaults until the `Settings` packet (sent once by
	    SettingsService when the profile is loaded); a change made before it arrives wins over it (Dirty).
	  - Apply: AudioController:SetVolume (Music; Sfx also drives Ambient and Ui; Voice; Scare = jumpscare group),
	    LocalPlayer attribute PromptMode ("Single" | "Multi", read by PromptController, TASK-278), Settings.Prefs
	    (PrepAssist: prep hint line and drag paw; ReducedMotion: Motion.Reduced).
	  - Save: the whole record by `SettingsSave`, SAVE_DELAY s after the last change (a slider drag sends once).
	  - Window: SettingsPanel in its own ScreenGui ("Settings", above the HUD). Toggled by the HUD gear (HudController) and
	    by the key M / gamepad Select. While open, a Modal button frees the mouse from the first-person lock.
	  - Dev row (TASK-332): only in Studio dev mode (PlaceController:IsDev), "Coffee" and "Sanity ∞" send `DevTool`
	    (DevService runs /dev mycoffee and /dev infsanity for this player); the ∞ state is the player attribute
	    DevInfiniteSanity written by VitalService. Never built for players (Dev = nil).
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local SettingsRules = require(ReplicatedStorage.shared.Settings.SettingsRules)
local AdminSettings = require(ReplicatedStorage.shared.Admin.AdminSettings)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Backdrop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Backdrop)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local SettingsPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SettingsPanel)
local Prefs = require(script.Parent.Prefs)

const SAVE_DELAY = 0.6 -- s after the last change (> SettingsService MIN_GAP)
const PROMPT_ATTRIBUTE = "PromptMode" -- contract with PromptController (TASK-278)
const TOGGLE_ACTION = "SettingsToggle"
const TOGGLE_KEY = Enum.KeyCode.M
const TOGGLE_PAD = Enum.KeyCode.ButtonSelect
const DISPLAY_ORDER = 20 -- above the HUD (1) and the prep shell
const FIRST_CONTROL = "Track" -- the gamepad selection lands on the first volume slider
const DEV_INFINITE = "DevInfiniteSanity" -- player attribute written by VitalService:DevInfiniteSanity (TASK-332)

const SettingsController = Modux.Controller(
	"SettingsController",
	{ Require = { "AudioController", "InputController", "PlaceController" }, Priority = 600 }
)

function SettingsController:Setup()
	self.Values = Vide.source(table.clone(SettingsRules.Defaults)) :: Vide.Source<SettingsRules.Settings>
	self.Open = Vide.source(false) :: Vide.Source<boolean>
	-- the player changed something before the server's record arrived: keep theirs
	self.Dirty = false :: boolean
	self.SaveToken = 0 :: number
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.Gui = nil :: ScreenGui?
	self.Infinite = Vide.source(false) :: Vide.Source<boolean>
end

-- Dev row props (TASK-332), nil outside Studio dev mode and for players off the admin allow-list (the server checks
-- again on every DevTool packet)
function SettingsController:DevProps(): SettingsPanel.DevProps?
	if not self.Dependencies.PlaceController:IsDev() and not AdminSettings.IsAllowed(Players.LocalPlayer) then
		return nil
	end
	const player = Players.LocalPlayer
	const read = function()
		self.Infinite(player:GetAttribute(DEV_INFINITE) == true)
	end
	player:GetAttributeChangedSignal(DEV_INFINITE):Connect(read)
	read()
	return {
		InfiniteSanity = self.Infinite,
		OnCoffee = function()
			self.Libs.Net.DevTool:fireServer({ Tool = "Coffee", On = true })
		end,
		OnInfiniteSanity = function(on: boolean)
			self.Libs.Net.DevTool:fireServer({ Tool = "InfiniteSanity", On = on })
		end,
	}
end

-- Applies a full record everywhere it acts (audio, prompt attribute, Prefs). Idempotent.
function SettingsController:Apply(settings: SettingsRules.Settings)
	const audio = self.Dependencies.AudioController
	const sfx = settings.Sfx / 100
	audio:SetVolume("Music", settings.Music / 100)
	audio:SetVolume("Sfx", sfx)
	audio:SetVolume("Ambient", sfx)
	audio:SetVolume("Ui", sfx)
	audio:SetVolume("Voice", settings.Voice / 100)
	audio:SetVolume("Scare", settings.Scare / 100)
	Players.LocalPlayer:SetAttribute(PROMPT_ATTRIBUTE, settings.PromptMode)
	Prefs.Set(settings)
end

-- One setting changed in the window: live apply, debounced save.
function SettingsController:Set(key: SettingsRules.Key, value: any)
	const nextValues = table.clone(Vide.untrack(self.Values)) :: { [string]: any }
	nextValues[key] = value
	const settings = SettingsRules.Sanitize(nextValues)
	if SettingsRules.Same(settings, Vide.untrack(self.Values)) then
		return
	end
	self.Dirty = true
	self.Values(settings)
	self:Apply(settings)
	self:ScheduleSave()
end

function SettingsController:ScheduleSave()
	self.SaveToken += 1
	const token = self.SaveToken
	task.delay(SAVE_DELAY, function()
		if token ~= self.SaveToken then
			return
		end
		self.Libs.Net.SettingsSave:fireServer(Vide.untrack(self.Values))
	end)
end

function SettingsController:SetOpen(open: boolean)
	if Vide.untrack(self.Open) ~= open then
		self.Open(open)
		if open then
			self.Libs.Net.MetricUi:fireServer({ Event = "settings_open", Key = nil }) -- analytics
		end
		self:Select(open)
	end
end

-- Gamepad: the selection goes to the first slider on open, and leaves the window on close (TASK-290).
function SettingsController:Select(open: boolean)
	const gui = self.Gui
	if gui == nil then
		return
	end
	if not open then
		const selected = GuiService.SelectedObject
		if selected ~= nil and selected:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
		return
	end
	if Vide.untrack(self.Dependencies.InputController.Device) ~= "Gamepad" then
		return
	end
	task.defer(function()
		for _, child in gui:GetDescendants() do
			if child.Name == FIRST_CONTROL and child:IsA("GuiButton") and child.Visible then
				GuiService.SelectedObject = child
				return
			end
		end
	end)
end

function SettingsController:Toggle()
	self:SetOpen(not Vide.untrack(self.Open))
end

function SettingsController:Rescale(camera: Camera?)
	if camera then
		self.Scale(Theme.ScaleOf(camera.ViewportSize))
	end
end

function SettingsController:WatchViewport()
	local connection: RBXScriptConnection? = nil
	local function bind()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		const camera = workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:Rescale(camera)
			end)
		end
		self:Rescale(camera)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
	bind()
end

function SettingsController:Mount(playerGui: Instance)
	const dev = self:DevProps()
	const _, gui = Vide.root(function()
		-- blur + veil behind the window (TASK-311)
		Backdrop.Hold(self.Open)
		return Vide.create("ScreenGui")({
			Name = "Settings",
			ResetOnSpawn = false,
			-- the slider reads InputObject.Position (no inset) against AbsolutePosition: keep both in screen space
			ScreenInsets = Enum.ScreenInsets.None,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = DISPLAY_ORDER,

			-- frees the mouse from the first-person lock while the window is open
			Vide.create("TextButton")({
				Name = "Cursor",
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				Selectable = false,
				Modal = true,
				Visible = self.Open,
			}),

			SettingsPanel({
				Visible = self.Open,
				Values = self.Values,
				Scale = self.Scale,
				Hint = function()
					return if UserInputService.KeyboardEnabled then "Press M to open or close" else ""
				end,
				OnChange = function(key: SettingsRules.Key, value: any)
					self:Set(key, value)
				end,
				OnClose = function()
					self:SetOpen(false)
				end,
				Dev = dev,
			}),
		})
	end)
	self.Gui = gui
	gui.Parent = playerGui
end

SettingsController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Settings:onClient(function(data)
		if self.Dirty then
			return
		end
		const settings = SettingsRules.Sanitize(data)
		self.Values(settings)
		self:Apply(settings)
	end)
end)

SettingsController:OnStart(function(self)
	self:Apply(Vide.untrack(self.Values))
	self:WatchViewport()

	self.Dependencies.InputController
		:Bind({
			Name = TOGGLE_ACTION,
			Key = TOGGLE_KEY,
			Keys = { TOGGLE_PAD },
		})
		.OnPress(function()
			-- typing in a text box (chat, codes) never toggles the window
			if UserInputService:GetFocusedTextBox() ~= nil then
				return
			end
			self:Toggle()
		end)

	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return SettingsController
