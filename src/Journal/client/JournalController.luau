--!strict
--[[
	JournalController (TASK-335, TASK-345 book -> tablet; owner request 2026-10-15, Provisional)

	The client of the Anomaly Tablet. The server (JournalService) owns the pages; here:
	  Pages    Vide source from the `Journal` packet (profile.Journal). New = a page that just unlocked: a HUD toast
	           (Content.Journal.Rules.ToastText, HudController:PushText "Good").
	  Fresh    (owner request 2026-10-17, Provisional) the unlocked pages whose gems were not claimed yet (Pages minus
	           Claimed, profile.JournalClaimed: saved, so it survives a rejoin). Each is "NEW!" on the tablet. A Fresh
	           page that stays on screen CLAIM_DELAY s while the tablet is open sends JournalClaim; the server pays
	           Rules.Reward gems and answers with Gained = that key: GemCollect plays over the tablet (gems fly into a
	           "+100" pill, coin per gem, buy chime at the end) and the page stops being Fresh.
	  Open     `JournalOpen` (the read_journal prompt on the tablet): the AnomalyTablet window in its own ScreenGui
	           ("AnomalyTablet", DisplayOrder 20), behind the window backdrop (Backdrop.Hold, TASK-311). It opens on the
	           newest unread page, else where it was left. Swipe / drag / wheel / dots live in the component; here, while
	           open: Left / Right arrow keys, LB / RB, LT / RT and D-pad left / right turn pages, gamepad B closes, the
	           selection lands on "Next"; a Modal button frees the mouse from the first-person lock.
	           Walking away from the tablet (Radius + AWAY studs) or a life state other than alive closes it.
	  Unseen   any Fresh page. While Unseen: a Mustard Highlight on the tablet Model (Rules.Model; the parent Model of
	           the read_journal anchor) pulsing, and the TabletBadge on its screen (where the "?" sticker was) shows a yellow "!"; else the badge shows a
	           green check. Only opening every new page (and its claim) clears it.
	Presentation only: the server decides pages and gems.
]]
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Backdrop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Backdrop)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local AnomalyTablet = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.AnomalyTablet)
local TabletBadge = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TabletBadge)
local GemCollect = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.GemCollect)

const rules = Content.Journal.Rules
const pageList = Content.Journal.List
const DISPLAY_ORDER = 20 -- with the other in-game windows (Settings), over the backdrop (5)
const ANCHOR_TAG = "Interactable"
const GLOW_NAME = "JournalGlow"
const GLOW_PERIOD = 0.9 -- s of one pulse
const AWAY = 6 -- studs past the prompt radius that close the tablet
const AWAY_CHECK = 0.5 -- s between two distance checks
const BADGE_CHECK = 1 -- s between two looks for the tablet (streaming, trailer rebuilt or moved)
const SCREEN_NAME = "Screen" -- the lit screen Part of the tablet Model (anomaly_tablet.luau)
const STICKER_TEXT = "?" -- the sticker the badge replaces
const CLAIM_DELAY = 0.6 -- s a new page stays on screen before its gems are claimed (the player sees it first)
const CLAIM_RETRY = 5 -- s before a claim with no answer may be sent again
const FIRST_CONTROL = "Next"
const TURN_PREV = "JournalPrev"
const TURN_NEXT = "JournalNext"
const CLOSE = "JournalClose"

type Spot = { AnchorPoint: Vector2, Position: UDim2, Size: UDim2, SizeConstraint: Enum.SizeConstraint }
-- the sticker's place in anomaly_tablet.luau, until the real one is read
const DEFAULT_SPOT: Spot = {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.66),
	Size = UDim2.fromScale(0.42, 0.42),
	SizeConstraint = Enum.SizeConstraint.RelativeXX,
}

const JournalController = Modux.Controller("JournalController", {
	Require = { "InputController", "HudController", "AudioController" },
	Priority = 450,
})

