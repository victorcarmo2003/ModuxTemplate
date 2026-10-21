--!strict
-- ProgressBar: world-space bar over a station item (port of AnimalPlane `CookInterface`, DEC-015, DEC-029).
-- Style guide §7.3: 0.8 x 0.15 stud, 1.0 stud above the sausage, orange while cooking, green when ready.
-- Pure: only props. The caller parents the returned BillboardGui (PlayerGui or the adornee itself)
-- and drives `Progress`, usually from `(GetServerTimeNow() - StartedAt) / Duration`.
-- Flip mode (owner 2026-10-20: the flip bar is the cooking bar itself, not a second billboard over it): with `Flip`, the one
-- BillboardGui holds two bodies. When `Flip()` turns on, the cooking bar shrinks and pops out, then the flip bar (FlipMeter.Body)
-- pops in; when it turns off, the flip bar pops out, then the cooking bar pops back in. Without `Flip` nothing changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Motion = require(script.Parent.Motion)
local FlipBody = require(script.Parent.FlipMeter.Body)
local Bar = require(script.Bar)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

-- Studs of the gui in flip mode: room for the "FLIP!" seal over the track and the sausage riding it
-- owner 2026-10-21 ("muito larga na horizontal"): 1.5 -> 1.0 wide; FlipMeter.Body keeps the sausage icon and the seal at their
-- old size in studs, only the track gets shorter
const FLIP_GUI = Vector2.new(1.0, 0.8)
const HANDOFF = 0.1 -- scale at which one body is "gone" and the other may start to pop in
const GONE = 0.02 -- below this a body is not drawn

export type Props = {
	Adornee: Instance?,
	Progress: () -> number,
	Visible: (() -> boolean)?,
	FillColor: (() -> Color3)?,
	Text: (() -> string)?,
	-- Flip mode: whether the bar is the flip bar now, and where the sausage icon is on it (0..1). Both optional; no Flip = the
	-- plain progress bar.
	Flip: (() -> boolean)?,
	Marker: (() -> number)?,
	-- Defaults follow the style guide; a caller may pass a bigger size and MaxDistance. With Flip, Size is the size of the
	-- progress bar itself (scale, in studs); the gui is bigger around it.
	Size: UDim2?,
	StudsOffset: Vector3?,
	MaxDistance: number?,
	AlwaysOnTop: boolean?, -- drawn over the world (the grill bars, owner 2026-10-20); default false
	Name: string?,
}

return function(props: Props): BillboardGui
	const visible = props.Visible
	const flip = props.Flip
	const progressSize = props.Size or UDim2.fromScale(0.8, 0.15)

	if flip == nil then
		return create("BillboardGui")({
			Name = props.Name or "ProgressBar",
			Adornee = props.Adornee,
			Size = progressSize,
			StudsOffset = props.StudsOffset or Vector3.new(0, 1, 0),
			MaxDistance = props.MaxDistance or 60,
			LightInfluence = 0,
			AlwaysOnTop = props.AlwaysOnTop == true,
			ResetOnSpawn = false,
			-- Off while a cinematic owns the screen (Interface/Cinematic).
			Enabled = function()
				return (if visible then visible() else true) and not Cinematic.Active()
			end,

			Bar({
				Progress = props.Progress,
				FillColor = props.FillColor,
				Text = props.Text,
			}),
		})
	end

	-- Two bodies, one after the other: each pops toward 1 only while the other is (almost) gone.
	const progressLevel = Vide.source(1)
	const flipLevel = Vide.source(0)
	const flipOn = Vide.derive(function(): boolean
		return flip()
	end)
	const progressScale = Motion.RevealPop(Vide.derive(function(): boolean
		return not flipOn() and flipLevel() < HANDOFF
	end))
	const flipScale = Motion.RevealPop(Vide.derive(function(): boolean
		return flipOn() and progressLevel() < HANDOFF
	end))
	Vide.effect(function()
		progressLevel(progressScale())
	end)
	Vide.effect(function()
		flipLevel(flipScale())
	end)

	const marker = props.Marker or function(): number
		return 0.5
	end

	return create("BillboardGui")({
		Name = props.Name or "ProgressBar",
		Adornee = props.Adornee,
		Size = UDim2.fromScale(FLIP_GUI.X, FLIP_GUI.Y),
		StudsOffset = props.StudsOffset or Vector3.new(0, 1, 0),
		MaxDistance = props.MaxDistance or 60,
		LightInfluence = 0,
		AlwaysOnTop = props.AlwaysOnTop == true,
		ResetOnSpawn = false,
		-- Off while a cinematic owns the screen, or while neither body shows
		Enabled = function()
			return (if visible then visible() else true)
				and not Cinematic.Active()
				and (progressLevel() > GONE or flipLevel() > GONE)
		end,

		-- the cooking bar, at the same size and place as without Flip
		create("Frame")({
			Name = "ProgressBody",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(progressSize.X.Scale / FLIP_GUI.X, progressSize.Y.Scale / FLIP_GUI.Y),
			BackgroundTransparency = 1,
			Visible = function()
				return progressLevel() > GONE
			end,
			createRaw("UIScale")({
				Scale = function()
					return math.max(progressScale(), 0.01)
				end,
			}),
			Bar({
				Progress = props.Progress,
				FillColor = props.FillColor,
				Text = props.Text,
			}),
		}),

		-- the flip bar
		create("Frame")({
			Name = "FlipHolder",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = function()
				return flipLevel() > GONE
			end,
			createRaw("UIScale")({
				Scale = function()
					return math.max(flipScale(), 0.01)
				end,
			}),
			FlipBody({
				Marker = marker,
				Active = function()
					return flipLevel() > GONE or flipOn()
				end,
			}),
		}),
	})
end
