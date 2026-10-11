--!strict
-- Sheet icon of the AST-071 / AST-091 sheets (Icons) for the lobby screens; hidden while its sheet is missing, so the
-- caller's text fallback shows instead. Pure: one ImageLabel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Icons = require(script.Parent.Parent.Icons)

const create = Vide.create

export type Value<T> = T | () -> T

local function read(value: Value<string>): string
	if type(value) == "function" then
		return value()
	end
	return value
end

local function rect(name: Value<string>): Icons.Rect
	return Icons.Rect(read(name)) or { Offset = Vector2.zero, Size = Vector2.zero }
end

return function(name: Value<string>, size: number, order: number?, color: Color3?): ImageLabel
	return create("ImageLabel")({
		Name = "Icon",
		LayoutOrder = order or 0,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ImageColor3 = color or Color3.new(1, 1, 1),
		Image = function()
			return Icons.ImageOf(read(name))
		end,
		ImageRectOffset = function()
			return rect(name).Offset
		end,
		ImageRectSize = function()
			return rect(name).Size
		end,
		Visible = function()
			return Icons.Has(read(name))
		end,
	}) :: ImageLabel
end
