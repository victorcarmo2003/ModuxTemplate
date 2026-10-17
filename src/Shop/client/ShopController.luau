--!strict
--[[
	ShopController (TASK-290; owner request 2026-10-14, Provisional)

	The in-run Robux shop of the HUD cart (Content.Shop.Utilities). Game servers only: the lobby has its own shop on B
	(LobbyController, gems and classes).
	  - Window: ShopPanel in its own ScreenGui ("Shop"). Toggled by the HUD cart (HudController), by B / gamepad DPadRight
	    and by the nudge. Opening it closes the settings window and the other way round. While open, a Modal button frees
	    the mouse from the first-person lock.
	  - Buy: a utility with a Target opens the pick view (mates / ingredients), sends ShopPick, then prompts. ProductId 0
	    (not created on the Creator Hub yet) shows "Coming soon" instead of a prompt. Night-only cards are off by day;
	    Scare is off with nobody else in the server. Prices: GetProductInfo when the id exists, else the suggested Robux.
	  - Grants (ShopGrant): a short note on the HUD for the buyer; the scared mate sees the cartoon jumpscare of the
	    anomalies (Effects/Kit/Jumpscare, called through its API only) and "Boo! from {name}"; Radar outlines the customer
	    anomalies of the Anomalies set for its seconds and names each new one.
	  - Nudge: every NUDGE_EVERY s (first after NUDGE_FIRST s), with someone else in the server, outside the prep mode,
	    cutscenes and cinematics and with the shop closed, the scare note for NUDGE_TIME s and the cart glows. Its words
	    follow the current input (NudgeLine, reactive): "Press B to scare your friends" (keyboard), the same with the pad
	    button image (controller), "Tap here to scare your friends" (touch). Clicking or tapping it opens the shop and
	    the Scare card blinks for FLASH_TIME s.
	  - Controller: opening a window with the gamepad puts the selection on its first button (GuiService), closing it
	    lets go of a selection inside it.
	  - Offers (TASK-363; owner request 2026-10-17, Provisional): `Offer` puts a contextual offer of OfferController in
	    the same note (product icon + text + price, NudgeIcon). Clicking it runs the offer's click (the prompt of that
	    product with its target picked, or the shop with its card flashing: `PromptOffer` / `ShowCard`); any other note
	    (receipts, the scare nudge) drops the offer. The scare nudge asks `NudgeGate` first and reports `NudgeShown`, so
	    OfferController keeps it inside the offers budget.
	    Key (owner request 2026-10-17): while an offer shows, G (keyboard) / ButtonY (controller) does the same as the
	    click; the note ends with "[G]" or the Y button image (NudgePad). Not E / ButtonX: those belong to the map's
	    ProximityPrompts. ButtonY is also used by the prep mode, the faint screen and the security cameras, where an
	    offer never shows (OfferController / CanOffer); the binding exists only while the offer is on the note.
]]
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local ShopContent = require(ReplicatedStorage.shared.Content.Shop)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local Backdrop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Backdrop)
local ShopPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ShopPanel)
local Jumpscare = require(StarterPlayer.StarterPlayerScripts.client.Anomaly.AnomalyController.Effects.Kit.Jumpscare)

type Utility = ShopContent.Utility

const TOGGLE_ACTION = "ShopToggle"
const TOGGLE_KEY = Enum.KeyCode.B
const TOGGLE_PAD = Enum.KeyCode.DPadRight -- free in game servers (the lobby uses it for its squad panel)
const OFFER_ACTION = "ShopOfferBuy"
const OFFER_KEY = Enum.KeyCode.G
const OFFER_PAD = Enum.KeyCode.ButtonY
const DISPLAY_ORDER = 20 -- same layer as the settings window
const SCARE_KEY = "util_scare"
const SCARE_NOTE = "<scare>" -- Nudge value of the scare note: NudgeLine picks the words per device
const FIRST_BUTTON = "Buy" -- the selection lands on the first card's buy button
const NUDGE_FIRST = 120 -- s after the HUD starts
const NUDGE_EVERY = 240 -- s between two nudges
const NUDGE_TIME = 1.2 -- s on screen (owner: ~1 s)
const NOTE_TIME = 2.5 -- s of a receipt note
const FLASH_TIME = 1 -- s the Scare card blinks
const FLASH_STEP = 0.15 -- s per blink
const STATUS_TIME = 3 -- s of a footer line
const TICK = 0.5 -- s between radar refreshes
const RADAR_COLOR = Theme.Color.Mustard
const RADAR_NAME = "ShopRadar"
const LIVE_PHASES = { Signal = true, Active = true }

