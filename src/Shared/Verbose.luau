--!strict
-- Verbose: one switch for the routine dev logs (owner request 2026-10-16: the Output had too many lines). Off by default;
-- set the Workspace attribute `VerboseLogs` = true (Studio, Properties of Workspace) to see them again. Problems that
-- break the game stay as warn/error and never pass through here.
local Verbose = {}

Verbose.Attribute = "VerboseLogs"

function Verbose.On(): boolean
	return workspace:GetAttribute(Verbose.Attribute) == true
end

-- print only with the switch on
function Verbose.print(...: any)
	if Verbose.On() then
		print(...)
	end
end

return table.freeze(Verbose)
