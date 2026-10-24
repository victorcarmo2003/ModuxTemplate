--!strict
--[[
	Paper: the SurfaceGui of Walt's notes (owner request 2026-10-22, Provisional; Content.Hints), drawn on the top face of the
	paper of the front counter. Pure: only props; build it inside a Vide root (HintController mounts it in PlayerGui with
	Adornee = the paper, so the place's static "NoteFace" can stay as the edit-mode look).

	Canvas: CANVAS_WIDTH px wide (the paper's Z side) and as tall as the paper's X side at the same density (Face Top: the
	text's up is the part's -X; Studio test 2026-10-22). Notebook paper: a margin line, "NOTES" in marker, a "NEW!" sticker
	until the player reads it, and a ScrollingFrame with every tip written so far, newest on top, each under its "NIGHT k".
	The newest tip writes itself in (MaxVisibleGraphemes) while the pencil is heard (Reveal). Scrolling is the
	controller's (drag, wheel, stick, keys): it writes Scroll; the frame never takes input itself (ScrollingEnabled off, the
	thumb is drawn here).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)

-- Vide 0.4.1 types `create` for some classes only: one untyped door for every class here
const create = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Adornee: () -> BasePart?,
	Height: () -> number, -- canvas height in px
	PixelsPerStud: () -> number,
	Written: () -> number, -- the last night whose tip is on the paper
	Unread: () -> boolean,
	Reading: () -> boolean,
	Clock: () -> number, -- os.clock() while something animates
	Reveal: () -> number, -- os.clock() of the last tip written live (0 = none)
	Scroll: () -> number, -- CanvasPosition.Y
	OnList: (list: ScrollingFrame) -> (),
}

const RULES = Content.Hints.Rules
const CANVAS_WIDTH = 300 -- px across the paper
const PAPER = Color3.fromRGB(255, 248, 234)
const GRAPHITE = Color3.fromRGB(52, 56, 68)
const SOFT = Color3.fromRGB(110, 116, 132)
const RULE = Color3.fromRGB(150, 190, 225)
const MARGIN = Color3.fromRGB(233, 167, 154)
const MUSTARD = Color3.fromHex("#F6C12B")
const INK = Color3.fromHex("#2B2118")
const MARGIN_X = 34
const LIST_TOP = 70
const TITLE_FONT = Font.fromEnum(Enum.Font.PermanentMarker)
const HAND_FONT = Font.fromEnum(Enum.Font.PatrickHand)
const STICKER_FONT = Font.fromEnum(Enum.Font.FredokaOne)
const LINE_SIZE = 23
const NIGHT_SIZE = 17
const CHARS_PER_SECOND = 22 -- the newest tip writes itself in at this speed after the pencil starts

local function rule(y: number): Instance
	return create("Frame")({
		Name = "Rule",
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = RULE,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	})
end

-- The tips of the paper, newest first
local function written(night: number): { Content.Hint }
	const out: { Content.Hint } = {}
	for index = math.min(night, #Content.Hints.List), 1, -1 do
		const row = Content.Hints.ByNight[index]
		if row ~= nil then
			table.insert(out, row)
		end
	end
	return out
end

return function(props: Props): (SurfaceGui, ScrollingFrame)
	-- graphemes shown of line `index` of the newest tip while it writes itself in (-1 = all)
	local function revealOf(lines: { string }, index: number): number
		const started = props.Reveal()
		if started <= 0 then
			return -1
		end
		const typed = math.floor((props.Clock() - started) * CHARS_PER_SECOND)
		local before = 0
		for other = 1, index - 1 do
			before += utf8.len(lines[other]) or #lines[other]
		end
		const total = before + (utf8.len(lines[index]) or #lines[index])
		if typed >= total then
			return -1
		end
		return math.max(typed - before, 0)
	end

	local function entry(row: () -> Content.Hint, order: number): Instance
		return create("Frame")({
			Name = "Tip",
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 1),
			}),
			create("TextLabel")({
				Name = "Night",
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, NIGHT_SIZE + 4),
				BackgroundTransparency = 1,
				FontFace = TITLE_FONT,
				TextSize = NIGHT_SIZE,
				TextColor3 = SOFT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = function()
					return `NIGHT {row().Night}`
				end,
			}),
			Vide.indexes(function()
				return row().Lines
			end, function(line: () -> string, index: number): Instance
				return create("TextLabel")({
					Name = "Line",
					LayoutOrder = index,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					FontFace = HAND_FONT,
					TextSize = LINE_SIZE,
					LineHeight = 0.95,
					TextColor3 = GRAPHITE,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = line,
					MaxVisibleGraphemes = function(): number
						-- only the newest tip (order 1) writes itself in
						if order ~= 1 then
							return -1
						end
						return revealOf(row().Lines, index)
					end,
				})
			end),
			create("Frame")({
				Name = "Gap",
				LayoutOrder = 1000,
				Size = UDim2.new(1, 0, 0, 10),
				BackgroundTransparency = 1,
			}),
		})
	end

	local list: ScrollingFrame
	list = create("ScrollingFrame")({
		Name = "List",
		Position = UDim2.fromOffset(MARGIN_X + 8, LIST_TOP),
		Size = function()
			return UDim2.fromOffset(CANVAS_WIDTH - MARGIN_X - 22, math.max(props.Height() - LIST_TOP - 10, 40))
		end,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingEnabled = false,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		CanvasPosition = function()
			return Vector2.new(0, props.Scroll())
		end,
		create("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		create("UIPadding")({
			PaddingBottom = UDim.new(0, 14),
		}),
		create("TextLabel")({
			Name = "Empty",
			LayoutOrder = 0,
			Visible = function()
				return props.Written() <= 0
			end,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = HAND_FONT,
			TextSize = LINE_SIZE,
			TextColor3 = SOFT,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = RULES.Empty,
		}),
		Vide.indexes(function()
			return written(props.Written())
		end, entry),
	}) :: ScrollingFrame

	-- the drawn scroll thumb (the frame's own bar is off)
	const thumb = create("Frame")({
		Name = "Thumb",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = SOFT,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
	}) :: Frame
	local function placeThumb()
		const window = list.AbsoluteWindowSize.Y
		const content = list.AbsoluteCanvasSize.Y
		const top = LIST_TOP
		const room = math.max(props.Height() - LIST_TOP - 10, 40)
		if content <= window + 1 or window <= 0 then
			thumb.Visible = false
			return
		end
		thumb.Visible = true
		const length = math.max(room * window / content, 24)
		const fraction = math.clamp(list.CanvasPosition.Y / (content - window), 0, 1)
		thumb.Size = UDim2.fromOffset(4, length)
		thumb.Position = UDim2.fromOffset(CANVAS_WIDTH - 6, top + (room - length) * fraction)
	end
	list:GetPropertyChangedSignal("CanvasPosition"):Connect(placeThumb)
	list:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(placeThumb)
	list:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(placeThumb)
	Vide.effect(function()
		props.Height()
		placeThumb()
	end)

	const surface = create("SurfaceGui")({
		Name = "HintNotes",
		Face = Enum.NormalId.Top,
		Adornee = props.Adornee,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = props.PixelsPerStud,
		-- legible in the close-up whatever the lights; part of the room otherwise
		LightInfluence = function()
			return if props.Reading() then 0 else 0.6
		end,
		Brightness = 1,
		MaxDistance = 60,
		ClipsDescendants = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		create("Frame")({
			Name = "Paper",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = PAPER,
			BorderSizePixel = 0,
			create("Frame")({
				Name = "Margin",
				Position = UDim2.fromOffset(MARGIN_X, 0),
				Size = UDim2.new(0, 2, 1, 0),
				BackgroundColor3 = MARGIN,
				BorderSizePixel = 0,
			}),
			rule(LIST_TOP - 6),
			create("TextLabel")({
				Name = "Title",
				Position = UDim2.fromOffset(MARGIN_X + 8, 8),
				Size = UDim2.fromOffset(170, 50),
				BackgroundTransparency = 1,
				FontFace = TITLE_FONT,
				TextSize = 38,
				TextColor3 = GRAPHITE,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = RULES.Title,
			}),
			list,
			thumb,
			-- "NEW!" until this player reads the paper; it breathes so it reads from across the counter
			create("TextLabel")({
				Name = "New",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(CANVAS_WIDTH - 44, 36),
				Size = UDim2.fromOffset(70, 70),
				Rotation = 12,
				Visible = props.Unread,
				BackgroundColor3 = MUSTARD,
				FontFace = STICKER_FONT,
				TextSize = 21,
				TextColor3 = INK,
				Text = RULES.NewText,
				create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				create("UIStroke")({ Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				create("UIScale")({
					Scale = function(): number
						return 1 + 0.08 * math.sin(props.Clock() * 5)
					end,
				}),
			}),
		}),
	}) :: SurfaceGui

	props.OnList(list)
	return surface, list
end
