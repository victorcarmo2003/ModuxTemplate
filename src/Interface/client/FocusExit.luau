--!strict
-- FocusExit: the ways out of a focused screen (kitchen-focus.md §2; owner 2026-10-21: the talk at the tablet leaves like the
-- cooking focus). While bound, walking does not walk: W A S D / arrows / Space and the caller's Leave keys call OnLeave
-- (deferred, once per press); Sink keys are only swallowed. Stick = the gamepad's left stick pushed past STICK_DEAD leaves
-- too (else it is only sunk when listed in Sink). Touch = the touch controls stay on and the character moving or jumping
-- from them leaves (armed only once the character stood still, so a thumb already on the stick does not leave at once).
-- The Back button that does the same is Components/BackButton. Plain module; Bind returns the unbind.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

const STICK_DEAD = 0.5 -- of the stick's travel
const MOVE_DEAD = 0.1 -- Humanoid.MoveDirection magnitude read as walking (touch)

const WALK_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
	Enum.KeyCode.Space,
}

export type Options = {
	Name: string, -- ContextActionService action name
	Priority: number,
	OnLeave: (walked: boolean) -> (), -- walked = walking / the stick / touch; false = a Leave key
	Leave: { Enum.KeyCode }, -- keys that leave besides walking
	Sink: { Enum.KeyCode }?, -- keys only swallowed while bound
	Stick: boolean?,
	Touch: boolean?,
}

local function humanoid(): Humanoid?
	const character = Players.LocalPlayer.Character
	return if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
end

local function bind(options: Options): () -> ()
	local bound = true
	local function leave(walked: boolean)
		task.defer(function()
			if bound then
				options.OnLeave(walked)
			end
		end)
	end
	const walking: { [Enum.KeyCode]: boolean } = {}
	for _, key in WALK_KEYS do
		walking[key] = true
	end
	const leaving: { [Enum.KeyCode]: boolean } = {}
	const keys: { Enum.KeyCode } = {}
	for _, list in { WALK_KEYS, options.Leave } do
		for _, key in list do
			leaving[key] = true
			table.insert(keys, key)
		end
	end
	for _, key in options.Sink or {} do
		table.insert(keys, key)
	end
	if options.Stick and not table.find(keys, Enum.KeyCode.Thumbstick1) then
		table.insert(keys, Enum.KeyCode.Thumbstick1)
	end
	ContextActionService:BindActionAtPriority(options.Name, function(_name: string, state: Enum.UserInputState, input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			if options.Stick and state == Enum.UserInputState.Change and input.Position.Magnitude > STICK_DEAD then
				leave(true)
			end
		elseif state == Enum.UserInputState.Begin and leaving[input.KeyCode] then
			leave(walking[input.KeyCode] == true)
		end
		return Enum.ContextActionResult.Sink
	end, false, options.Priority, table.unpack(keys))

	local watch: RBXScriptConnection? = nil
	if options.Touch then
		local armed = false
		watch = RunService.Heartbeat:Connect(function()
			const body = humanoid()
			if body == nil then
				return
			end
			const moving = body.MoveDirection.Magnitude > MOVE_DEAD or body.Jump
			if not armed then
				armed = not moving
			elseif moving then
				leave(true)
			end
		end)
	end

	return function()
		if not bound then
			return
		end
		bound = false
		ContextActionService:UnbindAction(options.Name)
		if watch ~= nil then
			watch:Disconnect()
		end
	end
end

return table.freeze({
	Walk = table.freeze(WALK_KEYS),
	Bind = bind,
})
