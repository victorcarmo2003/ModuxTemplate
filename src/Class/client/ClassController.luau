--!strict
--[[
	ClassController (TASK-020; DEC-186, FEAT-001 class part, FEAT-028; network.md §4.5, §4.6)

	The "Crew" screen: the 6 MVP animals (panda and lion are not playable yet, raccoon never is), price in gems,
	Selected / Owned / Buy / NoGems per card, Buy and Select by the `ClassAction` packet, preview of the focused
	animal with a local CrewRig (Build with Tag = false, then Dress; never tagged, never sent to the server).

	Client presents, server decides: gems, owned classes and the selection only change when the Profile packet says
	so (ProfileController). While a request is on its way the main button shows "..." and nothing else can be sent;
	it clears on the next Profile packet, on a class Notice (not_enough_gems, class_locked...) or after PENDING_TIMEOUT.
	Toasts for those Notices are HudController's job.

	Where it opens: the Lobby (FEAT-001) and, in wave 1, the Run in dev mode (no lobby yet, TASK-017 Provisional).
	Elsewhere no binding and no screen. Toggle: C (keyboard), ButtonY (gamepad), "Crew" touch button; close also
	with ButtonB / the X button. While open the input context is "Menu" (prompts stop).
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local CrewScreen = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CrewScreen)
local CardState = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CrewCard.State)

export type Action = "Buy" | "Select"

const TOGGLE = "CrewToggle"
const CLOSE = "CrewClose"
const TOUCH_SIZE = 56
const PENDING_TIMEOUT = 3 -- s without an answer: the button comes back (the server may have dropped it, 2/s)
const PREVIEW_OUTFIT = "crew"
const CLICK_SOUND = "ui_click"
-- UI scale: 1 on the smallest landscape phone (panel 620 x 320 + margins), grows up to 2
const BASE_WIDTH = 660
const BASE_HEIGHT = 340
const MAX_SCALE = 2

const CLASS_NOTICES: { [string]: boolean } = {
	class_bought = true,
	class_selected = true,
	class_locked = true,
	not_enough_gems = true,
}

-- The MVP classes in table order (DEC-186): panda and lion stay out until the game-designer asks for "coming soon".
local function entries(): { CrewScreen.Entry }
	const list: { CrewScreen.Entry } = {}
	for _, class in Content.Classes.List do
		if not class.InMvp then
			continue
		end
		const species = Content.Species.ByKey[class.Species]
		const animal = if species then species.Name else class.Species
		table.insert(list, {
			Key = class.Key,
			Title = class.Name,
			Animal = animal,
			Species = class.Species,
			Badge = string.upper(string.sub(animal, 1, 1)),
			Icon = nil, -- class icons: art-director (placeholder letter)
			Price = class.Price,
			Description = class.Description,
		})
	end
	return list
end

const ClassController = Modux.Controller(
	"ClassController",
	{ Require = { "ProfileController", "InputController", "PlaceController", "AudioController" }, Priority = 450 }
)

function ClassController:Setup()
	self.Entries = entries() :: { CrewScreen.Entry }
	self.Open = Vide.source(false) :: Vide.Source<boolean>
	self.Focus = Vide.source("") :: Vide.Source<string>
	-- class key of the request on its way; "" = none
	self.Pending = Vide.source("") :: Vide.Source<string>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.PendingThread = nil :: thread?
	self.Gui = nil :: ScreenGui?
	self.Unmount = nil :: (() -> ())?
	self.RigWarned = false :: boolean
end

-- Lobby, or the Run in dev mode (wave 1). The server checks the same rule (ClassService:CanWrite).
function ClassController:Available(): boolean
	const place = self.Dependencies.PlaceController
	return place:Is("Lobby") or place:IsDev()
end

function ClassController:StateOf(key: string): CardState.State
	const profile = self.Dependencies.ProfileController
	const class = Content.Classes.ByKey[key]
	const price = if class then class.Price else math.huge
	return CardState.Of(profile.Classes()[key] == true, profile.Selected() == key, profile.Gems(), price)
end

function ClassController:Busy(): boolean
	return self.Pending() ~= "" or not self.Dependencies.ProfileController.Ready()
end

function ClassController:ClearPending()
	const thread = self.PendingThread
	self.PendingThread = nil
	if thread and thread ~= coroutine.running() and coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
	if self.Pending() ~= "" then
		self.Pending("")
	end
end

function ClassController:Send(action: Action, key: string)
	if self:Busy() or not self:Available() then
		return
	end
	self.Pending(key)
	self.PendingThread = task.delay(PENDING_TIMEOUT, function()
		self.PendingThread = nil
		self.Pending("")
	end)
	self.Libs.Net.ClassAction:fireServer({ Action = action, Class = key })
end

