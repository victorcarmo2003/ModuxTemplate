--!strict
-- IngredientPanel: every box state at once (normal, low stock with the "!" diamond, no stock with the bar, locked, used with the
-- check, the rest) in the three layouts of the PrepShell (phone 2 x 3 with 64 px boxes, desktop 2 x 3 with 72, portrait 3 x 2).
-- Controls: Layout, Full (the plate has 3 toppings: the free boxes dim), Disabled (not the build step), Refuse (flip it: the
-- first box shakes). Tap a box to focus it (its name and stock go to the header).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local IngredientPanel = require(script.Parent)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect

type Controls = {
	Layout: () -> string,
	Full: () -> boolean,
	Disabled: () -> boolean,
	Refuse: () -> boolean,
}

type Shape = { Cols: number, Rows: number, Box: number, Size: Vector2 }

-- Cols, rows, box, panel size (the PrepShell Layout numbers)
const LAYOUTS: { [string]: Shape } = {
	Phone = { Cols = 2, Rows = 3, Box = 64, Size = Vector2.new(150, 246) },
	Desktop = { Cols = 2, Rows = 3, Box = 72, Size = Vector2.new(168, 260) },
	Portrait = { Cols = 3, Rows = 2, Box = 64, Size = Vector2.new(224, 176) },
}

const INFO: { [string]: IngredientPanel.Info } = {
	ketchup = { Stock = 12, Locked = false, Used = false },
	mustard = { Stock = 2, Locked = false, Used = false },
	cream_cheese = { Stock = 0, Locked = false, Used = false },
	cheese = { Stock = 5, Locked = true, Used = false },
	bacon = { Stock = 7, Locked = false, Used = true },
	potato_sticks = { Stock = 10, Locked = false, Used = false },
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Layout = UILabs.Choose({ "Phone", "Desktop", "Portrait" }),
		Full = false,
		Disabled = false,
		Refuse = false,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)
	const focus = source("")
	const refused = source(false :: { Key: string, Id: number } | false)
	local id = 0
	effect(function()
		controls.Refuse()
		id += 1
		if id > 1 then
			refused({ Key = "ketchup", Id = id })
		end
	end)
	const current = function(): Shape
		return LAYOUTS[controls.Layout()] or LAYOUTS.Phone
	end

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),

		create("Frame")({
			Position = UDim2.fromOffset(24, 24),
			Size = function(): UDim2
				const size = current().Size
				return UDim2.fromOffset(size.X, size.Y)
			end,
			BackgroundTransparency = 1,
			IngredientPanel({
				Info = function(key: string): IngredientPanel.Info
					return INFO[key] or { Stock = 0, Locked = false, Used = false }
				end,
				Cols = function(): number
					return current().Cols
				end,
				Rows = function(): number
					return current().Rows
				end,
				Box = function(): number
					return current().Box
				end,
				Full = controls.Full,
				Disabled = controls.Disabled,
				OnPick = function(key: string)
					focus(key)
				end,
				Focus = focus,
				Refused = function(): { Key: string, Id: number }?
					const value = refused()
					return if value ~= false then value else nil
				end,
			}),
		}),
	})
end)
