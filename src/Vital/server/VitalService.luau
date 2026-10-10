--!strict
-- Shell of VitalService between waves 1 and 2 (TASK-048, architecture.md §19.26 A9). The template example
-- (Health/Armor/Stamina, component Vital, Kill/respawn) is gone with its Net entry; TASK-062 rewrites this feature as
-- VitalService/ (init, Sanity, Life) per architecture.md §19.7. Priority stays 700 (§19.2).
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const VitalService = Modux.Service("VitalService", { Priority = 700 })

return VitalService
