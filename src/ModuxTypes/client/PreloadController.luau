--!strict

export type Public = {
	Done: boolean,
	Shelf: Folder?,
	Setup: (self: Public) -> (),
	BuildShelf: (self: Public) -> (),
	Background: (self: Public) -> (),
}

return {}
