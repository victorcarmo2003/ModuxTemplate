--!strict
-- Dev commands (board TASK-042; tests/wave-1.md §0.4; architecture.md §1 dev mode). Run place in Studio only:
-- when PlaceService:IsDev() is false this service returns at the top of OnInit and nothing is created.
-- Entry without Lync, two ways:
--   Command Bar (Server view): require(game.ServerScriptService.server.Dev.DevService).Run("day", 4)
--   Chat: /dev <command> <args>   (TextChatCommand created on the server; "/dev help" lists the commands)
-- Commands come from Commands/*.luau (contract in Api.luau), discovered at OnStart: new command = new file.
-- The Command Bar may get its own copy of this module (separate require cache), so Run forwards through a
-- BindableFunction parented to this script; with dev mode off there is no bridge and Run errors.
-- Replies go to the server Output only (Provisional, TASK-042: no Net entry for dev feedback).
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")
local Api = require(script.Api)
local Modux = require(ServerScriptService.server.Modux)
local ModuxModules = require(ServerScriptService.server.Modux.Modules)

const BRIDGE = "DevBridge"
const CHAT_COMMAND = "DevCommand"
const ALIAS = "/dev"
const PREFIX = "[Dev]"
const HELP = "help"

-- Booted instance in dev mode (nil in the Command Bar copy and when dev mode is off)
local live: any = nil

local function words(text: string): { string }
	const out = {}
	for word in string.gmatch(text, "%S+") do
		table.insert(out, word)
	end
	return out
end

local function log(message: string)
	print(`{PREFIX} {message}`)
end

local function findService(name: string): any
	for _, module in ModuxModules do
		if module.Name == name then
			return (require :: any)(module)
		end
	end
	error(`{PREFIX} service "{name}" is not in this build`, 2)
end

const DevService = Modux.Service("DevService", { Require = { "PlaceService" }, Priority = 100 })

function DevService:Setup()
	self.Enabled = false :: boolean
	self.Commands = {} :: { [string]: Api.Command }
	self.Order = {} :: { string }
end

function DevService:Add(command: Api.Command, source: string)
	const name = string.lower(command.Name)
	if name == HELP or self.Commands[name] ~= nil then
		warn(`{PREFIX} {source}: command "{name}" already exists, skipped`)
		return
	end
	self.Commands[name] = command
	table.insert(self.Order, name)
end

-- Requires every ModuleScript in Commands/ (sorted by name) and calls its factory. A broken file is warned and
-- skipped: one bad command must not take the others down.
function DevService:Load()
	const folder = script:FindFirstChild("Commands")
	if folder == nil then
		return
	end
	const context: Api.Context = { Get = findService, Log = log }
	const modules = folder:GetChildren()
	table.sort(modules, function(a: Instance, b: Instance): boolean
		return a.Name < b.Name
	end)
	for _, module in modules do
		if not module:IsA("ModuleScript") then
			continue
		end
		const ok, result = pcall(function(): { Api.Command }
			const factory = (require :: any)(module) :: Api.Module
			return factory(context)
		end)
		if not ok then
			warn(`{PREFIX} Commands/{module.Name} failed to load: {result}`)
			continue
		end
		for _, command in result do
			self:Add(command, `Commands/{module.Name}`)
		end
	end
	table.sort(self.Order)
end

function DevService:Help(): string
	const lines = { `commands ({ALIAS} <command> or DevService.Run("<command>", ...)):`, `  help - this list` }
	for _, name in self.Order do
		const command = self.Commands[name]
		table.insert(lines, `  {command.Usage} - {command.Help}`)
	end
	return table.concat(lines, "\n")
end

-- Runs one command and prints its reply. Errors propagate (unknown command, bad args, refused by the owner).
function DevService:Execute(name: string, args: { string }, caller: Player?): string?
	const key = string.lower(name)
	if key == HELP then
		const text = self:Help()
		log(text)
		return text
	end
	const command = self.Commands[key]
	if command == nil then
		error(`{PREFIX} unknown command "{name}" (try "help")`, 0)
	end
	const reply = command.Run(args, caller)
	const who = if caller then caller.Name else "CommandBar"
	log(`{who}: {key} {table.concat(args, " ")}{if reply then ` -> {reply}` else ""}`)
	return reply
end

-- Command Bar entry: require(<DevService>).Run("day", 4). Static (dot call) and assigned through `any` on purpose:
-- it is not part of the service's self type, and the Command Bar copy of this module never booted.
local function run(name: string, ...: any): string?
	const args = {}
	for i = 1, select("#", ...) do
		table.insert(args, tostring((select(i, ...))))
	end
	if live ~= nil then
		return live:Execute(name, args, nil)
	end
	const bridge = script:FindFirstChild(BRIDGE)
	if bridge ~= nil and bridge:IsA("BindableFunction") then
		return bridge:Invoke(name, args)
	end
	error(`{PREFIX} dev mode is off (Run place in Studio only)`, 2)
end
(DevService :: any).Run = run

function DevService:BindBridge()
	const bridge = Instance.new("BindableFunction")
	bridge.Name = BRIDGE
	bridge.OnInvoke = function(name: string, args: { string }): string?
		return self:Execute(name, args, nil)
	end
	bridge.Parent = script
end

-- "/dev <command> <args>". Created on the server, so Triggered fires here with the unfiltered text.
function DevService:BindChat()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		warn(`{PREFIX} TextChatService is not the chat version: "{ALIAS}" unavailable, use the Command Bar`)
		return
	end
	const command = Instance.new("TextChatCommand")
	command.Name = CHAT_COMMAND
	command.PrimaryAlias = ALIAS
	command.Triggered:Connect(function(source: TextSource, text: string)
		const caller = Players:GetPlayerByUserId(source.UserId)
		const parts = words(text)
		table.remove(parts, 1) -- the alias
		const name = table.remove(parts, 1) or HELP
		const ok, err = pcall(function()
			self:Execute(name, parts, caller)
		end)
		if not ok then
			warn(`{PREFIX} {ALIAS} {name}: {err}`)
		end
	end)
	command.Parent = TextChatService
end

DevService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:IsDev() then
		return
	end
	self.Enabled = true

	-- settings panel dev row (TASK-332): the same commands as the chat, for the sender
	self.Libs.Net.DevTool:onServer(function(data, player: Player)
		const ok, err = pcall(function()
			if data.Tool == "Coffee" then
				self:Execute("mycoffee", {}, player)
			else
				self:Execute("infsanity", { if data.On then "on" else "off" }, player)
			end
		end)
		if not ok then
			warn(`{PREFIX} DevTool {data.Tool}: {err}`)
		end
	end)
end)

DevService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	self:Load()
	live = self
	self:BindBridge()
	self:BindChat()
	log(`dev mode: {#self.Order} command(s); type "{ALIAS} help" in chat`)
end)

return DevService
