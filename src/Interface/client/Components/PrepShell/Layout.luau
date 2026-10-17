--!strict
-- PrepShell/Layout: where every block of the focused prep mode goes (docs/art/prep-ui-spec.md §4). Pure: a canvas size in
-- UI px (the ScreenGui area divided by the global UI scale) in, rectangles out. Three shapes:
--   Phone    landscape, canvas height < DESKTOP_MIN_H (844 x 390 is the design size; 667 x 375 is the floor and must fit too)
--   Desktop  landscape, canvas height >= DESKTOP_MIN_H (about 1371 x 771 at 1280 x 720)
--   Portrait canvas narrower than tall (about 358 x 774)
-- The spec tables are for the design sizes; on other sizes the same rules apply (anchored to the edges, the board takes the
-- rest) and the numbers land on the spec at the design sizes. No block overlaps another (spec §4 "Sem sobreposição").
-- Provisional: all numbers come from the art-director spec.

export type Rect = { X: number, Y: number, W: number, H: number }

export type Kind = "Phone" | "Desktop" | "Portrait"

-- Rectangles of the minimal 3D mode (docs/tech/prep-3d.md §5, TASK-199): the world is the minigame, only a thin progress
-- card on top, the section tabs and the buttons at the bottom, the ticket on the left. `HudStatus`, `HudSanity` and
-- `RobloxMenu` are NOT ours: they are the zones the Hud (money, clock, sanity) and the Roblox menu own, kept free.
-- (HudScreen: the clock pill is top CENTRE, the day and money pills top right; HudSanity: top left under the Roblox bar, at night.)
-- `Center` is the world: nothing of ours but the transient hint / toast / seal may enter it.
export type Mini = {
	Progress: Rect,
	-- the Skip pill of the tutorial step beside the progress card (zero without a step)
	Skip: Rect,
	Hint: Rect,
	Seal: Rect,
	Tap: Rect,
	-- the one pill that holds Leave, Assist (and Tap when it is offered), bottom left (polish 2026-10-12, U-2)
	Pill: Rect,
	-- px of Ink between the pill edge and its chips
	PillPad: number,
	-- the bin zone: the 2D drop target of a dragged item (shown only while something can be dragged), above Next
	Bin: Rect,
	HudStatus: Rect,
	HudClock: Rect,
	HudSanity: Rect,
	RobloxMenu: Rect,
	Center: Rect,
}

-- What the owner knows about the screen: `Taps` = the Tap chip is offered, `Objective` = the card carries a tutorial step (and the Skip
-- pill), `Reserved` = rectangles (canvas px) of transient overlays that the hint and the toast keep off.
-- `Sanity` = the sanity meter of the Hud is up (night): the ticket starts under it, else right under the Roblox menu.
export type Options = { Taps: boolean?, Objective: boolean?, Reserved: { Rect }?, Sanity: boolean? }

export type Result = {
	Kind: Kind,
	Canvas: Vector2,
	-- the ticket is a one-row strip (portrait) instead of a card
	TicketStrip: boolean,
	-- the leave button carries a word ("Leave"), desktop only
	LeaveWide: boolean,
	-- only the active tab shows its label, the others a short mark (portrait)
	TabsCompact: boolean,
	Bar: Rect,
	Leave: Rect,
	Tabs: { Rect },
	Status: Rect,
	Strip: Rect,
	Ticket: Rect,
	Peers: Rect,
	Board: Rect,
	Panel: Rect,
	-- ingredient grid of the panel: columns, rows, box side (px)
	Cols: number,
	Rows: number,
	Box: number,
	Next: Rect,
	Trash: Rect,
	Assist: Rect,
	Toast: Rect,
	-- height of the board header (pips + hint)
	Header: number,
	-- the minimal 3D mode; nil = the 2D chrome (board, panel, trash)
	Mini: Mini?,
	-- the tab of each index shows its label (the active one) or only its icon (the others)
	TabsIconOnly: boolean,
}

