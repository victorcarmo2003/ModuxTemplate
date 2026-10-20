--!strict
--[[
	ReviveKitController (TASK-317; closes Q-273; Provisional)

	Presents the Revive Kit credits (profile.ReviveCredits, util_revive). ReviveKitService decides every revive.
	  - Count: packet `ReviveKits` (s -> owner).
	  - Self: while the local player is Down and has credits, a "Use Revive Kit (n)" button in the centre of the
	    screen (own ScreenGui "ReviveKit"); R (keyboard) and ButtonY (gamepad) do the same while it shows. Sends
	    `ReviveKitUse`; the button waits for the answer (a new count or the state change) before it can fire again.
	  - Revive (TASK-330): while Down without credits, the same button reads "Revive · R$ n" and opens the util_revive
	    purchase; ShopUtilityService spends the new credit on the buyer at once when it is still Down. The button stays
	    busy until the prompt closes. Hidden outside Call / Prep / Night (NightLost, RunEnd: VitalService:Revive refuses
	    there).
	  - Fall screens (DEC-318, design/faint-screen-flow.md; owner: "the screen clean during the countdowns, only that
	    product in the centre and the count"). `Stage` drives one view at a time, the spectate HUD hidden meanwhile:
	      Cause      Revive.CauseTime s after my fall: "WHAT GOT YOU", the cause and how to get past it (FaintTips)
	      Countdown  Down with someone standing: the seconds left (Vitals StateEndsAt) over the revive button; at 0 the
	                 server makes me a Spectator until the next night (normal spectate, no offer)
	      Wait       nobody standing with a team life left: nothing, until NightLost breaks the heart
	      ReviveAll  nobody standing and no life left: the seconds left over "Revive all" (util_revive_all, everyone
	                 sees it; VitalService:ReviveAll stands the whole crew up)
	    Both the count and the button sit in a full-screen frame scaled like the HUD (UiScale) inside a centred row.
	  - Mate: the `revive_mate` prompt on a fallen mate's body (Prompt_Revive) shows only with credits
	    (PromptController:AddGate("ReviveKit")). Range, hold and the reviver's own state are the PromptController's.
	  - Focus: true for FOCUS_TIME s after the fall (HudSpectate reads it).
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
local CartoonLabel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonLabel)
local Icons = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Icons)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local UiScale = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.UiScale)

const ACTION = "revive_mate"
const GATE = "ReviveKit"
const BIND = "ReviveKitUse"
const BIND_KEY = Enum.KeyCode.R
const BIND_PAD = Enum.KeyCode.ButtonY
const DISPLAY_ORDER = 15 -- over the HUD (spectate status), under the settings / shop windows (20)
const WAIT = 2 -- s the button stays busy after a use without an answer
const PRODUCT = "util_revive"
const PRODUCT_ALL = "util_revive_all" -- DEC-318
const ICON = "Life/revive" -- AST-166
const ICON_OLD = "Item/revive_kit"
-- s HudSpectate's focus lasts after the fall (DEC-294)
const FOCUS_TIME = 7
-- px at UI scale 1: the button starts this far under the screen centre (the count sits above it)
const FOCUS_GAP = 6
const FOCUS_HEIGHT = 64
const COUNT_SIZE = 84 -- px of the countdown number
const CAUSE_WIDTH = 420
const TICK_RATE = 10 -- Hz of the server clock read by the countdowns
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance
-- phases where a Down can still be revived (RoundService Flow LOSABLE, night only)
const LIVE_PHASES: { [string]: boolean } = { Call = true, Prep = true, Night = true }

export type Stage = "None" | "Cause" | "Countdown" | "Wait" | "ReviveAll"

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
	-- true for FOCUS_TIME s after the local player goes Down; HudSpectate follows it
	self.Focus = Vide.source(false) :: Vide.Source<boolean>
	self.FocusThread = nil :: thread?
	-- DEC-318: server time now (TICK_RATE) and until when the cause card of my last fall shows
	self.Now = Vide.source(0) :: Vide.Source<number>
	self.CauseUntil = Vide.source(0) :: Vide.Source<number>
end

function ReviveKitController:Shows(): boolean
	const round = self.Dependencies.RoundController
	return self.Dependencies.VitalController.LocalState() == "Down" and round.IsNight() and LIVE_PHASES[round.Phase()] == true
end

