--!strict
--[[
	HintController (owner request 2026-10-22, Provisional; Content.Hints)

	Walt's notes on this client. The server (HintService) writes the Hints set (Night = the last night whose tip is on the
	paper) and answers the read_hints prompt with HintOpen. Here:
	  Paper    the live SurfaceGui on the paper of the front counter (Paper.luau; the place's static "NoteFace" is hidden on
	           this client): "NOTES", every tip so far, newest on top, a "NEW!" sticker until this player reads it.
	  Written  a rise of the record after the first one = Walt just wrote: pencil scribble (Rules.Sound, on screen: the
	           player is on the phone) and the newest tip writes itself in. The first tip this client sees written (Night 1,
	           right after the tutorial; owner 2026-10-22) also lights the paper (Mustard glow seen through walls) until read.
	  Read     HintOpen: the camera glides into a close-up over the paper (CameraController Prep mode, upright for the text,
	           framed to fit the sheet), the world prompts go away (input context "Hint"), the own body hides. Drag (mouse,
	           touch), the wheel, the right stick, the D-pad or the Up / Down / Page keys scroll the list. Walking (W A S D,
	           Space, the left stick), Backspace, Q, the gamepad's B and the Back button leave (FocusExit / BackButton, like
	           the cooking focus).
	  Scare    (Rules.Scare) a customer who reached the counter (Q1) or the drive-thru window while the player was reading,
	           and is still there when the player looks up: SuspenseController:Startle on its head (the forgotten-customer
	           scare: pull, zoom, shake, sting). Once per customer, a cooldown between two, never while the tutorial runs.
	           /dev hint scare arms it on the next way out (player attribute HintScareTest).
	Presentation only: the server decides what is written.
]]
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local BackButton = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.BackButton)
local FocusExit = require(StarterPlayer.StarterPlayerScripts.client.Interface.FocusExit)
local HudHold = require(StarterPlayer.StarterPlayerScripts.client.Interface.HudHold)
local Paper = require(script.Paper)

const RULES = Content.Hints.Rules
const SCARE = RULES.Scare
const RECORD_ID = 1
const HOLD = "Hint" -- InputController context owner while reading (world prompts hidden); also the HudHold key (the HUD
-- clock and money sat over the top of the sheet)
const LEAVE_ACTION = "HintLeave"
const SCROLL_ACTION = "HintScroll"
const SINK_PRIORITY = 3000
const LEAVE_KEYS: { Enum.KeyCode } = { Enum.KeyCode.Backspace, Enum.KeyCode.Q, Enum.KeyCode.ButtonB }
-- these scroll instead of leaving (bound above FocusExit, which treats the arrows as walking)
const SCROLL_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.Up] = -1,
	[Enum.KeyCode.Down] = 1,
	[Enum.KeyCode.PageUp] = -3,
	[Enum.KeyCode.PageDown] = 3,
	[Enum.KeyCode.DPadUp] = -1,
	[Enum.KeyCode.DPadDown] = 1,
}
const STATIC_FACE = "NoteFace" -- the place's own SurfaceGui on the paper (edit-mode look)
const GLOW_NAME = "HintGlow"
const GLOW_PERIOD = 1.1 -- s of one pulse
const SCARE_ATTRIBUTE = "HintScareTest" -- HintService:ArmScare
const TUTORIAL_ATTRIBUTE = "TutorialRunning"
const PAPER_LOOK = 1 -- s between two looks for the paper (streaming, map rebuilt)
-- Close-up (Provisional, judged in Play): the camera looks down at the sheet TILT off the vertical, from the reader's side,
-- and backs off until the sheet fits the screen with MARGIN around it
const FOV = 40
const TILT = math.rad(10)
const MARGIN = 1.08
const TRAVEL = 0.45
const LEAVE_TRAVEL = 0.35
-- Scrolling, in canvas px (Paper.luau: 300 px across the sheet)
const WHEEL_STEP = 48
const PAD_SPEED = 520 -- px/s at full stick or a held key
const PAD_DEAD = 0.2
const CANVAS_WIDTH = 300
const SCAN_STEP = 0.15 -- s between two looks at the counter while reading
const REVEAL_TIME = 6 -- s the newest tip may take to write itself in
const HEAD_LIFT = 4.5 -- studs above Q1 standing for a head when the dev scare has no customer
const FIRST_PERSON_WAIT = 1.5 -- s the scare waits for the camera to be back in the head

