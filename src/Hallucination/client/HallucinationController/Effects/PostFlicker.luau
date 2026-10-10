--!strict
-- post_flicker (< 40; script.md §5.12/§8, anomalies.md N7 note, DEC-123): a lit Juniper post the player is looking at
-- flickers like the Walker's post -- WITHOUT the buzz. `post_buzz` (SFX-148) is the real N7 start sign and is never
-- played here; the dry click is SFX-131 (`post_click`, no key yet: silent until Q-168). Local only; it never moves the
-- Walker, never opens a test and never costs the -5 of "seeing" (FEAT-019).
-- LightController owns Material/Color/Enabled of the posts; the flicker only dims (Context.Dim) and restores.
local Context = require(script.Parent.Parent.Context)

const TAG = "StreetLight"
const GROUP = "juniper_posts" -- the Walker's street (Content.LightGroups)
const KEY = "post_click" -- SFX-131; never "post_buzz" (DEC-123)
const CONE = 40 -- degrees: in view
const RANGE = 260 -- studs: up to the far end of Juniper (last post ~135 from the trailer window)
const MIN_RANGE = 20 -- a post right overhead does not read as "the far lamp"
-- off/on seconds: an irregular, nervous flicker of about 1.5 s (style guide: Flicker of AST-036)
const PATTERN = { 0.08, 0.12, 0.1, 0.25, 0.14, 0.06, 0.22, 0.18, 0.1 }
const DIM = 0.92

type Candidate = { Post: Instance, At: Vector3, Distance: number }

local function candidates(): { Candidate }
	const out: { Candidate } = {}
	for _, post in Context.Tagged(TAG) do
		const group = post:GetAttribute("Group")
		if group == nil or group == GROUP then
			const at = Context.PositionOf(post)
			if at and #Context.LitParts(post) > 0 then
				const angle, distance = Context.ViewAngle(at)
				if angle ~= nil and angle <= CONE and distance <= RANGE and distance >= MIN_RANGE then
					table.insert(out, { Post = post, At = at, Distance = distance })
				end
			end
		end
	end
	return out
end

const PostFlicker: Context.Effect = {
	CanRun = function(_env: Context.Env): boolean
		return #candidates() > 0
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const list = candidates()
		-- farther posts weigh more: the false alarm reads like "the far lamp"
		const chosen = Context.Pick(env.Random, list, function(candidate: Candidate): number
			return candidate.Distance
		end)
		if chosen == nil then
			return
		end
		const parts = Context.LitParts(chosen.Post)
		const lights = Context.Lights(chosen.Post)
		local restore: (() -> ())? = nil
		run:Cleanup(function()
			if restore then
				restore()
				restore = nil
			end
		end)
		for index, seconds in PATTERN do
			const off = index % 2 == 1
			if off then
				restore = Context.Dim(parts, lights, DIM)
				if index == 1 or env.Random:NextNumber() < 0.5 then
					env.Sound(KEY, chosen.At)
				end
			elseif restore then
				restore()
				restore = nil
			end
			if not run:Wait(seconds) then
				return
			end
		end
		if restore then
			restore()
			restore = nil
		end
	end,
}

return PostFlicker
