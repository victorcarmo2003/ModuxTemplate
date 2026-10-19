--!strict
-- What a focused station gets from CookController (kitchen-focus.md §2) and what it gives back. Types only.

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
	Graded: (score: number) -> (), -- pops the band of a gesture
	Done: () -> (), -- the step is over: the focus leaves by itself a moment later
	Send: (data: Send) -> (),
	Held: () -> Tool?, -- the Tool in the own hand
	Records: () -> { [number]: any }, -- Stations set (record id -> record)
	Order: () -> { string }?, -- the order of the held plate's ticket line, nil = not known
}

export type Handler = {
	Pointer: (kind: string, position: Vector2) -> (),
	Step: (dt: number) -> (),
	Stop: () -> (),
}

return nil
