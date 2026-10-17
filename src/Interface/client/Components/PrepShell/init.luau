--!strict
-- PrepShell: the chrome of the focused prep mode (docs/art/prep-ui-spec.md; docs/tech/prep-mode.md §2; DEC-223). It owns
-- WHERE things are and nothing else; the stages put their content in three slots (Ticket, Board, Panel) and the
-- PrepController owns every rule. Blocks (the five persistent ones of the spec §2.1, plus the contextual ones):
--   top bar        Leave (always on screen) + the four tabs Order / Grill / Build / Serve, badges on the tabs
--   status         money, sun / moon and the clock in an Ink pill, top right; a sanity strip under it at night
--   ticket         left column (a strip in portrait); the Ticket slot
--   board          the work surface (Cream), a header with the grade pips and the one-line hint; the Board slot
--   panel          the Panel slot (ingredients), only when HasPanel
--   Next / Serve   bottom right, Mustard when it can be pressed, Slate when not (a tap on it then shakes and calls
--                  OnBlocked); pulses 3 times when it becomes ready (not with reduced motion)
--   trash          bottom left, only with a plate; HOLD 0.5 s (a plain tap never trashes); a Green fill shows the hold
--   assist         the +30 % tolerance toggle (Content.Prep.Rules.Assist), left of Next
--   toast          one at a time, bottom centre
-- Minimal 3D mode (`Minimal`, docs/tech/prep-3d.md §5, TASK-199): the world is the minigame. Only a thin progress card (top
-- centre), the ticket (left), the section tabs + Leave / Assist / Tap + Next at the bottom, a one-line hint, the toast and the
-- plate seal stay; no Board, Panel, Trash or own status (the Hud keeps money, clock and sanity on screen). Layout.Compute(.., true).
-- Layout (Layout.luau) is computed from the area of the ScreenGui divided by the global UI scale (Theme.ScaleOf): phone
-- landscape 667 x 375 up, desktop, portrait. The ScreenGui must use ScreenInsets = DeviceSafeInsets (the spec margins are
-- inside the safe area). Tabs and buttons are CartoonButtons: touch targets >= 44 px, Selectable for the gamepad. No red.
-- Pure: only props, no network, no input binding (the PrepController binds keys and the gamepad). Build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Vignette = require(script.Parent.Vignette)
local Seal = require(script.Parent.PlateView.Seal)
local Layout = require(script.Layout)
local Objective = require(script.Parent.Parent.Objective)
local Zones = require(script.Parent.Parent.Zones)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale, UIStroke and UIGradient are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Tab = { Key: string, Label: string, Icon: string }

export type Pip = { Label: string, Grade: Seal.Grade? }

-- The live grade of the plate (polish 2026-10-12): the mean score 0..100 of the stages done and the shape of its band.
export type Note = { Score: number, Grade: Seal.Grade }

-- A gamepad button and what it does now ("Pour", "Free draw"), drawn over the hint pill (TASK-268).
export type PadKey = { Key: Enum.KeyCode, Text: string }

export type NextButton = {
	Label: () -> string,
	Enabled: () -> boolean,
	-- Pulses 3 times each time it turns true.
	Pulse: (() -> boolean)?,
	OnPress: () -> (),
	-- A tap while it is disabled (the owner shows why in the hint).
	OnBlocked: (() -> ())?,
}

export type TrashButton = {
	Visible: () -> boolean,
	-- Seconds of the hold (Content.Prep: 0.5).
	Hold: number,
	-- Header text while the hold is in progress ("Hold to trash").
	HoldText: string,
	OnTrash: () -> (),
}

export type AssistButton = {
	Label: string,
	On: () -> boolean,
	OnToggle: () -> (),
}

-- A call back to a section (the flip window of a sausage opened while another tab is in front): the dot of `Tab` pulses with a mini bar
-- (`Share` 0..1 through the window) and a chip with `Text` appears near the dots; a tap on either goes to the tab.
export type Alert = { Tab: string, Share: number, Id: number, Text: string }

export type Toast = { Text: string, Kind: "Info" | "Good" | "Alert", Id: number }

-- The thin progress card of the minimal 3D mode (top centre): the verb of the section, `Value` 0..1 over the whole run (the
-- bar has one division per tab), the three grade pips on the right of the label.
export type ProgressCard = {
	Label: () -> string,
	Value: () -> number,
}

-- The bin zone of the minimal mode (2D, at Layout.Mini.Bin): shown while there is something to drag, the lid opens and the zone lights
-- while a dragged item is inside it. The drop is tested in px by the world (`Bind` hands it the hit function and the centre).
export type BinZone = {
	Wanted: () -> boolean,
	-- a dragged item is inside the zone
	Over: () -> boolean,
	-- changes on every item swallowed (the zone bounces)
	Chomp: () -> number,
	Label: string,
	-- Called with the functions of the zone while it is mounted ((viewport px) -> inside, () -> centre in viewport px) and with nil on unmount.
	Bind: (hit: ((Vector2) -> boolean)?, centre: (() -> Vector2?)?) -> (),
}

export type Slots = {
	Ticket: (layout: () -> Layout.Result) -> any,
	Board: (layout: () -> Layout.Result) -> any,
	Panel: ((layout: () -> Layout.Result) -> any)?,
}

export type Props = {
	Tabs: { Tab },
	Tab: () -> string,
	-- Count per tab key (Order: customers waiting, Grill: sausages ready, Serve: plates ready); 0 / nil = no badge.
	Badges: (() -> { [string]: number })?,
	OnTab: (key: string) -> (),
	OnLeave: () -> (),
	LeaveText: string?,
	Hint: () -> string,
	Pips: (() -> { Pip })?,
	HasPanel: () -> boolean,
	Next: NextButton,
	Trash: TrashButton,
	-- The 2D bin zone of the minimal mode (nil = none).
	Bin: BinZone?,
	Assist: AssistButton,
	Cash: () -> number,
	Clock: () -> string,
	IsNight: () -> boolean,
	-- 0..1 (nil = no strip); only shown at night.
	Sanity: (() -> number?)?,
	Toast: () -> Toast?,
	Slots: Slots,
	-- false hides the whole chrome with a short pop (entering / leaving).
	Shown: (() -> boolean)?,
	-- Override of the UI scale (stories and tests).
	Scale: (() -> number)?,
	-- Ink vignette on the edges (the fallback of a camera without depth of field).
	Vignette: (() -> boolean)?,
	-- The minimal 3D mode (docs/tech/prep-3d.md §5, TASK-199): no Board, Panel, Trash, notch or own status (the Hud shows money,
	-- clock and sanity); the section tabs and the buttons go to the bottom, a thin progress card to the top centre. nil / false =
	-- the 2D chrome above, unchanged.
	Minimal: (() -> boolean)?,
	-- The minimal mode shows the sections as a row of indicator dots (the active one a longer pill), each a button. `Near` = the index
	-- of the tab the camera is closest to while it pans along the trail (0 / nil = the tab in front); `DotSize` / `DotActive` = px of
	-- the dot and of the active pill (Rules.Camera.Pan.Dots). The hit area stays the tab rectangle (>= 44 px).
	Near: (() -> number)?,
	-- The call back of the moment (false / nil = none), minimal mode only. Mustard, never red; no pulse with reduced motion.
	Alert: (() -> Alert | false)?,
	DotSize: number?,
	DotActive: number?,
	Progress: ProgressCard?,
	-- The seal of the finished plate (transient, 96 px) and the word under it; `SealScore` is the number that rolls 0 -> N under it.
	Seal: (() -> Seal.Grade?)?,
	SealLabel: ((grade: Seal.Grade) -> string)?,
	SealScore: (() -> number)?,
	-- The live note of the progress card (replaces the three 18 px pips) and the Perfects in a row (a chip from two).
	Note: (() -> Note?)?,
	Streak: (() -> number)?,
	-- "Tap and tap" accessibility chip, next to Assist (nil = no chip).
	TapMode: AssistButton?,
	-- The gamepad is the device: the buttons wear their button glyph (B Leave, Y Next, LB / RB the first / last tab).
	Pad: (() -> boolean)?,
	-- The gamepad buttons of the current step (TASK-268): chips with the platform's own button image (A / Cross, RT / R2...)
	-- over the hint pill, only while the gamepad is the device. nil / {} = none.
	PadKeys: (() -> { PadKey })?,
	-- The tutorial step of the moment (Objective module): when there is one, the progress card IS the tutorial card (chip, objective,
	-- hint, live note, bar) and the Skip pill sits beside it; false / nil = the plain progress card.
	Objective: (() -> Objective.Card | false)?,
	OnSkip: (() -> ())?,
	-- Overlays that are up (Zones module, screen px): the hint and the toast keep off them. nil = none.
	Reserved: (() -> { Zones.Zone })?,
	Name: string?,
}

