--!strict
-- KeyHint: the small key label under a HUD button (TASK-290; owner request 2026-10-14, Provisional), same text style as
-- the clock / day / money pills (CartoonLabel: Fredoka One, white with an Ink stroke).
--   KeyboardMouse  the key name ("M", "B")
--   Gamepad        the controller button image (UserInputService:GetImageForKeyCode); text fallback when Roblox has none
--   Touch          hidden (nothing to press on a phone)
-- Reacts to the device (InputController.Device). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create

export type Device = "KeyboardMouse" | "Gamepad" | "Touch"

export type Props = {
	Device: () -> Device,
	Key: Enum.KeyCode,
	Pad: Enum.KeyCode,
	-- Text for the pad when Roblox has no image for it ("Select", "Right").
	PadText: string?,
	-- Box width px at UI scale 1 (the button above). Default 38.
	Width: number?,
	Name: string?,
	LayoutOrder: number?,
	-- Extra gate on top of the device rule (nil = always).
	Visible: (() -> boolean)?,
}

const HEIGHT = 18
const PAD_ICON = 20

local function padImage(key: Enum.KeyCode): string
	const ok, image = pcall(function()
		return UserInputService:GetImageForKeyCode(key)
	end)
	return if ok and type(image) == "string" then image else ""
end

local function keyText(key: Enum.KeyCode): string
	const ok, text = pcall(function()
		return UserInputService:GetStringForKeyCode(key)
	end)
	return if ok and type(text) == "string" and text ~= "" then string.upper(text) else key.Name
end

return function(props: Props): Frame
	const width = props.Width or 38
	const image = padImage(props.Pad)
	const showImage = function(): boolean
		return props.Device() == "Gamepad" and image ~= ""
	end

	return create("Frame")({
		Name = props.Name or "KeyHint",
		LayoutOrder = props.LayoutOrder or 0,
		Size = UDim2.fromOffset(width, HEIGHT),
		BackgroundTransparency = 1,
		Visible = function()
			return props.Device() ~= "Touch" and (props.Visible == nil or props.Visible())
		end,

		CartoonLabel({
			Name = "Key",
			TextSize = 14,
			Text = function()
				if props.Device() == "Gamepad" then
					return props.PadText or props.Pad.Name
				end
				return keyText(props.Key)
			end,
			Box = UDim2.fromScale(1, 1),
			Visible = function()
				return not showImage()
			end,
		}),

		create("ImageLabel")({
			Name = "Pad",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(PAD_ICON, PAD_ICON),
			BackgroundTransparency = 1,
			Image = image,
			Visible = showImage,
		}),
	}) :: Frame
end