-- Main button: what it does depends on the class state. NoGems and Selected send nothing.
function ClassController:Act(key: string)
	const state = self:StateOf(key)
	if state == "Owned" then
		self:Send("Select", key)
	elseif state == "Buy" then
		self:Send("Buy", key)
	end
end

function ClassController:Buy(key: string)
	self:Send("Buy", key)
end

function ClassController:Select(key: string)
	self:Send("Select", key)
end

-- Local preview rig (TASK-016): not tagged, so RigController leaves it alone; dressed here once.
function ClassController:BuildRig(species: string): Model?
	const ok, result = pcall(function(): Model
		const model = CrewRig.Build(species, PREVIEW_OUTFIT, {
			Tag = false,
			Anchored = true,
			Name = `CrewPreview_{species}`,
			CFrame = CFrame.new(0, 3, 0),
		})
		CrewRig.Dress(model)
		return model
	end)
	if ok then
		return result
	end
	if not self.RigWarned then
		self.RigWarned = true
		warn(`[ClassController] preview rig unavailable ({result}); showing the placeholder`)
	end
	return nil
end

function ClassController:SelectCard()
	if self.Dependencies.InputController.Device() ~= "Gamepad" then
		return
	end
	const gui = self.Gui
	if gui == nil then
		return
	end
	const card = gui:FindFirstChild(self.Focus(), true)
	if card and card:IsA("GuiObject") then
		GuiService.SelectedObject = card
	end
end

function ClassController:SetOpen(open: boolean)
	if self.Open() == open or (open and not self:Available()) then
		return
	end
	const input = self.Dependencies.InputController
	if open then
		self.Focus(self.Dependencies.ProfileController.Selected())
		self.Open(true)
		input:SetContext("Menu")
		self:SelectCard()
	else
		self.Open(false)
		input:SetContext("Gameplay")
		const selected = GuiService.SelectedObject
		const gui = self.Gui
		if selected and gui and selected:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
	end
end

function ClassController:Toggle()
	self:SetOpen(not self.Open())
end

function ClassController:Bind()
	const input = self.Dependencies.InputController
	input
		:Bind({
			Name = TOGGLE,
			Key = Enum.KeyCode.C,
			Keys = { Enum.KeyCode.ButtonY },
			TouchButton = true,
			Title = "Crew",
			TouchSize = TOUCH_SIZE,
		})
		.OnPress(function()
			self:Toggle()
		end)
	input
		:Bind({
			Name = CLOSE,
			Key = Enum.KeyCode.ButtonB,
			Context = "Menu",
		})
		.OnPress(function()
			self:SetOpen(false)
		end)
end

function ClassController:Rescale(camera: Camera?)
	if camera == nil then
		return
	end
	const size = camera.ViewportSize
	const scale = math.clamp(math.min(size.X / BASE_WIDTH, size.Y / BASE_HEIGHT), 1, MAX_SCALE)
	if math.abs(scale - self.Scale()) > 0.01 then
		self.Scale(scale)
	end
end

function ClassController:WatchViewport()
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

function ClassController:Mount(playerGui: Instance)
	const profile = self.Dependencies.ProfileController

	const unmount, gui = Vide.root(function()
		-- A Profile packet answers the request: whatever it says, the button comes back.
		Vide.effect(function()
			profile.Classes()
			profile.Selected()
			profile.Gems()
			Vide.untrack(function()
				self:ClearPending()
				return nil
			end)
		end)

		return Vide.create("ScreenGui")({
			Name = "Crew",
			ResetOnSpawn = false,
			IgnoreGuiInset = false,
			ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 5,
			Enabled = self.Open,

			CrewScreen({
				Entries = self.Entries,
				Visible = self.Open,
				Gems = profile.Gems,
				StateOf = function(key: string): CardState.State
					return self:StateOf(key)
				end,
				Focus = self.Focus,
				Busy = function()
					return self:Busy()
				end,
				-- ui_click on every button of the Crew screen (user request 2026-10-10)
				OnFocus = function(key: string)
					if Vide.untrack(self.Focus) ~= key then
						self.Dependencies.AudioController:Play(CLICK_SOUND)
					end
					self.Focus(key)
				end,
				OnAction = function(key: string)
					self.Dependencies.AudioController:Play(CLICK_SOUND)
					self:Act(key)
				end,
				OnClose = function()
					self.Dependencies.AudioController:Play(CLICK_SOUND)
					self:SetOpen(false)
				end,
				Rig = function(species: string): Model?
					return self:BuildRig(species)
				end,
				Scale = self.Scale,
			}),
		})
	end)
	self.Unmount = unmount
	self.Gui = gui
	gui.Parent = playerGui
end

ClassController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Notice:onClient(function(notice)
		if CLASS_NOTICES[notice.Kind] then
			self:ClearPending()
		end
	end)
end)

ClassController:OnStart(function(self)
	if not self:Available() then
		return
	end
	self:Bind()
	self:WatchViewport()
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return ClassController
