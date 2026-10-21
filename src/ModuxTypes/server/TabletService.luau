--!strict

export type Tablet = {
	Index: number,
	Anchor: Instance?,
	State: TabletState,
	Npc: number, -- customer at this tablet, 0 = none
	User: Player?, -- who is taking the order
	StartedAt: number,
	EndsAt: number,
	Order: { string }, -- topping keys of the 1st hot dog
	Order2: { string }?, -- pair (FEAT-038)
	PromptOn: boolean?, -- last state written to the prompt (owner 2026-10-18: it showed with nobody at the counter)
	OrderTime: number?, -- s of the order talk after Accept (DEC-353), set at Start
}
export type TabletState = "Idle" | "Talking" | "Full" | "Deciding" | "Greeting"

export type Public = {
	AnchorTablet: { [Instance]: number },
	Enabled: boolean,
	NoticeAt: { [Player]: { [string]: number } },
	Published: { [number]: boolean },
	Tablets: { [number]: Tablet },
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	CustomerMethod: (self: Public, name: string) -> any,
	Pause: (self: Public, npc: number, on: boolean) -> (),
	PickupHasRoom: (self: Public) -> boolean,
	TalkTime: (self: Public, k1: number, k2: number?) -> number,
	Head: (self: Public, tablet: Tablet) -> number?,
	IsFull: (self: Public, npc: number?, drive: boolean?) -> boolean,
	Check: (self: Public, player: Player, tablet: Tablet) -> (boolean, string?),
	Start: (self: Public, player: Player, tablet: Tablet) -> boolean,
	Reset: (self: Public, tablet: Tablet) -> (),
	StartDrive: (self: Public, player: Player, npc: number) -> boolean,
	DriveTalking: (self: Public, npc: number) -> boolean,
	Ask: (self: Public, tablet: Tablet) -> (),
	Finish: (self: Public, tablet: Tablet) -> (),
	Decide: (self: Public, tablet: Tablet, player: Player, serve: boolean) -> (),
	UserGone: (self: Public, tablet: Tablet) -> boolean,
	Cancel: (self: Public, tablet: Tablet, why: string) -> (),
	StillThere: (self: Public, tablet: Tablet) -> boolean,
	UpdateFull: (self: Public, tablet: Tablet) -> boolean,
	SyncPrompt: (self: Public, tablet: Tablet) -> (),
	Step: (self: Public) -> (),
	Record: (self: Public, tablet: Tablet) -> any,
	Publish: (self: Public, tablet: Tablet) -> (),
	NotifyThrottled: (self: Public, player: Player, key: string) -> (),
	Bind: (self: Public) -> (),
	TabletAt: (self: Public, anchor: Instance) -> Tablet?,
	DevTablet: (self: Public, index: number?) -> Tablet,
	DevState: (self: Public, index: number?) -> string,
	DevTalk: (self: Public, player: Player, index: number?) -> string,
	DevFinish: (self: Public, index: number?) -> string,
}

return {}
