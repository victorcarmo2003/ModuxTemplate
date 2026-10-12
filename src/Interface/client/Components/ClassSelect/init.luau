--!strict
-- ClassSelect: the lobby class screen (user request 2026-10-11, "Animal Hospital" style), cartoon kit (AST-091).
-- Laid out for the smallest landscape phone (620 x 340 px at Scale 1, inside CoreUISafeInsets); `Scale` grows it.
--   centre   the class rig standing, facing the camera: the world stage (LobbyController moves the camera, nothing
--            here) or `Stage` (a ClassStage viewport) behind the panels; arrows under it cycle the classes
--   left     Ink list of every class (Content.Classes): icon, name, animal, lock / "Soon" / equipped check
--   right    Cream card of the focused class: name, animal, perk / drawback lines, and the buttons:
--              not owned   "Buy  45" (gems, Mustard; Slate "Need 45" without the gems) + "Buy  R$ 79" (Robux,
--                          Green; Slate "Robux (soon)" while the product id is 0)
--              owned       "Equip" (Mustard) / "Equipped" (Green, not pressable)
--              not in MVP  "Coming soon" (Slate)
-- The card pops on every class change. No backdrop: the rig shows through the middle. Pure: only props; the caller
-- sends the requests and the server decides (Profile / Wallet / ClassBuyResult).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local UiScale = require(script.Parent.UiScale)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Icon = require(script.Parent.LobbyWindow.Icon)

const create = Vide.create
const effect = Vide.effect
const source = Vide.source
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale, UIPadding, ScrollingFrame are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Entry = {
	Key: string, -- Content.Classes key
	Title: string,
	Animal: string,
	Species: string,
	Badge: string, -- placeholder letter
	Icon: string, -- Icons name ("Class/class_fox"); unknown = Badge
	Price: number, -- gems
	Available: boolean, -- InMvp: false = "Coming soon"
	Perks: { string },
	Drawbacks: { string },
	Notes: { string }, -- neutral lines (no effect)
}

-- Equipped: owned and selected · Owned · Locked: for sale, not owned · Soon: not in the MVP
export type State = "Equipped" | "Owned" | "Locked" | "Soon"

export type Props = {
	Entries: { Entry },
	Visible: () -> boolean,
	Gems: () -> number,
	Focus: () -> string,
	StateOf: (key: string) -> State,
	-- Robux price of a class; nil = product not created yet (the Robux button shows disabled).
	RobuxOf: (key: string) -> number?,
	-- A request is on its way (or the profile has not arrived): the buttons are disabled.
	Busy: () -> boolean,
	OnFocus: (key: string) -> (),
	OnBuyGems: (key: string) -> (),
	OnBuyRobux: (key: string) -> (),
	OnEquip: (key: string) -> (),
	OnClose: () -> (),
	-- Viewport stage (ClassStage) drawn behind the panels; nil = world stage.
	Stage: Instance?,
	Scale: (() -> number)?,
}

const MARGIN = 12
const HEADER = 44
const TOP = 60
const BODY = 268 -- 340 - TOP - MARGIN
const LIST_WIDTH = 196
const CARD_WIDTH = 226
const ROW = 52
const ROW_GAP = 6
const PAD = 10
const BUTTON = 44
const ARROW = 48
const DESIGN = Vector2.new(620, 340)

type Line = { Text: string, Icon: string, Fallback: string, Color: Color3 }

local function lines(entry: Entry): { Line }
	const out: { Line } = {}
	for _, text in entry.Perks do
		table.insert(out, { Text = text, Icon = "Ui/check", Fallback = "+", Color = Theme.Color.Green })
	end
	for _, text in entry.Drawbacks do
		table.insert(out, { Text = text, Icon = "Ui/warning", Fallback = "-", Color = Theme.Color.Mustard })
	end
	for _, text in entry.Notes do
		table.insert(out, { Text = text, Icon = "Ui/info", Fallback = "i", Color = Theme.Color.Teal })
	end
	return out
end

