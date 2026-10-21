--!strict
-- PadQueue: "you are in the queue" strip at the top of the lobby HUD while the player stands in a pad room (owner
-- request 2026-10-21, Provisional; replaces the players-online pill meanwhile). Cartoon kit (AST-091), mobile first.
--   circles  one per seat of the room (Max, at most MAX_SEATS): the head shot of each member (SquadStatus Avatar:
--            GetUserThumbnailAsync, cached, silhouette while loading) in a ring (Mustard = leader, Cream = the rest), and a
--            dashed empty circle for every free seat. A member who arrives pops in at once.
--   EXIT     on the right of the circles: leaves the room (the server takes the player out of the pad barrier)
-- An Ink pill holds both so it reads on any floor. Sized in px at UI scale 1 (the caller wraps it in its UIScale).
-- Pure: only props; LobbyController reads the Party set.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local Avatar = require(script.Parent.SquadStatus.Avatar)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	-- user ids in the room, leader first
	Members: () -> { number },
	-- seats of the room (its MaxPlayers); never fewer circles than members
	Max: () -> number,
	Leader: () -> number,
	OnExit: () -> (),
	Name: string?,
	AnchorPoint: Vector2?,
	Position: CartoonPanel.Value<UDim2>?,
	Visible: (() -> boolean)?,
}

const MAX_SEATS = 4 -- PartyRules.Rules.MaxSize
const SEAT = 38 -- px, a circle
const SEAT_GAP = 6
const HEIGHT = 48 -- px, the pill
const EXIT = Vector2.new(70, 36)
const DASHES = 12

-- Dashed circle of a free seat: DASHES small bars around the centre (Roblox has no dashed stroke).
local function dashes(diameter: number): { Instance }
	const list: { Instance } = {}
	const radius = diameter / 2 - 2
	for index = 1, DASHES do
		const angle = (index - 1) / DASHES * math.pi * 2
		table.insert(
			list,
			create("Frame")({
				Name = "Dash",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, math.cos(angle) * radius, 0.5, math.sin(angle) * radius),
				Size = UDim2.fromOffset(5, 2),
				Rotation = math.deg(angle) + 90,
				BackgroundColor3 = Theme.Color.Cream,
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			})
		)
	end
	return list
end

return function(props: Props): Frame
	const seats = function(): number
		return math.clamp(math.max(props.Max(), #props.Members()), 1, MAX_SEATS)
	end

	local seatViews: { Instance } = {}
	for index = 1, MAX_SEATS do
		const member = function(): number?
			return props.Members()[index]
		end
		const taken = function(): boolean
			return member() ~= nil
		end
		const pop = Motion.Pop(taken)
		table.insert(
			seatViews,
			create("Frame")({
				Name = `Seat{index}`,
				LayoutOrder = index,
				Size = UDim2.fromOffset(SEAT, SEAT),
				BackgroundTransparency = 1,
				Visible = function()
					return index <= seats()
				end,
				-- free seat
				create("Frame")({
					Name = "Free",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.Color.Slate,
					BackgroundTransparency = 0.7,
					Visible = function()
						return not taken()
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					dashes(SEAT),
				}),
				-- member: head shot, pops in
				create("Frame")({
					Name = "Taken",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Visible = function()
						return taken() or pop() > 0.02
					end,
					createRaw("UIScale")({ Scale = pop }),
					Avatar({
						Name = "Face",
						Size = SEAT,
						UserId = function()
							return member() or 0
						end,
						Ring = function()
							const userId = member()
							return if userId ~= nil and userId == props.Leader()
								then Theme.Color.Mustard
								else Theme.Color.Cream
						end,
					}),
				}),
			})
		)
	end

	return CartoonPanel({
		Name = props.Name or "PadQueue",
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = UDim2.fromOffset(0, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		Tone = Theme.Tone.Ink,
		Lip = 2,
		Outline = 2,
		Radius = UDim.new(0.5, 0),
		Padding = { Left = 8, Right = 6 },
		Visible = props.Visible,
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, SEAT_GAP),
			}),
			seatViews,
			CartoonButton({
				Name = "Exit",
				LayoutOrder = MAX_SEATS + 1,
				Size = UDim2.fromOffset(EXIT.X, EXIT.Y),
				TextSize = 17,
				Outline = Theme.Outline.Normal,
				Radius = UDim.new(0.5, 0),
				Tone = Theme.Tone.Mustard,
				Text = "EXIT",
				OnActivated = props.OnExit,
			}),
		},
	}) :: Frame
end
