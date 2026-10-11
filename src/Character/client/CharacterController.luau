--!strict
--[[
	CharacterController (TASK-063; architecture.md §19.1, §19.2, §19.7; FEAT-025; DEC-219)

	Own character on this client:
	  - locks the controls (walk, jump, hotbar) while the own life state is not `Active` (Down, Reviving,
	    Spectator) or while the server froze the character (`CharacterService:Freeze`: cutscene);
	  - shows the own arms in first person, day and night (DEC-219, `CameraController:SetArmsVisible(true)`);
	  - Fainted face on every crew member whose `Vitals.State` is `Down` (network.md §5.2, DEC-216), through
	    `RigController:SetExpression` (local layer; the server only ragdolls the body).

	The lock is presentation only: the server already refuses interaction (`InteractionService` gate "Vital") and
	holds a frozen character in place. Nothing here decides a state.

	Freeze contract (TASK-061): `CharacterService:Freeze` writes the boolean attribute `Frozen` on the character
	(walk and jump zeroed on the server); a non-empty string is also accepted. Wave 3 ragdoll prediction ("ragdoll previsto", §19.1) is not in this task.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const FROZEN_ATTRIBUTE = "Frozen"
const FAINTED_FACE = "Fainted" -- Content.Looks expression (DEC-216, Provisional DEC-167)
const MODULE_WAIT = 10 -- seconds the first lookup waits for PlayerScripts.PlayerModule; later lookups do not yield
-- Fallback lock when the stock PlayerModule is not there: sink the walk/jump inputs above every other binding.
const LOCK_ACTION = "CharacterControlsLock"
const LOCK_PRIORITY = Enum.ContextActionPriority.High.Value + 1000
const LOCK_INPUTS: { Enum.KeyCode } = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
	Enum.KeyCode.Space,
	Enum.KeyCode.Thumbstick1,
	Enum.KeyCode.ButtonA,
}

type Controls = {
	Enable: (self: Controls, enabled: boolean?) -> (),
	Disable: (self: Controls) -> (),
}

type PlayerModule = {
	GetControls: (self: PlayerModule) -> Controls,
}

local function isFrozen(value: unknown): boolean
	if value == true then
		return true
	elseif type(value) == "string" then
		return value ~= ""
	end
	return false
end

const CharacterController = Modux.Controller(
	"CharacterController",
	{ Require = { "VitalController", "CameraController", "RigController" }, Priority = 720 }
)

function CharacterController:Setup()
	-- The server froze the own character (attribute `Frozen`).
	self.Frozen = Vide.source(false) :: Vide.Source<boolean>
	-- Controls are locked now (not Active or Frozen). Other Controllers may read it.
	self.Locked = Vide.source(false) :: Vide.Source<boolean>
	self.Controls = nil :: Controls?
	-- The first lookup already waited MODULE_WAIT s (the next ones only look, never yield again).
	self.Looked = false :: boolean
	self.Sinking = false :: boolean
	self.Applied = false :: boolean
	self.Character = nil :: Model?
	self.FrozenConnection = nil :: RBXScriptConnection?
	-- Characters this client dressed with the Fainted face (weak keys: a removed body is forgotten).
	self.Faces = setmetatable({}, { __mode = "k" }) :: { [Model]: boolean }
end

-- Fainted face on every Down member's character; clears it from whoever is no longer Down.
function CharacterController:RefreshFaces()
	const vital = self.Dependencies.VitalController
	const rig = self.Dependencies.RigController
	const states = Vide.untrack(vital.State)
	const keep: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		const character = player.Character
		if character ~= nil and states[player.UserId] == "Down" then
			keep[character] = true
			if not self.Faces[character] then
				self.Faces[character] = true
				rig:SetExpression(character, FAINTED_FACE)
			end
		end
	end
	for character in self.Faces do
		if not keep[character] then
			self.Faces[character] = nil
			rig:SetExpression(character, nil)
		end
	end
end

-- PlayerModule controls (stock Roblox), loaded once; nil if the module is missing (custom player scripts). Only the
-- first lookup waits; a missing module warns once and the lock falls back to sinking the inputs (Apply).
function CharacterController:GetControls(): Controls?
	if self.Controls ~= nil then
		return self.Controls
	end
	const player = Players.LocalPlayer
	local module: Instance? = nil
	if self.Looked then
		const scripts = player:FindFirstChild("PlayerScripts")
		module = if scripts ~= nil then scripts:FindFirstChild("PlayerModule") else nil
	else
		self.Looked = true
		const scripts = player:WaitForChild("PlayerScripts", MODULE_WAIT)
		module = if scripts ~= nil then scripts:WaitForChild("PlayerModule", MODULE_WAIT) else nil
		-- harmless: the server freezes the body anyway (CharacterService:Freeze zeroes walk/jump), later lookups
		-- pick the module up if it arrives after MODULE_WAIT, and meanwhile the lock sinks the inputs. Studio only.
		if module == nil and RunService:IsStudio() then
			warn("[CharacterController] no PlayerScripts.PlayerModule yet: the lock sinks walk/jump input instead")
		end
	end
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	const ok, result = pcall(require, module :: ModuleScript)
	if not ok then
		warn(`[CharacterController] PlayerModule failed to load: {result}`)
		return nil
	end
	const controls = (result :: PlayerModule):GetControls()
	self.Controls = controls
	return controls
end

-- Fallback lock: walk/jump keys sunk at the top priority (no PlayerModule to disable)
function CharacterController:Sink(on: boolean)
	if self.Sinking == on then
		return
	end
	self.Sinking = on
	if on then
		ContextActionService:BindActionAtPriority(LOCK_ACTION, function()
			return Enum.ContextActionResult.Sink
		end, false, LOCK_PRIORITY, table.unpack(LOCK_INPUTS))
	else
		ContextActionService:UnbindAction(LOCK_ACTION)
	end
end

function CharacterController:Apply(locked: boolean)
	self.Applied = locked
	const controls = self:GetControls()
	if self.Applied ~= locked then
		return -- the state changed while the first lookup waited: the newer Apply wins
	end
	if controls ~= nil then
		self:Sink(false)
		if locked then
			controls:Disable()
		else
			controls:Enable()
		end
	else
		self:Sink(locked)
	end
	-- Hotbar: no switching items while locked (the server stashes or keeps the Tools; nothing is unequipped here).
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not locked)
	end)
