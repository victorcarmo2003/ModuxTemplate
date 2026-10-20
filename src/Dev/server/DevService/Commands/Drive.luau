--!strict
-- Restaurant drive-thru (board TASK-574; tech/restaurant-flow.md §3.4). Thin wrappers over DriveThruService (Dev* check
-- IsDev and Content.Restaurant.Drive.Enabled).
--   drive [state]   the lane spots: car, state, time left in the move, customer state and patience; night vs UnlockNight
--   drive car       the next spawn attempt is a car (any night, no share draw, every lane spot) and it is made now
--   drive take      takes the order of the car at the window at DT-PC as you (TabletService talk, then its end)
--   drive serve [exact]   hands the plate out at the window as you, without the range check (the order must be taken);
--                   exact = first puts a hot dog with the exact order in your hand
-- From the Command Bar (no caller) take / serve act as the first player in the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "drive [state | car | take | serve [exact]]"

type Drive = {
	DevState: (self: any) -> string,
	DevCar: (self: any) -> string,
	DevServe: (self: any, player: Player, exact: boolean?) -> string,
}

type Tablets = {
	DevTalk: (self: any, player: Player, index: number?) -> string,
	DevFinish: (self: any, index: number?) -> string,
}

local function player(caller: Player?): Player
	const who = caller or Players:GetPlayers()[1]
	if who == nil then
		error("no player in the server", 0)
	end
	return who
end

const Drive: Api.Module = function(ctx: Api.Context): { Api.Command }
	const drive = ctx.Get("DriveThruService") :: Drive
	const tablets = ctx.Get("TabletService") :: Tablets
	const pc = Content.Restaurant.Rules.DrivePcIndex

	return {
		{
			Name = "drive",
			Usage = USAGE,
			Help = "Restaurant drive-thru: lane state, force a car now, take the order at DT-PC, hand the plate out",
			Run = function(args: { string }, caller: Player?): string?
				const verb = args[1]
				if verb == nil or verb == "state" then
					return drive:DevState()
				elseif verb == "car" then
					return drive:DevCar()
				elseif verb == "take" then
					const talk = tablets:DevTalk(player(caller), pc)
					return `{talk}; {tablets:DevFinish(pc)}`
				elseif verb == "serve" then
					return drive:DevServe(player(caller), args[2] == "exact")
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Drive
