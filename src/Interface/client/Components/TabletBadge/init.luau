--!strict
-- TabletBadge: the round seal on the screen of the Anomaly Tablet in the trailer, where the "?" sticker was (owner request
-- 2026-10-17, Provisional), cartoon kit (AST-091; style guide §7.3 UI in the world). One look tells whether the tablet has
-- something the player has not read:
--   Alert   Mustard disc with a big white "!" (Ink outline), a soft glow behind it pulsing and the seal bobbing up and down
--   Clear   Green disc with the AST-091 check (drawn "OK" until the sheet is uploaded), still
-- The seal jumps (Motion.Bump) every time it flips. Reduced motion (Motion.Reduced): no bob, no pulse.
-- A plain Frame (the seal fills it): the caller puts it in a SurfaceGui on the tablet Screen. Never Active. Pure: only props;
-- JournalController owns the state, the SurfaceGui and the "?" it covers. Build it inside a Vide root (springs, effects).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local Icons = require(script.Parent.Icons)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	-- true = a page the player has not opened yet ("!"), false = nothing new (check)
	Alert: () -> boolean,
	-- false hides the seal (no tablet, or another window owns the screen)
	Visible: (() -> boolean)?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
	SizeConstraint: Enum.SizeConstraint?,
	Name: string?,
}

const MAX_TEXT = 96
const BOB = 0.04 -- of the seal height, up and down while Alert
const BOB_SPEED = 2 * math.pi / 1.1 -- rad/s (one bob per 1.1 s)
const CHECK = "Ui/check"

return function(props: Props): Frame
	const reduced = Motion.Reduced()
	const shown = function(): boolean
		return (if props.Visible then props.Visible() else true) and not Cinematic.Active()
	end
	const pop = Motion.Pop(shown)

	-- Jump on every flip of the state.
	const kicks = source(0)
	local last = untrack(props.Alert)
	effect(function()
		const alert = props.Alert()
		untrack(function()
			if alert ~= last then
				last = alert
				kicks(kicks() + 1)
			end
			return nil
		end)
	end)
	const bump = Motion.Bump(function(): number
		return kicks()
	end, 1.3, 0.22)

	-- 0..1 wave while Alert; idle (0) otherwise: no per-frame writes while clear.
	const beat = source(0)
	const connection = RunService.Heartbeat:Connect(function()
		if untrack(props.Alert) and not reduced then
			beat(0.5 + 0.5 * math.sin(os.clock() * BOB_SPEED))
		elseif untrack(beat) ~= 0 then
			beat(0)
		end
	end)
	cleanup(function()
		connection:Disconnect()
	end)

	const tone = function(): Theme.Tone
		return if props.Alert() then Theme.Tone.Mustard else Theme.Tone.Green
	end
	const hasCheck = Icons.Has(CHECK)
	const checkRect = Icons.Rect(CHECK)

	return create("Frame")({
		Name = props.Name or "TabletBadge",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromScale(1, 1),
		SizeConstraint = props.SizeConstraint or Enum.SizeConstraint.RelativeXY,
		BackgroundTransparency = 1,
		Active = false,
		Visible = function()
			return shown() or pop() > 0.02
		end,

		create("Frame")({
			Name = "Seal",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				const bob = if props.Alert() and not reduced then BOB * (beat() * 2 - 1) else 0
				return UDim2.fromScale(0.5, 0.5 - bob)
			end,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			createRaw("UIScale")({
				Scale = function()
					return math.max(pop(), 0) * bump()
				end,
			}),

			-- glow behind the disc (only while Alert)
			create("Frame")({
				Name = "Glow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = function()
					const grow = 1.18 + 0.12 * beat()
					return UDim2.fromScale(grow, grow)
				end,
				BackgroundColor3 = Theme.Color.Gold,
				BackgroundTransparency = function()
					return if props.Alert() then 0.55 - 0.25 * beat() else 1
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),

			CartoonPanel({
				Name = "Disc",
				Size = UDim2.fromScale(1, 1),
				Tone = tone,
				Outline = Theme.Outline.Normal,
				Lip = 4,
				Radius = UDim.new(0.5, 0),
				Children = {
					CartoonLabel({
						Name = "Mark",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Box = UDim2.fromScale(0.8, 0.8),
						Scaled = true,
						MaxTextSize = MAX_TEXT,
						TextSize = 48,
						Color = Theme.Color.Text,
						Stroke = Theme.Outline.Thick,
						Text = function()
							if props.Alert() then
								return "!"
							end
							return if hasCheck then "" else "OK"
						end,
					}),
					create("ImageLabel")({
						Name = "Check",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.78, 0.78),
						BackgroundTransparency = 1,
						Image = Icons.ImageOf(CHECK),
						ImageRectOffset = if checkRect then checkRect.Offset else Vector2.zero,
						ImageRectSize = if checkRect then checkRect.Size else Vector2.zero,
						Visible = function()
							return hasCheck and not props.Alert()
						end,
					}),
				},
			}),
		}),
	}) :: Frame
end
