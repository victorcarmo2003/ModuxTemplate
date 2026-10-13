--!nocheck
-- Pure overlap test of the prep chrome (U-1 of the polish of 2026-10-12): runs the real Layout.luau (PrepShell) at the screens that
-- matter and checks that no block of ours overlaps another, the Hud zones (clock, money, sanity), the Roblox menu or the world zone,
-- that every touch target is at least 44 px and that everything is inside the canvas. No Roblox, no Studio:
--   lune run tools/studio/prep_layout_check
-- Run it from the repo root. Prints one line per screen and `LAYOUT: N ok, M failures`; exit code 1 on a failure.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

-- the repo uses `const`; plain Luau wants `local`
local source = fs.readFile("src/Interface/client/Components/PrepShell/Layout.luau")
source = string.gsub(source, "%f[%w_]const%f[^%w_]", "local")
local chunk = luau.load(source, { debugName = "Layout" })
local Layout = chunk()

-- UI canvas = screen size divided by Theme.ScaleOf (touch never below 1; mouse floor 0.86, 1080p factor 1.4)
local screens = {
	{ "phone 667x375", 667, 375 },
	{ "phone 844x390", 844, 390 },
	{ "phone 932x430", 932, 430 },
	{ "desktop 1280x720 (canvas 1371x771)", 1371, 771 },
	{ "desktop 1920x1080 (canvas 1371x771)", 1371, 771 },
	{ "portrait 390x844", 390, 844 },
	{ "portrait 358x774", 358, 774 },
}

local failures, passes = 0, 0
local function fail(screen, text)
	failures += 1
	print(`  FAIL [{screen}] {text}`)
end

local function inside(rect, w, h)
	return rect.X >= 0 and rect.Y >= 0 and rect.X + rect.W <= w and rect.Y + rect.H <= h
end

for _, screen in screens do
	local name, w, h = screen[1], screen[2], screen[3]
	local before = failures
	-- every combination of the options of the owner: the Tap chip, the tutorial step (the Skip pill) and an overlay the hint must avoid
	-- (a subtitle band over the tabs, where Walt's call line lands)
	local combos = {}
	for _, taps in { false, true } do
		for _, objective in { false, true } do
			for _, reserved in { false, true } do
				table.insert(combos, { Taps = taps, Objective = objective, Reserved = reserved })
			end
		end
	end
	for _, combo in combos do
		local taps = combo.Taps
		for active = 1, 4 do
			local band = { X = math.floor(w / 2 - 170), Y = h - 120, W = 340, H = 40 }
			local layout = Layout.Compute({ X = w, Y = h }, false, 4, active, true, {
				Taps = taps,
				Objective = combo.Objective,
				Reserved = if combo.Reserved then { band } else nil,
			})
			local tag = `{name} tab{active}{taps and " +tap" or ""}{combo.Objective and " +step" or ""}{combo.Reserved and " +reserved" or ""}`
			for _, pair in Layout.Conflicts(layout, false) do
				fail(tag, `overlap {pair}`)
			end
			for _, block in Layout.CenterIntrusions(layout) do
				fail(tag, `{block} enters the world zone`)
			end
			local mini = layout.Mini
			local own = {
				Progress = mini.Progress,
				Pill = mini.Pill,
				Leave = layout.Leave,
				Assist = layout.Assist,
				Next = layout.Next,
				Bar = layout.Bar,
				Hint = mini.Hint,
				Toast = layout.Toast,
				Seal = mini.Seal,
				Ticket = layout.Ticket,
				Bin = mini.Bin,
			}
			if combo.Objective then
				own.Skip = mini.Skip
			end
			if taps then
				own.Tap = mini.Tap
			end
			for key, rect in own do
				if not inside(rect, w, h) then
					fail(tag, `{key} leaves the canvas ({rect.X},{rect.Y},{rect.W},{rect.H})`)
				end
			end
			-- the ticket is a tall paper (card) or one wide band (portrait strip): room for the head, 5 layers and the line
			if layout.TicketStrip then
				if layout.Ticket.H < 78 or layout.Ticket.W < 300 then
					fail(tag, `Ticket strip too small ({layout.Ticket.W}x{layout.Ticket.H})`)
				end
			elseif layout.Ticket.H < 176 or layout.Ticket.W < 104 then
				fail(tag, `Ticket card too small ({layout.Ticket.W}x{layout.Ticket.H}): needs 176 high, 104 wide`)
			end
			-- the bin zone is a drop target: at least 64 px (44 + a thumb on each side) and the hint stays off it
			if mini.Bin.W < 64 or mini.Bin.H < 64 then
				fail(tag, `Bin zone is small ({mini.Bin.W}x{mini.Bin.H})`)
			end
			-- the hint and the toast keep off the overlay that is up
			if combo.Reserved then
				for key, rect in { Hint = mini.Hint, Toast = layout.Toast } do
					if Layout.Overlaps(rect, band) then
						fail(tag, `{key} sits on the reserved overlay`)
					end
				end
			end
			-- touch targets
			local targets = { Leave = layout.Leave, Assist = layout.Assist, Next = layout.Next }
			if combo.Objective then
				targets.Skip = mini.Skip
			end
			if taps then
				targets.Tap = mini.Tap
			end
			for index, rect in layout.Tabs do
				targets[`Tab{index}`] = rect
			end
			for key, rect in targets do
				if rect.W < 44 or rect.H < 44 then
					fail(tag, `{key} is under 44 px ({rect.W}x{rect.H})`)
				end
			end
			-- the chips are inside the pill
			for key, rect in { Leave = layout.Leave, Assist = layout.Assist } do
				local pill = mini.Pill
				if rect.X < pill.X or rect.Y < pill.Y or rect.X + rect.W > pill.X + pill.W or rect.Y + rect.H > pill.Y + pill.H then
					fail(tag, `{key} is not inside the pill`)
				end
			end
			-- the tabs do not touch each other, the pill or Next
			for index = 1, #layout.Tabs do
				for other = index + 1, #layout.Tabs do
					if Layout.Overlaps(layout.Tabs[index], layout.Tabs[other]) then
						fail(tag, `Tab{index}/Tab{other} overlap`)
					end
				end
				if Layout.Overlaps(layout.Tabs[index], mini.Pill) then
					fail(tag, `Tab{index}/Pill overlap`)
				end
				if Layout.Overlaps(layout.Tabs[index], layout.Next) then
					fail(tag, `Tab{index}/Next overlap`)
				end
				-- the sections are indicator dots (pan, 2026-10-12): every hit rectangle is the same size, so the lit dot (drawn
				-- longer inside it, 34 px at most) never changes the row, and the lit pill fits in the rectangle
				if layout.Tabs[index].W ~= layout.Tabs[1].W or layout.Tabs[index].H ~= layout.Tabs[1].H then
					fail(tag, `Tab{index} is not the size of Tab1 (the dots are uniform)`)
				end
				if layout.Tabs[index].W < 36 then
					fail(tag, `Tab{index} hit area is narrower than the lit dot (36 px)`)
				end
			end
		end
	end
	if failures == before then
		passes += 1
		print(`ok   {name}`)
	end
end

print(`LAYOUT: {passes} ok, {failures} failures`)
if failures > 0 then
	process.exit(1)
end
