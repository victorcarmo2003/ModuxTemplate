--!strict
-- SquadSetup on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport, with a fake server:
-- Who can join / Max players answer after "Latency" s; the two setup stages (size, who can join) run as in the lobby; Start runs a 5 s countdown and goes back (as in Studio).
-- "Leader" off shows the member view; "Members" sets how many stand on the platform. "Invite" = an invite squad (Play ->
-- Create Squad): Ready / Not ready tags, the members' Ready button, Invite players / Leave in the foot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local SquadSetup = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Leader: () -> boolean,
	Members: () -> number,
	Latency: () -> number,
	Invite: () -> boolean,
}

const PEOPLE: { { UserId: number, Name: string } } = {
	{ UserId = 1, Name = "Roblox" },
	{ UserId = 156, Name = "builderman" },
	{ UserId = 261, Name = "Shedletsky" },
	{ UserId = 1311, Name = "HotdogFan_42" },
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02),
		Leader = true,
		Members = UILabs.Slider(2, 1, 4, 1),
		Latency = UILabs.Slider(0.3, 0, 3, 0.1),
		Invite = false,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const access = source("Setup")
	const stage = source(1)
	const maxPlayers = source(4)
	const startAt = source(0)
	const now = source(os.clock())
	const ready = source(false)

	const threads: { thread } = {}
	local alive = true
	cleanup(function()
		alive = false
		for _, thread in threads do
			if coroutine.status(thread) == "suspended" then
				task.cancel(thread)
			end
		end
	end)
	table.insert(
		threads,
		task.spawn(function()
			while alive do
				now(os.clock())
				task.wait(0.1)
			end
		end)
	)
	local function later(callback: () -> ())
		table.insert(threads, task.delay(controls.Latency(), callback))
	end

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Teal,
		BackgroundTransparency = 0.6,
		ClipsDescendants = true,

		SquadSetup({
			Visible = function()
				return true
			end,
			Platform = function()
				return 2
			end,
			Members = function()
				const list: { SquadSetup.Member } = {}
				const leader = controls.Leader()
				for index = 1, math.floor(controls.Members()) do
					const person = PEOPLE[index]
					const me = index == (if leader then 1 else 2)
					table.insert(list, {
						UserId = person.UserId,
						Name = if me then `{person.Name} (you)` else person.Name,
						Leader = index == 1,
						Me = me,
						Ready = if controls.Invite() then (if me then ready() else index % 2 == 1) else nil,
					})
				end
				return list
			end,
			IsLeader = controls.Leader,
			Access = access,
			Stage = function()
				return if access() == "Setup" and controls.Leader() then stage() else 3
			end,
			OnCount = function(count: number)
				maxPlayers(count)
				if count == 1 then
					access("Closed")
				else
					stage(2)
				end
			end,
			OnBack = function()
				stage(1)
			end,
			MaxPlayers = function()
				return math.max(maxPlayers(), math.floor(controls.Members()))
			end,
			MaxSize = 4,
			Countdown = function()
				const at = startAt()
				if at == 0 then
					return nil
				end
				return math.max(at - now(), 0)
			end,
			CanStart = function()
				return startAt() == 0
			end,
			OnAccess = function(value: string)
				later(function()
					access(value)
				end)
			end,
			OnMaxPlayers = function(count: number)
				later(function()
					maxPlayers(math.clamp(count, 1, 4))
				end)
			end,
			OnStart = function()
				startAt(os.clock() + 5)
				table.insert(
					threads,
					task.delay(6, function()
						startAt(0)
					end)
				)
			end,
			OnClose = function()
				print("[SquadSetup story] close")
			end,
			Scale = controls.Scale,
			Invite = controls.Invite,
			Ready = ready,
			OnReady = function(on: boolean)
				later(function()
					ready(on)
				end)
			end,
			OnInvite = function()
				print("[SquadSetup story] invite players")
			end,
			OnLeave = function()
				print("[SquadSetup story] leave")
			end,
		}),
	})
end)