export type AnomalyRecord = { Anomaly: string, Phase: string, StartedAt: number, Step: number, Anchor: number }

-- Theme.Tone of each ingredient on the refill picker (owner 2026-10-16: picture + theme colour)
const INGREDIENT_TONES: { [string]: string } = {
	bun = "Mustard",
	sausage = "Ketchup",
	ketchup = "Ketchup",
	mustard = "Mustard",
	cheese = "Mustard",
	bacon = "Ketchup",
	potato_sticks = "Mustard",
	cream_cheese = "White",
	coffee = "Teal",
}

const ShopController = Modux.Controller("ShopController", {
	Require = {
		"PlaceController",
		"InputController",
		"AudioController",
		"RoundController",
		"SettingsController",
		"CameraController",
		"CustomerController",
	},
	Priority = 550,
})

function ShopController:Setup()
	self.Enabled = false :: boolean
	self.Open = Vide.source(false) :: Vide.Source<boolean>
	self.Flash = Vide.source("") :: Vide.Source<string>
	self.Picking = Vide.source(false :: ShopPanel.Pick | false) :: Vide.Source<ShopPanel.Pick | false>
	self.PickKey = "" :: string
	self.Status = Vide.source("") :: Vide.Source<string>
	self.Nudge = Vide.source("") :: Vide.Source<string>
	-- Icons name left of the note (offers); "" = none
	self.NudgeIcon = Vide.source("") :: Vide.Source<string>
	-- click of the offer on the note (nil = the note is not an offer)
	self.OfferClick = nil :: (() -> ())?
	-- the note is an offer (adds the key hint); controller button image of the offer key
	self.OfferHint = Vide.source(false) :: Vide.Source<boolean>
	self.NudgePad = Vide.source("") :: Vide.Source<string>
	self.OfferPadImage = "" :: string
	-- OfferController hooks (nil = no budget): may the scare nudge show now; it just showed
	self.NudgeGate = nil :: (() -> boolean)?
	self.NudgeShown = nil :: (() -> ())?
	self.Glow = Vide.source(false) :: Vide.Source<boolean>
	-- other players in the server (Scare needs one)
	self.Others = Vide.source(0) :: Vide.Source<number>
	-- real prices (GetProductInfo) by key
	self.Prices = Vide.source({} :: { [string]: number }) :: Vide.Source<{ [string]: number }>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.Gui = nil :: ScreenGui?
	self.Tokens = { Status = 0, Nudge = 0, Flash = 0 } :: { [string]: number }
	self.NextNudge = (os.clock() + NUDGE_FIRST) :: number
	-- radar: os.clock() deadline, live anomaly records by id, names already announced, outlines by record id
	self.RadarUntil = 0 :: number
	self.Records = {} :: { [number]: AnomalyRecord }
	self.Announced = {} :: { [number]: boolean }
	self.Outlines = {} :: { [number]: Highlight }
end

-- Shows `text` in a source for `time` s (a newer call wins).
function ShopController:Flashy(slot: string, target: Vide.Source<string>, text: string, time: number)
	self.Tokens[slot] += 1
	const token = self.Tokens[slot]
	target(text)
	task.delay(time, function()
		if self.Tokens[slot] == token then
			target("")
		end
	end)
end

function ShopController:Say(text: string)
	self:Flashy("Status", self.Status, text, STATUS_TIME)
end

function ShopController:Note(text: string, time: number?)
	self:EndOffer()
	self.NudgeIcon("")
	self:Flashy("Nudge", self.Nudge, text, time or NOTE_TIME)
end

