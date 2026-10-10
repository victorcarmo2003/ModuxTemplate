--!strict
-- SkipPill on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport. Press and hold the pill
-- (mouse or touch) for "Hold" seconds to cast the vote, as CutsceneController does; the count adds the own vote
-- like the server would. "Mock jump" draws the stock mobile jump button area to check the pill clears it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local SkipPill = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

type Controls = {
	PhoneFrame: () -> boolean,
	MockJump: () -> boolean,
	Visible: () -> boolean,
	Others: () -> number,
	Connected: () -> number,
	Hold: () -> number,
	Key: () -> string,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		PhoneFrame = true,
		MockJump = true,
		Visible = true,
		Others = UILabs.Slider(0, 0, 3, 1), -- votes of the mates
		Connected = UILabs.Slider(3, 1, 4, 1),
		Hold = UILabs.Slider(0.6, 0.1, 2, 0.1),
		Key = UILabs.Choose({ "", "E", "X" }),
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)
	const voted = source(false)
	const progress = source(0)
	local holdStart: number? = nil

	const connection = RunService.Heartbeat:Connect(function()
		const start = holdStart
		if start == nil or voted() then
			return
		end
		const value = (os.clock() - start) / math.max(controls.Hold(), 0.05)
		if value >= 1 then
			holdStart = nil
			progress(0)
			voted(true)
		else
			progress(value)
		end
	end)
	cleanup(function()
		connection:Disconnect()
	end)

	const needed = function(): number
		return math.ceil(0.5 * controls.Connected())
	end
	const votes = function(): number
		return math.min(controls.Others() + (if voted() then 1 else 0), 4)
	end

	const pill = SkipPill({
		Visible = controls.Visible,
		Votes = votes,
		Needed = needed,
		Voted = voted,
		Progress = progress,
		KeyLabel = controls.Key,
		OnPress = function()
			if not voted() then
				holdStart = os.clock()
			end
		end,
		OnRelease = function()
			holdStart = nil
			progress(0)
		end,
	})

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		create("Frame")({
			Name = "Screen",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				return if controls.PhoneFrame() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
			end,
			BackgroundColor3 = Color3.fromHex("#1B2440"),
			ClipsDescendants = true,
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),

			-- Stock small-screen jump button area (70 px at 95 px from the right, 90 px from the bottom)
			create("Frame")({
				Name = "MockJump",
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(1, -95, 1, -90),
				Size = UDim2.fromOffset(70, 70),
				BackgroundColor3 = Theme.Color.Text,
				BackgroundTransparency = 0.7,
				Visible = controls.MockJump,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),

			create("TextButton")({
				Name = "ResetVote",
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(120, 44),
				BackgroundColor3 = Theme.Color.Teal,
				FontFace = Theme.Font.Body,
				TextSize = 16,
				TextColor3 = Theme.Color.Text,
				Text = "Reset vote",
				Activated = function()
					voted(false)
					progress(0)
				end,
			}),

			pill,
		}),
	})
end)
