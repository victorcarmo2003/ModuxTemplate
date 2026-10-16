--!strict

export type Public = {
	ProductKeys: { [number]: string },
	RunStarted: boolean,
	Started: boolean,
	Tutorial: { [Player]: { [number]: boolean } },
	UiAt: { [Player]: number },
	Setup: (self: Public) -> (),
	Init: (self: Public) -> (),
	Members: (self: Public) -> { Player },
	WireRound: (self: Public) -> (),
	WireAnomalies: (self: Public) -> (),
	WireCrew: (self: Public) -> (),
	WireWorld: (self: Public) -> (),
	OnTutorialStep: (self: Public, player: Player, index: number) -> (),
	OnUi: (self: Public, player: Player, event: string, key: string?) -> (),
	WireNet: (self: Public) -> (),
}

return {}
