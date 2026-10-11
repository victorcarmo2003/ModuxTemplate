--!strict
-- TutorialDebug on a phone-sized frame: "Shown" toggles it; the text is a sample readout.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local TutorialDebug = require(script.Parent)

const create = Vide.create

type Controls = {
	Shown: () -> boolean,
}

const SAMPLE = table.concat({
	"first run  true (profile ready, TutorialDone false)",
	"running    true  phase Prep  cinematic false",
	"step       grill (3/13)  forced -",
	"call       talking  boss Talking call_tutorial",
	"answered   true  voiced true  greeted true",
	"target     Workspace.Cart.Grill.Anchor_Place",
	"beacon     mounted true  marked Grill",
	"arrow far  false  pointer true",
	"voice      q 12  loading 1  loaded 30  failed 0",
	"volume     master 1.00 x voice 0.80 = 0.80  fader 0.80",
}, "\n")

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Shown = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(667, 375),
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),
		ClipsDescendants = true,

		TutorialDebug({
			Shown = controls.Shown,
			Text = function()
				return SAMPLE
			end,
		}),
	})
end)
