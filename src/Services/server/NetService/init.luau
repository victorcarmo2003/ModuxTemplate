--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Lync = require(ReplicatedStorage.Packages.Lync)
local Modux = require(ServerScriptService.server.Modux)

const NetService = Modux.Service("NetService", { Priority = 1000 })

NetService:OnStart(function(self)
	Lync.start()
	game:BindToClose(Lync.close)
end)

NetService:OnTick(function(self)
	Lync.flush()
end, 60, -1000)

return NetService
