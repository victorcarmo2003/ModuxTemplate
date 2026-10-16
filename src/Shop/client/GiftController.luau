--!strict
--[[
	GiftController (TASK-353; owner request 2026-10-16, Provisional; contract TASK-352: Content.Shop.Gifts, packets
	GiftPrompt / GiftResult)

	The giver side of a gift. Every lobby shop (GemShop cards, ClassSelect buy row) has a GiftButton next to Buy; it
	calls Open(giftKey) and this controller shows the recipient picker (GiftPicker, own ScreenGui over the lobby):
	  - candidates: the players of this server (never yourself) and the one found by username
	    (Players:GetUserIdFromNameAsync + GetNameFromUserIdAsync, in pcall);
	  - Send: GiftPrompt { Key, Recipient } -> the server answers GiftResult. Ok = this client prompts the gift product
	    (MarketplaceService:PromptProductPurchase, Content.Shop.Gifts[Key].ProductId) and the picker closes; any other
	    reason = a toast and the picker stays open. After the receipt: Sent ("Gift sent to <name>!") or Failed (Roblox
	    retries the receipt later).
	  - ProductId 0 = "Soon": the gift button is disabled and Send never fires (the server refuses too).
	Close: the close button, ButtonB (bound only while open, over LobbyController's Close), the Roblox menu (Esc).
	Toasts go through the toaster the lobby sets (SetToaster); without one they only warn.
	The recipient's celebration (GiftReceived) is PurchaseFxController's.
]]
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Backdrop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Backdrop)
local GiftPicker = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.GiftPicker)

export type Kind = "Info" | "Good" | "Alert"
export type Toaster = (text: string, kind: Kind) -> ()

const DISPLAY_ORDER = 8 -- over the lobby windows (Lobby 6)
const CLOSE_BIND = "GiftPickerClose"
const CLOSE_PRIORITY = 20 -- over LobbyController's Close (10): ButtonB closes the picker, not the shop under it
const ANSWER_TIMEOUT = 6 -- s without a GiftResult: the Send button comes back
const CLICK_SOUND = "ui_click"

-- GiftResult reasons that refuse the gift before any purchase
const REFUSED: { [string]: string } = {
	Self = "You can't send a gift to yourself.",
	NotFound = "That player could not be found.",
	Unavailable = "This gift is not on sale yet.",
	Rate = "Slow down a little and try again.",
	Busy = "Another gift is on its way. Try again in a moment.",
}

const GiftController = Modux.Controller("GiftController", {
	Require = { "InputController", "AudioController" },
	Priority = 450,
})

function GiftController:Setup()
	self.Key = Vide.source("") :: Vide.Source<string>
	self.Shown = Vide.source(false) :: Vide.Source<boolean>
	self.Selected = Vide.source(0) :: Vide.Source<number>
	self.Roster = Vide.source({}) :: Vide.Source<{ GiftPicker.Candidate }>
	-- the player found by username (0 or 1 entry; a list, since an optional source is ambiguous to call)
	self.Found = Vide.source({}) :: Vide.Source<{ GiftPicker.Candidate }>
	self.Lookup = Vide.source({ Kind = "None", Text = "" } :: GiftPicker.Lookup) :: Vide.Source<GiftPicker.Lookup>
	self.Busy = Vide.source(false) :: Vide.Source<boolean>
	-- UI scale of the lobby windows (LobbyController pushes its own; 1 elsewhere)
	self.Scale = Vide.source(1) :: Vide.Source<number>
	-- username lookups in flight: only the newest answer counts
	self.SearchId = 0 :: number
	-- GiftPrompt on its way (key, os.clock of the send); "" = none
	self.Waiting = "" :: string
	self.SentAt = 0 :: number
	-- gift key -> display name of its last recipient ("Gift sent to <name>!")
	self.Recipients = {} :: { [string]: string }
	self.Toaster = nil :: Toaster?
	self.CloseHandle = nil :: any
	self.Before = nil :: GuiObject?
	self.Gui = nil :: ScreenGui?
end