-- A contextual offer on the note (OfferController): `click` runs when the player clicks it while it shows. Returns the
-- note token: OfferController compares it later to know whether the offer was clicked, expired or replaced.
function ShopController:Offer(text: string, icon: string, time: number, click: () -> ()): number
	self:Flashy("Nudge", self.Nudge, text, time)
	self.NudgeIcon(icon)
	self.OfferClick = click
	self.OfferHint(true)
	self.NudgePad(self.OfferPadImage)
	self.Glow(true)
	self.Dependencies.InputController
		:Bind({
			Name = OFFER_ACTION,
			Key = OFFER_KEY,
			Keys = { OFFER_PAD },
		})
		.OnPress(function()
			if self.OfferClick ~= nil and Vide.untrack(self.Nudge) ~= "" then
				self:OnNudge()
			end
		end)
	const token = self.Tokens.Nudge
	task.delay(math.min(time, NUDGE_TIME * 2), function()
		if self.Tokens.Nudge == token then
			self.Glow(false)
		end
	end)
	task.delay(time, function()
		if self.Tokens.Nudge == token then
			self:EndOffer()
		end
	end)
	return token
end

-- The note stops being an offer: no click, no key, no hint.
function ShopController:EndOffer()
	self.OfferClick = nil
	self.OfferHint(false)
	self.NudgePad("")
	self.Dependencies.InputController:Unbind(OFFER_ACTION)
end

-- Token of the note on screen now (Offer's return value while the same offer still shows)
function ShopController:NoteToken(): number
	return self.Tokens.Nudge
end

-- Nothing on the note and nothing that hides it: an offer may show.
function ShopController:CanOffer(): boolean
	if not self.Enabled or Vide.untrack(self.Open) or Cinematic.Active() then
		return false
	end
	if Vide.untrack(self.Dependencies.SettingsController.Open) then
		return false
	end
	-- only in the normal first person view (not prep, cutscene, spectate, the security cameras)
	return Vide.untrack(self.Dependencies.CameraController.Mode) == "FirstPerson" and Vide.untrack(self.Nudge) == ""
end

-- The click of an offer: picks the target (Ingredient index / mate UserId) and opens the Roblox prompt of `key`.
function ShopController:PromptOffer(key: string, target: number?)
	const utility = Content.Shop.Utilities.ByKey[key]
	if utility == nil then
		return
	end
	if utility.ProductId <= 0 then
		self:Note("Coming soon: this item is not on sale yet.")
		return
	end
	if target ~= nil and utility.Target ~= nil then
		self.Libs.Net.ShopPick:fireServer({ Product = utility.Key, Target = target })
	end
	const ok, problem = pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, utility.ProductId)
	end)
	if not ok then
		warn(`[ShopController] PromptProductPurchase {utility.Key}: {problem}`)
		self:Note("The shop is busy. Try again in a moment.")
	end
end

-- The other click of an offer (A/B of Q-293): opens the shop with the card of `key` flashing.
function ShopController:ShowCard(key: string)
	self:SetOpen(true)
	self:FlashCard(key)
end

function ShopController:SetOpen(open: boolean)
	if Vide.untrack(self.Open) == open then
		return
	end
	self.Open(open)
	self.Libs.Net.MetricUi:fireServer({ Event = if open then "shop_open" else "shop_close", Key = nil }) -- analytics
	if open then
		self.Dependencies.SettingsController:SetOpen(false)
		self.Glow(false)
	else
		self.Picking(false)
	end
	self:Select(open)
end

-- Gamepad: the selection goes to the first buy button on open, and leaves the window on close.
function ShopController:Select(open: boolean)
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
			if child.Name == FIRST_BUTTON and child:IsA("GuiButton") and child.Visible then
				GuiService.SelectedObject = child
				return
			end
		end
	end)
end

-- Words of the HUD note (reactive): the scare note follows the current input; other notes as they are.
function ShopController:NudgeLine(): string
	const raw = self.Nudge()
	if raw ~= "" and self.OfferHint() then
		const device = self.Dependencies.InputController.Device()
		if device == "Touch" then
			return raw
		elseif device == "Gamepad" then
			return if self.OfferPadImage ~= "" then `{raw} {"{pad}"}` else `{raw} [Y]`
		end
		return `{raw} [G]`
	end
	if raw ~= SCARE_NOTE then
		return raw
	end
	const device = self.Dependencies.InputController.Device()
	if device == "Touch" then
		return "Tap here to scare your friends"
	elseif device == "Gamepad" then
		return "Press {pad} to scare your friends"
	end
	return "Press B to scare your friends"
