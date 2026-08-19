local ContextActionService = game:GetService("ContextActionService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)

export type Context = "Gameplay" | "Menu"

export type ContextCallback = (NewContext: Context) -> ()

export type HandlerType = {
	OnPress: (() -> ()) -> HandlerType,
	OnRelease: (() -> ()) -> HandlerType,
	Unbind: () -> (),
	_onPressCallbacks: { [number]: () -> () },
	_onReleaseCallbacks: { [number]: () -> () },
}

export type InputSettings = {
	ActionName: string,
	ActionKey: Enum.KeyCode | Enum.UserInputType,
	TouchButton: boolean?,
	ActionPriority: number?,
	Context: Context?,
	Position: UDim2?,
}

local InputController = Modux.Controller("InputController")
type Self = typeof(InputController)
InputController.allHandlers = {} :: { [string]: HandlerType }
InputController._listeners = {} :: { ContextCallback }

local function processInput(ActionName: string, InputState: Enum.UserInputState, inputObject: InputObject)
	for name, data in InputController.allHandlers do
		if ActionName ~= name then
			continue
		end

		if InputState == Enum.UserInputState.Begin and data._onPressCallbacks then
			for _, func in data._onPressCallbacks do
				func()
			end
		end

		if InputState == Enum.UserInputState.End and data._onReleaseCallbacks then
			for _, func in data._onReleaseCallbacks do
				func()
			end
		end

		return Enum.ContextActionResult.Sink
	end

	warn(`[InputController - ProcessInput] Error {ActionName} not founded in registered!`, InputController.allHandlers)
	return Enum.ContextActionResult.Pass
end

InputController.OnContextChange = function(self: Self, callback: ContextCallback)
	table.insert(self._listeners, callback)
end

InputController.UnbindAction = function(self: Self, ActionName: string)
	ContextActionService:UnbindAction(ActionName)
end

InputController.BindAction = function(self: Self, ActionConfig: InputSettings): HandlerType
	local ActionName, ActionPriority, ActionKey, TouchButton =
		ActionConfig.ActionName, ActionConfig.ActionPriority, ActionConfig.ActionKey, ActionConfig.TouchButton

	local handler = {
		_onPressCallbacks = {},
		_onReleaseCallbacks = {},
		Unbind = function()
			self:UnbindAction(ActionConfig.ActionName)
		end,
	} :: any

	handler.OnPress = function(callback: () -> ())
		table.insert(handler._onPressCallbacks, callback)
		return handler
	end

	handler.OnRelease = function(callback: () -> ())
		table.insert(handler._onReleaseCallbacks, callback)
		return handler
	end

	InputController.allHandlers[ActionName] = handler

	ContextActionService:BindActionAtPriority(
		ActionName,
		processInput,
		TouchButton or false,
		ActionPriority or 0,
		ActionKey
	)

	if ActionConfig.Position then
		ContextActionService:SetPosition(ActionName, ActionConfig.Position)
	end

	return handler :: HandlerType
end

InputController.ChangeContext = function(self: Self, newContext: Context)
	self.Context = newContext
	for _, listeners in self._listeners do
		task.spawn(function()
			listeners(newContext)
		end)
	end
end

InputController:OnInit(function(self)
	self.Context = "Gameplay" :: Context
end)

return InputController
