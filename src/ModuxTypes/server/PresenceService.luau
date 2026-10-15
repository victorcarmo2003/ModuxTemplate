--!strict

export type Public = {
	Map: MemoryStoreHashMap?,
	Sent: number?,
	Total: number?,
	Warned: boolean,
	Setup: (self: Public) -> (),
	Warn: (self: Public, what: string, err: any) -> (),
	LocalCount: (self: Public) -> number,
	Count: (self: Public) -> number,
	Publish: (self: Public) -> (),
	Claim: (self: Public, map: MemoryStoreHashMap) -> boolean,
	Sum: (self: Public, map: MemoryStoreHashMap) -> number?,
	Read: (self: Public) -> (),
	Send: (self: Public) -> (),
}

return {}