end

function ShopController:Toggle()
	self:SetOpen(not Vide.untrack(self.Open))
end

-- The Scare card blinks for FLASH_TIME s.
function ShopController:FlashScare()
	self:FlashCard(SCARE_KEY)
end

-- A card blinks for FLASH_TIME s.
function ShopController:FlashCard(key: string)
	self.Tokens.Flash += 1
	const token = self.Tokens.Flash
	task.spawn(function()
		const stop = os.clock() + FLASH_TIME
		local on = true
		while os.clock() < stop and self.Tokens.Flash == token do
			self.Flash(if on then key else "")
			on = not on
			task.wait(FLASH_STEP)
		end
		if self.Tokens.Flash == token then
			self.Flash("")
		end
	end)
end

function ShopController:OnNudge()
	const click = self.OfferClick
	if click ~= nil then
		self:EndOffer()
		self.Tokens.Nudge += 1
		self.Nudge("")
		self.NudgeIcon("")
		click()
		return
	end
	self:SetOpen(true)
	self:FlashScare()
end

function ShopController:PriceOf(utility: Utility): string
	const real = self.Prices()[utility.Key]
	return `R$ {real or utility.Robux}`
end

-- Cards of the panel (reactive: night, mates, prices).
function ShopController:Cards(): { ShopPanel.Card }
	const night = self.Dependencies.RoundController.IsNight()
	const others = self.Others()
	const cards: { ShopPanel.Card } = {}
	for _, utility in Content.Shop.Utilities.List do
		local note = ""
		if utility.Night and not night then
			note = "Night only"
		elseif utility.Target == "Mate" and others == 0 then
			note = "No crew here"
		end
		table.insert(cards, {
			Key = utility.Key,
			Name = utility.Name,
			Text = utility.Text,
			Icon = utility.Icon,
			Price = self:PriceOf(utility),
			Enabled = note == "",
			Note = note,
			Category = utility.Category,
			Tone = utility.Tone,
		})
	end
	return cards
end

function ShopController:Prompt(utility: Utility)
	if utility.ProductId <= 0 then
		self:Say("Coming soon: this item is not on sale yet.")
		return
	end
	self.Libs.Net.MetricUi:fireServer({ Event = "product_prompt", Key = utility.Key }) -- analytics
	const ok, problem = pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, utility.ProductId)
	end)
	if not ok then
		warn(`[ShopController] PromptProductPurchase {utility.Key}: {problem}`)
		self:Say("The shop is busy. Try again in a moment.")
	end
end

function ShopController:Buy(key: string)
	const utility = Content.Shop.Utilities.ByKey[key]
	if utility == nil then
		return
	end
	if utility.Target == "Mate" then
		const options: { ShopPanel.Option } = {}
		for _, other in Players:GetPlayers() do
			if other ~= Players.LocalPlayer then
				table.insert(options, { Id = other.UserId, Text = other.DisplayName })
			end
		end
		self.PickKey = key
		self.Picking({ Title = "Who do you want to scare?", Options = options })
		return
	elseif utility.Target == "Ingredient" then
		const options: { ShopPanel.Option } = {}
		for index, ingredient in Content.Ingredients.List do
			table.insert(options, {
				Id = index,
				Text = ingredient.Name,
				Icon = `Ingredient/{ingredient.Key}`,
				Tone = INGREDIENT_TONES[ingredient.Key] or "Cream",
			})
		end
		self.PickKey = key
		self.Picking({ Title = "Which one do you want to refill?", Options = options })
		return
	end
	self:Prompt(utility)
end

function ShopController:Pick(id: number)
	const utility = Content.Shop.Utilities.ByKey[self.PickKey]
	self.Picking(false)
	if utility == nil then
		return
	end
	self.Libs.Net.ShopPick:fireServer({ Product = utility.Key, Target = id })
	self:Prompt(utility)
end