const BADGE_TONE: { [string]: Theme.Tone } = {
	Order = Theme.Tone.Teal,
	Grill = Theme.Tone.Green,
	Build = Theme.Tone.Cream,
	Board = Theme.Tone.Cream,
	Toppings = Theme.Tone.Teal,
	Serve = Theme.Tone.Mustard,
}
const LIFT = 3 -- px the active tab rises
const PULSES = 3
const PULSE_TIME = 0.6
const ALERT_PERIOD = 0.9 -- s of one breath of the call back (the Grill dot)
const CHIP_W = 112
const CHIP_H = 44
const SHAKE_TIME = 0.18
const PAD_KEYS = 3 -- gamepad button chips over the hint pill (TASK-268)
const VIGNETTE = 0.35
-- The progress card at the top centre (verb, live note, section bar; it also hosted the tutorial step) is off (owner playtest
-- 2026-10-14, TASK-259, Provisional): the code stays, flip to bring it back
const SHOW_PROGRESS = false

local function money(value: number): string
	const digits = tostring(math.max(math.floor(value), 0))
	const spaced = string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")
	const trimmed = string.gsub(string.reverse(spaced), "^,", "")
	return `${trimmed}`
end

-- Small shake of a button: an offset source and the kick that runs it (not with reduced motion).
local function shaker(): (Vide.Source<number>, () -> ())
	const offset = source(0)
	local running = false
	local function kick()
		if running or Motion.Reduced() then
			return
		end
		running = true
		task.spawn(function()
			const start = os.clock()
			while true do
				const t = (os.clock() - start) / SHAKE_TIME
				if t >= 1 then
					break
				end
				offset(math.sin(t * math.pi * 6) * 6 * (1 - t))
				task.wait()
			end
			offset(0)
			running = false
		end)
	end
	return offset, kick
end

-- TASK-264 (owner request 2026-10-14): the section dots of the minimal mode are round ICON buttons: a sausage (grill), a bun
-- (board) and a ketchup pot (toppings), from the icon sheet; the lit one is Mustard and a little bigger, hover / press pop with a
-- spring and the name of the section floats over it. A tab without an entry keeps the plain dot.
const SECTION_ICONS: { [string]: string } = {
	Grill = "Ingredient/sausage",
	Board = "Ingredient/bun",
	Build = "Ingredient/bun",
	Toppings = "Ingredient/ketchup",
}
const SECTION_ICON_SIZE = 40 -- px, the round button
const SECTION_HOVER_SCALE = 1.25
const SECTION_LIT_SCALE = 1.12

-- One round section button (TASK-264): the icon on a Cream disc (Mustard when lit or called), Ink rim, a spring scale that pops on
-- hover / press, and the section name in a small tag over it while hovered. Reduced motion: no spring (the scale jumps).
local function sectionIcon(
	icon: string,
	label: string,
	lit: () -> boolean,
	called: () -> boolean,
	hovered: () -> boolean,
	pressed: () -> boolean
): Frame
	const target = function(): number
		if pressed() then
			return 0.92
		elseif hovered() then
			return SECTION_HOVER_SCALE
		elseif lit() then
			return SECTION_LIT_SCALE
		end
		return 1
	end
	const scale: () -> number = if Motion.Reduced()
		then target
		else Vide.spring(target, Theme.Motion.Pop, Theme.Motion.PopDamping) :: any
	const rect = Icons.Rect(icon) or { Offset = Vector2.zero, Size = Vector2.zero }
	return create("Frame")({
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SECTION_ICON_SIZE, SECTION_ICON_SIZE),
		BackgroundColor3 = function(): Color3
			return if lit() or called() then Theme.Color.Mustard else Theme.Color.Cream
		end,
		createRaw("UIScale")({
			Scale = function(): number
				return math.max(scale(), 0.01)
			end,
		}),
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = function(): number
				return if lit() then 3 else 2
			end,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		create("ImageLabel")({
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, 0.78),
			BackgroundTransparency = 1,
			Image = Icons.ImageOf(icon),
			ImageRectOffset = rect.Offset,
			ImageRectSize = rect.Size,
			Visible = Icons.Has(icon),
		}),
		-- the name of the section, over the button while the pointer is on it
		create("Frame")({
			Name = "Tag",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, -8),
			Size = UDim2.fromOffset(96, 26),
			BackgroundColor3 = Theme.Color.Cream,
			Visible = hovered,
			ZIndex = 6,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			CartoonLabel({
				Text = label,
				TextSize = Theme.MinTextSize,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Box = UDim2.fromScale(1, 1),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
				ZIndex = 7,
			}),
		}),
	}) :: Frame
end

-- Icon of the sheet when it exists, a flat dot otherwise.
local function glyph(name: string, fallback: Color3, side: number): Frame
	const has = Icons.Has(name)
	const rect = Icons.Rect(name) or { Offset = Vector2.zero, Size = Vector2.zero }
	return create("Frame")({
		Name = "Glyph",
		Size = UDim2.fromOffset(side, side),
		BackgroundTransparency = 1,
		create("ImageLabel")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Icons.ImageOf(name),
			ImageRectOffset = rect.Offset,
			ImageRectSize = rect.Size,
			Visible = has,
		}),
		create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, 0.78),
			BackgroundColor3 = fallback,
			Visible = not has,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
	})
end

-- The image Roblox has for a gamepad button on this platform (PlayStation or Xbox art), "" when none (TASK-268).
local function padImage(key: Enum.KeyCode): string
	const ok, image = pcall(function()
		return UserInputService:GetImageForKeyCode(key)
	end)
	return if ok and type(image) == "string" then image else ""
end

-- A gamepad glyph on the corner of a button (B, Y, LB, RB by their KeyCode): shown only when the gamepad is the device. The
-- platform's own button image (Cross / A, R1 / RB...) when Roblox has one (TASK-268), else a round chip with the Xbox letter, so
-- the cue is the shape and the text, not the colour.
local function padGlyph(key: Enum.KeyCode, text: string, visible: () -> boolean): Frame
	const image = padImage(key)
	if image ~= "" then
		return create("Frame")({
			Name = "PadGlyph",
			Position = UDim2.fromOffset(-8, -10),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 1,
			ZIndex = 7,
			Visible = visible,
			create("ImageLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = image,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 8,
			}),
		})
	end
	return create("Frame")({
		Name = "PadGlyph",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(-6, -8),
		Size = UDim2.fromOffset(if #text > 1 then 28 else 22, 22),
		BackgroundColor3 = Theme.Color.Cream,
		ZIndex = 7,
		Visible = visible,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		CartoonLabel({
			Text = text,
			TextSize = Theme.MinTextSize,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Box = UDim2.fromScale(1, 1),
			XAlignment = Enum.TextXAlignment.Center,
			YAlignment = Enum.TextYAlignment.Center,
			ZIndex = 8,
		}),
	})
end

-- The bin drawn with Frames (lid, handle, body).
local function binGlyph(): Frame
	local function bar(x: number, y: number, w: number, h: number, color: Color3, corner: number): Frame
		return create("Frame")({
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0, corner) }),
		})
	end
	return create("Frame")({
		Name = "Bin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 28),
		BackgroundTransparency = 1,
		ZIndex = 3,
		bar(8, 0, 10, 4, Theme.Color.Ink, 2),
		bar(1, 4, 24, 5, Theme.Color.Ink, 2),
		bar(4, 10, 18, 18, Theme.Color.Ink, 4),
		bar(7, 13, 3, 12, Theme.Tone.Cream.Top, 1),
		bar(12, 13, 3, 12, Theme.Tone.Cream.Top, 1),
		bar(17, 13, 3, 12, Theme.Tone.Cream.Top, 1),
	})
end