type Drag = { Input: InputObject, Last: Vector2 }

type Session = {
	EnteredAt: number,
	Gui: ScreenGui,
	Unmount: () -> (),
	Exit: () -> (),
	Heartbeat: RBXScriptConnection,
	Inputs: { RBXScriptConnection },
	Present: { [number]: boolean }, -- at the counter / window now (known before or seen arriving)
	Arrived: { [number]: number }, -- NpcId -> os.clock() it got there while reading
	Drag: Drag?,
	Held: number, -- -1 / 0 / 1 (x3 for the page keys): a scroll key held
	NextScan: number,
	Back: GuiButton?,
}

const HintController = Modux.Controller("HintController", {
	Require = { "CameraController", "InputController", "AudioController", "CustomerController", "SuspenseController" },
	Priority = 500,
})

function HintController:Setup()
	self.Written = Vide.source(0) :: Vide.Source<number>
	self.Ready = false :: boolean
	-- the last night this player read (client memory)
	self.LastRead = 0 :: number
	self.Unread = Vide.source(false) :: Vide.Source<boolean>
	-- the first tip written on this client glows until read (Spotlit: it already did, never again)
	self.Spotlight = false :: boolean
	self.Spotlit = false :: boolean
	self.Reading = Vide.source(false) :: Vide.Source<boolean>
	self.Clock = Vide.source(0) :: Vide.Source<number>
	self.Reveal = Vide.source(0) :: Vide.Source<number>
	self.Scroll = Vide.source(0) :: Vide.Source<number>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.PaperPart = Vide.source(nil :: BasePart?) :: Vide.Source<BasePart?>
	self.Height = Vide.source(450) :: Vide.Source<number>
	self.Density = Vide.source(300) :: Vide.Source<number>
	self.List = nil :: ScrollingFrame?
	self.Session = nil :: Session?
	-- os.clock() of the last arrival scare (nil = none yet)
	self.LastScare = nil :: number?
	-- NpcId -> true: already scared this client
	self.Startled = {} :: { [number]: boolean }
	-- last HintScareTest serial consumed
	self.ScareSeen = 0 :: number
end

-- Paper ---------------------------------------------------------------------------------------------------------------

-- The paper of the place (MapId Rules.MapId): the BasePart, or the highest part of a Model; nil while not there
local function findPaper(): BasePart?
	for _, descendant in Workspace:GetDescendants() do
		if descendant:GetAttribute("MapId") ~= RULES.MapId then
			continue
		end
		if descendant:IsA("BasePart") then
			return descendant
		elseif descendant:IsA("Model") then
			local best: BasePart? = nil
			for _, part in descendant:GetDescendants() do
				if part:IsA("BasePart") and (best == nil or part.Position.Y > best.Position.Y) then
					best = part
				end
			end
			return best
		end
	end
	return nil
end

-- Follows the paper: found, moved to the live notes (the static face hidden here), lost and found again
function HintController:WatchPaper()
	task.spawn(function()
		while true do
			local paper = Vide.untrack(self.PaperPart)
			if paper == nil or not paper:IsDescendantOf(Workspace) then
				paper = findPaper()
				if paper ~= Vide.untrack(self.PaperPart) then
					self.PaperPart(paper)
				end
			end
			if paper ~= nil then
				-- Face Top: the canvas runs along Z (across) and X (down) at the same density
				const density = CANVAS_WIDTH / math.max(paper.Size.Z, 0.05)
				if math.abs(density - Vide.untrack(self.Density)) > 1e-3 then
					self.Density(density)
				end
				const height = math.floor(paper.Size.X * density)
				if height ~= Vide.untrack(self.Height) then
					self.Height(height)
				end
				const face = paper:FindFirstChild(STATIC_FACE)
				if face ~= nil and face:IsA("SurfaceGui") and face.Enabled then
					face.Enabled = false
				end
			end
			task.wait(PAPER_LOOK)
		end
	end)
end

