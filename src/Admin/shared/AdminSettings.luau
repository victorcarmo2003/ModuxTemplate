--!strict
-- Admin console (Conch) access policy. Read by the server (authoritative) and the client (only decides whether
-- to bind the key; the server never trusts it). Pure data + one predicate: no Modux, Lync or Vide.
-- Policy (docs/tech/admin.md): Studio is always allowed; a published server only allows the UserIds below.
-- Add your own UserId here to use the console in a live server. Never add anyone else's without asking.
local RunService = game:GetService("RunService")

const AdminSettings = {
	AdminUserIds = {} :: { number },
	ToggleKey = Enum.KeyCode.F2,
}

function AdminSettings.IsAllowed(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return table.find(AdminSettings.AdminUserIds, player.UserId) ~= nil
end

return AdminSettings