-- The Assist chip's picture: a target (ring, dot, four ticks), 24 px, Ink: "the aim is easier". Frames only.
local function assistGlyph(): Frame
	local function tick(x: number, y: number, w: number, h: number): Frame
		return create("Frame")({
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = Theme.Color.Ink,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		})
	end
	return create("Frame")({
		Name = "AssistGlyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		ZIndex = 3,
		create("Frame")({
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
		tick(9, 9, 6, 6),
		tick(10.5, 0, 3, 4),
		tick(10.5, 20, 3, 4),
		tick(0, 10.5, 4, 3),
		tick(20, 10.5, 4, 3),
	})
end

-- A little Frame icon for a section (24 px box, Ink on the tab): the grate, the board with its cut, the bottle, the plate.
local function tabIcon(key: string, visible: () -> boolean, position: () -> UDim2): Frame
	local function piece(x: number, y: number, w: number, h: number, color: Color3, corner: number): Frame
		return create("Frame")({
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(corner, 0) }),
		})
	end
	const ink, cream = Theme.Color.Ink, Theme.Color.Cream
	local parts: { Frame }
	if key == "Grill" then
		parts = {
			piece(3, 3, 3, 15, ink, 0.5),
			piece(8, 3, 3, 15, ink, 0.5),
			piece(13, 3, 3, 15, ink, 0.5),
			piece(18, 3, 3, 15, ink, 0.5),
			piece(1, 19, 22, 4, ink, 0.5),
		}
	elseif key == "Board" or key == "Build" then
		parts = {
			piece(1, 5, 22, 15, ink, 0.25),
			piece(5, 11, 14, 3, cream, 0.5),
			piece(17, 7, 4, 4, cream, 0.5),
		}
	elseif key == "Toppings" then
		parts = {
			piece(9, 1, 6, 6, ink, 0.3),
			piece(5, 6, 14, 17, ink, 0.3),
			piece(9, 12, 6, 6, cream, 0.5),
		}
	else
		-- Serve (the plate) and anything else: a plate seen from above
		parts = {
			piece(1, 1, 22, 22, ink, 0.5),
			piece(5, 5, 14, 14, cream, 0.5),
			piece(9, 9, 6, 6, ink, 0.5),
		}
	end
	return create("Frame")({
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Visible = visible,
		ZIndex = 3,
		parts,
	}) :: Frame
end

