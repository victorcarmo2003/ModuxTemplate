--!strict
-- ClassStage with every class species (Content.Classes): pick one to see the swap pop; the rig swings slowly.
-- Needs ReplicatedStorage.Assets.Crew synced for the rig; otherwise the placeholder letter stays.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Theme = require(script.Parent.Parent.Theme)
local ClassStage = require(script.Parent)

const create = Vide.create

type Controls = {
	Class: () -> string,
	Visible: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Class = UILabs.Choose(Content.Classes.Keys),
		Visible = true,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)

	local function species(): string
		const class = Content.Classes.ByKey[controls.Class()]
		return if class then class.Species else "dog"
	end

	return create("Frame")({
		Name = "Screen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Teal,

		ClassStage({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(260, 340),
			Species = species,
			Badge = function()
				return string.upper(string.sub(species(), 1, 1))
			end,
			Visible = controls.Visible,
			Rig = function(key: string): Model?
				const ok, model = pcall(function(): Model
					const rig = CrewRig.Build(key, "crew", { Tag = false, Anchored = true })
					CrewRig.Dress(rig)
					return rig
				end)
				if not ok then
					warn(`[ClassStage story] no rig for {key}: {model}`)
					return nil
				end
				return model
			end,
		}),
	})
end)
