--!strict
-- Revive Kit credits (TASK-317; closes Q-273; DEC-117, DEC-129, DEC-255; Provisional). The util_revive product
-- (ShopUtilityService) adds profile.ReviveCredits; this service spends them, one per revive, through VitalService:Revive
-- (which owns the Down -> Active path and Content.Revive.MaxPerNight). Run place only.
--   Self   ReviveKitUse (c -> s): the Down player spends one credit on itself (the "Use Revive Kit" button of the
--          faint screen, ReviveKitController)
--   Mate   revive_mate on Prompt_Revive, an anchor this service puts on the HRP of a member's body while it is Down
--          (InteractionService: range, the Vital gate keeps the reviver Active); the credit is the reviver's
--   Count  ReviveKits (s -> owner) on Ready, on profile load and after every change, so the client shows the button
--          and the mate prompt only with credits
-- The credit is spent only when VitalService:Revive returned true, then the profile is saved.
-- Note: DEC-116 keeps the Robux revive self-only; a kit used on a mate was asked by the owner session (TASK-317) and
-- DEC-255 ("revivable by a mate with a Revive Kit"). Provisional until the owner confirms (Q-273 note).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const ACTION = "revive_mate"
const ANCHOR = "Prompt_Revive"
const INTERACTABLE_TAG = "Interactable"
const USE_GAP = 1 -- s between two ReviveKitUse of the same player
const CREDITS_MAX = 99

const ReviveKitService = Modux.Service("ReviveKitService", {
	Require = {
		"ProfileService",
		"NetService",
		"PlaceService",
		"VitalService",
		"InteractionService",
		"RunStateService",
	},
	Priority = 410,
})

function ReviveKitService:Setup()
	self.UseAt = {} :: { [Player]: number }
end

function ReviveKitService:Credits(player: Player): number
	const profile = self.Dependencies.ProfileService:Get(player)
	if profile == nil then
		return 0
	end
	return math.clamp(math.floor(profile.ReviveCredits()), 0, CREDITS_MAX)
end

function ReviveKitService:SendCount(player: Player)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or not net:IsReady(player) then
		return
	end
	self.Libs.Net.ReviveKits:fireClient(player, { Count = self:Credits(player) })
end

-- One credit of `payer` on `target` (self or a fallen mate). True when the revive happened and the credit was spent.
function ReviveKitService:Use(payer: Player, target: Player): boolean
	const credits = self:Credits(payer)
	if credits <= 0 then
		return false
	end
	if not self.Dependencies.VitalService:Revive(target, payer) then
		return false
	end
	const profiles = self.Dependencies.ProfileService
	profiles:Update(payer, { ReviveCredits = credits - 1 })
	profiles:RequestSave(payer)
	self:SendCount(payer)
	return true
end

-- The fallen member whose body carries this anchor (Prompt_Revive under the HRP), if still Down and not `player`.
function ReviveKitService:FallenOf(player: Player, anchor: Instance): Player?
	const root = anchor.Parent
	const character = if root ~= nil then root.Parent else nil
	if character == nil or not character:IsA("Model") then
		return nil
	end
	const owner = Players:GetPlayerFromCharacter(character)
	if owner == nil or owner == player then
		return nil
	end
	if self.Dependencies.VitalService:GetState(owner.UserId) ~= "Down" then
		return nil
	end
	return owner
end

function ReviveKitService:AddAnchor(userId: number)
	const player = Players:GetPlayerByUserId(userId)
	const character = if player ~= nil then player.Character else nil
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") or root:FindFirstChild(ANCHOR) ~= nil then
		return
	end
	const anchor = Instance.new("Attachment")
	anchor.Name = ANCHOR
	anchor:SetAttribute("PromptAction", ACTION)
	anchor:SetAttribute("PromptEnabled", true)
	anchor.Parent = root
	CollectionService:AddTag(anchor, INTERACTABLE_TAG)
end

function ReviveKitService:RemoveAnchor(userId: number)
	const player = Players:GetPlayerByUserId(userId)
	const character = if player ~= nil then player.Character else nil
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	const anchor = if root ~= nil then root:FindFirstChild(ANCHOR) else nil
	if anchor ~= nil then
		anchor:Destroy()
	end
end

ReviveKitService:OnInit(function(self)
	self:Setup()

	const profiles = self.Dependencies.ProfileService
	profiles.Loaded:Connect(function(player)
		self:SendCount(player)
	end)
	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:SendCount(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.UseAt[player] = nil
	end)

	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	self.Libs.Net.ReviveKitUse:onServer(function(_, player: Player)
		const now = os.clock()
		const last = self.UseAt[player]
		if last ~= nil and now - last < USE_GAP then
			return
		end
		self.UseAt[player] = now
		self:Use(player, player)
	end)

	self.Dependencies.InteractionService:RegisterAction(ACTION, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			return self:Credits(player) > 0 and self:FallenOf(player, anchor) ~= nil
		end,
		Run = function(player: Player, anchor: Instance, _id: number)
			const fallen = self:FallenOf(player, anchor)
			if fallen ~= nil then
				self:Use(player, fallen)
			end
		end,
	})

	self.Dependencies.RunStateService.LifeChanged:Connect(function(userId, _old, new)
		if new == "Down" then
			-- the body faints right after the state change: put the anchor once the frame settles
			task.defer(function()
				if self.Dependencies.VitalService:GetState(userId) == "Down" then
					self:AddAnchor(userId)
				end
			end)
		else
			self:RemoveAnchor(userId)
		end
	end)
end)

return ReviveKitService
