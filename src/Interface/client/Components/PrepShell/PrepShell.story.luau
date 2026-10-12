--!strict
-- PrepShell: the whole chrome of the focused prep mode on four device frames: Phone 667 x 375 (the floor), Phone 844 x 390 (the
-- design size), Desktop 1280 x 720 and Portrait 390 x 844. The frame has the size of the device (UI Labs scales the story down
-- when the viewport is smaller). "Insets" pads the frame like DeviceSafeInsets (notch 47 px on the sides, 24 px under).
-- Controls: Device, Mode (the minimal 3D chrome of TASK-199, or the 2D one), Tab, Night, NextReady, Count (badges), Toast (flip it
-- to push one), Assist, Plate (a plate is in the works: the bin shows, 2D only), Panel is on in the Build tab (2D), Hint (short,
-- long, empty), Seal (the finished plate), Pips (0 to 3 graded), Pad (gamepad glyphs), Progress (0..1 of the section).
-- In the Minimal mode the sky colour is the "3D world"; the Hud (money, clock, sanity) is drawn as a dashed ghost box in the zones
-- it owns, so an overlap would be visible. The label under the frame says "layout clean" or names the overlapping blocks
-- (Layout.Conflicts, the check of the spec 4 tables) and the blocks that enter the world zone (Layout.CenterIntrusions).
-- Tap a tab, Leave, Next, the bin (HOLD 0.5 s, 2D), Assist, Tap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Parent.Theme)
local IngredientPanel = require(script.Parent.Parent.IngredientPanel)
local PlateView = require(script.Parent.Parent.PlateView)
local TicketRail = require(script.Parent.Parent.TicketRail)
local PrepShell = require(script.Parent)
local Layout = require(script.Parent.Layout)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
-- Vide 0.4.1 types `create` for 19 classes only; UIPadding is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

type Controls = {
	Device: () -> string,
	Mode: () -> string,
	Hint: () -> string,
	Seal: () -> string,
	Pips: () -> number,
	Pad: () -> boolean,
	Progress: () -> number,
	Tab: () -> string,
	Night: () -> boolean,
	NextReady: () -> boolean,
	Count: () -> number,
	Toast: () -> boolean,
	Insets: () -> boolean,
	Plate: () -> boolean,
}

type Device = { Size: Vector2, Scale: number }

-- UI scale of each device (what Theme.ScaleOf gives on that screen: 1 on a touch phone, 0.93 at 720p, 1.09 portrait)
const DEVICES: { [string]: Device } = {
	["Phone 667"] = { Size = Vector2.new(667, 375), Scale = 1 },
	["Phone 844"] = { Size = Vector2.new(844, 390), Scale = 1 },
	["Desktop 1280"] = { Size = Vector2.new(1280, 720), Scale = 0.93 },
	["Portrait 390"] = { Size = Vector2.new(390, 844), Scale = 1.09 },
}

const INFO: { [string]: IngredientPanel.Info } = {
	ketchup = { Stock = 12, Locked = false, Used = true },
	mustard = { Stock = 9, Locked = false, Used = false },
	cream_cheese = { Stock = 2, Locked = false, Used = false },
	cheese = { Stock = 0, Locked = true, Used = false },
	bacon = { Stock = 0, Locked = false, Used = false },
	potato_sticks = { Stock = 10, Locked = false, Used = false },
}

const TICKET: TicketRail.Ticket = {
	Id = 12,
	Name = "Rex",
	Say = "The usual, please.",
	Toppings = { "ketchup", "mustard", "cheese" },
	Patience = 0.7,
	State = "Active",
}

-- Every layout of the spec, checked at once: the names of the pairs that overlap
local function audit(): string
	const problems: { string } = {}
	for name, device in DEVICES do
		for _, hasPanel in { true, false } do
			const layout = Layout.Compute(device.Size / device.Scale, hasPanel, 4, 3)
			for _, pair in Layout.Conflicts(layout, hasPanel) do
				table.insert(problems, `{name}{if hasPanel then " +panel" else ""}: {pair}`)
			end
		end
		-- the minimal 3D chrome: every active tab (portrait changes with it), overlaps and what enters the world zone
		for active = 1, 4 do
			const layout = Layout.Compute(device.Size / device.Scale, false, 4, active, true)
			for _, pair in Layout.Conflicts(layout, false) do
				table.insert(problems, `{name} minimal tab {active}: {pair}`)
			end
			for _, block in Layout.CenterIntrusions(layout) do
				table.insert(problems, `{name} minimal tab {active}: {block} enters the world zone`)
			end
		end
	end
	table.sort(problems)
	return if #problems == 0 then "layout clean: 0 overlaps in 24 combinations (8 in 2D, 16 minimal)" else table.concat(problems, "\n")
end

-- The tabs of a mode: Content.Prep.Tabs3D in the minimal one, TabsLegacy in the 2D one
local function tabRows(minimal: boolean): { PrepShell.Tab }
	const out: { PrepShell.Tab } = {}
	const set = if minimal then Content.Prep.Tabs3D else Content.Prep.TabsLegacy
	for _, row in set.List do
		table.insert(out, { Key = row.Key, Label = row.Label, Icon = row.Icon })
	end
	return out
