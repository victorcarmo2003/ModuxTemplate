--!strict
-- HudSanity: drag "Value" through the bands (>= 60 Day, 40-59 Mid, < 40 Night; < 25 breathes). "Max" = 0 hides it
-- (day). "Species" swaps the portrait (the class animal); "Atlas" off shows the letter fallback.
-- "Compact" = the phone layout (portrait 34, bar 110 x 10, number 11 px); off = desktop (44, 180 x 14).
-- "Revealed" off / on plays the progressive reveal (0.25 s scale); with "Intro" on, the Mustard presentation ring pulses
-- once, the first time the meter is shown and revealed (turn "Revealed" off first, then on). "Gain" toggled = a coffee gain (green flash and floating +N), "Emphasis" = the
-- Night 1 coffee ring. "Order card" shows the HudOrder card stacked under the meter like in the HUD.
-- Phone = 844 x 390 (the emulator landscape) at the top left under a mock of the Roblox bar (the red box of the screenshots).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local CrewLooks = require(ReplicatedStorage.shared.Crew.CrewLooks)
local Theme = require(script.Parent.Parent.Theme)
local HudSanity = require(script.Parent)
local HudOrder = require(script.Parent.Parent.HudOrder)

const create = Vide.create
const effect = Vide.effect
const source = Vide.source
const untrack = Vide.untrack

type Controls = {
	Phone: () -> boolean,
	Compact: () -> boolean,
	Value: () -> number,
	Max: () -> number,
	Species: () -> string,
	Atlas: () -> boolean,
	Revealed: () -> boolean,
	Intro: () -> boolean,
	Emphasis: () -> boolean,
	Gain: () -> boolean,
	OrderCard: () -> boolean,
}

const LEFT = 8
const TOP_BAR = 60 -- real px of the Roblox bar on a phone (HudController TOPBAR_REAL)
const GAP = 8

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Compact = true,
		Value = UILabs.Slider(72, 0, 150, 1),
		Max = UILabs.Slider(100, 0, 150, 1),
		Species = UILabs.Choose({ "dog", "rabbit", "cat", "bear", "fox", "owl", "panda", "lion" }),
		Atlas = true,
		Revealed = false, -- starts hidden: turn it on to play the reveal and the presentation pulse
		Intro = true,
		Emphasis = false,
		Gain = false,
		OrderCard = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const band = function(): HudSanity.Band
		const value = controls.Value()
		if controls.Max() <= 0 or value >= 60 then
			return "Day"
		elseif value >= 40 then
			return "Mid"
		end
		return "Night"
	end

	-- A new table each time "Gain" is toggled (either way) = a new coffee gain
	-- false = none (a Source of an optional type is ambiguous to call under the new solver)
	const gain = source(false :: HudSanity.Gain | false)
	local gainId = 0
	local primed = false
	effect(function()
		controls.Gain()
		if not primed then
			primed = true
			return
		end
		gainId += 1
		untrack(function()
			gain({ Amount = 25, Id = gainId })
		end)
	end)

	const rowHeight = function(): number
		return if controls.Compact() then 38 else 50
	end

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(844, 390) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Teal,
		BackgroundTransparency = 0.6,
		ClipsDescendants = true,

		-- Mock of the Roblox logo + menu / chat bar (top left): where the meter must stay clear of
		create("Frame")({
			Name = "RobloxBar",
			Size = UDim2.fromOffset(270, TOP_BAR - GAP),
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = 0.5,
			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		}),

		HudSanity({
			Value = function()
				return math.min(controls.Value(), controls.Max())
			end,
			Max = controls.Max,
			Band = band,
			Shown = function()
				return controls.Max() > 0
			end,
			Icon = function()
				return if controls.Atlas() then `Class/class_{controls.Species()}` else ""
			end,
			Letter = function()
				return string.upper(string.sub(controls.Species(), 1, 1))
			end,
			Fur = function()
				const look = CrewLooks.Species[controls.Species()]
				return if look then look.Fur else Theme.Color.Cream
			end,
			Compact = controls.Compact,
			Revealed = controls.Revealed,
			Intro = controls.Intro,
			Emphasis = controls.Emphasis,
			Gain = function(): HudSanity.Gain?
				const event = gain()
				return if event then event else nil
			end,
			Position = UDim2.fromOffset(LEFT, TOP_BAR + GAP),
		}),

		HudOrder({
			Shown = controls.OrderCard,
			Toppings = function()
				return { "ketchup", "cheese" }
			end,
			Patience = function()
				return 0.7
			end,
			Position = function()
				return UDim2.fromOffset(LEFT, TOP_BAR + GAP + rowHeight() + GAP)
			end,
		}),
	})
end)
