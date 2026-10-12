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
-- Layout (Layout.luau) is computed from the area of the ScreenGui divided by the global UI scale (Theme.ScaleOf): phone
-- landscape 667 x 375 up, desktop, portrait. The ScreenGui must use ScreenInsets = DeviceSafeInsets (the spec margins are
-- inside the safe area). Tabs and buttons are CartoonButtons: touch targets >= 44 px, Selectable for the gamepad. No red.
-- Pure: only props, no network, no input binding (the PrepController binds keys and the gamepad). Build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale, UIStroke and UIGradient are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Tab = { Key: string, Label: string, Icon: string }

export type Pip = { Label: string, Grade: Seal.Grade? }

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

export type Toast = { Text: string, Kind: "Info" | "Good" | "Alert", Id: number }

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
	Name: string?,
}

const BADGE_TONE: { [string]: Theme.Tone } = {
	Order = Theme.Tone.Teal,
	Grill = Theme.Tone.Green,
	Build = Theme.Tone.Cream,
	Serve = Theme.Tone.Mustard,
}
const LIFT = 3 -- px the active tab rises
const PULSES = 3
const PULSE_TIME = 0.6
const SHAKE_TIME = 0.18
const VIGNETTE = 0.35

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
	const layout = Vide.derive(function(): Layout.Result
		return Layout.Compute(canvas(), props.HasPanel(), #tabs, activeIndex())
	end)

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

	-- Leave: on screen whenever the chrome is
	const leave = CartoonButton({
		Name = "Leave",
		Tone = Theme.Tone.Cream,
		Position = at(function(l)
			return l.Leave
		end),
		Size = sized(function(l)
			return l.Leave
		end),
		Padding = 0,
		OnActivated = props.OnLeave,
		Children = {
			CartoonLabel({
				Text = function()
					return if layout().LeaveWide then (props.LeaveText or "Leave") else "Exit"
				end,
				TextSize = 16,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Box = UDim2.fromScale(1, 1),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})

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
					CartoonLabel({
						Text = function()
							const l = layout()
							return if l.TabsCompact and not isActive() then string.sub(tab.Label, 1, 1) else tab.Label
						end,
						TextSize = 16,
						Color = Theme.Color.Ink,
						Stroke = 0,
						Box = UDim2.fromScale(1, 1),
						XAlignment = Enum.TextXAlignment.Center,
						YAlignment = Enum.TextYAlignment.Center,
					}),
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
			return props.IsNight() and value ~= nil
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
		Visible = props.HasPanel,
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
		Visible = props.Trash.Visible,
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

	-- assist toggle
	const assist = CartoonButton({
		Name = "Assist",
		Tone = function()
			return if props.Assist.On() then Theme.Tone.Teal else Theme.Tone.Cream
		end,
		Outline = function()
			return if props.Assist.On() then Theme.Outline.Thick else Theme.Outline.Normal
		end,
		Radius = Theme.Radius.Chip,
		Position = at(function(l)
			return l.Assist
		end),
		Size = sized(function(l)
			return l.Assist
		end),
		Padding = 0,
		OnActivated = props.Assist.OnToggle,
		Children = {
			CartoonLabel({
				Text = props.Assist.Label,
				TextSize = Theme.MinTextSize,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Box = UDim2.fromScale(1, 1),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
			}),
			-- on: a Green dot in the corner (a mark, not just a tone)
			create("Frame")({
				Name = "On",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, -2),
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = Theme.Tone.Green.Bottom,
				ZIndex = 5,
				Visible = props.Assist.On,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			}),
		},
	})

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
			leave,
			tabButtons,
			status,
			strip,
			nextHolder,
			trash,
			assist,
			toast,
		}),
	})

	vignette.Parent = root
	canvasFrame.Parent = root
	return root
end
