--!strict

export type Public = {
	Names: { [number]: string },
	Setup: (self: Public) -> (),
	Celebrate: (self: Public, id: number) -> (),
	CelebrateGift: (self: Public, gift: { Kind: string, Key: string, Amount: number, FromName: string }) -> (),
	Show: (self: Public, text: string, hold: number) -> (),
}

return {}
