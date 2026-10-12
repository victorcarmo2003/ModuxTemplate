--!strict
--[[
	Content.Trash: numbers and names of the table-trash dumpsters (owner request 2026-10-12; TrashController;
	PROVISIONAL, no DEC). The owner placed two dumpsters (Workspace.MAP01_Assets.Extra.P2, both Parts named P2, a
	SpecialMesh each, no separate lid) behind the trailer so the tray of a cleaned table is thrown away there.

	Flow (nothing new on the network): SeatingService:Clean (clean_table, server) still flips the table Dirty -> Free and
	pays the tip into the drawer. SeatingController sees that flip, hands the tray it was showing to
	TrashController:Toss, which flies it in an arc to the nearest bin's DropPoint, opens the lid (if the bin has one),
	drops the tray in, plays `trash` and closes. Presentation only: the client decides nothing.

	Data on the bin (written by tools/assetplace/trash_bins.luau from what the owner built):
	  tag `TrashBin` on the bin Part (or Model)
	  attribute BinId   "BIN-1", "BIN-2" ... (west to east)
	  Attachment DropPoint   world point just above the mouth (where the tray goes in)
	  Attachment ApproachPoint   on the ground in front of the bin (where a walker would stop; for NPC routes)
	  optional Lid (BasePart) + Attachment/Part LidHinge: tweened open on hinge X. Without a Lid the bin "bumps" instead.
]]

local Trash = {
	Tag = "TrashBin",
	BinIdAttribute = "BinId",
	DropAttachment = "DropPoint",
	ApproachAttachment = "ApproachPoint",
	LidName = "Lid",
	HingeName = "LidHinge",
	-- Workspace attribute written by `/dev trash [n]` ("<table>:<counter>"): the client tosses a tray from that table
	DevAttribute = "TrashDevToss",

	Sound = "trash",

	-- flight of the tray
	Arc = {
		Speed = 22, -- studs / s along the straight line
		MinSeconds = 0.55,
		MaxSeconds = 1.2,
		Height = 3.2, -- studs over the straight line at mid flight
		SpinTurns = 1.5, -- turns around Y during the flight
		Style = "Quad",
		Direction = "InOut",
	},

	Lid = {
		OpenDegrees = 105,
		OpenSeconds = 0.22,
		HoldSeconds = 0.35,
		CloseSeconds = 0.3,
	},

	-- tray sinks into the mouth and shrinks
	Drop = {
		Depth = 1.6,
		Seconds = 0.22,
		EndScale = 0.4,
	},

	-- bins with no Lid: Y scale of their SpecialMesh over Seconds, then back
	Bump = {
		Scale = 1.05,
		Seconds = 0.12,
	},
}

return table.freeze(Trash)
