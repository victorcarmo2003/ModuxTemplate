--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Juice = require(StarterPlayer.StarterPlayerScripts.client.Cook.CookController.Juice)
local Pointer = require(StarterPlayer.StarterPlayerScripts.client.Cook.CookController.Pointer)
local Session = require(StarterPlayer.StarterPlayerScripts.client.Cook.CookController.Session)

type Station = "Board" | "Grill" | "Toppings"
type Active = {
	Station: Station,
	Session: Session.Session,
	Handler: Session.Handler,
	Pointer: Pointer.Pointer,
	Unmount: () -> (),
	Gui: Instance,
	Folder: Folder,
	Heartbeat: RBXScriptConnection,
	Exit: () -> (), -- unbinds the walk / leave keys (FocusExit)
}

export type Public = {
	Active: Active?,
	DoneAt: number?,
	Grade: Vide.Source<string | false>,
	GradeToken: number,
	Hint: Vide.Source<string>,
	Orders: { [number]: { { [string]: boolean } } },
	Progress: Vide.Source<number | false>,
	Pulse: Vide.Source<number>,
	Scale: Vide.Source<number>,
	Setup: (self: Public) -> (),
	IsOpen: (self: Public) -> boolean,
	Station: (self: Public) -> string?,
	Held: (self: Public) -> Tool?,
	Order: (self: Public) -> { string }?,
	Pose: (self: Public, station: Station, target: Instance) -> (Vector3, Vector3, Vector3, Vector3, CFrame, Vector3, number),
	Feedback: (self: Public, juice: Juice.Juice, score: number, at: Vector3?) -> (),
	ShowGrade: (self: Public, score: number) -> (),
	Enter: (self: Public, station: Station, target: Instance) -> (),
	Leave: (self: Public) -> (),
	WriteCustomer: (self: Public, id: number, record: any?) -> (),
}

return {}