end


-- The pips of the plate: the first `graded` of them have a grade, the others are empty
local function pipsOf(graded: number): { PrepShell.Pip }
	const all: { PrepShell.Pip } = {
		{ Label = "Cut", Grade = "Perfect" },
		{ Label = "Place", Grade = "Good" },
		{ Label = "Top", Grade = "Messy" },
	}
	for index, pip in all do
		if index > graded then
			all[index] = { Label = pip.Label }
		end
	end
	return all
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Device = UILabs.Choose({ "Phone 667", "Phone 844", "Desktop 1280", "Portrait 390" }),
		Mode = UILabs.Choose({ "Minimal 3D", "2D" }),
		Tab = UILabs.Choose({ "Board", "Grill", "Toppings", "Serve", "Build", "Order" }),
		Hint = UILabs.Choose({ "Short", "Long", "Empty" }),
		Seal = UILabs.Choose({ "None", "Perfect", "Good", "Messy" }),
		Pips = UILabs.Slider(3, 0, 3, 1),
		Progress = UILabs.Slider(0.4, 0, 1, 0.05),
		Pad = false,
		Night = false,
		NextReady = true,
		Count = UILabs.Slider(2, 0, 12, 1),
		Toast = false,
		Insets = false,
		Plate = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const tab = source("Board")
	effect(function()
		tab(controls.Tab())
	end)
	const isMinimal = function(): boolean
		return controls.Mode() == "Minimal 3D"
	end
	-- the tab the shell shows: the control's, resolved into the set of the mode (Build = Board and Order = Grill in 3D)
	const shownTab = function(): string
		const wanted = tab()
		const set = if isMinimal() then Content.Prep.Tabs3D else Content.Prep.TabsLegacy
		if set.ByKey[wanted] ~= nil then
			return wanted
		end
		const alias = Content.Prep.TabAlias[wanted]
		return if alias ~= nil and set.ByKey[alias] ~= nil then alias else set.List[1].Key
	end
	const toasts = source(false :: PrepShell.Toast | false)
	local toastId = 0
	effect(function()
		controls.Toast()
		toastId += 1
		if toastId > 1 then
			toasts({ Text = "Take your time", Kind = "Alert", Id = toastId })
		end
	end)
	const assist = source(false)
	const tapMode = source(false)
	const focus = source("")
	const device = function(): Device
		return DEVICES[controls.Device()] or DEVICES["Phone 844"]
	end
	const hintText = function(): string
		const kind = controls.Hint()
		if kind == "Empty" then
			return ""
		elseif kind == "Long" then
			return "Drag the sausage into the bun and hold it steady until the guide closes"
		end
		const row = Content.Prep.Tabs3D.ByKey[shownTab()] or Content.Prep.TabsLegacy.ByKey[shownTab()]
		return if row ~= nil then row.Hint else ""
	end

	-- a dark box where the Hud (clock, day and money, sanity) and the Roblox menu own the screen, so an overlap shows up
	local function ghost(name: string, pick: (Layout.Mini) -> Layout.Rect): Frame
		return create("Frame")({
			Name = `Ghost{name}`,
			Position = function(): UDim2
				const mini = Layout.Compute(device().Size / device().Scale, false, 4, 1, true).Mini
				const r = if mini ~= nil then pick(mini) else { X = 0, Y = 0, W = 0, H = 0 }
				return UDim2.fromOffset(r.X * device().Scale, r.Y * device().Scale)
			end,
			Size = function(): UDim2
				const mini = Layout.Compute(device().Size / device().Scale, false, 4, 1, true).Mini
				const r = if mini ~= nil then pick(mini) else { X = 0, Y = 0, W = 0, H = 0 }
				return UDim2.fromOffset(r.W * device().Scale, r.H * device().Scale)
			end,
			BackgroundTransparency = 0.7,
			BackgroundColor3 = Color3.fromHex("#2B2233"),
			Visible = isMinimal,
			ZIndex = 0,
			createRaw("UIStroke")({ Color = Color3.new(1, 1, 1), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			create("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = name,
				TextSize = 14,
				TextColor3 = Color3.new(1, 1, 1),
				FontFace = Theme.Font.Body,
			}),
		})
	end

	-- one shell per mode (the tab list is given once, so a mode change builds a new one)
	local function shell(minimal: boolean): any
		return PrepShell({
			Tabs = tabRows(minimal),
			Tab = shownTab,
			Badges = function(): { [string]: number }
				return { Order = controls.Count(), Grill = 3, Serve = 1 }
			end,
			OnTab = function(key: string)
				tab(key)
			end,
			OnLeave = function()
				print("[PrepShell story] Leave")
			end,
			Hint = hintText,
			Pips = function(): { PrepShell.Pip }
				return pipsOf(controls.Pips())
			end,
			HasPanel = function(): boolean
				return not minimal and shownTab() == "Build"
			end,
			Minimal = function(): boolean
				return minimal
			end,
			Progress = {
				Label = function(): string
					const row = Content.Prep.Tabs3D.ByKey[shownTab()] or Content.Prep.TabsLegacy.ByKey[shownTab()]
					return if row ~= nil then row.Label else ""
				end,
				Value = controls.Progress,
			},
			Seal = function(): PlateView.Grade?
				const kind = controls.Seal()
				return if kind == "Perfect" or kind == "Good" or kind == "Messy" then kind else nil
			end,
			SealLabel = function(grade: any): string
				return Content.Prep.Grades.Labels[grade]
			end,
			TapMode = {
				Label = "Tap",
				On = tapMode,
				OnToggle = function()
					tapMode(not tapMode())
				end,
			},
			Pad = controls.Pad,
			Next = {
				Label = function(): string
					return if shownTab() == "Serve" then Content.Prep.Texts.Serve else Content.Prep.Texts.Next
				end,
				Enabled = controls.NextReady,
				Pulse = controls.NextReady,
				OnPress = function()
					print("[PrepShell story] Next")
				end,
				OnBlocked = function()
					toastId += 1
					toasts({ Text = "Cut the bun first", Kind = "Alert", Id = toastId })
				end,
			},
			Trash = {
				Visible = controls.Plate,
				Hold = 0.5,
				HoldText = "Hold to trash",
				OnTrash = function()
					print("[PrepShell story] Trash")
				end,
			},
			Assist = {
				Label = Content.Prep.Texts.Assist,
				On = assist,
				OnToggle = function()
					assist(not assist())
				end,
			},
			Cash = function(): number
				return 128
			end,
			Clock = function(): string
				return "9:41 AM"
			end,
			IsNight = controls.Night,
			Sanity = function(): number?
				return 0.55
			end,
			Toast = function(): PrepShell.Toast?
				const value = toasts()
				return if value ~= false then value else nil
			end,
			Slots = {
				Ticket = function(layout: () -> Layout.Result): any
					return TicketRail({
						Ticket = function(): TicketRail.Ticket?
							return TICKET
						end,
						Queue = function(): number
							return 3
						end,
						Strip = function(): boolean
							return layout().TicketStrip
						end,
					})
				end,
				Board = function(_layout: () -> Layout.Result): any
					return PlateView({
						Bun = function(): PlateView.BunState
							return if shownTab() == "Build" or shownTab() == "Serve" then "Open" else "None"
						end,
						Guide = function(): boolean
							return false
						end,
						Sausage = function(): PlateView.Sausage?
							return { X = 0.5, Y = 0.5, State = "Ready" }
						end,
						Toppings = function(): { PlateView.Topping }
							return { { Key = "ketchup", Amount = 0.8 } }
						end,
						Seal = function(): PlateView.Grade?
							return if shownTab() == "Serve" then "Perfect" else nil
						end,
						SealLabel = function(grade: PlateView.Grade): string
							return if grade == "Perfect" then "Perfect!" else grade
						end,
						Message = function(): string
							return "Take a ticket"
						end,
					})
				end,
				Panel = function(layout: () -> Layout.Result): any
					return IngredientPanel({
						Info = function(key: string): IngredientPanel.Info
							return INFO[key] or { Stock = 0, Locked = false, Used = false }
						end,
						Cols = function(): number
							return layout().Cols
						end,
						Rows = function(): number
							return layout().Rows
						end,
						Box = function(): number
							return layout().Box
						end,
						Full = function(): boolean
							return false
						end,
						OnPick = function(key: string)
							focus(key)
						end,
						Focus = focus,
					})
				end,
			},
			Scale = function(): number
				return device().Scale
			end,
			Vignette = controls.Night,
		})
	end

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),

		-- the device frame: its real size, padded by the notch when asked
		create("Frame")({
			Name = "Device",
			Position = UDim2.fromOffset(16, 16),
			Size = function(): UDim2
				const size = device().Size
				return UDim2.fromOffset(size.X, size.Y)
			end,
			BackgroundColor3 = Color3.fromHex("#5C6B73"),
			ClipsDescendants = true,
			ghost("Hud status", function(m)
				return m.HudStatus
			end),
			ghost("Hud clock", function(m)
				return m.HudClock
			end),
			ghost("Hud sanity", function(m)
				return m.HudSanity
			end),
			ghost("Roblox menu", function(m)
				return m.RobloxMenu
			end),
			create("Frame")({
				Name = "Safe",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				createRaw("UIPadding")({
					PaddingLeft = function(): UDim
						return UDim.new(0, if controls.Insets() then 47 else 0)
					end,
					PaddingRight = function(): UDim
						return UDim.new(0, if controls.Insets() then 47 else 0)
					end,
					PaddingBottom = function(): UDim
						return UDim.new(0, if controls.Insets() then 24 else 0)
					end,
				}),
				Vide.switch(controls.Mode)({
					["Minimal 3D"] = function(): any
						return shell(true)
					end,
					["2D"] = function(): any
						return shell(false)
					end,
				} :: any),
			}),
		}),

		create("TextLabel")({
			Position = UDim2.new(0, 16, 1, -64),
			Size = UDim2.fromOffset(520, 56),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Body,
			TextSize = Theme.MinTextSize,
			TextColor3 = Theme.Color.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Text = audit(),
		}),
	})
end)
