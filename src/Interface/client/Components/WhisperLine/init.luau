--!strict
-- WhisperLine: the on-screen fallback of the "Rookie..." hallucination (TASK-119; script.md §8; sound-list.md §7:
-- "se não houver voz com licença, a alucinação vira só legenda"). One faint italic line a little above the centre,
-- no speaker, no panel, no button: it must read as something half heard, not as UI. Text >= Theme.MinTextSize.
-- Pure: only props. The owner (HallucinationController) decides the text and when it shows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const spring = Vide.spring
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	-- "" hides the line (fades out)
	Text: () -> string,
	-- UI scale of the owner (1 on the smallest phone)
	Scale: (() -> number)?,
	Name: string?,
}

const TEXT_SIZE = 18 -- >= Theme.MinTextSize on the smallest phone
const SHOWN = 0.35 -- text transparency when shown: faint on purpose
const DRIFT = 10 -- px it rises while fading in

return function(props: Props): Frame
	local last = ""
	const text = function(): string
		const value = props.Text()
		if value ~= "" then
			last = value
		end
		return last
	end
	const alpha = spring(function()
		return if props.Text() ~= "" then SHOWN else 1
	end, 0.35, 1)
	const rise = spring(function()
		return if props.Text() ~= "" then 0 else DRIFT
	end, 0.5, 1)

	return create("Frame")({
		Name = props.Name or "WhisperLine",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.new(0.6, 0, 0, TEXT_SIZE + 12),
		BackgroundTransparency = 1,
		Visible = function()
			return alpha() < 0.99
		end,

		createRaw("UIScale")({
			Scale = function()
				return if props.Scale then props.Scale() else 1
			end,
		}),

		create("TextLabel")({
			Name = "Line",
			Position = function()
				return UDim2.fromOffset(0, rise())
			end,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Whisper, -- thin italic on purpose: not part of the cartoon kit
			TextSize = TEXT_SIZE,
			TextColor3 = Theme.Color.Cream,
			TextTransparency = alpha,
			Text = text,
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = 1,
				Transparency = alpha,
			}),
		}),
	})
end
