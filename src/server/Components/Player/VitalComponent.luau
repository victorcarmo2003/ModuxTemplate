--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modux = require(ReplicatedStorage.Shared.Modux)

local VitalComponent =
	Modux.Component("VitalComponent"):Tag("VitalComponent"):ClassName("Player"):Import("VitalService")
type Self = typeof(VitalComponent)

export type VitalAttributes = "Armor" | "Health" | "Stamina"

local MAX_STAMINA = 100
local SPRINT_STAMINA_DRAIN_PER_SEC = 20
local SPRINT_STAMINA_REGEN_PER_SEC = 12

local function resetVitals(self)
	self.Armor = 0
	self.Health = 100
	self.Stamina = MAX_STAMINA
	self.Sprinting = false
	self.CanHeal = true
end

VitalComponent.OnDie = VitalComponent.Signal.new() :: Modux.Signal<Player>

VitalComponent.Die = function(self: Self)
	self.VitalService:OnPlayerDie(self.Instance)
end

VitalComponent.ReplicateAll = function(self: Self)
	self.Package:sendKey("Armor", self.Armor, self.Instance)
	self.Package:sendKey("Health", self.Health, self.Instance)
	self.Package:sendKey("Stamina", self.Stamina, self.Instance)
end

VitalComponent.ReplicateKey = function(self: Self, Key: VitalAttributes)
	self.Package:sendKey(Key, self[Key], self.Instance)
end

VitalComponent.TakeDamage = function(self: Self, Amount: number)
	local targetHealth = self.Health - Amount
	if targetHealth <= 0 then
		self.CanHeal = false
		self.Health = 0
		self.Package:sendKey("Health", self.Health, self.Instance)
		self:Die()
		return false
	end
	targetHealth = math.clamp(targetHealth, 0, 100)
	self.Health = targetHealth
	self.Package:sendKey("Health", self.Health, self.Instance)
	return true
end

VitalComponent.SetArmor = function(self: Self, Amount: number)
	self.Armor = Amount
	self.Package:sendKey("Armor", self.Armor, self.Instance)
	return true
end

VitalComponent.Heal = function(self: Self, Amount: number)
	local targetHealth = self.Health + Amount
	targetHealth = math.clamp(targetHealth, 0, 100)
	self.Health = targetHealth
	self.Package:sendKey("Health", self.Health, self.Instance)
	return true
end

VitalComponent.SetStamina = function(self: Self, Amount: number)
	local targetStamina = math.clamp(Amount, 0, MAX_STAMINA)
	if targetStamina == self.Stamina then
		return
	end

	self.Stamina = targetStamina
	self.Package:sendKey("Stamina", self.Stamina, self.Instance)

	if self.Stamina <= 0 and self.Sprinting then
		self.Sprinting = false
		self.VitalService.OnStaminaDepleted:Fire(self.Instance)
	end
end

VitalComponent.CanSprint = function(self: Self): boolean
	return self.Stamina > 0
end

-- Chamado pelo MovementComponent quando entra/sai do estado Running.
-- Retorna false se não houver stamina pra iniciar o sprint.
VitalComponent.SetSprinting = function(self: Self, sprinting: boolean): boolean
	if sprinting and not self:CanSprint() then
		return false
	end
	self.Sprinting = sprinting
	return true
end

VitalComponent:OnInit(function(self)
	resetVitals(self)
	self.Package = self.Network.Packages.VitalKey
	self:Cleanup((self.Instance :: Player).CharacterAdded:Connect(function()
		resetVitals(self)
		self:ReplicateAll()
	end))
end)

VitalComponent:OnTick(function(self, deltaTime: number)
	if self.CanHeal then
		self:Heal(0.5)
	end
end, Modux.TickRate.Hz1)

VitalComponent:OnTick(function(self, deltaTime: number)
	if self.Sprinting then
		self:SetStamina(self.Stamina - SPRINT_STAMINA_DRAIN_PER_SEC * deltaTime)
	elseif self.Stamina < MAX_STAMINA then
		self:SetStamina(self.Stamina + SPRINT_STAMINA_REGEN_PER_SEC * deltaTime)
	end
end, Modux.TickRate.Hz10)

return VitalComponent
