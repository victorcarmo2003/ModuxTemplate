--!strict
-- SquadPanel on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport, with a fake server:
-- "Create Squad" makes you leader; Invite adds the player after "Latency" s (as if they accepted); kick / leave /
-- start answer the same way. "Leader" off shows the member view (you are not the leader).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local SquadPanel = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Leader: () -> boolean,
	Latency: () -> number,
}

const ME = 1
const OTHERS: { { UserId: number, Name: string } } = {
	{ UserId = 156, Name = "builderman" },
	{ UserId = 261, Name = "Shedletsky" },
	{ UserId = 1311, Name = "HotdogFan_42" },
	{ UserId = 2032, Name = "MustardMaster" },
	{ UserId = 4040, Name = "NightOwlCook" },
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Leader = true,
		Latency = UILabs.Slider(0.5, 0, 3, 0.1),
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const inSquad = source(false)
	const members = source({} :: { number })
	const invited = source({} :: { [number]: boolean })
	const busy = source(false)
	const starting = source(false)

	const threads: { thread } = {}
	cleanup(function()
		for _, thread in threads do
			if coroutine.status(thread) == "suspended" then
				task.cancel(thread)
			end
		end
	end)
	local function later(callback: () -> ())
		busy(true)
		table.insert(
			threads,
			task.delay(controls.Latency(), function()
				callback()
				busy(false)
			end)
		)
	end
	local function nameOf(userId: number): string
		if userId == ME then
			return "You"
		end
		for _, other in OTHERS do
			if other.UserId == userId then
				return other.Name
			end
		end
		return tostring(userId)
	end
	local function leaderId(): number
		return if controls.Leader() then ME else (members()[2] or ME)
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

		SquadPanel({
			Visible = function()
				return true
			end,
			InSquad = inSquad,
			Members = function(): { SquadPanel.Member }
				const list: { SquadPanel.Member } = {}
				for _, userId in members() do
					table.insert(list, {
						UserId = userId,
						Name = nameOf(userId),
						Leader = userId == leaderId(),
						Me = userId == ME,
					})
				end
				return list
			end,
			IsLeader = function()
				return leaderId() == ME
			end,
			Starting = starting,
			Candidates = function(): { SquadPanel.Candidate }
				const list: { SquadPanel.Candidate } = {}
				for _, other in OTHERS do
					if not table.find(members(), other.UserId) then
						table.insert(list, {
							UserId = other.UserId,
							Name = other.Name,
							Invited = invited()[other.UserId] == true,
						})
					end
				end
				return list
			end,
			Busy = busy,
			OnCreate = function()
				later(function()
					inSquad(true)
					members({ ME })
				end)
			end,
			OnInvite = function(userId: number)
				const copy = table.clone(invited())
				copy[userId] = true
				invited(copy)
				later(function()
					if not inSquad() then
						inSquad(true)
						members({ ME })
					end
					if #members() < 4 then
						const list = table.clone(members())
						table.insert(list, userId)
						members(list)
					end
				end)
			end,
			OnKick = function(userId: number)
				later(function()
					const list = table.clone(members())
					const at = table.find(list, userId)
					if at then
						table.remove(list, at)
					end
					members(list)
				end)
			end,
			OnLeave = function()
				later(function()
					inSquad(false)
					members({})
					invited({})
					starting(false)
				end)
			end,
			OnStart = function()
				later(function()
					starting(true)
				end)
			end,
			OnClose = function()
				print("[SquadPanel story] close")
			end,
			Scale = controls.Scale,
		}),
	})
end)
