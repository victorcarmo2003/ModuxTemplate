--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

Modux.Start({ DebugLevel = "Low", Profiling = false })
