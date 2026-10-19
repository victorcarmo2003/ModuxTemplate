--!strict
-- Dev: coffee machine of the trailer (owner request 2026-10-17: cooldown timer, BrewTag, cup in front of the machine).
--   coffeemachine take   the caller (or the first player) takes the waiting cup through the real "Take Coffee" action
--                        (KitchenService:Perform): the player is moved in front of the machine first, so the range check
--                        passes; the machine then goes into its clean wait (the "Next cup in" countdown).
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

type Kitchen = {
	Perform: (self: any, key: string, player: Player, anchor: Instance) -> (),
}

const ACTION = "brew_coffee"
const USAGE = "coffeemachine take"
const STAND_OFF = 2.5 -- studs in front of the prompt

local function brewAnchor(): Attachment?
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Attachment") and descendant:GetAttribute("PromptAction") == ACTION then
			return descendant
		end
	end
	return nil
end

const CoffeeMachine: Api.Module = function(ctx: Api.Context): { Api.Command }
	const kitchen = ctx.Get("KitchenService") :: Kitchen

	return {
		{
			Name = "coffeemachine",
			Usage = USAGE,
			Help = "take: the caller (or the first player) takes the waiting coffee, the machine starts its clean wait",
			Run = function(args: { string }, caller: Player?): string?
				if args[1] ~= "take" then
					error(`usage: {USAGE}`, 0)
				end
				const player = caller or Players:GetPlayers()[1]
				if player == nil then
					error("no player", 0)
				end
				const anchor = brewAnchor()
				if anchor == nil then
					error("no coffee machine prompt (Prompt_Brew) in the workspace", 0)
				end
				const character = player.Character
				const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
				if root and root:IsA("BasePart") then
					const host = anchor.Parent
					const look = if host and host:IsA("BasePart") then host.CFrame.LookVector else Vector3.zAxis
					const at = anchor.WorldPosition + Vector3.new(look.X, 0, look.Z).Unit * STAND_OFF
					root.CFrame = CFrame.lookAt(at, Vector3.new(anchor.WorldPosition.X, at.Y, anchor.WorldPosition.Z))
				end
				kitchen:Perform(ACTION, player, anchor)
				return `take sent for {player.Name}`
			end,
		},
	}
end

return CoffeeMachine