-- Gift rows ---------------------------------------------------------------------------------------------------------

-- Gift row of a gem pack / class key (Key = "gift_" .. Target); nil = not giftable.
function GiftController:GiftOf(target: string): Content.ShopGift?
	return Content.Shop.Gifts.ByKey[`gift_{target}`]
end

-- The gift exists and its product is created (the button is pressable).
function GiftController:CanGift(target: string): boolean
	const gift = self:GiftOf(target)
	return gift ~= nil and gift.ProductId > 0
end

-- Shown name of a gift: the item's own name ("Handful of Gems", "Cat Crew").
function GiftController:TitleOf(key: string): string
	const gift = Content.Shop.Gifts.ByKey[key]
	if gift == nil then
		return "a gift"
	end
	if gift.Kind == "Gems" then
		const pack = Content.Shop.GemPacks.ByKey[gift.Target]
		return if pack then pack.Name else gift.Name
	end
	const pass = Content.Shop.GamePasses.ByKey[gift.Target]
	return if pass then pass.Name else gift.Name
end

function GiftController:PriceOf(key: string): string
	const gift = Content.Shop.Gifts.ByKey[key]
	return if gift then `R$ {gift.Robux}` else ""
end

-- Toasts ------------------------------------------------------------------------------------------------------------

function GiftController:SetToaster(toaster: Toaster?)
	self.Toaster = toaster
end

function GiftController:Say(text: string, kind: Kind)
	const toaster = self.Toaster
	if toaster then
		toaster(text, kind)
	else
		warn(`[GiftController] {text}`)
	end
end

function GiftController:Click()
	pcall(function()
		self.Dependencies.AudioController:Play(CLICK_SOUND)
	end)
end

-- Picker ------------------------------------------------------------------------------------------------------------

function GiftController:Candidates(): { GiftPicker.Candidate }
	const list: { GiftPicker.Candidate } = {}
	const found = self.Found()[1]
	const roster = self.Roster()
	if found then
		local listed = false
		for _, candidate in roster do
			if candidate.UserId == found.UserId then
				listed = true
				break
			end
		end
		if not listed then
			table.insert(list, found)
		end
	end
	for _, candidate in roster do
		table.insert(list, candidate)
	end
	return list
end

-- `leaving`: a player on its way out (PlayerRemoving fires while it is still listed).
function GiftController:RefreshRoster(leaving: Player?)
	const me = Players.LocalPlayer
	const list: { GiftPicker.Candidate } = {}
	for _, player in Players:GetPlayers() do
		if player ~= me and player ~= leaving then
			table.insert(list, { UserId = player.UserId, Name = player.Name, DisplayName = player.DisplayName })
		end
	end
	table.sort(list, function(a, b)
		return string.lower(a.DisplayName) < string.lower(b.DisplayName)
	end)
	self.Roster(list)
	-- a picked player who left can no longer be picked from the list (a found username stays)
	const selected = Vide.untrack(self.Selected)
	if selected > 0 then
		const found = Vide.untrack(self.Found)[1]
		local still = found ~= nil and found.UserId == selected
		for _, candidate in list do
			if candidate.UserId == selected then
				still = true
			end
		end
		if not still then
			self.Selected(0)
		end
	end
end

-- Opens the picker for the gift row `key` (Content.Shop.Gifts).
function GiftController:Open(key: string)
	const gift = Content.Shop.Gifts.ByKey[key]
	if gift == nil then
		return
	end
	if gift.ProductId <= 0 then
		self:Say("This gift is coming soon.", "Info")
		return
	end
	self:Click()
	self.Key(key)
	self.Selected(0)
	self.Found({})
	self.Lookup({ Kind = "None", Text = "" })
	self:RefreshRoster()
	if not Vide.untrack(self.Shown) then
		self.Before = GuiService.SelectedObject
		self.Shown(true)
		self:BindClose()
	end
	task.defer(function()
		self:SelectFirst()
	end)
end

