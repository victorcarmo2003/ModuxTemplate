--!strict
-- TASK-276: adds ReplicatedStorage.CrewExpressions.Angry (T_Expr_Angry, ANM-011 shake face). Run in Studio Edit mode
-- (command bar or MCP execute_luau), then save the place. Clones Stressed so every SurfaceAppearance property matches.
local folder = game:GetService("ReplicatedStorage"):WaitForChild("CrewExpressions")
local existing = folder:FindFirstChild("Angry")
if existing then
	existing:Destroy()
end
local angry = (folder:WaitForChild("Stressed") :: SurfaceAppearance):Clone()
angry.Name = "Angry"
angry.ColorMap = "rbxassetid://83147776191644"
angry.Parent = folder
return "CrewExpressions.Angry ok"
