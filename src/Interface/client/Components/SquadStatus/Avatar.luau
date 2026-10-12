--!strict
-- Avatar: round head shot of a player (user request 2026-10-12), cartoon kit (AST-091).
-- Players:GetUserThumbnailAsync(userId, HeadShot, Size100x100), one request per user id for the whole session
-- (module cache), run aside (it yields). While it loads, or when it fails, a silhouette (head + shoulders) shows; a
-- failed or not-ready thumbnail is asked again after RETRY s. The ring (UIStroke, Ink outline outside it) is the
-- caller's colour. Pure: only props.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)

const create = Vide.create
const source = Vide.source
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	UserId: () -> number,
	-- diameter px at UI scale 1
	Size: number,
	-- ring colour; nil colour = Slate
	Ring: (() -> Color3)?,
	Name: string?,
	LayoutOrder: number?,
}

const RETRY = 4 -- s before a failed thumbnail is asked again

-- userId -> content url of a ready head shot
const cache: { [number]: string } = {}
const pending: { [number]: boolean } = {}
const failedAt: { [number]: number } = {}
-- bumped when a thumbnail arrives (or may be asked again): the images re-read the cache
const version = source(0)

local function request(userId: number)
	if userId <= 0 or cache[userId] ~= nil or pending[userId] then
		return
	end
	const failed = failedAt[userId]
	if failed ~= nil and os.clock() - failed < RETRY then
		return
	end
	pending[userId] = true
	task.spawn(function()
		const ok, content, ready = pcall(function(): (string, boolean)
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		pending[userId] = nil
		if ok and ready and type(content) == "string" and content ~= "" then
			failedAt[userId] = nil
			cache[userId] = content
			version(version() + 1)
			return
		end
		failedAt[userId] = os.clock()
		task.delay(RETRY, function()
			version(version() + 1) -- the visible avatars ask again
		end)
	end)
end

-- Image of a user id; "" while loading or failed. Reads `version`, so it re-runs when a thumbnail lands.
local function imageOf(userId: number): string
	version()
	const content = cache[userId]
	if content ~= nil then
		return content
	end
	request(userId)
	return ""
end

return function(props: Props): Frame
	const loaded = function(): boolean
		return imageOf(props.UserId()) ~= ""
	end
	return create("Frame")({
		Name = props.Name or "Avatar",
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(props.Size, props.Size),
		BackgroundColor3 = Theme.Color.Slate,
		ClipsDescendants = true,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 3,
			Color = function()
				return if props.Ring then props.Ring() else Theme.Color.Slate
			end,
		}),

		-- silhouette while there is no picture
		create("Frame")({
			Name = "Head",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.18),
			Size = UDim2.fromScale(0.36, 0.36),
			BackgroundColor3 = Theme.Color.Cream,
			Visible = function()
				return not loaded()
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),
		create("Frame")({
			Name = "Shoulders",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.58),
			Size = UDim2.fromScale(0.7, 0.7),
			BackgroundColor3 = Theme.Color.Cream,
			Visible = function()
				return not loaded()
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),

		create("ImageLabel")({
			Name = "Picture",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = function()
				return imageOf(props.UserId())
			end,
			Visible = loaded,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),
	}) :: Frame
end
