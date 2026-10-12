--!strict
-- PrepShell/Layout: where every block of the focused prep mode goes (docs/art/prep-ui-spec.md §4). Pure: a canvas size in
-- UI px (the ScreenGui area divided by the global UI scale) in, rectangles out. Three shapes:
--   Phone    landscape, canvas height < 520 (844 x 390 is the design size; 667 x 375 is the floor and must fit too)
--   Desktop  landscape, canvas height >= 520 (about 1371 x 771 at 1280 x 720)
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
	Hint: Rect,
	Seal: Rect,
	Tap: Rect,
	HudStatus: Rect,
	HudClock: Rect,
	HudSanity: Rect,
	RobloxMenu: Rect,
	Center: Rect,
}

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
}

const MARGIN = 12
const TAB_GAP = 6
const TOUCH = 44

local function rect(x: number, y: number, w: number, h: number): Rect
	return { X = math.floor(x + 0.5), Y = math.floor(y + 0.5), W = math.floor(w + 0.5), H = math.floor(h + 0.5) }
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

-- Minimal 3D layout (prep-3d.md §5 table, rev. 2). The bottom row (Leave, Assist, Tap | tabs | Next) is anchored to the edges
-- and the section tabs are centred; the top stays free for the Hud (money, clock, sanity) and the Roblox menu. Provisional.
local function mini(canvas: Vector2, count: number, activeIndex: number): Result
	const w, h = canvas.X, canvas.Y
	const zero = rect(-100, -100, 0, 0)
	const portraitShape = w < h
	const desktopShape = not portraitShape and h >= 520
	const margin = if desktopShape then 16 else MARGIN
	const rowH = if desktopShape then 48 else TOUCH
	const rowY = h - margin - rowH
	const chipY = if desktopShape then rowY + 2 else rowY
	const nextW = if desktopShape then 152 elseif w < 760 then 128 else 132
	const nextH = if desktopShape then 56 elseif portraitShape then 54 else 52
	const next = rect(w - margin - nextW, h - margin - nextH, nextW, nextH)
	local leave: Rect
	local assist: Rect
	local tap: Rect
	if desktopShape then
		leave = rect(margin, rowY, 96, rowH)
		assist = rect(margin + 96 + 8, chipY, TOUCH, TOUCH)
		tap = rect(assist.X + TOUCH + 8, chipY, TOUCH, TOUCH)
	else
		leave = rect(margin, rowY, TOUCH, TOUCH)
		assist = rect(leave.X + TOUCH + 4, rowY, TOUCH, TOUCH)
		tap = rect(assist.X + TOUCH + 4, rowY, TOUCH, TOUCH)
	end

	-- the section tabs: centred, four equal buttons (phone, desktop); portrait: the active one wide, the others a mark, above Next
	local tabs: { Rect } = {}
	local tabsY = rowY
	local bar: Rect
	if portraitShape then
		tabsY = next.Y - 8 - TOUCH
		const gap = 6
		local total = (count - 1) * gap
		for index = 1, count do
			total += if index == activeIndex then 100 else 48
		end
		local x = (w - total) / 2
		for index = 1, count do
			const width = if index == activeIndex then 100 else 48
			table.insert(tabs, rect(x, tabsY, width, TOUCH))
			x += width + gap
		end
		bar = rect((w - total) / 2, tabsY, total, TOUCH)
	else
		const gap = if desktopShape then 8 elseif w < 760 then 4 else 6
		-- the room between the chips and Next, taken symmetrically around the centre
		const left = tap.X + tap.W + 8
		const half = math.ceil(math.min(w / 2 - left, next.X - 8 - w / 2))
		const wanted = if desktopShape then 128 elseif w < 760 then 84 else 104
		const tabW = math.min(wanted, math.floor((2 * half - (count - 1) * gap) / count))
		const total = count * tabW + (count - 1) * gap
		const x = (w - total) / 2
		tabs = equalTabs(count, x, tabsY, tabW, rowH, gap)
		bar = rect(x, tabsY, total, rowH)
	end

	const hintW = if portraitShape then w - 2 * margin elseif desktopShape then 400 elseif w < 760 then 332 else 400
	const hintX = (w - hintW) / 2
	const hint = rect(hintX, tabsY - 6 - 32, hintW, 32)
	const toast = rect(hintX, hint.Y - 6 - 32, hintW, 32)

	local progress: Rect
	local ticket: Rect
	local seal: Rect
	local hudStatus: Rect
	local sanity: Rect
	local menu: Rect
	-- The Hud as it is built (HudScreen / HudSanity): the clock pill 112 x 38 at the top centre (y 6), day + money 96 + 6 + 96 on the
	-- top right (a column under 560 px), the sanity meter under the 60 px Roblox bar (180 x 38 on touch, 274 x 50 otherwise).
	-- The spec put the clock top right; it is at the top centre, so the progress card goes right under it (y 50), not at y 8.
	const hudClock = rect((w - 112) / 2, 6, 112, 38)
	if portraitShape then
		hudStatus = rect(w - 10 - 110, 6, 110, 82)
		sanity = rect(8, 68, 180, 38)
		menu = rect(0, 0, 112, 60)
		progress = rect(margin, 114, w - 2 * margin, 36)
		ticket = rect(margin, 158, w - 2 * margin, 82)
		seal = rect(w - margin - 96, 248, 96, 96)
	elseif desktopShape then
		hudStatus = rect(w - 10 - 198, 6, 198, 38)
		sanity = rect(8, 52, 274, 50)
		menu = rect(0, 0, 112, 52)
		progress = rect((w - 280) / 2, 52, 280, 40)
		ticket = rect(margin, 130, 184, 152)
		seal = rect(w * 0.66, 140, 120, 120)
	else
		hudStatus = rect(w - 10 - 198, 6, 198, 38)
		sanity = rect(8, 68, 180, 38)
		menu = rect(0, 0, 112, 60)
		const progressW = if w < 760 then 267 else 264
		progress = rect((w - progressW) / 2, 50, progressW, 36)
		-- 134 / 140 px tall (the spec has 120): the TicketRail card needs 134 for its 3 chips and the two lines of what was said;
		-- it starts under the sanity meter (68 + 38 + 8)
		ticket = if w < 760 then rect(margin, 114, 140, 134) else rect(margin, 114, 152, 140)
		seal = rect(w * 0.66, 110, 96, 96)
	end
	const centerTop = progress.Y + progress.H + 8
	const center = if portraitShape
		then zero
		else rect(hint.X, centerTop, hint.W, math.max(toast.Y - centerTop, 0))

	return {
		Kind = if portraitShape then "Portrait" elseif desktopShape then "Desktop" else "Phone",
		Canvas = canvas,
		TicketStrip = portraitShape,
		LeaveWide = desktopShape,
		TabsCompact = portraitShape,
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
			Hint = hint,
			Seal = seal,
			Tap = tap,
			HudStatus = hudStatus,
			HudClock = hudClock,
			HudSanity = sanity,
			RobloxMenu = menu,
			Center = center,
		},
	}
end

-- `activeIndex` only matters in portrait, where the active tab is wider than the others. `minimal` = the 3D mode (mini above).
local function compute(canvas: Vector2, hasPanel: boolean, count: number, activeIndex: number, minimal: boolean?): Result
	if minimal == true then
		return mini(canvas, count, activeIndex)
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
	elseif canvas.Y >= 520 then
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
			Leave = layout.Leave,
			Assist = layout.Assist,
			Tap = extra.Tap,
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

local function overlaps(a: Rect, b: Rect): boolean
	return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H
end

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
