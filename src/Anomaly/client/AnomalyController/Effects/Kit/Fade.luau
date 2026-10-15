--!strict
--[[
	Fade: reusable client utility that fades a whole model (or any Instance tree) from its own look to fully invisible
	(user request 2026-10-14; DEC-246 ANM-002 "the customer vanishes smiling", DEC-247 ANM-004 "the copy fades").
	Lives in Effects/Kit/ (a Folder), so AnomalyController:LoadEffects never takes it for an effect module.

	```lua
	local Fade = require(script.Parent.Kit.Fade)
	local handle = Fade.Out(model, { Duration = 2, Destroy = true })  -- 0 -> 1 over 2 s (default), then destroy
	handle:Cancel()                    -- stops where it is (values stay as they are)
	handle:Restore()                   -- stops and gives every original value back (pooled / reused models)
	handle:Set(0.5)                    -- manual alpha 0..1 (no timer)
	```
	Reusable by ANM-002: the served customer fades out smiling during SFX-231 (DEC-246), exactly like the ANM-004 copy.

	What is faded (every descendant, and the root itself when it is not a Model):
	  - BasePart.Transparency (SurfaceAppearance / MeshPart textures follow the part), Decal / Texture.Transparency
	  - every GuiObject under SurfaceGui / BillboardGui / ScreenGui: BackgroundTransparency, ImageTransparency (Image*,
	    ViewportFrame), TextTransparency + TextStrokeTransparency (Text*), ScrollBarImageTransparency, CanvasGroup
	    GroupTransparency; UIStroke.Transparency; UIGradient.Transparency (sequence)
	  - Highlight Fill / Outline transparency
	  - Beam / Trail / ParticleEmitter transparency (sequences); ParticleEmitter, Fire, Smoke, Sparkles switch Enabled off
	    at once (and the emitter is cleared); PointLight / SpotLight / SurfaceLight Brightness goes to 0
	  - descendants added while the fade runs are picked up with their current value
	Every value is lerped from its original toward the invisible one (a part that was already half transparent starts
	there), and the originals are kept so Restore gives them back exactly.

	Presentation only: nothing here decides, sends or reads a rule. Client side only: server instances are never
	replicated back.
]]
local RunService = game:GetService("RunService")

export type Handle = {
	-- stops the timer; values stay where they are
	Cancel: (self: Handle) -> (),
	-- stops the timer and writes back every original value (also for descendants removed meanwhile when still alive)
	Restore: (self: Handle) -> (),
	-- manual alpha 0..1 (0 = original look, 1 = invisible); stops the timer
	Set: (self: Handle, alpha: number) -> (),
	-- true once the alpha reached 1 (onDone ran)
	IsDone: (self: Handle) -> boolean,
}

export type Options = {
	-- seconds 0 -> 1 (default Fade.Duration)
	Duration: number?,
	-- runs once when alpha reaches 1 (not on Cancel / Restore)
	OnDone: (() -> ())?,
	-- Destroy the root after OnDone (default false: the caller decides, e.g. a pooled rig goes back to its pool)
	Destroy: boolean?,
}

type Entry = {
	Instance: Instance,
	Scalars: { [string]: number },
	Sequences: { [string]: NumberSequence },
	Switches: { [string]: boolean }, -- Enabled-like properties turned off at the first frame
	Brightness: number?,
}

-- ClassName (IsA) -> scalar properties that go to 1
const SCALARS: { { Class: string, Properties: { string } } } = {
	{ Class = "BasePart", Properties = { "Transparency" } },
	{ Class = "Decal", Properties = { "Transparency" } }, -- Texture is a Decal
	{ Class = "GuiObject", Properties = { "BackgroundTransparency" } },
	{ Class = "ImageLabel", Properties = { "ImageTransparency" } },
	{ Class = "ImageButton", Properties = { "ImageTransparency" } },
	{ Class = "ViewportFrame", Properties = { "ImageTransparency" } },
	{ Class = "TextLabel", Properties = { "TextTransparency", "TextStrokeTransparency" } },
	{ Class = "TextButton", Properties = { "TextTransparency", "TextStrokeTransparency" } },
	{ Class = "TextBox", Properties = { "TextTransparency", "TextStrokeTransparency" } },
	{ Class = "ScrollingFrame", Properties = { "ScrollBarImageTransparency" } },
	{ Class = "CanvasGroup", Properties = { "GroupTransparency" } },
	{ Class = "UIStroke", Properties = { "Transparency" } },
	{ Class = "Highlight", Properties = { "FillTransparency", "OutlineTransparency" } },
}
-- ClassName -> NumberSequence properties that go to 1
const SEQUENCES: { { Class: string, Properties: { string } } } = {
	{ Class = "Beam", Properties = { "Transparency" } },
	{ Class = "Trail", Properties = { "Transparency" } },
	{ Class = "ParticleEmitter", Properties = { "Transparency" } },
	{ Class = "UIGradient", Properties = { "Transparency" } },
}
-- ClassName -> Enabled-like property turned off on the first frame
const SWITCHES: { { Class: string, Property: string } } = {
	{ Class = "ParticleEmitter", Property = "Enabled" },
	{ Class = "Fire", Property = "Enabled" },
	{ Class = "Smoke", Property = "Enabled" },
	{ Class = "Sparkles", Property = "Enabled" },
}
const LIGHTS = { "PointLight", "SpotLight", "SurfaceLight" }

