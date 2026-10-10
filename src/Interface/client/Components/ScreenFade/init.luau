--!strict
-- ScreenFade: full-screen black cover for transitions (vehicle swap, T58; FEAT-017 "troca no fim do turno (fade +
-- ligação)"). Alpha 0 = invisible, 1 = solid black. Pure: only props; the owner (VehicleController, TASK-058) drives
-- Alpha from the server start time. Wrap it in a ScreenGui with IgnoreGuiInset = true so it covers the top bar too.
-- Never takes input (Active = false): a fade never steals a tap from the HUD or a prompt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create

export type Props = {
	Alpha: () -> number,
	Name: string?,
}

return function(props: Props): Frame
	return create("Frame")({
		Name = props.Name or "ScreenFade",
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Active = false,
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = function()
			return 1 - math.clamp(props.Alpha(), 0, 1)
		end,
		Visible = function()
			return props.Alpha() > 0
		end,
		ZIndex = 100,
	})
end
