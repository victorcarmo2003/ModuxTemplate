--!strict
-- AnomalyTablet on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport. "Found" = how many pages
-- (from the start) are unlocked; the first one is "NEW!" while Fresh is on. Drag / swipe / wheel / arrows / dots turn
-- pages locally (no server); the photos are the uploaded ones (Images.luau), a locked page shows the "???" print.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Parent.Theme)
local AnomalyTablet = require(script.Parent)

const create = Vide.create
const source = Vide.source
const untrack = Vide.untrack

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Found: () -> number,
	Fresh: () -> boolean,
	Hint: () -> boolean,
}

const total = #Content.Journal.List

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Found = UILabs.Slider(4, 0, total, 1),
		Fresh = true,
		Hint = true,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const index = source(1)
	const open = source(true)

	const pages = function(): { [string]: boolean }
		const out: { [string]: boolean } = {}
		for i, row in Content.Journal.List do
			if i <= controls.Found() then
				out[row.Key] = true
			end
		end
		return out
	end

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Teal,
		BackgroundTransparency = 0.6,
		ClipsDescendants = true,

		create("TextButton")({
			Name = "Reopen",
			Size = UDim2.fromOffset(120, 36),
			Position = UDim2.fromOffset(8, 8),
			Text = "Open tablet",
			Visible = function()
				return not open()
			end,
			Activated = function()
				open(true)
			end,
		}),

		AnomalyTablet({
			Visible = open,
			Pages = pages,
			Fresh = function()
				const first = Content.Journal.List[1]
				return if controls.Fresh() and first then { [first.Key] = true } else {}
			end,
			Index = index,
			Scale = controls.Scale,
			Hint = function()
				return if controls.Hint() then "Swipe, drag or scroll to turn pages" else ""
			end,
			OnTurn = function(delta: number)
				index(math.clamp(untrack(index) + delta, 1, total))
			end,
			OnClose = function()
				open(false)
			end,
		}),
	})
end)
