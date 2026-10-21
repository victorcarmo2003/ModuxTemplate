--!strict
-- SquadSetup: the squad setup window (user request 2026-10-11, Provisional), cartoon kit (AST-091), mobile first.
-- Behind the gear beside START (DEC-344, TASK-619): stepping on a pad no longer opens it; the room already exists and
-- the leader starts it from the HUD. Also opened by "Create Squad" for the new invite squad.
-- A LobbyWindow (560 x 320 at Scale 1):
--   left   the squad: `MaxPlayers` slots (head shot, name, "Leader" tag); empty slots faded
--   right  Who can join (tap to cycle) · Max players  -  n  +  (the leader changes them; the others only read them);
--          Start (leader) or "Waiting for the leader..." (members) · Cancel while starting; while starting:
--          "Starting in n...". No draft and no ready step (DEC-344).
--   foot   platform squad: hint "Step off the platform to leave"
--          invite squad: Invite players (leader) · Leave · hint "Step on a free pad to take your squad there"
-- Pure: only props. The caller sends PartyConfigure / PartyStart / PartyCancel / PartyLeave and the server decides
-- (Party set).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent.LobbyWindow)

const create = Vide.create
const indexes = Vide.indexes

export type Member = {
	UserId: number,
	Name: string,
	Leader: boolean,
	Me: boolean,
}

type Slot = { Member: Member? }

export type Props = {
	Visible: () -> boolean,
	Platform: () -> number,
	Members: () -> { Member },
	IsLeader: () -> boolean,
	-- PartyRules.Access of the shown room: "Open" | "Friends" | "Invite" | "Closed"
	Access: () -> string,
	MaxPlayers: () -> number,
	MaxSize: number?,
	-- seconds left before the teleport; nil = not starting
	Countdown: () -> number?,
	OnAccess: (access: string) -> (),
	OnMaxPlayers: (count: number) -> (),
	OnStart: () -> (),
	-- the leader may abort the countdown until shortly before the teleport (Cancel button; nil = no button)
	CanCancel: (() -> boolean)?,
	OnCancel: (() -> ())?,
	OnClose: () -> (),
	Scale: (() -> number)?,
	-- invite squad (no platform): Invite players / Leave in the foot. Default false.
	Invite: (() -> boolean)?,
	-- open the invite list (the leader)
	OnInvite: (() -> ())?,
	OnLeave: (() -> ())?,
}

const WIDTH = 560
const HEIGHT = 320
const LEFT = 250
const GAP = 12
const FOOT = 44
const SLOT = 42
const SLOT_GAP = 4
const BUTTON = 44
const AVATAR = 32

-- who can join (PartyRules.Access): cycle order, button text and tone
const ACCESS_ORDER = { "Open", "Friends", "Invite", "Closed" }
const ACCESS_TEXT: { [string]: string } = {
	Open = "Open",
	Friends = "Friends only",
	Invite = "Invite only",
	Closed = "Closed",
}
const ACCESS_TONE: { [string]: Theme.Tone } = {
	Open = Theme.Tone.Green,
	Friends = Theme.Tone.Teal,
	Invite = Theme.Tone.Violet,
	Closed = Theme.Tone.Slate,
}

local function headshot(userId: number): string
	return if userId > 0 then `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150` else ""
end

