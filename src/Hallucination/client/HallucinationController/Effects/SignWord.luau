--!strict
-- sign_word (< 20, family D; anomalies-v2-proposal.md §3 D; DEC-254): the Mart's "OPEN 24 HOURS" sign (AST-028
-- `Sign_Open24`) goes dark for an instant and blinks ONE odd word in its own neon colour, twice, then is back to
-- normal. Only when the sign is in view. Local only: the tubes are dimmed through Context.Dim (LightController keeps
-- Material/Color/Enabled) and the word is a BillboardGui on top of the sign, removed at the end.
-- Words are original, short and Mild (no threat, no instruction the player could take as a rule).
local Workspace = game:GetService("Workspace")
local StarterPlayer = game:GetService("StarterPlayer")
local Context = require(script.Parent.Parent.Context)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

const SIGN_NAME = "Sign_Open24"
const KEY = "post_click" -- dry neon click
const WORDS = { "OPEN 25 HOURS", "HUNGRY", "STAY", "NOT OPEN", "HELLO ROOKIE", "WE SEE YOU" }
const CONE = 50 -- degrees
const RANGE = 250 -- studs
const DIM = 0.95
const PATTERN = { 0.15, 0.45, 0.12, 0.45, 0.15 } -- dark, word, dark, word, dark (s)
const RESCAN = 15 -- s: the Workspace walk is cached

local cached: { Instance } = {}
local scannedAt = -math.huge

local function signs(): { Instance }
	if os.clock() - scannedAt < RESCAN then
		return cached
	end
	scannedAt = os.clock()
	const out: { Instance } = {}
	for _, descendant in Workspace:GetDescendants() do
		if descendant.Name == SIGN_NAME and (descendant:IsA("BasePart") or descendant:IsA("Model")) then
			table.insert(out, descendant)
		end
	end
	cached = out
	return out
end

local function target(): (Instance?, { BasePart })
	for _, sign in signs() do
		const at = if sign:IsDescendantOf(Workspace) then Context.PositionOf(sign) else nil
		if at then
			const angle, distance = Context.ViewAngle(at)
			const parts = Context.LitParts(sign)
			if angle ~= nil and angle <= CONE and distance <= RANGE and #parts > 0 then
				return sign, parts
			end
		end
	end
	return nil, {}
end

local function boxOf(sign: Instance): (CFrame, Vector3)
	if sign:IsA("Model") then
		return sign:GetBoundingBox()
	end
	const part = sign :: BasePart
	return part.CFrame, part.Size
end

local function word(sign: Instance, parts: { BasePart }, text: string): (BillboardGui, BasePart)
	const frame, size = boxOf(sign)
	const anchor = Context.Prop("SignWordAnchor", Vector3.new(0.2, 0.2, 0.2), Color3.new(), nil)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(frame.Position)
	const width = math.max(size.X, size.Z)
	const gui = Instance.new("BillboardGui")
	gui.Name = "SignWord"
	gui.Adornee = anchor
	gui.Size = UDim2.fromScale(width * 0.9, math.max(size.Y * 0.6, 1))
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Enabled = false
	const label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.Font.Title
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = parts[1].Color
	label.TextStrokeTransparency = 0.6
	label.Parent = gui
	return gui, anchor
end

const SignWord: Context.Effect = {
	CanRun = function(_env: Context.Env): boolean
		return (target()) ~= nil
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const sign, parts = target()
		if sign == nil then
			return
		end
		const gui, anchor = word(sign, parts, WORDS[env.Random:NextInteger(1, #WORDS)])
		run:Cleanup(function()
			gui:Destroy()
			anchor:Destroy()
		end)
		anchor.Parent = Workspace
		gui.Parent = anchor
		const restore = Context.Dim(parts, Context.Lights(sign), DIM)
		run:Cleanup(restore)
		const at = Context.PositionOf(sign)
		for index, seconds in PATTERN do
			const showWord = index % 2 == 0
			gui.Enabled = showWord
			if showWord and at then
				env.Sound(KEY, at, { Volume = 0.6 })
			end
			if not run:Wait(seconds) then
				return
			end
		end
	end,
}

return SignWord
