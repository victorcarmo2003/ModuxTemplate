--!strict
-- Mock: the data of the dev preview `/dev prep ui` (the mode opened locally, no seat, no server). Plain tables the
-- controller copies into its view-model; nothing here talks to the network or to the stock.
local Mock = {}

-- A ticket in the shape of TicketRail.Ticket (declared here so the controller does not need the component type).
export type Ticket = {
	Id: number,
	Name: string,
	Say: string,
	Toppings: { string },
	Patience: number,
	State: "Active" | "Served" | "Urgent",
}

Mock.Ticket = {
	Id = 12,
	Name = "Rex",
	Say = "The usual, please.",
	Toppings = { "ketchup", "mustard", "cheese" },
	Patience = 0.72,
	State = "Active",
} :: Ticket

Mock.Queue = 3

-- Order: customers waiting, Grill: sausages ready, Serve: plates ready
Mock.Badges = { Order = 2, Grill = 3, Serve = 1 } :: { [string]: number }

-- Stock per topping: the low one (<= 2), the empty one and the locked one show every box state of the panel.
Mock.Stock = {
	ketchup = { Stock = 12, Locked = false },
	mustard = { Stock = 9, Locked = false },
	cream_cheese = { Stock = 2, Locked = false },
	cheese = { Stock = 0, Locked = true },
	bacon = { Stock = 0, Locked = false },
	potato_sticks = { Stock = 10, Locked = false },
} :: { [string]: { Stock: number, Locked: boolean } }

return Mock
