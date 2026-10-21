--!strict
-- Trailer capture camera (TASK-C1, docs/marketing/trailer-blackout-60s.md §7; owner request 2026-10-20, Provisional).
-- The tracks (keyframes) live in src/Dev/shared/CameraTracks.luau. A track plays on the caller's own client:
-- DevCameraController watches the caller's Player attributes DevCameraTrack = key and DevCameraTrackAt = server time
-- of the start (Player attributes replicate to its client), drives the camera and hides the UI when the track asks.
-- `here` reads the caller's camera from the attributes DevCameraPos / DevCameraLook that DevService writes from the
-- DevCameraHere packet (2 Hz while dev mode is on).
--   track              what plays on the caller (key, elapsed s), else the list
--   track list         key - name (duration s, n keys)
--   track <key>        starts that track on the caller's camera (key, or a unique part of it)
--   track stop         stops it: camera and UI back
--   track here         the caller's camera as a Key line, ready to paste in CameraTracks.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraTracks = require(ReplicatedStorage.shared.Dev.CameraTracks)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const USAGE = "track [list | stop | here | <key>]"
const TRACK_ATTRIBUTE = "DevCameraTrack" -- read by DevCameraController
const AT_ATTRIBUTE = "DevCameraTrackAt"
const POS_ATTRIBUTE = "DevCameraPos" -- written by DevService from the DevCameraHere packet
const LOOK_ATTRIBUTE = "DevCameraLook"
const CLEAR_GRACE = 0.5 -- s after Duration before the attributes are cleared on their own

type Track = CameraTracks.Track

local function list(): string
	const lines: { string } = { "tracks:" }
	for _, track in CameraTracks do
		table.insert(lines, `  {track.Key} - {track.Name} ({track.Duration} s, {#track.Keys} keys)`)
	end
	if #lines == 1 then
		table.insert(lines, "  (none in src/Dev/shared/CameraTracks.luau)")
	end
	return table.concat(lines, "\n")
end

-- Exact key (case-insensitive), else a unique part of it
local function find(word: string): Track
	const needle = string.lower(word)
	const found: { Track } = {}
	for _, track in CameraTracks do
		const key = string.lower(track.Key)
		if key == needle then
			return track
		end
		if string.find(key, needle, 1, true) then
			table.insert(found, track)
		end
	end
	if #found == 1 then
		return found[1]
	end
	if #found > 1 then
		const keys = {}
		for _, track in found do
			table.insert(keys, track.Key)
		end
		error(`"{word}" matches {table.concat(keys, ", ")}`, 0)
	end
	error(`unknown track "{word}" ("track list")`, 0)
end

local function vector(value: Vector3): string
	return string.format("Vector3.new(%.1f, %.1f, %.1f)", value.X, value.Y, value.Z)
end

local function status(player: Player): string
	const key = player:GetAttribute(TRACK_ATTRIBUTE)
	const at = player:GetAttribute(AT_ATTRIBUTE)
	if type(key) ~= "string" then
		return `nothing plays on {player.Name}\n{list()}`
	end
	const elapsed = if type(at) == "number" then workspace:GetServerTimeNow() - at else 0
	return `{key} plays on {player.Name}, {string.format("%.1f", elapsed)} s in`
end

local function stop(player: Player): string
	const key = player:GetAttribute(TRACK_ATTRIBUTE)
	player:SetAttribute(TRACK_ATTRIBUTE, nil)
	player:SetAttribute(AT_ATTRIBUTE, nil)
	return if type(key) == "string" then `{key} stopped on {player.Name}` else `nothing was playing on {player.Name}`
end

local function start(player: Player, track: Track): string
	const at = workspace:GetServerTimeNow()
	-- At first: the client reads it when the key arrives
	player:SetAttribute(AT_ATTRIBUTE, at)
	player:SetAttribute(TRACK_ATTRIBUTE, track.Key)
	-- the client lets go on its own after Duration; the attributes follow so `track` reads right afterwards
	task.delay(track.Duration + CLEAR_GRACE, function()
		if player.Parent == Players and player:GetAttribute(AT_ATTRIBUTE) == at then
			player:SetAttribute(TRACK_ATTRIBUTE, nil)
			player:SetAttribute(AT_ATTRIBUTE, nil)
		end
	end)
	return `{track.Key} ({track.Name}) plays on {player.Name} for {track.Duration} s{if track.HideUi then ", UI hidden" else ""}`
end

local function here(player: Player): string
	const pos = player:GetAttribute(POS_ATTRIBUTE)
	const look = player:GetAttribute(LOOK_ATTRIBUTE)
	if typeof(pos) ~= "Vector3" or typeof(look) ~= "Vector3" then
		error(`no camera reading from {player.Name} yet (its DevCameraController sends one every 0.5 s in dev mode)`, 0)
	end
	return `\{ T = 0, Pos = {vector(pos)}, Look = {vector(look)} },`
end

const Track: Api.Module = function(_ctx: Api.Context): { Api.Command }
	return {
		{
			Name = "track",
			Usage = USAGE,
			Help = "trailer capture camera: plays a keyframed track on your camera; here = your camera as a Key line",
			Run = function(args: { string }, caller: Player?): string?
				const player = Kit.target(nil, caller)
				const sub = if args[1] ~= nil then string.lower(args[1]) else nil
				if sub == nil then
					return status(player)
				elseif sub == "list" then
					return list()
				elseif sub == "stop" then
					return stop(player)
				elseif sub == "here" then
					return here(player)
				end
				return start(player, find(table.concat(args, " ")))
			end,
		},
	}
end

return Track
