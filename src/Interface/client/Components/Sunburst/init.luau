--!strict
-- Sunburst: the retro alternating rays of the shop icons (owner request 2026-10-15) spinning slowly behind a shop menu.
-- A clipped full-size frame with one square ImageLabel (Assets/textures/ui/fx/sunburst.png, tools/icons/fx_sunburst.py:
-- white rays that fade out on a circle) sized from the width so the corners never show while it turns. Tinted and faded
-- here; spins only while `Visible`, and stands still with Motion.Reduced (read once a second, the setting can change).
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup

const IMAGE = "rbxassetid://133931169813158" -- fx/sunburst (Assets/textures/ui/_texture_ids.json)

export type Props = {
	Visible: () -> boolean,
	Color: Color3?, -- default Cream
	Transparency: number?, -- default 0.86 (a hint over the panel)
	Speed: number?, -- degrees per second, default 8
	-- Image side as a share of the frame width (it must cover the diagonal while it turns); default 1.3.
	Cover: number?,
	ZIndex: number?,
}

return function(props: Props): Frame
	const angle = source(0)
	const speed = props.Speed or 8

	effect(function()
		if not props.Visible() then
			return
		end
		local reduced = Motion.Reduced()
		local check = 0
		const connection = RunService.RenderStepped:Connect(function(dt: number)
			check += dt
			if check >= 1 then
				check = 0
				reduced = Motion.Reduced()
			end
			if not reduced then
				angle((Vide.untrack(angle) + speed * dt) % 360)
			end
		end)
		cleanup(function()
			connection:Disconnect()
		end)
	end)

	const cover = props.Cover or 1.3
	return create("Frame")({
		Name = "Sunburst",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = props.ZIndex or 0,
		create("ImageLabel")({
			Name = "Rays",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(cover, cover),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			BackgroundTransparency = 1,
			Image = IMAGE,
			ImageColor3 = props.Color or Theme.Color.Cream,
			ImageTransparency = props.Transparency or 0.86,
			Rotation = angle,
			ZIndex = props.ZIndex or 0,
		}),
	}) :: Frame
end
