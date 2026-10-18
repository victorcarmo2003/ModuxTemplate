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
	  - Clean faint screen (TASK-485, DEC-294): for FOCUS_TIME s after the fall (`Focus`) the offer is BIG in the centre
	    of the screen, under the "You fainted!" title (HudSpectate); after that it is a small button right above the
	    spectate pill, still usable. Same Use / Buy either way; only where and how big changes. Both sit in a full-screen
	    frame scaled like the HUD (UiScale) inside a centred row, so they stay centred whatever their measured width.
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
-- s the offer stays big in the centre after the fall (DEC-294: 5-10 s; Provisional)
const FOCUS_TIME = 7
-- px at UI scale 1: the big offer starts this far under the screen centre (the title sits above it)
const FOCUS_GAP = 6
const FOCUS_HEIGHT = 64
-- px at UI scale 1 from the bottom: the small offer sits over the spectate pill (HudSpectate: 84 + pill 40 + hint)
const SMALL_BOTTOM = 158
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance
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
	-- true for FOCUS_TIME s after the local player goes Down (the big centred offer); HudSpectate follows it too
	self.Focus = Vide.source(false) :: Vide.Source<boolean>
	self.FocusThread = nil :: thread?
end

function ReviveKitController:Shows(): boolean
	const round = self.Dependencies.RoundController
	return self.Dependencies.VitalController.LocalState() == "Down" and round.IsNight() and LIVE_PHASES[round.Phase()] == true
end

-- The offer can show: Down in a live phase with a credit or a buyable kit
function ReviveKitController:Offered(): boolean
	return self:Shows() and (self.Count() > 0 or self:CanBuy())
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
	self.Libs.Net.MetricUi:fireServer({ Event = "revive_prompt", Key = PRODUCT }) -- analytics
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

type Look = { TextSize: number, IconSize: number, Padding: number, Outline: number?, Studs: boolean? }

-- One form of the offer: a full-width row that centres the button (its width is measured, so a lone anchored button
-- drifts off centre while the label settles).
function ReviveKitController:Row(
	name: string,
	anchor: Vector2,
	position: UDim2,
	height: number,
	visible: () -> boolean,
	look: Look
): Frame
	return Vide.create("Frame")({
		Name = name,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		Visible = visible,
		Vide.create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		CartoonButton({
			Name = if name == "Focus" then "UseReviveKit" else `UseReviveKit{name}`,
			Text = function()
				return self:Label()
			end,
			TextSize = look.TextSize,
			Icon = "Item/revive_kit",
			IconSize = look.IconSize,
			Padding = look.Padding,
			Outline = look.Outline,
			Studs = look.Studs,
			Size = UDim2.fromOffset(0, height),
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

				-- phase 1: big, centred, under the title
				self:Row("Focus", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.5, FOCUS_GAP), FOCUS_HEIGHT, function()
					return self:Offered() and self.Focus()
				end, {
					TextSize = 26,
					IconSize = 44,
					Padding = 26,
					Outline = Theme.Outline.Thick,
					Studs = true,
				}),

				-- phase 2: small, over the spectate pill
				self:Row("Small", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -SMALL_BOTTOM), Theme.MinTouch, function()
					return self:Offered() and not self.Focus()
				end, {
					TextSize = 15,
					IconSize = 24,
					Padding = 12,
				}),
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

	-- a revive (or the 6:00 AM Spectator) ends the wait at once; a fall opens the focus window
	Vide.root(function()
		Vide.effect(function()
			const state = self.Dependencies.VitalController.LocalState()
			Vide.untrack(function()
				self.Busy(false)
				self:SetFocus(state == "Down")
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