-- Jumpscare of the anomalies kit, shown on this screen (its Show only reads ctx.Play).
function ShopController:Scare()
	const audio = self.Dependencies.AudioController
	const ctx = {
		Play = function(key: string, at: any, scare: boolean?): Sound?
			return audio:Play(key, at, if scare then { Scare = true } else nil)
		end,
	}
	task.spawn(Jumpscare.Show, ctx :: any)
end

local function nameOf(userId: number): string
	const player = Players:GetPlayerByUserId(userId)
	return if player then player.DisplayName else "a friend"
end

function ShopController:OnGrant(data: { Product: string, Value: number, From: number })
	const utility = Content.Shop.Utilities.ByKey[data.Product]
	if utility == nil then
		return
	end
	const kind = utility.Kind
	if kind == "Scare" then
		if data.Value == 1 then
			-- I am the one scared (From = the buyer)
			self:Scare()
			self:Note(`Boo! From {nameOf(data.From)}`)
			return
		end
		self:Note(if data.From ~= 0 then `You scared {nameOf(data.From)}!` else "Nobody to scare...")
	elseif kind == "Radar" then
		self.RadarUntil = os.clock() + data.Value
		self.Announced = {}
		self:Note(`Anomaly Radar on for {data.Value} s`)
		self:RefreshRadar()
	elseif kind == "Cash" then
		self:Note(`+${data.Value} for the crew!`)
	elseif kind == "Restock" then
		const ingredient = Content.Ingredients.List[data.Value]
		self:Note(if ingredient then `{ingredient.Name} refilled!` else "Everything is already full")
	elseif kind == "Pantry" then
		self:Note("Pantry full!")
	elseif kind == "Coffee" then
		self:Note(if data.Value == 1 then "Sanity back to full!" else "A hot coffee for later")
	elseif kind == "Revive" then
		self:Note("Revive Kit saved")
	elseif kind == "Kit" then
		self.RadarUntil = os.clock() + data.Value
		self.Announced = {}
		self:Note("Night Kit ready!")
		self:RefreshRadar()
	end
end

-- Radar ----------------------------------------------------------------------------------------------------------------

function ShopController:ClearOutline(id: number)
	const outline = self.Outlines[id]
	if outline then
		outline:Destroy()
		self.Outlines[id] = nil
	end
end

function ShopController:RefreshRadar()
	const on = os.clock() < self.RadarUntil
	const models = self.Dependencies.CustomerController.Models :: { [number]: Model }
	for id, record in self.Records do
		const live = on and LIVE_PHASES[record.Phase] == true
		if not live then
			self:ClearOutline(id)
			continue
		end
		if not self.Announced[id] then
			self.Announced[id] = true
			const row = Content.Anomalies.ByKey[record.Anomaly]
			self:Note(`Radar: {if row then row.Name else "something is off"}`)
		end
		const model = if record.Anchor > 0 then models[record.Anchor] else nil
		const outline = self.Outlines[id]
		if model == nil then
			self:ClearOutline(id)
		elseif outline == nil or outline.Adornee ~= model then
			self:ClearOutline(id)
			const made = Instance.new("Highlight")
			made.Name = RADAR_NAME
			made.FillTransparency = 1
			made.OutlineColor = RADAR_COLOR
			made.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			made.Adornee = model
			made.Parent = model
			self.Outlines[id] = made
		end
	end
	for id in self.Outlines do
		if self.Records[id] == nil then
			self:ClearOutline(id)
		end
	end
end

function ShopController:WatchAnomalies()
	const set = self.Libs.Net.Anomalies
	set:onAdded(function(id: number, record: any)
		self.Records[id] = record :: AnomalyRecord
	end)
	set:onChanged(function(id: number, record: any)
		self.Records[id] = record :: AnomalyRecord
	end)
	set:onRemoved(function(id: number)
		self.Records[id] = nil
		self.Announced[id] = nil
		self:ClearOutline(id)
	end)
end

-- Nudge ----------------------------------------------------------------------------------------------------------------

