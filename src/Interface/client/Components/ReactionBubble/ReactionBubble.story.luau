--!strict
-- ReactionBubble is a BillboardGui, so it is previewed in the 3D viewport: a temporary "head" part 8 studs in front
-- of the Studio camera (removed when the story closes). Pick the kind and the line; toggle "Replay" to see the pop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local ReactionBubble = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup
const effect = Vide.effect
const untrack = Vide.untrack
const root = Vide.root

type Controls = {
	Kind: () -> string,
	Line: () -> string,
	Replay: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Kind = UILabs.Choose({ "Happy", "Neutral", "Complaint" }),
		Line = "Perfect, thanks!",
		Replay = false,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__ReactionBubbleStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Shape = Enum.PartType.Ball
	anchor.Size = Vector3.new(1.4, 1.4, 1.4)
	anchor.Color = Theme.Color.Cream
	anchor.CFrame = camera.CFrame * CFrame.new(0, -2, -8)
	anchor.Parent = workspace
	cleanup(anchor)

	local destroy: (() -> ())? = nil
	local function mount()
		if destroy then
			destroy()
		end
		destroy = root(function()
			const billboard = ReactionBubble({
				Adornee = anchor,
				Kind = function()
					return controls.Kind() :: ReactionBubble.Kind
				end,
				Text = controls.Line,
				Offset = Vector3.new(0, 1.2, 0),
				MaxDistance = 200,
			})
			billboard.Parent = anchor
			cleanup(billboard)
		end)
	end
	cleanup(function()
		if destroy then
			destroy()
		end
	end)

	effect(function()
		controls.Replay()
		untrack(mount)
	end)

	return create("TextLabel")({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(420, 28),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = 16,
		TextColor3 = Theme.Color.Text,
		Text = "ReactionBubble: look at the ball in front of the camera",
	})
end)
