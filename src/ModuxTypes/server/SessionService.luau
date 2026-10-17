--!strict

export type RunState = "Starting" | "Live" | "Suspended" | "Resuming" | "Ended"
export type RunRecord = {
	V: number,
	Code: string,
	Roster: { number },
	State: RunState,
	JobId: string,
	Day: number,
	IsNight: boolean,
	-- Suspended / Resuming: os.time() the resume window closes; 0 otherwise
	ExpiresAt: number,
	CreatedAt: number,
	UpdatedAt: number,
}
export type Pointer = { V: number, RunId: string, Code: string, At: number }
export type Mode = "None" | "Rejoin" | "Resume"
export type Offer = { RunId: string, Code: string, Dev: boolean, Mode: Mode }
type Reason = "None" | "Ended" | "Failed" | "StudioNoTeleport" | "TooFast"
type Verdict = "Claimed" | "Resume" | "Taken" | "Dead" | "None"

export type Public = {
	BootRoster: { number },
	Checked: { [Player]: boolean },
	Claimed: boolean,
	Code: string,
	CreatedAt: number,
	Ended: boolean,
	FromRejoin: boolean,
	Joining: { [Player]: number },
	LastReply: { [Player]: number },
	Offers: { [Player]: Offer },
	Pointers: MemoryStoreHashMap?,
	Resumed: boolean,
	RunId: string,
	Runs: MemoryStoreHashMap?,
	Snaps: MemoryStoreHashMap?,
	State: RunState,
	Warned: { [string]: boolean },
	Written: { [string]: any }?,
	Setup: (self: Public) -> (),
	Warn: (self: Public, what: string, err: any) -> (),
	Open: (self: Public) -> boolean,
	GetRun: (self: Public, runId: string) -> RunRecord?,
	GetPointer: (self: Public, userId: number) -> Pointer?,
	SetPointer: (self: Public, userId: number, pointer: Pointer, ttl: number?) -> (),
	ClearPointer: (self: Public, userId: number, runId: string?) -> (),
	GetSnap: (self: Public, runId: string) -> { [string]: any }?,
	SetSnap: (self: Public, snapshot: { [string]: any }, ttl: number) -> boolean,
	Register: (self: Public, runId: string, code: string, roster: { number }) -> (),
	Send: (self: Public, player: Player, mode: Mode, reason: Reason, run: RunRecord?, left: number?) -> (),
	OpenRun: (self: Public, userId: number, runId: string) -> (RunRecord?, Mode, number),
	Offer: (self: Public, player: Player, runId: string, run: RunRecord, mode: Mode, left: number) -> (),
	WaitReady: (self: Public, player: Player) -> boolean,
	Check: (self: Public, player: Player) -> (),
	DevOffer: (self: Public, player: Player, mode: Mode) -> (),
	HandleReply: (self: Public, player: Player, accept: boolean) -> (),
	Rejoin: (self: Public, player: Player, offer: Offer) -> (),
	OnTeleportFailed: (self: Public, player: Player, result: Enum.TeleportResult, message: string) -> (),
	Record: (self: Public, state: RunState) -> RunRecord,
	RosterIds: (self: Public) -> { number },
	PointerHere: (self: Public) -> Pointer,
	Claim: (self: Public, rejoin: boolean) -> Verdict,
	Beat: (self: Public) -> (),
	WatchSnapshots: (self: Public) -> (),
	EndRun: (self: Public) -> (),
	Suspend: (self: Public) -> (),
	OnMemberLeft: (self: Public, player: Player) -> (),
	OnMemberJoined: (self: Public, player: Player) -> (),
	DeadRun: (self: Public, forget: boolean) -> (),
	Resume: (self: Public) -> boolean,
	StartRun: (self: Public) -> (),
}

return {}