function GiftController:Close()
	if not Vide.untrack(self.Shown) then
		return
	end
	self.Shown(false)
	self.SearchId += 1
	self:UnbindClose()
	const gui = self.Gui
	const selected = GuiService.SelectedObject
	if gui and selected and selected:IsDescendantOf(gui) then
		const before = self.Before
		GuiService.SelectedObject = if before and before.Parent then before else nil
	end
	self.Before = nil
end

function GiftController:IsOpen(): boolean
	return Vide.untrack(self.Shown)
end

function GiftController:SelectFirst()
	if Vide.untrack(self.Dependencies.InputController.Device) ~= "Gamepad" then
		return
	end
	const gui = self.Gui
	if gui == nil or not Vide.untrack(self.Shown) then
		return
	end
	for _, name in { "Recipient", "Username" } do
		for _, descendant in gui:GetDescendants() do
			if descendant.Name == name and descendant:IsA("GuiObject") and descendant.Visible then
				GuiService.SelectedObject = descendant
				return
			end
		end
	end
end

function GiftController:BindClose()
	if self.CloseHandle then
		return
	end
	self.CloseHandle = self.Dependencies.InputController
		:Bind({
			Name = CLOSE_BIND,
			Key = Enum.KeyCode.ButtonB,
			Priority = CLOSE_PRIORITY,
		})
		.OnPress(function()
			self:Click()
			self:Close()
		end)
end

function GiftController:UnbindClose()
	const handle = self.CloseHandle
	if handle then
		self.CloseHandle = nil
		handle.Unbind()
	end
end

function GiftController:Select(userId: number)
	self:Click()
	self.Selected(userId)
end

-- Username box: resolves a Roblox username (any player, online or not) and picks it.
function GiftController:Search(raw: string)
	const name = string.match(raw, "^@?%s*([%w_]+)%s*$")
	if name == nil or #name < 3 or #name > 20 then
		self.Lookup({ Kind = "Missing", Text = "Usernames have 3 to 20 letters, digits or _" })
		return
	end
	self:Click()
	self.SearchId += 1
	const id = self.SearchId
	self.Lookup({ Kind = "Wait", Text = "" })
	task.spawn(function()
		const ok, userId = pcall(function(): number
			return Players:GetUserIdFromNameAsync(name)
		end)
		if id ~= self.SearchId then
			return
		end
		if not ok or type(userId) ~= "number" or userId <= 0 then
			self.Lookup({ Kind = "Missing", Text = `No player named "{name}"` })
			return
		end
		if userId == Players.LocalPlayer.UserId then
			self.Lookup({ Kind = "Missing", Text = "That's you! Pick somebody else." })
			return
		end
		-- the exact spelling of the username
		local exact = name
		const nameOk, real = pcall(function(): string
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if nameOk and type(real) == "string" and real ~= "" then
			exact = real
		end
		if id ~= self.SearchId then
			return
		end
		const online = Players:GetPlayerByUserId(userId)
		self.Found({ {
			UserId = userId,
			Name = exact,
			DisplayName = if online then online.DisplayName else exact,
		} })
		self.Selected(userId)
		self.Lookup({ Kind = "None", Text = "" })
	end)
end

function GiftController:NameOf(userId: number): string
	for _, candidate in self:Candidates() do
		if candidate.UserId == userId then
			return candidate.DisplayName
		end
	end
	return "your friend"
end

-- Send: asks the server first (GiftResult Ok = may prompt).
function GiftController:Confirm()
	const key = Vide.untrack(self.Key)
	const gift = Content.Shop.Gifts.ByKey[key]
	const recipient = Vide.untrack(self.Selected)
	if gift == nil or recipient <= 0 or Vide.untrack(self.Busy) then
		return
	end
	if gift.ProductId <= 0 then
		self:Say("This gift is coming soon.", "Info")
		return
	end
	if recipient == Players.LocalPlayer.UserId then
		self:Say(REFUSED.Self, "Alert")
		return
	end
	self:Click()
	self.Recipients[key] = Vide.untrack(function()
		return self:NameOf(recipient)
	end)
	self.Busy(true)
	self.Waiting = key
	const sentAt = os.clock()
	self.SentAt = sentAt
	self.Libs.Net.GiftPrompt:fireServer({ Key = key, Recipient = recipient })
	task.delay(ANSWER_TIMEOUT, function()
		if self.Waiting == key and self.SentAt == sentAt then
			self.Waiting = ""
			self.Busy(false)
			self:Say(REFUSED.Busy, "Alert")
		end
	end)
end

function GiftController:Prompt(key: string)
	const gift = Content.Shop.Gifts.ByKey[key]
	if gift == nil or gift.ProductId <= 0 then
		self.Busy(false)
		return
	end
	const ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, gift.ProductId)
	end)
	if not ok then
		warn(`[GiftController] PromptProductPurchase failed: {err}`)
		self.Busy(false)
		self:Say("The purchase window could not open. Try again.", "Alert")
		return
	end
	-- Busy until PromptProductPurchaseFinished
	self:Close()
