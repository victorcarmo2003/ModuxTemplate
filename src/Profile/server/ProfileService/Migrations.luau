--!strict
-- Profile migrations (docs/tech/data.md §1.5). Append-only: Migrations[v] takes data at version v to v + 1, in place,
-- as a pure function of the data. Renaming or removing a field needs one (Reconcile only adds missing fields).
-- Version 1 is the first published version: nothing to migrate yet.

export type Migration = (data: { [string]: any }) -> ()

const Migrations: { [number]: Migration } = {}

return Migrations