const MARGIN = 12
-- canvas height (UI px) from which the landscape layout is the desktop one. A phone at the touch scale 0.8 (Theme) has a
-- 470..540 px canvas, so it must stay under this (was 520, 2026-10-17)
const DESKTOP_MIN_H = 560
const TAB_GAP = 6
const TOUCH = 44
-- Ink border of the pill that holds Leave / Assist / Tap; the round chips inside have radius height / 2 - PILL_PAD
const PILL_PAD = 5

local function rect(x: number, y: number, w: number, h: number): Rect
	return { X = math.floor(x + 0.5), Y = math.floor(y + 0.5), W = math.floor(w + 0.5), H = math.floor(h + 0.5) }
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H
end

-- Tab rectangles of a bar: `first` = x of the first tab, equal widths.
local function equalTabs(count: number, first: number, y: number, width: number, height: number, gap: number): { Rect }
	const tabs: { Rect } = {}
	for index = 1, count do
		table.insert(tabs, rect(first + (index - 1) * (width + gap), y, width, height))
	end
	return tabs
end

local function phone(canvas: Vector2, hasPanel: boolean, count: number): Result
	const w, h = canvas.X, canvas.Y
	const statusW = 156
	const status = rect(w - MARGIN - statusW, 10, statusW, 32)
	-- the Roblox menu / chat cluster owns the top left on a phone (about 110 px)
	const reserve = 112
	const limit = status.X - 8
	const barW = math.min(486, limit - reserve)
	const barX = reserve + (limit - reserve - barW) / 2
	const tabW = math.min(104, math.floor((barW - TOUCH - TAB_GAP - (count - 1) * TAB_GAP) / count))
	const nextW, nextH = 132, 52
	const next = rect(w - MARGIN - nextW, h - MARGIN - nextH, nextW, nextH)
	const panelW = 150
	const panelH = math.min(246, next.Y - 6 - 60)
	const boxes = math.min(64, math.floor((panelH - 22 - 16 - 2 * 6) / 3))
	const boardW = w - 352
	const boardH = h - 134
	const boardX = if hasPanel then 176 else (w + 152) / 2 - boardW / 2
	const assist = rect(next.X - 8 - TOUCH, h - MARGIN - TOUCH, TOUCH, TOUCH)
	-- between the bin and the assist toggle, centred when it fits
	const toastW = math.min(320, assist.X - 8 - 76)
	const toastX = math.clamp(w / 2 - toastW / 2, 76, assist.X - 8 - toastW)
	return {
		Kind = "Phone",
		Canvas = canvas,
		TicketStrip = false,
		LeaveWide = false,
		TabsCompact = false,
		TabsIconOnly = false,
		Bar = rect(barX, 8, barW, 48),
		Leave = rect(barX, 10, TOUCH, TOUCH),
		Tabs = equalTabs(count, barX + TOUCH + TAB_GAP, 10, tabW, TOUCH, TAB_GAP),
		Status = status,
		Strip = rect(status.X, 46, statusW, 10),
		Ticket = rect(MARGIN, 60, 152, 140),
		Peers = rect(MARGIN, 208, 132, 36),
		Board = rect(boardX, 60, boardW, boardH),
		Panel = rect(w - MARGIN - panelW, 60, panelW, panelH),
		Cols = 2,
		Rows = 3,
		Box = boxes,
		Next = next,
		Trash = rect(MARGIN, h - 68, 56, 56),
		Assist = assist,
		Toast = rect(toastX, h - 54, toastW, 32),
		Header = 28,
	}
end

