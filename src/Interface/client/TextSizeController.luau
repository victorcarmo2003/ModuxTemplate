--!strict
--[[
	TextSizeController (owner request 2026-10-20, Provisional)

	Caps every text of the game UI at its own TextSize. The player's Text Size setting (GuiService.PreferredTextSize, on
	by default) adds px after the UIScale: on a phone, where the UI scale is 0.6 (Theme.Scale.MinPhone), the text
	outgrew its boxes, covered the bars and overflowed the rows. The UI scale already sizes the text for the screen.
	A UITextSizeConstraint (MaxTextSize = TextSize) is added to every TextLabel / TextButton / TextBox in PlayerGui and
	in the Workspace that is not TextScaled and has no constraint of its own (CartoonLabel adds its own); it follows
	TextSize changes.

	Text in a BillboardGui sized in studs (Scale): a fixed TextSize keeps its pixels while the sign shrinks with
	distance, so far away the text outgrew the sign (owner 2026-10-20). A fixed-box label there becomes TextScaled,
	capped at its TextSize: the design size up close, shrinking with the sign. Labels with AutomaticSize keep TextSize
	(TextScaled has no box to fit).
]]
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const CAP_NAME = "TextSizeCap"

const TextSizeController = Modux.Controller("TextSizeController", {
	Priority = 400,
})

-- The BillboardGui sized in studs this object sits in, nil = none. A billboard that scales a px layout with a UIScale
-- (PlateCard: fit = billboard px / design px) already shrinks its text: left alone.
local function studsBillboard(object: Instance): BillboardGui?
	const billboard = object:FindFirstAncestorOfClass("BillboardGui")
	if billboard == nil or (billboard.Size.X.Scale <= 0 and billboard.Size.Y.Scale <= 0) then
		return nil
	end
	local parent = object.Parent
	while parent ~= nil and parent ~= billboard do
		if parent:FindFirstChildOfClass("UIScale") then
			return nil
		end
		parent = parent.Parent
	end
	return if billboard:FindFirstChildOfClass("UIScale") then nil else billboard
end

local function cap(object: Instance)
	if not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
		return
	end
	-- the three classes share TextScaled / TextSize; typed through one of them
	const text = (object :: any) :: TextLabel
	local constraint = text:FindFirstChildOfClass("UITextSizeConstraint")
	if not text.TextScaled and text.AutomaticSize == Enum.AutomaticSize.None and studsBillboard(text) ~= nil then
		-- the cap (its own, or CartoonLabel's at its TextSize) keeps the design size up close
		if constraint == nil then
			const made = Instance.new("UITextSizeConstraint")
			made.Name = CAP_NAME
			made.MaxTextSize = math.max(math.floor(text.TextSize), 1)
			made.Parent = text
		end
		text.TextScaled = true
		return
	end
	if text.TextScaled or constraint ~= nil then
		return
	end
	const made = Instance.new("UITextSizeConstraint")
	made.Name = CAP_NAME
	made.MaxTextSize = math.max(math.floor(text.TextSize), 1)
	made.Parent = text
	text:GetPropertyChangedSignal("TextSize"):Connect(function()
		made.MaxTextSize = math.max(math.floor(text.TextSize), 1)
	end)
end

function TextSizeController:Watch(root: Instance)
	root.DescendantAdded:Connect(function(object)
		-- a component sets TextScaled / adds its constraint right after creating the label: look once it is built
		if object:IsA("GuiObject") then
			task.defer(cap, object)
		end
	end)
	for _, object in root:GetDescendants() do
		cap(object)
	end
end

TextSizeController:OnStart(function(self)
	-- billboards some features hang in the map (prices, pieces)
	self:Watch(workspace)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return TextSizeController
