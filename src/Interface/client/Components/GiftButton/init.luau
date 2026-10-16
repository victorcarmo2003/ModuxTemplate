--!strict
-- GiftButton (TASK-353, owner request 2026-10-16, Provisional): the small round "gift" button next to a Buy button of
-- the lobby shops (GemShop cards, ClassSelect buy row). A CartoonButton (44 px, Violet) holding a drawn gift box
-- (Frames: box, lid, ribbon, bow; no image upload needed). Disabled (`Enabled` false, e.g. the gift product is not
-- created yet): Slate face, never fires. Gamepad: Selectable (Name "Gift"). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonButton = require(script.Parent.CartoonButton)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Enabled: (() -> boolean)?,
	OnActivated: () -> (),
	Name: string?,
	LayoutOrder: number?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	-- px of the square button; default Theme.MinTouch (44)
	Size: number?,
	Visible: (() -> boolean)?,
}

const BOX = Color3.fromHex("#FFDA5C") -- Mustard box
const RIBBON = Color3.fromHex("#63C8D4") -- Teal ribbon

local function part(name: string, position: UDim2, size: UDim2, color: Color3, rotation: number?, z: number?): Instance
	return create("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		Rotation = rotation or 0,
		BackgroundColor3 = color,
		ZIndex = z or 2,
		create("UICorner")({ CornerRadius = UDim.new(0, 3) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2 }),
	})
end

-- The drawn gift box, `size` px square.
local function gift(size: number): Instance
	return create("Frame")({
		Name = "GiftIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		-- bow loops behind the lid
		part("BowLeft", UDim2.fromScale(0.36, 0.2), UDim2.fromScale(0.3, 0.22), RIBBON, -30, 1),
		part("BowRight", UDim2.fromScale(0.64, 0.2), UDim2.fromScale(0.3, 0.22), RIBBON, 30, 1),
		part("Box", UDim2.fromScale(0.5, 0.68), UDim2.fromScale(0.74, 0.5), BOX, 0, 2),
		part("Lid", UDim2.fromScale(0.5, 0.4), UDim2.fromScale(0.92, 0.22), BOX, 0, 3),
		create("Frame")({
			Name = "Ribbon",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(0.18, 0.63),
			BackgroundColor3 = RIBBON,
			BorderSizePixel = 0,
			ZIndex = 4,
		}),
	})
end

return function(props: Props): TextButton
	const size = props.Size or Theme.MinTouch
	return CartoonButton({
		Name = props.Name or "Gift",
		LayoutOrder = props.LayoutOrder,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = UDim2.fromOffset(size, size),
		Tone = Theme.Tone.Violet,
		Outline = Theme.Outline.Thick,
		Radius = Theme.Radius.Pill,
		Enabled = props.Enabled,
		Visible = props.Visible,
		OnActivated = props.OnActivated,
		Children = { gift(math.floor(size * 0.6)) },
	})
end