-- The one fall screen showing now (DEC-318)
function ReviveKitController:Stage(): Stage
	const round = self.Dependencies.RoundController
	if not round.IsNight() or LIVE_PHASES[round.Phase()] ~= true then
		return "None"
	end
	const state = self.Dependencies.VitalController.LocalState()
	const now = self.Now()
	if (state == "Down" or state == "Spectator") and now < self.CauseUntil() then
		return "Cause"
	end
	const wipe = round.WipeEndsAt()
	if wipe > 0 then
		if round.Chances() <= 0 and now >= wipe - Content.Revive.ReviveAllWindow then
			return "ReviveAll"
		end
		return "Wait"
	end
	return if state == "Down" then "Countdown" else "None"
end

-- Whole seconds left on the countdown of the stage (0 when none)
function ReviveKitController:Seconds(): number
	const stage = self:Stage()
	local endsAt = 0
	if stage == "ReviveAll" then
		endsAt = self.Dependencies.RoundController.WipeEndsAt()
	elseif stage == "Countdown" then
		const member = self.Dependencies.VitalController.Members()[Players.LocalPlayer.UserId]
		endsAt = if member then member.StateEndsAt else 0
	end
	return math.max(0, math.ceil(endsAt - self.Now()))
end

-- What got me (FaintTips); the generic line while the server has not said
function ReviveKitController:Tip(): Content.FaintTip
	const tip = (self.Dependencies.VitalController.FaintTip :: () -> Content.FaintTip?)()
	return tip or Content.FaintTips.Generic
end

-- The offer can show: the countdown with a credit or a buyable kit, or the last-life "Revive all"
function ReviveKitController:Offered(): boolean
	const stage = self:Stage()
	if stage == "ReviveAll" then
		return true
	end
	return stage == "Countdown" and self:Shows() and (self.Count() > 0 or self:CanBuy())
end

-- Starts the focus window on a fall; any other state ends it at once.
function ReviveKitController:SetFocus(down: boolean)
	const thread = self.FocusThread
	if thread and coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
	self.FocusThread = nil
	if Vide.untrack(self.Focus) ~= down then
		self.Focus(down)
	end
	if down then
		self.FocusThread = task.delay(FOCUS_TIME, function()
			self.FocusThread = nil
			self.Focus(false)
		end)
	end
end

-- "Revive" needs a live product id; credits always work
function ReviveKitController:CanBuy(): boolean
	const utility = Content.Shop.Utilities.ByKey[PRODUCT]
	return utility ~= nil and utility.ProductId > 0
end

function ReviveKitController:Label(): string
	const shop = self.Dependencies.ShopController
	if self:Stage() == "ReviveAll" then
		return `Revive all · {shop:PriceOf(Content.Shop.Utilities.ByKey[PRODUCT_ALL])}`
	end
	const count = self.Count()
	if count > 0 then
		return `Use Revive Kit ({count})`
	end
	return `Revive · {shop:PriceOf(Content.Shop.Utilities.ByKey[PRODUCT])}`
end

function ReviveKitController:Use()
	if Vide.untrack(self.Busy) then
		return
	end
	const stage = Vide.untrack(function()
		return self:Stage()
	end)
	if stage == "ReviveAll" then
		self:Buy(PRODUCT_ALL)
		return
	end
	if Vide.untrack(self.Dependencies.VitalController.LocalState) ~= "Down" then
		return
	end
	if Vide.untrack(self.Count) <= 0 then
		self:Buy(PRODUCT)
		return
	end
	self.Busy(true)
	self.Libs.Net.ReviveKitUse:fireServer()
	task.delay(WAIT, function()
		self.Busy(false)
	end)
end

-- Opens a revive purchase (TASK-330; util_revive_all, DEC-318). The server revives on the receipt; the button waits
-- for the prompt.
function ReviveKitController:Buy(key: string)
	const utility = Content.Shop.Utilities.ByKey[key]
	if utility == nil or utility.ProductId <= 0 then
		warn(`[ReviveKitController] {key} has no ProductId yet (Content.Shop)`)
		return
	end
	self.Busy(true)
	self.Libs.Net.MetricUi:fireServer({ Event = "revive_prompt", Key = key }) -- analytics
	const ok, problem = pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, utility.ProductId)
	end)
	if not ok then
		warn(`[ReviveKitController] PromptProductPurchase {key}: {problem}`)
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