return function(props: Props): Frame
	const byKey: { [string]: Entry } = {}
	for _, entry in props.Entries do
		byKey[entry.Key] = entry
	end
	const first = props.Entries[1]
	local function focused(): Entry
		return byKey[props.Focus()] or first
	end
	local function step(delta: number)
		const key = untrack(focused).Key
		local index = 1
		for i, entry in props.Entries do
			if entry.Key == key then
				index = i
			end
		end
		const n = #props.Entries
		props.OnFocus(props.Entries[(index - 1 + delta) % n + 1].Key)
	end

	-- Real px size of the screen (this root fills it): the screen shrinks to fit a narrow one (design 620 x 340).
	const area = source(Vector2.zero)
	const scale = function(): number
		const base = if props.Scale then math.max(math.min(props.Scale(), UiScale.Current()), Theme.Scale.Min) else 1
		return UiScale.Fit(base, area(), DESIGN)
	end
	const pop = Motion.Pop(props.Visible)
	const scaled = function(): number
		return scale() * pop()
	end

	-- List rows ---------------------------------------------------------------------------------------------------
	const rows: { Instance } = {}
	for index, entry in props.Entries do
		const state = function(): State
			return props.StateOf(entry.Key)
		end
		const isFocused = function(): boolean
			return focused().Key == entry.Key
		end
		table.insert(
			rows,
			CartoonButton({
				Name = entry.Key,
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, ROW),
				Tone = function()
					return if isFocused() then Theme.Tone.Mustard else Theme.Tone.Cream
				end,
				Outline = function()
					return if isFocused() then Theme.Outline.Thick else Theme.Outline.Normal
				end,
				Radius = Theme.Radius.Chip,
				Padding = 6,
				OnActivated = function()
					props.OnFocus(entry.Key)
				end,
				SelectionGained = function()
					props.OnFocus(entry.Key)
				end,
				Children = {
					-- portrait
					CartoonPanel({
						Name = "Portrait",
						Size = UDim2.fromOffset(ROW - 16, ROW - 16),
						Tone = Theme.Tone.White,
						Radius = Theme.Radius.Small,
						Lip = 2,
						Outline = 2,
						Gloss = false,
						Children = {
							create("UIListLayout")({
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							Icon(entry.Icon, ROW - 18, 1),
							CartoonLabel({
								Box = UDim2.fromScale(1, 1),
								TextSize = 20,
								Color = Theme.Color.Dark,
								Stroke = 0,
								Text = entry.Badge,
								Visible = not Icons.Has(entry.Icon),
							}),
						},
					}),
					CartoonLabel({
						Name = "Title",
						Position = UDim2.fromOffset(ROW - 8, -2),
						Box = UDim2.new(1, -(ROW - 8) - 30, 0, 22),
						TextSize = 18,
						XAlignment = Enum.TextXAlignment.Left,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Truncate = true,
						Text = entry.Title,
					}),
					CartoonLabel({
						Name = "Animal",
						Position = UDim2.fromOffset(ROW - 8, 18),
						Box = UDim2.new(1, -(ROW - 8) - 30, 0, 18),
						TextSize = Theme.MinTextSize,
						XAlignment = Enum.TextXAlignment.Left,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Transparency = 0.3,
						Truncate = true,
						Text = entry.Animal,
					}),
					-- status on the right: lock, check, "Soon"
					create("Frame")({
						Name = "Status",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, 0, 0.5, -2),
						Size = UDim2.fromOffset(28, 28),
						BackgroundTransparency = 1,
						Icon(function()
							const s = state()
							return if s == "Locked"
								then "Notice/lock"
								elseif s == "Equipped" then "Ui/check"
								else ""
						end, 28, 1),
						CartoonLabel({
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							TextSize = Theme.MinTextSize,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Text = function()
								const s = state()
								if s == "Soon" then
									return "Soon"
								elseif s == "Locked" and not Icons.Has("Notice/lock") then
									return "Lock"
								elseif s == "Equipped" and not Icons.Has("Ui/check") then
									return "On"
								end
								return ""
							end,
						}),
					}),
				},
			})
		)
	end

	-- Card of the focused class -----------------------------------------------------------------------------------
	const cardPop = createRaw("UIScale")({ Scale = 1 }) :: UIScale
	effect(function()
		props.Focus()
		if not untrack(props.Visible) then
			return
		end
		cardPop.Scale = 0.88
		TweenService:Create(
			cardPop,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end)

	const state = function(): State
		return props.StateOf(focused().Key)
	end
	const robux = function(): number?
		return props.RobuxOf(focused().Key)
	end
	const canGems = function(): boolean
		return props.Gems() >= focused().Price
	end

	const buttons: { any } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		-- Buy with gems
		CartoonButton({
			Name = "BuyGems",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, BUTTON),
			TextSize = 18,
			Outline = Theme.Outline.Thick,
			Icon = "Hud/gem",
			IconSize = 28,
			Visible = function()
				return state() == "Locked"
			end,
			Tone = Theme.Tone.Mustard,
			Enabled = function()
				return canGems() and not props.Busy()
			end,
			Text = function()
				if props.Busy() then
					return "..."
				end
				const price = focused().Price
				return if canGems() then `Buy  {price}` else `Need {price}`
			end,
			OnActivated = function()
				props.OnBuyGems(focused().Key)
			end,
		}),
		-- Buy with Robux
		CartoonButton({
			Name = "BuyRobux",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, BUTTON),
			TextSize = 18,
			Outline = Theme.Outline.Thick,
			Visible = function()
				return state() == "Locked"
			end,
			Tone = Theme.Tone.Green,
			Enabled = function()
				return robux() ~= nil and not props.Busy()
			end,
			Text = function()
				const price = robux()
				if price == nil then
					return "Robux (soon)"
				end
				return if price > 0 then `Buy  R$ {price}` else "Buy with Robux"
			end,
			OnActivated = function()
				props.OnBuyRobux(focused().Key)
			end,
		}),
		-- Equip / Equipped / Coming soon
		CartoonButton({
			Name = "Equip",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, BUTTON),
			TextSize = 20,
			Outline = Theme.Outline.Thick,
			Icon = function()
				return if state() == "Equipped" then "Ui/check" else ""
			end,
			IconSize = 26,
			Visible = function()
				return state() ~= "Locked"
			end,
			Tone = function()
				const s = state()
				return if s == "Equipped" then Theme.Tone.Green else Theme.Tone.Mustard
			end,
			Enabled = function()
				return state() == "Owned" and not props.Busy()
			end,
			Text = function()
				const s = state()
				if s == "Equipped" then
					return "Equipped"
				elseif s == "Soon" then
					return "Coming soon"
				end
				return if props.Busy() then "..." else "Equip"
			end,
			OnActivated = function()
				props.OnEquip(focused().Key)
			end,
		}),
	}

	const textWidth = CARD_WIDTH - PAD * 2 - 8 - 24
	const root = create("Frame")({
		Name = "ClassSelect",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = true,
		Visible = props.Visible,

		-- stage (viewport fallback) under everything
		if props.Stage
			then create("Frame")({
				Name = "StageAnchor",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -MARGIN),
				Size = UDim2.fromOffset(200, BODY + 20),
				BackgroundTransparency = 1,
				ZIndex = 0,
				createRaw("UIScale")({ Scale = scale }),
				props.Stage,
			})
			else nil,

		-- header: title tab
		create("Frame")({
			Name = "TitleAnchor",
			Position = UDim2.fromOffset(MARGIN, 8),
			Size = UDim2.fromOffset(0, HEADER),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			CartoonPanel({
				Name = "Title",
				Size = UDim2.fromOffset(0, HEADER),
				AutomaticSize = Enum.AutomaticSize.X,
				Rotation = -2,
				Tone = Theme.Tone.Mustard,
				Padding = { Left = 8, Right = 16 },
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					Icon("Ui/paw", HEADER - 12, 1),
					CartoonLabel({
						LayoutOrder = 2,
						TextSize = 26,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Text = "Classes",
					}),
				},
			}),
		}),

		-- header: gems + close
		create("Frame")({
			Name = "TopRight",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -MARGIN, 0, 8),
			Size = UDim2.fromOffset(0, HEADER),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			CartoonPanel({
				Name = "Gems",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(96, HEADER),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = Theme.Tone.Ink,
				Padding = { Left = 4, Right = 14 },
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					Icon("Hud/gem", HEADER - 6, 1),
					CartoonLabel({
						Name = "Amount",
						LayoutOrder = 2,
						TextSize = 22,
						Text = function()
							return tostring(props.Gems())
						end,
					}),
				},
			}),
			CartoonButton({
				Name = "Close",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(HEADER, HEADER),
				Tone = Theme.Tone.Teal,
				OnActivated = props.OnClose,
				Children = {
					create("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Icon("Ui/close", HEADER - 16, 1),
					CartoonLabel({
						LayoutOrder = 2,
						TextSize = 22,
						Text = "X",
						Visible = not Icons.Has("Ui/close"),
					}),
				},
			}),
		}),

		-- left: class list
		create("Frame")({
			Name = "ListAnchor",
			Position = UDim2.fromOffset(MARGIN, TOP),
			Size = UDim2.fromOffset(LIST_WIDTH, BODY),
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			CartoonPanel({
				Name = "List",
				Size = UDim2.fromScale(1, 1),
				Tone = Theme.Tone.Ink,
				Outline = Theme.Outline.Thick,
				Radius = Theme.Radius.Card,
				Studs = true,
				Gloss = false,
				Padding = { Top = 8, Bottom = 6, Left = 8, Right = 4 },
				Children = {
					createRaw("ScrollingFrame")({
						Name = "Rows",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 4,
						ScrollBarImageColor3 = Theme.Color.Cream,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						Selectable = false,
						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, ROW_GAP),
						}),
						createRaw("UIPadding")({
							PaddingTop = UDim.new(0, 2),
							PaddingBottom = UDim.new(0, 6),
							PaddingLeft = UDim.new(0, 2),
						}),
						rows,
					}),
				},
			}),
		}),

		-- right: card of the focused class
		create("Frame")({
			Name = "CardAnchor",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -MARGIN, 0, TOP),
			Size = UDim2.fromOffset(CARD_WIDTH, BODY),
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			CartoonPanel({
				Name = "Card",
				Size = UDim2.fromScale(1, 1),
				Tone = Theme.Tone.Cream,
				Outline = Theme.Outline.Thick,
				Radius = Theme.Radius.Card,
				Padding = PAD,
				Decor = { cardPop },
				Children = {
					CartoonLabel({
						Name = "Name",
						Box = UDim2.new(1, 0, 0, 28),
						TextSize = 24,
						XAlignment = Enum.TextXAlignment.Left,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Truncate = true,
						Text = function()
							return focused().Title
						end,
					}),
					CartoonLabel({
						Name = "Animal",
						Position = UDim2.fromOffset(0, 28),
						Box = UDim2.new(1, 0, 0, 20),
						TextSize = 16,
						XAlignment = Enum.TextXAlignment.Left,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Transparency = 0.3,
						Text = function()
							const entry = focused()
							return if entry.Price > 0 then `{entry.Animal} · {entry.Price} Gems` else `{entry.Animal} · Free`
						end,
					}),
					-- perk / drawback lines
					create("Frame")({
						Name = "Lines",
						Position = UDim2.fromOffset(0, 54),
						Size = UDim2.new(1, 0, 1, -54 - (BUTTON * 2 + 6) - 6),
						BackgroundTransparency = 1,
						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 4),
						}),
						Vide.indexes(function()
							return lines(focused())
						end, function(line: () -> Line, index: number)
							return create("Frame")({
								Name = "Line",
								LayoutOrder = index,
								Size = UDim2.new(1, 0, 0, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								Icon(function()
									return line().Icon
								end, 20, 0),
								CartoonLabel({
									Box = UDim2.fromOffset(20, 20),
									TextSize = 16,
									Color = function()
										return line().Color
									end,
									Stroke = 0,
									Text = function()
										return line().Fallback
									end,
									Visible = function()
										return not Icons.Has(line().Icon)
									end,
								}),
								CartoonLabel({
									Position = UDim2.fromOffset(26, 0),
									Box = UDim2.fromOffset(textWidth, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
									TextSize = Theme.MinTextSize,
									XAlignment = Enum.TextXAlignment.Left,
									YAlignment = Enum.TextYAlignment.Top,
									Wrapped = true,
									Color = Theme.Color.Dark,
									Stroke = 0,
									Text = function()
										return line().Text
									end,
								}),
							})
						end),
					}),
					-- buttons pinned to the bottom
					create("Frame")({
						Name = "Buttons",
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, BUTTON * 2 + 6),
						BackgroundTransparency = 1,
						buttons,
					}),
				},
			}),
		}),

		-- arrows under the rig
		create("Frame")({
			Name = "Arrows",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -MARGIN),
			Size = UDim2.fromOffset(ARROW * 2 + 64, ARROW),
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			CartoonButton({
				Name = "Previous",
				Size = UDim2.fromOffset(ARROW, ARROW),
				Tone = Theme.Tone.Teal,
				OnActivated = function()
					step(-1)
				end,
				Children = {
					create("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Icon("Ui/arrow_left", ARROW - 16, 1),
					CartoonLabel({
						Box = UDim2.fromScale(1, 1),
						TextSize = 22,
						Text = "<",
						Visible = not Icons.Has("Ui/arrow_left"),
					}),
				},
			}),
			CartoonButton({
				Name = "Next",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(ARROW, ARROW),
				Tone = Theme.Tone.Teal,
				OnActivated = function()
					step(1)
				end,
				Children = {
					create("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Icon("Ui/arrow_right", ARROW - 16, 1),
					CartoonLabel({
						Box = UDim2.fromScale(1, 1),
						TextSize = 22,
						Text = ">",
						Visible = not Icons.Has("Ui/arrow_right"),
					}),
				},
			}),
		}),
	}) :: Frame
	const measure = function()
		if root.AbsoluteSize.X > 0 then
			area(root.AbsoluteSize)
		end
	end
	const connection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
	cleanup(function()
		connection:Disconnect()
	end)
	return root
end
