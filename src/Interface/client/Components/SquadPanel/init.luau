--!strict
-- SquadPanel: the lobby squad (party) window (user request 2026-10-11), cartoon kit (AST-091), mobile first.
-- A LobbyWindow (600 x 330 at Scale 1):
--   left   the squad: up to `MaxSize` slots (avatar head shot, name, "Leader" tag, Ready / Not ready, kick X for the
--          leader on the others; empty slots faded) and the action row: Ready / Not ready · Start (leader) · Leave.
--          Outside a squad: a big "Create Squad" button instead.
--   right  "Invite": the other players of this server (avatar, name, Invite / Sent), scrolling.
-- Pure: only props; the caller sends the Party packets and the server decides (Party set).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent.LobbyWindow)
local Icon = require(script.Parent.LobbyWindow.Icon)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; ScrollingFrame and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Member = {
	UserId: number,
	Name: string,
	Leader: boolean,
	Ready: boolean,
	Me: boolean,
}

export type Candidate = {
	UserId: number,
	Name: string,
	Invited: boolean, -- invite sent a moment ago (local)
}

type Slot = { Member: Member? }

export type Props = {
	Visible: () -> boolean,
	InSquad: () -> boolean,
	Members: () -> { Member },
	IsLeader: () -> boolean,
	-- the server is moving the squad to a run
	Starting: () -> boolean,
	Candidates: () -> { Candidate },
	MaxSize: number?,
	-- a request is on its way
	Busy: (() -> boolean)?,
	OnCreate: () -> (),
	OnInvite: (userId: number) -> (),
	OnKick: (userId: number) -> (),
	OnLeave: () -> (),
	OnReady: (ready: boolean) -> (),
	OnStart: () -> (),
	OnClose: () -> (),
	Scale: (() -> number)?,
}

const WIDTH = 600
const HEIGHT = 330
const LEFT = 310
const GAP = 10
const SLOT = 46
const SLOT_GAP = 3
const BUTTON = 44
const ROW = 50
const AVATAR = 36

local function headshot(userId: number): string
	return if userId > 0 then `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150` else ""
end

local function avatar(userId: () -> number, size: number): Instance
	return create("ImageLabel")({
		Name = "Avatar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Color.Cream,
		Image = function()
			return headshot(userId())
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
	})
end