function HintController:MountPaper(playerGui: Instance)
	Vide.root(function()
		const surface = Paper({
			Adornee = function()
				-- read through a getter type: calling a Source of an optional type is ambiguous under the new solver
				return (self.PaperPart :: () -> BasePart?)()
			end,
			Height = function()
				return self.Height()
			end,
			PixelsPerStud = function()
				return self.Density()
			end,
			Written = function()
				return self.Written()
			end,
			Unread = function()
				return self.Unread()
			end,
			Reading = function()
				return self.Reading()
			end,
			Clock = function()
				return self.Clock()
			end,
			Reveal = function()
				return self.Reveal()
			end,
			Scroll = function()
				return self.Scroll()
			end,
			OnList = function(list: ScrollingFrame)
				self.List = list
			end,
		})
		surface.Parent = playerGui
		return nil
	end)
end

-- Clock for the sticker, the glow and the writing; the glow is a local Highlight on the paper while the first tip is unread
function HintController:Animate()
	RunService.Heartbeat:Connect(function()
		const now = os.clock()
		const unread = Vide.untrack(self.Unread)
		const revealing = now - Vide.untrack(self.Reveal) < REVEAL_TIME
		if unread or revealing or Vide.untrack(self.Reading) then
			self.Clock(now)
		end
		const paper = Vide.untrack(self.PaperPart)
		local glow = if paper ~= nil then paper:FindFirstChild(GLOW_NAME) :: Highlight? else nil
		if not unread or not self.Spotlight or paper == nil then
			if glow ~= nil then
				glow:Destroy()
			end
			return
		end
		if glow == nil then
			const made = Instance.new("Highlight")
			made.Name = GLOW_NAME
			made.FillColor = Theme.Color.Mustard
			made.OutlineColor = Theme.Color.Gold
			-- seen from the phone, through the trailer's walls: "go take a look"
			made.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			made.Adornee = paper
			made.Parent = paper
			glow = made
		end
		const wave = (math.sin(now * math.pi * 2 / GLOW_PERIOD) + 1) / 2
		const highlight = glow :: Highlight
		highlight.FillTransparency = 0.55 + 0.4 * wave
		highlight.OutlineTransparency = 0.2 + 0.6 * wave
	end)
end

-- Record ----------------------------------------------------------------------------------------------------------------

function HintController:Apply(night: number)
	const before = Vide.untrack(self.Written)
	if night ~= before then
		self.Written(night)
	end
	if self.Ready and night > before then
		-- Walt just wrote: the pencil from the paper, the tip writes itself in (on top: the sheet goes back to the top)
		self.Reveal(os.clock())
		self.Scroll(0)
		self.Dependencies.AudioController:Play(RULES.Sound, Vide.untrack(self.PaperPart))
		if not self.Spotlit then
			self.Spotlit = true
			self.Spotlight = true
		end
	end
	self.Ready = true
	if Vide.untrack(self.Reading) then
		self.LastRead = math.max(self.LastRead, night)
	end
	-- a repeated night goes back: what this player read stays read
	self.Unread(night > self.LastRead)
end

-- Close-up --------------------------------------------------------------------------------------------------------------

-- The camera over the sheet: the text's up (Face Top: the part's -X, flattened), the eye TILT off the vertical on the reader's
-- side, far enough for the whole sheet to fit the screen with MARGIN (the near edge is the one that leaves the frame first: it
-- is half the sheet x sin(TILT) closer to the eye; checked in Studio 2026-10-22)
local function poseOf(paper: BasePart): (CFrame, Vector3)
	const frame = paper.CFrame
	const top = frame.Position + frame.UpVector * (paper.Size.Y / 2)
	local up = -frame.RightVector
	up = Vector3.new(up.X, 0, up.Z)
	up = if up.Magnitude > 1e-3 then up.Unit else Vector3.new(0, 0, 1)
	const camera = Workspace.CurrentCamera
	const viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1280, 720)
	const aspect = math.max(viewport.X, 1) / math.max(viewport.Y, 1)
	const tanV = math.tan(math.rad(FOV) / 2)
	const tanH = tanV * aspect
	const half = paper.Size.X / 2
	const halfWide = paper.Size.Z / 2
	const distance = math.max(half * math.cos(TILT) / tanV + half * math.sin(TILT), halfWide / tanH) * MARGIN
	const back = -up * math.sin(TILT) + Vector3.yAxis * math.cos(TILT)
	return CFrame.lookAt(top + back * distance, top), top
end

