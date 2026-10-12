--!strict
-- Cursor: the virtual cursor of the focused prep mode (docs/tech/prep-mode.md §5: gamepad "stick left moves the cursor, A
-- holds / releases"; touch "cursor drawn 28 px above the finger"). It does two things:
--   * gamepad: while the active device is a gamepad, the left stick moves a point over the screen (px / s, dead zone) and
--     injects Move into the Pointer; Press / Release (the A button, bound by the controller) inject Down / Up at that point
--   * feedback for every device: `Position` / `Visible` / `Held` Vide sources the controller draws as a ring (the gamepad
--     cursor always; the touch point only while a finger is down; the mouse needs none)
-- No bindings here (InputController binds the buttons in the controller) and no UI. Create it inside a Vide root.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local Pointer = require(script.Parent.Pointer)

export type Cursor = {
	Position: Vide.Source<Vector2>,
	Visible: Vide.Source<boolean>,
	Held: Vide.Source<boolean>,
	-- The gamepad drives the cursor (set from the InputController device).
	SetPad: (self: Cursor, on: boolean) -> (),
	Press: (self: Cursor) -> (),
	Release: (self: Cursor) -> (),
	Destroy: (self: Cursor) -> (),
}

const SPEED = 640 -- px / s with the stick fully pushed
const DEAD = 0.22
const Cursor = {}

function Cursor.new(pointer: Pointer.Pointer): Cursor
	const camera = workspace.CurrentCamera
	const viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(800, 400)
	const position = Vide.source(viewport / 2)
	const visible = Vide.source(false)
	const held = Vide.source(false)
	local pad = false

	const stop1 = pointer:OnDown(function(at: Vector2)
		position(at)
		held(true)
		visible(pointer.Device == "Pad" or pointer.Device == "Touch")
	end)
	const stop2 = pointer:OnMove(function(at: Vector2)
		position(at)
		if pointer.Device == "Mouse" then
			visible(false)
		end
	end)
	const stop3 = pointer:OnUp(function(at: Vector2)
		position(at)
		held(false)
		if pointer.Device ~= "Pad" then
			visible(false)
		end
	end)

	const connection = RunService.Heartbeat:Connect(function(dt: number)
		if not pad then
			return
		end
		local stick = Vector2.zero
		for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if input.KeyCode == Enum.KeyCode.Thumbstick1 then
				stick = Vector2.new(input.Position.X, -input.Position.Y)
				break
			end
		end
		if stick.Magnitude < DEAD then
			return
		end
		const size = if workspace.CurrentCamera ~= nil then workspace.CurrentCamera.ViewportSize else viewport
		const target = Vide.untrack(position) + stick * SPEED * dt
		const clamped = Vector2.new(math.clamp(target.X, 0, size.X), math.clamp(target.Y, 0, size.Y))
		position(clamped)
		visible(true)
		pointer:Inject("Move", clamped, "Pad")
	end)

	const self = {
		Position = position,
		Visible = visible,
		Held = held,
	} :: any
	function self.SetPad(_: any, on: boolean)
		pad = on
		if on then
			visible(true)
		elseif pointer.Device == "Pad" then
			visible(false)
		end
	end
	function self.Press(_: any)
		if pad then
			pointer:Inject("Down", Vide.untrack(position), "Pad")
		end
	end
	function self.Release(_: any)
		if pad and pointer.Down then
			pointer:Inject("Up", Vide.untrack(position), "Pad")
		end
	end
	function self.Destroy(_: any)
		connection:Disconnect()
		stop1()
		stop2()
		stop3()
	end
	return self :: Cursor
end

return Cursor
