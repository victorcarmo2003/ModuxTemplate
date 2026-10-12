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

-- `activeIndex` only matters in portrait, where the active tab is wider than the others.
local function compute(canvas: Vector2, hasPanel: boolean, count: number, activeIndex: number): Result
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
	for i = 1, #names do
		for j = i + 1, #names do
			if overlaps(all[names[i]], all[names[j]]) then
				table.insert(found, `{names[i]}/{names[j]}`)
			end
		end
	end
	return found
end

return table.freeze({
	Compute = compute,
	Conflicts = conflicts,
	Overlaps = overlaps,
	Margin = MARGIN,
})
