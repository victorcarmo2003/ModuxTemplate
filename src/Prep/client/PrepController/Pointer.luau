--!strict
-- Pointer: ONE pointer for the focused prep mode (docs/tech/prep-mode.md §5 "Mobile / Gamepad / Teclado"), whatever the
-- device. Mouse (left button), the first touch, and the virtual cursor of a gamepad (Cursor.luau injects into it) all become
-- the same three events: Down, Move, Up, with a position in screen px (the space of GuiObject.AbsolutePosition under a
-- ScreenGui with ScreenInsets = DeviceSafeInsets). On touch the point is drawn `Rules.TouchOffset` px ABOVE the finger so the
-- hand does not hide the target. Nothing here knows about gestures or about the UI: Gestures.luau turns these events into
-- Drag / Trace / Tap / Hold, and `HitGrab` reads the `PrepGrab` attribute of the GUI under a point.
-- No Modux, no Vide: plain callbacks (a controller owns one and destroys it with the mode).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

export type Kind = "Down" | "Move" | "Up"

export type Device = "Mouse" | "Touch" | "Pad"

export type Pointer = {
	-- Last point (screen px, offset applied), whether the pointer is down and the device that moved it last.
	Position: Vector2,
	Down: boolean,
	Device: Device,
	-- Each returns the function that disconnects it.
	OnDown: (self: Pointer, fn: (position: Vector2) -> ()) -> () -> (),
	OnMove: (self: Pointer, fn: (position: Vector2) -> ()) -> () -> (),
	OnUp: (self: Pointer, fn: (position: Vector2) -> ()) -> () -> (),
	-- Events of a device that is not a UserInputService one (the gamepad cursor).
	Inject: (self: Pointer, kind: Kind, position: Vector2, device: Device?) -> (),
	-- Screen px offset above the finger (Rules.TouchOffset x the UI scale), set by the owner when the scale changes.
	SetOffset: (self: Pointer, pixels: number) -> (),
	-- The `PrepGrab` key of the topmost GUI under a point, nil when none.
	HitGrab: (self: Pointer, position: Vector2) -> string?,
	-- The `PrepPress` key (a chrome button: "Leave", "Next") on the GUI under a point or one of its ancestors, nil when none.
	-- The gamepad cursor is not a mouse, so a GuiButton never fires for it: the owner presses the button itself.
	HitPress: (self: Pointer, position: Vector2) -> string?,
	Destroy: (self: Pointer) -> (),
}


const Pointer = {}

local function add(list: { (position: Vector2) -> () }, fn: (position: Vector2) -> ()): () -> ()
	table.insert(list, fn)
	return function()
		const index = table.find(list, fn)
		if index ~= nil then
			table.remove(list, index)
		end
	end
end

local function fire(list: { (position: Vector2) -> () }, position: Vector2)
	for _, fn in table.clone(list) do
		task.spawn(fn, position)
	end
end

function Pointer.new(): Pointer
	const downs: { (position: Vector2) -> () } = {}
	const moves: { (position: Vector2) -> () } = {}
	const ups: { (position: Vector2) -> () } = {}
	local offset = 0
	local touch: InputObject? = nil
	const connections: { RBXScriptConnection } = {}

	const self = {
		Position = Vector2.zero,
		Down = false,
		Device = "Mouse" :: Device,
	} :: any

	local function dispatch(kind: Kind, position: Vector2, device: Device)
		self.Position = position
		self.Device = device
		if kind == "Down" then
			self.Down = true
			fire(downs, position)
		elseif kind == "Move" then
			fire(moves, position)
		else
			self.Down = false
			fire(ups, position)
		end
	end

	local function point(input: InputObject): Vector2
		return Vector2.new(input.Position.X, input.Position.Y)
	end

	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dispatch("Down", point(input), "Mouse")
			elseif input.UserInputType == Enum.UserInputType.Touch and touch == nil then
				touch = input
				dispatch("Down", point(input) - Vector2.new(0, offset), "Touch")
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				dispatch("Move", point(input), "Mouse")
			elseif input.UserInputType == Enum.UserInputType.Touch and input == touch then
				dispatch("Move", point(input) - Vector2.new(0, offset), "Touch")
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dispatch("Up", point(input), "Mouse")
			elseif input.UserInputType == Enum.UserInputType.Touch and input == touch then
				touch = nil
				dispatch("Up", point(input) - Vector2.new(0, offset), "Touch")
			end
		end)
	)

	function self.OnDown(_: any, fn: (position: Vector2) -> ()): () -> ()
		return add(downs, fn)
	end
	function self.OnMove(_: any, fn: (position: Vector2) -> ()): () -> ()
		return add(moves, fn)
	end
	function self.OnUp(_: any, fn: (position: Vector2) -> ()): () -> ()
		return add(ups, fn)
	end
	function self.Inject(_: any, kind: Kind, position: Vector2, device: Device?)
		dispatch(kind, position, device or "Pad")
	end
	function self.SetOffset(_: any, pixels: number)
		offset = pixels
	end
	-- GetGuiObjectsAtPosition speaks GUI space (the top bar inset taken out); the gamepad cursor lives in raw viewport px
	local function guiPoint(position: Vector2): Vector2
		return if self.Device == "Pad" then position - GuiService:GetGuiInset() else position
	end
	function self.HitGrab(_: any, position: Vector2): string?
		const gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if gui == nil then
			return nil
		end
		const at = guiPoint(position)
		for _, object in gui:GetGuiObjectsAtPosition(at.X, at.Y) do
			const key = object:GetAttribute("PrepGrab")
			if type(key) == "string" and key ~= "" then
				return key
			end
		end
		return nil
	end
	function self.HitPress(_: any, position: Vector2): string?
		const gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if gui == nil then
			return nil
		end
		const at = guiPoint(position)
		for _, object in gui:GetGuiObjectsAtPosition(at.X, at.Y) do
			if not object.Visible then
				continue
			end
			local current: Instance? = object
			while current ~= nil and current ~= gui do
				const key = current:GetAttribute("PrepPress")
				if type(key) == "string" and key ~= "" then
					return key
				end
				current = current.Parent
			end
		end
		return nil
	end
	function self.Destroy(_: any)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		table.clear(downs)
		table.clear(moves)
		table.clear(ups)
		touch = nil
	end

	return self :: Pointer
end

return Pointer
