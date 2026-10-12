--!strict
-- ToastStack: column of Toasts. Default (owner request 2026-10-12): anchored at the bottom centre and stacking UP, the
-- oldest toast on the bottom and each new one above it, so notices never take the top of the screen (clock, day and
-- money) nor the sides (joystick, jump button). The owner sets Position (above the hotbar / call subtitle), MaxVisible and
-- the card Width. Shows at most `MaxVisible` entries. Entries are keyed by table identity: the owner keeps
-- the same table for an entry while it lives and removes it in OnDone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Toast = require(script.Parent)

const create = Vide.create
const values = Vide.values

export type Entry = {
	Text: string,
	Kind: Toast.Kind?,
	Duration: number?,
}

export type Props = {
	Entries: () -> { Entry },
	OnDone: (entry: Entry) -> (),
	MaxVisible: (number | () -> number)?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	-- Card width in px at UI scale 1 (Toast default 220)
	Width: (() -> number)?,
	-- "Up" (default): bottom anchored, newest on top. "Down": top anchored, newest at the bottom, slides from the right.
	Direction: ("Up" | "Down")?,
	Visible: (() -> boolean)?,
}

return function(props: Props): Frame
	const up = props.Direction ~= "Down"
	local function maxVisible(): number
		const value = props.MaxVisible
		if type(value) == "function" then
			return value()
		end
		return value or 3
	end

	-- Queue: the oldest `maxVisible` entries are on screen; newer ones wait until a slot frees up,
	-- so every entry is shown for its full duration and reaches OnDone.
	local function visible(): { Entry }
		const list = props.Entries()
		return table.move(list, 1, math.min(#list, maxVisible()), 1, {})
	end

	return create("Frame")({
		Name = "ToastStack",
		AnchorPoint = props.AnchorPoint or (if up then Vector2.new(0.5, 1) else Vector2.new(1, 0)),
		Position = props.Position or (if up then UDim2.new(0.5, 0, 1, -16) else UDim2.new(1, -16, 0, 16)),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = props.Visible or true,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = if up then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8), -- room for the lean of the tags
		}),

		values(visible, function(entry: Entry, index: () -> number)
			return Toast({
				Text = function()
					return entry.Text
				end,
				Kind = function(): Toast.Kind
					return entry.Kind or "Info"
				end,
				Duration = entry.Duration,
				Width = props.Width,
				Slide = if up then "Bottom" else "Right",
				-- Up: the first (oldest) entry sorts last = bottom of the column
				LayoutOrder = if up
					then function()
						return -index()
					end
					else index,
				OnDone = function()
					props.OnDone(entry)
				end,
			})
		end),
	})
end
