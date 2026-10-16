--!strict
-- Admin console (Conch) server side. Access: AdminSettings.IsAllowed (Studio or whitelisted UserId), granted as the
-- Conch "super-user" role on join and re-checked inside every callback. Conch itself only replicates commands to
-- users holding the permission, so a normal player never even sees the command list.
--
-- Commands:
--   dev <command> [args]   bridge to DevService (same commands, args and help as chat "/dev"); no logic here.
--   day / cash / gems / upgrade   typed shortcuts that forward to the same DevService commands.
--   dev-help               returns the DevService help text; the client-side "help" (AdminController) uses it.
--   showcase               opens the dev showcase panel (ShowcaseService; same gate: Studio dev mode + allowed admin).
--   anomaly <id> trigger|resolve|wrong|stop   forces / resolves / fails / stops one anomaly (ANM-###, key or night n).
--   scare <id>             plays a hallucination (key) or a sting ("sting:<sound key>") on your client.
--   tp, content            native and safe in production (no DevService needed).
--   giftclass <player|userId> <class>, giftgems <player|userId> <amount>   gifts through GiftService (TASK-352; owner
--                          request 2026-10-16, Provisional): a ProfileStore message, so it works in production and for
--                          offline UserIds. The one profile mutation here, owner-approved; nothing else writes profiles.
-- Policy: DevService only exists in Studio dev mode (PlaceService:IsDev). Published servers therefore expose only
-- the native commands; the bridge answers "dev commands are off". Do not add other Content/profile mutations here
-- without an architect decision.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AdminArguments = require(ReplicatedStorage.shared.Admin.AdminArguments)
local AdminSettings = require(ReplicatedStorage.shared.Admin.AdminSettings)
local Content = require(ReplicatedStorage.shared.Content)
local conch = require(ReplicatedStorage.Packages.Conch)
local Modux = require(ServerScriptService.server.Modux)

const ROLE = "super-user"
const PERMISSION = "admin"

const AdminService = Modux.Service("AdminService", {
	Require = { "PlayerService", "DevService", "ShowcaseService", "GiftService" },
	Priority = 50, -- below DevService (100): its OnStart has already loaded the commands when ours runs
})

local function executor(): Player?
	const context = conch.get_command_context()
	const player = context and context.executor.player
	if player and player.Parent == Players and AdminSettings.IsAllowed(player) then
		return player
	end
	return nil
end

local function fail(message: string)
	conch.log("error", message)
end

local function integer(value: any, min: number, max: number): number?
	if type(value) ~= "number" or value ~= value or value < min or value > max then
		return nil
	end
	return math.floor(value)
end

-- Runs a DevService command for the executor and mirrors the reply into the console.
function AdminService:RunDev(name: string, args: { string })
	const caller = executor()
	if not caller then
		return fail("not allowed")
	end
	const dev = self.Dependencies.DevService
	if not dev.Enabled then
		return fail("dev commands are off here (DevService runs only in Studio dev mode)")
	end
	if string.lower(name) == "help" then
		conch.log("normal", dev:Help())
		return
	end
	const ok, result = pcall(function(): string?
		return dev:Execute(name, args, caller)
	end)
	if ok then
		conch.log("success", result or "ok")
	else
		fail(tostring(result))
	end
end

-- Text of the DevService help, returned (not logged) so the client "help" command can merge it into its own list.
function AdminService:CommandDevHelp(): string
	if not executor() then
		fail("not allowed")
		return "not allowed"
	end
	const dev = self.Dependencies.DevService
	if not dev.Enabled then
		return "dev commands are off here (DevService runs only in Studio dev mode)"
	end
	return dev:Help()
end

-- Showcase commands: ShowcaseService checks dev mode and the whitelist again. It yields (night jumps), and the Conch
-- context is only valid inside the callback, so the executor is read first and the work runs in its own thread.
function AdminService:RunShowcase(action: string, id: string, arg: string)
	const caller = executor()
	if not caller then
		return fail("not allowed")
	end
	task.spawn(function()
		const ok, text = self.Dependencies.ShowcaseService:Run(caller, action, id, arg, 0)
		conch.log(if ok then "success" else "error", text)
	end)
end

function AdminService:CommandShowcase()
	const caller = executor()
	if not caller then
		return fail("not allowed")
	end
	const ok, text = self.Dependencies.ShowcaseService:Open(caller)
	conch.log(if ok then "success" else "error", text)
end

function AdminService:CommandTeleport(a: Player, b: Player?)
	const caller = executor()
	if not caller then
		return fail("not allowed")
	end
	const target = if b then a else caller
	const destination = if b then b else a
	const from = target.Character
	const to = destination.Character
	if not from or not to then
		return fail("character not found")
	end
	from:PivotTo(to:GetPivot())
	conch.log("success", `{target.Name} teleported to {destination.Name}`)
end

-- "name" or "123456" -> UserId: a player in this server by name / display name, a number as is, else a Roblox
-- username lookup. Yields.
local function resolveUserId(text: string): number?
	const number = tonumber(text)
	if number ~= nil and number > 0 and number % 1 == 0 then
		return number
	end
	const lower = string.lower(text)
	for _, player in Players:GetPlayers() do
		if string.lower(player.Name) == lower or string.lower(player.DisplayName) == lower then
			return player.UserId
		end
	end
	const ok, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(text)
	end)
	return if ok then userId else nil