return function(props: Props): Frame
	const maxSize = props.MaxSize or 4
	const starting = function(): boolean
		return props.Countdown() ~= nil
	end
	const editable = function(): boolean
		return props.IsLeader() and not starting()
	end
	const inviteMode = function(): boolean
		return props.Invite ~= nil and props.Invite()
	end
	const slots = function(): { Slot }
		const list: { Slot } = {}
		for _, member in props.Members() do
			table.insert(list, { Member = member })
		end
		const max = math.max(props.MaxPlayers(), #list)
		while #list < max do
			table.insert(list, { Member = nil })
		end
		return list
	end

	const slotList = create("Frame")({
		Name = "Slots",
		Size = UDim2.new(0, LEFT, 1, -(FOOT + 4)),
		BackgroundTransparency = 1,
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
				Padding = { Left = 6, Right = 8 },
				Children = {
					create("ImageLabel")({
						Name = "Avatar",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(AVATAR, AVATAR),
						BackgroundColor3 = Theme.Color.Cream,
						Image = function()
							const m = member()
							return headshot(if m then m.UserId else 0)
						end,
						create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					}),
					CartoonLabel({
						Name = "Name",
						Position = UDim2.fromOffset(AVATAR + 6, 0),
						Box = UDim2.new(1, -(AVATAR + 6) - 64, 1, 0),
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
							return if m then m.Name else "Open"
						end,
					}),
					CartoonLabel({
						Name = "Tag",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						TextSize = Theme.MinTextSize,
						Color = Theme.Color.Green,
						Stroke = 0,
						Visible = function()
							const m = member()
							return m ~= nil and m.Leader
						end,
						Text = "Leader",
					}),
				},
			})
		end),
	})

	local function row(name: string, order: number, label: string, children: { any }): Frame
		return create("Frame")({
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, BUTTON),
			BackgroundTransparency = 1,
			CartoonLabel({
				Name = "Label",
				Box = UDim2.new(0.5, 0, 1, 0),
				TextSize = 16,
				XAlignment = Enum.TextXAlignment.Left,
				Text = label,
			}),
			create("Frame")({
				Name = "Control",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				children,
			}),
		}) :: Frame
	end

	const room = create("Frame")({
		Name = "Room",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		row("Access", 1, "Who can join", {
			CartoonButton({
				Name = "Toggle",
				Size = UDim2.fromOffset(130, BUTTON),
				TextSize = 16,
				Tone = function()
					return ACCESS_TONE[props.Access()] or Theme.Tone.Slate
				end,
				Enabled = editable,
				Text = function()
					return ACCESS_TEXT[props.Access()] or "Open"
				end,
				OnActivated = function()
					const current = table.find(ACCESS_ORDER, props.Access()) or 0
					props.OnAccess(ACCESS_ORDER[current % #ACCESS_ORDER + 1])
				end,
			}),
		}),
		row("MaxPlayers", 2, "Max players", {
			CartoonButton({
				Name = "Less",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(BUTTON, BUTTON),
				TextSize = 22,
				Tone = Theme.Tone.Teal,
				Enabled = function()
					return editable() and props.MaxPlayers() > math.max(#props.Members(), 1)
				end,
				Text = "-",
				OnActivated = function()
					props.OnMaxPlayers(props.MaxPlayers() - 1)
				end,
			}),
			CartoonLabel({
				Name = "Count",
				LayoutOrder = 2,
				Box = UDim2.fromOffset(28, BUTTON),
				TextSize = 22,
				Text = function()
					return tostring(props.MaxPlayers())
				end,
			}),
			CartoonButton({
				Name = "More",
				LayoutOrder = 3,
				Size = UDim2.fromOffset(BUTTON, BUTTON),
				TextSize = 22,
				Tone = Theme.Tone.Teal,
				Enabled = function()
					return editable() and props.MaxPlayers() < maxSize
				end,
				Text = "+",
				OnActivated = function()
					props.OnMaxPlayers(props.MaxPlayers() + 1)
				end,
			}),
		}),
		CartoonButton({
			Name = "Start",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, BUTTON + 8),
			TextSize = 22,
			Outline = Theme.Outline.Thick,
			Tone = Theme.Tone.Green,
			Visible = function()
				return props.IsLeader() and not starting()
			end,
			Text = "Start",
			OnActivated = props.OnStart,
		}),
		-- leader: abort the countdown (dark mustard, never red)
		CartoonButton({
			Name = "Cancel",
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, BUTTON),
			TextSize = 20,
			Outline = Theme.Outline.Thick,
			Tone = Theme.ToneOf(Color3.fromHex("#B07A0C")),
			Visible = function()
				return starting() and props.IsLeader() and props.CanCancel ~= nil and props.CanCancel()
			end,
			Text = "Cancel",
			OnActivated = function()
				if props.OnCancel then
					props.OnCancel()
				end
			end,
		}),
		CartoonLabel({
			Name = "Status",
			LayoutOrder = 6,
			Box = UDim2.new(1, 0, 0, 36),
			TextSize = 18,
			Wrapped = true,
			Color = function()
				return if starting() then Theme.Color.Green else Theme.Color.Text
			end,
			Visible = function()
				return starting() or not props.IsLeader()
			end,
			Text = function()
				const left = props.Countdown()
				if left ~= nil then
					return if left > 0 then `Starting in {math.ceil(left)}...` else "Here we go!"
				end
				return "Waiting for the leader..."
			end,
		}),
	})

	const settings = create("Frame")({
		Name = "Settings",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -(LEFT + GAP), 1, -(FOOT + 4)),
		BackgroundTransparency = 1,
		room,
	})

	const foot = create("Frame")({
		Name = "Foot",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FOOT),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		CartoonButton({
			Name = "Invite",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(150, BUTTON),
			TextSize = 18,
			Outline = Theme.Outline.Thick,
			Tone = Theme.Tone.Teal,
			Visible = function()
				return inviteMode() and props.IsLeader()
			end,
			Enabled = function()
				return not starting()
			end,
			Text = "Invite players",
			OnActivated = function()
				if props.OnInvite then
					props.OnInvite()
				end
			end,
		}),
		CartoonButton({
			Name = "Leave",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(96, BUTTON),
			TextSize = 18,
			Outline = Theme.Outline.Thick,
			Tone = Theme.Tone.Slate,
			Visible = inviteMode,
			Enabled = function()
				return not starting()
			end,
			Text = "Leave",
			OnActivated = function()
				if props.OnLeave then
					props.OnLeave()
				end
			end,
		}),
		CartoonLabel({
			Name = "Hint",
			LayoutOrder = 3,
			Box = function()
				if not inviteMode() then
					return UDim2.new(1, 0, 1, 0)
				end
				const used = 96 + 8 + (if props.IsLeader() then 150 + 8 else 0)
				return UDim2.new(1, -used, 1, 0)
			end,
			TextSize = Theme.MinTextSize,
			Wrapped = true,
			Transparency = 0.25,
			Text = function()
				return if inviteMode()
					then "Step on a free pad to take your squad there"
					else "Step off the platform to leave"
			end,
		}),
	})

	return LobbyWindow({
		Name = "SquadSetup",
		Title = "Squad",
		Icon = "Ui/friends",
		Size = Vector2.new(WIDTH, HEIGHT),
		Visible = props.Visible,
		Scale = props.Scale,
		OnClose = props.OnClose,
		Children = {
			slotList,
			settings,
			foot,
		},
	})
end
