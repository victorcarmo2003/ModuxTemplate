--!strict
-- Admin console UI (ConchUI). The key is bound only when AdminSettings.IsAllowed says so; that is a UX gate, the
-- real one is server-side (AdminService grants the Conch role and re-checks on every command).
--
-- "help" lives HERE (client), not on the server: Conch has no native help command, and a client-side command
-- can list every command the console really has (local ones plus the ones the server replicated, with args
-- built from their types) and does not depend on a round trip. DevService commands come from the server
-- command "dev-help" (returns text) and are appended.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local AdminArguments = require(ReplicatedStorage.shared.Admin.AdminArguments)
local AdminSettings = require(ReplicatedStorage.shared.Admin.AdminSettings)
local ConchUI = require(ReplicatedStorage.Packages.ConchUI)
local conch = require(ReplicatedStorage.Packages.Conch)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)

const TABLET_WATCH = 60 -- s the Tablets changes are logged after "tablet-client"

const _ARGUMENTS = AdminArguments -- keeps the type registration alive

const AdminController = Modux.Controller("AdminController", { Priority = 50 })

local function out(text: string)
	for _, line in string.split(text, "\n") do
		conch.log("normal", line)
	end
end

-- "<name>" required, "[name]" optional (union with nil), "[name...]" variadic, literal arguments as plain words.
local function argumentText(argument: any): string
	const name = tostring(argument.name or "arg")
	if argument.varargs then
		return `[{name}...]`
	end
	const kind: any = argument.type
	if kind ~= nil then
		if kind.kind == "literal" then
			return tostring(kind.value)
		end
		if kind.kind == "union" then
			for _, field in kind.fields do
				if field.kind == "literal" and field.value == nil then
					return `[{name}]`
				end
			end
		end
	end
	return `<{name}>`
end

local function signature(name: string, command: any): string
	const parts = { name }
	for _, argument in command.arguments or {} do
		table.insert(parts, argumentText(argument))
	end
	return table.concat(parts, " ")
end

-- One line per overload.
local function signatures(name: string, info: any): { string }
	const result = {}
	const kind: any = info.type
	if kind.kind == "intersection" then
		for _, command in kind.fields do
			table.insert(result, signature(name, command))
		end
	else
		table.insert(result, signature(name, kind))
	end
	return result
end

local function sortedNames(): { string }
	const names = {}
	for name in conch.console.commands do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- DevService list, via the server command "dev-help". Empty when the server did not replicate it.
local function devHelp(): string?
	const info = conch.console.commands["dev-help"]
	if info == nil then
		return nil
	end
	const ok, text = pcall(info.callback)
	if ok and type(text) == "string" then
		return text
	end
	return nil
end

local function showCommand(name: string)
	const info = conch.console.commands[name]
	if info ~= nil then
		conch.log("normal", `{name}: {info.description or ""}`)
		for _, line in signatures(name, info) do
			conch.log("normal", `  {line}`)
		end
		return
	end
	-- not a console command: maybe a DevService one ("help day"); show its line from the dev list
	const dev = devHelp()
	if dev ~= nil then
		const lowered = string.lower(name)
		for _, line in string.split(dev, "\n") do
			const trimmed = string.lower((string.gsub(line, "^%s+", "")))
			if string.sub(trimmed, 1, #lowered) == lowered then
				out(line)
				return
			end
		end
	end
	conch.log("error", `no command "{name}" (type help for the list)`)
end

local function showAll()
	conch.log("normal", "Commands (help <command> for details):")
	for _, name in sortedNames() do
		const info = conch.console.commands[name]
		for _, line in signatures(name, info) do
			conch.log("normal", `  {line} - {info.description or ""}`)
		end
	end
	const dev = devHelp()
	if dev ~= nil then
		conch.log("normal", "")
		conch.log("normal", 'Dev commands (run as "dev <command> [args]"):')
		out(dev)
	end
end

local function registerHelp()
	conch.register("help", {
		permissions = {},
		description = "List all commands with args and description; 'help <command>' shows one",
		arguments = function()
			return conch.args.opt(conch.args.string("command", "Command name (optional)"))
		end,
		callback = function(name: string?)
			if name ~= nil and name ~= "" then
				showCommand(name)
			else
				showAll()
			end
		end,
	})
end

-- What this client sees of the order talk (owner 2026-10-22: the close-up and the card never showed in the published
-- game while the server said Talking): the Tablets records it holds, the talk card's gui, what hides it; then every
-- Tablets change for TABLET_WATCH s
local function tabletRecordLine(index: number, record: any): string
	const me = Players.LocalPlayer.UserId
	return `TAB-{index} {record.State} npc {record.Npc} user {record.User} (mine {tostring(record.User == me)}) `
		.. `t {string.format("%.1f", record.StartedAt - workspace:GetServerTimeNow())}..{string.format(
			"%.1f",
			record.EndsAt - workspace:GetServerTimeNow()
		)} s`
end

local tabletWatch: { any }? = nil
local function tabletReport()
	const me = Players.LocalPlayer
	conch.log(
		"normal",
		`me {me.UserId}, TalkCloseUp {tostring(me:GetAttribute("TalkCloseUp"))}, cinematic {tostring(Cinematic.Active())}`
	)
	local any = false
	for index, record in Restaurant.Tablets:entries() do
		any = true
		conch.log("normal", tabletRecordLine(index, record))
	end
	if not any then
		conch.log("warn", "no Tablets record on this client")
	end
	const gui = me:FindFirstChildOfClass("PlayerGui")
	const dialog = if gui ~= nil then gui:FindFirstChild("TabletDialog", true) else nil
	if dialog == nil then
		conch.log("warn", "no TabletDialog gui (TabletController did not mount it)")
	else
		local shown = 0
		for _, item in dialog:GetDescendants() do
			if item:IsA("GuiObject") and item.Visible then
				shown += 1
			end
		end
		const enabled = if dialog:IsA("ScreenGui") then tostring(dialog.Enabled) else dialog.ClassName
		conch.log("normal", `TabletDialog in {dialog.Parent and dialog.Parent.Name}, enabled {enabled}, {shown} visible objects`)
	end
	if tabletWatch ~= nil then
		return
	end
	const watch = {
		Restaurant.Tablets:onAdded(function(index, record)
			conch.log("info", `+ {tabletRecordLine(index, record)}`)
		end),
		Restaurant.Tablets:onChanged(function(index, record)
			conch.log("info", `~ {tabletRecordLine(index, record)}`)
		end),
	}
	tabletWatch = watch
	conch.log("normal", `logging Tablets changes for {TABLET_WATCH} s`)
	task.delay(TABLET_WATCH, function()
		for _, connection in watch do
			connection:disconnect()
		end
		tabletWatch = nil
		conch.log("normal", "Tablets log over")
	end)
end

AdminController:OnStart(function(_self)
	if not AdminSettings.IsAllowed(Players.LocalPlayer) then
		return
	end
	conch.initiate_default_lifecycle()
	registerHelp()
	conch.register("tablet-client", {
		permissions = {},
		description = "What this client sees of the order talk (Tablets records, the talk card); logs changes for 60 s",
		arguments = function() end,
		callback = tabletReport,
	})
	ConchUI.bind_to(AdminSettings.ToggleKey) -- mounts the UI (sets conch.console.output)
	conch.log("info", "Admin console ready. Type help to list the commands.")
end)

return AdminController
