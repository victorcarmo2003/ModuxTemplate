--!strict
-- Player-facing texts of the lobby answers (placeholders for the narrative-writer, ui-text.md has no lobby section yet;
-- user request 2026-10-11, Provisional). The server sends keys (PartyNotice.Key, ClassBuyResult.Reason,
-- CodeRedeemResult.Reason); the client owns the words (network.md §15, §16). Pure: no Vide, no network.
-- Kind = toast colour: Info Teal, Good Green, Alert Mustard (never red, style guide §7.4).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Kind = "Info" | "Good" | "Alert"
export type Line = { Text: string, Kind: Kind }

-- {name} = the other player of the notice (PartyNotice.UserId)
const PARTY: { [string]: Line } = {
	Created = { Text = "Squad created!", Kind = "Good" },
	AlreadyInParty = { Text = "You're already in a squad", Kind = "Alert" },
	NotInParty = { Text = "You're not in a squad", Kind = "Alert" },
	NotLeader = { Text = "Only the squad leader can do that", Kind = "Alert" },
	PartyFull = { Text = "The squad is full", Kind = "Alert" },
	PlayerNotFound = { Text = "That player isn't here anymore", Kind = "Alert" },
	InviteSelf = { Text = "You can't invite yourself", Kind = "Alert" },
	InviteSent = { Text = "Invite sent to {name}", Kind = "Info" },
	InviteExpired = { Text = "That invite is gone", Kind = "Alert" },
	InviteDeclined = { Text = "{name} declined the invite", Kind = "Info" },
	Joined = { Text = "{name} joined the squad!", Kind = "Good" },
	Left = { Text = "{name} left the squad", Kind = "Info" },
	Kicked = { Text = "You were removed from the squad", Kind = "Alert" },
	NewLeader = { Text = "{name} is the new leader", Kind = "Info" },
	NotAllReady = { Text = "Not everyone is ready yet", Kind = "Alert" },
	Busy = { Text = "The squad is starting...", Kind = "Info" },
	TooFast = { Text = "Easy there! Try again in a moment", Kind = "Alert" },
	Starting = { Text = "Opening the shop... here we go!", Kind = "Good" },
	TeleportRetry = { Text = "Trip failed, trying again...", Kind = "Alert" },
	TeleportFailed = { Text = "Couldn't start the run. Try again!", Kind = "Alert" },
	StudioNoTeleport = { Text = "Studio can't teleport: test Start on a live server", Kind = "Info" },
	ReturningToLobby = { Text = "Heading back to the lobby...", Kind = "Info" },
	ReturnFailed = { Text = "Couldn't go back to the lobby", Kind = "Alert" },
	WrongServer = { Text = "Not available here", Kind = "Alert" },
	FriendsOnly = { Text = "This squad is friends only", Kind = "Alert" },
	Configured = { Text = "The leader changed the squad settings", Kind = "Info" },
}

-- {class} = class name
const CLASS_BUY: { [string]: Line } = {
	Ok = { Text = "{class} unlocked!", Kind = "Good" },
	Granted = { Text = "{class} unlocked!", Kind = "Good" },
	Converted = { Text = "You already had {class}: you got gems instead", Kind = "Info" },
	Owned = { Text = "You already own {class}", Kind = "Info" },
	NotEnoughGems = { Text = "Not enough gems", Kind = "Alert" },
	NotForSale = { Text = "{class} isn't for sale yet", Kind = "Alert" },
	Unavailable = { Text = "Robux purchase isn't available yet", Kind = "Alert" },
	Busy = { Text = "Easy there! Try again in a moment", Kind = "Alert" },
}

const CODE: { [string]: string } = {
	Invalid = "Invalid code",
	Expired = "This code has expired",
	Already = "You already used this code",
	Busy = "Easy there! Try again in a moment",
}

local function humanize(key: string): string
	return (string.gsub(key, "(%l)(%u)", "%1 %2"))
end

local function className(key: string?): string
	const class = if key then Content.Classes.ByKey[key] else nil
	return if class then class.Name else "Class"
end

local function party(key: string, name: string?): Line
	const line = PARTY[key] or { Text = humanize(key), Kind = "Info" :: Kind }
	return { Text = (string.gsub(line.Text, "{name}", name or "Someone")), Kind = line.Kind }
end

local function classBuy(reason: string, class: string): Line
	const line = CLASS_BUY[reason] or { Text = humanize(reason), Kind = "Alert" :: Kind }
	return { Text = (string.gsub(line.Text, "{class}", className(class))), Kind = line.Kind }
end

-- Feedback line of a code answer. Reward: gems credited (a class converted to gems included) and/or a class.
local function code(ok: boolean, reason: string, gems: number, class: string?): string
	if ok then
		const parts: { string } = {}
		if class then
			table.insert(parts, `{className(class)} unlocked`)
		end
		if gems > 0 then
			table.insert(parts, `+{gems} Gems`)
		end
		return if #parts > 0 then table.concat(parts, " · ") .. "!" else "Code redeemed!"
	end
	return CODE[reason] or humanize(reason)
end

return table.freeze({
	Party = party,
	ClassBuy = classBuy,
	Code = code,
	ClassName = className,
})
