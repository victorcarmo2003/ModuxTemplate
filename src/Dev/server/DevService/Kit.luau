--!strict
-- Shared helpers of the dev commands (owner request 2026-10-18; docs/tech/dev-commands.md). Pure Luau over the Api
-- contract: subcommand groups that forward to the older single commands kept in Parts/, the anomaly resolver (key,
-- ANM-###, number or part of the name: "blackout", "knock", "red fog"), the player resolver and the jump into the
-- Night phase used by trigger / scene / time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Api)

export type Sub = (args: { string }, caller: Player?) -> string?

type Round = {
	GetPhase: (self: any) -> string,
	GetDay: (self: any) -> number,
	GetNight: (self: any) -> number,
	IsNight: (self: any) -> boolean,
	DevSetNight: (self: any, night: number) -> (),
	DevSkipPhase: (self: any) -> (),
}

const NIGHT_PHASE = "Night"
const NIGHT_SHIFT_PHASES = { Call = true, Prep = true, Night = true }
const MAX_SKIPS = 6
const SKIP_WAIT = 0.3

const Kit = {}

-- Commands of a Parts/ module by name. A part that fails to load leaves its subcommands out (warned), the verb stays.
function Kit.parts(ctx: Api.Context, name: string): { [string]: Api.Command }
	const out: { [string]: Api.Command } = {}
	const folder = (script.Parent :: Instance):FindFirstChild("Parts")
	const module = if folder then folder:FindFirstChild(name) else nil
	if module == nil or not module:IsA("ModuleScript") then
		warn(`[Dev] Parts/{name} is missing`)
		return out
	end
	const ok, result = pcall(function(): { Api.Command }
		return ((require :: any)(module) :: Api.Module)(ctx)
	end)
	if not ok then
		warn(`[Dev] Parts/{name} failed to load: {result}`)
		return out
	end
	for _, command in result do
		out[command.Name] = command
	end
	return out
end

-- A Sub that runs `command` with `prefix` words before the args ("customer on" -> arrivals {"on"})
function Kit.forward(command: Api.Command?, prefix: { string }?): Sub
	return function(args: { string }, caller: Player?): string?
		const target = command
		if target == nil then
			error("this subcommand did not load (see the warnings at boot)", 0)
		end
		const full = table.clone(prefix or {})
		table.move(args, 1, #args, #full + 1, full)
		return target.Run(full, caller)
	end
end

-- A hidden command (old name) with the Run of `command`
function Kit.alias(name: string, command: Api.Command?, prefix: { string }?): Api.Command
	return {
		Name = name,
		Usage = if command then command.Usage else name,
		Help = if command then `(old name) {command.Help}` else "(old name)",
		Hidden = true,
		Run = Kit.forward(command, prefix),
	}
end

-- One verb: the first word picks a Sub; otherwise `default` gets every arg (nil = usage error)
function Kit.group(name: string, usage: string, help: string, subs: { [string]: Sub }, default: Sub?): Api.Command
	return {
		Name = name,
		Usage = usage,
		Help = help,
		Run = function(args: { string }, caller: Player?): string?
			const first = args[1]
			const sub = if first ~= nil then subs[string.lower(first)] else nil
			if sub ~= nil then
				return sub({ table.unpack(args, 2) }, caller)
			end
			if default ~= nil then
				return default(args, caller)
			end
			error(`usage: {usage}`, 0)
		end,
	}
end

-- Players -----------------------------------------------------------------------------------------------------------

-- By Name/DisplayName (exact, then unique prefix, case-insensitive)
function Kit.findPlayer(query: string): Player
	const needle = string.lower(query)
	const matches = {}
	for _, player in Players:GetPlayers() do
		const name = string.lower(player.Name)
		const display = string.lower(player.DisplayName)
		if name == needle or display == needle then
			return player
		end
		if string.sub(name, 1, #needle) == needle or string.sub(display, 1, #needle) == needle then
			table.insert(matches, player)
		end
	end
	if #matches == 1 then
		return matches[1]
	end
	error(if #matches == 0 then `no player matches "{query}"` else `"{query}" matches {#matches} players`, 0)
end

-- The named player; without a name the caller; from the Command Bar the only player
function Kit.target(query: string?, caller: Player?): Player
	if query ~= nil then
		return Kit.findPlayer(query)
	end
	if caller ~= nil then
		return caller
	end
	const players = Players:GetPlayers()
	if #players == 1 then
		return players[1]
	end
	error(`{#players} players in the server: name one`, 0)
end

-- Anomalies ---------------------------------------------------------------------------------------------------------

-- "anm_020_blackout" / "The blackout" -> "blackout"
local function shortName(row: { Key: string, Name: string }): string
	const fromKey = string.gsub(string.match(row.Key, "^anm_%d+_(.+)$") or row.Key, "_", " ")
	return fromKey
end

local function plain(text: string): string
	const lower = string.gsub(string.gsub(string.lower(text), "_", " "), "^the ", "")
	return lower
end

-- Content.Anomalies key from a key, ANM-###, a number (the ANM number) or a unique part of the name. Errors otherwise.
function Kit.anomaly(word: string): string
	if Content.Anomalies.ByKey[word] ~= nil then
		return word
	end
	const upper = string.upper(word)
	const number = tonumber(word)
	const ref = if number then string.format("ANM-%03d", number) else upper
	for _, row in Content.Anomalies.List do
		if row.Ref == ref then
			return row.Key
		end
	end
	const needle = plain(word)
	const found: { string } = {}
	for _, row in Content.Anomalies.List do
		const short = shortName(row)
		const name = plain(row.Name)
		if short == needle or name == needle then
			return row.Key
		end
		if string.find(short, needle, 1, true) or string.find(name, needle, 1, true) then
			table.insert(found, row.Key)
		end
	end
	if #found == 1 then
		return found[1]
	end
	if #found > 1 then
		error(`"{word}" matches {table.concat(found, ", ")}`, 0)
	end
	error(`unknown anomaly "{word}" (key, ANM-###, number or name; "trigger list")`, 0)
end


-- Shifts ------------------------------------------------------------------------------------------------------------

-- Puts the run in the Night phase: of `night` when given (restarts it), else the night shift we are in (skipping Call
-- / Prep), else the evening of the current day (Night k is on Day k + 1). Returns "" when already there, otherwise
-- where it went. Yields while skipping.
function Kit.toNight(round: Round, night: number?): string
	const phase = round:GetPhase()
	if night == nil and phase == NIGHT_PHASE then
		return ""
	end
	if night ~= nil or not round:IsNight() or not NIGHT_SHIFT_PHASES[phase] then
		const wanted = night
			or if round:IsNight() then round:GetNight() else math.clamp(round:GetDay() - 1, 1, Content.RunParams.Nights)
		round:DevSetNight(wanted)
	end
	for _ = 1, MAX_SKIPS do
		if round:GetPhase() == NIGHT_PHASE then
			break
		end
		pcall(function()
			round:DevSkipPhase()
		end)
		task.wait(SKIP_WAIT)
	end
	if round:GetPhase() ~= NIGHT_PHASE then
		error(`could not reach the Night phase (stuck in {round:GetPhase()})`, 0)
	end
	return `Night {round:GetNight()}`
end

return Kit
