--!strict
-- ProgressBar: world-space bar over a station item (port of AnimalPlane `CookInterface`, DEC-015, DEC-029).
-- Style guide §7.3: 0.8 x 0.15 stud, 1.0 stud above the sausage, orange while cooking, green when ready.
-- Pure: only props. The caller parents the returned BillboardGui (PlayerGui or the adornee itself)
-- and drives `Progress`, usually from `(GetServerTimeNow() - StartedAt) / Duration`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Bar = require(script.Bar)

const create = Vide.create

export type Props = {
	Adornee: Instance?,
	Progress: () -> number,
	Visible: (() -> boolean)?,
	FillColor: (() -> Color3)?,
	Text: (() -> string)?,
	-- Defaults follow the style guide; the thief bar passes a bigger size and MaxDistance (MAP-01 §6).
	Size: UDim2?,
	StudsOffset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

return function(props: Props): BillboardGui
	return create("BillboardGui")({
		Name = props.Name or "ProgressBar",
		Adornee = props.Adornee,
		Size = props.Size or UDim2.fromScale(0.8, 0.15),
		StudsOffset = props.StudsOffset or Vector3.new(0, 1, 0),
		MaxDistance = props.MaxDistance or 60,
		LightInfluence = 0,
		ResetOnSpawn = false,
		-- Off while a cinematic owns the screen (Interface/Cinematic).
		Enabled = function()
			const visible = props.Visible
			return (if visible then visible() else true) and not Cinematic.Active()
		end,

		Bar({
			Progress = props.Progress,
			FillColor = props.FillColor,
			Text = props.Text,
		}),
	})
end
