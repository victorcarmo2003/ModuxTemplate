--!strict
-- StockMenu.Tag: world counter of the stock room (FEAT-050; TASK-389). A big "x3" pill over the sign of a StockShelf bay
-- (boxes waiting there, from the Boxes attribute the server writes), or a small name tag over a box at the hatch
-- (DROP-R). Ink pill, Ketchup when Empty ("x0"); bumps when the number changes. Sized in studs like ShelfTag (shrinks with
-- distance, a real sign); short MaxDistance so the room does not fill with pills. Not AlwaysOnTop: walls hide it.
-- Pure: only props. The caller parents the BillboardGui (PlayerGui, Adornee = the sign / box).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)
local CartoonPanel = require(script.Parent.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	Text: () -> string, -- "x3" / "Buns"
	Empty: () -> boolean,
	-- changes of this number bump the pill (nil = no bump)
	Count: (() -> number)?,
	-- studs
	Size: Vector2?,
	StudsOffset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const SIZE = Vector2.new(1.7, 1.0)
const MAX_TEXT = 72
const EMPTY = Theme.ToneOf(Theme.Color.Low)

return function(props: Props): BillboardGui
	const size = props.Size or SIZE
	const count = props.Count or function(): number
		return 0
	end
	const bump = Motion.Bump(count)

	return create("BillboardGui")({
		Name = props.Name or "StockTag",
		Adornee = props.Adornee,
		Size = UDim2.fromScale(size.X, size.Y),
		StudsOffset = props.StudsOffset or Vector3.zero,
		MaxDistance = props.MaxDistance or 24,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		-- Off while a cinematic owns the screen (Interface/Cinematic).
		Enabled = function()
			return props.Visible() and not Cinematic.Active()
		end,

		CartoonPanel({
			Name = "Pill",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.94, 0.88),
			Tone = function()
				return if props.Empty() then EMPTY else Theme.Tone.Ink
			end,
			Transparency = Theme.Transparency.Panel,
			-- sized in studs: a thick pixel outline would swallow it from far away
			Outline = Theme.Outline.Thin,
			Lip = 3,
			Decor = {
				createRaw("UIScale")({ Scale = bump }),
			},
			Children = {
				CartoonLabel({
					Name = "Label",
					Box = UDim2.fromScale(1, 1),
					Scaled = true,
					MaxTextSize = MAX_TEXT,
					TextSize = 24,
					Stroke = Theme.Outline.Thin,
					Text = props.Text,
					Children = {
						createRaw("UIPadding")({
							PaddingTop = UDim.new(0.08, 0),
							PaddingBottom = UDim.new(0.08, 0),
							PaddingLeft = UDim.new(0.08, 0),
							PaddingRight = UDim.new(0.08, 0),
						}),
					},
				}),
			},
		}),
	})
end
