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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const FROZEN_ATTRIBUTE = "Frozen"
const FAINTED_FACE = "Fainted" -- Content.Looks expression (DEC-216, Provisional DEC-167)

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

-- PlayerModule controls (stock Roblox), loaded once; nil if the module is missing (custom player scripts).
function CharacterController:GetControls(): Controls?
	if self.Controls ~= nil then
		return self.Controls
	end
	const scripts = Players.LocalPlayer:WaitForChild("PlayerScripts", 10)
	const module = if scripts ~= nil then scripts:WaitForChild("PlayerModule", 10) else nil
	if module == nil or not module:IsA("ModuleScript") then
		warn("[CharacterController] PlayerModule not found: controls cannot be locked")
		return nil
	end
	const ok, result = pcall(require, module)
	if not ok then
		warn(`[CharacterController] PlayerModule failed to load: {result}`)
		return nil
	end
	const controls = (result :: PlayerModule):GetControls()
	self.Controls = controls
	return controls
end

function CharacterController:Apply(locked: boolean)
	self.Applied = locked
	const controls = self:GetControls()
	if controls ~= nil then
		if locked then
			controls:Disable()
		else
			controls:Enable()
		end
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
