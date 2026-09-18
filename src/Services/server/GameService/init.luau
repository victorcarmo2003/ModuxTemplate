--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Lync = require(ReplicatedStorage.Packages.Lync)
local Modux = require(ServerScriptService.server.Modux)

export type Status = "Waiting" | "Playing" | "Ending"

const INTERMISSION = 15
const ROUND = 120
const ENDING = 5

const GameService = Modux.Service("GameService", { Priority = 600 })

function GameService:Setup()
	self.Status = self.Libs.Charm.atom("Waiting") :: Charm.Atom<Status>
	self.Seconds = self.Libs.Charm.atom(INTERMISSION) :: Charm.Atom<number>
end

function GameService:Enter(status: Status, seconds: number)
	self.Libs.Charm.batch(function()
		self.Status(status)
		self.Seconds(seconds)
	end)
end

function GameService:Advance()
	const status = self.Status()
	if status == "Waiting" then
		self:Enter("Playing", ROUND)
	elseif status == "Playing" then
		self:Enter("Ending", ENDING)
	else
		self:Enter("Waiting", INTERMISSION)
	end
end

GameService:OnInit(function(self)
	self:Setup()
end)

GameService:OnStart(function(self)
	self.Libs.Charm.effect(function()
		self.Libs.Net.Round:fireClient(Lync.all, {
			Status = self.Status(),
			Seconds = self.Seconds(),
		})
	end)
end)

GameService:OnTick(function(self)
	const remaining = self.Seconds() - 1
	if remaining > 0 then
		self.Seconds(remaining)
		return
	end
	self:Advance()
end, 1)

return GameService
