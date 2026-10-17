--!strict
-- The owner's Studio Sounds (TASK-443): a Content.Sounds row with Id "" and a Studio name plays the SoundId of the Sound
-- of that name under ReplicatedStorage.Assets.SFX. Found by name in every subfolder (TASK-445 reorganises the folder
-- into subfolders), exact name first, then case-insensitive. A hit is cached for the session; a miss is searched again
-- at most every RETRY s (the folder may stream in late), so a silent row never scans the tree on every Play.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

const RETRY = 5 -- s between two searches of a name that was not found

const Studio = {}

const hits: { [string]: string } = {}
const missedAt: { [string]: number } = {}

local function folder(): Instance?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	return if assets ~= nil then assets:FindFirstChild("SFX") else nil
end

-- The Sound named `name` anywhere under Assets.SFX (nil = not there yet)
function Studio.Find(name: string): Sound?
	const root = folder()
	if root == nil then
		return nil
	end
	const lower = string.lower(name)
	local loose: Sound? = nil
	for _, instance in root:GetDescendants() do
		if not instance:IsA("Sound") then
			continue
		end
		if instance.Name == name then
			return instance
		end
		if loose == nil and string.lower(instance.Name) == lower then
			loose = instance
		end
	end
	return loose
end

-- rbxassetid of that Sound, nil when it is missing or has no SoundId
function Studio.IdOf(name: string): string?
	const cached = hits[name]
	if cached ~= nil then
		return cached
	end
	const last = missedAt[name]
	if last ~= nil and os.clock() - last < RETRY then
		return nil
	end
	const sound = Studio.Find(name)
	const id = if sound ~= nil then sound.SoundId else ""
	if id == "" then
		missedAt[name] = os.clock()
		return nil
	end
	hits[name] = id
	missedAt[name] = nil
	return id
end

return table.freeze(Studio)
