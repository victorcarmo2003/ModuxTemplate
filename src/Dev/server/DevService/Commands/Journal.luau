--!strict
-- /dev journal (TASK-335, TASK-345): Anomaly Tablet pages of the caller (or the first player from the Command Bar).
--   journal            list the unlocked pages
--   journal <ref|key>  unlock one page (ANM-007 or anm_007_walker): toast + glow on the client
--   journal all        unlock every page
--   journal reset      forget every page (the tablet starts empty)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

local function keyOf(text: string): string?
	if Content.Journal.ByKey[text] ~= nil then
		return text
	end
	const upper = string.upper(text)
	for _, row in Content.Journal.List do
		const anomaly = Content.Anomalies.ByKey[row.Key]
		if anomaly ~= nil and anomaly.Ref == upper then
			return row.Key
		end
	end
	return nil
end

const module: Api.Module = function(ctx: Api.Context): { Api.Command }
	return {
		{
			Name = "journal",
			Usage = "journal [all | reset | <ANM-###>]",
			Help = "Anomaly Tablet pages of the caller: list, unlock one or all, reset",
			Run = function(args: { string }, caller: Player?): string?
				const player = caller or Players:GetPlayers()[1]
				if player == nil then
					error("no player")
				end
				const journal = ctx.Get("JournalService")
				const arg = args[1]
				if arg == nil then
					const pages = journal:Pages(player)
					if pages == nil then
						error("profile not loaded")
					end
					const list: { string } = {}
					for _, row in Content.Journal.List do
						if pages[row.Key] then
							table.insert(list, Content.Anomalies.ByKey[row.Key].Ref)
						end
					end
					return `{#list}/{#Content.Journal.List} pages: {table.concat(list, " ")}`
				elseif arg == "reset" then
					journal:Reset(player)
					return "journal cleared"
				elseif arg == "all" then
					local count = 0
					for _, row in Content.Journal.List do
						if journal:Unlock(player, row.Key) then
							count += 1
						end
					end
					return `{count} new pages`
				end
				const key = keyOf(arg)
				if key == nil then
					error(`no page for "{arg}"`)
				end
				return if journal:Unlock(player, key) then `unlocked {key}` else `{key} was already on the tablet`
			end,
		},
	}
end

return module