end

function CharacterController:Watch(character: Model?)
	const previous = self.FrozenConnection
	if previous ~= nil then
		previous:Disconnect()
		self.FrozenConnection = nil
	end
	self.Character = character
	if character == nil then
		self.Frozen(false)
		return
	end
	local function update()
		self.Frozen(isFrozen(character:GetAttribute(FROZEN_ATTRIBUTE)))
	end
	self.FrozenConnection = character:GetAttributeChangedSignal(FROZEN_ATTRIBUTE):Connect(update)
	update()
end

CharacterController:OnInit(function(self)
	self:Setup()
end)

CharacterController:OnStart(function(self)
	const vital = self.Dependencies.VitalController
	const player = Players.LocalPlayer

	-- DEC-219: real arms of the own animal in first person, always (no viewmodel).
	self.Dependencies.CameraController:SetArmsVisible(true)

	player.CharacterAdded:Connect(function(character: Model)
		self:Watch(character)
		-- A new character comes with fresh controls enabled: re-apply a lock that is still on.
		if Vide.untrack(self.Locked) then
			task.defer(function()
				self:Apply(true)
			end)
		end
	end)
	player.CharacterRemoving:Connect(function(character: Model)
		if self.Character == character then
			self:Watch(nil)
		end
	end)
	self:Watch(player.Character)

	-- Faces: on any state change and whenever a member's character (re)appears on this client.
	local function onPlayer(other: Player)
		other.CharacterAdded:Connect(function()
			task.defer(function()
				self:RefreshFaces()
			end)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, other in Players:GetPlayers() do
		onPlayer(other)
	end

	Vide.root(function()
		Vide.effect(function()
			vital.State()
			Vide.untrack(function()
				self:RefreshFaces()
				return nil
			end)
		end)

		Vide.effect(function()
			const locked = vital.LocalState() ~= "Active" or self.Frozen()
			Vide.untrack(function()
				if self.Locked() ~= locked then
					self.Locked(locked)
				end
				if self.Applied ~= locked then
					-- GetControls may wait for PlayerScripts: never yield inside the effect.
					task.spawn(function()
						self:Apply(locked)
					end)
				end
				return nil
			end)
		end)
	end)
end)

return CharacterController
