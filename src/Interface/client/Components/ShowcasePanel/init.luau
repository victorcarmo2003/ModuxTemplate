--!strict
-- ShowcasePanel: dev-only tester panel (docs/tech/showcase.md; user request 2026-10-12, Provisional). One tall Ink card on
-- the right edge: world controls on top (night, clock, sanity, flags, stop / reset), three tabs (Anomalies, Scares,
-- Mechanics) and a scrolling list of cards. Each card has a name, ID, what should happen, the correct verb (from the
-- server, T10) and its live state, plus the buttons the server catalog lists. Built from the cartoon kit
-- (CartoonPanel / CartoonButton / CartoonLabel), so it reads as the rest of the UI. Not a player UI: ShowcaseController
-- mounts it in Studio dev mode only.
-- Pure: only props. The owner turns clicks into ShowcaseDo packets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local CartoonPanel = require(script.Parent.CartoonPanel)

const create = Vide.create
const values = Vide.values
-- Vide 0.4.1 types `create` for 19 classes only; UIScale, UIPadding and ScrollingFrame are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Action = { Id: string, Label: string, Arg: string }

export type Item = {
	Tab: string,
	Group: string,
	Id: string,
	Name: string,
	Ref: string,
	Desc: string,
	Verb: string,
	Actions: { Action },
}

-- One line of the list: a group heading or an item card
export type Row = { Kind: string, Title: string, Item: Item? }

export type Occurrence = { Ref: string, Phase: string, Step: number, Age: number, Live: boolean }

export type State = {
	Night: number,
	Phase: string,
	Clock: number,
	Sanity: number,
	SanityMax: number,
	Life: string,
	Revives: number,
	Frozen: boolean,
	God: boolean,
	Dark: string,
	Held: boolean,
	Switch: boolean,
	Shutter: boolean,
	Vehicle: string,
	Running: { Occurrence },
}

export type Props = {
	Shown: () -> boolean,
	Scale: () -> number,
	-- viewport size in px (the panel is sized from it: UIScale would otherwise stretch a scale-based height)
	Viewport: () -> Vector2,
	Tab: () -> string,
	Tabs: { string },
	Rows: () -> { Row },
	State: () -> State,
	LogText: () -> string,
	LogKind: () -> string,
	OnTab: (tab: string) -> (),
	-- action = ShowcaseDo.Action, id = item id or control name
	OnAction: (action: string, id: string, arg: string, value: number) -> (),
	OnClose: () -> (),
	Name: string?,
}

const WIDTH = 540 -- px at UI scale 1
const TEXT = 14 -- px (style guide floor)
const BUTTON_HEIGHT = 30
const SCALE_FACTOR = 0.72 -- a dev tool: smaller than the player UI
const NIGHTS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
-- game minutes of the Night clock (0:00 of the shift day = 0; 5:45 AM = 1785)
const CLOCKS = { { "9 PM", 1260 }, { "11 PM", 1380 }, { "1 AM", 1500 }, { "3 AM", 1620 }, { "5 AM", 1740 }, { "5:45", 1785 } }
const PHASE_LABEL: { [string]: string } = {
	Signal = "SIGNAL",
	Active = "ACTIVE",
	Resolved = "RESOLVED",
	Failed = "FAILED",
	Ended = "ENDED",
}

