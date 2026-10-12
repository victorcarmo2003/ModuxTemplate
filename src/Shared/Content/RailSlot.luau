--!strict
--[[
	Content.RailSlot: how a sausage rests on the RestRail (owner request 2026-10-12; PROVISIONAL, no DEC).
	The owner modelled invisible, anchored `Part`s on top of the rail rollers: `Rail_<N>/Part` (Part.CFrame is the
	surface pose, orientation included). Kitchen/shared/RailSlot resolves a slot to that pose.
]]

const RailSlot = {
	RailPrefix = "Rail_", -- child of the rail model: Rail_<N>
	PartName = "Part", -- surface Part inside each Rail_<N>
	-- a Rail_<N>/Part wider than this (studs, local X) is a tray shared by all slots (slots are projected on it);
	-- narrower = one Part per slot. Today: Rail_8 has one 2.6-wide Part for the 8 slots (pitch 0.343)
	PerSlotMaxWidth = 0.8,
	-- vertical offset from the TOP face of the Part to the sausage pivot (sausage pivot = base centre), studs
	VerticalOffset = 0,
	-- extra rotation (degrees, Y) on top of the Part orientation: the sausage model's long axis is its X, the Part's
	-- long run (roll direction) is its Z, so 90 puts the sausage across the slot line
	ExtraYawDegrees = 90,
}

return table.freeze(RailSlot)
