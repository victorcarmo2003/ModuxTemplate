--!strict
-- ANM-021 The red fog, server rule (T10: never in shared). Owner 2026-10-18 ("uma névoa vermelha começa a aparecer, o sino
-- começa a tocar, tudo vai ficando vermelho e o player precisa fechar a janela; as janelas começam a tremer com batidas
-- muito fortes"). Verb shutter: every active player in the shop zone must be protected (window closed, inside) when the
-- fog reaches the glass (OmenFor s after the start); then the fog beats on the glass for BangFor s, and whoever opens the
-- window or steps outside in that time pays. Error = jumpscare + faint for that player (DEC-255). All numbers Provisional.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_021_red_fog",
	Verb = "shutter",
	LikelyWrongVerb = "keep_working",
	Window = 12,
	IsCritical = false,
	Params = {
		OmenFor = 12, -- s: the fog rises, the bell tolls; the window must be shut by then
		BangFor = 14, -- s: the fog beats on the glass (cutscene look); opening = scared
		Linger = 5, -- s the record stays after the end (the fog recedes on every client)
		ScareFaint = 0.6,
		ZonePoint = "TRL",
		ZoneRadius = 24,
	},
}

return rule
