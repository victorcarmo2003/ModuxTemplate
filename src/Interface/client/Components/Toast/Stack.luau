--!strict
-- ToastStack: column of Toasts pinned to the top-right corner (style guide §7.2). Shows at most
-- `MaxVisible` entries, newest at the bottom. Entries are keyed by table identity: the owner keeps
-- the same table for an entry while it lives and removes it in OnDone.
-- Put it in a ScreenGui with `ScreenInsets = CoreUISafeInsets` so it stays clear of the Roblox top bar.
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
	MaxVisible: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

return function(props: Props): Frame
	const maxVisible = props.MaxVisible or 3

	-- Queue: the oldest `maxVisible` entries are on screen; newer ones wait until a slot frees up,
	-- so every entry is shown for its full duration and reaches OnDone.
	local function visible(): { Entry }
		const list = props.Entries()
		return table.move(list, 1, math.min(#list, maxVisible), 1, {})
	end

	return create("Frame")({
		Name = "ToastStack",
		AnchorPoint = props.AnchorPoint or Vector2.new(1, 0),
		Position = props.Position or UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
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
				LayoutOrder = index,
				OnDone = function()
					props.OnDone(entry)
				end,
			})
		end),
	})
end
