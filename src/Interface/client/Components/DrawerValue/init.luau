--!strict
-- DrawerValue: the cash drawer value in the world (FEAT-012, DEC-050; style guide §7.3 "Valor da gaveta": "$23" with a
-- coin, above the drawer) plus the "+$N" that rises from it on each sale (style guide §10 "Pagamento").
-- Pure: only props. EconomyController (TASK-024) owns the data and the list of pops; this only draws.
-- Fixed pixel size (not studs) so the text stays >= 14 px on a phone at any distance it is drawn.
-- When the value goes up the pill jumps and the number rolls up (Motion.Bump / Motion.Count, same as the HUD money,
-- style guide §7.2). Cartoon pass (AST-091): Ink CartoonPanel pill with the AST-071 `Hud/coin` icon (drawn coin while
-- missing).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Pop = require(script.Pop)

const create = Vide.create
const values = Vide.values
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Pop = Pop.Entry

export type Props = {
	Adornee: Instance?,
	Value: () -> number,
	-- "+$N" entries, keyed by table identity: the owner keeps the table while it lives and drops it in OnPopDone.
	Pops: (() -> { Pop })?,
	OnPopDone: ((pop: Pop) -> ())?,
	-- World-space offset over the adornee (studs, world up stays up whatever the camera does).
	Offset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 190
const HEIGHT = 130
const PILL_HEIGHT = 40
const COIN_SIZE = 36
const TEXT_SIZE = 22

-- 1234 -> "$1,234"
local function money(value: number): string
	local text = tostring(math.max(math.floor(value), 0))
	while true do
		const replaced, count = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then
			break
		end
	end
	return "$" .. text
end

return function(props: Props): BillboardGui
	const scale = Motion.Bump(props.Value)
	const rolled = Motion.Count(props.Value)
	const coin = Icons.Rect("Hud/coin")

	const pops = props.Pops or function(): { Pop }
		return {}
	end

	return create("BillboardGui")({
		Name = props.Name or "DrawerValue",
		Adornee = props.Adornee,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		-- The pill sits at the bottom of the gui, right over the anchor; pops rise in the space above it.
		SizeOffset = Vector2.new(0, 0.5),
		StudsOffsetWorldSpace = props.Offset or Vector3.zero,
		MaxDistance = props.MaxDistance or 40,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		ClipsDescendants = false,
		-- Off while a cinematic owns the screen (Interface/Cinematic).
		Enabled = function()
			return not Cinematic.Active()
		end,

		CartoonPanel({
			Name = "Pill",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(0, PILL_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			Tone = Theme.Tone.Ink,
			Transparency = Theme.Transparency.Panel,
			Decor = {
				createRaw("UIScale")({ Scale = scale }),
			},
			Padding = { Left = 2, Right = 16 },
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),

				if coin
					then create("ImageLabel")({
						Name = "Coin",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(COIN_SIZE, COIN_SIZE),
						BackgroundTransparency = 1,
						Image = Icons.ImageOf("Hud/coin"),
						ImageRectOffset = coin.Offset,
						ImageRectSize = coin.Size,
					})
					else create("Frame")({
						Name = "Coin",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(COIN_SIZE - 14, COIN_SIZE - 14),
						BackgroundColor3 = Theme.Color.Mustard,
						create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
						createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Outline.Normal }),
						CartoonLabel({
							Box = UDim2.fromScale(1, 1),
							TextSize = 16,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Text = "$",
						}),
					}),

				CartoonLabel({
					Name = "Amount",
					LayoutOrder = 2,
					TextSize = TEXT_SIZE,
					Text = function()
						return money(rolled() + 0.5)
					end,
				}),
			},
		}),

		values(pops, function(pop: Pop, _index: () -> number)
			return Pop.Render(pop, {
				Bottom = HEIGHT - PILL_HEIGHT,
				OnDone = function()
					if props.OnPopDone then
						props.OnPopDone(pop)
					end
				end,
			})
		end),
	})
end
