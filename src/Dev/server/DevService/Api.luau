--!strict
-- Contract of DevService/Commands/*.luau (board TASK-042; tests/wave-1.md §0.4). Pure: no Modux, Lync or Charm.
-- Each file in Commands/ returns a Module: a factory called once by DevService in its OnStart (every service has
-- run its OnInit, so signals exist and can be connected here). New command = new file; the DevService init is
-- never edited (TASK-043/044/045 run in parallel).

export type Context = {
	-- Live service by Modux ID (e.g. "RoundService"). Errors if that service is not in this build.
	Get: (name: string) -> any,
	-- Prints "[Dev] <message>" in the server Output (logs that are not a command reply, e.g. TASK-044/045).
	Log: (message: string) -> (),
}

export type Command = {
	Name: string, -- lowercase, one word; "help" is reserved
	Usage: string, -- e.g. "day <n>"
	Help: string, -- one line, English
	-- args = words after the command name, as strings. caller = nil from the Command Bar.
	-- Returns the reply printed in the Output; error(...) = refused (message shown as a warning).
	Run: (args: { string }, caller: Player?) -> string?,
}

export type Module = (ctx: Context) -> { Command }

return {}
