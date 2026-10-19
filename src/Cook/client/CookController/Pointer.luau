--!strict
-- One pointer for the cooking focus (kitchen-focus.md §2), from the old prep's Pointer + Cursor: the mouse (left button), the first
-- touch, or the gamepad's virtual cursor (left stick moves it, R2 or A presses) all become Down / Move / Up with a position in GUI
-- space (Camera:ScreenPointToRay space; the top bar inset is out). On touch the point is drawn TOUCH_LIFT px above the finger.
-- The gamepad cursor is drawn as a dot (a Frame in the focus HUD the owner passes). No Modux, no Vide: plain callbacks.
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

export type Kind = "Down" | "Move" | "Up"
export type Device = "Mouse" | "Touch" | "Pad"

export type Pointer = {
	Position: Vector2,
	IsDown: boolean,
	Device: Device,
	On: (self: Pointer, fn: (kind: Kind, position: Vector2) -> ()) -> (),
	-- the gamepad cursor dot (nil = none); shown while the last device is the pad
	SetDot: (self: Pointer, dot: GuiObject?) -> (),
	Destroy: (self: Pointer) -> (),
}

const TOUCH_LIFT = 0 -- px over the finger (the bun is big on screen; Provisional)
const PAD_SPEED = 900 -- px per second at full stick
const DEAD = 0.18
const PRESS_KEYS: { [Enum.KeyCode]: boolean } = { [Enum.KeyCode.ButtonR2] = true, [Enum.KeyCode.ButtonA] = true }

const Pointer = {}

function Pointer.new(): Pointer
	const listeners: { (kind: Kind, position: Vector2) -> () } = {}
	const connections: { RBXScriptConnection } = {}
	local touch: InputObject? = nil
	local padHeld = 0
	local dot: GuiObject? = nil

	const self = {
		Position = Vector2.zero,
		IsDown = false,
		Device = "Mouse" :: Device,
	} :: any

	local function viewportCentre(): Vector2
		const camera = Workspace.CurrentCamera
		const size = if camera then camera.ViewportSize else Vector2.new(800, 600)
		return size / 2 - GuiService:GetGuiInset() / 2
	end

	local function dispatch(kind: Kind, position: Vector2, device: Device)
		self.Position = position
		self.Device = device
		if kind == "Down" then
			self.IsDown = true
		elseif kind == "Up" then
			self.IsDown = false
		end
		const shown = dot
		if shown ~= nil then
			shown.Visible = device == "Pad"
			shown.Position = UDim2.fromOffset(position.X, position.Y)
		end
		for _, fn in table.clone(listeners) do
			task.spawn(fn, kind, position)
		end
	end

	local function point(input: InputObject): Vector2
		return Vector2.new(input.Position.X, input.Position.Y)
	end

	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
				dispatch("Down", point(input), "Mouse")
			elseif input.UserInputType == Enum.UserInputType.Touch and touch == nil and not processed then
				touch = input
				dispatch("Down", point(input) - Vector2.new(0, TOUCH_LIFT), "Touch")
			elseif PRESS_KEYS[input.KeyCode] then
				padHeld += 1
				if padHeld == 1 then
					if self.Device ~= "Pad" then
						self.Position = viewportCentre()
					end
					dispatch("Down", self.Position, "Pad")
				end
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				dispatch("Move", point(input), "Mouse")
			elseif input.UserInputType == Enum.UserInputType.Touch and input == touch then
				dispatch("Move", point(input) - Vector2.new(0, TOUCH_LIFT), "Touch")
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and self.Device == "Mouse" then
				dispatch("Up", point(input), "Mouse")
			elseif input.UserInputType == Enum.UserInputType.Touch and input == touch then
				touch = nil
				dispatch("Up", point(input) - Vector2.new(0, TOUCH_LIFT), "Touch")
			elseif PRESS_KEYS[input.KeyCode] then
				padHeld = math.max(padHeld - 1, 0)
				if padHeld == 0 then
					dispatch("Up", self.Position, "Pad")
				end
			end
		end)
	)
	-- the virtual cursor: the left stick moves it every frame
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt: number)
			local stick = Vector2.zero
			for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
				if state.KeyCode == Enum.KeyCode.Thumbstick1 then
					stick = Vector2.new(state.Position.X, -state.Position.Y)
				end
			end
			if stick.Magnitude < DEAD then
				return
			end
			if self.Device ~= "Pad" then
				self.Position = viewportCentre()
			end
			const camera = Workspace.CurrentCamera
			const size = if camera then camera.ViewportSize - GuiService:GetGuiInset() else Vector2.new(800, 600)
			const moved = self.Position + stick * PAD_SPEED * dt
			dispatch("Move", Vector2.new(math.clamp(moved.X, 0, size.X), math.clamp(moved.Y, 0, size.Y)), "Pad")
		end)
	)

	function self.On(_: any, fn: (kind: Kind, position: Vector2) -> ())
		table.insert(listeners, fn)
	end
	function self.SetDot(_: any, value: GuiObject?)
		dot = value
		if value ~= nil then
			value.Visible = self.Device == "Pad"
		end
	end
	function self.Destroy(_: any)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		table.clear(listeners)
		touch = nil
	end

	return self :: Pointer
end

return Pointer
