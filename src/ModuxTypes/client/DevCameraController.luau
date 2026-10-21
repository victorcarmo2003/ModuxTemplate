--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraTracks = require(ReplicatedStorage.shared.Dev.CameraTracks)

type Playing = {
	Track: Track,
	At: number, -- server time of the start
	Reached: number, -- index of the last key whose Note was printed
	ModeBefore: CameraMode,
	FovBefore: number,
	Hidden: boolean,
}
type SavedUi = {
	Guis: { [ScreenGui]: boolean },
	Core: { [Enum.CoreGuiType]: boolean },
	Chat: boolean?,
}
type Track = CameraTracks.Track
type CameraMode = "FirstPerson" | "Spectate" | "Fixed" | "Cutscene" | "Prep" | "External"

export type Public = {
	Enabled: boolean,
	NextHere: number,
	Playing: Playing?,
	Saved: SavedUi,
	Setup: (self: Public) -> (),
	HideUi: (self: Public) -> (),
	ShowUi: (self: Public) -> (),
	Play: (self: Public, key: string) -> (),
	Stop: (self: Public, reason: string) -> (),
	Notes: (self: Public, playing: Playing, t: number) -> (),
	Step: (self: Public) -> (),
	Refresh: (self: Public) -> (),
	SendHere: (self: Public, now: number) -> (),
}

return {}
