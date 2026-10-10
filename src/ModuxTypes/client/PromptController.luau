--!strict

local StarterPlayer = game:GetService("StarterPlayer")
local Prompt = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Prompt)
local Rules = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Rules)

export type Public = {
	Gui: Instance?,
	HoldThread: thread?,
	Holding: Prompt.Prompt?,
	LastFire: number,
	Prompts: { [Instance]: Prompt.Prompt },
	Target: Prompt.Prompt?,
	Setup: (self: Public) -> (),
	Add: (self: Public, anchor: Instance) -> (),
	Remove: (self: Public, anchor: Instance) -> (),
	Fire: (self: Public, prompt: Prompt.Prompt) -> (),
	CancelHold: (self: Public) -> (),
	BeginHold: (self: Public, prompt: Prompt.Prompt) -> (),
	EndHold: (self: Public) -> (),
	SetTarget: (self: Public, prompt: Prompt.Prompt?) -> (),
	HideAll: (self: Public) -> (),
	Held: (self: Public, character: Model) -> Rules.Held?,
	RulesContext: (self: Public, character: Model) -> Rules.Context,
	Tick: (self: Public) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
