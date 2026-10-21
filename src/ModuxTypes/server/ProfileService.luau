--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Atomic = require(ReplicatedStorage.shared.Types.Atomic)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Struct = require(ReplicatedStorage.shared.Types.Struct)
local Template = require(ServerScriptService.server.Profile.ProfileService.Template)

export type Data = Template.Data
export type Profile = Atomic.Table<Data>

export type Public = {
	Disposers: { [Player]: () -> () },
	Loaded: SignalLib.Signal<Player, Profile>,
	Message: SignalLib.Signal<Player, { [string]: any }, () -> ()>,
	Profiles: { [Player]: Profile },
	SavePending: { [Player]: boolean },
	Sessions: { [Player]: any },
	Store: any,
	Setup: (self: Public) -> (),
	MessageAsync: (self: Public, userId: number, message: { [string]: any }) -> boolean,
	ExistsAsync: (self: Public, userId: number) -> boolean?,
	Get: (self: Public, player: Player) -> Profile?,
	Update: (self: Public, player: Player, patch: Struct.Partial<Data>) -> (),
	RequestSave: (self: Public, player: Player) -> (),
	OwnedClasses: (self: Public, profile: Profile) -> { [string]: boolean },
	WithClass: (self: Public, profile: Profile, key: string) -> { [string]: boolean },
	SaveConfirmed: (self: Public, player: Player, saved: (data: { [string]: any }) -> boolean, timeout: number?) -> boolean,
	SelectedClass: (self: Public, profile: Profile) -> string,
	Leaderstats: (self: Public, player: Player) -> (),
	Replicate: (self: Public, player: Player) -> (),
	LobbyGuides: (self: Public, profile: Profile) -> { [string]: boolean },
	Migrate: (self: Public, data: { [string]: any }) -> (),
	Bind: (self: Public, player: Player, session: any) -> Profile,
	Load: (self: Public, player: Player) -> (),
	Forget: (self: Public, player: Player) -> (),
	Unload: (self: Public, player: Player) -> (),
}

return {}