local function desktop(canvas: Vector2, hasPanel: boolean, count: number): Result
	const w, h = canvas.X, canvas.Y
	const margin = 16
	const statusW = 196
	const status = rect(w - margin - statusW, 14, statusW, 36)
	const leaveW, tabW, gap = 96, 128, 8
	const barW = leaveW + gap + count * tabW + (count - 1) * gap
	const barX = (w - barW) / 2
	const next = rect(w - margin - 152, h - 75, 152, 56)
	const panelW = 168
	const panelX = w - margin - panelW
	const left = 16 + 184 + 16
	const right = if hasPanel then panelX - 16 else w - margin
	const boardW = math.min(780, right - left)
	const boardH = math.min(480, h - 84 - 120)
	const assist = rect(next.X - 8 - TOUCH, h - margin - TOUCH, TOUCH, TOUCH)
	return {
		Kind = "Desktop",
		Canvas = canvas,
		TicketStrip = false,
		LeaveWide = true,
		TabsCompact = false,
		TabsIconOnly = false,
		Bar = rect(barX, 12, barW, 52),
		Leave = rect(barX, 14, leaveW, 48),
		Tabs = equalTabs(count, barX + leaveW + gap, 14, tabW, 48, gap),
		Status = status,
		Strip = rect(status.X, 54, statusW, 10),
		Ticket = rect(margin, 84, 184, 152),
		Peers = rect(margin, 244, 140, 40),
		Board = rect((left + right) / 2 - boardW / 2, 84, boardW, boardH),
		Panel = rect(panelX, 84, panelW, 260),
		Cols = 2,
		Rows = 3,
		Box = 72,
		Next = next,
		Trash = rect(margin, h - 79, 60, 60),
		Assist = assist,
		Toast = rect(w / 2 - 180, h - 67, 360, 36),
		Header = 36,
	}
end

