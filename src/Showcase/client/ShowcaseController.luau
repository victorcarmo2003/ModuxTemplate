--!strict
--[[
	ShowcaseController (docs/tech/showcase.md; user request 2026-10-12, Provisional). Dev only: the client half of the
	showcase tester. Mounts ShowcasePanel in Studio dev mode (PlaceController:IsDev) and talks to ShowcaseService with
	the dev-only packets ShowcaseDo (c -> s), ShowcaseCatalog / ShowcaseState / ShowcaseLog / ShowcaseScare (s -> c).

	  - F9, `/dev showcase` and the Conch command `showcase` toggle the panel. Opening sends ShowcaseDo "open": the
	    server (dev mode + admin whitelist, checked on every request) answers with the catalog and then the state at 2 Hz.
	    A server that refuses never answers, so the panel stays empty and says nothing it should not.
	  - The panel never decides anything: every button is one ShowcaseDo; the server forces the real service and replies
	    with a ShowcaseLog line (shown at the bottom of the panel).
	  - ShowcaseScare plays a hallucination through HallucinationController:DevPlay (client-only effects) or a sting
	    through AudioController (Scare cap, DEC-173).
	  - While the panel is open a zero-size Modal button frees the mouse from the first-person lock (as the lobby screens).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local ShowcasePanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ShowcasePanel)
local UiScale = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.UiScale)

type Item = ShowcasePanel.Item
type Row = ShowcasePanel.Row
type State = ShowcasePanel.State

const BIND = "ShowcaseToggle"
const TABS = { "Anomalies", "Scares", "Mechanics" }
const STING = "sting:"
const PREFIX = "[ShowcaseController]"
const EMPTY: State = {
	Night = 0,
	Phase = "-",
	Clock = 0,
	Sanity = 0,
	SanityMax = 0,
	Life = "-",
	Revives = 0,
	Frozen = false,
	God = false,
	Dark = "auto",
	Held = false,
	Switch = true,
	Shutter = false,
	Vehicle = "-",
	Running = {},
}

const ShowcaseController = Modux.Controller("ShowcaseController", {
	Require = { "PlaceController", "InputController", "HallucinationController", "AudioController" },
	Priority = 55,
})

function ShowcaseController:Setup()
	self.Open = Vide.source(false) :: Vide.Source<boolean>
	self.Tab = Vide.source(TABS[1]) :: Vide.Source<string>
	self.Items = Vide.source({} :: { Item }) :: Vide.Source<{ Item }>
	self.State = Vide.source(EMPTY) :: Vide.Source<State>
	self.LogText = Vide.source("Press a button. The server answers here.") :: Vide.Source<string>
	self.LogKind = Vide.source("info") :: Vide.Source<string>
	self.Viewport = Vide.source(Vector2.new(1280, 720)) :: Vide.Source<Vector2>
	self.Mounted = false :: boolean
end

function ShowcaseController:IsDev(): boolean
	return self.Dependencies.PlaceController:IsDev()
end

-- Panel state ---------------------------------------------------------------------------------------------------------

function ShowcaseController:Send(action: string, id: string, arg: string, value: number)
	self.Libs.Net.ShowcaseDo:fireServer({ Action = action, Id = id, Arg = arg, Value = value })
end

function ShowcaseController:Show()
	if not self:IsDev() then
		return
	end
	if Vide.untrack(self.Open) then
		return
	end
	self.Open(true)
	self:Send("open", "", "", 0)
end

function ShowcaseController:Hide()
	if not Vide.untrack(self.Open) then
		return
	end
	self.Open(false)
	self:Send("close", "", "", 0)
end

function ShowcaseController:Toggle()
	if Vide.untrack(self.Open) then
		self:Hide()
	else
		self:Show()
	end
end

function ShowcaseController:Log(kind: string, text: string)
	Vide.batch(function()
		self.LogKind(kind)
		self.LogText(text)
	end)
end

-- Rows of the current tab: a heading per group (catalog order), then its cards.
function ShowcaseController:BuildRows(): { Row }
	const tab = self.Tab()
	const rows: { Row } = {}
	local group = ""
	for _, item in self.Items() do
		if item.Tab ~= tab then
			continue
		end
		if item.Group ~= group then
			group = item.Group
			table.insert(rows, { Kind = "Group", Title = group, Item = nil })
		end
		table.insert(rows, { Kind = "Item", Title = item.Name, Item = item })
	end
	return rows
end

-- Scares ---------------------------------------------------------------------------------------------------------------

