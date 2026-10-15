--!strict
--[[
	ReviveKitController (TASK-317; closes Q-273; Provisional)

	Presents the Revive Kit credits (profile.ReviveCredits, util_revive). ReviveKitService decides every revive.
	  - Count: packet `ReviveKits` (s -> owner).
	  - Self: while the local player is Down and has credits, a "Use Revive Kit (n)" button over the faint / spectate
	    screen (own ScreenGui "ReviveKit"); R (keyboard) and ButtonY (gamepad) do the same while it shows. Sends
	    `ReviveKitUse`; the button waits for the answer (a new count or the state change) before it can fire again.
	  - Revive now (TASK-330): while Down without credits, the same button reads "Revive now · R$ n" and opens the
	    util_revive purchase; ShopUtilityService spends the new credit on the buyer at once when it is still Down. The
	    button stays busy until the prompt closes. Both forms hide outside Call / Prep / Night (NightLost, RunEnd:
	    VitalService:Revive refuses there).
	  - Mate: the `revive_mate` prompt on a fallen mate's body (Prompt_Revive) shows only with credits
	    (PromptController:AddGate("ReviveKit")). Range, hold and the reviver's own state are the PromptController's.
	Game servers only (the lobby has no Down).
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local CartoonButton = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonButton)

const ACTION = "revive_mate"
const GATE = "ReviveKit"
const BIND = "ReviveKitUse"
const BIND_KEY = Enum.KeyCode.R
const BIND_PAD = Enum.KeyCode.ButtonY
const DISPLAY_ORDER = 15 -- over the HUD (spectate status), under the settings / shop windows (20)
const WAIT = 2 -- s the button stays busy after a use without an answer
const PRODUCT = "util_revive"
-- phases where a Down can still be revived (RoundService Flow LOSABLE, night only)
const LIVE_PHASES: { [string]: boolean } = { Call = true, Prep = true, Night = true }

const ReviveKitController = Modux.Controller("ReviveKitController", {
	Require = {
		"PlaceController",
		"VitalController",
		"PromptController",
		"InputController",
		"RoundController",
		"ShopController",
	},
	Priority = 540,
})

function ReviveKitController:Setup()
	self.Count = Vide.source(0) :: Vide.Source<number>
	self.Busy = Vide.source(false) :: Vide.Source<boolean>
	self.Bound = false :: boolean
	self.Gui = nil :: ScreenGui?
end

function ReviveKitController:Shows(): boolean
	const round = self.Dependencies.RoundController
	return self.Dependencies.VitalController.LocalState() == "Down" and round.IsNight() and LIVE_PHASES[round.Phase()] == true
end

-- "Revive now" needs a live product id; credits always work
function ReviveKitController:CanBuy(): boolean
	const utility = Content.Shop.Utilities.ByKey[PRODUCT]
	return utility ~= nil and utility.ProductId > 0
end

function ReviveKitController:Label(): string
	const count = self.Count()
	if count > 0 then
		return `Use Revive Kit ({count})`
	end
	const utility = Content.Shop.Utilities.ByKey[PRODUCT]
	return `Revive now · {self.Dependencies.ShopController:PriceOf(utility)}`
end

function ReviveKitController:Use()
	const down = Vide.untrack(self.Dependencies.VitalController.LocalState) == "Down"
	if Vide.untrack(self.Busy) or not down then
		return
	end
	if Vide.untrack(self.Count) <= 0 then
		self:Buy()
		return
	end
	self.Busy(true)
	self.Libs.Net.ReviveKitUse:fireServer()
	task.delay(WAIT, function()
		self.Busy(false)
	end)
end

-- Opens the util_revive purchase (TASK-330). The server revives on the receipt; the button waits for the prompt.
function ReviveKitController:Buy()
	if not self:CanBuy() then
		return
	end
	const utility = Content.Shop.Utilities.ByKey[PRODUCT]
	self.Busy(true)
	const ok, problem = pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, utility.ProductId)
	end)
	if not ok then
		warn(`[ReviveKitController] PromptProductPurchase {PRODUCT}: {problem}`)
		self.Busy(false)
	end
end

-- The key bind lives only while the button shows (R / ButtonY are other actions' keys when standing).
function ReviveKitController:SetBound(on: boolean)
	if on == self.Bound then
		return
	end
	self.Bound = on
	const input = self.Dependencies.InputController
	if on then
		input
			:Bind({
				Name = BIND,
				Key = BIND_KEY,
				Keys = { BIND_PAD },
				Priority = 20,
			})
			.OnPress(function()
				self:Use()
			end)
	else
		input:Unbind(BIND)
	end
end

function ReviveKitController:Mount(playerGui: Instance)
	const _, gui = Vide.root(function()
		Vide.effect(function()
			const shows = self:Shows() and (self.Count() > 0 or self:CanBuy())
			Vide.untrack(function()
				self:SetBound(shows)
				return nil
			end)
		end)

		return Vide.create("ScreenGui")({
			Name = "ReviveKit",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = DISPLAY_ORDER,
			Enabled = function()
				return not Cinematic.Active()
			end,

			CartoonButton({
				Name = "UseReviveKit",
				Text = function()
					return self:Label()
				end,
				Icon = "Item/revive_kit",
				Enabled = function()
					return not self.Busy()
				end,
				Visible = function()
					return self:Shows() and (self.Count() > 0 or self:CanBuy())
				end,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -140),
				OnActivated = function()
					self:Use()
				end,
			}),
		})
	end)
	self.Gui = gui
	gui.Parent = playerGui
end

ReviveKitController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.ReviveKits:onClient(function(data)
		self.Count(data.Count)
		self.Busy(false)
	end)

	-- Revive now: the purchase window closed (bought or not); a bought kit arrives as the state change / count
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, _bought: boolean)
		const utility = Content.Shop.Utilities.ByKey[PRODUCT]
		if userId == Players.LocalPlayer.UserId and utility ~= nil and productId == utility.ProductId then
			self.Busy(false)
		end
	end)
end)

ReviveKitController:OnStart(function(self)
	if self.Dependencies.PlaceController:Is("Lobby") then
		return
	end

	self.Dependencies.PromptController:AddGate(GATE, function(anchor: Instance): boolean
		if anchor:GetAttribute("PromptAction") ~= ACTION then
			return true
		end
		return Vide.untrack(self.Count) > 0
	end)

	-- a revive (or the 6:00 AM Spectator) ends the wait at once
	Vide.root(function()
		Vide.effect(function()
			self.Dependencies.VitalController.LocalState()
			Vide.untrack(function()
				self.Busy(false)
				return nil
			end)
		end)
		return nil
	end)

	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return ReviveKitController
