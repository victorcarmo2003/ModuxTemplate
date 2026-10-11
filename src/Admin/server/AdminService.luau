--!strict
-- Admin console (Conch) server side. Access: AdminSettings.IsAllowed (Studio or whitelisted UserId), granted as the
-- Conch "super-user" role on join and re-checked inside every callback. Conch itself only replicates commands to
-- users holding the permission, so a normal player never even sees the command list.
--
-- Commands:
--   dev <command> [args]   bridge to DevService (same commands, args and help as chat "/dev"); no logic here.
--   day / cash / gems / upgrade   typed shortcuts that forward to the same DevService commands.
--   tp, content            native and safe in production (no DevService needed).
-- Policy: DevService only exists in Studio dev mode (PlaceService:IsDev). Published servers therefore expose only
-- the native commands; the bridge answers "dev commands are off". Do not add Content/profile mutations here
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
	Require = { "PlayerService", "DevService" },
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
		arguments = function()
			return conch.args.overload({
				{ conch.args.string("command") } :: { any },
				{ conch.args.string("command"), conch.args.variadic(conch.args.any("arg")) } :: { any },
			})
		end,
		callback = function(name: string, ...: any)
			const args: { string } = {}
			for _, value in { ... } do
				table.insert(args, tostring(value))
			end
			self:RunDev(name, args)
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