function ShowcaseController:OnScare(id: string, stop: boolean)
	if not self:IsDev() then
		return
	end
	const hallucinations = self.Dependencies.HallucinationController
	if stop then
		self:Log("ok", hallucinations:DevStop())
		return
	end
	if string.sub(id, 1, #STING) == STING then
		const key = string.sub(id, #STING + 1)
		const sound = self.Dependencies.AudioController:Play(key, nil, { Scare = key ~= "car_honk_goofy" })
		self:Log(if sound ~= nil then "ok" else "error", if sound ~= nil then `{key} played` else `{key}: no sound`)
		return
	end
	self:Log("ok", hallucinations:DevPlay(id))
end

-- Mount ----------------------------------------------------------------------------------------------------------------

function ShowcaseController:WatchViewport()
	local connection: RBXScriptConnection? = nil
	local function bind()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		const camera = workspace.CurrentCamera
		if camera then
			self.Viewport(camera.ViewportSize)
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self.Viewport(camera.ViewportSize)
			end)
		end
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
	bind()
end

function ShowcaseController:Mount(playerGui: Instance)
	const _, gui = Vide.root(function()
		-- derive needs a stable scope: it lives inside the root (user report 2026-10-12)
		const rows = Vide.derive(function(): { Row }
			return self:BuildRows()
		end)
		return Vide.create("ScreenGui")({
			Name = "Showcase",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 60,

			-- frees the mouse of the first-person camera while the panel is open
			Vide.create("TextButton")({
				Name = "Modal",
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Text = "",
				Modal = self.Open,
				Visible = self.Open,
			}),

			ShowcasePanel({
				Shown = self.Open,
				Scale = function(): number
					return UiScale.Current()
				end,
				Viewport = self.Viewport,
				Tab = self.Tab,
				Tabs = TABS,
				Rows = rows,
				State = self.State,
				LogText = self.LogText,
				LogKind = self.LogKind,
				OnTab = function(tab: string)
					self.Tab(tab)
				end,
				OnAction = function(action: string, id: string, arg: string, value: number)
					self:Send(action, id, arg, value)
				end,
				OnClose = function()
					self:Hide()
				end,
			}),
		})
	end)
	gui.Parent = playerGui
	self.Mounted = true
end

ShowcaseController:OnInit(function(self)
	self:Setup()
	const net = self.Libs.Net
	net.ShowcaseCatalog:onClient(function(data)
		const items: { Item } = {}
		for _, entry in data.Items do
			const actions: { ShowcasePanel.Action } = {}
			for _, action in entry.Actions do
				table.insert(actions, { Id = action.Id, Label = action.Label, Arg = action.Arg })
			end
			table.insert(items, {
				Tab = entry.Tab,
				Group = entry.Group,
				Id = entry.Id,
				Name = entry.Name,
				Ref = entry.Ref,
				Desc = entry.Desc,
				Verb = entry.Verb,
				Actions = actions,
			})
		end
		self.Items(items)
	end)
	net.ShowcaseState:onClient(function(data)
		const running: { ShowcasePanel.Occurrence } = {}
		for _, entry in data.Running do
			table.insert(running, { Ref = entry.Ref, Phase = entry.Phase, Step = entry.Step, Age = entry.Age, Live = entry.Live })
		end
		self.State({
			Night = data.Night,
			Phase = data.Phase,
			Clock = data.Clock,
			Sanity = data.Sanity,
			SanityMax = data.SanityMax,
			Life = data.Life,
			Revives = data.Revives,
			Frozen = data.Frozen,
			God = data.God,
			Dark = data.Dark,
			Held = data.Held,
			Switch = data.Switch,
			Shutter = data.Shutter,
			Vehicle = data.Vehicle,
			Running = running,
		})
	end)
	net.ShowcaseLog:onClient(function(data)
		if data.Kind == "open" then
			self:Show()
			return
		end
		self:Log(data.Kind, data.Text)
	end)
	net.ShowcaseScare:onClient(function(data)
		self:OnScare(data.Id, data.Stop)
	end)
end)

ShowcaseController:OnStart(function(self)
	if not self:IsDev() then
		return
	end
	self:WatchViewport()
	self.Dependencies.InputController
		:Bind({
			Name = BIND,
			Key = Enum.KeyCode.F9,
		})
		.OnPress(function()
			self:Toggle()
		end)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
		print(`{PREFIX} dev showcase ready (F9, "/dev showcase" or the Conch command "showcase")`)
	end)
end)

return ShowcaseController
