--!strict
-- Anomaly tics in the order talk (design/anomaly-tics-proposal.md §4.1, Content.Tics): pilot ANM-012, and since
-- 2026-10-22 ANM-013 (white eyes), ANM-004 (the copy's echo: talk to the original first, then the copy) and ANM-014 (big
-- head), and ANM-001 (the face that fades). Spawn one with `trigger ANM-0xx`, wait for it at Q1, then Take Order (or
-- `tablet talk`).
--   tic [state] [n]        TAB-n (default 1): talk state, when the talk ends (the order is taken then, owner 2026-10-22:
--                          no ACCEPT / REFUSE), the head rig's tic row (Body, its timing: Freeze / Peak / last beat / End,
--                          from LineStart = StartedAt + OrderTalk.Speech.Start) and attributes (Variant, TicAt, Tic,
--                          TicUser, TicFollow, TicEnd, TicEcho)
--   tic reset [n]          takes the tic attributes off the head customer's rig: the next talk plays the full tic again
-- Owner 2026-10-22: the taker's tension (bars, heart, "paradinha", the apex's whispers and title) runs on the taker's
-- client from the freeze; the times here are the tic's (Content.Tics Layers: At = s from the peak)
-- (`tic early`, the pick sent before the choice gate, went with the choice)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "tic [state [n] | reset [n]]"
const ATTRIBUTES = { "TicAt", "TicUser", "Tic", "TicFollow", "TicEnd", "TicEcho" }

type Tablet = { Index: number, State: string, Npc: number, User: Player?, StartedAt: number, EndsAt: number }

type Tablets = {
	DevTablet: (self: any, index: number?) -> Tablet,
	Head: (self: any, tablet: Tablet) -> number?,
}

local function index(text: string?): number?
	if text == nil then
		return nil
	end
	const value = tonumber(text)
	if value == nil or value ~= math.floor(value) or value < 1 then
		error(`usage: {USAGE}`, 0)
	end
	return value
end

local function rigOf(npc: number): Model?
	for _, instance in CollectionService:GetTagged(CrewRig.Tag) do
		if instance:IsA("Model") and instance:GetAttribute("NpcId") == npc then
			return instance
		end
	end
	return nil
end

local function describe(rig: Model?): string
	if rig == nil then
		return "no rig"
	end
	const variant = rig:GetAttribute("Variant")
	const parts: { string } = { `Variant {tostring(variant or "-")}` }
	const row = if type(variant) == "string" then Content.Tics.ByVariant[variant] else nil
	if row ~= nil then
		-- the clock of this talk's line (the echo: from TicEcho and the taker's name, as the server and clients read it)
		const echo = rig:GetAttribute("TicEcho")
		const user = rig:GetAttribute("TicUser")
		const taker = if type(user) == "number" then Players:GetPlayerByUserId(user) else nil
		const said = Content.Tics.Said(row, if type(echo) == "number" then echo else nil, if taker ~= nil then taker.DisplayName else "")
		const t = Content.Tics.Timing(row, said)
		table.insert(
			parts,
			string.format(
				"tic %s %s (freeze on \"...\" %.2f, hold %.2f, peak = apex %.2f, last beat %.2f, end %.2f) \"%s\"",
				row.Body,
				row.Kind,
				t.Freeze,
				row.Hold,
				t.Peak,
				t.BeatsEnd,
				t.End,
				said.Text
			)
		)
	else
		table.insert(parts, "no tic row")
	end
	const now = Workspace:GetServerTimeNow()
	for _, name in ATTRIBUTES do
		const value = rig:GetAttribute(name)
		if (name == "TicAt" or name == "TicEnd") and type(value) == "number" then
			table.insert(parts, string.format("%s %.2f s ago", name, now - value))
		else
			table.insert(parts, `{name} {tostring(value or "-")}`)
		end
	end
	return table.concat(parts, ", ")
end

const Tic: Api.Module = function(ctx: Api.Context): { Api.Command }
	const tablets = ctx.Get("TabletService") :: Tablets

	local function state(tablet: Tablet): string
		const now = Workspace:GetServerTimeNow()
		const npc = if tablet.Npc ~= 0 then tablet.Npc else tablets:Head(tablet)
		const talking = tablet.State == "Talking"
		return string.format(
			"TAB-%d %s npc %s, line from %s, order taken %s | head rig: %s",
			tablet.Index,
			tablet.State,
			tostring(npc or "-"),
			if talking
				then string.format("%.2f s ago", now - (tablet.StartedAt + Content.OrderTalk.Speech.Start))
				else "-",
			if talking then string.format("in %.2f s", tablet.EndsAt - now) else "-",
			if npc ~= nil then describe(rigOf(npc)) else "-"
		)
	end

	return {
		{
			Name = "tic",
			Usage = USAGE,
			Help = "Anomaly tics in the order talk (ANM-012/013/004/014/001): state + timing, reset the residue",
			Run = function(args: { string }, _caller: Player?): string?
				const verb = args[1]
				if verb == nil or verb == "state" or tonumber(verb) ~= nil then
					return state(tablets:DevTablet(index(if verb == "state" then args[2] else verb)))
				elseif verb == "reset" then
					const tablet = tablets:DevTablet(index(args[2]))
					const npc = tablets:Head(tablet)
					const rig = if npc ~= nil then rigOf(npc) else nil
					if rig == nil then
						return "no customer rig at the head of the queue"
					end
					for _, name in ATTRIBUTES do
						rig:SetAttribute(name, nil)
					end
					return `tic attributes cleared on {npc}: the next talk plays the full tic`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Tic
