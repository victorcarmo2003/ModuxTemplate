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
	Seat: CFrame, -- the driver's root, from the car pivot
	Rig: Model?, -- the customer's rig on that seat (nil = not found yet)
	-- rest C0 of the joints this client bent on Rig (sitting pose, head turn), put back on release (owner 2026-10-20)
	Rest: { [Motor6D]: CFrame },
	Look: number, -- current head turn (rad) towards the local camera
}
export type Move = { From: number, To: number, Start: number, Duration: number, Accel: boolean }

export type Public = {
	DriveTalk: number,
	FindAt: number,
	Folder: Folder?,
	Lane: Lane.Lane?,
	Patience: { [number]: Patience },
	Records: { [number]: CarRecord },
	Views: { [number]: View },
	Window: Vector3?,
	Setup: (self: Public) -> (),
	Container: (self: Public) -> Folder,
	OnRecord: (self: Public, spot: number, record: CarRecord?) -> (),
	Apply: (self: Public, spot: number, record: CarRecord) -> (),
	Leave: (self: Public, car: View, at: number) -> (),
	Horn: (self: Public, car: View, sound: string) -> (),
	CheckHorn: (self: Public, car: View, t: number) -> (),
	Step: (self: Public) -> (),
	AlignWindow: (self: Public, car: View, pose: CFrame) -> CFrame,
	Release: (self: Public, car: View) -> (),
	SeatDriver: (self: Public, car: View, pose: CFrame) -> (),
	LookAtCamera: (self: Public, car: View, rig: Model) -> (),
	FindRigs: (self: Public) -> (),
	Rebuild: (self: Public) -> (),
}

return {}