-- Canvas px per screen px along the sheet's height (drag speed matches the finger)
function HintController:CanvasPerPixel(): number
	const paper = Vide.untrack(self.PaperPart)
	const camera = Workspace.CurrentCamera
	if paper == nil or camera == nil then
		return 1
	end
	const frame = paper.CFrame
	const top = frame.Position + frame.UpVector * (paper.Size.Y / 2)
	const half = -frame.RightVector * (paper.Size.X / 2)
	const a = camera:WorldToViewportPoint(top + half)
	const b = camera:WorldToViewportPoint(top - half)
	const pixels = (Vector2.new(a.X, a.Y) - Vector2.new(b.X, b.Y)).Magnitude
	return if pixels > 1 then Vide.untrack(self.Height) / pixels else 1
end

function HintController:ScrollBy(delta: number)
	const list = self.List
	if list == nil or delta == 0 then
		return
	end
	const room = math.max(list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y, 0)
	const target = math.clamp(Vide.untrack(self.Scroll) + delta, 0, room)
	if target ~= Vide.untrack(self.Scroll) then
		self.Scroll(target)
	end
end

-- Customer at the counter (Q1, not yet in the pickup line) or at the drive-thru window
local function atFront(record: any): boolean
	if record.State == "Leaving" or record.State == "Arriving" then
		return false
	end
	if record.Drive ~= nil then
		return record.Drive == 1
	end
	return record.Slot == 1 and record.Pickup == nil
end

function HintController:FrontNow(): { [number]: boolean }
	const out: { [number]: boolean } = {}
	for id, entry in self.Dependencies.CustomerController.Entries do
		const record = Vide.untrack(entry.Record)
		if record ~= false and atFront(record) then
			out[id] = true
		end
	end
	return out
end

-- While reading: who reached the counter / window since the reading began
function HintController:Scan(session: Session)
	const front = self:FrontNow()
	const now = os.clock()
	for id in front do
		if not session.Present[id] then
			session.Present[id] = true
			session.Arrived[id] = now
		end
	end
	for id in session.Present do
		if not front[id] then
			session.Present[id] = nil
			session.Arrived[id] = nil
		end
	end
end

function HintController:Overlay(): (() -> (), ScreenGui, GuiButton?)
	const device = self.Dependencies.InputController.Device
	local back: GuiButton? = nil
	const unmount, gui = Vide.root(function()
		const button = BackButton({
			Name = "HintBack",
			OnBack = function()
				self:Leave()
			end,
			Scale = function()
				return self.Scale()
			end,
		})
		back = button
		return Vide.create("ScreenGui")({
			Name = "HintReading",
			ResetOnSpawn = false,
			DisplayOrder = 20,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			-- frees the mouse wherever the camera left it
			Vide.create("TextButton")({
				Name = "Cursor",
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				Selectable = false,
				Modal = true,
			}),
			button,
			Vide.create("TextLabel")({
				Name = "Hint",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -18),
				Size = function()
					return UDim2.fromOffset(math.floor(520 * self.Scale()), math.floor(26 * self.Scale()))
				end,
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Body,
				TextSize = function()
					return math.floor(18 * self.Scale())
				end,
				TextColor3 = Theme.Color.Cream,
				TextStrokeColor3 = Theme.Color.Ink,
				TextStrokeTransparency = 0,
				Text = function()
					const kind = device()
					return if kind == "Gamepad"
						then "Right stick or D-pad to read  ·  B to leave"
						elseif kind == "Touch" then "Drag to read  ·  Back to leave"
						else "Drag or scroll to read  ·  Walk or Back to leave"
				end,
			}),
		})
	end)
	return unmount, gui :: ScreenGui, back
end

-- InputObject.Position and AbsolutePosition share a space (both under the top bar inset; the overlay keeps the inset)
local function inside(button: GuiButton?, position: Vector3): boolean
	if button == nil or not button.Visible then
		return false
	end
	const at = Vector2.new(position.X, position.Y)
	const min = button.AbsolutePosition
	const max = min + button.AbsoluteSize
	return at.X >= min.X and at.X <= max.X and at.Y >= min.Y and at.Y <= max.Y
end

