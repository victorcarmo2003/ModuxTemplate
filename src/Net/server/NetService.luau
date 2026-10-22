--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Lync = require(ReplicatedStorage.Packages.Lync)
local quietLync = require(ReplicatedStorage.shared.Net.Log)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

const NetService = Modux.Service("NetService", { Priority = 1000 })

-- Lync's internal set state (no public per-player resync in 4.0.2): Sync.joined(sync, player) is exactly what the
-- server does when it admits a client (every record it can see queued for it as keyframes). Found next to the
-- package Packages.Lync points to; nil when that layout changed (a Lync upgrade): then Resync only warns.
type LyncSync = { joined: (sync: any, who: Player) -> () }

local function findSync(): LyncSync?
	const index = ReplicatedStorage.Packages:FindFirstChild("_Index")
	if index == nil then
		return nil
	end
	for _, package in index:GetChildren() do
		if string.find(package.Name, "^axp3cter_lync@") == nil then
			continue
		end
		const root = package:FindFirstChild("lync")
		const state = if root ~= nil then root:FindFirstChild("state") else nil
		const module = if state ~= nil then state:FindFirstChild("Sync") else nil
		if module ~= nil and module:IsA("ModuleScript") then
			const ok, sync = pcall(function(): any
				return (require :: any)(module)
			end)
			if ok and type(sync) == "table" and type(sync.joined) == "function" then
				return sync :: LyncSync
			end
		end
	end
	return nil
end

function NetService:Setup()
	self.Running = false :: boolean
	self.ClientReady = self.Libs.Signal.new() :: SignalLib.Signal<Player>
	self.Ready = {} :: { [Player]: boolean }
	self.ResyncWarned = false :: boolean
	self.Audience = Lync.group() :: Lync.Group
end

function NetService:IsReady(player: Player): boolean
	return self.Ready[player] == true
end

function NetService:IsRunning(): boolean
	return self.Running
end

-- Every record of every set queued again for this player alone, as keyframes (one it already holds arrives as an
-- onChanged with the same values; one it lost arrives as onAdded). Why: a client admitted before its own Lync
-- handshake ended (in Players when the server's Lync.start ran, or handshake reply and backlog crossing on different
-- remotes) drops that backlog as drop.unready (silenced), Lync never sends it again, and deltas do not recreate a
-- record the client lacks (Lync state/Apply.luau `advanced` skips unknown slots). Called on `Ready`, which the client
-- only sends after its handshake, so these keyframes cannot be dropped the same way.
function NetService:Resync(player: Player)
	const sync = findSync()
	if sync == nil then
		if not self.ResyncWarned then
			self.ResyncWarned = true
			warn("[NetService] Lync internals not found (version changed?): no per-player resync on Ready")
		end
		return
	end
	-- one Lync session per namespace: "game" (Net) and "restaurant" (Net.Restaurant: Tablets, Plates, DriveCars...). Only
	-- "game" was resynced (owner 2026-10-22: on a reserved server the order talk never showed, the client had no Tablets
	-- record at all)
	const sessions: { any } = {}
	for _, namespace in { self.Libs.Net, Restaurant } :: { any } do
		for _, handle in namespace do
			if type(handle) == "table" and handle.kind == "set" and type(handle.live) == "table" then
				const session = handle.live.session
				if session ~= nil then
					if not table.find(sessions, session) then
						table.insert(sessions, session)
					end
					break
				end
			end
		end
	end
	for _, session in sessions do
		if type(session.order) ~= "table" or type(session.sets) ~= "table" then
			continue
		end
		const ok, problem = pcall(function()
			for _, id in session.order do
				sync.joined(session.sets[id], player)
			end
		end)
		if not ok then
			warn(`[NetService] resync of {player.Name} failed: {problem}`)
		end
	end
end

NetService:OnInit(function(self)
	self:Setup()
	quietLync()

	self.Libs.Net.Ready:onServer(function(_, player: Player)
		self.Ready[player] = true
		self.Audience:add(player)
		if self.Running then
			self:Resync(player)
		end
		self.ClientReady:Fire(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.Ready[player] = nil
	end)
end)

NetService:OnStart(function(self)
	Lync.start()
	self.Running = true

	game:BindToClose(function()
		self.Running = false
		Lync.close()
	end)
end)

NetService:OnTick(function(self)
	if not self.Running then
		return
	end
	Lync.flush()
end, 60, -1000)

return NetService