return function(props: Props): Frame
	const area = source(Vector2.new(667, 375))
	const root = create("Frame")({
		Name = props.Name or "PrepShell",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}) :: Frame
	const measure = function()
		const size = root.AbsoluteSize
		if size.X > 0 and size.Y > 0 and size ~= untrack(area) then
			area(size)
		end
	end
	const sizeConnection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
	cleanup(function()
		sizeConnection:Disconnect()
	end)
	measure()

	const scale = function(): number
		return if props.Scale ~= nil then props.Scale() else Theme.ScaleOf(area())
	end
	const canvas = function(): Vector2
		return area() / scale()
	end
	const shown = function(): boolean
		return props.Shown == nil or props.Shown()
	end
	const pop = Motion.Pop(shown)
	const reduced = Motion.Reduced()

	const tabs = props.Tabs
	const activeIndex = function(): number
		const current = props.Tab()
		for index, tab in tabs do
			if tab.Key == current then
				return index
			end
		end
		return 1
	end
	const minimal = function(): boolean
		return props.Minimal ~= nil and props.Minimal()
	end
	const pad = function(): boolean
		return props.Pad ~= nil and props.Pad()
	end
	const objectiveCard = function(): Objective.Card | false
		return if props.Objective ~= nil then props.Objective() else false
	end
	const layout = Vide.derive(function(): Layout.Result
		-- the zones of the overlays are screen px of the viewport; the canvas is in UI px from the top left of this gui
		const reserved: { Layout.Rect } = {}
		if props.Reserved ~= nil then
			const k = scale()
			const origin = root.AbsolutePosition
			for _, zone in props.Reserved() do
				table.insert(reserved, {
					X = (zone.X - origin.X) / k,
					Y = (zone.Y - origin.Y) / k,
					W = zone.W / k,
					H = zone.H / k,
				})
			end
		end
		return Layout.Compute(canvas(), props.HasPanel(), #tabs, activeIndex(), minimal(), {
			Taps = props.TapMode ~= nil,
			Objective = objectiveCard() ~= false,
			Reserved = reserved,
			Sanity = props.Sanity ~= nil and props.Sanity() ~= nil,
		})
	end)
	-- position / size of a block of the minimal mode (zero in the 2D chrome: those blocks are hidden there)
	local function miniRect(pick: (Layout.Mini) -> Layout.Rect): () -> Layout.Rect
		return function(): Layout.Rect
			const mini = layout().Mini
			return if mini ~= nil then pick(mini) else { X = 0, Y = 0, W = 0, H = 0 }
		end
	end
	local function atMini(pick: (Layout.Mini) -> Layout.Rect): () -> UDim2
		const rectOf = miniRect(pick)
		return function(): UDim2
			const r = rectOf()
			return UDim2.fromOffset(r.X, r.Y)
		end
	end
	local function sizedMini(pick: (Layout.Mini) -> Layout.Rect): () -> UDim2
		const rectOf = miniRect(pick)
		return function(): UDim2
			const r = rectOf()
			return UDim2.fromOffset(r.W, r.H)
		end
	end

	-- position / size of a block, reactive on the layout
	local function at(pick: (Layout.Result) -> Layout.Rect): () -> UDim2
		return function(): UDim2
			const r = pick(layout())
			return UDim2.fromOffset(r.X, r.Y)
		end
	end
	local function sized(pick: (Layout.Result) -> Layout.Rect): () -> UDim2
		return function(): UDim2
			const r = pick(layout())
			return UDim2.fromOffset(r.W, r.H)
		end
	end

	-- the pill that holds Leave, Assist and Tap in the 3D chrome (U-2): one Ink shape instead of three loose buttons
	const pill = CartoonPanel({
		Name = "Pill",
		Tone = Theme.Tone.Ink,
		Radius = Theme.Radius.Pill,
		Lip = 3,
		-- only while the Tap chip shares it with Leave: alone, the red Leave button needs no frame (owner 2026-10-17)
		Visible = function(): boolean
			return minimal() and props.TapMode ~= nil
		end,
		Position = atMini(function(m)
			return m.Pill
		end),
		Size = sizedMini(function(m)
			return m.Pill
		end),
	})

	-- Leave: on screen whenever the chrome is. A red rounded button with the close cross and the word (owner 2026-10-17: the
	-- cream disc in the Ink pill read badly); `PrepPress` lets the gamepad cursor press it (Pointer.HitPress)
	const leave = CartoonButton({
		Name = "Leave",
		Tone = Theme.Tone.Ketchup,
		Radius = Theme.Radius.Card,
		Icon = "Ui/close",
		IconSize = 18,
		-- the word only where it fits (the 2D chrome keeps a 44 px square: the cross alone)
		Text = function()
			const l = layout()
			if l.Leave.W < 70 then
				return ""
			end
			return if l.LeaveWide then (props.LeaveText or "Leave") else "Exit"
		end,
		TextSize = 16,
		Position = at(function(l)
			return l.Leave
		end),
		Size = sized(function(l)
			return l.Leave
		end),
		Padding = 8,
		OnActivated = props.OnLeave,
	})
	leave:SetAttribute("PrepPress", "Leave")
	-- the B glyph rides on the button itself: `Children` would replace the icon and the word of CartoonButton
	padGlyph(Enum.KeyCode.ButtonB, "B", pad).Parent = leave

	-- tabs
	const tabButtons: { any } = {}
	for index, tab in tabs do
		const isActive = function(): boolean
			return props.Tab() == tab.Key
		end
		const badge = function(): number
			const counts = if props.Badges ~= nil then props.Badges() else nil
			return if counts ~= nil then counts[tab.Key] or 0 else 0
		end
		const tone = BADGE_TONE[tab.Key] or Theme.Tone.Teal
		table.insert(
			tabButtons,
			CartoonButton({
				Name = `Tab_{tab.Key}`,
				-- the minimal mode has the dots below instead
				Visible = function(): boolean
					return not minimal()
				end,
				Tone = function()
					return if isActive() then Theme.Tone.Mustard else Theme.Tone.Cream
				end,
				Outline = function()
					return if isActive() then Theme.Outline.Thick else Theme.Outline.Normal
				end,
				Position = function(): UDim2
					const r = layout().Tabs[index]
					return UDim2.fromOffset(r.X, r.Y - (if isActive() then LIFT else 0))
				end,
				Size = function(): UDim2
					const r = layout().Tabs[index]
					return UDim2.fromOffset(r.W, r.H)
				end,
				Padding = 0,
				OnActivated = function()
					props.OnTab(tab.Key)
				end,
				Children = {
					-- the icon: centred on an inactive tab (3D chrome: only the icon), at the left of the word on the active one
					tabIcon(tab.Key, minimal, function(): UDim2
						return if isActive() then UDim2.new(0, 22, 0.5, 0) else UDim2.fromScale(0.5, 0.5)
					end),
					CartoonLabel({
						Text = function()
							const l = layout()
							return if l.TabsCompact and not isActive() and not l.TabsIconOnly then string.sub(tab.Label, 1, 1) else tab.Label
						end,
						TextSize = 16,
						Color = Theme.Color.Ink,
						Stroke = 0,
						Visible = function(): boolean
							return isActive() or not layout().TabsIconOnly
						end,
						Position = function(): UDim2
							return if minimal() and isActive() then UDim2.fromOffset(34, 0) else UDim2.fromOffset(0, 0)
						end,
						Box = function(): UDim2
							return if minimal() and isActive() then UDim2.new(1, -38, 1, 0) else UDim2.fromScale(1, 1)
						end,
						XAlignment = Enum.TextXAlignment.Center,
						YAlignment = Enum.TextYAlignment.Center,
					}),
					-- LB / RB walk the tabs: the glyph sits on the first and the last one (the minimal mode, gamepad)
					if index == 1 or index == #tabs
						then padGlyph(if index == 1 then Enum.KeyCode.ButtonL1 else Enum.KeyCode.ButtonR1, if index == 1 then "LB" else "RB", function(): boolean
							return pad() and minimal()
						end)
						else nil,
					-- the count of what waits on this tab
					create("Frame")({
						Name = "Badge",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 2, 0, -4),
						Size = UDim2.fromOffset(22, 22),
						BackgroundColor3 = tone.Bottom,
						ZIndex = 5,
						Visible = function()
							return badge() > 0
						end,
						create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						createRaw("UIStroke")({
							Color = Theme.Color.Ink,
							Thickness = 2,
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						}),
						CartoonLabel({
							Text = function()
								return tostring(math.min(badge(), 99))
							end,
							TextSize = Theme.MinTextSize,
							Color = Theme.Color.Ink,
							Stroke = 0,
							Box = UDim2.fromScale(1, 1),
							XAlignment = Enum.TextXAlignment.Center,
							YAlignment = Enum.TextYAlignment.Center,
							ZIndex = 6,
						}),
					}),
				},
			})
		)
	end

	-- the dots of the minimal mode: one round indicator per section, the lit one (the tab in front, or the nearest one while the
	-- camera pans) a longer mustard pill; each is a button with the full tab rectangle as its hit area
	const dotSize = props.DotSize or 14
	const dotActive = props.DotActive or 34
	const litIndex = function(): number
		const near = if props.Near ~= nil then props.Near() else 0
		return if near > 0 then near else activeIndex()
	end
	-- the call back (flip window open elsewhere): the dot of its tab pulses in Mustard, a mini bar under it, a chip near the dots
	const alertOf = function(): Alert | false
		return if props.Alert ~= nil then props.Alert() else false
	end
	const alertOn = Vide.derive(function(): boolean
		return minimal() and alertOf() ~= false
	end)
	const pulse = source(1)
	local pulseRun = 0
	effect(function()
		const on = alertOn()
		pulseRun += 1
		const mine = pulseRun
		pulse(1)
		if on and not Motion.Reduced() then
			task.spawn(function()
				const start = os.clock()
				while pulseRun == mine do
					pulse((math.sin((os.clock() - start) * math.pi * 2 / ALERT_PERIOD - math.pi / 2) + 1) / 2)
					task.wait()
				end
			end)
		end
	end)
	cleanup(function()
		pulseRun += 1
	end)
	const dotButtons: { any } = {}
	for index, tab in tabs do
		const lit = function(): boolean
			return litIndex() == index
		end
		const called = function(): boolean
			const value = alertOf()
			return value ~= false and value.Tab == tab.Key and minimal()
		end
		const badge = function(): number
			const counts = if props.Badges ~= nil then props.Badges() else nil
			return if counts ~= nil then counts[tab.Key] or 0 else 0
		end
		const tone = BADGE_TONE[tab.Key] or Theme.Tone.Teal
		const hovered = source(false)
		const pressed = source(false)
		table.insert(
			dotButtons,
			create("TextButton")({
				Name = `Dot_{tab.Key}`,
				Position = function(): UDim2
					const r = layout().Tabs[index]
					return UDim2.fromOffset(r.X, r.Y)
				end,
				Size = function(): UDim2
					const r = layout().Tabs[index]
					return UDim2.fromOffset(r.W, r.H)
				end,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				Visible = minimal,
				Selectable = true,
				Activated = function()
					props.OnTab(tab.Key)
				end,
				MouseEnter = function()
					hovered(true)
				end,
				MouseLeave = function()
					hovered(false)
					pressed(false)
				end,
				MouseButton1Down = function()
					pressed(true)
				end,
				MouseButton1Up = function()
					pressed(false)
				end,
				if SECTION_ICONS[tab.Key] ~= nil
					then sectionIcon(SECTION_ICONS[tab.Key], tab.Label, lit, called, hovered, pressed)
					else create("Frame")({
					Name = "Dot",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = function(): UDim2
						return if lit() then UDim2.fromOffset(dotActive, dotSize) else UDim2.fromOffset(dotSize, dotSize)
					end,
					BackgroundColor3 = function(): Color3
						return if lit() or called() then Theme.Color.Mustard else Theme.Color.Cream
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					createRaw("UIStroke")({
						Color = Theme.Color.Ink,
						Thickness = function(): number
							return if lit() then 3 else 2
						end,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				}),
				-- the call: a Mustard ring that breathes round the dot, and the mini flip bar under it (a shape, not only a colour)
				create("Frame")({
					Name = "CallRing",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = function(): UDim2
						const grow = 8 + 8 * pulse()
						return if lit()
							then UDim2.fromOffset(dotActive + grow, dotSize + grow)
							else UDim2.fromOffset(dotSize + grow, dotSize + grow)
					end,
					BackgroundTransparency = 1,
					Visible = called,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					createRaw("UIStroke")({
						Color = Theme.Color.Mustard,
						Thickness = 3,
						Transparency = function(): number
							return 0.55 * (1 - pulse())
						end,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				}),
				create("Frame")({
					Name = "CallBar",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0.5, dotSize / 2 + 6),
					Size = UDim2.fromOffset(30, 8),
					BackgroundColor3 = Theme.Color.Cream,
					ZIndex = 4,
					Visible = called,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					create("Frame")({
						Name = "Fill",
						Size = function(): UDim2
							const value = alertOf()
							return UDim2.fromScale(if value ~= false then math.max(value.Share, 0.12) else 0, 1)
						end,
						BackgroundColor3 = Theme.Color.Mustard,
						ZIndex = 5,
						create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					}),
				}),
				-- the count of what waits on this section
				create("Frame")({
					Name = "Badge",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0.5, -17),
					Size = UDim2.fromOffset(20, 20),
					BackgroundColor3 = tone.Bottom,
					ZIndex = 5,
					Visible = function()
						return badge() > 0
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					createRaw("UIStroke")({
						Color = Theme.Color.Ink,
						Thickness = 2,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					CartoonLabel({
						Text = function()
							return tostring(math.min(badge(), 99))
						end,
						TextSize = Theme.MinTextSize,
						Color = Theme.Color.Ink,
						Stroke = 0,
						Box = UDim2.fromScale(1, 1),
						XAlignment = Enum.TextXAlignment.Center,
						YAlignment = Enum.TextYAlignment.Center,
						ZIndex = 6,
					}),
				}),
				-- LB / RB walk the sections: the glyph sits on the first and the last dot (gamepad)
				if index == 1 or index == #tabs
					then padGlyph(if index == 1 then Enum.KeyCode.ButtonL1 else Enum.KeyCode.ButtonR1, if index == 1 then "LB" else "RB", function(): boolean
						return pad() and minimal()
					end)
					else nil,
			})
		)
	end

	-- the "Flip!" chip: above the transient pair (toast, hint), centred over the dot of the tab it calls back to (kept inside the canvas)
	const chip = CartoonButton({
		Name = "CallChip",
		Tone = Theme.Tone.Mustard,
		Radius = Theme.Radius.Pill,
		Position = function(): UDim2
			const l = layout()
			const value = alertOf()
			local at = 1
			if value ~= false then
				for index, tab in tabs do
					if tab.Key == value.Tab then
						at = index
					end
				end
			end
			const r = l.Tabs[at]
			const x = math.clamp(r.X + r.W / 2 - CHIP_W / 2, 8, math.max(l.Canvas.X - CHIP_W - 8, 8))
			return UDim2.fromOffset(x, l.Toast.Y - 6 - CHIP_H)
		end,
		Size = UDim2.fromOffset(CHIP_W, CHIP_H),
		Padding = 0,
		Selectable = true,
		Visible = alertOn,
		OnActivated = function()
			const value = alertOf()
			if value ~= false then
				props.OnTab(value.Tab)
			end
		end,
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			glyph("Ingredient/sausage", Theme.Color.Cream, 28),
			CartoonLabel({
				Name = "Text",
				Text = function(): string
					const value = alertOf()
					return if value ~= false then value.Text else ""
				end,
				TextSize = 18,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Box = UDim2.fromOffset(60, 28),
				XAlignment = Enum.TextXAlignment.Left,
				YAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 2,
			}),
		},
	})

	-- notch under the active tab (points at the board)
	const notch = create("Frame")({
		Name = "Notch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function(): UDim2
			const l = layout()
			const r = l.Tabs[activeIndex()]
			return UDim2.fromOffset(r.X + r.W / 2, r.Y + r.H - LIFT + 1)
		end,
		Size = UDim2.fromOffset(10, 10),
		Rotation = 45,
		BackgroundColor3 = Theme.Tone.Mustard.Bottom,
		ZIndex = 2,
		Visible = function(): boolean
			return not minimal()
		end,
		create("UICorner")({ CornerRadius = UDim.new(0, 2) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})

	-- status (money, sun / moon, clock) and the sanity strip
	const status = CartoonPanel({
		Name = "Status",
		Tone = Theme.Tone.Ink,
		Radius = Theme.Radius.Pill,
		Lip = 3,
		-- the minimal mode leaves money, clock and sun / moon to the Hud
		Visible = function(): boolean
			return not minimal()
		end,
		Position = at(function(l)
			return l.Status
		end),
		Size = sized(function(l)
			return l.Status
		end),
		Padding = { Left = 10, Right = 10 },
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 5),
			}),
			create("Frame")({
				Name = "Coin",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1,
				glyph("Hud/coin", Theme.Color.Mustard, 18),
			}),
			CartoonLabel({ LayoutOrder = 2, Name = "Cash", Text = function()
				return money(props.Cash())
			end, TextSize = 16 }),
			create("Frame")({
				Name = "Pad",
				LayoutOrder = 3,
				Size = UDim2.fromOffset(4, 1),
				BackgroundTransparency = 1,
			}),
			create("Frame")({
				Name = "Phase",
				LayoutOrder = 4,
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1,
				create("Frame")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Visible = function()
						return not props.IsNight()
					end,
					glyph("Hud/sun", Theme.Color.Gold, 18),
				}),
				create("Frame")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Visible = props.IsNight,
					glyph("Hud/moon", Theme.Color.Violet, 18),
				}),
			}),
			CartoonLabel({ LayoutOrder = 5, Name = "Clock", Text = props.Clock, TextSize = 16 }),
		},
	})

	const strip = create("Frame")({
		Name = "Sanity",
		Position = at(function(l)
			return l.Strip
		end),
		Size = sized(function(l)
			return l.Strip
		end),
		BackgroundColor3 = Theme.Tone.Ink.Bottom,
		Visible = function()
			const value = if props.Sanity ~= nil then props.Sanity() else nil
			return props.IsNight() and value ~= nil and not minimal()
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		create("Frame")({
			Name = "Fill",
			Size = function()
				const value = if props.Sanity ~= nil then props.Sanity() else nil
				return UDim2.fromScale(math.clamp(value or 0, 0, 1), 1)
			end,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIGradient")({ Color = ColorSequence.new(Theme.Color.Violet, Theme.Color.Gold) }),
		}),
		-- notches at 50 % and 25 % (the bar is read by shape, there is no number)
		create("Frame")({
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Theme.Color.Ink,
			BorderSizePixel = 0,
		}),
		create("Frame")({
			Position = UDim2.fromScale(0.25, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Theme.Color.Ink,
			BorderSizePixel = 0,
		}),
	})

	-- ticket slot
	const ticket = create("Frame")({
		Name = "Ticket",
		Position = at(function(l)
			return l.Ticket
		end),
		Size = sized(function(l)
			return l.Ticket
		end),
		BackgroundTransparency = 1,
		props.Slots.Ticket(layout),
	})

	-- board: header (pips + hint) and the Board slot
	const trashProgress = source(0)
	const pipRows = Vide.values(function(): { Pip }
		return if props.Pips ~= nil then props.Pips() else {}
	end, function(pip: Pip): Frame
		return create("Frame")({
			Name = `Pip_{pip.Label}`,
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
			}),
			Seal({
				LayoutOrder = 1,
				Size = 18,
				Grade = function()
					return pip.Grade
				end,
			}),
			CartoonLabel({
				LayoutOrder = 2,
				Text = pip.Label,
				TextSize = Theme.MinTextSize,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Visible = function()
					return layout().Board.W >= 440
				end,
			}),
		}) :: Frame
	end)
	const board = CartoonPanel({
		Name = "Board",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Card,
		Visible = function(): boolean
			return not minimal()
		end,
		Position = at(function(l)
			return l.Board
		end),
		Size = sized(function(l)
			return l.Board
		end),
		Children = {
			create("Frame")({
				Name = "Header",
				Position = UDim2.fromOffset(10, 0),
				Size = function(): UDim2
					return UDim2.new(1, -20, 0, layout().Header)
				end,
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),
				create("Frame")({
					Name = "Pips",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(0, 20),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					pipRows,
				}),
				CartoonLabel({
					LayoutOrder = 2,
					Name = "Hint",
					Text = function()
						return if trashProgress() > 0 then props.Trash.HoldText else props.Hint()
					end,
					TextSize = 16,
					Color = Theme.Color.Ink,
					Stroke = 0,
					Truncate = true,
					Box = function(): UDim2
						return UDim2.new(1, -(if props.Pips ~= nil and #untrack(props.Pips) > 0 then 140 else 0), 1, 0)
					end,
					XAlignment = Enum.TextXAlignment.Left,
					YAlignment = Enum.TextYAlignment.Center,
				}),
			}),
			create("Frame")({
				Name = "Content",
				Position = function(): UDim2
					return UDim2.fromOffset(8, layout().Header)
				end,
				Size = function(): UDim2
					return UDim2.new(1, -16, 1, -layout().Header - Theme.Lip - 4)
				end,
				BackgroundTransparency = 1,
				props.Slots.Board(layout),
			}),
		},
	})

	-- panel slot (ingredients)
	const panel = create("Frame")({
		Name = "Panel",
		Position = at(function(l)
			return l.Panel
		end),
		Size = sized(function(l)
			return l.Panel
		end),
		BackgroundTransparency = 1,
		Visible = function(): boolean
			return props.HasPanel() and not minimal()
		end,
		if props.Slots.Panel ~= nil then props.Slots.Panel(layout) else nil,
	})

	-- Next / Serve
	const nextShake, nextKick = shaker()
	const pulseUp = source(false)
	local pulseThread: thread? = nil
	effect(function()
		if props.Next.Pulse ~= nil and props.Next.Pulse() and not reduced then
			untrack(function()
				if pulseThread ~= nil and coroutine.status(pulseThread) == "suspended" then
					task.cancel(pulseThread)
				end
				pulseThread = task.spawn(function()
					for _ = 1, PULSES do
						pulseUp(true)
						task.wait(PULSE_TIME)
						pulseUp(false)
						task.wait(PULSE_TIME)
					end
				end)
				return nil
			end)
		end
	end)
	cleanup(function()
		if pulseThread ~= nil and coroutine.status(pulseThread) == "suspended" then
			task.cancel(pulseThread)
		end
	end)
	const pulseScale = Vide.spring(function(): number
		return if pulseUp() then 1.06 else 1
	end, 0.2, 0.6)
	const nextButton = CartoonButton({
		Name = "Next",
		Tone = Theme.Tone.Mustard,
		Enabled = props.Next.Enabled,
		Outline = function()
			return if reduced and props.Next.Pulse ~= nil and props.Next.Pulse() then Theme.Outline.Thick + 1 else Theme.Outline.Thick
		end,
		Size = UDim2.fromScale(1, 1),
		Padding = 0,
		OnActivated = props.Next.OnPress,
		Children = {
			CartoonLabel({
				Text = props.Next.Label,
				TextSize = 20,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Box = UDim2.fromScale(1, 1),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})
	-- the holder pulses (UIScale about its centre) and shakes; the button and the blocker live in it
	const nextHolder = create("Frame")({
		Name = "NextHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function(): UDim2
			const r = layout().Next
			return UDim2.fromOffset(r.X + r.W / 2 + nextShake(), r.Y + r.H / 2)
		end,
		Size = sized(function(l)
			return l.Next
		end),
		BackgroundTransparency = 1,
		createRaw("UIScale")({ Scale = pulseScale }),
		nextButton,
		padGlyph(Enum.KeyCode.ButtonY, "Y", pad),
	})
	-- a tap on the disabled button: shake and tell the owner (the hint says why)
	const blocker = create("TextButton")({
		Name = "NextBlocked",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 8,
		Visible = function()
			return not props.Next.Enabled()
		end,
		Activated = function()
			nextKick()
			if props.Next.OnBlocked ~= nil then
				props.Next.OnBlocked()
			end
		end,
	})
	blocker.Parent = nextHolder
	-- the gamepad cursor presses Next (or its blocker) through Pointer.HitPress, which reads this on the hit object or an ancestor
	nextHolder:SetAttribute("PrepPress", "Next")

	-- trash: hold to discard
	const trash = CartoonButton({
		Name = "Trash",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Pill,
		Position = at(function(l)
			return l.Trash
		end),
		Size = sized(function(l)
			return l.Trash
		end),
		Padding = 0,
		Visible = function(): boolean
			return props.Trash.Visible() and not minimal()
		end,
		Children = {
			-- the Green fill that rises while the hold runs
			create("Frame")({
				Name = "Fill",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = function()
					return UDim2.fromScale(1, trashProgress())
				end,
				BackgroundColor3 = Theme.Tone.Green.Bottom,
				BorderSizePixel = 0,
				Visible = function()
					return trashProgress() > 0
				end,
			}),
			binGlyph(),
		},
	})
	const holding = source(false)
	local holdThread: thread? = nil
	local function stopHold()
		holding(false)
		if holdThread ~= nil and coroutine.status(holdThread) == "suspended" then
			task.cancel(holdThread)
		end
		holdThread = nil
		trashProgress(0)
	end
	local function startHold()
		stopHold()
		holding(true)
		holdThread = task.spawn(function()
			const start = os.clock()
			while true do
				const t = (os.clock() - start) / math.max(props.Trash.Hold, 0.05)
				if t >= 1 then
					break
				end
				trashProgress(math.max(t, 0.02))
				task.wait()
			end
			holdThread = nil
			holding(false)
			trashProgress(0)
			props.Trash.OnTrash()
		end)
	end
	const trashBegan = trash.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			startHold()
		end
	end)
	const trashEnded = trash.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			stopHold()
		end
	end)
	const trashLeft = trash.MouseLeave:Connect(stopHold)
	cleanup(function()
		trashBegan:Disconnect()
		trashEnded:Disconnect()
		trashLeft:Disconnect()
		stopHold()
	end)
	-- the hold ends when the bin goes away
	effect(function()
		if not props.Trash.Visible() then
			untrack(stopHold)
		end
	end)

	-- assist toggle: a round chip inside the pill (radius = pill height / 2 - pad, so its corners follow the pill), a target glyph
	const assist = CartoonButton({
		Name = "Assist",
		-- owner decision 2026-10-14: no Assist chip in the chrome (the aim tolerance stays at 1); the toggle code is kept, hidden
		Visible = function(): boolean
			return false
		end,
		Tone = function()
			return if props.Assist.On() then Theme.Tone.Teal else Theme.Tone.Cream
		end,
		Outline = function()
			return if props.Assist.On() then Theme.Outline.Thick else Theme.Outline.Normal
		end,
		Radius = Theme.Radius.Pill,
		Position = at(function(l)
			return l.Assist
		end),
		Size = sized(function(l)
			return l.Assist
		end),
		Padding = 0,
		OnActivated = props.Assist.OnToggle,
		Children = {
			assistGlyph(),
			-- on: a Green dot on the rim (a mark, not just a tone)
			create("Frame")({
				Name = "On",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.85, 0.15),
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = Theme.Tone.Green.Bottom,
				ZIndex = 5,
				Visible = props.Assist.On,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			}),
		},
	})

	-- tap mode ("tap and tap"): a chip next to Assist, only when the owner offers it (minimal mode)
	const tapProps = props.TapMode
	const tapChip = if tapProps ~= nil
		then CartoonButton({
			Name = "TapMode",
			Tone = function()
				return if tapProps.On() then Theme.Tone.Teal else Theme.Tone.Cream
			end,
			Outline = function()
				return if tapProps.On() then Theme.Outline.Thick else Theme.Outline.Normal
			end,
			Radius = Theme.Radius.Pill,
			Position = atMini(function(m)
				return m.Tap
			end),
			Size = sizedMini(function(m)
				return m.Tap
			end),
			Padding = 0,
			Visible = minimal,
			OnActivated = tapProps.OnToggle,
			Children = {
				CartoonLabel({
					Text = tapProps.Label,
					TextSize = Theme.MinTextSize,
					Color = Theme.Color.Ink,
					Stroke = 0,
					Box = UDim2.fromScale(1, 1),
					XAlignment = Enum.TextXAlignment.Center,
					YAlignment = Enum.TextYAlignment.Center,
				}),
				create("Frame")({
					Name = "On",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, -2),
					Size = UDim2.fromOffset(12, 12),
					BackgroundColor3 = Theme.Tone.Green.Bottom,
					ZIndex = 5,
					Visible = tapProps.On,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				}),
			},
		})
		else nil

	-- progress card (minimal mode, top centre): the verb of the section, the three grade pips, a 10 px bar with one division per
	-- section. It is a level, read by shape (the divisions) and by the label, not by colour.
	const progressProps = props.Progress
	const divisions: { Frame } = {}
	for index = 1, #tabs - 1 do
		table.insert(
			divisions,
			create("Frame")({
				Name = `Division{index}`,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(index / #tabs, 0),
				Size = UDim2.new(0, 2, 1, 0),
				BackgroundColor3 = Theme.Color.Ink,
				BorderSizePixel = 0,
			})
		)
	end
	-- the live note (U-3): a seal of the band of the mean and the number that rolls to it, the Perfects in a row beside it
	const noteOf = function(): Note?
		return if props.Note ~= nil then props.Note() else nil
	end
	const shownNote = Motion.Count(function(): number
		const value = noteOf()
		return if value ~= nil then value.Score else 0
	end, 0.35)
	const streakOf = function(): number
		return if props.Streak ~= nil then props.Streak() else 0
	end
	const stepOf = function(): Objective.Card?
		const value = objectiveCard()
		return if value ~= false then value else nil
	end
	local function stepText(pick: (Objective.Card) -> string): () -> string
		return function(): string
			const value = stepOf()
			return if value ~= nil then pick(value) else ""
		end
	end
	const hasStep = function(): boolean
		return stepOf() ~= nil
	end
	-- the live note (seal, number, streak): one block, used by both shapes of the card
	local function noteBlock(): Frame
		return create("Frame")({
			Name = "Note",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			-- Perfects in a row: a small Mustard chip from two
			create("Frame")({
				Name = "Streak",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(0, 20),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Color.Mustard,
				Visible = function(): boolean
					return streakOf() >= 2
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				createRaw("UIPadding")({ PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
				CartoonLabel({
					Text = function(): string
						return `x{streakOf()}`
					end,
					TextSize = Theme.MinTextSize,
					Color = Theme.Color.Ink,
					Stroke = 0,
					YAlignment = Enum.TextYAlignment.Center,
					Box = UDim2.fromOffset(0, 20),
					AutomaticSize = Enum.AutomaticSize.X,
				}),
			}),
			Seal({
				LayoutOrder = 2,
				Size = 22,
				Grade = function(): Seal.Grade?
					const value = noteOf()
					return if value ~= nil then value.Grade else nil
				end,
			}),
			CartoonLabel({
				LayoutOrder = 3,
				Name = "Score",
				Text = function(): string
					return if noteOf() ~= nil then tostring(math.floor(shownNote() + 0.5)) else "--"
				end,
				TextSize = 20,
				Color = Theme.Color.Ink,
				Stroke = 0,
				YAlignment = Enum.TextYAlignment.Center,
				Box = UDim2.fromOffset(28, 24),
				XAlignment = Enum.TextXAlignment.Right,
			}),
		}) :: Frame
	end
	const progressCard = if SHOW_PROGRESS and progressProps ~= nil
		then CartoonPanel({
			Name = "Progress",
			Tone = function(): Theme.Tone
				const value = stepOf()
				return if value ~= nil and value.Urgent then Theme.Tone.Mustard else Theme.Tone.Cream
			end,
			Radius = Theme.Radius.Card,
			Lip = 3,
			Visible = minimal,
			Position = atMini(function(m)
				return m.Progress
			end),
			Size = sizedMini(function(m)
				return m.Progress
			end),
			Padding = { Left = 10, Right = 10, Top = 2, Bottom = 2 },
			Children = {
				-- plain card: the verb of the section on the left, the note on the right
				create("Frame")({
					Name = "Row",
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Visible = function(): boolean
						return not hasStep()
					end,
					CartoonLabel({
						Name = "Verb",
						Text = progressProps.Label,
						TextSize = 16,
						Color = Theme.Color.Ink,
						Stroke = 0,
						Truncate = true,
						Box = UDim2.new(0.5, 0, 1, 0),
						XAlignment = Enum.TextXAlignment.Left,
						YAlignment = Enum.TextYAlignment.Center,
					}),
					noteBlock(),
				}),
				-- tutorial card: step chip, the objective, its hint, the note (the tutorial banner is hidden meanwhile)
				create("Frame")({
					Name = "Step",
					Size = UDim2.new(1, 0, 0, 40),
					BackgroundTransparency = 1,
					Visible = hasStep,
					CartoonPanel({
						Name = "Chip",
						Position = UDim2.fromOffset(0, 1),
						Size = function(): UDim2
							const value = stepOf()
							return UDim2.fromOffset(if value ~= nil and value.Total >= 10 then 46 else 38, 30)
						end,
						Tone = function(): Theme.Tone
							const value = stepOf()
							return if value ~= nil and value.Done then Theme.Tone.Green else Theme.Tone.Mustard
						end,
						Outline = Theme.Outline.Normal,
						Lip = 3,
						Gloss = false,
						Children = {
							CartoonLabel({
								Box = UDim2.fromScale(1, 1),
								TextSize = Theme.MinTextSize,
								Color = Theme.Color.Dark,
								Stroke = 0,
								XAlignment = Enum.TextXAlignment.Center,
								YAlignment = Enum.TextYAlignment.Center,
								Text = function(): string
									const value = stepOf()
									return if value ~= nil then (if value.Done then "OK" else `{value.Step}/{value.Total}`) else ""
								end,
							}),
						},
					}),
					CartoonLabel({
						Name = "Title",
						Position = UDim2.fromOffset(52, 0),
						Box = function(): UDim2
							-- leaves the room of the note on the right once the first stage was graded
							return UDim2.new(1, -52 - (if noteOf() ~= nil then 70 else 0), 0, 20)
						end,
						Text = stepText(function(value)
							return value.Text
						end),
						TextSize = 16,
						Color = Theme.Color.Ink,
						Stroke = 0,
						Truncate = true,
						XAlignment = Enum.TextXAlignment.Left,
						YAlignment = Enum.TextYAlignment.Center,
					}),
					CartoonLabel({
						Name = "Hint",
						Position = UDim2.fromOffset(52, 23),
						Box = UDim2.new(1, -52, 0, 16),
						Text = stepText(function(value)
							return value.Hint
						end),
						TextSize = Theme.MinTextSize,
						Color = Theme.Tone.Ink.Top,
						Stroke = 0,
						Truncate = true,
						XAlignment = Enum.TextXAlignment.Left,
						YAlignment = Enum.TextYAlignment.Center,
					}),
					noteBlock(),
				}),
				create("Frame")({
					Name = "Bar",
					Position = function(): UDim2
						return UDim2.fromOffset(0, if hasStep() then 42 else 27)
					end,
					Size = UDim2.new(1, 0, 0, 10),
					BackgroundColor3 = Theme.Tone.Cream.Bottom,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					create("Frame")({
						Name = "Fill",
						Size = function(): UDim2
							return UDim2.fromScale(math.clamp(progressProps.Value(), 0, 1), 1)
						end,
						BackgroundColor3 = Theme.Tone.Mustard.Bottom,
						BorderSizePixel = 0,
						create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					}),
					-- one division per section
					divisions,
				}),
			},
		})
		else nil

	-- Skip of the tutorial step: a pill beside the card (44 px tall touch target, with the key of the device)
	const skipPill = CartoonButton({
		Name = "Skip",
		Tone = Theme.Tone.White,
		Radius = Theme.Radius.Pill,
		Position = atMini(function(m)
			return m.Skip
		end),
		Size = sizedMini(function(m)
			return m.Skip
		end),
		Padding = 0,
		Selectable = false,
		Visible = function(): boolean
			const value = stepOf()
			return minimal() and value ~= nil and value.SkipText ~= ""
		end,
		OnActivated = function()
			if props.OnSkip ~= nil then
				props.OnSkip()
			end
		end,
		Children = {
			CartoonLabel({
				Text = stepText(function(value)
					return value.SkipText
				end),
				TextSize = Theme.MinTextSize,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Box = UDim2.fromScale(1, 1),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})

	-- the gamepad buttons of the step (TASK-268): up to PAD_KEYS chips over the hint pill, platform button art + a word
	const padKeys = function(): { PadKey }
		return if pad() and props.PadKeys ~= nil then props.PadKeys() else {}
	end
	const padChips: { any } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	}
	for index = 1, PAD_KEYS do
		const row = function(): PadKey?
			return padKeys()[index]
		end
		table.insert(
			padChips,
			create("Frame")({
				Name = `PadKey{index}`,
				LayoutOrder = index,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				BackgroundTransparency = 1,
				Visible = function(): boolean
					return row() ~= nil
				end,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				create("ImageLabel")({
					Name = "Button",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(24, 24),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					Image = function(): string
						const current = row()
						return if current ~= nil then padImage(current.Key) else ""
					end,
				}),
				CartoonLabel({
					Name = "Label",
					LayoutOrder = 2,
					TextSize = 14,
					Text = function(): string
						const current = row()
						if current == nil then
							return ""
						end
						-- no button art on this platform: the button name goes before the word
						return if padImage(current.Key) == "" then `{current.Key.Name}: {current.Text}` else current.Text
					end,
					XAlignment = Enum.TextXAlignment.Left,
					YAlignment = Enum.TextYAlignment.Center,
				}),
			})
		)
	end

	-- one line of hint above the tabs (minimal mode)
	const hintPill = CartoonPanel({
		Name = "Hint",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Pill,
		Lip = 3,
		Visible = function(): boolean
			-- the toast takes this same slot while it is up (owner 2026-10-17: two stacked strips covered the counter on a phone)
			return minimal() and props.Hint() ~= "" and props.Toast() == nil
		end,
		Position = atMini(function(m)
			return m.Hint
		end),
		Size = sizedMini(function(m)
			return m.Hint
		end),
		Padding = { Left = 10, Right = 10 },
		Children = {
			CartoonLabel({
				Name = "Text",
				Text = props.Hint,
				TextSize = 16,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Truncate = true,
				Box = UDim2.fromScale(1, 1),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
			}),
			create("Frame")({
				Name = "PadKeys",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -6),
				Size = UDim2.new(1, 40, 0, 26),
				BackgroundTransparency = 1,
				Visible = function(): boolean
					return #padKeys() > 0
				end,
				padChips,
			}),
		},
	})

	-- the seal of the finished plate (transient, minimal mode): shape + colour + word
	const sealGrade = props.Seal
	const sealCount = Motion.Count(function(): number
		return if sealGrade ~= nil and sealGrade() ~= nil and props.SealScore ~= nil then props.SealScore() else 0
	end, 0.6)
	const sealHolder = if sealGrade ~= nil
		then create("Frame")({
			Name = "Seal",
			Position = atMini(function(m)
				return m.Seal
			end),
			Size = sizedMini(function(m)
				return m.Seal
			end),
			BackgroundTransparency = 1,
			Visible = function(): boolean
				return minimal() and sealGrade() ~= nil
			end,
			Seal({
				Name = "PlateSeal",
				Size = 96,
				Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				Grade = sealGrade,
				Label = props.SealLabel,
			}),
			-- the grade counter: rolls from 0 to the mean of the stages in 0.6 s
			CartoonLabel({
				Name = "SealScore",
				Text = function(): string
					return tostring(math.floor(sealCount() + 0.5))
				end,
				TextSize = 28,
				Color = Theme.Color.Cream,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 98),
				Box = UDim2.fromOffset(96, 26),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
			}),
		})
		else nil

	-- the bin zone (minimal mode): a toy bin in a card, only while something can be dragged. Closed lid at rest, open lid and a Mustard
	-- card while a dragged item is inside, a bounce when it swallows. Native Frames (a rounded body, a stripe, a hinged lid).
	const binProps = props.Bin
	local binZone: Frame? = nil
	if binProps ~= nil then
		const binWanted = binProps.Wanted
		const binOver = binProps.Over
		const binPop = Motion.Pop(function(): boolean
			return minimal() and binWanted()
		end)
		const lidOpen = Vide.spring(function(): number
			return if binOver() then 1 else 0
		end, 0.16, 0.6)
		const bounce = Motion.Bump(binProps.Chomp, 1.12, 0.18)
		const lid = create("Frame")({
			Name = "Lid",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromOffset(0, 12),
			Size = UDim2.fromOffset(40, 9),
			BackgroundColor3 = Theme.Tone.Mustard.Bottom,
			Rotation = function(): number
				return if reduced then (if binOver() then -38 else 0) else -38 * math.clamp(lidOpen(), 0, 1.2)
			end,
			ZIndex = 3,
			create("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			create("Frame")({
				Name = "Handle",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(14, 4),
				BackgroundColor3 = Theme.Color.Ink,
				BorderSizePixel = 0,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
		})
		const icon = create("Frame")({
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(40, 42),
			BackgroundTransparency = 1,
			-- the body: Teal, a Cream stripe
			create("Frame")({
				Name = "Body",
				Position = UDim2.fromOffset(3, 13),
				Size = UDim2.fromOffset(34, 28),
				BackgroundColor3 = Theme.Tone.Teal.Bottom,
				create("UICorner")({ CornerRadius = UDim.new(0, 7) }),
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				create("Frame")({
					Name = "Stripe",
					Position = UDim2.fromOffset(0, 9),
					Size = UDim2.new(1, 0, 0, 7),
					BackgroundColor3 = Theme.Color.Cream,
					BorderSizePixel = 0,
				}),
			}),
			lid,
		})
		binZone = CartoonPanel({
			Name = "Bin",
			Tone = function(): Theme.Tone
				return if binOver() then Theme.Tone.Mustard else Theme.Tone.Cream
			end,
			Radius = Theme.Radius.Card,
			Lip = 3,
			Outline = function(): number
				return if binOver() then Theme.Outline.Thick else Theme.Outline.Normal
			end,
			Visible = function(): boolean
				return minimal() and (binWanted() or binPop() > 0.02)
			end,
			Position = atMini(function(m)
				return m.Bin
			end),
			Size = sizedMini(function(m)
				return m.Bin
			end),
			Decor = {
				createRaw("UIScale")({
					Scale = function(): number
						const grow = if binOver() then 1.08 else 1
						return if reduced then 1 else math.max(binPop(), 0) * grow * bounce()
					end,
				}),
			},
			Children = {
				icon,
				CartoonLabel({
					Name = "Label",
					Text = binProps.Label,
					TextSize = Theme.MinTextSize,
					Color = Theme.Color.Ink,
					Stroke = 0,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -2),
					Box = UDim2.new(1, 0, 0, 18),
					XAlignment = Enum.TextXAlignment.Center,
					YAlignment = Enum.TextYAlignment.Center,
				}),
			},
		})
		-- hand the world the way to test a point (raw viewport px: the gui origin plus the inset) and the centre of the zone
		const zoneFrame: Frame = binZone :: Frame
		local function viewportRect(): (Vector2, Vector2)
			const inset = GuiService:GetGuiInset()
			return zoneFrame.AbsolutePosition + inset, zoneFrame.AbsoluteSize
		end
		binProps.Bind(function(point: Vector2): boolean
			if not zoneFrame.Visible or zoneFrame.AbsoluteSize.X <= 0 then
				return false
			end
			const origin, size = viewportRect()
			-- a forgiving edge: 10 px all round (the zone is 72 px, the thumb is not)
			return point.X >= origin.X - 10 and point.X <= origin.X + size.X + 10 and point.Y >= origin.Y - 10 and point.Y <= origin.Y + size.Y + 10
		end, function(): Vector2?
			if zoneFrame.AbsoluteSize.X <= 0 then
				return nil
			end
			const origin, size = viewportRect()
			return origin + size / 2
		end)
		cleanup(function()
			binProps.Bind(nil, nil)
		end)
	end

	-- toast: one at a time, bottom centre
	const toastShown = function(): boolean
		return props.Toast() ~= nil
	end
	const toastPop = Motion.Pop(toastShown)
	const toast = CartoonPanel({
		Name = "Toast",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Pill,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function(): UDim2
			const r = layout().Toast
			return UDim2.fromOffset(r.X + r.W / 2, r.Y + r.H / 2)
		end,
		Size = sized(function(l)
			return l.Toast
		end),
		Visible = function()
			return toastShown() or toastPop() > 0.02
		end,
		Padding = { Left = 10, Right = 10 },
		Decor = {
			createRaw("UIScale")({
				Scale = function()
					return if reduced then 1 else math.max(toastPop(), 0)
				end,
			}),
		},
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			-- kind mark: Info Teal disc, Good Green disc, Alert Mustard diamond
			create("Frame")({
				Name = "Mark",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(14, 14),
				Rotation = function()
					const value = props.Toast()
					return if value ~= nil and value.Kind == "Alert" then 45 else 0
				end,
				BackgroundColor3 = function()
					const value = props.Toast()
					const kind = if value ~= nil then value.Kind else "Info"
					return if kind == "Good" then Theme.Tone.Green.Bottom elseif kind == "Alert" then Theme.Color.Mustard else Theme.Tone.Teal.Bottom
				end,
				create("UICorner")({
					CornerRadius = function()
						const value = props.Toast()
						return if value ~= nil and value.Kind == "Alert" then UDim.new(0, 2) else UDim.new(0.5, 0)
					end,
				}),
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			}),
			CartoonLabel({
				LayoutOrder = 2,
				Text = function()
					const value = props.Toast()
					return if value ~= nil then value.Text else ""
				end,
				TextSize = 16,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Wrapped = true,
				Truncate = true,
				Box = UDim2.new(1, -24, 1, 0),
				XAlignment = Enum.TextXAlignment.Left,
				YAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})

	-- edge vignette: the fallback of a camera without depth of field
	const vignette = Vignette({
		Strength = function()
			return if props.Vignette ~= nil and props.Vignette() then VIGNETTE else 0
		end,
		Color = Theme.Color.Ink,
		Name = "Vignette",
	})

	-- the canvas (UI scale) with the pop of entering / leaving around its centre
	const canvasFrame = create("Frame")({
		Name = "Canvas",
		Size = function(): UDim2
			const size = canvas()
			return UDim2.fromOffset(size.X, size.Y)
		end,
		BackgroundTransparency = 1,
		Visible = function()
			return shown() or pop() > 0.02
		end,
		createRaw("UIScale")({ Scale = scale }),
		create("Frame")({
			Name = "Pop",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			createRaw("UIScale")({
				Scale = function()
					return if reduced then 1 else 0.92 + 0.08 * math.clamp(pop(), 0, 1.15)
				end,
			}),
			ticket,
			board,
			panel,
			notch,
			pill,
			leave,
			tabButtons,
			dotButtons,
			chip,
			status,
			strip,
			nextHolder,
			trash,
			binZone,
			assist,
			tapChip,
			progressCard,
			skipPill,
			hintPill,
			sealHolder,
			toast,
		}),
	})

	vignette.Parent = root
	canvasFrame.Parent = root
	return root
end
