--!strict
-- Front security camera CAM3 (owner request 2026-10-21, Provisional Q-437): a copy of CAM1 under the awning at the front
-- west post, above the tip jar (TRL-TIPJAR), looking down the counter front and the customer queue (Q1..Q5).
-- Its pivot (WorldPivot) is the view (Content.Security contract); the parts are posed around it.
--
-- Owner hand edit 2026-10-21 (Studio): the mount was moved under the awning and the CCTV monitor to the front
-- (SecurityCams.CCTV pivot (-25.725, 4.45, 8.977), facing -X). The values below are that saved pose: the parts go to
-- MOUNT, the view (WorldPivot) sits 0.4 stud in front of the lens. Idempotent: an existing CAM3 is replaced.
-- Run in Studio (Edit) through the MCP execute_luau, then save the place (Ctrl+S).
local folder = workspace:FindFirstChild("SecurityCams")
assert(folder, "no Workspace.SecurityCams")
local source = folder:FindFirstChild("CAM1")
assert(source and source:IsA("Model"), "no SecurityCams.CAM1 to copy")

local LOOK = Vector3.new(-0.965, -0.211, 0.155) -- down the counter front and the queue
local MOUNT = CFrame.lookAt(Vector3.new(-25.6, 7.3, 14.9), Vector3.new(-25.6, 7.3, 14.9) + LOOK) -- pose the copy first
local OFFSET = Vector3.new(-1.21, 0.46, 0.18) -- the owner's move of the parts (bbox -26.81, 7.76, 14.70)
local EYE = Vector3.new(-27.69, 7.86, 15.14) -- 0.4 stud in front of the lens

local old = folder:FindFirstChild("CAM3")
if old then
	old:Destroy()
end
local cam = source:Clone()
cam.Name = "CAM3"
cam:PivotTo(MOUNT)
cam:PivotTo(cam:GetPivot() + OFFSET)
cam.WorldPivot = CFrame.lookAt(EYE, EYE + LOOK)
cam.Parent = folder
return `CAM3 view at {EYE}`
