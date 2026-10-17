--!strict
-- TeleportService calls of the squad flow (architecture.md §20.2, §20.3). Pure wrappers: every call is pcall'd and
-- answers (ok, error) instead of throwing; the retry policy belongs to the callers (PartyService, PartyRunService).
-- Always the same place: one place, server roles (the role rides TeleportData, never a second PlaceId).
local TeleportService = game:GetService("TeleportService")

local Teleport = {}

-- New reserved server of this place. Returns the access code (server-only secret) and the PrivateServerId the server
-- will have (the RunId of SessionService, TASK-360), or nil, nil + error.
function Teleport.Reserve(): (string?, string?, string?)
	local serverId = ""
	const ok, result = pcall(function(): string
		const code, id = TeleportService:ReserveServer(game.PlaceId)
		serverId = id
		return code
	end)
	if not ok then
		return nil, nil, tostring(result)
	end
	return result, serverId, nil
end

-- Options for a reserved server (code) carrying data, or for the public servers of the place (code nil).
function Teleport.Options(code: string?, data: { [string]: any }?): TeleportOptions
	const options = Instance.new("TeleportOptions")
	if code ~= nil then
		options.ReservedServerAccessCode = code
	end
	if data ~= nil then
		options:SetTeleportData(data)
	end
	return options
end

-- Teleports the players together. True = the request was accepted (a player can still fail later, through
-- TeleportService.TeleportInitFailed).
function Teleport.Send(players: { Player }, options: TeleportOptions): (boolean, string?)
	if #players == 0 then
		return false, "no player to teleport"
	end
	const ok, problem = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players, options)
	end)
	if not ok then
		return false, tostring(problem)
	end
	return true, nil
end

return table.freeze(Teleport)