return function(props: Props): Frame
	const maxSize = props.MaxSize or 4
	const busy = function(): boolean
		return props.Busy ~= nil and props.Busy()
	end
	const me = function(): Member?
		for _, member in props.Members() do
			if member.Me then
				return member
			end
		end
		return nil
	end
	const allReady = function(): boolean
		for _, member in props.Members() do
			if not member.Ready and not member.Leader then
				return false
			end
		end
		return true
	end
	-- slot rows: the members, then empty slots up to maxSize
	const slots = function(): { Slot }
		const list: { Slot } = {}
		for _, member in props.Members() do
			table.insert(list, { Member = member })
		end
		while #list < maxSize do
			table.insert(list, { Member = nil })
		end
		return list
	end

	const slotList = create("Frame")({
		Name = "Slots",
		Size = UDim2.new(1, 0, 0, SLOT * maxSize + SLOT_GAP * (maxSize - 1)),
		BackgroundTransparency = 1,
		Visible = props.InSquad,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, SLOT_GAP),
		}),
		indexes(slots, function(slot: () -> Slot, index: number)
			const member = function(): Member?
				return slot().Member
			end
			const filled = function(): boolean
				return member() ~= nil
			end
			return CartoonPanel({
				Name = `Slot{index}`,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, SLOT),
				Tone = function()
					const m = member()
					return if m and m.Me then Theme.Tone.Mustard else Theme.Tone.Cream
				end,
				Transparency = function()
					return if filled() then 0 else 0.7
				end,
				Outline = Theme.Outline.Normal,
				Radius = Theme.Radius.Chip,
				Lip = 3,
				Gloss = false,
				Padding = { Left = 6, Right = 4 },
				Children = {
					avatar(function()
						const m = member()
						return if m then m.UserId else 0
					end, AVATAR - 4),
					CartoonLabel({
						Name = "Name",
						Position = UDim2.fromOffset(AVATAR + 2, 0),
						Box = UDim2.new(1, -(AVATAR + 2) - 140, 1, 0),
						TextSize = 16,
						XAlignment = Enum.TextXAlignment.Left,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Truncate = true,
						Transparency = function()
							return if filled() then 0 else 0.4
						end,
						Text = function()
							const m = member()
							return if m then m.Name else "Empty"
						end,
					}),
					-- leader crown / ready state
					CartoonLabel({
						Name = "State",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -(BUTTON + 6), 0.5, 0),
						TextSize = Theme.MinTextSize,
						Color = function()
							const m = member()
							return if m and (m.Ready or m.Leader) then Theme.Color.Green else Theme.Color.Dark
						end,
						Stroke = 0,
						Visible = filled,
						Text = function()
							const m = member()
							if m == nil then
								return ""
							elseif m.Leader then
								return "Leader"
							end
							return if m.Ready then "Ready" else "Not ready"
						end,
					}),
					CartoonButton({
						Name = "Kick",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(BUTTON, BUTTON - 6),
						Tone = Theme.Tone.Slate,
						Visible = function()
							const m = member()
							return m ~= nil and not m.Me and props.IsLeader()
						end,
						Enabled = function()
							return not busy()
						end,
						OnActivated = function()
							const m = member()
							if m then
								props.OnKick(m.UserId)
							end
						end,
						Children = {
							create("UIListLayout")({
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							Icon("Ui/close", 22, 1),
							CartoonLabel({
								TextSize = 18,
								Text = "X",
								Visible = not Icons.Has("Ui/close"),
							}),
						},
					}),
				},
			})
		end),
	})

	const actions = create("Frame")({
		Name = "Actions",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, BUTTON + 4),
		BackgroundTransparency = 1,
		Visible = props.InSquad,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		-- members: Ready toggle
		CartoonButton({
			Name = "Ready",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(150, BUTTON),
			TextSize = 18,
			Outline = Theme.Outline.Thick,
			Visible = function()
				return not props.IsLeader()
			end,
			Tone = function()
				const m = me()
				return if m and m.Ready then Theme.Tone.Mustard else Theme.Tone.Green
			end,
			Enabled = function()
				return not busy() and not props.Starting()
			end,
			Text = function()
				const m = me()
				return if m and m.Ready then "Not ready" else "Ready"
			end,
			OnActivated = function()
				const m = me()
				props.OnReady(not (m and m.Ready))
			end,
		}),
		-- leader: Start
		CartoonButton({
			Name = "Start",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(150, BUTTON),
			TextSize = 20,
			Outline = Theme.Outline.Thick,
			Visible = props.IsLeader,
			Tone = Theme.Tone.Green,
			Enabled = function()
				return allReady() and not busy() and not props.Starting()
			end,
			Text = function()
				if props.Starting() then
					return "Starting..."
				end
				return if allReady() then "Start" else "Waiting..."
			end,
			OnActivated = props.OnStart,
		}),
		CartoonButton({
			Name = "Leave",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(120, BUTTON),
			TextSize = 18,
			Outline = Theme.Outline.Thick,
			Tone = Theme.Tone.Slate,
			Enabled = function()
				return not busy() and not props.Starting()
			end,
			Text = "Leave",
			OnActivated = props.OnLeave,
		}),
	})

	const noSquad = create("Frame")({
		Name = "NoSquad",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = function()
			return not props.InSquad()
		end,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
		Icon("Ui/friends", 64, 1),
		CartoonLabel({
			LayoutOrder = 2,
			Box = UDim2.new(1, -20, 0, 44),
			TextSize = 16,
			Wrapped = true,
			Text = `Play together with up to {maxSize} friends.`,
		}),
		CartoonButton({
			Name = "Create",
			LayoutOrder = 3,
			Size = UDim2.fromOffset(200, 52),
			TextSize = 22,
			Outline = Theme.Outline.Thick,
			Tone = Theme.Tone.Green,
			Enabled = function()
				return not busy()
			end,
			Text = "Create Squad",
			OnActivated = props.OnCreate,
		}),
	})

	const invite = CartoonPanel({
		Name = "Invite",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -(LEFT + GAP), 1, 0),
		Tone = Theme.Tone.Ink,
		Outline = Theme.Outline.Normal,
		Radius = Theme.Radius.Card,
		Gloss = false,
		Padding = { Top = 6, Bottom = 6, Left = 8, Right = 4 },
		Children = {
			CartoonLabel({
				Name = "Title",
				Box = UDim2.new(1, 0, 0, 24),
				TextSize = 18,
				XAlignment = Enum.TextXAlignment.Left,
				Text = "Invite players",
			}),
			createRaw("ScrollingFrame")({
				Name = "Players",
				Position = UDim2.fromOffset(0, 28),
				Size = UDim2.new(1, 0, 1, -28),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Color.Cream,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Selectable = false,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				CartoonLabel({
					Name = "Empty",
					LayoutOrder = 0,
					Box = UDim2.new(1, -8, 0, 60),
					TextSize = Theme.MinTextSize,
					Wrapped = true,
					Transparency = 0.3,
					Text = "Nobody else here yet.",
					Visible = function()
						return #props.Candidates() == 0
					end,
				}),
				indexes(props.Candidates, function(candidate: () -> Candidate, index: number)
					return create("Frame")({
						Name = `Player{index}`,
						LayoutOrder = index,
						Size = UDim2.new(1, -8, 0, ROW),
						BackgroundTransparency = 1,
						avatar(function()
							return candidate().UserId
						end, AVATAR),
						CartoonLabel({
							Name = "Name",
							Position = UDim2.fromOffset(AVATAR + 6, 0),
							Box = UDim2.new(1, -(AVATAR + 6) - 96, 1, 0),
							TextSize = 16,
							XAlignment = Enum.TextXAlignment.Left,
							Truncate = true,
							Text = function()
								return candidate().Name
							end,
						}),
						CartoonButton({
							Name = "Invite",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							Size = UDim2.fromOffset(90, BUTTON),
							TextSize = 16,
							Tone = Theme.Tone.Mustard,
							Enabled = function()
								return not candidate().Invited and not busy()
							end,
							Text = function()
								return if candidate().Invited then "Sent" else "Invite"
							end,
							OnActivated = function()
								props.OnInvite(candidate().UserId)
							end,
						}),
					})
				end),
			}),
		},
	})

	return LobbyWindow({
		Name = "SquadPanel",
		Title = "Squad",
		Icon = "Ui/friends",
		Size = Vector2.new(WIDTH, HEIGHT),
		Visible = props.Visible,
		Scale = props.Scale,
		OnClose = props.OnClose,
		Children = {
			create("Frame")({
				Name = "Squad",
				Size = UDim2.new(0, LEFT, 1, 0),
				BackgroundTransparency = 1,
				slotList,
				actions,
				noSquad,
			}),
			invite,
		},
	})
end
