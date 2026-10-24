--!strict
-- ANM-011 tantrum (owner 2026-10-22): adds ReplicatedStorage.CrewExpressions.Rage (T_Expr_Rage, tools/assetplace/gen_rage_face.py)
-- Run in Studio Edit mode (command bar or MCP execute_luau), then save the place. Clones Stressed so every
-- SurfaceAppearance property matches.
local folder = game:GetService("ReplicatedStorage"):WaitForChild("CrewExpressions")
local existing = folder:FindFirstChild("Rage")
if existing then
	existing:Destroy()
end
local rage = (folder:WaitForChild("Stressed") :: SurfaceAppearance):Clone()
rage.Name = "Rage"
rage.ColorMap = "rbxassetid://81500320462180"
rage:SetAttribute("Texture", "T_Expr_Rage")
rage.Parent = folder
return "CrewExpressions.Rage ok"
