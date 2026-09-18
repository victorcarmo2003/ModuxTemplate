--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Lync = require(ReplicatedStorage.Packages.Lync)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const NetController = Modux.Controller("NetController", { Priority = 1000 })

NetController:OnStart(function(self)
	Lync.start()
	self.Libs.Net.Ready:fireServer()
end)

NetController:OnTick(function(self)
	Lync.flush()
end, 60, -1000)

return NetController