function JournalController:Setup()
	self.Pages = Vide.source({}) :: Vide.Source<{ [string]: boolean }>
	self.Fresh = Vide.source({}) :: Vide.Source<{ [string]: boolean }>
	self.Open = Vide.source(false) :: Vide.Source<boolean>
	self.Index = Vide.source(1) :: Vide.Source<number>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.Gui = nil :: ScreenGui?
	self.Unseen = Vide.source(false) :: Vide.Source<boolean>
	-- key -> os.clock() of a JournalClaim sent and not answered yet
	self.Pending = {} :: { [string]: number }
	self.ClaimSerial = 0 :: number
	-- the badge on the tablet screen: its SurfaceGui, whether the tablet is there, and where the "?" sticker sits
	self.BadgeGui = nil :: SurfaceGui?
	self.BadgeOn = Vide.source(false) :: Vide.Source<boolean>
	self.BadgeSpot = Vide.source(DEFAULT_SPOT) :: Vide.Source<Spot>
	self.GlowConnection = nil :: RBXScriptConnection?
	self.AwayThread = nil :: thread?
end

-- The read_journal anchor (Attachment or Part) in the Workspace, nil while the tablet is not placed.
function JournalController:Anchor(): Instance?
	for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
		if anchor:GetAttribute("PromptAction") == rules.Action and anchor:IsDescendantOf(workspace) then
			return anchor
		end
	end
	return nil
end

function JournalController:BookModel(): Instance?
	const anchor = self:Anchor()
	if anchor == nil then
		return nil
	end
	const model = anchor:FindFirstAncestor(rules.Model)
	return model or anchor:FindFirstAncestorWhichIsA("Model") or anchor.Parent
end

-- Glow --------------------------------------------------------------------------------------------------------------

function JournalController:StopGlow()
	if self.GlowConnection then
		self.GlowConnection:Disconnect()
		self.GlowConnection = nil
	end
	const model = self:BookModel()
	const glow = if model then model:FindFirstChild(GLOW_NAME) else nil
	if glow then
		glow:Destroy()
	end
end

function JournalController:StartGlow()
	if self.GlowConnection then
		return
	end
	self.GlowConnection = RunService.Heartbeat:Connect(function()
		if not Vide.untrack(self.Unseen) then
			self:StopGlow()
			return
		end
		const model = self:BookModel()
		if model == nil then
			return
		end
		local glow = model:FindFirstChild(GLOW_NAME) :: Highlight?
		if glow == nil then
			const made = Instance.new("Highlight")
			made.Name = GLOW_NAME
			made.FillColor = Theme.Color.Mustard
			made.OutlineColor = Theme.Color.Gold
			made.DepthMode = Enum.HighlightDepthMode.Occluded
			made.Parent = model
			glow = made
		end
		const wave = (math.sin(os.clock() * math.pi * 2 / GLOW_PERIOD) + 1) / 2
		const highlight = glow :: Highlight
		highlight.FillTransparency = 0.35 + 0.5 * wave
		highlight.OutlineTransparency = 0.6 * wave
	end)
end

-- Pages -------------------------------------------------------------------------------------------------------------

function JournalController:OnJournal(data: any)
	const pages: { [string]: boolean } = {}
	if type(data.Pages) == "table" then
		for key, on in data.Pages do
			if on == true and Content.Journal.ByKey[key] ~= nil then
				pages[key] = true
			end
		end
	end
	const fresh: { [string]: boolean } = {}
	for key in pages do
		if type(data.Claimed) ~= "table" or data.Claimed[key] ~= true then
			fresh[key] = true
		else
			self.Pending[key] = nil
		end
	end
	self.Pages(pages)
	self.Fresh(fresh)
	const unseen = next(fresh) ~= nil
	self.Unseen(unseen)
	if unseen then
		self:StartGlow()
	end
	const new = data.New
	if type(new) == "string" and pages[new] then
		self.Dependencies.HudController:PushText(rules.ToastText, "Good")
	end
	const gained = data.Gained
	if type(gained) == "string" then
		self:PlayCollect()
	end
	-- the page on screen may still be new (several new pages, or a claim that was dropped)
	self:ScheduleClaim()
end

-- Gems fly out of the tablet into a "+Reward" pill; coin on every landing, the buy chime at the end.
function JournalController:PlayCollect()
	const audio = self.Dependencies.AudioController
	GemCollect.Play({
		Amount = rules.Reward,
		OnLand = function(index: number, _count: number)
			if index % 2 == 1 then
				pcall(function()
					audio:Play("coin")
				end)
			end
		end,
		OnDone = function()
			pcall(function()
				audio:Play("buy")
			end)
		end,
	})
