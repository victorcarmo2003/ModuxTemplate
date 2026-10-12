--!strict
-- PadTag: the room sign over a lobby squad pad (user request 2026-10-12), cartoon kit (AST-091; style guide §7.3
-- UI in the world). One Ink-lipped plate in the colour of the pad state, readable from far away. A pad has NO fixed
-- capacity: the room takes the size its leader chose (Max), a free pad shows none.
--   title row   "SQUAD 3" (left) and "2/3" (right, only while a room has a size)
--   slots row   four round slots: filled (a player), empty, or faded (beyond the size the leader chose / free pad)
--   state row   "FREE" / "CONFIGURING" / "OPEN 2/3" / "FRIENDS ONLY" / "INVITE ONLY" / "CLOSED" / "STARTING IN 3..."
-- Colours: Free Green, Configuring Mustard, Open Teal, Closed Slate, Starting Violet (never red: style guide §7.4).
-- Sized in studs (a BillboardGui with a fixed size, like TableSign): it shrinks with distance like a real sign, so two
-- pads never overlap; MaxDistance 140 studs by default. Pure: only props; LobbyController owns the data, parents the
-- BillboardGui and decides every text (the server decides the squads).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIPadding and UIAspectRatioConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type State = "Free" | "Configuring" | "Open" | "Closed" | "Starting"

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	-- "SQUAD 3"
	Title: string,
	-- players in the squad on the pad (0 = free)
	Count: () -> number,
	-- players the room takes (the size its leader chose); 0 = no size yet (free pad, room being set up)
	Max: () -> number,
	State: () -> State,
	-- "OPEN" / "FULL" / "STARTING IN 3..."
	Status: () -> string,
	-- slot icons drawn (4 = the squad table size)
	Slots: number?,
	-- World-space offset over the adornee (studs).
	Offset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 10 -- studs
const HEIGHT = 5.6
const MAX_TEXT = 64
const DEFAULT_DISTANCE = 140
const DEFAULT_SLOTS = 4

const TONE: { [State]: Theme.Tone } = {
	Free = Theme.Tone.Green,
	Configuring = Theme.Tone.Mustard,
	Open = Theme.Tone.Teal,
	Closed = Theme.Tone.Slate,
	Starting = Theme.Tone.Violet,
}

local function padded(vertical: number, horizontal: number): Instance
	return createRaw("UIPadding")({
		PaddingTop = UDim.new(vertical, 0),
		PaddingBottom = UDim.new(vertical, 0),
		PaddingLeft = UDim.new(horizontal, 0),
		PaddingRight = UDim.new(horizontal, 0),
	})
end

-- A player glyph (head over shoulders) in Ink, on a filled slot.
local function glyph(): { Instance }
	return {
		create("Frame")({
			Name = "Head",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.36),
			Size = UDim2.fromScale(0.34, 0.34),
			BackgroundColor3 = Theme.Color.Dark,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),
		create("Frame")({
			Name = "Body",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.74),
			Size = UDim2.fromScale(0.58, 0.3),
			BackgroundColor3 = Theme.Color.Dark,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),
	}
end

return function(props: Props): BillboardGui
	const tone = function(): Theme.Tone
		return TONE[props.State()]
	end
	const textColor = function(): Color3
		return tone().Text
	end
	const stroke = function(): number
		return if tone().Stroke then Theme.Outline.Thin else 0
	end
	const slotCount = props.Slots or DEFAULT_SLOTS

	const slots: { Instance } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.04, 0),
		}),
	}
	for index = 1, slotCount do
		const filled = function(): boolean
			return index <= props.Count()
		end
		const closed = function(): boolean
			return index > math.max(props.Max(), props.Count()) -- no size yet: every slot faded
		end
		table.insert(
			slots,
			CartoonPanel({
				Name = `Slot{index}`,
				LayoutOrder = index,
				Size = UDim2.fromScale(0, 1),
				Tone = function()
					return if filled() then Theme.Tone.Cream else Theme.Tone.Ink
				end,
				Transparency = function()
					return if closed() then 0.7 else 0
				end,
				Outline = Theme.Outline.Thin,
				Lip = 2,
				Gloss = false,
				Decor = { createRaw("UIAspectRatioConstraint")({ AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }) },
				Children = {
					create("Frame")({
						Name = "Player",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = filled,
						glyph(),
					}),
				},
			})
		)
	end

	return create("BillboardGui")({
		Name = props.Name or "PadTag",
		Adornee = props.Adornee,
		Size = UDim2.fromScale(WIDTH, HEIGHT),
		StudsOffsetWorldSpace = props.Offset or Vector3.zero,
		MaxDistance = props.MaxDistance or DEFAULT_DISTANCE,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		-- Off while a cinematic owns the screen (Interface/Cinematic).
		Enabled = function()
			return props.Visible() and not Cinematic.Active()
		end,

		CartoonPanel({
			Name = "Plate",
			Size = UDim2.fromScale(1, 1),
			Tone = tone,
			Outline = Theme.Outline.Thin,
			Lip = 4,
			Radius = UDim.new(0.16, 0),
			Studs = true,
			Gloss = false,
			Children = {
				createRaw("UIPadding")({
					PaddingTop = UDim.new(0.05, 0),
					PaddingBottom = UDim.new(0.02, 0),
					PaddingLeft = UDim.new(0.05, 0),
					PaddingRight = UDim.new(0.05, 0),
				}),
				CartoonLabel({
					Name = "Title",
					Box = UDim2.fromScale(0.62, 0.3),
					Scaled = true,
					MaxTextSize = MAX_TEXT,
					TextSize = 24,
					XAlignment = Enum.TextXAlignment.Left,
					Color = textColor,
					Stroke = stroke,
					Text = props.Title,
				}),
				CartoonLabel({
					Name = "Count",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Box = UDim2.fromScale(0.34, 0.3),
					Scaled = true,
					MaxTextSize = MAX_TEXT,
					TextSize = 24,
					XAlignment = Enum.TextXAlignment.Right,
					Color = textColor,
					Stroke = stroke,
					Visible = function()
						return props.Max() > 0
					end,
					Text = function()
						return `{props.Count()}/{props.Max()}`
					end,
				}),
				create("Frame")({
					Name = "Slots",
					Position = UDim2.fromScale(0, 0.34),
					Size = UDim2.fromScale(1, 0.36),
					BackgroundTransparency = 1,
					slots,
				}),
				CartoonLabel({
					Name = "Status",
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, 1),
					Box = UDim2.fromScale(1, 0.22),
					Scaled = true,
					MaxTextSize = MAX_TEXT,
					TextSize = 20,
					Color = textColor,
					Stroke = stroke,
					Text = props.Status,
					Children = { padded(0.02, 0) },
				}),
			},
		}),
	}) :: BillboardGui
end
