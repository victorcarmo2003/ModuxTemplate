--!strict
-- What a focused station gets from CookController (kitchen-focus.md §2) and what it gives back. Types only.
local Paw = require(script.Parent.Paw)
local Juice = require(script.Parent.Juice)

-- One Cook packet (Net.Restaurant Cook)
export type Send = {
	Act: "Cut" | "Place" | "Flip" | "Collect" | "Topping",
	Slot: number,
	Score: number,
	Key: string?,
	Points: { number }?,
}

export type Session = {
	Target: Instance, -- the model / folder of the station
	Folder: Folder, -- local props live here (destroyed on leave)
	Top: Vector3, -- top centre of the station's visible parts
	Size: Vector3, -- their bounding box
	Right: Vector3, -- horizontal screen right of the focus camera
	Toward: Vector3, -- horizontal, from the station toward the camera
	Hint: (text: string) -> (),
	Graded: (score: number, at: Vector3?) -> (), -- the band of a gesture: floats up from `at` with particles and a sound
	-- the live bar of the gesture in progress, 0..1 (the cut along the line, the sauce over the pattern); nil hides it
	Progress: (fraction: number?) -> (),
	Juice: Juice.Juice, -- particles, sounds and popups of the focus (owner 2026-10-19)
	Done: () -> (), -- the step is over: the focus leaves by itself a moment later
	Send: (data: Send) -> (),
	Held: () -> Tool?, -- the Tool in the own hand
	Records: () -> { [number]: any }, -- Stations set (record id -> record)
	Order: () -> { string }?, -- the order of the held plate's ticket line, nil = not known
	Paw: Paw.Paw, -- the gesture coach (DEC-311): Show the gesture to make, Learned once the player made it
}

export type Handler = {
	Pointer: (kind: string, position: Vector2) -> (),
	Step: (dt: number) -> (),
	Stop: () -> (),
}

return nil