function HintController:BindScroll(session: Session)
	table.insert(
		session.Inputs,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			const kind = input.UserInputType
			if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
				return
			end
			if inside(session.Back, input.Position) then
				return
			end
			session.Drag = { Input = input, Last = Vector2.new(input.Position.X, input.Position.Y) }
		end)
	)
	table.insert(
		session.Inputs,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			const kind = input.UserInputType
			if kind == Enum.UserInputType.MouseWheel then
				self:ScrollBy(-input.Position.Z * WHEEL_STEP)
				return
			end
			const drag = session.Drag
			if drag == nil then
				return
			end
			const moving = if drag.Input.UserInputType == Enum.UserInputType.MouseButton1
				then kind == Enum.UserInputType.MouseMovement
				else input == drag.Input
			if not moving then
				return
			end
			const at = Vector2.new(input.Position.X, input.Position.Y)
			const dy = at.Y - drag.Last.Y
			drag.Last = at
			-- the finger pulls the sheet: up shows what is below
			self:ScrollBy(-dy * self:CanvasPerPixel())
		end)
	)
	table.insert(
		session.Inputs,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			const drag = session.Drag
			if drag ~= nil and (input == drag.Input or input.UserInputType == drag.Input.UserInputType) then
				session.Drag = nil
			end
		end)
	)
	ContextActionService:BindActionAtPriority(SCROLL_ACTION, function(_name: string, state: Enum.UserInputState, input: InputObject)
		const step = SCROLL_KEYS[input.KeyCode]
		if step ~= nil then
			if state == Enum.UserInputState.Begin then
				session.Held = step
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				if session.Held == step then
					session.Held = 0
				end
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, SINK_PRIORITY + 1, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.PageUp, Enum.KeyCode.PageDown, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown)
end

-- One frame of reading: the right stick and held keys scroll, the counter is watched, a way out is checked
function HintController:StepReading(session: Session, dt: number)
	const character = Players.LocalPlayer.Character
	const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	const paper = Vide.untrack(self.PaperPart)
	if
		humanoid == nil
		or humanoid.Health <= 0
		or paper == nil
		or not paper:IsDescendantOf(Workspace)
		or Vide.untrack(self.Dependencies.CameraController.Mode) ~= "Prep"
	then
		self:Leave()
		return
	end
	local speed = session.Held
	if UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
		for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if state.KeyCode == Enum.KeyCode.Thumbstick2 and math.abs(state.Position.Y) > PAD_DEAD then
				speed -= state.Position.Y
			end
		end
	end
	if speed ~= 0 then
		self:ScrollBy(speed * PAD_SPEED * dt)
	end
	const now = os.clock()
	if now >= session.NextScan then
		session.NextScan = now + SCAN_STEP
		self:Scan(session)
	end
end

function HintController:Enter()
	if self.Session ~= nil then
		return
	end
	const paper = Vide.untrack(self.PaperPart)
	if paper == nil or not paper:IsDescendantOf(Workspace) then
		return
	end
	const camera = self.Dependencies.CameraController
	const frame, look = poseOf(paper)
	camera:Prep(true, frame, { Fov = FOV, Travel = TRAVEL, Min = 0.25, Look = look })
	if Vide.untrack(camera.Mode) ~= "Prep" then
		return -- a cutscene / spectate owns the camera
	end
	const viewport = if Workspace.CurrentCamera then Workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
	self.Scale(Theme.ScaleOf(viewport))
	camera:SetBodyHidden(true)
	self.Dependencies.InputController:Hold(HOLD, true)
	HudHold.Hold(HOLD)
	-- the touch stick would sit under Back and walking does nothing here (the drag is the sheet's)
	GuiService.TouchControlsEnabled = false

	const unmount, gui, back = self:Overlay()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	const session: Session = {
		EnteredAt = os.clock(),
		Gui = gui,
		Unmount = unmount,
		Exit = FocusExit.Bind({
			Name = LEAVE_ACTION,
			Priority = SINK_PRIORITY,
			OnLeave = function()
				self:Leave()
			end,
			Leave = LEAVE_KEYS,
			Stick = true,
		}),
		Heartbeat = nil :: any,
		Inputs = {},
		Present = self:FrontNow(),
		Arrived = {},
		Drag = nil,
		Held = 0,
		NextScan = 0,
		Back = back,
	}
	session.Heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		if self.Session == session then
			self:StepReading(session, dt)
		end
	end)
	self.Session = session
	self:BindScroll(session)
	self.Reading(true)
	self.LastRead = math.max(self.LastRead, Vide.untrack(self.Written))
	self.Unread(false)
	self.Spotlight = false
end

