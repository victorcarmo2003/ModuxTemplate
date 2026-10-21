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
const CONFIRM_TIMEOUT = 15 -- s SaveConfirmed waits for the data to reach the DataStore (architecture.md §10.1)
const LEADERSTATS = "leaderstats"
const STAT_NIGHTS = "Nights"
const STAT_GEMS = "Gems"
const CONFIRM_RETRY = 5 -- s between Save attempts while the DataStore keeps failing

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
	-- ProfileStore messages (ProfileStore:MessageAsync) of a loaded profile: (player, message, processed). The listener
	-- applies the message and calls processed(); an unprocessed message stays in the profile and comes back next session.
	-- Listener: GiftService (TASK-352)
	self.Message = self.Libs.Signal.new() :: SignalLib.Signal<Player, { [string]: any }, () -> ()>
end

-- Sends a ProfileStore message to the profile of any UserId (online here, elsewhere or offline). Yields; false = the
-- DataStore did not take it (the store is closing).
function ProfileService:MessageAsync(userId: number, message: { [string]: any }): boolean
	return self.Store:MessageAsync(`{userId}`, message) == true
end

-- A profile exists for this UserId (the player has played at least once). Yields; nil = the DataStore call failed.
function ProfileService:ExistsAsync(userId: number): boolean?
	const ok, profile = pcall(function()
		return self.Store:GetAsync(`{userId}`)
	end)
	if not ok then
		return nil
	end
	return profile ~= nil
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

-- Copy of profile.Classes with `key` unlocked: the profile changes by copy, never in place (data.md §1.1). Callers put
-- it in the same Update as the payment, so the grant and the debit/receipt land in one batch (data.md §1.7).
function ProfileService:WithClass(profile: Profile, key: string): { [string]: boolean }
	const classes = table.clone(profile.Classes())
	classes[key] = true
	return classes
end

-- Saves now and yields until `saved(LastSavedData)` holds, the session ends or `timeout` runs out (ProfileStore
-- developer-product pattern; data.md §1.4). The atoms are already in session.Data: the Charm effect runs when the
-- outermost batch of Update ends. Used by ShopService before PurchaseGranted.
function ProfileService:SaveConfirmed(
	player: Player,
	saved: (data: { [string]: any }) -> boolean,
	timeout: number?
): boolean
	const session = self.Sessions[player]
	if not session then
		return false
	end
	const deadline = os.clock() + (timeout or CONFIRM_TIMEOUT)
	while session:IsActive() do
		if session.LastSavedData ~= nil and saved(session.LastSavedData) then
			return true
		end
		const left = deadline - os.clock()
		if left <= 0 then
			return false
		end

		-- connect before Save: a save without yield (ProfileStore mock in Studio) would fire before a later Connect
		const thread = coroutine.running()
		local fired = false
		local waiting = false
		local connection: any = nil
		local function resume()
			if fired then
				return
			end
			fired = true
			if connection then
				connection:Disconnect()
			end
			if waiting then
				task.spawn(thread)
			end
		end
		connection = session.OnAfterSave:Connect(resume)
		session:Save()
		task.delay(math.min(left, CONFIRM_RETRY), resume)
		if not fired then
			waiting = true
			coroutine.yield()
		end
	end
	return false
end

-- Selected class, falling back to the Dog when it is unknown or not owned (read only, nothing is written).
function ProfileService:SelectedClass(profile: Profile): string
	const selected = profile.SelectedClass()
	if Content.Classes.ByKey[selected] == nil or self:OwnedClasses(profile)[selected] ~= true then
		return DEFAULT_CLASS
	end
	return selected
end

-- Roblox leaderstats (owner 2026-10-21): nights won (Stats.NightsWon) and the gem balance, on every server role.
-- Shown where the Roblox player list is on (the lobby, DEC-339); the run keeps it off under its pills.
function ProfileService:Leaderstats(player: Player)
	const profile = self.Profiles[player]
	if not profile or player.Parent == nil then
		return
	end
	local folder = player:FindFirstChild(LEADERSTATS)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = LEADERSTATS
		folder.Parent = player
	end
	local function set(name: string, value: number)
		local stat = (folder :: Instance):FindFirstChild(name)
		if stat == nil or not stat:IsA("IntValue") then
			const created = Instance.new("IntValue")
			created.Name = name
			created.Parent = folder
			stat = created
		end
		(stat :: IntValue).Value = math.max(math.floor(value), 0)
	end
	const stats = profile.Stats()
	-- creation order = column order in the player list
	set(STAT_NIGHTS, if type(stats) == "table" and type(stats.NightsWon) == "number" then stats.NightsWon else 0)
	set(STAT_GEMS, profile.Gems())
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
		TutorialDone = profile.TutorialDone() == true,
		Guides = self:LobbyGuides(profile),
	})
end

-- Lobby floor guides already shown. The pad guide counts as done for anyone who already started a run.
function ProfileService:LobbyGuides(profile: Profile): { [string]: boolean }
	const saved = profile.LobbyGuides()
	const out: { [string]: boolean } = {}
	for _, key in Content.Lobby.Guide.Keys do
		out[key] = type(saved) == "table" and saved[key] ~= nil
	end
	const stats = profile.Stats()
	if type(stats) == "table" and (stats.RunsStarted or 0) > 0 then
		out.pad = true
	end
	return out
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
		self:Leaderstats(player)
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
	-- after Bind and Loaded: listeners can read and Update the profile while they handle a message
	session:MessageHandler(function(message: any, processed: () -> ())
		if self.Sessions[player] ~= session or type(message) ~= "table" then
			return
		end
		self.Message:Fire(player, message, processed)
	end)
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
