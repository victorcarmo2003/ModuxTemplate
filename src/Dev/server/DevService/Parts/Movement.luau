--!strict
-- Movement command (playtest 2026-10-12; Content.Movement). Debug of the NPC walking feel.
--   movement                  the numbers in use (Content.Movement)
--   movement debug on|off     draws the planned curve of every graph walk for 12 s (yellow = passed through, blue = stop)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Api = require(script.Parent.Parent.Api)
local Content = require(ReplicatedStorage.shared.Content)

const USAGE = "movement [debug on|off]"

type WalkerModule = { SetDebug: (on: boolean) -> () }

const Movement: Api.Module = function(_ctx: Api.Context): { Api.Command }
	return {
		{
			Name = "movement",
			Usage = USAGE,
			Help = "NPC walking feel: numbers in use, 'debug on|off' draws the rounded path of each walk",
			Run = function(args: { string }, _caller: Player?): string?
				const m = Content.Movement
				if args[1] == nil then
					return `corner r={m.Corner.Radius} min={m.Corner.MinAngle}deg | accept {m.Accept.Min}-{m.Accept.Max} | speed +-{m.Speed.Variation * 100}% start x{m.Speed.StartFactor}/{m.Speed.StartTime}s end x{m.Speed.EndFactor}/{m.Speed.BrakeDistance}studs | turn {m.Turn.Rate}deg/s | pedestrian smooth {m.Pedestrian.Smooth}`
				end
				if string.lower(args[1]) ~= "debug" or (args[2] ~= "on" and args[2] ~= "off") then
					error(`usage: {USAGE}`, 0)
				end
				const module = (ServerScriptService :: any).server.Npc.NpcService:FindFirstChild("Walker")
				if module == nil or not module:IsA("ModuleScript") then
					error("NpcService/Walker is not in this build", 0)
				end
				const walker = (require :: any)(module) :: WalkerModule
				walker.SetDebug(args[2] == "on")
				return `movement debug {args[2]}`
			end,
		},
	}
end

return Movement