function HintController:Leave()
	const session = self.Session
	if session == nil then
		return
	end
	self.Session = nil
	session.Heartbeat:Disconnect()
	for _, connection in session.Inputs do
		connection:Disconnect()
	end
	ContextActionService:UnbindAction(SCROLL_ACTION)
	session.Exit()
	session.Unmount()
	session.Gui:Destroy()
	self.Reading(false)
	self.LastRead = math.max(self.LastRead, Vide.untrack(self.Written))
	self.Unread(false)
	const camera = self.Dependencies.CameraController
	camera:SetBodyHidden(false)
	self.Dependencies.InputController:Hold(HOLD, false)
	HudHold.Release(HOLD)
	GuiService.TouchControlsEnabled = true
	camera:Prep(false, nil, { Travel = LEAVE_TRAVEL })
	self:LookUp(session)
end

-- Scare -----------------------------------------------------------------------------------------------------------------

-- The head of a customer rig (or its pivot), nil when the rig is gone
function HintController:HeadOf(id: number): Vector3?
	const model = self.Dependencies.CustomerController.Models[id]
	if model == nil or model.Parent == nil then
		return nil
	end
	const head = model:FindFirstChild("Head")
	return if head ~= nil and head:IsA("BasePart") then head.Position else model:GetPivot().Position
end

-- The player looks up from the paper: a customer who got to the counter / window meanwhile is right there
function HintController:LookUp(session: Session)
	const player = Players.LocalPlayer
	const now = os.clock()
	const serial = player:GetAttribute(SCARE_ATTRIBUTE)
	const forced = type(serial) == "number" and serial ~= self.ScareSeen
	if forced then
		self.ScareSeen = serial :: number
	end
	if not forced then
		if player:GetAttribute(TUTORIAL_ATTRIBUTE) == true then
			return
		end
		const last = self.LastScare
		if now - session.EnteredAt < SCARE.MinRead or (last ~= nil and now - last < SCARE.Cooldown) then
			return
		end
	end
	for id in self.Startled do
		if self.Dependencies.CustomerController.Entries[id] == nil then
			self.Startled[id] = nil
		end
	end
	const front = self:FrontNow()
	const character = player.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	const from = if root ~= nil then root.Position else Vector3.zero
	local chosen: number? = nil
	local nearest = math.huge
	local function consider(id: number)
		if self.Startled[id] or not front[id] then
			return
		end
		const head = self:HeadOf(id)
		if head == nil then
			return
		end
		const distance = (head - from).Magnitude
		if distance < nearest then
			nearest = distance
			chosen = id
		end
	end
	for id, at in session.Arrived do
		if forced or now - at >= SCARE.MinStand then
			consider(id)
		end
	end
	if forced and chosen == nil then
		for id in front do
			consider(id)
		end
	end
	local fallback: Vector3? = nil
	if chosen == nil then
		if not forced then
			return
		end
		const q1 = MapIndex.FindPoint("Q1")
		fallback = if q1 ~= nil then q1.Position + Vector3.new(0, HEAD_LIFT, 0) else nil
		if fallback == nil then
			return
		end
	end
	self.LastScare = now
	const id = chosen
	if id ~= nil then
		self.Startled[id] = true
		-- the forgotten-customer glance must not play it a second time
		self.Dependencies.SuspenseController.Noticed[id] = true
	end
	task.delay(SCARE.Delay, function()
		const camera = self.Dependencies.CameraController
		const deadline = os.clock() + FIRST_PERSON_WAIT
		while Vide.untrack(camera.Mode) ~= "FirstPerson" and os.clock() < deadline do
			task.wait()
		end
		if Vide.untrack(camera.Mode) ~= "FirstPerson" or self.Session ~= nil then
			return
		end
		const point = if id ~= nil then self:HeadOf(id) else fallback
		if point ~= nil then
			self.Dependencies.SuspenseController:Startle(point)
		end
	end)
end

HintController:OnInit(function(self)
	self:Setup()
	const hints = self.Libs.Net.Hints
	hints:onAdded(function(id, record)
		if id == RECORD_ID then
			self:Apply(record.Night)
		end
	end)
	hints:onChanged(function(id, record)
		if id == RECORD_ID then
			self:Apply(record.Night)
		end
	end)
	self.Libs.Net.HintOpen:onClient(function()
		self:Enter()
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		self:Leave()
	end)
end)

HintController:OnStart(function(self)
	self:WatchPaper()
	self:Animate()
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:MountPaper(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return HintController
