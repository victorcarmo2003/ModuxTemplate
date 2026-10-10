--!strict
-- DrawerValue: the cash drawer value in the world (FEAT-012, DEC-050; style guide §7.3 "Valor da gaveta": "$23" with a
-- coin, above the drawer) plus the "+$N" that rises from it on each sale (style guide §10 "Pagamento").
-- Pure: only props. EconomyController (TASK-024) owns the data and the list of pops; this only draws.
-- Fixed pixel size (not studs) so the text stays >= 14 px on a phone at any distance it is drawn.
-- When the value goes up the number bumps (scale 1.15 for 0.2 s, same as the HUD money, style guide §7.2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Pop = require(script.Pop)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack
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

const WIDTH = 220
const HEIGHT = 150
const PILL_HEIGHT = 48
const COIN_SIZE = 28
const TEXT_SIZE = 26
const BUMP_SCALE = 1.15
const BUMP_TIME = 0.2

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
	const bumped = source(false)
	local last = untrack(props.Value)
	local bumpThread: thread? = nil

	effect(function()
		const value = props.Value()
		if value > last then
			if bumpThread and coroutine.status(bumpThread) == "suspended" then
				task.cancel(bumpThread)
			end
			bumped(true)
			bumpThread = task.delay(BUMP_TIME, function()
				bumpThread = nil
				bumped(false)
			end)
		end
		last = value
	end)
	cleanup(function()
		if bumpThread and coroutine.status(bumpThread) == "suspended" then
			task.cancel(bumpThread)
		end
	end)

	const scale = spring(function()
		return if bumped() then BUMP_SCALE else 1
	end, 0.1, 0.6)

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
		MaxDistance = props.MaxDistance or 60,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		ClipsDescendants = false,

		create("Frame")({
			Name = "Pill",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(0, PILL_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = Theme.Transparency.Panel,

			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIScale")({ Scale = scale }),
			createRaw("UIPadding")({
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 16),
			}),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),

			-- Coin: drawn shape until the icon sheet (AST-071) exists.
			create("Frame")({
				Name = "Coin",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(COIN_SIZE, COIN_SIZE),
				BackgroundColor3 = Theme.Color.Mustard,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
				create("TextLabel")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					FontFace = Theme.Font.Title,
					TextSize = 18,
					TextColor3 = Theme.Color.Ink,
					Text = "$",
				}),
			}),

			create("TextLabel")({
				Name = "Amount",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, PILL_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextSize = TEXT_SIZE,
				TextColor3 = Theme.Color.Text,
				Text = function()
					return money(props.Value())
				end,
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
			}),
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
