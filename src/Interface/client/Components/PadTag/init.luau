--!strict
-- PadTag: the room sign over a lobby squad pad (user request 2026-10-12), cartoon kit (AST-091; style guide §7.3
-- UI in the world). Two big readable pieces floating over the pad, no loose numbers:
--   count pill   big round pill, Ink outline and a soft glow in the colour of the room state, white text:
--                  Free FREE (Green) · Configuring SETUP (Mustard) · Open "n/max" (Green) · Closed FULL / CLOSED (Slate)
--                  · Starting "n/max" (Teal, breathing). A pad has NO fixed capacity: the room takes the size its leader
--                  chose (Max); a free pad or a room being set up shows none.
--   (run seal removed, TASK-310; Badge is kept in the props but no longer drawn)
--   caption      small line under the seal: the leader's name (truncated), or the status line ("STEP IN",
--                "STARTING IN 3...") while nobody leads the room yet / during the countdown
-- Pop: the pill jumps (scale) every time the count or the state changes (someone steps on / off, the room opens). The
-- sign fades and grows in when it shows and shrinks out when it hides (Visible).
-- Colours: Free Green, Configuring Mustard, Open Green, Closed Slate, Starting Teal (never red: style guide §7.4).
-- Sized in studs (a BillboardGui with a fixed size, like TableSign): it shrinks with distance like a real sign, so two
-- pads never overlap; MaxDistance 140 studs by default; it always faces the player. Pure: only props; LobbyController
-- owns the data, parents the BillboardGui and decides every text (the server decides the squads). Build it inside a
-- Vide root (it uses springs and effects).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; CanvasGroup, UIPadding, UIScale and UIAspectRatioConstraint are not
-- among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type State = "Free" | "Configuring" | "Open" | "Closed" | "Starting"

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	-- players in the squad on the pad (0 = free)
	Count: () -> number,
	-- players the room takes (the size its leader chose); 0 = no size yet (free pad, room being set up)
	Max: () -> number,
	State: () -> State,
	-- "FULL" / "CLOSED" (shown in the Closed pill) / "STEP IN" / "STARTING IN 3..."
	Status: () -> string,
	-- name of the squad leader; "" or nil = none
	Leader: (() -> string)?,
	-- text of the old run seal ("D1"); not drawn since TASK-310
	Badge: string,
	-- World-space offset over the adornee (studs).
	Offset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 7 -- studs
const HEIGHT = 7.2
const MAX_TEXT = 64
const DEFAULT_DISTANCE = 140
const NAME_CHARS = 12
const BREATH_SPEED = 2 * math.pi / 0.7 -- rad/s while the countdown runs (one breath per 0.7 s)

const TONE: { [State]: Theme.Tone } = {
	Free = Theme.Tone.Green,
	Configuring = Theme.Tone.Mustard,
	Open = Theme.Tone.Green,
	Closed = Theme.Tone.Slate,
	Starting = Theme.Tone.Teal,
}

local function short(name: string): string
	const length = utf8.len(name)
	if length == nil or length <= NAME_CHARS then
		return name
	end
	const cut = (utf8.offset(name, NAME_CHARS + 1) or (#name + 1)) - 1
	return string.sub(name, 1, cut) .. "..."
end

return function(props: Props): BillboardGui
	const tone = function(): Theme.Tone
		return TONE[props.State()]
	end
	const shown = function(): boolean
		return props.Visible() and not Cinematic.Active()
	end
	const reveal = Motion.Reveal(shown)
	const pop = Motion.Pop(shown)

	-- Pill text: what the room is, then n/max
	const label = function(): string
		const state = props.State()
		if state == "Free" then
			return "FREE"
		elseif state == "Configuring" then
			return "SETUP"
		elseif state == "Closed" then
			return props.Status()
		end
		const count = props.Count()
		return `{count}/{math.max(props.Max(), count)}`
	end

	const caption = function(): string
		const state = props.State()
		if state == "Starting" or state == "Free" then
			return props.Status()
		end
		const leader = if props.Leader then props.Leader() else ""
		return if leader ~= "" then short(leader) else props.Status()
	end

	-- Pop of the pill: someone stepped on / off or the room changed state.
	const kicks = source(0)
	local lastCount = untrack(props.Count)
	local lastState = untrack(props.State)
	effect(function()
		const count = props.Count()
		const state = props.State()
		untrack(function()
			if count ~= lastCount or state ~= lastState then
				lastCount = count
				lastState = state
				kicks(kicks() + 1)
			end
			return nil
		end)
	end)
	const bump = Motion.Bump(function(): number
		return kicks()
	end, 1.22, 0.18)

	-- Breath of the countdown (0..1); idle (0) otherwise: no per-frame writes outside Starting.
	const beat = source(0)
	const connection = RunService.Heartbeat:Connect(function()
		if untrack(props.State) == "Starting" then
			beat(0.5 + 0.5 * math.sin(os.clock() * BREATH_SPEED))
		elseif untrack(beat) ~= 0 then
			beat(0)
		end
	end)
	cleanup(function()
		connection:Disconnect()
	end)

	const pillScale = function(): number
		return bump() * (1 + 0.06 * beat())
	end

	return createRaw("BillboardGui")({
		Name = props.Name or "PadTag",
		Adornee = props.Adornee,
		Size = UDim2.fromScale(WIDTH, HEIGHT),
		StudsOffsetWorldSpace = props.Offset or Vector3.zero,
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

			-- count pill (+ glow behind it)
			create("Frame")({
				Name = "Pill",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.03),
				Size = UDim2.fromScale(0.74, 0.3),
				BackgroundTransparency = 1,

				createRaw("UIScale")({ Scale = pillScale }),

				create("Frame")({
					Name = "Glow",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1.12, 1.3),
					BackgroundColor3 = function()
						return tone().Top
					end,
					BackgroundTransparency = function()
						return 0.72 - 0.4 * beat()
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				}),

				CartoonPanel({
					Name = "Plate",
					Size = UDim2.fromScale(1, 1),
					Tone = tone,
					Outline = Theme.Outline.Normal,
					Lip = 4,
					Radius = UDim.new(0.5, 0),
					Studs = true,
					Children = {
						createRaw("UIPadding")({
							PaddingTop = UDim.new(0.08, 0),
							PaddingBottom = UDim.new(0.04, 0),
							PaddingLeft = UDim.new(0.08, 0),
							PaddingRight = UDim.new(0.08, 0),
						}),
						CartoonLabel({
							Name = "Count",
							Box = UDim2.fromScale(1, 1),
							Scaled = true,
							MaxTextSize = MAX_TEXT,
							TextSize = 24,
							Color = Theme.Color.Text,
							Stroke = Theme.Outline.Normal,
							Text = label,
						}),
					},
				}),
			}),

			-- (the run seal "D1"/"N1" was removed, TASK-310: zero width under its aspect constraint, it drew a white dot)

			-- leader / status
			CartoonLabel({
				Name = "Caption",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.99),
				Box = UDim2.fromScale(0.9, 0.13),
				Scaled = true,
				MaxTextSize = MAX_TEXT,
				TextSize = 20,
				Color = Theme.Color.Cream,
				Stroke = Theme.Outline.Thin,
				Text = caption,
			}),
		}),
	}) :: BillboardGui
end
