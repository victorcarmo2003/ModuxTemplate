--!strict
-- Interior lights of MAP01_Restaurant for the Realistic lighting (owner 2026-10-19: switched Lighting to Realistic; "precisamos
-- melhorar algumas coisas na parte interna, na externa tá bom"; and the blackout's emergency light needs more range).
-- Idempotent: sets each listed Light to the values below (run in Studio, Edit mode, command bar or MCP), prints what changed.
-- Place data (MAP01_Restaurant is not rebuilt by Place.run); save the place (Ctrl+S) after running. Provisional, judged in Play.
local root = workspace:FindFirstChild("MAP01_Restaurant")
assert(root, "MAP01_Restaurant missing")

type Look = { Range: number, Brightness: number, Shadows: boolean? }

-- path under MAP01_Restaurant -> look (the Light child of that path)
const LOOKS: { { Path: { string }, Look: Look } } = {
	-- kitchen ceiling panels (switch group): were Range 11.05, Brightness 0.27
	{ Path = { "Trailer", "Kitchen", "Light_K1" }, Look = { Range = 16, Brightness = 1.1, Shadows = false } },
	{ Path = { "Trailer", "Kitchen", "Light_K3" }, Look = { Range = 16, Brightness = 1.1, Shadows = false } },
	-- pantry: were Range 9, Brightness 0.21
	{ Path = { "Trailer", "Pantry", "Light_P" }, Look = { Range = 13, Brightness = 0.8, Shadows = false } },
	{ Path = { "Trailer", "Pantry", "Light_P2" }, Look = { Range = 13, Brightness = 0.8, Shadows = false } },
	-- drive-thru window: was Range 8, Brightness 0.5
	{ Path = { "DriveThru", "LIT-DT" }, Look = { Range = 12, Brightness = 0.9 } },
	-- emergency light (stays on in the blackout, Content.LightPresets.Blackout KeepNames): was Range 8.1, Brightness 0.245
	{ Path = { "Emergency", "Lens" }, Look = { Range = 20, Brightness = 0.55 } },
	-- light under the emergency door: was Range 5, Brightness 0.6
	{ Path = { "Emergency", "DoorGap_B" }, Look = { Range = 9, Brightness = 0.8 } },
}

for _, row in LOOKS do
	local node: Instance? = root
	for _, name in row.Path do
		node = if node then node:FindFirstChild(name) else nil
	end
	const light = if node then node:FindFirstChildWhichIsA("Light") else nil
	if light == nil then
		warn(`[interior_lights] no Light under {table.concat(row.Path, ".")}`)
		continue
	end
	const before = `r={light.Range} b={light.Brightness}`
	light.Range = row.Look.Range
	light.Brightness = row.Look.Brightness
	if row.Look.Shadows ~= nil then
		light.Shadows = row.Look.Shadows
	end
	print(`[interior_lights] {table.concat(row.Path, ".")}: {before} -> r={light.Range} b={light.Brightness}`)
end