function ShopController:CanNudge(): boolean
	if Vide.untrack(self.Open) or Vide.untrack(self.Others) == 0 or Cinematic.Active() then
		return false
	end
	const mode = Vide.untrack(self.Dependencies.CameraController.Mode)
	return mode ~= "Prep" and mode ~= "Cutscene" and Vide.untrack(self.Nudge) == ""
end

function ShopController:StepNudge()
	const now = os.clock()
	if now < self.NextNudge then
		return
	end
	if not self:CanNudge() then
		return
	end
	const gate = self.NudgeGate
	if gate ~= nil and not gate() then
		return
	end
	self.NextNudge = now + NUDGE_EVERY
	self:Note(SCARE_NOTE, NUDGE_TIME)
	if self.NudgeShown ~= nil then
		self.NudgeShown()
	end
	self.Glow(true)
	task.delay(NUDGE_TIME, function()
		self.Glow(false)
	end)
end

-- Mount ----------------------------------------------------------------------------------------------------------------

function ShopController:CountOthers()
	self.Others(math.max(#Players:GetPlayers() - 1, 0))
end

function ShopController:LoadPadImage()
	const ok, image = pcall(function()
		return UserInputService:GetImageForKeyCode(OFFER_PAD)
	end)
	self.OfferPadImage = if ok and type(image) == "string" then image else ""
end

function ShopController:LoadPrices()
	for _, utility in Content.Shop.Utilities.List do
		if utility.ProductId <= 0 then
			continue
		end
		task.spawn(function()
			const ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(utility.ProductId, Enum.InfoType.Product)
			end)
			const price = if ok and type(info) == "table" then (info :: any).PriceInRobux else nil
			if type(price) == "number" then
				const prices = table.clone(Vide.untrack(self.Prices))
				prices[utility.Key] = price
				self.Prices(prices)
			end
		end)
	end
end

function ShopController:WatchViewport()
	local connection: RBXScriptConnection? = nil
	local function bind()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		const camera = workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self.Scale(Theme.ScaleOf(camera.ViewportSize))
			end)
			self.Scale(Theme.ScaleOf(camera.ViewportSize))
		end
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
	bind()
end

function ShopController:Mount(playerGui: Instance)
	const settings = self.Dependencies.SettingsController
	const _, gui = Vide.root(function()
		-- blur + veil behind the window (TASK-311)
		Backdrop.Hold(self.Open)
		-- the settings window and the shop never share the screen
		Vide.effect(function()
			if settings.Open() then
				Vide.untrack(function()
					self:SetOpen(false)
					return nil
				end)
			end
		end)

		return Vide.create("ScreenGui")({
			Name = "Shop",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = DISPLAY_ORDER,
			Enabled = function()
				return not Cinematic.Active()
			end,

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

			ShopPanel({
				Visible = self.Open,
				Items = function()
					return self:Cards()
				end,
				Categories = Content.Shop.Categories,
				Flash = self.Flash,
				Picking = self.Picking,
				Status = self.Status,
				Scale = self.Scale,
				OnBuy = function(key: string)
					self:Buy(key)
				end,
				OnPick = function(id: number)
					self:Pick(id)
				end,
				OnBack = function()
					self.Picking(false)
				end,
				OnClose = function()
					self:SetOpen(false)
				end,
			}),
		})
	end)
	self.Gui = gui
	gui.Parent = playerGui
end

ShopController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.ShopGrant:onClient(function(data)
		self:OnGrant(data)
	end)
end)

ShopController:OnStart(function(self)
	if self.Dependencies.PlaceController:Is("Lobby") then
		return
	end
	self.Enabled = true
	self:WatchAnomalies()
	self:WatchViewport()
	self:LoadPrices()
	self:LoadPadImage()
	self:CountOthers()
	Players.PlayerAdded:Connect(function()
		self:CountOthers()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			self:CountOthers()
		end)
	end)

	self.Dependencies.InputController
		:Bind({
			Name = TOGGLE_ACTION,
			Key = TOGGLE_KEY,
			Keys = { TOGGLE_PAD },
		})
		.OnPress(function()
			self:Toggle()
		end)

	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

ShopController:OnTick(function(self)
	if not self.Enabled then
		return
	end
	self:RefreshRadar()
	self:StepNudge()
end, TICK)

return ShopController
