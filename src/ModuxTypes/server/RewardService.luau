--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Atomic = require(ReplicatedStorage.shared.Types.Atomic)
local Ledger = require(ServerScriptService.server.Economy.EconomyService.Ledger)
local Template = require(ServerScriptService.server.Profile.ProfileService.Template)

type Profile = Atomic.Table<Template.Data>
type ShiftInfo = { Day: number, Night: number, IsNight: boolean, Attempt: number }
type ShiftReport = Ledger.Report
type RunRewards = { RunId: string, Keys: { string }, Gems: number }
export type Extra = (profile: Profile) -> ()
type Pending = { Until: number, Run: (player: Player, profile: Profile) -> () }

export type Public = {
	AwardBadge: (userId: number, badgeId: number) -> boolean,
	Awarding: { [string]: boolean },
	Pending: { [Player]: { Pending } },
	ShiftGems: { [number]: number },
	Warned: { [string]: boolean },
	Worked: { [number]: boolean },
	Setup: (self: Public) -> (),
	RunId: (self: Public) -> string,
	RunRewardsOf: (self: Public, profile: Profile) -> RunRewards,
	HasKey: (self: Public, profile: Profile, key: string) -> boolean,
	RunGems: (self: Public, player: Player) -> number,
	IsPresent: (self: Public, player: Player) -> boolean,
	Credit: (self: Public, player: Player, profile: Profile, key: string, gems: number, extra: Extra?) -> number,
	HasWorked: (self: Public, player: Player) -> boolean,
	ForPresent: (self: Public, pay: (player: Player, profile: Profile) -> ()) -> (),
	FlushPending: (self: Public, player: Player, profile: Profile) -> (),
	Toast: (self: Public, player: Player, gems: number) -> (),
	CheckAchievements: (self: Public, player: Player, profile: Profile) -> number,
	Unlock: (self: Public, player: Player, key: string) -> boolean,
	NightBadges: (self: Public, night: number) -> (),
	AwardPending: (self: Public, player: Player, profile: Profile) -> (),
	ReportStep: (self: Public, info: ShiftInfo, report: ShiftReport) -> (),
	NightWon: (self: Public, info: ShiftInfo) -> (),
	RunFailed: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	DevProfile: (self: Public, player: Player) -> Profile,
	DevSetEndless: (self: Public, player: Player, days: number) -> number,
	DevForget: (self: Public, player: Player) -> number,
	DevStatus: (self: Public, player: Player) -> string,
}

return {}