local function clockText(minutes: number): string
	const total = math.floor(minutes)
	return string.format("%02d:%02d", (total // 60) % 24, total % 60)
end

local function toneOf(action: string): Theme.Tone
	if action == "trigger" then
		return Theme.Tone.Mustard
	elseif action == "resolve" then
		return Theme.Tone.Green
	elseif action == "wrong" then
		return Theme.Tone.Ketchup
	elseif action == "stop" or action == "reset" or action == "scarestop" then
		return Theme.Tone.Violet
	end
	return Theme.Tone.Teal
end

local function button(label: string, tone: (() -> Theme.Tone) | Theme.Tone, onClick: () -> ()): TextButton
	return CartoonButton({
		Text = label,
		TextSize = TEXT,
		Tone = tone,
		Size = UDim2.fromOffset(0, BUTTON_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		Padding = 10,
		Selectable = false,
		OnActivated = onClick,
	})
end

-- Horizontal wrapping strip of buttons
local function strip(order: number, children: { any }): Frame
	return create("Frame")({
		Name = `Strip{order}`,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Wraps = true,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		children,
	}) :: Frame
end

local function label(
	text: (() -> string) | string,
	order: number,
	color: Color3?,
	dark: boolean?
): TextLabel
	return CartoonLabel({
		LayoutOrder = order,
		Box = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = TEXT,
		XAlignment = Enum.TextXAlignment.Left,
		YAlignment = Enum.TextYAlignment.Top,
		Wrapped = true,
		Color = color or (if dark then Theme.Color.Dark else Theme.Color.Text),
		Stroke = if dark then 0 else nil,
		Text = text,
	})
end

return function(props: Props): Frame
	const state = props.State

	local function onOf(flag: () -> boolean): () -> Theme.Tone
		return function(): Theme.Tone
			return if flag() then Theme.Tone.Green else Theme.Tone.Teal
		end
	end

	const readout = function(): string
		const s = state()
		const night = if s.Night > 0 then `Night {s.Night}` else "Day"
		const sanity = if s.SanityMax > 0 then `{s.Sanity}/{s.SanityMax}` else "none (day)"
		return `{night} {s.Phase}  {clockText(s.Clock)}{if s.Frozen then " (frozen)" else ""}`
			.. `\nSanity {sanity}  Life {s.Life}  revives {s.Revives}`
			.. `\nVehicle {s.Vehicle}  light {if s.Switch then "on" else "off"}  window {if s.Shutter then "closed" else "open"}`
	end

	-- state line of an anomaly card
	local function liveText(item: Item): string
		if item.Ref == "" or item.Tab ~= "Anomalies" then
			return ""
		end
		for _, occurrence in state().Running do
			if occurrence.Ref == item.Ref then
				const phase = PHASE_LABEL[occurrence.Phase] or occurrence.Phase
				const step = if occurrence.Step > 0 then ` step {occurrence.Step}` else ""
				return if occurrence.Live
					then `> {phase}{step} ({string.format("%.0f", occurrence.Age)}s)`
					else `last: {phase}{step} ({string.format("%.0f", occurrence.Age)}s ago)`
			end
		end
		return "idle"
	end

	local function card(item: Item, order: number): Frame
		const actions: { any } = {}
		for _, action in item.Actions do
			table.insert(
				actions,
				button(action.Label, toneOf(action.Id), function()
					props.OnAction(action.Id, item.Id, action.Arg, 0)
				end)
			)
		end
		const title = if item.Ref ~= "" and item.Ref ~= item.Name then `{item.Name}  [{item.Ref}]` else item.Name
		return CartoonPanel({
			Name = item.Id,
			LayoutOrder = order,
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Normal,
			Radius = Theme.Radius.Card,
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Padding = 8,
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 3),
				}),
				CartoonLabel({
					LayoutOrder = 1,
					Box = UDim2.new(1, 0, 0, 20),
					TextSize = 17,
					XAlignment = Enum.TextXAlignment.Left,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Truncate = true,
					Text = title,
				}),
				label(item.Desc, 2, Theme.Color.Dark, true),
				label(`Verb: {item.Verb}`, 3, Color3.fromHex("#8A5A00"), true),
				label(function()
					return liveText(item)
				end, 4, Color3.fromHex("#256E7A"), true),
				strip(5, actions),
			},
		}) :: Frame
	end

	local function row(entry: Row, index: () -> number): Frame
		if entry.Kind == "Group" then
			return CartoonLabel({
				Name = "Group",
				LayoutOrder = index,
				Box = UDim2.new(1, -6, 0, 22),
				TextSize = 16,
				XAlignment = Enum.TextXAlignment.Left,
				Color = Theme.Color.Gold,
				Text = entry.Title,
			}) :: any
		end
		return card(entry.Item :: Item, index())
	end

	-- header: close and readout
	const header = create("Frame")({
		Name = "Header",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		strip(1, {
			CartoonLabel({
				LayoutOrder = 0,
				TextSize = 20,
				Color = Theme.Color.Mustard,
				Text = "SHOWCASE (dev)",
			}),
			button("Close (F9)", Theme.Tone.Slate, props.OnClose),
		}),
		label(readout, 2, Theme.Color.Cream, false),
		-- Night 1..10
		strip(3, (function(): { any }
			const list: { any } = {
				CartoonLabel({ LayoutOrder = 0, TextSize = TEXT, Text = "Night:" }),
			}
			for _, night in NIGHTS do
				table.insert(
					list,
					button(tostring(night), function(): Theme.Tone
						return if state().Night == night then Theme.Tone.Green else Theme.Tone.Teal
					end, function()
						props.OnAction("ctl", "night", "", night)
					end)
				)
			end
			return list
		end)()),
		-- Clock
		strip(4, (function(): { any }
			const list: { any } = {
				CartoonLabel({ LayoutOrder = 0, TextSize = TEXT, Text = "Clock:" }),
			}
			for _, entry in CLOCKS do
				const minutes = entry[2] :: number
				table.insert(
					list,
					button(entry[1] :: string, Theme.Tone.Teal, function()
						props.OnAction("ctl", "clock", "", minutes)
					end)
				)
			end
			table.insert(
				list,
				button("Freeze", onOf(function()
					return state().Frozen
				end), function()
					props.OnAction("ctl", "freeze", "", 0)
				end)
			)
			table.insert(
				list,
				button("Skip to dawn", Theme.Tone.Mustard, function()
					props.OnAction("ctl", "dawn", "", 0)
				end)
			)
			return list
		end)()),
		-- Sanity, flags
		strip(5, {
			CartoonLabel({ LayoutOrder = 0, TextSize = TEXT, Text = "Sanity:" }),
			button("-10", Theme.Tone.Teal, function()
				props.OnAction("ctl", "sanity", "-10", 0)
			end),
			button("+10", Theme.Tone.Teal, function()
				props.OnAction("ctl", "sanity", "+10", 0)
			end),
			button("Max", Theme.Tone.Teal, function()
				props.OnAction("ctl", "sanity", "max", 0)
			end),
			button("0 (falls)", Theme.Tone.Ketchup, function()
				props.OnAction("ctl", "sanity", "0", 0)
			end),
			button("No faint", onOf(function()
				return state().God
			end), function()
				props.OnAction("ctl", "god", "", 0)
			end),
		}),
		strip(6, {
			CartoonLabel({ LayoutOrder = 0, TextSize = TEXT, Text = "Dark:" }),
			button("Auto", function(): Theme.Tone
				return if state().Dark == "auto" then Theme.Tone.Green else Theme.Tone.Teal
			end, function()
				props.OnAction("sc", "world", "dark:auto", 0)
			end),
			button("Force dark", function(): Theme.Tone
				return if state().Dark == "dark" then Theme.Tone.Green else Theme.Tone.Teal
			end, function()
				props.OnAction("sc", "world", "dark:on", 0)
			end),
			button("Force lit", function(): Theme.Tone
				return if state().Dark == "lit" then Theme.Tone.Green else Theme.Tone.Teal
			end, function()
				props.OnAction("sc", "world", "dark:off", 0)
			end),
			button("Agenda held", onOf(function()
				return state().Held
			end), function()
				props.OnAction("ctl", "hold", "", 0)
			end),
			button("Stop all", Theme.Tone.Violet, function()
				props.OnAction("ctl", "stopall", "", 0)
			end),
			button("Reset all", Theme.Tone.Ketchup, function()
				props.OnAction("ctl", "resetall", "", 0)
			end),
		}),
	})

	const tabs = (function(): { any }
		const list: { any } = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		}
		for index, tab in props.Tabs do
			table.insert(
				list,
				CartoonButton({
					Name = tab,
					LayoutOrder = index,
					Text = tab,
					TextSize = 16,
					Size = UDim2.fromOffset(0, 34),
					AutomaticSize = Enum.AutomaticSize.X,
					Padding = 14,
					Selectable = false,
					Tone = function(): Theme.Tone
						return if props.Tab() == tab then Theme.Tone.Mustard else Theme.Tone.Slate
					end,
					Enabled = true,
					OnActivated = function()
						props.OnTab(tab)
					end,
				})
			)
		end
		return list
	end)()

	return create("Frame")({
		Name = props.Name or "ShowcasePanel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = function()
			return UDim2.fromOffset(WIDTH, props.Viewport().Y * 0.96 / (props.Scale() * SCALE_FACTOR))
		end,
		BackgroundTransparency = 1,
		Visible = props.Shown,
		createRaw("UIScale")({
			Scale = function()
				return props.Scale() * SCALE_FACTOR
			end,
		}),
		CartoonPanel({
			Name = "Card",
			Tone = Theme.Tone.Ink,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Size = UDim2.fromScale(1, 1),
			Padding = 10,
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				header,
				create("Frame")({
					Name = "Tabs",
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 38),
					BackgroundTransparency = 1,
					tabs,
				}),
				createRaw("ScrollingFrame")({
					Name = "List",
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 1, -300),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 5,
					ScrollBarImageColor3 = Theme.Color.Cream,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					Selectable = false,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					values(props.Rows, row),
				}),
				CartoonLabel({
					Name = "Log",
					LayoutOrder = 4,
					Box = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					TextSize = TEXT,
					XAlignment = Enum.TextXAlignment.Left,
					Wrapped = true,
					Color = function(): Color3
						const kind = props.LogKind()
						return if kind == "error"
							then Theme.Color.NoCash
							elseif kind == "ok" then Theme.Color.Ready
							else Theme.Color.Cream
					end,
					Text = props.LogText,
				}),
			},
		}),
	}) :: Frame
end
