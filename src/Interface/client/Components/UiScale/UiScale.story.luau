--!strict
-- UiScale: the global UI scale (Theme.ScaleOf) for common screens, plus the live value of the Studio viewport.
-- A 44 px button is drawn at each scale, so the size on a phone, a 720p window and a 1080p / 1440p monitor can be
-- compared. Knob: Theme.Scale.Factor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)
local UiScale = require(script.Parent)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const SCREENS: { { Name: string, Size: Vector2 } } = {
	{ Name = "Phone 667x375", Size = Vector2.new(667, 375) },
	{ Name = "Tablet 1024x768", Size = Vector2.new(1024, 768) },
	{ Name = "720p", Size = Vector2.new(1280, 720) },
	{ Name = "1080p", Size = Vector2.new(1920, 1080) },
	{ Name = "1440p", Size = Vector2.new(2560, 1440) },
}

local function row(name: string, scale: () -> number, order: number): Frame
	return create("Frame")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(420, 72),
		BackgroundTransparency = 1,
		CartoonLabel({
			Box = UDim2.fromOffset(240, 72),
			XAlignment = Enum.TextXAlignment.Left,
			TextSize = 16,
			Text = function()
				return string.format("%s: %.2f", name, scale())
			end,
		}),
		create("Frame")({
			Name = "Button44",
			Position = UDim2.fromOffset(260, 0),
			Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch),
			BackgroundColor3 = Theme.Color.Mustard,
			create("UICorner")({ CornerRadius = Theme.Radius.Chip }),
			createRaw("UIScale")({ Scale = scale }),
		}),
	})
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {},
}, function()
	const rows: { Instance } = {}
	for index, screen in SCREENS do
		const value = Theme.ScaleOf(screen.Size)
		table.insert(rows, row(screen.Name, function()
			return value
		end, index))
	end
	table.insert(rows, row("Studio viewport (live)", UiScale.Current, #SCREENS + 1))

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Ink,
		createRaw("UIPadding")({ PaddingLeft = UDim.new(0, 16), PaddingTop = UDim.new(0, 16) }),
		create("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		rows,
	})
end)
