--!strict
-- BackButton: the "Back" of the focused screens (kitchen-focus.md §2; owner 2026-10-21: the talk at the tablet leaves the
-- same way as the cooking focus). Cream, Ink outline, bottom left by default, one touch target high; Hint (os.clock() while
-- the tutorial asks the player to step back, DEC-311) turns it Mustard and pulses it. The keys that do the same are the
-- caller's (FocusExit). Pure: only props; build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
-- Vide 0.4.1 types `create` for some classes only (UIStroke, UIScale are not among them)
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	OnBack: () -> (),
	Scale: (() -> number)?,
	Hint: (() -> number?)?,
	Visible: (() -> boolean)?,
	Text: string?,
	Name: string?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

const WIDTH = 96 -- px at UI scale 1
const TEXT_SIZE = 20

return function(props: Props): TextButton
	const scale = props.Scale or function(): number
		return 1
	end
	local function hint(): number?
		return if props.Hint ~= nil then props.Hint() else nil
	end
	return create("TextButton")({
		Name = props.Name or "Back",
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 1),
		Position = props.Position or UDim2.new(0, 18, 1, -18),
		Size = function()
			const s = scale()
			return UDim2.fromOffset(math.floor(WIDTH * s), math.floor(Theme.MinTouch * s))
		end,
		BackgroundColor3 = function(): Color3
			return if hint() ~= nil then Theme.Color.Mustard else Theme.Color.Cream
		end,
		AutoButtonColor = true,
		FontFace = Theme.Font.Title,
		Text = props.Text or "Back",
		TextColor3 = Theme.Color.Ink,
		TextSize = function()
			return math.floor(TEXT_SIZE * scale())
		end,
		Visible = props.Visible or true,
		Activated = function()
			props.OnBack()
		end,
		create("UICorner")({ CornerRadius = Theme.Radius.Card }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		createRaw("UIScale")({
			Scale = function(): number
				const clock = hint()
				return if clock ~= nil then 1 + 0.12 * (0.5 + 0.5 * math.sin(clock * 6)) else 1
			end,
		}),
	}) :: TextButton
end
