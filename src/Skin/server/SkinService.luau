--!strict
-- Class skins, Robux only (owner request 2026-10-17, Provisional; design/skins-proposal.md, Q-300..Q-305). Lobby and Run.
-- Visual only (DEC-069 guard): nothing here touches a class number.
--   ownership   profile.Skins[key] = os.time() of the grant. The ONLY writer of a grant is the Roblox receipt of the skin's
--               Developer Product (Content.Skins ProductId, registered with ShopService:RegisterProduct; idempotent per
--               PurchaseId there). A receipt after EndsAt is granted too (Roblox already charged).
--   equipped    profile.EquippedSkins[class] = key. SkinEquip (c -> s): owned skin of that class, owned class; "none" takes
--               it off. A fresh purchase of a skin whose class is owned is equipped at once (Q-300).
--   SkinState   s -> owner on load / ClientReady and after every change.
--   SkinOf      the skin a player wears with a class (CharacterService at spawn, the run's lock follows the class lock).
-- In the Run, SkinEquip is accepted only in dev mode, like ClassAction (ClassService:CanWrite): the skin locks with the class.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)
local MetricsLog = require(ServerScriptService.server.Metrics.MetricsService.Log)
local Atomic = require(ReplicatedStorage.shared.Types.Atomic)
local Template = require(ServerScriptService.server.Profile.ProfileService.Template)

-- Same type as ProfileService.Profile (one atom per Template field)
type Profile = Atomic.Table<Template.Data>

const RATE_MAX = 4 -- SkinEquip per player per window
const RATE_WINDOW = 1
const NONE = Content.Skins.Rules.None

const SkinService = Modux.Service(
	"SkinService",
	{ Require = { "ProfileService", "NetService", "ShopService", "PlaceService" }, Priority = 720 }
)

function SkinService:Setup()
	self.RateStart = {} :: { [Player]: number }
	self.RateCount = {} :: { [Player]: number }
end

function SkinService:Allow(player: Player): boolean
	const now = os.clock()
	const start = self.RateStart[player]
	if start == nil or now - start >= RATE_WINDOW then
		self.RateStart[player] = now
		self.RateCount[player] = 1
		return true
	end
	const count = (self.RateCount[player] or 0) + 1
	self.RateCount[player] = count
	return count <= RATE_MAX
end

-- Skins of a loaded profile known to Content (unknown keys ignored on read, data.md §1.5).
function SkinService:Owned(player: Player): { [string]: boolean }
	const owned: { [string]: boolean } = {}
	const profile = self.Dependencies.ProfileService:Get(player)
	if profile == nil then
		return owned
	end
	for key, at in profile.Skins() do
		if type(at) == "number" and Content.Skins.ByKey[key] ~= nil then
			owned[key] = true
		end
	end
	return owned
end

-- On sale now: limited skins until EndsAt; ProductId 0 = not created (never sold).
function SkinService:OnSale(skin: Content.Skin): boolean
	return skin.ProductId > 0 and (not skin.Limited or os.time() < skin.EndsAt)
end

-- Skin `player` wears with `class`; nil = the crew uniform. Only an owned skin of that class counts.
function SkinService:SkinOf(player: Player, class: string): string?
	const profile = self.Dependencies.ProfileService:Get(player)
	if profile == nil then
		return nil
	end
	const key = profile.EquippedSkins()[class]
	const skin = if type(key) == "string" then Content.Skins.ByKey[key] else nil
	if skin == nil or skin.Class ~= class or not self:Owned(player)[skin.Key] then
		return nil
	end
	return skin.Key
end

function SkinService:Send(player: Player)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or not net:IsReady(player) then
		return
	end
	const profile = self.Dependencies.ProfileService:Get(player)
	if profile == nil then
		return
	end
	const equipped: { { Class: string, Skin: string } } = {}
	for class in profile.EquippedSkins() do
		const key = if Content.Classes.ByKey[class] then self:SkinOf(player, class) else nil
		if key ~= nil then
			table.insert(equipped, { Class = class, Skin = key })
		end
	end
	self.Libs.Net.SkinState:fireClient(player, {
		Owned = self:Owned(player),
		Equipped = equipped,
	})
end

-- In the Run the skin locks with the class (dev mode excepted); the Lobby always accepts.
function SkinService:CanWrite(): boolean
	const place = self.Dependencies.PlaceService
	return not place:Is("Run") or place:IsDev()
end

function SkinService:Equip(player: Player, class: string, key: string)
	if not self:CanWrite() then
		return
	end
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if profile == nil or Content.Classes.ByKey[class] == nil then
		return
	end
	if key ~= NONE then
		const skin = Content.Skins.ByKey[key]
		if skin == nil or skin.Class ~= class or not self:Owned(player)[key] then
			return
		end
		if not profiles:OwnedClasses(profile)[class] then
			return -- bought for a class not owned yet (Q-300): kept, worn once the class is owned
		end
	end
	const current = profile.EquippedSkins()
	if (current[class] or NONE) == key then
		self:Send(player) -- the client may be out of date: answer anyway
		return
	end
	const copy = table.clone(current)
	copy[class] = if key == NONE then nil else key
	profiles:Update(player, { EquippedSkins = copy })
	profiles:RequestSave(player)
	self:Send(player)
end

-- Receipt handler of one skin (ShopService grants once per PurchaseId, Patch + Receipts in one batch).
function SkinService:Handler(skin: Content.Skin): any
	return function(player: Player, profile: Profile)
		const skins: { [string]: number } = table.clone(profile.Skins())
		const fresh = skins[skin.Key] == nil
		skins[skin.Key] = skins[skin.Key] or os.time()
		const patch: { [string]: any } = { Skins = skins }
		if fresh and self.Dependencies.ProfileService:OwnedClasses(profile)[skin.Class] then
			const equipped: { [string]: string } = table.clone(profile.EquippedSkins())
			equipped[skin.Class] = skin.Key
			patch.EquippedSkins = equipped
		end
		return {
			Patch = patch,
			After = function()
				self:Send(player)
				MetricsLog.player(player, "skin_bought", nil, { skin = skin.Key, class = skin.Class })
				MetricsLog.panel(player, "classes", 3, "buy", { skin = skin.Key, currency = "robux" })
			end,
		}
	end
end

-- Dev: `/dev receipt <skin key>` runs the receipt path (ShopService:DevReceipt finds the product registered here).
-- Dev hook: forget every skin of a player (dev mode only).
function SkinService:DevReset(player: Player)
	if not self.Dependencies.PlaceService:IsDev() then
		error("[SkinService] DevReset needs dev mode")
	end
	self.Dependencies.ProfileService:Update(player, { Skins = {}, EquippedSkins = {} })
	self.Dependencies.ProfileService:RequestSave(player)
	self:Send(player)
end

SkinService:OnInit(function(self)
	self:Setup()

	const shop = self.Dependencies.ShopService
	for _, skin in Content.Skins.List do
		shop:RegisterProduct(skin.ProductId, skin.Key, self:Handler(skin))
	end

	self.Dependencies.ProfileService.Loaded:Connect(function(player)
		self:Send(player)
	end)
	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:Send(player)
	end)

	self.Libs.Net.SkinEquip:onServer(function(data, player: Player)
		if not self:Allow(player) then
			return
		end
		self:Equip(player, data.Class, data.Skin)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.RateStart[player] = nil
		self.RateCount[player] = nil
	end)
end)

return SkinService
