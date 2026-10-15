--!strict

local StarterPlayer = game:GetService("StarterPlayer")
local DeliverMark = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.DeliverMark)

type Candidate = { Anchor: Attachment, Rig: Model, Distance: number }

export type Public = {
	Current: Candidate?,
	Dragging: boolean,
	Mark: DeliverMark.Mark?,
	Over: Attachment?,
	TouchAt: Vector2?,
	Setup: (self: Public) -> (),
	HeldHotDog: (self: Public) -> Tool?,
	Candidates: (self: Public) -> { Candidate },
	Under: (self: Public, candidates: { Candidate }, at: Vector2) -> Candidate?,
	Step: (self: Public) -> (),
	Drop: (self: Public, at: Vector2) -> (),
	BindInput: (self: Public) -> (),
}

return {}
