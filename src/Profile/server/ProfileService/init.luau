--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Content = require(ReplicatedStorage.shared.Content)
local Atomic = require(ReplicatedStorage.shared.Types.Atomic)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Struct = require(ReplicatedStorage.shared.Types.Struct)
local Migrations = require(script.Migrations)
local Template = require(script.Template)
local Modux = require(ServerScriptService.server.Modux)

export type Data = Template.Data
export type Profile = Atomic.Table<Data>

const STORE_NAME = "Player"
const SAVE_DELAY = 2 -- RequestSave groups events within this window (architecture.md §10.3)
const DEFAULT_CLASS = "class_dog" -- free class, fallback for unknown or unowned selections (data.md §1.5)

const ProfileService = Modux.Service(
	"ProfileService",
	{ Require = { "PlayerService", "NetService" }, Priority = 800 }
)

function ProfileService:Setup()
	-- ProfileStore types the template as `(T & JSONAcceptable)?`, a recursive union with only indexer tables; the
	-- new solver cannot fit a sealed record (Data) into it. ProfileStore checks the template at runtime and the
	-- shape is owned by Template.Data, so the template crosses as `any`. The result stays `any` because the Modux
	-- generator needs an annotation and `ProfileStore<Data>` is too complex for the solver (Data & JSONAcceptable).
	self.Store = ProfileStore.New(STORE_NAME, Template :: any) :: any
	self.Sessions = {} :: { [Player]: any }
	self.SavePending = {} :: { [Player]: boolean }
	self.Profiles = {} :: { [Player]: Profile }
	self.Disposers = {} :: { [Player]: () -> () }
	self.Loaded = self.Libs.Signal.new() :: SignalLib.Signal<Player, Profile>
end

function ProfileService:Get(player: Player): Profile?
	return self.Profiles[player]
end

function ProfileService:Update(player: Player, patch: Struct.Partial<Data>)
	const profile = self.Profiles[player]
	if not profile then
		warn(`[ProfileService] {player.Name} has no loaded profile`)
		return
	end

	const fields: { [string]: (any) -> any } = profile :: any
	self.Libs.Charm.batch(function()
		for key, value in patch :: { [string]: any } do
			const field = fields[key]
			if field == nil then
				warn(`[ProfileService] {key} is not a profile field`)
				continue
			end
			field(value)
		end
	end)
end

-- Saves within SAVE_DELAY seconds, grouping every request made meanwhile into one UpdateAsync (DEC-104).
-- The atom already holds the value; a server dying inside the window loses that event (R5, accepted).
function ProfileService:RequestSave(player: Player)
	if self.SavePending[player] or not self.Sessions[player] then
		return
	end
	self.SavePending[player] = true
	task.delay(SAVE_DELAY, function()
		self.SavePending[player] = nil
		const session = self.Sessions[player]
		if session and session:IsActive() then
			session:Save()
		end
	end)
end

-- Unlocked classes known to Content; unknown keys are ignored on read (data.md §1.5).
function ProfileService:OwnedClasses(profile: Profile): { [string]: boolean }
	const owned: { [string]: boolean } = {}
	for key, unlocked in profile.Classes() do
		if unlocked == true and Content.Classes.ByKey[key] ~= nil then
			owned[key] = true
		end
	end
	owned[DEFAULT_CLASS] = true
	return owned
end

-- Selected class, falling back to the Dog when it is unknown or not owned (read only, nothing is written).
function ProfileService:SelectedClass(profile: Profile): string
	const selected = profile.SelectedClass()
	if Content.Classes.ByKey[selected] == nil or self:OwnedClasses(profile)[selected] ~= true then
		return DEFAULT_CLASS
	end
	return selected
end

function ProfileService:Replicate(player: Player)
	const profile = self.Profiles[player]
	if not profile then
		return
	end
	if not self.Dependencies.NetService:IsReady(player) then
		return
	end

	self.Libs.Net.Profile:fireClient(player, {
		Gems = math.clamp(profile.Gems(), 0, 2147483647),
		Classes = self:OwnedClasses(profile),
		Selected = self:SelectedClass(profile),
	})
end

-- Runs Migrations[v] while the data is behind the Template version (data.md §1.5). Reconcile runs before this.
function ProfileService:Migrate(data: { [string]: any })
	const target = Template.Version
	while type(data.Version) == "number" and data.Version < target do
		const step = Migrations[data.Version]
		if not step then
			warn(`[ProfileService] no migration from version {data.Version}`)
			return
		end
		step(data)
		data.Version += 1
	end
end

function ProfileService:Bind(player: Player, session: any): Profile
	const profile = {}
	for key, value in session.Data do
		profile[key] = self.Libs.Charm.atom(value)
	end
	self.Profiles[player] = profile :: any

	self.Disposers[player] = self.Libs.Charm.effect(function()
		for key, field in profile do
			session.Data[key] = field()
		end
		self:Replicate(player)
	end)

	return profile :: any
end

function ProfileService:Load(player: Player)
	const session = self.Store:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not session then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	session:AddUserId(player.UserId)
	session:Reconcile()
	self:Migrate(session.Data)
	session.OnSessionEnd:Connect(function()
		if self.Sessions[player] == nil then
			return
		end
		self:Forget(player)
		player:Kick("Your data session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		session:EndSession()
		return
	end

	self.Sessions[player] = session
	self.Loaded:Fire(player, self:Bind(player, session))
end

function ProfileService:Forget(player: Player)
	const dispose = self.Disposers[player]
	if dispose then
		dispose()
		self.Disposers[player] = nil
	end
	self.Profiles[player] = nil
	self.Sessions[player] = nil
	self.SavePending[player] = nil
end

function ProfileService:Unload(player: Player)
	const session = self.Sessions[player]
	self:Forget(player)
	if session then
		session:EndSession()
	end
end

ProfileService:OnInit(function(self)
	self:Setup()

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:Load(player)
		end)
	end)
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Unload(player)
	end)

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:Replicate(player)
	end)
end)

return ProfileService