-- The offer: a full-width row that centres the button (its width is measured, so a lone anchored button drifts off
-- centre while the label settles).
function ReviveKitController:Offer(): Frame
	return Vide.create("Frame")({
		Name = "Focus",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, FOCUS_GAP),
		Size = UDim2.new(1, 0, 0, FOCUS_HEIGHT),
		BackgroundTransparency = 1,
		Visible = function()
			return self:Offered()
		end,
		Vide.create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		CartoonButton({
			Name = "UseReviveKit",
			Text = function()
				return self:Label()
			end,
			TextSize = 26,
			Icon = if Icons.Has(ICON) then ICON else ICON_OLD,
			IconSize = 44,
			Padding = 26,
			Outline = Theme.Outline.Thick,
			Studs = true,
			Size = UDim2.fromOffset(0, FOCUS_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			Enabled = function()
				return not self.Busy()
			end,
			OnActivated = function()
				self:Use()
			end,
		}),
	}) :: Frame
end

-- The cause card (DEC-318): small caption, the cause, the tip; pops in with the Cause stage
function ReviveKitController:CauseCard(): Frame
	const scale = Motion.Pop(function()
		return self:Stage() == "Cause"
	end)
	return Vide.create("Frame")({
		Name = "Cause",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(CAUSE_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = function()
			return scale() > 0.02
		end,
		createRaw("UIScale")({ Scale = scale }),
		Vide.create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		CartoonLabel({
			Name = "Label",
			LayoutOrder = 1,
			Text = Content.FaintTips.Label,
			TextSize = 16,
			Color = Theme.Color.Mustard,
		}),
		CartoonLabel({
			Name = "Title",
			LayoutOrder = 2,
			Box = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Wrapped = true,
			Text = function()
				return self:Tip().Title
			end,
			TextSize = 38,
			Stroke = 4,
		}),
		CartoonLabel({
			Name = "Tip",
			LayoutOrder = 3,
			Box = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Wrapped = true,
			Text = function()
				return self:Tip().Tip
			end,
			TextSize = 20,
			Color = Theme.Color.Cream,
		}),
	}) :: Frame
end

function ReviveKitController:Mount(playerGui: Instance)
	const _, gui = Vide.root(function()
		Vide.effect(function()
			const shows = self:Offered()
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

			Vide.create("Frame")({
				Name = "Offer",
				Size = function()
					const scale = UiScale.Current()
					return UDim2.fromScale(1 / scale, 1 / scale)
				end,
				BackgroundTransparency = 1,
				createRaw("UIScale")({ Scale = UiScale.Current }),

				-- Cause: what got me and how to get past it, alone in the centre
				self:CauseCard(),

				-- Countdown / ReviveAll: the seconds left over the centre, the offer right under it
				CartoonLabel({
					Name = "Count",
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 0.5, -FOCUS_GAP),
					Text = function()
						return tostring(self:Seconds())
					end,
					TextSize = COUNT_SIZE,
					Stroke = 5,
					Visible = function()
						const stage = self:Stage()
						return stage == "Countdown" or stage == "ReviveAll"
					end,
				}),
				self:Offer(),
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

	-- a revive purchase window closed (bought or not); a bought one arrives as the state change / count
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, _bought: boolean)
		if userId ~= Players.LocalPlayer.UserId then
			return
		end
		for _, key in { PRODUCT, PRODUCT_ALL } do
			const utility = Content.Shop.Utilities.ByKey[key]
			if utility ~= nil and productId == utility.ProductId then
				self.Busy(false)
			end
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

	-- a revive (or the Spectator) ends the wait at once; a fall opens the focus window and the cause card
	Vide.root(function()
		local standing = true
		Vide.effect(function()
			const state = self.Dependencies.VitalController.LocalState()
			Vide.untrack(function()
				self.Busy(false)
				self:SetFocus(state == "Down")
				const up = state == "Active" or state == "Reviving"
				if standing and (state == "Down" or state == "Spectator") then
					self.CauseUntil(workspace:GetServerTimeNow() + Content.Revive.CauseTime)
				elseif up then
					self.CauseUntil(0)
				end
				standing = up
				return nil
			end)
		end)
		return nil
	end)

	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

ReviveKitController:OnTick(function(self)
	-- tenths are enough for whole seconds and the cause card
	const now = math.floor(workspace:GetServerTimeNow() * TICK_RATE) / TICK_RATE
	if now ~= Vide.untrack(self.Now) then
		self.Now(now)
	end
end, TICK_RATE)

return ReviveKitController