const Fade = {}

Fade.Duration = 2 -- s (DEC-246, DEC-247)

local function capture(instance: Instance): Entry?
	const entry: Entry = { Instance = instance, Scalars = {}, Sequences = {}, Switches = {}, Brightness = nil }
	local any = false
	const raw = instance :: any
	for _, row in SCALARS do
		if instance:IsA(row.Class) then
			for _, property in row.Properties do
				if entry.Scalars[property] == nil then
					const ok, value = pcall(function(): any
						return raw[property]
					end)
					if ok and type(value) == "number" then
						entry.Scalars[property] = value
						any = true
					end
				end
			end
		end
	end
	for _, row in SEQUENCES do
		if instance:IsA(row.Class) then
			for _, property in row.Properties do
				const ok, value = pcall(function(): any
					return raw[property]
				end)
				if ok and typeof(value) == "NumberSequence" then
					entry.Sequences[property] = value
					any = true
				end
			end
		end
	end
	for _, row in SWITCHES do
		if instance:IsA(row.Class) then
			const ok, value = pcall(function(): any
				return raw[row.Property]
			end)
			if ok and type(value) == "boolean" then
				entry.Switches[row.Property] = value
				any = true
			end
		end
	end
	for _, class in LIGHTS do
		if instance:IsA(class) then
			entry.Brightness = raw.Brightness
			any = true
			break
		end
	end
	return if any then entry else nil
end

-- Sequence with every key moved toward 1 by alpha
local function lerpSequence(original: NumberSequence, alpha: number): NumberSequence
	const keys: { NumberSequenceKeypoint } = {}
	for _, key in original.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value + (1 - key.Value) * alpha, key.Envelope))
	end
	return NumberSequence.new(keys)
end

local function write(entry: Entry, alpha: number)
	const instance = entry.Instance
	const raw = instance :: any
	for property, original in entry.Scalars do
		raw[property] = original + (1 - original) * alpha
	end
	for property, original in entry.Sequences do
		raw[property] = lerpSequence(original, alpha)
	end
	if alpha > 0 then
		for property in entry.Switches do
			raw[property] = false
		end
		if instance:IsA("ParticleEmitter") then
			instance:Clear()
		end
	end
	if entry.Brightness ~= nil then
		raw.Brightness = entry.Brightness * (1 - alpha)
	end
end

local function restore(entry: Entry)
	const raw = entry.Instance :: any
	for property, original in entry.Scalars do
		raw[property] = original
	end
	for property, original in entry.Sequences do
		raw[property] = original
	end
	for property, original in entry.Switches do
		raw[property] = original
	end
	if entry.Brightness ~= nil then
		raw.Brightness = entry.Brightness
	end
end

-- Fades `root` and everything under it from the current look to invisible in `Duration` seconds (default 2).
function Fade.Out(root: Instance, options: Options?): Handle
	const opts: Options = options or {}
	const duration = math.max(opts.Duration or Fade.Duration, 1 / 60)
	const entries: { [Instance]: Entry } = {}
	const connections: { RBXScriptConnection } = {}
	local alpha = 0
	local done = false
	local stopped = false
	local startedAt = os.clock()

	local function track(instance: Instance)
		if entries[instance] ~= nil then
			return
		end
		const entry = capture(instance)
		if entry ~= nil then
			entries[instance] = entry
			if alpha > 0 then
				write(entry, alpha)
			end
		end
	end

	track(root)
	for _, descendant in root:GetDescendants() do
		track(descendant)
	end
	table.insert(connections, root.DescendantAdded:Connect(track))

	local function apply(value: number)
		alpha = math.clamp(value, 0, 1)
		for _, entry in entries do
			write(entry, alpha)
		end
	end

	local function stop()
		stopped = true
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	const handle: Handle = {
		Cancel = function(_self: Handle)
			stop()
		end,
		Restore = function(_self: Handle)
			stop()
			for _, entry in entries do
				pcall(restore, entry)
			end
			alpha = 0
			done = false
		end,
		Set = function(_self: Handle, value: number)
			stop()
			apply(value)
		end,
		IsDone = function(_self: Handle): boolean
			return done
		end,
	}

	table.insert(
		connections,
		RunService.Heartbeat:Connect(function()
			if stopped then
				return
			end
			apply((os.clock() - startedAt) / duration)
			if alpha >= 1 then
				stop()
				done = true
				const onDone = opts.OnDone
				if onDone ~= nil then
					const ok, problem = pcall(onDone)
					if not ok then
						warn(`[Fade] OnDone: {problem}`)
					end
				end
				if opts.Destroy == true then
					root:Destroy()
				end
			end
		end)
	)
	return handle
end

return table.freeze(Fade)