end

-- Claims the page on screen once it stayed there CLAIM_DELAY s with the tablet open (any turn restarts the wait).
function JournalController:ScheduleClaim()
	self.ClaimSerial += 1
	const serial = self.ClaimSerial
	if not Vide.untrack(self.Open) then
		return
	end
	const key = pageList[Vide.untrack(self.Index)].Key
	if not Vide.untrack(self.Fresh)[key] then
		return
	end
	task.delay(CLAIM_DELAY, function()
		if serial ~= self.ClaimSerial or not Vide.untrack(self.Open) then
			return
		end
		if pageList[Vide.untrack(self.Index)].Key ~= key or not Vide.untrack(self.Fresh)[key] then
			return
		end
		const sent = self.Pending[key]
		if sent ~= nil and os.clock() - sent < CLAIM_RETRY then
			return
		end
		self.Pending[key] = os.clock()
		self.Libs.Net.JournalClaim:fireServer(key)
	end)
end

-- Newest unread page in tablet order (the last one), nil when none.
function JournalController:FreshIndex(): number?
	const fresh = Vide.untrack(self.Fresh)
	local found: number? = nil
	for index, row in pageList do
		if fresh[row.Key] then
			found = index
		end
	end
	return found
end

function JournalController:Turn(delta: number)
	const index = math.clamp(Vide.untrack(self.Index) + delta, 1, #pageList)
	if index ~= Vide.untrack(self.Index) then
		self.Index(index)
		self:ScheduleClaim()
	end
end

-- Badge -------------------------------------------------------------------------------------------------------------

-- The "?" sticker on the tablet screen (tools/assetplace/anomaly_tablet.luau) and its SurfaceGui; nil while not placed.
function JournalController:Sticker(): (TextLabel?, SurfaceGui?)
	const model = self:BookModel()
	const screen = if model then model:FindFirstChild(SCREEN_NAME) else nil
	if screen == nil then
		return nil, nil
	end
	const gui = screen:FindFirstChildOfClass("SurfaceGui")
	if gui == nil then
		return nil, nil
	end
	for _, child in gui:GetDescendants() do
		if child:IsA("TextLabel") and child.Text == STICKER_TEXT then
			return child, gui
		end
	end
	return nil, gui
end

-- Follows the tablet: the badge SurfaceGui sits on the Screen part, over the "?" sticker (hidden on this client only),
-- same place and size. Rechecked every BADGE_CHECK s (streaming, trailer rebuilt).
function JournalController:WatchBadge()
	task.spawn(function()
		while true do
			const sticker, gui = self:Sticker()
			const surface = self.BadgeGui
			if surface then
				const screen = if gui then gui.Parent else nil
				if surface.Adornee ~= screen then
					surface.Adornee = screen :: any
				end
				if gui then
					surface.CanvasSize = gui.CanvasSize
					surface.Brightness = gui.Brightness
				end
			end
			if sticker then
				sticker.Visible = false
				self.BadgeSpot({
					AnchorPoint = sticker.AnchorPoint,
					Position = sticker.Position,
					Size = sticker.Size,
					SizeConstraint = sticker.SizeConstraint,
				})
			end
			self.BadgeOn(gui ~= nil)
			task.wait(BADGE_CHECK)
		end
	end)
end

function JournalController:MountBadge(playerGui: Instance)
	const spot = self.BadgeSpot
	const surface = Instance.new("SurfaceGui")
	surface.Name = "TabletBadge"
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = 0
	surface.ZOffset = 1
	surface.ResetOnSpawn = false
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	-- the cartoon kit layers by sibling order (face over lip); Global would draw the dark lip over the face
	surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Vide.root(function()
		const badge = TabletBadge({
			Name = "Seal",
			Alert = self.Unseen,
			Visible = function()
				return self.BadgeOn()
			end,
			AnchorPoint = Vide.untrack(spot).AnchorPoint,
			Position = Vide.untrack(spot).Position,
			Size = Vide.untrack(spot).Size,
			SizeConstraint = Vide.untrack(spot).SizeConstraint,
		})
		badge.Parent = surface
		-- the sticker geometry arrives with the first look at the tablet
		Vide.effect(function()
			const at = spot()
			badge.AnchorPoint = at.AnchorPoint
			badge.Position = at.Position
			badge.Size = at.Size
			badge.SizeConstraint = at.SizeConstraint
		end)
		return nil
	end)
	self.BadgeGui = surface
	surface.Parent = playerGui
end

-- Window ------------------------------------------------------------------------------------------------------------

function JournalController:SetOpen(open: boolean)
	if Vide.untrack(self.Open) == open then
		return
	end
	const input = self.Dependencies.InputController
	if open then
		const fresh = self:FreshIndex()
		if fresh then
			self.Index(fresh)
		end
		input:Bind({ Name = TURN_PREV, Key = Enum.KeyCode.Left, Keys = { Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonL2, Enum.KeyCode.DPadLeft } }).OnPress(function()
			self:Turn(-1)
		end)
		input:Bind({ Name = TURN_NEXT, Key = Enum.KeyCode.Right, Keys = { Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonR2, Enum.KeyCode.DPadRight } }).OnPress(function()
			self:Turn(1)
		end)
		input:Bind({ Name = CLOSE, Key = Enum.KeyCode.ButtonB }).OnPress(function()
			self:SetOpen(false)
		end)
		self:WatchAway()
	else
		input:Unbind(TURN_PREV)
		input:Unbind(TURN_NEXT)
		input:Unbind(CLOSE)
		const thread = self.AwayThread
		self.AwayThread = nil
		if thread and coroutine.status(thread) == "suspended" then
			task.cancel(thread)
		end
	end
	self.Open(open)
	self:Select(open)
	self:ScheduleClaim()
end

-- Closes the tablet when the body walks away from it or stops being alive.
function JournalController:WatchAway()
	const action = Content.Actions.ByKey[rules.Action]
	const limit = (if action then action.Radius else 6) + AWAY
	self.AwayThread = task.spawn(function()
		while Vide.untrack(self.Open) do
			task.wait(AWAY_CHECK)
			const character = Players.LocalPlayer.Character
			const root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			const anchor = self:Anchor()
			local away = root == nil or humanoid == nil or humanoid.Health <= 0
			if not away and root and anchor then
				const at = if anchor:IsA("Attachment")
					then anchor.WorldPosition
					elseif anchor:IsA("BasePart") then anchor.Position
					else root.Position
				away = (root.Position - at).Magnitude > limit
			end
			if away then
				self.AwayThread = nil
				self:SetOpen(false)
				return
			end
		end
	end)
end

-- Gamepad: the selection goes to the Next arrow on open, and leaves the window on close.
function JournalController:Select(open: boolean)
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
			if child.Name == FIRST_CONTROL and child:IsA("GuiButton") and child.Visible then
				GuiService.SelectedObject = child
				return
			end
		end
	end)
