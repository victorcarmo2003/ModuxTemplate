--!strict
-- Input by ContextActionService, with a context (Gameplay/Menu) and the current device.
-- Every command binds desktop (Key), gamepad (Keys) and mobile (TouchButton) in one Binding.
-- Device is the port of AnimalPlane `DeviceSettings` (architecture.md §13): the last input kind used, so prompts
-- show "E", "X" or no key chip (touch uses the fixed button).
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Context = "Gameplay" | "Menu"

export type Device = "KeyboardMouse" | "Gamepad" | "Touch"

export type Input = Enum.KeyCode | Enum.UserInputType

export type Binding = {
	Name: string,
	Key: Input,
	-- More inputs for the same action (gamepad button, alternate key).
	Keys: { Input }?,
	TouchButton: boolean?,
	-- Text on the mobile button.
	Title: string?,
	-- Side of the mobile button in px (CAS default is smaller than a comfortable thumb target on a phone).
	TouchSize: number?,
	Priority: number?,
	Position: UDim2?,
	-- Only dispatch while this context is active; nil = any context.
	Context: Context?,
}

export type Handle = {
	OnPress: (callback: () -> ()) -> Handle,
	OnRelease: (callback: () -> ()) -> Handle,
	Unbind: () -> (),
	_press: { () -> () },
	_release: { () -> () },
	_context: Context?,
}

local function deviceOf(inputType: Enum.UserInputType): Device?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.sub(inputType.Name, 1, 7) == "Gamepad" then
		return "Gamepad"
	elseif
		inputType == Enum.UserInputType.Keyboard
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.MouseWheel
	then
		return "KeyboardMouse"
	end
	return nil
end

local function initialDevice(): Device
	const last = deviceOf(UserInputService:GetLastInputType())
	if last then
		return last
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	return "KeyboardMouse"
end

const InputController = Modux.Controller("InputController", { Priority = 900 })

function InputController:Setup()
	self.Context = "Gameplay" :: Context
	self.Handles = {} :: { [string]: Handle }
	self.Listeners = {} :: { (Context) -> () }
	self.Device = Vide.source(initialDevice()) :: Vide.Source<Device>
end

function InputController:Dispatch(name: string, state: Enum.UserInputState): Enum.ContextActionResult
	const handle = self.Handles[name]
	if not handle then
		return Enum.ContextActionResult.Pass
	end

	-- A release always goes through, so a hold that started before a context change can end.
	if handle._context and handle._context ~= self.Context and state == Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	const callbacks = if state == Enum.UserInputState.Begin
		then handle._press
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then handle._release
		else nil

	if callbacks then
		for _, callback in callbacks do
			task.spawn(callback)
		end
	end

	return Enum.ContextActionResult.Sink
end

function InputController:Bind(binding: Binding): Handle
	if self.Handles[binding.Name] then
		self:Unbind(binding.Name)
	end

	const handle = {
		_press = {},
		_release = {},
		_context = binding.Context,
	} :: Handle

	handle.OnPress = function(callback: () -> ()): Handle
		table.insert(handle._press, callback)
		return handle
	end

	handle.OnRelease = function(callback: () -> ()): Handle
		table.insert(handle._release, callback)
		return handle
	end

	handle.Unbind = function()
		if self.Handles[binding.Name] == handle then
			self:Unbind(binding.Name)
		end
	end

	self.Handles[binding.Name] = handle

	const inputs: { Input } = { binding.Key }
	for _, key in binding.Keys or {} do
		table.insert(inputs, key)
	end

	ContextActionService:BindActionAtPriority(
		binding.Name,
		function(name: string, state: Enum.UserInputState): Enum.ContextActionResult
			return self:Dispatch(name, state)
		end,
		binding.TouchButton or false,
		binding.Priority or 0,
		table.unpack(inputs)
	)

	if binding.TouchButton then
		if binding.Title then
			ContextActionService:SetTitle(binding.Name, binding.Title)
		end
		if binding.Position then
			ContextActionService:SetPosition(binding.Name, binding.Position)
		end
		const size = binding.TouchSize
		const button = ContextActionService:GetButton(binding.Name)
		if size and button then
			button.Size = UDim2.fromOffset(size, size)
		end
	end

	return handle
end

function InputController:Unbind(name: string)
	if self.Handles[name] == nil then
		return
	end
	self.Handles[name] = nil
	ContextActionService:UnbindAction(name)
end

function InputController:OnContextChange(callback: (Context) -> ())
	table.insert(self.Listeners, callback)
end

function InputController:SetContext(context: Context)
	if self.Context == context then
		return
	end
	self.Context = context
	for _, listener in self.Listeners do
		task.spawn(listener, context)
	end
end

InputController:OnInit(function(self)
	self:Setup()

	UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		const device = deviceOf(inputType)
		if device and device ~= self.Device() then
			self.Device(device)
		end
	end)
end)

return InputController
