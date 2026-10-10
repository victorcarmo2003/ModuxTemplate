--!strict
-- Shell of VitalController between waves 1 and 2 (TASK-048, architecture.md §19.26 A9). The template example
-- (Health/Armor/Stamina sources) is gone with its Net entry; TASK-063 rewrites it (sources Sanity, Max, Band,
-- State[uid]; architecture.md §19.7 Client). Priority stays 800 (§19.2).
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const VitalController = Modux.Controller("VitalController", { Priority = 800 })

return VitalController