end

function GiftController:OnResult(result: { Ok: boolean, Reason: string, Key: string })
	const reason = result.Reason
	if reason == "Sent" then
		const name = self.Recipients[result.Key] or "your friend"
		self:Say(`Gift sent to {name}!`, "Good")
		return
	elseif reason == "Failed" then
		self:Say("Gift paid! It will reach them in a moment.", "Info")
		return
	end
	if self.Waiting ~= result.Key then
		return -- an answer to a request this client gave up on
	end
	self.Waiting = ""
	if result.Ok and reason == "Ok" then
		self:Prompt(result.Key)
		return
	end
	self.Busy(false)
	self:Say(REFUSED[reason] or "The gift could not be sent. Try again.", "Alert")
end

-- Mount -------------------------------------------------------------------------------------------------------------

function GiftController:Mount(playerGui: Instance)
	const unmount, gui = Vide.root(function()
		Backdrop.Hold(self.Shown)
		return Vide.create("ScreenGui")({
			Name = "GiftPicker",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = DISPLAY_ORDER,
			Enabled = self.Shown,
			-- frees the mouse of a first-person camera while the picker is open
			Vide.create("TextButton")({
				Name = "Modal",
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Text = "",
				Modal = self.Shown,
				Visible = self.Shown,
			}),
			GiftPicker({
				Visible = self.Shown,
				Title = function()
					return self:TitleOf(self.Key())
				end,
				Price = function()
					return self:PriceOf(self.Key())
				end,
				Available = function()
					const gift = Content.Shop.Gifts.ByKey[self.Key()]
					return gift ~= nil and gift.ProductId > 0
				end,
				Candidates = function()
					return self:Candidates()
				end,
				Selected = self.Selected,
				Lookup = self.Lookup,
				Busy = self.Busy,
				OnSelect = function(userId: number)
					self:Select(userId)
				end,
				OnSearch = function(name: string)
					self:Search(name)
				end,
				OnConfirm = function()
					self:Confirm()
				end,
				OnClose = function()
					self:Click()
					self:Close()
				end,
				Scale = self.Scale,
			}),
		})
	end)
	gui.Parent = playerGui
	self.Gui = gui
	-- the picker lives as long as the client; nothing unmounts it
	local _ = unmount
end

GiftController:OnInit(function(self)
	self:Setup()
	self.Libs.Net.GiftResult:onClient(function(result)
		self:OnResult(result)
	end)
end)

GiftController:OnStart(function(self)
	const me = Players.LocalPlayer
	Players.PlayerAdded:Connect(function()
		self:RefreshRoster()
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		self:RefreshRoster(player)
	end)
	GuiService.MenuOpened:Connect(function()
		self:Close()
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, _bought: boolean)
		if userId ~= me.UserId then
			return
		end
		for _, gift in Content.Shop.Gifts.List do
			if gift.ProductId > 0 and gift.ProductId == productId then
				self.Busy(false)
				return
			end
		end
	end)
	task.spawn(function()
		self:Mount(me:WaitForChild("PlayerGui"))
	end)
end)

return GiftController
