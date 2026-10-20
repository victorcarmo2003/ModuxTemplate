--!strict
-- ZoneSign: the floating "where am I" sign over a lobby zone (owner request 2026-10-20: the players could not tell the
-- zones apart, the neon of the map blows out at night). Cartoon kit (AST-091; style guide §7.3 UI in the world):
--   badge    big round disc in the zone tone, Ink outline, the zone icon (Icons sheet; a letter while it is missing)
--   caption  pill under it with the zone name ("CLASSES", "GEMS", "CODES")
--   pointer  small down arrow under the caption, aimed at the floor of the zone
-- The sign bobs slowly up and down so it reads as a marker and not as part of the map. It fades and grows in when it
-- shows and shrinks out when it hides (Visible).
-- Sized in studs (a BillboardGui with a fixed size, like PadTag): it shrinks with distance like a real sign;
-- MaxDistance 160 studs by default; it always faces the player; LightInfluence 0 (never darkened by the night).
-- Pure: only props; LobbyController owns the anchor, parents the BillboardGui and decides every text. Build it inside
-- a Vide root (it uses springs and a Heartbeat).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local Icons = require(script.Parent.Icons)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Icon = require(script.Parent.LobbyWindow.Icon)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; CanvasGroup, UIScale and UIAspectRatioConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	-- Zone name, shown in the caption pill.
	Text: string,
	-- Icons sheet name ("Ui/paw", "Hud/gem"...).
	Icon: string,
	-- Shown in the badge while the icon sheet is missing.
	Fallback: string,
	Tone: Theme.Tone,
	-- World-space offset over the adornee (studs).
	Offset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 8 -- studs
const HEIGHT = 9.8
const MAX_TEXT = 72
const DEFAULT_DISTANCE = 160
const BOB = 0.35 -- studs up and down
const BOB_SPEED = 2 * math.pi / 2.6 -- rad/s (one bob per 2.6 s)

return function(props: Props): BillboardGui
	const shown = function(): boolean
		return props.Visible() and not Cinematic.Active()
	end
	const reveal = Motion.Reveal(shown)
	const pop = Motion.Pop(shown)
	const offset = props.Offset or Vector3.zero

	-- Bob: one write per frame while shown; parked while hidden (no writes).
	const bob = source(0)
	const seed = math.random() * 2 * math.pi
	const connection = RunService.Heartbeat:Connect(function()
		if untrack(shown) and not Motion.Reduced() then
			bob(math.sin(os.clock() * BOB_SPEED + seed))
		end
	end)
	cleanup(function()
		connection:Disconnect()
	end)

	const icon = Icon(props.Icon, 24, 1)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.72, 0.72)

	return createRaw("BillboardGui")({
		Name = props.Name or "ZoneSign",
		Adornee = props.Adornee,
		Size = UDim2.fromScale(WIDTH, HEIGHT),
		StudsOffsetWorldSpace = function()
			return offset + Vector3.new(0, BOB * bob(), 0)
		end,
		MaxDistance = props.MaxDistance or DEFAULT_DISTANCE,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		-- Off once the fade-out is over, and while a cinematic owns the screen (Interface/Cinematic).
		Enabled = function()
			return shown() or reveal() > 0.02
		end,

		createRaw("CanvasGroup")({
			Name = "Root",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = function()
				return 1 - reveal()
			end,

			createRaw("UIScale")({
				Scale = function()
					return 0.55 + 0.45 * pop()
				end,
			}),

			-- round badge with the zone icon (+ soft glow behind it)
			create("Frame")({
				Name = "Badge",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.02),
				Size = UDim2.fromScale(0.62, 0.52),
				BackgroundTransparency = 1,
				createRaw("UIAspectRatioConstraint")({ AspectRatio = 1 }),

				create("Frame")({
					Name = "Glow",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1.18, 1.18),
					BackgroundColor3 = props.Tone.Top,
					BackgroundTransparency = 0.75,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				}),

				CartoonPanel({
					Name = "Disc",
					Size = UDim2.fromScale(1, 1),
					Tone = props.Tone,
					Outline = Theme.Outline.Normal,
					Lip = 4,
					Radius = UDim.new(0.5, 0),
					Children = {
						icon,
						CartoonLabel({
							Name = "Fallback",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Box = UDim2.fromScale(0.7, 0.7),
							Visible = not Icons.Has(props.Icon),
							Scaled = true,
							MaxTextSize = MAX_TEXT,
							TextSize = 40,
							Color = props.Tone.Text,
							Text = props.Fallback,
						}),
					},
				}),
			}),

			-- zone name
			CartoonPanel({
				Name = "Caption",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.56),
				Size = UDim2.fromScale(1, 0.32),
				Tone = Theme.Tone.Ink,
				Outline = Theme.Outline.Normal,
				Lip = 3,
				Radius = UDim.new(0.5, 0),
				Children = {
					CartoonLabel({
						Name = "Text",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Box = UDim2.fromScale(0.9, 0.86),
						Scaled = true,
						MaxTextSize = MAX_TEXT,
						TextSize = 28,
						Color = Theme.Color.Text,
						Stroke = Theme.Outline.Normal,
						Text = props.Text,
					}),
				},
			}),

			-- pointer to the floor
			CartoonLabel({
				Name = "Pointer",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Box = UDim2.fromScale(0.26, 0.11),
				Scaled = true,
				MaxTextSize = MAX_TEXT,
				TextSize = 24,
				Color = props.Tone.Top,
				Stroke = Theme.Outline.Normal,
				Text = "▼",
			}),
		}),
	}) :: BillboardGui
end
