--!strict
-- Squad (party) rules shared by PartyService (lobby), PartyRunService (game) and the lobby UI (architecture.md §20.2;
-- network.md §16). ReplicatedStorage.shared.Party.PartyRules. Pure: no Modux, Lync, Vide nor self.Libs.
-- Platform squads (user request 2026-10-11): a squad may own one of the 8 lobby platforms (Platform 1..8, 0 = none;
-- LOBBY.md v2 §V2-4);
-- State "Forming" = invite squad, "Configuring" = platform squad being set up, "Starting" = countdown / teleport.
-- MaxSize comes from the party price table (4 = DEC-012 "party de até 4"), the same source RunStateService uses.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

-- PartyNotice.Key (s -> c). The client owns the texts; UserId (optional) names the other player when there is one.
const NOTICE_KEYS = table.freeze({
	"Created", -- you created a squad
	"AlreadyInParty", -- create while in a squad
	"NotInParty", -- action that needs a squad
	"NotLeader", -- leader-only action
	"PartyFull", -- invite or accept with MaxSize members
	"PlayerNotFound", -- invite / kick target not in this server or not in the squad
	"InviteSelf", -- invite yourself
	"InviteSent", -- UserId = invited player
	"InviteExpired", -- answer to an invite that is gone (expired, squad gone or started)
	"InviteDeclined", -- to the leader; UserId = who declined
	"Joined", -- to the squad; UserId = who joined
	"Left", -- to the squad; UserId = who left
	"Kicked", -- to the kicked player
	"NewLeader", -- to the squad; UserId = new leader
	"NotAllReady", -- Start with a member not ready
	"Busy", -- squad is starting: nothing changes until the teleport ends
	"TooFast", -- rate limit
	"Starting", -- to the squad: server reserved, teleport on its way
	"TeleportRetry", -- to the squad / player: an attempt failed, trying again
	"TeleportFailed", -- every attempt failed: still in the lobby
	"StudioNoTeleport", -- Studio cannot teleport: nothing happens (test the rest)
	"ReturningToLobby", -- game server: teleport back to the lobby on its way
	"ReturnFailed", -- game server: every attempt to go back failed
	"WrongServer", -- squad packet outside a lobby / return packet outside a game
	-- squad platforms (user request 2026-10-11, Provisional; network.md §16.6)
	"FriendsOnly", -- stepped on a friends-only platform of someone who is not a friend
	"Configured", -- to the squad: the leader changed Friends only / Max players
})

const RULES = table.freeze({
	MaxSize = #Content.RunParams.PartyPriceMult, -- 4 (DEC-012, DEC-047)
	InviteTtl = 60, -- s an invite stays valid
	InviteCooldown = 3, -- s between two invites of one squad to the same player
	RateMax = 8, -- squad packets per player per window
	RateWindow = 1, -- s
	TeleportRetries = table.freeze({ 2, 5, 10 }), -- s before each retry (architecture.md §5.2: 3 tries)
	ReturnDelay = 12, -- s after RunEnded before the game server sends everyone back (RunEnd lasts 15 s)
	JoinWindow = Content.RunParams.JoinWindow, -- 60 s: the run waits this long for the squad (DEC-098)
	PartyIdMax = 65535, -- Party set record ids cycle in 1..PartyIdMax
	-- squad platforms (Content.Lobby.Squad; network.md §16.6)
	Platforms = 8, -- LOBBY-SQUAD-1..8 (LOBBY.md v2; = #Content.Lobby.Zones with Platform > 0)
	Countdown = Content.Lobby.Squad.Countdown, -- s between Start and the teleport (every squad, platform or not)
	DefaultMaxPlayers = Content.Lobby.Squad.DefaultMaxPlayers,
	DefaultFriendsOnly = Content.Lobby.Squad.DefaultFriendsOnly,
})

local isKey: { [string]: boolean } = {}
for _, key in NOTICE_KEYS do
	isKey[key] = true
end

return table.freeze({
	NoticeKeys = NOTICE_KEYS,
	IsNoticeKey = table.freeze(isKey),
	Rules = RULES,
})
