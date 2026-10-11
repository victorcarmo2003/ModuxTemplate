--!strict
-- LoadingScreen on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport. "Auto" fills the bar
-- by itself like a real join (steps with pauses); otherwise the Progress slider drives it. "Shown" off lifts the
-- curtain. Tips and texts are the real ones (ReplicatedFirst Loading/Tips), with a fallback list outside a place.
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local LoadingScreen = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

type Controls = {
	PhoneFrame: () -> boolean,
	Shown: () -> boolean,
	Auto: () -> boolean,
	Progress: () -> number,
}

type Texts = { Title: string, Tagline: string, Tips: { string }, Status: { [string]: string } }

const FALLBACK: Texts = {
	Title = "SELL HOTDOGS",
	Tagline = "Hot dogs by day. Keep the light on by night.",
	Tips = { "A short line is a happy line.", "Clean tables bring tips. Dirty tables bring nobody." },
	Status = { Game = "Rolling the cart to the corner...", Voices = "Rehearsing the phone call...", Done = "Ready!" },
}
const STEPS = { "Game", "Kit", "Assets", "Voices", "Crew", "Done" }

local function texts(): Texts
	const folder = ReplicatedFirst:FindFirstChild("client")
	const loading = if folder ~= nil then folder:FindFirstChild("Loading") else nil
	const module = if loading ~= nil then loading:FindFirstChild("Tips") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return FALLBACK
	end
	const ok, result = pcall(function(): Texts
		return (require :: any)(module)
	end)
	return if ok and type(result) == "table" then result else FALLBACK
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		PhoneFrame = true,
		Shown = true,
		Auto = true,
		Progress = UILabs.Slider(0.35, 0, 1, 0.01),
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)
	const copy = texts()
	const auto = source(0)
	const started = os.clock()
	const connection = RunService.Heartbeat:Connect(function()
		-- 0 -> 1 over ~9 s in uneven steps, then loops
		const t = (os.clock() - started) % 11
		const value = math.clamp(t / 9, 0, 1)
		auto(math.floor(value * 6) / 6 + (value % (1 / 6)) * 0.3)
	end)
	cleanup(function()
		connection:Disconnect()
	end)

	const progress = function(): number
		return if controls.Auto() then auto() else controls.Progress()
	end
	const status = function(): string
		const step = STEPS[math.clamp(math.floor(progress() * #STEPS) + 1, 1, #STEPS)]
		return copy.Status[step] or "Loading..."
	end

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

			LoadingScreen({
				Progress = progress,
				Status = status,
				Tips = copy.Tips,
				Title = copy.Title,
				Tagline = copy.Tagline,
				Shown = controls.Shown,
				TipTime = 3,
			}),
		}),
	})
end)
