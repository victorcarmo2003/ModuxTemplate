--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Context = "Gameplay" | "Menu"
export type Device = "KeyboardMouse" | "Gamepad" | "Touch"
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
export type Input = Enum.KeyCode | Enum.UserInputType

export type Public = {
	Context: Context,
	Device: Vide.Source<Device>,
	Handles: { [string]: Handle },
	Holds: { [string]: boolean },
	Listeners: { (Context) -> () },
	Setup: (self: Public) -> (),
	Dispatch: (self: Public, name: string, state: Enum.UserInputState) -> Enum.ContextActionResult,
	Bind: (self: Public, binding: Binding) -> Handle,
	Unbind: (self: Public, name: string) -> (),
	OnContextChange: (self: Public, callback: (Context) -> ()) -> (),
	SetContext: (self: Public, context: Context) -> (),
	Hold: (self: Public, owner: string, on: boolean) -> (),
}

return {}
