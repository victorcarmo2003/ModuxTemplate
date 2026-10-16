--!strict
--[[
	JournalController (TASK-335, TASK-345 book -> tablet; owner request 2026-10-15, Provisional)

	The client of the Anomaly Tablet. The server (JournalService) owns the pages; here:
	  Pages    Vide source from the `Journal` packet (profile.Journal). New = a page that just unlocked: a HUD toast
	           (Content.Journal.Rules.ToastText, HudController:PushText "Good"), the page is marked "NEW!" until the
	           tablet is closed with it on screen, and the tablet in the trailer glows for Rules.Blink s (or until opened).
	  Open     `JournalOpen` (the read_journal prompt on the tablet): the AnomalyTablet window in its own ScreenGui
	           ("AnomalyTablet", DisplayOrder 20), behind the window backdrop (Backdrop.Hold, TASK-311). It opens on the
	           newest unread page, else where it was left. Swipe / drag / wheel / dots live in the component; here, while
	           open: Left / Right arrow keys, LB / RB, LT / RT and D-pad left / right turn pages, gamepad B closes, the
	           selection lands on "Next"; a Modal button frees the mouse from the first-person lock.
	           Walking away from the tablet (Radius + AWAY studs) or a life state other than alive closes it.
	  Glow     a Mustard Highlight on the tablet Model (Rules.Model; the parent Model of the read_journal anchor) pulsing.
	Presentation only: nothing here changes a page.
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

const rules = Content.Journal.Rules
const pageList = Content.Journal.List
const DISPLAY_ORDER = 20 -- with the other in-game windows (Settings), over the backdrop (5)
const ANCHOR_TAG = "Interactable"
const GLOW_NAME = "JournalGlow"
const GLOW_PERIOD = 0.9 -- s of one pulse
const AWAY = 6 -- studs past the prompt radius that close the tablet
const AWAY_CHECK = 0.5 -- s between two distance checks
const FIRST_CONTROL = "Next"
const TURN_PREV = "JournalPrev"
const TURN_NEXT = "JournalNext"
const CLOSE = "JournalClose"

const JournalController = Modux.Controller("JournalController", {
	Require = { "InputController", "HudController" },
	Priority = 450,
})

function JournalController:Setup()
	self.Pages = Vide.source({}) :: Vide.Source<{ [string]: boolean }>
	self.Fresh = Vide.source({}) :: Vide.Source<{ [string]: boolean }>
	self.Open = Vide.source(false) :: Vide.Source<boolean>
	self.Index = Vide.source(1) :: Vide.Source<number>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.Gui = nil :: ScreenGui?
	self.GlowUntil = 0 :: number
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
	self.GlowUntil = 0
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
	self.GlowUntil = os.clock() + rules.Blink
	if self.GlowConnection then
		return
	end
	self.GlowConnection = RunService.Heartbeat:Connect(function()
		if os.clock() >= self.GlowUntil then
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
	self.Pages(pages)
	const new = data.New
	if type(new) == "string" and pages[new] then
		const fresh = table.clone(Vide.untrack(self.Fresh))
		fresh[new] = true
		self.Fresh(fresh)
		self.Dependencies.HudController:PushText(rules.ToastText, "Good")
		self:StartGlow()
	end
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

-- The page on screen is read: it loses its "NEW!" when the tablet closes or the page turns.
function JournalController:MarkRead()
	const key = pageList[Vide.untrack(self.Index)].Key
	const fresh = Vide.untrack(self.Fresh)
	if fresh[key] then
		const copy = table.clone(fresh)
		copy[key] = nil
		self.Fresh(copy)
	end
end

function JournalController:Turn(delta: number)
	const index = math.clamp(Vide.untrack(self.Index) + delta, 1, #pageList)
	if index ~= Vide.untrack(self.Index) then
		self:MarkRead()
		self.Index(index)
	end
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
		self:StopGlow()
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
		self:MarkRead()
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
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return JournalController
