--[[
	Quick preview of a Blender asset in Studio WITHOUT uploading (EditableMesh). Not saved reliably with the place.

		local Preview = require(<this module>)
		Preview.build(entry, CFrame.new(0, 0, 4000), { KP = "rbxassetid://...", FP = "rbxassetid://..." }, parent)

	entry = one item of a bridge JSON (toylib.entry): { label, parts = { { name, pos = {x,y,z,...}, uv = {u,v,...},
	tex, transparency?, material? } } }. Positions are already in Roblox axes, one vertex per triangle corner.
	The engine does NOT recentre EditableMesh vertices: the MeshPart CFrame is the asset pivot itself.
	Textures: upload PNGs first (Studio MCP upload_image from a local http server) and pass their ids by `tex` key.
]]

local AssetService = game:GetService("AssetService")

local Preview = {}

function Preview.build(entry: { [string]: any }, at: CFrame, textures: { [string]: string }, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = entry.label .. (entry.tris and (" (" .. entry.tris .. " tris)") or "")
	for _, p in entry.parts do
		local em = AssetService:CreateEditableMesh()
		for t = 0, #p.pos // 3 - 1, 3 do
			local vs, us = {}, {}
			for k = 0, 2 do
				local j = t + k
				vs[k + 1] = em:AddVertex(Vector3.new(p.pos[j * 3 + 1], p.pos[j * 3 + 2], p.pos[j * 3 + 3]))
				us[k + 1] = em:AddUV(Vector2.new(p.uv[j * 2 + 1], p.uv[j * 2 + 2]))
			end
			em:SetFaceUVs(em:AddTriangle(vs[1], vs[2], vs[3]), us)
		end
		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		mp.Name = p.name
		mp.Anchored = true
		mp.TextureID = textures[p.tex] or ""
		if p.transparency then
			mp.Transparency = p.transparency
		end
		if p.material == "Neon" then
			mp.Material = Enum.Material.Neon
		end
		mp.CFrame = at
		mp.Parent = model
		task.wait()
	end
	model.Parent = parent or workspace
	return model
end

return Preview
