--!strict
-- InvitePopup: squad invite card of the lobby (user request 2026-10-11), cartoon kit (AST-091), mobile first.
-- A Cream card at the top centre (340 x 128 at Scale 1, under the Roblox top bar with CoreUISafeInsets): avatar head
-- shot, "<name> invited you to their squad!", Accept (Green) and Decline (Slate), 44 px buttons. Pops in when `Invite`
-- returns an invite, shrinks away when it returns nil. Pure: only props; the caller answers PartyRespond.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local UiScale = require(script.Parent.UiScale)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Invite = {
	UserId: number,
	Name: string,
}

export type Props = {
	Invite: () -> Invite?,
	OnAccept: () -> (),
	OnDecline: () -> (),
	Scale: (() -> number)?,
}

const WIDTH = 340
const HEIGHT = 128
const AVATAR = 48
const BUTTON = 44

return function(props: Props): Frame
	const shown = function(): boolean
		return props.Invite() ~= nil
	end
	-- keeps the last invite on screen while the card shrinks away
	const last = source({ UserId = 0, Name = "" } :: Invite)
	effect(function()
		const invite = props.Invite()
		if invite then
			last(invite)
		end
	end)
	const pop = Motion.Pop(shown)
	const scale = function(): number
		return (if props.Scale then math.max(math.min(props.Scale(), UiScale.Current()), Theme.Scale.Min) else 1) * pop()
	end

	return create("Frame")({
		Name = "InvitePopup",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Visible = function()
			return pop() > 0.01
		end,
		createRaw("UIScale")({ Scale = scale }),

		CartoonPanel({
			Name = "Card",
			Size = UDim2.fromScale(1, 1),
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Padding = 10,
			Children = {
				create("ImageLabel")({
					Name = "Avatar",
					Size = UDim2.fromOffset(AVATAR, AVATAR),
					BackgroundColor3 = Theme.Color.Mustard,
					Image = function()
						const userId = last().UserId
						return if userId > 0 then `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150` else ""
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				}),
				CartoonLabel({
					Name = "Text",
					Position = UDim2.fromOffset(AVATAR + 10, 0),
					Box = UDim2.new(1, -(AVATAR + 10), 0, AVATAR),
					TextSize = 18,
					Wrapped = true,
					XAlignment = Enum.TextXAlignment.Left,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Text = function()
						return `{last().Name} invited you to their squad!`
					end,
				}),
				CartoonButton({
					Name = "Accept",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(0.5, -5, 0, BUTTON),
					TextSize = 18,
					Outline = Theme.Outline.Thick,
					Tone = Theme.Tone.Green,
					Enabled = shown,
					Text = "Accept",
					OnActivated = props.OnAccept,
				}),
				CartoonButton({
					Name = "Decline",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.fromScale(1, 1),
					Size = UDim2.new(0.5, -5, 0, BUTTON),
					TextSize = 18,
					Outline = Theme.Outline.Thick,
					Tone = Theme.Tone.Slate,
					Enabled = shown,
					Text = "Decline",
					OnActivated = props.OnDecline,
				}),
			},
		}),
	}) :: Frame
end
