--!strict

export type Reason = "Ok" | "Invalid" | "Expired" | "Already" | "Busy"
export type Reward = { Gems: number, Class: string? }

export type Public = {
	Broken: { [string]: boolean },
	ExpiresAt: { [string]: number },
	FailCount: { [Player]: number },
	FailStart: { [Player]: number },
	LastAt: { [Player]: number },
	Setup: (self: Public) -> (),
	Check: (self: Public) -> (),
	Allow: (self: Public, player: Player) -> boolean,
	CountFail: (self: Public, player: Player) -> (),
	Redeem: (self: Public, player: Player, raw: string) -> (Reason, Reward),
	Reply: (self: Public, player: Player, reason: Reason, reward: Reward) -> (),
}

return {}
