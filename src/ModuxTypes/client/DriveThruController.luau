--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lane = require(ReplicatedStorage.shared.DriveThru.Lane)

export type CarRecord = { State: string, Npc: number, Look: number, At: number, Pet: boolean? }
export type Patience = { EndsAt: number, Span: number, Phase: string, State: string, Mood: string }
export type View = {
	Npc: number,
	Model: Model,
	S: number, -- distance along the lane now
	Move: Move?,
	State: string,
	Spot: number, -- 0 = no record any more
	LostAt: number, -- os.clock() the record went (0 = has one)
	Horned: { [number]: boolean }, -- HornAt indices played for the running clock
	ClockKey: number, -- PatienceEndsAt the Horned set belongs to
	HopAt: number, -- os.clock() of the last horn (hop)
}
export type Move = { From: number, To: number, Start: number, Duration: number, Accel: boolean }

export type Public = {
	DriveTalk: number,
	Folder: Folder?,
	Hidden: { [Model]: boolean },
	HideAt: number,
	Lane: Lane.Lane?,
	Patience: { [number]: Patience },
	Records: { [number]: CarRecord },
	Views: { [number]: View },
	Setup: (self: Public) -> (),
	Container: (self: Public) -> Folder,
	OnRecord: (self: Public, spot: number, record: CarRecord?) -> (),
	Apply: (self: Public, spot: number, record: CarRecord) -> (),
	Leave: (self: Public, car: View, at: number) -> (),
	Horn: (self: Public, car: View, sound: string) -> (),
	CheckHorn: (self: Public, car: View, t: number) -> (),
	Step: (self: Public) -> (),
	HideRigs: (self: Public) -> (),
	Rebuild: (self: Public) -> (),
}

return {}
