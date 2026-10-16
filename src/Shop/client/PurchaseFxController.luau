--!strict
--[[
	PurchaseFxController (owner request 2026-10-16, Provisional): a clear "it worked!" when a Robux purchase goes
	through, in the lobby and in the run. Game Pass (classes) and Developer Product (gems, utilities, cash) alike:
	  - a burst of cartoon confetti over the whole screen (house palette, never alert red), falling and spinning;
	  - a pop-in banner with the item name ("Cat Crew!", "Handful of Gems!") that fades out;
	  - the buy chime + coin sounds.
	Local only, from MarketplaceService's own Prompt*PurchaseFinished on this client (isPurchased = true). The grant
	itself and its toast stay the server's (ShopService / ShopUtilityService); this is only the celebration.
	Reduced motion (Motion.Reduced): no confetti, the banner only fades.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)

const PIECES = 90 -- confetti pieces per burst
const FALL = { 1.6, 2.8 } -- s each piece takes to fall
const SIZE = { 8, 16 } -- px
const SPREAD = 0.15 -- s over which the pieces are launched
const BANNER_HOLD = 1.6 -- s the banner stays before fading
const DISPLAY_ORDER = 60
const COLORS = {
	Color3.fromHex("#F6C12B"), -- Mustard
	Color3.fromHex("#3FA7B5"), -- Teal
	Color3.fromHex("#A98BD6"), -- Lilac
	Color3.fromHex("#6FCF97"), -- Mint
	Color3.fromHex("#F29B6B"), -- Apricot
	Color3.fromHex("#5BA8F0"), -- Sky
	Color3.fromHex("#E58BC0"), -- Pink
	Color3.fromHex("#FFF1D6"), -- Cream
}
const SOUNDS = { "buy", "coin" }

const PurchaseFxController = Modux.Controller("PurchaseFxController", {
	Require = { "AudioController" },
	Priority = 40,
})

function PurchaseFxController:Setup()
	-- ProductId / PassId -> shown name
	self.Names = {} :: { [number]: string }
	for _, pack in Content.Shop.GemPacks.List do
		self.Names[pack.ProductId] = pack.Name
	end
	for _, utility in Content.Shop.Utilities.List do
		self.Names[utility.ProductId] = utility.Name
	end
	for _, pass in Content.Shop.GamePasses.List do
		self.Names[pass.PassId] = pass.Name
	end
end

local function between(rng: Random, range: { number }): number
	return range[1] + (range[2] - range[1]) * rng:NextNumber()
end

local function confetti(gui: ScreenGui)
	const rng = Random.new()
	const viewport = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
	for index = 1, PIECES do
		const size = math.floor(between(rng, SIZE))
		const piece = Instance.new("Frame")
		piece.Name = "Confetti"
		piece.BorderSizePixel = 0
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Size = UDim2.fromOffset(size, math.floor(size * 0.55))
		piece.BackgroundColor3 = COLORS[rng:NextInteger(1, #COLORS)]
		const startX = rng:NextNumber() * viewport.X
		piece.Position = UDim2.fromOffset(startX, -20 - rng:NextNumber() * 80)
		piece.Rotation = rng:NextNumber() * 360
		if rng:NextNumber() < 0.35 then
			const corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = piece
		end
		piece.Parent = gui
		const fall = between(rng, FALL)
		const drift = (rng:NextNumber() - 0.5) * 220
		task.delay(index / PIECES * SPREAD, function()
			TweenService:Create(piece, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(startX + drift, viewport.Y + 40),
				Rotation = piece.Rotation + (rng:NextNumber() - 0.5) * 900,
			}):Play()
			TweenService:Create(piece, TweenInfo.new(fall * 0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, fall * 0.6), {
				BackgroundTransparency = 1,
			}):Play()
		end)
	end
end

local function banner(gui: ScreenGui, text: string, reduced: boolean)
	const label = Instance.new("TextLabel")
	label.Name = "Banner"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.32)
	label.Size = UDim2.fromScale(0.6, 0.12)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font.Title
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.fromHex("#FFF1D6")
	label.TextStrokeColor3 = Color3.fromHex("#2B2233")
	label.TextStrokeTransparency = 0
	label.TextTransparency = 1
	label.Parent = gui
	const scale = Instance.new("UIScale")
	scale.Scale = if reduced then 1 else 0.4
	scale.Parent = label
	TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	if not reduced then
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	task.delay(BANNER_HOLD, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

-- The celebration for one finished purchase of `id` (ProductId or PassId)
function PurchaseFxController:Celebrate(id: number)
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	const reduced = Motion.Reduced()
	const gui = Instance.new("ScreenGui")
	gui.Name = "PurchaseFx"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = DISPLAY_ORDER
	gui.Parent = playerGui
	const name = self.Names[id]
	banner(gui, if name ~= nil then `{name}!` else "Thank you!", reduced)
	if not reduced then
		confetti(gui)
	end
	for _, key in SOUNDS do
		pcall(function()
			self.Dependencies.AudioController:Play(key)
		end)
	end
	task.delay(FALL[2] + SPREAD + 0.5, function()
		gui:Destroy()
	end)
end

PurchaseFxController:OnInit(function(self)
	self:Setup()
	const me = Players.LocalPlayer
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, bought: boolean)
		if bought and userId == me.UserId then
			self:Celebrate(productId)
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, bought: boolean)
		if bought and player == me then
			self:Celebrate(passId)
		end
	end)
end)

return PurchaseFxController
