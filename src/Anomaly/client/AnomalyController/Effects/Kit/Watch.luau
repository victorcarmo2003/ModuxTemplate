--!strict
--[[
	Security cameras seen from the anomalies (TASK-337, owner 2026-10-15: "looking through the camera must never kill").
	Presentation only: reads the LocalPlayer attributes of TASK-285 (`SecurityView` "" | "Normal" | "Night",
	`SecurityCam` Cam key) and can drop the camera view.

	  Watching()   true while the local player looks through a security camera (the body stands at the monitor).
	  Changed(fn)  fn(watching) on every enter / leave of the camera view (TASK-472).
	  Interrupt()  a warning that must be felt in the world (family B hide warning, the Hush, the blackout, the bell)
	               cuts the camera view back to the head, so the warning is never missed behind the feed.
	The jumpscare of a family A customer (Kit/Jumpscare, "near" the actor) is not shown to a watcher: the face belongs
	to who stands at the counter, not to who watches it on a screen.
]]
local Players = game:GetService("Players")

const Watch = {}

function Watch.Watching(): boolean
	const view = Players.LocalPlayer:GetAttribute("SecurityView")
	return type(view) == "string" and view ~= ""
end

-- Calls `callback(watching)` each time the local player enters or leaves the camera view (TASK-472: actors seen only
-- on the cameras). Disconnect the returned connection when done.
function Watch.Changed(callback: (watching: boolean) -> ()): RBXScriptConnection
	return Players.LocalPlayer:GetAttributeChangedSignal("SecurityView"):Connect(function()
		callback(Watch.Watching())
	end)
end

function Watch.Cam(): string?
	if not Watch.Watching() then
		return nil
	end
	const cam = Players.LocalPlayer:GetAttribute("SecurityCam")
	return if type(cam) == "string" and cam ~= "" then cam else nil
end

-- Drops the camera view through SecurityController:Leave (best effort: nothing when the feature is missing).
function Watch.Interrupt()
	if not Watch.Watching() then
		return
	end
	const client = script:FindFirstAncestor("client")
	const feature = if client then client:FindFirstChild("Security") else nil
	const module = if feature then feature:FindFirstChild("SecurityController") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return
	end
	pcall(function()
		const security: any = (require :: any)(module)
		const leave: any = if type(security) == "table" then security.Leave else nil
		if type(leave) == "function" then
			(leave :: any)(security)
		end
	end)
end

return table.freeze(Watch)