end

-- giftclass / giftgems: the executor is read inside the Conch callback, the lookups and the send yield in a thread.
function AdminService:CommandGift(target: string, kind: "Class" | "Gems", key: string, amount: number)
	const caller = executor()
	if not caller then
		return fail("not allowed")
	end
	task.spawn(function()
		const userId = resolveUserId(target)
		if userId == nil then
			return fail(`no player or UserId "{target}"`)
		end
		const sent = self.Dependencies.GiftService:SendFree(userId, kind, key, amount, caller)
		if sent then
			const what = if kind == "Class" then key else `{amount} gems`
			conch.log("success", `gift sent to {userId}: {what} (delivered when their profile loads)`)
		else
			fail(`gift to {userId} not sent (DataStore busy or closing); try again`)
		end
	end)
end

function AdminService:CommandContent(kind: string, key: string)
	if not executor() then
		return fail("not allowed")
	end
	const tables: { [string]: any } = {
		item = Content.Items,
		ingredient = Content.Ingredients,
		class = Content.Classes,
	}
	const row = tables[kind].ByKey[key]
	if not row then
		return fail(`no {kind} "{key}"`)
	end
	conch.log("normal", `{key}: {row.Ref or "?"} {row.Name or ""} {row.Kind or ""}`)
end

function AdminService:Register()
	conch.register("dev", {
		permissions = { PERMISSION },
		description = "Run a DevService command (same as chat /dev). 'dev help' lists them",
		-- one signature (command + rest of the line as text): an overload of string vs string+any is ambiguous in Conch
		arguments = function()
			return conch.args.string("command"), conch.args.variadic(conch.args.string("arg"))
		end,
		callback = function(name: string, ...: any)
			const args: { string } = {}
			for _, value in { ... } do
				table.insert(args, tostring(value))
			end
			self:RunDev(name, args)
		end,
	})

	-- NOT named "help": the client registers the real "help" locally (AdminController). Same name here would
	-- overwrite it in the client globals when the server replicates.
	conch.register("dev-help", {
		permissions = { PERMISSION },
		description = "Return the DevService command list (used by help)",
		arguments = function() end,
		callback = function(): string
			return self:CommandDevHelp()
		end,
	})

	conch.register("day", {
		permissions = { PERMISSION },
		description = "Go to the Prep of day n (DevService: day)",
		arguments = function()
			return AdminArguments.Day("day", "Day number, 1 or more")
		end,
		callback = function(day: number)
			const value = integer(day, 1, 9999)
			if not value then
				return fail("day must be a whole number from 1 to 9999")
			end
			self:RunDev("day", { tostring(value) })
		end,
	})

	conch.register("cash", {
		permissions = { PERMISSION },
		description = "Add to the party cash, negative removes (DevService: cash)",
		arguments = function()
			return AdminArguments.Money("amount", "Money amount")
		end,
		callback = function(amount: number)
			const value = integer(amount, -AdminArguments.MaxMoney, AdminArguments.MaxMoney)
			if not value then
				return fail("amount out of range")
			end
			self:RunDev("cash", { tostring(value) })
		end,
	})

	conch.register("gems", {
		permissions = { PERMISSION },
		description = "Add gems to a player, negative removes (DevService: gems)",
		arguments = function()
			return AdminArguments.Money("amount", "Gem amount"), conch.args.opt(AdminArguments.Player("player"))
		end,
		callback = function(amount: number, target: Player?)
			const value = integer(amount, -AdminArguments.MaxMoney, AdminArguments.MaxMoney)
			if not value then
				return fail("amount out of range")
			end
			const args = { tostring(value) }
			if target then
				table.insert(args, target.Name)
			end
			self:RunDev("gems", args)
		end,
	})

	conch.register("upgrade", {
		permissions = { PERMISSION },
		description = "Upgrade dev command (DevService: upgrade [key] [level])",
		arguments = function()
			return conch.args.opt(AdminArguments.UpgradeKey("upgrade")), conch.args.opt(conch.args.number("level"))
		end,
		callback = function(key: string?, level: number?)
			const args: { string } = {}
			if key then
				table.insert(args, key)
			end
			if level then
				const value = integer(level, 0, 99)
				if not value then
					return fail("level must be a whole number from 0 to 99")
				end
				table.insert(args, tostring(value))
			end
			self:RunDev("upgrade", args)
		end,
	})

	conch.register("showcase", {
		permissions = { PERMISSION },
		description = "Open the dev showcase panel (anomalies, scares, mechanics); F9 toggles it",
		arguments = function() end,
		callback = function()
			self:CommandShowcase()
		end,
	})

	conch.register("anomaly", {
		permissions = { PERMISSION },
		description = "Showcase: anomaly <ANM-###|key|night> trigger|resolve|wrong|stop (dev mode only)",
		arguments = function()
			return conch.args.string("id", "ANM-###, anomaly key or night number"),
				conch.args.string("action", "trigger | resolve | wrong | stop")
		end,
		callback = function(id: string, action: string)
			const verb = string.lower(action)
			if verb ~= "trigger" and verb ~= "resolve" and verb ~= "wrong" and verb ~= "stop" then
				return fail("action must be trigger, resolve, wrong or stop")
			end
			-- "7" / "anm_007_walker" / "ANM-007" -> the Ref the catalog uses
			const found = (Content.Anomalies.ByKey :: any)[id]
			local ref = id
			if found ~= nil then
				ref = found.Ref
			else
				const number = tonumber(id)
				for _, row in Content.Anomalies.List do
					if row.Ref == string.upper(id) or (number ~= nil and row.Night == number) then
						ref = row.Ref
					end
				end
			end
			self:RunShowcase(verb, ref, "")
		end,
	})

	-- anm <key> [action]: the same as "anomaly" with every anomaly in the autocomplete (owner 2026-10-16)
	conch.register("anm", {
		permissions = { PERMISSION },
		description = "Trigger an anomaly from the list (autocomplete): anm <key> [trigger|resolve|wrong|stop]",
		arguments = function()
			return AdminArguments.AnomalyKey("anomaly"), conch.args.opt(AdminArguments.AnomalyAction("action"))
		end,
		callback = function(key: string, action: string?)
			const row = (Content.Anomalies.ByKey :: any)[key]
			if row == nil then
				return fail(`no anomaly "{key}"`)
			end
			self:RunShowcase(action or "trigger", row.Ref, "")
		end,
	})

	-- anomalies: the list to test, one line each (Ref, key, family, debut night)
	conch.register("anomalies", {
		permissions = { PERMISSION },
		description = "List every anomaly (Ref, key, family, debut night) to use with anm",
		arguments = function() end,
		callback = function()
			const lines: { string } = {}
			for _, row in Content.Anomalies.List do
				const family = (row :: any).Family
				table.insert(
					lines,
					`{row.Ref}  {row.Key}  {row.Name}  family {family or "-"}  night {row.Night}`
				)
			end
			conch.log("normal", table.concat(lines, "\n"))
		end,
	})

	-- arrivals [on|off]: pause / resume ordinary customers (anomaly customers still come)
	conch.register("arrivals", {
		permissions = { PERMISSION },
		description = "Pause / resume ORDINARY customers (anomaly customers still come); no argument toggles",
		arguments = function()
			return conch.args.opt(AdminArguments.ArrivalsState("state"))
		end,
		callback = function(state: string?)
			self:RunDev("arrivals", if state then { state } else {})
		end,
	})

	-- autorevive [on|off]: stand up 2 s after a faint, the night goes on (owner 2026-10-16)
	conch.register("autorevive", {
		permissions = { PERMISSION },
		description = "Revive yourself automatically 2 s after any faint (no lost night); no argument toggles",
		arguments = function()
			return conch.args.opt(AdminArguments.ArrivalsState("state"))
		end,
		callback = function(state: string?)
			self:RunDev("autorevive", if state then { state } else {})
		end,
	})

	conch.register("scare", {
		permissions = { PERMISSION },
		description = "Showcase: play a hallucination (fake_call, whisper...) or 'sting:<sound key>' on your client",
		arguments = function()
			return conch.args.string("id", "hallucination key or sting:<sound key>")
		end,
		callback = function(id: string)
			self:RunShowcase("scare", id, "")
		end,
	})

	conch.register("giftclass", {
		permissions = { PERMISSION },
		description = "Gift a class to a player (name or UserId, offline too); already owned = its gem price",
		arguments = function()
			return AdminArguments.Recipient("player", "Player name or UserId"), AdminArguments.ClassKey("class")
		end,
		callback = function(target: string, key: string)
			if Content.Classes.ByKey[key] == nil then
				return fail(`no class "{key}"`)
			end
			self:CommandGift(target, "Class", key, 0)
		end,
	})

	conch.register("giftgems", {
		permissions = { PERMISSION },
		description = "Gift gems to a player (name or UserId, offline too)",
		arguments = function()
			return AdminArguments.Recipient("player", "Player name or UserId"), AdminArguments.Money("amount", "Gem amount")
		end,
		callback = function(target: string, amount: number)
			const value = integer(amount, 1, AdminArguments.MaxGiftGems)
			if not value then
				return fail(`amount must be a whole number from 1 to {AdminArguments.MaxGiftGems}`)
			end
			self:CommandGift(target, "Gems", "", value)
		end,
	})

	conch.register("tp", {
		permissions = { PERMISSION },
		description = "Teleport to a player, or one player to another",
		arguments = function()
			return conch.args.overload({
				{ AdminArguments.Player("to") } :: { any },
				{ AdminArguments.Player("target"), AdminArguments.Player("to") } :: { any },
			})
		end,
		callback = function(a: Player, b: Player?)
			self:CommandTeleport(a, b)
		end,
	})

	conch.register("content", {
		permissions = { PERMISSION },
		description = "Show a Content row (read only): content item|ingredient|class <key>",
		arguments = function()
			return conch.args.overload({
				{ conch.args.literal("item"), AdminArguments.ItemKey("key") } :: { any },
				{ conch.args.literal("ingredient"), AdminArguments.IngredientKey("key") } :: { any },
				{ conch.args.literal("class"), AdminArguments.ClassKey("key") } :: { any },
			})
		end,
		callback = function(kind: string, key: string)
			self:CommandContent(kind, key)
		end,
	})
end

AdminService:OnInit(function(self)
	conch.initiate_default_lifecycle()

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player: Player)
		if AdminSettings.IsAllowed(player) then
			conch.give_roles(conch.get_user(player), ROLE)
		end
	end)

	self:Register()
end)

return AdminService
