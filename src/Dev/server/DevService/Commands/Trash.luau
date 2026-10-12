--!strict
-- Trash command (owner request 2026-10-12; Content.Trash, TrashController). Fires the toss of a test tray from a table
-- to the nearest dumpster: sets Workspace.TrashDevToss "<table>:<counter>" (replicated, the client reacts).
--   trash          dumpsters found (tag TrashBin)
--   trash [n]      toss a tray from table n (default 1)
-- The real flow: `seating dirty n` then clean the table (prompt) during an open phase.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Api = require(script.Parent.Parent.Api)
local Content = require(ReplicatedStorage.shared.Content)

const USAGE = "trash [table]"

local counter = 0

const Trash: Api.Module = function(_ctx: Api.Context): { Api.Command }
	return {
		{
			Name = "trash",
			Usage = USAGE,
			Help = "table-trash dumpsters: list them, or toss a test tray from a table to the nearest one",
			Run = function(args: { string }, _caller: Player?): string?
				const params = Content.Trash
				const bins = CollectionService:GetTagged(params.Tag)
				if args[1] == nil then
					const lines = { `{#bins} bin(s) tagged {params.Tag}` }
					for _, bin in bins do
						table.insert(lines, `{bin:GetFullName()}: {bin:GetAttribute(params.BinIdAttribute) or "?"}`)
					end
					return table.concat(lines, "\n")
				end
				const index = tonumber(args[1])
				if index == nil then
					error(`usage: {USAGE}`, 0)
				end
				if #bins == 0 then
					error(`no instance tagged {params.Tag} (run tools/assetplace/trash_bins.luau)`, 0)
				end
				counter += 1
				workspace:SetAttribute(params.DevAttribute, `{math.floor(index)}:{counter}`)
				return `trash: tray from table {math.floor(index)} to the nearest of {#bins} bin(s)`
			end,
		},
	}
end

return Trash