local function portrait(canvas: Vector2, hasPanel: boolean, count: number): Result
	const w, h = canvas.X, canvas.Y
	const status = rect(w - MARGIN - 170, 14, 170, 32)
	const next = rect(w - MARGIN - 132, h - 98, 132, 54)
	const panelH = 176
	const panelY = next.Y - 14 - panelH
	-- the assist toggle sits above the Next button (the bottom row is Trash, the colleagues' chips and Next)
	const assist = rect(w - MARGIN - TOUCH, next.Y - 8 - TOUCH, TOUCH, TOUCH)
	const boardBottom = if hasPanel then panelY - 8 else assist.Y - 8
	-- Leave 44, the active tab 100, the other tabs 48 (a short mark); the active index is applied by the shell
	const tabs: { Rect } = {}
	for index = 1, count do
		table.insert(tabs, rect(MARGIN + TOUCH + TAB_GAP + (index - 1) * (48 + TAB_GAP), 64, 48, 48))
	end
	return {
		Kind = "Portrait",
		Canvas = canvas,
		TicketStrip = true,
		LeaveWide = false,
		TabsCompact = true,
		TabsIconOnly = false,
		Bar = rect(MARGIN, 64, w - 2 * MARGIN, 48),
		Leave = rect(MARGIN, 66, TOUCH, TOUCH),
		Tabs = tabs,
		Status = status,
		Strip = rect(status.X, 50, status.W, 10),
		Ticket = rect(MARGIN, 120, w - 2 * MARGIN, 82),
		Peers = rect(80, h - 90, 120, 36),
		Board = rect(MARGIN, 210, w - 2 * MARGIN, boardBottom - 210),
		Panel = rect((w - 224) / 2, panelY, 224, panelH),
		Cols = 3,
		Rows = 2,
		Box = 64,
		Next = next,
		Trash = rect(MARGIN, next.Y, 54, 54),
		Assist = assist,
		-- the spec puts it on the colleagues' chips, which overlaps Next: between the bin and Next instead (two lines, 44 high)
		Toast = rect(MARGIN + 54 + 8, next.Y + 5, next.X - 8 - (MARGIN + 54 + 8), 44),
		Header = 28,
	}
end

-- Variable tabs of the minimal bar: the active one wide (icon + label), the others a square with the icon only. `x` = the first.
local function variableTabs(count: number, activeIndex: number, x: number, y: number, small: number, wide: number, gap: number, height: number): { Rect }
	const tabs: { Rect } = {}
	local at = x
	for index = 1, count do
		const width = if index == activeIndex then wide else small
		table.insert(tabs, rect(at, y, width, height))
		at += width + gap
	end
	return tabs
end

-- Moves `block` up until it clears every reserved rectangle (the call subtitle of Walt, a banner): the transient hint and toast
-- never sit on them (user request 2026-10-12). Bounded: a rectangle that cannot be cleared is left where the last move put it.
local function clearOf(block: Rect, reserved: { Rect }?): Rect
	if reserved == nil then
		return block
	end
	local current = block
	for _ = 1, #reserved + 1 do
		local moved = false
		for _, zone in reserved do
			if zone.W > 0 and zone.H > 0 and overlaps(current, zone) then
				current = rect(current.X, zone.Y - 6 - current.H, current.W, current.H)
				moved = true
			end
		end
		if not moved then
			break
		end
	end
	return current
end

-- Minimal 3D layout (prep-3d.md §5 table, rev. 2; polish 2026-10-12). The bottom row is ONE pill on the left (Leave, Assist, Tap), the
-- section tabs centred (only the active one has its word, the others are icons) and Next on the right, all anchored to the edges; the
-- top stays free for the Hud (money, clock, sanity) and the Roblox menu. The progress card is 44 high: the verb on the left, the
-- live grade of the plate (a seal and a number) on the right, a 10 px bar below. With a tutorial step (`Objective`) it is ONE card 64
-- high (step chip, the objective, its hint, the live note, the bar) with the Skip pill beside it. The ticket is a tall paper on the left
-- (the OrderStack), the bin zone sits above Next. `Reserved` = rectangles of transient overlays that the hint and the toast avoid. Provisional.
local function mini(canvas: Vector2, count: number, activeIndex: number, options: Options): Result
	const w, h = canvas.X, canvas.Y
	const zero = rect(-100, -100, 0, 0)
	const portraitShape = w < h
	const desktopShape = not portraitShape and h >= DESKTOP_MIN_H
	const margin = if desktopShape then 16 else MARGIN
	const rowH = if desktopShape then 48 else TOUCH
	const rowY = h - margin - rowH
	-- owner 2026-10-17 (phone too crowded): Next 128 x 52 -> 112 x 46 on a phone
	const nextW = if desktopShape then 152 elseif w < 760 then 108 else 112
	const nextH = if desktopShape then 56 elseif portraitShape then 50 else 46
	const next = rect(w - margin - nextW, h - margin - nextH, nextW, nextH)
	-- the pill: PILL_PAD px of Ink all round, round chips of 44 (their corners follow the pill: radius = height / 2 - pad). Leave is 96
	-- wide with its word on a desktop
	const pad = PILL_PAD
	-- the red Leave button carries the close cross and its word on every shape (owner 2026-10-17)
	const leaveW = if desktopShape then 104 else 84
	-- the Assist chip is gone (owner decision 2026-10-14); only Tap can follow Leave
	const chips = if options.Taps == true then 1 else 0
	const pillW = pad + leaveW + chips * (pad + TOUCH) + pad
	const pillH = pad + TOUCH + pad
	const pillY = rowY + (rowH - TOUCH) / 2 - pad
	const pill = rect(margin, pillY, pillW, pillH)
	const leave = rect(pill.X + pad, pill.Y + pad, leaveW, TOUCH)
	const assist = zero
	const tap = if options.Taps == true then rect(leave.X + leaveW + pad, leave.Y, TOUCH, TOUCH) else zero

	-- the section tabs: centred; portrait: above Next
	local tabsY = rowY
	const gap = if desktopShape then 8 elseif w < 760 then 5 else 6
	const small = if desktopShape then 48 else TOUCH
	local wide = if desktopShape then 136 elseif portraitShape then 100 elseif w < 760 then 108 else 116
	if portraitShape then
		tabsY = next.Y - 8 - TOUCH
	else
		-- the room between the pill and Next, taken symmetrically around the centre: the active tab shrinks before it collides
		const left = pill.X + pill.W + 8
		const half = math.floor(math.min(w / 2 - left, next.X - 8 - w / 2))
		wide = math.min(wide, 2 * half - (count - 1) * small - (count - 1) * gap)
		wide = math.max(wide, small)
	end
	-- the sections are indicator dots now (feedback 2026-10-12, H): every rectangle is a same-size hit area (>= 44 px), the lit dot
	-- is drawn longer INSIDE its own rectangle by the shell, so the row never changes size and the camera pan can light any of them
	wide = small
	const total = (count - 1) * small + wide + (count - 1) * gap
	const x = (w - total) / 2
	const tabs = variableTabs(count, activeIndex, x, tabsY, small, wide, gap, if portraitShape then TOUCH else rowH)
	const bar = rect(x, tabsY, total, if portraitShape then TOUCH else rowH)

	const stripH = if desktopShape then 32 else 28
	const hintW = if portraitShape then w - 2 * margin elseif desktopShape then 400 elseif w < 760 then 300 else 340
	const hintX = (w - hintW) / 2
	const baseHint = rect(hintX, tabsY - 6 - stripH, hintW, stripH)
	-- the toast takes the hint's slot (the shell hides the hint while a toast is up): ONE strip over the counter, not two
	-- (owner 2026-10-17). `baseToast` stays the top of that strip for the world zone and the portrait bin.
	const baseToast = baseHint
	-- the strip moves above the overlays that are up (Walt's subtitle)
	const hint = clearOf(baseHint, options.Reserved)
	const toast = hint

	local progress: Rect
	local skip: Rect = zero
	local ticket: Rect
	local seal: Rect
	local hudStatus: Rect
	local sanity: Rect
	local menu: Rect
	-- The Hud as it is built (HudScreen / HudSanity): the clock pill ~120 x 32 at the top centre (y 6), day + money 84 + 6 + 84 on the
	-- top right (a column under 560 px), the sanity meter under the 60 px Roblox bar (180 x 38 on touch, 274 x 50 otherwise).
	-- The progress card goes right under the clock (y 50). The seal of the plate sits on the right under the money pills (it stays while the
	-- plate waits to be served, so it must not cover the customer in the middle of the Window view).
	const hudClock = rect((w - 120) / 2, 6, 120, 32)
	const objective = options.Objective == true
	const skipW = 76
	-- the card (and the Skip pill when there is a step): centred as one group
	local function group(cardW: number, y: number, height: number): (Rect, Rect)
		const full = if objective then cardW + 8 + skipW else cardW
		-- centred, unless the sanity meter (night, under the clock row) is in the way: then the group sits right of it
		local x0 = (w - full) / 2
		if sanity.W > 0 and y < sanity.Y + sanity.H and y + height > sanity.Y and x0 < sanity.X + sanity.W + 8 then
			x0 = math.min(sanity.X + sanity.W + 8, w - margin - full)
		end
		const card = rect(x0, y, cardW, height)
		const pillRect = if objective then rect(x0 + cardW + 8, y, skipW, TOUCH) else zero
		return card, pillRect
	end
	if portraitShape then
		hudStatus = rect(w - 10 - 110, 6, 110, 82)
		sanity = rect(8, 68, 180, 38)
		menu = rect(0, 0, 112, 60)
		progress = rect(margin, 114, w - 2 * margin - (if objective then 8 + skipW else 0), if objective then 64 else 44)
		if objective then
			skip = rect(progress.X + progress.W + 8, 114, skipW, TOUCH)
		end
		ticket = rect(margin, progress.Y + progress.H + 8, w - 2 * margin, 92)
		seal = rect(w - margin - 96, ticket.Y + ticket.H + 8, 96, 122)
	elseif desktopShape then
		hudStatus = rect(w - 10 - 224, 6, 224, 32)
		sanity = rect(8, 52, 274, 50)
		menu = rect(0, 0, 112, 52)
		progress, skip = group(if objective then 360 else 300, 52, if objective then 68 else 48)
		const top = 130
		ticket = rect(margin, top, 190, math.clamp(pill.Y - 8 - top, 200, 250))
		seal = rect(w - margin - 120, hudStatus.Y + hudStatus.H + 10, 120, 150)
	else
		-- the Hud on a phone (2026-10-17): day 84 + money 84 + the gear / cart column (38 x 78) on the right
		hudStatus = rect(w - 10 - 218, 6, 218, 32)
		-- the Roblox menu is ~58 real px tall; at the touch scale 0.8 that is ~72 UI px
		menu = rect(0, 0, 112, 72)
		sanity = if options.Sanity == true then rect(8, 80, 180, 38) else rect(8, 80, 0, 0)
		const progressW = if objective then (if w < 760 then 300 else 330) elseif w < 760 then 240 else 260
		progress, skip = group(progressW, 44, if objective then 60 else 40)
		-- the tall paper sits right under the Roblox menu (owner 2026-10-17: it was too low), under the sanity meter at night,
		-- and ends 8 px over the pill
		const top = if options.Sanity == true then sanity.Y + sanity.H + 6 else menu.Y + menu.H + 6
		ticket = rect(margin, top, 130, math.clamp(pill.Y - 8 - top, 190, 230))
		-- under the gear / cart column (6 + 2 x 38 + 2) and the Skip pill
		seal = rect(w - margin - 96, math.max(6 + 78 + 8, if skip.W > 0 then skip.Y + skip.H + 8 else 0), 96, 122)
	end
	-- the bin zone (owner request 2026-10-14): bottom left, right after the Leave pill, level with the row of the section dots; it only
	-- shows while something is being dragged (BinZone). Portrait: the left, over the hint row.
	const binSide = if desktopShape then 88 else 72
	local bin = if portraitShape
		then rect(margin, baseToast.Y - 8 - binSide, binSide, binSide)
		else rect(pill.X + pill.W + 16, rowY + rowH - binSide, binSide, binSide)
	-- a wide Leave (and the Tap chip) on a narrow phone: no room before the section dots, so the bin sits above the pill
	if not portraitShape and overlaps(bin, bar) then
		bin = rect(pill.X, pill.Y - 8 - binSide, binSide, binSide)
	end
	const centerTop = progress.Y + progress.H + 8
	const center = if portraitShape
		then zero
		else rect(hintX, centerTop, hintW, math.max(baseToast.Y - centerTop, 0))

	return {
		Kind = if portraitShape then "Portrait" elseif desktopShape then "Desktop" else "Phone",
		Canvas = canvas,
		TicketStrip = portraitShape,
		LeaveWide = desktopShape,
		TabsCompact = portraitShape,
		TabsIconOnly = true,
		Bar = bar,
		Leave = leave,
		Tabs = tabs,
		Status = hudStatus,
		Strip = zero,
		Ticket = ticket,
		Peers = zero,
		Board = zero,
		Panel = zero,
		Cols = 2,
		Rows = 3,
		Box = 44,
		Next = next,
		Trash = zero,
		Assist = assist,
		Toast = toast,
		Header = 0,
		Mini = {
			Progress = progress,
			Skip = skip,
			Hint = hint,
			Seal = seal,
			Tap = tap,
			Pill = pill,
			PillPad = pad,
			Bin = bin,
			HudStatus = hudStatus,
			HudClock = hudClock,
			HudSanity = sanity,
			RobloxMenu = menu,
			Center = center,
		},
	}
end

-- `activeIndex` only matters in portrait, where the active tab is wider than the others. `minimal` = the 3D mode (mini above).
local function compute(canvas: Vector2, hasPanel: boolean, count: number, activeIndex: number, minimal: boolean?, extra: (boolean | Options)?): Result
	if minimal == true then
		const options: Options = if type(extra) == "table" then extra elseif extra == true then { Taps = true } else {}
		return mini(canvas, count, activeIndex, options)
	end
	local result: Result
	if canvas.X < canvas.Y then
		result = portrait(canvas, hasPanel, count)
		const tabs: { Rect } = {}
		local x = MARGIN + TOUCH + TAB_GAP
		for index = 1, count do
			const width = if index == activeIndex then 100 else 48
			table.insert(tabs, rect(x, 66, width, TOUCH))
			x += width + TAB_GAP
		end
		result.Tabs = tabs
	elseif canvas.Y >= DESKTOP_MIN_H then
		result = desktop(canvas, hasPanel, count)
	else
		result = phone(canvas, hasPanel, count)
	end
	return result
end

-- Every rectangle that must not overlap another (the blocks that are on screen at once), by name; for the story and the
-- spec check. `trash` / `strip` / `peers` are contextual and left out unless asked.
local function blocks(layout: Result, hasPanel: boolean): { [string]: Rect }
	const extra = layout.Mini
	if extra ~= nil then
		-- the minimal mode: ours + the zones of the Hud and the Roblox menu (never ours). `Center` is checked apart (centerClear).
		const own: { [string]: Rect } = {
			Progress = extra.Progress,
			Ticket = layout.Ticket,
			Pill = extra.Pill,
			Skip = extra.Skip,
			Bin = extra.Bin,
			Tabs = layout.Bar,
			Next = layout.Next,
			Hint = extra.Hint,
			Toast = layout.Toast,
			Seal = extra.Seal,
			HudStatus = extra.HudStatus,
			HudClock = extra.HudClock,
			HudSanity = extra.HudSanity,
			RobloxMenu = extra.RobloxMenu,
		}
		return own
	end
	const out: { [string]: Rect } = {
		Bar = layout.Bar,
		Status = layout.Status,
		Ticket = layout.Ticket,
		Board = layout.Board,
		Next = layout.Next,
		Assist = layout.Assist,
		Toast = layout.Toast,
	}
	if hasPanel then
		out.Panel = layout.Panel
	end
	return out
end

-- the zones of the minimal mode that belong to the Hud and Roblox
const FOREIGN: { [string]: boolean } = { HudStatus = true, HudClock = true, HudSanity = true, RobloxMenu = true }

-- Names of the pairs that overlap ("Bar/Status"); empty = the layout is clean.
local function conflicts(layout: Result, hasPanel: boolean): { string }
	const found: { string } = {}
	const all = blocks(layout, hasPanel)
	const names: { string } = {}
	for name in all do
		table.insert(names, name)
	end
	table.sort(names)
	-- the Hud zones and the Roblox menu are not ours: they only have to be free of OUR blocks (two of them side by side is theirs)
	const foreign = layout.Mini ~= nil
	for i = 1, #names do
		for j = i + 1, #names do
			if foreign and FOREIGN[names[i]] and FOREIGN[names[j]] then
				continue
			end
			if overlaps(all[names[i]], all[names[j]]) then
				table.insert(found, `{names[i]}/{names[j]}`)
			end
		end
	end
	return found
end

-- The world zone of the minimal mode: the names of our permanent blocks that enter it (the transient Hint, Toast and Seal may).
local function centerIntrusions(layout: Result): { string }
	const found: { string } = {}
	const extra = layout.Mini
	if extra == nil or extra.Center.W <= 0 then
		return found
	end
	const all = blocks(layout, false)
	const names: { string } = {}
	for name in all do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		if name ~= "Hint" and name ~= "Toast" and name ~= "Seal" and not FOREIGN[name] and overlaps(extra.Center, all[name]) then
			table.insert(found, name)
		end
	end
	return found
end

return table.freeze({
	Compute = compute,
	Conflicts = conflicts,
	CenterIntrusions = centerIntrusions,
	Overlaps = overlaps,
	Margin = MARGIN,
})