end

function JournalController:WatchViewport()
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

function JournalController:Mount(playerGui: Instance)
	const device = self.Dependencies.InputController.Device
	const _, gui = Vide.root(function()
		-- blur + veil behind the window (TASK-311)
		Backdrop.Hold(self.Open)
		return Vide.create("ScreenGui")({
			Name = "AnomalyTablet",
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = DISPLAY_ORDER,
			Enabled = self.Open,

			-- frees the mouse from the first-person lock while the tablet is open
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

			AnomalyTablet({
				Visible = self.Open,
				Pages = self.Pages,
				Fresh = self.Fresh,
				Index = self.Index,
				Scale = self.Scale,
				Hint = function()
					const kind = device()
					return if kind == "Gamepad"
						then "LB / RB or the D-pad to turn pages  ·  B to close"
						elseif kind == "KeyboardMouse" then "Drag, scroll or use the arrow keys to turn pages"
						else "Swipe to turn pages"
				end,
				OnTurn = function(delta: number)
					self:Turn(delta)
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

JournalController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Journal:onClient(function(data)
		self:OnJournal(data)
	end)
	self.Libs.Net.JournalOpen:onClient(function()
		self:SetOpen(true)
	end)
end)

JournalController:OnStart(function(self)
	self:WatchViewport()
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		self:Mount(playerGui)
		self:MountBadge(playerGui)
		self:WatchBadge()
	end)
end)

return JournalController
